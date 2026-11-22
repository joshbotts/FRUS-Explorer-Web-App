// Archival Analytics (PLAN's S24h): where the FRUS editors found what they published, as the app's
// `ArchivalAnalyticsView` shows it in four modes. Collections ranks the archival units each era's volumes drew on,
// corpus-wide, from the bundled authority and usage index, and works with nothing indexed; Network draws the
// co-citation neighbourhood of one collection in custodian sectors; Flows maps where the editors sent the reader when
// they cross-referenced one document from another, or pointed at material they did not print; Your Library counts the
// same things in the volumes the served index holds. Every derivation is the kit's (FRUS-Explorer#1901):
// `ArchivalCollectionsData`, `ArchivalNetworkBuilder` with its layout and `GraphNodeLabels`, `ArchivalFlowsData`,
// `ArchivalLibraryProfile` over the pipeline's two grouped queries, `ArchivalCounts`' sentences and
// `ArchivalAnalyticsExport`'s statements, rendered by `AnalyticsProvenance` for the server's host, all compiled from the
// submodule. What the views decide between those calls and the screen is app code, mirrored here under the views' own
// names and held to the app's source by `ArchivalAndSeriesMirrorParityTests`: the defaults, the weights a lens offers,
// the denominator's sentence and pointer, the families, the caveats, the network's threshold, first focus, picker,
// dock and cards, the flows' picker, titles, captions and caveats, Your Library's cards, the tables and the words.
// Each series is computed once for its scope, or its focus, and kept (`BundledAnalytics`); Your Library once for the
// served index (`ServedIndex.archivalLibrary`).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

// MARK: - The context

/// What Archival Analytics opens on: its modes, the controls' choices in the kit's words, and the scope menu over the
/// series (`ArchivalAnalyticsView.scopableVolumeIds`, the catalogue's volumes, since the derivation is the bundled
/// authority's and is honest with nothing indexed), with the administration menu's volume sets.
public struct ArchivalContext: Codable, Equatable, Sendable, ResponseEncodable {
    public var modes: [Option]
    public var bands: [Option]
    /// The band the Collections ranking opens on, 1948–1960 (`ArchivalEraBand.all[1]`).
    public var defaultBand: String
    public var lenses: [Option]
    public var weights: [Option]
    public var measures: [Option]
    public var expansions: [Option]
    /// The two layers, or none without the external-citation index, where the app hides the control.
    public var layers: [Option]
    public var directions: [Option]
    /// The network's threshold slider: from 5% to 60% in steps of 5%, opening at 25%.
    public var thresholds: [Double]
    public var defaultThreshold: Double
    /// By Subseries and By Volume over the series, each subseries with its volumes and their titles.
    public var subseries: [AnalyticsContext.Subseries]
    /// By Subject over the series: the categories that narrow, each with its sub-categories and their counts.
    public var topics: [AnalyticsContext.TopicCategory]
    /// The administration menu: each presidency of the bundled profiles, by its id and its president.
    public var administrations: [Administration]
    /// The series' volumes, which a reader's own volume scope is resolved against.
    public var seriesVolumeIds: [String]
    public var indexedVolumeCount: Int
    /// The toolbar's link to About the Series' Archival Sourcing page, and the words of the modes' last line.
    public var researchGuide: String
    public var methodPointer: String
    /// A mode the bundle cannot draw, with the app's words: the network without the authority, the flows without
    /// their index.
    public var networkUnavailable: String?
    public var flowsUnavailable: String?

    public struct Option: Codable, Equatable, Sendable {
        public var value: String
        public var title: String
    }

    public struct Administration: Codable, Equatable, Sendable {
        public var id: String
        public var president: String
    }
}

// MARK: - Collections

