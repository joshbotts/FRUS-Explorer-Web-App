// The web's export (PLAN's S16d): a user's research as the Mac's Export as JSON writes it, the kit's
// `ResearchDataEnvelope` at its format version, each record as the app's exporter makes one
// (`ResearchDataExporter.makeEnvelope`, app code, which reads SwiftData), written by the kit's encoder,
// `makeEncoder()`, with one key more, the web's own, which the kit's decoder, and so a Mac importer,
// passes over. What the mapping mirrors of the app's exporter, held to its source by ExportParityTests:
// - its orders: what it fetches unsorted in the order the store took it, which stands for SwiftData's
//   fetch order, and the rest as its fetches sort them, the trail by its times, a plan by its name
//   and then when it was made, a collection's entries by their place, and so on, a tie in the
//   store's order;
// - a note's highlights, the ids of those that name it, in their order;
// - a summary with no authorship, from a file before version 5, written as an AI summary, as every
//   reader takes one;
// - a lead's score that is no finite number written as 0, which the encoder would refuse;
// - a saved search's search and watermark, and a plan's tiers and toggles, read as the app's
//   getters read them;
// - the header's project, the one the export is made under, as the Mac's names its active project:
//   none for no id or one that names no project.
// The web keeps no field the envelope cannot carry: the store's columns are the app's (S14a), and
// those the app's export leaves out no path here writes, which ExportParityTests holds column by
// column. Its key says what the file leaves out by choice, which the envelope cannot say.

import FRUSCoreKit
import FRUSLightCore
import Foundation

/// What the web adds to the file, under its one key, `frusExplorerLight`.
public struct WebExportKey: Codable, Equatable, Sendable {
    /// This key's own version, for a later build that adds to it.
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    /// Whether the file carries the user's summaries, as Include AI-Generated Summaries chose: an
    /// empty `summaries` in the Mac's file can mean either.
    public var includesGeneratedSummaries: Bool
    /// Whether it carries the instance's two corrections, which only a curator's export does.
    public var includesCorrections: Bool

    public init(includesGeneratedSummaries: Bool, includesCorrections: Bool) {
        formatVersion = Self.currentFormatVersion
        self.includesGeneratedSummaries = includesGeneratedSummaries
        self.includesCorrections = includesCorrections
    }
}

/// A row the export cannot write as the kit's record: what no path here writes, which only a
/// damaged store could hold.
public enum ResearchExportError: Error, Equatable, CustomStringConvertible {
    case malformed(table: String, id: String?, column: String, detail: String)

    var problem: APIProblem {
        APIProblem(.internalServerError, code: "EXPORT_FAILED", detail: "The export could not be written: \(description)")
    }

    public var description: String {
        switch self {
        case .malformed(let table, let id, let column, let detail):
            "the row \(id ?? "of the user's") of \(table) holds a \(column) that \(detail)."
        }
    }
}

public enum ResearchExport {
    /// The web's key, beside the envelope's.
    public static let webKey = "frusExplorerLight"
    /// The download's name, the file the app's export sheet writes.
    public static let fileName = "frus-research-export.json"

    /// What an export carries, and when it was made.
    public struct Options: Sendable, Equatable {
        /// Include AI-Generated Summaries: every summary, the app's switch, off by default.
        public var includeGeneratedSummaries: Bool
        /// The instance's two corrections, a curator's to carry, as a curator's to import.
        public var includingInstanceWide: Bool
        /// The project the export is made under, which heads the file.
        public var projectId: UUID?
        public var exportedAt: Date

        public init(includeGeneratedSummaries: Bool, includingInstanceWide: Bool, projectId: UUID? = nil, exportedAt: Date) {
            self.includeGeneratedSummaries = includeGeneratedSummaries
            self.includingInstanceWide = includingInstanceWide
            self.projectId = projectId
            self.exportedAt = exportedAt
        }
    }

    /// The tables `options` carries: every user table, the summaries with the switch, and the
    /// instance's two for a curator.
    public static func tables(_ options: Options) -> Set<String> {
        Set(UserStoreSchema.tables.filter { table in
            (table.scope == .user || options.includingInstanceWide)
                && (table.name != "summaries" || options.includeGeneratedSummaries)
        }.map(\.name))
    }

