// Chronology (PLAN's S24f), over the kit's fixture index imported as an export. Every range's sections, rows, chart,
// chips and summary through the API are the kit's `ChronologyGrouping` over the pipeline's rows, as the app's view
// model's `reload()` loads them, computed here with a host's own pipeline apart from the server: at each
// granularity, in either order, with the colours at their fewest, and with the legend's filter on. The labels are
// the kit's, in US English (FRUS-Explorer#1912), on Linux too.

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

@Suite struct ChronologyParityTests {
    struct Ask: CustomStringConvertible, Sendable {
        var from: String
        var to: String
        var newest = false
        var colors = 8
        var series: String?

        var query: String {
            var parts = ["from=\(from)", "to=\(to)", "order=\(newest ? "newest" : "oldest")", "colors=\(colors)"]
            if let series { parts.append("series=\(series)") }
            return parts.joined(separator: "&")
        }

        var description: String { query }
    }

    /// Ranges of each granularity over the three fixture volumes' years, the two either way round, and filtered.
    static let asks: [Ask] = [
        Ask(from: "1894-01-01", to: "1894-12-31"),
        Ask(from: "1894-12-31", to: "1894-01-01"),
        Ask(from: "1962-10-01", to: "1962-11-30"),
        Ask(from: "1962-10-01", to: "1962-11-30", newest: true),
        Ask(from: "1961-01-01", to: "1963-12-31"),
        Ask(from: "1961-01-01", to: "1963-12-31", colors: 6, series: "frus1961-63v06"),
        Ask(from: "1969-01-01", to: "1976-12-31"),
        Ask(from: "1860-01-01", to: "1999-12-31"),
        Ask(from: "1860-01-01", to: "1999-12-31", newest: true, colors: 6),
        Ask(from: "1860-01-01", to: "1999-12-31", series: "frus1894Nicaragua"),
        Ask(from: "1970-06-15", to: "1970-06-15"),
        // frus1961-63v06's d30 is dated 30 December 1961 to 18 January 1962: it begins before the first range, ends
        // after the second, and reaches past both ends of the third.
        Ask(from: "1962-01-01", to: "1962-03-31"),
        Ask(from: "1961-12-01", to: "1962-01-10"),
        Ask(from: "1962-01-05", to: "1962-01-10"),
        Ask(from: "1800-01-01", to: "1800-12-31"),
    ]

