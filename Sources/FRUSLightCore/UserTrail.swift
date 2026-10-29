// The research trail and the synced preferences (PLAN's S17f): each user's rows of `trail_reading`,
// `trail_search` and `trail_export`, the Mac's `ReadingHistoryEntry`, `SearchHistoryEntry` and
// `ExportHistoryEntry`, read a page at a time for one project's scope, as the app's
// `HistoryPaneSnapshot.fetch` reads them, and deleted whole, as `HistoryTrailAdmin.deleteAll` deletes
// them; and each user's one row of `preferences`, the Mac's `SyncedPreferences`. A trail row is
// written, and one deleted, through `ResearchRowStore`. None of these is a table the kit's search
// reads, so their writes leave the search mark where it was.

import Foundation

/// One of the trail's three tables.
public enum TrailTable: String, Sendable, CaseIterable {
    /// The documents visited, the Mac's `ReadingHistoryEntry`.
    case reading = "trail_reading"
    /// The searches run, the Mac's `SearchHistoryEntry`.
    case searches = "trail_search"
    /// The collections exported, the Mac's `ExportHistoryEntry`.
    case exports = "trail_export"

    /// The table as `UserStoreSchema` describes it.
    public var table: UserStoreSchema.Table {
        guard let table = UserStoreSchema.tables.first(where: { $0.name == rawValue }) else {
            preconditionFailure("UserStoreSchema has no table \(rawValue)")
        }
        return table
    }

    /// The time a row records, which a page is in the order of, newest first.
    public var timeColumn: String {
        switch self {
        case .reading: "accessed_at"
        case .searches: "executed_at"
        case .exports: "exported_at"
        }
    }
}

/// Which of the trail's rows a page reads, by the project each was recorded under: the app's
/// `HistoryScope`.
public enum TrailScope: Sendable, Equatable {
    /// Every row, whatever project was active when it was recorded.
    case all
    /// Only the rows recorded with no project active.
    case unfiled
    /// Only the rows recorded while the project with this id was active, in any letter case.
    case project(String)
}

/// One page of a trail table: its newest rows in a scope, and how many the scope holds.
public struct TrailPage: Sendable, Equatable {
    public var rows: [ExportRow]
    public var total: Int

    public init(rows: [ExportRow], total: Int) {
        self.rows = rows
        self.total = total
    }
}

/// Where a user's trail is read a page at a time, and deleted whole.
public protocol TrailStore: Sendable {
    /// The user's rows of `table` in `scope`, newest first by the time each records, as the app's
    /// fetch sorted by it in reverse gives them: one with no time last, two of one time the later
    /// written first; at most `limit` of them, with how many the scope holds.
    func trailPage(_ table: TrailTable, of user: String, scope: TrailScope, limit: Int) throws -> TrailPage
    /// How many of the user's trail rows record a time, of the three tables together: the rows a
    /// window of the trail is drawn from (`ResearchTrailSessions.datedActivityCount(in:)`).
    func datedTrailCount(of user: String) throws -> Int
    /// Deletes every row of the user's trail, as `HistoryTrailAdmin.deleteAll` does, and answers how
    /// many of each table's went.
    @discardableResult
    func deleteTrail(of user: String) throws -> [TrailTable: Int]
}

/// Where a user's synced preferences are kept: one row, the Mac's `SyncedPreferences`, which the
/// user has only once something sets it, as the Mac makes its record only when it needs one.
public protocol PreferenceStore: Sendable {
    /// The user's row of `preferences`, or nil when nothing has set it.
    func preferences(of user: String) throws -> ExportRow?
    /// Sets the columns `values` names on the user's preferences and stamps `updated_at` with `time`,
    /// first making their row, with `initial` for every column `values` leaves out, `created_at`
    /// `time` too; and answers the row as it then stands. `merging` gives more columns from the row as
    /// it stands inside the same write, none for a user who has none, so a column a change reads before
    /// it writes, as a list's order is, keeps any change made to it between. Throws
    /// `ResearchRowStoreError.unknownColumn` for a column the table lacks, writing nothing.
    @discardableResult
    func setPreferences(_ values: [String: SQLiteValue], initial: [String: SQLiteValue], for user: String,
                        at time: Date, merging: @Sendable (ExportRow?) throws -> [String: SQLiteValue]) throws -> ExportRow
}

