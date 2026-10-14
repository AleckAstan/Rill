import AppKit
import Darwin
import SwiftUI
import ImageIO

/// Bounded decoded artwork cache. Repeated media positions do not decode the same image again.
@MainActor
enum ExtensionImageCache {
    static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 64
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()

    static func image(at url: URL, revision: String? = nil) -> NSImage? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.intValue <= RillExtensionAPI.maximumImageBytes else { return nil }
        let key = "\(url.path)|\(revision ?? "")|\(attributes[.modificationDate] ?? "")|\(size)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 512,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        let result = NSImage(cgImage: image, size: .zero)
        cache.setObject(result, forKey: key, cost: image.bytesPerRow * image.height)
        return result
    }
}

struct ExtensionContributionKey: Hashable, Sendable {
    let extensionID: String
    let contributionID: String
}

@MainActor
final class ExtensionRuntimeStore: ObservableObject {
    @Published private(set) var presentations: [ExtensionContributionKey: RillExtensionPresentation] = [:]
    @Published private(set) var health: [String: ProviderHealth] = [:]
    @Published private(set) var diagnostics: [String: String] = [:]
    private var packageDirectories: [String: URL] = [:]
    private var actionHandlers: [String: @MainActor (String, String) -> Void] = [:]
    private var registrations: [String: UInt64] = [:]

    func register(
        extensionID: String,
        generation: UInt64,
        packageDirectory: URL,
        action: @escaping @MainActor (String, String) -> Void
    ) {
        packageDirectories[extensionID] = packageDirectory
        actionHandlers[extensionID] = action
        registrations[extensionID] = generation
        health[extensionID] = .starting
        diagnostics[extensionID] = nil
    }

    func unregister(extensionID: String, generation: UInt64, keepingPresentations: Bool = false) {
        guard registrations[extensionID] == generation else { return }
        actionHandlers[extensionID] = nil
        packageDirectories[extensionID] = nil
        registrations[extensionID] = nil
        if !keepingPresentations {
            presentations = presentations.filter { $0.key.extensionID != extensionID }
            health[extensionID] = nil
            diagnostics[extensionID] = nil
        }
    }

    func publish(
        extensionID: String,
        generation: UInt64,
        contributionID: String,
        presentation: RillExtensionPresentation
    ) throws {
        guard registrations[extensionID] == generation else { return }
        try presentation.validate(packageDirectory: packageDirectories[extensionID])
        presentations[.init(extensionID: extensionID, contributionID: contributionID)] = presentation
        health[extensionID] = .ready
        diagnostics[extensionID] = nil
    }

    func fail(extensionID: String, generation: UInt64, message: String, terminal: Bool) {
        guard registrations[extensionID] == generation else { return }
        diagnostics[extensionID] = String(message.prefix(2_048))
        health[extensionID] = terminal ? .failed : .stale
    }

    func perform(extensionID: String, contributionID: String, actionID: String) {
        actionHandlers[extensionID]?(contributionID, actionID)
    }

    func packageDirectory(for extensionID: String) -> URL {
        packageDirectories[extensionID] ?? URL(fileURLWithPath: "/", isDirectory: true)
    }
}

@MainActor
final class ExtensionHostResource: ManagedConfigurationResource, @unchecked Sendable {
    private nonisolated static let ioQueue = DispatchQueue(label: "dev.rill.extensions.io", qos: .utility, attributes: .concurrent)
    private let spec: ExtensionSpec
    private let generation: UInt64
    private let runtime: ExtensionRuntimeStore
    private let permittedContributions: Set<String>
    private var process: ManagedChildProcess?
    private var input: FileHandle?
    private var readTask: Task<Void, Never>?
    private var stderrTask: Task<Data, Never>?
    private var restartTask: Task<Void, Never>?
    private var stopping = false
    private var committed = false
    private var starts: [ContinuousClock.Instant] = []
    private var updateTimes: [ContinuousClock.Instant] = []
    private let maximumLaunches: Int
    private let restartBaseDelay: Duration

