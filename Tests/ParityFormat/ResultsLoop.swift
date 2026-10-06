// Check 3's results loop: each query's count, its first 50 results, and the results after the 50th
// that tie with it. tools/mac-golden runs it over the app's SearchService on the Mac, and the
// harness over FRUSCoreKit's on Linux, so the two record a query the same way.

import Foundation

/// One search result as check 3 records it: its document and its bm25 score.
public struct SearchHit: Equatable, Sendable {
    public var volume: String
    public var document: String
    public var score: Double

    public init(volume: String, document: String, score: Double) {
        self.volume = volume
        self.document = document
        self.score = score
    }

    /// `volume_id/document_id`, as a `ResultRecord` lists it.
    public var key: String { "\(volume)/\(document)" }

    /// The score's IEEE-754 bit pattern, in lowercase hex without leading zeros.
    public var scoreBits: String { String(score.bitPattern, radix: 16) }
}

public enum ResultsLoop {
    /// The results a record lists before its tie tail, and the page size the tail is read in.
    public static let limit = 50

    /// One query's record. `count` and `page` are the search's own calls, `searchCount(parameters:)`
    /// and `search(parameters:limit:offset:)`, so the loop needs neither platform's types. It takes
    /// the count and the first 50 results, then, when there are 50, reads on page by page while the
    /// results tie with the 50th, so a tie group that crosses position 50 is known whole. A search
    /// that throws is recorded with its error and no results.
    public static func record(id: String, count: () async throws -> Int,
                              page: (_ limit: Int, _ offset: Int) async throws -> [SearchHit]) async -> ResultRecord {
        do {
            let total = try await count()
            let top = try await page(limit, 0)
            var tail: [SearchHit] = []
            if top.count == limit, let last = top.last?.score.bitPattern {
                var offset = limit
                paging: while true {
                    let next = try await page(limit, offset)
                    for hit in next {
                        guard hit.score.bitPattern == last else { break paging }
                        tail.append(hit)
                    }
                    if next.count < limit { break }
                    offset += limit
                }
            }
            return ResultRecord(id: id, count: total, top: top.map(\.key), scoreBits: top.map(\.scoreBits),
                                tieTail: tail.map(\.key), tieTailScoreBits: tail.map(\.scoreBits))
        } catch {
            return ResultRecord(id: id, count: nil, top: [], scoreBits: [], error: String(describing: error))
        }
    }
}
