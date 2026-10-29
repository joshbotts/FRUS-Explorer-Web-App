// Collections and their entries in the user store (S18d), on every store the conformance suite runs
// on: a collection made with its entries and read with them, found by its id in any letter case, the
// user's alone; changed in one write that writes only what differs, adds and deletes entries, and
// takes a deleted entry's headnote draft with it but never a document's own summary; rolled back when
// the change throws; deleted with its entries and their drafts; and listed for the documents it holds.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserCollectionTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z
    static let collection = "C0110000-0000-4000-8000-000000000001"
    static let other = "C0110000-0000-4000-8000-000000000002"
    static let draft = "D2AF0000-0000-4000-8000-000000000001"
    static let ownSummary = "D2AF0000-0000-4000-8000-000000000002"

    static func entry(_ n: Int) -> String { String(format: "E0110000-0000-4000-8000-%012d", n) }

    static var stamp: SQLiteValue { .text(UserStoreDate.text(created)) }

    /// A collection's row, as the API writes one.
    static func collectionRow(_ id: String, _ name: String) -> [String: SQLiteValue] {
        ["id": .text(id), "name": .text(name), "project_ids": .text("[]"), "include_colophon": .integer(0),
         "include_project_provenance": .integer(0), "include_method_appendix": .integer(0), "default_body_depth": .text("full"),
         "footnote_style": .text("all"), "toc_style": .text("citation"), "apply_highlights": .integer(0), "include_notes": .integer(1),
         "include_word_cloud": .integer(0), "default_include_headnote": .integer(0), "created_at": stamp, "last_modified": stamp]
    }

    /// An entry's row: a document of frus1961-63v06's, or another kind with no document.
    static func entryRow(_ n: Int, of collection: String, kind: String = "document", document: String? = nil,
                         order: Int, headnote: String? = nil) -> [String: SQLiteValue] {
        ["id": .text(entry(n)), "collection_id": .text(collection), "document_id": .text(document ?? ""),
         "volume_id": .text(document == nil ? "" : "frus1961-63v06"), "sort_order": .integer(Int64(order)), "level": .integer(1),
         "selected_note_ids": .text("[]"), "selected_highlight_ids": .text("[]"), "kind": .text(kind),
         "headnote_summary_id": headnote.map { .text($0) } ?? .null, "created_at": stamp, "last_modified": stamp]
    }

    /// A summary's row: a collection's headnote draft, or a document's own.
    static func summaryRow(_ id: String, draft: Bool) -> [String: SQLiteValue] {
        ["id": .text(id), "document_id": .text("d1"), "volume_id": .text("frus1961-63v06"),
         "prompt_id": .text("0EAD0000-0000-4000-8000-000000000001"), "response_text": .text("A key takeaway."),
         "response_format": .text(#"{"plainText":{}}"#), "was_chunked": .integer(0), "is_headnote_draft": .integer(draft ? 1 : 0),
         "created_at": stamp, "last_modified": stamp]
    }

    static func ids(_ rows: [ExportRow]) -> [String] { rows.compactMap { $0.values["id"]?.text } }

    @Test(arguments: UserStoreKind.available)
    func aCollectionIsMadeWithItsEntriesAndReadWithThemTheUsersAlone(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        _ = try store.signedInUser("reader", at: Self.created)
        let made = try store.addCollection(CollectionChange(
            collection: Self.collectionRow(Self.collection, "Berlin"),
            entries: [Self.entryRow(1, of: Self.collection, kind: "heading", order: 0),
                      Self.entryRow(2, of: Self.collection, document: "d1", order: 1)]), for: "owner")
        #expect(made.collection.values["name"] == .text("Berlin"))
        #expect(Self.ids(made.entries) == [Self.entry(1), Self.entry(2)], "in the order the store took them")
        // Another user may hold a collection, and entries, under the same ids, as two imports give them.
        try store.addCollection(CollectionChange(collection: Self.collectionRow(Self.collection, "Theirs"),
                                                 entries: [Self.entryRow(1, of: Self.collection, order: 0)]), for: "reader")

        let found = try #require(try store.collectionRows(Self.collection.lowercased(), of: "owner"))
        #expect(found == made, "found in any letter case, each column as written")
        for (column, value) in Self.collectionRow(Self.collection, "Berlin") { #expect(found.collection.values[column] == value, "\(column)") }
        #expect(found.collection.values["subtitle"] == .null, "a column left out is NULL")
        #expect(try store.collectionRows(Self.collection, of: "reader")?.collection.values["name"] == .text("Theirs"))
        #expect(try store.collectionRows(Self.other, of: "owner") == nil)

        let (collections, entries) = try store.collectionRows(of: "owner")
        #expect(Self.ids(collections) == [Self.collection] && Self.ids(entries) == [Self.entry(1), Self.entry(2)])
        #expect(try store.collectionRows(of: "nobody").collections.isEmpty)

        // An id the user holds is refused, and so is a column a table lacks, writing nothing.
        #expect(throws: ResearchRowStoreError.invalidId(table: "collections", id: Self.collection)) {
            try store.addCollection(CollectionChange(collection: Self.collectionRow(Self.collection, "Again"), entries: []), for: "owner")
        }
        var unknown = Self.collectionRow(Self.other, "Other")
        unknown["colour"] = .text("red")
        #expect(throws: ResearchRowStoreError.unknownColumn(table: "collections", column: "colour")) {
            try store.addCollection(CollectionChange(collection: unknown, entries: []), for: "owner")
        }
        #expect(throws: ResearchRowStoreError.invalidId(table: "collection_entries", id: Self.entry(2))) {
            try store.addCollection(CollectionChange(collection: Self.collectionRow(Self.other, "Other"),
                                                     entries: [Self.entryRow(2, of: Self.other, order: 0)]), for: "owner")
        }
        // A summary the search reads is no collection's to add: a headnote draft alone.
        #expect(throws: ResearchRowStoreError.notAHeadnoteDraft(id: Self.ownSummary)) {
            try store.addCollection(CollectionChange(collection: Self.collectionRow(Self.other, "Other"), entries: [],
                                                     addedSummaries: [Self.summaryRow(Self.ownSummary, draft: false)]), for: "owner")
        }
        #expect(try store.collectionRows(Self.other, of: "owner") == nil, "nothing of a refused write")
    }

    /// A document's own summary, which an entry may choose for its headnote, made as the reader writes one.
    static func makeOwnSummary(in store: some SummaryStore) throws -> String {
        try store.createOwnSummary(in: DocumentKey(volumeId: "frus1961-63v06", documentId: "d1"), text: "A key takeaway.",
                                   responseFormat: #"{"general":{}}"#, for: "owner", at: created).id
    }

    /// A change writes the columns that differ and no other, adds the entries it gives under new ids,
    /// deletes those it leaves out, and a deleted entry's headnote draft with it, but never a summary
    /// an entry chose that is no draft; it answers the rows as they then stand.
    @Test(arguments: UserStoreKind.available)
    func aChangeWritesWhatDiffersAndDeletesAnEntrysDraftWithIt(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let own = try Self.makeOwnSummary(in: store)
        try store.addCollection(CollectionChange(
            collection: Self.collectionRow(Self.collection, "Berlin"),
            entries: [Self.entryRow(1, of: Self.collection, document: "d1", order: 0, headnote: Self.draft),
                      Self.entryRow(2, of: Self.collection, document: "d2", order: 1, headnote: own),
                      Self.entryRow(3, of: Self.collection, kind: "prose", order: 2)],
            addedSummaries: [Self.summaryRow(Self.draft, draft: true)]), for: "owner")
        let mark = try store.searchMark()
        #expect(try rows.rows(of: "summaries").count == 2)

        let changed = try #require(try store.changeCollection(Self.collection, for: "owner") { held in
            var collection = held.collection.values
            collection["name"] = .text("Berlin, 1961")
            var entries = held.entries.map(\.values)
            entries.removeAll { $0["id"] == .text(Self.entry(1)) }
            entries.removeAll { $0["id"] == .text(Self.entry(2)) }
            entries[0]["sort_order"] = .integer(0)
            entries.append(Self.entryRow(4, of: Self.collection, kind: "heading", order: 1))
            return CollectionChange(collection: collection, entries: entries)
        })
        #expect(changed.collection.values["name"] == .text("Berlin, 1961"))
        #expect(Self.ids(changed.entries) == [Self.entry(3), Self.entry(4)])
        #expect(changed.entries[0].values["sort_order"] == .integer(0) && changed.entries[1].values["kind"] == .text("heading"))
        #expect(try rows.rows(of: "summaries").count == 1, "the deleted entry's draft went with it")
        #expect(try store.researchRow(UserStoreSchema.table(for: "GeneratedSummary")!, id: own, of: "owner") != nil,
                "a document's own summary an entry chose stays")
        #expect(try store.searchMark() == mark, "no collection write moves the search mark")

        // A change that answers nothing writes nothing; one that throws, nothing either; one for a
        // collection the user does not hold is nil.
        let unchanged = try store.changeCollection(Self.collection, for: "owner") { _ in nil }
        #expect(unchanged == changed)
        struct Refused: Error {}
        #expect(throws: Refused.self) {
            try store.changeCollection(Self.collection, for: "owner") { held in
                var collection = held.collection.values
                collection["name"] = .text("Lost")
                _ = collection
                throw Refused()
            }
        }
        #expect(try store.collectionRows(Self.collection, of: "owner") == changed)
        #expect(throws: ResearchRowStoreError.unknownColumn(table: "collection_entries", column: "colour")) {
            try store.changeCollection(Self.collection, for: "owner") { held in
                var entries = held.entries.map(\.values)
                entries[0]["colour"] = .text("red")
                return CollectionChange(collection: held.collection.values, entries: entries)
            }
        }
        #expect(try store.changeCollection(Self.other, for: "owner") { _ in Issue.record("not asked"); return nil } == nil)
    }

    @Test(arguments: UserStoreKind.available)
    func aCollectionIsDeletedWithItsEntriesAndTheirDrafts(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        _ = try store.signedInUser("reader", at: Self.created)
        let own = try Self.makeOwnSummary(in: store)
        try store.addCollection(CollectionChange(
            collection: Self.collectionRow(Self.collection, "Berlin"),
            entries: [Self.entryRow(1, of: Self.collection, document: "d1", order: 0, headnote: Self.draft),
                      Self.entryRow(2, of: Self.collection, document: "d2", order: 1, headnote: own)],
            addedSummaries: [Self.summaryRow(Self.draft, draft: true)]), for: "owner")
        try store.addCollection(CollectionChange(collection: Self.collectionRow(Self.collection, "Theirs"),
                                                 entries: [Self.entryRow(1, of: Self.collection, order: 0)]), for: "reader")
        #expect(try store.deleteCollection(Self.collection.lowercased(), for: "owner"))
        #expect(try store.collectionRows(Self.collection, of: "owner") == nil)
        #expect(try store.collectionRows(of: "owner").entries.isEmpty)
        #expect(try rows.rows(of: "summaries").count == 1, "its draft, not the document's own summary")
        #expect(try store.collectionRows(Self.collection, of: "reader")?.entries.count == 1, "another user's are theirs")
        #expect(try !store.deleteCollection(Self.collection, for: "owner"))
    }

    /// The Research rail's collections: those holding the document as a document entry, an excerpt of
    /// it not counting, each once.
    @Test(arguments: UserStoreKind.available)
    func theCollectionsHoldingADocumentAreThoseWithADocumentEntryForIt(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try store.addCollection(CollectionChange(
            collection: Self.collectionRow(Self.collection, "Berlin"),
            entries: [Self.entryRow(1, of: Self.collection, document: "d1", order: 0),
                      Self.entryRow(2, of: Self.collection, document: "d1", order: 1)]), for: "owner")
        try store.addCollection(CollectionChange(
            collection: Self.collectionRow(Self.other, "Excerpts"),
            entries: [Self.entryRow(3, of: Self.other, kind: "excerpt", document: "d1", order: 0)]), for: "owner")
        #expect(Self.ids(try store.collections(holding: "frus1961-63v06", "d1", of: "owner")) == [Self.collection])
        #expect(try store.collections(holding: "frus1961-63v06", "d2", of: "owner").isEmpty)
        #expect(try store.collections(holding: "frus1961-63v06", "d1", of: "reader").isEmpty)
    }
}
