// Check 2's summary: the same rows stored differently summarize the same, one changed word changes
// only its own table and volume, and every database a golden summary cannot stand for is refused.

import CSQLite
import FRUSLightCore
import FRUSLightTestSupport
@testable import FRUSParity
import Foundation
import ParityFormat
import Testing

/// Ways to store the same rows differently, none of which may change a gating digest.
enum StorageVariant: String, CaseIterable, Sendable {
    case volumeOrder, rollupIdsOffset, rollupIdsReversed, jsonKeysReversed, fullTextFragmented, allAtOnce, unstamped

    var export: ParityExport {
        var export = ParityExport()
        switch self {
        case .volumeOrder: export.volumeOrder = ["frus1969-76ve09p1", "frus1894Nicaragua", "frus1961-63v06"]
        case .rollupIdsOffset: export.rollupNumbering = .offset(1_000)
        case .rollupIdsReversed: export.rollupNumbering = .reversed
        case .jsonKeysReversed: export.reversesJSONKeys = true
        case .fullTextFragmented: export.fragmentsFullText = true
        case .allAtOnce:
            export.volumeOrder = ["frus1961-63v06", "frus1969-76ve09p1", "frus1894Nicaragua"]
            export.rollupNumbering = .reversed
            export.reversesJSONKeys = true
            export.fragmentsFullText = true
        case .unstamped: export.stamped = false
        }
        return export
    }
}

/// Each database the summary must refuse, and why.
enum RefusalCase: String, CaseIterable, Sendable {
    case twoVolumes, volumeOutsideTheIndex
    case writingStamped, noteText, userTag, userTagIds
    case userVersion, revisionIndexVersion, stampIndexVersion, stampFTSVersion
    case rollupMemberMissing, personWithoutMember, rollupEmpty
    case extraTable, extraView, extraFullTextTable, extraColumn, missingTable
    case walInUse, notADatabase

    var kind: SummaryRefusal.Kind {
        switch self {
        case .twoVolumes, .volumeOutsideTheIndex: .volumes
        case .writingStamped, .noteText, .userTag, .userTagIds: .writing
        case .userVersion, .revisionIndexVersion, .stampIndexVersion, .stampFTSVersion: .versions
        case .rollupMemberMissing, .personWithoutMember, .rollupEmpty: .staleRollup
        case .extraTable, .extraView, .extraFullTextTable, .extraColumn, .missingTable: .schema
        case .walInUse: .inUse
        case .notADatabase: .notADatabase
        }
    }

    var export: ParityExport {
        var export = ParityExport()
        switch self {
        case .twoVolumes: export.volumes = ["frus1894Nicaragua", "frus1961-63v06"]
        case .volumeOutsideTheIndex: export.edits = ["INSERT INTO terms VALUES ('frus1900', 't1', 'NSC', 'National Security Council')"]
        case .writingStamped: export.edits = ["UPDATE research_provenance SET value = '1' WHERE key = 'my_writing_included'"]
        case .noteText: export.edits = ["UPDATE document_cache SET note_text = 'A planted note' WHERE volume_id = 'frus1961-63v06' AND document_id = 'd1'"]
        case .userTag: export.edits = ["INSERT INTO user_tags (tag_id, name) VALUES ('t1', 'Berlin crisis')"]
        case .userTagIds: export.edits = ["UPDATE document_cache SET user_tag_ids = 't1' WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd2'"]
        case .userVersion: export.edits = ["PRAGMA user_version = 3"]
        case .revisionIndexVersion: export.edits = ["UPDATE document_revisions SET index_version = 64 WHERE document_id = 'd2'"]
        case .stampIndexVersion: export.edits = ["UPDATE research_provenance SET value = '64' WHERE key = 'current_index_version'"]
        case .stampFTSVersion: export.edits = ["UPDATE research_provenance SET value = '3' WHERE key = 'installed_fts_schema_version'"]
        case .rollupMemberMissing: export.edits = ["DELETE FROM person_rollup_member WHERE volume_id = 'frus1894Nicaragua' AND ref = 'p1'"]
        case .personWithoutMember: export.edits = ["UPDATE person_rollup_member SET ref = 'p9' WHERE volume_id = 'frus1894Nicaragua' AND ref = 'p1'"]
        case .rollupEmpty: export.edits = ["DELETE FROM person_cluster_candidate", "DELETE FROM person_rollup"]
        case .extraTable: export.edits = ["CREATE TABLE reading_list (volume_id TEXT, document_id TEXT)"]
        case .extraView: export.edits = ["CREATE VIEW recent_documents AS SELECT * FROM document_cache"]
        case .extraFullTextTable: export.edits = ["CREATE VIRTUAL TABLE notes_index USING fts5(body)"]
        case .extraColumn: export.edits = ["ALTER TABLE terms ADD COLUMN source TEXT"]
        case .missingTable: export.edits = ["DROP TABLE terms"]
        case .walInUse: export.walMode = true
        case .notADatabase: break
        }
        return export
    }

