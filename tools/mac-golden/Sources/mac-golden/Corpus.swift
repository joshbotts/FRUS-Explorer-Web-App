// embed and corpus-neighbours: check 9 at full scale (PLAN's S31), run by the app's own code on the Mac.
//
// embed: the hundred queries (ParityFormat's SemanticQueries) embedded by the app's own encoder, SemanticQueryEncoder,
// over the vendored llama.xcframework and the app's model, a file the caller names, held first to the bundled index's
// SHA-256 by the app's own SemanticModelStore.sha256Hex, as the app holds a model it adopts. frus-parity embed holds a
// server's llama-server to its vectors, at the app's bar.
//
// corpus-neighbours: 600 corpus rows' ten nearest by the kit's two stages over the bundled tier and all 553 shards, a
// folder the caller names, checked against the bundled manifest and opened through the app's own SemanticShardStore,
// which validates each as the app does. The loop is ParityFormat's, which frus-parity corpus-neighbours runs on Linux
// over the server's store.

import Foundation
import ParityFormat
@testable import FRUSExplorer

/// Where the files go.
enum CorpusPaths {
    static let embeddings = "fixtures/golden/" + GoldenFile.semanticEmbeddings.rawValue
    static let corpusNeighbours = "fixtures/golden/" + GoldenFile.semanticCorpusNeighbours.rawValue
}

/// The bundled tier, as the app loads it.
private func bundledTiers(_ repo: Repository) throws -> (tiers: SemanticBundledTiers, resources: URL) {
    let resources = repo.upstream.appendingPathComponent("FRUSExplorer/Resources")
    let tiers = try SemanticBundledTiers(indexAt: resources.appendingPathComponent("semantic-vectors-index.json"),
                                         binaryAt: resources.appendingPathComponent("semantic-vectors-binary.bin"))
    return (tiers, resources)
}

func embedGolden(repo: Repository, model: URL, out: URL) async throws {
    let (queries, inputs) = try SemanticQueries.load(root: repo.root)
    let (tiers, _) = try bundledTiers(repo)
    let expected = tiers.index.provenance.modelFileSHA256
    let digest = try SemanticModelStore.sha256Hex(of: model)
    guard digest == expected else {
        throw ToolError("the model at \(model.path) has SHA-256 \(digest), where the bundled index names \(expected)")
    }
    let script = try String(contentsOf: repo.upstream.appendingPathComponent("Scripts/build-llama-xcframework.sh"), encoding: .utf8)
    guard let commit = script.firstMatch(of: /LLAMA_COMMIT=([0-9a-f]{40})/)?.1 else {
        throw ToolError("Scripts/build-llama-xcframework.sh names no LLAMA_COMMIT")
    }
    let encoder = SemanticQueryEncoder()
    try await encoder.load(modelPath: model.path)
    var rows: [SemanticEmbeddingsGolden.Query] = []
    let started = Date()
    for query in queries {
        rows.append(.init(text: query, vector: try await encoder.encodeQuery(query)))
    }
    let seconds = Date().timeIntervalSince(started)
    await encoder.unload()
    let engine = "SemanticQueryEncoder, the app's own, over the vendored llama.xcframework (llama.cpp \(commit.prefix(7)), "
        + "the commit Scripts/build-llama-xcframework.sh names), loaded as the app loads it: the model mapped, Metal, a "
        + "batch of \(SemanticQueryEncoder.maxTokens) tokens, pooling and attention the GGUF's, L2-normalised in double precision"
    var recorded = inputs
    recorded["model.sha256"] = digest
    let golden = SemanticEmbeddingsGolden(
        provenance: try repo.provenance(tool: "tools/mac-golden embed", inputs: recorded),
        queryPrefix: SemanticQueryPrompt.queryPrefix, ggufSHA256: digest, referenceEngine: engine, queries: rows)
    try GoldenJSON.write(golden, to: out)
    note("embed: \(rows.count) queries embedded by the app's encoder in \(String(format: "%.1f", seconds)) s, in \(repo.relativePath(out))")
}

func corpusNeighboursGolden(repo: Repository, shards: URL, out: URL) async throws {
    let (tiers, resources) = try bundledTiers(repo)
    let index = tiers.index
    let manifestDigest = try SemanticCorpusLoop.verifiedShards(
        folder: shards, manifest: resources.appendingPathComponent("semantic-shards-manifest.json"))
    var counts: [String: Int] = [:]
    for volume in index.volumes { counts[volume.volumeID] = volume.documentCount }
    let store = SemanticShardStore(directory: shards, provenance: index.provenance, expectedCounts: counts)
    var held: [String: SemanticShard] = [:]
    for volume in index.volumes {
        guard let shard = await store.shard(for: volume.volumeID) else {
            let why = await store.refusal(for: volume.volumeID).map { "\($0)" } ?? "none"
            throw ToolError("the app's store refused \(volume.volumeID)'s shard: \(why)")
        }
        held[volume.volumeID] = shard
    }
    let shardsByVolume = held
    let pool = index.file.retrieval.rerankPool
    let corpus = tiers.corpus
    let started = Date()
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
    let seconds = Date().timeIntervalSince(started)
    let golden = SemanticCorpusNeighboursGolden(
        provenance: try repo.provenance(tool: "tools/mac-golden corpus-neighbours",
                                        inputs: ["shards": "\(held.count) of the bundled manifest's, each of its length and SHA-256"]),
        configuration: SemanticCorpusLoop.configuration, generation: index.provenance.digestHex, shardManifest: manifestDigest,
        rerankPool: pool, neighbourCount: SemanticNeighboursLoop.neighbourCount,
        stride: SemanticCorpusLoop.stride(documentCount: corpus.documentCount), anchors: anchors)
    try GoldenJSON.write(golden, to: out)
    note("corpus-neighbours: \(anchors.count) rows' ten nearest, one in every \(golden.stride), over \(held.count) shards at a pool of \(pool), in \(String(format: "%.1f", seconds)) s, in \(repo.relativePath(out))")
}
