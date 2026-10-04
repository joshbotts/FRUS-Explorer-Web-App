// A synthetic index-65 export of the three fixture volumes, with a row in every corpus table, and
// switches for storing the same rows differently and for each way the summary must refuse one.

import FRUSLightCore
import FRUSLightTestSupport
@testable import FRUSParity
import Foundation
import ParityFormat

/// The repository these tests run in.
enum Repository {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let layout = RepositoryLayout(root: root)
}

struct ParityExport {
    enum RollupNumbering {
        case sequential
        case offset(Int64)
        case reversed
    }

    /// The volumes it holds.
    var volumes = ParityFixtures.volumes
    /// The order they are indexed in, which sets every rowid.
    var volumeOrder = ParityFixtures.volumes
    var rollupNumbering = RollupNumbering.sequential
    /// A volume whose documents are inserted last first: the same rows in another order.
    var reversedDocuments: String?
    /// Writes each volume's structure JSON with every object's keys in reverse order.
    var reversesJSONKeys = false
    /// After the build, rewrites one volume's documents in place and deletes and reinserts
    /// another's, so the full-text index holds delete markers and more segments.
    var fragmentsFullText = false
    var stamped = true
    /// Leaves the file in write-ahead-log mode.
    var walMode = false
    /// SQL run last, each making the export wrong in one way.
    var edits: [String] = []

    struct Document {
        let id: String
        let number: String?
        let header: String
        let body: String
        let frontMatter: Bool
    }

    static let documents: [String: [Document]] = [
        "frus1894Nicaragua": [
            Document(id: "d1", number: "1", header: "No. 1. Mr. Baker to Mr. Gresham",
                     body: "The canal concession and the Mosquito Reservation were discussed at length.", frontMatter: false),
            Document(id: "d2", number: "2", header: "No. 2. Mr. Gresham to Mr. Baker",
                     body: "The treaty with Nicaragua protects the canal route.", frontMatter: false),
            Document(id: "d3", number: nil, header: "Preface",
                     body: "This volume prints the correspondence on the Mosquito Reservation.", frontMatter: true),
        ],
        "frus1961-63v06": [
            Document(id: "d1", number: "1", header: "1. Telegram From the Embassy in the Soviet Union",
                     body: "The ambassador was negotiating treaties with the minister.", frontMatter: false),
            Document(id: "d2", number: "2", header: "2. Memorandum of Conversation",
                     body: "Negotiating began in May, and after many long weeks of talks the treaties came.", frontMatter: false),
            Document(id: "d3", number: nil, header: "Preface",
                     body: "The exchanges between Kennedy and Khrushchev.", frontMatter: true),
        ],
        "frus1969-76ve09p1": [
            Document(id: "d1", number: "1", header: "1. Memorandum From Kissinger to Nixon",
                     body: "Kissinger reported on the treaty negotiations in Moscow.", frontMatter: false),
            Document(id: "d2", number: "2", header: "2. Editorial Note",
                     body: "The editors note the summit's treaty talks.", frontMatter: false),
            Document(id: "d3", number: nil, header: "Abbreviations",
                     body: "NSC, National Security Council.", frontMatter: true),
        ],
    ]

    static let persons: [String: [(ref: String, name: String)]] = [
        "frus1894Nicaragua": [("p1", "Walter Q. Gresham"), ("p2", "Lewis Baker")],
        "frus1961-63v06": [("p1", "Nikita Khrushchev"), ("p2", "Henry Kissinger")],
        "frus1969-76ve09p1": [("p1", "Henry Kissinger"), ("p2", "Richard Nixon")],
    ]

