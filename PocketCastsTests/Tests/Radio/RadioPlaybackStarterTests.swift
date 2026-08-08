import XCTest
@testable import podcasts

final class RadioPlaybackStarterTests: XCTestCase {

    private final class FakeRegistry: RadioStationRegistering {
        var registerCallLog: [String] = []

        func register(_ station: RadioStation) {
            registerCallLog.append(station.uuid)
        }
    }

    private final class FakeEpisodeLoader: RadioEpisodeLoading {
        var callLog: [String] = []
        var currentUuid: String?
        var loadCount = 0
        var togglePlayPauseCount = 0

        func currentEpisodeUuid() -> String? {
            currentUuid
        }

        func load(station: RadioStation) {
            callLog.append("load:\(station.uuid)")
            loadCount += 1
        }

        func togglePlayPause() {
            callLog.append("togglePlayPause")
            togglePlayPauseCount += 1
        }
    }

    private var registry: FakeRegistry!
    private var episodeLoader: FakeEpisodeLoader!
    private var prefetchedStations: [String] = []
    private var republishCount = 0

    private func makeStarter() -> RadioPlaybackStarter {
        RadioPlaybackStarter(
            registry: registry,
            episodeLoader: episodeLoader,
            resolveStation: { _ in nil },
            tracklistPrefetcher: { [weak self] station in
                self?.prefetchedStations.append(station.uuid)
            },
            widgetRepublisher: { [weak self] in
                self?.republishCount += 1
            }
        )
    }

    private func makeStation(uuid: String = "station-1", tracklistUrl: String? = nil) -> RadioStation {
        RadioStation(stationId: uuid, name: "Test Station", streamUrl: "https://example.com/stream", tracklistUrl: tracklistUrl)
    }

    override func setUp() {
        super.setUp()
        registry = FakeRegistry()
        episodeLoader = FakeEpisodeLoader()
        prefetchedStations = []
        republishCount = 0
    }

    func testRegistersBeforeLoading() {
        // registry and episodeLoader are separate fakes, so ordering is asserted
        // via recorders that both append into one shared log.
        let station = makeStation()
        var combinedLog: [String] = []
        let starter = RadioPlaybackStarter(
            registry: RecordingRegistry(inner: registry) { combinedLog.append("register:\($0)") },
            episodeLoader: RecordingLoader(inner: episodeLoader) { combinedLog.append($0) },
            resolveStation: { _ in nil },
            tracklistPrefetcher: { _ in },
            widgetRepublisher: {}
        )

        _ = starter.play(station: station, source: .player)

        XCTAssertEqual(combinedLog, ["register:\(station.uuid)", "load:\(station.uuid)"])
    }

    func testAlreadyCurrentTogglesPauseAndDoesNotReload() {
        let station = makeStation()
        episodeLoader.currentUuid = station.uuid
        let starter = makeStarter()

        let result = starter.play(station: station, source: .player)

        XCTAssertEqual(result, .toggledPause)
        XCTAssertEqual(episodeLoader.togglePlayPauseCount, 1)
        XCTAssertEqual(episodeLoader.loadCount, 0)
    }

    func testReloadRegistersAndLoadsEvenWhenAlreadyCurrent() {
        let station = makeStation()
        episodeLoader.currentUuid = station.uuid
        let starter = makeStarter()

        let result = starter.reload(station: station, source: .player)

        XCTAssertEqual(result, .startedPlayback)
        XCTAssertEqual(episodeLoader.loadCount, 1)
        XCTAssertEqual(episodeLoader.togglePlayPauseCount, 0)
        XCTAssertEqual(registry.registerCallLog, [station.uuid])
    }

    func testPrefetchFiresWhenTracklistUrlPresent() {
        let station = makeStation(tracklistUrl: "https://example.com/tracklist")
        let starter = makeStarter()

        _ = starter.play(station: station, source: .player)

        XCTAssertEqual(prefetchedStations, [station.uuid])
    }

    func testPrefetchSkippedWhenTracklistUrlNil() {
        let station = makeStation(tracklistUrl: nil)
        let starter = makeStarter()

        _ = starter.play(station: station, source: .player)

        XCTAssertTrue(prefetchedStations.isEmpty)
    }

    func testPrefetchSkippedWhenTracklistUrlEmptyString() {
        let station = makeStation(tracklistUrl: "")
        let starter = makeStarter()

        _ = starter.play(station: station, source: .player)

        XCTAssertTrue(prefetchedStations.isEmpty)
    }

    func testPrefetchSkippedWhenDisabledByFlag() {
        let station = makeStation(tracklistUrl: "https://example.com/tracklist")
        let starter = makeStarter()

        _ = starter.play(station: station, source: .player, prefetchTracklist: false)

        XCTAssertTrue(prefetchedStations.isEmpty)
    }

    func testWidgetRepublishSkippedWhenDisabledByFlag() {
        let station = makeStation()
        let starter = makeStarter()

        _ = starter.play(station: station, source: .player, republishWidgetState: false)

        XCTAssertEqual(republishCount, 0)
    }

    func testWidgetRepublishFiresByDefault() {
        let station = makeStation()
        let starter = makeStarter()

        _ = starter.play(station: station, source: .player)

        XCTAssertEqual(republishCount, 1)
    }
}

// MARK: - Ordering recorders

private final class RecordingRegistry: RadioStationRegistering {
    private let inner: RadioStationRegistering
    private let record: (String) -> Void

    init(inner: RadioStationRegistering, record: @escaping (String) -> Void) {
        self.inner = inner
        self.record = record
    }

    func register(_ station: RadioStation) {
        record(station.uuid)
        inner.register(station)
    }
}

private final class RecordingLoader: RadioEpisodeLoading {
    private let inner: RadioEpisodeLoading
    private let record: (String) -> Void

    init(inner: RadioEpisodeLoading, record: @escaping (String) -> Void) {
        self.inner = inner
        self.record = record
    }

    func currentEpisodeUuid() -> String? {
        inner.currentEpisodeUuid()
    }

    func load(station: RadioStation) {
        record("load:\(station.uuid)")
        inner.load(station: station)
    }

    func togglePlayPause() {
        record("togglePlayPause")
        inner.togglePlayPause()
    }
}
