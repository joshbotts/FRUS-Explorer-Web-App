// Rows written into a user store and read back beside it, for the tests of rules that reach tables
// no route writes, a project's tag focus, which S17f brings, and of rows only an import writes, as
// S16c's will: a highlight with the Mac's id, time and version; a note with the Mac's RTF and ids
// that dangle; an AI summary, a headnote draft, a prompt and a project (S15d). And what the store
// keeps beside them: a note's columns, a highlight's note, and the rows of user_search.

import FRUSLightCore
import Foundation

/// A second connection to a user store's file.
public final class UserStoreRows: @unchecked Sendable {
    private let db: SQLiteConnection

    public init(_ url: URL) throws {
        db = try SQLiteConnection(url.path, readOnly: false)
    }

    deinit { db.close() }

    /// Adds a user beside `owner`, as S14e's sign-in will.
    public func addUser(_ id: String) throws {
        _ = try db.query("INSERT INTO users (user_id, display_name, created_at) VALUES (?, ?, '2026-10-23T00:00:00Z')",
                         [.text(id), .text(id)])
    }

    /// A note on a document as the Mac writes one: carrying `tagIds` as its `userTagIds`, any RTF or
    /// none, ids that may dangle, and any times or none.
    public func addNote(_ id: String, user: String = "owner", volumeId: String = "frus1961-63v06", documentId: String = "d1",
                        tagIds: [String] = [], bodyText: String = "A note.", richText: [UInt8]? = nil,
                        projectIds: [String] = [], selectedSummaryIds: [String] = [],
                        createdAt: String? = "2026-01-01T00:00:00.000Z",
                        lastModified: String? = "2026-01-01T00:00:00.000Z") throws {
        _ = try db.query(
            """
            INSERT INTO notes (user_id, id, document_id, volume_id, body_text, rich_text, project_ids, user_tag_ids,
                               selected_summary_ids, created_at, last_modified)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, [.text(user), .text(id), .text(documentId), .text(volumeId), .text(bodyText),
                  richText.map { .blob($0) } ?? .null, .text(Self.json(projectIds)), .text(Self.json(tagIds)),
                  .text(Self.json(selectedSummaryIds)), Self.optional(createdAt), Self.optional(lastModified)])
    }

    /// A project named `name` whose tag focus is `tagIds`.
    public func addProject(_ id: String, user: String = "owner", name: String = "A project", tagIds: [String] = [],
                           lastModified: String = "2026-01-01T00:00:00.000Z") throws {
        _ = try db.query(
            """
            INSERT INTO projects (user_id, id, name, default_subject_tag_ids, default_country_tag_ids,
                                  default_user_tag_ids, created_at, last_modified)
                VALUES (?, ?, ?, '[]', '[]', ?, ?, ?)
            """, [.text(user), .text(id), .text(name), .text(Self.json(tagIds)), .text(lastModified), .text(lastModified)])
    }

    /// A summary as the Mac's export carries one: an AI summary unless told otherwise, of any prompt,
    /// authorship, format and time.
    public func addSummary(_ id: String, user: String = "owner", volumeId: String = "frus1961-63v06", documentId: String = "d1",
                           promptId: String = "AA000000-0000-4000-8000-000000000001", responseText: String = "An AI summary.",
                           responseFormat: String = #"{"general":{}}"#, wasChunked: Bool = false,
                           authorship: String? = "aiGenerated", isHeadnoteDraft: Bool = false, projectId: String? = nil,
                           createdAt: String? = "2026-01-01T00:00:00.000Z",
                           lastModified: String? = "2026-01-01T00:00:00.000Z") throws {
        _ = try db.query(
            """
            INSERT INTO summaries (user_id, id, document_id, volume_id, prompt_id, response_text, response_format, was_chunked,
                                   authorship, is_headnote_draft, source_content_hash, project_id, created_at, last_modified)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?)
            """, [.text(user), .text(id), .text(documentId), .text(volumeId), .text(promptId), .text(responseText),
                  .text(responseFormat), .integer(wasChunked ? 1 : 0), Self.optional(authorship),
                  .integer(isHeadnoteDraft ? 1 : 0), Self.optional(projectId), Self.optional(createdAt),
                  Self.optional(lastModified)])
    }

    /// One of the user's own prompts, as the export carries one.
    public func addPrompt(_ id: String, user: String = "owner", name: String) throws {
        _ = try db.query(
            """
            INSERT INTO prompts (user_id, id, name, prompt_text, response_format, is_standard, schema, created_at, last_modified)
                VALUES (?, ?, ?, 'Summarize {{DOCUMENT}}', '{"general":{}}', 0, NULL, '2026-01-01T00:00:00.000Z',
                        '2026-01-01T00:00:00.000Z')
            """, [.text(user), .text(id), .text(name)])
    }

    /// An assignment as an import could leave it: any id, any time, a tag the user may not have.
    public func addAssignment(_ id: String, user: String = "owner", volumeId: String = "frus1961-63v06",
                              documentId: String, tagId: String, createdAt: String = "2026-01-01T00:00:00.000Z") throws {
        _ = try db.query(
            "INSERT INTO tag_assignments (user_id, id, volume_id, document_id, tag_id, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            [.text(user), .text(id), .text(volumeId), .text(documentId), .text(tagId), .text(createdAt)])
    }

    /// A highlight as the Mac's export carries one: any id, any time or none, any version and colour.
    public func addHighlight(_ id: String, user: String = "owner", volumeId: String = "frus1961-63v06",
                             documentId: String = "d1", start: Int = 0, end: Int = 5, colorTag: String = "yellow",
                             noteId: String? = nil, selectedText: String = "", renderingVersion: String = "",
                             createdAt: String? = "2026-01-01T00:00:00.000Z") throws {
        _ = try db.query(
            """
            INSERT INTO highlights (user_id, id, volume_id, document_id, start_offset, end_offset, color_tag, note_id,
                                    selected_text, rendering_version, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, [.text(user), .text(id), .text(volumeId), .text(documentId), .integer(Int64(start)), .integer(Int64(end)),
                  .text(colorTag), noteId.map { .text($0) } ?? .null, .text(selectedText), .text(renderingVersion),
                  createdAt.map { .text($0) } ?? .null])
    }

