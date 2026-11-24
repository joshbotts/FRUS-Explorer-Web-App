// The semantic map's routes (PLAN's S28b), over the bundled files: every point's place and region through the API is
// the kit's, as `SemanticMapVectors` reads it from `semantic-map.bin`, row for row; the regions are the bundled index's,
// and they count the points; the answers are revalidated by the layout's identity; and the map is refused, both answers
// alike, in the app's words, when its index or its binary names other vectors or another count than the bundled
// vectors' index, as the app's `BundledSemanticMap` refuses it.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import SemanticVectorsKit
import Testing

@testable import FRUSLightAPI

@Suite struct SemanticMapRouteTests {
    static let resources = RepositoryFiles.resources

    /// The bundled vectors' index and the map as the kit reads them, apart from the server.
    static func kit() throws -> (vectors: SemanticVectorsArtifacts.Index, map: SemanticMapVectors, index: SemanticMapArtifacts.MapIndex) {
        let vectors = try JSONDecoder().decode(SemanticVectorsArtifacts.Index.self,
                                               from: Data(contentsOf: resources.appendingPathComponent("semantic-vectors-index.json")))
        let map = try SemanticMapVectors(contentsOf: resources.appendingPathComponent("semantic-map.bin"),
                                         provenance: vectors.provenance, expectedDocumentCount: vectors.documentCount)
        let index = try JSONDecoder().decode(SemanticMapArtifacts.MapIndex.self,
                                             from: Data(contentsOf: resources.appendingPathComponent("semantic-map-index.json")))
        return (vectors, map, index)
    }

    /// A router with the map's routes alone, over the files in `directory`.
    static func app(_ directory: URL) -> some ApplicationProtocol {
        let router = Router(context: APIRequestContext.self)
        router.add(middleware: ProblemMiddleware(logger: Logger(label: "semantic-map-tests")))
        SemanticMapRoutes.add(to: router, map: SemanticMapFiles(directory: directory))
        return Application(router: router)
    }

