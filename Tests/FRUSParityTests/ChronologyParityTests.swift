// Chronology (PLAN's S24f), over the kit's fixture index imported as an export. Every range's sections, rows, chart,
// chips and summary through the API are the kit's `ChronologyGrouping` over the pipeline's rows, as the app's view
// model's `reload()` loads them, computed here with a host's own pipeline apart from the server: at each
// granularity, in either order, with the colours at their fewest, and with the legend's filter on.

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
        let groups = ChronologyGrouping.group(inRange, viewBucket: viewBucket, ascending: !ask.newest)
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
            lines.append("bucket \(bucket.bucketKey) " + bucket.segments.map { "\($0.seriesKey)=\($0.count)" }.joined(separator: " "))
        }
        for series in chart.series { lines.append("series \(series.key) \(series.total)") }
        for group in groups {
            let kept = group.rows.filter(shown)
            guard !kept.isEmpty else { continue }
            lines.append("group \(group.bucketKey) \(group.granularity) \(kept.count) \(Set(kept.map(\.volumeId)).count) "
                         + "\(kept.filter(\.isEditorialNote).count)")
            lines += kept.map { "row \($0.id)" }
        }
        let spanningShown = spanning.sorted { $0.dateISO < $1.dateISO }.filter(shown)
        if !spanningShown.isEmpty {
            lines.append("spanning \(ChronologyGrouping.spanningChipTitle(spanningShown.count, locale: Locale(identifier: "en_US")))")
            lines += spanningShown.map { "row \($0.id)" }
        }
        let overflowShown = overflow.sorted { $0.dateISO < $1.dateISO }.filter(shown)
        if !overflowShown.isEmpty {
            let counts = ChronologyGrouping.overflowCounts(overflowShown, startISO: startISO, endISO: endISO, locale: Locale(identifier: "en_US"))
            lines.append("overflow \(counts.chipTitle) \(counts.chipBreakdown)")
            lines += overflowShown.map { "row \($0.id)" }
        }
        return lines
    }

    /// The same lines, of the API's answer.
    static func api(_ answer: ChronologyAnswer) -> [String] {
        var lines = ["range \(answer.from) \(answer.to) \(answer.granularity)", "domain \(answer.domainFrom) \(answer.domainTo)",
                     "summary \(answer.summary)"]
        for bucket in answer.buckets {
            lines.append("bucket \(bucket.key) " + bucket.segments.map { "\($0.seriesKey)=\($0.count)" }.joined(separator: " "))
        }
        for series in answer.series { lines.append("series \(series.key) \(series.total)") }
        for group in answer.groups {
            let volumes = Set(group.rows.map(\.volumeId)).count
            let notes = group.rows.filter(\.isEditorialNote).count
            let granularity = group.key.count == 4 ? "year" : group.key.count == 7 ? "month" : "day"
            lines.append("group \(group.key) \(granularity) \(group.count) \(volumes) \(notes)")
            lines += group.rows.map { "row \($0.volumeId)/\($0.documentId)" }
        }
        if let spanning = answer.spanning {
            lines.append("spanning \(spanning.chipTitle)")
            lines += spanning.rows.map { "row \($0.volumeId)/\($0.documentId)" }
        }
        if let overflow = answer.overflow {
            lines.append("overflow \(overflow.chipTitle) \(overflow.chipBreakdown ?? "")")
            lines += overflow.rows.map { "row \($0.volumeId)/\($0.documentId)" }
        }
        return lines
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
        #expect(tally.filtered > 0 && tally.empty > 0, "\(tally)")
    }

    /// The labels the server writes in US English are the kit's formats, and its first day is the kit's sort date.
    @Test func theLabelsAreTheKitsFormatsInUSEnglish() throws {
        #expect(ChronologyLabels.label(forBucketKey: "1969", granularity: .year) == "1969")
        #expect(ChronologyLabels.label(forBucketKey: "1969-02", granularity: .month) == "February 1969")
        #expect(ChronologyLabels.label(forBucketKey: "1969-02-03", granularity: .day) == "February 3, 1969")
        #expect(ChronologyLabels.label(forBucketKey: "1969-02-03", granularity: .year) == "1969")
        #expect(ChronologyLabels.firstDay(ofBucketKey: "1969") == "1969-01-01" && ChronologyLabels.firstDay(ofBucketKey: "1969-02") == "1969-02-01")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.kit("FRUSCoreKit/Chronology/ChronologyGrouping.swift"), holds: [
            "guard let date = sortDate(forBucketKey: key) else { return key } let f = DateFormatter() f.locale = .autoupdatingCurrent switch granularity { case .year: f.dateFormat = \"yyyy\" case .month: f.setLocalizedDateFormatFromTemplate(\"MMMM yyyy\") case .day: f.dateStyle = .long } return f.string(from: date)",
            "let parts = key.split(separator: \"-\").map { Int($0) } guard let year = parts.first ?? nil else { return nil } var comps = DateComponents() comps.year = year comps.month = parts.count > 1 ? parts[1] : 1 comps.day = parts.count > 2 ? parts[2] : 1 return Calendar(identifier: .gregorian).date(from: comps)",
        ], file: "ChronologyGrouping.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/Chronology.swift"), holds: [
            "guard let date = sortDate(forBucketKey: key) else { return key } let f = DateFormatter() f.locale = SearchItem.locale switch granularity { case .year: f.dateFormat = \"yyyy\" case .month: f.setLocalizedDateFormatFromTemplate(\"MMMM yyyy\") case .day: f.dateStyle = .long } return f.string(from: date)",
            "let parts = key.split(separator: \"-\").map { Int($0) } guard let year = parts.first ?? nil else { return nil } var comps = DateComponents() comps.year = year comps.month = parts.count > 1 ? parts[1] : 1 comps.day = parts.count > 2 ? parts[2] : 1 return Calendar(identifier: .gregorian).date(from: comps)",
        ], file: "Chronology.swift")
    }
}