    init(
        spec: ExtensionSpec,
        generation: UInt64,
        runtime: ExtensionRuntimeStore,
        maximumLaunches: Int = 4,
        restartBaseDelay: Duration = .seconds(1)
    ) throws {
        guard let executable = spec.executable else { throw ExtensionHostError.unresolvedExecutable(spec.id) }
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw ExtensionHostError.notExecutable(executable)
        }
        self.spec = spec
        self.generation = generation
        self.runtime = runtime
        self.maximumLaunches = maximumLaunches
        self.restartBaseDelay = restartBaseDelay
        permittedContributions = Set(spec.contributions.map(\.id))
    }

    func commit() async {
        guard !committed else { return }
        committed = true
        stopping = false
        runtime.register(
            extensionID: spec.id,
            generation: generation,
            packageDirectory: URL(fileURLWithPath: spec.path, isDirectory: true),
            action: { [weak self] contributionID, actionID in
                self?.sendAction(contributionID: contributionID, actionID: actionID)
            }
        )
        start()
    }

    func stop() async {
        guard committed else { return }
        committed = false
        stopping = true
        restartTask?.cancel(); restartTask = nil
        readTask?.cancel(); readTask = nil
        let old = process
        if old?.isRunning == true { try? write(.init(kind: .shutdown, extensionID: spec.id)) }
        process = nil
        try? input?.close(); input = nil
        stderrTask?.cancel(); stderrTask = nil
        if let old { await Self.terminate(old) }
        runtime.unregister(extensionID: spec.id, generation: generation)
    }

    private func start() {
        guard !stopping, process == nil, let executable = spec.executable else { return }
        let now = ContinuousClock.now
        starts.removeAll { now - $0 > .seconds(60) }
        guard starts.count < maximumLaunches else {
            runtime.fail(extensionID: spec.id, generation: generation, message: "Stopped after \(maximumLaunches) launches in 60 seconds", terminal: true)
            return
        }
        starts.append(now)

        let child = ManagedChildProcess()
        let stdinPipe = Pipe(); let stdoutPipe = Pipe(); let stderrPipe = Pipe()
        child.executableURL = URL(fileURLWithPath: executable)
        child.arguments = spec.args
        child.currentDirectoryURL = URL(fileURLWithPath: spec.path, isDirectory: true)
        var environment = ProcessInfo.processInfo.environment
        environment["RILL_EXTENSION_ID"] = spec.id
        environment["RILL_EXTENSION_DIRECTORY"] = spec.path
        environment["RILL_EXTENSION_API_VERSION"] = "2"
        child.environment = environment
        child.standardInput = stdinPipe
        child.standardOutput = stdoutPipe
        child.standardError = stderrPipe
        do {
            try child.run()
            process = child
            input = stdinPipe.fileHandleForWriting
            // A hostile or immediately crashing child may close stdin before
            // the context write. Convert EPIPE into a Swift error instead of
            // allowing SIGPIPE to terminate the Rill host process.
            let inputFD = stdinPipe.fileHandleForWriting.fileDescriptor
            _ = fcntl(inputFD, F_SETNOSIGPIPE, 1)
            _ = fcntl(inputFD, F_SETFL, fcntl(inputFD, F_GETFL) | O_NONBLOCK)
            let context = RillExtensionHostContext(
                generation: generation,
                grantedCapabilities: spec.grant,
                appearance: spec.grant.contains(.hostAppearance)
                    ? NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])?.rawValue
                    : nil,
                displayIDs: spec.grant.contains(.hostDisplay)
                    ? ScreenInventory.descriptors().map(\.id.rawValue)
                    : nil,
                reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                settings: spec.settings
            )
            try write(.init(kind: .context, extensionID: spec.id, context: context))
            let output = stdoutPipe.fileHandleForReading
            let errors = stderrPipe.fileHandleForReading
            let errorTask = Task { await Self.drain(errors, retainingAtMost: 16_384) }
            stderrTask = errorTask
            readTask = Task.detached { [weak self] in
                await self?.readLoop(output: output, errors: errorTask, process: child)
            }
        } catch {
            Task { await Self.terminate(child) }
            try? input?.close(); input = nil
            process = nil
            runtime.fail(extensionID: spec.id, generation: generation, message: "Launch failed: \(error.localizedDescription)", terminal: false)
            scheduleRestart()
        }
    }

    private nonisolated func readLoop(output: FileHandle, errors: Task<Data, Never>, process: ManagedChildProcess) async {
        defer { try? output.close() }
        do {
            while !Task.isCancelled, let message = try await Self.readMessage(from: output) {
                try Task.checkCancellation()
                await receive(message, from: process)
            }
        } catch {
            if !Task.isCancelled { await protocolFailure(String(describing: error), from: process) }
        }
        // EOF while still running is a broken session, not evidence of process termination.
        await Self.terminate(process)
        let errorData = await errors.value
        let errorText = String(data: errorData.prefix(16_384), encoding: .utf8) ?? ""
        await ended(process: process, stderr: errorText)
    }

    private func receive(_ message: RillExtensionMessage, from child: ManagedChildProcess) {
        guard !stopping, process === child else { return }
        guard message.kind == .hello || message.kind == .update else {
            terminateForViolation("Extension may send only hello or update messages")
            return
        }
        guard message.extensionID == nil || message.extensionID == spec.id else {
            terminateForViolation("Extension attempted to impersonate '\(message.extensionID ?? "")'")
            return
        }

        let now = ContinuousClock.now
        updateTimes.removeAll { now - $0 > .seconds(1) }
        updateTimes.append(now)
        guard updateTimes.count <= 20 else {
            terminateForViolation("Update rate exceeded 20 frames per second")
            return
        }
        if message.kind == .hello { return }
        guard let contributionID = message.contributionID,
              permittedContributions.contains(contributionID),
              let presentation = message.presentation else {
            terminateForViolation("Update targets an undeclared contribution")
            return
        }
        do {
            try runtime.publish(
                extensionID: spec.id,
                generation: generation,
                contributionID: contributionID,
                presentation: presentation
            )
        }
        catch { terminateForViolation(String(describing: error)) }
    }

    private func protocolFailure(_ message: String, from child: ManagedChildProcess) {
        guard !stopping, process === child else { return }
        runtime.fail(extensionID: spec.id, generation: generation, message: "Protocol error: \(message)", terminal: false)
        if let process { Task { await Self.terminate(process) } }
    }

    private func terminateForViolation(_ message: String) {
        runtime.fail(extensionID: spec.id, generation: generation, message: message, terminal: true)
        stopping = true
        if let process { Task { await Self.terminate(process) } }
    }

    private func ended(process endedProcess: ManagedChildProcess, stderr: String) {
        guard process === endedProcess else { return }
        process = nil; try? input?.close(); input = nil; readTask = nil
        stderrTask = nil
        guard !stopping else { return }
        let detail = stderr.isEmpty ? "exit \(endedProcess.terminationStatus)" : String(stderr.prefix(2_048))
        runtime.fail(extensionID: spec.id, generation: generation, message: "Extension stopped: \(detail)", terminal: false)
        scheduleRestart()
    }

    private func scheduleRestart() {
        guard !stopping, restartTask == nil else { return }
        let multiplier = min(1 << min(starts.count - 1, 5), 30)
        let delay = restartBaseDelay * multiplier
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.restartTask = nil
            self.start()
        }
    }

    private func sendAction(contributionID: String, actionID: String) {
        guard spec.grant.contains(.actions) else {
            runtime.fail(extensionID: spec.id, generation: generation, message: "Action rejected: capability 'actions' was not granted", terminal: false)
            return
        }
        do { try write(.init(kind: .action, extensionID: spec.id, contributionID: contributionID, actionID: actionID)) }
        catch { if let process { protocolFailure("Action delivery failed: \(error)", from: process) } }
    }

    private func write(_ message: RillExtensionMessage) throws {
        guard let input else { throw ExtensionHostError.notRunning(spec.id) }
        let data = try RillExtensionFrameCodec.encode(message)
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(input.fileDescriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count > 0 { offset += count }
                else if count < 0 && errno == EINTR { continue }
                else { throw ExtensionHostError.backpressure }
            }
        }
    }

    private nonisolated static func readMessage(from handle: FileHandle) async throws -> RillExtensionMessage? {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do { continuation.resume(returning: try readMessageSynchronously(from: handle)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    private nonisolated static func readMessageSynchronously(from handle: FileHandle) throws -> RillExtensionMessage? {
        guard let header = try readExactly(4, from: handle) else { return nil }
        let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard length <= RillExtensionAPI.maximumFrameBytes else {
            throw RillExtensionProtocolError.oversizedFrame(Int(length))
        }
        guard let body = try readExactly(Int(length), from: handle) else {
            throw RillExtensionProtocolError.truncatedFrame
        }
        return try RillExtensionFrameCodec.decode(header + body)
    }

    private nonisolated static func terminate(_ child: ManagedChildProcess) async {
        if child.isRunning {
            child.terminate()
            for _ in 0..<25 where child.isRunning {
                try? await Task.sleep(for: .milliseconds(10))
            }
            child.forceTerminate()
        }
        await child.waitForExit()
    }

    private nonisolated static func readExactly(_ count: Int, from handle: FileHandle) throws -> Data? {
        var result = Data()
        while result.count < count {
            var descriptor = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, 100)
            if ready == 0 || (ready < 0 && errno == EINTR) { continue }
            guard ready > 0 else { throw POSIXError(.EIO) }
            let part = try handle.read(upToCount: min(4096, count - result.count)) ?? Data()
            if part.isEmpty {
                if result.isEmpty { return nil }
                throw RillExtensionProtocolError.truncatedFrame
            }
            result.append(part)
        }
        return result
    }

    private nonisolated static func drain(_ handle: FileHandle, retainingAtMost limit: Int) async -> Data {
        await withCheckedContinuation { continuation in
            ioQueue.async { continuation.resume(returning: drainSynchronously(handle, retainingAtMost: limit)) }
        }
    }

    private nonisolated static func drainSynchronously(_ handle: FileHandle, retainingAtMost limit: Int) -> Data {
        defer { try? handle.close() }
        var retained = Data()
        while true {
            var descriptor = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, 100)
            if ready == 0 || (ready < 0 && errno == EINTR) { continue }
            guard ready > 0 else { break }
            let chunk: Data
            do { chunk = try handle.read(upToCount: 4096) ?? Data() }
            catch { break }
            guard !chunk.isEmpty else { break }
            if retained.count < limit { retained.append(chunk.prefix(limit - retained.count)) }
        }
        return retained
    }

}

