// Checks 3 and 4 through the API, on the real Import path: the kit's fixture index, dropped into the
// server's drop zone as the owner drops an export, is imported, checked and installed, and opened
// read-only; then every parity query is searched and compiled over HTTP, and every golden row read
// as a page.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSLightAPI

/// A server with the fixture volumes' TEI mounted, serving the kit's fixture index once it has
/// imported it from the drop zone. The index is the shared fixture index's rollback-journal copy,
/// unstamped, which Import mode accepts because every document is at index version 65.
enum ServedFixture {
    static let resources = Repository.layout.upstream.appendingPathComponent(ParityIndex.resourcesPath)

    static func run<T: Sendable>(_ body: @escaping @Sendable (any TestClientProtocol, DataDirectory) async throws -> T) async throws -> T {
        let built = try await FixtureIndex.value()
        let directory = try TemporaryDirectory()
        defer { withExtendedLifetime(directory) {} }
        let files = DataDirectory(root: directory.url.appendingPathComponent("data"))
        try RepositoryFiles.mountTEI(ParityFixtures.volumes, at: files.volumesDirectory)
        let app = try await buildApplication(configuration: ServerConfiguration(
            dataDirectory: files.root, importPollInterval: .milliseconds(50), resourcesDirectory: resources))
        return try await app.test(.router) { client in
            // Staged outside the drop zone and moved in whole, as `docker compose cp` delivers a
            // file; the import removes what it installs, so it must not be the shared copy.
            let staged = directory.url.appendingPathComponent("staged.sqlite")
            try FileManager.default.copyItem(at: built.copy, to: staged)
            try FileManager.default.moveItem(at: staged, to: files.importDirectory.appendingPathComponent("fixtures.sqlite"))
            var readiness = ""
            for _ in 0..<2_400 {
                let response = try await client.execute(uri: "/readyz", method: .get)
                if response.status == .ok { return try await body(client, files) }
                readiness = String(buffer: response.body)
                try await Task.sleep(for: .milliseconds(50))
            }
            throw APIParityError("the import did not finish: \(readiness)")
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, _ response: TestResponse) throws -> T {
        try JSONDecoder().decode(type, from: Data(buffer: response.body))
    }
}

/// An HTTP answer the test did not expect, or the kit's refusal carried by a problem, named as the
/// kit names it so a record holds the same error as the golden file.
struct APIParityError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// The live index's file: its SHA-256, the names in its folder, and header bytes 18 and 19.
struct ServedFile: Equatable {
    let sha256: String
    let names: [String]
    let versions: [UInt8]

    init(_ files: DataDirectory) throws {
        let data = try Data(contentsOf: files.liveIndex)
        sha256 = ParityFormat.Digest.sha256(data)
        names = try FileManager.default.contentsOfDirectory(atPath: files.liveIndex.deletingLastPathComponent().path).sorted()
        versions = [data[18], data[19]]
    }
}

@Suite struct ServedAPIParityTests {
    static let coverage = Coverage(indexedVolumes: 3, indexedDocuments: 392, manifestVolumes: 553, indexVersion: 65)

    /// One page of a parity query's search, or the kit's refusal as an error.
    static func search(_ client: any TestClientProtocol, _ query: ParityQuery, limit: Int, offset: Int) async throws -> SearchResultList {
        let response = try await client.execute(uri: "/api/v1/search?\(APIParity.formEncode(query, limit: limit, offset: offset))", method: .get)
        if response.status == .badRequest, let refusal = try? ServedFixture.decode(APIProblem.Body.self, response).searchError {
            throw APIParityError(refusal)
        }
        guard response.status == .ok else { throw APIParityError("\(query.id): \(response.status.code) \(String(buffer: response.body))") }
        return try ServedFixture.decode(SearchResultList.self, response)
    }

