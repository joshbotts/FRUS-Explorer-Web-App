// What the kit's assembly reads of a collection on this server (PLAN's S18e): the user's store and the
// served index, behind the kit's `CollectionContentDataSource` (upstream #1809), as the app's
// `CollectionContentResolver` reads SwiftData and `AppState`. The store's half is read once, before a
// resolve, as the export's records (`ResearchExport`), since the data source answers it on the main
// actor and at once; the index's half is the served stack's, read as the assembly asks, and none of
// it while no index is served, when the kit resolves bodies from the TEI and citations from the
// manifest alone. A document's parse is the app's on a miss of its cache, `parseDocument`, kept for
// the next resolve (`CollectionDocumentParses`). What only an export does on the app, download its
// volumes, fetch its figures and generate its summaries, a server does not: its volumes and figures
// are the folder an administrator mounts, and it has no summarizer, so a summary only an export would
// generate is refused, as the app refuses one where Apple Intelligence is not.
//
// App code mirrored here, held to its source by CollectionExportParityTests:
// - `ZoteroJSONExporter.fetchTagsAndNotes`'s tags: the names of the document's own tags and of its
//   notes' tags, sorted;
// - `CrossReferenceStore.outboundEdges`: a document's edges that are not broken and name a document.

import FRUSCoreKit
import FRUSLightCore
import Foundation

/// What a resolve reads of one user's store, read at one moment before it starts: the notes every
/// entry's note links resolve against, newest first, as the editor's `@Query(sort: \ResearchNote.lastModified,
/// order: .reverse)` lists them; and their highlights, summaries, tags and the tags' assignments, as
/// the export's records, in the order the store took them, which stands for SwiftData's unsorted
/// fetch, a document's summaries by `SummaryOrder.ranksAbove`.
struct CollectionResearch: Sendable {
    /// Every note, newest first: the fields the assembly reads, as the app's resolver gives them.
    var notes: [ResearchNoteExport]
    /// Each document's highlights, by `volumeId/documentId`.
    var highlights: [String: [DocumentHighlightExport]]
    /// Each document's summaries, headnote drafts among them, newest first, by `volumeId/documentId`.
    var summaries: [String: [GeneratedSummaryExport]]
    /// Every summary, by id: a headnote's chosen one, wherever it is.
    var summariesById: [UUID: GeneratedSummaryExport]
    var tags: [UserTagExport]
    var assignments: [DocumentTagAssignmentExport]
    /// The project the user works in, which an export's title page names where the collection asks
    /// and whose searches its method appendix lists: none in Global Context, or for an id that names
    /// no project, as the app's `activeProject` is none then.
    var activeProject: ProjectExport?

    static func read(for user: String, in store: any UserDataStore) throws -> CollectionResearch {
        let (notes, rows, active) = try (
            store.notes(for: user),
            store.researchRows(for: user, tables: ["highlights", "summaries", "tags", "tag_assignments", "projects"]),
            store.activeProjectId(of: user))
        do {
            var research = CollectionResearch(
                notes: notes.compactMap { note in
                    // `noteValues(_:)`: its identity, its document, its text and its tags; the rest left empty.
                    UUID(uuidString: note.id).map {
                        ResearchNoteExport(id: $0, documentId: note.documentId, volumeId: note.volumeId, bodyText: note.bodyText,
                                           projectIds: [], userTagIds: note.userTagIds.compactMap(UUID.init(uuidString:)),
                                           selectedSummaryIds: [], linkedHighlightIds: [])
                    }
                },
                highlights: [:], summaries: [:], summariesById: [:],
                tags: try ResearchExport.records(rows, "tags", ResearchExport.tag),
                assignments: try ResearchExport.records(rows, "tag_assignments", ResearchExport.assignment),
                activeProject: try active.flatMap { id in
                    try ResearchExport.records(rows, "projects", ResearchExport.project).first { $0.id.uuidString == UserSearchText.uuidString(id) }
                })
            for highlight in try ResearchExport.records(rows, "highlights", ResearchExport.highlight) {
                research.highlights["\(highlight.volumeId)/\(highlight.documentId)", default: []].append(highlight)
            }
            for summary in try ResearchExport.records(rows, "summaries", ResearchExport.summary) {
                research.summaries["\(summary.volumeId)/\(summary.documentId)", default: []].append(summary)
                if research.summariesById[summary.id] == nil { research.summariesById[summary.id] = summary }
            }
            for key in research.summaries.keys { research.summaries[key]?.sort(by: Self.ranksAbove) }
            return research
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The collection's research could not be read: \(error.description)")
        }
    }

