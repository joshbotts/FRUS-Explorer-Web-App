// Search, the inspector, browsing and the reader's page through the router, over a synthetic export
// served read-only. FRUSParityTests runs the parity queries and every golden row through the same
// routes over the kit's fixture index.

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif
import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

/// A server fixture serving the synthetic export as its live index.
func servingSyntheticExport(volumes: [String] = []) async throws -> ServerFixture {
    let fixture = try await ServerFixture(volumes: volumes)
    try SyntheticExport().write(to: fixture.files.liveIndex)
    await fixture.state.openExistingIndex(files: fixture.files)
    return fixture
}

@Suite struct SearchRouteTests {
    @Test func searchWaitsForAnIndexNamingTheStep() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)
            let body = try problem(response, .serviceUnavailable)
            #expect(body.code == "INDEX_NOT_READY" && body.detail.contains("waiting_for_export"))
        }
    }

    @Test func aSearchGivesTheExactCountAndAPageOfResults() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)
            #expect(response.status == .ok)
            let list = try decode(SearchResultList.self, response)
            #expect(list.total == 2 && list.countBasis == "exact" && list.retainedLimit == 7_500)
            #expect(list.limit == 20 && list.offset == 0)
            #expect(Set(list.items.map(\.documentId)) == ["d1", "d2"] && list.items.allSatisfy { $0.volumeId == "frus1961-63v06" })
            #expect(list.items.allSatisfy { $0.snippet.contains("<b>") && $0.bm25Score < 0 })
            #expect(list.coverage == Coverage(indexedVolumes: 2, indexedDocuments: 3, manifestVolumes: 553, indexVersion: 65))
            #expect(list.items.first?.header.isEmpty == false)

            let second = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=treaties&limit=1&offset=1", method: .get))
            #expect(second.total == 2 && second.items.count == 1 && second.items.first?.documentId == list.items.last?.documentId)
            let none = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=zanzibar", method: .get))
            #expect(none.total == 0 && none.items.isEmpty)
        }
    }

    /// A query with nothing left to search is the kit's refusal, carried as it names it.
    @Test func aRefusedQueryIsAProblemCarryingTheKitsRefusal() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            for query in ["keywords=", "keywords=treaties&includeDocumentText=false&includeSummaries=false&includeNotes=false"] {
                let body = try problem(try await client.execute(uri: "/api/v1/search?\(query)", method: .get), .badRequest)
                #expect(body.code == "EMPTY_QUERY" && body.searchError == "emptyQuery", "\(query)")
            }
            let bad = try problem(try await client.execute(uri: "/api/v1/search?keywords=x&limit=500", method: .get), .badRequest)
            #expect(bad.code == "INVALID_PARAMETER")
        }
    }

    /// The inspector answers before an import, from a scratch compiler, and after, from the served
    /// stack, through GET or a form-encoded POST; a refused query is a 200 naming the refusal.
    @Test func theInspectorShowsWhatTheKitCompiles() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let before = try decode(SearchInspection.self, try await client.execute(uri: "/api/v1/search/inspect?keywords=%3Dtreaty+-canal", method: .get))
            #expect(before.parse.exactTerms == ["treaty"] && before.parse.operands.map(\.kind) == ["word", "word"])
            #expect(before.parse.operands.map(\.isNegated) == [false, true])
            #expect(before.search.corpus?.contains("treaty") == true && before.search.error == nil)

            try SyntheticExport().write(to: fixture.files.liveIndex)
            await fixture.state.openExistingIndex(files: fixture.files)
            let posted = try await client.execute(uri: "/api/v1/search/inspect", method: .post,
                                                  body: ByteBuffer(string: "keywords=%3Dtreaty+-canal"))
            #expect(try decode(SearchInspection.self, posted) == before)
            let refused = try await client.execute(uri: "/api/v1/search/inspect?keywords=", method: .get)
            #expect(refused.status == .ok)
            #expect(try decode(SearchInspection.self, refused).search.error == "emptyQuery")
        }
    }

    /// A search between an import's rename of its file over `frus.db` and the server serving it
    /// waits: the path no longer names the served index's file, and a stack over it would answer as
    /// the old index.
    @Test func aSearchBetweenTheRenameAndTheSwitchWaits() async throws {
        let fixture = try await servingSyntheticExport()
        var next = SyntheticExport()
        next.exportedAt = "2026-10-07T09:00:00Z"
        let staged = fixture.directory.url.appendingPathComponent("next.sqlite")
        try next.write(to: staged)
        #expect(rename(staged.path, fixture.files.liveIndex.path) == 0)
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)
            let body = try problem(response, .serviceUnavailable)
            #expect(body.code == "INDEX_NOT_READY" && body.detail.contains("being installed"))
        }
    }

    /// An import that replaces the live index gives the next search a stack over the new file.
    @Test func aNewIndexGetsANewStack() async throws {
        let fixture = try await ServerFixture()
        let provider = ServedIndexProvider(state: fixture.state, resources: fixture.resources, volumesDirectory: fixture.files.volumesDirectory)
        let app = Application(router: buildRouter(state: fixture.state, resources: fixture.resources, reader: fixture.reader, provider: provider))
        let jobs = InProcessJobQueue()
        let coordinator = ImportCoordinator(files: fixture.files, importer: IndexImporter(files: fixture.files, writer: LocalIndexWriter(files: fixture.files)),
                                            state: fixture.state, jobs: jobs)
        @Sendable func importExport(_ export: SyntheticExport) async throws {
            try export.write(to: fixture.files.importDirectory.appendingPathComponent("export.sqlite"))
            _ = await coordinator.scan()
            _ = await coordinator.scan()
            await jobs.waitUntilIdle()
        }
        try await app.test(.router) { client in
            try await importExport(SyntheticExport())
            #expect(try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)).total == 2)
            #expect(try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=canal", method: .get)).total == 1)
            #expect(await provider.opened == 1)
            var second = SyntheticExport()
            second.exportedAt = "2026-10-07T09:00:00Z"
            try await importExport(second)
            #expect(try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)).total == 2)
            #expect(await provider.opened == 2)
        }
        #expect(FileManager.default.fileExists(atPath: fixture.files.previousIndex.path))
    }
}

