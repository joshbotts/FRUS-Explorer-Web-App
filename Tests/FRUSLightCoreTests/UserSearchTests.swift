// The user's own search text (S15d): every note and summary change rewrites the document's row of
// user_search in its transaction, its note text joined as `ResearchNote.indexedTextPerDocument`
// joins a document's notes and its summary text the newest but a headnote draft, as
// `GeneratedSummary.newestNonDraftPerDocument` picks it; a document with neither has no row, and
// a tag change touches none. FRUSParityTests holds the two rules to the app's source.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserSearchTests {
    static let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
    static let d2 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d2")
    static let general = #"{"general":{}}"#

    static func time(_ hours: Double) -> Date { Date(timeIntervalSince1970: 1_792_800_000 + hours * 3_600) }

    static func row(_ document: DocumentKey = d1, summary: String? = nil, notes: String? = nil) -> UserSearchRow {
        UserSearchRow(volumeId: document.volumeId, documentId: document.documentId, summaryText: summary, noteText: notes)
    }

    /// Every kind of note write: a new note, a save with its body and one without, and a delete,
    /// the last of which leaves no row.
    @Test(arguments: UserStoreKind.available) func aDocumentsNotesAreJoinedAsTheAppIndexesThem(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        #expect(try rows.userSearch().isEmpty)
        _ = try UserNoteTests.make(store, "Second, written later.", at: Self.time(2))
        #expect(try rows.userSearch() == [Self.row(notes: "Second, written later.")])
        let first = try UserNoteTests.make(store, "First, written earlier.", at: Self.time(1))
        let blank = try UserNoteTests.make(store, " \n\t", at: Self.time(0))
        _ = try UserNoteTests.make(store, "On another document.", in: Self.d2, at: Self.time(3))
        // By createdAt, never lastModified: a later save of the first keeps its place.
        _ = try store.updateNote(first.id, body: { _ in NoteBody(text: "First, edited.", richText: nil) }, projectIds: [],
                                 userTagIds: [], selectedSummaryIds: [], for: "owner", at: Self.time(9))
        #expect(try rows.userSearch() == [Self.row(notes: "First, edited.\n\nSecond, written later."),
                                          Self.row(Self.d2, notes: "On another document.")],
                "oldest first, a blank note left out, joined by a blank line")
        // An import's note with no time comes first, and two of one time go by id in uppercase. Rows
        // written beside the store are indexed at the document's next write.
        try rows.addNote("b0000000-0000-0000-0000-000000000000", bodyText: "B, imported.", createdAt: "2026-10-24T01:30:00.000Z")
        try rows.addNote("A0000000-0000-0000-0000-000000000000", bodyText: "A, imported.", createdAt: "2026-10-24T01:30:00.000Z")
        try rows.addNote("C0000000-0000-0000-0000-000000000000", bodyText: "Undated.", createdAt: nil)
        _ = try store.updateNote(blank.id, body: nil, projectIds: [], userTagIds: [], selectedSummaryIds: [], for: "owner",
                                 at: Self.time(9))
        let joined = ["Undated.", "First, edited.", "A, imported.", "B, imported.", "Second, written later."].joined(separator: "\n\n")
        #expect(try rows.userSearch().first == Self.row(notes: joined))

        // A delete rewrites the row; the last delete leaves none.
        for note in try store.notes(of: Self.d1, for: "owner") { try store.deleteNote(note.id, for: "owner") }
        #expect(try rows.userSearch() == [Self.row(Self.d2, notes: "On another document.")])
        #expect(try rows.userSearchMatches("document") == ["d2"])
    }

    /// Two notes of one time go by id, as `uuidString`s compare; a note with no time goes first.
    @Test func theNoteTextsOrderIsTotal() {
        func note(_ id: String, _ body: String, _ created: Date?) -> NoteRecord {
            NoteRecord(id: id, volumeId: "v", documentId: "d", bodyText: body, richText: nil, projectIds: [], userTagIds: [],
                       selectedSummaryIds: [], createdAt: created, lastModified: nil)
        }
        let t = Self.time(1)
        #expect(UserSearchText.noteText([
            note("B0000000-0000-0000-0000-000000000000", "b", t), note("a0000000-0000-0000-0000-000000000000", "a", t),
            note("C0000000-0000-0000-0000-000000000000", "c", nil), note("D0000000-0000-0000-0000-000000000000", "\n", nil),
        ]) == "c\n\na\n\nb")
        #expect(UserSearchText.noteText([note("A0000000-0000-0000-0000-000000000000", "  ", t)]) == nil)
        #expect(UserSearchText.noteText([]) == nil)
        #expect(UserSearchText.noteText([NoteRecord(id: "A", volumeId: "", documentId: "d", bodyText: "x", richText: nil, projectIds: [],
                                                    userTagIds: [], selectedSummaryIds: [], createdAt: t, lastModified: t)]) == nil,
                "a note with no volume indexes nothing")
    }

    /// Every kind of summary write. The row's summary is the newest but a headnote draft, whose text
    /// is a collection's own; one whose every summary is a draft has none.
    @Test(arguments: UserStoreKind.available) func aDocumentsSummaryIsItsNewestButADraft(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addSummary("10000000-0000-4000-8000-000000000001", responseText: "An older AI summary.",
                            createdAt: "2026-01-01T00:00:00.000Z")
        try rows.addSummary("20000000-0000-4000-8000-000000000002", responseText: "A collection's draft.",
                            isHeadnoteDraft: true, createdAt: "2027-01-01T00:00:00.000Z")
        let mine = try store.createOwnSummary(in: Self.d1, text: "My summary.", responseFormat: Self.general, for: "owner",
                                              at: Self.time(0))
        #expect(try rows.userSearch() == [Self.row(summary: "My summary.")])
        _ = try store.updateOwnSummary(mine.id, text: "My summary, edited.", for: "owner", at: Self.time(1))
        #expect(try rows.userSearch() == [Self.row(summary: "My summary, edited.")])
        let note = try UserNoteTests.make(store, "A note too.", at: Self.time(2))
        #expect(try rows.userSearch() == [Self.row(summary: "My summary, edited.", notes: "A note too.")], "both columns at once")
        try store.deleteOwnSummary(mine.id, for: "owner")
        #expect(try rows.userSearch() == [Self.row(summary: "An older AI summary.", notes: "A note too.")])
        #expect(try rows.userSearchMatches("summary") == ["d1"])
        try store.deleteNote(note.id, for: "owner")
        #expect(try rows.userSearch() == [Self.row(summary: "An older AI summary.")])

        // A document whose only summary is a draft: no summary text, and with no note, no row.
        try rows.addSummary("30000000-0000-4000-8000-000000000003", documentId: "d2", responseText: "Only a draft.", isHeadnoteDraft: true)
        let other = try UserNoteTests.make(store, "On d2.", in: Self.d2, at: Self.time(3))
        #expect(try rows.userSearch().last == Self.row(Self.d2, notes: "On d2."))
        try store.deleteNote(other.id, for: "owner")
        #expect(try rows.userSearch() == [Self.row(summary: "An older AI summary.")])
    }

    /// A structured summary is searched by its fields as plain text, the app's `indexedText` since
    /// FRUS-Explorer#1824, and not by its JSON; one whose text is no JSON object of strings by its text.
    /// A row written before, which holds the JSON, takes the fields at the store's sync, as at the app's
    /// launch, and one left with no text in either column goes; a row already current is left alone, so
    /// a second sync changes nothing.
    @Test(arguments: UserStoreKind.available) func aStructuredSummaryIsSearchedByItsFields(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let schema = #"{"structured":{"schema":{"fields":[{"description":"Who","name":"KeyParticipants"},{"description":"What","name":"Background"}]}}}"#
        let json = #"{"Background": "Berlin, 1961.", "KeyParticipants": " Rusk and Dobrynin ", "Outcome": ""}"#
        try rows.addSummary("40000000-0000-4000-8000-000000000004", responseText: json, responseFormat: schema)
        try rows.addSummary("50000000-0000-4000-8000-000000000005", documentId: "d2", responseText: "[1, 2]", responseFormat: schema)
        // Any write to the documents' research rewrites their rows by the rule.
        let notes = [try UserNoteTests.make(store, "A note.", at: Self.time(0)),
                     try UserNoteTests.make(store, "Another.", in: Self.d2, at: Self.time(0))]
        let fields = "Key Participants: Rusk and Dobrynin\n\nBackground: Berlin, 1961.\n\nOutcome:"
        #expect(try rows.userSearch() == [Self.row(summary: fields, notes: "A note."), Self.row(Self.d2, summary: "[1, 2]", notes: "Another.")],
                "the schema's fields in its order, then any other by name, each trimmed; text that is no object as stored")
        #expect(try rows.userSearchMatches("\"Key Participants\"") == ["d1"])
        #expect(try store.syncSummarySearchText() == 0, "a store already current is left alone")

        // As an older build left the rows: the JSON, and two rows of documents whose only summary is a
        // draft, one with a note, which keeps its row, and one without, whose row goes.
        try rows.addSummary("60000000-0000-4000-8000-000000000006", documentId: "d3", responseText: "A draft.", isHeadnoteDraft: true)
        try rows.addSummary("70000000-0000-4000-8000-000000000007", documentId: "d4", responseText: "Another.", isHeadnoteDraft: true)
        _ = try rows.searched("UPDATE user_search SET summary_text = ? WHERE document_id = 'd1'", [.text(json)])
        for (document, note) in [("d3", SQLiteValue.text("Kept.")), ("d4", .null)] {
            _ = try rows.searched(
                "INSERT INTO user_search (user_id, document_id, volume_id, summary_text, note_text) VALUES ('owner', ?, 'frus1961-63v06', 'A draft.', ?)",
                [.text(document), note])
        }
        #expect(try rows.userSearchMatches("KeyParticipants") == ["d1"])
        #expect(try store.syncSummarySearchText() == 3)
        #expect(try rows.userSearch() == [Self.row(summary: fields, notes: "A note."), Self.row(Self.d2, summary: "[1, 2]", notes: "Another."),
                                          Self.row(DocumentKey(volumeId: "frus1961-63v06", documentId: "d3"), notes: "Kept.")])
        #expect(try rows.userSearchMatches("KeyParticipants").isEmpty)
        #expect(try store.syncSummarySearchText() == 0)
        for note in notes { try store.deleteNote(note.id, for: "owner") }
    }

    /// Porter stems the user's words as the corpus's: a search for "negotiate" finds "negotiating".
    /// A tag change touches no row, as user_search holds no tags; each user's rows are theirs.
    @Test(arguments: UserStoreKind.available) func theRowsAreSearchableAndEachUsersAlone(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        let tag = try store.createTag(named: "Laos", for: "owner", at: Self.time(0))
        let note = try UserNoteTests.make(store, "Negotiating the Laos settlement.", tags: [tag.id], at: Self.time(0))
        _ = try UserNoteTests.make(store, "Theirs.", user: "reader", at: Self.time(0))
        #expect(try rows.userSearchMatches("negotiate") == ["d1"])
        #expect(try rows.userSearchMatches("negotiate", user: "reader").isEmpty)
        #expect(try rows.userSearch(user: "reader") == [Self.row(notes: "Theirs.")])
        let before = try rows.userSearch()
        _ = try store.deleteTag(tag.id, for: "owner", at: Self.time(1))
        #expect(try rows.userSearch() == before)
        #expect(try store.note(note.id, of: "owner")?.userTagIds == [])
    }
}
