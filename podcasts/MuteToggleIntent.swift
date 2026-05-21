import AppIntents
import PocketCastsUtils
import WidgetKit

@available(iOS 17, *)
struct MuteToggleIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Toggle mute"
    static var isDiscoverable = false // only used by the Pocket Radio widget

    init() {}

    static var openAppWhenRun: Bool { return false }

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { return [.background] }

    @MainActor
    func perform() async throws -> some IntentResult {
        FileLog.shared.addMessage("MuteToggleIntent perform called")
        intentToggleMute()
        return .result()
    }
}
