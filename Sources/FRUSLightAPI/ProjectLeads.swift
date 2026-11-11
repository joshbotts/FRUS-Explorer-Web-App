// Suggested Next (PLAN's S23d): a project's leads, computed here as the app's `ProjectLeadsService`
// computes them, each computation a job of the server's queue (PLAN's S20d). The seed is the project's
// deliberately engaged documents, gathered as the service gathers them, mirrored here and held to its
// source by `RelatedDocumentsParityTests`: its collections' documents (`collectionSeedKeys`), the
// documents it has notes on (`noteSeedKeys`) and those its focus tags mark, by an assignment or a note's
// tags (`taggedSeedKeys`), never a document only visited. The first forty seeds are each ranked by the
// kit's engine, as Related Documents ranks (RelatedDocuments.swift), with the project's own tuning, else
// the tuning of the browser that asked, as the app reads its device's, else the defaults
// (`effectiveWeights(projectRaw:)`); the kit's `ProjectLeadsAggregator` sums the rankings into twenty-four
// leads; and the store keeps them as the app's `applyLeads` does (UserLeads.swift), where Project Home
// reads them, each with its line (`ProjectHomeRoutes.withLines`, S25c).
//
// A computation runs when Project Home asks to Refresh, and after an import: one job for every project of
// the user whose research a JSON import brought, and one for every project of each user who can sign in
// once an export is the served index. A project has one computation waiting at most: a Refresh while one
// waits is that one, and one while it runs waits behind it, so the leads are ranked from the seed as it
// stands after the change that asked; and each reads, when it starts, the tuning the project's newest
// Refresh brought. The leads are computed over a served index only: with none, a Refresh is refused and the leads
// stay as they were. Beyond your library, the app's count of the volumes the project reaches that the
// device does not hold, is the semantic axis's, and waits for phase 4.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// The seed and the tuning of a project's leads, as the app's `ProjectLeadsService` gathers them.
enum ProjectLeadsSeed {
    /// Seeds ranked a computation (`ProjectLeadsService.seedCap`).
    static let seedCap = 40
    /// Related documents taken from each seed's ranking (`perSeedRelatedLimit`).
    static let perSeedRelatedLimit = 30
    /// Leads kept a project, past its dismissed ones (`leadLimit`).
    static let leadLimit = 24

    /// The documents of the project's collections (`collectionSeedKeys(forProject:in:)`): each document
    /// entry with both its ids, an entry an older file left without a kind read as a document's.
    static func collectionKeys(forProject project: UUID, collections: [CollectionExport]) -> [String] {
        var keys = Set<String>()
        for collection in collections where collection.projectIds.contains(project) {
            for entry in collection.entries
            where (entry.kind ?? CollectionEntryKind.document.rawValue) == CollectionEntryKind.document.rawValue
                && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {
                keys.insert("\(entry.volumeId)/\(entry.documentId)")
            }
        }
        return keys.sorted()
    }

    /// The documents the project's notes are on (`noteSeedKeys(forProject:in:)`).
    static func noteKeys(forProject project: UUID, notes: [ResearchNoteExport]) -> [String] {
        var keys = Set<String>()
        for note in notes where note.projectIds.contains(project) && !note.volumeId.isEmpty && !note.documentId.isEmpty {
            keys.insert("\(note.volumeId)/\(note.documentId)")
        }
        return keys.sorted()
    }

    /// The documents the project's focus tags mark (`taggedSeedKeys(forTags:in:)`): by an assignment of a
    /// focus tag, or a note carrying one; none for a project with no focus tag.
    static func taggedKeys(forTags focusTags: Set<UUID>, assignments: [TagAssignmentRecord],
                           notes: [ResearchNoteExport]) -> [String] {
        guard !focusTags.isEmpty else { return [] }
        var keys = Set<String>()
        for assignment in assignments
        where UUID(uuidString: assignment.tagId).map(focusTags.contains) == true
            && !assignment.volumeId.isEmpty && !assignment.documentId.isEmpty {
            keys.insert("\(assignment.volumeId)/\(assignment.documentId)")
        }
        for note in notes where !Set(note.userTagIds).isDisjoint(with: focusTags) && !note.volumeId.isEmpty && !note.documentId.isEmpty {
            keys.insert("\(note.volumeId)/\(note.documentId)")
        }
        return keys.sorted()
    }

