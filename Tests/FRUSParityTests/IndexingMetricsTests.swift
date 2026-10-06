// The indexing metrics session 6 records: steps timed in order, documents per second, and the
// process's peak resident memory.

import FRUSParity
import Testing

@Suite struct IndexingMetricsTests {
    @Test func stepsAreTimedAndListedInOrder() async throws {
        var metrics = IndexingMetrics()
        let value = try await metrics.measure("index", documents: 392) {
            try await Task.sleep(for: .milliseconds(20))
            return 7
        }
        #expect(value == 7)
        await metrics.measure("rollup") {}
        #expect(metrics.steps.map(\.name) == ["index", "rollup"])
        #expect(metrics.steps[0].duration >= .milliseconds(20))
        #expect(metrics.steps[0].documents == 392)
        #expect(metrics.steps[1].documents == nil)
        #expect(metrics.total == metrics.steps[0].duration + metrics.steps[1].duration)

        // A step that throws is not recorded.
        struct Failure: Error {}
        do {
            try await metrics.measure("broken") { throw Failure() }
            Issue.record("the step did not throw")
        } catch {
            #expect(error is Failure)
        }
        #expect(metrics.steps.count == 2)

        let report = metrics.report()
        print(report)
        let lines = report.split(separator: "\n").map(String.init)
        #expect(lines.count == 5)
        #expect(lines[0] == "indexing metrics:")
        #expect(lines[1].hasPrefix("  index ") && lines[1].contains(" 392 documents") && lines[1].contains("documents/s"))
        #expect(lines[2].hasPrefix("  rollup ") && !lines[2].contains("documents"))
        #expect(lines[3].hasPrefix("  total "))
        #expect(lines[4].hasPrefix("  peak resident memory ") && lines[4].hasSuffix(" MiB"))
    }

    /// A step whose count is known only once it has run, such as indexing a volume, records the
    /// count its body returns; one that throws is not recorded.
    @Test func aStepCanRecordTheDocumentsItReturns() async throws {
        var metrics = IndexingMetrics()
        let documents = await metrics.measureDocuments("index frus1894Nicaragua") { 139 }
        #expect(documents == 139)
        #expect(metrics.steps.map(\.name) == ["index frus1894Nicaragua"])
        #expect(metrics.steps[0].documents == 139)
        #expect(metrics.steps[0].peakBytes != nil || IndexingMetrics.peakResidentBytes() == nil)
        struct Failure: Error {}
        await #expect(throws: Failure.self) { try await metrics.measureDocuments("broken") { throw Failure() } }
        #expect(metrics.steps.count == 1)
    }

    @Test func documentsPerSecondDividesTheCountByTheTime() {
        #expect(IndexingMetrics.Step(name: "index", duration: .seconds(2), documents: 392).documentsPerSecond == 196)
        #expect(IndexingMetrics.Step(name: "index", duration: .milliseconds(250), documents: 10).documentsPerSecond == 40)
        #expect(IndexingMetrics.Step(name: "rollup", duration: .seconds(2)).documentsPerSecond == nil)
        #expect(IndexingMetrics.Step(name: "index", duration: .zero, documents: 10).documentsPerSecond == nil)
    }

    /// Read from /proc/self/status on Linux and from getrusage on macOS: this process has resident
    /// memory, and every step records it.
    @Test func peakMemoryIsPositive() async throws {
        let peak = try #require(IndexingMetrics.peakResidentBytes())
        #expect(peak > 1_048_576)
        var metrics = IndexingMetrics()
        await metrics.measure("step") {}
        let recorded = try #require(metrics.steps.first?.peakBytes)
        #expect(recorded >= peak)
    }
}
