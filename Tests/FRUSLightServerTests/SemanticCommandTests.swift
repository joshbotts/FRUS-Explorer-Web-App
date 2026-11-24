// `frus-light semantic` (PLAN's S27b): Search Model's report for a server whose Administration is refused,
// the encoder's state read from the process table, since the command is not the server: idle with no
// encoder running, loaded once the server's child answers its health, off with FRUS_ENCODER=off, and a
// failure where the model is not the bundled index's. Since S26c, Vectors after it, as the pane gives them,
// over the fixture volumes' shards, and the bundled vectors refused.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Synchronization
import Testing

@testable import FRUSLightServer

@Suite struct SemanticCommandTests {
    /// A server's configuration over the stand-in, whose app data files hold a bundled index naming the
    /// stand-in's model, or `digest` in its place.
    static func configuration(_ directory: TemporaryDirectory, encoder: Bool = true, digest: String? = nil) throws -> ServerConfiguration {
        let (model, named) = try StandInEncoder.model(in: directory.url.appendingPathComponent("model"))
        let resources = directory.url.appendingPathComponent("resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let index = try String(contentsOf: RepositoryFiles.resources.appendingPathComponent(SearchModel.indexFile), encoding: .utf8)
        let real = try SearchModel.bundled(in: RepositoryFiles.resources)
        try index.replacingOccurrences(of: real.sha256, with: digest ?? named.sha256)
            .write(to: resources.appendingPathComponent(SearchModel.indexFile), atomically: true, encoding: .utf8)
        return ServerConfiguration(dataDirectory: directory.url.appendingPathComponent("data"), resourcesDirectory: resources,
                                   encoder: encoder, encoderBinary: try StandInEncoder.binary(), encoderModel: model)
    }

    /// The lines a run says, kept.
    final class Said: Sendable {
        private let lines = Mutex<[String]>([])
        var all: [String] { lines.withLock { $0 } }
        func add(_ line: String) { lines.withLock { $0.append(line) } }
    }

    static func run(_ configuration: ServerConfiguration) async -> (status: Int32, lines: [String]) {
        let said = Said()
        let status = await SemanticCommand.run([], configuration, say: said.add)
        return (status, said.all)
    }

    @Test func idleThenLoadedOnceTheServersEncoderAnswers() async throws {
        let directory = try TemporaryDirectory()
        let configuration = try Self.configuration(directory)
        let idle = await Self.run(configuration)
        #expect(idle.status == 0 && idle.lines.first == "Search Model")
        #expect(idle.lines.contains("  Encoder     on: idle, it starts at the next search by meaning"))
        #expect(idle.lines.contains { $0.hasPrefix("  SHA-256") && $0.hasSuffix(", the bundled index's: verified") })
        #expect(idle.lines.contains { $0.hasPrefix("  Engine      llama.cpp's llama-server, ") && $0.hasSuffix(", commit 5ea4d11") })

        // The server's encoder, started by a query, as a server's own child.
        let server = QueryEncoder(settings: EncoderSettings(configuration: configuration))
        _ = try await server.embed("the Bay of Pigs")
        let pid = try #require(await server.report().pid)
        let loaded = await Self.run(configuration)
        #expect(loaded.status == 0)
        let line = try #require(loaded.lines.first { $0.hasPrefix("  Encoder") })
        #expect(line.hasPrefix("  Encoder     on: loaded, process \(pid), holding ") && line.hasSuffix(" MB; it stops after 3 minutes without a search"))
        await server.shutdown()
    }

    @Test func offOrAModelThatIsNotTheBundledIndexs() async throws {
        let off = try TemporaryDirectory()
        let stopped = await Self.run(try Self.configuration(off, encoder: false))
        #expect(stopped.status == 0 && stopped.lines.contains(
            "  Encoder     off (FRUS_ENCODER=off): it never starts, and the server offers no search by meaning"))

        let other = try TemporaryDirectory()
        let refused = await Self.run(try Self.configuration(other, digest: String(repeating: "a", count: 64)))
        #expect(refused.status == 1)
        #expect(refused.lines.contains("  Encoder     on (FRUS_ENCODER), and it cannot start"))
        #expect(refused.lines.contains { $0.hasPrefix("  SHA-256") && $0.hasSuffix(", where the bundled index names \(String(repeating: "a", count: 64))") })
        #expect(refused.lines.contains { $0.hasPrefix("  Problem     This server cannot search by meaning: its search model, ") })
    }

    @Test func vectorsFollowSearchModelAsThePaneGivesThem() async throws {
        let directory = try TemporaryDirectory()
        let configuration = ServerConfiguration(dataDirectory: directory.url, resourcesDirectory: RepositoryFiles.resources, encoder: false,
                                                semanticShards: RepositoryFiles.semanticShards)
        let run = await Self.run(configuration)
        #expect(run.status == 0)
        let vectors = Array(run.lines.drop { $0 != "Semantic Vectors" })
        #expect(vectors == [
            "Semantic Vectors",
            "  Generation  89481b18, made on 2026-10-15: embeddinggemma-2-Q8_0, its 768 dimensions cut to 512",
            "  Documents   314,616 in 553 volumes; the Hamming stage gives the int8 rerank 800, at a recall@10 of 0.9021",
            "  In image    3 of 553: 199 KB of 162.4 MB on this server, in \(RepositoryFiles.semanticShards.path)",
            "  Problems    550 found. The server checked all 3 files in its image against the bundled manifest.",
            "  Missing     550: frus1861, frus1862, frus1863p1, frus1863p2, frus1864p1 and 545 more. The file is not in the image.",
        ])

        // With the bundled vectors refused, the section says so, and the status stays the encoder's.
        let other = try TemporaryDirectory()
        let refused = await Self.run(try Self.configuration(other, encoder: false))
        #expect(refused.status == 0)
        #expect(Array(refused.lines.drop { $0 != "Semantic Vectors" }) == [
            "Semantic Vectors",
            "  Vectors     Not available: This server cannot match documents by subject, so that part of Related Documents is unavailable. Nothing is wrong with its library.",
            "  Problem     The bundled vectors are refused: semantic-vectors-binary.bin is not among this server's data files.",
        ])
    }
}
