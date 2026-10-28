// GET /api/v1/search and /api/v1/search/inspect: the kit's search over the live index, in the order
// the reader chose, and what the Query Inspector says of it, each with the user half of the user the
// request acts for (PLAN's S17d, `SearchUsers`): their notes and summaries in the scopes searched,
// and their tags in the filter, the rows and the inspector's counts.

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird

/// One result: the draft's `SearchResult` fields, from the kit's, and what the row draws of them, as
/// the Mac's search window draws a result.
///
/// `snippet` is the document's text around the matches with `<b>` and `</b>` marking them, and is
/// not HTML-escaped: a client escapes it and puts back only the two markers. It is the kit's: the
/// window starts at the match in the document's own prose, after the heading, source note and
/// dateline its body opens with. A row whose only match is in those has the prose's opening with
/// nothing marked, and a row with no match in its body its heading and dateline (#1736).
///
/// A row draws its dateline, or where it prints none, the day or span the index dates it by
/// (`drawnDate`), as the Mac's window draws `result.dateline ?? result.drawnDate` (#1746).
public struct SearchItem: Codable, Equatable, Sendable {
    public var volumeId: String
    public var documentId: String
    public var documentNumber: String?
    public var header: String
    /// What the row names the document by: the header less a source note run on into it
    /// (`DocumentHeaderDisplay.trimmedHeader`), as the Mac's window draws it; for a row with no
    /// header, which the window would leave blank, the name the kit's rule for lists gives it
    /// (`DocumentDisplayTitle`).
    public var displayTitle: String
    /// The document's label beside its volume, "Doc 12" or "Unnumbered (d710a-1)", as the Mac's
    /// window labels a row (`CitableDocumentNumber.captionLabel`).
    public var documentLabel: String
    /// Whether the header already opens with the document's number, so the row withholds its label,
    /// as the Mac's window does (`DocumentHeaderDisplay.headerRepeatsNumber`).
    public var headerRepeatsNumber: Bool
    public var dateline: String?
    public var sourceNote: String?
    public var dateISO: String?
    /// The row's last day (`SearchResult.dateISOMax`, index version 70): the same day as `dateISO`
    /// for a document dated to a day, and the end of the span for a section's row, which the index
    /// dates by the documents it holds.
    public var dateISOMax: String?
    /// How precisely the index dates the row, `day`, `month` or `year` (`DatePrecision`), when it says.
    public var datePrecision: String?
    /// The words for the row's date, from the kit's `SearchResultDate`, as `SearchResult.drawnDate`
    /// gives them in US English, the language of the browser app's words: "July 16, 1945",
    /// "August 21, 1945 – January 22, 1946", "July 1945", "1862"; absent for a row with no date.
    public var drawnDate: String?
    public var snippet: String
    /// FTS5's bm25 for the document; lower ranks higher. Its bits survive the JSON round trip.
    public var bm25Score: Double
    public var isEditorialNote: Bool
    public var isFrontMatter: Bool
    public var subjectTagIds: [String]
    /// The tags the search's user put on the document (S17d), each once, its id in upper case, in
    /// order, as the kit reads them from the user's assignments and the app's reconcile writes a row's:
    /// none for a search that acts for no one. A row draws a chip for each the user's tags name, as
    /// the Mac's draws `UserTag.chips(for:among:)`.
    public var userTagIds: [String]

    /// The locale the server writes a row's date in: the browser app's strings are US English.
    static let locale = Locale(identifier: "en_US")

    /// What a row names `result` by: its header less a source note run on into it, or for a row with
    /// no header the name the kit's rule for lists gives it.
    static func displayTitle(of result: SearchResult) -> String {
        let trimmed = DocumentHeaderDisplay.trimmedHeader(result.header)
        return trimmed.isEmpty
            ? FRUSLightAPI.displayTitle(header: "", documentNumber: result.documentNumber,
                                        isEditorialNote: result.isEditorialNote, documentId: result.documentId)
            : trimmed
    }

