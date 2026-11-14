// The corrections a curator makes on this server, as the index takes them (PLAN's S21g): the store keeps them first,
// as override rows (UserCorrections.swift), and the index is given them second, through the kit's two calls, as the
// app replays its overrides: `applyClassificationOverrides`, which writes a document's classification into
// `document_cache.is_editorial_note`, the one place search, its facet and the reader read it; and
// `consolidatePersonRollup(overrides:forceReload:)`, which builds the person rollup again with the merges and
// separations as the clusterer's constraints.
//
// - A Standalone server's index has one writer, the library's jobs. Each opening of it re-asserts every
//   classification correction, which the kit keeps for `indexVolume`'s replay after each volume it indexes, and
//   the passes after indexing rebuild the rollup with every person correction, where S21d's passed none; the kit's
//   pass over every volume, which replays nothing, is followed by the set again. A correction made is applied by a
//   job of its own, `indexCorrections`, at once, as the app's live corrections apply theirs.
// - An Import server serves the Mac's export immutable (Compatibility contract, rule 7), so a correction is kept
//   and given to the next export it installs, before it is served, as the app replays its overrides at launch: every
//   classification correction, FRUS's own classification for each document whose correction was undone here, read
//   from its TEI again, and the rollup built again with every person correction, when there is one.

import FRUSCoreKit
import FTS5Store
import Foundation

/// The corrections the store keeps, as the index takes them.
public struct IndexCorrections: Sendable {
    public let store: any CorrectionStore & CorrectionLogStore
    /// The TEI the reader renders, which a restored document's classification is read from again.
    let volumesDirectory: URL
    let log: @Sendable (String) -> Void

    public init(store: any CorrectionStore & CorrectionLogStore, volumesDirectory: URL,
                log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.store = store
        self.volumesDirectory = volumesDirectory.standardizedFileURL
        self.log = log
    }

    /// Whether an application builds the rollup again.
    public enum RollupRebuild: Sendable, Equatable {
        /// Left as it is.
        case no
        /// Built again with every person correction, none included: an undone correction is dropped so.
        case yes
        /// Built again only when the store keeps a person correction when it is read, as an Import server's export
        /// is given them: the rollup the Mac built with its own corrections stands otherwise.
        case whenAnyKept
    }

    /// What one application gave the index.
    public struct Applied: Sendable, Equatable {
        public var classifications = 0
        public var restored = 0
        public var personCorrections = 0
        public var rollupRebuilt = false
    }

    /// Every classification correction, as the kit's values, in the order the app's snapshot gives them, oldest
    /// first, so that the newest for a document holds.
    public func classification() throws -> [DocumentClassificationOverrideData] {
        try store.classificationOverrides().map {
            DocumentClassificationOverrideData(volumeId: $0.volumeId, documentId: $0.documentId,
                                               isEditorialNote: $0.isEditorialNote, parsedIsEditorialNote: $0.parsedIsEditorialNote)
        }
    }

    /// Every person correction, as the kit's values, newest first, as the app's snapshot gives them.
    public func person() throws -> [PersonClusterOverrideData] {
        try store.personOverrides().map(\.data)
    }

    /// FRUS's own classification of a document whose correction was undone, as the rail's Restore takes it: its
    /// TEI's parse, read again (`isShapedAsEditorialNote`, the rule the indexer applies), since the Office of the
    /// Historian may have fixed the very mistag since; the value logged when it was undone where its TEI is not
    /// here or does not parse.
    public static func restoredValue(_ entry: CorrectionLogEntry, volumesDirectory: URL) async -> Bool? {
        guard let document = entry.document else { return nil }
        let url = volumesDirectory.appendingPathComponent("\(document.volumeId).xml")
        if FileManager.default.fileExists(atPath: url.path),
           let ast = try? await FRUSDocumentParser().parseDocument(documentId: document.documentId, volumeURL: url) {
            return ast.isShapedAsEditorialNote
        }
        return entry.isEditorialNote
    }

