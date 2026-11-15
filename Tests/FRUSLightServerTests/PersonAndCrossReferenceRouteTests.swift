// Person and Cross-Reference Analytics' routes (PLAN's S24g), over the synthetic export: what a request may ask and what
// is refused, the exports' attachments and the figures' plates, and the answers while no index is served; and, over
// values, the rules the fixtures cannot reach: the broken references' caption at any count, the series kept once per
// index, and the heat matrix's column codes. The series themselves are held to the kit's over the fixture index in
// `PersonAndCrossReferenceParityTests`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct PersonAndCrossReferenceRouteTests {
    @Test func theRequestsAndRefusals() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let people = try decode(PersonAnalyticsAnswer.self, try await client.execute(uri: "/api/v1/analytics/people", method: .get))
            #expect(people.years.start == 1861 && !people.years.isCustom && people.scope.label == "Whole corpus")
            #expect(people.ranking.heading == "Most-Mentioned People" && people.comparison.people.isEmpty && people.relationship == nil)
            #expect(people.ranking.subtitle.contains("1861–\(people.years.end)."), "\(people.ranking.subtitle)")
            #expect(people.comparison.prompt.hasPrefix("Add up to 5 people") && people.comparison.table.rows.isEmpty)
            if let first = people.ranking.rows.first {
                let one = try decode(PersonAnalyticsAnswer.self, try await client.execute(
                    uri: "/api/v1/analytics/people?people=\(first.rollupId)&decade=true&values=percentOfDocuments", method: .get))
                #expect(one.comparison.people.map(\.rollupId) == [first.rollupId] && one.comparison.periodLabel == "Decade"
                        && one.comparison.valueAxisLabel == "% of documents")
                let network = try decode(PersonNetworkAnswer.self, try await client.execute(
                    uri: "/api/v1/analytics/people/network?focus=\(first.rollupId)", method: .get))
                #expect(network.focus.rollupId == first.rollupId && network.nodes.first?.isFocus == true)
                let csv = try await client.execute(uri: "/api/v1/analytics/people/export?chart=ranking&timeZone=UTC", method: .get)
                #expect(csv.status == .ok && String(buffer: csv.body).hasPrefix("# "))
                let plate = try decode(AnalyticsPlate.self, try await client.execute(uri: "/api/v1/analytics/people/plate?chart=ranking", method: .get))
                #expect(plate.lines.first?.role == "title" && plate.lines.first?.text == "Most-Mentioned People")
                let matches = try decode(PersonAnalyticsMatches.self, try await client.execute(
                    uri: "/api/v1/analytics/people/search?q=\(String(first.name.prefix(3)).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")",
                    method: .get))
                #expect(matches.people.count <= 20)
            }
            let blank = try decode(PersonAnalyticsMatches.self, try await client.execute(uri: "/api/v1/analytics/people/search?q=%20", method: .get))
            #expect(blank.people.isEmpty)
            for (path, code) in [
                ("people?people=abc", "INVALID_PARAMETER"), ("people?people=999999999", "PERSON_NOT_FOUND"),
                ("people?people=1&people=1", "INVALID_PARAMETER"),
                ("people?people=1&people=2&people=3&people=4&people=5&people=6", "INVALID_PARAMETER"),
                ("people?values=percent", "INVALID_PARAMETER"), ("people?decade=yes", "INVALID_PARAMETER"),
                ("people?from=1950&to=1900", "INVALID_PARAMETER"), ("people?to=2999", "INVALID_PARAMETER"),
                ("people?volume=frus1800nowhere", "VOLUME_NOT_FOUND"), ("people?term=x", "UNKNOWN_PARAMETER"),
                ("people/search?q=\(String(repeating: "a", count: 201))", "INVALID_PARAMETER"),
                ("people/network", "INVALID_PARAMETER"), ("people/network?focus=999999999", "PERSON_NOT_FOUND"),
                ("people/network?focus=1&from=1900", "UNKNOWN_PARAMETER"),
                ("people/export?chart=pie", "INVALID_PARAMETER"), ("people/export?chart=trajectories", "NOTHING_TO_EXPORT"),
                ("people/export?chart=relationship", "NOTHING_TO_EXPORT"), ("people/plate?chart=relationship", "NOTHING_TO_EXPORT"),
                ("people/export?timeZone=Mars/Olympus", "INVALID_PARAMETER"),
                ("cross-references?outDegree=maybe", "INVALID_PARAMETER"), ("cross-references?from=1950&to=1900", "INVALID_PARAMETER"),
                ("cross-references?people=1", "UNKNOWN_PARAMETER"), ("cross-references/plate?chart=landmarks", "NOTHING_TO_EXPORT"),
                ("cross-references/export?chart=pie", "INVALID_PARAMETER"),
            ] {
                #expect(problemCode(try await client.execute(uri: "/api/v1/analytics/\(path)", method: .get)) == code, "\(path)")
            }

            let references = try decode(CrossReferenceAnalyticsAnswer.self, try await client.execute(
                uri: "/api/v1/analytics/cross-references?outDegree=true", method: .get))
            #expect(references.scope.label == "Whole corpus" && !references.years.isCustom && references.emptyTitle == "No Data")
            #expect(references.distribution.showsOutDegree && references.resolvedCaption.hasPrefix("The most-referenced, degree, and PageRank charts"))
            #expect((references.excludedBrokenCaption != nil) == (references.excludedBrokenCount > 0))
            #expect(references.matrix.subtitle.hasPrefix("Citations between the 15 volumes"))
            if !references.ranking.rows.isEmpty {
                let csv = try await client.execute(uri: "/api/v1/analytics/cross-references/export?chart=ranking&timeZone=UTC", method: .get)
                #expect(csv.status == .ok && csv.headers[.contentDisposition]?.contains("FRUS-Analytics-Most-Referenced-Documents-") == true)
                #expect(String(buffer: csv.body).contains("cross-reference"), "the method block says the exclusion")
            }
        }
        // No index served yet: each route says so, as the other analytics routes do.
        let waiting = try await UserDataFixture()
        defer { withExtendedLifetime(waiting) {} }
        try await waiting.app.test(.router) { client in
            for uri in ["/api/v1/analytics/people", "/api/v1/analytics/people/network?focus=1", "/api/v1/analytics/people/search?q=a",
                        "/api/v1/analytics/cross-references"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(response.status == .serviceUnavailable && problemCode(response) == "INDEX_NOT_READY", "\(uri)")
            }
        }
    }

    /// The broken references excluded are said on the page when there are any, one in the singular and more grouped, and
    /// always in the export's statement, "none" being a fact a reader needs.
    @Test func theExcludedReferencesAreSaid() throws {
        let resources = try TestResources.value()
        let ask = CrossReferenceAnalyticsAsk(start: 1861, end: 1992, scope: .wholeCorpus, showOutDegree: false)
        func answer(_ excluded: Int) -> CrossReferenceAnalyticsAnswer {
            let series = CrossReferenceSeries(excludedBrokenCount: excluded, ranking: [], distribution: [], outDistribution: [],
                                              matrixVolumes: [], matrixCells: [], matrixMaxCount: 0, landmarks: [])
            return CrossReferenceAnalyticsView(ask: ask, series: series, resources: resources).answer(corpusMaxYear: 1992)
        }
        #expect(answer(0).excludedBrokenCaption == nil)
        #expect(answer(1).excludedBrokenCaption == "1 unresolvable reference is excluded from this analysis — a cross-reference in the printed volumes that points to a document, page, or volume not present in the corpus.")
        #expect(answer(1_234).excludedBrokenCaption == "1,234 unresolvable references are excluded from this analysis — cross-references in the printed volumes that point to a document, page, or volume not present in the corpus.")
        let empty = answer(0)
        #expect(empty.ranking.empty != nil && empty.distribution.empty != nil && empty.matrix.empty != nil && empty.landmarks.empty != nil)
        for excluded in [0, 1, 1_234] {
            let statement = CrossReferenceAnalyticsView.crossRefProvenance(
                figureTitle: "Most-Referenced Documents", axisLabel: "Ranked by inbound references", extra: [], excludedBrokenCount: excluded,
                scopeLabel: nil, indexedVolumeCount: 3, start: 1861, end: 1992, date: Date())
            let said = statement.extraCaveats.first ?? ""
            #expect(said.hasPrefix("Unresolvable references: \(excluded.formatted(.number.locale(Locale(identifier: "en_US")))) cross-reference"), "\(said)")
        }
    }

    /// A series is computed once for its key, however many ask for it at once, and the least recently asked is let go past
    /// the capacity; a computation that fails keeps nothing.
    @Test func theSeriesAreKeptOnce() async throws {
        actor Counter {
            var count = 0
            func next() -> Int { count += 1; return count }
        }
        let counter = Counter()
        let kept = KeptSeries<Int, Int>(capacity: 2)
        let values = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await kept.value(for: 1) {
                        try await Task.sleep(for: .milliseconds(50))
                        return await counter.next()
                    }
                }
            }
            return try await group.reduce(into: [Int]()) { $0.append($1) }
        }
        let computed = await counter.count
        #expect(values == Array(repeating: 1, count: 8) && computed == 1)
        _ = try await kept.value(for: 2) { await counter.next() }
        _ = try await kept.value(for: 1) { await counter.next() }
        _ = try await kept.value(for: 3) { await counter.next() }
        // 2 was the least recently asked, so it went; 1 is still kept.
        let held = await kept.count
        let one = try await kept.value(for: 1) { -1 }
        let two = try await kept.value(for: 2) { -2 }
        #expect(held == 2 && one == 1 && two == -2)
        struct Failed: Error {}
        await #expect(throws: Failed.self) { try await kept.value(for: 9) { throw Failed() } }
        let nine = try await kept.value(for: 9) { 9 }
        #expect(nine == 9)
    }

    /// The heat matrix's column codes, as the app's `matrixColumnCodes` writes them: a number, a topic word, and escalated
    /// where two would read alike.
    @Test func theMatrixColumnCodes() {
        let codes = matrixColumnCodes([
            (id: "frus1955-57v02", subseries: "1955-57", title: "Foreign Relations of the United States, 1955–1957, Volume II, China", topic: "China"),
            (id: "frus1969-76ve13", subseries: "1969-76", title: "Foreign Relations of the United States, 1969–1976, Volume E–13, Documents on China and India", topic: "Documents on China and India"),
            (id: "frus1861", subseries: "1861", title: "Papers Relating to Foreign Affairs", topic: ""),
            (id: "frus1945Malta", subseries: "1945", title: "The Conferences at Malta and Yalta, 1945", topic: "The Conferences at Malta and Yalta"),
            (id: "frus1945Berlinv01", subseries: "1945", title: "The Conference of Berlin (The Potsdam Conference), 1945, Volume I", topic: "The Conference of Berlin"),
            (id: "frus1945Berlinv02", subseries: "1945", title: "The Conference of Berlin (The Potsdam Conference), 1945, Volume I", topic: "The Conference of Berlin"),
        ])
        #expect(codes["frus1955-57v02"] == "\u{2019}55–57 II")
        #expect(codes["frus1969-76ve13"] == "\u{2019}69–76 E–13")
        #expect(codes["frus1861"] == "\u{2019}61")
        #expect(codes["frus1945Malta"] == "\u{2019}45 Confer")
        // Two that read alike even escalated fall back to their ids' suffixes.
        #expect(codes["frus1945Berlinv01"] == "\u{2019}45 Berlinv01" && codes["frus1945Berlinv02"] == "\u{2019}45 Berlinv02")
        #expect(matrixTopicWords("Documents on the United Nations") == ["United", "Nations"])
    }
}
