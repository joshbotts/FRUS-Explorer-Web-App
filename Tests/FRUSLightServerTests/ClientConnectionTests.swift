// A search whose client goes stops its statements (upstream #1698): over a real connection, the
// kit's statement is held at its test hook until the client closes its socket, and the progress
// handler then stops it. And the cache of what an index computed lately: a request that is cancelled
// stops waiting, and a search no request waits for any more is stopped.

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import Synchronization
import Testing

@testable import FRUSCoreKit
@testable import FRUSLightAPI

/// One request over a plain socket, which the test can close before the answer, as a browser closes
/// a connection when it abandons a request. A live test's server listens on `localhost`, which may
/// be IPv4's loopback or IPv6's, so both are tried, as the health check tries them.
final class RawConnection {
    private let fd: Int32

    init(port: Int) throws {
        var failure: Int32 = ECONNREFUSED
        for family in [AF_INET, AF_INET6] {
            let fd = Self.connected(family: family, port: port)
            if fd >= 0 {
                self.fd = fd
                return
            }
            failure = -fd
        }
        throw POSIXError(POSIXErrorCode(rawValue: failure) ?? .EIO)
    }

    /// A socket connected to the loopback address of `family`, or minus `errno`.
    private static func connected(family: Int32, port: Int) -> Int32 {
        #if canImport(Glibc)
        let fd = socket(family, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let fd = socket(family, SOCK_STREAM, 0)
        #endif
        guard fd >= 0 else { return -errno }
        let result: Int32
        if family == AF_INET {
            var address = sockaddr_in()
            #if canImport(Darwin)
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            #endif
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = in_port_t(UInt16(port).bigEndian)
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
        } else {
            var address = sockaddr_in6()
            #if canImport(Darwin)
            address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
            #endif
            address.sin6_family = sa_family_t(AF_INET6)
            address.sin6_port = in_port_t(UInt16(port).bigEndian)
            address.sin6_addr = in6addr_loopback
            result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) }
            }
        }
        guard result == 0 else {
            let code = errno
            closeSocket(fd)
            return -code
        }
        return fd
    }

    func send(_ request: String) throws {
        let bytes = Array(request.utf8)
        let sent = bytes.withUnsafeBufferPointer { Self.write(fd, $0.baseAddress, $0.count) }
        guard sent == bytes.count else { throw POSIXError(.EIO) }
    }

    func close() { Self.closeSocket(fd) }

    private static func write(_ fd: Int32, _ bytes: UnsafePointer<UInt8>?, _ count: Int) -> Int {
        #if canImport(Glibc)
        Glibc.send(fd, bytes, count, Int32(MSG_NOSIGNAL))
        #else
        Darwin.send(fd, bytes, count, 0)
        #endif
    }

    private static func closeSocket(_ fd: Int32) {
        #if canImport(Glibc)
        _ = Glibc.close(fd)
        #else
        _ = Darwin.close(fd)
        #endif
    }
}

/// What the kit's search statements told the pipeline's test hook, and whether the first one, held
/// at its start, saw its task cancelled.
final class StatementMoments: Sendable {
    private struct State {
        var prepared = 0
        var ranToItsEnd = 0
        var heldUntilCancelled: Bool?
    }

    private let state = Mutex(State())

    var prepared: Int { state.withLock { $0.prepared } }
    var ranToItsEnd: Int { state.withLock { $0.ranToItsEnd } }
    var heldUntilCancelled: Bool? { state.withLock { $0.heldUntilCancelled } }

    /// The hook: the first statement prepared is held, its first step not yet taken, until the task
    /// running it is cancelled, or for ten seconds. Only the progress handler can then stop it.
    var hook: @Sendable (SearchStatementMoment) -> Void {
        { moment in
            switch moment {
            case .prepared:
                let first = self.state.withLock { state -> Bool in
                    state.prepared += 1
                    return state.prepared == 1
                }
                guard first else { return }
                let deadline = ContinuousClock.now + .seconds(10)
                while !Task.isCancelled, ContinuousClock.now < deadline { usleep(1_000) }
                let cancelled = Task.isCancelled
                self.state.withLock { $0.heldUntilCancelled = cancelled }
            case .ranToItsEnd:
                self.state.withLock { $0.ranToItsEnd += 1 }
            }
        }
    }
}

