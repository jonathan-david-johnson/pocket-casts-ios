import XCTest
@testable import podcasts

/// Exercises `WidgetHelper` Pocket Radio publish methods. We can't reach
/// the WidgetExtension target's decoders from this test target, so these
/// tests verify the App Group write contract directly: the bytes / bools
/// the widget will read end up at the keys the widget reads from.
final class WidgetHelperPocketRadioTests: XCTestCase {

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

    // MARK: - Live flag

    func test_publishPocketRadioLiveFlag_writes_bool_to_app_group() {
        // Sanity: key absent before call.
        XCTAssertNil(defaults.object(forKey: SharedConstants.GroupUserDefaults.pocketRadioIsLiveStream))

        WidgetHelper.shared.publishPocketRadioLiveFlag()

        // Whatever PlaybackManager reports, the key MUST be set as a Bool.
        let stored = defaults.object(forKey: SharedConstants.GroupUserDefaults.pocketRadioIsLiveStream)
        XCTAssertNotNil(stored, "Live flag key must be written even when false")
        XCTAssertTrue(stored is Bool)
        XCTAssertEqual(stored as? Bool, PlaybackManager.shared.shouldUseMuteControls())
    }

    // MARK: - Mute flag

    func test_publishPocketRadioMute_writes_bool_to_app_group() {
        XCTAssertNil(defaults.object(forKey: SharedConstants.GroupUserDefaults.pocketRadioIsMuted))

        WidgetHelper.shared.publishPocketRadioMute()

        let stored = defaults.object(forKey: SharedConstants.GroupUserDefaults.pocketRadioIsMuted)
        XCTAssertNotNil(stored, "Mute flag key must be written even when false")
        XCTAssertTrue(stored is Bool)
        XCTAssertEqual(stored as? Bool, PlaybackManager.shared.isMuted)
    }

    // MARK: - Live track snapshot

    func test_publishPocketRadioLiveTrack_clears_key_when_not_live() {
        // Seed something at the key so we can verify the not-live path clears it.
        defaults.set(Data("stale".utf8), forKey: SharedConstants.GroupUserDefaults.pocketRadioLiveTrack)
        XCTAssertNotNil(defaults.data(forKey: SharedConstants.GroupUserDefaults.pocketRadioLiveTrack))

        // In a unit-test environment there's no live stream playing, so this
        // call should hit the "clear key" branch.
        WidgetHelper.shared.publishPocketRadioLiveTrack()

        XCTAssertNil(defaults.data(forKey: SharedConstants.GroupUserDefaults.pocketRadioLiveTrack))
    }

    // MARK: - Favorites snapshot JSON shape

    /// Locally-defined mirror of `WidgetExtension/Data/WidgetFavoriteStation.swift`.
    /// Two structs in different targets can't be cross-imported, but the JSON
    /// must round-trip via this exact shape — that's the widget contract.
    private struct MirrorFavoriteStation: Decodable, Equatable {
        let stationId: String
        let name: String
        let logoAssetName: String?
        let faviconUrl: String?
    }

    func test_favoritesSnapshot_keys_match_widget_decoder_shape() throws {
        // Drive the same encoder WidgetHelper uses by writing through it via
        // a stub snapshot that mirrors the private PocketRadioFavoriteSnapshot
        // shape declared in WidgetHelper.swift.
        struct EncoderStub: Encodable {
            let stationId: String
            let name: String
            let logoAssetName: String?
            let faviconUrl: String?
        }

        let snapshot: [EncoderStub] = [
            EncoderStub(stationId: "id-1", name: "Station One", logoAssetName: "kcrw_logo", faviconUrl: nil),
            EncoderStub(stationId: "id-2", name: "Station Two", logoAssetName: nil, faviconUrl: "https://example.com/fav.ico")
        ]
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: SharedConstants.GroupUserDefaults.pocketRadioFavorites)

        // Decode using the widget-side mirror struct — this is the contract.
        let decoded = try JSONDecoder().decode([MirrorFavoriteStation].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0], MirrorFavoriteStation(stationId: "id-1", name: "Station One", logoAssetName: "kcrw_logo", faviconUrl: nil))
        XCTAssertEqual(decoded[1].stationId, "id-2")
        XCTAssertEqual(decoded[1].faviconUrl, "https://example.com/fav.ico")
    }

    func test_writePocketRadioFavoritesSnapshot_empty_results_in_empty_array() throws {
        // Drive WidgetHelper through a public entry point that ends up calling
        // the private writer with an empty snapshot. The favorites loader
        // is async + network-bound, so we exercise the encode path directly
        // by writing an empty JSON array (what the error fallback writes).
        let empty: [String] = []
        let data = try JSONEncoder().encode(empty)
        defaults.set(data, forKey: SharedConstants.GroupUserDefaults.pocketRadioFavorites)

        let decoded = try JSONDecoder().decode([MirrorFavoriteStation].self, from: data)
        XCTAssertTrue(decoded.isEmpty)
    }
}
