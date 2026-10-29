// /api/v1/me/collections (PLAN's S18d): the user's collections and their editor. A collection is the
// research data export's record of it, `CollectionExport`, its rows written as the import writes a
// Mac's (`MacImport.collection`, `.entry`) and read as the export reads one (`ResearchExport`), so a
// collection made here travels in the JSON export as the Mac's does. Listed as the Collections tab
// lists them, the most recently changed first; made as the Mac's New Collection sheet makes one, named
// and in the project the user works in; read with its entries in their order, each with what the
// editor's row shows and the outline the kit derives (`CollectionOutline`); changed field by field as
// the editor commits each (`CollectionEditorCommit`); deleted with its entries and their headnote
// drafts; duplicated as `Collection.duplicate(in:)`; given a preset; and listed in the Research
// rail's Collections section for a document it holds. The entries' routes are CollectionEntries.swift.

import FRUSCoreKit
import FRUSLightCore
import FRUSRichText
import Foundation
import Hummingbird

/// A collection in the Collections list, and in the Add to Collection picker.
public struct CollectionListItem: Codable, Equatable, Sendable {
    public var id: String
    /// As it was saved.
    public var name: String
    /// What a row prints for it, the kit's `CollectionEditorNaming.listName(savedName:)`: the name
    /// trimmed, or "Untitled Collection".
    public var listName: String
    /// Its `.document` entries, `Collection.documentCount`.
    public var documentCount: Int
    /// Whether it is linked to a saved search, a smart collection, whose row says so where an
    /// ordinary one counts its documents.
    public var isSmart: Bool
    public var projectIds: [String]
    public var createdAt: String?
    public var lastModified: String?

    init(_ collection: CollectionExport) {
        id = collection.id.uuidString
        name = collection.name
        listName = CollectionEditorNaming.listName(savedName: collection.name)
        documentCount = CollectionEditing.documentCount(collection.entries)
        isSmart = collection.savedSearchId != nil
        projectIds = collection.projectIds.map(\.uuidString)
        createdAt = collection.createdAt.map(UserStoreDate.text)
        lastModified = collection.lastModified.map(UserStoreDate.text)
    }
}

/// The user's collections, the most recently changed first.
public struct CollectionList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [CollectionListItem]
}

/// One collection, as its editor shows it.
public struct CollectionDetail: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var name: String
    public var listName: String
    public var note: String?
    public var subtitle: String?
    public var authorLine: String?
    /// The introduction's plain text, and its formatting as the codec reads its RTF, null for none;
    /// `introductionFormattingKept` when the RTF holds what runs cannot carry, kept until it is edited.
    public var introductionText: String?
    public var introductionRuns: [RichTextRun]?
    public var introductionFormattingKept: Bool
    public var includeColophon: Bool
    public var includeProjectProvenance: Bool
    public var includeMethodAppendix: Bool
    public var projectIds: [String]
    public var savedSearchId: String?
    /// The linked saved search's name, which Collection settings' Smart Collection rows show; absent for
    /// none, or for a link to a search the user no longer has, "Saved search not found".
    public var savedSearchName: String?
    /// Whether it takes documents, headings, note blocks and passages by hand: not a smart one.
    public var takesHandAddedEntries: Bool
    /// The composition: a `CollectionBodyDepth`, the effective footnote flags, a `CollectionToCStyle`.
    public var defaultBodyDepth: String
    public var includeFootnotes: Bool
    public var includeSourceNote: Bool
    public var tocStyle: String
    public var applyHighlights: Bool
    public var includeNotes: Bool
    public var includeWordCloud: Bool
    public var defaultIncludeHeadnote: Bool
    public var summaryPromptId: String?
    /// Whether summaries can be had for it: whether one of its documents has a summary stored, since
    /// the server writes none. Summary only, and Briefing packet, are offered only then.
    public var summariesAvailable: Bool
    /// The body depths a picker offers, `CollectionBodyDepth.available(summariesAvailable:)`.
    public var bodyDepths: [String]
    /// The presets offered, in the kit's order, each with whether it is the collection's composition
    /// (`CollectionPreset.matches`).
    public var presets: [Preset]
    /// The user's summary prompts, which the Summary prompt pickers offer, by name.
    public var prompts: [Prompt]
    public var documentCount: Int
    /// The volumes of its documents the server cannot open, sorted: those its folder of volumes
    /// lacks, or outside the catalogue, whose documents the preview prints as citations, as the app's
    /// prints those of a volume not downloaded (PLAN's S18e); none for a smart collection.
    public var volumesNotHeld: [String]
    public var entries: [Entry]
    public var createdAt: String?
    public var lastModified: String?

    public struct Preset: Codable, Equatable, Sendable {
        /// A `CollectionPreset` raw value.
        public var id: String
        public var active: Bool
    }

    public struct Prompt: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
    }

    /// One entry, as it is stored, with what its row shows and the outline's facts for it.
    public struct Entry: Codable, Equatable, Sendable {
        public var id: String
        /// The kit's reading of its kind (`CollectionEntryExport.entryKind`): `unrecognized` for one a
        /// newer build wrote.
        public var kind: String
        public var sortOrder: Int
        /// As stored; `depth` is the outline's, `CollectionOutline.resolvedDepths`.
        public var level: Int
        public var depth: Int
        public var documentId: String
        public var volumeId: String
        public var text: String?
        /// A note block's formatting, as the codec reads its RTF; null for none or for RTF it cannot
        /// read as the text, which `formattingKept` says is kept until the block is edited.
        public var runs: [RichTextRun]?
        public var formattingKept: Bool
        public var titleOverride: String?
        public var bodyDepthOverride: String?
        public var applyHighlightsOverride: Bool?
        public var includeNotesOverride: Bool?
        public var includeSourceNoteOverride: Bool?
        public var includeFootnotesOverride: Bool?
        public var summaryPromptIdOverride: String?
        public var includeRelatedDocuments: Bool?
        public var includeHeadnote: Bool?
        public var headnoteSummaryId: String?
        public var researchNoteId: String?
        public var selectedNoteIds: [String]
        public var selectedHighlightIds: [String]
        public var excerptStart: Int?
        public var excerptEnd: Int?
        public var excerptRenderingVersion: String?
        public var excerptColorTag: String?
        public var generatedBlockType: String?
        /// A heading's section, the kit's `sectionRange`: the position after its last entry.
        public var sectionEnd: Int?
        public var canIndent: Bool
        public var canOutdent: Bool
        /// Whether a smart collection leaves it out (`SmartCollectionRule.leavesOut`).
        public var leftOut: Bool
        /// Whether another document entry holds its document, "Also in collection".
        public var isDuplicate: Bool
        /// For a document or an excerpt: the index's header, the volume's title and the document's
        /// day, where the server has them.
        public var header: String?
        public var volumeTitle: String?
        public var dateISO: String?
        /// For a document: how many notes its document has, which its row's chip counts by.
        public var noteCount: Int?
    }
}

