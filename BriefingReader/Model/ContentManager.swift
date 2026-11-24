import Foundation
import CryptoKit

/// Everything the Manage screen does to files on the iPad: bring content in from a USB drive, an
/// SD card reader or the iPad itself, and take it back out. All of it is local, with no network.
///
/// These functions do plain file work and are safe to call off the main thread.
enum ContentManager {
    /// The app's private Documents folder. Top-level files are the Library; each folder is a meeting.
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    enum Destination {
        case library
        /// A meeting folder by name. `create` is written as its meeting.json when the folder is new.
        case meeting(folder: String, create: MeetingInfo?)
    }

    struct ImportResult {
        var added = 0
        var skipped: [String] = []   // file types this app cannot open
        var failed: [String] = []    // could not be copied (drive removed, no space)
    }

    // MARK: Names

    /// A folder or file name that is safe on the iPad and not absurdly long.
    static func safeName(_ raw: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?*\"<>|").union(.controlCharacters)
        let cleaned = raw.components(separatedBy: bad).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))      // no ".." and no hidden folders
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(80))
    }

    /// The name a meeting folder is stored under. "Notes" and "Inbox" are folders the library ignores,
    /// so a meeting called that is renamed rather than silently lost.
    static func meetingFolderName(_ raw: String) -> String {
        var name = safeName(raw)
        if name.isEmpty { name = "Meeting" }
        if ["notes", "inbox", "annotations"].contains(name.lowercased()) { name += " (meeting)" }
        return name
    }

    /// "Plan.pdf" becomes "Plan 2.pdf" if "Plan.pdf" is already there, so nothing is overwritten by accident.
    static func uniqueURL(for name: String, in directory: URL) -> URL {
        let fm = FileManager.default
        var candidate = directory.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var number = 2
        while true {
            let next = ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)"
            candidate = directory.appendingPathComponent(next)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            number += 1
        }
    }

    // MARK: Adding files

    /// Copies picked files into the chosen place. Slow for big videos, so call it off the main thread.
    static func importFiles(
        _ urls: [URL],
        to destination: Destination,
        progress: (_ done: Int, _ total: Int) -> Void
    ) -> ImportResult {
        var result = ImportResult()
        let fm = FileManager.default

        let directory: URL
        switch destination {
        case .library:
            directory = documents
        case .meeting(let folder, let info):
            directory = documents.appendingPathComponent(meetingFolderName(folder), isDirectory: true)
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
            if let info, !fm.fileExists(atPath: directory.appendingPathComponent("meeting.json").path) {
                writeMeeting(info, in: directory)
            }
        }

        for (index, url) in urls.enumerated() {
            progress(index, urls.count)
            let name = url.lastPathComponent
            guard MediaKind(fileExtension: url.pathExtension) != nil else {
                result.skipped.append(name)
                continue
            }
            do {
                try place(url, at: uniqueURL(for: name, in: directory))
                result.added += 1
            } catch {
                result.failed.append(name)
            }
        }
        progress(urls.count, urls.count)
        return result
    }

    /// Brings in a prepared folder from a USB drive. A folder holding files becomes one meeting
    /// (with its meeting.json); a folder holding only sub-folders brings each in as a meeting.
    /// Files with the same name as ones already here are replaced, because this is how you send an update.
    static func importFolder(_ folder: URL, progress: (_ done: Int, _ total: Int) -> Void) -> ImportResult {
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }

        // The app's own Documents folder can show up in the chooser. Importing it would copy a folder
        // onto itself, so refuse before anything is touched.
        let docsPath = documents.resolvingSymlinksInPath().path
        let pickedPath = folder.resolvingSymlinksInPath().path
        if pickedPath == docsPath || pickedPath.hasPrefix(docsPath + "/") {
            return ImportResult(failed: ["That folder is already on this iPad"])
        }

        var result = ImportResult()
        let top = children(of: folder)
        let directFiles = top.filter { !isDirectory($0) }
        let subfolders = top.filter { isDirectory($0) }

        let hasOwnContent = directFiles.contains {
            MediaKind(fileExtension: $0.pathExtension) != nil || $0.lastPathComponent.lowercased() == "meeting.json"
        }

        // (file, meeting folder name; "" = loose in the Library)
        var jobs: [(URL, String)] = []
        if hasOwnContent {
            let name = meetingFolderName(folder.lastPathComponent)
            for file in directFiles { jobs.append((file, name)) }
            for sub in subfolders { for file in children(of: sub) where !isDirectory(file) { jobs.append((file, name)) } }
        } else {
            for sub in subfolders {
                let name = meetingFolderName(sub.lastPathComponent)
                for file in children(of: sub) where !isDirectory(file) { jobs.append((file, name)) }
            }
        }

        let fm = FileManager.default
        for (index, job) in jobs.enumerated() {
            progress(index, jobs.count)
            let (source, meeting) = job
            let name = source.lastPathComponent
            let isAgenda = name.lowercased() == "meeting.json"
            guard isAgenda || MediaKind(fileExtension: source.pathExtension) != nil else {
                result.skipped.append(name)
                continue
            }
            let directory = meeting.isEmpty ? documents : documents.appendingPathComponent(meeting, isDirectory: true)
            do {
                try fm.createDirectory(at: directory, withIntermediateDirectories: true)
                // Copy to a hidden temporary name first. If the drive is pulled halfway, the earlier
                // version of the file is still there; it is only swapped once the copy is complete.
                let target = directory.appendingPathComponent(name)
                let temp = directory.appendingPathComponent(".incoming-\(UUID().uuidString)")
                defer { try? fm.removeItem(at: temp) }
                try fm.copyItem(at: source, to: temp)
                if fm.fileExists(atPath: target.path) {
                    _ = try fm.replaceItemAt(target, withItemAt: temp)
                } else {
                    try fm.moveItem(at: temp, to: target)
                }
                if !isAgenda { result.added += 1 }
            } catch {
                result.failed.append(name)
            }
        }
        progress(jobs.count, jobs.count)
        return result
    }

    static func writeMeeting(_ info: MeetingInfo, in directory: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(info) else { return }
        try? data.write(to: directory.appendingPathComponent("meeting.json"), options: .atomic)
    }

    /// Files the picker already copied into the app's own storage are moved, so a big video is not
    /// stored twice. Anything else, such as a file on a USB drive, is copied and the original is never touched.
    private static func place(_ source: URL, at target: URL) throws {
        let fm = FileManager.default
        let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path
        if source.resolvingSymlinksInPath().path.hasPrefix(home) {
            try fm.moveItem(at: source, to: target)
        } else {
            try fm.copyItem(at: source, to: target)
        }
    }

    /// Throws away the temporary copies of files that were picked but never added (the person cancelled).
    static func discard(_ urls: [URL]) {
        let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path
        for url in urls where url.resolvingSymlinksInPath().path.hasPrefix(home) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: Removing

    /// Removes one meeting folder and the notes typed for it. folder "" means the loose Library files.
    static func removeMeeting(folder: String) {
        let handwriting = MarkupStore.annotationsFolder.appendingPathComponent(folder.isEmpty ? ".library" : folder, isDirectory: true)
        try? FileManager.default.removeItem(at: handwriting)
        if folder.isEmpty {
            removeLooseFiles()
            try? FileManager.default.removeItem(at: NotesFile.url(forFolder: ""))
            return
        }
        try? FileManager.default.removeItem(at: documents.appendingPathComponent(folder, isDirectory: true))
        try? FileManager.default.removeItem(at: NotesFile.url(forFolder: folder))
    }

    static func removeLooseFiles() {
        let fm = FileManager.default
        for url in children(of: documents) where !isDirectory(url) && MediaKind(fileExtension: url.pathExtension) != nil {
            try? fm.removeItem(at: url)
        }
    }

    /// Removes every meeting dated before today. Returns how many were removed.
    @discardableResult
    static func removeFinishedMeetings(from collections: [ContentCollection]) -> Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        var removed = 0
        for collection in collections where !collection.folder.isEmpty {
            if let day = collection.meeting?.day, day < startOfToday {
                removeMeeting(folder: collection.folder)
                removed += 1
            }
        }
        return removed
    }

    /// Empties the iPad for the next meeting: every document, photo, video, note and meeting folder.
    static func wipeEverything() {
        let fm = FileManager.default
        let all = (try? fm.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil, options: [])) ?? []
        for url in all { try? fm.removeItem(at: url) }
    }

    // MARK: Sizes

    /// Bytes used by one meeting folder, or by the loose files when folder is "".
    static func bytes(inFolder folder: String) -> Int64 {
        if folder.isEmpty {
            return children(of: documents)
                .filter { !isDirectory($0) }
                .reduce(Int64(0)) { $0 + fileSize($1) }
        }
        let root = documents.appendingPathComponent(folder, isDirectory: true)
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in walker { total += fileSize(url) }
        return total
    }

    static func freeSpaceBytes() -> Int64? {
        let values = try? documents.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    // MARK: Helpers

    private static func children(of directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles])) ?? []
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    private static func fileSize(_ url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }
}

