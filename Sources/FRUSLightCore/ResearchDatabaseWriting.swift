// An export made with the owner's writing (PLAN's S16e): what the Mac's index keeps of it, read from
// the server's copy before the kit's strip removes it, and the records it becomes in the importing
// user's store. The store writes them as a JSON import writes its rows (S16c), keyed by id, a copy it
// holds replaced only by a newer one, at the time the Mac stamped the export with; and it leaves out
// what the user's own records hold already. A note block and a summary are marked as from a research
// database by values the app's model has, so the store gains no column: a summary by its prompt, as the
// app knows a collection's headnote draft and the web its reader's own summaries, and a note block by
// its id, named for its document. The tags are the Mac's own, under their ids, and so are the
// documents they are on.

import Crypto
import Foundation

/// The owner's writing as an export made with Include My Notes, Summaries, and Tags holds it, which is
/// what the Mac's index keeps: by document, its newest summary but a headnote draft
/// (`GeneratedSummary.newestNonDraftPerDocument`), its notes joined into one block
/// (`ResearchNote.indexedTextPerDocument`) and the tags it carries; and the name of every tag.
public struct ResearchDatabaseWriting: Sendable, Equatable {
    /// One document's writing.
    public struct Document: Sendable, Equatable {
        public var key: DocumentKey
        /// `document_cache.summary_text`, or nil.
        public var summaryText: String?
        /// `note_text`, the document's notes oldest first, joined by a blank line; or nil.
        public var noteText: String?
        /// `user_tag_ids`, as the store keeps ids, each once.
        public var tagIds: [String]

        public init(key: DocumentKey, summaryText: String?, noteText: String?, tagIds: [String]) {
            self.key = key
            self.summaryText = summaryText
            self.noteText = noteText
            self.tagIds = tagIds
        }
    }

    /// A row of `user_tags`.
    public struct Tag: Sendable, Equatable {
        /// The Mac's id, as the store keeps ids.
        public var id: String
        public var name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    /// Each document with a summary, a note block or a tag, by its key.
    public var documents: [Document]
    /// In the order the Mac wrote them.
    public var tags: [Tag]
    /// When the Mac made the export, its stamp's `exported_at`: the time of every record it gives,
    /// which the store compares with its own copy's.
    public var exportedAt: Date

    public init(documents: [Document], tags: [Tag], exportedAt: Date) {
        self.documents = documents
        self.tags = tags
        self.exportedAt = exportedAt
    }

    /// The writing `db`, a copy of an export, holds. A text that is blank once trimmed of white space
    /// and new lines is none, as the app's join leaves out a blank note. An id that is no UUID, which
    /// the app never writes, is given one named for it, so a tag and the documents it is on still
    /// match.
    public init(reading db: SQLiteConnection, exportedAt: Date) throws {
        func text(_ value: SQLiteValue) -> String? {
            guard let text = value.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return text
        }
        var documents: [Document] = []
        for row in try db.query("""
            SELECT volume_id, document_id, summary_text, note_text, user_tag_ids FROM document_cache
                WHERE coalesce(summary_text, '') <> '' OR coalesce(note_text, '') <> '' OR coalesce(user_tag_ids, '') <> ''
                ORDER BY volume_id, document_id
            """) {
            var tagIds: [String] = []
            for token in (row[4].text ?? "").split(whereSeparator: \.isWhitespace) {
                let id = ResearchDatabaseMark.tagId(String(token))
                if !tagIds.contains(id) { tagIds.append(id) }
            }
            let document = Document(key: DocumentKey(volumeId: row[0].text ?? "", documentId: row[1].text ?? ""),
                                    summaryText: text(row[2]), noteText: text(row[3]), tagIds: tagIds)
            if document.summaryText != nil || document.noteText != nil || !document.tagIds.isEmpty {
                documents.append(document)
            }
        }
        var tags: [Tag] = []
        if try db.hasObject(named: "user_tags") {
            for row in try db.query("SELECT tag_id, name FROM user_tags ORDER BY rowid") {
                let id = ResearchDatabaseMark.tagId(row[0].text ?? "")
                guard !tags.contains(where: { $0.id == id }) else { continue }
                tags.append(Tag(id: id, name: row[1].text ?? ""))
            }
        }
        self.init(documents: documents, tags: tags, exportedAt: exportedAt)
    }

