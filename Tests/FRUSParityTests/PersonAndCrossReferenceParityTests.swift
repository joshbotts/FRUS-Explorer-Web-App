// Person and Cross-Reference Analytics (PLAN's S24g), over the kit's fixture index imported as an export. Every
// series the API gives is held to the kit's own over the same index, computed here by a host's own
// `PersonMentionStore` and `CrossReferenceStore`, opened as a host opens them, apart from the server: the ranking
// (`topPeopleByMentions(inYearRange:)`), the trajectories and the relationship (`PersonAnalyticsMath`,
// `PersonRelationshipMath` over the store's trajectories, totals and timeline), the co-mention network
// (`PersonCoMentionNetwork`), the most-referenced documents, the degree distributions (`CrossReferenceStats`), the
// heat matrix's volumes and cells, the PageRank landmarks (`PageRank`) and the broken references excluded, with each
// table the kit's `AnalyticsChartTables` builds; and each CSV's method block, line for line, is the kit's
// `AnalyticsProvenance.csvPreambleLines(for:)` for the statement the app's views write.

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

@Suite struct PersonAndCrossReferenceParityTests {
    /// What a host has at this pin, apart from the server: the fixture index's copy opened read-only and immutable by
    /// the person and cross-reference stores, with a host's own copies of the bundled files, and the catalogue.
    struct Host: @unchecked Sendable {
        let persons: PersonMentionStore
        let crossReferences: CrossReferenceStore
        let catalogue: [VolumeManifestEntry]

        static func open() async throws -> Host {
            let built = try await FixtureIndex.value()
            let resources = ServedFixture.resources
            let catalogue = try FixedVolumeCatalogue(contentsOf: resources.appendingPathComponent("manifest.json")).citableEntries
            let crossReferences = try CrossReferenceStore(
                readingDatabaseAt: built.copy, volumes: catalogue,
                resolvedEdgeIndex: try ResolvedEdgeIndex(contentsOf: resources.appendingPathComponent("resolved-edge-index.json")),
                citedPageMap: try JSONDecoder().decode(CitedPageMap.self,
                                                       from: Data(contentsOf: resources.appendingPathComponent("cited-page-map.json"))))
            return Host(persons: try PersonMentionStore(readingDatabaseAt: built.copy), crossReferences: crossReferences,
                        catalogue: catalogue)
        }

        func title(_ volumeId: String) -> String {
            catalogue.first { $0.volumeId == volumeId }?.title ?? volumeId
        }

        var corpusMaxYear: Int { CorpusAnalyticsRoutes.corpusMaxYear(catalogue) }
    }

    static let english = Locale(identifier: "en_US")

    static func number(_ value: Double) -> String { String(format: "%.12f", value) }

    /// The first line two lists differ at, for a failure's message.
    static func difference(_ api: [String], _ kit: [String]) -> String {
        for (index, pair) in zip(api, kit).enumerated() where pair.0 != pair.1 {
            return "line \(index): api \(pair.0) | kit \(pair.1)"
        }
        return "api \(api.count) lines, kit \(kit.count)"
    }

    static func lines(_ table: ChartInspectorData) -> [String] {
        ["table \(table.title)", "columns \(table.columns.joined(separator: " | "))"] + table.rows.map { "row \($0.cells.joined(separator: " | "))" }
    }

    static func lines(_ table: CorpusAnalyticsAnswer.Table) -> [String] {
        ["table \(table.title)", "columns \(table.columns.joined(separator: " | "))"] + table.rows.map { "row \($0.joined(separator: " | "))" }
    }

    // MARK: - Person Analytics

    /// One request: the years, the scope's volumes, the people compared, and the decade switch and values.
    struct PersonAsk: CustomStringConvertible, Sendable {
        var start = 1861
        var end: Int
        var volumes: [String]?
        var people: [(id: Int, name: String)] = []
        var decade = false
        var share = false

        var query: String {
            var parts = ["from=\(start)", "to=\(end)", "decade=\(decade)", "values=\(share ? "percentOfDocuments" : "raw")"]
            for person in people { parts.append("people=\(person.id)") }
            for volume in volumes ?? [] { parts.append("volumes=\(volume)") }
            return parts.joined(separator: "&")
        }

        var description: String { query }
    }

