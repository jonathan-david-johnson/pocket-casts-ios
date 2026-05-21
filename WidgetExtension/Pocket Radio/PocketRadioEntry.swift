import Foundation
import WidgetKit

struct PocketRadioEntry: TimelineEntry {
    let date: Date
    let nowPlaying: WidgetEpisode?
    let isLive: Bool
    let liveTrack: WidgetLiveTrack?
    let isPlaying: Bool
    let isMuted: Bool
    /// Always exactly 3 entries — pad with `WidgetFavoriteStation.placeholder` if
    /// the user has fewer than 3 favorites.
    let favorites: [WidgetFavoriteStation]
}
