// The server's job queue (PLAN's S20d): long work, an index's import, a Mac JSON export's, the index's
// reset and, from S21c and S21d, the library's downloads and its indexing, runs as jobs, one at a time,
// in the order they were asked for. Each job is a row of the user store's `jobs` (UserJobs.swift), kept
// as it goes, so that the admin's Jobs list outlives a restart; the list itself is answered from what
// the queue holds, so that it never waits for the store while an import writes. A job is several steps:
// at each it says what it does, and a cancel asked for meanwhile stops it there, between two steps,
// never inside one. A job past the point where it can stop, as an import making its index live, says so
// (`JobContext.commit`), and a cancel is refused from then on. A job a server stopped mid-way, by a crash
// or a restart, is marked failed at its next start, before the queue takes any job: a job is the
// process's, and its work, which is code, does not outlive it.

import Foundation

/// What a job does: one part of the server's work. S21c's downloads and S21d's indexing add their kinds
/// beside these.
public struct JobKind: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    /// An export found in /data/import, checked and made the live index (Import mode).
    public static let indexImport = JobKind(rawValue: "indexImport")
    /// A Mac JSON export, imported into one user's research (PLAN's S16c).
    public static let researchImport = JobKind(rawValue: "researchImport")
    /// The served index removed in Import mode, so that the server waits for an export (S20d).
    public static let indexReset = JobKind(rawValue: "indexReset")
}

/// One job, as the queue holds it and the store keeps it.
public struct Job: Sendable, Equatable {
    public enum State: String, Sendable, Codable, CaseIterable {
        case queued, running, succeeded, failed, cancelled

        /// Whether the job has ended, one way or another.
        public var isFinished: Bool { self != .queued && self != .running }
    }

    /// A UUID, new for each job, so that an id from before a restart names no other job.
    public let id: String
    public let kind: JobKind
    /// What it works on, in the server's words: an export's file name, or nothing.
    public let subject: String?
    /// The user who asked for it, or nil for the server itself, as for an export found in /data/import.
    public let requestedBy: String?
    public var state: State
    /// A line of what it does now, or once it has finished, what it did.
    public var progress: String?
    /// How far through it is, 0 to 1, where it can tell.
    public var fraction: Double?
    public let queuedAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    /// Why it failed, in the server's words (`JobFailure`): never a key, nor anything of a user's research.
    public var error: String?
    /// Who asked it to stop, and when.
    public var cancelRequestedBy: String?
    public var cancelRequestedAt: Date?
    /// Whether a cancel is taken now: while it waits, and while it runs until it is past the point where
    /// it can stop. Never kept: a job the store gives back has ended.
    public var cancellable: Bool

    public init(id: String, kind: JobKind, subject: String?, requestedBy: String?, state: State, progress: String? = nil,
                fraction: Double? = nil, queuedAt: Date, startedAt: Date? = nil, finishedAt: Date? = nil, error: String? = nil,
                cancelRequestedBy: String? = nil, cancelRequestedAt: Date? = nil, cancellable: Bool? = nil) {
        self.id = id
        self.kind = kind
        self.subject = subject
        self.requestedBy = requestedBy
        self.state = state
        self.progress = progress
        self.fraction = fraction
        self.queuedAt = UserStoreDate.rounded(queuedAt)
        self.startedAt = startedAt.map(UserStoreDate.rounded)
        self.finishedAt = finishedAt.map(UserStoreDate.rounded)
        self.error = error
        self.cancelRequestedBy = cancelRequestedBy
        self.cancelRequestedAt = cancelRequestedAt.map(UserStoreDate.rounded)
        self.cancellable = cancellable ?? !state.isFinished
    }
}

/// An error whose sentence a job's row may keep, as its `error`: written by the server, and holding no
/// key and nothing of a user's research. A job that fails with any other error keeps
/// `Job.unexplained`, and the server's log has the error.
public protocol JobFailure: Error {
    var jobMessage: String { get }
}

extension Job {
    /// The `error` of a job that failed with an error that is no `JobFailure`.
    public static let unexplained = "It stopped at an error, which the server's log gives."
}

/// A job's failure in a sentence of the server's own.
public struct JobFailed: JobFailure, Equatable, CustomStringConvertible {
    public let jobMessage: String
    public init(_ message: String) { jobMessage = message }
    public var description: String { jobMessage }
}

