// The import's store half (S16c): a batch's rows written under the importing user with the Mac's ids,
// in one transaction; a row the store holds replaced only by a newer copy, and then only in the
// columns the file carries; an instance's rows keyed by id alone; the user's rows of user_search made
// again from all their notes and summaries; the collections whose saved search the user lacks named;
// and a batch that does not fit refused, writing nothing.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserResearchImportTests {
    static let id = "5E16C000-0000-4000-8000-000000000001"

    /// A tag's row, as the mapping gives one.
    static func tag(_ id: String = id, name: String, modified: String?) -> ImportRow {
        ImportRow(values: ["id": .text(id), "name": .text(name), "created_at": .text("2026-01-01T00:00:00.000Z"),
                           "last_modified": modified.map { .text($0) } ?? .null])
    }

    /// A note's row, its RTF a default as a file before version 7 leaves it, or a value.
    static func note(_ id: String, document: String = "d3", body: String, richText: [UInt8]? = nil, carriesRichText: Bool,
                     created: String = "2026-01-01T00:00:00.000Z", modified: String) -> ImportRow {
        var row = ImportRow(values: [
            "id": .text(id), "document_id": .text(document), "volume_id": .text("frus1961-63v06"), "body_text": .text(body),
            "project_ids": .text("[]"), "user_tag_ids": .text("[]"), "selected_summary_ids": .text("[]"),
            "created_at": .text(created), "last_modified": .text(modified),
        ])
        let rtf: SQLiteValue = richText.map { .blob($0) } ?? .null
        if carriesRichText { row.values["rich_text"] = rtf } else { row.defaults["rich_text"] = rtf }
        return row
    }

    @Test func aBatchsRowsComeInUnderTheUserWithTheMacsIds() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let result = try store.importResearch(ResearchImportBatch(rows: [
            "tags": [Self.tag(name: "Cuba", modified: "2026-02-01T00:00:00.000Z"),
                     Self.tag("5E16C000-0000-4000-8000-000000000002", name: "Laos", modified: nil)],
            "notes": [Self.note("5E16C000-0000-4000-8000-0000000000A1", body: "Imported.", carriesRichText: true,
                                modified: "2026-02-01T00:00:00.000Z")],
        ]), for: "owner")
        #expect(result.counts == ["tags": ImportCount(added: 2), "notes": ImportCount(added: 1)])
        #expect(try store.tags(of: "owner").map(\.id) == [Self.id, "5E16C000-0000-4000-8000-000000000002"])
        #expect(try store.tag(Self.id, of: "owner")?.lastModified == UserStoreDate.date("2026-02-01T00:00:00.000Z"))
        #expect(try rows.userSearch() == [UserSearchRow(volumeId: "frus1961-63v06", documentId: "d3", summaryText: nil,
                                                        noteText: "Imported.")])
        #expect(result.searchableDocuments == 1 && result.unlinkedCollections.isEmpty)
    }

    /// The newer-copy rule: a later time replaces, the same time or an earlier one keeps the store's,
    /// and a copy with no time of change is as new as when it was made.
    @Test func aRowTheStoreHoldsIsReplacedOnlyByANewerCopy() async throws {
        let (store, _, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let second = "5E16C000-0000-4000-8000-000000000002"
        _ = try store.importResearch(ResearchImportBatch(rows: ["tags": [
            Self.tag(name: "Cuba", modified: "2026-02-01T00:00:00.000Z"), Self.tag(second, name: "Laos", modified: nil),
        ]]), for: "owner")
        let cases: [(String?, String, Bool)] = [
            ("2026-02-01T00:00:00.000Z", "Same time", false), ("2026-01-31T00:00:00.000Z", "Earlier", false),
            (nil, "No time", false), ("2026-02-01T00:00:00.001Z", "Later", true),
        ]
        for (modified, name, replaces) in cases {
            let result = try store.importResearch(ResearchImportBatch(rows: ["tags": [Self.tag(name: name, modified: modified)]]),
                                                  for: "owner")
            #expect(result.counts["tags"] == (replaces ? ImportCount(replaced: 1) : ImportCount(kept: 1)), "\(name)")
        }
        #expect(try store.tag(Self.id, of: "owner")?.name == "Later")
        // A stored tag with no time of change is as new as when it was made; a lowercase id names
        // the same row.
        let older = try store.importResearch(ResearchImportBatch(rows: ["tags": [
            Self.tag(second.lowercased(), name: "Laos, before", modified: "2025-12-31T00:00:00.000Z"),
        ]]), for: "owner")
        #expect(older.counts["tags"] == ImportCount(kept: 1))
        let result = try store.importResearch(ResearchImportBatch(rows: ["tags": [
            Self.tag(second.lowercased(), name: "Laos, dated", modified: "2026-01-02T00:00:00.000Z"),
        ]]), for: "owner")
        #expect(result.counts["tags"] == ImportCount(replaced: 1))
        #expect(try store.tags(of: "owner").map(\.name) == ["Laos, dated", "Later"])
        #expect(try store.tag(second, of: "owner")?.id == second, "the id as the store spells it")
    }

    /// A replace writes the columns the file carries, and keeps the rest; a new row takes the defaults.
    @Test func aReplaceWritesOnlyWhatTheFileCarries() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let id = "5E16C000-0000-4000-8000-0000000000A1"
        let rtf = Array(#"{\rtf1\ansi Bold}"#.utf8)
        _ = try store.importResearch(ResearchImportBatch(rows: ["notes": [
            Self.note(id, body: "Bold", richText: rtf, carriesRichText: true, modified: "2026-02-01T00:00:00.000Z"),
            Self.note("5E16C000-0000-4000-8000-0000000000A2", body: "New", richText: Array("default".utf8), carriesRichText: false,
                      modified: "2026-02-01T00:00:00.000Z"),
        ]]), for: "owner")
        #expect(try rows.storedNote("5E16C000-0000-4000-8000-0000000000A2")?.richText == Array("default".utf8))
        // A newer copy from a file that cannot carry RTF: its text written, the RTF kept.
        let result = try store.importResearch(ResearchImportBatch(rows: ["notes": [
            Self.note(id, body: "Bold, edited", carriesRichText: false, modified: "2026-03-01T00:00:00.000Z"),
        ]]), for: "owner")
        #expect(result.counts["notes"] == ImportCount(replaced: 1))
        let stored = try #require(try rows.storedNote(id))
        #expect(stored.bodyText == "Bold, edited" && stored.richText == rtf && stored.lastModified == "2026-03-01T00:00:00.000Z")
        #expect(try rows.userSearch().map(\.noteText) == ["Bold, edited\n\nNew"])
    }

    /// Each user's rows are theirs, with the same Mac ids; an instance's are the instance's, by id.
    @Test func eachUsersRowsAreTheirsAndAnInstancesAreShared() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        let correction = ImportRow(values: [
            "id": .text(Self.id), "volume_id": .text("frus1961-63v06"), "document_id": .text("d4"),
            "is_editorial_note": .integer(1), "parsed_is_editorial_note": .integer(0), "created_at": .text("2026-01-01T00:00:00.000Z"),
        ])
        let batch = ResearchImportBatch(rows: ["tags": [Self.tag(name: "Cuba", modified: nil)], "classification_overrides": [correction]])
        #expect(try store.importResearch(batch, for: "owner").counts
                == ["tags": ImportCount(added: 1), "classification_overrides": ImportCount(added: 1)])
        #expect(try store.importResearch(batch, for: "reader").counts
                == ["tags": ImportCount(added: 1), "classification_overrides": ImportCount(kept: 1)])
        #expect(try store.tags(of: "owner").map(\.id) == [Self.id] && store.tags(of: "reader").map(\.id) == [Self.id])
        #expect(try store.classificationOverrides().map(\.id) == [Self.id])
    }

    /// user_search is made again for the user from every note and summary they hold, not only the
    /// batch's, and another user's rows are left as they are.
    @Test func userSearchIsMadeAgainForTheUser() async throws {
        let (store, rows, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        try rows.addNote("5E16C000-0000-4000-8000-0000000000B1", user: "reader", bodyText: "The reader's.")
        try rows.addNote("5E16C000-0000-4000-8000-0000000000B2", documentId: "d9", bodyText: "Written beside the store.")
        try rows.addSummary("5E16C000-0000-4000-8000-0000000000B3", documentId: "d9", responseText: "Its summary.")
        try rows.addSummary("5E16C000-0000-4000-8000-0000000000B4", documentId: "d8", responseText: "A draft.", isHeadnoteDraft: true)
        let result = try store.importResearch(ResearchImportBatch(rows: ["notes": [
            Self.note("5E16C000-0000-4000-8000-0000000000A1", body: "Imported.", carriesRichText: true,
                      modified: "2026-02-01T00:00:00.000Z"),
        ]]), for: "owner")
        #expect(result.searchableDocuments == 2, "d8's draft alone gives no row")
        #expect(Set(try rows.userSearch().map { "\($0.documentId): \($0.summaryText ?? "-") / \($0.noteText ?? "-")" })
                == ["d3: - / Imported.", "d9: Its summary. / Written beside the store."])
        #expect(try rows.userSearch(user: "reader").isEmpty, "the reader's rows, theirs to make at their own next write")
    }

    @Test func theCollectionsWhoseSavedSearchTheUserLacksAreNamed() async throws {
        let (store, _, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        func collection(_ number: Int, search: Int?) -> ImportRow {
            ImportRow(values: [
                "id": .text("5E16C000-0000-4000-8000-00000000005\(number)"), "name": .text("Collection \(number)"),
                "note": .null, "project_ids": .text("[]"),
                "saved_search_id": search.map { .text("5E16C000-0000-4000-8000-00000000009\($0)") } ?? .null,
                "created_at": .null, "last_modified": .null,
            ], defaults: [
                "subtitle": .null, "author_line": .null, "introduction_text": .null, "introduction_rich_text": .null,
                "include_colophon": .integer(0), "include_project_provenance": .integer(0), "include_method_appendix": .integer(0),
                "default_body_depth": .text("full"), "footnote_style": .text("all"), "include_footnotes": .null,
                "include_source_note": .null, "toc_style": .text("citation"), "apply_highlights": .integer(0),
                "include_notes": .integer(1), "include_word_cloud": .integer(0), "default_include_headnote": .integer(0),
                "summary_prompt_id": .null,
            ])
        }
        let search = ImportRow(values: [
            "id": .text("5E16C000-0000-4000-8000-000000000091"), "name": .text("A search"), "query_text": .text("a"),
            "phrase_text": .text(""), "prefix_wildcard": .text(""), "boolean_mode_raw": .text("and"), "excluded_terms_csv": .text(""),
            "scope_flags": .integer(7), "date_range_start": .null, "date_range_end": .null, "subject_tag_ids_csv": .text(""),
            "document_type_filter_raw": .text("all"), "person_ref": .text(""), "sort_order": .text("relevance"),
            "created_at": .null, "last_modified": .null, "parameters_data": .null, "freshness_data": .null,
        ])
        let result = try store.importResearch(ResearchImportBatch(rows: [
            "collections": [collection(1, search: 1), collection(2, search: 2), collection(3, search: nil)],
            "saved_searches": [search],
        ]), for: "owner")
        #expect(result.unlinkedCollections == [UnlinkedCollection(id: "5E16C000-0000-4000-8000-000000000052", name: "Collection 2")])
    }

    /// A batch that does not fit the tables is refused before anything is written, and a row SQLite
    /// refuses rolls back the whole import.
    @Test func aBatchThatDoesNotFitWritesNothing() async throws {
        let (store, _, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let good = Self.tag(name: "Cuba", modified: nil)
        var stray = good
        stray.values["colour"] = .text("red")
        var short = good
        short.values["name"] = nil
        var anonymous = good
        anonymous.values["id"] = .null
        let refusals: [(ResearchImportBatch, ResearchImportError)] = [
            (ResearchImportBatch(rows: ["tags": [good], "labels": []]), .unknownTable("labels")),
            (ResearchImportBatch(rows: ["tags": [good, stray]]), .unknownColumn(table: "tags", column: "colour")),
            (ResearchImportBatch(rows: ["tags": [good, short]]), .missingColumn(table: "tags", column: "name")),
            (ResearchImportBatch(rows: ["tags": [good, anonymous]]), .missingId(table: "tags")),
        ]
        for (batch, refusal) in refusals {
            #expect(throws: refusal) { try store.importResearch(batch, for: "owner") }
        }
        var unnamed = Self.tag("5E16C000-0000-4000-8000-000000000002", name: "", modified: nil)
        unnamed.values["name"] = .null
        #expect(throws: SQLiteError.self) {
            try store.importResearch(ResearchImportBatch(rows: ["tags": [good, unnamed]]), for: "owner")
        }
        #expect(try store.tags(of: "owner").isEmpty, "nothing of any of them was kept")
    }

    /// Every table says how new its copy is, by columns that hold its dates.
    @Test func everyTableHasAStamp() {
        for table in UserStoreSchema.tables {
            let columns = ImportStamp.columns[table.name] ?? []
            #expect(!columns.isEmpty, "\(table.name)")
            for column in columns {
                #expect(table.columns.first { $0.name == column }?.kind == .date, "\(table.name).\(column)")
            }
        }
        #expect(Set(ImportStamp.columns.keys) == Set(UserStoreSchema.tables.map(\.name)))
    }
}
