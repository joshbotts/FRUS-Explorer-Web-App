// Related Documents and Suggested Next through the router (PLAN's S23d), over the synthetic export: the
// list's refusals and what it answers of each axis; Suggested Next's Refresh, a job of the server's
// queue, one waiting a project at most, refused while no index is served and for another user's project,
// whose leads and notes never reach another user's; Project Home giving a computation as ended only
// beside the leads it kept; the leads' seed and tuning as the app's `ProjectLeadsService` gathers them;
// and the leads computed again after a JSON import, for each of that user's projects. The kit's ranking
// itself is held to the API's over the fixture index in `RelatedDocumentsParityTests`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Synchronization
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
            #expect(list.axes.filter { !$0.available }.map(\.id) == ["semanticSimilarity", "lexicalSimilarity"],
                    "the kit's cross-reference store since S23c's pin move; no lexical search until S24e's follow-up, no semantic axis until phase 4")
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

    /// A Refresh is a job of the server's queue; two asked for at once, or one while another waits, are that
    /// one; another user's project is refused; and a computation reads its own user's records alone, though
    /// two users hold one project's id, as two who imported one export do.
    @Test func aRefreshIsAJobOneWaitingAProject() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        // Live, so that each request comes from the proxy's address.
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            // Both import one export: one project's id, with a note on d3 filed under it, for each.
            for browser in [alice, bob] {
                let response = try await browser.send(.post, "/api/v1/me/import", try ImportRouteTests.export())
                #expect(response.status == .accepted, "\(String(buffer: response.body))")
                await fixture.jobs.waitUntilIdle()
            }
            let shared = ImportRouteTests.id(40).uuidString
            let note = try await bob.send(.post, "/api/v1/me/volumes/\(Self.volume)/documents/d4/notes",
                                          try ProjectHistoryTests.json(["bodyText": "Bob's", "runs": nil, "userTagIds": [String](),
                                                                        "projectIds": [shared], "selectedSummaryIds": [String]()]))
            #expect(note.status == .created, "\(String(buffer: note.body))")
            let bobs = try fixture.rows.rows(of: "project_leads", user: "bob")
            let grain = try await ProjectHistoryTests.made(alice, "Grain")
            // Bob's project is not Alice's to refresh, nor is a tuning the kit cannot read taken.
            let theirs = try await ProjectHistoryTests.made(bob, "Theirs")
            let refused = try await alice.send(.post, "/api/v1/me/projects/\(theirs.id)/leads/refresh", "{}")
            #expect(refused.status == .notFound && problemCode(refused) == "PROJECT_NOT_FOUND")
            let badWeights = try await alice.send(.post, "/api/v1/me/projects/\(grain.id)/leads/refresh", #"{"weights": "sharedPersons:3"}"#)
            #expect(problemCode(badWeights) == "INVALID_FIELD")

            // Held at the queue's head, so the Refreshes wait: two at once are one job.
            let gate = JobGate()
            _ = try await fixture.jobs.submit(.indexReset, subject: nil, requestedBy: nil, id: nil) { _ in
                await gate.wait()
                return nil
            }
            async let first = alice.send(.post, "/api/v1/me/projects/\(shared)/leads/refresh", #"{"weights": "sharedPersons:0.2"}"#)
            async let second = alice.send(.post, "/api/v1/me/projects/\(shared)/leads/refresh", "{}")
            let (one, two) = try await (first, second)
            let states = [try decode(LeadsRefresh.self, one), try decode(LeadsRefresh.self, two)]
            #expect(one.status == .accepted && two.status == .accepted)
            #expect(states.map(\.state) == ["queued", "queued"] && states[0].id == states[1].id, "one job, for both")
            let third = try decode(LeadsRefresh.self, try await alice.send(.post, "/api/v1/me/projects/\(shared)/leads/refresh", "{}"))
            #expect(third.id == states[0].id, "a Refresh while it waits is that job")
            let leadsJobs = await fixture.jobs.jobs().filter { $0.kind == .projectLeads && $0.state == .queued }
            #expect(leadsJobs.map(\.id) == [states[0].id] && leadsJobs.first?.requestedBy == "alice")
            #expect(try await ProjectFocusTests.home(alice, try decode(Project.self, try await alice.get("/api/v1/me/projects/\(shared)"))).leadsRefresh?.id
                    == states[0].id)
            gate.open()
            await fixture.jobs.waitUntilIdle()
            let job = try #require(await fixture.jobs.job(states[0].id))
            // Alice's seed is her note alone: Bob's note under the same project's id is not hers.
            #expect(job.state == .succeeded && job.progress?.hasPrefix("Ranked from 1 document of a project of alice's") == true,
                    "\(job.progress ?? "")")
            #expect(try fixture.rows.rows(of: "project_leads", user: "bob") == bobs, "Bob's leads untouched")
        }
    }

    /// Project Home gives a computation as ended only beside the leads it kept: where the newest stands is
    /// read before the leads are, so one that ends while Project Home is read is given as still running,
    /// or as ended with its own leads, and never as ended beside the leads from before it, which the
    /// browser, reading Project Home again only while one waits or runs, would keep. Here the computation
    /// runs to its end at the moment Project Home reads where it stands, as one did under the parity
    /// suite's load, where the leads' lines waited on the served index it ranked over.
    @Test func projectHomeGivesAComputationAsEndedBesideTheLeadsItKept() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        // The server's routes, as `UserDataFixture.app` builds them, with the provider `buildRouter` makes
        // when given none, and the leads' queue reading its jobs through `holding`.
        let holding = ReadHoldingQueue(fixture.jobs)
        let provider = ServedIndexProvider(state: fixture.server.state, resources: fixture.server.resources,
                                           volumesDirectory: await fixture.server.reader.volumesDirectory,
                                           userStore: fixture.services.enabled ? fixture.services.store.searchDatabase : nil)
        let leads = ProjectLeadsQueue(store: fixture.services.store, jobs: holding, provider: provider, resources: fixture.server.resources,
                                      now: fixture.services.now)
        let app = Application(router: ServedRouter(base: .root, router: buildRouter(
            state: fixture.server.state, resources: fixture.server.resources, reader: fixture.server.reader, provider: provider,
            userData: fixture.services, leads: leads)))
        try await app.test(.router) { client in
            let owner = Browser(client: client)
            let grain = try await ProjectHistoryTests.made(owner, "Grain")
            // Its seed is d1, which a note filed under it is on; and its lead is d1 too, which its
            // computation ranks from d1 and removes, as a seed is never its own lead.
            let note = try await owner.send(.post, "/api/v1/me/volumes/\(Self.volume)/documents/d1/notes", try ProjectHistoryTests.json(
                ["bodyText": "", "runs": nil, "userTagIds": [String](), "projectIds": [grain.id], "selectedSummaryIds": [String]()]))
            #expect(note.status == .created, "\(String(buffer: note.body))")
            try fixture.rows.run(
                """
                INSERT INTO project_leads (user_id, id, project_id, volume_id, document_id, aggregate_score, contributing_seed_keys,
                                           header, is_editorial_note, first_surfaced_at, last_computed_at, dismissed)
                    VALUES ('owner', ?, ?, ?, 'd1', 1, '[]', 'Lead', 0, ?, ?, 0)
                """, [.text(ProjectFocusTests.entry(1)), .text(grain.id), .text(Self.volume),
                      .text(UserStoreDate.text(UserDataFixture.now)), .text(UserStoreDate.text(UserDataFixture.now))])
            #expect(try await ProjectFocusTests.home(owner, grain).leads.map(\.documentId) == ["d1"])
            // Held at the queue's head, so the Refresh's computation waits; and let go however the test ends.
            let gate = JobGate()
            defer { gate.open() }
            _ = try await fixture.jobs.submit(.indexReset, subject: nil, requestedBy: nil, id: nil) { _ in
                await gate.wait()
                return nil
            }
            let asked = try decode(LeadsRefresh.self, try await owner.send(.post, "/api/v1/me/projects/\(grain.id)/leads/refresh", "{}"))
            #expect(asked.state == "queued")
            // The computation runs to its end as Project Home reads where it stands.
            holding.atNextRead {
                gate.open()
                await fixture.jobs.waitUntilIdle()
            }
            let home = try await ProjectFocusTests.home(owner, grain)
            #expect(holding.held, "Project Home read where the computation stands")
            #expect(home.leadsRefresh?.id == asked.id && home.leadsRefresh?.state == "succeeded", "\(String(describing: home.leadsRefresh))")
            let job = try #require(await fixture.jobs.job(asked.id))
            #expect(job.progress?.hasPrefix("Ranked from 1 document of a project of owner's") == true, "\(job.progress ?? "")")
            // The leads the computation kept, as Project Home reads them once it has ended, not those from before it.
            let kept = try await ProjectFocusTests.home(owner, grain).leads.map(\.documentId)
            #expect(!kept.contains("d1"))
            #expect(home.leads.map(\.documentId) == kept)
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

    /// After a JSON import, each of that user's projects has its leads computed again, in one job queued
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
            // One job for every project of the user's, two made here and one the export brought.
            let leads = jobs.filter { $0.kind == .projectLeads }
            #expect(leads.count == 1 && leads.first?.requestedBy == nil && leads.first?.state == .succeeded, "\(leads)")
            #expect(leads.first?.subject == "Every project of owner's" && leads.first?.progress == "Found the leads of 3 projects")
        }
    }
}

