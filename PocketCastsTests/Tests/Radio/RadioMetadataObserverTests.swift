import XCTest
@testable import podcasts

final class RadioMetadataObserverTests: XCTestCase {
    private func makeObserver() -> RadioMetadataObserver {
        RadioMetadataObserver(stationId: "test")
    }

    func testParsesArtistAndTitleSeparator() {
        let result = makeObserver().parseStreamTitle("StreamTitle='Artist - Track';")
        XCTAssertEqual(result?.artist, "Artist")
        XCTAssertEqual(result?.title, "Track")
    }

    func testParsesTitleOnlyWhenNoSeparator() {
        let result = makeObserver().parseStreamTitle("StreamTitle='Title only';")
        XCTAssertEqual(result?.artist, "")
        XCTAssertEqual(result?.title, "Title only")
    }

    func testRejectsAdFrame() {
        let result = makeObserver().parseStreamTitle("StreamTitle='';adw_ad='true';durationMilliseconds='14024';")
        XCTAssertNil(result)
    }

    func testRejectsEmptyStreamTitle() {
        let result = makeObserver().parseStreamTitle("StreamTitle='';StreamUrl='';")
        XCTAssertNil(result)
    }

    func testHandlesUnframedStringFromInBandID3() {
        let result = makeObserver().parseStreamTitle("Artist - Track")
        XCTAssertEqual(result?.artist, "Artist")
        XCTAssertEqual(result?.title, "Track")
    }

    // MARK: - Junk title rejection (station automation pseudo-songs)

    func testRejectsPrerollAsTitle() {
        XCTAssertNil(makeObserver().parseStreamTitle("StreamTitle='preroll';"))
    }

    func testRejectsMidrollAsTitle() {
        XCTAssertNil(makeObserver().parseStreamTitle("StreamTitle='midroll';"))
    }

    func testRejectsBreakBracketRow() {
        XCTAssertNil(makeObserver().parseStreamTitle("StreamTitle='[BREAK]';"))
    }

    // MARK: - KCRW ICY shape (no-space dash)

    /// KCRW emits `StreamTitle='Title-Artist-Album'` with no spaces around the
    /// dashes. The parser only splits on `" - "` (space-padded), so this returns
    /// `(artist: "", title: full)`. M7.2 routes this through
    /// `TrackArtworkResolver.bestResolveEntry`, which prefers the cached
    /// tracklist's top entry over the un-parseable ICY frame.
    func testParsesKCRWStyleNoSpaceDashAsTitleOnly() {
        let result = makeObserver().parseStreamTitle("StreamTitle='Infinity-Hohnen Ford-Infinity';")
        XCTAssertEqual(result?.artist, "")
        XCTAssertEqual(result?.title, "Infinity-Hohnen Ford-Infinity")
    }

    func testDedupesIdenticalConsecutiveEmissions() {
        let observer = makeObserver()
        var count = 0
        let token = NotificationCenter.default.addObserver(
            forName: .radioStationNowPlayingDidChange, object: nil, queue: nil) { _ in
            count += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        observer.emitForTesting(title: "Song", artist: "Band")
        observer.emitForTesting(title: "Song", artist: "Band")

        XCTAssertEqual(count, 1)
    }
}
