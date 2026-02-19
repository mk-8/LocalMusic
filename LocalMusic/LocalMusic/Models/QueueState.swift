import Foundation

/// Persisted to UserDefaults so playback can resume on next launch.
struct QueueState: Codable {
    var songFileNames: [String]
    var currentIndex: Int
    var elapsedSeconds: Double
    var shuffleEnabled: Bool
    var repeatMode: RepeatMode

    static let defaultsKey = "com.localmusic.queueState"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    static func load() -> QueueState? {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey) else { return nil }
        return try? JSONDecoder().decode(QueueState.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
    }
}
