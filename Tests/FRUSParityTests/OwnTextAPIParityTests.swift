// A section's own text through the API, beside the kit (joshbotts/FRUS-Explorer#1536, index versions
// 68 and 70). No fixture volume prints text at a section's own level, so the kit's own fixtures for
// those rows are indexed by FRUSCoreKit and dropped into the server's drop zone as an export: every
// section's answer is held to `VolumeSection.ownTextEntry(among:)` over the index's rows, and each
// row opens in the reader between the entries the kit's reading order puts around it, rendered as the
// app's reader renders it. Over the three fixture volumes the server lists none, as the kit gives none.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
@testable import FRUSParity
import Foundation
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSLightAPI

/// The kit's two fixture volumes for a section's own text (`fixtures/own-text`), indexed once per test
/// process by FRUSCoreKit, with its copy out of write-ahead-log mode, as an export is.
enum OwnTextFixtureIndex {
    struct Built: Sendable {
        let directory: TemporaryDirectory
        let index: ParityIndex
        let copy: URL
    }

    static func value() async throws -> Built { try await shared.value }

    static var volumes: [String] { OwnTextFixtures.volumes.map(\.id) }

    private static let shared = Task<Built, any Error> {
        let directory = try TemporaryDirectory()
        let tei = directory.url.appendingPathComponent("Volumes", isDirectory: true)
        try RepositoryFiles.mountTEI(volumes, at: tei)
        let index = try await ParityIndex.build(volumes: volumes, tei: tei, resources: ServedFixture.resources,
                                                database: directory.url.appendingPathComponent("frus.db"))
        let copy = directory.url.appendingPathComponent("copy.db")
        try IndexCopy.rollbackJournal(of: index.database, to: copy)
        return Built(directory: directory, index: index, copy: copy)
    }
}

@Suite struct OwnTextAPIParityTests {
    static let folder = OwnTextFixtures.folder(Repository.layout)

    /// A GET through the test client, as `LiveAPI` takes one.
    static func get(_ client: any TestClientProtocol) -> (String) async throws -> LiveAPI.Response {
        { path in
            let response = try await client.execute(uri: path, method: .get)
            return (Int(response.status.code), Data(response.body.readableBytesView))
        }
    }

    /// The rows a parse of each volume's TEI by the kit yields, which the reader can open.
    static func parsedRows(_ volumes: [String], in tei: URL) async throws -> [String: Set<String>] {
        var rows: [String: Set<String>] = [:]
        for volume in volumes {
            rows[volume] = Set(try await FRUSDocumentParser().parse(volumeURL: tei.appendingPathComponent("\(volume).xml")).map(\.documentId))
        }
        return rows
    }

