// Check 9 at full scale (PLAN's S31), in its two halves. The encoder's: a hundred queries embedded on the Mac by the
// app's own encoder, `SemanticQueryEncoder` over the app's model, which `frus-parity embed` holds a server's
// `llama-server` to at the app's bar. The kernel's: 600 corpus rows as queries, one in every 524, the stride the kit's
// benchmark takes, each row's ten nearest by the kit's two stages over the bundled tier and all 553 shards, which
// `frus-parity corpus-neighbours` holds Linux's to, in rows, order and score bits. `tools/mac-golden embed` and
// `tools/mac-golden corpus-neighbours` write the Mac's from the app's code, over the model and the shards, which no
// repository holds: `scripts/make-golden` fetches them as the image's build does, held to the bundled files' digests.

import Foundation

/// The hundred queries of check 9's encoder half: the 90 typed queries the app's repository keeps, in its three files,
/// and the first ten of check 3's.
public enum SemanticQueries {
    /// The app's three files, from the repository's root, in this order: the owner's 25 judged queries, whose vectors
    /// the app's own fixture holds, and the B4 session's 45 topical queries and 20 null controls.
    public static let appFiles = [
        "upstream/FRUS-Explorer/Planning/semantic-vectors/owner-eval-queries-2026-08-27.txt",
        "upstream/FRUS-Explorer/Planning/semantic-vectors/eg2-b4-move-2026-10-15/session-topical-queries.txt",
        "upstream/FRUS-Explorer/Planning/semantic-vectors/eg2-b4-move-2026-10-15/session-null-queries.txt",
    ]
    /// How many of the app's files' queries there are, and of check 3's are taken: its first ten, R01's plain words, as
    /// a reader types them into Search by Meaning too.
    public static let appCount = 90
    public static let checkThreeCount = 10
    public static var count: Int { appCount + checkThreeCount }

    /// The input keys a golden file made from them records: each app file, and check 3's list.
    public static var inputKeys: [String] { appFiles + ["fixtures/parity/queries.jsonl"] }

    /// A file's queries, by the harness grammar the app's fixture script reads them with
    /// (`tools/semantic-harvest/make_query_parity_fixture.py`, `parse_queries`): a blank line or one whose first
    /// character past its leading spaces is `#` is skipped, and a query's tag is split off at three spaces and `#`,
    /// then its trailing spaces.
    public static func queries(inFile text: String) -> [String] {
        var queries: [String] = []
        for raw in text.components(separatedBy: "\n") {
            var line = raw
            while line.hasSuffix("\r") { line.removeLast() }
            let leading = line.drop { $0 == " " || $0 == "\t" }
            if line.trimmingCharacters(in: .whitespaces).isEmpty || leading.hasPrefix("#") { continue }
            if let tag = line.range(of: "   #") { line = String(line[..<tag.lowerBound]) }
            while let last = line.last, last == " " || last == "\t" { line.removeLast() }
            queries.append(line)
        }
        return queries
    }

    /// The hundred, in order, from the repository at `root`, with the SHA-256 of each file read, by its key; the first
    /// ten of check 3's are its first ten lines' `query`, which must be plain words.
    public static func load(root: URL) throws -> (queries: [String], inputs: [String: String]) {
        var queries: [String] = []
        var inputs: [String: String] = [:]
        for path in appFiles {
            let url = root.appendingPathComponent(path)
            let data: Data
            do { data = try Data(contentsOf: url) } catch {
                throw GoldenError.malformed(path, "it could not be read: \(error.localizedDescription)")
            }
            inputs[path] = Digest.sha256(data)
            queries += Self.queries(inFile: String(decoding: data, as: UTF8.self))
        }
        guard queries.count == appCount else {
            throw GoldenError.malformed(appFiles.joined(separator: ", "), "they hold \(queries.count) queries, not the \(appCount) the check takes")
        }
        let listPath = "fixtures/parity/queries.jsonl"
        let list = try Data(contentsOf: root.appendingPathComponent(listPath))
        inputs[listPath] = Digest.sha256(list)
        struct Line: Decodable { let id: String; let query: String }
        let lines = String(decoding: list, as: UTF8.self).split(separator: "\n").prefix(checkThreeCount)
        for line in lines {
            let parsed = try JSONDecoder().decode(Line.self, from: Data(line.utf8))
            guard parsed.query.allSatisfy({ $0.isLetter || $0 == " " }) else {
                throw GoldenError.malformed(listPath, "\(parsed.id) is not plain words: \(parsed.query)")
            }
            queries.append(parsed.query)
        }
        guard queries.count == count else {
            throw GoldenError.malformed(listPath, "it gave \(queries.count - appCount) of the \(checkThreeCount) queries")
        }
        return (queries, inputs)
    }
}

