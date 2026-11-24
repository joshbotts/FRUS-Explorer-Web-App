// Check 9's kernel half, on the fixtures (PLAN's S26c): each vectored fixture document's ten nearest by the kit's two
// stages, the Hamming scan over the bundled tier at its rerank pool, fenced to the three fixture volumes, and the int8
// rerank against their shards, with each score's bits. `tools/mac-golden neighbours` writes them from the app's code
// on the Mac, over the app's own shard store, and `frus-parity neighbours` from SemanticVectorsKit on Linux, over the
// server's; the loop below is the one both run, so that the two record a document the same way, and a test holds
// the lists equal, in rows, order and scores.

import Foundation

/// `fixtures/golden/semantic/neighbours.json`.
public struct SemanticNeighboursGolden: Codable, Equatable, Sendable {
    public var format: Int
    public var provenance: Provenance
    /// How the lists were made, in words.
    public var configuration: String
    /// The bundled tier's provenance digest, the generation the lists are of.
    public var generation: String
    /// The candidates the Hamming stage hands the rerank, the bundled index's, and the neighbours kept.
    public var rerankPool: Int
    public var neighbourCount: Int
    /// Every vectored document of the fixture volumes, volumes sorted, each volume's rows in the bundled index's order.
    public var anchors: [SemanticNeighboursAnchor]

    public static let currentFormat = 1

    public init(provenance: Provenance, configuration: String, generation: String, rerankPool: Int, neighbourCount: Int,
                anchors: [SemanticNeighboursAnchor]) {
        self.format = Self.currentFormat
        self.provenance = provenance
        self.configuration = configuration
        self.generation = generation
        self.rerankPool = rerankPool
        self.neighbourCount = neighbourCount
        self.anchors = anchors
    }
}

/// One document and its nearest, best first.
public struct SemanticNeighboursAnchor: Codable, Equatable, Sendable {
    /// `volume/document`, and the document's row in the bundled tier.
    public var document: String
    public var row: Int
    /// The Hamming stage's candidates in its order, nearest first and ties by row, each as `count sha256` of their rows
    /// joined by spaces: fenced to the three volumes, which the rerank scores, all the others since the fence is smaller
    /// than the pool; and over the whole bundled tier at the pool, the nearest of every document, so that the scan's
    /// cut at the pool is held too.
    public var fencedCandidates: String
    public var poolCandidates: String
    /// Each neighbour as `volume/document row scoreBits`: its corpus row and its int8 cosine's IEEE-754 bit pattern,
    /// in lowercase hex.
    public var neighbours: [String]

    public init(document: String, row: Int, fencedCandidates: String, poolCandidates: String, neighbours: [String]) {
        self.document = document
        self.row = row
        self.fencedCandidates = fencedCandidates
        self.poolCandidates = poolCandidates
        self.neighbours = neighbours
    }
}

/// The loop both platforms run, over their own kit's calls.
public enum SemanticNeighboursLoop {
    /// The neighbours kept of each document: Related Documents' and the corpus gates' ten.
    public static let neighbourCount = 10

    /// The golden file's path, from `fixtures/golden`.
    public static let goldenPath = "semantic/neighbours.json"

    /// The fixture volumes' shards, which the golden file's provenance records by path and SHA-256.
    public static let shardsPath = "fixtures/semantic"
    public static var shardInputKeys: [String] {
        ParityFixtures.volumes.map { "\(shardsPath)/\($0).vec" } + ["\(shardsPath)/SHA256SUMS"]
    }

