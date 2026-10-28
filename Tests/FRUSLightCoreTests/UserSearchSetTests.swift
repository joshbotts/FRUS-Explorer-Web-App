// Saved searches, working corpora and volume scopes in the user store (S17e), on every store the
// conformance suite runs on: each user's rows of the three tables, kept with the columns they were
// written with, found by the Mac's id in any letter case, changed in the columns named alone, and
// deleted, the user's alone.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserSearchSetTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z
    static let first = "0C6B1D0E-5E2B-4E40-9A43-8E1A5D1E2F01"
    static let second = "7F1C2A3B-4D5E-4F60-8A71-9B2C3D4E5F02"

    /// A scope's row, as the API writes one.
    static func scope(_ id: String, _ name: String, volumes: [String]) -> [String: SQLiteValue] {
        ["id": .text(id), "name": .text(name), "volume_ids": .text(TagReferences.encode(volumes)),
         "created_at": .text(UserStoreDate.text(created)), "last_modified": .text(UserStoreDate.text(created))]
    }

    @Test(arguments: UserStoreKind.available)
    func eachUsersRowsAreTheirsAloneInTheOrderTheStoreTookThem(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        _ = try store.signedInUser("reader", at: Self.created)
        try store.addSearchSet(.volumeScopes, Self.scope(Self.second, "Berlin", volumes: ["frus1961-63v14"]), for: "owner")
        try store.addSearchSet(.volumeScopes, Self.scope(Self.first, "Cuba", volumes: ["frus1961-63v10", "frus1961-63v11"]), for: "owner")
        // Another user may hold a row under the same id, as two imports of one Mac export give them.
        try store.addSearchSet(.volumeScopes, Self.scope(Self.first, "Theirs", volumes: []), for: "reader")

        let rows = try store.searchSets(.volumeScopes, of: "owner")
        #expect(rows.map { $0.values["name"] } == [.text("Berlin"), .text("Cuba")], "in the order the store took them")
        #expect(rows[0].position < rows[1].position)
        #expect(try store.searchSets(.volumeScopes, of: "reader").map { $0.values["name"] } == [.text("Theirs")])
        #expect(try store.searchSets(.volumeScopes, of: "nobody").isEmpty)
        #expect(try store.searchSets(.savedSearches, of: "owner").isEmpty, "each table its own")

        let found = try #require(try store.searchSet(.volumeScopes, id: Self.first.lowercased(), of: "owner"))
        #expect(found.values["id"] == .text(Self.first), "found in any letter case, kept as it was written")
        #expect(found.values["volume_ids"] == .text(#"["frus1961-63v10","frus1961-63v11"]"#))
        #expect(try store.searchSet(.volumeScopes, id: Self.first, of: "reader")?.values["name"] == .text("Theirs"))
        #expect(try store.searchSet(.volumeScopes, id: "not an id", of: "owner") == nil)
    }

    /// Every kind of value a column keeps comes back as it was written, and a column a row leaves out
    /// is NULL, as an import leaves one.
    @Test(arguments: UserStoreKind.available)
    func aRowKeepsItsColumnsAsTheyWereWritten(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let values: [String: SQLiteValue] = [
            "id": .text(Self.first), "name": .text("Long telegram"), "document_keys": .text(#"["frus1946v06/d475"]"#),
            "captured_at": .text(UserStoreDate.text(Self.created)), "source_query": .text("long telegram"),
            "indexed_volume_count_at_capture": .integer(3), "was_truncated_at_capture": .integer(0),
        ]
        try store.addSearchSet(.workingCorpora, values, for: "owner")
        let row = try #require(try store.searchSet(.workingCorpora, id: Self.first, of: "owner"))
        for (column, value) in values { #expect(row.values[column] == value, "\(column)") }
        for column in ["source_description", "total_match_count_at_capture", "created_at", "last_modified"] {
            #expect(row.values[column] == .null, "\(column) left out is NULL")
        }
        #expect(Set(row.values.keys) == Set(SearchSetTable.workingCorpora.table.columns.map(\.name)))
    }

    /// An update sets the columns it names and no other, never the id, and answers the row as it
    /// then stands; one for a row the user does not hold writes nothing.
    @Test(arguments: UserStoreKind.available)
    func anUpdateSetsTheColumnsItNamesAlone(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        _ = try store.signedInUser("reader", at: Self.created)
        try store.addSearchSet(.volumeScopes, Self.scope(Self.first, "Cuba", volumes: ["frus1961-63v10"]), for: "owner")
        try store.addSearchSet(.volumeScopes, Self.scope(Self.first, "Theirs", volumes: []), for: "reader")
        let mark = try store.searchMark()

        let updated = try #require(try store.updateSearchSet(
            .volumeScopes, id: Self.first.lowercased(), ["name": .text("Cuba, 1961–63"), "id": .text(Self.second)], for: "owner"))
        #expect(updated.values["name"] == .text("Cuba, 1961–63"))
        #expect(updated.values["id"] == .text(Self.first), "never the id")
        #expect(updated.values["volume_ids"] == .text(#"["frus1961-63v10"]"#), "and no other column")
        #expect(try store.searchMark() > mark, "a write the store commits")
        #expect(try store.searchSet(.volumeScopes, id: Self.first, of: "reader")?.values["name"] == .text("Theirs"),
                "another user's row of the same id is theirs")

        #expect(try store.updateSearchSet(.volumeScopes, id: Self.second, ["name": .text("None")], for: "owner") == nil)
        #expect(try store.updateSearchSet(.volumeScopes, id: Self.first, [:], for: "owner") == updated, "nothing to set")
        #expect(try store.searchSets(.volumeScopes, of: "owner") == [updated])
    }

    @Test(arguments: UserStoreKind.available)
    func aDeleteRemovesTheUsersRowAlone(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        _ = try store.signedInUser("reader", at: Self.created)
        try store.addSearchSet(.volumeScopes, Self.scope(Self.first, "Cuba", volumes: []), for: "owner")
        try store.addSearchSet(.volumeScopes, Self.scope(Self.second, "Berlin", volumes: []), for: "owner")
        try store.addSearchSet(.volumeScopes, Self.scope(Self.first, "Theirs", volumes: []), for: "reader")

        #expect(try store.deleteSearchSet(.volumeScopes, id: Self.first.lowercased(), for: "owner"))
        #expect(try store.deleteSearchSet(.volumeScopes, id: Self.first, for: "owner") == false, "gone")
        #expect(try store.searchSets(.volumeScopes, of: "owner").map { $0.values["name"] } == [.text("Berlin")])
        #expect(try store.searchSets(.volumeScopes, of: "reader").map { $0.values["name"] } == [.text("Theirs")])
    }

    /// A column the table lacks, a row with no id, and an id the user's rows hold already, in any
    /// letter case, are refused, and nothing is written.
    @Test(arguments: UserStoreKind.available)
    func aRowThatDoesNotFitIsRefused(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try store.addSearchSet(.savedSearches, Self.savedSearch(Self.first, "Kept"), for: "owner")
        var unknown = Self.scope(Self.second, "Scope", volumes: [])
        unknown["document_keys"] = .text("[]")
        #expect(throws: SearchSetStoreError.unknownColumn(table: "volume_scopes", column: "document_keys")) {
            try store.addSearchSet(.volumeScopes, unknown, for: "owner")
        }
        #expect(throws: SearchSetStoreError.unknownColumn(table: "saved_searches", column: "volume_ids")) {
            try store.updateSearchSet(.savedSearches, id: Self.first, ["volume_ids": .text("[]")], for: "owner")
        }
        var unnamed = Self.savedSearch(Self.second, "No id")
        unnamed["id"] = nil
        #expect(throws: SearchSetStoreError.invalidId(table: "saved_searches", id: nil)) {
            try store.addSearchSet(.savedSearches, unnamed, for: "owner")
        }
        #expect(throws: SearchSetStoreError.invalidId(table: "saved_searches", id: Self.first.lowercased())) {
            try store.addSearchSet(.savedSearches, Self.savedSearch(Self.first.lowercased(), "Again"), for: "owner")
        }
        #expect(try store.searchSets(.savedSearches, of: "owner").map { $0.values["name"] } == [.text("Kept")])
        #expect(try store.searchSets(.volumeScopes, of: "owner").isEmpty)
    }

    /// A saved search's row with each column the table requires, as `SavedSearch.init(name:parameters:)`
    /// writes them for an empty search.
    static func savedSearch(_ id: String, _ name: String) -> [String: SQLiteValue] {
        ["id": .text(id), "name": .text(name), "query_text": .text(""), "phrase_text": .text(""), "prefix_wildcard": .text(""),
         "boolean_mode_raw": .text("and"), "excluded_terms_csv": .text(""), "scope_flags": .integer(7),
         "subject_tag_ids_csv": .text(""), "document_type_filter_raw": .text("all"), "person_ref": .text(""),
         "sort_order": .text("relevance")]
    }
}
