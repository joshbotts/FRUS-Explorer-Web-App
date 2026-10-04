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

    /// Ids and errors are compared as bytes: canonically equivalent text, which Swift's `==`
    /// takes as equal, is a difference.
    @Test func canonicallyEquivalentTextIsADifference() {
        let (nfc, nfd) = ("caf\u{E9}", "cafe\u{301}")
        #expect(nfc == nfd)
        var top = Self.fifty
        top[0] = "frus1961-63v06/\(nfc)"
        let golden = Self.record(top, ties: [10...13])
        var candidate = golden
        candidate.top[0] = "frus1961-63v06/\(nfd)"
        #expect(golden.top == candidate.top)
        #expect(ResultComparison.compare(golden: golden, candidate: candidate)
            == .different("top: position 1 is frus1961-63v06/\(nfd), golden frus1961-63v06/\(nfc)"))

        // Within a tie, too: the same ids in another order pass, an equivalent id does not.
        var tied = Self.fifty
        tied[12] = "frus1961-63v06/\(nfc)"
        let tiedGolden = Self.record(tied, ties: [10...13])
        candidate = tiedGolden
        candidate.top.swapAt(11, 12)
        #expect(ResultComparison.compare(golden: tiedGolden, candidate: candidate) == .tiePermutation(groups: [10...13]))
        candidate.top[11] = "frus1961-63v06/\(nfd)"
        #expect(!ResultComparison.compare(golden: tiedGolden, candidate: candidate).passes)

        candidate = golden
        candidate.error = "malformedQuery(\(nfd))"
        var erring = golden
        erring.error = "malformedQuery(\(nfc))"
        #expect(ResultComparison.compare(golden: erring, candidate: candidate)
            == .different("error: golden malformedQuery(\(nfc)), candidate malformedQuery(\(nfd))"))
        #expect(ResultComparison.compare(golden: erring, candidate: erring) == .identical)
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

    /// HTML is compared as bytes: canonically equivalent text, which Swift's `==` takes as equal,
    /// is a difference, and the piece holding it is named.
    @Test func canonicallyEquivalentTextIsADifference() {
        let golden = "<p>Caf\u{E9}</p><p>Two</p>"
        let candidate = "<p>Cafe\u{301}</p><p>Two</p>"
        #expect(golden == candidate)
        let difference = RenderDiff.firstDifference(golden: golden, candidate: candidate, context: 0)
        #expect(difference.map { Array($0.utf8) }
            == Array("piece 1 of 4 golden, 4 candidate\n  golden:    <p>Caf\u{E9}\n  candidate: <p>Cafe\u{301}".utf8))
    }

    @Test func aShorterCandidateEnds() {
        let difference = RenderDiff.firstDifference(golden: "<p>a</p><p>b</p>", candidate: "<p>a</p>", context: 0)
        #expect(difference == "piece 3 of 4 golden, 2 candidate\n  golden:    <p>b\n  candidate: (ends)")
    }
}
