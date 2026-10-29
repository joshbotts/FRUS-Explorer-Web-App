// A user's collections and their entries (PLAN's S18d): the rows of migration 2's `collections` and
// `collection_entries`, an entry held to its collection by the collection's id, as the Mac keeps its
// `collectionId`. The store keeps the rows, their identity and their consistency: a collection is read
// with its entries, made with them, changed with them in one write, which reads them, asks the API what
// they become and writes only what differs, so a rule that moves, renumbers or removes many entries
// changes all or none; and deleted with them. An entry deleted takes its headnote draft with it, as
// every delete in the app's editors does (`GeneratedSummary.deleteHeadnoteDraft(for:in:)`). What the
// columns hold is the API's, which writes a row as the import writes a Mac's record
// (`MacImport.collection`, `.entry`) and reads one as the export does (`ResearchExport.collection`,
// `.entry`). No collection write changes `user_search` or the tag assignments, a headnote draft being
// no summary the search reads (`UserSearchText.summaryText`), so none moves the search mark.

import Foundation

/// A collection's rows: its own, and its entries' in the order the store took them.
public struct CollectionRows: Sendable, Equatable {
    public var collection: ExportRow
    public var entries: [ExportRow]

    public init(collection: ExportRow, entries: [ExportRow]) {
        self.collection = collection
        self.entries = entries
    }
}

/// What a write makes of a collection's rows, each given whole, by its values with `id` among them,
/// as `ImportRow` gives one.
public struct CollectionChange: Sendable {
    /// The collection's columns. A change keeps the id it holds; a new collection takes this one.
    public var collection: [String: SQLiteValue]
    /// Its entries. One the store holds keeps its row, and only its columns that differ are written;
    /// one whose id the user holds no entry under is added; one held and left out is deleted, with
    /// its headnote draft.
    public var entries: [[String: SQLiteValue]]
    /// Summaries added with the write: the headnote drafts a duplicate's entries take copies of.
    public var addedSummaries: [[String: SQLiteValue]]

    public init(collection: [String: SQLiteValue], entries: [[String: SQLiteValue]], addedSummaries: [[String: SQLiteValue]] = []) {
        self.collection = collection
        self.entries = entries
        self.addedSummaries = addedSummaries
    }
}

/// Where a user's collections and their entries are kept, each the user's alone. A collection's id,
/// and an entry's, is the Mac's, an uppercase `uuidString`, and is found in any letter case.
public protocol CollectionStore: Sendable {
    /// The user's collections and every entry of theirs, each table's rows in the order the store took
    /// them; an entry whose collection they hold none of among them, as an import may leave one.
    func collectionRows(of user: String) throws -> (collections: [ExportRow], entries: [ExportRow])
    /// One of the user's collections with its entries, or nil when they hold none with this id.
    func collectionRows(_ id: String, of user: String) throws -> CollectionRows?
    /// Adds a collection with its entries, and the summaries the change adds, in one write, and answers
    /// its rows. Throws `ResearchRowStoreError`, writing nothing, for a column a table lacks or an id
    /// that is missing or the user's already.
    @discardableResult
    func addCollection(_ change: CollectionChange, for user: String) throws -> CollectionRows
    /// Reads the user's collection with this id and its entries inside one write, asks `change` what
    /// they become, nil for nothing, writes what differs, and answers the rows as they then stand; nil
    /// when the user has no such collection, writing nothing. What `change` throws rolls the write back.
    @discardableResult
    func changeCollection(_ id: String, for user: String,
                          _ change: @Sendable (CollectionRows) throws -> CollectionChange?) throws -> CollectionRows?
    /// Deletes the user's collection with this id, its entries and their headnote drafts, as the app's
    /// Collections list deletes one; whether there was one.
    @discardableResult
    func deleteCollection(_ id: String, for user: String) throws -> Bool
    /// The user's collections that hold the document as one of their documents, a `document` entry, as
    /// the Research rail's Collections section reads them (`membershipPredicate`), in the store's order.
    func collections(holding volumeId: String, _ documentId: String, of user: String) throws -> [ExportRow]
}

