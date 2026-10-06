// What the index summary hashes in an index-65 database, table by table, and how it classifies
// every other object, so that nothing in the file goes unhashed or unexplained.
//
// Verified against Tests/FRUSLightTestSupport/Fixtures/export-v65-schema.sql, the schema of the
// owner's export (index version 65, build 49). A pin move that changes a table fails the column
// check in `IndexSummarizer`, rather than leaving a new column out of every hash.

/// One table of the corpus index and how its rows are hashed.
struct CorpusTable: Sendable {
    let name: String
    /// Every column, in declaration order.
    let columns: [String]
    /// The column naming the volume a row belongs to: each volume's rows are also hashed apart,
    /// and no row may name a volume outside the index.
    var volumeColumn: String? = "volume_id"
    /// The natural key the set hash is ordered by; nil orders by every hashed column.
    var key: [String]?
    /// Columns left out of the set hash, each with the reason.
    var leftOut: [String: String] = [:]
    /// Columns hashed through an expression instead, selected under the given alias.
    var translated: [String: (alias: String, expression: String)] = [:]
    /// A hand-written set hash, where a generated one cannot say it.
    var custom: String?
    /// How the rows' order within each volume is hashed.
    var sequence: SequenceRule = .none

    enum SequenceRule: Sendable {
        /// No stable order to hash: the rows come from a Swift `Set`, or the table has no rowid.
        case none
        /// The app reads the rows in rowid order, so their order within a volume must match.
        case gating([String])
        /// Reported only: nothing reads the rows in rowid order.
        case information([String])
    }

    /// The set hash: every row, in natural-key order, without surrogate ids.
    var setSQL: String {
        if let custom { return custom }
        let selected = columns.filter { leftOut[$0] == nil }.map { column in
            translated[column].map { "\($0.expression) AS \($0.alias)" } ?? column
        }
        let order = key ?? columns.filter { leftOut[$0] == nil }.map { translated[$0]?.alias ?? $0 }
        return "SELECT \(selected.joined(separator: ", ")) FROM \(name) ORDER BY \(order.joined(separator: ", "))"
    }

    /// The sequence hash: the rows of each volume in rowid order.
    var sequenceSQL: String? {
        let columns: [String]
        switch sequence {
        case .none: return nil
        case .gating(let c), .information(let c): columns = c
        }
        guard let volumeColumn else { return nil }
        return "SELECT \(columns.joined(separator: ", ")) FROM \(name) ORDER BY \(volumeColumn), rowid"
    }

    /// The position of the volume column in the set hash's result, for per-volume digests. A
    /// hand-written statement selects it first.
    var volumeIndex: Int32? {
        guard let volumeColumn else { return nil }
        if custom != nil { return 0 }
        return columns.filter { leftOut[$0] == nil }.firstIndex(of: volumeColumn).map(Int32.init)
    }
}

enum IndexSchema {
    /// A rollup's representative: its least member by (volume_id, ref), as one text value. Rollup
    /// ids are renumbered whenever the rollup is rebuilt (IndexingPipeline.swift, #747), so the
    /// summary names a rollup by a member instead.
    static func representative(_ rollupId: String) -> String {
        "(SELECT m.volume_id || char(31) || m.ref FROM person_rollup_member m WHERE m.rollup_id = \(rollupId) ORDER BY m.volume_id, m.ref LIMIT 1)"
    }

    static let surrogate = "a surrogate id, numbered in insertion order"

