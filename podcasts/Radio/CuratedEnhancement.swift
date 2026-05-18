import Foundation

/// A display-time decoration applied to a radio-browser station whose UUID
/// matches one of the curated groups in `curated_stations.json`. Holds only
/// fields that enrich how the station is rendered or played — the playable
/// `streamUrl` etc. always come from the radio-browser entry, not from here.
struct CuratedEnhancement: Equatable {
    let name: String
    let logoAsset: String?
    let tracklistUrl: String?
    let description: String?
}
