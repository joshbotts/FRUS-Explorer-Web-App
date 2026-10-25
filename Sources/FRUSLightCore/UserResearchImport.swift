// The import of a Mac JSON export (PLAN's S16c), the store's half: the rows an import brings to each
// of the 23 tables, written under the importing user with the Mac's ids, in one transaction. A row the
// store holds is replaced only by a newer copy, and then only in the columns the file's format version
// carries, so what an older file cannot say is never written over; a new row takes the app's default
// for those. An import adds and replaces and never deletes, since the export carries no deletions.
// Last, the user's rows of `user_search` are made again from their notes and summaries.

import Foundation

/// One record an import brings, as a row of its table.
public struct ImportRow: Sendable, Equatable {
    /// What the file says of the row, by column: every column its format version carries.
    public var values: [String: SQLiteValue]
    /// What a new row takes for each other column: the app's default for the property, which the
    /// file's format version cannot carry. A row the store holds keeps its own.
    public var defaults: [String: SQLiteValue]

    public init(values: [String: SQLiteValue], defaults: [String: SQLiteValue] = [:]) {
        self.values = values
        self.defaults = defaults
    }
}

/// What an import brings: by table, each table's rows in the file's order.
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

/// What an import did.
public struct ResearchImportResult: Sendable, Equatable {
    /// By table, for each table the batch named.
    public var counts: [String: ImportCount]
    /// The batch's collections that, once it is written, name a saved search the user does not hold,
    /// in the batch's order: kept with the link as the Mac keeps one whose search was deleted, which
    /// the app reads as "The linked saved search could not be found."
    public var unlinkedCollections: [UnlinkedCollection]
    /// How many documents the user's rows of `user_search` hold text for, once made again.
    public var searchableDocuments: Int

    public init(counts: [String: ImportCount], unlinkedCollections: [UnlinkedCollection], searchableDocuments: Int) {
        self.counts = counts
        self.unlinkedCollections = unlinkedCollections
        self.searchableDocuments = searchableDocuments
    }
}

/// A batch that does not fit the store's tables: a mapping's mistake, so nothing is written.
public enum ResearchImportError: Error, Equatable, CustomStringConvertible {
    case unknownTable(String)
    case unknownColumn(table: String, column: String)
    /// A column a new row must have that neither the file nor a default gives.
    case missingColumn(table: String, column: String)
    /// A row with no id, in a table keyed by one.
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

/// How new a row's copy is: the first of its table's columns that holds a time, by table. A row with
/// none is older than any that has one. A type with no time of change, a highlight or a correction,
/// compares the time it was made, so the store's copy of one is kept.
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
    /// Writes `batch` under `user` in one transaction, as the file names each row: one the store
    /// holds by its key is replaced, in the columns the row's `values` give, only when its copy is
    /// newer by `ImportStamp`; any other is added, with its `defaults` for the rest. An instance-wide
    /// table's rows are the instance's, keyed by id alone. Then the user's rows of `user_search` are
    /// made again from all their notes and summaries. Throws `ResearchImportError`, writing nothing,
    /// for a batch that does not fit the tables.
    func importResearch(_ batch: ResearchImportBatch, for user: String) throws -> ResearchImportResult
}

extension SQLiteUserStore: ResearchImportStore {
    public func importResearch(_ batch: ResearchImportBatch, for user: String) throws -> ResearchImportResult {
        let tables = try Self.check(batch)
        return try writing { db in
            var counts: [String: ImportCount] = [:]
            for table in tables {
                var count = ImportCount()
                for row in batch.rows[table.name] ?? [] {
                    switch try Self.write(row, into: table, for: user, in: db) {
                    case .added: count.added += 1
                    case .replaced: count.replaced += 1
                    case .kept: count.kept += 1
                    }
                }
                counts[table.name] = count
            }
            let unlinked = try Self.unlinkedCollections(among: batch.rows["collections"] ?? [], for: user, in: db)
            return ResearchImportResult(counts: counts, unlinkedCollections: unlinked,
                                        searchableDocuments: try Self.rebuildSearch(for: user, in: db))
        }
    }

    private enum Outcome { case added, replaced, kept }

