// Saved searches, working corpora and volume scopes (PLAN's S17e): each user's rows of the three
// tables migration 2 made for the Mac's `SavedSearch`, `WorkingCorpus` and `CustomVolumeScope`, with
// the Mac's columns. The store keeps the rows and their identity; what the columns hold is the API's,
// which writes a row as the import writes one from a Mac's file (`MacImport`) and reads one as the
// export reads it (`ResearchExport`), both held to the app's source by the parity tests, since a
// search's parameters, a watermark and a corpus's capture are values of the kit's, which this module
// does not compile.

import Foundation

/// One of the three tables a search is saved as, or runs inside.
public enum SearchSetTable: String, Sendable, CaseIterable {
    /// The Mac's `SavedSearch`.
    case savedSearches = "saved_searches"
    /// The Mac's `WorkingCorpus`.
    case workingCorpora = "working_corpora"
    /// The Mac's `CustomVolumeScope`.
    case volumeScopes = "volume_scopes"

    /// The table as `UserStoreSchema` describes it.
    public var table: UserStoreSchema.Table {
        guard let table = UserStoreSchema.tables.first(where: { $0.name == rawValue }) else {
            preconditionFailure("UserStoreSchema has no table \(rawValue)")
        }
        return table
    }
}

/// Why the store refused a row of one of the three tables.
public enum SearchSetStoreError: Error, Equatable, CustomStringConvertible {
    /// A row was given a column its table does not have.
    case unknownColumn(table: String, column: String)
    /// A new row was given no id, or one the user's rows of its table hold already.
    case invalidId(table: String, id: String?)

    public var description: String {
        switch self {
        case .unknownColumn(let table, let column): "\(table) has no column \(column)"
        case .invalidId(let table, let id?): "\(table) holds a row with the id \(id) already"
        case .invalidId(let table, nil): "a row of \(table) needs an id"
        }
    }
}

/// Where a user's saved searches, working corpora and volume scopes are kept: each a row of its table,
/// with its columns by name, the user's alone. A row's id is the Mac's, an uppercase `uuidString`, and
/// is found in any letter case.
public protocol SearchSetStore: Sendable {
    /// The user's rows of `table`, in the order the store took them.
    func searchSets(_ table: SearchSetTable, of user: String) throws -> [ExportRow]
    /// The user's row of `table` with this id, or nil.
    func searchSet(_ table: SearchSetTable, id: String, of user: String) throws -> ExportRow?
    /// Adds a row to the user's: `values` names each column it gives a value, `id` among them, and a
    /// column it leaves out is NULL, as `ImportRow` leaves one. Throws `SearchSetStoreError`, writing
    /// nothing, for a column the table lacks, or an id that is missing or the user's already.
    func addSearchSet(_ table: SearchSetTable, _ values: [String: SQLiteValue], for user: String) throws
    /// Sets the columns `values` names, never the id, on the user's row with this id, and answers the
    /// row as it then stands, or nil when the user has none, writing nothing.
    @discardableResult
    func updateSearchSet(_ table: SearchSetTable, id: String, _ values: [String: SQLiteValue], for user: String) throws -> ExportRow?
    /// Deletes the user's row with this id, and answers whether there was one.
    @discardableResult
    func deleteSearchSet(_ table: SearchSetTable, id: String, for user: String) throws -> Bool
}

extension RelationalUserStore: SearchSetStore {
    public func searchSets(_ table: SearchSetTable, of user: String) throws -> [ExportRow] {
        try reading { db in
            try Self.rows(of: table.table, where: "user_id = ?", [.text(user)], in: db)
        }
    }

    public func searchSet(_ table: SearchSetTable, id: String, of user: String) throws -> ExportRow? {
        try reading { db in try Self.row(table.table, id: id, of: user, in: db) }
    }

    public func addSearchSet(_ table: SearchSetTable, _ values: [String: SQLiteValue], for user: String) throws {
        let schema = table.table
        try Self.check(values, in: schema)
        guard let id = values["id"]?.text else { throw SearchSetStoreError.invalidId(table: schema.name, id: nil) }
        try writing { db in
            guard try Self.row(schema, id: id, of: user, in: db) == nil else {
                throw SearchSetStoreError.invalidId(table: schema.name, id: id)
            }
            let columns = schema.columns.map(\.name)
            let names = ["user_id"] + columns
            _ = try db.query(
                "INSERT INTO \(schema.name) (\(names.joined(separator: ", "))) VALUES (\(names.map { _ in "?" }.joined(separator: ", ")))",
                [.text(user)] + columns.map { values[$0] ?? .null })
        }
    }

    @discardableResult
    public func updateSearchSet(_ table: SearchSetTable, id: String, _ values: [String: SQLiteValue], for user: String) throws -> ExportRow? {
        let schema = table.table
        try Self.check(values, in: schema)
        let columns = schema.columns.map(\.name).filter { $0 != "id" && values[$0] != nil }
        return try writing { db in
            guard let held = try Self.row(schema, id: id, of: user, in: db) else { return nil }
            guard !columns.isEmpty else { return held }
            _ = try db.query(
                "UPDATE \(schema.name) SET \(columns.map { "\($0) = ?" }.joined(separator: ", ")) WHERE user_id = ? AND id = ?",
                columns.map { values[$0] ?? .null } + [.text(user), held.values["id"] ?? .null])
            return try Self.row(schema, id: id, of: user, in: db)
        }
    }

    @discardableResult
    public func deleteSearchSet(_ table: SearchSetTable, id: String, for user: String) throws -> Bool {
        let schema = table.table
        return try writing { db in
            guard let held = try Self.row(schema, id: id, of: user, in: db) else { return false }
            _ = try db.query("DELETE FROM \(schema.name) WHERE user_id = ? AND id = ?", [.text(user), held.values["id"] ?? .null])
            return true
        }
    }

    /// Refuses values for a column `table` lacks.
    private static func check(_ values: [String: SQLiteValue], in table: UserStoreSchema.Table) throws {
        let columns = Set(table.columns.map(\.name))
        if let unknown = values.keys.sorted().first(where: { !columns.contains($0) }) {
            throw SearchSetStoreError.unknownColumn(table: table.name, column: unknown)
        }
    }

    /// The user's row of `table` whose id is `id` in any letter case, the first in the order of the
    /// ids where two differ only in case, as the import finds one.
    private static func row(_ table: UserStoreSchema.Table, id: String, of user: String,
                            in db: UserStoreTransaction) throws -> ExportRow? {
        try rows(of: table, where: "user_id = ? AND upper(id) = ?", [.text(user), .text(UserSearchText.uuidString(id))],
                 order: "id", in: db).first
    }

    private static func rows(of table: UserStoreSchema.Table, where condition: String, _ bindings: [SQLiteValue],
                             order: String = "rowid", in db: UserStoreTransaction) throws -> [ExportRow] {
        let columns = table.columns.map(\.name)
        return try db.query("SELECT rowid, \(columns.joined(separator: ", ")) FROM \(table.name) WHERE \(condition) ORDER BY \(order)",
                            bindings)
            .map { row in
                ExportRow(values: Dictionary(uniqueKeysWithValues: zip(columns, row.dropFirst())), position: row[0].integer ?? 0)
            }
    }
}
