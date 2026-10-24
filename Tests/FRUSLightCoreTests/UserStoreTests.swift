// The user store's migrations (S14a): a new store and one at migration 1 reach this build's
// schema, each existing store is copied before it is migrated, and a failing migration leaves the
// store and its copy as they were.

@testable import FRUSLightCore
import FRUSLightTestSupport
import FTS5Store
import Foundation
import Testing

@Suite struct UserStoreTests {
    static let now = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z

    /// A store left at the first `count` migrations, as a build with only those left it.
    static func store(at count: Int, in directory: TemporaryDirectory) async throws -> SQLiteUserStore {
        try await SQLiteUserStore(url: directory.url.appendingPathComponent("app.db"),
                                  backupsDirectory: directory.url.appendingPathComponent("backups"),
                                  migrations: Array(UserStoreMigrations.all.prefix(count)), now: now)
    }

    static func open(_ directory: TemporaryDirectory, migrations: [String] = UserStoreMigrations.all) async throws -> SQLiteUserStore {
        try await SQLiteUserStore(url: directory.url.appendingPathComponent("app.db"),
                                  backupsDirectory: directory.url.appendingPathComponent("backups"),
                                  migrations: migrations, now: now)
    }

    static func backups(in directory: TemporaryDirectory) throws -> [String] {
        let folder = directory.url.appendingPathComponent("backups")
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    }

    @Test func aNewStoreReachesTheLatestMigrationWithNothingToCopy() async throws {
        let directory = try TemporaryDirectory()
        let store = try await Self.open(directory)
        #expect(try store.schemaVersion() == UserStoreMigrations.all.count)
        #expect(UserStoreMigrations.all.count == 2)
        #expect(store.migration == UserStoreMigration(from: 0, to: 2, backup: nil))
        #expect(try Self.backups(in: directory).isEmpty, "a new store has nothing to copy")
        #expect(try store.singleUserID() == "owner")
        #expect(try store.enforcesForeignKeys(), "on again once the migrations are done")

        let reopened = try await Self.open(directory)
        #expect(reopened.migration == nil, "a store at this build's schema is opened as it is")
        #expect(try Self.backups(in: directory).isEmpty)
    }

