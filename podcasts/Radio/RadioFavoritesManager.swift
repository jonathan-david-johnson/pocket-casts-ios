import Foundation
import PocketCastsServer

struct FavoriteStation: Codable {
    let user_uuid: String
    let station_id: String
    let added_at: String
}

extension Notification.Name {
    /// Posted whenever the user's radio favorites list changes (added,
    /// removed, or reordered locally). Consumers like `WidgetHelper` use this
    /// to republish the App Group snapshot for the Pocket Radio widget.
    static let radioFavoritesChanged = Notification.Name("radioFavoritesChanged")
}

class RadioFavoritesManager {
    static let shared = RadioFavoritesManager()

    /// UserDefaults key for the local custom ordering (per signed-in user).
    /// Value: `[stationId]` in display order. Supabase row order
    /// (`added_at desc`) is the fallback when this key is absent or stale.
    /// Local-only: no schema change on Supabase; cross-device sync is a
    /// future-M8+ task if needed.
    private static let orderKeyPrefix = "radio_favorites_order_"

    private func orderKey(userId: String) -> String {
        Self.orderKeyPrefix + userId
    }

    private func savedOrder(userId: String) -> [String]? {
        UserDefaults.standard.array(forKey: orderKey(userId: userId)) as? [String]
    }

    private func saveOrder(_ ids: [String], userId: String) {
        UserDefaults.standard.set(ids, forKey: orderKey(userId: userId))
    }

    func loadFavorites() async throws -> [FavoriteStation] {
        guard let userId = ServerSettings.userId else { throw RadioError.notLoggedIn }
        let db = try RadioSupabase.client()
        let rows: [FavoriteStation] = try await db
            .from("radio_favorites")
            .select()
            .eq("user_uuid", value: userId)
            .order("added_at", ascending: false)
            .execute()
            .value

        // Re-sort by saved local order (if any). Stations present in Supabase
        // but absent from the saved order (added on another device, never
        // reordered here) get appended at the end in `added_at desc` order.
        guard let order = savedOrder(userId: userId), !order.isEmpty else {
            return rows
        }
        let byId: [String: FavoriteStation] = Dictionary(uniqueKeysWithValues: rows.map { ($0.station_id, $0) })
        var sorted: [FavoriteStation] = order.compactMap { byId[$0] }
        let known = Set(order)
        for row in rows where !known.contains(row.station_id) {
            sorted.append(row)
        }
        // Persist the reconciled order so subsequent loads are stable.
        saveOrder(sorted.map(\.station_id), userId: userId)
        return sorted
    }

    /// Persist a reordered list of station IDs as the local display order.
    /// Caller (FavoritesViewController) drives this from
    /// `tableView(_:moveRowAt:to:)`.
    func setOrder(_ stationIds: [String]) {
        guard let userId = ServerSettings.userId else { return }
        saveOrder(stationIds, userId: userId)
        NotificationCenter.default.post(name: .radioFavoritesChanged, object: nil)
    }

    func addFavorite(stationId: String) async throws {
        guard let userId = ServerSettings.userId else { throw RadioError.notLoggedIn }
        let db = try RadioSupabase.client()
        try await db
            .from("radio_favorites")
            .upsert(["user_uuid": userId, "station_id": stationId])
            .execute()
        // Append to local order so the new favourite lands at the bottom
        // (matches Supabase `added_at desc` semantics — newest visible first
        // in the saved order array).
        var order = savedOrder(userId: userId) ?? []
        if !order.contains(stationId) {
            order.insert(stationId, at: 0)
            saveOrder(order, userId: userId)
        }
        NotificationCenter.default.post(name: .radioFavoritesChanged, object: nil)
    }

    func removeFavorite(stationId: String) async throws {
        guard let userId = ServerSettings.userId else { throw RadioError.notLoggedIn }
        let db = try RadioSupabase.client()
        try await db
            .from("radio_favorites")
            .delete()
            .eq("user_uuid", value: userId)
            .eq("station_id", value: stationId)
            .execute()
        if var order = savedOrder(userId: userId), let idx = order.firstIndex(of: stationId) {
            order.remove(at: idx)
            saveOrder(order, userId: userId)
        }
        NotificationCenter.default.post(name: .radioFavoritesChanged, object: nil)
    }

    func isFavorite(stationId: String) async throws -> Bool {
        guard let userId = ServerSettings.userId else { return false }
        let db = try RadioSupabase.client()
        let results: [FavoriteStation] = try await db
            .from("radio_favorites")
            .select()
            .eq("user_uuid", value: userId)
            .eq("station_id", value: stationId)
            .execute()
            .value
        return !results.isEmpty
    }
}
