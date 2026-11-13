// The review ledger (PLAN's S21f): the store's `annotation_reviews`, the app's `AnnotationReview` rows, one for
// each change a user has reviewed, which the app writes when a reader marks a document reviewed and syncs to
// the reader's other devices, so that each stamps its own index with the kit's `applyAnnotationReviews`. Here
// each user is a reader and the server one device: a user's rows say which changes they have reviewed, and
// the index's `reviewed_at` that someone has. A row's id is the app's, derived from what it records, so that a
// review recorded twice is one row, as the app's `AnnotationReviewStore.record` keeps it, and a row an import
// brings from the Mac is the row the web would write.

import Crypto
import FRUSCoreKit
import Foundation

/// One row of a user's ledger, as the store keeps the Mac's `AnnotationReview`.
public struct AnnotationReviewRecord: Sendable, Equatable {
    /// The app's derived id, an uppercase `uuidString`.
    public var id: String
    /// `document`, `note`, `tag`, `collectionEntry`, `summary` or `visitDocument`: the app's kinds, of which the
    /// web records `document`, as the app's review sheet does.
    public var annotationType: String
    public var annotationId: String?
    public var volumeId: String
    public var documentId: String
    /// The `content_hash` of the change the user reviewed.
    public var contentHash: String
    /// The `change_kind` of the change the user reviewed, `body`, `apparatus` or `vanished`.
    public var changeKind: String?
    public var reviewedAt: Date?

    public init(id: String, annotationType: String, annotationId: String?, volumeId: String, documentId: String,
                contentHash: String, changeKind: String?, reviewedAt: Date?) {
        self.id = id
        self.annotationType = annotationType
        self.annotationId = annotationId
        self.volumeId = volumeId
        self.documentId = documentId
        self.contentHash = contentHash
        self.changeKind = changeKind
        self.reviewedAt = reviewedAt
    }

    /// The row as the kit's `applyAnnotationReviews` reads it.
    public var data: AnnotationReviewData {
        AnnotationReviewData(annotationType: annotationType, volumeId: volumeId, documentId: documentId,
                             contentHash: contentHash, changeKind: changeKind)
    }
}

/// The app's ledger rules, mirrored from `FRUSExplorer/Models/AnnotationReview.swift` (app code, a SwiftData
/// model's file) and held to its source by `UpdateReviewParityTests`.
public enum AnnotationReviewLedger {
    /// The kind of row the review sheet's Mark Reviewed records: `AnnotationReviewKind.document`.
    public static let documentKind = "document"

    /// `AnnotationReview.derivedId(kind:annotationId:volumeId:documentId:contentHash:changeKind:)`: a version-8
    /// UUID of the SHA-256 of what the row records, so that the same review recorded on two devices, or twice,
    /// is one row.
    public static func derivedId(kind: String, annotationId: String?, volumeId: String, documentId: String,
                                 contentHash: String, changeKind: String?) -> String {
        let key = "AnnotationReview|\(kind)|\(annotationId ?? "-")|\(volumeId)/\(documentId)|\(contentHash)|\(changeKind ?? "-")"
        let digest = SHA256.hash(data: Data(key.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80   // version nibble: 8 (custom, deterministic)
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC-4122 variant: 10xxxxxx
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15])).uuidString
    }

    /// Whether a ledger's document rows review `revision`, a change the index stamped: a row of the same
    /// document whose content hash and change kind are the change's, the match the kit's
    /// `applyAnnotationReviews` makes before it stamps a device's row (`WHERE volume_id = ? AND document_id = ?
    /// AND content_hash = ? AND change_kind IS ?`), held to the kit by `UpdateReviewParityTests`. A change the
    /// index has not stamped is no change to review.
    public static func reviews(_ rows: [AnnotationReviewRecord], _ revision: IndexingPipeline.DocumentRevision) -> Bool {
        guard revision.changedAt != nil else { return false }
        return rows.contains {
            $0.annotationType == documentKind && $0.volumeId == revision.volumeId && $0.documentId == revision.documentId
                && $0.contentHash == revision.contentHash && $0.changeKind == revision.changeKind
        }
    }
}

