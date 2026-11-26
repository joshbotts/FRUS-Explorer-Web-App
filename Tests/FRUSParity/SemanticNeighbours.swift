// Check 9's kernel half on Linux (PLAN's S26c): each vectored fixture document's ten nearest by SemanticVectorsKit's
// two stages, over the bundled tier the server reads and the fixture volumes' shards through the server's own store,
// `SemanticVectors`, which opens each through the kit's `SemanticShard` and holds it to the bundled manifest. The loop
// is ParityFormat's, which `tools/mac-golden neighbours` runs over the app's own code and shard store on the Mac.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import ParityFormat
import SemanticVectorsKit

public enum SemanticNeighbours {
    /// Why the lists could not be made.
    public struct Refusal: Error, CustomStringConvertible {
        public let description: String
    }

    /// The lists, and the generation and pool they were made at.
    public struct Lists: Sendable {
        public var generation: String
        public var rerankPool: Int
        public var anchors: [SemanticNeighboursAnchor]
    }

    /// Linux's lists, over the bundled files in `resources` and the shards in `shards`.
    public static func lists(resources: URL, shards: URL) async throws -> Lists {
        let vectors = SemanticVectors(resources: resources, shards: shards)
        let tiers: SemanticBundledTiers
        switch await vectors.tiers() {
        case .success(let read): tiers = read
        case .failure(let refused): throw Refusal(description: "the bundled vectors are refused: \(refused)")
        }
        let index = tiers.index
        var held: [String: SemanticShard] = [:]
        var volumes: [SemanticNeighboursLoop.Volume] = []
        for volume in ParityFixtures.volumes {
            guard let entry = index.volume(volume), let documents = index.documentIDs(forVolume: volume) else {
                throw Refusal(description: "the bundled index has no vectors for \(volume)")
            }
            guard let shard = await vectors.shard(for: volume) else {
                let why = await vectors.refusal(for: volume).map { "\($0.sentence) \($0.detail)" } ?? "none"
                throw Refusal(description: "the server has no usable shard for \(volume): \(why)")
            }
            held[volume] = shard
            volumes.append(.init(id: volume, rowOffset: entry.rowOffset, documentIDs: documents))
        }
        let pool = index.file.retrieval.rerankPool
        let corpus = tiers.corpus
        let shards = held
        let anchors = SemanticNeighboursLoop.anchors(
            volumes: volumes,
            candidates: { row, isEligible in
                SemanticRetrievalKernel.hammingCandidates(queryRow: row, in: corpus, limit: pool, isEligible: isEligible)
            },
            rerank: { row, candidates in
                guard let anchor = index.volumeSlot(containing: row), let shard = shards[index.volumes[anchor.slot].volumeID],
                      let query = shard.vector(at: anchor.localRow) else { return [] }
                return SemanticRetrievalKernel.rerank(candidates: candidates, limit: SemanticNeighboursLoop.neighbourCount) { candidate in
                    guard let place = index.volumeSlot(containing: candidate),
                          let shard = shards[index.volumes[place.slot].volumeID] else { return nil }
                    return shard.cosine(row: place.localRow, query: query.codes, queryScale: query.scale)
                }.map { (row: $0.row, score: $0.score) }
            },
            key: { row in index.document(at: row).map { "\($0.volumeID)/\($0.documentID)" } })
        return Lists(generation: index.provenance.digestHex, rerankPool: pool, anchors: anchors)
    }

    /// Check 9's kernel half at full scale (PLAN's S31): 600 rows' lists over the bundled files in `resources` and all
    /// 553 shards in `shards`, every one opened through the server's own store, which holds it to the bundled manifest.
    public static func corpusLists(resources: URL, shards: URL) async throws -> SemanticCorpusNeighboursGolden {
        let vectors = SemanticVectors(resources: resources, shards: shards)
        let tiers: SemanticBundledTiers
        switch await vectors.tiers() {
        case .success(let read): tiers = read
        case .failure(let refused): throw Refusal(description: "the bundled vectors are refused: \(refused)")
        }
        let index = tiers.index
        var held: [String: SemanticShard] = [:]
        for volume in index.volumes {
            guard let shard = await vectors.shard(for: volume.volumeID) else {
                let why = await vectors.refusal(for: volume.volumeID).map { "\($0.sentence) \($0.detail)" } ?? "none"
                throw Refusal(description: "the server has no usable shard for \(volume.volumeID): \(why)")
            }
            held[volume.volumeID] = shard
        }
        let manifest = resources.appendingPathComponent("semantic-shards-manifest.json")
        let manifestDigest = try ParityFormat.Digest.sha256(contentsOf: manifest)
        let pool = index.file.retrieval.rerankPool
        let corpus = tiers.corpus
        let shardsByVolume = held
        let anchors = SemanticCorpusLoop.anchors(
            rows: SemanticCorpusLoop.rows(documentCount: corpus.documentCount),
            candidates: { row in SemanticRetrievalKernel.hammingCandidates(queryRow: row, in: corpus, limit: pool) },
            rerank: { row, candidates in
                guard let anchor = index.volumeSlot(containing: row),
                      let shard = shardsByVolume[index.volumes[anchor.slot].volumeID],
                      let query = shard.vector(at: anchor.localRow) else { return [] }
                return SemanticRetrievalKernel.rerank(candidates: candidates, limit: SemanticNeighboursLoop.neighbourCount) { candidate in
                    guard let place = index.volumeSlot(containing: candidate),
                          let shard = shardsByVolume[index.volumes[place.slot].volumeID] else { return nil }
                    return shard.cosine(row: place.localRow, query: query.codes, queryScale: query.scale)
                }.map { (row: $0.row, score: $0.score) }
            },
            key: { row in index.document(at: row).map { "\($0.volumeID)/\($0.documentID)" } })
        return SemanticCorpusNeighboursGolden(
            provenance: Provenance(tool: "frus-parity corpus-neighbours", upstreamCommit: nil, appBuild: nil,
                                   indexVersion: IndexingPipeline.currentDateIndexVersion, sourceDigest: "",
                                   inputs: ["shards": "\(held.count) of the bundled manifest's"], platform: .current()),
            configuration: SemanticCorpusLoop.configuration, generation: index.provenance.digestHex,
            shardManifest: manifestDigest, rerankPool: pool, neighbourCount: SemanticNeighboursLoop.neighbourCount,
            stride: SemanticCorpusLoop.stride(documentCount: corpus.documentCount), anchors: anchors)
    }

    /// The lists as a golden file of the Mac's form, which `frus-parity neighbours` writes for a person to compare.
    public static func golden(layout: RepositoryLayout) async throws -> SemanticNeighboursGolden {
        let lists = try await lists(resources: layout.upstream.appendingPathComponent(ParityIndex.resourcesPath),
                                    shards: layout.root.appendingPathComponent(SemanticNeighboursLoop.shardsPath))
        return SemanticNeighboursGolden(
            provenance: Provenance(tool: "frus-parity neighbours", upstreamCommit: layout.upstreamCommit(),
                                   appBuild: Upstream.appBuild(layout.upstream), indexVersion: IndexingPipeline.currentDateIndexVersion,
                                   sourceDigest: try Upstream.sourceDigest(layout.upstream),
                                   inputs: try SemanticNeighboursLoop.verifiedShardInputs(root: layout.root),
                                   platform: .current()),
            configuration: SemanticNeighboursLoop.configuration, generation: lists.generation, rerankPool: lists.rerankPool,
            neighbourCount: SemanticNeighboursLoop.neighbourCount, anchors: lists.anchors)
    }
}
