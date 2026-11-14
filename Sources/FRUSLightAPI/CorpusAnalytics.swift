// Corpus Analytics (PLAN's S24f): a term's frequency across the served index, as the app's `AnalyticsView`
// charts it. Every series is the kit's `CorpusAnalyticsService` (FRUS-Explorer#1896), over the served index,
// fetched in the order the view's `reloadData()` fetches them for one committed term; the folding by volume
// (`AnalyticsSourceColoring`), the occurrence rule (`OccurrenceAvailability`), the hand-off's search and count
// (`AnalyticsSearchHandoff`), the dispersion (`CorpusDispersion`), the table (`AnalyticsChartTables`) and the
// method block (`AnalyticsProvenance`) are the kit's too, compiled from the submodule. What stays the view's,
// private, between the service and a chart is mirrored here, under the view's names, and held to the app's
// source by `CorpusAnalyticsParityTests`: the year-range filters and `yearRangeIsCustom`, the measure's and the
// normalisation's gates (`measureApplies`, `normalizationApplies`, `isNormalized`, `valueUnit`),
// `normalizedValue`, the occurrences' decades (`decadeSeries`), the headings, the export's title, table, period
// column and statement, the hand-off's words and the dispersion line, the scope menu's items, and the empty
// states' words; from the app's other files, the corpus's years (`ManifestStore.corpusDateRange`), the
// administration presets (`AdministrationPresetMenu.presets`) and the palette's count of colours
// (`ChartSeriesPalette`).
//
// One committed term, as the app's Search commits one: comparing terms, saved and recent queries, the scrub
// across the chart and the figure's PDF are not here (SPEC's Corpus Analytics). The browser shows the chart and
// its table at once, so the view's mode is always the chart's (`isNormalized` reads it), and the table is the
// export's, the app's chart data inspector.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

// MARK: - The answer

/// A term's chart, as the app's `AnalyticsView` draws it for one committed term, with its table and words.
public struct CorpusAnalyticsAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var term: String
    /// The axis, `AnalyticsChartAxis`'s raw value, and its picker's label.
    public var axis: String
    public var axisLabel: String
    /// What the content area shows: `chart`; `exactUnsupported`, the view's state for an `=` word the service
    /// refuses; or `empty`, No Results.
    public var state: String
    /// The state's title and words for `exactUnsupported` and `empty`.
    public var stateTitle: String?
    public var stateDetail: String?
    /// The chart's heading, the export's title, and the value axis's title.
    public var heading: String
    public var figureTitle: String
    public var valueAxisLabel: String
    /// The period axis's title (`exportPeriodColumn`).
    public var periodLabel: String
    public var measure: Measure
    public var values: Values
    public var years: Years
    public var scope: Scope
    /// How many colours the bars use before the rest fold into Other volumes.
    public var colors: Int
    /// The stacked bars of By Year and By Decade: each segment with its period, series and count, and the
    /// value plotted, a share in % of documents; none for a period with no denominator, as the view omits it.
    public var segments: [Segment]
    /// The legend's series, in its order, each with its title and total in the unit counted.
    public var series: [Series]
    /// The fit line's points over the plotted periods, By Year and By Decade.
    public var fit: [FitPoint]
    /// By Month's and By Day's points, each its stored label and count, within the years.
    public var points: [Point]
    /// By Month's or By Day's notice when no matching document is dated so finely.
    public var notice: Notice?
    /// By Subseries' and By Volume's bars, each its label, count, and the volumes its drill opens in Search.
    public var bars: [Bar]
    /// The caption under a normalised chart.
    public var normalizationCaption: String?
    /// The count under the chart, and beside it the full corpus's total when the years are narrowed.
    public var footnote: String?
    public var fullCorpusTotal: String?
    /// The documents the chart plots on this axis, as the view counts them (`matchedDocumentCount`): whether
    /// the hand-off link shows before Search has counted.
    public var matchedDocumentCount: Int
    /// The table behind the chart, the kit's `corpusSeriesTable`, as the app's export and inspector have it.
    public var table: Table

    /// The Measure picker, Documents or Occurrences, on By Year and By Decade (`measureApplies`).
    public struct Measure: Codable, Equatable, Sendable {
        /// What the reader chose, and what the numbers count (`valueUnit`).
        public var chosen: String
        public var effective: String
        public var applies: Bool
        /// Whether the term can be counted by occurrence (`OccurrenceAvailability`), and if not, the kit's reason.
        public var available: Bool
        public var reason: String?
        /// The notice the view shows when occurrences were asked for and cannot be served.
        public var notice: String?
    }

    /// The Values picker, Raw count or % of documents, on By Year and By Decade (`normalizationApplies`).
    public struct Values: Codable, Equatable, Sendable {
        public var chosen: String
        public var applies: Bool
        /// Disabled under Occurrences, where it is inert (#1305).
        public var enabled: Bool
        public var isNormalized: Bool
    }

    /// The year range, which the time views read and the breakdowns ignore.
    public struct Years: Codable, Equatable, Sendable {
        public var start: Int
        public var end: Int
        /// Whether the range is narrowed away from 1861 to the corpus's last year (`yearRangeIsCustom`).
        public var isCustom: Bool
        public var applies: Bool
    }

    /// The scope the chart counts, as the scope chip names it.
    public struct Scope: Codable, Equatable, Sendable {
        /// The chip's name for it: Whole corpus, or the scope's label.
        public var label: String
        /// The volumes it holds, or nil for the whole corpus.
        public var volumeIds: [String]?
    }

    public struct Segment: Codable, Equatable, Sendable {
        public var period: Int
        public var seriesKey: String
        public var count: Int
        public var plotted: Double?
    }

    public struct Series: Codable, Equatable, Sendable {
        public var key: String
        public var title: String
        public var total: Int
        /// "12 docs" or "12 mentions", the legend's total in the unit counted (`segmentLegendLabel`).
        public var totalLabel: String
        /// Whether it is the folded Other volumes, drawn grey.
        public var isOther: Bool
    }

    public struct FitPoint: Codable, Equatable, Sendable {
        public var period: Int
        public var value: Double
    }

    public struct Point: Codable, Equatable, Sendable {
        public var label: String
        public var count: Int
    }

    public struct Notice: Codable, Equatable, Sendable {
        public var title: String
        public var detail: String
    }

    public struct Bar: Codable, Equatable, Sendable {
        public var label: String
        public var count: Int
        public var volumeIds: [String]
    }

    /// A `ChartInspectorData`, its title, columns and rows.
    public struct Table: Codable, Equatable, Sendable {
        public var title: String
        public var columns: [String]
        public var rows: [[String]]
    }
}

/// Search's count of the documents the hand-off link opens, and the search it opens (#1756).
public struct CorpusAnalyticsDocuments: Codable, Equatable, Sendable, ResponseEncodable {
    /// The count, and the link's words, "View 9,162 documents".
    public var count: Int
    public var linkTitle: String
    /// The dispersion line beside it, or nil when the documents are none.
    public var dispersion: String?
    /// The search the link opens, in the fields of the browser app's Search address.
    public var search: SearchLink

