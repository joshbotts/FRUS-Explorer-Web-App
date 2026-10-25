// The web's export, checked (PLAN's S16d): an export imported into a store of its own, as the import
// route's job imports one, and exported again as the export route writes one, then held to the file:
// the kit's decoder reads the export, the export carries every record of the file as the file has it,
// read at the file's format version, type by type and id by id, and, for a file of the kit's version,
// it is the file itself, as the Mac writes it, with the web's key beside it. For the tests, the kit's
// fixtures and the browser suite's export; and `frus-parity export-check`, which a session runs on the
// owner's export, printing counts, ids and keys, never what a record says.

import FRUSCoreKit
import FRUSLightAPI
import FRUSLightCore
import Foundation

public enum ExportCheck {
    /// What an export of an imported file is, beside the file.
    public struct Outcome: Sendable {
        public let report: ResearchImportReport
        /// The export, as the route writes it.
        public let export: Data
        /// The file's records beside the export's, read at the file's format version.
        public let comparison: ResearchComparison
        /// For a file of the kit's format version, the top-level keys whose values the export gives
        /// otherwise than the file, as the store keeps it and the kit writes it in the app's order
        /// (`asStored`, `macOrdered`), and those either has that the other lacks: only the web's own
        /// for a file the Mac wrote. Nil for an older file, which the export writes at the kit's.
        public let differentKeys: [String]?
        /// The import's and the export's time.
        public let importSeconds: Double
        public let exportSeconds: Double
    }

    /// The options an export of `envelope` takes to be it: every summary, the instance's
    /// corrections, the project the file names in its header and the file's own time.
    public static func options(for envelope: ResearchDataEnvelope) -> ResearchExport.Options {
        let project = envelope.exportedForProjectName.flatMap { name in
            envelope.projects.first { $0.name == name && $0.researchQuestion == envelope.exportedForProjectResearchQuestion }
        }
        return ResearchExport.Options(includeGeneratedSummaries: true, includingInstanceWide: true, projectId: project?.id,
                                      exportedAt: envelope.exportedAt)
    }

