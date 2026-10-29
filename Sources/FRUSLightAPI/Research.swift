// The Research page (PLAN's S19b), as the app's `ResearchView` shows it: every document the user has
// annotated, with a note, a tag, a collection entry, a highlight, a summary or a place in a visit plan,
// as the kit's `ResearchDocumentAggregation` gathers them (S17b's FRUS-Explorer#1805); the documents
// a note is on, every note's count, and the documents of each collection, tag and highlight colour;
// and each document's row. Read once a request from the store, as the export reads its records
// (`ResearchExport`). What the kit holds is called: the six sources' union, a collection's distinct
// documents, the kinds of entry that count and the summaries a row may name. What the app's view
// computes for itself is a few lines of view code, mirrored here, held to its source by
// ResearchPageParityTests:
// - `documentsWithNotesCount`, `directlyTaggedDocs` and `collectionMemberships`;
// - the three sections, `sortedCollectionsWithCounts`, `sortedTagsWithCounts` and
//   `sortedHighlightColorsWithCounts`, with `DocumentHighlight.color`'s reading of a colour;
// - `documents(for:)`, which documents a category lists and each row's facts, with their order;
// - the row's newest annotation, its three highlights, and its tags' and collections' order.
// Changed by an update reads the index's `reviewed_at`, which a served index's reader cannot write, so
// it waits for phase 3's review of changed text, and its list says so (`UPDATE_REVIEW_NOT_OFFERED`).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// The Research page's categories, as the app's sidebar lists them, each with its count.
public struct ResearchPage: Codable, Equatable, Sendable, ResponseEncodable {
    /// All Research Documents: the documents any annotation is on.
    public var allAnnotated: Int
    /// Contains Notes: the documents a note is on.
    public var hasNotes: Int
    /// All Notes: every note.
    public var notes: Int
    /// By Collection: the collections, but smart ones, that hold a document, by the name each prints.
    public var collections: [Group]
    /// By Tag: the tags on a document, the most used first.
    public var tags: [Group]
    /// By Highlight: the colours in use, in the kit's order.
    public var highlightColors: [ColorGroup]

    /// A collection or a tag, with what its row prints and how many documents its list holds.
    public struct Group: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var count: Int
    }

    /// A colour, the kit's `HighlightColor`, with how many documents its list holds.
    public struct ColorGroup: Codable, Equatable, Sendable {
        public var color: String
        public var count: Int
    }
}

/// One category's documents, the most recently annotated first.
public struct ResearchDocumentList: Codable, Equatable, Sendable, ResponseEncodable {
    /// The category, as the request named it.
    public var group: String
    /// For a tag's list, the tag's name, absent for a tag the user has none of; for a collection's,
    /// the name its row prints. The list's title.
    public var name: String?
    public var total: Int
    public var items: [ResearchDocument]
}

/// A row of a Research list, as the app's draws it.
public struct ResearchDocument: Codable, Equatable, Sendable {
    public var volumeId: String
    public var documentId: String
    /// What the list calls the document: the kit's display title of what the served index holds of
    /// it, or its id.
    public var title: String
    /// The volume's title in the catalogue, or its id.
    public var volumeTitle: String
    /// The later of the times its newest note changed and its newest highlight was made, as the store
    /// keeps times; absent for neither.
    public var annotatedAt: String?
    /// Its newest note's text; absent for no note, or one with none.
    public var latestNote: String?
    public var noteCount: Int
    /// Its summaries, headnote drafts left out.
    public var summaryCount: Int
    /// Whether a visit plan names it.
    public var isInVisitPlan: Bool
    /// Its three newest highlights, newest first.
    public var highlights: [Highlight]
    /// How many highlights it has.
    public var highlightCount: Int
    /// The tags on it and on its notes, by name.
    public var tags: [Named]
    /// The collections it is in, by the name each prints.
    public var collections: [Named]

    /// A highlight's colour, the kit's, and its words, empty for one that stored none.
    public struct Highlight: Codable, Equatable, Sendable {
        public var id: String
        public var color: String
        public var selectedText: String
    }