    /// Writes the export to `url`, replacing any file there.
    func write(to url: URL) throws {
        for suffix in ["", "-journal", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        let db = try SQLiteConnection(url.path, readOnly: false, create: true)
        defer { db.close() }
        try db.execute(try SyntheticExport.schema())
        try db.execute("BEGIN")
        for volume in volumeOrder where volumes.contains(volume) { try insertVolume(volume, into: db) }
        try insertRollup(into: db)
        try db.execute("COMMIT")
        if fragmentsFullText { try fragment(db) }
        if stamped {
            let stamp = [
                ("exported_at", "2026-10-03T15:14:19Z"), ("my_writing_included", "0"), ("app_version", "0.2"),
                ("app_build", "49"), ("installed_index_version", "65"), ("current_index_version", "65"),
                ("installed_fts_schema_version", "4"), ("current_fts_schema_version", "4"),
            ]
            for (key, value) in stamp {
                _ = try db.query("INSERT INTO research_provenance (key, value) VALUES (?, ?)", [.text(key), .text(value)])
            }
        } else {
            try db.execute("""
                DROP VIEW research_documents; DROP VIEW research_cross_references;
                DROP VIEW research_suppressed_volumes; DROP TABLE research_provenance;
                """)
        }
        try db.execute("PRAGMA user_version = 4")
        for edit in edits { try db.execute(edit) }
        try db.execute(walMode ? "PRAGMA journal_mode = WAL" : "PRAGMA journal_mode = DELETE")
    }

    private func insertVolume(_ volume: String, into db: SQLiteConnection) throws {
        func insert(_ table: String, _ columns: [String], _ values: [SQLiteValue]) throws {
            let marks = Array(repeating: "?", count: values.count).joined(separator: ", ")
            _ = try db.query("INSERT INTO \(table) (\(columns.joined(separator: ", "))) VALUES (\(marks))", values)
        }
        let others = ParityFixtures.volumes.filter { $0 != volume }
        let year = volume.dropFirst(4).prefix(4)
        let documents = Array(Self.documents[volume]!.enumerated())
        for (index, doc) in volume == reversedDocuments ? documents.reversed() : documents {
            try insert("document_cache",
                       ["volume_id", "document_id", "document_number", "header", "dateline", "source_note", "body_text",
                        "subject_tag_ids", "is_editorial_note", "is_front_matter", "despatch_serial"],
                       [.text(volume), .text(doc.id), text(doc.number), .text(doc.header),
                        doc.frontMatter ? .null : .text("Washington, \(year)"),
                        doc.frontMatter ? .null : .text("Source: Department of State, Central Files."),
                        .text(doc.body), doc.frontMatter ? .null : .text("s\(index + 1)"),
                        .integer(doc.header.contains("Editorial") ? 1 : 0), .integer(doc.frontMatter ? 1 : 0),
                        index == 0 ? .text("No. \(index + 17)") : .null])
            try insert("document_dates", ["volume_id", "document_id", "date_iso", "date_iso_max", "date_precision", "date_certainty"],
                       doc.frontMatter ? [.text(volume), .text(doc.id), .null, .null, .null, .null]
                           : [.text(volume), .text(doc.id), .text("\(year)-0\(index + 1)-15"), .text("\(year)-0\(index + 1)-15"),
                              .text("day"), .text("stated")])
            try insert("document_revisions", ["volume_id", "document_id", "content_hash", "body_hash", "index_version"],
                       [.text(volume), .text(doc.id), .text(Digest.sha256("\(volume)/\(doc.id)/content")),
                        .text(String(Digest.sha256(doc.body).prefix(16))), .integer(65)])
            guard !doc.frontMatter else { continue }
            try insert("document_sources",
                       ["volume_id", "document_id", "repository", "record_group", "series_name", "citation_era", "raw_text", "classification"],
                       [.text(volume), .text(doc.id), .text("National Archives"), .text("RG 59"), .text("Central Files"),
                        .text("modern"), .text("Source: National Archives, RG 59, Central Files."), .text("Secret")])
            try insert("document_subjects", ["volume_id", "document_id", "bucket"], [.text(volume), .text(doc.id), .integer(Int64(3 + index * 4))])
            try insert("document_subject_refs", ["volume_id", "document_id", "subject"], [.text(volume), .text(doc.id), .integer(Int64(101 + index))])
        }
        try insert("external_citations",
                   ["volume_id", "document_id", "note_ordinal", "note_label", "citation_index", "anchor", "repository",
                    "collection", "file_id", "inherited", "raw_text"],
                   [.text(volume), .text("d1"), .integer(1), .text("1"), .integer(0), .text("fn1"), .text("National Archives"),
                    .text("RG 59"), .text("file-1"), .integer(0), .text("National Archives, RG 59.")])
        try insert("document_subject_volumes", ["volume_id", "digest"], [.text(volume), .text("digest-\(volume)")])
        for (order, entry) in ["Department of State, Central Files", "Lot Files"].enumerated() {
            try insert("volume_sources",
                       ["volume_id", "repository", "record_group", "entry_text", "kind", "depth", "is_heading", "sort_order", "note"],
                       [.text(volume), .text("National Archives"), .text("RG 59"), .text(entry), .text("item"), .integer(0),
                        .integer(Int64(order)), .integer(Int64(order)), order == 1 ? .text("A note.") : .null])
        }
        try insert("volume_structures", ["volume_id", "structure_json"], [.text(volume), .text(structureJSON(volume))])
        try insert("cross_references",
                   ["source_volume_id", "source_document_id", "target_volume_id", "target_document_id", "is_broken", "reference_type", "context"],
                   [.text(volume), .text("d1"), .null, .text("d2"), .integer(0), .text("document"), .text("See Document 2.")])
        try insert("cross_references",
                   ["source_volume_id", "source_document_id", "target_volume_id", "target_document_id", "is_broken", "reference_type", "context"],
                   [.text(volume), .text("d2"), .text(others[0]), .text("d1"), .integer(0), .text("document"), .null])
        try insert("cross_references",
                   ["source_volume_id", "source_document_id", "target_volume_id", "target_document_id", "is_broken", "reference_type", "context"],
                   [.text(volume), .text("d3"), .null, .text("pg_12"), .integer(1), .null, .null])
        let pages: [(String, String, String, Int64?, String, Int64)] = [
            ("d1", "ch1", "arabic", 1, "1", 1), ("d1", "ch1", "arabic", 2, "2", 0), ("d2", "ch1", "arabic", 2, "2", 1),
            ("d2", "ch1", "arabic", 3, "3", 0), ("d3", "front", "roman", nil, "iii", 1),
        ]
        for page in pages {
            try insert("page_ranges",
                       ["volume_id", "document_id", "section_id", "page_number_type", "page_number_int", "page_number_raw", "is_start"],
                       [.text(volume), .text(page.0), .text(page.1), .text(page.2), page.3.map(SQLiteValue.integer) ?? .null,
                        .text(page.4), .integer(page.5)])
        }
        for (index, person) in Self.persons[volume]!.enumerated() {
            try insert("persons", ["volume_id", "ref", "name", "description", "role", "start_year", "end_year"],
                       [.text(volume), .text(person.ref), .text(person.name), .text("\(person.name), a figure in \(volume)."),
                        index == 0 ? .text("Secretary") : .null, .integer(1890 + Int64(index)), .null])
        }
        for (document, ref) in [("d1", "p1"), ("d2", "p1"), ("d2", "p2")] {
            try insert("person_mentions", ["volume_id", "document_id", "person_ref"], [.text(volume), .text(document), .text(ref)])
        }
        if volume == "frus1969-76ve09p1" {
            try insert("person_list_sources", ["volume_id", "source_volume_id"], [.text(volume), .text("frus1961-63v06")])
        }
        for (ref, term, definition) in [("t1", "NSC", "National Security Council"), ("t2", "Deptel", "Department of State telegram")] {
            try insert("terms", ["volume_id", "ref", "term", "definition"], [.text(volume), .text(ref), .text(term), .text(definition)])
        }
    }

    /// One rollup per person name, ordered by its least member, then numbered as `rollupNumbering` says.
    private func insertRollup(into db: SQLiteConnection) throws {
        var clusters: [String: [(volume: String, ref: String)]] = [:]
        for volume in volumes {
            for person in Self.persons[volume]! { clusters[person.name, default: []].append((volume, person.ref)) }
        }
        let ordered = clusters.sorted { a, b in
            let x = a.value.min { ($0.volume, $0.ref) < ($1.volume, $1.ref) }!
            let y = b.value.min { ($0.volume, $0.ref) < ($1.volume, $1.ref) }!
            return (x.volume, x.ref) < (y.volume, y.ref)
        }
        var ids: [String: Int64] = [:]
        for (index, cluster) in ordered.enumerated() {
            let id: Int64 = switch rollupNumbering {
            case .sequential: Int64(index + 1)
            case .offset(let offset): Int64(index + 1) + offset
            case .reversed: Int64(ordered.count - index)
            }
            ids[cluster.key] = id
        }
        for (name, members) in ordered.sorted(by: { ids[$0.key]! < ids[$1.key]! }) {
            _ = try db.query("""
                INSERT INTO person_rollup (rollup_id, namekey, canonical_name, description, mention_count, role, start_year, volume_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, [.integer(ids[name]!), .text(name.lowercased()), .text(name), .text("\(name)."),
                      .integer(Int64(members.count * 2)), .null, .integer(1890), .integer(Int64(members.count))])
            for member in members {
                _ = try db.query("INSERT INTO person_rollup_member (volume_id, ref, rollup_id) VALUES (?, ?, ?)",
                                 [.text(member.volume), .text(member.ref), .integer(ids[name]!)])
            }
        }
        if let a = ids["Nikita Khrushchev"], let b = ids["Richard Nixon"] {
            _ = try db.query("INSERT INTO person_cluster_candidate (rollup_id_a, rollup_id_b, reason) VALUES (?, ?, ?)",
                             [.integer(min(a, b)), .integer(max(a, b)), .text("co-mentioned")])
        }
    }

    /// Rewrites the first volume's bodies and back, which deletes and reinserts their entries
    /// under the same rowids, then deletes the second volume's documents and inserts them again
    /// in the same order under new rowids.
    private func fragment(_ db: SQLiteConnection) throws {
        let present = volumeOrder.filter { volumes.contains($0) }
        guard present.count >= 2 else { return }
        for doc in Self.documents[present[0]]! {
            for body in ["A placeholder body.", doc.body] {
                _ = try db.query("UPDATE document_cache SET body_text = ? WHERE volume_id = ? AND document_id = ?",
                                 [.text(body), .text(present[0]), .text(doc.id)])
            }
        }
        _ = try db.query("CREATE TEMP TABLE kept AS SELECT * FROM document_cache WHERE volume_id = ? ORDER BY rowid", [.text(present[1])])
        _ = try db.query("DELETE FROM document_cache WHERE volume_id = ?", [.text(present[1])])
        try db.execute("INSERT INTO document_cache SELECT * FROM temp.kept ORDER BY rowid; DROP TABLE temp.kept")
    }

    /// The volume's structure, as the app's JSONEncoder might write it: with keys in either order.
    private func structureJSON(_ volume: String) -> String {
        func object(_ pairs: [(String, String)]) -> String {
            let ordered = reversesJSONKeys ? pairs.reversed() : pairs
            return "{" + ordered.map { "\"\($0.0)\":\($0.1)" }.joined(separator: ",") + "}"
        }
        let chapters = [
            object([("id", "\"ch1\""), ("title", "\"Chapter One\""), ("documents", "[\"d1\",\"d2\"]")]),
            object([("id", "\"front\""), ("title", "\"Front Matter\""), ("documents", "[\"d3\"]"), ("roman", "true")]),
        ]
        return object([("volume", "\"\(volume)\""), ("title", "\"The volume \(volume)\""),
                       ("chapters", "[" + chapters.joined(separator: ",") + "]"), ("count", "3"), ("scale", "1.5")])
    }

    private func text(_ value: String?) -> SQLiteValue { value.map(SQLiteValue.text) ?? .null }
}

/// Writes `export` to a temporary file and summarizes it.
func summarize(_ export: ParityExport, anyVolumes: Bool = false, fullCheckLimit: Int64 = IndexSummarizer.defaultFullCheckLimit,
               prepare: (URL) throws -> Void = { _ in }) throws -> IndexSummaryGolden {
    let directory = try TemporaryDirectory()
    return try withExtendedLifetime(directory) {
        let url = directory.url.appendingPathComponent("export.sqlite")
        try export.write(to: url)
        try prepare(url)
        return try IndexSummarizer(upstream: Repository.layout.upstream, anyVolumes: anyVolumes, fullCheckLimit: fullCheckLimit)
            .summarize(url)
    }
}
