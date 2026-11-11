// Check 2 through the server (PLAN's S21d): the three fixture volumes, indexed by a Standalone server's
// indexing job as its library holds them, summarize as the Mac's index of them does, fixtures/golden's.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite(.timeLimit(.minutes(2))) struct StandaloneIndexParityTests {
    /// Check 2, the server's index: the job's, through its queue, its stamps and its passes after
    /// indexing, copied out of write-ahead-log mode as check 2 reads an index, has the golden summary's
    /// digests and checks.
    @Test func theServersIndexingJobOfTheFixturesSummarizesAsTheMacs() async throws {
        let directory = try TemporaryDirectory()
        let files = DataDirectory(root: directory.url.appendingPathComponent("data", isDirectory: true))
        try files.prepare()
        try RepositoryFiles.mountTEI(ParityFixtures.volumes, at: files.volumesDirectory)
        let store = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
        let queue = try await InProcessJobQueue.open(store: store)
        let state = ServerState(configuration: ServerConfiguration(mode: .standalone, dataDirectory: files.root))
        let resources = try IndexingResources.loading(
            fromDirectory: Repository.layout.upstream.appendingPathComponent(ParityIndex.resourcesPath))
        let indexer = LibraryIndexer(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory, mode: .standalone,
                                     resources: resources, jobs: queue, state: state, capacity: { .max })
        let job = try await indexer.index(.asked(nil), requestedBy: nil)
        await queue.waitUntilIdle()
        let done = try #require(await queue.job(job.id))
        #expect(done.state == .succeeded && done.progress == "Indexed \(ParityFixtures.volumes.count) volumes.", "\(done)")

        let copy = directory.url.appendingPathComponent("copy.db")
        try IndexCopy.rollbackJournal(of: files.liveIndex, to: copy)
        let summary = try IndexSummarizer(layout: Repository.layout).summarize(copy)
        #expect(GoldenValidation.indexSummaryProblems(summary).isEmpty,
                "\(GoldenValidation.indexSummaryProblems(summary).joined(separator: "\n"))")
        switch try GoldenValidation.load(.indexSummary, as: IndexSummaryGolden.self, layout: Repository.layout) {
        case .present(let golden, let stale):
            #expect(stale.isEmpty, "\(stale.joined(separator: "\n"))")
            let differences = IndexSummaryComparison.differences(golden: golden, candidate: summary)
            #expect(differences.isEmpty, "\(differences.map(\.description).joined(separator: "\n"))")
            if stale.isEmpty, differences.isEmpty {
                print("check 2 through the server's indexing passes: \(golden.gating.digests.count) digests and \(golden.gating.checks.count) checks are the Mac's")
            }
        case .pending(let reason):
            print("\(GoldenFile.indexSummary.rawValue) is pending: it waits for \(reason)")
        }
    }
}
