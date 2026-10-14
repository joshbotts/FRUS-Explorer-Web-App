// The date order through the API, over the kit's fixture index imported as an export, beside the
// kit's own calls over the same index: a page in either order of the date is cut from the results
// the app keeps of the search, sorted by `SearchSortOrder.sorted(_:)`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSLightAPI

@Suite struct DateOrderAPIParityTests {
    /// A result, by its document and its score's bits, as the order compares them.
    static func described(volumeId: String, documentId: String, score: Double, dateISO: String?) -> String {
        "\(volumeId)/\(documentId)|\(score.bitPattern)|\(dateISO ?? "-")"
    }

    /// Every page of a sixth of the parity queries in each order of the date, read through the API,
    /// joins up to the kit's order of the 7,500 results the app keeps: `SearchSortOrder.sorted(_:)` over
    /// `search(parameters:limit:offset:)`. The order reads only the results' dates and scores, so a
    /// sixth is enough, and the test counts the orders that hold undated results and documents of one
    /// day. Pages of 7 cut across the order wherever a query has more, and pages of 100 read the rest
    /// whole. A query the kit refuses is refused in either order, and a page by relevance is the kit's
    /// page, as before.
    @Test func everyPageInAnOrderOfTheDateIsCutFromTheKitsOrderOfWhatTheAppKeeps() async throws {
        let queries = try QueryList.load(Repository.layout.queries).enumerated().filter { $0.offset.isMultiple(of: 6) }.map(\.element)
        let kit = try await FixtureIndex.value().index.service
        let orders: [SearchSortOrder] = [.dateAscending, .dateDescending]

        struct Read: Sendable {
            var pages: [String: [String]] = [:]
            var refused: [String: Bool] = [:]
            var labels: [String] = []
            var relevance: [String: [String]] = [:]
        }
        let read = try await ServedFixture.run { client, _ in
            var read = Read()
            for (index, query) in queries.enumerated() {
                let limit = index.isMultiple(of: 2) ? 7 : 100
                for order in orders {
                    let key = "\(query.id) \(order.rawValue)"
                    var items: [String] = []
                    var offset = 0
                    while true {
                        let uri = "/api/v1/search?\(APIParity.formEncode(query, limit: limit, offset: offset))&sort=\(order.rawValue)"
                        let response = try await client.execute(uri: uri, method: .get)
                        if response.status == .badRequest {
                            read.refused[key] = true
                            break
                        }
                        guard response.status == .ok else { throw APIParityError("\(key): \(response.status.code) \(String(buffer: response.body))") }
                        let list = try ServedFixture.decode(SearchResultList.self, response)
                        if read.labels.isEmpty { read.labels = list.sortChoices.map { "\($0.value) \($0.title)" } }
                        guard list.sort == order.rawValue else { throw APIParityError("\(key): answered in \(list.sort)") }
                        items += list.items.map { Self.described(volumeId: $0.volumeId, documentId: $0.documentId, score: $0.bm25Score, dateISO: $0.dateISO) }
                        offset += limit
                        if offset >= min(list.total, SearchRequest.retainedLimit) { break }
                    }
                    read.pages[key] = items
                }
                if index.isMultiple(of: 2) {
                    let uri = "/api/v1/search?\(APIParity.formEncode(query, limit: 7, offset: 7))&sort=relevance"
                    let response = try await client.execute(uri: uri, method: .get)
                    if response.status == .ok {
                        read.relevance[query.id] = try ServedFixture.decode(SearchResultList.self, response).items
                            .map { Self.described(volumeId: $0.volumeId, documentId: $0.documentId, score: $0.bm25Score, dateISO: $0.dateISO) }
                    }
                }
            }
            return read
        }

        #expect(read.labels == SearchSortOrder.allCases.map { "\($0.rawValue) \($0.label)" })
        var ordered = 0
        var paged = 0
        var undated = 0
        var sameDay = 0
        for (index, query) in queries.enumerated() {
            let parameters = try LinuxSearch.parameters(query)
            let kept: [SearchResult]
            do {
                kept = try await kit.search(parameters: parameters, limit: SearchRequest.retainedLimit, offset: 0)
            } catch {
                for order in orders { #expect(read.refused["\(query.id) \(order.rawValue)"] == true, "\(query.id): the kit refuses it") }
                continue
            }
            for order in orders {
                let key = "\(query.id) \(order.rawValue)"
                let expected = order.sorted(kept).map { Self.described(volumeId: $0.volumeId, documentId: $0.documentId, score: $0.bm25Score, dateISO: $0.dateISO) }
                #expect(read.pages[key] == expected, "\(key)")
                if kept.count > 1 { ordered += 1 }
                if index.isMultiple(of: 2), kept.count > 7 { paged += 1 }
                let dates = kept.compactMap(\.dateISO)
                if !dates.isEmpty, dates.count < kept.count { undated += 1 }
                if Set(dates).count < dates.count { sameDay += 1 }
            }
            if index.isMultiple(of: 2), kept.count > 7 {
                let page = try await kit.search(parameters: parameters, limit: 7, offset: 7)
                    .map { Self.described(volumeId: $0.volumeId, documentId: $0.documentId, score: $0.bm25Score, dateISO: $0.dateISO) }
                #expect(read.relevance[query.id] == page, "\(query.id) by relevance")
            }
        }
        #expect(ordered > 0 && paged > 0 && undated > 0 && sameDay > 0)
        print("the date order through the API: \(ordered) orders of more than one result as the kit sorts what the app keeps, \(paged) of them read across pages of 7, \(undated) with undated results and \(sameDay) with documents of one day")
    }
}
