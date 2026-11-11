// The server's jobs (PLAN's S20d), migration 6's `jobs` table: each job the queue runs is a row, kept
// as it goes, so that the admin's Jobs list outlives a restart, and a job a server stopped mid-way is
// marked failed at its next start. Each method is written once, on `RelationalUserStore`, in SQL both
// stores read; each write changes nothing the kit's search reads, so none moves the search mark.

import Foundation

/// Where the queue keeps its jobs: the user store's `jobs` (PLAN's S20d).
public protocol JobStore: Sendable {
    /// Keeps `job` as it is now: a new job's row, or the row of one the store holds, replaced whole.
    func saveJob(_ job: Job) throws
    /// Marks every job still queued or running failed at `time`, since the server that held it has
    /// stopped: a job is the process's, and none outlives it. Gives how many it marked.
    func failUnfinishedJobs(at time: Date) throws -> Int
    /// The newest `limit` jobs, by when they were queued, newest first.
    func jobs(limit: Int) throws -> [Job]
    /// Removes every finished job but the newest `kept`, by when they finished.
    func pruneJobs(keeping kept: Int) throws
}

extension RelationalUserStore: JobStore {
    private static let jobColumns = """
        job_id, kind, subject, state, progress, fraction, requested_by, queued_at, started_at, finished_at, error,
        cancel_requested_by, cancel_requested_at
        """

    /// The sentences a job a server stopped is left with.
    static let stoppedBeforeItBegan = "The server stopped before this job began."
    static let stoppedWhileItRan = "The server stopped while this job ran, so it did not finish."

    private static func text(_ value: String?) -> SQLiteValue { value.map(SQLiteValue.text) ?? .null }
    private static func date(_ value: Date?) -> SQLiteValue { value.map { .text(UserStoreDate.text($0)) } ?? .null }

    public func saveJob(_ job: Job) throws {
        let values: [SQLiteValue] = [
            .text(job.id), .text(job.kind.rawValue), Self.text(job.subject), .text(job.state.rawValue), Self.text(job.progress),
            job.fraction.map(SQLiteValue.real) ?? .null, Self.text(job.requestedBy), Self.date(job.queuedAt), Self.date(job.startedAt),
            Self.date(job.finishedAt), Self.text(job.error), Self.text(job.cancelRequestedBy), Self.date(job.cancelRequestedAt),
        ]
        try writing(outsideSearch: true) { db in
            _ = try db.query(
                """
                INSERT INTO jobs (\(Self.jobColumns)) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (job_id) DO UPDATE SET kind = excluded.kind, subject = excluded.subject, state = excluded.state,
                    progress = excluded.progress, fraction = excluded.fraction, requested_by = excluded.requested_by,
                    queued_at = excluded.queued_at, started_at = excluded.started_at, finished_at = excluded.finished_at,
                    error = excluded.error, cancel_requested_by = excluded.cancel_requested_by,
                    cancel_requested_at = excluded.cancel_requested_at
                """, values)
        }
    }

    public func failUnfinishedJobs(at time: Date) throws -> Int {
        try writing(outsideSearch: true) { db in
            let unfinished = Int(try db.scalar("SELECT count(*) FROM jobs WHERE state IN ('queued', 'running')", [])?.integer ?? 0)
            for (state, sentence) in [("queued", Self.stoppedBeforeItBegan), ("running", Self.stoppedWhileItRan)] {
                _ = try db.query("UPDATE jobs SET state = 'failed', finished_at = ?, error = ? WHERE state = ?",
                                 [Self.date(time), .text(sentence), .text(state)])
            }
            return unfinished
        }
    }

    public func jobs(limit: Int) throws -> [Job] {
        try reading { db in
            try db.query("SELECT \(Self.jobColumns) FROM jobs ORDER BY queued_at DESC, job_id DESC LIMIT ?",
                         [.integer(Int64(limit))]).map(Self.job)
        }
    }

    public func pruneJobs(keeping kept: Int) throws {
        try writing(outsideSearch: true) { db in
            _ = try db.query(
                """
                DELETE FROM jobs WHERE state IN ('succeeded', 'failed', 'cancelled') AND job_id NOT IN (
                    SELECT job_id FROM jobs WHERE state IN ('succeeded', 'failed', 'cancelled')
                        ORDER BY finished_at DESC, job_id DESC LIMIT ?)
                """, [.integer(Int64(kept))])
        }
    }

    /// A REAL as SQLite or PostgreSQL gives it back, or nil for NULL.
    private static func real(_ value: SQLiteValue) -> Double? {
        switch value {
        case .real(let real): real
        case .integer(let integer): Double(integer)
        case .text(let text): Double(text)
        case .null, .blob: nil
        }
    }

    private static func job(_ row: [SQLiteValue]) -> Job {
        let state = row[3].text.flatMap(Job.State.init(rawValue:)) ?? .failed
        return Job(id: row[0].text ?? "", kind: JobKind(rawValue: row[1].text ?? ""), subject: row[2].text,
                   requestedBy: row[6].text, state: state, progress: row[4].text, fraction: Self.real(row[5]),
                   queuedAt: row[7].text.flatMap(UserStoreDate.date) ?? Date(timeIntervalSince1970: 0),
                   startedAt: row[8].text.flatMap(UserStoreDate.date), finishedAt: row[9].text.flatMap(UserStoreDate.date),
                   error: row[10].text, cancelRequestedBy: row[11].text,
                   cancelRequestedAt: row[12].text.flatMap(UserStoreDate.date))
    }
}
