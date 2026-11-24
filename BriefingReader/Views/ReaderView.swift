import SwiftUI
import PDFKit
import PencilKit

private enum ReaderSheet: String, Identifiable {
    case contents, search
    var id: String { rawValue }
}

/// The PDF reader. Meant to feel like Books or Kindle:
/// - opens straight onto the page with no toolbars
/// - tap the left or right edge to turn the page, swipe to turn, tap the middle for the bar
/// - a quiet footer ("Page 12 of 96") and the time, outside the page
/// - bookmark ribbon, contents, search, and a scrubber that previews the page
@MainActor
struct ReaderView: View {
    let document: ContentItem
    let collection: ContentCollection
    var startPage: Int? = nil

    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("readingTone") private var toneRaw = ReadingTone.standard.rawValue

    @State private var pdf: PDFDocument?
    @State private var portraitPages = true       // the document's pages are taller than wide
    @State private var page = 0
    @State private var scrub: Double?              // slider position while the finger is down
    @State private var scrubImage: UIImage?
    @State private var scrubTask: Task<Void, Never>?
    @State private var chromeVisible = false       // reading starts with nothing in the way
    @State private var outline: [OutlineEntry] = []
    @State private var flags: [Int] = []
    @State private var sheet: ReaderSheet?
    @State private var highlight: PDFSelection?
    @State private var markup: MarkupStore?        // Apple Pencil handwriting, when the feature is on
    @State private var penOn = false               // true while the person is writing on the page

    private var tone: ReadingTone { ReadingTone(rawValue: toneRaw) ?? .standard }
    private var pageCount: Int { pdf?.pageCount ?? document.measure }
    private var shownPage: Int { Int((scrub ?? Double(page)).rounded()) }
    private var isFlagged: Bool { flags.contains(page) }

    var body: some View {
        GeometryReader { geo in screen(in: geo.size) }
            .statusBarHidden(true)
            .sheet(item: $sheet) { which in
                switch which {
                case .contents: contentsSheet
                case .search:
                    if let pdf {
                        SearchSheet(document: pdf) { result in
                            page = result.pageIndex
                            highlight = result.selection
                        }
                    }
                }
            }
            .task { await load() }
            .onChange(of: page) { newPage in
                if pdf != nil { store.savePage(newPage, for: document) }
                // Turning a page clears the bar, like a book.
                if scrub == nil && chromeVisible { withAnimation(.easeOut(duration: 0.2)) { chromeVisible = false } }
            }
            .onDisappear {
                markup?.save()
                store.commitProgress()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                markup?.save()   // do not wait for the one-second delay if the app is about to be put away
            }
    }

    /// Two pages side by side only on a landscape iPad showing portrait-shaped pages.
    private func usesSpread(_ size: CGSize) -> Bool {
        ReaderLayout.useSpreads && portraitPages && size.width > size.height * 1.1
    }

