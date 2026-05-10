import Foundation
import PocketCastsServer

struct FavoriteStation: Codable {
    let user_uuid: String
    let station_id: String
    let added_at: String
}

class RadioFavoritesManager {
    static let shared = RadioFavoritesManager()

    func loadFavorites() async throws -> [FavoriteStation] {
        guard let userId = ServerSettings.userId else { throw RadioError.notLoggedIn }
        let db = try RadioSupabase.client()
        return try await db
            .from("radio_favorites")
            .select()
            .eq("user_uuid", value: userId)
            .order("added_at", ascending: false)
            .execute()
            .value
    }

    func addFavorite(stationId: String) async throws {
        guard let userId = ServerSettings.userId else { throw RadioError.notLoggedIn }
        let db = try RadioSupabase.client()
        try await db
            .from("radio_favorites")
            .upsert(["user_uuid": userId, "station_id": stationId])
            .execute()
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
