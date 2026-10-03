// v1 interface 1: every write to the corpus index goes through one interface.

import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// The one way to change the corpus index. In phase 1 the only write is installing an
/// imported index; curator corrections and the person rollup will come through here too.
/// Snapshot mode (phase 6) serves a read-only copy, and swaps in `ReadOnlyIndexWriter`.
public protocol IndexWriter: Sendable {
    /// Makes a verified candidate the live index, keeping the replaced one as the previous index.
    func install(candidate: URL) throws
}

/// Writes the index on the local disk.
public struct LocalIndexWriter: IndexWriter {
    let files: any FileStore

    public init(files: any FileStore) { self.files = files }

    /// `frus.db` exists at every instant: the old index is kept as `frus.db.prev` through a hard
    /// link, and one `rename` then replaces `frus.db` with the candidate, atomically. Only on a
    /// filesystem without hard links does the old index move aside first, which leaves a moment
    /// without one.
    public func install(candidate: URL) throws {
        let manager = FileManager.default
        let live = files.liveIndex.path
        let previous = files.previousIndex.path
        if manager.fileExists(atPath: live) {
            if manager.fileExists(atPath: previous) { try manager.removeItem(atPath: previous) }
            if link(live, previous) != 0 {
                guard rename(live, previous) == 0 else { throw Self.posixError("keep \(live) as \(previous)") }
            }
        }
        guard rename(candidate.path, live) == 0 else { throw Self.posixError("move \(candidate.path) to \(live)") }
        syncDirectory(files.liveIndex.deletingLastPathComponent())
    }

    private static func posixError(_ action: String) -> any Error {
        let code = errno
        return CocoaError(.fileWriteUnknown, userInfo: [
            NSLocalizedDescriptionKey: "Could not \(action): \(String(cString: strerror(code)))",
        ])
    }

    /// Flushes the directory entry changes to disk.
    private func syncDirectory(_ directory: URL) {
        let fd = open(directory.path, O_RDONLY)
        guard fd >= 0 else { return }
        _ = fsync(fd)
        _ = close(fd)
    }
}

/// Refuses every write: for an index that must not change, such as a published snapshot.
public struct ReadOnlyIndexWriter: IndexWriter {
    public init() {}

    public func install(candidate: URL) throws { throw IndexWriteRefused() }
}

public struct IndexWriteRefused: Error, CustomStringConvertible, Equatable {
    public init() {}
    public var description: String { "This server's index is read-only." }
}
