// A Mac JSON export as the user store imports it (PLAN's S16c): the file decoded with the kit's own
// envelope and decoder, of any format version from 1 to 7, and each of its records mapped to its
// table's row, the columns its format version carries as values and the rest as the app's defaults,
// which only a new row takes (`ImportRow`). What the store did with them, and what the file held,
// make the report, per model type.
//
// What the mapping decides, where an older file does not say:
// - a summary is a collection's headnote draft when its prompt is the app's headnote prompt, as every
//   draft the app makes carries it, in a file before version 7, which has no flag;
// - an entry with no document in a file before version 7, a heading, a prose block or an apparatus
//   block there, is kept as a kind the app does not know, which it reads as inert;
// - a collection's saved search is kept as the file names it, so one whose search the store lacks
//   reads as the app's does when its search was deleted, and the report names it;
// - the store keeps one set of synced settings per user, the earliest made, as the app reads them;
// - the two corrections are the instance's, imported only for a curator.

import FRUSCoreKit
import FRUSLightCore
import FRUSRichText
import FTS5Store
import Foundation

/// What a Mac JSON export brought to the store: for each model type, what the file held and what
/// became of it, and what the import made of what an older file does not say.
public struct ResearchImportReport: Codable, Equatable, Sendable {
    /// The file's `formatVersion`, and when the Mac wrote it.
    public var formatVersion: Int
    public var exportedAt: String
    /// Each of the 23 model types, in the user store's order.
    public var types: [ImportTypeCount]
    /// The file's notes that carry their formatting, RTF, as files of version 7 do.
    public var formattedNotes: Int
    /// Of those, the notes whose RTF the codec cannot offer, which open as plain text until their
    /// body is edited on the web, their RTF kept as it came (`Note.formattingKept`).
    public var formattingKept: Int
    /// The file's summaries that are a collection's headnote draft, which no list or search shows.
    public var headnoteDrafts: Int
    /// The file's summaries with no authorship, from a file before version 5, read as AI summaries.
    public var summariesWithoutAuthorship: Int
    /// The collection entries with no document in a file before version 7, which did not say what
    /// they were, kept as the app keeps a kind it does not know: inert.
    public var inertEntries: Int
    /// The file's collections that name a saved search the store does not hold, as the app shows one
    /// whose search was deleted.
    public var unlinkedCollections: [UnlinkedCollection]
    /// How many documents the user's notes and summaries make findable, once `user_search` is made again.
    public var searchableDocuments: Int
}

/// What became of one model type's records.
public struct ImportTypeCount: Codable, Equatable, Sendable {
    /// The app's model type, such as `ResearchNote`.
    public var type: String
    /// Whether a file of this format version can carry the type: one that cannot holds none of it.
    public var carried: Bool
    /// The file's records of the type.
    public var inFile: Int
    /// Records the store did not hold, now written.
    public var added: Int
    /// Records of which the store held an older copy, now the file's.
    public var replaced: Int
    /// Records of which the store held a copy as new or newer, kept.
    public var kept: Int
    /// Records not written: synced settings after the earliest, which the app does not read, and an
    /// instance's corrections, which only a curator imports.
    public var setAside: Int
    /// Records whose id the file already gave, the same record exported twice: one copy is written,
    /// the newest, or of two as new the first, as a copy the store held would be kept.
    public var repeated: Int
}

/// A file the import cannot read.
public enum MacImportError: Error, Equatable, CustomStringConvertible {
    /// Not a research export at all.
    case notAnExport(String)
    /// A format version the kit's decoder does not read.
    case unsupportedVersion(Int)
    /// An export whose records do not decode.
    case undecodable(String)

    var problem: APIProblem {
        switch self {
        case .notAnExport(let detail):
            APIProblem(.badRequest, code: "INVALID_EXPORT",
                       detail: "This is not a FRUS Explorer research export, the file Settings ▸ Data & Recovery ▸ Export as JSON writes: \(detail)")
        case .unsupportedVersion(let version):
            APIProblem(.badRequest, code: "UNSUPPORTED_FORMAT_VERSION",
                       detail: "This export is format version \(version), and this server reads versions \(MacImport.formatVersions.lowerBound) to \(MacImport.formatVersions.upperBound). Update the server, then import it again.")
        case .undecodable(let detail):
            APIProblem(.badRequest, code: "INVALID_EXPORT", detail: "This export could not be read: \(detail)")
        }
    }

    public var description: String { problem.detail }
}

/// The import's mapping, public for the parity harness, which imports an export it is given as the
/// route's job does (`frus-parity import-check`).
public enum MacImport {
    /// The format versions the kit's decoder reads.
    static let formatVersions = 1...ResearchDataEnvelope.currentFormatVersion