    /// Check 3 through the API. Every query's count, first 50 results and tie tail, read over
    /// HTTP through ResultsLoop as the golden tool reads them, pass against the golden results, and
    /// are exactly what the kit gives in process, score bits and tie order included. Every query
    /// compiles over HTTP as the golden expressions say. The import installed the index as
    /// `frus.db` alone, in rollback-journal mode, and the searches leave it byte for byte as it was.
    @Test func checkThreePassesThroughTheAPI() async throws {
        let queries = try QueryList.load(Repository.layout.queries)
        let (status, records, inspections, anomalies, before, after) = try await ServedFixture.run { client, files in
            let status = try ServedFixture.decode(ServerStatus.self, try await client.execute(uri: "/api/v1/status", method: .get))
            let before = try ServedFile(files)
            var records: [ResultRecord] = []
            var anomalies: [String] = []
            for query in queries {
                var first: SearchResultList?
                func page(_ limit: Int, _ offset: Int) async throws -> SearchResultList {
                    if offset == 0, let first, first.limit == limit { return first }
                    let list = try await Self.search(client, query, limit: limit, offset: offset)
                    if list.countBasis != "exact" || list.coverage != Self.coverage || list.limit != limit || list.offset != offset {
                        anomalies.append("\(query.id) at \(offset): \(list.countBasis), \(list.coverage), \(list.limit)/\(list.offset)")
                    }
                    if let first, first.total != list.total { anomalies.append("\(query.id): total \(first.total), then \(list.total)") }
                    return list
                }
                records.append(await ResultsLoop.record(
                    id: query.id,
                    count: {
                        let list = try await page(ResultsLoop.limit, 0)
                        first = list
                        return list.total
                    },
                    page: { limit, offset in
                        try await page(limit, offset).items.map { SearchHit(volume: $0.volumeId, document: $0.documentId, score: $0.bm25Score) }
                    }))
            }
            struct Inspected: Decodable { let parse: ParseRecord; let search: SearchExpressionRecord }
            var inspections: [ExpressionRecord] = []
            for query in queries {
                let response = try await client.execute(uri: "/api/v1/search/inspect?\(APIParity.formEncode(query))", method: .get)
                guard response.status == .ok else { throw APIParityError("\(query.id): inspect answered \(response.status.code)") }
                let inspected = try ServedFixture.decode(Inspected.self, response)
                inspections.append(ExpressionRecord(id: query.id, parse: inspected.parse, search: inspected.search))
            }
            return (status, records, inspections, anomalies, before, try ServedFile(files))
        }

        #expect(status.index?.documents == 392 && status.index?.volumes == 3 && status.index?.exportedAt == nil)
        #expect(status.lastImport?.outcome == .installed)
        #expect(before.names == ["frus.db"] && before.versions == [1, 1])
        #expect(after == before, "the searches changed the live index or its folder")
        #expect(anomalies.isEmpty, "\(anomalies.joined(separator: "\n"))")

        // Against the golden results, as check 3 compares them: order, apart from exact Mac ties.
        guard case .present(let golden, let stale) = try GoldenValidation.load(.results, as: ResultsGolden.self, layout: Repository.layout) else {
            Issue.record("\(GoldenFile.results.rawValue) is pending")
            return
        }
        #expect(stale.isEmpty, "\(stale.joined(separator: "\n"))")
        var provenance = golden.provenance
        provenance.tool = "FRUSParityTests (Linux, through the API)"
        let report = SearchParity.compare(golden: golden, candidate: ResultsGolden(provenance: provenance, queries: records))
        #expect(report.passes, "\(report.differences.map(\.description).joined(separator: "\n"))")
        #expect(report.queryCount == queries.count)

        // Against the kit in process: nothing between the kit and the client changes a record.
        let inProcess = try await FixtureIndex.results()
        let differing = zip(records, inProcess).filter { $0 != $1 }.map(\.0.id)
        #expect(records.count == inProcess.count && differing.isEmpty, "\(differing.count) records differ from the kit's: \(differing.joined(separator: ", "))")

        // The expressions, every query in its own scope.
        let expressions = try SearchRunTests.expressionsGolden()
        let mismatches = ParseParity.recordMismatches(queries: queries, golden: expressions, linux: inspections)
        #expect(mismatches.isEmpty, "\(mismatches.count) differ:\n\(mismatches.map(\.description).joined(separator: "\n"))")
        let refused = inspections.filter { $0.search.error != nil }.count
        #expect(refused == 43 && records.filter { $0.error != nil }.count == 43)
        if report.passes, mismatches.isEmpty, differing.isEmpty {
            print("check 3 through the API: \(report.queryCount) queries, \(report.identical.count) identical and \(report.permuted.count) reordered only within Mac tie groups, every record the kit's own; \(queries.count) compiled as the golden file says, \(refused) refused; the live index unchanged")
        }
    }

