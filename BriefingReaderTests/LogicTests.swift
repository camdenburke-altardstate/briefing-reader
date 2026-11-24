import XCTest
@testable import BriefingReader

/// Fast checks of the app's plain logic. Run with Cmd U on the first Mac build: if these pass, the agenda,
/// ordering, naming and meeting.json code behaves as designed, before any device testing.
final class AgendaLogicTests: XCTestCase {

    func testReadsCommonTimeFormats() {
        XCTAssertEqual(AgendaLogic.minutes(from: "09:00"), 540)
        XCTAssertEqual(AgendaLogic.minutes(from: "9:30 AM"), 570)
        XCTAssertEqual(AgendaLogic.minutes(from: "2pm"), 840)
        XCTAssertEqual(AgendaLogic.minutes(from: "2:05 PM"), 845)
        XCTAssertEqual(AgendaLogic.minutes(from: "12:00 AM"), 0)
        XCTAssertEqual(AgendaLogic.minutes(from: "12:30 PM"), 750)
        XCTAssertEqual(AgendaLogic.minutes(from: "14:05"), 845)
        XCTAssertEqual(AgendaLogic.minutes(from: "  10:15 am "), 615)
    }

    func testRefusesUnreadableTimes() {
        XCTAssertNil(AgendaLogic.minutes(from: nil))
        XCTAssertNil(AgendaLogic.minutes(from: ""))
        XCTAssertNil(AgendaLogic.minutes(from: "after lunch"))
        XCTAssertNil(AgendaLogic.minutes(from: "9:75"))
        XCTAssertNil(AgendaLogic.minutes(from: "25:00"))
    }

    func testNowAndNext() {
        let times: [Int?] = [540, 600, nil, 660, 720]
        XCTAssertEqual(AgendaLogic.position(times: times, nowMinutes: 500), AgendaLogic.Position(now: nil, next: 0))
        XCTAssertEqual(AgendaLogic.position(times: times, nowMinutes: 570), AgendaLogic.Position(now: 0, next: 1))
        XCTAssertEqual(AgendaLogic.position(times: times, nowMinutes: 630), AgendaLogic.Position(now: 1, next: 3))
        XCTAssertEqual(AgendaLogic.position(times: times, nowMinutes: 600), AgendaLogic.Position(now: 1, next: 3))
        XCTAssertEqual(AgendaLogic.position(times: times, nowMinutes: 900), AgendaLogic.Position(now: 4, next: nil))
        XCTAssertEqual(AgendaLogic.position(times: [], nowMinutes: 600), AgendaLogic.Position(now: nil, next: nil))
    }

    func testMeetingOrder() {
        let cal = Calendar.current
        let today = Date()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: today))!
        let nextWeek = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: today))!
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today))!

        let keys = [
            AgendaLogic.key(day: nil, title: "Library", isRoot: true, today: today),
            AgendaLogic.key(day: yesterday, title: "Past", isRoot: false, today: today),
            AgendaLogic.key(day: nextWeek, title: "Later", isRoot: false, today: today),
            AgendaLogic.key(day: nil, title: "Undated", isRoot: false, today: today),
            AgendaLogic.key(day: tomorrow, title: "Soon", isRoot: false, today: today),
        ]
        let ordered = keys.sorted { AgendaLogic.areInOrder($0, $1) }.map(\.title)
        XCTAssertEqual(ordered, ["Soon", "Later", "Past", "Undated", "Library"])
    }

    func testClockText() {
        XCTAssertEqual(AgendaLogic.clock(seconds: 75), "1:15")
        XCTAssertEqual(AgendaLogic.clock(seconds: 9), "0:09")
        XCTAssertEqual(AgendaLogic.clock(seconds: 3725), "1:02:05")
        XCTAssertEqual(AgendaLogic.clock(seconds: -5), "0:00")
    }
}

final class MeetingInfoTests: XCTestCase {

