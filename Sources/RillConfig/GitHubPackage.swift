import Foundation

public struct GitHubPackage: Sendable, Equatable {
    public let owner: String
    public let repository: String
    public let tag: String?

    public init(_ value: String) throws {
        guard let url = URLComponents(string: value), url.scheme == "https",
              url.host == "github.com", url.port == nil, url.user == nil,
              url.password == nil, url.query == nil, url.fragment == nil,
              !url.percentEncodedPath.contains("%") else {
            throw Self.invalidURL()
        }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        var components = Array(parts.dropFirst())
        if components.last == "" { components.removeLast() }
        guard components.count == 2 || (components.count == 5 && components[2] == "releases" && components[3] == "tag"),
              components.allSatisfy({ $0.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$"#, options: .regularExpression) != nil }) else {
            throw Self.invalidURL()
        }
        owner = components[0].lowercased()
        let name = components[1]
        repository = (name.hasSuffix(".git") ? String(name.dropLast(4)) : name).lowercased()
        guard !repository.isEmpty else { throw Self.invalidURL() }
        tag = components.count == 5 ? components[4] : nil
    }

    public var downloadURL: URL {
        let release = tag.map { "download/\($0)" } ?? "latest/download"
        return URL(string: "https://github.com/\(owner)/\(repository)/releases/\(release)/rill-plugin-macos-arm64.zip")!
    }

    public var installationDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Rill/packages", isDirectory: true)
            .appendingPathComponent(owner, isDirectory: true)
            .appendingPathComponent(repository, isDirectory: true)
            .appendingPathComponent(tag.map { "tag-\($0)" } ?? "latest", isDirectory: true)
    }

    private static func invalidURL() -> ConfigurationLoadError {
        ConfigurationLoadError([.init(path: "package", message: "Expected https://github.com/OWNER/REPO or https://github.com/OWNER/REPO/releases/tag/TAG")])
    }
}

public struct GitHubPackageInstaller {
    public init() {}

    public func install(_ package: GitHubPackage) throws -> URL {
        let files = FileManager.default
        let destination = package.installationDirectory
        guard !files.fileExists(atPath: destination.path) else {
            throw failure("Already installed at \(destination.path); use a release tag for another version")
        }
        let parent = destination.deletingLastPathComponent()
        try files.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard parent.resolvingSymlinksInPath() == parent.standardizedFileURL else {
            throw failure("Installation directory must not contain symbolic links")
        }
        let temporary = parent.appendingPathComponent(".install-\(UUID().uuidString)", isDirectory: true)
        try files.createDirectory(at: temporary, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? files.removeItem(at: temporary) }
        let archive = temporary.appendingPathComponent("package.zip")
        try run("/usr/bin/curl", ["--fail", "--location", "--silent", "--show-error", "--proto", "=https", "--proto-redir", "=https", "--connect-timeout", "15", "--max-time", "120", "--max-filesize", "104857600", "--output", archive.path, package.downloadURL.absoluteString])
        let listing = temporary.appendingPathComponent("entries.txt")
        try run("/usr/bin/unzip", ["-Z1", archive.path], output: listing)
        let names = try String(contentsOf: listing, encoding: .utf8).split(separator: "\n")
        guard !names.isEmpty, names.count <= 10_000,
              names.allSatisfy({ !$0.hasPrefix("/") && !$0.contains("\\") && !$0.split(separator: "/").contains("..") }) else {
            throw failure("Archive contains unsafe paths or too many entries")
        }
        let contents = temporary.appendingPathComponent("contents", isDirectory: true)
        try files.createDirectory(at: contents, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        try run("/usr/bin/tar", ["-xf", archive.path, "-C", contents.path])
        try validateContents(at: contents)
        try ConfigurationParser().validatePackage(at: contents)
        try files.moveItem(at: contents, to: destination)
        return destination
    }

    private func validateContents(at directory: URL) throws {
        var enumerationError: (any Error)?
        guard let entries = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey], options: [], errorHandler: { _, error in enumerationError = error; return false }) else {
            throw failure("Cannot inspect extracted package")
        }
        var bytes = 0
        for case let entry as URL in entries {
            let values = try entry.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
            guard entry.resolvingSymlinksInPath().path.hasPrefix(directory.path + "/"),
                  values.isRegularFile == true || values.isDirectory == true || values.isSymbolicLink == true else {
                throw failure("Package contains an escaping link or unsupported file")
            }
            bytes += values.fileSize ?? 0
            guard bytes <= 268_435_456 else { throw failure("Extracted package exceeds 256 MiB") }
        }
        if let enumerationError { throw enumerationError }
    }

    private func run(_ executable: String, _ arguments: [String], output: URL? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let handle: FileHandle?
        if let output {
            guard FileManager.default.createFile(atPath: output.path, contents: nil) else { throw failure("Cannot create download log") }
            handle = try FileHandle(forWritingTo: output)
            process.standardOutput = handle
        } else {
            handle = nil
            process.standardOutput = FileHandle.nullDevice
        }
        defer { try? handle?.close() }
        try process.run()
        process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw failure("\(URL(fileURLWithPath: executable).lastPathComponent) failed (\(process.terminationStatus)); package was not installed")
        }
    }

    private func failure(_ message: String) -> ConfigurationLoadError {
        ConfigurationLoadError([.init(path: "install", message: message)])
    }
}
