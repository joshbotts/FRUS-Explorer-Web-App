// A minimal SQLite layer over CSQLite: open, execute, query, and the backup API.

import CSQLite
import Foundation

/// A SQLite failure: the result code and SQLite's own message.
public struct SQLiteError: Error, CustomStringConvertible, Sendable, Equatable {
    public let code: Int32
    public let message: String

    public var description: String { "SQLite error \(code): \(message)" }
}

/// One value from a result row.
public enum SQLiteValue: Sendable, Equatable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob([UInt8])

    /// The value as text, converting numbers; nil for NULL and blobs.
    public var text: String? {
        switch self {
        case .text(let s): s
        case .integer(let i): String(i)
        case .real(let d): String(d)
        case .null, .blob: nil
        }
    }

    /// The value as an integer, parsing text; nil when it is not one.
    public var integer: Int64? {
        switch self {
        case .integer(let i): i
        case .text(let s): Int64(s)
        case .real, .null, .blob: nil
        }
    }
}

/// A connection to one SQLite database.
///
/// It opens in serialized threading mode (`SQLITE_OPEN_FULLMUTEX`), so SQLite serializes
/// each call and the connection may be shared between tasks. A sequence of calls, such as a
/// transaction or reading an error after a failure, is not atomic: one owner should drive those.
public final class SQLiteConnection: @unchecked Sendable {
    let handle: OpaquePointer

