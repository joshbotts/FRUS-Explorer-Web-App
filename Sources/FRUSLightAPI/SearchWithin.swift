// Search Within These Results, and the fallback (PLAN's S27e): the app's #1577, which layers the two engines, over the
// kit's held list and composer (`SearchLayering.swift`, FRUS-Explorer#1982, S27a) and its Meaning engine's two rankings of
// a held list (`SemanticSearchBackend.rerank`, `rankWholeMatch`), with S27d's route, encoder and kept runs.
//
// A list is held as the browser app names it, by the search that found it (`within`): a search by meaning's closest
// matches, or a keyword search's results or a browse's, with the rows Checklist Mode hid when it was held. The served index
// keeps it for its user (`HeldList`), the kit's `PinnedResultBase` built as the app's view models build one, so that its
// row's sentences, its way back and the layers over it ask its search nothing again while it is kept. The app freezes the
// rows it holds, and lets go of them once its index is rebuilt; a server builds the list again from its search once it is
// no longer kept, after any write to the store or on a new index, so the row says the digest of its members, and a request
// that names it is refused when the list built again holds other members (`HELD_LIST_CHANGED`), for the browser app to
// let go of it as the app does. `GET /api/v1/search/held` says what the row says of it. `GET /api/v1/search/within` runs the other engine inside it, from the field's words or question:
// words found in a Meaning list, the kit's `LayeredResultComposer.wordsInMatches` over a keyword search gated to its
// members; or a keyword list or a browse ranked by a question, the kit's `rerank` of its members, or for a list cut at its
// ceiling the kit's `rankWholeMatch` of its whole match, inside the filters chosen since. A layer's rows are paged, ordered
// and checklisted as a keyword search's kept results are, from the run the served index keeps, and a layer its client
// abandons stops, as a search by meaning does. What the results header, the empty state and a capture say of a layer is the
// app's `ResultSetScope` for the two layered routes, mirrored (`LayerScope`), with `SearchLayerEmptyState`'s and
// `SearchLayerCopy`'s sentences and `SearchLayerSwap`'s rule; the kit's sentences that speak of a device are said in a
// server's words (`MeaningSearchWords`).
//
// `GET /api/v1/search/fallback` is the app's Semantic matches (experimental) under a keyword search that found nothing
// (`SemanticSearchFallbackView`): the kit's searcher's nearest ten across the whole series, filter-blind, each a document
// the reader opens where the served index holds it and its volume's title otherwise, with the kit's caption
// (`SemanticFallbackCopy`), whose sentence says the filters are not applied.

import Crypto
import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird
import SemanticVectorsKit

// MARK: - What the API answers

/// A held list, as the row that names it says it (the app's `SearchLayerBaseRow` over the kit's `PinnedResultBase`): its
/// kind, its words, its counts and every sentence the row, its way back and a capture inside it say, the kit's, in this
/// server's words where they speak of a device.
public struct HeldListSummary: Codable, Equatable, Sendable, ResponseEncodable {
    /// The way a layer over it runs (`SearchLayerDirection`): `wordsInMatches` over a Meaning list, `rankByMeaning` over a
    /// keyword list or a browse.
    public var direction: String
    /// `meaning`, `keywords` or `browse` (`PinnedResultBase.Kind`).
    public var kind: String
    /// The words or question the list was found by, trimmed; empty for a browse.
    public var query: String
    /// The words a keyword list with no typed words was found by, a phrase or a prefix (`describedQuery`).
    public var describedQuery: String?
    /// Every row the list loaded, the rows a layer runs inside (Checklist Mode's hidden left out), those it hid, and a
    /// Meaning list's hits in volumes this server does not serve, which have no row to search.
    public var rows: Int
    public var members: Int
    public var hiddenByChecklist: Int
    public var notDownloaded: Int
    /// Whether its fetch stopped short of its match, and whether a question ranks its whole match (`ranksWholeMatch`).
    public var wasCut: Bool
    public var ranksWholeMatch: Bool
    public var wholeMatchCount: Int?
    /// "100 closest matches to “how did the embassy…”", the set as the row says it after "Within".
    public var setDescription: String
    /// "Within 100 closest matches to “…”", the row's sentence, and what a screen reader says of it.
    public var rowDescription: String
    public var accessibilityLabel: String
    /// The row's second line: what the list held that a layer leaves out.
    public var leftOutDescription: String?
    /// "Back to the 100 Matches", the empty layer's way back.
    public var backTitle: String
    /// The list as a capture inside a layer names it.
    public var captureLabel: String?
    /// The command that holds such a list, and the field's prompt while it is held.
    public var startTitle: String
    public var fieldPrompt: String
    /// The `base=` part a layer's trail row carries.
    public var signaturePart: String
    /// A digest of its members' keys in their order, which a request names the list by as `members` inside `within`, so
    /// that a list built again with other members is refused rather than searched within.
    public var memberDigest: String
}

/// A page of a layer's rows, a keyword search's page in shape, and what the app says of the layer.
public struct LayeredSearchResult: Codable, Equatable, Sendable, ResponseEncodable {
    /// The rows the layer listed, after the filters; Checklist Mode's hidden rows count here, as in a keyword search's total.
    public var total: Int
    /// Always `exact`: a list's own length.
    public var countBasis: String
    public var limit: Int
    public var offset: Int
    /// How many rows the held list holds at most, the ceiling of the fetch it came from.
    public var retainedLimit: Int
    public var sort: String
    public var sortChoices: [Choice]
    /// The page's rows: words found keep their keyword snippets and gain the list's chips; a ranking's rows keep theirs.
    public var items: [SearchItem]
    public var hidden: Int?
    public var coverage: Coverage
    public var layer: LayerSummary
}

/// What the app says of a layer's run beside its rows.
public struct LayerSummary: Codable, Equatable, Sendable {
    /// `wordsInMatches` or `rankByMeaning`.
    public var direction: String
    /// The layer's words or question, trimmed.
    public var query: String
    public var route: LayerRoute
    /// The results header's sentence (`ResultSetScope.headerDescription` for the layered routes): "7 of your 100 closest
    /// matches contain these words", "212 results, closest first", "Closest 1,000 of 35,275 results".
    public var header: String
    /// Whether filters chosen since the list was held narrowed a layer of words too, which the header says.
    public var filtersNarrowed: Bool
    /// Where a ranking's rows it could not rank begin in the list as shown, and the line over them; absent under a date
    /// order and where every row was ranked.
    public var unrankedTail: UnrankedTail?
    /// What a layer that listed no row shows in their place (`SearchLayerEmptyState`).
    public var empty: LayerEmpty?
    /// A ranking's account, as the Meaning strip says it: the kit's sentences, in this server's words.
    public var strip: [String]?
    public var disclosure: MeaningDisclosure?
    /// The held list and this layer swapped (`SearchLayerSwap`), where both have words of their own.
    public var swap: LayerSwap?
    /// What the trail records of the layer: its rendered expression and its scope signature, the list's `base=` part last.
    public var renderedExpression: String?
    public var signature: String
    /// The held list, as the layer left it: a ranking of a whole match counts the match once it has read it.
    public var base: HeldListSummary
}

