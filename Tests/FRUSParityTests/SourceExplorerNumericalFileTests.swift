// Check 8 for the notes the fixture volumes lack (PLAN's S22d): a 1906–1910 file number, whose Numerical File rolls
// or coverage gap the export records, which no fixture document is dated to. Each answer is the route's own, built
// from the kit's resolution over the server's bundled files as `…/sources` builds it, and held to the export
// generator's record by check 8's comparator, as the API's answers are.

import FRUSCoreKit
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct SourceExplorerNumericalFileTests {
    /// The route's answer for a document with `note` and `dateline`, as JSON.
    static func answer(_ note: String, dateline: String, resources: ServerResources) async throws -> (SourceExplorerAnswer, Data) {
        let entry = DocumentBrowserEntry(documentId: "d1", volumeId: "frus1908", header: "A document", dateline: dateline, sourceNote: note)
        let dependencies = SourceExplorerResolution.Dependencies(
            collectionAuthority: resources.collectionAuthority, centralFiles: resources.archivalIndexes.centralFiles,
            chiefsOfMission: .empty, presidentialLibraries: resources.sourceExplorer(\.presidentialLibraries),
            curatedLibraries: resources.sourceExplorer(\.curatedLibraries),
            parsedDocuments: SourceExplorerRoutes.ReaderDocuments(reader: ReaderService(volumesDirectory: ServedFixture.resources, resources: resources)),
            volumeURL: nil)
        let resolution = await SourceExplorerResolution(rawSourceNote: note).resolved(
            route: CountrySeriesRoute(header: entry.header, dateline: dateline, year: nil, volumeId: nil, documentId: nil),
            pipeline: nil, dependencies: dependencies)
        let answer = SourceExplorerRoutes.answer(entry: entry, resolution: resolution, resources: resources)
        return (answer, try JSONEncoder().encode(answer))
    }

    @Test func theNumericalFileIsTheExports() async throws {
        let resources = try ServerResources.load(from: ServedFixture.resources)
        let comparator = try SourceExplorerCheck.Comparator(resources: ServedFixture.resources)
        // Case 551 is on roll 549–552; case 20200 falls in the rolls' gap between 20184 and 20233.
        for (note, onRolls) in [("File No. 551/79", true), ("File No. 20200/3", false)] {
            let (answer, body) = try await Self.answer(note, dateline: "Washington, March 4, 1908.", resources: resources)
            #expect(answer.year == 1908 && answer.provenance.contains { $0.kind == "numericalFile" }, "\(note)")
            if onRolls {
                #expect(answer.offline.numericalFileRolls?.map(\.naId) == ["19157669"] && answer.offline.numericalFileCoverageGap == nil)
            } else {
                #expect(answer.offline.numericalFileRolls == nil && answer.offline.numericalFileCoverageGap == true)
            }
            let result = await SourceExplorerCheck.run(
                notes: [SourceExplorerCheck.Note(volumeId: answer.volumeId, documentId: answer.documentId, note: note, year: 1908)],
                comparator: comparator) { _ in (200, body) }
            #expect(result.passes, "\(note): \(result.differences.joined(separator: "; "))")
        }
        // A year the export reads differently from the dateline's inside 1906–1910 is a difference, not the rule.
        let (_, body) = try await Self.answer("File No. 551/79", dateline: "Washington, undated.", resources: resources)
        let result = await SourceExplorerCheck.run(
            notes: [SourceExplorerCheck.Note(volumeId: "frus1908", documentId: "d1", note: "File No. 551/79", year: 1908)],
            comparator: comparator) { _ in (200, body) }
        #expect(!result.passes && result.differences.first?.contains("documentYear") == true)
    }
}
