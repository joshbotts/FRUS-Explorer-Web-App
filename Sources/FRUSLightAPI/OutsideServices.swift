// The two outside services the server asks for its users (PLAN's S22e): the NARA Catalog API, through the
// kit's `NARACatalogClient`, and Zotero's Web API, through the kit's `ZoteroAPIClient`. Each is asked with a
// key the server keeps (`SecretVault`, PLAN's S20c) or, for NARA, the instance's from the environment
// (`FRUS_NARA_API_KEY`), handed to the kit's client for the one request and to nothing else: no answer,
// problem, log line or cache holds it. The kit's clients ask the services' own addresses, which they fix;
// `FRUS_SERVICES_MIRROR` names a stand-in that answers in their place, as the tests and the smoke test serve
// their stubs, each service's paths under its host's name (`ServicesMirrorProtocol`). `FRUS_OFFLINE`
// refuses both, as it refuses the library's downloads.
//
// NARA's answers are kept by the query they answer, for a day, so a second user asking the same thing
// costs no call (`NARAAnswerCache`); and the calls made with the instance's key are counted against each
// user, so that one user cannot spend the instance's key for everyone (`NARAQuota`).

import FRUSCoreKit
import FRUSLightCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Synchronization

/// What the routes that ask NARA and Zotero need, beside the user's data: the sessions the kit's clients ask
/// through, the instance's key from the environment, whether the server may ask anything outside, and what it
/// keeps of NARA's answers and of each user's calls.
struct OutsideServices: Sendable {
    /// The session the NARA Catalog client asks through, and Zotero's: the services, or `FRUS_SERVICES_MIRROR`'s
    /// stand-in, or a test's stub.
    let naraSession: URLSession
    let zoteroSession: URLSession
    /// `FRUS_NARA_API_KEY`: the instance's key when the store holds none.
    let naraEnvironmentKey: String?
    /// `FRUS_OFFLINE`: nothing is asked outside.
    let offline: Bool
    let answers: NARAAnswerCache
    let quota: NARAQuota

    /// The services as the configuration names them.
    init(configuration: ServerConfiguration) {
        if let mirror = configuration.servicesMirror { ServicesMirrorProtocol.use(mirror) }
        let session = Self.session(mirrored: configuration.servicesMirror != nil)
        self.init(naraSession: session, zoteroSession: session, naraEnvironmentKey: configuration.naraAPIKey,
                  offline: configuration.offline)
    }

    init(naraSession: URLSession, zoteroSession: URLSession, naraEnvironmentKey: String? = nil, offline: Bool = false,
         answers: NARAAnswerCache = NARAAnswerCache(), quota: NARAQuota = NARAQuota()) {
        self.naraSession = naraSession
        self.zoteroSession = zoteroSession
        self.naraEnvironmentKey = naraEnvironmentKey
        self.offline = offline
        self.answers = answers
        self.quota = quota
    }

    /// A session that keeps nothing: no cookie, no cache, no credential. Through the mirror when there is one.
    static func session(mirrored: Bool) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        // In front of the session's own, which answer whatever the mirror's does not take.
        if mirrored { configuration.protocolClasses = [ServicesMirrorProtocol.self] + (configuration.protocolClasses ?? []) }
        return URLSession(configuration: configuration)
    }

    /// The hosts the kit's clients ask: the NARA Catalog's and Zotero's API's.
    static let naraHost = "catalog.archives.gov"
    static let zoteroHost = "api.zotero.org"

    /// The app's sentence about a key with the web's place for keys in it, Settings ▸ Keys, where the Mac's
    /// names its own, Settings → Connections, or Settings alone in its Zotero sentence: a sentence that names
    /// neither is the kit's, unchanged. `OutsideServicesTests` holds each sentence the server says to the
    /// place it names in the kit, so a reworded one is seen.
    static func webPlace(_ sentence: String) -> String {
        if sentence.contains(macPlace) { return sentence.replacingOccurrences(of: macPlace, with: keysPlace) }
        return sentence.replacingOccurrences(of: " in Settings first.", with: " in \(keysPlace) first.")
    }

    /// The Mac's place for keys, and the web's.
    static let macPlace = "Settings → Connections"
    static let keysPlace = "Settings ▸ Keys"

    /// `FRUS_OFFLINE`'s refusal, in the library's code.
    static func offlineProblem(_ service: String) -> APIProblem {
        APIProblem(.conflict, code: "OFFLINE",
                   detail: "This server is offline (FRUS_OFFLINE=true), so it asks \(service) nothing.")
    }
}