/// `fixtures/golden/semantic/embeddings.json`: the hundred embedded by the app's own encoder on the Mac. Its members
/// are those of the app's own fixture, `query-parity-fixture-embeddinggemma-2.json`, so that `frus-parity embed` reads
/// it as it reads the app's 25.
public struct SemanticEmbeddingsGolden: Codable, Equatable, Sendable {
    public struct Query: Codable, Equatable, Sendable {
        public var text: String
        /// The 768 values, L2-normalised, as `SemanticQueryEncoder.encodeQuery(_:)` returns them.
        public var vector: [Double]
        public var tokens: Int?

        public init(text: String, vector: [Double], tokens: Int? = nil) {
            self.text = text
            self.vector = vector
            self.tokens = tokens
        }
    }

    public var format: Int
    public var provenance: Provenance
    /// The kit's prompt, which each query was embedded under.
    public var queryPrefix: String
    /// The model's SHA-256, the bundled index's `provenance.modelFileSHA256`.
    public var ggufSHA256: String
    /// What embedded them, in words.
    public var referenceEngine: String
    public var queries: [Query]

    public static let currentFormat = 1
    /// The vectors' width: EmbeddingGemma 2's.
    public static let dimensions = 768

    public init(provenance: Provenance, queryPrefix: String, ggufSHA256: String, referenceEngine: String, queries: [Query]) {
        self.format = Self.currentFormat
        self.provenance = provenance
        self.queryPrefix = queryPrefix
        self.ggufSHA256 = ggufSHA256
        self.referenceEngine = referenceEngine
        self.queries = queries
    }
}

/// `fixtures/golden/semantic/corpus-neighbours.json`: 600 corpus rows' ten nearest over all 553 shards.
public struct SemanticCorpusNeighboursGolden: Codable, Equatable, Sendable {
    public var format: Int
    public var provenance: Provenance
    public var configuration: String
    /// The bundled tier's provenance digest, the generation the lists are of.
    public var generation: String
    /// The bundled shard manifest's SHA-256, which every shard was held to.
    public var shardManifest: String
    public var rerankPool: Int
    public var neighbourCount: Int
    /// The rows' stride and how many were taken.
    public var stride: Int
    public var anchors: [SemanticCorpusAnchor]

    public static let currentFormat = 1

    public init(provenance: Provenance, configuration: String, generation: String, shardManifest: String, rerankPool: Int,
                neighbourCount: Int, stride: Int, anchors: [SemanticCorpusAnchor]) {
        self.format = Self.currentFormat
        self.provenance = provenance
        self.configuration = configuration
        self.generation = generation
        self.shardManifest = shardManifest
        self.rerankPool = rerankPool
        self.neighbourCount = neighbourCount
        self.stride = stride
        self.anchors = anchors
    }
}

/// One row and its nearest, best first.
public struct SemanticCorpusAnchor: Codable, Equatable, Sendable {
    /// `volume/document`, and its row in the bundled tier.
    public var document: String
    public var row: Int
    /// The Hamming stage's candidates over the whole tier at the pool, in its order, as `count sha256` of their rows
    /// joined by spaces, which the rerank scores.
    public var candidates: String
    /// Each neighbour as `volume/document row scoreBits`, as `SemanticNeighboursAnchor` records them.
    public var neighbours: [String]

    public init(document: String, row: Int, candidates: String, neighbours: [String]) {
        self.document = document
        self.row = row
        self.candidates = candidates
        self.neighbours = neighbours
    }
}

/// The loop both platforms run for the kernel's half at full scale, over their own kit's calls and shard stores.
public enum SemanticCorpusLoop {
    /// How many rows are taken: SPEC's 600.
    public static let rowCount = 600

    /// The kit's benchmark's stride over a tier of `documentCount` rows (`DimensionLadderBenchmark`,
    /// `count / 600`), 524 for the 314,616 of the pinned generation.
    public static func stride(documentCount: Int) -> Int { max(1, documentCount / rowCount) }

