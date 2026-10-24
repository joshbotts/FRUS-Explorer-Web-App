// Copies of the user store in /data/backups, made with SQLite's backup API: before each migration
// from S14a, and daily from S14b.

import Foundation

/// A copy of `app.db` that could not be made. The store is left as it was.
public struct UserStoreBackupFailed: Error, CustomStringConvertible {
    public let destination: URL
    public let underlying: any Error

    public var description: String {
        "the user store could not be copied to \(destination.path) (\(underlying)), so it was left as it was"
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
    /// full-text table's through its own tables.
    static func holdTheSame(_ first: URL, _ second: URL) throws -> Bool {
        let one = try SQLiteConnection(first.path, readOnly: true)
        defer { one.close() }
        let other = try SQLiteConnection(SQLiteConnection.immutableURI(second), readOnly: true)
        defer { other.close() }
        let schema = "SELECT type, name, tbl_name, coalesce(sql, '') FROM sqlite_master ORDER BY type, name"
        guard try one.query(schema) == other.query(schema) else { return false }
        for row in try one.query("SELECT name, coalesce(sql, '') FROM sqlite_master WHERE type = 'table'") {
            guard let name = row[0].text else { continue }
            let sql = (row[1].text ?? "").uppercased()
            guard !sql.hasPrefix("CREATE VIRTUAL TABLE") else { continue }
            // A table without rowids reads in its key's order.
            let order = sql.contains("WITHOUT ROWID") ? "" : " ORDER BY rowid"
            let rows = "SELECT * FROM \"\(name.replacingOccurrences(of: "\"", with: "\"\""))\"\(order)"
            guard try one.query(rows) == other.query(rows) else { return false }
        }
        return true
    }

    private static func modified(_ file: URL) -> Date {
        ((try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date) ?? .distantPast
    }

    /// The name of the copy taken before migration `version` runs, such as
    /// `app-20261024T031500Z-before-migration-2.db`: the time first, in UTC, so a folder of copies
    /// lists in the order they were made. A copy already of that name gets a number after the time.
    public static func nameBeforeMigration(_ version: Int, at date: Date, in directory: URL) -> String {
        let stamp = timestamp(date)
        var name = "app-\(stamp)-before-migration-\(version).db"
        var counter = 2
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
            name = "app-\(stamp)-\(counter)-before-migration-\(version).db"
            counter += 1
        }
        return name
    }

    /// `yyyyMMdd'T'HHmmss'Z'` in UTC.
    static func timestamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d%02d%02dT%02d%02d%02dZ", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
                      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
    }
}
