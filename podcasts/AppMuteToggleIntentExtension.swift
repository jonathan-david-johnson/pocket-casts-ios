import PocketCastsUtils

@available(iOS 17, *)
extension MuteToggleIntent {
    func intentToggleMute() {
        // Mute toggle only valid for live radio streams; ignore otherwise.
        guard PlaybackManager.shared.shouldUseMuteControls() else {
            FileLog.shared.addMessage("MuteToggleIntent ignored: not a live stream")
            return
        }
        AnalyticsPlaybackHelper.shared.currentSource = .interactiveWidget
        Analytics.track(.pocketRadioWidgetInteraction, properties: ["action": PlaybackManager.shared.isMuted ? "unmute" : "mute"])
        PlaybackManager.shared.toggleMute()
    }
}
