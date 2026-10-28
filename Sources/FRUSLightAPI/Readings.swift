// GET /api/v1/search/timeline and /api/v1/search/concordance: the search window's two readings of a
// search, each over the set the Mac's reads. The timeline counts by year the results the app keeps
// of a search, 7,500 at most, as the Mac's window plots them (`DocumentTimelineView` over its
// `displayedResults`); the concordance lines up every occurrence of the search's terms in one page
// of those results, as the Mac's window builds it for the page on screen
// (`SearchService.concordance(for:parameters:radius:)`).

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird

/// A search's timeline: how many of the results the app keeps of it fall in each year.
///
/// The Mac's window plots the results it keeps by year, and leaves out, and counts, those with no
/// date. The years and counts here are the kit's: its Years facet over the keys of the results kept
/// (`SearchService.resultSetFacets(parameters:request:documentKeys:)`, its route for a list it
/// describes by its keys), which keys a document by the first four characters of its date, as the
/// kit's year filter does. A match of more than `retainedLimit` is counted only so far: the Mac's
/// window says then that the shape is the ranking's, when `retainedCount` reaches `retainedLimit`.
public struct SearchTimeline: Codable, Equatable, Sendable {
    /// One year, by the kit's key for it, with how many of the results kept fall in it.
    public struct Year: Codable, Equatable, Sendable {
        /// The year as the kit keys it: the first four characters of a document's date.
        public var year: String
        public var count: Int
        /// With `documents=true`, those results, in the order `sort` gives the results kept, as the
        /// Mac's timeline lists a year's documents in the window's order.
        public var documents: [TimelineDocument]?
    }

    /// How many results the app keeps of a search.
    public var retainedLimit: Int
    /// The results the timeline counts: those the app keeps of the search, its whole match up to
    /// `retainedLimit`. `/search` counts the match.
    public var retainedCount: Int
    /// The order of each year's documents: a `SearchSortOrder` raw value.
    public var sort: String
    /// The years that hold a result, earliest first.
    public var years: [Year]
    /// The results kept that carry no date, and so are in no year (the facet's `undatedCount`).
    public var undatedCount: Int
    public var coverage: Coverage
}

/// A document in a year of the timeline, named as its row in the results names it, with its label
/// beside its volume, as the Mac's timeline lists it under its year.
public struct TimelineDocument: Codable, Equatable, Sendable {
    public var volumeId: String
    public var documentId: String
    public var displayTitle: String
    public var documentLabel: String
    public var headerRepeatsNumber: Bool

    init(_ result: SearchResult) {
        volumeId = result.volumeId
        documentId = result.documentId
        displayTitle = SearchItem.displayTitle(of: result)
        documentLabel = CitableDocumentNumber.captionLabel(printed: result.documentNumber, documentId: result.documentId)
        headerRepeatsNumber = DocumentHeaderDisplay.headerRepeatsNumber(result.header, number: result.documentNumber)
    }
}

/// The concordance of one page of a search's results: every occurrence of the search's terms in
/// those documents, each on a line of its own between the text either side of it, as the kit builds
/// it for the Mac's window, with its radius of 60 characters. The page is the one `/search` gives for
/// the same fields, in the same order.
///
/// The kit gives the lines in the order of the page's results, each document's in the order of its
/// text, and leaves their order to its caller (`KWICSort`). Each of its orders comes as the positions
/// of the lines in it, so a client shows another order without asking again, as the Mac's window
/// sorts the lines it holds when its Align by changes.
public struct SearchConcordance: Codable, Equatable, Sendable {
    /// One occurrence, with the text either side of it: the kit's `KWICLine`, by the draft's names.
    public struct Line: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// The document's header, as the kit's line carries it.
        public var header: String
        /// What the document's row in the results names it by.
        public var displayTitle: String
        public var dateISO: String?
        /// The text before the occurrence, trimmed at a word's edge.
        public var left: String
        /// The occurrence as the document spells it: neither the stem nor the query.
        public var keyword: String
        /// The text after the occurrence.
        public var right: String
        /// Where the occurrence starts in the document's text, in characters, which tells two of
        /// its lines apart (`KWICLine.offset`).
        public var characterOffset: Int
    }

    /// The page the lines are of, as `/search` takes it; `/search` counts the match it is a page of.
    public var limit: Int
    public var offset: Int
    public var retainedLimit: Int
    public var sort: String
    /// How many documents the page holds.
    public var documentsOnPage: Int
    public var items: [Line]
    /// Each `KWICSort` order of the lines, by its raw value, as positions in `items`
    /// (`KWICSort.apply(to:)`).
    public var orders: [String: [Int]]
    /// The orders, with the kit's label for each (`KWICSort.pickerLabel`); the first is the Mac's.
    public var orderChoices: [Choice]
    /// Occurrences the kit's bound on one document's lines left out.
    public var omittedCount: Int
    /// Documents of the page that gave a line.
    public var documentsWithLines: Int
    /// Documents of the page that gave no line: none of their words stems to the query's terms as
    /// the kit's Swift stemmer stems it, though SQLite's matched them, or the index has no text.
    public var documentsWithoutLines: Int
    /// When the bound left occurrences out, the most lines one document gives: a document the bound
    /// cut short gave exactly that many (`KWICBuilder.maxLinesPerDocument`, which the kit keeps
    /// internal). Absent when nothing was left out.
    public var linesPerDocumentLimit: Int?
    public var coverage: Coverage
}