extension RelationalUserStore: CollectionStore {
    static let collectionsTable = UserStoreSchema.tables.first { $0.name == "collections" }!
    static let entriesTable = UserStoreSchema.tables.first { $0.name == "collection_entries" }!
    static let summariesTable = UserStoreSchema.tables.first { $0.name == "summaries" }!

    public func collectionRows(of user: String) throws -> (collections: [ExportRow], entries: [ExportRow]) {
        try reading { db in
            (try Self.rows(of: Self.collectionsTable, where: "user_id = ?", [.text(user)], in: db),
             try Self.rows(of: Self.entriesTable, where: "user_id = ?", [.text(user)], in: db))
        }
    }

    public func collectionRows(_ id: String, of user: String) throws -> CollectionRows? {
        try reading { db in try Self.collectionRows(id, of: user, in: db) }
    }

    @discardableResult
    public func addCollection(_ change: CollectionChange, for user: String) throws -> CollectionRows {
        try Self.check(change.collection, in: Self.collectionsTable)
        for entry in change.entries { try Self.check(entry, in: Self.entriesTable) }
        for summary in change.addedSummaries { try Self.check(summary, in: Self.summariesTable) }
        guard let id = change.collection["id"]?.text else {
            throw ResearchRowStoreError.invalidId(table: Self.collectionsTable.name, id: nil)
        }
        return try writing(outsideSearch: true) { db in
            guard try Self.row(Self.collectionsTable, id: id, of: user, in: db) == nil else {
                throw ResearchRowStoreError.invalidId(table: Self.collectionsTable.name, id: id)
            }
            try Self.insert(change.collection, into: Self.collectionsTable, for: user, in: db)
            try Self.insertEntries(change.entries, for: user, in: db)
            try Self.insertSummaries(change.addedSummaries, for: user, in: db)
            guard let rows = try Self.collectionRows(id, of: user, in: db) else {
                throw ResearchRowStoreError.invalidId(table: Self.collectionsTable.name, id: id)
            }
            return rows
        }
    }

    @discardableResult
    public func changeCollection(_ id: String, for user: String,
                                 _ change: @Sendable (CollectionRows) throws -> CollectionChange?) throws -> CollectionRows? {
        try writing(outsideSearch: true) { db in
            guard let held = try Self.collectionRows(id, of: user, in: db) else { return nil }
            guard let made = try change(held) else { return held }
            try Self.check(made.collection, in: Self.collectionsTable)
            for entry in made.entries { try Self.check(entry, in: Self.entriesTable) }
            for summary in made.addedSummaries { try Self.check(summary, in: Self.summariesTable) }
            let collectionId = held.collection.values["id"] ?? .null

            let changed = Self.differing(made.collection, from: held.collection.values)
            if !changed.isEmpty, let key = collectionId.text {
                _ = try Self.update(Self.collectionsTable, id: key, changed, of: user, in: db)
            }

            // An entry is the held one with its id in any letter case, as the store finds a row.
            var heldEntries: [String: ExportRow] = [:]
            for entry in held.entries {
                if let entryId = entry.values["id"]?.text { heldEntries[UserSearchText.uuidString(entryId)] = entry }
            }
            var kept = Set<String>()
            var added: [[String: SQLiteValue]] = []
            for entry in made.entries {
                guard let entryId = entry["id"]?.text else {
                    throw ResearchRowStoreError.invalidId(table: Self.entriesTable.name, id: nil)
                }
                let key = UserSearchText.uuidString(entryId)
                guard let existing = heldEntries[key] else {
                    added.append(entry)
                    continue
                }
                kept.insert(key)
                let differing = Self.differing(entry, from: existing.values)
                if !differing.isEmpty, let stored = existing.values["id"]?.text {
                    _ = try Self.update(Self.entriesTable, id: stored, differing, of: user, in: db)
                }
            }
            for (key, entry) in heldEntries where !kept.contains(key) {
                try Self.deleteEntry(entry, of: user, in: db)
            }
            try Self.insertEntries(added, for: user, in: db)
            try Self.insertSummaries(made.addedSummaries, for: user, in: db)
            return try Self.collectionRows(id, of: user, in: db)
        }
    }