    public struct SearchLink: Codable, Equatable, Sendable {
        public var keywords: String
        public var dateRangeEarliest: String?
        public var dateRangeLatest: String?
        public var volumeIds: [String]?
        /// Off, as the kit's hand-off sets them (#1306).
        public var includeNotes: Bool
        public var includeSummaries: Bool
    }
}

/// What both analytics screens read before a term or a range is asked for: the corpus's years, the presets,
/// the colours' counts and the scope menu's corpus-wide items.
public struct AnalyticsContext: Codable, Equatable, Sendable, ResponseEncodable {
    /// The year the range starts at by default, 1861, and the corpus's last year, its end (`corpusMaxYear`).
    public var floorYear: Int
    public var corpusMaxYear: Int
    /// The earliest year a start field takes, 1776, as the app's year field bounds it.
    public var earliestYear: Int
    /// Chronology's first range: the corpus's last year (`seedDefaultsAndApply`), as ISO days.
    public var chronologyFrom: String
    public var chronologyTo: String
    public var presets: [Preset]
    /// The colours' counts the picker offers, and the one it starts at.
    public var colorCounts: [Int]
    public var defaultColors: Int
    public var indexedVolumeCount: Int
    /// By Subseries and By Volume: the indexed subseries, each with its indexed volumes and their titles.
    public var subseries: [Subseries]
    /// By Detected Topic: the categories that narrow, each with its sub-categories, or none without the files.
    public var topics: [TopicCategory]

    public struct Preset: Codable, Equatable, Sendable {
        public var label: String
        public var start: Int
        public var end: Int
    }

    public struct Subseries: Codable, Equatable, Sendable {
        public var name: String
        public var volumes: [Volume]
    }

    public struct Volume: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
    }

    public struct TopicCategory: Codable, Equatable, Sendable {
        public var label: String
        public var items: [TopicItem]
    }

    public struct TopicItem: Codable, Equatable, Sendable {
        public var subcategory: String
        /// The item's words: "Arms control (3 of 5 indexed)", or "… — none indexed yet", disabled.
        public var label: String
        /// How many of its volumes are indexed, and how many the topic names.
        public var indexed: Int
        public var total: Int
    }
}

/// A figure's caption band, as the kit's method block writes it for the app's exported figure
/// (`AnalyticsProvenance.plateLines(for:)`): the title, the facts, the caveats, the attribution and the pointer to
/// the CSV, each with its role; and the file name the figure is saved under, without its extension.
public struct AnalyticsPlate: Codable, Equatable, Sendable, ResponseEncodable {
    public var lines: [Line]
    public var fileName: String

    public struct Line: Codable, Equatable, Sendable {
        /// `title`, `facts`, `caveat`, `attribution` or `dataPointer`.
        public var role: String
        public var text: String
    }

    init(_ provenance: AnalyticsProvenance, host: AnalyticsProvenance.Host, date: Date) {
        lines = provenance.plateLines(for: host).map { line in
            let role: String
            switch line.role {
            case .title: role = "title"
            case .facts: role = "facts"
            case .caveat: role = "caveat"
            case .attribution: role = "attribution"
            case .dataPointer: role = "dataPointer"
            }
            return Line(role: role, text: line.text)
        }
        fileName = CorpusAnalyticsRoutes.filenameStem(title: provenance.figureTitle, date: date)
    }
}

/// What the analytics screens' exports share.
enum AnalyticsFigures {
    /// The browser's time zone, in which the method block writes the export's moment, UTC when none is named.
    static func timeZone(_ query: FormQuery) throws -> TimeZone {
        let zone = try query.single("timeZone") ?? "UTC"
        guard let timeZone = TimeZone(identifier: zone) else {
            throw APIProblem.invalidParameter("timeZone", "\(zone) is not a time zone this server knows.")
        }
        return timeZone
    }

    /// A chart's CSV as an attachment, named `stem.csv`.
    static func csv(_ text: String, name stem: String) -> Response {
        var headers = ReaderRoutes.commonHeaders
        headers[.contentType] = "text/csv; charset=utf-8"
        headers[.contentDisposition] = CollectionExportRoutes.attachment(stem + ".csv")
        headers[.cacheControl] = "no-store"
        return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: text)))
    }
}

// MARK: - The request

/// What a request asks: the term, the axis, the measure and values chosen, the years, the scope and the colours.
struct CorpusAnalyticsAsk: Sendable, Equatable {
    var term: String
    var axis: AnalyticsChartAxis = .byYear
    var unit: AnalyticsValueUnit = .documents
    var normalization: AnalyticsNormalizationMode = .raw
    var start: Int
    var end: Int
    var scope: ResolvedScope = .wholeCorpus
    var colors: Int = CorpusAnalyticsRoutes.defaultColors

    /// The volumes a scope holds, with the label the chip names it by, as the app's `setScope` sets them.
    enum ResolvedScope: Sendable, Equatable {
        case wholeCorpus
        case volumes([String], label: String?)

        var volumeIds: [String]? {
            if case .volumes(let ids, _) = self { ids } else { nil }
        }

        var label: String? {
            if case .volumes(_, let label) = self { label } else { nil }
        }
    }
}

