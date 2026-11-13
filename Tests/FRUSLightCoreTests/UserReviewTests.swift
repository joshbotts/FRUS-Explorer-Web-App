// The review ledger in the user store (PLAN's S21f), as the app keeps `AnnotationReview`: a document's review
// recorded once under the app's derived id however often it is recorded, each user's their own; and a
// highlight anchored to the text as it reads now, its version and, for Move Here, its offsets, and nothing else.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import FRUSCoreKit
import FTS5Store
import Testing

@Suite struct UserReviewTests {
    static let at = Date(timeIntervalSince1970: 1_792_800_000.1234)  // 2026-10-24T00:00:00.123Z, rounded
    static let d2 = DocumentKey(volumeId: "frus1894Nicaragua", documentId: "d2")

    @Test(arguments: UserStoreKind.available) func aReviewIsRecordedOnceUnderTheAppsId(_ kind: UserStoreKind) async throws {
        let (store, _, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        _ = try store.signedInUser("bob", at: Self.at)
        let first = try store.recordDocumentReview(of: Self.d2, contentHash: "c1", changeKind: "body", for: "owner", at: Self.at)
        #expect(first.id == AnnotationReviewLedger.derivedId(kind: "document", annotationId: nil, volumeId: "frus1894Nicaragua",
                                                            documentId: "d2", contentHash: "c1", changeKind: "body"))
        #expect(UUID(uuidString: first.id)?.uuidString == first.id, "an uppercase uuidString, as the app's ids are")
        #expect(first.annotationType == "document" && first.annotationId == nil && first.contentHash == "c1" && first.changeKind == "body")
        #expect(first.reviewedAt == UserStoreDate.rounded(Self.at))
        // Recorded again, later: the row the user has, kept as it is.
        let again = try store.recordDocumentReview(of: Self.d2, contentHash: "c1", changeKind: "body", for: "owner",
                                                   at: Self.at.addingTimeInterval(60))
        #expect(again == first)
        #expect(try store.documentReviews(of: Self.d2, for: "owner") == [first])
        // Another change of the same document, a row of its own; a change of no kind, as the app records one.
        let apparatus = try store.recordDocumentReview(of: Self.d2, contentHash: "c2", changeKind: "apparatus", for: "owner", at: Self.at)
        let none = try store.recordDocumentReview(of: Self.d2, contentHash: "c3", changeKind: nil, for: "owner", at: Self.at)
        #expect(none.changeKind == nil && none.id != apparatus.id && apparatus.id != first.id)
        #expect(Set(try store.documentReviews(for: "owner").map(\.id)) == [first.id, apparatus.id, none.id])
        // Each user's their own: bob has none until he records his, under the same id as the owner's.
        #expect(try store.documentReviews(of: Self.d2, for: "bob").isEmpty)
        let bobs = try store.recordDocumentReview(of: Self.d2, contentHash: "c1", changeKind: "body", for: "bob", at: Self.at)
        #expect(bobs.id == first.id)
        #expect(try store.documentReviews(of: Self.d2, for: "bob") == [bobs])
        let every = try store.everyDocumentReview()
        #expect(every.keys.sorted() == ["bob", "owner"] && every["owner"]?.count == 3 && every["bob"] == [bobs])
        #expect(try store.documentReviews(of: DocumentKey(volumeId: "frus1894Nicaragua", documentId: "d3"), for: "owner").isEmpty)
    }

    /// The ledger's rule for a change, the kit's `applyAnnotationReviews`' match: a document row of the same
    /// document, content hash and change kind, and only for a change the index stamped.
    @Test func theLedgerReviewsAChangeOfItsHashAndKindAlone() async throws {
        func row(_ hash: String, _ kind: String?, type: String = "document", document: String = "d2") -> AnnotationReviewRecord {
            AnnotationReviewRecord(id: "x", annotationType: type, annotationId: nil, volumeId: "frus1894Nicaragua", documentId: document,
                                   contentHash: hash, changeKind: kind, reviewedAt: nil)
        }
        let scratch = try await ScratchRevisions()
        defer { withExtendedLifetime(scratch) {} }
        let ledger = [row("c1", "body"), row("c2", nil), row("c4", "apparatus", type: "note"), row("c5", "body", document: "d3")]
        #expect(AnnotationReviewLedger.reviews([row("c1", "body")], try await scratch.row("c1", "body")))
        #expect(!AnnotationReviewLedger.reviews(ledger, try await scratch.row("c1", "apparatus")), "another kind of change at the same text")
        #expect(!AnnotationReviewLedger.reviews(ledger, try await scratch.row("c9", "body")), "another text")
        #expect(!AnnotationReviewLedger.reviews(ledger, try await scratch.row("c4", "apparatus")), "a note's row is no document's review")
        #expect(!AnnotationReviewLedger.reviews(ledger, try await scratch.row("c5", "body")), "another document's")
        #expect(!AnnotationReviewLedger.reviews([row("c1", "body")], try await scratch.row("c1", "body", stamped: false)), "no change stamped")
    }

    @Test(arguments: UserStoreKind.available) func aHighlightIsAnchoredKeepingItsWords(_ kind: UserStoreKind) async throws {
        let (store, _, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let made = try store.createHighlight(in: Self.d2, start: 120, end: 183, colorTag: "green", selectedText: "the words",
                                             renderingVersion: "0000000000000001", for: "owner", at: Self.at)
        // Confirm: the version alone.
        let confirmed = try store.anchorHighlight(made.id, renderingVersion: "0000000000000002", span: nil, for: "owner")
        #expect(confirmed == HighlightRecord(id: made.id, volumeId: "frus1894Nicaragua", documentId: "d2", startOffset: 120, endOffset: 183,
                                             colorTag: "green", noteId: nil, selectedText: "the words",
                                             renderingVersion: "0000000000000002", createdAt: made.createdAt))
        #expect(try store.highlight(made.id, of: "owner") == confirmed)
        // Move Here: the offsets and the version, its words, colour and time kept.
        let moved = try store.anchorHighlight(made.id.lowercased(), renderingVersion: "0000000000000003", span: (122, 185), for: "owner")
        #expect(moved.startOffset == 122 && moved.endOffset == 185 && moved.renderingVersion == "0000000000000003")
        #expect(moved.selectedText == "the words" && moved.colorTag == "green" && moved.createdAt == made.createdAt)
        #expect(try store.highlight(made.id, of: "owner") == moved)
        #expect(throws: HighlightStoreError.highlightNotFound("nope")) {
            try store.anchorHighlight("nope", renderingVersion: "0000000000000004", span: nil, for: "owner")
        }
        _ = try store.signedInUser("bob", at: Self.at)
        #expect(throws: HighlightStoreError.highlightNotFound(made.id)) {
            try store.anchorHighlight(made.id, renderingVersion: "0000000000000004", span: nil, for: "bob")
        }
    }

}

