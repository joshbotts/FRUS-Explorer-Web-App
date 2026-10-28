// The timeline and the concordance through the API, over the kit's fixture index imported as an
// export, beside the app's rule and the kit's own calls over the same index: a timeline counts by
// year the results the app keeps of a search, as the Mac's timeline groups them, and a concordance
// is the kit's for the page on screen, in each of the kit's orders.

import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSCoreKit
@testable import FRUSLightAPI

@Suite struct ReadingsAPIParityTests {
    /// The Mac's timeline of `items`, as `DocumentTimelineView.loadTimeline()` groups them from their
    /// dates in `IndexingPipeline.datesByDocumentKey(_:)`: each under the year its date opens with
    /// (`parseYear`, the first four characters as a whole number), the years earliest first and each
    /// year's items in the order given; an item with no such year is undated. The app's rule, which
    /// `theReadingsAreTheMacsOverTheSetsItReads` holds to the app's source.
    static func macTimeline(_ items: [SearchResult], dates: [String: String]) -> (years: [(year: Int, keys: [String])], undated: Int) {
        var byYear: [Int: [String]] = [:]
        var undated = 0
        for item in items {
            let key = "\(item.volumeId)/\(item.documentId)"
            if let iso = dates[key], iso.count >= 4, let year = Int(iso.prefix(4)) {
                byYear[year, default: []].append(key)
            } else {
                undated += 1
            }
        }
        return (byYear.keys.sorted().map { ($0, byYear[$0]!) }, undated)
    }

    /// A timeline's years, each by its number and its documents' keys, as the Mac's timeline is compared.
    static func years(_ timeline: SearchTimeline) -> [String] {
        timeline.years.map { year in "\(Int(year.year).map(String.init) ?? "?\(year.year)") \(year.count) \((year.documents ?? []).map { "\($0.volumeId)/\($0.documentId)" })" }
    }

    static func years(_ mac: (years: [(year: Int, keys: [String])], undated: Int)) -> [String] {
        mac.years.map { "\($0.year) \($0.keys.count) \($0.keys)" }
    }

    static func get<T: Decodable>(_ type: T.Type, _ client: any TestClientProtocol, _ uri: String) async throws -> T? {
        let response = try await client.execute(uri: uri, method: .get)
        if response.status == .badRequest,
           (try? ServedFixture.decode(APIProblem.Body.self, response))?.code == "EMPTY_QUERY" { return nil }
        guard response.status == .ok else { throw APIParityError("\(uri): \(response.status.code) \(String(buffer: response.body))") }
        return try ServedFixture.decode(type, response)
    }