    /// What the kit gives for an ask, in the order the app's view loads it, put in the API's shape here apart from the
    /// server's mirror: the lines an answer must equal.
    static func kit(_ host: Host, _ ask: PersonAsk) async throws -> [String] {
        let range = min(ask.start, ask.end)...max(ask.start, ask.end)
        let store = host.persons
        let ranking = try await store.topPeopleByMentions(inYearRange: range, limit: 15, volumeIds: ask.volumes)
        let labels = disambiguatedRankingLabels(ranking.map { (id: String($0.rollupId), name: $0.canonicalName, shortSuffix: String($0.rollupId)) })
        var lines = ranking.map { "rank \($0.rollupId) \($0.canonicalName) \(labels[String($0.rollupId)] ?? "?") \($0.mentionCount)" }
        lines += Self.lines(AnalyticsChartTables.personRankingTable(
            title: "Most-Mentioned People",
            rows: ranking.map { (rollupId: $0.rollupId, name: $0.canonicalName, axisLabel: labels[String($0.rollupId)] ?? $0.canonicalName,
                                 mentions: $0.mentionCount) }))
        let period = ask.decade ? "Decade" : "Year"
        if !ask.people.isEmpty {
            let ids = ask.people.map(\.id)
            let raw = try await store.mentionTrajectories(rollupIds: ids, volumeIds: ask.volumes)
            let documents = try await store.mentioningDocumentTrajectories(rollupIds: ids, volumeIds: ask.volumes)
            let totals = try await store.datedDocumentTotalsByYear(volumeIds: ask.volumes)
            let names = Dictionary(uniqueKeysWithValues: ask.people.map { ($0.id, $0.name) })
            let base = ask.share
                ? PersonAnalyticsMath.sharePoints(mentioningDocs: documents, totals: totals, names: names, range: range)
                : PersonAnalyticsMath.rawPoints(trajectories: raw, names: names, range: range)
            let points = ask.decade ? PersonAnalyticsMath.bucketByDecade(base, isShare: ask.share) : base
            lines += points.map { "point \($0.rollupId) \($0.name) \($0.year) \(number($0.value))" }
            // The export's series, each person's plotted periods with the counts behind them, as the view's
            // `trajectorySeriesBody()` builds them, in the order the people were added.
            let byPerson = Dictionary(grouping: points, by: \.rollupId)
            let series = ask.people.map { person in
                (rollupId: person.id, name: person.name,
                 points: (byPerson[person.id] ?? []).sorted { $0.year < $1.year }.map { point in
                     let years = PersonAnalyticsMath.sourceYears(forPeriod: point.year, byDecade: ask.decade, range: range)
                     let docs = years.compactMap { documents[person.id]?[$0] }
                     let dated = years.compactMap { totals[$0] }
                     return (period: point.year, mentions: years.reduce(0) { $0 + (raw[person.id]?[$1] ?? 0) },
                             mentioningDocs: docs.isEmpty ? nil : docs.reduce(0, +),
                             datedTotal: dated.isEmpty ? nil : dated.reduce(0, +), plotted: point.value)
                 })
            }
            lines += Self.lines(AnalyticsChartTables.personTrajectoryTable(
                title: "Mention Trajectories", periodColumn: period, series: series, isNormalized: ask.share, locale: english))
        }
        if ask.people.count == 2 {
            let timeline = try await store.coMentionTimeline(rollupA: ask.people[0].id, rollupB: ask.people[1].id, volumeIds: ask.volumes)
            let base = PersonRelationshipMath.points(timeline: timeline, range: range)
            let points = ask.decade ? PersonRelationshipMath.bucketByDecade(base) : base
            lines += points.map { "together \($0.year) \($0.coMentions)" }
            lines += Self.lines(AnalyticsChartTables.personRelationshipTable(
                title: "Relationship Dynamics", periodColumn: period, personA: ask.people[0].name, personB: ask.people[1].name,
                points: points.map { (period: $0.year, coMentions: $0.coMentions) }))
        }
        return lines
    }

    /// The same lines, of the API's answer.
    static func api(_ answer: PersonAnalyticsAnswer) -> [String] {
        var lines = answer.ranking.rows.map { "rank \($0.rollupId) \($0.name) \($0.axisLabel) \($0.mentions)" }
        lines += Self.lines(answer.ranking.table)
        if !answer.comparison.people.isEmpty {
            lines += answer.comparison.points.map { "point \($0.rollupId) \($0.name) \($0.period) \(number($0.value))" }
            lines += Self.lines(answer.comparison.table)
        }
        if let relationship = answer.relationship {
            lines += relationship.points.map { "together \($0.period) \($0.coMentions)" }
            lines += Self.lines(relationship.table)
        }
        return lines
    }

