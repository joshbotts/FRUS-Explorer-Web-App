// Check 3: the query list, and the golden records for its compiled expressions and results.

import Foundation

/// One line of `fixtures/parity/queries.jsonl`.
public struct ParityQuery: Codable, Equatable, Sendable {
    /// `q001`, `q002`, …: unique, and stable once a golden file holds it.
    public var id: String
    /// The rule it exercises, from `fixtures/parity/rules.tsv`.
    public var rule: String
    /// The search box text.
    public var query: String
    public var filters: QueryFilters
    public var notes: String?

    public init(id: String, rule: String, query: String, filters: QueryFilters = QueryFilters(), notes: String? = nil) {
        self.id = id
        self.rule = rule
        self.query = query
        self.filters = filters
        self.notes = notes
    }
}

/// The `SearchParameters` fields a query sets besides its text. A field left out takes the app's
/// default: every `include…` switch on, no other filter.
public struct QueryFilters: Codable, Equatable, Sendable {
    /// Structured fields, which the parser reads with the typed text (`StructuredQueryParts`).
    public var phrase: String?
    public var prefixWildcard: String?
    public var excludedTerms: [String]?
    /// Filters applied in SQL.
    public var volumeIds: [String]?
    public var yearKeys: [String]?
    public var dateRange: DateRangeFilter?
    /// A `DocumentTypeFilter` raw value.
    public var documentType: String?
    public var includeFrontMatter: Bool?
    /// The content scope: the three Search in switches.
    public var includeDocumentText: Bool?
    public var includeSummaries: Bool?
    public var includeNotes: Bool?

    public init() {}

    /// True when the query searches the app's default scope, all three switches on. For those the
    /// compiled expressions are the unscoped parse's, so Linux can compare them before SearchService
    /// runs there (session 6).
    public var isDefaultScope: Bool {
        (includeDocumentText ?? true) && (includeSummaries ?? true) && (includeNotes ?? true)
    }
}

public struct DateRangeFilter: Codable, Equatable, Sendable {
    public var earliest: String?
    public var latest: String?

    public init(earliest: String?, latest: String?) {
        self.earliest = earliest
        self.latest = latest
    }
}

/// One line of `fixtures/parity/rules.tsv`: a search rule from the user manual's section 7.2, or
/// a behaviour the list covers beyond it.
public struct ParityRule: Equatable, Sendable {
    public var id: String
    /// Where the rule is stated, such as `macOS-User-Manual.md §7.2`.
    public var source: String
    public var summary: String
}

public enum QueryList {
    /// Reads a JSONL query list. Blank lines are ignored; any other line must decode.
    public static func load(_ url: URL) throws -> [ParityQuery] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var queries: [ParityQuery] = []
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
        where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            do {
                queries.append(try JSONDecoder().decode(ParityQuery.self, from: Data(line.utf8)))
            } catch {
                throw GoldenError.malformed(url.lastPathComponent, "line \(index + 1): \(error)")
            }
        }
        return queries
    }

    /// Reads the rules file: tab-separated id, source and summary, with `#` comment lines.
    public static func loadRules(_ url: URL) throws -> [ParityRule] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var rules: [ParityRule] = []
        for (index, line) in text.split(separator: "\n").enumerated() where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 3, fields.allSatisfy({ !$0.isEmpty }) else {
                throw GoldenError.malformed(url.lastPathComponent, "line \(index + 1) needs three tab-separated fields")
            }
            rules.append(ParityRule(id: fields[0], source: fields[1], summary: fields[2]))
        }
        return rules
    }

    /// SHA-256 of `recordText(queries)`: what a golden file made from the list records under
    /// `Provenance.recordsKey`, so that a changed note or rule leaves it current.
    public static func recordDigest(_ queries: [ParityQuery]) -> String {
        Digest.sha256(recordText(queries))
    }

    /// The fields that decide a query's results, as text built by hand, so that it is the same
    /// bytes on every platform (JSONEncoder escapes differently on Linux and macOS). One line per
    /// query, in list order: its id, its text, then each `QueryFilters` field in declaration order,
    /// separated by spaces. A string is its length in UTF-8 bytes, a colon and its bytes; an absent
    /// value is `-`; a list is its count, then its strings; a switch is `0` or `1`. A date range is
    /// `-` when absent, and otherwise `+` and its two bounds: an empty range is not an absent one,
    /// since an active range leaves out undated documents (IndexingPipeline.swift:4351-4354). The
    /// rule and the notes are left out: they do not change what the app returns.
    public static func recordText(_ queries: [ParityQuery]) -> String {
        func string(_ value: String?) -> String { value.map { "\($0.utf8.count):\($0)" } ?? "-" }
        func list(_ values: [String]?) -> String {
            values.map { ([String($0.count)] + $0.map(string)).joined(separator: " ") } ?? "-"
        }
        func flag(_ value: Bool?) -> String { value.map { $0 ? "1" : "0" } ?? "-" }
        var text = ""
        for query in queries {
            let filters = query.filters
            let fields = [
                string(query.id), string(query.query),
                string(filters.phrase), string(filters.prefixWildcard), list(filters.excludedTerms),
                list(filters.volumeIds), list(filters.yearKeys),
                filters.dateRange.map { "+ \(string($0.earliest)) \(string($0.latest))" } ?? "-",
                string(filters.documentType), flag(filters.includeFrontMatter),
                flag(filters.includeDocumentText), flag(filters.includeSummaries), flag(filters.includeNotes),
            ]
            text += fields.joined(separator: " ") + "\n"
        }
        return text
    }
}

