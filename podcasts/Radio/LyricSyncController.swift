import Foundation
import OSLog

private let lyricLog = Logger(subsystem: "com.jdj.pocketradio", category: "Lyrics")

protocol LyricSyncControllerDelegate: AnyObject {
    func lyricSyncController(_ c: LyricSyncController, didUpdateHeaderText text: String)
    func lyricSyncController(_ c: LyricSyncController, didChangeStatus status: LyricSyncController.LyricStatus)
    func lyricSyncController(_ c: LyricSyncController, didUpdateNowPlayingAlbum text: String)
}

extension LyricSyncControllerDelegate {
    func lyricSyncController(_ c: LyricSyncController, didUpdateNowPlayingAlbum text: String) {}
}

/// Owns the full lyrics state machine for a radio station:
/// fetch, LRC parse, synced-line timer, offset nudge, and debounced Supabase persistence.
/// Callers (StationDetailViewController) become thin delegates that update UI only.
final class LyricSyncController {

    enum LyricStatus: Equatable {
        case none, fetching, found, notFound, betweenTracks
    }

    weak var delegate: LyricSyncControllerDelegate?

    private(set) var status: LyricStatus = .none
    private(set) var lyricOffset: TimeInterval = 0
    private(set) var currentSongKey: String?
    private(set) var lyricStartDate: Date?
    private(set) var currentEntryAlbum: String?

    var hasLyrics: Bool { status != .none }

    private let stationId: String
    private let stationDisplayTitle: String

    private var lyricLines: [LyricLine] = []
    private var lyricDuration: TimeInterval?
    private var lyricTimer: Timer?
    private var lyricFetchTask: Task<Void, Never>?
    private var lyricOffsetSaveTask: Task<Void, Never>?

    private static let introGrace: TimeInterval = 3
    private static let endGrace: TimeInterval = 12

    init(stationId: String, stationDisplayTitle: String) {
        self.stationId = stationId
        self.stationDisplayTitle = stationDisplayTitle
    }

    // MARK: - Public interface

    func load(entry: TracklistEntry?) {
        guard let entry, !entry.title.isEmpty else { return }
        let key = songKey(for: entry)
        if currentSongKey == key { return }

        lyricFetchTask?.cancel()
        resetState()
        currentSongKey = key
        currentEntryAlbum = entry.album
        setStatus(.fetching)
        delegate?.lyricSyncController(self, didUpdateHeaderText: "Fetching…")

        lyricFetchTask = Task { [weak self] in
            guard let self else { return }
            lyricLog.debug("fetch start: artist='\(entry.artist, privacy: .public)' title='\(entry.title, privacy: .public)'")
            async let offsetsTask = RadioFavoritesManager.shared.fetchLyricOffsets()
            let result = await LyricsService.shared.fetch(artist: entry.artist, title: entry.title, album: entry.album)
            lyricLog.debug("fetch done: result=\(result == nil ? "nil" : result!.hasSynced ? "synced(\(result!.lines.count)lines)" : result!.plain != nil ? "plain" : "empty", privacy: .public) cancelled=\(Task.isCancelled)")
            _ = await offsetsTask
            guard !Task.isCancelled else {
                lyricLog.debug("task cancelled after fetch — discarding result")
                return
            }
            await MainActor.run {
                guard self.currentSongKey == key else {
                    lyricLog.debug("song key mismatch: expected '\(key, privacy: .public)' got '\(self.currentSongKey ?? "nil", privacy: .public)'")
                    return
                }
                guard let result else {
                    self.delegate?.lyricSyncController(self, didUpdateHeaderText: "No lyrics found")
                    self.setStatus(.notFound)
                    return
                }
                if result.hasSynced {
                    self.lyricLines = result.lines
                    self.lyricDuration = result.duration
                    self.lyricOffset = TimeInterval(RadioFavoritesManager.shared.lyricOffsets[self.stationId] ?? 0)
                    lyricLog.info("restored offset \(self.lyricOffset, format: .fixed(precision: 1))s station=\(self.stationId, privacy: .public)")
                    let elapsed = entry.playedAt.map { Date().timeIntervalSince($0) } ?? 0
                    self.lyricStartDate = entry.playedAt ?? Date().addingTimeInterval(-elapsed)
                    self.setStatus(.found)
                    self.startTimer(initialElapsed: max(0, elapsed))
                } else if let plain = result.plain, let firstLine = self.firstNonEmptyLine(plain) {
                    self.delegate?.lyricSyncController(self, didUpdateHeaderText: "♪ " + firstLine)
                    self.setStatus(.found)
                } else {
                    self.delegate?.lyricSyncController(self, didUpdateHeaderText: "No lyrics found")
                    self.setStatus(.notFound)
                }
            }
        }
    }

