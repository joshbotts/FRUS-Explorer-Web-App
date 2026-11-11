// Local accounts (PLAN's S20b), FRUS_AUTH=local, through the routes: a sign-in gives a session whose
// cookie is HttpOnly, Secure and SameSite=Lax, and names the user every route under /api/v1/me acts
// for; a wrong password, a name with no account and a name with no password are refused alike, each
// after one verification; a disabled account and an expired session are refused; the fifth failure for
// a name, or from an address, slows the sixth attempt; a sign-out ends the session; two users' research
// stays apart; and the corpus and the reader need no session. On a real socket where the peer matters.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import HummingbirdTesting
import Synchronization
import Testing

@testable import FRUSLightAPI

/// A clock a test moves.
final class SignInClock: Sendable {
    private let time = Mutex(UserDataFixture.now)
    var now: Date { time.withLock { $0 } }
    func advance(by seconds: TimeInterval) { time.withLock { $0 += seconds } }
}

/// A browser of the app under FRUS_AUTH=local: its origin, the session cookie a sign-in gave it, and
/// behind a proxy, the address the proxy says it came from.
struct AccountBrowser {
    let client: any TestClientProtocol
    var origin: String? = "http://localhost:8080"
    /// `frus_session=<token>`, as the browser sends it back.
    var cookie: String?
    var forwardedFor: String?

    init(client: any TestClientProtocol, cookie: String? = nil, forwardedFor: String? = nil) {
        self.client = client
        self.cookie = cookie
        self.forwardedFor = forwardedFor
    }

    var headers: HTTPFields {
        var headers: HTTPFields = [:]
        if let cookie { headers[.cookie] = cookie }
        if let forwardedFor { headers[ClientAddress.forwardedFor] = forwardedFor }
        return headers
    }

    /// Posts a sign-in, and keeps the cookie it is answered with.
    @discardableResult
    mutating func signIn(_ name: String, _ password: String) async throws -> TestResponse {
        var headers = headers
        if let origin { headers[.origin] = origin }
        headers[.contentType] = "application/json"
        let body = try JSONEncoder().encode(["name": name, "password": password])
        let response = try await client.execute(uri: "/api/v1/auth/sign-in", method: .post, headers: headers,
                                                body: ByteBuffer(bytes: body))
        if response.status == .ok, let set = response.headers[.setCookie] { cookie = String(set.prefix { $0 != ";" }) }
        return response
    }

    func signOut() async throws -> TestResponse {
        var headers = headers
        if let origin { headers[.origin] = origin }
        return try await client.execute(uri: "/api/v1/auth/sign-out", method: .post, headers: headers)
    }

    func get(_ path: String) async throws -> TestResponse {
        try await client.execute(uri: path, method: .get, headers: headers)
    }

    func me() async throws -> Me { try decode(Me.self, try await get("/api/v1/me")) }

    func session() async throws -> AuthSession { try decode(AuthSession.self, try await get("/api/v1/auth/session")) }

    /// A change, with the user's token unless `token` names another.
    func send(_ method: HTTPRequest.Method, _ path: String, _ json: String? = nil, token: String? = nil) async throws -> TestResponse {
        var headers = headers
        if let origin { headers[.origin] = origin }
        if let token { headers[CSRFTokens.header] = token } else { headers[CSRFTokens.header] = try await me().csrfToken }
        if json != nil { headers[.contentType] = "application/json" }
        return try await client.execute(uri: path, method: method, headers: headers, body: json.map { ByteBuffer(string: $0) })
    }
}

@Suite struct LocalAccountTests {
    static let password = "correct horse battery staple"
    static let hasher = PasswordHasher(.leastCost)

