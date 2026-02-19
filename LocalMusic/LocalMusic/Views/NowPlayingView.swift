import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var audio: AudioService
    @StateObject private var vm = NowPlayingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showUpNext = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                artworkView
                    .padding(.horizontal, 40)

                Spacer().frame(height: 32)

                // Song info
                VStack(spacing: 4) {
                    Text(audio.currentSong?.title ?? "Not Playing")
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                    Text(audio.currentSong?.artist ?? "")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                // Scrubber
                VStack(spacing: 4) {
                    Slider(
                        value: $vm.scrubValue,
                        in: 0...max(audio.duration, 1),
                        onEditingChanged: { editing in
                            if editing { vm.beginScrub() } else { vm.endScrub() }
                        }
                    )
                    .tint(Color.accentColor)

                    HStack {
                        Text(vm.formattedTime(vm.scrubValue))
                        Spacer()
                        Text("-\(vm.formattedTime(max(audio.duration - vm.scrubValue, 0)))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                // Transport controls
                HStack(spacing: 40) {
                    Button { audio.toggleShuffle() } label: {
                        Image(systemName: "shuffle")
                            .font(.title3)
                            .foregroundStyle(audio.shuffleEnabled ? Color.accentColor : Color.primary)
                    }
                    .accessibilityIdentifier("shuffleButton")

                    Button { audio.previous() } label: {
                        Image(systemName: "backward.fill")
                            .font(.title)
                    }

                    Button { audio.togglePlayPause() } label: {
                        Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }
                    .accessibilityIdentifier("playPauseButton")

                    Button { audio.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }

                    Button { audio.cycleRepeatMode() } label: {
                        Image(systemName: audio.repeatMode.icon)
                            .font(.title3)
                            .foregroundStyle(audio.repeatMode.isActive ? Color.accentColor : Color.primary)
                    }
                    .accessibilityIdentifier("repeatButton")
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3.weight(.semibold))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showUpNext = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                    }
                    .accessibilityIdentifier("upNextButton")
                }
            }
            .sheet(isPresented: $showUpNext) {
                UpNextView()
            }
        }
        .accessibilityIdentifier("nowPlayingView")
    }

    @ViewBuilder
    private var artworkView: some View {
        if let data = audio.currentSong?.artworkData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 16)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                }
                .shadow(radius: 16)
        }
    }
}

