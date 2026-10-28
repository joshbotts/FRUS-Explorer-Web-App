// /api/v1/me/saved-searches (PLAN's S17e): the user's saved searches, each keeping its search's
// `SearchParameters` whole, as the Mac's `SavedSearch` archives them in `parametersData`, beside the
// columns its `init(name:parameters:)` writes from them (`MacImport.savedSearch`, which ImportParityTests
// holds to the app's source), and read back as `SavedSearch.searchParameters` reads them
// (`ResearchExport.savedSearch`). Listed newest first, as the Saved Searches sheet lists them; renamed
// and deleted as the sheet does; recalled, which stamps the watermark from the saved search's own
// count, as `SavedSearchFreshnessEvaluator.recordRun(of:service:indexedVolumeCount:context:)` does;
// and each evaluated for "+N since last run" by the kit's rules (`SavedSearchFreshness`), writing the
// backfill an evaluation may give, as `newResultCount(for:service:context:)` writes it.

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird

/// One of the user's saved searches.
public struct SavedSearch: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    /// As it was saved or renamed: the sheet saves a name trimmed and never empty, and its Rename takes
    /// the text as given.
    public var name: String
    /// The search box's words, which the sheet shows under the name (`SavedSearch.queryText`).
    public var queryText: String
    /// The search a recall runs, as the query fields `GET /api/v1/search` reads them: the saved
    /// parameters with none of their own document gates (`SearchParameters.runningInside(workingCorpus:)`),
    /// as the Mac's window recalls one inside the corpus it has applied and under no other gate. A
    /// browser that has a corpus applied adds its `workingCorpusId`.
    public var search: [String: [String]]
    /// What the saved search sets that the API does not take, so that a recall here runs without it,
    /// by the parameters' names: `booleanMode`, `personRef`, `projectId` and `subjectRef`, which a
    /// Mac's saved search can carry. Its count, and so its badge, is of the whole search.
    public var notRecalled: [String]
    /// The watermark (`SavedSearch.freshness`): when it was last run, what it matched then, and how
    /// many volumes the index that ran it held. Absent for one never run.
    public var lastRunAt: String?
    public var matchCountAtLastRun: Int?
    public var indexedVolumeCountAtLastRun: Int?
    public var createdAt: String?
    public var lastModified: String?

    init(_ search: SavedSearchExport) {
        id = search.id.uuidString
        name = search.name
        queryText = search.parameters.keywords ?? ""
        self.search = SearchRequest.formFields(search.parameters.runningInside(workingCorpus: nil))
        notRecalled = Self.notRecalled(search.parameters)
        lastRunAt = search.lastRunAt.map(UserStoreDate.text)
        matchCountAtLastRun = search.matchCountAtLastRun
        indexedVolumeCountAtLastRun = search.indexedVolumeCountAtLastRun
        createdAt = search.createdAt.map(UserStoreDate.text)
        lastModified = search.lastModified.map(UserStoreDate.text)
    }

    /// The fields of `parameters` a recall through the API leaves out.
    static func notRecalled(_ parameters: SearchParameters) -> [String] {
        var names: [String] = []
        if parameters.booleanMode == .or { names.append("booleanMode") }
        if !(parameters.personRef ?? "").isEmpty { names.append("personRef") }
        if parameters.projectId != nil { names.append("projectId") }
        if parameters.subjectRef != nil { names.append("subjectRef") }
        return names
    }
}

/// The user's saved searches, the most recently made first.
public struct SavedSearchList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [SavedSearch]
}

/// What one evaluation of a saved search's watermark shows (`SavedSearchFreshness.Evaluation`).
public struct SavedSearchFreshnessResult: Codable, Equatable, Sendable, ResponseEncodable {
    /// "+N since last run": how many results it has gained, absent for no badge (never run, no count,
    /// nothing new, fewer than before, or a baseline backfilled by this evaluation).
    public var newResults: Int?
    /// The saved search as it stands after the evaluation, its backfilled baseline included.
    public var savedSearch: SavedSearch
}

enum SavedSearchRoutes {
    struct Save: Decodable {
        let name: String
        /// The search, as the query string `GET /api/v1/search` reads.
        let search: String
    }

