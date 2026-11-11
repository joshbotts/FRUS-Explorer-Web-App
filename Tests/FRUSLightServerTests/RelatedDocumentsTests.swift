// Related Documents and Suggested Next through the router (PLAN's S23d), over the synthetic export: the
// list's refusals and what it answers of each axis; Suggested Next's Refresh, a job of the server's
// queue, one waiting a project at most, refused while no index is served and for another user's project,
// whose leads and notes never reach another user's; the leads' seed and tuning as the app's
// `ProjectLeadsService` gathers them; and the leads computed again after a JSON import, for each of that
// user's projects. The kit's ranking itself is held to the API's over the fixture index in
// `RelatedDocumentsParityTests`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct RelatedDocumentsTests {
    static let volume = UserHalfSearchTests.volume

    @Test func theListsRefusalsAndItsAxes() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let base = "/api/v1/volumes/\(Self.volume)/documents/d1/related"
            let list = try decode(RelatedDocuments.self, try await client.execute(uri: base, method: .get))
            #expect(list.scope == "all" && list.weights == "" && list.scopes.first == "volume" && list.scopes.last == "all")
            #expect(list.axes.map(\.id) == SimilarityAxis.allCases.map(\.rawValue))
            #expect(list.axes.map(\.weight) == SimilarityAxis.allCases.map(\.defaultWeight))
            #expect(list.axes.filter { !$0.available }.map(\.id) == ["crossReference", "semanticSimilarity", "lexicalSimilarity"],
                    "no cross-reference query until S23c, no lexical search until S24d, no semantic axis until phase 4")
            #expect(list.axes.first { $0.id == "sharedSubjects" }?.available == true, "the image's subject index")
            // A tuning in the kit's stored form is answered in the kit's spelling.
            let tuned = try decode(RelatedDocuments.self, try await client.execute(uri: "\(base)?weights=sharedPersons:1,dateProximity:0.5", method: .get))
            #expect(tuned.weights == "sharedPersons:1.0" && tuned.axes.first { $0.id == "sharedPersons" }?.weight == 1)
            for (query, code) in [("weights=nonsense", "INVALID_PARAMETER"), ("weights=sharedPersons:2", "INVALID_PARAMETER"),
                                  ("weights=sharedPersons:-0.5", "INVALID_PARAMETER"), ("scope=everything", "INVALID_PARAMETER"),
                                  ("limit=0", "INVALID_PARAMETER"), ("limit=121", "INVALID_PARAMETER"), ("sort=date", "UNKNOWN_PARAMETER")] {
                #expect(problemCode(try await client.execute(uri: "\(base)?\(query)", method: .get)) == code, "\(query)")
            }
            #expect(problemCode(try await client.execute(uri: "/api/v1/volumes/frus1800nowhere/documents/d1/related", method: .get)) == "VOLUME_NOT_FOUND")
            // A volume with no other of its subseries in the catalogue has no subseries scope.
            if !list.scopes.contains("subseries") {
                #expect(problemCode(try await client.execute(uri: "\(base)?scope=subseries", method: .get)) == "SCOPE_NOT_OFFERED")
            }
            // A document the index does not hold has nothing related, as the app's engine finds nothing for it.
            let unheld = try decode(RelatedDocuments.self, try await client.execute(uri: "/api/v1/volumes/\(Self.volume)/documents/d999/related", method: .get))
            #expect(unheld.rows.isEmpty && unheld.totalBeforeLimit == 0)
        }
        let waiting = try await UserDataFixture()
        defer { withExtendedLifetime(waiting) {} }
        try await waiting.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/volumes/\(Self.volume)/documents/d1/related", method: .get)
            #expect(response.status == .serviceUnavailable && problemCode(response) == "INDEX_NOT_READY")
        }
    }

    /// The seed is the app's: a project's collections' document entries, an entry with no kind read as a
    /// document's; its notes on a document; and the documents its focus tags mark, by an assignment or a
    /// note's tags; never its visits, nor another project's. The tuning is the project's, else the browser's,
    /// else the defaults, each axis it leaves out at its default.
    @Test func theSeedAndTheTuningAreTheApps() throws {
        let grain = UUID()
        let other = UUID()
        let focus = UUID()
        func entry(_ document: String, kind: String?) -> CollectionEntryExport {
            CollectionEntryExport(id: UUID(), documentId: document, volumeId: Self.volume, sortOrder: 0, selectedNoteIds: [], kind: kind)
        }
        func note(_ document: String, projects: [UUID] = [], tags: [UUID] = []) -> ResearchNoteExport {
            ResearchNoteExport(id: UUID(), documentId: document, volumeId: document.isEmpty ? "" : Self.volume, bodyText: "", projectIds: projects,
                               userTagIds: tags, selectedSummaryIds: [], linkedHighlightIds: [], createdAt: nil, lastModified: nil)
        }
        let mine = CollectionExport(id: UUID(), name: "Mine", projectIds: [grain], entries: [
            entry("d2", kind: "document"), entry("d3", kind: nil), entry("d4", kind: "heading"), entry("", kind: "document"),
        ])
        let theirs = CollectionExport(id: UUID(), name: "Theirs", projectIds: [other], entries: [entry("d5", kind: "document")])
        #expect(ProjectLeadsSeed.collectionKeys(forProject: grain, collections: [mine, theirs]) == ["\(Self.volume)/d2", "\(Self.volume)/d3"])
        let notes = [note("d6", projects: [grain]), note("d7", projects: [other]), note("", projects: [grain]), note("d8", tags: [focus])]
        #expect(ProjectLeadsSeed.noteKeys(forProject: grain, notes: notes) == ["\(Self.volume)/d6"])
        let assignments = [TagAssignmentRecord(id: "A1", volumeId: Self.volume, documentId: "d9", tagId: focus.uuidString.lowercased(), createdAt: nil),
                           TagAssignmentRecord(id: "A2", volumeId: Self.volume, documentId: "d10", tagId: UUID().uuidString, createdAt: nil)]
        #expect(ProjectLeadsSeed.taggedKeys(forTags: [focus], assignments: assignments, notes: notes) == ["\(Self.volume)/d8", "\(Self.volume)/d9"])
        #expect(ProjectLeadsSeed.taggedKeys(forTags: [], assignments: assignments, notes: notes) == [])
        let project = ProjectExport(id: grain, name: "Grain", defaultSubjectTagIds: [], defaultCountryTagIds: [], defaultUserTagIds: [focus])
        #expect(ProjectLeadsSeed.keys(forProject: project, collections: [mine, theirs], notes: notes, assignments: assignments)
                == ["d2", "d3", "d6", "d8", "d9"].map { "\(Self.volume)/\($0)" })

        #expect(ProjectLeadsSeed.effectiveWeights(projectRaw: nil, browserRaw: nil) == .default)
        #expect(ProjectLeadsSeed.effectiveWeights(projectRaw: "sharedPersons:0.1", browserRaw: "sharedPersons:0.9")[.sharedPersons] == 0.1)
        let browsers = ProjectLeadsSeed.effectiveWeights(projectRaw: nil, browserRaw: "sharedPersons:0.9")
        #expect(browsers[.sharedPersons] == 0.9 && browsers[.archivalProvenance] == 1)
        #expect(ProjectLeadsSeed.effectiveWeights(projectRaw: "", browserRaw: "sharedPersons:0.9") == .default, "the project's default tuning")
        #expect(ProjectLeadsSeed.effectiveWeights(projectRaw: "not a tuning", browserRaw: nil) == .default)
    }

    /// A Refresh is a job of the server's queue; one asked for while another waits is that one; another
    /// user's project is refused, and their leads and notes never reach the first user's.
    @Test func aRefreshIsAJobOneWaitingAProject() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let grain = try await ProjectHistoryTests.made(alice, "Grain")
            let theirs = try await ProjectHistoryTests.made(bob, "Theirs")
            _ = try await bob.send(.post, "/api/v1/me/volumes/\(Self.volume)/documents/d1/notes",
                                   try ProjectHistoryTests.json(["bodyText": "Bob's", "userTagIds": [String](), "projectIds": [theirs.id],
                                                                 "selectedSummaryIds": [String]()]))
            // Bob's project is not Alice's to refresh.
            let refused = try await alice.send(.post, "/api/v1/me/projects/\(theirs.id)/leads/refresh", "{}")
            #expect(refused.status == .notFound && problemCode(refused) == "PROJECT_NOT_FOUND")
            let badWeights = try await alice.send(.post, "/api/v1/me/projects/\(grain.id)/leads/refresh", #"{"weights": "sharedPersons:3"}"#)
            #expect(problemCode(badWeights) == "INVALID_PARAMETER")

            // Held at the queue's head, so the Refresh waits: a second is the same job.
            let gate = JobGate()
            _ = try await fixture.jobs.submit(.indexReset, subject: nil, requestedBy: nil, id: nil) { _ in
                await gate.wait()
                return nil
            }
            let first = try await alice.send(.post, "/api/v1/me/projects/\(grain.id)/leads/refresh", #"{"weights": "sharedPersons:0.2"}"#)
            #expect(first.status == .accepted && (try decode(LeadsRefresh.self, first)).state == "queued")
            let second = try await alice.send(.post, "/api/v1/me/projects/\(grain.id)/leads/refresh", "{}")
            #expect((try decode(LeadsRefresh.self, second)).state == "queued")
            let leadsJobs = await fixture.jobs.jobs().filter { $0.kind == .projectLeads }
            #expect(leadsJobs.count == 1 && leadsJobs.first?.requestedBy == "alice", "one job, the first")
            let home = try await ProjectFocusTests.home(alice, grain)
            #expect(home.leadsRefresh?.state == "queued")
            gate.open()
            await fixture.jobs.waitUntilIdle()
            let after = try await ProjectFocusTests.home(alice, grain)
            #expect(after.leadsRefresh?.state == "succeeded" && after.leads.isEmpty, "a project with nothing to rank from")
            let job = try #require(await fixture.jobs.job(try #require(leadsJobs.first?.id)))
            #expect(job.progress?.contains("cleared") == true && job.progress?.contains("Bob") == false)
            // Bob's project and its leads are his alone: Alice's computation read none of his notes.
            let bobs = try await ProjectFocusTests.home(bob, theirs)
            #expect(bobs.leadsRefresh == nil && bobs.leads.isEmpty)
        }
    }

    /// While no index is served a Refresh is refused, and the leads stay as they were.
    @Test func aRefreshWaitsForAnIndex() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let grain = try await ProjectHistoryTests.made(owner, "Grain")
            let refused = try await owner.send(.post, "/api/v1/me/projects/\(grain.id)/leads/refresh", "{}")
            #expect(refused.status == .serviceUnavailable && problemCode(refused) == "INDEX_NOT_READY")
            #expect(await fixture.jobs.jobs().filter { $0.kind == .projectLeads }.isEmpty)
        }
    }

    /// After a JSON import, each of that user's projects has its leads computed again, a job each, queued
    /// behind the import's.
    @Test func anImportQueuesEachProjectsLeads() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            _ = try await ProjectHistoryTests.made(owner, "Grain")
            _ = try await ProjectHistoryTests.made(owner, "Berlin")
            // The import's export brings a third project, with a note filed under it.
            let response = try await owner.send(.post, "/api/v1/me/import", try ImportRouteTests.export())
            #expect(response.status == .accepted, "\(String(buffer: response.body))")
            await fixture.jobs.waitUntilIdle()
            let jobs = await fixture.jobs.jobs()
            #expect(jobs.filter { $0.kind == .researchImport }.map(\.state) == [.succeeded])
            let leads = jobs.filter { $0.kind == .projectLeads }
            #expect(leads.count == 3 && leads.allSatisfy { $0.requestedBy == nil && $0.state == .succeeded }, "\(leads)")
        }
    }
}
