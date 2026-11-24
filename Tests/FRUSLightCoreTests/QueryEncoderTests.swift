// Search by meaning's encoder (PLAN's S27b) over the stand-in that answers as llama-server does
// (Tests/EncoderStandIn), since the swift job has neither CMake nor the model: the child starts at the first
// query, with a key of its own; a query is the kit's prompt and the reader's words, its vector normalised as
// the app's; it stops when idle and comes back after it is killed; a query past the app's 2,048 tokens and a
// server with the encoder off are refused in their words; a model that is not the bundled index's, or a start
// that fails, says why; and the child stops with the server.

import FRUSLightTestSupport
import Foundation
import Synchronization
import Testing
#if canImport(Glibc)
import Glibc
#endif

@testable import FRUSLightCore

@Suite struct QueryEncoderTests {
    /// The prompt's words before the reader's: "task:", "search", "result", "|" and "query:".
    static let promptWords = SearchModel.queryPrefix.split(whereSeparator: \.isWhitespace).count

    /// Waits up to `seconds` for `condition`, asking every 20 ms.
    static func eventually(_ seconds: Double = 10, _ condition: () async -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .milliseconds(Int64(seconds * 1_000))
        while ContinuousClock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return await condition()
    }

    static func isAlive(_ pid: Int) -> Bool { kill(pid_t(pid), 0) == 0 }

