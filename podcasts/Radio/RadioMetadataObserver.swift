import AVFoundation
import Foundation

extension Notification.Name {
    static let radioStationNowPlayingDidChange = Notification.Name("radioStationNowPlayingDidChange")
}

enum RadioMetadataNotificationKey {
    static let stationId = "stationId"
    static let title = "title"
    static let artist = "artist"
    static let albumArtURL = "albumArtURL"  // reserved; always nil in M6
}

final class RadioMetadataObserver: NSObject, AVPlayerItemMetadataOutputPushDelegate {
    let stationId: String

    private let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
    private var lastEmittedTitle: String?
    private var lastEmittedArtist: String?

    init(stationId: String) {
        self.stationId = stationId
        super.init()
        metadataOutput.setDelegate(self, queue: .main)
    }

    /// Call once after the AVPlayerItem is created.
    func attach(to playerItem: AVPlayerItem) {
        playerItem.add(metadataOutput)
    }

    // MARK: - AVPlayerItemMetadataOutputPushDelegate
    func metadataOutput(_ output: AVPlayerItemMetadataOutput,
                        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
                        from track: AVPlayerItemTrack?) {
        for group in groups {
            for item in group.items {
                guard let raw = item.stringValue else { continue }
                if let parsed = parseStreamTitle(raw) {
                    emit(title: parsed.title, artist: parsed.artist)
                }
            }
        }
    }

    // MARK: - Parsing
    /// Returns nil for ad frames (empty StreamTitle or adw_ad='true' present).
    /// Returns (artist, title) split on first " - " when possible; otherwise
    /// (artist: "", title: <whole>).
    func parseStreamTitle(_ raw: String) -> (artist: String, title: String)? {
        // Strip ICY framing artefacts. The raw can be either:
        // - The full `StreamTitle='Foo';StreamUrl='...';` blob (ICY).
        // - Just the title text (HLS in-band ID3).
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Reject ad frames by explicit markers.
        if trimmed.contains("adw_ad='true'") { return nil }
        if trimmed.range(of: #"insertionType='(preroll|midroll|postroll|ad)'"#, options: .regularExpression) != nil { return nil }

        // Extract StreamTitle content if framed.
        let streamTitle: String
        if let range = trimmed.range(of: "StreamTitle='") {
            let afterPrefix = trimmed[range.upperBound...]
            if let end = afterPrefix.range(of: "';") {
                streamTitle = String(afterPrefix[..<end.lowerBound])
            } else {
                streamTitle = String(afterPrefix)
            }
        } else {
            streamTitle = trimmed
        }

        let title = streamTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        // Reject titles that are themselves ad/junk markers (e.g. station automation emits
        // `StreamTitle='preroll';` with no adw_ad flag, or `[BREAK]` / `-[BREAK]-` between songs).
        let lower = title.lowercased()
        if lower.contains("[break]") { return nil }
        let junkTitles: Set<String> = ["preroll", "midroll", "postroll", "advertisement", "ad", "break"]
        if junkTitles.contains(lower) { return nil }

        // Split on first " - " (with surrounding spaces) for artist/title.
        if let dash = title.range(of: " - ") {
            let artist = String(title[..<dash.lowerBound]).trimmingCharacters(in: .whitespaces)
            let track = String(title[dash.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (artist, track)
        }
        return (artist: "", title: title)
    }

    private func emit(title: String, artist: String) {
        // Dedupe consecutive identical frames.
        if title == lastEmittedTitle && artist == lastEmittedArtist { return }
        lastEmittedTitle = title
        lastEmittedArtist = artist

        NotificationCenter.default.post(
            name: .radioStationNowPlayingDidChange,
            object: nil,
            userInfo: [
                RadioMetadataNotificationKey.stationId: stationId,
                RadioMetadataNotificationKey.title: title,
                RadioMetadataNotificationKey.artist: artist
                // albumArtURL intentionally omitted (M6 = nil)
            ]
        )
    }

    /// Test-only hook: exercises the dedupe logic in emit() without needing AVFoundation machinery.
    func emitForTesting(title: String, artist: String) {
        emit(title: title, artist: artist)
    }
}
