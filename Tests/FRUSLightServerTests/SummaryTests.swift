// /api/v1/me/summaries and a document's summaries through the router (PLAN's S15d): the reader's own
// summary, the web's own, is written, read, edited and deleted, stored with the web's prompt id and the
// kit's `ResponseFormat.general` as its encoder writes it; a document's are listed newest first by the
// app's `ranksAbove`, headnote drafts left out, each with its authorship read as the app reads it and
// its prompt named only while the user has it; a draft is found by its id and says it is one; and
// every summary the reader did not write here is read-only, an imported user-written headnote draft
// among them.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct SummaryTests {
    static let d1 = "/api/v1/me/volumes/frus1961-63v06/documents/d1/summaries"

    static func summary(_ id: String) -> String { "/api/v1/me/summaries/\(id)" }

    @Test func aReadersOwnSummaryIsWrittenEditedAndDeleted() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let made = try await browser.send(.post, Self.d1, #"{"responseText": "My summary.\n\nTwo paragraphs."}"#)
            #expect(made.status == .created)
            let summary = try decode(Summary.self, made)
            #expect(made.headers[.location] == "/api/v1/me/summaries/\(summary.id)")
            #expect(UUID(uuidString: summary.id)?.uuidString == summary.id)
            #expect(summary.volumeId == "frus1961-63v06" && summary.documentId == "d1")
            #expect(summary.promptId == "0EB00000-0000-4000-8000-000000000001" && summary.promptName == nil)
            #expect(summary.responseText == "My summary.\n\nTwo paragraphs." && summary.responseFormat == "general")
            #expect(!summary.wasChunked && summary.authorship == "userWritten" && summary.projectId == nil && summary.editable)
            #expect(!summary.isHeadnoteDraft)
            #expect(summary.createdAt == "2026-10-24T00:00:00.000Z" && summary.lastModified == summary.createdAt)
            // Stored as the app's own rows are: the kit's encoding of `.general`, not a literal of it.
            let stored = try #require(try fixture.rows.storedSummary(summary.id))
            let general = String(decoding: try JSONEncoder().encode(ResponseFormat.general), as: UTF8.self)
            #expect(general == #"{"general":{}}"# && stored["response_format"] == general)
            #expect(stored["authorship"] == SummaryAuthorship.userWritten.rawValue && stored["is_headnote_draft"] == "0")
            #expect(stored["was_chunked"] == "0" && stored["project_id"] == .some(nil) && stored["source_content_hash"] == .some(nil))
            // Every field written, a prompt's name, a project and a time with none as null.
            let raw = try #require(try JSONSerialization.jsonObject(with: Data(buffer: made.body)) as? [String: Any])
            #expect(raw["promptName"] is NSNull && raw["projectId"] is NSNull && raw.count == 14)
            #expect(raw["isHeadnoteDraft"] as? Bool == false, "the draft flag is written, false too")

            #expect(try decode(Summary.self, try await browser.get(Self.summary(summary.id.lowercased()))) == summary)
            #expect(try decode(DocumentSummaries.self, try await browser.get(Self.d1)) ==
                DocumentSummaries(volumeId: "frus1961-63v06", documentId: "d1", items: [summary]))
            let editing = try await browser.send(.put, Self.summary(summary.id), #"{"responseText": "Edited."}"#)
            #expect(editing.status == .ok)
            var edited = summary
            edited.responseText = "Edited."
            #expect(try decode(Summary.self, editing) == edited, "the fixture's clock stands still")
            let deleted = try await browser.send(.delete, Self.summary(summary.id))
            #expect(deleted.status == .noContent && deleted.body.readableBytes == 0)
            for response in [try await browser.get(Self.summary(summary.id)), try await browser.send(.delete, Self.summary(summary.id)),
                             try await browser.send(.put, Self.summary(summary.id), #"{"responseText": "x"}"#),
                             try await browser.get(Self.summary("not-a-uuid"))] {
                #expect(response.status == .notFound && problemCode(response) == "SUMMARY_NOT_FOUND")
            }
            #expect(try decode(DocumentSummaries.self, try await browser.get(Self.d1)).items.isEmpty)
        }
    }

    /// Imported summaries as the rail shows them: newest first by `ranksAbove`, drafts left out,
    /// uncapped; nil authorship read as `aiGenerated`; a prompt named only while the user has it;
    /// each format by the kit's `ResponseFormat`, the text as stored; and none of them editable.
    @Test func aDocumentsSummariesAreListedAsTheRailShowsThem() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        let named = "AA000000-0000-4000-8000-000000000001"
        try fixture.rows.addPrompt(named.lowercased(), name: "Meeting Record")
        let structured = #"{"structured":{"schema":{"fields":[{"description":"Who","name":"People"}]}}}"#
        try fixture.rows.addSummary("10000000-0000-4000-8000-000000000001", promptId: named, responseText: "Named.",
                                    createdAt: "2026-05-01T00:00:00.000Z")
        try fixture.rows.addSummary("20000000-0000-4000-8000-000000000002", promptId: "BB000000-0000-4000-8000-000000000002",
                                    responseText: #"{"People":"Kennedy"}"#, responseFormat: structured, wasChunked: true,
                                    authorship: nil, projectId: "cc000000-0000-4000-8000-000000000003",
                                    createdAt: "2026-04-01T00:00:00.000Z")
        try fixture.rows.addSummary("30000000-0000-4000-8000-000000000003", promptId: "DD000000-0000-4000-8000-000000000004",
                                    responseText: "Edited AI.", responseFormat: "not json",
                                    authorship: "aiEdited", createdAt: nil)
        try fixture.rows.addSummary("40000000-0000-4000-8000-000000000004", promptId: "0EAD0000-0000-4000-8000-000000000001",
                                    responseText: "A headnote, imported from an older file.", authorship: "userWritten",
                                    createdAt: "2026-06-01T00:00:00.000Z")
        try fixture.rows.addSummary("50000000-0000-4000-8000-000000000005", promptId: "0EAD0000-0000-4000-8000-000000000001",
                                    responseText: "A collection's draft.", authorship: "userWritten", isHeadnoteDraft: true,
                                    createdAt: "2027-01-01T00:00:00.000Z")
        for index in 0..<21 {
            try fixture.rows.addSummary(String(format: "6%07d-0000-4000-8000-000000000006", index), documentId: "d2",
                                        createdAt: String(format: "2026-01-%02dT00:00:00.000Z", index + 1))
        }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let listed = try decode(DocumentSummaries.self, try await browser.get(Self.d1))
            #expect(listed.items.map(\.id) == ["40000000-0000-4000-8000-000000000004", "10000000-0000-4000-8000-000000000001",
                                               "20000000-0000-4000-8000-000000000002", "30000000-0000-4000-8000-000000000003"])
            #expect(listed.items.map(\.promptName) == [nil, "Meeting Record", nil, nil])
            #expect(listed.items.map(\.authorship) == ["userWritten", "aiGenerated", "aiGenerated", "aiEdited"])
            #expect(listed.items.map(\.responseFormat) == ["general", "general", "structured", "unknown"])
            #expect(listed.items.map(\.wasChunked) == [false, false, true, false])
            #expect(listed.items[2].responseText == #"{"People":"Kennedy"}"# && listed.items[2].projectId == "CC000000-0000-4000-8000-000000000003")
            #expect(listed.items[3].createdAt == nil)
            #expect(listed.items.allSatisfy { !$0.editable }, "only the reader's own")
            #expect(listed.items.allSatisfy { !$0.isHeadnoteDraft }, "the imported headnote too, though it shares the draft's prompt")
            #expect(try decode(DocumentSummaries.self, try await browser.get("/api/v1/me/volumes/frus1961-63v06/documents/d2/summaries"))
                .items.count == 21, "uncapped: the rail shows 20")
            // A draft is found by its id, and says it is one, as nothing else it carries tells it
            // from the imported headnote: both have the app's headnote prompt.
            let draft = try decode(Summary.self, try await browser.get(Self.summary("50000000-0000-4000-8000-000000000005")))
            #expect(draft.isHeadnoteDraft && !draft.editable && draft.promptId == listed.items[0].promptId)
            let rawDraft = try #require(try JSONSerialization.jsonObject(
                with: Data(buffer: try await browser.get(Self.summary(draft.id)).body)) as? [String: Any])
            #expect(rawDraft["isHeadnoteDraft"] as? Bool == true)

            // Read-only: an imported user-written headnote with the app's headnote prompt, an AI
            // summary, one edited by the reader in the app, and a draft, each kept as it was added.
            for (id, text) in [("40000000-0000-4000-8000-000000000004", "A headnote, imported from an older file."),
                               ("10000000-0000-4000-8000-000000000001", "Named."),
                               ("30000000-0000-4000-8000-000000000003", "Edited AI."),
                               ("50000000-0000-4000-8000-000000000005", "A collection's draft.")] {
                for response in [try await browser.send(.put, Self.summary(id), #"{"responseText": "Mine now."}"#),
                                 try await browser.send(.delete, Self.summary(id))] {
                    #expect(response.status == .forbidden && problemCode(response) == "SUMMARY_READ_ONLY", "\(id)")
                }
                #expect(try #require(try fixture.rows.storedSummary(id), "\(id) is still stored")["response_text"] == .some(text))
            }
            // The reader's own comes first, as the newest.
            let mine = try decode(Summary.self, try await browser.send(.post, Self.d1, #"{"responseText": "Mine."}"#))
            #expect(try decode(DocumentSummaries.self, try await browser.get(Self.d1)).items.first == mine)
        }
    }

    @Test func aSummaryTheReaderCouldNotWriteIsRefused() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            for (json, code) in [(#"{"responseText": ""}"#, "INVALID_FIELD"), (#"{"responseText": " \n\t"}"#, "INVALID_FIELD"),
                                 (#"{"responseText": "a\u0000b"}"#, "INVALID_FIELD"), (#"{"responseText": 5}"#, "INVALID_FIELD"),
                                 ("{}", "INVALID_FIELD"), (#"{"responseText": "x", "authorship": "aiGenerated"}"#, "UNKNOWN_FIELD"),
                                 ("[1]", "INVALID_BODY")] {
                let refused = try await browser.send(.post, Self.d1, json)
                #expect(refused.status == .badRequest && problemCode(refused) == code, "\(json)")
            }
            let volume = try await browser.send(.post, "/api/v1/me/volumes/frus9999v99/documents/d1/summaries", #"{"responseText": "x"}"#)
            #expect(volume.status == .notFound && problemCode(volume) == "VOLUME_NOT_FOUND")
            let mine = try decode(Summary.self, try await browser.send(.post, Self.d1, #"{"responseText": "Mine."}"#))
            let empty = try await browser.send(.put, Self.summary(mine.id), #"{"responseText": "  "}"#)
            #expect(empty.status == .badRequest && problemCode(empty) == "INVALID_FIELD")
            let large = #"{"responseText": ""# + String(repeating: "x", count: 64 * 1_024) + #""}"#
            #expect(problemCode(try await browser.send(.put, Self.summary(mine.id), large)) == "CONTENT_TOO_LARGE", "64 KiB, as tags")
            #expect(try decode(Summary.self, try await browser.get(Self.summary(mine.id))) == mine, "unchanged")
        }
        #expect(try fixture.store.summaries(of: DocumentKey(volumeId: "frus1961-63v06", documentId: "d1"), for: "owner").count == 1)
    }

    @Test func eachUsersSummariesAreTheirsAloneAndAnswerUnderThePath() async throws {
        let fixture = try await UserDataFixture(publicURL: "http://localhost:8080/frus-explorer/")
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addUser("reader")
        try fixture.rows.addSummary("10000000-0000-4000-8000-000000000001", user: "reader", promptId: OwnSummary.promptId,
                                    authorship: "userWritten")
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client, base: "/frus-explorer")
            #expect(try decode(DocumentSummaries.self, try await browser.get(Self.d1)).items.isEmpty)
            for response in [try await browser.get(Self.summary("10000000-0000-4000-8000-000000000001")),
                             try await browser.send(.put, Self.summary("10000000-0000-4000-8000-000000000001"), #"{"responseText": "x"}"#),
                             try await browser.send(.delete, Self.summary("10000000-0000-4000-8000-000000000001"))] {
                #expect(problemCode(response) == "SUMMARY_NOT_FOUND")
            }
            let made = try await browser.send(.post, Self.d1, #"{"responseText": "Under the path."}"#)
            let summary = try decode(Summary.self, made)
            #expect(made.headers[.location] == "/frus-explorer/api/v1/me/summaries/\(summary.id)")
            let missing = try await browser.get(Self.summary(UUID().uuidString))
            #expect(try decode(APIProblem.Body.self, missing).instance.hasPrefix("/frus-explorer/api/v1/me/summaries/"))
        }
        #expect(try fixture.rows.storedSummary("10000000-0000-4000-8000-000000000001", user: "reader")?["response_text"] == "An AI summary.")
        let off = try await UserDataFixture(userData: false)
        defer { withExtendedLifetime(off) {} }
        try await off.app.test(.router) { client in
            let browser = Browser(client: client)
            for response in [try await browser.get(Self.d1), try await browser.get(Self.summary(UUID().uuidString)),
                             try await browser.send(.post, Self.d1, #"{"responseText": "x"}"#)] {
                #expect(response.status == .forbidden && problemCode(response) == "USER_DATA_OFF")
            }
        }
    }
}
