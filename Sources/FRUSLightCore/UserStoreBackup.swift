// Copies of the user store in /data/backups, made with SQLite's backup API: before each migration
// from S14a, and daily from S14b, with the store a restore replaces. Each has a name that says what
// it is and when it was taken, and a fingerprint of what it holds.

import Crypto
import Foundation

/// A copy of `app.db` that could not be made. The store is left as it was.
public struct UserStoreBackupFailed: Error, CustomStringConvertible {
    public let destination: URL
    public let underlying: any Error

    public var description: String {
        "the user store could not be copied to \(destination.path) (\(underlying)), so it was left as it was"
    }
}

/// What a file in the backups folder is, by its name.
public enum UserStoreBackupKind: String, Sendable, Codable, Equatable {
    /// One of the daily backups, or one `frus-light backup` took, which counts among them: seven
    /// are kept (S14b).
    case daily
    /// The store as it was before a start migrated it (S14a), kept until it is removed by hand.
    case beforeMigration
    /// The store a restore replaced (S14b), kept until it is removed by hand.
    case beforeRestore
}

/// A backup or a copy of the store, under a name the server gave it.
public struct UserStoreBackupFile: Sendable, Equatable {
    public let url: URL
    public let kind: UserStoreBackupKind
    /// When it was taken, read from its name: to the second, in UTC.
    public let takenAt: Date
    /// The number after the time of a name that was taken already, 1 for none, so two copies taken
    /// in one second keep their order.
    let sequence: Int

    public var name: String { url.lastPathComponent }

    /// The file at `url` when its name is one the server gives: `app-20261027T030000Z.db`, with `-2`,
    /// `-3` and so on after the time where that name was taken, and `-before-migration-<n>` or
    /// `-before-restore` before `.db` for a copy. Nil for any other name.
    public init?(_ url: URL) {
        let pattern = /^app-([0-9]{8}T[0-9]{6}Z)(?:-([0-9]+))?(-before-migration-[0-9]+|-before-restore)?\.db$/
        guard let match = url.lastPathComponent.wholeMatch(of: pattern),
              let takenAt = UserStoreBackup.date(fromStamp: String(match.1)) else { return nil }
        self.url = url
        self.takenAt = takenAt
        sequence = match.2.flatMap { Int($0) } ?? 1
        switch match.3 {
        case nil: kind = .daily
        case "-before-restore": kind = .beforeRestore
        default: kind = .beforeMigration
        }
    }

    /// Whether this was taken after `other`.
    public func isNewer(than other: UserStoreBackupFile) -> Bool {
        (takenAt, sequence) > (other.takenAt, other.sequence)
    }
}