enum ExtensionHostError: Error, CustomStringConvertible {
    case unresolvedExecutable(String), notExecutable(String), notRunning(String), backpressure
    var description: String {
        switch self {
        case .unresolvedExecutable(let id): return "Extension '\(id)' has no resolved executable"
        case .notExecutable(let path): return "Extension executable is not executable: \(path)"
        case .backpressure: return "Extension is not reading host messages; session closed"
        case .notRunning(let id): return "Extension '\(id)' is not running"
        }
    }
}

struct ExtensionContributionView: View {
    let extensionID: String
    let contributionID: String
    let expanded: Bool
    @ObservedObject var runtime: ExtensionRuntimeStore

    var body: some View {
        let key = ExtensionContributionKey(extensionID: extensionID, contributionID: contributionID)
        if let presentation = runtime.presentations[key] {
            ExtensionNodeView(
                node: expanded ? presentation.expanded ?? presentation.compact : presentation.compact,
                expanded: expanded,
                packageDirectory: runtime.packageDirectory(for: extensionID),
                action: { runtime.perform(extensionID: extensionID, contributionID: contributionID, actionID: $0) }
            )
        } else {
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text(runtime.diagnostics[extensionID] ?? "Extension unavailable").lineLimit(1)
            }
            .accessibilityLabel("Extension \(extensionID) unavailable")
        }
    }

}

