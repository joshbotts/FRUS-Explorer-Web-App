// The citation endpoint and its record files, and the browser app's files with their fallback,
// through the router.

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
            #expect(byDefault.numberSource == "tei" && byDefault.publicationYear == "1996" && byDefault.publicationYearSource == "tei")
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

    /// For each fixture volume, the year its TEI header states, as the kit reads it, is the manifest's,
    /// so a citation reads the same whether the volume's TEI is mounted or not.
    @Test func eachFixturesTEIYearIsItsManifests() throws {
        let resources = try TestResources.value()
        for volume in ["frus1894Nicaragua", "frus1961-63v06", "frus1969-76ve09p1"] {
            let year = try #require(TEIPublicationYear.read(from: RepositoryFiles.tei.appendingPathComponent("\(volume).xml")), "\(volume)")
            #expect(CitationRoutes.manifestYear(resources.volume(volume)?.publicationDate) == year, "\(volume)")
        }
    }

    /// The year the TEI header states comes first, as both of the app's hosts take it, and the printer's
    /// name follows it in the citation and both records: a header that names 2015 for frus1894Nicaragua
    /// gives that year and the Publishing Office, though the manifest says 1895. An indexed document
    /// whose TEI is not mounted takes the manifest's year.
    @Test func theYearIsTheTEIHeadersThenTheManifests() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        let tei = fixture.files.volumesDirectory.appendingPathComponent("frus1894Nicaragua.xml")
        let original = try String(contentsOf: tei, encoding: .utf8)
        let printed = #"type="publication-date">1895</date>"#
        #expect(original.components(separatedBy: printed).count == 2)
        try original.replacingOccurrences(of: printed, with: #"type="publication-date">2015</date>"#)
            .write(to: tei, atomically: true, encoding: .utf8)
        try await fixture.app.test(.router) { client in
            let cited = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri("frus1894Nicaragua", document: "d1"), method: .get))
            #expect(cited.publicationYear == "2015" && cited.publicationYearSource == "tei")
            #expect(cited.plainText.hasSuffix("(Washington, D.C.: United States Government Publishing Office, 2015), Document 1."))
            #expect(cited.bibtex.contains("  publisher = {United States Government Publishing Office},\n  address   = {Washington, D.C.},\n  year      = {2015},"))
            #expect(cited.ris.contains("PB  - United States Government Publishing Office\nCY  - Washington, D.C.\nPY  - 2015\n"))
        }
        let unmounted = try await servingSyntheticExport()
        try await unmounted.app.test(.router) { client in
            let cited = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri(document: "d2"), method: .get))
            #expect(cited.publicationYear == "1996" && cited.publicationYearSource == "manifest")
            #expect(cited.bibtex.contains("  year      = {1996},") && cited.ris.contains("PY  - 1996\n"))
        }
    }

    /// With no year in the TEI header, the records take the manifest date's first four-digit year, as
    /// the Mac's popover does: frus1969-76v32's header gives its date only as 2010-11-05, which the
    /// kit's scan does not read, and its manifest gives the same date.
    @Test func theRecordsYearFallsBackAsTheMacsDoes() {
        #expect(CitationRoutes.manifestYear("1996") == "1996")
        #expect(CitationRoutes.manifestYear("2010-11-05") == "2010")
        #expect(CitationRoutes.manifestYear("1969–1976") == "1969")
        #expect(CitationRoutes.manifestYear("c. 1872") == "1872")
        // Only the first four-digit run is read, and a year before 1751 is none.
        #expect(CitationRoutes.manifestYear("1700, reprinted 1972") == nil)
        #expect(CitationRoutes.manifestYear("19960") == nil)
        #expect(CitationRoutes.manifestYear("") == nil && CitationRoutes.manifestYear(nil) == nil)
        let statement = """
            <publicationStmt>
                <date calendar="gregorian" type="publication-date">2010-11-05</date>
                <date calendar="gregorian" type="content-date">1969 to 1972</date>
            </publicationStmt>
            """
        #expect(TEIPublicationYear.year(inHeader: statement) == nil)
    }

    /// frus1961-63v06 d1's records, as the kit's exporters write them for the index's row: the
    /// header for a title, the TEI's number, the TEI's year and the canonical URL. A pin move that
    /// changes the entry or the exporters changes these.
    static let bibtex = """
        @incollection{frus1961-63v06_d1,
          title     = {1. Telegram From the Embassy in the Soviet Union},
          booktitle = {Foreign Relations of the United States, 1961--1963, Volume VI, Kennedy-Khrushchev Exchanges},
          editor    = {Charles S. Sampson},
          publisher = {Government Printing Office},
          address   = {Washington, D.C.},
          year      = {1996},
          note      = {Document 1},
          url       = {https://history.state.gov/historicaldocuments/frus1961-63v06/d1}
        }
        """
    static let ris = """
        TY  - CHAP
        TI  - 1. Telegram From the Embassy in the Soviet Union
        T2  - Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges
        A3  - Charles S. Sampson
        PB  - Government Printing Office
        CY  - Washington, D.C.
        PY  - 1996
        UR  - https://history.state.gov/historicaldocuments/frus1961-63v06/d1
        M2  - FRUS Document 1
        ER  -\u{20}
        """

    /// Every style carries the same records, and a document the index lacks takes its id for a
    /// title, as the kit's exporters do for a document with no header.
    @Test func theRecordsAreTheKitsBibTeXAndRIS() async throws {
        let fixture = try await servingSyntheticExport(volumes: ["frus1961-63v06"])
        try await fixture.app.test(.router) { client in
            for style in ["historyAtState", "chicago", "turabian"] {
                let cited = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri(query: "style=\(style)"), method: .get))
                #expect(cited.bibtex == Self.bibtex, "\(style)")
                #expect(cited.ris == Self.ris, "\(style)")
            }
            let d3 = try decode(DocumentCitation.self, try await client.execute(uri: Self.uri(document: "d3"), method: .get))
            #expect(d3.bibtex.hasPrefix("@incollection{frus1961-63v06_d3,\n  title     = {d3},\n"))
            #expect(d3.ris.hasPrefix("TY  - CHAP\nTI  - d3\n") && d3.ris.contains("M2  - FRUS Document 3\n"))
        }
    }

    /// The records as files, as the Mac's Cite saves a .bib: named for the volume and the document,
    /// to be saved, and the same text the citation carries.
    @Test func eachRecordIsServedAsAFile() async throws {
        let fixture = try await servingSyntheticExport(volumes: ["frus1961-63v06"])
        try await fixture.app.test(.router) { client in
            for (suffix, type, record) in [("bib", "application/x-bibtex; charset=utf-8", Self.bibtex),
                                           ("ris", "application/x-research-info-systems; charset=utf-8", Self.ris)] {
                let response = try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents/d1/citation.\(suffix)", method: .get)
                #expect(response.status == .ok && response.headers[.contentType] == type, "\(suffix)")
                #expect(response.headers[.contentDisposition] == "attachment; filename=\"frus1961-63v06-d1.\(suffix)\"")
                #expect(response.headers[.xContentTypeOptions] == "nosniff")
                #expect(String(buffer: response.body) == record, "\(suffix)")
                let unknown = try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents/d1/citation.\(suffix)?style=chicago", method: .get)
                #expect(try problem(unknown, .badRequest).code == "UNKNOWN_PARAMETER")
                let missing = try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents/d9999/citation.\(suffix)", method: .get)
                #expect(try problem(missing, .notFound).code == "DOCUMENT_NOT_FOUND")
            }
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
    /// A built app's page, as Vite writes it: a `<base>` for the server to write its path into, and
    /// relative paths under it.
    static func page(base: String = "/") -> String {
        "<!doctype html><head><base href=\"\(base)\" /><title>FRUS Explorer Light</title><script type=\"module\" src=\"./assets/index-abc123.js\"></script>"
    }

    /// A built app in a temporary folder: its page, a hashed script and a root file, served under
    /// `publicURL`'s path.
    static func builtApp(publicURL: String = "http://localhost:8080") throws -> (TemporaryDirectory, WebClient) {
        let directory = try TemporaryDirectory()
        try FileManager.default.createDirectory(at: directory.url.appendingPathComponent("assets"), withIntermediateDirectories: true)
        try Data(page().utf8).write(to: directory.url.appendingPathComponent("index.html"))
        try Data("console.log('app')".utf8).write(to: directory.url.appendingPathComponent("assets/index-abc123.js"))
        try Data("<svg/>".utf8).write(to: directory.url.appendingPathComponent("favicon.svg"))
        var configuration = ServerConfiguration(publicURL: publicURL)
        configuration.webDirectory = directory.url
        return (directory, try #require(try WebClient.load(configuration)))
    }

    @Test func theAppsFilesAndClientRoutesAreServedWithItsPolicy() async throws {
        let (directory, client) = try Self.builtApp()
        defer { withExtendedLifetime(directory) {} }
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        let app = Application(router: buildRouter(state: fixture.state, resources: fixture.resources, reader: fixture.reader, webClient: client))
        let index = try String(contentsOf: directory.url.appendingPathComponent("index.html"), encoding: .utf8)
        #expect(index == Self.page(), "at the root, the page is the build's")
        try await app.test(.router) { http in
            for uri in ["/", "/index.html", "/search?keywords=treaties", "/doc/frus1961-63v06/d1", "/browse"] {
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
        #expect(throws: WebClientError(path: "/nonexistent/web")) { try WebClient.load(configuration) }
        let named = try ServerConfiguration.fromEnvironment(["FRUS_WEB_DIR": "/srv/web"])
        #expect(named.webDirectory.path == "/srv/web" && named.requiresWebDirectory)
        #expect(!(try ServerConfiguration.fromEnvironment([:])).requiresWebDirectory)
    }

    /// A page with no `<base href="/">` is not this release's build: the server could not serve it
    /// under a path, nor at the root once a client route is deep, so it refuses to start.
    @Test func aPageWithNoBaseIsRefused() throws {
        let directory = try TemporaryDirectory()
        try Data("<!doctype html><title>FRUS Explorer Light</title><script type=\"module\" src=\"/assets/index-abc123.js\"></script>".utf8)
            .write(to: directory.url.appendingPathComponent("index.html"))
        var configuration = ServerConfiguration()
        configuration.webDirectory = directory.url
        #expect(throws: WebClientError(path: directory.url.path, problem: .noBase)) { try WebClient.load(configuration) }
    }
}
