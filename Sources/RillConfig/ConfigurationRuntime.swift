import Foundation
import Darwin
import TOMLDecoder

public enum ConfigurationSource: Sendable, Equatable {
    case bundledDefault
    case file(URL)

    public var directoryURL: URL? {
        guard case .file(let url) = self else { return nil }
        return url.deletingLastPathComponent()
    }

    public var fileURL: URL? {
        guard case .file(let url) = self else { return nil }
        return url
    }
}

public struct ConfigurationResolution: Sendable, Equatable {
    public let source: ConfigurationSource
    public let wasExplicit: Bool

    public init(source: ConfigurationSource, wasExplicit: Bool) {
        self.source = source
        self.wasExplicit = wasExplicit
    }
}

public enum ConfigurationResolutionError: Error, CustomStringConvertible, Sendable {
    case missingExplicitFile(URL)

    public var description: String {
        switch self {
        case .missingExplicitFile(let url):
            return "config: explicit file does not exist: \(url.path)"
        }
    }
}

public struct ConfigurationResolver: Sendable {
    public let environment: [String: String]
    public let workingDirectory: URL
    public let homeDirectory: URL

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.environment = environment
        self.workingDirectory = workingDirectory.standardizedFileURL
        self.homeDirectory = homeDirectory.standardizedFileURL
    }

    public func resolve(explicitPath: String? = nil) throws -> ConfigurationResolution {
        if let explicitPath {
            let expanded = URL(fileURLWithPath: explicitPath, relativeTo: workingDirectory).standardizedFileURL
            guard FileManager.default.fileExists(atPath: expanded.path) else {
                throw ConfigurationResolutionError.missingExplicitFile(expanded)
            }
            return .init(source: .file(expanded), wasExplicit: true)
        }

        let defaultURL = defaultConfigurationURL
        if FileManager.default.fileExists(atPath: defaultURL.path) {
            return .init(source: .file(defaultURL), wasExplicit: false)
        }
        return .init(source: .bundledDefault, wasExplicit: false)
    }

    public var defaultConfigurationURL: URL {
        if let xdg = environment["XDG_CONFIG_HOME"], NSString(string: xdg).isAbsolutePath {
            return URL(fileURLWithPath: xdg, isDirectory: true)
                .appendingPathComponent("rill", isDirectory: true)
                .appendingPathComponent("config.toml")
                .standardizedFileURL
        }
        return homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("rill", isDirectory: true)
            .appendingPathComponent("config.toml")
            .standardizedFileURL
    }
}

public struct ConfigurationLoadError: Error, CustomStringConvertible, Sendable {
    public let diagnostics: [ValidationDiagnostic]

    public init(_ diagnostics: [ValidationDiagnostic]) {
        self.diagnostics = diagnostics
    }

    public var description: String {
        diagnostics.map(\.description).joined(separator: "\n")
    }
}

public struct ConfigurationSnapshot: Sendable, Equatable {
    public let generation: UInt64
    public let configuration: AppConfiguration
    public let source: ConfigurationSource

    public init(generation: UInt64, configuration: AppConfiguration, source: ConfigurationSource) {
        self.generation = generation
        self.configuration = configuration
        self.source = source
    }
}

public struct ConfigurationParser: Sendable {
    public static let maximumFileBytes = 1_048_576
    public init() {}

