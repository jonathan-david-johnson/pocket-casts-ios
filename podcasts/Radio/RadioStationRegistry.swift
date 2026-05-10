import Foundation

/// In-memory registry of active RadioStations, keyed by stationId (== uuid).
/// Needed because PlaybackQueue reloads episodes from SQLite by UUID after queuing.
/// RadioStation is not in SQLite, so without this the queue returns a dead stub.
class RadioStationRegistry {
    static let shared = RadioStationRegistry()
    private var stations: [String: RadioStation] = [:]

    func register(_ station: RadioStation) {
        stations[station.stationId] = station
    }

    func station(for uuid: String) -> RadioStation? {
        stations[uuid]
    }

    func remove(uuid: String) {
        stations.removeValue(forKey: uuid)
    }
}
