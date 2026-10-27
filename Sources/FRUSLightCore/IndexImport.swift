// Import mode: validate a Mac research export, make it the live index, and open it read-only.
//
// The steps follow docs/SPEC.md (Operating modes > Import procedure), changed where a real
// v65 export showed the spec could not work as written (docs/prep/README.md):
// - SQLite refuses the rank-1 FTS5 integrity check on a read-only connection, so the checks
//   run on a writable copy, made with the backup API, which then becomes the live index.
// - An export that includes the owner's writing (PLAN's S16e) has it read from the copy, then the
//   copy stripped with the kit's own statements and checked; the writing goes into the importing
//   user's store only after every check that could refuse the file, just before the copy is
//   installed, so a refusal still changes nothing. A server that keeps no user data refuses one, as
//   phase 1 did.
// - Comparing each document's hashes with its TEI needs FRUSCoreKit's indexer. The server links
//   the kit since session 8, but that step is not built yet.

import CSQLite
import Foundation

/// Told about each step of an import as it starts, and about copying progress.
public protocol ImportObserver: Sendable {
    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) async
}

/// What the live index holds, as `/api/v1/status` reports it.
public struct IndexSummary: Sendable, Equatable, Codable {
    public var documents: Int
    public var volumes: Int
    public var indexVersion: Int
    public var ftsSchemaVersion: Int
    /// From the export's `research_provenance`; nil for an unstamped copy.
    public var exportedAt: String?
    public var appVersion: String?
    public var appBuild: String?

    public init(documents: Int, volumes: Int, indexVersion: Int, ftsSchemaVersion: Int,
                exportedAt: String?, appVersion: String?, appBuild: String?) {
        self.documents = documents
        self.volumes = volumes
        self.indexVersion = indexVersion
        self.ftsSchemaVersion = ftsSchemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.appBuild = appBuild
    }
}

/// Which file a path named when it was looked at: its device and inode. An import renames a new
/// file over `frus.db`, so the path alone does not say which index a connection opened.
public struct FileIdentity: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64

    /// The identity of the file at `url` now, or nil when it cannot be read.
    public init?(_ url: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let device = (attributes[.systemNumber] as? NSNumber)?.uint64Value,
              let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value else { return nil }
        self.device = device
        self.inode = inode
    }
}

/// The live corpus index, open read-only with `immutable=1`.
public final class CorpusIndex: Sendable {
    public let url: URL
    /// The file this index's connection opened, as it was just after opening.
    public let file: FileIdentity?
    public let summary: IndexSummary
    /// How many documents each volume has in `document_cache`, by volume id. It is not part of
    /// the status: the volume endpoints report it per volume.
    public let documentsByVolume: [String: Int]
    let connection: SQLiteConnection

    /// Opens an installed index after checking its format and version, but not its
    /// integrity, which the import checked. Throws `ImportRefusal` for an index this build
    /// cannot serve, such as one from before an upgrade.
    public static func open(_ url: URL) throws -> CorpusIndex {
        let db = try SQLiteConnection.immutable(url)
        let file = FileIdentity(url)
        try ExportChecks.checkFormat(db)
        let provenance = try ExportChecks.provenance(db)
        let version: Int
        do {
            version = try ExportChecks.checkVersions(db, provenance: provenance)
        } catch let refusal as ImportRefusal {
            throw ImportRefusal(.indexVersionMismatch, refusal.reason)
        }
        let counts = try db.query("SELECT count(*), count(DISTINCT volume_id) FROM document_cache")
        var documentsByVolume: [String: Int] = [:]
        for row in try db.query("SELECT volume_id, count(*) FROM document_cache GROUP BY volume_id") {
            if let volume = row[0].text { documentsByVolume[volume] = Int(row[1].integer ?? 0) }
        }
        let summary = IndexSummary(
            documents: Int(counts.first?[0].integer ?? 0),
            volumes: Int(counts.first?[1].integer ?? 0),
            indexVersion: version,
            ftsSchemaVersion: IndexCompatibility.ftsSchemaVersion,
            exportedAt: provenance?["exported_at"],
            appVersion: provenance?["app_version"],
            appBuild: provenance?["app_build"])
        return CorpusIndex(url: url, file: file, summary: summary, documentsByVolume: documentsByVolume, connection: db)
    }

