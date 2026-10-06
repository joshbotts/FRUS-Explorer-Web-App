// GET /api/v1/search and /api/v1/search/inspect: the kit's search over the live index, and what it compiles.

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird

/// One result: the draft's `SearchResult` fields, from the kit's.
///
/// `snippet` is the document's text around the matches with `<b>` and `</b>` marking them, and is
/// not HTML-escaped: a client escapes it and puts back only the two markers.
public struct SearchItem: Codable, Equatable, Sendable {
    public var volumeId: String
    public var documentId: String
    public var documentNumber: String?
    public var header: String
    public var dateline: String?
    public var sourceNote: String?
    public var dateISO: String?
    public var snippet: String
    /// FTS5's bm25 for the document; lower ranks higher. Its bits survive the JSON round trip.
    public var bm25Score: Double
    public var isEditorialNote: Bool
    public var isFrontMatter: Bool
    public var subjectTagIds: [String]
    public var userTagIds: [String]

    init(_ result: SearchResult) {
        volumeId = result.volumeId
        documentId = result.documentId
        documentNumber = result.documentNumber
        header = result.header
        dateline = result.dateline
        sourceNote = result.sourceNote
        dateISO = result.dateISO
        snippet = result.snippet
        bm25Score = result.bm25Score
        isEditorialNote = result.isEditorialNote
        isFrontMatter = result.isFrontMatter
        subjectTagIds = result.subjectTagIds
        userTagIds = result.userTagIds
    }
}

/// A page of results, best first, with the exact count of every match.
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
    public var items: [SearchItem]
    public var coverage: Coverage
}

/// What the kit compiles for a search: the unscoped parse of the typed text and the structured
/// fields, then each table's MATCH expression for the request's scope, as the Query Inspector
/// shows them. The keys are those of the parity harness's expression records.
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

    public var parse: Parse
    public var search: Search
}

extension SearchResultList: ResponseEncodable {}
extension SearchInspection: ResponseEncodable {}

enum SearchRoutes {
    static func add(to router: Router<BasicRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/search") { request, _ -> SearchResultList in
            let search = try SearchRequest(formEncoded: request.uri.query)
            let served = try await provider.served()
            do {
                // One count of the whole match, then the page: both through the pipeline's one connection.
                let total = try await served.service.searchCount(parameters: search.parameters)
                let results = try await served.service.search(parameters: search.parameters, limit: search.limit, offset: search.offset)
                return SearchResultList(total: total, countBasis: "exact", limit: search.limit, offset: search.offset,
                                        retainedLimit: SearchRequest.retainedLimit, items: results.map(SearchItem.init),
                                        coverage: Coverage(index: served.corpus, resources: resources))
            } catch let error as FTS5Error {
                throw refusal(error)
            }
        }
        // The inspector compiles without reading the index, so it answers before an import too.
        router.get("/api/v1/search/inspect") { request, _ -> SearchInspection in
            try await inspect(SearchRequest(formEncoded: request.uri.query), provider: provider)
        }
        router.post("/api/v1/search/inspect") { request, context -> SearchInspection in
            let body = try await request.body.collect(upTo: 64 * 1_024)
            let form = body.readableBytes > 0 ? String(buffer: body) : request.uri.query
            return try await inspect(SearchRequest(formEncoded: form), provider: provider)
        }
    }

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

    static func inspect(_ search: SearchRequest, provider: ServedIndexProvider) async throws -> SearchInspection {
        let parameters = search.parameters
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
        return SearchInspection(parse: SearchInspection.Parse(parse), search: result)
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
