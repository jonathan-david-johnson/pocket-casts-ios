import PocketCastsUtils
// Placeholder so that MuteToggleIntent can compile in the widget extension, but never actually executes
// because it is a subclass of AudioPlaybackIntent which only runs in the app.
@available(iOS 17, *)
extension MuteToggleIntent {
    func intentToggleMute() {
        FileLog.shared.addMessage("MuteToggleIntent error: In Widget intent extension")
    }
}