    /// Gives `pipeline`, a writer's, the corrections: first each of `restores`, FRUS's own classification put back
    /// through the kit's volume-scoped entry point, which keeps nothing for the replay, as the app's `saveAndApply`
    /// restores one; then every classification correction, which the pipeline keeps for `indexVolume`'s replay;
    /// and, as `rebuildingRollup` says, the rollup built again with every person correction, as the app's live
    /// merge and separation build it (`PersonClusterOverrideStore.saveAndReconsolidate`).
    public func apply(to pipeline: IndexingPipeline, restoring restores: [CorrectionLogEntry],
                      rebuildingRollup: RollupRebuild) async throws -> Applied {
        var applied = Applied()
        for entry in restores {
            guard let document = entry.document,
                  let value = await Self.restoredValue(entry, volumesDirectory: volumesDirectory) else { continue }
            try await pipeline.applyClassificationOverrides(
                [DocumentClassificationOverrideData(volumeId: document.volumeId, documentId: document.documentId,
                                                    isEditorialNote: value, parsedIsEditorialNote: value)],
                volumeId: document.volumeId)
            applied.restored += 1
        }
        let classification = try await Blocking.run { [self] in try self.classification() }
        try await pipeline.applyClassificationOverrides(classification)
        applied.classifications = classification.count
        if rebuildingRollup != .no {
            let person = try await Blocking.run { [self] in try self.person() }
            guard rebuildingRollup == .yes || !person.isEmpty else { return applied }
            // `forceReload: false`, as the app's live correction calls it: a writer opened for this job holds no
            // cluster inputs, so the kit loads them.
            try await pipeline.consolidatePersonRollup(overrides: person, forceReload: false)
            applied.personCorrections = person.count
            applied.rollupRebuilt = true
        }
        return applied
    }
}

extension LibraryIndexer {
    // MARK: The corrections, in every writer

    /// Gives a writer just opened every classification correction, which the kit keeps for `indexVolume`'s replay
    /// after each volume it indexes and which an index's own values may have lost to a pass that replays nothing.
    /// Throws when the store cannot say what they are, so that no job writes the index without them.
    func reassertCorrections(_ pipeline: IndexingPipeline) async throws {
        guard let corrections else { return }
        let classification = try await Blocking.run { try corrections.classification() }
        try await pipeline.applyClassificationOverrides(classification)
    }

    /// The kit's passes after indexing, `runPostIndexPasses`, with every person correction, as the app's launch
    /// passes its overrides, so that a rollup the gate rebuilds keeps the merges and separations made here, and an
    /// import's (S21d's passed none). With no corrections the passes run as before; with a store that cannot say
    /// what they are, the rollup's waits for the next job, since a rollup rebuilt without them would drop them, and
    /// the broken references' and the subjects' run, as `runPostIndexPasses` runs them.
    func postIndexPasses(_ pipeline: IndexingPipeline) async {
        guard let corrections else {
            await pipeline.runPostIndexPasses()
            return
        }
        do {
            let person = try await Blocking.run { try corrections.person() }
            await pipeline.runPostIndexPasses(overrides: person)
        } catch {
            log("The person rollup waits for the next job, since the person corrections could not be read: \(error)")
            try? await pipeline.applyBrokenRefsIndexIfNeeded()
            try? await pipeline.applyDocumentSubjectsIfNeeded()
        }
    }

    /// At a start's opening of the writer: the rollup built again with every person correction when it was built
    /// with others (the kit's gate, cheap when it was not), as when a stop kept an import's job from giving it the
    /// ones the Mac's research brought. A server that keeps none is left as before.
    func reassertPersonCorrections(_ pipeline: IndexingPipeline) async {
        guard let corrections else { return }
        do {
            let person = try await Blocking.run { try corrections.person() }
            guard !person.isEmpty else { return }
            if try await pipeline.consolidatePersonRollupIfNeeded(overrides: person) {
                log("The person rollup was built again at the start with the \(person.count) person corrections this server keeps")
            }
        } catch {
            log("The person corrections could not be given to the rollup at the start, which the next job gives them: \(error)")
        }
    }