    public struct Named: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
    }
}

/// A category of the page, named as the app's `ResearchSidebarItem.rowAccessibilityIdentifier` names
/// its row: All Notes and History, which open screens of their own, are none.
enum ResearchGroup: Equatable, Sendable {
    case allAnnotated
    case hasNotes
    case tag(UUID)
    case collection(UUID)
    case highlightColor(HighlightColor)
    /// Changed by an update, which waits for phase 3.
    case updated

    init?(_ raw: String) {
        switch raw {
        case "allAnnotated": self = .allAnnotated
        case "hasNotes": self = .hasNotes
        case "updated": self = .updated
        default:
            let parts = raw.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2 else { return nil }
            switch parts[0] {
            case "tag":
                guard let id = UUID(uuidString: parts[1]) else { return nil }
                self = .tag(id)
            case "collection":
                guard let id = UUID(uuidString: parts[1]) else { return nil }
                self = .collection(id)
            case "highlightColor":
                guard let color = HighlightColor(rawValue: parts[1]) else { return nil }
                self = .highlightColor(color)
            default:
                return nil
            }
        }
    }
}

/// What the page reads of one user's store at one moment, as the export reads its records: the six
/// sources the kit's aggregation reads, and the tags' names.
struct ResearchSources: Sendable {
    var notes: [ResearchNoteExport]
    var tags: [UserTagExport]
    var tagAssignments: [DocumentTagAssignmentExport]
    /// Each collection with its entries.
    var collections: [CollectionExport]
    var highlights: [DocumentHighlightExport]
    /// Every summary, headnote drafts among them.
    var summaries: [GeneratedSummaryExport]
    /// Every visit plan's documents, as their `documentKey`s.
    var visitDocumentKeys: [String]

    static let tables: Set<String> = ["notes", "tags", "tag_assignments", "collections", "collection_entries", "highlights",
                                      "summaries", "visit_documents"]

    static func read(for user: String, in store: any UserDataStore) async throws -> ResearchSources {
        let rows = try await Blocking.run { try store.researchRows(for: user, tables: tables) }
        do {
            let entries = try ResearchExport.children(rows["collection_entries"], in: "collection_entries", of: "collection_id")
            return ResearchSources(
                notes: try ResearchExport.records(rows, "notes") { try ResearchExport.note($0, links: [:]) },
                tags: try ResearchExport.records(rows, "tags", ResearchExport.tag),
                tagAssignments: try ResearchExport.records(rows, "tag_assignments", ResearchExport.assignment),
                collections: try ResearchExport.records(rows, "collections") { row in
                    try ResearchExport.collection(row, entries: entries[try row.uuid("id")] ?? [])
                },
                highlights: try ResearchExport.records(rows, "highlights", ResearchExport.highlight),
                summaries: try ResearchExport.records(rows, "summaries", ResearchExport.summary),
                visitDocumentKeys: try rows["visit_documents"].map { try ResearchExport.Fields("visit_documents", $0).text("document_key") })
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "Your research could not be read: \(error.description)")
        }
    }
}

/// The app's `ResearchView` over one read of the store: its badges, its sections and its lists, each
/// as its computed property makes it, the kit's aggregation where it calls the kit.
struct ResearchGroups {
    let sources: ResearchSources

    /// `ResearchDocumentEntry`: one row's facts.
    struct Entry {
        /// `"volumeId/documentId"`.
        let id: String
        let volumeId: String
        let documentId: String
        /// The most recently changed note, or nil for none.
        let latestNote: ResearchNoteExport?
        let noteCount: Int
        var summaryCount: Int = 0
        var isInVisitPlan: Bool = false
        /// The tags of its notes and its own.
        let allTagIds: Set<UUID>
        let collectionIds: Set<UUID>
        /// Newest first.
        let highlights: [DocumentHighlightExport]

        /// The row's date: its newest annotation's, the later of its newest note's and its newest
        /// highlight's.
        var annotationDate: Date? {
            [latestNote?.lastModified, highlights.first?.createdAt].compactMap { $0 }.max()
        }
    }

    // MARK: The kit's