    init(_ result: SearchResult) {
        volumeId = result.volumeId
        documentId = result.documentId
        documentNumber = result.documentNumber
        header = result.header
        displayTitle = Self.displayTitle(of: result)
        documentLabel = CitableDocumentNumber.captionLabel(printed: result.documentNumber, documentId: result.documentId)
        headerRepeatsNumber = DocumentHeaderDisplay.headerRepeatsNumber(result.header, number: result.documentNumber)
        dateline = result.dateline
        sourceNote = result.sourceNote
        dateISO = result.dateISO
        dateISOMax = result.dateISOMax
        datePrecision = result.datePrecision?.rawValue
        drawnDate = SearchResultDate.text(dateISO: result.dateISO, dateISOMax: result.dateISOMax,
                                          precision: result.datePrecision, locale: Self.locale)
        snippet = result.snippet
        bm25Score = result.bm25Score
        isEditorialNote = result.isEditorialNote
        isFrontMatter = result.isFrontMatter
        subjectTagIds = result.subjectTagIds
        userTagIds = result.userTagIds
    }
}

/// A choice a control offers, by its value and the kit's title for it.
public struct Choice: Codable, Equatable, Sendable {
    public var value: String
    public var title: String
}

/// A page of results, in the order asked for, with the exact count of every match.
public struct SearchResultList: Codable, Equatable, Sendable {
    /// Every document the search matches, counted by the kit's `searchCount`.
    public var total: Int
    /// Always `exact`: the count is a `COUNT(*)` over the whole match. `atLeast` is kept for a
    /// count that could not be made, as the app's method appendix keeps `floor`.
    public var countBasis: String
    public var limit: Int
    public var offset: Int
    /// How many results the app keeps of a search, and so how far a page can reach.
    public var retainedLimit: Int
    /// The order the page is cut from: a `SearchSortOrder` raw value.
    public var sort: String
    /// The orders a search offers, with the kit's label for each (`SearchSortOrder.label`).
    public var sortChoices: [Choice]
    public var items: [SearchItem]
    /// With `reviewed` (S17e): how many of the results kept the pages leave out as reviewed, as the
    /// Mac's Checklist Mode counts its hidden rows; absent outside it.
    public var hidden: Int?
    public var coverage: Coverage
}

/// What the kit compiles for a search, and what the Query Inspector says of it.
///
/// `parse` and `search` are the unscoped parse of the typed text and the structured fields, then
/// each table's MATCH expression for the request's scope, with the keys of the parity harness's
/// expression records. `inspection` is the kit's `QueryInspection` over the served index, and
/// `emptyConjuncts` the terms that match nothing on their own, when asked for.
public struct SearchInspection: Codable, Equatable, Sendable {
    public struct Parse: Codable, Equatable, Sendable {
        public var expression: String?
        public var exactTerms: [String]
        public var isApproximate: Bool
        public var malformedProximity: MalformedProximityValue?
        public var operands: [Operand]
        public var droppedOperands: [Operand]

        init(_ parsed: ParsedQuery) {
            expression = parsed.expression
            exactTerms = parsed.exactTerms
            isApproximate = parsed.isApproximate
            malformedProximity = parsed.malformedProximity.map(MalformedProximityValue.init)
            operands = parsed.operands.map(Operand.init)
            droppedOperands = parsed.droppedOperands.map(Operand.init)
        }
    }

    /// `kind` is `operatorInside` or `invalidDistance`.
    public struct MalformedProximityValue: Codable, Equatable, Sendable {
        public var kind: String
        public var text: String

        init(_ proximity: MalformedProximity) {
            switch proximity {
            case .operatorInside(let text): (kind, self.text) = ("operatorInside", text)
            case .invalidDistance(let text): (kind, self.text) = ("invalidDistance", text)
            }
        }
    }