/// What the Add to Collection picker's add did: whether the collection took the document, or held it
/// already, and the collection as it then stands.
public struct CollectionAddResult: Codable, Equatable, Sendable, ResponseEncodable {
    public var added: Bool
    public var collection: CollectionListItem
}

/// The collections that hold a document, as the Research rail's Collections section lists them.
public struct DocumentCollections: Codable, Equatable, Sendable, ResponseEncodable {
    public var volumeId: String
    public var documentId: String
    public var items: [Membership]

    public struct Membership: Codable, Equatable, Sendable {
        public var id: String
        public var listName: String
    }
}

enum CollectionRoutes {
    struct NewCollection: Decodable { let name: String }

    struct Duplicate: Decodable {}

    struct PresetChoice: Decodable { let preset: String }

    /// A change to a collection's own fields, each absent to leave it: a note, subtitle or author line
    /// null or empty to clear it, a summary prompt null for none, and any other field refused as null.
    struct Change: Decodable, Sendable {
        var name: String?
        var note: String?
        var subtitle: String?
        var authorLine: String?
        /// The introduction's text with its runs, null for a plain edit; text alone is refused.
        var introduction: (text: String, runs: [RichTextRun]?)?
        var includeColophon: Bool?
        var includeProjectProvenance: Bool?
        var includeMethodAppendix: Bool?
        var defaultBodyDepth: String?
        var includeFootnotes: Bool?
        var includeSourceNote: Bool?
        var tocStyle: String?
        var applyHighlights: Bool?
        var includeNotes: Bool?
        var includeWordCloud: Bool?
        var defaultIncludeHeadnote: Bool?
        var summaryPromptId: String??
        /// Link to Saved Search…'s pick, or null for Unlink (PLAN's S18f).
        var savedSearchId: String??

        static let fields: Set<String> = [
            "name", "note", "subtitle", "authorLine", "introductionText", "introductionRuns", "includeColophon",
            "includeProjectProvenance", "includeMethodAppendix", "defaultBodyDepth", "includeFootnotes", "includeSourceNote",
            "tocStyle", "applyHighlights", "includeNotes", "includeWordCloud", "defaultIncludeHeadnote", "summaryPromptId",
            "savedSearchId",
        ]