/// The Collections mode for an era, a lens, a weight, the umbrella and a scope (`collectionsMode`).
public struct ArchivalCollectionsAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var scope: ScopeChip
    public var band: String
    public var lens: String
    /// The weight in force, which falls back to volumes where the stored one cannot be drawn (`weight`).
    public var weight: String
    /// Each weight and whether the lens and the bundle can draw it (`supports(_:)`), as the menu disables it.
    public var weights: [WeightChoice]
    public var hidesUmbrella: Bool
    /// The umbrella chip's words, on the named-collections lens alone.
    public var umbrella: Umbrella?
    /// What the drawn rows account for, against the band's source notes (`denominatorLine`).
    public var denominator: Denominator?
    public var ranking: Ranking
    /// "Select a bar to …" (`drillInHint`), once there are rows.
    public var drillInHint: String?
    /// The way out of the row cap (`showAllUnitsButton`), when the cap withholds rows.
    public var showAllUnits: String?
    /// "Inside these families" (`classFamilies`), on the class lens when a row is a family.
    public var families: Families?
    /// The conditional disclosures (`collectionsConditionalCaveats`).
    public var caveats: [String]
    public var timingPointer: String

    public struct ScopeChip: Codable, Equatable, Sendable {
        /// The chip's value, Whole corpus or the scope's label.
        public var label: String
        public var isNarrowed: Bool
    }

    public struct WeightChoice: Codable, Equatable, Sendable {
        public var value: String
        public var title: String
        public var enabled: Bool
    }

    public struct Umbrella: Codable, Equatable, Sendable {
        public var caption: String
        public var value: String
        public var accessibilityLabel: String
        /// The value's two words, which the chip shows for the state asked while its answer comes.
        public var hidden: String
        public var shown: String
    }

    public struct Denominator: Codable, Equatable, Sendable {
        public var sentence: String
        public var pointer: String?
    }

    public struct Ranking: Codable, Equatable, Sendable {
        public var title: String
        public var caption: String
        /// The empty state's sentence, when no row is drawn.
        public var empty: String?
        public var axisLabel: String
        public var rows: [Row]
        public var table: CorpusAnalyticsAnswer.Table?
    }

    public struct Row: Codable, Equatable, Sendable {
        public var id: String
        public var label: String
        public var category: String
        public var categoryName: String
        public var value: Int
        public var gloss: String?
        public var glossAlternates: [String]
        /// The bar's name and value for a screen reader, as the chart's marks say them.
        public var accessibilityLabel: String
        public var accessibilityValue: String
        /// Whether the row opens a collection's record (named collections) or its class's documents.
        public var opens: Bool
    }

    public struct Families: Codable, Equatable, Sendable {
        public var title: String
        public var caption: String
        public var items: [Family]
    }

    public struct Family: Codable, Equatable, Sendable {
        public var name: String
        public var count: String
        public var leaves: [Leaf]
    }

    public struct Leaf: Codable, Equatable, Sendable {
        public var key: String
        public var gloss: String?
        public var tag: String
        public var value: Int
    }
}

/// The uncapped "Every Unit" list (`ArchivalAllUnitsSheet`), captured for the chart it is opened from.
public struct ArchivalUnitsAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var title: String
    public var header: String
    public var footer: String
    public var rows: [Row]

    public struct Row: Codable, Equatable, Sendable {
        public var rank: String
        public var id: String
        public var label: String
        public var gloss: String?
        public var glossAlternates: [String]
        public var value: Int
        public var opens: Bool
    }
}

// MARK: - The request

/// The archival surface's scope, as `setScope` sets it: its volumes and the chip's label, or the whole series.
struct ArchivalScope: Sendable, Equatable {
    var volumeIds: [String]?
    var label: String?

    static let whole = ArchivalScope(volumeIds: nil, label: nil)
}

/// What the Collections mode asks: the era, the lens, the stored weight, the umbrella and the scope.
struct ArchivalCollectionsAsk: Sendable, Equatable {
    var band: ArchivalEraBand
    var lens: ArchivalUnitLens
    var storedWeight: ArchivalWeight
    var hidesUmbrella: Bool
    var scope: ArchivalScope
}

/// The charts Archival Analytics exports, each as the app's control does: the ranking with its figure, the
/// every-unit list, the network's neighbourhood, the flows, and Your Library's three cards, as CSVs alone.
enum ArchivalAnalyticsChart: String, CaseIterable, Sendable {
    case ranking
    case units
    case network
    case flows
    case composition
    case bands
    case collections
}