    @Test func aStoreAtMigrationOneReachesTwoAfterACopyOfItself() async throws {
        let directory = try TemporaryDirectory()
        let first = try await Self.store(at: 1, in: directory)
        #expect(try first.schemaVersion() == 1)
        let db = try SQLiteConnection(directory.url.appendingPathComponent("app.db").path, readOnly: false)
        _ = try db.query(
            """
            INSERT INTO index_corrections (volume_id, document_id, field, value, recorded_by, recorded_at)
                VALUES ('frus1961-63v06', 'd1', 'is_editorial_note', '1', 'owner', '2026-10-23T12:00:00Z')
            """)
        db.close()
        let before = try StoreDump(directory.url.appendingPathComponent("app.db"))

        let store = try await Self.open(directory)
        #expect(try store.schemaVersion() == 2)
        #expect(try store.enforcesForeignKeys())
        let backup = try #require(store.migration?.backup)
        #expect(store.migration == UserStoreMigration(from: 1, to: 2, backup: backup))
        #expect(backup.lastPathComponent == "app-20261024T000000Z-before-migration-2.db")
        #expect(try Self.backups(in: directory) == [backup.lastPathComponent], "one whole copy, and no partial one")
        #expect(try StoreDump(backup) == before, "the copy is the store at migration 1")

        let tables = try StoreDump(directory.url.appendingPathComponent("app.db")).tables
        #expect(!tables.keys.contains("index_corrections"))
        #expect(tables.keys.contains("classification_overrides"))
        let carried = try store.classificationOverrides()
        #expect(carried.count == 1, "migration 2 carries index_corrections' rows into classification_overrides")
        #expect(carried.first?.volumeId == "frus1961-63v06")
        #expect(carried.first?.documentId == "d1")
        #expect(carried.first?.isEditorialNote == true)
        #expect(carried.first?.parsedIsEditorialNote == false, "the correction asserts what the TEI did not say")
        #expect(carried.first?.createdAt == UserStoreDate.date("2026-10-23T12:00:00Z"))
        let id = try #require(carried.first?.id)
        #expect(id.wholeMatch(of: /[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}/) != nil,
                "a version-4 UUID's string, as Swift writes one: \(id)")
    }

    @Test func aFailingMigrationLeavesTheStoreAndItsCopyAsTheyWere() async throws {
        let directory = try TemporaryDirectory()
        let store = try await Self.open(directory)
        try store.record(ClassificationOverride(volumeId: "frus1894Nicaragua", documentId: "d7", isEditorialNote: false,
                                                parsedIsEditorialNote: true, createdAt: Self.now))
        let url = directory.url.appendingPathComponent("app.db")
        let before = try StoreDump(url)

        // Migration 3 creates a table, changes a row and then fails: all of it is undone.
        let failing = """
            CREATE TABLE added_by_three (a TEXT);
            UPDATE classification_overrides SET is_editorial_note = 1;
            INSERT INTO no_such_table VALUES (1);
            """
        var thrown: (any Error)?
        do {
            _ = try await Self.open(directory, migrations: UserStoreMigrations.all + [failing])
        } catch {
            thrown = error
        }
        let error = try #require(thrown as? UserStoreOpenError)
        guard case .migrationFailed(let from, let to, let backup, _) = error else {
            Issue.record("expected a failed migration, got \(error)")
            return
        }
        #expect(from == 2 && to == 3)
        let copy = try #require(backup)
        #expect(String(describing: error).contains("left at 2"))
        #expect(String(describing: error).contains(copy.path))

        #expect(try StoreDump(url) == before, "the store is as it was")
        #expect(try StoreDump(copy) == before, "and so is its copy")
        let reopened = try await Self.open(directory)
        #expect(try reopened.schemaVersion() == 2)
        #expect(try reopened.classificationOverrides().map(\.isEditorialNote) == [false])
    }

    @Test func aStartThatFailsAgainReusesItsCopyUntilTheStoreChanges() async throws {
        let directory = try TemporaryDirectory()
        let store = try await Self.open(directory)
        let failing = UserStoreMigrations.all + ["INSERT INTO no_such_table VALUES (1);"]
        func failedCopy() async throws -> URL? {
            do {
                _ = try await Self.open(directory, migrations: failing)
            } catch UserStoreOpenError.migrationFailed(_, _, let backup, _) {
                return backup
            }
            Issue.record("the migration did not fail")
            return nil
        }
        // A restart policy starts the server again and again.
        let first = try #require(try await failedCopy())
        #expect(try await failedCopy() == first)
        #expect(try await failedCopy() == first)
        #expect(try Self.backups(in: directory) == [first.lastPathComponent], "one copy of the store as it is")

        try store.record(ClassificationOverride(volumeId: "frus1961-63v06", documentId: "d4", isEditorialNote: true,
                                                parsedIsEditorialNote: false, createdAt: Self.now))
        let second = try #require(try await failedCopy())
        #expect(second != first, "a store that has changed since is copied again")
        #expect(try StoreDump(second) == StoreDump(directory.url.appendingPathComponent("app.db")))
        #expect(try Self.backups(in: directory).count == 2)
    }

    @Test func aForeignKeyAMigrationBreaksFailsIt() async throws {
        let directory = try TemporaryDirectory()
        _ = try await Self.open(directory)
        let url = directory.url.appendingPathComponent("app.db")
        let before = try StoreDump(url)
        let orphan = "INSERT INTO tags (user_id, id, name, created_at, last_modified) VALUES ('nobody', 'T', 'x', NULL, NULL);"
        await #expect(throws: UserStoreOpenError.self) {
            _ = try await Self.open(directory, migrations: UserStoreMigrations.all + [orphan])
        }
        #expect(try StoreDump(url) == before)
    }

    @Test func aMigrationThatRebuildsATableKeepsWhatRefersToIt() async throws {
        let directory = try TemporaryDirectory()
        let store = try await Self.open(directory)
        try store.record(ClassificationOverride(volumeId: "frus1961-63v06", documentId: "d1", isEditorialNote: true,
                                                parsedIsEditorialNote: false, createdAt: Self.now))
        let db = try SQLiteConnection(directory.url.appendingPathComponent("app.db").path, readOnly: false)
        try db.execute("INSERT INTO tags (user_id, id, name) VALUES ('owner', 'A', 'Revisit')")
        db.close()
        // SQLite's procedure for changing a table: make the new one, copy, drop the old, rename.
        // With foreign keys on, dropping users would delete every row that refers to it.
        let rebuild = """
            CREATE TABLE users_new (user_id TEXT PRIMARY KEY, display_name TEXT NOT NULL, created_at TEXT NOT NULL);
            INSERT INTO users_new SELECT user_id, display_name, created_at FROM users;
            DROP TABLE users;
            ALTER TABLE users_new RENAME TO users;
            """
        let rebuilt = try await Self.open(directory, migrations: UserStoreMigrations.all + [rebuild])
        #expect(try rebuilt.schemaVersion() == 3)
        let check = try SQLiteConnection(directory.url.appendingPathComponent("app.db").path, readOnly: true)
        defer { check.close() }
        #expect(try check.query("SELECT user_id, id FROM tags") == [[.text("owner"), .text("A")]],
                "the tag outlives its user's table being rebuilt")
        #expect(try rebuilt.enforcesForeignKeys())
    }

    @Test func aStoreFromANewerBuildIsRefused() async throws {
        let directory = try TemporaryDirectory()
        _ = try await Self.open(directory)
        _ = try await Self.open(directory, migrations: UserStoreMigrations.all + ["CREATE TABLE later (a TEXT);"])
        await #expect(throws: UserStoreOpenError.self) { _ = try await Self.open(directory) }
        #expect(try Self.backups(in: directory).count == 1, "the copy before migration 3, and none for the refusal")
    }

    @Test func aBackupNameAlreadyTakenGetsANumber() async throws {
        let directory = try TemporaryDirectory()
        let store = try await Self.open(directory)
        let folder = directory.url.appendingPathComponent("backups")
        let first = try await store.backUp(into: folder, named: UserStoreBackup.nameBeforeMigration(3, at: Self.now, in: folder))
        let second = try await store.backUp(into: folder, named: UserStoreBackup.nameBeforeMigration(3, at: Self.now, in: folder))
        #expect(first.lastPathComponent == "app-20261024T000000Z-before-migration-3.db")
        #expect(second.lastPathComponent == "app-20261024T000000Z-2-before-migration-3.db")
        #expect(try StoreDump(first) == StoreDump(directory.url.appendingPathComponent("app.db")))
        for name in try Self.backups(in: directory) {
            #expect(!name.hasSuffix(".partial") && !name.hasSuffix("-wal") && !name.hasSuffix("-shm"),
                    "each copy is one self-contained file")
        }
    }

    @Test func correctionsAreOnePerDocumentOldestFirst() async throws {
        let directory = try TemporaryDirectory()
        let store = try await Self.open(directory)
        let early = ClassificationOverride(volumeId: "frus1961-63v06", documentId: "d1", isEditorialNote: true,
                                           parsedIsEditorialNote: false, createdAt: Self.now)
        let later = ClassificationOverride(volumeId: "frus1961-63v06", documentId: "d2", isEditorialNote: true,
                                           parsedIsEditorialNote: false, createdAt: Self.now.addingTimeInterval(0.25))
        try store.record(later)
        try store.record(early)
        // A second correction of d1, made later, with an id and a TEI value of its own.
        let second = ClassificationOverride(volumeId: "frus1961-63v06", documentId: "d1", isEditorialNote: false,
                                            parsedIsEditorialNote: true, createdAt: Self.now.addingTimeInterval(1))
        let stored = try store.record(second)
        var expected = early
        expected.isEditorialNote = false
        expected.createdAt = second.createdAt
        #expect(stored == expected, "it updates d1's value and time, and keeps its id and the TEI's value")
        #expect(try store.classificationOverrides() == [later, expected], "one for each document, oldest first")

        let undated = ClassificationOverride(volumeId: "frus1894Nicaragua", documentId: "d3", isEditorialNote: true,
                                             parsedIsEditorialNote: false, createdAt: nil)
        try store.record(undated)
        let reopened = try await Self.open(directory)
        #expect(try reopened.classificationOverrides() == [undated, later, expected],
                "one with no time is taken as the oldest, as the app's sort takes it")

        var exact = ClassificationOverride(volumeId: "frus1894Nicaragua", documentId: "d5", isEditorialNote: true,
                                           parsedIsEditorialNote: false)
        exact.createdAt = Date(timeIntervalSince1970: 1_792_800_002.123_456)  // the newest
        let returned = try reopened.record(exact)
        #expect(returned.createdAt == UserStoreDate.rounded(exact.createdAt!))
        #expect(try reopened.classificationOverrides().last == returned, "what is returned is what is stored")
    }

    @Test func datesKeepMillisecondsInUTC() {
        let date = Date(timeIntervalSince1970: 1_792_800_000.1234)
        #expect(UserStoreDate.text(date) == "2026-10-24T00:00:00.123Z")
        #expect(UserStoreDate.date("2026-10-24T00:00:00.123Z") == UserStoreDate.rounded(date))
        #expect(UserStoreDate.date(UserStoreDate.text(date)) == UserStoreDate.rounded(date))
        #expect(UserStoreDate.date("2026-10-24T00:00:00Z") == Self.now, "the Mac's JSON export writes whole seconds")
        #expect(UserStoreDate.text(Date(timeIntervalSince1970: 1_792_800_000.9996)) == "2026-10-24T00:00:01.000Z")
        #expect(UserStoreDate.date("2026-10-24 00:00:00") == nil)
        #expect(UserStoreDate.date("2026-02-31T00:00:00Z") == nil, "a day the month does not have")
        #expect(UserStoreDate.date("2026-13-01T00:00:00Z") == nil)
        #expect(UserStoreDate.date("2026-10-24T24:00:00Z") == nil)
        #expect(UserStoreDate.date("٢٠٢٦-10-24T00:00:00Z") == nil, "ASCII digits only")
        #expect(UserStoreDate.date("2024-02-29T23:59:59.999Z") != nil, "a leap day")
    }
}

/// Everything a SQLite file holds that a migration could change: each schema object's SQL and
/// each table's rows, in order. Two dumps are equal when the stores hold the same.
struct StoreDump: Equatable {
    let schema: [String]
    let tables: [String: [[SQLiteValue]]]

    init(_ url: URL) throws {
        let db = try SQLiteConnection(url.path, readOnly: true)
        defer { db.close() }
        schema = try db.query("SELECT type, name, coalesce(sql, '') FROM sqlite_master ORDER BY type, name")
            .map { $0.compactMap(\.text).joined(separator: " | ") }
        var tables: [String: [[SQLiteValue]]] = [:]
        // A virtual table's shadow tables are dumped as tables of their own. A table without rowids
        // reads in its key's order.
        for row in try db.query("SELECT name, sql FROM sqlite_master WHERE type = 'table' AND sql NOT LIKE 'CREATE VIRTUAL TABLE%'") {
            guard let name = row[0].text else { continue }
            let order = (row[1].text ?? "").uppercased().contains("WITHOUT ROWID") ? "" : " ORDER BY rowid"
            tables[name] = try db.query("SELECT * FROM \"\(name)\"\(order)")
        }
        self.tables = tables
    }
}
