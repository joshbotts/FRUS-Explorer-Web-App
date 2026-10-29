// What the kit's assembly reads of a collection on this server (PLAN's S18e): the user's store and the
// served index, behind the kit's `CollectionContentDataSource` (upstream #1809), as the app's
// `CollectionContentResolver` reads SwiftData and `AppState`. The store's half is read once, before a
// resolve, as the export's records (`ResearchExport`), since the data source answers it on the main
// actor and at once; the index's half is the served stack's, read as the assembly asks, and none of
// it while no index is served, when the kit resolves bodies from the TEI and citations from the
// manifest alone. A document is taken from one pass of its volume, the reader's, which builds it as the
// app's parse of it alone does, and a section is parsed alone, as the app parses one, each kept for the
// next resolve (`CollectionDocumentParses`). What only an export does on the app, download its
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
    /// The user's summary prompts, which Summary only's must be one of, as the app fetches its prompt.
    var promptIds: Set<UUID>

    static func read(for user: String, in store: any UserDataStore) throws -> CollectionResearch {
        let (notes, rows, active, prompts) = try (
            store.notes(for: user),
            store.researchRows(for: user, tables: ["highlights", "summaries", "tags", "tag_assignments", "projects"]),
            store.activeProjectId(of: user), store.prompts(for: user))
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
                },
                promptIds: Set(prompts.keys.compactMap(UUID.init(uuidString:))))
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
    /// The resolve's documents, by volume, each volume's read in one pass when the first is asked for.
    let batch: CollectionDocumentBatch

    var manifestEntries: [VolumeManifestEntry] { resources.manifest }

    var indexingPipeline: IndexingPipeline? { served?.pipeline }

    func documentAST(volumeId: String, documentId: String) async -> FRUSDocumentAST? {
        await batch.document(volumeId: volumeId, documentId: documentId, from: parses)
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

    /// The summaries the app's `resolveSummaries` takes, those stored, where it can write the rest: the
    /// prompt must still be the user's, as the app fetches it first, and each document must have one
    /// stored under it, since this server writes none. Either missing fails the export as the app's
    /// fails where it cannot write one (`ExportError.renderingFailed`); without Apple Intelligence the
    /// app refuses every Summary only export, stored summaries and all.
    func generateSummaries(for documents: [CollectionExportDocument], promptId: UUID,
                           bodyTexts: [String: String]) async throws -> [String: String] {
        guard research.promptIds.contains(promptId) else { throw ExportError.renderingFailed }
        var result: [String: String] = [:]
        for document in documents {
            guard let stored = summary(volumeId: document.volumeId, documentId: document.documentId, promptId: promptId),
                  !stored.responseText.isEmpty else { throw ExportError.renderingFailed }
            result["\(document.volumeId)/\(document.documentId)"] = stored.responseText
        }
        return result
    }
}

/// The documents of one resolve: those its document entries name, by volume, and the parses of each
/// volume's, asked of `CollectionDocumentParses` all at once when the assembly first asks for one of
/// them, and kept for the rest of the resolve.
@MainActor
final class CollectionDocumentBatch {
    /// Each volume's documents the resolve's document entries name.
    let wanted: [String: Set<String>]
    private var parsed: [String: [String: FRUSDocumentAST]] = [:]

    init(_ entries: [CollectionContentAssembly.Entry]) {
        var wanted: [String: Set<String>] = [:]
        for entry in entries where entry.kind == .document && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {
            wanted[entry.volumeId, default: []].insert(entry.documentId)
        }
        self.wanted = wanted
    }

    func document(volumeId: String, documentId: String, from parses: CollectionDocumentParses) async -> FRUSDocumentAST? {
        if let held = parsed[volumeId], wanted[volumeId]?.contains(documentId) == true { return held[documentId] }
        let documents = await parses.documents(volumeId: volumeId, documentIds: (wanted[volumeId] ?? []).union([documentId]))
        parsed[volumeId, default: [:]].merge(documents) { _, new in new }
        return documents[documentId]
    }
}

/// The documents collections resolve, parsed as the app's resolver has them parsed, and the most
/// recent kept, as its `DocumentASTCache` keeps them, so a preview resolved again after an edit parses
/// nothing again. A `<div type="document">` is taken from one pass of its volume, the reader's own
/// (`ReaderService`), which builds each document as the parser builds one asked for alone, since the
/// page breaks a container leaves go to the next section, never to a document (`finishParse()`), and
/// which the app's reader caches for its exports to read too (`parseDocumentWindow`); anything else, a
/// section or a division of front matter, which that pass gives the breaks it carries, is parsed alone,
/// as the app parses one its cache misses (`FRUSDocumentParser.parseDocument`). So the cost of a
/// collection is a pass of each of its volumes, never one for each document. A volume whose file
/// changes, by size or modification time, is read again. Only a manifest volume's file is opened, so
/// nothing a store holds is joined into a path.
actor CollectionDocumentParses {
    let reader: ReaderService
    let resources: ServerResources
    /// How many documents are kept: more than the preview's 20, as the app keeps its cap under its
    /// cache's 24, and more than most collections hold, so one resolved again finds its documents here.
    let capacity: Int
    private var held: [String: (signature: ReaderService.FileSignature, ast: FRUSDocumentAST?)] = [:]
    /// Keys of `held`, least recently used first.
    private var recency: [String] = []
    /// How many divisions have been parsed alone, and how many volumes asked of the reader, for the tests.
    private(set) var parseCount = 0
    private(set) var volumeCount = 0

    init(reader: ReaderService, resources: ServerResources, capacity: Int = 256) {
        self.reader = reader
        self.resources = resources
        self.capacity = max(1, capacity)
    }

    /// The parses of a volume's `documentIds` that are there: none when the volume is not in the
    /// manifest or the folder, or holds no such division, or will not parse, which the preview shows as
    /// its citation card, as the app's shows a volume not downloaded.
    func documents(volumeId: String, documentIds: Set<String>) async -> [String: FRUSDocumentAST] {
        guard resources.volume(volumeId) != nil, let url = ReaderService.teiFile(for: volumeId, in: reader.volumesDirectory) else {
            return [:]
        }
        let signature = ReaderService.signature(of: url)
        var found: [String: FRUSDocumentAST] = [:]
        var missing: [String] = []
        for id in documentIds.sorted() {
            if let kept = held[Self.key(volumeId, id)], kept.signature == signature {
                touch(Self.key(volumeId, id))
                if let ast = kept.ast { found[id] = ast }
            } else {
                missing.append(id)
            }
        }
        guard !missing.isEmpty else { return found }
        volumeCount += 1
        let pass = try? await reader.volume(volumeId)
        let divisions = pass.map { Set($0.structure.flatMap(Self.documentIds)) } ?? []
        for id in missing {
            let ast: FRUSDocumentAST?
            if let pass, pass.signature == signature, divisions.contains(id) {
                ast = pass.documents[id]
            } else {
                parseCount += 1
                ast = try? await FRUSDocumentParser().parseDocument(documentId: id, volumeURL: url)
            }
            held[Self.key(volumeId, id)] = (signature, ast)
            touch(Self.key(volumeId, id))
            if let ast { found[id] = ast }
        }
        while recency.count > capacity { held[recency.removeFirst()] = nil }
        return found
    }

    /// The ids of the `<div type="document">`s a section holds, and those of its sections.
    private static func documentIds(_ section: VolumeSection) -> [String] {
        section.documentIds + section.subsections.flatMap(documentIds)
    }

    private static func key(_ volumeId: String, _ documentId: String) -> String { "\(volumeId)/\(documentId)" }

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
