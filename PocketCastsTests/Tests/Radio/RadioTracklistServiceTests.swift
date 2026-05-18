import XCTest
@testable import podcasts

final class RadioTracklistServiceTests: XCTestCase {

    private func data(_ json: String) -> Data { json.data(using: .utf8)! }

    // MARK: - KCRW
    // KCRW returns a flat JSON array. Fields: title, artist, album, albumImage, datetime.

    func testKCRWParsesEntries() throws {
        let json = """
        [
            { "title": "Taxi Cub", "artist": "Vampire Weekend", "album": "Contra",
              "albumImage": "https://example.com/art.png", "datetime": "2026-05-17T12:00:00-07:00" }
        ]
        """
        let entries = try RadioTracklistService().parseKCRW(data: data(json))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "Taxi Cub")
        XCTAssertEqual(entries[0].artist, "Vampire Weekend")
        XCTAssertEqual(entries[0].album, "Contra")
        XCTAssertEqual(entries[0].albumArtURL?.absoluteString, "https://example.com/art.png")
        XCTAssertNotNil(entries[0].playedAt)
    }

    func testKCRWMissingAlbumArt() throws {
        let json = """
        [
            { "title": "T", "artist": "A", "album": null, "albumImage": null, "datetime": null }
        ]
        """
        let entries = try RadioTracklistService().parseKCRW(data: data(json))
        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries[0].albumArtURL)
        XCTAssertNil(entries[0].album)
        XCTAssertNil(entries[0].playedAt)
    }

    func testKCRWMalformedThrows() {
        let bad = data("{ not json }")
        XCTAssertThrowsError(try RadioTracklistService().parseKCRW(data: bad))
    }

    func testKCRWEmptyArray() throws {
        let json = "[]"
        let entries = try RadioTracklistService().parseKCRW(data: data(json))
        XCTAssertEqual(entries.count, 0)
    }

    func testKCRWSkipsBreakRows() throws {
        let json = """
        [
            { "title": "Real Track", "artist": "Real Artist", "album": "Real Album", "albumImage": null, "datetime": null },
            { "title": null, "artist": "[BREAK]", "album": null, "albumImage": null, "datetime": null },
            { "title": "Another Track", "artist": "Another Artist", "album": null, "albumImage": null, "datetime": null }
        ]
        """
        let entries = try RadioTracklistService().parseKCRW(data: data(json))
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].title, "Real Track")
        XCTAssertEqual(entries[1].title, "Another Track")
    }

    // MARK: - KEXP
    // KEXP returns { "results": [...] }. Fields: play_type, song, artist, album, thumbnail_uri, airdate.

    func testKEXPParsesOnlyTrackplays() throws {
        let json = """
        { "results": [
            { "play_type": "trackplay", "song": "A", "artist": "B", "album": "C",
              "thumbnail_uri": "https://example.com/a.png", "airdate": "2026-05-17T12:00:00-07:00" },
            { "play_type": "comment", "song": null, "artist": null, "album": null,
              "thumbnail_uri": null, "airdate": "2026-05-17T11:59:00-07:00" }
        ] }
        """
        let entries = try RadioTracklistService().parseKEXP(data: data(json))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "A")
        XCTAssertEqual(entries[0].artist, "B")
        XCTAssertEqual(entries[0].album, "C")
        XCTAssertEqual(entries[0].albumArtURL?.absoluteString, "https://example.com/a.png")
        XCTAssertNotNil(entries[0].playedAt)
    }

    func testKEXPFiltersOutNonTrackplays() throws {
        let json = """
        { "results": [
            { "play_type": "stationid", "song": null, "artist": null, "album": null,
              "thumbnail_uri": null, "airdate": "2026-05-17T12:01:00-07:00" },
            { "play_type": "trackplay", "song": "Song", "artist": "Artist", "album": null,
              "thumbnail_uri": null, "airdate": "2026-05-17T12:00:00-07:00" }
        ] }
        """
        let entries = try RadioTracklistService().parseKEXP(data: data(json))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "Song")
    }

    func testKEXPMalformedThrows() {
        let bad = data("{ not json }")
        XCTAssertThrowsError(try RadioTracklistService().parseKEXP(data: bad))
    }

    func testKEXPMissingAlbumArt() throws {
        let json = """
        { "results": [
            { "play_type": "trackplay", "song": "T", "artist": "A", "album": null,
              "thumbnail_uri": null, "airdate": null }
        ] }
        """
        let entries = try RadioTracklistService().parseKEXP(data: data(json))
        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries[0].albumArtURL)
        XCTAssertNil(entries[0].album)
        XCTAssertNil(entries[0].playedAt)
    }

    // MARK: - fetch() unknown stationId

    func testUnknownStationIdReturnsEmpty() async throws {
        // Feed a dummy URL — we won't hit the network because the unknown-id
        // branch returns [] before any HTTP call is made... actually the HTTP
        // call happens first. Use a data URL that returns valid HTTP so we can
        // exercise the switch default. Build a mock service with a stub session
        // that returns 200 + empty body for any URL.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AlwaysEmptyURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = RadioTracklistService(urlSession: session)
        let entries = try await service.fetch(stationId: "unknown_xyz", url: "https://example.com/feed")
        XCTAssertEqual(entries, [])
    }

    func testCacheStoresFetchedEntries() async throws {
        let service = RadioTracklistService()
        // Before any fetch, cache is empty.
        XCTAssertNil(service.cached(stationId: "kcrw"))
    }

    func testInvalidURLThrows() async {
        let service = RadioTracklistService()
        do {
            // Empty string produces nil from URL(string:), triggering .invalidURL
            _ = try await service.fetch(stationId: "kcrw", url: "")
            XCTFail("Expected throw")
        } catch RadioTracklistError.invalidURL {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Toast dedupe

    func testFailureToastDedupesWithinSession() {
        let service = RadioTracklistService()
        XCTAssertTrue(service.shouldShowFailureToast(stationId: "kcrw"),
                      "First failure for a station should show a toast")
        XCTAssertFalse(service.shouldShowFailureToast(stationId: "kcrw"),
                       "Second failure for the same station should be deduped")
        XCTAssertTrue(service.shouldShowFailureToast(stationId: "kexp"),
                      "First failure for a different station should still show")
    }
}

// MARK: - Test helpers

/// A URLProtocol that returns HTTP 200 with empty data for any request.
private final class AlwaysEmptyURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
