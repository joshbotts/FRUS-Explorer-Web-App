// Check 3 on Linux: the query list run through FRUSCoreKit's SearchService, as tools/mac-golden runs
// it through the app's on the Mac. The results go through ParityFormat's `ResultsLoop`, which the
// golden tool runs too; the expressions are made as its `expressions` command makes them.

import FRUSCoreKit
import FTS5Store
import Foundation
import ParityFormat

public enum LinuxSearch {
    /// The `SearchParameters` a parity query sets: its text, and each filter it names. A filter it
    /// leaves out keeps the app's default. This is tools/mac-golden's `searchParameters(_:)`, which
    /// builds the app module's own type and so cannot be shared; a test checks every field here.
    public static func parameters(_ query: ParityQuery) throws -> SearchParameters {
        let filters = query.filters
        var parameters = SearchParameters(keywords: query.query)
        parameters.phrase = filters.phrase
        parameters.prefixWildcard = filters.prefixWildcard
        if let excluded = filters.excludedTerms { parameters.excludedTerms = excluded }
        parameters.volumeIds = filters.volumeIds
        parameters.yearKeys = filters.yearKeys
        if let range = filters.dateRange { parameters.dateRange = DateRange(earliest: range.earliest, latest: range.latest) }
        if let type = filters.documentType {
            guard let filter = DocumentTypeFilter(rawValue: type) else {
                throw GoldenError.malformed(RepositoryLayout.queriesPath, "\(query.id): \(type) is not a DocumentTypeFilter")
            }
            parameters.documentTypeFilter = filter
        }
        if let value = filters.includeFrontMatter { parameters.includeFrontMatter = value }
        if let value = filters.includeDocumentText { parameters.includeDocumentText = value }
        if let value = filters.includeSummaries { parameters.includeSummaries = value }
        if let value = filters.includeNotes { parameters.includeNotes = value }
        return parameters
    }

    /// Each query's count, first 50 results and tie tail, in list order.
    public static func results(_ queries: [ParityQuery], service: SearchService) async throws -> [ResultRecord] {
        var records: [ResultRecord] = []
        for query in queries {
            let parameters = try parameters(query)
            records.append(await ResultsLoop.record(
                id: query.id,
                count: { try await service.searchCount(parameters: parameters) },
                page: { limit, offset in
                    try await service.search(parameters: parameters, limit: limit, offset: offset)
                        .map { SearchHit(volume: $0.volumeId, document: $0.documentId, score: $0.bm25Score) }
                }))
        }
        return records
    }

    /// Each query's compiled expressions, in list order: the unscoped parse, as
    /// `SearchService.parsedQuery(for:)` makes it from the typed text and the structured fields, and
    /// what `matchExpressions(for:)` returns or throws for the query's scope, with the parse's exact
    /// terms, which are `SearchService.exactTerms(from:)`.
    public static func expressions(_ queries: [ParityQuery], service: SearchService) async throws -> [ExpressionRecord] {
        var records: [ExpressionRecord] = []
        for query in queries {
            let parameters = try parameters(query)
            let parse = ParseRecord(parsed: FTS5InlineQueryParser.parseDetailed(
                parameters.keywords ?? "", columnPrefix: "", structured: parameters.structuredQueryParts))
            var search = SearchExpressionRecord(corpus: nil, userContent: nil, exactTerms: parse.exactTerms, error: nil)
            do {
                let expressions = try await service.matchExpressions(for: parameters)
                search.corpus = expressions.corpus
                search.userContent = expressions.userContent
            } catch {
                search.error = String(describing: error)
            }
            records.append(ExpressionRecord(id: query.id, parse: parse, search: search))
        }
        return records
    }

    /// A search service over a new, empty index at `database`, with no data files: enough for
    /// `matchExpressions(for:)`, which compiles a query and reads no index, as tools/mac-golden's
    /// expressions use an empty database.
    public static func emptyService(database: URL) throws -> SearchService {
        let store = try FTS5Store(databaseURL: database)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: database,
                                            volumesDirectory: database.deletingLastPathComponent(),
                                            resources: .none, defaults: InMemoryIndexingStampStore())
        return SearchService(fts5Store: store, pipeline: pipeline)
    }
}