    /// An entry's values, as the app's `Entry(of:)` hands them to the kit; a record with no kind is a
    /// document, as the kit's `entryKind` reads one.
    static func entry(_ entry: CollectionEntryExport) -> ResearchDocumentAggregation.Entry {
        ResearchDocumentAggregation.Entry(kind: entry.kind ?? CollectionEntryKind.document.rawValue, volumeId: entry.volumeId,
                                          documentId: entry.documentId)
    }

    /// A summary's values, as the app's `Summary(of:)` hands them to the kit.
    static func summary(_ summary: GeneratedSummaryExport) -> ResearchDocumentAggregation.Summary {
        ResearchDocumentAggregation.Summary(volumeId: summary.volumeId, documentId: summary.documentId,
                                            isHeadnoteDraft: summary.isHeadnoteDraft ?? false)
    }

    /// Every document carrying any annotation, across the six sources: the kit's
    /// `annotatedKeys(among:)` over the records' values, as the app's overload passes its models'.
    var allAnnotatedKeys: Set<String> {
        ResearchDocumentAggregation.annotatedKeys(among: ResearchDocumentAggregation.Sources(
            notes: sources.notes.map { ResearchDocumentAggregation.DocumentRef(volumeId: $0.volumeId, documentId: $0.documentId) },
            tagAssignments: sources.tagAssignments.map {
                ResearchDocumentAggregation.DocumentRef(volumeId: $0.volumeId, documentId: $0.documentId)
            },
            collections: sources.collections.map { $0.entries.map(Self.entry) },
            highlights: sources.highlights.map { ResearchDocumentAggregation.DocumentRef(volumeId: $0.volumeId, documentId: $0.documentId) },
            summaries: sources.summaries.map(Self.summary),
            visitDocumentKeys: sources.visitDocumentKeys))
    }

    /// Summary counts by document key, drafts left out: the kit's `summaryCounts(among:)`.
    var summarizedDocs: [String: Int] {
        ResearchDocumentAggregation.summaryCounts(among: sources.summaries.map(Self.summary))
    }

    // MARK: The app's view

    /// How many distinct documents carry at least one note: Contains Notes' badge, from one source.
    var documentsWithNotesCount: Int {
        Set(sources.notes.map { "\($0.volumeId)/\($0.documentId)" }).count
    }

    /// Each document's direct tags, by `"volumeId/documentId"`.
    var directlyTaggedDocs: [String: [UUID]] {
        var result: [String: [UUID]] = [:]
        for a in sources.tagAssignments {
            let key = "\(a.volumeId)/\(a.documentId)"
            result[key, default: []].append(a.tagId)
        }
        return result
    }

    /// The collections each document is in, under the kit's rule of which entries name one.
    var collectionMemberships: [String: Set<UUID>] {
        var result: [String: Set<UUID>] = [:]
        for collection in sources.collections {
            for entry in collection.entries {
                guard ResearchDocumentAggregation.countsAsAnnotation(Self.entry(entry).kind) else { continue }
                guard !entry.volumeId.isEmpty, !entry.documentId.isEmpty else { continue }
                result["\(entry.volumeId)/\(entry.documentId)", default: []].insert(collection.id)
            }
        }
        return result
    }

    /// The collections, but smart ones and those with no document, each with its distinct documents, by
    /// the name each row prints, then by id.
    var sortedCollectionsWithCounts: [(collection: CollectionExport, count: Int)] {
        sources.collections.compactMap { collection in
            // Exclude smart collections — their document list is dynamic, not curated entries.
            guard collection.savedSearchId == nil else { return nil }
            let count = ResearchDocumentAggregation.distinctDocumentKeys(among: collection.entries.map(Self.entry)).count
            guard count > 0 else { return nil }
            return (collection: collection, count: count)
        }
        .sorted {
            let names = CollectionEditorNaming.listOrder($0.collection.name, $1.collection.name)
            return names != .orderedSame ? names == .orderedAscending
                                         : $0.collection.id.uuidString < $1.collection.id.uuidString
        }
    }

