// The facets routes over a synthetic export: a section's rows and their narrowings, Apply, and
// each refusal. FRUSParityTests holds every section to the kit's own calls over the fixture index.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct FacetRouteTests {
    @Test func facetsWaitForAnIndex() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for uri in ["/api/v1/search/facets?keywords=treaties&section=years",
                        "/api/v1/search/facets/selection?keywords=treaties&section=years&include=1961"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(try problem(response, .serviceUnavailable).code == "INDEX_NOT_READY", "\(uri)")
            }
        }
    }

    /// The People section of the synthetic export's two treaty documents: its one rollup, counted
    /// twice, narrows the search to that person by the rollup and its name; Volumes, a staged
    /// section, has no narrowing of its own, and Apply over it sets the volume filter.
    @Test func aSectionsRowsCarryTheirNarrowings() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let people = try decode(SearchFacetSection.self, try await client.execute(
                uri: "/api/v1/search/facets?keywords=treaties&section=people", method: .get))
            #expect(people.section == "people" && people.selection == "immediate" && people.matchCount == 2)
            let khrushchev = try #require(people.rows.first { $0.label == "Khrushchev, Nikita Sergeyevich" })
            #expect(khrushchev.count == 2)
            #expect(khrushchev.narrowing?.fields == ["personRollupId": ["1"], "personLabel": ["Khrushchev, Nikita Sergeyevich"]])
            #expect(people.coverage.indexedDocuments == 3)

            let volumes = try decode(SearchFacetSection.self, try await client.execute(
                uri: "/api/v1/search/facets?keywords=treaties&section=volumes", method: .get))
            #expect(volumes.selection == "staged" && volumes.rows.map(\.key) == ["frus1961-63v06"])
            #expect(volumes.rows.allSatisfy { $0.narrowing == nil })
            let applied = try decode(SearchFacetSelection.self, try await client.execute(
                uri: "/api/v1/search/facets/selection?keywords=treaties&section=volumes&include=frus1961-63v06", method: .get))
            #expect(applied.keys == ["frus1961-63v06"] && applied.change.fields == ["volumeIds": ["frus1961-63v06"]])
            // A row this search's list lacks, as one counted before a new index can be, is refused.
            let stale = try await client.execute(
                uri: "/api/v1/search/facets/selection?keywords=treaties&section=volumes&include=frus1894Nicaragua", method: .get)
            let refusal = try problem(stale, .conflict)
            #expect(refusal.code == "SECTION_CHANGED" && refusal.detail.contains("frus1894Nicaragua"))

            let types = try decode(SearchFacetSection.self, try await client.execute(
                uri: "/api/v1/search/facets?keywords=treaties&section=documentType", method: .get))
            #expect(types.rows.map(\.key) == ["0"] && types.rows.first?.narrowing?.fields == ["documentType": ["documentsOnly"]])
            #expect(types.sortChoices.isEmpty)
        }
    }

    @Test func eachWayAFacetsRequestFailsIsAProblem() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            for (uri, code, named) in [
                ("/api/v1/search/facets?keywords=treaties", "INVALID_PARAMETER", "section"),
                ("/api/v1/search/facets?keywords=treaties&section=decades", "INVALID_PARAMETER", "section"),
                ("/api/v1/search/facets?keywords=treaties&section=documentType&facetSort=labelAscending", "INVALID_PARAMETER", "facetSort"),
                ("/api/v1/search/facets?keywords=treaties&section=people&facetPageSize=top50", "INVALID_PARAMETER", "facetPageSize"),
                ("/api/v1/search/facets?keywords=treaties&section=people&facetPage=-1", "INVALID_PARAMETER", "facetPage"),
                ("/api/v1/search/facets?keywords=treaties&section=people&limit=5", "UNKNOWN_PARAMETER", "limit"),
                ("/api/v1/search/facets?keywords=treaties&section=people&include=1", "UNKNOWN_PARAMETER", "include"),
                ("/api/v1/search/facets?keywords=&section=people", "EMPTY_QUERY", "Nothing is left to search"),
                ("/api/v1/search/facets/selection?keywords=treaties&section=people&include=1", "INVALID_PARAMETER", "years, volumes"),
                ("/api/v1/search/facets/selection?keywords=treaties&section=years&include=1961&exclude=1961", "INVALID_PARAMETER", "1961"),
                ("/api/v1/search/facets/selection?keywords=treaties&section=years&facetSort=count", "UNKNOWN_PARAMETER", "facetSort"),
            ] {
                let response = try await client.execute(uri: uri, method: .get)
                let body = try problem(response, .badRequest)
                #expect(body.code == code && body.detail.contains(named), "\(uri): \(body.code) \(body.detail)")
            }
        }
    }
}

