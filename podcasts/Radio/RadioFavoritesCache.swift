import Foundation

/// One favorite, fully resolved for display and playback without further I/O.
struct CachedFavoriteStation: Codable, Equatable {
    let stationId: String
    let name: String
    let streamUrl: String
    let city: String?
    let logoAsset: String?
    let faviconUrl: String?
    let bitrate: Int?

    func toRadioStation() -> RadioStation {
        RadioStation(
            stationId: stationId,
            name: name,
            streamUrl: streamUrl,
            city: city,
            bitrate: bitrate,
            logoAsset: logoAsset
        )
    }
}

/// Persisted, synchronously-readable favorites snapshot. Written by
/// `RadioFavoritesService`; read by CarPlay and anything else needing an
/// instant list. Stored in `UserDefaults.standard` — the CarPlay scene runs in
/// the main app process, so no App Group is involved.
final class RadioFavoritesCache {
    static let shared = RadioFavoritesCache()

    private static let key = "pocketradio.favoritesCache.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Never throws, never blocks. Returns `[]` on cold start or corrupt data.
    func snapshot() -> [CachedFavoriteStation] {
        guard let data = defaults.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([CachedFavoriteStation].self, from: data) else {
            return []
        }
        return decoded
    }

    func write(_ rows: [CachedFavoriteStation]) {
        guard let data = try? JSONEncoder().encode(rows) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