enum ArchivalAnalyticsRoutes {
    static let scopeParameters: Set<String> = ["subseries", "volume", "topic", "subtopic", "volumes", "scopeLabel", "administration"]
    static let collectionsParameters: Set<String> = scopeParameters.union(["band", "lens", "weight", "umbrella"])

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/analytics/archives/context") { request, _ -> ArchivalContext in
            try FormQuery(request.uri.query).refuseUnknown([])
            // The count the app reads as `appState?.indexedVolumeIds.count ?? 0`: an index that cannot be had leaves none.
            let indexed = (try? await provider.servedIfReady())?.indexedVolumeIds.count ?? 0
            return try await Blocking.run { context(resources: resources, indexedVolumeCount: indexed) }
        }
        router.get("/api/v1/analytics/archives") { request, _ -> ArchivalCollectionsAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(collectionsParameters)
            let ask = try collectionsAsk(query, resources: resources)
            let data = try await collections(ask.scope, resources: resources)
            return ArchivalAnalyticsView(ask: ask, data: data, resources: resources, indexedVolumeCount: 0).collectionsAnswer()
        }
        router.get("/api/v1/analytics/archives/units") { request, _ -> ArchivalUnitsAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(collectionsParameters)
            let ask = try collectionsAsk(query, resources: resources)
            let data = try await collections(ask.scope, resources: resources)
            return ArchivalAllUnits(view: ArchivalAnalyticsView(ask: ask, data: data, resources: resources, indexedVolumeCount: 0)).answer()
        }
        ArchivalNetworkRoutes.add(to: router, provider: provider, resources: resources)
        ArchivalFlowsRoutes.add(to: router, provider: provider, resources: resources)
        ArchivalLibraryRoutes.add(to: router, provider: provider, resources: resources)
        router.get("/api/v1/analytics/archives/export") { request, _ -> Response in
            let query = try FormQuery(request.uri.query)
            let chart = try query.choice("chart", among: ArchivalAnalyticsChart.allCases) ?? .ranking
            try query.refuseUnknown(parameters(for: chart).union(["chart", "timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let now = Date()
            let (table, provenance) = try await export(chart, query: query, provider: provider, resources: resources)
            let csv = table.provenancedCSV(provenance, for: CorpusAnalyticsRoutes.host(timeZone: timeZone))
            return AnalyticsFigures.csv(csv, name: CorpusAnalyticsRoutes.filenameStem(title: provenance.figureTitle, date: now))
        }
        router.get("/api/v1/analytics/archives/plate") { request, _ -> AnalyticsPlate in
            let query = try FormQuery(request.uri.query)
            let chart = try query.choice("chart", among: ArchivalAnalyticsChart.allCases) ?? .ranking
            try query.refuseUnknown(parameters(for: chart).union(["chart", "timeZone"]))
            // The ranking alone is drawn as a figure (`deliverFigure`); every other export is a CSV.
            guard chart == .ranking else {
                throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "This chart is exported as a CSV alone.")
            }
            let timeZone = try AnalyticsFigures.timeZone(query)
            let now = Date()
            let (_, provenance) = try await export(chart, query: query, provider: provider, resources: resources)
            return AnalyticsPlate(provenance, host: CorpusAnalyticsRoutes.host(timeZone: timeZone), date: now)
        }
    }

    /// The parameters each chart's export takes: its mode's own.
    static func parameters(for chart: ArchivalAnalyticsChart) -> Set<String> {
        switch chart {
        case .ranking, .units: collectionsParameters
        case .network: ArchivalNetworkRoutes.parameters
        case .flows: ArchivalFlowsRoutes.parameters
        case .composition, .bands, .collections: []
        }
    }

    // MARK: The context

    static func context(resources: ServerResources, indexedVolumeCount: Int) -> ArchivalContext {
        let scopable = scopableVolumeIds(resources)
        let options = { (cases: [(value: String, title: String)]) in cases.map { ArchivalContext.Option(value: $0.value, title: $0.title) } }
        var topics: [AnalyticsContext.TopicCategory] = []
        if let resolved = CorpusAnalyticsRoutes.detectedTopics(resources), !resolved.isEmpty {
            topics = ScopeFacets.narrowingCategories(resolvedByVolume: resolved).map { category in
                AnalyticsContext.TopicCategory(
                    label: category.label,
                    items: ScopeFacets.subCategoryCatalog(forCategory: category.label, resolvedByVolume: resolved).map { sub in
                        let profile = ScopeFacets.volumeIds(forCategory: sub.category, subcategory: sub.subcategory, resolvedByVolume: resolved)
                        let count = profile.intersection(scopable).count
                        return AnalyticsContext.TopicItem(
                            subcategory: sub.subcategory,
                            label: CorpusAnalyticsView.subjectFacetLabel(sub.subcategory, indexed: count, total: profile.count),
                            indexed: count, total: profile.count)
                    })
            }
        }
        let administrations = resources.administrationProfiles?.administrations ?? []
        return ArchivalContext(
            modes: options(ArchivalAnalyticsMode.allCases.map { ($0.rawValue, $0.title) }),
            bands: ArchivalEraBand.all.map { .init(value: String($0.index), title: $0.title) },
            defaultBand: String(ArchivalAnalyticsView.defaultBand.index),
            lenses: options(ArchivalUnitLens.allCases.map { ($0.rawValue, $0.title) }),
            weights: options(ArchivalWeight.allCases.map { ($0.rawValue, $0.title) }),
            measures: options(ArchivalEdgeMeasure.allCases.map { ($0.rawValue, $0.title) }),
            expansions: options(ArchivalUmbrellaExpansion.allCases.map { ($0.rawValue, $0.title) }),
            layers: resources.sourceExplorer(\.externalCitations) == nil
                ? [] : options(ArchivalFlowLayer.allCases.map { ($0.rawValue, $0.title) }),
            directions: options(ArchivalFlowDirection.allCases.map { ($0.rawValue, $0.title) }),
            thresholds: ArchivalNetworkView.thresholds, defaultThreshold: ArchivalNetworkView.defaultThreshold,
            subseries: CorpusAnalyticsRoutes.indexedSubseries(scopable).map { name in
                .init(name: name, volumes: CorpusAnalyticsRoutes.volumes(inSubseries: name, indexed: scopable).map {
                    .init(id: $0, title: CorpusAnalyticsRoutes.volumeTitle($0, resources: resources))
                })
            },
            topics: topics,
            administrations: administrations.map { .init(id: $0.id, president: $0.president) },
            seriesVolumeIds: scopable.sorted(),
            indexedVolumeCount: indexedVolumeCount,
            researchGuide: appWords("archival.researchGuide", "About Archival Sourcing"),
            methodPointer: ArchivalAnalyticsView.methodPointer,
            networkUnavailable: (resources.collectionAuthority?.collections.isEmpty ?? true)
                ? appWords("archival.network.unavailable", "The bundled collection authority is unavailable in this build, so the network cannot be drawn.")
                : nil,
            flowsUnavailable: (resources.bundledAnalytics.flows.value(in: resources.directory) == nil || resources.collectionAuthority == nil)
                ? appWords("archival.flows.unavailable", "The bundled reference-flow index is unavailable in this build, so hand-offs cannot be shown. This is not the same as the series having none.")
                : nil)
    }

    // MARK: Reading the request

    /// The volumes the scope bar offers here (`scopableVolumeIds`): the series', from the bundled catalogue.
    static func scopableVolumeIds(_ resources: ServerResources) -> Set<String> {
        Set(resources.manifest.map(\.volumeId))
    }

    /// The scope a request names, as the archival surface's scope bar and administration menu set it: a subseries's
    /// volumes, a volume, a subject's volumes, a reader's volume scope as given, or a presidency's volumes, each the
    /// series' and never empty, as the bar disables an item with none and the menu ignores one.
    static func scope(_ query: FormQuery, resources: ServerResources) throws -> ArchivalScope {
        let named = ["subseries", "volume", "topic", "volumes", "administration"].filter { !query.values($0).isEmpty }
        guard named.count <= 1 else {
            throw APIProblem.invalidParameter(named[1], "a scope is one of subseries, volume, topic, volumes or administration, not \(named.joined(separator: " and "))")
        }
        if !query.values("subtopic").isEmpty, named != ["topic"] {
            throw APIProblem.invalidParameter("subtopic", "is taken only with a topic")
        }
        if !query.values("scopeLabel").isEmpty, named != ["volumes"] {
            throw APIProblem.invalidParameter("scopeLabel", "is taken only with a scope of volumes")
        }
        let scopable = scopableVolumeIds(resources)
        if let subseries = try query.single("subseries") {
            let ids = CorpusAnalyticsRoutes.volumes(inSubseries: subseries, indexed: scopable)
            guard !ids.isEmpty else { throw APIProblem.invalidParameter("subseries", "no volume of the series is in \(subseries)") }
            return ArchivalScope(volumeIds: ids, label: subseries)
        }
        if let volume = try query.single("volume") {
            guard scopable.contains(volume) else { throw APIProblem.volumeNotFound(volume) }
            return ArchivalScope(volumeIds: [volume], label: CorpusAnalyticsRoutes.volumeTitle(volume, resources: resources))
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
                .intersection(scopable)
            guard !ids.isEmpty else { throw APIProblem.invalidParameter("topic", "no volume of the series is in \(category) · \(subcategory)") }
            return ArchivalScope(volumeIds: ids.sorted(), label: "\(category) · \(subcategory)")
        }
        if let ids = try query.list("volumes") {
            guard !ids.isEmpty else { throw APIProblem.invalidParameter("volumes", "a scope names at least one volume") }
            guard ids.count <= CorpusAnalyticsRoutes.maximumScopeVolumes else {
                throw APIProblem.invalidParameter("volumes", "names \(ids.count) volumes, more than \(CorpusAnalyticsRoutes.maximumScopeVolumes)")
            }
            for id in ids where !scopable.contains(id) { throw APIProblem.volumeNotFound(id) }
            // A scope's name, or the chip's when an address gives none (`AnalyticsChartChrome`'s Selected volumes): a
            // nameless scope would read, and export, as the whole series.
            let label = try query.single("scopeLabel").flatMap { $0.isEmpty ? nil : $0 }
            return ArchivalScope(volumeIds: Array(Set(ids)).sorted(),
                                 label: label ?? appWords("analytics.scope.custom", "Selected volumes"))
        }
        if let id = try query.single("administration") {
            // `administrationMenu`: the presidency's volumes the series holds, sorted, under the president's name.
            guard let profile = (resources.administrationProfiles?.administrations ?? []).first(where: { $0.id == id }) else {
                throw APIProblem.invalidParameter("administration", "\(id) is not an administration the menu offers")
            }
            let ids = profile.volumes.map(\.volumeId)
                .filter { scopable.contains($0) }
            guard !ids.isEmpty else { throw APIProblem.invalidParameter("administration", "no volume of the series is attributed to \(profile.president)") }
            return ArchivalScope(volumeIds: ids.sorted(), label: profile.president)
        }
        return .whole
    }

    static func collectionsAsk(_ query: FormQuery, resources: ServerResources) throws -> ArchivalCollectionsAsk {
        let band: ArchivalEraBand
        if let raw = try query.single("band") {
            guard let index = Int(raw), String(index) == raw, let found = ArchivalEraBand.all.first(where: { $0.index == index }) else {
                throw APIProblem.invalidParameter("band", "must be one of \(ArchivalEraBand.all.map { String($0.index) }.joined(separator: ", ")), not \(raw)")
            }
            band = found
        } else {
            band = ArchivalAnalyticsView.defaultBand
        }
        return ArchivalCollectionsAsk(
            band: band,
            lens: try query.choice("lens", among: ArchivalUnitLens.allCases) ?? .namedCollections,
            storedWeight: try query.choice("weight", among: ArchivalWeight.allCases) ?? .documents,
            // The umbrella is hidden by default, per visit.
            hidesUmbrella: !(try query.bool("umbrella") ?? false),
            scope: try scope(query, resources: resources))
    }

    // MARK: The kept derivation

    /// The Collections derivation for a scope, as `loadCollections()` builds it, once for the scope and kept: the kit's
    /// `make` over the authority's collections, the usage index, the scope's coverage, the external citations and the
    /// two label tables, each the app's store's file decoded by the kit.
    static func collections(_ scope: ArchivalScope, resources: ServerResources) async throws -> ArchivalCollectionsData {
        let bundle = resources.bundledAnalytics
        let key = SeriesScopeKey(scope.volumeIds)
        return try await bundle.collections.value(for: key) {
            try await Blocking.run {
                let directory = resources.directory
                let coverage = ArchivalVolumeCoverage.map(from: resources.manifest, limitedTo: key.set)
                return ArchivalCollectionsData.make(
                    authority: resources.collectionAuthority?.collections ?? [],
                    usage: bundle.usage.value(in: directory),
                    coverage: coverage,
                    external: resources.sourceExplorer(\.externalCitations),
                    labels: bundle.decimalLabels.value(in: directory),
                    subjectNumericLabels: bundle.subjectNumericLabels.value(in: directory))
            }
        }
    }

    // MARK: The export

    /// A chart's table and statement, as each of the app's export controls makes it, refused where the control is
    /// disabled (an empty table).
    static func export(_ chart: ArchivalAnalyticsChart, query: FormQuery, provider: ServedIndexProvider,
                       resources: ServerResources) async throws -> (ChartInspectorData, AnalyticsProvenance) {
        func nothing(_ what: String) -> APIProblem {
            APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "\(what) holds nothing to export.")
        }
        // A statement's indexed count, which no bundled chart's export waits on an index for.
        let indexedVolumeCount = (try? await provider.servedIfReady())?.indexedVolumeIds.count ?? 0
        switch chart {
        case .ranking, .units:
            let ask = try collectionsAsk(query, resources: resources)
            let data = try await collections(ask.scope, resources: resources)
            let view = ArchivalAnalyticsView(ask: ask, data: data, resources: resources, indexedVolumeCount: indexedVolumeCount)
            if chart == .units {
                let units = ArchivalAllUnits(view: view)
                guard !units.ranking.rows.isEmpty else { throw nothing(units.title) }
                return (units.table, units.provenance)
            }
            let ranking = view.ranking
            guard let table = view.rankingInspector(ranking, title: view.rankingTitle) else { throw nothing(view.rankingTitle) }
            return (table, view.rankingProvenance(ranking))
        case .network:
            return try await ArchivalNetworkRoutes.export(query: query, resources: resources, indexedVolumeCount: indexedVolumeCount)
        case .flows:
            return try await ArchivalFlowsRoutes.export(query: query, resources: resources, indexedVolumeCount: indexedVolumeCount)
        case .composition, .bands, .collections:
            let served = try await provider.served()
            let profile = try await ArchivalLibraryRoutes.profile(served: served, resources: resources)
            withExtendedLifetime(served) {}
            let view = ArchivalLibraryView(profile: profile, indexedVolumeCount: served.indexedVolumeIds.count,
                                           corpusVolumeCount: resources.manifest.count)
            let (table, provenance) = view.export(chart)
            guard !profile.isEmpty, !table.rows.isEmpty else { throw nothing(table.title) }
            return (table, provenance)
        }
    }
}

