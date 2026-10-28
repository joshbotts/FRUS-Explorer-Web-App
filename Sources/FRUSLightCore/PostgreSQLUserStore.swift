// The PostgreSQL user store (PLAN's S14d), SPEC's option B: app.db's tables, made by the same numbered
// migrations in PostgreSQL's SQL, and app.db's methods, `RelationalUserStore`'s, run on a PostgresNIO
// connection. Search stays on FTS5: `user_search` and the tag assignments the kit's search reads are
// kept in a local SQLite copy, made again from PostgreSQL at each start and written beside each change,
// in the call that makes it, so a change is in the copy before its request is answered. A copy follows
// its own process's writes alone until phase 6's change feed, so one server process serves a store.

import Foundation
import Logging

/// The user store in a PostgreSQL database, with app.db's numbered, forward-only migrations, each in a
/// transaction of its own, and a local copy for search. One connection serves it, held for each call
/// as the SQLite store holds its own, and made again when it has closed; every write transaction
/// takes the store's advisory lock first, as SQLite's `BEGIN IMMEDIATE` takes its write lock, so the
/// rules that read before they write meet no other process's write between, and a read reads one
/// moment of the store. Its backups are the database service's.
public final class PostgreSQLUserStore: RelationalUserStore, @unchecked Sendable {
    private let configuration: PostgreSQLConfiguration
    private let logger: Logger
    /// Held for each use of the connections.
    private let access = NSLock()
    private var connection: PostgreSQLConnection
    /// The local copy's connection.
    private let copy: SQLiteConnection
    /// Set when a change the store took could not be committed to the copy, which is then made again
    /// before the next call.
    private var copyIsStale = false
    private var isClosed = false

    /// Opens the store, migrating it to this build's schema, and makes its local copy at `searchCopy`
    /// from it, in place of any copy there.
    public convenience init(configuration: PostgreSQLConfiguration, searchCopy: URL,
                            logger: Logger = Logger(label: "frus-light.postgresql")) async throws {
        try await self.init(configuration: configuration, searchCopy: searchCopy, migrations: PostgreSQLMigrations.all,
                            logger: logger)
    }

    /// The same, with the migrations given: the tests' way to stop a store at an earlier one, or to
    /// try one that fails.
    init(configuration: PostgreSQLConfiguration, searchCopy: URL, migrations: [[String]],
         logger: Logger = Logger(label: "frus-light.postgresql")) async throws {
        let opened = try await Blocking.run {
            let connection = try PostgreSQLConnection.connect(configuration, logger: logger)
            do {
                let migration = try Self.migrate(connection, to: migrations)
                return Opened(connection: connection, migration: migration, copy: try Self.makeCopy(at: searchCopy, from: connection))
            } catch {
                connection.close()
                throw error
            }
        }
        self.configuration = configuration
        self.logger = logger
        connection = opened.connection
        copy = opened.copy
        super.init(migration: opened.migration, searchDatabase: searchCopy)
    }

    private struct Opened: @unchecked Sendable {
        let connection: PostgreSQLConnection
        let migration: UserStoreMigration?
        let copy: SQLiteConnection
    }

    /// Closes the store's connections. It answers no call after this.
    public func close() {
        access.withLock {
            guard !isClosed else { return }
            isClosed = true
            connection.close()
            copy.close()
        }
    }

    // MARK: Migrations

    /// The advisory lock every write transaction and migration takes first: this number, with the
    /// store's schema's, so that stores in two schemas of one database do not wait for each other.
    private static let lock = "SELECT pg_advisory_xact_lock(1179800915, hashtext(current_schema()))"

    /// Applies the migrations after the store's, each in a transaction of its own that holds the lock.
    private static func migrate(_ db: PostgreSQLConnection, to migrations: [[String]]) throws -> UserStoreMigration? {
        try transaction(on: db) {
            try db.execute("CREATE TABLE IF NOT EXISTS schema_migrations (version BIGINT PRIMARY KEY, applied_at TEXT COLLATE \"C\" NOT NULL)")
        }
        let applied = try version(of: db)
        guard applied <= migrations.count else {
            throw UserStoreOpenError.postgreSQLNewerThanThisBuild(store: applied, build: migrations.count)
        }
        guard applied < migrations.count else { return nil }
        for version in (applied + 1)...migrations.count {
            do {
                try transaction(on: db) {
                    // Another process may have applied it while this one waited for the lock.
                    guard try Self.version(of: db) < version else { return }
                    for statement in migrations[version - 1] { try db.execute(statement) }
                    _ = try db.query(
                        "INSERT INTO schema_migrations (version, applied_at) VALUES (?, to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'))",
                        [.integer(Int64(version))])
                }
            } catch {
                throw UserStoreOpenError.postgreSQLMigrationFailed(leftAt: version - 1, to: migrations.count, underlying: error)
            }
        }
        // A newer build's process may have migrated it further first.
        let reached = try version(of: db)
        guard reached <= migrations.count else {
            throw UserStoreOpenError.postgreSQLNewerThanThisBuild(store: reached, build: migrations.count)
        }
        return UserStoreMigration(from: applied, to: migrations.count, backup: nil)
    }

    private static func version(of db: PostgreSQLConnection) throws -> Int {
        Int(try db.scalar("SELECT coalesce(max(version), 0) FROM schema_migrations", [])?.integer ?? 0)
    }