    /// The prompt id every headnote draft carries: the app's `headnoteDraftPromptId`, in
    /// `CollectionEntryInspector`, which `GeneratedSummary.duplicateHeadnoteDraft` copies.
    static let headnoteDraftPromptId = "0EAD0000-0000-4000-8000-000000000001"

    /// The kind a version-6 entry with no document is kept as: one the app does not know, which its
    /// `CollectionEntry.entryKind` reads as `.unrecognized`, an inert row.
    static let inertKind = "unrecognized"

    /// The model types, each with its table and the first format version that carries it.
    static let types: [(model: String, table: String, since: Int)] = [
        ("ResearchNote", "notes", 1), ("DocumentHighlight", "highlights", 1), ("UserTag", "tags", 1),
        ("DocumentTagAssignment", "tag_assignments", 1), ("Collection", "collections", 1),
        ("CollectionEntry", "collection_entries", 1), ("Project", "projects", 1), ("ProjectLeadEntry", "project_leads", 7),
        ("SavedSearch", "saved_searches", 7), ("WorkingCorpus", "working_corpora", 7), ("CustomVolumeScope", "volume_scopes", 7),
        ("ReadingHistoryEntry", "trail_reading", 3), ("SearchHistoryEntry", "trail_search", 3),
        ("ExportHistoryEntry", "trail_export", 3), ("ArchiveVisitPlan", "visit_plans", 6),
        ("ArchiveVisitDocument", "visit_documents", 6), ("ArchiveVisitTarget", "visit_targets", 6),
        ("GeneratedSummary", "summaries", 1), ("SummarizationPrompt", "prompts", 1),
        ("AnnotationReview", "annotation_reviews", 7), ("SyncedPreferences", "preferences", 7),
        ("PersonClusterOverride", "person_overrides", 7), ("DocumentClassificationOverride", "classification_overrides", 7),
    ]

    // MARK: Reading the file

    /// The file's `formatVersion`, read before the rest, so that a file that is not an export, or of a
    /// version the server does not read, is refused at once.
    static func formatVersion(of data: Data) throws -> Int {
        struct Head: Decodable { let formatVersion: Int }
        let head: Head
        do {
            head = try JSONDecoder().decode(Head.self, from: data)
        } catch DecodingError.keyNotFound {
            throw MacImportError.notAnExport("it holds no formatVersion.")
        } catch DecodingError.typeMismatch(_, let context) where !context.codingPath.isEmpty {
            throw MacImportError.notAnExport("its formatVersion is not a whole number.")
        } catch DecodingError.valueNotFound(_, let context) where !context.codingPath.isEmpty {
            throw MacImportError.notAnExport("its formatVersion is not a whole number.")
        } catch DecodingError.dataCorrupted(let context) where !context.codingPath.isEmpty {
            throw MacImportError.notAnExport("its formatVersion is not a whole number.")
        } catch {
            throw MacImportError.notAnExport("it is not a JSON object.")
        }
        if head.formatVersion > formatVersions.upperBound { throw MacImportError.unsupportedVersion(head.formatVersion) }
        guard formatVersions.contains(head.formatVersion) else {
            throw MacImportError.notAnExport("its formatVersion, \(head.formatVersion), is none the app writes.")
        }
        return head.formatVersion
    }

    /// The file, decoded as the kit decodes an export, with its tolerant decoder.
    public static func envelope(of data: Data) throws -> ResearchDataEnvelope {
        let version = try formatVersion(of: data)
        do {
            let envelope = try ResearchDataEnvelope.makeDecoder().decode(ResearchDataEnvelope.self, from: data)
            precondition(envelope.formatVersion == version)
            return envelope
        } catch let error as DecodingError {
            throw MacImportError.undecodable(describe(error))
        }
    }

    /// Where a decoding error is, as a path through the file such as `notes[2].bodyText`, and what.
    static func describe(_ error: DecodingError) -> String {
        func path(_ codingPath: [any CodingKey]) -> String {
            let path = codingPath.reduce(into: "") { path, key in
                if let index = key.intValue { path += "[\(index)]" } else { path += path.isEmpty ? key.stringValue : ".\(key.stringValue)" }
            }
            return path.isEmpty ? "the file" : path
        }
        switch error {
        case .keyNotFound(let key, let context): return "\(path(context.codingPath + [key])) is missing."
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            return "\(path(context.codingPath)): \(context.debugDescription)"
        @unknown default: return String(describing: error)
        }
    }

    // MARK: Importing

