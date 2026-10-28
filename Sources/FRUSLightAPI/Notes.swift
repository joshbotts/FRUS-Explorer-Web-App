// /api/v1/me/notes and a document's notes (PLAN's S15d): the user's research notes, made, saved and
// deleted as the app's note editor does them, each by the store's rules (`NoteStore`). A note's
// formatting goes to and from the browser as runs, and the store keeps it as RTF, which the codec
// (FRUSRichText) reads and writes. A save rewrites the RTF only when the body was edited, as the app's
// editor rewrites it only when its view reports an edit, so a note's Mac formatting survives a change
// of its tags.

import FRUSCoreKit
import FRUSLightCore
import FRUSRichText
import Foundation
import Hummingbird

/// A note in a list: the fields of the Mac's export (`ResearchNoteExport`) but its formatting.
public struct NoteSummary: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var volumeId: String
    public var documentId: String
    /// The plain text, which is canonical: the lists, search and the Markdown export read it.
    public var bodyText: String
    public var projectIds: [String]
    public var userTagIds: [String]
    public var selectedSummaryIds: [String]
    /// The user's highlights linked to the note, as the export derives them from their `noteId`.
    public var linkedHighlightIds: [String]
    /// As the store keeps dates, or null.
    public var createdAt: String?
    public var lastModified: String?
    /// A document's note block from a research database, an export made with the owner's writing,
    /// which joins its notes into one (`ResearchDatabaseMark.isNoteBlock`, S16e).
    public var fromResearchDatabase: Bool

    init(_ record: NoteRecord) {
        id = NoteRoutes.wire(record.id)
        volumeId = record.volumeId
        documentId = record.documentId
        bodyText = record.bodyText
        projectIds = record.projectIds.map(NoteRoutes.wire)
        userTagIds = record.userTagIds.map(NoteRoutes.wire)
        selectedSummaryIds = record.selectedSummaryIds.map(NoteRoutes.wire)
        linkedHighlightIds = record.linkedHighlightIds.map(NoteRoutes.wire)
        createdAt = record.createdAt.map(UserStoreDate.text)
        lastModified = record.lastModified.map(UserStoreDate.text)
        fromResearchDatabase = ResearchDatabaseMark.isNoteBlock(record)
    }

    /// Each field, a date with none as null.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(volumeId, forKey: .volumeId)
        try container.encode(documentId, forKey: .documentId)
        try container.encode(bodyText, forKey: .bodyText)
        try container.encode(projectIds, forKey: .projectIds)
        try container.encode(userTagIds, forKey: .userTagIds)
        try container.encode(selectedSummaryIds, forKey: .selectedSummaryIds)
        try container.encode(linkedHighlightIds, forKey: .linkedHighlightIds)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(fromResearchDatabase, forKey: .fromResearchDatabase)
    }
}

/// One note, with its formatting: a list's fields, and the runs its RTF reads as.
public struct Note: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var volumeId: String
    public var documentId: String
    public var bodyText: String
    public var projectIds: [String]
    public var userTagIds: [String]
    public var selectedSummaryIds: [String]
    public var linkedHighlightIds: [String]
    public var createdAt: String?
    public var lastModified: String?
    public var fromResearchDatabase: Bool
    /// The formatting, as the codec reads the stored RTF, in canonical form: a line break formatted
    /// as the text before it, neighbours of one formatting joined, none empty. Null for a plain note,
    /// and when `formattingKept`.
    public var runs: [RichTextRun]?
    /// The note keeps RTF that `runs` cannot carry, until its body is next edited: RTF the codec
    /// cannot read, one whose text is not `bodyText` (from another device's edit, or a body holding
    /// a character Apple's writer folds into a line break, such as U+2029), or one holding what a
    /// save could not send back. `bodyText` is the note's text then, the web's own choice, since the
    /// app's editor would show the RTF's.
    public var formattingKept: Bool

    init(_ record: NoteRecord) {
        let list = NoteSummary(record)
        id = list.id
        volumeId = list.volumeId
        documentId = list.documentId
        bodyText = list.bodyText
        projectIds = list.projectIds
        userTagIds = list.userTagIds
        selectedSummaryIds = list.selectedSummaryIds
        linkedHighlightIds = list.linkedHighlightIds
        createdAt = list.createdAt
        lastModified = list.lastModified
        fromResearchDatabase = list.fromResearchDatabase
        let formatting = NoteFormatting.runs(of: record)
        runs = formatting.runs
        formattingKept = formatting.kept
    }

    /// Each field, a date with none, and runs for a plain note, as null.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(volumeId, forKey: .volumeId)
        try container.encode(documentId, forKey: .documentId)
        try container.encode(bodyText, forKey: .bodyText)
        try container.encode(projectIds, forKey: .projectIds)
        try container.encode(userTagIds, forKey: .userTagIds)
        try container.encode(selectedSummaryIds, forKey: .selectedSummaryIds)
        try container.encode(linkedHighlightIds, forKey: .linkedHighlightIds)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(fromResearchDatabase, forKey: .fromResearchDatabase)
        try container.encode(runs, forKey: .runs)
        try container.encode(formattingKept, forKey: .formattingKept)
    }
}