private struct ExtensionNodeView: View {
    let node: RillExtensionNode
    var expanded = false
    let packageDirectory: URL
    let action: (String) -> Void
    @State private var popover = false

    @ViewBuilder var body: some View {
        switch node.kind {
        case .hStack, .vStack, .list, .spacer, .divider, .nowPlaying, .wallpaper:
            rendered
        default:
            rendered.accessibilityLabel(node.label ?? defaultLabel)
        }
    }

    private var rendered: AnyView {
        switch node.kind {
        case .text:
            return AnyView(Text(node.text ?? "").lineLimit(1).truncationMode(.tail))
        case .symbol:
            return AnyView(Image(systemName: node.name ?? "questionmark"))
        case .image:
            let url = packageDirectory.appendingPathComponent(node.resource ?? "")
            if let image = ExtensionImageCache.image(at: url) {
                return AnyView(Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: 64, maxHeight: 64))
            }
            return AnyView(Image(systemName: "photo.badge.exclamationmark"))
        case .hStack:
            return AnyView(HStack(spacing: 6) { children })
        case .vStack, .list:
            return AnyView(VStack(alignment: .leading, spacing: 6) { children })
        case .spacer:
            return AnyView(Spacer(minLength: 4))
        case .divider:
            return AnyView(Divider())
        case .progress:
            return AnyView(ProgressView(value: node.value ?? 0).frame(maxWidth: 120))
        case .button:
            return AnyView(
                Button { if let id = node.actionID { action(id) } } label: {
                    HStack(spacing: 4) { children }
                }
                .buttonStyle(.plain).focusable().focusEffectDisabled()
            )
        case .popover:
            return AnyView(
                Button { popover.toggle() } label: {
                    child(at: 0)
                }
                .buttonStyle(.plain).focusable().focusEffectDisabled()
                .popover(isPresented: $popover) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(node.children.dropFirst().enumerated()), id: \.offset) { _, child in
                            ExtensionNodeView(node: child, packageDirectory: packageDirectory, action: action)
                        }
                    }.padding(14).frame(maxWidth: 420)
                }
            )
        case .nowPlaying:
            return AnyView(NowPlayingView(media: node.media!, expanded: expanded,
                packageDirectory: packageDirectory, action: action))
        case .wallpaper:
            if let wallpaper = node.wallpaper {
                return AnyView(WallpaperPreviewView(content: wallpaper, packageDirectory: packageDirectory, action: action))
            }
            return AnyView(Text("Wallpaper unavailable"))
        case .metric:
            if let metric = node.metric {
                return AnyView(MetricGaugeView(metric: metric, packageDirectory: packageDirectory))
            }
            return AnyView(Text("Metric unavailable"))
        }
    }

    private var children: some View {
        ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
            ExtensionNodeView(node: child, packageDirectory: packageDirectory, action: action)
        }
    }

    @ViewBuilder private func child(at index: Int) -> some View {
        if node.children.indices.contains(index) {
            ExtensionNodeView(node: node.children[index], packageDirectory: packageDirectory, action: action)
        } else { Text(node.label ?? "Details") }
    }

    private var defaultLabel: String {
        node.text ?? node.name ?? node.kind.rawValue
    }
}