enum CorpusAnalyticsRoutes {
    /// The range's first year and its reset target, the first FRUS volume's (`AnalyticsView.yearRangeStart`).
    static let floorYear = 1861
    /// The earliest year the start field takes (`AnalyticsYearRangeBar.yearEntryField`'s bounds, `1776...end`).
    static let earliestYear = 1776
    /// `ChartSeriesPalette.range` and `.defaultCount`, the app's.
    static let colorCounts = 6...12
    static let defaultColors = 8
    /// The longest term taken, in characters, and the most volumes a scope names.
    static let maximumTermLength = 1_000
    static let maximumScopeVolumes = 1_024
    /// The parameters each route takes.
    static let chartParameters: Set<String> = ["term", "axis", "measure", "values", "from", "to", "colors",
                                               "subseries", "volume", "topic", "subtopic", "volumes", "scopeLabel"]

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/analytics/context") { request, _ -> AnalyticsContext in
            try FormQuery(request.uri.query).refuseUnknown([])
            let served = try await provider.served()
            let context = try await context(served: served, resources: resources)
            withExtendedLifetime(served) {}
            return context
        }
        router.get("/api/v1/analytics/corpus") { request, _ -> CorpusAnalyticsAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(chartParameters)
            let served = try await provider.served()
            let ask = try ask(query, served: served, resources: resources)
            let answer = try await answer(ask, served: served, resources: resources)
            withExtendedLifetime(served) {}
            return answer
        }
        router.get("/api/v1/analytics/corpus/documents") { request, _ -> CorpusAnalyticsDocuments in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(chartParameters)
            let served = try await provider.served()
            let ask = try ask(query, served: served, resources: resources)
            let documents = try await documents(ask, served: served, resources: resources)
            withExtendedLifetime(served) {}
            return documents
        }
        router.get("/api/v1/analytics/corpus/export") { request, _ -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(chartParameters.union(["timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let served = try await provider.served()
            let ask = try ask(query, served: served, resources: resources)
            let answer = try await answer(ask, served: served, resources: resources)
            let now = Date()
            let provenance = provenance(ask, answer: answer, indexedVolumeCount: served.indexedVolumeIds.count, exportDate: now)
            withExtendedLifetime(served) {}
            guard answer.state == "chart" else {
                throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "The chart for \(ask.term) holds nothing to export.")
            }
            let csv = inspectorData(answer.table).provenancedCSV(provenance, for: host(timeZone: timeZone))
            return AnalyticsFigures.csv(csv, name: filenameStem(title: answer.figureTitle, date: now))
        }
        router.get("/api/v1/analytics/corpus/plate") { request, _ -> AnalyticsPlate in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(chartParameters.union(["timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let served = try await provider.served()
            let ask = try ask(query, served: served, resources: resources)
            let answer = try await answer(ask, served: served, resources: resources)
            let now = Date()
            let provenance = provenance(ask, answer: answer, indexedVolumeCount: served.indexedVolumeIds.count, exportDate: now)
            withExtendedLifetime(served) {}
            return AnalyticsPlate(provenance, host: host(timeZone: timeZone), date: now)
        }
    }

    // MARK: Reading the request

    /// The request's term, axis, measure, values, years, scope and colours, each checked.
    static func ask(_ query: FormQuery, served: ServedIndex, resources: ServerResources) throws -> CorpusAnalyticsAsk {
        // `addTerm()` and `runSearch()` trim the field's spaces.
        let term = (try query.single("term") ?? "").trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { throw APIProblem.invalidParameter("term", "a chart needs a term") }
        guard term.count <= maximumTermLength else {
            throw APIProblem.invalidParameter("term", "is longer than \(maximumTermLength) characters")
        }
        // The service keys its caches by the term's text, joined to a scope by U+0001: a control character in a
        // term could meet another request's entry, and no search box types one.
        guard !term.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else {
            throw APIProblem.invalidParameter("term", "holds a control character")
        }
        let maxYear = corpusMaxYear(resources.manifest)
        let start = try query.integer("from", in: earliestYear...maxYear, default: floorYear)
        let end = try query.integer("to", in: earliestYear...maxYear, default: maxYear)
        guard start <= end else { throw APIProblem.invalidParameter("from", "the range must start before it ends, not \(start)–\(end)") }
        return CorpusAnalyticsAsk(
            term: term,
            axis: try query.choice("axis", among: AnalyticsChartAxis.allCases) ?? .byYear,
            unit: try query.choice("measure", among: AnalyticsValueUnit.allCases) ?? .documents,
            normalization: try query.choice("values", among: AnalyticsNormalizationMode.allCases) ?? .raw,
            start: start, end: end,
            scope: try scope(query, served: served, resources: resources),
            colors: try query.integer("colors", in: colorCounts, default: defaultColors))
    }

    /// The scope a request names, resolved to its volumes as the scope menu's item seeds them: a subseries's
    /// indexed volumes, a volume, a detected topic's indexed volumes, or the volumes a scope of the user's holds,
    /// with the label each gives; the whole corpus for none. A scope that holds no indexed volume is refused,
    /// as the menu disables it, rather than read as the whole corpus (`setScope`'s empty→nil).
    static func scope(_ query: FormQuery, served: ServedIndex, resources: ServerResources) throws -> CorpusAnalyticsAsk.ResolvedScope {
        let named = ["subseries", "volume", "topic", "volumes"].filter { !query.values($0).isEmpty }
        guard named.count <= 1 else {
            throw APIProblem.invalidParameter(named[1], "a scope is one of subseries, volume, topic or volumes, not \(named.joined(separator: " and "))")
        }
        let indexed = served.indexedVolumeIds
        if let subseries = try query.single("subseries") {
            let ids = volumes(inSubseries: subseries, indexed: indexed)
            guard !ids.isEmpty else { throw APIProblem.invalidParameter("subseries", "no indexed volume is in \(subseries)") }
            return .volumes(ids, label: subseries)
        }
        if let volume = try query.single("volume") {
            guard resources.volume(volume) != nil else { throw APIProblem.volumeNotFound(volume) }
            return .volumes([volume], label: volumeTitle(volume, resources: resources))
        }
        if let category = try query.single("topic") {
            guard let subcategory = try query.single("subtopic") else {
                throw APIProblem.invalidParameter("subtopic", "a topic is scoped by one of its sub-categories")
            }
            guard let resolved = detectedTopics(resources), !resolved.isEmpty else {
                throw APIProblem.invalidParameter("topic", "this server has no detected topics")
            }
            let ids = ScopeFacets.volumeIds(forCategory: category, subcategory: subcategory, resolvedByVolume: resolved)
                .intersection(indexed)
            guard !ids.isEmpty else {
                throw APIProblem.invalidParameter("topic", "no indexed volume is in \(category) · \(subcategory)")
            }
            return .volumes(ids.sorted(), label: "\(category) · \(subcategory)")
        }
        if try query.single("subtopic") != nil { throw APIProblem.invalidParameter("subtopic", "is given with a topic") }
        if let ids = try query.list("volumes") {
            guard !ids.isEmpty else { throw APIProblem.invalidParameter("volumes", "a scope names at least one volume") }
            guard ids.count <= maximumScopeVolumes else {
                throw APIProblem.invalidParameter("volumes", "names \(ids.count) volumes, more than \(maximumScopeVolumes)")
            }
            for id in ids where resources.volume(id) == nil { throw APIProblem.volumeNotFound(id) }
            let label = try query.single("scopeLabel")
            return .volumes(Array(Set(ids)).sorted(), label: label?.isEmpty == true ? nil : label)
        }
        if try query.single("scopeLabel") != nil { throw APIProblem.invalidParameter("scopeLabel", "names a scope of volumes") }
        return .wholeCorpus
    }

    // MARK: The chart

    /// The chart `ask` asks for, as the view's `reloadData()` loads it for one committed term and its sections draw it.
    static func answer(_ ask: CorpusAnalyticsAsk, served: ServedIndex, resources: ServerResources) async throws -> CorpusAnalyticsAnswer {
        let service = served.analytics
        let term = ask.term
        let scope: Set<String>? = ask.scope.volumeIds.map(Set.init)
        // `reloadData()`, for one committed term: the totals, the per-volume breakdown, the occurrences when the
        // reader is looking at them and the term can be counted so, and the six axes' series.
        async let totalsYear = service.documentTotalsByYear(volumeIds: scope)
        async let totalsDecade = service.documentTotalsByDecade(volumeIds: scope)
        let yearVolumes = try await service.termFrequencyByYearAndVolume(term: term, volumeIds: scope)
        let availability = await service.occurrenceAvailability(for: term)
        var occurrenceYearVolumes: [YearVolumeFrequency] = []
        var occurrenceYears: [YearFrequency]?
        if ask.unit == .occurrences, availability.isAvailable {
            // The occurrence series come from a service of their own: the kit keys their cache as "occ:" and the
            // term, which a document term so spelt would meet in a shared one.
            occurrenceYearVolumes = try await served.occurrences.termOccurrencesByYearAndVolume(term: term, volumeIds: scope)
            occurrenceYears = try await served.occurrences.termOccurrencesByYear(term: term, volumeIds: scope)
        }
        async let years = service.termFrequencyByYear(term: term, volumeIds: scope)
        async let decades = service.termFrequencyByDecade(term: term, volumeIds: scope)
        async let months = service.termFrequencyByMonth(term: term, volumeIds: scope)
        async let days = service.termFrequencyByDay(term: term, volumeIds: scope)
        async let subseries = service.termFrequencyBySubseries(term: term, volumeIds: scope)
        async let volumes = service.termFrequencyByVolume(term: term, volumeIds: scope)
        let loaded = CorpusAnalyticsView.Loaded(
            years: try await years, decades: try await decades, months: try await months, days: try await days,
            subseries: try await subseries, volumes: try await volumes, yearVolumes: yearVolumes,
            occurrenceYears: occurrenceYears, occurrenceYearVolumes: occurrenceYearVolumes,
            totalsByYear: try await totalsYear, totalsByDecade: try await totalsDecade, availability: availability)
        let view = CorpusAnalyticsView(ask: ask, loaded: loaded, corpusMaxYear: corpusMaxYear(resources.manifest),
                                       indexedVolumeIds: served.indexedVolumeIds,
                                       volumeTitle: { volumeTitle($0, resources: resources) },
                                       sourceTitle: { sourceTitle($0, resources: resources) })
        return view.answer()
    }

    /// Search's count of the documents the hand-off link opens, and the dispersion beside it (#1756), over the
    /// served index's search, which a hand-off's search runs without the reader's own writing.
    static func documents(_ ask: CorpusAnalyticsAsk, served: ServedIndex, resources: ServerResources) async throws -> CorpusAnalyticsDocuments {
        let maxYear = corpusMaxYear(resources.manifest)
        let parameters = AnalyticsSearchHandoff.parameters(
            term: ask.term, axis: ask.axis, startYear: ask.start, endYear: ask.end,
            yearsNarrowed: CorpusAnalyticsView.yearRangeIsCustom(start: ask.start, end: ask.end, corpusMaxYear: maxYear),
            scopeVolumeIds: ask.scope.volumeIds)
        // No search is counted for a term the chart refuses (`handoffCountKey`): the link is hidden then.
        guard CorpusAnalyticsService.unsupportedExactTerms(in: ask.term).isEmpty else {
            throw APIProblem(.notFound, code: "NOTHING_TO_COUNT", detail: "The chart refuses \(ask.term), so its documents are not counted.")
        }
        let match = try await AnalyticsSearchHandoff.match(for: parameters, in: served.service)
        let dispersion = CorpusDispersion.make(volumeCounts: match.volumeCounts, indexedVolumeCount: served.indexedVolumeIds.count)
        return CorpusAnalyticsDocuments(
            count: match.count, linkTitle: CorpusAnalyticsView.handoffLinkTitle(count: match.count),
            dispersion: dispersion.map(CorpusAnalyticsView.dispersionLine),
            search: .init(keywords: parameters.keywords ?? ask.term, dateRangeEarliest: parameters.dateRange?.earliest,
                          dateRangeLatest: parameters.dateRange?.latest, volumeIds: parameters.volumeIds,
                          includeNotes: parameters.includeNotes, includeSummaries: parameters.includeSummaries))
    }

    // MARK: The context

    /// The corpus's years, the presets, the colours and the scope menu's corpus-wide items.
    static func context(served: ServedIndex, resources: ServerResources) async throws -> AnalyticsContext {
        let maxYear = corpusMaxYear(resources.manifest)
        let indexed = served.indexedVolumeIds
        let administrations = try await Blocking.run { resources.administrationProfiles?.administrations ?? [] }
        let presets = AnalyticsPresets.presets(from: administrations, corpusMaxYear: maxYear,
                                               currentYear: Calendar(identifier: .gregorian).component(.year, from: Date()))
        let chronology = ChronologyRoutes.defaultRange(resources.manifest)
        var topics: [AnalyticsContext.TopicCategory] = []
        if let resolved = detectedTopics(resources), !resolved.isEmpty {
            topics = ScopeFacets.narrowingCategories(resolvedByVolume: resolved).map { category in
                AnalyticsContext.TopicCategory(
                    label: category.label,
                    items: ScopeFacets.subCategoryCatalog(forCategory: category.label, resolvedByVolume: resolved).map { sub in
                        let profile = ScopeFacets.volumeIds(forCategory: sub.category, subcategory: sub.subcategory, resolvedByVolume: resolved)
                        let count = profile.intersection(indexed).count
                        return AnalyticsContext.TopicItem(
                            subcategory: sub.subcategory,
                            label: CorpusAnalyticsView.subjectFacetLabel(sub.subcategory, indexed: count, total: profile.count),
                            indexed: count, total: profile.count)
                    })
            }
        }
        return AnalyticsContext(
            floorYear: floorYear, corpusMaxYear: maxYear, earliestYear: earliestYear,
            chronologyFrom: chronology.from, chronologyTo: chronology.to,
            presets: presets.map { .init(label: AnalyticsPresets.label($0.profile.president, start: $0.start, end: $0.end),
                                         start: $0.start, end: $0.end) },
            colorCounts: Array(colorCounts), defaultColors: defaultColors, indexedVolumeCount: indexed.count,
            subseries: indexedSubseries(indexed).map { name in
                .init(name: name, volumes: volumes(inSubseries: name, indexed: indexed).map {
                    .init(id: $0, title: volumeTitle($0, resources: resources))
                })
            },
            topics: topics)
    }

    // MARK: The app's other rules

    /// The detected topics by volume the scope bars read: the document index's complete map, else the profiles'
    /// (`DocumentSubjectStore.shared?.subjectsByVolume ?? VolumeSubjectProfilesStore.shared?.resolvedByVolume`).
    static func detectedTopics(_ resources: ServerResources) -> [String: [VolumeSubjectProfiles.ResolvedSubject]]? {
        resources.documentSubjectIndex?.subjectsByVolume ?? resources.subjectProfiles.profiles?.resolvedByVolume
    }

    /// The distinct subseries of the indexed volumes, sorted (`AnalyticsScopeBar.indexedSubseries`).
    static func indexedSubseries(_ indexed: Set<String>) -> [String] {
        Set(indexed.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0) }).sorted()
    }

    /// The indexed volumes of a subseries, sorted (`AnalyticsScopeBar.volumes(inSubseries:)`,
    /// `AnalyticsView.indexedVolumeIds(forSubseries:)`).
    static func volumes(inSubseries subseries: String, indexed: Set<String>) -> [String] {
        indexed.filter { CorpusAnalyticsService.subseries(fromVolumeId: $0) == subseries }.sorted()
    }

    /// A volume's title from the catalogue, or its id (`AnalyticsView.volumeTitle`).
    static func volumeTitle(_ volumeId: String, resources: ServerResources) -> String {
        resources.volume(volumeId)?.title ?? volumeId
    }

    /// A source series' title: a volume's distilled label, or Other volumes (`AnalyticsView.sourceTitle`).
    static func sourceTitle(_ key: String, resources: ServerResources) -> String {
        if key == AnalyticsSourceColoring.otherSourceKey { return CorpusAnalyticsView.otherVolumes }
        let subseries = CorpusAnalyticsService.subseries(fromVolumeId: key) ?? ""
        let title = resources.volume(key)?.title ?? ""
        return VolumeLabels.distilledVolumeLabel(volumeId: key, subseries: subseries, title: title)
    }

    /// The corpus's last year: the Gregorian year of `ManifestStore.corpusDateRange.upperBound`, the latest
    /// subseries end year of the catalogue, 1992 for none.
    static func corpusMaxYear(_ entries: [VolumeManifestEntry]) -> Int {
        entries.compactMap { subseriesEndYear($0.subseries) }.max() ?? 1992
    }

    /// The corpus's first year: the earliest subseries start year, 1861 for none (`corpusDateRange.lowerBound`).
    static func corpusMinYear(_ entries: [VolumeManifestEntry]) -> Int {
        entries.compactMap { Int($0.subseries.prefix(4)) }.min() ?? 1861
    }

    /// A subseries's end year (`ManifestStore.subseriesEndYear(_:)`): `"1989-92"` → 1992, `"1899-01"` → 1901.
    static func subseriesEndYear(_ subseries: String) -> Int? {
        let parts = subseries.split(separator: "-", maxSplits: 1)
        guard let startPart = parts.first, startPart.count == 4, let start = Int(startPart) else {
            return nil
        }
        guard parts.count == 2 else { return start }   // bare single-year subseries
        let endPart = parts[1]
        if endPart.count == 4, let end = Int(endPart) { return end }
        if endPart.count == 2, let twoDigit = Int(endPart) {
            var end = (start / 100) * 100 + twoDigit
            if end < start { end += 100 }              // century rollover (e.g. 1899-01 → 1901)
            return end
        }
        return start
    }

    // MARK: The export

    /// The host the method block is written for: the server's name and version on its credit line, US English,
    /// the Gregorian calendar and the browser's time zone, as the method appendix is (`appendixHost`).
    static func host(timeZone: TimeZone) -> AnalyticsProvenance.Host {
        AnalyticsProvenance.Host(appVersion: "Light \(FRUSLightVersion.string)", locale: SearchItem.locale,
                                 calendar: Calendar(identifier: .gregorian), timeZone: timeZone)
    }

    /// The chart's statement (`AnalyticsView.exportProvenance`).
    static func provenance(_ ask: CorpusAnalyticsAsk, answer: CorpusAnalyticsAnswer, indexedVolumeCount: Int,
                           exportDate: Date) -> AnalyticsProvenance {
        let axis = ask.axis
        let normalizationApplies = CorpusAnalyticsView.normalizationApplies(axis)
        return AnalyticsProvenance(
            figureTitle: answer.figureTitle,
            terms: [ask.term],
            axisLabel: axis.pickerLabel,
            // The chip's name for a scope: the view passes its `scopeLabel`, which a hand-off may leave nil beside its
            // volumes, and the statement would then call a scoped chart the whole corpus; the chip says Selected volumes.
            scopeLabel: ask.scope.volumeIds == nil ? nil : answer.scope.label,
            indexedVolumeCount: indexedVolumeCount,
            // The categorical breakdowns ignore the range entirely — say so rather than implying it applied.
            yearRange: axis.isCategorical ? nil : ask.start...ask.end,
            valueMode: normalizationApplies
                ? (answer.values.isNormalized ? ask.normalization.pickerLabel : AnalyticsNormalizationMode.raw.pickerLabel)
                : nil,
            countingUnit: AnalyticsValueUnit(rawValue: answer.measure.effective)?.axisLabel,
            exportDate: exportDate)
    }

    /// The table as the kit's `ChartInspectorData`, whose CSV the method block heads.
    static func inspectorData(_ table: CorpusAnalyticsAnswer.Table) -> ChartInspectorData {
        ChartInspectorData(id: "corpus", title: table.title, columns: table.columns, rowCells: table.rows)
    }

    /// The export's file name (`AnalyticsExportDelivery.filenameStem(title:prefix:date:)`): the title's letters,
    /// digits, hyphens and underscores, spaces as hyphens, fitted beside the prefix and the day.
    static func filenameStem(title: String, prefix: String = "FRUS-Analytics", date: Date) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = title.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        var stem = String(cleaned)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "-")
        let stamp = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        // The prefix, the date, the two hyphens joining them, and the extension a caller appends.
        let extensionAllowance = 8
        let fitted = ExportFileName.fitting(
            stem, reserving: ExportFileName.length(of: prefix) + ExportFileName.length(of: stamp) + 2
                + extensionAllowance)
        if fitted.count < stem.count {
            stem = fitted
            while stem.hasSuffix("-") { stem.removeLast() }
        }
        if stem.isEmpty { stem = "chart" }
        return "\(prefix)-\(stem)-\(stamp)"
    }
}

