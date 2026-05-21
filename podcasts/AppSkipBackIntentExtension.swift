import PocketCastsUtils

@available(iOS 17, *)
extension SkipBackIntent {
    func intentSkipBack() {
        // Live radio streams reject skip — controls are mute-only.
        if PlaybackManager.shared.shouldUseMuteControls() {
            FileLog.shared.addMessage("SkipBackIntent ignored: live stream uses mute controls")
            return
        }
        AnalyticsPlaybackHelper.shared.currentSource = .interactiveWidget
        Analytics.track(.pocketRadioWidgetInteraction, properties: ["action": "skip_back"])
        PlaybackManager.shared.skipBack()
    }
}
