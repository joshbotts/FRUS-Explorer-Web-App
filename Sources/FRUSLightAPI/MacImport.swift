// A Mac JSON export as the user store imports it (PLAN's S16c), on the kit's plan since #1915's follow-up: the file
// read by the kit as an import reads it (`ResearchImportFile`), of any format version from 1 to the kit's; what the
// user holds read in the import's transaction as the kit's records, the export's own reading of the store's rows,
// into the kit's `ResearchLibrarySnapshot`; and the kit's `ResearchImportPlan` of the file against it, whose every
// decision the import takes (CLAUDE.md rule 4):
// - a record the store holds is replaced only by a newer copy, by the kit's `importStamp`;
// - a replacement writes `Item.written(over:)` of the store's copy: the fields the file's version carries, and the
//   store's for the rest, but for a field that describes a text the file replaces, which goes with the text (a note's
//   formatting from a file before version 7, a summary's authorship from one before version 5);
// - a new record takes the app's defaults for what its file cannot carry, and the app's reading of what an older file
//   does not say: a headnote draft by its prompt, an entry with no document inert, a summary with no author
//   AI-generated (`resolvedForImport`);
// - a record the file gives twice is planned once, and of several sets of synced preferences the earliest made is read.
// The SQL that writes the plan is the store's (`ResearchImportStore`), each record mapped to its table's row here, as
// the web's editors map theirs. The report's counts are the kit's `Report`, with the web's own lines beside it: the
// notes written with formatting this server cannot show, the notes and summaries whose text an older file replaced, as
// the app's done line counts them as it writes, and an instance's corrections set aside for a user who is no curator,
// as only a curator imports them here.

import FRUSCoreKit
import FRUSLightCore
import FRUSRichText
import FTS5Store
import Foundation

/// What a Mac JSON export brought to the store: for each model type, what the file held and what became of it, as the
/// kit's plan counts them, and what the import made of what an older file does not say.
public struct ResearchImportReport: Codable, Equatable, Sendable {
    /// The file's `formatVersion`, and when the Mac wrote it.
    public var formatVersion: Int
    public var exportedAt: String
    /// Each of the 23 model types, in the user store's order.
    public var types: [ImportTypeCount]
    /// The notes the import wrote with formatting, RTF, which only a file of version 7 carries, or a note an older file
    /// replaced keeps with a text it left as it was.
    public var formattedNotes: Int
    /// Of those, the notes whose RTF the codec cannot offer, which open as plain text until their body is edited on the
    /// web, their RTF kept as it is (`Note.formattingKept`).
    public var formattingKept: Int
    /// The notes whose text a file before version 7 replaced, and whose formatting went with it, as the kit's plan
    /// writes them: counted as the app's done line counts them, a note that had formatting written with none.
    public var notesMadePlain: Int
    /// The summaries whose text a file before version 5 replaced, which read as AI-generated since: one whose
    /// authorship was another written as AI-generated.
    public var summariesMadeAIGenerated: Int
    /// The file's summaries that are a collection's headnote draft, which no list or search shows.
    public var headnoteDrafts: Int
    /// The file's summaries with no authorship, as no file before version 5 has, read as AI summaries.
    public var summariesWithoutAuthorship: Int
    /// The collection entries the import added with no document from a file before version 7, which did not say what
    /// they were, as the kind the app treats as inert.
    public var inertEntries: Int
    /// The collections the import wrote that name a saved search neither the store nor the file holds, as the app
    /// shows one whose search was deleted.
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
    /// Records not written: synced settings after the earliest, which the app does not read, and an instance's
    /// corrections, which only a curator imports.
    public var setAside: Int
    /// Records whose id the file already gave, the same record exported twice: one copy is written, the newest, or of
    /// two as new the first, as a copy the store held would be kept.
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

/// The import, public for the parity harness, which imports an export it is given as the route's job does
/// (`frus-parity import-check`).
public enum MacImport {
    /// The format versions an import reads, the kit's.
    static let formatVersions = ResearchImportFile.supportedFormatVersions

