import Foundation

/// Where baseline artwork for a live radio station should come from.
/// Precedence: curated bundle art beats a scraped favicon beats nothing.
enum RadioArtworkSource: Equatable {
    case bundleAsset(String)
    case remote(URL)
    case placeholder
}

extension RadioArtworkSource {
    static func resolve(logoAsset: String?, faviconUrl: String?) -> RadioArtworkSource {
        if let logoAsset, !logoAsset.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .bundleAsset(logoAsset)
        }

        if let faviconUrl {
            let trimmed = faviconUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty,
               let url = URL(string: trimmed),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return .remote(url)
            }
        }

        return .placeholder
    }
}
