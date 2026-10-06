// Check 2: summarizes an index database read-only, and refuses any database a golden summary
// could not stand for.
//
// Each table is hashed in natural-key order without surrogate ids, so two databases holding the
// same rows summarize the same whatever order the volumes were indexed in. FTS5 is hashed through
// what does not depend on its segment layout: its configuration, its averages record, each
// document's sizes and its vocabulary. docs/SPEC.md, Verification, check 2.

import CSQLite
import FRUSLightCore
import Foundation
import ParityFormat

/// Why the summary refuses a database: the CLI prints the reason and exits 1.
public struct SummaryRefusal: Error, CustomStringConvertible, Equatable, Sendable {
    public enum Kind: String, Sendable {
        /// Missing, or not a SQLite database.
        case notADatabase
        /// In write-ahead-log mode with a `-wal` file beside it, a copy of a database in use; or
        /// with a hot `-journal` beside it, a transaction left unfinished.
        case inUse
        /// An object the summary does not know, or a table whose columns changed.
        case schema
        /// Another index version or FTS schema generation.
        case versions
        /// Not exactly the fixture volumes, or a row naming a volume the index does not hold.
        case volumes
        /// The owner's notes, summaries or tags.
        case writing
        /// A person rollup the app would rebuild on its next launch.
        case staleRollup
        /// The repository's `fixtures/tei` does not match its `SHA256SUMS`, so the summary could
        /// not record which fixtures it stands for.
        case fixtures
    }

    public let kind: Kind
    public let reason: String

    public init(_ kind: Kind, _ reason: String) {
        self.kind = kind
        self.reason = reason
    }

    public var description: String { reason }
}

/// Summarizes one index database (`summarize(_:)`).
public struct IndexSummarizer: Sendable {
    public static let ftsSchemaVersion = IndexCompatibility.ftsSchemaVersion
    /// Above this size the summary leaves out what costs most: the instance-mode vocabulary and
    /// the integrity checks, which need an in-memory copy. A three-volume index is about 5 MB.
    public static let defaultFullCheckLimit: Int64 = 64 * 1_048_576
    public static let tool = "frus-parity summarize"

    /// The repository: its submodule, for the provenance's source digest and app build, and its
    /// `fixtures/tei`, whose digests the provenance records.
    public var layout: RepositoryLayout
    /// Summarizes any set of volumes, not only the three fixtures. Such a summary is for
    /// diagnosis: it can never stand as the golden file, so it records no fixtures.
    public var anyVolumes: Bool
    public var upstreamCommit: String?
    public var fullCheckLimit: Int64

    public init(layout: RepositoryLayout, anyVolumes: Bool = false, upstreamCommit: String? = nil,
                fullCheckLimit: Int64 = IndexSummarizer.defaultFullCheckLimit) {
        self.layout = layout
        self.anyVolumes = anyVolumes
        self.upstreamCommit = upstreamCommit
        self.fullCheckLimit = fullCheckLimit
    }