    /// Imports `data` for `user` into a new store in `directory`, as the route's job does, exports it
    /// as the route does, and holds the export to the file.
    public static func run(_ data: Data, in directory: URL, user: String = "owner") async throws -> Outcome {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("app.db")
        let store = try await SQLiteUserStore(url: url, backupsDirectory: directory.appendingPathComponent("backups"))
        let file = try MacImport.envelope(of: data)
        let clock = ContinuousClock()
        let importStart = clock.now
        let report = try MacImport.run(file, into: store, for: user, includingInstanceWide: true)
        let exportStart = clock.now
        let export = try ResearchExport.file(from: store, for: user, options(for: file))
        let exportEnd = clock.now
        let exported = try MacImport.envelope(of: export)
        let current = file.formatVersion == ResearchDataEnvelope.currentFormatVersion
        return Outcome(report: report, export: export,
                       comparison: .compare(file: file, stored: atVersion(exported, file.formatVersion)),
                       differentKeys: current
                           ? try differentKeys(export, macOrdered(asStored(file)).jsonData()) : nil,
                       importSeconds: seconds(exportStart - importStart), exportSeconds: seconds(exportEnd - exportStart))
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    /// The top-level keys whose values differ between two files, or that one has and the other lacks.
    public static func differentKeys(_ a: Data, _ b: Data) throws -> [String] {
        let left = try JSONDecoder().decode([String: JSONValue].self, from: a)
        let right = try JSONDecoder().decode([String: JSONValue].self, from: b)
        return Set(left.keys).union(right.keys).sorted().filter { left[$0] != right[$0] }
    }

    /// What `frus-parity export-check` prints: the file's version, the export's size and times, and
    /// for each type its count in the file and whether the export carries every record as the file
    /// has it, by the ids and field names of any it does not; and the keys the export writes otherwise.
    public static func describe(_ outcome: Outcome) -> [String] {
        var lines = ["format version \(outcome.report.formatVersion), exported \(outcome.report.exportedAt); "
                     + "imported in \(String(format: "%.2f", outcome.importSeconds)) s, exported in "
                     + "\(String(format: "%.2f", outcome.exportSeconds)) s, \(outcome.export.count) bytes"]
        for (count, compared) in zip(outcome.report.types, outcome.comparison.types) {
            var line = "\(count.type): \(count.inFile) in the file, \(count.repeated) repeated in it, \(count.setAside) set aside"
            line += compared.isWhole ? "; all in the export as the file has them" : "; NOT WHOLE"
            lines.append(line)
            for id in compared.missing { lines.append("  missing: \(id)") }
            for difference in compared.different { lines.append("  differs: \(difference.id) in \(difference.fields.joined(separator: ", "))") }
        }
        if let keys = outcome.differentKeys {
            lines.append("keys the export writes otherwise than the file, in the app's order as the store keeps it: "
                         + (keys.isEmpty ? "none" : keys.joined(separator: ", ")))
        } else {
            lines.append("a file of version \(outcome.report.formatVersion), which the export writes at "
                         + "\(ResearchDataEnvelope.currentFormatVersion): its records compared at the file's version")
        }
        return lines
    }

    // MARK: The file as the Mac writes it, and as the store keeps it

    /// `envelope` with its records in the order the app's exporter writes them
    /// (`ResearchDataExporter.makeEnvelope`): the trail by its times, a plan by its name, compared as
    /// a `SortDescriptor` over a string compares by default, with Foundation's localized standard
    /// comparison, then by when it was made, its documents and targets by their keys, a collection's
    /// entries by their place, and the types of version 7 by when each was made, a review by when it
    /// was made and a lead by when it first surfaced; a time that is none first, each tie as the file
    /// gives it. What the exporter fetches unsorted stays as the file gives it.
    public static func macOrdered(_ envelope: ResearchDataEnvelope) -> ResearchDataEnvelope {
        var envelope = envelope
        envelope.readingHistory = stable(envelope.readingHistory) { earlier($0.accessedAt, $1.accessedAt) }
        envelope.searchHistory = stable(envelope.searchHistory) { earlier($0.executedAt, $1.executedAt) }
        envelope.exportHistory = stable(envelope.exportHistory) { earlier($0.exportedAt, $1.exportedAt) }
        envelope.archiveVisits = stable(envelope.archiveVisits) { a, b in
            switch a.name.localizedStandardCompare(b.name) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: earlier(a.createdAt, b.createdAt)
            }
        }.map { plan in
            var plan = plan
            plan.documents = stable(plan.documents) { $0.documentKey < $1.documentKey }
            plan.targets = stable(plan.targets) { $0.targetKey < $1.targetKey }
            return plan
        }
        envelope.collections = envelope.collections.map { collection in
            var collection = collection
            collection.entries = stable(collection.entries) { $0.sortOrder < $1.sortOrder }
            return collection
        }
        envelope.savedSearches = stable(envelope.savedSearches) { earlier($0.createdAt, $1.createdAt) }
        envelope.workingCorpora = stable(envelope.workingCorpora) { earlier($0.createdAt, $1.createdAt) }
        envelope.customVolumeScopes = stable(envelope.customVolumeScopes) { earlier($0.createdAt, $1.createdAt) }
        envelope.classificationOverrides = stable(envelope.classificationOverrides) { earlier($0.createdAt, $1.createdAt) }
        envelope.personClusterOverrides = stable(envelope.personClusterOverrides) { earlier($0.createdAt, $1.createdAt) }
        envelope.annotationReviews = stable(envelope.annotationReviews) { earlier($0.reviewedAt, $1.reviewedAt) }
        envelope.projectLeads = stable(envelope.projectLeads) { $0.firstSurfacedAt < $1.firstSurfacedAt }
        envelope.syncedPreferences = stable(envelope.syncedPreferences) { $0.createdAt < $1.createdAt }
        return envelope
    }

