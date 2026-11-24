// `frus-light semantic` (PLAN's S27b): Search Model's report for a server whose Administration is refused,
// the encoder's state read from the process table, since the command is not the server: idle with no
// encoder running, loaded once the server's child answers its health, off with FRUS_ENCODER=off, and a
// failure where the model is not the bundled index's.

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
}