/// Waits for `condition`, for ten seconds at most.
func eventually(_ condition: () -> Bool) async throws -> Bool {
    for _ in 0..<1_000 {
        if condition() { return true }
        try await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

@Suite struct ClientConnectionTests {
    /// The synthetic export with 2,000 more documents that say "containment", so a search's
    /// statements are long enough for the progress handler, which SQLite calls every 1,000
    /// instructions, to be called.
    static let manyDocuments = """
        WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 2000)
        INSERT INTO document_cache (volume_id, document_id, header, body_text)
          SELECT 'frus1961-63v06', 'x' || i, 'Item ' || i, 'The doctrine of containment shaped policy toward Europe.' FROM n;
        INSERT INTO document_revisions (volume_id, document_id, content_hash, body_hash, index_version)
          SELECT volume_id, document_id, printf('%064d', 0), printf('%016d', 0), \(IndexCompatibility.supportedIndexVersion)
          FROM document_cache WHERE document_id GLOB 'x*';
        """

    /// The client closes its socket while the search's first statement, the count, is held at its
    /// start: the request's task is cancelled, and the statement, let go, is stopped by the progress
    /// handler before its end. The server goes on answering, and a search whose client stays gets
    /// its answer, each statement run to its end.
    @Test func aSearchWhoseClientLeavesStopsItsStatement() async throws {
        let fixture = try await servingSyntheticExport(edits: Self.manyDocuments)
        let provider = ServedIndexProvider(state: fixture.state, resources: fixture.resources,
                                           volumesDirectory: fixture.files.volumesDirectory)
        let moments = StatementMoments()
        let served = try await provider.served()
        await served.pipeline.setSearchStatementTestHook(moments.hook)
        // Built as the server builds its own, so the test fails if that loses its watch.
        let app = apiApplication(
            router: buildRouter(state: fixture.state, resources: fixture.resources, reader: fixture.reader, provider: provider),
            configuration: .init(address: .hostname("127.0.0.1", port: 0)), logger: Logger(label: "test"))
        try await app.test(.live) { client in
            let connection = try RawConnection(port: try #require(client.port))
            try connection.send("GET /api/v1/search?keywords=containment HTTP/1.1\r\nHost: localhost\r\n\r\n")
            #expect(try await eventually { moments.prepared == 1 }, "the search's first statement was not prepared")
            connection.close()
            #expect(try await eventually { moments.heldUntilCancelled != nil })
            #expect(moments.heldUntilCancelled == true, "closing the connection did not cancel the search")
            // Let go, the count is stopped: it never reports running to its end.
            try await Task.sleep(for: .milliseconds(200))
            #expect(moments.ranToItsEnd == 0, "the held statement ran to its end")

            let response = try await client.execute(uri: "/api/v1/search?keywords=containment&limit=5", method: .get)
            #expect(response.status == .ok)
            let list = try decode(SearchResultList.self, response)
            #expect(list.total == 2_000 && list.items.count == 5)
            #expect(moments.prepared == 3 && moments.ranToItsEnd == 2, "the count and the page, each to its end")
        }
    }

    /// A connection with no watch, as the router's tests give a request, runs the work to its end.
    @Test func workRunsToItsEndWithoutAWatch() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)
            #expect(response.status == .ok)
            #expect(try decode(SearchResultList.self, response).total == 2)
        }
    }

    @Test func theClosureWakesItsWaitersAndThoseThatComeLater() async throws {
        let closure = ConnectionClosure()
        let waiting = Task { await closure.closed() }
        #expect(try await eventually { closure.waiterCount == 1 })
        #expect(!closure.isClosed)
        closure.close()
        await waiting.value
        #expect(closure.isClosed && closure.waiterCount == 0)
        await closure.closed()
        // A waiter whose task is cancelled stops waiting, whether it was cancelled before it waited
        // or while it waits.
        let other = ConnectionClosure()
        let early = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await other.closed()
        }
        await early.value
        let registered = Task { await other.closed() }
        #expect(try await eventually { other.waiterCount == 1 })
        registered.cancel()
        await registered.value
        #expect(!other.isClosed && other.waiterCount == 0)
    }
}

