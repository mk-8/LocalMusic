import AVFoundation
import Combine
import Foundation
import MediaPlayer

/// Global singleton managing audio playback via AVQueuePlayer.
/// Publishes state changes so SwiftUI views can react.
@MainActor
final class AudioService: ObservableObject {
    static let shared = AudioService()

    // MARK: - Published State

    @Published var isPlaying = false
    @Published var currentSong: Song?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var shuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off

    // MARK: - Queue

    /// The original (unshuffled) queue of file names.
    private(set) var originalQueue: [String] = []
    /// The active queue (may be shuffled). Published so UpNextView can observe.
    @Published private(set) var activeQueue: [String] = []
    @Published private(set) var currentIndex: Int = 0

    // MARK: - Private

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    private let dbService = DBService()

    private init() {
        configureAudioSession()
        restoreState()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }

    // MARK: - Queue Management

    /// Replace the entire queue and start playing at the given index.
    func setQueue(fileNames: [String], startIndex: Int = 0) {
        originalQueue = fileNames
        if shuffleEnabled {
            var shuffled = fileNames
            if startIndex < fileNames.count {
                // Keep the starting song first, shuffle the rest
                let first = shuffled.remove(at: startIndex)
                shuffled.shuffle()
                shuffled.insert(first, at: 0)
            } else {
                shuffled.shuffle()
            }
            activeQueue = shuffled
            currentIndex = 0
        } else {
            activeQueue = fileNames
            currentIndex = min(startIndex, max(fileNames.count - 1, 0))
        }
        playCurrent()
    }

    // MARK: - Up Next Queue Manipulation

    /// Insert a song immediately after the currently playing track.
    func playNext(fileName: String) {
        guard !activeQueue.isEmpty else { return }
        let insertIndex = currentIndex + 1
        activeQueue.insert(fileName, at: insertIndex)

        // Keep originalQueue in sync so the song survives an un-shuffle.
        if let origCurrent = currentIndex < activeQueue.count
            ? activeQueue[currentIndex] : nil,
           let origIdx = originalQueue.firstIndex(of: origCurrent) {
            originalQueue.insert(fileName, at: origIdx + 1)
        } else {
            originalQueue.append(fileName)
        }
        persistState()
    }

    /// Append a song at the end of the queue.
    func addToQueue(fileName: String) {
        guard !activeQueue.isEmpty else { return }
        activeQueue.append(fileName)
        originalQueue.append(fileName)
        persistState()
    }

    /// Remove a song from the queue by its global index.
    /// Refuses to remove the currently playing song.
    func removeFromQueue(at index: Int) {
        guard activeQueue.indices.contains(index), index != currentIndex else { return }
        let removed = activeQueue.remove(at: index)
        if let origIdx = originalQueue.firstIndex(of: removed) {
            originalQueue.remove(at: origIdx)
        }
        if index < currentIndex {
            currentIndex -= 1
        }
        persistState()
    }

    /// Jump to an arbitrary position in the queue and begin playback.
    func skipToQueueIndex(_ index: Int) {
        guard activeQueue.indices.contains(index) else { return }
        currentIndex = index
        playCurrent()
    }

    /// Reorder items in the "up next" portion of the queue (everything after currentIndex).
    /// `source` and `destination` are **local** indices within the up-next slice.
    func moveUpNextItem(from source: IndexSet, to destination: Int) {
        let upNextStart = currentIndex + 1
        guard upNextStart < activeQueue.count else { return }

        var upNext = Array(activeQueue[upNextStart...])
        upNext.move(fromOffsets: source, toOffset: destination)
        activeQueue.replaceSubrange(upNextStart..., with: upNext)
        persistState()
    }

    // MARK: - Transport

    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackInfo()
        persistState()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackInfo()
        persistState()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func next() {
        guard !activeQueue.isEmpty else { return }
        if repeatMode == .repeatOne {
            seek(to: 0)
            play()
            return
        }
        let nextIndex = currentIndex + 1
        if nextIndex < activeQueue.count {
            currentIndex = nextIndex
            playCurrent()
        } else if repeatMode == .repeatAll {
            currentIndex = 0
            playCurrent()
        } else {
            pause()
            seek(to: 0)
        }
    }

