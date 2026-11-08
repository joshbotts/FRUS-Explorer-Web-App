// Local accounts' sign-in (PLAN's S20b), `FRUS_AUTH=local`: a name and a password, posted as JSON
// under the guard /api/v1/me's writes pass but for a user, give a session, whose cookie is HttpOnly,
// Secure and SameSite=Lax; the session names the user each request under /api/v1/me acts for. A wrong
// password, an unknown name and a name with no password are refused alike, after the same Argon2id
// verification, and a name or a browser's address that has failed five times waits before it is tried
// again. The corpus, the reader and its frame need no session, as behind a proxy that signs people in
// (S14e): the frame's scripts and figures come with no cookie that is SameSite=Lax.
//   GET  /api/v1/auth/session    whether this browser is signed in, in every mode
//   POST /api/v1/auth/sign-in    {"name", "password"}: the session's cookie, and GET /api/v1/me's answer
//   POST /api/v1/auth/sign-out   ends the session the cookie names

import FRUSLightCore
import Foundation
import Hummingbird
import Logging
import Synchronization
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// The accounts' sign-in and their sessions, which `LocalSessionResolver` reads the user from.
final class LocalAccounts: Sendable {
    let store: any AccountStore & SessionStore
    let hasher: PasswordHasher
    let throttle = SignInThrottle()
    let slots = HashingSlots()
    let cookie: SessionCookie
    /// `FRUS_TRUSTED_PROXIES`: the proxies whose `X-Forwarded-For` names the browser.
    let proxies: [AddressRange]
    let now: @Sendable () -> Date
    /// A hash of no one's password, made once, which a name with none is verified against.
    private let decoy = Mutex<String?>(nil)
    /// How many passwords have been verified: the tests' way to see that a refusal for a name with no
    /// account or no password verifies one, as a wrong password does, and that a slowed attempt does not.
    private let verified = Mutex(0)
    var verifications: Int { verified.withLock { $0 } }
    /// Each session read lately, so that a request asks the store for it at most once in
    /// `readAgainAfter`, and need not wait while an import writes, as a proxy's users are held (S14e).
    private let known = Mutex<[String: Known]>([:])

    private struct Known {
        let user: RequestUser
        let expiresAt: Date
        let read: Date
    }

    /// A session ends this long after it was last used, and this long after its sign-in, whichever
    /// comes first; its use is written down at most once in `touchInterval`.
    static let idleLifetime: TimeInterval = 14 * 86_400
    static let longestLifetime: TimeInterval = 30 * 86_400
    static let touchInterval: TimeInterval = 5 * 60
    /// How long a session read is held before it is read again: so a change the command line makes in
    /// the store, an account disabled or a password set, reaches a session the server holds within it.
    static let readAgainAfter: TimeInterval = 30

    init(store: any AccountStore & SessionStore, configuration: ServerConfiguration, hasher: PasswordHasher,
         now: @escaping @Sendable () -> Date) {
        self.store = store
        self.hasher = hasher
        cookie = SessionCookie(path: configuration.basePath.path)
        proxies = configuration.trustedProxies
        self.now = now
        decoy.withLock { $0 = try? hasher.decoy() }
    }

    /// When a session made at `createdAt` and last used at `lastUsed` ends.
    static func expiry(createdAt: Date, lastUsed: Date) -> Date {
        min(lastUsed.addingTimeInterval(idleLifetime), createdAt.addingTimeInterval(longestLifetime))
    }

    // MARK: Sessions

    /// The user a session `request`'s cookie names acts for, or nil when it names none that is current:
    /// none, one ended, one expired, or one of an account disabled since.
    func signedInUser(_ request: Request) async throws -> RequestUser? {
        let time = now()
        var found: RequestUser?
        for id in SessionCookie.sessionIDs(in: request) {
            guard let user = try await user(ofSession: id, at: time) else { continue }
            // Cookies naming two people's sessions, as one another site set beside the browser's own
            // could, name no one: the request might be writing into the wrong person's research.
            if let found, found.id != user.id { return nil }
            found = user
        }
        return found
    }