    /// The files are the kit's fixtures at the pin: each suite's `volumeXML`, under the id the suite
    /// gives it, with a newline at the end. A pin move that changes one copies it again.
    @Test func theFixturesAreTheKitsAtThePin() throws {
        let source = try String(contentsOf: Repository.layout.upstream.appendingPathComponent(OwnTextFixtures.sourcePath), encoding: .utf8)
        for volume in OwnTextFixtures.volumes {
            let literal = try OwnTextFixtures.literal(of: volume.suite, in: source)
            let file = try String(contentsOf: Self.folder.appendingPathComponent("\(volume.id).xml"), encoding: .utf8)
            #expect(file == literal + "\n",
                    "fixtures/own-text/\(volume.id).xml is not \(volume.suite)'s volumeXML at the pin: copy it again (fixtures/own-text/README.md)")
            #expect(try OwnTextFixtures.volumeId(of: volume.suite, in: source) == volume.id)
        }
    }

    /// Every section of both volumes, through the API as the owner's server serves an export: the
    /// outline is the index's, each section's `hasOwnText` and each section's page are the kit's rule
    /// over the index's rows, the reader can open each row, as the kit's parse of the TEI says, and
    /// opens it between the entries the kit's reading order puts around it. The fixtures hold each
    /// case the rule decides: rows in sections that hold documents and in sections that hold only
    /// sections, one of a front-matter kind, and sections that could have a row and have none.
    @Test func everySectionAnswersAsTheKitsRuleGivesIt() async throws {
        let built = try await OwnTextFixtureIndex.value()
        let volumes = OwnTextFixtureIndex.volumes
        let readable = try await Self.parsedRows(volumes, in: Self.folder)
        var kit: [OwnTextVolume] = []
        for volume in volumes { kit.append(try await OwnTextVolume(volume, pipeline: built.index.pipeline)) }
        let report = try await ServedFixture.run(index: built.copy, volumes: volumes) { [kit] client, _ in
            var report = OwnTextCheck.Report()
            for volume in kit {
                try await OwnTextCheck.check(volume, readable: readable[volume.volumeId], get: Self.get(client), into: &report)
            }
            return report
        }
        #expect(report.mismatches.isEmpty, "\(report.mismatches.count) differences:\n\(report.mismatches.joined(separator: "\n"))")
        #expect(report.volumes == 2 && report.pages == report.sections && report.repeatedIds == 0)
        #expect(report.rowsInSectionsWithDocuments > 0 && report.rowsInSectionsWithOnlySections > 0 && report.frontMatterRows > 0)
        #expect(report.candidates > report.rows, "no section that could have a row has none")
        #expect(report.readableRows == report.rows && report.neighboursRead == report.rows)
        print("own text through the API over the kit's fixtures: \(report.summary)")
    }

    /// The reader's page for each row is the app's reader's: its body through the API, with the
    /// server's figure addresses written back as the reader's, is what the kit's reader path renders
    /// for the row, a parse of that one section (`parseDocument`).
    @Test func eachRowReadsAsTheAppsReaderRendersIt() async throws {
        let built = try await OwnTextFixtureIndex.value()
        var rows: [(volume: String, document: String)] = []
        for volume in OwnTextFixtureIndex.volumes {
            let kit = try await OwnTextVolume(volume, pipeline: built.index.pipeline)
            func walk(_ sections: [VolumeSection]) {
                for section in sections {
                    if let row = section.ownTextEntry(among: kit.rows) { rows.append((volume, row.documentId)) }
                    walk(section.subsections)
                }
            }
            walk(kit.sections)
        }
        let rendered = try await ReaderRenderer(layout: Repository.layout, tei: Self.folder).readerPass(rows)
        let (served, figures) = try await ServedFixture.run(index: built.copy, volumes: OwnTextFixtureIndex.volumes) { [rows] client, _ in
            try await LiveAPI.bodies(rows, get: Self.get(client))
        }
        #expect(rows.count > 0 && rendered.count == rows.count && served.count == rows.count)
        for (server, reader) in zip(served, rendered) {
            #expect(reader.html != nil, "the kit's reader opens no page for \(reader.volume)/\(reader.document)")
            #expect(server.html == reader.html, "\(server.volume)/\(server.document)'s page is not the reader's")
        }
        // One row prints a seating plan, an image at the section's own level.
        #expect(figures == ["frus1969-76v01/ch5": 1])
    }

    /// The three fixture volumes print no text at a section's own level: the kit finds no row for
    /// any of their sections, and neither does the API, on any section's page.
    @Test func theFixtureVolumesListNone() async throws {
        let built = try await FixtureIndex.value()
        let readable = try await Self.parsedRows(ParityFixtures.volumes, in: Repository.layout.tei)
        var kit: [OwnTextVolume] = []
        for volume in ParityFixtures.volumes { kit.append(try await OwnTextVolume(volume, pipeline: built.index.pipeline)) }
        let report = try await ServedFixture.run { [kit] client, _ in
            var report = OwnTextCheck.Report()
            for volume in kit {
                try await OwnTextCheck.check(volume, readable: readable[volume.volumeId], get: Self.get(client), into: &report)
            }
            return report
        }
        #expect(report.mismatches.isEmpty, "\(report.mismatches.count) differences:\n\(report.mismatches.joined(separator: "\n"))")
        #expect(report.volumes == 3 && report.pages == report.sections && report.candidates > 0 && report.rows == 0)
        print("own text through the API over the fixtures: \(report.summary)")
    }

    /// The synthetic export's rows of the kit's fixture, which the browser suite reads, are the kit's
    /// index of the file: each column of the four rows, their dates, and the outline.
    @Test func theSyntheticExportsRowsAreTheKits() async throws {
        let built = try await OwnTextFixtureIndex.value()
        let directory = try TemporaryDirectory()
        var export = SyntheticExport()
        export.includesOwnText = true
        let url = directory.url.appendingPathComponent("export.sqlite")
        try export.write(to: url)
        let synthetic = try ParityDatabase.immutable(url)
        let kit = try ParityDatabase.readOnly(built.copy)
        let volume = SyntheticExport.ownTextVolume
        let ids = SyntheticExport.ownTextRows.map { "'\($0.id)'" }.joined(separator: ", ")
        let columns = "document_id, document_number, header, dateline, source_note, body_text, subject_tag_ids, user_tag_ids, "
            + "summary_text, note_text, is_editorial_note, is_front_matter, despatch_serial"
        let rows = "SELECT \(columns) FROM document_cache WHERE volume_id = '\(volume)' AND document_id IN (\(ids)) ORDER BY rowid"
        #expect(try synthetic.rows(rows) == kit.rows(rows))
        #expect(try synthetic.rows(rows).count == SyntheticExport.ownTextRows.count)
        let dates = "SELECT document_id, date_iso, date_iso_max, date_precision, date_certainty FROM document_dates "
            + "WHERE volume_id = '\(volume)' AND document_id IN (\(ids)) ORDER BY document_id"
        #expect(try synthetic.rows(dates) == kit.rows(dates))
        let outline = "SELECT structure_json FROM volume_structures WHERE volume_id = '\(volume)'"
        let ours = try #require(try synthetic.scalar(outline)?.text)
        let theirs = try #require(try kit.scalar(outline)?.text)
        let decoded = try [ours, theirs].map { try JSONDecoder().decode(VolumeStructure.self, from: Data($0.utf8)) }
        #expect(decoded[0].volumeId == decoded[1].volumeId && decoded[0].sections == decoded[1].sections)
    }
}
