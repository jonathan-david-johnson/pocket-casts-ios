import Foundation

struct TracklistEntry: Equatable, Hashable {
    let title: String
    let artist: String
    let album: String?
    let albumArtURL: URL?
    let playedAt: Date?
}