// MARK: - The mirror

/// `FRUS_SERVICES_MIRROR`: a request of a service's own address asked of the mirror instead, at
/// `<mirror>/<host>/<path>?<query>`, with its method, headers and body, and the mirror's answer given back as
/// the service's. Only the two services' hosts go there; the session asks no other.
final class ServicesMirrorProtocol: URLProtocol {
    /// The mirror, set once as the server starts.
    private static let mirror = Mutex<URL?>(nil)
    /// The session the mirrored requests go out on, which no protocol of ours sits in front of.
    private static let relay = URLSession(configuration: .ephemeral)

    /// The task asking the mirror, which `stopLoading()` cancels.
    private let relayed = Relayed()

    static func use(_ base: URL) { mirror.withLock { $0 = base } }

    /// `url` under `base`: its host's name, then its path and query, as the mirror's folder keeps them.
    static func mirrored(_ url: URL, under base: URL) -> URL? {
        guard let host = url.host, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let root = base.absoluteString.hasSuffix("/") ? String(base.absoluteString.dropLast()) : base.absoluteString
        guard var mirrored = URLComponents(string: root) else { return nil }
        mirrored.percentEncodedPath += "/" + host + (parts.percentEncodedPath.isEmpty ? "/" : parts.percentEncodedPath)
        mirrored.percentEncodedQuery = parts.percentEncodedQuery
        return mirrored.url
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host, [OutsideServices.naraHost, OutsideServices.zoteroHost].contains(host) else { return false }
        return mirror.withLock { $0 != nil }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let reply = Reply(self)
        guard let url = request.url, let base = Self.mirror.withLock({ $0 }), let mirrored = Self.mirrored(url, under: base) else {
            reply.fail(URLError(.unsupportedURL))
            return
        }
        var forwarded = URLRequest(url: mirrored, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: request.timeoutInterval)
        forwarded.httpMethod = request.httpMethod
        for (name, value) in request.allHTTPHeaderFields ?? [:] { forwarded.setValue(value, forHTTPHeaderField: name) }
        forwarded.httpBody = request.httpBody ?? request.httpBodyStream.map(Self.drain)
        let relayed = self.relayed
        // Off the session's own queue, which this call holds: on Linux a task made here for the relay's
        // session waits for a queue the two sessions' queues share, a trap in `dispatch_sync`.
        DispatchQueue.global().async { [forwarded] in
            let dataTask = Self.relay.dataTask(with: forwarded) { data, response, error in
                if !relayed.stopped { Self.give(data, response, error, to: reply) }
            }
            if relayed.begin(dataTask) { dataTask.resume() }
        }
    }

    override func stopLoading() {
        relayed.stop()
    }

    /// The mirror's answer given to the protocol's client as the service's, at the address the session asked.
    private static func give(_ data: Data?, _ response: URLResponse?, _ error: (any Error)?, to reply: Reply) {
        if let error { reply.fail(error); return }
        var headers: [String: String] = [:]
        for (name, value) in (response as? HTTPURLResponse)?.allHeaderFields ?? [:] {
            if let name = name as? String, let value = value as? String { headers[name] = value }
        }
        guard let answer = response as? HTTPURLResponse, let url = reply.url,
              let given = HTTPURLResponse(url: url, statusCode: answer.statusCode, httpVersion: "HTTP/1.1",
                                          headerFields: headers) else {
            reply.fail(URLError(.badServerResponse))
            return
        }
        reply.answer(given, data ?? Data())
    }

    /// A body the session gave as a stream, read whole.
    private static func drain(_ stream: InputStream) -> Data {
        var data = Data()
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    /// The task asking the mirror, which `stopLoading()` cancels, even before it has begun.
    private final class Relayed: Sendable {
        private let state = Mutex<(task: URLSessionDataTask?, stopped: Bool)>((nil, false))

        var stopped: Bool { state.withLock { $0.stopped } }

        /// Keeps the task to cancel, unless the request was stopped first, when the task never begins.
        func begin(_ task: URLSessionDataTask) -> Bool {
            state.withLock { held in
                guard !held.stopped else { return false }
                held.task = task
                return true
            }
        }

        func stop() {
            state.withLock { held in
                held.stopped = true
                held.task?.cancel()
            }
        }
    }

    /// What the mirror's answer is handed to: the protocol's client, from the relay's queue.
    private final class Reply: @unchecked Sendable {
        let owner: ServicesMirrorProtocol
        init(_ owner: ServicesMirrorProtocol) { self.owner = owner }
        var url: URL? { owner.request.url }
        func fail(_ error: any Error) { owner.client?.urlProtocol(owner, didFailWithError: error) }
        func answer(_ response: HTTPURLResponse, _ data: Data) {
            owner.client?.urlProtocol(owner, didReceive: response, cacheStoragePolicy: .notAllowed)
            owner.client?.urlProtocol(owner, didLoad: data)
            owner.client?.urlProtocolDidFinishLoading(owner)
        }
    }
}

// MARK: - NARA's answers

/// One NARA Catalog record as the app's rows show it (`NARACatalogResult`): its NAID, title, link, scope note,
/// record group, series and dates. Nothing of the request that found it.
public struct NARACatalogRecord: Codable, Equatable, Sendable {
    public var naId: String
    public var title: String
    public var catalogURL: String
    public var scopeNote: String?
    public var recordGroupNumber: String?
    public var seriesTitle: String?
    public var dateRange: String?

