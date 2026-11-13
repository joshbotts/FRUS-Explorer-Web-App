// Import mode's step 5 (SPEC's Import procedure; PLAN's S21f, the hash comparison S2 deferred): each document of
// the served export recomputed from the mounted TEI as the kit's indexer computes it, and compared with the
// export's `document_revisions`, so that a document whose TEI changed after the Mac indexed it is listed for the
// review of what changed, as the Mac's After an Update lists one a volume update changed. The two hashes are the
// kit's indexer's own and not public, so the comparison runs the indexer itself: each volume is indexed with
// `indexVolume`, the volume-update path, into a comparison index of the server's own, whose revision rows are
// first the export's, so that the kit stamps what moved, `body`, `apparatus` or `vanished`, by its own rules, as
// it stamps an update. A volume nothing moved in is deleted from the comparison index as soon as it is compared,
// its revision rows with it; one something moved in is kept, so that the review reads its text as it reads now.
// The comparison index is the server's own file, in a folder of its own, `/data/tei-check`, apart from the served
// index's, which the server never writes in Import mode (Compatibility contract, rule 7), and it is read through
// the kit's immutable read-only open, once it is whole.
//
// It is a job of the queue (`teiComparison`), by the owner's choice of 13 November: after each import it compares
// every volume of the export, and later each volume whose file in the TEI folder has changed since it was compared,
// by the file's device, inode, length and modification time, which the record keeps. Over the full corpus the
// first comparison takes about as long as indexing it, 8 to 10 minutes on the owner's Mac, so the job gives way
// after each volume to any job queued behind it and goes on after them from where it stopped, its progress kept in
// its work folder, where a start after a stop finds it too.

import FRUSCoreKit
import FTS5Store
import Foundation

/// A file of the TEI folder as the check compared it: a later file in its place has another identity, length or
/// modification time, and is compared again.
public struct TEIFileStamp: Codable, Sendable, Equatable {
    public var device: UInt64
    public var inode: UInt64
    public var bytes: Int64
    /// Its modification time, in nanoseconds since 1970: a whole number, which the record keeps exactly.
    public var modified: Int64

    /// The regular file at `url` now, a link followed, as the reader follows one; nil when none is there.
    public static func of(_ url: URL) -> TEIFileStamp? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let device = (attributes[.systemNumber] as? NSNumber)?.uint64Value,
              let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
              let bytes = (attributes[.size] as? NSNumber)?.int64Value,
              let modified = attributes[.modificationDate] as? Date else { return nil }
        return TEIFileStamp(device: device, inode: inode, bytes: bytes,
                            modified: Int64((modified.timeIntervalSince1970 * 1_000_000_000).rounded()))
    }
}

/// The served index's file, as a record or a comparison under way names the one it compared: by device and inode,
/// which an import's rename makes another, and by its length and the export's stamp, since a file made later can
/// take an inode a removed one freed.
public struct TEIServedFile: Codable, Sendable, Equatable {
    public var device: UInt64
    public var inode: UInt64
    public var bytes: Int64
    public var exportedAt: String?

    init?(_ index: CorpusIndex?) {
        guard let index, let file = index.file else { return nil }
        device = file.device
        inode = file.inode
        bytes = ((try? FileManager.default.attributesOfItem(atPath: index.url.path))?[.size] as? NSNumber)?.int64Value ?? -1
        exportedAt = index.summary.exportedAt
    }
}

/// What the check found of the served index, kept beside it in `tei-changes.json`, written whole and renamed into
/// place once the comparison index it describes is whole.
public struct TEIChangeRecord: Codable, Sendable, Equatable {
    public var format = 1
    /// The served index's file the check compared.
    public var served: TEIServedFile
    public var checkedAt: Date
    /// The volumes compared, and those with a document whose TEI changed, by id.
    public var checked: [String]
    public var changed: [String]
    /// The volumes the check could not compare, with why, in the server's words.
    public var unchecked: [String: String]
    /// The file each volume was compared from, by id: a volume whose file has another stamp now is compared again,
    /// and one whose file was not there is compared once one is.
    public var files: [String: TEIFileStamp]

    public static let fileName = "tei-changes.json"
    /// The comparison index the record describes.
    public static let indexName = "tei-changes.db"

