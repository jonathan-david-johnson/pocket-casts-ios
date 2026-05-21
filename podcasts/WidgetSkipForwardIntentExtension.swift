import PocketCastsUtils
// Placeholder so that SkipForwardIntent can compile in the widget extension, but never actually executes
// because it is a subclass of AudioPlaybackIntent which only runs in the app.
@available(iOS 17, *)
extension SkipForwardIntent {
    func intentSkipForward() {
        FileLog.shared.addMessage("SkipForwardIntent error: In Widget intent extension")
    }
}
