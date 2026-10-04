// Check 3 on Linux: the app's query parser, compiled from the submodule, against the golden parse.
//
// The parse depends on the query text and the structured fields alone, not on any index or scope,
// so Linux compares it for every query before SearchService runs there (session 6).

import FTS5Schema
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
            mismatches += differences(id: query.id, golden: record.parse, linux: parse(query))
        }
        return mismatches
    }

    /// The fields of two parse records that differ.
    public static func differences(id: String, golden: ParseRecord, linux: ParseRecord) -> [ParseMismatch] {
        var mismatches: [ParseMismatch] = []
        func compare<T: Encodable & Equatable>(_ field: String, _ a: T, _ b: T) {
            if a != b { mismatches.append(ParseMismatch(id: id, field: field, golden: show(a), linux: show(b))) }
        }
        compare("expression", golden.expression, linux.expression)
        compare("exactTerms", golden.exactTerms, linux.exactTerms)
        compare("isApproximate", golden.isApproximate, linux.isApproximate)
        compare("malformedProximity", golden.malformedProximity, linux.malformedProximity)
        for (field, a, b) in [("operands", golden.operands, linux.operands),
                              ("droppedOperands", golden.droppedOperands, linux.droppedOperands)] {
            guard a.count == b.count else {
                compare(field, a, b)
                continue
            }
            for (index, (x, y)) in zip(a, b).enumerated() where x != y {
                let name = "\(field)[\(index)]"
                compare("\(name).text", x.text, y.text)
                compare("\(name).rendered", x.rendered, y.rendered)
                compare("\(name).kind", x.kind, y.kind)
                compare("\(name).isNegated", x.isNegated, y.isNegated)
                compare("\(name).isExact", x.isExact, y.isExact)
                compare("\(name).isExactApplied", x.isExactApplied, y.isExactApplied)
                compare("\(name).source", x.source, y.source)
            }
        }
        return mismatches
    }

    /// A value as compact JSON, so strings show their quotes and nil shows as null.
    static func show<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? String(describing: value)
    }
}
