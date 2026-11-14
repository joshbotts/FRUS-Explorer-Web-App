// Corpus Analytics and Chronology (PLAN's S24f), over the kit's fixture index imported as an export. Every chart the
// API draws is held to the kit's own series over the same index, computed here by a host's own
// `CorpusAnalyticsService` and pipeline, apart from the server: By Year's and By Decade's stacked segments and their
// legend (`AnalyticsSourceColoring` over `termFrequencyByYearAndVolume`, or the occurrences'), the plotted shares
// over the kit's document totals, the fit line, By Month's and By Day's points, By Subseries' and By Volume's bars,
// the footnote, the table (`AnalyticsChartTables.corpusSeriesTable`) and the hand-off's count and dispersion
// (`AnalyticsSearchHandoff`, `CorpusDispersion`); and each CSV's method block, line for line, is the kit's
// `AnalyticsProvenance.csvPreambleLines(for:)` for the statement the app's view writes. Chronology's sections,
// rows, chart, chips and summary are the kit's `ChronologyGrouping` over the pipeline's rows. And the server's and
// the browser app's mirrors of the views' own rules and words, held to the app's source.

import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import FTS5Store
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSCoreKit
@testable import FRUSLightAPI

@Suite struct CorpusAnalyticsParityTests {
    /// What a host has at this pin, apart from the server: the fixture index's copy opened read-only, as a host
    /// opens it, with a `CorpusAnalyticsService` and a `SearchService` over it, and the catalogue.
    struct Host: @unchecked Sendable {
        let service: CorpusAnalyticsService
        let pipeline: IndexingPipeline
        let search: SearchService
        let catalogue: [VolumeManifestEntry]
        let indexed: Set<String>

        static func open() async throws -> Host {
            let built = try await FixtureIndex.value()
            let resources = try IndexingResources.loading(fromDirectory: ServedFixture.resources)
            let store = try FTS5Store(readingDatabaseAt: built.copy)
            let pipeline = try IndexingPipeline(readingIndexAt: built.copy, fts5Store: store, resources: resources,
                                                volumesDirectory: Repository.layout.tei)
            let catalogue = try FixedVolumeCatalogue(contentsOf: ServedFixture.resources.appendingPathComponent("manifest.json")).citableEntries
            return Host(service: CorpusAnalyticsService(fts5Store: store, pipeline: pipeline), pipeline: pipeline,
                        search: SearchService(fts5Store: store, pipeline: pipeline), catalogue: catalogue,
                        indexed: Set(ParityFixtures.volumes))
        }

        func title(_ volumeId: String) -> String {
            catalogue.first { $0.volumeId == volumeId }?.title ?? volumeId
        }
    }

    /// The terms the charts are asked for: words of each fixture volume, a phrase, an `OR`, an exclusion, an
    /// exact word the service refuses, a prefix and a word no volume holds.
    static let terms = ["Soviet", "Nicaragua", "Khrushchev", "treaty", "\"Soviet Union\"", "Cuba OR Berlin",
                        "president -Nicaragua", "=Soviet", "negotiat*", "zyzzyva"]

    /// One request's state: the axis, the measure and values chosen, the years and the scope.
    struct Ask: CustomStringConvertible, Sendable {
        var term: String
        var axis: AnalyticsChartAxis
        var unit: AnalyticsValueUnit = .documents
        var normalization: AnalyticsNormalizationMode = .raw
        var start = 1861
        var end: Int
        var volumes: [String]?
        var colors = 8
        /// A detected topic the request names, whose indexed volumes `volumes` holds, resolved here by the kit.
        var topic: (category: String, subcategory: String)?

        var query: String {
            var parts = ["term=\(Self.encoded(term))", "axis=\(axis.rawValue)", "measure=\(unit.rawValue)",
                         "values=\(normalization.rawValue)", "from=\(start)", "to=\(end)", "colors=\(colors)"]
            if let topic {
                parts += ["topic=\(Self.encoded(topic.category))", "subtopic=\(Self.encoded(topic.subcategory))"]
            } else {
                for volume in volumes ?? [] { parts.append("volumes=\(volume)") }
            }
            return parts.joined(separator: "&")
        }

        var description: String { query }

        static func encoded(_ text: String) -> String {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
        }
    }

