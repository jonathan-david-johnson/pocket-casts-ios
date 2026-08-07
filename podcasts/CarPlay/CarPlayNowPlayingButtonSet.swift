import Foundation

/// Which Now Playing buttons CarPlay should show, decided purely from state.
/// Order in the array is the order they appear on screen.
enum CarPlayNowPlayingButtonKind: Equatable {
    // Podcast
    case markAsPlayed
    case playbackRate
    case chapters
    case star(filled: Bool)
    // Radio
    case mute(muted: Bool)
    case favorite(isFavorite: Bool)
}

enum CarPlayNowPlayingButtonSet {
    /// - Parameters:
    ///   - isLiveRadio: `PlaybackManager.isLiveStream()`
    ///   - canMute: `PlaybackManager.shouldUseMuteControls()` — live AND unseekable
    ///   - isMuted: `PlaybackManager.isMuted`
    ///   - isFavorite: cached favorite state for the current station
    ///   - chapterCount: `PlaybackManager.chapterCount()`
    ///   - isStarred: `(currentEpisode() as? Episode)?.keepEpisode == true`
    static func buttons(
        isLiveRadio: Bool,
        canMute: Bool,
        isMuted: Bool,
        isFavorite: Bool,
        chapterCount: Int,
        isStarred: Bool
    ) -> [CarPlayNowPlayingButtonKind] {
        guard isLiveRadio else {
            var buttons: [CarPlayNowPlayingButtonKind] = [.markAsPlayed, .playbackRate]
            if chapterCount > 0 {
                buttons.append(.chapters)
            }
            buttons.append(.star(filled: isStarred))
            return buttons
        }

        var buttons = [CarPlayNowPlayingButtonKind]()
        if canMute {
            buttons.append(.mute(muted: isMuted))
        }
        buttons.append(.favorite(isFavorite: isFavorite))
        return buttons
    }

    /// Whether `CPNowPlayingTemplate.isUpNextButtonEnabled` /
    /// `.isAlbumArtistButtonEnabled` should be on.
    static func showsUpNextButton(isLiveRadio: Bool) -> Bool {
        !isLiveRadio
    }

    static func showsAlbumArtistButton(isLiveRadio: Bool) -> Bool {
        !isLiveRadio
    }
}
