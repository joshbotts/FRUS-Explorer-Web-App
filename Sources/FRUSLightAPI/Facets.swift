// GET /api/v1/search/facets and /api/v1/search/facets/selection: what a search's whole match holds,
// broken down by year, volume, person, document type, provenance and subject, one section a
// request, as the app's facet panel computes a section when it is opened; and how a section's rows
// narrow the search, as the panel narrows it.
//
// Every answer is the kit's: `SearchService.resultSetFacets(parameters:request:documentKeys:)`
// computes the section over the match the search would run (FRUSCoreKit, upstream #1664), which the
// app's panel calls too, with the user half of the user the request acts for (S17d); `FacetPaging` sorts, filters and pages its rows; `FacetNarrowing` says how a
// row of a section that narrows on a click changes the search; and `FacetSelection` with
// `FacetSelectionApplier` resolves a staged selection of years or volumes into the filter Apply
// sets, over the section's whole list of rows.

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird

/// One section of a search's facets: a page of its rows, as `FacetPaging` cuts it, with what the
/// app's panel says beside them.
public struct SearchFacetSection: Codable, Equatable, Sendable {
    /// One row: a bucket of the match, by the kit's key and label, and how many matched documents
    /// it holds.
    public struct Row: Codable, Equatable, Sendable {
        public var key: String
        public var label: String
        public var count: Int
        /// How the search changes when the row is clicked, for a section that narrows on a click
        /// (`FacetNarrowing`); absent for a staged or a descriptive section.
        public var narrowing: SearchChange?
    }

    /// Which rows of the section's list this is: the kit's `FacetPage`.
    public struct Page: Codable, Equatable, Sendable {
        /// The rows that match the filter, and all the section's rows.
        public var matchingCount: Int
        public var totalCount: Int
        /// The page shown, from 0, clamped to the pages there are, and how many there are.
        public var pageIndex: Int
        public var pageCount: Int
        /// The first row's number among the matching rows, from 1.
        public var firstRowNumber: Int
    }

    /// How the rows are cut: the kit's `FacetDisplayState`, as given or by its standard.
    public struct Display: Codable, Equatable, Sendable {
        public var sort: String
        public var pageSize: String
        public var page: Int
        public var filter: String
    }

    /// A sort or a page size the section offers, by its value and the kit's title for it.
    public typealias Choice = FRUSLightAPI.Choice

    /// The kit's `FacetBound`: how many values the section fetched, of how many it has.
    public struct Bound: Codable, Equatable, Sendable {
        public var shown: Int
        public var total: Int
        public var isTruncated: Bool
    }

    /// The kit's `ProvenanceCoverage`: how many matched documents' source notes were parsed, and
    /// how many of those name a record group.
    public struct ProvenanceCoverage: Codable, Equatable, Sendable {
        public var parsed: Int
        public var withRecordGroup: Int
        public var matchCount: Int
    }

    /// `years`, `volumes`, `people`, `documentType`, `provenance` or `subjects`.
    public var section: String
    /// What a click on a row does: `staged` for years and volumes, whose rows are chosen and then
    /// applied together (`FacetSelectionApplier.stagedSections`); `immediate` for people, document
    /// type and subjects, where a row narrows the search; `descriptive` for provenance, which the
    /// search has no filter for (`FacetNarrowing.isNarrowable`).
    public var selection: String
    /// How many documents the whole match holds.
    public var matchCount: Int
    public var rows: [Row]
    public var page: Page
    public var display: Display
    public var sortChoices: [Choice]
    public var pageSizeChoices: [Choice]
    public var bound: Bound?
    /// For years: matched documents that carry no date and so are in no year.
    public var undatedCount: Int?
    /// For volumes: the share of the match the three largest volumes hold (`topVolumeShare(_:)`).
    public var topVolumeShare: Double?
    public var provenanceCoverage: ProvenanceCoverage?
    /// For subjects: how many matched documents carry a subject, and whether the subject index is
    /// ready (`subjectsPrepared`).
    public var subjectCoverage: Int?
    public var subjectsPrepared: Bool?
    public var coverage: Coverage
}

/// What a staged selection of years or volumes narrows the search to, as Apply sets it.
public struct SearchFacetSelection: Codable, Equatable, Sendable {
    public var section: String
    /// The keys the selection resolves to, over the section's whole list (`FacetSelection.resolved`);
    /// nil when nothing is chosen.
    public var keys: [String]?
    public var change: SearchChange
    public var coverage: Coverage
}

extension SearchFacetSection: ResponseEncodable {}
extension SearchFacetSelection: ResponseEncodable {}

