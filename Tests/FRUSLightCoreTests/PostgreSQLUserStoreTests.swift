// The PostgreSQL store's own (S14d): its URL, its placeholders, and, with a database to run on, what
// app.db does in its own way: migrations each in a transaction of their own, a local copy for search
// made from the store at each start, a connection made again when it has closed, and writes from two
// processes taken in turn, as SQLite's write lock takes them. The methods themselves are the
// conformance suite's (UserStoreConformanceTests).

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct PostgreSQLConfigurationTests {
    @Test func aURLGivesTheConnectionsSettings() throws {
        let full = try PostgreSQLConfiguration(url: "postgres://frus%2Dweb:p%40ss%3Aword@db.example.org:6543/research%20store?sslmode=verify-ca&sslrootcert=/run/secrets/rds.pem")
        #expect(full == PostgreSQLConfiguration(host: "db.example.org", port: 6543, username: "frus-web", password: "p@ss:word",
                                                database: "research store", tls: .verifyCA, rootCertificates: "/run/secrets/rds.pem"))
        #expect(!full.description.contains("p@ss") && !full.description.contains("p%40ss"), "the log never shows the password")
        #expect(full.description == "postgres://frus-web@db.example.org:6543/research store?sslmode=verify-ca&sslrootcert=/run/secrets/rds.pem")
        let short = try PostgreSQLConfiguration(url: "postgresql://frus@[::1]")
        #expect(short == PostgreSQLConfiguration(host: "::1", port: 5432, username: "frus", password: nil, database: nil, tls: .verifyFull))
        #expect(short.description == "postgres://frus@[::1]:5432/?sslmode=verify-full")
        for mode in PostgreSQLConfiguration.TLSMode.allCases {
            #expect(try PostgreSQLConfiguration(url: "postgres://frus@db/x?sslmode=\(mode.rawValue)").tls == mode)
        }
    }

    /// Anything else is refused, a mode libpq has but this server does not keep among it, so that a
    /// URL never connects with less than it says.
    @Test func anythingElseIsRefused() {
        for url in [
            "", "db.example.org", "http://frus@db.example.org/x", "postgres://db.example.org/x", "postgres://frus@/x",
            "postgres:///x", "postgres://frus@db.example.org:0/x", "postgres://frus@db.example.org/a/b",
            "postgres://frus@db.example.org/x#f", "postgres://frus@db.example.org/x?sslmode=prefer",
            "postgres://frus@db.example.org/x?sslmode=allow", "postgres://frus@db.example.org/x?sslmode=",
            "postgres://frus@db.example.org/x?ssl_mode=disable", "postgres://frus@db.example.org/x?sslrootcert=",
            "postgres://frus@db.example.org/x?options=-csearch_path%3Dx",
        ] {
            #expect(throws: PostgreSQLConfigurationError.self, "\(url)") { try PostgreSQLConfiguration(url: url) }
        }
    }

    /// Each `?` of the SQL both stores read is PostgreSQL's next `$n`, but in a quoted text or name
    /// or a comment.
    @Test func aStatementsPlaceholdersAreNumbered() {
        #expect(PostgreSQLConnection.numbered("SELECT ? , ?") == "SELECT $1 , $2")
        #expect(PostgreSQLConnection.numbered("UPDATE t SET a = ? WHERE b = 'what?' AND \"c?\" = ? -- why?\nAND d = ?")
            == "UPDATE t SET a = $1 WHERE b = 'what?' AND \"c?\" = $2 -- why?\nAND d = $3")
        #expect(PostgreSQLConnection.numbered("SELECT 'it''s?', /* a ? */ ?, 5-?, 6/?") == "SELECT 'it''s?', /* a ? */ $1, 5-$2, 6/$3")
        #expect(PostgreSQLConnection.numbered("SELECT 1 - ? /* * ? */ ?") == "SELECT 1 - $1 /* * ? */ $2")
        #expect(PostgreSQLConnection.numbered("no placeholders") == "no placeholders")
    }
}

