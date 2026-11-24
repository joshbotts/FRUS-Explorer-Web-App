// The semantic map (PLAN's S28b): the bundled map's points and regions, which Semantic Analytics draws.
//   GET /api/v1/semantic/map           the 314,616 points as one binary answer, application/octet-stream: six bytes a point
//                                      in the bundled vectors' row order, little-endian, int16 x and int16 y on the map's
//                                      grid and uint16 region, 0xFFFF for a point between regions, as SemanticVectorsKit's
//                                      `SemanticMapVectors` reads them from `semantic-map.bin`
//   GET /api/v1/semantic/map/regions   the map's 140 regions, each with its four terms, its count, its centre and its eras'
//                                      counts, from `semantic-map-index.json`, with the layout's facts
// The map is read once, on first use, as the app's `BundledSemanticMap` reads it, and refused whole, both answers alike,
// as the app refuses it: a map whose index or binary names other vectors than the bundled index's provenance, or places
// another number of documents, is not drawn, since a map from one generation drawn against another puts every document
// where other vectors put it. Each answer carries the kit's layout identity as its ETag, which moves with the layout.

import FRUSLightCore
import Foundation
import Hummingbird
import NIOCore
import SemanticVectorsKit

/// `GET /api/v1/semantic/map/regions`: the bundled map's index, its regions by id as the index lists them.
public struct SemanticMapRegions: Codable, Equatable, Sendable, ResponseEncodable {
    public struct Region: Codable, Equatable, Sendable {
        /// The id a point's region names.
        public var id: Int
        /// The label's terms, most distinctive first: four, from c-TF-IDF over a sample of the region's documents.
        public var terms: [String]
        public var documentCount: Int
        /// The region's centre on the map's grid.
        public var centreX: Int
        public var centreY: Int
        /// Documents per coverage era, by the era's number, as the map's index keeps them.
        public var eraCounts: [String: Int]
    }

    /// The kit's `MapIndex.layoutIdentity`, the digest, the day it was made and the count, against which alone a
    /// region's id means anything.
    public var layoutIdentity: String
    /// The day the layout was made.
    public var generated: String
    public var documentCount: Int
    /// The documents the clustering left between regions.
    public var unclusteredCount: Int
    /// Half the grid's width: every coordinate lies within it of zero.
    public var gridExtent: Int
    /// How the layout was made and clustered, in the generator's own words.
    public var method: String
    public var clustering: String
    public var regions: [Region]
}

