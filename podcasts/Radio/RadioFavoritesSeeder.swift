import Foundation
import PocketCastsServer

enum RadioFavoritesSeeder {
    /// One-shot seed of curated favorites for signed-in users. Idempotent on
    /// `Constants.UserDefaults.radioFavoritesSeeded` — sets the flag only
    /// after a fully-successful seed run. Signed-out installs no-op and
    /// leave the flag unset so a later signed-in launch can complete.
    static func seedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Constants.UserDefaults.radioFavoritesSeeded) else { return }
        guard SyncManager.isUserLoggedIn() else { return }

        let curated = CuratedStationsLoader.load().filter { $0.seedAsFavorite == true }
        guard !curated.isEmpty else {
            defaults.set(true, forKey: Constants.UserDefaults.radioFavoritesSeeded)
            return
        }

        Task { @MainActor in
            var allSucceeded = true
            for station in curated {
                do {
                    try await RadioFavoritesManager.shared.addFavorite(stationId: station.id)
                } catch {
                    allSucceeded = false
                    // Don't break — try the next one. Failure to seed one station
                    // shouldn't block others. If any failed, flag stays unset and
                    // a future launch will retry the missing ones (Supabase upsert
                    // makes the already-seeded ones a no-op).
                }
            }
            if allSucceeded {
                UserDefaults.standard.set(true, forKey: Constants.UserDefaults.radioFavoritesSeeded)
            }
        }
    }
}