    /// The requests: every term on every axis; By Year and By Decade with each measure and values, narrowed and
    /// not, scoped and not, and with the colours at their fewest.
    static func asks(corpusMaxYear: Int, topic: (category: String, subcategory: String, volumes: [String])? = nil) -> [Ask] {
        var asks: [Ask] = []
        // By Detected Topic: the scope menu's first item with indexed volumes, on the time views and a breakdown.
        if let topic {
            for term in ["Soviet", "treaty", "president -Nicaragua"] {
                for axis in [AnalyticsChartAxis.byYear, .byDecade, .byVolume] {
                    asks.append(Ask(term: term, axis: axis, end: corpusMaxYear, volumes: topic.volumes, topic: (topic.category, topic.subcategory)))
                }
                asks.append(Ask(term: term, axis: .byYear, normalization: .percentOfDocuments, start: 1950, end: 1975, volumes: topic.volumes,
                                colors: 6, topic: (topic.category, topic.subcategory)))
            }
        }
        for term in terms {
            for axis in AnalyticsChartAxis.allCases {
                asks.append(Ask(term: term, axis: axis, end: corpusMaxYear))
                asks.append(Ask(term: term, axis: axis, start: 1960, end: 1970))
            }
            for axis in [AnalyticsChartAxis.byYear, .byDecade] {
                for unit in AnalyticsValueUnit.allCases {
                    for normalization in AnalyticsNormalizationMode.allCases {
                        asks.append(Ask(term: term, axis: axis, unit: unit, normalization: normalization, end: corpusMaxYear))
                        asks.append(Ask(term: term, axis: axis, unit: unit, normalization: normalization, start: 1890, end: 1965,
                                        volumes: ["frus1961-63v06", "frus1894Nicaragua"], colors: 6))
                    }
                }
            }
        }
        return asks
    }

