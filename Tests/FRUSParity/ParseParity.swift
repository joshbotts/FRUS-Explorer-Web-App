// Check 3 on Linux: the app's query parser, compiled from the submodule, against the golden parse.
//
// The parse depends on the query text and the structured fields alone, not on any index or scope,
// so it is compared for every query without a search service: `mismatches(queries:golden:)`, which
// `frus-parity check-golden` runs. Since session 6's pin move SearchService runs on Linux, and
// `recordMismatches(queries:golden:linux:)` compares what it compiles too, in every scope.

import FTS5Store
import Foundation
import ParityFormat

extension ParseRecord {
    /// A `ParsedQuery`, field for field, with each enum case as its name.
    public init(parsed: ParsedQuery) {
        self.init(
            expression: parsed.expression,
            exactTerms: parsed.exactTerms,
            isApproximate: parsed.isApproximate,
            malformedProximity: parsed.malformedProximity.map(MalformedProximityRecord.init(proximity:)),
            operands: parsed.operands.map(OperandRecord.init(operand:)),
            droppedOperands: parsed.droppedOperands.map(OperandRecord.init(operand:)))
    }
}

extension MalformedProximityRecord {
    init(proximity: MalformedProximity) {
        switch proximity {
        case .operatorInside(let text): self.init(kind: "operatorInside", text: text)
        case .invalidDistance(let text): self.init(kind: "invalidDistance", text: text)
        }
    }
}

extension OperandRecord {
    init(operand: ParsedOperand) {
        let kind: String
        switch operand.kind {
        case .word: kind = "word"
        case .phrase: kind = "phrase"
        case .prefix: kind = "prefix"
        case .proximity: kind = "proximity"
        }
        let source: String
        switch operand.source {
        case .typed: source = "typed"
        case .structured: source = "structured"
        }
        self.init(text: operand.text, rendered: operand.rendered, kind: kind, isNegated: operand.isNegated,
                  isExact: operand.isExact, isExactApplied: operand.isExactApplied, source: source)
    }
}

/// One field where the Linux parse differs from the golden one.
public struct ParseMismatch: Equatable, Sendable, CustomStringConvertible {
    public var id: String
    /// The field, such as `expression` or `operands[2].rendered`.
    public var field: String
    public var golden: String
    public var linux: String

    public init(id: String, field: String, golden: String, linux: String) {
        self.id = id
        self.field = field
        self.golden = golden
        self.linux = linux
    }

    public var description: String { "\(id) \(field): golden \(golden), Linux \(linux)" }
}

public enum ParseParity {
    /// The structured fields as `SearchParameters.structuredQueryParts` passes them: an absent
    /// excluded-terms list is the app's default, an empty one.
    public static func structuredParts(_ filters: QueryFilters) -> StructuredQueryParts {
        StructuredQueryParts(phrase: filters.phrase, prefixWildcard: filters.prefixWildcard,
                             excludedTerms: filters.excludedTerms ?? [])
    }

    /// The query's parse as `SearchService.parsedQuery(for:)` makes it: unscoped, the typed text
    /// and the structured fields together.
    public static func parse(_ query: ParityQuery) -> ParseRecord {
        ParseRecord(parsed: FTS5InlineQueryParser.parseDetailed(
            query.query, columnPrefix: "", structured: structuredParts(query.filters)))
    }

    /// Every field where Linux parses a query differently from the golden file, and every query
    /// the golden file lacks or holds twice. Empty when check 3's parse comparison passes.
    ///
    /// Besides the parse, it checks what the parse decides of the golden search record: the exact
    /// terms of every query, and for a query in the default scope, its MATCH expressions, which
    /// are the unscoped parse's for both tables, and whether the search refused it, which it does
    /// when the parse has no expression. A query outside the default scope compiles
    /// column-scoped expressions inside SearchService, which `recordMismatches` compares.
    public static func mismatches(queries: [ParityQuery], golden: ExpressionsGolden) -> [ParseMismatch] {
        var records: [String: ExpressionRecord] = [:]
        var mismatches: [ParseMismatch] = []
        for record in golden.queries {
            if records[record.id] != nil {
                mismatches.append(ParseMismatch(id: record.id, field: "id", golden: "listed twice", linux: "-"))
            }
            records[record.id] = record
        }
        for query in queries {
            guard let record = records[query.id] else {
                mismatches.append(ParseMismatch(id: query.id, field: "record", golden: "missing", linux: "parsed"))
                continue
            }
            let linux = parse(query)
            mismatches += differences(id: query.id, golden: record.parse, linux: linux)
            let search = record.search
            mismatches += compare(id: query.id, field: "search.exactTerms", search.exactTerms, linux.exactTerms)
            if query.filters.isDefaultScope {
                mismatches += compare(id: query.id, field: "search.corpus", search.corpus, linux.expression)
                mismatches += compare(id: query.id, field: "search.userContent", search.userContent, linux.expression)
                if (search.error != nil) != (linux.expression == nil) {
                    mismatches.append(ParseMismatch(
                        id: query.id, field: "search.error", golden: show(search.error),
                        linux: linux.expression == nil ? "no expression, so a refusal" : "an expression, so no refusal"))
                }
            }
        }
        return mismatches
    }

