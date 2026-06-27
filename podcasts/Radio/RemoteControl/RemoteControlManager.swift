import Foundation
import Supabase
import UIKit
import PocketCastsServer

class RemoteControlManager {
    static let shared = RemoteControlManager()

    private let deviceIdKey = "pocketradio-device-id"

    private var client: SupabaseClient?
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?

    var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        return newId
    }

    func start() {
        guard let userId = ServerSettings.userId, !userId.isEmpty else { return }
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString) else { return }
        let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""

        let supabase = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                global: .init(headers: ["x-user-uuid": userId])
            )
        )
        client = supabase

        let ch = supabase.channel("remote:\(userId)") { config in
            config.broadcast.receiveOwnBroadcasts = false
            config.presence.key = deviceId
        }
        channel = ch

        listenTask = Task { [weak self] in
            guard let self else { return }
            for await msg in ch.broadcastStream(event: "command") {
                self.handleIncomingBroadcast(msg)
            }
        }

        presenceTask = Task { [weak self] in
            guard let self else { return }
            for await action in ch.presenceChange() {
                let joins = action.joins
                let leaves = action.leaves
                print("🌐 RemoteControl: presence_diff joins=\(joins.count) leaves=\(leaves.count)")
                for key in joins.keys { print("🌐 RemoteControl:   join device=\(key)") }
                for key in leaves.keys { print("🌐 RemoteControl:   leave device=\(key)") }
            }
        }

        Task { [weak self] in
            guard let self else { return }
            await ch.subscribe()
            print("🌐 RemoteControl: subscribed channel=remote:\(userId) device=\(deviceId)")
            await self.trackPresence(channel: ch)
        }

        observePlaybackNotifications()
    }

    func stop() {
        listenTask?.cancel()
        presenceTask?.cancel()
        listenTask = nil
        presenceTask = nil
        Task { [weak self] in
            guard let ch = self?.channel else { return }
            await ch.unsubscribe()
        }
        channel = nil
        client = nil
        removePlaybackObservers()
    }

    func updatePresence() {
        guard let ch = channel else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.trackPresence(channel: ch)
        }
    }

    /// Send a command to a specific device. Provide nil targetDeviceId to broadcast to all.
    func send(command: String, to targetDeviceId: String, payload: RemoteCommandPayload? = nil) {
        guard let ch = channel, let userId = ServerSettings.userId else { return }
        let cmd = RemoteCommand(
            commandId: UUID().uuidString,
            fromDeviceId: deviceId,
            targetDeviceId: targetDeviceId,
            command: command,
            payload: payload,
            sentAt: ISO8601DateFormatter().string(from: Date())
        )
        Task {
            do {
                try await ch.broadcast(event: "command", message: cmd)
                print("🌐 RemoteControl: sent command=\(command) to=\(targetDeviceId) from=\(userId)")
            } catch {
                print("🌐 RemoteControl: broadcast failed: \(error)")
            }
        }
    }

    // MARK: - Private

    private func trackPresence(channel: RealtimeChannelV2) async {
        let pm = PlaybackManager.shared
        let episode = pm.currentEpisode()
        let playing = pm.playing()

        let playbackState: String
        if episode == nil {
            playbackState = "idle"
        } else if playing {
            playbackState = "playing"
        } else {
            playbackState = "paused"
        }

        let station = episode as? RadioStation
        let presence = RemotePresence(
            deviceId: deviceId,
            deviceType: "ios",
            deviceName: UIDevice.current.name,
            role: "sender",
            playback: RemotePlaybackState(
                state: playbackState,
                stationId: station?.stationId,
                stationName: station?.title,
                artworkUrl: nil
            ),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        do {
            try await channel.track(presence)
            print("🌐 RemoteControl: tracked presence state=\(playbackState)")
        } catch {
            print("🌐 RemoteControl: presence track failed: \(error)")
        }
    }

    private func handleIncomingBroadcast(_ msg: JSONObject) {
        guard let data = try? JSONEncoder().encode(msg),
              let cmd = try? JSONDecoder().decode(RemoteCommand.self, from: data) else {
            print("🌐 RemoteControl: failed to decode incoming command")
            return
        }
        guard cmd.targetDeviceId == deviceId else { return }
        print("🌐 RemoteControl: received command=\(cmd.command) from=\(cmd.fromDeviceId) id=\(cmd.commandId)")
    }

    private var playbackObservers: [NSObjectProtocol] = []

    private func observePlaybackNotifications() {
        let center = NotificationCenter.default
        let notifications: [Notification.Name] = [
            Constants.Notifications.playbackStarted,
            Constants.Notifications.playbackPaused,
            Constants.Notifications.playbackTrackChanged
        ]
        playbackObservers = notifications.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.updatePresence()
            }
        }
    }

    private func removePlaybackObservers() {
        playbackObservers.forEach { NotificationCenter.default.removeObserver($0) }
        playbackObservers = []
    }
}