    /// What the kit's service gives for an ask, put in the API's shape by the view's rules, written here apart
    /// from the server's mirror: the lines a chart's answer must equal.
    static func kit(_ host: Host, _ ask: Ask, corpusMaxYear: Int) async throws -> [String] {
        let scope = ask.volumes.map(Set.init)
        let service = host.service
        let availability = await service.occurrenceAvailability(for: ask.term)
        let measured = ask.axis == .byYear || ask.axis == .byDecade
        let occurrences = ask.unit == .occurrences && measured && availability.isAvailable
        let normalized = measured && !occurrences && ask.normalization == .percentOfDocuments
        let years = occurrences
            ? try await service.termOccurrencesByYear(term: ask.term, volumeIds: scope)
            : try await service.termFrequencyByYear(term: ask.term, volumeIds: scope)
        var decades: [(decadeStart: Int, count: Int)] = []
        if occurrences {
            var byDecade: [Int: Int] = [:]
            for year in years { byDecade[year.year / 10 * 10, default: 0] += year.count }
            decades = byDecade.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        } else {
            decades = try await service.termFrequencyByDecade(term: ask.term, volumeIds: scope).map { ($0.decadeStart, $0.count) }
        }
        let segmentsByVolume = occurrences
            ? try await service.termOccurrencesByYearAndVolume(term: ask.term, volumeIds: scope)
            : try await service.termFrequencyByYearAndVolume(term: ask.term, volumeIds: scope)
        let allMonths = try await service.termFrequencyByMonth(term: ask.term, volumeIds: scope)
        let allDays = try await service.termFrequencyByDay(term: ask.term, volumeIds: scope)
        let months = allMonths.filter { (ask.start...ask.end).contains(Int($0.label.prefix(4)) ?? 0) }
        let days = allDays.filter { (ask.start...ask.end).contains(Int($0.label.prefix(4)) ?? 0) }
        let subseries = try await service.termFrequencyBySubseries(term: ask.term, volumeIds: scope)
        let volumes = try await service.termFrequencyByVolume(term: ask.term, volumeIds: scope)
        let totals = ask.axis == .byDecade
            ? try await service.documentTotalsByDecade(volumeIds: scope)
            : try await service.documentTotalsByYear(volumeIds: scope)
        let unit: AnalyticsValueUnit = occurrences ? .occurrences : .documents
        func plotted(_ count: Int, _ period: Int) -> Double? {
            guard normalized else { return Double(count) }
            guard let total = totals[period], total > 0 else { return nil }
            return Double(count) / Double(total) * 100
        }

        var lines: [String] = []
        if !CorpusAnalyticsService.unsupportedExactTerms(in: ask.term).isEmpty { return ["state exactUnsupported"] }
        let inYears = years.filter { $0.year >= ask.start && $0.year <= ask.end }
        let inDecades = decades.filter { $0.decadeStart + 9 >= ask.start && $0.decadeStart <= ask.end }
        // No Results: every series of the unit counted empty, the time views' before their years.
        if years.isEmpty && decades.isEmpty && allMonths.isEmpty && allDays.isEmpty && subseries.isEmpty && volumes.isEmpty {
            return ["state empty"]
        }
        lines.append("unit \(unit.rawValue) normalized \(normalized)")
        let quoted = QueryQuoting.quotable(ask.term)
        let names: [AnalyticsChartAxis: String] = [.byYear: "Year", .byDecade: "Decade", .byMonth: "Month", .byDay: "Day"]
        lines.append("heading " + (ask.axis.isCategorical ? "“\(quoted)” — by \(ask.axis == .bySubseries ? "Subseries" : "Volume")"
                                                       : "\"\(quoted)\" — by \(names[ask.axis] ?? "")"))
        lines.append("value axis \(AnalyticsValueUnit.axisLabel(unit: unit, isNormalized: normalized))")
        let narrowed = ask.start != 1861 || ask.end != corpusMaxYear
        func full(_ filtered: Int, _ all: Int) -> String {
            narrowed && all != filtered ? AnalyticsValueUnit.fullCorpusTotal(all) : "none"
        }
        let points: [CorpusSeriesPoint]
        switch ask.axis {
        case .byYear, .byDecade:
            let raw: [(period: Int, volumeId: String, count: Int)] = ask.axis == .byDecade
                ? segmentsByVolume.compactMap {
                    let decade = $0.year / 10 * 10
                    return decade + 9 >= ask.start && decade <= ask.end ? (decade, $0.volumeId, $0.count) : nil
                }
                : segmentsByVolume.filter { $0.year >= ask.start && $0.year <= ask.end }.map { ($0.year, $0.volumeId, $0.count) }
            let coloring = AnalyticsSourceColoring.sourceColoring(raw, seriesCount: ask.colors)
            for segment in coloring.segments {
                lines.append("segment \(segment.period) \(segment.seriesKey) \(segment.count) \(plotted(segment.count, segment.period).map(number) ?? "none")")
            }
            for series in coloring.series { lines.append("series \(series.key) \(series.total)") }
            let fit = ask.axis == .byDecade ? inDecades.map { ($0.decadeStart, $0.count) } : inYears.map { ($0.year, $0.count) }
            for (period, count) in fit { if let value = plotted(count, period) { lines.append("fit \(period) \(number(value))") } }
            let filtered = fit.reduce(0) { $0 + $1.1 }
            lines.append("footnote \(unit.matchedPhrase(count: filtered))")
            let all = ask.axis == .byDecade ? decades.reduce(0) { $0 + $1.count } : years.reduce(0) { $0 + $1.count }
            lines.append("full \(full(filtered, all))")
            points = ask.axis == .byDecade
                ? inDecades.map { CorpusSeriesPoint(periodLabel: "\($0.decadeStart)s", denominatorKey: $0.decadeStart, count: $0.count) }
                : inYears.map { CorpusSeriesPoint(periodLabel: "\($0.year)", denominatorKey: $0.year, count: $0.count) }
        case .byMonth, .byDay:
            let labelled = ask.axis == .byMonth ? months.map { ($0.label, $0.count) } : days.map { ($0.label, $0.count) }
            for (label, count) in labelled { lines.append("point \(label) \(count)") }
            if labelled.isEmpty {
                lines.append("notice " + (ask.axis == .byMonth ? "No documents with month-level dates" : "No documents with day-level dates"))
            }
            lines.append("footnote \(unit.matchedPhrase(count: labelled.reduce(0) { $0 + $1.1 }))")
            let all = ask.axis == .byMonth ? allMonths.reduce(0) { $0 + $1.count } : allDays.reduce(0) { $0 + $1.count }
            lines.append("full \(full(labelled.reduce(0) { $0 + $1.1 }, all))")
            points = labelled.map { CorpusSeriesPoint(periodLabel: $0.0, denominatorKey: nil, count: $0.1) }
        case .bySubseries:
            for row in subseries {
                let ids = host.indexed.filter { CorpusAnalyticsService.subseries(fromVolumeId: $0) == row.subseries }.sorted()
                lines.append("bar \(row.subseries) \(row.count) \(ids.joined(separator: ","))")
            }
            lines.append("footnote \(unit.matchedPhrase(count: subseries.reduce(0) { $0 + $1.count }))")
            lines.append("full none")
            points = subseries.map { CorpusSeriesPoint(periodLabel: $0.subseries, denominatorKey: nil, count: $0.count) }
        case .byVolume:
            for row in volumes { lines.append("bar \(host.title(row.volumeId)) \(row.count) \(row.volumeId)") }
            lines.append("footnote \(unit.matchedPhrase(count: volumes.reduce(0) { $0 + $1.count }))")
            lines.append("full none")
            points = volumes.map { CorpusSeriesPoint(periodLabel: host.title($0.volumeId), denominatorKey: nil, count: $0.count) }
        }
        let table = AnalyticsChartTables.corpusSeriesTable(
            id: "corpus", title: "", periodColumn: "", seriesByTerm: [(term: ask.term, points: points)],
            totals: ask.axis == .byYear || ask.axis == .byDecade ? totals : [:], isNormalized: normalized, unit: unit,
            locale: Locale(identifier: "en_US"))
        lines.append("columns \(table.columns.dropFirst(2).joined(separator: " | "))")
        for row in table.rows { lines.append("row \(row.cells.joined(separator: " | "))") }
        return lines
    }

