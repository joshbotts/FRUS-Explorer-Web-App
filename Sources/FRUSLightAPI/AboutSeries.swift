// About the Series (PLAN's S24h): the four dashboards the app's Research Guide shows under About the Series,
// `SeriesProductionDashboard`, `SeriesGeographyDashboard`, `SourceProvenanceDashboard` with its `TopCollectionsCard`, and
// `AdministrationProfilesDashboard`, from the bundled catalogue and data, which need nothing indexed. Every series is
// the kit's (FRUS-Explorer#1899, #1901): `SeriesProductionData` over the catalogue's entries, `SeriesGeographyData` over
// them and the taxonomy's places, `SourceProvenanceData` over the bundled aggregate, `AdministrationProfilesData` over
// the administrations' profiles, `ArchivalCollectionsData` for the top collections; each chart's years are cut by the
// kit's `effectiveDomain`, its table is the kit's `ChartInspectorAdapters`, and its statement the kit's
// `SeriesAnalyticsExport`, rendered by `AnalyticsProvenance` for the server's host. Each dashboard's data is computed
// once for its scope and kept (`BundledAnalytics`). What the dashboards decide between the kit and the screen is app
// code, mirrored here under their names and held to the app's source by `ArchivalAndSeriesMirrorParityTests`: the
// scope bar's menu (`SeriesScopeBar`), the default years, the category filter, the visible administrations, the focus,
// the axis labels, the detail card, the caveats and the words.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

// MARK: - The answers

/// What About the Series opens on: its four pages, the scope bar's menu over the series (`SeriesScopeBar`) and the
/// years' bounds.
public struct SeriesContext: Codable, Equatable, Sendable, ResponseEncodable {
    public var pages: [Page]
    /// By Subseries: the series' subseries grouped by the decade they begin in, each with its volumes' count.
    public var decades: [Decade]
    /// By Subject: the categories that narrow and hold a volume of the series, each with its sub-categories that do.
    public var topics: [Topic]
    /// The series' volumes, which a reader's own volume scope is resolved against.
    public var seriesVolumeIds: [String]
    public var floorYear: Int
    public var earliestYear: Int

    public struct Page: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var subtitle: String
        /// The dashboard's default last year: the production ceiling or the coverage ceiling.
        public var defaultEnd: Int
    }

    public struct Decade: Codable, Equatable, Sendable {
        public var label: String
        public var subseries: [String]
    }

    public struct Topic: Codable, Equatable, Sendable {
        public var label: String
        public var items: [String]
    }
}

/// A chart of a dashboard: its title, caption, the kit's table, and what Vega-Lite draws.
public struct SeriesChart: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var caption: String
    public var xLabel: String
    public var yLabel: String
    public var legendTitle: String?
    public var table: CorpusAnalyticsAnswer.Table?
    /// The points or bars, each a value of the x and y axes and its series' name.
    public var marks: [Mark]
    /// The target's steps under the publication-lag chart.
    public var steps: [Mark]?
    /// The x domain, where the chart fixes it: the dashboard's years, cut by `effectiveDomain`.
    public var domain: [Int]?
    /// The series' names in the order the legend gives them.
    public var series: [String]

    public struct Mark: Codable, Equatable, Sendable {
        public var x: String
        public var y: Double
        public var series: String?
    }
}

/// The scope chip and the years a dashboard is drawn for.
public struct SeriesFrame: Codable, Equatable, Sendable {
    /// "Scope: Whole series", or the scope's label.
    public var scopeLabel: String
    public var isNarrowed: Bool
    public var start: Int
    public var end: Int
    public var defaultEnd: Int
    public var isCustomRange: Bool
}

/// A dashboard's caveats under their heading.
public struct SeriesCaveats: Codable, Equatable, Sendable {
    public var title: String
    public var lines: [String]
}

public struct SeriesProductionAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var frame: SeriesFrame
    public var empty: SeriesCaveats?
    public var intro: String
    public var charts: [SeriesChart]
    public var caveats: SeriesCaveats
}

public struct SeriesGeographyAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var frame: SeriesFrame
    public var empty: SeriesCaveats?
    public var intro: String
    public var charts: [SeriesChart]
    public var caveats: SeriesCaveats
}

public struct SeriesSourcingAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var frame: SeriesFrame
    public var empty: SeriesCaveats?
    /// Whether the scope bar is offered: the aggregate must carry its per-volume rows.
    public var supportsScope: Bool
    public var intro: String
    public var filter: CategoryFilter
    public var charts: [SeriesChart]
    public var topCollections: TopCollections
    public var archivalLink: String
    public var archivalLinkDetail: String
    public var caveats: SeriesCaveats

    public struct CategoryFilter: Codable, Equatable, Sendable {
        /// "Categories: all", or how many are shown.
        public var label: String
        public var accessibilityLabel: String
        public var accessibilityValue: String
        public var categories: [Category]
        public var showAll: String?
    }

    public struct Category: Codable, Equatable, Sendable {
        public var value: String
        public var name: String
        public var shown: Bool
        /// Whether the menu lets it change: the last one shown cannot be hidden.
        public var enabled: Bool
    }

    public struct TopCollections: Codable, Equatable, Sendable {
        public var title: String
        public var caption: String
        /// The years fall outside every era, or the scope names no collection.
        public var notice: String?
        public var rows: [Row]
        public var legend: [Legend]
        public var footnotes: [String]
        public var method: String?
    }

    public struct Row: Codable, Equatable, Sendable {
        public var id: String
        public var label: String
        public var value: Int
        public var category: String
        public var categoryName: String
        /// The bar's length, a share of the first row's.
        public var bar: Double
        public var opens: Bool
    }

    public struct Legend: Codable, Equatable, Sendable {
        public var category: String
        public var name: String
    }
}

public struct SeriesAdministrationsAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var frame: SeriesFrame
    public var empty: SeriesCaveats?
    /// No administration in view under the scope and years.
    public var narrowedEmpty: SeriesCaveats?
    public var intro: String
    public var toggle: Toggle
    public var charts: [SeriesChart]
    public var detail: Detail?
    public var caveats: SeriesCaveats

    public struct Toggle: Codable, Equatable, Sendable {
        public var title: String
        public var subtitle: String
        public var isOn: Bool
    }

    public struct Detail: Codable, Equatable, Sendable {
        public var title: String
        public var pickerLabel: String
        public var choices: [Choice]
        public var focus: String
        public var president: String
        public var party: String
        public var partyName: String
        public var stats: [Stat]
        public var volumesHeader: String
        public var volumesCaption: String
        public var volumesEmpty: String?
        public var volumes: [Volume]
    }

    public struct Choice: Codable, Equatable, Sendable {
        public var id: String
        public var label: String
    }

    public struct Stat: Codable, Equatable, Sendable {
        public var label: String
        public var value: String
    }

    public struct Volume: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var documents: String
        public var proportion: String
    }
}

// MARK: - The request

/// The dashboards.
enum SeriesDashboard: String, CaseIterable, Sendable {
    case production
    case geography
    case sourcing
    case administrations

    /// The page's id in the app's Research Guide.
    var pageId: String { "series-\(self == .administrations ? "administrations" : rawValue)" }

    /// The charts each draws, in its order, each exported with its table and figure.
    var charts: [String] {
        switch self {
        case .production: ["lag", "perYear", "cumulative"]
        case .geography: ["trend", "totals", "countries"]
        case .sourcing: ["mix", "composition", "density"]
        case .administrations: ["documents", "perYear"]
        }
    }

    /// `defaultEnd`: the production ceiling where the x axis is a print year or a term, the coverage ceiling where it
    /// is a coverage decade.
    var defaultEnd: Int {
        switch self {
        case .production, .administrations: SeriesChartKind.productionCeilingYear
        case .geography, .sourcing: SeriesChartKind.coverageCeilingYear
        }
    }
}

/// The series scope, as `SeriesScopeBar` sets it: its volumes and label, or the whole series.
struct SeriesScopeAsk: Sendable, Equatable {
    var volumeIds: Set<String>?
    var label: String?

