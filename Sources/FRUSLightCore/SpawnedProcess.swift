// The processes the server starts itself, the encoder's `llama-server` and its `--version` (PLAN's S27b),
// through posix_spawn(3) rather than Foundation's `Process`, whose start crashed main's ci run 45643998324.
//
// On Linux, `Process.run()` (swift-corelibs-foundation 6.4.3, swift:6.4-noble's and the image's) finds the
// descriptors a child should not inherit by listing /proc/self/fd, and reads each entry's number from a copy
// of its whole 256-byte `d_name` (`findMaximumOpenFromProcSelfFD()`). readdir(3) gives an entry only the
// bytes its name takes, so once the listing holds some 1,355 entries, the last entry in glibc's full 32 KB
// buffer sits 13 bytes from the buffer's end, and the copy reads 243 bytes past it. Where the buffer is the
// last block of a heap, which glibc grows a page at a time, about one start in twenty finds those bytes
// unmapped and the process dies of SIGSEGV: main's FRUSLightServerTests runner did, holding more than 2,332
// descriptors. Foundation's main has the fix (swiftlang/swift-corelibs-foundation#5472, May 2026), which
// neither 6.4.3 nor the 6.4 branch has. Here the child closes every descriptor past its three itself, with
// closefrom, so the parent lists none.

import Dispatch
import Foundation
import Synchronization
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// A process the server started, from its start to its end: the part of `Process` the encoder uses.
final class SpawnedProcess: @unchecked Sendable {
    let processIdentifier: pid_t
    /// How it ended, once it has: the status it exited with, or the signal that ended it.
    private let termination = Mutex<(reason: Process.TerminationReason, status: Int32)?>(nil)
    /// Entered until it has ended, which `waitUntilExit()` waits for.
    private let running = DispatchGroup()

    private init(processIdentifier: pid_t) {
        self.processIdentifier = processIdentifier
    }

    var isRunning: Bool { termination.withLock { $0 == nil } }
    /// The status it exited with, or the signal that ended it; 0 while it runs.
    var terminationStatus: Int32 { termination.withLock { $0?.status ?? 0 } }
    var terminationReason: Process.TerminationReason { termination.withLock { $0?.reason ?? .exit } }

    /// Asks it to end, with SIGTERM, as `Process.terminate()` does.
    func terminate() {
        if isRunning { kill(processIdentifier, SIGTERM) }
    }

    func waitUntilExit() {
        running.wait()
    }

    /// Starts `executable` with `arguments` and `environment` alone, as `Process` started it: in a process
    /// group of its own, reading /dev/null, its output and its errors both written to `output`, a pipe's end
    /// the caller closes once this returns, and its signal mask the calling thread's. Every other descriptor
    /// is closed by the child itself. `terminationHandler` is called once it has ended, on the thread that
    /// waited for it.
    static func run(_ executable: URL, arguments: [String], environment: [String: String], output: Int32,
                    terminationHandler: (@Sendable (SpawnedProcess) -> Void)? = nil) throws -> SpawnedProcess {
        #if canImport(Glibc)
        var actions = posix_spawn_file_actions_t()
        var attributes = posix_spawnattr_t()
        #else
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        #endif
        try SpawnError.check(posix_spawn_file_actions_init(&actions), "posix_spawn_file_actions_init")
        defer { posix_spawn_file_actions_destroy(&actions) }
        try SpawnError.check(posix_spawnattr_init(&attributes), "posix_spawnattr_init")
        defer { posix_spawnattr_destroy(&attributes) }
        // Its output and errors before its input, since `output` may be a low descriptor.
        try SpawnError.check(posix_spawn_file_actions_adddup2(&actions, output, STDOUT_FILENO), "posix_spawn_file_actions_adddup2")
        try SpawnError.check(posix_spawn_file_actions_adddup2(&actions, output, STDERR_FILENO), "posix_spawn_file_actions_adddup2")
        try SpawnError.check(posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0),
                             "posix_spawn_file_actions_addopen")
        #if canImport(Glibc)
        // Every other descriptor, closed in the child by close_range(2) (glibc 2.34): nothing is listed here.
        try SpawnError.check(posix_spawn_file_actions_addclosefrom_np(&actions, STDERR_FILENO + 1),
                             "posix_spawn_file_actions_addclosefrom_np")
        let flags = Int16(POSIX_SPAWN_SETPGROUP)
        #else
        let flags = Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT)
        #endif
        try SpawnError.check(posix_spawnattr_setflags(&attributes, flags), "posix_spawnattr_setflags")
        let argv: [UnsafeMutablePointer<CChar>?] = ([executable.path] + arguments).map { strdup($0) } + [nil]
        let envp: [UnsafeMutablePointer<CChar>?] = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { for pointer in argv + envp { free(pointer) } }
        var pid = pid_t()
        // Neither array is empty: each ends in its nil.
        let spawned = argv.withUnsafeBufferPointer { argv in
            envp.withUnsafeBufferPointer { envp in
                posix_spawn(&pid, executable.path, &actions, &attributes, argv.baseAddress!, envp.baseAddress!)
            }
        }
        try SpawnError.check(spawned, "posix_spawn of \(executable.path)")
        let process = SpawnedProcess(processIdentifier: pid)
        process.running.enter()
        Thread.detachNewThread {
            var status: Int32 = 0
            var reaped: pid_t
            repeat { reaped = waitpid(process.processIdentifier, &status, 0) } while reaped == -1 && errno == EINTR
            // As `Process` reads a status: the signal in its low seven bits, or else the status above them.
            let signal = status & 0x7f
            let ending: (reason: Process.TerminationReason, status: Int32) =
                reaped != process.processIdentifier ? (.exit, -1) : signal == 0 ? (.exit, (status >> 8) & 0xff) : (.uncaughtSignal, signal)
            process.termination.withLock { $0 = ending }
            process.running.leave()
            terminationHandler?(process)
        }
        return process
    }
}

/// A step of a start that failed, and the error it gave.
struct SpawnError: Error, CustomStringConvertible {
    let step: String
    let code: Int32

    var description: String { "\(step) failed: \(String(cString: strerror(code)))" }

    static func check(_ result: Int32, _ step: String) throws {
        guard result == 0 else { throw SpawnError(step: step, code: result) }
    }
}
