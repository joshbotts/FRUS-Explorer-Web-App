// Notes in the user store (S15d), kept as the app keeps `ResearchNote`: what a note is given,
// verbatim, its RTF as its bytes, with a new id and its times; a document's and all of them the
// latest first, as the Research rail and All Notes list them; a save that keeps the body byte for byte
// unless it was edited, as the app's editor rewrites it only on an edit; ids that must name what the
// user has unless the note already carries them, as the app's picker keeps a dangling one; and the
// highlight a new note is written for, linked by its `noteId`, which a delete leaves.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserNoteTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000.1234)  // 2026-10-24T00:00:00.123Z, rounded
    static let later = Date(timeIntervalSince1970: 1_792_803_600)  // an hour on
    static let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
    static let d2 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d2")
    /// RTF as AppKit writes a bold word, whose bytes the store keeps whatever they say.
    static let rtf = Array(#"{\rtf1\ansi\ansicpg1252\cocoartf2907 {\fonttbl\f0\fnil\fcharset0 HelveticaNeue;}\f0\fs26 A \b bold\b0  word.}"#.utf8)

    static func make(_ store: SQLiteUserStore, _ body: String = "A note.", in document: DocumentKey = d1, richText: [UInt8]? = nil,
                     tags: [String] = [], projects: [String] = [], summaries: [String] = [], highlight: String? = nil,
                     user: String = "owner", at time: Date = created) throws -> NoteRecord {
        try store.createNote(in: document, bodyText: body, richText: richText, projectIds: projects, userTagIds: tags,
                             selectedSummaryIds: summaries, linkedHighlightId: highlight, for: user, at: time)
    }

    @Test func aNoteKeepsWhatItIsGivenVerbatim() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let body = "A bold word.\n\nAnd a second paragraph, café — “quoted”."
        let note = try Self.make(store, body, richText: Self.rtf)
        #expect(UUID(uuidString: note.id)?.uuidString == note.id, "an uppercase uuidString, as the Mac's ids are")
        #expect(note == NoteRecord(id: note.id, volumeId: "frus1961-63v06", documentId: "d1", bodyText: body, richText: Self.rtf,
                                   projectIds: [], userTagIds: [], selectedSummaryIds: [],
                                   createdAt: UserStoreDate.rounded(Self.created), lastModified: UserStoreDate.rounded(Self.created)))
        #expect(try store.note(note.id, of: "owner") == note, "read back as it was written")
        #expect(try store.note(note.id.lowercased(), of: "owner") == note, "an id in any case")
        #expect(try store.note("not-a-uuid", of: "owner") == nil)
        let stored = try #require(try rows.storedNote(note.id))
        #expect(stored.richText == Self.rtf && stored.bodyText == body, "the RTF's bytes and the body as given")
        #expect(stored.createdAt == "2026-10-24T00:00:00.123Z" && stored.lastModified == "2026-10-24T00:00:00.123Z")
        #expect(stored.userTagIds == "[]" && stored.projectIds == "[]" && stored.selectedSummaryIds == "[]")
        // A plain note keeps no RTF: nil, never an empty payload.
        let plain = try Self.make(store, "")
        #expect(plain.richText == nil && plain.bodyText == "")
        #expect(try rows.storedNote(plain.id)?.richText == nil)
    }

    /// The rail's `@Query` sorted by `lastModified` in reverse, and All Notes' too: the latest first,
    /// one with no time after the rest, then by id in uppercase, an import's lowercase one among them.
    @Test func notesAreListedTheLatestFirst() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let made = try Self.make(store, at: Self.later)
        try rows.addNote("B0000000-0000-0000-0000-000000000000", lastModified: "2026-01-01T00:00:00.000Z")
        try rows.addNote("a0000000-0000-0000-0000-000000000000", lastModified: "2026-01-01T00:00:00.000Z")
        try rows.addNote("C0000000-0000-0000-0000-000000000000", createdAt: nil, lastModified: nil)
        try rows.addNote("D0000000-0000-0000-0000-000000000000", lastModified: "2026-06-01T00:00:00.000Z")
        try rows.addNote("E0000000-0000-0000-0000-000000000000", documentId: "d2", lastModified: "2027-01-01T00:00:00.000Z")
        #expect(try store.notes(of: Self.d1, for: "owner").map(\.id) == [
            made.id, "D0000000-0000-0000-0000-000000000000", "a0000000-0000-0000-0000-000000000000",
            "B0000000-0000-0000-0000-000000000000", "C0000000-0000-0000-0000-000000000000",
        ])
        #expect(try store.notes(of: Self.d1, for: "owner").last?.lastModified == nil)
        #expect(try store.notes(for: "owner").map(\.id) == [
            "E0000000-0000-0000-0000-000000000000", made.id, "D0000000-0000-0000-0000-000000000000",
            "a0000000-0000-0000-0000-000000000000", "B0000000-0000-0000-0000-000000000000",
            "C0000000-0000-0000-0000-000000000000",
        ])
        #expect(try store.notes(of: Self.d2, for: "owner").map(\.documentId) == ["d2"])
    }

    /// The app's editor writes `richText` only when its view reports an edit: a save that leaves the
    /// body alone keeps it, Mac RTF the codec could not write included, byte for byte; a plain-mode
    /// edit drops it, as `setPlainBody` does; a formatted one replaces it.
    @Test func aSaveKeepsTheBodyByteForByteUnlessItWasEdited() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let tag = try store.createTag(named: "Revisit", for: "owner", at: Self.created)
        // A Mac note whose RTF holds what no wire carries, and a body with a CRLF, as a paste keeps one.
        let mac = Array(#"{\rtf1\ansi\ansicpg1252\cocoartf2907 \f0\fs26 \strike struck\strike0  \cb3 marked}"#.utf8)
        try rows.addNote("A0000000-0000-0000-0000-000000000000", bodyText: "struck marked\r\n", richText: mac)
        let retagged = try store.updateNote("a0000000-0000-0000-0000-000000000000", body: nil, projectIds: [], userTagIds: [tag.id],
                                            selectedSummaryIds: [], for: "owner", at: Self.later)
        #expect(retagged.richText == mac && retagged.bodyText == "struck marked\r\n" && retagged.userTagIds == [tag.id])
        #expect(retagged.createdAt == UserStoreDate.date("2026-01-01T00:00:00.000Z"))
        #expect(retagged.lastModified == Self.later, "stamped, as the app's save stamps it")
        var stored = try #require(try rows.storedNote("A0000000-0000-0000-0000-000000000000"))
        #expect(stored.richText == mac && stored.bodyText == "struck marked\r\n", "byte for byte")
        #expect(stored.userTagIds == UserStoreRows.json([tag.id]) && stored.lastModified == "2026-10-24T01:00:00.000Z")

        let plain = try store.updateNote(retagged.id, body: { _ in NoteBody(text: "now plain", richText: nil) }, projectIds: [],
                                         userTagIds: [tag.id], selectedSummaryIds: [], for: "owner", at: Self.later)
        #expect(plain.richText == nil && plain.bodyText == "now plain")
        stored = try #require(try rows.storedNote(retagged.id))
        #expect(stored.richText == nil && stored.bodyText == "now plain")
        let formatted = try store.updateNote(retagged.id, body: { _ in NoteBody(text: "A bold word.", richText: Self.rtf) },
                                             projectIds: [], userTagIds: [], selectedSummaryIds: [], for: "owner", at: Self.later)
        #expect(formatted.richText == Self.rtf && formatted.userTagIds.isEmpty)
        #expect(try rows.storedNote(retagged.id)?.richText == Self.rtf)
        #expect(throws: NoteStoreError.noteNotFound("not-an-id")) {
            try store.updateNote("not-an-id", body: nil, projectIds: [], userTagIds: [], selectedSummaryIds: [], for: "owner", at: Self.later)
        }
    }

    struct Refused: Error, Equatable {}

    /// A save's body is made from the note as the save's transaction finds it, so a rule that
    /// depends on what the note holds, the links a save may send back, is held to the row it
    /// changes, and not to one a save read before another's; it is made before the lists are held
    /// to their rule, and what it throws is passed on with nothing written.
    @Test func aSavesBodyIsMadeFromTheNoteItChanges() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let note = try Self.make(store, "A bold word.", richText: Self.rtf)
        // Another save takes the RTF out; the next save's body sees the note without it.
        _ = try store.updateNote(note.id, body: { _ in NoteBody(text: "Plain.", richText: nil) }, projectIds: [], userTagIds: [],
                                 selectedSummaryIds: [], for: "owner", at: Self.later)
        var seen: [NoteRecord] = []
        let saved = try store.updateNote(note.id.lowercased(), body: { stored in
            seen.append(stored)
            return NoteBody(text: stored.bodyText + " Again.", richText: nil)
        }, projectIds: [], userTagIds: [], selectedSummaryIds: [], for: "owner", at: Self.later)
        #expect(seen.map(\.bodyText) == ["Plain."] && seen.first?.richText == nil && seen.first?.id == note.id)
        #expect(saved.bodyText == "Plain. Again.")
        // Refused by the body, or by a list after it, the save writes nothing.
        let before = try #require(try rows.storedNote(note.id))
        #expect(throws: Refused()) {
            try store.updateNote(note.id, body: { _ in throw Refused() }, projectIds: [], userTagIds: [UUID().uuidString],
                                 selectedSummaryIds: [], for: "owner", at: Self.created)
        }
        let unknown = UUID().uuidString
        #expect(throws: NoteStoreError.notHeld(.userTagIds, unknown)) {
            try store.updateNote(note.id, body: { _ in NoteBody(text: "Lost.", richText: Self.rtf) }, projectIds: [],
                                 userTagIds: [unknown], selectedSummaryIds: [], for: "owner", at: Self.created)
        }
        #expect(try rows.storedNote(note.id) == before, "unchanged, its time too")
        var called = false
        #expect(throws: NoteStoreError.noteNotFound("B0000000-0000-0000-0000-000000000000")) {
            try store.updateNote("B0000000-0000-0000-0000-000000000000", body: { _ in
                called = true
                return NoteBody(text: "", richText: nil)
            }, projectIds: [], userTagIds: [], selectedSummaryIds: [], for: "owner", at: Self.later)
        }
        #expect(!called, "no note, no body")
    }

    /// A new id in a note's lists must name one of the user's tags, projects or summaries, so a
    /// stale editor cannot put back an id a delete has just taken out (S14c's rule); an id the note
    /// already carries is kept whatever it names, as the app's picker keeps one its catalogue lacks.
    @Test func anIdMustNameWhatTheUserHasUnlessTheNoteCarriesIt() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let tag = try store.createTag(named: "Revisit", for: "owner", at: Self.created)
        try rows.addProject("aa000000-0000-4000-8000-000000000001", name: "Laos")
        try rows.addSummary("50000000-0000-4000-8000-000000000001")
        let unknown = "F0000000-0000-4000-8000-00000000000F"
        #expect(throws: NoteStoreError.notHeld(.userTagIds, unknown)) { try Self.make(store, tags: [unknown]) }
        #expect(throws: NoteStoreError.notHeld(.projectIds, unknown)) { try Self.make(store, projects: [unknown]) }
        #expect(throws: NoteStoreError.notHeld(.selectedSummaryIds, unknown)) { try Self.make(store, summaries: [unknown]) }
        #expect(throws: NoteStoreError.malformedId(.userTagIds, "Revisit")) { try Self.make(store, tags: ["Revisit"]) }
        #expect(throws: NoteStoreError.notHeld(.userTagIds, unknown), "tags first, as a document's tags refuse") {
            try Self.make(store, tags: [unknown], projects: ["x"])
        }
        #expect(try store.notes(for: "owner").isEmpty, "nothing was made")

        // Held, in any case: kept in uppercase, once each, in the order given.
        let note = try Self.make(store, tags: [tag.id.lowercased(), tag.id], projects: ["AA000000-0000-4000-8000-000000000001"],
                                 summaries: ["50000000-0000-4000-8000-000000000001"])
        #expect(note.userTagIds == [tag.id] && note.projectIds == ["AA000000-0000-4000-8000-000000000001"])
        #expect(note.selectedSummaryIds == ["50000000-0000-4000-8000-000000000001"])

        // An import's note, carrying a deleted tag in lowercase, a project's id that is no UUID and a
        // summary the user no longer has: a save keeps each, and refuses a new one that dangles.
        let dangling = "d0000000-0000-4000-8000-00000000000d"
        try rows.addNote("A0000000-0000-0000-0000-000000000000", tagIds: [dangling], projectIds: ["not-a-uuid"],
                         selectedSummaryIds: [unknown])
        let saved = try store.updateNote("A0000000-0000-0000-0000-000000000000", body: nil, projectIds: ["not-a-uuid"],
                                         userTagIds: [dangling.uppercased(), tag.id], selectedSummaryIds: [unknown],
                                         for: "owner", at: Self.later)
        #expect(saved.userTagIds == [dangling.uppercased(), tag.id] && saved.projectIds == ["not-a-uuid"])
        #expect(saved.selectedSummaryIds == [unknown])
        let other = "E0000000-0000-4000-8000-00000000000E"
        for (list, call) in [(NoteIdList.userTagIds, { try store.updateNote(saved.id, body: nil, projectIds: [], userTagIds: [other],
                                                                         selectedSummaryIds: [], for: "owner", at: Self.later) }),
                             (.projectIds, { try store.updateNote(saved.id, body: nil, projectIds: [other], userTagIds: [],
                                                                  selectedSummaryIds: [], for: "owner", at: Self.later) }),
                             (.selectedSummaryIds, { try store.updateNote(saved.id, body: nil, projectIds: [], userTagIds: [],
                                                                          selectedSummaryIds: [other], for: "owner", at: Self.later) })] {
            #expect(throws: NoteStoreError.notHeld(list, other)) { _ = try call() }
        }
        #expect(throws: NoteStoreError.malformedId(.projectIds, "also-not-a-uuid")) {
            try store.updateNote(saved.id, body: nil, projectIds: ["also-not-a-uuid"], userTagIds: [], selectedSummaryIds: [],
                                 for: "owner", at: Self.later)
        }
        #expect(try store.note(saved.id, of: "owner") == saved, "a refused save changes nothing")
        // A tag the user has, deleted while the note is open, is gone from it, and cannot come back.
        _ = try store.deleteTag(tag.id, for: "owner", at: Self.later)
        #expect(try store.note(saved.id, of: "owner")?.userTagIds == [dangling.uppercased()])
        #expect(throws: NoteStoreError.notHeld(.userTagIds, tag.id)) {
            try store.updateNote(saved.id, body: nil, projectIds: [], userTagIds: [tag.id], selectedSummaryIds: [], for: "owner",
                                 at: Self.later)
        }
    }

    /// `linkNoteToHighlight`: Save sets the highlight's `noteId`, if the highlight is still there,
    /// and saves the note unlinked if not. Deleting either leaves the other, the link dangling.
    @Test func aNewNoteLinksTheHighlightItWasWrittenFor() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let highlight = try store.createHighlight(in: Self.d1, start: 0, end: 5, colorTag: "yellow", selectedText: "Allow",
                                                  renderingVersion: "v", for: "owner", at: Self.created)
        let note = try Self.make(store, highlight: highlight.id.lowercased())
        #expect(note.linkedHighlightIds == [highlight.id])
        #expect(try rows.highlightNoteId(highlight.id) == note.id)
        #expect(try store.highlight(highlight.id, of: "owner")?.noteId == note.id)
        #expect(try store.note(note.id, of: "owner")?.linkedHighlightIds == [highlight.id])
        #expect(try store.notes(for: "owner").first?.linkedHighlightIds == [highlight.id])
        // A second note for it takes the link, last write winning, as the app's plain id.
        let second = try Self.make(store, highlight: highlight.id, at: Self.later)
        #expect(try rows.highlightNoteId(highlight.id) == second.id)
        #expect(try store.note(note.id, of: "owner")?.linkedHighlightIds == [])
        // A highlight that has gone, or is not the user's, links nothing, and the note is saved.
        try rows.addUser("reader")
        let theirs = try store.createHighlight(in: Self.d1, start: 0, end: 5, colorTag: "blue", selectedText: "", renderingVersion: "",
                                               for: "reader", at: Self.created)
        let unlinked = try Self.make(store, highlight: theirs.id)
        #expect(try unlinked.linkedHighlightIds.isEmpty && rows.highlightNoteId(theirs.id) == nil)
        let gone = try Self.make(store, highlight: UUID().uuidString)
        #expect(gone.linkedHighlightIds.isEmpty)
        #expect(try Self.make(store, highlight: "not-a-uuid").linkedHighlightIds.isEmpty)
        // Deletes leave the link dangling.
        try store.deleteNote(second.id, for: "owner")
        #expect(try store.note(second.id, of: "owner") == nil)
        #expect(try rows.highlightNoteId(highlight.id) == second.id, "the highlight keeps the note's id")
        try store.deleteHighlight(highlight.id, for: "owner")
        #expect(try store.note(note.id, of: "owner") != nil, "a highlight's delete keeps its note")
        #expect(throws: NoteStoreError.noteNotFound(second.id)) { try store.deleteNote(second.id, for: "owner") }
    }

    @Test func eachUsersNotesAreTheirsAlone() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        let theirs = try Self.make(store, user: "reader")
        let tag = try store.createTag(named: "Theirs", for: "reader", at: Self.created)
        #expect(try store.notes(of: Self.d1, for: "owner").isEmpty)
        #expect(try store.notes(for: "owner").isEmpty)
        #expect(try store.note(theirs.id, of: "owner") == nil)
        #expect(throws: NoteStoreError.noteNotFound(theirs.id)) {
            try store.updateNote(theirs.id, body: nil, projectIds: [], userTagIds: [], selectedSummaryIds: [], for: "owner", at: Self.later)
        }
        #expect(throws: NoteStoreError.noteNotFound(theirs.id)) { try store.deleteNote(theirs.id, for: "owner") }
        #expect(throws: NoteStoreError.notHeld(.userTagIds, tag.id), "another user's tag is not the owner's") {
            try Self.make(store, tags: [tag.id])
        }
        #expect(try store.notes(for: "reader") == [theirs])
    }
}