enum FacetRoutes {
    /// The fields `/search/facets` takes beside the search's.
    static let sectionFields: Set<String> = ["section", "facetSort", "facetPageSize", "facetPage", "facetFilter"]

    /// The fields `/search/facets/selection` takes beside the search's.
    static let selectionFields: Set<String> = ["section", "include", "exclude"]

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources,
                    users: SearchUsers) {
        router.get("/api/v1/search/facets") { request, context -> SearchFacetSection in
            let form = try FormQuery(request.uri.query)
            let parameters = try SearchRequest.parameters(from: form, alsoTaking: sectionFields)
            let section = try requiredSection(form, among: FacetSection.allCases)
            let display = try displayState(form, for: section)
            let user = try await users.user(searching: parameters, for: request, context: context)
            let served = try await provider.served()
            let facets = try await computed(section, parameters: parameters, served: served, scoped: try served.search(for: user))
            let page = FacetPaging.page(buckets(section, in: facets), with: display)
            let narrowable = FacetNarrowing.isNarrowable(section) && !FacetSelectionApplier.stagedSections.contains(section)
            let rows = page.rows.map { bucket -> SearchFacetSection.Row in
                var row = SearchFacetSection.Row(key: bucket.key, label: bucket.label, count: bucket.count)
                if narrowable, let narrowing = FacetNarrowing.forBucket(bucket, in: section) {
                    var narrowed = parameters
                    narrowing.apply(to: &narrowed, resources: resources.indexing)
                    row.narrowing = SearchChange(from: parameters, to: narrowed)
                }
                return row
            }
            return SearchFacetSection(
                section: section.rawValue,
                selection: FacetSelectionApplier.stagedSections.contains(section) ? "staged"
                    : FacetNarrowing.isNarrowable(section) ? "immediate" : "descriptive",
                matchCount: facets.matchCount,
                rows: rows,
                page: .init(matchingCount: page.matchingCount, totalCount: page.totalCount, pageIndex: page.pageIndex,
                            pageCount: page.pageCount, firstRowNumber: page.firstRowNumber),
                display: .init(sort: display.sort.rawValue, pageSize: display.pageSize.rawValue,
                               page: page.pageIndex, filter: display.filterText),
                sortChoices: FacetSort.choices(for: section).map { .init(value: $0.rawValue, title: $0.title(for: section)) },
                pageSizeChoices: FacetPageSize.allCases.map { .init(value: $0.rawValue, title: $0.title) },
                bound: facets.bounds[section].map { .init(shown: $0.shown, total: $0.total, isTruncated: $0.isTruncated) },
                undatedCount: section == .years ? facets.undatedCount : nil,
                topVolumeShare: section == .volumes ? facets.topVolumeShare(3) : nil,
                provenanceCoverage: section == .provenance
                    ? .init(parsed: facets.provenanceCoverage.parsed, withRecordGroup: facets.provenanceCoverage.withRecordGroup,
                            matchCount: facets.provenanceCoverage.matchCount)
                    : nil,
                subjectCoverage: section == .subjects ? facets.subjectCoverage : nil,
                subjectsPrepared: section == .subjects ? facets.subjectsPrepared : nil,
                coverage: Coverage(index: served.corpus, resources: resources))
        }

        router.get("/api/v1/search/facets/selection") { request, context -> SearchFacetSelection in
            let form = try FormQuery(request.uri.query)
            let parameters = try SearchRequest.parameters(from: form, alsoTaking: selectionFields)
            let staged = FacetSection.allCases.filter(FacetSelectionApplier.stagedSections.contains)
            let section = try requiredSection(form, among: staged)
            let included = try form.list("include") ?? []
            let excluded = try form.list("exclude") ?? []
            if let both = included.first(where: excluded.contains) {
                throw APIProblem.invalidParameter("exclude", "\(both) is included too; a row is one or the other")
            }
            let user = try await users.user(searching: parameters, for: request, context: context)
            let served = try await provider.served()
            // Over the section's whole list, not the page shown: an exclusion alone means every row
            // but those, as the app's panel resolves it.
            let facets = try await computed(section, parameters: parameters, served: served, scoped: try served.search(for: user))
            let universe = buckets(section, in: facets).map(\.key)
            // The app's rows are the list it resolves over, so the kit drops an unknown key without a
            // word, and a volume selection of nothing but such keys would clear the filter. Rows the
            // browser counted before a new index, or another search, can be such keys: they are
            // refused, so the browser counts the section again rather than widen the search.
            let rows = Set(universe)
            if let stale = (included + excluded).first(where: { !rows.contains($0) }) {
                throw APIProblem(.conflict, code: "SECTION_CHANGED",
                                 detail: "\(stale) is not a row of \(section.rawValue) for this search; count the section again and choose afresh.")
            }
            let keys = FacetSelection(included: Set(included), excluded: Set(excluded)).resolved(from: universe)
            var narrowed = parameters
            FacetSelectionApplier.apply(section, keys: keys, to: &narrowed)
            return SearchFacetSelection(section: section.rawValue, keys: keys,
                                        change: SearchChange(from: parameters, to: narrowed),
                                        coverage: Coverage(index: served.corpus, resources: resources))
        }
    }

    /// `section`, which each facets request names: one of `known`.
    static func requiredSection(_ form: FormQuery, among known: [FacetSection]) throws(APIProblem) -> FacetSection {
        guard let section = try form.choice("section", among: known) else {
            throw APIProblem.invalidParameter("section", "is required: one of \(known.map(\.rawValue).joined(separator: ", "))")
        }
        guard known.contains(section) else {
            throw APIProblem.invalidParameter("section", "must be one of \(known.map(\.rawValue).joined(separator: ", ")), not \(section.rawValue)")
        }
        return section
    }

    /// The rows' sort, page size, page and filter, each the kit's standard for the section unless given.
    static func displayState(_ form: FormQuery, for section: FacetSection) throws(APIProblem) -> FacetDisplayState {
        var display = FacetDisplayState.standard(for: section)
        if let sort = try form.choice("facetSort", among: FacetSort.allCases) {
            let offered = Set(FacetSort.choices(for: section)).union([display.sort])
            guard offered.contains(sort) else {
                throw APIProblem.invalidParameter("facetSort", "\(section.rawValue) sorts only by \(FacetSort.allCases.filter(offered.contains).map(\.rawValue).joined(separator: ", "))")
            }
            display.sort = sort
        }
        if let size = try form.choice("facetPageSize", among: FacetPageSize.allCases) { display.pageSize = size }
        display.pageIndex = try form.integer("facetPage", in: 0...Int(Int32.max), default: 0)
        display.filterText = try form.single("facetFilter") ?? ""
        return display
    }

    /// One section of the search's facets as `scoped` searches, computed over its whole match, or as
    /// computed lately. A query the kit refuses, such as one with nothing left to search, is the
    /// request's fault, as it is for a search.
    static func computed(_ section: FacetSection, parameters: SearchParameters, served: ServedIndex,
                         scoped: ServedSearch) async throws -> ResultSetFacets {
        do {
            return try await served.facets.section(section, of: parameters, in: scoped)
        } catch let error as FTS5Error {
            throw SearchRoutes.refusal(error)
        }
    }

    /// The section's rows, as the app's panel reads them from the breakdown. The kit labels a
    /// document-type row by its key, `0` for documents and `1` for editorial notes, which the browser
    /// app names as the app does; the two names sort as the keys do, so the kit's order is the app's.
    static func buckets(_ section: FacetSection, in facets: ResultSetFacets) -> [FacetBucket] {
        switch section {
        case .years: facets.years
        case .volumes: facets.volumes
        case .people: facets.people
        case .documentType: facets.documentTypes
        case .provenance: facets.provenance
        case .subjects: facets.subjects
        }
    }
}

/// The facet sections computed lately over one served index, so a section's next page, sort or
/// filter, and Apply over it, cost no second computation: the app's panel, too, computes a section
/// once for a search and cuts it as it is shown. Each is kept by its section, whose search it is
/// (`ServedSearch.key`) and the query fields that say it (`SearchRequest.signature(_:)`).
public struct FacetCache: Sendable {
    let kept: RecentComputations<ResultSetFacets>

    public init(capacity: Int = 16) {
        kept = RecentComputations(capacity: capacity)
    }

    /// One section of the search `parameters` say, as computed lately, or as `scoped` computes it.
    func section(_ section: FacetSection, of parameters: SearchParameters, in scoped: ServedSearch) async throws -> ResultSetFacets {
        try await self.section(section, search: scoped.key + SearchRequest.signature(parameters)) {
            try await scoped.service.resultSetFacets(parameters: parameters, request: .one(section))
        }
    }

    /// The section kept for `search`, or the one `compute` gives, which is kept unless it fails.
    func section(_ section: FacetSection, search: String,
                 compute: @escaping @Sendable () async throws -> ResultSetFacets) async throws -> ResultSetFacets {
        try await kept.value(for: "\(section.rawValue) \(search)", compute: compute)
    }
}
