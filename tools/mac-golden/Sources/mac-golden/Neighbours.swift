// neighbours: check 9's kernel half on the fixtures (PLAN's S26c), each vectored fixture document's ten nearest by the
// kit's two stages, run by the app's own code on the Mac: the bundled tier loaded as the app loads it, by
// SemanticBundledTiers, the three fixture volumes' shards through the app's own store, SemanticShardStore, which
// validates each as the app does, and the Hamming scan and the int8 rerank of the kernel the app compiles. The loop
// is ParityFormat's, which frus-parity neighbours runs on Linux over the server's store, and a test holds the two
// lists equal, in rows, order and score bits.

import Foundation
import ParityFormat
@testable import FRUSExplorer

/// Where the lists go.
enum NeighboursPaths {
    /// The golden file, from the repository's root.
    static let golden = "fixtures/golden/" + GoldenFile.semanticNeighbours.rawValue
}

func neighboursGolden(repo: Repository, out: URL) async throws {
    let inputs = try SemanticNeighboursLoop.verifiedShardInputs(root: repo.root)
    let resources = repo.upstream.appendingPathComponent("FRUSExplorer/Resources")
    let tiers = try SemanticBundledTiers(indexAt: resources.appendingPathComponent("semantic-vectors-index.json"),
                                         binaryAt: resources.appendingPathComponent("semantic-vectors-binary.bin"))
    let index = tiers.index
    var counts: [String: Int] = [:]
    for volume in ParityFixtures.volumes { counts[volume] = index.volume(volume)?.documentCount }
    let store = SemanticShardStore(directory: repo.url(SemanticNeighboursLoop.shardsPath), provenance: index.provenance,
                                   expectedCounts: counts)
    var held: [String: SemanticShard] = [:]
    var volumes: [SemanticNeighboursLoop.Volume] = []
    for volume in ParityFixtures.volumes {
        guard let entry = index.volume(volume), let documents = index.documentIDs(forVolume: volume) else {
            throw ToolError("the bundled index has no vectors for \(volume)")
        }
        guard let shard = await store.shard(for: volume) else {
            let why = await store.refusal(for: volume).map { "\($0)" } ?? "none"
            throw ToolError("the app's store refused \(volume)'s shard: \(why)")
        }
        held[volume] = shard
        volumes.append(.init(id: volume, rowOffset: entry.rowOffset, documentIDs: documents))
    }
    let shards = held
    let pool = index.file.retrieval.rerankPool
    let corpus = tiers.corpus
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
    let golden = SemanticNeighboursGolden(
        provenance: try repo.provenance(tool: "tools/mac-golden neighbours", inputs: inputs),
        configuration: SemanticNeighboursLoop.configuration, generation: index.provenance.digestHex, rerankPool: pool,
        neighbourCount: SemanticNeighboursLoop.neighbourCount, anchors: anchors)
    try GoldenJSON.write(golden, to: out)
    note("neighbours: \(anchors.count) documents' ten nearest, at a pool of \(pool), in \(repo.relativePath(out))")
}