        enum CodingKeys: String, CodingKey {
            case name, note, subtitle, authorLine, introductionText, introductionRuns, includeColophon, includeProjectProvenance
            case includeMethodAppendix, defaultBodyDepth, includeFootnotes, includeSourceNote, tocStyle, applyHighlights
            case includeNotes, includeWordCloud, defaultIncludeHeadnote, summaryPromptId, savedSearchId
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            /// A field the change names, which may not be null.
            func given<T: Decodable>(_ key: CodingKeys) throws -> T? {
                container.contains(key) ? try container.decode(T.self, forKey: key) : nil
            }
            /// A text null clears, as an empty one does.
            func clearable(_ key: CodingKeys) throws -> String? {
                container.contains(key) ? (try container.decodeIfPresent(String.self, forKey: key) ?? "") : nil
            }
            name = try given(.name)
            note = try clearable(.note)
            subtitle = try clearable(.subtitle)
            authorLine = try clearable(.authorLine)
            switch (container.contains(.introductionText), container.contains(.introductionRuns)) {
            case (true, true):
                introduction = (try container.decode(String.self, forKey: .introductionText),
                                try NoteFormatting.decodeRuns(from: container, forKey: .introductionRuns))
            case (true, false):
                throw DecodingError.keyNotFound(CodingKeys.introductionRuns, .init(
                    codingPath: [], debugDescription: "required with introductionText: its runs, or null for a plain one"))
            case (false, true):
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [CodingKeys.introductionRuns], debugDescription: "runs come with the introductionText they format."))
            case (false, false):
                introduction = nil
            }
            includeColophon = try given(.includeColophon)
            includeProjectProvenance = try given(.includeProjectProvenance)
            includeMethodAppendix = try given(.includeMethodAppendix)
            defaultBodyDepth = try given(.defaultBodyDepth)
            includeFootnotes = try given(.includeFootnotes)
            includeSourceNote = try given(.includeSourceNote)
            tocStyle = try given(.tocStyle)
            applyHighlights = try given(.applyHighlights)
            includeNotes = try given(.includeNotes)
            includeWordCloud = try given(.includeWordCloud)
            defaultIncludeHeadnote = try given(.defaultIncludeHeadnote)
            summaryPromptId = container.contains(.summaryPromptId)
                ? .some(try container.decodeIfPresent(String.self, forKey: .summaryPromptId)) : nil
            savedSearchId = container.contains(.savedSearchId)
                ? .some(try container.decodeIfPresent(String.self, forKey: .savedSearchId)) : nil
        }
    }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    provider: ServedIndexProvider) {
        let store = services.store
        let now = services.now

        me.get("collections") { request, context -> CollectionList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let collections = try await self.collections(of: user.id, in: store)
            return CollectionList(total: collections.count, items: collections.map(CollectionListItem.init))
        }
        // The Mac's New Collection sheet: a name, trimmed and never empty, in the project the user works in.
        me.post("collections") { request, context -> EditedResponse<CollectionDetail> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(NewCollection.self, from: request, fields: ["name"])
            let name = try checked(body.name, "name").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw invalidField("name", "a new collection's name, trimmed, cannot be empty.")
            }
            let active = try await Blocking.run { try store.activeProjectId(of: user.id) }
            let time = UserStoreDate.rounded(now())
            let collection = newCollection(name: name, projectIds: active.flatMap(UUID.init(uuidString:)).map { [$0] } ?? [],
                                           at: time)
            let rows = try await Blocking.run { try store.addCollection(change(collection), for: user.id) }
            let location = context.basePath.prefixing("/api/v1/me/collections/\(collection.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location],
                                  response: try await detail(values(rows), for: user.id, in: store, resources: resources,
                                                             provider: provider))
        }
        me.get("collections/:collectionId") { request, context -> CollectionDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let collection = try await self.collection(try context.parameters.require("collectionId"), of: user.id, in: store)
            return try await detail(collection, for: user.id, in: store, resources: resources, provider: provider)
        }
        // Each field as the editor commits it: a text trimmed, an empty one none, and written only when
        // it changes what is saved (`CollectionEditorCommit`); an edit of the name, the description or the
        // title page files the collection under the project the user works in, as the editor's
        // `recordEdit()` does; the composition's fields as its pickers and switches write them.
        me.patch("collections/:collectionId") { request, context -> CollectionDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let body = try await JSONBody.decode(Change.self, from: request, fields: Change.fields,
                                                 limit: UserDataServices.noteBodyLimit)
            for case let (text?, field) in [(body.name, "name"), (body.note, "note"), (body.subtitle, "subtitle"),
                                            (body.authorLine, "authorLine")] {
                _ = try checked(text, field)
            }
            let summaryOnly = CollectionBodyDepth.summaryOnly.rawValue
            let summaryOnlyOffered: Bool
            if body.defaultBodyDepth == summaryOnly {
                let held = try await collection(id, of: user.id, in: store)
                summaryOnlyOffered = summariesAvailable(held, summarized: try await summarizedDocuments(of: user.id, in: store))
            } else {
                summaryOnlyOffered = true
            }
            let promptIds = body.summaryPromptId != nil ? try await promptIds(of: user.id, in: store) : []
            // Link to Saved Search… offers the user's saved searches, so a link names one of them.
            let link: UUID??
            switch body.savedSearchId {
            case .none: link = nil
            case .some(.none): link = .some(nil)
            case .some(.some(let raw)): link = .some(try await savedSearchLink(raw, of: user.id, in: store))
            }
            let active = try await Blocking.run { try store.activeProjectId(of: user.id) }.flatMap(UUID.init(uuidString:))
            let time = UserStoreDate.rounded(now())
            let rows = try await changed(id, for: user.id, in: store, at: time) { collection in
                var committed = false
                if let name = body.name, !CollectionEditorNaming.fieldAgrees(name, withSavedName: collection.name) {
                    collection.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    committed = true
                }
                for (text, keyPath) in [(body.note, \CollectionExport.note), (body.subtitle, \.subtitle),
                                        (body.authorLine, \.authorLine)] {
                    guard let text, !CollectionEditorNaming.fieldAgrees(text, withSavedName: collection[keyPath: keyPath] ?? "") else {
                        continue
                    }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    collection[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
                    committed = true
                }
                for (flag, keyPath) in [(body.includeColophon, \CollectionExport.includeColophon),
                                        (body.includeProjectProvenance, \.includeProjectProvenance),
                                        (body.includeMethodAppendix, \.includeMethodAppendix)] {
                    guard let flag, collection[keyPath: keyPath] != flag else { continue }
                    collection[keyPath: keyPath] = flag
                    committed = true
                }
                // `CollectionEditorCommit.savedSearch(_:to:)`: the link, or none, when it differs from the saved one.
                if let link, collection.savedSearchId != link {
                    collection.savedSearchId = link
                    committed = true
                }
                // `recordEdit()`, after a commit of one of the editor's own fields.
                if committed, let active, !collection.projectIds.contains(active) { collection.projectIds.append(active) }
                // `saveIntroduction(rtf:plain:)`: an introduction with no text but spaces is none.
                if let edit = body.introduction {
                    let introduction = try introductionBody(edit.text, runs: edit.runs, held: collection.introductionRichText)
                    collection.introductionText = introduction?.text
                    collection.introductionRichText = introduction?.richText.map { Data($0) }
                }
                if let depth = body.defaultBodyDepth {
                    guard CollectionBodyDepth(rawValue: depth) != nil else {
                        throw invalidField("defaultBodyDepth", "\(depth) is no body depth: full, summaryOnly or index.")
                    }
                    // Offered by the kit's rule, as Briefing packet is; a depth the collection holds stands.
                    guard depth != summaryOnly || summaryOnlyOffered || collection.defaultBodyDepth == depth else { throw depthNotOffered() }
                    collection.defaultBodyDepth = depth
                }
                if let footnotes = body.includeFootnotes {
                    CollectionEditing.writeFootnoteFlags(footnotes: footnotes, sourceNote: CollectionEditing.effectiveIncludeSourceNote(collection),
                                                         to: &collection)
                }
                if let sourceNote = body.includeSourceNote {
                    CollectionEditing.writeFootnoteFlags(footnotes: CollectionEditing.effectiveIncludeFootnotes(collection), sourceNote: sourceNote,
                                                         to: &collection)
                }
                if let style = body.tocStyle {
                    guard CollectionToCStyle(rawValue: style) != nil else {
                        throw invalidField("tocStyle", "\(style) is no contents style: citation or headerAndDateline.")
                    }
                    collection.tocStyle = style
                }
                if let flag = body.applyHighlights { collection.applyHighlights = flag }
                if let flag = body.includeNotes { collection.includeNotes = flag }
                if let flag = body.includeWordCloud { collection.includeWordCloud = flag }
                if let flag = body.defaultIncludeHeadnote { collection.defaultIncludeHeadnote = flag }
                if let prompt = body.summaryPromptId {
                    collection.summaryPromptId = try promptId(prompt, among: promptIds, field: "summaryPromptId")
                }
            }
            return try await detail(values(rows), for: user.id, in: store, resources: resources, provider: provider)
        }
        // The Collections list's delete: the collection, its entries and their headnote drafts.
        me.delete("collections/:collectionId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            guard try await Blocking.run({ try store.deleteCollection(id, for: user.id) }) else { throw notFound(id) }
            return Response(status: .noContent)
        }
        // The list's Duplicate, `Collection.duplicate(in:)`.
        me.post("collections/:collectionId/duplicate") { request, context -> EditedResponse<CollectionDetail> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let source = try await collection(try context.parameters.require("collectionId"), of: user.id, in: store)
            let (drafts, unreadable) = try await headnoteDrafts(of: user.id, in: store)
            let (copy, copied) = CollectionEditing.duplicate(source, drafts: drafts, unreadable: unreadable, at: UserStoreDate.rounded(now()))
            let rows = try await Blocking.run { try store.addCollection(change(copy, addedSummaries: copied), for: user.id) }
            let location = context.basePath.prefixing("/api/v1/me/collections/\(copy.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location],
                                  response: try await detail(values(rows), for: user.id, in: store, resources: resources,
                                                             provider: provider))
        }
        // A preset's card, the editor's `applyPreset(_:)`. One the collection is not offered is refused.
        me.post("collections/:collectionId/preset") { request, context -> CollectionDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("collectionId")
            let body = try await JSONBody.decode(PresetChoice.self, from: request, fields: ["preset"])
            guard let preset = CollectionPreset(rawValue: body.preset) else {
                let names = CollectionPreset.allCases.map(\.rawValue)
                throw invalidField("preset", "\(body.preset) is no preset: \(names.joined(separator: ", ")).")
            }
            let held = try await collection(id, of: user.id, in: store)
            let summaries = try await summarizedDocuments(of: user.id, in: store)
            guard offeredPresets(summariesAvailable: summariesAvailable(held, summarized: summaries)).contains(preset) else {
                throw APIProblem(.conflict, code: "PRESET_NOT_OFFERED",
                                 detail: "Briefing packet composes a summary of each document, and none of this collection's documents has one stored.")
            }
            let time = UserStoreDate.rounded(now())
            let rows = try await changed(id, for: user.id, in: store, at: time) { collection in
                CollectionEditing.applyPreset(preset, to: &collection, at: time)
            }
            return try await detail(values(rows), for: user.id, in: store, resources: resources, provider: provider)
        }
        // The Research rail's Collections section: those that hold the document among their documents,
        // by the name each row prints, a tie by id (`ResearchRailView.distinctCollections(from:)`).
        me.get("volumes/:volumeId/documents/:documentId/collections") { request, context -> DocumentCollections in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try UserDataRoutes.document(context, resources: resources)
            let rows = try await Blocking.run { try store.collections(holding: document.volumeId, document.documentId, of: user.id) }
            let held = try rows.map { row -> (id: String, name: String) in
                let fields = ResearchExport.Fields("collections", row)
                return (try fields.uuid("id").uuidString, try fields.text("name"))
            }
            let sorted = held.sorted {
                let order = CollectionEditorNaming.listOrder($0.name, $1.name)
                return order != .orderedSame ? order == .orderedAscending : $0.id < $1.id
            }
            return DocumentCollections(volumeId: document.volumeId, documentId: document.documentId, items: sorted.map {
                .init(id: $0.id, listName: CollectionEditorNaming.listName(savedName: $0.name))
            })
        }
    }

    // MARK: - Reading and writing

    /// The user's collections, the most recently changed first, as `@Query(sort: \Collection.lastModified,
    /// order: .reverse)` lists them, one with no time last; a tie in the store's order.
    static func collections(of user: String, in store: any UserDataStore) async throws -> [CollectionExport] {
        let (rows, entries) = try await Blocking.run { try store.collectionRows(of: user) }
        var byCollection: [String: [ExportRow]] = [:]
        for entry in entries {
            guard let id = entry.values["collection_id"]?.text else { continue }
            byCollection[UserSearchText.uuidString(id), default: []].append(entry)
        }
        let collections = try rows.map { row in
            try values(CollectionRows(collection: row, entries: byCollection[UserSearchText.uuidString(row.values["id"]?.text ?? "")] ?? []))
        }
        return collections.enumerated().sorted { a, b in
            let (x, y) = (a.element.lastModified ?? .distantPast, b.element.lastModified ?? .distantPast)
            return x != y ? x > y : a.offset < b.offset
        }.map(\.element)
    }

    static func collection(_ id: String, of user: String, in store: any UserDataStore) async throws -> CollectionExport {
        guard let rows = try await Blocking.run({ try store.collectionRows(id, of: user) }) else { throw notFound(id) }
        return try values(rows)
    }

    /// A collection's values as the export reads them, its entries in the order they sit
    /// (`CollectionEntryOrdering.modelOrder(of:)`).
    static func values(_ rows: CollectionRows) throws -> CollectionExport {
        do {
            var collection = try ResearchExport.collection(ResearchExport.Fields("collections", rows.collection), entries: rows.entries)
            collection.entries = CollectionEditing.modelOrder(collection.entries)
            return collection
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The collection could not be read: \(error.description)")
        }
    }

    /// The rows the store keeps for `collection`, as the import writes a Mac's record at the export's version,
    /// with the headnote drafts the write adds and deletes, and the notes a new collection's file brings.
    static func change(_ collection: CollectionExport, addedSummaries: [GeneratedSummaryExport] = [],
                       deletedSummaries: [UUID] = [], notes: [NoteRecord] = []) -> CollectionChange {
        let version = ResearchDataEnvelope.currentFormatVersion
        return CollectionChange(collection: MacImport.collection(collection, version: version).values,
                                entries: collection.entries.map { MacImport.entry($0, of: collection, version: version).values },
                                addedSummaries: addedSummaries.map { MacImport.summary($0, version: version).values },
                                deletedSummaries: deletedSummaries.map(\.uuidString), addedNotes: notes)
    }

    /// Changes the user's collection in one write: `edit` makes what it becomes from the values as the
    /// write finds them, and each entry it changes is stamped now, and the collection when its own
    /// fields change or an entry joins or leaves it, as the app's save stamps each model it changed
    /// (`ModelModificationStamper`), with the headnote drafts the write adds and those it deletes. Throws
    /// what `edit` throws, writing nothing.
    @discardableResult
    static func changed(_ id: String, for user: String, in store: any UserDataStore, at time: Date,
                        addingSummaries added: [GeneratedSummaryExport] = [], deletingSummaries deleted: [UUID] = [],
                        _ edit: @escaping @Sendable (inout CollectionExport) throws -> Void) async throws -> CollectionRows {
        let rows: CollectionRows?
        do {
            rows = try await Blocking.run {
                try store.changeCollection(id, for: user) { held in
                    let before = try values(held)
                    var after = before
                    try edit(&after)
                    return change(stamped(after, from: before, at: time), addedSummaries: added, deletedSummaries: deleted)
                }
            }
        } catch let error as ResearchRowStoreError {
            throw APIProblem(.internalServerError, code: "STORE_REFUSED", detail: error.description)
        }
        guard let rows else { throw notFound(id) }
        return rows
    }

    /// `after` with `lastModified` now on each entry that differs from `before`'s, and on the collection
    /// when its own fields differ or an entry joined or left it.
    static func stamped(_ after: CollectionExport, from before: CollectionExport, at time: Date) -> CollectionExport {
        var result = after
        let held = Dictionary(before.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for index in result.entries.indices {
            guard let old = held[result.entries[index].id] else { continue }
            var compared = result.entries[index]
            compared.lastModified = old.lastModified
            if compared != old { result.entries[index].lastModified = time }
        }
        var own = result
        own.entries = []
        own.lastModified = before.lastModified
        var heldOwn = before
        heldOwn.entries = []
        if own != heldOwn || Set(result.entries.map(\.id)) != Set(before.entries.map(\.id)) { result.lastModified = time }
        return result
    }

    /// A collection made now with `name` and `projectIds`, each other field at the app's initial value
    /// (`Collection.init(name:note:projectIds:)`).
    static func newCollection(name: String, projectIds: [UUID], at time: Date) -> CollectionExport {
        CollectionExport(id: UUID(), name: name, note: nil, projectIds: projectIds, savedSearchId: nil, entries: [],
                         createdAt: time, lastModified: time, includeColophon: false, includeProjectProvenance: false,
                         includeMethodAppendix: false, defaultBodyDepth: CollectionBodyDepth.full.rawValue,
                         footnoteStyle: CollectionFootnoteStyle.all.rawValue, includeFootnotes: nil, includeSourceNote: nil,
                         tocStyle: CollectionToCStyle.citation.rawValue, applyHighlights: false, includeNotes: true,
                         includeWordCloud: false, defaultIncludeHeadnote: false, summaryPromptId: nil)
    }

    /// The introduction as the store keeps it: none for text with nothing but spaces, as
    /// `saveIntroduction(rtf:plain:)` keeps none, else its text and the codec's RTF of its runs, or
    /// its text alone for a plain edit, a link the introduction held accepted back as a note's is.
    static func introductionBody(_ text: String, runs: [RichTextRun]?, held: Data?) throws -> NoteBody? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return try NoteFormatting.body(text, runs: runs, stored: { NoteFormatting.links(of: held.map { [UInt8]($0) }) },
                                       isNew: false)
    }

    // MARK: - The editor's view

    /// What the editor shows of a collection.
    static func detail(_ collection: CollectionExport, for user: String, in store: any UserDataStore,
                       resources: ServerResources, provider: ServedIndexProvider) async throws -> CollectionDetail {
        let (prompts, noteCounts) = try await Blocking.run { (try store.prompts(for: user), try store.noteCounts(of: user)) }
        var savedSearchName: String?
        if let id = collection.savedSearchId,
           let row = try await Blocking.run({ try store.searchSet(.savedSearches, id: id.uuidString, of: user) }) {
            savedSearchName = try? SavedSearchRoutes.read(row).name
        }
        let summarized = try await summarizedDocuments(of: user, in: store)
        let available = summariesAvailable(collection, summarized: summarized)
        let entries = collection.entries
        let keys = entries.filter { $0.entryKind == .document || $0.entryKind == .excerpt }
            .map { DocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
        let facts = await documentFacts(keys, provider: provider)
        let depths = CollectionEditing.depths(entries)
        let duplicates = CollectionEditing.duplicateDocumentKeys(in: entries)
        let introduction = NoteFormatting.runs(of: collection.introductionRichText.map { [UInt8]($0) },
                                               text: collection.introductionText ?? "")
        return CollectionDetail(
            id: collection.id.uuidString, name: collection.name, listName: CollectionEditorNaming.listName(savedName: collection.name),
            note: collection.note, subtitle: collection.subtitle, authorLine: collection.authorLine,
            introductionText: collection.introductionText, introductionRuns: introduction.runs,
            introductionFormattingKept: introduction.kept, includeColophon: collection.includeColophon ?? false,
            includeProjectProvenance: collection.includeProjectProvenance ?? false,
            includeMethodAppendix: collection.includeMethodAppendix ?? false, projectIds: collection.projectIds.map(\.uuidString),
            savedSearchId: collection.savedSearchId?.uuidString, savedSearchName: savedSearchName,
            takesHandAddedEntries: CollectionEditing.takesHandAddedEntries(collection),
            defaultBodyDepth: collection.defaultBodyDepth ?? CollectionBodyDepth.full.rawValue,
            includeFootnotes: CollectionEditing.effectiveIncludeFootnotes(collection),
            includeSourceNote: CollectionEditing.effectiveIncludeSourceNote(collection),
            tocStyle: collection.tocStyle ?? CollectionToCStyle.citation.rawValue, applyHighlights: collection.applyHighlights ?? false,
            includeNotes: collection.includeNotes ?? true, includeWordCloud: collection.includeWordCloud ?? false,
            defaultIncludeHeadnote: collection.defaultIncludeHeadnote ?? false, summaryPromptId: collection.summaryPromptId?.uuidString,
            summariesAvailable: available,
            bodyDepths: CollectionBodyDepth.available(summariesAvailable: available).map(\.rawValue),
            presets: offeredPresets(summariesAvailable: available).map {
                .init(id: $0.rawValue, active: CollectionEditing.matches($0, collection))
            },
            prompts: prompts.map { .init(id: $0.key, name: $0.value) }.sorted {
                $0.name != $1.name ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.id < $1.id
            },
            documentCount: CollectionEditing.documentCount(entries),
            // None for a smart collection, whose documents are its search's results, as the app names none.
            volumesNotHeld: collection.savedSearchId != nil ? []
                : CollectionExportRoutes.volumesNotHeld(entries, resources: resources, in: provider.volumesDirectory).sorted(),
            entries: entries.enumerated().map { index, entry in
                let key = "\(entry.volumeId)/\(entry.documentId)"
                let kind = entry.entryKind
                let carriesDocument = kind == .document || kind == .excerpt
                let runs = kind == .prose
                    ? NoteFormatting.runs(of: entry.richText.map { [UInt8]($0) }, text: entry.text ?? "") : (runs: nil, kept: false)
                return CollectionDetail.Entry(
                    id: entry.id.uuidString, kind: kind.rawValue, sortOrder: entry.sortOrder, level: entry.level ?? 1,
                    depth: depths[index], documentId: entry.documentId, volumeId: entry.volumeId, text: entry.text,
                    runs: runs.runs, formattingKept: runs.kept, titleOverride: entry.titleOverride,
                    bodyDepthOverride: entry.bodyDepthOverride, applyHighlightsOverride: entry.applyHighlightsOverride,
                    includeNotesOverride: entry.includeNotesOverride, includeSourceNoteOverride: entry.includeSourceNoteOverride,
                    includeFootnotesOverride: entry.includeFootnotesOverride,
                    summaryPromptIdOverride: entry.summaryPromptIdOverride?.uuidString,
                    includeRelatedDocuments: entry.includeRelatedDocuments, includeHeadnote: entry.includeHeadnote,
                    headnoteSummaryId: entry.headnoteSummaryId?.uuidString, researchNoteId: entry.researchNoteId?.uuidString,
                    selectedNoteIds: entry.selectedNoteIds.map(\.uuidString),
                    selectedHighlightIds: (entry.selectedHighlightIds ?? []).map(\.uuidString),
                    excerptStart: entry.excerptStart, excerptEnd: entry.excerptEnd,
                    excerptRenderingVersion: entry.excerptRenderingVersion, excerptColorTag: entry.excerptColorTag,
                    generatedBlockType: entry.generatedBlockType,
                    sectionEnd: kind == .heading ? CollectionEditing.sectionRange(of: index, in: entries).upperBound : nil,
                    canIndent: CollectionEditing.canIndent(index, in: entries),
                    canOutdent: CollectionEditing.canOutdent(index, in: entries),
                    leftOut: CollectionEditing.leavesOut(kind, savedSearchId: collection.savedSearchId),
                    isDuplicate: kind == .document && duplicates.contains(key),
                    header: carriesDocument ? facts[key]?.header : nil,
                    volumeTitle: carriesDocument ? resources.volume(entry.volumeId)?.title : nil,
                    dateISO: carriesDocument ? facts[key]?.dateISO : nil,
                    noteCount: kind == .document ? noteCounts[key] ?? 0 : nil)
            },
            createdAt: collection.createdAt.map(UserStoreDate.text), lastModified: collection.lastModified.map(UserStoreDate.text))
    }

    /// The presets a collection is offered, in the kit's order: Briefing packet, which composes a
    /// summary of each document, only where summaries can be had.
    static func offeredPresets(summariesAvailable: Bool) -> [CollectionPreset] {
        CollectionPreset.allCases.filter { summariesAvailable || $0.recipe.bodyDepth != .summaryOnly }
    }

    /// Whether summaries can be had for a collection on a server that writes none: whether a document
    /// entry's document has a summary stored that is not a headnote draft. The kit's
    /// `CollectionBodyDepth.available(summariesAvailable:)` reads it, as a host without a summarizer
    /// passes whether it has summaries to show.
    static func summariesAvailable(_ collection: CollectionExport, summarized: Set<String>) -> Bool {
        collection.entries.contains { $0.entryKind == .document && summarized.contains("\($0.volumeId)/\($0.documentId)") }
    }

    /// The documents the user has a summary of that is no headnote draft and holds text, by key.
    static func summarizedDocuments(of user: String, in store: any UserDataStore) async throws -> Set<String> {
        try await Blocking.run { try store.summarizedDocuments(of: user) }
    }

    /// The user's headnote drafts, by id, which a duplicate's entries take copies of, and the ids of
    /// those the export's reader cannot read, which a copy leaves out.
    static func headnoteDrafts(of user: String, in store: any UserDataStore) async throws
        -> (drafts: [UUID: GeneratedSummaryExport], unreadable: Set<UUID>) {
        let rows = try await Blocking.run { try store.researchRows(UserStoreSchema.table(for: "GeneratedSummary")!, of: user) }
        var drafts: [UUID: GeneratedSummaryExport] = [:]
        var unreadable = Set<UUID>()
        for row in rows where row.values["is_headnote_draft"]?.integer == 1 {
            guard let summary = try? ResearchExport.summary(ResearchExport.Fields("summaries", row)) else {
                if let id = row.values["id"]?.text.flatMap(UUID.init(uuidString:)) { unreadable.insert(id) }
                continue
            }
            if drafts[summary.id] == nil { drafts[summary.id] = summary }
        }
        return (drafts, unreadable.subtracting(drafts.keys))
    }

    /// What the served index says of each document: its header, as `CrossReferenceStore.documentHeaders`
    /// gives it, none when empty; its source note; and its day. Nothing while no index is served, or for
    /// a document it does not hold.
    struct DocumentFacts: Sendable {
        var header: String?
        var sourceNote: String?
        var documentNumber: String?
        var dateISO: String?
    }

    static func documentFacts(_ keys: [DocumentKey], provider: ServedIndexProvider) async -> [String: DocumentFacts] {
        guard !keys.isEmpty, let served = try? await provider.servedIfReady() else { return [:] }
        var facts: [String: DocumentFacts] = [:]
        let byVolume = Dictionary(grouping: keys, by: \.volumeId)
        for (volumeId, documents) in byVolume where served.indexedVolumeIds.contains(volumeId) {
            let wanted = Set(documents.map(\.documentId))
            guard let entries = try? await served.pipeline.documents(forVolume: volumeId) else { continue }
            for entry in entries where wanted.contains(entry.documentId) {
                facts["\(volumeId)/\(entry.documentId)"] = DocumentFacts(
                    header: entry.header.isEmpty ? nil : entry.header, sourceNote: entry.sourceNote,
                    documentNumber: entry.documentNumber)
            }
        }
        if let dates = try? await served.pipeline.datesByDocumentKey(keys.map { (volumeId: $0.volumeId, documentId: $0.documentId) }) {
            for (key, date) in dates { facts[key, default: DocumentFacts()].dateISO = date }
        }
        return facts
    }

    // MARK: - Fields

    /// The ids of the user's summary prompts, in uppercase.
    static func promptIds(of user: String, in store: any UserDataStore) async throws -> Set<String> {
        Set(try await Blocking.run { try store.prompts(for: user) }.keys)
    }

    /// The saved search a link names, one the user holds.
    static func savedSearchLink(_ raw: String, of user: String, in store: any UserDataStore) async throws -> UUID {
        guard let id = UUID(uuidString: raw), try await Blocking.run({ try store.searchSet(.savedSearches, id: id.uuidString, of: user) }) != nil else {
            throw invalidField("savedSearchId", "you have no saved search with the id \(raw).")
        }
        return id
    }

    /// A prompt the user holds, or none for null.
    static func promptId(_ raw: String?, among held: Set<String>, field: String) throws -> UUID? {
        guard let raw else { return nil }
        guard let id = UUID(uuidString: raw), held.contains(id.uuidString) else {
            throw invalidField(field, "you have no summary prompt with the id \(raw).")
        }
        return id
    }

    static func invalidField(_ name: String, _ detail: String) -> APIProblem {
        APIProblem(.badRequest, code: "INVALID_FIELD", detail: "\(name): \(detail)")
    }

    /// A text a collection or an entry keeps as it is given: refused, as a note's is, with U+0000, where
    /// SQLite's text ends, or past `UserDataServices.noteTextLimit` in UTF-8.
    static func checked(_ text: String, _ field: String) throws -> String {
        guard text.utf8.count <= UserDataServices.noteTextLimit else {
            throw invalidField(field, "may hold at most \(UserDataServices.noteTextLimit / 1_048_576) MiB of text, in UTF-8.")
        }
        guard !text.unicodeScalars.contains("\0") else { throw invalidField(field, "cannot hold U+0000.") }
        return text
    }

    /// Summary only, set where the kit's rule does not offer it, as Briefing packet's card is refused, with the
    /// app's reason a summary must be had (PLAN's S18f).
    static func depthNotOffered() -> APIProblem {
        APIProblem(.conflict, code: "DEPTH_NOT_OFFERED",
                   detail: "Summary only shows a summary of each document, and none of this collection's documents has one stored. \(SummariesNotStored.appsReason)")
    }

    /// Summary only, set on a document whose document has no summary stored, with the app's reason.
    static func documentDepthNotOffered() -> APIProblem {
        APIProblem(.conflict, code: "DEPTH_NOT_OFFERED",
                   detail: "Summary only shows this document's summary, and it has none stored. \(SummariesNotStored.appsReason)")
    }

    static func notFound(_ id: String) -> APIProblem {
        APIProblem(.notFound, code: "COLLECTION_NOT_FOUND", detail: "You have no collection with the id \(id).")
    }

    /// The Add to Collection picker's refusal of a smart collection, in its words
    /// (`CollectionPickerCopy.addFailure`).
    static func smart() -> APIProblem {
        APIProblem(.conflict, code: "COLLECTION_IS_SMART",
                   detail: "This is a smart collection. Its documents come from its saved search, so nothing can be added to it by hand.")
    }
}
