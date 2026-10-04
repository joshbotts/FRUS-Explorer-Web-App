// How check 3 compares results and check 4 reports an HTML difference.

import ParityFormat
import Testing

@Suite struct ResultComparisonTests {
    /// Fifty results; positions in `ties` share one score.
    static func record(_ top: [String], ties: [ClosedRange<Int>] = [], tieTail: [String] = []) -> ResultRecord {
        var scores = top.indices.map { String(0xC000_0000_0000_0000 - UInt64($0) * 1_000, radix: 16) }
        for range in ties { for index in range { scores[index] = scores[range.lowerBound] } }
        return ResultRecord(id: "q001", count: 120, top: top, scoreBits: scores, tieTail: tieTail,
                            tieTailScoreBits: tieTail.map { _ in scores.last ?? "" })
    }

    static let fifty = (1...50).map { "frus1961-63v06/d\($0)" }

    @Test func identicalResultsPass() {
        let golden = Self.record(Self.fifty)
        #expect(ResultComparison.compare(golden: golden, candidate: golden) == .identical)
    }

    @Test func orderWithinATieInTheMiddlePassesAndIsReported() {
        let golden = Self.record(Self.fifty, ties: [10...13])
        var top = Self.fifty
        top.swapAt(10, 13)
        top.swapAt(11, 12)
        let result = ResultComparison.compare(golden: golden, candidate: Self.record(top))
        #expect(result == .tiePermutation(groups: [10...13]))
        #expect(result.passes)
    }

    @Test func aTieCrossingTheFiftiethMayTakeAnyOfItsTail() {
        // Positions 48 and 49 tie with two more documents after the 50th.
        let golden = Self.record(Self.fifty, ties: [48...49], tieTail: ["frus1961-63v06/d51", "frus1961-63v06/d52"])
        var top = Self.fifty
        top[48] = "frus1961-63v06/d52"
        top[49] = "frus1961-63v06/d49"
        let result = ResultComparison.compare(golden: golden, candidate: Self.record(top))
        #expect(result == .tiePermutation(groups: [48...49]))

        // But a document outside the tie may not fill it.
        top[48] = "frus1961-63v06/d99"
        #expect(!ResultComparison.compare(golden: golden, candidate: Self.record(top)).passes)
    }

    @Test func aRealDifferenceFails() {
        let golden = Self.record(Self.fifty, ties: [10...13])
        var top = Self.fifty
        top.swapAt(20, 21)
        #expect(ResultComparison.compare(golden: golden, candidate: Self.record(top))
            == .different("top: position 21 is frus1961-63v06/d22, golden frus1961-63v06/d21"))
        // A permutation that crosses a tie group's edge.
        top = Self.fifty
        top.swapAt(13, 14)
        #expect(!ResultComparison.compare(golden: golden, candidate: Self.record(top)).passes)
    }

    @Test func countsAndErrorsMustMatch() {
        let golden = Self.record(Self.fifty)
        var candidate = golden
        candidate.count = 121
        #expect(ResultComparison.compare(golden: golden, candidate: candidate) == .different("count: golden 120, candidate 121"))
        candidate = golden
        candidate.error = "malformedQuery"
        #expect(ResultComparison.compare(golden: golden, candidate: candidate) == .different("error: golden none, candidate malformedQuery"))
        candidate = golden
        candidate.top.removeLast()
        #expect(ResultComparison.compare(golden: golden, candidate: candidate) == .different("top: golden has 50 results, candidate 49"))
    }
}

@Suite struct RenderDiffTests {
    @Test func identicalHTMLHasNoDifference() {
        #expect(RenderDiff.firstDifference(golden: "<p>a</p>", candidate: "<p>a</p>") == nil)
    }

    @Test func differenceNamesThePieceWithContext() {
        let golden = "<div><p>One</p><p>Two</p><p>Three</p></div>"
        let candidate = "<div><p>One</p><p>Too</p><p>Three</p></div>"
        let difference = RenderDiff.firstDifference(golden: golden, candidate: candidate, context: 1)
        #expect(difference == """
            piece 4 of 8 golden, 8 candidate
              golden:    </p><p>Two</p>
              candidate: </p><p>Too</p>
            """)
    }

    @Test func aShorterCandidateEnds() {
        let difference = RenderDiff.firstDifference(golden: "<p>a</p><p>b</p>", candidate: "<p>a</p>", context: 0)
        #expect(difference == "piece 3 of 4 golden, 2 candidate\n  golden:    <p>b\n  candidate: (ends)")
    }
}
