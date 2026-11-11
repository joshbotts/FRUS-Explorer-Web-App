// Suggested Next's leads kept as the app's `ProjectLeadsService` keeps them (PLAN's S23d), on each
// store: a lead still ranked keeps its row and its first surfacing, and takes the new score, seeds and
// record unless it was dismissed, a dismissed lead keeping what it showed; a new lead is added; a lead no
// longer ranked is removed, dismissed or not; a project with nothing to rank from loses its leads but its
// dismissed ones; and a project gone, or another user's, is written to not at all.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserLeadsTests {
    static let grain = "5E23D000-0000-4000-8000-000000000001"
    static let other = "5E23D000-0000-4000-8000-000000000002"
    static let first = "2026-01-01T00:00:00.000Z"
    static let now = Date(timeIntervalSince1970: 1_794_000_000)

    static func lead(_ id: String, _ document: String, project: String = grain, user: String = "owner", dismissed: Bool = false,
                     _ rows: UserStoreRows) throws {
        try rows.run(
            """
            INSERT INTO project_leads (user_id, id, project_id, volume_id, document_id, aggregate_score, contributing_seed_keys, header,
                                       document_number, is_editorial_note, first_surfaced_at, last_computed_at, dismissed)
                VALUES (?, ?, ?, 'frus1961-63v06', ?, 1.5, '["frus1961-63v06/d1"]', 'Old head', '7', 0, ?, ?, ?)
            """, [.text(user), .text(id), .text(project), .text(document), .text(first), .text(first), .integer(dismissed ? 1 : 0)])
    }

    /// A score as either store gives it back.
    static func real(_ value: SQLiteValue?) -> Double? {
        switch value {
        case .real(let number): number
        case .integer(let number): Double(number)
        case .text(let text): Double(text)
        default: nil
        }
    }

    static func write(_ document: String, score: Double, seeds: [String], header: String? = nil) -> ProjectLeadWrite {
        ProjectLeadWrite(volumeId: "frus1961-63v06", documentId: document, aggregateScore: score, contributingSeedKeys: seeds,
                         record: header.map { .init(header: $0, documentNumber: "12", isEditorialNote: true) })
    }

    @Test(arguments: UserStoreKind.available) func leadsAreKeptAsTheAppKeepsThem(_ kind: UserStoreKind) async throws {
        let test = try await TestUserStore.open(kind)
        let (store, rows) = (test.store, test.rows)
        try rows.addUser("reader")
        try rows.addProject(Self.grain)
        try rows.addProject(Self.other)
        try rows.addProject(Self.grain, user: "reader")
        try Self.lead("L-KEPT", "d2", rows)
        try Self.lead("L-DISMISSED", "d3", dismissed: true, rows)
        try Self.lead("L-GONE", "d4", rows)
        try Self.lead("L-GONE-DISMISSED", "d5", dismissed: true, rows)
        try Self.lead("L-OTHER-PROJECT", "d4", project: Self.other, rows)
        try Self.lead("L-THEIRS", "d4", user: "reader", rows)

        // The project's id in lower case, as a browser may send it, names the same project.
        let kept = try store.applyProjectLeads([
            Self.write("d2", score: 2.5, seeds: ["frus1961-63v06/d1", "frus1961-63v06/d9"], header: "New head"),
            Self.write("d3", score: 9, seeds: ["frus1961-63v06/d1"], header: "Not shown"),
            Self.write("d6", score: 1.25, seeds: ["frus1961-63v06/d9"], header: "A new lead"),
            Self.write("d7", score: 0.5, seeds: ["frus1961-63v06/d9"]),
        ], toProject: Self.grain.lowercased(), for: "owner", at: Self.now)
        #expect(kept)
        let time = UserStoreDate.text(UserStoreDate.rounded(Self.now))
        let leads = try rows.rows(of: "project_leads").filter { $0["project_id"]?.text == Self.grain }
        let byDocument = Dictionary(uniqueKeysWithValues: leads.map { ($0["document_id"]?.text ?? "", $0) })
        #expect(Set(byDocument.keys) == ["d2", "d3", "d6", "d7"], "the leads no longer ranked are gone, dismissed or not")
        let d2 = try #require(byDocument["d2"])
        #expect(d2["id"]?.text == "L-KEPT" && d2["first_surfaced_at"]?.text == Self.first && d2["last_computed_at"]?.text == time)
        #expect(Self.real(d2["aggregate_score"]) == 2.5 && d2["header"]?.text == "New head" && d2["document_number"]?.text == "12")
        #expect(d2["is_editorial_note"]?.integer == 1 && d2["dismissed"]?.integer == 0)
        #expect(d2["contributing_seed_keys"]?.text == TagReferences.encode(["frus1961-63v06/d1", "frus1961-63v06/d9"]))
        // A dismissed lead stays dismissed and keeps what it showed.
        let d3 = try #require(byDocument["d3"])
        #expect(d3["dismissed"]?.integer == 1 && d3["header"]?.text == "Old head" && Self.real(d3["aggregate_score"]) == 1.5)
        #expect(d3["last_computed_at"]?.text == time)
        let d6 = try #require(byDocument["d6"])
        #expect(d6["first_surfaced_at"]?.text == time && d6["header"]?.text == "A new lead" && d6["dismissed"]?.integer == 0)
        #expect(d6["project_id"]?.text == Self.grain, "under the project's id as the store holds it")
        let d7 = try #require(byDocument["d7"])
        #expect(d7["header"]?.text == "" && d7["document_number"] == .null && d7["is_editorial_note"]?.integer == 0)
        // Another project's and another user's leads are untouched.
        #expect(try rows.rows(of: "project_leads").contains { $0["id"]?.text == "L-OTHER-PROJECT" })
        #expect(try rows.rows(of: "project_leads", user: "reader").map { $0["id"]?.text } == ["L-THEIRS"])

        // Nothing to rank from: the leads on show go, the dismissed one stays.
        #expect(try store.clearVisibleProjectLeads(ofProject: Self.grain, for: "owner"))
        #expect(try rows.rows(of: "project_leads").filter { $0["project_id"]?.text == Self.grain }.map { $0["document_id"]?.text } == ["d3"])
        #expect(try rows.rows(of: "project_leads").contains { $0["id"]?.text == "L-OTHER-PROJECT" })

        // A project the user does not have is written to not at all.
        let missing = "5E23D000-0000-4000-8000-0000000000FF"
        #expect(try !store.applyProjectLeads([Self.write("d9", score: 1, seeds: [])], toProject: missing, for: "owner", at: Self.now))
        #expect(try !store.clearVisibleProjectLeads(ofProject: Self.other, for: "reader"))
        #expect(try rows.rows(of: "project_leads", user: "reader").map { $0["id"]?.text } == ["L-THEIRS"])
        #expect(try !rows.rows(of: "project_leads").contains { $0["document_id"]?.text == "d9" })
        withExtendedLifetime(test) {}
    }

    /// Two leads an import brought for one document: the first the store took is the one kept up to date,
    /// as the app's dictionary by key keeps the first, and the second stays as it was.
    @Test(arguments: UserStoreKind.available) func ofTwoLeadsForOneDocumentTheFirstIsKept(_ kind: UserStoreKind) async throws {
        let test = try await TestUserStore.open(kind)
        let (store, rows) = (test.store, test.rows)
        try rows.addProject(Self.grain)
        try Self.lead("L-FIRST", "d2", rows)
        try Self.lead("L-SECOND", "d2", rows)
        #expect(try store.applyProjectLeads([Self.write("d2", score: 4, seeds: ["frus1961-63v06/d1"], header: "Head")],
                                            toProject: Self.grain, for: "owner", at: Self.now))
        let leads = try rows.rows(of: "project_leads")
        #expect(leads.map { $0["id"]?.text } == ["L-FIRST", "L-SECOND"])
        #expect(leads.map { Self.real($0["aggregate_score"]) } == [4, 1.5])
        withExtendedLifetime(test) {}
    }
}
