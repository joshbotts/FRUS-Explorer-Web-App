// Check 3's results over a whole file: every query is identical, reordered only within Mac tie
// groups, which passes and is reported, or different, which fails with a line saying how.

@testable import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct SearchParityTests {
    /// A record whose scores fall by position; positions in `ties` share one score.
    static func record(_ id: String, _ top: [String], count: Int? = 120, ties: [ClosedRange<Int>] = [],
                       tieTail: [String] = [], error: String? = nil) -> ResultRecord {
        var scores = top.indices.map(score)
        for range in ties { for index in range { scores[index] = scores[range.lowerBound] } }
        return ResultRecord(id: id, count: count, top: top, scoreBits: scores, tieTail: tieTail,
                            tieTailScoreBits: tieTail.map { _ in scores.last ?? "" }, error: error)
    }

    static func score(_ position: Int) -> String { String(0xC000_0000_0000_0000 - UInt64(position) * 1_000, radix: 16) }

    static func file(_ records: [ResultRecord]) -> ResultsGolden {
        ResultsGolden(provenance: Provenance(tool: "tests", upstreamCommit: nil, appBuild: nil, indexVersion: 65,
                                             sourceDigest: "digest", inputs: [:],
                                             platform: Platform(os: "test", arch: "test", sqlite: nil, timeZone: "UTC", locale: "en_US")),
                      queries: records)
    }

    static let fifty = (1...50).map { "frus1961-63v06/d\($0)" }

    /// Three queries: fifty results with a tie at positions 11-14, three results, and a refusal.
    static let golden = file([
        record("q001", fifty, ties: [10...13]),
        record("q002", Array(fifty.prefix(3)), count: 3),
        record("q003", [], count: nil, error: "emptyQuery"),
    ])

    @Test func identicalFilesPass() {
        let report = SearchParity.compare(golden: Self.golden, candidate: Self.golden)
        #expect(report.passes)
        #expect(report.identical == ["q001", "q002", "q003"])
        #expect(report.permutations.isEmpty)
        #expect(report.differences.isEmpty)
        #expect(report.otherScores.isEmpty)
        #expect(report.queryCount == 3)
    }

    @Test func aTiePermutationPassesAndIsReported() throws {
        var candidate = Self.golden
        candidate.queries[0].top.swapAt(10, 13)
        candidate.queries[0].top.swapAt(11, 12)
        let report = SearchParity.compare(golden: Self.golden, candidate: candidate)
        #expect(report.passes)
        #expect(report.identical == ["q002", "q003"])
        #expect(report.permuted == ["q001"])
        #expect(report.queryCount == 3)
        let permutation = try #require(report.permutations.first)
        #expect(report.permutations.count == 1)
        #expect(permutation.id == "q001")
        #expect(permutation.positions == 10...13)
        #expect(permutation.scoreBits == Self.score(10))
        #expect(permutation.golden == Array(Self.fifty[10...13]))
        #expect(permutation.candidate == ["d14", "d13", "d12", "d11"].map { "frus1961-63v06/\($0)" })
        #expect(permutation.order == [14, 13, 12, 11])
        #expect(permutation.description == "q001 positions 11-14, tied at score bits \(Self.score(10)): the candidate has golden positions 14, 13, 12, 11")
        // The tied documents share a score, so the candidate's scores are still the golden ones.
        #expect(report.otherScores.isEmpty)
    }

    @Test func aSwapOutsideATieFails() {
        var candidate = Self.golden
        candidate.queries[0].top.swapAt(20, 21)
        var report = SearchParity.compare(golden: Self.golden, candidate: candidate)
        #expect(!report.passes)
        #expect(report.identical == ["q002", "q003"])
        #expect(report.differing == ["q001"])
        #expect(report.differences == [ResultsDifference(
            item: "q001", detail: "top: position 21 is frus1961-63v06/d22, golden frus1961-63v06/d21; every score is the golden one bit for bit")])

        // Where the candidate's scores part from the golden ones, both bit patterns are given.
        candidate.queries[0].scoreBits[20] = "c000000000000001"
        report = SearchParity.compare(golden: Self.golden, candidate: candidate)
        #expect(report.differences.map(\.description) == [
            "q001: top: position 21 is frus1961-63v06/d22, golden frus1961-63v06/d21; scores first differ at position 21: golden \(Self.score(20)), candidate c000000000000001",
        ])
    }

    /// A document missing from the candidate's top, or one the golden file never returned, is named.
    @Test func aMissingOrAddedDocumentIsNamed() {
        var candidate = Self.golden
        candidate.queries[1].top[1] = "frus1894Nicaragua/d7"
        let report = SearchParity.compare(golden: Self.golden, candidate: candidate)
        #expect(report.differences.map(\.description) == [
            "q002: top: position 2 is frus1894Nicaragua/d7, golden frus1961-63v06/d2; the candidate lacks frus1961-63v06/d2; the candidate adds frus1894Nicaragua/d7; every score is the golden one bit for bit",
        ])
    }

    @Test func aCountDifferenceFails() {
        var candidate = Self.golden
        candidate.queries[0].count = 121
        let report = SearchParity.compare(golden: Self.golden, candidate: candidate)
        #expect(report.differences == [ResultsDifference(item: "q001", detail: "count: golden 120, candidate 121; every score is the golden one bit for bit")])
        #expect(report.identical == ["q002", "q003"])
    }

    /// A query only one file holds, or that a file holds twice, is a difference. Queries the golden
    /// file lacks come after its own, in the candidate's order.
    @Test func aMissingOrExtraRecordFails() {
        var candidate = Self.golden
        candidate.queries.remove(at: 1)
        candidate.queries.append(Self.record("q999", Self.fifty))
        candidate.queries.append(Self.golden.queries[2])
        let report = SearchParity.compare(golden: Self.golden, candidate: candidate)
        #expect(report.identical == ["q001"])
        #expect(report.differences == [
            ResultsDifference(item: "q002", detail: "only the golden file has a record"),
            ResultsDifference(item: "q003", detail: "the candidate holds 2 records"),
            ResultsDifference(item: "q999", detail: "only the candidate has a record"),
        ])
        #expect(report.queryCount == 4)

        var golden = Self.golden
        golden.queries.append(golden.queries[0])
        #expect(SearchParity.compare(golden: golden, candidate: Self.golden).differences
            == [ResultsDifference(item: "q001", detail: "the golden file holds 2 records")])
    }

    /// Error strings are compared, and neither side's results are listed against a refusal.
    @Test func differingErrorsFail() {
        var candidate = Self.golden
        candidate.queries[2].error = "malformedQuery"
        candidate.queries[0] = Self.record("q001", [], count: nil, error: "emptyQuery")
        let report = SearchParity.compare(golden: Self.golden, candidate: candidate)
        #expect(report.identical == ["q002"])
        #expect(report.differences == [
            ResultsDifference(item: "q001", detail: "error: golden none, candidate emptyQuery"),
            ResultsDifference(item: "q003", detail: "error: golden emptyQuery, candidate malformedQuery"),
        ])
    }

    /// A tie crossing the 50th may take any of its tail, which the report shows as positions past
    /// 50. A document outside the tie may not fill it, and is named. The candidate's own tail is
    /// not compared.
    @Test func tieTailsAreHandled() throws {
        let tail = ["frus1961-63v06/d51", "frus1961-63v06/d52"]
        let golden = Self.file([Self.record("q001", Self.fifty, ties: [48...49], tieTail: tail)])
        var candidate = golden
        candidate.queries[0].top[48] = "frus1961-63v06/d52"
        candidate.queries[0].top[49] = "frus1961-63v06/d49"
        candidate.queries[0].tieTail = []
        candidate.queries[0].tieTailScoreBits = []
        var report = SearchParity.compare(golden: golden, candidate: candidate)
        #expect(report.passes)
        let permutation = try #require(report.permutations.first)
        #expect(permutation.positions == 48...49)
        #expect(permutation.order == [52, 49])
        #expect(permutation.description == "q001 positions 49-50, tied at score bits \(Self.score(48)): the candidate has golden positions 52, 49")

        // The 50th alone, replaced by a tied document after it.
        let single = Self.file([Self.record("q001", Self.fifty, tieTail: ["frus1961-63v06/d51"])])
        candidate = single
        candidate.queries[0].top[49] = "frus1961-63v06/d51"
        report = SearchParity.compare(golden: single, candidate: candidate)
        #expect(report.permutations.map(\.description) == [
            "q001 position 50, tied at score bits \(Self.score(49)): the candidate has golden position 51",
        ])

        // The last tie group may give way to its tail, so d49 is not lacking; d99 is added.
        candidate = golden
        candidate.queries[0].top[48] = "frus1961-63v06/d99"
        report = SearchParity.compare(golden: golden, candidate: candidate)
        #expect(report.differences.map(\.description) == [
            "q001: top: position 49 is frus1961-63v06/d99, golden frus1961-63v06/d49; the candidate adds frus1961-63v06/d99; every score is the golden one bit for bit",
        ])
    }

    /// A passing query whose scores differ in their bits is listed, and still passes.
    @Test func otherScoresAreInformation() {
        var candidate = Self.golden
        candidate.queries[1].scoreBits[2] = "c000000000000001"
        let report = SearchParity.compare(golden: Self.golden, candidate: candidate)
        #expect(report.passes)
        #expect(report.identical == ["q001", "q002", "q003"])
        #expect(report.otherScores == ["q002"])
    }

    @Test func anotherFormatFails() {
        var candidate = Self.golden
        candidate.format = 2
        let report = SearchParity.compare(golden: Self.golden, candidate: candidate)
        #expect(!report.passes)
        #expect(report.differences == [ResultsDifference(item: "format", detail: "golden 1, candidate 2")])
        #expect(report.differing.isEmpty)
        #expect(report.queryCount == 3)
    }

    /// The committed golden results, compared with themselves, pass with every query identical.
    @Test func committedResultsCompareWithThemselves() throws {
        let status = try GoldenStatus(directory: Repository.layout.golden)
        switch status.states[.results] {
        case .present:
            let golden = try GoldenJSON.read(ResultsGolden.self, from: status.url(.results))
            let report = SearchParity.compare(golden: golden, candidate: golden)
            #expect(report.passes, "\(report.differences.map(\.description).joined(separator: "\n"))")
            #expect(report.identical.count == golden.queries.count)
            #expect(report.permutations.isEmpty && report.otherScores.isEmpty)
            print("check 3's results, the golden file against itself: \(report.identical.count) of \(golden.queries.count) queries identical")
        case .pending(let reason):
            print("\(GoldenFile.results.rawValue) is pending: it waits for \(reason)")
        case nil:
            Issue.record("GoldenStatus has no state for \(GoldenFile.results.rawValue)")
        }
    }
}