    /// Every parity query's timeline, read through the API with its documents, is the Mac's timeline of
    /// the 7,500 results the app keeps of the search, as the kit ranks them: the same years, each with
    /// the same documents in the window's order, and the same undated count. A sixth of the queries are
    /// read in each order of the date too, which orders a year's documents as the list is ordered. A
    /// query the kit refuses is refused, and every year is four digits, as the facet keys it.
    @Test func everyTimelineCountsWhatTheAppKeepsAsTheMacsTimelineDoes() async throws {
        let queries = try QueryList.load(Repository.layout.queries)
        let built = try await FixtureIndex.value()
        let kit = built.index.service
        let read = try await ServedFixture.run { client, _ in
            var read: [String: SearchTimeline?] = [:]
            for (index, query) in queries.enumerated() {
                let orders: [SearchSortOrder] = index.isMultiple(of: 6) ? SearchSortOrder.allCases : [.relevance]
                for order in orders {
                    read["\(query.id) \(order.rawValue)"] = try await Self.get(
                        SearchTimeline.self, client,
                        "/api/v1/search/timeline?\(APIParity.formEncode(query))&documents=true&sort=\(order.rawValue)")
                }
                if index.isMultiple(of: 6) {
                    read["\(query.id) bare"] = try await Self.get(SearchTimeline.self, client, "/api/v1/search/timeline?\(APIParity.formEncode(query))")
                }
            }
            return read
        }

        var timelines = 0
        var spanning = 0
        var undated = 0
        var reordered = 0
        for (index, query) in queries.enumerated() {
            let parameters = try LinuxSearch.parameters(query)
            let orders: [SearchSortOrder] = index.isMultiple(of: 6) ? SearchSortOrder.allCases : [.relevance]
            let kept: [SearchResult]
            do {
                kept = try await kit.search(parameters: parameters, limit: SearchRequest.retainedLimit, offset: 0)
            } catch {
                for order in orders { #expect(read["\(query.id) \(order.rawValue)"] == .some(nil), "\(query.id): the kit refuses it") }
                continue
            }
            let dates = try await built.index.pipeline.datesByDocumentKey(kept.map { (volumeId: $0.volumeId, documentId: $0.documentId) })
            var relevance: [String] = []
            for order in orders {
                let key = "\(query.id) \(order.rawValue)"
                guard let timeline = read[key] ?? nil else {
                    Issue.record("\(key): refused, where the kit searches it")
                    continue
                }
                let mac = Self.macTimeline(order.sorted(kept), dates: dates)
                #expect(Self.years(timeline) == Self.years(mac), "\(key)")
                #expect(timeline.undatedCount == mac.undated, "\(key)")
                #expect(timeline.retainedCount == kept.count, "\(key)")
                #expect(timeline.retainedLimit == SearchRequest.retainedLimit && timeline.sort == order.rawValue, "\(key)")
                #expect(timeline.years.allSatisfy { $0.year.count == 4 && $0.year.allSatisfy(\.isASCIIDigitCharacter) }, "\(key)")
                #expect(timeline.years.map(\.count).reduce(0, +) + timeline.undatedCount == timeline.retainedCount, "\(key)")
                if order == .relevance {
                    relevance = Self.years(timeline)
                    timelines += 1
                    if mac.years.count > 1 { spanning += 1 }
                    if mac.undated > 0 && !mac.years.isEmpty { undated += 1 }
                } else if Self.years(timeline) != relevance {
                    reordered += 1
                }
            }
            if index.isMultiple(of: 6), let bare = read["\(query.id) bare"] ?? nil {
                // Without its documents, a timeline is the same years and counts.
                #expect(bare.years.map { "\($0.year) \($0.count)" } == Self.macTimeline(kept, dates: dates).years.map { "\($0.year) \($0.keys.count)" }, "\(query.id)")
                #expect(bare.years.allSatisfy { $0.documents == nil }, "\(query.id)")
            }
        }
        #expect(timelines > 0 && spanning > 0 && undated > 0 && reordered > 0)
        print("the timeline through the API: \(timelines) queries' timelines are the Mac's over what the app keeps, \(spanning) of them across more than one year, \(undated) with undated results, and \(reordered) orders of the date that order a year's documents otherwise")
    }

    /// A year's documents are the results kept that the kit's own year filter keeps for that year
    /// (`yearKeys`, matched in SQL on `substr(date_iso, 1, 4)`), so the year the server reads from a
    /// result's date is the kit's; and where the search keeps its whole match, as every search here
    /// does, the timeline's facet over the keys kept is the facet panel's over the match, the kit's
    /// other route to the same years.
    @Test func aYearsDocumentsAreThoseTheKitsYearFilterKeeps() async throws {
        let kit = try await FixtureIndex.value().index.service
        let queries = ["treaty", "khrushchev", "canal", "berlin OR nicaragua", "negoti*", "the"]
        try await ServedFixture.run { client, _ in
            var years = 0
            for keywords in queries {
                let parameters = SearchParameters(keywords: keywords)
                guard let timeline = try await Self.get(SearchTimeline.self, client,
                                                        "/api/v1/search/timeline?keywords=\(APIParity.encode(keywords, .strict))&documents=true")
                else {
                    Issue.record("\(keywords): refused")
                    continue
                }
                let kept = try await kit.search(parameters: parameters, limit: SearchRequest.retainedLimit, offset: 0)
                let facets = try await kit.resultSetFacets(parameters: parameters, request: .one(.years))
                #expect(facets.matchCount == kept.count, "\(keywords): every match kept")
                #expect(timeline.years.map { "\($0.year) \($0.count)" } == facets.years.map { "\($0.key) \($0.count)" }.sorted(), "\(keywords)")
                #expect(timeline.undatedCount == facets.undatedCount, "\(keywords)")
                let keptKeys = Set(kept.map { "\($0.volumeId)/\($0.documentId)" })
                for year in timeline.years {
                    var narrowed = parameters
                    narrowed.yearKeys = [year.year]
                    let filtered = try await kit.matchKeys(parameters: narrowed).filter(keptKeys.contains)
                    #expect(Set((year.documents ?? []).map { "\($0.volumeId)/\($0.documentId)" }) == Set(filtered), "\(keywords) \(year.year)")
                    #expect(year.documents?.count == year.count, "\(keywords) \(year.year)")
                    years += 1
                }
            }
            #expect(years > queries.count)
            print("the timeline's years: \(years) years of \(queries.count) searches hold the documents the kit's year filter keeps, as many as its Years facet counts")
        }
    }

    /// A match larger than the results the app keeps is counted over those alone, as the Mac's timeline
    /// plots only what it holds: with 7 kept here in place of 7,500, the timeline of each search that
    /// matches more is the Mac's of its 7 best, and for some it is not the whole match's.
    @Test func aMatchLargerThanWhatIsKeptIsCountedOverWhatIsKept() async throws {
        let built = try await FixtureIndex.value()
        let kit = built.index.service
        let coverage = Coverage(indexedVolumes: 3, indexedDocuments: 393, manifestVolumes: 553, indexVersion: nil)
        let limit = 7
        var larger = 0
        var narrower = 0
        for keywords in ["treaty", "khrushchev", "canal", "berlin OR nicaragua", "negoti*", "the", "soviet union nuclear", "oil price"] {
            let parameters = SearchParameters(keywords: keywords)
            let count = try await kit.searchCount(parameters: parameters)
            guard count > limit else { continue }
            larger += 1
            let kept = try await kit.search(parameters: parameters, limit: limit, offset: 0)
            let dates = try await built.index.pipeline.datesByDocumentKey(kept.map { (volumeId: $0.volumeId, documentId: $0.documentId) })
            for order in SearchSortOrder.allCases {
                let timeline = try await ReadingRoutes.timeline(parameters, sort: order, documents: true, scoped: ServedSearch(service: kit, key: ""), facets: FacetCache(),
                                                                keeping: limit, coverage: coverage) { kept }
                let mac = Self.macTimeline(order.sorted(kept), dates: dates)
                #expect(Self.years(timeline) == Self.years(mac), "\(keywords) \(order.rawValue)")
                #expect(timeline.undatedCount == mac.undated && timeline.retainedCount == limit, "\(keywords) \(order.rawValue)")
            }
            let whole = try await kit.resultSetFacets(parameters: parameters, request: .one(.years))
            let bare = try await ReadingRoutes.timeline(parameters, sort: .relevance, documents: false, scoped: ServedSearch(service: kit, key: ""), facets: FacetCache(),
                                                        keeping: limit, coverage: coverage) { kept }
            if bare.years.map({ "\($0.year) \($0.count)" }) != whole.years.map({ "\($0.key) \($0.count)" }).sorted() { narrower += 1 }
        }
        #expect(larger > 3 && narrower > 3)
        print("a timeline of a larger match: \(larger) searches counted over their \(limit) best, \(narrower) of them otherwise than the whole match")
    }

    /// A page's concordance through the API is the kit's for that page, the page `/search` gives for
    /// the same fields: the same lines, by the draft's names, each `KWICSort` order of them as the kit
    /// sorts them, by the kit's labels, and the same counts of what it left out. Every fourth parity
    /// query is read in pages of 7, its first two by relevance and its first in each order of the date;
    /// `the` reaches the kit's bound on one document's lines, which the answer then gives.
    @Test func aConcordanceIsTheKitsForThePageOnScreenInEachOfItsOrders() async throws {
        let queries = try QueryList.load(Repository.layout.queries).enumerated().filter { $0.offset.isMultiple(of: 4) || $0.element.query == "the" }.map(\.element)
        let kit = try await FixtureIndex.value().index.service
        let pages: [(sort: SearchSortOrder, offset: Int)] = [(.relevance, 0), (.relevance, 7), (.dateAscending, 0), (.dateDescending, 0)]
        struct Page: Sendable {
            var concordance: SearchConcordance
            var list: SearchResultList
        }
        let read = try await ServedFixture.run { client, _ in
            // A page the API refuses is nil.
            var read: [String: Page?] = [:]
            for query in queries {
                for page in pages {
                    let fields = "\(APIParity.formEncode(query, limit: 7, offset: page.offset))&sort=\(page.sort.rawValue)"
                    let concordance = try await Self.get(SearchConcordance.self, client, "/api/v1/search/concordance?\(fields)")
                    let list = try await Self.get(SearchResultList.self, client, "/api/v1/search?\(fields)")
                    read["\(query.id) \(page.sort.rawValue) \(page.offset)"] = concordance.flatMap { concordance in
                        list.map { Page(concordance: concordance, list: $0) }
                    }
                    if (concordance == nil) != (list == nil) { throw APIParityError("\(query.id): the concordance and the list disagree on a refusal") }
                }
            }
            return read
        }

        var withLines = 0
        var withoutLines = 0
        var bounded = 0
        var datedOrders = 0
        for query in queries {
            let parameters = try LinuxSearch.parameters(query)
            for page in pages {
                let key = "\(query.id) \(page.sort.rawValue) \(page.offset)"
                // The page as the server cuts it: by relevance the kit's page of the match, in an
                // order of the date a page of what the app keeps, sorted whole.
                let results: [SearchResult]
                do {
                    if page.sort == .relevance {
                        results = try await kit.search(parameters: parameters, limit: 7, offset: page.offset)
                    } else {
                        let kept = try await kit.search(parameters: parameters, limit: SearchRequest.retainedLimit, offset: 0)
                        results = Array(page.sort.sorted(kept).dropFirst(page.offset).prefix(7))
                    }
                } catch {
                    if case .some(.some) = read[key] { Issue.record("\(key): the kit refuses it, and the API answers") }
                    continue
                }
                guard let answered = read[key] ?? nil else {
                    Issue.record("\(key): refused, where the kit searches it")
                    continue
                }
                let (api, list) = (answered.concordance, answered.list)
                let built = try await kit.concordance(for: results, parameters: parameters)
                let lines = built.lines.map { "\($0.volumeId)/\($0.documentId)#\($0.offset) \($0.header) \($0.dateISO ?? "-") [\($0.left)] [\($0.match)] [\($0.right)]" }
                #expect(api.items.map { "\($0.volumeId)/\($0.documentId)#\($0.characterOffset) \($0.header) \($0.dateISO ?? "-") [\($0.left)] [\($0.keyword)] [\($0.right)]" } == lines, "\(key)")
                // The page is the list's, in its order, and each line names its document as the list does.
                #expect(list.items.map { "\($0.volumeId)/\($0.documentId)" } == results.map { "\($0.volumeId)/\($0.documentId)" }, "\(key)")
                let titles = Dictionary(list.items.map { ("\($0.volumeId)/\($0.documentId)", $0.displayTitle) }, uniquingKeysWith: { first, _ in first })
                #expect(api.items.allSatisfy { titles["\($0.volumeId)/\($0.documentId)"] == $0.displayTitle }, "\(key)")
                for order in KWICSort.allCases {
                    let positions = api.orders[order.rawValue] ?? []
                    #expect(positions.compactMap { lines.indices.contains($0) ? lines[$0] : nil }
                        == order.apply(to: built.lines).map { "\($0.volumeId)/\($0.documentId)#\($0.offset) \($0.header) \($0.dateISO ?? "-") [\($0.left)] [\($0.match)] [\($0.right)]" },
                            "\(key) \(order.rawValue)")
                }
                #expect(api.orderChoices.map { "\($0.value) \($0.title)" } == KWICSort.allCases.map { "\($0.rawValue) \($0.pickerLabel)" }, "\(key)")
                #expect(api.omittedCount == built.omittedCount && api.documentsWithoutLines == built.documentsWithoutLines, "\(key)")
                #expect(api.documentsOnPage == results.count && api.documentsWithLines == Set(built.lines.map { "\($0.volumeId)/\($0.documentId)" }).count, "\(key)")
                #expect(api.limit == 7 && api.offset == page.offset && api.sort == page.sort.rawValue, "\(key)")
                #expect(api.linesPerDocumentLimit == (built.omittedCount > 0 ? KWICBuilder.maxLinesPerDocument : nil), "\(key)")
                if !built.lines.isEmpty { withLines += 1 }
                if built.documentsWithoutLines > 0 { withoutLines += 1 }
                if built.omittedCount > 0 { bounded += 1 }
                if page.sort != .relevance, KWICSort.date.apply(to: built.lines) != built.lines { datedOrders += 1 }
            }
        }
        #expect(withLines > 0 && withoutLines > 0 && bounded > 0 && datedOrders > 0)
        print("the concordance through the API: \(withLines) pages' lines are the kit's for the page on screen in each of its orders, \(withoutLines) with documents that gave no line, \(bounded) cut at the kit's \(KWICBuilder.maxLinesPerDocument) lines a document, and \(datedOrders) pages in an order of the date whose lines the date orders otherwise")
    }

