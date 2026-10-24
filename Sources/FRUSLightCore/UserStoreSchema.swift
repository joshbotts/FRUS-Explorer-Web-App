// The user store's tables (S14a): one for each of the 23 model types in the app's `frusModelTypes`,
// with a column for each of their stored properties at the pin. UserStoreParityTests holds this
// list to the app's source and to the store that migrations build.

import Foundation

/// What the user store keeps for each of the Mac's model types, as `UserStoreMigrations` creates it.
///
/// A table is the model's, named as SPEC's mapping names it, and a column is one stored property's,
/// named in snake case: `volumeIdA` is `volume_id_a`, `listOrderJSON` is `list_order_json`. A row
/// keeps the Mac's own id as its key, so it keeps its identity through an import and an export. A
/// user table's rows are each one user's, and its key starts with `user_id`; the two override
/// types are instance-wide, since they correct the index every user shares. A relationship is kept
/// by the id the Mac keeps beside it: an entry's `collection` by its `collectionId`, and the
/// collection's `documentEntries` by the entries that name it. Nothing else in the store refers to
/// another row, since the Mac's own references are ids that can outlive what they name, as a tag
/// deleted on another device can.
public enum UserStoreSchema {
    public enum Scope: String, Sendable {
        /// Each row is one user's.
        case user
        /// One set of rows for the whole instance.
        case instance
    }

    /// How a column holds its property's value.
    public enum Kind: String, Sendable {
        /// A `String`, or an enumeration's raw `String` value.
        case text
        /// A `UUID`, as its `uuidString`.
        case uuid
        case integer
        case real
        /// `Bool`, as 0 or 1.
        case boolean
        /// A `Date`, as `UserStoreDate` writes it.
        case date
        /// `Data` kept as its bytes: a note's or a collection's RTF, or a payload the app has not
        /// yet defined.
        case blob
        /// JSON text: an array, a `Codable` value, or `Data` the app writes with `JSONEncoder`,
        /// kept as the bytes it wrote, with that encoder's own strategies: a date in a saved
        /// search's `freshnessData` is seconds since 2001, which the app's decoder reads back.
        case json

        /// The column's declared type.
        public var sqlType: String {
            switch self {
            case .text, .uuid, .date, .json: "TEXT"
            case .integer, .boolean: "INTEGER"
            case .real: "REAL"
            case .blob: "BLOB"
            }
        }
    }

    /// One stored property and its column.
    public struct Column: Sendable, Equatable {
        /// The property's name in the app's model.
        public let property: String
        public let kind: Kind
        /// Whether the property is optional; only then may the column hold NULL.
        public let optional: Bool

        public init(_ property: String, _ kind: Kind, optional: Bool = false) {
            self.property = property
            self.kind = kind
            self.optional = optional
        }

        public var name: String { UserStoreSchema.columnName(property) }
    }

    /// A stored property that is a relationship, which has no column of its own.
    public enum Relationship: Sendable, Equatable {
        /// The model's property `property` names one row, by the id the model keeps in `heldBy`.
        case toOne(String, heldBy: String)
        /// The model's property `property` lists the rows of `table` whose `heldBy` names it.
        case toMany(String, table: String, heldBy: String)

        public var property: String {
            switch self {
            case .toOne(let property, _), .toMany(let property, _, _): property
            }
        }
    }

    /// One model type's table.
    public struct Table: Sendable {
        /// The model type's name in the app.
        public let model: String
        public let name: String
        public let scope: Scope
        public let columns: [Column]
        public let relationships: [Relationship]

        public init(_ model: String, _ name: String, _ scope: Scope, _ columns: [Column], relationships: [Relationship] = []) {
            self.model = model
            self.name = name
            self.scope = scope
            self.columns = columns
            self.relationships = relationships
        }

        /// The key: the Mac's id, after `user_id` in a user table. `SyncedPreferences` has no id,
        /// and a user has one set of preferences.
        public var primaryKey: [String] {
            let keyedByID = columns.contains { $0.property == "id" }
            return switch scope {
            case .user: keyedByID ? ["user_id", "id"] : ["user_id"]
            case .instance: ["id"]
            }
        }

