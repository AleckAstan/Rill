import Foundation
import RillExtensionKit

@main
struct RillRichSample {
    static func main() throws {
        let connection = RillExtensionConnection()
        guard let context = try connection.receive(), context.kind == .context else { return }
        try connection.send(.init(kind: .hello, extensionID: "dev.rill.sample.rich"))
        try publish(connection, detail: "SDK connected")
        while let message = try connection.receive() {
            switch message.kind {
            case .action:
                try publish(connection, detail: "Action: \(message.actionID ?? "unknown")")
            case .shutdown:
                return
            default:
                continue
            }
        }
    }

    static func publish(_ connection: RillExtensionConnection, detail: String) throws {
        let compact = RillExtensionNode.hStack([
            .symbol("sparkles", label: "Rich sample"),
            .text("Extension SDK"),
            .init(kind: .progress, value: 0.72, label: "72 percent"),
            .button("Refresh", actionID: "refresh", children: [.symbol("arrow.clockwise", label: "Refresh")])
        ])
        let expanded = RillExtensionNode.vStack([
            .text("Rich native extension", label: "Rich native extension"),
            .init(kind: .divider),
            .init(kind: .image, resource: "Resources/sample.svg", label: "Rill sample artwork"),
            .init(kind: .list, children: [
                .text(detail),
                .text("Rendered by Rill, out of process")
            ]),
            .init(kind: .spacer),
            .init(kind: .popover, label: "About", children: [
                .text("About"),
                .text("This popover is described by the extension and rendered natively by Rill.")
            ])
        ])
        let presentation = RillExtensionPresentation(compact: compact, expanded: expanded)
        for contribution in ["rich-bar", "rich-notch"] {
            try connection.send(.init(
                kind: .update,
                extensionID: "dev.rill.sample.rich",
                contributionID: contribution,
                presentation: presentation
            ))
        }
    }
}
