// Check 2 on Linux: FRUSCoreKit's index of the three fixture volumes, summarized, is the Mac's.

import FRUSLightTestSupport
import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct IndexParityTests {
    /// Check 2. The index FRUSCoreKit builds of the fixtures, through its public API alone, as the
    /// server's indexer will, has the golden summary's 36 digests and 7 checks. While the golden
    /// summary waits for the owner's export, the test still checks what needs none: every check at
    /// its right value, the rollup rebuilt, and each volume's documents, which the render golden,
    /// made from the app's source, also counts.
    @Test func theKitsIndexOfTheFixturesSummarizesAsTheMacs() async throws {
        let built = try await FixtureIndex.value()
        let summary = try IndexSummarizer(layout: Repository.layout).summarize(built.copy)
        #expect(GoldenValidation.indexSummaryProblems(summary).isEmpty,
                "\(GoldenValidation.indexSummaryProblems(summary).joined(separator: "\n"))")
        #expect(built.index.rollupRebuilt)
        let (render, renderStale) = try RenderParity.golden(Repository.layout)
        #expect(renderStale.isEmpty, "\(renderStale.joined(separator: "\n"))")
        let rendered = Dictionary(grouping: render.rows, by: \.volume).mapValues(\.count)
        #expect(built.index.documents == rendered)
        print(built.index.metrics.report())
        #if DEBUG
        print("(a debug build: these timings are not measurements; use frus-parity index -c release)")
        #endif

        switch try GoldenValidation.load(.indexSummary, as: IndexSummaryGolden.self, layout: Repository.layout) {
        case .present(let golden, let stale):
            #expect(stale.isEmpty, "\(stale.joined(separator: "\n"))")
            let differences = IndexSummaryComparison.differences(golden: golden, candidate: summary)
            #expect(differences.isEmpty, "\(differences.map(\.description).joined(separator: "\n"))")
            if stale.isEmpty, differences.isEmpty {
                print("check 2 passes: \(golden.gating.digests.count) digests and \(golden.gating.checks.count) checks are the Mac's")
            }
        case .pending(let reason):
            print("\(GoldenFile.indexSummary.rawValue) is pending: it waits for \(reason)")
        }
    }

    /// What check 2 summarizes is a page-for-page copy out of write-ahead-log mode, with no log or
    /// journal beside it, and a copy is never made over a file that exists.
    @Test func theSummaryReadsACopyOutOfWriteAheadLogMode() async throws {
        let built = try await FixtureIndex.value()
        let header = try FileHandle(forReadingFrom: built.copy).read(upToCount: 20) ?? Data()
        #expect(header.count == 20 && header[18] == 1 && header[19] == 1, "file format bytes \(Array(header.suffix(2)))")
        for suffix in ["-wal", "-journal"] {
            #expect(!FileManager.default.fileExists(atPath: built.copy.path + suffix), "\(suffix) beside the copy")
        }
        let summary = try IndexSummarizer(layout: Repository.layout).summarize(built.copy)
        #expect(summary.information.journalMode == "delete")
        #expect(throws: IndexBuildError.self) { try IndexCopy.rollbackJournal(of: built.index.database, to: built.copy) }
    }
}
