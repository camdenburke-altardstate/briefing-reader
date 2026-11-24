import SwiftUI
import PDFKit

/// "Find the number I need" across every document on the iPad. Searches the text inside each PDF and
/// the names of photos, videos and recordings. Runs on the iPad, offline. Opens the result on its page.
struct LibrarySearchView: View {
    /// Called with the document, its meeting, and the page to open (nil for a photo or video).
    let onOpen: (ContentItem, ContentCollection, Int?) -> Void

    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var groups: [SearchGroup] = []
    @State private var searching = false
    @State private var searched = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Brand.inkSecondary)
                    TextField("Search every document on this iPad", text: $query)
                        .font(Brand.font(.book, 19, .body))
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { start() }
                    if searching { ProgressView() }
                }
                .padding(18)
                Divider()

                if groups.isEmpty {
                    Text(message)
                        .font(Brand.font(.light, 20, .title3))
                        .foregroundStyle(Brand.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groups) { group in
                            Section {
                                ForEach(group.hits) { hit in
                                    Button { open(hit) } label: { row(hit) }
                                        .buttonStyle(.plain)
                                }
                            } header: {
                                Text(group.item.title)
                                    .font(Brand.font(.medium, 15, .subheadline))
                                    .foregroundStyle(Brand.ink)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { task?.cancel(); dismiss() }
                }
            }
        }
        .onDisappear { task?.cancel() }
    }

    private var message: String {
        if searching { return "Searching…" }
        return searched ? "No matches" : "Type a word, a name or a number, then press Search."
    }

    private func row(_ hit: SearchHit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let page = hit.page {
                Text("Page \(page + 1)")
                    .font(Brand.font(.medium, 15, .subheadline))
                    .foregroundStyle(Brand.ink)
            } else {
                Text(hit.item.kind == .image ? "Photo" : "Title matches")
                    .font(Brand.font(.medium, 15, .subheadline))
                    .foregroundStyle(Brand.ink)
            }
            if !hit.snippet.isEmpty {
                Text(hit.snippet)
                    .font(Brand.font(.book, 16, .body))
                    .foregroundStyle(Brand.inkSecondary)
                    .lineLimit(2)
            }
        }
    }

    private func open(_ hit: SearchHit) {
        guard let collection = store.collection(containing: hit.item) else { return }
        task?.cancel()
        onOpen(hit.item, collection, hit.page)
    }

    private func start() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return }
        task?.cancel()
        groups = []
        searching = true
        searched = false
        let items = store.collections.flatMap(\.items)

        task = Task {
            var total = 0
            for item in items {
                if Task.isCancelled || total >= 200 { break }
                let hits = await Task.detached(priority: .userInitiated) { LibrarySearchEngine.search(item, for: text) }.value
                if Task.isCancelled { break }
                if !hits.isEmpty {
                    groups.append(SearchGroup(item: item, hits: hits))
                    total += hits.count
                }
            }
            if !Task.isCancelled {
                searching = false
                searched = true
            }
        }
    }
}

/// The search itself, kept outside the view so it can run on a background thread.
enum LibrarySearchEngine {
    /// Looks inside one PDF (first 25 matches) or matches the name of a photo, video or recording.
    static func search(_ item: ContentItem, for text: String) -> [SearchHit] {
        switch item.kind {
        case .pdf:
            guard let doc = PDFDocument(url: item.url), !doc.isLocked else { return [] }
            let selections = doc.findString(text, withOptions: .caseInsensitive)
            return selections.prefix(25).compactMap { selection -> SearchHit? in
                guard let page = selection.pages.first else { return nil }
                let context = selection.copy() as? PDFSelection
                context?.extend(atStart: 30)
                context?.extend(atEnd: 60)
                let snippet = (context?.string ?? selection.string ?? text).replacingOccurrences(of: "
", with: " ")
                return SearchHit(item: item, page: doc.index(for: page), snippet: snippet)
            }
        case .image, .video, .audio:
            return item.title.range(of: text, options: .caseInsensitive) != nil
                ? [SearchHit(item: item, page: nil, snippet: "")]
                : []
        }
    }
}

struct SearchHit: Identifiable {
    let id = UUID()
    let item: ContentItem
    let page: Int?
    let snippet: String
}

struct SearchGroup: Identifiable {
    let id = UUID()
    let item: ContentItem
    var hits: [SearchHit]
}