/// The server's queue, whose next read of a job, once a test asks, first waits for the test's `work`:
/// Project Home's read of where a computation stands, at which the test ends the computation.
private final class ReadHoldingQueue: JobQueue {
    let queue: InProcessJobQueue
    /// The work the next read of a job waits for, and whether a read has waited for one.
    private let state = Mutex<(work: (@Sendable () async -> Void)?, held: Bool)>((nil, false))

    init(_ queue: InProcessJobQueue) { self.queue = queue }

    /// Holds the next read of a job until `work` has run.
    func atNextRead(_ work: @escaping @Sendable () async -> Void) { state.withLock { $0.work = work } }

    /// Whether a read was held.
    var held: Bool { state.withLock { $0.held } }

    func submit(_ kind: JobKind, subject: String?, requestedBy: String?, id: String?, onCancel: (@Sendable () async -> Void)?,
                _ work: @escaping @Sendable (JobContext) async throws -> String?) async throws -> Job {
        try await queue.submit(kind, subject: subject, requestedBy: requestedBy, id: id, onCancel: onCancel, work)
    }

    func job(_ id: String) async -> Job? {
        let work = state.withLock { state in
            defer { state.work = nil }
            return state.work
        }
        if let work {
            await work()
            state.withLock { $0.held = true }
        }
        return await queue.job(id)
    }

    func jobs() async -> [Job] { await queue.jobs() }

    func cancel(_ id: String, by user: String?) async throws -> Job { try await queue.cancel(id, by: user) }
}