    /// The documents with a note block, with a summary, and the tags' assignments to documents.
    public var noteBlocks: Int { documents.filter { $0.noteText != nil }.count }
    public var summaries: Int { documents.filter { $0.summaryText != nil }.count }
    public var tagAssignments: Int { documents.reduce(0) { $0 + $1.tagIds.count } }
}

/// How the store knows a record an import took from a research database: by values the app's model
/// already has, so it gains no column, and the mark goes wherever the record goes, through the web's
/// export and an import of it.
public enum ResearchDatabaseMark {
    /// The web's prompt id for a summary taken from a research database, which no prompt row holds:
    /// the index keeps a summary's text alone, not the prompt that made it. The app knows a
    /// collection's headnote draft by its prompt in the same way, and the web its reader's own
    /// summaries by `OwnSummary.promptId`, which this is not.
    public static let promptId = "0EB00000-0000-4000-8000-000000000002"

    /// The namespace of the ids the records of a research database are given, each named for what it
    /// is: the web's own.
    static let namespace = UUID(uuidString: "0EB00000-0000-4000-8000-0000000000DB")!

    /// The id of a document's note block: a name-based UUID, version 5, of the document. It says what
    /// the note is, and an import of a later export finds the block again and replaces it, rather than
    /// adding another.
    public static func noteId(for document: DocumentKey) -> String {
        nameBased("note/\(document.volumeId)/\(document.documentId)")
    }

    /// The id of a document's summary from a research database, named as `noteId(for:)` is.
    public static func summaryId(for document: DocumentKey) -> String {
        nameBased("summary/\(document.volumeId)/\(document.documentId)")
    }

    /// The id of a tag's assignment to a document, which the index keeps without one.
    public static func assignmentId(of tag: String, on document: DocumentKey) -> String {
        nameBased("assignment/\(document.volumeId)/\(document.documentId)/\(tag)")
    }

    /// A tag's id as the store keeps it: the Mac's `uuidString`, or for one that is no UUID, a UUID
    /// named for it.
    static func tagId(_ raw: String) -> String {
        TagReferences.normalized(raw) ?? nameBased("tag/\(raw)")
    }

    /// Whether a note is a document's note block from a research database.
    public static func isNoteBlock(_ note: NoteRecord) -> Bool {
        UserSearchText.uuidString(note.id) == noteId(for: note.document)
    }

    /// Whether a summary is from a research database.
    public static func isFromResearchDatabase(_ summary: SummaryRecord) -> Bool {
        UserSearchText.uuidString(summary.promptId) == promptId
    }

    /// The name-based UUID of `name` in `namespace`, by RFC 9562's version 5: the first 16 bytes of the
    /// SHA-1 of the namespace's bytes and the name's UTF-8, with the version and variant bits set.
    static func nameBased(_ name: String, in namespace: UUID = namespace) -> String {
        let bytes = withUnsafeBytes(of: namespace.uuid) { Array($0) } + Array(name.utf8)
        var b = Array(Insecure.SHA1.hash(data: bytes).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50
        b[8] = (b[8] & 0x3F) | 0x80
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15])).uuidString
    }
}

/// What became of an export's writing in the user's store: each kind, as the app's export sheet names
/// it, counted as a JSON import counts a type.
public struct MovedWriting: Sendable, Equatable, Codable {
    /// Research Notes: a document's note block each. One the user's other notes on the document hold
    /// already, joined as the index joins them, is kept as they are.
    public var notes: ImportCount
    /// Generated Summaries: a document's newest each. One whose text a summary of the user's on the
    /// document has already is kept as it is.
    public var summaries: ImportCount
    public var tags: ImportCount
    /// One for each document and tag: an assignment the user holds already is kept.
    public var tagAssignments: ImportCount
    /// How many documents the user's notes and summaries make findable, once `user_search` is made again.
    public var searchableDocuments: Int

    public init(notes: ImportCount, summaries: ImportCount, tags: ImportCount, tagAssignments: ImportCount,
                searchableDocuments: Int) {
        self.notes = notes
        self.summaries = summaries
        self.tags = tags
        self.tagAssignments = tagAssignments
        self.searchableDocuments = searchableDocuments
    }

