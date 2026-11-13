// Import mode's step 5 (SPEC's Import procedure; PLAN's S21f, the hash comparison S2 deferred): each document of
// the served export recomputed from the mounted TEI as the kit's indexer computes it, and compared with the
// export's `document_revisions`, so that a document whose TEI changed after the Mac indexed it is listed for the
// review of what changed, as the Mac's After an Update lists one a volume update changed. The two hashes are the
// kit's indexer's own and not public, so the comparison runs the indexer itself: each volume is indexed with
// `indexVolume`, the volume-update path, into a comparison index of the server's own, whose revision rows are
// first the export's, so that the kit stamps what moved, `body`, `apparatus` or `vanished`, by its own rules, as
// it stamps an update. A volume nothing moved in is removed from the comparison index again, which keeps its
// revision rows; one something moved in is kept, so that the review reads its text as it reads now. The
// comparison index is the server's own file, in a folder of its own, `/data/tei-check`, apart from the served
// index's, which the server never writes in Import mode (Compatibility contract, rule 7), and it is read through
// the kit's immutable read-only open, once it is whole. The check runs beside the queue, not in it: over a full corpus it is hours of indexing, which would hold
// every job behind it, and it writes nothing another job reads.

import FRUSCoreKit
import FTS5Store
import Foundation

/// What the check found of the served index, kept beside it in `tei-changes.json`, written whole and renamed into
/// place once the comparison index it describes is whole.
public struct TEIChangeRecord: Codable, Sendable, Equatable {
    public var format = 1
    /// The served index's file the check compared, by device and inode, which an import's rename makes another, and by
    /// its length and the export's stamp, since a file made later can take an inode a removed one freed.
    public var device: UInt64
    public var inode: UInt64
    public var bytes: Int64
    public var exportedAt: String?
    public var checkedAt: Date
    /// The volumes compared, and those with a document whose TEI changed, by id.
    public var checked: [String]
    public var changed: [String]
    /// The volumes the check could not compare, with why, in the server's words.
    public var unchecked: [String: String]

    public static let fileName = "tei-changes.json"
    /// The comparison index the record describes.
    public static let indexName = "tei-changes.db"

    /// Whether it describes the served index `index`.
    func describes(_ index: CorpusIndex?) -> Bool {
        guard let index, let file = index.file else { return false }
        return file.device == device && file.inode == inode && Self.bytes(of: index.url) == bytes
            && index.summary.exportedAt == exportedAt
    }

    static func bytes(of url: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value ?? -1
    }
}

/// Why a check stopped, in the server's words.
struct TEICheckProblem: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Where the check stands, for Administration.
public struct TEICheckStatus: Sendable, Equatable {
    /// The volume being compared, and how far through the volumes the check is.
    public var volume: String?
    public var done: Int
    public var total: Int
    /// Whether a check runs.
    public var running: Bool
    /// The record of the last check of the served index, when it is whole.
    public var record: TEIChangeRecord?
    /// Why the last check stopped, in the server's words.
    public var problem: String?
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
    /// The check's own folder, `/data/tei-check`: the comparison index, its record, and the folder a check builds in.
    public let folder: URL
    let resources: IndexingResources
    let state: ServerState
    let now: @Sendable () -> Date
    let log: @Sendable (String) -> Void
    /// The served index's file the check last began for, so that it begins once for each.
    private var begunFor: FileIdentity?
    private var task: Task<Void, Never>?
    /// Each check's own number: a check cancelled for another index's goes on to its next step, and what it does
    /// then, to the status or the files, it does only while it is the latest.
    private var generation = 0
    private var phase = TEICheckStatus(volume: nil, done: 0, total: 0, running: false, record: nil, problem: nil)
    private var opened: TEIComparison?
    /// Test hook: told each volume once it has been compared.
    var volumeComparedTestHook: (@Sendable (String) async -> Void)?

    public init(liveIndex: URL, volumesDirectory: URL, folder: URL, resources: IndexingResources, state: ServerState,
                now: @escaping @Sendable () -> Date = Date.init, log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.liveIndex = liveIndex.standardizedFileURL
        self.volumesDirectory = volumesDirectory.standardizedFileURL
        self.folder = folder.standardizedFileURL
        self.resources = resources
        self.state = state
        self.now = now
        self.log = log
    }

    var recordURL: URL { folder.appendingPathComponent(TEIChangeRecord.fileName) }
    var comparisonURL: URL { folder.appendingPathComponent(TEIChangeRecord.indexName) }
    /// Where a check builds its comparison index, a folder of its own for each, removed when it ends, or by a start
    /// for one a stop cut short.
    func workFolder(_ generation: Int) -> URL { folder.appendingPathComponent(".tei-changes-\(generation)", isDirectory: true) }

