// The NARA proxy, Look Up and Send to Zotero Library through the router (PLAN's S22e), over a stand-in of
// each service that answers from the request alone, with no real key anywhere (the owner's word of 14
// November: stubs alone). The done-when's first part: a lookup through the API gives the kit's client's
// answer over a stub of the Catalog API, and the second time from the cache; its second: a request without a
// key says so in the app's words, with the web's place for keys. Beside them: whose key a search uses, the
// quota the instance's key is counted against, NARA's and Zotero's refusals in the kit's sentences, FRUS_OFFLINE,
// a key in no answer, problem or log line, a document's and a collection's send with the user's tags and notes,
// Look Up's candidates as the kit's analyzer reads them, and FRUS_SERVICES_MIRROR's stand-in, asked as a
// server asks it.

import FRUSCoreKit
import FRUSLightTestSupport
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import Logging
import Synchronization
import Testing

@testable import FRUSLightAPI
@testable import FRUSLightCore

// MARK: - The services' stand-in

/// The NARA Catalog's and Zotero's stand-in: it answers from the request alone, by the key it carries, and
/// keeps each request under that key, so that tests running beside each other, each with keys of its own, see
/// their own. A NARA key names its answer: `…-ok-…` the records a query finds, `…-empty-…` none, `…-403-…`,
/// `…-429-…` and `…-500-…` those statuses, `…-down-…` no answer at all. A Zotero key: `…-writer-…` an account that
/// writes, `…-reader-…`
/// one that cannot, anything else a 403.
final class ServiceStub: URLProtocol {
    struct Asked: Sendable {
        let method: String
        let url: URL
        let headers: [String: String]
        let body: Data
    }

    private static let asked = Mutex<[String: [Asked]]>([:])
    /// The keys whose answers wait until a test lets them go, with the answers waiting.
    private static let held = Mutex<[String: [@Sendable () -> Void]]>([:])

    /// What the stand-in was asked with `key`.
    static func requests(with key: String) -> [Asked] { asked.withLock { $0[key] ?? [] } }

    /// From now on, the answers to requests with `key` wait until `release(_:)`.
    static func hold(_ key: String) { held.withLock { $0[key] = $0[key] ?? [] } }

