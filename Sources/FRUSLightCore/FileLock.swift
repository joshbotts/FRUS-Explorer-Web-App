// Locks between the processes that share a data directory (PLAN's S14b): a server holds
// /data/app/server.lock shared while it runs, and a restore takes it exclusively, so a restore never
// replaces a store a server has open, nor a server opens a store a restore is replacing; a backup
// holds /data/app/backup.lock, so a server's and `frus-light backup`'s never run at once.

import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// An advisory lock on a file of its own, `flock(2)`'s, held until it is released or the process
/// ends, so a process that crashes leaves none behind. Never a lock on the store itself: closing any
/// descriptor of a file releases the POSIX locks SQLite holds on it for the process. Two containers
/// on one Docker host share the kernel, so a lock in the volume holds between them too.
public final class FileLock: @unchecked Sendable {
    public enum Mode: Sendable { case shared, exclusive }

    public let url: URL
    private let descriptor: Int32

    /// Opens the lock's file, making it when it is missing.
    public init(_ url: URL) throws {
        self.url = url
        let descriptor = open(url.path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else { throw FileLockError(url: url, code: errno) }
        self.descriptor = descriptor
    }

    deinit { close(descriptor) }

    /// Takes the lock in `mode`, waiting for it when `wait` is true. Returns false, holding nothing,
    /// when it does not wait and another process holds it in a mode that excludes this one.
    public func lock(_ mode: Mode, wait: Bool) throws -> Bool {
        var operation = mode == .shared ? LOCK_SH : LOCK_EX
        if !wait { operation |= LOCK_NB }
        while flock(descriptor, operation) != 0 {
            switch errno {
            case EINTR: continue
            case EWOULDBLOCK: return false
            case let code: throw FileLockError(url: url, code: code)
            }
        }
        return true
    }

    /// Takes the lock in `mode`, waiting for it off the cooperative pool.
    public func lock(_ mode: Mode) async throws {
        _ = try await Blocking.run { [self] in try lock(mode, wait: true) }
    }

    public func unlock() {
        _ = flock(descriptor, LOCK_UN)
    }
}

/// A lock's file that could not be opened or locked.
public struct FileLockError: Error, CustomStringConvertible {
    public let url: URL
    public let code: Int32

    public var description: String { "cannot lock \(url.path): \(String(cString: strerror(code)))" }
}
