// Research notes (PLAN's S15d), kept as the app keeps `ResearchNote`: the plain text, which is
// canonical, beside the RTF it was formatted with, kept as its bytes and rewritten only when the body
// is edited, as the app's editor rewrites it; the note's tag, project and summary ids, a dangling one
// kept as the app's picker keeps it; and the highlight a new note is written for, linked by the
// highlight's `noteId` in the same transaction, as the editor's Save links it. Every change rewrites
// the document's row of `user_search` in its transaction.

import Foundation

/// One of a user's notes, as the store keeps the Mac's `ResearchNote`.
public struct NoteRecord: Sendable, Equatable {
    /// The Mac's id, an uppercase `uuidString` for a note made here.
    public var id: String
    public var volumeId: String
    public var documentId: String
    /// The note's plain text, which search, the lists and the Markdown export read.
    public var bodyText: String
    /// The note's RTF as its bytes, or nil for a plain note: a reader takes nil as `bodyText` alone,
    /// never as an empty note.
    public var richText: [UInt8]?
    public var projectIds: [String]
    public var userTagIds: [String]
    public var selectedSummaryIds: [String]
    public var createdAt: Date?
    public var lastModified: Date?
    /// The user's highlights whose `noteId` names this note, as `ResearchNoteExport.linkedHighlightIds`
    /// derives them, in the order the reader draws highlights.
    public var linkedHighlightIds: [String]

    public init(id: String, volumeId: String, documentId: String, bodyText: String, richText: [UInt8]?,
                projectIds: [String], userTagIds: [String], selectedSummaryIds: [String], createdAt: Date?,
                lastModified: Date?, linkedHighlightIds: [String] = []) {
        self.id = id
        self.volumeId = volumeId
        self.documentId = documentId
        self.bodyText = bodyText
        self.richText = richText
        self.projectIds = projectIds
        self.userTagIds = userTagIds
        self.selectedSummaryIds = selectedSummaryIds
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.linkedHighlightIds = linkedHighlightIds
    }

    public var document: DocumentKey { DocumentKey(volumeId: volumeId, documentId: documentId) }
}

/// A note's body as an edit leaves it: its text, and the RTF it was formatted with, or nil for a
/// plain-mode edit, which drops the formatting as the app's `setPlainBody` does.
public struct NoteBody: Sendable, Equatable {
    public var text: String
    public var richText: [UInt8]?

    public init(text: String, richText: [UInt8]?) {
        self.text = text
        self.richText = richText
    }
}

/// One of a note's three lists of ids.
public enum NoteIdList: String, Sendable, CaseIterable {
    case userTagIds, projectIds, selectedSummaryIds

    /// The user's table whose rows the ids name.
    var table: String {
        switch self {
        case .userTagIds: "tags"
        case .projectIds: "projects"
        case .selectedSummaryIds: "summaries"
        }
    }

    var noun: String {
        switch self {
        case .userTagIds: "tag"
        case .projectIds: "project"
        case .selectedSummaryIds: "summary"
        }
    }
}

/// Why the store refused a change to notes.
public enum NoteStoreError: Error, Equatable, CustomStringConvertible {
    /// The user has no note with this id.
    case noteNotFound(String)
    /// An id in one of the lists that is not a UUID, which the note did not already carry.
    case malformedId(NoteIdList, String)
    /// An id of a tag, project or summary the user has not, which the note did not already carry.
    case notHeld(NoteIdList, String)

    public var description: String {
        switch self {
        case .noteNotFound(let id): "no note has the id \(id)"
        case .malformedId(let list, let id): "\(list.rawValue): \(id) is not a UUID"
        case .notHeld(let list, let id): "\(list.rawValue): no \(list.noun) has the id \(id)"
        }
    }
}

