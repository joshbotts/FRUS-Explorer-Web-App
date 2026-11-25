// The semantic map's reading's routes (PLAN's S28c), over the bundled files and a server with no index: what each
// refuses, in the API's words; a lens's and a mask's answers revalidated by their own bytes; and, with no index served,
// nothing on this server: On This Server colours no point, and a point's card opens nothing. Every answer's agreement
// with the kit over the fixture index is `SemanticMapReadingParityTests`'.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct SemanticMapReadingRouteTests {
    static func status(_ client: any TestClientProtocol, _ uri: String) async throws -> (Int, String) {
        let response = try await client.execute(uri: uri, method: .get)
        let code = (try? JSONDecoder().decode(APIProblem.Body.self, from: Data(buffer: response.body)))?.code ?? ""
        return (Int(response.status.code), code)
    }

    @Test func eachRouteRefusesWhatItCannotRead() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for (uri, expected, code) in [
                ("/api/v1/semantic/map/reading?lens=era", 400, "UNKNOWN_PARAMETER"),
                ("/api/v1/semantic/map/lens", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/lens?lens=administration", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/lens?lens=era&lens=cluster", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/scope?subseries=1961-63&volume=frus1961-63v06", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/scope?volume=frus1800", 404, "VOLUME_NOT_FOUND"),
                ("/api/v1/semantic/map/scope?administration=nobody", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/scope?scopeLabel=Mine", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/scope/flags", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/labels?x=0&y=0&halfExtent=30000&width=900", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/labels?x=0&y=0&halfExtent=0&width=900&height=600", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/labels?x=nan&y=0&halfExtent=30000&width=900&height=600", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/labels?x=0&y=0&halfExtent=30000&width=20000&height=600", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/labels?x=0&y=0&halfExtent=30000&width=900&height=600&zoom=2", 400, "UNKNOWN_PARAMETER"),
                ("/api/v1/semantic/map/pick?x=0&y=0", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/pick?x=0&y=0&tolerance=-1", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/pick?x=1e99&y=0&tolerance=10", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/request?region=-1", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/request?region=1&region=2", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/request?focus=1", 400, "UNKNOWN_PARAMETER"),
                ("/api/v1/semantic/map/regions/twelve", 404, "REGION_NOT_FOUND"),
                ("/api/v1/semantic/map/regions/012", 404, "REGION_NOT_FOUND"),
                ("/api/v1/semantic/map/regions/140", 404, "REGION_NOT_FOUND"),
                ("/api/v1/semantic/map/regions/3?layout=00000000:2026-01-01:1", 409, "LAYOUT_CHANGED"),
                ("/api/v1/semantic/map/regions/3?limit=0", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/regions/3?limit=201", 400, "INVALID_PARAMETER"),
                ("/api/v1/semantic/map/regions/3?offset=7501", 400, "INVALID_PARAMETER"),
            ] {
                let (answered, named) = try await Self.status(client, uri)
                #expect(answered == expected && named == code, "\(uri) answered \(answered) \(named)")
            }
        }
    }

    @Test func withNoIndexServedNothingIsOnThisServer() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let onServer = try await client.execute(uri: "/api/v1/semantic/map/lens?lens=availability", method: .get)
            #expect(onServer.status == .ok)
            let slots = Array(onServer.body.readableBytesView)
            #expect(slots.count == 314_616 && slots.allSatisfy { $0 == 0 }, "no volume is on this server")
            // A point is picked all the same, the map drawing the whole series, and its card opens nothing.
            let picked = try decode(SemanticMapPickAnswer.self, try await client.execute(
                uri: "/api/v1/semantic/map/pick?x=0&y=0&tolerance=30000", method: .get))
            let point = try #require(picked.point)
            #expect(!point.served && point.title == nil && !point.headline.isEmpty)
            let card = try decode(SemanticMapRegionCard.self, try await client.execute(
                uri: "/api/v1/semantic/map/regions/3?limit=5", method: .get))
            #expect(card.documents.count == 5 && card.documents.allSatisfy { !$0.served && $0.title == nil })
            #expect(card.total == card.kept || card.kept == 7_500)
        }
    }

    @Test func aLensAndAMaskRevalidateByTheirBytes() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for uri in ["/api/v1/semantic/map/lens?lens=era", "/api/v1/semantic/map/scope/flags?subseries=1961-63"] {
                let first = try await client.execute(uri: uri, method: .get)
                let tag = try #require(first.headers[.eTag])
                #expect(first.status == .ok && first.headers[.cacheControl] == "private, no-cache")
                let again = try await client.execute(uri: uri, method: .get, headers: [.ifNoneMatch: tag])
                #expect(again.status == .notModified && again.body.readableBytes == 0, "\(uri)")
                let other = try await client.execute(uri: uri, method: .get, headers: [.ifNoneMatch: "\"0\""])
                #expect(other.status == .ok && other.headers[.eTag] == tag)
            }
            // Two lenses, two answers.
            let era = try await client.execute(uri: "/api/v1/semantic/map/lens?lens=era", method: .get)
            let regions = try await client.execute(uri: "/api/v1/semantic/map/lens?lens=cluster", method: .get)
            #expect(era.headers[.eTag] != regions.headers[.eTag])
        }
    }
}