    /// The rows taken: the first 600 of the benchmark's stride, 0 to 313,876 at the pin, where the stride itself runs to a
    /// 601st, 314,400.
    public static func rows(documentCount: Int) -> [Int] {
        Array(Swift.stride(from: 0, to: documentCount, by: stride(documentCount: documentCount)).prefix(rowCount))
    }

    /// What the two stages are, in words.
    public static let configuration = """
        The bundled tier, semantic-vectors-index.json with semantic-vectors-binary.bin, loaded as a pair by \
        SemanticBundledTiers(indexAt:binaryAt:), and all 553 shards, each opened through \
        SemanticShard(contentsOf:provenance:expectedDocumentCount:) by a host's store and held to the bundled \
        semantic-shards-manifest.json's length and SHA-256. For 600 rows of the tier, the first 600 of the stride the \
        kit's DimensionLadderBenchmark takes, documentCount / 600: \
        SemanticRetrievalKernel.hammingCandidates(queryRow:in:limit:isEligible:) at the index's retrieval.rerankPool over \
        the whole tier, with no filter, then SemanticRetrievalKernel.rerank(candidates:limit:score:) to the ten best, \
        each candidate scored by its shard's cosine(row:query:queryScale:) against the anchor's own int8 codes and \
        scale, SemanticShard.vector(at:), its row and shard found by SemanticVectorIndex.volumeSlot(containing:). Each \
        row's Hamming candidates are recorded too, in the stage's order, as their count and the SHA-256 of their rows \
        joined by spaces.
        """

    /// Each row's record. `candidates` is the Hamming stage for a corpus row at the pool over the whole tier; `rerank`
    /// the int8 stage over them, the best first, each with its corpus row and score; `key` names a corpus row's
    /// document, `volume/document`.
    public static func anchors(rows: [Int], candidates: (_ row: Int) -> [Int],
                               rerank: (_ row: Int, _ candidates: [Int]) -> [(row: Int, score: Double)],
                               key: (_ row: Int) -> String?) -> [SemanticCorpusAnchor] {
        rows.map { row in
            let found = candidates(row)
            return SemanticCorpusAnchor(
                document: key(row) ?? "?", row: row, candidates: SemanticNeighboursLoop.record(found),
                neighbours: rerank(row, found).map { "\(key($0.row) ?? "?") \($0.row) \(String($0.score.bitPattern, radix: 16))" })
        }
    }

    /// Where two sets of lists differ, as sentences, the first `limit` of them; none when they are the same, row for
    /// row, in documents, candidates, neighbours and score bits.
    public static func differences(_ mac: [SemanticCorpusAnchor], _ linux: [SemanticCorpusAnchor], limit: Int = 20) -> [String] {
        var found: [String] = []
        if mac.map(\.row) != linux.map(\.row) {
            found.append("the rows differ: the Mac's \(mac.count), Linux's \(linux.count)")
        }
        let theirs = Dictionary(linux.map { ($0.row, $0) }, uniquingKeysWith: { first, _ in first })
        for anchor in mac {
            guard let other = theirs[anchor.row] else { continue }
            if anchor.document != other.document {
                found.append("row \(anchor.row): \(anchor.document) on the Mac, \(other.document) on Linux")
            }
            if anchor.candidates != other.candidates {
                found.append("\(anchor.document): the Hamming candidates are \(anchor.candidates) on the Mac, \(other.candidates) on Linux")
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

    /// The shards' folder's check against the bundled manifest: each shard it names is there, of its length and
    /// SHA-256. Returns the manifest's SHA-256, or throws the first shard that does not hold.
    public static func verifiedShards(folder: URL, manifest: URL) throws -> String {
        struct Manifest: Decodable {
            struct Shard: Decodable { let volumeID: String; let bytes: Int; let sha256: String }
            let shards: [Shard]
        }
        let data = try Data(contentsOf: manifest)
        let listed = try JSONDecoder().decode(Manifest.self, from: data)
        for shard in listed.shards {
            let url = folder.appendingPathComponent("\(shard.volumeID).vec")
            guard let bytes = try? Data(contentsOf: url, options: .alwaysMapped) else {
                throw GoldenError.malformed(folder.path, "it holds no \(shard.volumeID).vec, which the bundled manifest names")
            }
            guard bytes.count == shard.bytes, Digest.sha256(bytes) == shard.sha256 else {
                throw GoldenError.malformed(folder.path, "\(shard.volumeID).vec is not the bundled manifest's: \(bytes.count) bytes, where it names \(shard.bytes)")
            }
        }
        return Digest.sha256(data)
    }
}
