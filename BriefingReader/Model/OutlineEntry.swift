import PDFKit

/// One row of a deck's table of contents, flattened so it can be shown in a plain list.
struct OutlineEntry: Identifiable {
    let id = UUID()
    let label: String
    let depth: Int
    let pageIndex: Int

    /// Walks the PDF's bookmark tree. Entries that do not point at a page are skipped.
    /// Capped so a malformed file cannot build an enormous list.
    static func entries(for document: PDFDocument, limit: Int = 1500) -> [OutlineEntry] {
        guard let root = document.outlineRoot else { return [] }
        var result: [OutlineEntry] = []
        collect(root, in: document, depth: 0, into: &result, limit: limit)
        return result
    }

    private static func collect(
        _ node: PDFOutline,
        in document: PDFDocument,
        depth: Int,
        into result: inout [OutlineEntry],
        limit: Int
    ) {
        for i in 0..<node.numberOfChildren {
            guard result.count < limit, depth < 8, let child = node.child(at: i) else { return }

            let page = child.destination?.page ?? (child.action as? PDFActionGoTo)?.destination.page
            if let page, let label = child.label, !label.isEmpty {
                result.append(OutlineEntry(label: label, depth: depth, pageIndex: document.index(for: page)))
            }
            collect(child, in: document, depth: depth + 1, into: &result, limit: limit)
        }
    }
}