    /// What the import's report says of it: what moved, in the words of the app's export sheet, what
    /// marks it, and the JSON export the index's writing is no substitute for, as SPEC recommends.
    public var report: String {
        let counts = [notes, summaries, tags, tagAssignments]
        let unchanged = counts.allSatisfy { $0.added == 0 && $0.replaced == 0 }
        func phrase(_ count: ImportCount, _ one: String, _ many: String) -> String? {
            guard count.total > 0 else { return nil }
            var parts: [String] = []
            if count.added > 0, count.added < count.total { parts.append("\(count.added) new here") }
            if count.replaced > 0 { parts.append("\(count.replaced) replacing \(count.replaced == 1 ? "an older copy" : "older copies")") }
            if count.kept > 0, !unchanged { parts.append("\(count.kept) you had here already") }
            let head = "\(count.total) \(count.total == 1 ? one : many)"
            return parts.isEmpty ? head : "\(head) (\(parts.joined(separator: ", ")))"
        }
        let moved = [
            phrase(notes, "Research Note, a document's note block", "Research Notes, each a document's note block"),
            phrase(summaries, "Generated Summary, a document's newest", "Generated Summaries, each a document's newest"),
            phrase(tags, "Tag", "Tags"),
            phrase(tagAssignments, "Tag Assignment", "Tag Assignments"),
        ].compactMap { $0 }
        guard !moved.isEmpty else {
            return "The export was made with Include My Notes, Summaries, and Tags, but held no notes, summaries or tags."
        }
        let list = moved.count == 1 ? moved[0] : moved.dropLast().joined(separator: "; ") + "; and " + moved[moved.count - 1]
        var sentences = [unchanged
            ? "Your research data held the notes, summaries and tags in the export already, so none of them changed, and the server's copy of the index holds none of them: \(list)."
            : "Your notes, summaries and tags in the export were moved into your research data, and the server's copy of the index holds none of them: \(list)."]
        if notes.total + summaries.total > 0 {
            sentences.append("The note blocks and summaries are marked as from a research database.")
        }
        sentences.append("A research database keeps only one note block and the newest summary for each document: for every note and summary as you wrote them, export with Settings ▸ Data & Recovery ▸ Export as JSON in FRUS Explorer, with Include AI-Generated Summaries on, and import the file in Settings ▸ Data.")
        return sentences.joined(separator: " ")
    }
}

/// Where an export's writing is kept: the user store.
public protocol ResearchDatabaseWritingStore: Sendable {
    /// Writes `writing` under `user` in one transaction, as a JSON import writes its rows: each tag
    /// under its Mac id; each tag's assignment to a document unless the user's tags on the document
    /// include it; each document's note block as a note, plain text, under `ResearchDatabaseMark`'s id
    /// for it, unless the user's other notes on the document, joined as the index joins them, are the
    /// block already; and each document's summary under the mark's id and prompt, with
    /// `summaryFormat`, the kit's `ResponseFormat.general` as its encoder writes it, unless a summary
    /// of the user's on the document has its text. A record the store holds by its id is replaced
    /// only by a newer copy, the export's time being each record's; a new one takes that time as when
    /// it was made too. Then the user's rows of `user_search` are made again.
    func keep(_ writing: ResearchDatabaseWriting, summaryFormat: String, for user: String) throws -> MovedWriting
}

