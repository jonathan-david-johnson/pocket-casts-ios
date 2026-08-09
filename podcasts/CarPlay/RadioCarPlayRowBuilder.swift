import Foundation

/// One row in the CarPlay Radio tab, independent of CarPlay types.
struct RadioCarPlayRow: Equatable {
    /// Always a radio-browser UUID. Curated stations (KCRW, KEXP, NPR) reach
    /// this list the same way as any other favorite — the curated logo/name
    /// enhancement is merged in by `RadioFavoritesService`, keyed by this UUID.
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

/// Pure model: cache snapshot + sign-in state → the exact rows and sections the
/// CarPlay Radio tab should show. No CarPlay types, no singletons, no I/O.
///
/// One list, favorites only — curated stations (KCRW, KEXP, NPR) aren't a
/// separate browsable set here. They reach this list the same way any other
/// station does, by being favorited; `RadioFavoritesService` merges in their
/// curated logo/name/tracklist enhancement by UUID before it ever gets here.
enum RadioCarPlayRowBuilder {
    /// - Parameters:
    ///   - favorites: `RadioFavoritesCache.snapshot()`
    ///   - isSignedIn: `ServerSettings.userId != nil`
    ///   - nowPlayingStationId: `PlaybackManager.liveStation(for: nil)?.uuid`
    ///   - maxRowsPerSection: `Constants.Limits.maxCarplayItems` (100)
    static func sections(
        favorites: [CachedFavoriteStation],
        isSignedIn: Bool,
        nowPlayingStationId: String?,
        maxRowsPerSection: Int
    ) -> [RadioCarPlaySection] {
        guard isSignedIn, !favorites.isEmpty else { return [] }

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

        return [RadioCarPlaySection(header: L10n.carplayRadioFavorites, rows: Array(rows))]
    }
}
