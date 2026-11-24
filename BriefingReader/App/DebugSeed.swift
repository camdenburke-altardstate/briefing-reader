#if DEBUG
import Foundation

/// Debug builds only (this file is not compiled into a Release build).
/// Lets an automated run load a folder of sample content with `-seedFrom /path/to/folder`:
/// loose files go into the Library and each sub-folder becomes a meeting, exactly like the
/// Manage screen does. It does nothing when the app already has content, so a second launch
/// does not duplicate anything.
enum DebugSeed {
    static func run() {
        guard let path = UserDefaults.standard.string(forKey: "seedFrom") else { return }
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(atPath: ContentManager.documents.path)) ?? []
        if existing.contains(where: { !$0.hasPrefix(".") }) { return }

        let root = URL(fileURLWithPath: path, isDirectory: true)
        guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        var loose: [URL] = []
        var folders: [URL] = []
        for entry in entries where !entry.lastPathComponent.hasPrefix(".") {
            var isDirectory: ObjCBool = false
            fm.fileExists(atPath: entry.path, isDirectory: &isDirectory)
            if isDirectory.boolValue { folders.append(entry) } else { loose.append(entry) }
        }
        _ = ContentManager.importFiles(loose, to: .library) { _, _ in }
        for folder in folders { _ = ContentManager.importFolder(folder) { _, _ in } }
    }
}
#endif