    /// `envelope` as the store keeps it, which an export of it gives back: a record the file repeats
    /// under one id once, in the first copy's place, the newer copy by the import's stamp
    /// (`ImportStamp`), of two as new the first, a collection's entries and a plan's documents and
    /// targets under the parent their kept copy names; one set of synced settings, the earliest made,
    /// as the app reads them; and a summary's authorship, none in a file before version 5, as
    /// `.aiGenerated`, as the app's exporter writes it. `macOrdered` then gives its export's order.
    public static func asStored(_ envelope: ResearchDataEnvelope) -> ResearchDataEnvelope {
        var envelope = envelope
        envelope.notes = collapsed(envelope.notes, "notes", id: \.id)
        envelope.tags = collapsed(envelope.tags, "tags", id: \.id)
        envelope.tagAssignments = collapsed(envelope.tagAssignments, "tag_assignments", id: \.id)
        envelope.highlights = collapsed(envelope.highlights, "highlights", id: \.id)
        let entries = collapsed(envelope.collections.flatMap { collection in collection.entries.map { (collection.id, $0) } },
                                "collection_entries", id: \.1.id, record: \.1)
        envelope.collections = collapsed(envelope.collections, "collections", id: \.id).map { collection in
            var collection = collection
            collection.entries = entries.filter { $0.0 == collection.id }.map(\.1)
            return collection
        }
        envelope.prompts = collapsed(envelope.prompts, "prompts", id: \.id)
        envelope.projects = collapsed(envelope.projects, "projects", id: \.id)
        envelope.summaries = collapsed(envelope.summaries, "summaries", id: \.id).map { summary in
            var summary = summary
            summary.authorship = summary.authorship ?? .aiGenerated
            return summary
        }
        envelope.readingHistory = collapsed(envelope.readingHistory, "trail_reading", id: \.id)
        envelope.searchHistory = collapsed(envelope.searchHistory, "trail_search", id: \.id)
        envelope.exportHistory = collapsed(envelope.exportHistory, "trail_export", id: \.id)
        let documents = collapsed(envelope.archiveVisits.flatMap { plan in plan.documents.map { (plan.id, $0) } },
                                  "visit_documents", id: \.1.id, record: \.1)
        let targets = collapsed(envelope.archiveVisits.flatMap { plan in plan.targets.map { (plan.id, $0) } },
                                "visit_targets", id: \.1.id, record: \.1)
        envelope.archiveVisits = collapsed(envelope.archiveVisits, "visit_plans", id: \.id).map { plan in
            var plan = plan
            plan.documents = documents.filter { $0.0 == plan.id }.map(\.1)
            plan.targets = targets.filter { $0.0 == plan.id }.map(\.1)
            return plan
        }
        envelope.savedSearches = collapsed(envelope.savedSearches, "saved_searches", id: \.id)
        envelope.workingCorpora = collapsed(envelope.workingCorpora, "working_corpora", id: \.id)
        envelope.customVolumeScopes = collapsed(envelope.customVolumeScopes, "volume_scopes", id: \.id)
        envelope.classificationOverrides = collapsed(envelope.classificationOverrides, "classification_overrides", id: \.id)
        envelope.personClusterOverrides = collapsed(envelope.personClusterOverrides, "person_overrides", id: \.id)
        envelope.annotationReviews = collapsed(envelope.annotationReviews, "annotation_reviews", id: \.id)
        envelope.projectLeads = collapsed(envelope.projectLeads, "project_leads", id: \.id)
        envelope.syncedPreferences = envelope.syncedPreferences.enumerated()
            .min { ($0.element.createdAt, $0.offset) < ($1.element.createdAt, $1.offset) }.map { [$0.element] } ?? []
        return envelope
    }

    /// `items` with each id once, as the import writes a record a file repeats: in the first copy's
    /// place, a later copy taking it only when it is newer by the import's stamp for `table`, its time
    /// of change or else its creation, or for a type with none the time of what it records.
    static func collapsed<T>(_ items: [T], _ table: String, id: (T) -> UUID) -> [T] where T: Encodable {
        collapsed(items, table, id: id, record: \.self)
    }