    /// A server with local accounts, alice an admin and bob a reader, each with `password`, by `clock`.
    static func fixture(clock: SignInClock = SignInClock(), publicURL: String = "http://localhost:8080",
                        trustedProxies: [AddressRange] = [], volumes: [String] = []) async throws -> UserDataFixture {
        let fixture = try await UserDataFixture(publicURL: publicURL, volumes: volumes, auth: .local, trustedProxies: trustedProxies,
                                                now: { clock.now })
        let hash = try hasher.hash(password)
        try fixture.store.addAccount("alice", displayName: "Alice Liddell", role: .admin, passwordHash: hash, at: UserDataFixture.now)
        try fixture.store.addAccount("bob", displayName: "bob", role: .reader, passwordHash: hash, at: UserDataFixture.now)
        return fixture
    }

    static func accounts(_ fixture: UserDataFixture) throws -> LocalAccounts { try #require(fixture.services.accounts) }

    /// A sign-in answers with the user, as GET /api/v1/me does, and a cookie of a random token,
    /// HttpOnly, Secure, SameSite=Lax, for the server's path, kept for the longest a session lasts;
    /// the cookie then names the user, and the store holds the token's hash alone.
    @Test func aSignInGivesASessionWhoseCookieNamesTheUser() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client async throws in
            var alice = AccountBrowser(client: client)
            #expect(try await alice.session() == AuthSession(auth: "local", signedIn: false))
            let response = try await alice.signIn("alice", Self.password)
            #expect(response.status == .ok && response.headers[.cacheControl] == "no-store")
            let set = try #require(response.headers[.setCookie])
            let token = try #require(set.wholeMatch(of: /frus_session=([0-9a-f]{64}); Path=\/; Max-Age=2592000; HttpOnly; Secure; SameSite=Lax/)?.1)
            let me = try decode(Me.self, response)
            #expect(me.userId == "alice" && me.displayName == "Alice Liddell" && me.auth == "local")
            #expect(me.roles == [.reader, .curator, .admin] && me.userData && me.csrfToken.count == 64)
            #expect(try await alice.me() == me, "the cookie names her")
            #expect(try await alice.session() == AuthSession(auth: "local", signedIn: true))

            let id = SessionToken.id(of: String(token))
            #expect(try fixture.rows.stored("SELECT user_id FROM sessions WHERE session_id = ?", [.text(id)]) == [[.text("alice")]])
            #expect(try fixture.rows.stored("SELECT count(*) FROM sessions WHERE session_id = ?", [.text(String(token))]) == [[.integer(0)]],
                    "the store keeps the token's hash, never the token")
            #expect(try fixture.store.account("alice")?.lastSignInAt == UserDataFixture.now)

            // A request with no cookie, or another, acts for no one.
            let nobody = AccountBrowser(client: client)
            let refused = try await nobody.get("/api/v1/me")
            #expect(refused.status == .forbidden && problemCode(refused) == "NOT_SIGNED_IN")
            #expect(problemCode(try await nobody.get("/api/v1/me/tags")) == "NOT_SIGNED_IN")
            let forged = AccountBrowser(client: client, cookie: "frus_session=\(String(repeating: "0", count: 64))")
            #expect(problemCode(try await forged.get("/api/v1/me")) == "NOT_SIGNED_IN")
            let raw = AccountBrowser(client: client, cookie: "frus_session=\(id)")
            #expect(problemCode(try await raw.get("/api/v1/me")) == "NOT_SIGNED_IN", "the hash the store keeps signs no one in")

