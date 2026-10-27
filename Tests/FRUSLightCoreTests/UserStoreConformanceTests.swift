// The user store's conformance suite (S14d): every store method answers alike on app.db and on the
// PostgreSQL store. These tests hold what is the stores' own, each store's migrations, its users and
// corrections, the values it keeps, and the database the kit's search attaches; the tests of each
// protocol's methods, UserTagTests, UserNoteTests, UserHighlightTests, UserSummaryTests,
// UserSearchTests, UserResearchImportTests and UserResearchExportTests, take a store kind too. Each
// runs on every store `UserStoreKind.available` names: app.db always, and the PostgreSQL store where
// FRUS_TEST_POSTGRES_URL names a database, as CI's swift job does. A later row's store methods join it
// so: tests that take `_ kind: UserStoreKind` with `arguments: UserStoreKind.available`, and open
// their store with `UserTagTests.open(kind)`.

import CSQLite
@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserStoreConformanceTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z
    static let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
    static let d2 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d2")

    @Test(arguments: UserStoreKind.available)
    func aStoreIsAtThisBuildsSchemaAndAStartMigratesItOnce(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        #expect(try store.schemaVersion() == UserStoreMigrations.all.count)
        #expect(store.migration?.from == 0 && store.migration?.to == UserStoreMigrations.all.count)
        #expect(try store.singleUserID() == "owner")
        #expect(try store.user("owner") == UserAccount(id: "owner", displayName: "Owner"))
        #expect(try store.user("nobody") == nil)
        let tag = try store.createTag(named: "Kept", for: "owner", at: Self.created)

        let reopened = try await test.reopen()
        defer { (reopened as? PostgreSQLUserStore)?.close() }
        #expect(reopened.migration == nil, "a store at this build's schema is opened as it is")
        #expect(try reopened.tags(of: "owner") == [tag])
    }

    /// Each store's migrations make the 23 tables, each column as `UserStoreSchema` describes it and of
    /// the type its kind is kept as, with `user_id` first in a user table's key, and nothing else but
    /// the users and the migrations: app.db with `user_search` beside them, the PostgreSQL store with
    /// each table's `rowid`, the number SQLite gives every row, and every text in the "C" collation.
    @Test(arguments: UserStoreKind.available)
    func eachStoresMigrationsMakeTheTablesTheSchemaDescribes(_ kind: UserStoreKind) async throws {
        let (_, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        func key(_ table: UserStoreSchema.Table, _ name: String) -> Int { (table.primaryKey.firstIndex(of: name) ?? -1) + 1 }
        for table in UserStoreSchema.tables {
            var expected: [String] = []
            if table.scope == .user { expected.append("user_id TEXT NOT NULL \(key(table, "user_id"))") }
            expected += table.columns.map { "\($0.name) \($0.kind.sqlType) \($0.optional ? "NULL" : "NOT NULL") \(key(table, $0.name))" }
            let actual: [String]
            switch kind {
            case .sqlite:
                actual = try rows.stored("SELECT name, type, \"notnull\", pk FROM pragma_table_info(?)", [.text(table.name)]).map {
                    "\($0[0].text ?? "") \($0[1].text ?? "") \($0[2].integer == 1 ? "NOT NULL" : "NULL") \($0[3].integer ?? 0)"
                }
            case .postgreSQL:
                let types = ["text": "TEXT", "bigint": "INTEGER", "double precision": "REAL", "bytea": "BLOB"]
                let columns = try rows.stored(
                    """
                    SELECT c.column_name::text, c.data_type::text, c.is_nullable::text, coalesce(c.collation_name::text, ''),
                           coalesce((SELECT k.ordinal_position FROM information_schema.key_column_usage k
                                     JOIN information_schema.table_constraints t
                                       ON t.constraint_name = k.constraint_name AND t.table_schema = k.table_schema
                                     WHERE t.constraint_type = 'PRIMARY KEY' AND k.table_schema = c.table_schema
                                       AND k.table_name = c.table_name AND k.column_name = c.column_name), 0)
                        FROM information_schema.columns c
                        WHERE c.table_schema = current_schema() AND c.table_name = ?
                        ORDER BY c.ordinal_position
                    """, [.text(table.name)])
                #expect(columns.first?[0].text == "rowid" && columns.first?[1].text == "bigint", "\(table.name) carries rowid first")
                let identity = try rows.stored(
                    "SELECT is_identity::text FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = ? AND column_name = 'rowid'",
                    [.text(table.name)])
                #expect(identity.first?.first?.text == "YES", "\(table.name)'s rowid numbers its rows as they come")
                let texts = columns.dropFirst().filter { $0[1].text == "text" }
                #expect(texts.allSatisfy { $0[3].text == "C" }, "\(table.name)'s texts compare as bytes")
                actual = columns.dropFirst().map {
                    "\($0[0].text ?? "") \(types[$0[1].text ?? ""] ?? $0[1].text ?? "") \($0[2].text == "NO" ? "NOT NULL" : "NULL") \($0[4].integer ?? 0)"
                }
            }
            #expect(actual == expected, "\(table.name) as \(kind)'s migrations make it")
        }
        let tables: Set<String>
        switch kind {
        case .sqlite:
            tables = Set(try rows.stored("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'user_search%'", [])
                .compactMap { $0[0].text })
        case .postgreSQL:
            tables = Set(try rows.stored("SELECT table_name::text FROM information_schema.tables WHERE table_schema = current_schema()", [])
                .compactMap { $0[0].text })
        }
        #expect(tables == Set(UserStoreSchema.tables.map(\.name) + ["users", "schema_migrations"]))
        #expect(PostgreSQLMigrations.all.count == UserStoreMigrations.all.count, "the same numbered migrations")
    }

    /// `DocumentClassificationOverrideStore.setOverride`'s rule on both stores: a document's newest
    /// correction takes a new value, one with no time the oldest of all, as the app's sort leaves it.
    @Test(arguments: UserStoreKind.available) func aDocumentsNewestCorrectionTakesTheChange(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let insert = """
            INSERT INTO classification_overrides (id, volume_id, document_id, is_editorial_note, parsed_is_editorial_note, created_at)
                VALUES (?, 'frus1961-63v06', 'd1', 0, 0, ?)
            """
        try rows.run(insert, [.text("C0000000-0000-4000-8000-000000000003"), .null])
        try rows.run(insert, [.text("B0000000-0000-4000-8000-000000000002"), .text("2026-01-02T00:00:00.000Z")])
        try rows.run(insert, [.text("A0000000-0000-4000-8000-000000000001"), .text("2026-01-01T00:00:00.000Z")])
        #expect(try store.classificationOverrides().map(\.id) == [
            "C0000000-0000-4000-8000-000000000003", "A0000000-0000-4000-8000-000000000001", "B0000000-0000-4000-8000-000000000002",
        ], "oldest first, one with no time first of all")

        let stored = try store.record(ClassificationOverride(volumeId: "frus1961-63v06", documentId: "d1", isEditorialNote: true,
                                                             parsedIsEditorialNote: true, createdAt: Self.created))
        #expect(stored.id == "B0000000-0000-4000-8000-000000000002" && stored.isEditorialNote && !stored.parsedIsEditorialNote,
                "the newest keeps its id and what the TEI said")
        let other = try store.record(ClassificationOverride(id: "D0000000-0000-4000-8000-000000000004", volumeId: "frus1961-63v06",
                                                            documentId: "d2", isEditorialNote: true, parsedIsEditorialNote: false,
                                                            createdAt: nil))
        #expect(try store.classificationOverrides().map(\.id) == [
            "C0000000-0000-4000-8000-000000000003", other.id, "A0000000-0000-4000-8000-000000000001", stored.id,
        ])
        #expect(try store.classificationOverrides().last == stored)
    }

    /// What a store is given comes back as it was: text in every script, a NUL cut where SQLite's
    /// binding cuts it, a note's RTF as its bytes, whatever they are, an empty one empty and never
    /// none; a highlight's offsets at the ends of 64-bit integers; a score as a double.
    @Test(arguments: UserStoreKind.available) func valuesComeBackAsTheyWereWritten(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let text = "Ελληνικά, עברית, 中文, emoji 🇺🇸 and e\u{301}, “quoted”, 'single' and \"double\", a ? and $1."
        let bytes: [UInt8] = [0, 1, 0x7F, 0x80, 0xFE, 0xFF] + Array("{\\rtf1}".utf8)
        let note = try UserNoteTests.make(store, text, richText: bytes)
        #expect(try store.note(note.id, of: "owner")?.bodyText == text)
        #expect(try store.note(note.id, of: "owner")?.richText == bytes)
        let cut = try UserNoteTests.make(store, "Before\u{0}after", richText: [])
        let read = try #require(try store.note(cut.id, of: "owner"))
        #expect(read.bodyText == "Before", "text after a NUL is not kept, as SQLite binds a text up to its first NUL")
        #expect(read.richText == [], "an empty RTF is kept empty, which a reader takes as no formatting, never as none")

        let highlight = try store.createHighlight(in: Self.d1, start: 0, end: Int(Int64.max), colorTag: "yellow", selectedText: "",
                                                  renderingVersion: "", for: "owner", at: Self.created)
        #expect(try store.highlight(highlight.id, of: "owner")?.endOffset == Int(Int64.max))
        _ = try store.importResearch(ResearchImportBatch(rows: ["project_leads": [ImportRow(values: [
            "id": .text("5E16D000-0000-4000-8000-000000000001"), "project_id": .text("5E16D000-0000-4000-8000-000000000002"),
            "volume_id": .text("frus1961-63v06"), "document_id": .text("d1"), "aggregate_score": .real(0.1 + 0.2),
            "contributing_seed_keys": .text("[]"), "header": .text("A lead"), "document_number": .null,
            "is_editorial_note": .integer(0), "first_surfaced_at": .text("2026-01-01T00:00:00.000Z"),
            "last_computed_at": .text("2026-01-01T00:00:00.000Z"), "dismissed": .integer(1),
        ])]]), for: "owner")
        let lead = try #require(try store.researchRows(for: "owner", tables: ["project_leads"])["project_leads"].first)
        #expect(lead.values["aggregate_score"] == .real(0.1 + 0.2) && lead.values["dismissed"] == .integer(1))
        #expect(lead.values["document_number"] == .null)
        #expect(try rows.stored("SELECT count(*) FROM notes WHERE user_id = ? AND body_text = ?", [.text("owner"), .text(text)])
            .first?.first == .integer(1), "a ? and a $1 in a value are not placeholders")
    }

    /// The database the kit's search attaches holds, for every change, what the kit at `1c18b51e`
    /// (FRUS-Explorer#1806, `SearchUserSource.attachedStore(userId:)`) reads there: `user_search`, the
    /// FTS5 table app.db's migration 2 makes, a row of each user's text for each document; and the tag
    /// assignments, whose user, volume, document and tag are the store's. For app.db it is the store;
    /// for the PostgreSQL store, its local copy, written beside each change. The kit's statements of
    /// that source run on it here as they are written there, until S17d searches through the kit.
    @Test(arguments: UserStoreKind.available) func theSearchDatabaseHoldsWhatTheKitsSearchReads(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try rows.addUser("reader")
        let search = try SQLiteConnection(store.searchDatabase.path, readOnly: true)
        defer { search.close() }
        /// The store's assignments, and the searchable database's, each as user, volume, document and tag.
        func assignments() throws -> ([[SQLiteValue]], [[SQLiteValue]]) {
            let sql = "SELECT user_id, volume_id, document_id, tag_id FROM tag_assignments ORDER BY user_id, volume_id, document_id, tag_id"
            return (try rows.stored(sql, []), try search.query(sql))
        }
        func expectAssignmentsCopied(_ comment: Comment) throws {
            let (stored, searched) = try assignments()
            #expect(stored == searched, comment)
        }

        let laos = try store.createTag(named: "Laos", for: "owner", at: Self.created)
        let cuba = try store.createTag(named: "Cuba", for: "owner", at: Self.created)
        let theirs = try store.createTag(named: "Theirs", for: "reader", at: Self.created)
        try store.setTags([laos.id, cuba.id], of: Self.d1, for: "owner", at: Self.created)
        try store.setTags([laos.id], of: Self.d2, for: "owner", at: Self.created)
        try store.setTags([theirs.id], of: Self.d1, for: "reader", at: Self.created)
        try expectAssignmentsCopied("after the picker's Done")
        #expect(try assignments().1.count == 4)
        try store.removeTag(cuba.id, from: Self.d1, for: "owner")
        try expectAssignmentsCopied("after the rail's ×")
        #expect(throws: TagStoreError.self) { try store.setTags([laos.id, "5E16D000-0000-4000-8000-0000000000FF"], of: Self.d2,
                                                                for: "owner", at: Self.created) }
        try expectAssignmentsCopied("a refused change changes neither")
        _ = try store.mergeTag(laos.id, into: cuba.id, for: "owner", at: Self.created)
        try expectAssignmentsCopied("after a merge")
        _ = try store.deleteTag(cuba.id, for: "owner", at: Self.created)
        try expectAssignmentsCopied("after a delete")
        #expect(try assignments().1 == [[.text("reader"), .text("frus1961-63v06"), .text("d1"), .text(theirs.id)]])
        _ = try store.importResearch(ResearchImportBatch(rows: ["tag_assignments": [ImportRow(values: [
            "id": .text("5E16D000-0000-4000-8000-000000000010"), "volume_id": .text("frus1961-63v06"), "document_id": .text("d2"),
            "tag_id": .text(laos.id.lowercased()), "created_at": .text("2026-01-01T00:00:00.000Z"),
        ])]]), for: "owner")
        try expectAssignmentsCopied("after an import, a dangling id in lowercase kept as it came")

        let note = try UserNoteTests.make(store, "Negotiating the Laos settlement.", at: Self.created)
        _ = try store.createOwnSummary(in: Self.d2, text: "Cabled instructions.", responseFormat: #"{"general":{}}"#, for: "owner",
                                       at: Self.created)
        _ = try UserNoteTests.make(store, "Their negotiation.", user: "reader", at: Self.created)

        // The kit's statements, attached as it attaches the store: read-only, as `user_store`, beside a
        // stand-in for the index's `document_cache`, whose rowid is the document's.
        let index = try SQLiteConnection(":memory:", readOnly: false, create: true)
        defer { index.close() }
        try index.execute("CREATE TABLE document_cache (volume_id TEXT, document_id TEXT, user_tag_ids TEXT)")
        try index.execute("INSERT INTO document_cache (volume_id, document_id) VALUES ('frus1961-63v06', 'd1'), ('frus1961-63v06', 'd2')")
        _ = try index.query("ATTACH DATABASE ? AS user_store", [.text("\(store.searchDatabase.standardizedFileURL.absoluteString)?mode=ro")])
        let matches = """
            SELECT dc.rowid AS docrowid, bm25(us.user_search) AS score \
            FROM user_store.user_search us \
            JOIN document_cache dc ON dc.volume_id = us.volume_id AND dc.document_id = us.document_id \
            WHERE us.user_search MATCH ? AND us.user_id = ?
            """
        #expect(try index.query(matches, [.text("negotiate"), .text("owner")]).map { $0[0] } == [.integer(1)], "porter stems a note's words")
        #expect(try index.query(matches, [.text("cable"), .text("owner")]).map { $0[0] } == [.integer(2)], "and a summary's")
        #expect(try index.query(matches, [.text("negotiate"), .text("reader")]).map { $0[0] } == [.integer(1)], "each user's own rows")
        // The exact-word filter's subquery reads the two texts by name, through `frus_exact_word`, a
        // function only the kit's connection has.
        let texts = """
            SELECT us.volume_id, us.document_id, us.summary_text, us.note_text FROM user_store.user_search us \
            WHERE us.user_id = ? ORDER BY us.document_id
            """
        #expect(try index.query(texts, [.text("owner")]) == [
            [.text("frus1961-63v06"), .text("d1"), .null, .text("Negotiating the Laos settlement.")],
            [.text("frus1961-63v06"), .text("d2"), .text("Cabled instructions."), .null],
        ])
        let rowTags = """
            SELECT dc.document_id, (SELECT group_concat(id, ' ') FROM (\
            SELECT DISTINCT upper(ta.tag_id) AS id FROM user_store.tag_assignments ta \
            WHERE ta.user_id = ? AND ta.volume_id = dc.volume_id AND ta.document_id = dc.document_id \
            ORDER BY id)) AS user_tag_ids FROM document_cache dc ORDER BY dc.rowid
            """
        #expect(try index.query(rowTags, [.text("reader")]) == [[.text("d1"), .text(theirs.id)], [.text("d2"), .null]])
        #expect(try index.query(rowTags, [.text("owner")]) == [[.text("d1"), .null], [.text("d2"), .text(laos.id)]],
                "an id as the kit reads it, in uppercase")
        let tagKeys = """
            SELECT dc.document_id FROM document_cache dc WHERE (dc.volume_id, dc.document_id) IN (\
            SELECT ta.volume_id, ta.document_id FROM user_store.tag_assignments ta \
            WHERE ta.user_id = ? AND ta.tag_id = ? COLLATE NOCASE)
            """
        #expect(try index.query(tagKeys, [.text("owner"), .text(laos.id)]) == [[.text("d2")]])
        #expect(try rows.userSearch().map(\.documentId) == ["d1", "d2"])
        try store.deleteNote(note.id, for: "owner")
        #expect(try index.query(matches, [.text("negotiate"), .text("owner")]).isEmpty, "a delete reaches it at once")
    }
}
