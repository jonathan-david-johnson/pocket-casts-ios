import AppIntents
import PocketCastsUtils
import WidgetKit

@available(iOS 17, *)
struct SkipBackIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Skip back"
    static var isDiscoverable = false // only used by the Pocket Radio widget

    init() {}

    static var openAppWhenRun: Bool { return false }

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { return [.background] }

    @MainActor
    func perform() async throws -> some IntentResult {
        FileLog.shared.addMessage("SkipBackIntent perform called")
        intentSkipBack()
        return .result()
    }
}