    /// Every field where the expressions Linux compiled differ from the golden file's, for every
    /// query whatever its scope, and every query either lacks or holds twice: the parse, and the
    /// search record SearchService made from it, the MATCH expression for each table, the exact
    /// terms and the error. `linux` is `LinuxSearch.expressions`' records. Empty when check 3's
    /// expressions comparison passes. `mismatches(queries:golden:)` checks what the parse alone
    /// decides, for `frus-parity check-golden`, which runs no search service.
    public static func recordMismatches(queries: [ParityQuery], golden: ExpressionsGolden,
                                        linux: [ExpressionRecord]) -> [ParseMismatch] {
        var mismatches: [ParseMismatch] = []
        func index(_ records: [ExpressionRecord], side: String) -> [String: ExpressionRecord] {
            var byID: [String: ExpressionRecord] = [:]
            for record in records {
                if byID[record.id] != nil {
                    mismatches.append(ParseMismatch(id: record.id, field: "id",
                                                    golden: side == "golden" ? "listed twice" : "-",
                                                    linux: side == "Linux" ? "listed twice" : "-"))
                }
                byID[record.id] = record
            }
            return byID
        }
        let goldenRecords = index(golden.queries, side: "golden")
        let linuxRecords = index(linux, side: "Linux")
        for query in queries {
            switch (goldenRecords[query.id], linuxRecords[query.id]) {
            case (nil, nil):
                mismatches.append(ParseMismatch(id: query.id, field: "record", golden: "missing", linux: "missing"))
            case (nil, _?):
                mismatches.append(ParseMismatch(id: query.id, field: "record", golden: "missing", linux: "compiled"))
            case (_?, nil):
                mismatches.append(ParseMismatch(id: query.id, field: "record", golden: "compiled", linux: "missing"))
            case (let golden?, let linux?):
                mismatches += differences(id: query.id, golden: golden.parse, linux: linux.parse)
                mismatches += compare(id: query.id, field: "search.corpus", golden.search.corpus, linux.search.corpus)
                mismatches += compare(id: query.id, field: "search.userContent", golden.search.userContent, linux.search.userContent)
                mismatches += compare(id: query.id, field: "search.exactTerms", golden.search.exactTerms, linux.search.exactTerms)
                mismatches += compare(id: query.id, field: "search.error", golden.search.error, linux.search.error)
            }
        }
        return mismatches
    }

    /// The fields of two parse records that differ. Values are compared as their JSON bytes,
    /// never by Swift's `==`, which takes canonically equivalent strings, such as `é` and `e`
    /// with a combining accent, as equal.
    public static func differences(id: String, golden: ParseRecord, linux: ParseRecord) -> [ParseMismatch] {
        var mismatches: [ParseMismatch] = []
        mismatches += compare(id: id, field: "expression", golden.expression, linux.expression)
        mismatches += compare(id: id, field: "exactTerms", golden.exactTerms, linux.exactTerms)
        mismatches += compare(id: id, field: "isApproximate", golden.isApproximate, linux.isApproximate)
        mismatches += compare(id: id, field: "malformedProximity", golden.malformedProximity, linux.malformedProximity)
        for (field, a, b) in [("operands", golden.operands, linux.operands),
                              ("droppedOperands", golden.droppedOperands, linux.droppedOperands)] {
            guard a.count == b.count else {
                mismatches += compare(id: id, field: field, a, b)
                continue
            }
            for (index, (x, y)) in zip(a, b).enumerated() where json(x) != json(y) {
                let name = "\(field)[\(index)]"
                mismatches += compare(id: id, field: "\(name).text", x.text, y.text)
                mismatches += compare(id: id, field: "\(name).rendered", x.rendered, y.rendered)
                mismatches += compare(id: id, field: "\(name).kind", x.kind, y.kind)
                mismatches += compare(id: id, field: "\(name).isNegated", x.isNegated, y.isNegated)
                mismatches += compare(id: id, field: "\(name).isExact", x.isExact, y.isExact)
                mismatches += compare(id: id, field: "\(name).isExactApplied", x.isExactApplied, y.isExactApplied)
                mismatches += compare(id: id, field: "\(name).source", x.source, y.source)
            }
        }
        return mismatches
    }

    /// One mismatch when the two values' JSON bytes differ, or none.
    static func compare<T: Encodable>(id: String, field: String, _ golden: T, _ linux: T) -> [ParseMismatch] {
        json(golden) == json(linux) ? [] : [ParseMismatch(id: id, field: field, golden: show(golden), linux: show(linux))]
    }

    /// A value as compact JSON with sorted keys, the bytes `compare` compares.
    static func json<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try? encoder.encode(value)
    }

    /// A value as compact JSON, so strings show their quotes and nil shows as null.
    /// A value as JSON, with each non-ASCII scalar escaped, so that `é` and `e` with a combining
    /// accent print differently.
    static func show<T: Encodable>(_ value: T) -> String {
        let text = json(value).map { String(decoding: $0, as: UTF8.self) } ?? String(describing: value)
        return text.unicodeScalars.map { $0.isASCII ? String($0) : "\\u{\(String($0.value, radix: 16))}" }.joined()
    }
}
