// Archives Visits through the router (PLAN's S30c), over the synthetic export, whose documents carry no source note, so
// that no target derives and each write is the plan's own: New under the active project with its research question, the
// list's order and words, Rename's draft, Duplicate under the copy's derived ids with its tiers kept, Delete's cascade,
// Re-seed from Project with its topic filled, unchanged or asked about, a seed's two switches and its Remove, the tiers'
// sheet, each row stamped as the app's save stamps it; the refusals; and two users' plans apart. The derivation and a
// target's writes over targets that derive are `ArchiveVisitParityTests`', over the kit's fixture index.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct ArchiveVisitTests {
    static let volume = UserHalfSearchTests.volume
    static let now = UserStoreDate.text(UserDataFixture.now)
    static let earlier = Date(timeIntervalSince1970: 1_790_000_000)

    static func json(_ object: [String: Any?]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object.mapValues { $0 ?? NSNull() }), as: UTF8.self)
    }

    static func detail(_ response: TestResponse, _ status: HTTPResponse.Status = .ok,
                       sourceLocation: SourceLocation = #_sourceLocation) throws -> VisitPlanDetail {
        #expect(response.status == status, "\(response.status.code) \(String(buffer: response.body))", sourceLocation: sourceLocation)
        return try decode(VisitPlanDetail.self, response)
    }

    static func created(_ browser: Browser, _ fields: [String: Any?] = [:]) async throws -> VisitPlanDetail {
        try detail(try await browser.send(.post, "/api/v1/me/visits", try json(fields)), .created)
    }

    static func project(_ browser: Browser, _ name: String, question: String?) async throws -> String {
        let response = try await browser.send(.post, "/api/v1/me/projects", try json(["name": name, "researchQuestion": question]))
        #expect(response.status == .created, "\(String(buffer: response.body))")
        return try decode(FRUSLightAPI.Project.self, response).id
    }

    static func note(_ browser: Browser, on document: String, project: String) async throws {
        let response = try await browser.send(.post, "/api/v1/me/volumes/\(volume)/documents/\(document)/notes", try json([
            "bodyText": "A note on \(document)", "runs": String?.none, "userTagIds": [String](), "projectIds": [project],
            "selectedSummaryIds": [String](),
        ]))
        #expect(response.status == .created, "\(String(buffer: response.body))")
    }

    /// A plan written straight to the store as the import writes a Mac's, with its seeds and stored targets.
    static func stored(_ fixture: UserDataFixture, _ plan: ArchiveVisitPlanExport, for user: String = "owner") throws {
        try fixture.store.addVisitPlan(VisitPlanChange(plan: MacImport.plan(plan).values,
                                                       documents: plan.documents.map { MacImport.seed($0, of: plan.id).values },
                                                       targets: plan.targets.map { MacImport.target($0, of: plan.id).values }), for: user)
    }

    /// A Mac plan of two seeds, two tiers and two stored targets, made `earlier`.
    static func macPlan(id: UUID = UUID()) -> ArchiveVisitPlanExport {
        let first = ArchiveVisitTier(id: UUID(), label: "First morning", order: 0)
        let second = ArchiveVisitTier(id: UUID(), order: 1)
        let seeds = ["\(volume)/d1", "\(volume)/d2"].map {
            ArchiveVisitDocumentExport(id: ArchiveVisitPlanWrites.derivedChildId(planId: id, key: $0), documentKey: $0, includeSource: true,
                                       includeExternalRefs: $0.hasSuffix("d1"), createdAt: earlier, lastModified: earlier)
        }
        let targets = ["lot|66D204", "decimal|737.00/1-161"].map {
            ArchiveVisitTargetExport(id: ArchiveVisitPlanWrites.derivedChildId(planId: id, key: $0), targetKey: $0,
                                     tierId: $0.hasPrefix("lot") ? first.id : second.id, included: $0.hasPrefix("lot"),
                                     userNote: $0.hasPrefix("lot") ? "Box 4" : nil, createdAt: earlier, lastModified: earlier)
        }
        return ArchiveVisitPlanExport(id: id, name: "College Park", inquiryText: "The letters", projectIds: [], tiers: [first, second],
                                      deliverables: ArchiveVisitDeliverables(includeCitationCrib: true), documents: seeds, targets: targets,
                                      createdAt: earlier, lastModified: earlier)
    }

    /// The plan as the store holds it, read as the export reads one.
    static func held(_ fixture: UserDataFixture, _ id: String, for user: String = "owner") throws -> ArchiveVisitPlanExport? {
        try fixture.store.visitPlanRows(id, of: user).map(ArchiveVisitRoutes.record)
    }

    /// New Archives Visit: under the active project, its research question the topic, untitled; in the Global Context,
    /// neither; listed most recently changed first, a plan with no seeds counting its documents.
    @Test func aNewPlanBelongsToTheActiveProjectAndCopiesItsQuestion() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let project = try await Self.project(owner, "Berlin", question: "What did Khrushchev want?")
            let response = try await owner.send(.post, "/api/v1/me/visits", "{}")
            let plan = try Self.detail(response, .created)
            #expect(response.headers[.location] == "/api/v1/me/visits/\(plan.id)")
            #expect(UUID(uuidString: plan.id)?.uuidString == plan.id, "an uppercase uuidString, as the Mac's ids are")
            #expect(plan.name == "" && plan.displayName == "Untitled Archives Visit")
            #expect(plan.inquiryText == "What did Khrushchev want?" && plan.projectIds == [project])
            #expect(plan.project == .init(id: project, name: "Berlin"), "Re-seed from Project is offered")
            #expect(plan.tiers.isEmpty && plan.documents.isEmpty && plan.storedTargets.isEmpty && plan.sections.isEmpty)
            #expect(plan.served && plan.summary == nil && plan.documentCount == 0)
            #expect(plan.deliverables == .init(includeLinks: true, includeTargets: true, includeInquiry: true, includeCitationCrib: false))
            #expect(plan.createdAt == Self.now && plan.lastModified == Self.now)

            // The Global Context: no project, no topic.
            #expect(try await owner.send(.put, "/api/v1/me/active-project", #"{"projectId": null}"#).status == .ok)
            let global = try await Self.created(owner, ["name": "Abilene"])
            #expect(global.name == "Abilene" && global.projectIds.isEmpty && global.inquiryText == nil && global.project == nil)

            try Self.stored(fixture, Self.macPlan())
            let list = try await UserHalfSearchTests.answer(VisitPlanList.self, owner, "/api/v1/me/visits")
            #expect(list.total == 3)
            #expect(list.items.map(\.displayName) == ["Untitled Archives Visit", "Abilene", "College Park"],
                    "the most recently changed first, a tie in the store's order")
            #expect(list.items[0].summary == nil && list.items[0].documentCount == 0)
            // The synthetic export holds both seeds' volume and derives nothing from them.
            #expect(list.items[2].documentCount == 2 && list.items[2].indexedDocumentCount == 2)
            #expect(list.items[2].summary == "0 targets · 0 repositories")
        }
    }

    /// Rename from the reader's draft: trimmed, and an empty one writes nothing, its date included; the topic as written,
    /// a blank one as none.
    @Test func renameReadsTheDraftAsTheKitsRuleDoes() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let plan = Self.macPlan()
        try Self.stored(fixture, plan)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let path = "/api/v1/me/visits/\(plan.id.uuidString.lowercased())"
            let untouched = try Self.detail(try await owner.send(.patch, path, #"{"name": "  \n "}"#))
            #expect(untouched.name == "College Park" && untouched.lastModified == UserStoreDate.text(Self.earlier),
                    "an empty commit never clears a plan to Untitled, and stamps nothing")
            let renamed = try Self.detail(try await owner.send(.patch, path, #"{"name": "  Berlin trip \n"}"#))
            #expect(renamed.name == "Berlin trip" && renamed.displayName == "Berlin trip" && renamed.lastModified == Self.now)
            let topic = try Self.detail(try await owner.send(.patch, path, #"{"inquiryText": "Khrushchev's letters"}"#))
            #expect(topic.inquiryText == "Khrushchev's letters")
            #expect(try Self.detail(try await owner.send(.patch, path, #"{"inquiryText": "   "}"#)).inquiryText == nil)
            // A seed and a target are untouched by the plan's own writes.
            let held = try #require(try Self.held(fixture, plan.id.uuidString))
            #expect(held.documents.map(\.lastModified) == [UserStoreDate.rounded(Self.earlier), UserStoreDate.rounded(Self.earlier)])
            #expect(held.targets.map(\.lastModified) == [UserStoreDate.rounded(Self.earlier), UserStoreDate.rounded(Self.earlier)])
        }
    }

    /// Duplicate: "<name> copy", every seed and target under the copy's derived id, made now, its tiers kept with their ids,
    /// so its targets keep their tiers; the source as it was.
    @Test func aDuplicateIsTheKitsCopyUnderItsOwnDerivedIds() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let plan = Self.macPlan()
        try Self.stored(fixture, plan)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let response = try await owner.send(.post, "/api/v1/me/visits/\(plan.id.uuidString)/duplicate")
            let copy = try Self.detail(response, .created)
            #expect(response.headers[.location] == "/api/v1/me/visits/\(copy.id)")
            #expect(copy.name == "College Park copy" && copy.id != plan.id.uuidString)
            #expect(copy.tiers.map(\.id) == plan.tiers.map(\.id.uuidString) && copy.tiers.map(\.members) == [1, 1])
            let held = try #require(try Self.held(fixture, copy.id))
            let copyId = try #require(UUID(uuidString: copy.id))
            #expect(held == ArchiveVisitPlanWrites.duplicate(of: try #require(try Self.held(fixture, plan.id.uuidString)), id: copyId,
                                                             now: UserDataFixture.now),
                    "the kit's copy, row for row")
            #expect(held.documents.map(\.id) == held.documents.map { ArchiveVisitPlanWrites.derivedChildId(planId: copyId, key: $0.documentKey) })
            #expect(held.inquiryText == "The letters" && held.deliverables.includeCitationCrib)
            #expect(try Self.held(fixture, plan.id.uuidString)?.name == "College Park")
        }
    }

    /// Delete: the plan with every seed and target that names it, in any letter case, as the kit's cascade lists them.
    @Test func deleteTakesEverySeedAndTargetWithThePlan() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let plan = Self.macPlan()
        let kept = Self.macPlan()
        try Self.stored(fixture, plan)
        try Self.stored(fixture, kept)
        // A target that names the plan in lower case, as another writer may have.
        try fixture.rows.run("""
            INSERT INTO visit_targets (user_id, id, plan_id, target_key, included) VALUES ('owner', ?, ?, 'r|A note', 1)
            """, [.text(UUID().uuidString), .text(plan.id.uuidString.lowercased())])
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await owner.send(.delete, "/api/v1/me/visits/\(plan.id.uuidString)").status == .noContent)
            #expect(problemCode(try await owner.get("/api/v1/me/visits/\(plan.id.uuidString)")) == "VISIT_NOT_FOUND")
            let (plans, documents, targets) = try fixture.store.visitPlanRows(of: "owner")
            #expect(plans.count == 1 && documents.count == 2 && targets.count == 2, "the other plan's rows alone")
            #expect(problemCode(try await owner.send(.delete, "/api/v1/me/visits/\(plan.id.uuidString)")) == "VISIT_NOT_FOUND")
        }
    }

    /// Re-seed from Project: the project's seed, gathered as Suggested Next gathers it, added with both halves on, flags
    /// turned on and never off; its question written into an empty topic, left where the topic reads it, asked about where
    /// the topic says something else, which writes nothing; and nothing at all once the project is gone.
    @Test func reseedAddsTheProjectsSeedAndOffersItsQuestion() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let project = try await Self.project(owner, "Berlin", question: "What did Khrushchev want?")
            try await Self.note(owner, on: "d1", project: project)
            try await Self.note(owner, on: "d2", project: project)
            let plan = try await Self.created(owner)
            let path = "/api/v1/me/visits/\(plan.id)"
            let first = try decode(VisitReseedAnswer.self, try await owner.send(.post, "\(path)/reseed"))
            #expect(first.topic == "unchanged" && first.added == 2, "the topic reads the question already")
            #expect(first.plan.documents.map(\.key) == ["\(Self.volume)/d1", "\(Self.volume)/d2"])
            #expect(first.plan.documents.allSatisfy { $0.includeSource && $0.includeExternalRefs })
            let planId = try #require(UUID(uuidString: plan.id))
            #expect(try Self.held(fixture, plan.id)?.documents.map(\.id)
                    == ["d1", "d2"].map { ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: "\(Self.volume)/\($0)") })

            // A switch turned off is turned on again: an add turns flags on, never off.
            _ = try Self.detail(try await owner.send(.patch, "\(path)/documents", try Self.json(["key": "\(Self.volume)/d1", "includeSource": false])))
            let again = try decode(VisitReseedAnswer.self, try await owner.send(.post, "\(path)/reseed"))
            #expect(again.added == 0 && again.plan.documents.first?.includeSource == true)

            // The project's question changed: asked about, and nothing written.
            #expect(try await owner.send(.patch, "/api/v1/me/projects/\(project)", #"{"researchQuestion": "Why Vienna?"}"#).status == .ok)
            let asked = try decode(VisitReseedAnswer.self, try await owner.send(.post, "\(path)/reseed"))
            #expect(asked.topic == "needsConfirmation" && asked.question == "Why Vienna?" && asked.current == "What did Khrushchev want?")
            #expect(asked.plan.inquiryText == "What did Khrushchev want?")
            // Replace Topic: the question written as the topic.
            #expect(try Self.detail(try await owner.send(.patch, path, #"{"inquiryText": "Why Vienna?"}"#)).inquiryText == "Why Vienna?")

            // An empty topic is filled.
            _ = try Self.detail(try await owner.send(.patch, path, #"{"inquiryText": ""}"#))
            let filled = try decode(VisitReseedAnswer.self, try await owner.send(.post, "\(path)/reseed"))
            #expect(filled.topic == "filled" && filled.question == "Why Vienna?" && filled.plan.inquiryText == "Why Vienna?")

            // The project deleted: Re-seed is not offered, and changes nothing.
            #expect(try await owner.send(.delete, "/api/v1/me/projects/\(project)").status == .noContent)
            let gone = try decode(VisitReseedAnswer.self, try await owner.send(.post, "\(path)/reseed"))
            #expect(gone.topic == "unchanged" && gone.added == 0 && gone.plan.project == nil)
            #expect(gone.plan.projectIds == [project], "the plan keeps the id, as a deleted project's records do")
        }
    }

    /// A seed's switches and its Remove are writes of its row alone, stamped; the plan is stamped when a seed leaves it.
    @Test func aSeedsSwitchesAndRemoveWriteItsRowAlone() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let plan = Self.macPlan()
        try Self.stored(fixture, plan)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let path = "/api/v1/me/visits/\(plan.id.uuidString)"
            let off = try Self.detail(try await owner.send(.patch, "\(path)/documents",
                                                           try Self.json(["key": "\(Self.volume)/d2", "includeSource": false])))
            #expect(off.documents.map { [$0.includeSource, $0.includeExternalRefs] } == [[true, true], [false, false]])
            let held = try #require(try Self.held(fixture, plan.id.uuidString))
            #expect(held.documents.map(\.lastModified) == [UserStoreDate.rounded(Self.earlier), UserDataFixture.now])
            #expect(held.lastModified == UserStoreDate.rounded(Self.earlier), "a seed's own write leaves the plan's date")
            // The facts of each half over a served index: the synthetic export's documents carry neither.
            #expect(off.documents.allSatisfy { $0.hasSourceNote == false && $0.referenceCount == 0 })
            #expect(off.documents.first?.header == "1. Telegram From the Embassy in the Soviet Union")

            let removed = try Self.detail(try await owner.send(.delete, "\(path)/documents?key=\(Self.volume)%2Fd1"))
            #expect(removed.documents.map(\.key) == ["\(Self.volume)/d2"])
            #expect(try Self.held(fixture, plan.id.uuidString)?.lastModified == UserDataFixture.now, "a seed left the plan")
            #expect(problemCode(try await owner.send(.delete, "\(path)/documents?key=\(Self.volume)%2Fd9")) == "SEED_NOT_FOUND")
            #expect(problemCode(try await owner.send(.patch, "\(path)/documents", try Self.json(["key": "\(Self.volume)/d2"])))
                    == "INVALID_PARAMETER")
        }
    }

    /// The tiers' sheet: Add, an unlabeled tier at the end reading "Priority N"; Rename from the draft, an empty one
    /// clearing the label; a step's move; Delete, its members dropping to Unprioritized.
    @Test func theTiersSheetsWritesAreTheKitsRules() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let plan = Self.macPlan()
        try Self.stored(fixture, plan)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let path = "/api/v1/me/visits/\(plan.id.uuidString)"
            let added = try Self.detail(try await owner.send(.post, "\(path)/tiers"), .created)
            #expect(added.tiers.map(\.displayName) == ["First morning", "Priority 2", "Priority 3"])
            #expect(added.tiers.map(\.order) == [0, 1, 2] && added.tiers.map(\.members) == [1, 1, 0])
            let third = try #require(added.tiers.last?.id)
            let labeled = try Self.detail(try await owner.send(.patch, "\(path)/tiers/\(third)", #"{"label": "  If time allows "}"#))
            #expect(labeled.tiers.last?.label == "If time allows")
            let up = try Self.detail(try await owner.send(.post, "\(path)/tiers/\(third)/move", #"{"by": -1}"#))
            #expect(up.tiers.map(\.displayName) == ["First morning", "If time allows", "Priority 3"], "a tier's place names an unlabeled one")
            let top = try Self.detail(try await owner.send(.post, "\(path)/tiers/\(third)/move", #"{"by": -5}"#))
            #expect(top.tiers.map(\.displayName) == ["If time allows", "First morning", "Priority 3"] && top.tiers.map(\.order) == [0, 1, 2])
            let cleared = try Self.detail(try await owner.send(.patch, "\(path)/tiers/\(third)", #"{"label": ""}"#))
            #expect(cleared.tiers.first?.label == nil && cleared.tiers.first?.displayName == "Priority 1")

            let first = plan.tiers[0].id.uuidString
            let removed = try Self.detail(try await owner.send(.delete, "\(path)/tiers/\(first)"))
            #expect(removed.tiers.map(\.id) == [third, plan.tiers[1].id.uuidString] && removed.tiers.map(\.order) == [0, 1])
            let held = try #require(try Self.held(fixture, plan.id.uuidString))
            #expect(held.targets.first { $0.targetKey == "lot|66D204" }?.tierId == nil, "its member is Unprioritized")
            #expect(held.targets.first { $0.targetKey == "lot|66D204" }?.lastModified == UserDataFixture.now)
            #expect(held.targets.first { $0.targetKey == "lot|66D204" }?.userNote == "Box 4")
            for (method, tail) in [(HTTPRequest.Method.patch, "/tiers/\(first)"), (.delete, "/tiers/\(first)"), (.post, "/tiers/nonsense/move")] {
                let response = try await owner.send(method, path + tail, method == .delete ? nil : #"{"label": "x", "by": 1}"#)
                #expect(response.status == .notFound || response.status == .badRequest, "\(method) \(tail): \(response.status)")
            }
        }
    }

    /// The refusals: a plan the user does not have, a target the plan neither shows nor stores, a target's write that
    /// names more than one change, and fields the routes do not take.
    @Test func theRoutesRefuseWhatTheAppNeverOffers() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let plan = Self.macPlan()
        try Self.stored(fixture, plan)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let stranger = "/api/v1/me/visits/\(UUID().uuidString)"
            for (method, path) in [(HTTPRequest.Method.get, stranger), (.patch, stranger), (.delete, stranger), (.post, "\(stranger)/duplicate"),
                                   (.post, "\(stranger)/reseed"), (.post, "\(stranger)/tiers")] {
                let response = method == .get ? try await owner.get(path) : try await owner.send(method, path, method == .patch ? "{}" : nil)
                #expect(problemCode(response) == "VISIT_NOT_FOUND", "\(method) \(path)")
            }
            let path = "/api/v1/me/visits/\(plan.id.uuidString)"
            // The synthetic export derives no target: the orphans are the stored rows.
            let read = try Self.detail(try await owner.get(path))
            #expect(read.sections.isEmpty && read.storedTargets.map(\.key) == ["decimal|737.00/1-161", "lot|66D204"])
            #expect(read.storedTargets.map(\.label) == ["737.00/1-161", "66D204"] && read.storedTargets.allSatisfy { $0.kind == "orphan" })
            #expect(problemCode(try await owner.send(.patch, "\(path)/targets", try Self.json(["key": "lot|61D21", "note": "x"]))) == "TARGET_NOT_FOUND")
            #expect(problemCode(try await owner.send(.patch, "\(path)/targets", try Self.json(["key": "lot|66D204", "note": "x", "included": false])))
                    == "INVALID_PARAMETER")
            // An orphan's exclusion is not the reader's to set; its note and tier are.
            #expect(problemCode(try await owner.send(.patch, "\(path)/targets", try Self.json(["key": "lot|66D204", "included": false])))
                    == "TARGET_NOT_FOUND")
            let noted = try Self.detail(try await owner.send(.patch, "\(path)/targets", try Self.json(["key": "lot|66D204", "note": "  Box 5 "])))
            #expect(noted.storedTargets.last?.note == "Box 5")
            #expect(problemCode(try await owner.send(.patch, "\(path)/targets", try Self.json(["key": "lot|66D204", "tierId": UUID().uuidString])))
                    == "TIER_NOT_FOUND")
            let removed = try Self.detail(try await owner.send(.delete, "\(path)/targets?key=lot%7C66D204"))
            #expect(removed.storedTargets.map(\.key) == ["decimal|737.00/1-161"])
            #expect(problemCode(try await owner.send(.delete, "\(path)/targets")) == "INVALID_PARAMETER")
            #expect(problemCode(try await owner.send(.patch, path, #"{"title": "x"}"#)) == "UNKNOWN_FIELD")
        }
    }

    /// Two users' plans stay apart: one's are not listed, read, changed, copied, re-seeded or deleted by the other.
    @Test func eachUsersPlansAreTheirsAlone() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        // The bundled files the derivation reads, decoded before the live server starts, whose client waits 20 s.
        _ = try await Blocking.run { ArchiveVisitRoutes.packetIndexes(fixture.server.resources) }
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let hers = try await Self.created(alice, ["name": "Hers"])
            let his = try await Self.created(bob, ["name": "His"])
            #expect(try await UserHalfSearchTests.answer(VisitPlanList.self, alice, "/api/v1/me/visits").items.map(\.displayName) == ["Hers"])
            #expect(try await UserHalfSearchTests.answer(VisitPlanList.self, bob, "/api/v1/me/visits").items.map(\.displayName) == ["His"])
            let path = "/api/v1/me/visits/\(hers.id)"
            for (method, tail) in [(HTTPRequest.Method.get, ""), (.patch, ""), (.post, "/duplicate"), (.post, "/reseed"), (.post, "/tiers"),
                                   (.delete, "")] {
                // A live client sends a POST with no body in chunks, which the guard reads as a body to be JSON.
                let response = method == .get ? try await bob.get(path + tail)
                    : try await bob.send(method, path + tail, method == .delete ? nil : #"{}"#)
                #expect(problemCode(response) == "VISIT_NOT_FOUND", "\(method) \(tail)")
            }
            #expect(try Self.detail(try await alice.get(path)).name == "Hers")
            #expect(try Self.detail(try await bob.get("/api/v1/me/visits/\(his.id)")).name == "His")
        }
    }
}
