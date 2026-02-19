import Foundation

@MainActor
final class PlaylistViewModel: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var items: [PlaylistItem] = []

    private let db = DBService()

    func loadPlaylists() {
        playlists = db.fetchAllPlaylists()
    }

    func createPlaylist(name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        db.createPlaylist(name: name)
        loadPlaylists()
    }

    func deletePlaylist(_ playlist: Playlist) {
        db.deletePlaylist(playlist)
        loadPlaylists()
    }

    func renamePlaylist(_ playlist: Playlist, to name: String) {
        db.renamePlaylist(playlist, to: name)
        loadPlaylists()
    }

    func loadItems(for playlist: Playlist) {
        items = db.orderedItems(for: playlist)
    }

    func addSong(_ song: Song, to playlist: Playlist) {
        db.addSong(song, to: playlist)
        loadItems(for: playlist)
    }

    func removeItem(_ item: PlaylistItem, from playlist: Playlist) {
        db.removeItem(item)
        loadItems(for: playlist)
    }

    func moveItems(in playlist: Playlist, from source: IndexSet, to destination: Int) {
        var ordered = items
        ordered.move(fromOffsets: source, toOffset: destination)
        db.reorderItems(ordered)
        loadItems(for: playlist)
    }

    /// Play the playlist starting from a specific item.
    func play(playlist: Playlist, startingAt index: Int = 0) {
        let fileNames = items.compactMap { $0.song?.fileName }
        guard !fileNames.isEmpty else { return }
        AudioService.shared.setQueue(fileNames: fileNames, startIndex: index)
    }
}
