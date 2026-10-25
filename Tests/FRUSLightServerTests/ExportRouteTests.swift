// GET /api/v1/me/export and GET /api/v1/me/export/contents through the router (PLAN's S16d): the
// user's research as the kit's envelope at its format version, written by the kit's encoder, with the
// web's one key more, saved as the app's file; the summaries only with the app's switch; the header's
// project the one named; the counts of what an export carries; a row the export cannot write refused
// by name; and the guard's rules. FRUSParityTests holds every type's round trip to the kit.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct ExportRouteTests {
    static let path = "/api/v1/me/export"

    /// The envelope's keys, as the kit's `CodingKeys` spell them, beside which the web adds its one.
    static let envelopeKeys: Set<String> = [
        "formatVersion", "exportedAt", "exportedForProjectName", "exportedForProjectResearchQuestion", "notes", "tags",
        "tagAssignments", "highlights", "collections", "prompts", "projects", "summaries", "readingHistory", "searchHistory",
        "exportHistory", "archiveVisits", "savedSearches", "workingCorpora", "customVolumeScopes", "classificationOverrides",
        "personClusterOverrides", "annotationReviews", "projectLeads", "syncedPreferences",
    ]

    /// The store, with ImportRouteTests' export imported into it.
    static func imported() async throws -> UserDataFixture {
        let fixture = try await UserDataFixture()
        let envelope = try MacImport.envelope(of: Data(try ImportRouteTests.export().utf8))
        _ = try MacImport.run(envelope, into: fixture.store, for: "owner", includingInstanceWide: true)
        return fixture
    }

    static func object(_ response: TestResponse) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(buffer: response.body)) as? [String: Any])
    }

    /// The web's key in a file.
    static func key(_ file: Data) throws -> WebExportKey {
        struct File: Decodable { let frusExplorerLight: WebExportKey }
        return try JSONDecoder().decode(File.self, from: file).frusExplorerLight
    }

    static func key(_ response: TestResponse) throws -> WebExportKey { try key(Data(buffer: response.body)) }

    /// The done-when's file: the kit's envelope at its version, which its decoder reads, written by its
    /// encoder, with the web's key beside it, saved as the app names the file.
    @Test func anExportIsTheKitsEnvelopeWithTheWebsOneKey() async throws {
        let fixture = try await Self.imported()
        defer { withExtendedLifetime(fixture) {} }
        let file = try MacImport.envelope(of: Data(try ImportRouteTests.export().utf8))
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let response = try await browser.get(Self.path)
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "application/json")
            #expect(response.headers[.contentDisposition] == #"attachment; filename="frus-research-export.json""#)
            #expect(response.headers[.cacheControl] == "no-store")
            let object = try Self.object(response)
            #expect(Set(object.keys) == Self.envelopeKeys.subtracting(["exportedForProjectName", "exportedForProjectResearchQuestion"])
                .union(["frusExplorerLight"]), "no header project, as in the Mac's Global Context")
            #expect(try Self.key(response) == WebExportKey(includesGeneratedSummaries: false, includesCorrections: true))
            #expect(try Self.key(response).formatVersion == 1)

            let exported = try MacImport.envelope(of: Data(buffer: response.body))
            #expect(exported.formatVersion == ResearchDataEnvelope.currentFormatVersion)
            #expect(exported.exportedAt == UserDataFixture.now, "when it was made, at the kit's whole seconds")
            #expect(exported.notes == file.notes && exported.highlights == file.highlights && exported.tags == file.tags)
            #expect(exported.tagAssignments == file.tagAssignments && exported.prompts == file.prompts)
            #expect(exported.projects == file.projects && exported.classificationOverrides == file.classificationOverrides)
            #expect(exported.summaries.isEmpty, "Include AI-Generated Summaries is off unless asked, as the app's switch")
            #expect(try Data(buffer: response.body) == ResearchExport.file(exported, .init(
                includeGeneratedSummaries: false, includingInstanceWide: true, exportedAt: UserDataFixture.now)),
                    "the kit's encoder: pretty-printed, keys sorted, ISO 8601 dates")

            // The switch on: every summary, the headnote draft among them, and the key says so.
            let all = try await browser.get(Self.path + "?includeGeneratedSummaries=true")
            #expect(try MacImport.envelope(of: Data(buffer: all.body)).summaries == file.summaries)
            #expect(try Self.key(all).includesGeneratedSummaries)

            // The project the export is made under heads it; an id that names none heads it with none.
            let headed = try MacImport.envelope(of: Data(buffer: try await browser.get(
                Self.path + "?projectId=\(ImportRouteTests.id(40).uuidString.lowercased())").body))
            #expect(headed.exportedForProjectName == "Bay of Pigs review" && headed.exportedForProjectResearchQuestion == nil)
            let unheaded = try await browser.get(Self.path + "?projectId=\(ImportRouteTests.id(41).uuidString)")
            #expect(try unheaded.status == .ok && Set(Self.object(unheaded).keys).isDisjoint(with: ["exportedForProjectName"]))

            for (query, code) in [("projectId=40", "INVALID_PARAMETER"), ("includeGeneratedSummaries=yes", "INVALID_PARAMETER"),
                                  ("includeGeneratedSummaries=true&includeGeneratedSummaries=false", "INVALID_PARAMETER"),
                                  ("summaries=true", "UNKNOWN_PARAMETER")] {
                let refused = try await browser.get(Self.path + "?" + query)
                #expect(refused.status == .badRequest && problemCode(refused) == code, "\(query)")
            }
        }
    }

    /// Contents: what an export carries of each of the 23 types, in the store's order, the summaries
    /// as with the switch on, the researcher's own prompts.
    @Test func contentsCountWhatAnExportCarriesOfEachType() async throws {
        let fixture = try await Self.imported()
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.run("""
            INSERT INTO prompts (user_id, id, name, prompt_text, response_format, is_standard)
                VALUES ('owner', '5E16D000-0000-4000-8000-000000000081', 'Standard', 'Summarize', '{"general":{}}', 1)
            """)
        try await fixture.app.test(.router) { client in
            let response = try await Browser(client: client).get(Self.path + "/contents")
            #expect(response.status == .ok && response.headers[.cacheControl] == "no-store")
            let contents = try decode(ExportContents.self, response)
            #expect(contents.formatVersion == 7)
            #expect(contents.types.map(\.type) == UserStoreSchema.tables.map(\.model))
            let counts = Dictionary(uniqueKeysWithValues: contents.types.map { ($0.type, $0.count) })
            #expect(counts["ResearchNote"] == 1 && counts["DocumentHighlight"] == 1 && counts["UserTag"] == 1)
            #expect(counts["DocumentTagAssignment"] == 1 && counts["Project"] == 1 && counts["GeneratedSummary"] == 2)
            #expect(counts["SummarizationPrompt"] == 1, "the researcher's own, never a standard one")
            #expect(counts["DocumentClassificationOverride"] == 1, "the single user is a curator")
            #expect(counts.values.reduce(0, +) == 9)
            let unknown = try await Browser(client: client).get(Self.path + "/contents?x=1")
            #expect(unknown.status == .badRequest && problemCode(unknown) == "UNKNOWN_PARAMETER")
        }
    }

    /// The instance's corrections are a curator's to carry, as a curator's to import.
    @Test func anExportCarriesTheInstancesCorrectionsForACuratorOnly() async throws {
        let fixture = try await Self.imported()
        defer { withExtendedLifetime(fixture) {} }
        let options = ResearchExport.Options(includeGeneratedSummaries: true, includingInstanceWide: false,
                                             exportedAt: UserDataFixture.now)
        let data = try ResearchExport.file(from: fixture.store, for: "owner", options)
        let envelope = try MacImport.envelope(of: data)
        #expect(envelope.classificationOverrides.isEmpty && envelope.notes.count == 1 && envelope.summaries.count == 2)
        #expect(try Self.key(data) == WebExportKey(includesGeneratedSummaries: true, includesCorrections: false))
        #expect(ResearchExport.tables(options).count == 21, "every user table, no instance one")
    }

    /// What the web writes, a formatted note, a highlight linked to it and the reader's own summary,
    /// comes out as the app's records, the RTF as stored.
    @Test func whatTheWebWritesIsExportedAsTheAppsRecords() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addHighlight("5E16D000-0000-4000-8000-000000000010", documentId: "d1", selectedText: "a text",
                                      renderingVersion: "0123456789abcdef")
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let made = try await browser.send(.post, "/api/v1/me/volumes/frus1961-63v06/documents/d1/notes", #"""
                {"bodyText": "A bold note.", "runs": [{"text": "A ", "bold": false, "italic": false, "underline": false},
                          {"text": "bold", "bold": true, "italic": false, "underline": false},
                          {"text": " note.", "bold": false, "italic": false, "underline": false}],
                 "projectIds": [], "userTagIds": [], "selectedSummaryIds": [],
                 "linkedHighlightId": "5E16D000-0000-4000-8000-000000000010"}
                """#)
            #expect(made.status == .created, "\(String(buffer: made.body))")
            let note = try decode(Note.self, made)
            let own = try await browser.send(.post, "/api/v1/me/volumes/frus1961-63v06/documents/d1/summaries",
                                             #"{"responseText": "My own summary."}"#)
            #expect(own.status == .created)
            let exported = try MacImport.envelope(of: Data(buffer: try await browser.get(Self.path + "?includeGeneratedSummaries=true").body))
            let stored = try #require(try fixture.rows.storedNote(note.id))
            #expect(exported.notes.map(\.id.uuidString) == [note.id])
            #expect(exported.notes.first?.richText == stored.richText.map { Data($0) } && stored.richText != nil)
            #expect(exported.notes.first?.linkedHighlightIds.map(\.uuidString) == ["5E16D000-0000-4000-8000-000000000010"])
            #expect(exported.notes.first?.createdAt == UserDataFixture.now)
            let summary = try #require(exported.summaries.first)
            #expect(summary.promptId.uuidString == OwnSummary.promptId && summary.authorship == .userWritten)
            #expect(summary.isHeadnoteDraft == false && summary.responseFormat == .general && summary.responseText == "My own summary.")
        }
    }

    /// A row the export cannot write as the kit's record, which only a damaged store holds, refuses
    /// the export by its table, row and column, never what it holds; no part of a file is sent.
    @Test func aRowTheExportCannotWriteIsNamed() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addNote("5E16D000-0000-4000-8000-000000000001", projectIds: ["Not an id"])
        try await fixture.app.test(.router) { client in
            let response = try await Browser(client: client).get(Self.path)
            #expect(response.status == .internalServerError && problemCode(response) == "EXPORT_FAILED")
            let detail = try decode(APIProblem.Body.self, response).detail
            #expect(detail.contains("5E16D000-0000-4000-8000-000000000001") && detail.contains("notes") && detail.contains("project_ids"))
            #expect(!detail.contains("Not an id"))
        }
    }

    /// The guard holds the export as it holds every read of a user's data; under a path it answers
    /// under it.
    @Test func anExportIsGuardedAsEveryReadOfTheUsersDataIs() async throws {
        let off = try await UserDataFixture(userData: false)
        defer { withExtendedLifetime(off) {} }
        try await off.app.test(.router) { client in
            for path in [Self.path, Self.path + "/contents"] {
                let response = try await Browser(client: client).get(path)
                #expect(response.status == .forbidden && problemCode(response) == "USER_DATA_OFF", "\(path)")
            }
        }
        // A server whose address is another host: the test client sends `Host: localhost`.
        let elsewhere = try await UserDataFixture(publicURL: "https://frus.example.org")
        defer { withExtendedLifetime(elsewhere) {} }
        try await elsewhere.app.test(.router) { client in
            for path in [Self.path, Self.path + "/contents"] {
                let refused = try await client.execute(uri: path, method: .get)
                #expect(refused.status == .forbidden && problemCode(refused) == "HOST_NOT_ALLOWED", "\(path)")
            }
        }
        let under = try await UserDataFixture(publicURL: "http://localhost:8080/frus-explorer/")
        defer { withExtendedLifetime(under) {} }
        try await under.app.test(.router) { client in
            let browser = Browser(client: client, base: "/frus-explorer")
            let response = try await browser.get(Self.path)
            #expect(try response.status == .ok && MacImport.envelope(of: Data(buffer: response.body)).notes.isEmpty)
            #expect(try decode(ExportContents.self, try await browser.get(Self.path + "/contents")).types.count == 23)
        }
    }
}
