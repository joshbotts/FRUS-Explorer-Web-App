// The import of a Mac JSON export (PLAN's S16c), the store's half: in one transaction, what the importing user holds
// of the 23 tables is read, given to the import's plan, and what the plan decides is written, each addition a new row
// under the user with the Mac's id and each replacement the columns it names of the row the store holds. Since #1915's
// follow-up the plan is the kit's, `ResearchImportPlan`, which the API's `MacImport` makes from these rows: which
// record is added, replaced or kept, and what a replacement writes, are the kit's to say, and the SQL that writes them
// is the store's own. An import adds and replaces and never deletes, since the export carries no deletions. Last, the
// user's rows of `user_search` are made again from their notes and summaries, and in the PostgreSQL store's local copy
// their tag assignments too.
//
// The batch below, written by `ImportStamp`'s newer-copy rule, is S16e's: the import of a research database exported
// with the owner's writing, whose rules are the web's own (`ResearchDatabaseWriting`).

import Foundation

/// One record an import brings, as a row of its table.
public struct ImportRow: Sendable, Equatable {
    /// What the record says of the row, by column: every column it carries.
    public var values: [String: SQLiteValue]
    /// What a new row takes for each other column: a column the record does not carry, such as a summary's
    /// `source_content_hash`, which no path here writes. A row the store holds keeps its own.
    public var defaults: [String: SQLiteValue]

    public init(values: [String: SQLiteValue], defaults: [String: SQLiteValue] = [:]) {
        self.values = values
        self.defaults = defaults
    }
}

/// One write of an import, as its plan decided: a new row, or the columns of a row the store holds.
public struct ImportWrite: Sendable, Equatable {
    public enum Action: String, Sendable, Equatable { case add, replace }

    public var table: String
    public var action: Action
    /// For a replacement, the row's id as the store spells it, as the rows the plan was given hold it; nil for an
    /// addition, whose id is its row's, and for a replacement of the preferences, which a user has one set of.
    public var id: String?
    /// For an addition, every column of the row, its `values` and its `defaults`; for a replacement, the columns its
    /// `values` name but the id, written over the row the store holds, which keeps the rest, its `defaults` among them.
    public var row: ImportRow

    public init(_ table: String, _ action: Action, id: String? = nil, row: ImportRow) {
        self.table = table
        self.action = action
        self.id = id
        self.row = row
    }
}

/// What an import brings by the newer-copy rule (S16e's): by table, each table's rows in the file's order.
public struct ResearchImportBatch: Sendable, Equatable {
    public var rows: [String: [ImportRow]]

    public init(rows: [String: [ImportRow]] = [:]) {
        self.rows = rows
    }
}

/// What became of one table's rows.
public struct ImportCount: Sendable, Equatable, Codable {
    /// Rows the store did not hold, now written.
    public var added = 0
    /// Rows of which the store held an older copy, now the file's.
    public var replaced = 0
    /// Rows of which the store held a copy as new or newer, kept as it was.
    public var kept = 0

    public init(added: Int = 0, replaced: Int = 0, kept: Int = 0) {
        self.added = added
        self.replaced = replaced
        self.kept = kept
    }

    /// Every row the table was given.
    public var total: Int { added + replaced + kept }
}

/// A collection that names a saved search the user does not hold.
public struct UnlinkedCollection: Sendable, Equatable, Codable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// What an import wrote.
public struct ResearchImportResult: Sendable, Equatable {
    /// By table, the rows added and the rows replaced, each replacement counted once for each row it wrote over.
    public var counts: [String: ImportCount]
    /// How many documents the user's rows of `user_search` hold text for, once made again.
    public var searchableDocuments: Int

    public init(counts: [String: ImportCount], searchableDocuments: Int) {
        self.counts = counts
        self.searchableDocuments = searchableDocuments
    }
}

/// Writes that do not fit the store's tables: a mapping's mistake, so nothing is written.
public enum ResearchImportError: Error, Equatable, CustomStringConvertible {
    case unknownTable(String)
    case unknownColumn(table: String, column: String)
    /// A column a new row must have that neither its values nor its defaults give.
    case missingColumn(table: String, column: String)
    /// A row with no id, in a table keyed by one; or a replacement that names no row, or names one in the
    /// preferences, which a user has one set of.
    case missingId(table: String)

