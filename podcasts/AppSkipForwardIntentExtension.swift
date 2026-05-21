import PocketCastsUtils

@available(iOS 17, *)
extension SkipForwardIntent {
    func intentSkipForward() {
        // Live radio streams reject skip — controls are mute-only.
        if PlaybackManager.shared.shouldUseMuteControls() {
            FileLog.shared.addMessage("SkipForwardIntent ignored: live stream uses mute controls")
            return
        }
        AnalyticsPlaybackHelper.shared.currentSource = .interactiveWidget
        Analytics.track(.pocketRadioWidgetInteraction, properties: ["action": "skip_forward"])
        PlaybackManager.shared.skipForward()
    }
}