    /// Gives the answers held for `key`, and answers its later requests at once.
    static func release(_ key: String) {
        let waiting = held.withLock { $0.removeValue(forKey: key) } ?? []
        for answer in waiting { answer() }
    }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ServiceStub.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let url = request.url!
        let headers = request.allHTTPHeaderFields ?? [:]
        let body = request.httpBody ?? request.httpBodyStream.map(Self.drain) ?? Data()
        let key = Self.key(of: url, headers: headers)
        if let key {
            Self.asked.withLock { $0[key, default: []].append(Asked(method: request.httpMethod ?? "GET", url: url, headers: headers, body: body)) }
        }
        let reply = Reply(self)
        let method = request.httpMethod ?? "GET"
        let answer: @Sendable () -> Void = {
            if key?.contains("-down-") == true {
                reply.fail(URLError(.cannotConnectToHost, userInfo: [NSURLErrorFailingURLErrorKey: url]))
                return
            }
            let (status, text) = Self.answer(url: url, key: key, method: method, body: body)
            let type = text.hasPrefix("<") ? "text/html" : "application/json"
            reply.answer(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                         headerFields: ["Content-Type": type])!, Data(text.utf8))
        }
        let waits = key.map { key in Self.held.withLock { held in
            guard held[key] != nil else { return false }
            held[key]?.append(answer)
            return true
        } } ?? false
        if !waits { answer() }
    }

    /// What an answer is handed to: the protocol's client, now or once a test lets a held answer go.
    private final class Reply: @unchecked Sendable {
        let owner: ServiceStub
        init(_ owner: ServiceStub) { self.owner = owner }
        func fail(_ error: any Error) { owner.client?.urlProtocol(owner, didFailWithError: error) }
        func answer(_ response: HTTPURLResponse, _ data: Data) {
            owner.client?.urlProtocol(owner, didReceive: response, cacheStoragePolicy: .notAllowed)
            owner.client?.urlProtocol(owner, didLoad: data)
            owner.client?.urlProtocolDidFinishLoading(owner)
        }
    }

    /// A NARA Catalog answer with one series, in the shape NARA's live answers take (FRUS-Explorer#1908): the record
    /// under `body.hits.hits[]._source`, with no record group of its own, its record group a number on the member of
    /// its `ancestors` at `recordGroup` level. `fields` are the record's further fields, as JSON members.
    static func liveAnswer(naId: Int, title: String, recordGroup: String, years: (Int, Int), fields: String?) -> String {
        """
        {"body": {"hits": {"total": {"value": 1, "relation": "eq"}, "max_score": null, "hits": [{"_index": "nac-records4",
         "_id": "\(naId)", "_score": 3, "_source": {"record": {"naId": \(naId), "title": "\(title)", "levelOfDescription": "series",
         "recordType": "description", "inclusiveStartDate": {"year": \(years.0), "logicalDate": "\(years.0)-01-01"},
         "inclusiveEndDate": {"year": \(years.1), "logicalDate": "\(years.1)-12-31"},\(fields.map { " \($0)," } ?? "")
         "ancestors": [{"distance": 1, "levelOfDescription": "recordGroup", "recordGroupNumber": \(recordGroup), "naId": 388}]}}}]}}}
        """
    }

    static func key(of url: URL, headers: [String: String]) -> String? {
        func header(_ name: String) -> String? { headers.first { $0.key.lowercased() == name }?.value }
        if let nara = header("x-api-key") { return nara }
        if url.path.hasPrefix("/keys/") { return url.lastPathComponent }
        return header("authorization").map { $0.replacingOccurrences(of: "Bearer ", with: "") }
    }

    static func answer(url: URL, key: String?, method: String, body: Data) -> (Int, String) {
        let key = key ?? ""
        if url.host == OutsideServices.naraHost {
            if key.contains("-403-") { return (403, "{}") }
            if key.contains("-429-") { return (429, "{}") }
            if key.contains("-500-") { return (500, "{}") }
            if key.contains("-empty-") { return (200, #"{"body": {"hits": {"total": {"value": 0, "relation": "eq"}, "hits": []}}}"#) }
            // The Catalog website's page, which NARA's CDN served for every API request on 2026-11-16 (FRUS-Explorer#1908).
            if key.contains("-html-") {
                return (200, #"<!doctype html><html lang="en"><head><title>National Archives Catalog</title></head><body></body></html>"#)
            }
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            func item(_ name: String) -> String? { query.first { $0.name == name }?.value }
            if let lot = item("variantControlNumber_is") {
                // A series that carries the lot it was asked for, in the record group asked: the acceptance test's. In the
                // live answer's shape (FRUS-Explorer#1908's fixture, `NARALiveRecordGroupTests.liveAnswer`): the record
                // under `body.hits.hits[]._source`, its record group on its `recordGroup` ancestor alone.
                let group = item("description.recordGroupNumber") ?? "59"
                return (200, Self.liveAnswer(naId: 4567, title: "Records Relating to Lot \(lot)", recordGroup: group, years: (1961, 1963),
                                             fields: #""scopeAndContentNote": "Subject files.", "variantControlNumbers": [{"note": "This is a Department of State LOT file number.", "number": "\#(lot)", "type": "Agency-Assigned Identifier"}]"#))
            }
            return (200, Self.liveAnswer(naId: 1240, title: "Central Decimal Files", recordGroup: "59", years: (1910, 1963), fields: nil))
        }
        if url.host == OutsideServices.zoteroHost {
            if url.path.hasPrefix("/keys/") {
                if key.contains("-writer-") {
                    return (200, #"{"userID": 4210, "username": "frus-stub", "access": {"user": {"library": true, "write": true, "notes": true}}}"#)
                }
                if key.contains("-reader-") {
                    return (200, #"{"userID": 4211, "username": "frus-stub", "access": {"user": {"library": true, "write": false}}}"#)
                }
                return (403, "{}")
            }
            guard method == "POST", url.path.hasPrefix("/users/4210/") else { return (404, "{}") }
            // Every object written is taken, keyed by its index, as Zotero's write answer keys them.
            let count = ((try? JSONSerialization.jsonObject(with: body)) as? [Any])?.count ?? 0
            let prefix = url.path.hasSuffix("/collections") ? "COLL" : "ITEM"
            let successful = (0..<count).map { #""\#($0)": {"key": "\#(prefix)\#(String(format: "%04d", $0))", "version": 1}"# }
            return (200, #"{"successful": {\#(successful.joined(separator: ", "))}, "failed": {}}"#)
        }
        return (404, "{}")
    }

    static func drain(_ stream: InputStream) -> Data {
        var data = Data()
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// Every line logged, kept to be searched for a key.
final class CapturedLogs: Sendable {
    let lines = Mutex<[String]>([])

    var logger: Logger {
        var logger = Logger(label: "s22e-test") { _ in Handler(sink: self) }
        logger.logLevel = .trace
        return logger
    }

    func contains(_ text: String) -> Bool { lines.withLock { $0.contains { $0.contains(text) } } }

    struct Handler: LogHandler {
        let sink: CapturedLogs
        var metadata: Logger.Metadata = [:]
        var metadataProvider: Logger.MetadataProvider?
        var logLevel: Logger.Level = .trace

        subscript(metadataKey key: String) -> Logger.Metadata.Value? {
            get { metadata[key] }
            set { metadata[key] = newValue }
        }

        func log(event: LogEvent) {
            sink.lines.withLock { $0.append("\(event.level) \(event.message) \(event.metadata ?? [:]) \(metadata)") }
        }
    }
}

/// A server with user data, or none, whose outside services are the stand-in's, with the instance's key from
/// the environment, offline or not, and a quota of `limit` calls a day; with `auth`, the users a proxy names.
struct OutsideFixture {
    let base: UserDataFixture
    let services: UserDataServices
    let logs = CapturedLogs()

    init(userData: Bool = true, volumes: [String] = [], indexed: Bool = false, environmentKey: String? = nil, offline: Bool = false,
         limit: Int = NARAQuota.callsPerDay, auth: ServerConfiguration.Auth = .none) async throws {
        base = try await UserDataFixture(userData: userData, volumes: volumes, indexed: indexed, auth: auth,
                                         trustedProxies: auth == .header ? SignInTests.loopback : [])
        var services = base.services
        services.outside = OutsideServices(naraSession: ServiceStub.session, zoteroSession: ServiceStub.session,
                                           naraEnvironmentKey: environmentKey, offline: offline, quota: NARAQuota(limit: limit))
        self.services = services
    }

    var app: some ApplicationProtocol {
        Application(router: ServedRouter(base: .root, router: buildRouter(
            state: base.server.state, resources: base.server.resources, reader: base.server.reader, userData: services,
            base: .root, logger: logs.logger)), logger: logs.logger)
    }

    /// Stores `key` as `name` for the user or the instance, through the vault, as the routes of S20c store one.
    func store(_ key: String, as name: SecretName, for owner: SecretOwner) throws {
        _ = try services.secrets.set(key, named: name, for: owner, at: UserDataFixture.now)
    }
}

/// A key's records in the kit's client's own answer, over the stand-in: what the proxy must give.
private struct FixedKey: NARACatalogKeyProvider {
    let key: String
    func naraCatalogAPIKey() async throws -> String? { key }
}

private func body(_ response: TestResponse) -> String { String(buffer: response.body) }

@Suite struct OutsideServicesTests {
    static let missingKey = "A NARA Catalog API key is required to search for lot files and Presidential Library records. Add your key in Settings ▸ Keys."

    // MARK: The done-when

    /// The done-when's first part: Look Up's search and Source Explorer's through the API give the kit's client's
    /// answer over the stand-in, the key sent to it alone, and each a second time from the cache, which asks
    /// nothing more.
    @Test func aLookupThroughTheAPIIsTheClientsAnswerAndTheSecondFromTheCache() async throws {
        let key = "stub-nara-ok-cache"
        let fixture = try await OutsideFixture()
        defer { withExtendedLifetime(fixture) {} }
        try fixture.store(key, as: .nara, for: .user("owner"))
        let client = NARACatalogClient(keyProvider: FixedKey(key: key), urlSession: ServiceStub.session)
        let kits = try await LookupStrategy.lotFileRG59.execute(query: "66 D 204", client: client).map(NARACatalogRecord.init)
        let kitsLot = try await client.resolveLotFileVariants(lotNumber: "66 D 204", recordGroup: "59").map(NARACatalogRecord.init)
        #expect(!kits.isEmpty && kits.first?.title == "Records Relating to Lot 66D204" && kits.first?.dateRange == "1961–1963")
        let before = ServiceStub.requests(with: key).count

        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let lookUp = #"{"strategy": "lotFileRG59", "query": "  66 D 204\n"}"#
            let first = try await browser.send(.post, "/api/v1/nara/search", lookUp)
            #expect(first.status == .ok && first.headers[.cacheControl] == "no-store")
            #expect(try decode(NARASearchAnswer.self, first) == NARASearchAnswer(results: kits, cached: false))
            let asked = ServiceStub.requests(with: key).count - before
            #expect(asked == 1, "the first variant found the lot")
            let second = try await browser.send(.post, "/api/v1/nara/search", lookUp)
            #expect(try decode(NARASearchAnswer.self, second) == NARASearchAnswer(results: kits, cached: true))
            #expect(ServiceStub.requests(with: key).count - before == asked, "the second from the cache, NARA asked nothing")

            // Source Explorer's query for a lot, as its NARA Catalog section names it: its own answer, kept as well.
            let sources = #"{"route": "lotVariants", "lot": "66 D 204", "recordGroup": "59"}"#
            #expect(try decode(NARASearchAnswer.self, try await browser.send(.post, "/api/v1/nara/search", sources))
                == NARASearchAnswer(results: kitsLot, cached: false))
            #expect(try decode(NARASearchAnswer.self, try await browser.send(.post, "/api/v1/nara/search", sources)).cached)
            // The key went to NARA's stand-in in x-api-key, and nowhere else: not in an answer, nor the log.
            #expect(ServiceStub.requests(with: key).allSatisfy { $0.headers.contains { $0.key.lowercased() == "x-api-key" && $0.value == key } })
            #expect(![first, second].contains { body($0).contains(key) })
            let status = try await browser.get("/api/v1/nara")
            #expect(try decode(NARAStatus.self, status) == NARAStatus(key: "user", quota: nil, offline: false) && !body(status).contains(key))
        }
        #expect(!fixture.logs.contains(key))
        #expect(await fixture.services.outside.answers.count == 2)
    }

    /// The done-when's second part: a search with no key, the user's or the instance's, and a send with no Zotero key,
    /// each say so in the app's words with the web's place for keys, and ask the service nothing.
    @Test func aRequestWithoutAKeySaysSoInTheAppsWords() async throws {
        let fixture = try await OutsideFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            #expect(try decode(NARAStatus.self, try await browser.get("/api/v1/nara")) == NARAStatus(key: nil, quota: nil, offline: false))
            let search = try await browser.send(.post, "/api/v1/nara/search", #"{"strategy": "keyword", "query": "Khrushchev"}"#)
            let refused = try problem(search, .conflict)
            #expect(refused.code == "NARA_KEY_REQUIRED" && refused.detail == Self.missingKey)
            let send = try await browser.send(.post, "/api/v1/me/volumes/frus1961-63v06/documents/d3/zotero")
            let unsent = try problem(send, .conflict)
            #expect(unsent.code == "ZOTERO_KEY_REQUIRED" && unsent.detail == "Connect a Zotero account in Settings ▸ Keys first.")
        }
        // A server that keeps no user data has no Settings ▸ Keys: its sentence names the server's key.
        let readOnly = try await OutsideFixture(userData: false)
        defer { withExtendedLifetime(readOnly) {} }
        try await readOnly.app.test(.router) { client in
            let search = try await Browser(client: client).send(.post, "/api/v1/nara/search", #"{"strategy": "keyword", "query": "Laos"}"#)
            let refused = try problem(search, .conflict)
            #expect(refused.code == "NARA_KEY_REQUIRED" && refused.detail.contains("FRUS_NARA_API_KEY") && !refused.detail.contains("Settings ▸ Keys"))
        }
    }

    /// The kit's sentences the server says, each naming the Mac's place for keys where the web names its own: a
    /// sentence reworded upstream fails here before it reaches a reader with the Mac's place in it.
    @Test func theKitsSentencesNameTheWebsPlaceForKeys() {
        let nara: [NARACatalogError] = [.missingAPIKey, .apiKeyRejected]
        for error in nara {
            let sentence = error.errorDescription ?? ""
            #expect(sentence.components(separatedBy: OutsideServices.macPlace).count == 2, "\(sentence)")
            #expect(OutsideServices.webPlace(sentence) == sentence.replacingOccurrences(of: "Settings → Connections", with: "Settings ▸ Keys"))
        }
        #expect(NARARoutes.problem(.missingAPIKey).detail == Self.missingKey)
        #expect(NARARoutes.problem(.apiKeyRejected).detail
            == "NARA Catalog API key was rejected (HTTP 403). Check the key in Settings ▸ Keys.")
        #expect(ZoteroAPIError.missingCredentials.errorDescription == "Connect a Zotero account in Settings first.")
        #expect(ZoteroRoutes.problem(.missingCredentials).detail == "Connect a Zotero account in Settings ▸ Keys first.")
        // The rest name no place, and pass unchanged.
        for error in [ZoteroAPIError.invalidKey, .insufficientPermissions, .network("x"), .http(500), .decoding, .rateLimited(retryAfter: 1)] {
            #expect(ZoteroRoutes.problem(error).detail == error.errorDescription)
        }
        for error in [NARACatalogError.rateLimited, .decodingError, .unexpectedResponse(statusCode: 502), .networkError(underlying: URLError(.timedOut))] {
            #expect(NARARoutes.problem(error).detail == error.errorDescription)
        }
    }

    // MARK: Whose key

    /// The user's own key first, then the instance's an admin stored, then FRUS_NARA_API_KEY; on a server that keeps
    /// no user data the group still answers, with the instance's.
    @Test func theUsersKeyComesFirstThenTheInstances() async throws {
        let (own, stored, environment) = ("stub-nara-ok-own", "stub-nara-ok-stored", "stub-nara-ok-environment")
        let fixture = try await OutsideFixture(environmentKey: environment)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            func searched(_ query: String) async throws -> TestResponse {
                try await browser.send(.post, "/api/v1/nara/search", #"{"strategy": "keywordRG59", "query": "\#(query)"}"#)
            }
            #expect(try decode(NARAStatus.self, try await browser.get("/api/v1/nara")).key == "instance")
            #expect(try await searched("environment").status == .ok && ServiceStub.requests(with: environment).count == 1)
            try fixture.store(stored, as: .nara, for: .instance)
            #expect(try await searched("stored").status == .ok && ServiceStub.requests(with: stored).count == 1)
            try fixture.store(own, as: .nara, for: .user("owner"))
            #expect(try decode(NARAStatus.self, try await browser.get("/api/v1/nara")) == NARAStatus(key: "user", quota: nil, offline: false))
            #expect(try await searched("own").status == .ok && ServiceStub.requests(with: own).count == 1)
            #expect(ServiceStub.requests(with: environment).count == 1 && ServiceStub.requests(with: stored).count == 1)
        }

        // With FRUS_USER_DATA=off: the group answers, and the instance's key serves, the user's own unread.
        let readOnly = try await OutsideFixture(userData: false, environmentKey: "stub-nara-ok-readonly")
        defer { withExtendedLifetime(readOnly) {} }
        try readOnly.store("stub-nara-ok-unread", as: .nara, for: .user("owner"))
        try await readOnly.app.test(.router) { client in
            let browser = Browser(client: client)
            let status = try decode(NARAStatus.self, try await browser.get("/api/v1/nara"))
            #expect(status.key == "instance" && status.quota == NARAStatus.Quota(used: 0, limit: NARAQuota.callsPerDay))
            let found = try await browser.send(.post, "/api/v1/nara/search", #"{"strategy": "keyword", "query": "Laos"}"#)
            #expect(found.status == .ok && ServiceStub.requests(with: "stub-nara-ok-readonly").count == 1)
            #expect(ServiceStub.requests(with: "stub-nara-ok-unread").isEmpty)
            // The rest of the user's data stays refused.
            #expect(problemCode(try await browser.get("/api/v1/me/secrets")) == "USER_DATA_OFF")
        }
    }

    /// The calls a user makes with the instance's key, counted against them: past the quota a search is refused,
    /// but one the cache answers is not, and a user's own key is not counted at all.
    @Test func theInstancesKeyIsCountedAgainstEachUser() async throws {
        let shared = "stub-nara-ok-quota"
        let fixture = try await OutsideFixture(environmentKey: shared, limit: 2)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            func searched(_ query: String) async throws -> TestResponse {
                try await browser.send(.post, "/api/v1/nara/search", #"{"strategy": "keywordRG84", "query": "\#(query)"}"#)
            }
            // A lot's search holds the four calls it can make, more than the two allowed, and asks nothing.
            let lot = try problem(try await browser.send(.post, "/api/v1/nara/search", #"{"strategy": "lotFileRG59", "query": "66 D 204"}"#),
                                  .tooManyRequests)
            #expect(lot.code == "NARA_QUOTA_REACHED")
            #expect(try await searched("one").status == .ok)
            #expect(try await searched("two").status == .ok)
            #expect(try decode(NARAStatus.self, try await browser.get("/api/v1/nara")).quota == NARAStatus.Quota(used: 2, limit: 2))
            let refused = try problem(try await searched("three"), .tooManyRequests)
            #expect(refused.code == "NARA_QUOTA_REACHED" && refused.detail.contains("Settings ▸ Keys"))
            #expect(ServiceStub.requests(with: shared).count == 2, "the refusal asked nothing")
            #expect(try decode(NARASearchAnswer.self, try await searched("one")).cached, "the cache still answers")
            // A user's own key is NARA's to limit, not the server's.
            try fixture.store("stub-nara-ok-own-quota", as: .nara, for: .user("owner"))
            #expect(try await searched("three").status == .ok)
            #expect(try await searched("four").status == .ok)
        }
        // Each user's own count, and a day's window.
        let quota = NARAQuota(limit: 1)
        let day = Date(timeIntervalSince1970: 1_792_800_000)
        let one = try #require(await quota.admit("a", cost: 1, at: day))
        await quota.spend(one, at: day)
        await quota.end(one)
        #expect(await quota.used(by: "a", at: day) == 1)
        #expect(await quota.used(by: "b", at: day) == 0)
        #expect(await quota.used(by: "a", at: day.addingTimeInterval(NARAQuota.window)) == 0)
        // Searches sent at once each hold the most calls they can make until they end, so none passes on a count
        // not yet made; each call made is counted and held no longer, and at the end what was not made is let go.
        let held = NARAQuota(limit: 5)
        let lot = try #require(await held.admit("a", cost: 4, at: day))
        #expect(await held.admit("a", cost: 4, at: day) == nil)
        let single = try #require(await held.admit("a", cost: 1, at: day))
        #expect(await held.admit("a", cost: 1, at: day) == nil)
        #expect(await held.admit("b", cost: 4, at: day) != nil)
        await held.spend(lot, at: day)
        #expect(await held.used(by: "a", at: day) == 1, "a call made is counted")
        #expect(await held.held(by: "a") == 4, "and held no longer: the lot's three left and the single's one")
        await held.end(lot)
        #expect(await held.held(by: "a") == 1, "the lot's three calls it did not make are let go")
        await held.end(single)
        #expect(await held.admit("a", cost: 4, at: day) != nil)
        #expect(await held.admit("a", cost: 1, at: day) == nil)
    }

    /// Finding 2 of S22e's follow-up: a call NARA refuses, or never answers, is counted against the user as one it
    /// answers is, since the kit's client tells its provider only of a 2xx. Before, a user whose searches failed
    /// spent the instance's key without end.
    @Test func aCallNARARefusesOrNeverAnswersIsCountedToo() async throws {
        for refusing in ["stub-nara-500-quota", "stub-nara-403-quota", "stub-nara-down-quota"] {
            let fixture = try await OutsideFixture(environmentKey: refusing, limit: 2)
            defer { withExtendedLifetime(fixture) {} }
            try await fixture.app.test(.router) { client async throws in
                let browser = Browser(client: client)
                func searched(_ query: String) async throws -> TestResponse {
                    try await browser.send(.post, "/api/v1/nara/search", #"{"strategy": "keywordRG59", "query": "\#(query)"}"#)
                }
                #expect(try await searched("one").status != .ok)
                #expect(try await searched("two").status != .ok)
                #expect(try decode(NARAStatus.self, try await browser.get("/api/v1/nara")).quota == NARAStatus.Quota(used: 2, limit: 2), "\(refusing)")
                #expect(try problem(try await searched("three"), .tooManyRequests).code == "NARA_QUOTA_REACHED", "\(refusing)")
                #expect(ServiceStub.requests(with: refusing).count == 2, "the third asked nothing")
            }
            #expect(await fixture.services.outside.quota.held(by: "owner") == 0, "a refused search holds nothing once it has ended")
        }
        // A lot's search that NARA refuses at its first spelling makes one call, and is counted one.
        let lot = try await OutsideFixture(environmentKey: "stub-nara-429-lot", limit: 4)
        defer { withExtendedLifetime(lot) {} }
        try await lot.app.test(.router) { client in
            let browser = Browser(client: client)
            let refused = try await browser.send(.post, "/api/v1/nara/search", #"{"strategy": "lotFileRG59", "query": "66 D 204"}"#)
            #expect(try problem(refused, .serviceUnavailable).code == "NARA_RATE_LIMITED")
            #expect(try decode(NARAStatus.self, try await browser.get("/api/v1/nara")).quota == NARAStatus.Quota(used: 1, limit: 4))
        }
    }

    /// A NARA answer of 200 whose body is not JSON, the page NARA's CDN served for every API request on 2026-11-16, is an
    /// error and not "no records" since the kit's FRUS-Explorer#1908: the proxy answers 502 in the kit's sentence and
    /// keeps nothing, so a second search asks NARA again; each call is counted against the user as it is made, as every
    /// call the server makes with its key is, NARA's answer or not. A lot's lookup over the live shape, its record group
    /// on the record group's ancestor alone, resolves.
    @Test func aPageThatIsNotJSONIsAnErrorNotAnEmptyAnswer() async throws {
        let fixture = try await OutsideFixture(environmentKey: "stub-nara-html-quota", limit: 4)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let search = #"{"strategy": "keywordRG59", "query": "Laos"}"#
            for round in 1...2 {
                let refused = try problem(try await browser.send(.post, "/api/v1/nara/search", search), .badGateway)
                #expect(refused.code == "NARA_UNEXPECTED_ANSWER" && refused.detail == "Could not interpret the NARA Catalog response.")
                #expect(ServiceStub.requests(with: "stub-nara-html-quota").count == round, "each search asks NARA")
            }
            #expect(try decode(NARAStatus.self, try await browser.get("/api/v1/nara")).quota == NARAStatus.Quota(used: 2, limit: 4),
                    "each call made is counted")
            #expect(await fixture.services.outside.answers.count == 0)
            // The live shape: the lot resolves through its record group's ancestor, in one call, which is counted.
            try fixture.store("stub-nara-ok-live", as: .nara, for: .user("owner"))
            let lot = try decode(NARASearchAnswer.self, try await browser.send(
                .post, "/api/v1/nara/search", #"{"route": "lotVariants", "lot": "63 D 351", "recordGroup": "59"}"#))
            #expect(lot.results.map(\.naId) == ["4567"] && lot.results.first?.recordGroupNumber == "59", "\(lot)")
            #expect(ServiceStub.requests(with: "stub-nara-ok-live").count == 1)
        }
    }

    // MARK: S22e's follow-up

    /// Finding 1: an answer is kept for the user who asked alone. Another user's same search asks NARA itself, and is
    /// not answered as `cached`, nor sooner, nor left uncounted, so nothing tells them what was searched; each user's
    /// own answer serves them again.
    @Test func eachUsersAnswersAreTheirOwn() async throws {
        let shared = "stub-nara-ok-tenancy"
        let fixture = try await OutsideFixture(environmentKey: shared, auth: .header)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let ada = Browser(client: client, user: "ada")
            let bea = Browser(client: client, user: "bea")
            let search = #"{"strategy": "keywordRG59", "query": "Berlin contingency planning"}"#
            func asked(_ browser: Browser) async throws -> NARASearchAnswer {
                try decode(NARASearchAnswer.self, try await browser.send(.post, "/api/v1/nara/search", search))
            }
            let first = try await asked(ada)
            #expect(!first.cached && !first.results.isEmpty && ServiceStub.requests(with: shared).count == 1)
            let others = try await asked(bea)
            #expect(!others.cached, "another user's same search is not told that it was asked")
            #expect(others.results == first.results && ServiceStub.requests(with: shared).count == 2, "it asks NARA itself")
            #expect(try decode(NARAStatus.self, try await bea.get("/api/v1/nara")).quota?.used == 1, "and is counted")
            #expect(try await asked(ada).cached)
            #expect(try await asked(bea).cached)
            #expect(ServiceStub.requests(with: shared).count == 2, "each user's own answer served them again")
        }
        #expect(await fixture.services.outside.answers.count == 2)
        // The key holds the user and the search, each part after its length, so that no two share one.
        let call = try NARARoutes.Call(NARASearch(route: "lotVariants", lot: "1\u{1F}2", recordGroup: "59"))
        let crafted = try NARARoutes.Call(NARASearch(route: "lotVariants", lot: "2", recordGroup: "59\u{1F}1"))
        #expect(call.cacheKey(for: "ada") != call.cacheKey(for: "bea"))
        #expect(call.cacheKey(for: "ada") != crafted.cacheKey(for: "ada"))
        #expect(!call.cacheKey(for: "ada").contains("stub-nara"))
    }

    /// Finding 3: the same search asked again while it runs waits for the one under way, which asks NARA once and
    /// holds the quota once: four sent at once with the instance's key, on a quota of one call, are each answered.
    @Test func aSearchAskedAgainWhileItRunsWaitsForIt() async throws {
        let shared = "stub-nara-ok-at-once"
        let fixture = try await OutsideFixture(environmentKey: shared, limit: 1)
        defer { withExtendedLifetime(fixture) {} }
        ServiceStub.hold(shared)
        defer { ServiceStub.release(shared) }
        let answers = fixture.services.outside.answers
        try await fixture.app.test(.router) { client in
            let token = try await Browser(client: client).me().csrfToken
            let search = #"{"strategy": "keywordRG84", "query": "Saigon"}"#
            let found = try await withThrowingTaskGroup(of: NARASearchAnswer.self) { group in
                for _ in 0..<4 {
                    group.addTask {
                        try decode(NARASearchAnswer.self, try await Browser(client: client).send(.post, "/api/v1/nara/search", search, token: token))
                    }
                }
                // The first asks NARA, whose answer the stand-in holds, and the other three wait for it: both seen before
                // the answer is let go, the search's request reaching the stand-in later than the joins under load.
                var waited = 0
                while waited < 1_500, await answers.joined < 3 || ServiceStub.requests(with: shared).isEmpty {
                    try await Task.sleep(for: .milliseconds(10))
                    waited += 1
                }
                #expect(await answers.joined == 3)
                #expect(ServiceStub.requests(with: shared).count == 1)
                ServiceStub.release(shared)
                return try await group.reduce(into: [NARASearchAnswer]()) { $0.append($1) }
            }
            #expect(found.count == 4 && found.allSatisfy { $0.results == found[0].results } && !found[0].results.isEmpty)
            #expect(found.filter { !$0.cached }.count == 1, "one asked NARA; three were answered by it")
            #expect(try decode(NARAStatus.self, try await Browser(client: client).get("/api/v1/nara")).quota == NARAStatus.Quota(used: 1, limit: 1))
        }
        #expect(ServiceStub.requests(with: shared).count == 1)
        #expect(await answers.searching == 0)
        #expect(await answers.count == 1)
    }

    /// Finding 7: offsets far apart are read over the selection's limit at most, with the app's passage around it,
    /// where they read the whole of a document's text; a selection's own span reads as before.
    @Test func lookUpsPassageIsHeldToTheSelectionsLimit() async throws {
        let fixture = try await OutsideFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        let server = fixture.base.server
        let provider = ServedIndexProvider(state: server.state, resources: server.resources, volumesDirectory: await server.reader.volumesDirectory)
        let document = DocumentKey(volumeId: "frus1961-63v06", documentId: "d93")
        let page = try await HighlightRoutes.page(of: document, reader: server.reader, provider: provider, resources: server.resources)
        #expect(page.length > LookUpRoutes.longest + 10_000, "d93's text, 35,309 units, is longer than a selection may be")
        func passage(_ start: Int, _ end: Int) async throws -> String? {
            try await LookUpRoutes.passage(of: LookUpRoutes.Selection(text: "x", start: start, end: end, blockText: nil), in: document,
                                           reader: server.reader, provider: provider, resources: server.resources)
        }
        let (before, after, longest) = (NARALookupAnalyzer.contextBefore, NARALookupAnalyzer.contextAfter, LookUpRoutes.longest)
        #expect(try await passage(1_000, 1_040) == flatTextExcerpt(from: page.model, start: 1_000 - before, end: 1_040 + after))
        let whole = try #require(try await passage(0, Int.max))
        #expect(whole == flatTextExcerpt(from: page.model, start: 0, end: longest + after))
        let text = try #require(flatTextExcerpt(from: page.model, start: 0, end: page.length))
        #expect(whole.count < text.count - 10_000, "not the document's whole text")
        #expect(try await passage(2_000, 2_000 + longest + 5_000)
            == flatTextExcerpt(from: page.model, start: 2_000 - before, end: 2_000 + longest + after))
        #expect(try await passage(2_000, 2_000 + longest) == flatTextExcerpt(from: page.model, start: 2_000 - before, end: 2_000 + longest + after))
        // The largest offsets an Int holds trap nothing.
        #expect(try await passage(Int.max - 10, Int.max) == nil)
        #expect(try await passage(Int.max - longest - 10, Int.max) == nil)
    }

    /// Finding 10, the server's half: a stored key this server's key file cannot open is KEY_UNREADABLE in the web's
    /// sentence of whose it is and who can store it again, never the key, for the NARA key a user keeps, the
    /// instance's and a user's Zotero key, each read through the one helper.
    @Test func aStoredKeyTheKeyFileCannotOpenSaysWhose() async throws {
        let fixture = try await OutsideFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        // Keys sealed under another key file, as a store restored beside the wrong one holds them.
        let elsewhere = SecretVault(key: try #require(SecretKey(Array(repeating: 7, count: SecretKey.byteCount))),
                                    keyFile: fixture.base.server.files.secretKey, store: fixture.base.store)
        let keys = ["stub-nara-ok-sealed-user", "stub-nara-ok-sealed-instance", "stub-zotero-writer-sealed"]
        _ = try elsewhere.set(keys[0], named: .nara, for: .user("owner"), at: UserDataFixture.now)
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            func unreadable(_ response: TestResponse) throws -> String {
                let body = try problem(response, .internalServerError)
                #expect(body.code == "KEY_UNREADABLE" && !keys.contains { String(buffer: response.body).contains($0) })
                return body.detail
            }
            let search = #"{"strategy": "keyword", "query": "Laos"}"#
            #expect(try unreadable(try await browser.send(.post, "/api/v1/nara/search", search))
                == "Your stored NARA Catalog API key cannot be opened with this server’s key file. Add it again in Settings ▸ Keys.")
            #expect(try unreadable(try await browser.get("/api/v1/nara")).hasPrefix("Your stored NARA Catalog API key"))
            #expect(try fixture.services.secrets.remove(named: .nara, for: .user("owner")))
            _ = try elsewhere.set(keys[1], named: .nara, for: .instance, at: UserDataFixture.now)
            #expect(try unreadable(try await browser.send(.post, "/api/v1/nara/search", search))
                == "This server’s stored NARA Catalog API key cannot be opened with its key file. An admin can store it again in Administration ▸ Keys.")
            _ = try elsewhere.set(keys[2], named: .zotero, for: .user("owner"), at: UserDataFixture.now)
            #expect(try unreadable(try await browser.send(.post, "/api/v1/me/volumes/frus1961-63v06/documents/d3/zotero"))
                == "Your stored Zotero key cannot be opened with this server’s key file. Add it again in Settings ▸ Keys.")
        }
        for key in keys {
            #expect(ServiceStub.requests(with: key).isEmpty && !fixture.logs.contains(key))
        }
    }

    // MARK: Refusals

    /// NARA's refusals in the kit's sentences, none of them kept, and nothing of the key or of the error's own
    /// description in an answer or the log.
    @Test func naraRefusalsAreTheKitsSentencesAndNeverTheKey() async throws {
        let fixture = try await OutsideFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            for (key, status, code) in [("stub-nara-403-x", HTTPResponse.Status.conflict, "NARA_KEY_REJECTED"),
                                        ("stub-nara-429-x", .serviceUnavailable, "NARA_RATE_LIMITED"),
                                        ("stub-nara-500-x", .badGateway, "NARA_UNEXPECTED_ANSWER"),
                                        // A 200 whose body is not JSON, the CDN's page (FRUS-Explorer#1908): the kit's
                                        // `decodingError` since the pin move to `1.0-release`, where it read as no records.
                                        ("stub-nara-html-x", .badGateway, "NARA_UNEXPECTED_ANSWER"),
                                        ("stub-nara-down-x", .badGateway, "NARA_UNREACHABLE")] {
                try fixture.store(key, as: .nara, for: .user("owner"))
                let refused = try await browser.send(.post, "/api/v1/nara/search", #"{"route": "recordGroup", "recordGroup": "59", "keywords": "Laos"}"#)
                let body = try problem(refused, status)
                #expect(body.code == code, "\(key)")
                if key.contains("-html-") { #expect(body.detail == "Could not interpret the NARA Catalog response.") }
                #expect(!String(buffer: refused.body).contains(key) && !String(buffer: refused.body).contains("catalog.archives.gov"))
            }
            #expect(await fixture.services.outside.answers.count == 0, "a refusal is never kept")
            // Nor is an answer with no records, which the kit's client gives for refusals it passes over too.
            try fixture.store("stub-nara-empty-x", as: .nara, for: .user("owner"))
            for _ in 0..<2 {
                let none = try await browser.send(.post, "/api/v1/nara/search", #"{"strategy": "keywordRG59", "query": "nothing"}"#)
                #expect(try decode(NARASearchAnswer.self, none) == NARASearchAnswer(results: [], cached: false))
            }
            #expect(ServiceStub.requests(with: "stub-nara-empty-x").count == 2)
            #expect(await fixture.services.outside.answers.count == 0)
            // What a search must name, refused before anything is asked.
            for (search, field) in [(#"{"strategy": "centralURL", "query": "611.61"}"#, "strategy"), (#"{"strategy": "lotFileRG59"}"#, "query"),
                                    (#"{"strategy": "lotFileRG59", "query": "  "}"#, "query"), (#"{"route": "lotVariants", "lot": "66 D 204"}"#, "recordGroup"),
                                    (#"{"route": "elsewhere"}"#, "route"), (#"{"strategy": "keyword", "route": "recordGroup", "query": "x"}"#, "route"),
                                    (#"{}"#, "strategy"), (#"{"strategy": "keyword", "query": "x", "lot": "1"}"#, "lot")] {
                let refused = try problem(try await browser.send(.post, "/api/v1/nara/search", search), .badRequest)
                #expect(refused.code == "INVALID_FIELD" && refused.detail.hasPrefix(field), "\(search)")
            }
        }
        for key in ["stub-nara-403-x", "stub-nara-429-x", "stub-nara-500-x", "stub-nara-down-x"] { #expect(!fixture.logs.contains(key)) }

        // The instance's key refused is not the user's to change: the web's sentence names who can.
        let instance = try await OutsideFixture(environmentKey: "stub-nara-403-instance")
        defer { withExtendedLifetime(instance) {} }
        try await instance.app.test(.router) { client in
            let refused = try await Browser(client: client).send(.post, "/api/v1/nara/search", #"{"strategy": "keyword", "query": "Laos"}"#)
            let body = try problem(refused, .conflict)
            #expect(body.code == "NARA_KEY_REJECTED" && body.detail.contains("this server’s API key") && body.detail.contains("Administration ▸ Keys"))
        }
    }

    /// FRUS_OFFLINE: a search and a send are refused, and neither service is asked.
    @Test func offlineAsksNeitherService() async throws {
        let fixture = try await OutsideFixture(volumes: ["frus1961-63v06"], environmentKey: "stub-nara-ok-offline", offline: true)
        defer { withExtendedLifetime(fixture) {} }
        try fixture.store("stub-zotero-writer-offline", as: .zotero, for: .user("owner"))
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let status = try decode(NARAStatus.self, try await browser.get("/api/v1/nara"))
            #expect(status.offline)
            let search = try problem(try await browser.send(.post, "/api/v1/nara/search", #"{"strategy": "keyword", "query": "x"}"#), .conflict)
            #expect(search.code == "OFFLINE")
            let send = try problem(try await browser.send(.post, "/api/v1/me/volumes/frus1961-63v06/documents/d3/zotero"), .conflict)
            #expect(send.code == "OFFLINE")
        }
        #expect(ServiceStub.requests(with: "stub-nara-ok-offline").isEmpty && ServiceStub.requests(with: "stub-zotero-writer-offline").isEmpty)
    }

    // MARK: Send to Zotero Library

    /// Cite's send: the kit's item for the document, its tags those of the document and of its notes, its notes the
    /// notes' bodies, into the library with no collection; the key to Zotero's stand-in alone.
    @Test func aDocumentGoesToZoteroWithTheUsersTagsAndNotes() async throws {
        let key = "stub-zotero-writer-document"
        let fixture = try await OutsideFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        try fixture.store(key, as: .zotero, for: .user("owner"))
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let document = "/api/v1/me/volumes/frus1961-63v06/documents/d3"
            let made = try decode(UserTag.self, try await browser.send(.post, "/api/v1/me/tags", #"{"name": "Moscow"}"#))
            let noted = try decode(UserTag.self, try await browser.send(.post, "/api/v1/me/tags", #"{"name": "Kennedy"}"#))
            #expect(try await browser.send(.put, "\(document)/tags", #"{"tagIds": ["\#(made.id)"]}"#).status == .ok)
            for (text, tags) in [("A first note.", "[\"\(noted.id)\"]"), ("", "[]")] {
                let note = #"{"bodyText": "\#(text)", "runs": null, "userTagIds": \#(tags), "projectIds": [], "selectedSummaryIds": []}"#
                #expect(try await browser.send(.post, "\(document)/notes", note).status == .created)
            }
            let sent = try await browser.send(.post, "\(document)/zotero")
            #expect(sent.status == .ok)
            #expect(try decode(ZoteroSent.self, sent) == ZoteroSent(addedItems: 1, failedItems: 0, addedNotes: 1,
                                                                    webURL: "https://www.zotero.org/frus-stub/library"))
            #expect(!body(sent).contains(key))
        }
        let asked = ServiceStub.requests(with: key)
        #expect(asked.map { "\($0.method) \($0.url.path)" } == ["GET /keys/\(key)", "POST /users/4210/items", "POST /users/4210/items"])
        let items = try #require(try JSONSerialization.jsonObject(with: asked[1].body) as? [[String: Any]])
        #expect(items.count == 1)
        #expect((items[0]["title"] as? String)?.hasPrefix("Document 3: ") == true && items[0]["itemType"] as? String == "bookSection")
        #expect((items[0]["tags"] as? [[String: String]])?.compactMap { $0["tag"] } == ["Kennedy", "Moscow"])
        #expect((items[0]["collections"] as? [String]) == [])
        let notes = try #require(try JSONSerialization.jsonObject(with: asked[2].body) as? [[String: Any]])
        #expect(notes.map { $0["note"] as? String } == ["<p>A first note.</p>"] && notes.map { $0["parentItem"] as? String } == ["ITEM0000"])
        #expect(asked.dropFirst().allSatisfy { $0.headers["Authorization"] == "Bearer \(key)" })
        #expect(!fixture.logs.contains(key))
    }

    /// The export sheet's send: the collection's documents in their order, into a Zotero collection of its name, and
    /// the send kept in the history as the app keeps it.
    @Test func aCollectionGoesToZoteroAndIsKeptInTheHistory() async throws {
        let key = "stub-zotero-writer-collection"
        let fixture = try await OutsideFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        try fixture.store(key, as: .zotero, for: .user("owner"))
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let made = try await browser.send(.post, "/api/v1/me/collections", #"{"name": "Berlin, 1961"}"#)
            let id = try #require(try JSONSerialization.jsonObject(with: Data(buffer: made.body)) as? [String: Any])["id"] as? String ?? ""
            let documents = #"{"documents": [{"volumeId": "frus1961-63v06", "documentId": "d4"}, {"volumeId": "frus1961-63v06", "documentId": "d3"}]}"#
            #expect(try await browser.send(.post, "/api/v1/me/collections/\(id)/documents", documents).status.code < 300)
            let sent = try await browser.send(.post, "/api/v1/me/collections/\(id)/zotero")
            #expect(sent.status == .ok)
            let answer = try decode(ZoteroSent.self, sent)
            #expect(answer.addedItems == 2 && answer.failedItems == 0 && answer.webURL == "https://www.zotero.org/frus-stub/collections/COLL0000")
            let history = try decode(HistoryPage.self, try await browser.get("/api/v1/me/history?scope=all"))
            #expect(history.exports.map { [$0.format, $0.formatName, "\($0.documentCount)", $0.collectionName ?? ""] }
                == [["zotero-api", "Zotero (web)", "2", "Berlin, 1961"]])
            // An empty one has nothing to send, in the app's words.
            let empty = try await browser.send(.post, "/api/v1/me/collections", #"{"name": "Nothing yet"}"#)
            let emptyId = try #require(try JSONSerialization.jsonObject(with: Data(buffer: empty.body)) as? [String: Any])["id"] as? String ?? ""
            let refused = try problem(try await browser.send(.post, "/api/v1/me/collections/\(emptyId)/zotero"), .conflict)
            #expect(refused.code == "NOTHING_TO_EXPORT" && refused.detail == "This collection has no documents to send.")
        }
        let asked = ServiceStub.requests(with: key)
        #expect(asked.map { "\($0.method) \($0.url.path)" }.prefix(3) == ["GET /keys/\(key)", "POST /users/4210/collections", "POST /users/4210/items"])
        let collection = try #require(try JSONSerialization.jsonObject(with: asked[1].body) as? [[String: Any]])
        #expect(collection.first?["name"] as? String == "Berlin, 1961")
        let items = try #require(try JSONSerialization.jsonObject(with: asked[2].body) as? [[String: Any]])
        #expect(items.compactMap { ($0["title"] as? String)?.prefix(11).description } == ["Document 4:", "Document 3:"])
        #expect(items.allSatisfy { ($0["collections"] as? [String]) == ["COLL0000"] })
    }

    /// Zotero's refusals of a key, in the kit's sentences.
    @Test func zoteroRefusalsAreTheKitsSentences() async throws {
        let fixture = try await OutsideFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            for (key, code, sentence) in [("stub-zotero-rejected-x", "ZOTERO_KEY_REJECTED", "That Zotero API key was rejected. Check it and try again."),
                                          ("stub-zotero-reader-x", "ZOTERO_KEY_CANNOT_WRITE",
                                           "This Zotero key lacks write access to your library. Create a key with write and notes permission.")] {
                try fixture.store(key, as: .zotero, for: .user("owner"))
                let refused = try await browser.send(.post, "/api/v1/me/volumes/frus1961-63v06/documents/d3/zotero")
                let problem = try problem(refused, .conflict)
                #expect(problem.code == code && problem.detail == sentence)
                #expect(!String(buffer: refused.body).contains(key))
            }
        }
    }

    // MARK: Look Up

    /// Look Up's candidates: a footnote's selection read with its footnote, and one in the text with the flat text
    /// around it, each the kit's analyzer's answer over the server's bundled indexes, with the strategy the sheet
    /// opens on, the kit's six strategies and the filing periods.
    @Test func lookUpsCandidatesAreTheKitsAnalyzers() async throws {
        let fixture = try await OutsideFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        let archival = fixture.base.server.resources.archivalIndexes
        let note = "Source: Department of State, Presidential Correspondence: Lot 66 D 204. No classification marking."
        try await fixture.app.test(.router) { client in
            let lookUp = "/api/v1/volumes/frus1961-63v06/documents/d3/lookup"
            func asked(_ json: String) async throws -> TestResponse {
                try await client.execute(uri: lookUp, method: .post, headers: [.contentType: "application/json"], body: ByteBuffer(string: json))
            }
            let footnote = try decode(LookUpAnswer.self, try await asked(#"{"text": "Lot 66 D 204", "blockText": "\#(note)"}"#))
            let kits = NARALookupAnalyzer.candidates(selection: "Lot 66 D 204", context: note, centralFiles: archival.centralFiles,
                                                     volumeSources: archival.volumeSources, claimants: archival.claimants)
            #expect(footnote == LookUpRoutes.answer(kits))
            let lot = try #require(footnote.candidates.first)
            #expect(lot.label == "Lot 66 D 204" && lot.strategy == "lotFileRG59" && lot.origin == "selection" && lot.resolution != nil)
            #expect(footnote.strategy == "lotFileRG59")
            #expect(footnote.strategies.map(\.id) == LookupStrategy.allCases.map(\.rawValue))
            #expect(footnote.strategies.map(\.name) == LookupStrategy.allCases.map(\.displayName))
            #expect(footnote.strategies.filter { !$0.searches }.map(\.id) == ["centralURL"])
            #expect(footnote.periods.count == SourceExplorerPanels.allFilingPeriods.count && !footnote.periods.isEmpty)

            // In the text: the passage the flat text gives around the offsets, as the app's reader takes it.
            let page = try await HighlightRoutes.page(of: DocumentKey(volumeId: "frus1961-63v06", documentId: "d3"),
                                                      reader: fixture.base.server.reader, provider: ServedIndexProvider(
                                                          state: fixture.base.server.state, resources: fixture.base.server.resources,
                                                          volumesDirectory: fixture.base.server.reader.volumesDirectory),
                                                      resources: fixture.base.server.resources)
            let words = try #require(flatTextExcerpt(from: page.model, start: 10, end: 40))
            let selection = String(decoding: try JSONSerialization.data(withJSONObject: ["text": words, "start": 10, "end": 40] as [String: Any]),
                                   as: UTF8.self)
            let inText = try decode(LookUpAnswer.self, try await asked(selection))
            let around = flatTextExcerpt(from: page.model, start: 0, end: 40 + NARALookupAnalyzer.contextAfter)
            #expect(inText == LookUpRoutes.answer(NARALookupAnalyzer.candidates(
                selection: words, context: around, centralFiles: archival.centralFiles, volumeSources: archival.volumeSources,
                claimants: archival.claimants)))

            // Offsets past the text, to the largest an Int holds, read to its end; a footnote's text is the bridge's
            // 5,000 characters at most.
            #expect(try await asked(#"{"text": "x", "start": 0, "end": 9223372036854775807}"#).status == .ok)
            #expect(try await asked(#"{"text": "x", "start": 9223372036854775000, "end": 9223372036854775807}"#).status == .ok)
            let long = String(repeating: "a", count: LookUpRoutes.longestBlock + 1)
            #expect(problemCode(try await asked(#"{"text": "x", "blockText": "\#(long)"}"#)) == "INVALID_FIELD")

            // Nothing to read: no candidates, and the sheet opens on Keywords in RG 59, as the app's does.
            let nothing = try decode(LookUpAnswer.self, try await asked(#"{"text": ""}"#))
            #expect(nothing.candidates.isEmpty && nothing.strategy == "keywordRG59")
            // A body that is not JSON, and a field the route does not take.
            let form = try await client.execute(uri: lookUp, method: .post, headers: [.contentType: "text/plain"], body: ByteBuffer(string: "x"))
            #expect(form.status == .unsupportedMediaType)
            #expect(problemCode(try await asked(#"{"text": "x", "key": "y"}"#)) == "UNKNOWN_FIELD")
            #expect(problemCode(try await client.execute(uri: "/api/v1/volumes/frus9999/documents/d1/lookup", method: .post,
                                                         headers: [.contentType: "application/json"], body: ByteBuffer(string: #"{"text": ""}"#)))
                    == "VOLUME_NOT_FOUND")
        }
    }

    // MARK: The mirror

    /// FRUS_SERVICES_MIRROR, as a server asks it: each service's request, its method, headers and body, sent under the
    /// mirror at its host's name, and the mirror's answer given back as the service's.
    @Test func theMirrorIsAskedAsTheServiceWouldBe() async throws {
        #expect(ServicesMirrorProtocol.mirrored(URL(string: "https://catalog.archives.gov/api/v2/records/search?q=Lot%2066&rows=3")!,
                                                under: URL(string: "http://services:8000/")!)?.absoluteString
            == "http://services:8000/catalog.archives.gov/api/v2/records/search?q=Lot%2066&rows=3")
        #expect(ServicesMirrorProtocol.mirrored(URL(string: "https://api.zotero.org/keys/abc")!, under: URL(string: "http://stub:9/base")!)?.absoluteString
            == "http://stub:9/base/api.zotero.org/keys/abc")

        let seen = Mutex<[String]>([])
        let router = Router()
        router.get("/catalog.archives.gov/api/v2/records/search") { request, _ -> Response in
            seen.withLock { $0.append("GET \(request.uri.query ?? "") \(request.headers[HTTPField.Name("x-api-key")!] ?? "")") }
            return Response(status: .ok, headers: [.contentType: "application/json"], body: .init(byteBuffer: ByteBuffer(
                string: ServiceStub.liveAnswer(naId: 77, title: "Mirrored", recordGroup: "59", years: (1950, 1960), fields: nil))))
        }
        router.get("/catalog.archives.gov/api/v2/held") { _, _ -> Response in
            try? await Task.sleep(for: .seconds(2))
            return Response(status: .ok)
        }
        router.post("/api.zotero.org/users/{user}/items") { request, _ -> Response in
            let posted = try await request.body.collect(upTo: 65_536)
            seen.withLock { $0.append("POST \(request.headers[.authorization] ?? "") \(String(buffer: posted))") }
            return Response(status: .ok, headers: [.contentType: "application/json"], body: .init(byteBuffer: ByteBuffer(string: #"{"successful": {}, "failed": {}}"#)))
        }
        // `.live` serves the stand-in at localhost, on a port of its own.
        let mirror = Application(router: router)
        try await mirror.test(.live) { client in
            let port = try #require(client.port)
            let services = OutsideServices(configuration: ServerConfiguration(servicesMirror: URL(string: "http://localhost:\(port)/")!))
            let nara = NARACatalogClient(keyProvider: FixedKey(key: "stub-nara-mirror"), urlSession: services.naraSession)
            let found = try await nara.searchByRecordGroup("59", keywords: "Lot 66", maxResults: 3)
            #expect(found.map(\.title) == ["Mirrored"])
            var request = URLRequest(url: URL(string: "https://api.zotero.org/users/4210/items")!)
            request.httpMethod = "POST"
            request.httpBody = Data(#"[{"itemType": "note"}]"#.utf8)
            request.setValue("Bearer stub-zotero-mirror", forHTTPHeaderField: "Authorization")
            let (_, response) = try await services.zoteroSession.data(for: request)
            #expect((response as? HTTPURLResponse)?.statusCode == 200 && response.url?.host == OutsideServices.zoteroHost)
            // Another host is not the mirror's.
            #expect(!ServicesMirrorProtocol.canInit(with: URLRequest(url: URL(string: "https://example.org/")!)))

            // A request stopped while the mirror holds it stops its relay, off the session's queue as the relay
            // began, and the next is answered.
            let held = Task { try await services.naraSession.data(for: URLRequest(url: URL(string: "https://catalog.archives.gov/api/v2/held")!)) }
            try await Task.sleep(for: .milliseconds(300))
            held.cancel()
            await #expect(throws: (any Error).self) { try await held.value }
            #expect(try await nara.searchByRecordGroup("59", keywords: "Lot 66", maxResults: 3).map(\.title) == ["Mirrored"])
        }
        let query = "q=Lot%2066&description.recordGroupNumber=59&resultType=description&rows=3"
        #expect(seen.withLock { $0 } == ["GET \(query) stub-nara-mirror", #"POST Bearer stub-zotero-mirror [{"itemType": "note"}]"#,
                                         "GET \(query) stub-nara-mirror"])
    }
}
