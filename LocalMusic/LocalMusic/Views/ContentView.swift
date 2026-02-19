import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var audio: AudioService
    @State private var showNowPlaying = false

    var body: some View {
        TabView {
            NavigationStack {
                LibraryView()
            }
            .safeAreaInset(edge: .bottom) {
                if audio.currentSong != nil {
                    MiniPlayerBar(showNowPlaying: $showNowPlaying)
                        .transition(.move(edge: .bottom))
                }
            }
            .tabItem {
                Label("Library", systemImage: "music.note.list")
            }

            NavigationStack {
                PlaylistsView()
            }
            .safeAreaInset(edge: .bottom) {
                if audio.currentSong != nil {
                    MiniPlayerBar(showNowPlaying: $showNowPlaying)
                        .transition(.move(edge: .bottom))
                }
            }
            .tabItem {
                Label("Playlists", systemImage: "list.bullet")
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }
}

/// Compact bar shown above the tab bar when a song is loaded.
struct MiniPlayerBar: View {
    @EnvironmentObject private var audio: AudioService
    @Binding var showNowPlaying: Bool

    var body: some View {
        Button {
            showNowPlaying = true
        } label: {
            HStack(spacing: 12) {
                artworkImage
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(audio.currentSong?.title ?? "Not Playing")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(audio.currentSong?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    audio.togglePlayPause()
                } label: {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                Button {
                    audio.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("miniPlayerBar")
    }

    @ViewBuilder
    private var artworkImage: some View {
        if let data = audio.currentSong?.artworkData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

