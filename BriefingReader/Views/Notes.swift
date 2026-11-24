import SwiftUI

/// Meeting notes are plain text files in the app's Documents/Notes folder, one per meeting
/// (or "Library" for loose files). IT can copy them off through Finder file sharing.
enum NotesFile {
    private static var folder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notes", isDirectory: true)
    }

    static func url(forFolder name: String) -> URL {
        let base = name.isEmpty ? "Library" : name
        let bad = CharacterSet(charactersIn: "/\\:?*\"<>|")
        let safe = base.components(separatedBy: bad).joined(separator: "-")
        return folder.appendingPathComponent(safe + ".txt")
    }

    static func load(folder name: String) -> String {
        (try? String(contentsOf: url(forFolder: name), encoding: .utf8)) ?? ""
    }

    static func save(_ text: String, folder name: String) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? text.write(to: url(forFolder: name), atomically: true, encoding: .utf8)
    }
}

struct NotesView: View {
    let collection: ContentCollection

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var loaded = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(Brand.font(.book, 20, .body))
                .foregroundStyle(Brand.ink)
                .scrollContentBackground(.hidden)
                .background(Brand.paper)
                .padding(.horizontal, 20)
                .navigationTitle("Notes  ·  \(collection.title)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Add time") { insertTime() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { flush(); dismiss() }
                    }
                }
        }
        .onAppear {
            text = NotesFile.load(folder: collection.folder)
            loaded = true
        }
        .onChange(of: text) { _ in
            guard loaded else { return }
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                flush()
            }
        }
        .onDisappear { flush() }
    }

    private func flush() {
        guard loaded else { return }
        NotesFile.save(text, folder: collection.folder)
    }

    private func insertTime() {
        let stamp = Date().formatted(date: .omitted, time: .shortened)
        text += (text.isEmpty || text.hasSuffix("\n") ? "" : "\n") + "[\(stamp)] "
    }
}

struct NotesButton: View {
    let collection: ContentCollection
    var tint: Color = Brand.ink
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .foregroundStyle(tint)
        }
        .accessibilityLabel("Notes")
        .sheet(isPresented: $showing) { NotesView(collection: collection) }
    }
}