    /// Work on the file after it is written.
    func prepare(_ url: URL) throws {
        switch self {
        case .walInUse: try Data("an uncheckpointed page".utf8).write(to: URL(fileURLWithPath: url.path + "-wal"))
        case .notADatabase: try Data(repeating: 0x41, count: 4_096).write(to: url)
        default: break
        }
    }
}

@Suite struct SummarizerTests {
    @Test(arguments: StorageVariant.allCases)
    func gatingIgnoresHowTheSameRowsAreStored(_ variant: StorageVariant) throws {
        let base = try summarize(ParityExport())
        let summary = try summarize(variant.export)
        let differences = IndexSummaryComparison.differences(golden: base, candidate: summary)
        #expect(differences.isEmpty, "\(differences.map(\.description).joined(separator: "\n"))")
        #expect(IndexSummaryComparison.failedChecks(summary).isEmpty)

        // The variant really did store the rows differently.
        let (a, b) = (base.information, summary.information)
        switch variant {
        case .volumeOrder, .fullTextFragmented, .allAtOnce: #expect(a.volumeOrder != b.volumeOrder)
        case .rollupIdsOffset, .rollupIdsReversed: #expect(a.digests["person_rollup.ids"] != b.digests["person_rollup.ids"])
        case .jsonKeysReversed: #expect(a.digests["volume_structures.json"] != b.digests["volume_structures.json"])
        case .unstamped: #expect(b.exportStamp == nil && a.exportStamp != nil)
        }
    }

