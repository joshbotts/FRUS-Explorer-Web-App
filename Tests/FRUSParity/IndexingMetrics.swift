// Indexing speed and memory, which session 6 records for phase 0's exit (docs/PLAN.md): each step's
// time and documents per second, and the process's peak resident memory.

import Foundation

/// The steps of an indexing run, timed in order, each with the process's peak resident memory when
/// it ended. The peak only grows, so the step that raised it is the first to show it.
public struct IndexingMetrics: Sendable {
    public struct Step: Equatable, Sendable {
        public var name: String
        public var duration: Duration
        /// The documents the step handled, or nil for a step that handles none, such as a rollup.
        public var documents: Int?
        /// `IndexingMetrics.peakResidentBytes()` when the step ended.
        public var peakBytes: Int64?

        public init(name: String, duration: Duration, documents: Int? = nil, peakBytes: Int64? = nil) {
            self.name = name
            self.duration = duration
            self.documents = documents
            self.peakBytes = peakBytes
        }

        /// Documents per second, or nil when the step has no count or took no measurable time.
        public var documentsPerSecond: Double? {
            let seconds = IndexingMetrics.seconds(duration)
            guard let documents, seconds > 0 else { return nil }
            return Double(documents) / seconds
        }
    }

    public private(set) var steps: [Step] = []

    public init() {}

    /// Runs `body` as the step `name`, timed by `ContinuousClock`, and records it with `documents`
    /// and the peak memory after it. A step that throws is not recorded.
    @discardableResult
    public mutating func measure<T>(_ name: String, documents: Int? = nil, _ body: () async throws -> T) async rethrows -> T {
        let clock = ContinuousClock()
        let start = clock.now
        let value = try await body()
        steps.append(Step(name: name, duration: clock.now - start, documents: documents, peakBytes: Self.peakResidentBytes()))
        return value
    }

    /// Runs `body` as the step `name`, as `measure` does, and records it with the documents `body`
    /// returns: for a step whose count is known only once it has run, such as indexing a volume.
    @discardableResult
    public mutating func measureDocuments(_ name: String, _ body: () async throws -> Int) async rethrows -> Int {
        let clock = ContinuousClock()
        let start = clock.now
        let documents = try await body()
        steps.append(Step(name: name, duration: clock.now - start, documents: documents, peakBytes: Self.peakResidentBytes()))
        return documents
    }

    /// The time of every step together.
    public var total: Duration { steps.reduce(.zero) { $0 + $1.duration } }

    /// This process's peak resident memory in bytes, or nil where it cannot be read. On Linux it is
    /// `VmHWM` in `/proc/self/status`, given in kB; on macOS, `getrusage`'s `ru_maxrss`, which is in
    /// bytes there, though in kilobytes on Linux.
    public static func peakResidentBytes() -> Int64? {
        #if os(Linux)
        guard let status = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8) else { return nil }
        for line in status.split(separator: "\n") where line.hasPrefix("VmHWM:") {
            // A tab, then the value padded with spaces: "VmHWM:\t   1516 kB".
            let fields = line.dropFirst("VmHWM:".count).split(whereSeparator: \.isWhitespace)
            guard fields.count == 2, fields[1] == "kB", let kilobytes = Int64(fields[0]) else { return nil }
            return kilobytes * 1024
        }
        return nil
        #elseif os(macOS)
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }
        return Int64(usage.ru_maxrss)
        #else
        return nil
        #endif
    }

    /// A readable report: each step in order with its time, its documents and their rate, and the
    /// peak memory when it ended, in columns, then the total and the peak.
    public func report() -> String {
        func padded(_ text: String, _ width: Int) -> String {
            text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
        }
        let width = (steps.map(\.name.count) + ["total".count]).max()! + 2
        var lines = ["indexing metrics:"]
        for step in steps {
            var columns = [
                step.name.padding(toLength: width, withPad: " ", startingAt: 0) + String(format: "%9.3f s", Self.seconds(step.duration)),
                step.documents.map { "\(padded(String($0), 7)) documents" } ?? padded("", 17),
                step.documentsPerSecond.map { String(format: "%9.1f documents/s", $0) } ?? padded("", 21),
            ]
            if let peak = step.peakBytes { columns.append("peak \(Self.mebibytes(peak))") }
            var line = "  " + columns.joined(separator: "  ")
            while line.hasSuffix(" ") { line.removeLast() }
            lines.append(line)
        }
        lines.append("  \("total".padding(toLength: width, withPad: " ", startingAt: 0))\(String(format: "%9.3f s", Self.seconds(total)))")
        let peak = steps.compactMap(\.peakBytes).max() ?? Self.peakResidentBytes()
        lines.append("  peak resident memory \(peak.map(Self.mebibytes) ?? "unknown")")
        return lines.joined(separator: "\n")
    }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    static func mebibytes(_ bytes: Int64) -> String { String(format: "%.1f MiB", Double(bytes) / 1_048_576) }
}