/// The route a layer's rows came from (`ExecutedSearchRoute`).
public struct LayerRoute: Codable, Equatable, Sendable {
    /// `wordsInMatches` or `rankedByMeaning`.
    public var kind: String
    /// Words in matches: the held Meaning list's size.
    public var base: Int?
    /// A ranking: the rows it could not rank, listed last.
    public var unranked: Int?
    /// A ranking of a whole match (`WholeMatchRanking`).
    public var wholeMatch: WholeMatch?
}

/// What a question ranked when the list it ranked was cut at its ceiling (the kit's `WholeMatchRanking`).
public struct WholeMatch: Codable, Equatable, Sendable {
    public var size: Int
    public var filteredOut: Int
    public var notRanked: Int
    public var closest: Int
    public var isCut: Bool
}

/// The first row of a ranking it could not rank, as the list is shown, `volumeId/documentId`, how many follow it, and the
/// line over them (`SearchLayerCopy.unrankedHeader`).
public struct UnrankedTail: Codable, Equatable, Sendable {
    public var firstKey: String
    public var count: Int
    public var line: String
}

/// What a layer that found nothing says, and its ways on (`SearchLayerEmptyState`).
public struct LayerEmpty: Codable, Equatable, Sendable {
    public var statement: String
    /// "Search the Whole Library for These Words", for words found nowhere in a Meaning list.
    public var searchLibraryTitle: String?
    public var backTitle: String
}

/// The held list and the layer on screen, swapped (`SearchLayerSwap`): the layer's words or question become a list of
/// their own, and the list's become the search inside it.
public struct LayerSwap: Codable, Equatable, Sendable {
    /// The way the search inside the new list runs.
    public var direction: String
    /// The words or question the new list is found by, and those searched inside it.
    public var listQuery: String
    public var layerQuery: String
    /// What Swap will do, with both searches named (`SearchLayerCopy.swapHelp`).
    public var help: String
}

/// The app's Semantic matches (experimental) under a keyword search that found nothing: the nearest by meaning across the
/// whole series, filter-blind.
public struct MeaningFallback: Codable, Equatable, Sendable, ResponseEncodable {
    public var question: String
    /// The kit's caption (`SemanticFallbackCopy.caption`), in this server's words.
    public var caption: String
    public var hits: [FallbackHit]
    /// For a run with no hit, the sentence under "No semantic matches yet".
    public var emptyStatement: String?
    public var unscoredCandidates: Int
    public var unscoredVolumes: Int
    /// The volumes whose match file the searcher asked for, which this server lacks: none while the image holds them all.
    public var missingShards: [String]
}

/// A fallback's hit: a document the served index holds, which opens, or a volume's document it does not.
public struct FallbackHit: Codable, Equatable, Sendable {
    public var volumeId: String
    public var documentId: String
    public var score: Double
    /// The kit's chip, "Semantic match · 64%".
    public var chip: String
    /// Whether the served index holds the document, so that it opens in the reader.
    public var opens: Bool
    /// For one that opens: what a row names it by, its dateline, its label beside its volume.
    public var displayTitle: String?
    public var dateline: String?
    public var documentLabel: String?
    public var isEditorialNote: Bool
    /// The volume's title in the catalogue, or its id.
    public var volumeTitle: String
}

// MARK: - The held list

/// The list a request names as held, `within`: the search that found it, as `GET /api/v1/search` reads its fields, with
/// `by=meaning` for a search by meaning's, `label` for the name a browse is shown by, `reviewed`, the rows Checklist Mode hid
/// when it was held, which no layer searches, and `members`, the digest of its members the row gave, once it is known.
struct HeldListRequest: Sendable {
    let search: SearchRequest
    let byMeaning: Bool
    let label: String?
    let members: String?

    /// The fields `within` takes beside a search's.
    static let fields: Set<String> = ["by", "label", "members"]

    init(_ value: String?) throws(APIProblem) {
        guard let value, !value.isEmpty else {
            throw APIProblem.invalidParameter("within", "names the list held, as the query string of the search that found it")
        }
        let form: FormQuery
        do {
            form = try FormQuery(value)
            search = try SearchRequest(form: form, alsoTaking: Self.fields)
        } catch {
            throw APIProblem.invalidParameter("within", error.detail)
        }
        switch try form.single("by") {
        case nil, "keywords": byMeaning = false
        case "meaning": byMeaning = true
        case let other?: throw APIProblem.invalidParameter("within", "by: keywords or meaning, not \(other)")
        }
        label = try form.single("label").flatMap { $0.isEmpty ? nil : $0 }
        members = try form.single("members").flatMap { $0.isEmpty ? nil : $0 }
    }
}

/// A held list as the served index keeps it for its user: the kit's `PinnedResultBase`, and what its key is.
struct HeldList: Sendable {
    var base: PinnedResultBase
    /// The parameters its search ran with, inside the corpus it names.
    let parameters: SearchParameters
    let key: String
}

/// A layer's run, kept by the served index for its user: the rows in the layer's order, and what the app records of them.
struct LayerRun: Sendable {
    let query: String
    let rows: [SearchResult]
    let route: ExecutedSearchRoute
    /// The held list as the layer left it.
    let base: PinnedResultBase
    let filtersNarrowed: Bool
    /// A ranking's disclosure.
    let disclosure: SemanticSearchBackend.Disclosure?
    let renderedExpression: String?
    /// The trail's signature (`SearchScopeSignature.layered(_:parameters:basePart:)`).
    let signature: String
    /// The parameters the layer ran with, the held list joined to their gate, and without it.
    let gated: SearchParameters
    let outside: SearchParameters
    /// The ceiling its rows were fetched under, and the total a ranking keeps of its list.
    let fetchLimit: Int
    let totalMatchCount: Int?
    let missingShards: [String]
}

/// A fallback's run, which asks nothing of its user: the searcher's results and the hits resolved.
struct FallbackRun: Sendable {
    let results: SemanticQuerySearcher.Results
    let hits: [FallbackHit]
    let missingShards: [String]
}

/// What the served index computed lately, by a key that says what was asked, the least recently asked going past
/// `capacity`: S27e's held lists, layers and fallbacks, each kept once it is finished.
actor KeptValues<Value: Sendable> {
    private var kept: [String: Value] = [:]
    private var recency: [String] = []
    let capacity: Int

    init(capacity: Int = 8) {
        self.capacity = max(1, capacity)
    }

    func value(for key: String) -> Value? {
        guard let value = kept[key] else { return nil }
        recency.removeAll { $0 == key }
        recency.append(key)
        return value
    }

    func keep(_ value: Value, for key: String) {
        kept[key] = value
        recency.removeAll { $0 == key }
        recency.append(key)
        while recency.count > capacity {
            kept[recency.removeFirst()] = nil
        }
    }

    /// How many are kept, for the tests.
    var count: Int { kept.count }
}

