// v1 interface 4, generated files: the server reaches /data through this, never by bare paths.

import Foundation

/// Where the server keeps its files (docs/SPEC.md, Disk layout). Code asks this interface for
/// locations, so a later variant can put generated files somewhere other than a local disk.
public protocol FileStore: Sendable {
    /// Drop zone for Mac exports.
    var importDirectory: URL { get }
    /// The live corpus index.
    var liveIndex: URL { get }
    /// An import's verified copy before it becomes live.
    var candidateIndex: URL { get }
    /// The index an import replaced, kept for rollback.
    var previousIndex: URL { get }
    /// Users and their data.
    var userStore: URL { get }
    /// TEI volumes, mounted read-only from the Mac or fetched.
    var volumesDirectory: URL { get }
    var exportsDirectory: URL { get }
    var backupsDirectory: URL { get }
    /// Creates the directories the server writes to.
    func prepare() throws
    /// Free bytes on the volume that holds the index.
    func availableCapacity() throws -> Int64
}

/// The layout under one data directory, `/data` by default.
public struct DataDirectory: FileStore {
    public let root: URL

    public init(root: URL) { self.root = root.standardizedFileURL }

    public var importDirectory: URL { root.appendingPathComponent("import", isDirectory: true) }
    var indexDirectory: URL { root.appendingPathComponent("index", isDirectory: true) }
    public var liveIndex: URL { indexDirectory.appendingPathComponent("frus.db") }
    public var candidateIndex: URL { indexDirectory.appendingPathComponent("frus.db.new") }
    public var previousIndex: URL { indexDirectory.appendingPathComponent("frus.db.prev") }
    public var userStore: URL { root.appendingPathComponent("app/app.db") }
    public var volumesDirectory: URL { root.appendingPathComponent("volumes", isDirectory: true) }
    public var exportsDirectory: URL { root.appendingPathComponent("exports", isDirectory: true) }
    public var backupsDirectory: URL { root.appendingPathComponent("backups", isDirectory: true) }

    public func prepare() throws {
        // volumes/ is not created: it is a read-only mount, or arrives with Standalone mode.
        for directory in [importDirectory, indexDirectory, userStore.deletingLastPathComponent(),
                          exportsDirectory, backupsDirectory] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    public func availableCapacity() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: indexDirectory.path)
        return (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }
}
