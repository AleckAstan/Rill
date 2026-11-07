import CoreAudio
import Foundation

public struct AudioInputOption: Identifiable, Equatable, Sendable {
    public let id: UInt32
    public let name: String

    public init(id: UInt32, name: String) {
        self.id = id
        self.name = name
    }
}

public struct MicrophoneSnapshot: Equatable, Sendable {
    public let deviceID: UInt32?
    public let deviceName: String?
    public let volume: Double?
    public let canSetVolume: Bool
    public let muted: Bool?
    public let canSetMuted: Bool
    public let inputs: [AudioInputOption]
    public let error: String?

    public init(
        deviceID: UInt32?, deviceName: String?, volume: Double?, canSetVolume: Bool,
        muted: Bool?, canSetMuted: Bool, inputs: [AudioInputOption], error: String? = nil
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.volume = deviceID == nil ? nil : volume.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil }
        self.canSetVolume = canSetVolume && self.volume != nil
        self.muted = deviceID == nil ? nil : muted
        self.canSetMuted = canSetMuted && self.muted != nil
        self.inputs = inputs
        self.error = error
    }

    public static let unavailable = MicrophoneSnapshot(
        deviceID: nil, deviceName: nil, volume: nil, canSetVolume: false,
        muted: nil, canSetMuted: false, inputs: []
    )

    public var presentation: ModuleData {
        guard deviceID != nil else {
            return .init(text: "", symbolName: "mic.slash.fill", tooltip: error ?? "No input device available", health: .unavailable)
        }
        let name = deviceName ?? "Microphone"
        let detail: String
        if muted == true {
            detail = "\(name): muted"
        } else if let volume {
            detail = "\(name): \(Int((volume * 100).rounded()))%"
        } else {
            detail = "\(name): input level unavailable"
        }
        return .init(
            text: "", symbolName: muted == true ? "mic.slash.fill" : "mic.fill",
            tooltip: error ?? detail, state: error == nil ? .normal : .error,
            semanticState: muted == true ? .muted : nil, value: volume
        )
    }
}

@MainActor
final class MicrophoneModuleController {
    private struct Listener {
        let objectID: AudioObjectID
        var address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }

    private let store: NativeModuleStore
    private var systemListeners: [Listener] = []
    private var deviceListeners: [Listener] = []
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var running = false
    private var generation = UUID()
    private var inputGeneration = UUID()
    private var actionError: String?
    private var listenerError: String?

    init(store: NativeModuleStore) {
        self.store = store
    }

    func start() {
        guard !running else { return }
        running = true
        generation = UUID()
        actionError = nil
        listenerError = nil
        for selector in [kAudioHardwarePropertyDefaultInputDevice, kAudioHardwarePropertyDevices] {
            if let listener = makeListener(
                objectID: AudioObjectID(kAudioObjectSystemObject), selector: selector,
                scope: kAudioObjectPropertyScopeGlobal, deviceChange: true
            ) {
                systemListeners.append(listener)
            }
        }
        bindInput()
    }

    func stop() {
        running = false
        generation = UUID()
        inputGeneration = UUID()
        removeListeners(&systemListeners)
        removeListeners(&deviceListeners)
        deviceID = AudioObjectID(kAudioObjectUnknown)
        actionError = nil
        listenerError = nil
        store.microphone = .unavailable
    }

    func setVolume(_ value: Double) {
        guard running, validateCurrentInput() else { return }
        guard value.isFinite else {
            actionError = "Input volume must be finite"
            updateSnapshot()
            return
        }
        guard store.microphone.canSetVolume else {
            actionError = "This input device does not support volume control"
            updateSnapshot()
            return
        }
        var scalar = Float32(min(1, max(0, value)))
        write(&scalar, selector: kAudioDevicePropertyVolumeScalar, failure: "Unable to change input volume")
    }

    func setMuted(_ muted: Bool) {
        guard running, validateCurrentInput() else { return }
        guard store.microphone.canSetMuted else {
            actionError = "This input device does not support hardware mute"
            updateSnapshot()
            return
        }
        var value: UInt32 = muted ? 1 : 0
        write(&value, selector: kAudioDevicePropertyMute, failure: "Unable to change microphone mute")
    }

