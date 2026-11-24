import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The screen an assistant uses before a meeting: pick files from a USB drive, an SD card reader or
/// the iPad, say which meeting they belong to, and later clear everything out. Plain words, big
/// buttons, no technical steps. Everything stays on the iPad; nothing uses the network.
@MainActor
struct ManageView: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var unlocked = !ManagePIN.isSet
    @State private var sheet: ManageSheet?
    @State private var pending: [URL] = []
    @State private var work: WorkState?
    @State private var notice: ManageNotice?
    @State private var confirm: ManageConfirm?
    @State private var sizes: [String: Int64] = [:]
    @State private var freeBytes: Int64?
    @State private var pinOn = ManagePIN.isSet

    var body: some View {
        NavigationStack {
            Group {
                if unlocked {
                    list
                        .alert(
                            notice?.title ?? "",
                            isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } }),
                            presenting: notice
                        ) { _ in
                            Button("OK") {}
                        } message: { item in
                            Text(item.body)
                        }
                } else {
                    PINEntryView(onUnlock: { unlocked = true }, onCancel: { dismiss() })
                }
            }
            .navigationTitle("Manage content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.disabled(work != nil)
                }
            }
            .overlay { if let work { workOverlay(work) } }
        }
        .interactiveDismissDisabled(work != nil)
        .alert(
            "Are you sure?",
            isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
            presenting: confirm
        ) { item in
            Button(item.buttonLabel, role: .destructive) { perform(item) }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(item.message)
        }
        .sheet(item: $sheet) { which in sheetContent(which) }
        .task { refreshSizes() }
        .onChange(of: store.collections) { _ in refreshSizes() }
    }

    // MARK: Main list

    private var finishedCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return store.collections.filter { !$0.folder.isEmpty && ($0.meeting?.day ?? .distantFuture) < startOfToday }.count
    }

    private var list: some View {
        List {
            Section {
                actionRow(
                    title: "Choose files",
                    detail: "PDFs, photos, videos or audio",
                    symbol: "doc.badge.plus") { sheet = .files }
                actionRow(
                    title: "Choose a folder",
                    detail: "A prepared meeting folder, with its agenda",
                    symbol: "folder.badge.plus") { sheet = .folder }
            } header: {
                Text("Add to this iPad")
            } footer: {
                Text("Plug in a USB drive or SD card reader first, then pick it from the list. Files are copied onto this iPad. Nothing is sent anywhere.")
            }

            Section("On this iPad") {
                if store.collections.isEmpty {
                    Text("Nothing yet.")
                        .font(Brand.font(.book, 17, .body))
                        .foregroundStyle(Brand.inkSecondary)
                }
                ForEach(store.collections) { collection in
                    collectionRow(collection)
                }
            }

            Section {
                if finishedCount > 0 {
                    Button { confirm = .finished } label: {
                        Label(
                            "Remove \(finishedCount) finished \(finishedCount == 1 ? "meeting" : "meetings")",
                            systemImage: "calendar.badge.minus")
                            .font(Brand.font(.medium, 18, .headline))
                    }
                }
                Button(role: .destructive) { confirm = .everything } label: {
                    Label("Clear everything for the next meeting", systemImage: "trash")
                        .font(Brand.font(.medium, 18, .headline))
                }
                .disabled(store.collections.isEmpty)
            } header: {
                Text("Between meetings")
            } footer: {
                Text("Clearing removes every document, photo, video and note from this iPad, so the next meeting starts empty.")
            }

            Section {
                if pinOn {
                    Button("Change PIN") { sheet = .setPIN }
                    Button("Turn PIN off", role: .destructive) { confirm = .removePIN }
                } else {
                    Button("Set a PIN") { sheet = .setPIN }
                }
            } header: {
                Text("Protect this screen")
            } footer: {
                Text(pinOn
                     ? "A PIN is needed to open this screen. Keep it written down somewhere safe."
                     : "Set a PIN so only the person preparing the iPads can add or remove content.")
            }

            Section("Storage") {
                HStack {
                    Text("Free space")
                    Spacer()
                    Text(freeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "unknown")
                        .foregroundStyle(Brand.inkSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func actionRow(title: String, detail: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 26))
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Brand.font(.medium, 19, .headline))
                    Text(detail)
                        .font(Brand.font(.book, 15, .subheadline))
                        .foregroundStyle(Brand.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Brand.inkSecondary)
            }
            .foregroundStyle(Brand.ink)
            .padding(.vertical, 6)
        }
    }

    private func collectionRow(_ collection: ContentCollection) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.folder.isEmpty ? "Loose files (no meeting)" : collection.title)
                    .font(Brand.font(.medium, 18, .headline))
                    .foregroundStyle(Brand.ink)
                Text(detail(for: collection))
                    .font(Brand.font(.book, 15, .subheadline))
                    .foregroundStyle(Brand.inkSecondary)
            }
            Spacer()
            Button("Remove") { confirm = .meeting(collection) }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
        }
    }

    private func detail(for collection: ContentCollection) -> String {
        let count = collection.items.count
        var text = "\(count) \(count == 1 ? "item" : "items")"
        if let size = sizes[collection.folder] {
            text += "  ·  " + ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        return text
    }

    private func workOverlay(_ state: WorkState) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: Double(state.done), total: Double(max(state.total, 1)))
                    .tint(Brand.ink)
                Text("\(state.title)  ·  \(min(state.done + 1, max(state.total, 1))) of \(max(state.total, 1))")
                    .font(Brand.font(.medium, 17, .headline))
                    .foregroundStyle(Brand.ink)
                Text("Please keep this screen open.")
                    .font(Brand.font(.book, 15, .subheadline))
                    .foregroundStyle(Brand.inkSecondary)
            }
            .padding(28)
            .frame(width: 380)
            .background(Brand.paper)
            .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
        }
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetContent(_ which: ManageSheet) -> some View {
        switch which {
        case .files:
            FilePicker(
                types: [.pdf, .image, .movie, .audio],
                asCopy: true,
                multiple: true,
                onPick: { urls in
                    pending = urls
                    sheet = nil
                    // Let the picker finish closing before the next sheet opens.
                    if !urls.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { sheet = .destination }
                    }
                },
                onCancel: { sheet = nil })
        case .folder:
            FilePicker(
                types: [.folder],
                asCopy: false,
                multiple: false,
                onPick: { urls in
                    sheet = nil
                    if let url = urls.first { startFolderImport(url) }
                },
                onCancel: { sheet = nil })
        case .destination:
            DestinationSheet(
                count: pending.count,
                existing: store.collections.filter { !$0.folder.isEmpty }.map(\.folder),
                onStart: { destination in
                    sheet = nil
                    startImport(destination)
                },
                onCancel: {
                    ContentManager.discard(pending)
                    pending = []
                    sheet = nil
                })
        case .setPIN:
            SetPINView(
                onSave: { pin in
                    ManagePIN.set(pin)
                    pinOn = true
                    sheet = nil
                },
                onCancel: { sheet = nil })
        }
    }

    // MARK: Actions

    private func setProgress(_ title: String, _ done: Int, _ total: Int) {
        guard work != nil else { return }   // a late update must not bring the box back after it finished
        work = WorkState(title: title, done: done, total: total)
    }

    private func startImport(_ destination: ContentManager.Destination) {
        let urls = pending
        pending = []
        work = WorkState(title: "Adding files", done: 0, total: urls.count)
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                ContentManager.importFiles(urls, to: destination) { done, total in
                    Task { @MainActor in setProgress("Adding files", done, total) }
                }
            }.value
            finishImport(result)
        }
    }

    private func startFolderImport(_ url: URL) {
        work = WorkState(title: "Adding folder", done: 0, total: 1)
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                ContentManager.importFolder(url) { done, total in
                    Task { @MainActor in setProgress("Adding folder", done, total) }
                }
            }.value
            finishImport(result)
        }
    }

    private func finishImport(_ result: ContentManager.ImportResult) {
        work = nil
        store.refresh(force: true)
        refreshSizes()

        var lines = [result.added == 1 ? "1 file was added." : "\(result.added) files were added."]
        if !result.skipped.isEmpty {
            lines.append("Not added, because this app cannot open them: \(result.skipped.joined(separator: ", ")). Save PowerPoint or Word files as PDF first.")
        }
        if !result.failed.isEmpty {
            lines.append("Could not be copied (was the drive unplugged, or is the iPad full?): \(result.failed.joined(separator: ", ")).")
        }
        notice = ManageNotice(title: result.added > 0 ? "Added" : "Nothing was added", body: lines.joined(separator: "\n\n"))
    }

    private func perform(_ item: ManageConfirm) {
        switch item {
        case .meeting(let collection):
            ContentManager.removeMeeting(folder: collection.folder)
            afterRemoval("Removed \(collection.folder.isEmpty ? "the loose files" : "\"\(collection.title)\"").")
        case .finished:
            let removed = ContentManager.removeFinishedMeetings(from: store.collections)
            afterRemoval(removed == 0 ? "There were no finished meetings." : "Removed \(removed) finished \(removed == 1 ? "meeting" : "meetings").")
        case .everything:
            ContentManager.wipeEverything()
            afterRemoval("This iPad is empty and ready for the next meeting.")
        case .removePIN:
            ManagePIN.clear()
            pinOn = false
        }
    }

    /// After anything is removed: forget the cover pictures too, so no picture of a deleted
    /// document is left on the iPad, then refresh the library.
    private func afterRemoval(_ text: String) {
        Task {
            await ThumbnailCache.shared.clearAll()
            store.refresh(force: true)
            refreshSizes()
            notice = ManageNotice(title: "Done", body: text)
        }
    }

    private func refreshSizes() {
        let folders = store.collections.map(\.folder)
        Task {
            let (map, free) = await Task.detached(priority: .utility) { () -> ([String: Int64], Int64?) in
                var result: [String: Int64] = [:]
                for folder in folders { result[folder] = ContentManager.bytes(inFolder: folder) }
                return (result, ContentManager.freeSpaceBytes())
            }.value
            sizes = map
            freeBytes = free
        }
    }
}

