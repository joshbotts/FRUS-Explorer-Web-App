// v1 interface 3, the user store behind a protocol; and v1 interface 2, corrections as override rows.

import Foundation

/// The users and their data. One SQLite implementation today, so a PostgreSQL store
/// (the managed variant's option B) can be added rather than swapped in.
public protocol UserStore: Sendable {
    /// The newest migration applied.
    func schemaVersion() throws -> Int
    /// The user a server with `FRUS_AUTH=none` acts for.
    func singleUserID() throws -> String
}

/// A curator's correction to the corpus index. As on the Mac, it is kept first as an
/// override row in the user store, and written to the index second (through `IndexWriter`),
/// or applied as an overlay over a read-only index.
public struct IndexCorrection: Sendable, Equatable, Codable {
    public enum Field: String, Sendable, Codable { case isEditorialNote = "is_editorial_note" }

    public var volumeId: String
    public var documentId: String
    public var field: Field
    public var value: String
    public var recordedBy: String

    public init(volumeId: String, documentId: String, field: Field, value: String, recordedBy: String) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.field = field
        self.value = value
        self.recordedBy = recordedBy
    }
}

/// Where corrections are kept before they reach the index.
public protocol CorrectionStore: Sendable {
    /// Records a correction, replacing an earlier one for the same document and field.
    func record(_ correction: IndexCorrection) throws
    func corrections() throws -> [IndexCorrection]
}

/// The user store in `/data/app/app.db`, with numbered, forward-only migrations.
public final class SQLiteUserStore: UserStore, CorrectionStore, @unchecked Sendable {
    private let db: SQLiteConnection

    /// Each entry is one migration; its number is its position, starting at 1. Never edit one
    /// that has shipped: add another.
    static let migrations: [String] = [
        """
        CREATE TABLE users (
            user_id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        INSERT INTO users (user_id, display_name, created_at)
            VALUES ('owner', 'Owner', strftime('%Y-%m-%dT%H:%M:%SZ', 'now'));
        CREATE TABLE index_corrections (
            volume_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            field TEXT NOT NULL,
            value TEXT NOT NULL,
            recorded_by TEXT NOT NULL REFERENCES users (user_id),
            recorded_at TEXT NOT NULL,
            PRIMARY KEY (volume_id, document_id, field)
        );
        """,
    ]

    public init(url: URL) throws {
        db = try SQLiteConnection(url.path, readOnly: false, create: true)
        try db.execute("PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;")
        try migrate()
    }

    private func migrate() throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at TEXT NOT NULL
            )
            """)
        let applied = try schemaVersion()
        guard applied <= Self.migrations.count else {
            throw SQLiteError(code: 0, message: "app.db is at migration \(applied), newer than this build's \(Self.migrations.count)")
        }
        for version in stride(from: applied + 1, through: Self.migrations.count, by: 1) {
            try db.execute("BEGIN IMMEDIATE")
            do {
                try db.execute(Self.migrations[version - 1])
                _ = try db.query(
                    "INSERT INTO schema_migrations (version, applied_at) VALUES (?, strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))",
                    [.integer(Int64(version))])
                try db.execute("COMMIT")
            } catch {
                try? db.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func schemaVersion() throws -> Int {
        Int(try db.scalar("SELECT coalesce(max(version), 0) FROM schema_migrations")?.integer ?? 0)
    }

    public func singleUserID() throws -> String { "owner" }

    public func record(_ correction: IndexCorrection) throws {
        _ = try db.query(
            """
            INSERT INTO index_corrections (volume_id, document_id, field, value, recorded_by, recorded_at)
                VALUES (?, ?, ?, ?, ?, strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
            ON CONFLICT (volume_id, document_id, field)
                DO UPDATE SET value = excluded.value, recorded_by = excluded.recorded_by, recorded_at = excluded.recorded_at
            """,
            [.text(correction.volumeId), .text(correction.documentId), .text(correction.field.rawValue),
             .text(correction.value), .text(correction.recordedBy)])
    }

    public func corrections() throws -> [IndexCorrection] {
        try db.query(
            "SELECT volume_id, document_id, field, value, recorded_by FROM index_corrections ORDER BY volume_id, document_id, field"
        ).compactMap { row in
            guard let field = row[2].text.flatMap(IndexCorrection.Field.init(rawValue:)) else { return nil }
            return IndexCorrection(volumeId: row[0].text ?? "", documentId: row[1].text ?? "", field: field,
                                   value: row[3].text ?? "", recordedBy: row[4].text ?? "")
        }
    }
}