    private func screen(in size: CGSize) -> some View {
        let spread = usesSpread(size)
        return ZStack {
            tone.backdrop.ignoresSafeArea()

            if let pdf {
                VStack(spacing: 0) {
                    PDFKitView(
                        document: pdf,
                        page: $page,
                        highlight: $highlight,
                        spread: spread,
                        markup: markup,
                        penOn: penOn,
                        onCenterTap: { if !penOn { toggleChrome() } })
                        .id(spread)          // a fresh PDF view for each layout; the page is carried over
                        .readingTone(tone)
                        .overlay {
                            if spread {
                                // The soft shadow down the spine of an open book.
                                LinearGradient(
                                    colors: [.clear, Color.black.opacity(0.10), .clear],
                                    startPoint: .leading, endPoint: .trailing)
                                    .frame(width: 46)
                                    .allowsHitTesting(false)
                            }
                        }
                    footer(spread: spread)
                }
                .ignoresSafeArea(edges: .top)

                if isFlagged {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Brand.ink)
                        .padding(.trailing, 36)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }

                if penOn { penPill }
                if chromeVisible && !penOn { chrome(width: size.width) }
            } else {
                ProgressView().tint(tone.quietInk)
            }
        }
    }

    private func toggleChrome() {
        withAnimation(.easeInOut(duration: 0.2)) { chromeVisible.toggle() }
    }

    // MARK: Writing with Apple Pencil

    /// Writing mode: the bar goes away, the Pencil's tool palette appears, and Pencil strokes land on the
    /// page. A finger still turns pages and zooms. Done saves the handwriting.
    private func startMarking() {
        withAnimation(.easeInOut(duration: 0.2)) { chromeVisible = false }
        penOn = true
    }

    private func stopMarking() {
        penOn = false
        markup?.save()
    }

    private var penPill: some View {
        VStack {
            HStack {
                Spacer()
                Button { stopMarking() } label: {
                    Label("Done writing", systemImage: "checkmark")
                        .font(Brand.font(.medium, 16, .headline))
                        .foregroundStyle(Brand.paper)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Brand.ink)
                }
            }
            .padding(.top, 14)
            .padding(.trailing, 20)
            Spacer()
        }
    }

    private func load() async {
        let url = document.url
        // Opening the file and walking its bookmarks both happen off the main thread, so a
        // 500 page deck with a large table of contents does not freeze the screen.
        let result = await Task.detached(priority: .userInitiated) { () -> (PDFDocument, [OutlineEntry], Bool)? in
            guard let doc = PDFDocument(url: url), !doc.isLocked else { return nil }
            var tall = true
            if let first = doc.page(at: 0) {
                var box = first.bounds(for: .cropBox)
                if first.rotation % 180 != 0 { box = CGRect(x: 0, y: 0, width: box.height, height: box.width) }
                tall = box.height > box.width
            }
            return (doc, OutlineEntry.entries(for: doc), tall)
        }.value
        guard let (loaded, entries, tall) = result else { dismiss(); return }

        // Set the page first so the view is created already pointed at the saved page.
        page = min(max(startPage ?? store.savedPage(for: document), 0), max(document.measure - 1, 0))
        outline = entries
        portraitPages = tall
        flags = store.flags(for: document)
        markup = Features.pencilMarkup ? MarkupStore(item: document) : nil   // before the PDF, so the first pages get their layers
        pdf = loaded
        store.markOpened(document)
    }

    // MARK: Footer (always there, quiet)

    private func footer(spread: Bool) -> some View {
        ZStack {
            Text(pageLabel(spread: spread))
                .font(Brand.font(.book, 12, .caption))
                .foregroundStyle(tone.quietInk)
            HStack {
                Spacer()
                StatusCluster(tint: tone.quietInk)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 30)
    }

    private var percent: Int {
        Int((Double(page + 1) / Double(max(pageCount, 1)) * 100).rounded())
    }

    /// "Page 12 of 96", or "Pages 12-13 of 96" while two pages are showing. The cover is always alone,
    /// so the spreads are 2-3, 4-5 and so on, like a printed book.
    private func pageLabel(spread: Bool) -> String {
        let total = max(pageCount, 1)
        if spread && page > 0 {
            let left = page % 2 == 1 ? page : page - 1
            let right = min(left + 1, total - 1)
            if left != right { return "Pages \(left + 1)-\(right + 1) of \(total)  ·  \(percent)%" }
        }
        return "Page \(page + 1) of \(total)  ·  \(percent)%"
    }

    // MARK: Bar

    private func chrome(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            topBar(width: width)
            Spacer()
            if pageCount > 1 { scrubber }
        }
        .foregroundStyle(Brand.ink)
        .transition(.opacity)
    }

    /// Wide screens put the title in the middle of the bar. A portrait iPad is too narrow for icons
    /// and a title, so the bar there is icons only, like Kindle.
    private func topBar(width: CGFloat) -> some View {
        ZStack {
            HStack(spacing: 4) {
                iconButton("chevron.left", label: "Library") { dismiss() }
                Spacer()
                if !outline.isEmpty || !flags.isEmpty {
                    iconButton("list.bullet", label: "Contents") { sheet = .contents }
                }
                iconButton("magnifyingglass", label: "Search") { sheet = .search }
                if Features.pencilMarkup {
                    iconButton("pencil.tip", label: "Write on this document") { startMarking() }
                }
                iconButton(isFlagged ? "bookmark.fill" : "bookmark", label: "Bookmark this page") { toggleFlag() }
                NotesButton(collection: collection)
                DisplayButton(showsTone: true)
            }
            if width > 1000 {
                Text(document.title)
                    .font(Brand.font(.medium, 17, .headline))
                    .lineLimit(1)
                    .padding(.horizontal, 290)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Brand.paper.opacity(0.97))
        .overlay(alignment: .bottom) { Brand.hairline.frame(height: 1) }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
    }

    private func toggleFlag() {
        store.toggleFlag(page, for: document)
        flags = store.flags(for: document)
    }

    // MARK: Scrubber

    private var scrubber: some View {
        VStack(spacing: 12) {
            // While dragging, show the page you are over. The page itself only jumps on release,
            // so dragging across hundreds of pages never renders the ones in between.
            if scrub != nil {
                VStack(spacing: 8) {
                    if let scrubImage {
                        Image(uiImage: scrubImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 170)
                            .background(Color.white)
                            .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    }
                    Text(scrubCaption)
                        .font(Brand.font(.medium, 15, .subheadline))
                        .lineLimit(1)
                }
            }

            HStack(spacing: 14) {
                Text("\(shownPage + 1)")
                    .font(Brand.font(.book, 14, .footnote))
                    .monospacedDigit()
                    .frame(minWidth: 34, alignment: .trailing)
                Slider(
                    value: Binding(
                        get: { scrub ?? Double(page) },
                        set: { value in
                            scrub = value
                            requestScrubImage(Int(value.rounded()))
                        }),
                    in: 0...Double(max(pageCount - 1, 1)),
                    onEditingChanged: { editing in
                        if !editing, let target = scrub {
                            page = Int(target.rounded())
                            scrub = nil
                            scrubTask?.cancel()
                            scrubImage = nil
                        }
                    })
                    .tint(Brand.ink)
                Text("\(pageCount)")
                    .font(Brand.font(.book, 14, .footnote))
                    .monospacedDigit()
                    .frame(minWidth: 34, alignment: .leading)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(Brand.paper.opacity(0.97))
        .overlay(alignment: .top) { Brand.hairline.frame(height: 1) }
    }

    private var scrubCaption: String {
        let number = "Page \(shownPage + 1)"
        if let name = sectionName(forPage: shownPage) { return "\(number)  ·  \(name)" }
        return number
    }

    /// The nearest bookmark at or before a page, so scrubbing a 300 page deck can say "Chapter 9".
    private func sectionName(forPage index: Int) -> String? {
        outline.filter { $0.pageIndex <= index }.max { $0.pageIndex < $1.pageIndex }?.label
    }

    /// A small picture of the page under the finger. The latest request wins, and it waits a
    /// moment for the finger to settle, so fast scrubbing does not queue up renders.
    private func requestScrubImage(_ index: Int) {
        guard let pdf else { return }
        scrubTask?.cancel()
        scrubTask = Task {
            try? await Task.sleep(nanoseconds: 70_000_000)
            guard !Task.isCancelled else { return }
            let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let pdfPage = pdf.page(at: index) else { return nil }
                var bounds = pdfPage.bounds(for: .cropBox)
                if pdfPage.rotation % 180 != 0 {
                    bounds = CGRect(x: 0, y: 0, width: bounds.height, height: bounds.width)
                }
                let scale = 340 / max(bounds.height, 1)
                let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                return pdfPage.thumbnail(of: size, for: .cropBox)
            }.value
            if !Task.isCancelled { scrubImage = image }
        }
    }

    // MARK: Contents and bookmarks

    private var contentsSheet: some View {
        NavigationStack {
            List {
                if !flags.isEmpty {
                    Section("Bookmarks") {
                        ForEach(flags, id: \.self) { flagged in
                            row(label: "Page \(flagged + 1)", page: flagged, bold: false)
                        }
                    }
                }
                if !outline.isEmpty {
                    Section("Contents") {
                        ForEach(outline) { entry in
                            row(label: entry.label, page: entry.pageIndex, bold: entry.depth == 0, indent: entry.depth)
                        }
                    }
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { sheet = nil }
                }
            }
        }
    }

    private func row(label: String, page target: Int, bold: Bool, indent: Int = 0) -> some View {
        Button {
            page = target
            sheet = nil
        } label: {
            HStack {
                Text(label)
                    .font(bold ? Brand.font(.medium, 18, .headline) : Brand.font(.book, 17, .body))
                    .foregroundStyle(Brand.ink)
                    .padding(.leading, CGFloat(indent) * 20)
                Spacer()
                Text("\(target + 1)")
                    .font(Brand.font(.book, 16, .body))
                    .foregroundStyle(Brand.inkSecondary)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search

struct PDFSearchResult: Identifiable {
    let id = UUID()
    let selection: PDFSelection
    let pageIndex: Int
    let snippet: String
}

private struct SearchSheet: View {
    let document: PDFDocument
    let onPick: (PDFSearchResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PDFSearchResult] = []
    @State private var searching = false
    @State private var searched = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Brand.inkSecondary)
                    TextField("Search this document", text: $query)
                        .font(Brand.font(.book, 19, .body))
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { Task { await run() } }
                    if searching { ProgressView() }
                }
                .padding(18)
                Divider()

                if results.isEmpty {
                    Text(searched ? "No matches" : "Type a word or phrase, then press Search.")
                        .font(Brand.font(.light, 20, .title3))
                        .foregroundStyle(Brand.inkSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { result in
                        Button {
                            onPick(result)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Page \(result.pageIndex + 1)")
                                    .font(Brand.font(.medium, 15, .subheadline))
                                    .foregroundStyle(Brand.ink)
                                Text(result.snippet)
                                    .font(Brand.font(.book, 16, .body))
                                    .foregroundStyle(Brand.inkSecondary)
                                    .lineLimit(2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    @MainActor private func run() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return }
        searching = true
        let doc = document
        // Searching a 300 page deck takes a moment, so it runs off the main thread and keeps the first 300 hits.
        let found = await Task.detached(priority: .userInitiated) { () -> [PDFSearchResult] in
            let selections = doc.findString(text, withOptions: .caseInsensitive)
            return selections.prefix(300).compactMap { selection -> PDFSearchResult? in
                guard let hitPage = selection.pages.first else { return nil }
                let context = selection.copy() as? PDFSelection
                context?.extend(atStart: 30)
                context?.extend(atEnd: 60)
                let snippet = (context?.string ?? selection.string ?? text)
                    .replacingOccurrences(of: "\n", with: " ")
                return PDFSearchResult(selection: selection, pageIndex: doc.index(for: hitPage), snippet: snippet)
            }
        }.value
        results = found
        searched = true
        searching = false
    }
}

// MARK: - PDFKit bridge

/// A handwriting layer that remembers which page it belongs to.
final class PageCanvasView: PKCanvasView {
    var pageIndex = 0
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var page: Int
    @Binding var highlight: PDFSelection?
    var spread = false
    var markup: MarkupStore? = nil
    var penOn = false
    var onCenterTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> LockedPDFView {
        let view = LockedPDFView()
        view.displayMode = spread ? .twoUp : .singlePage
        view.displaysAsBook = true      // the cover stands alone, then pages pair up 2-3, 4-5
        view.displayDirection = .horizontal
        view.autoScales = true
        view.displaysPageBreaks = false
        view.pageShadowsEnabled = false
        view.backgroundColor = .clear
        view.usePageViewController(true, withViewOptions: [.interPageSpacing: 8])
        if Features.pencilMarkup { view.pageOverlayViewProvider = context.coordinator }   // handwriting layers
        view.document = document
        // PDFKit ignores go(to:) until the view has a size, so the jump to the saved page is
        // done by the view itself on its first layout. This matters for pages deep in a long deck.
        view.initialPage = document.page(at: min(max(page, 0), document.pageCount - 1))
        view.onCenterTap = onCenterTap
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: view)
        return view
    }

    func updateUIView(_ view: LockedPDFView, context: Context) {
        context.coordinator.parent = self
        view.onCenterTap = onCenterTap
        view.penMode = penOn
        context.coordinator.setPen(penOn, in: view)
        guard view.initialPage == nil else { return }   // first layout has not happened yet

        // Rotating the iPad switches between one page and a two-page spread, keeping the same page.
        let wanted: PDFDisplayMode = spread ? .twoUp : .singlePage
        if view.displayMode != wanted {
            let keep = view.currentPage
            view.displayMode = wanted
            view.displaysAsBook = true
            view.autoScales = true
            if let keep { view.go(to: keep) }
        }

        if let found = highlight {
            found.color = UIColor.systemYellow.withAlphaComponent(0.55)
            view.go(to: found)
            view.highlightedSelections = [found]   // a plain highlight, with no selection handles or menu
            DispatchQueue.main.async { self.highlight = nil }
            return
        }

        let current = view.currentPage.flatMap { document.index(for: $0) }
        if current != page, let target = document.page(at: page) {
            view.go(to: target)
        }
    }

    /// Called when SwiftUI throws the PDF view away (for example on rotation). Makes sure no stroke is lost.
    static func dismantleUIView(_ uiView: LockedPDFView, coordinator: Coordinator) {
        coordinator.flush()
    }

    final class Coordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate, PKToolPickerObserver {
        var parent: PDFKitView
        private let toolPicker = PKToolPicker()
        private let canvases = NSHashTable<PKCanvasView>.weakObjects()
        private var penActive = false

        init(_ parent: PDFKitView) {
            self.parent = parent
            super.init()
            toolPicker.addObserver(self)   // to copy the chosen pen to every page layer
        }

        /// Writes every page layer's drawing to the store and saves it now.
        func flush() {
            for case let canvas as PageCanvasView in canvases.allObjects {
                parent.markup?.set(canvas.drawing, for: canvas.pageIndex)
            }
            parent.markup?.save()
        }

        /// With two pages showing, only one layer holds the palette focus, so the chosen pen is copied
        /// to the other layer too.
        func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
            for canvas in canvases.allObjects { canvas.tool = toolPicker.selectedTool }
        }

        // MARK: Handwriting layers. PDFKit asks for one overlay per page it shows and scales it with the page.

        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            guard let markup = parent.markup, let doc = view.document else { return nil }
            let index = doc.index(for: page)
            let canvas = PageCanvasView()
            canvas.pageIndex = index
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            canvas.isScrollEnabled = false
            canvas.overrideUserInterfaceStyle = .light   // keep black ink black when the iPad is in Dark Mode
            canvas.drawingPolicy = .pencilOnly           // the Pencil writes; a finger keeps turning pages and zooming
            canvas.drawing = markup.drawing(for: index)
            canvas.tool = toolPicker.selectedTool
            canvas.delegate = self
            canvas.isUserInteractionEnabled = penActive   // off while reading, so taps and links pass through
            canvases.add(canvas)
            toolPicker.addObserver(canvas)
            #if DEBUG
            print("markup layer requested for page \(index + 1)")   // check this appears on the first device test
            #endif
            return canvas
        }

        func pdfView(_ pdfView: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
            guard penActive, let canvas = overlayView as? PKCanvasView, page === pdfView.currentPage else { return }
            // The layer is not in a window yet, so take focus on the next pass.
            DispatchQueue.main.async { [weak self, weak canvas] in
                if let canvas { self?.focus(canvas) }
            }
        }

        func pdfView(_ pdfView: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
            guard let canvas = overlayView as? PageCanvasView else { return }
            parent.markup?.set(canvas.drawing, for: canvas.pageIndex)
            toolPicker.removeObserver(canvas)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let canvas = canvasView as? PageCanvasView else { return }
            parent.markup?.set(canvas.drawing, for: canvas.pageIndex)
        }

        /// Turns writing mode on or off for every page layer that exists.
        func setPen(_ on: Bool, in view: PDFView) {
            guard on != penActive else { return }
            penActive = on
            for canvas in canvases.allObjects { canvas.isUserInteractionEnabled = on }
            if on {
                focusCurrent(in: view)
            } else {
                for canvas in canvases.allObjects {
                    toolPicker.setVisible(false, forFirstResponder: canvas)
                    canvas.resignFirstResponder()
                }
            }
        }

        /// The tool palette follows whichever page is showing.
        func focusCurrent(in view: PDFView) {
            guard penActive, let current = view.currentPage, let doc = view.document else { return }
            let index = doc.index(for: current)
            let match = canvases.allObjects.compactMap { $0 as? PageCanvasView }.first { $0.pageIndex == index }
            if let match { focus(match) }
        }

        private func focus(_ canvas: PKCanvasView) {
            toolPicker.setVisible(true, forFirstResponder: canvas)
            canvas.becomeFirstResponder()
        }

        @objc func pageChanged(_ note: Notification) {
            guard let view = note.object as? LockedPDFView,
                  view.initialPage == nil,
                  let current = view.currentPage,
                  let doc = view.document else { return }
            let index = doc.index(for: current)
            view.lockDown()
            if parent.page != index { parent.page = index }
            if penActive { DispatchQueue.main.async { self.focusCurrent(in: view) } }
        }

        deinit { NotificationCenter.default.removeObserver(self) }
    }
}

/// A PDFView with every way out removed: no selection menu (Copy / Look Up / Share) and no
/// long-press. Taps work like an e-reader: the outer fifth of the screen turns the page, the middle
/// shows the bar, and a tap on a link follows the link. When zoomed in, every tap is just "show the bar".
final class LockedPDFView: PDFView, UIGestureRecognizerDelegate {
    var onCenterTap: (() -> Void)?
    var initialPage: PDFPage?
    var penMode = false      // while writing, taps do nothing: a resting palm must not turn the page
    private var lastFitSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]   // a finger; not the Pencil
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }
    override var canBecomeFirstResponder: Bool { false }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        if penMode { return }
        let point = gesture.location(in: self)
        highlightedSelections = nil   // a tap clears any search highlight

        if let hitPage = page(for: point, nearest: false),
           hitPage.annotation(at: convert(point, to: hitPage)) != nil {
            return // let the link / form field do its job
        }

        let zoomedIn = scaleFactor > scaleFactorForSizeToFit * 1.05
        if !zoomedIn {
            let fraction = point.x / max(bounds.width, 1)
            if fraction < 0.2 {
                if canGoToPreviousPage { goToPreviousPage(nil) }
                return
            }
            if fraction > 0.8 {
                if canGoToNextPage { goToNextPage(nil) }
                return
            }
        }
        onCenterTap?()
    }

    /// PDFKit builds its internal views lazily, so this is re-run on layout and page change.
    func lockDown() { disableLongPresses(in: self) }

    private func disableLongPresses(in view: UIView) {
        if view is PKCanvasView { return }   // leave the handwriting layers alone
        view.gestureRecognizers?.forEach { if $0 is UILongPressGestureRecognizer { $0.isEnabled = false } }
        view.subviews.forEach(disableLongPresses)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let start = initialPage, bounds.width > 0, bounds.height > 0 {
            initialPage = nil
            go(to: start)
        }

        lockDown()
        // Zoom between "fit to screen" and 4x; refreshed when the iPad rotates.
        if bounds.size != lastFitSize, bounds.width > 0 {
            lastFitSize = bounds.size
            let fit = scaleFactorForSizeToFit
            if fit > 0 {
                minScaleFactor = fit
                maxScaleFactor = fit * 4
            }
        }
    }
}
