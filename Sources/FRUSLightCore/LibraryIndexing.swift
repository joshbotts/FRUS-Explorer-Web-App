// The library's indexing (PLAN's S21d): a Standalone server indexes the volumes its library keeps with
// FRUSCoreKit's read-write pipeline, as `frus-parity index` does and as the app does once a download
// lands: `indexVolume` a volume at a time, then the passes after indexing, `runPostIndexPasses`, in jobs
// of the server's queue, so that the index has one writer, which never runs beside a download, an
// import or a reset. The kit chooses the volumes (`volumesAwaitingIndex(excluding:)`), keeps its stamps
// in a file beside the index (`IndexStampFile`), and says how a pass goes (`progressStream`); the server
// keeps each volume a pass did not index against it, with the stage the stream gave last. A cancel stops
// a job before its next volume, or, with S21a's stop turned on, within the volume under way once its
// documents are stored, which leaves that volume for a later pass to finish, as the kit's model of a
// pass cut short has it (#1566).

import FRUSCoreKit
import FTS5Store
import Foundation

/// What the served index is told while a job of the library's writes the file it serves.
public protocol IndexWritingObserver: Sendable {
    /// A job is about to write the index at `url`, which may not exist yet. With `holding` nil the index is
    /// served while the job writes it, through the kit's live read-only opens (PLAN's S21e); with a sentence,
    /// the job holds the file to itself, as a compaction does, and nothing reads it until the job has
    /// closed it, the sentence saying why meanwhile.
    func willWriteIndex(at url: URL, holding: String?) async
    /// A volume's pass has ended, indexed or not: what it committed is in the file.
    func didWriteVolume(_ volumeId: String, at url: URL) async
    /// The job has closed the index: its writer's connections are closed, and the file holds every commit.
    func didFinishWritingIndex(at url: URL) async
}

/// Why the library indexes nothing for a request.
public enum LibraryIndexingRefusal: Error, Equatable, Sendable {
    /// An Import server serves the Mac's export, and indexes nothing.
    case importMode
    /// A removal of the volume waits or runs already (PLAN's S21e).
    case removalInProgress(String)
}

/// Where the library's indexing stands, for the Library and Status: the volume a job indexes now, the
/// volumes a pass did not index, and those whose pass a stop of the server cut short.
public struct LibraryIndexingStatus: Sendable, Equatable {
    /// The volume a job is indexing now.
    public var indexing: String?
    /// Whether an indexing job waits or runs.
    public var jobActive: Bool
    /// The volumes a pass did not index, by id.
    public var failures: [String: IndexingFailureRecord]
    /// The volumes whose pass began and never ended, as the kit's sentinel names them, but the one under way.
    public var interrupted: Set<String>
    /// The volumes the job running has indexed so far, which the served index holds once it ends.
    public var indexedSoFar: Set<String> = []
}

