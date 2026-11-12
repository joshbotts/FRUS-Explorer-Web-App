// The upkeep of a Standalone server's index (PLAN's S21e), through its one writer, in jobs of the server's
// queue beside the library's indexing (LibraryIndexing.swift): a volume's removal from the index and then
// its files; a compaction; a check; a reset, which empties the index and indexes the library again; the
// kit's pass over every volume, which an upgrade and a reset run, as the app's launch and its Rebuild From
// Scratch run it; and, at a start, the index brought to this build: its schema, its full-text tables rebuilt
// from the documents it holds when they are of an earlier generation, a removal or a reset a stop cut short
// finished, and an upgrade to the kit's date-index version begun, which the start's pass does while search
// answers. Every rule is the kit's, compiled from the submodule: `removeVolume(_:)`, `vacuumIndex()`,
// `indexPageStatistics()`, `checkIndexIntegrity()`, `removeAllVolumesFromIndex()`, `indexAllVolumes()`,
// `rebuildSearchIndexFromCache()`, `needsDateReindex`, `installedDateIndexVersion`, the stamps and the passes
// after indexing; but whether a compaction is worth offering, the app's (`IndexCompaction`, app code), which
// `IndexCompactionRule` mirrors and `IndexUpkeepParityTests` holds to the app's source, beside the room the
// server's own copy needs, as its import's strip reckons it.

import FRUSCoreKit
import FTS5Store
import Foundation

/// Whether to compact the index, and the room it needs: the app's rule (`IndexCompaction`, in
/// `FRUSExplorer/Settings/SettingsComponents.swift`, app code), mirrored. A compaction is worth offering once
/// 200 MB or more could be reclaimed, and is safe once the data volume has the index's live size and 15 per
/// cent more free, since `VACUUM` writes a packed copy of the database before it replaces it.
public enum IndexCompactionRule {
    /// Below this, compacting is not worth the job and the hold on the index.
    public static let minimumWorthwhileBytes = 200 * 1024 * 1024
    /// Headroom above the live size before compaction is offered.
    public static let freeSpaceSafetyMargin = 1.15

    /// What to say of compaction now.
    public enum Availability: Equatable, Sendable {
        case notWorthwhile
        case insufficientSpace(reclaimable: Int, required: Int, available: Int)
        case available(reclaimable: Int, fraction: Double)
    }

    /// The app's `IndexCompaction.availability(statistics:availableBytes:)`, line for line.
    public static func availability(statistics: IndexPageStatistics?, availableBytes: Int?) -> Availability {
        guard let statistics, statistics.reclaimableBytes >= minimumWorthwhileBytes else {
            return .notWorthwhile
        }
        let required = Int(Double(statistics.liveBytes) * freeSpaceSafetyMargin)
        guard let availableBytes, availableBytes >= required else {
            return .insufficientSpace(reclaimable: statistics.reclaimableBytes,
                                      required: required,
                                      available: availableBytes ?? 0)
        }
        return .available(reclaimable: statistics.reclaimableBytes,
                          fraction: statistics.reclaimableFraction)
    }

    /// The room a compaction of `statistics`' index needs free, by the same rule.
    public static func required(_ statistics: IndexPageStatistics) -> Int {
        Int(Double(statistics.liveBytes) * freeSpaceSafetyMargin)
    }

    /// The room this server's compaction needs free on the data volume: `VACUUM` writes its packed copy in
    /// SQLite's temporary folder, which the server keeps on the data volume (`SQLITE_TMPDIR`, /data/tmp), and
    /// the copied pages to the write-ahead log beside the index, so twice the live size, and 64 MB to spare
    /// for the user store and its backups, as the import's strip reckons its copy.
    public static func serverRequired(_ statistics: IndexPageStatistics) -> Int64 {
        2 * Int64(statistics.liveBytes) + 64 * 1_048_576
    }
}

extension LibraryIndexer {
    /// What `/readyz` and search's 503 say while a compaction holds the index to itself.
    static let compactionHold = "The index is being compacted, which gives the disk back the room removed and re-indexed volumes left in it: search answers again once its job ends, and the reader opens documents meanwhile"
    /// What they say while a reset empties the index.
    static let resetHold = "The index is being emptied, to be indexed again from the library's volumes: search answers again, over what is indexed, once it is empty, and the reader opens documents meanwhile"

