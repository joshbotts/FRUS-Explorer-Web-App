// Read-only SQLite access for the index summary, and statement hashing in sqlite3's sha3_query framing.

import CSQLite
import Crypto
import FRUSLightCore
import Foundation

/// A SQLite failure, with the statement that failed.
public struct ParityDatabaseError: Error, CustomStringConvertible, Equatable, Sendable {
    public let code: Int32
    public let message: String
    public let sql: String?

    public var description: String {
        sql.map { "SQLite error \(code): \(message), in \($0)" } ?? "SQLite error \(code): \(message)"
    }
}

/// One value from a result row. Text is decoded from its bytes, so a NUL inside it survives.
enum ParityValue: Equatable, Sendable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob([UInt8])

    var text: String? {
        switch self {
        case .text(let s): s
        case .integer(let i): String(i)
        case .real(let d): String(d)
        case .null, .blob: nil
        }
    }

    var integer: Int64? {
        switch self {
        case .integer(let i): i
        case .text(let s): Int64(s)
        case .real, .null, .blob: nil
        }
    }
}

/// A connection the summary reads through: the index itself, opened read-only and immutable,
/// or an in-memory copy of it for the checks an immutable connection cannot run.
final class ParityDatabase {
    let handle: OpaquePointer

    private init(_ location: String, flags: Int32) throws {
        var db: OpaquePointer?
        let code = sqlite3_open_v2(location, &db, flags, nil)
        guard code == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open \(location)"
            sqlite3_close_v2(db)
            throw ParityDatabaseError(code: code, message: message, sql: nil)
        }
        handle = db
        sqlite3_extended_result_codes(db, 1)
    }

    deinit { sqlite3_close_v2(handle) }

    /// Opens `url` with `mode=ro&immutable=1`: SQLite takes no lock and writes nothing beside it.
    static func immutable(_ url: URL) throws -> ParityDatabase {
        try ParityDatabase(SQLiteConnection.immutableURI(url), flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI)
    }

    /// An empty in-memory database.
    static func memory() throws -> ParityDatabase {
        try ParityDatabase(":memory:", flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
    }

    /// Runs statements that return no rows.
    func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw error(sql) }
    }

    /// Every row of a small result.
    func rows(_ sql: String) throws -> [[ParityValue]] {
        var rows: [[ParityValue]] = []
        try each(sql) { stmt in
            rows.append((0..<sqlite3_column_count(stmt)).map { Self.value(stmt, $0) })
        }
        return rows
    }

    /// The first column of the first row, or nil when there is none.
    func scalar(_ sql: String) throws -> ParityValue? { try rows(sql).first?.first }

    /// The first column of every row, as text.
    func strings(_ sql: String) throws -> [String] { try rows(sql).compactMap { $0.first?.text } }

    /// Copies the whole database into `destination` with the backup API.
    func backup(into destination: ParityDatabase) throws {
        guard let backup = sqlite3_backup_init(destination.handle, "main", handle, "main") else {
            throw destination.error(nil)
        }
        let code = sqlite3_backup_step(backup, -1)
        sqlite3_backup_finish(backup)
        guard code == SQLITE_DONE else {
            throw ParityDatabaseError(code: code, message: String(cString: sqlite3_errstr(code)), sql: nil)
        }
    }

    /// Hashes a query's result as sqlite3's `sha3_query` does, with SHA-256 in place of SHA3-256:
    /// `S<n>:` and the statement's text, then for each row `R` and for each value `N`, `I` or `F`
    /// and its 8 bytes big-endian, or `T<n>:` or `B<n>:` and its bytes. `volumeColumn`, when given,
    /// also hashes each volume's rows under the same `S` frame, keyed by that column's text.
    func digest(_ sql: String, volumeColumn: Int32? = nil) throws -> StatementDigest {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw error(sql) }
        defer { sqlite3_finalize(stmt) }

        let text = sqlite3_sql(stmt).map { Array(UnsafeBufferPointer(start: $0, count: strlen($0))) } ?? []
        var frame = Array("S\(text.count):".utf8)
        frame.append(contentsOf: text.map { UInt8(bitPattern: $0) })
        var whole = SHA256()
        whole.update(data: frame)
        var volumes: [String: (rows: Int, hash: SHA256)] = [:]

        let columns = sqlite3_column_count(stmt)
        var rowCount = 0
        var row: [UInt8] = []
        var code = sqlite3_step(stmt)
        while code == SQLITE_ROW {
            rowCount += 1
            row.removeAll(keepingCapacity: true)
            row.append(UInt8(ascii: "R"))
            for column in 0..<columns { Self.append(stmt, column, to: &row) }
            whole.update(data: row)
            if let volumeColumn {
                let key = Self.value(stmt, volumeColumn).text ?? "(null)"
                if volumes[key] == nil {
                    var hash = SHA256()
                    hash.update(data: frame)
                    volumes[key] = (0, hash)
                }
                volumes[key]!.rows += 1
                volumes[key]!.hash.update(data: row)
            }
            code = sqlite3_step(stmt)
        }
        guard code == SQLITE_DONE else { throw error(sql) }
        return StatementDigest(
            sql: sql, rows: rowCount, sha256: Self.hex(whole.finalize()),
            volumes: volumeColumn == nil ? nil : volumes.mapValues { VolumeDigest(rows: $0.rows, sha256: Self.hex($0.hash.finalize())) })
    }

    // MARK: - Helpers

    private func each(_ sql: String, _ body: (OpaquePointer) throws -> Void) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw error(sql) }
        defer { sqlite3_finalize(stmt) }
        var code = sqlite3_step(stmt)
        while code == SQLITE_ROW {
            try body(stmt)
            code = sqlite3_step(stmt)
        }
        guard code == SQLITE_DONE else { throw error(sql) }
    }

    func error(_ sql: String?) -> ParityDatabaseError {
        ParityDatabaseError(code: sqlite3_extended_errcode(handle), message: String(cString: sqlite3_errmsg(handle)), sql: sql)
    }

    private static func value(_ stmt: OpaquePointer, _ index: Int32) -> ParityValue {
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_INTEGER: return .integer(sqlite3_column_int64(stmt, index))
        case SQLITE_FLOAT: return .real(sqlite3_column_double(stmt, index))
        case SQLITE_TEXT:
            guard let bytes = sqlite3_column_text(stmt, index) else { return .text("") }
            let count = Int(sqlite3_column_bytes(stmt, index))
            return .text(String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self))
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(stmt, index))
            guard count > 0, let bytes = sqlite3_column_blob(stmt, index) else { return .blob([]) }
            return .blob(Array(UnsafeRawBufferPointer(start: bytes, count: count)))
        default: return .null
        }
    }

    /// Appends one value in `sha3_query`'s framing.
    private static func append(_ stmt: OpaquePointer, _ index: Int32, to row: inout [UInt8]) {
        func bigEndian(_ tag: Character, _ bits: UInt64) {
            row.append(UInt8(ascii: tag.unicodeScalars.first!))
            for shift in stride(from: 56, through: 0, by: -8) { row.append(UInt8(truncatingIfNeeded: bits >> UInt64(shift))) }
        }
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_NULL:
            row.append(UInt8(ascii: "N"))
        case SQLITE_INTEGER:
            bigEndian("I", UInt64(bitPattern: sqlite3_column_int64(stmt, index)))
        case SQLITE_FLOAT:
            bigEndian("F", sqlite3_column_double(stmt, index).bitPattern)
        case SQLITE_TEXT:
            let bytes = sqlite3_column_text(stmt, index)
            let count = Int(sqlite3_column_bytes(stmt, index))
            row.append(contentsOf: Array("T\(count):".utf8))
            if count > 0, let bytes { row.append(contentsOf: UnsafeBufferPointer(start: bytes, count: count)) }
        default:
            let bytes = sqlite3_column_blob(stmt, index)
            let count = Int(sqlite3_column_bytes(stmt, index))
            row.append(contentsOf: Array("B\(count):".utf8))
            if count > 0, let bytes { row.append(contentsOf: UnsafeRawBufferPointer(start: bytes, count: count)) }
        }
    }

    static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { byte in
            let hex = String(byte, radix: 16)
            return byte < 16 ? "0" + hex : hex
        }.joined()
    }
}
