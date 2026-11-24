import SwiftUI
import UIKit

/// Opens the right viewer for a file.
struct ViewerScreen: View {
    let item: ContentItem
    let collection: ContentCollection
    /// Open a PDF on this page instead of where it was last left (used by search results).
    var startPage: Int? = nil

    var body: some View {
        switch item.kind {
        case .pdf:
            ReaderView(document: item, collection: collection, startPage: startPage)
        case .image:
            ImageGalleryView(collection: collection, start: item)
        case .video, .audio:
            MediaPlayerView(item: item, collection: collection)
        }
    }
}

// MARK: - Photos

/// Swipe through a meeting's images. Pinch or double-tap to zoom. Tap to show or hide the bar.
struct ImageGalleryView: View {
    let collection: ContentCollection
    let start: ContentItem

    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var chromeVisible = false

    init(collection: ContentCollection, start: ContentItem) {
        self.collection = collection
        self.start = start
        // Start on the tapped photo right away, so the first photo is not decoded for nothing.
        let photos = collection.items.filter { $0.kind == .image }
        _index = State(initialValue: photos.firstIndex { $0.id == start.id } ?? 0)
    }

    private var images: [ContentItem] { collection.items.filter { $0.kind == .image } }

    var body: some View {
        ZStack {
            Brand.media.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(images.enumerated()), id: \.element.id) { position, image in
                    ZoomableImage(url: image.url) {
                        withAnimation(.easeInOut(duration: 0.2)) { chromeVisible.toggle() }
                    }
                    .ignoresSafeArea()
                    .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                if chromeVisible { topBar }
                Spacer()
                if !chromeVisible { footer }
            }
        }
        .statusBarHidden(true)
        .onAppear { store.markOpened(start) }
        .onDisappear { store.commitProgress() }
    }

    private var topBar: some View {
        ZStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 20)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Library")
                Spacer()
                NotesButton(collection: collection, tint: .white)
                DisplayButton(tint: .white)
            }
            Text(images.indices.contains(index) ? images[index].title : "")
                .font(Brand.font(.medium, 17, .headline))
                .lineLimit(1)
                .padding(.horizontal, 180)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .transition(.opacity)
    }

    /// Quiet position readout, like the footer in a book.
    private var footer: some View {
        HStack {
            Text("\(index + 1) of \(images.count)")
            Spacer()
            StatusCluster(tint: Color.white.opacity(0.55))
        }
        .font(Brand.font(.book, 13, .footnote))
        .foregroundStyle(Color.white.opacity(0.55))
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }
}

/// One photo that can be pinched and panned. Loaded at screen size, not full size.
struct ZoomableImage: UIViewRepresentable {
    let url: URL
    var onTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> ZoomScrollView {
        let scroll = ZoomScrollView()
        scroll.delegate = context.coordinator
        context.coordinator.scroll = scroll

        let double = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        double.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(double)

        let single = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.singleTap(_:)))
        single.require(toFail: double)
        scroll.addGestureRecognizer(single)

        let url = url
        DispatchQueue.global(qos: .userInitiated).async {
            let image = ImageLoader.downsampled(url: url, maxPixel: 3072)
            DispatchQueue.main.async { scroll.imageView.image = image }
        }
        return scroll
    }

    func updateUIView(_ view: ZoomScrollView, context: Context) {
        context.coordinator.onTap = onTap
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var onTap: () -> Void
        weak var scroll: ZoomScrollView?

        init(onTap: @escaping () -> Void) { self.onTap = onTap }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { scroll?.imageView }

        @objc func singleTap(_ gesture: UITapGestureRecognizer) { onTap() }

        @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll else { return }
            if scroll.zoomScale > scroll.minimumZoomScale + 0.01 {
                scroll.setZoomScale(scroll.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: scroll.imageView)
                let scale: CGFloat = 2.5
                let size = CGSize(width: scroll.bounds.width / scale, height: scroll.bounds.height / scale)
                let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
                scroll.zoom(to: rect, animated: true)
            }
        }
    }
}

final class ZoomScrollView: UIScrollView {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bouncesZoom = true
        contentInsetAdjustmentBehavior = .never
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // At fit size the image view simply fills the screen; zooming scales it from there.
        if abs(zoomScale - minimumZoomScale) < 0.001 {
            imageView.frame = bounds
            contentSize = bounds.size
        }
    }
}
