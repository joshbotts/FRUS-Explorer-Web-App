// What the server and the browser app mirror of Person and Cross-Reference Analytics' views (PLAN's S24g), held to the
// app's source at the pin, line beside line: `PersonAnalyticsView`'s caps, years, trajectory and relationship rules and
// export statement, `PersonAnalyticsCopy`, the co-mention graph's label limit, spokes and legend, and
// `CrossReferenceAnalyticsView`'s limits, years, sequence, row labels and statement, with `RankingChartLabels.swift`'s
// matrix labels; and every word the server writes and copy.ts holds, under the app's key.

import FRUSLightCore
import Foundation
import Testing

@Suite struct PersonAndCrossReferenceMirrorParityTests {
    static func app(_ path: String) throws -> String { try SearchSetParityTests.app(path) }
    static func server(_ path: String) throws -> String { try SearchSetParityTests.server(path) }
    static func kit(_ path: String) throws -> String { try SearchSetParityTests.kit(path) }
    static func web(_ path: String) throws -> String { try SearchSetParityTests.web(path) }

    static let person = "Analytics/PersonAnalyticsView.swift"
    static let graph = "Analytics/PersonCoMentionGraphView.swift"
    static let references = "Analytics/CrossReferenceAnalyticsView.swift"
    static let labels = "Analytics/RankingChartLabels.swift"
    static let personServer = "Sources/FRUSLightAPI/PersonAnalytics.swift"
    static let referencesServer = "Sources/FRUSLightAPI/CrossReferenceAnalytics.swift"

    /// Each pair: the app's file and line, and the server's file and line.
    static func expect(_ pairs: [(app: String, appLine: String, server: String, serverLine: String)]) throws {
        var read: [String: String] = [:]
        for pair in pairs {
            let app = try read[pair.app] ?? Self.app(pair.app)
            read[pair.app] = app
            let server = try read[pair.server] ?? Self.server(pair.server)
            read[pair.server] = server
            #expect(app.contains(NoteViewParityTests.flattened(pair.appLine)), "\(pair.app) holds \(pair.appLine)")
            #expect(server.contains(NoteViewParityTests.flattened(pair.serverLine)), "\(pair.server) holds \(pair.serverLine)")
        }
    }

