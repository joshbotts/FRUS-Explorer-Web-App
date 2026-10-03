// Long blocking calls, such as SQLite's integrity checks, run off Swift's cooperative thread pool.

import Dispatch

/// Runs blocking work on Dispatch threads rather than Swift's cooperative pool, which has one
/// thread per CPU: on a one-CPU host a 30-second `quick_check` there would stall every request,
/// `/healthz` included.
enum Blocking {
    private static let queue = DispatchQueue(label: "frus-light.blocking", qos: .utility, attributes: .concurrent)

    static func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try work() }) }
        }
    }
}
