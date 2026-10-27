// Summaries, prompts and projects in the user store (S15d): a document's summaries in the app's order,
// `GeneratedSummary.ranksAbove`; the reader's own, the web's own, written with the web's prompt id and
// `userWritten`, the only ones that change, an imported headnote draft that is `userWritten` too
// among those that do not; a prompt named by its id in any case; and projects by name.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserSummaryTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z
    static let later = Date(timeIntervalSince1970: 1_792_803_600.25)
    static let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
    static let general = #"{"general":{}}"#

    @Test(arguments: UserStoreKind.available) func aReadersOwnSummaryIsTheWebsOwn(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let text = "  My own summary.\n\nIn two paragraphs.\n"
        let summary = try store.createOwnSummary(in: Self.d1, text: text, responseFormat: Self.general, for: "owner", at: Self.created)
        #expect(UUID(uuidString: summary.id)?.uuidString == summary.id)
        #expect(summary == SummaryRecord(id: summary.id, volumeId: "frus1961-63v06", documentId: "d1",
                                         promptId: "0EB00000-0000-4000-8000-000000000001", responseText: text,
                                         responseFormat: Self.general, wasChunked: false, authorship: "userWritten",
                                         isHeadnoteDraft: false, sourceContentHash: nil, projectId: nil,
                                         createdAt: Self.created, lastModified: Self.created))
        #expect(summary.isEditable)
        #expect(try store.summary(summary.id.lowercased(), of: "owner") == summary)
        let stored = try #require(try rows.storedSummary(summary.id))
        #expect(stored == ["response_text": text, "response_format": Self.general, "was_chunked": "0", "authorship": "userWritten",
                           "is_headnote_draft": "0", "prompt_id": OwnSummary.promptId, "project_id": nil,
                           "source_content_hash": nil, "created_at": "2026-10-24T00:00:00.000Z",
                           "last_modified": "2026-10-24T00:00:00.000Z"])
        for empty in ["", "  ", "\n\t"] {
            #expect(throws: SummaryStoreError.emptyText) {
                try store.createOwnSummary(in: Self.d1, text: empty, responseFormat: Self.general, for: "owner", at: Self.created)
            }
            #expect(throws: SummaryStoreError.emptyText) { try store.updateOwnSummary(summary.id, text: empty, for: "owner", at: Self.later) }
        }
        let edited = try store.updateOwnSummary(summary.id, text: "Edited.", for: "owner", at: Self.later)
        #expect(edited.responseText == "Edited." && edited.createdAt == Self.created && edited.lastModified == UserStoreDate.rounded(Self.later))
        #expect(try store.summary(summary.id, of: "owner") == edited)
        try store.deleteOwnSummary(summary.id, for: "owner")
        #expect(try store.summary(summary.id, of: "owner") == nil)
        #expect(throws: SummaryStoreError.summaryNotFound(summary.id)) { try store.deleteOwnSummary(summary.id, for: "owner") }
        #expect(throws: SummaryStoreError.summaryNotFound("x")) { try store.updateOwnSummary("x", text: "y", for: "owner", at: Self.later) }
    }

    /// `GeneratedSummary.ranksAbove`: `createdAt` descending, one with none last; then
    /// `lastModified` descending, one with none last; then the id, in uppercase as `uuidString`.
    @Test(arguments: UserStoreKind.available) func aDocumentsSummariesComeInTheAppsOrder(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addSummary("10000000-0000-4000-8000-000000000001", createdAt: "2026-03-01T00:00:00.000Z")
        try rows.addSummary("20000000-0000-4000-8000-000000000002", createdAt: nil, lastModified: "2027-01-01T00:00:00.000Z")
        try rows.addSummary("30000000-0000-4000-8000-000000000003", createdAt: "2026-02-01T00:00:00.000Z",
                            lastModified: "2026-05-01T00:00:00.000Z")
        try rows.addSummary("40000000-0000-4000-8000-000000000004", createdAt: "2026-02-01T00:00:00.000Z", lastModified: nil)
        // Tied, an import's lowercase id goes as its uppercase `uuidString`: "a…" before "B…",
        // which a compare of the ids as written would put the other way.
        try rows.addSummary("B0000000-0000-4000-8000-00000000000B", createdAt: "2026-02-01T00:00:00.000Z",
                            lastModified: "2026-04-01T00:00:00.000Z")
        try rows.addSummary("a0000000-0000-4000-8000-00000000000a", createdAt: "2026-02-01T00:00:00.000Z",
                            lastModified: "2026-04-01T00:00:00.000Z")
        try rows.addSummary("50000000-0000-4000-8000-000000000005", isHeadnoteDraft: true, createdAt: "2026-09-01T00:00:00.000Z")
        try rows.addSummary("60000000-0000-4000-8000-000000000006", documentId: "d2", createdAt: "2028-01-01T00:00:00.000Z")
        let own = try store.createOwnSummary(in: Self.d1, text: "Mine.", responseFormat: Self.general, for: "owner", at: Self.created)
        #expect(try store.summaries(of: Self.d1, for: "owner").map(\.id) == [
            own.id, "50000000-0000-4000-8000-000000000005", "10000000-0000-4000-8000-000000000001",
            "30000000-0000-4000-8000-000000000003", "a0000000-0000-4000-8000-00000000000a",
            "B0000000-0000-4000-8000-00000000000B", "40000000-0000-4000-8000-000000000004",
            "20000000-0000-4000-8000-000000000002",
        ], "every summary, headnote drafts included, newest first")
        let all = try store.summaries(of: Self.d1, for: "owner")
        for (a, b) in zip(all, all.dropFirst()) {
            #expect(SummaryOrder.ranksAbove(a, b) && !SummaryOrder.ranksAbove(b, a), "\(a.id) before \(b.id)")
        }
    }

    /// The one rule for what the reader may change: the web's prompt id, `userWritten` and no
    /// headnote draft. Everything else is read-only: an AI summary, one with no authorship, and an
    /// imported headnote draft, `userWritten` with the app's headnote prompt, whose draft flag a file
    /// older than format 7 does not carry.
    @Test(arguments: UserStoreKind.available) func onlyTheReadersOwnSummariesChange(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let readOnly: [(String, String, String?, Bool)] = [
            ("10000000-0000-4000-8000-000000000001", "AA000000-0000-4000-8000-000000000001", "aiGenerated", false),
            ("20000000-0000-4000-8000-000000000002", "0EAD0000-0000-4000-8000-000000000001", "userWritten", false),
            ("30000000-0000-4000-8000-000000000003", "0EAD0000-0000-4000-8000-000000000001", "aiEdited", true),
            ("40000000-0000-4000-8000-000000000004", OwnSummary.promptId, nil, false),
            ("50000000-0000-4000-8000-000000000005", OwnSummary.promptId, "aiEdited", false),
            ("60000000-0000-4000-8000-000000000006", OwnSummary.promptId, "userWritten", true),
        ]
        for (id, prompt, authorship, draft) in readOnly {
            try rows.addSummary(id, promptId: prompt, authorship: authorship, isHeadnoteDraft: draft)
            let summary = try #require(try store.summary(id, of: "owner"))
            #expect(!summary.isEditable, "\(id)")
            #expect(throws: SummaryStoreError.readOnly(id)) { try store.updateOwnSummary(id, text: "Mine now.", for: "owner", at: Self.later) }
            #expect(throws: SummaryStoreError.readOnly(id)) { try store.deleteOwnSummary(id, for: "owner") }
            #expect(try store.summary(id, of: "owner") == summary, "unchanged")
        }
        // The web's prompt id written in lowercase, as an import might, is still the web's.
        try rows.addSummary("70000000-0000-4000-8000-000000000007", promptId: OwnSummary.promptId.lowercased(), authorship: "userWritten")
        #expect(try store.updateOwnSummary("70000000-0000-4000-8000-000000000007", text: "Edited.", for: "owner", at: Self.later)
            .responseText == "Edited.")
        // A note that selected a deleted summary keeps its id, as the app leaves one.
        try rows.addNote("A0000000-0000-0000-0000-000000000000", selectedSummaryIds: ["70000000-0000-4000-8000-000000000007"])
        try store.deleteOwnSummary("70000000-0000-4000-8000-000000000007", for: "owner")
        #expect(try store.note("A0000000-0000-0000-0000-000000000000", of: "owner")?.selectedSummaryIds
            == ["70000000-0000-4000-8000-000000000007"])
    }

    /// A summary's prompt is named only while the user has it (`SummarizationPrompt.resolve`'s
    /// `.requested`), so the names are by id, in uppercase whatever the import wrote.
    @Test(arguments: UserStoreKind.available) func promptsAreNamedByTheirIds(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        try rows.addPrompt("aa000000-0000-4000-8000-000000000001", name: "Meeting Record")
        try rows.addPrompt("BB000000-0000-4000-8000-000000000002", name: "Laos questions")
        try rows.addPrompt("CC000000-0000-4000-8000-000000000003", user: "reader", name: "Theirs")
        #expect(try store.prompts(for: "owner") == ["AA000000-0000-4000-8000-000000000001": "Meeting Record",
                                                    "BB000000-0000-4000-8000-000000000002": "Laos questions"])
        #expect(try store.prompts(for: "reader") == ["CC000000-0000-4000-8000-000000000003": "Theirs"])
    }

    /// Projects by name, as `NotesPaneSnapshot` sorts them, with the tag list's comparison; then by
    /// id in uppercase, an import's lowercase one among them.
    @Test(arguments: UserStoreKind.available) func projectsAreListedByNameAndEachUsersAlone(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        #expect(try store.projects(for: "owner").isEmpty, "none until an import")
        try rows.addUser("reader")
        for (id, name) in [("C0000000-0000-4000-8000-000000000003", "Laos 10"), ("A0000000-0000-4000-8000-000000000001", "Laos 9"),
                           ("b0000000-0000-4000-8000-000000000002", "berlin"), ("D0000000-0000-4000-8000-000000000004", "Berlin"),
                           ("c0000000-0000-4000-8000-000000000005", "Berlin")] {
            try rows.addProject(id, name: name)
        }
        try rows.addProject("E0000000-0000-4000-8000-000000000006", user: "reader", name: "Theirs")
        #expect(try store.projects(for: "owner").map(\.name) == ["berlin", "Berlin", "Berlin", "Laos 9", "Laos 10"])
        // "c…" before "D…", as uppercase ids compare, which ids compared as written would not give.
        #expect(try store.projects(for: "owner")[1...2].map(\.id) == ["c0000000-0000-4000-8000-000000000005",
                                                                     "D0000000-0000-4000-8000-000000000004"], "one name, by id")
        #expect(try store.projects(for: "reader") == [ProjectRecord(id: "E0000000-0000-4000-8000-000000000006", name: "Theirs")])
    }

    @Test(arguments: UserStoreKind.available) func eachUsersSummariesAreTheirsAlone(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        let theirs = try store.createOwnSummary(in: Self.d1, text: "Theirs.", responseFormat: Self.general, for: "reader", at: Self.created)
        #expect(try store.summaries(of: Self.d1, for: "owner").isEmpty)
        #expect(try store.summary(theirs.id, of: "owner") == nil)
        #expect(throws: SummaryStoreError.summaryNotFound(theirs.id)) {
            try store.updateOwnSummary(theirs.id, text: "Mine.", for: "owner", at: Self.later)
        }
        #expect(throws: SummaryStoreError.summaryNotFound(theirs.id)) { try store.deleteOwnSummary(theirs.id, for: "owner") }
        #expect(try store.summaries(of: Self.d1, for: "reader") == [theirs])
    }
}