    private func user(ofSession id: String, at time: Date) async throws -> RequestUser? {
        if let known = known.withLock({ $0[id] }), time.timeIntervalSince(known.read) < Self.readAgainAfter, time >= known.read {
            if known.expiresAt > time { return known.user }
        }
        let store = store
        guard let found = try await Blocking.run({ try store.session(id, at: time) }), found.account.canSignIn else {
            forget(id)
            return nil
        }
        var expiresAt = found.session.expiresAt
        if time.timeIntervalSince(found.session.lastUsedAt) >= Self.touchInterval {
            expiresAt = Self.expiry(createdAt: found.session.createdAt, lastUsed: time)
            let moved = expiresAt
            try await Blocking.run { try store.touchSession(id, at: time, expiresAt: moved) }
        }
        let user = Self.user(found.account)
        remember(id, user, expiresAt: expiresAt, at: time)
        return user
    }

    static func user(_ account: Account) -> RequestUser {
        RequestUser(id: account.id, displayName: account.displayName,
                    roles: account.role.held.compactMap { RequestUser.Role(rawValue: $0.rawValue) })
    }

    private func remember(_ id: String, _ user: RequestUser, expiresAt: Date, at time: Date) {
        known.withLock { known in
            // A bound on what the server holds; the store keeps every session.
            if known.count >= 10_000 { known.removeAll() }
            known[id] = Known(user: user, expiresAt: expiresAt, read: time)
        }
    }

    private func forget(_ id: String) {
        _ = known.withLock { $0.removeValue(forKey: id) }
    }

    // MARK: Signing in and out

    /// Why a sign-in was refused.
    enum Refusal: Error, Equatable {
        /// The name or the browser's address has failed too often lately: try again in this many seconds.
        case slowed(seconds: Int)
        /// The name has no account, no password that this one is, or is disabled.
        case failed
        /// Too many sign-ins wait to be hashed.
        case busy
    }

    /// The account `name` and `password` sign in, from a browser at `client`: refused if either has
    /// failed too often lately, and otherwise verified, whether or not the name has an account, so a
    /// refusal takes as long and says as much for a name that has none, or a disabled account, as for a
    /// wrong password. Each attempt the throttle admits counts as a failure from the moment it is
    /// admitted, under the throttle's lock, and a sign-in takes its own back, so attempts sent at once
    /// are admitted no further than one after another would be. The log names a name or an address the
    /// first time its failures slow it.
    func authenticate(_ name: String, _ password: String, client: String?, logger: Logger) async throws -> Account {
        let time = now()
        let nameKey = "the name \(name)"
        let addressKeys = client.map { ["the address \(ClientAddress.key($0))"] } ?? []
        let keys = [nameKey] + addressKeys
        let wait = throttle.admit(keys, at: time)
        if wait > 0 { throw Refusal.slowed(seconds: Int(wait.rounded(.up))) }
        guard await slots.acquire() else {
            throttle.withdraw(keys)
            throw Refusal.busy
        }
        let found: (account: Account?, verified: Bool)
        do {
            let store = store
            verified.withLock { $0 += 1 }
            found = try await Blocking.run {
                let account = try store.account(name)
                return (account, self.hasher.verify(password, against: try account?.passwordHash ?? self.decoyHash()))
            }
        } catch {
            slots.release()
            throttle.withdraw(keys)
            throw error
        }
        slots.release()
        guard let account = found.account, account.passwordHash != nil, found.verified, account.disabledAt == nil else {
            for key in throttle.justSlowed(keys) {
                logger.warning("Sign-ins for \(key) have failed \(SignInThrottle.freeFailures) times: each further attempt waits, a second at first and twice as long after each failure")
            }
            throw Refusal.failed
        }
        throttle.succeeded(nameKey)
        throttle.withdraw(addressKeys)
        return account
    }

