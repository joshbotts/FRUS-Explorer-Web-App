// Check 9's kernel half on the fixtures (PLAN's S26c): every vectored fixture document's ten nearest by the kit's two
// stages on Linux, over the server's own store of the fixture volumes' shards, are the Mac's, which
// `tools/mac-golden neighbours` wrote from the app's code over the app's own shard store, in rows, order and score
// bits. The fixture shards are the vectors' host's, as the bundled manifest names them, and the loop's comparison
// finds a difference where there is one.

@testable import FRUSParity
import Foundation
import FRUSLightCore
import ParityFormat
import Testing

@Suite struct SemanticNeighboursTests {
    @Test func linuxsListsAreTheMacs() async throws {
        let status = try GoldenStatus(directory: Repository.layout.golden)
        guard status.isPresent(.semanticNeighbours) else {
            Issue.record("\(GoldenFile.semanticNeighbours.rawValue) is made from the app's source alone and must be committed: run scripts/make-golden")
            return
        }
        let mac = try GoldenJSON.read(SemanticNeighboursGolden.self, from: status.url(.semanticNeighbours))
        let linux = try await SemanticNeighbours.lists(
            resources: Repository.layout.upstream.appendingPathComponent(ParityIndex.resourcesPath),
            shards: Repository.root.appendingPathComponent(SemanticNeighboursLoop.shardsPath))
        #expect(mac.generation == linux.generation && mac.rerankPool == linux.rerankPool && mac.rerankPool == 800)
        // The 386 vectored documents of the three volumes, each with its ten nearest among the 385 others, which the
        // fenced Hamming stage gives in its order, and the pool's 800 over the whole tier.
        #expect(linux.anchors.count == 138 + 120 + 128 && linux.anchors.allSatisfy { $0.neighbours.count == 10 })
        #expect(linux.anchors.allSatisfy { $0.fencedCandidates.hasPrefix("385 ") && $0.poolCandidates.hasPrefix("800 ") })
        #expect(SemanticNeighboursLoop.differences(mac.anchors, linux.anchors) == [])
        #expect(GoldenValidation.semanticNeighboursProblems(mac) == [])
    }

    @Test func theFixtureShardsAreTheHostsAsTheBundledManifestNamesThem() throws {
        let manifest = try JSONDecoder().decode(
            SemanticShardManifest.self,
            from: Data(contentsOf: Repository.layout.upstream.appendingPathComponent("\(ParityIndex.resourcesPath)/\(SemanticVectors.manifestFile)")))
        let inputs = try SemanticNeighboursLoop.verifiedShardInputs(root: Repository.root)
        var total = 0
        for volume in ParityFixtures.volumes {
            let entry = try #require(manifest.shards.first { $0.volumeID == volume })
            let url = Repository.root.appendingPathComponent("\(SemanticNeighboursLoop.shardsPath)/\(volume).vec")
            let bytes = try Data(contentsOf: url)
            #expect(bytes.count == entry.bytes && inputs["\(SemanticNeighboursLoop.shardsPath)/\(volume).vec"] == entry.sha256, "\(volume)")
            total += bytes.count
        }
        #expect(total == 199_368)
    }

    @Test func aDifferenceIsFoundInARowAnOrderOrAScore() {
        let (one, two) = (SemanticNeighboursLoop.record([1, 2]), SemanticNeighboursLoop.record([0]))
        #expect(one == "2 \(ParityFormat.Digest.sha256("1 2"))")
        let mac = [
            SemanticNeighboursAnchor(document: "v/d1", row: 0, fencedCandidates: one, poolCandidates: one,
                                     neighbours: ["v/d2 1 3fe0000000000000", "v/d3 2 3fd0000000000000"]),
            SemanticNeighboursAnchor(document: "v/d2", row: 1, fencedCandidates: two, poolCandidates: two,
                                     neighbours: ["v/d1 0 3fe0000000000000"]),
        ]
        #expect(SemanticNeighboursLoop.differences(mac, mac) == [])
        var swapped = mac
        swapped[0].neighbours.reverse()
        #expect(SemanticNeighboursLoop.differences(mac, swapped)
            == ["v/d1: neighbour 1 is v/d2 1 3fe0000000000000 on the Mac, v/d3 2 3fd0000000000000 on Linux"])
        var scored = mac
        scored[1].neighbours = ["v/d1 0 3fe0000000000001"]
        #expect(SemanticNeighboursLoop.differences(mac, scored)
            == ["v/d2: neighbour 1 is v/d1 0 3fe0000000000000 on the Mac, v/d1 0 3fe0000000000001 on Linux"])
        #expect(SemanticNeighboursLoop.differences(mac, [mac[0]]).first == "the documents differ: the Mac's 2, Linux's 1")
        var ordered = mac
        ordered[0].poolCandidates = SemanticNeighboursLoop.record([2, 1])
        #expect(SemanticNeighboursLoop.differences(mac, ordered)
            == ["v/d1: the pool's Hamming candidates are \(one) on the Mac, \(ordered[0].poolCandidates) on Linux"])
    }
}
