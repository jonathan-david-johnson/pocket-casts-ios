import XCTest
@testable import podcasts

class RadioCarPlayRowBuilderTests: XCTestCase {
    private func favorite(
        stationId: String = "fav-1",
        name: String = "Favorite Station",
        streamUrl: String = "https://example.com/stream",
        city: String? = "London",
        logoAsset: String? = "logo",
        faviconUrl: String? = "https://example.com/favicon.png",
        bitrate: Int? = 128
    ) -> CachedFavoriteStation {
        CachedFavoriteStation(
            stationId: stationId,
            name: name,
            streamUrl: streamUrl,
            city: city,
            logoAsset: logoAsset,
            faviconUrl: faviconUrl,
            bitrate: bitrate
        )
    }

    func testSignedOutOmitsFavoritesSection() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [favorite()],
            isSignedIn: false,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections.count, 0)
    }

    func testEmptyFavoritesOmitsFavoritesSection() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [],
            isSignedIn: true,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections.count, 0)
    }

    func testFavoritesSectionWhenSignedInAndPresent() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [favorite()],
            isSignedIn: true,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].header, L10n.carplayRadioFavorites)
    }

    func testIsPlayingSetWhenStationIdMatches() {
        let sharedId = "shared-station"
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [favorite(stationId: sharedId)],
            isSignedIn: true,
            nowPlayingStationId: sharedId,
            maxRowsPerSection: 100
        )

        XCTAssertTrue(sections[0].rows[0].isPlaying)
    }

    func testIsPlayingFalseWhenNilNowPlaying() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [favorite()],
            isSignedIn: true,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertFalse(sections[0].rows[0].isPlaying)
    }

    func testFavoritesCappedAtMax() {
        let favorites = (0..<150).map { favorite(stationId: "fav-\($0)") }
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: favorites,
            isSignedIn: true,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections[0].rows.count, 100)
    }

    func testFavoriteRowFieldsMapped() {
        let station = favorite(
            stationId: "fav-42",
            name: "KEXP",
            streamUrl: "https://stream.example.com/kexp",
            city: "Seattle",
            logoAsset: "kexp-logo",
            faviconUrl: "https://example.com/kexp-favicon.png",
            bitrate: 320
        )
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [station],
            isSignedIn: true,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        let row = sections[0].rows[0]
        XCTAssertEqual(row.stationId, "fav-42")
        XCTAssertEqual(row.title, "KEXP")
        XCTAssertEqual(row.detail, "Seattle")
        XCTAssertEqual(row.logoAsset, "kexp-logo")
        XCTAssertEqual(row.faviconUrl, "https://example.com/kexp-favicon.png")
        XCTAssertEqual(row.streamUrl, "https://stream.example.com/kexp")
    }

    /// A favorite can carry an empty stream URL when `RadioFavoritesService`
    /// kept the row for its curated enhancement despite radio-browser metadata
    /// failing to resolve. `RadioCarPlayRouting.needsResolution` is what routes
    /// that case to the async `play(stationId:)` path.
    func testFavoriteRowCanHaveEmptyStreamUrl() {
        let station = favorite(streamUrl: "")
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [station],
            isSignedIn: true,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections[0].rows[0].streamUrl, "")
    }
}