    private func decoyHash() throws -> String {
        if let hash = decoy.withLock({ $0 }) { return hash }
        let hash = try hasher.decoy()
        decoy.withLock { $0 = hash }
        return hash
    }

    /// A new session for `account`, kept in the store: its cookie's token. The store keeps it only if the
    /// account still has the password just verified and is not disabled, so a sign-in verifying while
    /// the command line set a password or disabled the account gives no session: `Refusal.failed`.
    func startSession(for account: Account) async throws -> String {
        let time = now()
        let token = SessionToken.make()
        let session = Session(id: SessionToken.id(of: token), userID: account.id, createdAt: time, lastUsedAt: time,
                              expiresAt: Self.expiry(createdAt: time, lastUsed: time))
        let (store, hash) = (store, account.passwordHash)
        do {
            try await Blocking.run { try store.startSession(session, passwordHash: hash) }
        } catch is AccountStoreError {
            throw Refusal.failed
        }
        remember(session.id, Self.user(account), expiresAt: session.expiresAt, at: time)
        return token
    }

    /// Ends every session `request`'s cookie names.
    func signOut(_ request: Request) async throws {
        let store = store
        for id in SessionCookie.sessionIDs(in: request) {
            forget(id)
            try await Blocking.run { try store.endSession(id) }
        }
    }
}

/// `FRUS_AUTH=local`: the user is the one the session the request's cookie names signs in.
struct LocalSessionResolver: UserResolver {
    let accounts: LocalAccounts

    func user(for request: Request, context: APIRequestContext) async throws -> RequestUser {
        guard let user = try await accounts.signedInUser(request) else {
            throw APIProblem(.forbidden, code: "NOT_SIGNED_IN",
                             detail: "This server keeps each person's research under an account of their own, and this request carries no session that is current: sign in.")
        }
        return user
    }
}

/// The session's cookie: `frus_session`, a token of 32 random bytes, scoped to the path the server
/// answers under, kept for the longest a session lasts, sent over https alone, or to this machine,
/// never to a script, and with no request another site starts but a link followed.
struct SessionCookie: Sendable {
    static let name = "frus_session"
    /// The most cookies of the name a request is read for: a site under the same host may set another.
    static let mostRead = 4

    /// The path the server answers under, `/` or such as `/frus-explorer/`.
    let path: String

    /// The `Set-Cookie` that gives the browser `token`.
    func setting(_ token: String) -> String {
        "\(Self.name)=\(token); Path=\(path); Max-Age=\(Int(LocalAccounts.longestLifetime)); HttpOnly; Secure; SameSite=Lax"
    }

    /// The `Set-Cookie` that removes it.
    var clearing: String {
        "\(Self.name)=; Path=\(path); Max-Age=0; HttpOnly; Secure; SameSite=Lax"
    }

    /// The ids of the sessions a request's cookies of the name carry, in the order sent: each token of
    /// the right form, hashed. Hummingbird's `Request.cookies` reads only the first of a name.
    static func sessionIDs(in request: Request) -> [String] {
        var ids: [String] = []
        for header in request.headers[values: .cookie] {
            for pair in header.split(separator: ";") {
                let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == name else { continue }
                let token = parts[1].trimmingCharacters(in: .whitespaces)[...]
                guard SessionToken.isWellFormed(token), ids.count < mostRead else { continue }
                ids.append(SessionToken.id(of: String(token)))
            }
        }
        return ids
    }
}

/// Sign-in's slowing (PLAN's S20b): each name, and each browser's address, may fail five times; after
/// that each attempt waits, a second after the fifth failure, twice as long after each further one, up
/// to fifteen minutes. An attempt made sooner is refused unheard, so attempts sent at once do not slip
/// through together. A name's count is forgotten when it signs in, and any count an hour after its last
/// failure. A name that has no account is counted as one that has, so that the slowing tells no one
/// which names have accounts.
final class SignInThrottle: Sendable {
    static let freeFailures = 5
    static let longestWait: TimeInterval = 15 * 60
    static let forgetAfter: TimeInterval = 60 * 60
    /// The most names and addresses held: past it, the oldest are forgotten.
    static let capacity = 10_000

