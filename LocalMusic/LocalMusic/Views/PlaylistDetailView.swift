import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist

    @EnvironmentObject private var audio: AudioService
    @StateObject private var vm = PlaylistViewModel()
    @State private var showAddSong = false
    @State private var isEditing = false
    @State private var showRename = false
    @State private var renameText = ""

    var body: some View {
        Group {
            if vm.items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Playlist is empty")
                        .font(.headline)
                    Text("Tap + to add songs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(Array(vm.items.enumerated()), id: \.element.objectID) { index, item in
                        if let song = item.song {
                            SongRowView(song: song)
                                .onTapGesture {
                                    vm.play(playlist: playlist, startingAt: index)
                                }
                                .contextMenu {
                                    if audio.currentSong != nil, let fn = song.fileName {
                                        Button {
                                            audio.playNext(fileName: fn)
                                        } label: {
                                            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                                        }
                                        Button {
                                            audio.addToQueue(fileName: fn)
                                        } label: {
                                            Label("Add to Queue", systemImage: "text.append")
                                        }
                                    }
                                }
                        }
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            vm.removeItem(vm.items[idx], from: playlist)
                        }
                    }
                    .onMove { source, dest in
                        vm.moveItems(in: playlist, from: source, to: dest)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            }
        }
        .navigationTitle(playlist.name ?? "Playlist")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if !vm.items.isEmpty {
                        Button(isEditing ? "Done" : "Edit") {
                            isEditing.toggle()
                        }
                    }
                    Menu {
                        Button {
                            renameText = playlist.name ?? ""
                            showRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button {
                            showAddSong = true
                        } label: {
                            Label("Add Songs", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("playlistMenu")
                }
            }
        }
        .sheet(isPresented: $showAddSong) {
            AddSongsSheet(playlist: playlist, vm: vm)
        }
        .alert("Rename Playlist", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                vm.renamePlaylist(playlist, to: renameText)
            }
        }
        .onAppear { vm.loadItems(for: playlist) }
    }
}

/// Sheet that shows all songs in the library so the user can add them to a playlist.
struct AddSongsSheet: View {
    let playlist: Playlist
    @ObservedObject var vm: PlaylistViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var songs: [Song] = []

    private let db = DBService()

    var body: some View {
        NavigationStack {
            List(songs, id: \.objectID) { song in
                Button {
                    vm.addSong(song, to: playlist)
                } label: {
                    HStack {
                        SongRowView(song: song)
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                songs = db.fetchAllSongs(sortKey: "title", ascending: true)
            }
        }
    }
}
