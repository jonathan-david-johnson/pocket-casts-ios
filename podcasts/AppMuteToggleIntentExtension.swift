import PocketCastsUtils

@available(iOS 17, *)
extension MuteToggleIntent {
    func intentToggleMute() {
        // Allow mute for any curated `RadioStation` (matches the widget's
        // `isStream` gate), not just indefinite-duration streams. Finite
        // streams like NPR Hourly should respond to the widget's mute too —
        // even though they have skip controls in the in-app player.
        guard PlaybackManager.shared.liveStation(for: nil) != nil else {
            FileLog.shared.addMessage("MuteToggleIntent ignored: not a radio station")
            return
        }
        AnalyticsPlaybackHelper.shared.currentSource = .interactiveWidget
        Analytics.track(.pocketRadioWidgetInteraction, properties: ["action": PlaybackManager.shared.isMuted ? "unmute" : "mute"])
        PlaybackManager.shared.toggleMute()
        WidgetHelper.shared.republishAllPocketRadioState()
    }
}