// MARK: - The view's rules

/// What `AnalyticsView` computes between the service and its chart for one committed term, under its names,
/// over the series its `reloadData()` loaded.
struct CorpusAnalyticsView {
    /// The series `reloadData()` stores.
    struct Loaded {
        var years: [YearFrequency]
        var decades: [DecadeFrequency]
        var months: [MonthFrequency]
        var days: [DayFrequency]
        var subseries: [SubseriesFrequency]
        var volumes: [VolumeFrequency]
        var yearVolumes: [YearVolumeFrequency]
        /// The occurrences by year, loaded only when the reader asked for them and the term can be so counted.
        var occurrenceYears: [YearFrequency]?
        var occurrenceYearVolumes: [YearVolumeFrequency]
        var totalsByYear: [Int: Int]
        var totalsByDecade: [Int: Int]
        var availability: OccurrenceAvailability
    }

    let ask: CorpusAnalyticsAsk
    let loaded: Loaded
    let corpusMaxYear: Int
    let indexedVolumeIds: Set<String>
    let volumeTitle: (String) -> String
    let sourceTitle: (String) -> String

    static let otherVolumes = appWords("analytics.chart.source.other", "Other volumes")

    private var axis: AnalyticsChartAxis { ask.axis }
    private var yearRangeStart: Int { ask.start }
    private var yearRangeEnd: Int { ask.end }
    private var committedTerm: String { ask.term }