    /// The asks: each range and scope with no one compared, one, two and five people of the host's own ranking, by
    /// year and by decade, raw and as shares.
    static func personAsks(_ host: Host) async throws -> [PersonAsk] {
        let maxYear = host.corpusMaxYear
        let top = try await host.persons.topPeopleByMentions(inYearRange: 1861...maxYear, limit: 15, volumeIds: nil)
        let people = top.map { (id: $0.rollupId, name: $0.canonicalName) }
        let comparisons: [[(id: Int, name: String)]] = [[], Array(people.prefix(1)), Array(people.prefix(2)), Array(people.prefix(5)),
                                                        // The last ranked two, whose mentions may fall outside a narrowed range.
                                                        Array(people.suffix(2))]
        var asks: [PersonAsk] = []
        for (start, end) in [(1861, maxYear), (1960, 1963), (1890, 1899)] {
            for volumes in [nil, ["frus1961-63v06"], ["frus1961-63v06", "frus1894Nicaragua"]] as [[String]?] {
                for compared in comparisons {
                    for (decade, share) in compared.isEmpty ? [(false, false)] : [(false, false), (false, true), (true, false), (true, true)] {
                        asks.append(PersonAsk(start: start, end: end, volumes: volumes, people: compared, decade: decade, share: share))
                    }
                }
            }
        }
        return asks
    }

