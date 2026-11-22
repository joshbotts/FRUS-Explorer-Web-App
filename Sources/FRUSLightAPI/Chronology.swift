// Chronology (PLAN's S24f): the documents of the served index dated within a range, as the app's `ChronologyView`
// lists them, loaded as its view model's `reload()` loads them: the pipeline's `documentsInDateRange`, at most
// `ChronologyGrouping.loadLimit` (5,000) rows; the spanning documents apart (`partition`), then those whose dates
// reach past the range (`splitOverflow`); the range's granularity (`bucket(forDaysBetween:and:calendar:)`), its
// sections (`group`), the chart's domain, and the distribution chart from the sections, or, when the list is
// capped, from the aggregate counts (`dateBucketVolumeCounts`, `makeChart(fromCounts:viewBucket:maxSeries:)`), with
// the true total. Every rule is the kit's `ChronologyGrouping` (FRUS-Explorer#1899), compiled from the submodule.
// The view's own rules are mirrored here and held to the app's source by `ChronologyParityTests`: the default
// range, the legend's filter of the list (`rowMatchesFilter`, `displayedGroups`), the summary line, the span and
// direction labels, a section's aggregate line (`ChronologyAggregateText`), the series' titles and the words. The
// kit writes a section's and a bar's label in the locale it is given (FRUS-Explorer#1912), `SearchItem.locale`,
// US English as the browser app's dates are, where it wrote the process's, World English on Linux. A row's
// summary is its reader's, read from the rows of the user the request searches as in the store the served index
// attaches, or the index's own for no one (FRUS-Explorer#1927), as the app reads its reader's from its index.
//
// The hover magnifier is the Mac's alone, and the word cloud for the range waits for the Word Cloud (PLAN's S24i).
// The chart's table and its CSV with the kit's method block, and its figure, are the web's own: the app's
// Chronology exports nothing.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// A range's documents and its chart, as the app's Chronology shows them.
public struct ChronologyAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// The range loaded, as whole days (`loadedStartISO`, `loadedEndISO`), and its order.
    public var from: String
    public var to: String
    public var ascending: Bool
    /// The range's granularity: `day`, `month` or `year`.
    public var granularity: String
    /// The chart's domain, the range rounded out to whole buckets, as ISO days, first and last.
    public var domainFrom: String
    public var domainTo: String
    /// `noDocuments`, the view's empty state, or `loaded`.
    public var state: String
    /// The placed documents shown, or the counts' true total when the chart shows the whole range.
    public var totalShown: Int
    public var isCapped: Bool
    public var chartShowsFullDistribution: Bool
    /// The line above the list, "1,204 documents", with what the cap leaves out.
    public var summary: String
    /// The chart's buckets and its legend's series, with the colours' count.
    public var buckets: [Bucket]
    public var series: [Series]
    public var colors: Int
    /// The legend's filter of the list, when one is on, and its banner.
    public var filter: Filter?
    /// The sections, each its rows; the spanning documents and those reaching past the range, apart.
    public var groups: [Group]
    public var spanning: Apart?
    public var overflow: Apart?
    /// The chart's table, the web's own: each bucket's documents by series.
    public var table: CorpusAnalyticsAnswer.Table

    public struct Bucket: Codable, Equatable, Sendable {
        public var key: String
        public var label: String
        /// The bucket's first day, ISO.
        public var date: String
        public var segments: [Segment]
        public var total: Int
    }

    public struct Segment: Codable, Equatable, Sendable {
        public var seriesKey: String
        public var count: Int
    }

    public struct Series: Codable, Equatable, Sendable {
        public var key: String
        public var title: String
        public var total: Int
        /// "1,204 documents", for the legend entry's name.
        public var totalPhrase: String
        public var isOther: Bool
    }

    public struct Filter: Codable, Equatable, Sendable {
        public var key: String
        public var title: String
        /// "Showing … only".
        public var banner: String
    }

    public struct Group: Codable, Equatable, Sendable {
        public var key: String
        public var label: String
        public var count: Int
        /// "2 volumes · 1 subseries · 3 editorial notes".
        public var aggregate: String
        /// "Show all 30 documents on this date", for a section past the dense threshold.
        public var showAll: String?
        public var rows: [Row]
    }

    /// The spanning documents, or those whose dates reach past the range, with their chip and section's words.
    public struct Apart: Codable, Equatable, Sendable {
        public var chipTitle: String
        public var chipBreakdown: String?
        public var chipAccessibilityLabel: String
        public var header: String
        public var footer: String
        public var rows: [Row]
    }

    public struct Row: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// The summary, else the head, else the id (`ChronologyRowView.snippet`).
        public var snippet: String
        public var volumeTitle: String
        public var dateline: String?
        /// A spanning row's years, or an overflow row's directions, shown in the dateline's place.
        public var spanLabel: String?
        public var approximate: Bool
        public var isEditorialNote: Bool
        public var isFrontMatter: Bool
    }
}

