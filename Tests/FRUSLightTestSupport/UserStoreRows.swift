// Rows written into a user store and read back beside it, for the tests of rules that reach tables
// no route writes yet, a note's tags and a project's tag focus, which S15d and S17f bring, and of
// rows only an import writes, as S16c's will: a highlight with the Mac's id, time and version.

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

    /// A note on a document carrying `tagIds`, as the Mac writes `userTagIds`.
    public func addNote(_ id: String, user: String = "owner", volumeId: String = "frus1961-63v06", documentId: String = "d1",
                        tagIds: [String], lastModified: String = "2026-01-01T00:00:00.000Z") throws {
        _ = try db.query(
            """
            INSERT INTO notes (user_id, id, document_id, volume_id, body_text, project_ids, user_tag_ids,
                               selected_summary_ids, created_at, last_modified)
                VALUES (?, ?, ?, ?, 'A note.', '[]', ?, '[]', ?, ?)
            """, [.text(user), .text(id), .text(documentId), .text(volumeId), .text(Self.json(tagIds)), .text(lastModified),
                  .text(lastModified)])
    }

    /// A project whose tag focus is `tagIds`.
    public func addProject(_ id: String, user: String = "owner", tagIds: [String],
                           lastModified: String = "2026-01-01T00:00:00.000Z") throws {
        _ = try db.query(
            """
            INSERT INTO projects (user_id, id, name, default_subject_tag_ids, default_country_tag_ids,
                                  default_user_tag_ids, created_at, last_modified)
                VALUES (?, ?, 'A project', '[]', '[]', ?, ?, ?)
            """, [.text(user), .text(id), .text(Self.json(tagIds)), .text(lastModified), .text(lastModified)])
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

    public static func json(_ ids: [String]) -> String {
        "[" + ids.map { "\"\($0)\"" }.joined(separator: ",") + "]"
    }
}
