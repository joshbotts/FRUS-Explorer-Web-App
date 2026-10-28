// Builds synthetic FRUS Explorer research exports for tests, from the schema of a real one.

import CSQLite
import FRUSLightCore
import Foundation

/// A small export built on `Fixtures/export-v69-schema.sql`, the schema of a real index-69
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
    /// The owner's writing of `Fixtures/export-writing.sql`, and the stamp that says the export holds
    /// it: an export made with Include My Notes, Summaries, and Tags on (PLAN's S16e), as
    /// `scripts/synthetic-export --writing` writes it.
    public var includesWriting = false
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
    /// The count of Khrushchev's person rollup, which spans the corpus; by default the export's own
    /// two documents that mention him, as a real three-volume export's rollup counts them.
    public var rollupMentionCount = 2
    /// Adds four rows of the kit's fixture volume for a section's own text, and its outline:
    /// `ownTextRows`, which `scripts/synthetic-export --own-text` writes too.
    public var includesOwnText = false

    public static let documents: [(volume: String, id: String, header: String, body: String)] = [
        ("frus1961-63v06", "d1", "1. Telegram From the Embassy in the Soviet Union",
         "The ambassador was negotiating treaties with the minister."),
        ("frus1961-63v06", "d2", "2. Memorandum of Conversation",
         "Negotiating began in May, and after many long weeks of talks the treaties came."),
        ("frus1894Nicaragua", "d1", "No. 1. Mr. Baker to Mr. Gresham",
         "The canal concession and the Mosquito Reservation."),
    ]

    /// The volume of `fixtures/own-text/frus1969-76v01.xml`, the kit's fixture for a section's own
    /// text (`SectionOwnTextTests`), as FRUSCoreKit indexes it: two documents of its first meeting,
    /// the meeting's own text and that of the conference around it, which holds only sections, in
    /// the order the kit stores them. The rest of its rows would change what the export's searches
    /// find. FRUSParityTests holds them, and the outline, to the kit's index of the file.
    public static let ownTextVolume = "frus1969-76v01"
    public static let ownTextRows: [(id: String, number: String?, header: String, body: String)] = [
        ("d1", "1", "1. Minutes", "1. Minutes Agreed minutes. Continued minutes."),
        ("d2", "2", "2. Memorandum", "2. Memorandum Annexed memorandum."),
        ("ch1", nil, "First Meeting", "First Meeting Held at Anfa Camp. Present Marshall and Brooke Closing communiqué, see Document 1."),
        ("comp1", nil, "The Conference", "The Conference Synopsis of the conference. Adjournment of the conference."),
    ]

    /// The outline the kit stores for the volume, which gives the reader its order, from
    /// `fixtures/own-text/frus1969-76v01-outline.json`.
    public static func ownTextOutline() throws -> String {
        try String(contentsOf: RepositoryFiles.ownText.appendingPathComponent("\(ownTextVolume)-outline.json"), encoding: .utf8)
            .trimmingCharacters(in: .newlines)
    }

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
        // A page and a person for the reader's links, shaped as a real export's rows for the same
        // documents: d1 and d2 begin pages 1 and 2 of frus1961-63v06, and both mention Khrushchev
        // (p_KNS2), whose rollup counts his documents, and Kennedy (p_KJF2), who has no rollup here,
        // so his count is his documents in the volume. Each document has its date from its TEI, so
        // the facets have years. scripts/synthetic-export writes the same rows.
        try db.execute("""
            INSERT INTO page_ranges (volume_id, document_id, section_id, page_number_type, page_number_int, page_number_raw, is_start)
            VALUES ('frus1961-63v06', 'd1', 'd1', 'arabic', 1, '1', 1), ('frus1961-63v06', 'd2', 'd2', 'arabic', 2, '2', 1);
            INSERT INTO person_mentions (volume_id, document_id, person_ref)
            VALUES ('frus1961-63v06', 'd1', 'p_KNS2'), ('frus1961-63v06', 'd2', 'p_KNS2'),
                   ('frus1961-63v06', 'd1', 'p_KJF2'), ('frus1961-63v06', 'd2', 'p_KJF2');
            INSERT INTO person_rollup (rollup_id, namekey, canonical_name, description, mention_count, volume_count)
            VALUES (1, 'khrushchev, nikita sergeyevich', 'Khrushchev, Nikita Sergeyevich',
                    'Chairman of the Council of Ministers of the Soviet Union', \(rollupMentionCount), 1);
            INSERT INTO person_rollup_member (volume_id, ref, rollup_id) VALUES ('frus1961-63v06', 'p_KNS2', 1);
            INSERT INTO document_dates (volume_id, document_id, date_iso, date_iso_max, date_precision)
            VALUES ('frus1961-63v06', 'd1', '1960-11-09', '1960-11-09', 'day'),
                   ('frus1961-63v06', 'd2', '1960-11-10', '1960-11-10', 'day'),
                   ('frus1894Nicaragua', 'd1', '1894-01-25', '1894-01-25', 'day');
            """)
        if includesOwnText {
            // Undated, as the kit stores them: a section's row takes the span of its dated documents,
            // and these have none.
            let volume = Self.ownTextVolume
            for row in Self.ownTextRows {
                _ = try db.query(
                    "INSERT INTO document_cache (volume_id, document_id, document_number, header, body_text) VALUES (?, ?, ?, ?, ?)",
                    [.text(volume), .text(row.id), row.number.map { .text($0) } ?? .null, .text(row.header), .text(row.body)])
                _ = try db.query("INSERT INTO document_dates (volume_id, document_id) VALUES (?, ?)", [.text(volume), .text(row.id)])
                _ = try db.query(
                    "INSERT INTO document_revisions (volume_id, document_id, content_hash, body_hash, index_version) VALUES (?, ?, ?, ?, ?)",
                    [.text(volume), .text(row.id), .text(String(repeating: "0", count: 64)),
                     .text(String(repeating: "0", count: 16)), .integer(Int64(indexVersion))])
            }
            _ = try db.query("INSERT INTO volume_structures (volume_id, structure_json) VALUES (?, ?)",
                             [.text(volume), .text(try Self.ownTextOutline())])
        }
        if includesWriting {
            try db.execute(try Self.fixture("export-writing"))
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
                ("my_writing_included", stampsWritingIncluded || includesWriting ? "1" : "0"),
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
    public static func schema() throws -> String { try fixture("export-v69-schema") }

    /// One of the SQL files in `Fixtures`.
    static func fixture(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "sql", subdirectory: "Fixtures") else {
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
