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
