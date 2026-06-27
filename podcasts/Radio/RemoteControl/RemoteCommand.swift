import Foundation

struct RemotePresence: Codable, Sendable {
    var deviceId: String
    var deviceType: String
    var deviceName: String
    var role: String
    var playback: RemotePlaybackState
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceType = "device_type"
        case deviceName = "device_name"
        case role
        case playback
        case updatedAt = "updated_at"
    }
}

struct RemotePlaybackState: Codable, Sendable {
    var state: String
    var stationId: String?
    var stationName: String?
    var artworkUrl: String?

    enum CodingKeys: String, CodingKey {
        case state
        case stationId = "station_id"
        case stationName = "station_name"
        case artworkUrl = "artwork_url"
    }
}

struct RemoteCommand: Codable, Sendable {
    let commandId: String
    let fromDeviceId: String
    let targetDeviceId: String
    let command: String
    let payload: RemoteCommandPayload?
    let sentAt: String

    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case fromDeviceId = "from_device_id"
        case targetDeviceId = "target_device_id"
        case command
        case payload
        case sentAt = "sent_at"
    }
}

struct RemoteCommandPayload: Codable, Sendable {
    let stationId: String?
    let stationUrl: String?
    let stationName: String?

    enum CodingKeys: String, CodingKey {
        case stationId = "station_id"
        case stationUrl = "station_url"
        case stationName = "station_name"
    }
}
