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
    /// dashes. Splitting it is what puts the song on the Now Playing title line
    /// instead of the whole blob.
    func testParsesKCRWStyleNoSpaceDashTriple() {
        let result = makeObserver().parseStreamTitle("StreamTitle='Infinity-Hohnen Ford-Infinity';")
        XCTAssertEqual(result?.title, "Infinity")
        XCTAssertEqual(result?.artist, "Hohnen Ford")
        XCTAssertEqual(result?.album, "Infinity")
    }

    func testParsesKCRWTripleWithParentheticalTitle() {
        let result = makeObserver().parseStreamTitle("StreamTitle='Hardy (feat. Clairo)-Rostam-American Music';")
        XCTAssertEqual(result?.title, "Hardy (feat. Clairo)")
        XCTAssertEqual(result?.artist, "Rostam")
        XCTAssertEqual(result?.album, "American Music")
    }

    /// A hyphenated title also splits into three parts, so the parser requires
    /// every component to be at least two characters before trusting the shape.
    func testHyphenatedSingleTitleIsNotSplit() {
        let result = makeObserver().parseStreamTitle("StreamTitle='Rock-N-Roll';")
        XCTAssertEqual(result?.title, "Rock-N-Roll")
        XCTAssertEqual(result?.artist, "")
        XCTAssertNil(result?.album)
    }

    /// Two bare-dash components are ambiguous (artist-title vs a hyphenated
    /// title), so they stay unsplit.
    func testTwoComponentBareDashIsNotSplit() {
        let result = makeObserver().parseStreamTitle("StreamTitle='Ydegirl-Stone Femmes';")
        XCTAssertEqual(result?.title, "Ydegirl-Stone Femmes")
        XCTAssertEqual(result?.artist, "")
    }

    /// The space-padded form stays the primary split and must win over the triple.
    func testSpacedDashTakesPrecedenceOverTriple() {
        let result = makeObserver().parseStreamTitle("StreamTitle='Hohnen Ford - Infinity-Deluxe';")
        XCTAssertEqual(result?.artist, "Hohnen Ford")
        XCTAssertEqual(result?.title, "Infinity-Deluxe")
        XCTAssertNil(result?.album)
    }

    func testAlbumIsCarriedInNotification() {
        let observer = makeObserver()
        var received: String?
        let token = NotificationCenter.default.addObserver(
            forName: .radioStationNowPlayingDidChange, object: nil, queue: nil) { note in
            received = note.userInfo?[RadioMetadataNotificationKey.album] as? String
        }
        defer { NotificationCenter.default.removeObserver(token) }

        observer.emitForTesting(title: "Infinity", artist: "Hohnen Ford", album: "Infinity")

        XCTAssertEqual(received, "Infinity")
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
