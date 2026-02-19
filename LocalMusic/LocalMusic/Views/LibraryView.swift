import SwiftUI

struct LibraryView: View {
    @StateObject private var vm = LibraryViewModel()
    @EnvironmentObject private var audio: AudioService
    @State private var showImporter = false
    @State private var showSortPicker = false

    var body: some View {
        Group {
            if vm.songs.isEmpty && vm.searchText.isEmpty {
                emptyState
            } else {
                songList
            }
        }
        .navigationTitle("Library")
        .searchable(text: $vm.searchText, prompt: "Search songs")
        .onChange(of: vm.searchText) { _, _ in vm.loadSongs() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(SongSortKey.allCases) { key in
                        Button {
                            vm.sortKey = key
                            vm.loadSongs()
                        } label: {
                            Label(key.rawValue, systemImage: vm.sortKey == key ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityIdentifier("sortButton")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showImporter = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("importButton")
            }
        }
        .sheet(isPresented: $showImporter) {
            DocumentPicker { urls in
                Task { await vm.importFiles(urls: urls) }
            }
        }
        .overlay {
            if let progress = vm.importProgress {
                VStack {
                    Spacer()
                    Text(progress)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 80)
                }
                .animation(.default, value: progress)
            }
        }
        .onAppear { vm.loadSongs() }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Songs Yet")
                .font(.title2.weight(.semibold))
            Text("Tap + to import MP3 files from your device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Import Music") {
                showImporter = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var songList: some View {
        List {
            ForEach(vm.songs, id: \.objectID) { song in
                SongRowView(song: song)
                    .onTapGesture {
                        let fileNames = vm.songs.compactMap(\.fileName)
                        if let idx = fileNames.firstIndex(of: song.fileName ?? "") {
                            audio.setQueue(fileNames: fileNames, startIndex: idx)
                        }
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            vm.deleteSong(song)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("songsList")
    }
}
