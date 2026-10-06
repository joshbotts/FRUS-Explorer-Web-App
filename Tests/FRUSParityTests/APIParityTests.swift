// Check 3 through the API, the request half: the search request decoder on every parity query.
// ServedAPIParityTests runs the queries, and check 4, through the routes.

import FRUSCoreKit
import FRUSParity
import Foundation
import ParityFormat
import Testing

@testable import FRUSLightAPI

@Suite struct APIParityTests {
    /// Every query, written as a client writes it, decodes into exactly the `SearchParameters`
    /// tools/mac-golden builds for it on the Mac, which `LinuxSearch.parameters` mirrors. So each
    /// compiled expression the expressions golden records is what the API's search will compile:
    /// `matchExpressions(for:)` is a function of those parameters alone. Text is compared by its
    /// UTF-8 bytes too, since Swift's string equality would let a normalization slip through.
    @Test func everyQueryReachesTheKitAsTheMacBuildsIt() throws {
        let queries = try QueryList.load(Repository.layout.queries)
        #expect(queries.count == 482)
        for encoding in APIParity.Encoding.allCases {
            var mismatches: [String] = []
            for query in queries {
                let expected = try LinuxSearch.parameters(query)
                let request = try SearchRequest(formEncoded: APIParity.formEncode(query, encoding: encoding))
                let decoded = request.parameters
                let bytesEqual = decoded.keywords.map { Array($0.utf8) } == expected.keywords.map { Array($0.utf8) }
                    && decoded.phrase.map { Array($0.utf8) } == expected.phrase.map { Array($0.utf8) }
                    && decoded.excludedTerms.map { Array($0.utf8) } == expected.excludedTerms.map { Array($0.utf8) }
                if decoded != expected || !bytesEqual || request.limit != 20 || request.offset != 0 {
                    mismatches.append("\(query.id): \(APIParity.formEncode(query, encoding: encoding))")
                }
            }
            #expect(mismatches.isEmpty, "\(encoding): \(mismatches.count) queries decode differently:\n\(mismatches.joined(separator: "\n"))")
        }
        print("check 3 through the API: all \(queries.count) queries decode into the Mac's SearchParameters, in both encodings")
    }

    /// The traps the query list holds, one by one: the empty lists that mean opposite things, the
    /// blank texts, a literal plus, and the open date ranges.
    @Test func theListsTrapsDecodeExactly() throws {
        let queries = Dictionary(uniqueKeysWithValues: try QueryList.load(Repository.layout.queries).map { ($0.id, $0) })
        func decoded(_ id: String) throws -> SearchParameters {
            try SearchRequest(formEncoded: APIParity.formEncode(try #require(queries[id]))).parameters
        }
        #expect(try decoded("q406").yearKeys == [], "an empty year list, which matches nothing")
        #expect(try decoded("q403").volumeIds == [], "an empty volume list, which filters nothing")
        #expect(try decoded("q251").keywords == "")
        #expect(try decoded("q252").keywords == "   ")
        #expect(try decoded("q157").keywords?.contains("+5") == true)
        #expect(try decoded("q418").dateRange == DateRange(earliest: "1975-01-01", latest: nil))
        #expect(try decoded("q419").dateRange == DateRange(earliest: nil, latest: "1961-12-31"))
    }
}