    // MARK: The job

    /// Queues the job that gives the index the corrections waiting in the store, or gives the one that waits
    /// already, which reads them when it runs (PLAN's S21g); `all` gives it every correction again, the rollup
    /// built with them, as after an import of the Mac's research brought some, which the log does not hold. Throws
    /// `LibraryIndexingRefusal.importMode` on an Import server, whose next export takes them, or what the queue throws.
    @discardableResult
    public func applyCorrections(requestedBy: String?, all: Bool = false) async throws -> Job {
        guard mode == .standalone else { throw LibraryIndexingRefusal.importMode }
        if let waiting = waitingCorrectionJob, let job = await jobs.job(waiting.id), job.state == .queued,
           waitingCorrectionJob?.id == waiting.id {
            // Checked again past the suspension: the job has not begun, and reads this when it does.
            if all { waitingCorrectionJob?.all = true }
            return job
        }
        let id = UUID().uuidString
        // One the queue was still saving, not yet seen above, gives its slot to this one: what it asked for is kept.
        waitingCorrectionJob = (id, all || (waitingCorrectionJob?.all ?? false))
        do {
            return try await jobs.submit(.indexCorrections, subject: nil, requestedBy: requestedBy, id: id, onCancel: {
                await self.forgetCorrectionJob(id)
            }) { job in
                try await self.runCorrections(id, job: job)
            }
        } catch {
            forgetCorrectionJob(id)
            throw error
        }
    }

    /// At a start, once the index found there is open: a job for the corrections a stop left waiting, if any.
    @discardableResult
    public func resumeCorrectionsAtStart() async -> Job? {
        guard mode == .standalone, let corrections else { return nil }
        do {
            guard try await !Blocking.run({ try corrections.store.waitingCorrections() }).isEmpty else { return nil }
            let job = try await applyCorrections(requestedBy: nil)
            log("Applying the corrections a stop of the server left waiting, as job \(job.id)")
            return job
        } catch {
            log("The corrections waiting at the start could not be queued: \(error)")
            return nil
        }
    }

    func forgetCorrectionJob(_ id: String) {
        if waitingCorrectionJob?.id == id { waitingCorrectionJob = nil }
    }

    private func runCorrections(_ id: String, job: JobContext) async throws -> String? {
        let all = waitingCorrectionJob?.id == id ? waitingCorrectionJob?.all ?? false : false
        forgetCorrectionJob(id)
        try await job.step("Applying the corrections curators made to the index", fraction: 0)
        guard let corrections else { return "This server keeps no corrections." }
        let waiting = try await Blocking.run { try corrections.store.waitingCorrections() }
        guard !waiting.isEmpty || all else { return "No correction was waiting to be applied." }
        guard FileManager.default.fileExists(atPath: liveIndex.path) else {
            throw JobFailed("No index is served, so no correction was applied to it: the first indexing applies them.")
        }
        // From its first write it runs to its end.
        try await job.commit()
        let restores = waiting.filter { $0.correction == .classification && $0.action == .undone }
        let rollup = all || waiting.contains { $0.correction == .person }
        let applied = try await withWriter(holding: nil) { writer in
            try await corrections.apply(to: writer.pipeline, restoring: restores, rebuildingRollup: rollup ? .yes : .no)
        }
        if let problem = stamps.writeProblem {
            log("The index's stamps could not be written after the corrections: \(problem)")
        }
        let time = now()
        try await Blocking.run { try corrections.store.markCorrectionsApplied(waiting.map(\.id), at: time) }
        log("Applied \(waiting.count) waiting corrections to the index: \(applied.classifications) classifications given again, \(applied.restored) restored, the rollup \(applied.rollupRebuilt ? "rebuilt with \(applied.personCorrections) person corrections" : "left as it was")")
        if all && waiting.isEmpty { return "Gave the index every correction kept, after an import brought some." }
        return waiting.count == 1 ? "Applied 1 correction to the index." : "Applied \(waiting.count) corrections to the index."
    }
}