    private init(url: URL, file: FileIdentity?, summary: IndexSummary, documentsByVolume: [String: Int], connection: SQLiteConnection) {
        self.url = url
        self.file = file
        self.summary = summary
        self.documentsByVolume = documentsByVolume
        self.connection = connection
    }
}

/// An installed export: the live index, and what became of the owner's writing when the export held it.
public struct ImportedExport: Sendable {
    /// The new live index, open.
    public let index: CorpusIndex
    /// What the user's store made of the writing, for an export made with it; nil for one without.
    public let writing: MovedWriting?
}

/// Validates a Mac export and installs it.
public struct IndexImporter: Sendable {
    let files: any FileStore
    let writer: any IndexWriter
    /// What becomes of the owner's writing in an export made with it; nil on a server that keeps
    /// no user data, which refuses such an export.
    let writingMove: WritingMove?

    public init(files: any FileStore, writer: any IndexWriter, writing: WritingMove? = nil) {
        self.files = files
        self.writer = writer
        self.writingMove = writing
    }

    /// Imports one export. On success its copy is the live index and open; the old index is kept
    /// as `frus.db.prev`. On an `ImportRefusal` (the file's fault) or an `ImportProblem` (the
    /// server's) nothing changes, with one exception: when installing the copy fails, the owner's
    /// writing an export held stays kept in the user's store, and a retry keeps it as it is. The
    /// source file is never modified or removed; the caller decides what happens to it.
    public func importExport(at source: URL, observer: some ImportObserver) async throws -> ImportedExport {
        let name = source.lastPathComponent
        let candidate = files.candidateIndex
        removeCandidate()  // left behind by an interrupted import

        /// Runs blocking SQLite work for a step, off the cooperative pool, classifying its errors.
        func run<T: Sendable>(_ step: ReadinessStep, _ work: @escaping @Sendable () throws -> T) async throws -> T {
            do {
                return try await Blocking.run(work)
            } catch let error as SQLiteError {
                throw ExportChecks.classify(error, at: step, file: name)
            }
        }
        var moved: MovedWriting?

        await observer.importDidReach(.copyingExport, detail: "Copying \(name)", progress: 0)
        // Checked before anything reads the file, since every read would follow the link.
        if ExportChecks.isSymbolicLink(source) { throw ExportChecks.linkRefusal(name) }
        guard ExportChecks.hasSQLiteHeader(source) else {
            throw ImportRefusal(.copyingExport, "\(name) is not a SQLite database. Use Export Research Database… in FRUS Explorer's settings.")
        }
        // immutable=1 never reads a -wal file, so a copy of a live database would lose its newest data.
        let wal = URL(fileURLWithPath: source.path + "-wal")
        if let walSize = Self.size(of: wal), walSize > 0 {
            throw ImportRefusal(.copyingExport, "\(name) arrived with a \(wal.lastPathComponent) file, so it is a copy of a database in use. Remove \(wal.lastPathComponent) from /data/import, then copy in an export made with Export Research Database… in FRUS Explorer's settings.")
        }
        // Nor does it roll back an unfinished transaction, so the copy would be half-written.
        if ExportChecks.hasHotJournal(beside: source) {
            throw ImportRefusal(.copyingExport, "\(name) arrived with a \(name)-journal file that may hold an unfinished transaction, so it is a copy of a database in use. Remove \(name)-journal from /data/import, then copy in an export made with Export Research Database… in FRUS Explorer's settings.")
        }
        let needed = (Self.size(of: source) ?? 0) + 64 * 1_048_576
        if let free = try? files.availableCapacity(), free < needed {
            throw ImportProblem(.copyingExport, "Importing \(name) needs about \(gigabytes(needed)) free beside the index; \(gigabytes(free)) is free.")
        }

        do {
            let copy: SQLiteConnection
            do {
                copy = try SQLiteConnection(candidate.path, readOnly: false, create: true)
            } catch let error as SQLiteError {
                throw ImportProblem(.copyingExport, "The server could not create \(candidate.lastPathComponent): \(error.message).")
            }
            defer { copy.close() }
            let export: SQLiteConnection
            do {
                export = try SQLiteConnection.immutable(source)
            } catch let error as SQLiteError {
                throw ImportRefusal(.copyingExport, "\(name) could not be opened as a SQLite database: \(error.message).")
            }
            defer { export.close() }
            do {
                try await export.backup(into: copy) { fraction in
                    await observer.importDidReach(.copyingExport, detail: "Copying \(name)", progress: fraction)
                }
            } catch let error as SQLiteError {
                throw ExportChecks.classify(error, at: .copyingExport, file: name)
            }
            export.close()

            await observer.importDidReach(.checkingFormat, detail: "Checking the file's format", progress: nil)
            let provenance = try await run(.checkingFormat) {
                // The live index is served immutable, so it needs no write-ahead log.
                try copy.execute("PRAGMA journal_mode = DELETE")
                try ExportChecks.checkFormat(copy)
                return try ExportChecks.provenance(copy)
            }

            await observer.importDidReach(.checkingVersions, detail: "Checking the index and FTS schema versions", progress: nil)
            _ = try await run(.checkingVersions) { try ExportChecks.checkVersions(copy, provenance: provenance) }

            let includesWriting = provenance?["my_writing_included"] == "1"
            await observer.importDidReach(.checkingWriting, detail: includesWriting
                ? "Reading your notes, summaries and tags from the export" : "Checking that it holds no notes, summaries or tags",
                progress: nil)
            let canKeep = writingMove != nil
            let writing = try await run(.checkingWriting) {
                try ExportChecks.checkWriting(copy, provenance: provenance, canKeep: canKeep)
            }
            if writing != nil, let move = writingMove {
                try await strip(copy, of: name, with: move.strip, observer: observer)
            }

            await observer.importDidReach(.checkingIntegrity, detail: "Checking the database and both full-text indexes", progress: nil)
            try await run(.checkingIntegrity) { try ExportChecks.checkIntegrity(copy) }

            if let writing, let move = writingMove {
                await observer.importDidReach(.movingWriting, detail: "Moving your notes, summaries and tags into your research data",
                                              progress: nil)
                do {
                    moved = try await Blocking.run { try move.keep(writing) }
                } catch {
                    throw ImportProblem(.movingWriting, "Your notes, summaries and tags could not be kept in your research data, so \(name) was not installed: \(error)")
                }
            }
        } catch {
            removeCandidate()
            throw error
        }

        await observer.importDidReach(.installingIndex, detail: "Making the new index live", progress: nil)
        do {
            try await Blocking.run { [writer] in try writer.install(candidate: candidate) }
        } catch {
            removeCandidate()
            throw ImportProblem(.installingIndex, "The new index could not be made live: \(error.localizedDescription)")
        }

        await observer.importDidReach(.openingIndex, detail: "Opening the index read-only", progress: nil)
        let live = files.liveIndex
        do {
            return ImportedExport(index: try await Blocking.run { try CorpusIndex.open(live) }, writing: moved)
        } catch let error as SQLiteError {
            throw ImportProblem(.openingIndex, "The new index was installed but could not be opened: \(error.message).")
        }
    }

