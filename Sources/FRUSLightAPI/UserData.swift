// The user a request acts for, and the guard on what is theirs (PLAN's S14c): everything under
// /api/v1/me. A server with no sign-in can be reached by any page in the browser, so a write must
// come from the address FRUS_PUBLIC_URL names, to it, with the token GET /api/v1/me gives, as JSON
// of a capped size; and a read of a user's data must be sent to that address. Since S15d a note's
// writes may be larger than the rest, as a note carries its text twice and a Mac note can be long,
// and since S16c an import's larger still, as it carries a whole Mac JSON export. Since S14e the user
// may be the one a proxy that signs people in names in a header, on a request from that proxy alone.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import NIOCore
import Synchronization

/// Who a request acts for.
public struct RequestUser: Sendable, Equatable {
    public enum Role: String, Codable, Sendable { case reader, curator, admin }

    public let id: String
    public let displayName: String
    public let roles: [Role]

    /// Refuses a request of a user who does not hold `role`: the check the server makes for an
    /// instance's data, whose corrections are a curator's (S16c) and whose backups an admin's (S14b).
    func require(_ role: Role) throws {
        guard roles.contains(role) else {
            throw APIProblem(.forbidden, code: "ROLE_REQUIRED", detail: "This needs the \(role.rawValue) role, which \(displayName) does not hold.")
        }
    }
}

/// Resolves the user a request acts for: the one step that S14e's sign-in through a proxy and phase
/// 3's local accounts change. Every route under /api/v1/me reads the user from its context.
protocol UserResolver: Sendable {
    func user(for request: Request, context: APIRequestContext) async throws -> RequestUser
}

/// `FRUS_AUTH=none`: every request acts for the store's single user, who holds all three roles
/// (SPEC, Tenancy and roles).
struct SingleUserResolver: UserResolver {
    let store: any UserStore
    /// The user, once read: the store's single user, who does not change while the server runs. So a
    /// request asks the store only for what it reads, and one that reads nothing else, such as an
    /// import's status, need not wait while an import writes (S16c).
    private let known = KnownUser()

    init(store: any UserStore) {
        self.store = store
    }

    func user(for request: Request, context: APIRequestContext) async throws -> RequestUser {
        if let user = known.value.withLock({ $0 }) { return user }
        let store = store
        let user = try await Blocking.run {
            let id = try store.singleUserID()
            return RequestUser(id: id, displayName: try store.user(id)?.displayName ?? id, roles: [.reader, .curator, .admin])
        }
        known.value.withLock { $0 = user }
        return user
    }

    private final class KnownUser: Sendable {
        let value = Mutex<RequestUser?>(nil)
    }
}

/// `FRUS_AUTH=header` (PLAN's S14e): the user is the value of `FRUS_AUTH_HEADER` on a request whose
/// peer is one of `FRUS_TRUSTED_PROXIES`, the proxy that signs people in and sets the header, in
/// place of any a client sent. A request from any other peer is refused, whatever it names, so that
/// no one names themselves. A user is made the first time the header names them, with their id as
/// their name; the users `FRUS_ADMIN_USERS` names hold the three roles, and everyone else is a
/// reader (SPEC, Tenancy and roles).
struct ProxyHeaderResolver: UserResolver {
    let store: any UserStore
    let header: HTTPFields.Element.Name
    let proxies: TrustedProxies
    let admins: Set<String>
    let now: @Sendable () -> Date
    /// Each user once read, so that a request asks the store only for what it reads, as the single
    /// user's does, and need not wait while an import writes.
    private let known = KnownUsers()

    init(store: any UserStore, header: HTTPFields.Element.Name, proxies: TrustedProxies, admins: Set<String>,
         now: @escaping @Sendable () -> Date) {
        self.store = store
        self.header = header
        self.proxies = proxies
        self.admins = admins
        self.now = now
    }

    /// The longest name the header may give, in UTF-8 bytes.
    static let longestName = 256

