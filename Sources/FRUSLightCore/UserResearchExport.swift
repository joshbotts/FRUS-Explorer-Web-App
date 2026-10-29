// The web's export (PLAN's S16d), the store's half: the rows of the tables an export carries, read
// at one moment, so that the file describes the store as it was then, each with its place among its
// table's rows, the order the store took them in, which the export reads as the order the app's
// store fetches its records in. Of the prompts, the researcher's own only, and of a collection's
// entries and a plan's documents and targets, those whose parent the store holds, as the app's export
// carries them. And how many rows of each an export would carry, for the browser app's Contents; and
// the same rows with a few of their columns, for the Research page (S19b).

import Foundation

/// One row as the export reads it.
public struct ExportRow: Sendable, Equatable {
    /// Each of its table's columns, by name.
    public var values: [String: SQLiteValue]
    /// Its rowid: where it stands among its table's rows, in the order the store took them. SQLite
    /// numbers a table's rows so; the PostgreSQL store's tables carry the number as a column.
    public var position: Int64

    public init(values: [String: SQLiteValue], position: Int64) {
        self.values = values
        self.position = position
    }
}

/// The rows of a user's research, by table, each table's in the order the store took them.
public struct ResearchRows: Sendable, Equatable {
    public var rows: [String: [ExportRow]]

    public init(rows: [String: [ExportRow]] = [:]) {
        self.rows = rows
    }

    /// A table's rows, none for a table the read did not include.
    public subscript(table: String) -> [ExportRow] { rows[table] ?? [] }
}

/// Where an export's rows are read.
public protocol ResearchExportStore: Sendable {
    /// The rows of each of `tables` an export of `user`'s carries, read at one moment: a user
    /// table's rows of the user's, an instance-wide table's every row. A name that is none of the
    /// 23 tables is passed over.
    func researchRows(for user: String, tables: Set<String>) throws -> ResearchRows
    /// The same rows of each table `columns` names, with only the columns it names of each, of
    /// those the table has, for a reader that needs a few of them: the Research page (S19b), which
    /// would otherwise read every note's RTF and every summary's text to count them.
    func researchRows(for user: String, columns: [String: Set<String>]) throws -> ResearchRows
    /// How many rows of each of `tables` `researchRows` would read, by table.
    func researchCounts(for user: String, tables: Set<String>) throws -> [String: Int]
}

/// Which of a table's rows an export carries, where it does not carry them all.
public enum ResearchExportRows {
    /// The researcher's own prompts, as the app's exporter carries them (`!isStandard`), never the
    /// standard ones, whose ids each device mints; and the entries of a collection, and the documents
    /// and targets of a plan, the store holds, as the app's exporter reaches them only through their
    /// parent. No path here writes a standard prompt, or leaves a child whose parent is gone.
    public static let conditions: [String: String] = [
        "prompts": "is_standard = 0",
        "collection_entries": held("collections", "collection_entries", "collection_id"),
        "visit_documents": held("visit_plans", "visit_documents", "plan_id"),
        "visit_targets": held("visit_plans", "visit_targets", "plan_id"),
    ]

    /// That the user holds the row of `parents` the row of `table` names in `column`, its id in any case.
    private static func held(_ parents: String, _ table: String, _ column: String) -> String {
        "EXISTS (SELECT 1 FROM \(parents) parent WHERE parent.user_id = \(table).user_id AND upper(parent.id) = upper(\(table).\(column)))"
    }
}

extension RelationalUserStore: ResearchExportStore {
    public func researchRows(for user: String, tables: Set<String>) throws -> ResearchRows {
        try exportRows(for: user, UserStoreSchema.tables.filter { tables.contains($0.name) }.map { ($0, $0.columns.map(\.name)) })
    }

    public func researchRows(for user: String, columns: [String: Set<String>]) throws -> ResearchRows {
        try exportRows(for: user, UserStoreSchema.tables.compactMap { table in
            columns[table.name].map { named in (table, table.columns.map(\.name).filter(named.contains)) }
        })
    }

    /// The rows an export of `user`'s carries of each table, with the columns given for it, in its
    /// own order, read at one moment.
    private func exportRows(for user: String, _ selection: [(table: UserStoreSchema.Table, columns: [String])]) throws -> ResearchRows {
        try reading { db in
            var rows: [String: [ExportRow]] = [:]
            for (table, columns) in selection {
                let (filter, bindings) = Self.exportFilter(table, user: user)
                rows[table.name] = try db.query(
                    "SELECT \((["rowid"] + columns).joined(separator: ", ")) FROM \(table.name)\(filter) ORDER BY rowid", bindings)
                    .map { row in
                        ExportRow(values: Dictionary(uniqueKeysWithValues: zip(columns, row.dropFirst())),
                                  position: row[0].integer ?? 0)
                    }
            }
            return ResearchRows(rows: rows)
        }
    }

    public func researchCounts(for user: String, tables: Set<String>) throws -> [String: Int] {
        try reading { db in
            var counts: [String: Int] = [:]
            for table in UserStoreSchema.tables where tables.contains(table.name) {
                let (filter, bindings) = Self.exportFilter(table, user: user)
                counts[table.name] = Int(try db.scalar("SELECT count(*) FROM \(table.name)\(filter)", bindings)?.integer ?? 0)
            }
            return counts
        }
    }

    /// The `WHERE` clause that picks the rows of `table` an export of `user`'s carries, with its
    /// bindings.
    private static func exportFilter(_ table: UserStoreSchema.Table, user: String) -> (String, [SQLiteValue]) {
        var conditions: [String] = []
        var bindings: [SQLiteValue] = []
        if table.scope == .user {
            conditions.append("user_id = ?")
            bindings.append(.text(user))
        }
        if let condition = ResearchExportRows.conditions[table.name] { conditions.append(condition) }
        return (conditions.isEmpty ? "" : " WHERE " + conditions.joined(separator: " AND "), bindings)
    }
}
