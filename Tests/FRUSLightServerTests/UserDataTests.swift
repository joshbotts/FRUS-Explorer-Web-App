// /api/v1/me and the user's tags through the router (PLAN's S14c): tags answer as the app's rules
// leave them, and a write without the token, from another origin or to another host is refused, as
// is a body that is not JSON or is too large, and anything under /me while FRUS_USER_DATA is off.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

/// A server with a user store, served as `buildApplication` serves it.
struct UserDataFixture {
    let server: ServerFixture
    let store: SQLiteUserStore
    let rows: UserStoreRows
    let configuration: ServerConfiguration
    let services: UserDataServices
    /// The queue an import runs on (S16c), which a test waits on.
    let jobs: InProcessJobQueue

    static let now = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z

    /// `volumes` from fixtures/tei are in the server's TEI folder, for the routes that read a page;
    /// `indexed`, the server serves the synthetic export, for the routes that read the index;
    /// `importLimit`, an import's largest file; `resolver`, who a request acts for, the store's single
    /// user by default; `userStore`, the store the configuration names, whichever the fixture holds.
    init(publicURL: String = "http://localhost:8080", userData: Bool = true, volumes: [String] = [],
         indexed: Bool = false, importLimit: Int = UserDataServices.importBodyLimit,
         resolver: (any UserResolver)? = nil, userStore: ServerConfiguration.UserStoreChoice = .sqlite) async throws {
        server = try await indexed ? servingSyntheticExport(volumes: volumes) : ServerFixture(volumes: volumes)
        let url = server.files.userStore
        store = try await SQLiteUserStore(url: url, backupsDirectory: server.files.backupsDirectory)
        rows = try UserStoreRows(url)
        configuration = ServerConfiguration(dataDirectory: server.files.root, publicURL: publicURL, userData: userData,
                                            userStore: userStore)
        jobs = InProcessJobQueue()
        services = UserDataServices(store: store, configuration: configuration, jobs: jobs, importLimit: importLimit,
                                    resolver: resolver, now: { Self.now })
    }

    var app: some ApplicationProtocol {
        let base = configuration.basePath
        return Application(router: ServedRouter(base: base, router: buildRouter(
            state: server.state, resources: server.resources, reader: server.reader, userData: services, base: base)))
    }
}

/// What the browser app sends: its origin, the token, and JSON.
struct Browser {
    let client: any TestClientProtocol
    var origin: String? = "http://localhost:8080"
    var base = ""

    func me() async throws -> Me {
        try decode(Me.self, try await client.execute(uri: base + "/api/v1/me", method: .get))
    }

    func get(_ path: String) async throws -> TestResponse {
        try await client.execute(uri: base + path, method: .get)
    }

    /// A request that changes state, with the user's token unless `token` names another, and `json`
    /// as its body.
    func send(_ method: HTTPRequest.Method, _ path: String, _ json: String? = nil, token: String? = nil,
              contentType: String? = "application/json") async throws -> TestResponse {
        var headers: HTTPFields = [:]
        if let origin { headers[.origin] = origin }
        if let token { headers[CSRFTokens.header] = token } else { headers[CSRFTokens.header] = try await me().csrfToken }
        if let contentType, json != nil { headers[.contentType] = contentType }
        return try await client.execute(uri: base + path, method: method, headers: headers,
                                        body: json.map { ByteBuffer(string: $0) })
    }
}

func problemCode(_ response: TestResponse) -> String? {
    try? decode(APIProblem.Body.self, response).code
}

