import Foundation

/// Decodable snapshot of the currently-resolved live-radio track mirrored
/// to the App Group by `WidgetHelper.publishPocketRadioLiveTrack()`.
struct WidgetLiveTrack: Decodable, Hashable {
    let stationId: String
    let title: String
    let artist: String
    let albumArtURL: String?
}
