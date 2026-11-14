// The NARA Catalog proxy (PLAN's S22e): `GET /api/v1/nara` says whose key a search would use, and
// `POST /api/v1/nara/search` runs one, through the kit's `NARACatalogClient`, for Source Explorer's NARA
// Catalog section, the query the app's `load()` runs for a note, and for Look Up, one of the kit's
// `LookupStrategy`s over the reader's text. The key is the user's own, else the instance's, the one an admin
// stored or else `FRUS_NARA_API_KEY`, as PLAN's risks have it ("a user's own key ... taking precedence"); it
// goes to the kit's client for the one request, and is never put in an answer, a problem, the log or the
// cache. An answer that found records is kept by the user who asked and its query for a day, so once it is
// answered the same search costs that user and NARA nothing more, and the same search asked while it runs
// waits for it; one that found none is not kept, since the kit's client answers none for some refusals too.
// Each user's answers are their own: one kept for another user, how soon it came or the calls it left
// uncounted would tell them what was searched. A search with the instance's key is counted against the user,
// `NARAQuota.callsPerDay` calls a day, each call as it is made, whatever NARA answers, each search holding
// the most calls it can make until it ends. The group passes /api/v1/me's guard, on a server that keeps no
// user data too, where the instance's key serves: a search is a POST, so it comes from the server's own
// pages, with the user's token.
//
// Look Up's candidates (`POST /api/v1/volumes/{v}/documents/{d}/lookup`) need no key and no network: the kit's
// `NARALookupAnalyzer` over the selection and the passage around it, the footnote's text for a footnote's
// selection, else the document's flat text around the selection's offsets, as the app's `lookupContext(vm:)`
// takes it, with the server's three bundled archival indexes. App code mirrored here, held to its source by
// `LookUpParityTests`: `load()`'s queries and their sizes, the sheet's opening strategy (its `init`) and
// `lookupContext(vm:)`.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A search of the NARA Catalog: Look Up's, one of the kit's strategies with its text; or Source Explorer's,
/// the query the app's `load()` runs for a note, as the sources answer's NARA Catalog section names it.
public struct NARASearch: Codable, Equatable, Sendable {
    /// Look Up's: a `LookupStrategy`'s raw value and the search text.
    public var strategy: String?
    public var query: String?
    /// Source Explorer's: `lotVariants` with `lot` and `recordGroup`, `recordGroup` with `recordGroup` and
    /// `keywords`, or `presidentialMaterials` with `library` and `collection`.
    public var route: String?
    public var lot: String?
    public var recordGroup: String?
    public var keywords: String?
    public var library: String?
    public var collection: String?

    public init(strategy: String? = nil, query: String? = nil, route: String? = nil, lot: String? = nil, recordGroup: String? = nil,
                keywords: String? = nil, library: String? = nil, collection: String? = nil) {
        self.strategy = strategy
        self.query = query
        self.route = route
        self.lot = lot
        self.recordGroup = recordGroup
        self.keywords = keywords
        self.library = library
        self.collection = collection
    }
}

/// `GET /api/v1/nara`: whose key a search would use, `user`, `instance` or none, and with the instance's the
/// calls the user has made with it in the last day, of how many.
public struct NARAStatus: Codable, Equatable, Sendable, ResponseEncodable {
    public var key: String?
    public var quota: Quota?
    /// `FRUS_OFFLINE`: the server asks NARA nothing.
    public var offline: Bool

    public struct Quota: Codable, Equatable, Sendable {
        public var used: Int
        public var limit: Int
    }
}

/// `POST /api/v1/nara/search`'s answer: the records, in NARA's order, and whether they were kept from an
/// earlier search of the same query.
public struct NARASearchAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var results: [NARACatalogRecord]
    public var cached: Bool
}

