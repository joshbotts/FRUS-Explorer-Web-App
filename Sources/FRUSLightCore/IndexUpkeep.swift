// The upkeep of a Standalone server's index (PLAN's S21e), through its one writer, in jobs of the server's
// queue beside the library's indexing (LibraryIndexing.swift): a volume's removal from the index and then
// its files; a compaction; a check; a reset, which empties the index and indexes the library again; and,
// at a start, the index brought to this build: its schema, its full-text tables rebuilt from the documents
// it holds when they are of an earlier generation, a removal a stop cut short finished, and an upgrade to
// the kit's date-index version begun or resumed, which the library's indexing then does volume by volume
// while search answers. Every rule is the kit's, compiled from the submodule: `removeVolume(_:)`,
// `vacuumIndex()`, `indexPageStatistics()`, `checkIndexIntegrity()`, `removeAllVolumesFromIndex()`,
// `rebuildSearchIndexFromCache()`, `needsDateReindex`, `installedDateIndexVersion`, the stamps and the passes
// after indexing; but whether a compaction is worth offering and the room it needs, the app's
// (`IndexCompaction`, app code), which `IndexCompactionRule` mirrors and `IndexUpkeepParityTests` holds to the
// app's source.

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
}

extension LibraryIndexer {
    /// What `/readyz` and search's 503 say while a compaction holds the index to itself.
    static let compactionHold = "The index is being compacted, which gives the disk back the room removed and re-indexed volumes left in it: search answers again once its job ends, and the reader opens documents meanwhile"
    /// What they say while a reset empties the index.
    static let resetHold = "The index is being emptied, to be indexed again from the library's volumes: search answers again, over what is indexed, once it is empty, and the reader opens documents meanwhile"

    // MARK: The writer, for the upkeep