    /// Opens a path or a `file:` URI.
    public init(_ location: String, readOnly: Bool, create: Bool = false) throws {
        var flags = SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX
        flags |= readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE
        if create { flags |= SQLITE_OPEN_CREATE }
        var db: OpaquePointer?
        let code = sqlite3_open_v2(location, &db, flags, nil)
        guard code == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open \(location)"
            sqlite3_close_v2(db)
            throw SQLiteError(code: code, message: message)
        }
        handle = db
        sqlite3_extended_result_codes(db, 1)
        sqlite3_busy_timeout(db, 5_000)
    }

    /// Opens a file read-only with `immutable=1`: SQLite reads it with no locking and
    /// creates no journal, `-wal` or `-shm` file beside it. The file must not change.
    public static func immutable(_ url: URL) throws -> SQLiteConnection {
        try SQLiteConnection(immutableURI(url), readOnly: true)
    }

    /// The `file:` URI for opening a path read-only and immutable.
    public static func immutableURI(_ url: URL) -> String {
        "\(url.standardizedFileURL.absoluteString)?mode=ro&immutable=1"
    }

    private let closeLock = NSLock()
    private var isOpen = true

    deinit { close() }

    /// Closes the connection now rather than when it is released, for example before the file
    /// is renamed. Safe to call twice; the connection must not be used afterwards.
    public func close() {
        closeLock.lock()
        defer { closeLock.unlock() }
        guard isOpen else { return }
        isOpen = false
        sqlite3_close_v2(handle)
    }

    /// Runs one or more statements that return no rows.
    public func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw lastError() }
    }

    /// Runs a query and returns every row, each as its column values.
    public func query(_ sql: String, _ bindings: [SQLiteValue] = []) throws -> [[SQLiteValue]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else { throw lastError() }
        defer { sqlite3_finalize(stmt) }
        for (index, value) in bindings.enumerated() {
            try bind(value, at: Int32(index + 1), in: stmt)
        }
        var rows: [[SQLiteValue]] = []
        var code = sqlite3_step(stmt)
        while code == SQLITE_ROW {
            let count = sqlite3_column_count(stmt)
            rows.append((0..<count).map { column(stmt, $0) })
            code = sqlite3_step(stmt)
        }
        guard code == SQLITE_DONE else { throw lastError() }
        return rows
    }

    /// The first column of the first row, or nil when there is no row.
    public func scalar(_ sql: String, _ bindings: [SQLiteValue] = []) throws -> SQLiteValue? {
        try query(sql, bindings).first?.first
    }

    /// Whether the schema holds a table or view with this name.
    public func hasObject(named name: String) throws -> Bool {
        try scalar("SELECT 1 FROM sqlite_master WHERE name = ?", [.text(name)]) != nil
    }

    /// Copies this whole database into `destination` with SQLite's backup API, which unlike a
    /// file copy is safe for any database. Each step runs off the cooperative pool. `progress`
    /// receives 0...1. A failure carries the failing step's result code, so a caller can tell a
    /// full disk from a damaged source.
    public func backup(
        into destination: SQLiteConnection,
        pagesPerStep: Int32 = 4_096,
        progress: (Double) async -> Void = { _ in }
    ) async throws {
        guard let raw = sqlite3_backup_init(destination.handle, "main", handle, "main") else {
            throw destination.lastError()
        }
        let backup = BackupHandle(raw)
        var finished = false
        defer { if !finished { sqlite3_backup_finish(raw) } }
        var code: Int32
        repeat {
            code = try await Blocking.run { backup.step(pagesPerStep) }
            let total = sqlite3_backup_pagecount(raw)
            let remaining = sqlite3_backup_remaining(raw)
            if total > 0 { await progress(Double(total - remaining) / Double(total)) }
            if code == SQLITE_BUSY || code == SQLITE_LOCKED { try await Task.sleep(for: .milliseconds(50)) }
        } while code == SQLITE_OK || code == SQLITE_BUSY || code == SQLITE_LOCKED
        finished = true
        sqlite3_backup_finish(raw)
        guard code == SQLITE_DONE else {
            throw SQLiteError(code: code, message: String(cString: sqlite3_errstr(code)))
        }
    }

    /// The SQLite library's version, such as 3.45.1.
    public static var libraryVersion: String { String(cString: sqlite3_libversion()) }

    func lastError() -> SQLiteError {
        SQLiteError(code: sqlite3_extended_errcode(handle), message: String(cString: sqlite3_errmsg(handle)))
    }

    private func bind(_ value: SQLiteValue, at index: Int32, in stmt: OpaquePointer?) throws {
        let code: Int32 =
            switch value {
            case .null: sqlite3_bind_null(stmt, index)
            case .integer(let i): sqlite3_bind_int64(stmt, index, i)
            case .real(let d): sqlite3_bind_double(stmt, index, d)
            case .text(let s): sqlite3_bind_text(stmt, index, s, -1, sqliteTransient)
            case .blob(let b): b.withUnsafeBytes {
                sqlite3_bind_blob(stmt, index, $0.baseAddress, Int32($0.count), sqliteTransient)
            }
            }
        guard code == SQLITE_OK else { throw lastError() }
    }

    private func column(_ stmt: OpaquePointer?, _ index: Int32) -> SQLiteValue {
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_INTEGER: return .integer(sqlite3_column_int64(stmt, index))
        case SQLITE_FLOAT: return .real(sqlite3_column_double(stmt, index))
        case SQLITE_TEXT: return .text(sqlite3_column_text(stmt, index).map { String(cString: $0) } ?? "")
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(stmt, index))
            guard count > 0, let bytes = sqlite3_column_blob(stmt, index) else { return .blob([]) }
            return .blob(Array(UnsafeRawBufferPointer(start: bytes, count: count)))
        default: return .null
        }
    }
}

/// An `sqlite3_backup` handle, stepped on one thread at a time by `backup(into:)`.
private final class BackupHandle: @unchecked Sendable {
    private let raw: OpaquePointer

    init(_ raw: OpaquePointer) { self.raw = raw }

    func step(_ pages: Int32) -> Int32 { sqlite3_backup_step(raw, pages) }
}

/// SQLITE_TRANSIENT: SQLite copies the bound value before the call returns.
private var sqliteTransient: sqlite3_destructor_type { unsafeBitCast(-1, to: sqlite3_destructor_type.self) }
