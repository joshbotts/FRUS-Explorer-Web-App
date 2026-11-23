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
        // A year the export reads inside 1906–1910 where the dateline gives none: the API, as both of the app's
        // views, shows no Numerical File, and the record is the generator's for the views' year; the export's own
        // year would resolve the rolls, the app's question, listed (S25b's settlement of the year rule).
        let (_, body) = try await Self.answer("File No. 551/79", dateline: "Washington, undated.", resources: resources)
        let result = await SourceExplorerCheck.run(
            notes: [SourceExplorerCheck.Note(volumeId: "frus1908", documentId: "d1", note: "File No. 551/79", year: 1908)],
            comparator: comparator) { _ in (200, body) }
        #expect(result.passes, "\(result.differences)")
        #expect(result.identical == 0 && result.undatedByDateline.isEmpty)
        let disagreement = try #require(result.yearDisagreements.first)
        #expect(result.yearDisagreements.count == 1 && disagreement.kind == .datelineGivesNoYear)
        #expect(disagreement.viewsYear == nil && disagreement.exportYear == 1908)
        #expect(disagreement.resolvesOtherwise.contains("numericalFileRolls") && disagreement.resolvesOtherwise.contains("offlineOutcome"),
                "\(disagreement.resolvesOtherwise)")
        #expect(result.exportYearQuestions == [disagreement])
    }

    /// The third rule (S25b): a 1906–1910 file number in the Decimal File's form names no Numerical File case to the
    /// kit, both of the app's views' reading since FRUS-Explorer#722, where the export generator's core reads the digits
    /// before the point as one; the record is held with the kit's reading, counted, and no year question is left of it.
    @Test func aDecimalFormFileNumberIsReadAsTheKitReadsIt() async throws {
        let resources = try ServerResources.load(from: ServedFixture.resources)
        let comparator = try SourceExplorerCheck.Comparator(resources: ServedFixture.resources)
        let note = "File No. 723.2515/110."
        // The export's own core finds case 723's rolls for it.
        #expect(comparator.record(volumeId: "frus1908", documentId: "d1", note: note, year: 1910).resolution.numericalFileRolls?.isEmpty == false)
        let (answer, body) = try await Self.answer(note, dateline: "American Embassy, Petropolis, March 17, 1910.", resources: resources)
        #expect(answer.year == 1910 && answer.offline.numericalFileRolls == nil && answer.offline.numericalFileCoverageGap == true)
        let result = await SourceExplorerCheck.run(
            notes: [SourceExplorerCheck.Note(volumeId: "frus1908", documentId: "d1", note: note, year: 1910)],
            comparator: comparator) { _ in (200, body) }
        #expect(result.passes, "\(result.differences)")
        #expect(result.identical == 1 && result.decimalFormFiles == ["frus1908/d1"])
        #expect(result.summary(volumes: 1).contains("1 of them with the kit's reading of a 1906–1910 file number in the Decimal File's form"))

        // With no dateline, the export's year resolves nothing the views' does not, read as the kit reads the number.
        let (_, undated) = try await Self.answer(note, dateline: "", resources: resources)
        let year = await SourceExplorerCheck.run(
            notes: [SourceExplorerCheck.Note(volumeId: "frus1908", documentId: "d1", note: note, year: 1910)],
            comparator: comparator) { _ in (200, undated) }
        #expect(year.passes, "\(year.differences)")
        // The export's 1910 still opens the Numerical File's window, whose gap the views' no year does not show: that
        // question stands; the rolls the export's core would read from the number do not.
        #expect(year.yearDisagreements.map(\.kind) == [.noDateline])
        #expect(year.exportYearQuestions.map(\.resolvesOtherwise) == [["numericalFileCoverageGap"]], "\(year.exportYearQuestions)")
        #expect(year.decimalFormFiles == ["frus1908/d1"])

        // A Numerical File number is no Decimal File form: the rule leaves it, and its rolls, alone.
        let (_, numbered) = try await Self.answer("File No. 551/79.", dateline: "Washington, March 4, 1908.", resources: resources)
        let rolls = await SourceExplorerCheck.run(
            notes: [SourceExplorerCheck.Note(volumeId: "frus1908", documentId: "d1", note: "File No. 551/79.", year: 1908)],
            comparator: comparator) { _ in (200, numbered) }
        #expect(rolls.passes && rolls.decimalFormFiles.isEmpty && rolls.byOutcome == ["resolvedNumericalFile": 1], "\(rolls.byOutcome)")
    }
}
