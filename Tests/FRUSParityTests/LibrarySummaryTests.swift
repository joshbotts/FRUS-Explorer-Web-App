// Check 2 at full scale (PLAN's S25b): a library summary reads a library the app upgraded in place as the
// index it holds, every row and hash still gating, with what the library's upgrades and history left apart,
// for information; it compares only with another and is never a golden file. And corrections made in the
// app are given to another index of the same files through the kit's own calls (`LibraryCorrections`).

import FRUSLightCore
import FRUSLightTestSupport
@testable import FRUSParity
import Foundation
import ParityFormat
import Testing

/// What the owner's full exports hold where their library's upgrades left it (S12d's entry): two tables'
/// columns where `ALTER TABLE … ADD COLUMN` appended them, `person_mentions` without the `UNIQUE` a later
/// version declares, each table's statement as that library stores it; and the revisions of a document the
/// corpus later dropped, at the version that last indexed it, and a held document's history.
enum UpgradedLibrary {
    static let layout = [
        """
        PRAGMA legacy_alter_table = ON;
        CREATE TABLE cross_references_upgraded ( id INTEGER PRIMARY KEY AUTOINCREMENT, source_volume_id TEXT NOT NULL, \
        source_document_id TEXT NOT NULL, target_volume_id TEXT, target_document_id TEXT NOT NULL , reference_type TEXT, \
        context TEXT, is_broken INTEGER NOT NULL DEFAULT 0);
        INSERT INTO cross_references_upgraded (id, source_volume_id, source_document_id, target_volume_id, target_document_id, \
        reference_type, context, is_broken) SELECT id, source_volume_id, source_document_id, target_volume_id, \
        target_document_id, reference_type, context, is_broken FROM cross_references ORDER BY id;
        DROP TABLE cross_references;
        ALTER TABLE cross_references_upgraded RENAME TO cross_references;
        CREATE INDEX idx_crossref_source ON cross_references(source_volume_id, source_document_id);
        CREATE INDEX idx_crossref_target ON cross_references(target_document_id);
        """,
        """
        PRAGMA legacy_alter_table = ON;
        CREATE TABLE external_citations_upgraded ( volume_id TEXT NOT NULL, document_id TEXT NOT NULL, note_ordinal INTEGER NOT NULL, \
        citation_index INTEGER NOT NULL, anchor TEXT NOT NULL, repository TEXT, collection TEXT, lot_file TEXT, lot_file_norm TEXT, \
        file_id TEXT, inherited INTEGER NOT NULL DEFAULT 0, raw_text TEXT NOT NULL, decimal_class TEXT, note_label TEXT, \
        PRIMARY KEY (volume_id, document_id, note_ordinal, citation_index) );
        INSERT INTO external_citations_upgraded SELECT volume_id, document_id, note_ordinal, citation_index, anchor, repository, \
        collection, lot_file, lot_file_norm, file_id, inherited, raw_text, decimal_class, note_label FROM external_citations;
        DROP TABLE external_citations;
        ALTER TABLE external_citations_upgraded RENAME TO external_citations;
        CREATE INDEX idx_ext_cit_class ON external_citations(decimal_class);
        CREATE INDEX idx_ext_cit_doc ON external_citations(volume_id, document_id);
        CREATE INDEX idx_ext_cit_lot_norm ON external_citations(lot_file_norm);
        CREATE INDEX idx_ext_cit_repo_collection ON external_citations(repository, collection);
        """,
        """
        PRAGMA legacy_alter_table = ON;
        CREATE TABLE person_mentions_upgraded ( id INTEGER PRIMARY KEY AUTOINCREMENT, volume_id TEXT NOT NULL, \
        document_id TEXT NOT NULL, person_ref TEXT NOT NULL );
        INSERT INTO person_mentions_upgraded (id, volume_id, document_id, person_ref) SELECT id, volume_id, document_id, person_ref \
        FROM person_mentions ORDER BY id;
        DROP TABLE person_mentions;
        ALTER TABLE person_mentions_upgraded RENAME TO person_mentions;
        CREATE INDEX idx_person_mentions_doc ON person_mentions(volume_id, document_id);
        CREATE INDEX idx_person_mentions_ref ON person_mentions(person_ref);
        CREATE INDEX idx_person_mentions_volref ON person_mentions(volume_id, person_ref);
        PRAGMA legacy_alter_table = OFF;
        """,
    ]