    /// A note's columns as stored: its body, its RTF's bytes, its three lists and its two times.
    public func storedNote(_ id: String, user: String = "owner") throws -> StoredNote? {
        try db.query(
            """
            SELECT body_text, rich_text, user_tag_ids, project_ids, selected_summary_ids, created_at, last_modified
                FROM notes WHERE user_id = ? AND upper(id) = upper(?)
            """, [.text(user), .text(id)]).first.map { row in
            let richText: [UInt8]? = if case .blob(let bytes) = row[1] { bytes } else { nil }
            return StoredNote(bodyText: row[0].text ?? "", richText: richText, userTagIds: row[2].text ?? "",
                              projectIds: row[3].text ?? "", selectedSummaryIds: row[4].text ?? "", createdAt: row[5].text,
                              lastModified: row[6].text)
        }
    }

    /// A summary's columns as stored, each as text: its text, format, chunking, authorship, draft
    /// flag, prompt, project and times.
    public func storedSummary(_ id: String, user: String = "owner") throws -> [String: String?]? {
        let names = ["response_text", "response_format", "was_chunked", "authorship", "is_headnote_draft", "prompt_id",
                     "project_id", "source_content_hash", "created_at", "last_modified"]
        return try db.query("SELECT \(names.joined(separator: ", ")) FROM summaries WHERE user_id = ? AND upper(id) = upper(?)",
                            [.text(user), .text(id)]).first.map { row in
            Dictionary(uniqueKeysWithValues: zip(names, row.map(\.text)))
        }
    }

    /// The note a highlight is linked to, as stored.
    public func highlightNoteId(_ id: String, user: String = "owner") throws -> String? {
        try db.scalar("SELECT note_id FROM highlights WHERE user_id = ? AND upper(id) = upper(?)", [.text(user), .text(id)])?.text
    }

    /// The user's rows of user_search, by volume and document.
    public func userSearch(user: String = "owner") throws -> [UserSearchRow] {
        try db.query(
            "SELECT volume_id, document_id, summary_text, note_text FROM user_search WHERE user_id = ? ORDER BY volume_id, document_id",
            [.text(user)]).map { UserSearchRow(volumeId: $0[0].text ?? "", documentId: $0[1].text ?? "", summaryText: $0[2].text,
                                               noteText: $0[3].text) }
    }