    func user(for request: Request, context: APIRequestContext) async throws -> RequestUser {
        try proxies.check(context)
        let id = try userID(request.headers[values: header])
        if let user = known.users.withLock({ $0[id] }) { return user }
        let (store, time) = (store, now())
        let account = try await Blocking.run { try store.signedInUser(id, at: time) }
        let user = RequestUser(id: account.id, displayName: account.displayName,
                               roles: admins.contains(account.id) ? [.reader, .curator, .admin] : [.reader])
        known.users.withLock { users in
            // A bound on what a proxy's names can make it hold; the store keeps every one.
            if users.count >= 10_000 { users.removeAll() }
            users[id] = user
        }
        return user
    }

    /// The user the header's values name: one value, which is a name of `longestName` bytes at most,
    /// with no control characters and nothing that was not UTF-8.
    func userID(_ values: [String]) throws -> String {
        func refused(_ why: String) -> APIProblem {
            APIProblem(.forbidden, code: "NOT_SIGNED_IN",
                       detail: "This server takes its user from \(header), which the proxy in front of it sets once it has signed you in, and \(why).")
        }
        guard values.count <= 1 else { throw refused("this request carried it more than once") }
        guard let value = values.first?.trimmingCharacters(in: .whitespaces), !value.isEmpty else {
            throw refused("this request named no one")
        }
        guard value.utf8.count <= Self.longestName,
              !value.unicodeScalars.contains(where: { $0.properties.generalCategory == .control || $0 == "\u{FFFD}" }) else {
            throw refused("the name this request carried is not one: a user's name is at most \(Self.longestName) bytes of UTF-8, with no control characters")
        }
        return value
    }

    private final class KnownUsers: Sendable {
        let users = Mutex<[String: RequestUser]>([:])
    }
}

/// `FRUS_TRUSTED_PROXIES` (PLAN's S14e): the peers a request may come from behind a proxy that signs
/// people in. The server's log names each peer it refuses the first time, so that the proxy's
/// address, as the server sees it, can be found and named.
final class TrustedProxies: Sendable {
    let ranges: [AddressRange]
    /// The peers refused and logged so far, up to `loggedPeers`.
    private let refused = Mutex<Set<String>>([])
    private static let loggedPeers = 64

    init(_ ranges: [AddressRange]) {
        self.ranges = ranges
    }

    /// Refuses a request whose peer the ranges do not hold, or that has none known, as a request in
    /// the router's tests has.
    func check(_ context: APIRequestContext) throws {
        let peer = context.peerAddress
        if let peer, ranges.contains(where: { $0.contains(peer) }) { return }
        let name = peer ?? "an unknown peer"
        if refused.withLock({ $0.count < Self.loggedPeers && $0.insert(name).inserted }) {
            context.logger.warning("Refused a request from \(name): FRUS_TRUSTED_PROXIES (\(ranges.map(\.description).joined(separator: ", "))) does not name it. Name the proxy's address there if this was the proxy.")
        }
        throw APIProblem(.forbidden, code: "PROXY_NOT_TRUSTED",
                         detail: "This server is reached through the proxy that signs people in, and this request came from elsewhere.")
    }
}

/// `FRUS_AUTH=header`'s guard on every route but /healthz and /readyz (PLAN's S14e): the request
/// comes from a proxy that `FRUS_TRUSTED_PROXIES` names, so that the server is reached only through
/// the proxy that signs people in. The corpus, the reader and the browser app need no user, so the
/// proxy may forward what a page asks for that carries no sign-in, as the reader's sandboxed frame
/// asks for its scripts and figures; under /api/v1/me the user is the one its header names.
struct TrustedProxyGuard: RouterMiddleware {
    typealias Context = APIRequestContext
    let proxies: TrustedProxies

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        try proxies.check(context)
        return try await next(request, context)
    }
}

