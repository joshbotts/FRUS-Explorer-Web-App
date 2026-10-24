// Tags and their assignments to documents (PLAN's S14c), kept by the app's rules: `UserTagAdmin`'s
// cascading delete and merge, the tag editor's and the picker's trimmed names, and the picker's and
// the Research rail's writes of one document's tags.

import Foundation

/// One of a user's tags, as the store keeps the Mac's `UserTag`.
public struct UserTagRecord: Sendable, Equatable {
    /// The Mac's id, an uppercase `uuidString`.
    public var id: String
    public var name: String
    public var createdAt: Date?
    public var lastModified: Date?

    public init(id: String, name: String, createdAt: Date?, lastModified: Date?) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

/// A document, as the index and the user store name it.
public struct DocumentKey: Sendable, Hashable {
    public let volumeId: String
    public let documentId: String

    public init(volumeId: String, documentId: String) {
        self.volumeId = volumeId
        self.documentId = documentId
    }
}

/// What deleting or merging a tag changed beside the tag itself.
public struct TagChange: Sendable, Equatable {
    /// The documents whose assignment of the tag was deleted or now names the tag it joined, each
    /// once, as `UserTagAdmin` returns them.
    public let documents: [DocumentKey]
    /// How many notes and projects carried the tag's id.
    public let notes: Int
    public let projects: Int
}

/// Why the store refused a change to tags.
public enum TagStoreError: Error, Equatable, CustomStringConvertible {
    /// A name with nothing left once it is trimmed, which the app's editor and picker refuse.
    case emptyName
    /// The user has no tag with this id.
    case tagNotFound(String)
    /// A tag asked to merge into itself.
    case mergeIntoItself

    public var description: String {
        switch self {
        case .emptyName: "a tag's name cannot be empty"
        case .tagNotFound(let id): "no tag has the id \(id)"
        case .mergeIntoItself: "a tag cannot be merged into itself"
        }
    }
}

/// Where a user's tags and their assignments to documents are kept.
public protocol TagStore: Sendable {
    /// The user's tags in the order the app lists them before the reader's own order (S17f): by
    /// name, as `@Query(sort: \UserTag.name)` sorts them, with Foundation's localized standard
    /// comparison, `SortDescriptor`'s for a string, which reads digits as numbers; then by id.
    func tags(of user: String) throws -> [UserTagRecord]
    /// One of the user's tags, or nil.
    func tag(_ id: String, of user: String) throws -> UserTagRecord?
    /// Makes a tag, its name trimmed of white space and new lines, as the app's picker and editor
    /// trim it. Throws `TagStoreError.emptyName` for a name with nothing left.
    @discardableResult func createTag(named name: String, for user: String, at now: Date) throws -> UserTagRecord
    /// Renames a tag, trimmed as a new one is. A name that is the tag's already changes nothing,
    /// as the editor's Save leaves it.
    @discardableResult func renameTag(_ id: String, to name: String, for user: String, at now: Date) throws -> UserTagRecord
    /// Deletes a tag as `UserTagAdmin.deleteCascading` does: its id leaves every note's
    /// `userTagIds` and every project's `defaultUserTagIds`, which each changed one records as
    /// modified, and its assignments go with it.
    @discardableResult func deleteTag(_ id: String, for user: String, at now: Date) throws -> TagChange
    /// Merges a tag into another as `UserTagAdmin.merge` does: every note and project that names it
    /// names the other once instead, and every assignment of it is the other's; then it is deleted.
    /// A document that carried both keeps the other's assignment, one per document and tag.
    @discardableResult func mergeTag(_ id: String, into target: String, for user: String, at now: Date) throws -> TagChange
    /// The tags a document carries, in the order `tags(of:)` gives them. An assignment of a tag the
    /// user no longer has names nothing, as the Research rail shows nothing for one.
    func tags(of document: DocumentKey, for user: String) throws -> [UserTagRecord]
    /// Gives a document exactly these tags, as the tag picker's Done replaces a document's set:
    /// one assignment per tag, a tag it carries already keeping the one it has. Throws
    /// `TagStoreError.tagNotFound` for an id the user has no tag for, changing nothing.
    @discardableResult func setTags(_ ids: [String], of document: DocumentKey, for user: String, at now: Date) throws -> [UserTagRecord]
    /// Takes one tag off a document, as the Research rail's × does: every assignment of it there.
    @discardableResult func removeTag(_ id: String, from document: DocumentKey, for user: String) throws -> [UserTagRecord]
}

extension SQLiteUserStore: TagStore {
    private static let tagColumns = "id, name, created_at, last_modified"