    static func collapsed<T, Record: Encodable>(_ items: [T], _ table: String, id: (T) -> UUID,
                                                 record: KeyPath<T, Record>) -> [T] {
        // The stamp's columns, by the JSON keys the kit writes them under: `last_modified` is `lastModified`.
        let keys = (ImportStamp.columns[table] ?? []).map { column in
            let parts = column.split(separator: "_")
            return ([String(parts[0])] + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }).joined()
        }
        let encoder = ResearchDataEnvelope.makeEncoder()
        func time(_ item: T) -> Date {
            guard let data = try? encoder.encode(item[keyPath: record]),
                  let object = try? JSONDecoder().decode([String: JSONValue].self, from: data) else { return .distantPast }
            for key in keys {
                if case .string(let text)? = object[key], let date = ISO8601DateFormatter().date(from: text) { return date }
            }
            return .distantPast
        }
        var kept: [T] = []
        var places: [UUID: Int] = [:]
        for item in items {
            guard let earlier = places[id(item)] else {
                places[id(item)] = kept.count
                kept.append(item)
                continue
            }
            if time(item) > time(kept[earlier]) { kept[earlier] = item }
        }
        return kept
    }

    /// `envelope` as a file of `version` carries it: a type or a field the version cannot carry as
    /// none, as the kit's decoder reads such a file, and a summary's authorship, which the exporter
    /// writes for one with none, as none before version 5.
    public static func atVersion(_ envelope: ResearchDataEnvelope, _ version: Int) -> ResearchDataEnvelope {
        var envelope = envelope
        envelope.formatVersion = version
        if version < 7 {
            envelope.savedSearches = []
            envelope.workingCorpora = []
            envelope.customVolumeScopes = []
            envelope.classificationOverrides = []
            envelope.personClusterOverrides = []
            envelope.annotationReviews = []
            envelope.projectLeads = []
            envelope.syncedPreferences = []
            envelope.notes = envelope.notes.map { note in
                var note = note
                note.richText = nil
                return note
            }
            envelope.collections = envelope.collections.map { collection in
                CollectionExport(id: collection.id, name: collection.name, note: collection.note, projectIds: collection.projectIds,
                                 savedSearchId: collection.savedSearchId, entries: collection.entries.map { entry in
                                     CollectionEntryExport(id: entry.id, documentId: entry.documentId, volumeId: entry.volumeId,
                                                           sortOrder: entry.sortOrder, researchNoteId: entry.researchNoteId,
                                                           selectedNoteIds: entry.selectedNoteIds, createdAt: entry.createdAt,
                                                           lastModified: entry.lastModified)
                                 }, createdAt: collection.createdAt, lastModified: collection.lastModified)
            }
            envelope.projects = envelope.projects.map { project in
                var project = project
                project.defaultUserTagIds = nil
                project.leadAxisWeights = nil
                return project
            }
            envelope.summaries = envelope.summaries.map { summary in
                var summary = summary
                summary.isHeadnoteDraft = nil
                return summary
            }
        }
        if version < 6 { envelope.archiveVisits = [] }
        if version < 5 {
            envelope.summaries = envelope.summaries.map { summary in
                var summary = summary
                summary.authorship = nil
                return summary
            }
        }
        if version < 4 {
            envelope.searchHistory = envelope.searchHistory.map { search in
                SearchHistoryEntryExport(id: search.id, queryText: search.queryText, resultCount: search.resultCount,
                                         projectId: search.projectId, executedAt: search.executedAt)
            }
        }
        if version < 3 {
            envelope.readingHistory = []
            envelope.searchHistory = []
            envelope.exportHistory = []
        }
        return envelope
    }

    /// Whether `a` sorts before `b` as a fetch sorted by an optional date puts them: none first.
    static func earlier(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case let (x?, y?): x < y
        case (nil, _?): true
        default: false
        }
    }

    /// `items` sorted by `before`, each tie as given.
    static func stable<T>(_ items: [T], by before: (T, T) -> Bool) -> [T] {
        items.enumerated().sorted { a, b in
            before(a.element, b.element) || (!before(b.element, a.element) && a.offset < b.offset)
        }.map(\.element)
    }

    /// Any JSON value, to compare two files' keys without reading what they hold.
    public indirect enum JSONValue: Codable, Equatable, Sendable {
        case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() { self = .null }
            else if let value = try? container.decode(Bool.self) { self = .bool(value) }
            else if let value = try? container.decode(Double.self) { self = .number(value) }
            else if let value = try? container.decode(String.self) { self = .string(value) }
            else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
            else { self = .object(try container.decode([String: JSONValue].self)) }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .null: try container.encodeNil()
            case .bool(let value): try container.encode(value)
            case .number(let value): try container.encode(value)
            case .string(let value): try container.encode(value)
            case .array(let value): try container.encode(value)
            case .object(let value): try container.encode(value)
            }
        }
    }
}