    /// Removes the owner's writing from the copy with the kit's statements, each named as the kit
    /// names it, then stamps the copy as the app stamps one it made without the writing. A copy that
    /// still holds some is refused.
    ///
    /// The statements run with SQLite's `secure_delete` on, which leaves zeros where they free a
    /// page. The kit's order reclaims the freed pages before the two full-text indexes are rebuilt,
    /// as it must, since `VACUUM` may renumber the rows they index; so the pages the rebuild of
    /// `user_content` frees, which held the words of the notes and summaries, would otherwise stay
    /// in the file. `VACUUM` writes a whole copy of the database beside it, in SQLite's temporary
    /// folder (`FRUSLightServer` puts it under the data directory), and the pages it replaces in the
    /// journal, so the strip needs about twice the copy's size free.
    private func strip(_ copy: SQLiteConnection, of name: String, with steps: [StripStep],
                       observer: some ImportObserver) async throws {
        let needed = 2 * (Self.size(of: files.candidateIndex) ?? 0) + 64 * 1_048_576
        if let free = try? files.availableCapacity(), free < needed {
            throw ImportProblem(.strippingWriting, "Removing your notes, summaries and tags from the server's copy of \(name) needs about \(gigabytes(needed)) free beside the index; \(gigabytes(free)) is free.")
        }
        do {
            try await Blocking.run { try copy.execute("PRAGMA secure_delete = ON") }
            for step in steps {
                await observer.importDidReach(.strippingWriting, detail: "\(step.action.prefix(1).uppercased())\(step.action.dropFirst()) in the server's copy",
                                              progress: nil)
                do {
                    try await Blocking.run { try copy.execute(step.sql) }
                } catch let error as SQLiteError {
                    throw ExportChecks.classify(error, at: .strippingWriting, file: name, while: step.action)
                }
            }
            try await Blocking.run {
                _ = try copy.query("UPDATE research_provenance SET value = '0' WHERE key = 'my_writing_included'")
            }
            guard try await Blocking.run({ try !ExportChecks.holdsWriting(copy) }) else {
                throw ImportRefusal(.strippingWriting, "The server's copy of \(name) still held notes, summaries or tags after FRUS Explorer's steps had removed them, so it is not served. Export again with Export Research Database….")
            }
        } catch let error as SQLiteError {
            throw ExportChecks.classify(error, at: .strippingWriting, file: name)
        }
    }