/// A host-owned media presentation. Extensions supply data and opaque action IDs only.
private struct NowPlayingView: View {
    let media: RillNowPlayingContent
    let expanded: Bool
    let packageDirectory: URL
    let action: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var artworkMotion

    var body: some View {
        Group {
            if expanded {
                expandedContent.transition(.opacity)
            } else {
                compactContent.transition(.opacity)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compactContent: some View {
        HStack(spacing: 0) {
            artwork(size: 24)
                .matchedGeometryEffect(id: "artwork", in: artworkMotion)
                .frame(width: 36, alignment: .center)
            Spacer(minLength: 0)
            activityWave
                .frame(width: 36, alignment: .center)
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now playing: \(media.title), \(media.artist)")
        .accessibilityValue(media.isPlaying ? "Playing" : "Paused")
    }

    private var expandedContent: some View {
        VStack(spacing: 9) {
            HStack(alignment: .center, spacing: 13) {
                artwork(size: 68)
                    .matchedGeometryEffect(id: "artwork", in: artworkMotion)
                VStack(alignment: .leading, spacing: 3) {
                    Text(media.source?.uppercased() ?? "NOW PLAYING")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                    Text(media.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .accessibilityLabel("Title: \(media.title)")
                    Text(media.artist.isEmpty ? "Unknown artist" : media.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                        .accessibilityLabel("Artist: \(media.artist)")
                    if let album = media.album, !album.isEmpty {
                        Text(album).font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.38)).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 12)
            }
            progressTrack
            HStack {
                activityWave.opacity(0.7)
                Spacer()
                playbackButton("backward.end.fill", label: "Previous track", id: media.previousActionID, size: 15)
                playbackButton(media.isPlaying ? "pause.fill" : "play.fill",
                    label: media.isPlaying ? "Pause" : "Play", id: media.toggleActionID, size: 18)
                    .frame(width: 31, height: 31)
                    .background(.white.opacity(0.15), in: Circle())
                playbackButton("forward.end.fill", label: "Next track", id: media.nextActionID, size: 15)
                Spacer()
                Text(media.source ?? "").font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                    .frame(width: 50, alignment: .trailing)
            }
            .frame(height: 31)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private func artwork(size: CGFloat) -> some View {
        let path = media.artworkResource.map { packageDirectory.appendingPathComponent($0) }
        if let path, let image = ExtensionImageCache.image(at: path, revision: media.artworkRevision) {
            Image(nsImage: image).resizable().scaledToFill()
                .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.18))
                .id(media.artworkRevision)
                .accessibilityLabel("Album artwork")
        } else {
            Image(systemName: "music.note")
                .font(.system(size: size * 0.42, weight: .medium))
                .frame(width: size, height: size)
                .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: size * 0.18))
                .accessibilityLabel("Music artwork placeholder")
        }
    }

    private var activityWave: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !media.isPlaying || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(media.isPlaying ? 0.78 : 0.32))
                        .frame(width: 2.5, height: waveHeight(index: index, time: time))
                }
            }
            .frame(height: 22)
        }
        .accessibilityLabel(media.isPlaying ? "Playback activity" : "Playback paused")
    }

    private func waveHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard media.isPlaying, !reduceMotion else { return CGFloat([6, 12, 17, 10, 5][index]) }
        let motion = abs(sin(time * 3.1 + Double(index) * 1.3))
        return 4 + CGFloat(motion) * CGFloat([10, 17, 13, 18, 9][index])
    }

    private var progressTrack: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = media.isPlaying && media.updatedAt > 0
                ? max(0, timeline.date.timeIntervalSince1970 - media.updatedAt) : 0
            let current = min(media.duration, max(0, media.position + elapsed))
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    Capsule().fill(.white.opacity(0.18))
                        .overlay(alignment: .leading) {
                            Capsule().fill(.white).frame(width: geometry.size.width * (media.duration > 0 ? current / media.duration : 0))
                        }
                }
                .frame(height: 3)
                HStack {
                    Text(timeLabel(current))
                    Spacer()
                    Text(timeLabel(media.duration))
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback progress")
            .accessibilityValue("\(timeLabel(current)) of \(timeLabel(media.duration))")
        }
    }

    private func timeLabel(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let value = Int(seconds)
        return "\(value / 60):\(String(format: "%02d", value % 60))"
    }

    private func playbackButton(_ symbol: String, label: String, id: String?, size: CGFloat) -> some View {
        Button { if let id { action(id) } } label: {
            Image(systemName: symbol).font(.system(size: size, weight: .semibold))
                .frame(width: 32, height: 30)
        }
        .buttonStyle(NotchPlaybackButtonStyle()).focusable().focusEffectDisabled()
        .help(label)
        .disabled(id == nil)
        .accessibilityLabel(label)
    }
}