extension SQLiteUserStore: ResearchDatabaseWritingStore {
    public func keep(_ export: ResearchDatabaseWriting, summaryFormat: String, for user: String) throws -> MovedWriting {
        let time = SQLiteValue.text(UserStoreDate.text(export.exportedAt))
        return try writing { db in
            // What the user holds of each document, read once.
            var notes: [DocumentKey: [NoteRecord]] = [:]
            for row in try db.query("SELECT id, volume_id, document_id, body_text, created_at FROM notes WHERE user_id = ?",
                                    [.text(user)]) {
                let document = DocumentKey(volumeId: row[1].text ?? "", documentId: row[2].text ?? "")
                notes[document, default: []].append(NoteRecord(
                    id: row[0].text ?? "", volumeId: document.volumeId, documentId: document.documentId,
                    bodyText: row[3].text ?? "", richText: nil, projectIds: [], userTagIds: [], selectedSummaryIds: [],
                    createdAt: row[4].text.flatMap(UserStoreDate.date), lastModified: nil))
            }
            var summaryTexts: [DocumentKey: [(id: String, text: String)]] = [:]
            for row in try db.query(
                "SELECT id, volume_id, document_id, response_text FROM summaries WHERE user_id = ? AND is_headnote_draft = 0",
                [.text(user)]) {
                let document = DocumentKey(volumeId: row[1].text ?? "", documentId: row[2].text ?? "")
                summaryTexts[document, default: []].append((UserSearchText.uuidString(row[0].text ?? ""), row[3].text ?? ""))
            }
            var assigned: Set<String> = []
            for row in try db.query("SELECT volume_id, document_id, tag_id FROM tag_assignments WHERE user_id = ?", [.text(user)]) {
                assigned.insert("\(row[0].text ?? "")/\(row[1].text ?? "")/\(UserSearchText.uuidString(row[2].text ?? ""))")
            }

            // The rows, and what the user's own records hold already.
            var batch = ResearchImportBatch(rows: ["tags": [], "tag_assignments": [], "notes": [], "summaries": []])
            var held = (notes: 0, summaries: 0, assignments: 0)
            for tag in export.tags {
                batch.rows["tags", default: []].append(ImportRow(
                    values: ["id": .text(tag.id), "name": .text(tag.name), "last_modified": time],
                    defaults: ["created_at": time]))
            }
            for document in export.documents {
                let key = document.key
                let place: [String: SQLiteValue] = ["volume_id": .text(key.volumeId), "document_id": .text(key.documentId)]
                for tag in document.tagIds {
                    guard assigned.insert("\(key.volumeId)/\(key.documentId)/\(tag)").inserted else {
                        held.assignments += 1
                        continue
                    }
                    batch.rows["tag_assignments", default: []].append(ImportRow(values: place.merging([
                        "id": .text(ResearchDatabaseMark.assignmentId(of: tag, on: key)), "tag_id": .text(tag),
                        "created_at": time,
                    ]) { $1 }))
                }
                if let block = document.noteText {
                    let id = ResearchDatabaseMark.noteId(for: key)
                    if UserSearchText.noteText((notes[key] ?? []).filter { UserSearchText.uuidString($0.id) != id }) == block {
                        held.notes += 1
                    } else {
                        // Plain text, as the index keeps it: a block the reader formatted here is plain again.
                        batch.rows["notes", default: []].append(ImportRow(
                            values: place.merging(["id": .text(id), "body_text": .text(block), "rich_text": .null,
                                                   "last_modified": time]) { $1 },
                            defaults: ["created_at": time, "project_ids": .text("[]"), "user_tag_ids": .text("[]"),
                                       "selected_summary_ids": .text("[]")]))
                    }
                }
                if let text = document.summaryText {
                    let id = ResearchDatabaseMark.summaryId(for: key)
                    if (summaryTexts[key] ?? []).contains(where: { $0.id != id && $0.text == text }) {
                        held.summaries += 1
                    } else {
                        // The index says nothing of how the summary was made: by the model, as every
                        // summary the app's index keeps is, none of the authorship, as a file before
                        // version 5 gives it, which every reader takes as an AI summary.
                        batch.rows["summaries", default: []].append(ImportRow(
                            values: place.merging([
                                "id": .text(id), "prompt_id": .text(ResearchDatabaseMark.promptId), "response_text": .text(text),
                                "response_format": .text(summaryFormat), "was_chunked": .integer(0), "authorship": .null,
                                "is_headnote_draft": .integer(0), "last_modified": time,
                            ]) { $1 },
                            defaults: ["created_at": time, "source_content_hash": .null, "project_id": .null]))
                    }
                }
            }
            let counts = try Self.write(batch, tables: try Self.check(batch), for: user, in: db)
            func count(_ table: String, held: Int) -> ImportCount {
                var count = counts[table] ?? ImportCount()
                count.kept += held
                return count
            }
            return MovedWriting(notes: count("notes", held: held.notes), summaries: count("summaries", held: held.summaries),
                                tags: count("tags", held: 0), tagAssignments: count("tag_assignments", held: held.assignments),
                                searchableDocuments: try Self.rebuildSearch(for: user, in: db))
        }
    }
}

/// One statement of the kit's strip, `ResearchDatabaseStrip.Step`, as Import mode runs it.
public struct StripStep: Sendable, Equatable {
    /// What the statement does, as the app's export names it in an error: "removing your tag names".
    public let action: String
    public let sql: String

    public init(action: String, sql: String) {
        self.action = action
        self.sql = sql
    }
}

/// What Import mode does with an export made with the owner's writing: it keeps the writing in the
/// importing user's store, and strips the copy with the kit's own statements before it is served.
public struct WritingMove: Sendable {
    /// `ResearchDatabaseStrip.steps`, in their order.
    public let strip: [StripStep]
    /// Keeps the writing in the importing user's store, in one transaction, and says what became of it.
    public let keep: @Sendable (ResearchDatabaseWriting) throws -> MovedWriting

    public init(strip: [StripStep], keep: @escaping @Sendable (ResearchDatabaseWriting) throws -> MovedWriting) {
        self.strip = strip
        self.keep = keep
    }
}
