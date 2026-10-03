// Builds synthetic FRUS Explorer research exports for tests, from the schema of a real one.

import CSQLite
import FRUSLightCore
import Foundation

/// A small export built on `Fixtures/export-v65-schema.sql`, the schema of a real index-65
/// export, with switches for each way an export can be wrong.
public struct SyntheticExport: Sendable {
    public var indexVersion = IndexCompatibility.supportedIndexVersion
    /// The Mac's installed version, when it differs from `indexVersion` (a re-index in progress).
    public var installedIndexVersion: Int?
    public var ftsSchemaVersion = IndexCompatibility.ftsSchemaVersion
    /// Writes `research_provenance`; a hand-made `.backup` copy has none.
    public var stamped = true
    /// The `my_writing_included` stamp.
    public var stampsWritingIncluded = false
    /// Puts a note in the copy, whatever the stamp says.
    public var containsWriting = false
    /// Changes a document's text behind the full-text index's back.
    public var corruptFullTextIndex = false
    /// Leaves the file's header in write-ahead-log mode, though fully checkpointed, with no -wal.
    public var walMode = false
    /// The stamp's export time; two exports with the same time and size count as the same file.
    public var exportedAt = "2026-10-03T15:14:19Z"
    /// Stamp keys to leave out.
    public var omittedStampKeys: Set<String> = []
    /// A stamped FTS schema version that differs from `PRAGMA user_version`.
    public var stampedFTSSchemaVersion: Int?
    /// Adds a row to `user_tags`, a kind of writing with no column in `document_cache`.
    public var containsUserTag = false
    /// Damages one b-tree page that no check before the integrity check reads.
    public var damagedPage = false

    public static let documents: [(volume: String, id: String, header: String, body: String)] = [
        ("frus1961-63v06", "d1", "1. Telegram From the Embassy in the Soviet Union",
         "The ambassador was negotiating treaties with the minister."),
        ("frus1961-63v06", "d2", "2. Memorandum of Conversation",
         "Negotiating began in May, and after many long weeks of talks the treaties came."),
        ("frus1894Nicaragua", "d1", "No. 1. Mr. Baker to Mr. Gresham",
         "The canal concession and the Mosquito Reservation."),
    ]

    public init() {}

    /// Writes the export to `url`, replacing any file there.
    public func write(to url: URL) throws {
        for suffix in ["", "-journal", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        let db = try SQLiteConnection(url.path, readOnly: false, create: true)
        defer { db.close() }
        try db.execute(try Self.schema())
        for doc in Self.documents {
            _ = try db.query(
                "INSERT INTO document_cache (volume_id, document_id, header, body_text) VALUES (?, ?, ?, ?)",
                [.text(doc.volume), .text(doc.id), .text(doc.header), .text(doc.body)])
            _ = try db.query(
                "INSERT INTO document_revisions (volume_id, document_id, content_hash, body_hash, index_version) VALUES (?, ?, ?, ?, ?)",
                [.text(doc.volume), .text(doc.id), .text(String(repeating: "0", count: 64)),
                 .text(String(repeating: "0", count: 16)), .integer(Int64(indexVersion))])
        }
        if !stamped {
            // A .backup of the live index: the exporter adds the stamp and these views to its copy only.
            try db.execute("""
                DROP VIEW research_documents; DROP VIEW research_cross_references;
                DROP VIEW research_suppressed_volumes; DROP TABLE research_provenance;
                """)
        } else {
            let stamp: [(String, String)] = [
                ("exported_at", exportedAt),
                ("my_writing_included", stampsWritingIncluded ? "1" : "0"),
                ("app_version", "0.2"),
                ("app_build", "49"),
                ("installed_index_version", String(installedIndexVersion ?? indexVersion)),
                ("current_index_version", String(indexVersion)),
                ("installed_fts_schema_version", String(stampedFTSSchemaVersion ?? ftsSchemaVersion)),
                ("current_fts_schema_version", String(stampedFTSSchemaVersion ?? ftsSchemaVersion)),
            ]
            for (key, value) in stamp where !omittedStampKeys.contains(key) {
                _ = try db.query("INSERT INTO research_provenance (key, value) VALUES (?, ?)", [.text(key), .text(value)])
            }
        }
        if containsWriting {
            try db.execute("UPDATE document_cache SET note_text = 'A planted note' WHERE document_id = 'd1' AND volume_id = 'frus1961-63v06'")
        }
        if containsUserTag {
            try db.execute("INSERT INTO user_tags (tag_id, name) VALUES ('t1', 'Berlin crisis')")
        }
        if corruptFullTextIndex {
            try db.execute("""
                DROP TRIGGER document_cache_frus_documents_au;
                UPDATE document_cache SET body_text = 'Text the full-text index never saw.' WHERE document_id = 'd2';
                """)
        }
        try db.execute("PRAGMA user_version = \(ftsSchemaVersion)")
        try db.execute(walMode ? "PRAGMA journal_mode = WAL" : "PRAGMA journal_mode = DELETE")
        if damagedPage {
            // The empty `terms` table's root page: zero its page-type byte.
            let root = try db.scalar("SELECT rootpage FROM sqlite_master WHERE name = 'terms'")?.integer ?? 0
            let pageSize = try db.scalar("PRAGMA page_size")?.integer ?? 4_096
            db.close()
            let handle = try FileHandle(forWritingTo: url)
            try handle.seek(toOffset: UInt64((root - 1) * pageSize))
            try handle.write(contentsOf: Data([0]))
            try handle.close()
        }
    }

    /// The real export's schema.
    public static func schema() throws -> String {
        guard let url = Bundle.module.url(forResource: "export-v65-schema", withExtension: "sql", subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

/// A temporary data directory, removed when the value is released.
public final class TemporaryDirectory: @unchecked Sendable {
    public let url: URL

    public init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("frus-light-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}