    /// Summarizes the database at `url`, which it opens read-only with `immutable=1`. Throws
    /// `SummaryRefusal` for a database the summary cannot stand for. A symbolic link is resolved
    /// first, so the size, the header and the files beside it are the database's own.
    public func summarize(_ url: URL) throws -> IndexSummaryGolden {
        let clock = ContinuousClock()
        let started = clock.now
        let url = url.resolvingSymlinksInPath()
        let fileBytes = try Self.checkFile(url)
        let db: ParityDatabase
        do {
            db = try ParityDatabase.immutable(url)
            _ = try db.scalar("SELECT count(*) FROM sqlite_schema")
        } catch let error as ParityDatabaseError {
            throw SummaryRefusal(.notADatabase, "\(url.lastPathComponent) could not be read as a SQLite database: \(error.message).")
        }
        try Self.checkSchema(db)
        let stamp = try Self.exportStamp(db)
        try Self.checkVersions(db, stamp: stamp)
        let volumes = try checkVolumes(db)
        try Self.checkWriting(db, stamp: stamp)
        try Self.checkRollup(db)
        var inputs: [String: String] = [:]
        if !anyVolumes {
            do {
                inputs = try ParityFixtures.verifiedInputs(tei: layout.tei)
            } catch {
                throw SummaryRefusal(.fixtures, "\(error). A golden summary records the fixtures it stands for, so they must be the ones SHA256SUMS lists.")
            }
        }

        let full = fileBytes <= fullCheckLimit
        var notes: [String] = []
        if !full {
            let limit = fullCheckLimit >= 1_048_576 ? "\(fullCheckLimit / 1_048_576) MB" : "\(fullCheckLimit) bytes"
            notes.append("The file is above \(limit), so the instance-mode vocabularies and the integrity checks were left out.")
        }
        if stamp == nil { notes.append("No research_provenance: the exporter did not stamp this index.") }

        var setup: [String] = []
        for table in IndexSchema.fullTextTables {
            for mode in full ? ["row", "col", "instance"] : ["row", "col"] {
                setup.append("CREATE VIRTUAL TABLE temp.parity_\(table)_\(mode) USING fts5vocab(main, \(table), \(mode))")
            }
        }
        for sql in setup { try db.execute(sql) }

        var gating: [String: StatementDigest] = [:]
        var information: [String: StatementDigest] = [:]
        var timings: [String: Double] = [:]
        for statement in Self.statements(full: full) {
            let start = clock.now
            let digest = try db.digest(statement.sql, volumeColumn: statement.volumeColumn)
            timings[statement.name] = Self.seconds(clock.now - start)
            if statement.gating { gating[statement.name] = digest } else { information[statement.name] = digest }
        }

        var checks: [String: String] = [:]
        checks["user_version"] = try db.scalar("PRAGMA user_version")?.text
        checks["application_id"] = try db.scalar("PRAGMA application_id")?.text
        checks["encoding"] = try db.scalar("PRAGMA encoding")?.text
        checks["document_revisions.history"] = try db.scalar("""
            SELECT count(*) FROM document_revisions
            WHERE changed_at IS NOT NULL OR change_kind IS NOT NULL OR reviewed_at IS NOT NULL
            """)?.text
        for table in IndexSchema.fullTextTables {
            checks["\(table).docsize_orphans"] = try db.scalar("""
                SELECT count(*) FROM \(table)_docsize ds WHERE NOT EXISTS (SELECT 1 FROM document_cache dc WHERE dc.rowid = ds.id)
                """)?.text
        }
        if full {
            let start = clock.now
            checks["integrity"] = try Self.integrity(of: db)
            timings["integrity"] = Self.seconds(clock.now - start)
        }

        var sequence: [String: Int64] = [:]
        if try db.scalar("SELECT 1 FROM sqlite_schema WHERE name = 'sqlite_sequence'") != nil {
            for row in try db.rows("SELECT name, seq FROM sqlite_sequence ORDER BY name") {
                if let name = row[0].text { sequence[name] = row[1].integer }
            }
        }
        let sqlite = try db.scalar("SELECT sqlite_version()")?.text ?? "unknown"
        timings["total"] = Self.seconds(clock.now - started)
        let info = IndexInformation(
            sqliteVersion: sqlite,
            fileBytes: fileBytes,
            pageSize: Int(try db.scalar("PRAGMA page_size")?.integer ?? 0),
            pageCount: Int(try db.scalar("PRAGMA page_count")?.integer ?? 0),
            freelistCount: Int(try db.scalar("PRAGMA freelist_count")?.integer ?? 0),
            journalMode: try db.scalar("PRAGMA journal_mode")?.text ?? "unknown",
            volumeOrder: try db.strings("SELECT volume_id FROM document_cache GROUP BY volume_id ORDER BY min(rowid)"),
            exportStamp: stamp,
            sqliteSequence: sequence,
            setup: setup,
            digests: information,
            notes: notes,
            timings: timings)

        for (key, value) in stamp ?? [:] { inputs["research_provenance.\(key)"] = value }
        let provenance = Provenance(
            tool: Self.tool, upstreamCommit: upstreamCommit, appBuild: Upstream.appBuild(layout.upstream),
            indexVersion: IndexCompatibility.supportedIndexVersion, sourceDigest: try Upstream.sourceDigest(layout.upstream),
            inputs: inputs, platform: .current(sqlite: sqlite))
        return IndexSummaryGolden(
            provenance: provenance,
            gating: IndexGating(volumes: volumes, checks: checks, digests: gating),
            information: info)
    }

    // MARK: - Statements

    struct Statement {
        let name: String
        let sql: String
        let volumeColumn: Int32?
        let gating: Bool
    }

