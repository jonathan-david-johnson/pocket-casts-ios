import XCTest
@testable import podcasts

final class LyricsServiceTests: XCTestCase {

    // MARK: - Sanitize

    func testSanitizeRemovesParentheticalQualifiers() {
        XCTAssertEqual(LyricsService.sanitize("Clint Eastwood (Edit) (CLEAN)"), "Clint Eastwood")
    }

    func testSanitizeRemovesBracketQualifiers() {
        XCTAssertEqual(LyricsService.sanitize("Song [Explicit]"), "Song")
    }

    func testSanitizeRemovesDashRemasteredSuffix() {
        XCTAssertEqual(LyricsService.sanitize("Song - Remastered 2010"), "Song")
    }

    func testSanitizeRemovesRadioEdit() {
        XCTAssertEqual(LyricsService.sanitize("Song (Radio Edit)"), "Song")
    }

    func testSanitizeRemovesFeaturingGroup() {
        XCTAssertEqual(LyricsService.sanitize("Song (feat. Artist)"), "Song")
    }

    func testSanitizeLeavesNonQualifierGroups() {
        // "2023" is not a qualifier, so the group should remain.
        XCTAssertEqual(LyricsService.sanitize("Song (2023)"), "Song (2023)")
    }

    func testSanitizeLeavesPlainTitle() {
        XCTAssertEqual(LyricsService.sanitize("Song"), "Song")
    }

    func testSanitizeReturnsEmptyForEmptyString() {
        XCTAssertEqual(LyricsService.sanitize(""), "")
    }

    // MARK: - Current line

    func testCurrentLineFindsFirstLineAtStart() {
        let result = LyricsResult(lines: [
            LyricLine(timestamp: 0, text: "Line 1"),
            LyricLine(timestamp: 5, text: "Line 2")
        ], plain: nil)
        XCTAssertEqual(LyricsService.shared.currentLine(in: result, at: 0)?.text, "Line 1")
    }

    func testCurrentLineAdvancesAtTimestampBoundary() {
        let result = LyricsResult(lines: [
            LyricLine(timestamp: 0, text: "Line 1"),
            LyricLine(timestamp: 5, text: "Line 2"),
            LyricLine(timestamp: 10, text: "Line 3")
        ], plain: nil)
        XCTAssertEqual(LyricsService.shared.currentLine(in: result, at: 4.9)?.text, "Line 1")
        XCTAssertEqual(LyricsService.shared.currentLine(in: result, at: 5)?.text, "Line 2")
        XCTAssertEqual(LyricsService.shared.currentLine(in: result, at: 12)?.text, "Line 3")
    }

    func testCurrentLineReturnsNilForNegativeOffset() {
        let result = LyricsResult(lines: [
            LyricLine(timestamp: 0, text: "Line 1")
        ], plain: nil)
        XCTAssertNil(LyricsService.shared.currentLine(in: result, at: -1))
    }

    // MARK: - LyricsResult

    func testLyricsResultHasSyncedWhenLinesPresent() {
        let result = LyricsResult(lines: [LyricLine(timestamp: 0, text: "Line")], plain: nil)
        XCTAssertTrue(result.hasSynced)
    }

    func testLyricsResultNotSyncedWhenPlainOnly() {
        let result = LyricsResult(lines: [], plain: "Plain lyrics")
        XCTAssertFalse(result.hasSynced)
    }

    func testLyricsResultDuration() {
        let result = LyricsResult(lines: [], plain: nil, duration: 180.5)
        XCTAssertEqual(result.duration, 180.5)
    }
}
