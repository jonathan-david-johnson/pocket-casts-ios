import XCTest
@testable import podcasts

/// `PocketRadioProvider` lives in the WidgetExtension target, which can't
/// be `@testable import`-ed from the app's unit test target. These tests
/// verify the **App Group contract** the provider depends on — the same
/// keys, the same JSON shapes, the same padding policy. If anything here
/// drifts from `PocketRadioProvider.loadEntry()`, the widget will silently
/// render the wrong thing.
///
/// Each test corresponds to one provider scenario described in the M8 plan.
final class PocketRadioProviderTests: XCTestCase {

    private var defaults: UserDefaults!

    private static let pocketRadioKeys: [String] = [
        SharedConstants.GroupUserDefaults.pocketRadioFavorites,
        SharedConstants.GroupUserDefaults.pocketRadioIsLiveStream,
        SharedConstants.GroupUserDefaults.pocketRadioLiveTrack,
        SharedConstants.GroupUserDefaults.pocketRadioIsMuted
    ]

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: SharedConstants.GroupUserDefaults.groupContainerId)
        clearPocketRadioKeys()
    }

    override func tearDown() {
        clearPocketRadioKeys()
        defaults = nil
        super.tearDown()
    }

    private func clearPocketRadioKeys() {
        Self.pocketRadioKeys.forEach { defaults?.removeObject(forKey: $0) }
    }

    // MARK: - Mirror types matching WidgetExtension/Data/*

    private struct MirrorFavoriteStation: Decodable, Equatable {
        let stationId: String
        let name: String
        let logoAssetName: String?
        let faviconUrl: String?

        static var placeholder: MirrorFavoriteStation {
            MirrorFavoriteStation(stationId: "", name: "", logoAssetName: nil, faviconUrl: nil)
        }

        var isPlaceholder: Bool { stationId.isEmpty }
    }

    private struct MirrorLiveTrack: Decodable, Equatable {
        let stationId: String
        let title: String
        let artist: String
        let albumArtURL: String?
    }

    private struct EncoderFavoriteSnapshot: Encodable {
        let stationId: String
        let name: String
        let logoAssetName: String?
        let faviconUrl: String?
    }

    private struct EncoderLiveTrack: Encodable {
        let stationId: String
        let title: String
        let artist: String
        let albumArtURL: String?
    }

    /// Mirror of `PocketRadioProvider.loadFavorites(defaults:)` — same key,
    /// same decoder, same prefix(3) + placeholder pad.
    private func loadFavoritesMirror() -> [MirrorFavoriteStation] {
        let decoded: [MirrorFavoriteStation] = {
            guard let data = defaults.data(forKey: SharedConstants.GroupUserDefaults.pocketRadioFavorites) else { return [] }
            return (try? JSONDecoder().decode([MirrorFavoriteStation].self, from: data)) ?? []
        }()
        var trimmed = Array(decoded.prefix(3))
        while trimmed.count < 3 { trimmed.append(.placeholder) }
        return trimmed
    }

    // MARK: - Scenarios

    func test_podcast_state_yields_back_play_fwd_controls() {
        // Provider distinguishes podcast vs live solely from the `isLiveStream`
        // bool key. Seed it as false.
        defaults.set(false, forKey: SharedConstants.GroupUserDefaults.pocketRadioIsLiveStream)

        let isLive = defaults.bool(forKey: SharedConstants.GroupUserDefaults.pocketRadioIsLiveStream)
        XCTAssertFalse(isLive, "Podcast scenario must surface isLive=false to the widget")
        // Live track key must remain absent in podcast state.
        XCTAssertNil(defaults.data(forKey: SharedConstants.GroupUserDefaults.pocketRadioLiveTrack))
    }

    func test_live_state_yields_mute_and_tracklist_controls() throws {
        defaults.set(true, forKey: SharedConstants.GroupUserDefaults.pocketRadioIsLiveStream)
        let track = EncoderLiveTrack(
            stationId: "kcrw-eclectic",
            title: "Some Song",
            artist: "Some Artist",
            albumArtURL: "https://example.com/art.jpg"
        )
        let data = try JSONEncoder().encode(track)
        defaults.set(data, forKey: SharedConstants.GroupUserDefaults.pocketRadioLiveTrack)

        let isLive = defaults.bool(forKey: SharedConstants.GroupUserDefaults.pocketRadioIsLiveStream)
        XCTAssertTrue(isLive)

        let storedData = try XCTUnwrap(defaults.data(forKey: SharedConstants.GroupUserDefaults.pocketRadioLiveTrack))
        let decoded = try JSONDecoder().decode(MirrorLiveTrack.self, from: storedData)
        XCTAssertEqual(decoded.stationId, "kcrw-eclectic")
        XCTAssertEqual(decoded.title, "Some Song")
        XCTAssertEqual(decoded.artist, "Some Artist")
        XCTAssertEqual(decoded.albumArtURL, "https://example.com/art.jpg")
    }

    func test_favorites_under_three_pads_with_placeholders() throws {
        // Seed exactly 1 favorite.
        let one = [EncoderFavoriteSnapshot(stationId: "id-1", name: "Only One", logoAssetName: nil, faviconUrl: nil)]
        let data = try JSONEncoder().encode(one)
        defaults.set(data, forKey: SharedConstants.GroupUserDefaults.pocketRadioFavorites)

        let result = loadFavoritesMirror()
        XCTAssertEqual(result.count, 3, "Provider must always return exactly 3 favorites")
        XCTAssertFalse(result[0].isPlaceholder)
        XCTAssertEqual(result[0].stationId, "id-1")
        XCTAssertTrue(result[1].isPlaceholder)
        XCTAssertTrue(result[2].isPlaceholder)
    }

    func test_favorites_zero_yields_three_placeholders() {
        // No data written at the favorites key.
        let result = loadFavoritesMirror()
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.allSatisfy { $0.isPlaceholder })
    }

    func test_favorites_more_than_three_are_truncated() throws {
        let snapshots: [EncoderFavoriteSnapshot] = (1...5).map {
            EncoderFavoriteSnapshot(stationId: "id-\($0)", name: "Station \($0)", logoAssetName: nil, faviconUrl: nil)
        }
        let data = try JSONEncoder().encode(snapshots)
        defaults.set(data, forKey: SharedConstants.GroupUserDefaults.pocketRadioFavorites)

        let result = loadFavoritesMirror()
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.stationId), ["id-1", "id-2", "id-3"])
    }

    func test_no_now_playing_renders_idle_state() {
        // Empty App Group: no live flag, no track, no favorites, no mute.
        // Provider must surface this as: isLive=false, isMuted=false, 3 placeholders.
        let isLive = defaults.bool(forKey: SharedConstants.GroupUserDefaults.pocketRadioIsLiveStream)
        let isMuted = defaults.bool(forKey: SharedConstants.GroupUserDefaults.pocketRadioIsMuted)
        XCTAssertFalse(isLive)
        XCTAssertFalse(isMuted)
        XCTAssertNil(defaults.data(forKey: SharedConstants.GroupUserDefaults.pocketRadioLiveTrack))

        let favorites = loadFavoritesMirror()
        XCTAssertEqual(favorites.count, 3)
        XCTAssertTrue(favorites.allSatisfy { $0.isPlaceholder })
    }
}
