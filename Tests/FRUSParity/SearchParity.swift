// Check 3's results over a whole file: a candidate's counts and first 50 results against the golden
// file's, query by query.
//
// The candidate is a file in the golden format: one `tools/mac-golden results` writes, or, once
// SearchService runs on Linux (session 6), one written from the Linux index. ParityFormat's
// `ResultComparison` compares each query, and allows any order among documents whose Mac scores
// are exactly equal. Check 3's results pass when every query passes, and each such reordering is
// reported (docs/PLAN.md, decided 3 October 2026). The rest of check 3, the compiled expressions,
// is ParseParity's.

import ParityFormat

/// A group of documents with exactly equal golden scores that the candidate orders otherwise.
/// Check 3 passes with it, and reports it.
public struct TiePermutation: Equatable, Sendable, CustomStringConvertible {
    public var id: String
    /// The group's positions in the top 50, from 0, as `ResultComparison` gives them.
    public var positions: ClosedRange<Int>
    /// The golden score the group shares, as its bit pattern in hex.
    public var scoreBits: String
    /// The group's documents in the golden order, and in the candidate's.
    public var golden: [String]
    public var candidate: [String]
    /// The golden position, from 1, of each of the candidate's documents, in its order. A position
    /// past 50 is in the golden tie tail.
    public var order: [Int]

    public init(golden record: ResultRecord, candidate: ResultRecord, positions: ClosedRange<Int>) {
        id = record.id
        self.positions = positions
        scoreBits = record.scoreBits[positions.lowerBound]
        golden = Array(record.top[positions])
        self.candidate = Array(candidate.top[positions])
        var position: [[UInt8]: Int] = [:]
        for (index, document) in (record.top + SearchParity.tail(record)).enumerated() where position[Array(document.utf8)] == nil {
            position[Array(document.utf8)] = index + 1
        }
        // 0 cannot occur: `ResultComparison` accepts a group only when each of its documents is
        // the golden group's or the tie tail's.
        order = self.candidate.map { position[Array($0.utf8)] ?? 0 }
    }

    public var description: String {
        let (first, last) = (positions.lowerBound + 1, positions.upperBound + 1)
        let place = first == last ? "position \(first)" : "positions \(first)-\(last)"
        let plural = order.count == 1 ? "" : "s"
        return "\(id) \(place), tied at score bits \(scoreBits): the candidate has golden position\(plural) \(order.map(String.init).joined(separator: ", "))"
    }
}

/// One way a candidate fails check 3's results: a query whose results differ, a record one file lacks or
/// holds more than once, or the files' format.
public struct ResultsDifference: Equatable, Sendable, CustomStringConvertible {
    /// A query's id, or `format`.
    public var item: String
    public var detail: String

    public init(item: String, detail: String) {
        self.item = item
        self.detail = detail
    }

    public var description: String { "\(item): \(detail)" }
}

/// What `SearchParity.compare` found. Each query either file holds is in exactly one of
/// `identical`, `permutations` and `differences`.
public struct ResultsReport: Equatable, Sendable {
    /// The queries whose results are the golden ones, document for document and in order.
    public var identical: [String] = []
    /// Each tie group a passing query reorders, query by query.
    public var permutations: [TiePermutation] = []
    /// One per query that differs, and one for the format if it differs.
    public var differences: [ResultsDifference] = []
    /// Passing queries whose candidate scores are not the golden ones bit for bit. Check 3 compares
    /// no score, so this is information: a platform whose bm25 rounds otherwise can still order
    /// every document the same.
    public var otherScores: [String] = []

    public init() {}

    public var passes: Bool { differences.isEmpty }

    /// The queries that pass only by reordering tie groups, each once, in order.
    public var permuted: [String] {
        var seen: Set<String> = []
        return permutations.map(\.id).filter { seen.insert($0).inserted }
    }

    /// The queries that differ.
    public var differing: [String] { differences.map(\.item).filter { $0 != "format" } }

    /// Every query either file holds, each once.
    public var queryCount: Int { identical.count + permuted.count + differing.count }
}