    @Test func everyPointsPlaceAndRegionAreTheKits() async throws {
        let (vectors, map, index) = try Self.kit()
        #expect(map.documentCount == 314_616 && vectors.documentCount == 314_616 && index.clusters.count == 140)
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/semantic/map", method: .get)
            #expect(response.status == .ok && response.headers[.contentType] == "application/octet-stream")
            let bytes = Array(response.body.readableBytesView)
            #expect(bytes.count == map.documentCount * 6)
            guard bytes.count == map.documentCount * 6 else { return }
            var differing: [Int] = []
            var perRegion: [UInt16: Int] = [:]
            for row in 0..<map.documentCount {
                let at = row * 6
                let x = Int16(bitPattern: UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8)
                let y = Int16(bitPattern: UInt16(bytes[at + 2]) | UInt16(bytes[at + 3]) << 8)
                let region = UInt16(bytes[at + 4]) | UInt16(bytes[at + 5]) << 8
                if map.placement(at: row) != SemanticMapArtifacts.Placement(x: x, y: y, cluster: region) { differing.append(row) }
                perRegion[region, default: 0] += 1
            }
            #expect(differing.isEmpty, "rows whose place or region is not the kit's: \(differing.prefix(10))")

            // The regions are the index's, by id, and they count the points: each region's documents, and those between.
            let regions = try decode(SemanticMapRegions.self, try await client.execute(uri: "/api/v1/semantic/map/regions", method: .get))
            #expect(regions.layoutIdentity == index.layoutIdentity && regions.generated == "2026-10-15")
            #expect(regions.documentCount == 314_616 && regions.unclusteredCount == 88_059 && regions.gridExtent == 30_000)
            #expect(regions.method == "PCA-50 -> UMAP-2 (cosine)" && regions.clustering.hasPrefix("HDBSCAN"))
            #expect(regions.regions.map(\.id) == Array(0..<140))
            for (region, cluster) in zip(regions.regions, index.clusters) {
                #expect(region == SemanticMapRegions.Region(id: cluster.id, terms: cluster.terms, documentCount: cluster.documentCount,
                                                           centreX: cluster.centreX, centreY: cluster.centreY, eraCounts: cluster.eraCounts))
                #expect(region.terms.count == 4 && perRegion[UInt16(region.id)] == region.documentCount, "region \(region.id)")
            }
            #expect(perRegion[SemanticMapArtifacts.unclustered] == regions.unclusteredCount)
            #expect(perRegion.keys.allSatisfy { $0 == SemanticMapArtifacts.unclustered || Int($0) < 140 })
            #expect(regions.regions.reduce(0) { $0 + $1.documentCount } + regions.unclusteredCount == regions.documentCount)
        }
    }

    /// Each answer carries a tag of its own bytes, the same from one start to the next, and a browser that holds it is told
    /// so; the regions' bytes are encoded once, their keys sorted; HEAD answers as GET does; and neither takes a parameter.
    @Test func theAnswersAreRevalidatedByTheirBytes() async throws {
        let (_, map, _) = try Self.kit()
        let tags = try await Self.app(Self.resources).test(.router) { client -> [String: String] in
            var tags: [String: String] = [:]
            for path in ["/api/v1/semantic/map", "/api/v1/semantic/map/regions"] {
                let first = try await client.execute(uri: path, method: .get)
                let tag = try #require(first.headers[.eTag], "\(path)")
                #expect(first.status == .ok && tag.count > 2 && tag.hasPrefix("\"") && tag.hasSuffix("\""), "\(path)")
                #expect(first.headers[.cacheControl] == "private, no-cache", "\(path)")
                tags[path] = tag
                let again = try await client.execute(uri: path, method: .get, headers: [.ifNoneMatch: "\"other\", \(tag)"])
                #expect(again.status == .notModified && again.body.readableBytes == 0 && again.headers[.eTag] == tag, "\(path)")
                let other = try await client.execute(uri: path, method: .get, headers: [.ifNoneMatch: "\"2026-01-01\""])
                #expect(other.status == .ok, "\(path)")
                #expect(problemCode(try await client.execute(uri: "\(path)?lens=era", method: .get)) == "UNKNOWN_PARAMETER", "\(path)")
            }
            let regions = try await client.execute(uri: "/api/v1/semantic/map/regions", method: .get)
            #expect(regions.headers[.contentType] == "application/json; charset=utf-8")
            #expect(String(buffer: regions.body).contains(
                #"{"centreX":-2259,"centreY":-10310,"documentCount":698,"eraCounts":{"1":134,"2":564},"id":0,"terms":["spanish","salazar","spain","lagen"]}"#))
            return tags
        }
        #expect(tags.count == 2 && tags["/api/v1/semantic/map"] != tags["/api/v1/semantic/map/regions"])
        // Read again, as at the server's next start: the same bytes, so the same tags.
        try await Self.app(Self.resources).test(.router) { client in
            for (path, tag) in tags {
                let again = try await client.execute(uri: path, method: .get)
                #expect(again.headers[.eTag] == tag, "\(path)")
            }
        }
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let head = try await client.execute(uri: "/api/v1/semantic/map", method: .head)
            #expect(head.status == .ok && head.headers[.contentLength] == String(map.documentCount * 6))
        }
    }

    /// A folder holding the three bundled files, as written, or with one of them changed.
    static func folder(vectors: (inout [String: Any]) -> Void = { _ in }, index: (inout [String: Any]) -> Void = { _ in },
                       binary: (inout Data) -> Void = { _ in }, leaving: String? = nil) throws -> TemporaryDirectory {
        let folder = try TemporaryDirectory()
        func json(_ name: String, _ change: (inout [String: Any]) -> Void) throws {
            var object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: resources.appendingPathComponent(name))) as? [String: Any])
            change(&object)
            try JSONSerialization.data(withJSONObject: object).write(to: folder.url.appendingPathComponent(name))
        }
        try json("semantic-vectors-index.json", vectors)
        try json("semantic-map-index.json", index)
        var data = try Data(contentsOf: resources.appendingPathComponent("semantic-map.bin"))
        binary(&data)
        try data.write(to: folder.url.appendingPathComponent("semantic-map.bin"))
        if let leaving { try FileManager.default.removeItem(at: folder.url.appendingPathComponent(leaving)) }
        return folder
    }

    @Test func theMapIsRefusedWholeWhenItsFilesDisagree() async throws {
        let whole = try Self.folder()
        try await Self.app(whole.url).test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/semantic/map", method: .get)
            #expect(response.status == .ok, "the files rewritten as they are")
        }
        let otherVectors = String(repeating: "0", count: 64)
        let cases: [(String, TemporaryDirectory, String)] = [
            ("the index names other vectors", try Self.folder(index: { $0["provenanceDigest"] = otherVectors }),
             "The map and the vectors come from different releases, so the map is not being drawn. semantic-map-index.json was made from the vectors 00000000, this server's are 89481b18."),
            ("the binary names other vectors", try Self.folder(binary: { $0[20] ^= 0xFF }),
             "The map and the vectors come from different releases, so the map is not being drawn. semantic-map.bin was made from the vectors 76481b18, this server's are 89481b18."),
            ("the vectors count other documents", try Self.folder(vectors: { $0["documentCount"] = 314_615 }),
             "The semantic map could not be read. semantic-map.bin: map places 314616 documents, the vectors have 314615."),
            ("the binary is cut short", try Self.folder(binary: { $0.removeLast(6) }),
             "The semantic map could not be read. semantic-map.bin: expected 1887760 bytes for 314616 placements, found 1887754."),
            ("the index's grid is another", try Self.folder(index: { $0["gridExtent"] = 25_000 }),
             "The semantic map could not be read. semantic-map-index.json describes 314616 documents in 140 regions on a grid of 25000, semantic-map.bin 314616 in 140 on 30000."),
            ("the index is not one", try Self.folder(index: { $0["clusters"] = "none" }),
             "The semantic map could not be read. semantic-map-index.json could not be decoded"),
            ("the binary is missing", try Self.folder(leaving: "semantic-map.bin"),
             "This server does not carry the semantic map. semantic-map.bin is not among its data files."),
            ("the vectors' index is missing", try Self.folder(leaving: "semantic-vectors-index.json"),
             "This server does not carry the semantic map. semantic-vectors-index.json is not among its data files."),
        ]
        for (what, folder, detail) in cases {
            try await Self.app(folder.url).test(.router) { client in
                for path in ["/api/v1/semantic/map", "/api/v1/semantic/map/regions"] {
                    let body = try problem(try await client.execute(uri: path, method: .get), .serviceUnavailable)
                    #expect(body.code == "SEMANTIC_MAP_UNAVAILABLE" && body.detail.hasPrefix(detail), "\(what), \(path): \(body.detail)")
                }
            }
        }
    }
}