/// Look Up's sheet, as the app's `NARACatalogLookupView` opens it: the readings of the selection, best first
/// (`NARALookupAnalyzer`), the strategy it opens on, the kit's strategies in their order with their words, and
/// the filing periods its Central files identifier strategy lists (`SourceExplorerPanels.allFilingPeriods`).
public struct LookUpAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var candidates: [Candidate]
    /// The first candidate's strategy, else Keywords in RG 59, as the sheet's `init` chooses.
    public var strategy: String
    public var strategies: [Strategy]
    public var periods: [SourceExplorerAnswer.FilingPeriodRow]

    /// One reading (`NARALookupCandidate`): the citation as printed, the text it fills the search with, its
    /// strategy, whether it was in the selection or around it, and the record the bundled indexes give it.
    public struct Candidate: Codable, Equatable, Sendable {
        public var id: String
        public var label: String
        public var query: String
        public var strategy: String
        /// `selection` or `context`.
        public var origin: String
        public var resolution: Resolution?
    }

    /// The bundled record (`ArchivalResolution`): its NAID, title and link.
    public struct Resolution: Codable, Equatable, Sendable {
        public var naId: String
        public var title: String
        public var catalogURL: String
    }

    /// A `LookupStrategy`, in the kit's words: whether it searches NARA, and so needs a key.
    public struct Strategy: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var hint: String
        public var searches: Bool
    }
}

/// Whose key a search uses, and the key, which goes no further than the kit's client.
struct NARAKey: Sendable {
    enum Owner: String, Sendable { case user, instance }
    let value: String
    let owner: Owner
}

/// The kit's key provider for one search: the key resolved for it, and each call told of as it is made, when the
/// kit's client asks for the key, which it does before each call (`NARACatalogKeyProvider`), so that a call NARA
/// refuses or never answers is counted too. The kit's `recordNARACatalogAPICall()`, after a 2xx alone, counts
/// nothing here.
private struct RequestNARAKey: NARACatalogKeyProvider {
    let key: String
    let calling: @Sendable () async -> Void

    func naraCatalogAPIKey() async throws -> String? {
        await calling()
        return key
    }
}

enum NARARoutes {
    static let searchFields: Set<String> = ["strategy", "query", "route", "lot", "recordGroup", "keywords", "library", "collection"]
    /// The longest text a search takes, in characters: far more than a citation or a series' name.
    static let longest = 1_000

    /// The group under /api/v1/nara, under /api/v1/me's guard, which lets it answer on a server that keeps no
    /// user data, whose instance key serves.
    static func add(to router: Router<APIRequestContext>, services: UserDataServices) {
        let group = router.group("/api/v1/nara").add(middleware: UserDataGuard(services: services, answersWithoutUserData: true))
        let outside = services.outside
        let now = services.now

        group.get { request, context -> EditedResponse<NARAStatus> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let key = try await key(for: user, services: services)
            var status = NARAStatus(key: key?.owner.rawValue, quota: nil, offline: outside.offline)
            if key?.owner == .instance {
                status.quota = NARAStatus.Quota(used: await outside.quota.used(by: user.id, at: now()), limit: outside.quota.limit)
            }
            return EditedResponse(headers: [.cacheControl: "no-store"], response: status)
        }

        group.post("search") { request, context -> EditedResponse<NARASearchAnswer> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let search = try await JSONBody.decode(NARASearch.self, from: request, fields: searchFields)
            let call = try Call(search)
            if outside.offline { throw OutsideServices.offlineProblem("the NARA Catalog") }
            // The app asks for the key before anything else, and says so when there is none.
            guard let key = try await key(for: user, services: services) else {
                throw problem(NARACatalogError.missingAPIKey, keepsUserData: services.enabled)
            }
            // The user's own answer kept, or their same search under way, or this one: the quota is asked only by a
            // search that will call NARA.
            let quota = outside.quota
            let userId = user.id
            let keepsUserData = services.enabled
            let session = outside.naraSession
            let answer = try await outside.answers.answer(to: call.cacheKey(for: userId), now: now) {
                try await run(call, key: key, for: userId, quota: quota, keepsUserData: keepsUserData, session: session, now: now)
            }
            return EditedResponse(headers: [.cacheControl: "no-store"],
                                  response: NARASearchAnswer(results: answer.records, cached: !answer.asked))
        }
    }