    /// Check 4 through the page. Every golden row, read as the page the browser loads, holds the
    /// golden fragment between its one `<body>\n` and `\n</body>`, once the 8 figure images, which
    /// the server names by its own address, are named by the app's again; the body alone is the
    /// same; and every page's head is the kit's `ReaderPage.build` head with the host script. The
    /// index is served, so the reader applies its classifications, which for the fixtures are the
    /// TEI's.
    @Test func checkFourPassesThroughThePage() async throws {
        let (golden, directory) = try RenderParityTests.currentGolden()
        let rows = golden.rows.map { (volume: $0.volume, document: $0.document) }
        let (pages, bodies) = try await ServedFixture.run { client, _ in
            var pages: [(String, String, String)] = []
            var bodies: [String: String] = [:]
            for row in rows {
                let base = "/api/v1/volumes/\(row.volume)/documents/\(row.document)/html"
                let page = try await client.execute(uri: base, method: .get)
                let body = try await client.execute(uri: "\(base)?part=body", method: .get)
                guard page.status == .ok, body.status == .ok else {
                    throw APIParityError("\(row.volume)/\(row.document): \(page.status.code) and \(body.status.code)")
                }
                pages.append((row.volume, row.document, String(buffer: page.body)))
                bodies["\(row.volume)/\(row.document)"] = String(buffer: body.body)
            }
            return (pages.map { [$0.0, $0.1, $0.2] }, bodies)
        }

        let expectedHead = try await ReaderRenderer(layout: Repository.layout)
            .fullParsePass([ParityFixtures.volumes[0]], write: { ReaderPage.build(model: $0, head: ReaderRoutes.pageHead) })
            .documents.first?.html?.components(separatedBy: "<body>\n").first
        var heads = Set<String>()
        var mapped: [RenderedDocument] = []
        var replaced: [String: Int] = [:]
        var failures: [String] = []
        let figureBase = "/api/v1/volumes/"
        for page in pages {
            let (volume, document, html) = (page[0], page[1], page[2])
            let parts = html.components(separatedBy: "<body>\n")
            guard parts.count == 2, parts[1].hasSuffix("\n</body>\n</html>"), parts[1].components(separatedBy: "\n</body>").count == 2 else {
                failures.append("\(volume)/\(document): not exactly one body")
                continue
            }
            heads.insert(parts[0])
            let fragment = String(parts[1].dropLast("\n</body>\n</html>".count))
            if bodies["\(volume)/\(document)"] != fragment { failures.append("\(volume)/\(document): part=body is not the page's body") }
            let count = fragment.components(separatedBy: "src=\"\(figureBase)").count - 1
            if count > 0 { replaced["\(volume)/\(document)"] = count }
            let back = fragment.replacing(/src="\/api\/v1\/volumes\/([^\/"]+)\/figures\//) { "src=\"frusexplorer://figure/\($0.1)/" }
            mapped.append(RenderedDocument(volume: volume, document: document, html: back))
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
        #expect(heads.count == 1 && heads.first == expectedHead, "every page's head is ReaderPage.build's, with the host script")
        #expect(replaced == ["frus1969-76ve09p1/d87": 7, "frus1969-76ve09p1/d116": 1])
        let mismatches = RenderParity.mismatches(mapped, golden: golden, directory: directory)
        #expect(mismatches.isEmpty, "\(mismatches.count) rows differ:\n\(mismatches.map(\.description).joined(separator: "\n"))")
        print("check 4 through the page: \(mapped.count - mismatches.count) of \(golden.rows.count) rows identical, \(replaced.values.reduce(0, +)) figure images in \(replaced.count) rows named by the server; one head for every page")
    }

