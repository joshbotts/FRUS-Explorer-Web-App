// The server under a path (PLAN's S14f): FRUS_PUBLIC_URL ending in /frus-explorer/, as a proxy that
// forwards the path as it is reaches it. The other suites serve at the root.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct BasePathTests {
    static let publicURL = "https://example.org/frus-explorer/"
    static let base = ServerConfiguration(publicURL: publicURL).basePath

    /// The server under the path, built as `buildApplication` builds it.
    static func app(_ fixture: ServerFixture, webClient: WebClient? = nil) -> some ApplicationProtocol {
        Application(router: ServedRouter(base: base, router: buildRouter(
            state: fixture.state, resources: fixture.resources, reader: fixture.reader, webClient: webClient, base: base)))
    }

    /// Every client route, the path's own and `index.html` answer with the build's page, its base
    /// written as the path, and the app's files are served under it.
    @Test func theAppIsServedUnderThePathWithItsBaseWritten() async throws {
        #expect(Self.base.path == "/frus-explorer/")
        let (directory, client) = try WebClientTests.builtApp(publicURL: Self.publicURL)
        defer { withExtendedLifetime(directory) {} }
        let page = WebClientTests.page(base: "/frus-explorer/")
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        try await Self.app(fixture, webClient: client).test(.router) { http in
            for uri in ["/frus-explorer/", "/frus-explorer/index.html", "/frus-explorer/search?keywords=treaties",
                        "/frus-explorer/doc/frus1961-63v06/d1", "/frus-explorer/browse"] {
                let response = try await http.execute(uri: uri, method: .get)
                #expect(response.status == .ok && String(buffer: response.body) == page, "\(uri)")
                #expect(response.headers[.contentSecurityPolicy] == WebClient.policy && response.headers[.cacheControl] == "no-cache", "\(uri)")
            }
            let script = try await http.execute(uri: "/frus-explorer/assets/index-abc123.js", method: .get)
            #expect(script.status == .ok && script.headers[.cacheControl] == "public, max-age=31536000, immutable")
            let icon = try await http.execute(uri: "/frus-explorer/favicon.svg", method: .get)
            #expect(icon.status == .ok && String(buffer: icon.body) == "<svg/>")
            let head = try await http.execute(uri: "/frus-explorer/browse", method: .head)
            #expect(head.status == .ok && head.headers[.contentLength] == String(page.utf8.count))
            let missing = try await http.execute(uri: "/frus-explorer/assets/index-old999.js", method: .get)
            #expect(missing.status == .notFound && !String(buffer: missing.body).contains("<!doctype"))
        }
    }

    /// The API answers under the path, with a query as it was sent; a problem names the path its
    /// client asked for. The reader's page names its host script and figures under the path.
    @Test func theAPIAndTheReaderAnswerUnderThePath() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua", "frus1969-76ve09p1"])
        let atRoot = try await fixture.app.test(.router) { http in
            String(buffer: try await http.execute(uri: "/api/v1/volumes/frus1894Nicaragua/documents/d1/html?part=body", method: .get).body)
        }
        try await Self.app(fixture).test(.router) { http in
            let volumes = try await http.execute(uri: "/frus-explorer/api/v1/volumes?limit=1", method: .get)
            #expect(volumes.status == .ok && String(buffer: volumes.body).contains(#""total":553"#))
            let unknown = try problem(try await http.execute(uri: "/frus-explorer/api/v1/nothing-here?x=1", method: .get), .notFound)
            #expect(unknown.code == "NOT_FOUND" && unknown.instance == "/frus-explorer/api/v1/nothing-here")
            #expect(unknown.detail == "No endpoint answers /frus-explorer/api/v1/nothing-here.")
            let refused = try problem(try await http.execute(uri: "/frus-explorer/api/v1/volumes?limit=ten", method: .get), .badRequest)
            #expect(refused.instance == "/frus-explorer/api/v1/volumes")

            let reader = "/frus-explorer/api/v1/volumes/frus1894Nicaragua/documents/d1/html"
            let page = try await http.execute(uri: reader, method: .get)
            #expect(page.status == .ok && page.headers[.contentSecurityPolicy] == ReaderRoutes.pagePolicy)
            #expect(String(buffer: page.body).contains("<script src=\"/frus-explorer/reader/host.js\" defer></script>\n</head>\n<body>\n"))
            let body = String(buffer: try await http.execute(uri: "\(reader)?part=body", method: .get).body)
            #expect(body == atRoot, "a page with no figure is the same under the path")
            let host = try await http.execute(uri: "/frus-explorer/reader/host.js", method: .get)
            #expect(host.status == .ok && String(buffer: host.body) == ReaderHostScript.source)
            #expect(String(buffer: page.body).contains("<script src=\"/frus-explorer/reader/frus-offset-engine.js\" defer></script>\n"))
            let engine = try await http.execute(uri: "/frus-explorer/reader/frus-offset-engine.js", method: .get)
            #expect(engine.status == .ok && String(buffer: engine.body) == kOffsetEngineJS)

            // frus1969-76ve09p1 d116 holds one figure, named under the path.
            let figured = String(buffer: try await http.execute(
                uri: "/frus-explorer/api/v1/volumes/frus1969-76ve09p1/documents/d116/html?part=body", method: .get).body)
            #expect(figured.components(separatedBy: "src=\"/frus-explorer/api/v1/volumes/frus1969-76ve09p1/figures/").count == 2)
            #expect(!figured.contains("src=\"/api/"))
        }
    }

    /// `/healthz` and `/readyz` answer at the root and under the path. The path without its slash,
    /// and the root, are redirected to it; nothing else outside it answers, not even a route's path
    /// at the root.
    @Test func healthAnswersAtBothAndNothingElseOutsideThePath() async throws {
        let (directory, client) = try WebClientTests.builtApp(publicURL: Self.publicURL)
        defer { withExtendedLifetime(directory) {} }
        let fixture = try await ServerFixture()
        try await Self.app(fixture, webClient: client).test(.router) { http in
            for uri in ["/healthz", "/frus-explorer/healthz"] {
                let health = try await http.execute(uri: uri, method: .get)
                #expect(health.status == .ok && String(buffer: health.body) == #"{"status":"ok"}"#, "\(uri)")
            }
            for uri in ["/readyz", "/frus-explorer/readyz"] {
                let ready = try await http.execute(uri: uri, method: .get)
                #expect(ready.status == .serviceUnavailable && String(buffer: ready.body).contains("waiting_for_export"), "\(uri)")
            }
            #expect(try await http.execute(uri: "/healthz", method: .head).status == .ok)

            for (uri, status, location) in [
                ("/frus-explorer", HTTPResponse.Status.permanentRedirect, "/frus-explorer/"),
                ("/frus-explorer?keywords=x", .permanentRedirect, "/frus-explorer/?keywords=x"),
                ("/", .found, "/frus-explorer/"),
            ] {
                let response = try await http.execute(uri: uri, method: .get)
                #expect(response.status == status && response.headers[.location] == location, "\(uri)")
            }
            for uri in ["/search", "/index.html", "/api/v1/status", "/assets/index-abc123.js", "/reader/host.js",
                        "/reader/frus-highlights.js", "/frus-explorers/", "/frus-explorer.html"] {
                let outside = try problem(try await http.execute(uri: uri, method: .get), .notFound)
                #expect(outside.instance == uri && outside.detail.hasPrefix("This server answers under /frus-explorer/"), "\(uri)")
            }
            #expect(try await http.execute(uri: "/frus-explorer", method: .post).status == .notFound)
        }
    }
}
