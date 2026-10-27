// What GET /api/v1/admin/backup gives (PLAN's S14b): the newest backup with a manifest of versions,
// as one tar archive, `manifest.json` first and then the backup under its own name. `tar -xf` opens
// it, and `frus-light restore` takes it as it is, checking the backup against its manifest.

import Crypto
import Foundation

/// `manifest.json`: the backup the archive holds, the versions of the server that wrote it, and
/// every backup and copy that server keeps.
public struct BackupManifest: Codable, Equatable, Sendable {
    /// This manifest's own format.
    public var manifestVersion: Int
    /// The backup the archive holds, with its SHA-256.
    public var backup: Version
    public var server: Server
    /// Every backup and copy the server keeps, newest first, the archive's among them.
    public var versions: [Version]

    public static let currentVersion = 1

    /// One backup or copy of the store.
    public struct Version: Codable, Equatable, Sendable {
        public var name: String
        public var kind: UserStoreBackupKind
        /// When it was taken, ISO 8601 in UTC.
        public var takenAt: String
        public var bytes: Int64
        /// The store's migration in it; nil for a file that cannot be read.
        public var migration: Int?
        /// The SHA-256 of its bytes, for the backup the archive holds.
        public var sha256: String?
        /// Whether the folder backups are copied to holds it too; nil when there is none.
        public var copied: Bool?
    }

    /// What wrote the archive.
    public struct Server: Codable, Equatable, Sendable {
        public var version: String
        /// The store's newest migration this server knows: a restore takes a backup up to it.
        public var migration: Int
        /// The index version it serves.
        public var indexVersion: Int
        public var sqliteVersion: String

        public static var current: Server {
            Server(version: FRUSLightVersion.string, migration: UserStoreMigrations.all.count,
                   indexVersion: IndexCompatibility.supportedIndexVersion, sqliteVersion: SQLiteConnection.libraryVersion)
        }
    }

    /// The manifest of `backup`, `bytes` long with the SHA-256 `sha256`, among every backup and copy
    /// in its folder.
    static func describing(_ backup: UserStoreBackupFile, bytes: Int64, sha256: String, copyDirectory: URL?) -> BackupManifest {
        let copies = copyDirectory.map { UserStoreBackup.files(in: $0) }
        func version(_ file: UserStoreBackupFile) -> Version {
            let bytes = size(of: file.url)
            let copied = copies.map { $0.contains { $0.name == file.name && size(of: $0.url) == bytes } }
            return Version(name: file.name, kind: file.kind, takenAt: file.takenAt.formatted(.iso8601), bytes: bytes,
                           migration: migration(of: file.url), sha256: nil, copied: copied)
        }
        var held = version(backup)
        held.bytes = bytes
        held.sha256 = sha256
        let versions = UserStoreBackup.files(in: backup.url.deletingLastPathComponent())
            .map { $0.name == backup.name ? held : version($0) }
        return BackupManifest(manifestVersion: currentVersion, backup: held, server: .current, versions: versions)
    }