    /// The model types, each with its table, in the user store's order: the kit's 23, `ResearchImportPlan.ModelType`,
    /// whose names are the app's.
    static let types: [(model: String, table: String)] = UserStoreSchema.tables.map { ($0.model, $0.name) }

    /// The tables of an instance's corrections, which only a curator imports.
    static let instanceTables = Set(UserStoreSchema.tables.filter { $0.scope == .instance }.map(\.name))

    // MARK: Reading the file

    /// The file's `formatVersion`, read before the rest, so that a file that is not an export, or of a version the
    /// server does not read, is refused at once.
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

    /// The file, read as the kit reads an export to import it: its envelope by the kit's tolerant decoder, and the
    /// web's key beside it (`ResearchImportFile(data:)`).
    public static func file(of data: Data) throws -> ResearchImportFile {
        try file(of: data, formatVersion: try formatVersion(of: data))
    }

    /// The same, of a file whose `formatVersion` has been read already: the route's job's, which parses the file once
    /// more, not twice.
    static func file(of data: Data, formatVersion version: Int) throws -> ResearchImportFile {
        let file: ResearchImportFile
        do {
            file = try ResearchImportFile(data: data)
        } catch let error as DecodingError {
            throw MacImportError.undecodable(describe(error))
        } catch ResearchImportFile.FormatError.newerFormatVersion(let version) {
            throw MacImportError.unsupportedVersion(version)
        } catch ResearchImportFile.FormatError.unknownFormatVersion(let version) {
            throw MacImportError.notAnExport("its formatVersion, \(version), is none the app writes.")
        }
        precondition(file.envelope.formatVersion == version)
        return file
    }