// MARK: - Parse records

/// A `ParsedQuery`, field for field. The Mac golden tool fills it from the app's own
/// `SearchService.parsedQuery(for:)`; Linux fills it from the same parser source compiled there.
public struct ParseRecord: Codable, Equatable, Sendable {
    public var expression: String?
    public var exactTerms: [String]
    public var isApproximate: Bool
    public var malformedProximity: MalformedProximityRecord?
    public var operands: [OperandRecord]
    public var droppedOperands: [OperandRecord]

    public init(expression: String?, exactTerms: [String], isApproximate: Bool,
                malformedProximity: MalformedProximityRecord?, operands: [OperandRecord],
                droppedOperands: [OperandRecord]) {
        self.expression = expression
        self.exactTerms = exactTerms
        self.isApproximate = isApproximate
        self.malformedProximity = malformedProximity
        self.operands = operands
        self.droppedOperands = droppedOperands
    }
}

/// `MalformedProximity`: `kind` is the case name, `operatorInside` or `invalidDistance`.
public struct MalformedProximityRecord: Codable, Equatable, Sendable {
    public var kind: String
    public var text: String

    public init(kind: String, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// `ParsedOperand`: `kind` and `source` are the case names.
public struct OperandRecord: Codable, Equatable, Sendable {
    public var text: String
    public var rendered: String
    public var kind: String
    public var isNegated: Bool
    public var isExact: Bool
    public var isExactApplied: Bool
    public var source: String

    public init(text: String, rendered: String, kind: String, isNegated: Bool, isExact: Bool,
                isExactApplied: Bool, source: String) {
        self.text = text
        self.rendered = rendered
        self.kind = kind
        self.isNegated = isNegated
        self.isExact = isExact
        self.isExactApplied = isExactApplied
        self.source = source
    }
}

// MARK: - Expressions golden

/// `fixtures/golden/queries.expressions.json`: what the app compiles for each query. It depends on
/// the app's source alone, not on any index, so the Mac golden tool makes it without an export.
public struct ExpressionsGolden: Codable, Equatable, Sendable {
    public var format: Int
    public var provenance: Provenance
    public var queries: [ExpressionRecord]

    public static let currentFormat = 1

    public init(provenance: Provenance, queries: [ExpressionRecord]) {
        self.format = Self.currentFormat
        self.provenance = provenance
        self.queries = queries
    }
}

public struct ExpressionRecord: Codable, Equatable, Sendable {
    public var id: String
    /// `SearchService.parsedQuery(for:)`: the unscoped parse.
    public var parse: ParseRecord
    /// `SearchService.matchExpressions(for:)` and `exactTerms(from:)`.
    public var search: SearchExpressionRecord

    public init(id: String, parse: ParseRecord, search: SearchExpressionRecord) {
        self.id = id
        self.parse = parse
        self.search = search
    }
}

public struct SearchExpressionRecord: Codable, Equatable, Sendable {
    /// The MATCH expression for `frus_documents`, or nil when that scope is off.
    public var corpus: String?
    /// The MATCH expression for `user_content`, or nil.
    public var userContent: String?
    public var exactTerms: [String]
    /// The error `matchExpressions` threw, as `String(describing:)` gives it, or nil.
    public var error: String?

    public init(corpus: String?, userContent: String?, exactTerms: [String], error: String?) {
        self.corpus = corpus
        self.userContent = userContent
        self.exactTerms = exactTerms
        self.error = error
    }
}

// MARK: - Results golden

/// `fixtures/golden/queries.results.json`: each query's count and first 50 results, run by the app's
/// SearchService on the Mac over a copy of the owner's three-volume export.
public struct ResultsGolden: Codable, Equatable, Sendable {
    public var format: Int
    public var provenance: Provenance
    public var queries: [ResultRecord]

    public static let currentFormat = 1

    public init(provenance: Provenance, queries: [ResultRecord]) {
        self.format = Self.currentFormat
        self.provenance = provenance
        self.queries = queries
    }
}

public struct ResultRecord: Codable, Equatable, Sendable {
    public var id: String
    /// `searchCount(parameters:)`, or nil when the search threw.
    public var count: Int?
    /// The first 50 results in order, as `volume_id/document_id`.
    public var top: [String]
    /// Each result's bm25 score, as its IEEE-754 bit pattern in hex, so ties are exact.
    public var scoreBits: [String]
    /// The results after the 50th that share its score exactly, with their bit patterns. A tie
    /// group that crosses position 50 is then known whole, so a candidate may take any of it.
    public var tieTail: [String]
    public var tieTailScoreBits: [String]
    /// The error the search threw, or nil.
    public var error: String?

    public init(id: String, count: Int?, top: [String], scoreBits: [String], tieTail: [String] = [],
                tieTailScoreBits: [String] = [], error: String? = nil) {
        self.id = id
        self.count = count
        self.top = top
        self.scoreBits = scoreBits
        self.tieTail = tieTail
        self.tieTailScoreBits = tieTailScoreBits
        self.error = error
    }
}

/// How a candidate's results compare with the golden ones (check 3). Documents whose golden
/// scores are exactly equal may come in any order among themselves: the order of a tie follows
/// the order volumes were indexed and SQLite's query plan, not the search. Such a reordering
/// passes and is reported (decided 3 October 2026).
public enum ResultComparison: Equatable, Sendable {
    case identical
    /// Passes: the results differ only by order within groups of exactly tied documents.
    case tiePermutation(groups: [ClosedRange<Int>])
    /// Fails, with the reason.
    case different(String)

    public var passes: Bool {
        if case .different = self { return false }
        return true
    }

    /// Compares ids and errors by their UTF-8 bytes, never by Swift's `==`, which takes canonically
    /// equivalent strings, such as `é` and `e` with a combining accent, as equal.
    public static func compare(golden: ResultRecord, candidate: ResultRecord) -> ResultComparison {
        if !sameBytes(golden.error, candidate.error) {
            return .different("error: golden \(golden.error ?? "none"), candidate \(candidate.error ?? "none")")
        }
        if golden.count != candidate.count {
            return .different("count: golden \(golden.count.map(String.init) ?? "none"), candidate \(candidate.count.map(String.init) ?? "none")")
        }
        let goldenTop = golden.top.map(bytes), candidateTop = candidate.top.map(bytes)
        if goldenTop == candidateTop { return .identical }
        if golden.top.count != candidate.top.count {
            return .different("top: golden has \(golden.top.count) results, candidate \(candidate.top.count)")
        }
        guard golden.scoreBits.count == golden.top.count else {
            return .different("golden record \(golden.id) has \(golden.scoreBits.count) scores for \(golden.top.count) results")
        }
        // Runs of exactly equal golden scores, by position.
        var groups: [ClosedRange<Int>] = []
        var start = 0
        for index in golden.top.indices.dropFirst() where golden.scoreBits[index] != golden.scoreBits[start] {
            groups.append(start...(index - 1))
            start = index
        }
        if !golden.top.isEmpty { groups.append(start...(golden.top.count - 1)) }

        var permuted: [ClosedRange<Int>] = []
        for group in groups {
            let expected = Array(goldenTop[group])
            let actual = Array(candidateTop[group])
            if expected == actual { continue }
            // The last group may continue past position 50: any of its tail may fill it.
            let isLast = group.upperBound == golden.top.count - 1
            let lastScore = golden.scoreBits.last
            let tail = isLast ? zip(golden.tieTail, golden.tieTailScoreBits).filter { $0.1 == lastScore }.map { bytes($0.0) } : []
            let allowed = Set(expected + tail)
            guard Set(actual).count == actual.count, Set(actual).isSubset(of: allowed),
                  isLast || Set(actual) == Set(expected) else {
                let first = group.first { goldenTop[$0] != candidateTop[$0] } ?? group.lowerBound
                return .different("top: position \(first + 1) is \(candidate.top[first]), golden \(golden.top[first])")
            }
            permuted.append(group)
        }
        return permuted.isEmpty ? .identical : .tiePermutation(groups: permuted)
    }

    private static func bytes(_ string: String) -> [UInt8] { Array(string.utf8) }

    private static func sameBytes(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case (let a?, let b?): a.utf8.elementsEqual(b.utf8)
        default: false
        }
    }
}