/// The library's indexer: a Standalone server's one writer of its index, through jobs of the queue.
public actor LibraryIndexer {
    /// What to index.
    public enum Request: Sendable, Equatable {
        /// What a start finds waiting: the volumes the kit lists, less those whose indexing failed and
        /// those whose pass a stop of the server cut short, which the kit's sentinel names: a volume that
        /// brought a server down would bring it down at every start, as the app's launch leaves such a
        /// volume to its reader.
        case atStart
        /// After a download job: the volumes the kit lists, those a pass left unfinished among them, less
        /// those whose indexing failed but for the volumes this download fetched, whose files are new.
        case afterDownload([String])
        /// An admin's Index: these volumes, or every volume waiting, whatever was kept of their last pass.
        case asked([String]?)
    }

    /// A request merged into a job that waits, so that a start's job and a download's, or two
    /// downloads', make one job.
    struct Pending: Sendable, Equatable {
        /// Whether the sentinel's volumes are left out: only when every request merged was a start's.
        var leavesInterrupted: Bool
        /// The volumes taken whatever was kept of their last pass.
        var retrying: Set<String>
        /// The volumes asked for, or nil for every one waiting.
        var only: Set<String>?
        /// Whether every volume is taken whatever was kept of its last pass: an admin's Index of all.
        var retriesAll: Bool

        init(_ request: Request) {
            switch request {
            case .atStart: (leavesInterrupted, retrying, only, retriesAll) = (true, [], nil, false)
            case .afterDownload(let fetched): (leavesInterrupted, retrying, only, retriesAll) = (false, Set(fetched), nil, false)
            case .asked(let ids?): (leavesInterrupted, retrying, only, retriesAll) = (false, Set(ids), Set(ids), false)
            case .asked(nil): (leavesInterrupted, retrying, only, retriesAll) = (false, [], nil, true)
            }
        }

        mutating func merge(_ other: Pending) {
            leavesInterrupted = leavesInterrupted && other.leavesInterrupted
            retrying.formUnion(other.retrying)
            only = only.flatMap { mine in other.only.map { mine.union($0) } }
            retriesAll = retriesAll || other.retriesAll
        }
    }

    /// The index the job writes, and its folder, where the stamps are.
    public let liveIndex: URL
    public let volumesDirectory: URL
    nonisolated public let mode: ServerConfiguration.Mode
    /// The stamps and the record of the volumes a pass did not index, beside the index.
    nonisolated public let stamps: IndexStampFile
    let resources: IndexingResources
    let jobs: any JobQueue
    let state: ServerState
    let observer: (any IndexWritingObserver)?
    /// The kit's interrupted-indexing sentinel, kept in the stamps.
    nonisolated let tracker: IndexingStateTracker
    /// Free bytes on the index's volume.
    let capacity: @Sendable () throws -> Int64
    let now: @Sendable () -> Date
    let log: @Sendable (String) -> Void
    /// What each job queued and not yet begun asked for, by its id, and the one that waits, which a request
    /// may join.
    private var requests: [String: Pending] = [:]
    private var waitingJob: String?
    /// The job running; its list, every volume of it until the job ends, or nil until it is read; the one it
    /// indexes now; and those it has indexed.
    var runningJob: String?
    var runningList: Set<String>?
    var runningVolume: String?
    var runningIndexed: Set<String> = []
    /// Test hook: told the writer's pipeline once a job has opened it, before its first volume.
    var writerOpenedTestHook: (@Sendable (IndexingPipeline) async -> Void)?
    /// The volumes a removal job waits or runs for (PLAN's S21e, IndexUpkeep.swift).
    var queuedRemovals: Set<String> = []
    /// The job that records users' reviews in the index and waits, which a review joins (PLAN's S21f, ReviewStamps.swift).
    var waitingReviewJob: String?

    /// Test hook: installs `writerOpenedTestHook`.
    func setWriterOpenedTestHook(_ hook: (@Sendable (IndexingPipeline) async -> Void)?) {
        writerOpenedTestHook = hook
    }

    /// The space a volume's pass leaves free on the data volume beyond twice its file's length, which the
    /// index grows by at most and its write-ahead log takes meanwhile: the user store and its backups
    /// share the volume.
    static let spareBytes: Int64 = 64 * 1_048_576
    /// How long a job waits for the kit's progress stream to say how a failed pass ended.
    static let streamPatience: Duration = .seconds(5)

    public init(liveIndex: URL, volumesDirectory: URL, mode: ServerConfiguration.Mode, resources: IndexingResources,
                jobs: any JobQueue, state: ServerState, observer: (any IndexWritingObserver)? = nil,
                capacity: @escaping @Sendable () throws -> Int64, now: @escaping @Sendable () -> Date = Date.init,
                log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.liveIndex = liveIndex.standardizedFileURL
        self.volumesDirectory = volumesDirectory.standardizedFileURL
        self.mode = mode
        self.resources = resources
        self.jobs = jobs
        self.state = state
        self.observer = observer
        self.capacity = capacity
        self.now = now
        self.log = log
        let stamps = IndexStampFile(url: self.liveIndex.deletingLastPathComponent().appendingPathComponent(IndexStampFile.fileName),
                                    now: now(), log: log)
        self.stamps = stamps
        tracker = IndexingStateTracker(store: stamps)
    }

    /// Where indexing stands now.
    public func status() async -> LibraryIndexingStatus {
        var interrupted = Set(await tracker.interruptedVolumeIds())
        if let volume = runningVolume { interrupted.remove(volume) }
        return LibraryIndexingStatus(indexing: runningVolume, jobActive: waitingJob != nil || runningJob != nil,
                                     failures: stamps.failures(), interrupted: interrupted, indexedSoFar: runningIndexed)
    }

    /// Whether a job may index `volumeId`, or has indexed it in an index not served yet: the one running holds
    /// every volume of its list until it ends, and any while it has not read its list, and one that waits
    /// may take any it was asked for. A volume a job holds is not removed meanwhile.
    public func holds(_ volumeId: String) -> Bool {
        if runningJob != nil {
            guard let runningList else { return true }
            if runningList.contains(volumeId) { return true }
        }
        guard let waitingJob, let request = requests[waitingJob] else { return false }
        return request.only?.contains(volumeId) ?? true
    }

    /// Another index took this one's place, as an import's does: what was kept of this one's is forgotten,
    /// and so is a write-ahead log or shared memory the file it replaced left beside its name, which SQLite
    /// would otherwise read into the new file at its next read-write open. `sameFile` is a Standalone reset's
    /// (PLAN's S21e), which empties the index in place: its side files are its own, and stay.
    public func indexWasReplaced(sameFile: Bool = false) {
        stamps.reset()
        if !sameFile {
            for suffix in ["-wal", "-shm"] { try? FileManager.default.removeItem(atPath: liveIndex.path + suffix) }
        }
        log(sameFile ? "The index in /data/index was emptied, so its stamps and records were cleared"
                     : "A new index was installed in /data/index, so the stamps and records of the one it replaced were cleared")
    }

    /// At a start, before the index found there is opened: a write-ahead log a stop left beside it, mid-job,
    /// is folded into the file through a connection of the server's own, so that the log a start leaves is
    /// short, as each job's end leaves it. The served stack reads through the log (PLAN's S21e), so a log
    /// that cannot be folded is said in the log alone. Gives whether the file holds every commit.
    @discardableResult
    public func foldLogAtStart() async -> Bool {
        guard mode == .standalone else { return true }
        let wal = liveIndex.path + "-wal"
        let size = ((try? FileManager.default.attributesOfItem(atPath: wal))?[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 0 else { return true }
        let folded = await foldLog()
        log(folded ? "The index's write-ahead log, which a stop left beside it, was folded into it before it was opened"
                   : "The index's write-ahead log, which a stop left beside it, could not be folded into it")
        return folded
    }

    /// Queues the indexing `request` asks for, in a job of the server's queue, or adds it to the job
    /// that waits already, which it gives. Throws `LibraryIndexingRefusal`, or what the queue throws when
    /// it cannot keep the job.
    @discardableResult
    public func index(_ request: Request, requestedBy: String?) async throws -> Job {
        guard mode == .standalone else { throw LibraryIndexingRefusal.importMode }
        let wanted = Pending(request)
        if let id = waitingJob, let job = await jobs.job(id), job.state == .queued, waitingJob == id, requests[id] != nil {
            // Checked again past the suspension: the job has not begun, and reads what is merged here.
            requests[id]?.merge(wanted)
            return job
        }
        let subject: String = switch request {
        case .asked(let ids?) where ids.count == 1: ids[0]
        case .asked(let ids?): "\(ids.count) volumes"
        case .afterDownload(let ids) where ids.count == 1: "\(ids[0]), after its download"
        case .afterDownload(let ids): "\(ids.count) volumes, after their download"
        case .atStart: "the volumes waiting at the server's start"
        case .asked(nil): "every volume waiting"
        }
        let id = UUID().uuidString
        requests[id] = wanted
        waitingJob = id
        do {
            return try await jobs.submit(.libraryIndex, subject: subject, requestedBy: requestedBy, id: id, onCancel: {
                await self.forget(id)
            }) { job in
                try await self.run(id, job: job)
            }
        } catch {
            forget(id)
            throw error
        }
    }

    /// At a start, once the queue is open: queues a job for the volumes waiting to be indexed, if any, as
    /// the app's launch indexes downloads that landed with it closed. Gives the job, if one was queued.
    @discardableResult
    public func resumeAtStart() async -> Job? {
        guard mode == .standalone else { return nil }
        // A reset a stop cut short, or an upgrade `prepareAtStart` began (PLAN's S21e): the kit's pass over every
        // volume, which takes what an interrupted run left with the rest, as the app's launch's pass does.
        if stamps.isResetting() || stamps.upgrade() != nil {
            let reason: WholePass = stamps.isResetting() ? .reset : .upgrade
            do {
                let job = try await queueWholePass(reason, requestedBy: nil)
                log("\(reason == .reset ? "Indexing every volume again, after a reset a stop of the server cut short" : "Re-indexing every volume for index version \(IndexingPipeline.currentDateIndexVersion)"), as job \(job.id)")
                return job
            } catch {
                log("The pass over every volume the start owes could not be queued: \(error)")
                return nil
            }
        }
        let leftOut = Set(await tracker.interruptedVolumeIds()).union(stamps.failures().filter { $0.value.kind == .failed }.keys)
        let waiting: [String]
        do {
            waiting = try await Blocking.run { [liveIndex, volumesDirectory, resources] in
                try Self.waitingAtStart(index: liveIndex, volumes: volumesDirectory, resources: resources, leftOut: leftOut)
            }
        } catch {
            log("The volumes waiting to be indexed could not be listed at the start: \(error)")
            return nil
        }
        if !leftOut.isEmpty {
            log("\(leftOut.count) \(leftOut.count == 1 ? "volume is" : "volumes are") left for an admin's Index, since \(leftOut.count == 1 ? "its" : "their") last pass failed or a stop of the server cut it short: \(leftOut.sorted().joined(separator: ", "))")
        }
        // A volume a download gave a file the index was not made from, before a stop took the indexing after it (PLAN's S21f).
        let owed = stamps.reindexOwed().subtracting(leftOut).filter {
            FileManager.default.fileExists(atPath: volumesDirectory.appendingPathComponent("\($0).xml").path)
        }
        guard !waiting.isEmpty || !owed.isEmpty else { return nil }
        do {
            let job = try await index(.atStart, requestedBy: nil)
            let count = Set(waiting).union(owed).count
            log("Indexing \(count) \(count == 1 ? "volume" : "volumes") the library holds and the index lacks, or holds from another file, as job \(job.id)")
            return job
        } catch {
            log("The indexing of the volumes waiting at the start could not be queued: \(error)")
            return nil
        }
    }

    /// The volumes a start indexes: with no index, every volume file in the folder; else those the kit
    /// lists, read through its live read-only open, as the served stack reads the index. Each less `leftOut`.
    static func waitingAtStart(index: URL, volumes: URL, resources: IndexingResources, leftOut: Set<String>) throws -> [String] {
        guard FileManager.default.fileExists(atPath: index.path) else {
            return volumeFiles(in: volumes).filter { !leftOut.contains($0) }
        }
        let store = try FTS5Store(readingLiveDatabaseAt: index)
        let pipeline = try IndexingPipeline(readingLiveIndexAt: index, fts5Store: store, resources: resources, volumesDirectory: volumes)
        return try pipeline.volumesAwaitingIndex(excluding: leftOut)
    }

    /// The volumes whose files are in the folder, by id, in order: what the kit's pass over every volume takes.
    static func volumeFiles(in volumes: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: volumes.path))?
            .filter { $0.hasSuffix(".xml") && !$0.hasPrefix(".") }
            .map { String($0.dropLast(4)) }
            .sorted() ?? []
    }

    private func forget(_ id: String) {
        requests[id] = nil
        if waitingJob == id { waitingJob = nil }
    }

    // MARK: The job

    /// The writer: the kit's read-write open of the index, its one connection pair.
    struct Writer: Sendable {
        let store: FTS5Store
        let pipeline: IndexingPipeline
    }

    /// How one volume's pass ended.
    enum Outcome {
        case indexed
        /// It was not indexed, for a reason of its own.
        case failed(IndexingFailureRecord)
        /// A cancel stopped it once its documents were stored.
        case stopped(IndexingFailureRecord)
        /// It was not indexed, and no volume after it can be either: the index cannot be written.
        case stopsTheJob(IndexingFailureRecord, String)
    }

    private func run(_ id: String, job: JobContext) async throws -> String? {
        // What it asked for; were that lost, the most careful request, a start's, never every volume.
        let request = requests.removeValue(forKey: id) ?? Pending(.atStart)
        if waitingJob == id { waitingJob = nil }
        runningJob = id
        defer { (runningJob, runningList, runningVolume, runningIndexed) = (nil, nil, nil, []) }

        try await job.step("Opening the index to write into it", fraction: 0)
        // The index a start finds is opened once the server listens: a job queued meanwhile waits for it.
        while await state.isOpeningIndexAtStart {
            try await Task.sleep(for: .milliseconds(100))
        }
        if FileManager.default.fileExists(atPath: liveIndex.path), await state.index == nil {
            let readiness = await state.readiness()
            throw JobFailed("The index in /data/index is not being served (\(readiness.detail)), so nothing was indexed into it.")
        }
        // Served while it is written: search reads each volume as its store commits (PLAN's S21e).
        await observer?.willWriteIndex(at: liveIndex, holding: nil)
        var writer: Writer?
        do {
            writer = try await openWriter()
        } catch {
            log("The index \(liveIndex.path) could not be opened to write into it: \(error)")
            await observer?.didFinishWritingIndex(at: liveIndex)
            throw JobFailed("The index in /data/index could not be opened to write into it, so nothing was indexed. The server's log says why.")
        }
        if let hook = writerOpenedTestHook { await hook(writer!.pipeline) }
        let relay = IndexingProgressRelay(job: job)
        let consumer = Task { [stream = writer!.pipeline.progressStream] in
            for await update in stream { await relay.take(update) }
        }
        let outcome: Result<String, any Error>
        do {
            outcome = .success(try await index(request, writer: writer!, relay: relay, job: job))
        } catch {
            outcome = .failure(error)
        }
        consumer.cancel()
        _ = await consumer.value
        // The writer's last reference: its connections close here. The log is folded into the file through
        // a connection of the server's own, so that it stays short; the served stack reads through it
        // (PLAN's S21e), so a log a reader keeps from folding at once is folded by the next job or start.
        writer = nil
        if !(await foldLog()) {
            try? await Task.sleep(for: .seconds(1))
            if !(await foldLog()) {
                log("The index's write-ahead log could not be folded into it after the job: the served index reads through it, and the next job or start folds it")
            }
        }
        await observer?.didFinishWritingIndex(at: liveIndex)
        return try outcome.get()
    }

    /// Folds the index's write-ahead log into the file and empties the log, through a connection of the
    /// server's own, which closes at once.
    func foldLog() async -> Bool {
        let path = liveIndex.path
        guard FileManager.default.fileExists(atPath: path + "-wal") else { return true }
        do {
            let busy = try await Blocking.run { () -> Bool in
                let db = try SQLiteConnection(path, readOnly: false)
                defer { db.close() }
                return try db.query("PRAGMA wal_checkpoint(TRUNCATE)").first?.first?.integer != 0
            }
            if busy { log("The index's write-ahead log could not be folded into it at once: a connection still reads it") }
            return !busy
        } catch {
            log("The index's write-ahead log could not be folded into it: \(error)")
            return false
        }
    }

    /// Opens the index read-write, as the kit sets it up, with S21a's stop turned on, so that a job that
    /// is cancelled stops within the volume under way once its documents are stored.
    func openWriter() async throws -> Writer {
        let (live, volumes, resources, stamps, tracker) = (liveIndex, volumesDirectory, self.resources, self.stamps, self.tracker)
        let writer = try await Blocking.run {
            let store = try FTS5Store(databaseURL: live)
            let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: live, volumesDirectory: volumes, resources: resources,
                                                stateTracker: tracker, concurrencyLimit: 1, defaults: stamps)
            return Writer(store: store, pipeline: pipeline)
        }
        await writer.pipeline.setStopsBetweenBatchesWhenCancelled(true)
        return writer
    }

    /// The volumes `request` takes, from the kit's list, through the writer's connection.
    private func volumes(for request: Pending, writer: Writer) async throws -> [String] {
        let records = stamps.failures()
        let sentinel = Set(await tracker.interruptedVolumeIds())
        if request.retriesAll || request.only != nil { await settle(Set(records.keys).union(sentinel), writer: writer) }
        let failed = Set(records.filter { $0.value.kind == .failed }.keys)
        // A pass the server's own stop or a cancel cut short keeps a `stopped` record; one the sentinel names with
        // none was cut short by a stop of the process, which the volume may have brought about: it is taken again
        // only when an admin asks, or its download fetched it again.
        let crashed = sentinel.subtracting(records.keys)
        var leftOut: Set<String> = []
        if !request.retriesAll {
            leftOut = failed.union(crashed)
            if request.leavesInterrupted { leftOut.formUnion(sentinel) }
            leftOut.subtract(request.retrying)
        }
        let waiting = try writer.pipeline.volumesAwaitingIndex(excluding: leftOut)
        // A volume a download gave a new file (PLAN's S21f), which the index may hold whole and so the kit
        // lists not: taken as the kit's waiting volumes are, by the same rules, while its file is in place,
        // so that `indexVolume` stamps in `document_revisions` what the new file changed.
        let listed = Set(waiting)
        let owed = stamps.reindexOwed()
            .filter { !leftOut.contains($0) && !listed.contains($0) }
            .filter { FileManager.default.fileExists(atPath: volumesDirectory.appendingPathComponent("\($0).xml").path) }
            .sorted()
        let list = waiting + owed
        guard let only = request.only else { return list }
        return list.filter(only.contains)
    }

    /// A download is about to put another file in `volumeId`'s place (PLAN's S21f): kept in the stamps before
    /// the file takes its name, so that the next pass, or the next start's, indexes the volume again from it.
    @discardableResult
    nonisolated public func oweReindex(_ volumeId: String) -> Bool {
        stamps.oweReindex(volumeId)
    }

    /// Whether a download gave `volumeId` a file the index has not been made from yet (PLAN's S21f).
    nonisolated public func owesReindex(_ volumeId: String) -> Bool {
        stamps.reindexOwed().contains(volumeId)
    }

    /// Forgets what was kept of a pass before for each of `volumeIds` that the index holds whole, its store
    /// finished: a stop after its last write and before the sentinel's, which the kit's list never takes again.
    private func settle(_ volumeIds: Set<String>, writer: Writer) async {
        for volumeId in volumeIds where Self.storedWhole(volumeId, writer: writer) {
            stamps.clearFailure(of: volumeId)
            await tracker.markCompleted(volumeId: volumeId)
        }
    }

    /// Whether the index holds `volumeId` with the record that its last store pass finished (#1566).
    static func storedWhole(_ volumeId: String, writer: Writer) -> Bool {
        (try? writer.pipeline.isVolumeIndexed(volumeId)) == true && (try? writer.pipeline.isStoreUnfinished(volumeId)) == false
    }

    /// The job's work, with the writer open: each volume a step, then the passes after indexing.
    private func index(_ request: Pending, writer: Writer, relay: IndexingProgressRelay, job: JobContext) async throws -> String {
        let list = try await volumes(for: request, writer: writer)
        guard !list.isEmpty else { return "No volume was waiting to be indexed." }
        var indexed = 0
        var failed: [String] = []
        var stopped: (volume: String, reason: String?)?
        var cancelled = false
        runningList = Set(list)
        do {
            for (position, volumeId) in list.enumerated() {
                try await job.step("Indexing \(volumeId) (\(position + 1) of \(list.count))",
                                   fraction: Double(position) / Double(list.count))
                if let shortage = shortage(for: volumeId) {
                    stopped = (volumeId, shortage)
                    break
                }
                runningVolume = volumeId
                await relay.begin(volumeId, position: position, count: list.count)
                let outcome = await indexOne(volumeId, writer: writer, relay: relay, job: job)
                runningVolume = nil
                switch outcome {
                case .indexed:
                    indexed += 1
                    runningIndexed.insert(volumeId)
                    stamps.clearFailure(of: volumeId)
                    stamps.upgradeDone(volumeId)
                    stamps.reindexDone(volumeId)
                case .failed(let record):
                    failed.append(volumeId)
                    stamps.recordFailure(record, for: volumeId)
                case .stopped(let record):
                    stamps.recordFailure(record, for: volumeId)
                    stopped = (volumeId, nil)
                    cancelled = true
                case .stopsTheJob(let record, let reason):
                    stamps.recordFailure(record, for: volumeId)
                    stopped = (volumeId, reason)
                }
                await publishUpgrade()
                await observer?.didWriteVolume(volumeId, at: liveIndex)
                if stopped != nil { break }
            }
        } catch is JobCancelled {
            cancelled = true
        }

        // The passes after indexing run over what was indexed, a cancel's job included: the rollup, the
        // broken references' flags and the subjects, each gated and idempotent, as the app's launch runs
        // them. Every volume in an index this server serves is at the kit's version: an import refuses
        // any other, and so does the open of the index found at a start, so the date-index and FTS
        // stamps are this build's, as the app records them after its first pass.
        await job.progress("Rebuilding the person rollup, the broken references' flags and the subjects", fraction: 1)
        // Not while an upgrade waits for its pass (PLAN's S21e), which records the version once it has run.
        if stamps.upgrade() == nil, writer.pipeline.installedDateIndexVersion == 0 {
            await writer.pipeline.markDateReindexComplete()
            await writer.pipeline.markFTSRebuildReindexComplete()
        }
        await writer.pipeline.runPostIndexPasses()
        if let problem = stamps.writeProblem {
            log("The index's stamps could not be written after the indexing: \(problem)")
        }

        let counted = "Indexed \(indexed) of \(list.count) \(list.count == 1 ? "volume" : "volumes")"
        if cancelled {
            let cut = stopped.map { " \($0.volume) was stopped once its documents were stored, and the next indexing finishes it." } ?? ""
            await job.progress("\(counted) before the cancel.\(cut)", fraction: nil)
            throw JobCancelled()
        }
        if let stopped, let reason = stopped.reason {
            throw JobFailed("\(counted), then stopped at \(stopped.volume): \(reason)")
        }
        guard failed.isEmpty else {
            throw JobFailed("\(counted); \(failed.count) could not be indexed, which the Library says why.")
        }
        return "Indexed \(indexed) \(indexed == 1 ? "volume" : "volumes")."
    }

    /// Why the volume's pass cannot begin for room on the data volume, or nil.
    private func shortage(for volumeId: String) -> String? {
        let file = volumesDirectory.appendingPathComponent("\(volumeId).xml").path
        let size = ((try? FileManager.default.attributesOfItem(atPath: file))?[.size] as? NSNumber)?.int64Value ?? 0
        let needed = 2 * size + Self.spareBytes
        guard let free = try? capacity(), free < needed else { return nil }
        return "the data volume has \(Self.megabytes(free)) free, and indexing \(volumeId) needs about \(Self.megabytes(needed)), with room for the user store and its backups."
    }

    public static func megabytes(_ bytes: Int64) -> String { "\(max(0, bytes) / 1_048_576) MB" }

    /// One volume's pass, in a child task beside a watcher that cancels it when an admin asks the job to
    /// stop meanwhile: S21a's stop then ends the pass once its documents are stored. Both are children of
    /// one group, so that nothing of the pass outlives it, and the writer's connections close with its
    /// last reference.
    private func indexOne(_ volumeId: String, writer: Writer, relay: IndexingProgressRelay, job: JobContext) async -> Outcome {
        enum Event: Sendable {
            case ended(Result<Void, any Error>)
            case cancelAsked
        }
        let pipeline = writer.pipeline
        let ended = await withTaskGroup(of: Event?.self) { group -> Result<Void, any Error> in
            group.addTask {
                do {
                    try await pipeline.indexVolume(volumeId)
                    return .ended(.success(()))
                } catch {
                    return .ended(.failure(error))
                }
            }
            group.addTask {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(200))
                    if !Task.isCancelled, await job.cancelRequested { return .cancelAsked }
                }
                return nil
            }
            var outcome: Result<Void, any Error> = .success(())
            while let event = await group.next() {
                switch event {
                case .ended(let result)?:
                    outcome = result
                    group.cancelAll()
                case .cancelAsked?:
                    // The pass stops at the kit's next check, and its end comes as another event.
                    group.cancelAll()
                case nil:
                    break
                }
            }
            return outcome
        }
        switch ended {
        case .success:
            return .indexed
        case .failure(let error):
            let stage = await relay.stage(of: volumeId, waiting: !Self.isNotFound(error), patience: Self.streamPatience)
            if stage == "storingTables", !(error is CancellationError), Self.storedWhole(volumeId, writer: writer) {
                // Stored whole before it threw, as in the FTS merge after the store: indexed, the sentinel told.
                log("\(volumeId)'s pass threw once its store had finished, so it is indexed: \(error)")
                await tracker.markCompleted(volumeId: volumeId)
                return .indexed
            }
            return outcome(of: error, volumeId: volumeId, stage: stage)
        }
    }

    static func isNotFound(_ error: any Error) -> Bool {
        if case IndexingError.volumeNotFound? = error as? IndexingError { return true }
        return false
    }

    /// How a pass that threw ended, in the server's words, with where it was.
    private func outcome(of error: any Error, volumeId: String, stage: String) -> Outcome {
        let at = now()
        func record(_ kind: IndexingFailureRecord.Kind, _ sentence: String) -> IndexingFailureRecord {
            IndexingFailureRecord(kind: kind, stage: stage, sentence: sentence, at: at)
        }
        switch error {
        case is CancellationError:
            return .stopped(record(.stopped, "An admin's cancel stopped its pass once its documents were stored, before its other tables: the next indexing finishes it."))
        case IndexingError.volumeNotFound:
            return .failed(record(.failed, "Its file, \(volumeId).xml, was not in the library's folder when its turn came."))
        case FRUSParserError.fileUnreadable:
            return .failed(record(.failed, "Its file could not be read \(Self.clause(stage))."))
        case FRUSParserError.xmlError(let underlying):
            log("\(volumeId) could not be indexed: its XML did not parse: \(underlying)")
            return .failed(record(.failed, "Its XML could not be parsed \(Self.clause(stage)): \(Self.parserSentence(underlying))."))
        case IndexingError.sqliteError(let code, let message):
            log("\(volumeId) could not be indexed: SQLite \(code): \(message)")
            if Self.stopsTheJob(code) {
                let reason = "the index could not be written (\(message)), so no volume after it was tried."
                return .stopsTheJob(record(.stopped, "The index could not be written \(Self.clause(stage)) (\(message)): the next indexing takes it again."), reason)
            }
            return .failed(record(.failed, "The index could not take it \(Self.clause(stage)) (\(message))."))
        case IndexingError.databaseOpenFailed(let message):
            log("\(volumeId) could not be indexed: the index could not be opened: \(message)")
            return .stopsTheJob(record(.stopped, "The index could not be opened \(Self.clause(stage)): the next indexing takes it again."),
                                "the index could not be opened, so no volume after it was tried.")
        default:
            log("\(volumeId) could not be indexed: \(error)")
            return .failed(record(.failed, "It stopped at an error \(Self.clause(stage)), which the server's log gives."))
        }
    }

    /// The stage, as a clause: where the pass was when it stopped.
    static func clause(_ stage: String) -> String {
        switch stage {
        case "reading": "while its XML was read"
        case "storingDocuments": "while its documents were stored"
        case "storingTables": "after its documents were stored, while its other tables were"
        default: "as its pass began"
        }
    }

    /// The XML parser's error in a sentence: its own words, which name a line and column where it can,
    /// and never a path.
    static func parserSentence(_ error: any Error) -> String {
        let nsError = error as NSError
        var parts: [String] = []
        if let line = nsError.userInfo["NSXMLParserErrorLineNumber"] as? Int { parts.append("line \(line)") }
        if let column = nsError.userInfo["NSXMLParserErrorColumn"] as? Int { parts.append("column \(column)") }
        let place = parts.isEmpty ? "" : " at \(parts.joined(separator: ", "))"
        return "the parser's error \(nsError.code)\(place)"
    }

    /// The SQLite results after which no later volume can be written either: a full disk, an index
    /// that is not a database or is damaged, and one that cannot be read, locked or written.
    static func stopsTheJob(_ code: Int32) -> Bool {
        [5, 6, 7, 8, 10, 11, 13, 14, 26].contains(code & 0xff)
    }
}

