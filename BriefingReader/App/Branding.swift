import SwiftUI
import UIKit

/// Everything that makes the app look like Altar'd State lives here.
///
/// Source of the values: the company wordmark (charcoal #363636 on white, wide letter-spacing)
/// and altardstate.com, which sets its type in Avenir and Gill Sans. Avenir ships with iPadOS,
/// so no font files are bundled. The site's headline face (Trenda) is licensed and is not used.
/// To restyle the app, change this file only.
enum Brand {
    // MARK: Colors (hex RGB)
    static let ink: Color = Color(hex: 0x363636)            // wordmark charcoal, primary text and controls
    static let inkSecondary: Color = Color(hex: 0x6B6B6B)   // captions
    static let hairline: Color = Color(hex: 0xE3E1DE)       // borders and dividers
    static let paper: Color = Color(hex: 0xFFFFFF)          // library and chrome background
    static let well: Color = Color(hex: 0xF7F6F4)           // behind covers
    static let backdrop: Color = Color(hex: 0xF1F0EE)       // behind PDF pages so page edges show
    static let backdropUI: UIColor = UIColor(hex: 0xF1F0EE)

    static let media: Color = Color(hex: 0x111111)          // behind photos and video

    // MARK: Type
    enum Weight: String {
        case light = "Avenir-Light"
        case book = "Avenir-Book"
        case medium = "Avenir-Medium"
        case heavy = "Avenir-Heavy"
    }

    static func font(_ weight: Weight, _ size: CGFloat, _ style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }
}

/// Feature switches. Each can be turned off in one line if it misbehaves on a device.
enum Features {
    /// Handwriting on PDF pages with Apple Pencil (PencilKit drawn over each page). When false the
    /// pen button is hidden and none of the markup code runs.
    static let pencilMarkup = true
}

/// How the PDF reader lays pages out.
enum ReaderLayout {
    /// Landscape iPad plus portrait-shaped pages shows two pages side by side like an open book (the
    /// Books app), with the cover alone on the right. Slide decks and portrait iPads always show one
    /// page. Set this to false for one page everywhere: a one-line fallback if PDFKit's two-page
    /// paging misbehaves on a device.
    static let useSpreads = true
}

/// Paper tone for reading PDFs, like the themes in Books and Kindle. Chosen from the sun button.
enum ReadingTone: String, CaseIterable, Identifiable {
    case standard, warm, night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "White"
        case .warm: return "Warm"
        case .night: return "Night"
        }
    }

    var backdrop: Color {
        switch self {
        case .standard: return Brand.backdrop
        case .warm: return Color(hex: 0xEADFC8)
        case .night: return Color(hex: 0x16161A)
        }
    }

    /// Quiet text (footer) on that backdrop.
    var quietInk: Color {
        switch self {
        case .standard: return Brand.inkSecondary
        case .warm: return Color(hex: 0x7A6F5A)
        case .night: return Color(hex: 0x8E8E93)
        }
    }
}

extension View {
    /// Tints the page itself. Night inverts the page, so photos in a PDF look negative; that is the
    /// usual trade in PDF readers.
    @ViewBuilder func readingTone(_ tone: ReadingTone) -> some View {
        switch tone {
        case .standard: self
        case .warm: self.colorMultiply(Color(hex: 0xF6EAD0))
        case .night: self.colorInvert()
        }
    }
}

/// Text shown on the library screen. Change these to retitle.
enum Branding {
    static let companyName = "Altar'd State"
    static let libraryTitle = "Executive Briefings"
    static let emptyMessage = "No briefing materials have been loaded."
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}

/// Soft press feedback for cards and buttons.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