    /// The file's envelope, as `file(of:)` reads it.
    public static func envelope(of data: Data) throws -> ResearchDataEnvelope {
        try file(of: data).envelope
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

    /// Imports `file` into `store` under `user` in one transaction, by the kit's plan of it against what the user
    /// holds, and reports it. An instance's corrections are written only `includingInstanceWide`, for a curator.
    public static func run(_ file: ResearchImportFile, into store: any ResearchImportStore, for user: String,
                           includingInstanceWide: Bool) throws -> ResearchImportReport {
        var planned: Planned?
        let result = try store.importResearch(for: user) { held in
            let plan = try Planned(file: file, held: held, includingInstanceWide: includingInstanceWide)
            planned = plan
            return plan.writes
        }
        guard let planned else { preconditionFailure("the store wrote an import it was not given a plan for") }
        return planned.report(searchableDocuments: result.searchableDocuments)
    }

    /// The same, of an envelope already decoded, which carries no web key.
    public static func run(_ envelope: ResearchDataEnvelope, into store: any ResearchImportStore, for user: String,
                           includingInstanceWide: Bool) throws -> ResearchImportReport {
        try run(try ResearchImportFile(envelope: envelope), into: store, for: user, includingInstanceWide: includingInstanceWide)
    }

    /// What the store holds, read as the kit's records by the export's own reading of the rows: the snapshot the
    /// kit's plan compares a file with, and each record's copy, which a replacement is written over.
    struct HeldLibrary {
        private(set) var snapshot = ResearchLibrarySnapshot()
        /// By type and id, the copy a replacement is written over, and each spelling of its id the store holds: of
        /// copies stored under one id in other letter cases, the one changed last, as the snapshot holds the id at
        /// the latest of their stamps, and of copies as new the first the store took.
        private var copies: [ResearchImportPlan.ModelType: [UUID: Copy]] = [:]
        /// The user's set of synced preferences.
        private(set) var preferences: SyncedPreferencesExport?

        private struct Copy {
            var record: any ResearchImportRecord
            var ids: [String]
        }

        /// Every row of the 23 tables `rows` holds, each read as the export reads it: a row that does not read as the
        /// kit's record, which only a damaged store holds, refuses the import, as it refuses the export.
        init(_ rows: ResearchRows) throws {
            try hold(rows, "notes", \ResearchNoteExport.id) { try ResearchExport.note($0, links: [:]) }
            try hold(rows, "highlights", \DocumentHighlightExport.id, ResearchExport.highlight)
            try hold(rows, "tags", \UserTagExport.id, ResearchExport.tag)
            try hold(rows, "tag_assignments", \DocumentTagAssignmentExport.id, ResearchExport.assignment)
            try hold(rows, "collections", \CollectionExport.id) { try ResearchExport.collection($0, entries: []) }
            try hold(rows, "collection_entries", \CollectionEntryExport.id, ResearchExport.entry)
            try hold(rows, "projects", \ProjectExport.id, ResearchExport.project)
            try hold(rows, "project_leads", \ProjectLeadEntryExport.id, ResearchExport.lead)
            try hold(rows, "saved_searches", \SavedSearchExport.id, ResearchExport.savedSearch)
            try hold(rows, "working_corpora", \WorkingCorpusExport.id, ResearchExport.corpus)
            try hold(rows, "volume_scopes", \CustomVolumeScopeExport.id, ResearchExport.scope)
            try hold(rows, "trail_reading", \ReadingHistoryEntryExport.id, ResearchExport.reading)
            try hold(rows, "trail_search", \SearchHistoryEntryExport.id, ResearchExport.search)
            try hold(rows, "trail_export", \ExportHistoryEntryExport.id, ResearchExport.exported)
            try hold(rows, "visit_plans", \ArchiveVisitPlanExport.id) { try ResearchExport.plan($0, documents: [], targets: []) }
            try hold(rows, "visit_documents", \ArchiveVisitDocumentExport.id, ResearchExport.visitDocument)
            try hold(rows, "visit_targets", \ArchiveVisitTargetExport.id, ResearchExport.visitTarget)
            try hold(rows, "summaries", \GeneratedSummaryExport.id, ResearchExport.summary)
            try hold(rows, "prompts", \SummarizationPromptExport.id, ResearchExport.prompt)
            try hold(rows, "annotation_reviews", \AnnotationReviewExport.id, ResearchExport.review)
            try hold(rows, "person_overrides", \PersonClusterOverrideExport.id, ResearchExport.personCorrection)
            try hold(rows, "classification_overrides", \DocumentClassificationOverrideExport.id, ResearchExport.classificationCorrection)
            // One set a user, the store's key.
            for row in rows["preferences"] {
                let set = try ResearchExport.preferences(ResearchExport.Fields("preferences", row))
                snapshot.insertSyncedPreferences(createdAt: set.createdAt, updatedAt: set.updatedAt)
                if preferences == nil { preferences = set }
            }
        }

        private mutating func hold<Record: ResearchImportRecord>(_ rows: ResearchRows, _ table: String, _ id: KeyPath<Record, UUID>,
                                                                 _ read: (ResearchExport.Fields) throws -> Record) throws {
            for row in rows[table] {
                let record = try read(ResearchExport.Fields(table, row))
                let key = record[keyPath: id]
                snapshot.insert(Record.importModel, id: key, stamp: record.importStamp)
                let spelling = row.values["id"]?.text ?? key.uuidString
                guard var copy = copies[Record.importModel]?[key] else {
                    copies[Record.importModel, default: [:]][key] = Copy(record: record, ids: [spelling])
                    continue
                }
                copy.ids.append(spelling)
                if let held = copy.record as? Record, (record.importStamp ?? .distantPast) > (held.importStamp ?? .distantPast) {
                    copy.record = record
                }
                copies[Record.importModel]?[key] = copy
            }
        }

        /// The copy the store holds of the record `id`, with each spelling of its id, or nil.
        func copy<Record: ResearchImportRecord>(of id: UUID, as type: Record.Type) -> (record: Record, ids: [String])? {
            guard let copy = copies[Record.importModel]?[id], let record = copy.record as? Record else { return nil }
            return (record, copy.ids)
        }
    }

    /// A plan that does not fit the rows it was made from: a replacement of a record the store does not hold, or a
    /// child record with no parent, which only a mistake here makes.
    struct PlanMismatch: Error, CustomStringConvertible {
        let table: String
        var description: String { "the import's plan of \(table) does not fit what the store holds" }
    }

    /// The kit's plan of a file against the rows the store holds, and the rows it writes.
    struct Planned {
        let plan: ResearchImportPlan
        let includingInstanceWide: Bool
        private(set) var writes: [ImportWrite] = []
        /// The web's own lines, counted over what the import writes.
        private(set) var formattedNotes = 0, formattingKept = 0, notesMadePlain = 0, summariesMadeAIGenerated = 0

        init(file: ResearchImportFile, held rows: ResearchRows, includingInstanceWide: Bool) throws {
            let held = try HeldLibrary(rows)
            plan = ResearchImportPlan(file: file, library: held.snapshot)
            self.includingInstanceWide = includingInstanceWide
            let version = plan.formatVersion

            for (before, note) in try write(plan.notes, to: "notes", held, \.id, { note, _ in MacImport.note(note) }) {
                if note.richText != nil {
                    formattedNotes += 1
                    if NoteFormatting.runs(of: note.richText.map(Array.init), text: note.bodyText).kept { formattingKept += 1 }
                }
                // As the app's writer counts them (`ResearchImportWriter.countTextChange`).
                if let before, version < ResearchImportPlan.Fields.noteFormatting.since, before.richText != nil, note.richText == nil {
                    notesMadePlain += 1
                }
            }
            try write(plan.highlights, to: "highlights", held, \.id) { record, _ in MacImport.highlight(record) }
            try write(plan.tags, to: "tags", held, \.id) { record, _ in MacImport.tag(record) }
            try write(plan.tagAssignments, to: "tag_assignments", held, \.id) { record, _ in MacImport.assignment(record) }
            try write(plan.collections, to: "collections", held, \.id) { record, _ in MacImport.collection(record) }
            try write(plan.collectionEntries, to: "collection_entries", held, \.id) { record, parent in
                MacImport.entry(record, of: try Self.parent(parent, of: "collection_entries"))
            }
            try write(plan.projects, to: "projects", held, \.id) { record, _ in MacImport.project(record) }
            try write(plan.projectLeads, to: "project_leads", held, \.id) { record, _ in MacImport.lead(record) }
            try write(plan.savedSearches, to: "saved_searches", held, \.id) { record, _ in MacImport.savedSearch(record) }
            try write(plan.workingCorpora, to: "working_corpora", held, \.id) { record, _ in MacImport.corpus(record) }
            try write(plan.customVolumeScopes, to: "volume_scopes", held, \.id) { record, _ in MacImport.scope(record) }
            try write(plan.readingHistory, to: "trail_reading", held, \.id) { record, _ in MacImport.reading(record) }
            try write(plan.searchHistory, to: "trail_search", held, \.id) { record, _ in MacImport.search(record) }
            try write(plan.exportHistory, to: "trail_export", held, \.id) { record, _ in MacImport.exported(record) }
            try write(plan.archiveVisits, to: "visit_plans", held, \.id) { record, _ in MacImport.plan(record) }
            try write(plan.archiveVisitDocuments, to: "visit_documents", held, \.id) { record, parent in
                MacImport.seed(record, of: try Self.parent(parent, of: "visit_documents"))
            }
            try write(plan.archiveVisitTargets, to: "visit_targets", held, \.id) { record, parent in
                MacImport.target(record, of: try Self.parent(parent, of: "visit_targets"))
            }
            for (before, summary) in try write(plan.summaries, to: "summaries", held, \.id, { record, _ in MacImport.summary(record) }) {
                // As the app's writer counts them (`ResearchImportWriter.countTextChange`).
                if let before, version < ResearchImportPlan.Fields.summaryAuthorship.since,
                   (before.authorship ?? .aiGenerated) != .aiGenerated, summary.authorship == .aiGenerated {
                    summariesMadeAIGenerated += 1
                }
            }
            try write(plan.prompts, to: "prompts", held, \.id) { record, _ in MacImport.prompt(record) }
            try write(plan.annotationReviews, to: "annotation_reviews", held, \.id) { record, _ in MacImport.review(record) }
            if let item = plan.syncedPreferences {
                switch item.action {
                case .keep: break
                case .add: writes.append(ImportWrite("preferences", .add, row: MacImport.preferences(item.record)))
                case .replace:
                    guard let current = held.preferences else { throw PlanMismatch(table: "preferences") }
                    writes.append(ImportWrite("preferences", .replace, row: MacImport.preferences(item.written(over: current))))
                }
            }
            // An instance's corrections change the index every user shares: a curator's to import, the web's own rule.
            if includingInstanceWide {
                try write(plan.personClusterOverrides, to: "person_overrides", held, \.id) { record, _ in
                    MacImport.personCorrection(record)
                }
                try write(plan.classificationOverrides, to: "classification_overrides", held, \.id) { record, _ in
                    MacImport.classificationCorrection(record)
                }
            }
        }

        /// Adds the writes `items` plan to `table`: for an addition, the item's record as a new row; for a
        /// replacement, the item's record written over the store's copy (`Item.written(over:)`), over each row that
        /// holds it; for a record kept, nothing. Gives each record written, with the store's copy it was written over,
        /// none for an addition.
        @discardableResult
        private mutating func write<Record: ResearchImportRecord>(
            _ items: [ResearchImportPlan.Item<Record>], to table: String, _ held: HeldLibrary, _ id: KeyPath<Record, UUID>,
            _ row: (Record, UUID?) throws -> ImportRow
        ) throws -> [(before: Record?, written: Record)] {
            var written: [(before: Record?, written: Record)] = []
            for item in items {
                switch item.action {
                case .keep:
                    continue
                case .add:
                    writes.append(ImportWrite(table, .add, row: try row(item.record, item.parentId)))
                    written.append((nil, item.record))
                case .replace:
                    guard let copy = held.copy(of: item.record[keyPath: id], as: Record.self) else { throw PlanMismatch(table: table) }
                    let record = item.written(over: copy.record)
                    let values = try row(record, item.parentId)
                    for spelling in copy.ids { writes.append(ImportWrite(table, .replace, id: spelling, row: values)) }
                    written.append((copy.record, record))
                }
            }
            return written
        }

        /// The parent the plan names for a collection's entry or a plan's document or target, each a record of its own.
        private static func parent(_ id: UUID?, of table: String) throws -> UUID {
            guard let id else { throw PlanMismatch(table: table) }
            return id
        }

        /// The report: the kit's counts, each type in the user store's order, with the web's own lines beside them.
        func report(searchableDocuments: Int) -> ResearchImportReport {
            let kit = plan.report
            let types = MacImport.types.compactMap { type -> ImportTypeCount? in
                guard let count = kit.types.first(where: { $0.model.rawValue == type.model }) else { return nil }
                var web = ImportTypeCount(type: type.model, carried: count.carried, inFile: count.inFile, added: count.added,
                                          replaced: count.replaced, kept: count.kept, setAside: count.setAside,
                                          repeated: count.repeated)
                if !includingInstanceWide, MacImport.instanceTables.contains(type.table) {
                    // Planned, as the kit plans every correction, and set aside, as only a curator imports one here.
                    web.setAside += web.added + web.replaced + web.kept
                    web.added = 0
                    web.replaced = 0
                    web.kept = 0
                }
                return web
            }
            return ResearchImportReport(
                formatVersion: kit.formatVersion, exportedAt: UserStoreDate.text(kit.exportedAt), types: types,
                formattedNotes: formattedNotes, formattingKept: formattingKept, notesMadePlain: notesMadePlain,
                summariesMadeAIGenerated: summariesMadeAIGenerated, headnoteDrafts: kit.headnoteDrafts,
                summariesWithoutAuthorship: kit.summariesWithoutAuthorship, inertEntries: kit.inertEntries,
                unlinkedCollections: kit.unlinkedCollections.map { UnlinkedCollection(id: $0.id.uuidString, name: $0.name) },
                searchableDocuments: searchableDocuments)
        }
    }

    // MARK: Each type's row

    // Each record as its table's row, every column it carries: the import's records come resolved by the kit's plan,
    // and the web's editors map theirs here too, each made as the app's model makes one. The four types whose
    // records may leave out a column the model keeps without an optional, a collection, an entry, a project and a
    // summary, are read as the kit reads a record of the current version that leaves them out (`resolvedForImport`),
    // so that no default here is the web's own.

    /// A record as a file of the current version gives it, by the kit's reading of what it leaves out.
    private static func resolved<Record: ResearchImportRecord>(_ record: Record) -> Record {
        record.resolvedForImport(fromFormatVersion: ResearchDataEnvelope.currentFormatVersion)
    }

    static func note(_ note: ResearchNoteExport) -> ImportRow {
        // The RTF as the Mac wrote it, byte for byte; a note's highlights name it by their noteId, which
        // `linkedHighlightIds` only repeats.
        ImportRow(values: [
            "id": uuid(note.id), "document_id": .text(note.documentId), "volume_id": .text(note.volumeId),
            "body_text": .text(note.bodyText), "rich_text": blob(note.richText), "project_ids": ids(note.projectIds),
            "user_tag_ids": ids(note.userTagIds), "selected_summary_ids": ids(note.selectedSummaryIds),
            "created_at": date(note.createdAt), "last_modified": date(note.lastModified),
        ])
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

    /// A collection without its entries, which are rows of their own, with its front matter, composition and settings.
    static func collection(_ collection: CollectionExport) -> ImportRow {
        let collection = resolved(collection)
        return ImportRow(values: [
            "id": uuid(collection.id), "name": .text(collection.name), "note": text(collection.note),
            "project_ids": ids(collection.projectIds), "saved_search_id": uuid(collection.savedSearchId),
            "created_at": date(collection.createdAt), "last_modified": date(collection.lastModified),
            "subtitle": text(collection.subtitle), "author_line": text(collection.authorLine),
            "introduction_text": text(collection.introductionText), "introduction_rich_text": blob(collection.introductionRichText),
            "include_colophon": bool(collection.includeColophon), "include_project_provenance": bool(collection.includeProjectProvenance),
            "include_method_appendix": bool(collection.includeMethodAppendix), "default_body_depth": text(collection.defaultBodyDepth),
            "footnote_style": text(collection.footnoteStyle), "include_footnotes": bool(collection.includeFootnotes),
            "include_source_note": bool(collection.includeSourceNote), "toc_style": text(collection.tocStyle),
            "apply_highlights": bool(collection.applyHighlights), "include_notes": bool(collection.includeNotes),
            "include_word_cloud": bool(collection.includeWordCloud), "default_include_headnote": bool(collection.defaultIncludeHeadnote),
            "summary_prompt_id": uuid(collection.summaryPromptId),
        ])
    }

    /// An entry of the collection `collectionId`, with its kind, text and overrides.
    static func entry(_ entry: CollectionEntryExport, of collectionId: UUID) -> ImportRow {
        let entry = resolved(entry)
        return ImportRow(values: [
            "id": uuid(entry.id), "collection_id": uuid(collectionId), "document_id": .text(entry.documentId),
            "volume_id": .text(entry.volumeId), "sort_order": int(entry.sortOrder), "research_note_id": uuid(entry.researchNoteId),
            "selected_note_ids": ids(entry.selectedNoteIds), "created_at": date(entry.createdAt),
            "last_modified": date(entry.lastModified), "title_override": text(entry.titleOverride), "level": int(entry.level),
            "body_depth_override": text(entry.bodyDepthOverride), "apply_highlights_override": bool(entry.applyHighlightsOverride),
            "include_notes_override": bool(entry.includeNotesOverride),
            "include_source_note_override": bool(entry.includeSourceNoteOverride),
            "include_footnotes_override": bool(entry.includeFootnotesOverride),
            "summary_prompt_id_override": uuid(entry.summaryPromptIdOverride),
            "selected_highlight_ids": entry.selectedHighlightIds.map(ids) ?? .null,
            "include_related_documents": bool(entry.includeRelatedDocuments), "include_headnote": bool(entry.includeHeadnote),
            "headnote_summary_id": uuid(entry.headnoteSummaryId), "excerpt_start": int(entry.excerptStart),
            "excerpt_end": int(entry.excerptEnd), "excerpt_rendering_version": text(entry.excerptRenderingVersion),
            "excerpt_color_tag": text(entry.excerptColorTag), "kind": text(entry.kind),
            "generated_block_type": text(entry.generatedBlockType), "text": text(entry.text), "rich_text": blob(entry.richText),
        ])
    }

    static func entry(_ entry: CollectionEntryExport, of collection: CollectionExport) -> ImportRow {
        self.entry(entry, of: collection.id)
    }

    static func project(_ project: ProjectExport) -> ImportRow {
        let project = resolved(project)
        return ImportRow(values: [
            "id": uuid(project.id), "name": .text(project.name), "research_question": text(project.researchQuestion),
            "default_date_range_start": date(project.defaultDateRangeStart), "default_date_range_end": date(project.defaultDateRangeEnd),
            "default_subject_tag_ids": strings(project.defaultSubjectTagIds),
            "default_country_tag_ids": strings(project.defaultCountryTagIds), "created_at": date(project.createdAt),
            "last_modified": date(project.lastModified), "default_user_tag_ids": project.defaultUserTagIds.map(ids) ?? .null,
            "lead_axis_weights": text(project.leadAxisWeights),
        ])
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

    static func search(_ entry: SearchHistoryEntryExport) -> ImportRow {
        ImportRow(values: [
            "id": uuid(entry.id), "query_text": .text(entry.queryText), "result_count": int(entry.resultCount),
            "project_id": uuid(entry.projectId), "executed_at": date(entry.executedAt),
            "loaded_count": int(entry.loadedCount), "match_count": int(entry.matchCount), "fetch_limit": int(entry.fetchLimit),
            "indexed_volume_count": int(entry.indexedVolumeCount), "scope_signature": text(entry.scopeSignature),
            "applied_corpus_id": uuid(entry.appliedCorpusId), "rendered_expression": text(entry.renderedExpression),
        ])
    }

    static func exported(_ entry: ExportHistoryEntryExport) -> ImportRow {
        ImportRow(values: ["id": uuid(entry.id), "format": .text(entry.format), "document_count": int(entry.documentCount),
                           "collection_name": text(entry.collectionName), "project_id": uuid(entry.projectId),
                           "exported_at": date(entry.exportedAt)])
    }

    /// A plan without its documents and targets, which are rows of their own.
    static func plan(_ plan: ArchiveVisitPlanExport) -> ImportRow {
        // The tiers and the resolved toggles, encoded as the app's `tiers` and `deliverables` setters encode them, so
        // the app's getters read back what the file holds.
        ImportRow(values: [
            "id": uuid(plan.id), "name": .text(plan.name), "inquiry_text": text(plan.inquiryText),
            "project_ids": ids(plan.projectIds), "tiers_data": json(plan.tiers), "deliverable_toggles_data": json(plan.deliverables),
            "created_at": date(plan.createdAt), "last_modified": date(plan.lastModified),
        ])
    }

    /// A seeded document of the plan `planId`; the state the app keeps of it, which the export does not carry, none in
    /// a new row and the store's in a replaced one.
    static func seed(_ document: ArchiveVisitDocumentExport, of planId: UUID) -> ImportRow {
        ImportRow(values: [
            "id": uuid(document.id), "plan_id": uuid(planId), "document_key": .text(document.documentKey),
            "include_source": bool(document.includeSource), "include_external_refs": bool(document.includeExternalRefs),
            "created_at": date(document.createdAt), "last_modified": date(document.lastModified),
        ], defaults: ["state_data": .null])
    }

    /// A target of the plan `planId`, with the state the export does not carry as `seed` keeps it.
    static func target(_ target: ArchiveVisitTargetExport, of planId: UUID) -> ImportRow {
        ImportRow(values: [
            "id": uuid(target.id), "plan_id": uuid(planId), "target_key": .text(target.targetKey), "tier_id": uuid(target.tierId),
            "included": bool(target.included), "user_note": text(target.userNote), "created_at": date(target.createdAt),
            "last_modified": date(target.lastModified),
        ], defaults: ["state_data": .null])
    }

    /// A summary, with its authorship and headnote flag as the kit reads them; the hash of the text it was made from,
    /// which the export does not carry, none in a new row and the store's in a replaced one.
    static func summary(_ summary: GeneratedSummaryExport) -> ImportRow {
        let summary = resolved(summary)
        return ImportRow(values: [
            "id": uuid(summary.id), "document_id": .text(summary.documentId), "volume_id": .text(summary.volumeId),
            "prompt_id": uuid(summary.promptId), "response_text": .text(summary.responseText),
            "response_format": json(summary.responseFormat), "was_chunked": bool(summary.wasChunked),
            "authorship": text(summary.authorship?.rawValue), "is_headnote_draft": bool(summary.isHeadnoteDraft),
            "project_id": uuid(summary.projectId), "created_at": date(summary.createdAt), "last_modified": date(summary.lastModified),
        ], defaults: ["source_content_hash": .null])
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

    /// A `Codable` value as JSON text, written by the app's own encoder for these columns, a plain `JSONEncoder()`.
    static func json<T: Encodable>(_ value: T) -> SQLiteValue {
        (try? JSONEncoder().encode(value)).map { .text(String(decoding: $0, as: UTF8.self)) } ?? .null
    }
}

/// The columns the app's `SavedSearch` keeps beside its search's snapshot: its `storeParameters(_:)`, which
/// `init(name:parameters:)` calls, writes the scalar columns from the parameters, app code mirrored, which
/// ImportParityTests holds to the app's source; and `recordRun` writes the watermark, the kit's
/// `SavedSearchFreshness`, as its `encoded` blob, which the import writes with the kit's own call.
enum SavedSearchColumns {
    /// `SavedSearch.storeParameters(_:)`'s scalar columns, as it writes them from `parameters`: a date range the
    /// search does not have as none, which the app clears since FRUS-Explorer#1951.
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

    /// The watermark the file records, as the kit's `SavedSearchFreshness.encoded` writes it (a field with no value
    /// left out, a date as seconds since 2001), or NULL when the file records no run, as a search saved and never run
    /// again keeps none.
    static func freshness(lastRunAt: Date?, matchCount: Int?, indexedVolumeCount: Int?) -> SQLiteValue {
        guard lastRunAt != nil || matchCount != nil || indexedVolumeCount != nil else { return .null }
        let mark = SavedSearchFreshness(lastRunAt: lastRunAt, matchCountAtLastRun: matchCount,
                                        indexedVolumeCountAtLastRun: indexedVolumeCount)
        return mark.encoded.map { .text(String(decoding: $0, as: UTF8.self)) } ?? .null
    }
}