    /// Every Trends answer the API gives for the fixtures is the kit's series.
    @Test func everyPersonSeriesIsTheKits() async throws {
        let host = try await Host.open()
        let asks = try await Self.personAsks(host)
        let read = try await ServedFixture.run { client, _ in
            var read: [PersonAnalyticsAnswer] = []
            for ask in asks {
                let response = try await client.execute(uri: "/api/v1/analytics/people?\(ask.query)", method: .get)
                guard response.status == .ok else { throw APIParityError("\(ask): \(response.status.code) \(String(buffer: response.body))") }
                read.append(try ServedFixture.decode(PersonAnalyticsAnswer.self, response))
            }
            return read
        }
        var tally = (ranked: 0, points: 0, shares: 0, decades: 0, relationships: 0, together: 0, empty: 0)
        for (ask, answer) in zip(asks, read) {
            let api = Self.api(answer)
            let kit = try await Self.kit(host, ask)
            #expect(api == kit, "\(ask): \(Self.difference(api, kit))")
            #expect(answer.comparison.people.map(\.rollupId) == ask.people.map(\.id), "\(ask)")
            #expect(answer.comparison.atCap == (ask.people.count >= 5), "\(ask)")
            #expect(answer.scope.volumeIds == ask.volumes.map { Array(Set($0)).sorted() }, "\(ask)")
            if !answer.ranking.rows.isEmpty { tally.ranked += 1 }
            if !answer.comparison.points.isEmpty {
                tally.points += 1
                if ask.share { tally.shares += 1 }
                if ask.decade { tally.decades += 1 }
            }
            if !ask.people.isEmpty, answer.comparison.points.isEmpty { tally.empty += 1 }
            if let relationship = answer.relationship {
                tally.relationships += 1
                if !relationship.points.isEmpty { tally.together += 1 }
            }
            #expect((answer.relationship != nil) == (ask.people.count == 2), "\(ask)")
        }
        // The comparison reached every kind of answer the fixtures give.
        #expect(tally.ranked > 20 && tally.points > 20 && tally.shares > 0 && tally.decades > 0 && tally.relationships > 0
                && tally.together > 0 && tally.empty > 0, "\(tally)")
    }

    /// Every network the API gives is the kit's choice of nodes and edges around the person asked for, the focus first.
    @Test func everyNetworkIsTheKits() async throws {
        let host = try await Host.open()
        var asks: [(person: PersonMentionRanking, volumes: [String]?)] = []
        for volumes in [nil, ["frus1961-63v06"]] as [[String]?] {
            let top = try await host.persons.topPeopleByMentions(inYearRange: 1861...host.corpusMaxYear, limit: 15, volumeIds: volumes)
            for person in top.prefix(6) + top.suffix(2) { asks.append((person, volumes)) }
        }
        let asked = asks
        let read = try await ServedFixture.run { client, _ in
            var read: [PersonNetworkAnswer] = []
            for ask in asked {
                let scope = (ask.volumes ?? []).map { "&volumes=\($0)" }.joined()
                let response = try await client.execute(uri: "/api/v1/analytics/people/network?focus=\(ask.person.rollupId)\(scope)", method: .get)
                guard response.status == .ok else { throw APIParityError("\(ask.person.rollupId): \(response.status.code) \(String(buffer: response.body))") }
                read.append(try ServedFixture.decode(PersonNetworkAnswer.self, response))
            }
            return read
        }
        var graphs = 0
        for (ask, answer) in zip(asks, read) {
            let ego = try await PersonCoMentionNetwork.nodes(focusRollupId: ask.person.rollupId, focusName: ask.person.canonicalName,
                                                             store: host.persons, volumeIds: ask.volumes)
            let edges = try await PersonCoMentionNetwork.edges(among: ego.nodes, store: host.persons, volumeIds: ask.volumes)
            let partners = PersonCoMentionNetwork.partners(of: ego.nodes, focusRollupId: ask.person.rollupId)
            let kitNodes = [("\(ask.person.rollupId) \(ask.person.canonicalName) 0")] + partners.map { "\($0.rollupId) \($0.name) \($0.sharedWithFocus)" }
            #expect(answer.nodes.map { "\($0.rollupId) \($0.name) \($0.sharedWithFocus)" } == kitNodes, "\(ask.person.rollupId)")
            #expect(answer.nodes.map(\.label) == [ask.person.canonicalName] .map { GraphNodeLabels.shortLabel($0, limit: 16) }
                    + partners.map { GraphNodeLabels.shortLabel($0.name, limit: 16) })
            #expect(answer.edges.map { "\($0.a) \($0.b) \($0.sharedDocuments)" } == edges.map { "\($0.a) \($0.b) \($0.sharedDocuments)" })
            let capApplied = PersonCoMentionNetwork.capApplied(partnerCount: partners.count, totalPartnerCount: ego.totalPartnerCount)
            #expect(answer.capApplied == capApplied && answer.totalPartnerCount == ego.totalPartnerCount)
            if capApplied {
                #expect(answer.footer == PersonCoMentionNetwork.capDisclosure(partnerCount: partners.count, totalPartnerCount: ego.totalPartnerCount))
            }
            #expect(answer.state == (partners.isEmpty ? "empty" : "graph"))
            if !partners.isEmpty { graphs += 1 }
        }
        #expect(graphs > 4, "the fixtures draw \(graphs) networks")
    }

    // MARK: - Cross-Reference Analytics

    struct CrossReferenceAsk: CustomStringConvertible, Sendable {
        var start = 1861
        var end: Int
        var volumes: [String]?
        var outDegree = false

        var query: String {
            var parts = ["from=\(start)", "to=\(end)", "outDegree=\(outDegree)"]
            for volume in volumes ?? [] { parts.append("volumes=\(volume)") }
            return parts.joined(separator: "&")
        }

        var description: String { query }
    }

    /// A row's label as the app's `CrossReferenceTargetLabel` names it, written here apart from the server.
    static func label(_ host: Host, volumeId: String, documentId: String,
                      facts: [String: CrossReferenceStore.DocumentTitleFacts]) -> (String, Bool) {
        if let found = facts["\(volumeId)/\(documentId)"] { return (DocumentDisplayTitle.text(found, documentId: documentId), true) }
        guard let number = CitableDocumentNumber.fromDocumentId(documentId) else { return ("\(documentId) — \(host.title(volumeId))", false) }
        return ("Document \(number) — \(host.title(volumeId))", false)
    }

    static func kit(_ host: Host, _ ask: CrossReferenceAsk) async throws -> [String] {
        let store = host.crossReferences
        let range: ClosedRange<Int>? = ask.start != 1861 || ask.end != host.corpusMaxYear ? ask.start...ask.end : nil
        var lines = ["excluded \(try await store.excludedBrokenCount(yearRange: range, volumeIds: ask.volumes))"]
        let top = try await store.topDocumentsByInDegree(limit: 15, yearRange: range, volumeIds: ask.volumes)
        let facts = try await store.documentTitleFacts(for: top.map { (volumeId: $0.volumeId, documentId: $0.documentId) })
        let rows = top.map { row -> (volumeId: String, documentId: String, label: String, inDegree: Int) in
            let (label, indexed) = Self.label(host, volumeId: row.volumeId, documentId: row.documentId, facts: facts)
            lines.append("ranked \(row.volumeId) \(row.documentId) \(label) \(indexed) \(row.inDegree)")
            return (row.volumeId, row.documentId, label, row.inDegree)
        }
        lines += Self.lines(AnalyticsChartTables.crossRefRankingTable(title: "Most-Referenced Documents", rows: rows))
        let inDistribution = CrossReferenceStats.degreeDistribution(try await store.resolvedInDegrees(yearRange: range, volumeIds: ask.volumes))
        let outDistribution = CrossReferenceStats.degreeDistribution(try await store.resolvedOutDegrees(yearRange: range, volumeIds: ask.volumes))
        lines += inDistribution.map { "in \($0.degree) \($0.label) \($0.documentCount)" }
        lines += outDistribution.map { "out \($0.degree) \($0.label) \($0.documentCount)" }
        let outByLabel = Dictionary(outDistribution.map { ($0.label, $0.documentCount) }, uniquingKeysWith: { first, _ in first })
        lines += Self.lines(AnalyticsChartTables.crossRefDistributionTable(
            title: "Citation Degree Distribution",
            rows: inDistribution.map { (bucket: $0.label, inDegreeDocuments: $0.documentCount,
                                        outDegreeDocuments: ask.outDegree ? outByLabel[$0.label] : nil) }))
        let edges = try await store.volumeLevelConnections(limitToVolumeIds: ask.volumes, yearRange: range)
        let volumes = CrossReferenceStats.topVolumesByTotalDegree(edges, limit: 15)
        let cells = edges.filter { volumes.contains($0.sourceVolumeId) && volumes.contains($0.targetVolumeId) }
        for volume in volumes {
            let entry = host.catalogue.first { $0.volumeId == volume }
            let parts = VolumeLabels.distilledVolumeLabelParts(volumeId: volume, subseries: entry?.subseries ?? "", title: entry?.title ?? "")
            lines.append("volume \(volume) \(parts.topic) | \(parts.tag)")
        }
        for source in volumes {
            lines.append("cells \(source) " + volumes.map { target in
                String(cells.first { $0.sourceVolumeId == source && $0.targetVolumeId == target }?.count ?? 0)
            }.joined(separator: " "))
        }
        lines.append("max \(cells.map(\.count).max() ?? 0)")
        lines += Self.lines(AnalyticsChartTables.crossRefMatrixTable(
            title: "Volume Citation Heat Matrix",
            rows: cells.map { (sourceId: $0.sourceVolumeId, sourceTitle: host.title($0.sourceVolumeId),
                               targetId: $0.targetVolumeId, targetTitle: host.title($0.targetVolumeId), count: $0.count) }))
        let scored = Array(PageRank.compute(edges: try await store.resolvedCitationEdges(yearRange: range, volumeIds: ask.volumes)).prefix(15))
        let landmarkFacts = try await store.documentTitleFacts(for: scored.map { (volumeId: $0.key.volumeId, documentId: $0.key.documentId) })
        let landmarks = scored.map { node -> (volumeId: String, documentId: String, label: String, score: Double) in
            let (label, indexed) = Self.label(host, volumeId: node.key.volumeId, documentId: node.key.documentId, facts: landmarkFacts)
            lines.append("landmark \(node.key.volumeId) \(node.key.documentId) \(label) \(indexed) \(number(node.score))")
            return (node.key.volumeId, node.key.documentId, label, node.score)
        }
        lines += Self.lines(AnalyticsChartTables.crossRefLandmarkTable(title: "Landmark Documents (Influence)", rows: landmarks))
        return lines
    }

    static func api(_ answer: CrossReferenceAnalyticsAnswer) -> [String] {
        var lines = ["excluded \(answer.excludedBrokenCount)"]
        lines += answer.ranking.rows.map { "ranked \($0.document.volumeId) \($0.document.documentId) \($0.document.label) \($0.document.isIndexed) \($0.inDegree)" }
        lines += Self.lines(answer.ranking.table)
        lines += answer.distribution.inDegree.map { "in \($0.degree) \($0.label) \($0.documentCount)" }
        lines += answer.distribution.outDegree.map { "out \($0.degree) \($0.label) \($0.documentCount)" }
        lines += Self.lines(answer.distribution.table)
        lines += answer.matrix.volumes.map { "volume \($0.id) \($0.topic) | \($0.tag)" }
        for (volume, row) in zip(answer.matrix.volumes, answer.matrix.rows) {
            lines.append("cells \(volume.id) " + row.map { String($0.count) }.joined(separator: " "))
        }
        lines.append("max \(answer.matrix.maxCount)")
        lines += Self.lines(answer.matrix.table)
        lines += answer.landmarks.rows.map { "landmark \($0.document.volumeId) \($0.document.documentId) \($0.document.label) \($0.document.isIndexed) \(number($0.score))" }
        lines += Self.lines(answer.landmarks.table)
        return lines
    }

    /// Every Cross-Reference Analytics answer the API gives for the fixtures is the kit's series, the broken references
    /// excluded counted as the kit counts them and said when there are any.
    @Test func everyCrossReferenceSeriesIsTheKits() async throws {
        let host = try await Host.open()
        var asks: [CrossReferenceAsk] = []
        for (start, end) in [(1861, host.corpusMaxYear), (1961, 1963), (1890, 1900), (1955, 1970)] {
            for volumes in [nil, ["frus1961-63v06"], ["frus1961-63v06", "frus1894Nicaragua"]] as [[String]?] {
                for outDegree in [false, true] {
                    asks.append(CrossReferenceAsk(start: start, end: end, volumes: volumes, outDegree: outDegree))
                }
            }
        }
        let asked = asks
        let read = try await ServedFixture.run { client, _ in
            var read: [CrossReferenceAnalyticsAnswer] = []
            for ask in asked {
                let response = try await client.execute(uri: "/api/v1/analytics/cross-references?\(ask.query)", method: .get)
                guard response.status == .ok else { throw APIParityError("\(ask): \(response.status.code) \(String(buffer: response.body))") }
                read.append(try ServedFixture.decode(CrossReferenceAnalyticsAnswer.self, response))
            }
            return read
        }
        var tally = (ranked: 0, notIndexed: 0, excluded: 0, matrices: 0, landmarks: 0, out: 0)
        for (ask, answer) in zip(asks, read) {
            let api = Self.api(answer)
            let kit = try await Self.kit(host, ask)
            #expect(api == kit, "\(ask): \(Self.difference(api, kit))")
            // The broken references excluded are said when there are any, in the kit's count phrase.
            #expect((answer.excludedBrokenCaption != nil) == (answer.excludedBrokenCount > 0), "\(ask)")
            if let caption = answer.excludedBrokenCaption {
                #expect(caption.hasPrefix(answer.excludedBrokenCount.formatted(.number.locale(Self.english)) + " unresolvable reference"), "\(caption)")
                tally.excluded += 1
            }
            if !answer.ranking.rows.isEmpty { tally.ranked += 1 }
            if answer.ranking.rows.contains(where: { !$0.document.isIndexed }) || answer.landmarks.rows.contains(where: { !$0.document.isIndexed }) {
                tally.notIndexed += 1
            }
            if answer.matrix.volumes.count >= 2 { tally.matrices += 1 }
            if !answer.landmarks.rows.isEmpty { tally.landmarks += 1 }
            if answer.distribution.table.columns.count == 3 { tally.out += 1 }
            #expect((answer.distribution.table.columns.count == 3) == (ask.outDegree && !answer.distribution.inDegree.isEmpty), "\(ask)")
        }
        // Whether the fixtures hold a broken reference or cite a volume they lack is theirs; the captions' rule over any
        // count is `CrossReferenceAnalyticsRouteTests`'.
        #expect(tally.ranked > 4 && tally.landmarks > 4 && tally.out > 0 && tally.matrices > 0, "\(tally)")
    }

    // MARK: - The method blocks

    /// Each CSV's method block is the kit's, for the statement the app's view writes, and its table the kit's
    /// `ChartInspectorData.csv`.
    @Test func everyCSVsPreambleIsTheKits() async throws {
        let host = try await Host.open()
        let maxYear = host.corpusMaxYear
        let top = try await host.persons.topPeopleByMentions(inYearRange: 1861...maxYear, limit: 15, volumeIds: nil)
        let two = top.prefix(2).map { "&people=\($0.rollupId)" }.joined()
        let zone = "America/New_York"
        let timeZone = try #require(TimeZone(identifier: zone))
        let datedCaveat = "Population: person mentions are counted in dated documents only. The Corpus Analytics charts fall back to the volume’s start year for undated documents; these charts do not. Counts from the two views are therefore not directly comparable."
        let identityCaveat = "Identity: mentions are grouped by the app’s person authority, so spelling variants and name forms for one individual merge into a single identity. The person id column is that grouped identity."
        let decadeCaveat = "Decade shares: the share plotted for a decade is the average of the yearly shares for the years this person was tagged. Years with no tags are dropped from that average rather than counted as zero. The “Dated documents in period” column, by contrast, sums every year of the decade. So dividing this file’s columns gives the decade’s own share, which can be far lower than the plotted value. Someone tagged in one year of a decade plots that single year’s share for the whole decade. Use the columns for the decade’s share and the plotted value for the average across the tagged years. They answer different questions."
        let sameVolume = "Attribution: the document-level figures count same-volume references, including resolved page references, toward the document’s own volume. The volume heat matrix counts only citations between different volumes, so it leaves same-volume references out."
        // Each export: its route and request, and the statement the app's view writes for it.
        struct Export: Sendable {
            var path: String
            var query: String
            var statement: @Sendable (_ excluded: Int, _ date: Date) -> AnalyticsProvenance
        }
        func person(_ title: String, axis: String, value: String?, extra: [String] = [], scope: String? = nil, years: ClosedRange<Int>)
            -> @Sendable (Int, Date) -> AnalyticsProvenance {
            { _, date in
                AnalyticsProvenance(figureTitle: title, axisLabel: axis, scopeLabel: scope, indexedVolumeCount: ParityFixtures.volumes.count,
                                    yearRange: years, appliesDocumentDating: false, valueMode: value,
                                    extraCaveats: [datedCaveat, identityCaveat] + extra, sources: [.frusText, .ohPeopleRegister], exportDate: date)
            }
        }
        func crossReference(_ title: String, axis: String, extra: [String] = [], scope: String? = nil, years: ClosedRange<Int>)
            -> @Sendable (Int, Date) -> AnalyticsProvenance {
            { excluded, date in
                let caveat = CountCopy.phrase(
                    excluded,
                    one: "Unresolvable references: %@ cross-reference is excluded from this analysis — a reference in the printed volumes that points to a document, page, or volume not present in this corpus.",
                    many: "Unresolvable references: %@ cross-references are excluded from this analysis — references in the printed volumes that point to a document, page, or volume not present in this corpus.",
                    locale: Locale(identifier: "en_US"))
                return AnalyticsProvenance(figureTitle: title, axisLabel: axis, scopeLabel: scope, indexedVolumeCount: ParityFixtures.volumes.count,
                                           yearRange: years, appliesDocumentDating: false, valueMode: nil,
                                           extraCaveats: [caveat, sameVolume] + extra, exportDate: date)
            }
        }
        let exports = [
            Export(path: "people", query: "chart=ranking", statement: person("Most-Mentioned People", axis: "Ranked by mentions", value: nil, years: 1861...maxYear)),
            Export(path: "people", query: "chart=ranking&from=1960&to=1963&volume=frus1961-63v06",
                   statement: person("Most-Mentioned People", axis: "Ranked by mentions", value: nil, scope: host.title("frus1961-63v06"), years: 1960...1963)),
            Export(path: "people", query: "chart=trajectories\(two)", statement: person("Mention Trajectories", axis: "Year", value: "Raw count", years: 1861...maxYear)),
            Export(path: "people", query: "chart=trajectories\(two)&decade=true&values=percentOfDocuments",
                   statement: person("Mention Trajectories", axis: "Decade", value: "% of documents", extra: [decadeCaveat], years: 1861...maxYear)),
            Export(path: "people", query: "chart=relationship\(two)&decade=true", statement: person("Relationship Dynamics", axis: "Decade", value: nil, years: 1861...maxYear)),
            Export(path: "cross-references", query: "chart=ranking",
                   statement: crossReference("Most-Referenced Documents", axis: "Ranked by inbound references", years: 1861...maxYear)),
            Export(path: "cross-references", query: "chart=distribution&outDegree=true&from=1955&to=1970",
                   statement: crossReference("Citation Degree Distribution", axis: "Grouped by references received", years: 1955...1970)),
            // The matrix of the whole corpus: its volumes are those the fixtures cite, which no scope of theirs holds both
            // ends of.
            Export(path: "cross-references", query: "chart=matrix",
                   statement: crossReference("Volume Citation Heat Matrix", axis: "Cross-volume citation counts",
                                             extra: ["Selection: the matrix covers the 15 volumes with the most references in and out. The CSV lists only pairs with at least one reference between them. The figure draws the whole grid and leaves the rest of the cells blank.",
                                                     "Axes: rows cite columns. In the figure the column headings are abbreviated volume codes and the row labels are shortened descriptive labels; both volumes’ full titles appear in this CSV."],
                                             years: 1861...maxYear)),
            Export(path: "cross-references", query: "chart=landmarks&volumes=frus1961-63v06&scopeLabel=Mine",
                   statement: crossReference("Landmark Documents (Influence)", axis: "Ranked by PageRank influence score",
                                             extra: ["Score: an offline PageRank over the resolved citation graph — a structural measure of how often a document is cited by other well-cited documents. It is a measure of editorial handling, not a claim of historical importance."],
                                             scope: "Mine", years: 1861...maxYear)),
        ]
        let read = try await ServedFixture.run { client, _ in
            var read: [(csv: String, excluded: Int, moments: ClosedRange<Date>, disposition: String?, table: CorpusAnalyticsAnswer.Table)] = []
            for export in exports {
                // The chart's own answer, whose table the CSV writes.
                let answer = try await client.execute(uri: "/api/v1/analytics/\(export.path)?\(export.query.replacingOccurrences(of: #"chart=[a-z]+&?"#, with: "", options: .regularExpression))", method: .get)
                guard answer.status == .ok else { throw APIParityError("\(export.query): \(answer.status.code) \(String(buffer: answer.body))") }
                var table: CorpusAnalyticsAnswer.Table
                var excluded = 0
                if export.path == "people" {
                    let decoded = try ServedFixture.decode(PersonAnalyticsAnswer.self, answer)
                    table = export.query.hasPrefix("chart=ranking") ? decoded.ranking.table
                        : export.query.hasPrefix("chart=trajectories") ? decoded.comparison.table : try #require(decoded.relationship).table
                } else {
                    let decoded = try ServedFixture.decode(CrossReferenceAnalyticsAnswer.self, answer)
                    excluded = decoded.excludedBrokenCount
                    table = export.query.hasPrefix("chart=ranking") ? decoded.ranking.table
                        : export.query.hasPrefix("chart=distribution") ? decoded.distribution.table
                        : export.query.hasPrefix("chart=matrix") ? decoded.matrix.table : decoded.landmarks.table
                }
                let before = Date()
                let response = try await client.execute(uri: "/api/v1/analytics/\(export.path)/export?\(export.query)&timeZone=\(zone)", method: .get)
                let after = Date()
                #expect(response.status == .ok && response.headers[.contentType] == "text/csv; charset=utf-8", "\(export.query)")
                read.append((String(buffer: response.body), excluded, before...after, response.headers[.contentDisposition], table))
            }
            return read
        }
        let english = AnalyticsProvenance.Host(appVersion: "Light \(FRUSLightVersion.string)", locale: Locale(identifier: "en_US"),
                                               calendar: Calendar(identifier: .gregorian), timeZone: timeZone)
        for (export, (csv, excluded, moments, disposition, table)) in zip(exports, read) {
            let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let written = Array(lines.prefix { $0.hasPrefix("#") })
            // The moment is the export's, between the request's start and end: either minute's rendering.
            let expected = [moments.lowerBound, moments.upperBound].map { export.statement(excluded, $0).csvPreambleLines(for: english) }
            #expect(expected.contains(written), "\(export.query): \(written)")
            let data = ChartInspectorData(id: "chart", title: table.title, columns: table.columns, rowCells: table.rows)
            #expect(Array(lines.dropFirst(written.count)).joined(separator: "\n") == data.csv + "\n", "\(export.query)")
            #expect(!table.rows.isEmpty, "\(export.query) exports a table with rows")
            #expect(disposition?.hasPrefix("attachment; filename=\"FRUS-Analytics-") == true && disposition?.contains(".csv") == true,
                    "\(export.query): \(disposition ?? "")")
        }
    }
}
