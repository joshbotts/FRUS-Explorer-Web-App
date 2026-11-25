// Browse's clusters' routes (PLAN's S28d), over the bundled files: what each refuses, in the API's words; a server with no
// index, whose clusters list their documents and open none; the map's refusals in the clusters' words; and Save as
// Working Corpus, the user's, with the kit's capture at the app's 7,500, its name in the reader's time zone, and its
// refusals. Every answer's agreement with the kit over the fixture index is `ClustersParityTests`'.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import SemanticVectorsKit
import Testing

@testable import FRUSLightAPI

@Suite struct ClustersRouteTests {
    /// The bundled map's layout identity and regions, as the kit reads them.
    static func mapIndex() throws -> SemanticMapArtifacts.MapIndex {
        try JSONDecoder().decode(SemanticMapArtifacts.MapIndex.self,
                                 from: Data(contentsOf: RepositoryFiles.resources.appendingPathComponent("semantic-map-index.json")))
    }

    @Test func eachRouteRefusesWhatItCannotRead() async throws {
        let fixture = try await ServerFixture()
        let index = try Self.mapIndex()
        try await fixture.app.test(.router) { client in
            for (uri, expected, code) in [
                ("/api/v1/clusters?shown=500", 400, "UNKNOWN_PARAMETER"),
                ("/api/v1/clusters/twelve", 404, "CLUSTER_NOT_FOUND"),
                ("/api/v1/clusters/012", 404, "CLUSTER_NOT_FOUND"),
                ("/api/v1/clusters/-3", 404, "CLUSTER_NOT_FOUND"),
                ("/api/v1/clusters/140", 404, "CLUSTER_NOT_FOUND"),
                ("/api/v1/clusters/65535", 404, "CLUSTER_NOT_FOUND"),
                ("/api/v1/clusters/3?layout=00000000:2026-01-01:1", 409, "LAYOUT_CHANGED"),
                ("/api/v1/clusters/3?shown=0", 400, "INVALID_PARAMETER"),
                ("/api/v1/clusters/3?shown=five", 400, "INVALID_PARAMETER"),
                ("/api/v1/clusters/3?shown=500&shown=1000", 400, "INVALID_PARAMETER"),
                ("/api/v1/clusters/3?shown=500&after=500", 400, "INVALID_PARAMETER"),
                ("/api/v1/clusters/122?shown=500&after=300", 400, "INVALID_PARAMETER"),
                ("/api/v1/clusters/3?page=2", 400, "UNKNOWN_PARAMETER"),
            ] {
                let (answered, named) = try await SemanticMapReadingRouteTests.status(client, uri)
                #expect(answered == expected && named == code, "\(uri) answered \(answered) \(named)")
            }
            // Every region of the layout answers; its id alone, or with its own layout.
            let (answered, _) = try await SemanticMapReadingRouteTests.status(client, "/api/v1/clusters/3?layout=\(index.layoutIdentity)")
            #expect(answered == 200)
            // Save as Working Corpus is a route of a server that keeps user data alone.
            let save = try await client.execute(uri: "/api/v1/me/working-corpora/cluster", method: .post,
                                                headers: [.contentType: "application/json"], body: ByteBuffer(string: #"{"cluster":3}"#))
            #expect(save.status == .notFound)
        }
    }

    @Test func withNoIndexServedARegionListsItsDocumentsAndOpensNone() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let index = try decode(ClustersIndex.self, try await client.execute(uri: "/api/v1/clusters", method: .get))
            #expect(index.clusters.count == 140 && index.clusters.first?.id == 3)
            let page = try decode(ClusterDocuments.self, try await client.execute(uri: "/api/v1/clusters/115", method: .get))
            #expect(page.total == 10_914 && page.shown == 500 && page.after == 0 && page.coverage == nil)
            #expect(page.sections.reduce(0) { $0 + $1.documents.count } == 500)
            #expect(page.sections.allSatisfy { !$0.indexed && $0.documents.allSatisfy { $0.displayTitle == nil && $0.dateISO == nil } })
            #expect(page.sections.allSatisfy { $0.title != nil }, "every volume the map places is in the catalogue")
            // The next page gives the sections it changed: the volume the boundary split, whole, and the volumes after it.
            let next = try decode(ClusterDocuments.self, try await client.execute(uri: "/api/v1/clusters/115?shown=1000&after=500", method: .get))
            #expect(next.shown == 1_000 && next.after == 500)
            let boundary = try #require(page.sections.last)
            if next.sections.first?.volumeId == boundary.volumeId {
                #expect(next.sections.first!.documents.count > boundary.documents.count)
            }
            #expect(Set(next.sections.map(\.volumeId)).intersection(page.sections.dropLast().map(\.volumeId)).isEmpty)
            // Asked past its members, a page lists them all.
            let whole = try decode(ClusterDocuments.self, try await client.execute(uri: "/api/v1/clusters/122?shown=1000", method: .get))
            #expect(whole.shown == 254 && whole.total == 254)
        }
    }