    /// The file: the envelope of what `store` holds of `user`'s, read at one moment, and the web's
    /// key, written by the kit's encoder.
    public static func file(from store: any ResearchExportStore, for user: String, _ options: Options) throws -> Data {
        try file(envelope(try store.researchRows(for: user, tables: tables(options)), options), options)
    }

    /// `envelope` as the file, with the web's key for `options`.
    public static func file(_ envelope: ResearchDataEnvelope, _ options: Options) throws -> Data {
        let key = WebExportKey(includesGeneratedSummaries: options.includeGeneratedSummaries,
                               includesCorrections: options.includingInstanceWide)
        return try ResearchDataEnvelope.makeEncoder().encode(File(envelope: envelope, web: key))
    }

    /// The envelope and the web's key, at the top level of one JSON object, its keys sorted.
    private struct File: Encodable {
        let envelope: ResearchDataEnvelope
        let web: WebExportKey

        enum Key: String, CodingKey { case frusExplorerLight }

        func encode(to encoder: any Encoder) throws {
            try envelope.encode(to: encoder)
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(web, forKey: .frusExplorerLight)
        }
    }

    /// The envelope of `rows`, at the kit's format version, as the app's exporter makes it.
    public static func envelope(_ rows: ResearchRows, _ options: Options) throws -> ResearchDataEnvelope {
        let highlights = try records(rows, "highlights", highlight)
        var links: [UUID: [UUID]] = [:]
        for highlight in highlights { if let note = highlight.noteId { links[note, default: []].append(highlight.id) } }
        let notes = try records(rows, "notes") { try note($0, links: links) }
        let entries = try children(rows["collection_entries"], in: "collection_entries", of: "collection_id")
        let collections = try records(rows, "collections") { row in
            let id = try row.uuid("id")
            return try collection(row, entries: try ordered(entries[id] ?? [], in: "collection_entries") { try $0.int("sort_order") })
        }
        let projects = try records(rows, "projects", project)
        let header = options.projectId.flatMap { id in projects.first { $0.id == id } }

        var envelope = ResearchDataEnvelope(
            formatVersion: ResearchDataEnvelope.currentFormatVersion, exportedAt: options.exportedAt,
            exportedForProjectName: header?.name, exportedForProjectResearchQuestion: header?.researchQuestion,
            notes: notes, tags: try records(rows, "tags", tag), tagAssignments: try records(rows, "tag_assignments", assignment),
            highlights: highlights, collections: collections, prompts: try records(rows, "prompts", prompt), projects: projects,
            summaries: try records(rows, "summaries", summary))
        envelope.readingHistory = try records(rows, "trail_reading", byTime: "accessed_at", reading)
        envelope.searchHistory = try records(rows, "trail_search", byTime: "executed_at", search)
        envelope.exportHistory = try records(rows, "trail_export", byTime: "exported_at", exported)
        envelope.archiveVisits = try archiveVisits(rows)
        envelope.savedSearches = try records(rows, "saved_searches", byTime: "created_at", savedSearch)
        envelope.workingCorpora = try records(rows, "working_corpora", byTime: "created_at", corpus)
        envelope.customVolumeScopes = try records(rows, "volume_scopes", byTime: "created_at", scope)
        envelope.classificationOverrides = try records(rows, "classification_overrides", byTime: "created_at",
                                                       classificationCorrection)
        envelope.personClusterOverrides = try records(rows, "person_overrides", byTime: "created_at", personCorrection)
        envelope.annotationReviews = try records(rows, "annotation_reviews", byTime: "reviewed_at", review)
        envelope.projectLeads = try records(rows, "project_leads", byTime: "first_surfaced_at", lead)
        envelope.syncedPreferences = try records(rows, "preferences", byTime: "created_at", preferences)
        return envelope
    }

    // MARK: Orders