    private struct Record {
        var failures: Int
        var last: Date
    }

    private let records = Mutex<[String: Record]>([:])

    /// The wait after `failures` failures in a row.
    static func wait(after failures: Int) -> TimeInterval {
        guard failures >= freeFailures else { return 0 }
        return min(pow(2, Double(failures - freeFailures)), longestWait)
    }

    /// Admits an attempt for `keys` at `time`, counting it a failure against each until it is known to
    /// be none, and gives 0; or gives how long it must still wait, counting nothing. The check and the
    /// count are one step under the lock, so attempts sent at once are admitted one after another.
    func admit(_ keys: [String], at time: Date) -> TimeInterval {
        records.withLock { records in
            let wait = keys.map { key -> TimeInterval in
                guard let record = records[key] else { return 0 }
                if time.timeIntervalSince(record.last) >= Self.forgetAfter {
                    records[key] = nil
                    return 0
                }
                return max(0, record.last.addingTimeInterval(Self.wait(after: record.failures)).timeIntervalSince(time))
            }.max() ?? 0
            guard wait == 0 else { return wait }
            if records.count >= Self.capacity { Self.prune(&records, at: time) }
            for key in keys {
                var record = records[key] ?? Record(failures: 0, last: time)
                record.failures += 1
                record.last = time
                records[key] = record
            }
            return 0
        }
    }

    /// Of `keys`, which an admitted attempt that failed has just brought to the count that slows them.
    func justSlowed(_ keys: [String]) -> [String] {
        records.withLock { records in keys.filter { records[$0]?.failures == Self.freeFailures } }
    }

    /// Takes back the failure an admitted attempt counted against each of `keys`, as when it was not
    /// heard, or an address's when it signed in.
    func withdraw(_ keys: [String]) {
        records.withLock { records in
            for key in keys {
                guard var record = records[key] else { continue }
                record.failures -= 1
                records[key] = record.failures > 0 ? record : nil
            }
        }
    }

    /// Forgets `key`'s failures, once it has signed in.
    func succeeded(_ key: String) {
        _ = records.withLock { $0.removeValue(forKey: key) }
    }

    /// Makes room: forgets every count an hour old, then, if that is not enough, the oldest counts
    /// that slow nothing yet, keeping every count that does, so a flood of names cannot free one.
    private static func prune(_ records: inout [String: Record], at time: Date) {
        records = records.filter { time.timeIntervalSince($0.value.last) < forgetAfter }
        guard records.count >= capacity else { return }
        let slowing = records.filter { $0.value.failures >= freeFailures }
        let newest = records.filter { $0.value.failures < freeFailures }.sorted { $0.value.last > $1.value.last }
            .prefix(max(0, capacity / 2 - slowing.count))
        records = slowing.merging(newest.map { ($0.key, $0.value) }) { kept, _ in kept }
    }
}

/// At most two passwords verified at once, each holding the hash's memory, 64 MiB under the standard
/// costs, while it runs; and at most 32 waiting, past which a sign-in is refused at once rather than
/// held, so a flood of them cannot fill the server's memory or its connections.
final class HashingSlots: Sendable {
    static let running = 2
    static let waiting = 32

    private struct State {
        var free = HashingSlots.running
        var queue: [CheckedContinuation<Void, Never>] = []
    }

    private let state = Mutex(State())

    /// Waits for a slot; false, at once, when too many wait already.
    func acquire() async -> Bool {
        enum Outcome { case taken, queue, refused }
        let outcome: Outcome = state.withLock { state in
            if state.free > 0 {
                state.free -= 1
                return .taken
            }
            return state.queue.count < Self.waiting ? .queue : .refused
        }
        switch outcome {
        case .taken: return true
        case .refused: return false
        case .queue:
            await withCheckedContinuation { continuation in
                let resumeNow = state.withLock { state -> Bool in
                    // A slot freed between the two locks is taken here.
                    if state.free > 0 {
                        state.free -= 1
                        return true
                    }
                    state.queue.append(continuation)
                    return false
                }
                if resumeNow { continuation.resume() }
            }
            return true
        }
    }

