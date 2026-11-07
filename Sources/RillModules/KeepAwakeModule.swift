import Foundation
import IOKit.pwr_mgt

public struct KeepAwakeSnapshot: Equatable, Sendable {
    public var active: Bool
    public var error: String?

    public static let inactive = KeepAwakeSnapshot(active: false)

    public var presentation: ModuleData {
        .init(
            text: "",
            symbolName: active ? "cup.and.saucer.fill" : "cup.and.saucer",
            tooltip: error ?? (active ? "Keep awake is on" : "Keep awake is off"),
            health: error == nil ? .healthy : .unavailable,
            semanticState: active ? .active : .off
        )
    }
}

final class KeepAwakeAssertion {
    private var assertionID: IOPMAssertionID?
    private let create: () -> (IOReturn, IOPMAssertionID)
    private let release: (IOPMAssertionID) -> IOReturn

    var active: Bool { assertionID != nil }

    init(
        create: @escaping () -> (IOReturn, IOPMAssertionID) = {
            var identifier = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoIdleSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Rill keep awake" as CFString,
                &identifier
            )
            return (result, identifier)
        },
        release: @escaping (IOPMAssertionID) -> IOReturn = { IOPMAssertionRelease($0) }
    ) {
        self.create = create
        self.release = release
    }

    func setEnabled(_ enabled: Bool) -> IOReturn {
        if enabled {
            guard assertionID == nil else { return kIOReturnSuccess }
            let (result, identifier) = create()
            if result == kIOReturnSuccess { assertionID = identifier }
            return result
        }
        guard let identifier = assertionID else { return kIOReturnSuccess }
        let result = release(identifier)
        if result == kIOReturnSuccess { assertionID = nil }
        return result
    }

    deinit {
        if let assertionID { _ = release(assertionID) }
    }
}

@MainActor
final class KeepAwakeController {
    private let store: NativeModuleStore
    private let assertion = KeepAwakeAssertion()

    init(store: NativeModuleStore) {
        self.store = store
    }

    func setEnabled(_ enabled: Bool) {
        let result = assertion.setEnabled(enabled)
        store.keepAwake = .init(
            active: assertion.active,
            error: result == kIOReturnSuccess ? nil : "Unable to change keep awake (IOKit error \(result))"
        )
    }

    func stop() {
        setEnabled(false)
    }
}