/// An optional PIN that must be entered to open the Manage screen, so only the person who sets up
/// the iPads can add or wipe content. It deters casual use; it is not strong protection against
/// someone with the iPad in hand. A forgotten PIN is cleared by erasing the iPad from the Mac.
enum ManagePIN {
    private static let hashKey = "manage.pin.hash"
    private static let saltKey = "manage.pin.salt"
    private static let failKey = "manage.pin.failures"
    private static let lockKey = "manage.pin.lockedUntil"

    static var isSet: Bool { UserDefaults.standard.string(forKey: hashKey) != nil }

    static func set(_ pin: String) {
        let salt = UUID().uuidString
        UserDefaults.standard.set(salt, forKey: saltKey)
        UserDefaults.standard.set(digest(pin, salt: salt), forKey: hashKey)
    }

    static func verify(_ pin: String) -> Bool {
        guard let salt = UserDefaults.standard.string(forKey: saltKey),
              let stored = UserDefaults.standard.string(forKey: hashKey) else { return true }
        return digest(pin, salt: salt) == stored
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: hashKey)
        UserDefaults.standard.removeObject(forKey: saltKey)
    }

    /// While set and in the future, PIN tries are refused. Kept on the iPad so closing and reopening
    /// the screen does not reset it.
    static var lockedUntil: Date? { UserDefaults.standard.object(forKey: lockKey) as? Date }

    /// Counts a wrong PIN. After five in a row the screen is locked for 30 seconds.
    static func recordFailure() {
        let count = UserDefaults.standard.integer(forKey: failKey) + 1
        if count >= 5 {
            UserDefaults.standard.set(0, forKey: failKey)
            UserDefaults.standard.set(Date().addingTimeInterval(30), forKey: lockKey)
        } else {
            UserDefaults.standard.set(count, forKey: failKey)
        }
    }

    static func resetFailures() {
        UserDefaults.standard.set(0, forKey: failKey)
        UserDefaults.standard.removeObject(forKey: lockKey)
    }

    private static func digest(_ pin: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + pin).utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