/// Subtle feedback without changing a control's hit target.
private struct NotchPlaybackButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.16), value: configuration.isPressed)
    }
}

enum NotchWidgetState: String, Sendable { case compact, expanded, dismissed }

/// The top corners turn out toward the menu bar; the bottom corners turn in.
/// One animatable outline keeps the attachment flush during expansion.
struct NotchSurfaceShape: Shape {
    var shoulder: CGFloat
    var radius: CGFloat
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulder, radius) }
        set { shoulder = newValue.first; radius = newValue.second }
    }
    func path(in rect: CGRect) -> Path {
        let s = min(shoulder, rect.height / 2)
        let r = min(radius, (rect.width - 2 * s) / 2, rect.height - s)
        let left = rect.minX, right = rect.maxX, top = rect.minY, bottom = rect.maxY
        var p = Path()
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: right, y: top))
        p.addQuadCurve(to: CGPoint(x: right - s, y: top + s), control: CGPoint(x: right - s, y: top))
        p.addLine(to: CGPoint(x: right - s, y: bottom - r))
        p.addQuadCurve(to: CGPoint(x: right - s - r, y: bottom), control: CGPoint(x: right - s, y: bottom))
        p.addLine(to: CGPoint(x: left + s + r, y: bottom))
        p.addQuadCurve(to: CGPoint(x: left + s, y: bottom - r), control: CGPoint(x: left + s, y: bottom))
        p.addLine(to: CGPoint(x: left + s, y: top + s))
        p.addQuadCurve(to: CGPoint(x: left, y: top), control: CGPoint(x: left + s, y: top))
        p.closeSubpath()
        return p
    }
}

@MainActor
private final class NotchWidgetViewState: ObservableObject {
    @Published var expanded = false
    var hovering = false
    var pendingHover: Task<Void, Never>?
    let compact: CGRect
    let open: CGRect
    let safeTop: CGFloat

    init(compact: CGRect, open: CGRect, safeTop: CGFloat) {
        self.compact = compact; self.open = open; self.safeTop = safeTop
    }

    func expand(_ value: Bool) {
        let animation: Animation? = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil :
            .smooth(duration: value ? 0.40 : 0.32)
        withAnimation(animation) { expanded = value }
    }
}

private struct NotchMotionValues {
    var left: CGFloat = 0
    var right: CGFloat = 0
    var height: CGFloat = 0
}

enum NotchWidgetGeometry {
    static func compactHeight(safeTopInset: CGFloat) -> CGFloat {
        safeTopInset > 0 ? safeTopInset : 36
    }

    /// Evaluate every animation sample: contraction must never uncover the cutout.
    static func animatedFrame(compact: CGSize, open: CGSize, left: CGFloat, right: CGFloat, height: CGFloat) -> CGRect {
        let wing = max(0, open.width - compact.width) / 2
        let leading = wing * left
        let trailing = wing * right
        return CGRect(x: -compact.width / 2 - leading, y: 0,
                      width: max(1, compact.width + leading + trailing),
                      height: max(compact.height, compact.height + (open.height - compact.height) * height))
    }

    static func frame(
        screen: CGRect,
        safeTopInset: CGFloat,
        spec: NotchWidgetSpec,
        state: NotchWidgetState,
        cutout: CGRect? = nil
    ) -> CGRect {
        let hasCutout = safeTopInset > 0 && cutout != nil
        let compactHeight = compactHeight(safeTopInset: safeTopInset)
        // Reserve two equal 44-point wings outside the physical cutout plus shoulders.
        let compactWidth = hasCutout ? cutout!.width + 104 : spec.compactWidth
        let width = min(screen.width, state == .expanded ? max(spec.expandedWidth, compactWidth) : compactWidth)
        let height = state == .expanded
            ? min(screen.height, spec.expandedHeight + (spec.backgroundStyle == .black ? safeTopInset : 0))
            : compactHeight
        let center = hasCutout ? cutout!.midX : screen.midX
        let x = min(max(screen.minX, center - width / 2), screen.maxX - width)
        return CGRect(x: x, y: screen.maxY - height, width: width, height: height)
    }

