// /api/v1/me/highlights and a document's highlights through the router (PLAN's S15c): a highlight is
// made as the app's reader makes one, its text and rendering version the kit's over the page's own
// model; a document's are listed in the order the reader draws them, each stale or not by the kit's
// rule; one is given another colour or deleted by id; and a request the app's reader could not send
// is refused, storing nothing.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct HighlightTests {
    static let d1 = "/api/v1/me/volumes/frus1961-63v06/documents/d1/highlights"

    /// The page's model, as the reader builds it with no index served, and its flat text.
    static func page(_ fixture: UserDataFixture, _ volume: String = "frus1961-63v06",
                     _ document: String = "d1") async throws -> (model: FRUSDocumentRenderModel, flat: String) {
        let parsed = try await fixture.server.reader.document(volume: volume, document: document)
        let model = ReaderService.model(parsed, volume: volume, classification: nil, brokenRefs: fixture.server.resources.brokenRefs)
        return (model, buildFlatText(from: model))
    }

    /// The UTF-16 offsets of `phrase` in `flat`.
    static func offsets(of phrase: String, in flat: String) throws -> (start: Int, end: Int) {
        let range = try #require(flat.range(of: phrase))
        let start = flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
        return (start, start + phrase.utf16.count)
    }

    /// The rendering version the reader's page sends, which a new highlight's request names.
    static func pageVersion(_ browser: Browser, _ volume: String = "frus1961-63v06", _ document: String = "d1") async throws -> String {
        let page = try await browser.get("/api/v1/volumes/\(volume)/documents/\(document)/html")
        return try #require(page.headers[ReaderRoutes.renderingVersionHeader])
    }

    static func body(_ start: Int, _ end: Int, _ color: String, _ version: String) -> String {
        #"{"startOffset": \#(start), "endOffset": \#(end), "colorTag": "\#(color)", "renderingVersion": "\#(version)"}"#
    }

    /// The done-when's first half on the server: a colour chosen over a selection makes a highlight
    /// as `createWebKitHighlight` makes one, and the document lists it for the reader to draw.
    @Test func aHighlightIsMadeAsTheAppsReaderMakesOne() async throws {
        let fixture = try await UserDataFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        let (model, flat) = try await Self.page(fixture)
        let phrase = "Allow me to congratulate you on the occasion of your election"
        let (start, end) = try Self.offsets(of: phrase, in: flat)
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let version = try await Self.pageVersion(browser)
            #expect(version == ASTToRenderNodeConverter.renderingVersion(for: model))
            let made = try await browser.send(.post, Self.d1, Self.body(start, end, "yellow", version))
            #expect(made.status == .created)
            let highlight = try decode(Highlight.self, made)
            #expect(made.headers[.location] == "/api/v1/me/highlights/\(highlight.id)")
            #expect(UUID(uuidString: highlight.id)?.uuidString == highlight.id)
            #expect(highlight.volumeId == "frus1961-63v06" && highlight.documentId == "d1")
            #expect(highlight.startOffset == start && highlight.endOffset == end && highlight.colorTag == "yellow")
            #expect(highlight.selectedText == phrase, "within one paragraph, the flat text between the offsets")
            #expect(highlight.renderingVersion == version && highlight.noteId == nil && highlight.isStale == nil)
            #expect(highlight.createdAt == "2026-10-24T00:00:00.000Z")

            // Across paragraphs, the kit's excerpt: each paragraph's part, joined by a blank line.
            let blocks = buildFlatTextBlocks(from: model)
            let boundary = blocks[0].utf16.count
            let across = try decode(Highlight.self, try await browser.send(.post, Self.d1, Self.body(boundary - 12, boundary + 12, "blue", version)))
            #expect(across.selectedText == flatTextExcerpt(from: model, start: boundary - 12, end: boundary + 12))
            #expect(across.selectedText.contains("\n\n"), "\(across.selectedText)")
            // Over text another holds: another highlight, as in the app.
            let again = try decode(Highlight.self, try await browser.send(.post, Self.d1, Self.body(start, end, "pink", version)))
            #expect(again.id != highlight.id)

            let listed = try decode(DocumentHighlights.self, try await browser.get(Self.d1))
            #expect(listed.volumeId == "frus1961-63v06" && listed.documentId == "d1" && listed.renderingVersion == version)
            #expect(listed.items.map(\.id) == [highlight.id, across.id, again.id].sorted(), "the fixture's clock stands still, so by id")
            #expect(listed.items.allSatisfy { $0.isStale == false })
            var stale = highlight
            stale.isStale = false
            #expect(listed.items.first { $0.id == highlight.id } == stale)
            #expect(try decode(Highlight.self, try await browser.get("/api/v1/me/highlights/\(highlight.id.lowercased())")) == highlight)
            let all = try decode(HighlightList.self, try await browser.get("/api/v1/me/highlights"))
            #expect(all.total == 3 && Set(all.items.map(\.id)) == Set(listed.items.map(\.id)) && all.items.allSatisfy { $0.isStale == nil })
        }
    }

    /// The kit's stale rule: a highlight made at another rendering version is stale, drawn in amber
    /// and answering no tap. A document the server cannot render lists its highlights with neither.
    @Test func aDocumentsHighlightsAreStaleByTheKitsRule() async throws {
        let fixture = try await UserDataFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        let (model, _) = try await Self.page(fixture)
        let current = ASTToRenderNodeConverter.renderingVersion(for: model)
        try fixture.rows.addHighlight("A0000000-0000-0000-0000-000000000000", renderingVersion: current, createdAt: "2026-01-02T00:00:00.000Z")
        try fixture.rows.addHighlight("B0000000-0000-0000-0000-000000000000", renderingVersion: "0000000000000000", createdAt: "2026-01-01T00:00:00.000Z")
        try fixture.rows.addHighlight("C0000000-0000-0000-0000-000000000000", renderingVersion: "", createdAt: nil)
        try fixture.rows.addHighlight("D0000000-0000-0000-0000-000000000000", volumeId: "frus1894Nicaragua", documentId: "d1")
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let listed = try decode(DocumentHighlights.self, try await browser.get(Self.d1))
            #expect(listed.renderingVersion == current)
            #expect(listed.items.map(\.id) == ["C0000000-0000-0000-0000-000000000000", "B0000000-0000-0000-0000-000000000000",
                                               "A0000000-0000-0000-0000-000000000000"], "the reader's order, no time first")
            #expect(listed.items.map(\.isStale) == [true, true, false])
            #expect(listed.items[0].createdAt == nil)
            // Nicaragua's TEI is not in this server's folder.
            let elsewhere = try decode(DocumentHighlights.self, try await browser.get("/api/v1/me/volumes/frus1894Nicaragua/documents/d1/highlights"))
            #expect(elsewhere.renderingVersion == nil && elsewhere.items.map(\.id) == ["D0000000-0000-0000-0000-000000000000"])
            #expect(elsewhere.items[0].isStale == nil)
            let unknown = try decode(DocumentHighlights.self, try await browser.get("/api/v1/me/volumes/frus1961-63v06/documents/d9999/highlights"))
            #expect(unknown.renderingVersion == nil && unknown.items.isEmpty)
        }
    }

    /// Another colour, the web's own, keeps everything else; Remove deletes the one asked about.
    @Test func aHighlightTakesAnotherColourAndIsRemoved() async throws {
        let fixture = try await UserDataFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let version = try await Self.pageVersion(browser)
            let made = try decode(Highlight.self, try await browser.send(.post, Self.d1, Self.body(0, 9, "yellow", version)))
            let recolouring = try await browser.send(.patch, "/api/v1/me/highlights/\(made.id)", #"{"colorTag": "green"}"#)
            #expect(recolouring.status == .ok)
            var green = made
            green.colorTag = "green"
            #expect(try decode(Highlight.self, recolouring) == green)
            #expect(try decode(DocumentHighlights.self, try await browser.get(Self.d1)).items.map(\.colorTag) == ["green"])
            let removed = try await browser.send(.delete, "/api/v1/me/highlights/\(made.id)")
            #expect(removed.status == .noContent && removed.body.readableBytes == 0)
            for response in [try await browser.get("/api/v1/me/highlights/\(made.id)"),
                             try await browser.send(.delete, "/api/v1/me/highlights/\(made.id)"),
                             try await browser.send(.patch, "/api/v1/me/highlights/\(made.id)", #"{"colorTag": "pink"}"#),
                             try await browser.get("/api/v1/me/highlights/not-a-uuid")] {
                #expect(response.status == .notFound && problemCode(response) == "HIGHLIGHT_NOT_FOUND")
            }
            #expect(try decode(DocumentHighlights.self, try await browser.get(Self.d1)).items.isEmpty)
        }
    }

    /// What the app's reader could not send is refused, and nothing is stored: a colour it has not,
    /// offsets outside the page's text, a body that is not the route's, and offsets taken from a
    /// page whose text has since changed.
    @Test func aHighlightTheReaderCouldNotMakeIsRefused() async throws {
        let fixture = try await UserDataFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        let (_, flat) = try await Self.page(fixture)
        let length = flat.utf16.count
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let version = try await Self.pageVersion(browser)
            func refused(_ json: String, _ code: String, _ status: HTTPResponse.Status = .badRequest,
                         path: String = Self.d1, sourceLocation: SourceLocation = #_sourceLocation) async throws {
                let response = try await browser.send(.post, path, json)
                #expect(response.status == status && problemCode(response) == code, "\(json): \(String(buffer: response.body))",
                        sourceLocation: sourceLocation)
            }
            try await refused(Self.body(0, 5, "teal", version), "INVALID_FIELD")
            try await refused(Self.body(-1, 5, "yellow", version), "INVALID_FIELD")
            try await refused(Self.body(5, 5, "yellow", version), "INVALID_FIELD")
            try await refused(Self.body(9, 5, "yellow", version), "INVALID_FIELD")
            try await refused(Self.body(0, length + 1, "yellow", version), "INVALID_FIELD")
            try await refused(#"{"startOffset": 5.5, "endOffset": 9, "colorTag": "yellow", "renderingVersion": "\#(version)"}"#, "INVALID_FIELD")
            try await refused(#"{"startOffset": 1e30, "endOffset": 9, "colorTag": "yellow", "renderingVersion": "\#(version)"}"#, "INVALID_FIELD")
            try await refused(#"{"startOffset": "0", "endOffset": 9, "colorTag": "yellow", "renderingVersion": "\#(version)"}"#, "INVALID_FIELD")
            try await refused(#"{"startOffset": 0, "endOffset": 9, "colorTag": "yellow"}"#, "INVALID_FIELD")
            try await refused(#"{"startOffset": 0, "endOffset": 9, "colorTag": "yellow", "renderingVersion": "\#(version)", "selectedText": "x"}"#,
                              "UNKNOWN_FIELD")
            try await refused(Self.body(0, 9, "yellow", "0123456789abcdef"), "DOCUMENT_CHANGED", .conflict)
            try await refused(Self.body(0, 9, "yellow", version), "VOLUME_NOT_FOUND", .notFound,
                              path: "/api/v1/me/volumes/frus9999v99/documents/d1/highlights")
            try await refused(Self.body(0, 9, "yellow", version), "DOCUMENT_NOT_FOUND", .notFound,
                              path: "/api/v1/me/volumes/frus1961-63v06/documents/d9999/highlights")
            try await refused(Self.body(0, 9, "yellow", version), "TEI_NOT_AVAILABLE", .notFound,
                              path: "/api/v1/me/volumes/frus1894Nicaragua/documents/d1/highlights")
            let ends = try decode(Highlight.self, try await browser.send(.post, Self.d1, Self.body(length - 3, length, "yellow", version)))
            #expect(ends.endOffset == length, "a highlight may end where the text does")
            let recolour = try await browser.send(.patch, "/api/v1/me/highlights/\(ends.id)", #"{"colorTag": "Yellow"}"#)
            #expect(recolour.status == .badRequest && problemCode(recolour) == "INVALID_FIELD")
            let unknown = try await browser.send(.patch, "/api/v1/me/highlights/\(ends.id)", #"{"colorTag": "pink", "noteId": null}"#)
            #expect(unknown.status == .badRequest && problemCode(unknown) == "UNKNOWN_FIELD")
            let tokenless = try await browser.send(.post, Self.d1, Self.body(0, 9, "yellow", version), token: "")
            #expect(tokenless.status == .forbidden && problemCode(tokenless) == "CSRF_TOKEN_INVALID")
        }
        #expect(try fixture.rows.highlightCount() == 1)
        #expect(try fixture.store.highlights(for: "owner").first?.colorTag == "yellow")
    }

    @Test func eachUsersHighlightsAreTheirsAlone() async throws {
        let fixture = try await UserDataFixture(volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addUser("reader")
        try fixture.rows.addHighlight("A0000000-0000-0000-0000-000000000000", user: "reader")
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            #expect(try decode(DocumentHighlights.self, try await browser.get(Self.d1)).items.isEmpty)
            #expect(try decode(HighlightList.self, try await browser.get("/api/v1/me/highlights")).total == 0)
            for response in [try await browser.get("/api/v1/me/highlights/A0000000-0000-0000-0000-000000000000"),
                             try await browser.send(.patch, "/api/v1/me/highlights/A0000000-0000-0000-0000-000000000000", #"{"colorTag": "pink"}"#),
                             try await browser.send(.delete, "/api/v1/me/highlights/A0000000-0000-0000-0000-000000000000")] {
                #expect(problemCode(response) == "HIGHLIGHT_NOT_FOUND")
            }
        }
        #expect(try fixture.rows.highlightCount(user: "reader") == 1)
    }

    @Test func highlightsAreRefusedWhileUserDataIsOffAndAnswerUnderThePath() async throws {
        let off = try await UserDataFixture(userData: false, volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(off) {} }
        try await off.app.test(.router) { client in
            let browser = Browser(client: client)
            #expect(problemCode(try await browser.get(Self.d1)) == "USER_DATA_OFF")
            #expect(problemCode(try await browser.get("/api/v1/me/highlights")) == "USER_DATA_OFF")
            let version = try await Self.pageVersion(browser)
            #expect(problemCode(try await browser.send(.post, Self.d1, Self.body(0, 9, "yellow", version))) == "USER_DATA_OFF")
        }
        let under = try await UserDataFixture(publicURL: "http://localhost:8080/frus-explorer/", volumes: ["frus1961-63v06"])
        defer { withExtendedLifetime(under) {} }
        try await under.app.test(.router) { client in
            let browser = Browser(client: client, base: "/frus-explorer")
            let version = try await Self.pageVersion(browser)
            let made = try await browser.send(.post, Self.d1, Self.body(0, 9, "yellow", version))
            let highlight = try decode(Highlight.self, made)
            #expect(made.headers[.location] == "/frus-explorer/api/v1/me/highlights/\(highlight.id)")
            let missing = try await browser.get("/api/v1/me/highlights/\(UUID().uuidString)")
            #expect(try decode(APIProblem.Body.self, missing).instance.hasPrefix("/frus-explorer/api/v1/me/highlights/"))
        }
    }
}
