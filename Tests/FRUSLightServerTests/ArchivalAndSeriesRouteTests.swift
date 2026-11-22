// Archival Analytics' and About the Series' routes (PLAN's S24h), over the synthetic export: what a request may ask and
// what is refused, the exports' attachments and the figures' plates, and the answers while no index is served, when
// every surface but Your Library still answers, from the bundled data; and, over values, what the fixtures cannot
// reach: the series kept once per bundle, the share's words at any size, and the administrations' labels. The series
// themselves are held to the kit's in `ArchivalAndSeriesParityTests`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct ArchivalAndSeriesRouteTests {
    @Test func theRequestsAndRefusals() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let context = try decode(ArchivalContext.self, try await client.execute(uri: "/api/v1/analytics/archives/context", method: .get))
            #expect(context.modes.map(\.title) == ["Collections", "Network", "Flows", "Your Library"])
            #expect(context.bands.count == 5 && context.defaultBand == "1" && context.bands[1].title == "1948–1960")
            #expect(context.thresholds.count == 12 && context.defaultThreshold == 0.25 && context.layers.count == 2)
            #expect(context.administrations.contains { $0.id == "kennedy" } && context.seriesVolumeIds.count == context.subseries.flatMap(\.volumes).count)
            #expect(context.networkUnavailable == nil && context.flowsUnavailable == nil)

            let collections = try decode(ArchivalCollectionsAnswer.self, try await client.execute(uri: "/api/v1/analytics/archives", method: .get))
            #expect(collections.band == "1" && collections.lens == "namedCollections" && collections.weight == "documents" && collections.hidesUmbrella)
            #expect(collections.scope.label == "Whole corpus" && !collections.scope.isNarrowed && collections.ranking.rows.count == 12)
            #expect(collections.ranking.title == "Top collections by era" && collections.umbrella?.value == "Hidden")
            #expect(collections.denominator?.sentence.contains(" in 1948–1960. The 12 rows below account for ") == true, "\(collections.denominator?.sentence ?? "")")
            let kennedy = try decode(ArchivalCollectionsAnswer.self, try await client.execute(uri: "/api/v1/analytics/archives?administration=kennedy&band=2", method: .get))
            #expect(kennedy.scope.label == "John F. Kennedy" && kennedy.scope.isNarrowed)
            #expect(kennedy.denominator?.sentence.contains("John F. Kennedy, 1961–1968.") == true, "\(kennedy.denominator?.sentence ?? "")")
            let classes = try decode(ArchivalCollectionsAnswer.self, try await client.execute(uri: "/api/v1/analytics/archives?lens=centralFileClasses&band=0", method: .get))
            #expect(classes.umbrella == nil && classes.ranking.title == "Top central-file classes by era")
            let units = try decode(ArchivalUnitsAnswer.self, try await client.execute(uri: "/api/v1/analytics/archives/units", method: .get))
            #expect(units.title == "Every Unit" && units.rows.first?.rank == "1." && units.rows.count > 12)

            let network = try decode(ArchivalNetworkAnswer.self, try await client.execute(uri: "/api/v1/analytics/archives/network", method: .get))
            #expect(network.focus != nil && !network.nodes.isEmpty && network.layout?.width == 720 && network.threshold == 0.25)
            #expect(network.labels.first?.id == network.focus?.id && network.labels.first?.isFocus == true, "the focus's label is placed first")
            #expect(network.sectors.map(\.start) == [180, 270, 0, 90] && network.dock.title == "Select a node to see the link")
            let candidates = try decode(ArchivalFocusCandidates.self, try await client.execute(uri: "/api/v1/analytics/archives/network/candidates?q=lot", method: .get))
            #expect(!candidates.candidates.isEmpty && candidates.candidates.count <= 200 && candidates.title == "Focus Collection")
            if let partner = network.nodes.first, let focus = network.focus {
                let id = focus.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
                let shown = try decode(ArchivalNetworkAnswer.self, try await client.execute(
                    uri: "/api/v1/analytics/archives/network?focus=\(id)&selected=\(partner.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")",
                    method: .get))
                #expect(shown.dock.node?.id == partner.id && shown.dock.node?.detail.contains("cite both") == true)
                let group = try decode(ArchivalNetworkAnswer.self, try await client.execute(
                    uri: "/api/v1/analytics/archives/network?focus=\(id)&group=\(partner.category)&only=true", method: .get))
                #expect(group.dock.group?.onlyThisGroup == true && group.nodes.allSatisfy { $0.category == partner.category })
                #expect(group.dock.group?.rescaled?.hasPrefix("Only this group is drawn") == true)
            }

            let flows = try decode(ArchivalFlowsAnswer.self, try await client.execute(uri: "/api/v1/analytics/archives/flows", method: .get))
            #expect(flows.focus == nil && flows.corpusWide?.pairs.count == 15 && flows.focusValue == "The whole series")
            #expect(flows.caveats.title == "Measured here" && flows.caveats.lines.count == 2)
            let unprinted = try decode(ArchivalFlowsAnswer.self, try await client.execute(uri: "/api/v1/analytics/archives/flows?layer=toUnprinted", method: .get))
            #expect(unprinted.layer == "toUnprinted" && unprinted.intro.hasPrefix("FRUS editors often include references"))

            let library = try decode(ArchivalLibraryAnswer.self, try await client.execute(uri: "/api/v1/analytics/archives/library", method: .get))
            #expect(library.composition.title == "Where your documents come from" && library.footer.title == "Measured here")

            for (chart, query) in [("ranking", ""), ("units", "&band=0"), ("network", ""), ("flows", ""), ("composition", "")] {
                let csv = try await client.execute(uri: "/api/v1/analytics/archives/export?chart=\(chart)\(query)&timeZone=UTC", method: .get)
                if chart == "composition", library.empty != nil {
                    #expect(problemCode(csv) == "NOTHING_TO_EXPORT", "an empty library exports nothing")
                    continue
                }
                #expect(csv.status == .ok && String(buffer: csv.body).hasPrefix("# "), "\(chart)")
                #expect(csv.headers[.contentDisposition]?.hasPrefix("attachment; filename=\"FRUS-Analytics-") == true, "\(chart)")
            }
            let plate = try decode(AnalyticsPlate.self, try await client.execute(uri: "/api/v1/analytics/archives/plate?chart=ranking", method: .get))
            // The kit's title for the ranking's export: the lens and the era.
            #expect(plate.lines.first?.role == "title" && plate.lines.first?.text == "Named collections by era — 1948–1960", "\(plate.lines.first?.text ?? "")")

            let about = try decode(SeriesContext.self, try await client.execute(uri: "/api/v1/about/context", method: .get))
            #expect(about.pages.map(\.title) == ["Production & Timeliness", "Geographic Emphasis", "Archival Sourcing", "Administration Profiles"])
            #expect(about.pages.map(\.defaultEnd) == [2026, 1993, 1993, 2026] && about.decades.first?.label == "1860s")
            let production = try decode(SeriesProductionAnswer.self, try await client.execute(uri: "/api/v1/about/production", method: .get))
            #expect(production.charts.map(\.id) == ["lag", "perYear", "cumulative"] && production.frame.scopeLabel == "Scope: Whole series")
            #expect(!production.frame.isCustomRange && production.charts[0].steps?.isEmpty == false)
            let narrowed = try decode(SeriesProductionAnswer.self, try await client.execute(uri: "/api/v1/about/production?from=1950&subseries=1961-63", method: .get))
            #expect(narrowed.frame.isCustomRange && narrowed.frame.scopeLabel == "Scope: 1961-63" && narrowed.caveats.lines.first?.hasPrefix("Scoped to the 1961-63 subseries") == true)
            let geography = try decode(SeriesGeographyAnswer.self, try await client.execute(uri: "/api/v1/about/geography", method: .get))
            #expect(geography.charts.map(\.id) == ["trend", "totals", "countries"] && geography.empty == nil)
            let sourcing = try decode(SeriesSourcingAnswer.self, try await client.execute(uri: "/api/v1/about/sourcing?hidden=unrecognized", method: .get))
            #expect(sourcing.filter.label == "Categories: 10 shown" && sourcing.filter.categories.first { $0.value == "unrecognized" }?.shown == false)
            #expect(sourcing.caveats.lines.first?.hasPrefix("Some categories are hidden.") == true && !sourcing.topCollections.rows.isEmpty)
            let administrations = try decode(SeriesAdministrationsAnswer.self, try await client.execute(uri: "/api/v1/about/administrations?administration=wilson", method: .get))
            #expect(administrations.detail?.focus == "wilson" && administrations.detail?.president == "Woodrow Wilson")
            #expect(administrations.detail?.stats.first?.value == "1913–1921" && administrations.charts.count == 2)
            let none = try decode(SeriesAdministrationsAnswer.self, try await client.execute(uri: "/api/v1/about/administrations?from=1776&to=1800", method: .get))
            #expect(none.narrowedEmpty?.title == "No administrations in view" && none.charts.isEmpty && none.detail == nil)
            let seriesCSV = try await client.execute(uri: "/api/v1/about/export?dashboard=geography&chart=totals&timeZone=UTC", method: .get)
            #expect(seriesCSV.status == .ok && String(buffer: seriesCSV.body).hasPrefix("# "))
            let seriesPlate = try decode(AnalyticsPlate.self, try await client.execute(uri: "/api/v1/about/plate?dashboard=administrations&chart=perYear", method: .get))
            #expect(seriesPlate.lines.first?.text == "Volumes per administration-year")

            for (path, code) in [
                ("analytics/archives?band=7", "INVALID_PARAMETER"), ("analytics/archives?band=01", "INVALID_PARAMETER"),
                ("analytics/archives?lens=everything", "INVALID_PARAMETER"), ("analytics/archives?weight=pages", "INVALID_PARAMETER"),
                ("analytics/archives?umbrella=yes", "INVALID_PARAMETER"), ("analytics/archives?term=x", "UNKNOWN_PARAMETER"),
                ("analytics/archives?administration=washington", "INVALID_PARAMETER"),
                ("analytics/archives?administration=clinton", "INVALID_PARAMETER"),
                ("analytics/archives?subseries=1861&administration=kennedy", "INVALID_PARAMETER"),
                ("analytics/archives?volume=frus1800nowhere", "VOLUME_NOT_FOUND"),
                ("analytics/archives?volumes=frus1800nowhere", "VOLUME_NOT_FOUND"),
                ("analytics/archives?scopeLabel=Mine", "INVALID_PARAMETER"),
                ("analytics/archives/network?focus=nowhere", "COLLECTION_NOT_FOUND"),
                ("analytics/archives/network?threshold=0.33", "INVALID_PARAMETER"), ("analytics/archives/network?only=true", "INVALID_PARAMETER"),
                ("analytics/archives/network?group=everyone", "INVALID_PARAMETER"), ("analytics/archives/network?width=10", "INVALID_PARAMETER"),
                ("analytics/archives/flows?layer=sideways", "INVALID_PARAMETER"), ("analytics/archives/flows?focus=nowhere", "COLLECTION_NOT_FOUND"),
                ("analytics/archives/flows?band=1", "UNKNOWN_PARAMETER"),
                ("analytics/archives/library?band=1", "UNKNOWN_PARAMETER"),
                ("analytics/archives/export?chart=pie", "INVALID_PARAMETER"),
                ("analytics/archives/export?chart=flows&band=1", "UNKNOWN_PARAMETER"),
                ("analytics/archives/plate?chart=network", "NOTHING_TO_EXPORT"), ("analytics/archives/plate?chart=units", "NOTHING_TO_EXPORT"),
                ("about/production?to=2027", "INVALID_PARAMETER"), ("about/geography?to=2000", "INVALID_PARAMETER"),
                ("about/production?from=1950&to=1900", "INVALID_PARAMETER"), ("about/production?hidden=lotFile", "UNKNOWN_PARAMETER"),
                ("about/sourcing?hidden=everything", "INVALID_PARAMETER"),
                ("about/sourcing?" + SourceProvenanceCategory.ordered.map { "hidden=\($0.rawValue)" }.joined(separator: "&"), "INVALID_PARAMETER"),
                ("about/administrations?editorialNotes=maybe", "INVALID_PARAMETER"),
                ("about/production?volume=frus1961-63v06", "UNKNOWN_PARAMETER"),
                ("about/production?volumes=frus1800nowhere", "INVALID_PARAMETER"),
                ("about/production?subseries=1700", "INVALID_PARAMETER"),
                ("about/export?dashboard=production&chart=totals", "INVALID_PARAMETER"),
                ("about/export?dashboard=everything", "INVALID_PARAMETER"),
                ("about/export?dashboard=production&chart=lag&from=1990&to=1991&subseries=1861", "NOTHING_TO_EXPORT"),
            ] {
                #expect(problemCode(try await client.execute(uri: "/api/v1/\(path)", method: .get)) == code, "\(path)")
            }
        }
        // No index served yet: every surface from the bundled data answers, Your Library alone waits for an index.
        let waiting = try await UserDataFixture()
        defer { withExtendedLifetime(waiting) {} }
        try await waiting.app.test(.router) { client in
            for uri in ["/api/v1/analytics/archives/context", "/api/v1/analytics/archives", "/api/v1/analytics/archives/units",
                        "/api/v1/analytics/archives/network", "/api/v1/analytics/archives/flows", "/api/v1/about/context",
                        "/api/v1/about/production", "/api/v1/about/geography", "/api/v1/about/sourcing", "/api/v1/about/administrations",
                        "/api/v1/analytics/archives/export?chart=ranking&timeZone=UTC", "/api/v1/about/export?dashboard=sourcing&chart=mix"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(response.status == .ok, "\(uri): \(response.status)")
            }
            let context = try decode(ArchivalContext.self, try await client.execute(uri: "/api/v1/analytics/archives/context", method: .get))
            #expect(context.indexedVolumeCount == 0)
            for uri in ["/api/v1/analytics/archives/library", "/api/v1/analytics/archives/export?chart=composition"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(response.status == .serviceUnavailable && problemCode(response) == "INDEX_NOT_READY", "\(uri)")
            }
        }
    }

    /// Each derivation is computed once for its scope and kept for the bundle, as the app's views keep what they loaded.
    @Test func theDerivationsAreKeptOncePerBundle() async throws {
        let resources = try TestResources.value().withOwnCatalogueOverlay()
        let bundle = resources.bundledAnalytics
        let whole = try await ArchivalAnalyticsRoutes.collections(.whole, resources: resources)
        let again = try await ArchivalAnalyticsRoutes.collections(.whole, resources: resources)
        #expect(await bundle.collections.count == 1 && whole.volumesPlaced == again.volumesPlaced)
        // A scope's volumes in another order are the same scope.
        _ = try await ArchivalAnalyticsRoutes.collections(ArchivalScope(volumeIds: ["frus1961-63v06", "frus1894Nicaragua"], label: "A"), resources: resources)
        _ = try await ArchivalAnalyticsRoutes.collections(ArchivalScope(volumeIds: ["frus1894Nicaragua", "frus1961-63v06"], label: "B"), resources: resources)
        #expect(await bundle.collections.count == 2)
        let scope = SeriesScopeAsk(volumeIds: ["frus1961-63v06"], label: "One")
        _ = try await AboutSeriesRoutes.production(scope, resources: resources)
        _ = try await AboutSeriesRoutes.production(scope, resources: resources)
        _ = try await AboutSeriesRoutes.production(.whole, resources: resources)
        #expect(await bundle.production.count == 2)
    }

    /// The words the views write around the kit's numbers, at the sizes the fixtures do not reach.
    @Test func theViewsWords() throws {
        #expect(ArchivalAnalyticsView.shareText(0.004) == "under 1%")
        #expect(ArchivalAnalyticsView.shareText(0.05) == "5.0%")
        #expect(ArchivalAnalyticsView.shareText(0.256) == "26%")
        #expect(ArchivalLibraryView.percentString(1, of: 0) == "0%")
        #expect(ArchivalLibraryView.percentString(1, of: 3) == "33.3%")
        #expect(ArchivalNetworkView.thresholds.first == 0.05 && ArchivalNetworkView.thresholds.last == 0.6 && ArchivalNetworkView.thresholds.count == 12)
        #expect(ArchivalNetworkView.dockSummarySentence(drawn: 1, aboveThreshold: 1, strongest: "100%")
                == "1 of the 1 node above the current threshold drawn. Distance from the center shows link strength. The dashed rings mark three quarters, one half, and one quarter of the strongest link here (100%).")
        #expect(ArchivalNetworkView.dockSummarySentence(drawn: 24, aboveThreshold: 1_250, strongest: "1,234").hasPrefix("24 of the 1,250 nodes above"))
        // Two presidents of one name are told apart by their first years, on the axis and in the picker.
        let profiles = try #require(TestResources.value().administrationProfiles)
        let data = AdministrationProfilesData(index: profiles, includeEditorialNotes: false, scopeVolumeIds: nil)
        let labels = AdministrationProfilesView.axisLabels(for: data.profiles)
        #expect(labels["cleveland-1"] == "Cleveland 1885" && labels["cleveland-2"] == "Cleveland 1893" && labels["wilson"] == "Wilson")
        let resources = try TestResources.value()
        let ask = SeriesAsk(dashboard: .administrations, start: 1861, end: 2026, scope: .whole)
        let view = AdministrationProfilesView(ask: ask, data: data, resources: resources)
        let cleveland = try #require(data.profiles.first { $0.id == "cleveland-1" })
        #expect(view.pickerLabel(for: cleveland) == "Grover Cleveland (1885–1889)")
        if let open = data.profiles.first(where: { $0.end == nil }) {
            #expect(view.termText(open).hasSuffix("–present"))
        }
        // The scope bar's decades: each subseries under the decade its first year begins.
        let groups = SeriesScopeBar.decadeGroups(resources.manifest)
        #expect(groups.first?.label == "1860s" && groups.map(\.decade) == groups.map(\.decade).sorted())
        #expect(groups.flatMap(\.buckets).map(\.subseries).contains("1961-63"))
    }
}
