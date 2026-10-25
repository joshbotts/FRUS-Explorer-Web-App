// A user's research read back from the user store as the kit's records (PLAN's S16c), for the import's
// check: each table read by its own SQL, beside the import's mapping rather than through it, into the
// kit's envelope at a file's format version, so that what a Mac JSON export brought can be held to the
// file field for field, in the tests and by `frus-parity import-check` on an export it is given. A
// field or a type a file of that version cannot carry reads as none, as it is in such a file.

import FRUSCoreKit
import FRUSLightCore
import Foundation

public enum StoredResearch {
    /// The user's records in the store at `url`, as an envelope of `formatVersion` with `header`'s
    /// date and project, which the store does not keep. A user's highlights give each note its
    /// `linkedHighlightIds`, as the app's exporter derives them.
    public static func envelope(at url: URL, user: String, formatVersion version: Int,
                                header: ResearchDataEnvelope) throws -> ResearchDataEnvelope {
        let db = try SQLiteConnection(url.path, readOnly: true)
        defer { db.close() }
        let reader = Reader(db: db, user: user)

        let highlights = try reader.rows("highlights").map { row in
            DocumentHighlightExport(id: row.uuid("id"), volumeId: row.text("volume_id"), documentId: row.text("document_id"),
                                    startOffset: row.int("start_offset"), endOffset: row.int("end_offset"),
                                    colorTag: row.text("color_tag"), noteId: row.optionalUUID("note_id"),
                                    selectedText: row.text("selected_text"), renderingVersion: row.text("rendering_version"),
                                    createdAt: row.date("created_at"))
        }
        var links: [UUID: [UUID]] = [:]
        for highlight in highlights { if let note = highlight.noteId { links[note, default: []].append(highlight.id) } }

        let notes = try reader.rows("notes").map { row in
            let id = row.uuid("id")
            return ResearchNoteExport(
                id: id, documentId: row.text("document_id"), volumeId: row.text("volume_id"), bodyText: row.text("body_text"),
                projectIds: row.uuids("project_ids"), userTagIds: row.uuids("user_tag_ids"),
                selectedSummaryIds: row.uuids("selected_summary_ids"), linkedHighlightIds: links[id] ?? [],
                createdAt: row.date("created_at"), lastModified: row.date("last_modified"),
                richText: version >= 7 ? row.data("rich_text") : nil)
        }
        let tags = try reader.rows("tags").map { row in
            UserTagExport(id: row.uuid("id"), name: row.text("name"), createdAt: row.date("created_at"),
                          lastModified: row.date("last_modified"))
        }
        let assignments = try reader.rows("tag_assignments").map { row in
            DocumentTagAssignmentExport(id: row.uuid("id"), volumeId: row.text("volume_id"), documentId: row.text("document_id"),
                                        tagId: row.uuid("tag_id"), createdAt: row.date("created_at"))
        }
        let entries = try Dictionary(grouping: reader.rows("collection_entries"), by: { $0.uuid("collection_id") })
        let collections = try reader.rows("collections").map { row in
            let v7 = version >= 7
            return CollectionExport(
                id: row.uuid("id"), name: row.text("name"), note: row.optionalText("note"), projectIds: row.uuids("project_ids"),
                savedSearchId: row.optionalUUID("saved_search_id"),
                entries: (entries[row.uuid("id")] ?? []).map { entry($0, version: version) },
                createdAt: row.date("created_at"), lastModified: row.date("last_modified"),
                subtitle: v7 ? row.optionalText("subtitle") : nil, authorLine: v7 ? row.optionalText("author_line") : nil,
                introductionText: v7 ? row.optionalText("introduction_text") : nil,
                introductionRichText: v7 ? row.data("introduction_rich_text") : nil,
                includeColophon: v7 ? row.bool("include_colophon") : nil,
                includeProjectProvenance: v7 ? row.bool("include_project_provenance") : nil,
                includeMethodAppendix: v7 ? row.bool("include_method_appendix") : nil,
                defaultBodyDepth: v7 ? row.text("default_body_depth") : nil, footnoteStyle: v7 ? row.text("footnote_style") : nil,
                includeFootnotes: v7 ? row.optionalBool("include_footnotes") : nil,
                includeSourceNote: v7 ? row.optionalBool("include_source_note") : nil,
                tocStyle: v7 ? row.text("toc_style") : nil, applyHighlights: v7 ? row.bool("apply_highlights") : nil,
                includeNotes: v7 ? row.bool("include_notes") : nil, includeWordCloud: v7 ? row.bool("include_word_cloud") : nil,
                defaultIncludeHeadnote: v7 ? row.bool("default_include_headnote") : nil,
                summaryPromptId: v7 ? row.optionalUUID("summary_prompt_id") : nil)
        }
        let prompts = try reader.rows("prompts").map { row in
            SummarizationPromptExport(id: row.uuid("id"), name: row.text("name"), promptText: row.text("prompt_text"),
                                      responseFormat: try row.json(ResponseFormat.self, "response_format"),
                                      schema: try row.optionalJSON(StructuredSummarySchema.self, "schema"),
                                      createdAt: row.date("created_at"), lastModified: row.date("last_modified"))
        }
        let projects = try reader.rows("projects").map { row in
            ProjectExport(id: row.uuid("id"), name: row.text("name"), researchQuestion: row.optionalText("research_question"),
                          defaultDateRangeStart: row.date("default_date_range_start"),
                          defaultDateRangeEnd: row.date("default_date_range_end"),
                          defaultSubjectTagIds: row.strings("default_subject_tag_ids"),
                          defaultCountryTagIds: row.strings("default_country_tag_ids"), createdAt: row.date("created_at"),
                          lastModified: row.date("last_modified"),
                          defaultUserTagIds: version >= 7 ? row.uuids("default_user_tag_ids") : nil,
                          leadAxisWeights: version >= 7 ? row.optionalText("lead_axis_weights") : nil)
        }
        let summaries = try reader.rows("summaries").map { row in
            GeneratedSummaryExport(
                id: row.uuid("id"), documentId: row.text("document_id"), volumeId: row.text("volume_id"),
                promptId: row.uuid("prompt_id"), responseText: row.text("response_text"),
                responseFormat: try row.json(ResponseFormat.self, "response_format"), wasChunked: row.bool("was_chunked"),
                projectId: row.optionalUUID("project_id"), createdAt: row.date("created_at"), lastModified: row.date("last_modified"),
                authorship: version >= 5 ? row.optionalText("authorship").flatMap(SummaryAuthorship.init(rawValue:)) : nil,
                isHeadnoteDraft: version >= 7 ? row.bool("is_headnote_draft") : nil)
        }

        var envelope = ResearchDataEnvelope(
            formatVersion: version, exportedAt: header.exportedAt, exportedForProjectName: header.exportedForProjectName,
            exportedForProjectResearchQuestion: header.exportedForProjectResearchQuestion, notes: notes, tags: tags,
            tagAssignments: assignments, highlights: highlights, collections: collections, prompts: prompts, projects: projects,
            summaries: summaries)
        if version >= 3 {
            envelope.readingHistory = try reader.rows("trail_reading").map { row in
                ReadingHistoryEntryExport(id: row.uuid("id"), documentId: row.text("document_id"), volumeId: row.text("volume_id"),
                                          displayTitle: row.optionalText("display_title"), projectId: row.optionalUUID("project_id"),
                                          accessedAt: row.date("accessed_at"))
            }
            envelope.searchHistory = try reader.rows("trail_search").map { row in
                let v4 = version >= 4
                return SearchHistoryEntryExport(
                    id: row.uuid("id"), queryText: row.text("query_text"), resultCount: row.int("result_count"),
                    projectId: row.optionalUUID("project_id"), executedAt: row.date("executed_at"),
                    loadedCount: v4 ? row.optionalInt("loaded_count") : nil, matchCount: v4 ? row.optionalInt("match_count") : nil,
                    fetchLimit: v4 ? row.optionalInt("fetch_limit") : nil,
                    indexedVolumeCount: v4 ? row.optionalInt("indexed_volume_count") : nil,
                    scopeSignature: v4 ? row.optionalText("scope_signature") : nil,
                    appliedCorpusId: v4 ? row.optionalUUID("applied_corpus_id") : nil,
                    renderedExpression: v4 ? row.optionalText("rendered_expression") : nil)
            }
            envelope.exportHistory = try reader.rows("trail_export").map { row in
                ExportHistoryEntryExport(id: row.uuid("id"), format: row.text("format"), documentCount: row.int("document_count"),
                                         collectionName: row.optionalText("collection_name"),
                                         projectId: row.optionalUUID("project_id"), exportedAt: row.date("exported_at"))
            }
        }
        if version >= 6 {
            let documents = try Dictionary(grouping: reader.rows("visit_documents"), by: { $0.uuid("plan_id") })
            let targets = try Dictionary(grouping: reader.rows("visit_targets"), by: { $0.uuid("plan_id") })
            envelope.archiveVisits = try reader.rows("visit_plans").map { row in
                let id = row.uuid("id")
                return ArchiveVisitPlanExport(
                    id: id, name: row.text("name"), inquiryText: row.optionalText("inquiry_text"), projectIds: row.uuids("project_ids"),
                    tiers: try row.optionalJSON([ArchiveVisitTier].self, "tiers_data") ?? [],
                    deliverables: try row.optionalJSON(ArchiveVisitDeliverables.self, "deliverable_toggles_data")
                        ?? ArchiveVisitDeliverables(),
                    documents: (documents[id] ?? []).map { document in
                        ArchiveVisitDocumentExport(id: document.uuid("id"), documentKey: document.text("document_key"),
                                                   includeSource: document.bool("include_source"),
                                                   includeExternalRefs: document.bool("include_external_refs"),
                                                   createdAt: document.date("created_at"),
                                                   lastModified: document.date("last_modified"))
                    },
                    targets: (targets[id] ?? []).map { target in
                        ArchiveVisitTargetExport(id: target.uuid("id"), targetKey: target.text("target_key"),
                                                 tierId: target.optionalUUID("tier_id"), included: target.bool("included"),
                                                 userNote: target.optionalText("user_note"), createdAt: target.date("created_at"),
                                                 lastModified: target.date("last_modified"))
                    },
                    createdAt: row.date("created_at"), lastModified: row.date("last_modified"))
            }
        }
        if version >= 7 {
            envelope.savedSearches = try reader.rows("saved_searches").map { row in
                let freshness = try row.optionalJSON(Freshness.self, "freshness_data")
                return SavedSearchExport(
                    id: row.uuid("id"), name: row.text("name"), parameters: try row.json(SearchParameters.self, "parameters_data"),
                    lastRunAt: freshness?.lastRunAt, matchCountAtLastRun: freshness?.matchCountAtLastRun,
                    indexedVolumeCountAtLastRun: freshness?.indexedVolumeCountAtLastRun, createdAt: row.date("created_at"),
                    lastModified: row.date("last_modified"))
            }
            envelope.workingCorpora = try reader.rows("working_corpora").map { row in
                WorkingCorpusExport(id: row.uuid("id"), name: row.text("name"), documentKeys: row.strings("document_keys"),
                                    capturedAt: row.date("captured_at"), sourceQuery: row.optionalText("source_query"),
                                    sourceDescription: row.optionalText("source_description"),
                                    indexedVolumeCountAtCapture: row.optionalInt("indexed_volume_count_at_capture"),
                                    wasTruncatedAtCapture: row.optionalBool("was_truncated_at_capture"),
                                    totalMatchCountAtCapture: row.optionalInt("total_match_count_at_capture"),
                                    createdAt: row.date("created_at"), lastModified: row.date("last_modified"))
            }
            envelope.customVolumeScopes = try reader.rows("volume_scopes").map { row in
                CustomVolumeScopeExport(id: row.uuid("id"), name: row.text("name"), volumeIds: row.strings("volume_ids"),
                                        createdAt: row.date("created_at"), lastModified: row.date("last_modified"))
            }
            envelope.classificationOverrides = try reader.rows("classification_overrides", instance: true).map { row in
                DocumentClassificationOverrideExport(id: row.uuid("id"), volumeId: row.text("volume_id"),
                                                     documentId: row.text("document_id"),
                                                     isEditorialNote: row.bool("is_editorial_note"),
                                                     parsedIsEditorialNote: row.bool("parsed_is_editorial_note"),
                                                     createdAt: row.date("created_at"))
            }
            envelope.personClusterOverrides = try reader.rows("person_overrides", instance: true).map { row in
                PersonClusterOverrideExport(id: row.uuid("id"), kind: row.text("kind"), volumeIdA: row.text("volume_id_a"),
                                            refA: row.text("ref_a"), volumeIdB: row.optionalText("volume_id_b"),
                                            refB: row.optionalText("ref_b"), createdAt: row.date("created_at"))
            }
            envelope.annotationReviews = try reader.rows("annotation_reviews").map { row in
                AnnotationReviewExport(id: row.uuid("id"), annotationType: row.text("annotation_type"),
                                       annotationId: row.optionalUUID("annotation_id"), volumeId: row.text("volume_id"),
                                       documentId: row.text("document_id"), contentHash: row.text("content_hash"),
                                       changeKind: row.optionalText("change_kind"), reviewedAt: row.date("reviewed_at"))
            }
            envelope.projectLeads = try reader.rows("project_leads").map { row in
                ProjectLeadEntryExport(id: row.uuid("id"), projectId: row.uuid("project_id"), volumeId: row.text("volume_id"),
                                       documentId: row.text("document_id"), aggregateScore: row.real("aggregate_score"),
                                       contributingSeedKeys: row.strings("contributing_seed_keys"), header: row.text("header"),
                                       documentNumber: row.optionalText("document_number"),
                                       isEditorialNote: row.bool("is_editorial_note"),
                                       firstSurfacedAt: row.date("first_surfaced_at") ?? .distantPast,
                                       lastComputedAt: row.date("last_computed_at") ?? .distantPast, dismissed: row.bool("dismissed"))
            }
            envelope.syncedPreferences = try reader.rows("preferences").map { row in
                SyncedPreferencesExport(
                    createdAt: row.date("created_at") ?? .distantPast, updatedAt: row.date("updated_at") ?? .distantPast,
                    wcMinLength: row.int("wc_min_length"), wcMinCount: row.int("wc_min_count"),
                    wcFoldPlurals: row.bool("wc_fold_plurals"), wcFilterMarkings: row.bool("wc_filter_markings"),
                    wcExcludeBoilerplate: row.bool("wc_exclude_boilerplate"),
                    wcGlobalStopwordsJSON: row.text("wc_global_stopwords_json"),
                    wcLensStopwordsJSON: row.text("wc_lens_stopwords_json"), citationStyleRaw: row.text("citation_style_raw"),
                    defaultDocumentModeRaw: row.text("default_document_mode_raw"),
                    researchLoggingEnabled: row.bool("research_logging_enabled"), listOrderJSON: row.text("list_order_json"))
            }
        }
        return envelope
    }

