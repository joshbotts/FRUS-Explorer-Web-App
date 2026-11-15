// Corpus Analytics' and Chronology's rules (PLAN's S24f) over values the fixtures cannot give: a chart of more
// volumes than colours, whose rest fold into Other volumes; the legend's filter to Other volumes; and a range of more
// documents than Chronology's cap, whose chart is drawn from the aggregate counts with the true total, or from the rows
// when the counts give nothing.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@testable import FRUSCoreKit
@testable import FRUSLightAPI

@Suite struct AnalyticsRulesTests {
    /// Eight volumes' matches in 1962, the first the most, at six colours: five volumes and Other volumes.
    @Test func moreVolumesThanColoursFoldIntoOtherVolumes() throws {
        let resources = try TestResources.value()
        let volumes = (1...8).map { "frus1961-63v0\($0)" }
        let yearVolumes = volumes.enumerated().map { YearVolumeFrequency(year: 1962, volumeId: $0.element, count: 10 - $0.offset) }
        let total = yearVolumes.reduce(0) { $0 + $1.count }
        let loaded = CorpusAnalyticsView.Loaded(
            years: [YearFrequency(year: 1962, count: total)], decades: [DecadeFrequency(decadeStart: 1960, count: total)],
            months: [], days: [], subseries: [SubseriesFrequency(subseries: "1961-63", count: total)],
            volumes: volumes.map { VolumeFrequency(volumeId: $0, count: 1) }, yearVolumes: yearVolumes,
            occurrenceYears: nil, occurrenceYearVolumes: [], totalsByYear: [1962: 100], totalsByDecade: [1960: 100],
            availability: .available(stem: "treati"))
        let ask = CorpusAnalyticsAsk(term: "treaties", axis: .byYear, start: 1861, end: 1992, colors: 6)
        let view = CorpusAnalyticsView(ask: ask, loaded: loaded, corpusMaxYear: 1992, indexedVolumeIds: Set(volumes),
                                       volumeTitle: { CorpusAnalyticsRoutes.volumeTitle($0, resources: resources) },
                                       sourceTitle: { CorpusAnalyticsRoutes.sourceTitle($0, resources: resources) })
        let answer = view.answer()
        #expect(answer.series.map(\.key) == Array(volumes.prefix(5)) + ["__other__"])
        let other = try #require(answer.series.last)
        #expect(other.isOther && other.title == "Other volumes" && other.total == 5 + 4 + 3 && other.totalLabel == "12 docs")
        #expect(answer.series.dropLast().allSatisfy { !$0.isOther && $0.title.contains("1961-63") })
        #expect(answer.segments.first { $0.seriesKey == "__other__" }?.count == 12)
        #expect(answer.segments.reduce(0) { $0 + $1.count } == total && answer.footnote == "52 documents matched")
        // Seven colours fold two volumes; twelve fold none.
        let seven = CorpusAnalyticsView(ask: CorpusAnalyticsAsk(term: "treaties", start: 1861, end: 1992, colors: 7), loaded: loaded,
                                        corpusMaxYear: 1992, indexedVolumeIds: Set(volumes), volumeTitle: { $0 }, sourceTitle: { $0 }).answer()
        #expect(seven.series.count == 7 && seven.series.last?.total == 4 + 3)
        let twelve = CorpusAnalyticsView(ask: CorpusAnalyticsAsk(term: "treaties", start: 1861, end: 1992, colors: 12), loaded: loaded,
                                         corpusMaxYear: 1992, indexedVolumeIds: Set(volumes), volumeTitle: { $0 }, sourceTitle: { $0 }).answer()
        #expect(twelve.series.count == 8 && !twelve.series.contains(where: \.isOther))
    }

    static func row(_ volume: String, _ document: String, _ date: String, max: String? = nil, editorial: Bool = false) -> ChronologyRow {
        ChronologyRow(volumeId: volume, documentId: document, header: "\(document). Telegram", dateline: nil, summary: nil,
                      dateISO: date, dateISOMax: max, precision: .day, certainty: .exact, isEditorialNote: editorial,
                      isFrontMatter: false, documentNumber: nil)
    }