    @Test func personAnalyticsRulesAreTheApps() throws {
        let (p, s, g) = (Self.person, Self.personServer, Self.graph)
        try Self.expect([
            (p, "private static let maxComparisonPeople = 5", s, "static let maxComparisonPeople = 5"),
            (p, "private static let rankingLimit = 15", s, "static let rankingLimit = 15"),
            (p, "let lo = min(yearRangeStart, yearRangeEnd) let hi = max(yearRangeStart, yearRangeEnd) return lo...hi",
             s, "let lo = min(start, end) let hi = max(start, end) return lo...hi"),
            (p, "yearRangeStart != 1861 || yearRangeEnd != corpusMaxYear", s, "start != 1861 || end != corpusMaxYear"),
            (p, "private var atComparisonCap: Bool { selectedPeople.count >= Self.maxComparisonPeople }",
             s, "var atComparisonCap: Bool { selectedPeople.count >= Self.maxComparisonPeople }"),
            (p, "private var isTwoPersonComparison: Bool { selectedPeople.count == 2 }", s, "var isTwoPersonComparison: Bool { selectedPeople.count == 2 }"),
            (p, "Dictionary(uniqueKeysWithValues: selectedPeople.map { ($0.rollupId, $0.canonicalName) })",
             s, "Dictionary(uniqueKeysWithValues: selectedPeople.map { ($0.rollupId, $0.name) })"),
            (p, """
                let base: [PersonTrajectoryPoint]
                if isNormalized {
                    base = PersonAnalyticsMath.sharePoints(
                        mentioningDocs: mentioningDocs, totals: datedTotals,
                        names: selectedNames, range: yearRange)
                } else {
                    base = PersonAnalyticsMath.rawPoints(
                        trajectories: rawTrajectories, names: selectedNames, range: yearRange)
                }
                return byDecade ? PersonAnalyticsMath.bucketByDecade(base, isShare: isNormalized) : base
                """, s, """
                let base: [PersonTrajectoryPoint]
                if isNormalized {
                    base = PersonAnalyticsMath.sharePoints(
                        mentioningDocs: mentioningDocs, totals: datedTotals,
                        names: selectedNames, range: yearRange)
                } else {
                    base = PersonAnalyticsMath.rawPoints(
                        trajectories: rawTrajectories, names: selectedNames, range: yearRange)
                }
                return byDecade ? PersonAnalyticsMath.bucketByDecade(base, isShare: isNormalized) : base
                """),
            (p, "let plottedByPerson = Dictionary(grouping: trajectoryPoints, by: { $0.rollupId })",
             s, "let plottedByPerson = Dictionary(grouping: trajectoryPoints, by: { $0.rollupId })"),
            (p, """
                let points = (plottedByPerson[person.rollupId] ?? []).sorted { $0.year < $1.year }.map { point in
                    let years = PersonAnalyticsMath.sourceYears(
                        forPeriod: point.year, byDecade: byDecade, range: yearRange)
                    let mentions = years.reduce(0) { $0 + (rawTrajectories[person.rollupId]?[$1] ?? 0) }
                """, s, """
                let points = (plottedByPerson[person.rollupId] ?? []).sorted { $0.year < $1.year }.map { point in
                    let years = PersonAnalyticsMath.sourceYears(
                        forPeriod: point.year, byDecade: byDecade, range: yearRange)
                    let mentions = years.reduce(0) { $0 + (rawTrajectories[person.rollupId]?[$1] ?? 0) }
                """),
            (p, """
                let docs = years.compactMap { mentioningDocs[person.rollupId]?[$0] }
                let totals = years.compactMap { datedTotals[$0] }
                return (period: point.year,
                        mentions: mentions,
                        mentioningDocs: docs.isEmpty ? nil : docs.reduce(0, +),
                        datedTotal: totals.isEmpty ? nil : totals.reduce(0, +),
                        plotted: point.value)
                """, s, """
                let docs = years.compactMap { mentioningDocs[person.rollupId]?[$0] }
                let totals = years.compactMap { datedTotals[$0] }
                return (period: point.year,
                        mentions: mentions,
                        mentioningDocs: docs.isEmpty ? nil : docs.reduce(0, +),
                        datedTotal: totals.isEmpty ? nil : totals.reduce(0, +),
                        plotted: point.value)
                """),
            (p, "return (rollupId: person.rollupId, name: person.canonicalName, points: points)",
             s, "return (rollupId: person.rollupId, name: person.name, points: points)"),
            (p, """
                let base = PersonRelationshipMath.points(timeline: relationshipTimeline, range: yearRange)
                return byDecade ? PersonRelationshipMath.bucketByDecade(base) : base
                """, s, """
                let base = PersonRelationshipMath.points(timeline: relationshipTimeline, range: yearRange)
                return byDecade ? PersonRelationshipMath.bucketByDecade(base) : base
                """),
            (p, "guard byDecade, isNormalized else { return [] }", s, "guard byDecade, isNormalized else { return [] }"),
            (p, "indexedVolumeCount: appState.indexedVolumeIds.count, yearRange: yearRangeStart...yearRangeEnd,",
             s, "indexedVolumeCount: indexedVolumeCount, yearRange: start...end,"),
            (p, "appliesDocumentDating: false, valueMode: valueMode, extraCaveats: [", s, "appliesDocumentDating: false, valueMode: valueMode, extraCaveats: ["),
            (p, "] + extra, // PV-1", s, "] + extra, sources: [.frusText, .ohPeopleRegister],"),
            (p, "sources: [.frusText, .ohPeopleRegister]", s, "sources: [.frusText, .ohPeopleRegister]"),
            // The statements each export writes: the ranking's, the trajectories' with the decade caveat on the CSV alone,
            // and the relationship's.
            (p, "personProvenance(figureTitle: title, periodGrain: nil, valueMode: nil)", s, "statement(answer.ranking.heading, nil, nil, [])"),
            (p, "personProvenance(figureTitle: title, periodGrain: periodGrainLabel, valueMode: normalization.pickerLabel, extra: decadeShareCaveat))",
             s, "statement(answer.comparison.heading, periodGrain, ask.normalization.pickerLabel, extra))"),
            (p, "personProvenance(figureTitle: title, periodGrain: periodGrainLabel, valueMode: normalization.pickerLabel), chartHeight: 420)",
             s, "let extra = figure ? [] : PersonAnalyticsView.decadeShareCaveat("),
            (p, "deliver(table, personProvenance(figureTitle: title, periodGrain: periodGrainLabel, valueMode: nil))",
             s, "statement(relationship.heading, periodGrain, nil, [])"),
            // The queries, in the view's order.
            (p, "store.topPeopleByMentions(inYearRange: range, limit: Self.rankingLimit, volumeIds: scopeVolumeIds)",
             s, "store.topPeopleByMentions(inYearRange: range, limit: PersonAnalyticsView.rankingLimit, volumeIds: scope)"),
            (p, "async let raw = store.mentionTrajectories(rollupIds: ids, volumeIds: scopeVolumeIds) async let docs = store.mentioningDocumentTrajectories(rollupIds: ids, volumeIds: scopeVolumeIds) async let totals = store.datedDocumentTotalsByYear(volumeIds: scopeVolumeIds)",
             s, "async let raw = store.mentionTrajectories(rollupIds: ids, volumeIds: scope) async let documents = store.mentioningDocumentTrajectories(rollupIds: ids, volumeIds: scope)"),
            (p, "store.datedDocumentTotalsByYear(volumeIds: scopeVolumeIds)", s, "store.datedDocumentTotalsByYear(volumeIds: scope)"),
            (p, "let a = selectedPeople[0].rollupId let b = selectedPeople[1].rollupId",
             s, "ask.people.count == 2 ? try await relationship(ask.people[0].rollupId, ask.people[1].rollupId,"),
            (p, "store.coMentionTimeline(rollupA: a, rollupB: b, volumeIds: scopeVolumeIds)", s, "store.coMentionTimeline(rollupA: a, rollupB: b, volumeIds: scope)"),
            (p, "searchResults = (try? await store.rollupsMatchingName(q, limit: 20)) ?? []",
             s, "try await served.persons.rollupsMatchingName(text, limit: 20)"),
            (p, "let q = searchText.trimmingCharacters(in: .whitespaces)", s, "(try query.single(\"q\") ?? \"\").trimmingCharacters(in: .whitespaces)"),
            (p, """
                ranking.map { (id: String($0.rollupId), name: $0.canonicalName, shortSuffix: String($0.rollupId)) })
                """, s, """
                ranking.map { (id: String($0.rollupId), name: $0.canonicalName, shortSuffix: String($0.rollupId)) })
                """),
            // The network: the kit's two halves, the label limit, the spokes and the legend's sentence.
            (g, "let ego = try await PersonCoMentionNetwork.nodes( focusRollupId: focusRollupId, focusName: focusName, store: store, volumeIds: volumeIds)",
             s, "let ego = try await PersonCoMentionNetwork.nodes( focusRollupId: focus.rollupId, focusName: focus.name, store: store, volumeIds: volumeIds)"),
            (g, "edges = try await PersonCoMentionNetwork.edges(among: ego.nodes, store: store, volumeIds: volumeIds)",
             s, "let edges = try await PersonCoMentionNetwork.edges(among: ego.nodes, store: store, volumeIds: volumeIds)"),
            (g, "static let labelLimit = 16", s, "static let labelLimit = 16"),
            (g, "GraphNodeLabels.shortLabel(name(for: rollupId), limit: Self.labelLimit)", s, "GraphNodeLabels.shortLabel(node.name, limit: labelLimit)"),
            (g, "let isSpoke = edge.a == focusId || edge.b == focusId", s, "isSpoke: $0.a == focus.rollupId || $0.b == focus.rollupId"),
            (g, "if vm.capApplied { Text(vm.capDisclosure)", s, "footer: capApplied ? PersonCoMentionNetwork.capDisclosure("),
            (g, "} else if vm.partners.isEmpty {", s, "state: partners.isEmpty ? \"empty\" : \"graph\","),
        ])
    }

