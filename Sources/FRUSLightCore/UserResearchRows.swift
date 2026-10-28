// A user's rows of any table migration 2 made for a model type with the Mac's id: listed, found by
// that id in any letter case, added, changed in the columns named alone, and deleted (S17e's saved
// searches, working corpora and volume scopes, and S17f's projects, leads and trail). The store keeps
// the rows and their identity; what the columns hold is the API's, which writes a row as the import
// writes a Mac's record (`MacImport`) and reads one as the export does (`ResearchExport`).

import Foundation

/// Why the store refused a row.
public enum ResearchRowStoreError: Error, Equatable, CustomStringConvertible {
    /// A row was given a column its table does not have.
    case unknownColumn(table: String, column: String)
    /// A new row was given no id, or one the user's rows of its table hold already.
    case invalidId(table: String, id: String?)
    /// The table is not one of a user's tables keyed by the Mac's id.
    case notKeyedById(table: String)

    public var description: String {
        switch self {
        case .unknownColumn(let table, let column): "\(table) has no column \(column)"
        case .invalidId(let table, let id?): "\(table) holds a row with the id \(id) already"
        case .invalidId(let table, nil): "a row of \(table) needs an id"
        case .notKeyedById(let table): "\(table) is not a table of a user's rows keyed by the Mac's id"
        }
    }
}

/// Where a user's rows of a table keyed by the Mac's id are kept, each the user's alone. A row's id is
/// the Mac's, an uppercase `uuidString`, and is found in any letter case.
public protocol ResearchRowStore: Sendable {
    /// The user's rows of `table`, in the order the store took them.
    func researchRows(_ table: UserStoreSchema.Table, of user: String) throws -> [ExportRow]
    /// The user's row of `table` with this id, or nil.
    func researchRow(_ table: UserStoreSchema.Table, id: String, of user: String) throws -> ExportRow?
    /// Adds a row to the user's: `values` names each column it gives a value, `id` among them, and a
    /// column it leaves out is NULL, as `ImportRow` leaves one. Throws `ResearchRowStoreError`, writing
    /// nothing, for a column the table lacks, or an id that is missing or the user's already.
    /// `outsideSearch` says that the table is none the kit's search reads (`writing(outsideSearch:_:)`).
    func addResearchRow(_ table: UserStoreSchema.Table, _ values: [String: SQLiteValue], for user: String,
                        outsideSearch: Bool) throws
    /// Sets the columns `values` names, never the id, on the user's row with this id, and answers the
    /// row as it then stands, or nil when the user has none, writing nothing.
    @discardableResult
    func updateResearchRow(_ table: UserStoreSchema.Table, id: String, _ values: [String: SQLiteValue], for user: String,
                           outsideSearch: Bool) throws -> ExportRow?
    /// Deletes the user's row with this id, and answers whether there was one.
    @discardableResult
    func deleteResearchRow(_ table: UserStoreSchema.Table, id: String, for user: String, outsideSearch: Bool) throws -> Bool
}

extension RelationalUserStore: ResearchRowStore {
    public func researchRows(_ table: UserStoreSchema.Table, of user: String) throws -> [ExportRow] {
        try Self.requireId(table)
        return try reading { db in try Self.rows(of: table, where: "user_id = ?", [.text(user)], in: db) }
    }

    public func researchRow(_ table: UserStoreSchema.Table, id: String, of user: String) throws -> ExportRow? {
        try Self.requireId(table)
        return try reading { db in try Self.row(table, id: id, of: user, in: db) }
    }

    public func addResearchRow(_ table: UserStoreSchema.Table, _ values: [String: SQLiteValue], for user: String,
                               outsideSearch: Bool) throws {
        try Self.requireId(table)
        try Self.check(values, in: table)
        guard let id = values["id"]?.text else { throw ResearchRowStoreError.invalidId(table: table.name, id: nil) }
        try writing(outsideSearch: outsideSearch) { db in
            guard try Self.row(table, id: id, of: user, in: db) == nil else {
                throw ResearchRowStoreError.invalidId(table: table.name, id: id)
            }
            try Self.insert(values, into: table, for: user, in: db)
        }
    }

