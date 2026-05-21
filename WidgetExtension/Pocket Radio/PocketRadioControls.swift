import SwiftUI
import WidgetKit

/// Top-row context-aware control cluster.
///
/// Podcast mode: back 15s · play/pause · fwd 30s (three AppIntent buttons).
/// Live mode: mute toggle · open tracklist (deep link).
///
/// On iOS < 17, AppIntent buttons aren't supported — we degrade to plain
/// `Link` glyphs that open the host app on tap.
struct PocketRadioControls: View {
    let entry: PocketRadioEntry

    var body: some View {
        if entry.isLive {
            liveControls
        } else {
            podcastControls
        }
    }

    // MARK: - Podcast

    @ViewBuilder
    private var podcastControls: some View {
        HStack(spacing: 16) {
            if #available(iOS 17, *), let episode = entry.nowPlaying {
                Button(intent: SkipBackIntent()) {
                    Image(systemName: "arrow.uturn.backward")
                        .accessibilityLabel("Skip back 15 seconds")
                }
                .buttonStyle(.plain)

                Button(intent: PlayEpisodeIntent(episodeUuid: episode.episodeUuid)) {
                    Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                        .accessibilityLabel(entry.isPlaying ? "Pause" : "Play")
                }
                .buttonStyle(.plain)

                Button(intent: SkipForwardIntent()) {
                    Image(systemName: "arrow.uturn.forward")
                        .accessibilityLabel("Skip forward 30 seconds")
                }
                .buttonStyle(.plain)
            } else {
                fallbackGlyph(systemName: "arrow.uturn.backward")
                fallbackGlyph(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                fallbackGlyph(systemName: "arrow.uturn.forward")
            }
        }
        .font(.title3)
        .foregroundStyle(.primary)
    }

    // MARK: - Live

    @ViewBuilder
    private var liveControls: some View {
        HStack(spacing: 16) {
            if #available(iOS 17, *) {
                Button(intent: MuteToggleIntent()) {
                    Image(systemName: entry.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .accessibilityLabel(entry.isMuted ? "Unmute" : "Mute")
                }
                .buttonStyle(.plain)
            } else {
                fallbackGlyph(systemName: entry.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }

            if let stationId = entry.liveTrack?.stationId, !stationId.isEmpty,
               let url = URL(string: "pktc://station/\(stationId)?source=widget") {
                Link(destination: url) {
                    Image(systemName: "music.note.list")
                        .accessibilityLabel("Open tracklist")
                }
            } else {
                fallbackGlyph(systemName: "music.note.list")
            }
        }
        .font(.title3)
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func fallbackGlyph(systemName: String) -> some View {
        // Below iOS 17 (or no episode/station context), render a static glyph
        // wrapped in a Link that just opens the app.
        if let url = URL(string: "pktc://last_opened") {
            Link(destination: url) {
                Image(systemName: systemName)
            }
        } else {
            Image(systemName: systemName)
        }
    }
}
