// Highlights (PLAN's S15c), kept as the app keeps `DocumentHighlight`: offsets into a document's flat
// text, its colour, the text it held and the rendering version it was made at, each kept verbatim.
// What the reader computes for a new one, its text and version, is the kit's, in the API's route;
// the store keeps what it is given.

import Foundation

/// One of a user's highlights, as the store keeps the Mac's `DocumentHighlight`.
public struct HighlightRecord: Sendable, Equatable {
    /// The Mac's id, an uppercase `uuidString`.
    public var id: String
    public var volumeId: String
    public var documentId: String
    /// UTF-16 offsets into the document's flat text, the first included and the last not.
    public var startOffset: Int
    public var endOffset: Int
    /// yellow, green, blue or pink, as the app writes `HighlightColor`'s raw values; kept as stored.
    public var colorTag: String
    /// The note it is linked to (S15d), a plain id, as the app keeps it.
    public var noteId: String?
    public var selectedText: String
    public var renderingVersion: String
    public var createdAt: Date?

    public init(id: String, volumeId: String, documentId: String, startOffset: Int, endOffset: Int, colorTag: String,
                noteId: String?, selectedText: String, renderingVersion: String, createdAt: Date?) {
        self.id = id
        self.volumeId = volumeId
        self.documentId = documentId
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.colorTag = colorTag
        self.noteId = noteId
        self.selectedText = selectedText
        self.renderingVersion = renderingVersion
        self.createdAt = createdAt
    }

    public var document: DocumentKey { DocumentKey(volumeId: volumeId, documentId: documentId) }
}

/// Why the store refused a change to highlights.
public enum HighlightStoreError: Error, Equatable, CustomStringConvertible {
    /// The user has no highlight with this id.
    case highlightNotFound(String)

    public var description: String {
        switch self {
        case .highlightNotFound(let id): "no highlight has the id \(id)"
        }
    }
}

/// Where a user's highlights are kept.
public protocol HighlightStore: Sendable {
    /// A document's highlights in the order the app's reader draws them, its `@Query` sorted by
    /// `createdAt`: oldest first, one with no time before any with one, as the app's SQLite store
    /// sorts a nil (`NULLS FIRST`, which PostgreSQL does not assume). The app's query leaves two of
    /// one time to its store; here they go by id in uppercase, the web's own, so they keep an order.
    func highlights(of document: DocumentKey, for user: String) throws -> [HighlightRecord]
    /// All the user's highlights, by volume and document, each document's in that order.
    func highlights(for user: String) throws -> [HighlightRecord]
    /// One of the user's highlights, or nil.
    func highlight(_ id: String, of user: String) throws -> HighlightRecord?
    /// Keeps a new highlight on a document as it is given, with a new id and `now` as its time, and
    /// no note.
    @discardableResult func createHighlight(in document: DocumentKey, start: Int, end: Int, colorTag: String,
                                            selectedText: String, renderingVersion: String, for user: String,
                                            at now: Date) throws -> HighlightRecord
    /// Gives a highlight another colour, keeping its id, offsets, text, version and time. Throws
    /// `HighlightStoreError.highlightNotFound` for an id the user has no highlight for.
    @discardableResult func recolorHighlight(_ id: String, to colorTag: String, for user: String) throws -> HighlightRecord
    /// Deletes a highlight. A note linked to it stays, as the app keeps one. Throws
    /// `HighlightStoreError.highlightNotFound` for an id the user has no highlight for.
    func deleteHighlight(_ id: String, for user: String) throws
}

extension RelationalUserStore: HighlightStore {
    /// The order `highlights(of:for:)` gives.
    private static let drawingOrder = "created_at ASC NULLS FIRST, upper(id)"

    private static let highlightColumns = """
        id, volume_id, document_id, start_offset, end_offset, color_tag, note_id, selected_text, rendering_version, created_at
        """