    /// Runs `body` in a transaction that holds the lock: committed when it returns, rolled back when it throws.
    private static func transaction(on db: PostgreSQLConnection, _ body: () throws -> Void) throws {
        try db.execute("BEGIN")
        do {
            try db.execute(lock)
            try body()
            try db.execute("COMMIT")
        } catch {
            try? db.execute("ROLLBACK")
            throw error
        }
    }

    // MARK: The local copy

    /// The copy's tables: `user_search` as app.db's migration 2 makes it, for the kit's search reads the
    /// copy as it reads app.db, and the tag assignments, with the columns that search reads and the id.
    static let copySchema = """
        CREATE VIRTUAL TABLE user_search USING fts5(
            user_id UNINDEXED,
            document_id UNINDEXED,
            volume_id UNINDEXED,
            summary_text,
            note_text,
            tokenize = 'porter unicode61'
        );
        CREATE TABLE tag_assignments (
            user_id TEXT NOT NULL,
            id TEXT NOT NULL,
            volume_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            PRIMARY KEY (user_id, id)
        );
        CREATE INDEX tag_assignments_by_document ON tag_assignments (user_id, volume_id, document_id);
        CREATE INDEX tag_assignments_by_tag ON tag_assignments (user_id, tag_id);
        """

    /// Makes the copy at `url` from the store, first removing whatever is there, a journal or a `-wal`
    /// left by an earlier process included, which SQLite would otherwise read into the new file.
    private static func makeCopy(at url: URL, from db: PostgreSQLConnection) throws -> SQLiteConnection {
        for suffix in ["", "-wal", "-shm", "-journal"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let copy = try SQLiteConnection(url.path, readOnly: false, create: true)
        do {
            // WAL, as app.db's, so the search's readers never hold up a write.
            try copy.execute("PRAGMA journal_mode = WAL")
            try copy.execute(copySchema)
            try fill(copy, from: db)
            return copy
        } catch {
            copy.close()
            throw error
        }
    }

    /// Writes every user's rows of the copy again from one moment of the store, the copy emptied first.
    private static func fill(_ copy: SQLiteConnection, from db: PostgreSQLConnection) throws {
        try db.execute("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
        do {
            try copy.execute("BEGIN IMMEDIATE")
            do {
                try copy.execute("DELETE FROM user_search; DELETE FROM tag_assignments;")
                let transaction = UserStoreTransaction(store: db, search: copy, copiesTagAssignments: true)
                for row in try db.query("SELECT user_id FROM users ORDER BY user_id", []) {
                    guard let user = row[0].text else { continue }
                    _ = try rebuildSearch(for: user, in: transaction)
                }
                try copy.execute("COMMIT")
            } catch {
                try? copy.execute("ROLLBACK")
                throw error
            }
            try db.execute("COMMIT")
        } catch {
            try? db.execute("ROLLBACK")
            throw error
        }
    }

    // MARK: Calls

    /// The store's connection, made again when it has closed, with the copy made again first if a
    /// change could not reach it.
    private func ready() throws -> PostgreSQLConnection {
        guard !isClosed else { throw PostgreSQLError(message: "the PostgreSQL store is closed") }
        if connection.isClosed {
            logger.notice("The PostgreSQL store's connection closed; connecting again")
            connection = try PostgreSQLConnection.connect(configuration, logger: logger)
        }
        if copyIsStale {
            try Self.fill(copy, from: connection)
            copyIsStale = false
            logger.notice("The local copy of user_search and the tag assignments was made again from the PostgreSQL store")
        }
        return connection
    }

    /// Runs `body` in a read-only transaction, so that its statements all read one moment of the store,
    /// as app.db's one connection does.
    override func reading<T>(_ body: (UserStoreTransaction) throws -> T) throws -> T {
        try access.withLock {
            let db = try ready()
            try db.execute("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
            do {
                let value = try body(UserStoreTransaction(store: db, search: copy, copiesTagAssignments: true))
                try db.execute("COMMIT")
                return value
            } catch {
                try? db.execute("ROLLBACK")
                throw error
            }
        }
    }

    /// Runs `body` in one write transaction holding the lock, with the copy's beside it: the store's is
    /// committed first, then the copy's. A copy that cannot take a change the store has taken is made
    /// again before the next call, and the call is answered as the store answers it.
    override func writing<T>(_ body: (UserStoreTransaction) throws -> T) throws -> T {
        try access.withLock {
            let db = try ready()
            try db.execute("BEGIN")
            let value: T
            var committing = false
            do {
                try db.execute(Self.lock)
                try copy.execute("BEGIN")
                do {
                    value = try body(UserStoreTransaction(store: db, search: copy, copiesTagAssignments: true))
                    committing = true
                    try db.execute("COMMIT")
                } catch {
                    try? copy.execute("ROLLBACK")
                    // A commit that failed may have reached the store, whose connection is then gone.
                    if committing { copyIsStale = true }
                    throw error
                }
            } catch {
                try? db.execute("ROLLBACK")
                throw error
            }
            do {
                try copy.execute("COMMIT")
            } catch {
                try? copy.execute("ROLLBACK")
                copyIsStale = true
                logger.error("The local copy of user_search could not take a change the PostgreSQL store took (\(error)); it is made again before the next call")
            }
            return value
        }
    }
}
