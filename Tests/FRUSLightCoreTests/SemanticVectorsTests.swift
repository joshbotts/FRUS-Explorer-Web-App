// The semantic vectors on the server (PLAN's S26c), over the submodule's bundled files and the three fixture
// volumes' shards: the bundled tier read through the kit's readers and refused whole as the kit refuses it, or
// with a manifest of another generation; each shard the kit's own reading, held to the bundled manifest's length
// and SHA-256; a shard of the wrong digest refused in the sentence the pane shows, as one of another generation and
// as one whose bytes are not the manifest's, and one missing counted apart; and what the status says, read from the
// folder's listing.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import SemanticVectorsKit
import Testing

@Suite struct SemanticVectorsTests {
    static let volumes = ["frus1894Nicaragua", "frus1961-63v06", "frus1969-76ve09p1"]
    static let generation = "89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101"

    /// A folder of the app's data files with the bundled pair, as linked from the submodule or with the binary's bytes
    /// edited, and the manifest, as it is or with its shards and digest edited.
    static func resources(binary: ((inout Data) -> Void)? = nil, manifest: (inout [String: Any]) -> Void = { _ in },
                          leaving: String? = nil) throws -> TemporaryDirectory {
        let folder = try TemporaryDirectory()
        let bundled = RepositoryFiles.resources
        try FileManager.default.createSymbolicLink(at: folder.url.appendingPathComponent(SemanticVectors.indexFile),
                                                   withDestinationURL: bundled.appendingPathComponent(SemanticVectors.indexFile))
        if let binary {
            var data = try Data(contentsOf: bundled.appendingPathComponent(SemanticVectors.binaryFile))
            binary(&data)
            try data.write(to: folder.url.appendingPathComponent(SemanticVectors.binaryFile))
        } else {
            try FileManager.default.createSymbolicLink(at: folder.url.appendingPathComponent(SemanticVectors.binaryFile),
                                                       withDestinationURL: bundled.appendingPathComponent(SemanticVectors.binaryFile))
        }
        var object = try #require(try JSONSerialization.jsonObject(
            with: Data(contentsOf: bundled.appendingPathComponent(SemanticVectors.manifestFile))) as? [String: Any])
        manifest(&object)
        try JSONSerialization.data(withJSONObject: object).write(to: folder.url.appendingPathComponent(SemanticVectors.manifestFile))
        if let leaving { try FileManager.default.removeItem(at: folder.url.appendingPathComponent(leaving)) }
        return folder
    }

    /// The manifest's shards narrowed to the fixture volumes'.
    static func fixturesAlone(_ manifest: inout [String: Any]) {
        let shards = manifest["shards"] as? [[String: Any]] ?? []
        manifest["shards"] = shards.filter { volumes.contains($0["volumeID"] as? String ?? "") }
    }

    /// A folder of the fixture volumes' shards, each as committed or with its bytes edited, less those left out.
    static func shards(_ edits: [String: (inout Data) -> Void] = [:], leaving: Set<String> = []) throws -> TemporaryDirectory {
        let folder = try TemporaryDirectory()
        for volume in volumes where !leaving.contains(volume) {
            var data = try Data(contentsOf: RepositoryFiles.semanticShards.appendingPathComponent("\(volume).vec"))
            edits[volume]?(&data)
            try data.write(to: folder.url.appendingPathComponent("\(volume).vec"))
        }
        return folder
    }

    @Test func everyFixtureShardIsTheKitsOwnReadingHeldToTheManifest() async throws {
        let vectors = SemanticVectors(resources: RepositoryFiles.resources, shards: RepositoryFiles.semanticShards)
        let tiers = try SemanticBundledTiers(indexAt: RepositoryFiles.resources.appendingPathComponent(SemanticVectors.indexFile),
                                             binaryAt: RepositoryFiles.resources.appendingPathComponent(SemanticVectors.binaryFile))
        for volume in Self.volumes {
            let shard = try #require(await vectors.shard(for: volume), "\(volume)'s shard")
            let kit = try SemanticShard(contentsOf: RepositoryFiles.semanticShards.appendingPathComponent("\(volume).vec"),
                                        provenance: tiers.index.provenance, expectedDocumentCount: tiers.index.volume(volume)?.documentCount)
            #expect(shard.documentCount == kit.documentCount && shard.dims == 512)
            for row in 0..<kit.documentCount {
                let (ours, theirs) = (try #require(shard.vector(at: row)), try #require(kit.vector(at: row)))
                #expect(ours.codes == theirs.codes && ours.scale.bitPattern == theirs.scale.bitPattern, "\(volume) row \(row)")
            }
        }
        #expect(await vectors.mappedVolumeIDs == Set(Self.volumes))
        // A volume the manifest publishes no shard for is ordinary, not a fault.
        let unpublished = await vectors.shard(for: "frus9999")
        #expect(unpublished == nil)
        #expect(await vectors.refusal(for: "frus9999") == .notPublished)

        let report = await vectors.report()
        #expect(report.state == "available" && report.problem == nil)
        let generation = try #require(report.generation)
        #expect(generation == .init(digest: Self.generation, name: "89481b18", generated: "2026-10-15", model: "embeddinggemma-2-Q8_0",
                                    nativeDimensions: 768, dimensions: 512, documents: 314_616, volumes: 553, rerankPool: 800,
                                    measuredRecallAt10: 0.9021))
        let shards = try #require(report.shards)
        #expect(shards.folder == RepositoryFiles.semanticShards.path)
        #expect(shards.held == 3 && shards.heldBytes == 199_368 && shards.published == 553 && shards.publishedBytes == 162_377_248)
        #expect(shards.checked == 3 && shards.verified == 3 && shards.refused.isEmpty)
        #expect(shards.missing.count == 550 && Set(shards.missing).isDisjoint(with: Self.volumes) && shards.missing.first == "frus1861")
    }

    @Test func aShardOfTheWrongDigestIsRefusedInTheSentenceThePaneShows() async throws {
        let resources = try Self.resources(manifest: Self.fixturesAlone)
        let shards = try Self.shards([
            // Another generation's: its header names other vectors, which the kit's `SemanticShard` refuses.
            "frus1894Nicaragua": { $0[16] ^= 0xFF },
            // This generation's header over other bytes: the kit's checks pass, and the manifest's SHA-256 does not.
            "frus1961-63v06": { $0[100] ^= 0x01 },
        ], leaving: ["frus1969-76ve09p1"])
        let vectors = SemanticVectors(resources: resources.url, shards: shards.url)
        for volume in Self.volumes { #expect(await vectors.shard(for: volume) == nil, "\(volume) is refused") }
        #expect(await vectors.refusal(for: "frus1894Nicaragua") == .unusable(.provenanceMismatch(expected: Self.generation,
                                                                                                    found: "76481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101")))
        guard case .notTheManifests(let expected, let found)? = await vectors.refusal(for: "frus1961-63v06") else {
            Issue.record("the edited shard is not refused as the manifest's")
            return
        }
        #expect(expected == "SHA-256 2219eb681046db21430ed2a3c8a154e7293dbd4367c06cd4b5a2ccbb6ce42836" && found.hasPrefix("SHA-256 ") && found != expected)
        #expect(await vectors.refusal(for: "frus1969-76ve09p1") == .missing)

        let report = try #require(await vectors.report().shards)
        #expect(report.held == 2 && report.heldBytes == 71_272 + 61_984 && report.published == 3 && report.publishedBytes == 199_368)
        #expect(report.checked == 2 && report.verified == 0 && report.missing == ["frus1969-76ve09p1"])
        #expect(report.refused == [
            .init(volumeId: "frus1894Nicaragua",
                  reason: "This file was made for a different version of the app, so it cannot be used with this one.",
                  detail: "Its header names the vectors 76481b18; the bundled index's are 89481b18."),
            .init(volumeId: "frus1961-63v06", reason: "The file did not arrive intact, so the server does not use it.",
                  detail: "The bundled manifest names \(expected); the file is \(found)."),
        ])
        #expect(SemanticStorageWords.problemsCaption(report.refused.count + report.missing.count, checked: report.checked)
            == "3 found. The server checked all 2 files in its image against the bundled manifest.")
    }

    @Test func aShardCutShortOrOfAnotherCountIsRefusedAsDamaged() async throws {
        let resources = try Self.resources(manifest: Self.fixturesAlone)
        let shards = try Self.shards(["frus1894Nicaragua": { $0.removeLast(4) }, "frus1961-63v06": { $0[12] = 119 }])
        let vectors = SemanticVectors(resources: resources.url, shards: shards.url)
        let report = try #require(await vectors.report().shards)
        #expect(report.verified == 1 && report.refused.map(\.volumeId) == ["frus1894Nicaragua", "frus1961-63v06"])
        #expect(report.refused.allSatisfy { $0.reason == "The file in the image is damaged and was not used." })
        #expect(report.refused.map(\.detail) == [
            "Expected 71272 bytes for 138 rows, found 71268.",
            "Shard holds 119 rows, index says 120.",
        ])
    }

    @Test func theBundledVectorsAreRefusedWholeAsTheKitRefusesThem() async throws {
        let cases: [(String, TemporaryDirectory, String)] = [
            ("the binary is missing", try Self.resources(leaving: SemanticVectors.binaryFile),
             "The bundled vectors are refused: semantic-vectors-binary.bin is not among this server's data files."),
            ("the index is missing", try Self.resources(leaving: SemanticVectors.indexFile),
             "The bundled vectors are refused: semantic-vectors-index.json is not among this server's data files."),
            ("the binary names other vectors", try Self.resources(binary: { $0[20] ^= 0xFF }),
             "The bundled vectors are refused: semantic-vectors-binary.bin was made from the vectors 76481b18, where the bundled index names 89481b18."),
            ("the binary is cut short", try Self.resources(binary: { $0.removeLast(516) }),
             "The bundled vectors are refused: semantic-vectors-binary.bin could not be read: expected 20476048 bytes for 314616 rows + 660 centroids, found 20475532."),
            ("the manifest names other vectors", try Self.resources(manifest: { $0["provenanceDigest"] = String(repeating: "0", count: 64) }),
             "The bundled vectors are refused: semantic-shards-manifest.json was made from the vectors 00000000, where the bundled index names 89481b18."),
            ("the manifest is missing", try Self.resources(leaving: SemanticVectors.manifestFile),
             "The bundled vectors are refused: semantic-shards-manifest.json is not among this server's data files."),
        ]
        for (what, resources, problem) in cases {
            let vectors = SemanticVectors(resources: resources.url, shards: RepositoryFiles.semanticShards)
            let report = await vectors.report()
            #expect(report.state == "unavailable" && report.generation == nil && report.shards == nil, "\(what)")
            #expect(report.problem == problem, "\(what): \(report.problem ?? "none")")
            #expect(await vectors.shard(for: "frus1894Nicaragua") == nil, "\(what): no shard is served")
            let features = await vectors.features(map: false, encoder: false)
            #expect(!features.vectors && features.generation == nil && features.shardsPublished == 0, "\(what)")
        }
        // A manifest of another generation leaves the pair itself read, which the map is drawn from.
        let other = try Self.resources(manifest: { $0["provenanceDigest"] = String(repeating: "0", count: 64) })
        guard case .success(let tiers) = await SemanticVectors(resources: other.url, shards: other.url).tiers() else {
            Issue.record("the pair is refused with the manifest")
            return
        }
        #expect(tiers.index.documentCount == 314_616)
    }

    @Test func theStatusReadsTheFoldersListingAndHashesNothing() async throws {
        let shards = try Self.shards(["frus1961-63v06": { $0[100] ^= 0x01 }])
        let vectors = SemanticVectors(resources: RepositoryFiles.resources, shards: shards.url)
        let features = await vectors.features(map: true, encoder: true)
        #expect(features == SemanticFeatures(vectors: true, generation: "89481b18", shardsHeld: 3, shardsPublished: 553, map: true,
                                             encoder: true, relatedDocuments: false, searchByMeaning: false))
        // Nothing was checked: the edited shard is found only once something asks for it.
        #expect(await vectors.refusal(for: "frus1961-63v06") == nil)
        #expect(await vectors.shard(for: "frus1961-63v06") == nil)
        #expect(await vectors.shard(for: "frus1894Nicaragua") != nil)
    }

    @Test func manyAskingAtOnceShareOneCheck() async throws {
        let vectors = SemanticVectors(resources: RepositoryFiles.resources, shards: RepositoryFiles.semanticShards)
        let counts = await withTaskGroup(of: Int?.self) { group in
            for _ in 0..<24 { group.addTask { await vectors.shard(for: "frus1969-76ve09p1")?.documentCount } }
            var all: [Int?] = []
            for await count in group { all.append(count) }
            return all
        }
        #expect(counts.count == 24 && counts.allSatisfy { $0 == 128 })
        #expect(await vectors.mappedVolumeIDs == ["frus1969-76ve09p1"])
    }

    @Test func aSizeIsWrittenAsTheAppsSectionWritesIt() {
        let sizes = [0, 1, 999, 1_096, 61_984, 199_368, 999_499, 162_377_248, 1_000_000_000, 1_234_567_890]
        #expect(sizes.map(SemanticStorageWords.fileSize) == [
            "Zero KB", "1 byte", "999 bytes", "1 KB", "62 KB", "199 KB", "999 KB", "162.4 MB", "1 GB", "1.23 GB",
        ])
        #expect(SemanticStorageWords.heldValue(553, of: 553) == "553 of 553")
        #expect(SemanticStorageWords.heldDetail(162_377_248, of: 162_377_248) == "162.4 MB of 162.4 MB on this server.")
        #expect(SemanticStorageWords.problemsCaption(0, checked: 553)
            == "Nothing has gone wrong. The server checked all 553 files in its image against the bundled manifest.")
        #expect(SemanticStorageWords.problemsCaption(1, checked: 1) == "1 found. The server checked the one file in its image against the bundled manifest.")
    }
}