// MARK: - The view's rules

/// What `ArchivalAnalyticsView` decides between the kit's derivation and its Collections mode, under its names
/// (`ArchivalAnalyticsView.swift`); held to the app's source by the mirror test.
struct ArchivalAnalyticsView {
    /// The band the ranking opens on: 1948–1960, where named collections and central-file classes are both well populated.
    static let defaultBand = ArchivalEraBand.all[1]

    let ask: ArchivalCollectionsAsk
    let data: ArchivalCollectionsData
    let resources: ServerResources
    /// The served index's volumes, which the statement counts, or 0 with none served.
    let indexedVolumeCount: Int

    var band: ArchivalEraBand { ask.band }
    var unitLens: ArchivalUnitLens { ask.lens }
    var hidesUmbrella: Bool { ask.hidesUmbrella }
    var scopeLabel: String? { ask.scope.label }

    /// The weight actually in force: the stored one where it can be drawn, else volumes, the floor.
    var weight: ArchivalWeight {
        let stored = ask.storedWeight
        return supports(stored) ? stored : .volumes
    }

    /// Whether a weight can be drawn, under a lens and this bundle's artifacts.
    func supports(_ candidate: ArchivalWeight, for lens: ArchivalUnitLens? = nil) -> Bool {
        let lens = lens ?? unitLens
        switch candidate {
        case .volumes: return true
        case .documents: return data.supportsDocumentWeight
        case .unprintedPointers:
            return (lens == .namedCollections || lens == .centralFileClasses)
                && data.supportsPointerWeight
        }
    }