/// Each user's token for requests that change state, made when it is first asked for and kept
/// while the process runs: a restart makes new ones, and the browser app asks again when a write
/// is refused for its token. A page of another origin cannot read `GET /api/v1/me`, so it cannot
/// learn one.
final class CSRFTokens: Sendable {
    private let tokens = Mutex<[String: String]>([:])

    /// The header a request that changes state carries it in. (`HTTPField.Name`, which Hummingbird
    /// does not re-export.)
    static let header = HTTPFields.Element.Name("X-CSRF-Token")!

    func token(for user: String) -> String {
        tokens.withLock { tokens in
            if let token = tokens[user] { return token }
            var generator = SystemRandomNumberGenerator()
            let token = (0..<4).map { _ in String(format: "%016llx", generator.next() as UInt64) }.joined()
            tokens[user] = token
            return token
        }
    }

    /// Whether `given` is the user's token, compared in a time that does not depend on where it differs.
    func accepts(_ given: String?, for user: String) -> Bool {
        guard let given, let token = tokens.withLock({ $0[user] }) else { return false }
        let (a, b) = (Array(given.utf8), Array(token.utf8))
        guard a.count == b.count else { return false }
        return zip(a, b).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

/// What the user store keeps for the routes under /api/v1/me.
typealias UserDataStore = UserStore & TagStore & HighlightStore & NoteStore & SummaryStore & ProjectStore & ResearchImportStore
    & ResearchExportStore & UserSearchStore & SearchSetStore & ResearchRowStore & TrailStore & PreferenceStore & CollectionStore

/// What the routes under /api/v1/me need.
struct UserDataServices: Sendable {
    let store: any UserDataStore
    let resolver: any UserResolver
    /// Under `FRUS_AUTH=header`, the proxies every request but /healthz and /readyz must come from.
    let proxies: TrustedProxies?
    let tokens: CSRFTokens
    /// `FRUS_PUBLIC_URL`'s address.
    let address: PublicAddress
    /// `FRUS_USER_DATA`: off, every resource under /api/v1/me is refused, and only /me answers.
    let enabled: Bool
    let auth: ServerConfiguration.Auth
    let now: @Sendable () -> Date
    /// Where an import runs (S16c): the server's queue, beside an index's import.
    let jobs: any JobQueue
    /// Each import's status and report.
    let imports: ResearchImports
    /// The largest export an import may send: `importBodyLimit`, or a test's smaller one.
    let importLimit: Int
    /// Where the store's backups are kept, and the folder each is copied to (S14b), for the admin's
    /// `/api/v1/admin/backup`: none for a PostgreSQL store, whose backups are its database service's.
    let backupsDirectory: URL?
    let backupCopyDirectory: URL?

    init(store: any UserDataStore, configuration: ServerConfiguration, tokens: CSRFTokens = CSRFTokens(),
         jobs: any JobQueue = InProcessJobQueue(), importLimit: Int = UserDataServices.importBodyLimit,
         resolver: (any UserResolver)? = nil, now: @escaping @Sendable () -> Date = Date.init) {
        self.store = store
        if configuration.auth == .header {
            let proxies = TrustedProxies(configuration.trustedProxies)
            self.proxies = proxies
            self.resolver = resolver ?? ProxyHeaderResolver(
                store: store, header: HTTPFields.Element.Name(configuration.authHeader) ?? HTTPFields.Element.Name("X-Forwarded-User")!,
                proxies: proxies, admins: configuration.adminUsers, now: now)
        } else {
            proxies = nil
            self.resolver = resolver ?? SingleUserResolver(store: store)
        }
        backupsDirectory = configuration.userStore == .sqlite
            ? DataDirectory(root: configuration.dataDirectory).backupsDirectory : nil
        backupCopyDirectory = configuration.backupCopyDirectory
        self.tokens = tokens
        address = configuration.publicAddress
        enabled = configuration.userData
        auth = configuration.auth
        self.now = now
        self.jobs = jobs
        imports = ResearchImports()
        self.importLimit = importLimit
    }

    /// The largest body a request under /api/v1/me may carry.
    static let bodyLimit = 64 * 1_024
    /// The largest body a new note or a note's save may carry, the web's own: four times
    /// `noteTextLimit`, room for the longest text twice, as `bodyText` and in its runs, and 2 MiB
    /// more for the escapes JSON gives it and each run's own fields, some 57 bytes a run beside its
    /// text, so about 36,000 runs. It bounds what one request makes the server read, and does not
    /// promise that every text `noteTextLimit` allows can be sent formatted: one near that length
    /// whose formatting changes every few words, or that is full of what JSON escapes (quotation
    /// marks, backslashes and line breaks, two bytes each, sent twice), is refused as
    /// CONTENT_TOO_LARGE with its runs, as is a plain one mostly of control characters, which JSON
    /// writes in six bytes each.
    static let noteBodyLimit = 4 * 1_024 * 1_024
    /// The longest text, in UTF-8, a new note or a save's body may be given: a quarter of
    /// `noteBodyLimit`, so that a text of that length can be sent again formatted, as the browser
    /// sends a GET's runs, while its runs and escapes fit in what is left. The app sets no limit; a
    /// Mac note an import leaves longer keeps its body until a shorter one is saved.
    static let noteTextLimit = noteBodyLimit / 4
    /// The largest Mac JSON export an import may send (S16c), the web's own: a summary takes a few
    /// kilobytes, so tens of thousands of them fit, and the job's decoding, which holds the file and
    /// its records at once, stays within a small server's memory.
    static let importBodyLimit = 128 * 1_024 * 1_024
}

/// The guard on every route under /api/v1/me, and from S14b under /api/v1/admin, whose backups hold
/// every user's data, in its group, before the route runs:
/// 1. the request's `Host` names `FRUS_PUBLIC_URL`'s address, for a read as for a write, since a
///    page under a name pointed at this server could otherwise read a user's data;
/// 2. the user it acts for is resolved, into its context;
/// 3. with `FRUS_USER_DATA=off`, nothing but /api/v1/me itself answers;
/// 4. a request that changes state, any but GET, HEAD and OPTIONS, comes from that address (its
///    `Origin`), carries the user's token in `X-CSRF-Token`, and declares a body it has as
///    `application/json`, of `bodyLimit` at most: `UserDataServices.bodyLimit`, or for the group of
///    a note's routes `noteBodyLimit`, and of an import's `importLimit`.
struct UserDataGuard: RouterMiddleware {
    typealias Context = APIRequestContext
    let services: UserDataServices
    var bodyLimit = UserDataServices.bodyLimit

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let address = services.address
        guard let host = request.head.authority, address.allows(host: host) else {
            throw APIProblem(.forbidden, code: "HOST_NOT_ALLOWED",
                             detail: "This server answers for \(address), the address FRUS_PUBLIC_URL names, and this request was sent to \(request.head.authority ?? "no host").")
        }
        var context = context
        let user = try await services.resolver.user(for: request, context: context)
        context.user = user
        if !services.enabled, request.uri.path != "/api/v1/me" {
            throw APIProblem(.forbidden, code: "USER_DATA_OFF",
                             detail: "This server keeps no tags, notes or other user data: FRUS_USER_DATA is off.")
        }
        if ![.get, .head, .options].contains(request.method) {
            guard let origin = request.headers[.origin], address.allows(origin: origin) else {
                throw APIProblem(.forbidden, code: "ORIGIN_NOT_ALLOWED",
                                 detail: "A change must come from a page of \(address), the address FRUS_PUBLIC_URL names, and this one came from \(request.headers[.origin] ?? "no origin").")
            }
            guard services.tokens.accepts(request.headers[CSRFTokens.header], for: user.id) else {
                throw APIProblem(.forbidden, code: "CSRF_TOKEN_INVALID",
                                 detail: "A change must carry the token GET /api/v1/me gives, in X-CSRF-Token; this request's is missing or no longer current.")
            }
            let length = request.headers[.contentLength].flatMap { Int($0) }
            if (length ?? 0) > 0 || request.headers[.transferEncoding] != nil {
                guard JSONBody.isJSON(request.headers[.contentType]) else {
                    throw APIProblem(.unsupportedMediaType, code: "UNSUPPORTED_MEDIA_TYPE",
                                     detail: "A change's body must be JSON, sent as application/json.")
                }
                if let length, length > bodyLimit { throw JSONBody.tooLarge(bodyLimit) }
            }
        }
        return try await next(request, context)
    }
}

/// A request's JSON body.
enum JSONBody {
    static func isJSON(_ contentType: String?) -> Bool {
        guard let type = contentType?.split(separator: ";").first else { return false }
        return type.trimmingCharacters(in: .whitespaces).lowercased() == "application/json"
    }