    /// The batch's tables, in the schema's order, once every row's columns are found to be theirs.
    private static func check(_ batch: ResearchImportBatch) throws -> [UserStoreSchema.Table] {
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

    private static func write(_ row: ImportRow, into table: UserStoreSchema.Table, for user: String,
                              in db: SQLiteConnection) throws -> Outcome {
        // The row's key: `user_id` for a user's table, then the Mac's id in any case, as the store
        // finds one; an instance-wide table's by its id alone.
        var conditions: [String] = []
        var keys: [SQLiteValue] = []
        if table.scope == .user {
            conditions.append("user_id = ?")
            keys.append(.text(user))
        }
        if table.primaryKey.contains("id") {
            conditions.append("upper(id) = ?")
            keys.append(.text(UserSearchText.uuidString(row.values["id"]?.text ?? "")))
        }
        let key = conditions.joined(separator: " AND ")
        let stampColumns = ImportStamp.columns[table.name] ?? []
        let stored = try db.query("SELECT \((stampColumns.isEmpty ? ["1"] : stampColumns).joined(separator: ", ")) FROM \(table.name) WHERE \(key) LIMIT 1",
                                  keys).first
        guard let stored else {
            let columns = table.columns.map(\.name)
            let names = (table.scope == .user ? ["user_id"] : []) + columns
            let values = (table.scope == .user ? [SQLiteValue.text(user)] : [])
                + columns.map { row.values[$0] ?? row.defaults[$0] ?? .null }
            _ = try db.query(
                "INSERT INTO \(table.name) (\(names.joined(separator: ", "))) VALUES (\(names.map { _ in "?" }.joined(separator: ", ")))",
                values)
            return .added
        }
        let storedTime = ImportStamp.time(of: { column in stampColumns.firstIndex(of: column).map { stored[$0] } }, in: table.name)
        let givenTime = ImportStamp.time(of: { row.values[$0] }, in: table.name)
        guard let givenTime, givenTime > (storedTime ?? .distantPast) else { return .kept }
        // Only what the file carries; the id stays as the store spells it.
        let columns = table.columns.map(\.name).filter { $0 != "id" && row.values[$0] != nil }
        _ = try db.query(
            "UPDATE \(table.name) SET \(columns.map { "\($0) = ?" }.joined(separator: ", ")) WHERE \(key)",
            columns.map { row.values[$0] ?? .null } + keys)
        return .replaced
    }

    /// The collections among `rows` that name a saved search the user does not hold.
    private static func unlinkedCollections(among rows: [ImportRow], for user: String,
                                            in db: SQLiteConnection) throws -> [UnlinkedCollection] {
        var unlinked: [UnlinkedCollection] = []
        var seen: Set<String> = []
        for row in rows {
            let id = UserSearchText.uuidString(row.values["id"]?.text ?? "")
            guard seen.insert(id).inserted,
                  let stored = try db.query(
                    """
                    SELECT c.id, c.name FROM collections c
                        WHERE c.user_id = ? AND upper(c.id) = ? AND c.saved_search_id IS NOT NULL
                          AND NOT EXISTS (SELECT 1 FROM saved_searches s
                                              WHERE s.user_id = c.user_id AND upper(s.id) = upper(c.saved_search_id))
                    """, [.text(user), .text(id)]).first else { continue }
            unlinked.append(UnlinkedCollection(id: stored[0].text ?? id, name: stored[1].text ?? ""))
        }
        return unlinked
    }

    /// Makes the user's rows of `user_search` again, one for each document their notes or summaries
    /// name, by `refreshSearch`'s rules. Returns how many rows it wrote.
    private static func rebuildSearch(for user: String, in db: SQLiteConnection) throws -> Int {
        _ = try db.query("DELETE FROM user_search WHERE user_id = ?", [.text(user)])
        let documents = try db.query(
            """
            SELECT volume_id, document_id FROM notes WHERE user_id = ?
            UNION SELECT volume_id, document_id FROM summaries WHERE user_id = ?
            """, [.text(user), .text(user)])
        for document in documents {
            try refreshSearch(of: DocumentKey(volumeId: document[0].text ?? "", documentId: document[1].text ?? ""),
                              for: user, in: db)
        }
        return Int(try db.scalar("SELECT count(*) FROM user_search WHERE user_id = ?", [.text(user)])?.integer ?? 0)
    }
}
