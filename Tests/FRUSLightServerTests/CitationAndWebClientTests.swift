// The citation endpoint, and the browser app's files with their fallback, through the router.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import Testing

@testable import FRUSLightAPI

@Suite struct CitationRouteTests {
    /// frus1961-63v06 d1 as the kit cites it, from the manifest's entry: the plain text Copy
    /// writes, in each style. A pin move that changes the entry or the formatters changes these.
    static let plain = [
        "historyAtState": "Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges, ed. Charles S. Sampson (Washington, D.C.: Government Printing Office, 1996), Document 1.",
        "chicago": "Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges, edited by Charles S. Sampson (Washington, D.C.: Government Printing Office, 1996), Document 1.",
        "turabian": "Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges. Edited by Charles S. Sampson. Washington, D.C.: Government Printing Office, 1996. Document 1.",
    ]

    static func uri(_ volume: String = "frus1961-63v06", document: String = "d1", query: String = "") -> String {
        "/api/v1/volumes/\(volume)/documents/\(document)/citation\(query.isEmpty ? "" : "?\(query)")"
    }

    /// With no index, the citation takes the TEI's printed number, in each of the kit's styles.
    @Test func eachStyleCitesTheDocumentAsTheKitDoes() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1961-63v06"])
        try await fixture.app.test(.router) { client in
            let byDefault = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri(), method: .get))
            #expect(byDefault.style == "historyAtState" && byDefault.plainText == Self.plain["historyAtState"])
            #expect(byDefault.citation.hasPrefix("_Foreign Relations of the United States_, 1961–1963"))
            #expect(byDefault.plainText == CitationPlainText.plain(byDefault.citation))
            #expect(byDefault.documentNumber == "1" && byDefault.documentLabel == "Doc 1")
            #expect(byDefault.numberSource == "tei" && byDefault.publicationYearSource == "manifest")
            #expect(byDefault.canonicalURL == "https://history.state.gov/historicaldocuments/frus1961-63v06/d1")
            #expect(byDefault.styles.map(\.style) == ["historyAtState", "chicago", "turabian"])
            #expect(byDefault.styles.map(\.shortName) == ["history.state.gov", "Chicago", "Turabian"])
            for style in ["chicago", "turabian"] {
                let cited = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri(query: "style=\(style)"), method: .get))
                #expect(cited.style == style && cited.plainText == Self.plain[style], "\(style)")
            }
        }
    }

    /// The index's number comes first, as the Mac's popover takes it; a row with none takes the
    /// TEI's, as the reader does; with neither, the number the id spells. Each source gives d1 a
    /// different number here, so the response shows which one was taken.
    @Test func theIndexsNumberComesFirstThenTheTEIsThenTheIds() async throws {
        let fixture = try await servingSyntheticExport(volumes: ["frus1961-63v06"])
        try await fixture.app.test(.router) { client in
            let fromTEI = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri(), method: .get))
            #expect(fromTEI.numberSource == "tei" && fromTEI.documentNumber == "1" && fromTEI.plainText == Self.plain["historyAtState"])
        }
        // The TEI prints 1 and the id spells 1; the index says 7.
        try SQLiteConnection(fixture.files.liveIndex.path, readOnly: false).execute(
            "UPDATE document_cache SET document_number = '7' WHERE volume_id = 'frus1961-63v06' AND document_id = 'd1'")
        // A new state reads the changed file.
        let state = ServerState(configuration: ServerConfiguration(dataDirectory: fixture.files.root))
        await state.openExistingIndex(files: fixture.files)
        let app = Application(router: buildRouter(state: state, resources: fixture.resources, reader: fixture.reader))
        try await app.test(.router) { client in
            let fromIndex = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri(), method: .get))
            #expect(fromIndex.numberSource == "index" && fromIndex.documentNumber == "7" && fromIndex.documentLabel == "Doc 7")
            #expect(fromIndex.plainText.hasSuffix("Document 7."))
        }
        // d2's row has no number and its TEI is not mounted, so the kit takes the number its id spells.
        let unmounted = try await servingSyntheticExport()
        try await unmounted.app.test(.router) { client in
            let fromId = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri(document: "d2"), method: .get))
            #expect(fromId.numberSource == "documentId" && fromId.documentNumber == "2" && fromId.plainText.hasSuffix("Document 2."))
        }
    }

    /// The other two fixture volumes, one of them past 2014, when the printer's name changed.
    @Test func thePrintersNameFollowsThePublicationYear() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua", "frus1969-76ve09p1"])
        try await fixture.app.test(.router) { client in
            let nicaragua = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri("frus1894Nicaragua", document: "d1"), method: .get))
            #expect(nicaragua.plainText == "Foreign Relations of the United States, 1894, Nicaragua (Mosquito Territory) (Washington, D.C.: Government Printing Office, 1895), Document 1.")
            let northAfrica = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri("frus1969-76ve09p1", document: "d87"), method: .get))
            #expect(northAfrica.plainText.hasSuffix("ed. Myra F. Burton (Washington, D.C.: United States Government Publishing Office, 2014), Document 87."))
        }
    }

    /// The manifest's year stands in for the year the app reads from the TEI header: for each
    /// fixture volume, the publication statement's year, a `when` attribute or a date's text, is
    /// the manifest's.
    @Test func eachFixturesManifestYearIsItsTEIs() throws {
        let resources = try TestResources.value()
        for volume in ["frus1894Nicaragua", "frus1961-63v06", "frus1969-76ve09p1"] {
            let head = try String(decoding: Data(contentsOf: RepositoryFiles.tei.appendingPathComponent("\(volume).xml")).prefix(8_192), as: UTF8.self)
            let statement = try #require(head.range(of: "<publicationStmt>").map { String(head[$0.upperBound...]) })
            let year = try #require(statement.firstMatch(of: /when="(\d{4})"/)?.1 ?? statement.firstMatch(of: />(\d{4})\s*</)?.1)
            #expect(resources.volume(volume)?.publicationDate?.hasPrefix(String(year)) == true, "\(volume)")
        }
    }

    @Test func eachWayACitationFailsIsAProblem() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1961-63v06"])
        try await fixture.app.test(.router) { client in
            for (uri, status, code) in [
                (Self.uri(query: "style=apa"), HTTPResponse.Status.badRequest, "INVALID_PARAMETER"),
                (Self.uri(query: "format=bibtex"), .badRequest, "UNKNOWN_PARAMETER"),
                (Self.uri("frus1969-76v99", document: "d1"), .notFound, "VOLUME_NOT_FOUND"),
                (Self.uri("frus1894Nicaragua", document: "d1"), .notFound, "TEI_NOT_AVAILABLE"),
                (Self.uri(document: "d9999"), .notFound, "DOCUMENT_NOT_FOUND"),
            ] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(try problem(response, status).code == code, "\(uri)")
            }
        }
    }
}