    // MARK: Gates

    /// `true` when the user has narrowed the range away from its default values.
    static func yearRangeIsCustom(start: Int, end: Int, corpusMaxYear: Int) -> Bool {
        start != 1861 || end != corpusMaxYear
    }

    var yearRangeIsCustom: Bool { Self.yearRangeIsCustom(start: yearRangeStart, end: yearRangeEnd, corpusMaxYear: corpusMaxYear) }

    /// The date-based By-Year / By-Decade axes, which have a per-period corpus denominator.
    static func normalizationApplies(_ chartAxis: AnalyticsChartAxis) -> Bool {
        chartAxis == .byYear || chartAxis == .byDecade
    }

    /// By Year and By Decade only, the axes with a per-period series the service can produce.
    static func measureApplies(_ chartAxis: AnalyticsChartAxis) -> Bool {
        chartAxis == .byYear || chartAxis == .byDecade
    }

    /// What this view's numbers actually count right now: documents whenever occurrences cannot be served.
    var valueUnit: AnalyticsValueUnit {
        guard ask.unit == .occurrences, Self.measureApplies(axis), loaded.availability.isAvailable
        else { return .documents }
        return .occurrences
    }

    /// `% of documents` plotting: the preference on, the axis supporting it, a chart on screen (always, here),
    /// and documents counted.
    var isNormalized: Bool {
        Self.normalizationApplies(axis) && valueUnit == .documents
            && ask.normalization == .percentOfDocuments
    }

