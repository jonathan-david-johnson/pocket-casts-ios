import Foundation
import MediaPlayer
import PocketCastsDataModel
import PocketCastsUtils

class NowPlayingHelper {
    class func updateNowPlayingInfo(for episode: BaseEpisode, currentChapters: Chapters, duration: TimeInterval, upTo: TimeInterval, playbackRate: Double?) {
        guard let currNowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            setAllNowPlayingInfo(for: episode, currentChapters: currentChapters, duration: duration, upTo: upTo, playbackRate: playbackRate)
            return
        }

        let title = NowPlayingHelper.titleForNowPlayingInfo(episode: episode, currentChapters: currentChapters)
        // there's a lot of weird edge case bugs with Apple's now playing implementation, so this method gets called every time progress
        // is saved to the DB, currently every updatesPerSave seconds. it looks at what's in their at the moment, and if it's not the current episode
        // sets all the data, otherwise is just updates the progress
        let nowPlayingTitle = currNowPlaying[MPMediaItemPropertyTitle] as? String
        if title == nowPlayingTitle {
            let nowPlayingInfo = NowPlayingHelper.addUpToInformationToNowPlaying(currNowPlaying as [String: AnyObject], duration: duration, upTo: upTo, playbackRate: playbackRate)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        } else {
            setAllNowPlayingInfo(for: episode, currentChapters: currentChapters, duration: duration, upTo: upTo, playbackRate: playbackRate)
        }
    }

    class func setAllNowPlayingInfo(for episode: BaseEpisode, currentChapters: Chapters, duration: TimeInterval, upTo: TimeInterval, playbackRate: Double?) {
        let playingInfo = nowPlayingInfo(for: episode, currentChapters: currentChapters)
        var nowPlayingInfoWithProgress = NowPlayingHelper.addUpToInformationToNowPlaying(playingInfo, duration: duration, upTo: upTo, playbackRate: playbackRate)

        let size = ImageManager.sizeFor(imageSize: .page)

        #if !os(watchOS) && !APPCLIP && !os(tvOS)
        // Live radio: ImageManager.imageForEpisode returns nil for RadioStation
        // (it has no parent podcast). Use the curated station logo asset as the
        // baseline artwork, and let RadioArtworkCoordinator overwrite it with
        // per-track art when a tracklist tick resolves one.
        if let radio = PlaybackManager.shared.liveStation(for: episode) {
            let stationLogo = stationLogoImage(for: radio)
            let imageToUse = stationLogo ?? UIImage(named: "noartwork-page")!
            let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: size, height: size), requestHandler: { _ -> UIImage in
                imageToUse
            })
            nowPlayingInfoWithProgress[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoWithProgress
            return
        }
        #endif

        ImageManager.sharedManager.imageForEpisode(episode, size: .page) { image in
            let imageToUse = image ?? UIImage(named: "noartwork-page")!

            let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: size, height: size), requestHandler: { _ -> UIImage in
                imageToUse
            })

            nowPlayingInfoWithProgress[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoWithProgress
        }
    }

    #if !os(watchOS) && !APPCLIP && !os(tvOS)
    /// Loads the station logo bundled asset for a curated radio station.
    /// Returns nil for non-curated stations (radio-browser ones without a
    /// `logoAsset`).
    class func stationLogoImage(for station: RadioStation) -> UIImage? {
        if let asset = station.logoAsset, let image = UIImage(named: asset) {
            return image
        }
        return nil
    }

    /// Replace `MPMediaItemPropertyArtwork` for the current `nowPlayingInfo`
    /// entry without re-serialising the full info dict. Used by the radio
    /// artwork coordinator on tracklist ticks. The `image` is captured by the
    /// `requestHandler` closure — it does NOT retain `self` and there is no
    /// cycle on `PlaybackManager`.
    class func setArtworkImage(_ image: UIImage) {
        let size = ImageManager.sizeFor(imageSize: .page)
        let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: size, height: size), requestHandler: { _ -> UIImage in
            image
        })
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    #endif

    /// Update title/artist in MPNowPlayingInfoCenter when ICY/tracklist track changes.
    /// Keeps existing fields (artwork, progress) intact.
    class func setRadioTrackInfo(trackTitle: String, artist: String, stationName: String) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        if trackTitle.isEmpty {
            info[MPMediaItemPropertyTitle] = stationName as NSString
            info[MPMediaItemPropertyArtist] = stationName as NSString
        } else {
            info[MPMediaItemPropertyTitle] = trackTitle as NSString
            info[MPMediaItemPropertyArtist] = artist.isEmpty ? stationName : artist as NSString
        }
        info[MPMediaItemPropertyAlbumTitle] = stationName as NSString
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    class func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private class func titleForNowPlayingInfo(episode: BaseEpisode, currentChapters: Chapters) -> String {
        if !currentChapters.title.isEmpty, Settings.publishChapterTitlesEnabled() {
            return currentChapters.title
        }

        if let podcastEpisode = episode as? Episode, podcastEpisode.episodeNumber > 0 {
            let suffix = L10n.seasonEpisodeShorthand(seasonNumber: podcastEpisode.seasonNumber, episodeNumber: podcastEpisode.episodeNumber, shortFormat: true)
            return "\(episode.displayableTitle()) (\(suffix))"
        }

        return episode.displayableTitle()
    }

    private class func nowPlayingInfo(for episode: BaseEpisode, currentChapters: Chapters) -> [String: AnyObject] {
        var nowPlayingInfo = [String: AnyObject]()

        nowPlayingInfo[MPMediaItemPropertyMediaType] = NSNumber(value: MPMediaType.podcast.rawValue)
        let nowPlayingMediaType = episode.videoPodcast() ? MPNowPlayingInfoMediaType.video.rawValue : MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = NSNumber(value: nowPlayingMediaType)
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackCount] = NSNumber(value: 1)
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = NSNumber(value: 1)
        nowPlayingInfo[MPMediaItemPropertyDiscCount] = NSNumber(value: 1)
        nowPlayingInfo[MPMediaItemPropertyDiscNumber] = NSNumber(value: 1)

        let episodeTitle = titleForNowPlayingInfo(episode: episode, currentChapters: currentChapters)
        if !episodeTitle.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyTitle] = episodeTitle as NSString
        }

        // duration
        if episode.duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: episode.duration)
            nowPlayingInfo[MPMediaItemPropertyBookmarkTime] = NSNumber(value: episode.playedUpTo)
        }

        if let episode = episode as? Episode, let parentPodcast = episode.parentPodcast() {
            // some car stereo's do weird things with the % character, so here we replace it with pct to work around those bugs
            let safeCharacterPodcastTitle = parentPodcast.title?.replacingOccurrences(of: "%", with: "pct") ?? "Pocket Casts"

            nowPlayingInfo[MPMediaItemPropertyArtist] = safeCharacterPodcastTitle as NSString
            nowPlayingInfo[MPMediaItemPropertyComposer] = safeCharacterPodcastTitle as NSString

            // we purposely show the date here instead, but as with the above there's a car stereo bug we need to work around as well where we don't show the word "Wednesday" in the artist field
            // because on some car stereos that have embedded image databases, this comes up with a really grotesque image (more info: https://github.com/shiftyjelly/pocketcasts-ios/issues/3874)
            let publishedDate = DateFormatHelper.sharedHelper.tinyLocalizedFormat(episode.publishedDate).replacingOccurrences(of: "Wednesday", with: "Wed", options: .caseInsensitive)
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = publishedDate as NSString

            nowPlayingInfo[MPMediaItemPropertyPodcastTitle] = safeCharacterPodcastTitle as NSString

            // genre
            if let podcastCategory = parentPodcast.podcastCategory, !podcastCategory.isEmpty {
                nowPlayingInfo[MPMediaItemPropertyGenre] = podcastCategory as NSString
            } else {
                nowPlayingInfo[MPMediaItemPropertyGenre] = "Podcast" as NSString
            }
        } else if let station = episode as? RadioStation {
            let stationName = station.displayableTitle()
            nowPlayingInfo[MPMediaItemPropertyArtist] = stationName as NSString
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = stationName as NSString
            nowPlayingInfo[MPMediaItemPropertyGenre] = "Radio" as NSString
        } else {
            nowPlayingInfo[MPMediaItemPropertyArtist] = "PocketCasts" as NSString
            nowPlayingInfo[MPMediaItemPropertyComposer] = "PocketCasts" as NSString
            nowPlayingInfo[MPMediaItemPropertyGenre] = "Podcast" as NSString
        }

        return nowPlayingInfo
    }

    private class func addUpToInformationToNowPlaying(_ nowPlaying: [String: AnyObject], duration: TimeInterval, upTo: TimeInterval, playbackRate: Double?) -> [String: AnyObject] {
        var nowPlayingClone = nowPlaying

        nowPlayingClone[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration)
        nowPlayingClone[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: upTo)
        if let playbackRate {
            nowPlayingClone[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: playbackRate)
            nowPlayingClone[MPNowPlayingInfoPropertyDefaultPlaybackRate] = NSNumber(value: playbackRate)
        } else {
            nowPlayingClone[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: 0)
        }

        return nowPlayingClone
    }
}
