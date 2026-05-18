import Foundation
import PocketCastsDataModel

/// Live radio stream conforming to BaseEpisode so it can enter PC's playback stack.
/// Key tricks:
///   - downloadUrl = streamUrl (EpisodeManager.urlForEpisode reads this after our patch)
///   - sizeInBytes = Int64.max  → DownloadManager cache guard always fails → no background caching
///   - duration = 0             → mini player hides progress bar automatically
///   - played() = false         → live stream is never "completed"
@objc public class RadioStation: NSObject, BaseEpisode {

    // MARK: - Radio identity

    public let stationId: String
    public let streamUrl: String
    public let donateUrl: String?
    public let city: String?
    public let bitrate: Int?
    public let tracklistUrl: String?

    public init(
        stationId: String,
        name: String,
        streamUrl: String,
        donateUrl: String? = nil,
        city: String? = nil,
        bitrate: Int? = nil,
        tracklistUrl: String? = nil
    ) {
        self.stationId = stationId
        self.streamUrl = streamUrl
        self.donateUrl = donateUrl
        self.city = city
        self.bitrate = bitrate
        self.tracklistUrl = tracklistUrl

        self.uuid = stationId
        self.title = name
        self.downloadUrl = streamUrl
        self.sizeInBytes = Int64.max
        self.episodeStatus = DownloadStatus.notDownloaded.rawValue
        self.playingStatus = PlayingStatus.notPlayed.rawValue
    }

    // MARK: - BaseEpisode stored properties

    public var uuid: String
    public var title: String?
    public var downloadUrl: String?
    public var sizeInBytes: Int64
    public var episodeStatus: Int32
    public var playingStatus: Int32

    public var addedDate: Date? = nil
    public var publishedDate: Date? = nil
    public var cachedFrameCount: Int64 = 0
    public var autoDownloadStatus: Int32 = 0
    public var fileType: String? = "audio/mpeg"
    public var contentType: String? = nil
    public var playbackErrorDetails: String? = nil
    public var downloadErrorDetails: String? = nil
    public var lastDownloadAttemptDate: Date? = nil
    public var downloadTaskId: String? = nil
    public var playingStatusModified: Int64 = 0
    public var playedUpToModified: Int64 = 0
    public var archived: Bool = false
    public var keepEpisode: Bool = false
    public var wasDeleted: Bool = false
    public var playedUpTo: Double = 0
    public var duration: Double = 0
    public var deselectedChapters: String? = nil
    public var deselectedChaptersModified: Int64 = 0
    public var hasBookmarks: Bool = false
    public var hasOnlyUuid: Bool = false

    // MARK: - BaseEpisode methods

    public func displayableTitle() -> String { title ?? stationId }
    public func parentIdentifier() -> String { stationId }

    public func downloaded(pathFinder: FilePathProtocol) -> Bool { false }
    public func bufferedForStreaming() -> Bool { false }
    public func downloadFailed() -> Bool { false }
    public func downloading() -> Bool { false }
    public func queued() -> Bool { false }
    public func waitingForWifi() -> Bool { false }
    public func exemptFromAutoDownload() -> Bool { true }
    public func pathToDownloadedFile(pathFinder: FilePathProtocol) -> String { "" }
    public func pathToTempFile(pathFinder: FilePathProtocol) -> String { "" }

    public func inProgress() -> Bool { playingStatus == PlayingStatus.inProgress.rawValue }
    public func played() -> Bool { false }
    public func unplayed() -> Bool { true }
    public func playbackError() -> Bool { playingStatus == PlayingStatus.old.rawValue }

    public func videoPodcast() -> Bool { false }
    public func mayContainChapters() -> Bool { false }

    public var isUserEpisode: Bool { false }
}
