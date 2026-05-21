import AppIntents
import WidgetKit
import PocketCastsUtils

/// Loads and starts playback of a curated or radio-browser radio station,
/// keyed by `stationuuid`. Used by the PocketRadio widget's bottom-row
/// favorite tiles so the user can start a station without opening the app.
@available(iOS 17, *)
struct PlayRadioStationIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play radio station"
    static var isDiscoverable = false

    @Parameter(title: "StationId")
    var stationId: String

    init(stationId: String) {
        self.stationId = stationId
    }

    init() {}

    static var openAppWhenRun: Bool { return false }

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { return [.background] }

    @MainActor
    func perform() async throws -> some IntentResult {
        FileLog.shared.addMessage("PlayRadioStationIntent perform called for station \(stationId)")
        await intentPlayStation(stationId)

        return .result()
    }
}
