import Foundation

struct RadioBrowserStation: Codable {
    let stationuuid: String
    let name: String
    let url: String?
    let url_resolved: String
    let favicon: String?
    let country: String?
    let state: String?
    let tags: String?
    let votes: Int?
    let bitrate: Int?
    let codec: String?

    init(
        stationuuid: String,
        name: String,
        url: String? = nil,
        url_resolved: String,
        favicon: String? = nil,
        country: String? = nil,
        state: String? = nil,
        tags: String? = nil,
        votes: Int? = nil,
        bitrate: Int? = nil,
        codec: String? = nil
    ) {
        self.stationuuid = stationuuid
        self.name = name
        self.url = url
        self.url_resolved = url_resolved
        self.favicon = favicon
        self.country = country
        self.state = state
        self.tags = tags
        self.votes = votes
        self.bitrate = bitrate
        self.codec = codec
    }

    func toRadioStation() -> RadioStation {
        let enhancement = CuratedStationsLoader.enhancementsByUUID[stationuuid]
        let resolvedState = state ?? ""
        let resolvedCountry = country ?? ""
        let city = resolvedState.isEmpty ? resolvedCountry : "\(resolvedState), \(resolvedCountry)"
        let displayName = enhancement?.name ?? name
        return RadioStation(
            stationId: stationuuid,
            name: displayName,
            streamUrl: url_resolved,
            donateUrl: nil,
            city: city,
            bitrate: bitrate,
            tracklistUrl: enhancement?.tracklistUrl,
            logoAsset: enhancement?.logoAsset
        )
    }
}

enum RadioBrowserAPI {
    private static let base = "https://de1.api.radio-browser.info/json"
    private static let decoder = JSONDecoder()

    static func topStations(limit: Int = 100) async throws -> [RadioBrowserStation] {
        let url = URL(string: "\(base)/stations/topvote?limit=\(limit)&hidebroken=true")!
        return try await fetch(url: url)
    }

    static func search(query: String, limit: Int = 40) async throws -> [RadioBrowserStation] {
        var components = URLComponents(string: "\(base)/stations/search")!
        components.queryItems = [
            .init(name: "name", value: query),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "hidebroken", value: "true"),
            .init(name: "order", value: "votes"),
            .init(name: "reverse", value: "true")
        ]
        return try await fetch(url: components.url!)
    }

    static func station(uuid: String) async throws -> RadioBrowserStation? {
        let url = URL(string: "\(base)/stations/byuuid/\(uuid)")!
        let results: [RadioBrowserStation] = try await fetch(url: url)
        return results.first
    }

    private static func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("PocketRadio/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(T.self, from: data)
    }
}
