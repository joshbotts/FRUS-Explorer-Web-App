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

/// Why the store refused a row of one of the three tables: the rows' own refusals, since S17f
/// those of every user table keyed by the Mac's id.
public typealias SearchSetStoreError = ResearchRowStoreError

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
        try researchRows(table.table, of: user)
    }

    public func searchSet(_ table: SearchSetTable, id: String, of user: String) throws -> ExportRow? {
        try researchRow(table.table, id: id, of: user)
    }

    public func addSearchSet(_ table: SearchSetTable, _ values: [String: SQLiteValue], for user: String) throws {
        try addResearchRow(table.table, values, for: user, outsideSearch: false)
    }

    @discardableResult
    public func updateSearchSet(_ table: SearchSetTable, id: String, _ values: [String: SQLiteValue], for user: String) throws -> ExportRow? {
        try updateResearchRow(table.table, id: id, values, for: user, outsideSearch: false)
    }

    @discardableResult
    public func deleteSearchSet(_ table: SearchSetTable, id: String, for user: String) throws -> Bool {
        try deleteResearchRow(table.table, id: id, for: user, outsideSearch: false)
    }
}
