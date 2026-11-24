import Foundation
import PencilKit

/// Handwriting on a PDF with Apple Pencil: one drawing per page, kept in a file inside the app's own
/// Documents folder (Annotations/<meeting>/<file>.<modified>.json). The PDF itself is never changed.
///
/// Because the file name includes the PDF's modified time, replacing a deck with a newer version starts
/// with a clean page instead of putting old handwriting on the wrong content. Removing a meeting, or
/// clearing the iPad, removes its handwriting too (see ContentManager).
///
/// Used from the main thread only.
final class MarkupStore {
    private var drawings: [Int: PKDrawing] = [:]
    private var pending: DispatchWorkItem?
    private let url: URL

    init(item: ContentItem) {
        url = MarkupStore.fileURL(for: item)
        if let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(MarkupFile.self, from: data) {
            for (key, blob) in file.pages {
                if let page = Int(key), let drawing = try? PKDrawing(data: blob) {
                    drawings[page] = drawing
                }
            }
        }
    }

    func drawing(for page: Int) -> PKDrawing {
        drawings[page] ?? PKDrawing()
    }

    /// Remembers a page's drawing and saves it a moment later (so drawing stays smooth).
    func set(_ drawing: PKDrawing, for page: Int) {
        if drawing.strokes.isEmpty {
            drawings[page] = nil
        } else {
            drawings[page] = drawing
        }
        scheduleSave()
    }

    /// Writes everything out now. Called when marking stops and when the reader closes.
    func save() {
        pending?.cancel()
        pending = nil
        let fm = FileManager.default
        var file = MarkupFile(pages: [:])
        for (page, drawing) in drawings where !drawing.strokes.isEmpty {
            file.pages[String(page)] = drawing.dataRepresentation()
        }
        if file.pages.isEmpty {
            try? fm.removeItem(at: url)
            return
        }
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func scheduleSave() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    static func fileURL(for item: ContentItem) -> URL {
        let meeting = item.folder.isEmpty ? ".library" : item.folder   // a dot name no meeting can have
        let name = "\(item.fileName).\(Int(item.modified.timeIntervalSince1970)).json"
        return annotationsFolder
            .appendingPathComponent(meeting, isDirectory: true)
            .appendingPathComponent(name)
    }

    /// Documents/Annotations. The library ignores this folder, like Notes.
    static var annotationsFolder: URL {
        ContentManager.documents.appendingPathComponent("Annotations", isDirectory: true)
    }
}

struct MarkupFile: Codable {
    /// Page number (as text) to the PencilKit data for that page.
    var pages: [String: Data]
}