    public var description: String {
        switch self {
        case .unknownTable(let table): "the user store has no table \(table)"
        case .unknownColumn(let table, let column): "\(table) has no column \(column)"
        case .missingColumn(let table, let column): "a new row of \(table) needs \(column)"
        case .missingId(let table): "a row of \(table) has no id"
        }
    }
}

/// How new a row's copy is, by S16e's newer-copy rule: the first of its table's columns that holds a time, by
/// table. A row with none is older than any that has one. A type with no time of change, a highlight or a
/// correction, compares the time it was made, so the store's copy of one is kept. The dates are the ones the kit's
/// `ResearchImportRecord.importStamp` reads, which decides a JSON import's newer copy since #1915's follow-up.
public enum ImportStamp {
    public static let columns: [String: [String]] = [
        "notes": ["last_modified", "created_at"],
        "highlights": ["created_at"],
        "tags": ["last_modified", "created_at"],
        "tag_assignments": ["created_at"],
        "collections": ["last_modified", "created_at"],
        "collection_entries": ["last_modified", "created_at"],
        "projects": ["last_modified", "created_at"],
        "project_leads": ["last_computed_at", "first_surfaced_at"],
        "saved_searches": ["last_modified", "created_at"],
        "working_corpora": ["last_modified", "created_at"],
        "volume_scopes": ["last_modified", "created_at"],
        "trail_reading": ["accessed_at"],
        "trail_search": ["executed_at"],
        "trail_export": ["exported_at"],
        "visit_plans": ["last_modified", "created_at"],
        "visit_documents": ["last_modified", "created_at"],
        "visit_targets": ["last_modified", "created_at"],
        "summaries": ["last_modified", "created_at"],
        "prompts": ["last_modified", "created_at"],
        "annotation_reviews": ["reviewed_at"],
        "preferences": ["updated_at", "created_at"],
        "person_overrides": ["created_at"],
        "classification_overrides": ["created_at"],
    ]

    /// The time `values` give a row of `table`, or nil.
    public static func time(of values: (String) -> SQLiteValue?, in table: String) -> Date? {
        for column in columns[table] ?? [] {
            if let text = values(column)?.text, let date = UserStoreDate.date(text) { return date }
        }
        return nil
    }
}

/// Where an import's rows are written.
public protocol ResearchImportStore: Sendable {
    /// Imports in one transaction: reads what the import may write over, every column of `user`'s rows of each user
    /// table and of every row of an instance-wide one, each table's in the order the store took them; gives them to
    /// `plan`, which says what to write; writes it, each addition a new row under the user and each replacement the
    /// columns it names of the row it names; then makes the user's rows of `user_search` again from all their notes
    /// and summaries. Throws what `plan` throws, and `ResearchImportError` for writes that do not fit the tables,
    /// writing nothing.
    func importResearch(for user: String, _ plan: (ResearchRows) throws -> [ImportWrite]) throws -> ResearchImportResult
}

extension RelationalUserStore: ResearchImportStore {
    public func importResearch(for user: String, _ plan: (ResearchRows) throws -> [ImportWrite]) throws -> ResearchImportResult {
        try writing { db in
            let writes = try plan(try Self.held(by: user, in: db))
            let tables = try Self.check(writes)
            var byTable: [String: [ImportWrite]] = [:]
            for write in writes { byTable[write.table, default: []].append(write) }
            var counts: [String: ImportCount] = [:]
            for table in tables {
                var count = ImportCount()
                for write in byTable[table.name] ?? [] {
                    switch write.action {
                    case .add:
                        try Self.add(write.row, to: table, for: user, in: db)
                        count.added += 1
                    case .replace:
                        try Self.replace(write.id, in: table, with: write.row.values, for: user, in: db)
                        count.replaced += 1
                    }
                }
                counts[table.name] = count
            }
            return ResearchImportResult(counts: counts, searchableDocuments: try Self.rebuildSearch(for: user, in: db))
        }
    }

    /// Every column of `user`'s rows of each user table and of every row of an instance-wide one, inside the caller's
    /// transaction, each table's in the order the store took them: what an import plans against.
    static func held(by user: String, in db: UserStoreTransaction) throws -> ResearchRows {
        var rows: [String: [ExportRow]] = [:]
        for table in UserStoreSchema.tables {
            rows[table.name] = table.scope == .user
                ? try Self.rows(of: table, where: "user_id = ?", [.text(user)], in: db)
                : try Self.rows(of: table, where: "1 = 1", [], in: db)
        }
        return ResearchRows(rows: rows)
    }