    /// The documents whose row of user_search matches an FTS5 query, for the user.
    public func userSearchMatches(_ query: String, user: String = "owner") throws -> [String] {
        try db.query("SELECT document_id FROM user_search WHERE user_search MATCH ? AND user_id = ? ORDER BY document_id",
                     [.text(query), .text(user)]).compactMap { $0[0].text }
    }

    /// How many highlights the user has, as stored.
    public func highlightCount(user: String = "owner") throws -> Int {
        Int(try db.scalar("SELECT count(*) FROM highlights WHERE user_id = ?", [.text(user)])?.integer ?? 0)
    }

    /// A note's or a project's tag ids and its last modification, as stored.
    public func note(_ id: String, user: String = "owner") throws -> [String] {
        try row("SELECT user_tag_ids, last_modified FROM notes WHERE user_id = ? AND id = ?", user, id)
    }

    public func project(_ id: String, user: String = "owner") throws -> [String] {
        try row("SELECT default_user_tag_ids, last_modified FROM projects WHERE user_id = ? AND id = ?", user, id)
    }

    /// Every assignment the user has: id, document and tag, oldest first.
    public func assignments(user: String = "owner") throws -> [(id: String, documentId: String, tagId: String)] {
        try db.query("SELECT id, document_id, tag_id FROM tag_assignments WHERE user_id = ? ORDER BY created_at, id", [.text(user)])
            .map { ($0[0].text ?? "", $0[1].text ?? "", $0[2].text ?? "") }
    }

    private func row(_ sql: String, _ user: String, _ id: String) throws -> [String] {
        try db.query(sql, [.text(user), .text(id)]).first?.map { $0.text ?? "" } ?? []
    }

    /// Runs a statement, for a row no route or import writes.
    public func run(_ sql: String, _ bindings: [SQLiteValue] = []) throws {
        _ = try db.query(sql, bindings)
    }

    /// The first column of each row a query gives, as text, NULL as empty.
    public func column(_ sql: String, _ bindings: [SQLiteValue] = []) throws -> [String] {
        try db.query(sql, bindings).map { $0.first?.text ?? "" }
    }

    /// Every row of `table`, a user table's of `user`'s, each with all of its columns but `user_id`, in
    /// the order the store took them (S16d's export and its round trip).
    public func rows(of table: String, user: String = "owner") throws -> [[String: SQLiteValue]] {
        guard let schema = UserStoreSchema.tables.first(where: { $0.name == table }) else { return [] }
        let columns = schema.columns.map(\.name)
        return try db.query("SELECT \(columns.joined(separator: ", ")) FROM \(table)"
                                + (schema.scope == .user ? " WHERE user_id = ?" : "") + " ORDER BY rowid",
                            schema.scope == .user ? [.text(user)] : [])
            .map { Dictionary(uniqueKeysWithValues: zip(columns, $0)) }
    }

    /// The first row a query gives, each value as text and NULL as empty, or none.
    public func firstRow(_ sql: String, _ bindings: [String] = []) throws -> [String] {
        try db.query(sql, bindings.map { .text($0) }).first?.map { $0.text ?? "" } ?? []
    }

    public static func json(_ ids: [String]) -> String {
        "[" + ids.map { "\"\($0)\"" }.joined(separator: ",") + "]"
    }

    private static func optional(_ text: String?) -> SQLiteValue { text.map { .text($0) } ?? .null }
}

/// A note's columns as the store keeps them.
public struct StoredNote: Sendable, Equatable {
    public var bodyText: String
    public var richText: [UInt8]?
    /// The three lists, as their JSON text.
    public var userTagIds: String
    public var projectIds: String
    public var selectedSummaryIds: String
    public var createdAt: String?
    public var lastModified: String?
}

/// One row of user_search.
public struct UserSearchRow: Sendable, Equatable {
    public var volumeId: String
    public var documentId: String
    public var summaryText: String?
    public var noteText: String?

    public init(volumeId: String, documentId: String, summaryText: String?, noteText: String?) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.summaryText = summaryText
        self.noteText = noteText
    }
}