// MARK: - Small types

private enum ManageSheet: String, Identifiable {
    case files, folder, destination, setPIN
    var id: String { rawValue }
}

private struct WorkState {
    var title: String
    var done: Int
    var total: Int
}

private struct ManageNotice: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

private enum ManageConfirm {
    case meeting(ContentCollection)
    case finished
    case everything
    case removePIN

    var buttonLabel: String {
        switch self {
        case .meeting: return "Remove"
        case .finished: return "Remove finished meetings"
        case .everything: return "Remove everything"
        case .removePIN: return "Turn PIN off"
        }
    }

    var message: String {
        switch self {
        case .meeting(let collection):
            let name = collection.folder.isEmpty ? "the loose files" : "\"\(collection.title)\""
            return "Remove \(name) and its notes from this iPad? This cannot be undone."
        case .finished:
            return "Remove every meeting dated before today, and its notes? This cannot be undone."
        case .everything:
            return "Remove every document, photo, video and note from this iPad? It will be empty and ready for the next meeting. This cannot be undone."
        case .removePIN:
            return "Turn the PIN off? Anyone using this iPad will be able to add or remove content."
        }
    }
}

// MARK: - Choosing where the files go

private struct DestinationSheet: View {
    let count: Int
    let existing: [String]
    let onStart: (ContentManager.Destination) -> Void
    let onCancel: () -> Void