    /// The lines `reload()` and the view give for a range, over the host's own pipeline.
    static func kit(_ pipeline: IndexingPipeline, _ ask: Ask, catalogue: [VolumeManifestEntry]) async throws -> [String] {
        let cal = Calendar(identifier: .gregorian)
        let one = try #require(ChronologyRoutes.isoDayDate(ask.from))
        let other = try #require(ChronologyRoutes.isoDayDate(ask.to))
        let startDay = cal.startOfDay(for: min(one, other))
        let endDay = cal.startOfDay(for: max(one, other))
        let startISO = ChronologyGrouping.isoDay(startDay)
        let endISO = ChronologyGrouping.isoDay(endDay)
        let range = DateRange(earliest: startISO, latest: endISO)
        let rows = try await pipeline.documentsInDateRange(range, scopeVolumeIds: nil, ascending: !ask.newest,
                                                           limit: ChronologyGrouping.loadLimit)
        let (placed, spanning) = ChronologyGrouping.partition(rows)
        let (inRange, overflow) = ChronologyGrouping.splitOverflow(placed, startISO: startISO, endISO: endISO)
        let viewBucket = ChronologyGrouping.bucket(forDaysBetween: startDay, and: endDay, calendar: cal)
        // Each section labelled by the kit in US English, at its own granularity, and each bucket with its section's label.
        let groups = ChronologyGrouping.group(inRange, viewBucket: viewBucket, ascending: !ask.newest, locale: Locale(identifier: "en_US"))
        let chart = ChronologyGrouping.makeChart(from: groups, maxSeries: ask.colors)
        let top = Set(chart.series.map(\.key).filter { $0 != chronologyOtherSeriesKey })
        func shown(_ row: ChronologyRow) -> Bool {
            guard let selected = ask.series else { return true }
            return selected == chronologyOtherSeriesKey ? !top.contains(row.volumeId) : row.volumeId == selected
        }
        var lines = ["range \(startISO) \(endISO) \(viewBucket)",
                     "domain \(ChronologyGrouping.isoDay(ChronologyGrouping.startOfBucket(startDay, bucket: viewBucket, calendar: cal))) "
                        + ChronologyGrouping.isoDay(ChronologyGrouping.endOfBucket(endDay, bucket: viewBucket, calendar: cal)),
                     "summary \(CountCopy.documents(inRange.count, locale: Locale(identifier: "en_US")))"]
        for bucket in chart.buckets {
            lines.append("bucket \(bucket.bucketKey) \(bucket.label) " + bucket.segments.map { "\($0.seriesKey)=\($0.count)" }.joined(separator: " "))
        }
        for series in chart.series { lines.append("series \(series.key) \(series.total)") }
        for group in groups {
            let kept = group.rows.filter(shown)
            guard !kept.isEmpty else { continue }
            let volumes = Set(kept.map(\.volumeId)).count
            let subseries = Set(kept.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0.volumeId) }).count
            let notes = kept.filter(\.isEditorialNote).count
            lines.append("group \(group.bucketKey) \(group.granularity) \(kept.count) \(volumes) \(notes) \(group.displayLabel) | "
                         + ChronologyViewRules.aggregateLine(volumes: volumes, subseries: subseries, editorialNotes: notes))
            lines += kept.map { Self.rowLine($0, span: nil) }
        }
        let spanningShown = spanning.sorted { $0.dateISO < $1.dateISO }.filter(shown)
        if !spanningShown.isEmpty {
            lines.append("spanning \(ChronologyGrouping.spanningChipTitle(spanningShown.count, locale: Locale(identifier: "en_US")))")
            lines += spanningShown.map { row in
                // The span's years, the app's `spanLabel`.
                let start = String(row.dateISO.prefix(4))
                let end = row.dateISOMax.map { String($0.prefix(4)) } ?? start
                return Self.rowLine(row, span: start == end ? start : "\(start)–\(end)")
            }
        }
        let overflowShown = overflow.sorted { $0.dateISO < $1.dateISO }.filter(shown)
        if !overflowShown.isEmpty {
            let counts = ChronologyGrouping.overflowCounts(overflowShown, startISO: startISO, endISO: endISO, locale: Locale(identifier: "en_US"))
            lines.append("overflow \(counts.chipTitle) \(counts.chipBreakdown)")
            lines += overflowShown.map { row in
                // The directions, the app's `overflowDirectionLabel`.
                let direction = ChronologyGrouping.overflowDirection(row, startISO: startISO, endISO: endISO)
                var parts: [String] = []
                if direction.leading { parts.append("begins \(row.dateISO.prefix(4)) · before range") }
                if direction.trailing { parts.append("ends \((row.dateISOMax ?? row.dateISO).prefix(4)) · after range") }
                return Self.rowLine(row, span: parts.joined(separator: " · "))
            }
        }
        return lines
    }

    /// A row's line: its key, its snippet (`ChronologyRowView.snippet`: the summary, else the head, else the id), its
    /// approximate mark and its span or directions.
    static func rowLine(_ row: ChronologyRow, span: String?) -> String {
        let summary = row.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let snippet = summary.isEmpty ? (row.header.isEmpty ? row.documentId : row.header) : (row.summary ?? "")
        return "row \(row.id) | \(snippet) | \(row.certainty == .approximate) | \(span ?? "-")"
    }

    /// The same lines, of the API's answer.
    static func api(_ answer: ChronologyAnswer) -> [String] {
        var lines = ["range \(answer.from) \(answer.to) \(answer.granularity)", "domain \(answer.domainFrom) \(answer.domainTo)",
                     "summary \(answer.summary)"]
        for bucket in answer.buckets {
            lines.append("bucket \(bucket.key) \(bucket.label) " + bucket.segments.map { "\($0.seriesKey)=\($0.count)" }.joined(separator: " "))
        }
        for series in answer.series { lines.append("series \(series.key) \(series.total)") }
        for group in answer.groups {
            let volumes = Set(group.rows.map(\.volumeId)).count
            let notes = group.rows.filter(\.isEditorialNote).count
            let granularity = group.key.count == 4 ? "year" : group.key.count == 7 ? "month" : "day"
            lines.append("group \(group.key) \(granularity) \(group.count) \(volumes) \(notes) \(group.label) | \(group.aggregate)")
            lines += group.rows.map(Self.rowLine)
        }
        if let spanning = answer.spanning {
            lines.append("spanning \(spanning.chipTitle)")
            lines += spanning.rows.map(Self.rowLine)
        }
        if let overflow = answer.overflow {
            lines.append("overflow \(overflow.chipTitle) \(overflow.chipBreakdown ?? "")")
            lines += overflow.rows.map(Self.rowLine)
        }
        return lines
    }

    /// An answer's row as `rowLine` writes the kit's.
    static func rowLine(_ row: ChronologyAnswer.Row) -> String {
        "row \(row.volumeId)/\(row.documentId) | \(row.snippet) | \(row.approximate) | \(row.spanLabel ?? "-")"
    }

    @Test func everyRangesChronologyIsTheKits() async throws {
        let built = try await FixtureIndex.value()
        let resources = try IndexingResources.loading(fromDirectory: ServedFixture.resources)
        let store = try FTS5Store(readingDatabaseAt: built.copy)
        let pipeline = try IndexingPipeline(readingIndexAt: built.copy, fts5Store: store, resources: resources,
                                            volumesDirectory: Repository.layout.tei)
        let catalogue = try FixedVolumeCatalogue(contentsOf: ServedFixture.resources.appendingPathComponent("manifest.json")).citableEntries
        let asks = Self.asks
        let read = try await ServedFixture.run { client, _ in
            var read: [ChronologyAnswer] = []
            for ask in asks {
                let response = try await client.execute(uri: "/api/v1/chronology?\(ask.query)", method: .get)
                guard response.status == .ok else { throw APIParityError("\(ask): \(response.status.code) \(String(buffer: response.body))") }
                read.append(try ServedFixture.decode(ChronologyAnswer.self, response))
            }
            return read
        }
        var tally = (days: 0, months: 0, years: 0, spanning: 0, overflow: 0, filtered: 0, empty: 0, approximate: 0)
        for (ask, answer) in zip(asks, read) {
            let kit = try await Self.kit(pipeline, ask, catalogue: catalogue)
            let api = Self.api(answer)
            #expect(api == kit, "\(ask): \(CorpusAnalyticsParityTests.difference(api, kit))")
            switch answer.granularity {
            case "day": tally.days += 1
            case "month": tally.months += 1
            default: tally.years += 1
            }
            if answer.spanning != nil { tally.spanning += 1 }
            if answer.overflow != nil { tally.overflow += 1 }
            if answer.filter != nil { tally.filtered += 1 }
            if answer.state == "noDocuments" { tally.empty += 1 }
            if answer.groups.contains(where: { $0.rows.contains(where: \.approximate) }) { tally.approximate += 1 }
            // The fixtures never reach the cap of 5,000.
            #expect(!answer.isCapped && !answer.chartShowsFullDistribution && answer.totalShown == answer.groups.reduce(0) { $0 + $1.count }
                    || answer.filter != nil, "\(ask)")
            // Each series' title is the kit's distilled label of the catalogue's volume.
            for series in answer.series where !series.isOther {
                let entry = catalogue.first { $0.volumeId == series.key }
                #expect(series.title == VolumeLabels.distilledVolumeLabel(volumeId: series.key, subseries: entry?.subseries ?? "",
                                                                          title: entry?.title ?? series.key))
            }
        }
        #expect(tally.days > 0 && tally.months > 0 && tally.years > 0 && tally.spanning > 0 && tally.overflow > 0, "\(tally)")
        #expect(tally.filtered > 0 && tally.empty > 0 && tally.approximate > 0, "\(tally)")
    }

    /// The labels are the kit's, written in US English (FRUS-Explorer#1912) on Linux too, where the process's locale is
    /// World English and the kit wrote "15 February 1969" until it took one: through the server's own assembly, a day's
    /// section, its bucket and its table row "February 15, 1969", a month's "February 1969" and a year's "1969". Each
    /// bucket's first day is the answer's own.
    @Test func theLabelsAreTheKitsInUSEnglish() throws {
        let resources = try ServerResources.load(from: ServedFixture.resources)
        let calendar = Calendar(identifier: .gregorian)
        let row = ChronologyRow(volumeId: "frus1969-76v01", documentId: "d1", header: "1. Minutes", dateline: nil, summary: nil,
                                dateISO: "1969-02-15", dateISOMax: nil, precision: .day, certainty: .exact, isEditorialNote: false,
                                isFrontMatter: false, documentNumber: "1")
        // A day's range is a year at most, a month's eight years at most (`dayGroupingMaxDays`, `monthGroupingMaxDays`).
        let ranges = [("1969-02-01", "1969-02-28", "day", "1969-02-15", "February 15, 1969", "1969-02-15"),
                      ("1968-01-01", "1970-12-31", "month", "1969-02", "February 1969", "1969-02-01"),
                      ("1960-01-01", "1979-12-31", "year", "1969", "1969", "1969-01-01")]
        for (from, to, granularity, key, label, firstDay) in ranges {
            let start = try #require(ChronologyRoutes.isoDayDate(from))
            let end = try #require(ChronologyRoutes.isoDayDate(to))
            let answer = ChronologyRoutes.assemble(ChronologyAsk(start: start, end: end), rows: [row], counts: [],
                                                   startDay: calendar.startOfDay(for: start), endDay: calendar.startOfDay(for: end),
                                                   resources: resources)
            #expect(answer.granularity == granularity && answer.groups.map(\.key) == [key], "\(from) to \(to)")
            #expect(answer.groups.map(\.label) == [label] && answer.buckets.map(\.label) == [label], "\(from) to \(to)")
            #expect(answer.table.rows.map { $0.first ?? "" } == [label] && answer.buckets.map(\.date) == [firstDay], "\(from) to \(to)")
        }
    }
}