    var ranking: ArchivalRanking {
        data.ranking(band: band, lens: unitLens, weight: weight,
                     hidingUmbrella: hidesUmbrella)
    }

    var rankingTitle: String {
        unitLens == .namedCollections
            ? appWords("archival.ranking.title.collections", "Top collections by era")
            : appWords("archival.ranking.title.classes", "Top central-file classes by era")
    }

    func rankingCaption(_ ranking: ArchivalRanking) -> String {
        ArchivalCounts.rankingCaption(bandTitle: band.title,
                                      bandVolumeCount: ranking.bandVolumeCount,
                                      unitsReached: ranking.unitsReached, lens: unitLens,
                                      measuresPrintedMaterial: weight.measuresPrintedMaterial)
    }

    func accessibilityValue(for row: ArchivalRankingRow) -> String {
        ArchivalCounts.rankingAccessibilityValue(row.value, weight: weight,
                                                 custodian: row.category.displayName)
    }

    /// The bar's name for a screen reader: the label, its gloss and how many other readings it has.
    func accessibilityLabel(for row: ArchivalRankingRow) -> String {
        [row.label, row.gloss,
         row.glossAlternates.isEmpty ? nil
             : ArchivalCounts.andOthers(row.glossAlternates.count)]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    func rankingInspector(_ ranking: ArchivalRanking, title: String)
        -> ChartInspectorData? {
        guard !ranking.rows.isEmpty else { return nil }
        return ChartInspectorData(
            id: "archival.ranking",
            title: title,
            columns: [
                appWords("archival.table.unit", "Archival unit"),
                appWords("archival.table.custodian", "Custodian"),
                weight.title,
            ],
            rowCells: ranking.rows.map { [$0.label, $0.category.displayName, "\($0.value)"] })
    }

    func rankingProvenance(_ ranking: ArchivalRanking) -> AnalyticsProvenance {
        ArchivalAnalyticsExport.ranking(
            band: band, lens: unitLens, weight: weight,
            hiddenUmbrella: ranking.hiddenUmbrellaValue, unitsReached: ranking.unitsReached,
            bandVolumeCount: ranking.bandVolumeCount,
            indexedVolumeCount: indexedVolumeCount,
            noteCount: ranking.bandNoteCount, shownValue: ranking.shownValue,
            scopeLabel: scopeLabel)
    }

    /// Whether a row opens anything: a named collection's record where the authority holds it, a class's documents.
    func canOpen(_ row: ArchivalRankingRow) -> Bool {
        unitLens == .centralFileClasses
            || data.record(forId: row.id) != nil
    }

    // The denominator line (#826/R-5).

    /// "N source notes in this era. The M rows below account for X% of them."
    func denominatorSentence(_ ranking: ArchivalRanking, notes: Int) -> String {
        let population = scopeLabel.map {
            String(format: appWords("archival.denominator.scoped %@ %@", "%1$@, %2$@"), $0, band.title)
        } ?? band.title
        guard let share = ranking.shownShare(weight: weight) else {
            return String(format: appWords("archival.denominator.notes %@ %@", "%1$@ in %2$@."),
                          ArchivalCounts.sourceNotes(notes), population)
        }
        let rows = CountCopy.phrase(
            ranking.rows.count,
            one: appWords("archival.denominator.rows.one", "The %@ row below accounts for"),
            many: appWords("archival.denominator.rows.many", "The %@ rows below account for"),
            locale: SearchItem.locale)
        return String(format: appWords("archival.denominator.share %@ %@ %@ %@", "%1$@ in %2$@. %3$@ %4$@ of them."),
                      ArchivalCounts.sourceNotes(notes), population, rows, Self.shareText(share))
    }

    /// A share, never rounded to a number that reads as nothing.
    static func shareText(_ share: Double) -> String {
        guard share >= 0.01 else {
            return appWords("archival.denominator.underOnePercent", "under 1%")
        }
        return share.formatted(.percent.precision(.fractionLength(share < 0.1 ? 1 : 0)).locale(SearchItem.locale))
    }

    /// Whether the other lens reaches materially more of this band, and the sentence that says so.
    func denominatorPointer() -> String? {
        let other: ArchivalUnitLens = unitLens == .namedCollections ? .centralFileClasses
                                                                    : .namedCollections
        let mine = data.reach(band: band, lens: unitLens)
        let theirs = data.reach(band: band, lens: other)
        guard theirs > mine * 2 else { return nil }
        switch other {
        case .centralFileClasses:
            return appWords("archival.denominator.tryClasses",
                            "Most of this era’s sourcing names a central-file number rather than a named collection — switch the unit to File numbers to rank those.")
        case .namedCollections:
            return appWords("archival.denominator.tryCollections",
                            "Most of this era’s sourcing names a collection rather than a central-file number — switch the unit to Collections to rank those.")
        }
    }

    var familiesCaption: String {
        weight == .documents
            ? appWords("archival.families.caption.documents",
                       "Related file numbers are ranked together. Open one for the exact designator a pull slip needs; its parts add up to the bar above.")
            : appWords("archival.families.caption.volumes",
                       "Related file numbers are ranked together. Open one for the exact designator a pull slip needs. Each line counts the volumes citing that designator, so they overlap and do not add up to the bar: a volume citing two of them counts once for the group.")
    }

    func classFamilies(_ ranking: ArchivalRanking) -> ArchivalCollectionsAnswer.Families? {
        let families = ranking.rows.filter(\.isFamily)
        guard unitLens == .centralFileClasses, !families.isEmpty else { return nil }
        return ArchivalCollectionsAnswer.Families(
            title: appWords("archival.families.title", "Inside these families"),
            caption: familiesCaption,
            items: families.map { family in
                ArchivalCollectionsAnswer.Family(
                    name: family.name,
                    count: String(format: appWords("archival.families.count %lld", "%lld in family"), Int64(family.leaves.count)),
                    leaves: family.leaves.sorted {
                        $0.value(weight: weight) != $1.value(weight: weight)
                            ? $0.value(weight: weight) > $1.value(weight: weight)
                            : $0.key < $1.key
                    }.map { leaf in
                        ArchivalCollectionsAnswer.Leaf(key: leaf.key, gloss: leaf.gloss,
                                                       tag: appWords("archival.families.leaf", "single file"),
                                                       value: leaf.value(weight: weight))
                    })
            })
    }

    func collectionsConditionalCaveats(ranking: ArchivalRanking) -> [String] {
        var caveats: [String] = []
        if let hidden = ranking.hiddenUmbrellaValue {
            caveats.append(ArchivalCounts.umbrellaCaveat(weight: weight, hidden: hidden,
                                                         bandTitle: band.title))
        }
        if !data.supportsDocumentWeight {
            caveats.append(appWords("archival.caveats.noUsageIndex",
                                    "Document counts are unavailable in this build — the bundled usage index did not load — so only the volume weight is offered."))
        }
        if unitLens == .centralFileClasses, weight == .unprintedPointers {
            caveats.append(appWords("archival.caveats.classPointersSelfCitation",
                                    "Most central-file citations name the file the citing document itself came from — about three in five, and closer to three in four before 1946. They are counted here, because the file was still cited, but they are not movement between archives."))
        } else if !data.supportsPointerWeight {
            caveats.append(appWords("archival.caveats.noExternalIndex",
                                    "Unprinted pointers are unavailable in this build — the bundled external-citation index did not load."))
        }
        return caveats
    }

    static let methodPointer = appWords("archival.caveats.pointer",
                                        "Where these figures come from, what each count measures, and how coverage changes by era — in About These Figures, above.")
    static let timingPointer = appWords("archival.collections.timingPointer",
                                        "When one collection entered the published record, and how long the editors kept returning to it, is on that collection’s own record, under Cited Over Time.")

    func collectionsAnswer() -> ArchivalCollectionsAnswer {
        let ranking = self.ranking
        let rows = ranking.rows.map { row in
            ArchivalCollectionsAnswer.Row(
                id: row.id, label: row.label, category: row.category.rawValue, categoryName: row.category.displayName,
                value: row.value, gloss: row.gloss, glossAlternates: row.glossAlternates,
                accessibilityLabel: accessibilityLabel(for: row), accessibilityValue: accessibilityValue(for: row),
                opens: canOpen(row))
        }
        let hiddenWord = appWords("archival.filter.umbrella.hidden", "Hidden")
        let shownWord = appWords("archival.filter.umbrella.shown", "Shown")
        let umbrellaValue = hidesUmbrella ? hiddenWord : shownWord
        return ArchivalCollectionsAnswer(
            scope: .init(label: scopeLabel ?? (ask.scope.volumeIds == nil
                                               ? appWords("analytics.scope.wholeCorpus", "Whole corpus")
                                               : appWords("analytics.scope.custom", "Selected volumes")),
                         isNarrowed: ask.scope.volumeIds != nil),
            band: String(band.index), lens: unitLens.rawValue, weight: weight.rawValue,
            weights: ArchivalWeight.allCases.map { .init(value: $0.rawValue, title: $0.title, enabled: supports($0)) },
            hidesUmbrella: hidesUmbrella,
            umbrella: unitLens == .namedCollections
                ? .init(caption: appWords("archival.filter.umbrella", "Central Files"), value: umbrellaValue,
                        accessibilityLabel: appWords("archival.filter.umbrella.a11y", "Central Files umbrella record"),
                        hidden: hiddenWord, shown: shownWord)
                : nil,
            denominator: data.noteCount(band: band).map {
                .init(sentence: denominatorSentence(ranking, notes: $0), pointer: denominatorPointer())
            },
            ranking: .init(
                title: rankingTitle, caption: rankingCaption(ranking),
                empty: ranking.rows.isEmpty
                    ? appWords("archival.ranking.empty", "No archival units resolved in this era under the current unit and weight.")
                    : nil,
                axisLabel: weight.title,
                rows: rows,
                table: rankingInspector(ranking, title: rankingTitle).map(ArchivalTables.table)),
            drillInHint: ranking.rows.isEmpty ? nil
                : (unitLens == .namedCollections
                   ? appWords("archival.ranking.drillIn.collections", "Select a bar to open that collection’s record, or use the list below.")
                   : appWords("archival.ranking.drillIn.classes", "Select a bar to see that file number’s documents, or use the list below.")),
            showAllUnits: ranking.unitsReached > ranking.rows.count
                ? CountCopy.phrase(ranking.unitsReached,
                                   one: appWords("archival.allUnits.button.one", "Show the %@ unit in this era"),
                                   many: appWords("archival.allUnits.button.many", "Show all %@ units in this era"),
                                   locale: SearchItem.locale)
                : nil,
            families: classFamilies(ranking),
            caveats: collectionsConditionalCaveats(ranking: ranking),
            timingPointer: Self.timingPointer)
    }
}

/// The uncapped list's rules (`ArchivalAllUnitsSheet`), for the chart it was opened from.
struct ArchivalAllUnits {
    let view: ArchivalAnalyticsView