/// The bundled map, read once on first use; or why it is refused.
actor SemanticMapFiles {
    /// The three files the map is read from, in the server's data files: the vectors' index names the provenance
    /// and the count the map is held to, as the app's map waits on `BundledSemanticVectors`.
    static let vectorsIndexFile = "semantic-vectors-index.json"
    static let indexFile = "semantic-map-index.json"
    static let binaryFile = "semantic-map.bin"

    struct Map: Sendable {
        /// The kit's reader, which S28c's lenses and picks read.
        let vectors: SemanticMapVectors
        /// The placements as the answer sends them: the kit's block, six bytes a point.
        let points: ByteBuffer
        let regions: SemanticMapRegions
        /// The layout identity, quoted as an entity tag.
        let entityTag: String
    }

    let directory: URL
    private var loading: Task<Result<Map, APIProblem>, Never>?

    init(directory: URL) {
        self.directory = directory
    }

    /// The map, read on the first call and kept, refusal and all.
    func map() async -> Result<Map, APIProblem> {
        if let loading { return await loading.value }
        let directory = directory
        let task = Task<Result<Map, APIProblem>, Never> {
            do {
                return try await Blocking.run { Self.read(from: directory) }
            } catch {
                return .failure(Self.malformed("\(error)"))
            }
        }
        loading = task
        return await task.value
    }

    /// Reads the map from `directory`, held as the app's `BundledSemanticMap.prepare()` holds it.
    static func read(from directory: URL) -> Result<Map, APIProblem> {
        for name in [vectorsIndexFile, indexFile, binaryFile]
        where !FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
            return .failure(refusal(.noArtifact, file: name))
        }
        let vectors: SemanticVectorsArtifacts.Index
        let index: SemanticMapArtifacts.MapIndex
        do {
            vectors = try JSONDecoder().decode(SemanticVectorsArtifacts.Index.self,
                                               from: Data(contentsOf: directory.appendingPathComponent(vectorsIndexFile)))
        } catch {
            return .failure(malformed("\(vectorsIndexFile) could not be decoded: \(error)"))
        }
        do {
            index = try JSONDecoder().decode(SemanticMapArtifacts.MapIndex.self,
                                             from: Data(contentsOf: directory.appendingPathComponent(indexFile)))
        } catch {
            return .failure(malformed("\(indexFile) could not be decoded: \(error)"))
        }
        let provenance = vectors.provenance
        guard index.provenanceDigest == provenance.digestHex else {
            return .failure(refusal(.provenanceMismatch(expected: provenance.digestHex, found: index.provenanceDigest), file: indexFile))
        }
        let map: SemanticMapVectors
        do {
            map = try SemanticMapVectors(contentsOf: directory.appendingPathComponent(binaryFile), provenance: provenance,
                                         expectedDocumentCount: vectors.documentCount)
        } catch let refused as SemanticUnavailable {
            return .failure(refusal(refused, file: binaryFile))
        } catch {
            return .failure(malformed("\(binaryFile): \(error)"))
        }
        // The two halves of one generator's run: the index's facts are the binary's.
        guard index.documentCount == map.documentCount, index.gridExtent == map.gridExtent,
              index.clusters.count == map.clusterCount else {
            return .failure(malformed("\(indexFile) describes \(index.documentCount) documents in \(index.clusters.count) "
                + "regions on a grid of \(index.gridExtent), \(binaryFile) \(map.documentCount) in \(map.clusterCount) on \(map.gridExtent)"))
        }
        let size = map.documentCount * SemanticMapArtifacts.bytesPerDocument
        var points = ByteBufferAllocator().buffer(capacity: size)
        map.withPlacements { base, count in
            _ = points.writeBytes(UnsafeRawBufferPointer(start: base, count: count * SemanticMapArtifacts.bytesPerDocument))
        }
        let regions = SemanticMapRegions(
            layoutIdentity: index.layoutIdentity, generated: index.generated, documentCount: index.documentCount,
            unclusteredCount: index.layout.unclusteredCount, gridExtent: index.gridExtent, method: index.layout.method,
            clustering: index.layout.clustering,
            regions: index.clusters.map {
                SemanticMapRegions.Region(id: $0.id, terms: $0.terms, documentCount: $0.documentCount, centreX: $0.centreX,
                                          centreY: $0.centreY, eraCounts: $0.eraCounts)
            })
        return .success(Map(vectors: map, points: points, regions: regions, entityTag: "\"\(index.layoutIdentity)\""))
    }

    /// A refusal in the app's words (`SemanticMapSpikeView.describe`), in a server's where the app's name a build,
    /// with the file and the reason after them.
    static func refusal(_ reason: SemanticUnavailable, file: String) -> APIProblem {
        switch reason {
        case .noArtifact:
            return APIProblem(.serviceUnavailable, code: "SEMANTIC_MAP_UNAVAILABLE",
                              detail: "\(noArtifactWords) \(file) is not among its data files.")
        case let .provenanceMismatch(expected, found):
            return APIProblem(.serviceUnavailable, code: "SEMANTIC_MAP_UNAVAILABLE",
                              detail: "\(mismatchWords) \(file) was made from the vectors \(found.prefix(8)), this server's are \(expected.prefix(8)).")
        case let .malformedArtifact(why):
            return malformed("\(file): \(why)")
        default:
            return malformed("\(file): \(reason)")
        }
    }

    static func malformed(_ why: String) -> APIProblem {
        APIProblem(.serviceUnavailable, code: "SEMANTIC_MAP_UNAVAILABLE", detail: "\(malformedWords) \(why).")
    }

    /// The app's `semanticMap.noArtifact`, a server's: "This build does not carry the semantic map."
    static let noArtifactWords = "This server does not carry the semantic map."
    /// The app's `semanticMap.mismatch`.
    static let mismatchWords = "The map and the vectors come from different releases, so the map is not being drawn."
    /// The app's `semanticMap.malformed`.
    static let malformedWords = "The semantic map could not be read."
}

enum SemanticMapRoutes {
    static func add(to router: Router<APIRequestContext>, map files: SemanticMapFiles) {
        router.get("/api/v1/semantic/map") { request, _ -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let map = try await files.map().get()
            var headers = Self.headers(map)
            if Self.isCurrent(request, map) { return Response(status: .notModified, headers: headers) }
            headers[.contentType] = "application/octet-stream"
            return Response(status: .ok, headers: headers, body: .init(byteBuffer: map.points))
        }
        router.get("/api/v1/semantic/map/regions") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let map = try await files.map().get()
            let headers = Self.headers(map)
            if Self.isCurrent(request, map) { return Response(status: .notModified, headers: headers) }
            return try EditedResponse(headers: headers, response: map.regions).response(from: request, context: context)
        }
    }

    /// Revalidated on each request, and the same for every reader, so a browser keeps it and asks again with its tag.
    static func headers(_ map: SemanticMapFiles.Map) -> HTTPFields {
        [.cacheControl: "private, no-cache", .eTag: map.entityTag]
    }

    /// Whether the request already holds this layout's answer.
    static func isCurrent(_ request: Request, _ map: SemanticMapFiles.Map) -> Bool {
        guard let tags = request.headers[.ifNoneMatch] else { return false }
        return tags.split(separator: ",").contains { $0.trimmingCharacters(in: .whitespaces) == map.entityTag }
    }
}
