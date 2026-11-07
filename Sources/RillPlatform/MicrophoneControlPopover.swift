import SwiftUI

struct MicrophoneControlPopover: View {
    @ObservedObject var store: NativeModuleStore
    let perform: (NativeModuleAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Microphone", systemImage: "mic.fill")
                .font(.headline)
            if snapshot.deviceID != nil {
                Text(snapshot.deviceName ?? "Input device")
                    .font(.subheadline)
                Toggle("Mute microphone", isOn: Binding(
                    get: { snapshot.muted == true },
                    set: { perform(.setMicrophoneMuted($0)) }
                ))
                .disabled(!snapshot.canSetMuted)
                if !snapshot.canSetMuted {
                    Text("This input device does not support hardware mute.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Slider(value: Binding(
                        get: { snapshot.volume ?? 0 },
                        set: { perform(.setMicrophoneVolume($0)) }
                    ), in: 0...1)
                    .disabled(!snapshot.canSetVolume)
                    .accessibilityLabel("Microphone input volume")
                    Text(snapshot.volume.map { "\(Int(($0 * 100).rounded()))%" } ?? "Unavailable")
                        .monospacedDigit()
                }
                if !snapshot.canSetVolume {
                    Text("This input device does not support volume adjustment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No input device available")
                    .foregroundStyle(.secondary)
            }
            if !snapshot.inputs.isEmpty {
                Text("Input").font(.subheadline.weight(.semibold))
                ForEach(snapshot.inputs) { input in
                    Button {
                        perform(.selectAudioInput(input.id))
                    } label: {
                        HStack {
                            Image(systemName: input.id == snapshot.deviceID ? "checkmark.circle.fill" : "circle")
                                .accessibilityHidden(true)
                            Text(input.name).lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 3)
                    .accessibilityLabel("Input: \(input.name)")
                    .accessibilityValue(input.id == snapshot.deviceID ? "Selected" : "Not selected")
                }
            }
            if let error = snapshot.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Divider()
            HStack {
                Spacer()
                SettingsButton(
                    title: "Sound Settings…",
                    url: "x-apple.systempreferences:com.apple.Sound-Settings.extension"
                )
            }
        }
        .frame(minWidth: 260, maxWidth: 320)
    }

    private var snapshot: MicrophoneSnapshot { store.microphone }
}
