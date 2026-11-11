// The server's job queue (PLAN's S20d): one job at a time, in the order queued, each a row of the user
// store kept as it goes; a cancel between steps, refused once a job is past the point where it can
// stop; a job a stopped server left marked failed at the next start, and a finished one kept across
// it. The store's methods are the conformance suite's, on every store `UserStoreKind.available` names.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Synchronization
import Testing

/// A clock a test moves by hand.
final class JobClock: Sendable {
    private let time = Mutex(Date(timeIntervalSince1970: 1_792_800_000))  // 2026-10-24T00:00:00Z
    var now: Date { time.withLock { $0 } }
    func advance(by seconds: TimeInterval) { time.withLock { $0 = $0.addingTimeInterval(seconds) } }
}

@Suite struct JobQueueTests {
    static func stored(_ rows: UserStoreRows, _ id: String) throws -> [SQLiteValue] {
        try rows.stored("SELECT kind, subject, state, progress, requested_by, error, cancel_requested_by FROM jobs WHERE job_id = ?",
                        [.text(id)]).first ?? []
    }

    /// The queue runs one job at a time, in the order queued, each kept as a row as it goes: queued,
    /// running with its line, and finished with what it did.
    @Test(arguments: UserStoreKind.available)
    func jobsRunOneAtATimeAndEachIsARowAsItGoes(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let clock = JobClock()
        let queue = try await InProcessJobQueue.open(store: store, now: { clock.now })
        let gate = JobGate()
        let first = try await queue.submit(.indexImport, subject: "export.sqlite", requestedBy: nil, id: nil) { job in
            try await job.step("Copying export.sqlite", fraction: 0)
            await gate.wait()
            return "Installed 3 documents"
        }
        clock.advance(by: 1)
        let second = try await queue.submit(.researchImport, subject: "A Mac JSON export, format 7", requestedBy: "alice", id: nil) { _ in
            nil
        }
        #expect(first.state == .queued && first.cancellable && second.requestedBy == "alice")
        await gate.untilReached()
        let started = await queue.job(first.id)
        #expect(started?.state == .running && started?.progress == "Copying export.sqlite")
        #expect(await queue.job(second.id)?.state == .queued, "one at a time")
        #expect(try Self.stored(rows, first.id) == [.text("indexImport"), .text("export.sqlite"), .text("running"),
                                                     .text("Copying export.sqlite"), .null, .null, .null])
        #expect(try Self.stored(rows, second.id)[2] == .text("queued"))
        clock.advance(by: 2)
        gate.open()
        await queue.waitUntilIdle()
        let done = try #require(await queue.job(first.id))
        #expect(done.state == .succeeded && done.progress == "Installed 3 documents" && done.fraction == 1 && !done.cancellable)
        #expect(done.startedAt == UserDataTimes.at(clock, -3) && done.finishedAt == clock.now)
        let next = try #require(await queue.job(second.id))
        #expect(next.state == .succeeded && next.startedAt.map { $0 >= done.finishedAt! } == true, "the second after the first")
        #expect(try Self.stored(rows, first.id) == [.text("indexImport"), .text("export.sqlite"), .text("succeeded"),
                                                     .text("Installed 3 documents"), .null, .null, .null])
        #expect(try store.jobs(limit: 10).map(\.id) == [second.id, first.id], "newest first")
        #expect(try store.jobs(limit: 10).first { $0.id == first.id } == done.withCancellable(false))
    }

    /// A job waiting is cancelled at once and never runs; one running stops at its next step, with the
    /// line of the step it finished, and who asked; one past the point where it can stop is refused, and
    /// runs to its end; one finished, or unknown, is refused.
    @Test(arguments: UserStoreKind.available)
    func aCancelStopsAJobBetweenItsSteps(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let queue = try await InProcessJobQueue.open(store: store)
        let (gate, last) = (JobGate(), JobGate())
        let steps = Mutex<[String]>([])
        let running = try await queue.submit(.indexImport, subject: nil, requestedBy: nil, id: nil) { job in
            try await job.step("One")
            steps.withLock { $0.append("one") }
            await gate.wait()
            // Within a step, a cancel waits for the next.
            await job.progress("Still one", fraction: 0.5)
            steps.withLock { $0.append("still one") }
            try await job.step("Two")
            steps.withLock { $0.append("two") }
            return nil
        }
        let waiting = try await queue.submit(.indexReset, subject: nil, requestedBy: "alice", id: nil) { _ in
            Issue.record("a job cancelled while it waits never runs")
            return nil
        }
        let committed = try await queue.submit(.researchImport, subject: nil, requestedBy: nil, id: nil) { job in
            try await job.step("Reading")
            try await job.commit()
            await last.wait()
            try await job.step("Writing")
            return "Written"
        }
        await gate.untilReached()

        let dequeued = try await queue.cancel(waiting.id, by: "bob")
        #expect(dequeued.state == .cancelled && dequeued.cancelRequestedBy == "bob" && dequeued.finishedAt != nil && !dequeued.cancellable)
        #expect(try Self.stored(rows, waiting.id)[2] == .text("cancelled") && Self.stored(rows, waiting.id)[6] == .text("bob"))

        let asked = try await queue.cancel(running.id, by: "bob")
        #expect(asked.state == .running && asked.cancelRequestedBy == "bob" && asked.cancellable, "it stops at its next step")
        gate.open()
        await last.untilReached()
        let stopped = try #require(await queue.job(running.id))
        #expect(stopped.state == .cancelled && stopped.progress == "Still one" && stopped.cancelRequestedBy == "bob")
        #expect(steps.withLock { $0 } == ["one", "still one"], "the step under way ran to its end, and the next never began")
        #expect(try Self.stored(rows, running.id) == [.text("indexImport"), .null, .text("cancelled"), .text("Still one"), .null, .null,
                                                       .text("bob")])

        await #expect(throws: JobCancelRefusal.self) { _ = try await queue.cancel(committed.id, by: "bob") }
        last.open()
        await queue.waitUntilIdle()
        let ended = await queue.job(committed.id)
        #expect(ended?.state == .succeeded && ended?.progress == "Written",
                "past the point where it can stop, it runs to its end")
        await #expect(throws: JobCancelRefusal.finished(.succeeded)) { _ = try await queue.cancel(committed.id, by: "bob") }
        await #expect(throws: JobCancelRefusal.finished(.cancelled)) { _ = try await queue.cancel(waiting.id, by: "bob") }
        await #expect(throws: JobCancelRefusal.notFound) { _ = try await queue.cancel(UUID().uuidString, by: "bob") }
    }

    /// A cancel asked for before the job's first step, or before its commit, stops it there.
    @Test func aCancelBeforeTheFirstStepOrTheCommitStopsTheJobThere() async throws {
        let queue = InProcessJobQueue()
        let gate = JobGate()
        let job = try await queue.submit(.indexImport) { job in
            await gate.wait()
            try await job.commit()
            Issue.record("the commit throws once a cancel was asked for")
            return nil
        }
        await gate.untilReached()
        _ = try await queue.cancel(job.id, by: nil)
        gate.open()
        await queue.waitUntilIdle()
        #expect(await queue.job(job.id)?.state == .cancelled)
    }

    /// A job the server stopped, running or waiting, is marked failed when a queue next opens over the
    /// store, before it takes a job, in the server's own sentence; one that finished is kept as it was.
    @Test(arguments: UserStoreKind.available)
    func aJobTheServerStoppedIsMarkedFailedAtTheNextStart(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let clock = JobClock()
        let queue = try await InProcessJobQueue.open(store: store, now: { clock.now })
        let finished = try await queue.submit(.researchImport, subject: "A Mac JSON export, format 7", requestedBy: "alice", id: nil) { _ in
            "Imported into alice's research: 3 records came in"
        }
        await queue.waitUntilIdle()
        // The server stops while one runs and one waits: their work never ends.
        let gate = JobGate()
        clock.advance(by: 1)
        let running = try await queue.submit(.indexImport, subject: "export.sqlite", requestedBy: nil, id: nil) { job in
            try await job.step("Copying export.sqlite", fraction: 0.25)
            await gate.wait()
            return nil
        }
        clock.advance(by: 1)
        let waiting = try await queue.submit(.indexReset, subject: nil, requestedBy: "alice", id: nil) { _ in nil }
        await gate.untilReached()

        let reopened = try await test.reopen()
        defer { (reopened as? PostgreSQLUserStore)?.close() }
        let lines = Mutex<[String]>([])
        let next = try await InProcessJobQueue.open(store: reopened, log: { line in lines.withLock { $0.append(line) } })
        #expect(lines.withLock { $0 } == ["2 jobs the server stopped before they finished were marked failed"])
        let listed = await next.jobs()
        #expect(listed.map(\.id) == [waiting.id, running.id, finished.id])
        #expect(listed.allSatisfy { $0.state.isFinished && !$0.cancellable })
        let stopped = try #require(listed.first { $0.id == running.id })
        #expect(stopped.state == .failed && stopped.error == RelationalUserStore.stoppedWhileItRan)
        #expect(stopped.progress == "Copying export.sqlite" && stopped.fraction == 0.25 && stopped.subject == "export.sqlite")
        let never = try #require(listed.first { $0.id == waiting.id })
        #expect(never.state == .failed && never.error == RelationalUserStore.stoppedBeforeItBegan && never.requestedBy == "alice")
        let kept = try #require(listed.first { $0.id == finished.id })
        #expect(kept == (await queue.job(finished.id))?.withCancellable(false), "a finished job outlives the restart as it was")
        #expect(kept.state == .succeeded && kept.progress == "Imported into alice's research: 3 records came in")
        #expect(try rows.stored("SELECT count(*) FROM jobs WHERE state IN ('queued', 'running')") == [[.integer(0)]])
        await #expect(throws: JobCancelRefusal.finished(.failed)) { _ = try await next.cancel(running.id, by: nil) }
    }

    /// A job's `error` is the server's own sentence, a `JobFailure`'s, and any other error's place is
    /// taken by one that says the log has it, which the queue's log does.
    @Test func aJobsErrorIsTheServersOwnSentence() async throws {
        let lines = Mutex<[String]>([])
        let queue = InProcessJobQueue(log: { line in lines.withLock { $0.append(line) } })
        let worded = try await queue.submit(.indexImport) { _ in throw JobFailed("The export is not one.") }
        let raw = try await queue.submit(.indexImport) { _ in throw CocoaError(.fileReadNoPermission, userInfo: [NSFilePathErrorKey: "/data/secret"]) }
        let refused = try await queue.submit(.indexImport) { _ in throw ImportRefusal(.checkingFormat, "x.sqlite is not an export.") }
        await queue.waitUntilIdle()
        #expect(await queue.job(worded.id)?.error == "The export is not one.")
        #expect(await queue.job(raw.id)?.error == Job.unexplained)
        #expect(await queue.job(refused.id)?.error == "x.sqlite is not an export.")
        #expect(lines.withLock { $0 }.contains { $0.contains(raw.id) }, "the log has the error the row leaves out")
    }

    /// Within one line a job's progress is written at most once a second; a new line at once.
    @Test(arguments: UserStoreKind.available)
    func progressWithinALineIsWrittenAtMostOnceASecond(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let clock = JobClock()
        let queue = try await InProcessJobQueue.open(store: store, now: { clock.now })
        let (gate, after) = (JobGate(), JobGate())
        let fractions = { try rows.stored("SELECT progress, fraction FROM jobs") }
        let job = try await queue.submit(.indexImport) { job in
            try await job.step("Copying", fraction: 0.1)
            await job.progress("Copying", fraction: 0.2)
            await gate.wait()
            await job.progress("Copying", fraction: 0.3)
            await after.wait()
            try await job.step("Checking")
            return nil
        }
        await gate.untilReached()
        #expect(await queue.job(job.id)?.fraction == 0.2, "the list is the queue's")
        #expect(try fractions() == [[.text("Copying"), .real(0.1)]], "the row waits for a second")
        clock.advance(by: 1)
        gate.open()
        await after.untilReached()
        #expect(try fractions() == [[.text("Copying"), .real(0.3)]], "a second on, it is written")
        after.open()
        await queue.waitUntilIdle()
        #expect(try fractions() == [[.text("Checking"), .null]], "a new line at once")
    }

    /// The queue keeps the newest finished jobs, and so does the store.
    @Test(arguments: UserStoreKind.available)
    func onlyTheNewestFinishedJobsAreKept(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let clock = JobClock()
        let queue = try await InProcessJobQueue.open(store: store, now: { clock.now })
        var ids: [String] = []
        for _ in 0..<(InProcessJobQueue.kept + 3) {
            clock.advance(by: 1)
            ids.append(try await queue.submit(.indexImport) { _ in nil }.id)
            await queue.waitUntilIdle()
        }
        #expect(await queue.jobs().map(\.id) == Array(ids.reversed().prefix(InProcessJobQueue.kept)))
        #expect(try rows.stored("SELECT count(*) FROM jobs") == [[.integer(Int64(InProcessJobQueue.kept))]])
        #expect(try store.jobs(limit: 1_000).map(\.id) == Array(ids.reversed().prefix(InProcessJobQueue.kept)))
    }

    /// A row is kept as it is given, every field, and given back as it was: the store's half alone.
    @Test(arguments: UserStoreKind.available)
    func aJobsRowIsKeptWhole(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let time = Date(timeIntervalSince1970: 1_792_800_000.123)
        var job = Job(id: UUID().uuidString, kind: JobKind(rawValue: "download"), subject: "frus1969-76v32", requestedBy: "Zoë Ödegaard",
                      state: .running, progress: "Downloading frus1969-76v32 (12 of 553)", fraction: 12.0 / 553, queuedAt: time,
                      startedAt: time.addingTimeInterval(1), cancelRequestedBy: "alice", cancelRequestedAt: time.addingTimeInterval(2))
        try store.saveJob(job)
        #expect(try store.jobs(limit: 1) == [job.withCancellable(true)])
        job.state = .failed
        job.error = "The listing could not be read."
        job.finishedAt = time.addingTimeInterval(3)
        try store.saveJob(job)
        #expect(try store.jobs(limit: 5) == [job.withCancellable(false)], "replaced whole, one row")
        #expect(try store.failUnfinishedJobs(at: time) == 0)
    }
}

/// Times a test's clock gave.
enum UserDataTimes {
    static func at(_ clock: JobClock, _ seconds: TimeInterval) -> Date { UserStoreDate.rounded(clock.now.addingTimeInterval(seconds)) }
}

extension Job {
    /// The job as the store gives it back, which keeps no `cancellable`: true while it is unfinished.
    func withCancellable(_ cancellable: Bool) -> Job {
        var job = self
        job.cancellable = cancellable
        return job
    }
}