    public func tags(of user: String) throws -> [UserTagRecord] {
        try reading { db in
            Self.ordered(try db.query("SELECT \(Self.tagColumns) FROM tags WHERE user_id = ?", [.text(user)]).map(Self.tag))
        }
    }

    /// Tags in the order `tags(of:)` gives them.
    static func ordered(_ tags: [UserTagRecord]) -> [UserTagRecord] {
        tags.sorted { a, b in
            switch a.name.localizedStandardCompare(b.name) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: a.id < b.id
            }
        }
    }

    public func tag(_ id: String, of user: String) throws -> UserTagRecord? {
        guard let id = TagReferences.normalized(id) else { return nil }
        return try reading { try Self.tag(id, of: user, in: $0) }
    }

    @discardableResult
    public func createTag(named name: String, for user: String, at now: Date) throws -> UserTagRecord {
        let trimmed = try Self.trimmed(name)
        let time = UserStoreDate.rounded(now)
        let tag = UserTagRecord(id: UUID().uuidString, name: trimmed, createdAt: time, lastModified: time)
        try writing { db in
            _ = try db.query("INSERT INTO tags (user_id, \(Self.tagColumns)) VALUES (?, ?, ?, ?, ?)",
                             [.text(user), .text(tag.id), .text(tag.name), .text(UserStoreDate.text(time)),
                              .text(UserStoreDate.text(time))])
        }
        return tag
    }

    @discardableResult
    public func renameTag(_ id: String, to name: String, for user: String, at now: Date) throws -> UserTagRecord {
        let trimmed = try Self.trimmed(name)
        return try writing { db in
            guard let key = TagReferences.normalized(id), var tag = try Self.tag(key, of: user, in: db) else {
                throw TagStoreError.tagNotFound(id)
            }
            guard tag.name != trimmed else { return tag }
            tag.name = trimmed
            tag.lastModified = UserStoreDate.rounded(now)
            _ = try db.query("UPDATE tags SET name = ?, last_modified = ? WHERE user_id = ? AND id = ?",
                             [.text(trimmed), .text(UserStoreDate.text(now)), .text(user), .text(key)])
            return tag
        }
    }

    @discardableResult
    public func deleteTag(_ id: String, for user: String, at now: Date) throws -> TagChange {
        try writing { db in
            guard let key = TagReferences.normalized(id), try Self.tag(key, of: user, in: db) != nil else {
                throw TagStoreError.tagNotFound(id)
            }
            let notes = try Self.rewriteReferences(in: "notes", column: "user_tag_ids", naming: key, for: user, at: now, db) {
                TagReferences.removing(key, from: $0)
            }
            let documents = try Self.documents(carrying: key, for: user, db)
            _ = try db.query("DELETE FROM tag_assignments WHERE user_id = ? AND upper(tag_id) = ?", [.text(user), .text(key)])
            let projects = try Self.rewriteReferences(in: "projects", column: "default_user_tag_ids", naming: key, for: user,
                                                      at: now, db) {
                TagReferences.removing(key, from: $0)
            }
            _ = try db.query("DELETE FROM tags WHERE user_id = ? AND id = ?", [.text(user), .text(key)])
            return TagChange(documents: documents, notes: notes, projects: projects)
        }
    }