/// Who a request's searches are made as: the user each runs as, its tags checked, and its parameters inside the corpus it
/// names. A route's comes from the request; the trail's, a capture's and My Tags' from the user's id and store.
struct LayerUser: Sendable {
    let user: @Sendable (SearchParameters) async throws -> SearchUser?
    let inside: @Sendable (String?, SearchParameters, SearchUser?, ServedIndex) async throws -> SearchParameters

    static func of(_ request: Request, context: APIRequestContext, users: SearchUsers) -> LayerUser {
        LayerUser(user: { try await users.user(searching: $0, for: request, context: context) },
                  inside: { try await users.inside($0, $1, for: $2, served: $3) })
    }

    static func of(_ id: String, in store: any UserDataStore) -> LayerUser {
        LayerUser(user: { try await SearchUsers.user(id, searching: $0, in: store) },
                  inside: { corpus, parameters, _, served in
                      try await SearchUsers.inside(corpus, parameters, for: id, in: store, served: served)
                  })
    }
}

enum SearchWithinRoutes {
    /// `GET` and `POST /api/v1/search/within` (a layer), `/api/v1/search/held` (a held list's row) and
    /// `GET /api/v1/search/fallback`.
    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources,
                    users: SearchUsers, engine: MeaningSearchRoutes.MeaningEngine) {
        router.get("/api/v1/search/within") { request, context -> LayeredSearchResult in
            try await layer(try FormQuery(request.uri.query), searcher: .of(request, context: context, users: users),
                            provider: provider, resources: resources, engine: engine, context: context)
        }
        // The same, with its query in the body, for a list whose Checklist Mode hid more rows than an address holds.
        router.post("/api/v1/search/within") { request, context -> LayeredSearchResult in
            let form = try await postedForm(request)
            return try await layer(form, searcher: .of(request, context: context, users: users), provider: provider,
                                   resources: resources, engine: engine, context: context)
        }
        router.get("/api/v1/search/held") { request, context -> HeldListSummary in
            try await held(try FormQuery(request.uri.query), searcher: .of(request, context: context, users: users),
                           provider: provider, resources: resources, engine: engine, context: context)
        }
        router.post("/api/v1/search/held") { request, context -> HeldListSummary in
            let form = try await postedForm(request)
            return try await held(form, searcher: .of(request, context: context, users: users), provider: provider,
                                  resources: resources, engine: engine, context: context)
        }
        router.get("/api/v1/search/fallback") { request, context -> MeaningFallback in
            try await fallback(try FormQuery(request.uri.query), provider: provider, resources: resources, engine: engine,
                               context: context)
        }
    }

    /// A posted form, as `POST /api/v1/search` reads one.
    static func postedForm(_ request: Request) async throws -> FormQuery {
        let body = try await request.body.collect(upTo: 2 * SearchRoutes.postedSearchLimit)
        return try FormQuery(body.readableBytes > 0 ? String(buffer: body) : request.uri.query)
    }

    /// What the row of the list `form` holds says of it.
    static func held(_ form: FormQuery, searcher: LayerUser, provider: ServedIndexProvider, resources: ServerResources,
                     engine: MeaningSearchRoutes.MeaningEngine, context: APIRequestContext) async throws -> HeldListSummary {
        try form.refuseUnknown(["within"])
        let asked = try HeldListRequest(try form.single("within"))
        let served = try await provider.served()
        let list = try await context.whileClientConnected {
            try await heldList(asked, searcher: searcher, served: served, resources: resources, engine: engine)
        }
        return summary(list.base)
    }

    /// A page of the layer `form` says: its words or question, the filters and the corpus in force now, its page, order and
    /// Checklist Mode's hidden rows, inside the list `within` names.
    static func layer(_ form: FormQuery, searcher: LayerUser, provider: ServedIndexProvider, resources: ServerResources,
                      engine: MeaningSearchRoutes.MeaningEngine, context: APIRequestContext) async throws -> LayeredSearchResult {
        var asked = try SearchRequest(form: form, alsoTaking: ["within"])
        let within = try HeldListRequest(try form.single("within"))
        let text = (asked.parameters.keywords ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw APIProblem(.badRequest, code: "QUERY_MISSING",
                             detail: "A search within a held list runs on words or a question, and keywords holds none.")
        }
        let served = try await provider.served()
        let user = try await searcher.user(asked.parameters)
        asked.parameters = try await searcher.inside(asked.workingCorpusId, asked.parameters, user, served)
        let scoped = try served.search(for: user)
        let outside = asked.parameters
        let run = try await context.whileClientConnected {
            let list = try await heldList(within, searcher: searcher, served: served, resources: resources, engine: engine)
            return try await ran(text, outside: outside, list: list, scoped: scoped, served: served, engine: engine,
                                 resources: resources)
        }
        return page(run, asked: asked, served: served, resources: resources)
    }

    /// The layer `asked` says inside the list `within` names, as the trail records it, a capture saves it and My Tags counts
    /// it: the one the served index keeps, or one made now.
    static func run(_ asked: SearchRequest, within: HeldListRequest, searcher: LayerUser, provider: ServedIndexProvider,
                    resources: ServerResources, engine: MeaningSearchRoutes.MeaningEngine) async throws -> LayerRun {
        let text = (asked.parameters.keywords ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw APIProblem(.badRequest, code: "QUERY_MISSING",
                             detail: "A search within a held list runs on words or a question, and keywords holds none.")
        }
        let served = try await provider.served()
        let user = try await searcher.user(asked.parameters)
        let outside = try await searcher.inside(asked.workingCorpusId, asked.parameters, user, served)
        let list = try await heldList(within, searcher: searcher, served: served, resources: resources, engine: engine)
        return try await ran(text, outside: outside, list: list, scoped: try served.search(for: user), served: served,
                             engine: engine, resources: resources)
    }

    /// The list `asked` names, for its user: the one the served index keeps, or the kit's `PinnedResultBase` built now from
    /// its search's rows, as the app's view models build one (`holdBase`), its search a search by meaning's run, which the
    /// served index keeps too, or a keyword search's rows up to the ceiling, with its exact count.
    static func heldList(_ asked: HeldListRequest, searcher: LayerUser, served: ServedIndex, resources: ServerResources,
                         engine: MeaningSearchRoutes.MeaningEngine) async throws -> HeldList {
        let user = try await searcher.user(asked.search.parameters)
        let parameters = try await searcher.inside(asked.search.workingCorpusId, asked.search.parameters, user, served)
        let scoped = try served.search(for: user)
        let words = (parameters.keywords ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let key = [scoped.key, asked.byMeaning ? "meaning" : "keywords", words, SearchRequest.signature(parameters),
                   digest(asked.search.reviewed), asked.label ?? "", String(engine.ceiling)].joined(separator: "\n")
        if let kept = await served.held.value(for: key) { return try unchanged(kept, asked) }
        let base: PinnedResultBase
        if asked.byMeaning {
            let question = try MeaningSearchRoutes.question(of: asked.search, engine: engine)
            let bundle = try await MeaningSearchRoutes.bundle(engine.vectors)
            let run = try await MeaningSearchRoutes.ran(question, parameters: parameters, scoped: scoped, served: served,
                                                        bundle: bundle, engine: engine, resources: resources)
            let outcome = run.outcome
            base = pinned(route: .meaning, query: words, rows: outcome.results, hidden: asked.search.reviewed,
                          notDownloaded: outcome.beyondLibrary.count, fetchLimit: SemanticSearchBackend.hitLimit,
                          totalMatchCount: nil, renderedExpression: run.renderedExpression, disclosure: outcome.disclosure,
                          beyondLibraryHits: outcome.beyondLibrary,
                          scope: .resultKeys(outcome.results.map { .init(volumeId: $0.volumeId, documentId: $0.documentId) }),
                          parameters: parameters, label: asked.label)
        } else {
            do {
                async let counted = served.recent.count(of: parameters, in: scoped)
                let rows = try await keywordRows(of: parameters, limit: engine.ceiling, scoped: scoped, served: served)
                // A count that fails leaves the list's total unknown, as the app's does, and the list is held all the same.
                let total = try? await counted
                try Task.checkCancellation()
                let expression = try? await scoped.service.matchExpressions(for: parameters).corpus
                base = pinned(route: .keywords, query: words, rows: rows, hidden: asked.search.reviewed, notDownloaded: 0,
                              fetchLimit: engine.ceiling, totalMatchCount: total, renderedExpression: expression,
                              disclosure: nil, beyondLibraryHits: [], scope: .match(parameters), parameters: parameters,
                              label: asked.label)
            } catch let error as FTS5Error {
                throw SearchRoutes.refusal(error)
            }
        }
        let list = HeldList(base: base, parameters: parameters, key: key)
        try Task.checkCancellation()
        await served.held.keep(list, for: key)
        return try unchanged(list, asked)
    }

    /// `list`, unless the request names the list by a digest of other members: the list was built again since, after a
    /// write or on a new index, and holds other rows than the ones searched within, which the browser app then lets go of.
    static func unchanged(_ list: HeldList, _ asked: HeldListRequest) throws -> HeldList {
        guard let named = asked.members, named != memberDigest(list.base) else { return list }
        throw APIProblem(.conflict, code: "HELD_LIST_CHANGED",
                         detail: "The list you were searching within holds other documents now, since its search was run again; search it again to hold it.")
    }

    /// The digest of `base`'s members' keys in their order, which the row says and a request names the list by.
    static func memberDigest(_ base: PinnedResultBase) -> String {
        SHA256.hash(data: Data(base.memberKeys.joined(separator: "\n").utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The rows a keyword search keeps of `parameters`, best first, up to `limit`: at the Mac's ceiling, the results the
    /// served index keeps for an order of the date (`RetainedResults`), else the kit's search cut there.
    static func keywordRows(of parameters: SearchParameters, limit: Int, scoped: ServedSearch, served: ServedIndex) async throws
        -> [SearchResult] {
        if limit == SearchRequest.retainedLimit { return try await served.retained.results(of: parameters, in: scoped) }
        return try await scoped.service.search(parameters: parameters, limit: limit, offset: 0)
    }

    /// The kit's held list of `rows`, as `SearchViewModel.holdBase` builds one: its members the rows Checklist Mode was not
    /// hiding, in the search's order; its kind, and the words a list with nothing typed is named by, the kit's rule; the
    /// filters its rows were found under, its document gate among them; and nothing set aside, which a server keeps none of.
    static func pinned(route: ExecutedSearchRoute, query: String, rows: [SearchResult], hidden: Set<String>, notDownloaded: Int,
                       fetchLimit: Int, totalMatchCount: Int?, renderedExpression: String?,
                       disclosure: SemanticSearchBackend.Disclosure?, beyondLibraryHits: [SemanticSearchBackend.BeyondLibraryHit],
                       scope: UserTagCountScope, parameters: SearchParameters, label: String?) -> PinnedResultBase {
        let members = PinnedResultBase.members(of: rows, shown: rows.filter { !hidden.contains($0.id) })
        let (kind, describedQuery) = PinnedResultBase.kind(route: route, query: query, ran: scope.ranParameters,
                                                           browseName: browseName(of: parameters, label: label))
        // Never nil: a held list is a search's, a keyword one or a Meaning one, never a layer's.
        let direction = SearchLayerDirection.starting(over: route) ?? .rankByMeaning
        return PinnedResultBase(direction: direction, kind: kind, query: query, rows: rows, members: members,
                                hiddenByChecklist: rows.count - members.count, notDownloaded: notDownloaded, route: route,
                                fetchLimit: fetchLimit, totalMatchCount: totalMatchCount, renderedExpression: renderedExpression,
                                disclosure: disclosure, beyondLibraryHits: beyondLibraryHits, userTagCountScope: scope,
                                setAside: nil, filterSignature: SearchScopeSignature.signature(for: parameters),
                                describedQuery: describedQuery)
    }

    /// What a browse with no words is of (the app's `PinnedResultBase.browseName(of:)`): the person its filter names, by
    /// the name the filter shows, then the subject, by the name the reader was shown, which the request gives, since the
    /// kit's subject vocabulary is internal; `nil` where it has neither.
    static func browseName(of parameters: SearchParameters, label: String?) -> String? {
        if parameters.personRollupId != nil, let name = parameters.personLabel, !name.isEmpty { return name }
        if parameters.subjectBucket != nil || parameters.subjectBucketKey != nil, let label, !label.isEmpty { return label }
        return nil
    }

    /// A short digest of a set of keys, for a key the served index keeps a held list by.
    static func digest(_ keys: Set<String>) -> String {
        guard !keys.isEmpty else { return "" }
        let joined = keys.sorted().joined(separator: "\n")
        return SHA256.hash(data: Data(joined.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: The layers

    /// The layer of `text` under `outside` inside `list`: the one the served index keeps, or the kit's made now in the
    /// request's own task, so that a layer its client abandons stops and keeps nothing. Its refusals are the API's, but for
    /// a run whose task is cancelled, which throws its cancellation whatever the encoder answered (S27d's rule).
    static func ran(_ text: String, outside: SearchParameters, list: HeldList, scoped: ServedSearch, served: ServedIndex,
                    engine: MeaningSearchRoutes.MeaningEngine, resources: ServerResources) async throws -> LayerRun {
        let key = "\(list.key)\n\(text)\n\(SearchRequest.signature(outside))"
        if let kept = await served.layers.value(for: key) { return kept }
        let run: LayerRun
        switch list.base.direction {
        case .wordsInMatches:
            run = try await words(text, outside: outside, base: list.base, scoped: scoped, engine: engine)
        case .rankByMeaning:
            guard engine.encoder.settings.enabled else { throw EncoderRefusal.off.problem }
            let bundle = try await MeaningSearchRoutes.bundle(engine.vectors)
            do {
                run = try await kitRanking(text, outside: outside, base: list.base, service: scoped.service, bundle: bundle,
                                           engine: engine, indexedVolumeIds: served.indexedVolumeIds, resources: resources)
            } catch let refusal as EncoderRefusal {
                try Task.checkCancellation()
                throw refusal.problem
            } catch let unavailable as SemanticQuerySearcher.SearchUnavailable {
                try Task.checkCancellation()
                throw MeaningSearchRoutes.problem(unavailable)
            } catch let error as FTS5Error {
                try Task.checkCancellation()
                throw SearchRoutes.refusal(error)
            }
            // A ranking of a whole match keeps the match's keys with the list, so that the next question asks the index
            // nothing (`PinnedResultBase.keepWholeMatch`).
            if run.base.wholeMatch != nil, list.base.wholeMatch == nil {
                await served.held.keep(HeldList(base: run.base, parameters: list.parameters, key: list.key), for: list.key)
            }
        }
        try Task.checkCancellation()
        await served.layers.keep(run, for: key)
        return run
    }

    /// Words found in a held Meaning list, as `SearchViewModel.search()` finds them inside one: the keyword search the field
    /// and the filters say, its gate joined by the list's members (`LayeredResultComposer.gating`), its rows put in the
    /// list's order with the list's scores (`wordsInMatches`); whether filters chosen since narrowed it too
    /// (`filtersNarrow`); its expression with the list's part, and its signature, the keyword route's with the `base=` part.
    static func words(_ words: String, outside: SearchParameters, base: PinnedResultBase, scoped: ServedSearch,
                      engine: MeaningSearchRoutes.MeaningEngine) async throws -> LayerRun {
        let gated = LayeredResultComposer.gating(outside, inside: base)
        do {
            // The gate holds the list's members at most, so a fetch of that many rows holds every one it admits.
            let rows = try await scoped.service.search(parameters: gated, limit: max(1, base.members.count), offset: 0)
            let expression = try? await scoped.service.matchExpressions(for: gated).corpus
            return LayerRun(query: words, rows: LayeredResultComposer.wordsInMatches(keywordRows: rows, base: base),
                            route: .wordsInMatches(base: base.members.count), base: base,
                            filtersNarrowed: base.filtersNarrow(outside), disclosure: nil,
                            renderedExpression: expression.map { $0 + base.renderedExpressionSuffix },
                            signature: SearchScopeSignature.layered(nil, parameters: gated, basePart: base.signaturePart)
                                ?? SearchScopeSignature.signature(for: gated),
                            gated: gated, outside: outside, fetchLimit: engine.ceiling, totalMatchCount: nil, missingShards: [])
        } catch let error as FTS5Error {
            throw SearchRoutes.refusal(error)
        }
    }

    /// A held keyword list or browse ranked by a question, as `SearchViewModel.rankHeldList` ranks one: the kit's
    /// `rankWholeMatch` of a list cut at its ceiling, its match narrowed by the filters chosen since, the closest listed up
    /// to the ceiling; otherwise the kit's `rerank` of its members, the list joined to the gate, the rows it cannot rank
    /// last. A ranking keeps its list's ceiling and total, its expression says what it ranked, and its signature is the
    /// Meaning route's, with the documents it ranked inside, and the list's part.
    @MainActor
    static func kitRanking(_ question: String, outside: SearchParameters, base held: PinnedResultBase, service: SearchService,
                           bundle: SemanticBundle, engine: MeaningSearchRoutes.MeaningEngine, indexedVolumeIds: Set<String>,
                           resources: ServerResources) async throws -> LayerRun {
        let asks = ShardAsks()
        let searcher = SemanticQuerySearcher(index: bundle.index, corpus: bundle.corpus, shards: engine.shards,
                                             encoder: engine.encoding, requestShardFetch: { asks.ask($0) })
        let backend = SemanticSearchBackend(searcher: searcher, searchService: service,
                                            manifestEntry: { resources.volume($0) }, indexedVolumeIds: { indexedVolumeIds })
        var base = held
        let gated = LayeredResultComposer.gating(outside, inside: base)
        let model = bundle.provenance.model
        if base.ranksWholeMatch, let ran = base.ranParameters {
            let whole = try await backend.rankWholeMatch(query: question, base: base, match: ran, parameters: outside,
                                                         limit: base.fetchLimit)
            base.keepWholeMatch(whole.matchKeys)
            let rows = whole.outcome.results
            return LayerRun(
                query: question, rows: rows,
                route: .rankedByMeaning(unranked: rows.filter { $0.semanticScore == nil }.count, wholeMatch: whole.ranking),
                base: base, filtersNarrowed: false, disclosure: whole.outcome.disclosure,
                renderedExpression: SemanticSearchBackend.renderedExpression(rankingAll: whole.ranking.size, listing: base.fetchLimit,
                                                                             model: model) + base.renderedExpressionSuffix,
                signature: SearchScopeSignature.layered(whole.setSignature, parameters: gated, basePart: base.signaturePart)
                    ?? whole.setSignature,
                gated: gated, outside: outside, fetchLimit: base.fetchLimit, totalMatchCount: base.totalMatchCount,
                missingShards: asks.volumes)
        }
        let ranking = try await backend.rerank(query: question, base: base.members, parameters: gated)
        let rows = ranking.results
        let signature = SearchScopeSignature.semanticSignature(for: gated)
        return LayerRun(
            query: question, rows: rows, route: .rankedByMeaning(unranked: rows.filter { $0.semanticScore == nil }.count),
            base: base, filtersNarrowed: false, disclosure: ranking.disclosure,
            renderedExpression: SemanticSearchBackend.renderedExpression(rankingAll: base.members.count, model: model)
                + base.renderedExpressionSuffix,
            signature: SearchScopeSignature.layered(signature, parameters: gated, basePart: base.signaturePart) ?? signature,
            gated: gated, outside: outside, fetchLimit: base.fetchLimit, totalMatchCount: base.totalMatchCount,
            missingShards: asks.volumes)
    }

    // MARK: The answer

    /// The page `asked` names of `run`, in its order, less the rows Checklist Mode hides, with what the app says of the layer.
    static func page(_ run: LayerRun, asked: SearchRequest, served: ServedIndex, resources: ServerResources) -> LayeredSearchResult {
        let rows = asked.sort.sorted(run.rows)
        let shown = rows.filter { !asked.hides($0) }
        let scope = LayerScope(run, loaded: rows.count, shown: shown.count, sort: asked.sort)
        return LayeredSearchResult(
            total: rows.count, countBasis: "exact", limit: asked.limit, offset: asked.offset, retainedLimit: run.base.fetchLimit,
            sort: asked.sort.rawValue, sortChoices: SearchSortOrder.allCases.map { Choice(value: $0.rawValue, title: $0.label) },
            items: shown.dropFirst(asked.offset).prefix(asked.limit).map(SearchItem.init),
            hidden: asked.reviewed.isEmpty ? nil : rows.count - shown.count,
            coverage: Coverage(index: served.corpus, resources: resources),
            layer: summary(run, scope: scope, shown: shown, sort: asked.sort))
    }

    /// What the app says of `run` beside its rows, shown as `shown` in `sort`.
    static func summary(_ run: LayerRun, scope: LayerScope, shown: [SearchResult], sort: SearchSortOrder) -> LayerSummary {
        let tail = LayeredResultComposer.unrankedTail(of: shown, route: run.route, sortOrder: sort)
        let empty: LayerEmpty? = run.rows.isEmpty
            ? LayerEmpty(statement: run.base.direction == .wordsInMatches ? scope.headerDescription
                             : LayerWords.rankedStatement(route: run.route, disclosure: run.disclosure),
                         searchLibraryTitle: run.base.direction == .wordsInMatches ? LayerWords.searchLibraryTitle : nil,
                         backTitle: run.base.backTitle)
            : nil
        return LayerSummary(
            direction: name(run.base.direction), query: run.query, route: route(run.route), header: scope.headerDescription,
            filtersNarrowed: scope.layerFiltersNarrowed,
            unrankedTail: tail.map { UnrankedTail(firstKey: $0.firstId, count: $0.count, line: LayerWords.unrankedHeader($0.count)) },
            empty: empty,
            strip: run.disclosure.map { MeaningSearchWords.strip($0, beyondCount: 0) },
            disclosure: run.disclosure.map(MeaningDisclosure.init),
            swap: LayerWords.swap(heldList: run.base, route: run.route, layerQuery: run.query),
            renderedExpression: run.renderedExpression, signature: run.signature, base: summary(run.base))
    }

    /// What the row of `base` says of it.
    static func summary(_ base: PinnedResultBase) -> HeldListSummary {
        let kind: String
        switch base.kind {
        case .meaning: kind = "meaning"
        case .keywords: kind = "keywords"
        case .browse: kind = "browse"
        }
        return HeldListSummary(
            direction: name(base.direction), kind: kind, query: base.query, describedQuery: base.describedQuery,
            rows: base.rows.count, members: base.members.count, hiddenByChecklist: base.hiddenByChecklist,
            notDownloaded: base.notDownloaded, wasCut: base.wasCut, ranksWholeMatch: base.ranksWholeMatch,
            wholeMatchCount: base.wholeMatchCount, setDescription: base.setDescription, rowDescription: base.rowDescription,
            accessibilityLabel: base.accessibilityLabel, leftOutDescription: base.leftOutDescription.map(MeaningSearchWords.server),
            backTitle: base.backTitle, captureLabel: base.captureLabel, startTitle: base.direction.startTitle,
            fieldPrompt: base.direction.fieldPrompt, signaturePart: base.signaturePart, memberDigest: memberDigest(base))
    }

    static func name(_ direction: SearchLayerDirection) -> String {
        switch direction {
        case .wordsInMatches: "wordsInMatches"
        case .rankByMeaning: "rankByMeaning"
        }
    }

    static func route(_ route: ExecutedSearchRoute) -> LayerRoute {
        switch route {
        case .wordsInMatches(let base):
            return LayerRoute(kind: "wordsInMatches", base: base)
        case .rankedByMeaning(let unranked, let whole):
            return LayerRoute(kind: "rankedByMeaning", unranked: unranked, wholeMatch: whole.map {
                WholeMatch(size: $0.size, filteredOut: $0.filteredOut, notRanked: $0.notRanked, closest: $0.closest, isCut: $0.isCut)
            })
        case .keywords, .meaning:
            return LayerRoute(kind: "unlayered")
        }
    }

    // MARK: The fallback

    /// The app's Semantic matches (experimental) for the keyword search `form` says, which found nothing: the kit's
    /// searcher's nearest across the whole series, its filters and its corpus not applied, and the caption that says so
    /// where it had any.
    static func fallback(_ form: FormQuery, provider: ServedIndexProvider, resources: ServerResources,
                         engine: MeaningSearchRoutes.MeaningEngine, context: APIRequestContext) async throws -> MeaningFallback {
        let asked = try SearchRequest(form: form)
        let question = try MeaningSearchRoutes.question(of: asked, engine: engine)
        let bundle = try await MeaningSearchRoutes.bundle(engine.vectors)
        let served = try await provider.served()
        // `SearchViewModel.hasActiveFilters`, read from the parameters as the kit reads it, a corpus applied among them.
        let filtersActive = asked.workingCorpusId != nil || PinnedResultBase.setsAFilter(asked.parameters)
        let run = try await context.whileClientConnected {
            try await fallbackRun(question, served: served, bundle: bundle, engine: engine, resources: resources)
        }
        let results = run.results
        return MeaningFallback(
            question: question,
            caption: MeaningSearchWords.server(SemanticFallbackCopy.caption(
                unscored: results.unscoredCandidates, unscoredVolumes: results.unscoredVolumes,
                downloadingVolumes: results.downloadingVolumes, filtersActive: filtersActive, locale: MeaningSearchWords.locale)),
            hits: run.hits,
            emptyStatement: run.hits.isEmpty ? MeaningSearchWords.server(SemanticModeStripCopy.emptyStatement(
                disclosure: SemanticSearchBackend.Disclosure(
                    unscoredCandidates: results.unscoredCandidates, unscoredVolumes: results.unscoredVolumes,
                    downloadingVolumes: results.downloadingVolumes, filtersApplied: false, filteredOut: 0,
                    beyondUncheckedByFilters: false),
                locale: MeaningSearchWords.locale)) : nil,
            unscoredCandidates: results.unscoredCandidates, unscoredVolumes: results.unscoredVolumes,
            missingShards: run.missingShards)
    }

    /// The fallback's run of `question`: the one the served index keeps, which no user's half changes, or the kit's
    /// searcher's corpus-wide search made now, at its own length, ten, with each hit resolved as the app's view resolves it:
    /// a document the index holds by its record, any other by its volume's title in the catalogue.
    static func fallbackRun(_ question: String, served: ServedIndex, bundle: SemanticBundle,
                            engine: MeaningSearchRoutes.MeaningEngine, resources: ServerResources) async throws -> FallbackRun {
        if let kept = await served.fallbacks.value(for: question) { return kept }
        let asks = ShardAsks()
        let searcher = SemanticQuerySearcher(index: bundle.index, corpus: bundle.corpus, shards: engine.shards,
                                             encoder: engine.encoding, requestShardFetch: { asks.ask($0) })
        let results: SemanticQuerySearcher.Results
        do {
            results = try await searcher.search(question)
        } catch let refusal as EncoderRefusal {
            try Task.checkCancellation()
            throw refusal.problem
        } catch let unavailable as SemanticQuerySearcher.SearchUnavailable {
            try Task.checkCancellation()
            throw MeaningSearchRoutes.problem(unavailable)
        }
        try Task.checkCancellation()
        let indexed = served.indexedVolumeIds
        let keys = results.hits.filter { indexed.contains($0.volumeID) }
            .map { DocumentKey(volumeId: $0.volumeID, documentId: $0.documentID) }
        let records = (try? await served.pipeline.candidateRecords(forKeys: keys)) ?? [:]
        let hits = results.hits.map { hit -> FallbackHit in
            let record = records[DocumentKey(volumeId: hit.volumeID, documentId: hit.documentID)]
            return FallbackHit(
                volumeId: hit.volumeID, documentId: hit.documentID, score: hit.score,
                chip: SemanticScoreCopy.chipLabel(for: hit.score), opens: record != nil,
                displayTitle: record.map { record in
                    let trimmed = DocumentHeaderDisplay.trimmedHeader(record.header)
                    return trimmed.isEmpty
                        ? FRUSLightAPI.displayTitle(header: "", documentNumber: record.documentNumber,
                                                    isEditorialNote: record.isEditorialNote, documentId: hit.documentID)
                        : trimmed
                },
                dateline: record?.dateline,
                documentLabel: record.map { CitableDocumentNumber.captionLabel(printed: $0.documentNumber, documentId: hit.documentID) },
                isEditorialNote: record?.isEditorialNote ?? false,
                volumeTitle: resources.volume(hit.volumeID)?.title ?? hit.volumeID)
        }
        let run = FallbackRun(results: results, hits: hits, missingShards: asks.volumes)
        await served.fallbacks.keep(run, for: question)
        return run
    }
}

// MARK: - The app's words for a layer

/// What the app's search screen says of a layer beyond the kit's sentences, mirrored: `SearchLayerEmptyState`'s statics,
/// `SearchLayerCopy`'s line over a ranking's unranked rows and its Swap help, and `SearchLayerSwap`'s rule, which
/// `SearchWithinParityTests` holds to the app's source.
enum LayerWords {
    /// "Search the Whole Library for These Words" (`SearchLayerEmptyState.searchLibraryTitle`).
    static let searchLibraryTitle = "Search the Whole Library for These Words"

    /// What an empty ranking of a list's rows says (`SearchLayerEmptyState.rankedStatement`).
    static let rankedStatementOfRows = "None of the results you are searching within passes your filters."

    /// What an empty ranking says, by what it ranked (`SearchLayerEmptyState.rankedStatement(route:disclosure:)`): a
    /// ranking of a whole match whose set held documents says why none could be listed, the kit's sentence for a search
    /// inside a set, in this server's words.
    static func rankedStatement(route: ExecutedSearchRoute, disclosure: SemanticSearchBackend.Disclosure?) -> String {
        guard case .rankedByMeaning(_, let wholeMatch?) = route, wholeMatch.size > 0, let disclosure else {
            return rankedStatementOfRows
        }
        return MeaningSearchWords.server(SemanticUnscoredCopy.emptyInsideSet(
            setSize: wholeMatch.size, ranked: disclosure.rankedCount ?? 0, filteredOut: 0,
            volumes: disclosure.unscoredVolumes, downloading: disclosure.downloadingVolumes, locale: MeaningSearchWords.locale))
    }

    /// The line over a ranking's rows it could not rank (`SearchLayerCopy.unrankedHeader`).
    static func unrankedHeader(_ count: Int) -> String {
        count == 1 ? "1 result not ranked by meaning" : "\(CorpusCapture.grouped(count)) results not ranked by meaning"
    }

    /// The swap of `heldList` and the layer on screen (`SearchLayerSwap.init(heldList:route:layerQuery:)`): none before a
    /// layer's rows, nor where either side has no words of its own; and what Swap will do (`SearchLayerCopy.swapHelp`).
    static func swap(heldList: PinnedResultBase, route: ExecutedSearchRoute, layerQuery: String) -> LayerSwap? {
        let layer = layerQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let own = heldList.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard route.isLayer, !layer.isEmpty, !own.isEmpty else { return nil }
        let direction = heldList.direction.swapped
        let list = PinnedResultBase.quotable(layer)
        let inside = PinnedResultBase.quotable(own)
        let help = switch direction {
        case .rankByMeaning: "Search for “\(list)” first, then rank what it finds by “\(inside)”"
        case .wordsInMatches: "Ask “\(list)” first, then find “\(inside)” among its closest matches"
        }
        return LayerSwap(direction: SearchWithinRoutes.name(direction), listQuery: layer, layerQuery: own, help: help)
    }
}

// MARK: - ResultSetScope for a layer

/// What the app's `ResultSetScope` says of a layer's rows (`ResultSetScope.swift`, #1577 lanes 2 to 6), mirrored for the two
/// layered routes, as the app's view models compose it (`describingLayer(over:filtersNarrowed:sortOrder:)`): the results
/// header and a capture's warnings, provenance and partial flag. `SearchWithinParityTests` holds each sentence to the app's.
struct LayerScope: Sendable {
    /// What the layer listed, and those Checklist Mode leaves.
    let loaded: Int
    let shown: Int
    /// The ceiling its rows ran under, and the whole-query count a ranking keeps of its list.
    let fetchLimit: Int
    let totalMatchCount: Int?
    let route: ExecutedSearchRoute
    var layerFiltersNarrowed = false
    var listIsInRankOrder = true
    var layerBaseLabel: String?
    var layerBaseWasCut: Bool?
    var layerBaseHiddenByChecklist = 0
    var narrowing: [String] = []
    /// Whether the corpus the layer ran inside was itself a capture cut short (`appliedCorpusTruncation`).
    var insideTruncatedCorpus = false

    init(loaded: Int, shown: Int, fetchLimit: Int, totalMatchCount: Int?, route: ExecutedSearchRoute) {
        self.loaded = loaded
        self.shown = shown
        self.fetchLimit = fetchLimit
        self.totalMatchCount = totalMatchCount
        self.route = route
    }

    /// The scope of `run`'s rows, `loaded` of them and `shown` in `sort`, as `describingLayer` sets a layer's members.
    init(_ run: LayerRun, loaded: Int, shown: Int, sort: SearchSortOrder) {
        self.init(loaded: loaded, shown: shown, fetchLimit: run.fetchLimit, totalMatchCount: run.totalMatchCount, route: run.route)
        var ranking = false
        if case .rankedByMeaning = run.route { ranking = true }
        layerFiltersNarrowed = run.route.isLayer && run.filtersNarrowed
        listIsInRankOrder = sort == .relevance
        layerBaseLabel = run.route.isLayer ? run.base.captureLabel : nil
        layerBaseWasCut = ranking ? run.base.wasCut : nil
        layerBaseHiddenByChecklist = ranking ? run.base.hiddenByChecklist : 0
    }

    var hiddenByChecklist: Int { max(0, loaded - shown) }

    var capturedHiddenByChecklist: Int {
        guard case .rankedByMeaning = route else { return hiddenByChecklist }
        return hiddenByChecklist + layerBaseHiddenByChecklist
    }

    var didHitFetchLimit: Bool {
        switch route {
        case .meaning, .wordsInMatches: return false
        case .rankedByMeaning(_, let wholeMatch?): return wholeMatch.isCut
        case .rankedByMeaning: if let layerBaseWasCut { return layerBaseWasCut }
        case .keywords: break
        }
        if loaded >= fetchLimit { return true }
        if let totalMatchCount { return totalMatchCount > loaded }
        return false
    }

    var isPartialEvidence: Bool {
        if didHitFetchLimit { return true }
        if insideTruncatedCorpus { return true }
        if case .wordsInMatches = route { return true }
        return false
    }

    /// `isCapturePartial`: a layer is never a Meaning search's list itself.
    var isCapturePartial: Bool { isPartialEvidence }

    private func grouped(_ value: Int) -> String { CorpusCapture.grouped(value) }

    private func resultsPhrase(_ count: Int) -> String {
        count == 1 ? "1 result" : "\(grouped(count)) results"
    }

    /// `layeredHeaderClause`.
    var layeredHeaderClause: String? {
        switch route {
        case .keywords, .meaning:
            return nil
        case .wordsInMatches(let base):
            if layerFiltersNarrowed { return wordsInMatchesClauseWithFilters(base: base) }
            if base == 1 {
                return loaded == 0 ? "Your closest match does not contain these words" : "Your closest match contains these words"
            }
            switch loaded {
            case 0: return "None of your \(grouped(base)) closest matches contains these words"
            case 1: return "1 of your \(grouped(base)) closest matches contains these words"
            default: return "\(grouped(loaded)) of your \(grouped(base)) closest matches contain these words"
            }
        case .rankedByMeaning(let unranked, let wholeMatch):
            guard loaded > 0 else { return nil }
            if let wholeMatch, wholeMatch.isCut { return wholeMatchClause(wholeMatch) }
            guard unranked > 0 else {
                guard listIsInRankOrder else { return resultsPhrase(loaded) }
                return "\(resultsPhrase(loaded)), closest first"
            }
            return "\(resultsPhrase(loaded)) · \(grouped(max(0, loaded - unranked))) ranked · \(grouped(unranked)) not ranked"
        }
    }

    private func wholeMatchClause(_ wholeMatch: WholeMatchRanking) -> String {
        let filtered = wholeMatch.filteredOut > 0
        guard wholeMatch.closest > 0 else {
            return filtered
                ? "None of the \(grouped(wholeMatch.size)) results that pass your filters could be ranked"
                : "None of the \(grouped(wholeMatch.size)) results could be ranked"
        }
        var parts = [filtered
            ? "Closest \(grouped(wholeMatch.closest)) of the \(grouped(wholeMatch.size)) results that pass your filters"
            : "Closest \(grouped(wholeMatch.closest)) of \(grouped(wholeMatch.size)) results"]
        if wholeMatch.notRanked > 0 { parts.append("\(grouped(wholeMatch.notRanked)) not ranked") }
        return parts.joined(separator: " · ")
    }

    private func wordsInMatchesClauseWithFilters(base: Int) -> String {
        if base == 1 {
            return loaded == 0
                ? "Your closest match does not both contain these words and pass your filters"
                : "Your closest match contains these words and passes your filters"
        }
        switch loaded {
        case 0: return "None of your \(grouped(base)) closest matches both contains these words and passes your filters"
        case 1: return "1 of your \(grouped(base)) closest matches contains these words and passes your filters"
        default: return "\(grouped(loaded)) of your \(grouped(base)) closest matches contain these words and pass your filters"
        }
    }

    /// `headerDescription` for a layer's rows: its clause, with what the checklist hides beside it; "No results" for a
    /// ranking of no row.
    var headerDescription: String {
        if let layered = layeredHeaderClause {
            guard hiddenByChecklist > 0 else { return layered }
            return ["\(grouped(shown)) shown", layered].joined(separator: " · ")
        }
        return "No results"
    }

    /// `captureTruncationWarning` for the two layered routes.
    var captureTruncationWarning: String? {
        if case .wordsInMatches = route {
            return shown == 1
                ? "This document is the one among a Meaning search’s closest matches that contains your words, not every document that contains them. Counts taken inside this corpus are counts inside that set."
                : "These documents are the ones among a Meaning search’s closest matches that contain your words, not every document that contains them. Counts taken inside this corpus are counts inside that set."
        }
        guard didHitFetchLimit else { return nil }
        if case .rankedByMeaning(let unranked, let wholeMatch?) = route {
            guard wholeMatch.closest > 0 else { return highestScoringWarning(of: wholeMatch.size) }
            guard unranked > 0 else {
                return wholeMatch.closest == 1
                    ? "This document is the closest to your question of \(grouped(wholeMatch.size)) matching documents, not all of them. Counts taken inside this corpus are counts inside that subset."
                    : "These \(grouped(wholeMatch.closest)) documents are the closest to your question of \(grouped(wholeMatch.size)) matching documents, not all of them. Counts taken inside this corpus are counts inside that subset."
            }
            return "These \(grouped(loaded)) documents are the \(grouped(wholeMatch.closest)) closest to your question of \(grouped(wholeMatch.size)) matching documents, and \(grouped(unranked)) that it could not rank. Counts taken inside this corpus are counts inside that subset."
        }
        if let totalMatchCount { return highestScoringWarning(of: totalMatchCount) }
        return "These \(grouped(loaded)) documents are the highest-scoring of a larger match, not all of it. Counts taken inside this corpus are counts inside that subset."
    }

    private func highestScoringWarning(of total: Int) -> String {
        "These \(grouped(loaded)) documents are the highest-scoring of \(grouped(total)) matching documents. Counts taken inside this corpus are counts inside that subset."
    }

    private func highestScoringClause(of total: Int) -> String {
        " — the highest-scoring \(grouped(loaded)) of \(grouped(total)) matches"
    }

    /// `captureChecklistWarning`.
    var captureChecklistWarning: String? {
        guard capturedHiddenByChecklist > 0 else { return nil }
        return capturedHiddenByChecklist == 1
            ? "Checklist mode is hiding 1 reviewed document. It will not be in this corpus."
            : "Checklist mode is hiding \(grouped(capturedHiddenByChecklist)) reviewed documents. They will not be in this corpus."
    }

    /// `captureProvenanceDescription` for the two layered routes.
    var captureProvenanceDescription: String {
        var description: String
        if case .wordsInMatches(let base) = route {
            if let label = layerBaseLabel {
                description = "Words found in a Meaning search’s closest matches to \(label) — \(grouped(loaded)) of \(grouped(base))"
            } else {
                description = "Words found in a Meaning search’s closest matches — \(grouped(loaded)) of \(grouped(base))"
            }
        } else if case .rankedByMeaning = route {
            description = layerBaseLabel.map { "Search results for \($0), ranked by a question" }
                ?? "Search results, ranked by a question"
        } else {
            description = "Search results"
        }
        if !narrowing.isEmpty { description = "\(description) (\(narrowing.joined(separator: "; ")))" }
        if didHitFetchLimit, case .rankedByMeaning(let unranked, let wholeMatch?) = route {
            if wholeMatch.closest == 0 {
                description += highestScoringClause(of: wholeMatch.size)
            } else if unranked > 0 {
                description += " — the closest \(grouped(wholeMatch.closest)) of \(grouped(wholeMatch.size)) matches, and \(grouped(unranked)) not ranked"
            } else {
                description += " — the closest \(grouped(wholeMatch.closest)) of \(grouped(wholeMatch.size)) matches"
            }
        } else if didHitFetchLimit {
            if let totalMatchCount {
                description += highestScoringClause(of: totalMatchCount)
            } else {
                description += " — the highest-scoring \(grouped(loaded)) of a larger match"
            }
        }
        if capturedHiddenByChecklist > 0 {
            description += capturedHiddenByChecklist == 1
                ? "; 1 reviewed document excluded" : "; \(grouped(capturedHiddenByChecklist)) reviewed documents excluded"
        }
        return description
    }
}
