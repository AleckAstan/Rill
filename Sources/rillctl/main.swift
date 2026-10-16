import Darwin
import Foundation

enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case exit(Int32, String)

    var description: String {
        switch self {
        case .usage(let message), .exit(_, let message): return message
        }
    }
}

struct RillCTL {
    static func main() {
        do {
            try run(Array(CommandLine.arguments.dropFirst()))
        } catch let error as ConfigurationLoadError {
            fputs(error.description + "\n", stderr)
            exit(2)
        } catch let error as CLIError {
            fputs("rillctl: \(error.description)\n", stderr)
            if case .exit(let code, _) = error { exit(code) }
            exit(2)
        } catch let error as IPCTransportError {
            fputs("rillctl: \(error.description)\n", stderr)
            exit(3)
        } catch {
            fputs("rillctl: \(error)\n", stderr)
            exit(2)
        }
    }

    static func run(_ arguments: [String]) throws {
        guard let command = arguments.first else {
            printHelp()
            return
        }

        switch command {
        case "--help", "help":
            printHelp()
        case "--version", "version":
            print("rillctl 0.1.0")
        case "init":
            try initialize(Array(arguments.dropFirst()))
        case "install":
            guard arguments.count == 2 else { throw CLIError.usage("install requires a GitHub repository or release URL") }
            let package = try GitHubPackage(arguments[1])
            let directory = try GitHubPackageInstaller().install(package)
            print("Installed \(directory.path)")
        case "validate":
            try validate(Array(arguments.dropFirst()))
        case "status":
            guard Array(arguments.dropFirst()) == ["--json"] else { throw CLIError.usage("status requires --json") }
            try runtime(command: "status")
        case "diagnostics":
            guard Array(arguments.dropFirst()) == ["--json"] else { throw CLIError.usage("diagnostics requires --json") }
            try runtime(command: "diagnostics")
        case "displays":
            guard Array(arguments.dropFirst()) == ["--json"] else { throw CLIError.usage("displays requires --json") }
            try runtime(command: "displays")
        case "reload":
            guard arguments.count == 1 else { throw CLIError.usage("reload accepts no arguments") }
            try runtime(command: "reload")
        case "emit":
            try emit(Array(arguments.dropFirst()))
        default:
            throw CLIError.usage("unknown command '\(command)'; run rillctl --help")
        }
    }

    static func initialize(_ arguments: [String]) throws {
        let explicitPath = try configPath(in: arguments, required: false)
        let resolver = ConfigurationResolver()
        let destination: URL
        if let explicitPath {
            destination = URL(
                fileURLWithPath: explicitPath,
                relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            ).standardizedFileURL
        } else {
            destination = resolver.defaultConfigurationURL
        }

        do {
            try ConfigurationInitializer.writeDefault(to: destination)
            print("Created \(destination.path)")
        } catch CocoaError.fileWriteFileExists {
            throw CLIError.usage("refusing to overwrite existing configuration: \(destination.path)")
        } catch {
            throw CLIError.usage("cannot create \(destination.path): \(error.localizedDescription)")
        }
    }

    static func validate(_ arguments: [String]) throws {
        guard let explicitPath = try configPath(in: arguments, required: true) else {
            throw CLIError.usage("validate requires --config PATH")
        }
        let resolution = try ConfigurationResolver().resolve(explicitPath: explicitPath)
        let snapshot = try ConfigurationParser().load(resolution)
        print("Valid configuration: \(snapshot.source.fileURL?.path ?? "bundled defaults")")
    }

    static func configPath(in arguments: [String], required: Bool) throws -> String? {
        guard !arguments.isEmpty else {
            if required { throw CLIError.usage("missing --config PATH") }
            return nil
        }
        guard arguments.count == 2, arguments[0] == "--config", !arguments[1].isEmpty else {
            throw CLIError.usage("expected --config PATH")
        }
        return arguments[1]
    }

    static func runtime(command: String, arguments: [String: JSONValue] = [:]) throws {
        let request = IPCRequestEnvelope(requestID: UUID().uuidString, command: command, arguments: arguments)
        let reply = try IPCClient().send(request)
        guard reply.ok, let result = reply.result else {
            throw CLIError.exit(4, reply.error?.message ?? "request rejected")
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(result)
        print(String(decoding: data, as: UTF8.self))
    }

    static func emit(_ arguments: [String]) throws {
        var source: String?; var name: String?; var rawData: String?
        var index = 0
        while index < arguments.count {
            guard index + 1 < arguments.count else { throw CLIError.usage("emit option '\(arguments[index])' requires a value") }
            switch arguments[index] {
            case "--source": source = arguments[index + 1]
            case "--name": name = arguments[index + 1]
            case "--data": rawData = arguments[index + 1]
            default: throw CLIError.usage("unknown emit option '\(arguments[index])'")
            }
            index += 2
        }
        guard let source, !source.isEmpty, let name, !name.isEmpty, let rawData,
              let bytes = rawData.data(using: .utf8) else {
            throw CLIError.usage("emit requires --source ID --name NAME --data JSON")
        }
        let payload: JSONValue
        do { payload = try JSONDecoder().decode(JSONValue.self, from: bytes) }
        catch { throw CLIError.usage("--data is invalid JSON: \(error)") }
        guard case .object = payload else { throw CLIError.usage("--data must be a JSON object") }
        try runtime(command: "emit", arguments: ["source": .string(source), "name": .string(name), "data": payload])
    }

    static func printHelp() {
        print("""
        rillctl - configure and control Rill

        Usage:
          rillctl init [--config PATH]      Create the no-manager starter without overwriting
          rillctl validate --config PATH    Parse and validate without executing commands
          rillctl install GITHUB_URL        Install a trusted release without executing it
          rillctl reload                    Reload the active configuration
          rillctl status --json             Show generation, provider health and errors
          rillctl diagnostics --json        Export-safe redacted runtime diagnostics
          rillctl displays --json           List stable display identifiers
          rillctl emit --source ID --name NAME --data JSON
          rillctl --help                    Show this help
          rillctl --version                 Show the CLI version
        """)
    }
}

RillCTL.main()
