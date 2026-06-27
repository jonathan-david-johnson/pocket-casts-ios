import XCTest
@testable import podcasts

final class RemoteCommandTests: XCTestCase {
    func testCommandRoundTrip() throws {
        let cmd = RemoteCommand(
            commandId: "abc-123",
            fromDeviceId: "device-a",
            targetDeviceId: "device-b",
            command: "load_station",
            payload: RemoteCommandPayload(stationId: "s1", stationUrl: "https://stream.example.com/live", stationName: "KCRW"),
            sentAt: "2026-06-27T00:00:00Z"
        )
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(RemoteCommand.self, from: data)
        XCTAssertEqual(decoded.commandId, cmd.commandId)
        XCTAssertEqual(decoded.fromDeviceId, cmd.fromDeviceId)
        XCTAssertEqual(decoded.targetDeviceId, cmd.targetDeviceId)
        XCTAssertEqual(decoded.command, cmd.command)
        XCTAssertEqual(decoded.payload?.stationId, cmd.payload?.stationId)
        XCTAssertEqual(decoded.payload?.stationUrl, cmd.payload?.stationUrl)
        XCTAssertEqual(decoded.payload?.stationName, cmd.payload?.stationName)
        XCTAssertEqual(decoded.sentAt, cmd.sentAt)
    }

    func testPresenceRoundTrip() throws {
        let presence = RemotePresence(
            deviceId: "dev-1",
            deviceType: "ios",
            deviceName: "Jonathan's iPhone",
            role: "sender",
            playback: RemotePlaybackState(state: "playing", stationId: "s1", stationName: "KCRW", artworkUrl: nil),
            updatedAt: "2026-06-27T00:00:00Z"
        )
        let data = try JSONEncoder().encode(presence)
        let decoded = try JSONDecoder().decode(RemotePresence.self, from: data)
        XCTAssertEqual(decoded.deviceId, presence.deviceId)
        XCTAssertEqual(decoded.deviceType, presence.deviceType)
        XCTAssertEqual(decoded.playback.state, presence.playback.state)
        XCTAssertEqual(decoded.playback.stationName, presence.playback.stationName)
        XCTAssertNil(decoded.playback.artworkUrl)
    }

    func testSnakeCaseKeys() throws {
        let cmd = RemoteCommand(
            commandId: "id1",
            fromDeviceId: "from",
            targetDeviceId: "target",
            command: "play",
            payload: nil,
            sentAt: "2026-06-27T00:00:00Z"
        )
        let data = try JSONEncoder().encode(cmd)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["command_id"])
        XCTAssertNotNil(json["from_device_id"])
        XCTAssertNotNil(json["target_device_id"])
        XCTAssertNotNil(json["sent_at"])
        XCTAssertNil(json["commandId"])
    }
}
