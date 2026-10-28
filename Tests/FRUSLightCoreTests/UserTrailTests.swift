// Projects, the research trail and the synced preferences in the user store (S17f), on every store the
// conformance suite runs on: the project each user works in, which a delete returns to Global Context
// and a merge moves; a merge's re-pointing of what is filed under a project, as the app's
// `ProjectAdminService.merge` re-points it; the trail's pages, newest first in a project's scope, and
// its delete; and the one row of preferences each user has once something sets it. None of it moves
// the search mark, which the conformance suite holds.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserTrailTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z
    static let grain = "5E17F000-0000-4000-8000-000000000001"
    static let berlin = "5E17F000-0000-4000-8000-000000000002"
    static let stranger = "5E17F000-0000-4000-8000-0000000000FF"

    static func table(_ model: String) throws -> UserStoreSchema.Table { try #require(UserStoreSchema.table(for: model)) }

    /// A trail row's columns, as the API writes a visit.
    static func visit(_ id: String, at time: String?, project: String?, document: String = "d1") -> [String: SQLiteValue] {
        ["id": .text(id), "document_id": .text(document), "volume_id": .text("frus1961-63v06"), "display_title": .null,
         "project_id": project.map { .text($0) } ?? .null, "accessed_at": time.map { .text($0) } ?? .null]
    }

    static func entry(_ n: Int) -> String { String(format: "5E17F000-0000-4000-8000-%012d", 100 + n) }

    /// The columns of a new row of preferences beside its times, as the API gives them.
    static let initialPreferences: [String: SQLiteValue] = [
        "wc_min_length": .integer(3), "wc_min_count": .integer(1), "wc_fold_plurals": .integer(1), "wc_filter_markings": .integer(1),
        "wc_exclude_boilerplate": .integer(1), "wc_global_stopwords_json": .text(""), "wc_lens_stopwords_json": .text(""),
        "citation_style_raw": .text(""), "default_document_mode_raw": .text(""), "research_logging_enabled": .integer(1),
        "list_order_json": .text(""),
    ]

    /// The user works in one project, or in none: chosen by its id in any case and kept as it is held,
    /// refused for an id they hold no project for, and none once it is deleted, by them or under them.
    @Test(arguments: UserStoreKind.available)
    func theProjectAUserWorksInIsTheirsAndGoesWithIt(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try rows.addProject(Self.grain, name: "Grain")
        try rows.addProject(Self.berlin, name: "Berlin")
        try rows.addUser("reader")
        try rows.addProject(Self.stranger, user: "reader", name: "Theirs")
        #expect(try store.activeProjectId(of: "owner") == nil, "Global Context to begin with")

        try store.setActiveProject(Self.grain.lowercased(), for: "owner")
        #expect(try store.activeProjectId(of: "owner") == Self.grain, "as the project holds its id")
        #expect(try store.activeProjectId(of: "reader") == nil, "each user's own")
        #expect(throws: ProjectStoreError.projectNotFound(Self.stranger)) { try store.setActiveProject(Self.stranger, for: "owner") }
        #expect(try store.activeProjectId(of: "owner") == Self.grain, "a refusal changes nothing")

        // Another project deleted leaves it; deleting it returns the user to Global Context.
        #expect(try store.deleteProject(Self.berlin, for: "owner"))
        #expect(try store.activeProjectId(of: "owner") == Self.grain)
        #expect(try store.deleteProject(Self.grain.lowercased(), for: "owner"))
        #expect(try store.activeProjectId(of: "owner") == nil)
        #expect(try !store.deleteProject(Self.grain, for: "owner"), "gone")
        #expect(try !store.deleteProject(Self.stranger, for: "owner"), "not theirs")
        #expect(try rows.column("SELECT name FROM projects WHERE user_id = 'reader'") == ["Theirs"])

        // One that goes some other way, as an import cannot but a restore could, reads as none too.
        try rows.addProject(Self.berlin, name: "Berlin")
        try store.setActiveProject(Self.berlin, for: "owner")
        try store.setActiveProject(nil, for: "owner")
        #expect(try store.activeProjectId(of: "owner") == nil, "chosen, and Global Context chosen again")
    }

    /// A merge files under the target what was filed under the source, re-points the summaries and the
    /// trail stamped with it and the project the user works in, deletes the source, and leaves its leads
    /// and everything of another project, or user, as it was.
    @Test(arguments: UserStoreKind.available)
    func aMergeRepointsWhatTheAppsMergeRepoints(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try rows.addProject(Self.grain, name: "Grain")
        try rows.addProject(Self.berlin, name: "Berlin")
        let third = "5E17F000-0000-4000-8000-000000000003"
        try rows.addProject(third, name: "Third")
        try rows.addNote("5E17F000-0000-4000-8000-0000000000A1", projectIds: [Self.grain.lowercased()])
        try rows.addNote("5E17F000-0000-4000-8000-0000000000A2", projectIds: [Self.berlin, Self.grain])
        try rows.addNote("5E17F000-0000-4000-8000-0000000000A3", projectIds: [third])
        try rows.addSummary("5E17F000-0000-4000-8000-0000000000B1", projectId: Self.grain)
        try rows.run(
            """
            INSERT INTO visit_plans (user_id, id, name, project_ids, created_at, last_modified)
                VALUES ('owner', '5E17F000-0000-4000-8000-0000000000C1', 'Archives', ?, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z')
            """, [.text(TagReferences.encode([Self.grain, third, Self.berlin]))])
        try rows.run(
            """
            INSERT INTO project_leads (user_id, id, project_id, volume_id, document_id, aggregate_score, contributing_seed_keys, header,
                                       is_editorial_note, first_surfaced_at, last_computed_at, dismissed)
                VALUES ('owner', '5E17F000-0000-4000-8000-0000000000D1', ?, 'frus1961-63v06', 'd9', 1.5, '[]', 'A lead', 0,
                        '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z', 0)
            """, [.text(Self.grain)])
        let reading = try Self.table("ReadingHistoryEntry")
        try store.addResearchRow(reading, Self.visit(Self.entry(1), at: "2026-01-02T00:00:00.000Z", project: Self.grain),
                                 for: "owner", outsideSearch: true)
        try store.addResearchRow(reading, Self.visit(Self.entry(2), at: "2026-01-03T00:00:00.000Z", project: third),
                                 for: "owner", outsideSearch: true)
        try store.setActiveProject(Self.grain, for: "owner")

        try store.mergeProject(Self.grain, into: Self.berlin.lowercased(), for: "owner", at: Self.created)
        let stamp = UserStoreDate.text(Self.created)
        #expect(try rows.column("SELECT name FROM projects WHERE user_id = 'owner' ORDER BY name") == ["Berlin", "Third"])
        #expect(try store.activeProjectId(of: "owner") == Self.berlin, "the user follows the merge")
        let notes = try rows.stored("SELECT id, project_ids, last_modified FROM notes ORDER BY id")
        #expect(notes.map { $0[1] } == [.text(TagReferences.encode([Self.berlin])), .text(TagReferences.encode([Self.berlin])),
                                        .text(TagReferences.encode([third]))],
                "the source gone, the target after the rest unless it is there")
        #expect(notes.map { $0[2] } == [.text(stamp), .text(stamp), .text("2026-01-01T00:00:00.000Z")], "the two changed are stamped")
        #expect(try rows.column("SELECT project_ids FROM visit_plans") == [TagReferences.encode([Self.berlin, third])],
                "a plan's list re-pointed where it stands, each id once")
        #expect(try rows.column("SELECT project_id FROM summaries") == [Self.berlin])
        #expect(try rows.column("SELECT project_id FROM trail_reading ORDER BY accessed_at") == [Self.berlin, third])
        #expect(try rows.column("SELECT project_id FROM project_leads") == [Self.grain], "a lead keeps its project, as the app's merge leaves it")

        #expect(throws: ProjectStoreError.mergeIntoItself) { try store.mergeProject(Self.berlin, into: Self.berlin, for: "owner", at: Self.created) }
        #expect(throws: ProjectStoreError.projectNotFound(Self.grain)) { try store.mergeProject(Self.grain, into: third, for: "owner", at: Self.created) }
        #expect(throws: ProjectStoreError.projectNotFound(Self.stranger)) { try store.mergeProject(third, into: Self.stranger, for: "owner", at: Self.created) }
    }

    /// A page is the scope's rows, newest first, one with no time last and two of one time the later
    /// written first, cut at its limit, with the scope's total; each user's alone.
    @Test(arguments: UserStoreKind.available)
    func aTrailPageIsNewestFirstInItsScope(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try rows.addUser("reader")
        let reading = try Self.table("ReadingHistoryEntry")
        let added: [(Int, String?, String?)] = [
            (1, "2026-01-02T00:00:00.000Z", Self.grain), (2, nil, nil), (3, "2026-01-05T00:00:00.000Z", nil),
            (4, "2026-01-02T00:00:00.000Z", Self.grain.lowercased()), (5, "2026-01-04T00:00:00.000Z", Self.berlin),
        ]
        for (n, time, project) in added {
            try store.addResearchRow(reading, Self.visit(Self.entry(n), at: time, project: project), for: "owner", outsideSearch: true)
        }
        try store.addResearchRow(reading, Self.visit(Self.entry(9), at: "2026-01-09T00:00:00.000Z", project: nil), for: "reader",
                                 outsideSearch: true)
        func ids(_ page: TrailPage) -> [String] { page.rows.map { $0.values["id"]?.text ?? "" } }

        let all = try store.trailPage(.reading, of: "owner", scope: .all, limit: 500)
        #expect(ids(all) == [3, 5, 4, 1, 2].map(Self.entry), "newest first, the tie the later written first, none last")
        #expect(all.total == 5)
        let cut = try store.trailPage(.reading, of: "owner", scope: .all, limit: 2)
        #expect(ids(cut) == [3, 5].map(Self.entry) && cut.total == 5, "the page is cut, the total is not")
        let grain = try store.trailPage(.reading, of: "owner", scope: .project(Self.grain.lowercased()), limit: 500)
        #expect(ids(grain) == [4, 1].map(Self.entry) && grain.total == 2, "the project's in any case")
        let unfiled = try store.trailPage(.reading, of: "owner", scope: .unfiled, limit: 500)
        #expect(ids(unfiled) == [3, 2].map(Self.entry) && unfiled.total == 2)
        #expect(try store.trailPage(.searches, of: "owner", scope: .all, limit: 500).total == 0, "each table its own")
        #expect(try store.datedTrailCount(of: "owner") == 4, "the row with no time is not dated")

        let deleted = try store.deleteTrail(of: "owner")
        #expect(deleted == [.reading: 5, .searches: 0, .exports: 0])
        #expect(try store.trailPage(.reading, of: "owner", scope: .all, limit: 500).total == 0)
        #expect(try store.trailPage(.reading, of: "reader", scope: .all, limit: 500).total == 1, "another user's stays")
    }

    /// A user has no preferences until something sets them; the first change makes the row, with the
    /// initial values for the rest, and a later one changes what it names and when the row changed.
    @Test(arguments: UserStoreKind.available)
    func preferencesAreMadeOnceAndChangedByField(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        #expect(try store.preferences(of: "owner") == nil)
        let initial = Self.initialPreferences
        let first = try store.setPreferences(["citation_style_raw": .text("chicago")], initial: initial, for: "owner", at: Self.created)
        #expect(first.values["citation_style_raw"] == .text("chicago") && first.values["wc_min_length"] == .integer(3))
        #expect(first.values["created_at"] == .text(UserStoreDate.text(Self.created)) && first.values["updated_at"] == first.values["created_at"])
        let later = Self.created.addingTimeInterval(60)
        let second = try store.setPreferences(["research_logging_enabled": .integer(0)], initial: initial, for: "owner", at: later)
        #expect(second.values["citation_style_raw"] == .text("chicago"), "kept")
        #expect(second.values["research_logging_enabled"] == .integer(0))
        #expect(second.values["created_at"] == first.values["created_at"] && second.values["updated_at"] == .text(UserStoreDate.text(later)))
        #expect(try store.preferences(of: "owner") == second)
        #expect(throws: ResearchRowStoreError.unknownColumn(table: "preferences", column: "theme")) {
            try store.setPreferences(["theme": .text("dark")], initial: initial, for: "owner", at: later)
        }
        _ = try store.signedInUser("reader", at: Self.created)
        #expect(try store.preferences(of: "reader") == nil, "each user's own")
    }
}
