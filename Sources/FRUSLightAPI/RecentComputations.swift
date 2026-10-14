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
/// about 20 MB by estimate over the whole corpus.
public struct RetainedResults: Sendable {
    let kept: RecentComputations<[SearchResult]>

    public init(capacity: Int = 2) {
        kept = RecentComputations(capacity: capacity)
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
public actor RecentComputations<Value: Sendable> {
    private var entries: [String: Task<Value, any Error>] = [:]
    /// The keys in `entries`, least recently used first.
    private var recency: [String] = []
    let capacity: Int

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    /// The value kept for `key`, or the one `compute` gives, which is kept unless it fails.
    func value(for key: String, compute: @escaping @Sendable () async throws -> Value) async throws -> Value {
        let task: Task<Value, any Error>
        if let running = entries[key] {
            task = running
        } else {
            task = Task { try await compute() }
            entries[key] = task
        }
        recency.removeAll { $0 == key }
        recency.append(key)
        while recency.count > capacity { entries[recency.removeFirst()] = nil }
        do {
            return try await task.value
        } catch {
            if entries[key] == task {
                entries[key] = nil
                recency.removeAll { $0 == key }
            }
            throw error
        }
    }
}