    /// Imports `envelope` into `store` under `user` in one transaction, and reports it.
    public static func run(_ envelope: ResearchDataEnvelope, into store: any ResearchImportStore, for user: String,
                           includingInstanceWide: Bool) throws -> ResearchImportReport {
        let prepared = prepare(envelope, includingInstanceWide: includingInstanceWide)
        let result = try store.importResearch(prepared.batch, for: user)
        let types = Self.types.map { type in
            let count = result.counts[type.table] ?? ImportCount()
            return ImportTypeCount(type: type.model, carried: envelope.formatVersion >= type.since,
                                   inFile: prepared.inFile[type.table] ?? 0, added: count.added, replaced: count.replaced,
                                   kept: count.kept, setAside: prepared.setAside[type.table] ?? 0,
                                   repeated: prepared.repeated[type.table] ?? 0)
        }
        let formatted = envelope.notes.filter { $0.richText != nil }
        let kept = formatted.filter { note in
            NoteFormatting.runs(of: NoteRecord(
                id: note.id.uuidString, volumeId: note.volumeId, documentId: note.documentId, bodyText: note.bodyText,
                richText: note.richText.map(Array.init), projectIds: [], userTagIds: [], selectedSummaryIds: [],
                createdAt: nil, lastModified: nil)).kept
        }
        return ResearchImportReport(
            formatVersion: envelope.formatVersion, exportedAt: UserStoreDate.text(envelope.exportedAt), types: types,
            formattedNotes: formatted.count, formattingKept: kept.count,
            headnoteDrafts: envelope.summaries.filter { isHeadnoteDraft($0, version: envelope.formatVersion) }.count,
            summariesWithoutAuthorship: envelope.summaries.filter { $0.authorship == nil }.count,
            inertEntries: envelope.formatVersion >= 7 ? 0 : envelope.collections.flatMap(\.entries).filter(\.documentId.isEmpty).count,
            unlinkedCollections: result.unlinkedCollections, searchableDocuments: result.searchableDocuments)
    }

    /// The file's rows, one for each id, with how many records of each table it held, how many are set
    /// aside and how many repeat an id it already gave.
    struct Prepared {
        var batch = ResearchImportBatch()
        var inFile: [String: Int] = [:]
        var setAside: [String: Int] = [:]
        var repeated: [String: Int] = [:]

        /// A table's rows in the file's order. A row whose id the file gave before is counted as a
        /// repeat, and takes the earlier one's place only when it is newer by `ImportStamp`, as it
        /// would replace a copy the store held.
        mutating func add(_ table: String, _ rows: [ImportRow], inFile count: Int? = nil) {
            inFile[table, default: 0] += count ?? rows.count
            var kept = batch.rows[table] ?? []
            var positions: [String: Int] = [:]
            for (index, row) in kept.enumerated() { if let id = row.values["id"]?.text { positions[UserSearchText.uuidString(id)] = index } }
            for row in rows {
                guard let id = row.values["id"]?.text.map(UserSearchText.uuidString) else {
                    kept.append(row)
                    continue
                }
                guard let earlier = positions[id] else {
                    positions[id] = kept.count
                    kept.append(row)
                    continue
                }
                repeated[table, default: 0] += 1
                let time = { (row: ImportRow) in ImportStamp.time(of: { row.values[$0] }, in: table) ?? .distantPast }
                if time(row) > time(kept[earlier]) { kept[earlier] = row }
            }
            batch.rows[table] = kept
        }
    }