    /// Runs `body` with the index's writer open, as each job of the upkeep does: once the start has opened
    /// the index found there, and only over the index the server serves; the served index told before the
    /// first write, served meanwhile unless `holding` says why it is held; and, after `body`, the writer let
    /// go, the log folded and the served index told it is whole, opened again over the file as it is now.
    func withWriter<T: Sendable>(holding: String?, _ body: (Writer) async throws -> T) async throws -> T {
        while await state.isOpeningIndexAtStart {
            try await Task.sleep(for: .milliseconds(100))
        }
        if await state.index == nil {
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

    // MARK: Removal

    /// Whether a removal of `volumeId` waits, runs, or was cut short by a stop and is still to be finished.
    public func isRemoving(_ volumeId: String) -> Bool {
        queuedRemovals.contains(volumeId) || stamps.removals().contains(volumeId)
    }

    /// Queues the removal of `volumeId` (PLAN's S21e): a job, the index's one writer, which takes the volume
    /// out of the index with the kit's `removeVolume(_:)`, forgets what the server kept of its passes, runs
    /// the passes after indexing over what remains, folds the log, and then removes its files and its row
    /// through `files`, the library's `remove(_:)`. The removal is kept in the stamps from before its first
    /// write until its files are gone, so that one a stop of the server cut short is finished by the next
    /// start (`prepareAtStart`). Throws `LibraryIndexingRefusal`, or what the queue throws.
    @discardableResult
    public func remove(_ volumeId: String, requestedBy: String?,
                       files: @escaping @Sendable (String) async throws -> Void) async throws -> Job {
        guard mode == .standalone else { throw LibraryIndexingRefusal.importMode }
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
        stamps.beginRemoval(volumeId)
        if FileManager.default.fileExists(atPath: liveIndex.path) {
            try await withWriter(holding: nil) { writer in
                try await takeOut(volumeId, writer: writer)
                await job.progress("Rebuilding the person rollup, the broken references' flags and the subjects", fraction: 0.5)
                await writer.pipeline.runPostIndexPasses()
            }
        }
        await job.progress("Removing \(volumeId)'s file and figure images", fraction: 0.9)
        try await files(volumeId)
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
    /// room the app's rule asks (`IndexCompactionRule`), the job holding the index to itself, since `VACUUM`
    /// replaces the file under every read-only connection, which the kit asks its host to open again
    /// afterwards; the log then folded, so that the file shrinks, and the index opened again and served.
    @discardableResult
    public func compact(requestedBy: String?) async throws -> Job {
        guard mode == .standalone else { throw LibraryIndexingRefusal.importMode }
        return try await jobs.submit(.indexCompact, subject: nil, requestedBy: requestedBy, id: nil) { job in
            try await self.runCompaction(job: job)
        }
    }

    private func runCompaction(job: JobContext) async throws -> String? {
        try await job.step("Compacting the index", fraction: 0)
        let before = try await withWriter(holding: Self.compactionHold) { writer -> Int in
            guard let statistics = try await writer.pipeline.indexPageStatistics() else {
                throw JobFailed("The index's size could not be read, so it was not compacted.")
            }
            let required = Int64(IndexCompactionRule.required(statistics))
            if let free = try? capacity(), free < required {
                throw JobFailed("Compacting the index needs about \(Self.megabytes(required)) free on the data volume, which has \(Self.megabytes(free)), so nothing was changed.")
            }
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
            try await job.step("Checking the index: SQLite's quick check, and both full-text indexes' own", fraction: 0)
            let problems = try await self.withWriter(holding: nil) { writer in try await writer.pipeline.checkIndexIntegrity() }
            guard problems.isEmpty else {
                let shown = problems.prefix(3).joined(separator: "; ")
                throw JobFailed("The index's check found \(problems.count) \(problems.count == 1 ? "problem" : "problems"): \(shown)\(problems.count > 3 ? "; and more" : ""). Resetting the index indexes the library's volumes into it again.")
            }
            return "The index's check found no problems: SQLite's quick check and both full-text indexes' checks passed."
        }
    }

    // MARK: Reset

    /// Queues Standalone's reset of the index (PLAN's S21e): a job that empties the index it serves with the
    /// kit's `removeAllVolumesFromIndex()`, holding it to itself meanwhile, or removes an index it does not
    /// serve, as one the start refused; forgets every stamp and record of it (`indexWasReplaced`), and
    /// queues the indexing of every volume the library holds, which search follows volume by volume. The
    /// index's record of each document's revisions stays, as the kit keeps it through its own rebuild, so
    /// that the reviews of what an update changed survive. Refused when an index import finished after it
    /// was asked for, whose index it would empty.
    @discardableResult
    public func reset(requestedBy: String?) async throws -> Job {
        guard mode == .standalone else { throw LibraryIndexingRefusal.importMode }
        let asked = now()
        return try await jobs.submit(.indexReset, subject: nil, requestedBy: requestedBy, id: nil) { job in
            try await self.runReset(job: job, askedAt: asked, requestedBy: requestedBy)
        }
    }

    private func runReset(job: JobContext, askedAt: Date, requestedBy: String?) async throws -> String? {
        try await job.step("Emptying the index", fraction: 0)
        if await jobs.jobs().contains(where: { $0.kind == .indexImport && $0.state == .succeeded && ($0.finishedAt ?? .distantPast) >= UserStoreDate.rounded(askedAt) }) {
            throw IndexResetRefusal()
        }
        try await job.commit()
        while await state.isOpeningIndexAtStart {
            try await Task.sleep(for: .milliseconds(100))
        }
        let removed = await state.index?.summary
        if FileManager.default.fileExists(atPath: liveIndex.path) {
            if removed != nil {
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
        } else {
            indexWasReplaced()
        }
        await publishUpgrade()
        let emptied = removed.map { "Emptied the index of \($0.documents) documents from \($0.volumes) volumes" } ?? "Removed the index the server did not serve"
        do {
            let next = try await index(.asked(nil), requestedBy: requestedBy)
            return "\(emptied): job \(next.id) indexes the library's volumes again."
        } catch {
            log("The indexing after the index's reset could not be queued: \(error)")
            return "\(emptied). The library's volumes are indexed again by Index All Waiting, or at the next start."
        }
    }

    // MARK: At a start

    /// At a start, before the index found there is opened (PLAN's S21d, S21e): the log a stop left folded;
    /// then, through the writer, the index brought to this build as the app's launch brings its own: the kit's
    /// schema migrated by its read-write open, full-text tables of an earlier generation, which that open
    /// makes again empty, rebuilt from the documents the index holds (`rebuildSearchIndexFromCache()`), the
    /// index part of a removal a stop cut short finished, and an upgrade begun when the stamps' date-index
    /// version is behind the kit's (`needsDateReindex`), or resumed where a stop left one, which the start's
    /// indexing job then does, volume by volume, from the cached XML, while search answers and `/readyz`
    /// names the volumes still to go. A stamp of 0, as an index seeded from an export has, reads as the lowest
    /// version its documents were indexed at. Then the files of a removal a stop cut short, through
    /// `removingFiles`, the library's `remove(_:)`.
    public func prepareAtStart(removingFiles: (@Sendable (String) async throws -> Void)? = nil) async {
        guard mode == .standalone else { return }
        if FileManager.default.fileExists(atPath: liveIndex.path) {
            await foldLogAtStart()
            await bringUpToDate()
            _ = await foldLog()
        }
        for volumeId in stamps.removals() {
            do {
                try await removingFiles?(volumeId)
                stamps.endRemoval(volumeId)
                log("Finished the removal of \(volumeId), which a stop of the server cut short")
            } catch {
                log("The removal of \(volumeId), which a stop of the server cut short, could not remove its files: \(error)")
            }
        }
        await publishUpgrade()
    }

    /// The writer's part of `prepareAtStart`, its connections closed when it returns.
    private func bringUpToDate() async {
        let writer: Writer
        do {
            writer = try await openWriter()
        } catch {
            log("The index \(liveIndex.path) could not be opened to bring it to this build at the start: \(error)")
            return
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
        let removals = stamps.removals()
        for volumeId in removals {
            do {
                try await takeOut(volumeId, writer: writer)
            } catch {
                log("\(volumeId), whose removal a stop of the server cut short, could not be taken out of the index: \(error)")
            }
        }
        if !removals.isEmpty { await pipeline.runPostIndexPasses() }

        let current = IndexingPipeline.currentDateIndexVersion
        let indexed = (try? pipeline.allIndexedVolumeIds()) ?? []
        var installed = pipeline.installedDateIndexVersion
        if installed == 0 {
            installed = (try? CorpusIndex.open(liveIndex, live: true))?.summary.indexVersion ?? current
        }
        if let upgrade = stamps.upgrade(), upgrade.to == current, installed < current {
            stamps.keepUpgrading(indexed)
            log("The index's upgrade to index version \(current), which a stop of the server cut short, goes on: \(stamps.upgrade()?.remaining.count ?? 0) volumes are still to be re-indexed")
        } else if installed < current, !indexed.isEmpty {
            stamps.beginUpgrade(from: installed, to: current, volumes: indexed.sorted(), at: now())
            log("The index is at index version \(installed), and this build indexes at \(current): its \(indexed.count) volumes are re-indexed from their files, one after another, while search answers")
        } else if stamps.upgrade() != nil {
            stamps.endUpgrade()
        }
        if let upgrade = stamps.upgrade(), upgrade.remaining.isEmpty {
            await pipeline.markDateReindexComplete()
            await pipeline.markFTSRebuildReindexComplete()
            stamps.endUpgrade()
        } else if stamps.upgrade() == nil, pipeline.installedDateIndexVersion == 0, !indexed.isEmpty {
            // Every document is at the kit's version, as in an index seeded from an export: the stamps say so.
            await pipeline.markDateReindexComplete()
            await pipeline.markFTSRebuildReindexComplete()
        }
        withExtendedLifetime(writer) {}
    }
}
