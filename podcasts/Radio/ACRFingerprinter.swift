#if !os(watchOS) && !APPCLIP && !os(tvOS)
import CryptoKit
import Foundation
import OSLog

private let acrLog = Logger(subsystem: "com.jdj.pocketradio", category: "ACR")

// MARK: - Credentials

struct ACRCloudCredentials {
    let host: String
    let accessKey: String
    let accessSecret: String
}

// MARK: - Result

struct ACRFingerprintResult {
    let title: String
    let artist: String
    let album: String
    let confidence: Int

    var displayTitle: String {
        artist.isEmpty ? title : "\(title) — \(artist)"
    }
}

// MARK: - Fingerprinter

final class ACRFingerprinter {

    static var credentials = ACRCloudCredentials(
        host: "identify-us-west-2.acrcloud.com",
        accessKey: "69df99de909bfee94d568df3a286ef7a",
        accessSecret: "33FF4Z7ZOizLNjLLRoZLuQKKwSNsNlI0i0hsGiIJ"
    )

    var minConfidence: Int = 70
    var captureSeconds: Double = 15

    private let streamURL: URL
    private var task: Task<Void, Never>?

    init(streamURL: URL) {
        self.streamURL = streamURL
    }

    func identifyOnce(onResult: @escaping (ACRFingerprintResult) -> Void,
                      onError: @escaping (String) -> Void) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            guard let data = await self.captureAudioBytes() else {
                await MainActor.run { onError("Failed to capture audio") }
                return
            }
            await self.recognize(audioData: data, onResult: onResult, onError: onError)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    // MARK: - Capture

    private func captureAudioBytes() async -> Data? {
        var request = URLRequest(url: streamURL, timeoutInterval: 30)
        request.setValue("PocketRadio-Fingerprinter/1.0", forHTTPHeaderField: "User-Agent")
        // Do NOT request ICY metadata — injected title chunks corrupt the fingerprint.

        do {
            let (asyncBytes, _) = try await URLSession.shared.bytes(for: request)
            let deadline = Date().addingTimeInterval(captureSeconds)
            var data = Data()
            data.reserveCapacity(2_000_000)
            for try await byte in asyncBytes {
                data.append(byte)
                if Date() >= deadline { break }
            }
            acrLog.debug("captured \(data.count) bytes in \(Int(self.captureSeconds))s")
            return data.isEmpty ? nil : data
        } catch {
            acrLog.error("capture error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - ACRCloud REST identification

    private func recognize(audioData: Data,
                           onResult: @escaping (ACRFingerprintResult) -> Void,
                           onError: @escaping (String) -> Void) async {
        let creds = Self.credentials
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let httpURI = "/v1/identify"
        let stringToSign = ["POST", httpURI, creds.accessKey, "audio", "1", timestamp]
            .joined(separator: "\n")

        let key = SymmetricKey(data: Data(creds.accessSecret.utf8))
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: Data(stringToSign.utf8), using: key)
        let signature = Data(mac).base64EncodedString()

        let boundary = "PocketRadioACR\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()

        func field(_ name: String, _ value: String) {
            body += "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n"
                .data(using: .utf8)!
        }

        field("access_key", creds.accessKey)
        field("sample_bytes", String(audioData.count))
        field("timestamp", timestamp)
        field("signature", signature)
        field("data_type", "audio")
        field("signature_version", "1")

        body += "--\(boundary)\r\nContent-Disposition: form-data; name=\"sample\"; filename=\"sample.mp3\"\r\nContent-Type: application/octet-stream\r\n\r\n"
            .data(using: .utf8)!
        body += audioData
        body += "\r\n--\(boundary)--\r\n".data(using: .utf8)!

        guard let url = URL(string: "https://\(creds.host)\(httpURI)") else {
            await MainActor.run { onError("Invalid ACRCloud host") }
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
            acrLog.debug("ACR HTTP \(httpStatus), \(data.count) bytes")

            guard let result = parseResult(data) else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                acrLog.debug("No match: \(raw, privacy: .public)")
                await MainActor.run { onError("No match") }
                return
            }

            if result.confidence >= minConfidence {
                acrLog.debug("Match: \(result.displayTitle, privacy: .public) (\(result.confidence)%)")
                await MainActor.run { onResult(result) }
            } else {
                await MainActor.run { onError("Low confidence (\(result.confidence)) for \(result.title)") }
            }
        } catch {
            await MainActor.run { onError("Network error: \(error.localizedDescription)") }
        }
    }

    #if DEBUG
    func parseResultForTesting(_ data: Data) -> ACRFingerprintResult? { parseResult(data) }
    #endif

    private func parseResult(_ data: Data) -> ACRFingerprintResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? [String: Any],
              (status["code"] as? Int) == 0,
              let metadata = json["metadata"] as? [String: Any],
              let music = metadata["music"] as? [[String: Any]],
              let top = music.first else { return nil }

        let title  = top["title"]   as? String ?? ""
        let artist = (top["artists"] as? [[String: Any]])?.first?["name"] as? String ?? ""
        let album  = (top["album"]  as? [String: Any])?["name"] as? String ?? ""
        let score  = top["score"]   as? Int ?? 0

        return ACRFingerprintResult(title: title, artist: artist, album: album, confidence: score)
    }
}
#endif
