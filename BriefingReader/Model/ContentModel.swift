import Foundation

// MARK: - Content types

enum MediaKind: String, Codable, Hashable {
    case pdf, image, video, audio

    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "pdf": self = .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "tif", "tiff", "webp": self = .image
        case "mp4", "mov", "m4v": self = .video
        case "mp3", "m4a", "wav", "aac": self = .audio
        default: return nil
        }
    }
}

struct ContentItem: Identifiable, Hashable {
    let url: URL
    let kind: MediaKind
    let title: String
    /// Pages for a PDF, seconds for video and audio, 1 for an image.
    let measure: Int
    let modified: Date
    /// The meeting folder this file sits in. Empty for files at the top level.
    let folder: String

    /// Includes the modified time so a replaced file is treated as new
    /// (reading position starts again and the cover is regenerated).
    var id: String { Self.makeID(folder: folder, fileName: url.lastPathComponent, modified: modified) }
    var fileName: String { url.lastPathComponent }

    static func makeID(folder: String, fileName: String, modified: Date) -> String {
        "\(folder)/\(fileName)|\(Int(modified.timeIntervalSince1970))"
    }
}

/// A meeting folder, or the loose files at the top level ("Library").
struct ContentCollection: Identifiable, Hashable {
    let folder: String
    let title: String
    let items: [ContentItem]
    let meeting: MeetingInfo?

    var id: String { folder.isEmpty ? "__library__" : folder }

    func sortKey(today: Date) -> CollectionSortKey {
        AgendaLogic.key(day: meeting?.day, title: title, isRoot: folder.isEmpty, today: today)
    }
}

// MARK: - meeting.json

/// Optional file named meeting.json inside a meeting folder:
///
///     { "title": "Board Meeting", "date": "2026-12-08", "time": "9:00 AM",
///       "location": "Boardroom", "confidential": true, "note": "Pre-read first",
///       "agenda": [ { "time": "9:00 AM", "title": "Welcome", "presenter": "CEO",
///                     "file": "Q4 Board Book.pdf" } ] }
///
/// Every field is optional. "file" is a file name inside the same folder.
struct AgendaItem: Codable, Hashable {
    var time: String?
    var title: String
    var presenter: String?
    var file: String?
}

struct MeetingInfo: Codable, Hashable {
    var title: String?
    var date: String?
    var time: String?
    var location: String?
    var confidential: Bool?
    var note: String?
    var agenda: [AgendaItem]?

    static func load(from url: URL) -> MeetingInfo? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MeetingInfo.self, from: data)
    }

    /// The meeting date at local midnight, from "yyyy-MM-dd".
    var day: Date? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var isToday: Bool {
        guard let day else { return false }
        return Calendar.current.isDateInToday(day)
    }

    /// "Mon, Dec 8  ·  9:00 AM  ·  Boardroom"
    var subtitle: String {
        var parts: [String] = []
        if let day {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            parts.append(isToday ? "Today" : formatter.string(from: day))
        }
        if let time, !time.isEmpty { parts.append(time) }
        if let location, !location.isEmpty { parts.append(location) }
        return parts.joined(separator: "  ·  ")
    }
}

// MARK: - Pure logic (Foundation only, so it can be tested anywhere)

struct CollectionSortKey {
    var rank: Int
    var day: Date?
    var title: String
}

enum AgendaLogic {
    /// "09:00", "9:30 AM", "2pm", "14:05" to minutes since midnight. nil when it cannot be read.
    static func minutes(from text: String?) -> Int? {
        guard var s = text?.trimmingCharacters(in: .whitespaces).lowercased(), !s.isEmpty else { return nil }
        var pm = false
        var am = false
        if s.hasSuffix("pm") { pm = true; s.removeLast(2) }
        else if s.hasSuffix("am") { am = true; s.removeLast(2) }
        s = s.trimmingCharacters(in: .whitespaces)

        let parts = s.split(separator: ":")
        guard let first = parts.first, var hour = Int(first) else { return nil }
        let minute = parts.count > 1 ? Int(parts[1]) : 0
        guard let minute, (0..<60).contains(minute), (0...24).contains(hour) else { return nil }
        if pm && hour < 12 { hour += 12 }
        if am && hour == 12 { hour = 0 }
        return hour * 60 + minute
    }

    struct Position: Equatable {
        var now: Int?
        var next: Int?
    }

    /// Which agenda line is under way and which is next, given each line's start time in minutes
    /// (in agenda order). A line with no readable time is skipped.
    static func position(times: [Int?], nowMinutes: Int) -> Position {
        var now: Int?
        var next: Int?
        for (index, time) in times.enumerated() {
            guard let time else { continue }
            if time <= nowMinutes {
                now = index
            } else if next == nil {
                next = index
            }
        }
        return Position(now: now, next: next)
    }

    /// Meetings today or later first (soonest first), then past meetings (newest first),
    /// then folders with no date (by name), then the loose-files library.
    static func key(day: Date?, title: String, isRoot: Bool, today: Date, calendar: Calendar = .current) -> CollectionSortKey {
        if isRoot { return CollectionSortKey(rank: 3, day: nil, title: title) }
        guard let day else { return CollectionSortKey(rank: 2, day: nil, title: title) }
        let startOfToday = calendar.startOfDay(for: today)
        return CollectionSortKey(rank: day >= startOfToday ? 0 : 1, day: day, title: title)
    }

    static func areInOrder(_ a: CollectionSortKey, _ b: CollectionSortKey) -> Bool {
        if a.rank != b.rank { return a.rank < b.rank }
        if let da = a.day, let db = b.day, da != db {
            return a.rank == 0 ? da < db : da > db
        }
        return a.title.localizedStandardCompare(b.title) == .orderedAscending
    }

    /// 75 -> "1:15", 3725 -> "1:02:05"
    static func clock(seconds: Int) -> String {
        let total = max(seconds, 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%ld:%02ld:%02ld", h, m, s) : String(format: "%ld:%02ld", m, s)
    }
}