    /// The kit's call for `call`, with `key`, for `user`: with the instance's key, admitted against the user's quota
    /// first, holding the most calls it can make, each call counted as it is made; NARA's refusals as problems.
    static func run(_ call: Call, key: NARAKey, for user: String, quota: NARAQuota, keepsUserData: Bool, session: URLSession,
                    now: @escaping @Sendable () -> Date) async throws -> [NARACatalogRecord] {
        let hold: NARAQuota.Hold?
        if key.owner == .instance {
            guard let admitted = await quota.admit(user, cost: call.mostCalls, at: now()) else {
                let own = keepsUserData ? ", or add your own NARA Catalog API key in \(OutsideServices.keysPlace)" : ""
                throw APIProblem(.tooManyRequests, code: "NARA_QUOTA_REACHED",
                                 detail: "This search could take you past the \(quota.limit) requests to the NARA Catalog that this server’s key makes for each person in a day. Try again later\(own).")
            }
            hold = admitted
        } else {
            hold = nil
        }
        let provider = RequestNARAKey(key: key.value) {
            if let hold { await quota.spend(hold, at: now()) }
        }
        let client = NARACatalogClient(keyProvider: provider, urlSession: session)
        do {
            let records = try await call.run(client).map(NARACatalogRecord.init)
            if let hold { await quota.end(hold) }
            return records
        } catch {
            if let hold { await quota.end(hold) }
            // The kit's client gives every failure of a call as `networkError`, a cancelled one too. Nothing here is
            // cancelled by a client's going, which only `whileClientConnected` watches for: the search is the
            // cache's own task, and runs to its end, its answer kept and its calls counted.
            if let error = error as? NARACatalogError { throw problem(error, owner: key.owner, keepsUserData: keepsUserData) }
            // Nothing of the error is said or logged: a transport's can name the address it asked.
            throw problem(NARACatalogError.networkError(underlying: error))
        }
    }

    /// The key a search of `user`'s uses: their own, on a server that keeps user data, else the instance's,
    /// stored by an admin or else given in `FRUS_NARA_API_KEY`; nil for none.
    static func key(for user: RequestUser, services: UserDataServices) async throws -> NARAKey? {
        if services.enabled, let own = try await OutsideServices.storedKey(
            .nara, of: .user(user.id), in: services.secrets,
            unreadable: "Your stored NARA Catalog API key cannot be opened with this server’s key file. Add it again in \(OutsideServices.keysPlace).") {
            return NARAKey(value: own, owner: .user)
        }
        let stored = try await OutsideServices.storedKey(
            .nara, of: .instance, in: services.secrets,
            unreadable: "This server’s stored NARA Catalog API key cannot be opened with its key file. An admin can store it again in \(adminPlace).")
        return (stored ?? services.outside.naraEnvironmentKey).map { NARAKey(value: $0, owner: .instance) }
    }

    /// Where an admin stores the instance's key.
    static let adminPlace = "Administration ▸ Keys"