@Suite struct BrowseRouteTests {
    @Test func aVolumesDocumentsAreListedInReadingOrder() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents", method: .get)
            #expect(response.status == .ok)
            let list = try decode(DocumentList.self, response)
            #expect(list.total == 2 && list.items.map(\.documentId) == ["d1", "d2"] && list.items.allSatisfy(\.inIndex))
            #expect(list.items.first?.header == "1. Telegram From the Embassy in the Soviet Union")
            let page = try decode(DocumentList.self, try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents?limit=1&offset=1", method: .get))
            #expect(page.total == 2 && page.items.map(\.documentId) == ["d2"])
            // A catalogue volume the index does not hold has no documents.
            #expect(try decode(DocumentList.self, try await client.execute(uri: "/api/v1/volumes/frus1861/documents", method: .get)).total == 0)
        }
    }

    @Test func aDocumentsMetadataNamesItsNeighbours() async throws {
        let fixture = try await servingSyntheticExport(volumes: ["frus1961-63v06"])
        try await fixture.app.test(.router) { client in
            let detail = try decode(DocumentDetail.self, try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents/d1", method: .get))
            #expect(detail.document.documentId == "d1" && detail.document.inIndex && !detail.document.isEditorialNote)
            #expect(detail.canonicalURL == "https://history.state.gov/historicaldocuments/frus1961-63v06/d1")
            #expect(detail.previous == nil && detail.next?.documentId == "d2" && detail.teiAvailable)
            let missing = try problem(try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents/d999", method: .get), .notFound)
            #expect(missing.code == "DOCUMENT_NOT_FOUND")
            #expect(try problem(try await client.execute(uri: "/api/v1/volumes/frus1969-76v99/documents/d1", method: .get), .notFound).code == "VOLUME_NOT_FOUND")
        }
    }

    @Test func browsingADocumentWaitsForAnIndex() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for uri in ["/api/v1/volumes/frus1961-63v06/documents", "/api/v1/volumes/frus1961-63v06/documents/d1"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(try problem(response, .serviceUnavailable).code == "INDEX_NOT_READY", "\(uri)")
            }
            // The catalogue does not wait.
            let volume = try await client.execute(uri: "/api/v1/volumes/frus1961-63v06", method: .get)
            #expect(volume.status == .ok)
        }
    }
}

