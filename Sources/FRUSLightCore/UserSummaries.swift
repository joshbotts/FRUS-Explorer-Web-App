// Summaries and their prompts' names (PLAN's S15d), kept as the app keeps `GeneratedSummary` and
// `SummarizationPrompt`; the app's order of a document's summaries, `GeneratedSummary.ranksAbove`,
// in one place for the API's list and for search; and the summaries the web's reader writes, the
// web's own, since no app screen writes a document's summary: the only ones a reader may change.
// Every change rewrites the document's row of `user_search` in its transaction.

import Foundation

/// One of a user's summaries, as the store keeps the Mac's `GeneratedSummary`.
public struct SummaryRecord: Sendable, Equatable {
    /// The Mac's id, an uppercase `uuidString` for a summary written here.
    public var id: String
    public var volumeId: String
    public var documentId: String
    /// The prompt it was made with; for a summary written here, `OwnSummary.promptId`.
    public var promptId: String
    /// The text, which for a structured summary is the JSON the model gave.
    public var responseText: String
    /// The kit's `ResponseFormat`, as the JSON its encoder writes.
    public var responseFormat: String
    public var wasChunked: Bool
    /// `SummaryAuthorship`'s raw value, or nil, which every reader takes as `aiGenerated`.
    public var authorship: String?
    /// A collection's private headnote draft, which no list or search shows.
    public var isHeadnoteDraft: Bool
    public var sourceContentHash: String?
    public var projectId: String?
    public var createdAt: Date?
    public var lastModified: Date?

    public init(id: String, volumeId: String, documentId: String, promptId: String, responseText: String,
                responseFormat: String, wasChunked: Bool, authorship: String?, isHeadnoteDraft: Bool,
                sourceContentHash: String?, projectId: String?, createdAt: Date?, lastModified: Date?) {
        self.id = id
        self.volumeId = volumeId
        self.documentId = documentId
        self.promptId = promptId
        self.responseText = responseText
        self.responseFormat = responseFormat
        self.wasChunked = wasChunked
        self.authorship = authorship
        self.isHeadnoteDraft = isHeadnoteDraft
        self.sourceContentHash = sourceContentHash
        self.projectId = projectId
        self.createdAt = createdAt
        self.lastModified = lastModified
    }

    public var document: DocumentKey { DocumentKey(volumeId: volumeId, documentId: documentId) }

    /// Whether the reader may change or delete it: `OwnSummary.isEditable`.
    public var isEditable: Bool { OwnSummary.isEditable(self) }
}

/// The summaries the web's reader writes, the web's own: no app screen writes a document's summary,
/// and the app's only user-written ones are collections' headnote drafts.
public enum OwnSummary {
    /// The web's prompt id for them, which no prompt row holds, so none is named. Never the app's
    /// headnote prompt, `0EAD0000-0000-4000-8000-000000000001`, which is how an import tells a
    /// headnote draft from a document's summary in a file older than format 7.
    public static let promptId = "0EB00000-0000-4000-8000-000000000001"
    /// `SummaryAuthorship.userWritten`'s raw value.
    public static let authorship = "userWritten"

    /// The one rule for a summary the reader may change or delete: the web's prompt id, written by
    /// the user, and no headnote draft. An imported summary, a user-written headnote draft among
    /// them, is read-only.
    public static func isEditable(_ summary: SummaryRecord) -> Bool {
        summary.promptId.uppercased() == promptId && summary.authorship == authorship && !summary.isHeadnoteDraft
    }
}

/// The app's order of a document's summaries, the newest first.
public enum SummaryOrder {
    /// `GeneratedSummary.ranksAbove`, app code: whether `a` is newer than `b`, by `createdAt`
    /// descending, one with none last, then `lastModified` descending, one with none last, then by id
    /// in uppercase, as the app compares `uuidString`s. The API's list and `user_search` both order
    /// by it.
    public static func ranksAbove(_ a: SummaryRecord, _ b: SummaryRecord) -> Bool {
        let ca = a.createdAt ?? .distantPast, cb = b.createdAt ?? .distantPast
        if ca != cb { return ca > cb }
        let la = a.lastModified ?? .distantPast, lb = b.lastModified ?? .distantPast
        if la != lb { return la > lb }
        return UserSearchText.uuidString(a.id) < UserSearchText.uuidString(b.id)
    }
}

