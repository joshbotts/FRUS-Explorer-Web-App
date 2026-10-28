// v1 interface 3, the user store behind a protocol; and v1 interface 2, corrections as override rows.

import Foundation

/// The users and their data: app.db, SQLite's, and since S14d the PostgreSQL store, SPEC's option B,
/// both `RelationalUserStore`s.
public protocol UserStore: Sendable {
    /// The newest migration applied.
    func schemaVersion() throws -> Int
    /// The user a server with `FRUS_AUTH=none` acts for.
    func singleUserID() throws -> String
    /// The user with this id, or nil when the store has none.
    func user(_ id: String) throws -> UserAccount?
    /// The user a sign-in through a proxy names (PLAN's S14e), made at `time` the first time, with
    /// their id as their name.
    func signedInUser(_ id: String, at time: Date) throws -> UserAccount
}

/// A user the store holds, as its `users` table keeps them.
public struct UserAccount: Sendable, Equatable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

/// A correction of one document's classification, editorial note or document, as the Mac's
/// `DocumentClassificationOverride` records it. As on the Mac, it is kept first as an override row
/// in the user store, and written to the index second (through `IndexWriter`), or applied as an
/// overlay over a read-only index. It is instance-wide: it changes the shared index for every user.
public struct ClassificationOverride: Sendable, Equatable, Codable {
    /// The Mac's id, a UUID's string.
    public var id: String
    public var volumeId: String
    public var documentId: String
    /// The correction: `true` when the document is an editorial note.
    public var isEditorialNote: Bool
    /// What the TEI said when the correction was made, which undoing it restores.
    public var parsedIsEditorialNote: Bool
    /// When it was made, as the store keeps dates: whole milliseconds, in UTC.
    public var createdAt: Date?

    public init(id: String = UUID().uuidString, volumeId: String, documentId: String, isEditorialNote: Bool,
                parsedIsEditorialNote: Bool, createdAt: Date? = Date()) {
        self.id = id
        self.volumeId = volumeId
        self.documentId = documentId
        self.isEditorialNote = isEditorialNote
        self.parsedIsEditorialNote = parsedIsEditorialNote
        self.createdAt = createdAt.map(UserStoreDate.rounded)
    }
}

/// Where corrections are kept before they reach the index.
public protocol CorrectionStore: Sendable {
    /// Records a correction as the app's `DocumentClassificationOverrideStore.setOverride` does,
    /// one per document: a correction of a document that has one updates the newest one's value
    /// and time, keeping its id and what the TEI said, and any other is added as it is. Returns the
    /// correction as stored.
    @discardableResult func record(_ correction: ClassificationOverride) throws -> ClassificationOverride
    /// Every correction, oldest first, one with no time first of all: the order in which the app
    /// applies them, so the newest for a document is the one that holds.
    func classificationOverrides() throws -> [ClassificationOverride]
}

/// `SQLiteUserStore.changeMarker()`'s mark.
public struct UserStoreChangeMarker: Sendable, Equatable {
    let changes: Int64
    let others: Int64
}

/// What opening the store did when it had migrations to apply.
public struct UserStoreMigration: Sendable, Equatable {
    /// The migration the store was at, 0 for a new one.
    public let from: Int
    public let to: Int
    /// The copy taken before migrating, or nil for a new store, which has nothing to copy.
    public let backup: URL?
}

/// A store that could not be opened at this build's schema. The store is left as it was.
public enum UserStoreOpenError: Error, CustomStringConvertible {
    /// The store was made by a newer build.
    case newerThanThisBuild(store: Int, build: Int)
    /// A migration failed and was rolled back.
    case migrationFailed(from: Int, to: Int, backup: URL?, underlying: any Error)
    /// The PostgreSQL store (S14d) was made by a newer build.
    case postgreSQLNewerThanThisBuild(store: Int, build: Int)
    /// One of the PostgreSQL store's migrations failed and was rolled back. Each runs in a transaction
    /// of its own, so those before it stay applied, and the store is left at the one before it.
    case postgreSQLMigrationFailed(leftAt: Int, to: Int, underlying: any Error)

    public var description: String {
        switch self {
        case .newerThanThisBuild(let store, let build):
            return "app.db is at migration \(store), newer than this build's \(build): run the newer image, or restore a backup made before it"
        case .migrationFailed(let from, let to, let backup, let underlying):
            let copy = backup.map { " Its copy from before is \($0.path)." } ?? ""
            return "app.db could not be migrated from \(from) to \(to) (\(underlying)), so it was left at \(from).\(copy)"
        case .postgreSQLNewerThanThisBuild(let store, let build):
            return "The PostgreSQL store is at migration \(store), newer than this build's \(build): run the newer image, or restore the database service's backup from before it"
        case .postgreSQLMigrationFailed(let leftAt, let to, let underlying):
            return "The PostgreSQL store could not be migrated to \(to) (\(underlying)): migration \(leftAt + 1) was rolled back, so it was left at \(leftAt)."
        }
    }
}

