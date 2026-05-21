import PocketCastsUtils

// Placeholder so that PlayRadioStationIntent can compile in the widget
// extension target. Never actually runs there — the real `perform()` body is
// in the app target's extension via `AudioPlaybackIntent`.
@available(iOS 17, *)
extension PlayRadioStationIntent {
    func intentPlayStation(_ stationId: String) async {
        FileLog.shared.addMessage("PlayRadioStationIntent error: in Widget intent extension \(stationId)")
    }
}