    // MARK: The writer, for the upkeep

    /// Runs `body` with the index's writer open, as each job of the upkeep does: once the start has opened
    /// the index found there, and never over an index the server does not serve; the served index told before
    /// the first write, served meanwhile unless `holding` says why it is held; and, after `body`, the writer let
    /// go, the log folded and the served index told it is whole, opened again over the file as it is now.
    func withWriter<T: Sendable>(holding: String?, _ body: (Writer) async throws -> T) async throws -> T {
        while await state.isOpeningIndexAtStart {
            try await Task.sleep(for: .milliseconds(100))
        }
        if FileManager.default.fileExists(atPath: liveIndex.path), await state.index == nil {
            let readiness = await state.readiness()
            throw JobFailed("The index in /data/index is not being served (\(readiness.detail)), so nothing was changed in it.")
        }
        await observer?.willWriteIndex(at: liveIndex, holding: holding)
        var writer: Writer?
        do {
            writer = try await openWriter()
        } catch {
            log("The index \(liveIndex.path) could not be opened to write into it: \(error)")
            await observer?.didFinishWritingIndex(at: liveIndex)
            throw JobFailed("The index in /data/index could not be opened to write into it, so nothing was changed. The server's log says why.")
        }
        if let hook = writerOpenedTestHook { await hook(writer!.pipeline) }
        let outcome: Result<T, any Error>
        do {
            outcome = .success(try await body(writer!))
        } catch {
            outcome = .failure(error)
        }
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

    /// The upgrade under way, as `/readyz` and the Library name it.
    func publishUpgrade() async {
        await state.setUpgrade(stamps.upgrade().map { IndexUpgradeStatus(from: $0.from, to: $0.to, volumes: $0.remaining) })
    }

    /// Before an import installs an export in the index's place (PLAN's S21c's seed): the log is folded into the
    /// file, so that no commit of the index it replaces is left in a log beside the new file's name, which a
    /// live read-only open would read into it, and `frus.db.prev` holds every commit.
    public func indexWillBeReplaced() async {
        guard mode == .standalone, FileManager.default.fileExists(atPath: liveIndex.path + "-wal") else { return }
        if !(await foldLog()) {
            log("The index's write-ahead log could not be folded into it before an import replaced it")
        }
    }

    // MARK: The pass over every volume

    /// Why the kit's pass over every volume runs.
    enum WholePass: Sendable, Equatable {
        /// An upgrade a start began: the stamps' date-index version is behind the kit's.
        case upgrade
        /// Standalone's reset, which emptied the index.
        case reset
    }

    /// Queues the pass over every volume a start owes, for an upgrade it began or a reset a stop cut short.
    func queueWholePass(_ reason: WholePass, requestedBy: String?) async throws -> Job {
        let subject = reason == .upgrade
            ? "every volume, re-indexed for index version \(IndexingPipeline.currentDateIndexVersion)"
            : "every volume, indexed again after the index's reset"
        return try await jobs.submit(reason == .upgrade ? .libraryIndex : .indexReset, subject: subject, requestedBy: requestedBy, id: nil) { job in
            try await job.step(reason == .upgrade ? "Re-indexing every volume from its file" : "Indexing every volume again from its file", fraction: 0)
            if reason == .reset {
                let line = try await self.runWholePass(.reset, job: job)
                await self.endReset()
                return line
            }
            return try await self.runWholePass(.upgrade, job: job)
        }
    }

    func endReset() {
        stamps.endResetting()
    }

    /// The kit's pass over every volume the library holds, `indexAllVolumes()`, as the app's upgrade at its
    /// launch and its Rebuild From Scratch run it (PLAN's S21e): each volume re-indexed from its file, one at a
    /// time, its revisions rebaselined rather than stamped, since no file changed, and a volume that fails
    /// passed over; the index served throughout and opened again after each volume; each volume that could
    /// not be indexed kept failed, with the stage its pass reached; then, for an upgrade, the date-index and
    /// FTS stamps the kit's, whatever failed, as the app marks them after its pass, and the passes after
    /// indexing. The pass runs to its end once begun, as the app's does: no cancel stops it part-way. Gives
    /// the job's last line.
    func runWholePass(_ reason: WholePass, job: JobContext) async throws -> String {
        let volumes = Self.volumeFiles(in: volumesDirectory)
        (runningJob, runningList, runningIndexed) = (job.id, Set(volumes), [])
        defer { (runningJob, runningList, runningVolume, runningIndexed) = (nil, nil, nil, []) }
        try await job.commit()
        let counted = try await withWriter(holding: nil) { writer -> (indexed: Int, failed: Int) in
            let relay = IndexingProgressRelay(job: job, writesLine: false)
            let updates = Task { [stream = writer.pipeline.progressStream] in
                for await update in stream { await relay.take(update) }
            }
            let events = Task { [stream = writer.pipeline.progress] () -> (indexed: Int, failed: Int) in
                var counts = (indexed: 0, failed: 0)
                var failures = Set<String>()
                for await event in stream {
                    switch event.state {
                    case .failed(let volumeId, let error):
                        failures.insert(volumeId)
                        counts.failed += 1
                        await self.passFailed(volumeId, error: error, relay: relay)
                    case .indexing(let volumeId, let current, let total) where current > 0 && !failures.contains(volumeId):
                        counts.indexed += 1
                        await self.passStored(volumeId, current: current, total: total, reason: reason, job: job)
                    case .completed:
                        return counts
                    default:
                        break
                    }
                }
                return counts
            }
            do {
                try await writer.pipeline.indexAllVolumes()
            } catch {
                events.cancel()
                updates.cancel()
                throw error
            }
            // The pass's last event says it ended; a pass that never says so is not waited for long.
            let watchdog = Task {
                try? await Task.sleep(for: .seconds(30))
                events.cancel()
            }
            let counted = await events.value
            watchdog.cancel()
            updates.cancel()
            _ = await updates.value
            if reason == .upgrade || writer.pipeline.installedDateIndexVersion == 0 {
                await writer.pipeline.markDateReindexComplete()
                await writer.pipeline.markFTSRebuildReindexComplete()
            }
            if let upgrade = stamps.upgrade() {
                stamps.endUpgrade()
                log("The index's upgrade to index version \(upgrade.to), from \(upgrade.from), is done: \(counted.indexed) volumes re-indexed, \(counted.failed) could not be")
            }
            await publishUpgrade()
            await job.progress("Rebuilding the person rollup, the broken references' flags and the subjects", fraction: 1)
            await writer.pipeline.runPostIndexPasses()
            if let problem = stamps.writeProblem {
                log("The index's stamps could not be written after the pass over every volume: \(problem)")
            }
            return counted
        }
        let done = reason == .upgrade ? "Re-indexed \(counted.indexed) of \(volumes.count) \(volumes.count == 1 ? "volume" : "volumes") for index version \(IndexingPipeline.currentDateIndexVersion)"
            : "indexed \(counted.indexed) of \(volumes.count) \(volumes.count == 1 ? "volume" : "volumes") again"
        return counted.failed == 0 ? "\(done)." : "\(done); \(counted.failed) could not be indexed, which the Library says why."
    }

    /// A volume the pass stored: served at once, its record and the upgrade's word on it brought up to date.
    private func passStored(_ volumeId: String, current: Int, total: Int, reason: WholePass, job: JobContext) async {
        runningIndexed.insert(volumeId)
        stamps.clearFailure(of: volumeId)
        stamps.upgradeDone(volumeId)
        await publishUpgrade()
        await observer?.didWriteVolume(volumeId, at: liveIndex)
        let what = reason == .upgrade ? "Re-indexed \(current) of \(total) volumes for index version \(IndexingPipeline.currentDateIndexVersion)"
            : "Indexed \(current) of \(total) volumes again"
        await job.progress("\(what): \(volumeId)", fraction: Double(current) / Double(max(total, 1)))
    }

    /// A volume the pass could not index: kept failed, with the stage it reached, its error in the log alone.
    private func passFailed(_ volumeId: String, error: String, relay: IndexingProgressRelay) async {
        let stage = await relay.stage(of: volumeId, waiting: false, patience: .zero)
        stamps.recordFailure(IndexingFailureRecord(kind: .failed, stage: stage,
                                                   sentence: "It could not be indexed \(Self.clause(stage)) in the pass over every volume, which the server's log gives.",
                                                   at: now()), for: volumeId)
        stamps.upgradeDone(volumeId)
        await publishUpgrade()
        log("\(volumeId) could not be indexed in the pass over every volume: \(error)")
    }

    // MARK: Removal

    /// Whether a removal of `volumeId` waits, runs, or was cut short by a stop and is still to be finished.
    public func isRemoving(_ volumeId: String) -> Bool {
        queuedRemovals.contains(volumeId) || stamps.removals().contains(volumeId)
    }

    /// The volumes a removal waits or runs for.
    public func removing() -> Set<String> {
        queuedRemovals.union(stamps.removals())
    }

    /// Queues the removal of `volumeId` (PLAN's S21e): a job, the index's one writer, which takes the volume
    /// out of the index with the kit's `removeVolume(_:)`, forgets what the server kept of its passes, runs
    /// the passes after indexing over what remains, folds the log, and then removes its files and its row
    /// through `files`, the library's `remove(_:)`. The removal is kept in the stamps from before its first
    /// write until its files are gone, so that one a stop of the server cut short is finished by the next
    /// start (`prepareAtStart`); one that fails is forgotten, for Remove to ask again. Throws
    /// `LibraryIndexingRefusal`, a removal of the volume waiting or running among them, or what the queue throws.
    @discardableResult
    public func remove(_ volumeId: String, requestedBy: String?,
                       files: @escaping @Sendable (String) async throws -> Void) async throws -> Job {
        guard mode == .standalone else { throw LibraryIndexingRefusal.importMode }
        // Checked and taken in one step of the actor's, so that two requests queue one removal.
        guard !isRemoving(volumeId) else { throw LibraryIndexingRefusal.removalInProgress(volumeId) }
        queuedRemovals.insert(volumeId)
        do {
            return try await jobs.submit(.libraryRemove, subject: volumeId, requestedBy: requestedBy, id: nil, onCancel: {
                await self.forgetRemoval(volumeId)
            }) { job in
                try await self.runRemoval(volumeId, job: job, files: files)
            }
        } catch {
            queuedRemovals.remove(volumeId)
            throw error
        }
    }

    func forgetRemoval(_ volumeId: String) {
        queuedRemovals.remove(volumeId)
    }

    private func runRemoval(_ volumeId: String, job: JobContext, files: @Sendable (String) async throws -> Void) async throws -> String? {
        defer { queuedRemovals.remove(volumeId) }
        try await job.step("Removing \(volumeId) from the index", fraction: 0)
        // From its first write it runs to its end; a stop of the server meanwhile is finished at the next start.
        try await job.commit()
        do {
            if FileManager.default.fileExists(atPath: liveIndex.path) {
                try await withWriter(holding: nil) { writer in
                    // Kept from before the first write, once the writer is open over the index served.
                    stamps.beginRemoval(volumeId)
                    try await takeOut(volumeId, writer: writer)
                    await job.progress("Rebuilding the person rollup, the broken references' flags and the subjects", fraction: 0.5)
                    await writer.pipeline.runPostIndexPasses()
                }
            }
            await job.progress("Removing \(volumeId)'s file and figure images", fraction: 0.9)
            try await files(volumeId)
        } catch {
            // Nothing waits to finish it: Remove asks again, as for a removal that never began.
            stamps.endRemoval(volumeId)
            throw error
        }
        stamps.endRemoval(volumeId)
        await publishUpgrade()
        log("Removed \(volumeId) from the index and the library")
        return "Removed \(volumeId) from the index and the library."
    }

    /// Takes `volumeId` out of the index through the writer, with what the server kept of its passes.
    func takeOut(_ volumeId: String, writer: Writer) async throws {
        try await writer.pipeline.removeVolume(volumeId)
        stamps.clearFailure(of: volumeId)
        await tracker.markCompleted(volumeId: volumeId)
        stamps.upgradeDone(volumeId)
    }

    // MARK: Compaction

    /// Queues a compaction of the index (PLAN's S21e): the kit's `vacuumIndex()`, once the data volume has the
    /// room the server's copy needs (`IndexCompactionRule.serverRequired`), read through a live read-only open
    /// before the job holds the index to itself, since `VACUUM` replaces the file under every read-only
    /// connection, which the kit asks its host to open again afterwards; the log then folded, so that the file
    /// shrinks, and the index opened again and served.
    @discardableResult
    public func compact(requestedBy: String?) async throws -> Job {
        guard mode == .standalone else { throw LibraryIndexingRefusal.importMode }
        return try await jobs.submit(.indexCompact, subject: nil, requestedBy: requestedBy, id: nil) { job in
            try await self.runCompaction(job: job)
        }
    }

    /// The index's room, by the kit's `indexPageStatistics()`, through a live read-only open of its own.
    func pageStatistics() async throws -> IndexPageStatistics? {
        let (index, resources, volumes) = (liveIndex, self.resources, volumesDirectory)
        let pipeline = try await Blocking.run {
            try IndexingPipeline(readingLiveIndexAt: index, fts5Store: try FTS5Store(readingLiveDatabaseAt: index),
                                 resources: resources, volumesDirectory: volumes)
        }
        return try await pipeline.indexPageStatistics()
    }

    /// Why the data volume has no room to compact `statistics`' index, or nil when it has.
    private func noRoom(_ statistics: IndexPageStatistics) -> String? {
        let required = IndexCompactionRule.serverRequired(statistics)
        guard let free = try? capacity(), free < required else { return nil }
        return "Compacting the index needs about \(Self.megabytes(required)) free on the data volume, for its copy and its log, which has \(Self.megabytes(free)), so nothing was changed."
    }

    private func runCompaction(job: JobContext) async throws -> String? {
        try await job.step("Compacting the index", fraction: 0)
        while await state.isOpeningIndexAtStart {
            try await Task.sleep(for: .milliseconds(100))
        }
        guard FileManager.default.fileExists(atPath: liveIndex.path), await state.index != nil else {
            throw JobFailed("No index is served, so there is none to compact.")
        }
        // The room, before the index is held: a compaction that cannot run holds nothing.
        if let statistics = try? await pageStatistics(), let reason = noRoom(statistics) { throw JobFailed(reason) }
        let before = try await withWriter(holding: Self.compactionHold) { writer -> Int in
            guard let statistics = try await writer.pipeline.indexPageStatistics() else {
                throw JobFailed("The index's size could not be read, so it was not compacted.")
            }
            if let reason = noRoom(statistics) { throw JobFailed(reason) }
            // Past here `VACUUM` runs, which no cancel stops part-way.
            try await job.commit()
            await job.progress("Compacting the index: \(Self.megabytes(Int64(statistics.reclaimableBytes))) to give back", fraction: 0.2)
            try await writer.pipeline.vacuumIndex()
            return statistics.fileBytes
        }
        let after = Self.fileBytes(liveIndex) + Self.fileBytes(URL(fileURLWithPath: liveIndex.path + "-wal"))
        return "Compacted the index from \(Self.megabytes(Int64(before))) to \(Self.megabytes(after))."
    }

    static func fileBytes(_ url: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value ?? 0
    }

    // MARK: Check

    /// Queues a check of the index (PLAN's S21e): the kit's `checkIndexIntegrity()`, SQLite's quick check and
    /// both full-text indexes' own, whose rank-1 form needs the writer, while search answers. The job fails,
    /// naming the first three, when it finds problems.
    @discardableResult
    public func checkIntegrity(requestedBy: String?) async throws -> Job {
        guard mode == .standalone else { throw LibraryIndexingRefusal.importMode }
        return try await jobs.submit(.indexCheck, subject: nil, requestedBy: requestedBy, id: nil) { job in
            try await self.runCheck(job: job)
        }
    }

    private func runCheck(job: JobContext) async throws -> String? {
        try await job.step("Checking the index: SQLite's quick check, and both full-text indexes' own", fraction: 0)
        guard FileManager.default.fileExists(atPath: liveIndex.path) else { throw JobFailed("No index is served, so there is none to check.") }
        let problems = try await withWriter(holding: nil) { writer in try await writer.pipeline.checkIndexIntegrity() }
        guard problems.isEmpty else {
            let shown = problems.prefix(3).joined(separator: "; ")
            throw JobFailed("The index's check found \(problems.count) \(problems.count == 1 ? "problem" : "problems"): \(shown)\(problems.count > 3 ? "; and more" : ""). Resetting the index indexes the library's volumes into it again.")
        }
        return "The index's check found no problems: SQLite's quick check and both full-text indexes' checks passed."
    }

    // MARK: Reset

    /// Queues Standalone's reset of the index (PLAN's S21e): a job that empties the index it serves with the
    /// kit's `removeAllVolumesFromIndex()`, holding it to itself meanwhile, or removes whole an index it does
    /// not serve, as one the start refused; forgets every stamp and record of it (`indexWasReplaced`); and then
    /// runs the kit's pass over every volume the library holds, as the app's Rebuild From Scratch follows its
    /// wipe, which search follows volume by volume. The reset is kept in the stamps from before its first
    /// write until its pass has ended, so that one a stop cut short is finished by the next start. The index's
    /// record of each document's revisions stays, as the kit keeps it through its own rebuild, which its
    /// pass rebaselines, so that the reviews of what an update changed survive. Refused when an index import
    /// finished after it was asked for, whose index it would empty.
    @discardableResult
    public func reset(requestedBy: String?) async throws -> Job {
        guard mode == .standalone else { throw LibraryIndexingRefusal.importMode }
        let asked = now()
        return try await jobs.submit(.indexReset, subject: nil, requestedBy: requestedBy, id: nil) { job in
            try await self.runReset(job: job, askedAt: asked)
        }
    }

    private func runReset(job: JobContext, askedAt: Date) async throws -> String? {
        try await job.step("Emptying the index", fraction: 0)
        if await jobs.jobs().contains(where: { $0.kind == .indexImport && $0.state == .succeeded && ($0.finishedAt ?? .distantPast) >= UserStoreDate.rounded(askedAt) }) {
            throw IndexResetRefusal()
        }
        try await job.commit()
        while await state.isOpeningIndexAtStart {
            try await Task.sleep(for: .milliseconds(100))
        }
        let removed = await state.index?.summary
        if FileManager.default.fileExists(atPath: liveIndex.path), removed != nil {
            stamps.markResetting()
            try await withWriter(holding: Self.resetHold) { writer in
                try await writer.pipeline.removeAllVolumesFromIndex()
            }
            // The same file, emptied: its side files are its own.
            indexWasReplaced(sameFile: true)
        } else {
            // An index the server does not serve, as one the start refused, goes whole, as Import mode's reset removes its index.
            for suffix in ["", "-wal", "-shm", "-journal"] where FileManager.default.fileExists(atPath: liveIndex.path + suffix) {
                try FileManager.default.removeItem(atPath: liveIndex.path + suffix)
            }
            indexWasReplaced()
        }
        stamps.markResetting()
        await publishUpgrade()
        await job.progress("Indexing every volume again from its file", fraction: 0.1)
        let line = try await runWholePass(.reset, job: job)
        stamps.endResetting()
        let emptied = removed.map { "Emptied the index of \($0.documents) documents from \($0.volumes) volumes" } ?? "Removed the index the server did not serve"
        return "\(emptied), and \(line)"
    }

    // MARK: At a start

    /// At a start, before the index found there is opened (PLAN's S21d, S21e): the log a stop left folded;
    /// then, through the writer, the index brought to this build as the app's launch brings its own: the kit's
    /// schema migrated by its read-write open, full-text tables of an earlier generation, which that open
    /// makes again empty, rebuilt from the documents the index holds (`rebuildSearchIndexFromCache()`), the
    /// emptying of a reset a stop cut short made again, the index part of a removal a stop cut short finished,
    /// and an upgrade begun when the stamps' date-index version is behind the kit's (`needsDateReindex`),
    /// which the start's job then does with the kit's pass over every volume, while search answers and
    /// `/readyz` names the volumes still to go. A stamp of 0, as an index seeded from an export has, reads as
    /// the lowest version its documents were indexed at. Then the files of each removal whose index part is
    /// done, through `removingFiles`, the library's `remove(_:)`.
    public func prepareAtStart(removingFiles: (@Sendable (String) async throws -> Void)? = nil) async {
        guard mode == .standalone else { return }
        var removable: [String] = []
        if FileManager.default.fileExists(atPath: liveIndex.path) {
            await foldLogAtStart()
            removable = await bringUpToDate()
            _ = await foldLog()
        } else {
            removable = stamps.removals()
        }
        for volumeId in stamps.removals() {
            guard removable.contains(volumeId) else {
                stamps.endRemoval(volumeId)
                log("\(volumeId), whose removal a stop of the server cut short, could not be taken out of the index at the start: Remove asks again")
                continue
            }
            do {
                try await removingFiles?(volumeId)
                log("Finished the removal of \(volumeId), which a stop of the server cut short")
            } catch {
                log("The removal of \(volumeId), which a stop of the server cut short, could not remove its files: \(error); Remove asks again")
            }
            stamps.endRemoval(volumeId)
        }
        await publishUpgrade()
    }

    /// The writer's part of `prepareAtStart`, its connections closed when it returns. Gives the removals whose
    /// index part is done.
    private func bringUpToDate() async -> [String] {
        let writer: Writer
        do {
            writer = try await openWriter()
        } catch {
            log("The index \(liveIndex.path) could not be opened to bring it to this build at the start: \(error)")
            return []
        }
        let pipeline = writer.pipeline
        // The app's rule: a schema the open made again, or a rebuild a stop cut short (`needsFTSRebuildReindex`),
        // where a stamp is kept: an index with none, seeded from an export, was opened at this generation.
        let ftsStamp = stamps.integer(forKey: IndexingPipeline.ftsSchemaVersionKey)
        if writer.store.didRebuildSchema || (ftsStamp != 0 && pipeline.needsFTSRebuildReindex) {
            log("The index's full-text tables were of an earlier generation: they are rebuilt from the documents it holds, before it is served")
            do {
                try await pipeline.rebuildSearchIndexFromCache()
                await pipeline.markFTSRebuildReindexComplete()
            } catch {
                log("The index's full-text tables could not be rebuilt from its documents: \(error)")
            }
        }
        if stamps.isResetting() {
            log("A reset a stop of the server cut short is finished: the index is emptied again, and the start's job indexes every volume again")
            do {
                try await pipeline.removeAllVolumesFromIndex()
            } catch {
                log("The index could not be emptied again: \(error)")
            }
            indexWasReplaced(sameFile: true)
            stamps.markResetting()
        }
        var removed: [String] = []
        let removals = stamps.removals()
        for volumeId in removals {
            do {
                try await takeOut(volumeId, writer: writer)
                removed.append(volumeId)
            } catch {
                log("\(volumeId), whose removal a stop of the server cut short, could not be taken out of the index: \(error)")
            }
        }
        if !removals.isEmpty { await pipeline.runPostIndexPasses() }

        guard !stamps.isResetting() else {
            withExtendedLifetime(writer) {}
            return removed
        }
        let current = IndexingPipeline.currentDateIndexVersion
        let indexed = (try? pipeline.allIndexedVolumeIds()) ?? []
        var installed = pipeline.installedDateIndexVersion
        if installed == 0 {
            installed = (try? CorpusIndex.open(liveIndex, live: true))?.summary.indexVersion ?? current
        }
        if installed < current, !indexed.isEmpty {
            // The kit's pass takes every volume the library holds again, as the app's launch runs its pass again.
            stamps.beginUpgrade(from: installed, to: current, volumes: Self.volumeFiles(in: volumesDirectory), at: now())
            log("The index is at index version \(installed), and this build indexes at \(current): the start's job re-indexes every volume from its file, one after another, while search answers")
        } else {
            if stamps.upgrade() != nil { stamps.endUpgrade() }
            if pipeline.installedDateIndexVersion == 0, !indexed.isEmpty {
                // Every document is at the kit's version, as in an index seeded from an export: the stamps say so.
                await pipeline.markDateReindexComplete()
                await pipeline.markFTSRebuildReindexComplete()
            }
        }
        withExtendedLifetime(writer) {}
        return removed
    }
}
