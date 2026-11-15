// The series Person and Cross-Reference Analytics compute (PLAN's S24g), each once for its index and kept, as the app's
// views keep what they loaded until the index changes: a `ServedIndex` holds them, so a new index starts with none, and
// every reader of an index shares what any of them asked for first.

import Foundation

/// Values computed once for a key and kept while their index is served (PLAN's S24g): the least recently asked let go
/// past `capacity`, and a key asked for while it is being computed waits for that computation rather than starting
/// another. A computation that fails keeps nothing, so the next request computes it again.
actor KeptSeries<Key: Hashable & Sendable, Value: Sendable> {
    private var kept: [Key: Value] = [:]
    /// The keys kept, the most recently asked last.
    private var recency: [Key] = []
    private var running: [Key: Task<Value, any Error>] = [:]
    let capacity: Int

    init(capacity: Int = 64) {
        self.capacity = capacity
    }

    /// The value kept for `key`, computed by `compute` the first time it is asked for.
    func value(for key: Key, compute: @escaping @Sendable () async throws -> Value) async throws -> Value {
        if let value = kept[key] {
            recency.removeAll { $0 == key }
            recency.append(key)
            return value
        }
        if let task = running[key] { return try await task.value }
        let task = Task { try await compute() }
        running[key] = task
        let result = await task.result
        running[key] = nil
        let value = try result.get()
        kept[key] = value
        recency.removeAll { $0 == key }
        recency.append(key)
        while recency.count > capacity {
            kept[recency.removeFirst()] = nil
        }
        return value
    }

    /// How many values are kept, for the tests.
    var count: Int { kept.count }
}
