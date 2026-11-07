import CoreBluetooth
import Foundation
import IOBluetooth

public struct BluetoothDeviceOption: Identifiable, Equatable, Sendable {
    public let address: String
    public let name: String
    public let connected: Bool

    public var id: String { address }

    public init(address: String, name: String, connected: Bool) {
        self.address = address
        self.name = name
        self.connected = connected
    }
}

public enum BluetoothState: Equatable, Sendable {
    case unavailable
    case starting
    case unauthorized
    case unsupported
    case poweredOff
    case poweredOn
}

public struct BluetoothSnapshot: Equatable, Sendable {
    public var state: BluetoothState
    public var devices: [BluetoothDeviceOption]
    public var refreshing: Bool
    public var busyAddress: String?
    public var error: String?

    public static let unavailable = BluetoothSnapshot(state: .unavailable)

    public init(
        state: BluetoothState,
        devices: [BluetoothDeviceOption] = [],
        refreshing: Bool = false,
        busyAddress: String? = nil,
        error: String? = nil
    ) {
        self.state = state
        self.devices = devices
        self.refreshing = refreshing
        self.busyAddress = busyAddress
        self.error = error
    }

    public var status: String {
        switch state {
        case .unavailable: return "Bluetooth unavailable"
        case .starting: return "Checking Bluetooth"
        case .unauthorized: return "Allow Rill in System Settings > Privacy & Security > Bluetooth"
        case .unsupported: return "Bluetooth hardware unavailable"
        case .poweredOff: return "Bluetooth is off"
        case .poweredOn:
            let connected = devices.filter(\.connected).count
            return connected == 0 ? "Bluetooth is on" : "Bluetooth: \(connected) connected"
        }
    }

    public var presentation: ModuleData {
        let health: ModuleHealth
        switch state {
        case .poweredOn, .poweredOff: health = .healthy
        case .starting: health = .stale
        case .unavailable, .unauthorized, .unsupported: health = .unavailable
        }
        let semantic: ModuleSemanticState?
        switch state {
        case .poweredOff: semantic = .off
        case .poweredOn: semantic = devices.contains(where: \.connected) ? .connected : .disconnected
        default: semantic = nil
        }
        return .init(
            text: "",
            symbolName: "rill.bluetooth",
            tooltip: error ?? status,
            health: health,
            state: error == nil ? .normal : .error,
            semanticState: semantic
        )
    }
}

private actor BluetoothDeviceAccess {
    func pairedDevices() -> [BluetoothDeviceOption] {
        guard !Task.isCancelled else { return [] }
        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        return devices.compactMap { device in
            guard let address = device.addressString else { return nil }
            let name = device.name ?? ""
            return BluetoothDeviceOption(
                address: address,
                name: name.isEmpty ? address : name,
                connected: device.isConnected()
            )
        }.sorted {
            if $0.connected != $1.connected { return $0.connected }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func setConnected(_ connected: Bool, address: String) -> String? {
        guard !Task.isCancelled else { return nil }
        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        guard let device = devices.first(where: { $0.addressString == address }) else {
            return "This device is no longer paired. Open Bluetooth Settings to pair it."
        }
        guard device.isConnected() != connected else { return nil }
        let result = connected
            ? device.openConnection(nil, withPageTimeout: 8_192, authenticationRequired: true)
            : device.closeConnection()
        guard result != kIOReturnSuccess else { return nil }
        return "Unable to \(connected ? "connect" : "disconnect") \(device.name ?? address) (Bluetooth error \(result))"
    }
}

@MainActor
public final class BluetoothModuleController: NSObject, @preconcurrency CBCentralManagerDelegate {
    private weak var store: NativeModuleStore?
    private let devices = BluetoothDeviceAccess()
    private var central: CBCentralManager?
    private var refreshTask: Task<Void, Never>?
    private var operationTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var generation = UUID()
    private var active = false

    public init(store: NativeModuleStore) {
        self.store = store
        super.init()
    }

    public func start() {
        guard !active else { return }
        active = true
        generation = UUID()
        store?.bluetooth = .init(state: .starting)
        central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    public func stop() {
        active = false
        generation = UUID()
        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshTask?.cancel()
        refreshTask = nil
        operationTask?.cancel()
        operationTask = nil
        central?.delegate = nil
        central = nil
        store?.bluetooth = .unavailable
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard active, central === self.central else { return }
        refreshTask?.cancel()
        refreshTask = nil
        operationTask?.cancel()
        operationTask = nil
        generation = UUID()
        store?.bluetooth = .init(state: state(of: central))
        refresh()
    }

    public func refresh() {
        guard active, store?.bluetooth.state == .poweredOn, refreshTask == nil, operationTask == nil else { return }
        let generation = generation
        store?.bluetooth.refreshing = true
        refreshTask = Task { [weak self, devices] in
            let paired = await devices.pairedDevices()
            guard let self, !Task.isCancelled, self.active, self.generation == generation else { return }
            self.store?.bluetooth.devices = paired
            self.store?.bluetooth.refreshing = false
            self.refreshTask = nil
        }
    }

    public func connect(address: String) {
        setConnected(true, address: address)
    }

    public func disconnect(address: String) {
        setConnected(false, address: address)
    }

    private func setConnected(_ connected: Bool, address: String) {
        guard active, store?.bluetooth.state == .poweredOn, operationTask == nil else { return }
        guard store?.bluetooth.devices.contains(where: { $0.address == address }) == true else {
            store?.bluetooth.error = "This device is no longer available. Refresh the paired-device list."
            return
        }
        refreshTask?.cancel()
        refreshTask = nil
        store?.bluetooth.refreshing = false
        store?.bluetooth.busyAddress = address
        store?.bluetooth.error = nil
        let generation = generation
        operationTask = Task { [weak self, devices] in
            let error = await devices.setConnected(connected, address: address)
            let paired = await devices.pairedDevices()
            guard let self, !Task.isCancelled, self.active, self.generation == generation else { return }
            self.store?.bluetooth.devices = paired
            self.store?.bluetooth.error = error
            self.store?.bluetooth.busyAddress = nil
            self.operationTask = nil
        }
    }

    private func state(of central: CBCentralManager) -> BluetoothState {
        switch central.state {
        case .poweredOn: return .poweredOn
        case .poweredOff: return .poweredOff
        case .unauthorized: return .unauthorized
        case .unsupported: return .unsupported
        case .unknown, .resetting: return .starting
        @unknown default: return .unavailable
        }
    }
}
