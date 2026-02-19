import Foundation
import Combine

enum SongSortKey: String, CaseIterable, Identifiable {
    case dateAdded = "Date Added"
    case title = "Title"
    case artist = "Artist"

    var id: String { rawValue }

    var coreDataKey: String {
        switch self {
        case .dateAdded: return "dateAdded"
        case .title:     return "title"
        case .artist:    return "artist"
        }
    }
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var searchText = ""
    @Published var sortKey: SongSortKey = .dateAdded
    @Published var isImporting = false
    @Published var importProgress: String?

    private let db = DBService()

    func loadSongs() {
        if searchText.isEmpty {
            let ascending = sortKey != .dateAdded
            songs = db.fetchAllSongs(sortKey: sortKey.coreDataKey, ascending: ascending)
        } else {
            songs = db.searchSongs(query: searchText)
        }
    }

    /// Import files chosen via document picker. Copies to Documents, extracts metadata, saves to DB.
    func importFiles(urls: [URL]) async {
        importProgress = "Importing \(urls.count) file(s)…"
        let docs = AudioService.documentsURL

        for (i, url) in urls.enumerated() {
            // Begin security-scoped access for files from outside the sandbox
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            let destName = uniqueFileName(for: url.lastPathComponent, in: docs)
            let dest = docs.appendingPathComponent(destName)

            do {
                try FileManager.default.copyItem(at: url, to: dest)
            } catch {
                print("Copy failed for \(url.lastPathComponent): \(error)")
                continue
            }

            let meta = await MetadataService.extract(from: dest)
            db.insertSong(
                title: meta.title,
                artist: meta.artist,
                duration: meta.duration,
                artworkData: meta.artworkData,
                fileName: destName
            )
            importProgress = "Imported \(i + 1) of \(urls.count)"
        }

        importProgress = nil
        loadSongs()
    }

    func deleteSong(_ song: Song) {
        if let name = song.fileName {
            let url = AudioService.documentsURL.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: url)
        }
        db.deleteSong(song)
        loadSongs()
    }

    /// Prevents overwriting if a file with the same name already exists.
    private func uniqueFileName(for name: String, in dir: URL) -> String {
        var candidate = name
        var counter = 1
        while FileManager.default.fileExists(atPath: dir.appendingPathComponent(candidate).path) {
            let ext = (name as NSString).pathExtension
            let base = (name as NSString).deletingPathExtension
            candidate = "\(base)_\(counter).\(ext)"
            counter += 1
        }
        return candidate
    }
}
