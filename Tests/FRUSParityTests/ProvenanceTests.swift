// What a golden file's provenance records: the app's sources and resources, and the fixtures.

import FRUSLightTestSupport
@testable import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct ProvenanceTests {
    /// Every regular file under the listed directories counts, resources too, whatever its name;
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
        }
    }

    /// FRUSCoreKit is listed before the pin reaches upstream's FRUSCoreKit, part 1. A listed
    /// directory the submodule lacks contributes nothing, as an empty one does, so the digest at an
    /// older pin, and the golden files made there, stay as they were. Once the directory exists,
    /// its files count, and moving a file into it changes the digest, as that pin move will.
    @Test func upstreamDigestSkipsAListedDirectoryThePinLacks() throws {
        #expect(UpstreamDigest.directories.contains("FRUSCoreKit"))
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let manager = FileManager.default
            let upstream = directory.url.appendingPathComponent("upstream", isDirectory: true)
            let kit = upstream.appendingPathComponent("FRUSCoreKit", isDirectory: true)
            func write(_ path: String, _ text: String) throws {
                let url = upstream.appendingPathComponent(path)
                try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(text.utf8).write(to: url)
            }
            func line(_ path: String, _ text: String) -> String { "\(path)\t\(Digest.sha256(text))" }

            // A submodule as at cfc0d3c: the app's directories, and no FRUSCoreKit.
            try write("FRUSExplorer/App.swift", "struct App {}\n")
            try write("FRUSExplorer/TEI/FRUSDocumentParser.swift", "struct Parser {}\n")
            try write("FTS5Store/FTS5Types.swift", "enum FTS5 {}\n")
            let before = try UpstreamDigest.compute(upstream: upstream)
            #expect(before == Digest.sha256([
                line("FRUSExplorer/App.swift", "struct App {}\n"),
                line("FRUSExplorer/TEI/FRUSDocumentParser.swift", "struct Parser {}\n"),
                line("FTS5Store/FTS5Types.swift", "enum FTS5 {}\n"),
            ].joined(separator: "\n")))

            // Every other listed directory present but empty gives the same digest.
            for name in UpstreamDigest.directories {
                try manager.createDirectory(at: upstream.appendingPathComponent(name), withIntermediateDirectories: true)
            }
            #expect(try UpstreamDigest.compute(upstream: upstream) == before)
            try manager.removeItem(at: kit)
            #expect(try UpstreamDigest.compute(upstream: upstream) == before)

            // The pin move: the parser moves into FRUSCoreKit, and its new path counts.
            try manager.removeItem(at: upstream.appendingPathComponent("FRUSExplorer/TEI"))
            try write("FRUSCoreKit/TEI/FRUSDocumentParser.swift", "struct Parser {}\n")
            let after = try UpstreamDigest.compute(upstream: upstream)
            #expect(after == Digest.sha256([
                line("FRUSCoreKit/TEI/FRUSDocumentParser.swift", "struct Parser {}\n"),
                line("FRUSExplorer/App.swift", "struct App {}\n"),
                line("FTS5Store/FTS5Types.swift", "enum FTS5 {}\n"),
            ].joined(separator: "\n")))
            #expect(after != before)

            // Something at a listed path that is not a directory is an error, never skipped: a
            // file, or a symbolic link pointing nowhere.
            try manager.removeItem(at: kit)
            try Data("not a directory".utf8).write(to: kit)
            #expect(throws: (any Error).self) { try UpstreamDigest.compute(upstream: upstream) }
            try manager.removeItem(at: kit)
            try manager.createSymbolicLink(atPath: kit.path, withDestinationPath: "nowhere")
            #expect(throws: (any Error).self) { try UpstreamDigest.compute(upstream: upstream) }

            // A submodule holding none of the directories, as an uninitialized one is, is an error,
            // and so is one that is not there.
            let empty = directory.url.appendingPathComponent("empty", isDirectory: true)
            try manager.createDirectory(at: empty, withIntermediateDirectories: true)
            #expect(throws: GoldenError.self) { try UpstreamDigest.compute(upstream: empty) }
            #expect(throws: GoldenError.self) {
                try UpstreamDigest.compute(upstream: directory.url.appendingPathComponent("absent", isDirectory: true))
            }
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