    /// `kind` is `word`, `phrase`, `prefix` or `proximity`; `source` is `typed` or `structured`.
    public struct Operand: Codable, Equatable, Sendable {
        public var text: String
        public var rendered: String
        public var kind: String
        public var isNegated: Bool
        public var isExact: Bool
        public var isExactApplied: Bool
        public var source: String

        init(_ operand: ParsedOperand) {
            text = operand.text
            rendered = operand.rendered
            switch operand.kind {
            case .word: kind = "word"
            case .phrase: kind = "phrase"
            case .prefix: kind = "prefix"
            case .proximity: kind = "proximity"
            }
            isNegated = operand.isNegated
            isExact = operand.isExact
            isExactApplied = operand.isExactApplied
            switch operand.source {
            case .typed: source = "typed"
            case .structured: source = "structured"
            }
        }
    }

    /// `SearchService.matchExpressions(for:)`: nil for a table the scope leaves out, and the
    /// refusal, as `String(describing:)` gives it, when the kit refuses the query.
    public struct Search: Codable, Equatable, Sendable {
        public var corpus: String?
        public var userContent: String?
        public var exactTerms: [String]
        public var error: String?
    }

    /// The kit's `QueryInspection`: what the Query Inspector shows of a search, from
    /// `QueryInspector.inspect(parameters:indexedVolumeCount:)`, its cheap pass, which runs no search.
    public struct Inspection: Codable, Equatable, Sendable {
        /// The kit's `RenderedExpression`: each table's MATCH expression, and the one shown.
        public struct Expression: Codable, Equatable, Sendable {
            public var corpus: String?
            public var userContent: String?
            /// The corpus expression when there is one, else the user-content one (`displayed`).
            public var displayed: String?
            /// Whether the two tables are searched with different expressions (`expressionsDiffer`).
            public var expressionsDiffer: Bool

            init(_ expression: RenderedExpression) {
                corpus = expression.corpus
                userContent = expression.userContent
                displayed = expression.displayed
                expressionsDiffer = expression.expressionsDiffer
            }
        }

        /// The kit's `InspectedOperand`: one of the query's searchable units, with what the index
        /// knows of it.
        public struct Term: Codable, Equatable, Sendable {
            public var operand: Operand
            /// The index term its word resolves to, from SQLite's own tokenizer; nil for a phrase, a
            /// prefix, a proximity search, or a word that is more than one term.
            public var stem: String?
            /// Its exact count within the request's filters, from the expensive pass
            /// (`scopedCounts=true`); nil until counted.
            public var scopedCount: Int?
            /// How many documents of the whole index hold the stem, and how often it occurs in all,
            /// from one `fts5vocab` row; nil without a stem, or for a stem the index has no row for.
            public var corpusDocumentFrequency: Int?
            public var corpusOccurrences: Int?
            public var corpusOccurrencesPerDocument: Double?
            /// Whether the stem differs from the word as typed, so other words with that root match.
            public var isStemBroadening: Bool
            /// Whether it came from a structured field rather than the search box (the ADVANCED tag).
            public var showsStructuredTag: Bool

            init(_ term: InspectedOperand) {
                operand = Operand(term.operand)
                stem = term.stem
                scopedCount = term.scopedCount
                corpusDocumentFrequency = term.corpusDocumentFrequency
                corpusOccurrences = term.corpusOccurrences
                corpusOccurrencesPerDocument = term.corpusOccurrencesPerDocument
                isStemBroadening = term.isStemBroadening
                showsStructuredTag = term.showsStructuredTag
            }
        }

        public var expression: Expression?
        public var operands: [Term]
        /// What the query typed that the search leaves out, as exclusions with nothing to exclude from.
        public var notApplied: [Operand]
        /// How many volumes the served index holds: what every count is out of.
        public var indexedVolumeCount: Int
        public var isFilterOnly: Bool
        public var isApproximate: Bool
        public var isRefused: Bool
        /// The `NEAR(…)` that refused the query, as typed.
        public var malformedProximity: String?
        /// The kit's gates for what the inspector shows: the strip at all, its narrower-than-typed
        /// caption, its term rows, and the offer to count each term in scope.
        public var showsStrip: Bool
        public var showsApproximateCaption: Bool
        public var showsTermRows: Bool
        public var hasOperands: Bool
        public var hasUncountedOperands: Bool