    /// A collection entry, its fields of version 7 none before it.
    private static func entry(_ row: Row, version: Int) -> CollectionEntryExport {
        let v7 = version >= 7
        return CollectionEntryExport(
            id: row.uuid("id"), documentId: row.text("document_id"), volumeId: row.text("volume_id"), sortOrder: row.int("sort_order"),
            researchNoteId: row.optionalUUID("research_note_id"), selectedNoteIds: row.uuids("selected_note_ids"),
            createdAt: row.date("created_at"), lastModified: row.date("last_modified"),
            kind: v7 ? row.text("kind") : nil, level: v7 ? row.int("level") : nil, text: v7 ? row.optionalText("text") : nil,
            richText: v7 ? row.data("rich_text") : nil, excerptStart: v7 ? row.optionalInt("excerpt_start") : nil,
            excerptEnd: v7 ? row.optionalInt("excerpt_end") : nil,
            excerptRenderingVersion: v7 ? row.optionalText("excerpt_rendering_version") : nil,
            excerptColorTag: v7 ? row.optionalText("excerpt_color_tag") : nil,
            generatedBlockType: v7 ? row.optionalText("generated_block_type") : nil,
            titleOverride: v7 ? row.optionalText("title_override") : nil,
            bodyDepthOverride: v7 ? row.optionalText("body_depth_override") : nil,
            applyHighlightsOverride: v7 ? row.optionalBool("apply_highlights_override") : nil,
            includeNotesOverride: v7 ? row.optionalBool("include_notes_override") : nil,
            includeSourceNoteOverride: v7 ? row.optionalBool("include_source_note_override") : nil,
            includeFootnotesOverride: v7 ? row.optionalBool("include_footnotes_override") : nil,
            summaryPromptIdOverride: v7 ? row.optionalUUID("summary_prompt_id_override") : nil,
            selectedHighlightIds: v7 ? row.uuids("selected_highlight_ids") : nil,
            includeRelatedDocuments: v7 ? row.optionalBool("include_related_documents") : nil,
            includeHeadnote: v7 ? row.optionalBool("include_headnote") : nil,
            headnoteSummaryId: v7 ? row.optionalUUID("headnote_summary_id") : nil)
    }