    @discardableResult
    public func mergeTag(_ id: String, into target: String, for user: String, at now: Date) throws -> TagChange {
        try writing { db in
            guard let source = TagReferences.normalized(id), try Self.tag(source, of: user, in: db) != nil else {
                throw TagStoreError.tagNotFound(id)
            }
            guard let survivor = TagReferences.normalized(target), try Self.tag(survivor, of: user, in: db) != nil else {
                throw TagStoreError.tagNotFound(target)
            }
            guard source != survivor else { throw TagStoreError.mergeIntoItself }
            let notes = try Self.rewriteReferences(in: "notes", column: "user_tag_ids", naming: source, for: user, at: now, db) {
                TagReferences.repointing(source, to: survivor, in: $0)
            }
            // Each assignment of the source becomes the survivor's, unless the document carries the
            // survivor already: the app re-points both and keeps two, which every reader of them
            // takes as one; the store keeps one per document and tag.
            let rows = try db.query(
                """
                SELECT id, volume_id, document_id FROM tag_assignments WHERE user_id = ? AND upper(tag_id) = ?
                    ORDER BY created_at, id
                """, [.text(user), .text(source)])
            var documents: [DocumentKey] = []
            var seen: Set<DocumentKey> = []
            for row in rows {
                let document = DocumentKey(volumeId: row[1].text ?? "", documentId: row[2].text ?? "")
                guard seen.insert(document).inserted else {
                    _ = try db.query("DELETE FROM tag_assignments WHERE user_id = ? AND id = ?", [.text(user), row[0]])
                    continue
                }
                documents.append(document)
                let carries = try db.scalar(
                    """
                    SELECT count(*) FROM tag_assignments
                        WHERE user_id = ? AND volume_id = ? AND document_id = ? AND upper(tag_id) = ?
                    """, [.text(user), .text(document.volumeId), .text(document.documentId), .text(survivor)])?.integer ?? 0
                if carries > 0 {
                    _ = try db.query("DELETE FROM tag_assignments WHERE user_id = ? AND id = ?", [.text(user), row[0]])
                } else {
                    _ = try db.query("UPDATE tag_assignments SET tag_id = ? WHERE user_id = ? AND id = ?",
                                     [.text(survivor), .text(user), row[0]])
                }
            }
            let projects = try Self.rewriteReferences(in: "projects", column: "default_user_tag_ids", naming: source,
                                                      for: user, at: now, db) {
                TagReferences.repointing(source, to: survivor, in: $0)
            }
            _ = try db.query("DELETE FROM tags WHERE user_id = ? AND id = ?", [.text(user), .text(source)])
            return TagChange(documents: documents, notes: notes, projects: projects)
        }
    }

    public func tags(of document: DocumentKey, for user: String) throws -> [UserTagRecord] {
        try reading { try Self.tags(of: document, for: user, in: $0) }
    }

    @discardableResult
    public func setTags(_ ids: [String], of document: DocumentKey, for user: String, at now: Date) throws -> [UserTagRecord] {
        try writing { db in
            var wanted: [String] = []
            for id in ids {
                guard let key = TagReferences.normalized(id), try Self.tag(key, of: user, in: db) != nil else {
                    throw TagStoreError.tagNotFound(id)
                }
                if !wanted.contains(key) { wanted.append(key) }
            }
            let rows = try db.query(
                """
                SELECT id, tag_id FROM tag_assignments WHERE user_id = ? AND volume_id = ? AND document_id = ?
                    ORDER BY created_at, id
                """, [.text(user), .text(document.volumeId), .text(document.documentId)])
            var kept: Set<String> = []
            for row in rows {
                let tag = TagReferences.normalized(row[1].text ?? "") ?? (row[1].text ?? "")
                // The oldest assignment of a tag the document keeps stays; any other goes.
                if wanted.contains(tag), kept.insert(tag).inserted { continue }
                _ = try db.query("DELETE FROM tag_assignments WHERE user_id = ? AND id = ?", [.text(user), row[0]])
            }
            for tag in wanted where !kept.contains(tag) {
                _ = try db.query(
                    """
                    INSERT INTO tag_assignments (user_id, id, volume_id, document_id, tag_id, created_at)
                        VALUES (?, ?, ?, ?, ?, ?)
                    """, [.text(user), .text(UUID().uuidString), .text(document.volumeId), .text(document.documentId),
                          .text(tag), .text(UserStoreDate.text(now))])
            }
            return try Self.tags(of: document, for: user, in: db)
        }
    }

    @discardableResult
    public func removeTag(_ id: String, from document: DocumentKey, for user: String) throws -> [UserTagRecord] {
        try writing { db in
            guard let key = TagReferences.normalized(id), try Self.tag(key, of: user, in: db) != nil else {
                throw TagStoreError.tagNotFound(id)
            }
            _ = try db.query(
                "DELETE FROM tag_assignments WHERE user_id = ? AND volume_id = ? AND document_id = ? AND upper(tag_id) = ?",
                [.text(user), .text(document.volumeId), .text(document.documentId), .text(key)])
            return try Self.tags(of: document, for: user, in: db)
        }
    }

    // MARK: Within a transaction

