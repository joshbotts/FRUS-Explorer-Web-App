// Check 8's year rule, as the full corpus's run settled it (PLAN's S25b): where the year both of the app's views
// read, the API's, and the export's differ, the API's record is held to the generator's record for the views'
// year, counted by how the years differ, and a note the export's own year would resolve otherwise is listed as
// the app's question, never as a difference of the server's; a server that resolves otherwise still differs.
// Each answer is the route's own, built from the kit's resolution over the server's bundled files.

import FRUSCoreKit
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct SourceExplorerYearRuleTests {
    /// The route's answer for a document `documentId` of frus1953 with `note` and `dateline`, as JSON.
    static func answer(_ note: String, dateline: String, documentId: String = "d1",
                       resources: ServerResources) async throws -> Data {
        let entry = DocumentBrowserEntry(documentId: documentId, volumeId: "frus1953", header: "A document", dateline: dateline,
                                         sourceNote: note)
        let dependencies = SourceExplorerResolution.Dependencies(
            collectionAuthority: resources.collectionAuthority, centralFiles: resources.archivalIndexes.centralFiles,
            chiefsOfMission: .empty, presidentialLibraries: resources.sourceExplorer(\.presidentialLibraries),
            curatedLibraries: resources.sourceExplorer(\.curatedLibraries),
            parsedDocuments: SourceExplorerRoutes.ReaderDocuments(reader: ReaderService(volumesDirectory: ServedFixture.resources, resources: resources)),
            volumeURL: nil)
        let resolution = await SourceExplorerResolution(rawSourceNote: note).resolved(
            route: CountrySeriesRoute(header: entry.header, dateline: dateline, year: nil, volumeId: nil, documentId: nil),
            pipeline: nil, dependencies: dependencies)
        return try JSONEncoder().encode(SourceExplorerRoutes.answer(entry: entry, resolution: resolution, resources: resources))
    }

    static let lot = "S/S–NSC files, lot 63 D 351, NSC 140"

    /// Each way the two years differ, for a note whose resolution no year changes: the generator's record for
    /// the views' year, counted by kind, and no question of the app's.
    @Test(arguments: [
        ("Washington, January 1, 1953.", 1952, SourceExplorerCheck.YearDisagreement.Kind.anotherYear),
        ("", 1953, .noDateline),
        ("Washington, March 4, 1953.", nil, .noExportYear),
    ] as [(String, Int?, SourceExplorerCheck.YearDisagreement.Kind)])
    func aYearTheViewsReadOtherwiseIsHeldToTheGeneratorsRecordForIt(_ dateline: String, _ exportYear: Int?,
                                                                     _ kind: SourceExplorerCheck.YearDisagreement.Kind) async throws {
        let resources = try ServerResources.load(from: ServedFixture.resources)
        let comparator = try SourceExplorerCheck.Comparator(resources: ServedFixture.resources)
        let body = try await Self.answer(Self.lot, dateline: dateline, resources: resources)
        let result = await SourceExplorerCheck.run(
            notes: [SourceExplorerCheck.Note(volumeId: "frus1953", documentId: "d1", note: Self.lot, year: exportYear)],
            comparator: comparator) { _ in (200, body) }
        #expect(result.passes, "\(dateline): \(result.differences)")
        #expect(result.identical == 0 && result.undatedByDateline.isEmpty)
        #expect(result.yearDisagreements.map(\.kind) == [kind], "\(dateline)")
        #expect(result.yearDisagreements.first?.exportYear == exportYear)
        #expect(result.exportYearQuestions.isEmpty, "\(result.exportYearQuestions)")
        #expect(result.byStrategy == ["lotFile": 1])
        #expect(result.summary(volumes: 1).contains("1 of them for the year both of the app's views read, where the export reads another (\(kind.rawValue) 1), 0 of which"))
    }

    /// A server that resolves the note otherwise differs, whatever the years: the rule holds the API to the
    /// generator for the views' year, and never lets an answer through that the generator does not give.
    @Test func aServerThatResolvesOtherwiseStillDiffers() async throws {
        let resources = try ServerResources.load(from: ServedFixture.resources)
        let comparator = try SourceExplorerCheck.Comparator(resources: ServedFixture.resources)
        let body = try await Self.answer(Self.lot, dateline: "Washington, January 1, 1953.", resources: resources)
        var json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        var keys = try #require(json["keys"] as? [String: Any])
        keys["lotFileNorm"] = "64D999"
        json["keys"] = keys
        let tampered = try JSONSerialization.data(withJSONObject: json)
        for exportYear in [1953, 1952] as [Int?] {
            let result = await SourceExplorerCheck.run(
                notes: [SourceExplorerCheck.Note(volumeId: "frus1953", documentId: "d1", note: Self.lot, year: exportYear)],
                comparator: comparator) { _ in (200, tampered) }
            #expect(!result.passes && result.yearDisagreements.isEmpty)
            #expect(result.differences.first?.contains("derived is") == true, "\(result.differences)")
        }
    }

    /// Asking several answers at once holds each record as asking one at a time does, in the notes' order.
    @Test func askingSeveralAtOnceIsAskingOneAtATime() async throws {
        let resources = try ServerResources.load(from: ServedFixture.resources)
        let comparator = try SourceExplorerCheck.Comparator(resources: ServedFixture.resources)
        let cases: [(id: String, note: String, dateline: String, year: Int?)] = [
            ("d1", Self.lot, "Washington, March 4, 1953.", 1953),
            ("d2", Self.lot, "Washington, January 1, 1953.", 1952),
            ("d3", "Department of State, Central Files, 611.61/3–453", "Washington, March 4, 1953.", 1953),
            ("d4", Self.lot, "", 1953),
            ("d5", "Eisenhower Library, Whitman File, NSC Series", "Washington, undated.", 1953),
            ("", Self.lot, "Washington, March 4, 1953.", 1953),
        ]
        var bodies: [String: Data] = [:]
        for item in cases where !item.id.isEmpty {
            bodies["/api/v1/volumes/frus1953/documents/\(item.id)/sources"] = try await Self.answer(item.note, dateline: item.dateline,
                                                                                                 documentId: item.id, resources: resources)
        }
        let notes = cases.map { SourceExplorerCheck.Note(volumeId: "frus1953", documentId: $0.id, note: $0.note, year: $0.year) }
        let answers = bodies
        let one = await SourceExplorerCheck.run(notes: notes, comparator: comparator) { path in (answers[path] == nil ? 404 : 200, answers[path] ?? Data()) }
        var heard: [Int] = []
        let several = await SourceExplorerCheck.run(notes: notes, comparator: comparator, parallel: 3, progress: { done, _ in heard.append(done) }) { path in
            (answers[path] == nil ? 404 : 200, answers[path] ?? Data())
        }
        #expect(several == one)
        #expect(one.passes, "\(one.differences)")
        #expect(one.withoutId == 1 && one.identical + one.yearDisagreements.count == 5)
        #expect(one.undatedByDateline == ["frus1953/d5"])
        #expect(heard == [5])
    }
}
