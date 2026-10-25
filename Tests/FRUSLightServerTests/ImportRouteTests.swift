// POST /api/v1/me/import and GET /api/v1/me/import/{id} through the router (PLAN's S16c): a Mac JSON
// export, sent as the body, is queued as a job, and its status gives the report once the job is done;
// a file that is not an export, or of a version the server does not read, is refused at once; one
// whose records do not decode fails its job and writes nothing; a user has one import at a time; the
// guard holds the route to the token, the origin, JSON and the import's own limit; and what came in
// reads through the user's routes. FRUSParityTests holds the import of every type to the kit.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct ImportRouteTests {
    static let path = "/api/v1/me/import"

    static func id(_ number: Int) -> UUID { UUID(uuidString: String(format: "5E16C000-0000-4000-8000-%012X", number))! }
    static func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    /// A small export of version 7: a note in a project, its tag, a highlight linked to it, two
    /// summaries, one of the researcher's prompts and a correction.
    static func export(noteText: String = "An imported note.") throws -> String {
        let envelope = ResearchDataEnvelope(
            formatVersion: 7, exportedAt: date("2026-10-24T20:00:00Z"),
            notes: [ResearchNoteExport(id: id(1), documentId: "d3", volumeId: "frus1961-63v06", bodyText: noteText,
                                       projectIds: [id(40)], userTagIds: [id(20)], selectedSummaryIds: [],
                                       linkedHighlightIds: [id(10)], createdAt: date("2026-03-01T10:00:00Z"),
                                       lastModified: date("2026-03-02T10:00:00Z"))],
            tags: [UserTagExport(id: id(20), name: "Cuba", createdAt: date("2026-02-01T00:00:00Z"))],
            tagAssignments: [DocumentTagAssignmentExport(id: id(30), volumeId: "frus1961-63v06", documentId: "d3", tagId: id(20))],
            highlights: [DocumentHighlightExport(id: id(10), volumeId: "frus1961-63v06", documentId: "d3", startOffset: 3,
                                                 endOffset: 9, colorTag: "green", noteId: id(1), selectedText: "a text",
                                                 renderingVersion: "0123456789abcdef", createdAt: date("2026-03-01T09:00:00Z"))],
            collections: [],
            prompts: [SummarizationPromptExport(id: id(80), name: "Cold War brief", promptText: "Brief {{DOCUMENT}}",
                                                responseFormat: .general)],
            projects: [ProjectExport(id: id(40), name: "Bay of Pigs review", defaultSubjectTagIds: [], defaultCountryTagIds: [],
                                     defaultUserTagIds: [])],
            summaries: [
                GeneratedSummaryExport(id: id(70), documentId: "d3", volumeId: "frus1961-63v06", promptId: id(80),
                                       responseText: "An AI summary.", responseFormat: .general, wasChunked: false,
                                       createdAt: date("2026-05-01T00:00:00Z"), authorship: .aiGenerated, isHeadnoteDraft: false),
                GeneratedSummaryExport(id: id(71), documentId: "d3", volumeId: "frus1961-63v06",
                                       promptId: UUID(uuidString: MacImport.headnoteDraftPromptId)!, responseText: "A headnote.",
                                       responseFormat: .general, wasChunked: false, createdAt: date("2026-05-02T00:00:00Z"),
                                       authorship: .userWritten, isHeadnoteDraft: true),
            ],
            classificationOverrides: [DocumentClassificationOverrideExport(
                id: id(150), volumeId: "frus1961-63v06", documentId: "d4", isEditorialNote: true, parsedIsEditorialNote: false,
                createdAt: date("2026-06-11T00:00:00Z"))])
        return String(decoding: try envelope.jsonData(), as: UTF8.self)
    }

    /// The import's status, once the job queued before it and the import itself are done.
    static func finished(_ browser: Browser, _ fixture: UserDataFixture, _ location: String) async throws -> ImportStatus {
        await fixture.jobs.waitUntilIdle()
        return try decode(ImportStatus.self, try await browser.get(location))
    }

    /// The route queues the import as a job, answers where its status is, and the status gives the
    /// report once the job is done; meanwhile another of the user's imports is refused.
    @Test func anExportIsImportedAsAJobWhoseStatusGivesItsReport() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        // Held behind a job queued first, so the import is seen waiting.
        let (gate, open) = AsyncStream<Void>.makeStream()
        _ = await fixture.jobs.submit("held") { for await _ in gate {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let posted = try await browser.send(.post, Self.path, try Self.export())
            let queued = try decode(ImportStatus.self, posted)
            let location = "/api/v1/me/import/\(queued.id)"
            #expect(posted.status == .accepted && posted.headers[.location] == location)
            #expect(UUID(uuidString: queued.id)?.uuidString == queued.id, "an id of its own, which a restart never gives again")
            #expect(posted.headers[.cacheControl] == "no-store")
            #expect(queued == ImportStatus(id: queued.id, state: .queued, formatVersion: 7, report: nil, problem: nil))
            let raw = try #require(try JSONSerialization.jsonObject(with: Data(buffer: posted.body)) as? [String: Any])
            #expect(Set(raw.keys) == ["id", "state", "formatVersion", "report", "problem"], "a report and a problem with none as null")
            #expect(try decode(ImportStatus.self, try await browser.get(location)) == queued)
            #expect(try decode(ImportStatus.self, try await browser.get("/api/v1/me/import/\(queued.id.lowercased())")) == queued,
                    "its id in any case")
            let second = try await browser.send(.post, Self.path, try Self.export())
            #expect(second.status == .conflict && problemCode(second) == "IMPORT_IN_PROGRESS")
            open.finish()

            let done = try await Self.finished(browser, fixture, location)
            #expect(done.state == .succeeded && done.problem == nil)
            let report = try #require(done.report)
            #expect(report.formatVersion == 7 && report.exportedAt == "2026-10-24T20:00:00.000Z")
            #expect(report.types.count == 23 && report.types.allSatisfy(\.carried))
            let counts = Dictionary(uniqueKeysWithValues: report.types.map { ($0.type, ($0.inFile, $0.added)) })
            #expect(counts["ResearchNote"]! == (1, 1) && counts["DocumentHighlight"]! == (1, 1) && counts["UserTag"]! == (1, 1))
            #expect(counts["GeneratedSummary"]! == (2, 2) && counts["SummarizationPrompt"]! == (1, 1))
            #expect(counts["DocumentClassificationOverride"]! == (1, 1), "the single user is a curator")
            #expect(counts["SavedSearch"]! == (0, 0))
            #expect(report.headnoteDrafts == 1 && report.searchableDocuments == 1 && report.unlinkedCollections.isEmpty)

            // What came in, as the user's routes read it.
            let note = try decode(Note.self, try await browser.get("/api/v1/me/notes/\(Self.id(1).uuidString)"))
            #expect(note.bodyText == "An imported note." && note.projectIds == [Self.id(40).uuidString])
            #expect(note.linkedHighlightIds == [Self.id(10).uuidString] && note.lastModified == "2026-03-02T10:00:00.000Z")
            let highlight = try #require(try fixture.store.highlight(Self.id(10).uuidString, of: "owner"))
            #expect(highlight.startOffset == 3 && highlight.endOffset == 9 && highlight.selectedText == "a text"
                    && highlight.renderingVersion == "0123456789abcdef", "kept verbatim")
            let summaries = try decode(DocumentSummaries.self,
                                       try await browser.get("/api/v1/me/volumes/frus1961-63v06/documents/d3/summaries"))
            #expect(summaries.items.map(\.id) == [Self.id(70).uuidString] && summaries.items[0].promptName == "Cold War brief")
            #expect(!summaries.items[0].editable)
            #expect(try decode(ProjectList.self, try await browser.get("/api/v1/me/projects")).items.map(\.name) == ["Bay of Pigs review"])
            #expect(try fixture.store.classificationOverrides().map(\.id) == [Self.id(150).uuidString])

            // The same file again: every record kept, with a new status of its own.
            let again = try await browser.send(.post, Self.path, try Self.export())
            let next = try #require(again.headers[.location])
            #expect(next != location && next.hasPrefix("/api/v1/me/import/"))
            let kept = try #require(try await Self.finished(browser, fixture, next).report)
            #expect(kept.types.allSatisfy { $0.kept == $0.inFile && $0.added == 0 && $0.repeated == 0 })
            for missing in ["/api/v1/me/import/\(UUID().uuidString)", "/api/v1/me/import/x", "/api/v1/me/import/1"] {
                let response = try await browser.get(missing)
                #expect(response.status == .notFound && problemCode(response) == "IMPORT_NOT_FOUND", "\(missing)")
            }
            let unknown = try await browser.get("\(location)?x=1")
            #expect(problemCode(unknown) == "UNKNOWN_PARAMETER")
        }
    }

    /// A file that is not an export, or of a format version the kit does not read, is refused before
    /// any job is queued.
    @Test func aFileThatIsNotAnExportIsRefusedAtOnce() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            for (body, code) in [("not json", "INVALID_EXPORT"), ("[7]", "INVALID_EXPORT"), (#"{"notes": []}"#, "INVALID_EXPORT"),
                                 (#"{"formatVersion": "7"}"#, "INVALID_EXPORT"), (#"{"formatVersion": 6.5}"#, "INVALID_EXPORT"),
                                 (#"{"formatVersion": 0}"#, "INVALID_EXPORT"), (#"{"formatVersion": 8}"#, "UNSUPPORTED_FORMAT_VERSION")] {
                let refused = try await browser.send(.post, Self.path, body)
                #expect(refused.status == .badRequest && problemCode(refused) == code, "\(body)")
            }
            let newer = try decode(APIProblem.Body.self, try await browser.send(.post, Self.path, #"{"formatVersion": 8}"#))
            #expect(newer.detail == "This export is format version 8, and this server reads versions 1 to 7. Update the server, then import it again.")
            let bodiless = try await browser.send(.post, Self.path)
            #expect(problemCode(bodiless) == "INVALID_EXPORT")
            #expect(try await browser.get("/api/v1/me/import/1").status == .notFound, "nothing queued")
        }
    }

    /// An export whose records do not decode fails its job, which says where, and writes nothing.
    @Test func anExportWhoseRecordsDoNotDecodeFailsItsJob() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let broken = try Self.export().replacingOccurrences(of: #""bodyText" : "An imported note.""#, with: #""bodyText" : 7"#)
            let posted = try await browser.send(.post, Self.path, broken)
            #expect(posted.status == .accepted)
            let failed = try await Self.finished(browser, fixture, try #require(posted.headers[.location]))
            #expect(failed.state == .failed && failed.report == nil && failed.problem?.code == "INVALID_EXPORT")
            #expect(failed.problem?.detail.hasPrefix("This export could not be read: notes[0].bodyText: ") == true,
                    "\(failed.problem?.detail ?? "")")
            #expect(try fixture.store.tags(of: "owner").isEmpty && fixture.store.notes(for: "owner").isEmpty)
            // A missing key: the tolerant decoder requires the arrays every version has.
            let missing = try await browser.send(.post, Self.path, #"{"formatVersion": 2, "exportedAt": "2026-10-24T00:00:00Z"}"#)
            let status = try await Self.finished(browser, fixture, try #require(missing.headers[.location]))
            #expect(status.problem?.detail == "This export could not be read: notes is missing.")
        }
    }

    /// The import's body is JSON, of the import's own limit, sent with the token from the server's
    /// own address, as every change is.
    @Test func theImportIsGuardedAsEveryChangeIsWithALimitOfItsOwn() async throws {
        let limit = 64 * 1_024
        let fixture = try await UserDataFixture(importLimit: limit)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let export = try Self.export()
            let plain = try await browser.send(.post, Self.path, export, contentType: "text/plain")
            #expect(plain.status == .unsupportedMediaType && problemCode(plain) == "UNSUPPORTED_MEDIA_TYPE")
            let elsewhere = try await Browser(client: client, origin: "https://attacker.example").send(.post, Self.path, export)
            #expect(problemCode(elsewhere) == "ORIGIN_NOT_ALLOWED")
            let tokenless = try await browser.send(.post, Self.path, export, token: "0")
            #expect(problemCode(tokenless) == "CSRF_TOKEN_INVALID")
            let tooLarge = try await browser.send(.post, Self.path, export + String(repeating: " ", count: limit + 1 - export.utf8.count))
            #expect(tooLarge.status == .contentTooLarge && problemCode(tooLarge) == "CONTENT_TOO_LARGE")
            #expect(try decode(APIProblem.Body.self, tooLarge).detail == "A change's body here may be at most 64 KiB.")
            let full = try await browser.send(.post, Self.path, export + String(repeating: " ", count: limit - export.utf8.count))
            #expect(full.status == .accepted, "an export of the limit itself")
        }
        #expect(UserDataServices.importBodyLimit == 128 * 1_048_576)
    }

    /// With user data off nothing is imported; under a path the status is under it.
    @Test func anImportIsRefusedWhileUserDataIsOffAndAnswersUnderThePath() async throws {
        let off = try await UserDataFixture(userData: false)
        defer { withExtendedLifetime(off) {} }
        try await off.app.test(.router) { client in
            let browser = Browser(client: client)
            for response in [try await browser.send(.post, Self.path, try Self.export()), try await browser.get("/api/v1/me/import/1")] {
                #expect(response.status == .forbidden && problemCode(response) == "USER_DATA_OFF")
            }
        }
        let under = try await UserDataFixture(publicURL: "http://localhost:8080/frus-explorer/")
        defer { withExtendedLifetime(under) {} }
        try await under.app.test(.router) { client in
            let browser = Browser(client: client, base: "/frus-explorer")
            let posted = try await browser.send(.post, Self.path, try Self.export())
            let id = try decode(ImportStatus.self, posted).id
            #expect(posted.headers[.location] == "/frus-explorer/api/v1/me/import/\(id)")
            await under.jobs.waitUntilIdle()
            #expect(try decode(ImportStatus.self, try await browser.get("/api/v1/me/import/\(id)")).state == .succeeded)
        }
    }

    /// An instance's corrections are a curator's to import: for anyone else they are set aside, and
    /// counted so.
    @Test func anInstancesCorrectionsAreSetAsideForAUserWhoIsNoCurator() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        let envelope = try MacImport.envelope(of: Data(try Self.export().utf8))
        let report = try MacImport.run(envelope, into: fixture.store, for: "owner", includingInstanceWide: false)
        let correction = try #require(report.types.first { $0.type == "DocumentClassificationOverride" })
        #expect(correction.inFile == 1 && correction.setAside == 1 && correction.added == 0)
        #expect(try fixture.store.classificationOverrides().isEmpty)
    }
}
