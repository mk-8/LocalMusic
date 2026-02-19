import CoreData
import Foundation

/// CRUD operations for Song, Playlist, and PlaylistItem entities.
final class DBService {
    let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    private var context: NSManagedObjectContext { stack.context }

    // MARK: - Song

    @discardableResult
    func insertSong(
        title: String,
        artist: String,
        duration: Double,
        artworkData: Data?,
        fileName: String
    ) -> Song {
        let song = Song(context: context)
        song.id = UUID()
        song.title = title
        song.artist = artist
        song.duration = duration
        song.artworkData = artworkData
        song.fileName = fileName
        song.dateAdded = Date()
        stack.save()
        return song
    }

    func fetchAllSongs(sortKey: String = "dateAdded", ascending: Bool = false) -> [Song] {
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: ascending)]
        return (try? context.fetch(request)) ?? []
    }

    func searchSongs(query: String) -> [Song] {
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        request.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR artist CONTAINS[cd] %@", query, query
        )
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func song(byFileName name: String) -> Song? {
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        request.predicate = NSPredicate(format: "fileName == %@", name)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    func deleteSong(_ song: Song) {
        context.delete(song)
        stack.save()
    }

    // MARK: - Playlist

    @discardableResult
    func createPlaylist(name: String) -> Playlist {
        let playlist = Playlist(context: context)
        playlist.id = UUID()
        playlist.name = name
        playlist.dateCreated = Date()
        stack.save()
        return playlist
    }

    func fetchAllPlaylists() -> [Playlist] {
        let request: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func renamePlaylist(_ playlist: Playlist, to name: String) {
        playlist.name = name
        stack.save()
    }

    func deletePlaylist(_ playlist: Playlist) {
        context.delete(playlist)
        stack.save()
    }

    // MARK: - PlaylistItem

    /// Adds a song to a playlist. The same song can appear multiple times.
    @discardableResult
    func addSong(_ song: Song, to playlist: Playlist) -> PlaylistItem {
        let maxOrder = orderedItems(for: playlist).last?.orderIndex ?? -1
        let item = PlaylistItem(context: context)
        item.id = UUID()
        item.orderIndex = maxOrder + 1
        item.song = song
        item.playlist = playlist
        stack.save()
        return item
    }

    func orderedItems(for playlist: Playlist) -> [PlaylistItem] {
        let request: NSFetchRequest<PlaylistItem> = PlaylistItem.fetchRequest()
        request.predicate = NSPredicate(format: "playlist == %@", playlist)
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func removeItem(_ item: PlaylistItem) {
        context.delete(item)
        stack.save()
    }

    /// Reorder items by writing consecutive orderIndex values.
    func reorderItems(_ items: [PlaylistItem]) {
        for (idx, item) in items.enumerated() {
            item.orderIndex = Int16(idx)
        }
        stack.save()
    }
}
