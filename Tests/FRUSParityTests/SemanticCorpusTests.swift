// Check 9 at full scale (PLAN's S31), what the swift job can hold without the model or the 553 shards, which the
// image holds and the Compose smoke test reads: the hundred queries are the app's 90 and check 3's first ten, read by
// the app's fixture script's grammar; the Mac's vectors for the app's 25 judged queries are the app's own fixture's at
// the app's bar, so the committed file is the app's encoder's; the 600 rows are the kit's benchmark's stride; the two
// committed files are whole and of the bundled generation; the corpus loop refuses a folder without every shard and
// finds a difference where there is one; and the two encoders' agreement is counted over the lists search by meaning
// gives.

@testable import FRUSParity
import Foundation
import FRUSLightCore
import ParityFormat
import SemanticVectorsKit
import Testing

@Suite struct SemanticCorpusTests {
    static let resources = Repository.layout.upstream.appendingPathComponent(ParityIndex.resourcesPath)

    static func embeddings() throws -> SemanticEmbeddingsGolden {
        let status = try GoldenStatus(directory: Repository.layout.golden)
        return try GoldenJSON.read(SemanticEmbeddingsGolden.self, from: status.url(.semanticEmbeddings))
    }

    static func corpus() throws -> SemanticCorpusNeighboursGolden {
        let status = try GoldenStatus(directory: Repository.layout.golden)
        return try GoldenJSON.read(SemanticCorpusNeighboursGolden.self, from: status.url(.semanticCorpusNeighbours))
    }

    @Test func theHundredAreTheAppsNinetyAndCheckThreesFirstTen() throws {
        let queries = try SemanticQueries.load(root: Repository.root)
        #expect(queries.count == 100 && Set(queries).count == 100)
        // The app's fixture script read the owner's 25 from the first file, by the same grammar.
        let fixture = try EmbedCheck.Fixture(contentsOf: Repository.layout.upstream.appendingPathComponent(EmbedCheck.fixturePath))
        #expect(Array(queries.prefix(25)) == fixture.queries.map(\.text))
        #expect(queries[25] == "Alaska purchase negotiations with Russia" && queries[69] == "Why did the United States support Pakistan in 1971?")
        #expect(queries[70] == "Chocolate chip cookie recipe" && queries[89] == "Houseplants that need little light")
        let list = try QueryList.load(Repository.layout.queries)
        #expect(Array(queries.suffix(10)) == list.prefix(10).map(\.query))
        let golden = try Self.embeddings()
        #expect(golden.provenance.inputs["queries.sha256"] == SemanticQueries.digest(queries))
    }

    @Test func theHarnessGrammar() {
        let text = "# a comment\r\n   # an indented comment\n\nMexican Revolution\r\nSpace aliens   # null control\n"
            + "C# in diplomacy  \n\"trust but verify\"\n"
        #expect(SemanticQueries.queries(inFile: text) == ["Mexican Revolution", "Space aliens", "C# in diplomacy", "\"trust but verify\""])
    }

