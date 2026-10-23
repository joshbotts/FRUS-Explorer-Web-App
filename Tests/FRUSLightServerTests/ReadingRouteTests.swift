// The timeline and the concordance through the router, over a synthetic export served read-only,
// and each refusal. FRUSParityTests holds both to the app's rule and the kit's own calls over the
// fixture index.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct ReadingRouteTests {
    @Test func eachReadingWaitsForAnIndex() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for uri in ["/api/v1/search/timeline?keywords=treaties", "/api/v1/search/concordance?keywords=treaties"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(try problem(response, .serviceUnavailable).code == "INDEX_NOT_READY", "\(uri)")
            }
        }
    }

    /// The synthetic export's three documents by year: two of November 1960 and one of January 1894,
    /// the earliest first, each year's documents in the order chosen, and none undated.
    @Test func aTimelineCountsTheResultsKeptByYear() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let timeline = try decode(SearchTimeline.self, try await client.execute(
                uri: "/api/v1/search/timeline?keywords=negotiating+OR+canal", method: .get))
            #expect(timeline.years.map { "\($0.year) \($0.count)" } == ["1894 1", "1960 2"])
            #expect(timeline.years.allSatisfy { $0.documents == nil })
            #expect(timeline.retainedCount == 3 && timeline.retainedLimit == 7_500)
            #expect(timeline.undatedCount == 0 && timeline.sort == "relevance")
            #expect(timeline.coverage.indexedDocuments == 3)

            let oldest = try decode(SearchTimeline.self, try await client.execute(
                uri: "/api/v1/search/timeline?keywords=negotiating+OR+canal&documents=true&sort=dateDescending", method: .get))
            #expect(oldest.sort == "dateDescending")
            #expect(oldest.years.map { $0.documents?.map { "\($0.volumeId)/\($0.documentId)" } ?? [] }
                == [["frus1894Nicaragua/d1"], ["frus1961-63v06/d2", "frus1961-63v06/d1"]])
            let telegram = try #require(oldest.years.last?.documents?.last)
            #expect(telegram.displayTitle == "1. Telegram From the Embassy in the Soviet Union")
            #expect(telegram.documentLabel == "Doc 1" && !telegram.headerRepeatsNumber)
            // A search's address as it stands: its page says nothing of the timeline, its order the order of each year's documents.
            let ascending = try decode(SearchTimeline.self, try await client.execute(
                uri: "/api/v1/search/timeline?keywords=negotiating+OR+canal&documents=true&sort=dateAscending&limit=50&offset=50", method: .get))
            #expect(ascending.years.last?.documents?.map(\.documentId) == ["d1", "d2"] && ascending.retainedCount == 3)
        }
    }

    /// A document the index gives no date is in no year, and is counted as undated.
    @Test func aDocumentWithNoDateIsInNoYear() async throws {
        let fixture = try await servingSyntheticExport(edits: "DELETE FROM document_dates WHERE volume_id = 'frus1894Nicaragua';")
        try await fixture.app.test(.router) { client in
            let timeline = try decode(SearchTimeline.self, try await client.execute(
                uri: "/api/v1/search/timeline?keywords=negotiating+OR+canal&documents=true", method: .get))
            #expect(timeline.years.map { "\($0.year) \($0.count)" } == ["1960 2"] && timeline.undatedCount == 1)
            #expect(timeline.years.flatMap { $0.documents ?? [] }.count == 2)
            let canal = try decode(SearchTimeline.self, try await client.execute(uri: "/api/v1/search/timeline?keywords=canal", method: .get))
            #expect(canal.years.isEmpty && canal.undatedCount == 1 && canal.retainedCount == 1)
            let none = try decode(SearchTimeline.self, try await client.execute(uri: "/api/v1/search/timeline?keywords=zanzibar", method: .get))
            #expect(none.years.isEmpty && none.undatedCount == 0 && none.retainedCount == 0)
        }
    }

    /// Each occurrence on a line of its own, as the kit builds it for the page: the words before, the
    /// word as the document spells it, and the words after, out to a word's edge 60 characters away,
    /// with each of the kit's orders and its label for it.
    @Test func aConcordanceLinesUpEachOccurrenceOnThePage() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let concordance = try decode(SearchConcordance.self, try await client.execute(
                uri: "/api/v1/search/concordance?keywords=negotiating", method: .get))
            let lines = Dictionary(uniqueKeysWithValues: concordance.items.map { ($0.documentId, $0) })
            let d1 = try #require(lines["d1"])
            #expect(d1.left == "The ambassador was" && d1.keyword == "negotiating" && d1.right == "treaties with the minister.")
            #expect(d1.characterOffset == 19 && d1.dateISO == "1960-11-09")
            #expect(d1.header == "1. Telegram From the Embassy in the Soviet Union" && d1.displayTitle == d1.header)
            let d2 = try #require(lines["d2"])
            #expect(d2.left.isEmpty && d2.keyword == "Negotiating" && d2.right == "began in May, and after many long weeks of talks the treaties")
            #expect(d2.characterOffset == 0)
            #expect(concordance.items.count == 2 && concordance.documentsOnPage == 2 && concordance.documentsWithLines == 2)
            #expect(concordance.documentsWithoutLines == 0 && concordance.omittedCount == 0 && concordance.linesPerDocumentLimit == nil)
            #expect(concordance.limit == 20 && concordance.offset == 0 && concordance.sort == "relevance")
            func order(_ name: String) -> [String] { (concordance.orders[name] ?? []).map { concordance.items[$0].documentId } }
            // By the word before (none, for d2, comes first), by what follows, by date, by volume and place.
            #expect(order("leftContext") == ["d2", "d1"] && order("rightContext") == ["d2", "d1"])
            #expect(order("date") == ["d1", "d2"] && order("volume") == ["d1", "d2"])
            #expect(concordance.orderChoices.map(\.title) == ["Left context", "Right context", "Date", "Volume"])
            #expect(concordance.orderChoices.map(\.value) == ["leftContext", "rightContext", "date", "volume"])

            // A page of one: its document's lines alone.
            let second = try decode(SearchConcordance.self, try await client.execute(
                uri: "/api/v1/search/concordance?keywords=negotiating&limit=1&offset=1&sort=dateAscending", method: .get))
            #expect(second.items.map(\.documentId) == ["d2"] && second.documentsOnPage == 1)
            let past = try decode(SearchConcordance.self, try await client.execute(
                uri: "/api/v1/search/concordance?keywords=negotiating&offset=40", method: .get))
            #expect(past.items.isEmpty && past.documentsOnPage == 0 && past.orders.values.allSatisfy(\.isEmpty))
        }
    }

    /// An exact word is matched as typed, which no stem can center a line on, so the page's documents
    /// give no line and the answer counts them, as the Mac's window says so.
    @Test func aConcordanceCountsTheDocumentsItCouldNotAlign() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let concordance = try decode(SearchConcordance.self, try await client.execute(
                uri: "/api/v1/search/concordance?keywords=%3Dnegotiating", method: .get))
            #expect(concordance.items.isEmpty && concordance.documentsOnPage > 0)
            #expect(concordance.documentsWithoutLines == concordance.documentsOnPage && concordance.documentsWithLines == 0)
        }
    }

    /// A search with no words, such as a person's, as a facet narrows to one, gives no line, and the
    /// documents on its page gave none, which the kit leaves its own count of at nothing.
    @Test func aConcordanceOfASearchWithNoWordsGivesNoLine() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let concordance = try decode(SearchConcordance.self, try await client.execute(
                uri: "/api/v1/search/concordance?keywords=&personRollupId=1&personLabel=Khrushchev", method: .get))
            #expect(concordance.items.isEmpty && concordance.documentsOnPage == 2)
            #expect(concordance.documentsWithLines == 0 && concordance.documentsWithoutLines == 0)
            let timeline = try decode(SearchTimeline.self, try await client.execute(
                uri: "/api/v1/search/timeline?keywords=&personRollupId=1&personLabel=Khrushchev", method: .get))
            #expect(timeline.years.map { "\($0.year) \($0.count)" } == ["1960 2"])
        }
    }

    /// Each reading takes a search's fields and its page's, and refuses anything else, as a search
    /// does, the draft's concordance parameters with what this one does instead, and a query with
    /// nothing left to search.
    @Test func eachReadingRefusesWhatItDoesNotTake() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            for (uri, code) in [
                ("/api/v1/search/timeline?keywords=treaties&section=years", "UNKNOWN_PARAMETER"),
                ("/api/v1/search/timeline?keywords=treaties&limit=101", "INVALID_PARAMETER"),
                ("/api/v1/search/timeline?keywords=treaties&documents=yes", "INVALID_PARAMETER"),
                ("/api/v1/search/timeline?keywords=treaties&sort=oldest", "INVALID_PARAMETER"),
                ("/api/v1/search/timeline?keywords=treaties&facets=years", "UNSUPPORTED_PARAMETER"),
                ("/api/v1/search/timeline?keywords=", "EMPTY_QUERY"),
                ("/api/v1/search/concordance?keywords=treaties&documents=true", "UNKNOWN_PARAMETER"),
                ("/api/v1/search/concordance?keywords=treaties&limit=101", "INVALID_PARAMETER"),
                ("/api/v1/search/concordance?keywords=treaties&sortBy=leftContext", "UNSUPPORTED_PARAMETER"),
                ("/api/v1/search/concordance?keywords=treaties&contextCharacters=40", "UNSUPPORTED_PARAMETER"),
                ("/api/v1/search/concordance?keywords=treaties&documentKeys=frus1961-63v06%2Fd1", "UNSUPPORTED_PARAMETER"),
                ("/api/v1/search/concordance?keywords=-treaties", "EMPTY_QUERY"),
            ] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(try problem(response, .badRequest).code == code, "\(uri)")
            }
        }
    }
}
