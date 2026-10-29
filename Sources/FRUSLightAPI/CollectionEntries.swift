// A collection's entries (PLAN's S18d), changed as the app's editors change them, each rule
// CollectionEditing's, over the values the store's rows map to: documents added by Add Documents and
// by the Add to Collection picker; a section heading, a note block or an apparatus block added from
// the editor's Add menu; a frozen excerpt of a selection, the reader's Excerpt, or of highlights, Add
// Highlighted Passages and the inspector's Insert as Excerpt; an entry's text, formatting and
// overrides, and a document's notes and highlights included or not, as the row and the inspector
// write them; a row deleted, a heading alone or with its section; a section indented or outdented; a
// row moved, a heading taking its section; Sort by Date across the collection or within its sections;
// and the inspector's view of a document or a section.

import FRUSCoreKit
import FRUSLightCore
import FRUSRichText
import Foundation
import Hummingbird
import Synchronization

/// A collection after a change that added entries, with the ids of those it added, in order.
public struct CollectionEdit: Codable, Equatable, Sendable, ResponseEncodable {
    public var collection: CollectionDetail
    public var entryIds: [String]
}

/// What the entry inspector shows of a document entry, or of a heading's section defaults.
public struct EntryInspector: Codable, Equatable, Sendable, ResponseEncodable {
    public var entryId: String
    /// `document` or `heading`, the two kinds the inspector opens for.
    public var kind: String
    /// A heading's title, or the kit's `CollectionEditorNaming.untitledSection` for one with none.
    public var sectionTitle: String?
    public var documentId: String
    public var volumeId: String
    /// The index's header, where the server has it.
    public var header: String?
    public var volumeTitle: String?
    /// What the export's heading falls back to with no title override, the override's placeholder:
    /// the history.state.gov citation, else the volume's title and the document's id.
    public var derivedTitle: String?
    /// The document's notes, the last changed first, each with whether the entry includes it.
    public var notes: [NoteChoice]
    /// The document's highlights, the oldest first, each with whether the entry includes it.
    public var highlights: [HighlightChoice]
    /// The names of the tags on the document and on its notes, sorted.
    public var tags: [String]
    /// The summary the inspector shows: one made with the collection's prompt, else the first stored.
    public var summary: ShownSummary?
    /// What each override resolves to at Default, for a document.
    public var resolved: Resolved?
    /// The document's excerpts in this collection, in order.
    public var excerpts: [Excerpt]
    /// The document's archival source note, where the index has one.
    public var sourceNote: String?

    public struct NoteChoice: Codable, Equatable, Sendable {
        public var id: String
        /// Its first 60 characters, trimmed, or the inspector's "Untitled Note".
        public var preview: String
        public var included: Bool
    }

    public struct HighlightChoice: Codable, Equatable, Sendable {
        public var id: String
        public var colorTag: String
        /// Its passage, absent for one that stored none, which cannot be excerpted.
        public var text: String?
        public var included: Bool
    }

    public struct ShownSummary: Codable, Equatable, Sendable {
        public var text: String
        /// Its prompt's name, while the user has the prompt.
        public var promptName: String?
    }

    public struct Resolved: Codable, Equatable, Sendable {
        public var bodyDepth: String
        public var highlights: Bool
        public var notes: Bool
        public var sourceNote: Bool
        public var footnotes: Bool
        public var related: Bool
        public var summaryPromptId: String?
        public var headnote: Bool
    }

    public struct Excerpt: Codable, Equatable, Sendable {
        public var id: String
        public var text: String
    }
}

enum CollectionEntryRoutes {
    struct Documents: Decodable, Sendable {
        let documents: [Key]
    }

    struct Key: Decodable, Sendable {
        let volumeId: String
        let documentId: String
    }

    struct Block: Decodable, Sendable {
        let kind: String?
        let generatedBlockType: String?
    }

    /// A selection's excerpt, or highlights' excerpts.
    struct Excerpts: Decodable, Sendable {
        let volumeId: String?
        let documentId: String?
        let startOffset: Int?
        let endOffset: Int?
        let renderingVersion: String?
        let highlightIds: [String]?
    }

    struct Move: Decodable, Sendable {
        let entryId: String
        /// The entry the moved one goes before; none for the end.
        let before: String?
    }

