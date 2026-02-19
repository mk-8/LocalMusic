import Foundation
import Combine

/// Bridges AudioService published properties to the Now Playing view.
/// Keeps scrubber state separate so dragging doesn't fight the periodic time observer.
@MainActor
final class NowPlayingViewModel: ObservableObject {
    @Published var isScrubbing = false
    @Published var scrubValue: Double = 0

    private var cancellables = Set<AnyCancellable>()

    let audio = AudioService.shared

    init() {
        audio.$currentTime
            .receive(on: RunLoop.main)
            .sink { [weak self] t in
                guard let self, !self.isScrubbing else { return }
                self.scrubValue = t
            }
            .store(in: &cancellables)
    }

    func beginScrub() {
        isScrubbing = true
    }

    func endScrub() {
        audio.seek(to: scrubValue)
        isScrubbing = false
    }

    func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