/// The kit's progress stream for one job, read as it comes: each update said in the job's line, and the
/// last stage each volume reached kept, so that a volume whose pass failed is kept with where it was.
actor IndexingProgressRelay {
    private let job: JobContext
    /// Whether it says each update in the job's line: not for the pass over every volume (PLAN's S21e), whose
    /// line says how far through the volumes it is, this relay keeping only each volume's stage.
    private let writesLine: Bool
    private var position = 0
    private var count = 1
    /// Each volume's last update before its pass ended.
    private var last: [String: IndexingProgressUpdate] = [:]
    /// Each volume's `.failed` or `.complete`.
    private var ended: [String: IndexingProgressUpdate] = [:]

    init(job: JobContext, writesLine: Bool = true) {
        self.job = job
        self.writesLine = writesLine
    }

    /// The job takes `volumeId`, the volume at `position` of `count`.
    func begin(_ volumeId: String, position: Int, count: Int) {
        self.position = position
        self.count = max(count, 1)
        last[volumeId] = nil
        ended[volumeId] = nil
    }

    func take(_ update: IndexingProgressUpdate) async {
        switch update.stage {
        case .failed, .complete:
            ended[update.volumeId] = update
        case .optimizing:
            break
        case .reading, .storingBatch:
            last[update.volumeId] = update
            guard writesLine else { return }
            let what = switch update.stage {
            case .reading where update.totalDocuments == 0: "reading its XML"
            case .reading: "read \(update.totalDocuments) \(update.totalDocuments == 1 ? "document" : "documents")"
            default: "storing \(update.totalDocuments) \(update.totalDocuments == 1 ? "document" : "documents") and its other tables"
            }
            let within = update.stage == .reading ? 0.2 : 0.6
            await job.progress("Indexing \(update.volumeId) (\(position + 1) of \(count)): \(what)",
                               fraction: (Double(position) + within) / Double(count))
        }
    }

    /// Where `volumeId`'s pass was when it failed: `starting`, `reading`, `storingDocuments` or
    /// `storingTables`, from the stream's last updates, once it has said the pass ended, or after
    /// `patience` when `waiting` and it has not.
    func stage(of volumeId: String, waiting: Bool, patience: Duration) async -> String {
        let deadline = ContinuousClock.now.advanced(by: patience)
        while waiting, ended[volumeId] == nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard let update = last[volumeId] else { return "starting" }
        switch update.stage {
        case .reading:
            return "reading"
        default:
            let end = ended[volumeId]
            let stored = end.map { $0.totalDocuments > 0 && $0.completedDocuments >= $0.totalDocuments } ?? false
            return stored ? "storingTables" : "storingDocuments"
        }
    }
}
