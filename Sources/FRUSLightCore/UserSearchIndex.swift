// The user's own search text (PLAN's S15d): one row of `user_search` for each user and document, as
// the Mac's `user_content` holds a document's note and summary text, rewritten in the transaction of
// every note and summary change, so that S17d's search finds what was written a moment ago. The text
// is the app's: its notes joined as `ResearchNote.indexedTextPerDocument` joins them, and its newest
// summary but a headnote draft, as `GeneratedSummary.newestNonDraftPerDocument` picks it, each app
// code mirrored here with a parity test that reads the app's source.

import Foundation

/// The two texts a document's row holds, composed in one place.
public enum UserSearchText {
    /// `ResearchNote.indexedTextSeparator`.
    public static let separator = "\n\n"

    /// `ResearchNote.indexedTextPerDocument` for one document's notes: oldest first by `createdAt`,
    /// one with none first of all, then by id in uppercase, as the app compares `uuidString`s; bodies
    /// blank once trimmed of white space and new lines left out; the rest joined by a blank line. Nil
    /// when nothing is left, which clears the column, as the app's `noteTextWrite` gives `.clear`.
    public static func noteText(_ notes: [NoteRecord]) -> String? {
        let ordered = notes.filter { !$0.volumeId.isEmpty && !$0.documentId.isEmpty }.sorted {
            let left = $0.createdAt ?? .distantPast
            let right = $1.createdAt ?? .distantPast
            if left != right { return left < right }
            return uuidString($0.id) < uuidString($1.id)
        }
        let text = ordered.map(\.bodyText)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: separator)
        return text.isEmpty ? nil : text
    }

    /// `GeneratedSummary.newestNonDraftPerDocument` for one document's summaries: the text of the
    /// newest by `SummaryOrder.ranksAbove` that is not a headnote draft, or nil when every one is,
    /// which clears the column, as the app's `draftOnlyDocuments` does.
    public static func summaryText(_ summaries: [SummaryRecord]) -> String? {
        summaries.filter { !$0.isHeadnoteDraft && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
            .min(by: SummaryOrder.ranksAbove)?.responseText
    }

    /// An id as the app's `uuidString` spells it, in uppercase; one that is no UUID, in uppercase too.
    public static func uuidString(_ id: String) -> String {
        TagReferences.normalized(id) ?? id.uppercased()
    }
}

extension SQLiteUserStore {
    /// Rewrites the user's row of `user_search` for `document` from its notes and summaries, inside
    /// the caller's transaction: on its connection, since the store's lock is not recursive. The row
    /// is deleted, then written again unless both texts are empty; an empty one is NULL, as the
    /// app's clear leaves its column.
    static func refreshSearch(of document: DocumentKey, for user: String, in db: SQLiteConnection) throws {
        let notes = UserSearchText.noteText(try indexedNotes(of: document, for: user, in: db))
        let summary = UserSearchText.summaryText(try summaries(of: document, for: user, in: db))
        _ = try db.query("DELETE FROM user_search WHERE user_id = ? AND volume_id = ? AND document_id = ?",
                         [.text(user), .text(document.volumeId), .text(document.documentId)])
        let columns = [summary, notes].map { text -> SQLiteValue in
            guard let text, !text.isEmpty else { return .null }
            return .text(text)
        }
        guard columns.contains(where: { $0 != .null }) else { return }
        _ = try db.query(
            "INSERT INTO user_search (user_id, document_id, volume_id, summary_text, note_text) VALUES (?, ?, ?, ?, ?)",
            [.text(user), .text(document.documentId), .text(document.volumeId)] + columns)
    }

    /// A document's notes as far as `UserSearchText.noteText` reads them: each one's id, body and
    /// creation time, and none of what a row of `user_search` does not hold, their RTF, lists and
    /// highlights' links, which a save would otherwise read for every note of its document.
    private static func indexedNotes(of document: DocumentKey, for user: String, in db: SQLiteConnection) throws -> [NoteRecord] {
        try db.query("SELECT id, body_text, created_at FROM notes WHERE user_id = ? AND volume_id = ? AND document_id = ?",
                     [.text(user), .text(document.volumeId), .text(document.documentId)]).map { row in
            NoteRecord(id: row[0].text ?? "", volumeId: document.volumeId, documentId: document.documentId,
                       bodyText: row[1].text ?? "", richText: nil, projectIds: [], userTagIds: [], selectedSummaryIds: [],
                       createdAt: row[2].text.flatMap(UserStoreDate.date), lastModified: nil)
        }
    }
}
