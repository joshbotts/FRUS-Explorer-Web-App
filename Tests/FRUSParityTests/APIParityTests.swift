// Checks 3 and 4 through the API: the search request decoder on every parity query, and the
// reader's HTML for every golden row, fetched from the server's route.

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

@Suite struct APIParityTests {
    /// Every query, written as a client writes it, decodes into exactly the `SearchParameters`
    /// tools/mac-golden builds for it on the Mac, which `LinuxSearch.parameters` mirrors. So each
    /// compiled expression the expressions golden records is what the API's search will compile:
    /// `matchExpressions(for:)` is a function of those parameters alone. Text is compared by its
    /// UTF-8 bytes too, since Swift's string equality would let a normalization slip through.
    @Test func everyQueryReachesTheKitAsTheMacBuildsIt() throws {
        let queries = try QueryList.load(Repository.layout.queries)
        #expect(queries.count == 482)
        for encoding in APIParity.Encoding.allCases {
            var mismatches: [String] = []
            for query in queries {
                let expected = try LinuxSearch.parameters(query)
                let request = try SearchRequest(formEncoded: APIParity.formEncode(query, encoding: encoding))
                let decoded = request.parameters
                let bytesEqual = decoded.keywords.map { Array($0.utf8) } == expected.keywords.map { Array($0.utf8) }
                    && decoded.phrase.map { Array($0.utf8) } == expected.phrase.map { Array($0.utf8) }
                    && decoded.excludedTerms.map { Array($0.utf8) } == expected.excludedTerms.map { Array($0.utf8) }
                if decoded != expected || !bytesEqual || request.limit != 20 || request.offset != 0 {
                    mismatches.append("\(query.id): \(APIParity.formEncode(query, encoding: encoding))")
                }
            }
            #expect(mismatches.isEmpty, "\(encoding): \(mismatches.count) queries decode differently:\n\(mismatches.joined(separator: "\n"))")
        }
        print("check 3 through the API: all \(queries.count) queries decode into the Mac's SearchParameters, in both encodings")
    }

    /// The traps the query list holds, one by one: the empty lists that mean opposite things, the
    /// blank texts, a literal plus, and the open date ranges.
    @Test func theListsTrapsDecodeExactly() throws {
        let queries = Dictionary(uniqueKeysWithValues: try QueryList.load(Repository.layout.queries).map { ($0.id, $0) })
        func decoded(_ id: String) throws -> SearchParameters {
            try SearchRequest(formEncoded: APIParity.formEncode(try #require(queries[id]))).parameters
        }
        #expect(try decoded("q406").yearKeys == [], "an empty year list, which matches nothing")
        #expect(try decoded("q403").volumeIds == [], "an empty volume list, which filters nothing")
        #expect(try decoded("q251").keywords == "")
        #expect(try decoded("q252").keywords == "   ")
        #expect(try decoded("q157").keywords?.contains("+5") == true)
        #expect(try decoded("q418").dateRange == DateRange(earliest: "1975-01-01", latest: nil))
        #expect(try decoded("q419").dateRange == DateRange(earliest: nil, latest: "1961-12-31"))
    }

    /// Check 4 through the API: each golden row, fetched from
    /// `/api/v1/volumes/{v}/documents/{d}/html?part=body` with the fixture volumes in the TEI
    /// folder, is the golden file's bytes. The server renders with the reader's figure URLs, as the
    /// golden was made, so no row needs a rewrite.
    @Test func everyGoldenRowIsServedAsTheReaderRendersIt() async throws {
        let (golden, directory) = try RenderParityTests.currentGolden()
        let temporary = try TemporaryDirectory()
        let files = DataDirectory(root: temporary.url.appendingPathComponent("data"))
        try files.prepare()
        try RepositoryFiles.mountTEI(ParityFixtures.volumes, at: files.volumesDirectory)
        let resources = try ServerResources.load(from: Repository.layout.upstream.appendingPathComponent("FRUSExplorer/Resources"))
        let state = ServerState(configuration: ServerConfiguration(dataDirectory: files.root))
        let reader = ReaderService(volumesDirectory: files.volumesDirectory, resources: resources)
        let app = Application(router: buildRouter(state: state, resources: resources, reader: reader))

        let (rendered, failures) = try await app.test(.router) { client in
            var rendered: [RenderedDocument] = []
            var failures: [String] = []
            for row in golden.rows {
                let response = try await client.execute(
                    uri: "/api/v1/volumes/\(row.volume)/documents/\(row.document)/html?part=body", method: .get)
                guard response.status == .ok, response.headers[.contentType] == "text/html; charset=utf-8" else {
                    failures.append("\(row.volume)/\(row.document): \(response.status.code) \(String(buffer: response.body).prefix(200))")
                    continue
                }
                rendered.append(RenderedDocument(volume: row.volume, document: row.document, html: String(buffer: response.body)))
            }
            return (rendered, failures)
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
        let mismatches = RenderParity.mismatches(rendered, golden: golden, directory: directory)
        #expect(mismatches.isEmpty, "\(mismatches.count) of \(golden.rows.count) rows differ:\n\(mismatches.map(\.description).joined(separator: "\n"))")
        #expect(await reader.parseCount == ParityFixtures.volumes.count, "one parse per volume")
        print("check 4 through the API: \(rendered.count - mismatches.count) of \(golden.rows.count) rows identical")
    }
}