    /// The tags on a document, each with its distinct documents (its notes' and its own), the most used
    /// first, then by name, then by id.
    var sortedTagsWithCounts: [(tag: UserTagExport, count: Int)] {
        let directlyTaggedDocs = directlyTaggedDocs
        return sources.tags.compactMap { tag in
            let fromNotes = Set(
                sources.notes
                    .filter { $0.userTagIds.contains(tag.id) }
                    .map { "\($0.volumeId)/\($0.documentId)" }
            )
            let fromDirect = Set(
                directlyTaggedDocs
                    .filter { $0.value.contains(tag.id) }
                    .map(\.key)
            )
            let count = fromNotes.union(fromDirect).count
            guard count > 0 else { return nil }
            return (tag: tag, count: count)
        }
        .sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            let names = $0.tag.name.localizedCaseInsensitiveCompare($1.tag.name)
            return names != .orderedSame ? names == .orderedAscending
                                         : $0.tag.id.uuidString < $1.tag.id.uuidString
        }
    }

    /// The colours with at least one document, each with its distinct documents, in the kit's order.
    var sortedHighlightColorsWithCounts: [(color: HighlightColor, count: Int)] {
        HighlightColor.allCases.compactMap { color in
            let docs = Set(
                sources.highlights
                    .filter { Self.color(of: $0) == color }
                    .map { "\($0.volumeId)/\($0.documentId)" }
            )
            return docs.isEmpty ? nil : (color: color, count: docs.count)
        }
    }

    /// A highlight's colour, as `DocumentHighlight.color` reads its tag: one this build does not know
    /// is yellow.
    static func color(of highlight: DocumentHighlightExport) -> HighlightColor {
        HighlightColor(rawValue: highlight.colorTag) ?? .yellow
    }

    /// The documents named by any visit plan.
    var visitPlanDocs: Set<String> {
        Set(sources.visitDocumentKeys.filter { !$0.isEmpty })
    }

    /// Each document's highlights, in the store's order.
    var highlightedDocs: [String: [DocumentHighlightExport]] {
        var result: [String: [DocumentHighlightExport]] = [:]
        for h in sources.highlights {
            let key = "\(h.volumeId)/\(h.documentId)"
            result[key, default: []].append(h)
        }
        return result
    }

    /// A category's rows, the most recently annotated first, then by key. Changed by an update lists
    /// the annotated documents an unreviewed change touched, and a served index records none this
    /// server may review, so it lists none (the route refuses it first).
    func documents(for item: ResearchGroup) -> [Entry] {
        let matchingKeys: Set<String>
        switch item {
        case .allAnnotated:
            matchingKeys = allAnnotatedKeys
        case .hasNotes:
            matchingKeys = Set(sources.notes.map { "\($0.volumeId)/\($0.documentId)" })
        case .tag(let id):
            let fromNotes  = Set(sources.notes.filter { $0.userTagIds.contains(id) }
                                              .map { "\($0.volumeId)/\($0.documentId)" })
            let fromDirect = Set(directlyTaggedDocs.filter { $0.value.contains(id) }.map(\.key))
            matchingKeys = fromNotes.union(fromDirect)
        case .collection(let collId):
            matchingKeys = Set(collectionMemberships.filter { $0.value.contains(collId) }.map(\.key))
        case .highlightColor(let color):
            matchingKeys = Set(
                sources.highlights
                    .filter { Self.color(of: $0) == color }
                    .map { "\($0.volumeId)/\($0.documentId)" }
            )
        case .updated:
            matchingKeys = []
        }

        // The store holds one copy of each note, one row for each user and id, as the app's
        // `ResearchNote.oneCopyEach` keeps one.
        var grouped: [String: [ResearchNoteExport]] = [:]
        for key in matchingKeys { grouped[key] = [] }
        for note in sources.notes {
            let key = "\(note.volumeId)/\(note.documentId)"
            if matchingKeys.contains(key) {
                grouped[key, default: []].append(note)
            }
        }

        let directlyTaggedDocs = directlyTaggedDocs
        let collectionMemberships = collectionMemberships
        let highlightedDocs = highlightedDocs
        let summarizedDocs = summarizedDocs
        let visitPlanDocs = visitPlanDocs

        return grouped.compactMap { key, notes -> Entry? in
            let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }

            let sortedNotes = notes.sorted {
                let l = $0.lastModified ?? .distantPast, r = $1.lastModified ?? .distantPast
                return l != r ? l > r : $0.id.uuidString < $1.id.uuidString
            }
            let directTagIds = Set(directlyTaggedDocs[key] ?? [])
            let noteTagIds   = Set(notes.flatMap { $0.userTagIds })
            let colIds       = collectionMemberships[key] ?? []
            let docHighlights = (highlightedDocs[key] ?? []).sorted {
                let l = $0.createdAt ?? .distantPast, r = $1.createdAt ?? .distantPast
                return l != r ? l > r : $0.id.uuidString < $1.id.uuidString
            }

            return Entry(
                id: key,
                volumeId: parts[0],
                documentId: parts[1],
                latestNote: sortedNotes.first,
                noteCount: notes.count,
                summaryCount: summarizedDocs[key] ?? 0,
                isInVisitPlan: visitPlanDocs.contains(key),
                allTagIds: noteTagIds.union(directTagIds),
                collectionIds: colIds,
                highlights: docHighlights
            )
        }
        .sorted { lhs, rhs in
            let lhsDate = [lhs.latestNote?.lastModified,
                           lhs.highlights.first?.createdAt].compactMap { $0 }.max() ?? .distantPast
            let rhsDate = [rhs.latestNote?.lastModified,
                           rhs.highlights.first?.createdAt].compactMap { $0 }.max() ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.id < rhs.id
        }
    }

    /// A row's tags, the user's that it carries, by name, whatever the case, then by id.
    func tagRows(_ entry: Entry) -> [(id: UUID, name: String)] {
        entry.allTagIds
            .compactMap { id in sources.tags.first(where: { $0.id == id }).map { (id, $0.name) } }
            .sorted {
                let names = $0.name.localizedCaseInsensitiveCompare($1.name)
                return names != .orderedSame ? names == .orderedAscending : $0.id.uuidString < $1.id.uuidString
            }
    }

    /// A row's collections, by the name each prints, then by id.
    func collectionRows(_ entry: Entry) -> [(id: UUID, name: String)] {
        entry.collectionIds
            .compactMap { id in sources.collections.first(where: { $0.id == id }).map { (id, $0.name) } }
            .sorted {
                let names = CollectionEditorNaming.listOrder($0.name, $1.name)
                return names != .orderedSame ? names == .orderedAscending : $0.id.uuidString < $1.id.uuidString
            }
    }

    /// A list's name, as `listTitle(for:)` titles a tag's or a collection's: the tag's name, none for a
    /// tag the user does not have, which the browser app calls Tag; and the name a collection's row
    /// prints, an unnamed or missing one's the kit's.
    func name(of item: ResearchGroup) -> String? {
        switch item {
        case .tag(let id):
            return sources.tags.first(where: { $0.id == id })?.name
        case .collection(let id):
            let name = sources.collections.first(where: { $0.id == id })?.name ?? ""
            return CollectionEditorNaming.listName(savedName: name)
        case .allAnnotated, .hasNotes, .highlightColor, .updated:
            return nil
        }
    }
}