    /// The app's `SavedSearchFreshness` as its decoder reads the store's blob.
    private struct Freshness: Decodable {
        var lastRunAt: Date?
        var matchCountAtLastRun: Int?
        var indexedVolumeCountAtLastRun: Int?
    }

    /// The rows of one table, each by its columns' names.
    private struct Reader {
        let db: SQLiteConnection
        let user: String

        /// The user's rows of `table`, or an instance-wide table's every row.
        func rows(_ table: String, instance: Bool = false) throws -> [Row] {
            guard let schema = UserStoreSchema.tables.first(where: { $0.name == table }) else {
                throw ResearchImportError.unknownTable(table)
            }
            let columns = schema.columns.map(\.name)
            let rows = try db.query(
                "SELECT \(columns.joined(separator: ", ")) FROM \(table)" + (instance ? "" : " WHERE user_id = ?"),
                instance ? [] : [.text(user)])
            return rows.map { values in Row(values: Dictionary(uniqueKeysWithValues: zip(columns, values))) }
        }
    }

    /// One row's values, read as the import wrote them.
    private struct Row {
        let values: [String: SQLiteValue]

        func optionalText(_ column: String) -> String? { values[column]?.text }
        func text(_ column: String) -> String { optionalText(column) ?? "" }
        func optionalInt(_ column: String) -> Int? { values[column]?.integer.map(Int.init) }
        func int(_ column: String) -> Int { optionalInt(column) ?? 0 }
        func real(_ column: String) -> Double {
            switch values[column] {
            case .real(let value)?: value
            case .integer(let value)?: Double(value)
            default: 0
            }
        }
        func optionalBool(_ column: String) -> Bool? { values[column]?.integer.map { $0 != 0 } }
        func bool(_ column: String) -> Bool { optionalBool(column) ?? false }
        func date(_ column: String) -> Date? { optionalText(column).flatMap(UserStoreDate.date) }
        func optionalUUID(_ column: String) -> UUID? { optionalText(column).flatMap(UUID.init(uuidString:)) }
        func uuid(_ column: String) -> UUID { optionalUUID(column) ?? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)) }
        func strings(_ column: String) -> [String] { optionalText(column).flatMap(TagReferences.decode) ?? [] }
        func uuids(_ column: String) -> [UUID] { strings(column).compactMap(UUID.init(uuidString:)) }

        func data(_ column: String) -> Data? {
            switch values[column] {
            case .blob(let bytes)?: Data(bytes)
            case .text(let text)?: Data(text.utf8)
            default: nil
            }
        }

        func optionalJSON<T: Decodable>(_ type: T.Type, _ column: String) throws -> T? {
            guard let text = optionalText(column) else { return nil }
            return try JSONDecoder().decode(T.self, from: Data(text.utf8))
        }

        func json<T: Decodable>(_ type: T.Type, _ column: String) throws -> T {
            guard let value = try optionalJSON(type, column) else { throw Unreadable(column: column) }
            return value
        }
    }

    /// A column the import always writes, found empty.
    public struct Unreadable: Error, CustomStringConvertible {
        public let column: String
        public var description: String { "the store holds no \(column)" }
    }
}