    @Test func theChildStartsAtTheFirstQueryAndAnswersAsTheAppsEncoder() async throws {
        let directory = try TemporaryDirectory()
        let encoder = QueryEncoder(settings: try StandInEncoder.settings(in: directory.url, loadMilliseconds: 300))
        let before = await encoder.report()
        #expect(before.setting == "on" && before.state == "idle" && before.starts == 0 && before.pid == nil)
        #expect(before.model.verified == true && before.engine.version == "version: 0.0.0-stand-in (build 1, commit 5ea4d11)")
        #expect(before.engine.commit == "5ea4d11" && before.idleSeconds == 180 && before.maxTokens == 2_048)

        let query = "Soviet missiles in Cuba, October 1962"
        let first = try await encoder.embed(query)
        let prompt = "task: search result | query: " + query
        #expect(first.started && first.tokens == StandInEncoder.tokens(prompt))
        // The stand-in's own values, normalised in double precision as the app normalises them.
        #expect(first.vector == QueryEncoder.normalised(StandInEncoder.vector(prompt)))
        #expect(first.vector.count == 768 && abs(first.vector.reduce(0) { $0 + $1 * $1 } - 1) < 1e-12)

        let loaded = await encoder.report()
        #expect(loaded.state == "loaded" && loaded.starts == 1 && loaded.queries == 1)
        let pid = try #require(loaded.pid)
        #expect(Self.isAlive(pid) && loaded.loadedAt != nil && loaded.stopsAt != nil)

        let second = try await encoder.embed("  the Berlin airlift  ")
        #expect(!second.started && second.vector == QueryEncoder.normalised(StandInEncoder.vector("task: search result | query:   the Berlin airlift  ")),
                "the reader's words are appended as they came, as the app appends them")
        #expect(await encoder.report().pid == pid, "one child serves both")
        await encoder.shutdown()
        #expect(await Self.eventually { !Self.isAlive(pid) }, "the child stops with the server")
        await #expect(throws: EncoderRefusal.failed("is stopping with the server")) { try await encoder.embed(query) }
    }

    @Test func queriesAtOnceShareOneStart() async throws {
        let directory = try TemporaryDirectory()
        let encoder = QueryEncoder(settings: try StandInEncoder.settings(in: directory.url, loadMilliseconds: 400))
        let vectors = try await withThrowingTaskGroup(of: [Double].self) { group in
            for index in 0..<4 { group.addTask { try await encoder.embed("question \(index)").vector } }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(vectors.count == 4 && Set(vectors.map { $0.description }).count == 4)
        let report = await encoder.report()
        #expect(report.starts == 1 && report.queries == 4)
        await encoder.shutdown()
    }

    @Test func itStopsWhenIdleAndStartsAgainAtTheNextQuery() async throws {
        let directory = try TemporaryDirectory()
        let encoder = QueryEncoder(settings: try StandInEncoder.settings(in: directory.url, idle: .milliseconds(400)))
        _ = try await encoder.embed("the Marshall Plan")
        let pid = try #require(await encoder.report().pid)
        #expect(await Self.eventually { await encoder.report().state == "idle" }, "idle after its window")
        #expect(await Self.eventually { !Self.isAlive(pid) }, "its process has ended, giving back its memory")
        let again = try await encoder.embed("the Marshall Plan")
        let report = await encoder.report()
        #expect(again.started && report.starts == 2 && report.pid != pid && report.state == "loaded" && report.problem == nil)
        await encoder.shutdown()
    }

    @Test func itComesBackAfterItIsKilled() async throws {
        let directory = try TemporaryDirectory()
        let encoder = QueryEncoder(settings: try StandInEncoder.settings(in: directory.url))
        let first = try await encoder.embed("Suez, 1956")
        let pid = try #require(await encoder.report().pid)
        #expect(kill(pid_t(pid), SIGKILL) == 0)
        #expect(await Self.eventually { await encoder.report().state == "idle" }, "the server notices it gone")
        let problem = try #require(await encoder.report().problem)
        #expect(problem.contains("ended by signal 9 (SIGKILL)") && problem.contains("The next search by meaning starts it again"))
        let again = try await encoder.embed("Suez, 1956")
        let report = await encoder.report()
        #expect(again.started && again.vector == first.vector && report.pid != pid && report.starts == 2 && report.problem == nil)
        await encoder.shutdown()
    }

    @Test func aServerWithTheEncoderOffStartsNone() async throws {
        let directory = try TemporaryDirectory()
        let encoder = QueryEncoder(settings: try StandInEncoder.settings(in: directory.url, enabled: false))
        await #expect(throws: EncoderRefusal.off) { try await encoder.embed("the Congo crisis") }
        #expect(EncoderRefusal.off.description == "This server does not search by meaning: FRUS_ENCODER is off, so its encoder does not start.")
        let report = await encoder.report()
        #expect(report.setting == "off" && report.state == "off" && report.starts == 0 && report.pid == nil)
        #expect(report.model.verified == true, "the model in the image is still reported")
    }

    /// The app's limit is the prompt's tokens, the model's two special tokens included: 2,048 pass, 2,049 do
    /// not, refused in the app's words with the count; a query longer than any of 2,048 tokens is refused
    /// before the encoder is asked.
    @Test func aQueryPastTheAppsTokensIsRefusedInItsWords() async throws {
        let directory = try TemporaryDirectory()
        let encoder = QueryEncoder(settings: try StandInEncoder.settings(in: directory.url))
        let fits = Array(repeating: "word", count: 2_048 - 2 - Self.promptWords).joined(separator: " ")
        #expect(try await encoder.embed(fits).tokens == 2_048)
        await #expect(throws: EncoderRefusal.tooLong(tokens: 2_049)) { try await encoder.embed(fits + " more") }
        #expect(EncoderRefusal.tooLong(tokens: 2_049).description
                == "This search is too long for the model. Try a shorter phrasing. It is 2,049 tokens, of 2,048 at most.")
        let huge = String(repeating: "x", count: QueryEncoder.longestQueryBytes + 1)
        await #expect(throws: EncoderRefusal.tooLong(tokens: nil)) { try await encoder.embed(huge) }
        await #expect(throws: EncoderRefusal.emptyQuery) { try await encoder.embed(" \n ") }
        #expect(await encoder.report().queries == 1)
        await encoder.shutdown()
    }

    /// llama-server's own refusal of a query past its batch, should one reach it, is read as too long.
    @Test func llamaServersRefusalOfALongQueryIsReadAsTooLong() {
        let body = #"{"error":{"code":500,"message":"input (2101 tokens) is too large to process. increase the physical batch size (current batch size: 2048)","type":"server_error"}}"#
        guard case .tooLarge(let tokens) = Child.refusal(HTTPAnswer(status: 500, headers: [:], body: Data(body.utf8))) else {
            Issue.record("not read as too long")
            return
        }
        #expect(tokens == 2_101)
        let other = Child.refusal(HTTPAnswer(status: 401, headers: [:], body: Data(#"{"error":{"message":"Invalid API Key","type":"authentication_error","code":401}}"#.utf8)))
        #expect("\(other)" == "answered 401: Invalid API Key")
    }

    @Test func aModelThatIsNotTheBundledIndexsIsRefused() async throws {
        let directory = try TemporaryDirectory()
        var settings = try StandInEncoder.settings(in: directory.url)
        let real = try #require(settings.bundled)
        settings.bundled = SearchModel(name: real.name, sha256: String(repeating: "0", count: 64), dimensions: real.dimensions)
        let encoder = QueryEncoder(settings: settings)
        await #expect {
            try await encoder.embed("NATO")
        } throws: { error in
            guard case EncoderRefusal.unavailable(let reason) = error else { return false }
            return reason.contains("is not the one the bundled vectors were made with: its SHA-256 is \(real.sha256)")
        }
        let report = await encoder.report()
        #expect(report.state == "unavailable" && report.model.verified == false && report.starts == 0)
        #expect(report.model.sha256 == real.sha256 && report.model.bundledSHA256 == String(repeating: "0", count: 64))
    }

    @Test func anImageWithoutTheEncoderSaysSo() async throws {
        let directory = try TemporaryDirectory()
        var settings = try StandInEncoder.settings(in: directory.url)
        settings.binary = directory.url.appendingPathComponent("llama-server")
        let encoder = QueryEncoder(settings: settings)
        await #expect(throws: EncoderRefusal.unavailable("the image holds no encoder at \(settings.binary.path)")) {
            try await encoder.embed("NATO")
        }
        let report = await encoder.report()
        #expect(report.state == "unavailable" && !report.engine.present && report.engine.version == nil)
    }

    @Test func aStartThatFailsSaysWhyAndTheNextQueryTriesAgain() async throws {
        let directory = try TemporaryDirectory()
        let lines = LogLines()
        let encoder = QueryEncoder(settings: try StandInEncoder.settings(in: directory.url, failStart: true), log: lines.add)
        await #expect {
            try await encoder.embed("Laos")
        } throws: { error in
            "\(error)".hasPrefix("Semantic search could not run. Try again. The encoder did not start: it exited with status 1")
        }
        #expect(lines.all.contains { $0.contains("The encoder did not start") && $0.contains("stand-in: failing to start, as its model asks") })
        let report = await encoder.report()
        #expect(report.state == "idle" && report.starts == 1 && report.problem?.contains("did not start") == true)
        await #expect(throws: EncoderRefusal.self) { try await encoder.embed("Laos") }
        #expect(await encoder.report().starts == 2, "each query tries again")
    }

    /// The child's environment holds its key and the paths and locale, nothing of the server's own.
    @Test func theChildIsGivenItsKeyAndNoneOfTheServersSettings() {
        let environment = Child.environment(key: "abc")
        #expect(environment["LLAMA_API_KEY"] == "abc" && environment["PATH"] != nil)
        #expect(Set(environment.keys).isSubset(of: Child.passedOn.union(["LLAMA_API_KEY"])))
        #expect(Child.passedOn == ["PATH", "HOME", "TZ", "LANG", "LC_ALL", "LC_CTYPE", "TMPDIR", "MALLOC_ARENA_MAX"])
        #expect(Child.environment(key: nil)["LLAMA_API_KEY"] == nil)
        let arguments = Child.arguments(model: URL(fileURLWithPath: "/m.gguf"), port: 4321)
        #expect(arguments == ["--model", "/m.gguf", "--embedding", "--host", "127.0.0.1", "--port", "4321", "--ctx-size", "0",
                              "--batch-size", "2048", "--ubatch-size", "2048", "--parallel", "1", "--fit", "off", "--no-warmup",
                              "--no-webui", "--no-slots", "--log-colors", "off"])
    }

    @Test func theVersionLineNamesItsCommitAsTheAppsFixtureScriptReadsIt() {
        #expect(QueryEncoder.commit(inVersion: "version: 0.6.0-dev (build 1, commit a0e6dc7)") == "a0e6dc7")
        #expect(QueryEncoder.commit(inVersion: "version: 4589 (a1b2c3d)") == "a1b2c3d")
        #expect(QueryEncoder.commit(inVersion: "version: unknown") == nil)
    }

    @Test func normalisingIsTheApps() {
        // Each value times the inverse square root of the sum of squares, exact here in binary.
        #expect(QueryEncoder.normalised([1, 1, 1, 1]) == [0.5, 0.5, 0.5, 0.5])
        #expect(QueryEncoder.normalised([-4, 0]) == [-1, 0])
        #expect(QueryEncoder.normalised([3, 4]) == [3 * (1 / 5.0), 4 * (1 / 5.0)], "times the inverse, as the app's, not divided by the norm")
        #expect(QueryEncoder.normalised([0, 0]) == [0, 0])
    }

    /// The running encoders, as `frus-light semantic` reads them from /proc: the child this process started.
    @Test func theProcessTableNamesTheRunningEncoder() async throws {
        let directory = try TemporaryDirectory()
        let settings = try StandInEncoder.settings(in: directory.url)
        let encoder = QueryEncoder(settings: settings)
        _ = try await encoder.embed("détente")
        let pid = try #require(await encoder.report().pid)
        let running = QueryEncoder.runningProcesses(binary: settings.binary, model: settings.model)
        #expect(running.map(\.pid) == [Int32(pid)] && running.first?.port != nil)
        #expect(QueryEncoder.runningProcesses(binary: settings.binary, model: directory.url.appendingPathComponent("other.gguf")).isEmpty)
        #expect(QueryEncoder.residentBytes(of: Int32(pid)).map { $0 > 1_000_000 } == true)
        await encoder.shutdown()
        #expect(QueryEncoder.runningProcesses(binary: settings.binary, model: settings.model).isEmpty)
    }
}

/// The lines an encoder logs, kept for a test.
final class LogLines: Sendable {
    private let lines = Mutex<[String]>([])
    var all: [String] { lines.withLock { $0 } }
    var add: @Sendable (String) -> Void { { line in self.lines.withLock { $0.append(line) } } }
}