/// What a Chronology request asks: the range, the order, the colours and the legend's filter.
struct ChronologyAsk: Sendable, Equatable {
    var start: Date
    var end: Date
    var ascending = true
    var colors = CorpusAnalyticsRoutes.defaultColors
    var series: String?
}

enum ChronologyRoutes {
    /// `ChronologyView.denseThreshold`: the rows a section shows before Show all.
    static let denseThreshold = 25
    static let parameters: Set<String> = ["from", "to", "order", "colors", "series"]

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources,
                    users: SearchUsers) {
        router.get("/api/v1/chronology") { request, context -> ChronologyAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters)
            let ask = try ask(query, resources: resources)
            let served = try await provider.served()
            let summaries = try await users.summarySource(for: request, context: context, served: served)
            let answer = try await load(ask, pipeline: served.pipeline, summaries: summaries, resources: resources)
            withExtendedLifetime(served) {}
            return answer
        }
        // The chart's table and figure read no row's summary, so the export and the plate read the index's.
        router.get("/api/v1/chronology/export") { request, _ -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters.union(["timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let ask = try ask(query, resources: resources)
            let served = try await provider.served()
            let answer = try await load(ask, pipeline: served.pipeline, summaries: .index, resources: resources)
            let now = Date()
            let provenance = provenance(answer, indexedVolumeCount: served.indexedVolumeIds.count, exportDate: now)
            withExtendedLifetime(served) {}
            guard !answer.buckets.isEmpty else {
                throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "No document of the range is placed on the chart.")
            }
            let csv = CorpusAnalyticsRoutes.inspectorData(answer.table)
                .provenancedCSV(provenance, for: CorpusAnalyticsRoutes.host(timeZone: timeZone))
            return AnalyticsFigures.csv(csv, name: CorpusAnalyticsRoutes.filenameStem(title: provenance.figureTitle, date: now))
        }
        router.get("/api/v1/chronology/plate") { request, _ -> AnalyticsPlate in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters.union(["timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let ask = try ask(query, resources: resources)
            let served = try await provider.served()
            let answer = try await load(ask, pipeline: served.pipeline, summaries: .index, resources: resources)
            let now = Date()
            let provenance = provenance(answer, indexedVolumeCount: served.indexedVolumeIds.count, exportDate: now)
            withExtendedLifetime(served) {}
            guard !answer.buckets.isEmpty else {
                throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "No document of the range is placed on the chart.")
            }
            return AnalyticsPlate(provenance, host: CorpusAnalyticsRoutes.host(timeZone: timeZone), date: now)
        }
    }

    /// The request's range, two ISO days, either first, as the view model takes its two pickers' dates; its
    /// order, its colours and the legend's filter, each checked.
    static func ask(_ query: FormQuery, resources: ServerResources) throws -> ChronologyAsk {
        func day(_ name: String) throws -> Date {
            guard let value = try query.single(name) else { throw APIProblem.invalidParameter(name, "a range needs from and to") }
            guard let date = isoDayDate(value) else {
                throw APIProblem.invalidParameter(name, "must be a day as yyyy-MM-dd, not \(value)")
            }
            return date
        }
        var ask = ChronologyAsk(start: try day("from"), end: try day("to"))
        switch try query.single("order") {
        case nil, "oldest": ask.ascending = true
        case "newest": ask.ascending = false
        case let order?: throw APIProblem.invalidParameter("order", "must be oldest or newest, not \(order)")
        }
        ask.colors = try query.integer("colors", in: CorpusAnalyticsRoutes.colorCounts, default: CorpusAnalyticsRoutes.defaultColors)
        if let series = try query.single("series") {
            guard series == chronologyOtherSeriesKey || resources.volume(series) != nil else {
                throw APIProblem.invalidParameter("series", "\(series) is neither a volume nor \(chronologyOtherSeriesKey)")
            }
            ask.series = series
        }
        return ask
    }

    /// A day `yyyy-MM-dd` at its start in the server's calendar, as a picker's date is a moment of that day;
    /// nil for any other text or a day the calendar has not.
    static func isoDayDate(_ text: String) -> Date? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard text.utf8.count == 10, parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCIIDigitCharacter) }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]), year >= 1 else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.dateComponents([.year, .month, .day], from: date) == DateComponents(year: year, month: month, day: day)
        else { return nil }
        return date
    }

    /// The range the view opens on, the corpus's last year (`seedDefaultsAndApply`): from a year before the
    /// corpus's end, 31 December of the year before its last, to that end, as ISO days.
    static func defaultRange(_ entries: [VolumeManifestEntry]) -> (from: String, to: String) {
        let cal = Calendar(identifier: .gregorian)
        let upper = corpusYearEnd(CorpusAnalyticsRoutes.corpusMaxYear(entries))
        let lower = corpusYearStart(CorpusAnalyticsRoutes.corpusMinYear(entries))
        let start = cal.date(byAdding: .year, value: -1, to: upper) ?? lower
        return (ChronologyGrouping.isoDay(start), ChronologyGrouping.isoDay(upper))
    }

    /// 1 January of a year in the Gregorian calendar (`ManifestStore.corpusYearStart`).
    static func corpusYearStart(_ year: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = 1; c.day = 1
        return Calendar(identifier: .gregorian).date(from: c) ?? .distantPast
    }

    /// 31 December of a year in the Gregorian calendar (`ManifestStore.corpusYearEnd`).
    static func corpusYearEnd(_ year: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = 12; c.day = 31
        return Calendar(identifier: .gregorian).date(from: c) ?? .distantFuture
    }

    // MARK: Loading

    /// The range's documents and chart, as `reload()` loads them, with the legend's filter applied to the list, and
    /// each row's summary read from `summaries`.
    static func load(_ ask: ChronologyAsk, pipeline: IndexingPipeline, summaries: SearchUserSource,
                     resources: ServerResources) async throws -> ChronologyAnswer {
        let cal = Calendar(identifier: .gregorian)
        // Normalize the bounds to whole days so the inclusive end day is captured.
        let startDay = cal.startOfDay(for: min(ask.start, ask.end))
        let endDay = cal.startOfDay(for: max(ask.start, ask.end))
        let startISO = ChronologyGrouping.isoDay(startDay)
        let endISO = ChronologyGrouping.isoDay(endDay)
        let range = DateRange(earliest: startISO, latest: endISO)

        let rows = try await pipeline.documentsInDateRange(range, scopeVolumeIds: nil, ascending: ask.ascending,
                                                           limit: ChronologyGrouping.loadLimit, userSource: summaries)
        let isCapped = rows.count >= ChronologyGrouping.loadLimit
        let viewBucket = ChronologyGrouping.bucket(forDaysBetween: startDay, and: endDay, calendar: cal)
        // The list is truncated to `loadLimit`, but the distribution chart reflects the whole range: from an aggregate
        // count (no row materialisation), as `reload()` takes it.
        let counts = isCapped ? ((try? await pipeline.dateBucketVolumeCounts(range, bucket: viewBucket, scopeVolumeIds: nil)) ?? []) : []
        return assemble(ask, rows: rows, counts: counts, startDay: startDay, endDay: endDay, resources: resources)
    }

    /// The answer from the rows `documentsInDateRange` gave and, for a capped list, the aggregate counts, as
    /// `reload()` makes its state of them, with the legend's filter applied to the list: apart from the pipeline, so a
    /// test reaches the capped path, which the fixtures' 393 documents cannot.
    static func assemble(_ ask: ChronologyAsk, rows: [ChronologyRow], counts: [(bucketKey: String, volumeId: String, count: Int)],
                         startDay: Date, endDay: Date, resources: ServerResources) -> ChronologyAnswer {
        let cal = Calendar(identifier: .gregorian)
        let startISO = ChronologyGrouping.isoDay(startDay)
        let endISO = ChronologyGrouping.isoDay(endDay)
        let isCapped = rows.count >= ChronologyGrouping.loadLimit
        let (placed, spanning) = ChronologyGrouping.partition(rows)
        let spanningRows = spanning.sorted { $0.dateISO < $1.dateISO }
        let (inRange, overflow) = ChronologyGrouping.splitOverflow(placed, startISO: startISO, endISO: endISO)
        let overflowRows = overflow.sorted { $0.dateISO < $1.dateISO }
        var totalShown = inRange.count

        let viewBucket = ChronologyGrouping.bucket(forDaysBetween: startDay, and: endDay, calendar: cal)
        let domainStart = ChronologyGrouping.startOfBucket(startDay, bucket: viewBucket, calendar: cal)
        let domainEnd = ChronologyGrouping.endOfBucket(endDay, bucket: viewBucket, calendar: cal)
        // Each section labelled at its own granularity, in the reader's locale, and each bucket of a chart from the
        // sections with its section's label.
        let groups = ChronologyGrouping.group(inRange, viewBucket: viewBucket, ascending: ask.ascending, locale: SearchItem.locale)

        var chart: (buckets: [ChronologyChartBucket], series: [ChronologyChartSeries])
        var full = false
        if isCapped {
            if !counts.isEmpty {
                // Each bucket of the counts labelled at the view's granularity, at which they are keyed.
                chart = ChronologyGrouping.makeChart(fromCounts: counts, viewBucket: viewBucket, maxSeries: ask.colors,
                                                     locale: SearchItem.locale)
                totalShown = counts.reduce(0) { $0 + $1.count }
                full = true
            } else {
                // Defensive fallback: keep the row-derived chart if the aggregate query returned nothing.
                chart = ChronologyGrouping.makeChart(from: groups, maxSeries: ask.colors)
            }
        } else {
            chart = ChronologyGrouping.makeChart(from: groups, maxSeries: ask.colors)
        }

        let view = ChronologyViewRules(seriesKeys: chart.series.map(\.key), selected: ask.series, resources: resources)
        let displayedGroups = view.displayedGroups(groups)
        let displayedSpanning = spanningRows.filter(view.rowMatchesFilter)
        let displayedOverflow = overflowRows.filter(view.rowMatchesFilter)

        var answer = ChronologyAnswer(
            from: startISO, to: endISO, ascending: ask.ascending, granularity: "\(viewBucket)",
            domainFrom: ChronologyGrouping.isoDay(domainStart), domainTo: ChronologyGrouping.isoDay(domainEnd),
            state: groups.isEmpty && spanningRows.isEmpty && overflowRows.isEmpty ? "noDocuments" : "loaded",
            totalShown: totalShown, isCapped: isCapped, chartShowsFullDistribution: full,
            summary: ChronologyViewRules.summaryLine(totalShown: totalShown, isCapped: isCapped, chartShowsFullDistribution: full),
            buckets: chart.buckets.map { bucket in
                ChronologyAnswer.Bucket(
                    key: bucket.bucketKey,
                    label: bucket.label,
                    date: firstDay(ofBucketKey: bucket.bucketKey),
                    segments: bucket.segments.map { .init(seriesKey: $0.seriesKey, count: $0.count) },
                    total: bucket.total)
            },
            series: chart.series.map {
                .init(key: $0.key, title: view.seriesTitle($0.key), total: $0.total,
                      totalPhrase: CountCopy.documents($0.total, locale: SearchItem.locale),
                      isOther: $0.key == chronologyOtherSeriesKey)
            },
            colors: ask.colors,
            filter: ask.series.map { .init(key: $0, title: view.seriesTitle($0), banner: ChronologyViewRules.banner(view.seriesTitle($0))) },
            groups: displayedGroups.map { group in
                ChronologyAnswer.Group(
                    key: group.bucketKey,
                    label: group.displayLabel,
                    count: group.count,
                    aggregate: ChronologyViewRules.aggregateLine(volumes: group.volumeCount, subseries: group.subseriesCount,
                                                                 editorialNotes: group.editorialNoteCount),
                    showAll: group.count > denseThreshold ? ChronologyViewRules.showAll(group.count) : nil,
                    rows: group.rows.map { view.row($0) })
            },
            table: CorpusAnalyticsAnswer.Table(title: "", columns: [], rows: []))
        if !displayedSpanning.isEmpty {
            answer.spanning = ChronologyAnswer.Apart(
                chipTitle: ChronologyGrouping.spanningChipTitle(displayedSpanning.count, locale: SearchItem.locale),
                chipBreakdown: nil,
                chipAccessibilityLabel: ChronologyGrouping.spanningChipAccessibilityLabel(displayedSpanning.count, locale: SearchItem.locale),
                header: ChronologyGrouping.spanningSectionHeader,
                footer: ChronologyViewRules.spanningFooter,
                rows: displayedSpanning.map { view.row($0, spanLabel: ChronologyViewRules.spanLabel($0)) })
        }
        if !displayedOverflow.isEmpty {
            let counts = ChronologyGrouping.overflowCounts(displayedOverflow, startISO: startISO, endISO: endISO, locale: SearchItem.locale)
            answer.overflow = ChronologyAnswer.Apart(
                chipTitle: counts.chipTitle, chipBreakdown: counts.chipBreakdown,
                chipAccessibilityLabel: counts.chipAccessibilityLabel,
                header: ChronologyViewRules.overflowHeader, footer: ChronologyViewRules.overflowFooter,
                rows: displayedOverflow.map {
                    view.row($0, spanLabel: ChronologyViewRules.overflowDirectionLabel($0, startISO: startISO, endISO: endISO))
                })
        }
        answer.table = table(answer)
        return answer
    }

    /// A bucket's first day as an ISO day, the answer's own: `1969` → `1969-01-01`, `1969-02` → `1969-02-01`.
    static func firstDay(ofBucketKey key: String) -> String {
        switch key.count {
        case 4: return key + "-01-01"
        case 7: return key + "-01"
        default: return key
        }
    }

    // MARK: The chart's table and statement, the web's own

    /// The chart's table: a row for each bucket's series, in the chart's order, with the axis names the app's
    /// chart gives its values (Date, Volume, Documents).
    static func table(_ answer: ChronologyAnswer) -> CorpusAnalyticsAnswer.Table {
        let titles = Dictionary(answer.series.map { ($0.key, $0.title) }, uniquingKeysWith: { first, _ in first })
        let order = Dictionary(answer.series.enumerated().map { ($0.element.key, $0.offset) }, uniquingKeysWith: { first, _ in first })
        var rows: [[String]] = []
        for bucket in answer.buckets {
            for segment in bucket.segments.sorted(by: { (order[$0.seriesKey] ?? .max) < (order[$1.seriesKey] ?? .max) }) {
                rows.append([bucket.label, titles[segment.seriesKey] ?? segment.seriesKey, "\(segment.count)"])
            }
        }
        return .init(title: figureTitle(answer), columns: [ChronologyViewRules.chartX, ChronologyViewRules.chartSeries,
                                                          ChronologyViewRules.chartY], rows: rows)
    }

    /// The figure's title: "Chronology, 1969-01-01 to 1969-12-31".
    static func figureTitle(_ answer: ChronologyAnswer) -> String {
        "\(ChronologyViewRules.title), \(answer.from) to \(answer.to)"
    }

    /// The chart's statement, written by the kit's method block: the documents placed on the chart, by the
    /// range's granularity, with the app's Chronology words for how its dates work, what it lists apart and
    /// what it leaves out, as its caveats.
    static func provenance(_ answer: ChronologyAnswer, indexedVolumeCount: Int, exportDate: Date) -> AnalyticsProvenance {
        let axis: AnalyticsChartAxis = answer.granularity == "day" ? .byDay : answer.granularity == "month" ? .byMonth : .byYear
        var caveats = [ChronologyViewRules.spanningFooter, ChronologyViewRules.overflowFooter, ChronologyViewRules.undatedNote]
        if answer.isCapped { caveats.append(ChronologyViewRules.capDetail) }
        return AnalyticsProvenance(
            figureTitle: figureTitle(answer), terms: [], axisLabel: axis.pickerLabel, scopeLabel: nil,
            indexedVolumeCount: indexedVolumeCount,
            yearRange: (Int(answer.from.prefix(4)) ?? 1)...(Int(answer.to.prefix(4)) ?? 1),
            countingUnit: AnalyticsValueUnit.documents.axisLabel,
            datingRule: ChronologyViewRules.datesDetail, extraCaveats: caveats, exportDate: exportDate)
    }
}

