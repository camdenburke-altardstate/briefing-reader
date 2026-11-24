import UIKit
import PDFKit
import AVFoundation
import ImageIO
import CryptoKit

/// Reads an image file at screen size instead of full size. A 48 megapixel photo decoded whole
/// takes about 190MB; at 3072 pixels it takes about 38MB, and looks the same on an iPad.
enum ImageLoader {
    static func downsampled(url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Makes the cover of each item once, one at a time (so a 100MB deck never competes with others
/// for memory), and keeps the result in memory and on disk.
actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private let memory = NSCache<NSString, UIImage>()
    private let folder: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// Forgets every cover, in memory and on disk. Used when content is removed, so no picture of a
    /// deleted document is left behind.
    func clearAll() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func thumbnail(for item: ContentItem) -> UIImage? {
        if item.kind == .audio { return nil }

        let key = Self.key(for: item.id)
        if let hit = memory.object(forKey: key as NSString) { return hit }

        let file = folder.appendingPathComponent(key + ".jpg")
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
            memory.setObject(image, forKey: key as NSString)
            return image
        }

        let made: UIImage?
        switch item.kind {
        case .pdf: made = Self.pdfCover(item.url)
        case .image: made = ImageLoader.downsampled(url: item.url, maxPixel: 640)
        case .video: made = Self.videoFrame(item.url, seconds: item.measure)
        case .audio: made = nil
        }
        guard let image = made else { return nil }

        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: file, options: .atomic)
        }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    private static func key(for id: String) -> String {
        SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func pdfCover(_ url: URL) -> UIImage? {
        guard let pdf = PDFDocument(url: url), let page = pdf.page(at: 0) else { return nil }
        var bounds = page.bounds(for: .mediaBox)
        if page.rotation % 180 != 0 {
            bounds = CGRect(x: 0, y: 0, width: bounds.height, height: bounds.width)
        }
        let scale = 640 / max(bounds.height, 1)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        return page.thumbnail(of: size, for: .mediaBox)
    }

    private static func videoFrame(_ url: URL, seconds: Int) -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 960)
        // A frame a little way in, so it is not a black fade-in.
        let at = CMTime(seconds: min(2.0, Double(seconds) / 10), preferredTimescale: 600)
        guard let cg = try? generator.copyCGImage(at: at, actualTime: nil) else { return nil }
        return UIImage(cgImage: cg)
    }
}