    static func cutout(screen: CGRect, safeTopInset: CGFloat, left: CGRect?, right: CGRect?) -> CGRect? {
        guard safeTopInset > 0, let left, let right,
              left.maxX < right.minX, left.maxX >= screen.minX, right.minX <= screen.maxX else { return nil }
        return CGRect(x: left.maxX, y: screen.maxY - safeTopInset,
                      width: right.minX - left.maxX, height: safeTopInset)
    }
}

@MainActor
final class NotchWidgetResource: NSObject, ManagedConfigurationResource, @unchecked Sendable {
    private let spec: NotchWidgetSpec
    private let configuration: AppConfiguration
    private let runtime: ExtensionRuntimeStore
    private var panels: [(panel: RillPanel, state: NotchWidgetViewState)] = []
    private var committed = false
    private var dismissed = false
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    init(id: String, configuration: AppConfiguration, runtime: ExtensionRuntimeStore) throws {
        guard let spec = configuration.notchWidgets.first(where: { $0.id == id }) else {
            throw ExtensionHostError.notRunning(id)
        }
        self.spec = spec; self.configuration = configuration; self.runtime = runtime
        super.init()
        makePanels()
    }

    func commit() async {
        guard !committed else { return }; committed = true
        NotificationCenter.default.addObserver(self, selector: #selector(reconcile), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        // Monitor only pointer movement. No accessibility/input-monitoring permission is needed.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.trackPointer() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            MainActor.assumeIsolated { self?.trackPointer() }
            return event
        }
        panels.forEach { $0.panel.orderFrontRegardless() }
        trackPointer()
    }

    func stop() async {
        NotificationCenter.default.removeObserver(self)
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil; localMouseMonitor = nil
        closePanels(); committed = false
    }

    private func closePanels() {
        panels.forEach { $0.state.pendingHover?.cancel(); $0.panel.close() }
        panels = []
    }

    @objc private func reconcile() {
        closePanels(); makePanels()
        if committed { panels.forEach { $0.panel.orderFrontRegardless() }; trackPointer() }
    }

    private func trackPointer() {
        let mouse = NSEvent.mouseLocation
        for (panel, state) in panels {
            let frame = state.expanded ? state.open : state.compact
            let local = CGPoint(x: mouse.x - frame.minX, y: frame.maxY - mouse.y)
            let outline = NotchSurfaceShape(shoulder: state.expanded ? 12 : 6, radius: state.expanded ? 28 : 12)
            let inside = outline.path(in: CGRect(origin: .zero, size: frame.size)).contains(local)
            // The stable animation canvas must never intercept clicks on the desktop around it.
            panel.ignoresMouseEvents = !inside
            guard inside != state.hovering else { continue }
            state.hovering = inside
            state.pendingHover?.cancel()
            state.pendingHover = Task { @MainActor [weak self, weak state] in
                try? await Task.sleep(for: .milliseconds(inside ? 100 : 260))
                guard !Task.isCancelled, let self, let state else { return }
                state.expand(inside)
                self.trackPointer()
            }
        }
    }

    private func makePanels() {
        guard !dismissed, isCollisionWinner else { return }
        panels = ScreenInventory.screens(for: spec.display).map { screen, displayID in
            let safeTop = screen.safeAreaInsets.top
            let cutout = NotchWidgetGeometry.cutout(screen: screen.frame, safeTopInset: safeTop,
                left: screen.auxiliaryTopLeftArea, right: screen.auxiliaryTopRightArea)
            let compact = NotchWidgetGeometry.frame(screen: screen.frame, safeTopInset: safeTop, spec: spec, state: .compact, cutout: cutout)
            let open = NotchWidgetGeometry.frame(screen: screen.frame, safeTopInset: safeTop, spec: spec, state: .expanded, cutout: cutout)
            let state = NotchWidgetViewState(compact: compact, open: open, safeTop: safeTop)
            // AppKit stays still; SwiftUI owns the entire interruptible shape/content spring.
            // Leave room for spring overshoot and shadow even at large configured sizes.
            let sideRoom = 16 + max(0, open.width - compact.width) * 0.04
            let bottomRoom = 20 + max(0, open.height - compact.height) * 0.08
            let canvas = CGRect(x: open.minX - sideRoom, y: open.minY - bottomRoom,
                                width: open.width + sideRoom * 2, height: open.height + bottomRoom)
            let panel = RillPanel(surfaceID: SurfaceID("notch.\(spec.id)"), displayID: displayID, frame: canvas)
            panel.usesMenuBarArea = true
            panel.acceptsMouseMovedEvents = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.isMovable = false; panel.isReleasedWhenClosed = false
            panel.contentView = NotchHostingView(rootView: NotchWidgetRootView(
                spec: spec, viewState: state, runtime: runtime,
                dismiss: { [weak self] in self?.dismissed = true; self?.closePanels() }))
            return (panel, state)
        }
    }

