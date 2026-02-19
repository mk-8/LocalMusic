import SwiftUI

struct PlaylistsView: View {
    @StateObject private var vm = PlaylistViewModel()
    @State private var showCreateAlert = false
    @State private var newPlaylistName = ""

    var body: some View {
        Group {
            if vm.playlists.isEmpty {
                emptyState
            } else {
                playlistList
            }
        }
        .navigationTitle("Playlists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newPlaylistName = ""
                    showCreateAlert = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("createPlaylistButton")
            }
        }
        .alert("New Playlist", isPresented: $showCreateAlert) {
            TextField("Playlist Name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                vm.createPlaylist(name: newPlaylistName)
            }
        }
        .onAppear { vm.loadPlaylists() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Playlists")
                .font(.title2.weight(.semibold))
            Text("Tap + to create your first playlist.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var playlistList: some View {
        List {
            ForEach(vm.playlists, id: \.objectID) { playlist in
                NavigationLink {
                    PlaylistDetailView(playlist: playlist)
                } label: {
                    HStack {
                        Image(systemName: "music.note.list")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name ?? "Untitled")
                                .font(.body.weight(.medium))
                            let count = playlist.items?.count ?? 0
                            Text("\(count) song\(count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        vm.deletePlaylist(playlist)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
