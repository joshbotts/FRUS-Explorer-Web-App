// An admin's recovery action (PLAN's S20d): erase one user's research, every row the store keeps of
// theirs in the 23 model types' tables, with their rows of `user_search` and the tag assignments the
// kit's search reads, their stored keys and the project they worked in, after a confirmation that
// names the counts. Their account stays as it was, with its name, role, password and sessions, and so
// do the jobs' rows that name them, which hold none of their research. Written once, on
// `RelationalUserStore`, in SQL both stores read; the erasure moves the search mark, so no search kept
// from before it is given again.

import Foundation

/// What an erasure removes, table by table.
public protocol ResearchErasureStore: Sendable {
    /// How many rows of the user's each table an erasure would remove: each of the 23 model types'
    /// tables a user keeps rows in (`UserStoreSchema.erased`), and `secrets`. A user the store does not
    /// hold is `AccountStoreError.notFound`.
    func researchHoldings(of user: String) throws -> [String: Int]
    /// Removes them, in one transaction, if what the user holds is still `expected`, the holdings the
    /// confirmation named; else `ResearchErasureError.changed`, with what they hold now, and nothing is
    /// removed. Gives what it removed.
    @discardableResult
    func eraseResearch(of user: String, expected: [String: Int]) throws -> [String: Int]
}

public enum ResearchErasureError: Error, Equatable, CustomStringConvertible {
    /// The user's holdings changed since they were counted: these are what they hold now.
    case changed([String: Int])

    public var description: String { "The user's research changed since it was counted." }
}

extension UserStoreSchema {
    /// The tables an erasure of one user's research empties of their rows: every user table of the 23
    /// (`Scope.user`); the two instance-wide corrections are every user's.
    public static var erased: [Table] { tables.filter { $0.scope == .user } }
}

extension RelationalUserStore: ResearchErasureStore {
    /// The stored keys' table, which an erasure empties of the user's rows too (S20c).
    public static let secretsTable = "secrets"

    public func researchHoldings(of user: String) throws -> [String: Int] {
        try reading { db in try Self.holdings(of: user, in: db) }
    }

    @discardableResult
    public func eraseResearch(of user: String, expected: [String: Int]) throws -> [String: Int] {
        try writing { db in
            let held = try Self.holdings(of: user, in: db)
            guard held == expected else { throw ResearchErasureError.changed(held) }
            for table in UserStoreSchema.erased {
                _ = try db.query("DELETE FROM \(table.name) WHERE user_id = ?", [.text(user)])
            }
            _ = try db.query("DELETE FROM \(Self.secretsTable) WHERE user_id = ?", [.text(user)])
            _ = try db.query("UPDATE users SET active_project_id = NULL WHERE user_id = ?", [.text(user)])
            // What the kit's search reads: app.db's own rows, or the PostgreSQL store's copy of them.
            _ = try db.search.query("DELETE FROM user_search WHERE user_id = ?", [.text(user)])
            try Self.copyTagAssignments(for: user, in: db)
            return held
        }
    }

    private static func holdings(of user: String, in db: UserStoreTransaction) throws -> [String: Int] {
        guard try db.scalar("SELECT 1 FROM users WHERE user_id = ?", [.text(user)]) != nil else {
            throw AccountStoreError.notFound(user)
        }
        var held: [String: Int] = [:]
        for table in UserStoreSchema.erased.map(\.name) + [secretsTable] {
            held[table] = Int(try db.scalar("SELECT count(*) FROM \(table) WHERE user_id = ?", [.text(user)])?.integer ?? 0)
        }
        return held
    }
}
