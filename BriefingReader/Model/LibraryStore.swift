import Foundation
import PDFKit
import AVFoundation
import ImageIO
import SwiftUI

struct ReadingProgress: Codable {
    /// Page for a PDF; seconds into playback for video and audio.
    var page: Int
    var opened: Date
    var flags: [Int]?
}

private let ignoredMeetingFolders: Set<String> = ["notes", "inbox", "annotations"]

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var collections: [ContentCollection] = []

    /// What the library screen shows. Only refreshed by commitProgress(), so turning pages in a
    /// long document does not make SwiftUI redraw every screen on every flip.
    @Published private(set) var progress: [String: ReadingProgress] = [:]

    private var working: [String: ReadingProgress] = [:]   // always up to date
    private var measures: [String: Int] = [:]              // remembered so big files are not reopened
    private var signature = ""
    private var persistTask: Task<Void, Never>?

    private let progressKey = "readingProgress.v2"
    private let measuresKey = "measures.v2"

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: progressKey),
           let saved = try? JSONDecoder().decode([String: ReadingProgress].self, from: data) {
            working = saved
            progress = saved
        }
        if let data = defaults.data(forKey: measuresKey),
           let saved = try? JSONDecoder().decode([String: Int].self, from: data) {
            measures = saved
        }
        refresh(force: true)
    }

    var itemCount: Int { collections.reduce(0) { $0 + $1.items.count } }

    // MARK: Folder scanning

    /// The app's Documents folder. Finder file sharing writes here.
    /// Top-level files form the "Library"; each folder is a meeting.
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Rescans the folders. Cheap when nothing changed: it compares a name/size/date signature
    /// first, and it never reopens a file whose length it already knows (opening a 100MB+ PDF or
    /// a long video is the slow part).
    func refresh(force: Bool = false) {
        let root = Self.documentsDirectory
        let previous = force ? nil : signature
        let known = measures
        Task { [self] in
            let result = await Task.detached(priority: .utility) { () -> (String, [ContentCollection], Set<String>)? in
                let sig = Self.signature(of: root)
                if sig == previous { return nil }
                return (sig, Self.scan(root: root, known: known), Self.presentIDs(in: root))
            }.value
            if let (sig, found, present) = result {
                signature = sig
                collections = found
                var fresh: [String: Int] = [:]
                for collection in found {
                    for item in collection.items { fresh[item.id] = item.measure }
                }
                measures = fresh
                // Keep progress for every file that is still on disk, even one that is mid-copy and
                // not readable yet; only files that are really gone lose their position.
                prune(keeping: present)
                persistMeasures()
            }
        }
    }

    private nonisolated static func entries(in directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles])) ?? []
    }

    private nonisolated static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    private nonisolated static func describe(_ url: URL, prefix: String) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let time = Int(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
        return "\(prefix)/\(url.lastPathComponent):\(values?.fileSize ?? 0):\(time)"
    }

    private nonisolated static func signature(of root: URL) -> String {
        var parts: [String] = []
        for url in entries(in: root) {
            if isDirectory(url) {
                guard !ignoredMeetingFolders.contains(url.lastPathComponent.lowercased()) else { continue }
                for inner in entries(in: url) where !isDirectory(inner) {
                    parts.append(describe(inner, prefix: url.lastPathComponent))
                }
            } else {
                parts.append(describe(url, prefix: ""))
            }
        }
        return parts.sorted().joined(separator: "|")
    }

    /// The id of every supported file on disk, whether or not it could be opened right now.
    private nonisolated static func presentIDs(in root: URL) -> Set<String> {
        var ids = Set<String>()
        func add(_ url: URL, folder: String) {
            guard MediaKind(fileExtension: url.pathExtension) != nil else { return }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            ids.insert(ContentItem.makeID(folder: folder, fileName: url.lastPathComponent, modified: modified))
        }
        for url in entries(in: root) {
            if isDirectory(url) {
                guard !ignoredMeetingFolders.contains(url.lastPathComponent.lowercased()) else { continue }
                for inner in entries(in: url) where !isDirectory(inner) { add(inner, folder: url.lastPathComponent) }
            } else {
                add(url, folder: "")
            }
        }
        return ids
    }

    private nonisolated static func scan(root: URL, known: [String: Int]) -> [ContentCollection] {
        var result: [ContentCollection] = []

        let loose = items(in: root, folder: "", known: known)
        if !loose.isEmpty {
            result.append(ContentCollection(folder: "", title: "Library", items: loose, meeting: nil))
        }

        for url in entries(in: root) where isDirectory(url) {
            let name = url.lastPathComponent
            guard !ignoredMeetingFolders.contains(name.lowercased()) else { continue }
            let found = items(in: url, folder: name, known: known)
            let meeting = MeetingInfo.load(from: url.appendingPathComponent("meeting.json"))
            if found.isEmpty && meeting == nil { continue }
            result.append(ContentCollection(folder: name, title: meeting?.title ?? name, items: found, meeting: meeting))
        }

        let today = Date()
        return result.sorted { AgendaLogic.areInOrder($0.sortKey(today: today), $1.sortKey(today: today)) }
    }

    private nonisolated static func items(in directory: URL, folder: String, known: [String: Int]) -> [ContentItem] {
        entries(in: directory).compactMap { url -> ContentItem? in
            guard !isDirectory(url), let kind = MediaKind(fileExtension: url.pathExtension) else { return nil }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let id = ContentItem.makeID(folder: folder, fileName: url.lastPathComponent, modified: modified)

            let length: Int
            if let cached = known[id], cached > 0 {
                length = cached
            } else if let fresh = Self.measure(of: url, kind: kind) {
                length = fresh
            } else {
                // Still being copied, locked with a password, or not playable. Skipped for now;
                // the signature changes when a copy finishes, so the next refresh picks it up.
                return nil
            }
            return ContentItem(
                url: url,
                kind: kind,
                title: url.deletingPathExtension().lastPathComponent,
                measure: length,
                modified: modified,
                folder: folder)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private nonisolated static func measure(of url: URL, kind: MediaKind) -> Int? {
        switch kind {
        case .pdf:
            guard let pdf = PDFDocument(url: url), !pdf.isLocked, pdf.pageCount > 0 else { return nil }
            return pdf.pageCount
        case .image:
            return CGImageSourceCreateWithURL(url as CFURL, nil) == nil ? nil : 1
        case .video, .audio:
            let asset = AVURLAsset(url: url)
            guard asset.isPlayable else { return nil }
            let seconds = CMTimeGetSeconds(asset.duration)
            return seconds.isFinite && seconds > 0 ? max(Int(seconds.rounded()), 1) : nil
        }
    }

    // MARK: Reading progress

    func savedPage(for item: ContentItem) -> Int {
        min(max(working[item.id]?.page ?? 0, 0), max(item.measure - 1, 0))
    }

    func savedSeconds(for item: ContentItem) -> Int {
        min(max(working[item.id]?.page ?? 0, 0), item.measure)
    }

    /// For the library cards: reads the published copy so cards refresh when the viewer closes.
    func resume(for item: ContentItem) -> ReadingProgress? {
        progress[item.id]
    }

    func lastOpened(for item: ContentItem) -> Date? {
        progress[item.id]?.opened
    }

    func markOpened(_ item: ContentItem) {
        var entry = working[item.id] ?? ReadingProgress(page: 0, opened: Date(), flags: nil)
        entry.opened = Date()
        working[item.id] = entry
        schedulePersist()
    }

    /// Called on every page change or playback tick. Writes are batched: nothing is published and
    /// storage is touched at most once every 0.7 seconds, however fast pages are turned.
    func savePage(_ page: Int, for item: ContentItem) {
        var entry = working[item.id] ?? ReadingProgress(page: 0, opened: Date(), flags: nil)
        entry.page = page
        working[item.id] = entry
        schedulePersist()
    }

    func flags(for item: ContentItem) -> [Int] {
        (working[item.id]?.flags ?? []).sorted()
    }

    func toggleFlag(_ page: Int, for item: ContentItem) {
        var entry = working[item.id] ?? ReadingProgress(page: 0, opened: Date(), flags: nil)
        var list = entry.flags ?? []
        if let index = list.firstIndex(of: page) {
            list.remove(at: index)
        } else {
            list.append(page)
        }
        entry.flags = list
        working[item.id] = entry
        schedulePersist()
    }

    /// Called when a viewer closes and when the app goes to the background.
    func commitProgress() {
        progress = working
        persistTask?.cancel()
        persistNow()
    }

    private func prune(keeping live: Set<String>) {
        let trimmed = working.filter { live.contains($0.key) }
        if trimmed.count != working.count {
            working = trimmed
            progress = trimmed
            persistNow()
        }
    }

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.persistNow()
        }
    }

    private func persistNow() {
        if let data = try? JSONEncoder().encode(working) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    private func persistMeasures() {
        if let data = try? JSONEncoder().encode(measures) {
            UserDefaults.standard.set(data, forKey: measuresKey)
        }
    }
}