    /// The plotted y-value for a raw `count` in `period`, or nil for a period with no denominator.
    func normalizedValue(count: Int, period: Int, totals: [Int: Int]) -> Double? {
        guard isNormalized else { return Double(count) }
        guard let total = totals[period], total > 0 else { return nil }
        return Double(count) / Double(total) * 100.0
    }

    // MARK: Series in the unit counted, and within the years

    /// The By-Year series in the active unit.
    var yearData: [YearFrequency] {
        valueUnit == .occurrences ? (loaded.occurrenceYears ?? []) : loaded.years
    }

    /// The By-Decade series in the active unit: occurrences bucketed from the year series (`decadeSeries`). The
    /// kit's `DecadeFrequency` keeps its initialiser internal (FRUS-Explorer#1906 left it so), so the view's sum is
    /// carried in a value of the server's own, with the same two fields.
    var decadeData: [Decade] {
        guard valueUnit == .occurrences else { return loaded.decades.map { Decade(decadeStart: $0.decadeStart, count: $0.count) } }
        var byDecade: [Int: Int] = [:]
        for entry in loaded.occurrenceYears ?? [] {
            byDecade[(entry.year / 10) * 10, default: 0] += entry.count
        }
        return byDecade
            .map { Decade(decadeStart: $0.key, count: $0.value) }
            .sorted { $0.decadeStart < $1.decadeStart }
    }

    /// A decade's count: a `DecadeFrequency`'s two fields.
    struct Decade: Equatable {
        let decadeStart: Int
        let count: Int
    }

    var filteredYearData: [YearFrequency] {
        guard !yearData.isEmpty else { return [] }
        return yearData.filter { $0.year >= yearRangeStart && $0.year <= yearRangeEnd }
    }

    var filteredDecadeData: [Decade] {
        guard !decadeData.isEmpty else { return [] }
        return decadeData.filter { d in
            let bucketEnd = d.decadeStart + 9
            return bucketEnd >= yearRangeStart && d.decadeStart <= yearRangeEnd
        }
    }

    var filteredMonthData: [MonthFrequency] {
        guard !loaded.months.isEmpty else { return [] }
        let cal = Calendar(identifier: .gregorian)
        return loaded.months.filter { m in
            let y = cal.component(.year, from: m.date)
            return y >= yearRangeStart && y <= yearRangeEnd
        }
    }

    var filteredDayData: [DayFrequency] {
        guard !loaded.days.isEmpty else { return [] }
        return loaded.days.filter { d in
            guard let y = d.year else { return false }
            return y >= yearRangeStart && y <= yearRangeEnd
        }
    }

    /// The per-(year, volume) series the bar segments are drawn from, following the Measure picker (#1305).
    var segmentSeries: [YearVolumeFrequency] {
        valueUnit == .occurrences ? loaded.occurrenceYearVolumes : loaded.yearVolumes
    }

    /// Every backing data array empty: the No Results state.
    var isAllResultDataEmpty: Bool {
        yearData.isEmpty
            && decadeData.isEmpty
            && loaded.months.isEmpty
            && loaded.days.isEmpty
            && loaded.subseries.isEmpty
            && loaded.volumes.isEmpty
    }

    /// The documents the chart plots on the active axis (`matchedDocumentCount`), documents whatever is plotted.
    var matchedDocumentCount: Int {
        switch axis {
        case .byYear:
            return loaded.years
                .filter { $0.year >= yearRangeStart && $0.year <= yearRangeEnd }
                .reduce(0) { $0 + $1.count }
        case .byDecade:
            return loaded.decades
                .filter { $0.decadeStart + 9 >= yearRangeStart && $0.decadeStart <= yearRangeEnd }
                .reduce(0) { $0 + $1.count }
        case .byMonth:     return filteredMonthData.reduce(0) { $0 + $1.count }
        case .byDay:       return filteredDayData.reduce(0) { $0 + $1.count }
        case .bySubseries: return loaded.subseries.reduce(0) { $0 + $1.count }
        case .byVolume:    return loaded.volumes.reduce(0) { $0 + $1.count }
        }
    }

    // MARK: Words

    /// The chart heading's quoted term: `"term"`, a phrase quoted once (`chartHeadingTerms`).
    var chartHeadingTerms: String { "\"\(QueryQuoting.quotable(committedTerm))\"" }

    /// The term as a sentence quotes it (`quotedTerm`).
    var quotedTerm: String { QueryQuoting.quotable(committedTerm) }

    /// The heading above the chart, by axis.
    var heading: String {
        switch axis {
        case .byYear:
            return appWords("analytics.chart.year.heading", "\(chartHeadingTerms) \u{2014} by Year")
        case .byDecade:
            return appWords("analytics.chart.decade.heading", "\(chartHeadingTerms) \u{2014} by Decade")
        case .byMonth:
            return appWords("analytics.chart.month.heading", "\(chartHeadingTerms) \u{2014} by Month")
        case .byDay:
            return appWords("analytics.chart.day.heading", "\(chartHeadingTerms) \u{2014} by Day")
        case .bySubseries:
            return appWords("analytics.chart.subseries.heading", "“\(quotedTerm)” \u{2014} by Subseries")
        case .byVolume:
            return appWords("analytics.chart.volume.heading", "“\(quotedTerm)” \u{2014} by Volume")
        }
    }

    /// The export's figure title: the quoted term and the active grouping (`exportFigureTitle`).
    var exportFigureTitle: String {
        "\(chartHeadingTerms) — \(axis.pickerLabel)"
    }

    /// The period column's header for the active axis (`exportPeriodColumn`).
    var exportPeriodColumn: String {
        switch axis {
        case .byYear:      return appWords("analytics.axis.year", "Year")
        case .byDecade:    return appWords("analytics.axis.decade", "Decade")
        case .byMonth:     return appWords("analytics.axis.month", "Month")
        case .byDay:       return appWords("analytics.axis.date", "Date")
        case .bySubseries: return appWords("analytics.axis.subseries", "Subseries")
        case .byVolume:    return appWords("analytics.axis.volume", "Volume")
        }
    }

    /// The value axis's title (`valueAxisLabel`).
    var valueAxisLabel: String {
        isNormalized
            ? AnalyticsValueUnit.axisLabel(unit: valueUnit, isNormalized: true)
            : AnalyticsValueUnit.axisLabel(unit: valueUnit, isNormalized: false)
    }