    /// Frees a slot, for the next waiting if one is.
    func release() {
        let next = state.withLock { state -> CheckedContinuation<Void, Never>? in
            if state.queue.isEmpty {
                state.free += 1
                return nil
            }
            return state.queue.removeFirst()
        }
        next?.resume()
    }
}

/// The address of the browser a request came from, as sign-in's slowing counts it.
enum ClientAddress {
    /// The header a proxy names the addresses a request passed through in. (`HTTPField.Name`, which
    /// Hummingbird does not re-export.)
    static let forwardedFor = HTTPFields.Element.Name("X-Forwarded-For")!

    /// The peer's address, or behind a proxy `proxies` holds, the last address `X-Forwarded-For` gives,
    /// which that proxy appended: the address it was reached from. The addresses before it are the
    /// browser's to write, so none is read, even where the last is one of `proxies` too, as a browser
    /// inside a trusted range would be; a chain of proxies is counted by the one nearest the server. A
    /// last entry that is no address, or none, leaves the peer. Nil where the peer is not known, as in
    /// the router's tests.
    static func of(_ request: Request, peer: String?, proxies: [AddressRange]) -> String? {
        guard let peer, proxies.contains(where: { $0.contains(peer) }) else { return peer }
        let forwarded = request.headers[values: Self.forwardedFor]
            .flatMap { $0.split(separator: ",") }.map { $0.trimmingCharacters(in: .whitespaces) }
        guard let last = forwarded.last, !last.contains("/"), AddressRange(last) != nil else { return peer }
        return last
    }

    /// The key an address is counted under: an IPv4 address, from either of its forms, or an IPv6
    /// address's first 64 bits, the network a single host is given, so that one host cannot count as
    /// many by changing its address within it.
    static func key(_ address: String) -> String {
        var v6 = in6_addr()
        guard inet_pton(AF_INET6, address, &v6) == 1 else { return address }
        let bytes = withUnsafeBytes(of: &v6) { Array($0) }
        if bytes[0..<10].allSatisfy({ $0 == 0 }) && bytes[10] == 0xff && bytes[11] == 0xff {
            return bytes[12...].map(String.init).joined(separator: ".")
        }
        let groups = stride(from: 0, to: 8, by: 2).map { String(format: "%x", UInt16(bytes[$0]) << 8 | UInt16(bytes[$0 + 1])) }
        return groups.joined(separator: ":") + "::/64"
    }
}

/// `GET /api/v1/auth/session`: whether this browser is signed in, which the browser app asks before
/// anything else, so that it shows its sign-in page under `FRUS_AUTH=local` without a refusal. Under
/// `none` and `header` it is always signed in: the one user, or the user the proxy names.
public struct AuthSession: Codable, Equatable, Sendable, ResponseEncodable {
    public var auth: String
    public var signedIn: Bool
}

/// What a sign-in posts.
struct SignInBody: Decodable {
    let name: String
    let password: String
}

/// The guard on /api/v1/auth: the request's `Host` names `FRUS_PUBLIC_URL`'s address, as under
/// /api/v1/me; a POST also comes from a page of that address, by its `Origin`, so no other site signs
/// a browser in or out, and declares a body it has as JSON of `AuthRoutes.bodyLimit` at most. No user
/// is resolved, and no CSRF token asked for: there is none before a sign-in, and a sign-out ends only
/// the session the browser's own cookie names.
struct SignInGuard: RouterMiddleware {
    typealias Context = APIRequestContext
    let services: UserDataServices

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        try UserDataGuard.checkHost(request, services.address)
        if ![.get, .head, .options].contains(request.method) {
            try UserDataGuard.checkOrigin(request, services.address)
            try UserDataGuard.checkBody(request, limit: AuthRoutes.bodyLimit)
        }
        return try await next(request, context)
    }
}