/// All the user's notes, the latest first.
public struct NoteList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [NoteSummary]
}

/// A document's notes, as the Research rail lists them, the latest first.
public struct DocumentNotes: Codable, Equatable, Sendable, ResponseEncodable {
    public var volumeId: String
    public var documentId: String
    public var items: [NoteSummary]
}

/// A note's formatting between the store's RTF and the wire's runs.
enum NoteFormatting {
    /// The runs a stored note's RTF reads as, canonical, and whether RTF is kept that they cannot
    /// carry. Every value this gives a save can send back.
    static func runs(of record: NoteRecord) -> (runs: [RichTextRun]?, kept: Bool) {
        guard let bytes = record.richText else { return (nil, false) }
        guard let reading = RTFReader.read(bytes), reading.text.utf16.elementsEqual(record.bodyText.utf16) else {
            return (nil, true)
        }
        let runs = RichTextRuns.canonical(reading.runs)
        // A link the writer could not write again, from RTF the Mac did not write, or a character a
        // note's runs may not hold: kept as bytes rather than offered to a save that would refuse it.
        guard RichTextRuns.problem(runs, bodyText: record.bodyText) == nil else { return (nil, true) }
        return (runs, false)
    }

    /// The links a stored note's RTF holds, which a save may send back whatever their scheme.
    static func links(of record: NoteRecord) -> Set<String> {
        guard let bytes = record.richText, let reading = RTFReader.read(bytes) else { return [] }
        return Set(reading.runs.compactMap(\.linkURL))
    }

    /// A body edit as the store keeps it. `runs` nil is a plain-mode edit, which keeps no RTF, as
    /// the app's `setPlainBody` keeps none; runs are a formatted-mode edit, which keeps the codec's
    /// RTF of them once they are held to the codec's rules and made canonical. A link the stored
    /// note does not hold must be one a browser may follow; a link already in the note is accepted
    /// back, as the app links any text. `stored` gives the note's links, and is asked only for a
    /// link a browser may not follow, since it reads the note's RTF, a long note's slowest step. A
    /// new note with no text keeps no RTF, as the app's editor stores none until something is
    /// typed. The text may be `UserDataServices.noteTextLimit` long, a quarter of the route's body
    /// limit, so that a text that long can be sent again formatted while its runs and escapes fit
    /// in the rest (`UserDataServices.noteBodyLimit` says when they do not).
    static func body(_ text: String, runs: [RichTextRun]?, stored: () -> Set<String>, isNew: Bool) throws -> NoteBody {
        guard text.utf8.count <= UserDataServices.noteTextLimit else {
            throw NoteRoutes.invalidField(
                "bodyText", "a note may hold at most \(UserDataServices.noteTextLimit / 1_048_576) MiB of text, in UTF-8.")
        }
        guard let runs else {
            // The app stores any text; SQLite's text ends at a NUL.
            guard !text.unicodeScalars.contains("\0") else {
                throw NoteRoutes.invalidField("bodyText", "a note cannot hold U+0000.")
            }
            return NoteBody(text: text, richText: nil)
        }
        if let problem = RichTextRuns.problem(runs, bodyText: text) {
            throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: problem)
        }
        let unfollowable = runs.compactMap(\.linkURL).filter { !RichTextRuns.isFollowable($0) }
        if !unfollowable.isEmpty {
            let held = stored()
            if let url = unfollowable.first(where: { !held.contains($0) }) {
                throw NoteRoutes.invalidField("runs", "linkURL \(url) is not http, https or mailto, which a new link must be.")
            }
        }
        let canonical = RichTextRuns.canonical(runs)
        if isNew, canonical.isEmpty { return NoteBody(text: text, richText: nil) }
        return NoteBody(text: text, richText: RTFWriter.write(canonical))
    }

    /// A save's body edit, made by the store from the note as its transaction finds it, so that the
    /// links accepted back are those of the row the save changes, not of one read before it.
    static func edit(_ text: String, runs: [RichTextRun]?) -> (NoteRecord) throws -> NoteBody {
        { note in try body(text, runs: runs, stored: { links(of: note) }, isNew: false) }
    }

    /// The `runs` of a body: null, or an array of runs, each with only a run's fields.
    static func decodeRuns<Key: CodingKey>(from container: KeyedDecodingContainer<Key>, forKey key: Key) throws -> [RichTextRun]? {
        if try container.decodeNil(forKey: key) { return nil }
        let fields: Set<String> = ["text", "bold", "italic", "underline", "colorHex", "linkURL"]
        let objects = try container.decode([[String: Ignored]].self, forKey: key)
        for (index, object) in objects.enumerated() {
            if let unknown = object.keys.sorted().first(where: { !fields.contains($0) }) {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [key], debugDescription: "run \(index) holds \(unknown), and a run holds \(fields.sorted().joined(separator: ", ")) only."))
            }
        }
        return try container.decode([RichTextRun].self, forKey: key)
    }

    /// Any JSON value, read and set aside.
    private struct Ignored: Decodable {
        init(from decoder: any Decoder) throws {}
    }
}