extension SearchTimeline: ResponseEncodable {}
extension SearchConcordance: ResponseEncodable {}

enum ReadingRoutes {
    /// The field `/search/timeline` takes beside a search's and its page's: its page and order say
    /// nothing of it but the order of each year's documents, and are taken so a search's address can
    /// be read as it stands, as `/search/inspect` takes them.
    static let timelineFields: Set<String> = ["documents"]

    /// The draft's parameters for its concordance, which reads the whole match, and why this one,
    /// which reads a page as the Mac's does, takes none of them.
    static let draftConcordanceFields: [(name: String, detail: String)] = [
        ("sortBy", "the lines come in each of the kit's orders: see orders and orderChoices"),
        ("contextCharacters", "the lines carry the kit's 60 characters either side, as the Mac's do"),
        ("maxLinesPerDocument", "the kit bounds a document's lines itself: see omittedCount and linesPerDocumentLimit"),
        ("documentKeys", "a concordance reads the page of a search that limit, offset and sort choose, as the Mac's reads the page on screen"),
    ]

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources,
                    users: SearchUsers) {
        // Each runs while its client is connected, as a search does: the results kept of a search and
        // the page stop with it. The facet over the keys kept is a cheap pass, and runs to its end.
        router.get("/api/v1/search/timeline") { request, context -> SearchTimeline in
            let form = try FormQuery(request.uri.query)
            let search = try SearchRequest(form: form, alsoTaking: timelineFields)
            let documents = try form.bool("documents") ?? false
            let user = try await users.user(searching: search.parameters, for: request, context: context)
            let served = try await provider.served()
            let parameters = try await users.inside(search.workingCorpusId, search.parameters, for: user, served: served)
            let scoped = try served.search(for: user)
            let coverage = Coverage(index: served.corpus, resources: resources)
            return try await context.whileClientConnected {
                do {
                    // In Checklist Mode, of the results kept less those it hides, as the Mac's timeline
                    // plots what its checklist leaves (S17e).
                    return try await timeline(parameters, sort: search.sort, documents: documents, scoped: scoped,
                                              facets: served.facets, keeping: SearchRequest.retainedLimit, reviewed: search.reviewed,
                                              coverage: coverage) {
                        try await served.retained.results(of: parameters, in: scoped).filter { !search.hides($0) }
                    }
                } catch let error as FTS5Error {
                    throw SearchRoutes.refusal(error)
                }
            }
        }
        router.get("/api/v1/search/concordance") { request, context -> SearchConcordance in
            let form = try FormQuery(request.uri.query)
            if let draft = draftConcordanceFields.first(where: { !form.values($0.name).isEmpty }) {
                throw APIProblem(.badRequest, code: "UNSUPPORTED_PARAMETER", detail: "\(draft.name): \(draft.detail)")
            }
            var asked = try SearchRequest(form: form)
            let user = try await users.user(searching: asked.parameters, for: request, context: context)
            let served = try await provider.served()
            asked.parameters = try await users.inside(asked.workingCorpusId, asked.parameters, for: user, served: served)
            let search = asked
            let scoped = try served.search(for: user)
            return try await context.whileClientConnected {
                do {
                    return try await concordance(search, served: served, scoped: scoped, resources: resources)
                } catch let error as FTS5Error {
                    throw SearchRoutes.refusal(error)
                }
            }
        }
    }

    /// The timeline of the search `parameters` say, over the `limit` results the app keeps of it,
    /// which `kept` gives, best first, as the date order keeps them.
    ///
    /// Its years are the Years facet over the keys of those results, the kit's route for a list it
    /// describes by its keys, which reads only the rows the keys name; `facets` keeps it beside the
    /// panel's sections, by whose search it is, as `scoped` says. The match is not counted here, and
    /// nothing but the results kept reads it, so the work stops when its client goes, as a search's
    /// does. A year's documents, asked for with `documents`, are the results kept whose date the kit
    /// keys by that year, in the order `sort` gives them.
    static func timeline(_ parameters: SearchParameters, sort: SearchSortOrder, documents: Bool,
                         scoped: ServedSearch, facets: FacetCache, keeping limit: Int, reviewed: Set<String> = [],
                         coverage: Coverage,
                         kept: @escaping @Sendable () async throws -> [SearchResult]) async throws -> SearchTimeline {
        let retained = try await kept()
        let keys = retained.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        // Kept by the results it counts: those Checklist Mode leaves are another set's.
        let hidden = reviewed.isEmpty ? "" : " reviewed \(reviewed.sorted().joined(separator: ","))"
        let breakdown = try await facets.section(.years,
                                                 search: "\(scoped.key)retained \(limit) \(SearchRequest.signature(parameters))\(hidden)") {
            try await scoped.service.resultSetFacets(parameters: parameters, request: .one(.years), documentKeys: keys)
        }
        var byYear: [String: [TimelineDocument]] = [:]
        if documents {
            for result in sort.sorted(retained) {
                guard let year = result.dateISO.map(yearKey) else { continue }
                byYear[year, default: []].append(TimelineDocument(result))
            }
        }
        // The facet's rows come newest first; a timeline reads from its earliest year.
        let years = breakdown.years.sorted { $0.key < $1.key }.map { bucket in
            SearchTimeline.Year(year: bucket.key, count: bucket.count, documents: documents ? byYear[bucket.key] ?? [] : nil)
        }
        return SearchTimeline(retainedLimit: limit, retainedCount: retained.count, sort: sort.rawValue, years: years,
                              undatedCount: breakdown.undatedCount, coverage: coverage)
    }

    /// The kit's key for the year of a date: its first four characters, as SQLite's `substr` counts
    /// them, which the Years facet buckets on and the year filter matches (`substr(date_iso, 1, 4)`).
    static func yearKey(_ dateISO: String) -> String {
        String(String.UnicodeScalarView(dateISO.unicodeScalars.prefix(4)))
    }

    /// The concordance of the page `search` asks for, as `/search` cuts it, and as `/search` kept it
    /// lately, so the page on screen is not fetched again. It counts nothing: the list it is a page of
    /// has its count from `/search`.
    static func concordance(_ search: SearchRequest, served: ServedIndex, scoped: ServedSearch,
                            resources: ServerResources) async throws -> SearchConcordance {
        let results = try await SearchRoutes.page(search, served: served, scoped: scoped)
        let built = try await scoped.service.concordance(for: results, parameters: search.parameters)
        let titles = Dictionary(results.map { ("\($0.volumeId)/\($0.documentId)", SearchItem($0).displayTitle) },
                                uniquingKeysWith: { first, _ in first })
        let position = Dictionary(built.lines.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
        var perDocument: [String: Int] = [:]
        for line in built.lines { perDocument["\(line.volumeId)/\(line.documentId)", default: 0] += 1 }
        return SearchConcordance(
            limit: search.limit, offset: search.offset,
            retainedLimit: SearchRequest.retainedLimit, sort: search.sort.rawValue, documentsOnPage: results.count,
            items: built.lines.map { line in
                SearchConcordance.Line(volumeId: line.volumeId, documentId: line.documentId, header: line.header,
                                       displayTitle: titles["\(line.volumeId)/\(line.documentId)"] ?? line.header,
                                       dateISO: line.dateISO, left: line.left, keyword: line.match, right: line.right,
                                       characterOffset: line.offset)
            },
            orders: Dictionary(uniqueKeysWithValues: KWICSort.allCases.map { order in
                (order.rawValue, order.apply(to: built.lines).compactMap { position[$0.id] })
            }),
            orderChoices: KWICSort.allCases.map { Choice(value: $0.rawValue, title: $0.pickerLabel) },
            omittedCount: built.omittedCount,
            // Counted from the lines: for a search with no words the kit builds none, and counts no
            // document as giving none.
            documentsWithLines: perDocument.count,
            documentsWithoutLines: built.documentsWithoutLines,
            linesPerDocumentLimit: built.omittedCount > 0 ? perDocument.values.max() : nil,
            coverage: Coverage(index: served.corpus, resources: resources))
    }
}