/// Why the store refused a change to summaries.
public enum SummaryStoreError: Error, Equatable, CustomStringConvertible {
    /// The user has no summary with this id.
    case summaryNotFound(String)
    /// A summary the reader did not write here, which only the app's own paths change.
    case readOnly(String)
    /// A text with nothing left once it is trimmed of spaces and new lines.
    case emptyText

    public var description: String {
        switch self {
        case .summaryNotFound(let id): "no summary has the id \(id)"
        case .readOnly(let id): "the summary \(id) was not written here, so it cannot be changed"
        case .emptyText: "a summary's text cannot be empty"
        }
    }
}

/// Where a user's summaries and their prompts' names are kept.
public protocol SummaryStore: Sendable {
    /// Every summary of a document, headnote drafts included, by `SummaryOrder.ranksAbove`.
    func summaries(of document: DocumentKey, for user: String) throws -> [SummaryRecord]
    /// One of the user's summaries, or nil.
    func summary(_ id: String, of user: String) throws -> SummaryRecord?
    /// The names of the user's prompts, by id in uppercase: the app names a summary's prompt only
    /// when the prompt it was made with is still there (`SummarizationPrompt.resolve`'s `.requested`).
    func prompts(for user: String) throws -> [String: String]
    /// Writes one of the reader's own summaries of a document: `OwnSummary`'s prompt and authorship,
    /// no headnote draft, not chunked, in no project, with `responseFormat` as given and `now` as both
    /// its times. Throws `SummaryStoreError.emptyText` for a text that is only white space.
    @discardableResult func createOwnSummary(in document: DocumentKey, text: String, responseFormat: String, for user: String,
                                             at now: Date) throws -> SummaryRecord
    /// Replaces the text of one of the reader's own summaries, stamping `lastModified`.
    @discardableResult func updateOwnSummary(_ id: String, text: String, for user: String, at now: Date) throws -> SummaryRecord
    /// Deletes one of the reader's own summaries. A note that selected it keeps its id, as the app
    /// leaves a dangling one.
    func deleteOwnSummary(_ id: String, for user: String) throws
}

extension RelationalUserStore: SummaryStore {
    private static let summaryColumns = """
        id, volume_id, document_id, prompt_id, response_text, response_format, was_chunked, authorship, is_headnote_draft, \
        source_content_hash, project_id, created_at, last_modified
        """

    public func summaries(of document: DocumentKey, for user: String) throws -> [SummaryRecord] {
        try reading { try Self.summaries(of: document, for: user, in: $0) }
    }

    public func summary(_ id: String, of user: String) throws -> SummaryRecord? {
        guard let id = TagReferences.normalized(id) else { return nil }
        return try reading { try Self.summary(id, of: user, in: $0) }
    }

    public func prompts(for user: String) throws -> [String: String] {
        try reading { db in
            var names: [String: String] = [:]
            for row in try db.query("SELECT id, name FROM prompts WHERE user_id = ? ORDER BY created_at ASC NULLS FIRST, id",
                                    [.text(user)]) {
                guard let id = row[0].text, let name = row[1].text else { continue }
                let key = UserSearchText.uuidString(id)
                if names[key] == nil { names[key] = name }
            }
            return names
        }
    }