    /// The rows of each record in `envelope`, its format version saying which columns it carries.
    static func prepare(_ envelope: ResearchDataEnvelope, includingInstanceWide: Bool) -> Prepared {
        let version = envelope.formatVersion
        var prepared = Prepared()
        prepared.add("notes", envelope.notes.map { note($0, version: version) })
        prepared.add("highlights", envelope.highlights.map(highlight))
        prepared.add("tags", envelope.tags.map(tag))
        prepared.add("tag_assignments", envelope.tagAssignments.map(assignment))
        prepared.add("collections", envelope.collections.map { collection($0, version: version) })
        prepared.add("collection_entries", envelope.collections.flatMap { collection in
            collection.entries.map { entry($0, of: collection, version: version) }
        })
        prepared.add("projects", envelope.projects.map { project($0, version: version) })
        prepared.add("project_leads", envelope.projectLeads.map(lead))
        prepared.add("saved_searches", envelope.savedSearches.map(savedSearch))
        prepared.add("working_corpora", envelope.workingCorpora.map(corpus))
        prepared.add("volume_scopes", envelope.customVolumeScopes.map(scope))
        prepared.add("trail_reading", envelope.readingHistory.map(reading))
        prepared.add("trail_search", envelope.searchHistory.map { search($0, version: version) })
        prepared.add("trail_export", envelope.exportHistory.map(exported))
        prepared.add("visit_plans", envelope.archiveVisits.map(plan))
        prepared.add("visit_documents", envelope.archiveVisits.flatMap { plan in plan.documents.map { seed($0, of: plan) } })
        prepared.add("visit_targets", envelope.archiveVisits.flatMap { plan in plan.targets.map { target($0, of: plan) } })
        prepared.add("summaries", envelope.summaries.map { summary($0, version: version) })
        prepared.add("prompts", envelope.prompts.map(prompt))
        prepared.add("annotation_reviews", envelope.annotationReviews.map(review))
        // One set per user, the earliest made, as the app's `SyncedPreferences` reads them; a
        // second device's, which iCloud had not yet merged, is set aside.
        let earliest = envelope.syncedPreferences.enumerated().min {
            ($0.element.createdAt, $0.offset) < ($1.element.createdAt, $1.offset)
        }?.element
        prepared.add("preferences", earliest.map { [preferences($0)] } ?? [], inFile: envelope.syncedPreferences.count)
        prepared.setAside["preferences"] = max(0, envelope.syncedPreferences.count - 1)
        // An instance's corrections change the index every user shares: a curator's to import.
        let corrections = (person: envelope.personClusterOverrides.map(personCorrection),
                           classification: envelope.classificationOverrides.map(classificationCorrection))
        prepared.add("person_overrides", includingInstanceWide ? corrections.person : [], inFile: corrections.person.count)
        prepared.add("classification_overrides", includingInstanceWide ? corrections.classification : [],
                     inFile: corrections.classification.count)
        if !includingInstanceWide {
            prepared.setAside["person_overrides"] = corrections.person.count
            prepared.setAside["classification_overrides"] = corrections.classification.count
        }
        return prepared
    }

    // MARK: Each type's row

    static func note(_ note: ResearchNoteExport, version: Int) -> ImportRow {
        var row = ImportRow(values: [
            "id": uuid(note.id), "document_id": .text(note.documentId), "volume_id": .text(note.volumeId),
            "body_text": .text(note.bodyText), "project_ids": ids(note.projectIds), "user_tag_ids": ids(note.userTagIds),
            "selected_summary_ids": ids(note.selectedSummaryIds), "created_at": date(note.createdAt),
            "last_modified": date(note.lastModified),
        ])
        // The RTF as the Mac wrote it, byte for byte; a note's highlights name it by their noteId,
        // which `linkedHighlightIds` only repeats.
        row.carry(["rich_text": blob(note.richText)], since: 7, in: version, defaults: ["rich_text": .null])
        return row
    }

    static func highlight(_ highlight: DocumentHighlightExport) -> ImportRow {
        ImportRow(values: [
            "id": uuid(highlight.id), "volume_id": .text(highlight.volumeId), "document_id": .text(highlight.documentId),
            "start_offset": int(highlight.startOffset), "end_offset": int(highlight.endOffset), "color_tag": .text(highlight.colorTag),
            "note_id": uuid(highlight.noteId), "selected_text": .text(highlight.selectedText),
            "rendering_version": .text(highlight.renderingVersion), "created_at": date(highlight.createdAt),
        ])
    }

    static func tag(_ tag: UserTagExport) -> ImportRow {
        ImportRow(values: ["id": uuid(tag.id), "name": .text(tag.name), "created_at": date(tag.createdAt),
                           "last_modified": date(tag.lastModified)])
    }

    static func assignment(_ assignment: DocumentTagAssignmentExport) -> ImportRow {
        ImportRow(values: ["id": uuid(assignment.id), "volume_id": .text(assignment.volumeId),
                           "document_id": .text(assignment.documentId), "tag_id": uuid(assignment.tagId),
                           "created_at": date(assignment.createdAt)])
    }

    static func collection(_ collection: CollectionExport, version: Int) -> ImportRow {
        var row = ImportRow(values: [
            "id": uuid(collection.id), "name": .text(collection.name), "note": text(collection.note),
            "project_ids": ids(collection.projectIds), "saved_search_id": uuid(collection.savedSearchId),
            "created_at": date(collection.createdAt), "last_modified": date(collection.lastModified),
        ])
        row.carry(collectionSettings(collection), since: 7, in: version, defaults: collectionSettings(nil))
        return row
    }