/// What a job's step throws when it was asked to stop since the step before: the job ends `cancelled`.
public struct JobCancelled: Error, Equatable, CustomStringConvertible {
    public init() {}
    public var description: String { "The job was asked to stop." }
}

/// Why a cancel was refused.
public enum JobCancelRefusal: Error, Equatable {
    /// The queue holds no job of that id.
    case notFound
    /// It has ended already, in this state.
    case finished(Job.State)
    /// It is past the point where it can stop, and runs to its end.
    case committed(Job)
}

/// What a job's work reports through: the line the Jobs list shows, and the steps between which a cancel
/// stops it. S21c's downloads and S21d's indexing take one too.
public struct JobContext: Sendable {
    public let id: String
    let queue: InProcessJobQueue

    /// A step begins: throws `JobCancelled` if the job was asked to stop since the last step began, and
    /// otherwise says what it does now, and how far through the job is, where it can tell.
    public func step(_ line: String, fraction: Double? = nil) async throws {
        try await queue.step(id, line: line, fraction: fraction)
    }

    /// Says what it does now within a step, and how far through it is: a cancel waits for the next step.
    public func progress(_ line: String, fraction: Double? = nil) async {
        await queue.report(id, line: line, fraction: fraction)
    }

    /// Between steps that say nothing new: throws `JobCancelled` if the job was asked to stop.
    public func checkpoint() async throws {
        try await queue.checkpoint(id)
    }

    /// The job is past the point where it can stop, and runs to its end: throws `JobCancelled` if it was
    /// asked to stop before, and refuses a cancel from then on.
    public func commit() async throws {
        try await queue.commit(id)
    }

    /// Whether an admin has asked the job to stop: for a job whose step failed meanwhile, which then
    /// leaves what it worked on as a cancel would, rather than trying it again.
    public var cancelRequested: Bool {
        get async { await queue.isCancelRequested(id) }
    }
}

/// Where long work runs: the server's queue.
public protocol JobQueue: Sendable {
    /// Queues `work` as a job of `kind`, asked for by `requestedBy`, nil for the server itself, under
    /// `id`, a new UUID unless given, and gives it as it was queued. Its row is kept before this returns,
    /// so a store that cannot keep it refuses the job. `work` gives the line its job ends with, or nil to
    /// keep its last; `onCancel` is told when a cancel stops the job before `work` began, so that what
    /// waited for it can say so, as `work` itself does for a cancel between its steps.
    func submit(_ kind: JobKind, subject: String?, requestedBy: String?, id: String?,
                onCancel: (@Sendable () async -> Void)?,
                _ work: @escaping @Sendable (JobContext) async throws -> String?) async throws -> Job
    /// The job with this id, or nil.
    func job(_ id: String) async -> Job?
    /// Every job the queue holds, newest first: each one queued or running, and the newest it finished.
    func jobs() async -> [Job]
    /// Stops a job: one waiting at once, one running at its next step, as `user` asked.
    func cancel(_ id: String, by user: String?) async throws -> Job
}

extension JobQueue {
    /// A job that needs no word when it is cancelled before it begins.
    public func submit(_ kind: JobKind, subject: String?, requestedBy: String?, id: String?,
                       _ work: @escaping @Sendable (JobContext) async throws -> String?) async throws -> Job {
        try await submit(kind, subject: subject, requestedBy: requestedBy, id: id, onCancel: nil, work)
    }

    /// A job the server asks for itself.
    public func submit(_ kind: JobKind, subject: String? = nil,
                       _ work: @escaping @Sendable (JobContext) async throws -> String?) async throws -> Job {
        try await submit(kind, subject: subject, requestedBy: nil, id: nil, onCancel: nil, work)
    }
}