enum AuthRoutes {
    /// The largest body a sign-in may send: a name of 256 bytes and a password of 1,024, escaped.
    static let bodyLimit = 8 * 1_024

    static func add(to router: Router<APIRequestContext>, services: UserDataServices) {
        let auth = router.group("/api/v1/auth").add(middleware: SignInGuard(services: services))
        auth.get("session") { request, _ -> EditedResponse<AuthSession> in
            try FormQuery(request.uri.query).refuseUnknown([])
            var signedIn = true
            if let accounts = services.accounts { signedIn = try await accounts.signedInUser(request) != nil }
            return EditedResponse(headers: [.cacheControl: "no-store"],
                                  response: AuthSession(auth: services.auth.rawValue, signedIn: signedIn))
        }
        guard let accounts = services.accounts else { return }

        auth.post("sign-in") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let body = try await JSONBody.decode(SignInBody.self, from: request, fields: ["name", "password"], limit: bodyLimit)
            let name: String
            switch AccountNames.checked(body.name) {
            case .success(let checked): name = checked
            case .failure(let problem): throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "name: \(problem)")
            }
            guard body.password.utf8.count <= PasswordRules.longest else {
                throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "password: at most \(PasswordRules.longest) bytes.")
            }
            let account: Account
            do {
                account = try await accounts.authenticate(name, body.password,
                                                          client: ClientAddress.of(request, peer: context.peerAddress, proxies: accounts.proxies),
                                                          logger: context.logger)
            } catch let refusal as LocalAccounts.Refusal {
                return try refused(refusal).response(from: request, context: context)
            }
            let token = try await accounts.startSession(for: account)
            // A session the browser held already, its own or another's, ends once the new one is kept:
            // a browser has one at a time. The new one's token is in no cookie yet.
            try await accounts.signOut(request)
            let user = LocalAccounts.user(account)
            let me = Me(userId: user.id, displayName: user.displayName, auth: services.auth.rawValue, roles: user.roles,
                        userData: services.enabled, csrfToken: services.tokens.token(for: user.id))
            return try EditedResponse(headers: [.cacheControl: "no-store", .setCookie: accounts.cookie.setting(token)], response: me)
                .response(from: request, context: context)
        }

        auth.post("sign-out") { request, _ -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            try await accounts.signOut(request)
            return Response(status: .noContent, headers: [.cacheControl: "no-store", .setCookie: accounts.cookie.clearing])
        }
    }

    /// A refusal's answer: a problem, with `Retry-After` when the attempt was slowed or held back.
    private static func refused(_ refusal: LocalAccounts.Refusal) -> SignInRefusal {
        switch refusal {
        case .slowed(let seconds):
            SignInRefusal(problem: APIProblem(.tooManyRequests, code: "SIGN_IN_SLOWED",
                                              detail: "Too many sign-ins have failed for this name or from this address lately: try again in \(seconds == 1 ? "a second" : "\(seconds) seconds")."),
                          retryAfter: seconds)
        case .failed:
            SignInRefusal(problem: APIProblem(.forbidden, code: "SIGN_IN_FAILED", detail: "The name or the password is not right."))
        case .busy:
            SignInRefusal(problem: APIProblem(.serviceUnavailable, code: "SIGN_IN_BUSY",
                                              detail: "Too many sign-ins are being checked at once: try again in a moment."),
                          retryAfter: 1)
        }
    }
}

/// A sign-in's refusal as it is answered.
private struct SignInRefusal: ResponseGenerator {
    let problem: APIProblem
    var retryAfter: Int?

    func response(from request: Request, context: some RequestContext) throws -> Response {
        var response = try problem.response(from: request, context: context)
        if let retryAfter { response.headers[.retryAfter] = String(retryAfter) }
        return response
    }
}
