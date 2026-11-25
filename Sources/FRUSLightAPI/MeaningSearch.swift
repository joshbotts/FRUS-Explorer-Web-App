// GET and POST /api/v1/search/meaning (PLAN's S27d): search by meaning, the kit's Meaning engine over the served index.
// The answer is the kit's `SemanticSearchBackend.run` (FRUS-Explorer#1982, S27a) over the served index's search service,
// as the user the request acts for searches it; the kit's `SemanticQuerySearcher`, with the server's encoder (S27b) as its
// encoder, the bundled tier and the image's shards through the server's `SemanticVectors` (S26c); and the catalogue, which
// titles a hit in a volume the server does not serve. So a run lists the hundred nearest, each a result row with the
// kit's prose snippet and its semantic score, calibrated by the generation's query offset, and the kit's chip. Inside a
// working corpus the kit ranks every member the index holds, and the other filters are intersected after the ranking,
// the answer counting what they removed. A candidate whose shard the server lacks is dropped, never ranked by Hamming,
// and counted with its volumes, which the answer names as the volumes the searcher asked for: a server holds every match
// file it ever will in its image, so it fetches none. A hit in a volume the server does not serve is listed apart,
// titled from the catalogue, under the volume scope alone, as the app lists what is not downloaded.
//
// What the Meaning mode says of a run is the kit's (`SemanticSearchCopy.swift`): the strip's sentences, the empty
// state's and the heading over the hits beyond the library, in this server's words where the kit's speak of a device
// that downloads its volumes and their match files (`MeaningSearchWords`). The list is paged, ordered by the kit's
// `SearchSortOrder` and checklisted as a keyword search's kept results are, from the run, which the served index keeps a
// while for its user (`MeaningRuns`), so that another page, another order, a mark of the checklist, the run's record in
// the trail and its capture as a working corpus ask the encoder nothing again. A run is made in its request's own task,
// so that a search its client abandons stops: before its question is embedded and after, and inside a set between the
// kit's steps.

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird
import SemanticVectorsKit
import Synchronization

/// A search by meaning's answer: a page of its rows, as a keyword search's page is given (`SearchResultList`), and what
/// the Meaning mode shows of the run.
public struct MeaningSearchResult: Codable, Equatable, Sendable, ResponseEncodable {
    /// The rows the run listed, after the filters: the app's "100 closest matches". Checklist Mode's hidden rows count
    /// here, as they count in a keyword search's total.
    public var total: Int
    /// Always `exact`: a list's own length.
    public var countBasis: String
    public var limit: Int
    public var offset: Int
    /// How many rows a run lists at most, the kit's `SemanticSearchBackend.hitLimit`, which a page cannot reach past.
    public var retainedLimit: Int
    /// The order the page is cut from: a `SearchSortOrder` raw value.
    public var sort: String
    public var sortChoices: [Choice]
    /// The page's rows, each with its semantic score and its chip.
    public var items: [SearchItem]
    /// With `reviewed`: how many of the run's rows the pages leave out as reviewed, as for a keyword search.
    public var hidden: Int?
    public var coverage: Coverage
    public var meaning: MeaningRunSummary
}

