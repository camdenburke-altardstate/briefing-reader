import SwiftUI

extension LibraryStore {
    /// How far through a PDF or video someone is, 0 to 1. nil for images and unopened items.
    func fraction(for item: ContentItem) -> Double? {
        guard let entry = progress[item.id] else { return nil }
        switch item.kind {
        case .pdf: return min(Double(entry.page + 1) / Double(max(item.measure, 1)), 1)
        case .video, .audio: return min(Double(entry.page) / Double(max(item.measure, 1)), 1)
        case .image: return nil
        }
    }

    /// The most recently opened PDF, video or recording, for the "Continue" row.
    var continueItem: ContentItem? {
        var best: ContentItem?
        var bestDate = Date.distantPast
        for collection in collections {
            for item in collection.items where item.kind != .image {
                if let entry = progress[item.id], entry.opened > bestDate {
                    best = item
                    bestDate = entry.opened
                }
            }
        }
        return best
    }

    func collection(containing item: ContentItem) -> ContentCollection? {
        collections.first { $0.folder == item.folder }
    }
}

private struct OpenedItem: Identifiable {
    let item: ContentItem
    let collection: ContentCollection
    var startPage: Int? = nil
    var id: String { item.id }
}

@MainActor
struct LibraryView: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var opened: OpenedItem?
    @State private var notesFor: ContentCollection?
    @State private var showManage = false
    @State private var showSearch = false

    private let poll = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        // The layout follows how the iPad is held: landscape puts a meeting's agenda beside its
        // materials; portrait stacks them and uses three narrower columns.
        GeometryReader { geo in
            content(landscape: geo.size.width > geo.size.height)
        }
    }

    private func content(landscape: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 44) {
                header(landscape: landscape)

                if store.collections.isEmpty {
                    VStack(spacing: 24) {
                        Text(Branding.emptyMessage)
                            .font(Brand.font(.light, 22, .title3))
                            .foregroundStyle(Brand.inkSecondary)
                        Button { showManage = true } label: {
                            Label("Add files", systemImage: "plus")
                                .font(Brand.font(.medium, 18, .headline))
                                .foregroundStyle(Brand.paper)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(Brand.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    if let item = store.continueItem, let collection = store.collection(containing: item) {
                        ContinueCard(item: item) { opened = OpenedItem(item: item, collection: collection) }
                    }
                    ForEach(store.collections) { collection in
                        CollectionSection(
                            collection: collection,
                            showHeader: showHeaders,
                            landscape: landscape,
                            open: { opened = OpenedItem(item: $0, collection: collection) },
                            notes: { notesFor = collection })
                    }
                }
            }
            .padding(.horizontal, landscape ? 56 : 40)
            .padding(.vertical, landscape ? 48 : 36)
        }
        .background(Brand.paper.ignoresSafeArea())
        .fullScreenCover(item: $opened) { open in
            ViewerScreen(item: open.item, collection: open.collection, startPage: open.startPage)
                .environmentObject(store)
        }
        .sheet(item: $notesFor) { NotesView(collection: $0) }
        .sheet(isPresented: $showManage) {
            ManageView().environmentObject(store)
        }
        .sheet(isPresented: $showSearch) {
            LibrarySearchView { item, collection, page in
                showSearch = false
                // Let the search sheet finish closing before the document opens.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    opened = OpenedItem(item: item, collection: collection, startPage: page)
                }
            }
            .environmentObject(store)
        }
        // Picks up files copied in over Finder while the app is open.
        .onReceive(poll) { _ in store.refresh() }
    }

    /// A single loose-files library needs no heading; meeting folders do.
    private var showHeaders: Bool {
        !(store.collections.count == 1 && store.collections[0].folder.isEmpty)
    }

    private func header(landscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 14) {
                Image("Wordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: landscape ? 300 : 230)
                    .accessibilityLabel(Branding.companyName)
                Spacer()
                StatusCluster()
                DisplayButton()
                Button { showSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(Brand.ink)
                }
                .accessibilityLabel("Search all documents")
                .disabled(store.collections.isEmpty)
                Button { showManage = true } label: {
                    Label("Manage", systemImage: "tray.and.arrow.down")
                        .font(Brand.font(.medium, 15, .subheadline))
                        .foregroundStyle(Brand.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
                }
                .accessibilityLabel("Manage content")
            }

            Rectangle().fill(Brand.hairline).frame(height: 1)

            HStack(alignment: .firstTextBaseline) {
                Text(Branding.libraryTitle.uppercased())
                    .font(Brand.font(.medium, 15, .subheadline))
                    .tracking(3.5)
                    .foregroundStyle(Brand.ink)
                Spacer()
                if store.itemCount > 0 {
                    Text("\(store.itemCount) \(store.itemCount == 1 ? "item" : "items")")
                        .font(Brand.font(.book, 15, .subheadline))
                        .foregroundStyle(Brand.inkSecondary)
                }
            }
        }
    }
}

