// The Research page (PLAN's S19b), as the app's `ResearchView` shows it: every document the user has
// annotated, with a note, a tag, a collection entry, a highlight, a summary or a place in a visit plan,
// as the kit's `ResearchDocumentAggregation` gathers them (S17b's FRUS-Explorer#1805); the documents
// a note is on, every note's count, and the documents of each collection, tag and highlight colour;
// and each document's row. Read once a request from the store, the rows the export reads with the
// few columns the page reads of them. What the kit holds is called: the six sources' union, a
// collection's distinct documents, the kinds of entry that count and the summaries a row may name.
// What the app's view computes for itself is a few lines of view code, mirrored here, held to its
// source by ResearchPageParityTests:
// - `documentsWithNotesCount`, `directlyTaggedDocs` and `collectionMemberships`;
// - the three sections, `sortedCollectionsWithCounts`, `sortedTagsWithCounts` and
//   `sortedHighlightColorsWithCounts`, with `DocumentHighlight.color`'s reading of a colour;
// - `documents(for:)`, which documents a category lists and each row's facts, with their order;
// - the row's newest annotation, its three highlights, and its tags' and collections' order;
// - `CrossReferenceStore.documentTitleFacts(for:)`, the served index's query for a row's title, with
//   `documentChunks`, its ids by volume, each once, 400 to a query.
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

/// What the page reads of one user's store at one moment: the rows the export reads of the six sources
/// the kit's aggregation reads and of the tags, with the columns the page reads of them, as values.
struct ResearchSources: Sendable {
    /// A note's identity, document, text, tags and last change.
    struct Note: Sendable {
        var id: UUID
        var volumeId: String
        var documentId: String
        var bodyText: String
        var userTagIds: [UUID]
        var lastModified: Date?
    }

    struct Tag: Sendable {
        var id: UUID
        var name: String
    }

    /// A direct document-tag assignment.
    struct Assignment: Sendable {
        var volumeId: String
        var documentId: String
        var tagId: UUID
    }

    /// A collection, with its entries as the kit's rules read them.
    struct Collection: Sendable {
        var id: UUID
        var name: String
        var savedSearchId: UUID?
        var entries: [ResearchDocumentAggregation.Entry]
    }

    struct Highlight: Sendable {
        var id: UUID
        var volumeId: String
        var documentId: String
        var colorTag: String
        var selectedText: String
        var createdAt: Date?
    }

    var notes: [Note]
    var tags: [Tag]
    var tagAssignments: [Assignment]
    var collections: [Collection]
    var highlights: [Highlight]
    /// Every summary, headnote drafts among them, as the kit's rules read them.
    var summaries: [ResearchDocumentAggregation.Summary]
    /// Every visit plan's documents, as their `documentKey`s.
    var visitDocumentKeys: [String]

    /// The columns read of each table: a collection's entries those the kit's rules read, and a
    /// summary's its document and whether it is a headnote draft, never its text.
    static let columns: [String: Set<String>] = [
        "notes": ["id", "volume_id", "document_id", "body_text", "user_tag_ids", "last_modified"],
        "tags": ["id", "name"],
        "tag_assignments": ["volume_id", "document_id", "tag_id"],
        "collections": ["id", "name", "saved_search_id"],
        "collection_entries": ["collection_id", "kind", "volume_id", "document_id"],
        "highlights": ["id", "volume_id", "document_id", "color_tag", "selected_text", "created_at"],
        "summaries": ["volume_id", "document_id", "is_headnote_draft"],
        "visit_documents": ["document_key"],
    ]