@Suite struct UserDataTests {
    @Test func meNamesTheUserTheServerActsForAndTheirToken() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/me", method: .get)
            #expect(response.status == .ok && response.headers[.cacheControl] == "no-store")
            let me = try decode(Me.self, response)
            #expect(me.userId == "owner" && me.displayName == "Owner" && me.auth == "none")
            #expect(me.roles == [.reader, .curator, .admin] && me.userData)
            #expect(me.csrfToken.count == 64 && me.csrfToken.allSatisfy(\.isHexDigit))
            #expect(try await Browser(client: client).me().csrfToken == me.csrfToken, "one token while the process runs")
            let unknown = try await client.execute(uri: "/api/v1/me?x=1", method: .get)
            #expect(unknown.status == .badRequest && problemCode(unknown) == "UNKNOWN_PARAMETER")
        }
        #expect(CSRFTokens().accepts(fixture.services.tokens.token(for: "owner"), for: "owner") == false,
                "another process's tokens are not this one's")
    }

    /// The done-when's first half: made, renamed, given to documents, merged and deleted through
    /// the API, tags answer as the app's rules leave them.
    @Test func tagsAnswerThroughTheAPIAsTheAppsRulesLeaveThem() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let made = try await browser.send(.post, "/api/v1/me/tags", #"{"name": "  Primary source\n"}"#)
            #expect(made.status == .created)
            let primary = try decode(UserTag.self, made)
            #expect(primary.name == "Primary source" && primary.createdAt == "2026-10-24T00:00:00.000Z")
            #expect(made.headers[.location] == "/api/v1/me/tags/\(primary.id)")
            let cold = try decode(UserTag.self, try await browser.send(.post, "/api/v1/me/tags", #"{"name": "cold war"}"#))
            let berlin = try decode(UserTag.self, try await browser.send(.post, "/api/v1/me/tags", #"{"name": "Berlin"}"#))

            let list = try decode(TagList.self, try await browser.get("/api/v1/me/tags"))
            #expect(list.total == 3 && list.items.map(\.name) == ["Berlin", "cold war", "Primary source"])
            let renaming = try await browser.send(.patch, "/api/v1/me/tags/\(cold.id)", #"{"name": "Cold War"}"#)
            #expect(renaming.status == .ok)
            let renamed = try decode(UserTag.self, renaming)
            #expect(renamed.name == "Cold War" && renamed.lastModified == renamed.createdAt, "the fixture's clock stands still")
            #expect(try decode(UserTag.self, try await browser.get("/api/v1/me/tags/\(cold.id.lowercased())")).name == "Cold War")

            // The picker's Done on two documents, and a note and a project that name the tags.
            let d1 = "/api/v1/me/volumes/frus1961-63v06/documents/d1/tags"
            let d2 = "/api/v1/me/volumes/frus1961-63v06/documents/d2/tags"
            let set = try await browser.send(.put, d1, #"{"tagIds": ["\#(cold.id)", "\#(primary.id)"]}"#)
            #expect(set.status == .ok)
            #expect(try decode(DocumentTags.self, set) == DocumentTags(volumeId: "frus1961-63v06", documentId: "d1", items: [renamed, primary]))
            _ = try await browser.send(.put, d2, #"{"tagIds": ["\#(berlin.id)", "\#(cold.id)"]}"#)
            try fixture.rows.addNote("N1", tagIds: [cold.id, primary.id])
            try fixture.rows.addProject("P1", tagIds: [cold.id])

            // Merge Cold War into Berlin: d1 carries Berlin in its place, and d2, which carried
            // both, Berlin once.
            let merged = try await browser.send(.post, "/api/v1/me/tags/\(cold.id)/merge", #"{"into": "\#(berlin.id)"}"#)
            #expect(merged.status == .ok)
            #expect(try decode(UserTag.self, merged) == berlin)
            #expect(try decode(DocumentTags.self, try await browser.get(d1)).items.map(\.name) == ["Berlin", "Primary source"])
            #expect(try decode(DocumentTags.self, try await browser.get(d2)).items.map(\.name) == ["Berlin"])
            #expect(try fixture.rows.assignments().filter { $0.documentId == "d2" }.count == 1)
            #expect(try fixture.rows.note("N1") == [UserStoreRows.json([primary.id, berlin.id]), "2026-10-24T00:00:00.000Z"])
            #expect(try fixture.rows.project("P1")[0] == UserStoreRows.json([berlin.id]))
            #expect(try await browser.get("/api/v1/me/tags/\(cold.id)").status == .notFound)

            // The rail's × on d1, then Delete Tag on Berlin.
            let removed = try await browser.send(.delete, "/api/v1/me/volumes/frus1961-63v06/documents/d1/tags/\(primary.id)")
            #expect(removed.status == .ok)
            #expect(try decode(DocumentTags.self, removed).items.map(\.name) == ["Berlin"])
            let deleted = try await browser.send(.delete, "/api/v1/me/tags/\(berlin.id)")
            #expect(deleted.status == .noContent && deleted.body.readableBytes == 0)
            #expect(try decode(DocumentTags.self, try await browser.get(d1)).items.isEmpty)
            #expect(try decode(DocumentTags.self, try await browser.get(d2)).items.isEmpty)
            #expect(try fixture.rows.note("N1")[0] == UserStoreRows.json([primary.id]))
            #expect(try fixture.rows.project("P1")[0] == "[]")
            #expect(try fixture.rows.assignments().isEmpty)
            #expect(try decode(TagList.self, try await browser.get("/api/v1/me/tags")).items.map(\.name) == ["Primary source"])
        }
    }

    /// The done-when's second half: a write without the token, from another origin or to another
    /// host is refused, and changes nothing.
    @Test func aWriteWithoutTheTokenFromAnotherOriginOrToAnotherHostIsRefused() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let body = #"{"name": "Revisit"}"#
            for token in ["", "0123", String(repeating: "0", count: 64)] {
                let refused = try await browser.send(.post, "/api/v1/me/tags", body, token: token)
                #expect(refused.status == .forbidden && problemCode(refused) == "CSRF_TOKEN_INVALID", "\(token)")
            }
            var headers: HTTPFields = [.origin: "http://localhost:8080", .contentType: "application/json"]
            let tokenless = try await client.execute(uri: "/api/v1/me/tags", method: .post, headers: headers, body: ByteBuffer(string: body))
            #expect(tokenless.status == .forbidden && problemCode(tokenless) == "CSRF_TOKEN_INVALID")
            for origin in [nil, "null", "https://attacker.example", "http://localhost:9999", "https://localhost:8080",
                           "http://localhost:8080/", "http://localhost.attacker.example:8080"] {
                let refused = try await Browser(client: client, origin: origin).send(.post, "/api/v1/me/tags", body)
                #expect(refused.status == .forbidden && problemCode(refused) == "ORIGIN_NOT_ALLOWED", "\(origin ?? "no origin")")
            }
            headers = [.origin: "https://attacker.example"]
            headers[CSRFTokens.header] = try await browser.me().csrfToken
            let deletion = try await client.execute(uri: "/api/v1/me/tags/\(UUID().uuidString)", method: .delete, headers: headers)
            #expect(deletion.status == .forbidden && problemCode(deletion) == "ORIGIN_NOT_ALLOWED", "a delete is a write")
            #expect(try fixture.store.tags(of: "owner").isEmpty, "nothing was made")

            // An address on this machine goes by three names, at its port.
            let loopback = try await Browser(client: client, origin: "http://127.0.0.1:8080").send(.post, "/api/v1/me/tags", body)
            #expect(loopback.status == .created)
        }

        // A server whose address is another host: the test client sends `Host: localhost`, as a
        // page under a name an attacker pointed at this server would send its own.
        let elsewhere = try await UserDataFixture(publicURL: "https://frus.example.org")
        defer { withExtendedLifetime(elsewhere) {} }
        try await elsewhere.app.test(.router) { client in
            for (method, path) in [(HTTPRequest.Method.get, "/api/v1/me"), (.get, "/api/v1/me/tags"), (.post, "/api/v1/me/tags")] {
                let refused = try await client.execute(uri: path, method: method, headers: [.origin: "https://frus.example.org"],
                                                       body: method == .post ? ByteBuffer(string: #"{"name": "x"}"#) : nil)
                #expect(refused.status == .forbidden && problemCode(refused) == "HOST_NOT_ALLOWED", "\(method) \(path)")
            }
            let corpus = try await client.execute(uri: "/api/v1/status", method: .get)
            #expect(corpus.status == .ok, "the corpus is not the user's, and answers any host")
        }
        #expect(try elsewhere.store.tags(of: "owner").isEmpty)
    }

    @Test func aChangesBodyIsJSONOfACappedSize() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            for type in ["text/plain", "application/x-www-form-urlencoded", "multipart/form-data; boundary=x"] {
                let refused = try await browser.send(.post, "/api/v1/me/tags", #"{"name": "x"}"#, contentType: type)
                #expect(refused.status == .unsupportedMediaType && problemCode(refused) == "UNSUPPORTED_MEDIA_TYPE", "\(type)")
            }
            let charset = try await browser.send(.post, "/api/v1/me/tags", #"{"name": "x"}"#, contentType: "application/json; charset=utf-8")
            #expect(charset.status == .created)
            let large = #"{"name": ""# + String(repeating: "x", count: 64 * 1_024) + #""}"#
            let tooLarge = try await browser.send(.post, "/api/v1/me/tags", large)
            #expect(tooLarge.status == .contentTooLarge && problemCode(tooLarge) == "CONTENT_TOO_LARGE")
            for (json, code) in [("[1]", "INVALID_BODY"), ("not json", "INVALID_BODY"), (#"{"name": "x", "id": "y"}"#, "UNKNOWN_FIELD"),
                                 ("{}", "INVALID_FIELD"), (#"{"name": 5}"#, "INVALID_FIELD"), (#"{"name": " \n"}"#, "INVALID_FIELD")] {
                let refused = try await browser.send(.post, "/api/v1/me/tags", json)
                #expect(refused.status == .badRequest && problemCode(refused) == code, "\(json)")
            }
            let bodiless = try await browser.send(.post, "/api/v1/me/tags")
            #expect(bodiless.status == .badRequest && problemCode(bodiless) == "INVALID_BODY")
            #expect(try fixture.store.tags(of: "owner").map(\.name) == ["x"])
        }
    }

    @Test func eachRefusalNamesWhatItCouldNotFind() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let tag = try decode(UserTag.self, try await browser.send(.post, "/api/v1/me/tags", #"{"name": "A"}"#))
            let unknown = UUID().uuidString
            for response in [try await browser.get("/api/v1/me/tags/\(unknown)"),
                             try await browser.send(.patch, "/api/v1/me/tags/\(unknown)", #"{"name": "B"}"#),
                             try await browser.send(.delete, "/api/v1/me/tags/not-a-uuid"),
                             try await browser.send(.post, "/api/v1/me/tags/\(tag.id)/merge", #"{"into": "\#(unknown)"}"#),
                             try await browser.send(.put, "/api/v1/me/volumes/frus1961-63v06/documents/d1/tags",
                                                    #"{"tagIds": ["\#(tag.id)", "\#(unknown)"]}"#)] {
                #expect(response.status == .notFound && problemCode(response) == "TAG_NOT_FOUND")
            }
            #expect(try decode(DocumentTags.self, try await browser.get("/api/v1/me/volumes/frus1961-63v06/documents/d1/tags")).items.isEmpty,
                    "a set with a tag the user has not changes nothing")
            let itself = try await browser.send(.post, "/api/v1/me/tags/\(tag.id)/merge", #"{"into": "\#(tag.id)"}"#)
            #expect(itself.status == .badRequest && problemCode(itself) == "INVALID_FIELD")
            let volume = try await browser.get("/api/v1/me/volumes/frus9999v99/documents/d1/tags")
            #expect(volume.status == .notFound && problemCode(volume) == "VOLUME_NOT_FOUND")
            let document = try await browser.get("/api/v1/me/volumes/frus1961-63v06/documents/\(String(repeating: "d", count: 300))/tags")
            #expect(document.status == .badRequest && problemCode(document) == "INVALID_PARAMETER")
        }
    }

    /// `FRUS_USER_DATA=off`: the instance is read-only. /me says so, and every resource under it
    /// is refused, reads included.
    @Test func userDataOffKeepsTheInstanceReadOnly() async throws {
        let fixture = try await UserDataFixture(userData: false)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            #expect(try await browser.me().userData == false)
            let read = try await browser.get("/api/v1/me/tags")
            #expect(read.status == .forbidden && problemCode(read) == "USER_DATA_OFF")
            let write = try await browser.send(.post, "/api/v1/me/tags", #"{"name": "A"}"#)
            #expect(write.status == .forbidden && problemCode(write) == "USER_DATA_OFF")
            let document = try await browser.get("/api/v1/me/volumes/frus1961-63v06/documents/d1/tags")
            #expect(problemCode(document) == "USER_DATA_OFF")
        }
        #expect(try fixture.store.tags(of: "owner").isEmpty)
    }

    /// Under a path (S14f) the routes answer as at the root, and name the path the client used.
    @Test func theUsersRoutesAnswerUnderThePath() async throws {
        let fixture = try await UserDataFixture(publicURL: "http://localhost:8080/frus-explorer/")
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client, base: "/frus-explorer")
            #expect(try await browser.me().userData)
            let made = try await browser.send(.post, "/api/v1/me/tags", #"{"name": "A"}"#)
            let tag = try decode(UserTag.self, made)
            #expect(made.headers[.location] == "/frus-explorer/api/v1/me/tags/\(tag.id)")
            let missing = try await browser.get("/api/v1/me/tags/\(UUID().uuidString)")
            #expect(try decode(APIProblem.Body.self, missing).instance.hasPrefix("/frus-explorer/api/v1/me/tags/"))
            let off = try await browser.send(.post, "/api/v1/me/tags", #"{"name": "B"}"#, token: "wrong")
            #expect(problemCode(off) == "CSRF_TOKEN_INVALID")
        }
    }
}
