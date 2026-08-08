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

    private func curated(
        id: String = "curated-1",
        name: String = "Curated Station",
        description: String? = "A curated description",
        logoAsset: String? = "curated-logo",
        seedUUID: String = "uuid-1"
    ) -> CuratedStation {
        CuratedStation(
            id: id,
            name: name,
            description: description,
            logoAsset: logoAsset,
            tracklistUrl: nil,
            radioBrowserUUIDs: [seedUUID],
            defaultSeedUUID: seedUUID,
            seedAsFavorite: nil
        )
    }

    func testSignedOutOmitsFavoritesSection() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [favorite()],
            curated: [curated()],
            isSignedIn: false,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].header, L10n.carplayRadioStations)
    }

    func testEmptyFavoritesOmitsFavoritesSection() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [],
            curated: [curated()],
            isSignedIn: true,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].header, L10n.carplayRadioStations)
    }

    func testBothSectionsWhenFavoritesPresent() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [favorite()],
            curated: [curated()],
            isSignedIn: true,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].header, L10n.carplayRadioFavorites)
        XCTAssertEqual(sections[1].header, L10n.carplayRadioStations)
    }

    func testCuratedSectionAlwaysPresent() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [],
            curated: [curated(), curated(id: "curated-2")],
            isSignedIn: false,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].header, L10n.carplayRadioStations)
        XCTAssertEqual(sections[0].rows.count, 2)
    }

    func testNoDedupe() {
        let sharedId = "shared-station"
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [favorite(stationId: sharedId)],
            curated: [curated(id: "curated-slug", seedUUID: sharedId)],
            isSignedIn: true,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].rows.filter { $0.stationId == sharedId }.count, 1)
        XCTAssertEqual(sections[1].rows.filter { $0.stationId == sharedId }.count, 1)
    }

    func testIsPlayingSetOnBothCopies() {
        let sharedId = "shared-station"
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [favorite(stationId: sharedId)],
            curated: [curated(id: "curated-slug", seedUUID: sharedId)],
            isSignedIn: true,
            nowPlayingStationId: sharedId,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections.count, 2)
        XCTAssertTrue(sections[0].rows.first { $0.stationId == sharedId }?.isPlaying ?? false)
        XCTAssertTrue(sections[1].rows.first { $0.stationId == sharedId }?.isPlaying ?? false)
    }

    func testIsPlayingFalseWhenNilNowPlaying() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [favorite()],
            curated: [curated()],
            isSignedIn: true,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertFalse(sections[0].rows[0].isPlaying)
        XCTAssertFalse(sections[1].rows[0].isPlaying)
    }

    func testFavoritesCappedAtMax() {
        let favorites = (0..<150).map { favorite(stationId: "fav-\($0)") }
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: favorites,
            curated: [],
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
            curated: [],
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

    func testCuratedRowHasEmptyStreamUrlAndNilFavicon() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [],
            curated: [curated()],
            isSignedIn: false,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        let row = sections[0].rows[0]
        XCTAssertEqual(row.streamUrl, "")
        XCTAssertNil(row.faviconUrl)
    }

    /// Curated rows must carry the radio-browser UUID, never the slug `id` —
    /// `RadioPlaybackStarter.play(stationId:)` resolves by UUID, and
    /// `RadioStation.uuid` (what `isPlaying` compares against) is a UUID too.
    func testCuratedRowUsesSeedUUIDNotSlug() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [],
            curated: [curated(id: "kexp", seedUUID: "445cbb3a-1c4e-49aa-a268-f5b6acfa8f2e")],
            isSignedIn: false,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections[0].rows[0].stationId, "445cbb3a-1c4e-49aa-a268-f5b6acfa8f2e")
    }

    func testCuratedDetailUsesDescription() {
        let sections = RadioCarPlayRowBuilder.sections(
            favorites: [],
            curated: [curated(description: "Jazz all day")],
            isSignedIn: false,
            nowPlayingStationId: nil,
            maxRowsPerSection: 100
        )

        XCTAssertEqual(sections[0].rows[0].detail, "Jazz all day")
    }
}
