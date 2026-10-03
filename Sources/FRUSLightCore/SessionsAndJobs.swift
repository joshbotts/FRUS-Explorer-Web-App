// v1 interface 4, sessions and the job queue: small interfaces rather than files under /data.

import Foundation

/// A signed-in browser session. Phase 1 runs with `FRUS_AUTH=none` and creates none;
/// local accounts (phase 3) and header sign-in (phase 6) will.
public struct Session: Sendable, Equatable {
    public let id: String
    public let userID: String
    public let expiresAt: Date
}

public protocol SessionStore: Sendable {
    func create(for userID: String, lifetime: Duration) async -> Session
    /// The session, or nil when it is unknown or expired.
    func session(id: String) async -> Session?
    func remove(id: String) async
}

/// Sessions held in memory, lost on restart.
public actor InMemorySessionStore: SessionStore {
    private var sessions: [String: Session] = [:]
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = Date.init) { self.now = now }

    public func create(for userID: String, lifetime: Duration) -> Session {
        var generator = SystemRandomNumberGenerator()
        let id = (0..<4).map { _ in String(format: "%016llx", generator.next() as UInt64) }.joined()
        let session = Session(id: id, userID: userID,
                              expiresAt: now().addingTimeInterval(TimeInterval(lifetime.components.seconds)))
        sessions[id] = session
        return session
    }

    public func session(id: String) -> Session? {
        guard let session = sessions[id] else { return nil }
        guard session.expiresAt > now() else {
            sessions[id] = nil
            return nil
        }
        return session
    }

    public func remove(id: String) { sessions[id] = nil }
}

/// A job's progress.
public struct JobRecord: Sendable, Equatable, Codable {
    public enum State: String, Sendable, Codable { case queued, running, succeeded, failed }

    public let id: Int
    public let name: String
    public var state: State
    public var message: String?
}

/// Long-running work, such as an import, runs as a job.
public protocol JobQueue: Sendable {
    /// Queues work and returns its job id.
    func submit(_ name: String, _ work: @escaping @Sendable () async throws -> Void) async -> Int
    func record(id: Int) async -> JobRecord?
    func records() async -> [JobRecord]
}

/// Runs jobs in this process, one at a time, in the order they were submitted.
public actor InProcessJobQueue: JobQueue {
    private var jobs: [Int: JobRecord] = [:]
    private var nextID = 1
    private var tail: Task<Void, Never>?

    public init() {}

    public func submit(_ name: String, _ work: @escaping @Sendable () async throws -> Void) -> Int {
        let id = nextID
        nextID += 1
        jobs[id] = JobRecord(id: id, name: name, state: .queued, message: nil)
        let previous = tail
        tail = Task {
            await previous?.value
            self.update(id, .running, nil)
            do {
                try await work()
                self.update(id, .succeeded, nil)
            } catch {
                self.update(id, .failed, String(describing: error))
            }
        }
        return id
    }

    public func record(id: Int) -> JobRecord? { jobs[id] }

    public func records() -> [JobRecord] { jobs.values.sorted { $0.id < $1.id } }

    /// Waits until every job submitted so far has finished.
    public func waitUntilIdle() async { await tail?.value }

    private func update(_ id: Int, _ state: JobRecord.State, _ message: String?) {
        jobs[id]?.state = state
        jobs[id]?.message = message
    }
}