public enum SearchParity {
    /// Compares a candidate's results with the golden file's, query by query, in the golden file's
    /// order and then the candidate's for queries only it has. A query only one file has, or that
    /// a file holds more than once, is a difference, and so is another format. A query's results
    /// differ as `ResultComparison` says, with what its reason leaves out (`context`).
    public static func compare(golden: ResultsGolden, candidate: ResultsGolden) -> ResultsReport {
        var report = ResultsReport()
        if golden.format != candidate.format {
            report.differences.append(ResultsDifference(item: "format", detail: "golden \(golden.format), candidate \(candidate.format)"))
        }
        let goldenRecords = Dictionary(grouping: golden.queries, by: \.id)
        let candidateRecords = Dictionary(grouping: candidate.queries, by: \.id)
        var seen: Set<String> = []
        let ids = (golden.queries + candidate.queries).map(\.id).filter { seen.insert($0).inserted }
        for id in ids {
            func differ(_ detail: String) { report.differences.append(ResultsDifference(item: id, detail: detail)) }
            let (a, b) = (goldenRecords[id] ?? [], candidateRecords[id] ?? [])
            guard !a.isEmpty else { differ("only the candidate has a record"); continue }
            guard !b.isEmpty else { differ("only the golden file has a record"); continue }
            guard a.count == 1 else { differ("the golden file holds \(a.count) records"); continue }
            guard b.count == 1 else { differ("the candidate holds \(b.count) records"); continue }
            let (g, c) = (a[0], b[0])
            switch ResultComparison.compare(golden: g, candidate: c) {
            case .identical:
                report.identical.append(id)
            case .tiePermutation(let groups):
                report.permutations += groups.map { TiePermutation(golden: g, candidate: c, positions: $0) }
            case .different(let reason):
                differ(([reason] + context(golden: g, candidate: c)).joined(separator: "; "))
                continue
            }
            if g.scoreBits != c.scoreBits { report.otherScores.append(id) }
        }
        return report
    }

    /// What a difference's reason leaves out: the golden documents the candidate's top lacks, the
    /// documents it adds, and where the two files' scores first differ. A document of the last tie
    /// group may give way to one of its tail, so it is not counted as lacking when the golden file
    /// has a tail. Nothing when either search threw, since the other's top is all lacking or added.
    static func context(golden: ResultRecord, candidate: ResultRecord) -> [String] {
        guard golden.error == nil, candidate.error == nil else { return [] }
        func bytes(_ string: String) -> [UInt8] { Array(string.utf8) }
        let tail = tail(golden)
        var required = golden.top
        if !tail.isEmpty, let last = golden.scoreBits.last, golden.scoreBits.count == golden.top.count {
            let start = golden.scoreBits.lastIndex(where: { $0 != last }).map { $0 + 1 } ?? 0
            required = Array(golden.top[..<start])
        }
        let candidateTop = Set(candidate.top.map(bytes))
        let known = Set((golden.top + tail).map(bytes))
        let lacks = required.filter { !candidateTop.contains(bytes($0)) }
        let adds = candidate.top.filter { !known.contains(bytes($0)) }
        var parts: [String] = []
        if !lacks.isEmpty { parts.append("the candidate lacks \(list(lacks))") }
        if !adds.isEmpty { parts.append("the candidate adds \(list(adds))") }
        let shared = min(golden.scoreBits.count, candidate.scoreBits.count)
        if let index = (0..<shared).first(where: { golden.scoreBits[$0] != candidate.scoreBits[$0] }) {
            parts.append("scores first differ at position \(index + 1): golden \(golden.scoreBits[index]), candidate \(candidate.scoreBits[index])")
        } else if golden.scoreBits.count == candidate.scoreBits.count, !golden.scoreBits.isEmpty {
            parts.append("every score is the golden one bit for bit")
        }
        return parts
    }

    /// The golden tie tail's documents that share the 50th's score, as `ResultComparison` takes them.
    static func tail(_ record: ResultRecord) -> [String] {
        guard let last = record.scoreBits.last else { return [] }
        return zip(record.tieTail, record.tieTailScoreBits).filter { $0.1 == last }.map(\.0)
    }

    /// Up to five documents, then how many more.
    static func list(_ documents: [String]) -> String {
        let shown = documents.prefix(5).joined(separator: ", ")
        return documents.count > 5 ? "\(shown) and \(documents.count - 5) more" : shown
    }
}