    static func tooLarge(_ limit: Int) -> APIProblem {
        let size = limit % (1_024 * 1_024) == 0 ? "\(limit / (1_024 * 1_024)) MiB" : "\(limit / 1_024) KiB"
        return APIProblem(.contentTooLarge, code: "CONTENT_TOO_LARGE", detail: "A change's body here may be at most \(size).")
    }

    /// The body as `T`: a JSON object holding only `fields`, as a query string may hold only the
    /// parameters a route takes, of `limit` bytes at most, the route's group's. Any other is refused,
    /// as is a body that is not such an object.
    static func decode<T: Decodable>(_ type: T.Type, from request: Request, fields: Set<String>,
                                     limit: Int = UserDataServices.bodyLimit) async throws -> T {
        let buffer: ByteBuffer
        do {
            buffer = try await request.body.collect(upTo: limit)
        } catch is NIOTooManyBytesError {
            // A body sent in chunks, whose length no header gave.
            throw tooLarge(limit)
        } catch let error as HTTPError where error.status == .contentTooLarge {
            throw tooLarge(limit)
        }
        let data = Data(buffer: buffer)
        guard let object = try? JSONDecoder().decode([String: Ignored].self, from: data) else {
            throw APIProblem(.badRequest, code: "INVALID_BODY", detail: "The body must be a JSON object.")
        }
        if let unknown = object.keys.sorted().first(where: { !fields.contains($0) }) {
            throw APIProblem(.badRequest, code: "UNKNOWN_FIELD",
                             detail: "\(unknown): this endpoint takes \(fields.sorted().joined(separator: ", ")).")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch DecodingError.keyNotFound(let key, _) {
            throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "\(key.stringValue): required.")
        } catch DecodingError.typeMismatch(_, let context), DecodingError.valueNotFound(_, let context),
                DecodingError.dataCorrupted(let context) {
            // dataCorrupted: a number that is no Int, such as 5.5 or 1e30.
            let name = context.codingPath.first?.stringValue ?? "body"
            throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "\(name): \(context.debugDescription)")
        }
    }