    var ranking: ArchivalRanking {
        view.data.ranking(band: view.band, lens: view.unitLens, weight: view.weight,
                          hidingUmbrella: view.hidesUmbrella, limit: .max)
    }

    var title: String { appWords("archival.allUnits.title", "Every Unit") }

    var header: String {
        String(format: appWords("archival.allUnits.header %@ %@", "%1$@ · %2$@"),
               CountCopy.phrase(ranking.rows.count,
                                one: appWords("archival.allUnits.header.units.one", "%@ unit"),
                                many: appWords("archival.allUnits.header.units.many", "%@ units"),
                                locale: SearchItem.locale),
               view.band.title)
    }

    var footer: String {
        String(format: appWords("archival.allUnits.footer %@ %@", "Ranked by %1$@, same as the chart. %2$@"),
               view.weight.title.lowercased(),
               view.hidesUmbrella && view.unitLens == .namedCollections
                   ? appWords("archival.allUnits.footer.umbrella",
                              "The Central Files umbrella record is withheld here too, so this list and the chart above count the same population.")
                   : appWords("archival.allUnits.footer.everything", "Nothing is withheld."))
    }

    var table: ChartInspectorData {
        ChartInspectorData(
            id: "archival.allUnits",
            title: String(format: appWords("archival.allUnits.export.title %@ %@", "%1$@ — every unit, %2$@"),
                          view.unitLens.title, view.band.title),
            columns: [
                appWords("archival.table.unit", "Archival unit"),
                appWords("archival.table.custodian", "Custodian"),
                view.weight.title,
            ],
            rowCells: ranking.rows.map { row in
                let reading = row.gloss.map { gloss -> String in
                    ArchivalCounts.exportReading(gloss: gloss,
                                                 alternates: row.glossAlternates.count)
                }
                return [[row.label, reading].compactMap { $0 }.joined(separator: " — "),
                        row.category.displayName, "\(row.value)"]
            })
    }