    static func size(of url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
    }

    private func removeCandidate() {
        for suffix in ["", "-journal", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: files.candidateIndex.path + suffix)
        }
    }

    private func gigabytes(_ bytes: Int64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
    }
}

/// The checks an export must pass, shared by an import and by opening the index at start.
enum ExportChecks {
    /// Tables Import mode relies on.
    static let requiredTables = ["document_cache", "frus_documents", "user_content", "document_revisions"]

    /// Whether `url` is a symbolic link, not following it.
    static func isSymbolicLink(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    /// The refusal for a link in the drop zone. `docker compose cp` copies a link as a link, so
    /// it usually points at a path that exists only on the host; one that resolves would be
    /// imported from outside the drop zone. Either way, the export itself should be copied.
    static func linkRefusal(_ name: String) -> ImportRefusal {
        ImportRefusal(.copyingExport, "\(name) is a symbolic link, not an export. Copy the export itself with docker compose cp -L, which follows the link.")
    }

    /// Whether a rollback journal beside the database holds, or may hold, an unfinished
    /// transaction, by SQLite's own test (`hasHotJournal` in pager.c): it is not empty and its
    /// first byte is not zero, and one that cannot be opened or read counts as hot, as SQLite
    /// assumes. Anything but a regular file in the journal's place, such as a link or a FIFO,
    /// counts too, and is never opened: opening a FIFO would block. `immutable=1` never rolls a
    /// journal back. `open` is replaceable for tests, which run as root in CI.
    static func hasHotJournal(beside url: URL,
                              open: (String) -> FileHandle? = { FileHandle(forReadingAtPath: $0) }) -> Bool {
        let journal = url.path + "-journal"
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: journal) else { return false }
        guard attributes[.type] as? FileAttributeType == .typeRegular else { return true }
        guard (attributes[.size] as? NSNumber)?.int64Value != 0 else { return false }
        guard let handle = open(journal) else { return true }
        defer { try? handle.close() }
        guard let first = try? handle.read(upToCount: 1) else { return true }
        return first.first.map { $0 != 0 } ?? false
    }

