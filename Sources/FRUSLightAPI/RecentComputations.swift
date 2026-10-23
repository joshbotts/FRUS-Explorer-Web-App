// What one served index computed lately, by what was asked: the facets' sections, and the results
// the app keeps of a search, so the same question asked again costs no second computation.

import FRUSCoreKit
import Foundation

/// The results the app keeps of each search ordered lately by date over one served index: the first
/// 7,500 the kit ranks, as the Mac's search window keeps them, which the date order sorts whole
/// (`SearchSortOrder.sorted(_:)`). Each is kept by the query fields that say its search, so its other
/// pages, in either order of the date, fetch them once.
///
/// Two are kept: one holds up to 7,500 results with their snippets, as the Mac's window holds one,
/// about 20 MB by estimate over the whole corpus. A search no request waits for any more is
/// stopped, as the Mac's window stops one a later search replaced (#1698).
public struct RetainedResults: Sendable {
    let kept: RecentComputations<[SearchResult]>

    public init(capacity: Int = 2) {
        kept = RecentComputations(capacity: capacity, stopsAbandoned: true)
    }

    /// The results the app keeps of the search `parameters` say, best first, as kept lately or as
    /// the search service ranks them.
    func results(of parameters: SearchParameters, service: SearchService) async throws -> [SearchResult] {
        try await kept.value(for: SearchRequest.signature(parameters)) {
            try await service.search(parameters: parameters, limit: SearchRequest.retainedLimit, offset: 0)
        }
    }
}

/// What was computed lately over one served index, each kept by a key that says what was asked, so
/// asking again, or while it is computed, costs no second computation while it is kept. The least
/// recently used goes when more than `capacity` are kept, even while it is computed, and a
/// computation that fails is not kept. A new index starts with none, since each served index has
/// its own.
///
/// A request that is cancelled while it waits, as one whose client has gone is, stops waiting at
/// once. With `stopsAbandoned`, a computation no request waits for any more is cancelled and not
/// kept once `grace` has passed with none, which stops the kit's search; otherwise it runs to its end
/// and is kept, as the kit's facet pass, which nothing stops, is on the Mac. The grace is for a
/// request that replaces another for the same search, as a browser sends one just after it abandons
/// the first when the reader turns the date order round: it joins the computation the first began.
public actor RecentComputations<Value: Sendable> {
    /// What a key holds: a computation under way, by its number, or the value it gave.
    private enum Slot {
        case computing(UInt64)
        case done(Value)
    }

    /// A computation under way, the key it is for, and the requests waiting for it.
    private struct Computation {
        let key: String
        let task: Task<Void, Never>
        var waiters: [UInt64: CheckedContinuation<Value, any Error>] = [:]
    }

    private var slots: [String: Slot] = [:]
    /// The keys in `slots`, least recently used first.
    private var recency: [String] = []
    /// Every computation under way, a slot's or one that lost its slot to a newer key.
    private var computations: [UInt64: Computation] = [:]
    private var lastNumber: UInt64 = 0
    let capacity: Int
    let stopsAbandoned: Bool
    let grace: Duration

    public init(capacity: Int, stopsAbandoned: Bool = false, grace: Duration = .milliseconds(250)) {
        self.capacity = max(1, capacity)
        self.stopsAbandoned = stopsAbandoned
        self.grace = grace
    }

    /// The value kept for `key`, or the one `compute` gives, which is kept unless it fails. Throws
    /// `CancellationError` as soon as the calling task is cancelled.
    func value(for key: String, compute: @escaping @Sendable () async throws -> Value) async throws -> Value {
        let number: UInt64
        switch slots[key] {
        case .done(let value)?:
            touch(key)
            return value
        case .computing(let running)?:
            number = running
        case nil:
            number = nextNumber()
            let task = Task {
                let result: Result<Value, any Error>
                do { result = .success(try await compute()) } catch { result = .failure(error) }
                self.finish(number, result)
            }
            computations[number] = Computation(key: key, task: task)
            slots[key] = .computing(number)
        }
        touch(key)
        let waiter = nextNumber()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled || computations[number] == nil {
                    continuation.resume(throwing: CancellationError())
                } else {
                    computations[number]?.waiters[waiter] = continuation
                }
            }
        } onCancel: {
            Task { await self.leave(waiter, from: number) }
        }
    }

    private func nextNumber() -> UInt64 {
        lastNumber += 1
        return lastNumber
    }

    /// Makes `key` the most recently used, and lets go of the least recently used beyond `capacity`.
    private func touch(_ key: String) {
        recency.removeAll { $0 == key }
        recency.append(key)
        while recency.count > capacity { slots[recency.removeFirst()] = nil }
    }

    private func drop(_ key: String) {
        slots[key] = nil
        recency.removeAll { $0 == key }
    }

    /// Gives a computation's result to every request waiting for it, and keeps a value its slot
    /// still names.
    private func finish(_ number: UInt64, _ result: Result<Value, any Error>) {
        guard let computation = computations.removeValue(forKey: number) else { return }
        for waiter in computation.waiters.values { waiter.resume(with: result) }
        guard case .computing(number)? = slots[computation.key] else { return }
        switch result {
        case .success(let value): slots[computation.key] = .done(value)
        case .failure: drop(computation.key)
        }
    }

    /// A waiting request was cancelled: it stops waiting, and with `stopsAbandoned` a computation
    /// left with no one waiting is stopped once `grace` has passed with no one joining it.
    private func leave(_ waiter: UInt64, from number: UInt64) {
        guard var computation = computations[number] else { return }
        computation.waiters.removeValue(forKey: waiter)?.resume(throwing: CancellationError())
        computations[number] = computation
        guard stopsAbandoned, computation.waiters.isEmpty else { return }
        Task {
            try? await Task.sleep(for: self.grace)
            self.stopIfAbandoned(number)
        }
    }

    /// Cancels a computation that still has no request waiting for it, and drops its slot.
    private func stopIfAbandoned(_ number: UInt64) {
        guard let computation = computations[number], computation.waiters.isEmpty else { return }
        computation.task.cancel()
        computations[number] = nil
        if case .computing(number)? = slots[computation.key] { drop(computation.key) }
    }

    /// How many requests wait for the computation under way for `key`, for the tests.
    func waitingCount(for key: String) -> Int {
        guard case .computing(let number)? = slots[key] else { return 0 }
        return computations[number]?.waiters.count ?? 0
    }
}