    /// Browsing through the API: the catalogue's coverage, each fixture volume's documents, reading
    /// order and structure, and a document's neighbours, as the kit's index holds them.
    @Test func browsingThroughTheAPIShowsTheIndex() async throws {
        let (golden, _) = try RenderParityTests.currentGolden()
        let built = try await FixtureIndex.value()
        var sequences: [String: [String]] = [:]
        for volume in ParityFixtures.volumes {
            sequences[volume] = try await built.index.pipeline.readingSequence(forVolume: volume).map(\.documentId)
        }
        let (list, volumes, documents, details) = try await ServedFixture.run { client, _ in
            let list = try ServedFixture.decode(VolumeList.self, try await client.execute(uri: "/api/v1/volumes?limit=1000", method: .get))
            var volumes: [String: Volume] = [:]
            var documents: [String: DocumentList] = [:]
            var details: [String: DocumentDetail] = [:]
            for volume in ParityFixtures.volumes {
                volumes[volume] = try ServedFixture.decode(Volume.self, try await client.execute(uri: "/api/v1/volumes/\(volume)", method: .get))
                documents[volume] = try ServedFixture.decode(DocumentList.self,
                                                             try await client.execute(uri: "/api/v1/volumes/\(volume)/documents?limit=1000", method: .get))
                details[volume] = try ServedFixture.decode(DocumentDetail.self,
                                                           try await client.execute(uri: "/api/v1/volumes/\(volume)/documents/d1", method: .get))
            }
            return (list, volumes, documents, details)
        }
        #expect(list.total == 553 && list.coverage == Self.coverage)
        #expect(ParityFixtures.volumes.map { documents[$0]?.total } == [140, 128, 134], "front matter, documents and back matter")
        #expect(Set(list.items.filter(\.indexed).map(\.volumeId)) == Set(ParityFixtures.volumes))
        for volume in ParityFixtures.volumes {
            let rows = Set(golden.rows.filter { $0.volume == volume }.map(\.document))
            #expect(volumes[volume]?.indexedDocuments == built.index.documents[volume] && volumes[volume]?.teiAvailable == true)
            #expect(volumes[volume]?.structure?.isEmpty == false, "\(volume) has a structure")
            let listed = documents[volume]?.items ?? []
            #expect(listed.map(\.documentId) == sequences[volume], "\(volume)'s list is the kit's reading order")
            #expect(Set(listed.filter(\.inIndex).map(\.documentId)) == rows, "\(volume)'s documents are the golden rows")
            #expect(documents[volume]?.total == listed.count && listed.count >= rows.count)
            let detail = details[volume]
            #expect(detail?.document.documentId == "d1" && detail?.teiAvailable == true)
            #expect(detail?.canonicalURL == "https://history.state.gov/historicaldocuments/\(volume)/d1")
            if let position = listed.firstIndex(where: { $0.documentId == "d1" }) {
                #expect(detail?.previous?.documentId == (position > 0 ? listed[position - 1].documentId : nil), "\(volume): d1's previous entry")
                #expect(detail?.next?.documentId == (position + 1 < listed.count ? listed[position + 1].documentId : nil), "\(volume): d1's next entry")
            }
        }
        print("browse through the API: 3 volumes of 553 indexed, \(ParityFixtures.volumes.map { "\(documents[$0]?.items.filter(\.inIndex).count ?? 0) of \(documents[$0]?.total ?? 0)" }.joined(separator: ", ")) entries in reading order held by the index")
    }

    /// The page's policy lets the figure handler run by its SHA-256 alone, and that handler is what
    /// the reader's markup holds.
    @Test func thePolicyAllowsExactlyTheFigureHandler() throws {
        let hex = ParityFormat.Digest.sha256(ReaderRoutes.figureErrorHandler)
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        #expect(ReaderRoutes.figureErrorHandlerHash == "sha256-\(Data(bytes).base64EncodedString())")
        let golden = try String(contentsOf: Repository.layout.golden.appendingPathComponent("render/html/frus1969-76ve09p1/d87.html"), encoding: .utf8)
        #expect(golden.contains("onerror=\"\(ReaderRoutes.figureErrorHandler)\""))
        #expect(golden.components(separatedBy: "onerror=").count - 1 == golden.components(separatedBy: "onerror=\"\(ReaderRoutes.figureErrorHandler)\"").count - 1,
                "every onerror in the reader's markup is the figure handler")
    }
}
