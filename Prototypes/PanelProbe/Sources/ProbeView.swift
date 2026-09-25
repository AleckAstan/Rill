import AppKit
import SwiftUI

@MainActor
final class ProbeModel: ObservableObject {
    @Published var clicks = 0
    @Published var focusResult = "Click to check focus"

    func recordClick() {
        clicks += 1
        focusResult = NSApp.isActive ? "Probe activated" : "Probe remained inactive"
    }
}

struct ProbeView: View {
    @ObservedObject var model: ProbeModel
    let edge: PanelEdge
    var menuBarArea = false
    var notchExclusion: CGRect?

    var body: some View {
        Group {
            if edge.isHorizontal {
                if let notch = notchExclusion {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            leadingContent
                                .padding(.horizontal, 14)
                                .frame(width: max(0, notch.minX - 8), height: geometry.size.height)
                                .clipped()
                            Color.clear.frame(width: notch.width + 16)
                                .allowsHitTesting(false)
                            trailingContent
                                .padding(.horizontal, 14)
                                .frame(width: max(0, geometry.size.width - notch.maxX - 8),
                                       height: geometry.size.height)
                                .clipped()
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        leadingContent
                        Spacer(minLength: 8)
                        trailingContent
                    }
                    .padding(.horizontal, 14)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "water.waves").foregroundStyle(.mint)
                    Text("R").fontWeight(.bold)
                    Spacer(minLength: 8)
                    counter
                }
                .padding(.vertical, 12)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.07, green: 0.09, blue: 0.12).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: menuBarArea ? 0 : 10))
        .overlay(RoundedRectangle(cornerRadius: menuBarArea ? 0 : 10).stroke(.white.opacity(0.14)))
        // Window placement covers the notch row; only content uses the exclusion above.
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    private var leadingContent: some View {
        HStack(spacing: 12) {
            brand
            Text("Panel probe · \(edge.rawValue)").foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var trailingContent: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Text(model.focusResult).font(.caption).lineLimit(1)
            counter.fixedSize()
        }
    }

    private var brand: some View {
        Label("RILL", systemImage: "water.waves")
            .fontWeight(.bold).foregroundStyle(.mint)
    }

    private var counter: some View {
        Button { model.recordClick() } label: {
            Text("\(model.clicks)").monospacedDigit().frame(minWidth: 24, minHeight: 24)
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("Test focus retention")
        .accessibilityValue("\(model.clicks) clicks. \(model.focusResult)")
        .help("Click while another app is active. Its keyboard focus should remain there.")
    }
}