    @Test func crossReferenceAnalyticsRulesAreTheApps() throws {
        let (x, s, l) = (Self.references, Self.referencesServer, Self.labels)
        try Self.expect([
            (x, "private static let rankingLimit = 15", s, "static let rankingLimit = 15"),
            (x, "private static let landmarkLimit = 15", s, "static let landmarkLimit = 15"),
            (x, "private static let matrixVolumeLimit = 15", s, "static let matrixVolumeLimit = 15"),
            (x, "yearRangeStart != 1861 || yearRangeEnd != corpusMaxYear", s, "start != 1861 || end != corpusMaxYear"),
            (x, "yearRangeIsCustom ? yearRange : nil",
             s, "yearRangeIsCustom(start: start, end: end, corpusMaxYear: corpusMaxYear) ? PersonAnalyticsView.yearRange(start: start, end: end) : nil"),
            // `loadAll()`, in its order.
            (x, "store.excludedBrokenCount(yearRange: range, volumeIds: scope)", s, "store.excludedBrokenCount(yearRange: range, volumeIds: scope)"),
            (x, "store.topDocumentsByInDegree(limit: Self.rankingLimit, yearRange: range, volumeIds: scope)",
             s, "store.topDocumentsByInDegree(limit: CrossReferenceAnalyticsView.rankingLimit, yearRange: range, volumeIds: scope)"),
            (x, "store.documentTitleFacts( for: topDocs.map { (volumeId: $0.volumeId, documentId: $0.documentId) })",
             s, "store.documentTitleFacts( for: topDocs.map { (volumeId: $0.volumeId, documentId: $0.documentId) })"),
            (x, "CrossReferenceTargetLabel.resolve( volumeId: $0.volumeId, documentId: $0.documentId, in: rankingFacts, volumeTitle: volumeTitle($0.volumeId))",
             s, "CrossReferenceTargetLabel.resolve( volumeId: $0.volumeId, documentId: $0.documentId, in: rankingFacts, volumeTitle: volumeTitle($0.volumeId))"),
            (x, "store.resolvedInDegrees(yearRange: range, volumeIds: scope)", s, "store.resolvedInDegrees(yearRange: range, volumeIds: scope)"),
            (x, "store.resolvedOutDegrees(yearRange: range, volumeIds: scope)", s, "store.resolvedOutDegrees(yearRange: range, volumeIds: scope)"),
            (x, "distribution = CrossReferenceStats.degreeDistribution(inDeg) outDistribution = CrossReferenceStats.degreeDistribution(outDeg)",
             s, "let distribution = CrossReferenceStats.degreeDistribution(inDeg) let outDistribution = CrossReferenceStats.degreeDistribution(outDeg)"),
            (x, "store.volumeLevelConnections(limitToVolumeIds: scope, yearRange: range)", s, "store.volumeLevelConnections(limitToVolumeIds: scope, yearRange: range)"),
            (x, "let topVolumes = CrossReferenceStats.topVolumesByTotalDegree(edges, limit: Self.matrixVolumeLimit) let volumeSet = Set(topVolumes)",
             s, "let topVolumes = CrossReferenceStats.topVolumesByTotalDegree(edges, limit: CrossReferenceAnalyticsView.matrixVolumeLimit) let volumeSet = Set(topVolumes)"),
            (x, ".filter { volumeSet.contains($0.sourceVolumeId) && volumeSet.contains($0.targetVolumeId) }",
             s, ".filter { volumeSet.contains($0.sourceVolumeId) && volumeSet.contains($0.targetVolumeId) }"),
            (x, "matrixMaxCount = cells.map(\\.count).max() ?? 0", s, "matrixMaxCount: cells.map(\\.count).max() ?? 0"),
            (x, "store.resolvedCitationEdges(yearRange: range, volumeIds: scope)", s, "store.resolvedCitationEdges(yearRange: range, volumeIds: scope)"),
            (x, "PageRank.compute(edges: citationEdges)", s, "PageRank.compute(edges: citationEdges)"),
            (x, "let topScored = Array(scored.prefix(Self.landmarkLimit))", s, "let topScored = Array(scored.prefix(CrossReferenceAnalyticsView.landmarkLimit))"),
            (x, "let landmarkKeys = topScored.map { (volumeId: $0.key.volumeId, documentId: $0.key.documentId) }",
             s, "let landmarkKeys = topScored.map { (volumeId: $0.key.volumeId, documentId: $0.key.documentId) }"),
            // A row's label (`CrossReferenceTargetLabel`).
            (x, "if let facts { return DocumentDisplayTitle.text(facts, documentId: documentId) }",
             s, "if let facts { return DocumentDisplayTitle.text(facts, documentId: documentId) }"),
            (x, #"guard let number = CitableDocumentNumber.fromDocumentId(documentId) else { return "\(documentId) — \(volumeTitle)" }"#,
             s, #"guard let number = CitableDocumentNumber.fromDocumentId(documentId) else { return "\(documentId) — \(volumeTitle)" }"#),
            (x, #"return "\(prefix) \(number) — \(volumeTitle)""#, s, #"return "\(prefix) \(number) — \(volumeTitle)""#),
            (x, #"let found = facts["\(volumeId)/\(documentId)"] return (text(facts: found, documentId: documentId, volumeTitle: volumeTitle), found != nil)"#,
             s, #"let found = facts["\(volumeId)/\(documentId)"] return (text(facts: found, documentId: documentId, volumeTitle: volumeTitle), found != nil)"#),
            // The tables and the chart's labels.
            (x, "Dictionary(outDistribution.map { ($0.label, $0.documentCount) }, uniquingKeysWith: { first, _ in first })",
             s, "Dictionary(series.outDistribution.map { ($0.label, $0.documentCount) }, uniquingKeysWith: { first, _ in first })"),
            (x, "outDegreeDocuments: showOutDegree ? outByLabel[$0.label] : nil) })", s, "outDegreeDocuments: showOutDegree ? outByLabel[$0.label] : nil) })"),
            (x, "(id: row.id, name: row.label, shortSuffix: row.documentId)",
             s, "(id: \"\\(row.document.volumeId)/\\(row.document.documentId)\", name: row.document.label, shortSuffix: row.document.documentId)"),
            (x, "var id: String { \"\\(volumeId)/\\(documentId)\" }", s, "let id = \"\\(row.document.volumeId)/\\(row.document.documentId)\""),
            (x, "(sourceId: cell.sourceVolumeId, sourceTitle: volumeTitle(cell.sourceVolumeId), targetId: cell.targetVolumeId, targetTitle: volumeTitle(cell.targetVolumeId), count: cell.count)",
             s, "(sourceId: cell.sourceVolumeId, sourceTitle: volumeTitle(cell.sourceVolumeId), targetId: cell.targetVolumeId, targetTitle: volumeTitle(cell.targetVolumeId), count: cell.count)"),
            (x, "private var maxLandmarkScore: Double { landmarks.map(\\.score).max() ?? 1 }", s, "let maxLandmarkScore = series.landmarks.map(\\.score).max() ?? 1"),
            (x, "influenceBar(fraction: maxLandmarkScore > 0 ? row.score / maxLandmarkScore : 0)", s, "fraction: maxLandmarkScore > 0 ? row.score / maxLandmarkScore : 0)"),
            (x, "Text(row.score, format: .number.precision(.significantDigits(2)))", s, "row.score.formatted(.number.precision(.significantDigits(2)).locale(SearchItem.locale))"),
            (x, "volumeId.hasPrefix(\"frus\") ? String(volumeId.dropFirst(4)) : volumeId", s, "volumeId.hasPrefix(\"frus\") ? String(volumeId.dropFirst(4)) : volumeId"),
            (x, "appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId", s, "CorpusAnalyticsRoutes.volumeTitle(volumeId, resources: resources)"),
            (x, "} else if matrixVolumes.count < 2 {", s, "empty: volumes.count < 2"),
            (x, "labels.codes[target] ?? shortVolumeLabel(target)", s, "codes[id] ?? shortVolumeLabel(id)"),
            (x, "labels.rows[source] ?? HeatMatrixRowAxis.label(volumeId: source, entry: nil)", s, "rows[id] ?? HeatMatrixRowAxis.label(volumeId: id, entry: nil)"),
            (x, "let columns = entries.map { HeatMatrixColumnAxis.column(volumeId: $0.id, entry: $0.entry) }",
             s, "matrixColumnCodes(entries.map { HeatMatrixColumnAxis.column(volumeId: $0.id, entry: $0.entry) })"),
            (x, "if excludedBrokenCount > 0 {", s, "excludedBrokenCaption: excluded > 0"),
            // The statement every export carries.
            (x, "appliesDocumentDating: false, valueMode: nil, extraCaveats: [excluded, sameVolume] + extra",
             s, "appliesDocumentDating: false, valueMode: nil, extraCaveats: [excluded, sameVolume] + extra"),
            (x, "Int64(Self.matrixVolumeLimit)),", s, "Int64(Self.matrixVolumeLimit)),"),
            (x, "axisLabel: String(localized: \"crossRefAnalytics.export.axis.matrix\", defaultValue: \"Cross-volume citation counts\"), extra: matrixCaveats))",
             s, "appWords(\"crossRefAnalytics.export.axis.matrix\", \"Cross-volume citation counts\"), CrossReferenceAnalyticsView.matrixCaveats))"),
            // The heat matrix's labels (`RankingChartLabels.swift`).
            (l, #"if let numeral = firstVolumeNumeral(in: c.title) { return "\(years) \(numeral)" }"#, s, #"if let numeral = firstVolumeNumeral(in: c.title) { return "\(years) \(numeral)" }"#),
            (l, #"if let word = matrixTopicWords(c.topic).first { return "\(years) \(String(word.prefix(6)))" }"#,
             s, #"if let word = matrixTopicWords(c.topic).first { return "\(years) \(String(word.prefix(6)))" }"#),
            (l, #"guard let first = words.first else { return "\(years) \(numeral)" } return "\(years) \(numeral) \(String(first.prefix(6)))""#,
             s, #"guard let first = words.first else { return "\(years) \(numeral)" } return "\(years) \(numeral) \(String(first.prefix(6)))""#),
            (l, #"if let first = words.first { s += " \(String(first.prefix(6)))" } if let second = words.dropFirst().first { s += " \(String(second.prefix(6)))" }"#,
             s, #"if let first = words.first { s += " \(String(first.prefix(6)))" } if let second = words.dropFirst().first { s += " \(String(second.prefix(6)))" }"#),
            (l, "let code = (baseCounts[b.code] ?? 0) > 1 ? expanded(c) : b.code", s, "let code = (baseCounts[b.code] ?? 0) > 1 ? expanded(c) : b.code"),
            (l, #"if (provisionalCounts[code] ?? 0) > 1 { var suffix = c.id if suffix.hasPrefix("frus") { suffix = String(suffix.dropFirst(4)) } if suffix.hasPrefix(c.subseries) { suffix = String(suffix.dropFirst(c.subseries.count)) } suffix = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "-_ ")) let years = matrixYearCode(c.subseries) result[c.id] = suffix.isEmpty ? years : "\(years) \(suffix)""#,
             s, #"if (provisionalCounts[code] ?? 0) > 1 { var suffix = c.id if suffix.hasPrefix("frus") { suffix = String(suffix.dropFirst(4)) } if suffix.hasPrefix(c.subseries) { suffix = String(suffix.dropFirst(c.subseries.count)) } suffix = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "-_ ")) let years = matrixYearCode(c.subseries) result[c.id] = suffix.isEmpty ? years : "\(years) \(suffix)""#),
            (l, #"let parts = subseries.split(separator: "-", maxSplits: 1) if parts.count == 2 { return "\u{2019}\(parts[0].suffix(2))–\(parts[1].suffix(2))" } return "\u{2019}\(subseries.suffix(2))""#,
             s, #"let parts = subseries.split(separator: "-", maxSplits: 1) if parts.count == 2 { return "\u{2019}\(parts[0].suffix(2))–\(parts[1].suffix(2))" } return "\u{2019}\(subseries.suffix(2))""#),
            (l, #"guard let regex = try? NSRegularExpression(pattern: "Volumes?\\s+(E[–-][0-9]+|[IVXLCDM]+)\\b") else { return nil }"#,
             s, #"guard let regex = try? NSRegularExpression(pattern: "Volumes?\\s+(E[–-][0-9]+|[IVXLCDM]+)\\b") else { return nil }"#),
            (l, "guard let m = regex.firstMatch(in: title, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else { return nil } return ns.substring(with: m.range(at: 1))",
             s, "guard let m = regex.firstMatch(in: title, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else { return nil } return ns.substring(with: m.range(at: 1))"),
            (l, #"let stop: Set<String> = ["the", "of", "and", "to", "a", "an", "in", "on", "for"]"#, s, #"let stop: Set<String> = ["the", "of", "and", "to", "a", "an", "in", "on", "for"]"#),
            (l, #"let tokens = topic .replacingOccurrences(of: "…", with: " ") .components(separatedBy: CharacterSet.alphanumerics.inverted) .filter { $0.count >= 2 } let words = Array(tokens.drop { stop.contains($0.lowercased()) }) guard words.count >= 2, words[0].lowercased() == "documents", words[1].lowercased() == "on" else { return words }"#,
             s, #"let tokens = topic .replacingOccurrences(of: "…", with: " ") .components(separatedBy: CharacterSet.alphanumerics.inverted) .filter { $0.count >= 2 } let words = Array(tokens.drop { stop.contains($0.lowercased()) }) guard words.count >= 2, words[0].lowercased() == "documents", words[1].lowercased() == "on" else { return words }"#),
            (l, "let rest = Array(words.dropFirst(2).drop { stop.contains($0.lowercased()) }) return rest.isEmpty ? words : rest",
             s, "let rest = Array(words.dropFirst(2).drop { stop.contains($0.lowercased()) }) return rest.isEmpty ? words : rest"),
            (l, "let subseries = entry?.subseries ?? \"\" let title = entry?.title ?? volumeId let distilled = ChronologyViewModel.distilledVolumeLabel(volumeId: volumeId, subseries: subseries, title: title)",
             s, "let subseries = entry?.subseries ?? \"\" let title = entry?.title ?? volumeId let distilled = VolumeLabels.distilledVolumeLabel(volumeId: volumeId, subseries: subseries, title: title)"),
            (l, #"let topic = distilled.contains(" · ") ? String(distilled.components(separatedBy: " · ").first ?? "") : """#,
             s, #"let topic = distilled.contains(" · ") ? String(distilled.components(separatedBy: " · ").first ?? "") : """#),
            (l, #"ChronologyViewModel.distilledVolumeLabelParts(volumeId: volumeId, subseries: entry?.subseries ?? "", title: entry?.title ?? "")"#,
             s, #"VolumeLabels.distilledVolumeLabelParts(volumeId: volumeId, subseries: entry?.subseries ?? "", title: entry?.title ?? "")"#),
        ])
    }

    /// Every word the two servers' files write through `appWords`, each where the app's source writes it under its key.
    @Test func theAppsWordsAreTheServers() throws {
        let (p, c, g, x, v) = (Self.person, "Analytics/PersonAnalyticsCopy.swift", Self.graph, Self.references, "Analytics/AnalyticsView.swift")
        let chrome = "Analytics/AnalyticsChartChrome.swift"
        // The app's file, the key, the app's default value, and the server's where it differs.
        let words: [(file: String, key: String, value: String, mirror: String?)] = [
            (v, "analytics.axis.decade", "Decade", nil),
            (v, "analytics.axis.year", "Year", nil),
            (chrome, "analytics.scope.wholeCorpus", "Whole corpus", nil),
            (chrome, "analytics.scope.custom", "Selected volumes", nil),
            (c, "personAnalytics.ranking.subtitle",
             "Top people by tagged mentions in dated documents, \\(String(years.lowerBound))–\\(String(years.upperBound)). Select a person to compare them below.", nil),
            (p, "personAnalytics.export.caveat.decadeShare", "Decade shares: the share plotted for a decade is the average of the yearly shares for the years this person was tagged. Years with no tags are dropped from that average rather than counted as zero. The “Dated documents in period” column, by contrast, sums every year of the decade. So dividing this file’s columns gives the decade’s own share, which can be far lower than the plotted value. Someone tagged in one year of a decade plots that single year’s share for the whole decade. Use the columns for the decade’s share and the plotted value for the average across the tagged years. They answer different questions.", nil),
            (p, "personAnalytics.export.axis.ranking", "Ranked by mentions", nil),
            (p, "personAnalytics.export.caveat.dated", "Population: person mentions are counted in dated documents only. The Corpus Analytics charts fall back to the volume’s start year for undated documents; these charts do not. Counts from the two views are therefore not directly comparable.", nil),
            (p, "personAnalytics.export.caveat.identity", "Identity: mentions are grouped by the app’s person authority, so spelling variants and name forms for one individual merge into a single identity. The person id column is that grouped identity.", nil),
            (p, "personAnalytics.ranking.heading", "Most-Mentioned People", nil),
            (p, "personAnalytics.comparison.heading", "Mention Trajectories", nil),
            (p, "personAnalytics.relationship.heading", "Relationship Dynamics", nil),
            (p, "personAnalytics.relationship.subtitle", "How often \\(selectedPeople[0].canonicalName) and \\(selectedPeople[1].canonicalName) are tagged together over time.",
             "How often \\(a) and \\(b) are tagged together over time."),
            (p, "personAnalytics.axis.year", "Year", nil),
            (p, "personAnalytics.axis.coMentions", "Shared documents", nil),
            (p, "personAnalytics.relationship.empty.title", "No Shared Documents", nil),
            (p, "personAnalytics.relationship.empty.detail", "These two people are never co-mentioned in a dated document within this year range.", nil),
            (p, "personAnalytics.relationship.caption", "Co-occurrences in dated documents only; documents tagging mentions of both people. Undated documents cannot be placed on the year axis.", nil),
            (p, "personAnalytics.axis.mentionsValue", "\\(row.mentionCount) mentions", "\\(grouped(row.mentionCount)) mentions"),
            (p, "personAnalytics.ranking.empty.title", "No People in Range", nil),
            (p, "personAnalytics.ranking.empty.detail", "No dated documents in this year range mention indexed people. Widen the range or index more volumes.", nil),
            (p, "personAnalytics.search.cap", "Comparison is limited to \\(Self.maxComparisonPeople) people. Remove one to add another.",
             "Comparison is limited to \\(maxComparisonPeople) people. Remove one to add another."),
            (p, "personAnalytics.comparison.empty", "Add up to \\(Self.maxComparisonPeople) people — from the ranking above or the search field — to compare how often each is tagged over time.",
             "Add up to \\(maxComparisonPeople) people — from the ranking above or the search field — to compare how often each is tagged over time."),
            (p, "personAnalytics.axis.share", "% of documents", nil),
            (p, "personAnalytics.axis.mentions", "Mentions", nil),
            (p, "personAnalytics.comparison.noData.title", "No Dated Mentions", nil),
            (p, "personAnalytics.comparison.noData.detail", "The selected people have no mentions in dated documents within this year range.", nil),
            (p, "personAnalytics.comparison.caption", "Counts tagged mentions in dated documents only; tagged mentions in undated documents cannot be placed on the year axis.", nil),
            (g, "personCoMention.node.a11yValue", "\\(node.sharedWithFocus) shared documents with \\(vm.focusName)",
             "\\(grouped(node.sharedWithFocus)) shared documents with \\(focusName)"),
            (g, "personCoMention.info.shared", "\\(shared) shared document\\(shared == 1 ? \"\" : \"s\") with \\(vm.focusName)",
             "\\(grouped(shared)) shared document\\(shared == 1 ? \"\" : \"s\") with \\(focusName)"),
            (g, "personCoMention.empty.title", "No Co-Mentions", nil),
            (g, "personCoMention.empty.detail", "\\(vm.focusName) is not co-mentioned with any other indexed person. Index more volumes, or pick a more frequently tagged focus person.",
             "\\(focusName) is not co-mentioned with any other indexed person. Index more volumes, or pick a more frequently tagged focus person."),
            (g, "personCoMention.cap.all", "Showing all \\(vm.partners.count) co-mentioned people, sized by shared documents. Edge thickness = documents mentioning both.",
             "Showing all \\(grouped(partners.count)) co-mentioned people, sized by shared documents. Edge thickness = documents mentioning both."),
            (x, "crossRefAnalytics.export.axis.inDegree", "Ranked by inbound references", nil),
            (x, "crossRefAnalytics.export.axis.degree", "Grouped by references received", nil),
            (x, "crossRefAnalytics.export.axis.matrix", "Cross-volume citation counts", nil),
            (x, "crossRefAnalytics.export.axis.pageRank", "Ranked by PageRank influence score", nil),
            (x, "crossRefAnalytics.export.caveat.pageRank", "Score: an offline PageRank over the resolved citation graph — a structural measure of how often a document is cited by other well-cited documents. It is a measure of editorial handling, not a claim of historical importance.", nil),
            (x, "crossRefAnalytics.export.caveat.excluded.one", "Unresolvable references: %@ cross-reference is excluded from this analysis — a reference in the printed volumes that points to a document, page, or volume not present in this corpus.", nil),
            (x, "crossRefAnalytics.export.caveat.excluded.many", "Unresolvable references: %@ cross-references are excluded from this analysis — references in the printed volumes that point to a document, page, or volume not present in this corpus.", nil),
            (x, "crossRefAnalytics.export.caveat.sameVolume", "Attribution: the document-level figures count same-volume references, including resolved page references, toward the document’s own volume. The volume heat matrix counts only citations between different volumes, so it leaves same-volume references out.", nil),
            (x, "crossRefAnalytics.export.caveat.matrixLimit %lld", "Selection: the matrix covers the %lld volumes with the most references in and out. The CSV lists only pairs with at least one reference between them. The figure draws the whole grid and leaves the rest of the cells blank.", nil),
            (x, "crossRefAnalytics.export.caveat.matrixAxes", "Axes: rows cite columns. In the figure the column headings are abbreviated volume codes and the row labels are shortened descriptive labels; both volumes’ full titles appear in this CSV.", nil),
            (x, "crossRefAnalytics.ranking.heading", "Most-Referenced Documents", nil),
            (x, "crossRefAnalytics.distribution.heading", "Citation Degree Distribution", nil),
            (x, "crossRefAnalytics.matrix.heading", "Volume Citation Heat Matrix", nil),
            (x, "crossRefAnalytics.landmarks.heading", "Landmark Documents (Influence)", nil),
            (x, "crossRefAnalytics.resolvedCaption", "The most-referenced, degree, and PageRank charts count same-volume references, including resolved page references, toward the document’s own volume. Set a year range or scope and they count citations made by documents in that era or scope. The heat matrix counts only connections between different volumes, so it leaves same-volume citations out.", nil),
            (x, "crossRefAnalytics.excludedBrokenCaption.one", "%@ unresolvable reference is excluded from this analysis — a cross-reference in the printed volumes that points to a document, page, or volume not present in the corpus.", nil),
            (x, "crossRefAnalytics.excludedBrokenCaption.many", "%@ unresolvable references are excluded from this analysis — cross-references in the printed volumes that point to a document, page, or volume not present in the corpus.", nil),
            (x, "crossRefAnalytics.section.empty.title", "No Data", nil),
            (x, "crossRefAnalytics.ranking.subtitle", "Top documents by inbound citation count (in-degree). Select a document to open it.", nil),
            (x, "crossRefAnalytics.axis.inDegreeValue", "\\(row.inDegree) inbound citations", "\\(grouped(row.inDegree)) inbound citations"),
            (x, "crossRefAnalytics.ranking.empty", "No resolved cross-references are indexed yet. Index more volumes to build the citation network.", nil),
            (x, "crossRefAnalytics.distribution.subtitle", "How many documents have each inbound-citation count — a few landmark documents and a long tail. Toggle the out-degree overlay to compare how many citations documents make.", nil),
            (x, "crossRefAnalytics.distribution.empty", "No resolved cross-references to chart.", nil),
            (x, "crossRefAnalytics.landmarks.subtitle", "Ranked by a PageRank score computed on this device over the citations the app resolved. These are the documents a reader who follows citations would keep returning to. The score measures position in the citation network, not historical importance. Select one to open it.", nil),
            (x, "crossRefAnalytics.landmarks.empty", "No resolved citation graph to rank yet.", nil),
            (x, "crossRefAnalytics.matrix.subtitle", "Citations between the \\(Self.matrixVolumeLimit) volumes with the most references in and out. Rows cite columns. Darker cells mean more references. Select a volume label to open it.",
             "Citations between the \\(grouped(Self.matrixVolumeLimit)) volumes with the most references in and out. Rows cite columns. Darker cells mean more references. Select a volume label to open it."),
            (x, "crossRefAnalytics.matrix.cell.help", "\\(shortVolumeLabel(source)) → \\(shortVolumeLabel(target)): \\(count) references",
             "\\(shortVolumeLabel(source)) → \\(shortVolumeLabel(target)): \\(grouped(count)) references"),
            (x, "crossRefAnalytics.matrix.cell.none", "\\(shortVolumeLabel(source)) → \\(shortVolumeLabel(target)): no references", nil),
            (x, "crossRefAnalytics.matrix.cell.axLabel", "\\(labels.titles[source] ?? source) cites \\(labels.titles[target] ?? target): \\(count) references",
             "\\(volumeTitle(source)) cites \\(volumeTitle(target)): \\(grouped(count)) references"),
            (x, "crossRefAnalytics.matrix.cell.axLabel.none", "\\(labels.titles[source] ?? source) cites \\(labels.titles[target] ?? target): no references",
             "\\(volumeTitle(source)) cites \\(volumeTitle(target)): no references"),
            (x, "crossRefAnalytics.matrix.empty", "Not enough cross-volume references are indexed to build a heat matrix. Index more volumes.", nil),
            (x, "crossRefAnalytics.matrix.legend.low", "Fewer", nil),
            (x, "crossRefAnalytics.matrix.legend.high", "More", nil),
            (x, "crossRefAnalytics.matrix.legend.max", "(max \\(matrixMaxCount))", "(max \\(grouped(series.matrixMaxCount)))"),
            (x, "crossRefAnalytics.row.documentPrefix", "Document", nil),
        ]
        var read: [String: String] = [:]
        let servers = try [Self.server(Self.personServer), Self.server(Self.referencesServer)].joined(separator: " ")
        for word in words {
            let app = try read[word.file] ?? Self.app(word.file)
            read[word.file] = app
            #expect(NoteViewParityTests.writes(app, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(servers.contains("appWords(\"\(word.key)\", \"\(word.mirror ?? word.value)\")"), "the server writes \(word.key)")
        }
        // Every word the two files write is one of these.
        let keys = Set(words.map(\.key))
        let written = servers.components(separatedBy: "appWords(\"").dropFirst().compactMap { $0.split(separator: "\"", maxSplits: 1).first.map(String.init) }
        #expect(!written.isEmpty && written.allSatisfy(keys.contains), "\(written.filter { !keys.contains($0) })")
    }

    /// What the browser app mirrors of the app's canvases, line beside line: the co-mention network's layout, discs and
    /// edges, the comparison's cap and matches, Values' key, and the heat matrix's shading and legend.
    @Test func theBrowsersRulesAreTheApps() throws {
        let rules = try Self.web("analytics/personReferenceRules.ts")
        let screen = try Self.web("analytics/PersonAnalyticsScreen.tsx")
        let graph = try Self.app(Self.graph)
        let person = try Self.app(Self.person)
        let references = try Self.app(Self.references)
        let pairs: [(app: String, appLine: String, web: String, webLine: String)] = [
            (graph, "let k_s: CGFloat = 0.008 let L0: CGFloat = 150 let k_r: CGFloat = 6_000 let damping: CGFloat = 0.82 let pad: CGFloat = 48",
             rules, "const kS = 0.008; const restLength = 150; const kR = 6_000; const damping = 0.82; const pad = 48;"),
            (graph, "let f = k_s * (d - L0)", rules, "const f = kS * (d - restLength);"),
            (graph, "let f = k_r / (d * d)", rules, "const f = kR / (d * d);"),
            (graph, "v.dx = (v.dx + f.dx) * damping v.dy = (v.dy + f.dy) * damping p.x = max(pad, min(size.width - pad, p.x + v.dx)) p.y = max(pad, min(size.height - pad, p.y + v.dy))",
             rules, "v.dx = (v.dx + f.dx) * damping; v.dy = (v.dy + f.dy) * damping; p.x = Math.max(pad, Math.min(size.width - pad, p.x + v.dx)); p.y = Math.max(pad, Math.min(size.height - pad, p.y + v.dy));"),
            (graph, "let r = min(size.width, size.height) * 0.35", rules, "const r = Math.min(size.width, size.height) * 0.35;"),
            (graph, "let angle = 2 * Double.pi * Double(i) / Double(partnerIds.count)", rules, "const angle = (2 * Math.PI * i) / partners.length;"),
            (graph, "if reduceMotion || ids.count <= 3 {", rules, "if (reducedMotion || ids.length <= 3) return runPhysics(ids, focus, answer.edges, current, size, 300);"),
            (graph, "positions: initial, size: size, iterations: 300)", rules, "current, size, 300)"),
            (graph, "static let layoutSteps = 15", rules, "export const layoutSteps = 15;"),
            (graph, "positions: current, size: size, iterations: 20)", rules, "current = runPhysics(ids, focus, answer.edges, current, size, 20);"),
            (graph, "static let focusRadius: CGFloat = 26", rules, "export const focusRadius = 26;"),
            (graph, "let base = 12 + 10 * (CGFloat(sharedWithFocus(for: rollupId)) / CGFloat(maxSharedWithFocus)) return displayedPartnerId == rollupId ? base + 3 : base",
             rules, "const base = 12 + 10 * (shared / maxShared); return displayed === rollupId ? base + 3 : base;"),
            (graph, "var maxSharedWithFocus: Int { max(1, partners.map(\\.sharedWithFocus).max() ?? 1) }",
             rules, "const maxShared = Math.max(1, ...partners.map((node) => node.sharedWithFocus));"),
            (graph, "with: .color(color.opacity(0.2 + weight * 0.5)), lineWidth: 0.5 + weight * 3.5)", rules, "return { width: 0.5 + weight * 3.5, opacity: 0.2 + weight * 0.5 };"),
            (graph, "weight: CGFloat(edge.sharedDocuments) / maxWeight)", rules, "const weight = sharedDocuments / maxWeight;"),
            (person, "private static let maxComparisonPeople = 5", rules, "export const maxComparisonPeople = 5;"),
            (person, "ForEach(searchResults.prefix(6))", rules, "export const shownMatches = 6;"),
            (person, "let idx = selectedPeople.firstIndex { $0.rollupId == rollupId } ?? 0 return ChartSeriesPalette.color(at: idx)",
             rules, "const index = Math.max(0, people.findIndex((person) => person.rollupId === rollupId));"),
            (references, "let opacity = 0.15 + 0.80 * ratio", rules, "return 0.15 + 0.8 * (count / maxCount);"),
            (references, "guard count > 0, matrixMaxCount > 0 else { return Color.secondary.opacity(0.06) }", rules, "value: 0.06 },"),
            (references, "ForEach([0.15, 0.35, 0.55, 0.75, 0.95], id: \\.self)", rules, "export const heatLegendSteps = [0.15, 0.35, 0.55, 0.75, 0.95];"),
            (references, "private static let matrixCellSize: CGFloat = 34", rules, "const size = 34;"),
        ]
        for pair in pairs {
            #expect(pair.app.contains(NoteViewParityTests.flattened(pair.appLine)), "the app holds \(pair.appLine)")
            #expect(pair.web.contains(NoteViewParityTests.flattened(pair.webLine)), "the web holds \(pair.webLine)")
        }
        #expect(try Self.kit("FRUSCoreKit/Analytics/PersonAnalyticsMath.swift").contains("public static let storageKey = \"frus.personAnalytics.normalizationMode\""))
        #expect(screen.contains("const valuesKey = 'frus.personAnalytics.normalizationMode';"))
    }

    /// The app's words the browser app takes, each where the app's source writes it, and in copy.ts's block.
    @Test func theAppsWordsAreTheWebs() throws {
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let (p, g, x) = (Self.person, Self.graph, Self.references)
        let math = "../FRUSCoreKit/Analytics/PersonAnalyticsMath.swift"
        let tables = "../FRUSCoreKit/Analytics/Export/AnalyticsChartTables.swift"
        let words: [(file: String, key: String, value: String, block: String, web: String)] = [
            (p, "personAnalytics.title", "Person Analytics", "personAnalytics", "title"),
            (p, "personAnalytics.unavailable.title", "Person Analytics Unavailable", "personAnalytics", "unavailableTitle"),
            (p, "personAnalytics.unavailable.detail", "The search index is not available. Index at least one volume to enable person analytics.", "personAnalytics", "unavailableDetail"),
            (p, "personAnalytics.mode.picker", "Mode", "personAnalytics", "mode"),
            (p, "personAnalytics.mode.help", "Switch between the trends dashboard (rankings, trajectories, relationship dynamics) and the co-mention network graph.", "personAnalytics", "modeHelp"),
            (p, "personAnalytics.mode.trends", "Trends", "personAnalytics", "trends"),
            (p, "personAnalytics.mode.network", "Network", "personAnalytics", "network"),
            (p, "personAnalytics.axis.person", "Person", "personAnalytics", "person"),
            (p, "personAnalytics.axis.mentions", "Mentions", "personAnalytics", "mentions"),
            (p, "personAnalytics.row.findMentions", "Find all mentions", "personAnalytics", "findMentions"),
            (p, "personAnalytics.search.placeholder", "Add a person to compare…", "personAnalytics", "addPlaceholder"),
            (p, "personAnalytics.decade.toggle", "By decade", "personAnalytics", "byDecade"),
            (p, "personAnalytics.decade.help", "Bucket the trajectory chart by decade instead of by year", "personAnalytics", "byDecadeHelp"),
            (p, "personAnalytics.normalize.picker", "Values", "personAnalytics", "values"),
            (p, "personAnalytics.normalize.help", "Plot raw tagged mention counts, or each person’s share of all dated documents in that period — so a growing corpus doesn’t masquerade as a rising person.", "personAnalytics", "valuesHelp"),
            (math, "personAnalytics.normalize.raw", "Raw count", "personAnalytics", "raw"),
            (math, "personAnalytics.normalize.percent", "% of documents", "personAnalytics", "percent"),
            (p, "personAnalytics.export.relationship", "Export relationship CSV", "personAnalytics", "exportRelationship"),
            (p, "personAnalytics.export.relationship.help", "Export the two-person co-mention series with its method and caveats", "personAnalytics", "exportRelationshipHelp"),
            (p, "personAnalytics.network.focusLabel", "Focus:", "personAnalytics", "focusLabel"),
            (p, "personAnalytics.network.focusNone", "None", "personAnalytics", "focusNone"),
            (p, "personAnalytics.network.searchPlaceholder", "Set focus person…", "personAnalytics", "focusPlaceholder"),
            (p, "personAnalytics.network.noFocus.title", "Pick a Focus Person", "personAnalytics", "noFocusTitle"),
            (p, "personAnalytics.network.noFocus.detail", "Search for a person above to center the co-mention network on them. No people are indexed in this range yet.", "personAnalytics", "noFocusDetail"),
            (p, "personAnalytics.axis.coMentions", "Shared documents", "personAnalytics", "sharedDocuments"),
            (g, "personCoMention.loading", "Loading co-mention network…", "personAnalytics", "loadingNetwork"),
            (g, "personCoMention.error.title", "Graph Error", "personAnalytics", "graphError"),
            (g, "personCoMention.resetView", "Reset View", "personAnalytics", "resetView"),
            (g, "personCoMention.back", "Back", "personAnalytics", "back"),
            (g, "personCoMention.info.explore", "Explore connections", "personAnalytics", "explore"),
            (g, "personCoMention.info.openSearch", "Open in Search", "personAnalytics", "openInSearch"),
            (g, "personCoMention.dock.empty", "Select a person to see their shared documents and connections.", "personAnalytics", "dockEmpty"),
            (g, "personCoMention.legend.focus", "Focus person", "personAnalytics", "legendFocus"),
            (g, "personCoMention.legend.partner", "Co-mentioned (size = shared documents)", "personAnalytics", "legendPartner"),
            (g, "personCoMention.node.help", "Co-mention count with the focus person — click for details, right-click for actions", "personAnalytics", "nodeHelp"),
            (x, "crossRefAnalytics.title", "Cross-Reference Analytics", "crossReferenceAnalytics", "title"),
            (x, "crossRefAnalytics.unavailable.title", "Cross-Reference Analytics Unavailable", "crossReferenceAnalytics", "unavailableTitle"),
            (x, "crossRefAnalytics.unavailable.detail", "The search index is not available. Index at least one volume to build the citation network.", "crossReferenceAnalytics", "unavailableDetail"),
            (x, "crossRefAnalytics.outDegree.toggle", "Out-degree", "crossReferenceAnalytics", "outDegree"),
            (x, "crossRefAnalytics.outDegree.help", "Overlay the out-degree distribution (how many citations documents make) on the in-degree histogram.", "crossReferenceAnalytics", "outDegreeHelp"),
            (x, "crossRefAnalytics.axis.degree", "Degree", "crossReferenceAnalytics", "degree"),
            (x, "crossRefAnalytics.axis.documentCount", "Documents", "crossReferenceAnalytics", "documents"),
            (x, "crossRefAnalytics.axis.series", "Direction", "crossReferenceAnalytics", "direction"),
            (x, "crossRefAnalytics.series.inDegree", "In-degree", "crossReferenceAnalytics", "inDegreeSeries"),
            (x, "crossRefAnalytics.series.outDegree", "Out-degree", "crossReferenceAnalytics", "outDegreeSeries"),
            (x, "crossRefAnalytics.axis.document", "Document", "crossReferenceAnalytics", "document"),
            (x, "crossRefAnalytics.axis.inDegree", "Inbound citations", "crossReferenceAnalytics", "inboundCitations"),
            (x, "crossRefAnalytics.matrix.table", "View as table", "crossReferenceAnalytics", "viewAsTable"),
            (tables, "analytics.export.column.citingVolume", "Citing volume", "crossReferenceAnalytics", "citing"),
            (tables, "analytics.export.column.citedVolume", "Cited volume", "crossReferenceAnalytics", "cited"),
            (tables, "analytics.export.column.references", "References", "crossReferenceAnalytics", "references"),
            ("App/MainWindowView.swift", "mainwindow.tools.personAnalytics", "Person Analytics", "app", "personAnalytics"),
            ("App/MainWindowView.swift", "mainwindow.tools.crossRefAnalytics", "Cross-Reference Analytics", "app", "crossReferenceAnalytics"),
        ]
        var read: [String: String] = [:]
        for word in words {
            let app = try read[word.file] ?? Self.app(word.file)
            read[word.file] = app
            #expect(NoteViewParityTests.writes(app, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            let block = try NoteViewParityTests.block(word.block, of: copy)
            #expect(block.contains("\(word.web): '\(word.value)'"), "copy.ts's \(word.block) block has \(word.web): \(word.value)")
        }
        // The chip's remove button, whose words name the person.
        #expect(NoteViewParityTests.writes(try Self.app(p), "personAnalytics.chip.remove.a11y", "Remove \\(person.canonicalName) from comparison"))
        #expect(try NoteViewParityTests.block("personAnalytics", of: copy).contains("removeFromComparison: (name: string) => `Remove ${name} from comparison`"))
    }
}
