import XCTest
import CoreData
@testable import LocalMusic

final class DBServiceTests: XCTestCase {
    var stack: CoreDataStack!
    var db: DBService!

    override func setUp() {
        super.setUp()
        stack = CoreDataStack(inMemory: true)
        db = DBService(stack: stack)
    }

    override func tearDown() {
        db = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - Song Tests

    func testInsertAndFetchSong() {
        let song = db.insertSong(
            title: "Test Song",
            artist: "Test Artist",
            duration: 180,
            artworkData: nil,
            fileName: "test.mp3"
        )

        XCTAssertNotNil(song.id)
        XCTAssertEqual(song.title, "Test Song")
        XCTAssertEqual(song.artist, "Test Artist")
        XCTAssertEqual(song.duration, 180)

        let all = db.fetchAllSongs()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.fileName, "test.mp3")
    }

    func testSearchSongs() {
        db.insertSong(title: "Bohemian Rhapsody", artist: "Queen", duration: 354, artworkData: nil, fileName: "bohemian.mp3")
        db.insertSong(title: "Stairway to Heaven", artist: "Led Zeppelin", duration: 482, artworkData: nil, fileName: "stairway.mp3")
        db.insertSong(title: "Hotel California", artist: "Eagles", duration: 391, artworkData: nil, fileName: "hotel.mp3")

        let results = db.searchSongs(query: "Queen")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Bohemian Rhapsody")

        let titleSearch = db.searchSongs(query: "Hotel")
        XCTAssertEqual(titleSearch.count, 1)
    }

    func testSongByFileName() {
        db.insertSong(title: "A", artist: "B", duration: 100, artworkData: nil, fileName: "a.mp3")
        let found = db.song(byFileName: "a.mp3")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "A")
        XCTAssertNil(db.song(byFileName: "nonexistent.mp3"))
    }

    func testDeleteSong() {
        let song = db.insertSong(title: "Del", artist: "X", duration: 60, artworkData: nil, fileName: "del.mp3")
        XCTAssertEqual(db.fetchAllSongs().count, 1)
        db.deleteSong(song)
        XCTAssertEqual(db.fetchAllSongs().count, 0)
    }

    func testSortOrder() {
        db.insertSong(title: "Zebra", artist: "A", duration: 100, artworkData: nil, fileName: "z.mp3")
        db.insertSong(title: "Apple", artist: "B", duration: 100, artworkData: nil, fileName: "a.mp3")

        let byTitle = db.fetchAllSongs(sortKey: "title", ascending: true)
        XCTAssertEqual(byTitle.first?.title, "Apple")
        XCTAssertEqual(byTitle.last?.title, "Zebra")
    }

    // MARK: - Playlist Tests

    func testCreateAndFetchPlaylist() {
        let pl = db.createPlaylist(name: "Favourites")
        XCTAssertNotNil(pl.id)
        XCTAssertEqual(pl.name, "Favourites")

        let all = db.fetchAllPlaylists()
        XCTAssertEqual(all.count, 1)
    }

    func testRenamePlaylist() {
        let pl = db.createPlaylist(name: "Old Name")
        db.renamePlaylist(pl, to: "New Name")
        XCTAssertEqual(pl.name, "New Name")
    }

    func testDeletePlaylist() {
        let pl = db.createPlaylist(name: "Temp")
        db.deletePlaylist(pl)
        XCTAssertEqual(db.fetchAllPlaylists().count, 0)
    }

    // MARK: - PlaylistItem Tests

    func testAddSongToPlaylist() {
        let song = db.insertSong(title: "S1", artist: "A", duration: 100, artworkData: nil, fileName: "s1.mp3")
        let pl = db.createPlaylist(name: "PL")
        db.addSong(song, to: pl)

        let items = db.orderedItems(for: pl)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.song?.title, "S1")
    }

    func testDuplicateSongInPlaylist() {
        let song = db.insertSong(title: "S1", artist: "A", duration: 100, artworkData: nil, fileName: "s1.mp3")
        let pl = db.createPlaylist(name: "PL")
        db.addSong(song, to: pl)
        db.addSong(song, to: pl)

        let items = db.orderedItems(for: pl)
        XCTAssertEqual(items.count, 2, "Same song should appear twice")
        XCTAssertEqual(items[0].orderIndex, 0)
        XCTAssertEqual(items[1].orderIndex, 1)
    }

    func testReorderItems() {
        let s1 = db.insertSong(title: "A", artist: "A", duration: 100, artworkData: nil, fileName: "a.mp3")
        let s2 = db.insertSong(title: "B", artist: "B", duration: 100, artworkData: nil, fileName: "b.mp3")
        let s3 = db.insertSong(title: "C", artist: "C", duration: 100, artworkData: nil, fileName: "c.mp3")
        let pl = db.createPlaylist(name: "PL")
        db.addSong(s1, to: pl)
        db.addSong(s2, to: pl)
        db.addSong(s3, to: pl)

        var items = db.orderedItems(for: pl)
        // Reverse order: C, B, A
        items.reverse()
        db.reorderItems(items)

        let reordered = db.orderedItems(for: pl)
        XCTAssertEqual(reordered[0].song?.title, "C")
        XCTAssertEqual(reordered[1].song?.title, "B")
        XCTAssertEqual(reordered[2].song?.title, "A")
    }

    func testRemoveItem() {
        let song = db.insertSong(title: "S", artist: "A", duration: 100, artworkData: nil, fileName: "s.mp3")
        let pl = db.createPlaylist(name: "PL")
        let item = db.addSong(song, to: pl)
        XCTAssertEqual(db.orderedItems(for: pl).count, 1)
        db.removeItem(item)
        XCTAssertEqual(db.orderedItems(for: pl).count, 0)
    }

    /// Deleting a song cascades to its playlist items.
    func testDeleteSongCascadesToPlaylistItems() {
        let song = db.insertSong(title: "S", artist: "A", duration: 100, artworkData: nil, fileName: "s.mp3")
        let pl = db.createPlaylist(name: "PL")
        db.addSong(song, to: pl)
        XCTAssertEqual(db.orderedItems(for: pl).count, 1)
        db.deleteSong(song)
        XCTAssertEqual(db.orderedItems(for: pl).count, 0)
    }
}