        init(_ inspection: QueryInspection) {
            expression = inspection.expression.map(Expression.init)
            operands = inspection.operands.map(Term.init)
            notApplied = inspection.notApplied.map(Operand.init)
            indexedVolumeCount = inspection.indexedVolumeCount
            isFilterOnly = inspection.isFilterOnly
            isApproximate = inspection.isApproximate
            isRefused = inspection.isRefused
            malformedProximity = inspection.malformedProximity
            showsStrip = inspection.showsStrip
            showsApproximateCaption = inspection.showsApproximateCaption
            showsTermRows = inspection.showsTermRows
            hasOperands = inspection.hasOperands
            hasUncountedOperands = inspection.hasUncountedOperands
        }
    }

    public var parse: Parse
    public var search: Search
    /// Absent while no index is served: the inspector reads the index's own tokenizer and vocabulary.
    public var inspection: Inspection?
    /// With `emptyConjuncts=true`: the terms that match no document on their own under the request's
    /// filters (`QueryInspector.emptyConjuncts(parameters:)`), which name why a search found nothing.
    public var emptyConjuncts: [Operand]?
}

extension SearchResultList: ResponseEncodable {}
extension SearchInspection: ResponseEncodable {}

enum SearchRoutes {
    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources,
                    users: SearchUsers) {
        // A search runs while its client is connected: a browser that replaces it closes the
        // connection, and the kit then stops its statements, the count's, the page's and those of the
        // results kept for an order of the date, so the next search does not wait behind them (#1698).
        router.get("/api/v1/search") { request, context -> SearchResultList in
            try await search(try FormQuery(request.uri.query), request: request, context: context, provider: provider,
                             resources: resources, users: users)
        }
        // The same, with its query in the body, for one whose Checklist Mode hides more results than
        // an address holds (S17e), as /search/inspect takes a long query.
        router.post("/api/v1/search") { request, context -> SearchResultList in
            let body = try await request.body.collect(upTo: postedSearchLimit)
            let form = try FormQuery(body.readableBytes > 0 ? String(buffer: body) : request.uri.query)
            return try await search(form, request: request, context: context, provider: provider, resources: resources, users: users)
        }
        // The inspector compiles without reading the index, so it answers before an import too. Its
        // expensive passes count each term, which stops as a search does.
        router.get("/api/v1/search/inspect") { request, context -> SearchInspection in
            let form = try FormQuery(request.uri.query)
            return try await context.whileClientConnected {
                try await inspect(form, provider: provider) { try await users.user(searching: $0, for: request, context: context) }
                    inside: { try await users.inside($0, $1, for: $2, served: $3) }
            }
        }
        router.post("/api/v1/search/inspect") { request, context -> SearchInspection in
            let body = try await request.body.collect(upTo: 64 * 1_024)
            let form = try FormQuery(body.readableBytes > 0 ? String(buffer: body) : request.uri.query)
            return try await context.whileClientConnected {
                try await inspect(form, provider: provider) { try await users.user(searching: $0, for: request, context: context) }
                    inside: { try await users.inside($0, $1, for: $2, served: $3) }
            }
        }
    }

    /// The largest body `POST /api/v1/search` takes: room for every key `reviewed` may name, each
    /// escaped as a form escapes it, beside the search's fields.
    static let postedSearchLimit = 1_024 * 1_024

    /// A page of the search `form` says, with its exact count, for the user `request` acts for.
    static func search(_ form: FormQuery, request: Request, context: APIRequestContext, provider: ServedIndexProvider,
                       resources: ServerResources, users: SearchUsers) async throws -> SearchResultList {
        var asked = try SearchRequest(form: form)
        let user = try await users.user(searching: asked.parameters, for: request, context: context)
        let served = try await provider.served()
        asked.parameters = try await users.inside(asked.workingCorpusId, asked.parameters, for: user, served: served)
        let search = asked
        let scoped = try served.search(for: user)
        return try await context.whileClientConnected {
            do {
                // One count of the whole match, and the page: both through the pipeline's one
                // connection, and each kept a while, so another page of the search, or the
                // concordance of this one, asks for neither again. The page is asked for first, so
                // that in an order of the date the request joins at once the results kept of its
                // search, as a request that replaces another for the same search must to share
                // them: its count waits behind them.
                async let cut = cutPage(search, served: served, scoped: scoped)
                let total = try await served.recent.count(of: search.parameters, in: scoped)
                let page = try await cut
                return SearchResultList(total: total, countBasis: "exact", limit: search.limit, offset: search.offset,
                                        retainedLimit: SearchRequest.retainedLimit, sort: search.sort.rawValue,
                                        sortChoices: SearchSortOrder.allCases.map { Choice(value: $0.rawValue, title: $0.label) },
                                        items: page.results.map(SearchItem.init), hidden: page.hidden,
                                        coverage: Coverage(index: served.corpus, resources: resources))
            } catch let error as FTS5Error {
                throw refusal(error)
            }
        }
    }

    /// The page `search` asks for, as `scoped` searches. By relevance it is the kit's page of the match,
    /// as kept lately; in an order of the date, it is cut from the results the app keeps of the search,
    /// all of them in that order, as the Mac's window sorts what it keeps and pages it
    /// (`SearchSortOrder.sorted(_:)`).
    static func page(_ search: SearchRequest, served: ServedIndex, scoped: ServedSearch) async throws -> [SearchResult] {
        try await cutPage(search, served: served, scoped: scoped).results
    }

    /// The page `search` asks for, as ``page(_:served:scoped:)`` cuts it, and how many of the results
    /// kept it leaves out as reviewed. Outside Checklist Mode that is nil, and the page is as before.
    /// In it, the page is cut, in either order, from the results the app keeps of the search less those
    /// `reviewed` names, as the Mac's window pages its `displayedResults`, and the count is of those.
    static func cutPage(_ search: SearchRequest, served: ServedIndex, scoped: ServedSearch) async throws
        -> (results: [SearchResult], hidden: Int?) {
        switch search.sort {
        case .relevance where search.reviewed.isEmpty:
            return (try await served.recent.page(of: search, in: scoped), nil)
        case .relevance, .dateAscending, .dateDescending:
            let kept = try await served.retained.results(of: search.parameters, in: scoped)
            let shown = search.sort.sorted(kept).filter { !search.hides($0) }
            return (Array(shown.dropFirst(search.offset).prefix(search.limit)),
                    search.reviewed.isEmpty ? nil : kept.count - shown.count)
        }
    }

    /// The fields `/search/inspect` takes beside a search's: its two expensive passes.
    static let passFields: Set<String> = ["scopedCounts", "emptyConjuncts"]

    /// The most terms the Query Inspector looks up in the index. Each costs statements of its own,
    /// run one after another on the connection every search shares, and each expensive pass a count
    /// more. No query a reader types comes near it; text pasted into the box by mistake can pass it
    /// by thousands.
    static let inspectedTermLimit = 64

    /// A query the kit refuses, such as one with nothing left to search, is the request's fault: a
    /// 400 carrying the refusal. Any other error is the server's, and the problem middleware hides it.
    static func refusal(_ error: FTS5Error) -> any Error {
        switch error {
        case .emptyQuery:
            return APIProblem(.badRequest, code: "EMPTY_QUERY",
                              detail: "Nothing is left to search: the query has no terms in the parts of documents it searches.",
                              searchError: String(describing: error))
        default:
            return error
        }
    }

    /// What the kit compiles for the search `form` says, and, over the served index, the Query
    /// Inspector's account of it: its cheap pass always, and each expensive pass the form asks for,
    /// `scopedCounts` and `emptyConjuncts`, which need an index and are refused until one is served.
    /// A query of more terms than `inspectedTermLimit` is compiled, and not looked up. The passes
    /// count as the search does, with the user half of the user `user` gives for the parameters.
    static func inspect(_ form: FormQuery, provider: ServedIndexProvider,
                        user: (SearchParameters) async throws -> SearchUser?,
                        inside: (String?, SearchParameters, SearchUser?, ServedIndex?) async throws -> SearchParameters)
        async throws -> SearchInspection {
        let search = try SearchRequest(form: form, alsoTaking: passFields)
        let countsInScope = try form.bool("scopedCounts") ?? false
        let blames = try form.bool("emptyConjuncts") ?? false
        var parameters = search.parameters
        let searcher = try await user(parameters)
        let parse = FTS5InlineQueryParser.parseDetailed(parameters.keywords ?? "", columnPrefix: "",
                                                        structured: parameters.structuredQueryParts)
        var result = SearchInspection.Search(corpus: nil, userContent: nil, exactTerms: parse.exactTerms, error: nil)
        do {
            let expressions = try await compiler(provider).matchExpressions(for: parameters)
            result.corpus = expressions.corpus
            result.userContent = expressions.userContent
        } catch let error as FTS5Error {
            result.error = String(describing: error)
        }
        var inspected = SearchInspection(parse: SearchInspection.Parse(parse), search: result)
        guard parse.operands.count <= inspectedTermLimit else {
            if countsInScope || blames {
                throw APIProblem(.badRequest, code: "TOO_MANY_TERMS",
                                 detail: "The Query Inspector looks up at most \(inspectedTermLimit) terms in the index; this query has \(parse.operands.count).")
            }
            return inspected
        }
        let served = countsInScope || blames ? try await provider.served() : try await provider.servedIfReady()
        guard let served else {
            // A corpus is the user's whatever is served, and the passes that read it wait for an index.
            _ = try await inside(search.workingCorpusId, parameters, searcher, nil)
            return inspected
        }
        // Its counts are taken inside the working corpus the search runs inside, as the search counts.
        parameters = try await inside(search.workingCorpusId, parameters, searcher, served)
        let inspector = QueryInspector(searchService: try served.search(for: searcher).service)
        var inspection = await inspector.inspect(parameters: parameters, indexedVolumeCount: served.corpus.summary.volumes)
        if countsInScope {
            inspection = inspection.replacingOperands(await inspector.scopedCounts(for: inspection, parameters: parameters))
        }
        inspected.inspection = SearchInspection.Inspection(inspection)
        if blames {
            inspected.emptyConjuncts = await inspector.emptyConjuncts(parameters: parameters).map(SearchInspection.Operand.init)
        }
        return inspected
    }

    /// The served stack's search service when an index is open; otherwise one over an empty
    /// scratch index, enough for `matchExpressions(for:)`, which reads no index.
    static func compiler(_ provider: ServedIndexProvider) async throws -> SearchService {
        if let served = try await provider.servedIfReady() { return served.service }
        return try await ScratchCompiler.shared.service()
    }
}

/// A search service over a new, empty index in a temporary folder, made once, for compiling
/// queries while no index is served. It is never the corpus.
actor ScratchCompiler {
    static let shared = ScratchCompiler()
    private var made: SearchService?

    func service() throws -> SearchService {
        if let made { return made }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-light-compiler-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = directory.appendingPathComponent("compiler.db")
        let store = try FTS5Store(databaseURL: database)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: database, volumesDirectory: directory,
                                            resources: .none, defaults: InMemoryIndexingStampStore())
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        made = service
        return service
    }
}