    /// A collection's front matter, composition and settings, or for nil the app's defaults: each
    /// stored property's initial value in `Collection`.
    static func collectionSettings(_ collection: CollectionExport?) -> [String: SQLiteValue] {
        [
            "subtitle": text(collection?.subtitle), "author_line": text(collection?.authorLine),
            "introduction_text": text(collection?.introductionText), "introduction_rich_text": blob(collection?.introductionRichText),
            "include_colophon": bool(collection?.includeColophon ?? false),
            "include_project_provenance": bool(collection?.includeProjectProvenance ?? false),
            "include_method_appendix": bool(collection?.includeMethodAppendix ?? false),
            "default_body_depth": .text(collection?.defaultBodyDepth ?? "full"),
            "footnote_style": .text(collection?.footnoteStyle ?? "all"),
            "include_footnotes": bool(collection?.includeFootnotes), "include_source_note": bool(collection?.includeSourceNote),
            "toc_style": .text(collection?.tocStyle ?? "citation"),
            "apply_highlights": bool(collection?.applyHighlights ?? false), "include_notes": bool(collection?.includeNotes ?? true),
            "include_word_cloud": bool(collection?.includeWordCloud ?? false),
            "default_include_headnote": bool(collection?.defaultIncludeHeadnote ?? false),
            "summary_prompt_id": uuid(collection?.summaryPromptId),
        ]
    }

    static func entry(_ entry: CollectionEntryExport, of collection: CollectionExport, version: Int) -> ImportRow {
        var row = ImportRow(values: [
            "id": uuid(entry.id), "collection_id": uuid(collection.id), "document_id": .text(entry.documentId),
            "volume_id": .text(entry.volumeId), "sort_order": int(entry.sortOrder), "research_note_id": uuid(entry.researchNoteId),
            "selected_note_ids": ids(entry.selectedNoteIds), "created_at": date(entry.createdAt),
            "last_modified": date(entry.lastModified),
        ])
        var defaults = entryFields(nil)
        // Version 6 wrote a heading, a prose block and an apparatus block as an entry with no
        // document, and did not say which.
        if entry.documentId.isEmpty { defaults["kind"] = .text(inertKind) }
        row.carry(entryFields(entry), since: 7, in: version, defaults: defaults)
        return row
    }

    /// An entry's kind, text and overrides, or for nil the app's defaults: each stored property's
    /// initial value in `CollectionEntry`.
    static func entryFields(_ entry: CollectionEntryExport?) -> [String: SQLiteValue] {
        [
            "title_override": text(entry?.titleOverride), "level": int(entry?.level ?? 1),
            "body_depth_override": text(entry?.bodyDepthOverride), "apply_highlights_override": bool(entry?.applyHighlightsOverride),
            "include_notes_override": bool(entry?.includeNotesOverride),
            "include_source_note_override": bool(entry?.includeSourceNoteOverride),
            "include_footnotes_override": bool(entry?.includeFootnotesOverride),
            "summary_prompt_id_override": uuid(entry?.summaryPromptIdOverride),
            "selected_highlight_ids": ids(entry?.selectedHighlightIds ?? []),
            "include_related_documents": bool(entry?.includeRelatedDocuments), "include_headnote": bool(entry?.includeHeadnote),
            "headnote_summary_id": uuid(entry?.headnoteSummaryId), "excerpt_start": int(entry?.excerptStart),
            "excerpt_end": int(entry?.excerptEnd), "excerpt_rendering_version": text(entry?.excerptRenderingVersion),
            "excerpt_color_tag": text(entry?.excerptColorTag), "kind": .text(entry?.kind ?? "document"),
            "generated_block_type": text(entry?.generatedBlockType), "text": text(entry?.text), "rich_text": blob(entry?.richText),
        ]
    }

    static func project(_ project: ProjectExport, version: Int) -> ImportRow {
        var row = ImportRow(values: [
            "id": uuid(project.id), "name": .text(project.name), "research_question": text(project.researchQuestion),
            "default_date_range_start": date(project.defaultDateRangeStart), "default_date_range_end": date(project.defaultDateRangeEnd),
            "default_subject_tag_ids": strings(project.defaultSubjectTagIds),
            "default_country_tag_ids": strings(project.defaultCountryTagIds), "created_at": date(project.createdAt),
            "last_modified": date(project.lastModified),
        ])
        row.carry(["default_user_tag_ids": ids(project.defaultUserTagIds ?? []), "lead_axis_weights": text(project.leadAxisWeights)],
                  since: 7, in: version, defaults: ["default_user_tag_ids": ids([]), "lead_axis_weights": .null])
        return row
    }

    static func lead(_ lead: ProjectLeadEntryExport) -> ImportRow {
        ImportRow(values: [
            "id": uuid(lead.id), "project_id": uuid(lead.projectId), "volume_id": .text(lead.volumeId),
            "document_id": .text(lead.documentId), "aggregate_score": .real(lead.aggregateScore),
            "contributing_seed_keys": strings(lead.contributingSeedKeys), "header": .text(lead.header),
            "document_number": text(lead.documentNumber), "is_editorial_note": bool(lead.isEditorialNote),
            "first_surfaced_at": date(lead.firstSurfacedAt), "last_computed_at": date(lead.lastComputedAt),
            "dismissed": bool(lead.dismissed),
        ])
    }

