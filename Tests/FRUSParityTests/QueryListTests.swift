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

    @Test func idsAreQAndDigits() {
        #expect(QueryListValidation.isQueryId("q001"))
        #expect(QueryListValidation.isQueryId("q1200"))
        #expect(!QueryListValidation.isQueryId("q01"))
        #expect(!QueryListValidation.isQueryId("Q001"))
        #expect(!QueryListValidation.isQueryId("q00a"))
    }
}