@Suite struct RecentComputationsTests {
    /// A computation that waits at a gate, and says whether it was cancelled.
    actor Gate {
        private(set) var started = 0
        private(set) var cancelled = 0
        private var open = false

        func compute(_ value: Int) async throws -> Int {
            started += 1
            while !open {
                if Task.isCancelled {
                    cancelled += 1
                    throw CancellationError()
                }
                try? await Task.sleep(for: .milliseconds(5))
            }
            return value
        }

        func release() { open = true }
    }

    @Test func aRequestCancelledWhileAnotherWaitsLeavesAtOnceAndTheValueIsKept() async throws {
        let kept = RecentComputations<Int>(capacity: 2, stopsAbandoned: true, grace: .zero)
        let gate = Gate()
        let first = Task { try await kept.value(for: "a") { try await gate.compute(1) } }
        let second = Task { try await kept.value(for: "a") { try await gate.compute(2) } }
        #expect(try await eventuallyAsync { await kept.waitingCount(for: "a") == 2 })
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        await gate.release()
        #expect(try await second.value == 1)
        #expect(try await kept.value(for: "a") { try await gate.compute(3) } == 1)
        let (started, cancelled) = (await gate.started, await gate.cancelled)
        #expect(started == 1 && cancelled == 0)
    }

    @Test func aComputationNoRequestWaitsForIsStoppedAndNotKept() async throws {
        let kept = RecentComputations<Int>(capacity: 2, stopsAbandoned: true, grace: .milliseconds(50))
        let gate = Gate()
        let only = Task { try await kept.value(for: "a") { try await gate.compute(1) } }
        #expect(try await eventuallyAsync { await gate.started == 1 })
        only.cancel()
        await #expect(throws: CancellationError.self) { try await only.value }
        #expect(try await eventuallyAsync { await gate.cancelled == 1 }, "the computation was not cancelled")
        // Asked again, it is computed again.
        await gate.release()
        #expect(try await kept.value(for: "a") { try await gate.compute(2) } == 2)
        #expect(await gate.started == 2)
    }

    /// A request for the same search that comes while a computation no one waits for is in its grace,
    /// as a browser sends one just after it abandons the first, joins it: nothing is computed again.
    @Test func aRequestThatComesWithinTheGraceJoinsTheComputation() async throws {
        let kept = RecentComputations<Int>(capacity: 2, stopsAbandoned: true, grace: .seconds(2))
        let gate = Gate()
        let first = Task { try await kept.value(for: "a") { try await gate.compute(1) } }
        #expect(try await eventuallyAsync { await kept.waitingCount(for: "a") == 1 })
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(await kept.waitingCount(for: "a") == 0)
        let second = Task { try await kept.value(for: "a") { try await gate.compute(2) } }
        #expect(try await eventuallyAsync { await kept.waitingCount(for: "a") == 1 })
        await gate.release()
        #expect(try await second.value == 1)
        let (started, cancelled) = (await gate.started, await gate.cancelled)
        #expect(started == 1 && cancelled == 0)
    }

    /// The facets' cache keeps a section no request waits for any more: the kit's facet pass, which
    /// nothing stops, runs to its end, and the panel's next ask finds it.
    @Test func withoutStoppingAComputationNoOneWaitsForRunsOnAndIsKept() async throws {
        let kept = RecentComputations<Int>(capacity: 2)
        let gate = Gate()
        let only = Task { try await kept.value(for: "a") { try await gate.compute(1) } }
        #expect(try await eventuallyAsync { await gate.started == 1 })
        only.cancel()
        await #expect(throws: CancellationError.self) { try await only.value }
        await gate.release()
        #expect(try await kept.value(for: "a") { try await gate.compute(2) } == 1)
        let (started, cancelled) = (await gate.started, await gate.cancelled)
        #expect(started == 1 && cancelled == 0)
    }
}

/// Waits for `condition`, for ten seconds at most.
func eventuallyAsync(_ condition: () async -> Bool) async throws -> Bool {
    for _ in 0..<1_000 {
        if await condition() { return true }
        try await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}