    func setVolumeComparedTestHook(_ hook: (@Sendable (String) async -> Void)?) { volumeComparedTestHook = hook }

    /// Where the check stands.
    public func status() -> TEICheckStatus { phase }

    /// Begins the check of the index the server serves, unless it has begun for that file already, or a record of a
    /// whole check of it is in place: at a start, once the index found there is open, and after each import, which
    /// serves another file. A check under way for an index the server no longer serves is cancelled first.
    public func ensureCurrent() async {
        guard state.configuration.mode == .import else { return }
        if generation == 0 {
            // A start: the folders a stop left a check building in.
            for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasPrefix(".tei-changes") {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
            }
        }
        guard let index = await state.index, let file = index.file else {
            // No index served, as after a reset: nothing to compare, and a check under way stops.
            if begunFor != nil || task != nil { forget() }
            return
        }
        guard begunFor != file else { return }
        forget()
        begunFor = file
        if let record = Self.read(recordURL), record.describes(index),
           FileManager.default.fileExists(atPath: comparisonURL.path) {
            phase = TEICheckStatus(volume: nil, done: record.checked.count, total: record.checked.count, running: false,
                                   record: record, problem: nil)
            return
        }
        phase = TEICheckStatus(volume: nil, done: 0, total: 0, running: true, record: nil, problem: nil)
        let mine = generation
        task = Task { [weak self] in await self?.run(index, file: file, generation: mine) }
    }

    /// Stops the check under way, which ends at its next step, and forgets what was found of the index before.
    private func forget() {
        task?.cancel()
        task = nil
        generation += 1
        begunFor = nil
        opened = nil
        phase = TEICheckStatus(volume: nil, done: 0, total: 0, running: false, record: nil, problem: nil)
    }

    /// Changes the status, for the check numbered `mine` while it is the latest.
    private func update(_ mine: Int, _ change: (inout TEICheckStatus) -> Void) {
        guard mine == generation else { return }
        change(&phase)
    }

    /// The comparison index of the served index's last whole check, opened through the kit's immutable read-only
    /// open, or nil while none describes it.
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

    /// Waits until the check under way has ended: for the tests.
    func settled() async {
        await task?.value
    }

    // MARK: The check

    private func run(_ index: CorpusIndex, file: FileIdentity, generation mine: Int) async {
        let volumes = index.documentsByVolume.filter { $0.value > 0 }.keys.sorted()
        let work = workFolder(mine)
        let building = work.appendingPathComponent(TEIChangeRecord.indexName)
        defer { try? FileManager.default.removeItem(at: work) }
        var checked: [String] = []
        var changed: [String] = []
        var unchecked: [String: String] = [:]
        do {
            try? FileManager.default.removeItem(at: work)
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            // The export's own record of each document, read once a volume through a connection of the check's own.
            let served = try SQLiteConnection.immutable(index.url)
            defer { served.close() }
            // The comparison index's writer, the kit's, let go once every volume is compared, so that the connection
            // of the check's own that seeds each volume is the file's last, and folds its log and ends it.
            let seeder = try await compare(volumes, from: served, into: building, generation: mine, checked: &checked,
                                           changed: &changed, unchecked: &unchecked)
            defer { seeder.close() }
            // A file a reader opens immutable: its log folded, the fold whole, and its journal a rollback journal's.
            let folded = try seeder.query("PRAGMA wal_checkpoint(TRUNCATE)").first?.first?.integer ?? 1
            let journal = try seeder.query("PRAGMA journal_mode=DELETE").first?.first?.text ?? ""
            guard folded == 0, journal.lowercased() == "delete" else {
                throw TEICheckProblem("the comparison index's log could not be folded into it (busy \(folded), journal \(journal))")
            }
        } catch is CancellationError {
            update(mine) { $0 = TEICheckStatus(volume: nil, done: 0, total: 0, running: false, record: nil, problem: nil) }
            log("The comparison of the index with the TEI folder stopped, for another index")
            return
        } catch {
            log("The index could not be compared with the TEI folder: \(error)")
            update(mine) {
                $0 = TEICheckStatus(volume: nil, done: 0, total: volumes.count, running: false, record: nil,
                                    problem: "The index could not be compared with the TEI folder, which the server's log says why.")
            }
            return
        }
        // A check cancelled for another index's places nothing.
        guard mine == generation else { return }
        // To the second, as the record's file keeps it.
        let checkedAt = Date(timeIntervalSince1970: now().timeIntervalSince1970.rounded(.down))
        let record = TEIChangeRecord(device: file.device, inode: file.inode, bytes: TEIChangeRecord.bytes(of: index.url),
                                     exportedAt: index.summary.exportedAt, checkedAt: checkedAt, checked: checked, changed: changed,
                                     unchecked: unchecked)
        do {
            try Self.place(building, at: comparisonURL)
            try Self.write(record, to: recordURL)
        } catch {
            log("The comparison of the index with the TEI folder could not be kept: \(error)")
            phase = TEICheckStatus(volume: nil, done: checked.count, total: volumes.count, running: false, record: nil,
                                   problem: "The comparison of the index with the TEI folder could not be kept in /data/tei-check, which the server's log says why.")
            return
        }
        opened = nil
        phase = TEICheckStatus(volume: nil, done: checked.count, total: volumes.count, running: false, record: record, problem: nil)
        log("Compared \(checked.count) of the index's \(volumes.count) volumes with the TEI folder: \(changed.count) with a document whose TEI changed after the export was indexed")
    }