    @Test func theMapsRefusalIsSaidInTheClustersWords() {
        let mismatch = ClustersRoutes.refusal(SemanticMapFiles.refusal(.provenanceMismatch(expected: "a", found: "b"), file: "semantic-map-index.json"))
        #expect(mismatch.status == .serviceUnavailable && mismatch.code == "CLUSTERS_UNAVAILABLE")
        #expect(mismatch.detail == "The cluster data and the semantic vectors come from different releases, so the list is not shown.")
        let missing = ClustersRoutes.refusal(SemanticMapFiles.refusal(.noArtifact, file: "semantic-map.bin"))
        #expect(missing.code == "CLUSTERS_UNAVAILABLE")
        #expect(missing.detail == "This server’s cluster data could not be read. This server does not carry the semantic map. semantic-map.bin is not among its data files.")
        let other = APIProblem(.notFound, code: "VOLUME_NOT_FOUND", detail: "No.")
        #expect(ClustersRoutes.refusal(other) == other, "a problem that is not the map's is its own")
    }

    @Test func savingARegionKeepsTheKitsCaptureForItsUser() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let map = try Self.mapIndex()
        let layout = map.layoutIdentity
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            func save(_ fields: [String: Any]) async throws -> TestResponse {
                try await owner.send(.post, "/api/v1/me/working-corpora/cluster",
                                     String(decoding: try JSONSerialization.data(withJSONObject: fields), as: UTF8.self))
            }
            let response = try await save(["cluster": 115, "layout": layout])
            #expect(response.status == .created, "\(String(buffer: response.body))")
            let corpus = try decode(WorkingCorpus.self, response)
            #expect(response.headers[.location] == "/api/v1/me/working-corpora/\(corpus.id)")
            // The kit's capture of "edc nato nuclear": the first 7,500 of its 10,914, named by the map's rule in UTC, no
            // time zone named, and described as a browse.
            let stamp = SemanticMapCapture.stamp(for: UserDataFixture.now, locale: Locale(identifier: "en_US"),
                                                 timeZone: try #require(TimeZone(identifier: "UTC")))
            #expect(corpus.name == SemanticMapCapture.corpusName(regionNames: ["edc nato nuclear"], stamp: stamp))
            #expect(corpus.documentCount == 7_500 && corpus.totalMatchCountAtCapture == 10_914 && corpus.wasTruncatedAtCapture == true)
            #expect(corpus.sourceDescription == "Semantic cluster, browsed" && corpus.sourceQuery == nil)
            #expect(corpus.indexedVolumeCountAtCapture == 2 && corpus.capturedAt == UserStoreDate.text(UserDataFixture.now))
            let listed = try decode(WorkingCorpusList.self, try await owner.get("/api/v1/me/working-corpora"))
            #expect(listed.items.map(\.id) == [corpus.id])
            // In the reader's time zone, when the browser names it.
            let york = try decode(WorkingCorpus.self, try await save(["cluster": 122, "layout": layout, "timeZone": "America/New_York"]))
            #expect(york.name == SemanticMapCapture.corpusName(
                regionNames: [try #require(map.clusters.first { $0.id == 122 }).terms.prefix(3).joined(separator: " ")],
                stamp: SemanticMapCapture.stamp(for: UserDataFixture.now, locale: Locale(identifier: "en_US"),
                                                timeZone: try #require(TimeZone(identifier: "America/New_York")))))
            #expect(york.documentCount == 254 && york.wasTruncatedAtCapture == false && york.totalMatchCountAtCapture == 254)

            for (fields, status, code) in [
                (["cluster": 115, "layout": "00000000:2026-01-01:1"] as [String: Any], 409, "LAYOUT_CHANGED"),
                (["cluster": 999], 404, "CLUSTER_NOT_FOUND"),
                (["cluster": 115, "timeZone": "Mars/Olympus"], 400, "INVALID_FIELD"),
                (["cluster": 115, "name": "Mine"], 400, "UNKNOWN_FIELD"),
                (["layout": layout], 400, "INVALID_FIELD"),
            ] {
                let refused = try await save(fields)
                #expect(Int(refused.status.code) == status && problemCode(refused) == code, "\(fields) answered \(refused.status.code) \(problemCode(refused) ?? "")")
            }
            let unsigned = try await owner.send(.post, "/api/v1/me/working-corpora/cluster", #"{"cluster":115}"#, token: "stale")
            #expect(unsigned.status == .forbidden && problemCode(unsigned) == "CSRF_TOKEN_INVALID")
            #expect(try decode(WorkingCorpusList.self, try await owner.get("/api/v1/me/working-corpora")).total == 2, "nothing refused was kept")
        }
        // A server that keeps no user data saves nothing.
        let off = try await UserDataFixture(userData: false)
        defer { withExtendedLifetime(off) {} }
        try await off.app.test(.router) { client in
            let refused = try await Browser(client: client).send(.post, "/api/v1/me/working-corpora/cluster", #"{"cluster":115}"#)
            #expect(refused.status == .forbidden && problemCode(refused) == "USER_DATA_OFF")
        }
    }
}