    /// Whether the file starts with SQLite's 16-byte header string.
    static func hasSQLiteHeader(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let magic = (try? handle.read(upToCount: 16)) ?? Data()
        return magic == Data("SQLite format 3\0".utf8)
    }

    static func checkFormat(_ db: SQLiteConnection) throws {
        let missing = try requiredTables.filter { try !db.hasObject(named: $0) }
        guard missing.isEmpty else {
            throw ImportRefusal(.checkingFormat, "This is not a FRUS Explorer research export: it has no \(missing.joined(separator: ", ")).")
        }
        let generation = Int(try db.scalar("PRAGMA user_version")?.integer ?? -1)
        guard generation == IndexCompatibility.ftsSchemaVersion else {
            throw ImportRefusal(.checkingFormat, "The export's FTS schema is generation \(generation); this server serves generation \(IndexCompatibility.ftsSchemaVersion).")
        }
    }

    /// The export's `research_provenance` stamp, or nil for an unstamped copy: a `.backup`
    /// of the live index has no such table, and an empty one stamps nothing either.
    static func provenance(_ db: SQLiteConnection) throws -> [String: String]? {
        guard try db.hasObject(named: "research_provenance") else { return nil }
        var stamp: [String: String] = [:]
        for row in try db.query("SELECT key, value FROM research_provenance") {
            if let key = row[0].text { stamp[key] = row[1].text }
        }
        return stamp.isEmpty ? nil : stamp
    }

    /// Returns the index version, or refuses one this server does not serve.
    static func checkVersions(_ db: SQLiteConnection, provenance: [String: String]?) throws -> Int {
        let supported = IndexCompatibility.supportedIndexVersion
        guard let stamp = provenance else {
            // A hand-made copy has no stamp: every document must carry the supported version.
            let row = try db.query("SELECT count(*), count(index_version), min(index_version), max(index_version) FROM document_revisions").first ?? []
            let total = row.first?.integer ?? 0
            guard total > 0, row[1].integer == total, row[2].integer == Int64(supported), row[3].integer == Int64(supported) else {
                let range = [row[2].text, row[3].text].compactMap { $0 }.joined(separator: " to ")
                throw ImportRefusal(.checkingVersions, "This copy has no export stamp, and its documents are not all at index version \(supported) (found \(range.isEmpty ? "none" : range)). Use Export Research Database… on a Mac running a matching build.")
            }
            return supported
        }
        func number(_ key: String) throws -> Int {
            guard let value = stamp[key].flatMap({ Int($0) }) else {
                throw ImportRefusal(.checkingVersions, "The export's stamp has no \(key).")
            }
            return value
        }
        let installed = try number("installed_index_version")
        let current = try number("current_index_version")
        guard installed == current else {
            throw ImportRefusal(.checkingVersions, "The Mac's library was at index version \(installed) while its app expects \(current). Let FRUS Explorer finish re-indexing, then export again.")
        }
        guard current == supported else {
            throw ImportRefusal(.checkingVersions, "This export is index version \(current); this server serves index version \(supported). Update FRUS Explorer or this server so they match, then export again.")
        }
        for key in ["installed_fts_schema_version", "current_fts_schema_version"] {
            let value = try number(key)
            guard value == IndexCompatibility.ftsSchemaVersion else {
                throw ImportRefusal(.checkingVersions, "The export's \(key) is \(value); this server serves \(IndexCompatibility.ftsSchemaVersion).")
            }
        }
        return supported
    }