    // Sequence rules. The app reads three tables in rowid order, so their order within a volume
    // is part of what it shows:
    // - document_cache: a volume's document list (FRUSCoreKit/Search/IndexingPipeline.swift:2789-2794,
    //   `documents(forVolume:)`, ORDER BY rowid);
    // - page_ranges: citation page spans (PageSpanResolver.swift:342-347, `arabicPageRowsSQL`,
    //   ORDER BY rowid);
    // - cross_references: a document's edges (CrossReferenceStore.swift:627-643, `outboundEdges`,
    //   no ORDER BY, so rowid order within the index's key).
    // person_mentions and person_list_sources are written from Swift Sets (IndexingPipeline.swift:4985
    // and 4937), so their rowid order is not stable between runs: set hashes only.
    static let corpusTables: [CorpusTable] = [
        CorpusTable(
            name: "cross_references",
            columns: ["id", "source_volume_id", "source_document_id", "target_volume_id", "target_document_id",
                      "is_broken", "reference_type", "context"],
            volumeColumn: "source_volume_id",
            leftOut: ["id": surrogate],
            sequence: .gating(["source_volume_id", "source_document_id", "target_volume_id", "target_document_id",
                               "is_broken", "reference_type", "context"])),
        CorpusTable(
            name: "page_ranges",
            columns: ["id", "volume_id", "document_id", "section_id", "page_number_type", "page_number_int",
                      "page_number_raw", "is_start"],
            leftOut: ["id": surrogate],
            sequence: .gating(["volume_id", "document_id", "section_id", "page_number_type", "page_number_int",
                               "page_number_raw", "is_start"])),
        CorpusTable(
            name: "document_dates",
            columns: ["volume_id", "document_id", "date_iso", "date_iso_max", "date_precision", "date_certainty"],
            key: ["volume_id", "document_id"],
            sequence: .information(["volume_id", "document_id"])),
        CorpusTable(
            name: "document_cache",
            columns: ["volume_id", "document_id", "document_number", "header", "dateline", "source_note", "body_text",
                      "subject_tag_ids", "user_tag_ids", "summary_text", "note_text", "is_editorial_note",
                      "is_front_matter", "despatch_serial"],
            key: ["volume_id", "document_id"],
            sequence: .gating(["volume_id", "document_id"])),
        CorpusTable(
            name: "document_revisions",
            columns: ["volume_id", "document_id", "content_hash", "body_hash", "changed_at", "change_kind",
                      "reviewed_at", "index_version"],
            key: ["volume_id", "document_id"],
            leftOut: [
                "changed_at": "revision history, which a fresh index leaves empty: checked as document_revisions.history",
                "change_kind": "revision history: checked as document_revisions.history",
                "reviewed_at": "revision history: checked as document_revisions.history",
            ],
            sequence: .information(["volume_id", "document_id"])),
        CorpusTable(
            name: "user_tags", columns: ["tag_id", "name"], volumeColumn: nil, key: ["tag_id"]),
        CorpusTable(
            name: "person_mentions",
            columns: ["id", "volume_id", "document_id", "person_ref"],
            leftOut: ["id": surrogate]),
        CorpusTable(
            name: "persons",
            columns: ["volume_id", "ref", "name", "description", "role", "start_year", "end_year"],
            key: ["volume_id", "ref"],
            sequence: .information(["volume_id", "ref"])),
        CorpusTable(
            name: "person_list_sources", columns: ["volume_id", "source_volume_id"]),
        CorpusTable(
            name: "person_rollup",
            columns: ["rollup_id", "namekey", "canonical_name", "description", "mention_count", "role", "start_year",
                      "end_year", "volume_count", "authority_id", "viaf_id"],
            volumeColumn: nil,
            translated: ["rollup_id": ("representative", representative("person_rollup.rollup_id"))]),
        CorpusTable(
            name: "person_rollup_member",
            columns: ["volume_id", "ref", "rollup_id"],
            key: ["volume_id", "ref"],
            translated: ["rollup_id": ("representative", representative("person_rollup_member.rollup_id"))]),
        CorpusTable(
            name: "person_cluster_candidate",
            columns: ["rollup_id_a", "rollup_id_b", "reason"],
            volumeColumn: nil,
            custom: """
                SELECT min(a, b) AS low, max(a, b) AS high, reason FROM (SELECT \(representative("c.rollup_id_a")) AS a, \
                \(representative("c.rollup_id_b")) AS b, c.reason AS reason FROM person_cluster_candidate c) ORDER BY low, high, reason
                """),
        CorpusTable(
            name: "terms",
            columns: ["volume_id", "ref", "term", "definition"],
            key: ["volume_id", "ref"],
            sequence: .information(["volume_id", "ref"])),
        CorpusTable(
            name: "document_sources",
            columns: ["volume_id", "document_id", "repository", "record_group", "lot_file", "lot_file_norm",
                      "series_name", "citation_era", "raw_text", "classification", "decimal_class", "job_number_norm"],
            key: ["volume_id", "document_id"],
            sequence: .information(["volume_id", "document_id"])),
        CorpusTable(
            name: "external_citations",
            columns: ["volume_id", "document_id", "note_ordinal", "note_label", "citation_index", "anchor",
                      "repository", "collection", "lot_file", "lot_file_norm", "file_id", "inherited", "raw_text",
                      "decimal_class"],
            key: ["volume_id", "document_id", "note_ordinal", "citation_index"],
            sequence: .information(["volume_id", "document_id", "note_ordinal", "citation_index"])),
        CorpusTable(
            name: "document_subjects", columns: ["volume_id", "document_id", "bucket"]),
        CorpusTable(
            name: "document_subject_refs", columns: ["volume_id", "document_id", "subject"]),
        CorpusTable(
            name: "document_subject_volumes", columns: ["volume_id", "digest"], key: ["volume_id"]),
        CorpusTable(
            name: "volume_sources",
            columns: ["volume_id", "repository", "record_group", "lot_file", "lot_file_norm", "series_name",
                      "decimal_class", "job_number", "job_number_norm", "entry_text", "kind", "depth", "is_heading",
                      "sort_order", "note"],
            key: ["volume_id", "sort_order"],
            sequence: .information(["volume_id", "sort_order"])),
        // The app writes the JSON with a JSONEncoder that does not sort keys, so its text is not
        // stable: hash it as json_tree's (path, type, value) rows instead.
        CorpusTable(
            name: "volume_structures",
            columns: ["volume_id", "structure_json"],
            custom: """
                SELECT v.volume_id, j.fullkey, j.type, j.atom FROM volume_structures v, json_tree(v.structure_json) j \
                ORDER BY v.volume_id, j.fullkey
                """),
    ]

