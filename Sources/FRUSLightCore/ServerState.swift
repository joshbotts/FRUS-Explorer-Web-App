// The server's state as /readyz and /api/v1/status report it.

import Foundation

/// How an import ended.
public struct ImportReport: Sendable, Equatable, Codable {
    /// `cancelled` when an admin stopped it between two of its steps (PLAN's S20d).
    public enum Outcome: String, Sendable, Codable { case installed, refused, failed, cancelled }

    public var file: String
    public var outcome: Outcome
    /// The step that refused or failed; nil when installed.
    public var step: ReadinessStep?
    public var message: String
    public var finishedAt: String
    /// For an export made with the owner's writing, what the user's store made of it (S16e), which
    /// the message says in words; nil for one without it.
    public var writing: MovedWriting?
}

/// An import under way.
public struct ImportProgress: Sendable, Equatable, Codable {
    public var file: String
    public var step: ReadinessStep
    public var detail: String
    public var progress: Double?
}

/// The body of `/api/v1/status`.
public struct ServerStatus: Sendable, Equatable, Codable {
    public var version: String
    public var mode: ServerConfiguration.Mode
    public var auth: ServerConfiguration.Auth
    public var supportedIndexVersion: Int
    public var ftsSchemaVersion: Int
    public var sqliteVersion: String
    public var startedAt: String
    public var readiness: Readiness
    public var index: IndexSummary?
    public var importInProgress: ImportProgress?
    public var lastImport: ImportReport?
}