    /// `SummaryOrder.ranksAbove` over the export's records.
    static func ranksAbove(_ a: GeneratedSummaryExport, _ b: GeneratedSummaryExport) -> Bool {
        SummaryOrder.ranksAbove(createdAt: (a.createdAt, b.createdAt), lastModified: (a.lastModified, b.lastModified),
                                ids: (a.id.uuidString, b.id.uuidString))
    }

    /// The names a document's Zotero item lists as its tags: `ZoteroJSONExporter.fetchTagsAndNotes`'s,
    /// the names of the tags assigned to it and of its notes' tags, each once, sorted.
    func zoteroTags(volumeId: String, documentId: String) -> [String] {
        let names = Dictionary(tags.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        var tagNames = Set<String>()
        for assignment in assignments where assignment.volumeId == volumeId && assignment.documentId == documentId {
            if let name = names[assignment.tagId] { tagNames.insert(name) }
        }
        for note in notes where note.volumeId == volumeId && note.documentId == documentId {
            for tagId in note.userTagIds {
                if let name = names[tagId] { tagNames.insert(name) }
            }
        }
        return tagNames.sorted()
    }
}

/// The kit's data source for one resolve of one user's collection: the user's research as read before
/// it, and the library: the manifest, the served index when there is one, the TEI folder's documents,
/// its figures' folders and the app's archival indexes.
@MainActor
struct CollectionContentSource: CollectionContentDataSource {
    let research: CollectionResearch
    /// The served index, or nil while none is.
    let served: ServedIndex?
    let resources: ServerResources
    let parses: CollectionDocumentParses

    var manifestEntries: [VolumeManifestEntry] { resources.manifest }

    var indexingPipeline: IndexingPipeline? { served?.pipeline }

    func documentAST(volumeId: String, documentId: String) async -> FRUSDocumentAST? {
        await parses.document(volumeId: volumeId, documentId: documentId)
    }

    func crossReferenceTargets(volumeId: String, documentId: String) async -> [(volumeId: String, documentId: String)]? {
        guard let served else { return nil }
        // As the app's: an edge that cannot be read is none.
        return (try? await Blocking.run { try served.outboundTargets(volumeId: volumeId, documentId: documentId) }) ?? []
    }

    var personMentionStore: PersonMentionStore? { served?.persons }

    var archivalIndexes: ArchivalIndexes { resources.archivalIndexes }

    func highlights(volumeId: String, documentId: String) -> [DocumentHighlightExport] {
        research.highlights["\(volumeId)/\(documentId)"] ?? []
    }

    func summary(id: UUID) -> GeneratedSummaryExport? { research.summariesById[id] }

    func headnoteSummaries(volumeId: String, documentId: String) -> [GeneratedSummaryExport] {
        // A record with no flag, from a file before format 7, is the model's default: no draft.
        (research.summaries["\(volumeId)/\(documentId)"] ?? []).filter { $0.isHeadnoteDraft != true }
    }

    func summary(volumeId: String, documentId: String, promptId: UUID) -> GeneratedSummaryExport? {
        research.summaries["\(volumeId)/\(documentId)"]?.first { $0.promptId == promptId }
    }

    func zoteroTags(volumeId: String, documentId: String) -> [String] {
        research.zoteroTags(volumeId: volumeId, documentId: documentId)
    }

    func userTags() -> [UserTagExport] { research.tags }

    func tagAssignments() -> [DocumentTagAssignmentExport] { research.assignments }

    /// A smart collection's saved search is S18f's to run; the routes refuse one before it resolves.
    func smartDocumentRefs() async throws -> [SmartCollectionDocumentRef] {
        throw CollectionRoutes.smartWaits()
    }

    /// Nothing to download: the server's volumes are the folder it is given.
    func prepareVolumesForExport(_ volumeIds: Set<String>) async {}

    /// Nothing to fetch: a figure the folder lacks prints its placeholder.
    func fetchAbsentFigureImages(_ images: [FigureImageName]) async {}