@Suite struct ReaderPageRouteTests {
    static func uri(_ query: String = "") -> String { "/api/v1/volumes/frus1894Nicaragua/documents/d1/html\(query.isEmpty ? "" : "?\(query)")" }

    /// The page is the kit's, with the host script in its head and the fragment in its body, under
    /// a policy that runs nothing but the host script and the figure handler.
    @Test func thePageIsTheKitsWithTheHostScript() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        try await fixture.app.test(.router) { client in
            let page = try await client.execute(uri: Self.uri(), method: .get)
            #expect(page.status == .ok && page.headers[.contentType] == "text/html; charset=utf-8")
            let html = String(buffer: page.body)
            #expect(html.hasPrefix("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"))
            #expect(html.contains("<script src=\"/reader/host.js\" defer></script>\n</head>\n<body>\n"))
            #expect(html.hasSuffix("\n</body>\n</html>"))
            #expect(page.headers[.contentSecurityPolicy] == ReaderRoutes.pagePolicy)
            #expect(ReaderRoutes.pagePolicy.contains("script-src 'self'") && ReaderRoutes.pagePolicy.contains(ReaderRoutes.figureErrorHandlerHash))

            let body = String(buffer: try await client.execute(uri: Self.uri("part=body"), method: .get).body)
            #expect(html.contains("<body>\n\(body)\n</body>"), "the page's body is the fragment")
            let dark = String(buffer: try await client.execute(uri: Self.uri("colorScheme=dark&textSize=large"), method: .get).body)
            #expect(dark != html && dark.contains("<body>\n\(body)\n</body>"))
        }
    }

    /// The ETag names the rendering version and the page's bytes; asked again with it, the server
    /// answers 304.
    @Test func aPageAlreadyHeldIsNotSentAgain() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        try await fixture.app.test(.router) { client in
            let first = try await client.execute(uri: Self.uri(), method: .get)
            let tag = try #require(first.headers[.eTag])
            let version = try #require(first.headers[ReaderRoutes.renderingVersionHeader])
            #expect(tag.hasPrefix("W/\"\(version)-"))
            let again = try await client.execute(uri: Self.uri(), method: .get, headers: [.ifNoneMatch: tag])
            #expect(again.status == .notModified && again.body.readableBytes == 0)
            let dark = try await client.execute(uri: Self.uri("colorScheme=dark"), method: .get, headers: [.ifNoneMatch: tag])
            #expect(dark.status == .ok && dark.headers[.eTag] != tag)
        }
    }

    /// The index's effective classification reshapes the page, as the app's reader applies it: a
    /// document the index calls an editorial note is rendered as one, and the same document reads
    /// as its TEI shapes it when no index is served. The fixture index cannot show this, since its
    /// classifications are the TEI's.
    @Test func theIndexsClassificationReshapesThePage() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        let unserved = try await fixture.app.test(.router) { client in
            String(buffer: try await client.execute(uri: Self.uri("part=body"), method: .get).body)
        }
        try SyntheticExport().write(to: fixture.files.liveIndex)
        try SQLiteConnection(fixture.files.liveIndex.path, readOnly: false).execute(
            "UPDATE document_cache SET is_editorial_note = 1 WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd1'")
        await fixture.state.openExistingIndex(files: fixture.files)
        let served = try await fixture.app.test(.router) { client in
            String(buffer: try await client.execute(uri: Self.uri("part=body"), method: .get).body)
        }
        let parsed = try await fixture.reader.document(volume: "frus1894Nicaragua", document: "d1")
        #expect(!parsed.ast.isShapedAsEditorialNote, "the TEI shapes d1 as a document")
        let asNote = ReaderService.render(parsed, volume: "frus1894Nicaragua", classification: true, part: .body,
                                          brokenRefs: fixture.resources.brokenRefs).html
        let asTEI = ReaderService.render(parsed, volume: "frus1894Nicaragua", classification: nil, part: .body,
                                         brokenRefs: fixture.resources.brokenRefs).html
        #expect(asNote != asTEI)
        #expect(unserved == asTEI && served == asNote)
    }

    @Test func theHostScriptIsServed() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/reader/host.js", method: .get)
            #expect(response.status == .ok && response.headers[.contentType] == "text/javascript; charset=utf-8")
            let script = String(buffer: response.body)
            #expect(script.contains("frus-reader") && script.contains("frusexplorer:") && script.contains("highlightTapped"))
        }
    }

    /// A figure's image comes from the volume's `.figures` folder beside its TEI. Nothing else is
    /// served: not a name that leaves the folder, not another kind of file, not another volume.
    @Test func aFigureIsServedFromTheVolumesFigureFolder() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        let figures = fixture.files.volumesDirectory.appendingPathComponent("frus1894Nicaragua.figures", isDirectory: true)
        try FileManager.default.createDirectory(at: figures, withIntermediateDirectories: true)
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3])
        try png.write(to: figures.appendingPathComponent("map.png"))
        try Data("secret".utf8).write(to: figures.appendingPathComponent("notes.txt"))
        try Data("secret".utf8).write(to: fixture.files.root.appendingPathComponent("secret.png"))
        try await fixture.app.test(.router) { client in
            let image = try await client.execute(uri: "/api/v1/volumes/frus1894Nicaragua/figures/map.png", method: .get)
            #expect(image.status == .ok && image.headers[.contentType] == "image/png" && Data(buffer: image.body) == png)
            for (uri, code) in [
                ("/api/v1/volumes/frus1894Nicaragua/figures/absent.png", "FIGURE_NOT_FOUND"),
                ("/api/v1/volumes/frus1894Nicaragua/figures/notes.txt", "FIGURE_NOT_FOUND"),
                ("/api/v1/volumes/frus1894Nicaragua/figures/..%2F..%2Fsecret.png", "FIGURE_NOT_FOUND"),
                ("/api/v1/volumes/frus1894Nicaragua/figures/%2E%2E", "FIGURE_NOT_FOUND"),
                ("/api/v1/volumes/frus1969-76v99/figures/map.png", "VOLUME_NOT_FOUND"),
            ] {
                #expect(try problem(try await client.execute(uri: uri, method: .get), .notFound).code == code, "\(uri)")
            }
        }
    }

    /// The page names each figure by the server's address, which is the route above.
    @Test func figuresAreNamedByTheServersAddress() {
        let image = FigureImageName(volumeId: "frus1969-76ve09p1", graphic: "SpanishSaharaMap.jpg")
        #expect(ReaderRoutes.figureURL(for: image)?.absoluteString == "/api/v1/volumes/frus1969-76ve09p1/figures/SpanishSaharaMap.jpg.png")
        #expect(ReaderRoutes.figureURL(for: FigureImageName(volumeId: "../x", graphic: "a")) == nil)
        #expect(ReaderRoutes.figureURL(for: FigureImageName(volumeId: nil, graphic: "a")) == nil)
    }
}