    private static func tag(_ row: [SQLiteValue]) -> UserTagRecord {
        UserTagRecord(id: row[0].text ?? "", name: row[1].text ?? "", createdAt: row[2].text.flatMap(UserStoreDate.date),
                      lastModified: row[3].text.flatMap(UserStoreDate.date))
    }

    private static func tag(_ id: String, of user: String, in db: SQLiteConnection) throws -> UserTagRecord? {
        try db.query("SELECT \(tagColumns) FROM tags WHERE user_id = ? AND id = ?", [.text(user), .text(id)]).first.map(tag)
    }

    private static func tags(of document: DocumentKey, for user: String, in db: SQLiteConnection) throws -> [UserTagRecord] {
        ordered(try db.query(
            """
            SELECT \(tagColumns) FROM tags WHERE user_id = ? AND id IN (
                SELECT upper(tag_id) FROM tag_assignments WHERE user_id = ? AND volume_id = ? AND document_id = ?)
            """, [.text(user), .text(user), .text(document.volumeId), .text(document.documentId)]).map(tag))
    }

    /// The documents an assignment of `tag` is on, each once, oldest assignment first.
    private static func documents(carrying tag: String, for user: String, _ db: SQLiteConnection) throws -> [DocumentKey] {
        var seen: Set<DocumentKey> = []
        return try db.query(
            "SELECT volume_id, document_id FROM tag_assignments WHERE user_id = ? AND upper(tag_id) = ? ORDER BY created_at, id",
            [.text(user), .text(tag)]
        ).compactMap { row in
            let document = DocumentKey(volumeId: row[0].text ?? "", documentId: row[1].text ?? "")
            return seen.insert(document).inserted ? document : nil
        }
    }

    /// Rewrites the id list in `column` of each of the user's rows in `table` that names `tag`, as
    /// `rewrite` gives it, and records the row as modified at `now`, as the app's save stamps a
    /// changed note or project. A list that does not decode is left as it is. Returns how many rows
    /// changed.
    private static func rewriteReferences(in table: String, column: String, naming tag: String, for user: String,
                                          at now: Date, _ db: SQLiteConnection,
                                          _ rewrite: ([String]) -> [String]?) throws -> Int {
        let rows = try db.query("SELECT id, \(column) FROM \(table) WHERE user_id = ? AND instr(upper(\(column)), ?) > 0",
                                [.text(user), .text(tag)])
        var changed = 0
        for row in rows {
            guard let ids = row[1].text.flatMap(TagReferences.decode), let rewritten = rewrite(ids) else { continue }
            _ = try db.query("UPDATE \(table) SET \(column) = ?, last_modified = ? WHERE user_id = ? AND id = ?",
                             [.text(TagReferences.encode(rewritten)), .text(UserStoreDate.text(now)), .text(user), row[0]])
            changed += 1
        }
        return changed
    }

    private static func trimmed(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TagStoreError.emptyName }
        return trimmed
    }
}

/// The app's two rewrites of a list of tag ids, a note's `userTagIds` or a project's
/// `defaultUserTagIds`, kept apart from the SQL so the PostgreSQL store (S14d) writes the same lists.
public enum TagReferences {
    /// An id as the store keeps it, an uppercase `uuidString`; nil for text that is not a UUID.
    public static func normalized(_ id: String) -> String? { UUID(uuidString: id)?.uuidString }

    /// `ids` without `tag`, as `UserTagAdmin.deleteCascading` strips it; nil when they do not name it.
    public static func removing(_ tag: String, from ids: [String]) -> [String]? {
        guard ids.contains(where: { names($0, tag) }) else { return nil }
        return ids.filter { !names($0, tag) }
    }

    /// `ids` with `source` gone and `target` after the rest unless they name it already, as
    /// `UserTagAdmin.merge` re-points them; nil when they do not name `source`.
    public static func repointing(_ source: String, to target: String, in ids: [String]) -> [String]? {
        guard var kept = removing(source, from: ids) else { return nil }
        if !kept.contains(where: { names($0, target) }) { kept.append(target) }
        return kept
    }

    /// A list as the store holds it, JSON text of strings.
    public static func decode(_ text: String) -> [String]? {
        try? JSONDecoder().decode([String].self, from: Data(text.utf8))
    }

    public static func encode(_ ids: [String]) -> String {
        (try? JSONEncoder().encode(ids)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }

    private static func names(_ id: String, _ tag: String) -> Bool { (normalized(id) ?? id) == tag }
}
