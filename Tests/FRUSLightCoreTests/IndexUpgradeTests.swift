// The index at a Standalone server's start (PLAN's S21e): an index whose stamps are behind the kit's
// date-index version is re-indexed from the cached XML, volume by volume, by the start's job, while the
// index is served and `/readyz` names the volumes still to go; an upgrade a stop cut short between volumes
// is finished, from where it was, by the next start; full-text tables of an earlier generation are rebuilt
// from the documents the index holds before it is served; and a removal a stop cut short is finished.

import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import FTS5Store
import Foundation
import Testing

@Suite(.timeLimit(.minutes(3))) struct IndexUpgradeTests {
    typealias Fixture = LibraryIndexingTests.Fixture

    /// The server's next start over the same folders and store, in `ImportWatcher.run`'s order: the indexer
    /// brings the index to this build, then the index found there is opened and served, then the start's
    /// indexing is queued, which it gives.
    static func start(after f: Fixture, held: JobGate? = nil,
                      removingFiles: (@Sendable (String) async throws -> Void)? = nil) async throws -> (Fixture, Job?) {
        let queue = try await InProcessJobQueue.open(store: f.store)
        let state = ServerState(configuration: ServerConfiguration(mode: .standalone, dataDirectory: f.files.root))
        await state.prepareToOpenExistingIndex(files: f.files)
        let recorder = LibraryIndexingTests.Recorder(state: state, held: held)
        let indexer = LibraryIndexingTests.indexer(files: f.files, mode: .standalone, queue: queue, state: state, observer: recorder)
        await indexer.prepareAtStart(removingFiles: removingFiles)
        await state.openExistingIndex(files: f.files)
        let job = await indexer.resumeAtStart()
        return (Fixture(directory: f.directory, files: f.files, store: f.store, queue: queue, state: state, recorder: recorder,
                        indexer: indexer), job)
    }

    /// The fixtures indexed by a first job, the index then served, as a Standalone server leaves them.
    static func indexed(_ volumes: [String]) async throws -> Fixture {
        let f = try await LibraryIndexingTests.open(volumes: volumes)
        let first = try #require(await f.indexer.resumeAtStart())
        #expect(try await f.finished(first).state == .succeeded)
        return f
    }

    /// Lowers the stamps' date-index version below the kit's, as an image whose kit moved past them finds them.
    static func lowerTheStamp(_ f: Fixture) {
        IndexStampFile(url: f.stampsFile).set(IndexingPipeline.currentDateIndexVersion - 1, forKey: IndexingPipeline.dateIndexVersionKey)
    }

    static func wrote(_ f: Fixture) async -> [String] {
        await f.recorder.events.filter { $0.hasPrefix("wrote ") }.map { String($0.dropFirst(6)) }
    }

    /// The row's done-when: a volume indexed under a lowered stamp is re-indexed at the start. The start's job
    /// re-indexes each volume from its file, one after another, while the index found there is served and
    /// `/readyz` names the volumes still to go; then the stamp is the kit's, the upgrade's record goes, and the
    /// next start begins none.
    @Test func aVolumeIndexedUnderALoweredStampIsReindexedAtTheStart() async throws {
        let f = try await Self.indexed(["frus1894Nicaragua", "frus1961-63v06"])
        defer { withExtendedLifetime(f.directory) {} }
        Self.lowerTheStamp(f)
        let gate = JobGate()
        let (next, job) = try await Self.start(after: f, held: gate)
        let upgrade = try #require(next.indexer.stamps.upgrade())
        #expect(upgrade.from == IndexingPipeline.currentDateIndexVersion - 1 && upgrade.to == IndexingPipeline.currentDateIndexVersion)
        #expect(upgrade.remaining == ["frus1894Nicaragua", "frus1961-63v06"])
        let running = try #require(job)

        // Held once the first volume is re-indexed: the index is served, and /readyz names the one to go.
        await gate.untilReached()
        let readiness = await next.state.readiness()
        #expect(readiness.ready && readiness.step == .ready, "\(readiness)")
        #expect(readiness.detail.contains("for index version \(IndexingPipeline.currentDateIndexVersion)") &&
                readiness.detail.contains("1 volume is still to go (frus1961-63v06)"), "\(readiness.detail)")
        #expect(await next.state.upgrade?.volumes == ["frus1961-63v06"])
        #expect(await next.state.index != nil, "served while it is upgraded")
        gate.open()

        let ended = try await next.finished(running)
        #expect(ended.state == .succeeded && ended.progress == "Indexed 2 volumes.", "\(ended)")
        #expect(await Self.wrote(next) == ["frus1894Nicaragua", "frus1961-63v06"])
        #expect(next.indexer.stamps.integer(forKey: IndexingPipeline.dateIndexVersionKey) == IndexingPipeline.currentDateIndexVersion)
        #expect(next.indexer.stamps.upgrade() == nil)
        #expect(await next.state.upgrade == nil)
        #expect(try next.indexed() == ["frus1894Nicaragua": 139, "frus1961-63v06": 123])
        #expect(await next.state.readiness().detail.contains("still to go") == false)

        let (again, none) = try await Self.start(after: next)
        #expect(none == nil && again.indexer.stamps.upgrade() == nil, "nothing is behind")
    }

    /// The row's done-when: a run killed between volumes is finished at the next start. The server stops once
    /// the upgrade's first volume is re-indexed, its job going no further; the next start finds the upgrade's
    /// record and re-indexes the two volumes it had still to do, and only those, and then marks it done.
    @Test func anUpgradeAStopCutShortBetweenVolumesIsFinishedAtTheNextStart() async throws {
        let f = try await Self.indexed(LibraryIndexingTests.fixtures)
        defer { withExtendedLifetime(f.directory) {} }
        Self.lowerTheStamp(f)
        let gate = JobGate()
        let (stopped, job) = try await Self.start(after: f, held: gate)
        let abandoned = try #require(job)
        await gate.untilReached()
        #expect(stopped.indexer.stamps.upgrade()?.remaining == ["frus1961-63v06", "frus1969-76ve09p1"])

        // The next start, the stopped server's job going no further, as a stop leaves it.
        let (next, resumed) = try await Self.start(after: stopped)
        #expect(next.indexer.stamps.upgrade()?.remaining == ["frus1961-63v06", "frus1969-76ve09p1"])
        #expect(await next.state.readiness().detail.contains("2 volumes are still to go (frus1961-63v06, frus1969-76ve09p1)"))
        let ended = try await next.finished(try #require(resumed))
        #expect(ended.state == .succeeded && ended.progress == "Indexed 2 volumes.", "\(ended)")
        #expect(await Self.wrote(next) == ["frus1961-63v06", "frus1969-76ve09p1"])
        #expect(next.indexer.stamps.integer(forKey: IndexingPipeline.dateIndexVersionKey) == IndexingPipeline.currentDateIndexVersion)
        #expect(next.indexer.stamps.upgrade() == nil && (await next.state.upgrade) == nil)
        #expect(try next.indexed() == LibraryIndexingTests.documents)

        // The stopped server's job, let go, so that nothing of it outlives the test.
        _ = try? await stopped.queue.cancel(abandoned.id, by: nil)
        gate.open()
        await stopped.queue.waitUntilIdle()
    }

    /// Full-text tables of an earlier generation, as an older build's index has, are made again by the kit's
    /// read-write open at the start and rebuilt from the documents the index holds
    /// (`rebuildSearchIndexFromCache()`) before it is served, so that search finds what it found before.
    @Test func fullTextTablesOfAnEarlierGenerationAreRebuiltAtTheStart() async throws {
        let f = try await Self.indexed(["frus1894Nicaragua"])
        defer { withExtendedLifetime(f.directory) {} }
        func matches() throws -> Int64 {
            let db = try SQLiteConnection(FTS5Store.readOnlyURI(for: f.files.liveIndex), readOnly: true)
            defer { db.close() }
            return try db.scalar("SELECT count(*) FROM frus_documents WHERE frus_documents MATCH 'nicaragua'")?.integer ?? 0
        }
        let before = try matches()
        #expect(before > 0)
        do {
            let db = try SQLiteConnection(f.files.liveIndex.path, readOnly: false)
            defer { db.close() }
            try db.execute("PRAGMA user_version = \(IndexCompatibility.ftsSchemaVersion - 1)")
        }
        let (next, job) = try await Self.start(after: f)
        #expect(job == nil, "nothing to index again")
        #expect(await next.state.index != nil, "\(await next.state.readiness())")
        #expect(try matches() == before)
    }

    /// A removal a stop of the server cut short, kept in the stamps, is finished by the next start: the
    /// volume taken out of the index, then its files, and the record forgotten.
    @Test func aRemovalAStopCutShortIsFinishedAtTheNextStart() async throws {
        let f = try await Self.indexed(["frus1894Nicaragua", "frus1961-63v06"])
        defer { withExtendedLifetime(f.directory) {} }
        IndexStampFile(url: f.stampsFile).beginRemoval("frus1894Nicaragua")
        let volumes = f.volumes
        let (next, _) = try await Self.start(after: f, removingFiles: { volumeId in
            try FileManager.default.removeItem(at: volumes.appendingPathComponent("\(volumeId).xml"))
        })
        #expect(try next.indexed() == ["frus1961-63v06": 123])
        #expect(!FileManager.default.fileExists(atPath: volumes.appendingPathComponent("frus1894Nicaragua.xml").path))
        #expect(next.indexer.stamps.removals().isEmpty)
        #expect(await next.state.index?.documentsByVolume["frus1894Nicaragua"] == nil)
    }
}