    /// A NARA Catalog error, in the kit's sentence, which names the web's place for keys where the app's names
    /// its own; never the error's underlying cause. Where the key is not the user's to change, the web's own
    /// sentence names who can: the instance's key refused, and no key on a server that keeps no user data, which
    /// has no place for a user's.
    static func problem(_ error: NARACatalogError, owner: NARAKey.Owner = .user, keepsUserData: Bool = true) -> APIProblem {
        var detail = OutsideServices.webPlace(error.errorDescription ?? "")
        switch error {
        case .missingAPIKey where !keepsUserData:
            detail = "This server has no NARA Catalog API key, and keeps no user data, so it has no place for yours. Its admin can give it one in FRUS_NARA_API_KEY."
        case .apiKeyRejected where owner == .instance:
            detail = "The NARA Catalog refused this server’s API key. "
                + (keepsUserData ? "An admin can store another in \(adminPlace), or you can add your own in \(OutsideServices.keysPlace)."
                                 : "Its admin can give it another in FRUS_NARA_API_KEY.")
        default: break
        }
        switch error {
        case .missingAPIKey: return APIProblem(.conflict, code: "NARA_KEY_REQUIRED", detail: detail)
        case .apiKeyRejected: return APIProblem(.conflict, code: "NARA_KEY_REJECTED", detail: detail)
        case .rateLimited: return APIProblem(.serviceUnavailable, code: "NARA_RATE_LIMITED", detail: detail)
        case .networkError: return APIProblem(.badGateway, code: "NARA_UNREACHABLE", detail: detail)
        case .unexpectedResponse, .decodingError: return APIProblem(.badGateway, code: "NARA_UNEXPECTED_ANSWER", detail: detail)
        }
    }

    /// A search, checked: the kit's call it makes, and the query its answer is kept under.
    struct Call: Sendable {
        enum Kind: Sendable {
            case strategy(LookupStrategy, query: String)
            /// `load()`'s three queries, with the app's sizes.
            case lotVariants(lot: String, recordGroup: String)
            case recordGroup(String, keywords: String)
            case presidentialMaterials(library: String, collection: String)
        }

        let kind: Kind

        init(_ search: NARASearch) throws {
            func text(_ name: String, _ value: String?, empty: Bool = false) throws -> String {
                guard let value else { throw invalidField(name, "is required.") }
                // As the app's sheet trims its search text.
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard empty || !trimmed.isEmpty else { throw invalidField(name, "cannot be empty.") }
                guard trimmed.count <= NARARoutes.longest else { throw invalidField(name, "may be \(NARARoutes.longest) characters at most.") }
                return trimmed
            }
            func none(_ names: [(String, String?)]) throws {
                if let (name, _) = names.first(where: { $0.1 != nil }) { throw invalidField(name, "is not a field of this search.") }
            }
            switch (search.strategy, search.route) {
            case (let raw?, nil):
                guard let strategy = LookupStrategy(rawValue: raw) else {
                    throw invalidField("strategy", "\(raw) is not a strategy: \(LookupStrategy.allCases.map(\.rawValue).joined(separator: ", ")).")
                }
                // The app's sheet opens the period links for it, and searches nothing.
                guard strategy != .centralURL else {
                    throw invalidField("strategy", "centralURL searches nothing: it opens NARA's finding aids for each filing period.")
                }
                try none([("lot", search.lot), ("recordGroup", search.recordGroup), ("keywords", search.keywords),
                          ("library", search.library), ("collection", search.collection)])
                kind = .strategy(strategy, query: try text("query", search.query))
            case (nil, let route?):
                try none([("query", search.query)])
                switch route {
                case "lotVariants":
                    try none([("keywords", search.keywords), ("library", search.library), ("collection", search.collection)])
                    kind = .lotVariants(lot: try text("lot", search.lot), recordGroup: try text("recordGroup", search.recordGroup))
                case "recordGroup":
                    try none([("lot", search.lot), ("library", search.library), ("collection", search.collection)])
                    // A collection the note names with no series searches its record group on nothing more.
                    kind = .recordGroup(try text("recordGroup", search.recordGroup), keywords: try text("keywords", search.keywords, empty: true))
                case "presidentialMaterials":
                    try none([("lot", search.lot), ("recordGroup", search.recordGroup), ("keywords", search.keywords)])
                    kind = .presidentialMaterials(library: try text("library", search.library),
                                                  collection: try text("collection", search.collection, empty: true))
                default:
                    throw invalidField("route", "\(route) is not a route: lotVariants, recordGroup or presidentialMaterials.")
                }
            case (nil, nil):
                throw invalidField("strategy", "a search names a strategy, or a route.")
            case (_?, _?):
                throw invalidField("route", "a search names a strategy or a route, not both.")
            }
        }