    /// Checks the fixture shards' folder against its `SHA256SUMS`: it lists exactly the fixture volumes' shards, the
    /// folder holds no other, and each file matches its line. Returns the SHA-256 of each of `shardInputKeys`, by key.
    public static func verifiedShardInputs(root: URL) throws -> [String: String] {
        let folder = root.appendingPathComponent(shardsPath)
        let sums: Data
        do {
            sums = try Data(contentsOf: folder.appendingPathComponent("SHA256SUMS"))
        } catch {
            throw GoldenError.malformed(shardsPath, "SHA256SUMS could not be read: \(error.localizedDescription)")
        }
        var listed: [String: String] = [:]
        for line in String(decoding: sums, as: UTF8.self).split(separator: "\n") {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count == 2 else { throw GoldenError.malformed(shardsPath, "SHA256SUMS cannot read \"\(line)\"") }
            listed[fields[1]] = fields[0]
        }
        let expected = Set(ParityFixtures.volumes.map { "\($0).vec" })
        let present = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".vec") }
        guard Set(listed.keys) == expected, present == expected else {
            throw GoldenError.malformed(shardsPath, "it must hold exactly \(expected.sorted().joined(separator: ", ")), each listed in SHA256SUMS")
        }
        var inputs: [String: String] = [:]
        for file in expected.sorted() {
            let digest = try Digest.sha256(contentsOf: folder.appendingPathComponent(file))
            guard digest == listed[file] else { throw GoldenError.malformed(shardsPath, "\(file) does not match SHA256SUMS") }
            inputs["\(shardsPath)/\(file)"] = digest
        }
        inputs["\(shardsPath)/SHA256SUMS"] = Digest.sha256(sums)
        return inputs
    }

    /// What the two stages are, in words, for the golden file and the harness's report alike.
    public static let configuration = """
        The bundled tier, semantic-vectors-index.json with semantic-vectors-binary.bin, loaded as a pair by \
        SemanticBundledTiers(indexAt:binaryAt:), and the three fixture volumes' shards from fixtures/semantic, each \
        opened through SemanticShard(contentsOf:provenance:expectedDocumentCount:) by a host's store. For every \
        document of the three volumes, volumes sorted and rows in the bundled index's order: \
        SemanticRetrievalKernel.hammingCandidates(queryRow:in:limit:isEligible:) at the index's \
        retrieval.rerankPool, its filter the three volumes' rows, then SemanticRetrievalKernel.rerank(candidates:limit:score:) \
        to the ten best, each candidate scored by its shard's cosine(row:query:queryScale:) against the anchor's own \
        int8 codes and scale, SemanticShard.vector(at:), its row and shard found by SemanticVectorIndex.volumeSlot(containing:). \
        Each document's Hamming candidates are recorded too, in the stage's order, as their count and the SHA-256 of their \
        rows joined by spaces: those fenced to the three volumes, and those of the same scan over the whole tier with no \
        filter, at the pool.
        """

    /// One volume of the fence: its id, its first row in the bundled tier, and its documents in row order.
    public struct Volume: Sendable {
        public var id: String
        public var rowOffset: Int
        public var documentIDs: [String]

        public init(id: String, rowOffset: Int, documentIDs: [String]) {
            self.id = id
            self.rowOffset = rowOffset
            self.documentIDs = documentIDs
        }
    }

    /// Each document's record. `candidates` is the Hamming stage for a corpus row at the pool, with the filter given,
    /// `volumes`' rows, or none; `rerank` the int8 stage over the fenced ones, the best first, each with its corpus row
    /// and score; `key` names a corpus row's document, `volume/document`.
    public static func anchors(volumes: [Volume], candidates: (_ row: Int, _ isEligible: ((Int) -> Bool)?) -> [Int],
                               rerank: (_ row: Int, _ candidates: [Int]) -> [(row: Int, score: Double)],
                               key: (_ row: Int) -> String?) -> [SemanticNeighboursAnchor] {
        let fence = volumes.map { $0.rowOffset..<($0.rowOffset + $0.documentIDs.count) }
        let isEligible: (Int) -> Bool = { row in fence.contains { $0.contains(row) } }
        var anchors: [SemanticNeighboursAnchor] = []
        for volume in volumes.sorted(by: { $0.id < $1.id }) {
            for (offset, document) in volume.documentIDs.enumerated() {
                let row = volume.rowOffset + offset
                let fenced = candidates(row, isEligible)
                let nearest = rerank(row, fenced)
                anchors.append(SemanticNeighboursAnchor(
                    document: "\(volume.id)/\(document)", row: row, fencedCandidates: record(fenced),
                    poolCandidates: record(candidates(row, nil)),
                    neighbours: nearest.map { "\(key($0.row) ?? "?") \($0.row) \(String($0.score.bitPattern, radix: 16))" }))
            }
        }
        return anchors
    }

    /// Candidates as an anchor records them: their count, and the SHA-256 of their rows in order, joined by spaces.
    public static func record(_ rows: [Int]) -> String {
        "\(rows.count) \(Digest.sha256(rows.map(String.init).joined(separator: " ")))"
    }

    /// Where two sets of lists differ, as sentences, the first `limit` of them; none when they are the same, document
    /// for document, in rows, order and score bits.
    public static func differences(_ mac: [SemanticNeighboursAnchor], _ linux: [SemanticNeighboursAnchor], limit: Int = 20) -> [String] {
        var found: [String] = []
        if mac.map(\.document) != linux.map(\.document) {
            found.append("the documents differ: the Mac's \(mac.count), Linux's \(linux.count)")
        }
        let theirs = Dictionary(linux.map { ($0.document, $0) }, uniquingKeysWith: { first, _ in first })
        for anchor in mac {
            guard let other = theirs[anchor.document] else { continue }
            if anchor.row != other.row { found.append("\(anchor.document): row \(anchor.row) on the Mac, \(other.row) on Linux") }
            if anchor.fencedCandidates != other.fencedCandidates {
                found.append("\(anchor.document): the fenced Hamming candidates are \(anchor.fencedCandidates) on the Mac, \(other.fencedCandidates) on Linux")
            }
            if anchor.poolCandidates != other.poolCandidates {
                found.append("\(anchor.document): the pool's Hamming candidates are \(anchor.poolCandidates) on the Mac, \(other.poolCandidates) on Linux")
            }
            if anchor.neighbours != other.neighbours {
                let shared = min(anchor.neighbours.count, other.neighbours.count)
                let at = (0..<shared).first { anchor.neighbours[$0] != other.neighbours[$0] } ?? shared
                found.append("\(anchor.document): neighbour \(at + 1) is \(at < anchor.neighbours.count ? anchor.neighbours[at] : "none") on the Mac, \(at < other.neighbours.count ? other.neighbours[at] : "none") on Linux")
            }
            if found.count >= limit { break }
        }
        return found
    }
}