    /// A legend entry's total, in the unit the segments are counted in (`segmentLegendLabel`).
    func segmentLegendLabel(total: Int) -> String {
        valueUnit == .occurrences
            ? appWords("analytics.figure.legend.occurrences", "\(grouped(total)) mentions")
            : appWords("analytics.figure.legend.docs", "\(grouped(total)) docs")
    }

    /// The caption under a normalised chart (`normalizationCaption`).
    var normalizationCaption: String? {
        guard isNormalized else { return nil }
        return appWords("analytics.normalize.caption", "Share of indexed documents per period. Only downloaded, indexed volumes are counted, so this is a share of your local corpus, not the entire FRUS series.")
    }

    /// The occurrence notice: shown when occurrences were asked for, on an axis that offers them, and the term
    /// has no honest occurrence count (`occurrenceNotice`).
    var occurrenceNotice: String? {
        guard ask.unit == .occurrences, Self.measureApplies(axis), let reason = loaded.availability.reason else { return nil }
        return reason.explanation
    }

    /// The empty state for the `=` words the service refuses (`unsupportedExactTerms`, the exact-word state).
    static func exactUnsupported(_ unsupportedExactTerms: [String]) -> CorpusAnalyticsAnswer.Notice {
        CorpusAnalyticsAnswer.Notice(
            title: appWords("analytics.exactUnsupported.title", "Exact-Word Charting Isn’t Available"),
            detail: appWords("analytics.exactUnsupported.detail", "\(unsupportedExactTerms.map { "=\($0)" }.formatted(.list(type: .and).locale(SearchItem.locale))) can’t be charted: Analytics counts by word stem in the search index, so it cannot tell \"containment\" from \"container\". Remove the = to chart the stem, or use Search, whose exact-word filter re-reads the stored document text to keep only the exact word."))
    }

    /// No Results (`analytics.empty.*`).
    var empty: CorpusAnalyticsAnswer.Notice {
        CorpusAnalyticsAnswer.Notice(
            title: appWords("analytics.empty.title", "No Results"),
            detail: appWords("analytics.empty.detail", "No indexed documents match “\(quotedTerm)”."))
    }

    /// By Month's notice when no matching document has a month-level date (`noMonthDataNotice`).
    static let noMonthData = CorpusAnalyticsAnswer.Notice(
        title: appWords("analytics.month.empty.title", "No documents with month-level dates"),
        detail: appWords("analytics.month.empty.detail", "Matching documents are indexed with year-only dates. Switch to By Year or By Decade."))

    /// By Day's (`noDayDataNotice`).
    static let noDayData = CorpusAnalyticsAnswer.Notice(
        title: appWords("analytics.day.empty.title", "No documents with day-level dates"),
        detail: appWords("analytics.day.empty.detail", "Matching documents are indexed without full yyyy-MM-dd dates. Try By Month or By Year."))

    /// The link's words once Search has counted (`handoffLinkTitle`), "View 9,162 documents".
    static func handoffLinkTitle(count: Int) -> String {
        String(format: appWords("analytics.handoff.viewDocuments %@", "View %@"),
               CountCopy.documents(count, locale: SearchItem.locale))
    }

    /// The dispersion footnote's words (`dispersionLine`).
    static func dispersionLine(_ d: CorpusDispersion) -> String {
        let volumes = appWords("analytics.dispersion.volumes", "Spread across \(grouped(d.volumes)) of \(grouped(d.indexedVolumeCount)) indexed volumes")
        guard d.showsConcentration else { return volumes }
        let concentration = appWords("analytics.dispersion.concentration", "top 3 hold \(grouped(d.topThreePercent))%")
        return volumes + " · " + concentration
    }

    /// A detected topic's menu item (`subjectFacetItem`): "%@ (%lld of %lld indexed)", or "%@ — none indexed yet".
    static func subjectFacetLabel(_ baseLabel: String, indexed: Int, total: Int) -> String {
        indexed == 0
            ? String(format: appWords("analytics.scope.subject.none %@", "%@ — none indexed yet"), baseLabel)
            : String(format: appWords("analytics.scope.subject.indexed %@ %lld %lld", "%@ (%lld of %lld indexed)"),
                     baseLabel, Int64(indexed), Int64(total))
    }

    /// The scope chip's name for the scope (`AnalyticsScopeBar.currentLabel`).
    var scopeLabel: String {
        ask.scope.volumeIds == nil
            ? appWords("analytics.scope.wholeCorpus", "Whole corpus")
            : (ask.scope.label ?? appWords("analytics.scope.custom", "Selected volumes"))
    }

    // MARK: The table

    /// The data table behind the chart (`exportTable`), for the one committed term.
    var exportTable: ChartInspectorData {
        let term = committedTerm
        let points: [CorpusSeriesPoint]
        switch axis {
        case .byYear:
            points = filteredYearData.map {
                CorpusSeriesPoint(periodLabel: "\($0.year)", denominatorKey: $0.year, count: $0.count)
            }
        case .byDecade:
            points = filteredDecadeData.map {
                CorpusSeriesPoint(periodLabel: "\($0.decadeStart)s", denominatorKey: $0.decadeStart, count: $0.count)
            }
        case .byMonth:
            points = filteredMonthData.map {
                CorpusSeriesPoint(periodLabel: $0.label, denominatorKey: nil, count: $0.count)
            }
        case .byDay:
            points = filteredDayData.map {
                CorpusSeriesPoint(periodLabel: $0.label, denominatorKey: nil, count: $0.count)
            }
        case .bySubseries:
            points = loaded.subseries.map {
                CorpusSeriesPoint(periodLabel: $0.subseries, denominatorKey: nil, count: $0.count)
            }
        case .byVolume:
            points = loaded.volumes.map {
                CorpusSeriesPoint(periodLabel: volumeTitle($0.volumeId), denominatorKey: nil, count: $0.count)
            }
        }
        let totals: [Int: Int]
        switch axis {
        case .byYear:   totals = loaded.totalsByYear
        case .byDecade: totals = loaded.totalsByDecade
        default:        totals = [:]
        }
        return AnalyticsChartTables.corpusSeriesTable(
            id: "corpus.\(axis.rawValue)",
            title: exportFigureTitle,
            periodColumn: exportPeriodColumn,
            seriesByTerm: [(term: term, points: points)],
            totals: totals,
            isNormalized: isNormalized,
            unit: valueUnit,
            locale: SearchItem.locale)
    }

    // MARK: The answer