/// Where a user's review ledger is kept.
public protocol AnnotationReviewStore: Sendable {
    /// The user's ledger rows of the `document` kind, by volume and document, then by id.
    func documentReviews(for user: String) throws -> [AnnotationReviewRecord]
    /// The user's ledger rows of the `document` kind on one document.
    func documentReviews(of document: DocumentKey, for user: String) throws -> [AnnotationReviewRecord]
    /// Every user's ledger rows of the `document` kind, by user id, for the index's own record that a change was reviewed.
    func everyDocumentReview() throws -> [String: [AnnotationReviewRecord]]
    /// Records that the user reviewed a document's change, the content hash and change kind the index stamped,
    /// as the app's `AnnotationReviewStore.record` does: a row with the app's derived id, or the row of that id
    /// the user has already, kept as it is.
    @discardableResult func recordDocumentReview(of document: DocumentKey, contentHash: String, changeKind: String?,
                                                 for user: String, at now: Date) throws -> AnnotationReviewRecord
}

extension RelationalUserStore: AnnotationReviewStore {
    private static let reviewColumns = """
        id, annotation_type, annotation_id, volume_id, document_id, content_hash, change_kind, reviewed_at
        """

    public func documentReviews(for user: String) throws -> [AnnotationReviewRecord] {
        try reading { db in
            try db.query(
                """
                SELECT \(Self.reviewColumns) FROM annotation_reviews WHERE user_id = ? AND annotation_type = ?
                    ORDER BY volume_id, document_id, upper(id)
                """, [.text(user), .text(AnnotationReviewLedger.documentKind)]).map(Self.review)
        }
    }

    public func documentReviews(of document: DocumentKey, for user: String) throws -> [AnnotationReviewRecord] {
        try reading { db in
            try db.query(
                """
                SELECT \(Self.reviewColumns) FROM annotation_reviews
                    WHERE user_id = ? AND annotation_type = ? AND volume_id = ? AND document_id = ?
                    ORDER BY upper(id)
                """, [.text(user), .text(AnnotationReviewLedger.documentKind), .text(document.volumeId), .text(document.documentId)])
                .map(Self.review)
        }
    }

    public func everyDocumentReview() throws -> [String: [AnnotationReviewRecord]] {
        try reading { db in
            var reviews: [String: [AnnotationReviewRecord]] = [:]
            for row in try db.query(
                """
                SELECT user_id, \(Self.reviewColumns) FROM annotation_reviews WHERE annotation_type = ?
                    ORDER BY user_id, volume_id, document_id, upper(id)
                """, [.text(AnnotationReviewLedger.documentKind)]) {
                reviews[row[0].text ?? "", default: []].append(Self.review(Array(row.dropFirst())))
            }
            return reviews
        }
    }

    @discardableResult
    public func recordDocumentReview(of document: DocumentKey, contentHash: String, changeKind: String?,
                                     for user: String, at now: Date) throws -> AnnotationReviewRecord {
        let id = AnnotationReviewLedger.derivedId(kind: AnnotationReviewLedger.documentKind, annotationId: nil,
                                                  volumeId: document.volumeId, documentId: document.documentId,
                                                  contentHash: contentHash, changeKind: changeKind)
        // Outside the search mark: no row of the ledger is what the kit's search reads.
        return try writing(outsideSearch: true) { db in
            if let row = try db.query("SELECT \(Self.reviewColumns) FROM annotation_reviews WHERE user_id = ? AND upper(id) = ?",
                                      [.text(user), .text(id)]).first {
                return Self.review(row)
            }
            _ = try db.query(
                "INSERT INTO annotation_reviews (user_id, \(Self.reviewColumns)) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [.text(user), .text(id), .text(AnnotationReviewLedger.documentKind), .null, .text(document.volumeId),
                 .text(document.documentId), .text(contentHash), changeKind.map { SQLiteValue.text($0) } ?? SQLiteValue.null,
                 .text(UserStoreDate.text(now))])
            return AnnotationReviewRecord(id: id, annotationType: AnnotationReviewLedger.documentKind, annotationId: nil,
                                          volumeId: document.volumeId, documentId: document.documentId, contentHash: contentHash,
                                          changeKind: changeKind, reviewedAt: UserStoreDate.rounded(now))
        }
    }

    private static func review(_ row: [SQLiteValue]) -> AnnotationReviewRecord {
        AnnotationReviewRecord(id: row[0].text ?? "", annotationType: row[1].text ?? "", annotationId: row[2].text,
                               volumeId: row[3].text ?? "", documentId: row[4].text ?? "", contentHash: row[5].text ?? "",
                               changeKind: row[6].text, reviewedAt: row[7].text.flatMap(UserStoreDate.date))
    }
}
