// The user store's methods, written once for its two stores (PLAN's S14d): app.db, SQLite's, and the
// PostgreSQL store, SPEC's option B. Each method runs its statements on a connection either store
// gives, in SQL both read: a `?` for each value bound, NULLs placed by `NULLS FIRST` or `NULLS LAST`
// wherever an order can meet one, since the two place them apart by default, and a row's place among
// its table's rows read as `rowid`, which SQLite keeps for every table and the PostgreSQL store's
// tables carry as a column. Where the two must differ, a statement asks its connection's dialect.

import Foundation
import Synchronization

/// What the kit's search reads of a user store (PLAN's S17d): the SQLite file it attaches for one
/// user's half, and a mark of how far that file has moved, so that an answer computed under one mark
/// may be given again while the mark stands.
public protocol UserSearchStore: Sendable {
    /// The file holding `user_search` and the tag assignments.
    var searchDatabase: URL { get }
    /// A number that moves whenever the store commits a write, and so whenever `searchDatabase` may
    /// hold other rows: two that are equal say that nothing was written between them.
    func searchMark() throws -> Int
}

/// A connection a user store's statements run on: SQLite's to app.db, or one to the PostgreSQL store.
public protocol UserStoreConnection {
    /// Whose SQL it reads, for the few statements the two stores write apart.
    var dialect: UserStoreDialect { get }
    /// Runs one statement, with a value for each `?` in it, and returns every row it gives.
    func query(_ sql: String, _ bindings: [SQLiteValue]) throws -> [[SQLiteValue]]
    /// The first column of the first row a statement gives, or nil when it gives none.
    func scalar(_ sql: String, _ bindings: [SQLiteValue]) throws -> SQLiteValue?
}

/// The SQL a connection reads.
public enum UserStoreDialect: Sendable {
    case sqlite, postgreSQL

    /// Where `needle` first occurs in `haystack`, counting from 1, or 0: SQLite's `instr`, PostgreSQL's
    /// `strpos`.
    func position(of needle: String, in haystack: String) -> String {
        switch self {
        case .sqlite: "instr(\(haystack), \(needle))"
        case .postgreSQL: "strpos(\(haystack), \(needle))"
        }
    }
}

extension SQLiteConnection: UserStoreConnection {
    public var dialect: UserStoreDialect { .sqlite }
}

/// What one of the store's methods runs its statements on: the store's connection, in one transaction
/// for a write, and the SQLite database the kit's search attaches (`RelationalUserStore.searchDatabase`),
/// which holds `user_search` and the tag assignments that search reads. For app.db that database is
/// the store itself. For the PostgreSQL store it is a local copy, written in a transaction of its own
/// beside the store's and committed after it, so a write is in the copy before the method returns.
struct UserStoreTransaction: UserStoreConnection {
    /// The store's connection, which `query` and `scalar` run on.
    let store: any UserStoreConnection
    /// The searchable database's: `store` itself for app.db.
    let search: any UserStoreConnection
    /// Whether `search` is a copy, whose tag assignments are written beside the store's.
    let copiesTagAssignments: Bool

    var dialect: UserStoreDialect { store.dialect }

    func query(_ sql: String, _ bindings: [SQLiteValue]) throws -> [[SQLiteValue]] { try store.query(sql, bindings) }

    func scalar(_ sql: String, _ bindings: [SQLiteValue]) throws -> SQLiteValue? { try store.scalar(sql, bindings) }
}

/// The user store's methods, the same for both of its stores, `SQLiteUserStore` and
/// `PostgreSQLUserStore`. Each store gives its own connection, for a read and for a write
/// transaction, and its own migrations; every method of every store protocol is written once, here and
/// in this class's extensions, so the two answer alike, as the conformance suite holds them. A later
/// row's methods go in an extension of this class, in SQL both read, and their tests in that suite.
public class RelationalUserStore: UserStore, CorrectionStore, UserSearchStore, @unchecked Sendable {
    /// What opening the store applied, or nil when it was already at this build's schema.
    public let migration: UserStoreMigration?
    /// The SQLite file holding `user_search` and the tag assignments, which the kit's search attaches
    /// for one user's half (`SearchUserSource.attachedStore(userId:)`, S17d): app.db itself, or the
    /// PostgreSQL store's local copy.
    public let searchDatabase: URL
    /// How many write transactions the store has committed while it has been open: `searchMark()`.
    private let commits = Mutex(0)

    init(migration: UserStoreMigration?, searchDatabase: URL) {
        self.migration = migration
        self.searchDatabase = searchDatabase
    }

    /// Counts a write transaction committed. Each store's `writing(_:)` calls it once the write is in
    /// `searchDatabase`, before the write's caller is answered, unless the write is one the search
    /// reads nothing of (`writing(outsideSearch:_:)`).
    func didCommit() {
        commits.withLock { $0 += 1 }
    }