// MARK: - The view's rules

/// What `ChronologyView` decides between the view model and the screen, under its names.
struct ChronologyViewRules {
    /// The chart's series keys, in the legend's order, and the legend's filter.
    let seriesKeys: [String]
    let selected: String?
    let resources: ServerResources

    /// Volume IDs that have their own coloured series (everything not folded into "Other").
    var topSeriesKeys: Set<String> {
        Set(seriesKeys.filter { $0 != chronologyOtherSeriesKey })
    }

    /// Whether a row passes the active legend filter (always `true` when no filter is set).
    func rowMatchesFilter(_ row: ChronologyRow) -> Bool {
        guard let selected else { return true }
        if selected == chronologyOtherSeriesKey { return !topSeriesKeys.contains(row.volumeId) }
        return row.volumeId == selected
    }

    /// Placed date groups after the legend filter: groups left empty are dropped, and each group's counts are
    /// recomputed from the surviving rows.
    func displayedGroups(_ groups: [ChronologyDateGroup]) -> [ChronologyDateGroup] {
        guard selected != nil else { return groups }
        return groups.compactMap { group in
            let rows = group.rows.filter(rowMatchesFilter)
            guard !rows.isEmpty else { return nil }
            let subseries = Set(rows.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0.volumeId) })
            return ChronologyDateGroup(
                bucketKey: group.bucketKey,
                granularity: group.granularity,
                sortDate: group.sortDate,
                displayLabel: group.displayLabel,
                rows: rows,
                volumeCount: Set(rows.map(\.volumeId)).count,
                subseriesCount: subseries.count,
                editorialNoteCount: rows.filter(\.isEditorialNote).count
            )
        }
    }

    /// A series' title: a volume's distilled label, or Other volumes (`seriesTitle`, `distilledVolumeLabel`).
    func seriesTitle(_ key: String) -> String {
        if key == chronologyOtherSeriesKey { return Self.other }
        let entry = resources.volume(key)
        return VolumeLabels.distilledVolumeLabel(volumeId: key, subseries: entry?.subseries ?? "", title: entry?.title ?? key)
    }

    /// A volume's title from the catalogue, or its id (`volumeTitle`).
    func volumeTitle(_ volumeId: String) -> String {
        resources.volume(volumeId)?.title ?? volumeId
    }

    /// A row as `ChronologyRowView` draws it.
    func row(_ row: ChronologyRow, spanLabel: String? = nil) -> ChronologyAnswer.Row {
        ChronologyAnswer.Row(
            volumeId: row.volumeId, documentId: row.documentId, snippet: Self.snippet(row), volumeTitle: volumeTitle(row.volumeId),
            dateline: row.dateline, spanLabel: spanLabel, approximate: row.certainty == .approximate,
            isEditorialNote: row.isEditorialNote, isFrontMatter: row.isFrontMatter)
    }

    /// Prefer the generated summary; fall back to the document header (`ChronologyRowView.snippet`).
    static func snippet(_ row: ChronologyRow) -> String {
        if let summary = row.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }
        return row.header.isEmpty ? row.documentId : row.header
    }

    /// Year–year label for a spanning row, e.g. "1952–1975" (`spanLabel`).
    static func spanLabel(_ row: ChronologyRow) -> String {
        let start = String(row.dateISO.prefix(4))
        let end = row.dateISOMax.map { String($0.prefix(4)) } ?? start
        return start == end ? start : "\(start)\u{2013}\(end)"
    }

    /// Direction annotation for an overflow row, e.g. "begins 1961 · before range" (`overflowDirectionLabel`).
    static func overflowDirectionLabel(_ row: ChronologyRow, startISO: String, endISO: String) -> String {
        let dir = ChronologyGrouping.overflowDirection(row, startISO: startISO, endISO: endISO)
        var parts: [String] = []
        if dir.leading {
            parts.append(String(format: appWords("chronology.overflow.begins %@", "begins %@ · before range"),
                                String(row.dateISO.prefix(4))))
        }
        if dir.trailing {
            let end = row.dateISOMax.map { String($0.prefix(4)) } ?? String(row.dateISO.prefix(4))
            parts.append(String(format: appWords("chronology.overflow.ends %@", "ends %@ · after range"), end))
        }
        return parts.joined(separator: " \u{00b7} ")
    }

    /// The line above the list (`summaryLine`).
    static func summaryLine(totalShown: Int, isCapped: Bool, chartShowsFullDistribution: Bool) -> String {
        // #1422: through `CountCopy`, like the chips below — it printed ungrouped, and "1 documents".
        let base = CountCopy.documents(totalShown, locale: SearchItem.locale)
        if chartShowsFullDistribution {
            return base + " " + appWords(
                "chronology.summary.chartFull",
                "(chart shows all; list shows the first \(grouped(ChronologyGrouping.loadLimit)) — narrow the range to browse them)")
        }
        return isCapped
            ? base + " " + appWords("chronology.summary.capped",
                                    "(showing the first \(grouped(ChronologyGrouping.loadLimit)) — narrow the range)")
            : base
    }

    /// A dense section's expander: "Show all 30 documents on this date".
    static func showAll(_ count: Int) -> String {
        String(format: appWords("chronology.showAll %@", "Show all %@ on this date"),
               CountCopy.documents(count, locale: SearchItem.locale))
    }

    /// The per-day summary line under a date header (`ChronologyAggregateText.line`).
    static func aggregateLine(volumes: Int, subseries: Int, editorialNotes: Int) -> String {
        var parts: [String] = []
        parts.append(appWords("chronology.agg.volumes.v2",
                              "\(grouped(volumes)) volume\(volumes == 1 ? "" : "s")"))
        parts.append(CountCopy.phrase(subseries,
                                      one: appWords("chronology.agg.subseries.one", "%@ subseries"),
                                      many: appWords("chronology.agg.subseries.many", "%@ subseries"),
                                      locale: SearchItem.locale))
        if editorialNotes > 0 {
            parts.append(appWords("chronology.agg.editorial.v2",
                                  "\(grouped(editorialNotes)) editorial note\(editorialNotes == 1 ? "" : "s")"))
        }
        return parts.joined(separator: " · ")
    }

    /// The legend filter's banner, "Showing %@ only".
    static func banner(_ title: String) -> String {
        String(format: appWords("chronology.filter.active %@", "Showing %@ only"), title)
    }

    static let title = appWords("chronology.title", "Chronology")
    static let other = appWords("chronology.chart.other", "Other volumes")
    static let chartX = appWords("chronology.chart.x", "Date")
    static let chartY = appWords("chronology.chart.y", "Documents")
    static let chartSeries = appWords("chronology.chart.series", "Volume")
    static let spanningFooter = appWords(
        "chronology.spanning.footer",
        "These documents (mostly editorial notes) cover a span of dates rather than a single day, so they’re listed here instead of on the timeline.")
    static let overflowHeader = appWords("chronology.overflow.header", "Extends beyond this range")
    static let overflowFooter = appWords(
        "chronology.overflow.footer",
        "These documents overlap your range but their dates are imprecise enough to reach before or after it, so they’re listed here rather than placed on the chart.")
    static let undatedNote = appWords("chronology.undated.note", "Documents without a machine-readable date are not shown.")
    static let datesDetail = appWords(
        "chronology.info.dates.detail",
        "Each document sits at its TEI date, and is shown no more precisely than its source supports — with the editor’s annotated precision (day/month/year) and certainty (exact vs. approximate) preserved.")
    static let capDetail = appWords(
        "chronology.info.cap.detail",
        "The document list is capped at 5,000, but the chart still reflects the whole range; the summary line reports the true total so you can narrow the range.")
}