// MARK: - Continue

private struct ContinueCard: View {
    let item: ContentItem
    let open: () -> Void

    @EnvironmentObject private var store: LibraryStore
    @State private var cover: UIImage?

    var body: some View {
        Button(action: open) {
            HStack(spacing: 28) {
                ZStack {
                    Brand.well
                    if let cover {
                        Image(uiImage: cover).resizable().scaledToFit().padding(8)
                    } else {
                        ProgressView().tint(Brand.inkSecondary)
                    }
                }
                .frame(width: 200, height: 130)
                .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: 10) {
                    Text("CONTINUE")
                        .font(Brand.font(.medium, 12, .caption))
                        .tracking(3)
                        .foregroundStyle(Brand.inkSecondary)
                    Text(item.title)
                        .font(Brand.font(.medium, 24, .title3))
                        .foregroundStyle(Brand.ink)
                        .lineLimit(2)
                    Text(detail)
                        .font(Brand.font(.book, 15, .subheadline))
                        .foregroundStyle(Brand.inkSecondary)
                    if let fraction = store.fraction(for: item) {
                        ProgressBar(fraction: fraction).frame(maxWidth: 360)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Brand.inkSecondary)
            }
            .padding(24)
            .background(Brand.paper)
            .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .task(id: item.id) { cover = await ThumbnailCache.shared.thumbnail(for: item) }
    }

    private var detail: String {
        guard let entry = store.resume(for: item) else { return "" }
        switch item.kind {
        case .pdf:
            let percent = Int(((store.fraction(for: item) ?? 0) * 100).rounded())
            return "Page \(entry.page + 1) of \(item.measure)  ·  \(percent)%"
        case .video, .audio:
            return "\(AgendaLogic.clock(seconds: entry.page)) of \(AgendaLogic.clock(seconds: item.measure))"
        case .image:
            return ""
        }
    }
}

private struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Brand.hairline)
                Rectangle().fill(Brand.ink).frame(width: proxy.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Meeting sections

private struct CollectionSection: View {
    let collection: ContentCollection
    let showHeader: Bool
    let landscape: Bool
    let open: (ContentItem) -> Void
    let notes: () -> Void

    private var agenda: [AgendaItem] { collection.meeting?.agenda ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if showHeader { sectionHeader }

            if landscape && !agenda.isEmpty && !collection.items.isEmpty {
                // Landscape: the agenda on the left, the materials beside it, like a meeting pack.
                HStack(alignment: .top, spacing: 40) {
                    AgendaList(collection: collection, agenda: agenda, open: open)
                        .frame(width: 450)   // wide enough that titles and presenters do not break mid-word
                    grid(columns: 2)
                }
            } else {
                if !agenda.isEmpty {
                    AgendaList(collection: collection, agenda: agenda, open: open)
                }
                if !collection.items.isEmpty {
                    grid(columns: landscape ? 4 : 3)
                }
            }
        }
    }

    private func grid(columns count: Int) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 32, alignment: .top), count: count)
        return LazyVGrid(columns: columns, spacing: 44) {
            ForEach(collection.items) { item in
                Button { open(item) } label: { ItemCard(item: item) }
                    .buttonStyle(PressableStyle())
            }
        }
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(collection.title)
                        .font(Brand.font(.medium, 26, .title2))
                        .foregroundStyle(Brand.ink)
                    if let meeting = collection.meeting, !meeting.subtitle.isEmpty {
                        Text(meeting.subtitle)
                            .font(Brand.font(.book, 16, .subheadline))
                            .foregroundStyle(Brand.inkSecondary)
                    }
                }
                if collection.meeting?.confidential == true {
                    Text("CONFIDENTIAL")
                        .font(Brand.font(.medium, 11, .caption2))
                        .tracking(2)
                        .foregroundStyle(Brand.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(Rectangle().stroke(Brand.ink, lineWidth: 1))
                }
                Spacer()
                Button(action: notes) {
                    Label("Notes", systemImage: "square.and.pencil")
                        .font(Brand.font(.medium, 15, .subheadline))
                        .foregroundStyle(Brand.ink)
                }
            }
            if let note = collection.meeting?.note, !note.isEmpty {
                Text(note)
                    .font(Brand.font(.book, 16, .body))
                    .foregroundStyle(Brand.inkSecondary)
            }
            Rectangle().fill(Brand.hairline).frame(height: 1)
        }
    }
}

private struct AgendaList: View {
    let collection: ContentCollection
    let agenda: [AgendaItem]
    let open: (ContentItem) -> Void

