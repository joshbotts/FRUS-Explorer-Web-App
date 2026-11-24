// Check 9's encoder half's own path (PLAN's S27b), in process: `EmbedCheck.run`, which `frus-parity embed` runs
// against a server in its image over the app's 25 judged queries, here against a server built as
// `buildApplication` builds one, its encoder the stand-in that answers as llama-server does, its bundled index
// naming the stand-in's model. A fixture of the stand-in's own vectors passes at a cosine of 1; one vector off
// by more than the app's bar fails, named; and a fixture of another model or prompt is refused before any
// query is asked.

import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct EmbedCheckTests {
    /// A server over the stand-in, its app data files the repository's but for a bundled index naming the
    /// stand-in's model: the check run through it, with the model's digest.
    static func run(_ make: @escaping @Sendable (SearchModel) -> EmbedCheck.Fixture) async throws -> EmbedCheck.Result {
        let directory = try TemporaryDirectory()
        defer { withExtendedLifetime(directory) {} }
        let (model, named) = try StandInEncoder.model(in: directory.url.appendingPathComponent("model"))
        let resources = directory.url.appendingPathComponent("resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        for file in try FileManager.default.contentsOfDirectory(atPath: RepositoryFiles.resources.path) where file != SearchModel.indexFile {
            try FileManager.default.createSymbolicLink(at: resources.appendingPathComponent(file),
                                                       withDestinationURL: RepositoryFiles.resources.appendingPathComponent(file))
        }
        let index = try String(contentsOf: RepositoryFiles.resources.appendingPathComponent(SearchModel.indexFile), encoding: .utf8)
        try index.replacingOccurrences(of: try SearchModel.bundled(in: RepositoryFiles.resources).sha256, with: named.sha256)
            .write(to: resources.appendingPathComponent(SearchModel.indexFile), atomically: true, encoding: .utf8)
        let binary = try StandInEncoder.binary()
        let app = try await buildApplication(configuration: ServerConfiguration(
            dataDirectory: directory.url.appendingPathComponent("data"), resourcesDirectory: resources,
            encoderBinary: binary, encoderModel: model))
        let fixture = make(named)
        // Live, so that the server's services run, and its end stops the encoder's child.
        let result = try await app.test(.live) { client in
            await EmbedCheck.run(fixture: fixture) { path in
                let response = try await client.execute(uri: path, method: .get)
                return (Int(response.status.code), Data(buffer: response.body))
            }
        }
        #expect(QueryEncoder.runningProcesses(binary: binary, model: model).isEmpty, "the encoder stopped with the server")
        return result
    }

    static let queries = ["Who negotiated the Treaty of Paris?", "nuclear test ban, 1963", "Kissinger's trip to Beijing"]

    /// The stand-in's vector of `query`, as the app's encoder normalises it.
    static func vector(_ query: String) -> [Double] {
        QueryEncoder.normalised(StandInEncoder.vector(SearchModel.queryPrefix + query))
    }

    static func fixture(_ model: SearchModel, prefix: String = SearchModel.queryPrefix,
                        vector made: (String) -> [Double] = { EmbedCheckTests.vector($0) }) -> EmbedCheck.Fixture {
        let queries = Self.queries.map { #"{"text":"\#($0)","vector":[\#(made($0).map { String($0) }.joined(separator: ","))]}"# }
        let json = #"{"queryPrefix":"\#(prefix)","ggufSHA256":"\#(model.sha256)","referenceEngine":"the stand-in","queries":[\#(queries.joined(separator: ","))]}"#
        return try! JSONDecoder().decode(EmbedCheck.Fixture.self, from: Data(json.utf8))
    }

    @Test func theStandInsOwnVectorsPassAtACosineOfOne() async throws {
        let result = try await Self.run { Self.fixture($0) }
        #expect(result.passes && result.rows.count == 3 && result.failures.isEmpty)
        #expect(result.rows.allSatisfy { abs($0.cosine - 1) < 1e-12 && $0.signsDiffering == 0 && $0.tokens > 5 })
        #expect(result.server?.engine == "version: 0.0.0-stand-in (build 1, commit 5ea4d11)")
        #expect(result.summary().hasPrefix("check 9's encoder half passes: 3 queries, least cosine 1.000000"))
        #expect(result.summary().hasSuffix("0 of 1536 signs of the first 512 values differing, against the stand-in, by version: 0.0.0-stand-in (build 1, commit 5ea4d11)"))
    }

    /// One vector turned from the stand-in's to a cosine of 0.998, toward a direction at right angles to it:
    /// below the app's bar, and named.
    @Test func aVectorBelowTheAppsBarFails() async throws {
        let result = try await Self.run { model in
            Self.fixture(model) { query in
                let vector = Self.vector(query)
                guard query == Self.queries[1] else { return vector }
                let other = Array(vector.reversed())
                let along = zip(other, vector).map(*).reduce(0, +)
                let across = QueryEncoder.normalised(zip(other, vector).map { $0 - along * $1 })
                return zip(vector, across).map { 0.998 * $0 + (1 - 0.998 * 0.998).squareRoot() * $1 }
            }
        }
        #expect(!result.passes && result.rows.count == 3)
        let least = try #require(result.least)
        #expect(least.query == Self.queries[1] && abs(least.cosine - 0.998) < 1e-9)
        #expect(result.summary().contains("; 1 below 0.999, 0 not embedded"))
    }

    @Test func aFixtureOfAnotherModelOrPromptIsRefused() async throws {
        let other = try await Self.run { model in
            Self.fixture(SearchModel(name: model.name, sha256: String(repeating: "b", count: 64), dimensions: model.dimensions))
        }
        #expect(!other.passes && other.rows.isEmpty)
        #expect(other.refusals.first?.contains("where the fixture's vectors were made by \(String(repeating: "b", count: 64))") == true)
        let prompt = try await Self.run { Self.fixture($0, prefix: "query: ") }
        #expect(!prompt.passes && prompt.rows.isEmpty && prompt.refusals.first?.contains(#"under "query: ""#) == true)
    }

    /// The cosine and the signs as the check reads them.
    @Test func theCosineAndTheSigns() {
        #expect(abs(EmbedCheck.cosine([1, 0], [0.6, 0.8]) - 0.6) < 1e-15)
        #expect(EmbedCheck.signsDiffering([1, -1, 0, 0.5], [1, 1, -0.0, -0.5]) == 2, "a zero is packed as a positive sign")
    }
}
