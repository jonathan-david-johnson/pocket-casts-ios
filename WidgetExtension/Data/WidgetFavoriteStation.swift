import Foundation

/// Decodable snapshot of a favorite radio station mirrored to the App Group
/// by `WidgetHelper.publishPocketRadioFavorites()` in the main app.
/// JSON shape MUST match the encoder side (`PocketRadioFavoriteSnapshot`).
struct WidgetFavoriteStation: Decodable, Hashable {
    let stationId: String
    let name: String
    let logoAssetName: String?
    let faviconUrl: String?

    /// Sentinel used to pad the favorites slot when the user has fewer than 3
    /// favorites. Tap target is the Favorites tab, not a station detail.
    static var placeholder: WidgetFavoriteStation {
        WidgetFavoriteStation(
            stationId: "",
            name: "",
            logoAssetName: nil,
            faviconUrl: nil
        )
    }

    var isPlaceholder: Bool {
        stationId.isEmpty
    }
}
