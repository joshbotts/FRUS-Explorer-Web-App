// The facets through the API, over the kit's fixture index imported as an export, beside the kit's
// own calls over the same index: every section's rows are `resultSetFacets` cut by `FacetPaging`,
// each row's narrowing is `FacetNarrowing`'s, and a staged selection resolves as `FacetSelection`
// and `FacetSelectionApplier` resolve it.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct FacetsAPIParityTests {
    /// Searches whose matches, over the three fixture volumes, give every section rows.
    static let queries = ["treaty", "khrushchev", "canal", "berlin OR nicaragua"]

    /// A query string for `fields`, with form semantics, as a browser writes it.
    static func query(_ fields: [String: [String]]) -> String {
        fields.keys.sorted().flatMap { name in
            fields[name, default: []].map { "\(APIParity.encode(name, .strict))=\(APIParity.encode($0, .strict))" }
        }.joined(separator: "&")
    }

    /// `fields` with `change` made to them, as the browser app makes it to the search it shows.
    static func applying(_ change: SearchChange, to fields: [String: [String]]) -> [String: [String]] {
        var fields = fields
        for (name, values) in change.fields { fields[name] = values }
        return fields
    }

    static func section(_ client: any TestClientProtocol, _ fields: [String: [String]]) async throws -> SearchFacetSection {
        let response = try await client.execute(uri: "/api/v1/search/facets?\(query(fields))", method: .get)
        guard response.status == .ok else { throw APIParityError("facets answered \(response.status): \(String(buffer: response.body))") }
        return try ServedFixture.decode(SearchFacetSection.self, response)
    }

    static func total(_ client: any TestClientProtocol, _ fields: [String: [String]]) async throws -> Int {
        let response = try await client.execute(uri: "/api/v1/search?\(query(fields))", method: .get)
        guard response.status == .ok else { throw APIParityError("search answered \(response.status): \(String(buffer: response.body))") }
        return try ServedFixture.decode(SearchResultList.self, response).total
    }

    /// Each section of each search, with the kit's standard sort and page size, is the kit's breakdown
    /// of the whole match cut by `FacetPaging`, with the kit's bounds, counts and sort titles.
    @Test func everySectionIsTheKitsBreakdownCutByFacetPaging() async throws {
        let kit = try await FixtureIndex.value().index.service
        try await ServedFixture.run { client, _ in
            var sectionsWithRows: Set<FacetSection> = []
            for keywords in Self.queries {
                let parameters = SearchParameters(keywords: keywords)
                for section in FacetSection.allCases {
                    let facets = try await kit.resultSetFacets(parameters: parameters, request: .one(section))
                    let page = FacetPaging.page(FacetRoutes.buckets(section, in: facets), with: .standard(for: section))
                    let api = try await Self.section(client, ["keywords": [keywords], "section": [section.rawValue]])
                    let context = "\(keywords), \(section)"
                    #expect(api.section == section.rawValue && api.matchCount == facets.matchCount, "\(context)")
                    #expect(api.rows.map { "\($0.key)|\($0.label)|\($0.count)" } == page.rows.map { "\($0.key)|\($0.label)|\($0.count)" }, "\(context)")
                    #expect(api.page == .init(matchingCount: page.matchingCount, totalCount: page.totalCount, pageIndex: page.pageIndex,
                                              pageCount: page.pageCount, firstRowNumber: page.firstRowNumber), "\(context)")
                    let standard = FacetDisplayState.standard(for: section)
                    #expect(api.display == .init(sort: standard.sort.rawValue, pageSize: standard.pageSize.rawValue, page: 0, filter: ""), "\(context)")
                    #expect(api.sortChoices.map(\.value) == FacetSort.choices(for: section).map(\.rawValue), "\(context)")
                    #expect(api.sortChoices.map(\.title) == FacetSort.choices(for: section).map { $0.title(for: section) }, "\(context)")
                    #expect(api.bound?.shown == facets.bounds[section]?.shown && api.bound?.total == facets.bounds[section]?.total, "\(context)")
                    #expect(api.undatedCount == (section == .years ? facets.undatedCount : nil), "\(context)")
                    #expect(api.topVolumeShare == (section == .volumes ? facets.topVolumeShare(3) : nil), "\(context)")
                    let provenance = facets.provenanceCoverage
                    #expect(api.provenanceCoverage == (section == .provenance
                        ? .init(parsed: provenance.parsed, withRecordGroup: provenance.withRecordGroup, matchCount: provenance.matchCount)
                        : nil), "\(context)")
                    #expect(api.subjectCoverage == (section == .subjects ? facets.subjectCoverage : nil), "\(context)")
                    #expect(api.subjectsPrepared == (section == .subjects ? facets.subjectsPrepared : nil), "\(context)")
                    #expect(api.selection == (FacetSelectionApplier.stagedSections.contains(section) ? "staged"
                        : section == .provenance ? "descriptive" : "immediate"), "\(context)")
                    if !api.rows.isEmpty { sectionsWithRows.insert(section) }
                }
            }
            // Each section is tested on rows, not on an empty breakdown.
            #expect(sectionsWithRows == Set(FacetSection.allCases))
        }
    }

    /// A sort, page size, page and filter of the browser app's choosing cut the rows as the kit cuts them.
    @Test func aSectionsSortPageAndFilterAreFacetPagings() async throws {
        let kit = try await FixtureIndex.value().index.service
        try await ServedFixture.run { client, _ in
            let parameters = SearchParameters(keywords: "treaty")
            let facets = try await kit.resultSetFacets(parameters: parameters, request: .one(.people))
            let people = FacetRoutes.buckets(.people, in: facets)
            for (sort, size, page, filter) in [(FacetSort.labelAscending, FacetPageSize.top5, 1, ""), (.labelDescending, .top10, 0, "an"),
                                                (.count, .all, 0, "e"), (.count, .top5, 999, "")] {
                let expected = FacetPaging.page(people, with: FacetDisplayState(sort: sort, pageSize: size, pageIndex: page, filterText: filter))
                let api = try await Self.section(client, [
                    "keywords": ["treaty"], "section": ["people"], "facetSort": [sort.rawValue], "facetPageSize": [size.rawValue],
                    "facetPage": [String(page)], "facetFilter": [filter],
                ])
                let context = "\(sort), \(size), \(page), \(filter)"
                #expect(api.rows.map(\.key) == expected.rows.map(\.key), "\(context)")
                #expect(api.page.matchingCount == expected.matchingCount && api.page.pageIndex == expected.pageIndex, "\(context)")
                // The page shown is the one there is: one past the last is clamped, as the kit clamps it.
                #expect(api.display.page == expected.pageIndex, "\(context)")
            }
        }
    }

    /// A row of a section that narrows on a click says how the search changes, and the change makes the
    /// search `FacetNarrowing` makes, which finds the row's documents.
    @Test func eachRowNarrowsAsFacetNarrowingDoes() async throws {
        let resources = try ServerResources.load(from: ServedFixture.resources).indexing
        let kit = try await FixtureIndex.value().index.service
        try await ServedFixture.run { client, _ in
            var narrowed: Set<FacetSection> = []
            for keywords in Self.queries {
                let parameters = SearchParameters(keywords: keywords)
                let fields = SearchRequest.formFields(parameters)
                for section in [FacetSection.people, .documentType, .subjects] {
                    let api = try await Self.section(client, fields.merging(["section": [section.rawValue], "facetPageSize": ["all"]]) { $1 })
                    let buckets = FacetRoutes.buckets(section, in: try await kit.resultSetFacets(parameters: parameters, request: .one(section)))
                    for row in api.rows {
                        let change = try #require(row.narrowing, "\(keywords), \(section), \(row.key)")
                        let kitBucket = try #require(buckets.first { $0.key == row.key }, "\(keywords), \(section), \(row.key)")
                        let bucket = try #require(FacetNarrowing.forBucket(kitBucket, in: section))
                        var expected = parameters
                        bucket.apply(to: &expected, resources: resources)
                        let applied = Self.applying(change, to: fields)
                        #expect(try SearchRequest(formEncoded: Self.query(applied)).parameters == expected, "\(keywords), \(section), \(row.key)")
                        #expect(try await Self.total(client, applied) == row.count, "\(keywords), \(section), \(row.label)")
                        narrowed.insert(section)
                    }
                }
                // Staged and descriptive rows carry no narrowing of their own.
                for section in [FacetSection.years, .volumes, .provenance] {
                    let api = try await Self.section(client, fields.merging(["section": [section.rawValue]]) { $1 })
                    #expect(api.rows.allSatisfy { $0.narrowing == nil }, "\(keywords), \(section)")
                }
            }
            #expect(narrowed == [.people, .documentType, .subjects])
        }
    }

    /// Apply resolves a staged selection over the section's whole list, as `FacetSelection.resolved(from:)`
    /// does, into the filter `FacetSelectionApplier` sets, and the search it gives counts the chosen rows.
    @Test func aStagedSelectionResolvesAsTheKitResolvesIt() async throws {
        let kit = try await FixtureIndex.value().index.service
        try await ServedFixture.run { client, _ in
            let parameters = SearchParameters(keywords: "treaty")
            let fields = SearchRequest.formFields(parameters)
            for section in [FacetSection.years, .volumes] {
                let buckets = FacetRoutes.buckets(section, in: try await kit.resultSetFacets(parameters: parameters, request: .one(section)))
                try #require(buckets.count >= 3, "\(section) needs rows to choose among")
                let keys = buckets.map(\.key)
                let choices: [(included: [String], excluded: [String])] = [
                    ([keys[0], keys[2]], []), ([], [keys[1]]), (keys, []), ([], keys),
                ]
                for (included, excluded) in choices {
                    var query = fields
                    query["section"] = [section.rawValue]
                    if !included.isEmpty { query["include"] = included }
                    if !excluded.isEmpty { query["exclude"] = excluded }
                    let response = try await client.execute(uri: "/api/v1/search/facets/selection?\(Self.query(query))", method: .get)
                    let api = try ServedFixture.decode(SearchFacetSelection.self, response)
                    let resolved = FacetSelection(included: Set(included), excluded: Set(excluded)).resolved(from: keys)
                    var expected = parameters
                    FacetSelectionApplier.apply(section, keys: resolved, to: &expected)
                    let context = "\(section), included \(included), excluded \(excluded)"
                    #expect(api.section == section.rawValue && api.keys == resolved, "\(context)")
                    let applied = Self.applying(api.change, to: fields)
                    #expect(try SearchRequest(formEncoded: Self.query(applied)).parameters == expected, "\(context)")
                    // The search counts the chosen rows' documents: each document has one year and one
                    // volume. A volume selection that excludes every row clears the filter instead.
                    let chosen = buckets.filter { resolved?.contains($0.key) ?? false }.map(\.count).reduce(0, +)
                    let all = buckets.map(\.count).reduce(0, +)
                    let total = try await Self.total(client, applied)
                    if section == .volumes, resolved?.isEmpty ?? true {
                        #expect(api.change.fields["volumeIds"] == nil && total == all, "\(context)")
                    } else {
                        #expect(total == chosen, "\(context)")
                    }
                }
                // A key the section's list does not hold, as rows counted before a new index can be, is
                // refused, where the kit would drop it: rather than widen the search, the browser counts again.
                var stale = fields
                stale["section"] = [section.rawValue]
                stale["include"] = ["no such key", keys[0]]
                let response = try await client.execute(uri: "/api/v1/search/facets/selection?\(Self.query(stale))", method: .get)
                #expect(response.status == .conflict && String(buffer: response.body).contains("SECTION_CHANGED"), "\(section)")
            }
        }
    }
}