    static func read(for user: String, in store: any UserDataStore) async throws -> ResearchSources {
        let rows = try await Blocking.run { try store.researchRows(for: user, columns: columns) }
        do {
            let fields = { (table: String) in rows[table].map { ResearchExport.Fields(table, $0) } }
            var entries: [UUID: [ResearchDocumentAggregation.Entry]] = [:]
            for entry in fields("collection_entries") {
                entries[try entry.uuid("collection_id"), default: []].append(ResearchDocumentAggregation.Entry(
                    kind: try entry.text("kind"), volumeId: try entry.text("volume_id"), documentId: try entry.text("document_id")))
            }
            return ResearchSources(
                notes: try fields("notes").map {
                    Note(id: try $0.uuid("id"), volumeId: try $0.text("volume_id"), documentId: try $0.text("document_id"),
                         bodyText: try $0.text("body_text"), userTagIds: try $0.uuids("user_tag_ids"),
                         lastModified: try $0.optionalDate("last_modified"))
                },
                tags: try fields("tags").map { Tag(id: try $0.uuid("id"), name: try $0.text("name")) },
                tagAssignments: try fields("tag_assignments").map {
                    Assignment(volumeId: try $0.text("volume_id"), documentId: try $0.text("document_id"), tagId: try $0.uuid("tag_id"))
                },
                collections: try fields("collections").map {
                    let id = try $0.uuid("id")
                    return Collection(id: id, name: try $0.text("name"), savedSearchId: try $0.optionalUUID("saved_search_id"),
                                      entries: entries[id] ?? [])
                },
                highlights: try fields("highlights").map {
                    Highlight(id: try $0.uuid("id"), volumeId: try $0.text("volume_id"), documentId: try $0.text("document_id"),
                              colorTag: try $0.text("color_tag"), selectedText: try $0.text("selected_text"),
                              createdAt: try $0.optionalDate("created_at"))
                },
                summaries: try fields("summaries").map {
                    ResearchDocumentAggregation.Summary(volumeId: try $0.text("volume_id"), documentId: try $0.text("document_id"),
                                                        isHeadnoteDraft: try $0.bool("is_headnote_draft"))
                },
                visitDocumentKeys: try fields("visit_documents").map { try $0.text("document_key") })
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
        let latestNote: ResearchSources.Note?
        let noteCount: Int
        var summaryCount: Int = 0
        var isInVisitPlan: Bool = false
        /// The tags of its notes and its own.
        let allTagIds: Set<UUID>
        let collectionIds: Set<UUID>
        /// Newest first.
        let highlights: [ResearchSources.Highlight]

        /// The row's date: its newest annotation's, the later of its newest note's and its newest
        /// highlight's.
        var annotationDate: Date? {
            [latestNote?.lastModified, highlights.first?.createdAt].compactMap { $0 }.max()
        }
    }

    // MARK: The kit's

    /// Every document carrying any annotation, across the six sources: the kit's
    /// `annotatedKeys(among:)` over the records' values, as the app's overload passes its models'.
    var allAnnotatedKeys: Set<String> {
        ResearchDocumentAggregation.annotatedKeys(among: ResearchDocumentAggregation.Sources(
            notes: sources.notes.map { ResearchDocumentAggregation.DocumentRef(volumeId: $0.volumeId, documentId: $0.documentId) },
            tagAssignments: sources.tagAssignments.map {
                ResearchDocumentAggregation.DocumentRef(volumeId: $0.volumeId, documentId: $0.documentId)
            },
            collections: sources.collections.map(\.entries),
            highlights: sources.highlights.map { ResearchDocumentAggregation.DocumentRef(volumeId: $0.volumeId, documentId: $0.documentId) },
            summaries: sources.summaries,
            visitDocumentKeys: sources.visitDocumentKeys))
    }

    /// Summary counts by document key, drafts left out: the kit's `summaryCounts(among:)`.
    var summarizedDocs: [String: Int] {
        ResearchDocumentAggregation.summaryCounts(among: sources.summaries)
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
                guard ResearchDocumentAggregation.countsAsAnnotation(entry.kind) else { continue }
                guard !entry.volumeId.isEmpty, !entry.documentId.isEmpty else { continue }
                result["\(entry.volumeId)/\(entry.documentId)", default: []].insert(collection.id)
            }
        }
        return result
    }

    /// The collections, but smart ones and those with no document, each with its distinct documents, by
    /// the name each row prints, then by id.
    var sortedCollectionsWithCounts: [(collection: ResearchSources.Collection, count: Int)] {
        sources.collections.compactMap { collection in
            // Exclude smart collections — their document list is dynamic, not curated entries.
            guard collection.savedSearchId == nil else { return nil }
            let count = ResearchDocumentAggregation.distinctDocumentKeys(among: collection.entries).count
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
    var sortedTagsWithCounts: [(tag: ResearchSources.Tag, count: Int)] {
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
    static func color(of highlight: ResearchSources.Highlight) -> HighlightColor {
        HighlightColor(rawValue: highlight.colorTag) ?? .yellow
    }

    /// The documents named by any visit plan.
    var visitPlanDocs: Set<String> {
        Set(sources.visitDocumentKeys.filter { !$0.isEmpty })
    }

    /// Each document's highlights, in the store's order.
    var highlightedDocs: [String: [ResearchSources.Highlight]] {
        var result: [String: [ResearchSources.Highlight]] = [:]
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
        var grouped: [String: [ResearchSources.Note]] = [:]
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
            let facts = await titleFacts(entries.map { (volumeId: $0.volumeId, documentId: $0.documentId) }, provider: provider)
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

    /// What the served index holds of each document a list names, for its title: the app's
    /// `documentTitleFacts(for:)`, nothing while no index is served or for a document it does not hold.
    static func titleFacts(_ keys: [(volumeId: String, documentId: String)], provider: ServedIndexProvider) async
        -> [String: DocumentDisplayTitle.Facts] {
        guard !keys.isEmpty, let served = try? await provider.servedIfReady() else { return [:] }
        return (try? await Blocking.run { try served.documentTitleFacts(for: keys) }) ?? [:]
    }

    /// Changed by an update's list, which reads the index's `reviewed_at`, a column a served index's
    /// reader cannot write: it waits for phase 3's review of changed text.
    static func updateReviewNotOffered() -> APIProblem {
        APIProblem(.conflict, code: "UPDATE_REVIEW_NOT_OFFERED",
                   detail: "Changed by an update lists the documents you annotated that an update changed, for a review of their new text, which this server does not offer yet.")
    }
}

extension ServedIndex {
    /// `CrossReferenceStore.documentTitleFacts(for:)`, app code: what a display title needs of each
    /// document, one query for each volume's ids, 400 at a time, a head or a number that is empty none.
    /// A key's presence says the index holds the document.
    func documentTitleFacts(for keys: [(volumeId: String, documentId: String)]) throws -> [String: DocumentDisplayTitle.Facts] {
        var result: [String: DocumentDisplayTitle.Facts] = [:]
        for (volumeId, documentIds) in Self.documentChunks(keys) {
            let sql = """
                SELECT document_id, header, document_number, is_editorial_note
                  FROM document_cache
                 WHERE volume_id = ? AND document_id IN (\(Array(repeating: "?", count: documentIds.count).joined(separator: ", ")))
                """
            for row in try references.query(sql, [.text(volumeId)] + documentIds.map { .text($0) }) {
                guard let doc = row[0].text else { continue }
                let head = row[1].text.flatMap { $0.isEmpty ? nil : $0 }
                let number = row[2].text.flatMap { $0.isEmpty ? nil : $0 }
                result["\(volumeId)/\(doc)"] = DocumentDisplayTitle.Facts(header: head, documentNumber: number,
                                                                          isEditorialNote: (row[3].integer ?? 0) != 0)
            }
        }
        return result
    }

    /// How many document ids ride in one `IN (…)` list: the app's `documentChunkSize`.
    static let documentChunkSize = 400

    /// `CrossReferenceStore.documentChunks(_:)`, app code: the keys by volume, in the order each volume
    /// first comes, each key once, its ids `documentChunkSize` at a time.
    static func documentChunks(_ keys: [(volumeId: String, documentId: String)]) -> [(volumeId: String, documentIds: [String])] {
        var byVolume: [String: [String]] = [:]
        var order: [String] = []
        var seen: Set<String> = []
        for (vol, doc) in keys where seen.insert("\(vol)/\(doc)").inserted {
            if byVolume[vol] == nil { order.append(vol) }
            byVolume[vol, default: []].append(doc)
        }
        var out: [(volumeId: String, documentIds: [String])] = []
        for volumeId in order {
            let ids = byVolume[volumeId] ?? []
            for start in stride(from: 0, to: ids.count, by: documentChunkSize) {
                out.append((volumeId, Array(ids[start..<min(start + documentChunkSize, ids.count)])))
            }
        }
        return out
    }
}