    /// The same lines, of the API's answer.
    static func api(_ answer: CorpusAnalyticsAnswer) -> [String] {
        guard answer.state == "chart" else { return ["state \(answer.state)"] }
        var lines = ["unit \(answer.measure.effective) normalized \(answer.values.isNormalized)", "heading \(answer.heading)",
                     "value axis \(answer.valueAxisLabel)"]
        for segment in answer.segments {
            lines.append("segment \(segment.period) \(segment.seriesKey) \(segment.count) \(segment.plotted.map(number) ?? "none")")
        }
        for series in answer.series { lines.append("series \(series.key) \(series.total)") }
        for point in answer.fit { lines.append("fit \(point.period) \(number(point.value))") }
        for point in answer.points { lines.append("point \(point.label) \(point.count)") }
        if let notice = answer.notice { lines.append("notice \(notice.title)") }
        for bar in answer.bars { lines.append("bar \(bar.label) \(bar.count) \(bar.volumeIds.joined(separator: ","))") }
        lines.append("footnote \(answer.footnote ?? "")")
        lines.append("full \(answer.fullCorpusTotal ?? "none")")
        lines.append("columns \(answer.table.columns.dropFirst(2).joined(separator: " | "))")
        for row in answer.table.rows { lines.append("row \(row.joined(separator: " | "))") }
        return lines
    }

    static func number(_ value: Double) -> String { String(format: "%.9f", value) }

    /// The first line two lists differ at, for a failure's message.
    static func difference(_ api: [String], _ kit: [String]) -> String {
        for (index, pair) in zip(api, kit).enumerated() where pair.0 != pair.1 {
            return "line \(index): api \(pair.0) | kit \(pair.1)"
        }
        return "api \(api.count) lines, kit \(kit.count)"
    }

