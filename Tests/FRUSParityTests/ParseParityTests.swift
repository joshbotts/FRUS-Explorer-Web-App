// Check 3's parse comparison: Linux parses every query of the list as the Mac app's golden file says.

import FRUSLightCore
import FRUSLightTestSupport
@testable import FRUSParity
import FTS5Schema
import Foundation
import ParityFormat
import Testing

@Suite struct ParseParityTests {
    /// Check 3 on Linux, once `scripts/make-golden` has made the expressions golden file.
    @Test func everyQueryParsesAsTheGoldenFileSays() throws {
        let status = try GoldenStatus(directory: Repository.layout.golden)
        switch status.states[.expressions] {
        case .present:
            let queries = try QueryList.load(Repository.layout.queries)
            let golden = try GoldenJSON.read(ExpressionsGolden.self, from: status.url(.expressions))
            let mismatches = ParseParity.mismatches(queries: queries, golden: golden)
            #expect(mismatches.isEmpty, "\(mismatches.count) mismatches:\n\(mismatches.map(\.description).joined(separator: "\n"))")
        case .pending(let reason):
            #expect(!reason.isEmpty)
            print("\(GoldenFile.expressions.rawValue) is pending: it waits for \(reason). Its comparison runs once the file is committed.")
        case nil:
            Issue.record("GoldenStatus has no state for \(GoldenFile.expressions.rawValue)")
        }
    }

    /// The comparison itself, on a golden file made here from the Linux parser: it passes as made,
    /// and names the query, the field and both values for each change.
    @Test func comparisonNamesEachDifference() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let golden = directory.url.appendingPathComponent("golden")
            try writePending(in: golden, except: .expressions)
            let made = Self.golden(for: Self.queries, sourceDigest: "digest")
            try GoldenJSON.write(made, to: golden.appendingPathComponent(GoldenFile.expressions.rawValue))
            let status = try GoldenStatus(directory: golden)
            #expect(status.isPresent(.expressions))

            let read = try GoldenJSON.read(ExpressionsGolden.self, from: status.url(.expressions))
            #expect(ParseParity.mismatches(queries: Self.queries, golden: read).isEmpty)