    /// Every hashed statement. `full` adds the instance-mode vocabularies.
    static func statements(full: Bool) -> [Statement] {
        var statements: [Statement] = []
        for table in IndexSchema.corpusTables {
            statements.append(Statement(name: table.name, sql: table.setSQL, volumeColumn: table.volumeIndex, gating: true))
            if let sql = table.sequenceSQL {
                var gating = false
                if case .gating = table.sequence { gating = true }
                statements.append(Statement(name: "\(table.name).sequence", sql: sql, volumeColumn: 0, gating: gating))
            }
        }
        for table in IndexSchema.fullTextTables {
            statements += [
                Statement(name: "\(table).config", sql: "SELECT k, v FROM \(table)_config ORDER BY k", volumeColumn: nil, gating: true),
                // The averages record: the row count and each column's token total.
                Statement(name: "\(table).averages", sql: "SELECT id, block FROM \(table)_data WHERE id = 1", volumeColumn: nil, gating: true),
                Statement(name: "\(table).docsize", sql: """
                    SELECT dc.volume_id, dc.document_id, ds.sz FROM \(table)_docsize ds JOIN document_cache dc ON dc.rowid = ds.id \
                    ORDER BY dc.volume_id, dc.document_id
                    """, volumeColumn: 0, gating: true),
                Statement(name: "\(table).vocab_row", sql: "SELECT term, doc, cnt FROM temp.parity_\(table)_row ORDER BY term",
                          volumeColumn: nil, gating: true),
                Statement(name: "\(table).vocab_col", sql: "SELECT term, col, doc, cnt FROM temp.parity_\(table)_col ORDER BY term, col",
                          volumeColumn: nil, gating: true),
            ]
            if full {
                statements.append(Statement(name: "\(table).vocab_instance", sql: """
                    SELECT dc.volume_id, dc.document_id, i.col, i.offset, i.term FROM temp.parity_\(table)_instance i \
                    JOIN document_cache dc ON dc.rowid = i.doc ORDER BY dc.volume_id, dc.document_id, i.col, i.offset, i.term
                    """, volumeColumn: 0, gating: true))
            }
        }
        statements += [
            Statement(name: "schema", sql: IndexSchema.schemaSQL, volumeColumn: nil, gating: true),
            Statement(name: "schema.export_only", sql: IndexSchema.exportOnlySchemaSQL, volumeColumn: nil, gating: false),
            Statement(name: "volume_structures.json", sql: "SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id",
                      volumeColumn: 0, gating: false),
            Statement(name: "person_rollup.ids", sql: "SELECT rollup_id, namekey FROM person_rollup ORDER BY rollup_id",
                      volumeColumn: nil, gating: false),
        ]
        return statements
    }

    // MARK: - Refusals