    static func savedSearch(_ search: SavedSearchExport) -> ImportRow {
        var values = SavedSearchColumns.scalars(of: search.parameters)
        values.merge([
            "id": uuid(search.id), "name": .text(search.name), "created_at": date(search.createdAt),
            "last_modified": date(search.lastModified), "parameters_data": json(search.parameters),
            "freshness_data": SavedSearchColumns.freshness(lastRunAt: search.lastRunAt, matchCount: search.matchCountAtLastRun,
                                                          indexedVolumeCount: search.indexedVolumeCountAtLastRun),
        ]) { $1 }
        return ImportRow(values: values)
    }

    static func corpus(_ corpus: WorkingCorpusExport) -> ImportRow {
        ImportRow(values: [
            "id": uuid(corpus.id), "name": .text(corpus.name), "document_keys": strings(corpus.documentKeys),
            "captured_at": date(corpus.capturedAt), "source_query": text(corpus.sourceQuery),
            "source_description": text(corpus.sourceDescription),
            "indexed_volume_count_at_capture": int(corpus.indexedVolumeCountAtCapture),
            "was_truncated_at_capture": bool(corpus.wasTruncatedAtCapture),
            "total_match_count_at_capture": int(corpus.totalMatchCountAtCapture), "created_at": date(corpus.createdAt),
            "last_modified": date(corpus.lastModified),
        ])
    }

    static func scope(_ scope: CustomVolumeScopeExport) -> ImportRow {
        ImportRow(values: ["id": uuid(scope.id), "name": .text(scope.name), "volume_ids": strings(scope.volumeIds),
                           "created_at": date(scope.createdAt), "last_modified": date(scope.lastModified)])
    }

    static func reading(_ entry: ReadingHistoryEntryExport) -> ImportRow {
        ImportRow(values: ["id": uuid(entry.id), "document_id": .text(entry.documentId), "volume_id": .text(entry.volumeId),
                           "display_title": text(entry.displayTitle), "project_id": uuid(entry.projectId),
                           "accessed_at": date(entry.accessedAt)])
    }

    static func search(_ entry: SearchHistoryEntryExport, version: Int) -> ImportRow {
        var row = ImportRow(values: [
            "id": uuid(entry.id), "query_text": .text(entry.queryText), "result_count": int(entry.resultCount),
            "project_id": uuid(entry.projectId), "executed_at": date(entry.executedAt),
        ])
        let provenance: [String: SQLiteValue] = [
            "loaded_count": int(entry.loadedCount), "match_count": int(entry.matchCount), "fetch_limit": int(entry.fetchLimit),
            "indexed_volume_count": int(entry.indexedVolumeCount), "scope_signature": text(entry.scopeSignature),
            "applied_corpus_id": uuid(entry.appliedCorpusId), "rendered_expression": text(entry.renderedExpression),
        ]
        row.carry(provenance, since: 4, in: version, defaults: provenance.mapValues { _ in .null })
        return row
    }

    static func exported(_ entry: ExportHistoryEntryExport) -> ImportRow {
        ImportRow(values: ["id": uuid(entry.id), "format": .text(entry.format), "document_count": int(entry.documentCount),
                           "collection_name": text(entry.collectionName), "project_id": uuid(entry.projectId),
                           "exported_at": date(entry.exportedAt)])
    }

    static func plan(_ plan: ArchiveVisitPlanExport) -> ImportRow {
        // The tiers and the resolved toggles, encoded as the app's `tiers` and `deliverables`
        // setters encode them, so the app's getters read back what the file holds.
        ImportRow(values: [
            "id": uuid(plan.id), "name": .text(plan.name), "inquiry_text": text(plan.inquiryText),
            "project_ids": ids(plan.projectIds), "tiers_data": json(plan.tiers), "deliverable_toggles_data": json(plan.deliverables),
            "created_at": date(plan.createdAt), "last_modified": date(plan.lastModified),
        ])
    }

    static func seed(_ document: ArchiveVisitDocumentExport, of plan: ArchiveVisitPlanExport) -> ImportRow {
        ImportRow(values: [
            "id": uuid(document.id), "plan_id": uuid(plan.id), "document_key": .text(document.documentKey),
            "include_source": bool(document.includeSource), "include_external_refs": bool(document.includeExternalRefs),
            "created_at": date(document.createdAt), "last_modified": date(document.lastModified),
        ], defaults: ["state_data": .null])
    }

