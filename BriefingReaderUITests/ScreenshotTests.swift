import XCTest

/// Runs the real app in an iPad simulator, opens the main screens and saves a screenshot of each
/// into /tmp/BriefingShots (and into the test results). It is a look-and-feel check, not a pass/fail
/// rule: a step that cannot find its button logs a failure and the rest still run, so one wrong
/// label does not hide the other pictures.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private let outDir = "/tmp/BriefingShots"

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchArguments = ["-seedFrom", "/tmp/BriefingSeed"]
    }

    // MARK: Helpers

    private func start(landscape: Bool) {
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        app.launch()
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        sleep(4)   // first launch also loads the sample content and draws the covers
    }

    private func shot(_ name: String) {
        sleep(1)
        let screenshot = app.screenshot()
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Scrolls the library until a card whose label contains `text` can be tapped, then taps it.
    @discardableResult
    private func open(_ text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let card = app.buttons.matching(predicate).firstMatch
        for _ in 0..<8 {
            if card.exists && card.isHittable {
                card.tap()
                sleep(3)
                return true
            }
            app.swipeUp()
        }
        XCTFail("Could not find a card containing \"\(text)\"")
        return false
    }

    private func tapEdge(right: Bool) {
        app.coordinate(withNormalizedOffset: CGVector(dx: right ? 0.95 : 0.05, dy: 0.5)).tap()
        sleep(1)
    }

    private func tapCenter() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(1)
    }

    // MARK: Library

    func test01_LibraryLandscape() {
        start(landscape: true)
        shot("01-library-landscape")
        app.swipeUp()
        shot("02-library-landscape-scrolled")
    }

    func test02_LibraryPortrait() {
        start(landscape: false)
        shot("03-library-portrait")
        app.swipeUp()
        shot("04-library-portrait-scrolled")
    }

    // MARK: Reading

    func test03_BoardBookLandscape() {
        start(landscape: true)
        guard open("Q4 Board Book") else { return }
        shot("10-board-book-landscape-cover")
        tapEdge(right: true)
        shot("11-board-book-landscape-spread")
        tapEdge(right: true)
        tapEdge(right: true)
        shot("12-board-book-landscape-later")
        tapCenter()
        shot("13-board-book-landscape-bar")
    }

    func test04_BoardBookPortrait() {
        start(landscape: false)
        guard open("Q4 Board Book") else { return }
        shot("20-board-book-portrait-cover")
        tapEdge(right: true)
        tapEdge(right: true)
        shot("21-board-book-portrait-page")
        tapCenter()
        shot("22-board-book-portrait-bar")
    }

    func test05_LongReport() {
        start(landscape: true)
        guard open("Annual Report") else { return }
        shot("30-long-report-open")
        for _ in 0..<4 { tapEdge(right: true) }
        shot("31-long-report-after-turns")
        tapCenter()
        shot("32-long-report-bar")
    }

    func test06_SlideDeck() {
        start(landscape: true)
        guard open("Holiday Plan") else { return }
        shot("40-slide-deck-landscape")
    }

    // MARK: Other content and screens

    func test07_Photo() {
        start(landscape: true)
        guard open("Sales Heat Map") else { return }
        shot("50-photo")
    }

    func test08_Video() {
        start(landscape: true)
        guard open("Store Walkthrough") else { return }
        shot("51-video")
    }

    func test09_Manage() {
        start(landscape: true)
        let manage = app.buttons["Manage content"]
        if manage.waitForExistence(timeout: 5) {
            manage.tap()
            sleep(2)
            shot("60-manage")
        } else {
            XCTFail("No Manage button")
        }
    }

    func test10_Search() {
        start(landscape: true)
        let search = app.buttons["Search all documents"]
        if search.waitForExistence(timeout: 5) {
            search.tap()
            sleep(2)
            shot("61-search")
        } else {
            XCTFail("No Search button")
        }
    }
}