    var body: some View {
        // Re-evaluated every minute so NOW and NEXT follow the clock.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let position = currentPosition(at: context.date)
            VStack(spacing: 0) {
                ForEach(Array(agenda.enumerated()), id: \.offset) { index, entry in
                    AgendaRow(
                        entry: entry,
                        tag: index == position.now ? "NOW" : (index == position.next ? "NEXT" : nil),
                        highlighted: index == position.now,
                        linked: linkedItem(for: entry),
                        open: open)
                }
            }
            .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
        }
    }

    private func currentPosition(at date: Date) -> AgendaLogic.Position {
        guard collection.meeting?.isToday == true else { return AgendaLogic.Position(now: nil, next: nil) }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return AgendaLogic.position(times: agenda.map { AgendaLogic.minutes(from: $0.time) }, nowMinutes: minutes)
    }

    private func linkedItem(for entry: AgendaItem) -> ContentItem? {
        guard let file = entry.file else { return nil }
        return collection.items.first { $0.fileName.caseInsensitiveCompare(file) == .orderedSame }
    }
}

private struct AgendaRow: View {
    let entry: AgendaItem
    let tag: String?
    let highlighted: Bool
    let linked: ContentItem?
    let open: (ContentItem) -> Void

    var body: some View {
        Button {
            if let linked { open(linked) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text(entry.time ?? "")
                    .font(Brand.font(.medium, 16, .body))
                    .monospacedDigit()
                    .foregroundStyle(Brand.ink)
                    .frame(width: 96, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(Brand.font(.medium, 18, .headline))
                        .foregroundStyle(Brand.ink)
                    if let presenter = entry.presenter, !presenter.isEmpty {
                        Text(presenter)
                            .font(Brand.font(.book, 15, .subheadline))
                            .foregroundStyle(Brand.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                Spacer()
                if let tag {
                    Text(tag)
                        .font(Brand.font(.medium, 11, .caption2))
                        .tracking(2)
                        .foregroundStyle(highlighted ? Brand.paper : Brand.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(highlighted ? Brand.ink : Color.clear)
                        .overlay(Rectangle().stroke(Brand.ink, lineWidth: highlighted ? 0 : 1))
                }
                if linked != nil {
                    Image(systemName: "chevron.right").foregroundStyle(Brand.inkSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(highlighted ? Brand.well : Brand.paper)
            .overlay(alignment: .bottom) { Brand.hairline.frame(height: 1) }
        }
        .buttonStyle(PressableStyle())
        .disabled(linked == nil)
    }
}

// MARK: - Cards

private struct ItemCard: View {
    let item: ContentItem
    @EnvironmentObject private var store: LibraryStore
    @State private var cover: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Brand.well
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFit()
                        .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
                        .padding(14)
                } else if item.kind == .audio {
                    Image(systemName: "waveform").font(.system(size: 44)).foregroundStyle(Brand.inkSecondary)
                } else {
                    ProgressView().tint(Brand.inkSecondary)
                }
                if item.kind == .video {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.35), radius: 4)
                }
            }
            .frame(height: 200)
            .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
            .overlay(alignment: .topLeading) {
                if store.resume(for: item) == nil {
                    Text("NEW")
                        .font(Brand.font(.medium, 10, .caption2))
                        .tracking(1.5)
                        .foregroundStyle(Brand.paper)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Brand.ink)
                        .padding(8)
                }
            }

            if let fraction = store.fraction(for: item) {
                ProgressBar(fraction: fraction)
            }

            Text(item.title)
                .font(Brand.font(.medium, 19, .headline))
                .foregroundStyle(Brand.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Text(status)
                .font(Brand.font(.book, 15, .subheadline))
                .foregroundStyle(Brand.inkSecondary)
        }
        .contentShape(Rectangle())
        .task(id: item.id) { cover = await ThumbnailCache.shared.thumbnail(for: item) }
    }

    private var status: String {
        let entry = store.resume(for: item)
        switch item.kind {
        case .pdf:
            let pages = "\(item.measure) \(item.measure == 1 ? "page" : "pages")"
            guard let entry else { return pages }
            let percent = Int(((store.fraction(for: item) ?? 0) * 100).rounded())
            return entry.page > 0 ? "\(pages)  ·  \(percent)%" : pages
        case .image:
            return "Image"
        case .video:
            let length = AgendaLogic.clock(seconds: item.measure)
            if let entry, entry.page > 5 { return "Video  ·  \(length)  ·  Resume \(AgendaLogic.clock(seconds: entry.page))" }
            return "Video  ·  \(length)"
        case .audio:
            return "Audio  ·  \(AgendaLogic.clock(seconds: item.measure))"
        }
    }
}