/// The user store in `/data/app/app.db`, with numbered, forward-only migrations. Before an existing
/// store is migrated, it is copied into the backups folder; the migrations a start applies run in
/// one transaction, so a failure leaves the store as it was. Its methods are `RelationalUserStore`'s,
/// and it is the database the kit's search attaches.
public final class SQLiteUserStore: RelationalUserStore, @unchecked Sendable {
    private let db: SQLiteConnection
    private let url: URL
    /// Held for each use of the connection. It is shared, and a transaction is a sequence of calls
    /// one caller drives: another caller's statement in between would run inside it, and read what
    /// it has not committed.
    private let access = NSLock()

    /// Opens or creates the store at `url`, migrating it to this build's schema. A copy taken
    /// before a migration goes into `backupsDirectory`.
    public convenience init(url: URL, backupsDirectory: URL) async throws {
        try await self.init(url: url, backupsDirectory: backupsDirectory, migrations: UserStoreMigrations.all,
                            now: Date())
    }

    /// The same, with the migrations given: the tests' way to stop a store at an earlier one, or
    /// to try one that fails.
    init(url: URL, backupsDirectory: URL, migrations: [String], now: Date) async throws {
        let db = try SQLiteConnection(url.path, readOnly: false, create: true)
        try db.execute("PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;")
        self.db = db
        self.url = url
        let migration = try await Self.migrate(db, at: url, to: migrations, backupsDirectory: backupsDirectory, now: now)
        super.init(migration: migration, searchDatabase: url)
    }