/// What a run of a search by meaning says beside its rows, as the app's Meaning mode shows it.
public struct MeaningRunSummary: Codable, Equatable, Sendable {
    /// The question as the kit ranked it: the search box's text, trimmed of the spaces and new lines around it.
    public var question: String
    /// The strip's parts, the kit's `SemanticModeStripCopy.parts`, in this server's words: the opening, then each thing
    /// the run owes the reader, which the strip joins and a reader can read one by one.
    public var strip: [String]
    /// The sentence under "No semantic matches yet", the kit's `emptyStatement(disclosure:)`, in this server's words, for
    /// a run that listed no row.
    public var emptyStatement: String
    /// Every count the run owes the reader, the kit's `SemanticSearchBackend.Disclosure`.
    public var disclosure: MeaningDisclosure
    /// The hits in volumes this server does not serve, in rank order, titled from the catalogue.
    public var beyondLibrary: [MeaningBeyondHit]
    /// The heading over them, the kit's `beyondHeader(count:)` in this server's words, when there are any.
    public var beyondHeader: String?
    /// The volumes the searcher asked a match file for, which this server does not hold, sorted: their candidates were
    /// dropped, never ranked by Hamming. None while the image holds every shard.
    public var missingShards: [String]
    /// What the run records as its rendered expression, the kit's `renderedExpression(model:)`, which names the bundled
    /// generation's model: `route=semantic; model=embeddinggemma-2-Q8_0; top=100`.
    public var renderedExpression: String
    /// The trail's signature of the run, the kit's `SearchScopeSignature.semanticSignature(for:)`: the Meaning route, and
    /// inside a working corpus the documents it ranked inside.
    public var signature: String
}

/// The kit's `SemanticSearchBackend.Disclosure`: every count a Meaning search owes the reader.
public struct MeaningDisclosure: Codable, Equatable, Sendable {
    /// Candidates, or inside a set its members, dropped for want of their volume's match file, and their volumes.
    public var unscoredCandidates: Int
    public var unscoredVolumes: Int
    /// Of those volumes, the ones whose match file is downloading: none on a server, which downloads none.
    public var downloadingVolumes: Int
    /// Whether the other filters were intersected with the ranked rows, and how many rows they removed.
    public var filtersApplied: Bool
    public var filteredOut: Int
    /// Whether hits beyond the library stood under filters they were checked against only by the volume scope.
    public var beyondUncheckedByFilters: Bool
    /// The size of the set a search inside a working corpus ranked, or absent for a search of the whole series.
    public var rankedWithin: Int?
    /// Members of that set the bundled vectors hold no row for.
    public var withoutVector: Int
    /// Ranked hits in volumes the server serves whose documents its index does not hold.
    public var notIndexedHere: Int
    /// Members of that set the search ranked, absent for a search of the whole series.
    public var rankedCount: Int?

    init(_ disclosure: SemanticSearchBackend.Disclosure) {
        unscoredCandidates = disclosure.unscoredCandidates
        unscoredVolumes = disclosure.unscoredVolumes
        downloadingVolumes = disclosure.downloadingVolumes
        filtersApplied = disclosure.filtersApplied
        filteredOut = disclosure.filteredOut
        beyondUncheckedByFilters = disclosure.beyondUncheckedByFilters
        rankedWithin = disclosure.rankedWithin
        withoutVector = disclosure.withoutVector
        notIndexedHere = disclosure.notIndexedHere
        rankedCount = disclosure.rankedCount
    }
}

/// A hit in a volume this server does not serve, as the app's `SemanticUndownloadedRow` draws one: the document's id in
/// its volume, titled from the catalogue, and its chip; no other metadata, since the index holds no row for it.
public struct MeaningBeyondHit: Codable, Equatable, Sendable {
    public var volumeId: String
    public var documentId: String
    /// The volume's title in the catalogue, or its id.
    public var volumeTitle: String
    /// The calibrated cosine, on the rows' scale.
    public var score: Double
    /// The kit's chip, "Semantic match · 64%".
    public var chip: String
}

/// One search by meaning as the kit's backend ran it, which the served index keeps a while (`MeaningRuns`): its outcome,
/// the volumes whose match file the searcher asked for, the parameters it ran with, a working corpus's documents in
/// their gate, and the bundled generation's model.
struct MeaningRun: Sendable {
    let question: String
    let outcome: SemanticSearchBackend.Outcome
    let missingShards: [String]
    let parameters: SearchParameters
    let model: String

    /// The rows in the order `sort` asks for, the kit's: relevance is the ranking's own.
    func rows(in sort: SearchSortOrder) -> [SearchResult] { sort.sorted(outcome.results) }