enum ResearchRoutes {
    /// How many of a row's highlights it shows, newest first; "and N more" says the rest.
    static let shownHighlights = 3

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    provider: ServedIndexProvider) {
        let store = services.store

        me.get("research") { request, context -> ResearchPage in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let groups = ResearchGroups(sources: try await ResearchSources.read(for: user.id, in: store))
            return ResearchPage(
                allAnnotated: groups.allAnnotatedKeys.count,
                hasNotes: groups.documentsWithNotesCount,
                notes: groups.sources.notes.count,
                collections: groups.sortedCollectionsWithCounts.map {
                    ResearchPage.Group(id: $0.collection.id.uuidString,
                                       name: CollectionEditorNaming.listName(savedName: $0.collection.name), count: $0.count)
                },
                tags: groups.sortedTagsWithCounts.map { ResearchPage.Group(id: $0.tag.id.uuidString, name: $0.tag.name, count: $0.count) },
                highlightColors: groups.sortedHighlightColorsWithCounts.map {
                    ResearchPage.ColorGroup(color: $0.color.rawValue, count: $0.count)
                })
        }
        me.get("research/documents") { request, context -> ResearchDocumentList in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["group"])
            let user = try context.requireUser()
            let raw = try query.single("group") ?? "allAnnotated"
            guard let item = ResearchGroup(raw) else {
                throw APIProblem.invalidParameter(
                    "group", "\(raw) is none of allAnnotated, hasNotes, tag.{id}, collection.{id} and highlightColor.{color}.")
            }
            if item == .updated { throw updateReviewNotOffered() }
            let groups = ResearchGroups(sources: try await ResearchSources.read(for: user.id, in: store))
            let entries = groups.documents(for: item)
            let facts = await titleFacts(entries.map { DocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }, provider: provider)
            let items = entries.map { entry in
                ResearchDocument(
                    volumeId: entry.volumeId, documentId: entry.documentId,
                    title: DocumentDisplayTitle.text(facts[entry.id], documentId: entry.documentId),
                    volumeTitle: resources.volume(entry.volumeId)?.title ?? entry.volumeId,
                    annotatedAt: entry.annotationDate.map(UserStoreDate.text),
                    latestNote: entry.latestNote.flatMap { $0.bodyText.isEmpty ? nil : $0.bodyText },
                    noteCount: entry.noteCount, summaryCount: entry.summaryCount, isInVisitPlan: entry.isInVisitPlan,
                    highlights: entry.highlights.prefix(shownHighlights).map {
                        ResearchDocument.Highlight(id: $0.id.uuidString, color: ResearchGroups.color(of: $0).rawValue,
                                                   selectedText: $0.selectedText)
                    },
                    highlightCount: entry.highlights.count,
                    tags: groups.tagRows(entry).map { ResearchDocument.Named(id: $0.id.uuidString, name: $0.name) },
                    collections: groups.collectionRows(entry).map {
                        ResearchDocument.Named(id: $0.id.uuidString, name: CollectionEditorNaming.listName(savedName: $0.name))
                    })
            }
            return ResearchDocumentList(group: raw, name: groups.name(of: item), total: items.count, items: items)
        }
    }

    /// What the served index holds of each document a list names, for its title, as the app's
    /// `CrossReferenceStore.documentTitleFacts(for:)` reads `document_cache`, an empty head or number
    /// none: nothing while no index is served, or for a document it does not hold.
    static func titleFacts(_ keys: [DocumentKey], provider: ServedIndexProvider) async -> [String: DocumentDisplayTitle.Facts] {
        guard !keys.isEmpty, let served = try? await provider.servedIfReady() else { return [:] }
        var facts: [String: DocumentDisplayTitle.Facts] = [:]
        for (volumeId, documents) in Dictionary(grouping: keys, by: \.volumeId) where served.indexedVolumeIds.contains(volumeId) {
            let wanted = Set(documents.map(\.documentId))
            guard let entries = try? await served.pipeline.documents(forVolume: volumeId) else { continue }
            for entry in entries where wanted.contains(entry.documentId) {
                facts["\(volumeId)/\(entry.documentId)"] = DocumentDisplayTitle.Facts(
                    header: entry.header.isEmpty ? nil : entry.header,
                    documentNumber: entry.documentNumber.flatMap { $0.isEmpty ? nil : $0 },
                    isEditorialNote: entry.isEditorialNote)
            }
        }
        return facts
    }

    /// Changed by an update's list, which reads the index's `reviewed_at`, a column a served index's
    /// reader cannot write: it waits for phase 3's review of changed text.
    static func updateReviewNotOffered() -> APIProblem {
        APIProblem(.conflict, code: "UPDATE_REVIEW_NOT_OFFERED",
                   detail: "Changed by an update lists the documents you annotated that an update changed, for a review of their new text, which this server does not offer yet.")
    }
}
