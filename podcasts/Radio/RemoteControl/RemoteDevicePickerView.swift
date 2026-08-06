import SwiftUI

struct RemoteDevicePickerView: View {
    let devices: [RemotePresence]
    let currentTargetId: String?
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if devices.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No devices found")
                            .font(.headline)
                        Text("Open PocketStreams on another device and sign in.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(devices, id: \.deviceId) { device in
                        Button {
                            onSelect(device.deviceId == currentTargetId ? nil : device.deviceId)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: device.deviceType == "macos" ? "desktopcomputer" : "iphone")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.deviceName)
                                        .foregroundColor(.primary)
                                    Text(stateLabel(device.playback.state))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if device.deviceId == currentTargetId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Play on…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if currentTargetId != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Stop Remote") {
                            onSelect(nil)
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private func stateLabel(_ state: String) -> String {
        switch state {
        case "playing": return "Playing"
        case "paused": return "Paused"
        default: return "Idle"
        }
    }
}
