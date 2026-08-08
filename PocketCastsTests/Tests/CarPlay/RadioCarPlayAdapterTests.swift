import CarPlay
import XCTest
@testable import podcasts

/// `CPListItem` is constructible in a simulator-hosted test but exposes almost
/// nothing readable — `handler` is write-only and there is no accessor for a
/// section's item text. Assertions stay on what CarPlay genuinely surfaces;
/// everything behavioural is covered by `RadioCarPlayRowBuilderTests` and
/// `RadioPlaybackStarterTests`.
class RadioCarPlayAdapterTests: XCTestCase {
    private func row(
        stationId: String = "station-1",
        title: String = "KEXP",
        detail: String? = "Seattle",
        logoAsset: String? = nil,
        faviconUrl: String? = nil,
        streamUrl: String = "https://example.com/stream",
        isPlaying: Bool = false
    ) -> RadioCarPlayRow {
        RadioCarPlayRow(
            stationId: stationId,
            title: title,
            detail: detail,
            logoAsset: logoAsset,
            faviconUrl: faviconUrl,
            streamUrl: streamUrl,
            isPlaying: isPlaying
        )
    }

    private func makeDelegate() -> CarPlaySceneDelegate {
        CarPlaySceneDelegate()
    }

    func testSectionCountMatchesModel() {
        let delegate = makeDelegate()
        let model = [
            RadioCarPlaySection(header: "Favorites", rows: [row()]),
            RadioCarPlaySection(header: "Stations", rows: [row(stationId: "station-2")])
        ]

        let sections = model.map { delegate.convertToListSection($0) }

        XCTAssertEqual(sections.count, 2)
    }

    func testItemCountMatchesRows() {
        let delegate = makeDelegate()
        let rows = (0..<5).map { row(stationId: "station-\($0)") }

        let section = delegate.convertToListSection(RadioCarPlaySection(header: "Stations", rows: rows))

        XCTAssertEqual(section.items.count, 5)
    }

    func testEmptySectionProducesNoItems() {
        let delegate = makeDelegate()

        let section = delegate.convertToListSection(RadioCarPlaySection(header: "Favorites", rows: []))

        XCTAssertEqual(section.items.count, 0)
    }

    func testSectionHeaderCarriedThrough() {
        let delegate = makeDelegate()

        let section = delegate.convertToListSection(RadioCarPlaySection(header: "Favorites", rows: [row()]))

        XCTAssertEqual(section.header, "Favorites")
    }

    // MARK: - Routing

    func testCuratedRowRoutesToAsyncResolve() {
        XCTAssertTrue(RadioCarPlayRouting.needsResolution(streamUrl: ""))
    }

    func testFavoriteRowRoutesToSyncPlay() {
        XCTAssertFalse(RadioCarPlayRouting.needsResolution(streamUrl: "https://example.com/stream"))
    }

    // MARK: - Row → RadioStation

    func testToRadioStationCarriesIdentityAndStream() {
        let station = row(
            stationId: "445cbb3a",
            title: "KEXP",
            detail: "Seattle",
            logoAsset: "kexp_logo",
            streamUrl: "https://example.com/kexp"
        ).toRadioStation()

        XCTAssertEqual(station.uuid, "445cbb3a")
        XCTAssertEqual(station.stationId, "445cbb3a")
        XCTAssertEqual(station.title, "KEXP")
        XCTAssertEqual(station.streamUrl, "https://example.com/kexp")
        XCTAssertEqual(station.downloadUrl, "https://example.com/kexp")
        XCTAssertEqual(station.city, "Seattle")
        XCTAssertEqual(station.logoAsset, "kexp_logo")
    }
}