    /// Every chart the API draws for the fixtures is the kit's series, and its hand-off's count is Search's.
    @Test func everySeriesIsTheKits() async throws {
        let host = try await Host.open()
        let corpusMaxYear = CorpusAnalyticsRoutes.corpusMaxYear(host.catalogue)
        // The scope menu's first detected topic with a fixture volume, resolved by the kit's `ScopeFacets` over a host's
        // own copy of the document subject index, apart from the server's.
        let subjects = try #require(try IndexingResources.loading(fromDirectory: ServedFixture.resources).documentSubjects())
        let resolved = subjects.subjectsByVolume
        var topic: (category: String, subcategory: String, volumes: [String])?
        search: for category in ScopeFacets.narrowingCategories(resolvedByVolume: resolved) {
            for sub in ScopeFacets.subCategoryCatalog(forCategory: category.label, resolvedByVolume: resolved) {
                let ids = ScopeFacets.volumeIds(forCategory: sub.category, subcategory: sub.subcategory, resolvedByVolume: resolved)
                    .intersection(host.indexed)
                if !ids.isEmpty {
                    topic = (category.label, sub.subcategory, ids.sorted())
                    break search
                }
            }
        }
        let asks = Self.asks(corpusMaxYear: corpusMaxYear, topic: try #require(topic))
        let read = try await ServedFixture.run { client, _ in
            var read: [(CorpusAnalyticsAnswer, CorpusAnalyticsDocuments?)] = []
            for ask in asks {
                let response = try await client.execute(uri: "/api/v1/analytics/corpus?\(ask.query)", method: .get)
                guard response.status == .ok else { throw APIParityError("\(ask): \(response.status.code) \(String(buffer: response.body))") }
                let answer = try ServedFixture.decode(CorpusAnalyticsAnswer.self, response)
                let counted = try await client.execute(uri: "/api/v1/analytics/corpus/documents?\(ask.query)", method: .get)
                read.append((answer, counted.status == .ok ? try ServedFixture.decode(CorpusAnalyticsDocuments.self, counted) : nil))
            }
            return read
        }
        var tally = (charts: 0, shares: 0, occurrences: 0, folded: 0, exact: 0, empty: 0, notices: 0, topics: 0, totals: 0)
        for (ask, (answer, documents)) in zip(asks, read) {
            let kit = try await Self.kit(host, ask, corpusMaxYear: corpusMaxYear)
            let api = Self.api(answer)
            #expect(api == kit, "\(ask): \(Self.difference(api, kit))")
            switch answer.state {
            case "chart": tally.charts += 1
            case "exactUnsupported": tally.exact += 1
            default: tally.empty += 1
            }
            if answer.values.isNormalized { tally.shares += 1 }
            if answer.measure.effective == "occurrences" { tally.occurrences += 1 }
            if answer.series.contains(where: \.isOther) { tally.folded += 1 }
            if answer.measure.notice != nil { tally.notices += 1 }
            if answer.fullCorpusTotal != nil { tally.totals += 1 }
            if let named = ask.topic {
                #expect(answer.scope.label == "\(named.category) · \(named.subcategory)" && answer.scope.volumeIds == ask.volumes, "\(ask)")
                if answer.state == "chart" { tally.topics += 1 }
            }
            // The hand-off's count and dispersion are the kit's over a search the kit's hand-off makes.
            let parameters = AnalyticsSearchHandoff.parameters(
                term: ask.term, axis: ask.axis, startYear: ask.start, endYear: ask.end,
                yearsNarrowed: ask.start != 1861 || ask.end != corpusMaxYear, scopeVolumeIds: ask.volumes.map { Array(Set($0)).sorted() })
            if CorpusAnalyticsService.unsupportedExactTerms(in: ask.term).isEmpty {
                let match = try await AnalyticsSearchHandoff.match(for: parameters, in: host.search)
                let dispersion = CorpusDispersion.make(volumeCounts: match.volumeCounts, indexedVolumeCount: host.indexed.count)
                #expect(documents?.count == match.count, "\(ask)")
                #expect(documents?.linkTitle == "View \(CountCopy.documents(match.count, locale: Locale(identifier: "en_US")))", "\(ask)")
                #expect(documents?.dispersion == dispersion.map(CorpusAnalyticsView.dispersionLine), "\(ask)")
                #expect(documents?.search.keywords == ask.term && documents?.search.includeNotes == false
                        && documents?.search.includeSummaries == false
                        && documents?.search.dateRangeEarliest == parameters.dateRange?.earliest
                        && documents?.search.volumeIds == parameters.volumeIds, "\(ask)")
            } else {
                #expect(documents == nil, "no search is counted for \(ask.term)")
            }
        }
        // The comparison reached every kind of chart the fixtures give.
        #expect(tally.charts > 100 && tally.shares > 0 && tally.occurrences > 0 && tally.exact > 0 && tally.empty > 0, "\(tally)")
        // The fixtures hold three volumes, fewer than the fewest colours, so no chart folds a volume into Other volumes:
        // the folding is the kit's `AnalyticsSourceColoring`, which its own suites hold.
        #expect(tally.folded == 0 && tally.notices > 0 && tally.topics > 0 && tally.totals > 0, "\(tally)")
    }