    public func highlights(of document: DocumentKey, for user: String) throws -> [HighlightRecord] {
        try reading { db in
            try db.query(
                """
                SELECT \(Self.highlightColumns) FROM highlights WHERE user_id = ? AND volume_id = ? AND document_id = ?
                    ORDER BY \(Self.drawingOrder)
                """, [.text(user), .text(document.volumeId), .text(document.documentId)]).map(Self.highlight)
        }
    }

    public func highlights(for user: String) throws -> [HighlightRecord] {
        try reading { db in
            try db.query(
                "SELECT \(Self.highlightColumns) FROM highlights WHERE user_id = ? ORDER BY volume_id, document_id, \(Self.drawingOrder)",
                [.text(user)]).map(Self.highlight)
        }
    }

    public func highlight(_ id: String, of user: String) throws -> HighlightRecord? {
        guard let id = TagReferences.normalized(id) else { return nil }
        return try reading { try Self.highlight(id, of: user, in: $0) }
    }

    @discardableResult
    public func createHighlight(in document: DocumentKey, start: Int, end: Int, colorTag: String, selectedText: String,
                                renderingVersion: String, for user: String, at now: Date) throws -> HighlightRecord {
        let highlight = HighlightRecord(id: UUID().uuidString, volumeId: document.volumeId, documentId: document.documentId,
                                        startOffset: start, endOffset: end, colorTag: colorTag, noteId: nil,
                                        selectedText: selectedText, renderingVersion: renderingVersion,
                                        createdAt: UserStoreDate.rounded(now))
        try writing { db in
            _ = try db.query(
                "INSERT INTO highlights (user_id, \(Self.highlightColumns)) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [.text(user), .text(highlight.id), .text(highlight.volumeId), .text(highlight.documentId),
                 .integer(Int64(start)), .integer(Int64(end)), .text(colorTag), .null, .text(selectedText),
                 .text(renderingVersion), .text(UserStoreDate.text(now))])
        }
        return highlight
    }

    @discardableResult
    public func recolorHighlight(_ id: String, to colorTag: String, for user: String) throws -> HighlightRecord {
        try writing { db in
            guard let key = TagReferences.normalized(id), var highlight = try Self.highlight(key, of: user, in: db) else {
                throw HighlightStoreError.highlightNotFound(id)
            }
            guard highlight.colorTag != colorTag else { return highlight }
            highlight.colorTag = colorTag
            _ = try db.query("UPDATE highlights SET color_tag = ? WHERE user_id = ? AND upper(id) = ?",
                             [.text(colorTag), .text(user), .text(key)])
            return highlight
        }
    }

    public func deleteHighlight(_ id: String, for user: String) throws {
        try writing { db in
            guard let key = TagReferences.normalized(id), try Self.highlight(key, of: user, in: db) != nil else {
                throw HighlightStoreError.highlightNotFound(id)
            }
            _ = try db.query("DELETE FROM highlights WHERE user_id = ? AND upper(id) = ?", [.text(user), .text(key)])
        }
    }

    // MARK: Within a transaction

    private static func highlight(_ row: [SQLiteValue]) -> HighlightRecord {
        HighlightRecord(id: row[0].text ?? "", volumeId: row[1].text ?? "", documentId: row[2].text ?? "",
                        startOffset: Int(row[3].integer ?? 0), endOffset: Int(row[4].integer ?? 0),
                        colorTag: row[5].text ?? "", noteId: row[6].text, selectedText: row[7].text ?? "",
                        renderingVersion: row[8].text ?? "", createdAt: row[9].text.flatMap(UserStoreDate.date))
    }

    private static func highlight(_ id: String, of user: String, in db: UserStoreTransaction) throws -> HighlightRecord? {
        // An id in any case, as an import may write one.
        try db.query("SELECT \(highlightColumns) FROM highlights WHERE user_id = ? AND upper(id) = ?", [.text(user), .text(id)])
            .first.map(highlight)
    }
}