    @Test func theMacsVectorsForTheAppsTwentyFiveAreTheAppsFixturesAtItsBar() async throws {
        let golden = try Self.embeddings()
        let app = try EmbedCheck.Fixture(contentsOf: Repository.layout.upstream.appendingPathComponent(EmbedCheck.fixturePath))
        // The committed file reads as the app's fixture does, under the kit's prompt and the bundled index's model.
        let asFixture = try EmbedCheck.Fixture(contentsOf: try GoldenStatus(directory: Repository.layout.golden).url(.semanticEmbeddings))
        #expect(asFixture.queries.count == 100 && asFixture.queryPrefix == SearchModel.queryPrefix)
        let vectors = SemanticVectors(resources: Self.resources, shards: Repository.root.appendingPathComponent(SemanticNeighboursLoop.shardsPath))
        let tiers = try await vectors.tiers().get()
        #expect(golden.ggufSHA256 == tiers.index.provenance.modelFileSHA256 && golden.ggufSHA256 == app.ggufSHA256)
        // The app's encoder over the app's model against llama.cpp's command line, the app's own measure, on Metal both.
        let mac = Dictionary(golden.queries.map { ($0.text, $0.vector) }, uniquingKeysWith: { first, _ in first })
        let cosines = try app.queries.map { query in EmbedCheck.cosine(try #require(mac[query.text]), query.vector) }
        #expect(cosines.count == 25 && cosines.allSatisfy { $0 >= EmbedCheck.bar })
        #expect(GoldenValidation.semanticEmbeddingsProblems(golden, root: Repository.root) == [])
    }

    @Test func theRowsAreTheFirstSixHundredOfTheBenchmarksStride() async throws {
        let rows = SemanticCorpusLoop.rows(documentCount: 314_616)
        #expect(SemanticCorpusLoop.stride(documentCount: 314_616) == 524)
        #expect(rows.count == 600 && rows.first == 0 && rows.last == 313_876)
        // The benchmark's own stride runs to a 601st row, which the check leaves out.
        #expect(Array(stride(from: 0, to: 314_616, by: 524)).count == 601)
        let golden = try Self.corpus()
        let vectors = SemanticVectors(resources: Self.resources, shards: Repository.root.appendingPathComponent(SemanticNeighboursLoop.shardsPath))
        let tiers = try await vectors.tiers().get()
        #expect(golden.anchors.map(\.row) == SemanticCorpusLoop.rows(documentCount: tiers.corpus.documentCount))
        #expect(golden.generation == tiers.index.provenance.digestHex && golden.rerankPool == tiers.index.file.retrieval.rerankPool)
        let manifest = Self.resources.appendingPathComponent(SemanticVectors.manifestFile)
        #expect(golden.shardManifest == (try ParityFormat.Digest.sha256(contentsOf: manifest)))
        #expect(golden.anchors.allSatisfy { $0.neighbours.count == 10 && $0.candidates.hasPrefix("800 ") })
        for anchor in golden.anchors.prefix(50) {
            let identity = try #require(tiers.index.document(at: anchor.row))
            #expect(anchor.document == "\(identity.volumeID)/\(identity.documentID)")
        }
        #expect(GoldenValidation.semanticCorpusNeighboursProblems(golden) == [])
    }

    @Test func theCorpusListsNeedEveryShard() async throws {
        await #expect(throws: SemanticNeighbours.Refusal.self) {
            _ = try await SemanticNeighbours.corpusLists(
                resources: Self.resources, shards: Repository.root.appendingPathComponent(SemanticNeighboursLoop.shardsPath))
        }
        // A folder holding three of the 553 is refused before a list is made, by the shard's own check.
        #expect(throws: GoldenError.self) {
            _ = try SemanticCorpusLoop.verifiedShards(
                folder: Repository.root.appendingPathComponent(SemanticNeighboursLoop.shardsPath),
                manifest: Self.resources.appendingPathComponent(SemanticVectors.manifestFile))
        }
    }

