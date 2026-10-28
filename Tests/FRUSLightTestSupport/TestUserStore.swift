// A new user store of either kind for one test (S14d's conformance suite): app.db in a temporary
// folder, or the PostgreSQL store in a schema of its own in the database FRUS_TEST_POSTGRES_URL names,
// dropped when the test closes it. CI's swift job names a PostgreSQL service there, and
// `scripts/swift --postgres` a container on this machine.

import FRUSLightCore
import Foundation

/// The two stores the conformance suite holds alike.
public enum UserStoreKind: String, Sendable, CaseIterable {
    case sqlite, postgreSQL

    /// Those this run can open: app.db always, and the PostgreSQL store where FRUS_TEST_POSTGRES_URL
    /// names a database.
    public static var available: [UserStoreKind] { TestPostgreSQL.isConfigured ? allCases : [.sqlite] }
}

/// The PostgreSQL database the tests use, if any.
public enum TestPostgreSQL {
    public static let variable = "FRUS_TEST_POSTGRES_URL"

    public static var isConfigured: Bool { !(ProcessInfo.processInfo.environment[variable] ?? "").isEmpty }

    /// The database the variable names, in `schema`.
    public static func configuration(schema: String?) throws -> PostgreSQLConfiguration {
        guard let url = ProcessInfo.processInfo.environment[variable], !url.isEmpty else {
            throw PostgreSQLConfigurationError("\(variable) names no database")
        }
        var configuration = try PostgreSQLConfiguration(url: url)
        configuration.schema = schema
        return configuration
    }

    /// A schema name no other test has.
    public static func newSchema() -> String {
        "frus_test_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
    }

    /// Drops `schema` and everything in it.
    public static func drop(_ schema: String) throws {
        let db = try PostgreSQLConnection.connect(try configuration(schema: nil))
        defer { db.close() }
        try db.execute("DROP SCHEMA IF EXISTS \(PostgreSQLConnection.quoted(schema)) CASCADE")
    }
}

/// A store for one test, with a second connection to it (`rows`). `close()` closes both and removes
/// the store: call it in a `defer`, so that the store outlives the test's last use of it.
public final class TestUserStore: @unchecked Sendable {
    public let kind: UserStoreKind
    public let store: RelationalUserStore
    public let rows: UserStoreRows
    public let directory: TemporaryDirectory
    /// The PostgreSQL store's schema, or nil for app.db.
    public let schema: String?
    private let lock = NSLock()
    private var isClosed = false

    private init(kind: UserStoreKind, store: RelationalUserStore, rows: UserStoreRows, directory: TemporaryDirectory,
                 schema: String?) {
        self.kind = kind
        self.store = store
        self.rows = rows
        self.directory = directory
        self.schema = schema
    }

    deinit { close() }

    public static func open(_ kind: UserStoreKind) async throws -> TestUserStore {
        let directory = try TemporaryDirectory()
        switch kind {
        case .sqlite:
            let url = directory.url.appendingPathComponent("app.db")
            let store = try await SQLiteUserStore(url: url, backupsDirectory: directory.url.appendingPathComponent("backups"))
            return TestUserStore(kind: kind, store: store, rows: try UserStoreRows(url), directory: directory, schema: nil)
        case .postgreSQL:
            let schema = TestPostgreSQL.newSchema()
            let configuration = try TestPostgreSQL.configuration(schema: schema)
            let copy = directory.url.appendingPathComponent("user-search.db")
            do {
                let store = try await PostgreSQLUserStore(configuration: configuration, searchCopy: copy)
                return TestUserStore(kind: kind, store: store, rows: try UserStoreRows(postgreSQL: configuration, searchCopy: copy),
                                     directory: directory, schema: schema)
            } catch {
                try? TestPostgreSQL.drop(schema)
                throw error
            }
        }
    }

    /// The PostgreSQL configuration of this test's schema, or nil for app.db.
    public func postgreSQLConfiguration() throws -> PostgreSQLConfiguration? {
        try schema.map { try TestPostgreSQL.configuration(schema: $0) }
    }

    /// The store opened again over the same data, as a server's next start opens it; the store this
    /// one holds keeps working beside it. For the PostgreSQL store, a second copy at `copy`, or in place
    /// of the first.
    public func reopen(copy: URL? = nil) async throws -> RelationalUserStore {
        switch kind {
        case .sqlite:
            return try await SQLiteUserStore(url: directory.url.appendingPathComponent("app.db"),
                                             backupsDirectory: directory.url.appendingPathComponent("backups"))
        case .postgreSQL:
            return try await PostgreSQLUserStore(configuration: try TestPostgreSQL.configuration(schema: schema),
                                                 searchCopy: copy ?? directory.url.appendingPathComponent("user-search.db"))
        }
    }

    /// Closes the store and the rows' connections, and drops the PostgreSQL store's schema. Safe to
    /// call twice.
    public func close() {
        let first = lock.withLock {
            defer { isClosed = true }
            return !isClosed
        }
        guard first else { return }
        (store as? PostgreSQLUserStore)?.close()
        rows.closeConnections()
        if let schema { try? TestPostgreSQL.drop(schema) }
    }
}
