// The export's store half (S16d): the rows of the tables an export names, a user table's of the
// user's and an instance table's every row, each table's in the order the store took them, which a
// newer copy's replace keeps; of the prompts, the researcher's own only; and the counts of the same
// rows, for the browser app's Contents.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserResearchExportTests {
    static func id(_ number: Int) -> String { String(format: "5E16D000-0000-4000-8000-%012X", number) }

    @Test(arguments: UserStoreKind.available) func theRowsOfTheTablesNamedAreTheUsersInTheOrderTheStoreTookThem(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        // Ids that sort against the order the rows came in.
        _ = try store.importResearch(ResearchImportBatch(rows: ["tags": [
            UserResearchImportTests.tag(Self.id(3), name: "Came first", modified: "2026-02-01T00:00:00.000Z"),
            UserResearchImportTests.tag(Self.id(1), name: "Came second", modified: nil),
        ]]), for: "owner")
        _ = try store.importResearch(ResearchImportBatch(rows: ["tags": [
            UserResearchImportTests.tag(Self.id(2), name: "The reader's", modified: nil),
        ]]), for: "reader")
        // A newer copy replaces the row where it stands.
        _ = try store.importResearch(ResearchImportBatch(rows: ["tags": [
            UserResearchImportTests.tag(Self.id(3), name: "Came first, renamed", modified: "2026-03-01T00:00:00.000Z"),
        ]]), for: "owner")

        let read = try store.researchRows(for: "owner", tables: ["tags", "notes", "users", "no_such_table"])
        #expect(Set(read.rows.keys) == ["tags", "notes"], "the research tables named, and nothing else")
        #expect(read["tags"].map { $0.values["name"]?.text } == ["Came first, renamed", "Came second"])
        #expect(read["tags"].map(\.position) == read["tags"].map(\.position).sorted())
        let columns = try #require(UserStoreSchema.table(for: "UserTag")).columns.map(\.name)
        #expect(read["tags"].allSatisfy { Set($0.values.keys) == Set(columns) }, "every column the model has, and no user_id")
        #expect(read["notes"].isEmpty && read["prompts"].isEmpty)
        #expect(try store.researchRows(for: "reader", tables: ["tags"])["tags"].map { $0.values["id"]?.text } == [Self.id(2)])
        #expect(try store.researchCounts(for: "owner", tables: ["tags", "notes"]) == ["tags": 2, "notes": 0])
        #expect(try store.researchCounts(for: "reader", tables: ["tags"]) == ["tags": 1])
    }

    /// An instance-wide table's rows are every user's to read, when named; the prompts are the
    /// researcher's own, never a standard one, which no path here writes but the export would leave
    /// out, as the app's does.
    @Test(arguments: UserStoreKind.available) func anInstanceTablesRowsAndOnlyTheResearchersOwnPrompts(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        _ = try store.importResearch(ResearchImportBatch(rows: ["classification_overrides": [ImportRow(values: [
            "id": .text(Self.id(150)), "volume_id": .text("frus1961-63v06"), "document_id": .text("d4"),
            "is_editorial_note": .integer(1), "parsed_is_editorial_note": .integer(0),
            "created_at": .text("2026-06-11T00:00:00.000Z"),
        ])]]), for: "owner")
        try rows.addPrompt(Self.id(80), name: "Cold War brief")
        try rows.run("""
            INSERT INTO prompts (user_id, id, name, prompt_text, response_format, is_standard, created_at, last_modified)
                VALUES ('owner', ?, 'Brief', 'Summarize {{DOCUMENT}}', '{"general":{}}', 1, NULL, NULL)
            """, [.text(Self.id(81))])

        let tables: Set<String> = ["classification_overrides", "prompts"]
        for user in ["owner", "reader"] {
            let read = try store.researchRows(for: user, tables: tables)
            #expect(read["classification_overrides"].map { $0.values["id"]?.text } == [Self.id(150)], "\(user)")
        }
        #expect(try store.researchRows(for: "owner", tables: tables)["prompts"].map { $0.values["id"]?.text } == [Self.id(80)])
        #expect(try store.researchCounts(for: "owner", tables: tables) == ["classification_overrides": 1, "prompts": 1])
        #expect(try store.researchRows(for: "owner", tables: ["prompts"]).rows.keys.sorted() == ["prompts"])
    }
}
