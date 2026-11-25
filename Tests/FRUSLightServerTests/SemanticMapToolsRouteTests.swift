// The semantic map's tools' routes (PLAN's S28e), over the bundled files: what each refuses, in the API's words; with no
// index served, a lasso that holds no coverage, a point with no nearest and a slice's points revalidated by their bytes;
// and the two saves, each the user's, refused for a capture of nothing, another layout, a stale token and a server that
// keeps no user data. Every answer's agreement with the kit over the fixture index is `SemanticMapToolsParityTests`'.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import SemanticVectorsKit
import Testing

@testable import FRUSLightAPI

@Suite struct SemanticMapToolsRouteTests {
    static func lasso(_ client: any TestClientProtocol, _ query: String, _ body: String) async throws -> TestResponse {
        try await client.execute(uri: "/api/v1/semantic/map/lasso\(query.isEmpty ? "" : "?\(query)")", method: .post,
                                 headers: [.contentType: "application/json"], body: ByteBuffer(string: body))
    }

    static let band = #"{"polygon":[[-30000,-6000],[30000,-6000],[30000,6000],[-30000,6000]]}"#

    @Test func eachRouteRefusesWhatItCannotRead() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for (uri, expected, code) in [
                ("/api/v1/semantic/map/slice", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/slice?from=frus1961-63v06", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/slice?from=frus1961-63v06&to=frus%201", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/slice?from=frus1961-63v06&to=frus1969-76ve09p1&zoom=2", 400, "UNKNOWN_PARAMETER"),
                ("/api/v1/semantic/map/slice/points?from=frus1961-63v06&to=frus1961-63v06", 404, "NO_SLICE"),
                ("/api/v1/semantic/map/slice/pick?x=0&y=0&tolerance=10", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/slice/pick?from=frus1961-63v06&x=0&y=0&tolerance=10", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/slice/pick?from=frus1961-63v06&to=frus1961-63v06&x=0&y=0&tolerance=10", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/slice/pick?from=frus1961-63v06&to=frus1969-76ve09p1&x=0&y=0", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/nearest", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/nearest?document=frus1961-63v06", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/nearest?document=frus1961-63v06/ch1", 404, "NOT_ON_MAP"),
                ("/api/v1/semantic/map/nearest?document=frus1961-63v06/d1&scope=all", 400, "UNKNOWN_PARAMETER"),
                ("/api/v1/semantic/map/export?lens=administration", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/export?timeZone=Mars/Olympus", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/export?volume=frus1800", 404, "VOLUME_NOT_FOUND"),
                ("/api/v1/semantic/map/plate?x=0&y=0", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/plate?x=0&y=0&halfExtent=30000&from=frus1961-63v06&to=frus1961-63v06", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/plate?x=0&y=0&halfExtent=30000&width=900", 400, "UNKNOWN_PARAMETER"),
            ] {
                let (answered, named) = try await SemanticMapReadingRouteTests.status(client, uri)
                #expect(answered == expected && named == code, "\(uri) answered \(answered) \(named)")
            }
            let many = (0...SemanticMapToolsRoutes.polygonLimit).map { "[\($0),0]" }.joined(separator: ",")
            for (query, body, expected, code) in [
                ("", "polygon", 400, "INVALID_BODY"),
                ("", #"{"polygon":[[0,0],[1,0],[1,1]],"name":"Mine"}"#, 400, "UNKNOWN_FIELD"),
                ("", #"{"polygon":[[0,0],[1,0,2],[1,1]]}"#, 400, "INVALID_PARAMETER"),
                ("", #"{"polygon":[[0,0],[1e9,0],[1,1]]}"#, 400, "INVALID_PARAMETER"),
                ("", #"{"polygon":[\#(many)]}"#, 400, "INVALID_PARAMETER"),
                ("from=frus1961-63v06", Self.band, 400, "INVALID_PARAMETER"),
                ("from=frus1961-63v06&to=frus1961-63v06", Self.band, 400, "INVALID_PARAMETER"),
                ("volume=frus1961-63v06&subseries=1961-63", Self.band, 400, "INVALID_PARAMETER"),
                ("zoom=2", Self.band, 400, "UNKNOWN_PARAMETER"),
            ] {
                let response = try await Self.lasso(client, query, body)
                #expect(Int(response.status.code) == expected && problemCode(response) == code,
                        "a lasso of \(body.prefix(40)) at '\(query)' answered \(response.status.code) \(problemCode(response) ?? "")")
            }
        }
    }

    @Test func withNoIndexServedTheToolsHoldNothingOfThisServer() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            // A lasso draws on the whole series, with no coverage while no index is served.
            let caught = try decode(SemanticMapLassoAnswer.self, try await Self.lasso(client, "", Self.band))
            let capture = try #require(caught.capture)
            #expect(capture.total > 7_500 && capture.kept == 7_500 && capture.regionNames.count == 3 && capture.coverage == nil && !caught.scoped)
            // Two points, and an unscoped lasso over bare ground, make no card; a scoped one says it holds nothing.
            let two = try decode(SemanticMapLassoAnswer.self, try await Self.lasso(client, "", #"{"polygon":[[0,0],[10,10]]}"#))
            #expect(two.capture == nil)
            let bare = #"{"polygon":[[32000,32000],[32700,32000],[32700,32700]]}"#
            #expect(try decode(SemanticMapLassoAnswer.self, try await Self.lasso(client, "", bare)).capture == nil)
            let scoped = try decode(SemanticMapLassoAnswer.self, try await Self.lasso(client, "volume=frus1961-63v06", bare))
            #expect(scoped.scoped && scoped.capture == .init(total: 0, kept: 0, regionNames: [], coverage: nil))
            // A point has no nearest while no index is served.
            let nearest = try decode(SemanticMapNearestAnswer.self, try await client.execute(
                uri: "/api/v1/semantic/map/nearest?document=frus1961-63v06/d1", method: .get))
            #expect(nearest.neighbours.isEmpty && nearest.empty == "noIndex")
            // A slice's points, six bytes a point, revalidated by their bytes.
            let uri = "/api/v1/semantic/map/slice/points?from=frus1961-63v06&to=frus1969-76ve09p1"
            let points = try await client.execute(uri: uri, method: .get)
            #expect(points.status == .ok && points.body.readableBytes == 314_616 * 6)
            #expect(points.headers[.contentType] == "application/octet-stream" && points.headers[.cacheControl] == "private, no-cache")
            let tag = try #require(points.headers[.eTag])
            let again = try await client.execute(uri: uri, method: .get, headers: [.ifNoneMatch: tag])
            #expect(again.status == .notModified)
            let slice = try decode(SemanticMapSliceAnswer.self, try await client.execute(
                uri: "/api/v1/semantic/map/slice?from=frus1961-63v06&to=frus1969-76ve09p1", method: .get))
            #expect(slice.refusal == nil && slice.gridExtent == 30_000 && slice.scale?.undatedCount == 0 && slice.gutterY == nil)
            #expect(slice.caveat?.hasPrefix("Left to right is how far each document leans from frus1961-63v06 toward frus1969-76ve09p1.") == true)
            // The figure of the whole map names its regions and states the frame; a slice's names none.
            let plate = try decode(SemanticMapFigure.self, try await client.execute(
                uri: "/api/v1/semantic/map/plate?x=0&y=0&halfExtent=32767", method: .get))
            #expect(plate.width == 1_144 && plate.height == 900 && !plate.labels.isEmpty && plate.labels.count <= 22)
            #expect(plate.plate.lines.contains { $0.text.hasPrefix("Frame: rendered at 1144 × 900 points") })
            let slicePlate = try decode(SemanticMapFigure.self, try await client.execute(
                uri: "/api/v1/semantic/map/plate?x=0&y=0&halfExtent=30000&from=frus1961-63v06&to=frus1969-76ve09p1", method: .get))
            #expect(slicePlate.labels.isEmpty && slicePlate.plate.lines.contains { $0.text.hasPrefix("This figure shows a SLICE (frus1961-63v06 → frus1969-76ve09p1)") })
        }
    }

    @Test func aSliceIsRefusedBeforeItIsLaidOutWhenNoVolumeHasAYear() throws {
        // FRUS-Explorer#1986: the layout's year span overflows with no dated volume, so the server never calls it so.
        let directory = RepositoryFiles.resources
        func at(_ name: String) -> URL { directory.appendingPathComponent(name) }
        let tiers = try SemanticBundledTiers(indexAt: at("semantic-vectors-index.json"), binaryAt: at("semantic-vectors-binary.bin"))
        let map = try SemanticBundledMap(indexAt: at("semantic-map-index.json"), binaryAt: at("semantic-map.bin"), vectorIndex: tiers.index)
        let plane = SemanticMapReading.Plane(map: try Self.files(map), index: tiers.index, positions: [], mapped: [])
        guard case .failure(let refused) = SemanticMapTools.laidOut(from: "frus1961-63v06", to: "frus1969-76ve09p1", plane: plane,
                                                                    corpus: tiers.corpus, yearForVolume: { _ in nil }) else {
            Issue.record("a slice was laid out with no volume dated")
            return
        }
        #expect(refused.code == "SLICE_UNAVAILABLE" && refused.detail == SemanticMapTools.undatedWords)
        // A pair refused is refused before the years are asked.
        guard case .success(.refused(.sameVolume)) = SemanticMapTools.laidOut(
            from: "frus1961-63v06", to: "frus1961-63v06", plane: plane, corpus: tiers.corpus, yearForVolume: { _ in nil }) else {
            Issue.record("one volume as both poles was not refused as the app refuses it")
            return
        }
    }

    @Test func twoFirstAsksOfASliceWaitForOneLayout() async throws {
        let fixture = try await ServerFixture()
        let vectors = SemanticVectors(resources: fixture.resources.directory, shards: fixture.state.configuration.semanticShards)
        let provider = ServedIndexProvider(state: fixture.state, resources: fixture.resources,
                                           volumesDirectory: fixture.reader.volumesDirectory, userStore: nil)
        let reading = SemanticMapReading(files: SemanticMapFiles(vectors: vectors), provider: provider, resources: fixture.resources)
        let tools = SemanticMapTools(reading: reading, vectors: vectors, provider: provider, resources: fixture.resources)
        async let first = tools.slice(from: "frus1961-63v06", to: "frus1969-76ve09p1")
        async let second = tools.slice(from: "frus1961-63v06", to: "frus1969-76ve09p1")
        async let other = tools.slice(from: "frus1969-76ve09p1", to: "frus1961-63v06")
        let (one, two, three) = try await (first, second, other)
        #expect(one == two && one.refusal == nil && three.refusal == nil && three.from == "frus1969-76ve09p1")
        #expect(await tools.layoutsBegun == 2, "the pair asked twice at once was laid out once")
        // Kept: asked again, it is not laid out again.
        _ = try await tools.slice(from: "frus1961-63v06", to: "frus1969-76ve09p1")
        #expect(await tools.layoutsBegun == 2)
    }

    /// The map's files as the server keeps them, from the kit's read of them.
    static func files(_ map: SemanticBundledMap) throws -> SemanticMapFiles.Map {
        let empty = ByteBuffer()
        return SemanticMapFiles.Map(vectors: map.vectors, index: map.index, points: empty,
                                    regions: SemanticMapRegions(layoutIdentity: map.index.layoutIdentity, generated: map.index.generated,
                                                                documentCount: map.index.documentCount, unclusteredCount: 0,
                                                                gridExtent: map.index.gridExtent, method: "", clustering: "", regions: []),
                                    regionsJSON: empty, pointsTag: "", regionsTag: "")
    }

    @Test func savingALassoAndARegionKeepsTheirCapturesForTheirUser() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let utc = try #require(TimeZone(identifier: "UTC"))
        let stamp = SemanticMapCapture.stamp(for: UserDataFixture.now, locale: Locale(identifier: "en_US"), timeZone: utc)
        let layout = try ClustersRouteTests.mapIndex().layoutIdentity
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            func save(_ path: String, _ fields: [String: Any]) async throws -> TestResponse {
                try await owner.send(.post, path, String(decoding: try JSONSerialization.data(withJSONObject: fields), as: UTF8.self))
            }
            let band: [[Double]] = [[-30_000, -6_000], [30_000, -6_000], [30_000, 6_000], [-30_000, 6_000]]
            let lasso = try await save("/api/v1/me/working-corpora/lasso", ["polygon": band])
            #expect(lasso.status == .created, "\(String(buffer: lasso.body))")
            let caught = try decode(WorkingCorpus.self, lasso)
            #expect(lasso.headers[.location] == "/api/v1/me/working-corpora/\(caught.id)")
            #expect(caught.documentCount == 7_500 && caught.wasTruncatedAtCapture == true && (caught.totalMatchCountAtCapture ?? 0) > 7_500)
            #expect(caught.name.hasSuffix(" — \(stamp)") && caught.sourceDescription == "Semantic map selection" && caught.sourceQuery == nil)
            #expect(caught.indexedVolumeCountAtCapture == 2 && caught.capturedAt == UserStoreDate.text(UserDataFixture.now))
            // A region under a scope, in the reader's time zone: "edc nato nuclear", frus1961-63v06's 79.
            let region = try decode(WorkingCorpus.self, try await save(
                "/api/v1/me/working-corpora/region?volume=frus1961-63v06", ["region": 115, "layout": layout, "timeZone": "America/New_York"]))
            let york = SemanticMapCapture.stamp(for: UserDataFixture.now, locale: Locale(identifier: "en_US"),
                                                timeZone: try #require(TimeZone(identifier: "America/New_York")))
            #expect(region.name == SemanticMapCapture.corpusName(regionNames: ["edc nato nuclear"], stamp: york))
            #expect(region.documentCount == 79 && region.wasTruncatedAtCapture == false && region.totalMatchCountAtCapture == 79)
            #expect(region.sourceDescription?.hasPrefix("Semantic map selection, scoped to ") == true)
            #expect(try decode(WorkingCorpusList.self, try await owner.get("/api/v1/me/working-corpora")).total == 2)

            let bare: [[Double]] = [[32_000, 32_000], [32_700, 32_000], [32_700, 32_700]]
            for (path, fields, status, code) in [
                ("/api/v1/me/working-corpora/lasso", ["polygon": bare] as [String: Any], 400, "NOTHING_TO_CAPTURE"),
                ("/api/v1/me/working-corpora/lasso?volume=frus1961-63v06", ["polygon": bare], 400, "NOTHING_TO_CAPTURE"),
                ("/api/v1/me/working-corpora/lasso", ["polygon": [[0, 0], [10, 10]]], 400, "NOTHING_TO_CAPTURE"),
                ("/api/v1/me/working-corpora/lasso", ["polygon": band, "timeZone": "Mars/Olympus"], 400, "INVALID_FIELD"),
                ("/api/v1/me/working-corpora/lasso?from=frus1961-63v06&to=frus1961-63v06", ["polygon": band], 400, "INVALID_PARAMETER"),
                ("/api/v1/me/working-corpora/region", ["region": 115, "layout": "00000000:2026-01-01:1"], 409, "LAYOUT_CHANGED"),
                ("/api/v1/me/working-corpora/region", ["region": 999], 404, "REGION_NOT_FOUND"),
                ("/api/v1/me/working-corpora/region", ["region": 115, "name": "Mine"], 400, "UNKNOWN_FIELD"),
                ("/api/v1/me/working-corpora/region?zoom=2", ["region": 115], 400, "UNKNOWN_PARAMETER"),
            ] {
                let refused = try await save(path, fields)
                #expect(Int(refused.status.code) == status && problemCode(refused) == code, "\(path) \(fields) answered \(refused.status.code) \(problemCode(refused) ?? "")")
            }
            let unsigned = try await owner.send(.post, "/api/v1/me/working-corpora/region", #"{"region":115}"#, token: "stale")
            #expect(unsigned.status == .forbidden && problemCode(unsigned) == "CSRF_TOKEN_INVALID")
            #expect(try decode(WorkingCorpusList.self, try await owner.get("/api/v1/me/working-corpora")).total == 2, "nothing refused was kept")
        }
        // A server that keeps no user data saves nothing.
        let off = try await UserDataFixture(userData: false)
        defer { withExtendedLifetime(off) {} }
        try await off.app.test(.router) { client in
            for path in ["/api/v1/me/working-corpora/lasso", "/api/v1/me/working-corpora/region"] {
                let refused = try await Browser(client: client).send(.post, path, #"{"region":115}"#)
                #expect(refused.status == .forbidden && problemCode(refused) == "USER_DATA_OFF", "\(path)")
            }
        }
    }
}
