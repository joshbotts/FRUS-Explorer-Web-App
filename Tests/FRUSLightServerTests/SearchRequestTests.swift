// The search request decoder, field by field. FRUSParityTests decodes every parity query.

import FRUSCoreKit
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct SearchRequestTests {
    func decode(_ query: String?) throws(APIProblem) -> SearchRequest { try SearchRequest(formEncoded: query) }

    func refusal(_ query: String) -> APIProblem? {
        do throws(APIProblem) {
            _ = try decode(query)
            return nil
        } catch {
            return error
        }
    }

    @Test func nothingGivenIsTheAppsDefaultSearch() throws {
        let request = try decode(nil)
        #expect(request.parameters == SearchParameters())
        #expect(request.limit == 20 && request.offset == 0)
        #expect(try decode("") == request)
    }

    @Test func everyFieldReachesItsSearchParameter() throws {
        let request = try decode([
            "keywords=cuba%20missile", "phrase=naval+quarantine", "prefixWildcard=khrush",
            "excludedTerms=turkey", "excludedTerms=jupiter",
            "dateRangeEarliest=1962-10-01", "dateRangeLatest=1962-11-30",
            "volumeIds=frus1961-63v06", "volumeIds=frus1894Nicaragua", "yearKeys=1962",
            "documentType=editorialNotesOnly",
            "includeDocumentText=false", "includeSummaries=false", "includeNotes=false", "includeFrontMatter=false",
            "limit=100", "offset=7400",
        ].joined(separator: "&"))
        var expected = SearchParameters(keywords: "cuba missile")
        expected.phrase = "naval quarantine"
        expected.prefixWildcard = "khrush"
        expected.excludedTerms = ["turkey", "jupiter"]
        expected.dateRange = DateRange(earliest: "1962-10-01", latest: "1962-11-30")
        expected.volumeIds = ["frus1961-63v06", "frus1894Nicaragua"]
        expected.yearKeys = ["1962"]
        expected.documentTypeFilter = .editorialNotesOnly
        expected.includeDocumentText = false
        expected.includeSummaries = false
        expected.includeNotes = false
        expected.includeFrontMatter = false
        #expect(request.parameters == expected)
        #expect(request.limit == 100 && request.offset == 7_400)
    }

    @Test func plusIsASpaceAndAnEncodedPlusIsAPlus() throws {
        #expect(try decode("keywords=a+b").parameters.keywords == "a b")
        #expect(try decode("keywords=a%2Bb").parameters.keywords == "a+b")
        #expect(try decode("keywords=NEAR(khrushchev%20kennedy,%20%2B5)").parameters.keywords == "NEAR(khrushchev kennedy, +5)")
        // Names decode as values do.
        #expect(try decode("key%77ords=x").parameters.keywords == "x")
    }

    @Test func textIsPassedOnExactlyAsTyped() throws {
        #expect(try decode("keywords=").parameters.keywords == "")
        #expect(try decode("keywords=+++").parameters.keywords == "   ")
        #expect(try decode("keywords").parameters.keywords == "", "a name with no = is an empty value")
        // Precomposed and decomposed é stay as sent.
        #expect(try decode("keywords=%C3%A9").parameters.keywords.map { Array($0.utf8) } == [0xC3, 0xA9])
        #expect(try decode("keywords=e%CC%81").parameters.keywords.map { Array($0.utf8) } == [0x65, 0xCC, 0x81])
        #expect(try decode("keywords=%C2%ABkhrushchev%C2%BB").parameters.keywords == "«khrushchev»")
    }

    @Test func oneEmptyValueIsTheEmptyList() throws {
        #expect(try decode("yearKeys=").parameters.yearKeys == [])
        #expect(try decode("volumeIds=").parameters.volumeIds == [])
        #expect(try decode("excludedTerms=").parameters.excludedTerms == [])
        #expect(try decode("keywords=x").parameters.yearKeys == nil)
        #expect(try decode("keywords=x").parameters.volumeIds == nil)
        #expect(refusal("volumeIds=&volumeIds=frus1894Nicaragua")?.code == "INVALID_PARAMETER")
    }

    @Test func eitherBoundMakesARangeAndAnEmptyBoundIsNone() throws {
        #expect(try decode("dateRangeEarliest=1975-01-01").parameters.dateRange == DateRange(earliest: "1975-01-01", latest: nil))
        #expect(try decode("dateRangeLatest=1961-12-31").parameters.dateRange == DateRange(earliest: nil, latest: "1961-12-31"))
        #expect(try decode("dateRangeEarliest=").parameters.dateRange == DateRange(earliest: nil, latest: nil),
                "a range with no bounds, which leaves out undated documents")
        #expect(try decode("keywords=x").parameters.dateRange == nil)
        // The last two are a digit carrying a combining acute and a full-width digit.
        for bad in ["1962", "1962-10", "62-10-01", "1962-10-01T00:00", "1962/10/01", "2%CC%81962-10-01", "%EF%BC%91962-10-01"] {
            #expect(refusal("dateRangeEarliest=\(bad)")?.code == "INVALID_PARAMETER", "\(bad)")
        }
    }

    @Test func eachBadValueIsRefusedByName() {
        for (query, code, named) in [
            ("keywords=a&keywords=b", "INVALID_PARAMETER", "keywords"),
            ("documentType=memos", "INVALID_PARAMETER", "documentType"),
            ("includeNotes=yes", "INVALID_PARAMETER", "includeNotes"),
            ("includeNotes=TRUE", "INVALID_PARAMETER", "includeNotes"),
            ("limit=0", "INVALID_PARAMETER", "limit"),
            ("limit=101", "INVALID_PARAMETER", "limit"),
            ("limit=+5", "INVALID_PARAMETER", "limit"),
            ("offset=-1", "INVALID_PARAMETER", "offset"),
            ("offset=7481", "INVALID_PARAMETER", "offset"),
            ("offset=7500&limit=1", "INVALID_PARAMETER", "offset"),
            ("facets=year", "UNSUPPORTED_PARAMETER", "facets"),
            ("personRef=p1", "UNSUPPORTED_PARAMETER", "personRef"),
            ("volumeIds[]=frus1894Nicaragua", "UNKNOWN_PARAMETER", "volumeIds[]"),
            ("q=treaty", "UNKNOWN_PARAMETER", "q"),
            ("keywords=%E2%28", "MALFORMED_QUERY", "keywords"),
        ] {
            let problem = refusal(query)
            #expect(problem?.code == code && problem?.status == .badRequest, "\(query): \(problem.map(\.description) ?? "accepted")")
            #expect(problem?.detail.contains(named) == true, "\(query): \(problem?.detail ?? "")")
        }
        // The last page the app keeps is allowed.
        #expect(refusal("offset=7480&limit=20") == nil)
    }
}
