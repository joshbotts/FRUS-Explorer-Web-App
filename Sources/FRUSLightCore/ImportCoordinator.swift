// Watches /data/import for a finished export and imports it as a job.

import Foundation

/// Finds exports dropped into the import directory and imports them, one at a time.
///
/// `docker compose cp` makes a file visible under its final name while it is still being
/// written, so a file is imported only once it has stopped changing between two looks, and,
/// for a SQLite file whose header records its size, once it has reached that size.
///
/// A file is not tried again while it is unchanged once it has been installed, or refused for
/// something about the file itself. A problem on the server's side, such as a full disk, is
/// tried again after `retryDelay`.
public actor ImportCoordinator {
    struct Signature: Equatable {
        let size: Int64
        let modified: Date
    }

    private let files: any FileStore
    private let importer: IndexImporter
    private let state: ServerState
    private let jobs: any JobQueue
    private let alsoNotify: (any ImportObserver)?
    private let retryDelay: Duration
    private let now: @Sendable () -> Date
    private let removeFile: @Sendable (URL) throws -> Void
    private let isReadable: @Sendable (String) -> Bool
    private var lastLook: [String: Signature] = [:]
    /// Installed or refused, and unchanged since.
    private var settled: [String: Signature] = [:]
    /// Failed for a server-side reason: not before this time while unchanged.
    private var retryAfter: [String: (Signature, Date)] = [:]
    private var busy = false

    /// `alsoNotify` hears each import step after the server state has, so a test can see what
    /// `/readyz` reports at every step. `removeFile`, `isReadable` and `now` are replaceable for tests.
    public init(files: any FileStore, importer: IndexImporter, state: ServerState, jobs: any JobQueue,
                alsoNotify: (any ImportObserver)? = nil, retryDelay: Duration = .seconds(60),
                now: @escaping @Sendable () -> Date = Date.init,
                removeFile: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) },
                isReadable: @escaping @Sendable (String) -> Bool = { FileManager.default.isReadableFile(atPath: $0) }) {
        self.files = files
        self.importer = importer
        self.state = state
        self.jobs = jobs
        self.alsoNotify = alsoNotify
        self.retryDelay = retryDelay
        self.now = now
        self.removeFile = removeFile
        self.isReadable = isReadable
    }

    /// Looks once, and starts an import if a file is ready. Returns the job id it started.
    @discardableResult
    public func scan() async -> Int? {
        guard !busy else { return nil }
        let present = candidates()
        lastLook = lastLook.filter { present[$0.key] != nil }
        settled = settled.filter { present[$0.key] == $0.value }
        retryAfter = retryAfter.filter { present[$0.key] == $0.value.0 }

        var ready: URL?
        var stillCopying: [String] = []
        for (path, signature) in present.sorted(by: { $0.key < $1.key }) {
            defer { lastLook[path] = signature }
            if settled[path] == signature { continue }
            if let retry = retryAfter[path], now() < retry.1 { continue }
            let url = URL(fileURLWithPath: path)
            // Refused before anything follows the link: a dangling one would read as unreadable.
            if ExportChecks.isSymbolicLink(url) {
                settled[path] = signature
                await state.importFailed(file: url.lastPathComponent, error: ExportChecks.linkRefusal(url.lastPathComponent))
                continue
            }
            // `docker compose cp` keeps the file's mode, so a 0600 export arrives unreadable.
            guard isReadable(path) else {
                await reportUnreadable(url, signature: signature)
                continue
            }
            guard lastLook[path] == signature, Self.isComplete(url, size: signature.size) else {
                stillCopying.append(url.lastPathComponent)
                continue
            }
            if ready == nil { ready = url }
        }
        await state.setStillCopying(stillCopying)
        guard let file = ready, let signature = present[file.path] else { return nil }

        if await isAlreadyLive(file, size: signature.size) {
            let note: String
            do {
                try removeFile(file)
                note = "removed it from the drop zone"
            } catch {
                note = "it could not be removed from the drop zone: \(error.localizedDescription)"
            }
            settled[file.path] = signature
            await state.importSkipped(file: file.lastPathComponent, note: note)
            return nil
        }

        busy = true
        await state.importStarted(file: file.lastPathComponent)
        let observer = StateThenOthers(state: state, others: alsoNotify)
        return await jobs.submit("import \(file.lastPathComponent)") { [importer, state, removeFile] in
            do {
                let index = try await importer.importExport(at: file, observer: observer)
                var note: String?
                do { try removeFile(file) } catch {
                    note = "The file could not be removed from /data/import: \(error.localizedDescription)"
                }
                await state.importFinished(file: file.lastPathComponent, index: index, note: note)
                await self.finished(file: file, signature: signature, retry: false)
            } catch {
                await state.importFailed(file: file.lastPathComponent, error: error)
                await self.finished(file: file, signature: signature, retry: !(error is ImportRefusal))
                throw error
            }
        }
    }

    /// Reports a file the server cannot read, as a server-side problem tried again later:
    /// changing its permissions does not change its size or modification time.
    private func reportUnreadable(_ file: URL, signature: Signature) async {
        let name = file.lastPathComponent
        let problem = ImportProblem(.copyingExport, "The server cannot read \(name): its permissions keep it from the server's user. Copy it again with docker compose cp -a, which gives it to that user; it is tried again within a minute")
        await state.importFailed(file: name, error: problem)
        retryAfter[file.path] = (signature, now().addingTimeInterval(Self.seconds(retryDelay)))
    }

    private func finished(file: URL, signature: Signature, retry: Bool) {
        if retry {
            retryAfter[file.path] = (signature, now().addingTimeInterval(Self.seconds(retryDelay)))
        } else {
            settled[file.path] = signature
        }
        busy = false
    }

    /// Whether the file is the export the live index came from: same export time and size.
    private func isAlreadyLive(_ file: URL, size: Int64) async -> Bool {
        guard let live = await state.index,
              let liveExportedAt = live.summary.exportedAt,
              IndexImporter.size(of: live.url) == size else { return false }
        let exportedAt = try? await Blocking.run { () -> String? in
            let db = try SQLiteConnection.immutable(file)
            defer { db.close() }
            return try ExportChecks.provenance(db)?["exported_at"]
        }
        return exportedAt == liveExportedAt
    }

    /// Regular files and symbolic links in the import directory, visible and other than SQLite's
    /// side files. Their attributes are their own, never a link's target's, so a link is seen as
    /// a link (and refused) on Linux and macOS alike.
    private func candidates() -> [String: Signature] {
        let directory = files.importDirectory
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [:] }
        var found: [String: Signature] = [:]
        for url in urls {
            let name = url.lastPathComponent
            guard !["-journal", "-wal", "-shm"].contains(where: name.hasSuffix),
                  let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let type = attributes[.type] as? FileAttributeType,
                  type == .typeRegular || type == .typeSymbolicLink,
                  let size = (attributes[.size] as? NSNumber)?.int64Value, size > 0 else { continue }
            found[url.standardizedFileURL.path] = Signature(size: size, modified: attributes[.modificationDate] as? Date ?? .distantPast)
        }
        return found
    }

    /// Whether a SQLite file has reached the size its header records. The header's page count
    /// is trusted only when it is valid (offset 92 equals the change counter at offset 24); a
    /// file that is not SQLite counts as complete, so the import can refuse it with a reason.
    static func isComplete(_ url: URL, size: Int64) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 100), header.count == 100,
              header.prefix(16) == Data("SQLite format 3\0".utf8) else { return true }
        func uint32(_ offset: Int) -> UInt32 { header[offset..<offset + 4].reduce(0) { $0 << 8 | UInt32($1) } }
        let rawPageSize = UInt32(header[16]) << 8 | UInt32(header[17])
        let pageSize = Int64(rawPageSize == 1 ? 65_536 : rawPageSize)
        let pageCount = Int64(uint32(28))
        guard pageCount > 0, uint32(92) == uint32(24) else { return true }
        return size == pageSize * pageCount
    }

    private static func seconds(_ duration: Duration) -> TimeInterval {
        let (seconds, attoseconds) = duration.components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}

/// Updates the server state first, then any other observer.
private struct StateThenOthers: ImportObserver {
    let state: ServerState
    let others: (any ImportObserver)?

    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) async {
        await state.importDidReach(step, detail: detail, progress: progress)
        await others?.importDidReach(step, detail: detail, progress: progress)
    }
}