    /// The project's seed (`gatherSeed(forProject:container:)`): the three unioned, sorted.
    static func keys(forProject project: ProjectExport, collections: [CollectionExport], notes: [ResearchNoteExport],
                     assignments: [TagAssignmentRecord]) -> [String] {
        let focusTags = Set(project.defaultUserTagIds ?? [])
        return Set(collectionKeys(forProject: project.id, collections: collections))
            .union(noteKeys(forProject: project.id, notes: notes))
            .union(taggedKeys(forTags: focusTags, assignments: assignments, notes: notes))
            .sorted()
    }

    /// The tuning the leads are ranked with (`effectiveWeights(projectRaw:)`): the project's own, else the
    /// one the asking browser keeps, as the app reads its device's, else the defaults; each axis it leaves
    /// out at its default.
    static func effectiveWeights(projectRaw: String?, browserRaw: String?) -> AxisWeights {
        let stored = projectRaw ?? browserRaw
        let base = stored.flatMap { AxisWeights(rawValue: $0) } ?? .default
        var merged: [SimilarityAxis: Double] = [:]
        for axis in SimilarityAxis.allCases {
            merged[axis] = base.weights[axis] ?? axis.defaultWeight
        }
        return AxisWeights(weights: merged)
    }
}

/// Where a project's leads are computed: the server's queue, one computation waiting a project at most.
actor ProjectLeadsQueue {
    let store: any UserDataStore
    let jobs: any JobQueue
    let provider: ServedIndexProvider
    let resources: ServerResources
    let now: @Sendable () -> Date
    /// The newest computation queued for each project, by its user and its id: its own, or the one an
    /// import queued for every project concerned.
    private var latest: [Key: String] = [:]
    /// A computation being queued for a project, which a Refresh arriving meanwhile is: the queue is
    /// asked across an await, where another Refresh may run on this actor.
    private var queueing: [Key: Task<Job, any Error>] = [:]
    /// The tuning the newest Refresh of each project brought from its browser, which a computation of the
    /// project reads when it starts, whoever queued it.
    private var tunings: [Key: String] = [:]

    struct Key: Hashable, Sendable {
        let user: String
        let project: String

        init(user: String, project: String) {
            self.user = user
            self.project = UserSearchText.uuidString(project)
        }
    }

    init(store: any UserDataStore, jobs: any JobQueue, provider: ServedIndexProvider, resources: ServerResources,
         now: @escaping @Sendable () -> Date = Date.init) {
        self.store = store
        self.jobs = jobs
        self.provider = provider
        self.resources = resources
        self.now = now
    }

    /// Queues a computation of the leads of `project`, `user`'s, or gives the one waiting already, which
    /// reads `browserWeights`, the asking browser's tuning, when it starts, the project's own replacing it.
    func refresh(_ project: String, of user: String, browserWeights: String?) async throws -> Job {
        let key = Key(user: user, project: project)
        if let browserWeights { tunings[key] = browserWeights } else { tunings[key] = nil }
        if let pending = queueing[key] { return try await pending.value }
        if let id = latest[key], let waiting = await jobs.job(id), waiting.state == .queued { return waiting }
        // Asked again while the queue answered: that Refresh's computation is this one.
        if let pending = queueing[key] { return try await pending.value }
        let pending = Task { [jobs] in
            try await jobs.submit(.projectLeads, subject: "Project \(key.project)", requestedBy: user, id: nil) { job in
                try await job.step("Finding the project's leads")
                return try await self.compute(key, job: job)
            }
        }
        queueing[key] = pending
        defer { queueing[key] = nil }
        let job = try await pending.value
        latest[key] = job.id
        return job
    }

    /// Queues one computation of every project of `user`'s, as the server does after their import; or of
    /// every user's who can sign in, once an export is the served index. One job, so that the computations
    /// an import asks for take one row of the admin's Jobs list, not one a project.
    func refreshAfterImport(of user: String?) async {
        let users: [String]
        if let user {
            users = [user]
        } else {
            guard let accounts = try? await Blocking.run({ [store] in try store.accounts() }) else { return }
            users = accounts.filter { $0.disabledAt == nil }.map(\.id)
        }
        var keys: [Key] = []
        for user in users {
            guard let projects = try? await Blocking.run({ [store] in try store.projects(for: user) }) else { continue }
            keys += projects.map { Key(user: user, project: $0.id) }
        }
        guard !keys.isEmpty else { return }
        let subject = user.map { "Every project of \($0)'s" } ?? "Every project"
        let provider = provider
        guard let job = try? await jobs.submit(.projectLeads, subject: subject, requestedBy: nil, id: nil, { job in
            guard try await provider.servedIfReady() != nil else {
                throw JobFailed("No index is served, so the projects' leads were kept as they were.")
            }
            var found = 0
            for (index, key) in keys.enumerated() {
                try await job.step("Finding a project's leads, \(index + 1) of \(keys.count)", fraction: Double(index) / Double(keys.count))
                do {
                    _ = try await self.compute(key, job: job)
                    found += 1
                } catch is JobCancelled {
                    throw JobCancelled()
                } catch {
                    // One project whose records cannot be read keeps its leads; the others go on.
                    continue
                }
            }
            let projects = keys.count == 1 ? "1 project" : "\(keys.count) projects"
            return found == keys.count ? "Found the leads of \(projects)" : "Found the leads of \(found) of \(projects)"
        }) else { return }
        // Each project's Refresh while it waits is this job, and Project Home says where it stands.
        for key in keys where queueing[key] == nil { latest[key] = job.id }
    }

    /// The newest computation queued for the project, as the queue holds it, or nil for none since the
    /// server started.
    func latestJob(_ project: String, of user: String) async -> Job? {
        guard let id = latest[Key(user: user, project: project)] else { return nil }
        return await jobs.job(id)
    }

    /// The tuning the newest Refresh of the project brought, if it brought one.
    private func tuning(_ key: Key) -> String? { tunings[key] }

    /// A computation of the project's leads, as `ProjectLeadsService.recompute` runs one: the seed gathered,
    /// each of its first forty seeds ranked, the rankings aggregated, and the leads kept. Its lines say what
    /// it does in the server's words, never what the project holds; a cancel stops it between two seeds.
    private func compute(_ key: Key, job: JobContext) async throws -> String? {
        try await Self.compute(key.project, of: key.user, browserWeights: tuning(key), job: job, store: store,
                               provider: provider, resources: resources, now: now)
    }

    static func compute(_ projectId: String, of user: String, browserWeights: String?, job: JobContext,
                        store: any UserDataStore, provider: ServedIndexProvider, resources: ServerResources,
                        now: @escaping @Sendable () -> Date) async throws -> String? {
        let (rows, assignments) = try await Blocking.run {
            (try store.researchRows(for: user, tables: ["projects", "collections", "collection_entries", "notes"]),
             try store.tagAssignments(of: user))
        }
        let project: ProjectExport
        let collections: [CollectionExport]
        let notes: [ResearchNoteExport]
        do {
            guard let found = try ResearchExport.records(rows, "projects", ResearchExport.project)
                .first(where: { $0.id.uuidString == projectId }) else {
                return "The project was deleted before its leads were computed"
            }
            project = found
            let entries = try ResearchExport.children(rows["collection_entries"], in: "collection_entries", of: "collection_id")
            collections = try ResearchExport.records(rows, "collections") { row in
                try ResearchExport.collection(row, entries: try ResearchExport.ordered(entries[try row.uuid("id")] ?? [],
                                                                                      in: "collection_entries") { try $0.int("sort_order") })
            }
            notes = try ResearchExport.records(rows, "notes") { try ResearchExport.note($0, links: [:]) }
        } catch let error as ResearchExportError {
            // Its words name the table, the row and the column, never what the record holds.
            throw JobFailed("A project's leads were kept as they were: \(error.description)")
        }
        let seed = ProjectLeadsSeed.keys(forProject: project, collections: collections, notes: notes, assignments: assignments)
        guard !seed.isEmpty else {
            // Nothing to rank from: the leads on show go, the dismissed ones stay, as the app's do.
            let kept = try await Blocking.run { try store.clearVisibleProjectLeads(ofProject: project.id.uuidString, for: user) }
            return kept ? "A project with no documents to rank from: its leads were cleared" : "The project was deleted before its leads were computed"
        }
        guard let served = try await provider.servedIfReady() else {
            throw JobFailed("No index is served, so the project's leads were kept as they were.")
        }
        let subjects = try await Blocking.run { resources.documentSubjectIndex }
        let weights = ProjectLeadsSeed.effectiveWeights(projectRaw: project.leadAxisWeights, browserRaw: browserWeights)
        let ranked = Array(seed.prefix(ProjectLeadsSeed.seedCap))
        var perSeed: [(seed: String, related: [(key: String, score: Double)])] = []
        var records: [String: CandidateRecord] = [:]
        for (index, seedKey) in ranked.enumerated() {
            // One line for the whole ranking, so that the job's row is written once a second at most.
            try await job.checkpoint()
            await job.progress("Ranking the documents related to the project's documents", fraction: Double(index) / Double(ranked.count))
            guard let anchor = DocumentKey(compositeString: seedKey) else { continue }
            let result = await rank(anchor, weights: weights, served: served, resources: resources, subjects: subjects)
            perSeed.append((seed: seedKey, related: result.rows.map { ($0.key.compositeString, $0.totalScore) }))
            for row in result.rows where records[row.key.compositeString] == nil {
                records[row.key.compositeString] = row.record
            }
        }
        try await job.checkpoint()
        // The leads dismissed as they stand now, which keep their places hidden, and the next best fills.
        let leadRows = try await Blocking.run { try store.researchRows(for: user, tables: ["project_leads"]) }
        let dismissed: Set<String>
        do {
            dismissed = Set(try ResearchExport.records(leadRows, "project_leads", ResearchExport.lead)
                .filter { $0.projectId == project.id && $0.dismissed }
                .map { "\($0.volumeId)/\($0.documentId)" })
        } catch let error as ResearchExportError {
            throw JobFailed("A project's leads were kept as they were: \(error.description)")
        }
        let candidates = ProjectLeadsAggregator.aggregate(perSeedRelated: perSeed, seedKeys: Set(seed),
                                                          dismissedKeys: dismissed, limit: ProjectLeadsSeed.leadLimit)
        let writes = candidates.compactMap { candidate -> ProjectLeadWrite? in
            guard let key = DocumentKey(compositeString: candidate.key) else { return nil }
            return ProjectLeadWrite(
                volumeId: key.volumeId, documentId: key.documentId, aggregateScore: candidate.aggregateScore,
                contributingSeedKeys: candidate.contributingSeedKeys,
                record: records[candidate.key].map {
                    .init(header: $0.header, documentNumber: $0.documentNumber, isEditorialNote: $0.isEditorialNote)
                })
        }
        let time = now()
        let kept = try await Blocking.run { try store.applyProjectLeads(writes, toProject: project.id.uuidString, for: user, at: time) }
        guard kept else { return "The project was deleted before its leads were kept" }
        let shown = candidates.count - candidates.filter { dismissed.contains($0.key) }.count
        return "Ranked from \(ranked.count == 1 ? "1 document" : "\(ranked.count) documents") of a project of \(user)'s: \(shown == 1 ? "1 lead" : "\(shown) leads")"
    }

    /// One seed's related documents, as the service ranks them: no year, every volume, thirty, and no lines.
    @MainActor
    static func rank(_ anchor: DocumentKey, weights: AxisWeights, served: ServedIndex, resources: ServerResources,
                     subjects: DocumentSubjectIndex?) async -> RelatedDocumentsResult {
        await RelatedDocumentsEngine.rank(
            anchor: anchor, anchorYear: nil, weights: weights, scopeVolumeIds: nil,
            limit: ProjectLeadsSeed.perSeedRelatedLimit, includeSnippets: false, includeOffIndexLeads: false,
            dependencies: RelatedDocumentsRoutes.dependencies(served: served, resources: resources, subjects: subjects))
    }
}