    /// The owner's writing an export made with it holds, to be kept in the user's store, or nil for
    /// an export without it. Refuses one made with it when the server keeps no user data
    /// (`canKeep` false) or its stamp does not say when it was made; and, as in phase 1, a copy
    /// whose stamp denies writing it holds, or an unstamped copy that holds some.
    static func checkWriting(_ db: SQLiteConnection, provenance: [String: String]?, canKeep: Bool) throws -> ResearchDatabaseWriting? {
        if provenance?["my_writing_included"] == "1" {
            guard let exportedAt = provenance?["exported_at"].flatMap(UserStoreDate.date) else {
                throw ImportRefusal(.checkingWriting, "The export's stamp says it includes your notes, summaries and tags, but not when it was made, so the server cannot tell them from newer copies. Export again.")
            }
            guard canKeep else {
                throw ImportRefusal(.checkingWriting, "This export includes your notes, summaries and tags, and this server keeps no research data: FRUS_USER_DATA is off. Export again with Include My Notes, Summaries, and Tags turned off.")
            }
            return try ResearchDatabaseWriting(reading: db, exportedAt: exportedAt)
        }
        if try holdsWriting(db) {
            throw ImportRefusal(.checkingWriting, provenance == nil
                ? "This copy has no export stamp and holds notes, summaries or tags, so the server cannot tell when they were written. Use Export Research Database… in FRUS Explorer's settings."
                : "The export's stamp says it excludes your writing, but it holds notes, summaries or tags. Export again.")
        }
        return nil
    }

    /// Whether the copy holds any of the owner's writing: a summary, a note or a tag on a document,
    /// or a tag's name.
    static func holdsWriting(_ db: SQLiteConnection) throws -> Bool {
        if try db.scalar("""
            SELECT EXISTS (SELECT 1 FROM document_cache
                           WHERE coalesce(summary_text, '') <> '' OR coalesce(note_text, '') <> ''
                              OR coalesce(user_tag_ids, '') <> '')
            """)?.integer == 1 {
            return true
        }
        return try db.hasObject(named: "user_tags") && db.scalar("SELECT EXISTS (SELECT 1 FROM user_tags)")?.integer == 1
    }

    /// Sorts a SQLite failure into the server's fault (disk full, I/O, permissions), which is
    /// retried, or the file's (damaged, not a database), which refuses it. `action` names the
    /// statement of the kit's strip it came from, as the kit names it.
    static func classify(_ error: SQLiteError, at step: ReadinessStep, file: String, while action: String? = nil) -> any Error {
        let during = action.map { " while \($0)" } ?? ""
        switch error.code & 0xFF {
        case SQLITE_FULL, SQLITE_IOERR, SQLITE_CANTOPEN, SQLITE_NOMEM, SQLITE_READONLY, SQLITE_PERM:
            return ImportProblem(step, "The server could not write its copy of \(file)\(during): \(error.message).")
        default:
            return ImportRefusal(step, "\(file) is damaged or is not a FRUS Explorer research export\(action == nil ? "" : ": the server's copy failed\(during)"): \(error.message).")
        }
    }

    /// `quick_check`, then FTS5's rank-1 integrity check on both full-text tables, which
    /// compares each index with its content table. The rank-1 check needs a writable connection.
    static func checkIntegrity(_ db: SQLiteConnection) throws {
        let result: [String]
        do {
            result = try db.query("PRAGMA quick_check").compactMap { $0.first?.text }
        } catch let error as SQLiteError where error.code & 0xFF == SQLITE_CORRUPT || error.code & 0xFF == SQLITE_NOTADB {
            // A damaged page can stop the check partway, as an error rather than a row.
            throw ImportRefusal(.checkingIntegrity, "The database failed SQLite's integrity check: \(error.message).")
        }
        guard result == ["ok"] else {
            throw ImportRefusal(.checkingIntegrity, "The database failed SQLite's integrity check: \(result.prefix(3).joined(separator: "; ")).")
        }
        for table in ["frus_documents", "user_content"] {
            do {
                try db.execute("INSERT INTO \(table) (\(table), rank) VALUES ('integrity-check', 1)")
            } catch let error as SQLiteError {
                throw ImportRefusal(.checkingIntegrity, "The full-text index \(table) does not match its documents: \(error.message).")
            }
        }
    }
}
