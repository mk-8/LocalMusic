import Foundation

enum RepeatMode: Int, Codable, CaseIterable {
    case off = 0
    case repeatAll = 1
    case repeatOne = 2

    var icon: String {
        switch self {
        case .off:       return "repeat"
        case .repeatAll: return "repeat"
        case .repeatOne: return "repeat.1"
        }
    }

    var isActive: Bool { self != .off }

    func next() -> RepeatMode {
        let all = RepeatMode.allCases
        let idx = (all.firstIndex(of: self)! + 1) % all.count
        return all[idx]
    }
}