    func answer() -> CorpusAnalyticsAnswer {
        let exact = CorpusAnalyticsService.unsupportedExactTerms(in: committedTerm)
        let table = exportTable
        var answer = CorpusAnalyticsAnswer(
            term: committedTerm, axis: axis.rawValue, axisLabel: axis.pickerLabel, state: "chart",
            heading: heading, figureTitle: exportFigureTitle, valueAxisLabel: valueAxisLabel, periodLabel: exportPeriodColumn,
            measure: .init(chosen: ask.unit.rawValue, effective: valueUnit.rawValue, applies: Self.measureApplies(axis),
                           available: loaded.availability.isAvailable, reason: loaded.availability.reason?.explanation,
                           notice: occurrenceNotice),
            values: .init(chosen: ask.normalization.rawValue, applies: Self.normalizationApplies(axis),
                          enabled: valueUnit != .occurrences, isNormalized: isNormalized),
            years: .init(start: yearRangeStart, end: yearRangeEnd, isCustom: yearRangeIsCustom, applies: !axis.isCategorical),
            scope: .init(label: scopeLabel, volumeIds: ask.scope.volumeIds),
            colors: ask.colors, segments: [], series: [], fit: [], points: [], bars: [],
            matchedDocumentCount: matchedDocumentCount,
            table: .init(title: table.title, columns: table.columns, rows: table.rows.map(\.cells)))
        if !exact.isEmpty {
            // Ahead of No Results: this state has matches.
            let notice = Self.exactUnsupported(exact)
            answer.state = "exactUnsupported"
            answer.stateTitle = notice.title
            answer.stateDetail = notice.detail
            return answer
        }
        if isAllResultDataEmpty {
            answer.state = "empty"
            answer.stateTitle = empty.title
            answer.stateDetail = empty.detail
            return answer
        }
        switch axis {
        case .byYear, .byDecade:
            let decadeStride = axis == .byDecade
            let raw: [(period: Int, volumeId: String, count: Int)] = decadeStride
                ? segmentSeries.compactMap {
                    let decade = ($0.year / 10) * 10
                    guard decade + 9 >= yearRangeStart && decade <= yearRangeEnd else { return nil }
                    return (period: decade, volumeId: $0.volumeId, count: $0.count)
                }
                : segmentSeries
                    .filter { $0.year >= yearRangeStart && $0.year <= yearRangeEnd }
                    .map { (period: $0.year, volumeId: $0.volumeId, count: $0.count) }
            let coloring = AnalyticsSourceColoring.sourceColoring(raw, seriesCount: ask.colors)
            let totals = decadeStride ? loaded.totalsByDecade : loaded.totalsByYear
            answer.segments = coloring.segments.map {
                .init(period: $0.period, seriesKey: $0.seriesKey, count: $0.count,
                      plotted: normalizedValue(count: $0.count, period: $0.period, totals: totals))
            }
            answer.series = coloring.series.map {
                .init(key: $0.key, title: sourceTitle($0.key), total: $0.total, totalLabel: segmentLegendLabel(total: $0.total),
                      isOther: $0.key == AnalyticsSourceColoring.otherSourceKey)
            }
            let fitPoints: [(period: Int, count: Int)] = decadeStride
                ? filteredDecadeData.map { (period: $0.decadeStart, count: $0.count) }
                : filteredYearData.map { (period: $0.year, count: $0.count) }
            answer.fit = fitPoints.compactMap { point in
                normalizedValue(count: point.count, period: point.period, totals: totals).map { .init(period: point.period, value: $0) }
            }
            answer.normalizationCaption = normalizationCaption
            let all = decadeStride ? decadeData.reduce(0) { $0 + $1.count } : yearData.reduce(0) { $0 + $1.count }
            let filtered = decadeStride ? filteredDecadeData.reduce(0) { $0 + $1.count } : filteredYearData.reduce(0) { $0 + $1.count }
            footnotes(&answer, filtered: filtered, total: all)
        case .byMonth, .byDay:
            let isMonth = axis == .byMonth
            answer.points = isMonth
                ? filteredMonthData.map { .init(label: $0.label, count: $0.count) }
                : filteredDayData.map { .init(label: $0.label, count: $0.count) }
            if answer.points.isEmpty { answer.notice = isMonth ? Self.noMonthData : Self.noDayData }
            let all = isMonth ? loaded.months.reduce(0) { $0 + $1.count } : loaded.days.reduce(0) { $0 + $1.count }
            footnotes(&answer, filtered: answer.points.reduce(0) { $0 + $1.count }, total: all)
        case .bySubseries:
            answer.bars = loaded.subseries.map {
                .init(label: $0.subseries, count: $0.count,
                      volumeIds: CorpusAnalyticsRoutes.volumes(inSubseries: $0.subseries, indexed: indexedVolumeIds))
            }
            answer.footnote = valueUnit.matchedPhrase(count: loaded.subseries.reduce(0) { $0 + $1.count })
        case .byVolume:
            answer.bars = loaded.volumes.map { .init(label: volumeTitle($0.volumeId), count: $0.count, volumeIds: [$0.volumeId]) }
            answer.footnote = valueUnit.matchedPhrase(count: loaded.volumes.reduce(0) { $0 + $1.count })
        }
        return answer
    }

    /// The count under a time chart, and the full corpus's total beside it when the range is narrowed and
    /// the two differ (`totalsFootnote`).
    private func footnotes(_ answer: inout CorpusAnalyticsAnswer, filtered: Int, total: Int) {
        answer.footnote = valueUnit.matchedPhrase(count: filtered)
        if yearRangeIsCustom && total != filtered {
            answer.fullCorpusTotal = AnalyticsValueUnit.fullCorpusTotal(total)
        }
    }
}

// MARK: - The administration presets

/// `AdministrationPresetMenu.presets(from:corpusMaxYear:currentYear:)`, app code in a SwiftUI file, over the kit's
/// `AdministrationProfile`: the administrations whose term meets 1861 to the corpus's last year, clamped into it,
/// by presidency number.
enum AnalyticsPresets {
    /// The corpus floor year (the first FRUS volume, 1861).
    static let floorYear = 1861

    static func presets(
        from administrations: [AdministrationProfile],
        corpusMaxYear: Int,
        currentYear: Int
    ) -> [(profile: AdministrationProfile, start: Int, end: Int)] {
        administrations
            .compactMap { profile -> (AdministrationProfile, Int, Int)? in
                guard let start = Int(profile.start.prefix(4)) else { return nil }
                let end = max(start, profile.end.flatMap { Int($0.prefix(4)) } ?? currentYear)
                // Drop terms that never intersect the host's span (the zero-document
                // post-corpus administrations), then clamp straddlers into it.
                guard start <= corpusMaxYear && end >= floorYear else { return nil }
                let clampedStart = min(max(start, floorYear), corpusMaxYear)
                let clampedEnd = max(clampedStart, min(end, corpusMaxYear))
                return (profile, clampedStart, clampedEnd)
            }
            .sorted { $0.0.number < $1.0.number }
    }

    /// A preset's words, "%@ (%lld–%lld)".
    static func label(_ president: String, start: Int, end: Int) -> String {
        String(format: appWords("analytics.adminPreset.item %@ %lld %lld", "%@ (%lld–%lld)"),
               president, Int64(start), Int64(end))
    }
}

// MARK: - The app's words

/// The app's words for `key`: the English its `String(localized:defaultValue:)` gives, which is all the app
/// ships, held to the app's source by the parity tests. The kit's stand-in for `String(localized:)` on Linux is
/// its own, so the server writes the English itself, an integer grouped as the stand-in and Apple's
/// `String(localized:)` write the `%lld` it stands for (`grouped`).
func appWords(_ key: StaticString, _ text: String) -> String { text }

/// An integer as `String(localized:)` writes an interpolated one: grouped, in US English.
func grouped(_ value: Int) -> String { value.formatted(.number.locale(SearchItem.locale)) }