    func selectInput(_ inputID: UInt32) {
        guard running else { return }
        guard availableInputs().contains(where: { $0.id == inputID }) else {
            actionError = "The selected input device is no longer available"
            updateSnapshot()
            return
        }
        var address = property(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal)
        var value = inputID
        let result = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &value
        )
        actionError = result == noErr ? nil : "Unable to select input device (\(result))"
        bindInput()
    }

    private func validateCurrentInput() -> Bool {
        let current: AudioObjectID? = read(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultInputDevice,
            scope: kAudioObjectPropertyScopeGlobal, initial: AudioObjectID(kAudioObjectUnknown)
        )
        guard deviceID != AudioObjectID(kAudioObjectUnknown), current == deviceID else {
            bindInput()
            actionError = "The input device changed; try again"
            updateSnapshot()
            return false
        }
        return true
    }

    private func bindInput() {
        guard running else { return }
        inputGeneration = UUID()
        removeListeners(&deviceListeners)
        let previousDeviceID = deviceID
        deviceID = read(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultInputDevice,
            scope: kAudioObjectPropertyScopeGlobal, initial: AudioObjectID(kAudioObjectUnknown)
        ) ?? AudioObjectID(kAudioObjectUnknown)
        if deviceID != previousDeviceID { actionError = nil }
        if deviceID != AudioObjectID(kAudioObjectUnknown) {
            for selector in [kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyMute, kAudioDevicePropertyDeviceIsAlive] {
                let scope = selector == kAudioDevicePropertyDeviceIsAlive
                    ? kAudioObjectPropertyScopeGlobal : kAudioDevicePropertyScopeInput
                var address = property(selector, scope: scope)
                guard AudioObjectHasProperty(deviceID, &address) else { continue }
                if let listener = makeListener(objectID: deviceID, selector: selector, scope: scope, deviceChange: false) {
                    deviceListeners.append(listener)
                }
            }
        }
        updateSnapshot()
    }

    private func updateSnapshot() {
        guard running else { return }
        let inputs = availableInputs()
        let current = inputs.first { $0.id == deviceID }
        guard let current else {
            store.microphone = .init(
                deviceID: nil, deviceName: nil, volume: nil, canSetVolume: false,
                muted: nil, canSetMuted: false, inputs: inputs, error: actionError ?? listenerError
            )
            return
        }
        let scalar: Float32? = read(objectID: deviceID, selector: kAudioDevicePropertyVolumeScalar, initial: Float32(0))
        let mute: UInt32? = read(objectID: deviceID, selector: kAudioDevicePropertyMute, initial: UInt32(0))
        store.microphone = .init(
            deviceID: current.id, deviceName: current.name, volume: scalar.map(Double.init),
            canSetVolume: isSettable(kAudioDevicePropertyVolumeScalar), muted: mute.map { $0 != 0 },
            canSetMuted: isSettable(kAudioDevicePropertyMute), inputs: inputs, error: actionError ?? listenerError
        )
    }

    private func availableInputs() -> [AudioInputOption] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = property(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
              size >= MemoryLayout<AudioObjectID>.size else { return [] }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return [] }
        return devices.compactMap { id in
            var streamAddress = property(kAudioDevicePropertyStreams)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streamAddress, 0, nil, &streamSize) == noErr,
                  streamSize > 0 else { return nil }
            let alive: UInt32? = read(
                objectID: id, selector: kAudioDevicePropertyDeviceIsAlive,
                scope: kAudioObjectPropertyScopeGlobal, initial: UInt32(0)
            )
            guard alive == 1 else { return nil }
            var nameAddress = property(kAudioObjectPropertyName, scope: kAudioObjectPropertyScopeGlobal)
            var name: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &name) == noErr,
                  let name else { return nil }
            return AudioInputOption(id: id, name: name.takeUnretainedValue() as String)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func property(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeInput
    ) -> AudioObjectPropertyAddress {
        .init(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private func read<Value: BitwiseCopyable>(
        objectID: AudioObjectID, selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeInput, initial: Value
    ) -> Value? {
        var address = property(selector, scope: scope)
        var value = initial
        var size = UInt32(MemoryLayout<Value>.size)
        guard AudioObjectHasProperty(objectID, &address),
              AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private func isSettable(_ selector: AudioObjectPropertySelector) -> Bool {
        var address = property(selector)
        var settable: DarwinBoolean = false
        return AudioObjectHasProperty(deviceID, &address) &&
            AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr && settable.boolValue
    }

    private func write<Value: BitwiseCopyable>(
        _ value: inout Value, selector: AudioObjectPropertySelector, failure: String
    ) {
        var address = property(selector)
        let result = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Value>.size), &value)
        actionError = result == noErr ? nil : "\(failure) (\(result))"
        updateSnapshot()
    }

    private func makeListener(
        objectID: AudioObjectID, selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope, deviceChange: Bool
    ) -> Listener? {
        var address = property(selector, scope: scope)
        let generation = self.generation
        let inputGeneration = self.inputGeneration
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.running, self.generation == generation else { return }
                guard deviceChange || self.inputGeneration == inputGeneration else { return }
                if deviceChange { self.bindInput() } else { self.updateSnapshot() }
            }
        }
        let result = AudioObjectAddPropertyListenerBlock(objectID, &address, .main, block)
        guard result == noErr else {
            listenerError = "Unable to observe input device changes (\(result))"
            return nil
        }
        return Listener(objectID: objectID, address: address, block: block)
    }

    private func removeListeners(_ listeners: inout [Listener]) {
        for var listener in listeners {
            let result = AudioObjectRemovePropertyListenerBlock(listener.objectID, &listener.address, .main, listener.block)
            if result != noErr { listenerError = "Unable to remove input device observer (\(result))" }
        }
        listeners.removeAll()
    }
}