    init(_ result: NARACatalogResult) {
        naId = result.naId
        title = result.title
        catalogURL = result.catalogURL.absoluteString
        scopeNote = result.scopeNote
        recordGroupNumber = result.recordGroupNumber
        seriesTitle = result.seriesTitle
        dateRange = result.dateRange
    }
}

/// NARA's answers, by the query each answers, for a day, the most recently used 1,000 at most. The query is
/// the route and its fields as the request named them, never the key it was asked with, so one user's answer
/// serves the next, whatever key either has; an answer kept is public catalogue data alone. Kept in memory,
/// so a restart empties it.
actor NARAAnswerCache {
    static let lifetime: TimeInterval = 24 * 60 * 60
    static let capacity = 1_000

    private var kept: [String: (records: [NARACatalogRecord], at: Date)] = [:]
    /// The queries, least recently used first.
    private var order: [String] = []
    let capacity: Int
    let lifetime: TimeInterval

    init(capacity: Int = NARAAnswerCache.capacity, lifetime: TimeInterval = NARAAnswerCache.lifetime) {
        self.capacity = capacity
        self.lifetime = lifetime
    }

    /// The answer kept for `query`, if it is younger than a day.
    func answer(to query: String, at now: Date) -> [NARACatalogRecord]? {
        guard let entry = kept[query] else { return nil }
        guard now.timeIntervalSince(entry.at) < lifetime else {
            kept[query] = nil
            order.removeAll { $0 == query }
            return nil
        }
        order.removeAll { $0 == query }
        order.append(query)
        return entry.records
    }

    func keep(_ records: [NARACatalogRecord], for query: String, at now: Date) {
        kept[query] = (records, now)
        order.removeAll { $0 == query }
        order.append(query)
        while order.count > capacity { kept[order.removeFirst()] = nil }
    }

    var count: Int { kept.count }
}

/// The calls each user has made to NARA with the instance's key in the last day, of `limit` at most: a user's
/// own key is theirs, and NARA limits it, so none of its calls are counted. A call is one NARA answered (the
/// kit's client tells its key provider of each), and a lot's lookup may make up to four. A search is admitted
/// while the user's calls and their searches still running are fewer than the limit, so that searches sent at
/// once cannot each pass before any is counted. Kept in memory, so a restart empties it, and each server
/// sharing a store counts its own.
actor NARAQuota {
    static let callsPerDay = 100
    static let window: TimeInterval = 24 * 60 * 60

    let limit: Int
    private var calls: [String: [Date]] = [:]
    /// Each user's searches admitted and not yet ended.
    private var running: [String: Int] = [:]

    init(limit: Int = NARAQuota.callsPerDay) {
        self.limit = limit
    }

    /// How many calls `user` has made in the day before `now`.
    func used(by user: String, at now: Date) -> Int {
        let recent = (calls[user] ?? []).filter { now.timeIntervalSince($0) < Self.window }
        calls[user] = recent.isEmpty ? nil : recent
        return recent.count
    }

    /// Whether `user` may search now, holding a place for the search until `end(_:)`.
    func admit(_ user: String, at now: Date) -> Bool {
        guard used(by: user, at: now) + running[user, default: 0] < limit else { return false }
        running[user, default: 0] += 1
        return true
    }

    /// A search `admit(_:at:)` let through has ended, however it ended.
    func end(_ user: String) {
        let left = running[user, default: 0] - 1
        running[user] = left > 0 ? left : nil
    }

    func record(_ user: String, at now: Date) {
        calls[user, default: []].append(now)
    }
}