    /// The Mac's readings read the sets the server reads, as the app's source says at the pin: its
    /// timeline plots the window's `displayedResults`, which are what it keeps, up to 7,500, in its
    /// order, grouped as `macTimeline` groups them; and its concordance is the kit's of the page on
    /// screen, `pagedResults`, with the kit's own radius. These are app code, which the server follows,
    /// so a pin move that changes one fails here.
    @Test func theReadingsAreTheMacsOverTheSetsItReads() throws {
        let app = Repository.layout.upstream.appendingPathComponent("FRUSExplorer")
        let timeline = try String(contentsOf: app.appendingPathComponent("Search/DocumentTimelineView.swift"), encoding: .utf8)
        for line in [
            "let dates = (try? await pipeline.datesByDocumentKey(pairs)) ?? [:]",
            "if let iso = dates[item.id], let year = Self.parseYear(iso) {",
            "yearToItems[year, default: []].append(item)",
            "yearSections = yearToItems.keys.sorted().map {",
            "guard iso.count >= 4 else { return nil }",
            "return Int(iso.prefix(4))",
        ] {
            #expect(timeline.contains(line), "DocumentTimelineView: \(line)")
        }
        let sheet = try String(contentsOf: app.appendingPathComponent("App/SearchSheet.swift"), encoding: .utf8)
        #expect(sheet.contains(/DocumentTimelineView\(\s*\/\/[^\n]*\n\s*\/\/[^\n]*\n\s*items: searchVM\.displayedResults\.map/), "the Mac's timeline plots displayedResults")
        #expect(sheet.contains(/let page = searchVM\.pagedResults/), "the Mac's concordance is of pagedResults")
        #expect(sheet.contains(/service\.concordance\(\s*for: page, parameters: searchVM\.submittedSearchParameters\)\)/), "with the kit's own radius")
        let model = try String(contentsOf: app.appendingPathComponent("App/MacSearchViewModel.swift"), encoding: .utf8)
        #expect(model.contains("static let searchHardLimit: Int = 7_500") && SearchRequest.retainedLimit == 7_500)
        #expect(model.contains(/var displayedResults: \[SearchResult\] \{\s*let hidden = hiddenReviewedKeys\s*guard !hidden\.isEmpty else \{ return allSortedResults \}/),
                "displayedResults are what the window keeps, in its order, less what Checklist Mode hides")
    }
}
