// Administration ▸ Semantic through the router (PLAN's S27b), over the encoder's stand-in: Search Model's
// report, the model in the image held to the bundled index and the encoder idle, then loaded once a query has
// started it; one query embedded through the server's own path, as the smoke test and `frus-parity embed` ask;
// and the refusals, a query missing or too long and a server with the encoder off, each in its words. Since
// S26c, Vectors beside Search Model, over the fixture volumes' shards, and what `/api/v1/status` says of the
// semantic features.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct SemanticRouteTests {
    /// The fixture's server, with `encoder`, and `vectors` or the server's own over its configuration's folder.
    static func app(_ fixture: UserDataFixture, encoder: QueryEncoder, vectors: SemanticVectors? = nil) -> some ApplicationProtocol {
        Application(router: ServedRouter(base: .root, router: buildRouter(
            state: fixture.server.state, resources: fixture.server.resources, reader: fixture.server.reader,
            userData: fixture.services, encoder: encoder, vectors: vectors)))
    }

    /// The vectors over the bundled files and the three fixture volumes' shards.
    static func fixtureVectors() -> SemanticVectors {
        SemanticVectors(resources: RepositoryFiles.resources, shards: RepositoryFiles.semanticShards)
    }

    @Test func vectorsComeBesideSearchModelEachShardChecked() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await Self.app(fixture, encoder: .none, vectors: Self.fixtureVectors()).test(.router) { client in
            let response = try await Browser(client: client).get("/api/v1/admin/semantic")
            #expect(response.status == .ok && response.headers[.cacheControl] == "no-store")
            // Search Model's members are where S27b gave them, and the vectors' report beside them.
            let model = try decode(EncoderReport.self, response)
            #expect(model.setting == "off" && model.state == "off")
            let report = try decode(SemanticAdminReport.self, response)
            #expect(report.searchModel == model)
            let vectors = report.vectors
            #expect(vectors.state == "available" && vectors.generation?.name == "89481b18" && vectors.generation?.documents == 314_616)
            let shards = try #require(vectors.shards)
            #expect(shards.held == 3 && shards.heldBytes == 199_368 && shards.published == 553 && shards.publishedBytes == 162_377_248)
            #expect(shards.checked == 3 && shards.verified == 3 && shards.refused.isEmpty && shards.missing.count == 550)
            let keys = try #require(try JSONSerialization.jsonObject(with: Data(buffer: response.body)) as? [String: Any]).keys.sorted()
            #expect(keys.contains("vectors") && keys.contains("model") && keys.contains("engine") && keys.contains("setting"))
        }
    }

    @Test func theStatusSaysWhichSemanticFeaturesTheServerServes() async throws {
        let fixture = try await ServerFixture()
        let router = buildRouter(state: fixture.state, resources: fixture.resources, reader: fixture.reader, vectors: Self.fixtureVectors())
        try await Application(router: router).test(.router) { client in
            let status = try decode(ServerStatus.self, try await client.execute(uri: "/api/v1/status", method: .get))
            // Related Documents' semantic axis ranks wherever the vectors are served (S26d).
            #expect(status.semantic == SemanticFeatures(vectors: true, generation: "89481b18", shardsHeld: 3, shardsPublished: 553,
                                                        map: true, encoder: false, relatedDocuments: true, searchByMeaning: false))
        }
        // A server whose bundled vectors are refused serves neither them, nor the map drawn from them, nor the axis.
        let empty = try TemporaryDirectory()
        let refused = buildRouter(state: fixture.state, resources: fixture.resources, reader: fixture.reader,
                                  vectors: SemanticVectors(resources: empty.url, shards: empty.url))
        try await Application(router: refused).test(.router) { client in
            let status = try decode(ServerStatus.self, try await client.execute(uri: "/api/v1/status", method: .get))
            #expect(status.semantic == SemanticFeatures(vectors: false, generation: nil, shardsHeld: 0, shardsPublished: 0,
                                                        map: false, encoder: false))
        }
    }

    @Test func searchModelReportsTheModelAndTheEncoderIdleThenLoaded() async throws {
        let fixture = try await UserDataFixture()
        let directory = try TemporaryDirectory()
        let encoder = QueryEncoder(settings: try StandInEncoder.settings(in: directory.url))
        defer { withExtendedLifetime(fixture) {} }
        try await Self.app(fixture, encoder: encoder).test(.router) { client in
            let owner = Browser(client: client)
            let response = try await owner.get("/api/v1/admin/semantic")
            #expect(response.status == .ok && response.headers[.cacheControl] == "no-store")
            let idle = try decode(EncoderReport.self, response)
            #expect(idle.setting == "on" && idle.state == "idle" && idle.model.verified == true && idle.model.present)
            #expect(idle.model.file == "stand-in.gguf" && idle.model.publishedBytes == 309_855_456 && idle.model.licence == "Apache 2.0")
            #expect(idle.engine.present && idle.engine.commit == "5ea4d11" && idle.idleSeconds == 180 && idle.maxTokens == 2_048)

            let query = "the partition of Germany"
            let embedded = try decode(EmbeddingAnswer.self, try await owner.get("/api/v1/admin/semantic/embedding?query=the%20partition%20of%20Germany"))
            #expect(embedded.query == query && embedded.prompt == "task: search result | query: " + query && embedded.started)
            #expect(embedded.dimensions == 768 && embedded.vector == QueryEncoder.normalised(StandInEncoder.vector(embedded.prompt)))
            #expect(embedded.tokens == StandInEncoder.tokens(embedded.prompt))

            let loaded = try decode(EncoderReport.self, try await owner.get("/api/v1/admin/semantic"))
            #expect(loaded.state == "loaded" && loaded.pid != nil && loaded.queries == 1 && loaded.starts == 1)
            #expect(loaded.lastQueryAt != nil && loaded.stopsAt != nil && loaded.loadedAt != nil)
            #expect(problemCode(try await owner.get("/api/v1/admin/semantic?x=1")) == "UNKNOWN_PARAMETER")
        }
        await encoder.shutdown()
    }

    @Test func aQueryMissingOrTooLongIsRefusedInItsWords() async throws {
        let fixture = try await UserDataFixture()
        let directory = try TemporaryDirectory()
        let encoder = QueryEncoder(settings: try StandInEncoder.settings(in: directory.url))
        defer { withExtendedLifetime(fixture) {} }
        try await Self.app(fixture, encoder: encoder).test(.router) { client in
            let owner = Browser(client: client)
            let missing = try await owner.get("/api/v1/admin/semantic/embedding")
            #expect(missing.status == .badRequest && problemCode(missing) == "QUERY_MISSING")
            #expect(problemCode(try await owner.get("/api/v1/admin/semantic/embedding?query=%20")) == "QUERY_MISSING")
            let long = Array(repeating: "word", count: 2_100).joined(separator: "%20")
            let refused = try await owner.get("/api/v1/admin/semantic/embedding?query=\(long)")
            let problem = try decode(APIProblem.Body.self, refused)
            #expect(refused.status == .unprocessableContent && problem.code == "QUERY_TOO_LONG")
            #expect(problem.detail == "This search is too long for the model. Try a shorter phrasing. It is 2,107 tokens, of 2,048 at most.")
        }
        await encoder.shutdown()
    }

    @Test func aServerWithTheEncoderOffSaysSo() async throws {
        let fixture = try await UserDataFixture()
        let directory = try TemporaryDirectory()
        let encoder = QueryEncoder(settings: try StandInEncoder.settings(in: directory.url, enabled: false))
        defer { withExtendedLifetime(fixture) {} }
        try await Self.app(fixture, encoder: encoder).test(.router) { client in
            let owner = Browser(client: client)
            let refused = try await owner.get("/api/v1/admin/semantic/embedding?query=Berlin")
            let problem = try decode(APIProblem.Body.self, refused)
            #expect(refused.status == .conflict && problem.code == "ENCODER_OFF")
            #expect(problem.detail == "This server does not search by meaning: FRUS_ENCODER is off, so its encoder does not start.")
            let report = try decode(EncoderReport.self, try await owner.get("/api/v1/admin/semantic"))
            #expect(report.setting == "off" && report.state == "off" && report.starts == 0)
        }
    }

    /// A router built without an encoder, as most tests build one, offers none.
    @Test func aRouterWithoutAnEncoderOffersNone() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let report = try decode(EncoderReport.self, try await Browser(client: client).get("/api/v1/admin/semantic"))
            #expect(report.setting == "off" && report.state == "off")
        }
    }

    /// FRUS_ENCODER is on unless it says off.
    @Test func theEncoderIsOnUnlessFRUSEncoderIsOff() throws {
        #expect(try ServerConfiguration.fromEnvironment([:]).encoder)
        #expect(try ServerConfiguration.fromEnvironment(["FRUS_ENCODER": "on"]).encoder)
        #expect(try !ServerConfiguration.fromEnvironment(["FRUS_ENCODER": "OFF"]).encoder)
        #expect {
            try ServerConfiguration.fromEnvironment(["FRUS_ENCODER": "maybe"])
        } throws: { error in
            (error as? ConfigurationError)?.problems == ["FRUS_ENCODER must be on or off, not maybe"]
        }
        let image = try ServerConfiguration.fromEnvironment([:])
        #expect(image.encoderBinary.path == "/usr/local/bin/llama-server")
        #expect(image.encoderModel.path == "/usr/share/frus-light/model/embeddinggemma-2-Q8_0.gguf")
        #expect(image.semanticShards.path == "/usr/share/frus-light/semantic/shards")
    }
}