        /// The kit's call: a strategy's own, or the query `load()` runs, with its sizes.
        func run(_ client: NARACatalogClient) async throws -> [NARACatalogResult] {
            switch kind {
            case .strategy(let strategy, let query):
                return try await strategy.execute(query: query, client: client)
            case .lotVariants(let lot, let recordGroup):
                return try await client.resolveLotFileVariants(lotNumber: lot, recordGroup: recordGroup)
            case .recordGroup(let recordGroup, let keywords):
                return try await client.searchByRecordGroup(recordGroup, keywords: keywords, maxResults: 5)
            case .presidentialMaterials(let library, let collection):
                return try await client.searchByPresidentialMaterials(library: library, collection: collection, maxResults: 3)
            }
        }

        /// The most calls the kit's call can make of NARA, which the quota holds for it: a lot's three spellings
        /// and the phrase search after them, else one.
        var mostCalls: Int {
            switch kind {
            case .strategy(.lotFileRG59, _), .strategy(.lotFileRG84, _), .lotVariants: return 4
            case .strategy, .recordGroup, .presidentialMaterials: return 1
            }
        }

        /// What `user`'s answer is kept under: their id, then the kind and its fields, each as the search gave it,
        /// trimmed, each after its length, so that no two searches share a key whatever their fields hold. No NARA key.
        func cacheKey(for user: String) -> String {
            let parts: [String]
            switch kind {
            case .strategy(let strategy, let query): parts = ["strategy", strategy.rawValue, query]
            case .lotVariants(let lot, let recordGroup): parts = ["lotVariants", recordGroup, lot]
            case .recordGroup(let recordGroup, let keywords): parts = ["recordGroup", recordGroup, keywords]
            case .presidentialMaterials(let library, let collection): parts = ["presidentialMaterials", library, collection]
            }
            return ([user] + parts).map { "\($0.utf8.count):\($0)" }.joined()
        }
    }

    static func invalidField(_ name: String, _ detail: String) -> APIProblem {
        APIProblem(.badRequest, code: "INVALID_FIELD", detail: "\(name): \(detail)")
    }
}

// MARK: - Look Up's candidates

enum LookUpRoutes {
    /// The selection's text and its passage, as the reader sends them: `start` and `end`, the selection's
    /// offsets in the document's flat text, for a selection in the text; `blockText`, its footnote's text, for
    /// one in a footnote.
    struct Selection: Decodable {
        let text: String
        let start: Int?
        let end: Int?
        let blockText: String?
    }

    /// The longest selection the sheet reads, in characters: more than a page.
    static let longest = 20_000
    /// The longest footnote's text, in characters: the reader's bridge sends 5,000 at most (`enclosingBlockText`).
    static let longestBlock = 5_000