enum NoteRoutes {
    /// A new note: its body, with `runs` null for a plain one, its lists, and the highlight it was
    /// written for, from the rail's Add Note to Highlight.
    struct NewNote: Decodable {
        let bodyText: String
        let runs: [RichTextRun]?
        let userTagIds: [String]
        let projectIds: [String]
        let selectedSummaryIds: [String]
        let linkedHighlightId: String?

        static let fields: Set<String> = ["bodyText", "runs", "userTagIds", "projectIds", "selectedSummaryIds", "linkedHighlightId"]

        enum CodingKeys: String, CodingKey {
            case bodyText, runs, userTagIds, projectIds, selectedSummaryIds, linkedHighlightId
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            bodyText = try container.decode(String.self, forKey: .bodyText)
            guard container.contains(.runs) else {
                throw DecodingError.keyNotFound(CodingKeys.runs, .init(codingPath: [], debugDescription: "required"))
            }
            runs = try NoteFormatting.decodeRuns(from: container, forKey: .runs)
            userTagIds = try container.decode([String].self, forKey: .userTagIds)
            projectIds = try container.decode([String].self, forKey: .projectIds)
            selectedSummaryIds = try container.decode([String].self, forKey: .selectedSummaryIds)
            linkedHighlightId = try container.decodeIfPresent(String.self, forKey: .linkedHighlightId)
        }
    }

    /// A save: the three lists, always; and `bodyText` with `runs` only when the body was edited in
    /// the editor, `runs` null for a plain-mode edit. Both absent keep the body as it is stored. A
    /// key absent and a key null are told apart here, as a default decoder cannot.
    struct NoteEdit: Decodable {
        let body: (text: String, runs: [RichTextRun]?)?
        let userTagIds: [String]
        let projectIds: [String]
        let selectedSummaryIds: [String]

        static let fields: Set<String> = ["bodyText", "runs", "userTagIds", "projectIds", "selectedSummaryIds"]

