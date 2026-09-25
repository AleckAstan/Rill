import AppKit
import SwiftUI

@MainActor
final class ProbePanel: NSPanel {
    var usesMenuBarArea = false

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        usesMenuBarArea ? frameRect : super.constrainFrameRect(frameRect, to: screen)
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class ProbeHostingView: NSHostingView<ProbeView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
}

@main
@MainActor
final class PanelProbe: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panels: [ProbePanel] = []
    private let model = ProbeModel()
    private var edge: PanelEdge = .top
    private var level: NSWindow.Level = .floating
    private var fullscreenAuxiliary = false
    private var allDisplays = true
    private var topUsesMenuBarArea = true

    static func main() {
        let app = NSApplication.shared
        let delegate = PanelProbe()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--edge"), args.indices.contains(index + 1),
           let value = PanelEdge(rawValue: args[index + 1]) { edge = value }
        topUsesMenuBarArea = !args.contains("--below-system-ui")
        makeMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(reconcile),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            workspace.addObserver(self, selector: #selector(reconcile), name: name, object: nil)
        }
        reconcile()
        if args.contains("--smoke-test") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.runSmokeTest()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        panels.forEach { $0.close() }
        panels.removeAll()
    }

    private var screens: [NSScreen] {
        allDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
    }

    private func availableFrame(_ screen: NSScreen) -> CGRect {
        // Menu-bar placement intentionally includes the camera housing's row.
        // The view protects interactive content separately using the auxiliary areas.
        if edge == .top && topUsesMenuBarArea { return screen.frame }
        let frame = screen.frame
        let safe = screen.safeAreaInsets
        let safeFrame = CGRect(x: frame.minX + safe.left, y: frame.minY + safe.bottom,
            width: frame.width - safe.left - safe.right,
            height: frame.height - safe.top - safe.bottom)
        return screen.visibleFrame.intersection(safeFrame)
    }

    private func panelFrame(_ screen: NSScreen) -> CGRect? {
        if edge == .top && topUsesMenuBarArea {
            return PanelGeometry.menuBarFrame(in: screen.frame, topInset: screen.safeAreaInsets.top)
        }
        return PanelGeometry.frame(in: availableFrame(screen), edge: edge)
    }

    @objc private func reconcile() {
        panels.forEach { $0.close() }
        panels.removeAll()
        for screen in screens {
            guard let frame = panelFrame(screen) else { continue }
            let panel = ProbePanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false)
            panel.usesMenuBarArea = edge == .top && topUsesMenuBarArea
            panel.isReleasedWhenClosed = false
            panel.level = level
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle,
                fullscreenAuxiliary ? .fullScreenAuxiliary : .fullScreenNone]
            panel.hidesOnDeactivate = false
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovable = false
            panel.title = "Rill Panel Probe — \(edge.rawValue)"
            let menuBarArea = edge == .top && topUsesMenuBarArea
            let exclusion = menuBarArea ? PanelGeometry.notchExclusion(in: frame,
                leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea) : nil
            let content = ProbeHostingView(rootView: ProbeView(model: model, edge: edge,
                menuBarArea: menuBarArea, notchExclusion: exclusion))
            if menuBarArea { content.safeAreaRegions = [] }
            panel.contentView = content
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    private func makeMenu() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem?.button?.title = "Rill ◇"
        }
        let menu = NSMenu()
        let heading = NSMenuItem(title: "Rill · Panel feasibility probe", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        menu.addItem(.separator())
        for value in PanelEdge.allCases {
            let item = add("Edge: \(value.rawValue.capitalized)", action: #selector(changeEdge(_:)), to: menu)
            item.representedObject = value.rawValue
            item.state = edge == value ? .on : .off
        }
        menu.addItem(.separator())
        for (name, value) in [("Normal", NSWindow.Level.normal), ("Floating", .floating), ("Status bar", .statusBar)] {
            let item = add("Level: \(name)", action: #selector(changeLevel(_:)), to: menu)
            item.tag = value.rawValue
            item.state = level == value ? .on : .off
        }
        menu.addItem(.separator())
        add("Top: use menu-bar area (enable macOS auto-hide)", action: #selector(toggleTopPlacement), to: menu).state = topUsesMenuBarArea ? .on : .off
        add("All displays", action: #selector(toggleDisplays), to: menu).state = allDisplays ? .on : .off
        add("Fullscreen auxiliary (experiment)", action: #selector(toggleFullscreen), to: menu).state = fullscreenAuxiliary ? .on : .off
        add("Rebuild panels", action: #selector(reconcile), to: menu)
        add("Copy diagnostics", action: #selector(copyDiagnostics), to: menu)
        menu.addItem(.separator())
        let quit = add("Quit Panel Probe", action: #selector(quit), to: menu)
        quit.keyEquivalent = "q"
        statusItem?.menu = menu
    }

    @discardableResult
    private func add(_ title: String, action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func changeEdge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let selected = PanelEdge(rawValue: raw) else { return }
        edge = selected
        reconcile()
        makeMenu()
    }
    @objc private func changeLevel(_ sender: NSMenuItem) {
        level = NSWindow.Level(rawValue: sender.tag)
        reconcile()
        makeMenu()
    }
    @objc private func toggleTopPlacement() { topUsesMenuBarArea.toggle(); reconcile(); makeMenu() }
    @objc private func toggleDisplays() { allDisplays.toggle(); reconcile(); makeMenu() }
    @objc private func toggleFullscreen() { fullscreenAuxiliary.toggle(); reconcile(); makeMenu() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func rect(_ value: CGRect) -> [String: Double] {
        ["x": value.minX, "y": value.minY, "width": value.width, "height": value.height]
    }

    private func diagnostics() -> [String: Any] {
        ["os": ProcessInfo.processInfo.operatingSystemVersionString,
         "edge": edge.rawValue, "level": level.rawValue,
         "topPlacement": topUsesMenuBarArea ? "menuBarArea" : "belowSystemUI",
         "fullscreenPolicy": fullscreenAuxiliary ? "auxiliary-experiment" : "fullScreenNone-unverified",
         "appActive": NSApp.isActive, "panelCount": panels.count, "clicks": model.clicks,
         "screens": screens.map { screen -> [String: Any] in
             let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
             let uuid = number.flatMap { CGDisplayCreateUUIDFromDisplayID($0.uint32Value)?.takeRetainedValue() }
             return ["displayUUID": uuid.map { CFUUIDCreateString(nil, $0) as String } ?? "unavailable",
                 "frame": rect(screen.frame), "visibleFrame": rect(screen.visibleFrame),
                 "availableFrame": rect(availableFrame(screen)), "scale": screen.backingScaleFactor,
                 "safeAreaTop": screen.safeAreaInsets.top,
                 "auxiliaryTopLeftArea": screen.auxiliaryTopLeftArea.map(rect) as Any? ?? NSNull(),
                 "auxiliaryTopRightArea": screen.auxiliaryTopRightArea.map(rect) as Any? ?? NSNull()]
         },
         "panels": panels.map { ["frame": rect($0.frame), "visible": $0.isVisible,
              "key": $0.isKeyWindow, "main": $0.isMainWindow] as [String: Any] }]
    }

    @objc private func copyDiagnostics() {
        guard let data = try? JSONSerialization.data(withJSONObject: diagnostics(), options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func runSmokeTest() {
        var samples: [[String: Any]] = []
        var passed = !screens.isEmpty
        for candidate in PanelEdge.allCases {
            edge = candidate
            reconcile()
            samples.append(diagnostics())
            // Render only our own content; this does not capture the user's desktop.
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "--snapshots"), args.indices.contains(index + 1) {
                for (displayIndex, panel) in panels.enumerated() {
                    guard let view = panel.contentView else { passed = false; continue }
                    let suffix = displayIndex == 0 ? "" : "-display-\(displayIndex + 1)"
                    view.layoutSubtreeIfNeeded()
                if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    if let data = bitmap.representation(using: .png, properties: [:]) {
                        do {
                            try data.write(to: URL(fileURLWithPath: args[index + 1])
                                .appendingPathComponent("\(candidate.rawValue)\(suffix).png"))
                        } catch {
                            passed = false
                            FileHandle.standardError.write(Data("Snapshot failed: \(error)\n".utf8))
                        }
                    } else { passed = false }
                } else { passed = false }
                }
            }
            passed = passed && panels.count == screens.count
            for (panel, screen) in zip(panels, screens) {
                passed = passed && panel.isVisible && !panel.isKeyWindow && !panel.isMainWindow
                    && availableFrame(screen).contains(panel.frame)
                    && panel.frame == panelFrame(screen)
            }
        }
        let report: [String: Any] = ["passed": passed, "samples": samples,
            "scope": "Programmatic placement and window flags only; no physical click, Spaces or fullscreen verification."]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "--report"), args.indices.contains(index + 1) {
                try data.write(to: URL(fileURLWithPath: args[index + 1]), options: .atomic)
            } else { FileHandle.standardOutput.write(data) }
        } catch {
            FileHandle.standardError.write(Data("Smoke report failed: \(error)\n".utf8))
            exit(2)
        }
        panels.forEach { $0.close() }
        exit(passed ? 0 : 1)
    }
}
