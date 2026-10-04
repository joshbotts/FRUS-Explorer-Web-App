// What a golden file's provenance records: the app's sources and resources, and the fixtures.

import FRUSLightTestSupport
@testable import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct ProvenanceTests {
    /// Every regular file under the six directories counts, resources too, whatever its name;
    /// hidden files do not, and a symbolic link counts by the path it holds. A fixed vector, so
    /// Linux and macOS agree.
    @Test func upstreamDigestCoversEveryResourceAndNoHiddenFile() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let upstream = directory.url.appendingPathComponent("upstream", isDirectory: true)
            func write(_ path: String, _ text: String) throws {
                let url = upstream.appendingPathComponent(path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(text.utf8).write(to: url)
            }
            for name in UpstreamDigest.directories {
                try FileManager.default.createDirectory(at: upstream.appendingPathComponent(name), withIntermediateDirectories: true)
            }
            try write("FRUSExplorer/App.swift", "struct App {}\n")
            try write("FRUSExplorer/Resources/broken-refs-index.json", "{\"degradableTargets\":[]}\n")
            try write("FTS5Store/FTS5Types.swift", "enum FTS5 {}\n")
            try write("FRUSExplorer/.DS_Store", "Finder's")
            try write("FRUSExplorer/.build/Cache.swift", "struct Cache {}\n")
            try write("outside.swift", "struct Outside {}\n")
            try FileManager.default.createSymbolicLink(
                atPath: upstream.appendingPathComponent("FRUSExplorer/Linked.swift").path, withDestinationPath: "../outside.swift")

            let digest = try UpstreamDigest.compute(upstream: upstream)
            let lines = [
                "FRUSExplorer/App.swift\t\(Digest.sha256("struct App {}\n"))",
                "FRUSExplorer/Linked.swift\t\(Digest.sha256("../outside.swift"))",
                "FRUSExplorer/Resources/broken-refs-index.json\t\(Digest.sha256("{\"degradableTargets\":[]}\n"))",
                "FTS5Store/FTS5Types.swift\t\(Digest.sha256("enum FTS5 {}\n"))",
            ]
            #expect(digest == Digest.sha256(lines.joined(separator: "\n")))
            #expect(digest == "2955a9f2820ce6e6f7c9e582c3bd6a940d2e1870654f37b7a766e36a415cca07")

            // Hidden files, and the file a link points to, leave it as it was.
            try write("FRUSExplorer/.DS_Store", "Finder's, rewritten")
            try write("FRUSExplorer/.build/Cache.swift", "struct Cache { var stale = true }\n")
            try write("outside.swift", "struct Outside { var moved = true }\n")
            #expect(try UpstreamDigest.compute(upstream: upstream) == digest)

            // A bundled resource changes it.
            try write("FRUSExplorer/Resources/broken-refs-index.json", "{\"degradableTargets\":[{}]}\n")
            #expect(try UpstreamDigest.compute(upstream: upstream) != digest)

            // A missing directory is an error, not an empty one.
            try FileManager.default.removeItem(at: upstream.appendingPathComponent("WordCloudKit"))
            #expect(throws: (any Error).self) { try UpstreamDigest.compute(upstream: upstream) }
        }
    }

    @Test func fixturesAreVerifiedAgainstTheirSums() throws {
        let inputs = try ParityFixtures.verifiedInputs(tei: Repository.layout.tei)
        #expect(inputs.keys.sorted() == ParityFixtures.teiInputKeys.sorted())
        let sums = try String(contentsOf: Repository.layout.tei.appendingPathComponent("SHA256SUMS"), encoding: .utf8)
        for volume in ParityFixtures.volumes {
            let digest = try #require(inputs["fixtures/tei/\(volume).xml"])
            #expect(sums.contains("\(digest)  \(volume).xml"))
        }

        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let tei = directory.url.appendingPathComponent("tei", isDirectory: true)
            try writeTEIFixtures(to: tei)
            #expect(try ParityFixtures.verifiedInputs(tei: tei).count == 4)

            try Data("<TEI>changed</TEI>".utf8).write(to: tei.appendingPathComponent("frus1961-63v06.xml"))
            #expect(throws: GoldenError.malformed("fixtures/tei", "frus1961-63v06.xml does not match SHA256SUMS")) {
                try ParityFixtures.verifiedInputs(tei: tei)
            }

            try writeTEIFixtures(to: tei)
            try Data("<TEI/>".utf8).write(to: tei.appendingPathComponent("frus1900.xml"))
            #expect(throws: GoldenError.self) { try ParityFixtures.verifiedInputs(tei: tei) }

            try FileManager.default.removeItem(at: tei.appendingPathComponent("frus1900.xml"))
            try FileManager.default.removeItem(at: tei.appendingPathComponent("frus1894Nicaragua.xml"))
            #expect(throws: GoldenError.self) { try ParityFixtures.verifiedInputs(tei: tei) }
        }
    }

    @Test func upstreamCommitIsNilWithoutGit() throws {
        let directory = try TemporaryDirectory()
        withExtendedLifetime(directory) {
            #expect(RepositoryLayout(root: directory.url).upstreamCommit() == nil)
        }
        if let commit = Repository.layout.upstreamCommit() {
            #expect(commit.count == 40 && commit.allSatisfy(\.isHexDigit))
        }
    }
}
