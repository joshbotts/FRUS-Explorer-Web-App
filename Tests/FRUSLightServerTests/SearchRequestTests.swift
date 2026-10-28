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
        #expect(request.limit == 20 && request.offset == 0 && request.sort == .relevance)
        #expect(try decode("") == request)
    }

    /// `sort` names a `SearchSortOrder`, and only that.
    @Test func sortNamesTheKitsOrder() throws {
        for order in SearchSortOrder.allCases {
            #expect(try decode("keywords=treaty&sort=\(order.rawValue)").sort == order)
        }
        #expect(try decode("keywords=treaty&sort=relevance") == decode("keywords=treaty"))
    }

    @Test func everyFieldReachesItsSearchParameter() throws {
        let request = try decode([
            "keywords=cuba%20missile", "phrase=naval+quarantine", "prefixWildcard=khrush",
            "excludedTerms=turkey", "excludedTerms=jupiter",
            "dateRangeEarliest=1962-10-01", "dateRangeLatest=1962-11-30",
            "volumeIds=frus1961-63v06", "volumeIds=frus1894Nicaragua", "yearKeys=1962",
            "documentType=editorialNotesOnly",
            "includeDocumentText=false", "includeSummaries=false", "includeNotes=false", "includeFrontMatter=false",
            "userTagIds=5E14D000-0000-4000-8000-000000000001", "userTagIds=5e14d000-0000-4000-8000-000000000002",
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
        expected.userTagIds = ["5E14D000-0000-4000-8000-000000000001", "5e14d000-0000-4000-8000-000000000002"]
        #expect(request.parameters == expected)
        #expect(request.limit == 100 && request.offset == 7_400)
        // And back, as a facet's change and a kept answer's key say a search.
        #expect(SearchRequest.formFields(expected)["userTagIds"] == expected.userTagIds)
        #expect(try decode(SearchRequest.formFields(expected).flatMap { name, values in
            values.map { "\(name)=\($0.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0)" }
        }.joined(separator: "&")).parameters == expected)
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
        #expect(try decode("userTagIds=").parameters.userTagIds == [], "no tag filter, as the kit's empty list is")
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
            ("sort=date", "INVALID_PARAMETER", "sort"),
            ("sort=relevance&sort=dateAscending", "INVALID_PARAMETER", "sort"),
            ("facets=year", "UNSUPPORTED_PARAMETER", "/api/v1/search/facets"),
            ("personRef=p1", "UNSUPPORTED_PARAMETER", "personRef"),
            ("subjectTagIds=cuba", "UNSUPPORTED_PARAMETER", "userTagIds"),
            ("booleanMode=or", "UNSUPPORTED_PARAMETER", "OR"),
            ("userTagIds=&userTagIds=5E14D000-0000-4000-8000-000000000001", "INVALID_PARAMETER", "userTagIds"),
            ("personRollupId=x", "INVALID_PARAMETER", "personRollupId"),
            ("personRollupId=-1", "INVALID_PARAMETER", "personRollupId"),
            ("subjectBucket=1.5", "INVALID_PARAMETER", "subjectBucket"),
            ("personLabel=a&personLabel=b", "INVALID_PARAMETER", "personLabel"),
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

    /// The four fields a facet narrows by reach their parameters: a person's rollup and the name its
    /// filter shows, and a subject's place in the vocabulary and its durable name.
    @Test func theFieldsAFacetNarrowsByReachTheirParameters() throws {
        let request = try decode("keywords=treaty&personRollupId=12&personLabel=Khrushchev%2C+Nikita+S.&subjectBucket=40&subjectBucketKey=Cold+War%2FBerlin")
        #expect(request.parameters.personRollupId == 12 && request.parameters.personLabel == "Khrushchev, Nikita S.")
        #expect(request.parameters.subjectBucket == 40 && request.parameters.subjectBucketKey == "Cold War/Berlin")
    }

    /// What `formFields` writes, the decoder reads back as the same parameters, field by field, and a
    /// field at its default is left out.
    @Test func formFieldsSayWhatTheDecoderReads() throws {
        var every = SearchParameters(keywords: "cuba missile + «quarantine»")
        every.phrase = "naval quarantine"
        every.prefixWildcard = "khrush"
        every.excludedTerms = ["turkey", "jupiter"]
        every.dateRange = DateRange(earliest: "1962-10-01", latest: "1962-11-30")
        every.volumeIds = ["frus1961-63v06", "frus1894Nicaragua"]
        every.yearKeys = ["1962"]
        every.documentTypeFilter = .editorialNotesOnly
        every.includeDocumentText = false
        every.includeSummaries = false
        every.includeNotes = false
        every.includeFrontMatter = false
        every.personRollupId = 12
        every.personLabel = "Khrushchev, Nikita S."
        every.subjectBucket = 40
        every.subjectBucketKey = "Cold War/Berlin"
        var empties = SearchParameters(keywords: "")
        empties.volumeIds = []
        empties.yearKeys = []
        empties.dateRange = DateRange(earliest: nil, latest: nil)
        for parameters in [SearchParameters(), SearchParameters(keywords: "treaty"), every, empties] {
            let fields = SearchRequest.formFields(parameters)
            let query = fields.keys.sorted().flatMap { name in
                fields[name, default: []].map { "\(name)=\($0.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0)" }
            }.joined(separator: "&")
            #expect(try decode(query).parameters == parameters, "\(query)")
        }
        #expect(SearchRequest.formFields(SearchParameters()).isEmpty)
        #expect(SearchRequest.formFields(SearchParameters(keywords: "treaty")) == ["keywords": ["treaty"]])
        #expect(SearchRequest.formFields(empties)["yearKeys"] == [""], "the empty list is one empty value")
    }

    /// A change names each field whose values move, with its new values, and `null` for one the new
    /// search leaves out.
    @Test func aChangeNamesEachFieldThatMoves() throws {
        var before = SearchParameters(keywords: "treaty")
        before.volumeIds = ["frus1961-63v06"]
        var after = before
        after.volumeIds = nil
        after.personRollupId = 1
        after.personLabel = "Khrushchev"
        let change = SearchChange(from: before, to: after)
        let json = try JSONEncoder().encode(change)
        // An object's keys come in no fixed order; a field left out is null, not absent.
        let object = try JSONDecoder().decode([String: [String]?].self, from: json)
        #expect(object == ["personLabel": ["Khrushchev"], "personRollupId": ["1"], "volumeIds": [String]?.none])
        #expect(String(decoding: json, as: UTF8.self).contains(#""volumeIds":null"#))
        #expect(try JSONDecoder().decode(SearchChange.self, from: json) == change)
        #expect(SearchChange(from: before, to: before).fields.isEmpty)
    }
}
