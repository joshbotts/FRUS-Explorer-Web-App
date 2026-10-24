// Highlights in the user store (S15c), kept as the app keeps `DocumentHighlight`: what a highlight is
// given, verbatim, with a new id and its time; a document's in the order the app's reader draws them,
// its `@Query` sorted by `createdAt`; another colour changing nothing else; and a delete by id, as
// the reader's Remove deletes one, leaving any other over the same text.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserHighlightTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000.1234)  // 2026-10-24T00:00:00.123Z, rounded
    static let later = Date(timeIntervalSince1970: 1_792_803_600)
    static let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
    static let d2 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d2")

    @Test func aHighlightKeepsWhatItIsGivenVerbatim() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let text = "of your election\n\nas President"
        let highlight = try store.createHighlight(in: Self.d1, start: 120, end: 151, colorTag: "green", selectedText: text,
                                                  renderingVersion: "0123456789abcdef", for: "owner", at: Self.created)
        #expect(UUID(uuidString: highlight.id)?.uuidString == highlight.id, "an uppercase uuidString, as the Mac's ids are")
        #expect(highlight == HighlightRecord(id: highlight.id, volumeId: "frus1961-63v06", documentId: "d1", startOffset: 120,
                                             endOffset: 151, colorTag: "green", noteId: nil, selectedText: text,
                                             renderingVersion: "0123456789abcdef", createdAt: UserStoreDate.rounded(Self.created)))
        #expect(highlight.createdAt.map(UserStoreDate.text) == "2026-10-24T00:00:00.123Z")
        #expect(try store.highlight(highlight.id, of: "owner") == highlight, "read back as it was written")
        #expect(try store.highlight(highlight.id.lowercased(), of: "owner") == highlight, "an id in any case")
        #expect(try store.highlights(of: Self.d1, for: "owner") == [highlight])
        #expect(try store.highlights(of: Self.d2, for: "owner") == [])
        #expect(try rows.highlightCount() == 1)
    }

    /// The app's reader draws a document's highlights in its `@Query`'s order, by `createdAt`: one
    /// with no time first, as the app's store sorts a nil. Two of one time go by id in uppercase, the
    /// web's own order, an import's lowercase id among them: "a…" before "B…", where a plain sort of
    /// the text would put "B…" first.
    @Test func aDocumentsHighlightsComeInTheOrderTheReaderDrawsThem() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let made = try store.createHighlight(in: Self.d1, start: 0, end: 4, colorTag: "pink", selectedText: "", renderingVersion: "",
                                             for: "owner", at: Self.later)
        try rows.addHighlight("B0000000-0000-0000-0000-000000000000", createdAt: "2026-01-01T00:00:00.000Z")
        try rows.addHighlight("a0000000-0000-0000-0000-000000000000", createdAt: "2026-01-01T00:00:00.000Z")
        try rows.addHighlight("C0000000-0000-0000-0000-000000000000", createdAt: nil)
        try rows.addHighlight("D0000000-0000-0000-0000-000000000000", documentId: "d2")
        try rows.addHighlight("E0000000-0000-0000-0000-000000000000", volumeId: "frus1894Nicaragua", documentId: "d1")
        #expect(try store.highlights(of: Self.d1, for: "owner").map(\.id) == [
            "C0000000-0000-0000-0000-000000000000", "a0000000-0000-0000-0000-000000000000",
            "B0000000-0000-0000-0000-000000000000", made.id,
        ])
        #expect(try store.highlights(of: Self.d1, for: "owner").first?.createdAt == nil)
        // The import's lowercase id is found in any case, and kept as written.
        #expect(try store.highlight("A0000000-0000-0000-0000-000000000000", of: "owner")?.id == "a0000000-0000-0000-0000-000000000000")
        try store.deleteHighlight("A0000000-0000-0000-0000-000000000000", for: "owner")
        #expect(try store.highlights(of: Self.d1, for: "owner").count == 3)
        try rows.addHighlight("a0000000-0000-0000-0000-000000000000", createdAt: "2026-01-01T00:00:00.000Z")
        // All of them, by volume and document, each document's in the reader's order.
        #expect(try store.highlights(for: "owner").map(\.id) == [
            "E0000000-0000-0000-0000-000000000000", "C0000000-0000-0000-0000-000000000000",
            "a0000000-0000-0000-0000-000000000000", "B0000000-0000-0000-0000-000000000000", made.id,
            "D0000000-0000-0000-0000-000000000000",
        ])
    }

    @Test func anotherColourChangesOnlyTheColour() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        // An import's row: a colour the app does not draw and a version of another text are kept.
        try rows.addHighlight("A0000000-0000-0000-0000-000000000000", start: 10, end: 20, colorTag: "teal", noteId: "N",
                              selectedText: "ten chars.", renderingVersion: "old")
        let before = try #require(try store.highlight("A0000000-0000-0000-0000-000000000000", of: "owner"))
        #expect(before.colorTag == "teal" && before.renderingVersion == "old" && before.noteId == "N")
        let recoloured = try store.recolorHighlight("a0000000-0000-0000-0000-000000000000", to: "blue", for: "owner")
        var expected = before
        expected.colorTag = "blue"
        #expect(recoloured == expected)
        #expect(try store.highlight(before.id, of: "owner") == expected)
        #expect(try store.recolorHighlight(before.id, to: "blue", for: "owner") == expected, "the same colour changes nothing")
        #expect(throws: HighlightStoreError.highlightNotFound("not-an-id")) {
            try store.recolorHighlight("not-an-id", to: "pink", for: "owner")
        }
    }

    /// The reader's Remove deletes the highlight it was asked about, by id, where the app's fetch by
    /// offsets takes the first of two over the same text.
    @Test func aDeleteTakesOneHighlightAndLeavesAnyOtherOverTheSameText() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let first = try store.createHighlight(in: Self.d1, start: 5, end: 9, colorTag: "yellow", selectedText: "same",
                                              renderingVersion: "v", for: "owner", at: Self.created)
        let second = try store.createHighlight(in: Self.d1, start: 5, end: 9, colorTag: "yellow", selectedText: "same",
                                               renderingVersion: "v", for: "owner", at: Self.later)
        #expect(try store.highlights(of: Self.d1, for: "owner") == [first, second], "the app makes another over the same text")
        try store.deleteHighlight(second.id.lowercased(), for: "owner")
        #expect(try store.highlights(of: Self.d1, for: "owner") == [first])
        #expect(throws: HighlightStoreError.highlightNotFound(second.id)) { try store.deleteHighlight(second.id, for: "owner") }
        #expect(throws: HighlightStoreError.highlightNotFound("x")) { try store.deleteHighlight("x", for: "owner") }
        #expect(try rows.highlightCount() == 1)
    }

    @Test func eachUsersHighlightsAreTheirsAlone() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        let theirs = try store.createHighlight(in: Self.d1, start: 0, end: 3, colorTag: "blue", selectedText: "", renderingVersion: "",
                                               for: "reader", at: Self.created)
        #expect(try store.highlights(of: Self.d1, for: "owner") == [])
        #expect(try store.highlights(for: "owner") == [])
        #expect(try store.highlight(theirs.id, of: "owner") == nil)
        #expect(throws: HighlightStoreError.highlightNotFound(theirs.id)) { try store.recolorHighlight(theirs.id, to: "pink", for: "owner") }
        #expect(throws: HighlightStoreError.highlightNotFound(theirs.id)) { try store.deleteHighlight(theirs.id, for: "owner") }
        #expect(try store.highlights(of: Self.d1, for: "reader") == [theirs])
        #expect(try rows.highlightCount(user: "reader") == 1)
    }
}