        /// The model's stored properties, relationships included.
        public var properties: [String] { columns.map(\.property) + relationships.map(\.property) }
    }

    /// The tables, in SPEC's order, each with its columns in the order the model declares them.
    public static let tables: [Table] = [
        Table("ResearchNote", "notes", .user, [
            Column("id", .uuid),
            Column("documentId", .text),
            Column("volumeId", .text),
            Column("bodyText", .text),
            Column("richText", .blob, optional: true),
            Column("projectIds", .json),
            Column("userTagIds", .json),
            Column("selectedSummaryIds", .json),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ]),
        Table("DocumentHighlight", "highlights", .user, [
            Column("id", .uuid),
            Column("volumeId", .text),
            Column("documentId", .text),
            Column("startOffset", .integer),
            Column("endOffset", .integer),
            Column("colorTag", .text),
            Column("noteId", .uuid, optional: true),
            Column("selectedText", .text),
            Column("renderingVersion", .text),
            Column("createdAt", .date, optional: true),
        ]),
        Table("UserTag", "tags", .user, [
            Column("id", .uuid),
            Column("name", .text),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ]),
        Table("DocumentTagAssignment", "tag_assignments", .user, [
            Column("id", .uuid),
            Column("volumeId", .text),
            Column("documentId", .text),
            Column("tagId", .uuid),
            Column("createdAt", .date, optional: true),
        ]),
        Table("Collection", "collections", .user, [
            Column("id", .uuid),
            Column("name", .text),
            Column("note", .text, optional: true),
            Column("subtitle", .text, optional: true),
            Column("authorLine", .text, optional: true),
            Column("introductionText", .text, optional: true),
            Column("introductionRichText", .blob, optional: true),
            Column("includeColophon", .boolean),
            Column("includeProjectProvenance", .boolean),
            Column("includeMethodAppendix", .boolean),
            Column("projectIds", .json),
            Column("savedSearchId", .uuid, optional: true),
            Column("defaultBodyDepth", .text),
            Column("footnoteStyle", .text),
            Column("includeFootnotes", .boolean, optional: true),
            Column("includeSourceNote", .boolean, optional: true),
            Column("tocStyle", .text),
            Column("applyHighlights", .boolean),
            Column("includeNotes", .boolean),
            Column("includeWordCloud", .boolean),
            Column("defaultIncludeHeadnote", .boolean),
            Column("summaryPromptId", .uuid, optional: true),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ], relationships: [
            .toMany("documentEntries", table: "collection_entries", heldBy: "collectionId"),
        ]),
        Table("CollectionEntry", "collection_entries", .user, [
            Column("id", .uuid),
            Column("collectionId", .uuid),
            Column("documentId", .text),
            Column("volumeId", .text),
            Column("titleOverride", .text, optional: true),
            Column("sortOrder", .integer),
            Column("level", .integer),
            Column("researchNoteId", .uuid, optional: true),
            Column("selectedNoteIds", .json),
            Column("bodyDepthOverride", .text, optional: true),
            Column("applyHighlightsOverride", .boolean, optional: true),
            Column("includeNotesOverride", .boolean, optional: true),
            Column("includeSourceNoteOverride", .boolean, optional: true),
            Column("includeFootnotesOverride", .boolean, optional: true),
            Column("summaryPromptIdOverride", .uuid, optional: true),
            Column("selectedHighlightIds", .json),
            Column("includeRelatedDocuments", .boolean, optional: true),
            Column("includeHeadnote", .boolean, optional: true),
            Column("headnoteSummaryId", .uuid, optional: true),
            Column("excerptStart", .integer, optional: true),
            Column("excerptEnd", .integer, optional: true),
            Column("excerptRenderingVersion", .text, optional: true),
            Column("excerptColorTag", .text, optional: true),
            Column("kind", .text),
            Column("generatedBlockType", .text, optional: true),
            Column("text", .text, optional: true),
            Column("richText", .blob, optional: true),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ], relationships: [
            .toOne("collection", heldBy: "collectionId"),
        ]),
        Table("Project", "projects", .user, [
            Column("id", .uuid),
            Column("name", .text),
            Column("researchQuestion", .text, optional: true),
            Column("defaultDateRangeStart", .date, optional: true),
            Column("defaultDateRangeEnd", .date, optional: true),
            Column("defaultSubjectTagIds", .json),
            Column("defaultCountryTagIds", .json),
            Column("leadAxisWeights", .text, optional: true),
            Column("defaultUserTagIds", .json),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ]),
        Table("ProjectLeadEntry", "project_leads", .user, [
            Column("id", .uuid),
            Column("projectId", .uuid),
            Column("volumeId", .text),
            Column("documentId", .text),
            Column("aggregateScore", .real),
            Column("contributingSeedKeys", .json),
            Column("header", .text),
            Column("documentNumber", .text, optional: true),
            Column("isEditorialNote", .boolean),
            Column("firstSurfacedAt", .date),
            Column("lastComputedAt", .date),
            Column("dismissed", .boolean),
        ]),
        Table("SavedSearch", "saved_searches", .user, [
            Column("id", .uuid),
            Column("name", .text),
            Column("queryText", .text),
            Column("phraseText", .text),
            Column("prefixWildcard", .text),
            Column("booleanModeRaw", .text),
            Column("excludedTermsCSV", .text),
            Column("scopeFlags", .integer),
            Column("dateRangeStart", .date, optional: true),
            Column("dateRangeEnd", .date, optional: true),
            Column("subjectTagIdsCSV", .text),
            Column("documentTypeFilterRaw", .text),
            Column("personRef", .text),
            Column("sortOrder", .text),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
            Column("parametersData", .json, optional: true),
            Column("freshnessData", .json, optional: true),
        ]),
        Table("WorkingCorpus", "working_corpora", .user, [
            Column("id", .uuid),
            Column("name", .text),
            Column("documentKeys", .json),
            Column("capturedAt", .date, optional: true),
            Column("sourceQuery", .text, optional: true),
            Column("sourceDescription", .text, optional: true),
            Column("indexedVolumeCountAtCapture", .integer, optional: true),
            Column("wasTruncatedAtCapture", .boolean, optional: true),
            Column("totalMatchCountAtCapture", .integer, optional: true),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ]),
        Table("CustomVolumeScope", "volume_scopes", .user, [
            Column("id", .uuid),
            Column("name", .text),
            Column("volumeIds", .json),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ]),
        Table("ReadingHistoryEntry", "trail_reading", .user, [
            Column("id", .uuid),
            Column("documentId", .text),
            Column("volumeId", .text),
            Column("displayTitle", .text, optional: true),
            Column("projectId", .uuid, optional: true),
            Column("accessedAt", .date, optional: true),
        ]),
        Table("SearchHistoryEntry", "trail_search", .user, [
            Column("id", .uuid),
            Column("queryText", .text),
            Column("resultCount", .integer),
            Column("projectId", .uuid, optional: true),
            Column("executedAt", .date, optional: true),
            Column("loadedCount", .integer, optional: true),
            Column("matchCount", .integer, optional: true),
            Column("fetchLimit", .integer, optional: true),
            Column("indexedVolumeCount", .integer, optional: true),
            Column("scopeSignature", .text, optional: true),
            Column("appliedCorpusId", .uuid, optional: true),
            Column("renderedExpression", .text, optional: true),
        ]),
        Table("ExportHistoryEntry", "trail_export", .user, [
            Column("id", .uuid),
            Column("format", .text),
            Column("documentCount", .integer),
            Column("collectionName", .text, optional: true),
            Column("projectId", .uuid, optional: true),
            Column("exportedAt", .date, optional: true),
        ]),
        Table("ArchiveVisitPlan", "visit_plans", .user, [
            Column("id", .uuid),
            Column("name", .text),
            Column("inquiryText", .text, optional: true),
            Column("projectIds", .json),
            Column("tiersData", .json, optional: true),
            Column("deliverableTogglesData", .json, optional: true),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ], relationships: [
            .toMany("documents", table: "visit_documents", heldBy: "planId"),
            .toMany("targets", table: "visit_targets", heldBy: "planId"),
        ]),
        Table("ArchiveVisitDocument", "visit_documents", .user, [
            Column("id", .uuid),
            Column("planId", .uuid),
            Column("documentKey", .text),
            Column("includeSource", .boolean),
            Column("includeExternalRefs", .boolean),
            Column("stateData", .blob, optional: true),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ], relationships: [
            .toOne("plan", heldBy: "planId"),
        ]),
        Table("ArchiveVisitTarget", "visit_targets", .user, [
            Column("id", .uuid),
            Column("planId", .uuid),
            Column("targetKey", .text),
            Column("tierId", .uuid, optional: true),
            Column("included", .boolean),
            Column("userNote", .text, optional: true),
            Column("stateData", .blob, optional: true),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ], relationships: [
            .toOne("plan", heldBy: "planId"),
        ]),
        Table("GeneratedSummary", "summaries", .user, [
            Column("id", .uuid),
            Column("documentId", .text),
            Column("volumeId", .text),
            Column("promptId", .uuid),
            Column("responseText", .text),
            Column("responseFormat", .json),
            Column("wasChunked", .boolean),
            Column("authorship", .text, optional: true),
            Column("isHeadnoteDraft", .boolean),
            Column("sourceContentHash", .text, optional: true),
            Column("projectId", .uuid, optional: true),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ]),
        Table("SummarizationPrompt", "prompts", .user, [
            Column("id", .uuid),
            Column("name", .text),
            Column("promptText", .text),
            Column("responseFormat", .json),
            Column("isStandard", .boolean),
            Column("schema", .json, optional: true),
            Column("createdAt", .date, optional: true),
            Column("lastModified", .date, optional: true),
        ]),
        Table("AnnotationReview", "annotation_reviews", .user, [
            Column("id", .uuid),
            Column("annotationType", .text),
            Column("annotationId", .uuid, optional: true),
            Column("volumeId", .text),
            Column("documentId", .text),
            Column("contentHash", .text),
            Column("changeKind", .text, optional: true),
            Column("reviewedAt", .date, optional: true),
        ]),
        Table("SyncedPreferences", "preferences", .user, [
            Column("createdAt", .date),
            Column("updatedAt", .date),
            Column("wcMinLength", .integer),
            Column("wcMinCount", .integer),
            Column("wcFoldPlurals", .boolean),
            Column("wcFilterMarkings", .boolean),
            Column("wcExcludeBoilerplate", .boolean),
            Column("wcGlobalStopwordsJSON", .text),
            Column("wcLensStopwordsJSON", .text),
            Column("citationStyleRaw", .text),
            Column("defaultDocumentModeRaw", .text),
            Column("researchLoggingEnabled", .boolean),
            Column("listOrderJSON", .text),
        ]),
        Table("PersonClusterOverride", "person_overrides", .instance, [
            Column("id", .uuid),
            Column("kind", .text),
            Column("volumeIdA", .text),
            Column("refA", .text),
            Column("volumeIdB", .text, optional: true),
            Column("refB", .text, optional: true),
            Column("createdAt", .date, optional: true),
        ]),
        Table("DocumentClassificationOverride", "classification_overrides", .instance, [
            Column("id", .uuid),
            Column("volumeId", .text),
            Column("documentId", .text),
            Column("isEditorialNote", .boolean),
            Column("parsedIsEditorialNote", .boolean),
            Column("createdAt", .date, optional: true),
        ]),
    ]

    /// The table for the app's model type `model`.
    public static func table(for model: String) -> Table? { tables.first { $0.model == model } }

    /// A property's column name: snake case, with a run of capitals read as one word, so
    /// `volumeIdA` is `volume_id_a` and `listOrderJSON` is `list_order_json`.
    public static func columnName(_ property: String) -> String {
        let characters = Array(property)
        var name = ""
        for (index, character) in characters.enumerated() {
            if character.isUppercase, index > 0 {
                let previous = characters[index - 1]
                let next = index + 1 < characters.count ? characters[index + 1] : nil
                if previous.isLowercase || previous.isNumber || (previous.isUppercase && next?.isLowercase == true) {
                    name.append("_")
                }
            }
            name.append(contentsOf: character.lowercased())
        }
        return name
    }
}