    /// Whether it describes the served index `index`.
    func describes(_ index: CorpusIndex?) -> Bool { TEIServedFile(index).map { $0 == served } ?? false }
}

/// A comparison under way, kept in its work folder as each volume is compared, so that a job that gave way to
/// another, or a start after a stop, goes on from where it stopped.
struct TEIComparisonWork: Codable, Sendable, Equatable {
    var format = 1
    var served: TEIServedFile
    /// Whether it compares only the volumes whose file changed since the last whole comparison, over a copy of it.
    var recheck: Bool
    /// The volumes to compare, in order, and how many of them are compared.
    var plan: [String]
    var done: Int
    /// What it has found, beginning from the last comparison's for a re-check.
    var checked: [String]
    var changed: [String]
    var unchecked: [String: String]
    var files: [String: TEIFileStamp]

    static let fileName = "work.json"
}

/// Why a check stopped, in the server's words.
struct TEICheckProblem: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Where the check stands, for Administration.
public struct TEICheckStatus: Sendable, Equatable {
    /// The volume being compared, and how far through the volumes to compare the check is.
    public var volume: String?
    public var done: Int
    public var total: Int
    /// Whether a comparison is under way: its job queued or running, or waiting behind jobs it gave way to.
    public var running: Bool
    /// Whether it waits behind jobs it gave way to.
    public var waiting: Bool
    /// Whether it compares only the volumes whose file changed since the last whole comparison.
    public var recheck: Bool
    /// The record of the last whole comparison of the served index.
    public var record: TEIChangeRecord?
    /// Why the last comparison stopped, in the server's words.
    public var problem: String?

    static let idle = TEICheckStatus(volume: nil, done: 0, total: 0, running: false, waiting: false, recheck: false,
                                     record: nil, problem: nil)
}

/// The comparison index, read through the kit: the documents whose TEI changed, their hashes as the TEI gives
/// them now, and their text, which the review's quotation check reads.
public struct TEIComparison: Sendable {
    public let record: TEIChangeRecord
    public let pipeline: IndexingPipeline
}

