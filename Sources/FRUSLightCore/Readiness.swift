// Readiness: what /readyz and /api/v1/status report while the server comes up and imports.

/// Where the server is on its way to serving an index.
public enum ReadinessStep: String, Sendable, Codable, CaseIterable {
    case waitingForExport = "waiting_for_export"
    case copyingExport = "copying_export"
    case checkingFormat = "checking_format"
    case checkingVersions = "checking_versions"
    case checkingWriting = "checking_writing"
    case checkingIntegrity = "checking_integrity"
    case installingIndex = "installing_index"
    case openingIndex = "opening_index"
    case indexVersionMismatch = "index_version_mismatch"
    case ready

    /// The steps of an import, in order.
    public static let importSteps: [ReadinessStep] = [
        .copyingExport, .checkingFormat, .checkingVersions, .checkingWriting,
        .checkingIntegrity, .installingIndex, .openingIndex,
    ]
}

/// The body of `/readyz`: 200 when `ready`, otherwise 503 naming the current step.
public struct Readiness: Sendable, Codable, Equatable {
    public var ready: Bool
    public var step: ReadinessStep
    public var detail: String
    /// 0...1 while an export is copied.
    public var progress: Double?

    public init(step: ReadinessStep, detail: String, progress: Double? = nil) {
        self.ready = step == .ready
        self.step = step
        self.detail = detail
        self.progress = progress
    }
}

/// Why an import, or the index found at start, was refused: something about the file itself.
/// Nothing changes, and the file is not tried again until it changes.
public struct ImportRefusal: Error, Sendable, Equatable, CustomStringConvertible {
    public let step: ReadinessStep
    public let reason: String

    public init(_ step: ReadinessStep, _ reason: String) {
        self.step = step
        self.reason = reason
    }

    public var description: String { reason }
}

/// A problem on the server's side, such as too little disk space or a write error, rather than
/// with the export. Nothing changes, and the file is tried again later.
public struct ImportProblem: Error, Sendable, Equatable, CustomStringConvertible {
    public let step: ReadinessStep
    public let reason: String

    public init(_ step: ReadinessStep, _ reason: String) {
        self.step = step
        self.reason = reason
    }

    public var description: String { reason }
}