    /// Each CSV's method block is the kit's, for the statement the app's view writes (`exportProvenance`), and its
    /// table the kit's `ChartInspectorData.csv`.
    @Test func everyCSVsPreambleIsTheKits() async throws {
        let host = try await Host.open()
        let corpusMaxYear = CorpusAnalyticsRoutes.corpusMaxYear(host.catalogue)
        let asks = [
            Ask(term: "Soviet", axis: .byYear, end: corpusMaxYear),
            Ask(term: "Soviet", axis: .byDecade, normalization: .percentOfDocuments, start: 1890, end: 1965,
                volumes: ["frus1961-63v06", "frus1894Nicaragua"]),
            Ask(term: "treaty", axis: .byYear, unit: .occurrences, end: corpusMaxYear),
            Ask(term: "\"Soviet Union\"", axis: .byYear, unit: .occurrences, end: corpusMaxYear),
            Ask(term: "Khrushchev", axis: .byMonth, start: 1961, end: 1963),
            Ask(term: "Nicaragua", axis: .bySubseries, end: corpusMaxYear),
            Ask(term: "Nicaragua", axis: .byVolume, start: 1900, end: 1950),
        ]
        let zone = "America/New_York"
        let timeZone = try #require(TimeZone(identifier: zone))
        let read = try await ServedFixture.run { client, _ in
            var read: [(String, CorpusAnalyticsAnswer, ClosedRange<Date>, String?)] = []
            for ask in asks {
                let answer = try ServedFixture.decode(CorpusAnalyticsAnswer.self,
                                                      try await client.execute(uri: "/api/v1/analytics/corpus?\(ask.query)", method: .get))
                let before = Date()
                let response = try await client.execute(uri: "/api/v1/analytics/corpus/export?\(ask.query)&timeZone=\(zone)", method: .get)
                let after = Date()
                #expect(response.status == .ok && response.headers[.contentType] == "text/csv; charset=utf-8", "\(ask)")
                read.append((String(buffer: response.body), answer, before...after, response.headers[.contentDisposition]))
            }
            return read
        }
        for (ask, (csv, answer, moments, disposition)) in zip(asks, read) {
            let unit: AnalyticsValueUnit = AnalyticsValueUnit(rawValue: answer.measure.effective) ?? .documents
            let measured = ask.axis == .byYear || ask.axis == .byDecade
            let scopeLabel = ask.volumes == nil ? nil : "Selected volumes"
            let title = "\"\(QueryQuoting.quotable(ask.term))\" — \(ask.axis.pickerLabel)"
            func preamble(_ date: Date) -> [String] {
                AnalyticsProvenance(
                    figureTitle: title, terms: [ask.term], axisLabel: ask.axis.pickerLabel, scopeLabel: scopeLabel,
                    indexedVolumeCount: ParityFixtures.volumes.count,
                    yearRange: ask.axis.isCategorical ? nil : ask.start...ask.end,
                    valueMode: measured ? (answer.values.isNormalized ? ask.normalization.pickerLabel : AnalyticsNormalizationMode.raw.pickerLabel) : nil,
                    countingUnit: unit.axisLabel, exportDate: date)
                    .csvPreambleLines(for: AnalyticsProvenance.Host(appVersion: "Light \(FRUSLightVersion.string)",
                                                                   locale: Locale(identifier: "en_US"),
                                                                   calendar: Calendar(identifier: .gregorian),
                                                                   timeZone: timeZone))
            }
            let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let written = Array(lines.prefix { $0.hasPrefix("#") })
            // The moment is the export's, between the request's start and end: either minute's rendering.
            #expect(written == preamble(moments.lowerBound) || written == preamble(moments.upperBound), "\(ask): \(written)")
            let table = ChartInspectorData(id: "corpus", title: answer.table.title, columns: answer.table.columns,
                                           rowCells: answer.table.rows)
            #expect(Array(lines.dropFirst(written.count)).joined(separator: "\n") == table.csv + "\n", "\(ask)")
            #expect(disposition?.hasPrefix("attachment; filename=\"FRUS-Analytics-") == true && disposition?.contains(".csv") == true,
                    "\(ask): \(disposition ?? "")")
        }
    }
}
