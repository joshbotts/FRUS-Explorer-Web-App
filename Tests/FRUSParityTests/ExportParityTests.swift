// The export's done-when in tests (PLAN's S16d): import, export and import again is the identity over
// every type, and the export of an imported Mac file differs from it only by the added key. Over the
// kit's own files of every format version, envelopes the kit writes with every type at 6 and at 7, and
// the browser suite's export; and over what the web writes itself, which comes back through its own
// export at the file's whole seconds. Then that every column of every table reaches the file, but
// those the app's own export leaves out and those made from another, and that every table of the
// store is exported or no one's research; the exporter's orders on the store's rows; and the lines of
// the app's exporter the export mirrors, held to its source at the pin.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSRichText
@testable import FRUSParity
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct ExportParityTests {
    static let layout = Repository.layout

    /// A store of its own in `directory`.
    static func store(_ directory: TemporaryDirectory, _ name: String) async throws -> (SQLiteUserStore, URL) {
        let url = directory.url.appendingPathComponent("\(name).db")
        return (try await SQLiteUserStore(url: url, backupsDirectory: directory.url.appendingPathComponent("backups-\(name)")), url)
    }

    /// `data` imported into a new store in `directory`, as the route's job imports it, for a curator.
    static func imported(_ data: Data, _ directory: TemporaryDirectory, _ name: String) async throws -> (SQLiteUserStore, URL) {
        let (store, url) = try await Self.store(directory, name)
        _ = try MacImport.run(try MacImport.envelope(of: data), into: store, for: "owner", includingInstanceWide: true)
        return (store, url)
    }

    /// What every case exports with: every summary, the instance's corrections, and a fixed time.
    static let options = ResearchExport.Options(includeGeneratedSummaries: true, includingInstanceWide: true,
                                                exportedAt: Date(timeIntervalSince1970: 1_792_886_400))  // 2026-10-25

    /// The files the done-when is held over: the kit's own of each version, envelopes it writes with
    /// every type at 7 and at 6, and the browser suite's.
    static func files() throws -> [(name: String, version: Int, data: Data)] {
        try KitExportFixtures.files(layout: layout).map { ("the kit's version \($0.version)", $0.version, Data($0.json.utf8)) }
            + [("every type at 7", 7, try ImportFixtures.file(ImportFixtures.everyType(formatVersion: 7))),
               ("every type at 6", 6, try ImportFixtures.file(ImportFixtures.everyType(formatVersion: 6))),
               ("the browser suite's", 7, try Data(contentsOf: layout.root.appendingPathComponent(ImportFixtures.browserSuitePath)))]
    }

    /// Every row a store holds for `owner` in the 23 tables, in the store's order.
    static func ordered(_ url: URL) throws -> [String: [[String: SQLiteValue]]] {
        let rows = try UserStoreRows(url)
        return try Dictionary(uniqueKeysWithValues: UserStoreSchema.tables.map { ($0.name, try rows.rows(of: $0.name)) })
    }

    // MARK: The done-when

    /// The done-when's second half: an imported Mac file of the kit's version, as the Mac writes one,
    /// its records in its exporter's order and one set of synced settings, exported at the file's time
    /// under the project it names, is the file, with the web's key beside it and nothing else.
    @Test func theExportOfAnImportedMacFileIsTheFileWithTheWebsKey() async throws {
        let macFiles: [(String, ResearchDataEnvelope)] = [
            ("every type at 7", ImportFixtures.everyType(formatVersion: 7)),
            ("the kit's version 7", try MacImport.envelope(of: Data(try #require(try KitExportFixtures.files(layout: Self.layout).last).json.utf8))),
            ("the browser suite's", try MacImport.envelope(of: try Data(contentsOf: Self.layout.root.appendingPathComponent(ImportFixtures.browserSuitePath)))),
        ]
        for (name, envelope) in macFiles {
            // As the Mac writes it: the kit's encoder over its exporter's records.
            let file = try ExportCheck.asStored(ExportCheck.macOrdered(envelope)).jsonData()
            let directory = try TemporaryDirectory()
            let outcome = try await ExportCheck.run(file, in: directory.url)
            #expect(outcome.comparison.isWhole, "\(name): \(outcome.comparison.types.filter { !$0.isWhole })")
            #expect(outcome.differentKeys == [ResearchExport.webKey], "\(name): \(outcome.differentKeys ?? [])")
            // Literally: the export's JSON without the web's key is the file's.
            var exported = try JSONDecoder().decode([String: ExportCheck.JSONValue].self, from: outcome.export)
            let key = exported.removeValue(forKey: ResearchExport.webKey)
            #expect(key == .object(["formatVersion": .number(1), "includesGeneratedSummaries": .bool(true),
                                    "includesCorrections": .bool(true)]))
            #expect(try exported == JSONDecoder().decode([String: ExportCheck.JSONValue].self, from: file), "\(name)")
            // And its bytes are the kit's, the web's key's lines among the file's.
            #expect(try outcome.export == ResearchExport.file(MacImport.envelope(of: file), ExportCheck.options(for: envelope)), "\(name)")
            withExtendedLifetime(directory) {}
        }
    }

    /// The done-when's first half: a file imported, exported and the export imported into another
    /// store leaves the two stores holding the same, every row of the 23 tables column by column; the
    /// export imported into the first store again keeps every record as it is; and the second store's
    /// export is the first's, byte for byte. A summary with no authorship, from a file before version
    /// 5, the app's exporter writes as an AI summary, as every reader takes it: the one value that
    /// changes, from none to `aiGenerated`.
    @Test func importExportAndImportAgainIsTheIdentityOverEveryType() async throws {
        for (name, version, file) in try Self.files() {
            let directory = try TemporaryDirectory()
            let (first, firstURL) = try await Self.imported(file, directory, "first")
            let before = try Self.held(firstURL)
            let order = try Self.ordered(firstURL)
            let export = try ResearchExport.file(from: first, for: "owner", Self.options)
            let (second, secondURL) = try await Self.imported(export, directory, "second")
            #expect(try Self.held(secondURL) == Self.asExported(before), "\(name)")
            #expect(try version < 5 || !Self.withoutAuthorship(firstURL), "\(name): a summary without authorship only before 5")
            #expect(try ResearchExport.file(from: second, for: "owner", Self.options) == export, "\(name)")

            let again = try MacImport.run(try MacImport.envelope(of: export), into: first, for: "owner", includingInstanceWide: true)
            for type in again.types {
                #expect(type.added == 0 && type.replaced == 0 && type.kept == type.inFile && type.repeated == 0, "\(name): \(type)")
            }
            #expect(try Self.ordered(firstURL) == order, "\(name): the first store as it was, in its order")
            withExtendedLifetime(directory) {}
        }
    }

    /// What the web writes itself, a tag given to a document, a formatted note linked to a highlight
    /// and the reader's own summary, beside an import: exported, imported into another store and
    /// exported again, the same file; the second store holds what the first does, each time at the
    /// file's whole seconds, as the kit's encoder writes a date; and the export imported into the
    /// first store keeps every record of it as it is, since a time cut to the second is never newer.
    @Test func whatTheWebWritesComesBackThroughItsOwnExport() async throws {
        let directory = try TemporaryDirectory()
        let (first, firstURL) = try await Self.imported(try ImportFixtures.file(ImportFixtures.everyType(formatVersion: 7)),
                                                         directory, "first")
        let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
        let now = Date(timeIntervalSince1970: 1_792_800_000.789)
        let tag = try first.createTag(named: "Written here", for: "owner", at: now)
        _ = try first.setTags([tag.id], of: d1, for: "owner", at: now.addingTimeInterval(1.5))
        let highlight = try first.createHighlight(in: d1, start: 0, end: 5, colorTag: "blue", selectedText: "Begin",
                                                  renderingVersion: "0123456789abcdef", for: "owner", at: now.addingTimeInterval(2.25))
        _ = try first.createNote(in: d1, bodyText: "A note written here.", richText: RTFWriter.write([
            RichTextRun(text: "A note "), RichTextRun(text: "written", bold: true), RichTextRun(text: " here."),
        ]), projectIds: [], userTagIds: [tag.id], selectedSummaryIds: [], linkedHighlightId: highlight.id, for: "owner",
                                 at: now.addingTimeInterval(3.5))
        _ = try first.createOwnSummary(in: d1, text: "My own summary.", responseFormat: Summary.generalFormat, for: "owner",
                                       at: now.addingTimeInterval(4.999))
        let export = try ResearchExport.file(from: first, for: "owner", Self.options)
        let (second, secondURL) = try await Self.imported(export, directory, "second")
        #expect(try ResearchExport.file(from: second, for: "owner", Self.options) == export)
        #expect(try Self.held(secondURL) == Self.atWholeSeconds(Self.held(firstURL)))

        let before = try Self.held(firstURL)
        let again = try MacImport.run(try MacImport.envelope(of: export), into: first, for: "owner", includingInstanceWide: true)
        #expect(again.types.allSatisfy { $0.added == 0 && $0.replaced == 0 }, "\(again.types.filter { $0.added + $0.replaced > 0 })")
        #expect(try Self.held(firstURL) == before)
        let note = try #require(try MacImport.envelope(of: export).notes.first { $0.bodyText == "A note written here." })
        #expect(note.linkedHighlightIds.map(\.uuidString) == [highlight.id], "\(note.linkedHighlightIds) \(highlight.id)")
        #expect(note.richText != nil)
        #expect(note.createdAt == Date(timeIntervalSince1970: 1_792_800_004), "4.289 seconds after the fixture's second, cut to it")
    }

    // MARK: Everything the web holds

    /// The columns the export carries in no record, by table, with why: the app's own export leaves
    /// them out too, and no path here writes them; or they are made from another column, which the
    /// file carries. Every other column reaches the file.
    static let leftOut: [String: [String: String]] = [
        "summaries": ["source_content_hash": "the content hash of the text the app's summarizer read, which the app's export leaves out; no summary here is made by one, and an import leaves it none"],
        "visit_documents": ["state_data": "a payload the app has not yet defined, which its export leaves out; nothing here writes one"],
        "visit_targets": ["state_data": "the same"],
        "saved_searches": Dictionary(uniqueKeysWithValues: [
            "query_text", "phrase_text", "prefix_wildcard", "boolean_mode_raw", "excluded_terms_csv", "scope_flags",
            "date_range_start", "date_range_end", "subject_tag_ids_csv", "document_type_filter_raw", "person_ref", "sort_order",
        ].map { ($0, "made from the search's parameters, which the file carries, as `SavedSearch.init(name:parameters:)` makes it") }),
    ]

    /// The store's tables that hold no one's research, with why.
    static let notResearch: [String: String] = [
        "users": "the accounts the server acts for, S2's and S14e's",
        "schema_migrations": "the store's own record of its migrations",
        "user_search": "made again from the notes and summaries by every write and import (S15d, S16c), with FTS5's own tables",
    ]

    /// Every column of every table, changed in one row, changes the export, but those the export leaves
    /// out, which change nothing: so every value the store holds reaches the file, and the list of what
    /// does not is exact.
    @Test func everyColumnReachesTheFileButWhatTheExportLeavesOut() async throws {
        let directory = try TemporaryDirectory()
        let (store, url) = try await Self.imported(try ImportFixtures.file(ImportFixtures.everyType(formatVersion: 7)), directory, "store")
        let rows = try UserStoreRows(url)
        let base = try ResearchExport.file(from: store, for: "owner", Self.options)
        var unchanged: [String: [String: String]] = [:]
        for table in UserStoreSchema.tables {
            let filter = table.scope == .user ? " WHERE user_id = 'owner'" : ""
            let rowid = try #require(try rows.firstRow("SELECT rowid FROM \(table.name)\(filter) ORDER BY rowid LIMIT 1").first,
                                     "\(table.name) holds a row")
            let row = try #require(try rows.rows(of: table.name).first)
            for column in table.columns {
                let original = row[column.name] ?? .null
                let changed = try Self.changed(original, table: table.name, column: column)
                #expect(changed != original, "\(table.name).\(column.name)")
                try rows.run("UPDATE \(table.name) SET \(column.name) = ? WHERE rowid = \(rowid)", [changed])
                if try ResearchExport.file(from: store, for: "owner", Self.options) == base {
                    unchanged[table.name, default: [:]][column.name] = Self.leftOut[table.name]?[column.name] ?? "NOT LEFT OUT"
                }
                try rows.run("UPDATE \(table.name) SET \(column.name) = ? WHERE rowid = \(rowid)", [original])
            }
        }
        #expect(unchanged == Self.leftOut)
        #expect(try ResearchExport.file(from: store, for: "owner", Self.options) == base, "every value as it was")
    }

    /// Every table of the store is one of the 23 the export reads, or holds no one's research.
    @Test func everyTableOfTheStoreIsExportedOrNoOnesResearch() async throws {
        let directory = try TemporaryDirectory()
        let (_, url) = try await Self.store(directory, "store")
        let tables = try UserStoreRows(url).column("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")
        let exported = Set(UserStoreSchema.tables.map(\.name))
        let others = tables.filter { !exported.contains($0) }
        #expect(Set(others.filter { !$0.hasPrefix("user_search_") }) == Set(Self.notResearch.keys))
        #expect(others.filter { $0.hasPrefix("user_search_") }.sorted()
                == ["user_search_config", "user_search_content", "user_search_data", "user_search_docsize", "user_search_idx"],
                "FTS5's own tables of user_search")
        #expect(exported.isSubset(of: Set(tables)))
    }

    // MARK: The exporter's orders

    /// On rows whose times run against the order the store took them, the export gives what the app's
    /// exporter fetches unsorted in the store's order, and the rest as its fetches sort them.
    @Test func theExportsOrdersAreTheAppExportersOverTheStoresRows() async throws {
        let directory = try TemporaryDirectory()
        let (store, url) = try await Self.imported(try ImportFixtures.file(ImportFixtures.everyType(formatVersion: 7)), directory, "store")
        let rows = try UserStoreRows(url)
        // Each table's times, places and keys, the later the row the earlier its value, and one time none.
        let reversed: [(table: String, column: String, value: (Int) -> SQLiteValue)] = [
            ("notes", "created_at", Self.day), ("tags", "created_at", Self.day), ("tag_assignments", "created_at", Self.day),
            ("highlights", "created_at", Self.day), ("collections", "created_at", Self.day), ("prompts", "created_at", Self.day),
            ("projects", "created_at", Self.day), ("summaries", "created_at", Self.day),
            ("trail_reading", "accessed_at", Self.day), ("trail_search", "executed_at", Self.day), ("trail_export", "exported_at", Self.day),
            ("saved_searches", "created_at", Self.day), ("working_corpora", "created_at", Self.day), ("volume_scopes", "created_at", Self.day),
            ("classification_overrides", "created_at", Self.day), ("person_overrides", "created_at", Self.day),
            ("annotation_reviews", "reviewed_at", Self.day), ("project_leads", "first_surfaced_at", Self.day),
            ("collection_entries", "sort_order", { .integer(Int64(100 - $0)) }),
            ("visit_plans", "name", { .text("Plan \(String(UnicodeScalar(UInt8(90 - $0))))") }),
            ("visit_documents", "document_key", { .text("frus1961-63v06/d\(90 - $0)") }),
            ("visit_targets", "target_key", { .text("target-\(90 - $0)") }),
        ]
        for (table, column, value) in reversed {
            let schema = try #require(UserStoreSchema.tables.first { $0.name == table })
            let filter = schema.scope == .user ? " WHERE user_id = 'owner'" : ""
            var rowids = try rows.column("SELECT rowid FROM \(table)\(filter) ORDER BY rowid")
            if rowids.count == 1 {
                // A second row to order, the first's copy under an id of its own, of the same parent.
                let columns = (schema.scope == .user ? ["user_id"] : []) + schema.columns.map(\.name)
                try rows.run("INSERT INTO \(table) (\(columns.joined(separator: ", "))) SELECT "
                                 + columns.map { $0 == "id" ? "?" : $0 }.joined(separator: ", ") + " FROM \(table) WHERE rowid = \(rowids[0])",
                             [.text(UUID().uuidString)])
                rowids = try rows.column("SELECT rowid FROM \(table)\(filter) ORDER BY rowid")
            }
            #expect(rowids.count >= 2, "\(table) has rows to order")
            for (index, rowid) in rowids.enumerated() {
                let optional = schema.columns.first { $0.name == column }?.optional == true
                try rows.run("UPDATE \(table) SET \(column) = ? WHERE rowid = \(rowid)",
                             [optional && index == rowids.count - 1 && column.hasSuffix("_at") ? .null : value(index)])
            }
        }
        let export = try MacImport.envelope(of: try ResearchExport.file(from: store, for: "owner", Self.options))
        // The sorted ones as the app's fetches sort them: the export is already in that order.
        #expect(ExportCheck.macOrdered(export) == export)
        #expect(export.readingHistory.first?.accessedAt == nil, "a time that is none first")
        // The unsorted ones in the store's order, whatever their times.
        for (table, ids) in [("notes", export.notes.map(\.id)), ("tags", export.tags.map(\.id)),
                             ("tag_assignments", export.tagAssignments.map(\.id)), ("highlights", export.highlights.map(\.id)),
                             ("collections", export.collections.map(\.id)), ("prompts", export.prompts.map(\.id)),
                             ("projects", export.projects.map(\.id)), ("summaries", export.summaries.map(\.id))] {
            let stored = try rows.column("SELECT id FROM \(table) WHERE user_id = 'owner' ORDER BY rowid")
            #expect(ids.map(\.uuidString) == stored.map { $0.uppercased() }, "\(table)")
        }
        // And what sorts, against the store's order.
        #expect(export.readingHistory.count >= 2 && export.collections.contains { $0.entries.count >= 2 })
    }

    /// A day before the fixtures' times, the later `index` the earlier.
    static func day(_ index: Int) -> SQLiteValue {
        .text(UserStoreDate.text(Date(timeIntervalSince1970: 1_767_225_600 - Double(index) * 86_400)))  // 2026-01-01
    }

    // MARK: The app's exporter, at the pin

    /// The lines of the app's exporter and its getters the export mirrors (`ResearchExport`,
    /// `ExportCheck.macOrdered`), read from the app's source: which fetches sort and by what, the
    /// orders within a collection and a plan, the summaries only with the switch, the researcher's own
    /// prompts, a note's highlights, a missing authorship and a score that is no number, the header's
    /// project; the getters of a saved search's watermark and of a plan's two blobs; and the export
    /// sheet's file and switch. A pin move that changes one fails here until the export follows it.
    @Test func theExportMirrorsTheAppsExporterAtThePin() throws {
        let app = Self.layout.upstream.appendingPathComponent("FRUSExplorer")
        func source(_ path: String) throws -> String {
            NoteViewParityTests.flattened(try String(contentsOf: app.appendingPathComponent(path), encoding: .utf8))
        }
        let exporter = try source("Export/ResearchDataExporter.swift")
        let start = try #require(exporter.firstRange(of: "static func makeEnvelope("))
        let end = try #require(exporter.firstRange(of: "private static func savedSearchExport"))
        let makeEnvelope = String(exporter[start.lowerBound..<end.lowerBound])
        var fetches: [String: String] = [:]
        for match in makeEnvelope.matches(of: /FetchDescriptor<(\w+)>\((.*?)\)\)/) {
            fetches[String(match.1)] = String(match.2)
        }
        let sorted = #"SortDescriptor(\."#
        #expect(fetches == [
            "ResearchNote": "", "UserTag": "", "DocumentTagAssignment": "", "DocumentHighlight": "", "Collection": "",
            "SummarizationPrompt": "", "Project": "", "GeneratedSummary": "",
            "ReadingHistoryEntry": "sortBy: [\(sorted)accessedAt)]", "SearchHistoryEntry": "sortBy: [\(sorted)executedAt)]",
            "ExportHistoryEntry": "sortBy: [\(sorted)exportedAt)]",
            "ArchiveVisitPlan": "sortBy: [\(sorted)name), \(sorted)createdAt)]",
            "SavedSearch": "sortBy: [\(sorted)createdAt)]", "WorkingCorpus": "sortBy: [\(sorted)createdAt)]",
            "CustomVolumeScope": "sortBy: [\(sorted)createdAt)]", "DocumentClassificationOverride": "sortBy: [\(sorted)createdAt)]",
            "PersonClusterOverride": "sortBy: [\(sorted)createdAt)]", "AnnotationReview": "sortBy: [\(sorted)reviewedAt)]",
            "ProjectLeadEntry": "sortBy: [\(sorted)firstSurfacedAt)]", "SyncedPreferences": "sortBy: [\(sorted)createdAt)]",
        ], "\(fetches)")
        for line in [
            "let summaries = includeGeneratedSummaries ? try modelContext.fetch(FetchDescriptor<GeneratedSummary>()) : []",
            #"let highlightsByNoteId = Dictionary(grouping: highlights, by: \.noteId)"#,
            "let activeProject = activeProjectId.flatMap { id in projects.first { $0.id == id } }",
            "exportedForProjectName: activeProject?.name, exportedForProjectResearchQuestion: activeProject?.researchQuestion,",
            #"linkedHighlightIds: (highlightsByNoteId[note.id] ?? []).map(\.id),"#,
            "entries: (collection.documentEntries ?? []) .sorted { $0.sortOrder < $1.sortOrder }",
            "prompts: prompts.filter { !$0.isStandard }.map { prompt in",
            "authorship: summary.authorship ?? .aiGenerated,",
            "documents: (plan.documents ?? []) .sorted { $0.documentKey < $1.documentKey }",
            "targets: (plan.targets ?? []) .sorted { $0.targetKey < $1.targetKey }",
            "savedSearches: savedSearches.map(savedSearchExport),",
            "aggregateScore: lead.aggregateScore.isFinite ? lead.aggregateScore : 0,",
            "parameters: search.searchParameters,",
            "let freshness = search.freshness",
            "try envelope.jsonData()",
        ] {
            #expect(exporter.contains(line), "ResearchDataExporter.swift holds \(line)")
        }
        let savedSearch = try source("Models/SavedSearch.swift")
        #expect(savedSearch.contains("guard let freshnessData else { return nil } return try? JSONDecoder().decode(SavedSearchFreshness.self, from: freshnessData)"))
        #expect(savedSearch.contains("if let parametersData, let decoded = try? JSONDecoder().decode(SearchParameters.self, from: parametersData) { return decoded }"))
        let plan = try source("Models/ArchiveVisitPlan.swift")
        for line in [
            "guard let tiersData else { return [] } return (try? JSONDecoder().decode([ArchiveVisitTier].self, from: tiersData)) ?? []",
            "guard let deliverableTogglesData else { return ArchiveVisitDeliverables() }",
            "return (try? JSONDecoder().decode(ArchiveVisitDeliverables.self, from: deliverableTogglesData)) ?? ArchiveVisitDeliverables()",
        ] {
            #expect(plan.contains(line), "ArchiveVisitPlan.swift holds \(line)")
        }
        let sheet = try source("Export/ResearchDataExportView.swift")
        #expect(sheet.contains(#"appendingPathComponent("frus-research-export.json")"#) && ResearchExport.fileName == "frus-research-export.json")
        #expect(sheet.contains("@State private var includeGeneratedSummaries = false"))
        #expect(sheet.contains("includeGeneratedSummaries: includeGeneratedSummaries, activeProjectId: appState.activeProjectId"))
    }

    // MARK: Two stores beside each other

    /// A value as the round trip is held to keep it: a JSON column's as the value it holds, which the
    /// import writes again with a plain `JSONEncoder()`, any other as stored.
    enum Cell: Equatable {
        case value(SQLiteValue)
        case json(ExportCheck.JSONValue?)
    }

    /// Every row a store holds for `owner` in the 23 tables, by table and then by its key, the Mac's
    /// id in uppercase, or the user for the synced settings: the store's order apart, which the export
    /// gives in the app's.
    static func held(_ url: URL) throws -> [String: [String: [String: Cell]]] {
        let rows = try UserStoreRows(url)
        var held: [String: [String: [String: Cell]]] = [:]
        for table in UserStoreSchema.tables {
            let kinds = Dictionary(uniqueKeysWithValues: table.columns.map { ($0.name, $0.kind) })
            for row in try rows.rows(of: table.name) {
                var cells: [String: Cell] = [:]
                for (column, value) in row {
                    cells[column] = kinds[column] == .json
                        ? .json(value.text.flatMap { try? JSONDecoder().decode(ExportCheck.JSONValue.self, from: Data($0.utf8)) })
                        : .value(value)
                }
                held[table.name, default: [:]][row["id"]?.text?.uppercased() ?? "owner"] = cells
            }
        }
        return held
    }

    /// `held` as its export imported again holds it: a summary's missing authorship written as an AI
    /// summary's, as the app's exporter writes it.
    static func asExported(_ held: [String: [String: [String: Cell]]]) -> [String: [String: [String: Cell]]] {
        var held = held
        for (key, summary) in held["summaries"] ?? [:] where summary["authorship"] == .value(.null) {
            held["summaries"]?[key]?["authorship"] = .value(.text(SummaryAuthorship.aiGenerated.rawValue))
        }
        return held
    }

    /// Whether the store holds a summary with no authorship.
    static func withoutAuthorship(_ url: URL) throws -> Bool {
        try UserStoreRows(url).rows(of: "summaries").contains { $0["authorship"] == .null }
    }

    /// `held` with every time cut to its whole second, as the kit's encoder writes a date.
    static func atWholeSeconds(_ held: [String: [String: [String: Cell]]]) -> [String: [String: [String: Cell]]] {
        var held = held
        for table in UserStoreSchema.tables {
            let dates = Set(table.columns.filter { $0.kind == .date }.map(\.name))
            for (key, row) in held[table.name] ?? [:] {
                for (column, cell) in row where dates.contains(column) {
                    guard case .value(.text(let text)) = cell, let date = UserStoreDate.date(text) else { continue }
                    held[table.name]?[key]?[column] = .value(.text(UserStoreDate.text(Date(
                        timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down)))))
                }
            }
        }
        return held
    }

    /// Another value of `original`'s, of `column`'s kind, that a record can hold.
    static func changed(_ original: SQLiteValue, table: String, column: UserStoreSchema.Column) throws -> SQLiteValue {
        let encoder = JSONEncoder()
        func json<T: Encodable>(_ value: T) throws -> SQLiteValue { .text(String(decoding: try encoder.encode(value), as: UTF8.self)) }
        func decoded<T: Decodable>(_ type: T.Type) -> T? {
            original.text.flatMap { try? JSONDecoder().decode(T.self, from: Data($0.utf8)) }
        }
        let schema = StructuredSummarySchema(fields: [.init(name: "Gist", description: "The document's point")])
        switch column.name {
        case "authorship":
            return .text(original.text == "userWritten" ? "aiGenerated" : "userWritten")
        case "response_format":
            return try decoded(ResponseFormat.self) == .general ? json(ResponseFormat.structured(schema: schema)) : json(ResponseFormat.general)
        case "schema":
            return original == .null ? try json(schema) : .null
        case "tiers_data":
            return try json((decoded([ArchiveVisitTier].self) ?? []) + [ArchiveVisitTier(label: "Another", order: 99)])
        case "deliverable_toggles_data":
            var deliverables = decoded(ArchiveVisitDeliverables.self) ?? ArchiveVisitDeliverables()
            deliverables.includeCitationCrib.toggle()
            return try json(deliverables)
        case "parameters_data":
            var parameters = try #require(decoded(SearchParameters.self))
            parameters.keywords = (parameters.keywords ?? "") + " another"
            return try json(parameters)
        case "freshness_data":
            var freshness = decoded(SavedSearchColumns.Freshness.self) ?? SavedSearchColumns.Freshness()
            freshness.matchCountAtLastRun = (freshness.matchCountAtLastRun ?? 0) + 1
            return try json(freshness)
        case "default_subject_tag_ids", "default_country_tag_ids", "document_keys", "volume_ids", "contributing_seed_keys":
            return .text(TagReferences.encode((original.text.flatMap(TagReferences.decode) ?? []) + ["another"]))
        default:
            break
        }
        switch column.kind {
        case .json:
            return .text(TagReferences.encode((original.text.flatMap(TagReferences.decode) ?? []) + [UUID().uuidString]))
        case .uuid: return .text(UUID().uuidString)
        case .text: return .text((original.text ?? "") + " another")
        case .integer: return .integer((original.integer ?? 0) + 1)
        case .boolean: return .integer(original.integer == 1 ? 0 : 1)
        case .real:
            if case .real(let value) = original { return .real(value + 0.5) }
            return .real(Double(original.integer ?? 0) + 0.5)
        case .date:
            let date = original.text.flatMap(UserStoreDate.date) ?? Date(timeIntervalSince1970: 1_767_225_600)
            return .text(UserStoreDate.text(date.addingTimeInterval(86_400)))
        case .blob:
            if case .blob(let bytes) = original { return .blob(bytes + [0x20]) }
            return .blob(Array("{\\rtf1 another}".utf8))
        }
    }
}
