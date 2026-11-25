import XCTest

/// One slow, deliberate pass through the app, for a screen recording. The workflow records the
/// simulator while this runs and uses the markers written here (with real clock times) to put
/// captions on the video afterwards. Every step is gentle on failure: if a button is not found
/// the walk-through carries on, so a wrong label costs a caption, not the whole video.
final class WalkthroughTests: XCTestCase {
    private var app: XCUIApplication!
    private let outDir = "/tmp/BriefingWalk"
    private var markers: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchArguments = ["-seedFrom", "/tmp/BriefingSeed"]
    }

    // MARK: Helpers

    /// Records "step name, seconds on the clock" so the captions line up with the video.
    private func mark(_ name: String) {
        markers.append("\(name) \(Date().timeIntervalSince1970)")
        try? markers.joined(separator: "\n").write(
            toFile: "\(outDir)/markers.txt", atomically: true, encoding: .utf8)
    }

    private func hold(_ seconds: UInt32) { sleep(seconds) }

    private func tapEdge(right: Bool) {
        app.coordinate(withNormalizedOffset: CGVector(dx: right ? 0.95 : 0.05, dy: 0.5)).tap()
    }

    private func tapCenter() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Back arrow at the top left of the reader bar (the bar must be showing).
    private func tapBackArrow() {
        let named = app.buttons["Library"]
        if named.exists && named.isHittable {
            named.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.035, dy: 0.045)).tap()
        }
    }

    /// Finds a library card by part of its label, scrolling down then back up, and taps it.
    @discardableResult
    private func openCard(_ text: String) -> Bool {
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
        for _ in 0..<6 {
            if card.exists && card.isHittable { card.tap(); return true }
            app.swipeUp()
        }
        for _ in 0..<12 {
            if card.exists && card.isHittable { card.tap(); return true }
            app.swipeDown()
        }
        XCTFail("Could not find a card containing \"\(text)\"")
        return false
    }

    // MARK: The walk-through

    func testWalkthrough() {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        hold(5)

        mark("library")                   // agenda with NOW and NEXT, the materials beside it
        hold(5)
        app.swipeUp()
        hold(3)
        app.swipeDown()
        hold(2)

        mark("open-book")                 // a board book opens like a book, no clutter
        if openCard("Q4 Board Book") {
            hold(4)

            mark("spreads")               // two facing pages, edge taps turn the spread
            tapEdge(right: true); hold(3)
            tapEdge(right: true); hold(3)
            tapEdge(right: true); hold(3)

            mark("bar")                   // tap the middle: contents, search, bookmark, notes
            tapCenter(); hold(5)
            tapCenter(); hold(2)

            mark("portrait")              // turn the iPad: one page, same place
            XCUIDevice.shared.orientation = .portrait
            hold(4)
            tapEdge(right: true); hold(3)
            XCUIDevice.shared.orientation = .landscapeLeft
            hold(3)

            tapCenter(); hold(2)          // show the bar, then go back to the library
            tapBackArrow()
            hold(3)
        }

        mark("long-report")               // a 320-page report, hundreds of turns away from the start
        if openCard("Annual Report") {
            hold(3)
            for _ in 0..<8 { tapEdge(right: true); sleep(1) }
            hold(2)
            tapCenter(); hold(2)
            tapBackArrow()
            hold(3)
        }

        mark("photo")                     // photos and charts open full screen
        if openCard("Sales Heat Map") {
            hold(5)
            tapBackArrow()
            hold(3)
        }

        mark("manage")                    // how the assistant loads and wipes content
        for _ in 0..<6 { app.swipeDown() }   // the library may be scrolled; the Manage button is in the header
        let manage = app.buttons["Manage content"]
        if manage.waitForExistence(timeout: 5) {
            manage.tap()
            hold(5)
            app.swipeUp()
            hold(4)
            let done = app.buttons["Done"]
            if done.exists { done.tap() }
            hold(2)
        }

        mark("search")                    // find a word in every document on the iPad
        for _ in 0..<6 { app.swipeDown() }
        let search = app.buttons["Search all documents"]
        if search.waitForExistence(timeout: 5) {
            search.tap()
            hold(2)
            let field = app.searchFields.firstMatch
            if field.waitForExistence(timeout: 3) {
                field.tap()
                field.typeText("revenue\n")
                hold(5)
            } else {
                hold(3)
            }
        }

        mark("end")
        hold(2)
    }
}
