import Foundation

/// One row in the CarPlay Radio tab, independent of CarPlay types.
struct RadioCarPlayRow: Equatable {
    let stationId: String
    let title: String
    let detail: String?         // city/country, nil when unknown
    let logoAsset: String?      // bundle asset name (curated)
    let faviconUrl: String?     // remote favicon (radio-browser)
    let streamUrl: String
    let isPlaying: Bool
}

struct RadioCarPlaySection: Equatable {
    let header: String
    let rows: [RadioCarPlayRow]
}

/// Pure model: cache snapshot + curated stations + sign-in state → the exact
/// rows and sections the CarPlay Radio tab should show. No CarPlay types, no
/// singletons, no I/O.
enum RadioCarPlayRowBuilder {
    /// - Parameters:
    ///   - favorites: `RadioFavoritesCache.snapshot()`
    ///   - curated: `CuratedStationsLoader.load()`
    ///   - isSignedIn: `ServerSettings.userId != nil`
    ///   - nowPlayingStationId: `PlaybackManager.liveStation(for: nil)?.uuid`
    ///   - maxRowsPerSection: `Constants.Limits.maxCarplayItems` (100)
    static func sections(
        favorites: [CachedFavoriteStation],
        curated: [CuratedStation],
        isSignedIn: Bool,
        nowPlayingStationId: String?,
        maxRowsPerSection: Int
    ) -> [RadioCarPlaySection] {
        var sections: [RadioCarPlaySection] = []

        if isSignedIn && !favorites.isEmpty {
            let rows = favorites.prefix(maxRowsPerSection).map { favorite in
                RadioCarPlayRow(
                    stationId: favorite.stationId,
                    title: favorite.name,
                    detail: favorite.city,
                    logoAsset: favorite.logoAsset,
                    faviconUrl: favorite.faviconUrl,
                    streamUrl: favorite.streamUrl,
                    isPlaying: favorite.stationId == nowPlayingStationId
                )
            }
            sections.append(RadioCarPlaySection(header: L10n.carplayRadioFavorites, rows: Array(rows)))
        }

        let curatedRows = curated.prefix(maxRowsPerSection).map { station in
            RadioCarPlayRow(
                stationId: station.id,
                title: station.name,
                detail: station.description,
                logoAsset: station.logoAsset,
                faviconUrl: nil,
                streamUrl: "",
                isPlaying: station.id == nowPlayingStationId
            )
        }
        sections.append(RadioCarPlaySection(header: L10n.carplayRadioStations, rows: Array(curatedRows)))

        return sections
    }
}