    struct Rename: Decodable { let name: String }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, provider: ServedIndexProvider) {
        let store = services.store
        let now = services.now

        me.get("saved-searches") { request, context -> SavedSearchList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let searches = try await savedSearches(of: user.id, in: store)
            return SavedSearchList(total: searches.count, items: searches.map(SavedSearch.init))
        }
        // Save this search: `SavedSearch.init(name:parameters:)` of the search as it runs, its working
        // corpus's documents in its gate, as the Mac's window saves its parameters with the corpus it
        // has applied composed into them.
        me.post("saved-searches") { request, context -> EditedResponse<SavedSearch> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Save.self, from: request, fields: ["name", "search"])
            let name = try savedName(body.name)
            let search = try SearchRequest(formEncoded: body.search)
            _ = try await SearchUsers.user(user.id, searching: search.parameters, in: store)
            var parameters = search.parameters
            if search.workingCorpusId != nil {
                parameters = try await SearchUsers.inside(search.workingCorpusId, parameters, for: user.id, in: store,
                                                          served: try await provider.served())
            }
            let time = UserStoreDate.rounded(now())
            let saved = SavedSearchExport(id: UUID(), name: name, parameters: parameters, createdAt: time, lastModified: time)
            try await Blocking.run { try store.addSearchSet(.savedSearches, MacImport.savedSearch(saved).values, for: user.id) }
            let location = context.basePath.prefixing("/api/v1/me/saved-searches/\(saved.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location], response: SavedSearch(saved))
        }
        me.get("saved-searches/:searchId") { request, context -> SavedSearch in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            return SavedSearch(try await savedSearch(try context.parameters.require("searchId"), of: user.id, in: store))
        }
        // Rename, as the sheet's alert renames one: the name as given.
        me.patch("saved-searches/:searchId") { request, context -> SavedSearch in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("searchId")
            let body = try await JSONBody.decode(Rename.self, from: request, fields: ["name"])
            var saved = try await savedSearch(id, of: user.id, in: store)
            saved.name = body.name
            saved.lastModified = UserStoreDate.rounded(now())
            return try await write(saved, columns: ["name", "last_modified"], for: user.id, in: store)
        }
        me.delete("saved-searches/:searchId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("searchId")
            guard try await Blocking.run({ try store.deleteSearchSet(.savedSearches, id: id, for: user.id) }) else { throw notFound(id) }
            return Response(status: .noContent)
        }
        // A recall's stamp: now, the saved search's own count, and the volumes the index holds,
        // `SavedSearchFreshness.run(at:matchCount:indexedVolumeCount:)`. A count that fails stamps the
        // time with no baseline, which the next evaluation backfills.
        me.post("saved-searches/:searchId/run") { request, context -> SavedSearch in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("searchId")
            var saved = try await savedSearch(id, of: user.id, in: store)
            let served = try await provider.served()
            // Counted to its end, as the stamp is the recall's and the browser goes on to the search.
            let count = try? await count(saved.parameters, for: user.id, in: store, served: served, context: nil)
            let mark = SavedSearchFreshness.run(at: UserStoreDate.rounded(now()), matchCount: count,
                                                indexedVolumeCount: served.indexedVolumeIds.count)
            saved.lastRunAt = mark.lastRunAt
            saved.matchCountAtLastRun = mark.matchCountAtLastRun
            saved.indexedVolumeCountAtLastRun = mark.indexedVolumeCountAtLastRun
            return try await write(saved, columns: ["freshness_data"], for: user.id, in: store)
        }
        // "+N since last run": the watermark against the saved search's count now, which the sheet
        // asks for each of its rows in turn. A change, since the baseline it backfills is written.
        me.post("saved-searches/:searchId/freshness") { request, context -> SavedSearchFreshnessResult in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("searchId")
            var saved = try await savedSearch(id, of: user.id, in: store)
            let mark = SavedSearchFreshness(lastRunAt: saved.lastRunAt, matchCountAtLastRun: saved.matchCountAtLastRun,
                                            indexedVolumeCountAtLastRun: saved.indexedVolumeCountAtLastRun)
            // A baseline that never existed cannot have grown, so nothing is counted for one never run.
            guard mark.hasRun else { return SavedSearchFreshnessResult(newResults: nil, savedSearch: SavedSearch(saved)) }
            let served = try await provider.served()
            let current = try? await count(saved.parameters, for: user.id, in: store, served: served, context: context)
            switch mark.evaluation(currentCount: current) {
            case .noBadge:
                return SavedSearchFreshnessResult(newResults: nil, savedSearch: SavedSearch(saved))
            case .newResults(let count):
                return SavedSearchFreshnessResult(newResults: count, savedSearch: SavedSearch(saved))
            case .backfill(let backfilled):
                saved.matchCountAtLastRun = backfilled.matchCountAtLastRun
                let written = try await write(saved, columns: ["freshness_data"], for: user.id, in: store)
                return SavedSearchFreshnessResult(newResults: nil, savedSearch: written)
            }
        }
    }

    /// The name a search is saved under: `SaveSearchRequest.savedName(from:)`, the text without the
    /// spaces around it, and never empty.
    static func savedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "name: a saved search's name, trimmed of spaces, cannot be empty.")
        }
        return trimmed
    }

    /// The exact count of `parameters` as the user's search, `SearchService.searchCount`, kept as a
    /// search's count is kept. A tag of theirs the parameters name that they no longer have matches
    /// nothing, as the Mac's re-resolution of a stale id matches nothing, where a search through the
    /// API refuses it.
    /// With `context`, the count stops when its client goes, as a search's does: the sheet's pass over
    /// its rows stops when it closes, as the Mac's task is cancelled.
    static func count(_ parameters: SearchParameters, for user: String, in store: any UserDataStore, served: ServedIndex,
                      context: APIRequestContext?) async throws -> Int {
        let mark = try await Blocking.run { try store.searchMark() }
        let scoped = try served.search(for: SearchUser(id: user, mark: mark))
        do {
            guard let context else { return try await served.recent.count(of: parameters, in: scoped) }
            return try await context.whileClientConnected { try await served.recent.count(of: parameters, in: scoped) }
        } catch let error as FTS5Error {
            throw SearchRoutes.refusal(error)
        }
    }

    /// Writes the columns `columns` of `saved`, as the import writes them, and answers it as stored.
    static func write(_ saved: SavedSearchExport, columns: Set<String>, for user: String,
                      in store: any UserDataStore) async throws -> SavedSearch {
        let id = saved.id.uuidString
        let values = MacImport.savedSearch(saved).values.filter { columns.contains($0.key) }
        guard let row = try await Blocking.run({ try store.updateSearchSet(.savedSearches, id: id, values, for: user) }) else {
            throw notFound(id)
        }
        return SavedSearch(try read(row))
    }

    /// The user's saved searches, the most recently made first, as `@Query(sort: \SavedSearch.createdAt,
    /// order: .reverse)` lists them, one with no time last; a tie in the store's order.
    static func savedSearches(of user: String, in store: any UserDataStore) async throws -> [SavedSearchExport] {
        let rows = try await Blocking.run { try store.searchSets(.savedSearches, of: user) }
        let searches = try rows.map(read)
        return searches.enumerated().sorted { a, b in
            let (x, y) = (a.element.createdAt ?? .distantPast, b.element.createdAt ?? .distantPast)
            return x != y ? x > y : a.offset < b.offset
        }.map(\.element)
    }

    static func savedSearch(_ id: String, of user: String, in store: any UserDataStore) async throws -> SavedSearchExport {
        guard let row = try await Blocking.run({ try store.searchSet(.savedSearches, id: id, of: user) }) else { throw notFound(id) }
        return try read(row)
    }

    static func read(_ row: ExportRow) throws -> SavedSearchExport {
        do {
            return try ResearchExport.savedSearch(ResearchExport.Fields("saved_searches", row))
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The saved search could not be read: \(error.description)")
        }
    }

    static func notFound(_ id: String) -> APIProblem {
        APIProblem(.notFound, code: "SAVED_SEARCH_NOT_FOUND", detail: "You have no saved search with the id \(id).")
    }
}