/// An export made the served index: every project's leads are computed again over it, in one job queued
/// behind the import's, as the leads a project had were ranked over the index it replaced. Queued off the
/// import's step, so that making the index live waits for none of it.
struct LeadsAfterIndexImport: ImportObserver {
    let leads: ProjectLeadsQueue

    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) async {
        // The import's last step: the computation queued now runs once its job has ended.
        guard step == .openingIndex else { return }
        Task { [leads] in await leads.refreshAfterImport(of: nil) }
    }
}

/// Suggested Next's Refresh, and where a computation stands.
struct LeadsRefresh: Codable, Equatable, Sendable, ResponseEncodable {
    /// The computation's job, the one an import queued for every project concerned included.
    var id: String
    /// `queued`, `running`, `succeeded`, `failed` or `cancelled`.
    var state: String
    /// When it ended.
    var finishedAt: String?
    /// Why it failed, in the server's words.
    var error: String?

    init(_ job: Job) {
        id = job.id
        state = job.state.rawValue
        finishedAt = job.finishedAt.map(UserStoreDate.text)
        error = job.state == .failed ? job.error : nil
    }
}

enum ProjectLeadsRoutes {
    private struct Refresh: Decodable {
        /// The browser's tuning of Related Documents, which the project's own replaces.
        var weights: String?
    }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, leads: ProjectLeadsQueue) {
        let store = services.store
        // Suggested Next's Refresh: the project's leads computed again, as a job of the server's queue.
        me.post("projects/:projectId/leads/refresh") { request, context -> EditedResponse<LeadsRefresh> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let projectId = try context.parameters.require("projectId")
            let body = try await JSONBody.decode(Refresh.self, from: request, fields: ["weights"])
            if let weights = body.weights {
                do {
                    _ = try RelatedDocumentsRoutes.requestedWeights(weights)
                } catch let problem as APIProblem {
                    throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: problem.detail)
                }
            }
            let project = try await ProjectRoutes.project(projectId, of: user.id, in: store)
            // The leads are ranked over the served index, and kept as they are while none is served.
            guard try await leads.provider.servedIfReady() != nil else {
                throw APIProblem(.serviceUnavailable, code: "INDEX_NOT_READY",
                                 detail: "No index is served, so Suggested Next cannot be computed: its leads are kept as they are.")
            }
            let job: Job
            do {
                job = try await leads.refresh(project.id.uuidString, of: user.id, browserWeights: body.weights)
            } catch {
                throw APIProblem(.serviceUnavailable, code: "LEADS_NOT_QUEUED",
                                 detail: "Suggested Next could not be computed, since the server could not keep its job: try again in a moment.")
            }
            return EditedResponse(status: .accepted, headers: [.cacheControl: "no-store"], response: LeadsRefresh(job))
        }
    }
}
