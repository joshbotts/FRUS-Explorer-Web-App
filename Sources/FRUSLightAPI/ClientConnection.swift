// A request whose client has gone stops its work: each connection's pipeline notices when the client
// closes its side, and a search's work, run while its client is connected, is cancelled then, so the
// kit stops its statement (`SearchStatementStop`, joshbotts/FRUS-Explorer#1698). Session 10 found a
// search running on for minutes after its client had dropped the connection.

import Hummingbird
import HummingbirdCore
import Logging
import NIOCore
import Synchronization

/// Whether the client's side of one connection has closed, and the work waiting to hear it.
final class ConnectionClosure: Sendable {
    private struct State {
        var isClosed = false
        var waiters: [UInt64: CheckedContinuation<Void, Never>] = [:]
        var lastWaiter: UInt64 = 0
    }

    private let state = Mutex(State())

    var isClosed: Bool { state.withLock { $0.isClosed } }

    /// Records that the client's side has closed, and wakes every waiter. Called on the event loop.
    func close() {
        let waiting = state.withLock { state -> [CheckedContinuation<Void, Never>] in
            guard !state.isClosed else { return [] }
            state.isClosed = true
            defer { state.waiters = [:] }
            return Array(state.waiters.values)
        }
        for waiter in waiting { waiter.resume() }
    }

    /// Returns once the client's side has closed, or once the calling task is cancelled.
    func closed() async {
        let id = state.withLock { state -> UInt64 in
            state.lastWaiter += 1
            return state.lastWaiter
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let now = state.withLock { state -> Bool in
                    if state.isClosed || Task.isCancelled { return true }
                    state.waiters[id] = continuation
                    return false
                }
                if now { continuation.resume() }
            }
        } onCancel: {
            state.withLock { $0.waiters.removeValue(forKey: id) }?.resume()
        }
    }
}

/// Watches one connection for its client's side closing: the input closed, as a browser closes a
/// connection when it abandons a request, or the connection gone. Hummingbird allows half-closure,
/// so a closed input is reported as an event, and the connection stays open for the answer; a
/// client that closes its side while it waits has gone, as Go's server reads it too.
final class ClientCloseHandler: ChannelInboundHandler, RemovableChannelHandler, Sendable {
    typealias InboundIn = NIOAny

    let closure = ConnectionClosure()

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let event = event as? ChannelEvent, event == .inputClosed { closure.close() }
        context.fireUserInboundEventTriggered(event)
    }

    func channelInactive(context: ChannelHandlerContext) {
        closure.close()
        context.fireChannelInactive()
    }
}

/// The server's HTTP/1.1 channel, with a `ClientCloseHandler` in each connection's pipeline.
enum APIServer {
    static var http1: HTTPServerBuilder {
        .http1(configuration: .init(additionalChannelHandlers: [ClientCloseHandler()]))
    }
}

/// The context of every request the API answers: Hummingbird's own, and the connection the request
/// came on, so its work can stop when its client has gone.
public struct APIRequestContext: RequestContext {
    public var coreContext: CoreRequestContextStorage
    let channel: any Channel

    public init(source: ApplicationRequestContextSource) {
        coreContext = .init(source: source)
        channel = source.channel
    }

    /// Runs `work` while the request's client is connected. When the client closes its side first,
    /// `work` is cancelled, and this throws `ClientClosedConnection` once it has stopped: a search
    /// stops its statement at the progress handler's next call, usually within a millisecond. A
    /// connection with no `ClientCloseHandler`, as in the router's tests, runs `work` to its end.
    func whileClientConnected<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        guard let closure = try? await channel.pipeline.handler(type: ClientCloseHandler.self).get().closure else {
            return try await work()
        }
        return try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { try await work() }
            group.addTask {
                await closure.closed()
                return nil
            }
            if case let value?? = try await group.next() {
                group.cancelAll()
                return value
            }
            // The watch ended first: the client has gone, or this request was cancelled.
            group.cancelAll()
            _ = try? await group.next()
            if closure.isClosed { throw ClientClosedConnection() }
            throw CancellationError()
        }
    }
}

/// A request's client closed its connection before the answer, so its work was stopped.
struct ClientClosedConnection: Error, CustomStringConvertible {
    var description: String { "the client closed its connection before the answer" }
}
