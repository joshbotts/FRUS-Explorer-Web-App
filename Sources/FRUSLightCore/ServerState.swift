// The server's state as /readyz and /api/v1/status report it.

import Foundation

/// How an import ended.
public struct ImportReport: Sendable, Equatable, Codable {
    public enum Outcome: String, Sendable, Codable { case installed, refused, failed }

    public var file: String
    public var outcome: Outcome
    /// The step that refused or failed; nil when installed.
    public var step: ReadinessStep?
    public var message: String
    public var finishedAt: String
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
    public let configuration: ServerConfiguration
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
    private let log: @Sendable (String) -> Void

    public init(configuration: ServerConfiguration, log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.configuration = configuration
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
        do {
            let opened = try await Blocking.run { try CorpusIndex.open(live) }
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

    /// `note` reports a loose end, such as a drop file that could not be removed.
    func importFinished(file: String, index newIndex: CorpusIndex, note: String? = nil) {
        index = newIndex
        importing = nil
        startupProblem = nil
        let s = newIndex.summary
        var message = "Installed \(s.documents) documents from \(s.volumes) volumes, index version \(s.indexVersion)"
        if let note { message += ". \(note)" }
        lastImport = ImportReport(file: file, outcome: .installed, step: nil, message: message,
                                  finishedAt: Self.timestamp(Date()))
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
        default:
            (outcome, step, message) = (.failed, importing?.step, error.localizedDescription)
        }
        lastImport = ImportReport(file: file, outcome: outcome, step: step, message: message,
                                  finishedAt: Self.timestamp(Date()))
        importing = nil
        log("Import of \(file) \(outcome.rawValue): \(message)")
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