    func testDecodesAFullMeetingFile() throws {
        let json = """
        {"title":"Board Meeting","date":"2026-12-08","time":"9:00 AM","location":"Boardroom",
         "confidential":true,"note":"Read first",
         "agenda":[{"time":"9:15 AM","title":"Q4 results","presenter":"Finance","file":"Q4.pdf"}]}
        """
        let info = try JSONDecoder().decode(MeetingInfo.self, from: Data(json.utf8))
        XCTAssertEqual(info.title, "Board Meeting")
        XCTAssertEqual(info.confidential, true)
        XCTAssertEqual(info.agenda?.count, 1)
        XCTAssertEqual(info.agenda?.first?.file, "Q4.pdf")
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: try XCTUnwrap(info.day))
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 12)
        XCTAssertEqual(parts.day, 8)
        XCTAssertTrue(info.subtitle.contains("Boardroom"))
        XCTAssertTrue(info.subtitle.contains("9:00 AM"))
    }

    func testEveryFieldIsOptional() throws {
        let info = try JSONDecoder().decode(MeetingInfo.self, from: Data("{}".utf8))
        XCTAssertNil(info.title)
        XCTAssertNil(info.day)
        XCTAssertEqual(info.subtitle, "")
    }

    func testBadDateIsIgnoredNotFatal() throws {
        let info = try JSONDecoder().decode(MeetingInfo.self, from: Data(#"{"date":"next Tuesday"}"#.utf8))
        XCTAssertNil(info.day)
    }
}

final class ContentTypesTests: XCTestCase {

    func testFileKinds() {
        XCTAssertEqual(MediaKind(fileExtension: "pdf"), .pdf)
        XCTAssertEqual(MediaKind(fileExtension: "JPG"), .image)
        XCTAssertEqual(MediaKind(fileExtension: "mov"), .video)
        XCTAssertEqual(MediaKind(fileExtension: "m4a"), .audio)
        XCTAssertNil(MediaKind(fileExtension: "pptx"))
        XCTAssertNil(MediaKind(fileExtension: "docx"))
    }

    func testReplacedFileGetsANewID() {
        let first = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)
        XCTAssertNotEqual(
            ContentItem.makeID(folder: "Board", fileName: "Deck.pdf", modified: first),
            ContentItem.makeID(folder: "Board", fileName: "Deck.pdf", modified: later))
        XCTAssertNotEqual(
            ContentItem.makeID(folder: "A", fileName: "Deck.pdf", modified: first),
            ContentItem.makeID(folder: "B", fileName: "Deck.pdf", modified: first))
    }
}

final class ContentManagerTests: XCTestCase {

    func testNamesAreSafe() {
        XCTAssertEqual(ContentManager.safeName(".."), "")
        XCTAssertEqual(ContentManager.safeName(".hidden"), "hidden")
        XCTAssertEqual(ContentManager.safeName("a/b:c"), "a-b-c")
        XCTAssertEqual(ContentManager.safeName("  Board Meeting  "), "Board Meeting")
        XCTAssertLessThanOrEqual(ContentManager.safeName(String(repeating: "x", count: 200)).count, 80)
    }

    func testReservedMeetingNamesAreRenamedNotLost() {
        XCTAssertEqual(ContentManager.meetingFolderName("Notes"), "Notes (meeting)")
        XCTAssertEqual(ContentManager.meetingFolderName("inbox"), "inbox (meeting)")
        XCTAssertEqual(ContentManager.meetingFolderName("Annotations"), "Annotations (meeting)")
        XCTAssertEqual(ContentManager.meetingFolderName(""), "Meeting")
        XCTAssertEqual(ContentManager.meetingFolderName("Board Meeting"), "Board Meeting")
    }

    func testDuplicateFileNamesAreNumberedNotOverwritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        XCTAssertEqual(ContentManager.uniqueURL(for: "Plan.pdf", in: dir).lastPathComponent, "Plan.pdf")
        try Data().write(to: dir.appendingPathComponent("Plan.pdf"))
        XCTAssertEqual(ContentManager.uniqueURL(for: "Plan.pdf", in: dir).lastPathComponent, "Plan 2.pdf")
        try Data().write(to: dir.appendingPathComponent("Plan 2.pdf"))
        XCTAssertEqual(ContentManager.uniqueURL(for: "Plan.pdf", in: dir).lastPathComponent, "Plan 3.pdf")
    }

    func testPINRoundTrip() {
        ManagePIN.clear()
        XCTAssertFalse(ManagePIN.isSet)
        ManagePIN.set("4821")
        XCTAssertTrue(ManagePIN.isSet)
        XCTAssertTrue(ManagePIN.verify("4821"))
        XCTAssertFalse(ManagePIN.verify("1234"))
        ManagePIN.clear()
        XCTAssertFalse(ManagePIN.isSet)
    }
}