    static func target(_ target: ArchiveVisitTargetExport, of plan: ArchiveVisitPlanExport) -> ImportRow {
        ImportRow(values: [
            "id": uuid(target.id), "plan_id": uuid(plan.id), "target_key": .text(target.targetKey), "tier_id": uuid(target.tierId),
            "included": bool(target.included), "user_note": text(target.userNote), "created_at": date(target.createdAt),
            "last_modified": date(target.lastModified),
        ], defaults: ["state_data": .null])
    }

    static func summary(_ summary: GeneratedSummaryExport, version: Int) -> ImportRow {
        var row = ImportRow(values: [
            "id": uuid(summary.id), "document_id": .text(summary.documentId), "volume_id": .text(summary.volumeId),
            "prompt_id": uuid(summary.promptId), "response_text": .text(summary.responseText),
            "response_format": json(summary.responseFormat), "was_chunked": bool(summary.wasChunked),
            "is_headnote_draft": bool(isHeadnoteDraft(summary, version: version)), "project_id": uuid(summary.projectId),
            "created_at": date(summary.createdAt), "last_modified": date(summary.lastModified),
        ], defaults: ["source_content_hash": .null])
        // As the Mac exported it: none before version 5, which every reader takes as AI-generated.
        row.carry(["authorship": text(summary.authorship?.rawValue)], since: 5, in: version, defaults: ["authorship": .null])
        return row
    }

    /// Whether a summary is a collection's headnote draft: as the file says, from version 7, and
    /// before it by the prompt every draft carries.
    static func isHeadnoteDraft(_ summary: GeneratedSummaryExport, version: Int) -> Bool {
        (version >= 7 ? summary.isHeadnoteDraft : nil) ?? (summary.promptId.uuidString == headnoteDraftPromptId)
    }

    static func prompt(_ prompt: SummarizationPromptExport) -> ImportRow {
        // The export holds the researcher's own prompts only, never the standard ones.
        ImportRow(values: [
            "id": uuid(prompt.id), "name": .text(prompt.name), "prompt_text": .text(prompt.promptText),
            "response_format": json(prompt.responseFormat), "is_standard": bool(false),
            "schema": prompt.schema.map { json($0) } ?? .null, "created_at": date(prompt.createdAt),
            "last_modified": date(prompt.lastModified),
        ])
    }

    static func review(_ review: AnnotationReviewExport) -> ImportRow {
        ImportRow(values: [
            "id": uuid(review.id), "annotation_type": .text(review.annotationType), "annotation_id": uuid(review.annotationId),
            "volume_id": .text(review.volumeId), "document_id": .text(review.documentId), "content_hash": .text(review.contentHash),
            "change_kind": text(review.changeKind), "reviewed_at": date(review.reviewedAt),
        ])
    }

    static func preferences(_ preferences: SyncedPreferencesExport) -> ImportRow {
        ImportRow(values: [
            "created_at": date(preferences.createdAt), "updated_at": date(preferences.updatedAt),
            "wc_min_length": int(preferences.wcMinLength), "wc_min_count": int(preferences.wcMinCount),
            "wc_fold_plurals": bool(preferences.wcFoldPlurals), "wc_filter_markings": bool(preferences.wcFilterMarkings),
            "wc_exclude_boilerplate": bool(preferences.wcExcludeBoilerplate),
            "wc_global_stopwords_json": .text(preferences.wcGlobalStopwordsJSON),
            "wc_lens_stopwords_json": .text(preferences.wcLensStopwordsJSON),
            "citation_style_raw": .text(preferences.citationStyleRaw),
            "default_document_mode_raw": .text(preferences.defaultDocumentModeRaw),
            "research_logging_enabled": bool(preferences.researchLoggingEnabled), "list_order_json": .text(preferences.listOrderJSON),
        ])
    }

    static func personCorrection(_ correction: PersonClusterOverrideExport) -> ImportRow {
        ImportRow(values: [
            "id": uuid(correction.id), "kind": .text(correction.kind), "volume_id_a": .text(correction.volumeIdA),
            "ref_a": .text(correction.refA), "volume_id_b": text(correction.volumeIdB), "ref_b": text(correction.refB),
            "created_at": date(correction.createdAt),
        ])
    }

    static func classificationCorrection(_ correction: DocumentClassificationOverrideExport) -> ImportRow {
        ImportRow(values: [
            "id": uuid(correction.id), "volume_id": .text(correction.volumeId), "document_id": .text(correction.documentId),
            "is_editorial_note": bool(correction.isEditorialNote),
            "parsed_is_editorial_note": bool(correction.parsedIsEditorialNote), "created_at": date(correction.createdAt),
        ])
    }

    // MARK: Values, as the store keeps them