            // Among several cookies, those of other names and a token of the wrong form are passed over.
            let crowded = AccountBrowser(client: client, cookie: "theme=dark; frus_session=nope; frus_session=\(token); other=1")
            #expect(try await crowded.me().userId == "alice")
        }
    }

    /// The cookie is scoped to the path the server answers under (S14f), and a server whose address is
    /// another host takes no sign-in sent to this one, as a page under a name an attacker pointed at it
    /// would send it (the test client's `Host` is `localhost`).
    @Test func theCookieIsTheServersPathAloneAndItsAddresssAlone() async throws {
        let fixture = try await Self.fixture(publicURL: "http://localhost:8080/frus-explorer/")
        defer { withExtendedLifetime(fixture) {} }
        let body = #"{"name": "alice", "password": "\#(Self.password)"}"#
        try await fixture.app.test(.router) { client async throws in
            let headers: HTTPFields = [.origin: "http://localhost:8080", .contentType: "application/json"]
            let response = try await client.execute(uri: "/frus-explorer/api/v1/auth/sign-in", method: .post, headers: headers,
                                                    body: ByteBuffer(string: body))
            #expect(response.status == .ok)
            #expect(response.headers[.setCookie]?.contains("; Path=/frus-explorer/; ") == true)
            let out = try await client.execute(uri: "/frus-explorer/api/v1/auth/sign-out", method: .post, headers: [.origin: "http://localhost:8080"])
            #expect(out.headers[.setCookie] == "frus_session=; Path=/frus-explorer/; Max-Age=0; HttpOnly; Secure; SameSite=Lax")
        }
        let elsewhere = try await Self.fixture(publicURL: "https://frus.example.org")
        defer { withExtendedLifetime(elsewhere) {} }
        try await elsewhere.app.test(.router) { client async throws in
            let headers: HTTPFields = [.origin: "https://frus.example.org", .contentType: "application/json"]
            let refused = try await client.execute(uri: "/api/v1/auth/sign-in", method: .post, headers: headers, body: ByteBuffer(string: body))
            #expect(refused.status == .forbidden && problemCode(refused) == "HOST_NOT_ALLOWED")
            #expect(problemCode(try await client.execute(uri: "/api/v1/auth/session", method: .get)) == "HOST_NOT_ALLOWED")
        }
    }

    /// The done-when's refusals: a wrong password, a name with no account and a name with no password
    /// are refused in the same words, each after one verification of a password, so neither the answer
    /// nor its time says which names have accounts; and so is a disabled account, its password right or
    /// wrong, so that a guess learns nothing of a password it cannot use.
    @Test func aWrongPasswordAnUnknownNameAndNoPasswordAreRefusedAlike() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        let accounts = try Self.accounts(fixture)
        try await fixture.app.test(.router) { client async throws in
            var browser = AccountBrowser(client: client)
            var bodies: [APIProblem.Body] = []
            for (name, password) in [("alice", "not her password at all"), ("nobody", Self.password), ("owner", Self.password)] {
                let before = accounts.verifications
                let response = try await browser.signIn(name, password)
                #expect(response.status == .forbidden && response.headers[.setCookie] == nil, "\(name)")
                #expect(accounts.verifications == before + 1, "\(name): one verification, as for any password")
                var body = try decode(APIProblem.Body.self, response)
                body.instance = ""
                bodies.append(body)
            }
            #expect(bodies.allSatisfy { $0 == bodies[0] } && bodies[0].code == "SIGN_IN_FAILED")
            #expect(bodies[0].detail == "The name or the password is not right.")
            #expect(browser.cookie == nil)

            try fixture.store.setDisabled(true, of: "bob", at: UserDataFixture.now)
            let before = accounts.verifications
            let disabled = try await browser.signIn("bob", Self.password)
            #expect(disabled.status == .forbidden && disabled.headers[.setCookie] == nil)
            var body = try decode(APIProblem.Body.self, disabled)
            body.instance = ""
            #expect(body == bodies[0], "refused as a wrong password is")
            #expect(accounts.verifications == before + 1)
            try fixture.store.setDisabled(false, of: "bob", at: UserDataFixture.now)
            #expect(try await browser.signIn("bob", Self.password).status == .ok)
            #expect(try await browser.me().userId == "bob")
        }
    }

    /// The done-when's slowing, by name: five failures are heard, and the sixth attempt waits a
    /// second, refused unheard before it with Retry-After, the right password too; after the wait it is
    /// heard, and a sign-in forgets the name's failures. Each failure after the fifth doubles the wait.
    @Test func theFifthFailureSlowsTheSixthAttempt() async throws {
        let clock = SignInClock()
        let fixture = try await Self.fixture(clock: clock)
        defer { withExtendedLifetime(fixture) {} }
        let accounts = try Self.accounts(fixture)
        try await fixture.app.test(.router) { client async throws in
            var browser = AccountBrowser(client: client)
            for attempt in 1...5 {
                #expect(problemCode(try await browser.signIn("alice", "wrong guess number \(attempt)")) == "SIGN_IN_FAILED", "\(attempt)")
            }
            let heard = accounts.verifications
            let slowed = try await browser.signIn("alice", Self.password)
            #expect(slowed.status == .tooManyRequests && problemCode(slowed) == "SIGN_IN_SLOWED")
            #expect(slowed.headers[.retryAfter] == "1" && slowed.headers[.setCookie] == nil)
            #expect(try decode(APIProblem.Body.self, slowed).detail.contains("try again in a second"))
            #expect(accounts.verifications == heard, "a slowed attempt is refused unheard")
            #expect(problemCode(try await browser.signIn("bob", Self.password)) == nil, "another name is not slowed by hers")
            browser.cookie = nil

            clock.advance(by: 1)
            #expect(try await browser.signIn("alice", Self.password).status == .ok, "heard after the wait")
            #expect(problemCode(try await browser.signIn("alice", "one more wrong guess")) == "SIGN_IN_FAILED")
            #expect(try await browser.signIn("alice", Self.password).status == .ok, "her sign-in forgot the failures")

            for attempt in 1...6 {
                #expect(problemCode(try await browser.signIn("alice", "wrong again \(attempt)")) == "SIGN_IN_FAILED", "\(attempt)")
                if attempt == 5 { clock.advance(by: 1) }
            }
            #expect(try await browser.signIn("alice", Self.password).headers[.retryAfter] == "2", "the sixth failure doubles the wait")
            clock.advance(by: 2)
            #expect(problemCode(try await browser.signIn("alice", "seventh wrong guess")) == "SIGN_IN_FAILED")
            #expect(try await browser.signIn("alice", Self.password).headers[.retryAfter] == "4")
            // An hour after the last failure the count is forgotten.
            clock.advance(by: 3_600)
            #expect(try await browser.signIn("alice", Self.password).status == .ok)
        }
        // A name with no account is slowed as one with an account is.
        try await fixture.app.test(.router) { client async throws in
            var browser = AccountBrowser(client: client)
            for attempt in 1...5 { _ = try await browser.signIn("nobody", "guess \(attempt)") }
            #expect(problemCode(try await browser.signIn("nobody", "guess 6")) == "SIGN_IN_SLOWED")
        }
        #expect(SignInThrottle.wait(after: 4) == 0 && SignInThrottle.wait(after: 5) == 1 && SignInThrottle.wait(after: 9) == 16)
        #expect(SignInThrottle.wait(after: 30) == 900, "fifteen minutes at most")
    }

    /// Attempts sent at once are admitted one after another: of ten wrong guesses for one name sent
    /// together, five are heard and the rest slowed unheard, as if each had waited for the one before.
    @Test func attemptsSentAtOnceAreAdmittedOneAfterAnother() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        let accounts = try Self.accounts(fixture)
        try await fixture.app.test(.router) { client async throws in
            let codes = try await withThrowingTaskGroup(of: String?.self) { group in
                for attempt in 1...10 {
                    group.addTask {
                        var browser = AccountBrowser(client: client)
                        return problemCode(try await browser.signIn("alice", "guess number \(attempt)"))
                    }
                }
                return try await group.reduce(into: [String?]()) { $0.append($1) }
            }
            #expect(codes.filter { $0 == "SIGN_IN_FAILED" }.count == 5 && codes.filter { $0 == "SIGN_IN_SLOWED" }.count == 5, "\(codes)")
            #expect(accounts.verifications == 5)
        }
    }

    /// A sign-in that was verifying while the command line set a new password, or disabled the account,
    /// keeps no session: the store keeps it only for the password that was verified.
    @Test func aSignInVerifiedAgainstAnOldPasswordKeepsNoSession() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        let accounts = try Self.accounts(fixture)
        let alice = try #require(try fixture.store.account("alice"))
        try fixture.store.setPasswordHash(try Self.hasher.hash("a new passphrase for alice"), of: "alice")
        await #expect(throws: LocalAccounts.Refusal.failed) { _ = try await accounts.startSession(for: alice) }
        let bob = try #require(try fixture.store.account("bob"))
        try fixture.store.setDisabled(true, of: "bob", at: UserDataFixture.now)
        await #expect(throws: LocalAccounts.Refusal.failed) { _ = try await accounts.startSession(for: bob) }
        #expect(try fixture.rows.stored("SELECT count(*) FROM sessions", []) == [[.integer(0)]])
    }

    /// A role an admin changed while a sign-in verified the password is the new session's (S20d): the
    /// session carries the role the store holds once it is kept, not the one read before the hash.
    @Test func aSignInTakesTheRoleTheStoreHoldsOnceItsSessionIsKept() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        let accounts = try Self.accounts(fixture)
        let alice = try #require(try fixture.store.account("alice"))
        try fixture.store.setRole(.reader, of: "alice")
        let (_, user) = try await accounts.startSession(for: alice)
        #expect(user.roles == [.reader])
    }

    /// Cookies that name two people's sessions, as another site under the same host could set beside the
    /// browser's own, name no one.
    @Test func cookiesNamingTwoPeoplesSessionsNameNoOne() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client async throws in
            var alice = AccountBrowser(client: client)
            try await alice.signIn("alice", Self.password)
            var bob = AccountBrowser(client: client)
            try await bob.signIn("bob", Self.password)
            let both = AccountBrowser(client: client, cookie: "\(bob.cookie ?? ""); \(alice.cookie ?? "")")
            #expect(problemCode(try await both.get("/api/v1/me")) == "NOT_SIGNED_IN")
            #expect(try await both.session().signedIn == false)
        }
    }

    /// The slowing by address: five failures from one address, whatever names they give, slow the
    /// next attempt from it for any name, and from no other address. Behind a proxy FRUS_TRUSTED_PROXIES
    /// names, the address is the browser's, as X-Forwarded-For's last address outside the list gives it;
    /// from any other peer that header is the browser's own words, and is not read.
    @Test func anAddressThatFailsFiveTimesIsSlowedForEveryName() async throws {
        let direct = try await Self.fixture()
        defer { withExtendedLifetime(direct) {} }
        try await direct.app.test(.live) { client async throws in
            var browser = AccountBrowser(client: client, forwardedFor: "203.0.113.5")
            for attempt in 1...5 { _ = try await browser.signIn("name \(attempt)", "wrong") }
            browser.forwardedFor = "198.51.100.7"
            #expect(problemCode(try await browser.signIn("alice", Self.password)) == "SIGN_IN_SLOWED",
                    "the peer is this machine, whatever the header says")
        }

        let proxied = try await Self.fixture(trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(proxied) {} }
        try await proxied.app.test(.live) { client async throws in
            var browser = AccountBrowser(client: client, forwardedFor: "10.0.0.1, 203.0.113.5")
            for attempt in 1...5 { _ = try await browser.signIn("name \(attempt)", "wrong") }
            #expect(problemCode(try await browser.signIn("alice", Self.password)) == "SIGN_IN_SLOWED")
            browser.forwardedFor = "203.0.113.5, 198.51.100.7"
            #expect(try await browser.signIn("alice", Self.password).status == .ok, "another browser behind the proxy is heard")
        }
        #expect(ClientAddress.key("203.0.113.5") == "203.0.113.5" && ClientAddress.key("::ffff:203.0.113.5") == "203.0.113.5")
        #expect(ClientAddress.key("2001:db8:1:2:aaaa::1") == "2001:db8:1:2::/64")
        #expect(ClientAddress.key("2001:db8:1:2:bbbb:cccc:dddd:eeee") == "2001:db8:1:2::/64", "one host's network, whatever its address in it")
    }

    /// The done-when's expired session: a session ends fourteen days after its last use, and thirty
    /// after its sign-in however it is used; a use is written down once in five minutes.
    @Test func anExpiredSessionIsRefused() async throws {
        let clock = SignInClock()
        let fixture = try await Self.fixture(clock: clock)
        defer { withExtendedLifetime(fixture) {} }
        let day: TimeInterval = 86_400
        try await fixture.app.test(.router) { client async throws in
            var idle = AccountBrowser(client: client)
            try await idle.signIn("bob", Self.password)
            var daily = AccountBrowser(client: client)
            try await daily.signIn("alice", Self.password)
            for _ in 1...13 {
                clock.advance(by: day)
                #expect(try await daily.me().userId == "alice")
            }
            clock.advance(by: day)
            let expired = try await idle.get("/api/v1/me")
            #expect(problemCode(expired) == "NOT_SIGNED_IN", "fourteen days unused")
            #expect(try await idle.session().signedIn == false)
            for _ in 15...29 {
                clock.advance(by: day)
                #expect(try await daily.me().userId == "alice", "used each day, it lasts")
            }
            clock.advance(by: day)
            #expect(problemCode(try await daily.get("/api/v1/me")) == "NOT_SIGNED_IN", "thirty days after its sign-in")
        }
        #expect(LocalAccounts.expiry(createdAt: UserDataFixture.now, lastUsed: UserDataFixture.now)
                == UserDataFixture.now.addingTimeInterval(14 * day))
    }

    /// A disabled account, or one given a new password, is signed out: at once by the store, and within
    /// half a minute for a session the server holds, as a change the command line makes reaches it.
    @Test func aDisabledAccountsSessionEndsWithinHalfAMinute() async throws {
        let clock = SignInClock()
        let fixture = try await Self.fixture(clock: clock)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client async throws in
            var alice = AccountBrowser(client: client)
            try await alice.signIn("alice", Self.password)
            var bob = AccountBrowser(client: client)
            try await bob.signIn("bob", Self.password)
            try fixture.store.setDisabled(true, of: "alice", at: clock.now)
            try fixture.store.setPasswordHash(try Self.hasher.hash("a new passphrase for bob"), of: "bob")
            clock.advance(by: LocalAccounts.readAgainAfter)
            #expect(problemCode(try await alice.get("/api/v1/me")) == "NOT_SIGNED_IN")
            #expect(problemCode(try await bob.get("/api/v1/me")) == "NOT_SIGNED_IN")
            #expect(problemCode(try await bob.signIn("bob", Self.password)) == "SIGN_IN_FAILED")
            #expect(try await bob.signIn("bob", "a new passphrase for bob").status == .ok)
        }
    }

    /// A sign-out ends the session its cookie names, and clears the cookie, whether or not it named one.
    @Test func aSignOutEndsTheSession() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client async throws in
            var alice = AccountBrowser(client: client)
            try await alice.signIn("alice", Self.password)
            var other = AccountBrowser(client: client)
            try await other.signIn("alice", Self.password)
            let out = try await alice.signOut()
            #expect(out.status == .noContent)
            #expect(out.headers[.setCookie] == "frus_session=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax")
            #expect(problemCode(try await alice.get("/api/v1/me")) == "NOT_SIGNED_IN")
            #expect(try await other.me().userId == "alice", "her other session stays")
            #expect(try await AccountBrowser(client: client).signOut().status == .noContent)
            #expect(try fixture.rows.stored("SELECT count(*) FROM sessions", []) == [[.integer(1)]])

            // A sign-in in a browser that holds a session ends that one: a browser has one at a time.
            let first = try #require(other.cookie)
            try await other.signIn("bob", Self.password)
            #expect(try await other.me().userId == "bob")
            #expect(problemCode(try await AccountBrowser(client: client, cookie: first).get("/api/v1/me")) == "NOT_SIGNED_IN")
            #expect(try fixture.rows.stored("SELECT user_id FROM sessions", []) == [[.text("bob")]])
        }
    }

    /// Sign-in and sign-out are taken from a page of FRUS_PUBLIC_URL's address alone, by their Host
    /// and Origin, so no other site signs a browser in or out, with a JSON body of the fields they take.
    @Test func signInComesFromAPageOfThisAddressAsJSON() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client async throws in
            func post(_ body: String?, origin: String? = "http://localhost:8080",
                      contentType: String = "application/json") async throws -> TestResponse {
                var headers: HTTPFields = [.contentType: contentType]
                if let origin { headers[.origin] = origin }
                return try await client.execute(uri: "/api/v1/auth/sign-in", method: .post, headers: headers,
                                                body: body.map { ByteBuffer(string: $0) })
            }
            let good = #"{"name": "alice", "password": "\#(Self.password)"}"#
            #expect(problemCode(try await post(good, origin: "https://attacker.example")) == "ORIGIN_NOT_ALLOWED")
            #expect(problemCode(try await post(good, origin: nil)) == "ORIGIN_NOT_ALLOWED")
            #expect(problemCode(try await post(good, origin: "null")) == "ORIGIN_NOT_ALLOWED")
            #expect(problemCode(try await post(good, contentType: "text/plain")) == "UNSUPPORTED_MEDIA_TYPE")
            #expect(problemCode(try await post(String(repeating: " ", count: AuthRoutes.bodyLimit) + good)) == "CONTENT_TOO_LARGE")
            #expect(problemCode(try await post(#"{"name": "alice", "password": "x", "remember": true}"#)) == "UNKNOWN_FIELD")
            #expect(problemCode(try await post(#"{"name": "alice"}"#)) == "INVALID_FIELD")
            #expect(problemCode(try await post(#"{"name": "  ", "password": "\#(Self.password)"}"#)) == "INVALID_FIELD")
            let long = String(repeating: "p", count: PasswordRules.longest + 1)
            #expect(problemCode(try await post(#"{"name": "alice", "password": "\#(long)"}"#)) == "INVALID_FIELD")
            #expect(problemCode(try await post("[]")) == "INVALID_BODY")
            #expect(try await post(#"{"name": " alice ", "password": "\#(Self.password)"}"#).status == .ok, "a name's spaces are trimmed")

            var out: HTTPFields = [.origin: "https://attacker.example"]
            out[.cookie] = "frus_session=\(String(repeating: "a", count: 64))"
            #expect(problemCode(try await client.execute(uri: "/api/v1/auth/sign-out", method: .post, headers: out)) == "ORIGIN_NOT_ALLOWED")
            #expect(problemCode(try await client.execute(uri: "/api/v1/auth/sign-in", method: .get)) != nil, "sign-in is a POST")
            #expect(problemCode(try await client.execute(uri: "/api/v1/auth/session?x=1", method: .get)) == "UNKNOWN_PARAMETER")
        }
    }

    /// The done-when's first half: two users signed in with accounts keep their research apart, and
    /// one's token carries no change of the other's. SignInTests holds it through every route for a
    /// proxy's users; the user each route reads is the guard's either way.
    @Test func twoUsersResearchStaysApart() async throws {
        let fixture = try await Self.fixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        let d1 = "/api/v1/me/volumes/frus1961-63v06/documents/d1"
        try await fixture.app.test(.router) { client async throws in
            var alice = AccountBrowser(client: client)
            try await alice.signIn("alice", Self.password)
            var bob = AccountBrowser(client: client)
            try await bob.signIn("bob", Self.password)
            let tag = try decode(UserTag.self, try await alice.send(.post, "/api/v1/me/tags", #"{"name": "Berlin"}"#))
            #expect(try await alice.send(.put, "\(d1)/tags", #"{"tagIds": ["\#(tag.id)"]}"#).status == .ok)
            let note = try decode(Note.self, try await alice.send(.post, "\(d1)/notes", NoteJSON(bodyText: "Alice's note").json))

            #expect(try decode(TagList.self, try await bob.get("/api/v1/me/tags")).total == 0)
            #expect(try decode(DocumentTags.self, try await bob.get("\(d1)/tags")).items.isEmpty)
            #expect(try decode(NoteList.self, try await bob.get("/api/v1/me/notes")).total == 0)
            #expect(problemCode(try await bob.get("/api/v1/me/tags/\(tag.id)")) == "TAG_NOT_FOUND")
            #expect(problemCode(try await bob.get(NoteTests.note(note.id))) == "NOTE_NOT_FOUND")
            #expect(problemCode(try await bob.send(.delete, "/api/v1/me/tags/\(tag.id)")) == "TAG_NOT_FOUND")
            let crossed = try await bob.send(.post, "/api/v1/me/tags", #"{"name": "Mine"}"#, token: try await alice.me().csrfToken)
            #expect(problemCode(crossed) == "CSRF_TOKEN_INVALID")
            #expect(try await alice.me().roles == [.reader, .curator, .admin])
            #expect(try await bob.me().roles == [.reader])
            // An admin's route is alice's, and refused to bob for his role.
            #expect(problemCode(try await bob.get("/api/v1/admin/backup")) == "ROLE_REQUIRED")
        }
        #expect(try fixture.store.tags(of: "alice").map(\.name) == ["Berlin"])
        #expect(try fixture.store.tags(of: "bob").isEmpty && fixture.store.tags(of: "owner").isEmpty)
    }

    /// The corpus, the reader and its frame need no session, as behind a proxy that signs people in:
    /// the frame's scripts and figures come with no SameSite=Lax cookie.
    @Test func theCorpusAndTheReaderNeedNoSession() async throws {
        let fixture = try await Self.fixture(volumes: ["frus1894Nicaragua"])
        defer { withExtendedLifetime(fixture) {} }
        let figures = fixture.server.files.volumesDirectory.appendingPathComponent("frus1894Nicaragua.figures", isDirectory: true)
        try FileManager.default.createDirectory(at: figures, withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]).write(to: figures.appendingPathComponent("map.png"))
        try await fixture.app.test(.router) { client async throws in
            let nobody = AccountBrowser(client: client)
            for path in ["/api/v1/status", "/api/v1/volumes?limit=1", "/reader/host.js", "/reader/frus-selection.js",
                         "/api/v1/volumes/frus1894Nicaragua/figures/map.png", "/healthz"] {
                #expect(try await nobody.get(path).status == .ok, "\(path)")
            }
            #expect(problemCode(try await nobody.get("/api/v1/volumes/frus1894Nicaragua/figures/absent.png")) == "FIGURE_NOT_FOUND",
                    "the server's own answer, not a sign-in")
            #expect(try await nobody.get("/api/v1/me/volumes/frus1894Nicaragua/documents/d1/tags").status == .forbidden)
        }
    }

    /// Under FRUS_AUTH=none and header there is no sign-in to post, and the browser app is told it is
    /// signed in, as the one user or the user the proxy names.
    @Test func withoutLocalAccountsThereIsNoSignIn() async throws {
        let none = try await UserDataFixture()
        defer { withExtendedLifetime(none) {} }
        try await none.app.test(.router) { client async throws in
            let browser = AccountBrowser(client: client)
            #expect(try await browser.session() == AuthSession(auth: "none", signedIn: true))
            var signer = browser
            let response = try await signer.signIn("owner", Self.password)
            #expect(response.status == .notFound && problemCode(response) == "NOT_FOUND")
            #expect(problemCode(try await browser.signOut()) == "NOT_FOUND")
        }
        let header = try await UserDataFixture(auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(header) {} }
        try await header.app.test(.live) { client async throws in
            #expect(try await AccountBrowser(client: client).session() == AuthSession(auth: "header", signedIn: true))
        }
    }
}