    @discardableResult
    public func createOwnSummary(in document: DocumentKey, text: String, responseFormat: String, for user: String,
                                 at now: Date) throws -> SummaryRecord {
        try Self.checkText(text)
        let time = UserStoreDate.rounded(now)
        let summary = SummaryRecord(id: UUID().uuidString, volumeId: document.volumeId, documentId: document.documentId,
                                    promptId: OwnSummary.promptId, responseText: text, responseFormat: responseFormat,
                                    wasChunked: false, authorship: OwnSummary.authorship, isHeadnoteDraft: false,
                                    sourceContentHash: nil, projectId: nil, createdAt: time, lastModified: time)
        try writing { db in
            _ = try db.query(
                "INSERT INTO summaries (user_id, \(Self.summaryColumns)) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [.text(user), .text(summary.id), .text(summary.volumeId), .text(summary.documentId), .text(summary.promptId),
                 .text(text), .text(responseFormat), .integer(0), .text(OwnSummary.authorship), .integer(0), .null, .null,
                 .text(UserStoreDate.text(time)), .text(UserStoreDate.text(time))])
            try Self.refreshSearch(of: document, for: user, in: db)
        }
        return summary
    }

    @discardableResult
    public func updateOwnSummary(_ id: String, text: String, for user: String, at now: Date) throws -> SummaryRecord {
        try writing { db in
            var summary = try Self.ownSummary(id, of: user, in: db)
            try Self.checkText(text)
            summary.responseText = text
            summary.lastModified = UserStoreDate.rounded(now)
            _ = try db.query("UPDATE summaries SET response_text = ?, last_modified = ? WHERE user_id = ? AND upper(id) = ?",
                             [.text(text), .text(UserStoreDate.text(now)), .text(user), .text(UserSearchText.uuidString(summary.id))])
            try Self.refreshSearch(of: summary.document, for: user, in: db)
            return summary
        }
    }

    public func deleteOwnSummary(_ id: String, for user: String) throws {
        try writing { db in
            let summary = try Self.ownSummary(id, of: user, in: db)
            _ = try db.query("DELETE FROM summaries WHERE user_id = ? AND upper(id) = ?",
                             [.text(user), .text(UserSearchText.uuidString(summary.id))])
            try Self.refreshSearch(of: summary.document, for: user, in: db)
        }
    }

    // MARK: Within a transaction

    static func summaries(of document: DocumentKey, for user: String, in db: UserStoreTransaction) throws -> [SummaryRecord] {
        try db.query("SELECT \(summaryColumns) FROM summaries WHERE user_id = ? AND volume_id = ? AND document_id = ?",
                     [.text(user), .text(document.volumeId), .text(document.documentId)])
            .map(summary).sorted(by: SummaryOrder.ranksAbove)
    }

    private static func summary(_ id: String, of user: String, in db: UserStoreTransaction) throws -> SummaryRecord? {
        // An id in any case, as an import may write one.
        try db.query("SELECT \(summaryColumns) FROM summaries WHERE user_id = ? AND upper(id) = ?", [.text(user), .text(id)])
            .first.map(summary)
    }

    /// One of the reader's own summaries, or the refusal of any other.
    private static func ownSummary(_ id: String, of user: String, in db: UserStoreTransaction) throws -> SummaryRecord {
        guard let key = TagReferences.normalized(id), let summary = try summary(key, of: user, in: db) else {
            throw SummaryStoreError.summaryNotFound(id)
        }
        guard summary.isEditable else { throw SummaryStoreError.readOnly(id) }
        return summary
    }

    private static func summary(_ row: [SQLiteValue]) -> SummaryRecord {
        SummaryRecord(id: row[0].text ?? "", volumeId: row[1].text ?? "", documentId: row[2].text ?? "",
                      promptId: row[3].text ?? "", responseText: row[4].text ?? "", responseFormat: row[5].text ?? "",
                      wasChunked: row[6].integer == 1, authorship: row[7].text, isHeadnoteDraft: row[8].integer == 1,
                      sourceContentHash: row[9].text, projectId: row[10].text,
                      createdAt: row[11].text.flatMap(UserStoreDate.date), lastModified: row[12].text.flatMap(UserStoreDate.date))
    }

    private static func checkText(_ text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SummaryStoreError.emptyText }
    }
}
