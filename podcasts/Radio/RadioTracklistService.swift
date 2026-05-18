import Foundation

enum RadioTracklistError: Error {
    case invalidURL
    case unknownStation
    case parse(Error)
    case http(Int)
    case network(Error)
}

final class RadioTracklistService {
    static let shared = RadioTracklistService()

    private let urlSession: URLSession
    private var cache: [String: [TracklistEntry]] = [:]
    private let cacheQueue = DispatchQueue(label: "RadioTracklistService.cache", attributes: .concurrent)

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// Returns the most recent successfully-fetched tracklist for the
    /// station, or nil if none has been fetched this app session.
    func cached(stationId: String) -> [TracklistEntry]? {
        cacheQueue.sync { cache[stationId] }
    }

    /// Fetch the most recent plays for a curated station.
    /// - Parameter stationId: curated station id (`"kcrw"`, `"kexp"`). For
    ///   unknown ids returns an empty array (no throw).
    /// - Parameter url: the station's tracklist endpoint.
    /// Returns up to ~10 entries, most recent first.
    func fetch(stationId: String, url: String) async throws -> [TracklistEntry] {
        guard let requestURL = URL(string: url) else { throw RadioTracklistError.invalidURL }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(from: requestURL)
        } catch {
            throw RadioTracklistError.network(error)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RadioTracklistError.http(http.statusCode)
        }

        let result: [TracklistEntry]
        switch stationId {
        case "kcrw": result = try parseKCRW(data: data)
        case "kexp": result = try parseKEXP(data: data)
        default:     result = []
        }
        if !result.isEmpty {
            cacheQueue.async(flags: .barrier) { [stationId] in
                self.cache[stationId] = result
            }
        }
        return result
    }

    // MARK: - KCRW
    // The KCRW tracklist API returns a flat JSON array of track objects.
    // Observed fields: title, artist, album, albumImage, datetime (ISO-8601 with offset)

    private struct KCRWTrack: Decodable {
        let title: String?       // can be null on [BREAK] rows
        let artist: String?      // also nullable defensively
        let album: String?
        let albumImage: String?
        let datetime: String?
    }

    func parseKCRW(data: Data) throws -> [TracklistEntry] {
        do {
            let tracks = try JSONDecoder().decode([KCRWTrack].self, from: data)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            return tracks.compactMap { t in
                // Skip [BREAK] rows and anything missing title or artist.
                guard let title = t.title, !title.isEmpty else { return nil }
                guard let artist = t.artist, !artist.isEmpty, artist != "[BREAK]" else { return nil }
                return TracklistEntry(
                    title: title,
                    artist: artist,
                    album: t.album,
                    albumArtURL: t.albumImage.flatMap(URL.init(string:)),
                    playedAt: t.datetime.flatMap(iso.date(from:))
                )
            }
        } catch {
            throw RadioTracklistError.parse(error)
        }
    }

    // MARK: - KEXP
    // The KEXP plays API returns { "results": [...] }.
    // Observed fields: play_type, song, artist, album, thumbnail_uri, airdate (ISO-8601 with offset)

    private struct KEXPResponse: Decodable {
        struct Play: Decodable {
            let play_type: String
            let song: String?
            let artist: String?
            let album: String?
            let thumbnail_uri: String?
            let airdate: String?
        }
        let results: [Play]
    }

    func parseKEXP(data: Data) throws -> [TracklistEntry] {
        do {
            let response = try JSONDecoder().decode(KEXPResponse.self, from: data)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            return response.results.compactMap { play in
                guard play.play_type == "trackplay" else { return nil }
                guard let song = play.song, let artist = play.artist else { return nil }
                return TracklistEntry(
                    title: song,
                    artist: artist,
                    album: play.album,
                    albumArtURL: play.thumbnail_uri.flatMap(URL.init(string:)),
                    playedAt: play.airdate.flatMap(iso.date(from:))
                )
            }
        } catch {
            throw RadioTracklistError.parse(error)
        }
    }
}