    struct Sort: Decodable, Sendable { let scope: String }

    struct Inclusion: Decodable, Sendable {
        let id: String
        let included: Bool
    }

    /// A change to one entry, each field absent to leave it, a nullable one null for Default.
    struct Change: Decodable, Sendable {
        var text: String?
        /// A note block's text with its runs, null for a plain edit.
        var prose: (text: String, runs: [RichTextRun]?)?
        var titleOverride: String?
        var bodyDepthOverride: String??
        var applyHighlightsOverride: Bool??
        var includeNotesOverride: Bool??
        var includeSourceNoteOverride: Bool??
        var includeFootnotesOverride: Bool??
        var summaryPromptIdOverride: String??
        var includeRelatedDocuments: Bool??
        var includeHeadnote: Bool??
        var highlight: Inclusion?
        var note: Inclusion?
        var given: Set<String>

        static let fields: Set<String> = [
            "text", "runs", "titleOverride", "bodyDepthOverride", "applyHighlightsOverride", "includeNotesOverride",
            "includeSourceNoteOverride", "includeFootnotesOverride", "summaryPromptIdOverride", "includeRelatedDocuments",
            "includeHeadnote", "highlight", "note",
        ]

        enum CodingKeys: String, CodingKey, CaseIterable {
            case text, runs, titleOverride, bodyDepthOverride, applyHighlightsOverride, includeNotesOverride
            case includeSourceNoteOverride, includeFootnotesOverride, summaryPromptIdOverride, includeRelatedDocuments
            case includeHeadnote, highlight, note
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            given = Set(CodingKeys.allCases.filter { container.contains($0) }.map(\.rawValue))
            func nullable<T: Decodable>(_ key: CodingKeys) throws -> T?? {
                container.contains(key) ? .some(try container.decodeIfPresent(T.self, forKey: key)) : nil
            }
            if container.contains(.runs) {
                guard container.contains(.text) else {
                    throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.runs], debugDescription: "runs come with the text they format."))
                }
                prose = (try container.decode(String.self, forKey: .text), try NoteFormatting.decodeRuns(from: container, forKey: .runs))
            } else {
                text = try container.decodeIfPresent(String.self, forKey: .text)
            }
            titleOverride = try container.decodeIfPresent(String.self, forKey: .titleOverride)
            bodyDepthOverride = try nullable(.bodyDepthOverride)
            applyHighlightsOverride = try nullable(.applyHighlightsOverride)
            includeNotesOverride = try nullable(.includeNotesOverride)
            includeSourceNoteOverride = try nullable(.includeSourceNoteOverride)
            includeFootnotesOverride = try nullable(.includeFootnotesOverride)
            summaryPromptIdOverride = try nullable(.summaryPromptIdOverride)
            includeRelatedDocuments = try nullable(.includeRelatedDocuments)
            includeHeadnote = try nullable(.includeHeadnote)
            highlight = try container.decodeIfPresent(Inclusion.self, forKey: .highlight)
            note = try container.decodeIfPresent(Inclusion.self, forKey: .note)
        }
    }

    /// The fields each kind of entry takes: a section's title and its defaults; a note block's text;
    /// a document's title override, overrides, headnote and selections. An excerpt's passage is
    /// frozen (decision A9), and an apparatus block or an entry a newer build wrote has nothing to edit.
    static func editable(_ kind: CollectionEntryKind) -> Set<String> {
        let overrides: Set<String> = ["bodyDepthOverride", "applyHighlightsOverride", "includeNotesOverride",
                                      "includeSourceNoteOverride", "includeFootnotesOverride", "summaryPromptIdOverride",
                                      "includeRelatedDocuments"]
        switch kind {
        case .heading: return overrides.union(["text"])
        case .prose: return ["text", "runs"]
        case .document: return overrides.union(["titleOverride", "includeHeadnote", "highlight", "note"])
        case .excerpt, .generated, .unrecognized: return []
        }
    }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    reader: ReaderService, provider: ServedIndexProvider) {
        let store = services.store
        let now = services.now

        /// The collection as the editor shows it.
        @Sendable func detail(_ rows: CollectionRows, _ user: String) async throws -> CollectionDetail {
            try await CollectionRoutes.detail(CollectionRoutes.values(rows), for: user, in: store, resources: resources, provider: provider)
        }

        /// The ids of the entries `after` holds that `before` did not, in its order.
        @Sendable func added(_ rows: CollectionRows, since before: CollectionExport) throws -> [String] {
            let held = Set(before.entries.map(\.id))
            return try CollectionRoutes.values(rows).entries.filter { !held.contains($0.id) }.map(\.id.uuidString)
        }

        // Add Documents' add, `CollectionDocumentDiscovery.appendEntries`: at the end, in the order
        // chosen, a document the collection holds added again.
        me.post("collections/:collectionId/documents") { request, context -> CollectionEdit in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let body = try await JSONBody.decode(Documents.self, from: request, fields: ["documents"],
                                                 limit: UserDataServices.noteBodyLimit)
            let documents = try keys(body.documents, resources: resources)
            let before = try await CollectionRoutes.collection(id, of: user.id, in: store)
            let time = UserStoreDate.rounded(now())
            let rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: time) { collection in
                guard CollectionEditing.appendEntries(documents, to: &collection, at: time) else { throw CollectionRoutes.smart() }
            }
            return CollectionEdit(collection: try await detail(rows, user.id), entryIds: try added(rows, since: before))
        }
        // The Add to Collection picker's add of one document: nothing again for one it holds.
        me.post("collections/:collectionId/document") { request, context -> CollectionAddResult in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let body = try await JSONBody.decode(Key.self, from: request, fields: ["volumeId", "documentId"])
            guard let document = try keys([body], resources: resources).first else { throw CollectionRoutes.notFound(id) }
            let time = UserStoreDate.rounded(now())
            let took = Mutex(false)
            let rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: time) { collection in
                guard CollectionEditing.takesHandAddedEntries(collection) else { throw CollectionRoutes.smart() }
                let added = CollectionEditing.appendToCollection(document, to: &collection, at: time)
                took.withLock { $0 = added }
            }
            return CollectionAddResult(added: took.withLock { $0 }, collection: CollectionListItem(try CollectionRoutes.values(rows)))
        }
        // The Add menu's Add Section Heading and Add Note Block, `appendBlock(kind:)`, and its Apparatus
        // items, `addGeneratedEntry(type:)`, which a smart collection takes too.
        me.post("collections/:collectionId/blocks") { request, context -> CollectionEdit in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let body = try await JSONBody.decode(Block.self, from: request, fields: ["kind", "generatedBlockType"])
            let before = try await CollectionRoutes.collection(id, of: user.id, in: store)
            let time = UserStoreDate.rounded(now())
            let rows: CollectionRows
            switch (body.kind, body.generatedBlockType) {
            case (let kind?, nil):
                guard let block = CollectionEntryKind(rawValue: kind), [.heading, .prose].contains(block) else {
                    throw CollectionRoutes.invalidField("kind", "\(kind) is no block the Add menu adds: heading or prose.")
                }
                rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: time) { collection in
                    guard CollectionEditing.appendBlock(block, to: &collection, at: time) != nil else { throw CollectionRoutes.smart() }
                }
            case (nil, let raw?):
                guard let type = CollectionGeneratedBlockType(rawValue: raw) else {
                    let names = CollectionGeneratedBlockType.allCases.map(\.rawValue)
                    throw CollectionRoutes.invalidField("generatedBlockType", "\(raw) is no apparatus block: \(names.joined(separator: ", ")).")
                }
                rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: time) { collection in
                    CollectionEditing.addGeneratedEntry(type, to: &collection, at: time)
                }
            default:
                throw CollectionRoutes.invalidField("kind", "a block is a kind, heading or prose, or a generatedBlockType, and not both.")
            }
            return CollectionEdit(collection: try await detail(rows, user.id), entryIds: try added(rows, since: before))
        }
        // Excerpts: of the reader's selection, frozen from the page's own model as the app's
        // `selectionExcerptCapture` freezes one, with its offsets and version; or of highlights, as
        // `CollectionExcerpts.capture(from:)` takes one, in the order given. A smart collection takes none.
        me.post("collections/:collectionId/excerpts") { request, context -> CollectionEdit in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let body = try await JSONBody.decode(Excerpts.self, from: request,
                                                 fields: ["volumeId", "documentId", "startOffset", "endOffset", "renderingVersion",
                                                          "highlightIds"])
            let captures: [CollectionEditing.ExcerptCapture]
            if let ids = body.highlightIds {
                guard body.volumeId == nil, body.documentId == nil, body.startOffset == nil, body.endOffset == nil,
                      body.renderingVersion == nil else {
                    throw CollectionRoutes.invalidField("highlightIds", "highlights' excerpts take no selection.")
                }
                let highlights = try await Blocking.run { try store.highlights(for: user.id) }
                captures = try ids.map { raw in
                    guard let highlight = highlights.first(where: { UserSearchText.uuidString($0.id) == UserSearchText.uuidString(raw) }) else {
                        throw APIProblem(.notFound, code: "HIGHLIGHT_NOT_FOUND", detail: "You have no highlight with the id \(raw).")
                    }
                    guard let capture = CollectionEditing.capture(from: exported(highlight)) else {
                        throw APIProblem(.conflict, code: "HIGHLIGHT_HAS_NO_PASSAGE",
                                         detail: "No stored passage text — open the document and re-create this highlight to excerpt it.")
                    }
                    return capture
                }
            } else {
                guard let volumeId = body.volumeId, let documentId = body.documentId, let start = body.startOffset,
                      let end = body.endOffset, let version = body.renderingVersion else {
                    throw CollectionRoutes.invalidField("body", "a selection's excerpt names its volumeId, documentId, startOffset, endOffset and renderingVersion.")
                }
                captures = [try await selectionCapture(volumeId: volumeId, documentId: documentId, start: start, end: end,
                                                       version: version, resources: resources, reader: reader, provider: provider)]
            }
            let before = try await CollectionRoutes.collection(id, of: user.id, in: store)
            let time = UserStoreDate.rounded(now())
            let rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: time) { collection in
                guard CollectionEditing.appendExcerpts(captures, to: &collection, at: time) else { throw CollectionRoutes.smart() }
            }
            return CollectionEdit(collection: try await detail(rows, user.id), entryIds: try added(rows, since: before))
        }
        // A row moved, a heading with its section, through the kit's move: before the entry named, or to
        // the end. One the kit refuses, into its own section or onto itself, changes nothing, as the
        // editor's drop does.
        me.post("collections/:collectionId/move") { request, context -> CollectionDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let body = try await JSONBody.decode(Move.self, from: request, fields: ["entryId", "before"])
            let time = UserStoreDate.rounded(now())
            let rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: time) { collection in
                let from = try index(of: body.entryId, in: collection)
                let to = try body.before.map { try index(of: $0, in: collection) } ?? collection.entries.count
                CollectionEditing.move(from: from, to: to, in: &collection)
            }
            return try await detail(rows, user.id)
        }
        // Sort by Date, `CollectionEntryData.sortedByDate`: each document by its day in the index, else
        // its volume's first, across the collection or within each section.
        me.post("collections/:collectionId/sort") { request, context -> CollectionDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let body = try await JSONBody.decode(Sort.self, from: request, fields: ["scope"])
            guard let scope = CollectionEditing.DateSortScope(rawValue: body.scope) else {
                throw CollectionRoutes.invalidField("scope", "\(body.scope) is no scope: wholeCollection or withinSections.")
            }
            let held = try await CollectionRoutes.collection(id, of: user.id, in: store)
            let keys = held.entries.map { DocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
            let facts = await CollectionRoutes.documentFacts(keys, provider: provider)
            let dates = facts.compactMapValues(\.dateISO)
            let manifest = resources.manifest
            let time = UserStoreDate.rounded(now())
            let rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: time) { collection in
                CollectionEditing.sortByDate(scope, in: &collection, documentDates: dates, manifest: manifest)
            }
            return try await detail(rows, user.id)
        }
        // A row's edit and the inspector's: each field its kind takes, as the row's and the inspector's
        // bindings write them.
        me.patch("collections/:collectionId/entries/:entryId") { request, context -> CollectionDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let entryId = try context.parameters.require("entryId")
            let body = try await JSONBody.decode(Change.self, from: request, fields: Change.fields, limit: UserDataServices.noteBodyLimit)
            let held = try await CollectionRoutes.collection(id, of: user.id, in: store)
            let entry = held.entries[try index(of: entryId, in: held)]
            let kind = entry.entryKind
            if let field = body.given.sorted().first(where: { !editable(kind).contains($0) }) {
                throw CollectionRoutes.invalidField(field, "a \(kind.rawValue) entry does not take it.")
            }
            if kind == .prose, body.given.contains("text"), body.prose == nil {
                throw CollectionRoutes.invalidField("runs", "required with a note block's text: its runs, or null for a plain one.")
            }
            let prompts = body.summaryPromptIdOverride != nil ? try await CollectionRoutes.promptIds(of: user.id, in: store) : []
            let document = DocumentKey(volumeId: entry.volumeId, documentId: entry.documentId)
            let highlightIds = body.highlight != nil
                ? try await documentHighlights(document, of: user.id, in: store).compactMap { UUID(uuidString: $0.id) } : []
            let noteIds = body.note != nil
                ? try await documentNotes(document, of: user.id, in: store).compactMap { UUID(uuidString: $0.id) } : []
            let time = UserStoreDate.rounded(now())
            let rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: time) { collection in
                let at = try index(of: entryId, in: collection)
                var edited = collection.entries[at]
                if let text = body.text { edited.text = text }
                if let prose = body.prose {
                    let held = edited.richText.map { [UInt8]($0) }
                    let made = try NoteFormatting.body(prose.text, runs: prose.runs, stored: { NoteFormatting.links(of: held) }, isNew: false)
                    edited.text = made.text
                    edited.richText = made.richText.map { Data($0) }
                }
                // The inspector's binding: an emptied field is none.
                if let title = body.titleOverride { edited.titleOverride = title.isEmpty ? nil : title }
                if let depth = body.bodyDepthOverride {
                    if let depth, CollectionBodyDepth(rawValue: depth) == nil {
                        throw CollectionRoutes.invalidField("bodyDepthOverride", "\(depth) is no body depth: full, summaryOnly or index.")
                    }
                    edited.bodyDepthOverride = depth
                }
                if let value = body.applyHighlightsOverride { edited.applyHighlightsOverride = value }
                if let value = body.includeNotesOverride { edited.includeNotesOverride = value }
                if let value = body.includeSourceNoteOverride { edited.includeSourceNoteOverride = value }
                if let value = body.includeFootnotesOverride { edited.includeFootnotesOverride = value }
                if let value = body.includeRelatedDocuments { edited.includeRelatedDocuments = value }
                if let value = body.includeHeadnote { edited.includeHeadnote = value }
                if let prompt = body.summaryPromptIdOverride {
                    edited.summaryPromptIdOverride = try CollectionRoutes.promptId(prompt, among: prompts, field: "summaryPromptIdOverride")
                }
                if let highlight = body.highlight {
                    guard let id = UUID(uuidString: highlight.id), highlightIds.contains(id) else {
                        throw CollectionRoutes.invalidField("highlight", "the document has no highlight of yours with the id \(highlight.id).")
                    }
                    CollectionEditing.setHighlightIncluded(id, highlight.included, all: highlightIds, in: &edited)
                }
                if let note = body.note {
                    guard let id = UUID(uuidString: note.id), noteIds.contains(id) else {
                        throw CollectionRoutes.invalidField("note", "the document has no note of yours with the id \(note.id).")
                    }
                    CollectionEditing.setNoteIncluded(id, note.included, all: noteIds, in: &edited)
                }
                collection.entries[at] = edited
            }
            return try await detail(rows, user.id)
        }
        // A row's delete: the one entry, a heading alone, its contents left. An entry a newer build wrote
        // offers nothing to do (`UnrecognizedEntryRow`).
        me.delete("collections/:collectionId/entries/:entryId") { request, context -> CollectionDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let entryId = try context.parameters.require("entryId")
            let rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: UserStoreDate.rounded(now())) { collection in
                let at = try index(of: entryId, in: collection)
                guard collection.entries[at].entryKind != .unrecognized else { throw unsupported() }
                CollectionEditing.deleteEntry(at: at, in: &collection)
            }
            return try await detail(rows, user.id)
        }
        // A heading's Delete Section, once the reader has said so.
        me.post("collections/:collectionId/entries/:entryId/delete-section") { request, context -> CollectionDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let entryId = try context.parameters.require("entryId")
            let rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: UserStoreDate.rounded(now())) { collection in
                let at = try index(of: entryId, in: collection)
                guard collection.entries[at].entryKind == .heading else { throw notAHeading(entryId) }
                CollectionEditing.deleteSection(at: at, in: &collection)
            }
            return try await detail(rows, user.id)
        }
        // A heading's Indent and Outdent, refused where the menu would not offer them.
        for (path, indent) in [("indent", true), ("outdent", false)] {
            me.post("collections/:collectionId/entries/:entryId/\(path)") { request, context -> CollectionDetail in
                try FormQuery(request.uri.query).refuseUnknown([])
                let user = try context.requireUser()
                let id = try context.parameters.require("collectionId")
                let entryId = try context.parameters.require("entryId")
                let rows = try await CollectionRoutes.changed(id, for: user.id, in: store, at: UserStoreDate.rounded(now())) { collection in
                    let at = try index(of: entryId, in: collection)
                    guard collection.entries[at].entryKind == .heading else { throw notAHeading(entryId) }
                    if indent {
                        guard CollectionEditing.canIndent(at, in: collection.entries) else {
                            throw APIProblem(.conflict, code: "OUTLINE_REFUSED",
                                             detail: "This heading cannot indent: a section nests at most \(CollectionOutline.maxLevel) deep, one level below the heading before it.")
                        }
                        CollectionEditing.indentSection(at: at, in: &collection.entries)
                    } else {
                        guard CollectionEditing.canOutdent(at, in: collection.entries) else {
                            throw APIProblem(.conflict, code: "OUTLINE_REFUSED", detail: "This heading is at the outline's first level already.")
                        }
                        CollectionEditing.outdentSection(at: at, in: &collection.entries)
                    }
                }
                return try await detail(rows, user.id)
            }
        }
        me.get("collections/:collectionId/entries/:entryId/inspector") { request, context -> EntryInspector in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let entryId = try context.parameters.require("entryId")
            let collection = try await CollectionRoutes.collection(id, of: user.id, in: store)
            return try await inspector(of: try index(of: entryId, in: collection), in: collection, for: user.id, in: store,
                                       resources: resources, provider: provider)
        }
    }

    // MARK: - The inspector

    /// The inspector's `load()`: for a heading, its section's title; for a document, its identity, the
    /// citation the title override stands in for, its notes and highlights with what the entry
    /// includes, the tags, the summary shown, what each override resolves to, its excerpts here and
    /// its source note.
    static func inspector(of index: Int, in collection: CollectionExport, for user: String, in store: any UserDataStore,
                          resources: ServerResources, provider: ServedIndexProvider) async throws -> EntryInspector {
        let entry = collection.entries[index]
        switch entry.entryKind {
        case .heading:
            let text = entry.text ?? ""
            return EntryInspector(entryId: entry.id.uuidString, kind: CollectionEntryKind.heading.rawValue,
                                  sectionTitle: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      ? CollectionEditorNaming.untitledSection : text,
                                  documentId: entry.documentId, volumeId: entry.volumeId, notes: [], highlights: [], tags: [],
                                  excerpts: [])
        case .document:
            break
        default:
            throw APIProblem(.conflict, code: "NOT_INSPECTABLE", detail: "The inspector opens for a document or a section heading.")
        }
        let document = DocumentKey(volumeId: entry.volumeId, documentId: entry.documentId)
        let notes = try await documentNotes(document, of: user, in: store)
        let highlights = try await documentHighlights(document, of: user, in: store)
        let (summaries, prompts, assigned, tags) = try await Blocking.run {
            (try store.summaries(of: document, for: user), try store.prompts(for: user),
             try store.tags(of: document, for: user), try store.tags(of: user))
        }
        // The names of the tags on the document and on its notes (`ZoteroJSONExporter.fetchTagsAndNotes`).
        let names = Dictionary(tags.map { (UserSearchText.uuidString($0.id), $0.name) }, uniquingKeysWith: { first, _ in first })
        var tagNames = Set(assigned.map(\.name))
        for note in notes {
            for id in note.userTagIds { if let name = names[UserSearchText.uuidString(id)] { tagNames.insert(name) } }
        }
        // The summary shown: one with the collection's prompt, else the first; no draft and none empty.
        let shown = summaries.filter { !$0.responseText.isEmpty && !$0.isHeadnoteDraft }
        let collectionPrompt = collection.summaryPromptId?.uuidString
        let summary = collectionPrompt.flatMap { prompt in shown.first { UserSearchText.uuidString($0.promptId) == prompt } } ?? shown.first
        let facts = await CollectionRoutes.documentFacts([document], provider: provider)["\(document.volumeId)/\(document.documentId)"]
        let volume = resources.volume(entry.volumeId)
        let resolved = CollectionEditing.resolvedDefaults(of: index, in: collection)
        return EntryInspector(
            entryId: entry.id.uuidString, kind: CollectionEntryKind.document.rawValue, sectionTitle: nil,
            documentId: entry.documentId, volumeId: entry.volumeId, header: facts?.header, volumeTitle: volume?.title,
            derivedTitle: derivedTitle(entry, volume: volume, printed: facts?.documentNumber),
            notes: notes.compactMap { note in
                guard let id = UUID(uuidString: note.id) else { return nil }
                return .init(id: id.uuidString, preview: notePreview(note.bodyText),
                             included: CollectionEditing.noteIncluded(id, in: entry))
            },
            highlights: highlights.compactMap { highlight in
                guard let id = UUID(uuidString: highlight.id) else { return nil }
                return .init(id: id.uuidString, colorTag: highlight.colorTag,
                             text: highlight.selectedText.isEmpty ? nil : highlight.selectedText,
                             included: CollectionEditing.highlightIncluded(id, in: entry))
            },
            tags: tagNames.sorted(),
            summary: summary.map { .init(text: $0.responseText, promptName: prompts[UserSearchText.uuidString($0.promptId)]) },
            resolved: resolved.map {
                .init(bodyDepth: $0.bodyDepth.rawValue, highlights: $0.highlights, notes: $0.notes, sourceNote: $0.sourceNote,
                      footnotes: $0.footnotes, related: $0.related, summaryPromptId: $0.summaryPromptId?.uuidString, headnote: $0.headnote)
            },
            excerpts: collection.entries.filter {
                $0.entryKind == .excerpt && $0.volumeId == entry.volumeId && $0.documentId == entry.documentId
            }.map { .init(id: $0.id.uuidString, text: $0.text ?? "") },
            sourceNote: facts?.sourceNote)
    }

    /// The inspector's `derivedTitlePlaceholder`: the citation `exportCitation` builds from the
    /// manifest's volume and the printed number, else the volume's title and the document's id.
    static func derivedTitle(_ entry: CollectionEntryExport, volume: VolumeManifestEntry?, printed: String?) -> String {
        if let volume {
            let metadata = FRUSDocumentMetadata(
                documentId: entry.documentId,
                documentNumber: CitableDocumentNumber.resolve(printed: printed, documentId: entry.documentId),
                header: "", dateline: nil)
            let citation = HistoryAtStateCitationFormatter().format(document: metadata, volume: FRUSVolumeMetadata(volume))
            if !citation.isEmpty { return citation }
        }
        return "\(volume?.title ?? entry.volumeId) — \(entry.documentId)"
    }

    /// A note's row in the inspector: its first 60 characters, trimmed, or "Untitled Note".
    static func notePreview(_ text: String) -> String {
        let trimmed = text.prefix(60).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Note" : String(trimmed)
    }

    /// A document's notes, the last changed first, as the inspector lists them.
    static func documentNotes(_ document: DocumentKey, of user: String, in store: any UserDataStore) async throws -> [NoteRecord] {
        let notes = try await Blocking.run { try store.notes(of: document, for: user) }
        return notes.enumerated().sorted { a, b in
            let (x, y) = (a.element.lastModified ?? .distantPast, b.element.lastModified ?? .distantPast)
            return x != y ? x > y : a.offset < b.offset
        }.map(\.element)
    }

    /// A document's highlights, the oldest first, as the inspector lists them.
    static func documentHighlights(_ document: DocumentKey, of user: String,
                                   in store: any UserDataStore) async throws -> [HighlightRecord] {
        let highlights = try await Blocking.run { try store.highlights(of: document, for: user) }
        return highlights.enumerated().sorted { a, b in
            let (x, y) = (a.element.createdAt ?? .distantPast, b.element.createdAt ?? .distantPast)
            return x != y ? x < y : a.offset < b.offset
        }.map(\.element)
    }

    // MARK: - Helpers

    /// The documents a request names, each a manifest volume's and a document's id, at most the app's
    /// bulk limit (`CollectionDocumentDiscovery.bulkDocumentLimit`) at a time.
    static func keys(_ given: [Key], resources: ServerResources) throws -> [DocumentKey] {
        let limit = 1_000
        guard given.count <= limit else {
            throw CollectionRoutes.invalidField("documents", "A collection takes up to \(limit) documents at a time, and \(given.count) were chosen.")
        }
        return try given.map { key in
            guard resources.volume(key.volumeId) != nil else { throw APIProblem.volumeNotFound(key.volumeId) }
            guard key.documentId.utf8.count <= 256, FRUSURLScheme.isSafeComponent(key.documentId) else {
                throw APIProblem.invalidParameter("documentId", "\(key.documentId) is not a document's id.")
            }
            return DocumentKey(volumeId: key.volumeId, documentId: key.documentId)
        }
    }

    /// The selection's excerpt: the passage the page's own model holds between its offsets, block-aware
    /// (`flatTextExcerpt`), with the offsets and the page's rendering version, refused as a highlight's
    /// selection is when the text has changed since the page was loaded.
    static func selectionCapture(volumeId: String, documentId: String, start: Int, end: Int, version: String,
                                 resources: ServerResources, reader: ReaderService,
                                 provider: ServedIndexProvider) async throws -> CollectionEditing.ExcerptCapture {
        let document = try keys([Key(volumeId: volumeId, documentId: documentId)], resources: resources)[0]
        guard start >= 0 else { throw CollectionRoutes.invalidField("startOffset", "must be 0 or more, not \(start).") }
        guard end > start else { throw CollectionRoutes.invalidField("endOffset", "must be after startOffset, \(start), not \(end).") }
        let page = try await HighlightRoutes.page(of: document, reader: reader, provider: provider, resources: resources)
        guard version == page.renderingVersion else {
            throw APIProblem(.conflict, code: "DOCUMENT_CHANGED",
                             detail: "renderingVersion: the document's text has changed since the page was loaded, from \(version) to \(page.renderingVersion). Load it again and select once more.")
        }
        guard end <= page.length else {
            throw CollectionRoutes.invalidField("endOffset", "the document's text has \(page.length) characters, so an excerpt ends at \(page.length) at most, not \(end).")
        }
        guard let text = flatTextExcerpt(from: page.model, start: start, end: end), !text.isEmpty else {
            throw CollectionRoutes.invalidField("endOffset", "the selection holds no text to excerpt.")
        }
        return CollectionEditing.ExcerptCapture(text: text, volumeId: volumeId, documentId: documentId, start: start, end: end,
                                                renderingVersion: page.renderingVersion, colorTag: nil)
    }

    /// A stored highlight as the export's record of it.
    static func exported(_ highlight: HighlightRecord) -> DocumentHighlightExport {
        DocumentHighlightExport(id: UUID(uuidString: highlight.id) ?? UUID(), volumeId: highlight.volumeId,
                                documentId: highlight.documentId, startOffset: highlight.startOffset, endOffset: highlight.endOffset,
                                colorTag: highlight.colorTag, noteId: highlight.noteId.flatMap(UUID.init(uuidString:)),
                                selectedText: highlight.selectedText, renderingVersion: highlight.renderingVersion,
                                createdAt: highlight.createdAt)
    }

    /// An entry's place in the collection's order, found by its id in any letter case.
    static func index(of entryId: String, in collection: CollectionExport) throws -> Int {
        let key = UserSearchText.uuidString(entryId)
        guard let index = collection.entries.firstIndex(where: { $0.id.uuidString == key }) else {
            throw APIProblem(.notFound, code: "ENTRY_NOT_FOUND", detail: "The collection has no entry with the id \(entryId).")
        }
        return index
    }

    static func notAHeading(_ entryId: String) -> APIProblem {
        APIProblem(.conflict, code: "NOT_A_HEADING", detail: "The entry \(entryId) is not a section heading.")
    }

    /// `UnrecognizedEntryRow`'s line: an entry a newer build wrote, which this one neither edits nor deletes.
    static func unsupported() -> APIProblem {
        APIProblem(.conflict, code: "ENTRY_NOT_SUPPORTED", detail: "Update FRUS Explorer to view this entry.")
    }
}
