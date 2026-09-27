import Darwin
import Foundation

/// Owns a process group from the instant of spawn, including children that inherit its pipes.
/// Foundation.Process + setpgid after exec is racy and cannot establish that guarantee.
final class ManagedChildProcess: @unchecked Sendable {
    var executableURL: URL?
    var arguments: [String] = []
    var environment = ProcessInfo.processInfo.environment
    var currentDirectoryURL: URL?
    var standardInput: Pipe?
    var standardOutput = Pipe()
    var standardError = Pipe()
    private let condition = NSCondition()
    private var pid: pid_t = 0
    private var status: Int32?

    var processIdentifier: pid_t { condition.withLock { pid } }
    var isRunning: Bool { condition.withLock { pid > 0 && status == nil } }
    var terminationStatus: Int32 { condition.withLock { status ?? -1 } }

    func run() throws {
        guard let executableURL else { throw POSIXError(.ENOENT) }
        let args = [executableURL.path] + arguments
        let env = environment.map { "\($0.key)=\($0.value)" }
        guard !(args + env).contains(where: { $0.utf8.contains(0) }) else { throw POSIXError(.EINVAL) }
        let argv = args.map { strdup($0) } + [nil]
        let envp = env.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        var attributes: posix_spawnattr_t?
        var actions: posix_spawn_file_actions_t?
        func check(_ result: Int32) throws {
            if result != 0 { throw POSIXError(POSIXErrorCode(rawValue: result) ?? .EIO) }
        }
        try check(posix_spawnattr_init(&attributes))
        defer { posix_spawnattr_destroy(&attributes) }
        try check(posix_spawn_file_actions_init(&actions))
        defer { posix_spawn_file_actions_destroy(&actions) }
        try check(posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK)))
        try check(posix_spawnattr_setpgroup(&attributes, 0))
        var defaults = sigset_t()
        sigemptyset(&defaults)
        for number in [SIGTERM, SIGINT, SIGPIPE] { sigaddset(&defaults, number) }
        try check(posix_spawnattr_setsigdefault(&attributes, &defaults))
        var mask = sigset_t()
        sigemptyset(&mask)
        try check(posix_spawnattr_setsigmask(&attributes, &mask))
        if let directory = currentDirectoryURL {
            try check(posix_spawn_file_actions_addchdir_np(&actions, directory.path))
        }
        let null = open("/dev/null", O_RDONLY | O_CLOEXEC)
        guard null >= 0 else { throw POSIXError(.EIO) }
        defer { close(null) }
        try check(posix_spawn_file_actions_adddup2(&actions, standardInput?.fileHandleForReading.fileDescriptor ?? null, STDIN_FILENO))
        try check(posix_spawn_file_actions_adddup2(&actions, standardOutput.fileHandleForWriting.fileDescriptor, STDOUT_FILENO))
        try check(posix_spawn_file_actions_adddup2(&actions, standardError.fileHandleForWriting.fileDescriptor, STDERR_FILENO))
        var spawned: pid_t = 0
        try check(posix_spawn(&spawned, executableURL.path, &actions, &attributes, argv, envp))
        condition.withLock { pid = spawned }
        // Parent does not retain the child's pipe ends.
        try? standardInput?.fileHandleForReading.close()
        try? standardOutput.fileHandleForWriting.close()
        if standardError !== standardOutput { try? standardError.fileHandleForWriting.close() }
        let childPID = spawned
        DispatchQueue.global(qos: .utility).async { [self] in
            var raw: Int32 = 0
            while waitpid(childPID, &raw, 0) < 0 { if errno != EINTR { break } }
            // A leader's exit must not leave grandchildren holding descriptors indefinitely.
            kill(-childPID, SIGKILL)
            condition.lock()
            status = raw & 0x7f == 0 ? (raw >> 8) & 0xff : 128 + (raw & 0x7f)
            condition.broadcast()
            condition.unlock()
        }
    }

    func terminate() { signalGroup(SIGTERM) }
    func forceTerminate() { signalGroup(SIGKILL) }
    private func signalGroup(_ signal: Int32) {
        condition.withLock { if pid > 0 && status == nil { kill(-pid, signal) } }
    }
    func waitUntilExit() {
        condition.lock()
        while pid > 0 && status == nil { condition.wait() }
        condition.unlock()
    }
}