/// Runs jobs in this process, one at a time, in the order they were queued, keeping each as a row of
/// `store` as it goes; with no store, as a test's, it keeps them in memory alone.
public actor InProcessJobQueue: JobQueue {
    public typealias Work = @Sendable (JobContext) async throws -> String?

    private struct Entry {
        var job: Job
        var work: Work?
        var onCancel: (@Sendable () async -> Void)?
        /// Past the point where it can stop (`JobContext.commit`).
        var committed = false
        /// The progress line last written to the store, and when, so that a job reporting often is
        /// written at most once a second unless its line changes.
        var written: (line: String?, at: Date)?
    }

    private let store: (any JobStore)?
    private let now: @Sendable () -> Date
    private let log: @Sendable (String) -> Void
    private var entries: [String: Entry] = [:]
    /// Every id the queue holds, in the order they were queued.
    private var order: [String] = []
    /// The jobs waiting, in the order they were queued.
    private var waiting: [String] = []
    private var running: String?
    /// The ids of jobs whose rows are being kept, not yet in the line: no second job takes one.
    private var reserved: Set<String> = []
    private var idle: [CheckedContinuation<Void, Never>] = []

    /// How many finished jobs are kept, the oldest forgotten first, here and in the store.
    public static let kept = 100
    /// How often a job's progress within one line is written to the store, at most.
    static let writeInterval: TimeInterval = 1

    /// A queue that keeps its jobs in memory alone.
    public init(now: @escaping @Sendable () -> Date = Date.init, log: @escaping @Sendable (String) -> Void = { _ in }) {
        store = nil
        self.now = now
        self.log = log
    }

    private init(store: any JobStore, jobs: [Job], now: @escaping @Sendable () -> Date, log: @escaping @Sendable (String) -> Void) {
        self.store = store
        self.now = now
        self.log = log
        for job in jobs.reversed() {
            entries[job.id] = Entry(job: job)
            order.append(job.id)
        }
    }

    /// The queue over `store`, opened at a start before any job is queued: every job a server stopped
    /// before it finished is marked failed, and the newest it keeps are the list's.
    public static func open(store: any JobStore, now: @escaping @Sendable () -> Date = Date.init,
                            log: @escaping @Sendable (String) -> Void = { _ in }) async throws -> InProcessJobQueue {
        let time = now()
        let (stopped, jobs) = try await Blocking.run { (try store.failUnfinishedJobs(at: time), try store.jobs(limit: kept)) }
        if stopped > 0 {
            log(stopped == 1 ? "1 job the server stopped before it finished was marked failed"
                : "\(stopped) jobs the server stopped before they finished were marked failed")
        }
        return InProcessJobQueue(store: store, jobs: jobs, now: now, log: log)
    }

    // MARK: JobQueue

    public func submit(_ kind: JobKind, subject: String?, requestedBy: String?, id: String?,
                       onCancel: (@Sendable () async -> Void)?, _ work: @escaping Work) async throws -> Job {
        let job = Job(id: id ?? UUID().uuidString, kind: kind, subject: subject, requestedBy: requestedBy, state: .queued,
                      queuedAt: now())
        guard entries[job.id] == nil, reserved.insert(job.id).inserted else {
            throw JobFailed("A job with the id \(job.id) is queued already.")
        }
        defer { reserved.remove(job.id) }
        if let store { try await Blocking.run { try store.saveJob(job) } }
        entries[job.id] = Entry(job: job, work: work, onCancel: onCancel, written: (nil, now()))
        order.append(job.id)
        waiting.append(job.id)
        startNext()
        return job
    }

    public func job(_ id: String) -> Job? { entries[id]?.job }

    public func jobs() -> [Job] { order.reversed().compactMap { entries[$0]?.job } }

    public func cancel(_ id: String, by user: String?) async throws -> Job {
        guard var entry = entries[id] else { throw JobCancelRefusal.notFound }
        switch entry.job.state {
        case .queued:
            // It never runs: it leaves the line at once, and its work with it.
            let time = now()
            waiting.removeAll { $0 == id }
            entry.job.state = .cancelled
            entry.job.finishedAt = UserStoreDate.rounded(time)
            entry.job.cancelRequestedBy = user
            entry.job.cancelRequestedAt = UserStoreDate.rounded(time)
            entry.job.cancellable = false
            let told = entry.onCancel
            entry.work = nil
            entry.onCancel = nil
            entries[id] = entry
            await persist(id)
            await told?()
            await prune()
            resumeIdleWaiters()
            return entries[id]?.job ?? entry.job
        case .running:
            guard !entry.committed else { throw JobCancelRefusal.committed(entry.job) }
            // The job stops at its next step; the request is kept with it once it has.
            if entry.job.cancelRequestedAt == nil {
                entry.job.cancelRequestedBy = user
                entry.job.cancelRequestedAt = UserStoreDate.rounded(now())
                entries[id] = entry
            }
            return entry.job
        case .succeeded, .failed, .cancelled:
            throw JobCancelRefusal.finished(entry.job.state)
        }
    }

    /// Waits until no job is queued or running: the tests' way to wait for what they queued.
    public func waitUntilIdle() async {
        guard running != nil || !waiting.isEmpty else { return }
        await withCheckedContinuation { idle.append($0) }
    }

    // MARK: What a job reports

    func step(_ id: String, line: String, fraction: Double?) async throws {
        try checkpoint(id)
        await report(id, line: line, fraction: fraction)
    }

    func isCancelRequested(_ id: String) -> Bool { entries[id]?.job.cancelRequestedAt != nil }

    func checkpoint(_ id: String) throws {
        guard let entry = entries[id] else { return }
        if entry.job.cancelRequestedAt != nil, !entry.committed { throw JobCancelled() }
    }

    func commit(_ id: String) throws {
        try checkpoint(id)
        entries[id]?.committed = true
        entries[id]?.job.cancellable = false
    }

    func report(_ id: String, line: String, fraction: Double?) async {
        guard var entry = entries[id], entry.job.state == .running else { return }
        entry.job.progress = line
        entry.job.fraction = fraction.map { min(1, max(0, $0)) }
        entries[id] = entry
        let time = now()
        if let written = entry.written, written.line == line, time.timeIntervalSince(written.at) < Self.writeInterval { return }
        await persist(id)
    }

    // MARK: Running

    /// Starts the job first in line, unless one runs.
    private func startNext() {
        guard running == nil, !waiting.isEmpty else { return }
        let id = waiting.removeFirst()
        running = id
        entries[id]?.job.state = .running
        entries[id]?.job.startedAt = UserStoreDate.rounded(now())
        Task { await self.run(id) }
    }

    private func run(_ id: String) async {
        await persist(id)
        let outcome: Result<String?, any Error>
        if let work = entries[id]?.work {
            let context = JobContext(id: id, queue: self)
            do {
                outcome = .success(try await work(context))
            } catch {
                outcome = .failure(error)
            }
        } else {
            outcome = .failure(JobFailed("The job had no work to run."))
        }
        entries[id]?.onCancel = nil
        finish(id, outcome)
        await persist(id)
        await prune()
        running = nil
        startNext()
        resumeIdleWaiters()
    }

    private func finish(_ id: String, _ outcome: Result<String?, any Error>) {
        guard var entry = entries[id] else { return }
        entry.job.finishedAt = UserStoreDate.rounded(now())
        entry.job.cancellable = false
        entry.work = nil
        switch outcome {
        case .success(let line):
            entry.job.state = .succeeded
            if let line { entry.job.progress = line }
            if entry.job.fraction != nil { entry.job.fraction = 1 }
        case .failure(let error) where error is JobCancelled:
            entry.job.state = .cancelled
        case .failure(let error):
            entry.job.state = .failed
            if let failure = error as? any JobFailure {
                entry.job.error = failure.jobMessage
            } else {
                entry.job.error = Job.unexplained
                log("The job \(id) (\(entry.job.kind.rawValue)) failed: \(error)")
            }
        }
        entries[id] = entry
    }

    /// Writes the job as it is now to the store. A write that fails leaves the queue as it is: its list
    /// stays right, and a row left running is marked failed at the next start.
    private func persist(_ id: String) async {
        guard let store, let job = entries[id]?.job else { return }
        entries[id]?.written = (job.progress, now())
        do {
            try await Blocking.run { try store.saveJob(job) }
        } catch {
            log("The job \(id)'s row could not be written to the user store: \(error)")
        }
    }

    /// Forgets the finished jobs past the newest `kept`, here and in the store.
    private func prune() async {
        let finished = order.filter { entries[$0]?.job.state.isFinished == true }
        let forgotten = Set(finished.dropLast(Self.kept))
        if !forgotten.isEmpty {
            for id in forgotten { entries[id] = nil }
            order.removeAll { forgotten.contains($0) }
        }
        guard let store, finished.count > Self.kept else { return }
        do {
            try await Blocking.run { try store.pruneJobs(keeping: Self.kept) }
        } catch {
            log("The user store's finished jobs could not be pruned: \(error)")
        }
    }

    private func resumeIdleWaiters() {
        guard running == nil, waiting.isEmpty else { return }
        let waiters = idle
        idle = []
        for waiter in waiters { waiter.resume() }
    }
}
