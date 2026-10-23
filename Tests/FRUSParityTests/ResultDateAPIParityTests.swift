// A result's date through the API, over the kit's fixture index imported as an export, beside the
// kit's own search over the same index (#1746): each row carries the kit's date, last day and
// precision, and the words `SearchResultDate` gives them, which the Mac's window draws for a row that
// prints no dateline.

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

@Suite struct ResultDateAPIParityTests {
    /// The first 100 rows of every parity query the kit answers, read through the API, are the kit's
    /// rows in the kit's order, each with the kit's `dateISO`, `dateISOMax` and `datePrecision`, and
    /// with `drawnDate` the words `SearchResultDate` writes for them in US English. The fixture's four
    /// rows that print no dateline and have a date draw theirs: the President's message of 1895 by its
    /// day, and three editorial notes of the Kennedy–Khrushchev exchanges by the span their index gives
    /// them.
    @Test func everyRowCarriesTheKitsDateAndTheWordsForIt() async throws {
        let queries = try QueryList.load(Repository.layout.queries)
        let kit = try await FixtureIndex.value().index.service
        let targeted: [(keywords: String, volume: String, document: String, words: String)] = [
            ("senate resolution transmitting", "frus1894Nicaragua", "message-of-the-president", "January 3, 1895"),
            ("Sulzberger", "frus1961-63v06", "d20", "November 9, 1960 – December 1, 1963"),
            ("Bolshoi", "frus1961-63v06", "d76", "November 9, 1960 – December 1, 1963"),
            ("Thompson Dobrynin announce", "frus1961-63v06", "d80", "November 9, 1960 – December 1, 1963"),
        ]
        let (read, found) = try await ServedFixture.run { client, _ in
            var read: [String: [SearchItem]] = [:]
            for query in queries {
                let response = try await client.execute(uri: "/api/v1/search?\(APIParity.formEncode(query, limit: 100, offset: 0))", method: .get)
                if response.status == .badRequest { continue }
                guard response.status == .ok else { throw APIParityError("\(query.id): \(response.status.code)") }
                read[query.id] = try ServedFixture.decode(SearchResultList.self, response).items
            }
            var found: [String: SearchItem] = [:]
            for row in targeted {
                var query = URLComponents()
                query.queryItems = [URLQueryItem(name: "keywords", value: row.keywords), URLQueryItem(name: "limit", value: "100")]
                let response = try await client.execute(uri: "/api/v1/search?\(query.percentEncodedQuery ?? "")", method: .get)
                let list = try ServedFixture.decode(SearchResultList.self, response)
                found[row.document] = list.items.first { $0.volumeId == row.volume && $0.documentId == row.document }
            }
            return (read, found)
        }

        let english = Locale(identifier: "en_US")
        var rows = 0
        var spans = 0
        var drawnInPlaceOfADateline = 0
        for query in queries {
            guard let items = read[query.id] else { continue }
            let expected = try await kit.search(parameters: try LinuxSearch.parameters(query), limit: 100, offset: 0)
            #expect(items.map { "\($0.volumeId)/\($0.documentId)" } == expected.map(\.id), "\(query.id)")
            for (item, result) in zip(items, expected) {
                #expect(item.dateISO == result.dateISO && item.dateISOMax == result.dateISOMax
                        && item.datePrecision == result.datePrecision?.rawValue, "\(query.id) \(result.id)")
                #expect(item.drawnDate == SearchResultDate.text(dateISO: result.dateISO, dateISOMax: result.dateISOMax,
                                                                precision: result.datePrecision, locale: english),
                        "\(query.id) \(result.id)")
                rows += 1
                if let last = result.dateISOMax, last != result.dateISO { spans += 1 }
                if result.dateline == nil, item.drawnDate != nil { drawnInPlaceOfADateline += 1 }
            }
        }
        #expect(read.count == queries.count - 43, "the kit refuses 43 of the queries")
        #expect(rows > 1_000 && spans > 0 && drawnInPlaceOfADateline > 0)
        for row in targeted {
            let item = try #require(found[row.document], "\(row.keywords) finds \(row.volume)/\(row.document)")
            #expect(item.dateline == nil && item.drawnDate == row.words, "\(row.volume)/\(row.document): \(item.drawnDate ?? "none")")
        }
        print("a result's date through the API: \(rows) rows of \(read.count) queries carry the kit's date and its words, \(spans) of them spans; \(drawnInPlaceOfADateline) draw their date where they print no dateline")
    }
}