public actor ServerState: ImportObserver {
    public nonisolated let configuration: ServerConfiguration
    /// The PDF service `FRUS_PDF_URL` names (PLAN's S25a), none when it is unset, which hides PDF.
    public nonisolated let pdf: PDFService?
    private let startedAt = Date()
    public private(set) var index: CorpusIndex?
    private var importing: ImportProgress?
    private var lastImport: ImportReport?
    /// Why the index found at start cannot be served, such as a version from before an upgrade.
    private var startupProblem: ImportRefusal?
    /// Set while the index found at start is opened and counted.
    private var openingAtStart = false
    /// Files in the drop zone still being copied.
    private var stillCopying: [String] = []
    /// Moved each time an import makes a new index live, and by each reset (PLAN's S20d): a reset asked
    /// for at one removes nothing an import installed after it, and an index the start was opening when
    /// a reset removed it is not served.
    public private(set) var indexGeneration = 0
    private let log: @Sendable (String) -> Void

    public init(configuration: ServerConfiguration, log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.configuration = configuration
        pdf = configuration.pdfURL.flatMap { PDFService(url: $0, log: log) }
        self.log = log
    }

    /// Marks that an index found at start is about to be opened, so `/readyz` says so meanwhile.
    public func prepareToOpenExistingIndex(files: any FileStore) {
        openingAtStart = FileManager.default.fileExists(atPath: files.liveIndex.path)
    }

    /// Opens the live index if there is one, off the cooperative pool. A restart copies nothing.
    public func openExistingIndex(files: any FileStore) async {
        defer { openingAtStart = false }
        let live = files.liveIndex
        guard FileManager.default.fileExists(atPath: live.path) else { return }
        openingAtStart = true
        let generation = indexGeneration
        do {
            let opened = try await Blocking.run { try CorpusIndex.open(live) }
            // A reset that removed the file while it opened wins: the server waits for an export.
            guard indexGeneration == generation else {
                log("Not serving \(live.path): the index was reset while it was opened")
                return
            }
            if index == nil { index = opened }
            startupProblem = nil
            log("Serving \(opened.summary.documents) documents from \(opened.summary.volumes) volumes, index version \(opened.summary.indexVersion)")
        } catch let refusal as ImportRefusal {
            startupProblem = refusal
            log("Not serving \(live.path): \(refusal.reason)")
        } catch {
            startupProblem = ImportRefusal(.openingIndex, "The index could not be opened: \(error)")
            log("Not serving \(live.path): \(error)")
        }
    }

    /// Records the drop-zone files that are still arriving.
    func setStillCopying(_ files: [String]) { stillCopying = files }

    public func readiness() -> Readiness {
        if let index {
            let s = index.summary
            return Readiness(step: .ready, detail: "Serving \(s.documents) documents from \(s.volumes) volumes, index version \(s.indexVersion)")
        }
        if let importing {
            return Readiness(step: importing.step, detail: importing.detail, progress: importing.progress)
        }
        if openingAtStart {
            return Readiness(step: .openingIndex, detail: "Opening the index found at start")
        }
        if let startupProblem {
            return Readiness(step: startupProblem.step, detail: startupProblem.reason)
        }
        var detail = "Copy a FRUS Explorer research export into /data/import, for example with: docker compose cp <export file> frus:/data/import/"
        if !stillCopying.isEmpty {
            detail = "Waiting for \(stillCopying.joined(separator: ", ")) to finish copying into /data/import"
        } else if let lastImport {
            switch lastImport.outcome {
            case .refused: detail += ". The last file, \(lastImport.file), was refused: \(lastImport.message)"
            case .failed: detail += ". The last file, \(lastImport.file), could not be imported and will be tried again: \(lastImport.message)"
            case .cancelled: detail += ". The import of the last file, \(lastImport.file), was stopped by an admin"
            case .installed: break
            }
        }
        return Readiness(step: .waitingForExport, detail: detail)
    }

    public func status() -> ServerStatus {
        ServerStatus(
            version: FRUSLightVersion.string,
            mode: configuration.mode,
            auth: configuration.auth,
            supportedIndexVersion: IndexCompatibility.supportedIndexVersion,
            ftsSchemaVersion: IndexCompatibility.ftsSchemaVersion,
            sqliteVersion: SQLiteConnection.libraryVersion,
            startedAt: Self.timestamp(startedAt),
            readiness: readiness(),
            index: index?.summary,
            importInProgress: importing,
            lastImport: lastImport)
    }

    // MARK: Import progress

    func importStarted(file: String) {
        importing = ImportProgress(file: file, step: .copyingExport, detail: "Copying \(file)", progress: 0)
        log("Importing \(file)")
    }

    public func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) {
        let isNewStep = importing?.step != step
        importing?.step = step
        importing?.detail = detail
        importing?.progress = progress
        if isNewStep { log("Import: \(step.rawValue)") }
    }

    /// `writing` is what the user's store made of the owner's writing an export held, and `note`
    /// reports a loose end, such as a drop file that could not be removed. Gives the report's message.
    @discardableResult
    func importFinished(file: String, index newIndex: CorpusIndex, writing: MovedWriting? = nil, note: String? = nil) -> String {
        index = newIndex
        indexGeneration += 1
        importing = nil
        startupProblem = nil
        let s = newIndex.summary
        var message = "Installed \(s.documents) documents from \(s.volumes) volumes, index version \(s.indexVersion)"
        if let writing { message += ". \(writing.report)" }
        if let note { message += "\(writing == nil ? "." : "") \(note)" }
        lastImport = ImportReport(file: file, outcome: .installed, step: nil, message: message,
                                  finishedAt: Self.timestamp(Date()), writing: writing)
        log(message)
        return message
    }

    /// An admin stopped the import between two of its steps (PLAN's S20d): nothing changed.
    func importCancelled(file: String) {
        let message = "An admin stopped the import of \(file) before it changed anything. It is tried again once the file in /data/import changes, or the server restarts"
        lastImport = ImportReport(file: file, outcome: .cancelled, step: importing?.step, message: message,
                                  finishedAt: Self.timestamp(Date()))
        importing = nil
        log(message)
    }

    func importFailed(file: String, error: any Error) {
        let outcome: ImportReport.Outcome
        let step: ReadinessStep?
        let message: String
        switch error {
        case let refusal as ImportRefusal:
            (outcome, step, message) = (.refused, refusal.step, refusal.reason)
        case let problem as ImportProblem:
            (outcome, step, message) = (.failed, problem.step, problem.reason)
            if let logged = problem.logged { log("Import of \(file): \(logged)") }
        default:
            (outcome, step, message) = (.failed, importing?.step, error.localizedDescription)
        }
        lastImport = ImportReport(file: file, outcome: outcome, step: step, message: message,
                                  finishedAt: Self.timestamp(Date()))
        importing = nil
        log("Import of \(file) \(outcome.rawValue): \(message)")
    }

    /// The recovery action that resets the index in Import mode (PLAN's S20d): the server stops serving
    /// its index and removes it, with the index an import kept before it and any copy one left, and then
    /// waits for an export in /data/import, as at its first start. A request that holds the index
    /// finishes on it, as on an index an import replaced. `generation` is `indexGeneration` when the
    /// reset was asked for: an import that made a new index live since is not undone, and the reset is
    /// refused. An import queued meanwhile keeps its line in `/readyz`. Gives what the index held, or nil
    /// when none was served.
    public func resetIndex(files: any FileStore, askedAt generation: Int) async throws -> IndexSummary? {
        guard indexGeneration == generation else {
            throw IndexResetRefusal()
        }
        indexGeneration += 1
        let removed = index?.summary
        index = nil
        lastImport = nil
        startupProblem = nil
        let paths = [files.liveIndex, files.previousIndex, files.candidateIndex].flatMap { url in
            ["", "-wal", "-shm", "-journal"].map { url.path + $0 }
        }
        try await Blocking.run {
            for path in paths where FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        }
        log(removed.map { "Removed the served index of \($0.documents) documents from \($0.volumes) volumes: waiting for an export" }
            ?? "No index was served; any left on disk was removed: waiting for an export")
        return removed
    }

    /// An export already live was found in the drop zone again, for example after a restart
    /// that came between installing it and removing it.
    func importSkipped(file: String, note: String) {
        importing = nil
        log("\(file) is the index already being served; \(note)")
    }

    static func timestamp(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}

/// A reset refused because an import made a new index live after it was asked for (PLAN's S20d).
public struct IndexResetRefusal: JobFailure, Equatable {
    public init() {}
    public var jobMessage: String {
        "An import made a new index live after the reset was asked for, so nothing was removed: ask for the reset again to remove that index."
    }
}
