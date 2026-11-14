// Corpus Analytics' and Chronology's mirrors (PLAN's S24f): what the app's views decide between the kit and the
// screen, which the server's CorpusAnalytics.swift and Chronology.swift and the browser app's analyticsRules.ts and
// screens mirror, held line by line to the app's source, and the app's words, each where the app's source writes it
// under its key, and where the server or copy.ts writes it. A change upstream to one of these lines fails here, and
// says which mirror to bring to it.

import FRUSParity
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct AnalyticsMirrorParityTests {
    static func app(_ path: String) throws -> String { try ProjectHistoryParityTests.app(path) }
    static func kit(_ path: String) throws -> String { try ProjectHistoryParityTests.kit(path) }
    static func server(_ path: String) throws -> String { try ProjectHistoryParityTests.server(path) }
    static func web(_ path: String) throws -> String { try ProjectHistoryParityTests.web(path) }

    /// The view's rules the server mirrors, the app's line beside the server's.
    @Test func corpusAnalyticsRulesAreTheApps() throws {
        let view = try Self.app("Analytics/AnalyticsView.swift")
        let server = try Self.server("Sources/FRUSLightAPI/CorpusAnalytics.swift")
        let pairs: [(app: String, server: String)] = [
            ("yearRangeStart != 1861 || yearRangeEnd != corpusMaxYear", "start != 1861 || end != corpusMaxYear"),
            ("private var normalizationApplies: Bool { chartAxis == .byYear || chartAxis == .byDecade }",
             "static func normalizationApplies(_ chartAxis: AnalyticsChartAxis) -> Bool { chartAxis == .byYear || chartAxis == .byDecade }"),
            ("private var measureApplies: Bool { chartAxis == .byYear || chartAxis == .byDecade }",
             "static func measureApplies(_ chartAxis: AnalyticsChartAxis) -> Bool { chartAxis == .byYear || chartAxis == .byDecade }"),
            ("guard storedValueUnit == .occurrences, measureApplies, occurrenceAvailability.isAvailable else { return .documents } return .occurrences",
             "guard ask.unit == .occurrences, Self.measureApplies(axis), loaded.availability.isAvailable else { return .documents } return .occurrences"),
            // The browser draws the chart and its table at once, so its mode is the chart's.
            ("normalizationApplies && viewMode == .chart && valueUnit == .documents && effectiveNormalizationMode == .percentOfDocuments",
             "Self.normalizationApplies(axis) && valueUnit == .documents && ask.normalization == .percentOfDocuments"),
            ("guard isNormalized else { return Double(count) } guard let total = totals[period], total > 0 else { return nil } return Double(count) / Double(total) * 100.0",
             "guard isNormalized else { return Double(count) } guard let total = totals[period], total > 0 else { return nil } return Double(count) / Double(total) * 100.0"),
            ("valueUnit == .occurrences ? (occurrenceYearDataByTerm[term] ?? []) : (yearDataByTerm[term] ?? [])",
             "valueUnit == .occurrences ? (loaded.occurrenceYears ?? []) : loaded.years"),
            ("for entry in occurrenceYearDataByTerm[term] ?? [] { byDecade[(entry.year / 10) * 10, default: 0] += entry.count }",
             "for entry in loaded.occurrenceYears ?? [] { byDecade[(entry.year / 10) * 10, default: 0] += entry.count }"),
            ("return yearData.filter { $0.year >= yearRangeStart && $0.year <= yearRangeEnd }",
             "return yearData.filter { $0.year >= yearRangeStart && $0.year <= yearRangeEnd }"),
            ("let bucketEnd = d.decadeStart + 9 return bucketEnd >= yearRangeStart && d.decadeStart <= yearRangeEnd",
             "let bucketEnd = d.decadeStart + 9 return bucketEnd >= yearRangeStart && d.decadeStart <= yearRangeEnd"),
            ("let y = cal.component(.year, from: m.date) return y >= yearRangeStart && y <= yearRangeEnd",
             "let y = cal.component(.year, from: m.date) return y >= yearRangeStart && y <= yearRangeEnd"),
            ("guard let y = d.year else { return false } return y >= yearRangeStart && y <= yearRangeEnd",
             "guard let y = d.year else { return false } return y >= yearRangeStart && y <= yearRangeEnd"),
            ("valueUnit == .occurrences ? occurrenceYearVolumeData : yearVolumeData",
             "valueUnit == .occurrences ? loaded.occurrenceYearVolumes : loaded.yearVolumes"),
            ("return yearData.isEmpty && decadeData.isEmpty && monthData.isEmpty && dayData.isEmpty && subseriesData.isEmpty && volumeData.isEmpty",
             "yearData.isEmpty && decadeData.isEmpty && loaded.months.isEmpty && loaded.days.isEmpty && loaded.subseries.isEmpty && loaded.volumes.isEmpty"),
            ("case .byMonth: return filteredMonthData.reduce(0) { $0 + $1.count } case .byDay: return filteredDayData.reduce(0) { $0 + $1.count } case .bySubseries: return subseriesData.reduce(0) { $0 + $1.count } case .byVolume: return volumeData.reduce(0) { $0 + $1.count }",
             "case .byMonth: return filteredMonthData.reduce(0) { $0 + $1.count } case .byDay: return filteredDayData.reduce(0) { $0 + $1.count } case .bySubseries: return loaded.subseries.reduce(0) { $0 + $1.count } case .byVolume: return loaded.volumes.reduce(0) { $0 + $1.count }"),
            ("committedTerms.map { \"\\\"\\(PinnedResultBase.quotable($0))\\\"\" }.joined(separator: \", \")",
             "var chartHeadingTerms: String { \"\\\"\\(QueryQuoting.quotable(committedTerm))\\\"\" }"),
            ("\"\\(chartHeadingTerms) — \\(chartAxis.pickerLabel)\"", "\"\\(chartHeadingTerms) — \\(axis.pickerLabel)\""),
            ("case .byYear: points = filteredYearData(for: term).map { CorpusSeriesPoint(periodLabel: \"\\($0.year)\", denominatorKey: $0.year, count: $0.count) }",
             "case .byYear: points = filteredYearData.map { CorpusSeriesPoint(periodLabel: \"\\($0.year)\", denominatorKey: $0.year, count: $0.count) }"),
            ("CorpusSeriesPoint(periodLabel: \"\\($0.decadeStart)s\", denominatorKey: $0.decadeStart, count: $0.count)",
             "CorpusSeriesPoint(periodLabel: \"\\($0.decadeStart)s\", denominatorKey: $0.decadeStart, count: $0.count)"),
            ("CorpusSeriesPoint(periodLabel: volumeTitle($0.volumeId), denominatorKey: nil, count: $0.count)",
             "CorpusSeriesPoint(periodLabel: volumeTitle($0.volumeId), denominatorKey: nil, count: $0.count)"),
            ("id: \"corpus.\\(chartAxis.rawValue)\", title: exportFigureTitle, periodColumn: exportPeriodColumn,",
             "id: \"corpus.\\(axis.rawValue)\", title: exportFigureTitle, periodColumn: exportPeriodColumn,"),
            ("yearRange: chartAxis.isCategorical ? nil : yearRangeStart...yearRangeEnd,", "yearRange: axis.isCategorical ? nil : ask.start...ask.end,"),
            ("? (isNormalized ? effectiveNormalizationMode.pickerLabel : AnalyticsNormalizationMode.raw.pickerLabel) : nil,",
             "? (answer.values.isNormalized ? ask.normalization.pickerLabel : AnalyticsNormalizationMode.raw.pickerLabel) : nil,"),
            ("countingUnit: valueUnit.axisLabel", "countingUnit: AnalyticsValueUnit(rawValue: answer.measure.effective)?.axisLabel,"),
            ("let subseries = CorpusAnalyticsService.subseries(fromVolumeId: key) ?? \"\" let title = appState.manifestStore.entry(forVolumeId: key)?.title ?? \"\" return ChronologyViewModel.distilledVolumeLabel(volumeId: key, subseries: subseries, title: title)",
             "let subseries = CorpusAnalyticsService.subseries(fromVolumeId: key) ?? \"\" let title = resources.volume(key)?.title ?? \"\" return VolumeLabels.distilledVolumeLabel(volumeId: key, subseries: subseries, title: title)"),
            ("appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId", "resources.volume(volumeId)?.title ?? volumeId"),
            ("AnalyticsSearchHandoff.parameters(term: committedTerm, axis: chartAxis, startYear: yearRangeStart, endYear: yearRangeEnd, yearsNarrowed: yearRangeIsCustom, scopeVolumeIds: scopeVolumeIds)",
             "AnalyticsSearchHandoff.parameters( term: ask.term, axis: ask.axis, startYear: ask.start, endYear: ask.end,"),
            ("CorpusDispersion.make(volumeCounts: match.volumeCounts, indexedVolumeCount: appState.indexedVolumeIds.count)",
             "CorpusDispersion.make(volumeCounts: match.volumeCounts, indexedVolumeCount: served.indexedVolumeIds.count)"),
            ("String(format: String(localized: \"analytics.handoff.viewDocuments %@\", defaultValue: \"View %@\"), CountCopy.documents(match.count))",
             "String(format: appWords(\"analytics.handoff.viewDocuments %@\", \"View %@\"), CountCopy.documents(count, locale: SearchItem.locale))"),
            ("guard d.showsConcentration else { return volumes }", "guard d.showsConcentration else { return volumes }"),
            ("return volumes + \" · \" + concentration", "return volumes + \" · \" + concentration"),
            ("if yearRangeIsCustom && total != filtered {", "if yearRangeIsCustom && total != filtered {"),
            ("let coloring = sourceColoring(raw)", "let coloring = AnalyticsSourceColoring.sourceColoring(raw, seriesCount: ask.colors)"),
            ("guard decade + 9 >= yearRangeStart && decade <= yearRangeEnd else { return nil } return (period: decade, volumeId: $0.volumeId, count: $0.count)",
             "guard decade + 9 >= yearRangeStart && decade <= yearRangeEnd else { return nil } return (period: decade, volumeId: $0.volumeId, count: $0.count)"),
            ("Text(unsupportedExactTerms.map { \"=\\($0)\" }", "\\(unsupportedExactTerms.map { \"=\\($0)\" }.formatted(.list(type: .and).locale(SearchItem.locale)))"),
        ]
        for (app, mirror) in pairs {
            #expect(view.contains(NoteViewParityTests.flattened(app)), "AnalyticsView.swift holds \(app)")
            #expect(server.contains(NoteViewParityTests.flattened(mirror)), "CorpusAnalytics.swift holds \(mirror)")
        }
        // `reloadData()`'s series, each for the one committed term, in the scope.
        NoteViewParityTests.expect(view, holds: [
            "async let totalsYear = service.documentTotalsByYear(volumeIds: scope) async let totalsDecade = service.documentTotalsByDecade(volumeIds: scope)",
            "? try await service.termFrequencyByYearAndVolume(term: terms[0], volumeIds: scope)",
            "? await service.occurrenceAvailability(for: terms[0])",
            "if singleTerm, unit == .occurrences, availability.isAvailable {",
            "occurrenceYearVolumes = try await service.termOccurrencesByYearAndVolume( term: terms[0], volumeIds: scope)",
            "occurrenceYears[terms[0]] = try await service.termOccurrencesByYear( term: terms[0], volumeIds: scope)",
            "async let y = service.termFrequencyByYear(term: term, volumeIds: scope)",
            "async let v = service.termFrequencyByVolume(term: term, volumeIds: scope)",
        ], file: "AnalyticsView.swift")
        NoteViewParityTests.expect(server, holds: [
            "async let totalsYear = service.documentTotalsByYear(volumeIds: scope) async let totalsDecade = service.documentTotalsByDecade(volumeIds: scope)",
            "let yearVolumes = try await service.termFrequencyByYearAndVolume(term: term, volumeIds: scope)",
            "let availability = await service.occurrenceAvailability(for: term)",
            "if ask.unit == .occurrences, availability.isAvailable {",
            "occurrenceYearVolumes = try await served.occurrences.termOccurrencesByYearAndVolume(term: term, volumeIds: scope)",
            "occurrenceYears = try await served.occurrences.termOccurrencesByYear(term: term, volumeIds: scope)",
            "async let years = service.termFrequencyByYear(term: term, volumeIds: scope)",
            "async let volumes = service.termFrequencyByVolume(term: term, volumeIds: scope)",
        ], file: "CorpusAnalytics.swift")
    }

    /// The scope bar's menu, the presets, the corpus's years, the export's name and the palette's counts.
    @Test func theOtherFilesRulesAreTheApps() throws {
        let server = try Self.server("Sources/FRUSLightAPI/CorpusAnalytics.swift")
        let chrome = try Self.app("Analytics/AnalyticsChartChrome.swift")
        NoteViewParityTests.expect(chrome, holds: [
            "Set(indexedVolumeIds.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0) }) .sorted()",
            "indexedVolumeIds .filter { CorpusAnalyticsService.subseries(fromVolumeId: $0) == subseries } .sorted()",
            "if let resolved = DocumentSubjectStore.shared?.subjectsByVolume ?? VolumeSubjectProfilesStore.shared?.resolvedByVolume,",
            "ForEach(ScopeFacets.narrowingCategories(resolvedByVolume: resolved)) { category in",
            "ForEach(ScopeFacets.subCategoryCatalog(forCategory: category.label, resolvedByVolume: resolved)) { sub in",
            "scopeLabel: \"\\(sub.category) · \\(sub.subcategory)\",",
            "profileVolumeIds: ScopeFacets.volumeIds(forCategory: sub.category, subcategory: sub.subcategory, resolvedByVolume: resolved))",
            "let indexed = profileVolumeIds.intersection(indexedVolumeIds)",
            "setScope(indexed.sorted(), label: scopeLabel)",
            "setScope(volumes(inSubseries: sub), label: sub)",
            "setScope([volumeId], label: volumeTitle(volumeId))",
            "setScope(ids.sorted(), label: scope.name)",
            "defaultValue: \"%@ (%lld of %lld indexed)\"), scope.name, Int64(ids.count), Int64(scope.volumeIds.count)))",
            "defaultValue: \"%@ — none indexed yet\"), scope.name))",
            "bounds: 1776...end,",
            "bounds: start...corpusMaxYear,",
            "@Query(sort: \\CustomVolumeScope.name) private var customScopes: [CustomVolumeScope]",
        ], file: "AnalyticsChartChrome.swift")
        NoteViewParityTests.expect(server, holds: [
            "Set(indexed.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0) }).sorted()",
            "indexed.filter { CorpusAnalyticsService.subseries(fromVolumeId: $0) == subseries }.sorted()",
            "resources.documentSubjectIndex?.subjectsByVolume ?? resources.subjectProfiles.profiles?.resolvedByVolume",
            "topics = ScopeFacets.narrowingCategories(resolvedByVolume: resolved).map { category in",
            "items: ScopeFacets.subCategoryCatalog(forCategory: category.label, resolvedByVolume: resolved).map { sub in",
            "let profile = ScopeFacets.volumeIds(forCategory: sub.category, subcategory: sub.subcategory, resolvedByVolume: resolved)",
            "let count = profile.intersection(indexed).count",
            "let ids = ScopeFacets.volumeIds(forCategory: category, subcategory: subcategory, resolvedByVolume: resolved) .intersection(indexed)",
            "return .volumes(ids.sorted(), label: \"\\(category) · \\(subcategory)\")",
            "return .volumes(ids, label: subseries)",
            "return .volumes([volume], label: volumeTitle(volume, resources: resources))",
            "static let earliestYear = 1776",
            "static let colorCounts = 6...12 static let defaultColors = 8",
        ], file: "CorpusAnalytics.swift")
        // The user's scopes, resolved by the kit on the server, sorted by name and labelled in the browser.
        NoteViewParityTests.expect(try Self.web("analytics/analyticsRules.ts"), holds: [
            "const sorted = [...scopes].sort((a, b) => a.name.localeCompare(b.name, 'en', { numeric: true }));",
            "return Math.min(Math.max(value, earliest), end);",
            "return Math.min(Math.max(value, start), corpusMaxYear);",
            "const all: AnalyticsAxis[] = ['byDecade', 'byYear', 'byMonth', 'byDay', 'bySubseries', 'byVolume'];",
            "{ label: words.overTime, axes: all.filter(isDateBased) }, { label: words.brokenDown, axes: all.filter((axis) => !isDateBased(axis)) },",
            "'#007AFF', '#FF9500', '#34C759', '#AF52DE', '#FF2D55', '#30B0C7', '#5856D6', '#FF3B30', '#00C7BE', '#32ADE6', '#A2845E', '#FFCC00',",
        ], file: "analyticsRules.ts")
        NoteViewParityTests.expect(try Self.web("copy.ts"), holds: [
            "customScope: (name: string, indexed: number, total: number) => `${name} (${indexed} of ${total} indexed)`,",
            "customScopeNone: (name: string) => `${name} — none indexed yet`,",
        ], file: "copy.ts")
        let axes = try Self.kit("FRUSCoreKit/Analytics/AnalyticsChartAxis.swift")
        NoteViewParityTests.expect(axes, holds: [
            "case byDecade, byYear, byMonth, byDay, bySubseries, byVolume",
            "self != .bySubseries && self != .byVolume",
        ], file: "AnalyticsChartAxis.swift")
        NoteViewParityTests.expect(try Self.app("Analytics/AnalyticsView.swift"), holds: [
            "ForEach(AnalyticsChartAxis.allCases.filter { $0.isDateBased }, id: \\.self) { axis in",
            "ForEach(AnalyticsChartAxis.allCases.filter { $0.isCategorical }, id: \\.self) { axis in",
        ], file: "AnalyticsView.swift")
        // The palette's colours, counts and default.
        NoteViewParityTests.expect(try Self.app("Theme/FRUSTheme.swift"), holds: [
            "static let colors: [Color] = [ .blue, .orange, .green, .purple, .pink, .teal, .indigo, .red, .mint, .cyan, .brown, .yellow, ]",
            "static let range: ClosedRange<Int> = 6...12",
            "static let defaultCount = 8",
            "static let storageKey = \"frus.display.chartSeriesCount\"",
        ], file: "FRUSTheme.swift")
        NoteViewParityTests.expect(try Self.kit("FRUSCoreKit/Analytics/AnalyticsValueUnit.swift"), holds: ["static let storageKey = \"frus.analytics.valueUnit\""],
                                   file: "AnalyticsValueUnit.swift")
        NoteViewParityTests.expect(try Self.kit("FRUSCoreKit/Analytics/AnalyticsChartAxis.swift"), holds: ["static let storageKey = \"frus.analytics.normalizationMode\""],
                                   file: "AnalyticsChartAxis.swift")
        NoteViewParityTests.expect(try Self.web("analytics/analyticsRules.ts"), holds: [
            "measure: 'frus.analytics.valueUnit', values: 'frus.analytics.normalizationMode', colors: 'frus.display.chartSeriesCount',",
        ], file: "analyticsRules.ts")
        // The presets, the app's rule over the kit's profiles, line for line.
        let presets = try Self.app("Analytics/AdministrationPresetMenu.swift")
        for line in [
            "nonisolated static let floorYear = 1861",
            "guard let start = Int(profile.start.prefix(4)) else { return nil }",
            "let end = max(start, profile.end.flatMap { Int($0.prefix(4)) } ?? currentYear)",
            "guard start <= corpusMaxYear && end >= floorYear else { return nil }",
            "let clampedStart = min(max(start, floorYear), corpusMaxYear)",
            "let clampedEnd = max(clampedStart, min(end, corpusMaxYear))",
            "return (profile, clampedStart, clampedEnd) } .sorted { $0.0.number < $1.0.number }",
            "Calendar(identifier: .gregorian).component(.year, from: Date())",
        ] {
            #expect(presets.contains(NoteViewParityTests.flattened(line)), "AdministrationPresetMenu.swift holds \(line)")
            #expect(server.contains(NoteViewParityTests.flattened(line.replacingOccurrences(of: "nonisolated static let floorYear", with: "static let floorYear"))),
                    "CorpusAnalytics.swift holds \(line)")
        }
        #expect(presets.contains("defaultValue: \"%@ (%lld–%lld)\"), item.profile.president, Int64(item.start), Int64(item.end)))"))
        #expect(server.contains("String(format: appWords(\"analytics.adminPreset.item %@ %lld %lld\", \"%@ (%lld–%lld)\"), president, Int64(start), Int64(end))"))
        // The corpus's years.
        let manifest = try Self.app("Models/Manifest/ManifestStore.swift")
        for line in [
            "let minYear = source.compactMap { Int($0.subseries.prefix(4)) }.min() ?? 1861",
            "let maxYear = source.compactMap { Self.subseriesEndYear($0.subseries) }.max() ?? 1992",
            "let parts = subseries.split(separator: \"-\", maxSplits: 1) guard let startPart = parts.first, startPart.count == 4, let start = Int(startPart) else { return nil }",
            "if endPart.count == 2, let twoDigit = Int(endPart) { var end = (start / 100) * 100 + twoDigit if end < start { end += 100 }",
        ] {
            #expect(manifest.contains(NoteViewParityTests.flattened(line)), "ManifestStore.swift holds \(line)")
        }
        NoteViewParityTests.expect(server, holds: [
            "entries.compactMap { Int($0.subseries.prefix(4)) }.min() ?? 1861",
            "entries.compactMap { subseriesEndYear($0.subseries) }.max() ?? 1992",
            "let parts = subseries.split(separator: \"-\", maxSplits: 1) guard let startPart = parts.first, startPart.count == 4, let start = Int(startPart) else { return nil }",
            "if endPart.count == 2, let twoDigit = Int(endPart) { var end = (start / 100) * 100 + twoDigit if end < start { end += 100 }",
        ], file: "CorpusAnalytics.swift")
        // The export's name.
        let delivery = try Self.app("Analytics/Export/AnalyticsExportDelivery.swift")
        for line in [
            "let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: \"-_ \"))",
            "let cleaned = title.unicodeScalars.map { allowed.contains($0) ? Character($0) : \" \" }",
            ".replacingOccurrences(of: \" +\", with: \" \", options: .regularExpression) .replacingOccurrences(of: \" \", with: \"-\")",
            "let stamp = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))",
            "let extensionAllowance = 8",
            "if stem.isEmpty { stem = \"chart\" } return \"\\(prefix)-\\(stem)-\\(stamp)\"",
        ] {
            #expect(delivery.contains(NoteViewParityTests.flattened(line)), "AnalyticsExportDelivery.swift holds \(line)")
            #expect(server.contains(NoteViewParityTests.flattened(line)), "CorpusAnalytics.swift holds \(line)")
        }
        #expect(delivery.contains("prefix: String = \"FRUS-Analytics\","))
    }

    /// Chronology's `reload()` and the view's rules, the app's beside the server's and the browser's.
    @Test func chronologyRulesAreTheApps() throws {
        let model = try Self.app("Chronology/ChronologyViewModel.swift")
        let view = try Self.app("Chronology/ChronologyView.swift")
        let server = try Self.server("Sources/FRUSLightAPI/Chronology.swift")
        let shared = [
            "let startDay = cal.startOfDay(for: min(rangeStart, rangeEnd)) let endDay = cal.startOfDay(for: max(rangeStart, rangeEnd))",
            "let range = DateRange(earliest: startISO, latest: endISO)",
            "let (placed, spanning) = Self.partition(rows)",
            "let (inRange, overflow) = Self.splitOverflow(placed, startISO: startISO, endISO: endISO)",
            "let viewBucket = Self.bucket(forDaysBetween: startDay, and: endDay, calendar: cal)",
            "chartDomainStart = Self.startOfBucket(startDay, bucket: viewBucket, calendar: cal)",
            "groups = Self.group(inRange, viewBucket: viewBucket, ascending: ascending)",
            "range, bucket: viewBucket, scopeVolumeIds: nil)) ?? []",
            "totalShown = counts.reduce(0) { $0 + $1.count }",
            "let chart = Self.makeChart(from: groups, maxSeries: seriesCount)",
        ]
        NoteViewParityTests.expect(model, holds: shared + ["isCapped = rows.count >= Self.loadLimit", "spanningRows = spanning.sorted { $0.dateISO < $1.dateISO }",
                                                           "overflowRows = overflow.sorted { $0.dateISO < $1.dateISO }"],
                                   file: "ChronologyViewModel.swift")
        NoteViewParityTests.expect(server, holds: [
            "let startDay = cal.startOfDay(for: min(ask.start, ask.end)) let endDay = cal.startOfDay(for: max(ask.start, ask.end))",
            "let range = DateRange(earliest: startISO, latest: endISO)",
            "let (placed, spanning) = ChronologyGrouping.partition(rows)",
            "let (inRange, overflow) = ChronologyGrouping.splitOverflow(placed, startISO: startISO, endISO: endISO)",
            "let viewBucket = ChronologyGrouping.bucket(forDaysBetween: startDay, and: endDay, calendar: cal)",
            "let domainStart = ChronologyGrouping.startOfBucket(startDay, bucket: viewBucket, calendar: cal)",
            "let groups = ChronologyGrouping.group(inRange, viewBucket: viewBucket, ascending: ask.ascending)",
            "let counts = (try? await pipeline.dateBucketVolumeCounts(range, bucket: viewBucket, scopeVolumeIds: nil)) ?? []",
            "totalShown = counts.reduce(0) { $0 + $1.count }",
            "chart = ChronologyGrouping.makeChart(from: groups, maxSeries: ask.colors)",
            "let isCapped = rows.count >= ChronologyGrouping.loadLimit",
            "let spanningRows = spanning.sorted { $0.dateISO < $1.dateISO }",
            "let overflowRows = overflow.sorted { $0.dateISO < $1.dateISO }",
        ], file: "Chronology.swift")
        let viewRules = [
            "guard let selected = selectedSeries else { return true } if selected == chronologyOtherSeriesKey { return !topSeriesKeys.contains(row.volumeId) } return row.volumeId == selected",
            "let rows = group.rows.filter(rowMatchesFilter) guard !rows.isEmpty else { return nil }",
            "let subseries = Set(rows.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0.volumeId) })",
            "volumeCount: Set(rows.map(\\.volumeId)).count, subseriesCount: subseries.count, editorialNoteCount: rows.filter(\\.isEditorialNote).count",
            "let start = String(row.dateISO.prefix(4)) let end = row.dateISOMax.map { String($0.prefix(4)) } ?? start return start == end ? start : \"\\(start)\\u{2013}\\(end)\"",
            "let end = row.dateISOMax.map { String($0.prefix(4)) } ?? String(row.dateISO.prefix(4))",
            "return parts.joined(separator: \" \\u{00b7} \")",
            "if let summary = row.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return summary } return row.header.isEmpty ? row.documentId : row.header",
            "private static let denseThreshold = 25",
            "vm.rangeEnd = corpus.upperBound vm.rangeStart = cal.date(byAdding: .year, value: -1, to: corpus.upperBound) ?? corpus.lowerBound",
        ]
        NoteViewParityTests.expect(view, holds: viewRules + [
            "Set(vm.chartSeries.map(\\.key).filter { $0 != chronologyOtherSeriesKey })",
            "volumeId: volumeId, subseries: entry?.subseries ?? \"\", title: entry?.title ?? volumeId",
            "let base = CountCopy.documents(vm.totalShown)",
        ], file: "ChronologyView.swift")
        NoteViewParityTests.expect(server, holds: [
            "guard let selected else { return true } if selected == chronologyOtherSeriesKey { return !topSeriesKeys.contains(row.volumeId) } return row.volumeId == selected",
            "let rows = group.rows.filter(rowMatchesFilter) guard !rows.isEmpty else { return nil }",
            "let subseries = Set(rows.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0.volumeId) })",
            "volumeCount: Set(rows.map(\\.volumeId)).count, subseriesCount: subseries.count, editorialNoteCount: rows.filter(\\.isEditorialNote).count",
            "let start = String(row.dateISO.prefix(4)) let end = row.dateISOMax.map { String($0.prefix(4)) } ?? start return start == end ? start : \"\\(start)\\u{2013}\\(end)\"",
            "let end = row.dateISOMax.map { String($0.prefix(4)) } ?? String(row.dateISO.prefix(4))",
            "return parts.joined(separator: \" \\u{00b7} \")",
            "if let summary = row.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return summary } return row.header.isEmpty ? row.documentId : row.header",
            "static let denseThreshold = 25",
            "let start = cal.date(byAdding: .year, value: -1, to: upper) ?? lower",
            "Set(seriesKeys.filter { $0 != chronologyOtherSeriesKey })",
            "return VolumeLabels.distilledVolumeLabel(volumeId: key, subseries: entry?.subseries ?? \"\", title: entry?.title ?? key)",
            "let base = CountCopy.documents(totalShown, locale: SearchItem.locale)",
        ], file: "Chronology.swift")
        NoteViewParityTests.expect(try Self.web("analytics/ChronologyScreen.tsx"), holds: ["const denseThreshold = 25;"], file: "ChronologyScreen.tsx")
        // The section's aggregate line (`ChronologyAggregateText`), its counts grouped as `String(localized:)` groups them.
        NoteViewParityTests.expect(view, holds: [
            "parts.append(String(localized: \"chronology.agg.volumes.v2\", defaultValue: \"\\(volumes) volume\\(volumes == 1 ? \"\" : \"s\")\"))",
            "parts.append(CountCopy.phrase(subseries, one: String(localized: \"chronology.agg.subseries.one\", defaultValue: \"%@ subseries\"), many: String(localized: \"chronology.agg.subseries.many\", defaultValue: \"%@ subseries\")))",
            "if editorialNotes > 0 { parts.append(String(localized: \"chronology.agg.editorial.v2\", defaultValue: \"\\(editorialNotes) editorial note\\(editorialNotes == 1 ? \"\" : \"s\")\")) } return parts.joined(separator: \" · \")",
        ], file: "ChronologyView.swift")
        NoteViewParityTests.expect(server, holds: [
            "parts.append(appWords(\"chronology.agg.volumes.v2\", \"\\(grouped(volumes)) volume\\(volumes == 1 ? \"\" : \"s\")\"))",
            "parts.append(CountCopy.phrase(subseries, one: appWords(\"chronology.agg.subseries.one\", \"%@ subseries\"), many: appWords(\"chronology.agg.subseries.many\", \"%@ subseries\"), locale: SearchItem.locale))",
            "if editorialNotes > 0 { parts.append(appWords(\"chronology.agg.editorial.v2\", \"\\(grouped(editorialNotes)) editorial note\\(editorialNotes == 1 ? \"\" : \"s\")\")) } return parts.joined(separator: \" · \")",
        ], file: "Chronology.swift")
        #expect(ChronologyViewRules.aggregateLine(volumes: 1, subseries: 1, editorialNotes: 0) == "1 volume · 1 subseries")
        #expect(ChronologyViewRules.aggregateLine(volumes: 1_204, subseries: 2, editorialNotes: 3) == "1,204 volumes · 2 subseries · 3 editorial notes")
        #expect(ChronologyViewRules.summaryLine(totalShown: 7_000, isCapped: true, chartShowsFullDistribution: true)
                == "7,000 documents (chart shows all; list shows the first 5,000 — narrow the range to browse them)")
        #expect(ChronologyViewRules.summaryLine(totalShown: 5_000, isCapped: true, chartShowsFullDistribution: false)
                == "5,000 documents (showing the first 5,000 — narrow the range)")
    }

    /// The app's words the server writes, each under its key where the app's source writes it.
    @Test func theAppsWordsAreTheServers() throws {
        let words: [(file: String, key: String, value: String, server: String, mirror: String)] = [
            ("Analytics/AnalyticsView.swift", "analytics.chart.year.heading", "\\(chartHeadingTerms) \\u{2014} by Year", "CorpusAnalytics.swift", "\\(chartHeadingTerms) \\u{2014} by Year"),
            ("Analytics/AnalyticsView.swift", "analytics.chart.decade.heading", "\\(chartHeadingTerms) \\u{2014} by Decade", "CorpusAnalytics.swift", "\\(chartHeadingTerms) \\u{2014} by Decade"),
            ("Analytics/AnalyticsView.swift", "analytics.chart.month.heading", "\\(chartHeadingTerms) \\u{2014} by Month", "CorpusAnalytics.swift", "\\(chartHeadingTerms) \\u{2014} by Month"),
            ("Analytics/AnalyticsView.swift", "analytics.chart.day.heading", "\\(chartHeadingTerms) \\u{2014} by Day", "CorpusAnalytics.swift", "\\(chartHeadingTerms) \\u{2014} by Day"),
            ("Analytics/AnalyticsView.swift", "analytics.chart.subseries.heading", "“\\(quotedTerm)” \\u{2014} by Subseries", "CorpusAnalytics.swift", "“\\(quotedTerm)” \\u{2014} by Subseries"),
            ("Analytics/AnalyticsView.swift", "analytics.chart.volume.heading", "“\\(quotedTerm)” \\u{2014} by Volume", "CorpusAnalytics.swift", "“\\(quotedTerm)” \\u{2014} by Volume"),
            ("Analytics/AnalyticsView.swift", "analytics.axis.year", "Year", "CorpusAnalytics.swift", "Year"),
            ("Analytics/AnalyticsView.swift", "analytics.axis.decade", "Decade", "CorpusAnalytics.swift", "Decade"),
            ("Analytics/AnalyticsView.swift", "analytics.axis.month", "Month", "CorpusAnalytics.swift", "Month"),
            ("Analytics/AnalyticsView.swift", "analytics.axis.date", "Date", "CorpusAnalytics.swift", "Date"),
            ("Analytics/AnalyticsView.swift", "analytics.axis.subseries", "Subseries", "CorpusAnalytics.swift", "Subseries"),
            ("Analytics/AnalyticsView.swift", "analytics.axis.volume", "Volume", "CorpusAnalytics.swift", "Volume"),
            ("Analytics/AnalyticsView.swift", "analytics.figure.legend.occurrences", "\\(total) mentions", "CorpusAnalytics.swift", "\\(grouped(total)) mentions"),
            ("Analytics/AnalyticsView.swift", "analytics.figure.legend.docs", "\\(total) docs", "CorpusAnalytics.swift", "\\(grouped(total)) docs"),
            ("Analytics/AnalyticsView.swift", "analytics.normalize.caption",
             "Share of indexed documents per period. Only downloaded, indexed volumes are counted, so this is a share of your local corpus, not the entire FRUS series.",
             "CorpusAnalytics.swift",
             "Share of indexed documents per period. Only downloaded, indexed volumes are counted, so this is a share of your local corpus, not the entire FRUS series."),
            ("Analytics/AnalyticsView.swift", "analytics.exactUnsupported.title", "Exact-Word Charting Isn’t Available", "CorpusAnalytics.swift", "Exact-Word Charting Isn’t Available"),
            ("Analytics/AnalyticsView.swift", "analytics.empty.title", "No Results", "CorpusAnalytics.swift", "No Results"),
            ("Analytics/AnalyticsView.swift", "analytics.empty.detail", "No indexed documents match “\\(quotedTerm)”.", "CorpusAnalytics.swift", "No indexed documents match “\\(quotedTerm)”."),
            ("Analytics/AnalyticsView.swift", "analytics.month.empty.title", "No documents with month-level dates", "CorpusAnalytics.swift", "No documents with month-level dates"),
            ("Analytics/AnalyticsView.swift", "analytics.month.empty.detail", "Matching documents are indexed with year-only dates. Switch to By Year or By Decade.",
             "CorpusAnalytics.swift", "Matching documents are indexed with year-only dates. Switch to By Year or By Decade."),
            ("Analytics/AnalyticsView.swift", "analytics.day.empty.title", "No documents with day-level dates", "CorpusAnalytics.swift", "No documents with day-level dates"),
            ("Analytics/AnalyticsView.swift", "analytics.day.empty.detail", "Matching documents are indexed without full yyyy-MM-dd dates. Try By Month or By Year.",
             "CorpusAnalytics.swift", "Matching documents are indexed without full yyyy-MM-dd dates. Try By Month or By Year."),
            ("Analytics/AnalyticsView.swift", "analytics.dispersion.volumes", "Spread across \\(d.volumes) of \\(d.indexedVolumeCount) indexed volumes",
             "CorpusAnalytics.swift", "Spread across \\(grouped(d.volumes)) of \\(grouped(d.indexedVolumeCount)) indexed volumes"),
            ("Analytics/AnalyticsView.swift", "analytics.dispersion.concentration", "top 3 hold \\(d.topThreePercent)%", "CorpusAnalytics.swift", "top 3 hold \\(grouped(d.topThreePercent))%"),
            ("Analytics/AnalyticsView.swift", "analytics.chart.source.other", "Other volumes", "CorpusAnalytics.swift", "Other volumes"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.scope.wholeCorpus", "Whole corpus", "CorpusAnalytics.swift", "Whole corpus"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.scope.custom", "Selected volumes", "CorpusAnalytics.swift", "Selected volumes"),
            ("Chronology/ChronologyView.swift", "chronology.overflow.header", "Extends beyond this range", "Chronology.swift", "Extends beyond this range"),
            ("Chronology/ChronologyView.swift", "chronology.undated.note", "Documents without a machine-readable date are not shown.", "Chronology.swift",
             "Documents without a machine-readable date are not shown."),
            ("Chronology/ChronologyView.swift", "chronology.chart.other", "Other volumes", "Chronology.swift", "Other volumes"),
            ("Chronology/ChronologyView.swift", "chronology.chart.x", "Date", "Chronology.swift", "Date"),
            ("Chronology/ChronologyView.swift", "chronology.chart.y", "Documents", "Chronology.swift", "Documents"),
            ("Chronology/ChronologyView.swift", "chronology.chart.series", "Volume", "Chronology.swift", "Volume"),
        ]
        var read: [String: String] = [:]
        for word in words {
            let app = try read[word.file] ?? Self.app(word.file)
            read[word.file] = app
            let server = try read[word.server] ?? Self.server("Sources/FRUSLightAPI/\(word.server)")
            read[word.server] = server
            #expect(app.contains("String(localized: \"\(word.key)\", defaultValue: \"\(word.value)\")"), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(server.contains("appWords(\"\(word.key)\", \"\(word.mirror)\")"), "\(word.server) writes \(word.key) as \(word.mirror)")
        }
        // The words a format string carries, written through `String(format:)`.
        let chrome = try Self.app("Analytics/AnalyticsChartChrome.swift")
        #expect(chrome.contains("localized: \"analytics.scope.subject.none %@\", defaultValue: \"%@ — none indexed yet\"), baseLabel))"))
        #expect(chrome.contains("localized: \"analytics.scope.subject.indexed %@ %lld %lld\", defaultValue: \"%@ (%lld of %lld indexed)\"), baseLabel, Int64(indexed.count), Int64(profileVolumeIds.count)))"))
        let chronology = try Self.app("Chronology/ChronologyView.swift")
        for (key, value) in [("chronology.overflow.begins %@", "begins %@ · before range"), ("chronology.overflow.ends %@", "ends %@ · after range"),
                             ("chronology.showAll %@", "Show all %@ on this date"), ("chronology.filter.active %@", "Showing %@ only")] {
            #expect(chronology.contains("localized: \"\(key)\", defaultValue: \"\(value)\")"), "ChronologyView.swift writes \(key)")
            #expect(try Self.server("Sources/FRUSLightAPI/Chronology.swift").contains("appWords(\"\(key)\", \"\(value)\")"), "Chronology.swift writes \(key)")
        }
        for (key, value) in [
            ("chronology.summary.chartFull", "(chart shows all; list shows the first \\(ChronologyViewModel.loadLimit) — narrow the range to browse them)"),
            ("chronology.summary.capped", "(showing the first \\(ChronologyViewModel.loadLimit) — narrow the range)"),
        ] {
            #expect(chronology.contains("String(localized: \"\(key)\", defaultValue: \"\(value)\")"), "ChronologyView.swift writes \(key)")
        }
    }

    /// The app's words the browser app takes, each where the app's source writes it, and in copy.ts's block.
    @Test func theAppsWordsAreTheWebs() throws {
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let words: [(file: String, key: String, value: String, block: String, web: String)] = [
            ("Analytics/AnalyticsView.swift", "analytics.title", "Corpus Analytics", "corpusAnalytics", "title"),
            ("Analytics/AnalyticsView.swift", "analytics.term.placeholder", "Term…", "corpusAnalytics", "termPlaceholder"),
            ("Analytics/AnalyticsView.swift", "analytics.search.button", "Search", "corpusAnalytics", "search"),
            ("Analytics/AnalyticsView.swift", "analytics.prompt.title", "Enter a Term", "corpusAnalytics", "promptTitle"),
            ("Analytics/AnalyticsView.swift", "analytics.prompt.detail.mac",
             "Type a keyword and click Search to chart its frequency across the FRUS corpus.", "corpusAnalytics", "promptDetail"),
            ("Analytics/AnalyticsView.swift", "analytics.unavailable.title", "Analytics Unavailable", "corpusAnalytics", "unavailableTitle"),
            ("Analytics/AnalyticsView.swift", "analytics.unavailable.detail",
             "The search index is not available. Index at least one volume to enable analytics.", "corpusAnalytics", "unavailableDetail"),
            ("Analytics/AnalyticsView.swift", "analytics.error.title", "Error", "corpusAnalytics", "errorTitle"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.scope.menu.a11y", "Analysis scope", "corpusAnalytics", "scope"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.scope.menu.help",
             "Restrict the analysis to a subseries or a single volume, or chart the whole corpus.", "corpusAnalytics", "scopeHelp"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.scope.wholeCorpus", "Whole corpus", "corpusAnalytics", "wholeCorpus"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.scope.bySubseries", "By Subseries", "corpusAnalytics", "bySubseries"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.scope.customScopes", "My Volume Scopes", "corpusAnalytics", "customScopes"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.scope.subject.experimental", "Detected topics — experimental", "corpusAnalytics", "topicsNote"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.yearRange.chip.a11y", "Year range", "corpusAnalytics", "yearRange"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.yearRange.start.a11y", "Start year", "corpusAnalytics", "startYear"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.yearRange.end.a11y", "End year", "corpusAnalytics", "endYear"),
            ("Analytics/AnalyticsChartChrome.swift", "analytics.yearRange.reset", "Reset", "corpusAnalytics", "reset"),
            ("Analytics/AnalyticsView.swift", "analytics.yearRange.categoricalNote",
             "The year range applies to the time views; the breakdowns show the whole span.", "corpusAnalytics", "categoricalNote"),
            ("Analytics/AnalyticsView.swift", "analytics.axis.help", "Group the chart", "corpusAnalytics", "groupByHelp"),
            ("Analytics/AnalyticsView.swift", "analytics.axis.section.overTime", "Over time", "corpusAnalytics", "overTime"),
            ("Analytics/AnalyticsView.swift", "analytics.axis.section.brokenDown", "Broken down by", "corpusAnalytics", "brokenDown"),
            ("Analytics/AdministrationPresetMenu.swift", "analytics.adminPreset.label", "Administration", "corpusAnalytics", "administration"),
            ("Analytics/AdministrationPresetMenu.swift", "analytics.adminPreset.help",
             "Set the year range to a presidential administration’s years in office", "corpusAnalytics", "administrationHelp"),
            ("Analytics/AnalyticsView.swift", "analytics.measure.picker", "Measure", "corpusAnalytics", "measure"),
            ("Analytics/AnalyticsView.swift", "analytics.normalize.picker", "Values", "corpusAnalytics", "values"),
            ("Analytics/AnalyticsView.swift", "analytics.fitLine.toggle", "Fit line", "corpusAnalytics", "fitLine"),
            ("Analytics/AnalyticsView.swift", "analytics.fitLine.help", "Toggle the smoothed trend line overlay on the chart.", "corpusAnalytics", "fitLineHelp"),
            ("Analytics/AnalyticsView.swift", "analytics.colors.count.v2", "Colors per chart", "corpusAnalytics", "colors"),
            ("Analytics/AnalyticsView.swift", "analytics.export.menu", "Export", "corpusAnalytics", "export"),
            ("Analytics/AnalyticsView.swift", "analytics.export.menu.help", "Export this chart’s data with its method and caveats", "corpusAnalytics", "exportHelp"),
            ("Analytics/AnalyticsView.swift", "analytics.export.csv", "Chart data (CSV)…", "corpusAnalytics", "exportCSV"),
            ("Analytics/AnalyticsView.swift", "analytics.export.png", "Figure (PNG)…", "corpusAnalytics", "exportPNG"),
            ("Analytics/AnalyticsView.swift", "analytics.export.error.title", "Export Failed", "corpusAnalytics", "exportFailed"),
            ("Analytics/AnalyticsView.swift", "analytics.export.error.render", "The figure could not be rendered.", "corpusAnalytics", "renderError"),
            ("Analytics/AnalyticsView.swift", "analytics.handoff.viewDocuments.counting", "View documents", "corpusAnalytics", "viewDocuments"),
            ("Analytics/AnalyticsView.swift", "analytics.drillIn.hint", "Select a bar to open the matching documents in Search.", "corpusAnalytics", "drillHint"),
            ("Analytics/AnalyticsView.swift", "analytics.chart.source.series", "Volume", "corpusAnalytics", "volume"),
            ("Chronology/ChronologyView.swift", "chronology.title", "Chronology", "chronology", "title"),
            ("Chronology/ChronologyView.swift", "chronology.range.from", "From", "chronology", "from"),
            ("Chronology/ChronologyView.swift", "chronology.range.to", "To", "chronology", "to"),
            ("Chronology/ChronologyView.swift", "chronology.show", "Show", "chronology", "show"),
            ("Chronology/ChronologyView.swift", "chronology.searchRange", "Search in this range", "chronology", "searchRange"),
            ("Chronology/ChronologyView.swift", "chronology.prompt.title", "Choose a Date Range", "chronology", "promptTitle"),
            ("Chronology/ChronologyView.swift", "chronology.prompt.detail.mac",
             "Pick a start and end date, then click Show to browse every corpus document from that period.", "chronology", "promptDetail"),
            ("Chronology/ChronologyView.swift", "chronology.empty.title", "No Documents", "chronology", "emptyTitle"),
            ("Chronology/ChronologyView.swift", "chronology.unavailable.title", "Chronology Unavailable", "chronology", "unavailableTitle"),
            ("Chronology/ChronologyView.swift", "chronology.chart.hide", "Hide chart", "chronology", "hideChart"),
            ("Chronology/ChronologyView.swift", "chronology.chart.show", "Show chart", "chronology", "showChart"),
            ("Chronology/ChronologyView.swift", "chronology.chart.toggle.help", "Show or hide the document distribution chart", "chronology", "chartToggleHelp"),
            ("Chronology/ChronologyView.swift", "chronology.sort.oldest", "Oldest first", "chronology", "oldestFirst"),
            ("Chronology/ChronologyView.swift", "chronology.sort.newest", "Newest first", "chronology", "newestFirst"),
            ("Chronology/ChronologyView.swift", "chronology.sort.help", "Toggle chronological order", "chronology", "sortHelp"),
            ("Chronology/ChronologyView.swift", "chronology.colors.count.v2", "Colors per chart", "chronology", "colors"),
            ("Chronology/ChronologyView.swift", "chronology.chart.x", "Date", "chronology", "chartX"),
            ("Chronology/ChronologyView.swift", "chronology.chart.y", "Documents", "chronology", "chartY"),
            ("Chronology/ChronologyView.swift", "chronology.chart.series", "Volume", "chronology", "chartSeries"),
            ("Chronology/ChronologyView.swift", "chronology.chart.legend.hint", "Filters the list to this volume", "chronology", "legendHint"),
            ("Chronology/ChronologyView.swift", "chronology.filter.clear", "Show all", "chronology", "showAll"),
            ("Chronology/ChronologyView.swift", "chronology.badge.approx", "~ approximate", "chronology", "approximate"),
            ("Chronology/ChronologyView.swift", "chronology.badge.editorial", "Editorial note", "chronology", "editorialNote"),
            ("Chronology/ChronologyView.swift", "chronology.badge.frontMatter", "Front matter", "chronology", "frontMatter"),
            ("Chronology/ChronologyView.swift", "chronology.undated.note", "Documents without a machine-readable date are not shown.", "chronology", "undatedNote"),
            ("App/MainWindowView.swift", "mainwindow.tools.analytics", "Analytics", "app", "analytics"),
            ("App/MainWindowView.swift", "mainwindow.tools.corpusAnalytics", "Corpus Analytics", "app", "corpusAnalytics"),
            ("App/MainWindowView.swift", "mainwindow.tools.chronology", "Chronology", "app", "chronology"),
        ]
        var read: [String: String] = [:]
        for word in words {
            let app = try read[word.file] ?? Self.app(word.file)
            read[word.file] = app
            #expect(NoteViewParityTests.writes(app, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            let block = try NoteViewParityTests.block(word.block, of: copy)
            #expect(block.contains("\(word.web): '\(word.value)'"), "copy.ts's \(word.block) block has \(word.web): \(word.value)")
        }
        // The kit's axis names, which the menu shows before a chart is drawn.
        let axes = try Self.kit("FRUSCoreKit/Analytics/AnalyticsChartAxis.swift")
        let block = try NoteViewParityTests.block("corpusAnalytics", of: copy)
        for (key, value, web) in [("analytics.axis.byDecade", "By Decade", "byDecade"), ("analytics.axis.byYear", "By Year", "byYear"),
                                  ("analytics.axis.byMonth", "By Month", "byMonth"), ("analytics.axis.byDay", "By Day", "byDay"),
                                  ("analytics.axis.bySubseries", "By Subseries", "bySubseries"), ("analytics.axis.byVolume", "By Volume", "byVolume"),
                                  ("analytics.measure.documents", "Documents", "documents"), ("analytics.measure.occurrences", "Occurrences", "occurrences"),
                                  ("analytics.normalize.raw", "Raw count", "raw"), ("analytics.normalize.percent", "% of documents", "percent")] {
            let source = key.hasPrefix("analytics.measure") ? try Self.kit("FRUSCoreKit/Analytics/AnalyticsValueUnit.swift") : axes
            #expect(NoteViewParityTests.writes(source, key, value), "the kit writes \(key) as \(value)")
            #expect(block.contains("\(web): '\(value)'"), "copy.ts's corpusAnalytics block has \(web): \(value)")
        }
        // The chart's description, which the app gives its chart for VoiceOver.
        let chronology = try Self.app("Chronology/ChronologyView.swift")
        #expect(NoteViewParityTests.writes(chronology, "chronology.chart.a11y",
                                           "Document distribution over the selected dates, stacked by volume. Counts are listed in the legend and in each date section below."))
        #expect(try NoteViewParityTests.block("chronology", of: copy).contains(
            "chartDescription: 'Document distribution over the selected dates, stacked by volume. Counts are listed in the legend and in each date section below.'"))
    }
}
