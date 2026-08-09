import CarPlay
import Foundation
import PocketCastsServer
import PocketCastsUtils

/// Pure routing decision, extracted so it can be tested without reaching through
/// a `CPListItem`'s write-only `handler`.
enum RadioCarPlayRouting {
    /// A favorite normally arrives from the cache with its stream URL already
    /// resolved. It can be empty when `RadioFavoritesService` kept the row for
    /// its curated enhancement (name/logo) despite radio-browser metadata
    /// failing to resolve — that row still only knows a station UUID and needs
    /// `RadioPlaybackStarter.play(stationId:source:)` to look it up.
    static func needsResolution(streamUrl: String) -> Bool {
        streamUrl.isEmpty
    }
}

extension RadioCarPlayRow {
    /// Only valid when `streamUrl` is non-empty. A row with an empty stream URL
    /// must go through `RadioPlaybackStarter.play(stationId:source:)` instead.
    func toRadioStation() -> RadioStation {
        RadioStation(
            stationId: stationId,
            name: title,
            streamUrl: streamUrl,
            city: detail,
            logoAsset: logoAsset
        )
    }
}

// MARK: - Radio

extension CarPlaySceneDelegate {
    /// Fallback glyph and tab image. Radio has no bundled `car_tab_*` asset and a
    /// podcast placeholder would be misleading.
    private static let radioSymbolName = "dot.radiowaves.left.and.right"

    /// Synchronous by construction: a `UserDefaults` read plus bundle JSON. The
    /// async favorites refresh is kicked alongside and lands via
    /// `.radioFavoritesChanged`, which reloads the visible template.
    var radioTabSections: [CPListSection] {
        Task { await RadioFavoritesService.shared.resolvedFavorites() }

        let model = RadioCarPlayRowBuilder.sections(
            favorites: RadioFavoritesCache.shared.snapshot(),
            isSignedIn: ServerSettings.userId != nil,
            nowPlayingStationId: PlaybackManager.shared.liveStation(for: nil)?.uuid,
            maxRowsPerSection: Constants.Limits.maxCarplayItems
        )

        return model.map { convertToListSection($0) }
    }

    func createRadioTab() -> CPListTemplate {
        return CarPlayListData.template(title: L10n.carplayRadioTab, emptyTitle: L10n.carplayRadioEmpty, image: UIImage(systemName: Self.radioSymbolName)) { [weak self] in
            guard let self else { return nil }

            return self.radioTabSections
        }
    }

    func convertToListSection(_ section: RadioCarPlaySection) -> CPListSection {
        let items = section.rows.map { row -> CPListItem in
            let image = CarPlayImageHelper.imageForStation(stationId: row.stationId, logoAsset: row.logoAsset, faviconUrl: row.faviconUrl)
            let item = CPListItem(text: row.title, detailText: row.detail, image: image)

            // Deliberately no `playbackProgress` (a live stream has none, and
            // duration 0 renders a misleading half bar) and no `accessoryType`
            // (`.cloud` means "not downloaded", meaningless for a stream).
            item.isPlaying = row.isPlaying
            item.playingIndicatorLocation = .trailing
            item.handler = { [weak self] _, completion in
                self?.stationTapped(row)
                completion()
            }

            return item
        }

        return CPListSection(items: items, header: section.header, sectionIndexTitle: nil)
    }

    func stationTapped(_ row: RadioCarPlayRow) {
        AnalyticsPlaybackHelper.shared.currentSource = .carPlay

        defer {
            interfaceController?.showNowPlaying()
        }

        // A list row means "go to this station", never "toggle it". Without this
        // guard `RadioPlaybackStarter.play(station:)` sees the tapped station is
        // already current and toggles pause — so re-entering from the list would
        // stop playback. Mirrors `episodeTapped`'s actively-playing guard; the
        // `defer` above still pushes Now Playing.
        guard !PlaybackManager.shared.isActivelyPlaying(episodeUuid: row.stationId) else { return }

        if RadioCarPlayRouting.needsResolution(streamUrl: row.streamUrl) {
            Task {
                if await RadioPlaybackStarter.shared.play(stationId: row.stationId, source: .carPlay) == nil {
                    FileLog.shared.addMessage("CarPlay: could not resolve station \(row.stationId)")
                }
            }
        } else {
            // `reload` rather than `play`: a paused live stream can't be trusted to
            // resume from a play/pause toggle, so reconnect. Matches the phone's
            // `StationDetailViewController.togglePlay`.
            RadioPlaybackStarter.shared.reload(station: row.toRadioStation(), source: .carPlay)
        }
    }
}