    private func readText(_ url: URL) throws -> String {
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
            throw ConfigurationLoadError([.init(path: "config", message: "Configuration and manifests must be regular files")])
        }
        let data = try handle.read(upToCount: Self.maximumFileBytes + 1) ?? Data()
        guard data.count <= Self.maximumFileBytes else {
            throw ConfigurationLoadError([.init(path: "config", message: "File exceeds the 1 MiB limit")])
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ConfigurationLoadError([.init(path: "config", message: "File must be UTF-8")])
        }
        return text
    }

    public func load(_ resolution: ConfigurationResolution, generation: UInt64 = 0) throws -> ConfigurationSnapshot {
        switch resolution.source {
        case .bundledDefault:
            return try parse(
                text: DefaultConfiguration.contents,
                source: .bundledDefault,
                generation: generation
            )
        case .file(let url):
            let text: String
            do { text = try readText(url) }
            catch let error as ConfigurationLoadError { throw error }
            catch {
                throw ConfigurationLoadError([
                    .init(path: "config", message: "Cannot read \(url.path): \(error.localizedDescription)")
                ])
            }
            return try parse(text: text, source: .file(url), generation: generation)
        }
    }

    public func parse(
        text: String,
        source: ConfigurationSource = .bundledDefault,
        generation: UInt64 = 0
    ) throws -> ConfigurationSnapshot {
        guard text.utf8.count <= Self.maximumFileBytes else {
            throw ConfigurationLoadError([.init(path: "config", message: "Configuration exceeds the 1 MiB limit")])
        }
        let decoded: AppConfiguration
        do {
            decoded = try TOMLDecoder().decode(AppConfiguration.self, from: text)
        } catch {
            throw ConfigurationLoadError([diagnostic(for: error)])
        }

        let relative = resolveRelativePaths(in: decoded, source: source)
        let resolved = try resolveExtensions(in: resolvePlugins(in: relative, source: source), source: source)
        let diagnostics = resolved.validate()
        guard diagnostics.isEmpty else {
            throw ConfigurationLoadError(diagnostics)
        }

        return ConfigurationSnapshot(
            generation: generation,
            configuration: resolved,
            source: source
        )
    }

    private func diagnostic(for error: Error) -> ValidationDiagnostic {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .dataCorrupted(let context):
                return .init(path: path(context.codingPath), message: context.debugDescription)
            case .keyNotFound(let key, let context):
                return .init(path: path(context.codingPath + [key]), message: "Missing required key")
            case .typeMismatch(let type, let context):
                return .init(path: path(context.codingPath), message: "Expected \(type): \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                return .init(path: path(context.codingPath), message: "Missing \(type): \(context.debugDescription)")
            @unknown default:
                break
            }
        }
        return .init(path: "config", message: String(describing: error))
    }

    private func path(_ codingPath: [any CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "config" }
        var result = ""
        for key in codingPath {
            if let index = key.intValue {
                result += "[\(index)]"
            } else {
                if !result.isEmpty { result += "." }
                result += key.stringValue
            }
        }
        return result
    }

    private func resolveRelativePaths(
        in configuration: AppConfiguration,
        source: ConfigurationSource
    ) -> AppConfiguration {
        guard let baseURL = source.directoryURL else { return configuration }
        var result = configuration
        for index in result.providers.indices {
            if let executable = result.providers[index].executable {
                result.providers[index].executable = resolve(executable, relativeTo: baseURL)
            }
        }
        for index in result.modules.indices {
            let actionPaths: [WritableKeyPath<ModuleSpec, ActionSpec?>] = [
                \.onClick, \.onRightClick, \.onMiddleClick, \.onScrollUp, \.onScrollDown
            ]
            for keyPath in actionPaths {
                if let executable = result.modules[index][keyPath: keyPath]?.executable {
                    result.modules[index][keyPath: keyPath]?.executable = resolve(executable, relativeTo: baseURL)
                }
            }
        }
        for index in result.plugins.indices {
            result.plugins[index].path = resolve(result.plugins[index].path, relativeTo: baseURL)
        }
        for index in result.extensions.indices {
            result.extensions[index].path = resolve(result.extensions[index].path, relativeTo: baseURL)
        }
        return result
    }

    private func resolveExtensions(
        in configuration: AppConfiguration,
        source: ConfigurationSource
    ) throws -> AppConfiguration {
        guard !configuration.extensions.isEmpty else { return configuration }
        var result = configuration
        for index in result.extensions.indices {
            let package = URL(fileURLWithPath: result.extensions[index].path, isDirectory: true).standardizedFileURL
            let field = "extensions[\(index)].path"
            try validateTrustedExtensionItem(package, field: field, requiresExecutable: false)
            let manifestURL = package.appendingPathComponent("extension.toml")
            try validateTrustedExtensionItem(manifestURL, field: field, requiresExecutable: false)
            let text: String
            do { text = try readText(manifestURL) }
            catch { throw ConfigurationLoadError([.init(path: field, message: "Cannot read extension manifest at \(manifestURL.path): \(error.localizedDescription)")]) }
            let file: ExtensionManifestFile
            do { file = try TOMLDecoder().decode(ExtensionManifestFile.self, from: text) }
            catch { throw ConfigurationLoadError([.init(path: field, message: "Invalid extension manifest at \(manifestURL.path): \(error)")]) }
            let manifest = file.extension
            guard manifest.apiVersion == RillExtensionAPI.version else {
                throw ConfigurationLoadError([.init(path: field, message: "Extension '\(result.extensions[index].id)' uses unsupported API version \(manifest.apiVersion); expected \(RillExtensionAPI.version)")])
            }
            guard manifest.id == result.extensions[index].id else {
                throw ConfigurationLoadError([.init(path: field, message: "Extension manifest ID '\(manifest.id)' does not match configured ID '\(result.extensions[index].id)'")])
            }
            let executable = URL(fileURLWithPath: resolve(manifest.executable, relativeTo: package))
            try validateTrustedExtensionItem(executable, field: field, requiresExecutable: true)
            result.extensions[index].name = manifest.name
            result.extensions[index].executable = executable.path
            result.extensions[index].args = manifest.args
            result.extensions[index].requestedCapabilities = manifest.requestedCapabilities
            result.extensions[index].contributions = manifest.contributions
        }
        return result
    }

    private func validateTrustedExtensionItem(
        _ url: URL,
        field: String,
        requiresExecutable: Bool
    ) throws {
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) }
        catch { throw ConfigurationLoadError([.init(path: field, message: "Missing extension item \(url.path)")]) }
        if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
            throw ConfigurationLoadError([.init(path: field, message: "Extension package, manifest and executable must not be symbolic links: \(url.path)")])
        }
        if let owner = attributes[.ownerAccountID] as? NSNumber, owner.uint32Value != getuid() {
            throw ConfigurationLoadError([.init(path: field, message: "Extension item is not owned by the current user: \(url.path)")])
        }
        if let permissions = attributes[.posixPermissions] as? NSNumber, permissions.intValue & 0o022 != 0 {
            throw ConfigurationLoadError([.init(path: field, message: "Extension item is group/other writable: \(url.path)")])
        }
        if requiresExecutable && !FileManager.default.isExecutableFile(atPath: url.path) {
            throw ConfigurationLoadError([.init(path: field, message: "Extension executable is not executable: \(url.path)")])
        }
    }

    private func resolvePlugins(
        in configuration: AppConfiguration,
        source: ConfigurationSource
    ) throws -> AppConfiguration {
        guard !configuration.plugins.isEmpty else { return configuration }
        var result = configuration
        var plugins: [String: String] = [:]
        for (index, plugin) in result.plugins.enumerated() {
            guard plugins.updateValue(plugin.path, forKey: plugin.id) == nil else {
                throw ConfigurationLoadError([.init(path: "plugins[\(index)].id", message: "Duplicate ID '\(plugin.id)'")])
            }
        }
        for index in result.providers.indices where result.providers[index].kind == .plugin {
            let provider = result.providers[index]
            guard let pluginID = provider.plugin, let packagePath = plugins[pluginID] else { continue }
            let packageURL = URL(fileURLWithPath: packagePath, isDirectory: true)
            let manifestURL = packageURL.appendingPathComponent("plugin.toml", isDirectory: false)
            let text: String
            do { text = try readText(manifestURL) }
            catch {
                throw ConfigurationLoadError([.init(
                    path: "providers[\(index)].plugin",
                    message: "Cannot read plugin manifest at \(manifestURL.path): \(error.localizedDescription)"
                )])
            }
            let manifest: PluginManifestFile
            do { manifest = try TOMLDecoder().decode(PluginManifestFile.self, from: text) }
            catch {
                throw ConfigurationLoadError([.init(
                    path: "providers[\(index)].plugin",
                    message: "Invalid plugin manifest at \(manifestURL.path): \(error)"
                )])
            }
            guard manifest.plugin.apiVersion == 1 else {
                throw ConfigurationLoadError([.init(path: "providers[\(index)].plugin", message: "Plugin '\(pluginID)' uses unsupported API version \(manifest.plugin.apiVersion); expected 1")])
            }
            guard manifest.plugin.id == pluginID else {
                throw ConfigurationLoadError([.init(path: "providers[\(index)].plugin", message: "Plugin manifest ID '\(manifest.plugin.id)' does not match configured ID '\(pluginID)'")])
            }
            guard !manifest.plugin.executable.isEmpty else {
                throw ConfigurationLoadError([.init(path: "providers[\(index)].plugin", message: "Plugin '\(pluginID)' has an empty executable")])
            }
            result.providers[index].executable = resolve(manifest.plugin.executable, relativeTo: packageURL)
            result.providers[index].args = manifest.plugin.args
            result.providers[index].environment = manifest.plugin.environment.merging(provider.environment) { _, configured in configured }
            result.providers[index].environment["RILL_PLUGIN_ID"] = pluginID
            result.providers[index].environment["RILL_PLUGIN_DIRECTORY"] = packageURL.path
            result.providers[index].environment["RILL_PLUGIN_API_VERSION"] = "1"
        }
        return result
    }

    private func resolve(_ path: String, relativeTo directory: URL) -> String {
        if path.hasPrefix("/") { return URL(fileURLWithPath: path).standardizedFileURL.path }
        return URL(fileURLWithPath: path, relativeTo: directory).standardizedFileURL.path
    }
}

