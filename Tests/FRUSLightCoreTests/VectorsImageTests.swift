// The semantic vectors in the image (PLAN's S26c), held to the pinned app: docker/Dockerfile's vectors' host to the
// repository the app's shard fetcher names, and the generation its address names to the bundled index's provenance,
// so that a pin move that moves the bundled tier to another generation moves the image's folder with it; the
// runtime's two layers at the server's folder, as docker/fetch-vectors lays them out; and the fixture shards
// committed under fixtures/semantic, the host's own, as the bundled manifest names them.

import FRUSLightTestSupport
import Foundation
import SemanticVectorsKit
import Testing

@testable import FRUSLightCore

@Suite struct VectorsImageTests {
    @Test func theHostIsTheOneTheAppsFetcherNamesAtTheBundledGeneration() throws {
        let fetcher = try EncoderImageTests.read("FRUSExplorer/Semantic/SemanticShardFetcher.swift", in: EncoderImageTests.app)
        let address = try #require(fetcher.firstMatch(of: /static let defaultBaseURL = URL\(\s*string: "([^"]+)"\)!/)?.1)
        let parts = try #require(address.wholeMatch(of: /https:\/\/raw\.githubusercontent\.com\/([^\/]+\/[^\/]+)\/main\/generations\/([0-9a-f]{8})\/shards/))
        #expect(try EncoderImageTests.dockerArgument("VECTORS_REPOSITORY") == String(parts.1))
        let tiers = try SemanticBundledTiers(indexAt: RepositoryFiles.resources.appendingPathComponent(SemanticVectors.indexFile),
                                             binaryAt: RepositoryFiles.resources.appendingPathComponent(SemanticVectors.binaryFile))
        #expect(String(parts.2) == String(tiers.index.provenance.digestHex.prefix(8)))
        // A commit is named whole, so that the build fetches the one the plan names.
        for name in ["VECTORS_COMMIT", "VECTORS_BASE_COMMIT"] {
            #expect(try EncoderImageTests.dockerArgument(name).wholeMatch(of: /[0-9a-f]{40}/) != nil, "\(name)")
        }
    }

    /// The vectors stage holds the shards through docker/fetch-vectors, given CI's cache or fetching, and the runtime
    /// copies them in two layers of their own at the folder the server opens them from.
    @Test func theDockerfileLaysTheShardsOutInTwoLayersAtTheServersFolder() throws {
        let dockerfile = try EncoderImageTests.read("docker/Dockerfile")
        #expect(dockerfile.contains("FROM scratch AS vectors-source"))
        #expect(dockerfile.contains("--mount=type=bind,from=vectors-source,target=/given"))
        #expect(dockerfile.contains("COPY upstream/FRUS-Explorer/FRUSExplorer/Resources/semantic-shards-manifest.json /vectors/bundled-manifest.json"))
        #expect(dockerfile.contains("VECTORS_MANIFEST=/vectors/bundled-manifest.json fetch-vectors /vectors/mirror --layout /out"))
        #expect(dockerfile.contains("COPY --link --from=vectors /out/base/ /\nCOPY --link --from=vectors /out/repack/ /\n"))
        let script = try EncoderImageTests.read("docker/fetch-vectors")
        #expect(script.contains("local folder=$1 out=$2 shards=usr/share/frus-light/semantic/shards stamp"))
        #expect(ServerConfiguration.imageSemanticShards.path == "/usr/share/frus-light/semantic/shards")
        #expect(ServerConfiguration().semanticShards == ServerConfiguration.imageSemanticShards)
    }

    @Test func theFixtureShardsAreTheHostsAsTheBundledManifestNamesThem() throws {
        let manifest = try JSONDecoder().decode(SemanticShardManifest.self,
                                                from: Data(contentsOf: RepositoryFiles.resources.appendingPathComponent(SemanticVectors.manifestFile)))
        #expect(manifest.shards.count == 553 && manifest.publishedBytes == 162_377_248)
        let sums = try EncoderImageTests.read("fixtures/semantic/SHA256SUMS")
        let named = Set(try FileManager.default.contentsOfDirectory(atPath: RepositoryFiles.semanticShards.path).filter { $0.hasSuffix(".vec") })
        #expect(named == ["frus1894Nicaragua.vec", "frus1961-63v06.vec", "frus1969-76ve09p1.vec"])
        for file in named.sorted() {
            let entry = try #require(manifest.shards.first { "\($0.volumeID).vec" == file })
            let bytes = try Data(contentsOf: RepositoryFiles.semanticShards.appendingPathComponent(file))
            #expect(bytes.count == entry.bytes, "\(file)")
            #expect(sums.contains("\(entry.sha256)  \(file)\n"), "\(file) in SHA256SUMS at the manifest's digest")
        }
    }
}