/// Revision rows the kit reads, from a scratch index of the kit's schema whose `document_revisions` the test writes,
/// as an update's pass leaves one.
struct ScratchRevisions {
    let directory: TemporaryDirectory
    let url: URL
    let pipeline: IndexingPipeline

    init() async throws {
        directory = try TemporaryDirectory()
        url = directory.url.appendingPathComponent("scratch.db")
        pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: url), databaseURL: url, volumesDirectory: directory.url,
                                        resources: try IndexingResources.loading(fromDirectory: RepositoryFiles.resources),
                                        defaults: InMemoryIndexingStampStore())
    }

    /// d2's row, given `hash` and `kind`, stamped or not, as the kit reads it.
    func row(_ hash: String, _ kind: String?, stamped: Bool = true) async throws -> IndexingPipeline.DocumentRevision {
        let db = try SQLiteConnection(url.path, readOnly: false)
        defer { db.close() }
        _ = try db.query("DELETE FROM document_revisions")
        _ = try db.query("""
            INSERT INTO document_revisions (volume_id, document_id, content_hash, body_hash, changed_at, change_kind, reviewed_at, index_version)
            VALUES ('frus1894Nicaragua', 'd2', ?, '0000000000000001', ?, ?, NULL, ?)
            """, [.text(hash), stamped ? .text("2026-11-13T00:00:00Z") : .null,
                  kind.map { SQLiteValue.text($0) } ?? .null, .integer(Int64(IndexingPipeline.currentDateIndexVersion))])
        return try #require(try await pipeline.documentRevision(volumeId: "frus1894Nicaragua", documentId: "d2"))
    }
}