    /// The route answers whoever reaches the server, with no session, origin or token, as Citation Lookup does: it
    /// reads the corpus, the bundled indexes and the request's own text, keeps nothing, asks nothing outside and
    /// acts for no user, so a session would guard nothing the corpus does not give anyone. Its body must be JSON,
    /// which a page elsewhere cannot send without the browser asking first. Its work is bounded by the request, as
    /// a search's is: a selection of `longest` characters at most, whose offsets are read over as long a span at
    /// most with the app's passage around it, or a footnote's text of `longestBlock` (the log's entry, Session 22e,
    /// follow-up, has the measures).
    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources,
                    reader: ReaderService) {
        router.post("/api/v1/volumes/:volumeId/documents/:documentId/lookup") { request, context -> LookUpAnswer in
            try FormQuery(request.uri.query).refuseUnknown([])
            let document = try UserDataRoutes.document(context, resources: resources)
            // JSON, as a change's body is: a page elsewhere can send none without the browser asking first.
            try UserDataGuard.checkBody(request, limit: UserDataServices.bodyLimit)
            let selection = try await JSONBody.decode(Selection.self, from: request, fields: ["text", "start", "end", "blockText"])
            guard selection.text.count <= longest else { throw NARARoutes.invalidField("text", "may be \(longest) characters at most.") }
            if let blockText = selection.blockText, blockText.count > longestBlock {
                throw NARARoutes.invalidField("blockText", "may be \(longestBlock) characters at most.")
            }
            let context = try await passage(of: selection, in: document, reader: reader, provider: provider, resources: resources)
            // The three indexes, decoded once, and the reading, off the cooperative pool: the analyzer's work grows
            // with the lots a passage names.
            let archival = try await Blocking.run { resources.archivalIndexes }
            let text = selection.text
            return try await Blocking.run {
                answer(NARALookupAnalyzer.candidates(selection: text, context: context, centralFiles: archival.centralFiles,
                                                     volumeSources: archival.volumeSources, claimants: archival.claimants))
            }
        }
    }

    /// `lookupContext(vm:)`: a footnote's text, when the selection is in one and it has any; else the flat text
    /// from `contextBefore` before the selection to `contextAfter` after it, as the kit's offsets count them;
    /// nil when there is neither. The selection's span is read as `longest` at most, the selection's own limit, so
    /// that offsets far apart cannot make the passage a whole document's text.
    static func passage(of selection: Selection, in document: DocumentKey, reader: ReaderService, provider: ServedIndexProvider,
                        resources: ServerResources) async throws -> String? {
        if let block = selection.blockText, !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return block
        }
        guard let start = selection.start, let end = selection.end else { return nil }
        guard start >= 0, end > start else {
            // A selection outside the text with no footnote's text to read around it, as a cleared one.
            return nil
        }
        let page = try await HighlightRoutes.page(of: document, reader: reader, provider: provider, resources: resources)
        // `end - start` cannot overflow, both being at least 0, nor can `start + longest`, which is then below `end`.
        let last = end - start > longest ? start + longest : end
        // The excerpt stops at the text's end, so an end no addition can take reads to it.
        let after = NARALookupAnalyzer.contextAfter
        return flatTextExcerpt(from: page.model,
                               start: max(0, start - NARALookupAnalyzer.contextBefore),
                               end: last > Int.max - after ? Int.max : last + after)
    }

    /// The sheet's answer from the analyzer's candidates: each in its order, the strategy the sheet opens on, the
    /// kit's six strategies and the filing periods.
    static func answer(_ candidates: [NARALookupCandidate]) -> LookUpAnswer {
        let found = candidates.map { candidate in
            LookUpAnswer.Candidate(
                id: candidate.id, label: candidate.label, query: candidate.query, strategy: candidate.strategy.rawValue,
                origin: candidate.origin == .selection ? "selection" : "context",
                resolution: candidate.resolution.map { LookUpAnswer.Resolution(naId: $0.naId, title: $0.title, catalogURL: $0.catalogURL) })
        }
        let opening = candidates.first?.strategy ?? .keywordRG59
        return LookUpAnswer(
            candidates: found, strategy: opening.rawValue,
            strategies: LookupStrategy.allCases.map {
                LookUpAnswer.Strategy(id: $0.rawValue, name: $0.displayName, hint: $0.hint, searches: $0 != .centralURL)
            },
            periods: SourceExplorerPanels.allFilingPeriods.map { period in
                SourceExplorerAnswer.FilingPeriodRow(
                    id: period.id, label: period.label, url: period.url.absoluteString,
                    manuals: period.filingManuals.map { SourceExplorerAnswer.Link(url: $0.url.absoluteString, label: $0.label) })
            })
    }
}
