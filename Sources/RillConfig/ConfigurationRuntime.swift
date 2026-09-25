import Foundation
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
    public init() {}

    public func load(_ resolution: ConfigurationResolution, generation: UInt64 = 0) throws -> ConfigurationSnapshot {
        switch resolution.source {
        case .bundledDefault:
            return try parse(
                text: DefaultConfiguration.contents,
                source: .bundledDefault,
                generation: generation
            )
        case .file(let url):
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw ConfigurationLoadError([
                    .init(path: "config", message: "Cannot read \(url.path): \(error.localizedDescription)")
                ])
            }
            guard let text = String(data: data, encoding: .utf8) else {
                throw ConfigurationLoadError([
                    .init(path: "config", message: "Configuration must be UTF-8")
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
        let decoded: AppConfiguration
        do {
            decoded = try TOMLDecoder().decode(AppConfiguration.self, from: text)
        } catch {
            throw ConfigurationLoadError([diagnostic(for: error)])
        }

        let diagnostics = decoded.validate()
        guard diagnostics.isEmpty else {
            throw ConfigurationLoadError(diagnostics)
        }

        return ConfigurationSnapshot(
            generation: generation,
            configuration: resolveRelativePaths(in: decoded, source: source),
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
            if let executable = result.modules[index].onClick?.executable {
                result.modules[index].onClick?.executable = resolve(executable, relativeTo: baseURL)
            }
        }
        return result
    }

    private func resolve(_ path: String, relativeTo directory: URL) -> String {
        if path.hasPrefix("/") { return URL(fileURLWithPath: path).standardizedFileURL.path }
        return URL(fileURLWithPath: path, relativeTo: directory).standardizedFileURL.path
    }
}

public enum DefaultConfiguration {
    public static let contents = """
    schema_version = 1

    [theme]
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
    end = ["battery"]

    [[modules]]
    id = "frontmost"
    kind = "frontmostApp"

    [[modules]]
    id = "clock"
    kind = "clock"
    format = "HH:mm"

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

    public init(factory: @escaping ManagedResourceFactory) {
        self.factory = factory
    }

    public var snapshot: ConfigurationSnapshot? { activeSnapshot }

    public func apply(configuration: AppConfiguration, source: ConfigurationSource) async -> ConfigurationApplyResult {
        let diagnostics = configuration.validate()
        guard diagnostics.isEmpty else {
            return .init(applied: false, generation: activeSnapshot?.generation ?? 0, diagnostics: diagnostics)
        }

        let generation = (activeSnapshot?.generation ?? 0) + 1
        let descriptors =
            configuration.providers.map { ManagedResourceDescriptor.provider($0.id) } +
            configuration.modules.map { ManagedResourceDescriptor.module($0.id) } +
            configuration.surfaces.map { ManagedResourceDescriptor.surface($0.id) }
        var staged: [any ManagedConfigurationResource] = []

        do {
            for descriptor in descriptors {
                staged.append(try await factory(descriptor, configuration, generation))
            }
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

    public func stop() async {
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
            let current = signature()
            guard current != previous else { continue }
            previous = current
            try? await Task.sleep(for: debounce)
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