    @Test func aDifferenceIsFoundInARowACandidateAnOrderOrAScore() {
        let anchors = SemanticCorpusLoop.anchors(
            rows: [0, 524],
            candidates: { row in row == 0 ? [3, 1] : [2] },
            rerank: { row, _ in row == 0 ? [(row: 3, score: 0.5), (row: 1, score: 0.25)] : [(row: 2, score: 0.75)] },
            key: { "v/d\($0)" })
        #expect(anchors.map(\.neighbours) == [["v/d3 3 3fe0000000000000", "v/d1 1 3fd0000000000000"], ["v/d2 2 3fe8000000000000"]])
        #expect(anchors[0].candidates == "2 \(ParityFormat.Digest.sha256("3 1"))")
        #expect(SemanticCorpusLoop.differences(anchors, anchors) == [])
        var swapped = anchors
        swapped[0].neighbours.reverse()
        #expect(SemanticCorpusLoop.differences(anchors, swapped)
            == ["v/d0: neighbour 1 is v/d3 3 3fe0000000000000 on the Mac, v/d1 1 3fd0000000000000 on Linux"])
        var scored = anchors
        scored[1].neighbours = ["v/d2 2 3fe8000000000001"]
        #expect(SemanticCorpusLoop.differences(anchors, scored)
            == ["v/d524: neighbour 1 is v/d2 2 3fe8000000000000 on the Mac, v/d2 2 3fe8000000000001 on Linux"])
        var candidates = anchors
        candidates[1].candidates = SemanticNeighboursLoop.record([2, 5])
        #expect(SemanticCorpusLoop.differences(anchors, candidates).count == 1)
        #expect(SemanticCorpusLoop.differences(anchors, [anchors[0]]).first == "the rows differ: the Mac's 2, Linux's 1")
    }

    @Test func theValidationFindsAFileThatIsNotWhole() throws {
        var embeddings = try Self.embeddings()
        embeddings.queries.removeLast()
        #expect(!GoldenValidation.semanticEmbeddingsProblems(embeddings, root: Repository.root).isEmpty)
        embeddings = try Self.embeddings()
        embeddings.queries[3].vector = embeddings.queries[3].vector.map { $0 * 2 }
        #expect(GoldenValidation.semanticEmbeddingsProblems(embeddings, root: Repository.root).count == 1)
        embeddings = try Self.embeddings()
        embeddings.queryPrefix = "query: "
        #expect(GoldenValidation.semanticEmbeddingsProblems(embeddings, root: Repository.root).count == 1)

        var corpus = try Self.corpus()
        corpus.anchors.removeFirst()
        #expect(!GoldenValidation.semanticCorpusNeighboursProblems(corpus).isEmpty)
        corpus = try Self.corpus()
        corpus.anchors[7].neighbours[2] = "frus1861/d3"
        #expect(GoldenValidation.semanticCorpusNeighboursProblems(corpus).count == 1)
        corpus = try Self.corpus()
        corpus.anchors[9].candidates = SemanticNeighboursLoop.record([1, 2, 3])
        #expect(GoldenValidation.semanticCorpusNeighboursProblems(corpus).count == 1)
    }

    @Test func theAgreementOfTwoEncodersIsCountedOverWhatSearchByMeaningLists() async throws {
        // Over the fixture volumes' shards, the lists are the scored candidates of those volumes, which suffices to count.
        let golden = try Self.embeddings()
        let picked = golden.queries.filter { ["berlin crisis", "khrushchev kennedy", "soviet union nuclear"].contains($0.text) }
        #expect(picked.count == 3)
        let fixture = try JSONDecoder().decode(EmbedCheck.Fixture.self, from: JSONEncoder().encode(
            SemanticEmbeddingsGolden(provenance: golden.provenance, queryPrefix: golden.queryPrefix, ggufSHA256: golden.ggufSHA256,
                                     referenceEngine: golden.referenceEngine, queries: picked)))
        let shards = Repository.root.appendingPathComponent(SemanticNeighboursLoop.shardsPath)
        let same = Dictionary(picked.map { ($0.text, $0.vector) }, uniquingKeysWith: { first, _ in first })
        let agreed = try await EmbedCheck.agreement(fixture: fixture, server: same, resources: Self.resources, shards: shards)
        #expect(agreed.rows.count == 3 && agreed.rows.allSatisfy { $0.fixture == $0.server })
        #expect(agreed.listed > 0 && agreed.shared == agreed.listed)
        #expect(agreed.summary().contains("3 of 3 queries list the same ten"))
        // One query embedded as another: its lists part.
        var crossed = same
        crossed["berlin crisis"] = same["soviet union nuclear"]
        let parted = try await EmbedCheck.agreement(fixture: fixture, server: crossed, resources: Self.resources, shards: shards)
        let berlin = try #require(parted.rows.first { $0.query == "berlin crisis" })
        #expect(berlin.server == agreed.rows.first { $0.query == "soviet union nuclear" }?.server)
        #expect(parted.shared <= agreed.shared)
    }
}