    /// The trail's signature of the run (`SearchScopeSignature.semanticSignature(for:)`).
    var signature: String { SearchScopeSignature.semanticSignature(for: parameters) }

    /// The run's rendered expression (`SemanticSearchBackend.renderedExpression(model:)`).
    var renderedExpression: String { SemanticSearchBackend.renderedExpression(model: model) }
}

/// The searches by meaning run lately over a served index (PLAN's S27d): each run's outcome, kept for its user, as their
/// store's mark was, its question and its parameters, so that another page of it, another order, its record in the
/// trail and its capture ask the encoder nothing again. A run is made in the request's own task and kept once it ends,
/// so that a search its client abandons stops, and two requests that make one at once make it twice and keep it once.
/// A served index holds them, so a new index starts with none.
actor MeaningRuns {
    private var kept: [String: MeaningRun] = [:]
    /// The keys kept, the most recently asked last.
    private var recency: [String] = []
    let capacity: Int

    init(capacity: Int = 8) {
        self.capacity = capacity
    }

    /// The run kept for `key`, if any.
    func run(for key: String) -> MeaningRun? {
        guard let run = kept[key] else { return nil }
        recency.removeAll { $0 == key }
        recency.append(key)
        return run
    }

    /// Keeps `run` for `key`, letting the least recently asked go past `capacity`.
    func keep(_ run: MeaningRun, for key: String) {
        kept[key] = run
        recency.removeAll { $0 == key }
        recency.append(key)
        while recency.count > capacity {
            kept[recency.removeFirst()] = nil
        }
    }

    /// How many runs are kept, for the tests.
    var count: Int { kept.count }
}

/// The server's encoder as the kit's searcher asks it (PLAN's S27d): S27b's `QueryEncoder`, its vector of the reader's
/// words under the kit's prompt, normalised as the app's are, with its refusal of a query past the model's context the
/// kit's own, `SearchUnavailable.queryTooLong`, as the app's encoder refuses one. Its other refusals pass as they came. A
/// search whose task is cancelled stops before its question is embedded and once it is, so that a search its client
/// abandons asks the shards nothing.
struct ServerQueryEncoding: SemanticQueryEncoding {
    let encoder: QueryEncoder

    func embed(_ query: String) async throws -> [Double] {
        try Task.checkCancellation()
        let vector: [Double]
        do {
            vector = try await encoder.embed(query).vector
        } catch EncoderRefusal.tooLong {
            throw SemanticQuerySearcher.SearchUnavailable.queryTooLong
        }
        try Task.checkCancellation()
        return vector
    }
}

/// The volumes a search asked a match file for (`SemanticQuerySearcher`'s `requestShardFetch`). A server holds every
/// shard it ever will in its image and fetches none, so it answers that no download is under way, and counts the ask.
final class ShardAsks: Sendable {
    private let asked = Mutex<Set<String>>([])

    func ask(_ volume: String) -> Bool {
        asked.withLock { _ = $0.insert(volume) }
        return false
    }

    var volumes: [String] { asked.withLock { $0.sorted() } }
}

/// The Meaning mode's sentences in a server's words (PLAN's S27d): the kit's (`SemanticSearchCopy.swift`), which speak of
/// a device that downloads its volumes and their match files, each phrase of a device replaced by the server's. A server
/// holds every match file it ever will in its image and downloads none, so no sentence offers a download, as the row
/// asks: the remedies that name Settings' downloads are replaced by what is so. `MeaningSearchParityTests` holds each
/// replacement to a sentence the kit says, so that a pin move that rewords one fails until the web follows it.
enum MeaningSearchWords {
    /// Each phrase of a device and the server's, in the order they are replaced: the remedies first, then the places.
    static let replacements: [(device: String, server: String)] = [
        (" Try Download Vectors for Every Volume in Settings to enable scoring.", " This server does not hold their match files."),
        (" Use Download Vectors for Every Volume in Settings to get the data needed to run this search.", " This server does not hold them."),
        (" Download Missing Vectors in Settings fetches the files for volumes you have downloaded.", ""),
        ("this device's index", "this server's index"),
        ("on this device", "on this server"),
        ("volumes you have not downloaded", "volumes this server does not serve"),
        ("the app has no match data", "the server has no match data"),
    ]