    /// The stored summary of each document under `promptId`, as the app's `resolveSummaries` checks for
    /// one first; this server generates none, so a document with none fails the export as the app's
    /// does where Apple Intelligence is not there to write one (`ExportError.renderingFailed`).
    func generateSummaries(for documents: [CollectionExportDocument], promptId: UUID,
                           bodyTexts: [String: String]) async throws -> [String: String] {
        var result: [String: String] = [:]
        for document in documents {
            guard let stored = summary(volumeId: document.volumeId, documentId: document.documentId, promptId: promptId),
                  !stored.responseText.isEmpty else { throw ExportError.renderingFailed }
            result["\(document.volumeId)/\(document.documentId)"] = stored.responseText
        }
        return result
    }
}

/// The documents collections resolve, parsed as the app's resolver parses one its cache misses
/// (`FRUSDocumentParser.parseDocument`), and the most recent kept, as its `DocumentASTCache` keeps
/// them, so a preview resolved again after an edit parses nothing again. A volume whose file changes,
/// by size or modification time, is parsed again; requests for a document being parsed wait for it.
/// Only a manifest volume's file is opened, so nothing a store holds is joined into a path.
actor CollectionDocumentParses {
    let volumesDirectory: URL
    let resources: ServerResources
    /// How many documents are kept: more than the preview's 20, as the app keeps its cap under its
    /// cache's 24, so a capped preview resolved again finds each of its documents here.
    let capacity: Int
    private var held: [String: (signature: ReaderService.FileSignature, ast: FRUSDocumentAST?)] = [:]
    /// Keys of `held`, least recently used first.
    private var recency: [String] = []
    private var parsing: [String: Task<FRUSDocumentAST?, Never>] = [:]
    /// How many parses have started, for the tests.
    private(set) var parseCount = 0

    init(volumesDirectory: URL, resources: ServerResources, capacity: Int = 48) {
        self.volumesDirectory = volumesDirectory
        self.resources = resources
        self.capacity = max(1, capacity)
    }

    /// The document's parse, or nil when its volume is not in the manifest or the folder, or holds no
    /// such document, or will not parse: the preview's citation-only card, as for a volume not
    /// downloaded on the app.
    func document(volumeId: String, documentId: String) async -> FRUSDocumentAST? {
        guard resources.volume(volumeId) != nil, let url = ReaderService.teiFile(for: volumeId, in: volumesDirectory) else {
            return nil
        }
        let key = "\(volumeId)/\(documentId)"
        let signature = ReaderService.signature(of: url)
        if let kept = held[key], kept.signature == signature {
            touch(key)
            return kept.ast
        }
        if let running = parsing[key] { return await running.value }
        parseCount += 1
        let task = Task<FRUSDocumentAST?, Never> {
            try? await FRUSDocumentParser().parseDocument(documentId: documentId, volumeURL: url)
        }
        parsing[key] = task
        let ast = await task.value
        parsing[key] = nil
        held[key] = (signature, ast)
        touch(key)
        while recency.count > capacity { held[recency.removeFirst()] = nil }
        return ast
    }

    private func touch(_ key: String) {
        recency.removeAll { $0 == key }
        recency.append(key)
    }
}

/// The figure images an export embeds, from the TEI folder's `<volumeId>.figures/`, where the reader
/// serves them from and FRUS Explorer keeps them: the app's `FigureImageStore`, for a manifest volume's
/// images only. One the folder lacks prints its placeholder.
struct ServedFigureImages: FigureImageSource {
    let volumesDirectory: URL
    let resources: ServerResources

    func data(for image: FigureImageName) -> Data? {
        guard let volumeId = image.volumeId, resources.volume(volumeId) != nil, let file = image.fileName,
              FRUSURLScheme.isSafeComponent(volumeId), FRUSURLScheme.isSafeComponent(file),
              let url = ReaderRoutes.figureFile(volumeId: volumeId, file: file, in: volumesDirectory) else { return nil }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }
}

extension ServedIndex {
    /// `CrossReferenceStore.outboundEdges(forDocumentId:volumeId:)`'s query, app code: a document's edges
    /// that are not broken and whose target is a document, a reference to a whole volume being none
    /// (`namesADocumentPredicate`), with a target in its own volume named by it.
    static let outboundEdgesQuery = """
        SELECT COALESCE(target_volume_id, source_volume_id) AS resolved_target_volume, target_document_id
        FROM cross_references
        WHERE source_document_id = ?
          AND source_volume_id = ?
          AND is_broken = 0
          AND target_document_id != ''
        """

    /// The documents a document's outbound cross-references name, in the index's order, for the "See
    /// also:" line, which keeps those the collection holds.
    func outboundTargets(volumeId: String, documentId: String) throws -> [(volumeId: String, documentId: String)] {
        try references.query(Self.outboundEdgesQuery, [.text(documentId), .text(volumeId)]).compactMap { row in
            guard let volume = row[0].text, let document = row[1].text else { return nil }
            return (volumeId: volume, documentId: document)
        }
    }
}