    private enum Choice: String, CaseIterable, Identifiable {
        case newMeeting = "New meeting"
        case existingMeeting = "A meeting already here"
        case library = "No meeting"
        var id: String { rawValue }
    }

    @State private var choice: Choice = .newMeeting
    @State private var name = ""
    @State private var hasDate = false
    @State private var date = Date()
    @State private var confidential = false
    @State private var existingFolder = ""

    private var canStart: Bool {
        switch choice {
        case .newMeeting:
            let cleaned = ContentManager.safeName(name).lowercased()
            return !cleaned.isEmpty && !["notes", "inbox", "annotations"].contains(cleaned)
        case .existingMeeting: return !existingFolder.isEmpty
        case .library: return true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Put them in", selection: $choice) {
                        ForEach(Choice.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Where should these \(count) \(count == 1 ? "file" : "files") go?")
                }

                switch choice {
                case .newMeeting:
                    Section {
                        TextField("Meeting name, for example Board Meeting", text: $name)
                        Toggle("It has a date", isOn: $hasDate)
                        if hasDate {
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                        }
                        Toggle("Mark as confidential", isOn: $confidential)
                    }
                case .existingMeeting:
                    Section {
                        if existing.isEmpty {
                            Text("There are no meetings on this iPad yet.")
                                .foregroundStyle(Brand.inkSecondary)
                        } else {
                            Picker("Meeting", selection: $existingFolder) {
                                ForEach(existing, id: \.self) { Text($0).tag($0) }
                            }
                        }
                    }
                case .library:
                    Section {
                        Text("The files will be listed under Library, not tied to a meeting.")
                            .foregroundStyle(Brand.inkSecondary)
                    }
                }
            }
            .navigationTitle("Add files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(count) \(count == 1 ? "file" : "files")") { start() }
                        .disabled(!canStart)
                }
            }
        }
        .onAppear { existingFolder = existing.first ?? "" }
        .interactiveDismissDisabled(true)   // leave only through Cancel or Add, so picked files are never orphaned
    }

    private func start() {
        switch choice {
        case .newMeeting:
            let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
            var dateText: String?
            if hasDate {
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                dateText = formatter.string(from: date)
            }
            let info = MeetingInfo(title: title, date: dateText, confidential: confidential ? true : nil)
            onStart(.meeting(folder: title, create: info))
        case .existingMeeting:
            onStart(.meeting(folder: existingFolder, create: nil))
        case .library:
            onStart(.library)
        }
    }
}