    /// The tables `writes` name, in the schema's order, once every write is found to fit its table: each column one
    /// of its table's; an addition naming every column, and an id in a table keyed by one; a replacement naming the
    /// row it writes over in a table keyed by id, and none in the preferences.
    static func check(_ writes: [ImportWrite]) throws -> [UserStoreSchema.Table] {
        let named = Set(writes.map(\.table))
        for name in named.sorted() where UserStoreSchema.tables.first(where: { $0.name == name }) == nil {
            throw ResearchImportError.unknownTable(name)
        }
        let tables = UserStoreSchema.tables.filter { named.contains($0.name) }
        let byName = Dictionary(uniqueKeysWithValues: tables.map { ($0.name, $0) })
        for write in writes {
            guard let table = byName[write.table] else { continue }
            let columns = Set(table.columns.map(\.name))
            for column in (Array(write.row.values.keys) + Array(write.row.defaults.keys)).sorted() where !columns.contains(column) {
                throw ResearchImportError.unknownColumn(table: table.name, column: column)
            }
            let keyed = table.primaryKey.contains("id")
            switch write.action {
            case .add:
                for column in table.columns where write.row.values[column.name] == nil && write.row.defaults[column.name] == nil {
                    throw ResearchImportError.missingColumn(table: table.name, column: column.name)
                }
                if keyed, write.row.values["id"]?.text == nil { throw ResearchImportError.missingId(table: table.name) }
            case .replace:
                if keyed != (write.id != nil) { throw ResearchImportError.missingId(table: table.name) }
            }
        }
        return tables
    }

    /// Adds `row` to `table`, under `user` in a user table: every column, as `row` gives it, NULL where it gives none.
    static func add(_ row: ImportRow, to table: UserStoreSchema.Table, for user: String, in db: UserStoreTransaction) throws {
        let columns = table.columns.map(\.name)
        let names = (table.scope == .user ? ["user_id"] : []) + columns
        let values = (table.scope == .user ? [SQLiteValue.text(user)] : []) + columns.map { row.values[$0] ?? row.defaults[$0] ?? .null }
        _ = try db.query(
            "INSERT INTO \(table.name) (\(names.joined(separator: ", "))) VALUES (\(names.map { _ in "?" }.joined(separator: ", ")))",
            values)
    }

    /// Sets the columns `values` names, never the id, on the row of `table` the store holds by `id`, as it spells it,
    /// the user's in a user table; with no id, the user's one row of a table keyed by user alone.
    static func replace(_ id: String?, in table: UserStoreSchema.Table, with values: [String: SQLiteValue], for user: String,
                        in db: UserStoreTransaction) throws {
        // A row keyed by id is named by it, or the write would reach every row the other conditions hold.
        guard table.primaryKey.contains("id") == (id != nil) else { throw ResearchImportError.missingId(table: table.name) }
        var conditions: [String] = []
        var keys: [SQLiteValue] = []
        if table.scope == .user {
            conditions.append("user_id = ?")
            keys.append(.text(user))
        }
        if let id {
            conditions.append("id = ?")
            keys.append(.text(id))
        }
        let columns = table.columns.map(\.name).filter { $0 != "id" && values[$0] != nil }
        guard !columns.isEmpty else { return }
        _ = try db.query(
            "UPDATE \(table.name) SET \(columns.map { "\($0) = ?" }.joined(separator: ", ")) WHERE \(conditions.joined(separator: " AND "))",
            columns.map { values[$0] ?? .null } + keys)
    }

    // MARK: S16e's batch, by the newer-copy rule

    /// Writes `batch` under `user` in a transaction of its own by the newer-copy rule (`write(_:tables:for:in:)`), then
    /// makes the user's rows of `user_search` again, as a research database's writing does: the tests seed a store so.
    /// Throws `ResearchImportError`, writing nothing, for a batch that does not fit the tables.
    @discardableResult
    public func importResearch(_ batch: ResearchImportBatch, for user: String) throws -> ResearchImportResult {
        let tables = try Self.check(batch)
        return try writing { db in
            let counts = try Self.write(batch, tables: tables, for: user, in: db)
            return ResearchImportResult(counts: counts, searchableDocuments: try Self.rebuildSearch(for: user, in: db))
        }
    }

