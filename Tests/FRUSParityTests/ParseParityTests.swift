// Check 3's parse comparison: Linux parses every query of the list as the Mac app's golden file says.

import FRUSLightCore
import FRUSLightTestSupport
@testable import FRUSParity
import FTS5Store
import Foundation
import ParityFormat
import Testing

@Suite struct ParseParityTests {
    /// Check 3 on Linux. The expressions come from the app's source alone, so the golden file is
    /// made in the session and committed: it is never pending.
    @Test func everyQueryParsesAsTheGoldenFileSays() throws {
        let status = try GoldenStatus(directory: Repository.layout.golden)
        switch status.states[.expressions] {
        case .present:
            let queries = try QueryList.load(Repository.layout.queries)
            let golden = try GoldenJSON.read(ExpressionsGolden.self, from: status.url(.expressions))
            let mismatches = ParseParity.mismatches(queries: queries, golden: golden)
            #expect(mismatches.isEmpty, "\(mismatches.count) mismatches:\n\(mismatches.map(\.description).joined(separator: "\n"))")
        case .pending:
            Issue.record("\(GoldenFile.expressions.rawValue) is made from the app's source alone and must be committed, not pending: run scripts/make-golden")
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

    /// The search half of each record is checked against the parse: the exact terms always, and
    /// in the default scope the expressions of both tables and whether the search refused it.
    @Test func searchRecordsAreCheckedAgainstTheParse() {
        var golden = Self.golden(for: Self.queries, sourceDigest: "digest")
        #expect(ParseParity.mismatches(queries: Self.queries, golden: golden).isEmpty)
        let q001 = ParseParity.parse(Self.queries[0])
        golden.queries[0].search.exactTerms = ["kennedy"]
        golden.queries[0].search.corpus = "\"kennedy\""
        golden.queries[1].search.userContent = nil
        golden.queries[1].search.error = "emptyQuery"
        golden.queries[3].search.error = nil
        // Outside the default scope only the exact terms are compared.
        golden.queries[5].search.corpus = "notes: \"treaty\""
        golden.queries[5].search.userContent = nil
        golden.queries[5].search.exactTerms = ["treaty"]
        let q002 = ParseParity.parse(Self.queries[1])
        #expect(ParseParity.mismatches(queries: Self.queries, golden: golden) == [
            ParseMismatch(id: "q001", field: "search.exactTerms", golden: "[\"kennedy\"]", linux: ParseParity.show(q001.exactTerms)),
            ParseMismatch(id: "q001", field: "search.corpus", golden: "\"\\\"kennedy\\\"\"", linux: ParseParity.show(q001.expression)),
            ParseMismatch(id: "q002", field: "search.userContent", golden: "null", linux: ParseParity.show(q002.expression)),
            ParseMismatch(id: "q002", field: "search.error", golden: "\"emptyQuery\"", linux: "an expression, so no refusal"),
            ParseMismatch(id: "q004", field: "search.error", golden: "null", linux: "no expression, so a refusal"),
            ParseMismatch(id: "q006", field: "search.exactTerms", golden: "[\"treaty\"]", linux: "[]"),
        ])
    }

