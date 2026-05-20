import XCTest
@testable import podcasts

final class TrackArtworkResolverTests: XCTestCase {

    private func makeStation() -> RadioStation {
        RadioStation(stationId: "test-uuid", name: "Test", streamUrl: "https://example/stream")
    }

    // MARK: - Direct tracklist URL short-circuit

    func testEntryWithAlbumArtURLReturnsItDirectly() {
        let resolver = TrackArtworkResolver()
        let url = URL(string: "https://i.scdn.co/image/abc")!
        let entry = TracklistEntry(title: "Song", artist: "Artist", album: nil, albumArtURL: url, playedAt: nil)

        let exp = expectation(description: "completion")
        var resolved: URL?
        resolver.artworkURL(for: entry, station: makeStation()) { result in
            resolved = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(resolved, url)
    }

    // MARK: - Caching

    func testSecondCallForSameEntryHitsCacheWithoutNetwork() {
        let resolver = TrackArtworkResolver()
        let url = URL(string: "https://i.scdn.co/image/abc")!
        let entry = TracklistEntry(title: "Song", artist: "Artist", album: nil, albumArtURL: url, playedAt: nil)

        let exp1 = expectation(description: "first")
        resolver.artworkURL(for: entry, station: makeStation()) { _ in exp1.fulfill() }
        wait(for: [exp1], timeout: 1.0)

        // Now call again with NO albumArtURL but matching artist/title — must
        // return the previously cached URL without going to the network.
        let bareEntry = TracklistEntry(title: "Song", artist: "Artist", album: nil, albumArtURL: nil, playedAt: nil)
        let exp2 = expectation(description: "second")
        var resolved: URL?
        resolver.artworkURL(for: bareEntry, station: makeStation()) { result in
            resolved = result
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1.0)
        XCTAssertEqual(resolved, url)
    }

    // MARK: - iTunes URL builder

    func testItunesSearchURLEncodesTerm() {
        let url = TrackArtworkResolver.itunesSearchURL(artist: "Bon Iver", title: "Holocene")
        XCTAssertNotNil(url)
        let absolute = url!.absoluteString
        XCTAssertTrue(absolute.hasPrefix("https://itunes.apple.com/search?"))
        XCTAssertTrue(absolute.contains("entity=song"))
        XCTAssertTrue(absolute.contains("limit=1"))
        // "Bon Iver Holocene" — space encoded as %20 by URLComponents
        XCTAssertTrue(absolute.contains("Bon%20Iver%20Holocene") || absolute.contains("Bon+Iver+Holocene"))
    }

    func testItunesSearchURLNilForBlankTerm() {
        XCTAssertNil(TrackArtworkResolver.itunesSearchURL(artist: "", title: ""))
        XCTAssertNil(TrackArtworkResolver.itunesSearchURL(artist: "  ", title: "  "))
    }

    // MARK: - iTunes response parsing

    func testParseITunesArtworkURLUpgradesTo600() {
        let json = """
        {"resultCount":1,"results":[{"artworkUrl100":"https://is1-ssl.mzstatic.com/image/abc/100x100bb.jpg"}]}
        """.data(using: .utf8)!
        let url = TrackArtworkResolver.parseITunesArtworkURL(from: json)
        XCTAssertEqual(url?.absoluteString, "https://is1-ssl.mzstatic.com/image/abc/600x600bb.jpg")
    }

    func testParseITunesArtworkURLNilForEmptyResults() {
        let json = """
        {"resultCount":0,"results":[]}
        """.data(using: .utf8)!
        XCTAssertNil(TrackArtworkResolver.parseITunesArtworkURL(from: json))
    }

    func testParseITunesArtworkURLNilForGarbage() {
        XCTAssertNil(TrackArtworkResolver.parseITunesArtworkURL(from: Data("not json".utf8)))
    }

    // MARK: - KCRW JSON shape (large-or-small fallback)

    func testKCRWParserPrefersAlbumImageLargeOverAlbumImage() throws {
        let json = """
        [{
          "title": "Song",
          "artist": "Artist",
          "album": "Album",
          "albumImage": "https://i.scdn.co/image/small",
          "albumImageLarge": "https://i.scdn.co/image/large",
          "datetime": "2026-05-18T12:00:00-07:00"
        }]
        """.data(using: .utf8)!
        let entries = try RadioTracklistService().parseKCRW(data: json)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.albumArtURL?.absoluteString, "https://i.scdn.co/image/large")
    }

    func testKCRWParserFallsBackToAlbumImageWhenLargeMissing() throws {
        let json = """
        [{
          "title": "Song",
          "artist": "Artist",
          "album": null,
          "albumImage": "https://i.scdn.co/image/small",
          "albumImageLarge": null,
          "datetime": null
        }]
        """.data(using: .utf8)!
        let entries = try RadioTracklistService().parseKCRW(data: json)
        XCTAssertEqual(entries.first?.albumArtURL?.absoluteString, "https://i.scdn.co/image/small")
    }

    func testKCRWParserNilArtURLWhenBothMissing() throws {
        let json = """
        [{
          "title": "Song",
          "artist": "Artist",
          "album": null,
          "albumImage": null,
          "albumImageLarge": null,
          "datetime": null
        }]
        """.data(using: .utf8)!
        let entries = try RadioTracklistService().parseKCRW(data: json)
        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries.first?.albumArtURL)
    }
}