        enum CodingKeys: String, CodingKey {
            case bodyText, runs, userTagIds, projectIds, selectedSummaryIds
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch (container.contains(.bodyText), container.contains(.runs)) {
            case (false, false):
                body = nil
            case (true, true):
                if try container.decodeNil(forKey: .bodyText) {
                    throw DecodingError.valueNotFound(String.self, .init(
                        codingPath: [CodingKeys.bodyText], debugDescription: "must be the note's text, not null."))
                }
                body = (try container.decode(String.self, forKey: .bodyText),
                        try NoteFormatting.decodeRuns(from: container, forKey: .runs))
            case (true, false):
                throw DecodingError.keyNotFound(CodingKeys.runs, .init(
                    codingPath: [], debugDescription: "required with bodyText: the edit's runs, or null for a plain one"))
            case (false, true):
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [CodingKeys.runs], debugDescription: "runs come with the bodyText they format, and this edit has none."))
            }
            userTagIds = try container.decode([String].self, forKey: .userTagIds)
            projectIds = try container.decode([String].self, forKey: .projectIds)
            selectedSummaryIds = try container.decode([String].self, forKey: .selectedSummaryIds)
        }
    }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    provider: ServedIndexProvider) {
        let store = services.store
        let now = services.now
        let limit = UserDataServices.noteBodyLimit

        me.get("notes") { request, context -> NoteList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let notes = try await Blocking.run { try store.notes(for: user.id) }
            return NoteList(total: notes.count, items: notes.map(NoteSummary.init))
        }
        // Export Notes as Markdown: before notes/:noteId, which it would otherwise be.
        me.get("notes/export") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let (notes, tags) = try await Blocking.run { (try store.notes(for: user.id), try store.tags(of: user.id)) }
            return try await NotesExport.response(notes: notes, tags: tags, provider: provider, resources: resources)
        }
        me.get("notes/:noteId") { request, context -> Note in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("noteId")
            // The answer reads the note's RTF, so it is made off the cooperative pool too.
            guard let note = try await Blocking.run({ try store.note(id, of: user.id).map(Note.init) }) else {
                throw problem(.noteNotFound(id))
            }
            return note
        }
        // The editor's Save. PUT, where tags and highlights change by PATCH: a save sends the whole
        // of what the editor holds, every list replaced, and the body too when it was edited.
        me.put("notes/:noteId") { request, context -> Note in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("noteId")
            let edit = try await JSONBody.decode(NoteEdit.self, from: request, fields: NoteEdit.fields, limit: limit)
            // The body is held to its rules in the save's transaction, against the note it changes;
            // its refusals are problems already, which `stored` passes on.
            return try await stored {
                Note(try store.updateNote(id, body: edit.body.map { NoteFormatting.edit($0.text, runs: $0.runs) },
                                          projectIds: edit.projectIds, userTagIds: edit.userTagIds,
                                          selectedSummaryIds: edit.selectedSummaryIds, for: user.id, at: now()))
            }
        }
        // The editor's Delete, and All Notes' Delete….
        me.delete("notes/:noteId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("noteId")
            try await stored { try store.deleteNote(id, for: user.id) }
            return Response(status: .noContent)
        }

        // A document's notes are the user's, and may name a document this server does not hold, as
        // tags may: the volume must be in the catalogue, and the document is named, not looked up.
        let documentNotes: RouterPath = "volumes/:volumeId/documents/:documentId/notes"
        me.get(documentNotes) { request, context -> DocumentNotes in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try UserDataRoutes.document(context, resources: resources)
            let notes = try await Blocking.run { try store.notes(of: document, for: user.id) }
            return DocumentNotes(volumeId: document.volumeId, documentId: document.documentId, items: notes.map(NoteSummary.init))
        }
        // A new note's Save: the selection bar's Note, the rail's Add Note, or its Add Note to
        // Highlight, which names the highlight.
        me.post(documentNotes) { request, context -> EditedResponse<Note> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try UserDataRoutes.document(context, resources: resources)
            let new = try await JSONBody.decode(NewNote.self, from: request, fields: NewNote.fields, limit: limit)
            if let highlight = new.linkedHighlightId, TagReferences.normalized(highlight) == nil {
                throw invalidField("linkedHighlightId", "\(highlight) is not a UUID.")
            }
            let body = try NoteFormatting.body(new.bodyText, runs: new.runs, stored: { [] }, isNew: true)
            let response = try await stored {
                Note(try store.createNote(in: document, bodyText: body.text, richText: body.richText, projectIds: new.projectIds,
                                          userTagIds: new.userTagIds, selectedSummaryIds: new.selectedSummaryIds,
                                          linkedHighlightId: new.linkedHighlightId, for: user.id, at: now()))
            }
            let location = context.basePath.prefixing("/api/v1/me/notes/\(response.id)")
            return EditedResponse(status: .created, headers: [.location: location], response: response)
        }
    }

    /// An id as the API answers it: a UUID in uppercase, and anything else as it is stored, so that
    /// a save sends back what the note carries.
    static func wire(_ id: String) -> String { TagReferences.normalized(id) ?? id }

    static func invalidField(_ name: String, _ detail: String) -> APIProblem {
        APIProblem(.badRequest, code: "INVALID_FIELD", detail: "\(name): \(detail)")
    }

    /// Runs a store call off the cooperative pool, its refusals as problems.
    private static func stored<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        do {
            return try await Blocking.run(work)
        } catch let error as NoteStoreError {
            throw problem(error)
        }
    }

    static func problem(_ error: NoteStoreError) -> APIProblem {
        switch error {
        case .noteNotFound(let id):
            APIProblem(.notFound, code: "NOTE_NOT_FOUND", detail: "You have no note with the id \(id).")
        case .notHeld(.userTagIds, let id):
            // As a document's tags refuse one (Tags.swift).
            TagRoutes.problem(.tagNotFound(id))
        case .notHeld(let list, let id):
            invalidField(list.rawValue, "you have no \(list == .projectIds ? "project" : "summary") with the id \(id).")
        case .malformedId(let list, let id):
            invalidField(list.rawValue, "\(id) is not a UUID.")
        }
    }
}