    /// The comparison with the expressions SearchService compiled checks every field of every
    /// record, in every scope: here a query outside the default scope, whose search record is not
    /// the parse's, and a refusal.
    @Test func compiledRecordsAreComparedInEveryScope() {
        let golden = Self.golden(for: Self.queries, sourceDigest: "digest")
        #expect(ParseParity.recordMismatches(queries: Self.queries, golden: golden, linux: golden.queries).isEmpty)
        var linux = golden.queries
        linux[5].search.corpus = nil                       // q006 searches notes alone
        linux[5].search.userContent = "{note_text}: \"treaty\""
        linux[0].search.error = "emptyQuery"               // q001 now refused
        linux[0].search.corpus = nil
        linux.remove(at: 1)                                // q002 not compiled
        #expect(ParseParity.recordMismatches(queries: Self.queries, golden: golden, linux: linux) == [
            ParseMismatch(id: "q001", field: "search.corpus", golden: ParseParity.show(golden.queries[0].search.corpus), linux: "null"),
            ParseMismatch(id: "q001", field: "search.error", golden: "null", linux: "\"emptyQuery\""),
            ParseMismatch(id: "q002", field: "record", golden: "compiled", linux: "missing"),
            ParseMismatch(id: "q006", field: "search.corpus", golden: ParseParity.show(golden.queries[5].search.corpus), linux: "null"),
            ParseMismatch(id: "q006", field: "search.userContent", golden: ParseParity.show(golden.queries[5].search.userContent),
                          linux: ParseParity.show(linux[4].search.userContent)),
        ])
    }

    /// Values are compared as bytes: canonically equivalent text, which Swift's `==` takes as
    /// equal, is a difference.
    @Test func canonicallyEquivalentTextIsADifference() {
        func record(_ word: String) -> ParseRecord {
            ParseRecord(expression: "\"\(word)\"", exactTerms: [word], isApproximate: false, malformedProximity: nil,
                        operands: [OperandRecord(text: word, rendered: "\"\(word)\"", kind: "word", isNegated: false,
                                                 isExact: true, isExactApplied: true, source: "typed")],
                        droppedOperands: [])
        }
        let (nfc, nfd) = (record("caf\u{E9}"), record("cafe\u{301}"))
        #expect(nfc == nfd)
        #expect(ParseParity.differences(id: "q001", golden: nfc, linux: nfd).map(\.field)
            == ["expression", "exactTerms", "operands[0].text", "operands[0].rendered"])
        #expect(ParseParity.differences(id: "q001", golden: nfc, linux: nfc).isEmpty)
    }

    @Test func staleExpressionsAreReported() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let layout = RepositoryLayout(root: directory.url)
            try writePending(in: layout.golden, except: .expressions)
            let lines = try Self.queries.map(Self.line)
            try writeQueries(lines, to: layout.queries)

            var made = Self.golden(for: Self.queries, sourceDigest: "current")
            let records = Provenance.recordsKey(RepositoryLayout.queriesPath)
            made.provenance.inputs = [records: QueryList.recordDigest(Self.queries)]
            let url = layout.golden.appendingPathComponent(GoldenFile.expressions.rawValue)
            try GoldenJSON.write(made, to: url)
            #expect(GoldenValidation.validate(layout, sourceDigest: "current").problems == [])

            // Made from other app sources: a pin move since.
            let problems = GoldenValidation.validate(layout, sourceDigest: "moved").problems
            #expect(problems.count == 1)
            #expect(problems.first?.contains("queries.expressions.json is stale: it was made from other app sources") == true)

            // A changed note or rule leaves the records, and so the golden file, current.
            var renoted = Self.queries
            renoted[0].notes = "A note added since."
            renoted[1].rule = "R32"
            try writeQueries(try renoted.map(Self.line), to: layout.queries)
            #expect(GoldenValidation.validate(layout, sourceDigest: "current").problems == [])

            // Made from another query list.
            var retyped = Self.queries
            retyped[2].query = "cold OR -vietnam"
            try writeQueries(try retyped.map(Self.line), to: layout.queries)
            #expect(GoldenValidation.validate(layout, sourceDigest: "current").problems
                == ["queries.expressions.json is stale: the queries of its input fixtures/parity/queries.jsonl have changed. Run scripts/make-golden"])

            // An input recorded by its bytes changes with any byte.
            try writeQueries(lines, to: layout.queries)
            made.provenance.inputs[RepositoryLayout.queriesPath] = try Digest.sha256(contentsOf: layout.queries)
            try GoldenJSON.write(made, to: url)
            #expect(GoldenValidation.validate(layout, sourceDigest: "current").problems == [])
            try writeQueries(lines + [""], to: layout.queries)
            #expect(GoldenValidation.validate(layout, sourceDigest: "current").problems
                == ["queries.expressions.json is stale: its input fixtures/parity/queries.jsonl has changed. Run scripts/make-golden"])

            // Made at another index version.
            made.provenance.indexVersion = 64
            made.provenance.inputs = [records: QueryList.recordDigest(Self.queries)]
            try GoldenJSON.write(made, to: url)
            #expect(GoldenValidation.validate(layout, sourceDigest: "current").problems
                == ["queries.expressions.json is stale: it was made at index version 64; the pin's is 65. Run scripts/make-golden"])

            // Made without recording its query list.
            made.provenance.indexVersion = IndexCompatibility.supportedIndexVersion
            made.provenance.inputs = [:]
            try GoldenJSON.write(made, to: url)
            #expect(GoldenValidation.validate(layout, sourceDigest: "current").problems
                == ["queries.expressions.json: it was made without recording fixtures/parity/queries.jsonl#records. Run scripts/make-golden"])

            // A query list that is gone.
            made.provenance.inputs = [records: QueryList.recordDigest(Self.queries)]
            try FileManager.default.removeItem(at: layout.queries)
            #expect(GoldenValidation.staleness(of: made.provenance, file: GoldenFile.expressions.rawValue, layout: layout, sourceDigest: "current")
                == ["queries.expressions.json is stale: its input fixtures/parity/queries.jsonl no longer exists. Run scripts/make-golden"])
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
        var notes = QueryFilters()
        notes.includeDocumentText = false
        notes.includeSummaries = false
        return [
            ParityQuery(id: "q001", rule: "R01", query: "khrushchev kennedy"),
            ParityQuery(id: "q002", rule: "R31", query: "(=treaty OR canal) =treaty"),
            ParityQuery(id: "q003", rule: "R18", query: "cold OR -korea"),
            ParityQuery(id: "q004", rule: "R28", query: "NEAR(military -europe, 5)"),
            ParityQuery(id: "q005", rule: "R20", query: "soviet", filters: phrase),
            ParityQuery(id: "q006", rule: "R55", query: "treaty", filters: notes),
        ]
    }()

    /// A query as one line of a JSONL list.
    static func line(_ query: ParityQuery) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(query), as: UTF8.self)
    }

    /// An expressions golden file from the Linux parser, with the search half as the app fills it
    /// in the default scope: both tables take the parse's expression, and a query without one is
    /// refused.
    static func golden(for queries: [ParityQuery], sourceDigest: String) -> ExpressionsGolden {
        let records = queries.map { query in
            let parse = ParseParity.parse(query)
            let search = SearchExpressionRecord(corpus: parse.expression, userContent: parse.expression, exactTerms: parse.exactTerms,
                                                error: parse.expression == nil ? "emptyQuery" : nil)
            return ExpressionRecord(id: query.id, parse: parse, search: search)
        }
        let provenance = Provenance(tool: "frus-parity tests", upstreamCommit: nil, appBuild: 49,
                                    indexVersion: IndexCompatibility.supportedIndexVersion, sourceDigest: sourceDigest,
                                    inputs: [:], platform: .current())
        return ExpressionsGolden(provenance: provenance, queries: records)
    }
}

/// Writes a query list's lines, creating its folder.
func writeQueries(_ lines: [String], to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: url)
}

/// Writes a PENDING file listing every golden file but `present`.
func writePending(in directory: URL, except present: GoldenFile...) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let lines = GoldenFile.allCases.filter { !present.contains($0) }.map { "\($0.rawValue)\tthe tests" }
    try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: directory.appendingPathComponent(GoldenStatus.pendingFile))
}