private struct PluginManifestFile: Decodable {
    let plugin: PluginManifest
    enum CodingKeys: String, CodingKey, CaseIterable { case plugin }
    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        plugin = try container.decode(PluginManifest.self, forKey: .plugin)
    }
}

private struct ExtensionManifestFile: Decodable {
    let `extension`: ExtensionManifest

    enum CodingKeys: String, CodingKey, CaseIterable { case `extension` }

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        `extension` = try container.decode(ExtensionManifest.self, forKey: .extension)
    }
}

private struct ExtensionManifest: Decodable {
    let apiVersion: Int
    let id: String
    let name: String
    let executable: String
    let args: [String]
    let requestedCapabilities: [RillExtensionCapability]
    let contributions: [ExtensionContributionSpec]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case apiVersion = "api_version"
        case id, name, executable, args, contributions
        case requestedCapabilities = "requested_capabilities"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        apiVersion = try container.decode(Int.self, forKey: .apiVersion)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        executable = try container.decode(String.self, forKey: .executable)
        args = try container.decodeIfPresent([String].self, forKey: .args) ?? []
        requestedCapabilities = try container.decodeIfPresent([RillExtensionCapability].self, forKey: .requestedCapabilities) ?? []
        contributions = try container.decode([ExtensionContributionSpec].self, forKey: .contributions)
    }
}