/// Where a user's notes are kept.
public protocol NoteStore: Sendable {
    /// A document's notes as the Research rail lists them, its `@Query` sorted by `lastModified` in
    /// reverse: the latest first, one with no time after any with one (`NULLS LAST`, the web's own,
    /// since the app's order for a nil is its store's), then by id in uppercase.
    func notes(of document: DocumentKey, for user: String) throws -> [NoteRecord]
    /// All the user's notes, in the same order, as All Notes lists them.
    func notes(for user: String) throws -> [NoteRecord]
    /// One of the user's notes, or nil.
    func note(_ id: String, of user: String) throws -> NoteRecord?
    /// Makes a note on a document, with a new id and `now` as both its times. Each id in the lists
    /// must name a tag, project or summary the user has (`NoteStoreError.notHeld`, or `malformedId`
    /// for one that is not a UUID). When `linkedHighlightId` names one of the user's highlights, its
    /// `noteId` becomes the new note's, as the editor's Save links it; any other is passed over, as
    /// the app saves the note unlinked when the highlight has gone.
    @discardableResult func createNote(in document: DocumentKey, bodyText: String, richText: [UInt8]?, projectIds: [String],
                                       userTagIds: [String], selectedSummaryIds: [String], linkedHighlightId: String?,
                                       for user: String, at now: Date) throws -> NoteRecord
    /// Saves a note as the editor's Save does: its three lists, and its body when it was edited, nil
    /// keeping `bodyText` and `richText` byte for byte. `body` makes the edited body from the note as
    /// the save's transaction finds it, so that a rule that depends on what the note holds, such as
    /// the links a save may send back, is held to the row it changes, however many saves race; what
    /// it throws is passed on, and nothing is written. An id the note already carries is kept,
    /// whether or not the user still has what it names, as the app's picker keeps one; any other is
    /// held to the rule of `createNote`. Stamps `lastModified`, as the app's save does.
    @discardableResult func updateNote(_ id: String, body: ((NoteRecord) throws -> NoteBody)?, projectIds: [String],
                                       userTagIds: [String], selectedSummaryIds: [String], for user: String,
                                       at now: Date) throws -> NoteRecord
    /// Deletes a note. A highlight linked to it keeps its `noteId`, as the app leaves one dangling.
    func deleteNote(_ id: String, for user: String) throws
}

extension SQLiteUserStore: NoteStore {
    /// The order `notes(of:for:)` gives.
    private static let listOrder = "last_modified DESC NULLS LAST, upper(id)"

    private static let noteColumns = """
        id, volume_id, document_id, body_text, rich_text, project_ids, user_tag_ids, selected_summary_ids, created_at, last_modified
        """

    public func notes(of document: DocumentKey, for user: String) throws -> [NoteRecord] {
        try reading { db in try Self.notes(of: document, for: user, in: db) }
    }

    public func notes(for user: String) throws -> [NoteRecord] {
        try reading { db in
            let links = try Self.highlightLinks(for: user, in: db)
            return try db.query("SELECT \(Self.noteColumns) FROM notes WHERE user_id = ? ORDER BY \(Self.listOrder)", [.text(user)])
                .map { Self.note($0, links: links) }
        }
    }

    public func note(_ id: String, of user: String) throws -> NoteRecord? {
        guard let id = TagReferences.normalized(id) else { return nil }
        return try reading { try Self.note(id, of: user, in: $0) }
    }