    static let history = [
        """
        INSERT INTO document_revisions (volume_id, document_id, content_hash, body_hash, changed_at, change_kind, reviewed_at, index_version) \
        VALUES ('frus1961-63v06', 'd404', 'the content of a document the corpus dropped', 'its body', NULL, 'vanished', NULL, 62)
        """,
        """
        UPDATE document_revisions SET changed_at = '2026-11-01T12:00:00Z', change_kind = 'body', reviewed_at = '2026-11-02T09:00:00Z' \
        WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd2'
        """,
    ]

    static var export: ParityExport {
        var export = ParityExport()
        export.edits = layout + history
        return export
    }
}

@Suite struct LibrarySummaryTests {
    /// The owner's full export's case: a golden summary refuses the library for its columns' places, and a
    /// library summary of it gates exactly what one of the index it holds gates, the layout and history apart.
    @Test func aLibrarySummaryReadsAnUpgradedLibraryAsTheIndexItHolds() throws {
        let refusal = #expect(throws: SummaryRefusal.self) { _ = try summarize(UpgradedLibrary.export) }
        #expect(refusal?.kind == .schema, "\(refusal?.reason ?? "no refusal")")

        let index = try summarize(ParityExport(), library: true)
        let library = try summarize(UpgradedLibrary.export, library: true)
        let differences = IndexSummaryComparison.differences(golden: index, candidate: library)
        #expect(differences.isEmpty, "\(differences.map(\.description).joined(separator: "\n"))")
        #expect(library.gating.isLibrary && index.gating.isLibrary)
        #expect(library.gating.checks["document_revisions.history"] == nil)

        // The library's layout and history, each said and none compared.
        let information = IndexSummaryComparison.informationDifferences(golden: index, candidate: library)
        #expect(Set(information.map(\.item)) == [
            "document_revisions.dropped", "document_revisions.history", "document_revisions.sequence", "schema", "schema.constraints",
        ], "\(information.map(\.description))")
        #expect(index.information.digests["document_revisions.dropped"]?.rows == 0)
        #expect(library.information.digests["document_revisions.dropped"]?.rows == 1)
        #expect(library.information.digests["document_revisions.dropped"]?.volumes?["frus1961-63v06"]?.rows == 1)
        #expect(library.information.digests["document_revisions.history"]?.rows == 2)
        #expect(library.gating.digests["document_revisions"]?.rows == index.gating.digests["document_revisions"]?.rows)
        for table in ["cross_references", "external_citations"] {
            #expect(library.information.notes.contains { $0.hasPrefix("\(table) holds its columns in the order") }, "\(table)")
        }
        #expect(!index.information.notes.contains { $0.contains("holds its columns in the order") })
        #expect(library.report().hasPrefix("a library summary"))
    }

    /// Every row and hash still gates: a word, a held revision's hash, a column's definition, an index.
    @Test func aLibrarySummaryStillGatesEveryRow() throws {
        let library = try summarize(UpgradedLibrary.export, library: true)
        func differing(_ edit: String) throws -> Set<String> {
            var export = UpgradedLibrary.export
            export.edits.append(edit)
            return Set(IndexSummaryComparison.differences(golden: library, candidate: try summarize(export, library: true)).map(\.item))
        }
        #expect(try differing("UPDATE document_cache SET body_text = replace(body_text, 'canal route', 'canal zone') WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd2'")
                .isSuperset(of: ["document_cache", "frus_documents.vocab_row"]))
        #expect(try differing("UPDATE document_revisions SET body_hash = 'another' WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd1'")
                == ["document_revisions"])
        #expect(try differing("UPDATE cross_references SET is_broken = 1 - is_broken WHERE id = (SELECT min(id) FROM cross_references)")
                .contains("cross_references"))
        #expect(try differing("DROP INDEX idx_person_mentions_ref") == ["schema.statements"])
        #expect(try differing("CREATE INDEX idx_terms_extra ON terms(term)") == ["schema.statements"])

        // A held document's revision at another version is refused, as a golden summary refuses it.
        var stale = UpgradedLibrary.export
        stale.edits.append("UPDATE document_revisions SET index_version = 62 WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd1'")
        let refusal = #expect(throws: SummaryRefusal.self) { _ = try summarize(stale, library: true) }
        #expect(refusal?.kind == .versions)
        #expect(refusal?.reason.contains("rows of documents the index holds") == true)

        // A column the version does not have, or one it lacks, is refused as before: only places change.
        var extra = UpgradedLibrary.export
        extra.edits.append("ALTER TABLE terms ADD COLUMN source TEXT")
        #expect(throws: SummaryRefusal.self) { _ = try summarize(extra, library: true) }
    }

    /// A new index's library summary gates every row a golden summary gates, by the same statements, but
    /// for the revisions, which it takes of the documents the index holds, the schema, which it reads by
    /// the tables' columns and the other statements' text, and the order of `document_cache`, which the kit
    /// upserts, so that a library's is its history (`LibraryOrder`).
    @Test func aNewIndexsLibrarySummaryGatesWhatAGoldenSummaryGates() throws {
        let golden = try summarize(ParityExport())
        let library = try summarize(ParityExport(), library: true)
        for (name, digest) in golden.gating.digests where !["schema", "document_revisions", "document_cache.sequence"].contains(name) {
            #expect(library.gating.digests[name] == digest, "\(name)")
        }
        #expect(library.gating.digests["document_revisions"]?.sha256 != nil)
        #expect(library.gating.digests["document_revisions"]?.rows == golden.gating.digests["document_revisions"]?.rows)
        #expect(library.information.digests["schema"] == golden.gating.digests["schema"])
        #expect(library.information.digests["document_cache.sequence"] == golden.gating.digests["document_cache.sequence"])
        // The order of the tables the kit writes again a volume at a time still gates.
        #expect(library.gating.digests["page_ranges.sequence"] != nil && library.gating.digests["cross_references.sequence"] != nil)
        #expect(Set(library.gating.digests.keys).subtracting(golden.gating.digests.keys) == ["schema.columns", "schema.statements"])
        #expect(Set(golden.gating.digests.keys).subtracting(library.gating.digests.keys) == ["schema", "document_cache.sequence"])
        #expect(library.gating.digests["schema.columns"].map { $0.rows > 0 } == true)
        #expect(library.gating.volumes == golden.gating.volumes)
        var checks = golden.gating.checks
        checks["document_revisions.history"] = nil
        #expect(library.gating.checks == checks)
    }

    /// A library summary compares only with another, and never stands as the golden file.
    @Test func aLibrarySummaryComparesOnlyWithAnotherAndIsNeverGolden() throws {
        let golden = try summarize(ParityExport())
        let library = try summarize(ParityExport(), library: true)
        for (a, b) in [(golden, library), (library, golden)] {
            let differences = IndexSummaryComparison.differences(golden: a, candidate: b)
            #expect(differences.map(\.item) == ["library"], "\(differences)")
        }
        #expect(GoldenValidation.indexSummaryProblems(library).contains { $0.contains("is a library summary") })
        #expect(!GoldenValidation.indexSummaryProblems(golden).contains { $0.contains("library summary") })

        // Written out, a golden summary names no library, so its file is as it was; a library summary's says so.
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            for (name, summary) in [("golden.json", golden), ("library.json", library)] {
                let url = directory.url.appendingPathComponent(name)
                try GoldenJSON.write(summary, to: url)
                #expect(try GoldenJSON.read(IndexSummaryGolden.self, from: url) == summary)
                let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
                #expect(text.contains("\"library\"") == summary.gating.isLibrary, "\(name)")
            }
        }
    }

    // MARK: - The order of a library's documents

    /// One document of a volume stored again after every other, as a later index version's pass appends a
    /// document it began to hold.
    static func storedAgainLast(_ volume: String, _ document: String) -> String {
        """
        CREATE TEMP TABLE moved AS SELECT * FROM document_cache WHERE volume_id = '\(volume)' AND document_id = '\(document)';
        DELETE FROM document_cache WHERE volume_id = '\(volume)' AND document_id = '\(document)';
        INSERT INTO document_cache SELECT * FROM moved;
        DROP TABLE moved;
        """
    }

    /// A library's order is reported volume by volume: the index's, runs of passes each in the index's order,
    /// or out of order within a run; and refused only where the two hold other documents. A library summary
    /// gates none of it, where a golden summary gates it.
    @Test func theOrderOfALibrarysDocumentsIsReportedNotGated() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            func written(_ export: ParityExport, _ name: String) throws -> URL {
                let url = directory.url.appendingPathComponent(name)
                try export.write(to: url)
                return url
            }
            let index = try written(ParityExport(), "index.sqlite")
            let same = try LibraryOrder.compare(library: index, index: index)
            #expect(same.volumes == 3 && same.sameOrder == 3 && same.passes.isEmpty && same.outOfOrder.isEmpty && same.holdsTheSameDocuments)

            var appended = ParityExport()
            appended.edits = [Self.storedAgainLast("frus1894Nicaragua", "d1")]
            let later = try LibraryOrder.compare(library: try written(appended, "appended.sqlite"), index: index)
            #expect(later.sameOrder == 2 && later.passes == ["frus1894Nicaragua": 2] && later.laterRows == 1 && later.outOfOrder.isEmpty)
            #expect(later.singleRowRuns == 1)
            #expect(later.summary().hasPrefix("3 volumes: 2 in the index's order; 1 in runs of consecutive rowids"))

            var reversed = ParityExport()
            reversed.reversedDocuments = "frus1961-63v06"
            let backwards = try LibraryOrder.compare(library: try written(reversed, "reversed.sqlite"), index: index)
            #expect(backwards.outOfOrder.keys.sorted() == ["frus1961-63v06"] && backwards.passes.isEmpty)
            #expect(backwards.summary().contains("out of order within a run: frus1961-63v06:"))

            var fewer = ParityExport()
            fewer.edits = ["DELETE FROM document_cache WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd3'"]
            let other = try LibraryOrder.compare(library: try written(fewer, "fewer.sqlite"), index: index)
            #expect(!other.holdsTheSameDocuments && other.differentDocuments.keys.sorted() == ["frus1894Nicaragua"])

            // A file whose log holds pages is refused, as the summary refuses it: `immutable=1` would not read them.
            var logged = ParityExport()
            logged.walMode = true
            let open = try written(logged, "open.sqlite")
            try Data("an uncheckpointed page".utf8).write(to: URL(fileURLWithPath: open.path + "-wal"))
            let refusal = #expect(throws: SummaryRefusal.self) { _ = try LibraryOrder.compare(library: open, index: index) }
            #expect(refusal?.kind == .inUse)
        }

        var appended = ParityExport()
        appended.edits = [Self.storedAgainLast("frus1894Nicaragua", "d1")]
        let golden = IndexSummaryComparison.differences(golden: try summarize(ParityExport()), candidate: try summarize(appended))
        #expect(golden.map(\.item) == ["document_cache.sequence", "document_cache.sequence"], "\(golden)")
        let library = IndexSummaryComparison.differences(golden: try summarize(ParityExport(), library: true),
                                                         candidate: try summarize(appended, library: true))
        #expect(library.isEmpty, "\(library)")
    }

    // MARK: - Corrections made in the app, given to another index

    /// A copy of the kit's own index of the fixtures, to write.
    static func writableFixtureIndex(in directory: TemporaryDirectory) async throws -> URL {
        let built = try await FixtureIndex.value()
        let url = directory.url.appendingPathComponent("corrected.db")
        try FileManager.default.copyItem(at: built.copy, to: url)
        return url
    }

    /// The kit's own calls make the corrections what the app's make them: the document's classification, and
    /// two people one identity, the summary changing only where they do, and the log folded into the file.
    @Test func correctionsAreGivenThroughTheKitsOwnCalls() async throws {
        let directory = try TemporaryDirectory()
        let url = try await Self.writableFixtureIndex(in: directory)
        let layout = Repository.layout
        let before = try IndexSummarizer(layout: layout).summarize(url)

        // A document the TEI makes a document, and two people of two volumes in two identities.
        let db = try ParityDatabase.readOnly(url)
        let document = try #require(try db.rows("""
            SELECT volume_id, document_id FROM document_cache WHERE is_editorial_note = 0 AND is_front_matter = 0 ORDER BY volume_id, document_id LIMIT 1
            """).first)
        let pair = try #require(try db.rows("""
            SELECT a.volume_id, a.ref, b.volume_id, b.ref FROM person_rollup_member a, person_rollup_member b
            WHERE a.volume_id = 'frus1961-63v06' AND b.volume_id = 'frus1969-76ve09p1' AND a.rollup_id <> b.rollup_id
            ORDER BY a.ref, b.ref LIMIT 1
            """).first)
        let corrections = LibraryCorrections(
            classifications: [.init(volumeId: document[0].text!, documentId: document[1].text!, isEditorialNote: true)],
            people: [.init(kind: "merge", volumeIdA: pair[0].text!, refA: pair[1].text!, volumeIdB: pair[2].text!, refB: pair[3].text!)])

        let applied = try await corrections.apply(to: url, resources: layout.upstream.appendingPathComponent(ParityIndex.resourcesPath))
        #expect(applied.classificationsChanged == 1)
        #expect(applied.personCorrections == 1)
        #expect(applied.rollupsAfter == applied.rollupsBefore - 1)
        // The log is folded, so the summary reads the file.
        let wal = (try? FileManager.default.attributesOfItem(atPath: url.path + "-wal")[.size] as? NSNumber)?.intValue ?? 0
        #expect(wal == 0)

        let after = try IndexSummarizer(layout: layout).summarize(url)
        let check = try ParityDatabase.readOnly(url)
        #expect(try check.scalar("SELECT is_editorial_note FROM document_cache WHERE volume_id = '\(document[0].text!)' AND document_id = '\(document[1].text!)'")?.integer == 1)
        #expect(try check.scalar("""
            SELECT count(DISTINCT rollup_id) FROM person_rollup_member
            WHERE (volume_id = '\(pair[0].text!)' AND ref = '\(pair[1].text!)') OR (volume_id = '\(pair[2].text!)' AND ref = '\(pair[3].text!)')
            """)?.integer == 1)
        let differences = Set(IndexSummaryComparison.differences(golden: before, candidate: after).map(\.item))
        #expect(differences.isSuperset(of: ["document_cache", "person_rollup", "person_rollup_member"]), "\(differences)")
        #expect(differences.isSubset(of: ["document_cache", "person_rollup", "person_rollup_member", "person_cluster_candidate"]), "\(differences)")

        // Given again, the corrections change nothing more.
        let again = try await corrections.apply(to: url, resources: layout.upstream.appendingPathComponent(ParityIndex.resourcesPath))
        #expect(again.classificationsChanged == 0 && again.rollupsAfter == again.rollupsBefore)
        #expect(IndexSummaryComparison.differences(golden: after, candidate: try IndexSummarizer(layout: layout).summarize(url)).isEmpty)
        withExtendedLifetime(directory) {}
    }

    /// A correction naming what the index does not hold is refused, where the kit would pass it over.
    @Test func aCorrectionTheIndexCannotTakeIsRefused() async throws {
        let directory = try TemporaryDirectory()
        let url = try await Self.writableFixtureIndex(in: directory)
        let resources = Repository.layout.upstream.appendingPathComponent(ParityIndex.resourcesPath)
        let cases = [
            LibraryCorrections(classifications: [.init(volumeId: "frus1894Nicaragua", documentId: "d999", isEditorialNote: true)]),
            LibraryCorrections(people: [.init(kind: "merge", volumeIdA: "frus1894Nicaragua", refA: "nobody", volumeIdB: "frus1961-63v06", refB: "nobody")]),
            LibraryCorrections(people: [.init(kind: "merge", volumeIdA: "frus1894Nicaragua", refA: "p1")]),
            LibraryCorrections(people: [.init(kind: "join", volumeIdA: "frus1894Nicaragua", refA: "p1")]),
            LibraryCorrections(classifications: [.init(volumeId: "frus1894Nicaragua", documentId: "d1", isEditorialNote: true),
                                                 .init(volumeId: "frus1894Nicaragua", documentId: "d1", isEditorialNote: false)]),
        ]
        for corrections in cases {
            await #expect(throws: LibraryCorrectionsError.self) { _ = try await corrections.apply(to: url, resources: resources) }
        }
        withExtendedLifetime(directory) {}
    }

    /// The file a run reads names each correction by the kit's names.
    @Test func aCorrectionsFileReadsAsTheKitsValues() throws {
        let json = """
            {"classifications": [{"volumeId": "frus1943", "documentId": "ch2subsubch11", "isEditorialNote": true}],
             "people": [{"kind": "merge", "volumeIdA": "frus1945Berlinv02", "refA": ",\\n  Chief of Staff of the Red Army",
                         "volumeIdB": "frus1943CairoTehran", "refB": "p_AAI1"}, {"kind": "split", "volumeIdA": "frus1961-63v06", "refA": "p2"}]}
            """
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let url = directory.url.appendingPathComponent("corrections.json")
            try Data(json.utf8).write(to: url)
            let corrections = try LibraryCorrections.read(from: url)
            #expect(corrections.classifications == [.init(volumeId: "frus1943", documentId: "ch2subsubch11", isEditorialNote: true)])
            let overrides = try corrections.personOverrides()
            #expect(overrides.map(\.kind) == [.merge, .split])
            #expect(overrides[0].refA == ",\n  Chief of Staff of the Red Army" && overrides[0].refB == "p_AAI1")
            #expect(overrides[1].volumeIdB == nil && overrides[1].refB == nil)
        }
    }
}