@Suite struct WebClientTests {
    /// A built app in a temporary folder: its page, a hashed script and a root file.
    static func builtApp() throws -> (TemporaryDirectory, WebClient) {
        let directory = try TemporaryDirectory()
        try FileManager.default.createDirectory(at: directory.url.appendingPathComponent("assets"), withIntermediateDirectories: true)
        try Data("<!doctype html><title>FRUS Explorer Light</title><script type=\"module\" src=\"/assets/index-abc123.js\"></script>".utf8)
            .write(to: directory.url.appendingPathComponent("index.html"))
        try Data("console.log('app')".utf8).write(to: directory.url.appendingPathComponent("assets/index-abc123.js"))
        try Data("<svg/>".utf8).write(to: directory.url.appendingPathComponent("favicon.svg"))
        var configuration = ServerConfiguration()
        configuration.webDirectory = directory.url
        return (directory, try #require(try WebClient.load(configuration)))
    }

    @Test func theAppsFilesAndClientRoutesAreServedWithItsPolicy() async throws {
        let (directory, client) = try Self.builtApp()
        defer { withExtendedLifetime(directory) {} }
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        let app = Application(router: buildRouter(state: fixture.state, resources: fixture.resources, reader: fixture.reader, webClient: client))
        let index = try String(contentsOf: directory.url.appendingPathComponent("index.html"), encoding: .utf8)
        try await app.test(.router) { http in
            for uri in ["/", "/search?keywords=treaties", "/doc/frus1961-63v06/d1", "/browse"] {
                let response = try await http.execute(uri: uri, method: .get)
                #expect(response.status == .ok && String(buffer: response.body) == index, "\(uri)")
                #expect(response.headers[.contentType] == "text/html; charset=utf-8", "\(uri)")
                #expect(response.headers[.contentSecurityPolicy] == WebClient.policy && response.headers[.cacheControl] == "no-cache", "\(uri)")
            }
            let script = try await http.execute(uri: "/assets/index-abc123.js", method: .get)
            #expect(script.status == .ok && script.headers[.contentType]?.hasPrefix("text/javascript") == true)
            #expect(script.headers[.cacheControl] == "public, max-age=31536000, immutable")
            // HEAD sends GET's headers, the length among them, and no body.
            let head = try await http.execute(uri: "/browse", method: .head)
            #expect(head.status == .ok && head.body.readableBytes == 0)
            #expect(head.headers[.contentLength] == String(index.utf8.count) && head.headers[.contentSecurityPolicy] == WebClient.policy)
        }
    }

    /// The fallback never answers what is not a client route: a missing file, an API path, a
    /// reader path or a method other than GET and HEAD. The routes themselves are untouched.
    @Test func theFallbackLeavesEverythingElseAlone() async throws {
        let (directory, client) = try Self.builtApp()
        defer { withExtendedLifetime(directory) {} }
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        let app = Application(router: buildRouter(state: fixture.state, resources: fixture.resources, reader: fixture.reader, webClient: client))
        try await app.test(.router) { http in
            let asset = try await http.execute(uri: "/assets/index-old999.js", method: .get)
            #expect(asset.status == .notFound && !String(buffer: asset.body).contains("<!doctype"))
            let api = try await http.execute(uri: "/api/v1/nothing-here", method: .get)
            #expect(try problem(api, .notFound).code == "NOT_FOUND")
            // A reader path is never a client route, with an extension or without one.
            for uri in ["/reader/nothing.js", "/reader/nothing"] {
                let reader = try await http.execute(uri: uri, method: .get)
                #expect(reader.status == .notFound && !String(buffer: reader.body).contains("<!doctype"), "\(uri)")
            }
            let post = try await http.execute(uri: "/search", method: .post)
            #expect(post.status == .notFound)
            let health = try await http.execute(uri: "/healthz", method: .get)
            #expect(String(buffer: health.body) == #"{"status":"ok"}"#)
            // HEAD on a server route says what GET says: before an import, /readyz is not ready.
            let readyHead = try await http.execute(uri: "/readyz", method: .head)
            #expect(readyHead.status == .serviceUnavailable && readyHead.headers[.contentType] != "text/html; charset=utf-8")
            let healthHead = try await http.execute(uri: "/healthz", method: .head)
            #expect(healthHead.status == .ok && healthHead.headers[.contentType]?.hasPrefix("application/json") == true)
            // The reader's page keeps its own policy alone.
            let page = try await http.execute(uri: "/api/v1/volumes/frus1894Nicaragua/documents/d1/html", method: .get)
            #expect(page.headers[values: .contentSecurityPolicy] == [ReaderRoutes.pagePolicy])
        }
    }

    @Test func aMissingAppIsAnErrorOnlyWhenNamed() throws {
        var configuration = ServerConfiguration()
        configuration.webDirectory = URL(fileURLWithPath: "/nonexistent/web")
        #expect(try WebClient.load(configuration) == nil)
        configuration.requiresWebDirectory = true
        #expect(throws: WebClientError.self) { try WebClient.load(configuration) }
        let named = try ServerConfiguration.fromEnvironment(["FRUS_WEB_DIR": "/srv/web"])
        #expect(named.webDirectory.path == "/srv/web" && named.requiresWebDirectory)
        #expect(!(try ServerConfiguration.fromEnvironment([:])).requiresWebDirectory)
    }
}