    @Test func fragmentationReallyChangesTheSegments() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            var segments: [String] = []
            for fragments in [false, true] {
                let url = directory.url.appendingPathComponent("export-\(fragments).sqlite")
                var export = ParityExport()
                export.fragmentsFullText = fragments
                try export.write(to: url)
                segments.append(try ParityDatabase.immutable(url).digest("SELECT id, block FROM frus_documents_data ORDER BY id").sha256)
            }
            #expect(segments[0] != segments[1], "the rewrites left the index's segments as they were")
        }
    }

    @Test func aChangedWordChangesOnlyItsTableAndVolume() throws {
        let base = try summarize(ParityExport())
        var export = ParityExport()
        export.edits = ["UPDATE terms SET definition = 'National Security Staff' WHERE volume_id = 'frus1961-63v06' AND ref = 't1'"]
        let differences = IndexSummaryComparison.differences(golden: base, candidate: try summarize(export))
        #expect(differences == [
            SummaryDifference(item: "terms", detail: "6 rows each, content differs"),
            SummaryDifference(item: "terms", volume: "frus1961-63v06", detail: "2 rows each, content differs"),
        ])
    }

    @Test func aChangedWordInADocumentChangesItsVocabularyToo() throws {
        let base = try summarize(ParityExport())
        var export = ParityExport()
        export.edits = ["UPDATE document_cache SET body_text = replace(body_text, 'canal route', 'canal zone') WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd2'"]
        let differences = IndexSummaryComparison.differences(golden: base, candidate: try summarize(export))
        // The same number of tokens, so each document's sizes and the averages are unchanged.
        #expect(Set(differences.map(\.item)) == [
            "document_cache", "frus_documents.vocab_row", "frus_documents.vocab_col", "frus_documents.vocab_instance",
        ])
        #expect(Set(differences.compactMap(\.volume)) == ["frus1894Nicaragua"])
    }

    @Test func documentOrderWithinAVolumeIsGated() throws {
        let base = try summarize(ParityExport())
        var export = ParityExport()
        export.reversedDocuments = "frus1894Nicaragua"
        let differences = IndexSummaryComparison.differences(golden: base, candidate: try summarize(export))
        #expect(differences == [
            SummaryDifference(item: "document_cache.sequence", detail: "9 rows each, content differs"),
            SummaryDifference(item: "document_cache.sequence", volume: "frus1894Nicaragua", detail: "3 rows each, content differs"),
        ])
    }

    @Test(arguments: RefusalCase.allCases)
    func refuses(_ refusal: RefusalCase) throws {
        let error = #expect(throws: SummaryRefusal.self) {
            _ = try summarize(refusal.export, prepare: refusal.prepare)
        }
        #expect(error?.kind == refusal.kind, "\(error?.reason ?? "no refusal")")
    }

    @Test func anyVolumesSummarizesAnotherSet() throws {
        var export = ParityExport()
        export.volumes = ["frus1894Nicaragua", "frus1961-63v06"]
        let summary = try summarize(export, anyVolumes: true)
        #expect(summary.gating.volumes == ["frus1894Nicaragua", "frus1961-63v06"])
        #expect(summary.gating.digests["document_cache"]?.rows == 6)
    }

    @Test func aDamagedFullTextIndexFailsTheIntegrityCheck() throws {
        var export = ParityExport()
        export.edits = ["""
            DROP TRIGGER document_cache_frus_documents_au;
            UPDATE document_cache SET body_text = 'Text the full-text index never saw.' WHERE volume_id = 'frus1961-63v06' AND document_id = 'd2';
            """]
        let summary = try summarize(export)
        #expect(summary.gating.checks["integrity"]?.hasPrefix("frus_documents:") == true)
        #expect(IndexSummaryComparison.failedChecks(summary).map(\.item) == ["integrity"])
        let differences = IndexSummaryComparison.differences(golden: try summarize(ParityExport()), candidate: summary)
        #expect(differences.contains { $0.item == "integrity" })
    }

    @Test func aboveTheSizeLimitTheCostlyChecksAreLeftOut() throws {
        let summary = try summarize(ParityExport(), fullCheckLimit: 0)
        #expect(summary.gating.checks["integrity"] == nil)
        #expect(summary.gating.digests["frus_documents.vocab_instance"] == nil)
        #expect(summary.gating.digests["frus_documents.vocab_row"] != nil)
        #expect(summary.information.notes.contains { $0.contains("instance-mode vocabularies and the integrity checks") })
        #expect(IndexSummaryComparison.failedChecks(summary).isEmpty)
        // So such a summary never compares equal to a full one.
        let differences = IndexSummaryComparison.differences(golden: try summarize(ParityExport()), candidate: summary)
        #expect(Set(differences.map(\.item)) == ["integrity", "frus_documents.vocab_instance", "user_content.vocab_instance"])
    }

    @Test func summaryRecordsWhatMadeItAndRoundTrips() throws {
        let summary = try summarize(ParityExport())
        #expect(summary.format == IndexSummaryGolden.currentFormat)
        #expect(summary.provenance.tool == "frus-parity summarize")
        #expect(summary.provenance.indexVersion == IndexCompatibility.supportedIndexVersion)
        #expect(summary.provenance.appBuild == 49)
        #expect(summary.provenance.sourceDigest == (try UpstreamDigest.compute(upstream: Repository.layout.upstream)))
        #expect(summary.provenance.inputs["research_provenance.exported_at"] == "2026-10-03T15:14:19Z")
        #expect(summary.gating.volumes == ParityFixtures.volumes)
        #expect(summary.gating.checks == IndexGating.expectedChecks)
        // Every hashed statement records its SQL, and its volumes' rows add up to its own.
        for (name, digest) in summary.gating.digests.merging(summary.information.digests, uniquingKeysWith: { a, _ in a }) {
            #expect(digest.sql.hasPrefix("SELECT "), "\(name)")
            if let volumes = digest.volumes { #expect(volumes.values.map(\.rows).reduce(0, +) == digest.rows, "\(name)") }
        }
        #expect(summary.gating.digests["document_cache"]?.volumes?.keys.sorted() == ParityFixtures.volumes)
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let url = directory.url.appendingPathComponent(GoldenFile.indexSummary.rawValue)
            try GoldenJSON.write(summary, to: url)
            #expect(try GoldenJSON.read(IndexSummaryGolden.self, from: url) == summary)
        }
        #expect(summary.report().contains("integrity = ok"))
    }

    @Test func rollupsAreNamedByTheirLeastMember() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let url = directory.url.appendingPathComponent("export.sqlite")
            var export = ParityExport()
            export.rollupNumbering = .reversed
            try export.write(to: url)
            let db = try ParityDatabase.immutable(url)
            let sql = try #require(IndexSchema.corpusTables.first { $0.name == "person_rollup_member" }?.setSQL)
            var representatives: [String: String] = [:]
            for row in try db.rows(sql) { representatives["\(row[0].text ?? "")/\(row[1].text ?? "")"] = row[2].text }
            // Henry Kissinger's two entries share one rollup, named by its least member.
            #expect(representatives["frus1961-63v06/p2"] == "frus1961-63v06\u{1F}p2")
            #expect(representatives["frus1969-76ve09p1/p1"] == "frus1961-63v06\u{1F}p2")
            #expect(representatives["frus1894Nicaragua/p1"] == "frus1894Nicaragua\u{1F}p1")
            #expect(representatives.count == 6)
        }
    }

    // MARK: - Schema coverage

    @Test func everyObjectOfTheV65SchemaIsClassified() throws {
        let db = try ParityDatabase.memory()
        try db.execute(try SyntheticExport.schema())
        var tables: Set<String> = []
        for row in try db.rows("SELECT type, name, tbl_name, sql FROM sqlite_schema") {
            let (type, name, table) = (row[0].text ?? "", row[1].text ?? "", row[2].text ?? "")
            #expect(IndexSchema.role(type: type, name: name, table: table) != nil, "\(type) \(name)")
            if type == "table", IndexSchema.role(type: type, name: name, table: table) == .corpus { tables.insert(name) }
        }
        #expect(tables == Set(IndexSchema.corpusTables.map(\.name)))
        for table in IndexSchema.corpusTables {
            #expect(try db.strings("SELECT name FROM pragma_table_info('\(table.name)')") == table.columns, "\(table.name)")
            // Every column is hashed or left out with a reason.
            #expect(Set(table.leftOut.keys).isSubset(of: table.columns), "\(table.name)")
            #expect(try db.rows(table.setSQL).isEmpty, "\(table.name)")
        }
        #expect(IndexSchema.role(type: "table", name: "reading_list", table: "reading_list") == nil)
    }

    @Test func statementHashUsesSha3QueryFraming() throws {
        let db = try ParityDatabase.memory()
        let sql = "SELECT NULL, 1, -2, 1.5, 'a' || char(0) || 'b', x'00ff'"
        var expected = Array("S\(sql.utf8.count):\(sql)R".utf8)
        expected.append(UInt8(ascii: "N"))
        for (tag, bits) in [("I", UInt64(1)), ("I", UInt64(bitPattern: -2)), ("F", (1.5).bitPattern)] {
            expected.append(contentsOf: Array(tag.utf8))
            for shift in stride(from: 56, through: 0, by: -8) { expected.append(UInt8(truncatingIfNeeded: bits >> UInt64(shift))) }
        }
        expected += Array("T3:".utf8) + [0x61, 0x00, 0x62] + Array("B2:".utf8) + [0x00, 0xFF]
        let digest = try db.digest(sql)
        #expect(digest.rows == 1)
        #expect(digest.sha256 == Digest.sha256(Data(expected)))
        // A NUL inside text survives reading too.
        #expect(try db.scalar("SELECT 'a' || char(0) || 'b'") == .text("a\u{0}b"))
    }
}