private struct PluginManifest: Decodable {
    let apiVersion: Int
    let id: String
    let name: String
    let executable: String
    let args: [String]
    let environment: [String: String]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case apiVersion = "api_version"
        case id, name, executable, args
        case environment = "env"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        apiVersion = try container.decode(Int.self, forKey: .apiVersion)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        executable = try container.decode(String.self, forKey: .executable)
        args = try container.decodeIfPresent([String].self, forKey: .args) ?? []
        environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
    }
}

private struct PluginCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
    init?(intValue: Int) { stringValue = "\(intValue)"; self.intValue = intValue }
}

private extension Decoder {
    func strictContainer<Key: CodingKey & CaseIterable>(
        keyedBy type: Key.Type
    ) throws -> KeyedDecodingContainer<Key> where Key.AllCases: Sequence {
        let dynamic = try container(keyedBy: PluginCodingKey.self)
        let allowed = Set(type.allCases.map(\.stringValue))
        if let unknown = dynamic.allKeys.first(where: { !allowed.contains($0.stringValue) }) {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath + [unknown], debugDescription: "Unknown key '\(unknown.stringValue)'"
            ))
        }
        return try container(keyedBy: type)
    }
}

public enum DefaultConfiguration {
    public static let contents = """
    schema_version = 1

    [theme]
    preset = "segmented"
    font = "SF Pro Text"
    font_size = 13
    foreground = "#F2F2F7FF"
    background = "#17171CDD"
    accent = "#89B4FAFF"
    corner_radius = 10
    padding = 8
    spacing = 10
    animation_ms = 160

    [[surfaces]]
    id = "main"
    kind = "bar"
    display = "all"
    edge = "top"
    top_placement = "menuBarArea"
    fullscreen = "hide"
    start = ["frontmost"]
    center = ["clock"]
    end = ["wifi", "status-separator", "volume", "battery"]

    [[modules]]
    id = "frontmost"
    kind = "frontmostApp"

    [[modules]]
    id = "clock"
    kind = "clock"
    format = "HH:mm"

    [[modules]]
    id = "wifi"
    kind = "wifi"

    [[modules]]
    id = "status-separator"
    kind = "separator"

    [[modules]]
    id = "volume"
    kind = "volume"

    [[modules]]
    id = "battery"
    kind = "battery"
    """
}