    private static func migrate(_ db: SQLiteConnection, at url: URL, to migrations: [String], backupsDirectory: URL,
                                now: Date) async throws -> UserStoreMigration? {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at TEXT NOT NULL
            )
            """)
        let applied = try version(of: db)
        guard applied <= migrations.count else {
            throw UserStoreOpenError.newerThanThisBuild(store: applied, build: migrations.count)
        }
        guard applied < migrations.count else { return nil }

        var backup: URL?
        if applied > 0 {
            // A start that failed to migrate this store as it is has copied it already. Under
            // Compose's restart policy each start tries again, and a copy each time would fill
            // the volume.
            if let earlier = try UserStoreBackup.copy(of: url, before: applied + 1, in: backupsDirectory) {
                backup = earlier
            } else {
                let name = UserStoreBackup.nameBeforeMigration(applied + 1, at: now, in: backupsDirectory)
                backup = try await UserStoreBackup.copy(of: url, into: backupsDirectory, named: name)
            }
        }
        let migrated: Bool
        do {
            // Off for the transaction, as SQLite's procedure for changing a table asks, and checked
            // whole before the commit. The pragma does nothing inside a transaction.
            try db.execute("PRAGMA foreign_keys = OFF")
            defer { try? db.execute("PRAGMA foreign_keys = ON") }
            migrated = try apply(migrations, to: db, from: applied)
        } catch {
            throw UserStoreOpenError.migrationFailed(from: applied, to: migrations.count, backup: backup, underlying: error)
        }
        // Another process migrated the store first: start again from where it left it.
        guard migrated else {
            return try await migrate(db, at: url, to: migrations, backupsDirectory: backupsDirectory, now: now)
        }
        return UserStoreMigration(from: applied, to: migrations.count, backup: backup)
    }

    /// Applies the migrations after `applied` in one transaction. Returns false, changing nothing,
    /// when the store is no longer at `applied` once the write lock is held.
    private static func apply(_ migrations: [String], to db: SQLiteConnection, from applied: Int) throws -> Bool {
        try db.execute("BEGIN IMMEDIATE")
        do {
            guard try version(of: db) == applied else {
                try db.execute("ROLLBACK")
                return false
            }
            for version in (applied + 1)...migrations.count {
                try db.execute(migrations[version - 1])
                _ = try db.query(
                    "INSERT INTO schema_migrations (version, applied_at) VALUES (?, strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))",
                    [.integer(Int64(version))])
            }
            let violations = try db.query("PRAGMA foreign_key_check")
            guard violations.isEmpty else {
                throw SQLiteError(code: 787, message: "\(violations.count) rows would break a foreign key, the first in \(violations[0][0].text ?? "a table")")
            }
            try db.execute("COMMIT")
            return true
        } catch {
            try? db.execute("ROLLBACK")
            throw error
        }
    }

    private static func version(of db: SQLiteConnection) throws -> Int {
        Int(try db.scalar("SELECT coalesce(max(version), 0) FROM schema_migrations")?.integer ?? 0)
    }

    /// The store itself is the database the kit's search attaches, so its `user_search` and tag
    /// assignments are written in the method's own transaction.
    private var transaction: UserStoreTransaction {
        UserStoreTransaction(store: db, search: db, copiesTagAssignments: false)
    }

    /// Runs `body` on the connection, holding `access`.
    override func reading<T>(_ body: (UserStoreTransaction) throws -> T) throws -> T {
        try access.withLock { try body(transaction) }
    }

    /// Runs `body` in one write transaction, holding `access` throughout.
    override func writing<T>(_ body: (UserStoreTransaction) throws -> T) throws -> T {
        try access.withLock {
            try db.execute("BEGIN IMMEDIATE")
            do {
                let value = try body(transaction)
                try db.execute("COMMIT")
                return value
            } catch {
                try? db.execute("ROLLBACK")
                throw error
            }
        }
    }

    /// Runs `body` on the connection itself, holding `access`: the tests' way to trace its statements.
    func withConnection<T>(_ body: (SQLiteConnection) throws -> T) throws -> T {
        try access.withLock { try body(db) }
    }

    /// Whether the store's connection enforces foreign keys, as it does once it is open.
    func enforcesForeignKeys() throws -> Bool {
        try access.withLock { try db.scalar("PRAGMA foreign_keys")?.integer == 1 }
    }

    /// Copies the store into `directory` as `name`, through the backup API: what has been committed.
    public func backUp(into directory: URL, named name: String) async throws -> URL {
        try await UserStoreBackup.copy(of: url, into: directory, named: name)
    }

    /// A mark of how far the store has changed while it has been open (S14b): two that are equal
    /// say that nothing was written in between, so a daily backup need not read the store again to
    /// tell. Two that differ say only that something may have been.
    public func changeMarker() throws -> UserStoreChangeMarker {
        try access.withLock {
            // The rows this connection has written, and a count SQLite moves when another commits.
            UserStoreChangeMarker(changes: try db.scalar("SELECT total_changes()")?.integer ?? 0,
                                  others: try db.scalar("PRAGMA data_version")?.integer ?? 0)
        }
    }
}

/// How the store writes a date: ISO 8601 in UTC with milliseconds, `2026-10-24T03:15:00.000Z`, as
/// SQLite's `strftime('%Y-%m-%dT%H:%M:%fZ')` writes it, so stored dates sort as text and SQLite's
/// date functions read them. The Mac's JSON export writes whole seconds, which this keeps exactly.
public enum UserStoreDate {
    public static func text(_ date: Date) -> String {
        let (seconds, milliseconds) = split(date)
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                       from: Date(timeIntervalSince1970: seconds))
        return String(format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
                      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0, milliseconds)
    }

    /// Reads a stored date, `yyyy-MM-ddTHH:mm:ssZ` with or without `.SSS` before the `Z`; nil for
    /// anything else, a 31 February included.
    public static func date(_ text: String) -> Date? {
        let pattern = /^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.([0-9]{3}))?Z$/
        guard let match = text.wholeMatch(of: pattern),
              let year = Int(match.1), let month = Int(match.2), let day = Int(match.3),
              let hour = Int(match.4), let minute = Int(match.5), let second = Int(match.6) else { return nil }
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        // The calendar carries a day or an hour out of range into the next: refuse what does not
        // read back as it was written.
        guard let whole = utc.date(from: parts),
              utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: whole) == parts else { return nil }
        return compose(whole.timeIntervalSince1970, match.7.flatMap { Int($0) } ?? 0)
    }

    /// `date` to the store's precision, so it reads back equal to what was written.
    public static func rounded(_ date: Date) -> Date {
        let (seconds, milliseconds) = split(date)
        return compose(seconds, milliseconds)
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Whole seconds since 1970 and the milliseconds after them, rounded to the nearest.
    private static func split(_ date: Date) -> (Double, Int) {
        let milliseconds = (date.timeIntervalSince1970 * 1000).rounded()
        let seconds = (milliseconds / 1000).rounded(.down)
        return (seconds, Int(milliseconds - seconds * 1000))
    }

    /// The one computation both `date(_:)` and `rounded(_:)` end in, so their dates are equal.
    private static func compose(_ seconds: Double, _ milliseconds: Int) -> Date {
        Date(timeIntervalSince1970: seconds + Double(milliseconds) / 1000)
    }
}
