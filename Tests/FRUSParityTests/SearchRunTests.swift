// Check 3 on Linux: FRUSCoreKit's SearchService runs every query of the list as the Mac's does,
// and compiles each as the app does, whatever its scope.

import FRUSCoreKit
import FRUSLightTestSupport
import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct SearchRunTests {
    /// Check 3's results: over the kit's fixture index, every query's count and first 50 results are
    /// the Mac's, document for document and in order, apart from documents whose Mac scores are
    /// exactly equal, which may come in any order among themselves and are reported. Scores are not
    /// compared: another platform's bm25 may round otherwise in the last bits. While the golden
    /// results wait for the owner's export, the test still checks that every query runs and that
    /// the ones the app refuses are refused.
    @Test func everyQueryReturnsTheGoldenResults() async throws {
        let queries = try QueryList.load(Repository.layout.queries)
        let records = try await FixtureIndex.results()
        #expect(records.map(\.id) == queries.map(\.id))
        let expressions = try Self.expressionsGolden()
        let refused = Set(expressions.queries.filter { $0.search.error != nil }.map(\.id))
        #expect(Set(records.filter { $0.error != nil }.map(\.id)) == refused)

        switch try GoldenValidation.load(.results, as: ResultsGolden.self, layout: Repository.layout) {
        case .present(let golden, let stale):
            #expect(stale.isEmpty, "\(stale.joined(separator: "\n"))")
            var provenance = golden.provenance
            provenance.tool = "FRUSParityTests (Linux)"
            let report = SearchParity.compare(golden: golden, candidate: ResultsGolden(provenance: provenance, queries: records))
            #expect(report.passes, "\(report.differences.map(\.description).joined(separator: "\n"))")
            #expect(report.queryCount == queries.count)
            for permutation in report.permutations { print("tie reordered: \(permutation)") }
            if stale.isEmpty, report.passes {
                print("check 3's results pass: \(report.queryCount) queries, \(report.identical.count) identical and \(report.permuted.count) reordered only within Mac tie groups; \(report.otherScores.count) with other score bits (information)")
            }
        case .pending(let reason):
            print("\(GoldenFile.results.rawValue) is pending: it waits for \(reason)")
        }
    }

    /// Check 3's expressions: every query compiles as the app compiles it, the unscoped parse and,
    /// from SearchService itself, each table's MATCH expression, the exact terms and any refusal.
    /// The 25 queries outside the default scope, which compile column-scoped expressions or search
    /// one table, are compared too. The expressions read no index, so an empty one serves, as it
    /// does for tools/mac-golden.
    @Test func everyQueryCompilesTheGoldenExpressions() async throws {
        let queries = try QueryList.load(Repository.layout.queries)
        let directory = try TemporaryDirectory()
        let service = try LinuxSearch.emptyService(database: directory.url.appendingPathComponent("frus.db"))
        let linux = try await LinuxSearch.expressions(queries, service: service)
        let golden: ExpressionsGolden
        switch try GoldenValidation.load(.expressions, as: ExpressionsGolden.self, layout: Repository.layout) {
        case .present(let file, let stale):
            #expect(stale.isEmpty, "\(stale.joined(separator: "\n"))")
            golden = file
        case .pending:
            Issue.record("\(GoldenFile.expressions.rawValue) is made from the app's source alone and must be committed, not pending: run scripts/make-golden")
            return
        }
        let mismatches = ParseParity.recordMismatches(queries: queries, golden: golden, linux: linux)
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches:\n\(mismatches.map(\.description).joined(separator: "\n"))")
        let scoped = queries.filter { !$0.filters.isDefaultScope }.count
        let refused = linux.filter { $0.search.error != nil }.count
        print("check 3's expressions: \(queries.count - Set(mismatches.map(\.id)).count) of \(queries.count) queries compile as the golden file says, \(scoped) of them outside the default scope; \(refused) refused")
        withExtendedLifetime(directory) {}
    }

    /// The query-to-parameters mapping is tools/mac-golden's, copied, since each builds its own
    /// module's `SearchParameters`. Every filter reaches its field, a query that sets none keeps the
    /// app's defaults, and a document type the app lacks is refused rather than dropped.
    @Test func everyFilterReachesItsSearchParameter() throws {
        var filters = QueryFilters()
        filters.phrase = "cold war"
        filters.prefixWildcard = "sovi"
        filters.excludedTerms = ["korea"]
        filters.volumeIds = ["frus1961-63v06"]
        filters.yearKeys = ["1961"]
        filters.dateRange = DateRangeFilter(earliest: "1961-01-01", latest: "1961-12-31")
        filters.documentType = "editorialNotesOnly"
        filters.includeFrontMatter = true
        filters.includeDocumentText = false
        filters.includeSummaries = false
        filters.includeNotes = true
        // The mapping must set every field QueryFilters has.
        #expect(Mirror(reflecting: filters).children.count == 11)
        let parameters = try LinuxSearch.parameters(ParityQuery(id: "q", rule: "R01", query: "berlin", filters: filters))
        #expect(parameters.keywords == "berlin")
        #expect(parameters.phrase == "cold war")
        #expect(parameters.prefixWildcard == "sovi")
        #expect(parameters.excludedTerms == ["korea"])
        #expect(parameters.volumeIds == ["frus1961-63v06"])
        #expect(parameters.yearKeys == ["1961"])
        #expect(parameters.dateRange?.earliest == "1961-01-01" && parameters.dateRange?.latest == "1961-12-31")
        #expect(parameters.documentTypeFilter == .editorialNotesOnly)
        #expect(parameters.includeFrontMatter && !parameters.includeDocumentText && !parameters.includeSummaries && parameters.includeNotes)

        let plain = try LinuxSearch.parameters(ParityQuery(id: "q", rule: "R01", query: "berlin"))
        #expect(plain == SearchParameters(keywords: "berlin"))

        var unknown = QueryFilters()
        unknown.documentType = "memorandaOnly"
        #expect(throws: GoldenError.self) { try LinuxSearch.parameters(ParityQuery(id: "q", rule: "R01", query: "x", filters: unknown)) }
    }

    static func expressionsGolden() throws -> ExpressionsGolden {
        try GoldenJSON.read(ExpressionsGolden.self, from: Repository.layout.golden.appendingPathComponent(GoldenFile.expressions.rawValue))
    }
}
