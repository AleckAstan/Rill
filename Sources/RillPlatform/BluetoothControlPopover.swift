import SwiftUI

struct BluetoothControlPopover: View {
    @ObservedObject var store: NativeModuleStore
    let perform: (NativeModuleAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text("Bluetooth")
                } icon: {
                    BluetoothIcon(size: 16)
                }
                .font(.headline)
                Spacer()
                if snapshot.refreshing || snapshot.busyAddress != nil {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel("Updating Bluetooth devices")
                }
            }
            Text(snapshot.status).font(.subheadline)
            if snapshot.state == .poweredOn {
                Text("Paired devices").font(.subheadline.weight(.semibold))
                if snapshot.devices.isEmpty {
                    Text("No paired devices. Add a device in Bluetooth Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(snapshot.devices) { device in
                                deviceRow(device)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
            if let error = snapshot.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Divider()
            HStack {
                Button {
                    perform(.refreshBluetooth)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(snapshot.state != .poweredOn || snapshot.refreshing || snapshot.busyAddress != nil)
                Spacer()
                SettingsButton(
                    title: "Bluetooth Settings…",
                    url: "x-apple.systempreferences:com.apple.BluetoothSettings"
                )
            }
        }
    }

    private var snapshot: BluetoothSnapshot { store.bluetooth }

    private func deviceRow(_ device: BluetoothDeviceOption) -> some View {
        HStack(spacing: 8) {
            Image(systemName: device.connected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(device.connected ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).lineLimit(1)
                Text(device.connected ? "Connected" : "Not connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(device.connected ? "Disconnect" : "Connect") {
                if device.connected {
                    perform(.disconnectBluetooth(address: device.address))
                } else {
                    perform(.connectBluetooth(address: device.address))
                }
            }
            .disabled(snapshot.busyAddress != nil)
            .accessibilityLabel("\(device.connected ? "Disconnect" : "Connect") \(device.name)")
        }
    }
}

struct BluetoothIcon: View {
    let size: CGFloat

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size * 0.25))
            path.addLine(to: CGPoint(x: size * 0.6, y: size * 0.75))
            path.addLine(to: CGPoint(x: size * 0.3, y: size))
            path.addLine(to: CGPoint(x: size * 0.3, y: 0))
            path.addLine(to: CGPoint(x: size * 0.6, y: size * 0.25))
            path.addLine(to: CGPoint(x: 0, y: size * 0.75))
        }
        .stroke(style: StrokeStyle(lineWidth: max(1.2, size * 0.09), lineCap: .round, lineJoin: .round))
        .frame(width: size * 0.6, height: size)
        .accessibilityHidden(true)
    }
}