    @discardableResult
    public func deleteCollection(_ id: String, for user: String) throws -> Bool {
        try writing(outsideSearch: true) { db in
            guard let held = try Self.collectionRows(id, of: user, in: db) else { return false }
            for entry in held.entries { try Self.deleteEntry(entry, of: user, in: db) }
            _ = try db.query("DELETE FROM collections WHERE user_id = ? AND id = ?", [.text(user), held.collection.values["id"] ?? .null])
            return true
        }
    }

    public func collections(holding volumeId: String, _ documentId: String, of user: String) throws -> [ExportRow] {
        try reading { db in
            try Self.rows(of: Self.collectionsTable, where: """
                user_id = ? AND upper(id) IN (SELECT upper(collection_id) FROM collection_entries
                    WHERE user_id = ? AND volume_id = ? AND document_id = ? AND kind = 'document')
                """, [.text(user), .text(user), .text(volumeId), .text(documentId)], in: db)
        }
    }

    // MARK: Within a transaction

    /// The user's collection with this id in any letter case, and the entries that name it, in any
    /// letter case, in the store's order.
    static func collectionRows(_ id: String, of user: String, in db: UserStoreTransaction) throws -> CollectionRows? {
        guard let collection = try row(collectionsTable, id: id, of: user, in: db) else { return nil }
        let key = UserSearchText.uuidString(collection.values["id"]?.text ?? id)
        let entries = try rows(of: entriesTable, where: "user_id = ? AND upper(collection_id) = ?", [.text(user), .text(key)], in: db)
        return CollectionRows(collection: collection, entries: entries)
    }

    /// The columns of `values` whose value is not the one `held` gives them, never the id.
    static func differing(_ values: [String: SQLiteValue], from held: [String: SQLiteValue]) -> [String: SQLiteValue] {
        values.filter { $0.key != "id" && held[$0.key] != $0.value }
    }

    /// Adds entries, each refused, and the write with it, under an id one of the user's entries holds.
    static func insertEntries(_ entries: [[String: SQLiteValue]], for user: String, in db: UserStoreTransaction) throws {
        for entry in entries {
            guard let id = entry["id"]?.text else { throw ResearchRowStoreError.invalidId(table: entriesTable.name, id: nil) }
            guard try row(entriesTable, id: id, of: user, in: db) == nil else {
                throw ResearchRowStoreError.invalidId(table: entriesTable.name, id: id)
            }
            try insert(entry, into: entriesTable, for: user, in: db)
        }
    }

    /// Adds headnote drafts, each refused, and the write with it, when it is no draft or under an id one
    /// of the user's summaries holds.
    static func insertSummaries(_ summaries: [[String: SQLiteValue]], for user: String, in db: UserStoreTransaction) throws {
        for summary in summaries {
            // A headnote draft alone, which the search does not read, so the write leaves the search mark.
            guard summary["is_headnote_draft"] == .integer(1) else {
                throw ResearchRowStoreError.notAHeadnoteDraft(id: summary["id"]?.text)
            }
            guard let id = summary["id"]?.text else { throw ResearchRowStoreError.invalidId(table: summariesTable.name, id: nil) }
            guard try row(summariesTable, id: id, of: user, in: db) == nil else {
                throw ResearchRowStoreError.invalidId(table: summariesTable.name, id: id)
            }
            try insert(summary, into: summariesTable, for: user, in: db)
        }
    }

    /// Deletes an entry and the headnote draft its `headnote_summary_id` names, as
    /// `GeneratedSummary.deleteHeadnoteDraft(for:in:)` deletes it: the summary with that id that is a
    /// draft, never a document's own summary an entry chose.
    static func deleteEntry(_ entry: ExportRow, of user: String, in db: UserStoreTransaction) throws {
        if let draft = entry.values["headnote_summary_id"]?.text {
            _ = try db.query("DELETE FROM summaries WHERE user_id = ? AND upper(id) = ? AND is_headnote_draft = 1",
                             [.text(user), .text(UserSearchText.uuidString(draft))])
        }
        _ = try db.query("DELETE FROM collection_entries WHERE user_id = ? AND id = ?", [.text(user), entry.values["id"] ?? .null])
    }
}