/// Import mode's check of the served index against the mounted TEI (PLAN's S21f).
public actor TEIChangeCheck {
    public let liveIndex: URL
    public let volumesDirectory: URL
    /// The check's own folder, `/data/tei-check`: the comparison index, its record, and the work folder of the
    /// comparison under way.
    public let folder: URL
    let resources: IndexingResources
    let state: ServerState
    let jobs: any JobQueue
    let now: @Sendable () -> Date
    let log: @Sendable (String) -> Void
    /// Whether a job of the comparison is queued or running: one at a time.
    private var underWay = false
    /// The served index a comparison stopped for, at an error or an admin's cancel: it goes on at the next start,
    /// and one begins for the next index served.
    private var stoppedFor: TEIServedFile?
    private var phase = TEICheckStatus.idle
    private var opened: TEIComparison?
    /// Test hook: told each volume once it has been compared.
    var volumeComparedTestHook: (@Sendable (String) async -> Void)?

    public init(liveIndex: URL, volumesDirectory: URL, folder: URL, resources: IndexingResources, state: ServerState,
                jobs: any JobQueue, now: @escaping @Sendable () -> Date = Date.init,
                log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.liveIndex = liveIndex.standardizedFileURL
        self.volumesDirectory = volumesDirectory.standardizedFileURL
        self.folder = folder.standardizedFileURL
        self.resources = resources
        self.state = state
        self.jobs = jobs
        self.now = now
        self.log = log
    }

    var recordURL: URL { folder.appendingPathComponent(TEIChangeRecord.fileName) }
    var comparisonURL: URL { folder.appendingPathComponent(TEIChangeRecord.indexName) }
    /// Where the comparison under way is built, with its progress, removed once it is whole.
    var workFolder: URL { folder.appendingPathComponent(".work", isDirectory: true) }
    var workURL: URL { workFolder.appendingPathComponent(TEIComparisonWork.fileName) }
    var buildingURL: URL { workFolder.appendingPathComponent(TEIChangeRecord.indexName) }

    func setVolumeComparedTestHook(_ hook: (@Sendable (String) async -> Void)?) { volumeComparedTestHook = hook }

    /// Where the check stands.
    public func status() -> TEICheckStatus { phase }

    /// Queues the comparison the served index needs, unless one is under way: at a start, once the index found
    /// there is open, and after each look in /data/import. The comparison under way for it goes on; else, with a
    /// record of a whole comparison of it, the volumes whose file changed since are compared again; else every
    /// volume is. One stopped at an error or by an admin waits for the next start, or for another index.
    public func ensureCurrent() async {
        guard state.configuration.mode == .import else { return }
        let index = await state.index
        guard let index, let served = TEIServedFile(index) else {
            // No index served, as after a reset: nothing to compare. A job under way ends when it begins.
            if !underWay { phase = .idle }
            opened = nil
            return
        }
        let record = currentRecord(for: served)
        if phase.record != record {
            phase.record = record
            opened = nil
        }
        guard !underWay, stoppedFor != served else { return }
        if let work = Self.readWork(workURL), work.served == served {
            await queue(served, recheck: work.recheck, done: work.done, total: work.plan.count)
        } else if let record {
            let stale = staleVolumes(of: index, against: record)
            guard !stale.isEmpty else {
                if !phase.running { phase = Self.finished(record, problem: phase.problem) }
                return
            }
            await queue(served, recheck: true, done: 0, total: stale.count)
        } else {
            await queue(served, recheck: false, done: 0, total: Self.volumes(of: index).count)
        }
    }

    /// The comparison index of the served index's last whole comparison, opened through the kit's immutable
    /// read-only open, or nil while none describes it.
    public func comparison() async -> TEIComparison? {
        guard let record = phase.record, let index = await state.index, record.describes(index) else { return nil }
        if let opened, opened.record == record { return opened }
        do {
            let url = comparisonURL
            let store = try FTS5Store(readingDatabaseAt: url)
            let pipeline = try IndexingPipeline(readingIndexAt: url, fts5Store: store, resources: resources, volumesDirectory: volumesDirectory)
            let comparison = TEIComparison(record: record, pipeline: pipeline)
            opened = comparison
            return comparison
        } catch {
            log("The comparison of the index with the TEI folder could not be opened: \(error)")
            return nil
        }
    }

    // MARK: The job

    /// The record of a whole comparison of `served`, with its comparison index in place.
    private func currentRecord(for served: TEIServedFile) -> TEIChangeRecord? {
        guard let record = Self.read(recordURL), record.served == served,
              FileManager.default.fileExists(atPath: comparisonURL.path) else { return nil }
        return record
    }

    /// The volumes of the served index, each holding a document.
    static func volumes(of index: CorpusIndex) -> [String] {
        index.documentsByVolume.filter { $0.value > 0 }.keys.sorted()
    }

    func teiFile(_ volumeId: String) -> URL { volumesDirectory.appendingPathComponent("\(volumeId).xml") }

    /// The volumes whose file in the TEI folder is not the one the record compared, or is there now where none
    /// was, or has gone.
    private func staleVolumes(of index: CorpusIndex, against record: TEIChangeRecord) -> [String] {
        Self.volumes(of: index).filter { TEIFileStamp.of(teiFile($0)) != record.files[$0] }
    }

    /// Queues a job of the comparison, which plans it when it begins; the status says what it will compare.
    private func queue(_ served: TEIServedFile, recheck: Bool, done: Int, total: Int) async {
        underWay = true
        phase.running = true
        phase.waiting = false
        phase.problem = nil
        phase.recheck = recheck
        phase.done = done
        phase.total = total
        phase.volume = nil
        do {
            try await submit(served)
        } catch {
            underWay = false
            stoppedFor = served
            phase.running = false
            phase.problem = "The comparison of the index with the TEI folder could not be queued, which the server's log says why."
            log("The comparison of the index with the TEI folder could not be queued: \(error)")
        }
    }

    private func submit(_ served: TEIServedFile) async throws {
        _ = try await jobs.submit(.teiComparison, subject: nil, requestedBy: nil, id: nil,
                                  onCancel: { [weak self] in await self?.cancelledBeforeItBegan(served) }) { [weak self] context in
            guard let self else { return nil }
            return try await self.run(context)
        }
    }

    /// An admin cancelled the job before it began.
    private func cancelledBeforeItBegan(_ served: TEIServedFile) {
        underWay = false
        stopped(served, problem: Self.cancelled)
    }

    private func stopped(_ served: TEIServedFile, problem: String) {
        stoppedFor = served
        phase.running = false
        phase.waiting = false
        phase.volume = nil
        phase.problem = problem
    }

    static let cancelled = "An admin stopped the comparison. It goes on at the server's next start, or begins again after the next import."

    private func show(_ work: TEIComparisonWork, volume: String?) {
        phase.running = true
        phase.recheck = work.recheck
        phase.done = work.done
        phase.total = work.plan.count
        phase.volume = volume
    }

    static func finished(_ record: TEIChangeRecord, problem: String?) -> TEICheckStatus {
        TEICheckStatus(volume: nil, done: record.checked.count, total: record.checked.count, running: false, waiting: false,
                       recheck: false, record: record, problem: problem)
    }

    /// The job: the served index's comparison taken up where it stands, a volume at a time.
    private func run(_ context: JobContext) async throws -> String? {
        var handedOver = false
        defer { if !handedOver { underWay = false } }
        let index = await state.index
        guard let index, let served = TEIServedFile(index) else {
            try? FileManager.default.removeItem(at: workFolder)
            phase = .idle
            return "No index is served, so there was nothing to compare."
        }
        phase.record = currentRecord(for: served)
        do {
            guard var work = try plan(index, served) else {
                if let record = phase.record { phase = Self.finished(record, problem: nil) }
                return "No file of the TEI folder has changed since the last comparison."
            }
            show(work, volume: nil)
            phase.waiting = false
            let export = try SQLiteConnection.immutable(index.url)
            defer { export.close() }
            let (finished, seeder) = try await compare(&work, from: export, context: context)
            defer { seeder.close() }
            guard finished else {
                // It gives way to the jobs queued behind it, and goes on after them.
                try await submit(work.served)
                handedOver = true
                phase.waiting = true
                phase.volume = nil
                return "Compared \(work.done) of \(work.plan.count) volumes with the TEI folder; goes on once the jobs waiting have run."
            }
            let record = try place(work, seeder: seeder)
            opened = nil
            phase = Self.finished(record, problem: nil)
            let line = Self.line(record, recheck: work.recheck, compared: work.plan.count)
            log(line)
            return line
        } catch is JobCancelled {
            stopped(served, problem: Self.cancelled)
            log("An admin stopped the comparison of the index with the TEI folder")
            throw JobCancelled()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            stopped(served, problem: "The index could not be compared with the TEI folder, which the server's log says why. It goes on at the server's next start, or begins again after the next import.")
            log("The index could not be compared with the TEI folder: \(error)")
            throw JobFailed("The index could not be compared with the TEI folder, which the server's log says why.")
        }
    }

    /// The comparison the job takes up: the one under way for the served index, or one of the volumes whose file
    /// changed since the last whole comparison, over a copy of it, or one of every volume. Nil when no file has
    /// changed since the last.
    private func plan(_ index: CorpusIndex, _ served: TEIServedFile) throws -> TEIComparisonWork? {
        if let work = Self.readWork(workURL), work.served == served, FileManager.default.fileExists(atPath: buildingURL.path) {
            return work
        }
        try? FileManager.default.removeItem(at: workFolder)
        var work: TEIComparisonWork
        if let record = phase.record {
            let stale = staleVolumes(of: index, against: record)
            guard !stale.isEmpty else { return nil }
            try FileManager.default.createDirectory(at: workFolder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: comparisonURL, to: buildingURL)
            let again = Set(stale)
            work = TEIComparisonWork(served: served, recheck: true, plan: stale, done: 0,
                                     checked: record.checked.filter { !again.contains($0) },
                                     changed: record.changed.filter { !again.contains($0) },
                                     unchecked: record.unchecked.filter { !again.contains($0.key) },
                                     files: record.files.filter { !again.contains($0.key) })
        } else {
            try FileManager.default.createDirectory(at: workFolder, withIntermediateDirectories: true)
            work = TEIComparisonWork(served: served, recheck: false, plan: Self.volumes(of: index), done: 0, checked: [],
                                     changed: [], unchecked: [:], files: [:])
        }
        try Self.write(work, to: workURL)
        return work
    }

    /// Compares the volumes of `work` not yet compared, keeping `work` in its folder after each, and gives way to
    /// the jobs queued behind it after each but the last. Gives whether every volume is compared, the comparison
    /// index then packed, and the connection of the check's own that seeds each volume and deletes what is not
    /// kept, which is the file's last once the kit's writer is let go, as it is when this returns, and folds its log.
    private func compare(_ work: inout TEIComparisonWork, from served: SQLiteConnection,
                         context: JobContext) async throws -> (finished: Bool, seeder: SQLiteConnection) {
        let building = buildingURL
        let pipeline = try await Blocking.run { [volumesDirectory, resources] in
            try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: building), databaseURL: building,
                                 volumesDirectory: volumesDirectory, resources: resources, defaults: InMemoryIndexingStampStore())
        }
        let seeder = try SQLiteConnection(building.path, readOnly: false)
        do {
            while work.done < work.plan.count {
                let volumeId = work.plan[work.done]
                try await context.step("Comparing \(volumeId) with its TEI file: \(work.done + 1) of \(work.plan.count)",
                                       fraction: Double(work.done) / Double(work.plan.count))
                show(work, volume: volumeId)
                try await compareVolume(volumeId, in: &work, pipeline: pipeline, from: served, seeder: seeder)
                work.done += 1
                try Self.write(work, to: workURL)
                show(work, volume: nil)
                if let hook = volumeComparedTestHook { await hook(volumeId) }
                if work.done < work.plan.count,
                   await jobs.jobs().contains(where: { $0.state == .queued && $0.kind != .teiComparison }) {
                    return (false, seeder)
                }
            }
            try await pipeline.vacuumIndex()
            return (true, seeder)
        } catch {
            seeder.close()
            throw error
        }
    }

    /// One volume: its revision rows the export's, its TEI indexed over them with the kit's `indexVolume`, and its
    /// tables kept when the kit stamped a change, or deleted with its revision rows when it stamped none.
    private func compareVolume(_ volumeId: String, in work: inout TEIComparisonWork, pipeline: IndexingPipeline,
                               from served: SQLiteConnection, seeder: SQLiteConnection) async throws {
        // A volume compared before, as a re-check's, or one a stop left half compared, leaves the comparison first.
        if try Self.holds(volumeId, seeder) { try await Self.delete(volumeId, pipeline: pipeline, seeder: seeder) }
        work.checked.removeAll { $0 == volumeId }
        work.changed.removeAll { $0 == volumeId }
        work.unchecked[volumeId] = nil
        // The file as it is before the indexer reads it, so that one changed meanwhile is compared again.
        guard let file = TEIFileStamp.of(teiFile(volumeId)) else {
            work.files[volumeId] = nil
            work.unchecked[volumeId] = "Its file, \(volumeId).xml, is not in the TEI folder, so the reader opens none of its documents."
            return
        }
        // Room for the volume's tables and their log, beside the user store and its backups.
        if let free = VolumeLibrary.freeBytes(at: folder), free < 2 * file.bytes + LibraryIndexer.spareBytes {
            throw TEICheckProblem("the data volume has \(LibraryIndexer.megabytes(free)) free, and comparing \(volumeId) needs about \(LibraryIndexer.megabytes(2 * file.bytes + LibraryIndexer.spareBytes))")
        }
        work.files[volumeId] = file
        do {
            try Self.seed(volumeId, from: served, into: seeder)
            try await pipeline.indexVolume(volumeId)
            let moved = try await pipeline.documentRevisions(forVolumeId: volumeId).filter { $0.changedAt != nil }
            work.checked.append(volumeId)
            if moved.isEmpty {
                try await Self.delete(volumeId, pipeline: pipeline, seeder: seeder)
            } else {
                work.changed.append(volumeId)
                log("\(volumeId): \(moved.count) \(moved.count == 1 ? "document's" : "documents'") TEI changed after the export was indexed")
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            log("\(volumeId) could not be compared with its TEI: \(error)")
            work.unchecked[volumeId] = "Its TEI could not be indexed to compare it, which the server's log says why."
            try? await Self.delete(volumeId, pipeline: pipeline, seeder: seeder)
        }
    }

    /// The comparison whole: its log folded into it and its journal a rollback journal's, a file a reader opens
    /// immutable, renamed into place with its record, and the work folder removed.
    private func place(_ work: TEIComparisonWork, seeder: SQLiteConnection) throws -> TEIChangeRecord {
        let folded = try seeder.query("PRAGMA wal_checkpoint(TRUNCATE)").first?.first?.integer ?? 1
        let journal = try seeder.query("PRAGMA journal_mode=DELETE").first?.first?.text ?? ""
        guard folded == 0, journal.lowercased() == "delete" else {
            throw TEICheckProblem("the comparison index's log could not be folded into it (busy \(folded), journal \(journal))")
        }
        seeder.close()
        // To the second, as the record's file keeps it.
        let checkedAt = Date(timeIntervalSince1970: now().timeIntervalSince1970.rounded(.down))
        let record = TEIChangeRecord(served: work.served, checkedAt: checkedAt, checked: work.checked.sorted(),
                                     changed: work.changed.sorted(), unchecked: work.unchecked, files: work.files)
        try Self.place(buildingURL, at: comparisonURL)
        try Self.write(record, to: recordURL)
        try? FileManager.default.removeItem(at: workFolder)
        return record
    }

    static func line(_ record: TEIChangeRecord, recheck: Bool, compared: Int) -> String {
        let found = "\(record.changed.count) with a document whose TEI changed after the export was indexed"
        let failed = record.unchecked.isEmpty ? "" : "; \(record.unchecked.count) not compared"
        return recheck
            ? "Compared again the \(compared) \(compared == 1 ? "volume" : "volumes") whose TEI file changed: of the index's \(record.checked.count) volumes compared, \(found)\(failed)"
            : "Compared \(record.checked.count) of the index's \(record.checked.count + record.unchecked.count) volumes with the TEI folder: \(found)\(failed)"
    }

    // MARK: The comparison index's rows

    /// Whether the comparison index holds anything of `volumeId`.
    static func holds(_ volumeId: String, _ db: SQLiteConnection) throws -> Bool {
        try !db.query(
            """
            SELECT 1 FROM document_revisions WHERE volume_id = ?
            UNION ALL SELECT 1 FROM document_cache WHERE volume_id = ? LIMIT 1
            """, [.text(volumeId), .text(volumeId)]).isEmpty
    }

    /// Deletes `volumeId` from the comparison index: its tables with the kit's `removeVolume`, and its revision
    /// rows, which the kit keeps.
    static func delete(_ volumeId: String, pipeline: IndexingPipeline, seeder: SQLiteConnection) async throws {
        try await pipeline.removeVolume(volumeId)
        _ = try seeder.query("DELETE FROM document_revisions WHERE volume_id = ?", [.text(volumeId)])
    }

    /// The export's record of `volumeId`'s documents, as the comparison's baseline: each document's two hashes and
    /// the version that indexed it, with no change and no review, so that what the kit stamps is the TEI's alone.
    static func seed(_ volumeId: String, from served: SQLiteConnection, into writer: SQLiteConnection) throws {
        let rows = try served.query(
            "SELECT document_id, content_hash, body_hash, index_version FROM document_revisions WHERE volume_id = ?",
            [.text(volumeId)])
        try writer.execute("BEGIN IMMEDIATE")
        do {
            _ = try writer.query("DELETE FROM document_revisions WHERE volume_id = ?", [.text(volumeId)])
            for row in rows {
                _ = try writer.query(
                    """
                    INSERT INTO document_revisions
                        (volume_id, document_id, content_hash, body_hash, changed_at, change_kind, reviewed_at, index_version)
                    VALUES (?, ?, ?, ?, NULL, NULL, NULL, ?)
                    """, [.text(volumeId), row[0], row[1], row[2], row[3]])
            }
            try writer.execute("COMMIT")
        } catch {
            try? writer.execute("ROLLBACK")
            throw error
        }
    }

    // MARK: Files

    static func read(_ url: URL) -> TEIChangeRecord? { decode(url) }
    static func readWork(_ url: URL) -> TEIComparisonWork? { decode(url) }

    private static func decode<T: Decodable>(_ url: URL) -> T? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    /// Writes `value` whole under a hidden name, flushed, and renames it into place.
    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let hidden = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).new")
        try encoder.encode(value).write(to: hidden)
        try VolumeLibrary.flush(hidden)
        try place(hidden, at: url)
    }

    /// Renames `file` over `url`, and flushes the folder.
    static func place(_ file: URL, at url: URL) throws {
        try VolumeLibrary.rename(file, over: url)
        VolumeLibrary.flushFolder(url.deletingLastPathComponent())
    }
}