public enum ConfigurationInitializer {
    public static func writeDefault(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(DefaultConfiguration.contents.utf8).write(to: url, options: .withoutOverwriting)
    }
}

public enum ManagedResourceDescriptor: Hashable, Sendable {
    case provider(ProviderID)
    case surface(SurfaceID)
    case module(ModuleID)
    case uiExtension(String)
    case notchWidget(String)
    case edgeWidget(String)
}

public protocol ManagedConfigurationResource: Sendable {
    func commit() async
    func stop() async
}

public typealias ManagedResourceFactory = @Sendable (
    ManagedResourceDescriptor,
    AppConfiguration,
    UInt64
) async throws -> any ManagedConfigurationResource

public struct ConfigurationApplyResult: Sendable, Equatable {
    public let applied: Bool
    public let generation: UInt64
    public let diagnostics: [ValidationDiagnostic]
}

public actor ConfigurationCoordinator {
    private let factory: ManagedResourceFactory
    private var resources: [any ManagedConfigurationResource] = []
    private var activeSnapshot: ConfigurationSnapshot?
    private var applying = false
    private var stopping = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private let activate: @Sendable (UInt64?, AppConfiguration?) async -> Void

    public init(activate: @escaping @Sendable (UInt64?, AppConfiguration?) async -> Void = { _, _ in }, factory: @escaping ManagedResourceFactory) {
        self.factory = factory
        self.activate = activate
    }

    public var snapshot: ConfigurationSnapshot? { activeSnapshot }

    public func apply(configuration: AppConfiguration, source: ConfigurationSource) async -> ConfigurationApplyResult {
        await acquire()
        defer { release() }
        guard !stopping, !Task.isCancelled else {
            return .init(applied: false, generation: activeSnapshot?.generation ?? 0,
                         diagnostics: [.init(path: "reload", message: "Rill is stopping or the reload was cancelled")])
        }
        let diagnostics = configuration.validate()
        guard diagnostics.isEmpty else {
            return .init(applied: false, generation: activeSnapshot?.generation ?? 0, diagnostics: diagnostics)
        }

        let generation = (activeSnapshot?.generation ?? 0) + 1
        let descriptors =
            configuration.providers.map { ManagedResourceDescriptor.provider($0.id) } +
            configuration.extensions.map { ManagedResourceDescriptor.uiExtension($0.id) } +
            configuration.modules.map { ManagedResourceDescriptor.module($0.id) } +
            configuration.surfaces.map { ManagedResourceDescriptor.surface($0.id) } +
            configuration.notchWidgets.map { ManagedResourceDescriptor.notchWidget($0.id) } +
            configuration.edgeWidgets.map { ManagedResourceDescriptor.edgeWidget($0.id) }
        var staged: [any ManagedConfigurationResource] = []

        do {
            for descriptor in descriptors {
                try Task.checkCancellation()
                guard !stopping else { throw CancellationError() }
                staged.append(try await factory(descriptor, configuration, generation))
            }
            try Task.checkCancellation()
            guard !stopping else { throw CancellationError() }
        } catch {
            for resource in staged.reversed() {
                await resource.stop()
            }
            return .init(
                applied: false,
                generation: activeSnapshot?.generation ?? 0,
                diagnostics: [.init(path: "reload.prepare", message: String(describing: error))]
            )
        }

        // Preparation is side-effect free. Once commit begins, finish it even if the caller cancels.
        await activate(generation, configuration)
        for resource in staged { await resource.commit() }
        let retired = resources
        resources = staged
        activeSnapshot = .init(generation: generation, configuration: configuration, source: source)
        for resource in retired.reversed() { await resource.stop() }
        return .init(applied: true, generation: generation, diagnostics: [])
    }

    public func acceptsEvent(from generation: UInt64) -> Bool {
        activeSnapshot?.generation == generation
    }

    private func acquire() async {
        if !applying { applying = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty { applying = false }
        else { waiters.removeFirst().resume() }
    }

    public func stop() async {
        stopping = true
        await acquire()
        defer { release() }
        await activate(nil, nil)
        let retired = resources
        resources = []
        activeSnapshot = nil
        for resource in retired.reversed() { await resource.stop() }
    }
}

public actor ConfigurationWatcher {
    public typealias UpdateHandler = @Sendable (Result<ConfigurationSnapshot, ConfigurationLoadError>) async -> Void

    private struct Signature: Equatable {
        let exists: Bool
        let modificationDate: Date?
        let size: UInt64?
        let inode: UInt64?
    }

    private let url: URL
    private let parser: ConfigurationParser
    private let debounce: Duration
    private let pollInterval: Duration
    private let handler: UpdateHandler
    private var task: Task<Void, Never>?
    private var generation: UInt64

    public init(
        url: URL,
        parser: ConfigurationParser = .init(),
        generation: UInt64 = 0,
        debounce: Duration = .milliseconds(150),
        pollInterval: Duration = .milliseconds(50),
        handler: @escaping UpdateHandler
    ) {
        self.url = url.standardizedFileURL
        self.parser = parser
        self.generation = generation
        self.debounce = debounce
        self.pollInterval = pollInterval
        self.handler = handler
    }

    deinit {
        task?.cancel()
    }

    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            await self?.run()
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    private func run() async {
        var previous = signature()
        while !Task.isCancelled {
            try? await Task.sleep(for: pollInterval)
            guard !Task.isCancelled else { return }
            let current = signature()
            guard current != previous else { continue }
            previous = current
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            let settled = signature()
            previous = settled
            generation += 1
            do {
                let snapshot = try parser.load(
                    .init(source: .file(url), wasExplicit: false),
                    generation: generation
                )
                await handler(.success(snapshot))
            } catch let error as ConfigurationLoadError {
                await handler(.failure(error))
            } catch {
                await handler(.failure(.init([
                    .init(path: "config", message: String(describing: error))
                ])))
            }
        }
    }

    private func signature() -> Signature {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return .init(exists: false, modificationDate: nil, size: nil, inode: nil)
        }
        return .init(
            exists: true,
            modificationDate: attributes[.modificationDate] as? Date,
            size: (attributes[.size] as? NSNumber)?.uint64Value,
            inode: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        )
    }
}
