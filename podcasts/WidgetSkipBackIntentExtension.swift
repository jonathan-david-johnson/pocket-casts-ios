import PocketCastsUtils
// Placeholder so that SkipBackIntent can compile in the widget extension, but never actually executes
// because it is a subclass of AudioPlaybackIntent which only runs in the app.
@available(iOS 17, *)
extension SkipBackIntent {
    func intentSkipBack() {
        FileLog.shared.addMessage("SkipBackIntent error: In Widget intent extension")
    }
}
