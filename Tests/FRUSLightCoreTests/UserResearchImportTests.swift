// The import's store half (S16c, on the kit's plan since #1915's follow-up): in one transaction, what the importing
// user holds is read, every column of their rows of each table and of every row of an instance's, and given to the
// plan; what the plan returns is written, each addition a new row under the user with the Mac's id and each
// replacement the columns it names of the row it names, by the id as the store spells it, the preferences by the user
// alone; the user's rows of user_search are made again from all their notes and summaries; and writes that do not fit
// the tables, or a plan that throws, write nothing. Which record is added, replaced or kept is the kit's plan's to
// say, which FRUSParityTests' ImportParityTests holds through the route.

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

    /// A note's row, every column, as the mapping gives one.
    static func note(_ id: String, document: String = "d3", body: String, richText: [UInt8]? = nil,
                     modified: String = "2026-02-01T00:00:00.000Z") -> ImportRow {
        ImportRow(values: [
            "id": .text(id), "document_id": .text(document), "volume_id": .text("frus1961-63v06"), "body_text": .text(body),
            "rich_text": richText.map { .blob($0) } ?? .null, "project_ids": .text("[]"), "user_tag_ids": .text("[]"),
            "selected_summary_ids": .text("[]"), "created_at": .text("2026-01-01T00:00:00.000Z"), "last_modified": .text(modified),
        ])
    }

    /// A set of synced preferences, every column.
    static func preferences(style: String, updated: String) -> ImportRow {
        ImportRow(values: [
            "created_at": .text("2026-01-01T00:00:00.000Z"), "updated_at": .text(updated), "wc_min_length": .integer(3),
            "wc_min_count": .integer(2), "wc_fold_plurals": .integer(1), "wc_filter_markings": .integer(1),
            "wc_exclude_boilerplate": .integer(1), "wc_global_stopwords_json": .text("[]"), "wc_lens_stopwords_json": .text("{}"),
            "citation_style_raw": .text(style), "default_document_mode_raw": .text(""), "research_logging_enabled": .integer(1),
            "list_order_json": .text("{}"),
        ])
    }

    /// A correction of the instance's, every column.
    static let correction = ImportRow(values: [
        "id": .text(id), "volume_id": .text("frus1961-63v06"), "document_id": .text("d4"), "is_editorial_note": .integer(1),
        "parsed_is_editorial_note": .integer(0), "created_at": .text("2026-01-01T00:00:00.000Z"),
    ])

    /// The plan is given what the user holds, every column of their rows and of an instance's every row, read in the
    /// import's transaction; what it returns is written, and counted, and user_search is made again.
    @Test(arguments: UserStoreKind.available) func thePlanIsGivenWhatTheUserHoldsAndWhatItReturnsIsWritten(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        let mine = "5E16C000-0000-4000-8000-0000000000A1"
        try rows.addNote(mine.lowercased(), documentId: "d3", bodyText: "Before.", richText: Array("{\\rtf1 Before.}".utf8))
        try rows.addNote("5E16C000-0000-4000-8000-0000000000B1", user: "reader", bodyText: "The reader's.")
        _ = try store.importResearch(for: "reader") { _ in [ImportWrite("classification_overrides", .add, row: Self.correction)] }

        var given: ResearchRows?
        let result = try store.importResearch(for: "owner") { held in
            given = held
            return [
                ImportWrite("tags", .add, row: Self.tag(name: "Cuba", modified: "2026-02-01T00:00:00.000Z")),
                ImportWrite("notes", .replace, id: mine.lowercased(),
                            row: ImportRow(values: ["body_text": .text("After."), "last_modified": .text("2026-03-01T00:00:00.000Z")])),
            ]
        }
        let held = try #require(given)
        #expect(Set(held.rows.keys) == Set(UserStoreSchema.tables.map(\.name)), "every table")
        #expect(held["notes"].map { $0.values["id"]?.text } == [mine.lowercased()], "the user's own, its id as the store spells it")
        #expect(held["classification_overrides"].map { $0.values["id"]?.text } == [Self.id], "the instance's, whoever wrote it")
        for (name, table) in held.rows {
            let columns = Set(try #require(UserStoreSchema.tables.first { $0.name == name }).columns.map(\.name))
            #expect(table.allSatisfy { Set($0.values.keys) == columns }, "\(name): every column")
        }

        #expect(result.counts == ["tags": ImportCount(added: 1), "notes": ImportCount(replaced: 1)])
        #expect(try store.tags(of: "owner").map(\.id) == [Self.id])
        let note = try #require(try rows.storedNote(mine))
        #expect(note.bodyText == "After." && note.lastModified == "2026-03-01T00:00:00.000Z")
        #expect(note.richText == Array("{\\rtf1 Before.}".utf8), "a column the replacement does not name is kept")
        #expect(try rows.storedNote("5E16C000-0000-4000-8000-0000000000B1", user: "reader")?.bodyText == "The reader's.")
        #expect(try rows.userSearch().map(\.noteText) == ["After."] && result.searchableDocuments == 1)
    }

    /// Each user's rows are theirs, with the same Mac ids; an instance's are the instance's, by id; and a user's
    /// preferences, which have no id, are replaced by the user alone.
    @Test(arguments: UserStoreKind.available) func eachUsersRowsAreTheirsAndAnInstancesAreShared(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        let writes = [ImportWrite("tags", .add, row: Self.tag(name: "Cuba", modified: nil)),
                      ImportWrite("preferences", .add, row: Self.preferences(style: "chicago", updated: "2026-01-02T00:00:00.000Z"))]
        #expect(try store.importResearch(for: "owner") { _ in writes + [ImportWrite("classification_overrides", .add, row: Self.correction)] }
            .counts == ["tags": ImportCount(added: 1), "preferences": ImportCount(added: 1), "classification_overrides": ImportCount(added: 1)])
        #expect(try store.importResearch(for: "reader") { _ in writes }.counts
                == ["tags": ImportCount(added: 1), "preferences": ImportCount(added: 1)])
        #expect(try store.tags(of: "owner").map(\.id) == [Self.id] && store.tags(of: "reader").map(\.id) == [Self.id])
        #expect(try store.classificationOverrides().map(\.id) == [Self.id])

        _ = try store.importResearch(for: "reader") { held in
            #expect(held["preferences"].count == 1)
            return [ImportWrite("preferences", .replace, row: ImportRow(values: ["citation_style_raw": .text("mla"),
                                                                                  "updated_at": .text("2026-02-01T00:00:00.000Z")]))]
        }
        #expect(try rows.column("SELECT citation_style_raw FROM preferences ORDER BY user_id") == ["chicago", "mla"],
                "the owner's set, then the reader's")
    }

    /// user_search is made again for the user from every note and summary they hold, not only those the import wrote,
    /// and another user's rows are left as they are.
    @Test(arguments: UserStoreKind.available) func userSearchIsMadeAgainForTheUser(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        try rows.addNote("5E16C000-0000-4000-8000-0000000000B1", user: "reader", bodyText: "The reader's.")
        try rows.addNote("5E16C000-0000-4000-8000-0000000000B2", documentId: "d9", bodyText: "Written beside the store.")
        try rows.addSummary("5E16C000-0000-4000-8000-0000000000B3", documentId: "d9", responseText: "Its summary.")
        try rows.addSummary("5E16C000-0000-4000-8000-0000000000B4", documentId: "d8", responseText: "A draft.", isHeadnoteDraft: true)
        let result = try store.importResearch(for: "owner") { _ in
            [ImportWrite("notes", .add, row: Self.note("5E16C000-0000-4000-8000-0000000000A1", body: "Imported."))]
        }
        #expect(result.searchableDocuments == 2, "d8's draft alone gives no row")
        #expect(Set(try rows.userSearch().map { "\($0.documentId): \($0.summaryText ?? "-") / \($0.noteText ?? "-")" })
                == ["d3: - / Imported.", "d9: Its summary. / Written beside the store."])
        #expect(try rows.userSearch(user: "reader").isEmpty, "the reader's rows, theirs to make at their own next write")
    }

    /// Writes that do not fit the tables are refused before anything is written; a row the store's database refuses,
    /// SQLite or PostgreSQL, rolls back the whole import; and so does a plan that throws.
    @Test(arguments: UserStoreKind.available) func writesThatDoNotFitWriteNothing(_ kind: UserStoreKind) async throws {
        let (store, _, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let good = ImportWrite("tags", .add, row: Self.tag(name: "Cuba", modified: nil))
        var stray = good
        stray.row.values["colour"] = .text("red")
        var short = good
        short.row.values["name"] = nil
        var anonymous = good
        anonymous.row.values["id"] = .null
        let unnamed = ImportWrite("tags", .replace, row: ImportRow(values: ["name": .text("Laos")]))
        let named = ImportWrite("preferences", .replace, id: Self.id, row: ImportRow(values: ["citation_style_raw": .text("mla")]))
        let refusals: [([ImportWrite], ResearchImportError)] = [
            ([good, ImportWrite("labels", .add, row: ImportRow(values: [:]))], .unknownTable("labels")),
            ([good, stray], .unknownColumn(table: "tags", column: "colour")),
            ([good, short], .missingColumn(table: "tags", column: "name")),
            ([good, anonymous], .missingId(table: "tags")),
            ([good, unnamed], .missingId(table: "tags")),
            ([good, named], .missingId(table: "preferences")),
        ]
        for (writes, refusal) in refusals {
            #expect(throws: refusal) { try store.importResearch(for: "owner") { _ in writes } }
        }
        var refused = ImportWrite("tags", .add, row: Self.tag("5E16C000-0000-4000-8000-000000000002", name: "", modified: nil))
        refused.row.values["name"] = .null
        #expect {
            try store.importResearch(for: "owner") { _ in [good, refused] }
        } throws: { $0 is SQLiteError || $0 is PostgreSQLError }
        struct Refused: Error {}
        #expect(throws: Refused.self) { try store.importResearch(for: "owner") { _ in throw Refused() } }
        #expect(try store.tags(of: "owner").isEmpty, "nothing of any of them was kept")
    }

    /// S16e's batch, by the newer-copy rule: a later time replaces, the same time or an earlier one keeps the store's,
    /// and a copy with no time of change is as new as when it was made; a replacement writes the columns the row
    /// carries, by the id as the store spells it.
    @Test(arguments: UserStoreKind.available) func aBatchReplacesARowOnlyByANewerCopy(_ kind: UserStoreKind) async throws {
        let (store, _, directory) = try await UserTagTests.open(kind)
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
        let result = try store.importResearch(ResearchImportBatch(rows: ["tags": [
            Self.tag(second.lowercased(), name: "Laos, dated", modified: "2026-01-02T00:00:00.000Z"),
        ]]), for: "owner")
        #expect(result.counts["tags"] == ImportCount(replaced: 1))
        #expect(try store.tags(of: "owner").map(\.name) == ["Laos, dated", "Later"])
        #expect(try store.tag(second, of: "owner")?.id == second, "the id as the store spells it")
    }

    /// Every table says how new its copy is, by columns that hold its dates: the rule S16e's research database writes
    /// its rows by.
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