    static let whole = SeriesScopeAsk(volumeIds: nil, label: nil)

    /// `SeriesScope.filter(_:)`: the entries the scope holds.
    func filter(_ entries: [VolumeManifestEntry]) -> [VolumeManifestEntry] {
        guard let ids = volumeIds else { return entries }
        return entries.filter { ids.contains($0.volumeId) }
    }
}

/// What a dashboard asks: its years, scope, hidden categories, editorial notes and the administration picked.
struct SeriesAsk: Sendable {
    var dashboard: SeriesDashboard
    var start: Int
    var end: Int
    var scope: SeriesScopeAsk
    var hiddenCategories: Set<SourceProvenanceCategory> = []
    var includeEditorialNotes = false
    var administration: String?
}

enum AboutSeriesRoutes {
    static let scopeParameters: Set<String> = ["subseries", "topic", "subtopic", "volumes", "scopeLabel"]
    static let frameParameters = scopeParameters.union(["from", "to"])

    static func parameters(for dashboard: SeriesDashboard) -> Set<String> {
        switch dashboard {
        case .production, .geography: frameParameters
        case .sourcing: frameParameters.union(["hidden"])
        case .administrations: frameParameters.union(["editorialNotes", "administration"])
        }
    }

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/about/context") { request, _ -> SeriesContext in
            try FormQuery(request.uri.query).refuseUnknown([])
            return try await Blocking.run { context(resources: resources) }
        }
        router.get("/api/v1/about/production") { request, _ -> SeriesProductionAnswer in
            let ask = try ask(.production, request: request, resources: resources)
            return try await SeriesProductionView(ask: ask, data: production(ask.scope, resources: resources), resources: resources).answer()
        }
        router.get("/api/v1/about/geography") { request, _ -> SeriesGeographyAnswer in
            let ask = try ask(.geography, request: request, resources: resources)
            return try await SeriesGeographyView(ask: ask, data: geography(ask.scope, resources: resources), resources: resources).answer()
        }
        router.get("/api/v1/about/sourcing") { request, _ -> SeriesSourcingAnswer in
            let ask = try ask(.sourcing, request: request, resources: resources)
            let data = try await provenance(ask.scope, resources: resources)
            let archival = try await ArchivalAnalyticsRoutes.collections(ArchivalScope(volumeIds: ask.scope.volumeIds.map { $0.sorted() }, label: ask.scope.label), resources: resources)
            return SourceProvenanceView(ask: ask, data: data, resources: resources).answer(topCollections: TopCollectionsView(ask: ask, data: archival, resources: resources))
        }
        router.get("/api/v1/about/administrations") { request, _ -> SeriesAdministrationsAnswer in
            let ask = try ask(.administrations, request: request, resources: resources)
            let data = try await administrations(ask, resources: resources)
            return AdministrationProfilesView(ask: ask, data: data, resources: resources).answer()
        }
        router.get("/api/v1/about/export") { request, _ -> Response in
            let query = try FormQuery(request.uri.query)
            let (dashboard, chart) = try chart(query)
            try query.refuseUnknown(parameters(for: dashboard).union(["dashboard", "chart", "timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let now = Date()
            let (table, provenance) = try await export(dashboard, chart: chart, query: query, resources: resources)
            let csv = table.provenancedCSV(provenance, for: CorpusAnalyticsRoutes.host(timeZone: timeZone))
            return AnalyticsFigures.csv(csv, name: CorpusAnalyticsRoutes.filenameStem(title: provenance.figureTitle, date: now))
        }
        router.get("/api/v1/about/plate") { request, _ -> AnalyticsPlate in
            let query = try FormQuery(request.uri.query)
            let (dashboard, chart) = try chart(query)
            try query.refuseUnknown(parameters(for: dashboard).union(["dashboard", "chart", "timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let now = Date()
            let (_, provenance) = try await export(dashboard, chart: chart, query: query, resources: resources)
            return AnalyticsPlate(provenance, host: CorpusAnalyticsRoutes.host(timeZone: timeZone), date: now)
        }
    }

    // MARK: The context

    static func context(resources: ServerResources) -> SeriesContext {
        let entries = resources.manifest
        let manifestIds = Set(entries.map(\.volumeId))
        var topics: [SeriesContext.Topic] = []
        if let resolved = CorpusAnalyticsRoutes.detectedTopics(resources), !resolved.isEmpty {
            for category in ScopeFacets.narrowingCategories(resolvedByVolume: resolved) {
                let catIds = ScopeFacets.volumeIds(forCategory: category.label, resolvedByVolume: resolved)
                    .intersection(manifestIds)
                guard !catIds.isEmpty else { continue }
                let items = ScopeFacets.subCategoryCatalog(forCategory: category.label, resolvedByVolume: resolved)
                    .filter {
                        !ScopeFacets.volumeIds(forCategory: $0.category, subcategory: $0.subcategory, resolvedByVolume: resolved)
                            .intersection(manifestIds).isEmpty
                    }
                    .map(\.subcategory)
                topics.append(.init(label: category.label, items: items))
            }
        }
        return SeriesContext(
            pages: SeriesDashboard.allCases.map { dashboard in
                let (title, subtitle) = SeriesPages.page(dashboard)
                return .init(id: dashboard.pageId, title: title, subtitle: subtitle, defaultEnd: dashboard.defaultEnd)
            },
            decades: SeriesScopeBar.decadeGroups(entries).map { .init(label: $0.label, subseries: $0.buckets.map(\.subseries)) },
            topics: topics,
            seriesVolumeIds: manifestIds.sorted(),
            floorYear: SeriesChartKind.floorYear,
            earliestYear: CorpusAnalyticsRoutes.earliestYear)
    }

    // MARK: Reading the request

    static func ask(_ dashboard: SeriesDashboard, request: Request, resources: ServerResources) throws -> SeriesAsk {
        let query = try FormQuery(request.uri.query)
        try query.refuseUnknown(parameters(for: dashboard))
        return try ask(dashboard, query: query, resources: resources)
    }

    static func ask(_ dashboard: SeriesDashboard, query: FormQuery, resources: ServerResources) throws -> SeriesAsk {
        let end = dashboard.defaultEnd
        let start = try query.integer("from", in: CorpusAnalyticsRoutes.earliestYear...end, default: SeriesChartKind.floorYear)
        let last = try query.integer("to", in: CorpusAnalyticsRoutes.earliestYear...end, default: end)
        guard start <= last else { throw APIProblem.invalidParameter("from", "the range must start before it ends, not \(start)–\(last)") }
        var ask = SeriesAsk(dashboard: dashboard, start: start, end: last, scope: try scope(query, resources: resources))
        if dashboard == .sourcing, let hidden = try query.list("hidden") {
            var categories: Set<SourceProvenanceCategory> = []
            for raw in hidden {
                guard let category = SourceProvenanceCategory(rawValue: raw) else {
                    throw APIProblem.invalidParameter("hidden", "must be among \(SourceProvenanceCategory.ordered.map(\.rawValue).joined(separator: ", ")), not \(raw)")
                }
                categories.insert(category)
            }
            // `toggleCategory`: one category is always shown.
            guard categories.count < SourceProvenanceCategory.ordered.count else {
                throw APIProblem.invalidParameter("hidden", "one category is always shown")
            }
            ask.hiddenCategories = categories
        }
        if dashboard == .administrations {
            ask.includeEditorialNotes = try query.bool("editorialNotes") ?? false
            ask.administration = try query.single("administration")
        }
        return ask
    }

    /// The scope a request names, as `SeriesScopeBar` sets it: a subseries's volumes, a subject's volumes in the series,
    /// or a reader's volume scope resolved against the series, each under its label; never empty, as the bar offers no
    /// item with none.
    static func scope(_ query: FormQuery, resources: ServerResources) throws -> SeriesScopeAsk {
        let named = ["subseries", "topic", "volumes"].filter { !query.values($0).isEmpty }
        guard named.count <= 1 else {
            throw APIProblem.invalidParameter(named[1], "a scope is one of subseries, topic or volumes, not \(named.joined(separator: " and "))")
        }
        if !query.values("subtopic").isEmpty, named != ["topic"] {
            throw APIProblem.invalidParameter("subtopic", "is taken only with a topic")
        }
        if !query.values("scopeLabel").isEmpty, named != ["volumes"] {
            throw APIProblem.invalidParameter("scopeLabel", "is taken only with a scope of volumes")
        }
        let entries = resources.manifest
        let manifestIds = Set(entries.map(\.volumeId))
        if let subseries = try query.single("subseries") {
            let ids = Set(entries.filter { !$0.subseries.isEmpty && $0.subseries == subseries }.map(\.volumeId))
            guard !ids.isEmpty else { throw APIProblem.invalidParameter("subseries", "no volume of the series is in \(subseries)") }
            return SeriesScopeAsk(volumeIds: ids, label: subseries)
        }
        if let category = try query.single("topic") {
            guard let subcategory = try query.single("subtopic") else {
                throw APIProblem.invalidParameter("subtopic", "a topic is scoped by one of its sub-categories")
            }
            guard let resolved = CorpusAnalyticsRoutes.detectedTopics(resources), !resolved.isEmpty else {
                throw APIProblem.invalidParameter("topic", "this server has no subject data")
            }
            guard ScopeFacets.narrowingCategories(resolvedByVolume: resolved).contains(where: { $0.label == category }),
                  ScopeFacets.subCategoryCatalog(forCategory: category, resolvedByVolume: resolved)
                    .contains(where: { $0.subcategory == subcategory }) else {
                throw APIProblem.invalidParameter("topic", "\(category) · \(subcategory) is not a subject the scope menu offers")
            }
            let ids = ScopeFacets.volumeIds(forCategory: category, subcategory: subcategory, resolvedByVolume: resolved)
                .intersection(manifestIds)
            guard !ids.isEmpty else { throw APIProblem.invalidParameter("topic", "no volume of the series is in \(category) · \(subcategory)") }
            return SeriesScopeAsk(volumeIds: ids, label: "\(category) · \(subcategory)")
        }
        if let ids = try query.list("volumes") {
            guard !ids.isEmpty else { throw APIProblem.invalidParameter("volumes", "a scope names at least one volume") }
            guard ids.count <= CorpusAnalyticsRoutes.maximumScopeVolumes else {
                throw APIProblem.invalidParameter("volumes", "names \(ids.count) volumes, more than \(CorpusAnalyticsRoutes.maximumScopeVolumes)")
            }
            // `CustomScopeResolver.manifestVolumeIds`: the scope's members the series holds.
            let resolved = CustomScopeResolver.manifestVolumeIds(memberVolumeIds: ids, manifestIds: manifestIds)
            guard !resolved.isEmpty else { throw APIProblem.invalidParameter("volumes", "no volume of the series is in this scope") }
            let label = try query.single("scopeLabel")
            return SeriesScopeAsk(volumeIds: resolved, label: label?.isEmpty == true ? nil : label)
        }
        return .whole
    }

    static func chart(_ query: FormQuery) throws -> (SeriesDashboard, String) {
        let dashboard = try query.choice("dashboard", among: SeriesDashboard.allCases) ?? .production
        let chart = try query.single("chart") ?? dashboard.charts[0]
        guard dashboard.charts.contains(chart) else {
            throw APIProblem.invalidParameter("chart", "must be one of \(dashboard.charts.joined(separator: ", ")), not \(chart)")
        }
        return (dashboard, chart)
    }

    // MARK: The kept data

    static func production(_ scope: SeriesScopeAsk, resources: ServerResources) async throws -> SeriesProductionData {
        let key = SeriesScopeKey(scope.volumeIds.map { Array($0) })
        return try await resources.bundledAnalytics.production.value(for: key) {
            try await Blocking.run { SeriesProductionData(entries: scope.filter(resources.manifest)) }
        }
    }

    static func geography(_ scope: SeriesScopeAsk, resources: ServerResources) async throws -> SeriesGeographyData {
        let key = SeriesScopeKey(scope.volumeIds.map { Array($0) })
        return try await resources.bundledAnalytics.geography.value(for: key) {
            try await Blocking.run {
                SeriesGeographyData(entries: scope.filter(resources.manifest),
                                    placeRegions: resources.bundledAnalytics.placeRegions(in: resources.directory))
            }
        }
    }

    static func provenance(_ scope: SeriesScopeAsk, resources: ServerResources) async throws -> SourceProvenanceData {
        let key = SeriesScopeKey(scope.volumeIds.map { Array($0) })
        return try await resources.bundledAnalytics.provenance.value(for: key) {
            try await Blocking.run {
                SourceProvenanceData(index: resources.bundledAnalytics.sourceProvenance.value(in: resources.directory),
                                     scopeVolumeIds: scope.volumeIds)
            }
        }
    }

    static func administrations(_ ask: SeriesAsk, resources: ServerResources) async throws -> AdministrationProfilesData {
        let key = AdministrationsKey(scope: SeriesScopeKey(ask.scope.volumeIds.map { Array($0) }),
                                     includeEditorialNotes: ask.includeEditorialNotes)
        return try await resources.bundledAnalytics.administrations.value(for: key) {
            try await Blocking.run {
                AdministrationProfilesData(
                    index: resources.administrationProfiles,
                    includeEditorialNotes: ask.includeEditorialNotes,
                    scopeVolumeIds: ask.scope.volumeIds)
            }
        }
    }

    // MARK: The export

    /// A chart's table and statement, as its card's export control makes them; refused for a chart with no rows.
    static func export(_ dashboard: SeriesDashboard, chart: String, query: FormQuery,
                       resources: ServerResources) async throws -> (ChartInspectorData, AnalyticsProvenance) {
        let ask = try ask(dashboard, query: query, resources: resources)
        let exported: (ChartInspectorData, AnalyticsProvenance)?
        switch dashboard {
        case .production:
            exported = SeriesProductionView(ask: ask, data: try await production(ask.scope, resources: resources), resources: resources).export(chart)
        case .geography:
            exported = SeriesGeographyView(ask: ask, data: try await geography(ask.scope, resources: resources), resources: resources).export(chart)
        case .sourcing:
            exported = SourceProvenanceView(ask: ask, data: try await provenance(ask.scope, resources: resources), resources: resources).export(chart)
        case .administrations:
            exported = AdministrationProfilesView(ask: ask, data: try await administrations(ask, resources: resources), resources: resources).export(chart)
        }
        guard let exported, !exported.0.rows.isEmpty else {
            throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "This chart holds nothing to export.")
        }
        return exported
    }
}

// MARK: - The pages and the scope bar

/// The four pages' titles and subtitles (`EducationPage.seriesProduction` and its siblings).
enum SeriesPages {
    static func page(_ dashboard: SeriesDashboard) -> (title: String, subtitle: String) {
        switch dashboard {
        case .production:
            (appWords("education.series.production.page.title", "Production & Timeliness"),
             appWords("education.series.production.page.subtitle", "How long the official record takes to reach print"))
        case .geography:
            (appWords("education.series.geography.page.title", "Geographic Emphasis"),
             appWords("education.series.geography.page.subtitle", "Which regions and countries the series covers most"))
        case .sourcing:
            (appWords("education.series.sourcing.page.title", "Archival Sourcing"),
             appWords("education.series.sourcing.page.subtitle", "Where the series drew its documents from, over time"))
        case .administrations:
            (appWords("education.series.administrations.page.title", "Administration Profiles"),
             appWords("education.series.administrations.page.subtitle", "How the series’ coverage is distributed across presidencies"))
        }
    }
}

/// `SeriesScopeBar`'s rules over the catalogue, under its names.
enum SeriesScopeBar {
    struct SubseriesBucket {
        let subseries: String
        let volumeIds: Set<String>
    }

    struct DecadeGroup {
        let decade: Int
        let buckets: [SubseriesBucket]
        var label: String { "\(decade)s" }
    }

    static func decadeGroups(_ entries: [VolumeManifestEntry]) -> [DecadeGroup] {
        var byName: [String: Set<String>] = [:]
        for entry in entries where !entry.subseries.isEmpty {
            byName[entry.subseries, default: []].insert(entry.volumeId)
        }
        var byDecade: [Int: [SubseriesBucket]] = [:]
        for (name, ids) in byName {
            let leadingYear = Int(name.prefix(4)) ?? 0
            let decade = (leadingYear / 10) * 10
            byDecade[decade, default: []].append(SubseriesBucket(subseries: name, volumeIds: ids))
        }
        return byDecade
            .map { DecadeGroup(decade: $0.key, buckets: $0.value.sorted { $0.subseries < $1.subseries }) }
            .sorted { $0.decade < $1.decade }
    }

    static func currentLabel(_ scope: SeriesScopeAsk) -> String {
        scope.label ?? appWords("series.scope.wholeSeries", "Whole series")
    }

    static func frame(_ ask: SeriesAsk) -> SeriesFrame {
        let end = ask.dashboard.defaultEnd
        return SeriesFrame(
            scopeLabel: String(format: appWords("series.scope.label %@", "Scope: %@"), currentLabel(ask.scope)),
            isNarrowed: ask.scope.volumeIds != nil,
            start: ask.start, end: ask.end, defaultEnd: end,
            isCustomRange: ask.start != SeriesChartKind.floorYear || ask.end != end)
    }

    static func scopeCaveat(_ scope: SeriesScopeAsk) -> String? {
        scope.label.map {
            String(format: appWords("series.caveats.scope %@", "Scoped to the %@ subseries — reset the scope above for the whole series."), $0)
        }
    }
}

/// A kit table as a chart carries it, or none for a chart the kit gives none.
private func seriesTable(_ data: ChartInspectorData?) -> CorpusAnalyticsAnswer.Table? {
    data.map(ArchivalTables.table)
}

// MARK: - Production & Timeliness

/// What `SeriesProductionDashboard` decides, under its names; held to the app's source by the mirror test.
struct SeriesProductionView {
    let ask: SeriesAsk
    let data: SeriesProductionData
    let resources: ServerResources

    /// The catalogue's entries, which the statement counts whatever the scope (`entries.count`).
    var entries: [VolumeManifestEntry] { resources.manifest }
    var domain: ClosedRange<Int> { effectiveDomain(userStart: ask.start, userEnd: ask.end, kind: .production) }

    static let lagTitle = appWords("series.chart.lag.title", "Publication lag over time")
    static let perYearTitle = appWords("series.chart.peryear.title", "Volumes published per year")
    static let cumulativeTitle = appWords("series.chart.cumulative.title", "Cumulative volumes published")

    func statement(_ title: String, _ axisLabel: String) -> AnalyticsProvenance {
        SeriesAnalyticsExport.production(
            figureTitle: title, axisLabel: axisLabel,
            scopeLabel: ask.scope.label, yearRange: ask.start...ask.end,
            volumeCount: entries.count)
    }

    func export(_ chart: String) -> (ChartInspectorData, AnalyticsProvenance)? {
        switch chart {
        case "lag":
            (ChartInspectorAdapters.lagTable(data.lagPoints(in: domain)),
             statement(Self.lagTitle, appWords("series.export.axis.lag", "By print year, lag in years")))
        case "perYear":
            (ChartInspectorAdapters.perYearTable(data.volumesPerPrintYearByEra(in: domain)),
             statement(Self.perYearTitle, appWords("series.export.axis.perYear", "By print year")))
        case "cumulative":
            (ChartInspectorAdapters.cumulativeTable(data.cumulativeByPrintYear(in: domain)),
             statement(Self.cumulativeTitle, appWords("series.export.axis.cumulative", "By print year, running total")))
        default: nil
        }
    }

    func answer() -> SeriesProductionAnswer {
        let domain = self.domain
        let eras = CoverageEra.ordered.map(\.label)
        let points = data.lagPoints(in: domain)
        let buckets = data.volumesPerPrintYearByEra(in: domain)
        let cumulative = data.cumulativeByPrintYear(in: domain)
        let lagX = appWords("series.chart.lag.x", "Publication year")
        let lagY = appWords("series.chart.lag.y", "Years to publication")
        let eraLegend = appWords("series.chart.era.legend", "Era")
        let charts = [
            SeriesChart(
                id: "lag", title: Self.lagTitle,
                caption: appWords("series.chart.lag.caption", "Each point is a volume. The horizontal axis is its publication year. The vertical axis is the lag: how many years earlier its latest document was written. The dashed step line is the timeliness target in force when the volume appeared. That target was 15 years from the 1961 directive, 20 years from 1972, and 30 years from 1985, codified by the 1991 statute."),
                xLabel: lagX, yLabel: lagY, legendTitle: eraLegend,
                table: seriesTable(ChartInspectorAdapters.lagTable(points)),
                marks: points.map { .init(x: String($0.printYear), y: Double($0.lagYears), series: $0.coverageEra.label) },
                steps: PublicationLagTarget.stepPoints(in: domain).map {
                    .init(x: String($0.year), y: Double($0.targetYears),
                          series: appWords("series.chart.lag.target.series", "Publication-timeliness target"))
                },
                domain: [domain.lowerBound, domain.upperBound], series: eras),
            SeriesChart(
                id: "perYear", title: Self.perYearTitle,
                caption: appWords("series.chart.peryear.caption", "How many volumes reached print in each year, colored by era. Output has never been steady — it reflects staffing, declassification throughput, and the shift to digital publication."),
                xLabel: appWords("series.chart.peryear.x", "Print year"), yLabel: appWords("series.chart.peryear.y", "Volumes"),
                legendTitle: eraLegend,
                table: seriesTable(ChartInspectorAdapters.perYearTable(buckets)),
                marks: buckets.map { .init(x: String($0.printYear), y: Double($0.count), series: $0.pubEra.label) },
                steps: nil, domain: [domain.lowerBound, domain.upperBound], series: eras),
            SeriesChart(
                id: "cumulative", title: Self.cumulativeTitle,
                caption: String(format: appWords("series.chart.cumulative.caption.v2 %lld",
                                                 "The digitized corpus has grown to the %lld volumes this app catalogs — steeply in some decades, slowly in others."),
                                Int64(data.total)),
                xLabel: appWords("series.chart.cumulative.x", "Print year"), yLabel: appWords("series.chart.cumulative.y", "Volumes to date"),
                legendTitle: nil,
                table: seriesTable(ChartInspectorAdapters.cumulativeTable(cumulative)),
                marks: cumulative.map { .init(x: String($0.printYear), y: Double($0.cumulativeCount), series: nil) },
                steps: nil, domain: [domain.lowerBound, domain.upperBound], series: []),
        ]
        var lines = [String]()
        if let caveat = SeriesScopeBar.scopeCaveat(ask.scope) { lines.append(caveat) }
        lines.append(String(format: appWords("series.caveats.body.v2 %lld",
                                             "These figures cover only published, digitized volumes. A volume’s publication year is the print year in its TEI header, and its coverage is the span of its document dates. Lag is print year minus coverage-end year. For the near-contemporaneous early volumes that lag can be close to zero. The timeliness target changed over time. There was no formal target before 1961. It was then 15 years under Kennedy’s 1961 directive, 20 under Nixon’s 1972 directive, and 30 under Reagan’s 1985 directive and as codified by the 1991 statute. The step line is drawn against each volume’s publication year, so it shows exactly the target in force when that volume was published. These charts cover the %lld volumes the app currently catalogs, so the newest volumes may not appear yet."),
                            Int64(data.total)))
        return SeriesProductionAnswer(
            frame: SeriesScopeBar.frame(ask),
            empty: entries.isEmpty
                ? .init(title: appWords("series.empty.title", "No manifest data"),
                        lines: [appWords("series.empty.message", "The bundled volume manifest is unavailable in this context.")])
                : nil,
            intro: appWords("series.production.intro", "How long does the official record lag events? These charts trace the timeliness of Foreign Relations of the United States across its whole span. They show the lag between the events a volume documents and its publication. That lag is measured against the publication-timeliness target in force at the time. They also show the pace of publication over time and the steady growth of the digitized series."),
            charts: charts,
            caveats: .init(title: appWords("series.caveats.title", "About these figures"), lines: lines))
    }
}

// MARK: - Geographic Emphasis

/// What `SeriesGeographyDashboard` decides, under its names; held to the app's source by the mirror test.
struct SeriesGeographyView {
    let ask: SeriesAsk
    let data: SeriesGeographyData
    let resources: ServerResources

    var entries: [VolumeManifestEntry] { resources.manifest }
    var domain: ClosedRange<Int> { effectiveDomain(userStart: ask.start, userEnd: ask.end, kind: .coverage) }

    func displayName(forSlug slug: String) -> String {
        resources.bundledAnalytics.tagName(slug, in: resources.directory)
    }

    static let trendTitle = appWords("series.geography.trend.title", "Regional emphasis over time")
    static let totalsTitle = appWords("series.geography.totals.title", "Overall regional emphasis")
    static let countriesTitle = appWords("series.geography.countries.title", "Most-covered countries")

    func statement(_ title: String, _ axisLabel: String, years: Bool) -> AnalyticsProvenance {
        SeriesAnalyticsExport.geography(
            figureTitle: title, axisLabel: axisLabel,
            scopeLabel: ask.scope.label, yearRange: years ? ask.start...ask.end : nil,
            volumeCount: entries.count)
    }

    func export(_ chart: String) -> (ChartInspectorData, AnalyticsProvenance)? {
        switch chart {
        case "trend":
            (ChartInspectorAdapters.regionTrendTable(data.regionShareByDecade(in: domain)),
             statement(Self.trendTitle, appWords("series.export.axis.regionTrend", "By coverage decade, share of volumes"), years: true))
        case "totals":
            (ChartInspectorAdapters.regionTotalsTable(data.regionTotals),
             statement(Self.totalsTitle, appWords("series.export.axis.regionTotals", "By region, across the whole span"), years: false))
        case "countries":
            (ChartInspectorAdapters.topCountriesTable(data.topCountries, displayName: { displayName(forSlug: $0) }),
             statement(Self.countriesTitle, appWords("series.export.axis.topCountries", "By country, volumes tagged"), years: false))
        default: nil
        }
    }

    func answer() -> SeriesGeographyAnswer {
        let domain = self.domain
        let regions = GeographicRegion.ordered.map(\.displayName)
        let regionLegend = appWords("series.geography.region.legend", "Region")
        let shares = data.regionShareByDecade(in: domain)
        let empty = entries.isEmpty || resources.bundledAnalytics.placeRegions(in: resources.directory).isEmpty
        let charts = [
            SeriesChart(
                id: "trend", title: Self.trendTitle,
                caption: appWords("series.geography.trend.caption", "Each decade’s volumes divided among the regions they cover. A volume spanning several regions splits evenly between them, so every decade totals 100%. A volume’s decade is set by the midpoint of its coverage."),
                xLabel: appWords("series.geography.trend.x", "Coverage decade"), yLabel: appWords("series.geography.trend.y", "Share of volumes"),
                legendTitle: regionLegend,
                table: seriesTable(ChartInspectorAdapters.regionTrendTable(shares)),
                marks: shares.map { .init(x: String($0.decade), y: $0.share, series: $0.region.displayName) },
                steps: nil, domain: [domain.lowerBound, domain.upperBound], series: regions),
            SeriesChart(
                id: "totals", title: Self.totalsTitle,
                caption: appWords("series.geography.totals.caption", "How many volumes touch each region across the whole series. A volume that covers several regions counts once in each, so these totals overlap."),
                xLabel: appWords("series.geography.totals.x", "Region"), yLabel: appWords("series.geography.totals.y", "Volumes"),
                legendTitle: regionLegend,
                table: seriesTable(ChartInspectorAdapters.regionTotalsTable(data.regionTotals)),
                marks: data.regionTotals.map { .init(x: $0.region.displayName, y: Double($0.volumeCount), series: $0.region.displayName) },
                steps: nil, domain: nil, series: regions),
            SeriesChart(
                id: "countries", title: Self.countriesTitle,
                caption: appWords("series.geography.countries.caption", "The individual place tags carried by the most volumes — the concrete detail behind the regional picture."),
                xLabel: appWords("series.geography.countries.x", "Volumes"), yLabel: appWords("series.geography.countries.y", "Country"),
                legendTitle: nil,
                table: seriesTable(ChartInspectorAdapters.topCountriesTable(data.topCountries, displayName: { displayName(forSlug: $0) })),
                marks: data.topCountries.map { .init(x: displayName(forSlug: $0.slug), y: Double($0.volumeCount), series: nil) },
                steps: nil, domain: nil, series: []),
        ]
        var lines = [String]()
        if let caveat = SeriesScopeBar.scopeCaveat(ask.scope) { lines.append(caveat) }
        lines.append(String(format: appWords("series.geography.caveats.body.v2 %lld %lld",
                                             "Place tags are editorial tags on the volume, not on the document. A volume touches a region if it carries a place tag that maps to that region. These are volume counts, not document counts, and a volume commonly spans several regions. The stacked chart splits each volume across its regions. A volume covering three regions contributes a third to each, so every decade totals 100%. The overall bars work differently: they count a multi-region volume once in every region it touches. Regions roughly follow the State Department’s six current regional bureaus, with dependencies and territories folded into “Other.” %1$lld of the %2$lld cataloged volumes carry a place tag that maps to a region. These figures cover the volumes the app currently catalogs, so the newest volumes may not appear yet."),
                            Int64(data.volumesWithAnyRegion), Int64(data.totalVolumes)))
        return SeriesGeographyAnswer(
            frame: SeriesScopeBar.frame(ask),
            empty: empty
                ? .init(title: appWords("series.geography.empty.title", "No geographic data"),
                        lines: [appWords("series.geography.empty.message", "The bundled volume manifest or place-tag taxonomy is unavailable in this context.")])
                : nil,
            intro: appWords("series.geography.intro", "Where in the world does Foreign Relations of the United States look? Every volume carries editorial place tags, which map roughly to the State Department’s six regional bureaus. These charts show how the series’ geographic emphasis shifted over time. Early volumes concentrate on Europe and the Western Hemisphere. Postwar volumes widen into Asia, the Near East, and Africa. The charts also show which regions and countries the series covers most."),
            charts: charts,
            caveats: .init(title: appWords("series.geography.caveats.title", "About these figures"), lines: lines))
    }
}

// MARK: - Archival Sourcing

/// What `SourceProvenanceDashboard` decides, under its names; held to the app's source by the mirror test.
struct SourceProvenanceView {
    let ask: SeriesAsk
    let data: SourceProvenanceData
    let resources: ServerResources

    var entries: [VolumeManifestEntry] { resources.manifest }
    var hiddenCategories: Set<SourceProvenanceCategory> { ask.hiddenCategories }
    var domain: ClosedRange<Int> { effectiveDomain(userStart: ask.start, userEnd: ask.end, kind: .coverage) }

    static let mixTitle = appWords("series.provenance.trend.title", "Archival provenance over time")
    static let compositionTitle = appWords("series.provenance.composition.title", "Overall provenance composition")
    static let densityTitle = appWords("series.provenance.density.title", "The documentary base by decade")

    func provenanceStatement(figureTitle: String, axisLabel: String,
                             yearRange: ClosedRange<Int>?) -> AnalyticsProvenance {
        SeriesAnalyticsExport.provenance(
            figureTitle: figureTitle,
            axisLabel: axisLabel,
            scopeLabel: ask.scope.label,
            yearRange: yearRange,
            volumeCount: data.volumesCovered,
            noteCount: data.totalSourceNotes,
            hiddenCategories: hiddenCategories.map(\.displayName),
            generated: data.generated)
    }

    func export(_ chart: String) -> (ChartInspectorData, AnalyticsProvenance)? {
        let domain = self.domain
        switch chart {
        case "mix":
            return (ChartInspectorAdapters.provenanceMixTable(data.shareByDecade(in: domain, excluding: hiddenCategories)),
                    provenanceStatement(figureTitle: Self.mixTitle,
                                        axisLabel: appWords("series.export.axis.provenanceMix", "By coverage decade, share of source notes"),
                                        yearRange: domain.lowerBound...domain.upperBound))
        case "composition":
            return (ChartInspectorAdapters.compositionTable(data.overallComposition(excluding: hiddenCategories)),
                    provenanceStatement(figureTitle: Self.compositionTitle,
                                        axisLabel: appWords("series.export.axis.composition", "By provenance, across the whole span"),
                                        yearRange: nil))
        case "density":
            return (ChartInspectorAdapters.densityTable(data.notesByDecade(in: domain)),
                    provenanceStatement(figureTitle: Self.densityTitle,
                                        axisLabel: appWords("series.export.axis.density", "By coverage decade, source notes"),
                                        yearRange: domain.lowerBound...domain.upperBound))
        default:
            return nil
        }
    }

    /// `isLastShownCategory(_:)`: the one category still shown cannot be hidden.
    func isLastShownCategory(_ category: SourceProvenanceCategory) -> Bool {
        !hiddenCategories.contains(category)
            && hiddenCategories.count == SourceProvenanceCategory.ordered.count - 1
    }

    var filter: SeriesSourcingAnswer.CategoryFilter {
        let shown = Int64(SourceProvenanceCategory.ordered.count - hiddenCategories.count)
        return .init(
            label: hiddenCategories.isEmpty
                ? appWords("series.provenance.filter.label", "Categories: all")
                : String(format: appWords("series.provenance.filter.label.count %lld", "Categories: %lld shown"), shown),
            accessibilityLabel: appWords("series.provenance.filter.a11y", "Provenance categories shown"),
            accessibilityValue: hiddenCategories.isEmpty
                ? appWords("series.provenance.filter.a11y.all", "All shown")
                : String(format: appWords("series.provenance.filter.a11y.count %lld %lld", "%1$lld of %2$lld shown"),
                         shown, Int64(SourceProvenanceCategory.ordered.count)),
            categories: SourceProvenanceCategory.ordered.map {
                .init(value: $0.rawValue, name: $0.displayName, shown: !hiddenCategories.contains($0), enabled: !isLastShownCategory($0))
            },
            showAll: hiddenCategories.isEmpty ? nil : appWords("series.provenance.filter.showAll", "Show all categories"))
    }

    func answer(topCollections: TopCollectionsView) -> SeriesSourcingAnswer {
        let domain = self.domain
        let categories = SourceProvenanceCategory.ordered.map(\.displayName)
        let legend = appWords("series.provenance.category.legend", "Provenance")
        let shares = data.shareByDecade(in: domain, excluding: hiddenCategories)
        let composition = data.overallComposition(excluding: hiddenCategories)
        let density = data.notesByDecade(in: domain)
        let charts = [
            SeriesChart(
                id: "mix", title: Self.mixTitle,
                caption: appWords("series.provenance.trend.caption", "Each decade’s source notes divided among the archival collections they cite, so every decade totals 100%. A volume’s decade is set by the midpoint of its coverage. The trend begins in 1900 because earlier volumes carry no archival source notes."),
                xLabel: appWords("series.provenance.trend.x", "Coverage decade"), yLabel: appWords("series.provenance.trend.y", "Share of source notes"),
                legendTitle: legend,
                table: seriesTable(ChartInspectorAdapters.provenanceMixTable(shares)),
                marks: shares.map { .init(x: String($0.decade), y: $0.share, series: $0.category.displayName) },
                steps: nil, domain: [domain.lowerBound, domain.upperBound], series: categories),
            SeriesChart(
                id: "composition", title: Self.compositionTitle,
                caption: appWords("series.provenance.composition.caption", "How many source notes across the whole series, from 1900 on, cite each kind of archival collection. The Central Decimal File dwarfs the rest. Most published FRUS documents came from the State Department’s various central filing systems, but recent volumes draw from presidential records and other kinds of federal record collections."),
                xLabel: appWords("series.provenance.composition.x", "Provenance"), yLabel: appWords("series.provenance.composition.y", "Source notes"),
                legendTitle: nil,
                table: seriesTable(ChartInspectorAdapters.compositionTable(composition)),
                marks: composition.map { .init(x: $0.category.displayName, y: Double($0.noteCount), series: $0.category.displayName) },
                steps: nil, domain: nil, series: categories),
            SeriesChart(
                id: "density", title: Self.densityTitle,
                caption: appWords("series.provenance.density.caption", "How many source notes each decade contributes. These are the counts behind the shares above. The 1940s carry the deepest base. Volumes covering the 1970s, 1980s, and 1990s are still in production, so those decades will grow as new volumes are released."),
                xLabel: appWords("series.provenance.density.x", "Coverage decade"), yLabel: appWords("series.provenance.density.y", "Source notes"),
                legendTitle: nil,
                table: seriesTable(ChartInspectorAdapters.densityTable(density)),
                marks: density.map { .init(x: String($0.decade), y: Double($0.totalNotes), series: nil) },
                steps: nil, domain: [domain.lowerBound, domain.upperBound], series: []),
        ]
        var lines = [String]()
        if !hiddenCategories.isEmpty {
            lines.append(appWords("series.provenance.caveats.filtered.v2", "Some categories are hidden. Each share below is a share of the categories still shown, not of all source notes. A decade with no notes in any shown category reads as zero rather than being skipped. Use the Categories menu above to show them all."))
        }
        lines.append(String(format: appWords("series.provenance.caveats.body.v3 %lld %lld",
                                             "These figures come from parsing each document’s source note, the citation naming where its archival original was found. They are not drawn from a catalog of the archives. “Other / Unclassified” means a citation the parser could not classify, not a missing source note. Coverage spans %1$lld of the %2$lld cataloged volumes. Pre-1900 volumes are largely published diplomatic correspondence with no archival source notes, so the trend begins around 1900. The categories follow State Department filing practice. Between 1906 and 1910, the Department used a case-based Numerical File. After 1910, it adopted a classification-based Central Decimal File that persisted (with incremental revisions) until January 1963. The Subject-Numeric File replaced the decimal file in February 1963 and ran through 1973, and the Central Foreign Policy File followed from July 1973. A citation to the central files is placed by what it gives: a decimal file number, a Subject-Numeric file designation or its block of years, or the Central Foreign Policy File’s name or a film number. Lot files were kept by individual bureaus, offices, and posts. Presidential libraries hold the White House records that dominate modern volumes. Remember that these counts show where FRUS editors found the documents they selected for publication. That is an editorial and archival signal, not a full census of the underlying archives."),
                            Int64(data.volumesCovered), Int64(entries.count)))
        return SeriesSourcingAnswer(
            frame: SeriesScopeBar.frame(ask),
            empty: data.shareByDecade.isEmpty
                ? .init(title: appWords("series.provenance.empty.title", "No provenance data"),
                        lines: [appWords("series.provenance.empty.message", "The bundled source-provenance index is unavailable in this context.")])
                : nil,
            supportsScope: data.supportsVolumeScope,
            intro: appWords("series.provenance.intro", "Where did the editors of Foreign Relations of the United States find the documents they published? Since the early 20th century, nearly every document carries a source note naming the archival file it came from. These charts read those notes across the whole series to trace how its archival provenance changed. The State Department’s central files predominated until bureau lot files and presidential libraries appeared after World War II. Modern volumes draw on a much wider range of sources."),
            filter: filter,
            charts: charts,
            topCollections: topCollections.answer(),
            archivalLink: appWords("series.provenance.archivalLink", "Open Archival Analytics"),
            archivalLinkDetail: appWords("series.provenance.archivalLink.detail.v2", "This dashboard groups source notes into eleven broad categories. Archival Analytics names the individual collections inside them, ranks them era by era, and shows which ones the same volumes drew on together."),
            caveats: .init(title: appWords("series.provenance.caveats.title", "About these figures"), lines: lines))
    }
}

/// What `TopCollectionsCard` decides, under its names; held to the app's source by the mirror test.
struct TopCollectionsView {
    let ask: SeriesAsk
    let data: ArchivalCollectionsData
    let resources: ServerResources

    static let rowLimit = ArchivalCollectionsData.rowCap

    var entries: [VolumeManifestEntry] { resources.manifest }
    var bands: [ArchivalEraBand] { ArchivalEraBand.bands(overlapping: ask.start, through: ask.end) }

    var weight: ArchivalWeight {
        data.supportsDocumentWeight ? .documents : .volumes
    }

    var ranking: ArchivalRanking {
        data.ranking(bands: bands, lens: .namedCollections, weight: weight,
                     hidingUmbrella: true, limit: Self.rowLimit)
    }

    func bar(_ row: ArchivalRankingRow, maximum: Int) -> Double {
        min(1, max(0, Double(row.value) / Double(maximum)))
    }

    func coverageSentence(_ ranking: ArchivalRanking) -> String {
        let eras = bands.count == ArchivalEraBand.all.count
            ? appWords("series.provenance.topCollections.eras.all", "the whole series")
            : bands.map(\.title).joined(separator: ", ")
        if let share = ranking.shownShare(weight: weight) {
            let percent = share < 0.01
                ? appWords("series.provenance.topCollections.share.tiny", "under 1%")
                : share.formatted(.percent.precision(.fractionLength(0)).locale(SearchItem.locale))
            return String(format: appWords("series.provenance.topCollections.coverage %lld %lld %@ %@",
                                           "Showing %1$lld of %2$lld collections reached across %3$@. Together they account for %4$@ of the source notes those volumes carry."),
                          Int64(ranking.rows.count), Int64(ranking.unitsReached), eras, percent)
        }
        return String(format: appWords("series.provenance.topCollections.coverage.noShare %lld %lld %@",
                                       "Showing %1$lld of %2$lld collections reached across %3$@."),
                      Int64(ranking.rows.count), Int64(ranking.unitsReached), eras)
    }

    func answer() -> SeriesSourcingAnswer.TopCollections {
        var card = SeriesSourcingAnswer.TopCollections(
            title: appWords("series.provenance.topCollections.title", "Which collections carried this scope"),
            caption: appWords("series.provenance.topCollections.caption", "The charts above group source notes into broad kinds of record. These are the individual bodies of records inside them, ranked by how many documents each supplied."),
            notice: nil, rows: [], legend: [], footnotes: [], method: nil)
        guard !bands.isEmpty else {
            card.notice = appWords("series.provenance.topCollections.noBands", "The years selected above fall outside the eras this ranking covers, which run from 1861 to 1992. Widen the range to see the collections.")
            return card
        }
        let ranking = self.ranking
        guard !ranking.rows.isEmpty else {
            card.notice = appWords("series.provenance.topCollections.empty", "No named collection is recorded for the volumes in this scope. That is an answer about the scope, not a gap in the app — before 1948 the volumes cite filing-system classes far more often than named collections.")
            return card
        }
        let maximum = max(ranking.rows.first?.value ?? 1, 1)
        card.rows = ranking.rows.map {
            .init(id: $0.id, label: $0.label, value: $0.value, category: $0.category.rawValue, categoryName: $0.category.displayName,
                  bar: bar($0, maximum: maximum), opens: data.record(forId: $0.id) != nil)
        }
        card.legend = ArchivalRepositoryCategory.ordered.map { .init(category: $0.rawValue, name: $0.displayName) }
        var footnotes = [coverageSentence(ranking)]
        if let withheld = ranking.hiddenUmbrellaValue {
            footnotes.append(String(format: appWords("series.provenance.topCollections.umbrella.v2 %lld %lld",
                                                     "The State Department’s central files are withheld from this ranking — one undifferentiated in the NARA Catalog, carrying %1$lld here against %2$lld for the largest collection shown. Archival Analytics can show it."),
                                    Int64(withheld), Int64(ranking.rows.first?.value ?? 0)))
        }
        if !data.supportsDocumentWeight {
            footnotes.append(appWords("series.provenance.topCollections.volumesFallback", "Counted in volumes, not documents: the document-level index is unavailable in this build, so these bars say how many volumes drew on each collection."))
        }
        card.footnotes = footnotes
        card.method = String(format: appWords("series.provenance.topCollections.method.v4 %lld %lld",
                                              "Colors group collections by who holds the records — four custodians, not the eleven categories above, which classify the citation rather than its holder. Eras here are coarser than the decades above, so a year range ending mid-era still covers the whole era. Document counts come from an index covering all %1$lld cataloged volumes with no 1900 floor, so a row here can rest on volumes the charts above leave out; the collection names come from a cross-volume authority that reaches %2$lld of them. The Categories filter above does not apply to this ranking."),
                             Int64(data.volumesScanned ?? entries.count),
                             Int64(data.authorityVolumeReach))
        return card
    }
}

// MARK: - Administration Profiles

/// What `AdministrationProfilesDashboard` decides, under its names; held to the app's source by the mirror test.
struct AdministrationProfilesView {
    let ask: SeriesAsk
    let data: AdministrationProfilesData
    let resources: ServerResources

    static let defaultEnd = SeriesChartKind.productionCeilingYear

    var yearStart: Int { ask.start }
    var yearEnd: Int { ask.end }
    var includeEditorialNotes: Bool { ask.includeEditorialNotes }

    var visibleProfiles: [AdministrationProfilesData.Profile] {
        data.profiles.filter { profile in
            guard let termStart = Int(profile.start.prefix(4)) else { return true }
            let termEnd = profile.end.flatMap { Int($0.prefix(4)) } ?? Self.defaultEnd
            return termStart <= yearEnd && termEnd >= yearStart
        }
    }

    /// The administration the detail shows: the one picked, if still in view, else the most documented in view. The
    /// page opens on the most documented overall (`onAppear`), which the browser passes as its first pick.
    var focusProfile: AdministrationProfilesData.Profile? {
        let visible = visibleProfiles
        if let id = ask.administration,
           let match = visible.first(where: { $0.id == id }) {
            return match
        }
        return visible.max { $0.documentCount < $1.documentCount }
    }

    var indexHasData: Bool {
        !(resources.administrationProfiles?.administrations.isEmpty ?? true)
    }

    static func year(from iso: String) -> String {
        iso.count >= 4 ? String(iso.prefix(4)) : iso
    }

    static func lastName(_ fullName: String) -> String {
        fullName.split(separator: " ").last.map(String.init) ?? fullName
    }

    static func axisLabels(for profiles: [AdministrationProfilesData.Profile]) -> [String: String] {
        var counts: [String: Int] = [:]
        for profile in profiles {
            counts[lastName(profile.president), default: 0] += 1
        }
        var labels: [String: String] = [:]
        for profile in profiles {
            let name = lastName(profile.president)
            if counts[name, default: 0] > 1 {
                labels[profile.id] = "\(name) \(year(from: profile.start))"
            } else {
                labels[profile.id] = name
            }
        }
        return labels
    }

    func termText(_ profile: AdministrationProfilesData.Profile) -> String {
        let startYear = Self.year(from: profile.start)
        if let end = profile.end {
            let endYear = Self.year(from: end)
            return "\(startYear)\u{2013}\(endYear)"
        }
        return "\(String(startYear))–present"
    }

    func documentsText(_ profile: AdministrationProfilesData.Profile) -> String {
        if includeEditorialNotes {
            return "\(grouped(profile.documentCount)) (\(grouped(profile.pointDocCount)) dated + \(grouped(profile.rangeDocCount)) editorial notes)"
        }
        return grouped(profile.pointDocCount)
    }

    func pickerLabel(for profile: AdministrationProfilesData.Profile) -> String {
        let sharesName = data.profiles.filter { $0.president == profile.president }.count > 1
        guard sharesName else { return profile.president }
        return "\(profile.president) (\(termText(profile)))"
    }

    func volumeTitle(for volumeId: String) -> String {
        resources.volume(volumeId)?.title ?? volumeId
    }

    static let documentsTitle = appWords("series.admin.docs.title", "Documents per administration")
    static let perYearTitle = appWords("series.admin.perYear.title", "Volumes per administration-year")

    func statement(_ title: String, _ axisLabel: String) -> AnalyticsProvenance {
        SeriesAnalyticsExport.administration(
            figureTitle: title, axisLabel: axisLabel,
            scopeLabel: ask.scope.label, yearRange: yearStart...yearEnd,
            volumeCount: data.volumesCovered,
            includesEditorialNotes: includeEditorialNotes)
    }

    func export(_ chart: String) -> (ChartInspectorData, AnalyticsProvenance)? {
        switch chart {
        case "documents":
            (ChartInspectorAdapters.administrationDocumentsTable(visibleProfiles),
             statement(Self.documentsTitle, appWords("series.export.axis.adminDocuments", "By administration, documents")))
        case "perYear":
            (ChartInspectorAdapters.administrationVolumesPerYearTable(visibleProfiles.filter { $0.termYears > 0 }),
             statement(Self.perYearTitle, appWords("series.export.axis.adminPerYear", "By administration, volumes per term-year")))
        default: nil
        }
    }

    func detail() -> SeriesAdministrationsAnswer.Detail? {
        guard let profile = focusProfile else { return nil }
        var stats: [SeriesAdministrationsAnswer.Stat] = [
            .init(label: appWords("series.admin.stat.term", "Term"), value: termText(profile)),
            .init(label: appWords("series.admin.stat.documents", "Documents"), value: documentsText(profile)),
            .init(label: appWords("series.admin.stat.volumes", "Volumes"), value: grouped(profile.volumeCount)),
        ]
        if profile.termYears > 0 {
            stats.append(.init(label: appWords("series.admin.stat.density", "Volumes per term-year"),
                               value: profile.volumesPerAdministrationYear.formatted(.number.precision(.fractionLength(1)).locale(SearchItem.locale))))
        }
        if let earliest = profile.coverageEarliest, let latest = profile.coverageLatest {
            stats.append(.init(label: appWords("series.admin.stat.coverage", "Coverage span"),
                               value: "\(String(earliest))\u{2013}\(String(latest))"))
        }
        let rows = data.volumeShares(for: profile.id)
        return .init(
            title: appWords("series.admin.detail.title", "Administration detail"),
            pickerLabel: appWords("series.admin.detail.picker", "Administration"),
            choices: visibleProfiles.map { .init(id: $0.id, label: pickerLabel(for: $0)) },
            focus: profile.id, president: profile.president,
            party: profile.party.rawValue, partyName: profile.party.displayName,
            stats: stats,
            volumesHeader: "Volumes covering this administration (\(grouped(rows.count)))",
            volumesCaption: appWords("series.admin.volumes.caption", "Each volume’s share is the fraction of that volume’s documents that fall in this administration — so shares can sum past 100% across administrations under any-overlap attribution."),
            volumesEmpty: rows.isEmpty ? appWords("series.admin.volumes.empty", "No volumes attributed.") : nil,
            volumes: rows.map {
                .init(id: $0.id, title: volumeTitle(for: $0.id), documents: "\(grouped($0.documentCount)) documents",
                      proportion: $0.proportion.formatted(.percent.precision(.fractionLength(0)).locale(SearchItem.locale)))
            })
    }

    func answer() -> SeriesAdministrationsAnswer {
        let visible = visibleProfiles
        let labels = Self.axisLabels(for: visible)
        let parties = PoliticalParty.ordered.map(\.displayName)
        let partyLegend = appWords("series.admin.party.legend", "Party")
        let perYear = visible.filter { $0.termYears > 0 }
        let perYearLabels = Self.axisLabels(for: perYear)
        let charts = [
            SeriesChart(
                id: "documents", title: Self.documentsTitle,
                caption: appWords("series.admin.docs.caption", "How many published documents concern each administration’s foreign policy, in chronological order. Any date overlap counts, so a volume spanning two terms counts in both.\n\nVolumes covering the 1970s, 1980s, and 1990s are still in production. Coverage of the Carter, Reagan, H.W. Bush, and Clinton administrations will expand as new volumes are released."),
                xLabel: appWords("series.admin.docs.x", "Administration"), yLabel: appWords("series.admin.docs.y", "Documents"),
                legendTitle: partyLegend,
                table: seriesTable(ChartInspectorAdapters.administrationDocumentsTable(visible)),
                marks: visible.map { .init(x: labels[$0.id] ?? $0.id, y: Double($0.documentCount), series: $0.party.displayName) },
                steps: nil, domain: nil, series: parties),
            SeriesChart(
                id: "perYear", title: Self.perYearTitle,
                caption: appWords("series.admin.perYear.caption", "How many volumes cover each administration, divided by the length of its term in years. This measures how densely the series covers each presidency.\n\nVolumes covering the 1970s, 1980s, and 1990s are still in production. Coverage of the Carter, Reagan, H.W. Bush, and Clinton administrations will expand as new volumes are released."),
                xLabel: appWords("series.admin.perYear.x", "Administration"), yLabel: appWords("series.admin.perYear.y", "Volumes per year"),
                legendTitle: partyLegend,
                table: seriesTable(ChartInspectorAdapters.administrationVolumesPerYearTable(perYear)),
                marks: perYear.map { .init(x: perYearLabels[$0.id] ?? $0.id, y: $0.volumesPerAdministrationYear, series: $0.party.displayName) },
                steps: nil, domain: nil, series: parties),
        ]
        var lines = [String]()
        if let label = ask.scope.label {
            lines.append(String(format: appWords("series.admin.caveats.scope %@",
                                                 "Scoped to the %@ subseries. Counts and proportions come from that subseries’ volumes alone. The coverage span for each administration is hidden here, because the source data pre-aggregates it for the whole series. Reset the scope above to see the whole series."),
                                label))
        }
        lines.append(String(format: appWords("series.admin.caveats.body.v2 %lld",
                                             "A document counts toward an administration if its dates overlap that president’s term at all. A volume spanning two administrations therefore counts in both. That is why the volume counts add up to more than the series’ %lld volumes. It is also why one volume’s proportions can total over 100% across administrations. Editorial notes carry a range of dates rather than a single date. The toggle above decides whether they are counted, and it is off by default. Each president is counted separately: Nixon and Ford are distinct, as are Grover Cleveland’s two non-consecutive terms. Administrations the series has not yet published do not appear."),
                            Int64(data.volumesCovered)))
        return SeriesAdministrationsAnswer(
            frame: SeriesScopeBar.frame(ask),
            empty: indexHasData ? nil
                : .init(title: appWords("series.admin.empty.title", "No administration data"),
                        lines: [appWords("series.admin.empty.message", "The bundled administration-profiles index is unavailable in this context.")]),
            narrowedEmpty: indexHasData && visible.isEmpty
                ? .init(title: appWords("series.admin.narrowedEmpty.title", "No administrations in view"),
                        lines: [appWords("series.admin.narrowedEmpty.message", "No administration matches your current scope and year range. The subseries you selected may carry no attributed documents, or your years may fall outside every presidential term. Reset the scope or year range above to see the whole series.")])
                : nil,
            intro: appWords("series.admin.intro", "Whose foreign policy does Foreign Relations of the United States document? Every dated document is assigned to the presidential administration in office when the events it records took place. These charts show how many documents each administration draws, and how densely the series covers each term. Select any administration to see which volumes carry its record."),
            toggle: .init(title: appWords("series.admin.toggle.title", "Include editorial notes (date ranges)"),
                          subtitle: appWords("series.admin.toggle.subtitle", "Editorial-note documents carry a span of dates rather than a single date; including them adds them to every count and proportion."),
                          isOn: includeEditorialNotes),
            charts: visible.isEmpty ? [] : charts,
            detail: visible.isEmpty ? nil : detail(),
            caveats: .init(title: appWords("series.admin.caveats.title", "About these figures"), lines: lines))
    }
}