    var provenance: AnalyticsProvenance {
        let ranking = self.ranking
        return ArchivalAnalyticsExport.ranking(
            band: view.band, lens: view.unitLens, weight: view.weight,
            hiddenUmbrella: ranking.hiddenUmbrellaValue, unitsReached: ranking.unitsReached,
            bandVolumeCount: ranking.bandVolumeCount, indexedVolumeCount: view.indexedVolumeCount,
            noteCount: ranking.bandNoteCount, shownValue: ranking.shownValue,
            rowCapApplied: false, scopeLabel: view.scopeLabel,
            glossesWritten: ranking.rows.contains { $0.gloss != nil })
    }

    func answer() -> ArchivalUnitsAnswer {
        ArchivalUnitsAnswer(
            title: title, header: header, footer: footer,
            rows: ranking.rows.enumerated().map { index, row in
                ArchivalUnitsAnswer.Row(rank: "\(index + 1).", id: row.id, label: row.label, gloss: row.gloss,
                                        glossAlternates: row.glossAlternates, value: row.value, opens: view.canOpen(row))
            })
    }
}

/// A kit table as the answer carries it.
enum ArchivalTables {
    static func table(_ data: ChartInspectorData) -> CorpusAnalyticsAnswer.Table {
        CorpusAnalyticsAnswer.Table(title: data.title, columns: data.columns, rows: data.rows.map(\.cells))
    }
}
