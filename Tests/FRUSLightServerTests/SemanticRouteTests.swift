// Administration ▸ Semantic through the router (PLAN's S27b), over the encoder's stand-in: Search Model's
// report, the model in the image held to the bundled index and the encoder idle, then loaded once a query has
// started it; one query embedded through the server's own path, as the smoke test and `frus-parity embed` ask;
// and the refusals, a query missing or too long and a server with the encoder off, each in its words.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct SemanticRouteTests {
    /// The fixture's server, with `encoder`.
    static func app(_ fixture: UserDataFixture, encoder: QueryEncoder) -> some ApplicationProtocol {
        Application(router: ServedRouter(base: .root, router: buildRouter(
            state: fixture.server.state, resources: fixture.server.resources, reader: fixture.server.reader,
            userData: fixture.services, encoder: encoder)))
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
    }
}
