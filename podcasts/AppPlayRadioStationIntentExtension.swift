import PocketCastsDataModel
import PocketCastsUtils

@available(iOS 17, *)
extension PlayRadioStationIntent {
    /// Resolve the station via `RadioStationRegistry` first (instant if the
    /// user has interacted with it this session) and fall back to a
    /// radio-browser by-UUID lookup. Then call `PlaybackManager.load`. If the
    /// station is already the current episode and playing, toggle pause.
    func intentPlayStation(_ stationId: String) async {
        FileLog.shared.addMessage("PlayRadioStationIntent called for station \(stationId)")

        AnalyticsPlaybackHelper.shared.currentSource = .interactiveWidget

        // Toggle if it's already current.
        if PlaybackManager.shared.currentEpisode()?.uuid == stationId {
            Analytics.track(.pocketRadioWidgetInteraction, properties: ["action": PlaybackManager.shared.playing() ? "pause_station" : "play_station"])
            PlaybackActionHelper.playPause()
            return
        }

        let station: RadioStation
        if let registered = RadioStationRegistry.shared.station(for: stationId) {
            station = registered
        } else if let browse = try? await RadioBrowserAPI.station(uuid: stationId) {
            station = browse.toRadioStation()
        } else {
            FileLog.shared.addMessage("PlayRadioStationIntent error: station not resolvable: \(stationId)")
            return
        }

        RadioStationRegistry.shared.register(station)
        PlaybackManager.shared.load(episode: station, autoPlay: true, overrideUpNext: false)
        Analytics.track(.pocketRadioWidgetInteraction, properties: ["action": "play_station"])

        // Kick a tracklist fetch so artist/title populate in the widget
        // before the first ICY frame arrives. KCRW's broadcast cadence can
        // delay ICY by 10–20s; the tracklist API is usually a sub-second
        // round-trip. After the fetch, `RadioTracklistService` posts
        // `.radioTracklistDidRefresh` which republishes `pocketRadioLiveTrack`
        // through WidgetHelper. Best-effort — fail silently.
        if let url = station.tracklistUrl, !url.isEmpty {
            Task {
                _ = try? await RadioTracklistService.shared.fetch(stationId: station.uuid, url: url)
            }
        }

        // Force the widget to repaint immediately. Notification observers
        // inside `WidgetHelper` may not fire (or may fire too late to bind
        // before WidgetCenter samples the timeline) when this intent runs in
        // the background intent-extension process. Explicit republish +
        // reload keeps the widget face in sync with what just started.
        WidgetHelper.shared.republishAllPocketRadioState()
    }
}