    /// A table's records, in the order the store took its rows, as the app's unsorted fetch gives them.
    static func records<T>(_ rows: ResearchRows, _ table: String, _ record: (Fields) throws -> T) throws -> [T] {
        try rows[table].map { try record(Fields(table, $0)) }
    }

    /// A table's records as a fetch sorted by the time in `column` gives them, oldest first and those
    /// with none before the rest, each tie in the store's order.
    static func records<T>(_ rows: ResearchRows, _ table: String, byTime column: String,
                           _ record: (Fields) throws -> T) throws -> [T] {
        try ordered(rows[table], in: table) { Time(try $0.optionalDate(column)) }.map { try record(Fields(table, $0)) }
    }

    /// `rows` in the order of `key`, each tie in the store's order, as a stable sort leaves them.
    static func ordered<Key: Comparable>(_ rows: [ExportRow], in table: String,
                                         by key: (Fields) throws -> Key) throws -> [ExportRow] {
        try rows.map { ($0, try key(Fields(table, $0))) }
            .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.position < $1.0.position }
            .map(\.0)
    }

    /// A table's rows by the parent each names in `column`, each parent's in the store's order.
    static func children(_ rows: [ExportRow], in table: String, of column: String) throws -> [UUID: [ExportRow]] {
        var children: [UUID: [ExportRow]] = [:]
        for row in rows {
            let parent = try Fields(table, row).uuid(column)
            children[parent, default: []].append(row)
        }
        return children
    }

    /// A time that may be none, which comes first, as a sort over an optional date puts it.
    struct Time: Comparable {
        let date: Date?
        init(_ date: Date?) { self.date = date }
        static func < (a: Time, b: Time) -> Bool {
            switch (a.date, b.date) {
            case let (x?, y?): x < y
            case (nil, _?): true
            default: false
            }
        }
    }

    /// The archive visits by name, as the app's `SortDescriptor` over a string compares it, with
    /// Foundation's localized standard comparison, then by when each was made; each plan's documents
    /// and targets by their keys.
    static func archiveVisits(_ rows: ResearchRows) throws -> [ArchiveVisitPlanExport] {
        let documents = try children(rows["visit_documents"], in: "visit_documents", of: "plan_id")
        let targets = try children(rows["visit_targets"], in: "visit_targets", of: "plan_id")
        let plans = try rows["visit_plans"].map { row in
            let fields = Fields("visit_plans", row)
            return (fields: fields, name: try fields.text("name"), made: Time(try fields.optionalDate("created_at")),
                    position: row.position)
        }.sorted { a, b in
            switch a.name.localizedStandardCompare(b.name) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: a.made != b.made ? a.made < b.made : a.position < b.position
            }
        }
        return try plans.map { plan in
            let id = try plan.fields.uuid("id")
            return try self.plan(
                plan.fields, documents: try ordered(documents[id] ?? [], in: "visit_documents") { try $0.text("document_key") },
                targets: try ordered(targets[id] ?? [], in: "visit_targets") { try $0.text("target_key") })
        }
    }

    // MARK: Each type's record

    static func note(_ row: Fields, links: [UUID: [UUID]]) throws -> ResearchNoteExport {
        let id = try row.uuid("id")
        return ResearchNoteExport(
            id: id, documentId: try row.text("document_id"), volumeId: try row.text("volume_id"),
            bodyText: try row.text("body_text"), projectIds: try row.uuids("project_ids"), userTagIds: try row.uuids("user_tag_ids"),
            selectedSummaryIds: try row.uuids("selected_summary_ids"), linkedHighlightIds: links[id] ?? [],
            createdAt: try row.optionalDate("created_at"), lastModified: try row.optionalDate("last_modified"),
            richText: row.data("rich_text"))
    }

    static func highlight(_ row: Fields) throws -> DocumentHighlightExport {
        DocumentHighlightExport(
            id: try row.uuid("id"), volumeId: try row.text("volume_id"), documentId: try row.text("document_id"),
            startOffset: try row.int("start_offset"), endOffset: try row.int("end_offset"), colorTag: try row.text("color_tag"),
            noteId: try row.optionalUUID("note_id"), selectedText: try row.text("selected_text"),
            renderingVersion: try row.text("rendering_version"), createdAt: try row.optionalDate("created_at"))
    }

    static func tag(_ row: Fields) throws -> UserTagExport {
        UserTagExport(id: try row.uuid("id"), name: try row.text("name"), createdAt: try row.optionalDate("created_at"),
                      lastModified: try row.optionalDate("last_modified"))
    }

    static func assignment(_ row: Fields) throws -> DocumentTagAssignmentExport {
        DocumentTagAssignmentExport(id: try row.uuid("id"), volumeId: try row.text("volume_id"),
                                    documentId: try row.text("document_id"), tagId: try row.uuid("tag_id"),
                                    createdAt: try row.optionalDate("created_at"))
    }

    static func collection(_ row: Fields, entries: [ExportRow]) throws -> CollectionExport {
        CollectionExport(
            id: try row.uuid("id"), name: try row.text("name"), note: row.optionalText("note"),
            projectIds: try row.uuids("project_ids"), savedSearchId: try row.optionalUUID("saved_search_id"),
            entries: try entries.map { try entry(Fields("collection_entries", $0)) },
            createdAt: try row.optionalDate("created_at"), lastModified: try row.optionalDate("last_modified"),
            subtitle: row.optionalText("subtitle"), authorLine: row.optionalText("author_line"),
            introductionText: row.optionalText("introduction_text"), introductionRichText: row.data("introduction_rich_text"),
            includeColophon: try row.bool("include_colophon"), includeProjectProvenance: try row.bool("include_project_provenance"),
            includeMethodAppendix: try row.bool("include_method_appendix"), defaultBodyDepth: try row.text("default_body_depth"),
            footnoteStyle: try row.text("footnote_style"), includeFootnotes: try row.optionalBool("include_footnotes"),
            includeSourceNote: try row.optionalBool("include_source_note"), tocStyle: try row.text("toc_style"),
            applyHighlights: try row.bool("apply_highlights"), includeNotes: try row.bool("include_notes"),
            includeWordCloud: try row.bool("include_word_cloud"), defaultIncludeHeadnote: try row.bool("default_include_headnote"),
            summaryPromptId: try row.optionalUUID("summary_prompt_id"))
    }

    static func entry(_ row: Fields) throws -> CollectionEntryExport {
        CollectionEntryExport(
            id: try row.uuid("id"), documentId: try row.text("document_id"), volumeId: try row.text("volume_id"),
            sortOrder: try row.int("sort_order"), researchNoteId: try row.optionalUUID("research_note_id"),
            selectedNoteIds: try row.uuids("selected_note_ids"), createdAt: try row.optionalDate("created_at"),
            lastModified: try row.optionalDate("last_modified"), kind: try row.text("kind"), level: try row.int("level"),
            text: row.optionalText("text"), richText: row.data("rich_text"), excerptStart: try row.optionalInt("excerpt_start"),
            excerptEnd: try row.optionalInt("excerpt_end"), excerptRenderingVersion: row.optionalText("excerpt_rendering_version"),
            excerptColorTag: row.optionalText("excerpt_color_tag"), generatedBlockType: row.optionalText("generated_block_type"),
            titleOverride: row.optionalText("title_override"), bodyDepthOverride: row.optionalText("body_depth_override"),
            applyHighlightsOverride: try row.optionalBool("apply_highlights_override"),
            includeNotesOverride: try row.optionalBool("include_notes_override"),
            includeSourceNoteOverride: try row.optionalBool("include_source_note_override"),
            includeFootnotesOverride: try row.optionalBool("include_footnotes_override"),
            summaryPromptIdOverride: try row.optionalUUID("summary_prompt_id_override"),
            selectedHighlightIds: try row.uuids("selected_highlight_ids"),
            includeRelatedDocuments: try row.optionalBool("include_related_documents"),
            includeHeadnote: try row.optionalBool("include_headnote"), headnoteSummaryId: try row.optionalUUID("headnote_summary_id"))
    }

    static func prompt(_ row: Fields) throws -> SummarizationPromptExport {
        SummarizationPromptExport(id: try row.uuid("id"), name: try row.text("name"), promptText: try row.text("prompt_text"),
                                  responseFormat: try row.json(ResponseFormat.self, "response_format"),
                                  schema: try row.optionalJSON(StructuredSummarySchema.self, "schema"),
                                  createdAt: try row.optionalDate("created_at"), lastModified: try row.optionalDate("last_modified"))
    }

    static func project(_ row: Fields) throws -> ProjectExport {
        ProjectExport(id: try row.uuid("id"), name: try row.text("name"), researchQuestion: row.optionalText("research_question"),
                      defaultDateRangeStart: try row.optionalDate("default_date_range_start"),
                      defaultDateRangeEnd: try row.optionalDate("default_date_range_end"),
                      defaultSubjectTagIds: try row.strings("default_subject_tag_ids"),
                      defaultCountryTagIds: try row.strings("default_country_tag_ids"),
                      createdAt: try row.optionalDate("created_at"), lastModified: try row.optionalDate("last_modified"),
                      defaultUserTagIds: try row.uuids("default_user_tag_ids"), leadAxisWeights: row.optionalText("lead_axis_weights"))
    }

    static func summary(_ row: Fields) throws -> GeneratedSummaryExport {
        // None, from a file before version 5, as `.aiGenerated`, which every reader takes it for:
        // the app's exporter writes no ambiguity a reader must resolve by a rule it does not have.
        let authorship: SummaryAuthorship = try row.optionalText("authorship").map { raw in
            guard let authorship = SummaryAuthorship(rawValue: raw) else { throw row.malformed("authorship", "is no authorship the app writes") }
            return authorship
        } ?? .aiGenerated
        return GeneratedSummaryExport(
            id: try row.uuid("id"), documentId: try row.text("document_id"), volumeId: try row.text("volume_id"),
            promptId: try row.uuid("prompt_id"), responseText: try row.text("response_text"),
            responseFormat: try row.json(ResponseFormat.self, "response_format"), wasChunked: try row.bool("was_chunked"),
            projectId: try row.optionalUUID("project_id"), createdAt: try row.optionalDate("created_at"),
            lastModified: try row.optionalDate("last_modified"), authorship: authorship,
            isHeadnoteDraft: try row.bool("is_headnote_draft"))
    }

    static func reading(_ row: Fields) throws -> ReadingHistoryEntryExport {
        ReadingHistoryEntryExport(id: try row.uuid("id"), documentId: try row.text("document_id"), volumeId: try row.text("volume_id"),
                                  displayTitle: row.optionalText("display_title"), projectId: try row.optionalUUID("project_id"),
                                  accessedAt: try row.optionalDate("accessed_at"))
    }

    static func search(_ row: Fields) throws -> SearchHistoryEntryExport {
        SearchHistoryEntryExport(
            id: try row.uuid("id"), queryText: try row.text("query_text"), resultCount: try row.int("result_count"),
            projectId: try row.optionalUUID("project_id"), executedAt: try row.optionalDate("executed_at"),
            loadedCount: try row.optionalInt("loaded_count"), matchCount: try row.optionalInt("match_count"),
            fetchLimit: try row.optionalInt("fetch_limit"), indexedVolumeCount: try row.optionalInt("indexed_volume_count"),
            scopeSignature: row.optionalText("scope_signature"), appliedCorpusId: try row.optionalUUID("applied_corpus_id"),
            renderedExpression: row.optionalText("rendered_expression"))
    }

    static func exported(_ row: Fields) throws -> ExportHistoryEntryExport {
        ExportHistoryEntryExport(id: try row.uuid("id"), format: try row.text("format"), documentCount: try row.int("document_count"),
                                 collectionName: row.optionalText("collection_name"), projectId: try row.optionalUUID("project_id"),
                                 exportedAt: try row.optionalDate("exported_at"))
    }

    static func plan(_ row: Fields, documents: [ExportRow], targets: [ExportRow]) throws -> ArchiveVisitPlanExport {
        // As the app's getters read the two blobs: none, or one that does not decode, as no tiers and
        // the default toggles.
        ArchiveVisitPlanExport(
            id: try row.uuid("id"), name: try row.text("name"), inquiryText: row.optionalText("inquiry_text"),
            projectIds: try row.uuids("project_ids"), tiers: row.appJSON([ArchiveVisitTier].self, "tiers_data") ?? [],
            deliverables: row.appJSON(ArchiveVisitDeliverables.self, "deliverable_toggles_data") ?? ArchiveVisitDeliverables(),
            documents: try documents.map { document in
                let document = Fields("visit_documents", document)
                return ArchiveVisitDocumentExport(
                    id: try document.uuid("id"), documentKey: try document.text("document_key"),
                    includeSource: try document.bool("include_source"), includeExternalRefs: try document.bool("include_external_refs"),
                    createdAt: try document.optionalDate("created_at"), lastModified: try document.optionalDate("last_modified"))
            },
            targets: try targets.map { target in
                let target = Fields("visit_targets", target)
                return ArchiveVisitTargetExport(
                    id: try target.uuid("id"), targetKey: try target.text("target_key"), tierId: try target.optionalUUID("tier_id"),
                    included: try target.bool("included"), userNote: target.optionalText("user_note"),
                    createdAt: try target.optionalDate("created_at"), lastModified: try target.optionalDate("last_modified"))
            },
            createdAt: try row.optionalDate("created_at"), lastModified: try row.optionalDate("last_modified"))
    }

    static func savedSearch(_ row: Fields) throws -> SavedSearchExport {
        // The watermark as `SavedSearch.freshness` reads it, with the kit's decoder since S17c's pin
        // move: none when there is none or it is no object, each field none that does not read.
        let freshness = SavedSearchFreshness.decoded(from: row.optionalText("freshness_data").map { Data($0.utf8) })
        return SavedSearchExport(
            id: try row.uuid("id"), name: try row.text("name"), parameters: try searchParameters(row),
            lastRunAt: freshness?.lastRunAt, matchCountAtLastRun: freshness?.matchCountAtLastRun,
            indexedVolumeCountAtLastRun: freshness?.indexedVolumeCountAtLastRun, createdAt: try row.optionalDate("created_at"),
            lastModified: try row.optionalDate("last_modified"))
    }

    /// The search a saved search runs, as `SavedSearch.searchParameters` reads it, app code mirrored:
    /// its whole snapshot, which every saved search here holds, and when there is none, or it does
    /// not decode, the search its scalar columns make.
    static func searchParameters(_ row: Fields) throws -> SearchParameters {
        if let parameters = row.appJSON(SearchParameters.self, "parameters_data") { return parameters }
        let list = { (csv: String) in csv.isEmpty ? [] : csv.split(separator: ",").map(String.init) }
        let documentType: DocumentTypeFilter = switch try row.text("document_type_filter_raw") {
        case "documentsOnly": .documentsOnly
        case "editorialNotesOnly": .editorialNotesOnly
        default: .all
        }
        var dateRange: DateRange?
        if let start = try row.optionalDate("date_range_start"), let end = try row.optionalDate("date_range_end") {
            let format = ISO8601DateFormatter()
            format.formatOptions = [.withFullDate]
            dateRange = DateRange(earliest: format.string(from: start), latest: format.string(from: end))
        }
        let flags = try row.int("scope_flags")
        let text = { (column: String) throws -> String? in
            let value = try row.text(column)
            return value.isEmpty ? nil : value
        }
        return SearchParameters(
            keywords: try text("query_text"), phrase: try text("phrase_text"),
            booleanMode: try row.text("boolean_mode_raw") == "or" ? .or : .and,
            excludedTerms: list(try row.text("excluded_terms_csv")), prefixWildcard: try text("prefix_wildcard"),
            dateRange: dateRange, subjectTagIds: list(try row.text("subject_tag_ids_csv")),
            includeDocumentText: flags & 1 != 0, includeSummaries: flags & 2 != 0, includeNotes: flags & 4 != 0,
            documentTypeFilter: documentType, personRef: try text("person_ref"))
    }

    static func corpus(_ row: Fields) throws -> WorkingCorpusExport {
        WorkingCorpusExport(
            id: try row.uuid("id"), name: try row.text("name"), documentKeys: try row.strings("document_keys"),
            capturedAt: try row.optionalDate("captured_at"), sourceQuery: row.optionalText("source_query"),
            sourceDescription: row.optionalText("source_description"),
            indexedVolumeCountAtCapture: try row.optionalInt("indexed_volume_count_at_capture"),
            wasTruncatedAtCapture: try row.optionalBool("was_truncated_at_capture"),
            totalMatchCountAtCapture: try row.optionalInt("total_match_count_at_capture"),
            createdAt: try row.optionalDate("created_at"), lastModified: try row.optionalDate("last_modified"))
    }

    static func scope(_ row: Fields) throws -> CustomVolumeScopeExport {
        CustomVolumeScopeExport(id: try row.uuid("id"), name: try row.text("name"), volumeIds: try row.strings("volume_ids"),
                                createdAt: try row.optionalDate("created_at"), lastModified: try row.optionalDate("last_modified"))
    }

    static func classificationCorrection(_ row: Fields) throws -> DocumentClassificationOverrideExport {
        DocumentClassificationOverrideExport(
            id: try row.uuid("id"), volumeId: try row.text("volume_id"), documentId: try row.text("document_id"),
            isEditorialNote: try row.bool("is_editorial_note"), parsedIsEditorialNote: try row.bool("parsed_is_editorial_note"),
            createdAt: try row.optionalDate("created_at"))
    }

    static func personCorrection(_ row: Fields) throws -> PersonClusterOverrideExport {
        PersonClusterOverrideExport(id: try row.uuid("id"), kind: try row.text("kind"), volumeIdA: try row.text("volume_id_a"),
                                    refA: try row.text("ref_a"), volumeIdB: row.optionalText("volume_id_b"),
                                    refB: row.optionalText("ref_b"), createdAt: try row.optionalDate("created_at"))
    }

    static func review(_ row: Fields) throws -> AnnotationReviewExport {
        AnnotationReviewExport(id: try row.uuid("id"), annotationType: try row.text("annotation_type"),
                               annotationId: try row.optionalUUID("annotation_id"), volumeId: try row.text("volume_id"),
                               documentId: try row.text("document_id"), contentHash: try row.text("content_hash"),
                               changeKind: row.optionalText("change_kind"), reviewedAt: try row.optionalDate("reviewed_at"))
    }

    static func lead(_ row: Fields) throws -> ProjectLeadEntryExport {
        // A score that is no finite number as 0, which `JSONEncoder` would refuse, as the app's
        // exporter writes it: Suggested Next computes it again, and the dismissal is the researcher's.
        let score = try row.real("aggregate_score")
        return ProjectLeadEntryExport(
            id: try row.uuid("id"), projectId: try row.uuid("project_id"), volumeId: try row.text("volume_id"),
            documentId: try row.text("document_id"), aggregateScore: score.isFinite ? score : 0,
            contributingSeedKeys: try row.strings("contributing_seed_keys"), header: try row.text("header"),
            documentNumber: row.optionalText("document_number"), isEditorialNote: try row.bool("is_editorial_note"),
            firstSurfacedAt: try row.date("first_surfaced_at"), lastComputedAt: try row.date("last_computed_at"),
            dismissed: try row.bool("dismissed"))
    }

    static func preferences(_ row: Fields) throws -> SyncedPreferencesExport {
        SyncedPreferencesExport(
            createdAt: try row.date("created_at"), updatedAt: try row.date("updated_at"),
            wcMinLength: try row.int("wc_min_length"), wcMinCount: try row.int("wc_min_count"),
            wcFoldPlurals: try row.bool("wc_fold_plurals"), wcFilterMarkings: try row.bool("wc_filter_markings"),
            wcExcludeBoilerplate: try row.bool("wc_exclude_boilerplate"),
            wcGlobalStopwordsJSON: try row.text("wc_global_stopwords_json"),
            wcLensStopwordsJSON: try row.text("wc_lens_stopwords_json"), citationStyleRaw: try row.text("citation_style_raw"),
            defaultDocumentModeRaw: try row.text("default_document_mode_raw"),
            researchLoggingEnabled: try row.bool("research_logging_enabled"), listOrderJSON: try row.text("list_order_json"))
    }

    // MARK: A row's values

    /// One row's values, read as the import and the routes write them; a value that does not read as
    /// its column's names the row, never what it holds.
    struct Fields {
        let table: String
        let values: [String: SQLiteValue]

        init(_ table: String, _ row: ExportRow) {
            self.table = table
            values = row.values
        }

        func malformed(_ column: String, _ detail: String) -> ResearchExportError {
            .malformed(table: table, id: values["id"]?.text, column: column, detail: detail)
        }

        func optionalText(_ column: String) -> String? { values[column]?.text }

        func text(_ column: String) throws -> String {
            guard let text = optionalText(column) else { throw malformed(column, "is empty") }
            return text
        }

        func optionalInt(_ column: String) throws -> Int? {
            guard let value = values[column], value != .null else { return nil }
            guard let integer = value.integer else { throw malformed(column, "is not a whole number") }
            return Int(integer)
        }

        func int(_ column: String) throws -> Int {
            guard let value = try optionalInt(column) else { throw malformed(column, "is empty") }
            return value
        }

        func real(_ column: String) throws -> Double {
            switch values[column] {
            case .real(let value)?: return value
            case .integer(let value)?: return Double(value)
            default: throw malformed(column, "is not a number")
            }
        }

        func optionalBool(_ column: String) throws -> Bool? { try optionalInt(column).map { $0 != 0 } }

        func bool(_ column: String) throws -> Bool { try int(column) != 0 }

        func optionalDate(_ column: String) throws -> Date? {
            guard let text = optionalText(column) else { return nil }
            guard let date = UserStoreDate.date(text) else { throw malformed(column, "is no time the store writes") }
            return date
        }

        func date(_ column: String) throws -> Date {
            guard let date = try optionalDate(column) else { throw malformed(column, "is empty") }
            return date
        }

        func optionalUUID(_ column: String) throws -> UUID? {
            guard let text = optionalText(column) else { return nil }
            guard let id = UUID(uuidString: text) else { throw malformed(column, "is not a UUID") }
            return id
        }

        func uuid(_ column: String) throws -> UUID {
            guard let id = try optionalUUID(column) else { throw malformed(column, "is empty") }
            return id
        }

        func strings(_ column: String) throws -> [String] {
            guard let list = TagReferences.decode(try text(column)) else { throw malformed(column, "is not a list of strings") }
            return list
        }

        func uuids(_ column: String) throws -> [UUID] {
            try strings(column).map { text in
                guard let id = UUID(uuidString: text) else { throw malformed(column, "holds an id that is not a UUID") }
                return id
            }
        }

        func data(_ column: String) -> Data? {
            switch values[column] {
            case .blob(let bytes)?: Data(bytes)
            case .text(let text)?: Data(text.utf8)
            default: nil
            }
        }

        /// A `Codable` value the import writes with a plain `JSONEncoder()`, as the app's setters do.
        func optionalJSON<T: Decodable>(_ type: T.Type, _ column: String) throws -> T? {
            guard let text = optionalText(column) else { return nil }
            do {
                return try JSONDecoder().decode(T.self, from: Data(text.utf8))
            } catch {
                throw malformed(column, "does not read as the app's \(T.self)")
            }
        }

        func json<T: Decodable>(_ type: T.Type, _ column: String) throws -> T {
            guard let value = try optionalJSON(type, column) else { throw malformed(column, "is empty") }
            return value
        }

        /// A blob as the app's getter reads it, `try?`: none when it is absent or does not decode.
        func appJSON<T: Decodable>(_ type: T.Type, _ column: String) -> T? {
            optionalText(column).flatMap { try? JSONDecoder().decode(T.self, from: Data($0.utf8)) }
        }
    }
}