    /// Any JSON value, read and set aside.
    private struct Ignored: Decodable {
        init(from decoder: any Decoder) throws {}
    }
}

/// `GET /api/v1/me`: who the server takes the browser to be, what they may do, and the token their
/// changes carry. Never cached, since the token is the user's.
public struct Me: Codable, Equatable, Sendable, ResponseEncodable {
    public var userId: String
    public var displayName: String
    /// `FRUS_AUTH`: `none` for a server with no sign-in, `header` behind a proxy that signs people in.
    public var auth: String
    public var roles: [RequestUser.Role]
    /// `FRUS_USER_DATA`: false when the server keeps none, and every resource under /me is refused.
    public var userData: Bool
    /// What `X-CSRF-Token` carries on a request that changes state.
    public var csrfToken: String
}

enum UserDataRoutes {
    static func add(to router: Router<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    reader: ReaderService, provider: ServedIndexProvider) {
        let me = router.group("/api/v1/me").add(middleware: UserDataGuard(services: services))
        me.get { request, context -> EditedResponse<Me> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = Me(userId: user.id, displayName: user.displayName, auth: services.auth.rawValue, roles: user.roles,
                          userData: services.enabled, csrfToken: services.tokens.token(for: user.id))
            return EditedResponse(headers: [.cacheControl: "no-store"], response: body)
        }
        TagRoutes.add(to: me, services: services, resources: resources)
        HighlightRoutes.add(to: me, services: services, resources: resources, reader: reader, provider: provider)
        SummaryRoutes.add(to: me, services: services, resources: resources)
        ProjectRoutes.add(to: me, services: services, resources: resources)
        HistoryRoutes.add(to: me, services: services, provider: provider, resources: resources, reader: reader)
        ResearchRoutes.add(to: me, services: services, resources: resources, provider: provider)
        PreferenceRoutes.add(to: me, services: services)
        ExportRoutes.add(to: me, services: services)
        SearchTagRoutes.add(to: me, services: services, provider: provider, resources: resources)
        SavedSearchRoutes.add(to: me, services: services, provider: provider)
        VolumeScopeRoutes.add(to: me, services: services, provider: provider, resources: resources)
        // A working corpus's capture carries the results Checklist Mode hides, so its two routes have
        // a group of their own, with its larger limit (S17e).
        let captures = router.group("/api/v1/me")
            .add(middleware: UserDataGuard(services: services, bodyLimit: WorkingCorpusRoutes.bodyLimit))
        WorkingCorpusRoutes.add(to: me, captures: captures, services: services, provider: provider, resources: resources)
        // The same guard with a note's larger limit, over a group of its own, so that the limit is
        // the route's.
        let notes = router.group("/api/v1/me")
            .add(middleware: UserDataGuard(services: services, bodyLimit: UserDataServices.noteBodyLimit))
        NoteRoutes.add(to: notes, services: services, resources: resources, provider: provider)
        // Collections take a note block's text and an introduction, as long as a note's (S18d).
        let collections = router.group("/api/v1/me")
            .add(middleware: UserDataGuard(services: services, bodyLimit: UserDataServices.noteBodyLimit))
        CollectionRoutes.add(to: collections, services: services, resources: resources, provider: provider)
        CollectionEntryRoutes.add(to: collections, services: services, resources: resources, reader: reader, provider: provider)
        CollectionExportRoutes.add(to: collections, services: services, resources: resources, reader: reader, provider: provider)
        // And an import's, the export itself.
        let imports = router.group("/api/v1/me")
            .add(middleware: UserDataGuard(services: services, bodyLimit: services.importLimit))
        ImportRoutes.add(to: imports, services: services)
    }

    /// The document a route names. Its volume must be in the catalogue; the document is named and
    /// not looked up, since the Mac's tags, highlights, notes and summaries can name a document this
    /// server does not hold.
    static func document(_ context: APIRequestContext, resources: ServerResources) throws -> DocumentKey {
        let volumeId = try context.parameters.require("volumeId")
        let documentId = try context.parameters.require("documentId")
        guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
        guard documentId.utf8.count <= 256, FRUSURLScheme.isSafeComponent(documentId) else {
            throw APIProblem.invalidParameter("documentId", "\(documentId) is not a document's id.")
        }
        return DocumentKey(volumeId: volumeId, documentId: documentId)
    }
}

extension APIRequestContext {
    /// The user the request acts for, which `UserDataGuard` resolves before any route under
    /// /api/v1/me runs.
    func requireUser() throws -> RequestUser {
        guard let user else {
            throw APIProblem(.internalServerError, code: "INTERNAL_ERROR", detail: "No user was resolved for this request.")
        }
        return user
    }
}