    private static func size(of file: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// The store's migration in `file`, read without locks; nil for a file that is not a store.
    static func migration(of file: URL) -> Int? {
        guard let db = try? SQLiteConnection.immutable(file) else { return nil }
        defer { db.close() }
        return (try? db.scalar("SELECT max(version) FROM schema_migrations"))?.integer.map { Int($0) }
    }

    /// The manifest as the archive writes it: sorted keys, two spaces' indent.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

/// The newest backup, opened, with its manifest: the archive `GET /api/v1/admin/backup` streams.
/// It reads the backup through the handle it hashed it through, so it streams those bytes though
/// a newer backup is taken meanwhile.
public final class BackupArchiveSource: @unchecked Sendable {
    public let manifest: BackupManifest
    private let manifestData: Data
    private let handle: FileHandle
    private let modified: Date

    /// The newest daily backup in `directory` and its manifest; nil when it has none.
    public static func newest(in directory: URL, copyDirectory: URL?) throws -> BackupArchiveSource? {
        guard let newest = UserStoreBackup.files(in: directory).first(where: { $0.kind == .daily }) else { return nil }
        let handle = try FileHandle(forReadingFrom: newest.url)
        do {
            // The bytes this handle reads are the ones described and then streamed.
            var hash = SHA256()
            while let chunk = try handle.read(upToCount: UserStoreBackup.chunkSize), !chunk.isEmpty { hash.update(data: chunk) }
            let sha256 = hash.finalize().map { String(format: "%02x", $0) }.joined()
            let manifest = BackupManifest.describing(newest, bytes: Int64(try handle.offset()), sha256: sha256,
                                                     copyDirectory: copyDirectory)
            try handle.seek(toOffset: 0)
            let modified = (try? FileManager.default.attributesOfItem(atPath: newest.url.path))?[.modificationDate] as? Date
            return BackupArchiveSource(manifest: manifest, data: try manifest.encoded(), handle: handle, modified: modified ?? Date())
        } catch {
            try? handle.close()
            throw error
        }
    }

    private init(manifest: BackupManifest, data: Data, handle: FileHandle, modified: Date) {
        self.manifest = manifest
        manifestData = data
        self.handle = handle
        self.modified = modified
    }

    deinit { try? handle.close() }

    /// The archive's file name, `frus-light-backup-20261027T030000Z.tar` for `app-20261027T030000Z.db`.
    public var fileName: String {
        "frus-light-backup-\(manifest.backup.name.dropFirst("app-".count).dropLast(".db".count)).tar"
    }

    /// The archive's length in bytes.
    public var length: Int64 {
        BackupArchive.member(Int64(manifestData.count)) + BackupArchive.member(manifest.backup.bytes) + Int64(BackupArchive.end.count)
    }

    /// Hands the archive to `write` in order, a part at a time: the manifest's header and bytes, the
    /// backup's in chunks, each read off the cooperative pool, and the archive's end.
    public func write(_ write: (Data) async throws -> Void) async throws {
        try await write(Data(BackupArchive.header(name: BackupArchive.manifestName, size: Int64(manifestData.count), modified: modified)))
        try await write(manifestData + BackupArchive.padding(after: Int64(manifestData.count)))
        try await write(Data(BackupArchive.header(name: manifest.backup.name, size: manifest.backup.bytes, modified: modified)))
        var left = manifest.backup.bytes
        while left > 0 {
            let count = Int(min(left, Int64(UserStoreBackup.chunkSize)))
            let chunk = try await Blocking.run { [self] in try handle.read(upToCount: count) ?? Data() }
            guard !chunk.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            left -= Int64(chunk.count)
            try await write(chunk)
        }
        try await write(BackupArchive.padding(after: manifest.backup.bytes) + Data(BackupArchive.end))
    }
}

/// The archive's tar format, POSIX ustar: a 512-byte header for each member, its bytes padded to a
/// whole block, and two empty blocks at the end.
public enum BackupArchive {
    public static let manifestName = "manifest.json"
    static let block = 512
    static let end = [UInt8](repeating: 0, count: 2 * block)

    /// The blocks a member of `size` bytes takes, its header's among them, in bytes.
    static func member(_ size: Int64) -> Int64 {
        Int64(block) + (size + Int64(block) - 1) / Int64(block) * Int64(block)
    }

    /// The zeros after a member of `size` bytes, to a whole block.
    static func padding(after size: Int64) -> Data {
        Data(count: Int((Int64(block) - size % Int64(block)) % Int64(block)))
    }

    /// A regular file's header, readable by -rw-r--r--, owned by no one in particular.
    static func header(name: String, size: Int64, modified: Date) -> [UInt8] {
        var header = [UInt8](repeating: 0, count: block)
        // The names the server gives are ASCII, and far shorter than the field's 100 bytes.
        func put(_ text: String, at offset: Int, width: Int = 100) {
            for (index, byte) in text.utf8.prefix(width).enumerated() { header[offset + index] = byte }
        }
        // An octal number of `width - 1` digits and a NUL, as ustar writes one.
        func octal(_ value: Int64, at offset: Int, width: Int) {
            let digits = String(value, radix: 8)
            put(String(repeating: "0", count: max(0, width - 1 - digits.count)) + digits, at: offset, width: width - 1)
        }
        put(name, at: 0)
        octal(0o644, at: 100, width: 8)
        octal(0, at: 108, width: 8)
        octal(0, at: 116, width: 8)
        octal(size, at: 124, width: 12)
        octal(Int64(modified.timeIntervalSince1970.rounded(.down)), at: 136, width: 12)
        header[156] = UInt8(ascii: "0")
        put("ustar", at: 257)
        put("00", at: 263)
        put("        ", at: 148)
        // Six digits, a NUL and a space, summed with the field as spaces.
        let sum = header.reduce(0) { $0 + Int($1) }
        octal(Int64(sum), at: 148, width: 7)
        header[154] = 0
        header[155] = UInt8(ascii: " ")
        return header
    }

    /// Whether `file` begins with a ustar header, as an archive from the API does.
    public static func isArchive(_ file: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return false }
        defer { try? handle.close() }
        guard let first = try? handle.read(upToCount: block), first.count == block else { return false }
        return Array(first[257..<262]) == Array("ustar".utf8)
    }

    /// Reads `archive`'s manifest, then writes the backup it names to `destination`, which must not
    /// exist, holding it to the manifest's size and SHA-256. Returns the manifest.
    public static func extract(_ archive: URL, to destination: URL) throws -> BackupManifest {
        let handle = try FileHandle(forReadingFrom: archive)
        defer { try? handle.close() }
        var manifest: BackupManifest?
        while true {
            guard let header = try handle.read(upToCount: block), header.count == block else {
                throw ArchiveError("it ends before its last header")
            }
            let bytes = Array(header)
            if bytes.allSatisfy({ $0 == 0 }) { break }
            guard Array(bytes[257..<262]) == Array("ustar".utf8), checksum(of: bytes) else {
                throw ArchiveError("a header is damaged")
            }
            let name = text(bytes[0..<100])
            let prefix = text(bytes[345..<500])
            let path = prefix.isEmpty ? name : "\(prefix)/\(name)"
            guard let size = number(bytes[124..<136]) else { throw ArchiveError("a header gives no size") }
            let isFile = bytes[156] == UInt8(ascii: "0") || bytes[156] == 0
            if isFile, path == manifestName, manifest == nil {
                guard size <= 1 << 24, let data = try handle.read(upToCount: Int(size)), Int64(data.count) == size else {
                    throw ArchiveError("its manifest is cut short")
                }
                do {
                    manifest = try JSONDecoder().decode(BackupManifest.self, from: data)
                } catch {
                    throw ArchiveError("its manifest cannot be read: \(error)")
                }
                try handle.seek(toOffset: try handle.offset() + UInt64(padding(after: size).count))
            } else if isFile, let manifest, path == manifest.backup.name {
                try write(size, from: handle, to: destination, as: manifest.backup)
                return manifest
            } else {
                try handle.seek(toOffset: try handle.offset() + UInt64(member(size) - Int64(block)))
            }
        }
        throw ArchiveError(manifest == nil ? "it holds no manifest.json" : "it holds no \(manifest?.backup.name ?? "backup")")
    }

    /// Copies a member of `size` bytes from `handle` to `destination`, flushed to disk, and holds it
    /// to `version`'s size and SHA-256; removes it when it does not match.
    private static func write(_ size: Int64, from handle: FileHandle, to destination: URL, as version: BackupManifest.Version) throws {
        guard size == version.bytes else {
            throw ArchiveError("its \(version.name) is \(size) bytes, where its manifest says \(version.bytes)")
        }
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: destination.path])
        }
        do {
            let writer = try FileHandle(forWritingTo: destination)
            defer { try? writer.close() }
            var hash = SHA256()
            var left = size
            while left > 0 {
                guard let chunk = try handle.read(upToCount: Int(min(left, Int64(UserStoreBackup.chunkSize)))), !chunk.isEmpty else {
                    throw ArchiveError("its \(version.name) is cut short")
                }
                hash.update(data: chunk)
                try writer.write(contentsOf: chunk)
                left -= Int64(chunk.count)
            }
            try writer.synchronize()
            let sha256 = hash.finalize().map { String(format: "%02x", $0) }.joined()
            guard sha256 == version.sha256 else {
                throw ArchiveError("its \(version.name) is not the file its manifest describes: its SHA-256 is \(sha256), not \(version.sha256 ?? "given")")
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    private static func checksum(of header: [UInt8]) -> Bool {
        var unsigned = 0
        for (index, byte) in header.enumerated() { unsigned += (148..<156).contains(index) ? 0x20 : Int(byte) }
        return number(header[148..<156]) == Int64(unsigned)
    }

    /// A NUL-terminated field.
    private static func text(_ field: ArraySlice<UInt8>) -> String {
        String(decoding: field.prefix { $0 != 0 }, as: UTF8.self)
    }

    /// An octal field, its spaces and NULs set aside.
    private static func number(_ field: ArraySlice<UInt8>) -> Int64? {
        let digits = String(decoding: field.filter { $0 != 0 && $0 != 0x20 }, as: UTF8.self)
        return digits.isEmpty ? 0 : Int64(digits, radix: 8)
    }
}

/// An archive that is not one the API wrote, or was changed after.
public struct ArchiveError: Error, CustomStringConvertible {
    public let reason: String

    init(_ reason: String) { self.reason = reason }

    public var description: String { reason }
}
