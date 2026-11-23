// What the index summary hashes in an index-75 database, table by table, and how it classifies
// every other object, so that nothing in the file goes unhashed or unexplained.
//
// Verified against Tests/FRUSLightTestSupport/Fixtures/export-v75-schema.sql, the schema of the
// owner's three-volume export from FRUS Explorer 1.0 (1861), the tag 1.0-release (index version 75),
// whose tables index version 74 held but volume_structures' two columns (S12d's pin move). The owner's
// full export from the same build has two tables' columns in another order, where its library's
// upgrades appended them, so the column check refuses it, and a library summary reads it (S25b, below).
// A pin move that changes a table fails the column check in `IndexSummarizer`, rather than leaving a new
// column out of every hash.

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
    /// For a library summary (`IndexSummarizer.library`), the condition that keeps the rows of documents
    /// the index still holds: a library the app has kept for years holds rows for documents the corpus
    /// dropped since, which an index made today never has. The set hash then takes only those rows, and
    /// the others are hashed for information as `<name>.dropped`.
    var heldRows: String?
    /// Whether the kit writes the table by upsert (`ON CONFLICT … DO UPDATE`), which keeps a row's rowid when
    /// its volume is indexed again, where it deletes and writes again the other tables a volume's pass
    /// stores. In a library indexed over many versions and corrections, a row an index version began to hold,
    /// or a file's later version added, then comes after the rows its volume already had: the rows' order is
    /// that library's history of indexing passes, which a library summary hashes for information
    /// (`LibraryOrder` reports it, volume by volume).
    var upserted = false

    enum SequenceRule: Sendable {
        /// No stable order to hash: the rows come from a Swift `Set`, or the table has no rowid.
        case none
        /// The app reads the rows in rowid order, so their order within a volume must match.
        case gating([String])
        /// Reported only: nothing reads the rows in rowid order.
        case information([String])
    }

    /// The set hash: every row, in natural-key order, without surrogate ids.
    var setSQL: String { setSQL(where: nil) }

    /// The set hash over the rows `condition` keeps, or over every row.
    func setSQL(where condition: String?) -> String {
        if let custom { return custom }
        let selected = columns.filter { leftOut[$0] == nil }.map { column in
            translated[column].map { "\($0.expression) AS \($0.alias)" } ?? column
        }
        let order = key ?? columns.filter { leftOut[$0] == nil }.map { translated[$0]?.alias ?? $0 }
        let filter = condition.map { " WHERE \($0)" } ?? ""
        return "SELECT \(selected.joined(separator: ", ")) FROM \(name)\(filter) ORDER BY \(order.joined(separator: ", "))"
    }

    /// For a library summary, the rows `heldRows` leaves out, every column of them, for information.
    var droppedSQL: String? {
        guard let heldRows else { return nil }
        let order = key ?? columns
        return "SELECT \(columns.joined(separator: ", ")) FROM \(name) WHERE NOT (\(heldRows)) ORDER BY \(order.joined(separator: ", "))"
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
            sequence: .gating(["volume_id", "document_id"]),
            upserted: true),
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
            sequence: .information(["volume_id", "document_id"]),
            heldRows: heldRevision),
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
        // stable: hash it as json_tree's (path, type, value) rows instead. Since index version 75
        // (FRUS-Explorer#1909) the row also records the file its volume was indexed from, the git blob
        // SHA-1 and the length of the bytes the store pass parsed, which each of its rows carries: the
        // fixture volumes' files are fixtures/tei's on both platforms, so the two agree.
        CorpusTable(
            name: "volume_structures",
            columns: ["volume_id", "structure_json", "file_blob_sha1", "file_size_bytes"],
            custom: """
                SELECT v.volume_id, v.file_blob_sha1, v.file_size_bytes, j.fullkey, j.type, j.atom \
                FROM volume_structures v, json_tree(v.structure_json) j ORDER BY v.volume_id, j.fullkey
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

    /// The app's schema: every object but the exporter's and SQLite's statistics, ordered by type and name, without
    /// root pages, each statement's text with its layout set aside (`normalizedSQL`). A column an upgrade adds,
    /// `ALTER TABLE … ADD COLUMN`, is written into the stored `CREATE TABLE` text after the last column's line, where
    /// a database the version creates has it on a line of its own, so a library the app upgraded and an index made
    /// fresh hold the same table in two layouts. Index version 75 is the first to add
    /// columns that the kit's `CREATE TABLE` names too (`volume_structures`' two, FRUS-Explorer#1909): the owner's
    /// golden library, which Erase Everything… keeps, gains them by `ALTER`, and the fixture index made here by
    /// `CREATE`. The words, their order and every column's place still count.
    static let schemaSQL = """
        SELECT type, name, tbl_name, \(normalizedSQL("sql")) FROM sqlite_schema WHERE name NOT GLOB 'research_*' \
        AND name NOT GLOB 'sqlite_autoindex_research_*' AND name NOT GLOB 'sqlite_stat*' ORDER BY type, name
        """

    /// SQL for `column`'s statement text with its layout set aside: each run of white space one space, and no space
    /// beside a parenthesis or a comma.
    static func normalizedSQL(_ column: String) -> String {
        var text = "replace(replace(replace(\(column), char(13), ' '), char(10), ' '), char(9), ' ')"
        // Seven halvings bring a run of up to 128 spaces to one; the kit's statements indent by a few dozen at most.
        for _ in 0..<7 { text = "replace(\(text), '  ', ' ')" }
        for (from, to) in [(" ,", ","), (", ", ","), (" (", "("), ("( ", "("), (" )", ")"), (") ", ")")] {
            text = "replace(\(text), '\(from)', '\(to)')"
        }
        return "trim(\(text))"
    }

    static let exportOnlySchemaSQL = """
        SELECT type, name, tbl_name, sql FROM sqlite_schema WHERE name GLOB 'research_*' \
        OR name GLOB 'sqlite_autoindex_research_*' ORDER BY type, name
        """

    // MARK: - A library summary (`frus-parity summarize --library`)
    //
    // A library the app has upgraded in place since its first index differs from an index made today in
    // what its upgrades left, not in what it indexes: a column an upgrade added comes last in its table
    // (`cross_references.is_broken` and `external_citations.note_label` in the owner's full exports), a
    // constraint a later version declares is missing (`person_mentions`' `UNIQUE`), and `document_revisions`
    // keeps rows for documents the corpus later dropped and the history of corrections it saw; and since the
    // kit upserts `document_cache`, keeping a row's rowid, a volume's documents come in the order of the
    // library's indexing passes (`upserted`, `LibraryOrder`). A library summary reads the index such a library
    // holds: every hash already selects its columns by name, so their places change nothing; the schema is
    // gated by each table's columns and every other statement's text, and the stored text of the tables,
    // their constraints, the dropped documents' rows, the history and that order are information. S25b's
    // check 2 at full scale.

    /// A revision row of a document the index holds.
    static let heldRevision = """
        EXISTS (SELECT 1 FROM document_cache c WHERE c.volume_id = document_revisions.volume_id \
        AND c.document_id = document_revisions.document_id)
        """

    /// The objects a library summary's schema statements read: the app's, leaving out the exporter's and every object
    /// SQLite names itself (`sqlite_sequence`, its statistics, the indexes it keeps for a constraint), where `schemaSQL`
    /// keeps `sqlite_sequence`'s and the constraints' rows; the constraints are `constraintsSQL`'s, and AUTOINCREMENT
    /// is each primary key's in `columnsSQL`.
    static let appObjects = """
        m.name NOT GLOB 'research_*' AND m.name NOT GLOB 'sqlite_*'
        """

    /// Every table's columns by name, each with its declared type, NOT NULL, default, place in the primary
    /// key, whether a virtual table hides it, and, for a primary key, whether the table declares AUTOINCREMENT, which
    /// only an INTEGER PRIMARY KEY can carry, whatever place the table gives it.
    static let columnsSQL = """
        SELECT m.name, p.name, p.type, p."notnull", p.dflt_value, p.pk, p.hidden, \
        p.pk > 0 AND instr(upper(m.sql), 'AUTOINCREMENT') > 0 \
        FROM sqlite_schema m, pragma_table_xinfo(m.name) p WHERE m.type = 'table' AND \(appObjects) \
        ORDER BY m.name, p.name
        """

    /// Every statement but a table's own: each index, trigger and virtual table, whose text holds no column
    /// an upgrade can append, with its layout set aside as `schemaSQL` sets it aside. An index SQLite makes
    /// for a constraint has no text, and is read by `constraintsSQL`.
    static let statementsSQL = """
        SELECT m.type, m.name, m.tbl_name, \(normalizedSQL("m.sql")) FROM sqlite_schema m \
        WHERE m.sql IS NOT NULL AND (m.type IN ('index', 'trigger') OR (m.type = 'table' AND m.sql GLOB 'CREATE VIRTUAL TABLE*')) \
        AND \(appObjects) ORDER BY m.type, m.name
        """

    /// Each table's UNIQUE and PRIMARY KEY constraints, by the index SQLite keeps for each, with its columns:
    /// for information in a library summary, since an upgrade does not add a constraint a later version declares.
    static let constraintsSQL = """
        SELECT m.name, l.name, l.origin, l."unique", i.seqno, i.name FROM sqlite_schema m, pragma_index_list(m.name) l, \
        pragma_index_info(l.name) i WHERE m.type = 'table' AND \(appObjects) AND l.origin <> 'c' ORDER BY m.name, l.name, i.seqno
        """

    /// The revision history a library keeps, which an index made today does not: for information in a library
    /// summary, where a golden summary checks that there is none (`document_revisions.history`).
    static let revisionHistorySQL = """
        SELECT volume_id, document_id, change_kind, changed_at, reviewed_at, index_version FROM document_revisions \
        WHERE changed_at IS NOT NULL OR change_kind IS NOT NULL OR reviewed_at IS NOT NULL ORDER BY volume_id, document_id
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

    /// Tables every index-69 database holds.
    static var requiredTables: [String] {
        corpusTables.map(\.name) + fullTextTables.flatMap { table in
            [table] + ["data", "idx", "docsize", "config"].map { "\(table)_\($0)" }
        }
    }
}
