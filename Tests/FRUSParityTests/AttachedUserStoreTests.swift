// The kit's search of a user's own half (FRUS-Explorer#1806, `SearchUserSource.attachedStore(userId:)`)
// over each user store's search database (S14d): app.db itself, or the PostgreSQL store's local copy.
// The fixture index is served read-only, as Import mode serves it, with the store's file attached, and
// a user's notes, summaries and tags, written through the store's own methods, are found through it:
// theirs alone, in the scopes searched, with a row's tags and the tag counts the store holds; and each
// change is found by the next search, as the store writes the file in the call that makes it. S17d's
// search routes stand on this. Part of the user store's conformance suite, on every store
// `UserStoreKind.available` names.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import FTS5Store
import Foundation
import Testing

@Suite struct AttachedUserStoreTests {
    static let volume = "frus1961-63v06"
    static let time = Date(timeIntervalSince1970: 1_792_800_000)

    static func document(_ id: String) -> DocumentKey { DocumentKey(volumeId: volume, documentId: id) }

    /// A search's documents, as `volume/document`.
    static func keys(_ results: [SearchResult]) -> Set<String> { Set(results.map { "\($0.volumeId)/\($0.documentId)" }) }

    static func keys(_ documents: String...) -> Set<String> { Set(documents.map { "\(volume)/\($0)" }) }

    @Test(arguments: UserStoreKind.available)
    func theKitsSearchReadsTheStoresSearchDatabase(_ kind: UserStoreKind) async throws {
        let built = try await FixtureIndex.value()
        let copy = try ReadOnlyOpenTests.Copy(built)
        let test = try await TestUserStore.open(kind)
        defer { test.close() }
        let store = test.store
        try test.rows.addUser("reader")
        func note(_ text: String, on document: String, for user: String = "owner") throws -> NoteRecord {
            try store.createNote(in: Self.document(document), bodyText: text, richText: nil, projectIds: [], userTagIds: [],
                                 selectedSummaryIds: [], linkedHighlightId: nil, for: user, at: Self.time)
        }
        let cable = try note("Zanzibar cable on the talks", on: "d1")
        _ = try note("Two zanzibars, and a third", on: "d2")
        _ = try store.createOwnSummary(in: Self.document("d3"), text: "A quixotic proposal", responseFormat: #"{"general":{}}"#,
                                       for: "owner", at: Self.time)
        _ = try note("Their zanzibar", on: "d4", for: "reader")
        let laos = try store.createTag(named: "Laos", for: "owner", at: Self.time)
        let cuba = try store.createTag(named: "Cuba", for: "owner", at: Self.time)
        try store.setTags([laos.id, cuba.id], of: Self.document("d1"), for: "owner", at: Self.time)
        try store.setTags([laos.id], of: Self.document("d3"), for: "owner", at: Self.time)

        let fts5 = try FTS5Store(readingDatabaseAt: copy.database)
        let pipeline = try IndexingPipeline(readingIndexAt: copy.database, fts5Store: fts5, resources: built.index.pipeline.resources,
                                            userStore: store.searchDatabase)
        let owner = SearchService(fts5Store: fts5, pipeline: pipeline, userSource: .attachedStore(userId: "owner"))
        let reader = SearchService(fts5Store: fts5, pipeline: pipeline, userSource: .attachedStore(userId: "reader"))

        // Notes and summaries, each user's own, in the scopes searched.
        let zanzibar = SearchParameters(keywords: "zanzibar", includeDocumentText: false)
        #expect(Self.keys(try await owner.search(parameters: zanzibar)) == Self.keys("d1", "d2"), "porter stems a note's words")
        #expect(Self.keys(try await reader.search(parameters: zanzibar)) == Self.keys("d4"), "the other user's own")
        #expect(Self.keys(try await owner.search(parameters: SearchParameters(keywords: "quixotic", includeDocumentText: false,
                                                                              includeNotes: false))) == Self.keys("d3"))
        #expect(try await owner.searchCount(parameters: SearchParameters(keywords: "quixotic", includeDocumentText: false,
                                                                         includeSummaries: false)) == 0, "a summary is not a note")
        #expect(Self.keys(try await owner.search(parameters: SearchParameters(keywords: "=Zanzibar", includeDocumentText: false)))
                == Self.keys("d1"), "the exact word reads the note's own text")

        // Tags: the filter, a row's tags and the counts, from the assignments the store holds.
        let either = SearchParameters(keywords: "zanzibar quixotic", booleanMode: .or, includeDocumentText: false)
        var tagged = either
        tagged.userTagIds = [laos.id]
        #expect(Self.keys(try await owner.search(parameters: tagged)) == Self.keys("d1", "d3"))
        tagged.userTagIds = [cuba.id.lowercased()]
        #expect(Self.keys(try await owner.search(parameters: tagged)) == Self.keys("d1"), "an id in any case")
        let rows = try await owner.search(parameters: either)
        #expect(rows.first { $0.documentId == "d1" }?.userTagIds == [laos.id, cuba.id].sorted())
        #expect(rows.first { $0.documentId == "d2" }?.userTagIds == [])
        #expect(try await owner.userTagCounts(parameters: either, tagIds: [laos.id, cuba.id]) == [laos.id: 2, cuba.id: 1])

        // Each change is in the next search.
        try store.removeTag(cuba.id, from: Self.document("d1"), for: "owner")
        try store.deleteNote(cable.id, for: "owner")
        _ = try note("A last zanzibar", on: "d5")
        #expect(Self.keys(try await owner.search(parameters: zanzibar)) == Self.keys("d2", "d5"))
        #expect(try await owner.userTagCounts(parameters: either, tagIds: [laos.id, cuba.id])[cuba.id, default: 0] == 0)
        _ = try store.importResearch(ResearchImportBatch(rows: ["tag_assignments": [ImportRow(values: [
            "id": .text("5E14D000-0000-4000-8000-000000000001"), "volume_id": .text(Self.volume), "document_id": .text("d5"),
            "tag_id": .text(cuba.id.lowercased()), "created_at": .text("2026-01-01T00:00:00.000Z"),
        ])]]), for: "owner")
        tagged.userTagIds = [cuba.id]
        #expect(Self.keys(try await owner.search(parameters: tagged)) == Self.keys("d5"), "an import's assignment, kept as it came")
        #expect(Self.keys(try await reader.search(parameters: tagged)).isEmpty)
    }
}