    /// `sentence`, one of the kit's, in this server's words.
    static func server(_ sentence: String) -> String {
        replacements.reduce(sentence) { $0.replacingOccurrences(of: $1.device, with: $1.server) }
    }

    /// The locale the counts are grouped in, as the server's other words are.
    static let locale = Locale(identifier: "en_US")

    /// The strip's parts for a run (`SemanticModeStripCopy.parts`): its own record, so no pending set.
    static func strip(_ disclosure: SemanticSearchBackend.Disclosure, beyondCount: Int) -> [String] {
        SemanticModeStripCopy.parts(disclosure: disclosure, beyondCount: beyondCount, locale: locale).map(server)
    }

    /// The empty state's sentence for a run (`SemanticModeStripCopy.emptyStatement(disclosure:)`).
    static func emptyStatement(_ disclosure: SemanticSearchBackend.Disclosure) -> String {
        server(SemanticModeStripCopy.emptyStatement(disclosure: disclosure, locale: locale))
    }

    /// The heading over the hits beyond the library (`SemanticModeStripCopy.beyondHeader(count:)`).
    static func beyondHeader(_ count: Int) -> String {
        server(SemanticModeStripCopy.beyondHeader(count: count))
    }
}

enum MeaningSearchRoutes {
    /// `GET` and `POST /api/v1/search/meaning`, which read a search's fields, as `GET /api/v1/search` reads them, its words
    /// the question, and its page, order and Checklist Mode's reviewed results.
    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources,
                    users: SearchUsers, engine: MeaningEngine) {
        router.get("/api/v1/search/meaning") { request, context -> MeaningSearchResult in
            try await answer(try FormQuery(request.uri.query), request: request, context: context, provider: provider,
                             resources: resources, users: users, engine: engine)
        }
        // The same, with its query in the body, for one whose Checklist Mode hides more rows than an address holds.
        router.post("/api/v1/search/meaning") { request, context -> MeaningSearchResult in
            let body = try await request.body.collect(upTo: SearchRoutes.postedSearchLimit)
            let form = try FormQuery(body.readableBytes > 0 ? String(buffer: body) : request.uri.query)
            return try await answer(form, request: request, context: context, provider: provider, resources: resources,
                                    users: users, engine: engine)
        }
    }

    /// What a search by meaning is made with: the server's encoder, whose setting says whether it searches by meaning at
    /// all, and which embeds each question (`ServerQueryEncoding`); and the vectors, the bundled tier, and the shards,
    /// which they hold unless a test gives a source that watches what is asked of them.
    struct MeaningEngine: Sendable {
        let encoder: QueryEncoder
        let encoding: any SemanticQueryEncoding
        let vectors: SemanticVectors
        let shards: any SemanticShardSource

        init(encoder: QueryEncoder, vectors: SemanticVectors, shards: (any SemanticShardSource)? = nil) {
            self.encoder = encoder
            encoding = ServerQueryEncoding(encoder: encoder)
            self.vectors = vectors
            self.shards = shards ?? vectors
        }
    }

    /// A page of the search by meaning `form` says, for the user `request` acts for.
    static func answer(_ form: FormQuery, request: Request, context: APIRequestContext, provider: ServedIndexProvider,
                       resources: ServerResources, users: SearchUsers, engine: MeaningEngine) async throws -> MeaningSearchResult {
        var asked = try SearchRequest(form: form)
        let question = try question(of: asked, engine: engine)
        let bundle = try await bundle(engine.vectors)
        let user = try await users.user(searching: asked.parameters, for: request, context: context)
        let served = try await provider.served()
        asked.parameters = try await users.inside(asked.workingCorpusId, asked.parameters, for: user, served: served)
        let scoped = try served.search(for: user)
        let parameters = asked.parameters
        let run = try await context.whileClientConnected {
            try await ran(question, parameters: parameters, scoped: scoped, served: served, bundle: bundle, engine: engine,
                          resources: resources)
        }
        return page(run, asked: asked, served: served, resources: resources)
    }

    /// The question a search asks: its words trimmed of the spaces and new lines around them, as the app sends them. A
    /// server whose encoder is off refuses every search by meaning, in the encoder's words, and one with no words is
    /// refused too.
    static func question(of asked: SearchRequest, engine: MeaningEngine) throws -> String {
        guard engine.encoder.settings.enabled else { throw EncoderRefusal.off.problem }
        let question = (asked.parameters.keywords ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { throw EncoderRefusal.emptyQuery.problem }
        return question
    }

    /// The bundled generation, or the refusal of a server whose vectors are refused, which then searches nothing by meaning.
    static func bundle(_ vectors: SemanticVectors) async throws -> SemanticBundle {
        switch await vectors.bundle() {
        case .success(let bundle): return bundle
        case .failure(let refusal):
            throw APIProblem(.serviceUnavailable, code: "SEMANTIC_UNAVAILABLE",
                             detail: "This server cannot search by meaning: its semantic vectors are refused. \(refusal.description)")
        }
    }

    /// The run of `question` under `parameters` as `scoped` searches it: the one the served index keeps, or the kit's run
    /// made now and kept. Its refusals are the API's, but for a run whose task is cancelled, as its client's leaving cancels
    /// it, which throws its cancellation whatever the encoder answered: the encoder's exchange is cut short then, and the
    /// encoder says so as a failure, which no client is there to hear.
    static func ran(_ question: String, parameters: SearchParameters, scoped: ServedSearch, served: ServedIndex,
                    bundle: SemanticBundle, engine: MeaningEngine, resources: ServerResources) async throws -> MeaningRun {
        let key = "\(scoped.key)\(question)\n\(SearchRequest.signature(parameters))"
        if let kept = await served.meaning.run(for: key) { return kept }
        let run: MeaningRun
        do {
            run = try await kitRun(question, parameters: parameters, service: scoped.service, bundle: bundle, shards: engine.shards,
                                   encoding: engine.encoding, indexedVolumeIds: served.indexedVolumeIds, resources: resources)
        } catch let refusal as EncoderRefusal {
            try Task.checkCancellation()
            throw refusal.problem
        } catch let unavailable as SemanticQuerySearcher.SearchUnavailable {
            try Task.checkCancellation()
            throw problem(unavailable)
        } catch let error as FTS5Error {
            try Task.checkCancellation()
            throw SearchRoutes.refusal(error)
        }
        try Task.checkCancellation()
        await served.meaning.keep(run, for: key)
        return run
    }

    /// The kit's run (`SemanticSearchBackend.run(query:parameters:)`) over the served index's search service as the user
    /// searches it, the kit's searcher over the bundled tier, the server's shards and its encoder, the catalogue, and the
    /// volumes the index holds; and the volumes whose match file the searcher asked for.
    @MainActor
    static func kitRun(_ question: String, parameters: SearchParameters, service: SearchService, bundle: SemanticBundle,
                       shards: any SemanticShardSource, encoding: any SemanticQueryEncoding, indexedVolumeIds: Set<String>,
                       resources: ServerResources) async throws -> MeaningRun {
        let asks = ShardAsks()
        let searcher = SemanticQuerySearcher(index: bundle.index, corpus: bundle.corpus, shards: shards, encoder: encoding,
                                             requestShardFetch: { asks.ask($0) })
        let backend = SemanticSearchBackend(searcher: searcher, searchService: service,
                                            manifestEntry: { resources.volume($0) }, indexedVolumeIds: { indexedVolumeIds })
        let outcome = try await backend.run(query: question, parameters: parameters)
        return MeaningRun(question: question, outcome: outcome, missingShards: asks.volumes, parameters: parameters,
                          model: bundle.provenance.model)
    }

    /// The kit's refusals of a search, in the encoder's words where it has them.
    static func problem(_ unavailable: SemanticQuerySearcher.SearchUnavailable) -> APIProblem {
        switch unavailable {
        case .queryTooLong:
            EncoderRefusal.tooLong(tokens: nil).problem
        case .encodingFailed(let reason):
            EncoderRefusal.failed(reason).problem
        case .modelNotDownloaded:
            EncoderRefusal.unavailable("the image holds no search model").problem
        case .vectorsUnavailable:
            APIProblem(.serviceUnavailable, code: "SEMANTIC_UNAVAILABLE",
                       detail: "This server cannot search by meaning: its semantic vectors are unavailable.")
        }
    }

    /// The page `asked` names of `run`, in its order, less the rows Checklist Mode hides, with what the Meaning mode
    /// shows of the run.
    static func page(_ run: MeaningRun, asked: SearchRequest, served: ServedIndex, resources: ServerResources) -> MeaningSearchResult {
        let rows = run.rows(in: asked.sort)
        let shown = rows.filter { !asked.hides($0) }
        return MeaningSearchResult(
            total: rows.count, countBasis: "exact", limit: asked.limit, offset: asked.offset,
            retainedLimit: SemanticSearchBackend.hitLimit, sort: asked.sort.rawValue,
            sortChoices: SearchSortOrder.allCases.map { Choice(value: $0.rawValue, title: $0.label) },
            items: shown.dropFirst(asked.offset).prefix(asked.limit).map(SearchItem.init),
            hidden: asked.reviewed.isEmpty ? nil : rows.count - shown.count,
            coverage: Coverage(index: served.corpus, resources: resources),
            meaning: summary(run))
    }

    /// What the Meaning mode shows of `run` beside its rows.
    static func summary(_ run: MeaningRun) -> MeaningRunSummary {
        let outcome = run.outcome
        return MeaningRunSummary(
            question: run.question,
            strip: MeaningSearchWords.strip(outcome.disclosure, beyondCount: outcome.beyondLibrary.count),
            emptyStatement: MeaningSearchWords.emptyStatement(outcome.disclosure),
            disclosure: MeaningDisclosure(outcome.disclosure),
            beyondLibrary: outcome.beyondLibrary.map {
                MeaningBeyondHit(volumeId: $0.volumeID, documentId: $0.documentID, volumeTitle: $0.volumeTitle, score: $0.score,
                                 chip: SemanticScoreCopy.chipLabel(for: $0.score))
            },
            beyondHeader: outcome.beyondLibrary.isEmpty ? nil : MeaningSearchWords.beyondHeader(outcome.beyondLibrary.count),
            missingShards: run.missingShards, renderedExpression: run.renderedExpression, signature: run.signature)
    }

    /// The run of the search `asked` says for the user `id`, as the trail records it and a capture saves it: the one the
    /// served index keeps, or one made now, inside the user's corpus.
    static func run(_ asked: SearchRequest, for id: String, in store: any UserDataStore, provider: ServedIndexProvider,
                    resources: ServerResources, engine: MeaningEngine) async throws -> MeaningRun {
        let question = try question(of: asked, engine: engine)
        let bundle = try await bundle(engine.vectors)
        let user = try await SearchUsers.user(id, searching: asked.parameters, in: store)
        let served = try await provider.served()
        let parameters = try await SearchUsers.inside(asked.workingCorpusId, asked.parameters, for: id, in: store, served: served)
        return try await ran(question, parameters: parameters, scoped: try served.search(for: user), served: served,
                             bundle: bundle, engine: engine, resources: resources)
    }
}
