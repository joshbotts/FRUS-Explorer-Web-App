// Check 12's search times (S13b): each query's first page and its count through FRUSCoreKit's
// SearchService, over an index opened read-only and immutable as the server opens it, one after the
// other as `/api/v1/search` asks them. The same code times both platforms, on Linux in the build
// container and natively on a Mac.

import CSQLite
import FRUSCoreKit
import FTS5Store
import Foundation
import ParityFormat

public enum SearchTiming {
    /// One query's times, in seconds, and what it found.
    public struct Record: Sendable {
        public let id: String
        public let query: String
        /// The match's exact count, or nil when the kit refused the query.
        public let count: Int?
        public let error: String?
        /// The first page, by relevance, of `pageLimit` results, as the browser app asks for it.
        public let page: Double
        /// The count of the whole match, which `/api/v1/search` makes beside its page.
        public let counting: Double
        /// The 7,500 results the app keeps, which the date order and the timeline read, when asked.
        public let retained: Double?

        /// What `/api/v1/search` spends: its page and its count, one after the other on the pipeline.
        public var request: Double { page + counting }

        public var line: String {
            let text = query.count > 34 ? String(query.prefix(33)) + "…" : query
            let found = count.map { String($0) } ?? "refused"
            var line = id.padding(toLength: 6, withPad: " ", startingAt: 0)
                + text.padding(toLength: 36, withPad: " ", startingAt: 0)
                + String(repeating: " ", count: max(0, 8 - found.count)) + found
                + String(format: "   page %7.2f s   count %7.2f s   request %7.2f s", page, counting, request)
            if let retained { line += String(format: "   7,500 kept %7.2f s", retained) }
            return line
        }
    }

    /// The page the browser app asks for first, `SearchRequest.defaultLimit`.
    public static let pageLimit = 20
    /// The results the app keeps of a search, `SearchRequest.retainedLimit`.
    public static let retainedLimit = 7_500

    /// The queries of `queries` whose parse applies an exact term, which run `frus_exact_word`:
    /// `SearchService.exactTerms(from:)` reads the same parse.
    public static func exactWordQueries(_ queries: [ParityQuery]) throws -> [ParityQuery] {
        try queries.filter { query in
            let parameters = try LinuxSearch.parameters(query)
            return !FTS5InlineQueryParser.parseDetailed(parameters.keywords ?? "", columnPrefix: "",
                                                        structured: parameters.structuredQueryParts).exactTerms.isEmpty
        }
    }

    /// The server's search stack over `database`: `FTS5Store(readingDatabaseAt:)`, the pipeline's
    /// read-only open with the app's data files from `resources`, and a `SearchService` over both.
    public static func service(database: URL, resources: URL) throws -> SearchService {
        let store = try FTS5Store(readingDatabaseAt: database)
        let pipeline = try IndexingPipeline(readingIndexAt: database, fts5Store: store,
                                            resources: try IndexingResources.loading(fromDirectory: resources),
                                            volumesDirectory: nil)
        return SearchService(fts5Store: store, pipeline: pipeline)
    }

    /// Times each query in turn: its first page, then its count, as `/api/v1/search` asks the
    /// pipeline for them, and with `retained` the 7,500 results the app keeps. Each record goes to
    /// `report` as it is made.
    public static func run(_ queries: [ParityQuery], service: SearchService, retained: Bool = false,
                           report: (Record) -> Void = { _ in }) async throws -> [Record] {
        let clock = ContinuousClock()
        var records: [Record] = []
        for query in queries {
            let parameters = try LinuxSearch.parameters(query)
            var count: Int?
            var failure: String?
            var start = clock.now
            do { _ = try await service.search(parameters: parameters, limit: pageLimit, offset: 0) } catch {
                failure = String(describing: error)
            }
            let page = seconds(clock.now - start)
            start = clock.now
            do { count = try await service.searchCount(parameters: parameters) } catch {
                failure = failure ?? String(describing: error)
            }
            let counting = seconds(clock.now - start)
            var kept: Double?
            if retained, failure == nil {
                start = clock.now
                _ = try await service.search(parameters: parameters, limit: retainedLimit, offset: 0)
                kept = seconds(clock.now - start)
            }
            let record = Record(id: query.id, query: query.query, count: failure == nil ? count : nil, error: failure,
                                page: page, counting: counting, retained: kept)
            report(record)
            records.append(record)
        }
        return records
    }

    /// The run in a few lines: the queries, their requests' time in all, the median and the slowest.
    public static func summary(_ records: [Record]) -> String {
        let requests = records.map(\.request).sorted()
        guard !requests.isEmpty else { return "no queries" }
        let total = requests.reduce(0, +)
        let median = requests.count % 2 == 1
            ? requests[requests.count / 2]
            : (requests[requests.count / 2 - 1] + requests[requests.count / 2]) / 2
        var lines = [String(format: "%d queries: requests %.1f s in all, median %.2f s, slowest %.2f s; pages %.1f s, counts %.1f s",
                            records.count, total, median, requests.last!, records.map(\.page).reduce(0, +),
                            records.map(\.counting).reduce(0, +))]
        let kept = records.compactMap(\.retained)
        if !kept.isEmpty {
            lines.append(String(format: "the 7,500 kept: %.1f s in all, slowest %.2f s", kept.reduce(0, +), kept.max()!))
        }
        lines.append("the slowest requests:")
        for record in records.sorted(by: { $0.request > $1.request }).prefix(10) { lines.append("  " + record.line) }
        return lines.joined(separator: "\n")
    }

    /// Each query's count, first 50 results and tie tail through `service`, as check 3 records them, in
    /// a results file at `out` that `compare-results` reads: a change that must keep every result as it
    /// was, over a whole export, is held to it by two such files, one from before it and one from after.
    public static func writeRecords(_ queries: [ParityQuery], service: SearchService, queriesPath: String,
                                    layout: RepositoryLayout, database: URL, to out: URL) async throws -> [ResultRecord] {
        let records = try await LinuxSearch.results(queries, service: service)
        let golden = ResultsGolden(
            provenance: Provenance(tool: "frus-parity time-search --out", upstreamCommit: layout.upstreamCommit(),
                                   appBuild: Upstream.appBuild(layout.upstream), indexVersion: IndexingPipeline.currentDateIndexVersion,
                                   sourceDigest: try Upstream.sourceDigest(layout.upstream),
                                   inputs: [Provenance.recordsKey(queriesPath): QueryList.recordDigest(queries),
                                            "index": database.lastPathComponent],
                                   platform: .current(sqlite: sqliteVersion)),
            queries: records)
        try GoldenJSON.write(golden, to: out)
        return records
    }

    /// The SQLite the kit runs on: the SDK's on a Mac, libsqlite3's on Linux.
    public static var sqliteVersion: String { String(cString: sqlite3_libversion()) }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