    private var isCollisionWinner: Bool {
        !configuration.notchWidgets.contains {
            $0.id != spec.id && $0.display.mayResolveSameDisplay(as: spec.display) && $0.priority > spec.priority
        }
    }
}

@MainActor
private final class NotchHostingView: NSHostingView<NotchWidgetRootView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
}

private struct NotchWidgetRootView: View {
    let spec: NotchWidgetSpec
    @ObservedObject var viewState: NotchWidgetViewState
    @ObservedObject var runtime: ExtensionRuntimeStore
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var expanded: Bool { viewState.expanded }
    private var isNowPlaying: Bool {
        let key = ExtensionContributionKey(extensionID: spec.extensionID, contributionID: spec.contribution)
        return runtime.presentations[key]?.compact.kind == .nowPlaying
    }

    var body: some View {
        KeyframeAnimator(initialValue: NotchMotionValues(), trigger: expanded) { motion in
            let target: CGFloat = expanded ? 1 : 0
            let frame = NotchWidgetGeometry.animatedFrame(
                compact: viewState.compact.size, open: viewState.open.size,
                left: reduceMotion ? target : motion.left,
                right: reduceMotion ? target : motion.right,
                height: reduceMotion ? target : motion.height)
            let rounding = min(1, max(0, reduceMotion ? target : motion.height))
            let shape = NotchSurfaceShape(shoulder: 6 + 6 * rounding, radius: 12 + 16 * rounding)
            surface(shape: shape, size: frame.size)
                .contentShape(shape)
                .shadow(color: .black.opacity(0.3 * rounding), radius: 8, y: 5)
                .offset(x: frame.midX)
        } keyframes: { _ in
            // Different side responses give a slight elastic follow-through, not a mirrored pulse.
            KeyframeTrack(\.left) {
                SpringKeyframe(expanded ? 1 : 0, duration: 0.52,
                    spring: .init(response: expanded ? 0.43 : 0.38, dampingRatio: 0.73))
            }
            KeyframeTrack(\.right) {
                SpringKeyframe(expanded ? 1 : 0, duration: 0.60,
                    spring: .init(response: expanded ? 0.51 : 0.46, dampingRatio: 0.78))
            }
            KeyframeTrack(\.height) {
                if expanded {
                    SpringKeyframe(1, duration: 0.52, spring: .init(response: 0.46, dampingRatio: 0.78))
                } else {
                    CubicKeyframe(0, duration: 0.40)
                }
            }
        }
            .onTapGesture { if !expanded { viewState.expand(true) } }
            .accessibilityAction(named: expanded ? "Collapse notch widget" : "Expand notch widget") {
                viewState.expand(!expanded)
            }
            .accessibilityAction(named: "Dismiss notch widget", dismiss)
            .onExitCommand { viewState.expand(false) }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private func surface(shape: NotchSurfaceShape, size: CGSize) -> some View {
        if spec.backgroundStyle == .black {
            content.frame(width: size.width, height: size.height, alignment: .top)
                .background(.black, in: shape).clipShape(shape).foregroundStyle(.white)
        } else if #available(macOS 26.0, *) {
            content.frame(width: size.width, height: size.height, alignment: .top)
                .glassEffect(.regular, in: shape)
        } else {
            content.frame(width: size.width, height: size.height, alignment: .top)
                .background(.regularMaterial, in: shape).clipShape(shape)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if expanded && spec.backgroundStyle == .black {
                Color.clear.frame(height: viewState.safeTop).accessibilityHidden(true)
            }
            HStack(spacing: 8) {
                ExtensionContributionView(extensionID: spec.extensionID, contributionID: spec.contribution,
                    expanded: expanded, runtime: runtime)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if expanded && !isNowPlaying {
                    Button { viewState.expand(false) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.plain).accessibilityLabel("Collapse notch widget")
                    Button(action: dismiss) { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss notch widget")
                }
            }
            .padding(.horizontal, isNowPlaying ? 6 : (expanded ? 20 : 12))
            .padding(.vertical, isNowPlaying ? 0 : (expanded ? 10 : 3))
        }
    }
}
