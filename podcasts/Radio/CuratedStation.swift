import Foundation

struct CuratedStation: Codable, Equatable {
    let id: String
    let name: String
    let description: String?
    let logoAsset: String?
    let tracklistUrl: String?
    let radioBrowserUUIDs: [String]
    let defaultSeedUUID: String
    let seedAsFavorite: Bool?

    func toEnhancement() -> CuratedEnhancement {
        CuratedEnhancement(
            name: name,
            logoAsset: logoAsset,
            tracklistUrl: tracklistUrl,
            description: description
        )
    }
}

enum CuratedStationsLoader {
    static func load() -> [CuratedStation] {
        guard let url = Bundle.main.url(forResource: "curated_stations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode(StationsFile.self, from: data) else {
            return []
        }
        return result.stations
    }

    /// UUID → enhancement, built once per app session.
    static let enhancementsByUUID: [String: CuratedEnhancement] = {
        var index: [String: CuratedEnhancement] = [:]
        for station in load() {
            let enhancement = station.toEnhancement()
            for uuid in station.radioBrowserUUIDs {
                if index[uuid] != nil {
                    assertionFailure("Duplicate radio-browser UUID across curated entries: \(uuid)")
                    continue
                }
                index[uuid] = enhancement
            }
        }
        return index
    }()

    private struct StationsFile: Codable {
        let stations: [CuratedStation]
    }
}
