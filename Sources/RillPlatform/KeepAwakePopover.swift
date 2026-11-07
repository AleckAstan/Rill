import SwiftUI

struct KeepAwakePopover: View {
    @ObservedObject var store: NativeModuleStore
    let perform: (NativeModuleAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Keep awake", isOn: Binding(
                get: { store.keepAwake.active },
                set: { perform(.setKeepAwake($0)) }
            ))
            Text("Prevents automatic system sleep while Rill is running. The display can still turn off, and closing the lid or choosing Sleep still works.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error = store.keepAwake.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }
}
