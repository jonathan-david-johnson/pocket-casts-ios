import XCTest
@testable import podcasts

final class RadioFavoritesCacheTests: XCTestCase {
    private var defaults: UserDefaults!
    private var cache: RadioFavoritesCache!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "RadioFavoritesCacheTests")
        defaults.removePersistentDomain(forName: "RadioFavoritesCacheTests")
        cache = RadioFavoritesCache(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "RadioFavoritesCacheTests")
        defaults = nil
        cache = nil
        super.tearDown()
    }

    func testColdStartReturnsEmpty() {
        XCTAssertEqual(cache.snapshot(), [])
    }

    func testRoundTripPreservesAllFields() {
        let row = CachedFavoriteStation(
            stationId: "abc",
            name: "KCRW",
            streamUrl: "https://stream.example/kcrw",
            city: "CA, United States",
            logoAsset: "kcrw_logo",
            faviconUrl: "https://example/favicon.png",
            bitrate: 128,
            tracklistUrl: "https://kcrw.com/tracklist.json"
        )
        cache.write([row])
        XCTAssertEqual(cache.snapshot(), [row])
    }

    func testOldCachedDataWithoutTracklistUrlDecodesAsNil() {
        // Simulates data written before tracklistUrl existed on this struct.
        let legacyJSON = """
        [{"stationId":"abc","name":"KCRW","streamUrl":"https://x","city":null,"logoAsset":null,"faviconUrl":null,"bitrate":null}]
        """
        defaults.set(Data(legacyJSON.utf8), forKey: "pocketradio.favoritesCache.v1")
        XCTAssertNil(cache.snapshot().first?.tracklistUrl)
    }

    func testToRadioStationPassesThroughTracklistUrl() {
        let row = CachedFavoriteStation(
            stationId: "abc",
            name: "KCRW",
            streamUrl: "https://stream.example/kcrw",
            city: nil,
            logoAsset: nil,
            faviconUrl: nil,
            bitrate: nil,
            tracklistUrl: "https://kcrw.com/tracklist.json"
        )
        XCTAssertEqual(row.toRadioStation().tracklistUrl, "https://kcrw.com/tracklist.json")
    }

    func testOrderIsPreserved() {
        let a = CachedFavoriteStation(stationId: "a", name: "A", streamUrl: "", city: nil, logoAsset: nil, faviconUrl: nil, bitrate: nil)
        let b = CachedFavoriteStation(stationId: "b", name: "B", streamUrl: "", city: nil, logoAsset: nil, faviconUrl: nil, bitrate: nil)
        let c = CachedFavoriteStation(stationId: "c", name: "C", streamUrl: "", city: nil, logoAsset: nil, faviconUrl: nil, bitrate: nil)
        cache.write([a, b, c])
        XCTAssertEqual(cache.snapshot().map(\.stationId), ["a", "b", "c"])
    }

    func testCorruptDataReturnsEmpty() {
        defaults.set(Data("not json".utf8), forKey: "pocketradio.favoritesCache.v1")
        XCTAssertEqual(cache.snapshot(), [])
    }

    func testWrongShapeReturnsEmpty() {
        let wrongShape = try! JSONEncoder().encode(["just": "a dictionary"])
        defaults.set(wrongShape, forKey: "pocketradio.favoritesCache.v1")
        XCTAssertEqual(cache.snapshot(), [])
    }

    func testClearEmptiesSnapshot() {
        let row = CachedFavoriteStation(stationId: "a", name: "A", streamUrl: "", city: nil, logoAsset: nil, faviconUrl: nil, bitrate: nil)
        cache.write([row])
        XCTAssertFalse(cache.snapshot().isEmpty)
        cache.clear()
        XCTAssertEqual(cache.snapshot(), [])
    }

    func testOptionalFieldsSurviveNil() {
        let row = CachedFavoriteStation(stationId: "a", name: "A", streamUrl: "https://x", city: nil, logoAsset: nil, faviconUrl: nil, bitrate: nil)
        cache.write([row])
        let readBack = cache.snapshot().first
        XCTAssertNil(readBack?.city)
        XCTAssertNil(readBack?.logoAsset)
        XCTAssertNil(readBack?.faviconUrl)
        XCTAssertNil(readBack?.bitrate)
    }
}