/// Writes copies of the user store.
public enum UserStoreBackup {
    /// Copies the store at `store` into `directory` as `name`, through the backup API, which is
    /// safe while the store is open (SPEC's compatibility contract, rule 4). It reads the store
    /// through a read-only connection of its own, so it copies only what has been committed. The
    /// copy is written under a `.partial` name of its own, checked with `quick_check`, switched out
    /// of write-ahead logging so it is one self-contained file, and only then given its name, which
    /// it never takes from another copy: a file with that name is always a whole copy. Returns where
    /// it is.
    public static func copy(of store: URL, into directory: URL, named name: String) async throws -> URL {
        let destination = directory.appendingPathComponent(name)
        let partial = directory.appendingPathComponent("\(name).\(UUID().uuidString).partial")
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let source = try SQLiteConnection(store.path, readOnly: true)
            defer { source.close() }
            let copy = try SQLiteConnection(partial.path, readOnly: false, create: true)
            do {
                try await source.backup(into: copy)
                try copy.execute("PRAGMA journal_mode = DELETE")
                let check = try copy.scalar("PRAGMA quick_check")?.text
                guard check == "ok" else {
                    throw SQLiteError(code: 11, message: "the copy failed its quick_check: \(check ?? "no answer")")
                }
                copy.close()
            } catch {
                copy.close()
                throw error
            }
            guard !manager.fileExists(atPath: destination.path) else {
                throw CocoaError(.fileWriteFileExists)
            }
            try manager.moveItem(at: partial, to: destination)
            return destination
        } catch {
            for leftover in [partial.path, partial.path + "-journal", partial.path + "-wal", partial.path + "-shm"] {
                try? manager.removeItem(atPath: leftover)
            }
            throw UserStoreBackupFailed(destination: destination, underlying: error)
        }
    }

    /// The newest copy in `directory` taken before migration `version` that holds what the store at
    /// `store` holds now, or nil when there is none: what a start that failed to migrate the store
    /// as it is left behind.
    public static func copy(of store: URL, before version: Int, in directory: URL) throws -> URL? {
        let suffix = "-before-migration-\(version).db"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let copies = names.filter { $0.hasPrefix("app-") && $0.hasSuffix(suffix) }
            .map { directory.appendingPathComponent($0) }
            .sorted { modified($0) > modified($1) }
        for copy in copies where try holdTheSame(store, copy) { return copy }
        return nil
    }

    /// Whether two databases hold the same: every schema object's SQL and every table's rows, a
    /// full-text table's through its own tables. The second must not change while it is read.
    static func holdTheSame(_ first: URL, _ second: URL) throws -> Bool {
        try fingerprint(of: first) == fingerprint(of: second, immutable: true)
    }

    /// A digest of what a database holds: each schema object's SQL, then each table's rows in
    /// order, a full-text table's through its own tables. Two databases hold the same exactly when
    /// their digests are equal, so a backup is read once to tell whether the store has changed
    /// since it, and no table is ever held whole. It reads in one transaction, so a store in use is
    /// read as it stood at one moment; `immutable` reads a file that does not change, such as a
    /// finished backup, without locks.
    public static func fingerprint(of database: URL, immutable: Bool = false) throws -> String {
        let db = try immutable ? SQLiteConnection.immutable(database) : SQLiteConnection(database.path, readOnly: true)
        defer { db.close() }
        var digest = RowDigest()
        try db.execute("BEGIN")
        defer { try? db.execute("COMMIT") }
        try db.forEachRow("SELECT type, name, tbl_name, coalesce(sql, '') FROM sqlite_master ORDER BY type, name") {
            digest.add($0)
        }
        let tables = try db.query("SELECT name, coalesce(sql, '') FROM sqlite_master WHERE type = 'table' ORDER BY name")
        for table in tables {
            guard let name = table[0].text else { continue }
            let sql = (table[1].text ?? "").uppercased()
            guard !sql.hasPrefix("CREATE VIRTUAL TABLE") else { continue }
            digest.add([.text(name)])
            // A table without rowids reads in its key's order.
            let order = sql.contains("WITHOUT ROWID") ? "" : " ORDER BY rowid"
            try db.forEachRow("SELECT * FROM \"\(name.replacingOccurrences(of: "\"", with: "\"\""))\"\(order)") {
                digest.add($0)
            }
        }
        return digest.hex
    }

    /// Whether a store holds no research yet: no row in any table but its users and its migrations,
    /// a full-text table read as itself. Its backup would hold nothing to restore (S14b).
    public static func holdsNoResearch(_ store: URL) throws -> Bool {
        let db = try SQLiteConnection(store.path, readOnly: true)
        defer { db.close() }
        let tables = try db.query("SELECT name, coalesce(sql, '') FROM sqlite_master WHERE type = 'table'")
        let virtual = tables.filter { ($0[1].text ?? "").uppercased().hasPrefix("CREATE VIRTUAL TABLE") }.compactMap { $0[0].text }
        for table in tables {
            guard let name = table[0].text, name != "users", name != "schema_migrations", !name.hasPrefix("sqlite_"),
                  !virtual.contains(where: { name.hasPrefix($0 + "_") }) else { continue }
            let quoted = "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
            if try db.scalar("SELECT EXISTS (SELECT 1 FROM \(quoted))")?.integer == 1 { return false }
        }
        return true
    }

    /// The SHA-256 of a file's bytes, in lowercase hexadecimal.
    public static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty { hash.update(data: chunk) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Copies a finished file byte for byte into `directory` under its own name, through a
    /// `.partial` name, flushed to disk before it takes its name, which it never takes from another
    /// file. For a backup that is whole and closed, such as one copied to a folder shared from the
    /// host, where SQLite's locks may not hold: a store in use is copied only by the backup API.
    public static func copyFile(_ source: URL, into directory: URL, named name: String? = nil) throws -> URL {
        let destination = directory.appendingPathComponent(name ?? source.lastPathComponent)
        let partial = directory.appendingPathComponent("\(destination.lastPathComponent).\(UUID().uuidString).partial")
        let manager = FileManager.default
        do {
            guard manager.createFile(atPath: partial.path, contents: nil) else {
                throw CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: partial.path])
            }
            let reader = try FileHandle(forReadingFrom: source)
            defer { try? reader.close() }
            let writer = try FileHandle(forWritingTo: partial)
            do {
                while let chunk = try reader.read(upToCount: chunkSize), !chunk.isEmpty { try writer.write(contentsOf: chunk) }
                try writer.synchronize()
                try writer.close()
            } catch {
                try? writer.close()
                throw error
            }
            guard !manager.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteFileExists) }
            try manager.moveItem(at: partial, to: destination)
            return destination
        } catch {
            try? manager.removeItem(at: partial)
            throw UserStoreBackupFailed(destination: destination, underlying: error)
        }
    }

    /// The backups and copies in `directory` whose names the server gave them, newest first; none
    /// when there is no such folder.
    public static func files(in directory: URL) -> [UserStoreBackupFile] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.compactMap { UserStoreBackupFile(directory.appendingPathComponent($0)) }
            .sorted { $0.isNewer(than: $1) }
    }

    private static func modified(_ file: URL) -> Date {
        ((try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date) ?? .distantPast
    }

    /// The name of the copy taken before migration `version` runs, such as
    /// `app-20261024T031500Z-before-migration-2.db`: the time first, in UTC, so a folder of copies
    /// lists in the order they were made. A copy already of that name gets a number after the time.
    public static func nameBeforeMigration(_ version: Int, at date: Date, in directory: URL) -> String {
        name(at: date, ending: "-before-migration-\(version)", in: [directory])
    }

    /// The name of a backup taken at `date`, such as `app-20261027T030000Z.db`, numbered after the
    /// time when a file of that name is in any of `directories`, the folder it is copied to too.
    public static func dailyName(at date: Date, in directories: [URL]) -> String {
        name(at: date, ending: "", in: directories)
    }

    /// The name of the copy of the store a restore replaces, such as
    /// `app-20261027T150000Z-before-restore.db`, numbered as `dailyName` numbers one.
    public static func nameBeforeRestore(at date: Date, in directories: [URL]) -> String {
        name(at: date, ending: "-before-restore", in: directories)
    }

    private static func name(at date: Date, ending: String, in directories: [URL]) -> String {
        let stamp = timestamp(date)
        func taken(_ name: String) -> Bool {
            directories.contains { FileManager.default.fileExists(atPath: $0.appendingPathComponent(name).path) }
        }
        var name = "app-\(stamp)\(ending).db"
        var counter = 2
        while taken(name) {
            name = "app-\(stamp)-\(counter)\(ending).db"
            counter += 1
        }
        return name
    }

    /// `yyyyMMdd'T'HHmmss'Z'` in UTC.
    static func timestamp(_ date: Date) -> String {
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d%02d%02dT%02d%02d%02dZ", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
                      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
    }

    /// The time a `timestamp` names; nil for one that names no real time.
    static func date(fromStamp stamp: String) -> Date? {
        let digits = Array(stamp.utf8)
        func number(_ range: Range<Int>) -> Int? { Int(String(decoding: digits[range], as: UTF8.self)) }
        guard digits.count == 16, let year = number(0..<4), let month = number(4..<6), let day = number(6..<8),
              let hour = number(9..<11), let minute = number(11..<13), let second = number(13..<15) else { return nil }
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let date = utc.date(from: parts),
              utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date) == parts else { return nil }
        return date
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// What a file is read and written in.
    static let chunkSize = 1 << 20
}

/// A SHA-256 of rows, each value with its type and length, so no two different rows read alike.
private struct RowDigest {
    private var hash = SHA256()

    mutating func add(_ row: [SQLiteValue]) {
        var bytes: [UInt8] = []
        append(UInt64(row.count), to: &bytes)
        for value in row {
            switch value {
            case .null:
                bytes.append(0)
            case .integer(let integer):
                bytes.append(1)
                append(UInt64(bitPattern: integer), to: &bytes)
            case .real(let real):
                bytes.append(2)
                append(real.bitPattern, to: &bytes)
            case .text(let text):
                bytes.append(3)
                append(UInt64(text.utf8.count), to: &bytes)
                bytes.append(contentsOf: text.utf8)
            case .blob(let blob):
                bytes.append(4)
                append(UInt64(blob.count), to: &bytes)
                bytes.append(contentsOf: blob)
            }
        }
        hash.update(data: bytes)
    }

    var hex: String { hash.finalize().map { String(format: "%02x", $0) }.joined() }

    private func append(_ value: UInt64, to bytes: inout [UInt8]) {
        withUnsafeBytes(of: value.bigEndian) { bytes.append(contentsOf: $0) }
    }
}