/// An import's step (PLAN's S21g): the server's corrections given to the export it installs, before it is served.
public struct IndexCorrectionReplay: Sendable {
    let corrections: IndexCorrections
    let resources: IndexingResources

    public init(corrections: IndexCorrections, resources: IndexingResources) {
        self.corrections = corrections
        self.resources = resources
    }

    /// What the store asks of an export: every classification correction, every standing restore and every person
    /// correction, and the waiting entries an install takes with them.
    public struct Plan: Sendable {
        let classification: Int
        let restores: [CorrectionLogEntry]
        let person: Int
        /// The entries waiting when the plan was read, which the install takes.
        public let waiting: [String]

        /// Whether it gives the export anything: an export is installed as the Mac made it otherwise.
        public var givesAnything: Bool { classification > 0 || person > 0 || !restores.isEmpty }
    }

    public func plan() throws -> Plan {
        let store = corrections.store
        // The entries waiting first: one made after them waits for the next install, since the sets read after may
        // or may not hold it, and the copy is given whatever the sets hold.
        let waiting = try store.waitingCorrections().map(\.id)
        return Plan(classification: try store.classificationOverrides().count, restores: try store.standingRestores(),
                    person: try store.personOverrides().count, waiting: waiting)
    }

    /// Records that the export installed took the entries `plan` read waiting; a failure is said in the log alone,
    /// since the next install gives them again.
    func installed(_ plan: Plan, at time: Date) async {
        guard !plan.waiting.isEmpty else { return }
        let store = corrections.store
        do {
            try await Blocking.run { try store.markCorrectionsApplied(plan.waiting, at: time) }
        } catch {
            corrections.log("The corrections the installed index took could not be marked applied: \(error)")
        }
    }

    /// Gives the copy at `candidate` the corrections, through the kit's read-write pipeline, as the app replays its
    /// overrides at launch, and leaves it whole: the kit's connections closed, the log folded into the file through
    /// `copy`, the import's own connection, and its journal a rollback journal's again, as the immutable open an
    /// Import server serves needs. The rollup is built again only when the store keeps a person correction when the
    /// kit is given them: an export's own, which the Mac built with its corrections, stands otherwise.
    func apply(_ plan: Plan, to candidate: URL, through copy: SQLiteConnection) async throws -> IndexCorrections.Applied {
        let volumes = corrections.volumesDirectory
        var applied = IndexCorrections.Applied()
        do {
            let pipeline = try await Blocking.run { [resources] in
                try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: candidate), databaseURL: candidate,
                                     volumesDirectory: volumes, resources: resources, defaults: InMemoryIndexingStampStore())
            }
            applied = try await corrections.apply(to: pipeline, restoring: plan.restores, rebuildingRollup: .whenAnyKept)
        }
        let (folded, journal) = try await Blocking.run { () -> (Int64, String) in
            // A statement first, so that `copy`, idle since the kit switched the file to a write-ahead log, reads its
            // header again and takes the log mode: the checkpoint and the switch back are then its own, and the
            // switch fails while any other connection still holds the file.
            _ = try copy.query("SELECT count(*) FROM sqlite_master")
            let folded = try copy.query("PRAGMA wal_checkpoint(TRUNCATE)").first?.first?.integer ?? 1
            let journal = try copy.query("PRAGMA journal_mode=DELETE").first?.first?.text ?? ""
            return (folded, journal)
        }
        guard folded == 0, journal.lowercased() == "delete" else {
            throw CorrectionReplayError(detail: "the copy's write-ahead log could not be folded into it after its corrections (busy \(folded), journal \(journal))")
        }
        return applied
    }
}

/// The replay's own failure, which says nothing of the export: the copy was given its corrections and could not be
/// left whole.
struct CorrectionReplayError: Error, CustomStringConvertible {
    let detail: String
    var description: String { detail }
}