    /// Writes the rows of `batch` into `tables`, `check(_:)`'s, inside the caller's transaction, and counts what became
    /// of each table's: a row the store holds by its key is replaced, in the columns the row's `values` give, only when
    /// its copy is newer by `ImportStamp`; any other is added, with its `defaults` for the rest; an instance-wide
    /// table's rows are the instance's, keyed by id alone. The import of an export made with the owner's writing
    /// writes its rows so (S16e).
    static func write(_ batch: ResearchImportBatch, tables: [UserStoreSchema.Table], for user: String,
                      in db: UserStoreTransaction) throws -> [String: ImportCount] {
        var counts: [String: ImportCount] = [:]
        for table in tables {
            var held = try Self.held(in: table, for: user, in: db)
            var count = ImportCount()
            for row in batch.rows[table.name] ?? [] {
                switch try Self.write(row, into: table, for: user, held: &held, in: db) {
                case .added: count.added += 1
                case .replaced: count.replaced += 1
                case .kept: count.kept += 1
                }
            }
            counts[table.name] = count
        }
        return counts
    }

    private enum Outcome { case added, replaced, kept }

    /// A row the store holds: its id as the store spells it, nil for a table keyed by user alone, and its time by
    /// `ImportStamp`.
    private struct Held {
        var id: String?
        var time: Date?
    }

    /// The batch's tables, in the schema's order, once every row's columns are found to be theirs.
    static func check(_ batch: ResearchImportBatch) throws -> [UserStoreSchema.Table] {
        for name in batch.rows.keys where UserStoreSchema.tables.first(where: { $0.name == name }) == nil {
            throw ResearchImportError.unknownTable(name)
        }
        let tables = UserStoreSchema.tables.filter { batch.rows[$0.name] != nil }
        for table in tables {
            let columns = Set(table.columns.map(\.name))
            for row in batch.rows[table.name] ?? [] {
                for column in Array(row.values.keys) + Array(row.defaults.keys) where !columns.contains(column) {
                    throw ResearchImportError.unknownColumn(table: table.name, column: column)
                }
                for column in table.columns where row.values[column.name] == nil && row.defaults[column.name] == nil {
                    throw ResearchImportError.missingColumn(table: table.name, column: column.name)
                }
                if table.primaryKey.contains("id"), row.values["id"]?.text == nil {
                    throw ResearchImportError.missingId(table: table.name)
                }
            }
        }
        return tables
    }

    /// The rows of `table` the store holds, the user's or an instance-wide table's every row, by id as the store
    /// finds one, in any case, or by "" for a table keyed by user alone: read once, so that a row's lookup does not
    /// read the table again however many rows it holds. In the order of their ids, so that where two ids differ only
    /// in case both stores find the same one.
    private static func held(in table: UserStoreSchema.Table, for user: String, in db: UserStoreTransaction) throws -> [String: Held] {
        let stamps = ImportStamp.columns[table.name] ?? []
        let keyed = table.primaryKey.contains("id")
        let columns = (keyed ? ["id"] : []) + stamps
        let rows = try db.query(
            "SELECT \((columns.isEmpty ? ["1"] : columns).joined(separator: ", ")) FROM \(table.name)"
                + (table.scope == .user ? " WHERE user_id = ?" : "") + (keyed ? " ORDER BY id" : ""),
            table.scope == .user ? [.text(user)] : [])
        var held: [String: Held] = [:]
        for row in rows {
            let id = keyed ? row[0].text : nil
            let first = keyed ? 1 : 0
            let time = ImportStamp.time(of: { column in stamps.firstIndex(of: column).map { row[first + $0] } }, in: table.name)
            let key = id.map(UserSearchText.uuidString) ?? ""
            if held[key] == nil { held[key] = Held(id: id, time: time) }
        }
        return held
    }

    private static func write(_ row: ImportRow, into table: UserStoreSchema.Table, for user: String, held: inout [String: Held],
                              in db: UserStoreTransaction) throws -> Outcome {
        let keyed = table.primaryKey.contains("id")
        let key = keyed ? UserSearchText.uuidString(row.values["id"]?.text ?? "") : ""
        let givenTime = ImportStamp.time(of: { row.values[$0] }, in: table.name)
        guard let stored = held[key] else {
            try Self.add(row, to: table, for: user, in: db)
            held[key] = Held(id: row.values["id"]?.text, time: givenTime)
            return .added
        }
        guard let givenTime, givenTime > (stored.time ?? .distantPast) else { return .kept }
        // Only what the row carries, in the row the store holds, by its key as the store spells it.
        try Self.replace(keyed ? stored.id : nil, in: table, with: row.values, for: user, in: db)
        held[key]?.time = givenTime
        return .replaced
    }
}