    func previous() {
        // If more than 3 seconds in, restart current track; otherwise go back.
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard !activeQueue.isEmpty else { return }
        let prevIndex = currentIndex - 1
        if prevIndex >= 0 {
            currentIndex = prevIndex
            playCurrent()
        } else if repeatMode == .repeatAll {
            currentIndex = activeQueue.count - 1
            playCurrent()
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = seconds
                self?.updateNowPlayingPlaybackInfo()
                self?.persistState()
            }
        }
    }

    // MARK: - Shuffle

    func toggleShuffle() {
        shuffleEnabled.toggle()
        if shuffleEnabled {
            let currentFile = activeQueue.indices.contains(currentIndex)
                ? activeQueue[currentIndex] : nil
            var shuffled = originalQueue
            shuffled.shuffle()
            if let f = currentFile, let idx = shuffled.firstIndex(of: f) {
                shuffled.remove(at: idx)
                shuffled.insert(f, at: 0)
            }
            activeQueue = shuffled
            currentIndex = 0
        } else {
            // Restore original order, keep current song
            let currentFile = activeQueue.indices.contains(currentIndex)
                ? activeQueue[currentIndex] : nil
            activeQueue = originalQueue
            if let f = currentFile, let idx = activeQueue.firstIndex(of: f) {
                currentIndex = idx
            }
        }
        persistState()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next()
        persistState()
    }

    // MARK: - Core Playback

    private func playCurrent() {
        removeObservers()
        guard activeQueue.indices.contains(currentIndex) else {
            isPlaying = false
            return
        }
        let fileName = activeQueue[currentIndex]
        let url = Self.documentsURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("File not found: \(url.path)")
            isPlaying = false
            return
        }

        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }
        currentSong = dbService.song(byFileName: fileName)

        addObservers()
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
        persistState()

        // Ensure Now Playing shows an accurate duration once it's loaded
        Task { [weak self] in
            guard let self else { return }
            if let d = try? await item.asset.load(.duration), d.isValid && !d.isIndefinite {
                await MainActor.run {
                    self.duration = CMTimeGetSeconds(d)
                    self.updateNowPlayingInfo()
                }
            }
        }
    }

    // MARK: - Observers

    private func addObservers() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = CMTimeGetSeconds(time)
                if let d = self.player?.currentItem?.duration, d.isValid && !d.isIndefinite {
                    self.duration = CMTimeGetSeconds(d)
                }
                self.updateNowPlayingPlaybackInfo()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleTrackEnd()
            }
        }
    }

    private func removeObservers() {
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
    }

    private func handleTrackEnd() {
        switch repeatMode {
        case .repeatOne:
            seek(to: 0)
            play()
        case .repeatAll:
            currentIndex = (currentIndex + 1) % max(activeQueue.count, 1)
            playCurrent()
        case .off:
            if currentIndex + 1 < activeQueue.count {
                currentIndex += 1
                playCurrent()
            } else {
                isPlaying = false
                updateNowPlayingPlaybackInfo()
            }
        }
    }

    // MARK: - Now Playing Info (lock screen)

    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentSong?.title ?? "Unknown"
        info[MPMediaItemPropertyArtist] = currentSong?.artist ?? ""
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if let data = currentSong?.artworkData, let img = UIImage(data: data) {
            let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingPlaybackInfo() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - State Persistence

    private func persistState() {
        let state = QueueState(
            songFileNames: originalQueue,
            currentIndex: currentIndex,
            elapsedSeconds: currentTime,
            shuffleEnabled: shuffleEnabled,
            repeatMode: repeatMode
        )
        state.save()
    }

    private func restoreState() {
        guard let state = QueueState.load() else { return }
        originalQueue = state.songFileNames
        shuffleEnabled = state.shuffleEnabled
        repeatMode = state.repeatMode

        if shuffleEnabled {
            var shuffled = originalQueue
            shuffled.shuffle()
            if state.currentIndex < originalQueue.count {
                let current = originalQueue[state.currentIndex]
                if let idx = shuffled.firstIndex(of: current) {
                    shuffled.remove(at: idx)
                    shuffled.insert(current, at: 0)
                }
            }
            activeQueue = shuffled
            currentIndex = 0
        } else {
            activeQueue = originalQueue
            currentIndex = state.currentIndex
        }

        // Prepare the player without auto-playing; user taps play to resume.
        guard activeQueue.indices.contains(currentIndex) else { return }
        let fileName = activeQueue[currentIndex]
        let url = Self.documentsURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.pause()
        currentSong = dbService.song(byFileName: fileName)

        let seekTime = CMTime(seconds: state.elapsedSeconds, preferredTimescale: 600)
        player?.seek(to: seekTime)
        currentTime = state.elapsedSeconds

        addObservers()

        // Load duration async from the player item
        Task {
            if let d = try? await item.asset.load(.duration), d.isValid && !d.isIndefinite {
                self.duration = CMTimeGetSeconds(d)
            }
            updateNowPlayingInfo()
        }
    }

    // MARK: - Helpers

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