/// How far the store holds what a file brought, type by type, by the records' ids.
public struct ResearchComparison: Sendable, Equatable {
    /// A model type's comparison: its records in the file, and those the store holds otherwise or
    /// not at all, each by id with the fields that differ, and never their values.
    public struct TypeComparison: Sendable, Equatable {
        public var type: String
        public var inFile = 0
        public var missing: [String] = []
        public var different: [(id: String, fields: [String])] = []

        public static func == (a: TypeComparison, b: TypeComparison) -> Bool {
            a.type == b.type && a.inFile == b.inFile && a.missing == b.missing
                && a.different.map(\.id) == b.different.map(\.id) && a.different.map(\.fields) == b.different.map(\.fields)
        }

        public var isWhole: Bool { missing.isEmpty && different.isEmpty }
    }

    public var types: [TypeComparison]

    public var isWhole: Bool { types.allSatisfy(\.isWhole) }

    /// The file's records beside the store's, as `StoredResearch` reads them at the file's version.
    /// A note's highlights are compared as a set, since the app's exporter gives them in no set
    /// order; a collection's entries and a plan's documents and targets are each their own type;
    /// and the store's one set of synced settings is the file's earliest.
    public static func compare(file: ResearchDataEnvelope, stored: ResearchDataEnvelope) -> ResearchComparison {
        func sortedLinks(_ note: ResearchNoteExport) -> ResearchNoteExport {
            var note = note
            note.linkedHighlightIds.sort { $0.uuidString < $1.uuidString }
            return note
        }
        func withoutEntries(_ collection: CollectionExport) -> CollectionExport {
            var collection = collection
            collection.entries = []
            return collection
        }
        func withoutSeeds(_ plan: ArchiveVisitPlanExport) -> ArchiveVisitPlanExport {
            var plan = plan
            plan.documents = []
            plan.targets = []
            return plan
        }
        let earliest: ([SyncedPreferencesExport]) -> [SyncedPreferencesExport] = { all in
            all.enumerated().min { ($0.element.createdAt, $0.offset) < ($1.element.createdAt, $1.offset) }.map { [$0.element] } ?? []
        }
        return ResearchComparison(types: [
            compared("ResearchNote", file.notes.map(sortedLinks), stored.notes.map(sortedLinks), id: \.id),
            compared("DocumentHighlight", file.highlights, stored.highlights, id: \.id),
            compared("UserTag", file.tags, stored.tags, id: \.id),
            compared("DocumentTagAssignment", file.tagAssignments, stored.tagAssignments, id: \.id),
            compared("Collection", file.collections.map(withoutEntries), stored.collections.map(withoutEntries), id: \.id),
            compared("CollectionEntry", file.collections.flatMap(\.entries), stored.collections.flatMap(\.entries), id: \.id),
            compared("Project", file.projects, stored.projects, id: \.id),
            compared("ProjectLeadEntry", file.projectLeads, stored.projectLeads, id: \.id),
            compared("SavedSearch", file.savedSearches, stored.savedSearches, id: \.id),
            compared("WorkingCorpus", file.workingCorpora, stored.workingCorpora, id: \.id),
            compared("CustomVolumeScope", file.customVolumeScopes, stored.customVolumeScopes, id: \.id),
            compared("ReadingHistoryEntry", file.readingHistory, stored.readingHistory, id: \.id),
            compared("SearchHistoryEntry", file.searchHistory, stored.searchHistory, id: \.id),
            compared("ExportHistoryEntry", file.exportHistory, stored.exportHistory, id: \.id),
            compared("ArchiveVisitPlan", file.archiveVisits.map(withoutSeeds), stored.archiveVisits.map(withoutSeeds), id: \.id),
            compared("ArchiveVisitDocument", file.archiveVisits.flatMap(\.documents), stored.archiveVisits.flatMap(\.documents), id: \.id),
            compared("ArchiveVisitTarget", file.archiveVisits.flatMap(\.targets), stored.archiveVisits.flatMap(\.targets), id: \.id),
            compared("GeneratedSummary", file.summaries, stored.summaries, id: \.id),
            compared("SummarizationPrompt", file.prompts, stored.prompts, id: \.id),
            compared("AnnotationReview", file.annotationReviews, stored.annotationReviews, id: \.id),
            compared("SyncedPreferences", earliest(file.syncedPreferences), stored.syncedPreferences, id: { _ in UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)) }),
            compared("PersonClusterOverride", file.personClusterOverrides, stored.personClusterOverrides, id: \.id),
            compared("DocumentClassificationOverride", file.classificationOverrides, stored.classificationOverrides, id: \.id),
        ])
    }

    private static func compared<T: Encodable & Equatable>(_ type: String, _ file: [T], _ stored: [T],
                                                            id: (T) -> UUID) -> TypeComparison {
        var comparison = TypeComparison(type: type, inFile: file.count)
        var held: [UUID: T] = [:]
        for record in stored { held[id(record)] = record }
        // A record the file gives twice is held as one of its copies, the newer of two that differ.
        var copies: [UUID: [T]] = [:]
        var order: [UUID] = []
        for record in file {
            if copies[id(record)] == nil { order.append(id(record)) }
            copies[id(record), default: []].append(record)
        }
        for key in order {
            let given = copies[key] ?? []
            guard let copy = held[key] else {
                comparison.missing.append(key.uuidString)
                continue
            }
            if !given.contains(copy), let first = given.first { comparison.different.append((key.uuidString, fields(first, copy))) }
        }
        return comparison
    }

    /// The fields whose values differ between two records, by their JSON keys.
    private static func fields<T: Encodable>(_ a: T, _ b: T) -> [String] {
        let encoder = ResearchDataEnvelope.makeEncoder()
        let decoder = JSONDecoder()
        guard let left = (try? encoder.encode(a)).flatMap({ try? decoder.decode([String: JSONValue].self, from: $0) }),
              let right = (try? encoder.encode(b)).flatMap({ try? decoder.decode([String: JSONValue].self, from: $0) }) else {
            return ["the record"]
        }
        return Set(left.keys).union(right.keys).sorted().filter { left[$0] != right[$0] }
    }

    /// Any JSON value, to compare two records' fields without reading them.
    private indirect enum JSONValue: Decodable, Equatable {
        case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() { self = .null }
            else if let value = try? container.decode(Bool.self) { self = .bool(value) }
            else if let value = try? container.decode(Double.self) { self = .number(value) }
            else if let value = try? container.decode(String.self) { self = .string(value) }
            else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
            else { self = .object(try container.decode([String: JSONValue].self)) }
        }
    }
}
