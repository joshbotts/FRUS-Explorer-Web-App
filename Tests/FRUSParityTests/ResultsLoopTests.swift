// Check 3's results loop, which tools/mac-golden and the Linux harness share, over a search made here.

import ParityFormat
import Testing

@Suite struct ResultsLoopTests {
    /// A search over `scores`, in order: one hit per score, `d1`, `d2`, … in volume `v`.
    struct FakeSearch {
        var scores: [Double]
        var pages: [(limit: Int, offset: Int)] = []

        mutating func page(_ limit: Int, _ offset: Int) -> [SearchHit] {
            pages.append((limit, offset))
            guard offset < scores.count else { return [] }
            return scores[offset..<min(offset + limit, scores.count)].enumerated().map { index, score in
                SearchHit(volume: "v", document: "d\(offset + index + 1)", score: score)
            }
        }
    }

    /// The 50th result's score is shared by the 41st to the 120th: the tie tail runs from the 51st
    /// to the 120th, read across two more pages, and stops at the 121st, whose score differs.
    @Test func theTieAfterTheFiftiethIsPagedUntilTheScoreChanges() async {
        var search = FakeSearch(scores: (1...40).map { -Double(100 - $0) } + Array(repeating: -5, count: 80) + [-1, -1])
        let record = await ResultsLoop.record(id: "q001", count: { 122 }, page: { search.page($0, $1) })
        #expect(record.count == 122)
        #expect(record.top == (1...50).map { "v/d\($0)" })
        #expect(record.tieTail == (51...120).map { "v/d\($0)" })
        #expect(record.tieTailScoreBits == Array(repeating: SearchHit(volume: "", document: "", score: -5).scoreBits, count: 70))
        #expect(record.scoreBits.count == 50 && record.error == nil)
        #expect(search.pages.map(\.offset) == [0, 50, 100])
        #expect(search.pages.allSatisfy { $0.limit == ResultsLoop.limit })

        // Fewer than 50 results: no tail is read.
        var short = FakeSearch(scores: [-3, -3, -2])
        let shortRecord = await ResultsLoop.record(id: "q002", count: { 3 }, page: { short.page($0, $1) })
        #expect(shortRecord.top == ["v/d1", "v/d2", "v/d3"] && shortRecord.tieTail.isEmpty)
        #expect(short.pages.count == 1)
    }

    /// A search that throws, as the app's does for a query it refuses, is recorded with its error,
    /// no count and no results.
    @Test func aSearchThatThrowsIsRecordedWithItsError() async {
        struct Refusal: Error, CustomStringConvertible { var description: String { "emptyQuery" } }
        let record = await ResultsLoop.record(id: "q003", count: { throw Refusal() }, page: { _, _ in [] })
        #expect(record == ResultRecord(id: "q003", count: nil, top: [], scoreBits: [], error: "emptyQuery"))
    }
}
