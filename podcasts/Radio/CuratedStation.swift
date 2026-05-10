import Foundation

struct CuratedStation: Codable {
    let id: String
    let name: String
    let description: String
    let streamUrl: String
    let tracklistUrl: String?
    let donateUrl: String
    let homepageUrl: String
    let logoAsset: String
    let city: String

    func toRadioStation() -> RadioStation {
        RadioStation(
            stationId: id,
            name: name,
            streamUrl: streamUrl,
            donateUrl: donateUrl,
            tracklistUrl: tracklistUrl,
            city: city
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

    private struct StationsFile: Codable {
        let stations: [CuratedStation]
    }
}