    static func uuid(_ id: UUID?) -> SQLiteValue { id.map { .text($0.uuidString) } ?? .null }
    static func text(_ text: String?) -> SQLiteValue { text.map { .text($0) } ?? .null }
    static func date(_ date: Date?) -> SQLiteValue { date.map { .text(UserStoreDate.text($0)) } ?? .null }
    static func bool(_ value: Bool?) -> SQLiteValue { value.map { .integer($0 ? 1 : 0) } ?? .null }
    static func int(_ value: Int?) -> SQLiteValue { value.map { .integer(Int64($0)) } ?? .null }
    static func blob(_ data: Data?) -> SQLiteValue { data.map { .blob(Array($0)) } ?? .null }
    static func ids(_ ids: [UUID]) -> SQLiteValue { .text(TagReferences.encode(ids.map(\.uuidString))) }
    static func strings(_ strings: [String]) -> SQLiteValue { .text(TagReferences.encode(strings)) }

    /// A `Codable` value as JSON text, written by the app's own encoder for these columns, a plain
    /// `JSONEncoder()`.
    static func json<T: Encodable>(_ value: T) -> SQLiteValue {
        (try? JSONEncoder().encode(value)).map { .text(String(decoding: $0, as: UTF8.self)) } ?? .null
    }
}

extension ImportRow {
    /// Adds `columns` as values when a file of `version` carries them, from `since` on, and otherwise
    /// as the defaults a new row takes.
    mutating func carry(_ columns: [String: SQLiteValue], since: Int, in version: Int, defaults: [String: SQLiteValue]) {
        if version >= since {
            values.merge(columns) { $1 }
        } else {
            self.defaults.merge(defaults) { $1 }
        }
    }
}

/// The columns the app's `SavedSearch` keeps beside its search's snapshot, app code mirrored: its
/// `init(name:parameters:)` writes the scalar columns from the parameters, and `recordRun` writes the
/// watermark, `SavedSearchFreshness`, with a plain `JSONEncoder()`. NotesAndSummariesParityTests
/// holds both to the app's source.
enum SavedSearchColumns {
    /// `SavedSearch.init(name:parameters:)`'s scalar columns, as it writes them from `parameters`.
    static func scalars(of parameters: SearchParameters) -> [String: SQLiteValue] {
        var flags = 0
        if parameters.includeDocumentText { flags |= 1 }
        if parameters.includeSummaries { flags |= 2 }
        if parameters.includeNotes { flags |= 4 }
        var start: Date?
        var end: Date?
        if let range = parameters.dateRange {
            let format = ISO8601DateFormatter()
            format.formatOptions = [.withFullDate]
            start = range.earliest.flatMap { format.date(from: $0) }
            end = range.latest.flatMap { format.date(from: $0) }
        }
        let documentType = switch parameters.documentTypeFilter {
        case .documentsOnly: "documentsOnly"
        case .editorialNotesOnly: "editorialNotesOnly"
        case .all: "all"
        }
        return [
            "query_text": .text(parameters.keywords ?? ""), "phrase_text": .text(parameters.phrase ?? ""),
            "prefix_wildcard": .text(parameters.prefixWildcard ?? ""),
            "boolean_mode_raw": .text(parameters.booleanMode == .or ? "or" : "and"),
            "excluded_terms_csv": .text(parameters.excludedTerms.joined(separator: ",")), "scope_flags": .integer(Int64(flags)),
            "date_range_start": MacImport.date(start), "date_range_end": MacImport.date(end),
            "subject_tag_ids_csv": .text(parameters.subjectTagIds.joined(separator: ",")),
            "document_type_filter_raw": .text(documentType), "person_ref": .text(parameters.personRef ?? ""),
            "sort_order": .text("relevance"),
        ]
    }

    /// The watermark `SavedSearchFreshness` encodes, or NULL when the file records no run, as a
    /// search saved and never run again keeps none.
    static func freshness(lastRunAt: Date?, matchCount: Int?, indexedVolumeCount: Int?) -> SQLiteValue {
        guard lastRunAt != nil || matchCount != nil || indexedVolumeCount != nil else { return .null }
        return MacImport.json(Freshness(lastRunAt: lastRunAt, matchCountAtLastRun: matchCount,
                                        indexedVolumeCountAtLastRun: indexedVolumeCount))
    }

    /// `SavedSearchFreshness`'s fields and keys, encoded as its synthesized encoder writes them: a
    /// field with no value left out, and the date as the default strategy writes one, seconds since
    /// 2001, which the app's decoder reads back.
    struct Freshness: Codable, Equatable {
        var lastRunAt: Date?
        var matchCountAtLastRun: Int?
        var indexedVolumeCountAtLastRun: Int?
    }
}