    @discardableResult
    func adjustOffset(by delta: TimeInterval) -> TimeInterval {
        lyricOffset += delta
        if let startDate = lyricStartDate {
            tick(at: Date().timeIntervalSince(startDate) + lyricOffset)
        }
        lyricLog.info("lyric offset = \(self.lyricOffset, format: .fixed(precision: 1))s  song=\(self.currentSongKey ?? "—", privacy: .public)")

        guard !stationId.isEmpty else { return lyricOffset }
        lyricOffsetSaveTask?.cancel()
        let seconds = Int(lyricOffset)
        lyricOffsetSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            guard let self else { return }
            await RadioFavoritesManager.shared.upsertLyricOffset(stationId: self.stationId, seconds: seconds)
            lyricLog.info("saved offset \(seconds)s station=\(self.stationId, privacy: .public)")
        }
        return lyricOffset
    }

    func stop() {
        resetState()
    }

    func songKey(for entry: TracklistEntry) -> String {
        "\(entry.artist.lowercased())|\(entry.title.lowercased())"
    }

    // MARK: - Private

    private func setStatus(_ newStatus: LyricStatus) {
        guard newStatus != status else { return }
        status = newStatus
        delegate?.lyricSyncController(self, didChangeStatus: newStatus)
    }

    private func startTimer(initialElapsed: TimeInterval) {
        tick(at: initialElapsed + lyricOffset)
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let startDate = self.lyricStartDate else { return }
            self.tick(at: Date().timeIntervalSince(startDate) + self.lyricOffset)
        }
        lyricTimer = timer
    }

    private func tick(at offset: TimeInterval) {
        guard let first = lyricLines.first, let last = lyricLines.last else { return }
        let songEnd = lyricDuration ?? (last.timestamp + Self.endGrace)
        if offset < first.timestamp - Self.introGrace || offset > songEnd + Self.endGrace {
            if status != .betweenTracks {
                delegate?.lyricSyncController(self, didUpdateHeaderText: "♪ " + stationDisplayTitle)
                delegate?.lyricSyncController(self, didUpdateNowPlayingAlbum: currentEntryAlbum ?? stationDisplayTitle)
                setStatus(.betweenTracks)
            }
            return
        }
        let result = LyricsResult(lines: lyricLines, plain: nil)
        if let line = LyricsService.shared.currentLine(in: result, at: offset) {
            delegate?.lyricSyncController(self, didUpdateHeaderText: "♪ " + line.text)
            delegate?.lyricSyncController(self, didUpdateNowPlayingAlbum: line.text)
            if status != .found { setStatus(.found) }
        }
    }

    private func resetState() {
        lyricTimer?.invalidate()
        lyricTimer = nil
        lyricFetchTask?.cancel()
        lyricFetchTask = nil
        lyricOffsetSaveTask?.cancel()
        lyricOffsetSaveTask = nil
        lyricLines = []
        lyricStartDate = nil
        currentSongKey = nil
        lyricDuration = nil
        lyricOffset = 0
        status = .none
    }

    private func firstNonEmptyLine(_ text: String) -> String? {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }
}
