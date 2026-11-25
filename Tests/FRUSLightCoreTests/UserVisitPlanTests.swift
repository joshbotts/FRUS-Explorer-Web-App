// A user's Archives Visit plans (PLAN's S30c), on every store `UserStoreKind.available` names: a plan read with the seeds
// and targets that name it, in any letter case; made with them in one write; changed in one write that writes only the
// columns that differ, adds what is new and deletes what is left out, or nothing when the change throws; deleted with
// every row that names it; refused for a column a table lacks or an id the user holds; and two users' plans apart, each
// free to hold one under the same id.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserVisitPlanTests {
    static let planId = "5E30C000-0000-4000-8000-000000000001"

    static func plan(_ id: String = planId, name: String = "College Park") -> [String: SQLiteValue] {
        ["id": .text(id), "name": .text(name), "inquiry_text": .text("The letters"), "project_ids": .text("[]"),
         "tiers_data": .text(#"[{"id":"5E30C000-0000-4000-8000-0000000000A1","order":0}]"#), "created_at": .text("2026-11-01T00:00:00.000Z"),
         "last_modified": .text("2026-11-01T00:00:00.000Z")]
    }

    static func seed(_ id: String, _ key: String, source: Bool = true) -> [String: SQLiteValue] {
        ["id": .text(id), "plan_id": .text(planId), "document_key": .text(key), "include_source": .integer(source ? 1 : 0),
         "include_external_refs": .integer(1), "created_at": .text("2026-11-01T00:00:00.000Z"), "last_modified": .text("2026-11-01T00:00:00.000Z")]
    }

    static func target(_ id: String, _ key: String, note: String? = nil) -> [String: SQLiteValue] {
        ["id": .text(id), "plan_id": .text(planId), "target_key": .text(key), "included": .integer(1),
         "user_note": note.map(SQLiteValue.text) ?? .null, "created_at": .text("2026-11-01T00:00:00.000Z"),
         "last_modified": .text("2026-11-01T00:00:00.000Z")]
    }

    static let seedA = "5E30C000-0000-4000-8000-0000000000D1"
    static let seedB = "5E30C000-0000-4000-8000-0000000000D2"
    static let targetA = "5E30C000-0000-4000-8000-0000000000E1"
    static let targetB = "5E30C000-0000-4000-8000-0000000000E2"

    static func change(plan: [String: SQLiteValue] = plan(), documents: [[String: SQLiteValue]]? = nil,
                       targets: [[String: SQLiteValue]]? = nil) -> VisitPlanChange {
        VisitPlanChange(plan: plan, documents: documents ?? [seed(seedA, "frus1961-63v06/d1"), seed(seedB, "frus1961-63v06/d2")],
                        targets: targets ?? [target(targetA, "lot|66D204", note: "Box 4")])
    }

    static func keys(_ rows: [ExportRow], _ column: String) -> [String] { rows.compactMap { $0.values[column]?.text } }

    /// A plan is made with its seeds and targets, each naming it, and read with them, in the store's order, by its id in
    /// any letter case; every plan, seed and target of the user's listed.
    @Test(arguments: UserStoreKind.available)
    func aPlanIsKeptWithItsSeedsAndTargets(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let made = try store.addVisitPlan(Self.change(), for: "owner")
        #expect(Self.keys([made.plan], "name") == ["College Park"])
        #expect(Self.keys(made.documents, "document_key") == ["frus1961-63v06/d1", "frus1961-63v06/d2"])
        #expect(Self.keys(made.targets, "user_note") == ["Box 4"])
        #expect(Self.keys(made.documents + made.targets, "plan_id") == Array(repeating: Self.planId, count: 3))
        let read = try #require(try store.visitPlanRows(Self.planId.lowercased(), of: "owner"))
        #expect(read == made)
        let all = try store.visitPlanRows(of: "owner")
        #expect(all.plans.count == 1 && all.documents.count == 2 && all.targets.count == 1)
        #expect(try store.visitPlanRows(UUID().uuidString, of: "owner") == nil)
    }

    /// A change writes what differs: a column of the plan, a seed's switch, a target added and one left out; a seed it
    /// keeps whole is not written. Nothing for a nil change, and nothing when the change throws.
    @Test(arguments: UserStoreKind.available)
    func aChangeWritesWhatDiffersInOneWrite(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try store.addVisitPlan(Self.change(), for: "owner")
        let changed = try #require(try store.changeVisitPlan(Self.planId, for: "owner") { held in
            #expect(held.documents.count == 2)
            return VisitPlanChange(plan: ["id": .text(Self.planId), "name": .text("Berlin")],
                                   documents: [["id": .text(Self.seedA.lowercased())], ["id": .text(Self.seedB), "include_source": .integer(0)]],
                                   targets: [Self.target(Self.targetB, "r|A note")])
        })
        #expect(Self.keys([changed.plan], "name") == ["Berlin"] && Self.keys([changed.plan], "inquiry_text") == ["The letters"])
        #expect(changed.documents.map { $0.values["include_source"]?.integer } == [1, 0])
        #expect(Self.keys(changed.targets, "target_key") == ["r|A note"], "the target left out is gone, the new one names the plan")
        #expect(Self.keys(changed.targets, "plan_id") == [Self.planId])

        // Nothing written for a change of nothing, and nothing for one that throws.
        #expect(try store.changeVisitPlan(Self.planId, for: "owner") { _ in nil } == changed)
        struct Refused: Error {}
        #expect(throws: Refused.self) {
            try store.changeVisitPlan(Self.planId, for: "owner") { _ in
                _ = VisitPlanChange(plan: [:], documents: [], targets: [])
                throw Refused()
            }
        }
        #expect(throws: ResearchRowStoreError.unknownColumn(table: "visit_documents", column: "colour")) {
            try store.changeVisitPlan(Self.planId, for: "owner") { _ in
                VisitPlanChange(plan: ["id": .text(Self.planId), "name": .text("Gone")], documents: [["id": .text(Self.seedA), "colour": .text("red")]],
                                targets: [])
            }
        }
        #expect(try store.visitPlanRows(Self.planId, of: "owner") == changed, "a refused change wrote nothing")
        #expect(try store.changeVisitPlan(UUID().uuidString, for: "owner") { _ in nil } == nil)
        #expect(try rows.rows(of: "visit_documents").count == 2)
    }

    /// A plan deleted takes every seed and target that names it, in any letter case, and no other plan's.
    @Test(arguments: UserStoreKind.available)
    func aPlanDeletedTakesEveryRowThatNamesIt(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try store.addVisitPlan(Self.change(), for: "owner")
        let other = "5E30C000-0000-4000-8000-000000000002"
        try store.addVisitPlan(VisitPlanChange(plan: Self.plan(other, name: "Abilene"),
                                               documents: [Self.seed("5E30C000-0000-4000-8000-0000000000D3", "frus1894Nicaragua/d1")],
                                               targets: []), for: "owner")
        try rows.run("INSERT INTO visit_targets (user_id, id, plan_id, target_key, included) VALUES ('owner', ?, ?, 'r|Lower', 1)",
                     [.text(UUID().uuidString), .text(Self.planId.lowercased())])
        #expect(try store.deleteVisitPlan(Self.planId.lowercased(), for: "owner"))
        let left = try store.visitPlanRows(of: "owner")
        #expect(Self.keys(left.plans, "name") == ["Abilene"] && Self.keys(left.documents, "document_key") == ["frus1894Nicaragua/d1"])
        #expect(left.targets.isEmpty)
        #expect(try !store.deleteVisitPlan(Self.planId, for: "owner"))
    }

    /// A plan, a seed or a target under an id the user already holds is refused, writing nothing, as is a column a table
    /// lacks.
    @Test(arguments: UserStoreKind.available)
    func anIdHeldOrAColumnUnknownIsRefused(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try store.addVisitPlan(Self.change(), for: "owner")
        #expect(throws: ResearchRowStoreError.invalidId(table: "visit_plans", id: Self.planId.lowercased())) {
            try store.addVisitPlan(Self.change(plan: Self.plan(Self.planId.lowercased())), for: "owner")
        }
        let other = "5E30C000-0000-4000-8000-000000000003"
        #expect(throws: ResearchRowStoreError.invalidId(table: "visit_documents", id: Self.seedA)) {
            try store.addVisitPlan(Self.change(plan: Self.plan(other)), for: "owner")
        }
        #expect(throws: ResearchRowStoreError.unknownColumn(table: "visit_plans", column: "status")) {
            try store.addVisitPlan(VisitPlanChange(plan: Self.plan(other).merging(["status": .text("draft")]) { $1 }, documents: [], targets: []),
                                   for: "owner")
        }
        #expect(try rows.rows(of: "visit_plans").count == 1 && rows.rows(of: "visit_documents").count == 2)
    }

    /// Two users' plans stay apart: each holds one under the same id, as two who import one Mac's export do; one's is
    /// neither read, changed nor deleted by the other.
    @Test(arguments: UserStoreKind.available)
    func twoUsersPlansStayApart(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try rows.addUser("reader")
        try store.addVisitPlan(Self.change(), for: "owner")
        try store.addVisitPlan(Self.change(plan: Self.plan(name: "The reader's")), for: "reader")
        #expect(Self.keys([try #require(try store.visitPlanRows(Self.planId, of: "reader")).plan], "name") == ["The reader's"])
        #expect(try store.changeVisitPlan(Self.planId, for: "reader") { _ in
            VisitPlanChange(plan: ["id": .text(Self.planId), "name": .text("Renamed")], documents: [], targets: [])
        }.map { Self.keys([$0.plan], "name") } == ["Renamed"])
        #expect(try store.deleteVisitPlan(Self.planId, for: "reader"))
        let owners = try #require(try store.visitPlanRows(Self.planId, of: "owner"))
        #expect(Self.keys([owners.plan], "name") == ["College Park"] && owners.documents.count == 2 && owners.targets.count == 1)
        #expect(try store.visitPlanRows(of: "reader").plans.isEmpty)
        #expect(try store.visitPlanRows(Self.planId, of: "nobody") == nil)
    }
}