    @discardableResult
    public func createNote(in document: DocumentKey, bodyText: String, richText: [UInt8]?, projectIds: [String],
                           userTagIds: [String], selectedSummaryIds: [String], linkedHighlightId: String?,
                           for user: String, at now: Date) throws -> NoteRecord {
        let time = UserStoreDate.rounded(now)
        return try writing { db in
            let tags = try Self.resolved(userTagIds, .userTagIds, carried: [], for: user, in: db)
            let projects = try Self.resolved(projectIds, .projectIds, carried: [], for: user, in: db)
            let summaries = try Self.resolved(selectedSummaryIds, .selectedSummaryIds, carried: [], for: user, in: db)
            var note = NoteRecord(
                id: UUID().uuidString, volumeId: document.volumeId, documentId: document.documentId, bodyText: bodyText,
                richText: richText, projectIds: projects, userTagIds: tags, selectedSummaryIds: summaries,
                createdAt: time, lastModified: time)
            _ = try db.query(
                "INSERT INTO notes (user_id, \(Self.noteColumns)) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [.text(user), .text(note.id), .text(note.volumeId), .text(note.documentId), .text(bodyText),
                 Self.blob(richText), .text(TagReferences.encode(note.projectIds)), .text(TagReferences.encode(note.userTagIds)),
                 .text(TagReferences.encode(note.selectedSummaryIds)), .text(UserStoreDate.text(time)),
                 .text(UserStoreDate.text(time))])
            // `linkNoteToHighlight`: the highlight's `noteId`, last write winning, as the app's plain id.
            if let highlight = linkedHighlightId.flatMap(TagReferences.normalized),
               try db.scalar("SELECT 1 FROM highlights WHERE user_id = ? AND upper(id) = ?", [.text(user), .text(highlight)]) != nil {
                _ = try db.query("UPDATE highlights SET note_id = ? WHERE user_id = ? AND upper(id) = ?",
                                 [.text(note.id), .text(user), .text(highlight)])
            }
            note.linkedHighlightIds = try Self.highlightLinks(for: user, ofNote: note.id, in: db)[note.id] ?? []
            try Self.refreshSearch(of: document, for: user, in: db)
            return note
        }
    }

    @discardableResult
    public func updateNote(_ id: String, body: ((NoteRecord) throws -> NoteBody)?, projectIds: [String],
                           userTagIds: [String], selectedSummaryIds: [String], for user: String,
                           at now: Date) throws -> NoteRecord {
        try writing { db in
            guard let key = TagReferences.normalized(id), var note = try Self.note(key, of: user, in: db) else {
                throw NoteStoreError.noteNotFound(id)
            }
            // The body first, as the route refused one before the lists, and from this row as it is.
            let body = try body?(note)
            note.userTagIds = try Self.resolved(userTagIds, .userTagIds, carried: note.userTagIds, for: user, in: db)
            note.projectIds = try Self.resolved(projectIds, .projectIds, carried: note.projectIds, for: user, in: db)
            note.selectedSummaryIds = try Self.resolved(selectedSummaryIds, .selectedSummaryIds, carried: note.selectedSummaryIds,
                                                        for: user, in: db)
            note.lastModified = UserStoreDate.rounded(now)
            var assignments: [(String, SQLiteValue)] = [
                ("project_ids", .text(TagReferences.encode(note.projectIds))),
                ("user_tag_ids", .text(TagReferences.encode(note.userTagIds))),
                ("selected_summary_ids", .text(TagReferences.encode(note.selectedSummaryIds))),
                ("last_modified", .text(UserStoreDate.text(now))),
            ]
            // A body left alone is not written at all, so its bytes stay exactly as they were.
            if let body {
                note.bodyText = body.text
                note.richText = body.richText
                assignments += [("body_text", .text(body.text)), ("rich_text", Self.blob(body.richText))]
            }
            _ = try db.query(
                "UPDATE notes SET \(assignments.map { "\($0.0) = ?" }.joined(separator: ", ")) WHERE user_id = ? AND upper(id) = ?",
                assignments.map(\.1) + [.text(user), .text(key)])
            try Self.refreshSearch(of: note.document, for: user, in: db)
            return note
        }
    }

    public func deleteNote(_ id: String, for user: String) throws {
        try writing { db in
            guard let key = TagReferences.normalized(id), let note = try Self.note(key, of: user, in: db) else {
                throw NoteStoreError.noteNotFound(id)
            }
            _ = try db.query("DELETE FROM notes WHERE user_id = ? AND upper(id) = ?", [.text(user), .text(key)])
            try Self.refreshSearch(of: note.document, for: user, in: db)
        }
    }

    // MARK: Within a transaction

    /// A document's notes, in the rail's order, with the links of those notes alone.
    private static func notes(of document: DocumentKey, for user: String, in db: SQLiteConnection) throws -> [NoteRecord] {
        let documentNotes = "SELECT upper(id) FROM notes WHERE user_id = ? AND volume_id = ? AND document_id = ?"
        let keys: [SQLiteValue] = [.text(user), .text(document.volumeId), .text(document.documentId)]
        let links = try highlightLinks(for: user, narrowedBy: "AND upper(note_id) IN (\(documentNotes))", keys, in: db)
        return try db.query(
            "SELECT \(noteColumns) FROM notes WHERE user_id = ? AND volume_id = ? AND document_id = ? ORDER BY \(listOrder)", keys)
            .map { note($0, links: links) }
    }

    private static func note(_ id: String, of user: String, in db: SQLiteConnection) throws -> NoteRecord? {
        // An id in any case, as an import may write one.
        guard let row = try db.query("SELECT \(noteColumns) FROM notes WHERE user_id = ? AND upper(id) = ?",
                                     [.text(user), .text(id)]).first else { return nil }
        return note(row, links: try highlightLinks(for: user, ofNote: id, in: db))
    }

    private static func note(_ row: [SQLiteValue], links: [String: [String]]) -> NoteRecord {
        let id = row[0].text ?? ""
        let richText: [UInt8]? = switch row[4] {
        case .blob(let bytes): bytes
        case .text(let text): Array(text.utf8)
        case .null, .integer, .real: nil
        }
        return NoteRecord(id: id, volumeId: row[1].text ?? "", documentId: row[2].text ?? "", bodyText: row[3].text ?? "",
                          richText: richText, projectIds: ids(row[5]), userTagIds: ids(row[6]),
                          selectedSummaryIds: ids(row[7]), createdAt: row[8].text.flatMap(UserStoreDate.date),
                          lastModified: row[9].text.flatMap(UserStoreDate.date),
                          linkedHighlightIds: links[TagReferences.normalized(id) ?? id.uppercased()] ?? [])
    }

    /// A stored list of ids; a list that will not decode reads as none, as the tag rewrites leave it.
    private static func ids(_ value: SQLiteValue) -> [String] {
        value.text.flatMap(TagReferences.decode) ?? []
    }

    private static func blob(_ bytes: [UInt8]?) -> SQLiteValue {
        bytes.map { .blob($0) } ?? .null
    }

    /// The ids of the user's highlights that name each note, by the note's id in uppercase, each
    /// note's in the order the reader draws highlights: every note's, or with `filter`, a clause
    /// on `note_id` and its bindings, only those it keeps. A note's links are read for that note
    /// alone, so that a read or a save, under the store's one lock, returns no more rows the more
    /// highlights the user has linked elsewhere. SQLite still visits each of the user's highlights
    /// to test its `note_id`: an index on `(user_id, upper(note_id))`, the expression these queries
    /// test, would spare that, and would be a migration (one on `note_id` itself would not, since
    /// the queries read it in uppercase).
    private static func highlightLinks(for user: String, narrowedBy filter: String = "", _ bindings: [SQLiteValue] = [],
                                       in db: SQLiteConnection) throws -> [String: [String]] {
        var links: [String: [String]] = [:]
        for row in try db.query(
            """
            SELECT id, note_id FROM highlights WHERE user_id = ? AND note_id IS NOT NULL \(filter)
                ORDER BY created_at ASC NULLS FIRST, upper(id)
            """, [.text(user)] + bindings) {
            guard let id = row[0].text, let note = row[1].text else { continue }
            links[TagReferences.normalized(note) ?? note.uppercased(), default: []].append(id)
        }
        return links
    }

    /// The links of one note, whose id is in uppercase, as `ResearchNoteExport.linkedHighlightIds`
    /// derives them: a `noteId` in any case names it.
    private static func highlightLinks(for user: String, ofNote id: String, in db: SQLiteConnection) throws -> [String: [String]] {
        try highlightLinks(for: user, narrowedBy: "AND upper(note_id) = ?", [.text(id)], in: db)
    }

    /// `given` as a note keeps it: each id in uppercase, once, in the order given. An id the note
    /// already carries is kept whatever it names, as the app's picker keeps an id its catalogue
    /// lacks (and kept as it was written when it is no UUID); any other must be a UUID naming one of
    /// the user's rows, so that a stale editor cannot put back an id a delete has just taken out.
    private static func resolved(_ given: [String], _ list: NoteIdList, carried: [String], for user: String,
                                 in db: SQLiteConnection) throws -> [String] {
        var kept: [String] = []
        for id in given {
            let key = TagReferences.normalized(id)
            let isCarried = carried.contains { $0 == id || (key != nil && TagReferences.normalized($0) == key) }
            let value: String
            if let key {
                if !isCarried, try db.scalar("SELECT 1 FROM \(list.table) WHERE user_id = ? AND upper(id) = ?",
                                             [.text(user), .text(key)]) == nil {
                    throw NoteStoreError.notHeld(list, id)
                }
                value = key
            } else {
                guard isCarried else { throw NoteStoreError.malformedId(list, id) }
                value = id
            }
            if !kept.contains(value) { kept.append(value) }
        }
        return kept
    }
}