            var changed = read
            changed.queries[1].parse.expression = "\"cold\""
            changed.queries[1].parse.operands[0].rendered = "\"hot\""
            changed.queries.remove(at: 2)
            let mismatches = ParseParity.mismatches(queries: Self.queries, golden: changed)
            let linux = ParseParity.parse(Self.queries[1])
            #expect(mismatches == [
                ParseMismatch(id: "q002", field: "expression", golden: "\"\\\"cold\\\"\"", linux: ParseParity.show(linux.expression)),
                ParseMismatch(id: "q002", field: "operands[0].rendered", golden: "\"\\\"hot\\\"\"", linux: ParseParity.show(linux.operands[0].rendered)),
                ParseMismatch(id: "q003", field: "record", golden: "missing", linux: "parsed"),
            ])
        }
    }

    @Test func staleExpressionsAreReported() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let layout = RepositoryLayout(root: directory.url)
            try writePending(in: layout.golden, except: .expressions)
            try FileManager.default.createDirectory(at: layout.queries.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let lines = try Self.queries.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
            try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: layout.queries)

            var made = Self.golden(for: Self.queries, sourceDigest: "current")
            made.provenance.inputs = [RepositoryLayout.queriesPath: try Digest.sha256(contentsOf: layout.queries)]
            let url = layout.golden.appendingPathComponent(GoldenFile.expressions.rawValue)
            try GoldenJSON.write(made, to: url)
            #expect(GoldenValidation.validate(layout, sourceDigest: "current").problems == [])

            // Made from other app sources: a pin move since.
            let problems = GoldenValidation.validate(layout, sourceDigest: "moved").problems
            #expect(problems.count == 1)
            #expect(problems.first?.contains("queries.expressions.json is stale: it was made from other app sources") == true)

            // Made from another query list.
            try Data((lines.joined(separator: "\n") + "\n\n").utf8).write(to: layout.queries)
            #expect(GoldenValidation.validate(layout, sourceDigest: "current").problems
                == ["queries.expressions.json is stale: its input fixtures/parity/queries.jsonl has changed. Run scripts/make-golden"])

            // Made at another index version.
            made.provenance.indexVersion = 64
            made.provenance.inputs = [:]
            try GoldenJSON.write(made, to: url)
            #expect(GoldenValidation.validate(layout, sourceDigest: "current").problems
                == ["queries.expressions.json is stale: it was made at index version 64; the pin's is 65. Run scripts/make-golden"])
        }
    }

    @Test func parseRecordsNameEachCase() {
        let refused = ParseParity.parse(ParityQuery(id: "q1", rule: "R28", query: "NEAR(military -europe, 5)"))
        #expect(refused.expression == nil)
        #expect(refused.malformedProximity?.kind == "operatorInside")

        let dropped = ParseParity.parse(ParityQuery(id: "q2", rule: "R18", query: "cold OR -korea"))
        #expect(dropped.droppedOperands.map(\.text) == ["korea"])
        #expect(dropped.droppedOperands.allSatisfy { $0.isNegated && $0.kind == "word" && $0.source == "typed" })

        var filters = QueryFilters()
        filters.phrase = "cold war"
        filters.prefixWildcard = "negoti"
        filters.excludedTerms = ["korea"]
        let structured = ParseParity.parse(ParityQuery(id: "q3", rule: "R20", query: "soviet", filters: filters))
        #expect(structured.operands.map(\.source) == ["typed", "structured", "structured", "structured"])
        #expect(structured.operands.map(\.kind) == ["word", "phrase", "prefix", "word"])

        let exact = ParseParity.parse(ParityQuery(id: "q4", rule: "R31", query: "=Soviet =soviet"))
        #expect(exact.exactTerms == ["Soviet"])
        #expect(exact.operands.allSatisfy { $0.isExact && $0.isExactApplied })
    }

    @Test func structuredPartsMirrorTheApp() {
        var filters = QueryFilters()
        #expect(ParseParity.structuredParts(filters) == StructuredQueryParts.none)
        filters.phrase = "cold war"
        filters.excludedTerms = ["korea", "vietnam"]
        #expect(ParseParity.structuredParts(filters)
            == StructuredQueryParts(phrase: "cold war", prefixWildcard: nil, excludedTerms: ["korea", "vietnam"]))
    }

    static let queries: [ParityQuery] = {
        var phrase = QueryFilters()
        phrase.phrase = "cold war"
        phrase.excludedTerms = ["korea"]
        return [
            ParityQuery(id: "q001", rule: "R01", query: "khrushchev kennedy"),
            ParityQuery(id: "q002", rule: "R31", query: "(=treaty OR canal) =treaty"),
            ParityQuery(id: "q003", rule: "R18", query: "cold OR -korea"),
            ParityQuery(id: "q004", rule: "R28", query: "NEAR(military -europe, 5)"),
            ParityQuery(id: "q005", rule: "R20", query: "soviet", filters: phrase),
        ]
    }()

    /// An expressions golden file from the Linux parser, with the search half left empty.
    static func golden(for queries: [ParityQuery], sourceDigest: String) -> ExpressionsGolden {
        let records = queries.map { query in
            let parse = ParseParity.parse(query)
            return ExpressionRecord(id: query.id, parse: parse,
                                    search: SearchExpressionRecord(corpus: parse.expression, userContent: nil, exactTerms: parse.exactTerms, error: nil))
        }
        let provenance = Provenance(tool: "frus-parity tests", upstreamCommit: nil, appBuild: 49,
                                    indexVersion: IndexCompatibility.supportedIndexVersion, sourceDigest: sourceDigest,
                                    inputs: [:], platform: .current())
        return ExpressionsGolden(provenance: provenance, queries: records)
    }
}

/// Writes a PENDING file listing every golden file but `present`.
func writePending(in directory: URL, except present: GoldenFile...) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let lines = GoldenFile.allCases.filter { !present.contains($0) }.map { "\($0.rawValue)\tthe tests" }
    try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: directory.appendingPathComponent(GoldenStatus.pendingFile))
}