extension PreferenceStore {
    /// `setPreferences(_:initial:for:at:merging:)`, merging nothing.
    @discardableResult
    public func setPreferences(_ values: [String: SQLiteValue], initial: [String: SQLiteValue], for user: String,
                               at time: Date) throws -> ExportRow {
        try setPreferences(values, initial: initial, for: user, at: time, merging: { _ in [:] })
    }
}

extension RelationalUserStore: TrailStore, PreferenceStore {
    public func trailPage(_ table: TrailTable, of user: String, scope: TrailScope, limit: Int) throws -> TrailPage {
        var condition = "user_id = ?"
        var bindings: [SQLiteValue] = [.text(user)]
        switch scope {
        case .all:
            break
        case .unfiled:
            condition += " AND project_id IS NULL"
        case .project(let id):
            condition += " AND upper(project_id) = ?"
            bindings.append(.text(UserSearchText.uuidString(id)))
        }
        return try reading { db in
            let rows = try Self.rows(of: table.table, where: condition, bindings,
                                     order: "\(table.timeColumn) DESC NULLS LAST, rowid DESC", limit: max(0, limit), in: db)
            let total = try db.scalar("SELECT count(*) FROM \(table.rawValue) WHERE \(condition)", bindings)?.integer ?? 0
            return TrailPage(rows: rows, total: Int(total))
        }
    }

    public func datedTrailCount(of user: String) throws -> Int {
        try reading { db in
            try TrailTable.allCases.reduce(0) { total, table in
                total + Int(try db.scalar("SELECT count(*) FROM \(table.rawValue) WHERE user_id = ? AND \(table.timeColumn) IS NOT NULL",
                                          [.text(user)])?.integer ?? 0)
            }
        }
    }

    @discardableResult
    public func deleteTrail(of user: String) throws -> [TrailTable: Int] {
        try writing(outsideSearch: true) { db in
            var counts: [TrailTable: Int] = [:]
            for table in TrailTable.allCases {
                counts[table] = Int(try db.scalar("SELECT count(*) FROM \(table.rawValue) WHERE user_id = ?", [.text(user)])?.integer ?? 0)
                _ = try db.query("DELETE FROM \(table.rawValue) WHERE user_id = ?", [.text(user)])
            }
            return counts
        }
    }

    public func preferences(of user: String) throws -> ExportRow? {
        try reading { db in try Self.preferencesRow(of: user, in: db) }
    }

    @discardableResult
    public func setPreferences(_ values: [String: SQLiteValue], initial: [String: SQLiteValue], for user: String,
                               at time: Date, merging: @Sendable (ExportRow?) throws -> [String: SQLiteValue]) throws -> ExportRow {
        let table = Self.preferencesTable
        try Self.check(values, in: table)
        try Self.check(initial, in: table)
        let stamp = SQLiteValue.text(UserStoreDate.text(UserStoreDate.rounded(time)))
        return try writing(outsideSearch: true) { db in
            let held = try Self.preferencesRow(of: user, in: db)
            let merged = try merging(held)
            try Self.check(merged, in: table)
            let values = values.merging(merged) { $1 }
            if held == nil {
                var first = initial.merging(values) { $1 }
                first["created_at"] = stamp
                first["updated_at"] = stamp
                let columns = table.columns.map(\.name)
                _ = try db.query(
                    "INSERT INTO preferences (user_id, \(columns.joined(separator: ", "))) VALUES (?\(String(repeating: ", ?", count: columns.count)))",
                    [.text(user)] + columns.map { first[$0] ?? .null })
            } else {
                var changed = values.filter { $0.key != "created_at" }
                changed["updated_at"] = stamp
                let columns = table.columns.map(\.name).filter { changed[$0] != nil }
                _ = try db.query("UPDATE preferences SET \(columns.map { "\($0) = ?" }.joined(separator: ", ")) WHERE user_id = ?",
                                 columns.map { changed[$0] ?? .null } + [.text(user)])
            }
            guard let row = try Self.preferencesRow(of: user, in: db) else {
                throw ResearchRowStoreError.invalidId(table: table.name, id: user)
            }
            return row
        }
    }

    private static var preferencesTable: UserStoreSchema.Table {
        guard let table = UserStoreSchema.table(for: "SyncedPreferences") else {
            preconditionFailure("UserStoreSchema has no table for SyncedPreferences")
        }
        return table
    }

    private static func preferencesRow(of user: String, in db: UserStoreTransaction) throws -> ExportRow? {
        try rows(of: preferencesTable, where: "user_id = ?", [.text(user)], in: db).first
    }
}
