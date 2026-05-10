import Foundation
import Supabase
import PocketCastsServer

enum RadioError: Error, LocalizedError {
    case notLoggedIn
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "Sign in to Pocket Casts to sync favorites."
        case .serverError(let msg): return msg
        }
    }
}

enum RadioSupabase {
    private static var supabaseUrl: String {
        Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    }

    private static var anonKey: String {
        Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }

    // Creates a SupabaseClient configured with the current user's ID.
    // Called per-operation so userId is always fresh after login/logout.
    static func client() throws -> SupabaseClient {
        guard let userId = ServerSettings.userId, !userId.isEmpty else {
            throw RadioError.notLoggedIn
        }
        guard let url = URL(string: supabaseUrl), !supabaseUrl.isEmpty else {
            throw RadioError.serverError("SUPABASE_URL not configured")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                global: SupabaseClientOptions.Global(
                    headers: ["x-user-uuid": userId]
                )
            )
        )
    }
}
