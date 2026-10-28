// What one served index computed lately, by what was asked: the facets' sections, the results the
// app keeps of a search, and the pages and counts of searches by relevance, so the same question
// asked again costs no second computation.

import FRUSCoreKit
import Foundation

/// The pages and counts of the searches asked for lately by relevance over one served index (S13b):
/// the page `/search` fetched, which the concordance of that page reads, even while it is fetched, and
/// the count every page of a search shows, which its next page needs again. A search with an exact word
/// reads every row its stem matches, for its page and again for its count; the Mac's window, which
/// keeps what it fetched and pages it, asks for neither twice, and nor does the server while it keeps
/// them.
///
/// Each is kept by whose search it is (`ServedSearch.key`, S17d) and the query fields that say it, and a
/// page by its limit and offset too. A page holds at most 100 results with their snippets, well under a
/// megabyte. A page or a count no request waits for any more is stopped at once, with no grace, as
/// `/search` stopped its own when its client went before it kept them (#1698).
public struct RecentSearches: Sendable {
    let pages: RecentComputations<[SearchResult]>
    let counts: RecentComputations<Int>

    public init(capacity: Int = 4) {
        pages = RecentComputations(capacity: capacity, stopsAbandoned: true, grace: .zero)
        counts = RecentComputations(capacity: capacity, stopsAbandoned: true, grace: .zero)
    }

    /// The page `search` asks for, by relevance, as kept lately or as `scoped` ranks it.
    func page(of search: SearchRequest, in scoped: ServedSearch) async throws -> [SearchResult] {
        try await pages.value(for: "\(scoped.key)\(search.limit) \(search.offset) \(SearchRequest.signature(search.parameters))") {
            try await scoped.service.search(parameters: search.parameters, limit: search.limit, offset: search.offset)
        }
    }

    /// The count of every document the search `parameters` say matches, as kept lately or as `scoped`
    /// counts it.
    func count(of parameters: SearchParameters, in scoped: ServedSearch) async throws -> Int {
        try await counts.value(for: scoped.key + SearchRequest.signature(parameters)) {
            try await scoped.service.searchCount(parameters: parameters)
        }
    }
}

/// The results the app keeps of each search ordered lately by date over one served index: the first
/// 7,500 the kit ranks, as the Mac's search window keeps them, which the date order sorts whole
/// (`SearchSortOrder.sorted(_:)`). Each is kept by whose search it is and the query fields that say it,
/// so its other pages, in either order of the date, fetch them once.
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
    /// `scoped` ranks them.
    func results(of parameters: SearchParameters, in scoped: ServedSearch) async throws -> [SearchResult] {
        try await kept.value(for: scoped.key + SearchRequest.signature(parameters)) {
            try await scoped.service.search(parameters: parameters, limit: SearchRequest.retainedLimit, offset: 0)
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
/// kept once `grace` has passed with none since the last request left, which stops the kit's search;
/// otherwise it runs to its end and is kept, as the kit's facet pass, which nothing stops, is on the
/// Mac. The grace is for a request that replaces another for the same search, as a browser sends one
/// just after it abandons the first when the reader turns the date order round: it joins the
/// computation the first began, and if it is abandoned in turn, the grace begins again.
public actor RecentComputations<Value: Sendable> {
    /// What a key holds: a computation under way, by its number, or the value it gave.
    private enum Slot {
        case computing(UInt64)
        case done(Value)
    }

    /// A computation under way, the key it is for, the requests waiting for it, and how many times
    /// it has been abandoned, left with no request waiting.
    private struct Computation {
        let key: String
        let task: Task<Void, Never>
        var waiters: [UInt64: CheckedContinuation<Value, any Error>] = [:]
        var abandonments = 0
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
    /// What waits out a grace: a sleep for its length, or a wait the tests end by hand.
    private var graceWait: @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    /// How many graces have passed, each with its computation stopped or left to run on, for the
    /// tests.
    private(set) var gracesPassed = 0

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
    /// left with no one waiting is stopped once `grace` has passed with no one joining it. Each
    /// abandonment begins a grace, and a grace stops nothing once a later abandonment has begun
    /// another.
    private func leave(_ waiter: UInt64, from number: UInt64) {
        guard var computation = computations[number] else { return }
        computation.waiters.removeValue(forKey: waiter)?.resume(throwing: CancellationError())
        let abandoned = stopsAbandoned && computation.waiters.isEmpty
        if abandoned { computation.abandonments += 1 }
        computations[number] = computation
        guard abandoned else { return }
        let abandonment = computation.abandonments
        Task {
            await self.graceWait(self.grace)
            self.stopIfAbandoned(number, since: abandonment)
        }
    }

    /// Cancels a computation whose last abandonment is still `abandonment`, with no request waiting
    /// for it, and drops its slot.
    private func stopIfAbandoned(_ number: UInt64, since abandonment: Int) {
        gracesPassed += 1
        guard let computation = computations[number], computation.waiters.isEmpty,
              computation.abandonments == abandonment else { return }
        computation.task.cancel()
        computations[number] = nil
        if case .computing(number)? = slots[computation.key] { drop(computation.key) }
    }

    /// How many requests wait for the computation under way for `key`, for the tests.
    func waitingCount(for key: String) -> Int {
        guard case .computing(let number)? = slots[key] else { return 0 }
        return computations[number]?.waiters.count ?? 0
    }

    /// Waits out each grace with `wait` instead of a sleep, for the tests.
    func waitOutGraces(with wait: @escaping @Sendable (Duration) async -> Void) {
        graceWait = wait
    }
}
