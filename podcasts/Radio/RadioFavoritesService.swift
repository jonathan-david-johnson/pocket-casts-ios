import Foundation
import PocketCastsServer
import PocketCastsUtils

/// The one place favorites are resolved from Supabase + radio-browser into
/// display-ready rows. Writes `RadioFavoritesCache` and posts
/// `.radioFavoritesChanged` on success.
final class RadioFavoritesService {
    static let shared = RadioFavoritesService()

    private let cache: RadioFavoritesCache

    /// radio-browser metadata cached across reloads, keyed by station id.
    /// Persisted to UserDefaults so cold starts show cached names/art immediately
    /// while the network re-fetch runs in the background.
    private static var metadataCache: [String: RadioBrowserStation] = {
        guard let data = UserDefaults.standard.data(forKey: "pocketradio.favoritesBrowseCache"),
              let decoded = try? JSONDecoder().decode([String: RadioBrowserStation].self, from: data) else {
            return [:]
        }
        return decoded
    }()

    private static func persistMetadataCache() {
        guard let data = try? JSONEncoder().encode(metadataCache) else { return }
        UserDefaults.standard.set(data, forKey: "pocketradio.favoritesBrowseCache")
    }

    /// Guards against concurrent resolves stacking Supabase queries when
    /// something (e.g. rapid CarPlay tab switching) refreshes on every
    /// `didAppear`. A second caller awaits the first's in-flight task rather
    /// than starting its own.
    private var inFlight: Task<[CachedFavoriteStation], Never>?

    init(cache: RadioFavoritesCache = .shared) {
        self.cache = cache
    }

    /// Loads favorite ids from Supabase, resolves metadata (cache-first,
    /// network for misses), persists, notifies. Returns [] when signed out or
    /// on failure — never throws.
    @discardableResult
    func resolvedFavorites() async -> [CachedFavoriteStation] {
        if let inFlight {
            return await inFlight.value
        }

        let task = Task<[CachedFavoriteStation], Never> { [weak self] in
            guard let self else { return [] }
            return await self.performResolve()
        }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }

    private func performResolve() async -> [CachedFavoriteStation] {
        guard ServerSettings.userId != nil else { return [] }

        let favorites: [FavoriteStation]
        do {
            favorites = try await RadioFavoritesManager.shared.loadFavorites()
        } catch {
            FileLog.shared.addMessage("RadioFavoritesService: loadFavorites failed: \(error)")
            return cache.snapshot()
        }

        var browse: [String: RadioBrowserStation] = [:]
        for fav in favorites {
            browse[fav.station_id] = Self.metadataCache[fav.station_id]
        }

        await withTaskGroup(of: (String, RadioBrowserStation?).self) { group in
            for fav in favorites where browse[fav.station_id] == nil {
                group.addTask {
                    let station = try? await RadioBrowserAPI.station(uuid: fav.station_id)
                    return (fav.station_id, station)
                }
            }
            for await (stationId, station) in group {
                if let station {
                    browse[stationId] = station
                    Self.metadataCache[stationId] = station
                }
            }
        }
        Self.persistMetadataCache()

        var rows: [CachedFavoriteStation] = []
        for fav in favorites {
            let stationId = fav.station_id
            let b = browse[stationId]
            let enhancement = CuratedStationsLoader.enhancementsByUUID[stationId]
            let streamUrl = b?.url_resolved ?? ""

            // Drop only when there is no usable streamUrl AND no curated
            // fallback — an unplayable row in a car is worse than a missing
            // one, but a row with neither a stream nor a name is useless.
            guard !streamUrl.isEmpty || enhancement != nil else { continue }

            rows.append(CachedFavoriteStation(
                stationId: stationId,
                name: enhancement?.name ?? b?.name ?? stationId,
                streamUrl: streamUrl,
                city: Self.displayCity(for: b),
                logoAsset: enhancement?.logoAsset,
                faviconUrl: (b?.favicon?.isEmpty == false) ? b?.favicon : nil,
                bitrate: b?.bitrate
            ))
        }

        // Post only on a genuine change. CarPlay's data source kicks a resolve on
        // every reload and reloads on `.radioFavoritesChanged` — an unconditional
        // post would make those two chase each other forever.
        let changed = rows != cache.snapshot()
        cache.write(rows)
        if changed {
            NotificationCenter.default.post(name: .radioFavoritesChanged, object: nil)
        }
        return rows
    }

    /// Mirrors `FavoriteRow.displayCity` exactly — state/country joining,
    /// empty-string handling.
    private static func displayCity(for b: RadioBrowserStation?) -> String? {
        guard let b else { return nil }
        let state = b.state ?? ""
        let country = b.country ?? ""
        if state.isEmpty && country.isEmpty { return nil }
        if state.isEmpty { return country }
        if country.isEmpty { return state }
        return "\(state), \(country)"
    }
}