    /// The FTS5 tables over `document_cache`, with the columns their vocabulary covers.
    static let fullTextTables = ["frus_documents", "user_content"]

    /// FTS5's shadow tables. `_data` and `_idx` hold the index's segments, whose layout follows
    /// the order of inserts and merges, so only the averages record (id 1) is hashed from them.
    static let shadowSuffixes = ["data", "idx", "docsize", "config", "content"]

    /// Objects only the exporter adds, beside the index: hashed for information only.
    static let exportOnly: Set<String> = [
        "research_provenance", "research_suppressed_volumes", "research_documents", "research_cross_references",
        "sqlite_autoindex_research_provenance_1",
    ]

    /// The app's schema: every object but the exporter's and SQLite's statistics, ordered by type
    /// and name, without root pages.
    static let schemaSQL = """
        SELECT type, name, tbl_name, sql FROM sqlite_schema WHERE name NOT GLOB 'research_*' \
        AND name NOT GLOB 'sqlite_autoindex_research_*' AND name NOT GLOB 'sqlite_stat*' ORDER BY type, name
        """

    static let exportOnlySchemaSQL = """
        SELECT type, name, tbl_name, sql FROM sqlite_schema WHERE name GLOB 'research_*' \
        OR name GLOB 'sqlite_autoindex_research_*' ORDER BY type, name
        """

    enum Role: String, Sendable {
        /// A corpus table, hashed row by row.
        case corpus
        /// An FTS5 table, its vocabulary view or one of its shadow tables.
        case fullText
        /// Added by the exporter: its research views and stamp.
        case exportOnly
        /// SQLite's own: `sqlite_sequence`, statistics and automatic indexes.
        case `internal`
        /// An index or trigger on a corpus or full-text table, hashed through the schema's SQL.
        case schema
    }

    /// The role of one `sqlite_schema` row, or nil when the summary does not know it.
    static func role(type: String, name: String, table: String) -> Role? {
        if exportOnly.contains(name) { return .exportOnly }
        if name.hasPrefix("sqlite_") { return .internal }
        let corpus = Set(corpusTables.map(\.name))
        var fullText = Set(fullTextTables + ["frus_documents_vocab"])
        for table in fullTextTables { for suffix in shadowSuffixes { fullText.insert("\(table)_\(suffix)") } }
        switch type {
        case "table":
            if corpus.contains(name) { return .corpus }
            if fullText.contains(name) { return .fullText }
            return nil
        case "index", "trigger":
            return corpus.contains(table) || fullText.contains(table) ? .schema : nil
        default:
            return nil
        }
    }

    /// Tables every index-65 database holds.
    static var requiredTables: [String] {
        corpusTables.map(\.name) + fullTextTables.flatMap { table in
            [table] + ["data", "idx", "docsize", "config"].map { "\(table)_\($0)" }
        }
    }
}