@Suite(.enabled(if: TestPostgreSQL.isConfigured, "the PostgreSQL store's own tests need a database: FRUS_TEST_POSTGRES_URL, as scripts/swift --postgres sets"))
struct PostgreSQLUserStoreTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000)
    static let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")

    /// A schema of its own, dropped once `body` is done.
    static func inSchema(_ body: (PostgreSQLConfiguration, TemporaryDirectory) async throws -> Void) async throws {
        let schema = TestPostgreSQL.newSchema()
        defer { try? TestPostgreSQL.drop(schema) }
        try await body(try TestPostgreSQL.configuration(schema: schema), try TemporaryDirectory())
    }

    static func open(_ configuration: PostgreSQLConfiguration, in directory: TemporaryDirectory, copy: String = "user-search.db",
                     migrations: [[String]] = PostgreSQLMigrations.all) async throws -> PostgreSQLUserStore {
        try await PostgreSQLUserStore(configuration: configuration, searchCopy: directory.url.appendingPathComponent(copy),
                                      migrations: migrations)
    }

    /// A store left at migration 1, as a build with only that one would have left it, reaches 2, its
    /// corrections the classification overrides app.db's migration 2 makes of them.
    @Test func aStoreAtMigrationOneReachesTwoWithItsCorrections() async throws {
        try await Self.inSchema { configuration, directory in
            let db = try PostgreSQLConnection.connect(configuration)
            defer { db.close() }
            try db.execute("CREATE TABLE schema_migrations (version BIGINT PRIMARY KEY, applied_at TEXT COLLATE \"C\" NOT NULL)")
            for statement in PostgreSQLMigrations.one { try db.execute(statement) }
            try db.execute("INSERT INTO schema_migrations (version, applied_at) VALUES (1, '2026-10-23T00:00:00Z')")
            try db.execute("""
                INSERT INTO index_corrections (volume_id, document_id, field, value, recorded_by, recorded_at)
                    VALUES ('frus1961-63v06', 'd1', 'is_editorial_note', '1', 'owner', '2026-10-23T12:00:00Z')
                """)

            let store = try await Self.open(configuration, in: directory)
            defer { store.close() }
            #expect(store.migration == UserStoreMigration(from: 1, to: 2, backup: nil), "its backups are the database service's")
            #expect(try store.schemaVersion() == 2 && store.user("owner")?.displayName == "Owner")
            let corrections = try store.classificationOverrides()
            #expect(corrections.count == 1)
            #expect(corrections.first?.isEditorialNote == true && corrections.first?.parsedIsEditorialNote == false)
            #expect(corrections.first.map { UUID(uuidString: $0.id)?.uuidString == $0.id } == true, "an uppercase uuidString")
            #expect(corrections.first?.createdAt == UserStoreDate.date("2026-10-23T12:00:00.000Z"))
            #expect(try db.scalar("SELECT count(*) FROM information_schema.tables WHERE table_schema = current_schema() AND table_name = 'index_corrections'", [])
                == .integer(0))
        }
    }

    /// Each migration runs in a transaction of its own: one that fails is rolled back whole, those
    /// before it stay, and the store says where it was left.
    @Test func aFailingMigrationLeavesTheStoreAtTheOneBefore() async throws {
        try await Self.inSchema { configuration, directory in
            let failing = ["CREATE TABLE later (a TEXT)", "SELECT no_such_function()"]
            await #expect {
                _ = try await Self.open(configuration, in: directory, migrations: PostgreSQLMigrations.all + [failing])
            } throws: { error in
                guard case .postgreSQLMigrationFailed(let leftAt, let to, _) = error as? UserStoreOpenError else { return false }
                return leftAt == 2 && to == 3 && "\(error)".contains("left at 2")
            }
            let store = try await Self.open(configuration, in: directory)
            defer { store.close() }
            #expect(try store.schemaVersion() == 2 && store.migration == nil)
            let db = try PostgreSQLConnection.connect(configuration)
            defer { db.close() }
            #expect(try db.scalar("SELECT count(*) FROM information_schema.tables WHERE table_schema = current_schema() AND table_name = 'later'", [])
                == .integer(0), "the failed migration's first statement is rolled back with it")
        }
    }

    @Test func aStoreANewerBuildMigratedIsRefused() async throws {
        try await Self.inSchema { configuration, directory in
            let newer = try await Self.open(configuration, in: directory, migrations: PostgreSQLMigrations.all + [["CREATE TABLE later (a TEXT)"]])
            newer.close()
            await #expect {
                _ = try await Self.open(configuration, in: directory)
            } throws: { error in
                guard case .postgreSQLNewerThanThisBuild(let store, let build) = error as? UserStoreOpenError else { return false }
                return store == 3 && build == 2
            }
        }
    }

    /// Each start makes the copy again from the store, whatever an earlier process left in its place,
    /// so a row written by another process since is in it.
    @Test func eachStartMakesTheCopyFromTheStore() async throws {
        try await Self.inSchema { configuration, directory in
            let store = try await Self.open(configuration, in: directory)
            let tag = try store.createTag(named: "Laos", for: "owner", at: Self.created)
            try store.setTags([tag.id], of: Self.d1, for: "owner", at: Self.created)
            _ = try UserNoteTests.make(store, "Negotiating.", at: Self.created)
            store.close()
            // Another process's writes, which this copy never saw.
            let rows = try UserStoreRows(postgreSQL: configuration, searchCopy: directory.url.appendingPathComponent("user-search.db"))
            defer { rows.closeConnections() }
            try rows.addUser("reader")
            try rows.addNote("A0000000-0000-4000-8000-0000000000A1", user: "reader", bodyText: "Theirs, written elsewhere.")
            try rows.addAssignment("A0000000-0000-4000-8000-0000000000A2", user: "reader", documentId: "d2", tagId: tag.id)
            // And what a crashed process may leave beside the file.
            try Data("not a journal".utf8).write(to: directory.url.appendingPathComponent("user-search.db-journal"))

            let again = try await Self.open(configuration, in: directory)
            defer { again.close() }
            let copy = try SQLiteConnection(again.searchDatabase.path, readOnly: true)
            defer { copy.close() }
            #expect(try copy.query("SELECT user_id, document_id, note_text FROM user_search ORDER BY user_id") == [
                [.text("owner"), .text("d1"), .text("Negotiating.")], [.text("reader"), .text("d1"), .text("Theirs, written elsewhere.")],
            ])
            #expect(try copy.query("SELECT user_id, document_id, tag_id FROM tag_assignments ORDER BY user_id") == [
                [.text("owner"), .text("d1"), .text(tag.id)], [.text("reader"), .text("d2"), .text(tag.id)],
            ])
            let journal = directory.url.appendingPathComponent("user-search.db-journal")
            #expect(!FileManager.default.fileExists(atPath: journal.path))
        }
    }

    /// A connection the server closes is made again for the next call; the call it failed under fails.
    @Test func aClosedConnectionIsMadeAgain() async throws {
        try await Self.inSchema { configuration, directory in
            let store = try await Self.open(configuration, in: directory)
            defer { store.close() }
            let tag = try store.createTag(named: "Laos", for: "owner", at: Self.created)
            let db = try PostgreSQLConnection.connect(configuration)
            defer { db.close() }
            // The store's connection is the only other one in its schema.
            let ended = try db.query(
                """
                SELECT pg_terminate_backend(pid, 5000) FROM pg_stat_activity
                    WHERE pid <> pg_backend_pid() AND application_name = ?
                """, [.text(PostgreSQLConnection.applicationName(configuration))])
            #expect(ended.count == 1)
            _ = try? store.tags(of: "owner")
            #expect(try store.tags(of: "owner") == [tag])
            try store.setTags([tag.id], of: Self.d1, for: "owner", at: Self.created)
            #expect(try store.tags(of: Self.d1, for: "owner") == [tag])
        }
    }

    /// Two processes' stores on one database write in turn, each rule's reads and writes together, as
    /// SQLite's write lock takes app.db's: however their Done races, a document carries a tag once.
    @Test func twoStoresOnOneDatabaseWriteInTurn() async throws {
        try await Self.inSchema { configuration, directory in
            let one = try await Self.open(configuration, in: directory, copy: "one.db")
            defer { one.close() }
            let two = try await Self.open(configuration, in: directory, copy: "two.db")
            defer { two.close() }
            let tag = try one.createTag(named: "Laos", for: "owner", at: Self.created)
            for round in 0..<20 {
                let document = DocumentKey(volumeId: "frus1961-63v06", documentId: "d\(round)")
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for store in [one, two] {
                        group.addTask { _ = try await Blocking.run { try store.setTags([tag.id], of: document, for: "owner", at: Self.created) } }
                    }
                    try await group.waitForAll()
                }
                #expect(try one.tags(of: document, for: "owner") == [tag])
            }
            let db = try PostgreSQLConnection.connect(configuration)
            defer { db.close() }
            #expect(try db.scalar("SELECT count(*) FROM tag_assignments", []) == .integer(20), "one assignment for each document")
        }
    }
}