    /// The file's size. Refuses a missing file, one that is not SQLite, a write-ahead-log
    /// database with a `-wal` file beside it, and one with a hot rollback journal beside it.
    /// `immutable=1` never reads either file: the summary would miss a `-wal` file's newest pages,
    /// and read the pages a hot journal's transaction left half written, which SQLite would
    /// otherwise roll back. `url` must be the database itself, not a link to it.
    static func checkFile(_ url: URL) throws -> Int64 {
        guard let size = fileSize(url.path) else {
            throw SummaryRefusal(.notADatabase, "\(url.path) does not exist.")
        }
        let header: Data
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            header = try handle.read(upToCount: 100) ?? Data()
        } catch {
            throw SummaryRefusal(.notADatabase, "\(url.path) could not be read: \(error.localizedDescription)")
        }
        guard header.count == 100, header.prefix(16) == Data("SQLite format 3\0".utf8) else {
            throw SummaryRefusal(.notADatabase, "\(url.lastPathComponent) is not a SQLite database.")
        }
        // Header bytes 18 and 19 are the read and write versions: 2 in write-ahead-log mode.
        let wal = url.path + "-wal"
        if header[header.startIndex + 18] == 2 || header[header.startIndex + 19] == 2, let walSize = fileSize(wal), walSize > 0 {
            throw SummaryRefusal(.inUse, "\(url.lastPathComponent) is in write-ahead-log mode with a \(walSize)-byte -wal file beside it, so it is a database in use. Summarize an export, or let the app close the database first.")
        }
        // A journal is hot when it is not empty and its first byte is not zero (pager.c,
        // hasHotJournal). A zeroed or empty one is what a committed transaction leaves.
        let journal = url.path + "-journal"
        if let journalSize = fileSize(journal), journalSize > 0 {
            let first: Data
            do {
                let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: journal))
                defer { try? handle.close() }
                first = try handle.read(upToCount: 1) ?? Data()
            } catch {
                throw SummaryRefusal(.inUse, "\(url.lastPathComponent) has a \(journalSize)-byte -journal beside it that could not be read: \(error.localizedDescription)")
            }
            if first.first.map({ $0 != 0 }) ?? false {
                throw SummaryRefusal(.inUse, "\(url.lastPathComponent) has a hot \(journalSize)-byte -journal beside it: a transaction was left unfinished, and immutable=1 would read its half-written pages. Let FRUS Explorer open the database to roll it back, or summarize a fresh export.")
            }
        }
        return size
    }

    /// Refuses an object the summary does not know, a missing table, or a table whose columns differ
    /// from index 65's: any of them would leave rows out of every hash.
    static func checkSchema(_ db: ParityDatabase) throws {
        var unknown: [String] = []
        var tables: Set<String> = []
        for row in try db.rows("SELECT type, name, tbl_name FROM sqlite_schema ORDER BY type, name") {
            let (type, name, table) = (row[0].text ?? "", row[1].text ?? "", row[2].text ?? "")
            if type == "table" { tables.insert(name) }
            if IndexSchema.role(type: type, name: name, table: table) == nil { unknown.append("\(type) \(name)") }
        }
        guard unknown.isEmpty else {
            throw SummaryRefusal(.schema, "The database holds \(unknown.joined(separator: ", ")), which the summary does not know, so it would go unhashed. Add it to IndexSchema if the app now makes it.")
        }
        let missing = IndexSchema.requiredTables.filter { !tables.contains($0) }
        guard missing.isEmpty else {
            throw SummaryRefusal(.schema, "This is not an index-\(IndexCompatibility.supportedIndexVersion) database: it has no \(missing.joined(separator: ", ")).")
        }
        for table in IndexSchema.corpusTables {
            let columns = try db.strings("SELECT name FROM pragma_table_info('\(table.name)')")
            guard columns == table.columns else {
                throw SummaryRefusal(.schema, "\(table.name) has the columns \(columns.joined(separator: ", ")); the summary knows \(table.columns.joined(separator: ", ")). Update IndexSchema for the new index version.")
            }
        }
    }

    /// The exporter's `research_provenance`, or nil when there is none or it is empty.
    static func exportStamp(_ db: ParityDatabase) throws -> [String: String]? {
        guard try db.scalar("SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = 'research_provenance'") != nil else {
            return nil
        }
        var stamp: [String: String] = [:]
        for row in try db.rows("SELECT key, value FROM research_provenance") {
            if let key = row[0].text { stamp[key] = row[1].text ?? "" }
        }
        return stamp.isEmpty ? nil : stamp
    }

    /// Refuses another FTS schema generation or index version, in the file or in the stamp.
    static func checkVersions(_ db: ParityDatabase, stamp: [String: String]?) throws {
        let supported = IndexCompatibility.supportedIndexVersion
        let generation = try db.scalar("PRAGMA user_version")?.integer ?? -1
        guard generation == Int64(ftsSchemaVersion) else {
            throw SummaryRefusal(.versions, "PRAGMA user_version is \(generation); index \(supported) uses FTS schema generation \(ftsSchemaVersion).")
        }
        let row = try db.rows("SELECT count(*), count(index_version), min(index_version), max(index_version) FROM document_revisions").first ?? []
        let total = row.first?.integer ?? 0
        guard total > 0, row[1].integer == total, row[2].integer == Int64(supported), row[3].integer == Int64(supported) else {
            let range = [row[2].text, row[3].text].compactMap { $0 }.joined(separator: " to ")
            throw SummaryRefusal(.versions, "document_revisions holds \(total) rows at index version \(range.isEmpty ? "none" : range), \(total - (row[1].integer ?? 0)) of them without one; every row must be at \(supported).")
        }
        guard let stamp else { return }
        let expected = [
            "installed_index_version": String(supported), "current_index_version": String(supported),
            "installed_fts_schema_version": String(ftsSchemaVersion), "current_fts_schema_version": String(ftsSchemaVersion),
        ]
        for key in expected.keys.sorted() where stamp[key] != expected[key] {
            throw SummaryRefusal(.versions, "The export's research_provenance has \(key) = \(stamp[key] ?? "nothing"); this harness summarizes \(expected[key]!).")
        }
    }

    /// The distinct volumes, sorted. Refuses any set but the fixtures unless `anyVolumes`, and any
    /// row of a per-volume table that names a volume `document_cache` does not hold.
    func checkVolumes(_ db: ParityDatabase) throws -> [String] {
        let volumes = try db.strings("SELECT DISTINCT volume_id FROM document_cache ORDER BY volume_id")
        guard !volumes.isEmpty else { throw SummaryRefusal(.volumes, "The database holds no documents.") }
        if !anyVolumes, Set(volumes) != Set(ParityFixtures.volumes) {
            let shown = volumes.prefix(5).joined(separator: ", ") + (volumes.count > 5 ? ", …" : "")
            throw SummaryRefusal(.volumes, "The database holds \(volumes.count) volumes (\(shown)), not exactly the fixtures (\(ParityFixtures.volumes.joined(separator: ", "))). BM25 and the person rollup depend on the whole index, so a golden summary needs a library of exactly those volumes. Pass --any-volumes to summarize it for diagnosis.")
        }
        let held = Set(volumes)
        for table in IndexSchema.corpusTables {
            guard let column = table.volumeColumn else { continue }
            let outside = try db.strings("SELECT DISTINCT \(column) FROM \(table.name) ORDER BY \(column)").filter { !held.contains($0) }
            guard outside.isEmpty else {
                throw SummaryRefusal(.volumes, "\(table.name).\(column) names \(outside.count) volume(s) that document_cache does not hold: \(outside.prefix(5).joined(separator: ", ")).")
            }
        }
        return volumes
    }

    /// Refuses the owner's notes, summaries or tags, whatever the stamp says.
    static func checkWriting(_ db: ParityDatabase, stamp: [String: String]?) throws {
        if let stamp, stamp["my_writing_included"] != "0" {
            throw SummaryRefusal(.writing, "The export's research_provenance has my_writing_included = \(stamp["my_writing_included"] ?? "nothing"). Export again with Include My Notes, Summaries, and Tags turned off.")
        }
        let documents = try db.scalar("""
            SELECT count(*) FROM document_cache
            WHERE coalesce(summary_text, '') <> '' OR coalesce(note_text, '') <> '' OR coalesce(user_tag_ids, '') <> ''
            """)?.integer ?? 0
        let tags = try db.scalar("SELECT count(*) FROM user_tags")?.integer ?? 0
        guard documents == 0, tags == 0 else {
            throw SummaryRefusal(.writing, "The database holds the owner's writing: \(documents) documents with a summary, note or tag, and \(tags) tags. Export again with Include My Notes, Summaries, and Tags turned off.")
        }
    }

    /// Refuses a person rollup that the app's own rule calls stale (IndexingPipeline.swift:1474-1484,
    /// `consolidatePersonRollupIfNeeded`): its members no longer match `persons`, so the app would
    /// rebuild and renumber it on its next launch.
    static func checkRollup(_ db: ParityDatabase) throws {
        let persons = try db.scalar("SELECT count(*) FROM persons")?.integer ?? 0
        let members = try db.scalar("SELECT count(*) FROM person_rollup_member")?.integer ?? 0
        let rollups = try db.scalar("SELECT count(*) FROM person_rollup")?.integer ?? 0
        let unmatched = try db.scalar("""
            SELECT count(*) FROM persons p
            WHERE NOT EXISTS (SELECT 1 FROM person_rollup_member m WHERE m.volume_id = p.volume_id AND m.ref = p.ref)
            """)?.integer ?? 0
        let advice = "The person rollup is stale; open the library in FRUS Explorer, let it rebuild the rollup, and export again."
        guard members == persons else {
            throw SummaryRefusal(.staleRollup, "person_rollup_member has \(members) rows for \(persons) persons. \(advice)")
        }
        guard unmatched == 0 else {
            throw SummaryRefusal(.staleRollup, "\(unmatched) persons have no person_rollup_member row. \(advice)")
        }
        guard rollups > 0 || persons == 0 else {
            throw SummaryRefusal(.staleRollup, "person_rollup is empty while persons holds \(persons) rows. \(advice)")
        }
    }

    // MARK: - Checks

    /// `quick_check` and FTS5's rank-1 integrity check on both full-text tables, which compares
    /// each index with `document_cache`. The rank-1 check needs a writable connection, so both run
    /// on an in-memory copy. "ok", or the first failure.
    static func integrity(of db: ParityDatabase) throws -> String {
        let copy = try ParityDatabase.memory()
        try db.backup(into: copy)
        do {
            let result = try copy.strings("PRAGMA quick_check")
            guard result == ["ok"] else { return "quick_check: " + result.prefix(3).joined(separator: "; ") }
        } catch let error as ParityDatabaseError {
            return "quick_check: \(error.message)"
        }
        for table in IndexSchema.fullTextTables {
            do {
                try copy.execute("INSERT INTO \(table) (\(table), rank) VALUES ('integrity-check', 1)")
            } catch let error as ParityDatabaseError {
                return "\(table): \(error.message)"
            }
        }
        return "ok"
    }

    // MARK: - Helpers

    static func fileSize(_ path: String) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value
    }

    static func seconds(_ duration: Duration) -> Double {
        let (seconds, attoseconds) = duration.components
        return ((Double(seconds) + Double(attoseconds) / 1e18) * 1000).rounded() / 1000
    }
}
