// Check 3's query list: every query well formed, and every rule of the manual exercised.

import FRUSLightTestSupport
@testable import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct QueryListTests {
    @Test func queryListCoversEveryRuleAndNothingElse() throws {
        let layout = Repository.layout
        let queries = try QueryList.load(layout.queries)
        let rules = try QueryList.loadRules(layout.rules)
        let text = try String(contentsOf: layout.queries, encoding: .utf8)
        let problems = QueryListValidation.problems(queries: queries, rules: rules, text: text)
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
        // docs/SPEC.md, check 3: 200 or more queries.
        #expect(queries.count >= 200)
        print("query list: \(queries.count) queries over \(rules.count) rules")
    }

    @Test func validationFindsEachProblem() throws {
        var outside = QueryFilters()
        outside.volumeIds = ["frus1894Nicaragua", "frus1900"]
        outside.dateRange = DateRangeFilter(earliest: "1961-02-30", latest: "1963")
        let queries = [
            ParityQuery(id: "q001", rule: "R01", query: "treaty"),
            ParityQuery(id: "q001", rule: "R01", query: "canal"),
            ParityQuery(id: "query2", rule: "R09", query: "cold OR war", filters: outside),
        ]
        let directory = try TemporaryDirectory()
        let rules = try withExtendedLifetime(directory) {
            let url = directory.url.appendingPathComponent("rules.tsv")
            try Data("""
                # id, source, summary
                R01\tmacOS-User-Manual.md §7.2\tWords are ANDed.
                R02\tmacOS-User-Manual.md §7.2\tWords are stemmed.
                R02\tmacOS-User-Manual.md §7.2\tTwice.

                """.utf8).write(to: url)
            return try QueryList.loadRules(url)
        }
        #expect(QueryListValidation.problems(queries: queries, rules: rules) == [
            "q001 is used twice",
            "query2 is not of the form q001",
            "rule R02 is listed twice",
            "query2 exercises R09, which rules.tsv does not list",
            "rule R02 has no query",
            "query2 filters on frus1900, which is not a fixture volume",
            "query2 has the date 1961-02-30, which is neither yyyy-MM-dd nor yyyy",
        ])
    }

    @Test func validationFindsKeysTheDecoderWouldDrop() {
        let text = """
            {"id": "q001", "rule": "R01", "query": "treaty", "filters": {"volumeID": ["frus1894Nicaragua"]}}
            {"id": "q002", "rule": "R01", "query": "canal", "filter": {}, "filters": {"dateRange": {"earliest": "1894", "end": "1895"}}}
            {"id": "q003", "rule": "R01", "query": "war", "filters": {"phrase": "cold war", "includeNotes": false}, "notes": ""}
            """
        #expect(QueryListValidation.unknownKeys(text) == [
            "line 1 has keys the query format does not read: filters.volumeID",
            "line 2 has keys the query format does not read: filter, filters.dateRange.end",
        ])
    }

    @Test(arguments: [("1961-02-28", true), ("1964-02-29", true), ("1900-02-29", false), ("2000-02-29", true),
                      ("1961", true), ("1961-2-28", false), ("1961-13-01", false), ("1961-00-10", false),
                      ("61", false), ("1961-02", false), ("", false), ("+961", false)])
    func datesAreDaysOrYears(_ text: String, _ valid: Bool) {
        #expect(QueryListValidation.isDate(text) == valid)
    }

    /// `recordText` lists the fields by hand: a field added to `QueryFilters` or `ParityQuery`
    /// fails here until it is added there, or, like the rule and the notes, ruled out.
    @Test func recordTextCoversEveryField() {
        let filterFields = Mirror(reflecting: QueryFilters()).children.compactMap(\.label)
        #expect(filterFields == ["phrase", "prefixWildcard", "excludedTerms", "volumeIds", "yearKeys", "dateRange",
                                 "documentType", "includeFrontMatter", "includeDocumentText", "includeSummaries",
                                 "includeNotes"], "QueryFilters changed: update QueryList.recordText")
        let queryFields = Mirror(reflecting: ParityQuery(id: "", rule: "", query: "")).children.compactMap(\.label)
        #expect(queryFields == ["id", "rule", "query", "filters", "notes"], "ParityQuery changed: update QueryList.recordText")
    }

    /// A fixed vector: the same digest on Linux and macOS, from text built by hand.
    @Test func recordDigestIsAFixedVector() {
        var filters = QueryFilters()
        filters.phrase = "cold war"
        filters.prefixWildcard = "negoti"
        filters.excludedTerms = ["korea", "vietnam"]
        filters.volumeIds = []
        filters.yearKeys = ["1961"]
        filters.dateRange = DateRangeFilter(earliest: "1961-01-01", latest: nil)
        filters.documentType = "telegram"
        filters.includeFrontMatter = false
        filters.includeDocumentText = true
        filters.includeNotes = false
        var emptyRange = QueryFilters()
        emptyRange.dateRange = DateRangeFilter(earliest: nil, latest: nil)
        let queries = [
            ParityQuery(id: "q001", rule: "R01", query: "berlin crisis", notes: "The manual's example."),
            ParityQuery(id: "q002", rule: "R20", query: "caf\u{E9} \"cold\nwar\"", filters: filters),
            ParityQuery(id: "q003", rule: "R42", query: "cafe\u{301}", filters: emptyRange),
        ]
        let text = """
            4:q001 13:berlin crisis - - - - - - - - - - -
            4:q002 16:caf\u{E9} "cold
            war" 8:cold war 6:negoti 2 5:korea 7:vietnam 0 1 4:1961 + 10:1961-01-01 - 8:telegram 0 1 - 0
            4:q003 6:cafe\u{301} - - - - - + - - - - - - -

            """
        #expect(Array(QueryList.recordText(queries).utf8) == Array(text.utf8))
        #expect(QueryList.recordDigest(queries) == "de7a897c169b023a50cabbbee21bdcf29c5e92cef1e6acd13e318d77aa2ff8b0")

        // The rule and the notes do not change it; the text, by its bytes, and the filters do.
        var renoted = queries
        renoted[0].rule = "R02"
        renoted[1].notes = "A note."
        #expect(QueryList.recordDigest(renoted) == QueryList.recordDigest(queries))
        var composed = queries
        composed[2].query = "caf\u{E9}"
        #expect(composed == queries)
        #expect(QueryList.recordDigest(composed) == "3308129c9a6753fedb13aca8aa93d2ba05aba6631d5e8b0c668343d10c49ad77")
        var unranged = queries
        unranged[2].filters.dateRange = nil
        #expect(QueryList.recordDigest(unranged) != QueryList.recordDigest(queries))
        var reordered = queries
        reordered.swapAt(0, 1)
        #expect(QueryList.recordDigest(reordered) != QueryList.recordDigest(queries))
    }

    @Test func idsAreQAndDigits() {
        #expect(QueryListValidation.isQueryId("q001"))
        #expect(QueryListValidation.isQueryId("q1200"))
        #expect(!QueryListValidation.isQueryId("q01"))
        #expect(!QueryListValidation.isQueryId("Q001"))
        #expect(!QueryListValidation.isQueryId("q00a"))
    }
}