    /// Indexes each of `volumes` from the TEI folder into the comparison index at `building`, with the kit's
    /// `indexVolume`, over the export's record of its documents: a volume nothing moved in is removed again, and one
    /// something moved in kept. Gives the connection of the check's own that seeded each volume, once the kit's
    /// writer, packed, is let go.
    private func compare(_ volumes: [String], from served: SQLiteConnection, into building: URL, generation mine: Int,
                         checked: inout [String], changed: inout [String], unchecked: inout [String: String]) async throws -> SQLiteConnection {
        let pipeline = try await Blocking.run { [volumesDirectory, resources] in
            try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: building), databaseURL: building,
                                 volumesDirectory: volumesDirectory, resources: resources, defaults: InMemoryIndexingStampStore())
        }
        let seeder = try SQLiteConnection(building.path, readOnly: false)
        update(mine) { $0.total = volumes.count }
        do {
            for (position, volumeId) in volumes.enumerated() {
                try Task.checkCancellation()
                update(mine) { ($0.volume, $0.done) = (volumeId, position) }
                let tei = volumesDirectory.appendingPathComponent("\(volumeId).xml")
                guard let size = VolumeLibrary.regularFileSize(tei) else {
                    unchecked[volumeId] = "Its file, \(volumeId).xml, is not in the TEI folder, so the reader opens none of its documents."
                    continue
                }
                // Room for the volume's tables and their log, beside the user store and its backups.
                if let free = VolumeLibrary.freeBytes(at: folder), free < 2 * Int64(size) + LibraryIndexer.spareBytes {
                    throw TEICheckProblem("the data volume has \(LibraryIndexer.megabytes(free)) free, and comparing \(volumeId) needs about \(LibraryIndexer.megabytes(2 * Int64(size) + LibraryIndexer.spareBytes))")
                }
                do {
                    try Self.seed(volumeId, from: served, into: seeder)
                    try await pipeline.indexVolume(volumeId)
                    let moved = try await pipeline.documentRevisions(forVolumeId: volumeId).filter { $0.changedAt != nil }
                    checked.append(volumeId)
                    if moved.isEmpty {
                        try await pipeline.removeVolume(volumeId)
                    } else {
                        changed.append(volumeId)
                        log("\(volumeId): \(moved.count) \(moved.count == 1 ? "document's" : "documents'") TEI changed after the export was indexed")
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    log("\(volumeId) could not be compared with its TEI: \(error)")
                    unchecked[volumeId] = "Its TEI could not be indexed to compare it, which the server's log says why."
                    try? await pipeline.removeVolume(volumeId)
                }
                if let hook = volumeComparedTestHook { await hook(volumeId) }
            }
            try await pipeline.vacuumIndex()
        } catch {
            seeder.close()
            throw error
        }
        return seeder
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

    static func read(_ url: URL) -> TEIChangeRecord? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TEIChangeRecord.self, from: data)
    }

    /// Writes `record` whole under a hidden name, flushed, and renames it into place.
    static func write(_ record: TEIChangeRecord, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let hidden = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).new")
        try encoder.encode(record).write(to: hidden)
        try VolumeLibrary.flush(hidden)
        try place(hidden, at: url)
    }

    /// Renames `file` over `url`, and flushes the folder.
    static func place(_ file: URL, at url: URL) throws {
        try VolumeLibrary.rename(file, over: url)
        VolumeLibrary.flushFolder(url.deletingLastPathComponent())
    }
}
