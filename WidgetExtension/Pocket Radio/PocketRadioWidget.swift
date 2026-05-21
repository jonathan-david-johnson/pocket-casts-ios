import SwiftUI
import WidgetKit

struct PocketRadioWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketRadio_Widget", provider: PocketRadioProvider()) { entry in
            PocketRadioEntryView(entry: entry)
                .clearBackground()
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName("Pocket Radio")
        .description("Now playing, quick controls, and your top favorite radio stations.")
        .supportedFamilies([.systemMedium])
    }
}