@Suite struct FacetCacheTests {
    /// How many computations ran, and a gate a computation can wait at.
    actor Computations {
        private(set) var count = 0
        private var waiting: [CheckedContinuation<Void, Never>] = []
        private var open = false

        func start() { count += 1 }

        func pass() async {
            if open { return }
            await withCheckedContinuation { waiting.append($0) }
        }

        func release() {
            open = true
            waiting.forEach { $0.resume() }
            waiting = []
        }
    }

    struct Failure: Error {}

    /// A computation of `matchCount` that counts itself.
    static func computing(_ matchCount: Int, _ computations: Computations) -> @Sendable () async throws -> ResultSetFacets {
        { await computations.start(); return .empty(matchCount: matchCount) }
    }

    @Test func aSectionAskedForAgainIsTheOneComputed() async throws {
        let cache = FacetCache()
        let computations = Computations()
        #expect(try await cache.section(.years, search: "a", compute: Self.computing(1, computations)).matchCount == 1)
        #expect(try await cache.section(.years, search: "a", compute: Self.computing(2, computations)).matchCount == 1)
        // Another section of the search, or the section of another search, is computed for itself.
        #expect(try await cache.section(.people, search: "a", compute: Self.computing(3, computations)).matchCount == 3)
        #expect(try await cache.section(.years, search: "b", compute: Self.computing(4, computations)).matchCount == 4)
        #expect(await computations.count == 3)
    }

    @Test func aSectionAskedForWhileItIsComputedWaitsForThatComputation() async throws {
        let cache = FacetCache()
        let computations = Computations()
        let first = Task {
            try await cache.section(.years, search: "a") {
                await computations.start()
                await computations.pass()
                return .empty(matchCount: 1)
            }
        }
        while await computations.count == 0 { await Task.yield() }
        let second = Task { try await cache.section(.years, search: "a", compute: Self.computing(2, computations)) }
        await computations.release()
        let (one, two) = (try await first.value, try await second.value)
        #expect(one.matchCount == 1 && two.matchCount == 1)
        #expect(await computations.count == 1)
    }

    @Test func theLeastRecentlyAskedForGoesWhenTheCacheIsFull() async throws {
        let cache = FacetCache(capacity: 2)
        let computations = Computations()
        for search in ["a", "b"] { _ = try await cache.section(.years, search: search, compute: Self.computing(1, computations)) }
        // Asking for a makes b the least recent, so c's computation drops b.
        _ = try await cache.section(.years, search: "a", compute: Self.computing(1, computations))
        _ = try await cache.section(.years, search: "c", compute: Self.computing(1, computations))
        #expect(await computations.count == 3)
        _ = try await cache.section(.years, search: "a", compute: Self.computing(1, computations))
        #expect(await computations.count == 3)
        _ = try await cache.section(.years, search: "b", compute: Self.computing(1, computations))
        #expect(await computations.count == 4)
    }

    @Test func aComputationThatFailsIsNotKept() async throws {
        let cache = FacetCache()
        let computations = Computations()
        await #expect(throws: Failure.self) {
            try await cache.section(.years, search: "a") {
                await computations.start()
                throw Failure()
            }
        }
        #expect(try await cache.section(.years, search: "a", compute: Self.computing(5, computations)).matchCount == 5)
        #expect(await computations.count == 2)
    }
}