    @discardableResult
    public func updateResearchRow(_ table: UserStoreSchema.Table, id: String, _ values: [String: SQLiteValue], for user: String,
                                  outsideSearch: Bool) throws -> ExportRow? {
        try Self.requireId(table)
        try Self.check(values, in: table)
        return try writing(outsideSearch: outsideSearch) { db in
            try Self.update(table, id: id, values, of: user, in: db)
        }
    }

    @discardableResult
    public func deleteResearchRow(_ table: UserStoreSchema.Table, id: String, for user: String, outsideSearch: Bool) throws -> Bool {
        try Self.requireId(table)
        return try writing(outsideSearch: outsideSearch) { db in
            guard let held = try Self.row(table, id: id, of: user, in: db) else { return false }
            _ = try db.query("DELETE FROM \(table.name) WHERE user_id = ? AND id = ?", [.text(user), held.values["id"] ?? .null])
            return true
        }
    }

    // MARK: Within a transaction

    /// Refuses a table that is not a user's keyed by the Mac's id, whose name the SQL below takes.
    static func requireId(_ table: UserStoreSchema.Table) throws {
        guard table.scope == .user, table.primaryKey == ["user_id", "id"],
              UserStoreSchema.tables.contains(where: { $0.name == table.name }) else {
            throw ResearchRowStoreError.notKeyedById(table: table.name)
        }
    }

    /// Refuses values for a column `table` lacks.
    static func check(_ values: [String: SQLiteValue], in table: UserStoreSchema.Table) throws {
        let columns = Set(table.columns.map(\.name))
        if let unknown = values.keys.sorted().first(where: { !columns.contains($0) }) {
            throw ResearchRowStoreError.unknownColumn(table: table.name, column: unknown)
        }
    }

    /// Inserts a row of `values`, a column they leave out NULL.
    static func insert(_ values: [String: SQLiteValue], into table: UserStoreSchema.Table, for user: String,
                       in db: UserStoreTransaction) throws {
        let columns = table.columns.map(\.name)
        let names = ["user_id"] + columns
        _ = try db.query(
            "INSERT INTO \(table.name) (\(names.joined(separator: ", "))) VALUES (\(names.map { _ in "?" }.joined(separator: ", ")))",
            [.text(user)] + columns.map { values[$0] ?? .null })
    }

    /// Sets the columns `values` names, never the id, on the user's row with this id, and answers the
    /// row as it then stands, or nil when the user has none.
    static func update(_ table: UserStoreSchema.Table, id: String, _ values: [String: SQLiteValue], of user: String,
                       in db: UserStoreTransaction) throws -> ExportRow? {
        let columns = table.columns.map(\.name).filter { $0 != "id" && values[$0] != nil }
        guard let held = try row(table, id: id, of: user, in: db) else { return nil }
        guard !columns.isEmpty else { return held }
        _ = try db.query(
            "UPDATE \(table.name) SET \(columns.map { "\($0) = ?" }.joined(separator: ", ")) WHERE user_id = ? AND id = ?",
            columns.map { values[$0] ?? .null } + [.text(user), held.values["id"] ?? .null])
        return try row(table, id: id, of: user, in: db)
    }

    /// The user's row of `table` whose id is `id` in any letter case, the first in the order of the
    /// ids where two differ only in case, as the import finds one.
    static func row(_ table: UserStoreSchema.Table, id: String, of user: String,
                    in db: UserStoreTransaction) throws -> ExportRow? {
        try rows(of: table, where: "user_id = ? AND upper(id) = ?", [.text(user), .text(UserSearchText.uuidString(id))],
                 order: "id", in: db).first
    }

    /// `table`'s rows that `condition` holds, in `order`, the store's by default.
    static func rows(of table: UserStoreSchema.Table, where condition: String, _ bindings: [SQLiteValue],
                     order: String = "rowid", limit: Int? = nil, in db: UserStoreTransaction) throws -> [ExportRow] {
        let columns = table.columns.map(\.name)
        let cut = limit.map { " LIMIT \($0)" } ?? ""
        return try db.query("SELECT rowid, \(columns.joined(separator: ", ")) FROM \(table.name) WHERE \(condition) ORDER BY \(order)\(cut)",
                            bindings)
            .map { row in
                ExportRow(values: Dictionary(uniqueKeysWithValues: zip(columns, row.dropFirst())), position: row[0].integer ?? 0)
            }
    }
}