    public func searchMark() throws -> Int {
        commits.withLock { $0 }
    }

    /// Runs `body` on the store's connection, for reads: what has been committed. Each store's own.
    func reading<T>(_ body: (UserStoreTransaction) throws -> T) throws -> T {
        preconditionFailure("\(Self.self) reads on a connection of its own")
    }

    /// Runs `body` in one write transaction: committed when it returns, rolled back when it throws, so
    /// a rule that changes several tables changes all or none. Each store's own. Its commit moves the
    /// search mark, but for a write `outsideSearch`: one that changes none of the rows the kit's search
    /// reads, `user_search` and the tag assignments (S17f's trail, preferences and projects), which so
    /// leaves every user's kept searches standing, as a search that read the store again would find
    /// what they hold.
    func writing<T>(outsideSearch: Bool = false, _ body: (UserStoreTransaction) throws -> T) throws -> T {
        preconditionFailure("\(Self.self) writes on a connection of its own")
    }

    // MARK: UserStore

    public func schemaVersion() throws -> Int {
        try reading { db in Int(try db.scalar("SELECT coalesce(max(version), 0) FROM schema_migrations", [])?.integer ?? 0) }
    }

    public func singleUserID() throws -> String { "owner" }

    public func user(_ id: String) throws -> UserAccount? {
        try reading { db in try Self.user(id, in: db) }
    }

    public func signedInUser(_ id: String, at time: Date) throws -> UserAccount {
        if let user = try user(id) { return user }
        return try writing { db in
            _ = try db.query("INSERT INTO users (user_id, display_name, created_at) VALUES (?, ?, ?) ON CONFLICT (user_id) DO NOTHING",
                             [.text(id), .text(id), .text(UserStoreDate.text(time))])
            return try Self.user(id, in: db) ?? UserAccount(id: id, displayName: id)
        }
    }

    private static func user(_ id: String, in db: UserStoreTransaction) throws -> UserAccount? {
        try db.query("SELECT user_id, display_name FROM users WHERE user_id = ?", [.text(id)]).first.map {
            UserAccount(id: $0[0].text ?? id, displayName: $0[1].text ?? "")
        }
    }

    // MARK: CorrectionStore

    private static let overrideColumns = "id, volume_id, document_id, is_editorial_note, parsed_is_editorial_note, created_at"

    @discardableResult
    public func record(_ given: ClassificationOverride) throws -> ClassificationOverride {
        // To the store's precision, so what is returned is what is stored.
        var correction = given
        correction.createdAt = given.createdAt.map(UserStoreDate.rounded)
        let time: SQLiteValue = correction.createdAt.map { .text(UserStoreDate.text($0)) } ?? .null
        return try writing { db in
            // The newest for the document, as the app's fetch sorted by createdAt, newest first,
            // finds it: one with no time last. Two of one time fall to their ids.
            let existing = try db.query(
                """
                SELECT \(Self.overrideColumns) FROM classification_overrides WHERE volume_id = ? AND document_id = ?
                    ORDER BY created_at DESC NULLS LAST, id DESC LIMIT 1
                """,
                [.text(correction.volumeId), .text(correction.documentId)]).first.map(Self.correction)
            var stored = correction
            if let existing {
                stored = existing
                stored.isEditorialNote = correction.isEditorialNote
                stored.createdAt = correction.createdAt
                _ = try db.query("UPDATE classification_overrides SET is_editorial_note = ?, created_at = ? WHERE id = ?",
                                 [.integer(correction.isEditorialNote ? 1 : 0), time, .text(existing.id)])
            } else {
                _ = try db.query(
                    "INSERT INTO classification_overrides (\(Self.overrideColumns)) VALUES (?, ?, ?, ?, ?, ?)",
                    [.text(correction.id), .text(correction.volumeId), .text(correction.documentId),
                     .integer(correction.isEditorialNote ? 1 : 0), .integer(correction.parsedIsEditorialNote ? 1 : 0),
                     time])
            }
            return stored
        }
    }

    public func classificationOverrides() throws -> [ClassificationOverride] {
        try reading { db in
            try db.query("SELECT \(Self.overrideColumns) FROM classification_overrides ORDER BY created_at ASC NULLS FIRST, id", [])
                .map(Self.correction)
        }
    }

    private static func correction(_ row: [SQLiteValue]) -> ClassificationOverride {
        ClassificationOverride(id: row[0].text ?? "", volumeId: row[1].text ?? "", documentId: row[2].text ?? "",
                               isEditorialNote: row[3].integer == 1, parsedIsEditorialNote: row[4].integer == 1,
                               createdAt: row[5].text.flatMap(UserStoreDate.date))
    }
}