// MARK: - PIN

private struct PINEntryView: View {
    let onUnlock: () -> Void
    let onCancel: () -> Void

    @State private var pin = ""
    @State private var message: String?

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock").font(.system(size: 34)).foregroundStyle(Brand.ink)
            Text("Enter the PIN to manage content")
                .font(Brand.font(.medium, 20, .title3))
                .foregroundStyle(Brand.ink)
            SecureField("PIN", text: $pin)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(Brand.font(.medium, 24, .title2))
                .frame(width: 220)
                .padding(12)
                .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
                .onSubmit(check)
            if let message {
                Text(message)
                    .font(Brand.font(.book, 16, .body))
                    .foregroundStyle(.red)
            }
            Button("Open", action: check)
                .font(Brand.font(.medium, 18, .headline))
                .disabled(pin.isEmpty)
            Button("Cancel", action: onCancel)
                .font(Brand.font(.book, 16, .body))
                .foregroundStyle(Brand.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func check() {
        if let until = ManagePIN.lockedUntil, until > Date() {
            message = "Too many tries. Wait a little and try again."
            pin = ""
            return
        }
        if ManagePIN.verify(pin) {
            ManagePIN.resetFailures()
            onUnlock()
        } else {
            ManagePIN.recordFailure()
            pin = ""
            message = "That PIN is not right."
            if let until = ManagePIN.lockedUntil, until > Date() {
                message = "Too many tries. Wait 30 seconds and try again."
            }
        }
    }
}

private struct SetPINView: View {
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var first = ""
    @State private var second = ""

    private var valid: Bool {
        first.count >= 4 && first.count <= 8 && first == second && first.allSatisfy(\.isNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New PIN (4 to 8 digits)", text: $first).keyboardType(.numberPad)
                    SecureField("Type it again", text: $second).keyboardType(.numberPad)
                } footer: {
                    Text("Write it down and keep it somewhere safe. If it is forgotten, the iPad has to be erased and set up again from the Mac.")
                }
            }
            .navigationTitle("Set a PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(first) }.disabled(!valid)
                }
            }
        }
    }
}

// MARK: - The system file picker

/// The iPad's own file chooser. It shows USB drives, SD cards, and this iPad, and works with no network.
struct FilePicker: UIViewControllerRepresentable {
    let types: [UTType]
    let asCopy: Bool
    let multiple: Bool
    let onPick: ([URL]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: asCopy)
        picker.allowsMultipleSelection = multiple
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePicker
        init(_ parent: FilePicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}
