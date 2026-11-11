// The library's indexing (PLAN's S21d): a Standalone server indexes the volumes its library keeps with the
// kit's read-write pipeline, in jobs of the queue, its stamps in index-stamps.json beside the index, written
// whole; a volume that fails is kept failed with its stage while the others are indexed and the passes
// after indexing run; a cancel stops a job between volumes; a start indexes what waits but a volume whose
// pass a stop cut short; a download that fetched volumes queues their indexing; and Import mode indexes
// nothing.

import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import FTS5Store
import Foundation
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(2))) struct LibraryIndexingTests {
    static let fixtures = LibraryTests.fixtures
    /// The fixture volumes' documents in `document_cache` at the pin, 393 in all, as the index summary's
    /// golden file counts them.
    static let documents = ["frus1894Nicaragua": 139, "frus1961-63v06": 123, "frus1969-76ve09p1": 131]

    /// What the served index is told, recorded, and the index opened again and served once a job closes
    /// it, as the server's own observer does; `held` keeps a job at its first volume's end until opened.
    actor Recorder: IndexWritingObserver {
        let state: ServerState
        private(set) var events: [String] = []
        let held: JobGate?

        init(state: ServerState, held: JobGate? = nil) {
            self.state = state
            self.held = held
        }

        func willWriteIndex(at url: URL) async { events.append("will write") }

        func didWriteVolume(_ volumeId: String, at url: URL) async {
            events.append("wrote \(volumeId)")
            if let held, events.filter({ $0.hasPrefix("wrote") }).count == 1 { await held.wait() }
        }

        func didFinishWritingIndex(at url: URL) async {
            events.append("finished")
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            if let index = try? await Blocking.run({ try CorpusIndex.open(url) }) { await state.indexWritten(index) }
        }
    }

    struct Fixture {
        let directory: TemporaryDirectory
        let files: DataDirectory
        let store: SQLiteUserStore
        let queue: InProcessJobQueue
        let state: ServerState
        let recorder: Recorder
        let indexer: LibraryIndexer

        var volumes: URL { files.volumesDirectory }
        var stampsFile: URL { files.liveIndex.deletingLastPathComponent().appendingPathComponent(IndexStampFile.fileName) }

        /// The server again over the same folders and store, as its next start has it.
        func restarted(mode: ServerConfiguration.Mode = .standalone) async throws -> Fixture {
            let queue = try await InProcessJobQueue.open(store: store)
            let state = ServerState(configuration: ServerConfiguration(mode: mode, dataDirectory: files.root))
            await state.openExistingIndex(files: files)
            let recorder = Recorder(state: state)
            let indexer = LibraryIndexingTests.indexer(files: files, mode: mode, queue: queue, state: state, observer: recorder)
            return Fixture(directory: directory, files: files, store: store, queue: queue, state: state, recorder: recorder, indexer: indexer)
        }

        func finished(_ job: Job) async throws -> Job {
            await queue.waitUntilIdle()
            return try #require(await queue.job(job.id))
        }

        /// What the index holds of each volume now, read through a connection of the test's own.
        func indexed() throws -> [String: Int] {
            guard FileManager.default.fileExists(atPath: files.liveIndex.path) else { return [:] }
            let db = try SQLiteConnection(files.liveIndex.path, readOnly: true)
            defer { db.close() }
            var counts: [String: Int] = [:]
            for row in try db.query("SELECT volume_id, count(*) FROM document_cache GROUP BY volume_id") {
                counts[row[0].text ?? ""] = Int(row[1].integer ?? 0)
            }
            return counts
        }

        /// The volumes with documents and no record that their last pass finished (#1566).
        func unfinished() throws -> Set<String> {
            let db = try SQLiteConnection(files.liveIndex.path, readOnly: true)
            defer { db.close() }
            return Set(try db.query("SELECT DISTINCT volume_id FROM document_cache WHERE volume_id NOT IN (SELECT volume_id FROM volume_structures)")
                .compactMap { $0[0].text })
        }
    }

    static func indexer(files: DataDirectory, mode: ServerConfiguration.Mode, queue: InProcessJobQueue, state: ServerState,
                        observer: Recorder, capacity: Int64 = .max) -> LibraryIndexer {
        LibraryIndexer(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory, mode: mode,
                       resources: try! IndexingResources.loading(fromDirectory: RepositoryFiles.resources),
                       jobs: queue, state: state, observer: observer, capacity: { capacity })
    }

    static func open(volumes: [String] = fixtures, mode: ServerConfiguration.Mode = .standalone, held: JobGate? = nil,
                     capacity: Int64 = .max) async throws -> Fixture {
        let (store, _, directory) = try await UserTagTests.open()
        let files = DataDirectory(root: directory.url.appendingPathComponent("data", isDirectory: true))
        try files.prepare()
        try RepositoryFiles.mountTEI(volumes, at: files.volumesDirectory)
        let queue = try await InProcessJobQueue.open(store: store)
        let state = ServerState(configuration: ServerConfiguration(mode: mode, dataDirectory: files.root))
        let recorder = Recorder(state: state, held: held)
        let indexer = indexer(files: files, mode: mode, queue: queue, state: state, observer: recorder, capacity: capacity)
        return Fixture(directory: directory, files: files, store: store, queue: queue, state: state, recorder: recorder, indexer: indexer)
    }

    /// A volume whose XML stops in the middle of an element, which the parser refuses.
    static let brokenId = "frus1999v98"
    static func writeBroken(in volumes: URL) throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body><div type="document" xml:id="d1"><head>One</head>
            <p>A paragraph that is never closed
            """
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(brokenId).xml"))
    }

    // MARK: The stamps file

    /// The stamps read back as the kit's in-memory store reads them, through a restart, and the file holds
    /// them in its format, written whole, with no hidden file left beside it.
    @Test func theStampsFileKeepsWhatTheKitStoresThroughARestart() async throws {
        let directory = try TemporaryDirectory()
        let url = directory.url.appendingPathComponent(IndexStampFile.fileName)
        let stamps = IndexStampFile(url: url)
        #expect(stamps.integer(forKey: "absent") == 0 && stamps.string(forKey: "absent") == nil && stamps.data(forKey: "absent") == nil)
        stamps.set(74, forKey: IndexingPipeline.dateIndexVersionKey)
        stamps.set("2026-11-06", forKey: IndexingPipeline.brokenRefsIndexAppliedKey)
        stamps.set("12", forKey: "numberAsText")
        stamps.set(Data([0, 1, 2, 255]), forKey: "frus.indexingInProgress")
        stamps.set(true, forKey: "flag")
        stamps.set(5, forKey: "gone")
        stamps.removeObject(forKey: "gone")
        stamps.set(3, forKey: "alsoGone")
        stamps.set(nil, forKey: "alsoGone")
        let record = IndexingFailureRecord(kind: .failed, stage: "reading", sentence: "Its XML could not be parsed.",
                                           at: Date(timeIntervalSince1970: 1_792_800_000))
        stamps.recordFailure(record, for: "frus1999v98")
        #expect(stamps.writeProblem == nil)

        let again = IndexStampFile(url: url)
        #expect(again.integer(forKey: IndexingPipeline.dateIndexVersionKey) == 74)
        #expect(again.string(forKey: IndexingPipeline.dateIndexVersionKey) == "74")
        #expect(again.string(forKey: IndexingPipeline.brokenRefsIndexAppliedKey) == "2026-11-06")
        #expect(again.integer(forKey: "numberAsText") == 12 && again.integer(forKey: IndexingPipeline.brokenRefsIndexAppliedKey) == 0)
        #expect(again.data(forKey: "frus.indexingInProgress") == Data([0, 1, 2, 255]))
        #expect(again.integer(forKey: "flag") == 1)
        #expect(again.integer(forKey: "gone") == 0 && again.string(forKey: "alsoGone") == nil)
        #expect(again.failures() == ["frus1999v98": record])
        again.clearFailure(of: "frus1999v98")
        #expect(IndexStampFile(url: url).failures().isEmpty)

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(json?["format"] as? Int == 1)
        #expect((json?["stamps"] as? [String: Any])?[IndexingPipeline.dateIndexVersionKey] as? [String: Int] == ["integer": 74])
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.url.path) == [IndexStampFile.fileName])

        // The kit's own tracker keeps its sentinel there, and a restart reads it back.
        await IndexingStateTracker(store: again).markStarted(volumeId: "frus1961-63v06")
        #expect(await IndexingStateTracker(store: IndexStampFile(url: url)).interruptedVolumeIds() == ["frus1961-63v06"])
    }

    /// Each change replaces the file whole: a reader never finds part of one, while changes come from
    /// several tasks at once.
    @Test func eachChangeReplacesTheFileWhole() async throws {
        let directory = try TemporaryDirectory()
        let url = directory.url.appendingPathComponent(IndexStampFile.fileName)
        let stamps = IndexStampFile(url: url)
        stamps.set(Data(repeating: 7, count: 4096), forKey: "padding")
        let reading = Task.detached { () -> Int in
            var reads = 0
            while !Task.isCancelled {
                if let data = FileManager.default.contents(atPath: url.path) {
                    #expect((try? JSONSerialization.jsonObject(with: data)) != nil, "a read of \(data.count) bytes was not whole")
                    reads += 1
                }
            }
            return reads
        }
        await withTaskGroup(of: Void.self) { group in
            for writer in 0..<4 {
                group.addTask { for n in 0..<50 { stamps.set(n, forKey: "writer\(writer)") } }
            }
        }
        reading.cancel()
        #expect(await reading.value > 0)
        let again = IndexStampFile(url: url)
        #expect((0..<4).allSatisfy { again.integer(forKey: "writer\($0)") == 49 })
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.url.path) == [IndexStampFile.fileName])
    }

    /// A file that is not the stamps is set aside, and the store begins with none; a hidden file a stop
    /// left mid-write is removed; and a write that fails keeps the change in memory, says so, and is made
    /// again with the next change.
    @Test func anUnreadableFileIsSetAsideAndAFailedWriteIsMadeAgain() throws {
        let directory = try TemporaryDirectory()
        let url = directory.url.appendingPathComponent(IndexStampFile.fileName)
        try Data("{not json".utf8).write(to: url)
        try Data("partial".utf8).write(to: directory.url.appendingPathComponent(".\(IndexStampFile.fileName).ABC.new"))
        let logged = Mutex<[String]>([])
        let stamps = IndexStampFile(url: url, now: Date(timeIntervalSince1970: 1_792_800_000)) { line in logged.withLock { $0.append(line) } }
        #expect(stamps.integer(forKey: IndexingPipeline.dateIndexVersionKey) == 0)
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.url.path).sorted()
        #expect(names == ["\(IndexStampFile.fileName).unreadable-2026-10-24T00-00-00.000Z"], "\(names)")
        #expect(logged.withLock { $0 }.contains { $0.contains("set aside") })

        // A folder the server cannot write: the change is kept in memory, and said.
        let folder = directory.url.appendingPathComponent("locked", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let locked = IndexStampFile(url: folder.appendingPathComponent(IndexStampFile.fileName))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path) }
        locked.set(74, forKey: IndexingPipeline.dateIndexVersionKey)
        // Root writes any folder: the check is for the server's own user.
        guard getuid() != 0 else { return }
        #expect(locked.writeProblem != nil)
        #expect(locked.integer(forKey: IndexingPipeline.dateIndexVersionKey) == 74)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        locked.set(4, forKey: IndexingPipeline.ftsSchemaVersionKey)
        #expect(locked.writeProblem == nil)
        let reread = IndexStampFile(url: folder.appendingPathComponent(IndexStampFile.fileName))
        #expect(reread.integer(forKey: IndexingPipeline.dateIndexVersionKey) == 74 && reread.integer(forKey: IndexingPipeline.ftsSchemaVersionKey) == 4)
    }

    // MARK: The job

    /// The three fixture volumes, indexed by a job: each volume's documents in the index, the served index
    /// opened again over the file once the job closed it, its write-ahead log folded in, and the stamps
    /// the kit's after the passes, kept beside the index.
    @Test func aJobIndexesTheLibrarysVolumesAndStampsTheIndex() async throws {
        let f = try await Self.open()
        defer { withExtendedLifetime(f.directory) {} }
        let job = try await f.indexer.index(.asked(nil), requestedBy: "alice")
        #expect(job.kind == .libraryIndex && job.subject == "every volume waiting" && job.requestedBy == "alice")
        let done = try await f.finished(job)
        #expect(done.state == .succeeded && done.progress == "Indexed 3 volumes." && done.error == nil, "\(done)")
        // Before any connection of the test's own, which would make an empty log beside a file in
        // write-ahead-log mode: the writer's log is folded into the file, and no longer holds a page.
        let log = (try? FileManager.default.attributesOfItem(atPath: f.files.liveIndex.path + "-wal"))?[.size] as? NSNumber
        #expect(log == nil || log == 0, "the writer's log holds \(log ?? 0) bytes")
        let counts = try f.indexed()
        #expect(counts == Self.documents, "\(counts)")
        #expect(try f.unfinished().isEmpty)
        #expect(await f.recorder.events == ["will write"] + Self.fixtures.map { "wrote \($0)" } + ["finished"])
        let served = try #require(await f.state.index)
        #expect(served.summary.volumes == 3 && served.summary.documents == 393, "\(served.summary)")
        #expect(served.summary.indexVersion == IndexCompatibility.supportedIndexVersion, "\(served.summary)")

        let stamps = IndexStampFile(url: f.stampsFile)
        #expect(stamps.integer(forKey: IndexingPipeline.dateIndexVersionKey) == IndexingPipeline.currentDateIndexVersion)
        #expect(stamps.integer(forKey: IndexingPipeline.ftsSchemaVersionKey) == IndexingPipeline.currentFTSSchemaVersion)
        #expect(stamps.integer(forKey: IndexingPipeline.personRollupVersionKey) == IndexingPipeline.currentPersonRollupVersion)
        #expect(stamps.integer(forKey: IndexingPipeline.personRollupDateIndexVersionKey) == IndexingPipeline.currentDateIndexVersion)
        #expect(stamps.string(forKey: IndexingPipeline.brokenRefsIndexAppliedKey) != nil)
        #expect(stamps.failures().isEmpty)
        #expect(await IndexingStateTracker(store: stamps).interruptedVolumeIds().isEmpty)
        let status = await f.indexer.status()
        #expect(!status.jobActive && status.indexing == nil && status.failures.isEmpty && status.interrupted.isEmpty)

        // A second job finds nothing waiting.
        let again = try await f.finished(try await f.indexer.index(.asked(nil), requestedBy: nil))
        #expect(again.state == .succeeded && again.progress == "No volume was waiting to be indexed.")
    }

    /// A volume whose XML does not parse is kept failed, with the stage the kit's stream gave, while the
    /// others are indexed and the rollup built; a later job leaves it out until it is asked for, or
    /// downloaded again, and a pass that indexes it forgets the failure.
    @Test func aVolumeThatFailsToParseIsKeptFailedAndTheOthersAreIndexed() async throws {
        let f = try await Self.open()
        defer { withExtendedLifetime(f.directory) {} }
        try Self.writeBroken(in: f.volumes)
        let done = try await f.finished(try await f.indexer.index(.asked(nil), requestedBy: nil))
        #expect(done.state == .failed && done.error == "Indexed 3 of 4 volumes; 1 could not be indexed, which the Library says why.", "\(done)")
        let counts = try f.indexed()
        #expect(counts == Self.documents, "\(counts)")
        let record = try #require(IndexStampFile(url: f.stampsFile).failures()[Self.brokenId])
        #expect(record.kind == .failed && record.stage == "reading", "\(record)")
        #expect(record.sentence.hasPrefix("Its XML could not be parsed while its XML was read: the parser's error "), "\(record.sentence)")
        #expect(!record.sentence.contains(f.volumes.path))
        // The passes after indexing ran over the three.
        let stamps = IndexStampFile(url: f.stampsFile)
        #expect(stamps.integer(forKey: IndexingPipeline.personRollupVersionKey) == IndexingPipeline.currentPersonRollupVersion)
        #expect(await f.indexer.status().failures.keys.sorted() == [Self.brokenId])

        // Not taken again after a download that fetched others, nor at a start.
        let later = try await f.finished(try await f.indexer.index(.afterDownload(["frus1894Nicaragua"]), requestedBy: nil))
        #expect(later.state == .succeeded && later.progress == "No volume was waiting to be indexed.", "\(later)")
        #expect(try await f.restarted().indexer.resumeAtStart() == nil)
        // Taken when asked for, and once its file parses, indexed and forgotten.
        let asked = try await f.finished(try await f.indexer.index(.asked([Self.brokenId]), requestedBy: nil))
        #expect(asked.state == .failed)
        let xml = try String(contentsOf: RepositoryFiles.tei.appendingPathComponent("frus1894Nicaragua.xml"), encoding: .utf8)
        try Data(xml.utf8).write(to: f.volumes.appendingPathComponent("\(Self.brokenId).xml"))
        let fixed = try await f.finished(try await f.indexer.index(.afterDownload([Self.brokenId]), requestedBy: nil))
        #expect(fixed.state == .succeeded && fixed.progress == "Indexed 1 volume.", "\(fixed)")
        #expect(try f.indexed()[Self.brokenId] == 139)
        #expect(IndexStampFile(url: f.stampsFile).failures().isEmpty)
    }

    /// A cancel asked for while a volume's pass runs, or between two, stops the job before its next volume:
    /// the volumes indexed stay, the passes after indexing run over them, and the next job takes the rest.
    @Test func aCancelStopsTheJobBetweenVolumes() async throws {
        let gate = JobGate()
        let f = try await Self.open(held: gate)
        defer { withExtendedLifetime(f.directory) {} }
        let job = try await f.indexer.index(.asked(nil), requestedBy: nil)
        await gate.untilReached()
        let asked = try await f.queue.cancel(job.id, by: "alice")
        #expect(asked.state == .running && asked.cancelRequestedBy == "alice")
        gate.open()
        let done = try await f.finished(job)
        #expect(done.state == .cancelled && done.progress == "Indexed 1 of 3 volumes before the cancel.", "\(done)")
        #expect(try f.indexed() == ["frus1894Nicaragua": 139])
        #expect(try f.unfinished().isEmpty)
        #expect(await f.recorder.events == ["will write", "wrote frus1894Nicaragua", "finished"])
        #expect(IndexStampFile(url: f.stampsFile).integer(forKey: IndexingPipeline.personRollupVersionKey) == IndexingPipeline.currentPersonRollupVersion)
        #expect(IndexStampFile(url: f.stampsFile).failures().isEmpty)
        let rest = try await f.finished(try await f.indexer.index(.asked(nil), requestedBy: nil))
        #expect(rest.state == .succeeded && rest.progress == "Indexed 2 volumes.", "\(rest)")
        let counts = try f.indexed()
        #expect(counts == Self.documents, "\(counts)")
    }

    /// A start indexes what waits: every volume file when there is no index, and what the index lacks once
    /// there is one; but not a volume whose pass a stop of the server cut short, which the kit's sentinel
    /// names, nor one whose indexing failed. An admin's Index takes the one a stop cut short.
    @Test func aStartIndexesWhatWaitsButAPassAStopCutShort() async throws {
        let f = try await Self.open(volumes: [Self.fixtures[0]])
        defer { withExtendedLifetime(f.directory) {} }
        let first = try #require(await f.indexer.resumeAtStart())
        #expect(first.subject == "the volumes waiting at the server's start")
        #expect(try await f.finished(first).state == .succeeded)
        #expect(try f.indexed() == ["frus1894Nicaragua": 139])
        #expect(try await f.restarted().indexer.resumeAtStart() == nil, "nothing waits")

        // Two more volumes arrive; a stop of the server cut one's pass short, as the sentinel says.
        try RepositoryFiles.mountTEI(Array(Self.fixtures.dropFirst()), at: f.volumes)
        await IndexingStateTracker(store: IndexStampFile(url: f.stampsFile)).markStarted(volumeId: "frus1961-63v06")
        let next = try await f.restarted()
        let status = await next.indexer.status()
        #expect(status.interrupted == ["frus1961-63v06"] && !status.jobActive)
        let resumed = try #require(await next.indexer.resumeAtStart())
        #expect(try await next.finished(resumed).progress == "Indexed 1 volume.")
        #expect(try next.indexed().keys.sorted() == ["frus1894Nicaragua", "frus1969-76ve09p1"])
        #expect(try await next.restarted().indexer.resumeAtStart() == nil, "the volume a stop cut short is left for an admin")
        // Nor does a download that did not fetch it take it: its pass may have brought the server down.
        let other = try await next.finished(try await next.indexer.index(.afterDownload(["frus1894Nicaragua"]), requestedBy: nil))
        #expect(other.state == .succeeded && other.progress == "No volume was waiting to be indexed.", "\(other)")
        let asked = try await next.finished(try await next.indexer.index(.asked(["frus1961-63v06"]), requestedBy: "alice"))
        #expect(asked.state == .succeeded && asked.progress == "Indexed 1 volume.")
        let counts = try next.indexed()
        #expect(counts == Self.documents, "\(counts)")
        #expect(await next.indexer.status().interrupted.isEmpty)
    }

    /// A download job that fetched volumes queues their indexing, in a job of the server's own once the
    /// download has ended, and requests made while it waits join it.
    @Test func aDownloadThatFetchedVolumesQueuesTheirIndexing() async throws {
        let f = try await LibraryTests.open(github: try LibraryTests.servingFixtures())
        defer { withExtendedLifetime(f.directory) {} }
        let files = DataDirectory(root: f.directory.url.appendingPathComponent("data", isDirectory: true))
        try files.prepare()
        let state = ServerState(configuration: ServerConfiguration(mode: .standalone, dataDirectory: files.root))
        let indexer = LibraryIndexer(liveIndex: files.liveIndex, volumesDirectory: f.volumes, mode: .standalone,
                                     resources: try IndexingResources.loading(fromDirectory: RepositoryFiles.resources),
                                     jobs: f.queue, state: state, observer: Recorder(state: state), capacity: { .max })
        f.library.whenDownloadsEnd { fetched in _ = try? await indexer.index(.afterDownload(fetched), requestedBy: nil) }
        let download = try await f.library.download(.volumes(Array(LibraryTests.fixtures.prefix(2))), requestedBy: "alice")
        await f.queue.waitUntilIdle()
        let jobs = await f.queue.jobs()
        #expect(jobs.map(\.kind) == [.libraryIndex, .libraryDownload])
        let indexing = try #require(jobs.first)
        #expect(indexing.subject == "2 volumes, after their download" && indexing.requestedBy == nil)
        #expect(indexing.state == .succeeded && indexing.progress == "Indexed 2 volumes.", "\(indexing)")
        #expect(try #require(await f.queue.job(download.id)).state == .succeeded)
        #expect(await state.index?.summary.volumes == 2)
    }

    /// Requests made while a job waits make one job, which takes what each asked.
    @Test func requestsJoinTheJobThatWaits() async throws {
        let f = try await Self.open()
        defer { withExtendedLifetime(f.directory) {} }
        let gate = JobGate()
        let blocker = try await f.queue.submit(.indexReset, subject: nil, requestedBy: nil, id: nil, onCancel: nil) { _ in
            await gate.wait()
            return nil
        }
        let first = try await f.indexer.index(.asked([Self.fixtures[0]]), requestedBy: "alice")
        let second = try await f.indexer.index(.afterDownload([Self.fixtures[1]]), requestedBy: nil)
        #expect(first.id == second.id)
        #expect(await f.indexer.holds(Self.fixtures[2]), "a job that waits for every volume waiting may take it")
        gate.open()
        _ = try await f.finished(blocker)
        let done = try await f.finished(first)
        #expect(done.state == .succeeded && done.progress == "Indexed 3 volumes.", "\(done)")
        #expect(await f.queue.jobs().filter { $0.kind == .libraryIndex }.count == 1)
        #expect(await !f.indexer.holds(Self.fixtures[2]))
    }

    /// A volume's pass that would leave the data volume short stops the job before it, and the volume is
    /// taken again by the next indexing.
    @Test func aDataVolumeShortOfRoomStopsTheJob() async throws {
        let f = try await Self.open(capacity: 1_048_576)
        defer { withExtendedLifetime(f.directory) {} }
        let done = try await f.finished(try await f.indexer.index(.asked(nil), requestedBy: nil))
        #expect(done.state == .failed, "\(done)")
        #expect(done.error?.hasPrefix("Indexed 0 of 3 volumes, then stopped at frus1894Nicaragua: the data volume has 1 MB free, and indexing frus1894Nicaragua needs about ") == true,
                "\(done.error ?? "")")
        #expect(try f.indexed().isEmpty)
    }

    /// An Import server indexes nothing, and a Standalone server writes no index it does not serve.
    @Test func importModeIndexesNothingAndAnUnservedIndexIsNotWritten() async throws {
        let f = try await Self.open(mode: .import)
        defer { withExtendedLifetime(f.directory) {} }
        await #expect(throws: LibraryIndexingRefusal.importMode) { try await f.indexer.index(.asked(nil), requestedBy: nil) }
        #expect(await f.indexer.resumeAtStart() == nil)

        let s = try await Self.open()
        defer { withExtendedLifetime(s.directory) {} }
        try Data("not an index".utf8).write(to: s.files.liveIndex)
        await s.state.openExistingIndex(files: s.files)
        #expect(await s.state.index == nil)
        let done = try await s.finished(try await s.indexer.index(.asked(nil), requestedBy: nil))
        #expect(done.state == .failed && done.error?.hasPrefix("The index in /data/index is not being served (") == true, "\(done)")
        #expect(try Data(contentsOf: s.files.liveIndex) == Data("not an index".utf8))
    }

    /// An index another took the place of, as an import's, leaves no stamp or record behind it.
    @Test func anIndexReplacedLeavesNoStamps() async throws {
        let f = try await Self.open()
        defer { withExtendedLifetime(f.directory) {} }
        try Self.writeBroken(in: f.volumes)
        _ = try await f.finished(try await f.indexer.index(.asked(nil), requestedBy: nil))
        #expect(!IndexStampFile(url: f.stampsFile).failures().isEmpty)
        for suffix in ["-wal", "-shm"] { try Data("the old file's".utf8).write(to: URL(fileURLWithPath: f.files.liveIndex.path + suffix)) }
        await f.indexer.indexWasReplaced()
        let stamps = IndexStampFile(url: f.stampsFile)
        #expect(stamps.failures().isEmpty && stamps.integer(forKey: IndexingPipeline.dateIndexVersionKey) == 0)
        for suffix in ["-wal", "-shm"] {
            #expect(!FileManager.default.fileExists(atPath: f.files.liveIndex.path + suffix), "the old file's \(suffix) is gone")
        }
    }

    /// A volume the index holds whole, with a record or a sentinel entry a stop left after its last write,
    /// is settled by an admin's Index: indexed, and forgotten by both.
    @Test func aVolumeStoredWholeIsSettledByAnAdminsIndex() async throws {
        let f = try await Self.open()
        defer { withExtendedLifetime(f.directory) {} }
        _ = try await f.finished(try await f.indexer.index(.asked(nil), requestedBy: nil))
        f.indexer.stamps.recordFailure(IndexingFailureRecord(kind: .stopped, stage: "storingTables", sentence: "Cut short.", at: Date()),
                                       for: "frus1894Nicaragua")
        await f.indexer.tracker.markStarted(volumeId: "frus1961-63v06")
        let before = await f.indexer.status()
        #expect(before.failures.keys.sorted() == ["frus1894Nicaragua"] && before.interrupted == ["frus1961-63v06"])
        let done = try await f.finished(try await f.indexer.index(.asked(["frus1894Nicaragua", "frus1961-63v06"]), requestedBy: "alice"))
        #expect(done.state == .succeeded && done.progress == "No volume was waiting to be indexed.", "\(done)")
        let after = await f.indexer.status()
        #expect(after.failures.isEmpty && after.interrupted.isEmpty, "\(after)")
    }

    /// A stop of the server mid-job leaves the index's write-ahead log beside it, with commits a checkpoint
    /// may not have reached: a start folds it before the index is opened, read immutable, which then reads
    /// every volume the job stored.
    @Test func aStartFoldsTheLogAStopLeftBeforeTheIndexIsOpened() async throws {
        let f = try await Self.open()
        defer { withExtendedLifetime(f.directory) {} }
        // The job's writer, as a stop leaves it: the file and its log copied while the writer holds them open.
        let built = f.directory.url.appendingPathComponent("built", isDirectory: true)
        try FileManager.default.createDirectory(at: built, withIntermediateDirectories: true)
        let database = built.appendingPathComponent("frus.db")
        do {
            let store = try FTS5Store(databaseURL: database)
            let writer = try IndexingPipeline(fts5Store: store, databaseURL: database, volumesDirectory: f.volumes,
                                              resources: try IndexingResources.loading(fromDirectory: RepositoryFiles.resources),
                                              defaults: InMemoryIndexingStampStore())
            for id in Self.fixtures { try await writer.indexVolume(id) }
            for suffix in ["", "-wal"] {
                try FileManager.default.copyItem(atPath: database.path + suffix, toPath: f.files.liveIndex.path + suffix)
            }
            withExtendedLifetime(writer) {}
        }
        let log = (try FileManager.default.attributesOfItem(atPath: f.files.liveIndex.path + "-wal")[.size] as? NSNumber)?.intValue ?? 0
        #expect(log > 0, "the copy holds a log")
        #expect(await f.indexer.foldLogAtStart())
        let left = (try? FileManager.default.attributesOfItem(atPath: f.files.liveIndex.path + "-wal"))?[.size] as? NSNumber
        #expect(left == nil || left == 0, "the log is folded: \(left ?? 0) bytes left")
        let opened = try CorpusIndex.open(f.files.liveIndex)
        #expect(opened.summary.documents == 393 && opened.summary.volumes == 3, "\(opened.summary)")
    }
}