    /// The legend's Other volumes keeps the rows of every volume without a colour of its own (`rowMatchesFilter`).
    @Test func theOtherVolumesFilterKeepsTheFoldedVolumes() throws {
        let resources = try TestResources.value()
        let rules = ChronologyViewRules(seriesKeys: ["frus1961-63v06", "frus1894Nicaragua", chronologyOtherSeriesKey],
                                        selected: chronologyOtherSeriesKey, resources: resources)
        #expect(!rules.rowMatchesFilter(Self.row("frus1961-63v06", "d1", "1962-10-22")))
        #expect(rules.rowMatchesFilter(Self.row("frus1969-76v01", "d1", "1969-01-20")))
        #expect(rules.seriesTitle(chronologyOtherSeriesKey) == "Other volumes")
        #expect(ChronologyViewRules.banner(rules.seriesTitle(chronologyOtherSeriesKey)) == "Showing Other volumes only")
        // A section left with no row is dropped, and the others' counts are of the rows that stay.
        let groups = ChronologyGrouping.group([Self.row("frus1961-63v06", "d1", "1962-10-22"), Self.row("frus1969-76v01", "d2", "1962-10-22"),
                                               Self.row("frus1961-63v06", "d3", "1962-10-23")], viewBucket: .day, ascending: true)
        let shown = rules.displayedGroups(groups)
        #expect(shown.map(\.bucketKey) == ["1962-10-22"] && shown.first?.count == 1 && shown.first?.volumeCount == 1)
    }

    /// A range of more documents than the cap: the list holds the first 5,000, and the chart and the total come from
    /// the aggregate counts, as `reload()` takes them; with no counts, the chart is the rows'.
    @Test func aCappedRangesChartIsTheAggregateCounts() throws {
        let resources = try TestResources.value()
        let calendar = Calendar(identifier: .gregorian)
        let start = try #require(ChronologyRoutes.isoDayDate("1962-10-01"))
        let end = try #require(ChronologyRoutes.isoDayDate("1962-10-31"))
        let rows = (0..<ChronologyGrouping.loadLimit).map { index in
            Self.row(index % 3 == 0 ? "frus1961-63v06" : "frus1961-63v11", "d\(index)", String(format: "1962-10-%02d", 1 + index % 31))
        }
        let counts: [(bucketKey: String, volumeId: String, count: Int)] = (1...31).flatMap { day in
            [(String(format: "1962-10-%02d", day), "frus1961-63v06", 100), (String(format: "1962-10-%02d", day), "frus1961-63v11", 150)]
        }
        let ask = ChronologyAsk(start: start, end: end)
        let capped = ChronologyRoutes.assemble(ask, rows: rows, counts: counts, startDay: calendar.startOfDay(for: start),
                                               endDay: calendar.startOfDay(for: end), resources: resources)
        #expect(capped.isCapped && capped.chartShowsFullDistribution && capped.granularity == "day")
        #expect(capped.totalShown == 31 * 250)
        #expect(capped.summary == "7,750 documents (chart shows all; list shows the first 5,000 — narrow the range to browse them)")
        #expect(capped.buckets.count == 31 && capped.buckets.first?.key == "1962-10-01" && capped.buckets.first?.total == 250)
        #expect(capped.buckets.first?.label == "October 1, 1962" && capped.buckets.first?.date == "1962-10-01")
        #expect(capped.series.map(\.key) == ["frus1961-63v11", "frus1961-63v06"] && capped.series.map(\.total) == [31 * 150, 31 * 100])
        // The list is the rows', capped, in their sections.
        #expect(capped.groups.reduce(0) { $0 + $1.count } == ChronologyGrouping.loadLimit && capped.groups.count == 31)
        #expect(capped.groups.first?.showAll == "Show all \(capped.groups.first?.count ?? 0) documents on this date")
        // No counts: the chart is the rows', and the summary says the list is cut short.
        let fallback = ChronologyRoutes.assemble(ask, rows: rows, counts: [], startDay: calendar.startOfDay(for: start),
                                                 endDay: calendar.startOfDay(for: end), resources: resources)
        #expect(fallback.isCapped && !fallback.chartShowsFullDistribution && fallback.totalShown == ChronologyGrouping.loadLimit)
        #expect(fallback.summary == "5,000 documents (showing the first 5,000 — narrow the range)")
        #expect(fallback.buckets.reduce(0) { $0 + $1.total } == ChronologyGrouping.loadLimit)
    }
}
