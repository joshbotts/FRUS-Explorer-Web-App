// The stored API keys through the router (PLAN's S20c): `PUT` and `DELETE /api/v1/me/secrets/{name}` take
// and clear a user's NARA and Zotero keys, `/api/v1/admin/secrets` the instance's NARA key for an admin
// alone, and no answer, export or backup gives a key back; every route passes /api/v1/me's guard, its
// host, its origin, its token and its body's size; a server starts only with the key file its stored
// keys need, saying the guide's sentence when it does not; and `frus-light secrets forget` removes what
// the key file does not open.

import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI
@testable import FRUSLightCore
@testable import FRUSLightServer

/// Whether a response's bytes hold `text` anywhere.
private func carries(_ response: TestResponse, _ text: String) -> Bool {
    String(decoding: Data(buffer: response.body), as: UTF8.self).contains(text)
}

@Suite struct SecretRouteTests {
    static let zotero = "P9NiFoyLeZu2bZNvvuQPDWsd"
    static let nara = "nara-key-0f1e2d3c4b5a"

    /// The done-when's first clause, through the routes: a key is taken, named as set with when, and
    /// cleared, and no answer gives it back; the server reads it, through the vault, as it was given.
    @Test func aKeyIsNamedAsSetAndNeverGivenBack() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client async throws in
            let browser = Browser(client: client)
            let empty = try await browser.get("/api/v1/me/secrets")
            #expect(empty.status == .ok && empty.headers[.cacheControl] == "no-store")
            #expect(try decode(SecretList.self, empty) == SecretList(secrets: [
                SecretStatus(name: "nara", set: false, updatedAt: nil), SecretStatus(name: "zotero", set: false, updatedAt: nil),
            ], instance: []))

            let set = try await browser.send(.put, "/api/v1/me/secrets/zotero", #"{"value": "  \#(Self.zotero)\n"}"#)
            #expect(set.status == .ok && set.headers[.cacheControl] == "no-store")
            #expect(try decode(SecretStatus.self, set) == SecretStatus(name: "zotero", set: true, updatedAt: "2026-10-24T00:00:00.000Z"))
            #expect(!carries(set, Self.zotero) && !carries(set, "value"), "its name, that it is set, and when, and nothing more")
            let listed = try await browser.get("/api/v1/me/secrets")
            #expect(try decode(SecretList.self, listed).secrets == [
                SecretStatus(name: "nara", set: false, updatedAt: nil), SecretStatus(name: "zotero", set: true, updatedAt: "2026-10-24T00:00:00.000Z"),
            ])
            #expect(!carries(listed, Self.zotero) && !carries(listed, "value"))
            #expect(try fixture.services.secrets.value(named: .zotero, for: .user("owner")) == Self.zotero, "the server reads it as it was given")

            // Set again, in place of the first; then cleared, and cleared again, which leaves none either way.
            #expect(try await browser.send(.put, "/api/v1/me/secrets/nara", #"{"value": "\#(Self.nara)"}"#).status == .ok)
            #expect(try fixture.services.secrets.value(named: .nara, for: .user("owner")) == Self.nara)
            #expect(try await browser.send(.put, "/api/v1/me/secrets/nara", #"{"value": "another-key"}"#).status == .ok)
            #expect(try fixture.services.secrets.value(named: .nara, for: .user("owner")) == "another-key")
            let cleared = try await browser.send(.delete, "/api/v1/me/secrets/nara")
            #expect(cleared.status == .noContent && cleared.body.readableBytes == 0)
            #expect(try await browser.send(.delete, "/api/v1/me/secrets/nara").status == .noContent)
            #expect(try fixture.services.secrets.value(named: .nara, for: .user("owner")) == nil)
            #expect(try decode(SecretList.self, try await browser.get("/api/v1/me/secrets")).secrets.map(\.set) == [false, true])

            // What a key may not be is refused in words that do not repeat it, and nothing is kept.
            for (body, code) in [(#"{"value": "two words"}"#, "INVALID_FIELD"), (#"{"value": ""}"#, "INVALID_FIELD"),
                                 (#"{"value": "line\nbreak-\#(Self.nara)"}"#, "INVALID_FIELD"), (#"{"value": 5}"#, "INVALID_FIELD"),
                                 (#"{"value": null}"#, "INVALID_FIELD"), ("{}", "INVALID_FIELD"), (#"["\#(Self.nara)"]"#, "INVALID_BODY"),
                                 (#"{"value": "x", "key": "\#(Self.nara)"}"#, "UNKNOWN_FIELD"),
                                 (#"{"value": "\#(String(repeating: "k", count: 1_025))"}"#, "INVALID_FIELD")] {
                let refused = try await browser.send(.put, "/api/v1/me/secrets/nara", body)
                #expect(refused.status == .badRequest && problemCode(refused) == code, "\(body.prefix(40))")
                #expect(!carries(refused, Self.nara) && !carries(refused, "two words") && !carries(refused, "kkkkkkkk"))
            }
            #expect(try fixture.services.secrets.value(named: .nara, for: .user("owner")) == nil)

            // A name that is no key's, and a query the routes do not take.
            for method in [HTTPRequest.Method.put, .delete] {
                let unknown = try await browser.send(method, "/api/v1/me/secrets/github", method == .put ? #"{"value": "k"}"# : nil)
                #expect(unknown.status == .notFound && problemCode(unknown) == "SECRET_NOT_FOUND", "\(method)")
            }
            #expect(problemCode(try await browser.send(.put, "/api/v1/me/secrets/NARA", #"{"value": "k"}"#)) == "SECRET_NOT_FOUND")
            #expect(problemCode(try await browser.get("/api/v1/me/secrets?name=nara")) == "UNKNOWN_PARAMETER")
            #expect(problemCode(try await browser.send(.put, "/api/v1/me/secrets/nara?x=1", #"{"value": "k"}"#)) == "UNKNOWN_PARAMETER")
            // No route gives one key.
            let one = try await browser.get("/api/v1/me/secrets/zotero")
            #expect(one.status != .ok && !carries(one, Self.zotero))
        }
    }

    /// Every route here passes /api/v1/me's guard: a change from another origin, without the token, not
    /// JSON or larger than the guard's 64 KiB is refused before the route reads it; a read or a change
    /// sent to another host is refused; and nothing answers while FRUS_USER_DATA is off.
    @Test func theGuardHoldsEverySecretsRoute() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        let changes: [(HTTPRequest.Method, String)] = [(.put, "/api/v1/me/secrets/zotero"), (.delete, "/api/v1/me/secrets/zotero"),
                                                       (.put, "/api/v1/admin/secrets/nara"), (.delete, "/api/v1/admin/secrets/nara")]
        try await fixture.app.test(.router) { client async throws in
            let browser = Browser(client: client)
            #expect(try await browser.send(.put, "/api/v1/me/secrets/zotero", #"{"value": "\#(Self.zotero)"}"#).status == .ok)
            #expect(try await browser.send(.put, "/api/v1/admin/secrets/nara", #"{"value": "\#(Self.nara)"}"#).status == .ok)
            let body = #"{"value": "replaced-key"}"#
            for (method, path) in changes {
                let json = method == .put ? body : nil
                let foreign = try await Browser(client: client, origin: "https://attacker.example").send(method, path, json)
                #expect(problemCode(foreign) == "ORIGIN_NOT_ALLOWED", "\(method) \(path)")
                let originless = try await Browser(client: client, origin: nil).send(method, path, json)
                #expect(problemCode(originless) == "ORIGIN_NOT_ALLOWED", "\(method) \(path)")
                let tokenless = try await browser.send(method, path, json, token: "")
                #expect(problemCode(tokenless) == "CSRF_TOKEN_INVALID", "\(method) \(path)")
                let stale = try await browser.send(method, path, json, token: String(repeating: "0", count: 64))
                #expect(problemCode(stale) == "CSRF_TOKEN_INVALID", "\(method) \(path)")
                guard method == .put else { continue }
                let form = try await browser.send(method, path, "value=replaced-key", contentType: "application/x-www-form-urlencoded")
                #expect(form.status == .unsupportedMediaType && problemCode(form) == "UNSUPPORTED_MEDIA_TYPE", "\(path)")
                let large = try await browser.send(method, path, #"{"value": "\#(String(repeating: "k", count: 70_000))"}"#)
                #expect(large.status == .contentTooLarge && problemCode(large) == "CONTENT_TOO_LARGE", "\(path)")
            }
            #expect(try fixture.services.secrets.value(named: .zotero, for: .user("owner")) == Self.zotero, "none of them changed a key")
            #expect(try fixture.services.secrets.value(named: .nara, for: .instance) == Self.nara)
        }

        // Sent to another host, as a page under a name an attacker pointed at this server sends them.
        let elsewhere = try await UserDataFixture(publicURL: "https://frus.example.org")
        defer { withExtendedLifetime(elsewhere) {} }
        try await elsewhere.app.test(.router) { client async throws in
            for (method, path) in [(HTTPRequest.Method.get, "/api/v1/me/secrets"), (.get, "/api/v1/admin/secrets")] + changes {
                let refused = try await client.execute(uri: path, method: method, headers: [.origin: "https://frus.example.org"],
                                                       body: method == .put ? ByteBuffer(string: #"{"value": "k"}"#) : nil)
                #expect(problemCode(refused) == "HOST_NOT_ALLOWED", "\(method) \(path)")
            }
        }
        #expect(try elsewhere.store.secretCounts().isEmpty)

        let off = try await UserDataFixture(userData: false)
        defer { withExtendedLifetime(off) {} }
        try await off.app.test(.router) { client async throws in
            for path in ["/api/v1/me/secrets", "/api/v1/admin/secrets"] {
                #expect(problemCode(try await Browser(client: client).get(path)) == "USER_DATA_OFF", "\(path)")
            }
            #expect(problemCode(try await Browser(client: client).send(.put, "/api/v1/me/secrets/nara", #"{"value": "k"}"#)) == "USER_DATA_OFF")
        }
        #expect(try off.store.secretCounts().isEmpty)
    }

    /// The instance's NARA key is an admin's to set and clear, under every sign-in, and a reader's to
    /// use: under local accounts a reader is refused each route, by the role, before the route reads the
    /// body, and is told only that the instance has one; a user's own keys stay theirs.
    @Test func theInstancesKeyIsAnAdminsAlone() async throws {
        let fixture = try await LocalAccountTests.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client async throws in
            var alice = AccountBrowser(client: client)
            try await alice.signIn("alice", LocalAccountTests.password)
            var bob = AccountBrowser(client: client)
            try await bob.signIn("bob", LocalAccountTests.password)

            // The last body is no change this route takes: the role is checked before the body is read.
            let refusedCases: [(HTTPRequest.Method, String, String?)] = [
                (.get, "/api/v1/admin/secrets", nil), (.put, "/api/v1/admin/secrets/nara", #"{"value": "\#(Self.nara)"}"#),
                (.delete, "/api/v1/admin/secrets/nara", nil), (.put, "/api/v1/admin/secrets/nara", #"{"unread": true}"#),
            ]
            for (method, path, body) in refusedCases {
                let refused: TestResponse
                if method == .get {
                    refused = try await bob.get(path)
                } else {
                    refused = try await bob.send(method, path, body)
                }
                #expect(refused.status == .forbidden && problemCode(refused) == "ROLE_REQUIRED", "\(method) \(path) \(body ?? "")")
            }
            #expect(try fixture.store.secretCounts().isEmpty, "a reader set nothing")
            let nobody = AccountBrowser(client: client)
            #expect(problemCode(try await nobody.get("/api/v1/admin/secrets")) == "NOT_SIGNED_IN")
            #expect(problemCode(try await nobody.get("/api/v1/me/secrets")) == "NOT_SIGNED_IN")

            let shared = try await alice.get("/api/v1/admin/secrets")
            #expect(try decode(SecretList.self, shared) == SecretList(secrets: [SecretStatus(name: "nara", set: false, updatedAt: nil)], instance: nil))
            #expect(try await alice.send(.put, "/api/v1/admin/secrets/nara", #"{"value": "\#(Self.nara)"}"#).status == .ok)
            #expect(problemCode(try await alice.send(.put, "/api/v1/admin/secrets/zotero", #"{"value": "k"}"#)) == "SECRET_NOT_FOUND",
                    "the instance keeps a NARA key alone")
            #expect(try decode(SecretList.self, try await alice.get("/api/v1/admin/secrets")).secrets == [
                SecretStatus(name: "nara", set: true, updatedAt: "2026-10-24T00:00:00.000Z"),
            ])

            // Bob is told the instance has one, and has none of his own; Alice's own are hers.
            #expect(try await alice.send(.put, "/api/v1/me/secrets/zotero", #"{"value": "\#(Self.zotero)"}"#).status == .ok)
            let bobs = try await bob.get("/api/v1/me/secrets")
            #expect(try decode(SecretList.self, bobs) == SecretList(secrets: [
                SecretStatus(name: "nara", set: false, updatedAt: nil), SecretStatus(name: "zotero", set: false, updatedAt: nil),
            ], instance: ["nara"]))
            #expect(!carries(bobs, Self.nara) && !carries(bobs, Self.zotero))
            #expect(try await bob.send(.put, "/api/v1/me/secrets/nara", #"{"value": "bobs-own-key"}"#).status == .ok)
            #expect(try fixture.services.secrets.value(named: .nara, for: .user("bob")) == "bobs-own-key")
            #expect(try fixture.services.secrets.value(named: .nara, for: .instance) == Self.nara)
            #expect(try fixture.services.secrets.value(named: .zotero, for: .user("bob")) == nil)
            #expect(try fixture.services.secrets.value(named: .zotero, for: .user("alice")) == Self.zotero)
            #expect(try await bob.send(.delete, "/api/v1/me/secrets/zotero").status == .noContent, "clearing what he has none of")
            #expect(try fixture.services.secrets.value(named: .zotero, for: .user("alice")) == Self.zotero, "leaves hers")

            #expect(try await alice.send(.delete, "/api/v1/admin/secrets/nara").status == .noContent)
            #expect(try decode(SecretList.self, try await bob.get("/api/v1/me/secrets")).instance == [])
            #expect(try fixture.services.secrets.value(named: .nara, for: .user("bob")) == "bobs-own-key")
        }
    }

    /// A user without the admin role, as a proxy's sign-in resolves one that `FRUS_ADMIN_USERS` does not
    /// name, keeps their own keys and not the instance's; with no sign-in the one user sets it, as they
    /// hold the three roles.
    @Test func theAdminRouteFollowsEachSignInsRoles() async throws {
        let reader = try await UserDataFixture(resolver: RolesResolver(roles: [.reader]))
        defer { withExtendedLifetime(reader) {} }
        try await reader.app.test(.router) { client async throws in
            let browser = Browser(client: client)
            #expect(problemCode(try await browser.get("/api/v1/admin/secrets")) == "ROLE_REQUIRED")
            #expect(problemCode(try await browser.send(.put, "/api/v1/admin/secrets/nara", #"{"value": "k"}"#)) == "ROLE_REQUIRED")
            #expect(try await browser.send(.put, "/api/v1/me/secrets/nara", #"{"value": "mine"}"#).status == .ok, "a reader keeps their own")
        }
        #expect(try reader.store.secretEntries(of: .instance).isEmpty)

        let owner = try await UserDataFixture()
        defer { withExtendedLifetime(owner) {} }
        try await owner.app.test(.router) { client async throws in
            #expect(try await Browser(client: client).send(.put, "/api/v1/admin/secrets/nara", #"{"value": "k"}"#).status == .ok)
        }
        #expect(try owner.services.secrets.value(named: .nara, for: .instance) == "k")
    }

    /// No other route carries a stored key: the JSON export, the notes' export and the backup's archive
    /// hold none of them, nor the key file's bytes.
    @Test func noExportOrBackupCarriesAKey() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client async throws in
            let browser = Browser(client: client)
            #expect(try await browser.send(.put, "/api/v1/me/secrets/zotero", #"{"value": "\#(Self.zotero)"}"#).status == .ok)
            #expect(try await browser.send(.put, "/api/v1/admin/secrets/nara", #"{"value": "\#(Self.nara)"}"#).status == .ok)
            _ = try await browser.send(.post, "/api/v1/me/tags", #"{"name": "Kept"}"#)
            let backups = UserStoreBackups(files: fixture.server.files, copyDirectory: nil,
                                           schedule: BackupSchedule(hour: 3, timeZone: TimeZone(identifier: "UTC")!))
            guard case .taken = try await backups.backUp(at: AdminBackupTests.hour) else {
                Issue.record("no backup was taken")
                return
            }
            let key = try Data(contentsOf: fixture.server.files.secretKey)
            for path in ["/api/v1/me/export", "/api/v1/me/export/contents", "/api/v1/me/notes/export", "/api/v1/admin/backup"] {
                let response = try await browser.get(path)
                #expect(response.status == .ok, "\(path)")
                let bytes = Data(buffer: response.body)
                #expect(!carries(response, Self.zotero) && !carries(response, Self.nara), "\(path)")
                #expect(bytes.range(of: key) == nil, "\(path) holds no key file")
            }
            let archive = Data(buffer: try await browser.get("/api/v1/admin/backup").body)
            #expect(String(decoding: archive.prefix(4_096), as: UTF8.self).contains(#""keyFileIncluded" : false"#),
                    "the archive's manifest says it holds no key file")
        }
    }

    /// The done-when's second clause, as a server starts: the first start makes the key file, for the
    /// server's user alone; a store that holds stored keys without its key file does not start, with the
    /// guide's sentence, and makes none in its place; nor does one whose key file is another; and a key
    /// file `FRUS_SECRET_KEY_FILE` names is read, and never made.
    @Test func aServerStartsOnlyWithTheKeyFileItsStoredKeysNeed() async throws {
        let directory = try TemporaryDirectory()
        let config = ServerConfiguration.testing(directory.url.appendingPathComponent("data"))
        let files = DataDirectory(root: config.dataDirectory)
        _ = try await buildApplication(configuration: config)
        let attributes = try FileManager.default.attributesOfItem(atPath: files.secretKey.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 && (attributes[.size] as? NSNumber)?.intValue == 32)
        let bytes = try Data(contentsOf: files.secretKey)
        _ = try await buildApplication(configuration: config)
        #expect(try Data(contentsOf: files.secretKey) == bytes, "a second start keeps it")

        let store = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
        let vault = try SecretVault.open(store: store, keyFile: files.secretKey, named: false).vault
        try vault.set(Self.zotero, named: .zotero, for: .user("owner"), at: UserDataFixture.now)

        try FileManager.default.removeItem(at: files.secretKey)
        await #expect(throws: SecretKeyProblem.missing(path: files.secretKey.path, secrets: 1)) {
            _ = try await buildApplication(configuration: config)
        }
        #expect(!FileManager.default.fileExists(atPath: files.secretKey.path), "no key file was made in its place")

        try Data(SecretKey(Array(0..<32))!.bytes).write(to: files.secretKey)
        await #expect(throws: SecretKeyProblem.self) { _ = try await buildApplication(configuration: config) }

        try bytes.write(to: files.secretKey)
        _ = try await buildApplication(configuration: config)

        var named = config
        named.secretKeyFile = directory.url.appendingPathComponent("frus_secret_key")
        await #expect(throws: SecretKeyProblem.namedFileMissing(path: directory.url.appendingPathComponent("frus_secret_key").path)) {
            _ = try await buildApplication(configuration: named)
        }
        try bytes.write(to: directory.url.appendingPathComponent("frus_secret_key"))
        _ = try await buildApplication(configuration: named)
    }

    /// `frus-light secrets forget`, with the server stopped: with a key file in place, the stored keys it
    /// does not open go and the rest stay; with none, nothing goes unless `--all` asks for every one,
    /// after which the next start makes a new key file; a key file `FRUS_SECRET_KEY_FILE` names must be
    /// there; and while a server holds the store, nothing goes.
    @Test func secretsForgetRemovesWhatTheKeyFileDoesNotOpen() async throws {
        let directory = try TemporaryDirectory()
        let configuration = UserCommandTests.configuration(directory, auth: .none)
        let files = DataDirectory(root: configuration.dataDirectory)
        try files.prepare()
        let store = try await UserCommandTests.store(configuration)
        let first = try SecretVault.open(store: store, keyFile: files.secretKey, named: false).vault
        try first.set(Self.zotero, named: .zotero, for: .user("owner"), at: UserDataFixture.now)
        try first.set(Self.nara, named: .nara, for: .instance, at: UserDataFixture.now)
        let again = "The people who had stored one enter it again in Settings ▸ Keys."

        let none = UserCommandTests.Script([])
        #expect(await SecretCommands.run(["forget"], configuration, console: none.console()) == 0)
        #expect(none.said == ["\(files.secretKey.path) opens every stored key the store holds, 2 of them, so none was forgotten."])

        // A server holds the store: nothing goes.
        let running = try FileLock(files.serverLock)
        #expect(try running.lock(.shared, wait: false))
        let refused = UserCommandTests.Script([])
        #expect(await SecretCommands.run(["forget", "--all"], configuration, console: refused.console()) == 1)
        #expect(refused.complaints == ["frus-light: the server is running, and holds app.db: stop it first, with docker compose stop frus"])
        running.unlock()
        #expect(try store.secretCounts().values.reduce(0, +) == 2)

        let other = SecretKey.random()
        try Data(other.bytes).write(to: files.secretKey)
        try SecretVault(key: other, keyFile: files.secretKey, store: store).set("a-third-key", named: .nara, for: .user("owner"),
                                                                               at: UserDataFixture.now)
        let some = UserCommandTests.Script([])
        #expect(await SecretCommands.run(["forget"], configuration, console: some.console()) == 0)
        #expect(some.said == ["Forgot 2 stored keys of the 3 the store held, which \(files.secretKey.path) does not open. \(again)"])
        #expect(try store.secretCounts() == [other.id: 1])

        // With no key file in place, a key file not there yet is no key file lost: nothing goes without --all.
        try FileManager.default.removeItem(at: files.secretKey)
        let kept = UserCommandTests.Script([])
        #expect(await SecretCommands.run(["forget"], configuration, console: kept.console()) == 1)
        #expect(kept.complaints == ["frus-light: there is no key file at \(files.secretKey.path) to open the 1 stored key the store holds, so nothing was forgotten. Put the key file back there if you kept a copy; if it is lost for good, run frus-light secrets forget --all, which removes every stored key, and the next start makes a new key file."])
        #expect(try store.secretCounts() == [other.id: 1])
        let all = UserCommandTests.Script([])
        #expect(await SecretCommands.run(["forget", "--all"], configuration, console: all.console()) == 0)
        #expect(all.said == ["Forgot the 1 stored key the store held, as --all asks: there is no key file at \(files.secretKey.path) to open it, and the next start makes one. \(again)"])
        #expect(try store.secretCounts().isEmpty)
        #expect(try SecretVault.open(store: store, keyFile: files.secretKey, named: false).origin == .made)

        let empty = UserCommandTests.Script([])
        #expect(await SecretCommands.run(["forget"], configuration, console: empty.console()) == 0)
        #expect(empty.said == ["The store holds no stored keys, so none was forgotten."])

        // --all with a key file in place forgets every key, and keeps the key file.
        let third = try SecretVault.open(store: store, keyFile: files.secretKey, named: false).vault
        try third.set(Self.zotero, named: .zotero, for: .user("owner"), at: UserDataFixture.now)
        let everything = UserCommandTests.Script([])
        #expect(await SecretCommands.run(["forget", "--all"], configuration, console: everything.console()) == 0)
        #expect(everything.said == ["Forgot every stored key, 1 of them, as --all asks; new ones are sealed under \(files.secretKey.path). \(again)"])
        #expect(try store.secretCounts().isEmpty && SecretKeyFile.key(at: files.secretKey)?.id == third.key.id)

        // A file there that is no key file is said, and nothing is removed.
        try third.set(Self.zotero, named: .zotero, for: .user("owner"), at: UserDataFixture.now)
        try Data(repeating: 1, count: 12).write(to: files.secretKey)
        let short = UserCommandTests.Script([])
        #expect(await SecretCommands.run(["forget", "--all"], configuration, console: short.console()) == 1)
        #expect(short.complaints == ["frus-light: \(SecretKeyProblem.wrongSize(path: files.secretKey.path, bytes: 12))"])
        #expect(try store.secretCounts().values.reduce(0, +) == 1)

        // A key file FRUS_SECRET_KEY_FILE names that is not there, as one not yet mounted: nothing goes.
        var named = configuration
        named.secretKeyFile = directory.url.appendingPathComponent("frus_secret_key")
        let unmounted = UserCommandTests.Script([])
        #expect(await SecretCommands.run(["forget", "--all"], named, console: unmounted.console()) == 1)
        #expect(unmounted.complaints == ["frus-light: \(SecretKeyProblem.namedFileMissing(path: directory.url.appendingPathComponent("frus_secret_key").path)) Nothing was forgotten."])
        #expect(try store.secretCounts().values.reduce(0, +) == 1)

        let wrong = UserCommandTests.Script([])
        #expect(await SecretCommands.run(["forget", "now"], configuration, console: wrong.console()) == 2)
        #expect(await SecretCommands.run([], configuration, console: wrong.console()) == 2)
        #expect(wrong.complaints == [SecretCommands.usage, SecretCommands.usage])
    }

    /// A PostgreSQL store, which every server sharing it opens, needs a key file named for all of them:
    /// a start with none named is refused, with the guide's sentence, and makes none.
    @Test(.enabled(if: TestPostgreSQL.isConfigured, "the PostgreSQL store needs FRUS_TEST_POSTGRES_URL, as scripts/swift --postgres sets"))
    func aPostgreSQLStoreNeedsANamedKeyFile() async throws {
        let directory = try TemporaryDirectory()
        let schema = TestPostgreSQL.newSchema()
        defer { try? TestPostgreSQL.drop(schema) }
        var config = ServerConfiguration.testing(directory.url.appendingPathComponent("data"))
        config.userStore = .postgreSQL(try TestPostgreSQL.configuration(schema: schema))
        await #expect(throws: SecretKeyProblem.postgreSQLNeedsNamedFile) { _ = try await buildApplication(configuration: config) }
        #expect(!FileManager.default.fileExists(atPath: DataDirectory(root: config.dataDirectory).secretKey.path))
        config.secretKeyFile = directory.url.appendingPathComponent("frus_secret_key")
        try Data(SecretKey.random().bytes).write(to: try #require(config.secretKeyFile))
        _ = try await buildApplication(configuration: config)
    }

    /// What a restore says of the stored keys a backup carries: that the key file in place opens them,
    /// or that the server will not start until the one they were sealed under is back.
    @Test func aRestoreSaysWhichKeyFileItsStoredKeysNeed() throws {
        let directory = try TemporaryDirectory()
        let configuration = UserCommandTests.configuration(directory, auth: .none)
        let files = DataDirectory(root: configuration.dataDirectory)
        try files.prepare()
        let key = SecretKey(Array(0..<32))!
        let carried = BackupManifest.Secrets(table: "secrets", rows: 2, keyIds: [key.id], keyFileIncluded: false)
        #expect(StoreCommands.keyFileLine(for: nil, configuration, files: files) == nil)
        #expect(StoreCommands.keyFileLine(for: BackupManifest.Secrets(table: "secrets", rows: 0, keyIds: [], keyFileIncluded: false),
                                          configuration, files: files) == nil)
        let missing = try #require(StoreCommands.keyFileLine(for: carried, configuration, files: files))
        #expect(missing.isProblem && missing.line.hasPrefix("It carries 2 stored keys, sealed under the key file with id 141c99669e6cf0cc, and there is no key file at \(files.secretKey.path)."))
        #expect(missing.line.contains(SecretKeyProblem.forget))
        try Data(SecretKey.random().bytes).write(to: files.secretKey)
        #expect(StoreCommands.keyFileLine(for: carried, configuration, files: files)?.isProblem == true)
        try Data(key.bytes).write(to: files.secretKey)
        #expect(StoreCommands.keyFileLine(for: carried, configuration, files: files)?.line == "It carries 2 stored keys, which the key file \(files.secretKey.path) opens.")
        // Keys under two key files, one of them the one in place: it names the other alone.
        let mixed = BackupManifest.Secrets(table: "secrets", rows: 3, keyIds: [key.id, "9f3a6c0d51e27b48"], keyFileIncluded: false)
        let line = try #require(StoreCommands.keyFileLine(for: mixed, configuration, files: files))
        #expect(line.isProblem && line.line.hasPrefix("It carries 3 stored keys: the key file \(files.secretKey.path), id \(key.id), opens those sealed under it, and not those sealed under the key file with id 9f3a6c0d51e27b48."))
    }
}
