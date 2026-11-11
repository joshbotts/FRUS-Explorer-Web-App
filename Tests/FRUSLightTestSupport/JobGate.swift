// A gate a test's job waits at (PLAN's S20d): the queue's tests, and the admin routes', hold a job
// running with it, to cancel it or queue another behind it.

import Foundation
import Synchronization

/// A gate a job waits at until a test opens it, and that says when the job has reached it.
public final class JobGate: Sendable {
    private let state = Mutex<(open: Bool, reached: Bool, waiters: [CheckedContinuation<Void, Never>])>((false, false, []))

    public init() {}

    public func wait() async {
        await withCheckedContinuation { continuation in
            let now = state.withLock { state -> Bool in
                state.reached = true
                if state.open { return true }
                state.waiters.append(continuation)
                return false
            }
            if now { continuation.resume() }
        }
    }

    public func open() {
        let waiters = state.withLock { state -> [CheckedContinuation<Void, Never>] in
            state.open = true
            defer { state.waiters = [] }
            return state.waiters
        }
        for waiter in waiters { waiter.resume() }
    }

    public var reached: Bool { state.withLock { $0.reached } }

    /// Waits until a job has reached the gate.
    public func untilReached() async {
        while !reached { try? await Task.sleep(for: .milliseconds(5)) }
    }
}
