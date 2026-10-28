// The user's own search text (PLAN's S15d): one row of `user_search` for each user and document, as
// the Mac's `user_content` holds a document's note and summary text, rewritten in the transaction of
// every note and summary change, so that S17d's search finds what was written a moment ago. The text
// is the app's: its notes joined as `ResearchNote.indexedTextPerDocument` joins them, and its newest
// summary but a headnote draft, as `GeneratedSummary.newestNonDraftPerDocument` picks it, each app
// code mirrored here with a parity test that reads the app's source. The rows are written to the
// database the kit's search attaches (S14d): app.db itself, or the PostgreSQL store's local copy,
// which holds the tag assignments too, copied from the store beside each change to them.

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

extension RelationalUserStore {
    /// Rewrites the user's row of `user_search` for `document` from its notes and summaries, inside
    /// the caller's transaction: on its connections, since the store's lock is not recursive. The row
    /// is deleted, then written again unless both texts are empty; an empty one is NULL, as the
    /// app's clear leaves its column.
    static func refreshSearch(of document: DocumentKey, for user: String, in db: UserStoreTransaction) throws {
        let notes = try indexedNotes(of: document, for: user, in: db)
        let summaries = try summaries(of: document, for: user, in: db)
        _ = try db.search.query("DELETE FROM user_search WHERE user_id = ? AND volume_id = ? AND document_id = ?",
                                [.text(user), .text(document.volumeId), .text(document.documentId)])
        try writeSearchRow(of: document, notes: notes, summaries: summaries, for: user, into: db.search)
    }

    /// Makes all of the user's rows of the searchable database again, inside the caller's transaction,
    /// as an import does (S16c): each document's row of `user_search` by `refreshSearch`'s rules, from
    /// one read of the user's notes and one of their summaries, where a refresh of each document would
    /// read both for each; and where that database is a copy, the user's tag assignments, which an
    /// import writes too. Returns how many rows of `user_search` it wrote.
    static func rebuildSearch(for user: String, in db: UserStoreTransaction) throws -> Int {
        _ = try db.search.query("DELETE FROM user_search WHERE user_id = ?", [.text(user)])
        var notes: [DocumentKey: [NoteRecord]] = [:]
        for row in try db.query("SELECT id, volume_id, document_id, body_text, created_at FROM notes WHERE user_id = ?",
                                [.text(user)]) {
            let document = DocumentKey(volumeId: row[1].text ?? "", documentId: row[2].text ?? "")
            notes[document, default: []].append(NoteRecord(
                id: row[0].text ?? "", volumeId: document.volumeId, documentId: document.documentId, bodyText: row[3].text ?? "",
                richText: nil, projectIds: [], userTagIds: [], selectedSummaryIds: [],
                createdAt: row[4].text.flatMap(UserStoreDate.date), lastModified: nil))
        }
        var summaries: [DocumentKey: [SummaryRecord]] = [:]
        for row in try db.query(
            """
            SELECT id, volume_id, document_id, response_text, is_headnote_draft, created_at, last_modified FROM summaries
                WHERE user_id = ?
            """, [.text(user)]) {
            let document = DocumentKey(volumeId: row[1].text ?? "", documentId: row[2].text ?? "")
            summaries[document, default: []].append(SummaryRecord(
                id: row[0].text ?? "", volumeId: document.volumeId, documentId: document.documentId, promptId: "",
                responseText: row[3].text ?? "", responseFormat: "", wasChunked: false, authorship: nil,
                isHeadnoteDraft: row[4].integer == 1, sourceContentHash: nil, projectId: nil,
                createdAt: row[5].text.flatMap(UserStoreDate.date), lastModified: row[6].text.flatMap(UserStoreDate.date)))
        }
        var written = 0
        for document in Set(notes.keys).union(summaries.keys) {
            if try writeSearchRow(of: document, notes: notes[document] ?? [], summaries: summaries[document] ?? [], for: user,
                                  into: db.search) {
                written += 1
            }
        }
        try copyTagAssignments(for: user, in: db)
        return written
    }

    /// Where the searchable database is a copy, makes its rows of the user's assignments on each of
    /// `documents` again from the store's, inside the caller's transaction, after a change to them;
    /// app.db's are the store's own.
    static func copyTagAssignments(of documents: [DocumentKey], for user: String, in db: UserStoreTransaction) throws {
        guard db.copiesTagAssignments else { return }
        for document in documents {
            let keys: [SQLiteValue] = [.text(user), .text(document.volumeId), .text(document.documentId)]
            _ = try db.search.query("DELETE FROM tag_assignments WHERE user_id = ? AND volume_id = ? AND document_id = ?", keys)
            for row in try db.query(
                "SELECT id, volume_id, document_id, tag_id FROM tag_assignments WHERE user_id = ? AND volume_id = ? AND document_id = ?",
                keys) {
                try copyTagAssignment(row, for: user, into: db.search)
            }
        }
    }

    /// The same for every assignment of the user's.
    static func copyTagAssignments(for user: String, in db: UserStoreTransaction) throws {
        guard db.copiesTagAssignments else { return }
        _ = try db.search.query("DELETE FROM tag_assignments WHERE user_id = ?", [.text(user)])
        for row in try db.query("SELECT id, volume_id, document_id, tag_id FROM tag_assignments WHERE user_id = ?", [.text(user)]) {
            try copyTagAssignment(row, for: user, into: db.search)
        }
    }

    /// One assignment, read as its id, volume, document and tag, written to the copy.
    private static func copyTagAssignment(_ row: [SQLiteValue], for user: String, into search: any UserStoreConnection) throws {
        _ = try search.query("INSERT INTO tag_assignments (user_id, id, volume_id, document_id, tag_id) VALUES (?, ?, ?, ?, ?)",
                             [.text(user)] + row.prefix(4))
    }

    /// Writes the user's row of `user_search` for `document` from its notes and summaries, unless both
    /// texts are empty; an empty one is NULL, as the app's clear leaves its column. Whether it wrote one.
    @discardableResult
    private static func writeSearchRow(of document: DocumentKey, notes: [NoteRecord], summaries: [SummaryRecord],
                                       for user: String, into search: any UserStoreConnection) throws -> Bool {
        let columns = [UserSearchText.summaryText(summaries), UserSearchText.noteText(notes)].map { text -> SQLiteValue in
            guard let text, !text.isEmpty else { return .null }
            return .text(text)
        }
        guard columns.contains(where: { $0 != .null }) else { return false }
        _ = try search.query(
            "INSERT INTO user_search (user_id, document_id, volume_id, summary_text, note_text) VALUES (?, ?, ?, ?, ?)",
            [.text(user), .text(document.documentId), .text(document.volumeId)] + columns)
        return true
    }

    /// A document's notes as far as `UserSearchText.noteText` reads them: each one's id, body and
    /// creation time, and none of what a row of `user_search` does not hold, their RTF, lists and
    /// highlights' links, which a save would otherwise read for every note of its document.
    private static func indexedNotes(of document: DocumentKey, for user: String, in db: UserStoreTransaction) throws -> [NoteRecord] {
        try db.query("SELECT id, body_text, created_at FROM notes WHERE user_id = ? AND volume_id = ? AND document_id = ?",
                     [.text(user), .text(document.volumeId), .text(document.documentId)]).map { row in
            NoteRecord(id: row[0].text ?? "", volumeId: document.volumeId, documentId: document.documentId,
                       bodyText: row[1].text ?? "", richText: nil, projectIds: [], userTagIds: [], selectedSummaryIds: [],
                       createdAt: row[2].text.flatMap(UserStoreDate.date), lastModified: nil)
        }
    }
}
