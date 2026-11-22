// Archival Analytics and About the Series (PLAN's S24h), over the kit's fixture index imported as an export. Every
// series the API gives is held to the kit's own, computed here apart from the server by a host that decodes the
// bundled files with the kit's loaders and builds what the app's views build: the Collections ranking with its caption,
// reach, notes and table (`ArchivalCollectionsData`, `ArchivalCounts`), the every-unit list, the co-citation network
// with its layout and placed labels (`ArchivalNetworkBuilder`, `GraphNodeLabels`) at the server's estimate of the
// canvas's font, the flows on both layers (`ArchivalFlowsData`), Your Library over a host's own pipeline
// (`ArchivalLibraryProfile`), and About the Series' four dashboards (`SeriesProductionData`, `SeriesGeographyData`,
// `SourceProvenanceData`, `AdministrationProfilesData`, the top collections) with each chart's years cut by the kit's
// `effectiveDomain` and its table the kit's `ChartInspectorAdapters`; and each CSV's method block, line for line, is
// the kit's `AnalyticsProvenance.csvPreambleLines(for:)` for the statement the app's view writes, and each figure's band
// the kit's `plateLines(for:)`.

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

@Suite struct ArchivalAndSeriesParityTests {
    /// The bundled files as a host decodes them with the kit's loaders, apart from the server's.
    struct Host: @unchecked Sendable {
        let catalogue: [VolumeManifestEntry]
        let authority: CollectionAuthorityIndex
        let usage: CollectionUsageIndex
        let external: ExternalCitationIndex
        let decimal: DecimalClassLabelTable
        let subjectNumeric: SubjectNumericLabelTable
        let flows: ProvenanceFlowIndex
        let sourceProvenance: SourceProvenanceIndex
        let administrations: AdministrationProfilesIndex
        let taxonomy: [TagTaxonomyEntry]

        static func open() throws -> Host {
            let directory = ServedFixture.resources
            func at(_ name: String) -> URL { directory.appendingPathComponent(name) }
            return Host(
                catalogue: try FixedVolumeCatalogue(contentsOf: at("manifest.json")).citableEntries,
                authority: try CollectionAuthorityIndex(contentsOf: at("collection-authority.json")),
                usage: try CollectionUsageIndex(contentsOf: at("collection-usage-index.json")),
                external: try ExternalCitationIndex(contentsOf: at("external-citation-index.json")),
                decimal: try DecimalClassLabelTable(contentsOf: at("decimal-class-labels.json")),
                subjectNumeric: try SubjectNumericLabelTable(contentsOf: at("subject-numeric-labels.json")),
                flows: try ProvenanceFlowIndex(contentsOf: at("provenance-flow-index.json")),
                sourceProvenance: try SourceProvenanceIndex(contentsOf: at("source-provenance-index.json")),
                administrations: try AdministrationProfilesIndex(contentsOf: at("administration-profiles-index.json")),
                taxonomy: try JSONDecoder().decode([TagTaxonomyEntry].self, from: Data(contentsOf: at("volume-tag-taxonomy.json"))))
        }

        func collections(_ scope: Set<String>?) -> ArchivalCollectionsData {
            ArchivalCollectionsData.make(
                authority: authority.collections, usage: usage,
                coverage: ArchivalVolumeCoverage.map(from: catalogue, limitedTo: scope),
                external: external, labels: decimal, subjectNumericLabels: subjectNumeric)
        }

        var placeRegions: [String: GeographicRegion] {
            var map: [String: GeographicRegion] = [:]
            for tag in taxonomy where TagCategory(rawValue: tag.category) == .places {
                map[tag.slug] = GeographicRegion.from(subcategory: tag.subcategory)
            }
            return map
        }

        func tagName(_ slug: String) -> String { taxonomy.first { $0.slug == slug }?.displayName ?? slug }

        func entries(_ scope: Set<String>?) -> [VolumeManifestEntry] {
            scope.map { ids in catalogue.filter { ids.contains($0.volumeId) } } ?? catalogue
        }
    }

    static func number(_ value: Double) -> String { String(format: "%.12f", value) }

    static func lines(_ table: ChartInspectorData) -> [String] {
        ["table \(table.title)", "columns \(table.columns.joined(separator: " | "))"] + table.rows.map { "row \($0.cells.joined(separator: " | "))" }
    }

    static func lines(_ table: CorpusAnalyticsAnswer.Table?) -> [String] {
        guard let table else { return ["no table"] }
        return ["table \(table.title)", "columns \(table.columns.joined(separator: " | "))"] + table.rows.map { "row \($0.joined(separator: " | "))" }
    }

    /// The first line two lists differ at, for a failure's message.
    static func difference(_ api: [String], _ kit: [String]) -> String {
        PersonAndCrossReferenceParityTests.difference(api, kit)
    }

    /// A value as a query's part.
    static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~")))!
    }

    /// Asks the fixture server each path in turn and decodes each answer.
    static func read<T: Decodable & Sendable>(_ type: T.Type, _ paths: [String]) async throws -> [T] {
        try await ServedFixture.run { client, _ in
            var answers: [T] = []
            for path in paths {
                let response = try await client.execute(uri: path, method: .get)
                guard response.status == .ok else { throw APIParityError("\(path): \(response.status.code) \(String(buffer: response.body))") }
                answers.append(try ServedFixture.decode(T.self, response))
            }
            return answers
        }
    }

    // MARK: - Collections

    struct CollectionsAsk: CustomStringConvertible, Sendable {
        var band: Int
        var lens: ArchivalUnitLens
        var weight: ArchivalWeight
        var umbrella: Bool
        /// The scope's query and the volumes it holds, as the test resolves them, and its label.
        var scopeQuery = ""
        var scope: Set<String>?
        var label: String?

        var query: String {
            "band=\(band)&lens=\(lens.rawValue)&weight=\(weight.rawValue)&umbrella=\(umbrella)" + (scopeQuery.isEmpty ? "" : "&\(scopeQuery)")
        }

        var description: String { query }
    }

    /// The weight the app's view draws a stored one in: volumes where the bundle cannot draw it.
    static func weight(_ stored: ArchivalWeight, lens: ArchivalUnitLens, data: ArchivalCollectionsData) -> ArchivalWeight {
        switch stored {
        case .volumes: .volumes
        case .documents: data.supportsDocumentWeight ? .documents : .volumes
        case .unprintedPointers: data.supportsPointerWeight ? .unprintedPointers : .volumes
        }
    }

    static func kit(_ data: ArchivalCollectionsData, _ ask: CollectionsAsk) -> [String] {
        let band = ArchivalEraBand.all[ask.band]
        let weight = Self.weight(ask.weight, lens: ask.lens, data: data)
        let ranking = data.ranking(band: band, lens: ask.lens, weight: weight, hidingUmbrella: !ask.umbrella)
        var lines = ["weight \(weight.rawValue)"]
        lines += ranking.rows.map {
            "row \($0.id) \($0.label) \($0.category.rawValue) \($0.value) \($0.gloss ?? "-") \($0.glossAlternates.joined(separator: "/"))"
        }
        lines.append("caption " + ArchivalCounts.rankingCaption(bandTitle: band.title, bandVolumeCount: ranking.bandVolumeCount,
                                                                 unitsReached: ranking.unitsReached, lens: ask.lens,
                                                                 measuresPrintedMaterial: weight.measuresPrintedMaterial))
        if !ranking.rows.isEmpty {
            lines += Self.lines(ChartInspectorData(
                id: "archival.ranking", title: ask.lens == .namedCollections ? "Top collections by era" : "Top central-file classes by era",
                columns: ["Archival unit", "Custodian", weight.title],
                rowCells: ranking.rows.map { [$0.label, $0.category.displayName, "\($0.value)"] }))
        }
        if let notes = data.noteCount(band: band) {
            let population = ask.label.map { "\($0), \(band.title)" } ?? band.title
            if let share = ranking.shownShare(weight: weight) {
                let rows = ranking.rows.count == 1 ? "The 1 row below accounts for" : "The \(ranking.rows.count.formatted(.number.locale(PersonAndCrossReferenceParityTests.english))) rows below account for"
                let shareText = share < 0.01 ? "under 1%"
                    : share.formatted(.percent.precision(.fractionLength(share < 0.1 ? 1 : 0)).locale(PersonAndCrossReferenceParityTests.english))
                lines.append("denominator \(ArchivalCounts.sourceNotes(notes)) in \(population). \(rows) \(shareText) of them.")
            } else {
                lines.append("denominator \(ArchivalCounts.sourceNotes(notes)) in \(population).")
            }
        }
        if let hidden = ranking.hiddenUmbrellaValue {
            lines.append("umbrella " + ArchivalCounts.umbrellaCaveat(weight: weight, hidden: hidden, bandTitle: band.title))
        }
        return lines
    }

    static func api(_ answer: ArchivalCollectionsAnswer) -> [String] {
        var lines = ["weight \(answer.weight)"]
        lines += answer.ranking.rows.map {
            "row \($0.id) \($0.label) \($0.category) \($0.value) \($0.gloss ?? "-") \($0.glossAlternates.joined(separator: "/"))"
        }
        lines.append("caption " + answer.ranking.caption)
        if answer.ranking.table != nil { lines += Self.lines(answer.ranking.table) }
        if let denominator = answer.denominator { lines.append("denominator \(denominator.sentence)") }
        if let umbrella = answer.caveats.first(where: { $0.hasPrefix("The Central Files umbrella record is hidden here.") }) {
            lines.append("umbrella \(umbrella)")
        }
        return lines
    }

    @Test func everyCollectionsRankingIsTheKits() async throws {
        let host = try Host.open()
        let subseries = Set(host.catalogue.filter { $0.subseries == "1961-63" }.map(\.volumeId))
        let kennedy = Set(host.administrations.administrations.first { $0.id == "kennedy" }!.volumes.map(\.volumeId))
            .intersection(Set(host.catalogue.map(\.volumeId)))
        let scopes: [(query: String, ids: Set<String>?, label: String?)] = [
            ("", nil, nil),
            ("subseries=1961-63", subseries, "1961-63"),
            ("administration=kennedy", kennedy, "John F. Kennedy"),
            ("volumes=frus1961-63v06&volumes=frus1969-76ve09p1&scopeLabel=Mine", ["frus1961-63v06", "frus1969-76ve09p1"], "Mine"),
        ]
        var asks: [CollectionsAsk] = []
        for scope in scopes {
            for band in ArchivalEraBand.all.map(\.index) {
                for lens in ArchivalUnitLens.allCases {
                    for weight in ArchivalWeight.allCases {
                        // Every weight and lens over the whole series; over a scope, each lens's default weight and the
                        // umbrella shown, which the scope narrows alike.
                        if !scope.query.isEmpty, weight == .unprintedPointers { continue }
                        for umbrella in [false, true] where scope.query.isEmpty || !umbrella || lens == .namedCollections {
                            asks.append(CollectionsAsk(band: band, lens: lens, weight: weight, umbrella: umbrella,
                                                       scopeQuery: scope.query, scope: scope.ids, label: scope.label))
                        }
                    }
                }
            }
        }
        let answers = try await Self.read(ArchivalCollectionsAnswer.self, asks.map { "/api/v1/analytics/archives?\($0.query)" })
        var built: [String: ArchivalCollectionsData] = [:]
        for (ask, answer) in zip(asks, answers) {
            let data = built[ask.scopeQuery] ?? host.collections(ask.scope)
            built[ask.scopeQuery] = data
            let kit = Self.kit(data, ask)
            #expect(Self.api(answer) == kit, "\(ask): \(Self.difference(Self.api(answer), kit))")
            // The weights the menu offers are the kit's support, and the scope chip names the scope.
            #expect(answer.weights.map(\.enabled) == [data.supportsDocumentWeight, true, data.supportsPointerWeight], "\(ask)")
            #expect(answer.scope.label == (ask.label ?? "Whole corpus"), "\(ask)")
        }
        #expect(answers.count == asks.count && asks.count >= 150)
        // At least one ask exercises each kind of answer the fixtures give: rows, a family, a withheld umbrella.
        #expect(answers.contains { !$0.ranking.rows.isEmpty })
        #expect(answers.contains { $0.families != nil })
        #expect(answers.contains { $0.caveats.contains { $0.hasPrefix("The Central Files umbrella record is hidden here.") } })
    }

    @Test func everyUnitIsTheKitsUncappedRanking() async throws {
        let host = try Host.open()
        let data = host.collections(nil)
        let asks = [(0, ArchivalUnitLens.namedCollections, ArchivalWeight.documents), (1, .centralFileClasses, .volumes),
                    (2, .namedCollections, .unprintedPointers), (4, .centralFileClasses, .documents)]
        let answers = try await Self.read(ArchivalUnitsAnswer.self, asks.map {
            "/api/v1/analytics/archives/units?band=\($0.0)&lens=\($0.1.rawValue)&weight=\($0.2.rawValue)"
        })
        for (ask, answer) in zip(asks, answers) {
            let ranking = data.ranking(band: ArchivalEraBand.all[ask.0], lens: ask.1, weight: Self.weight(ask.2, lens: ask.1, data: data),
                                       hidingUmbrella: true, limit: .max)
            #expect(answer.rows.map { "\($0.rank) \($0.id) \($0.label) \($0.value)" }
                    == ranking.rows.enumerated().map { "\($0.offset + 1). \($0.element.id) \($0.element.label) \($0.element.value)" },
                    "\(ask)")
        }
        #expect(answers.contains { $0.rows.count > ArchivalCollectionsData.rowCap }, "an uncapped list lists more than the chart's cap")
    }

    // MARK: - Network

    struct NetworkAsk: CustomStringConvertible, Sendable {
        var focus: String
        var measure: ArchivalEdgeMeasure = .sharedVolumes
        var threshold = 0.25
        var expansion: ArchivalUmbrellaExpansion = .collapsed
        var selected: String?
        var group: ArchivalRepositoryCategory?
        var only = false

        var query: String {
            var parts = ["focus=\(ArchivalAndSeriesParityTests.encode(focus))", "measure=\(measure.rawValue)",
                         "threshold=\(String(format: "%.2f", threshold))", "expansion=\(expansion.rawValue)", "width=720", "height=420"]
            if let selected { parts.append("selected=\(ArchivalAndSeriesParityTests.encode(selected))") }
            if let group { parts.append("group=\(group.rawValue)") }
            if only { parts.append("only=true") }
            return parts.joined(separator: "&")
        }

        var description: String { query }
    }

    static func size(_ text: String, _ fontSize: Double) -> CGSize {
        CGSize(width: CGFloat(Double(text.count) * fontSize * 0.55), height: CGFloat(fontSize * 1.25))
    }

    static func point(_ value: CGPoint) -> String { String(format: "%.6f,%.6f", Double(value.x), Double(value.y)) }

    static func rect(_ value: CGRect) -> String {
        String(format: "%.6f,%.6f,%.6f,%.6f", Double(value.origin.x), Double(value.origin.y), Double(value.size.width), Double(value.size.height))
    }

    static func kit(_ host: Host, _ ask: NetworkAsk) -> [String] {
        let focus = host.authority.collections.first { $0.id == ask.focus }!
        let graph = ArchivalNetworkBuilder.graph(focus: focus, in: host.authority.collections, usage: host.usage, measure: ask.measure,
                                                 minimumRelativeStrength: ask.threshold, expansion: ask.expansion)
        var drawn = graph
        if ask.only, let group = ask.group {
            let kept = graph.nodes.filter { $0.category == group }
            if !kept.isEmpty {
                drawn = ArchivalNetworkGraph(focus: graph.focus, focusCategory: graph.focusCategory, nodes: kept,
                                             nodesAboveThreshold: graph.nodesAboveThreshold, partnersTotal: graph.partnersTotal,
                                             strongestMeasureValue: kept.map(\.measureValue).max() ?? graph.strongestMeasureValue,
                                             expandedUmbrella: graph.expandedUmbrella, expansion: graph.expansion)
            }
        }
        var lines = graph.nodes.isEmpty ? [] : drawn.nodes.map {
            "node \($0.id) \($0.label) \($0.kind == .collection ? "collection" : "centralFileClass") \($0.category.rawValue) \($0.sharedVolumeCount) \($0.sharedDocumentCount.map(String.init) ?? "-") \(number($0.relativeStrength))"
        }
        guard !graph.nodes.isEmpty else { return lines + ["empty"] }
        let layout = ArchivalNetworkBuilder.layout(drawn, in: CGSize(width: 720, height: 420), captionSize: { text in
            let size = Self.size(text, 9)
            return CGSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
        })
        lines += layout.positions.sorted { $0.key < $1.key }.map { "at \($0.key) \(point($0.value))" }
        lines += layout.ringRadii.map { String(format: "ring %.6f", Double($0)) }
        lines += ArchivalRepositoryCategory.allCases.compactMap { category in
            layout.captions[category].map { "caption \(category.rawValue) \($0.text) \(rect($0.rect))" }
        }
        let selected = drawn.nodes.contains { $0.id == ask.selected } ? ask.selected : nil
        let texts = ArchivalNetworkBuilder.drawnLabels(in: drawn)
        var sizes: [String: CGSize] = [:]
        for id in ArchivalNetworkBuilder.labelPriority(drawn, selectedNodeId: selected) {
            sizes[id] = Self.size(texts[id] ?? "", id == drawn.focus.id ? 9 : 8)
        }
        let requests = ArchivalNetworkBuilder.labelRequests(drawn, layout: layout, selectedNodeId: selected, sizes: sizes)
        let placed = GraphNodeLabels.place(requests, avoiding: ArchivalNetworkBuilder.labelObstacles(layout))
        lines += requests.compactMap { request in placed[request.id].map { "label \(request.id) \(texts[request.id] ?? "") \(rect($0))" } }
        if let node = graph.nodes.first(where: { $0.id == ask.selected }) {
            lines.append("card " + ArchivalNetworkBuilder.cardDetail(for: node, in: graph, usage: host.usage))
        }
        lines += Self.lines(ChartInspectorData(
            id: "archival.network", title: "Co-cited with \(graph.focusLabel)",
            columns: ["Archival unit", "Kind", "Custodian", "Shared volumes", "Jointly supplied documents", "Share of strongest link"],
            rowCells: graph.nodes.map(ArchivalNetworkBuilder.exportCells(for:))))
        return lines
    }

    static func api(_ answer: ArchivalNetworkAnswer) -> [String] {
        var lines = answer.nodes.map {
            "node \($0.id) \($0.label) \($0.kind) \($0.category) \($0.sharedVolumes) \($0.sharedDocuments.map(String.init) ?? "-") \(number($0.relativeStrength))"
        }
        guard let layout = answer.layout else { return lines + ["empty"] }
        lines += layout.positions.sorted { $0.key < $1.key }.map { "at \($0.key) " + String(format: "%.6f,%.6f", $0.value.x, $0.value.y) }
        lines += layout.ringRadii.map { String(format: "ring %.6f", $0) }
        lines += ArchivalRepositoryCategory.allCases.compactMap { category in
            layout.captions[category.rawValue].map {
                "caption \(category.rawValue) \($0.text) " + String(format: "%.6f,%.6f,%.6f,%.6f", $0.rect.x, $0.rect.y, $0.rect.width, $0.rect.height)
            }
        }
        lines += answer.labels.map {
            "label \($0.id) \($0.text) " + String(format: "%.6f,%.6f,%.6f,%.6f", $0.rect.x, $0.rect.y, $0.rect.width, $0.rect.height)
        }
        if let card = answer.dock.node { lines.append("card \(card.detail)") }
        lines += Self.lines(answer.table)
        return lines
    }

    @Test func everyNetworkIsTheKits() async throws {
        let host = try Host.open()
        let candidates = ArchivalNetworkView.focusCandidates(host.authority.collections, searchText: "")
        let seed = try #require(ArchivalNetworkView.seedFocus(host.authority.collections))
        let foci = [seed.id] + candidates.prefix(4).map(\.id).filter { $0 != seed.id } + [candidates[40].id, candidates[150].id]
        var asks: [NetworkAsk] = []
        for focus in foci {
            for measure in ArchivalEdgeMeasure.allCases {
                for threshold in [0.05, 0.25, 0.6] {
                    asks.append(NetworkAsk(focus: focus, measure: measure, threshold: threshold))
                }
            }
            for expansion in [ArchivalUmbrellaExpansion.decimalClasses, .subjectNumeric] {
                asks.append(NetworkAsk(focus: focus, threshold: 0.1, expansion: expansion))
            }
        }
        // A partner shown, a group, and the group alone, around the first focus.
        let first = host.authority.collections.first { $0.id == seed.id }!
        let graph = ArchivalNetworkBuilder.graph(focus: first, in: host.authority.collections, usage: host.usage, measure: .sharedVolumes,
                                                 minimumRelativeStrength: 0.25, expansion: .collapsed)
        for node in graph.nodes.prefix(3) {
            asks.append(NetworkAsk(focus: seed.id, selected: node.id))
        }
        for category in ArchivalRepositoryCategory.allCases {
            asks.append(NetworkAsk(focus: seed.id, group: category))
            asks.append(NetworkAsk(focus: seed.id, group: category, only: true))
        }
        let answers = try await Self.read(ArchivalNetworkAnswer.self, asks.map { "/api/v1/analytics/archives/network?\($0.query)" })
        let english = PersonAndCrossReferenceParityTests.english
        for (ask, answer) in zip(asks, answers) {
            let kit = Self.kit(host, ask)
            #expect(Self.api(answer) == kit, "\(ask): \(Self.difference(Self.api(answer), kit))")
            // The dock's summary carries the kit's sentences for the whole graph: its partners, those held back, its squares.
            let focus = host.authority.collections.first { $0.id == ask.focus }!
            let graph = ArchivalNetworkBuilder.graph(focus: focus, in: host.authority.collections, usage: host.usage, measure: ask.measure,
                                                     minimumRelativeStrength: ask.threshold, expansion: ask.expansion)
            guard !graph.nodes.isEmpty else { continue }
            #expect(answer.dock.summary.contains(ArchivalCounts.networkPartners(graph.partnersTotal, locale: english)), "\(ask)")
            #expect(answer.dock.summary.contains(ArchivalCounts.networkHeldBack(graph.withheldCount, locale: english)) == graph.isCapped, "\(ask)")
            #expect(answer.dock.summary.contains(ArchivalCounts.networkClassSquares(graph.classNodeCount, locale: english)) == (graph.classNodeCount > 0),
                    "\(ask)")
        }
        #expect(answers.contains { !$0.nodes.isEmpty && $0.nodes.contains { $0.kind == "centralFileClass" } }, "an expansion draws classes")
        // The first focus is the seed, as the view seeds it, when none is named.
        let seeded = try await Self.read(ArchivalNetworkAnswer.self, ["/api/v1/analytics/archives/network"])
        #expect(seeded.first?.focus?.id == seed.id)
    }

    // MARK: - Flows

    struct FlowsAsk: CustomStringConvertible, Sendable {
        var layer: ArchivalFlowLayer
        var focus: String?
        var direction: ArchivalFlowDirection = .outgoing

        var query: String {
            var parts = ["layer=\(layer.rawValue)", "direction=\(direction.rawValue)"]
            if let focus { parts.append("focus=\(ArchivalAndSeriesParityTests.encode(focus))") }
            return parts.joined(separator: "&")
        }

        var description: String { query }
    }

    static func endpoint(_ endpoint: ArchivalFlowEndpoint) -> String {
        "\(endpoint.id) \(endpoint.label) \(endpoint.repository ?? "-") \(endpoint.category.rawValue) \(endpoint.count) \(endpoint.isRemainder)"
    }

    static func endpoint(_ endpoint: ArchivalFlowsAnswer.Endpoint) -> String {
        "\(endpoint.id) \(endpoint.label) \(endpoint.repository ?? "-") \(endpoint.category) \(endpoint.count) \(endpoint.isRemainder)"
    }

    static func percent(_ share: Double) -> String {
        share.formatted(.percent.precision(.fractionLength(1)).locale(PersonAndCrossReferenceParityTests.english))
    }

    /// The kit's flows for an ask, in the API's shape: the pairs or the endpoints and the remainder, the diagram's
    /// caption, and the caveats, each sentence the app's with the kit's numbers.
    static func kit(_ host: Host, _ ask: FlowsAsk) -> [String] {
        let entries = Dictionary(host.catalogue.map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first })
        let focus = ask.focus.flatMap { host.authority.record(id: $0) }
        let data: ArchivalFlowsData
        switch (ask.layer, focus) {
        case (.toUnprinted, nil): data = .corpusWideExternal(index: host.external, authority: host.authority, entriesById: entries)
        case (.toUnprinted, let focus?): data = .focusedExternal(on: focus, direction: ask.direction, index: host.external, authority: host.authority, entriesById: entries)
        case (_, nil): data = .corpusWide(index: host.flows, authority: host.authority)
        case (_, let focus?): data = .focused(on: focus, direction: ask.direction, index: host.flows, authority: host.authority)
        }
        var lines: [String] = []
        if data.focus == nil {
            lines += data.topPairs.map { "pair \(endpoint($0.source)) → \(endpoint($0.target))" }
        } else if data.endpoints.isEmpty {
            lines.append("none \(data.volumesWithEdges) of \(data.volumesScanned)")
        } else {
            lines += data.endpoints.map { "end \(endpoint($0))" }
            lines += data.allEndpoints.dropFirst(ArchivalFlowsData.endpointCap).map { "rest \(endpoint($0))" }
            lines.append("totals \(data.totalReferences) \(data.sameUnitReferences)")
        }
        if let facts = data.externalFacts {
            lines.append("caveat \(facts.referencesFound) citations were found and \(facts.referencesJoined) of them matched a known collection, across \(data.volumesWithEdges) of the \(data.volumesScanned) volumes in the series.")
            if let span = facts.eraSpan { lines.append("caveat The volumes contributing here cover \(span.lowerBound) to \(span.upperBound).") }
            lines.append("caveat \(percent(facts.inheritedShare)) of these citations come from an “Ibid.”")
        } else {
            lines.append("caveat \(percent(data.footnoteShare)) of these references are footnotes.")
            lines.append("caveat Only \(data.volumesWithEdges) of the \(data.volumesScanned) volumes in the series contribute a single reference. The central-file classes left out of the diagrams carry \(data.classBetweenReferences) references over \(data.classBetweenPairs) pairs.")
        }
        return lines
    }

    static func api(_ answer: ArchivalFlowsAnswer) -> [String] {
        var lines: [String] = []
        if let pairs = answer.corpusWide?.pairs {
            lines += pairs.map { "pair \(endpoint($0.source)) → \(endpoint($0.target))" }
        }
        if let none = answer.none {
            // "Only N of M volumes in the series carry any of these references."
            let tail = none.detail.components(separatedBy: "Only ").last ?? ""
            lines.append("none " + (tail.components(separatedBy: " volumes in the series").first ?? "").replacingOccurrences(of: " of the ", with: " of "))
        }
        if let diagram = answer.diagram {
            lines += diagram.endpoints.map { "end \(endpoint($0))" }
            lines += diagram.remainder.map { "rest \(endpoint($0))" }
            // The caption's first two numbers: the references shown and those left out as the collection's own.
            let numbers = diagram.caption.split(whereSeparator: { !$0.isNumber }).prefix(2).map(String.init)
            lines.append("totals \(numbers.joined(separator: " "))")
        }
        for line in answer.caveats.lines {
            // Each caveat up to the sentence the kit's numbers end.
            for prefix in [" What this layer reads", " a reading rather than", " While annotating", " These figures cover"] {
                if let range = line.range(of: prefix) {
                    var head = String(line[..<range.lowerBound])
                    if prefix == " a reading rather than" { head = head.replacingOccurrences(of: ", which the app follows back —", with: "") }
                    lines.append("caveat \(head)")
                    break
                }
            }
            if line.hasPrefix("The volumes contributing here cover") { lines.append("caveat \(line)") }
        }
        return lines
    }

    @Test func everyFlowIsTheKits() async throws {
        let host = try Host.open()
        var asks = [FlowsAsk(layer: .betweenPrinted), FlowsAsk(layer: .toUnprinted)]
        let printed = ArchivalFlowsData.focusCandidates(index: host.flows, authority: host.authority).map(\.record.id)
        let unprinted = ArchivalFlowsData.externalFocusCandidates(index: host.external, authority: host.authority).map(\.record.id)
        for (layer, foci) in [(ArchivalFlowLayer.betweenPrinted, printed), (.toUnprinted, unprinted)] {
            for focus in [foci[0], foci[1], foci[min(25, foci.count - 1)], foci[foci.count - 1]] {
                for direction in ArchivalFlowDirection.allCases {
                    asks.append(FlowsAsk(layer: layer, focus: focus, direction: direction))
                }
            }
        }
        let answers = try await Self.read(ArchivalFlowsAnswer.self, asks.map { "/api/v1/analytics/archives/flows?\($0.query)" })
        for (ask, answer) in zip(asks, answers) {
            let kit = Self.kit(host, ask)
            let api = Self.api(answer)
            #expect(api == kit, "\(ask): \(Self.difference(api, kit))")
        }
        #expect(answers.contains { $0.diagram.map { !$0.remainder.isEmpty } ?? false }, "a focus folds a remainder")
        // A focus draws its diagram or says it has none, never both; the series' pairs stand alone.
        for (ask, answer) in zip(asks, answers) {
            #expect(ask.focus == nil ? answer.diagram == nil && answer.none == nil && answer.corpusWide != nil
                    : (answer.diagram == nil) != (answer.none == nil), "\(ask)")
        }
        #expect(answers.contains { $0.focus != nil && $0.diagram != nil }, "a focus draws its diagram")
    }

    // MARK: - Your Library

    @Test func yourLibraryIsTheKitsProfileOfTheServedIndex() async throws {
        let host = try Host.open()
        let built = try await FixtureIndex.value()
        let resources = try IndexingResources.loading(fromDirectory: ServedFixture.resources)
        let store = try FTS5Store(readingDatabaseAt: built.copy)
        let pipeline = try IndexingPipeline(readingIndexAt: built.copy, fts5Store: store, resources: resources,
                                            volumesDirectory: Repository.layout.tei)
        let profile = ArchivalLibraryProfile.make(
            groups: try await pipeline.archivalLibraryGroups(),
            collectionGroups: try await pipeline.archivalLibraryCollectionGroups(),
            coverage: ArchivalVolumeCoverage.map(from: host.catalogue, limitedTo: nil),
            authority: host.authority)
        #expect(!profile.isEmpty, "the fixtures carry source notes")
        let answer = try #require(try await Self.read(ArchivalLibraryAnswer.self, ["/api/v1/analytics/archives/library"]).first)
        #expect(answer.empty == nil)
        #expect(answer.composition.items.map { "\($0.category) \($0.documents)" }
                == profile.composition.map { "\($0.category.rawValue) \($0.documentCount)" })
        #expect(answer.bands.items.map { "\($0.band) \($0.category) \($0.documents)" }
                == profile.bands.flatMap { band in band.categories.map { "\(band.band.title) \($0.category.rawValue) \($0.documentCount)" } })
        #expect(answer.collections.rows.map { "\($0.id) \($0.name)" } == profile.collections.map { "\($0.record.id) \($0.record.name)" })
        #expect(answer.intro.contains("the \(profile.noteCount) source notes across the \(profile.volumeCount) indexed volumes"))
        #expect(answer.footer.lines[1].hasPrefix("\(profile.centralFileNoteCount) notes cite the central files"))
        #expect(Self.lines(answer.collections.table) == Self.lines(ChartInspectorData(
            id: "c", title: "Your most-cited collections", columns: ["Archival unit", "Custodian", "Documents"],
            rowCells: profile.collections.map { [$0.record.name, $0.record.repository ?? ArchivalRepositoryCategory.from($0.record).displayName, "\($0.documentCount)"] })))
    }

    // MARK: - About the Series

    struct SeriesAsk: CustomStringConvertible, Sendable {
        var dashboard: String
        var from: Int?
        var to: Int?
        var scopeQuery = ""
        var scope: Set<String>?
        var label: String?
        var extra = ""

        var query: String {
            var parts: [String] = []
            if let from { parts.append("from=\(from)") }
            if let to { parts.append("to=\(to)") }
            if !scopeQuery.isEmpty { parts.append(scopeQuery) }
            if !extra.isEmpty { parts.append(extra) }
            return parts.joined(separator: "&")
        }

        var description: String { "\(dashboard)?\(query)" }
    }

    static func marks(_ chart: SeriesChart) -> [String] {
        ["chart \(chart.id) \(chart.title)"] + chart.marks.map { "\($0.x) \(number($0.y)) \($0.series ?? "-")" }
            + (chart.steps ?? []).map { "step \($0.x) \(number($0.y))" } + Self.lines(chart.table)
    }

    static func seriesAsks(_ host: Host, dashboard: String, defaultEnd: Int) -> [SeriesAsk] {
        let subseries = Set(host.catalogue.filter { $0.subseries == "1969-76" }.map(\.volumeId))
        return [
            SeriesAsk(dashboard: dashboard),
            SeriesAsk(dashboard: dashboard, from: 1945, to: min(1975, defaultEnd)),
            SeriesAsk(dashboard: dashboard, from: 1990, to: defaultEnd),
            SeriesAsk(dashboard: dashboard, scopeQuery: "subseries=1969-76", scope: subseries, label: "1969-76"),
            SeriesAsk(dashboard: dashboard, scopeQuery: "volumes=frus1961-63v06&volumes=frus1894Nicaragua&volumes=notInTheSeries&scopeLabel=Mine",
                      scope: ["frus1961-63v06", "frus1894Nicaragua"], label: "Mine"),
        ]
    }

    @Test func productionAndGeographyAreTheKits() async throws {
        let host = try Host.open()
        let production = Self.seriesAsks(host, dashboard: "production", defaultEnd: 2026)
        let geography = Self.seriesAsks(host, dashboard: "geography", defaultEnd: 1993)
        let producedAnswers = try await Self.read(SeriesProductionAnswer.self, production.map { "/api/v1/about/production?\($0.query)" })
        for (ask, answer) in zip(production, producedAnswers) {
            let data = SeriesProductionData(entries: host.entries(ask.scope))
            let domain = effectiveDomain(userStart: ask.from ?? 1861, userEnd: ask.to ?? 2026, kind: .production)
            let points = data.lagPoints(in: domain)
            let buckets = data.volumesPerPrintYearByEra(in: domain)
            let cumulative = data.cumulativeByPrintYear(in: domain)
            let kit = ["chart lag Publication lag over time"] + points.map { "\($0.printYear) \(Self.number(Double($0.lagYears))) \($0.coverageEra.label)" }
                + PublicationLagTarget.stepPoints(in: domain).map { "step \($0.year) \(Self.number(Double($0.targetYears)))" }
                + Self.lines(ChartInspectorAdapters.lagTable(points))
                + ["chart perYear Volumes published per year"] + buckets.map { "\($0.printYear) \(Self.number(Double($0.count))) \($0.pubEra.label)" }
                + Self.lines(ChartInspectorAdapters.perYearTable(buckets))
                + ["chart cumulative Cumulative volumes published"] + cumulative.map { "\($0.printYear) \(Self.number(Double($0.cumulativeCount))) -" }
                + Self.lines(ChartInspectorAdapters.cumulativeTable(cumulative))
            let api = answer.charts.flatMap(Self.marks)
            #expect(api == kit, "\(ask): \(Self.difference(api, kit))")
            #expect(answer.caveats.lines.last?.contains("cover the \(data.total) volumes") == true, "\(ask)")
            #expect(answer.frame.scopeLabel == "Scope: \(ask.label ?? "Whole series")", "\(ask)")
        }
        let geographyAnswers = try await Self.read(SeriesGeographyAnswer.self, geography.map { "/api/v1/about/geography?\($0.query)" })
        for (ask, answer) in zip(geography, geographyAnswers) {
            let data = SeriesGeographyData(entries: host.entries(ask.scope), placeRegions: host.placeRegions)
            let domain = effectiveDomain(userStart: ask.from ?? 1861, userEnd: ask.to ?? 1993, kind: .coverage)
            let shares = data.regionShareByDecade(in: domain)
            let kit = ["chart trend Regional emphasis over time"] + shares.map { "\($0.decade) \(Self.number($0.share)) \($0.region.displayName)" }
                + Self.lines(ChartInspectorAdapters.regionTrendTable(shares))
                + ["chart totals Overall regional emphasis"] + data.regionTotals.map { "\($0.region.displayName) \(Self.number(Double($0.volumeCount))) \($0.region.displayName)" }
                + Self.lines(ChartInspectorAdapters.regionTotalsTable(data.regionTotals))
                + ["chart countries Most-covered countries"] + data.topCountries.map { "\(host.tagName($0.slug)) \(Self.number(Double($0.volumeCount))) -" }
                + Self.lines(ChartInspectorAdapters.topCountriesTable(data.topCountries, displayName: host.tagName))
            let api = answer.charts.flatMap(Self.marks)
            #expect(api == kit, "\(ask): \(Self.difference(api, kit))")
            #expect(answer.caveats.lines.last?.contains("\(data.volumesWithAnyRegion) of the \(data.totalVolumes) cataloged volumes") == true, "\(ask)")
        }
    }

    @Test func sourcingAndItsTopCollectionsAreTheKits() async throws {
        let host = try Host.open()
        var asks = Self.seriesAsks(host, dashboard: "sourcing", defaultEnd: 1993)
        asks.append(SeriesAsk(dashboard: "sourcing", extra: "hidden=centralDecimalFile&hidden=unrecognized"))
        asks.append(SeriesAsk(dashboard: "sourcing", from: 1930, to: 1950, extra: "hidden=lotFile"))
        let answers = try await Self.read(SeriesSourcingAnswer.self, asks.map { "/api/v1/about/sourcing?\($0.query)" })
        for (ask, answer) in zip(asks, answers) {
            let data = SourceProvenanceData(index: host.sourceProvenance, scopeVolumeIds: ask.scope)
            let hidden = Set(ask.extra.components(separatedBy: "&").compactMap { $0.hasPrefix("hidden=") ? SourceProvenanceCategory(rawValue: String($0.dropFirst(7))) : nil })
            let start = ask.from ?? 1861
            let end = ask.to ?? 1993
            let domain = effectiveDomain(userStart: start, userEnd: end, kind: .coverage)
            let shares = data.shareByDecade(in: domain, excluding: hidden)
            let composition = data.overallComposition(excluding: hidden)
            let density = data.notesByDecade(in: domain)
            let kit = ["chart mix Archival provenance over time"] + shares.map { "\($0.decade) \(Self.number($0.share)) \($0.category.displayName)" }
                + Self.lines(ChartInspectorAdapters.provenanceMixTable(shares))
                + ["chart composition Overall provenance composition"] + composition.map { "\($0.category.displayName) \(Self.number(Double($0.noteCount))) \($0.category.displayName)" }
                + Self.lines(ChartInspectorAdapters.compositionTable(composition))
                + ["chart density The documentary base by decade"] + density.map { "\($0.decade) \(Self.number(Double($0.totalNotes))) -" }
                + Self.lines(ChartInspectorAdapters.densityTable(density))
            let api = answer.charts.flatMap(Self.marks)
            #expect(api == kit, "\(ask): \(Self.difference(api, kit))")
            #expect(answer.supportsScope == data.supportsVolumeScope)
            // The top collections: the kit's ranking over the bands the years overlap, the named collections, the
            // umbrella withheld, the documents where the usage index gives them.
            let collections = host.collections(ask.scope)
            let bands = ArchivalEraBand.bands(overlapping: start, through: end)
            let ranking = collections.ranking(bands: bands, lens: .namedCollections,
                                              weight: collections.supportsDocumentWeight ? .documents : .volumes,
                                              hidingUmbrella: true, limit: ArchivalCollectionsData.rowCap)
            #expect(answer.topCollections.rows.map { "\($0.id) \($0.label) \($0.value) \($0.category)" }
                    == ranking.rows.map { "\($0.id) \($0.label) \($0.value) \($0.category.rawValue)" }, "\(ask)")
            if let first = answer.topCollections.footnotes.first {
                #expect(first.hasPrefix("Showing \(ranking.rows.count) of \(ranking.unitsReached) collections reached"), "\(ask): \(first)")
            }
        }
        #expect(answers.contains { !$0.topCollections.rows.isEmpty })
    }

    @Test func administrationsAreTheKits() async throws {
        let host = try Host.open()
        var asks = Self.seriesAsks(host, dashboard: "administrations", defaultEnd: 2026)
        asks.append(SeriesAsk(dashboard: "administrations", extra: "editorialNotes=true"))
        asks.append(SeriesAsk(dashboard: "administrations", from: 1900, to: 1930, extra: "editorialNotes=true&administration=wilson"))
        asks.append(SeriesAsk(dashboard: "administrations", from: 1900, to: 1930, extra: "administration=kennedy"))
        let answers = try await Self.read(SeriesAdministrationsAnswer.self, asks.map { "/api/v1/about/administrations?\($0.query)" })
        for (ask, answer) in zip(asks, answers) {
            let notes = ask.extra.contains("editorialNotes=true")
            let data = AdministrationProfilesData(index: host.administrations, includeEditorialNotes: notes, scopeVolumeIds: ask.scope)
            let start = ask.from ?? 1861
            let end = ask.to ?? 2026
            // The administrations whose terms the years overlap, an open term running to the production ceiling.
            let visible = data.profiles.filter { profile in
                guard let termStart = Int(profile.start.prefix(4)) else { return true }
                let termEnd = profile.end.flatMap { Int($0.prefix(4)) } ?? 2026
                return termStart <= end && termEnd >= start
            }
            let perYear = visible.filter { $0.termYears > 0 }
            let kitDocuments = visible.map { "\(Int($0.documentCount)) \($0.party.displayName)" }
            let kitPerYear = perYear.map { "\(Self.number($0.volumesPerAdministrationYear)) \($0.party.displayName)" }
            if visible.isEmpty {
                #expect(answer.narrowedEmpty != nil && answer.charts.isEmpty, "\(ask)")
                continue
            }
            #expect(answer.charts[0].marks.map { "\(Int($0.y)) \($0.series ?? "-")" } == kitDocuments, "\(ask)")
            #expect(answer.charts[1].marks.map { "\(Self.number($0.y)) \($0.series ?? "-")" } == kitPerYear, "\(ask)")
            #expect(Self.lines(answer.charts[0].table) == Self.lines(ChartInspectorAdapters.administrationDocumentsTable(visible)), "\(ask)")
            #expect(Self.lines(answer.charts[1].table) == Self.lines(ChartInspectorAdapters.administrationVolumesPerYearTable(perYear)), "\(ask)")
            // The detail: the administration picked if in view, else the most documented in view, with the kit's shares.
            let picked = ask.extra.components(separatedBy: "&").first { $0.hasPrefix("administration=") }.map { String($0.dropFirst(15)) }
            let focus = visible.first { $0.id == picked } ?? visible.max { $0.documentCount < $1.documentCount }
            let detail = try #require(answer.detail)
            #expect(detail.focus == focus?.id, "\(ask)")
            #expect(detail.volumes.map(\.id) == data.volumeShares(for: detail.focus).map(\.id), "\(ask)")
            #expect(detail.volumes.map(\.proportion) == data.volumeShares(for: detail.focus).map {
                $0.proportion.formatted(.percent.precision(.fractionLength(0)).locale(PersonAndCrossReferenceParityTests.english))
            }, "\(ask)")
        }
    }

    // MARK: - The exports

    /// One export: its path and query, the statement the app's view writes for it at a moment, and its table, the
    /// kit's rows under the app's columns.
    struct Export: Sendable {
        var path: String
        var query: String
        var statement: @Sendable (Date) -> AnalyticsProvenance
        var table: ChartInspectorData
        var figure: Bool
    }

    /// A table under its columns, which a CSV writes after its method block (`ChartInspectorData.csv`).
    static func table(_ columns: [String], _ rows: [[String]]) -> ChartInspectorData {
        ChartInspectorData(id: "export", title: "", columns: columns, rowCells: rows)
    }

    /// The ranking's table as `rankingInspector` writes it: each unit, its custodian and its value.
    static func rankingTable(_ ranking: ArchivalRanking, weight: ArchivalWeight) -> ChartInspectorData {
        table(["Archival unit", "Custodian", weight.title], ranking.rows.map { [$0.label, $0.category.displayName, "\($0.value)"] })
    }

    /// The ranking's statement as `rankingProvenance` writes it, over a scope or the series.
    static func rankingStatement(_ ranking: ArchivalRanking, band: ArchivalEraBand, weight: ArchivalWeight, indexed: Int,
                                 scopeLabel: String?) -> AnalyticsProvenance {
        ArchivalAnalyticsExport.ranking(
            band: band, lens: .namedCollections, weight: weight, hiddenUmbrella: ranking.hiddenUmbrellaValue,
            unitsReached: ranking.unitsReached, bandVolumeCount: ranking.bandVolumeCount, indexedVolumeCount: indexed,
            noteCount: ranking.bandNoteCount, shownValue: ranking.shownValue, scopeLabel: scopeLabel)
    }

    @Test func everyCSVsPreambleIsTheKits() async throws {
        let host = try Host.open()
        let zone = "America/New_York"
        let timeZone = try #require(TimeZone(identifier: zone))
        let dated = { (statement: AnalyticsProvenance) in { @Sendable (date: Date) -> AnalyticsProvenance in
            var copy = statement
            copy.exportDate = date
            return copy
        } }
        // The served index holds the three fixture volumes, which the statements count.
        let indexed = 3
        let data = host.collections(nil)
        let band = ArchivalEraBand.all[1]
        let ranking = data.ranking(band: band, lens: .namedCollections, weight: .documents, hidingUmbrella: true)
        let classes = data.ranking(band: ArchivalEraBand.all[0], lens: .centralFileClasses, weight: .volumes, hidingUmbrella: true, limit: .max)
        // Two scopes of volumes, one named and one not: the statement names the first, and the second by the chip's
        // words, never as the whole series.
        let sixties = ArchivalEraBand.all[2]
        let mineData = host.collections(["frus1961-63v06", "frus1969-76ve09p1"])
        let mineWeight = Self.weight(.documents, lens: .namedCollections, data: mineData)
        let mine = mineData.ranking(band: sixties, lens: .namedCollections, weight: mineWeight, hidingUmbrella: true)
        let selectedData = host.collections(["frus1961-63v06"])
        let selectedWeight = Self.weight(.documents, lens: .namedCollections, data: selectedData)
        let selected = selectedData.ranking(band: sixties, lens: .namedCollections, weight: selectedWeight, hidingUmbrella: true)
        #expect(!mine.rows.isEmpty && !selected.rows.isEmpty, "the scopes' rankings have rows to export")
        let seed = try #require(ArchivalNetworkView.seedFocus(host.authority.collections))
        let graph = ArchivalNetworkBuilder.graph(focus: seed, in: host.authority.collections, usage: host.usage, measure: .sharedVolumes,
                                                 minimumRelativeStrength: 0.25, expansion: .collapsed)
        let flows = ArchivalFlowsData.corpusWide(index: host.flows, authority: host.authority)
        let focus = try #require(ArchivalFlowsData.focusCandidates(index: host.flows, authority: host.authority).first?.record)
        let focused = ArchivalFlowsData.focused(on: focus, direction: .outgoing, index: host.flows, authority: host.authority)
        let built = try await FixtureIndex.value()
        let resources = try IndexingResources.loading(fromDirectory: ServedFixture.resources)
        let pipeline = try IndexingPipeline(readingIndexAt: built.copy, fts5Store: try FTS5Store(readingDatabaseAt: built.copy),
                                            resources: resources, volumesDirectory: Repository.layout.tei)
        let profile = ArchivalLibraryProfile.make(groups: try await pipeline.archivalLibraryGroups(),
                                                  collectionGroups: try await pipeline.archivalLibraryCollectionGroups(),
                                                  coverage: ArchivalVolumeCoverage.map(from: host.catalogue, limitedTo: nil), authority: host.authority)
        let library = { (title: String, axis: String) in
            dated(ArchivalAnalyticsExport.library(title: title, axisLabel: axis, profile: profile, indexedVolumeCount: indexed,
                                                  corpusVolumeCount: host.catalogue.count))
        }
        let catalogue = host.catalogue.count
        let production = { (scope: Set<String>?) in SeriesProductionData(entries: host.entries(scope)) }
        let geography = SeriesGeographyData(entries: host.entries(nil), placeRegions: host.placeRegions)
        let provenance = SourceProvenanceData(index: host.sourceProvenance)
        let administrations = AdministrationProfilesData(index: host.administrations, includeEditorialNotes: true, scopeVolumeIds: nil)
        // The administrations whose terms the dashboard's years overlap, an open term running to the production ceiling.
        let visible = administrations.profiles.filter { profile in
            guard let termStart = Int(profile.start.prefix(4)) else { return true }
            return termStart <= 2026 && (profile.end.flatMap { Int($0.prefix(4)) } ?? 2026) >= 1861
        }
        let exports: [Export] = [
            Export(path: "analytics/archives", query: "chart=ranking&band=1",
                   statement: dated(Self.rankingStatement(ranking, band: band, weight: .documents, indexed: indexed, scopeLabel: nil)),
                   table: Self.rankingTable(ranking, weight: .documents), figure: true),
            Export(path: "analytics/archives",
                   query: "chart=ranking&band=2&volumes=frus1961-63v06&volumes=frus1969-76ve09p1&scopeLabel=Mine",
                   statement: dated(Self.rankingStatement(mine, band: sixties, weight: mineWeight, indexed: indexed, scopeLabel: "Mine")),
                   table: Self.rankingTable(mine, weight: mineWeight), figure: true),
            Export(path: "analytics/archives", query: "chart=ranking&band=2&volumes=frus1961-63v06",
                   statement: dated(Self.rankingStatement(selected, band: sixties, weight: selectedWeight, indexed: indexed,
                                                          scopeLabel: "Selected volumes")),
                   table: Self.rankingTable(selected, weight: selectedWeight), figure: true),
            Export(path: "analytics/archives", query: "chart=units&band=0&lens=centralFileClasses&weight=volumes",
                   statement: dated(ArchivalAnalyticsExport.ranking(
                       band: ArchivalEraBand.all[0], lens: .centralFileClasses, weight: .volumes, hiddenUmbrella: classes.hiddenUmbrellaValue,
                       unitsReached: classes.unitsReached, bandVolumeCount: classes.bandVolumeCount, indexedVolumeCount: indexed,
                       noteCount: classes.bandNoteCount, shownValue: classes.shownValue, rowCapApplied: false, scopeLabel: nil,
                       glossesWritten: classes.rows.contains { $0.gloss != nil })),
                   // Each class with its gloss as the export reads it, "and N others" where it has more than one.
                   table: Self.table(["Archival unit", "Custodian", ArchivalWeight.volumes.title], classes.rows.map { row in
                       [[row.label, row.gloss.map { ArchivalCounts.exportReading(gloss: $0, alternates: row.glossAlternates.count) }]
                           .compactMap { $0 }.joined(separator: " — "), row.category.displayName, "\(row.value)"]
                   }), figure: false),
            Export(path: "analytics/archives", query: "chart=network",
                   statement: dated(ArchivalAnalyticsExport.network(
                       focusName: graph.focusLabel, measure: .sharedVolumes, drawn: graph.nodes.count,
                       aboveThreshold: graph.nodesAboveThreshold, partnersTotal: graph.partnersTotal, indexedVolumeCount: indexed)),
                   table: Self.table(["Archival unit", "Kind", "Custodian", "Shared volumes", "Jointly supplied documents", "Share of strongest link"],
                                     graph.nodes.map(ArchivalNetworkBuilder.exportCells(for:))), figure: false),
            Export(path: "analytics/archives", query: "chart=flows",
                   statement: dated(ArchivalAnalyticsExport.flows(
                       title: "The heaviest hand-offs in the series", axisLabel: "Ranked by references between the pair",
                       data: flows, indexedVolumeCount: indexed)),
                   table: Self.table(["From", "To", "References"], flows.topPairs.map { [$0.source.label, $0.target.label, "\($0.source.count)"] }),
                   figure: false),
            Export(path: "analytics/archives", query: "chart=flows&layer=betweenPrinted&direction=outgoing&focus=\(Self.encode(focus.id))",
                   statement: dated(ArchivalAnalyticsExport.flows(
                       title: "\(focus.name) — Outgoing", axisLabel: "References out of this collection",
                       data: focused, indexedVolumeCount: indexed)),
                   // Every endpoint, the ten the diagram draws and those it folds into its remainder.
                   table: Self.table(["Archival unit", "Custodian", "References"],
                                     focused.allEndpoints.map { [$0.label, $0.category.displayName, "\($0.count)"] }),
                   figure: false),
            Export(path: "analytics/archives", query: "chart=composition",
                   statement: library("Where your documents come from", "Divided by kind of archival collection"),
                   table: Self.table(["Provenance", "Documents", "Share"], profile.composition.map {
                       [$0.category.displayName, "\($0.documentCount)", ArchivalLibraryView.percentString($0.documentCount, of: profile.noteCount)]
                   }), figure: false),
            Export(path: "analytics/archives", query: "chart=bands",
                   statement: library("Citation forms across your volumes", "Divided by coverage era and kind of collection"),
                   table: Self.table(["Era", "Provenance", "Documents"], profile.bands.flatMap { band in
                       band.categories.map { [band.band.title, $0.category.displayName, "\($0.documentCount)"] }
                   }), figure: false),
            Export(path: "analytics/archives", query: "chart=collections",
                   statement: library("Your most-cited collections", "Ranked by documents drawn from the collection"),
                   table: Self.table(["Archival unit", "Custodian", "Documents"], profile.collections.map {
                       [$0.record.name, $0.record.repository ?? ArchivalRepositoryCategory.from($0.record).displayName, "\($0.documentCount)"]
                   }), figure: false),
            Export(path: "about", query: "dashboard=production&chart=lag&from=1945&to=2026&subseries=1969-76",
                   statement: dated(SeriesAnalyticsExport.production(
                       figureTitle: "Publication lag over time", axisLabel: "By print year, lag in years",
                       scopeLabel: "1969-76", yearRange: 1945...2026, volumeCount: catalogue)),
                   table: ChartInspectorAdapters.lagTable(production(Set(host.catalogue.filter { $0.subseries == "1969-76" }.map(\.volumeId)))
                       .lagPoints(in: effectiveDomain(userStart: 1945, userEnd: 2026, kind: .production))), figure: true),
            Export(path: "about", query: "dashboard=production&chart=cumulative",
                   statement: dated(SeriesAnalyticsExport.production(
                       figureTitle: "Cumulative volumes published", axisLabel: "By print year, running total",
                       scopeLabel: nil, yearRange: 1861...2026, volumeCount: catalogue)),
                   table: ChartInspectorAdapters.cumulativeTable(production(nil)
                       .cumulativeByPrintYear(in: effectiveDomain(userStart: 1861, userEnd: 2026, kind: .production))), figure: true),
            Export(path: "about", query: "dashboard=production&chart=perYear&volumes=frus1961-63v06&volumes=frus1894Nicaragua",
                   statement: dated(SeriesAnalyticsExport.production(
                       figureTitle: "Volumes published per year", axisLabel: "By print year",
                       scopeLabel: "Selected volumes", yearRange: 1861...2026, volumeCount: catalogue)),
                   table: ChartInspectorAdapters.perYearTable(production(["frus1961-63v06", "frus1894Nicaragua"])
                       .volumesPerPrintYearByEra(in: effectiveDomain(userStart: 1861, userEnd: 2026, kind: .production))), figure: true),
            Export(path: "about", query: "dashboard=geography&chart=trend&from=1900&to=1960",
                   statement: dated(SeriesAnalyticsExport.geography(
                       figureTitle: "Regional emphasis over time", axisLabel: "By coverage decade, share of volumes",
                       scopeLabel: nil, yearRange: 1900...1960, volumeCount: catalogue)),
                   table: ChartInspectorAdapters.regionTrendTable(
                       geography.regionShareByDecade(in: effectiveDomain(userStart: 1900, userEnd: 1960, kind: .coverage))), figure: true),
            Export(path: "about", query: "dashboard=geography&chart=countries",
                   statement: dated(SeriesAnalyticsExport.geography(
                       figureTitle: "Most-covered countries", axisLabel: "By country, volumes tagged",
                       scopeLabel: nil, yearRange: nil, volumeCount: catalogue)),
                   table: ChartInspectorAdapters.topCountriesTable(geography.topCountries, displayName: host.tagName), figure: true),
            Export(path: "about", query: "dashboard=sourcing&chart=mix&from=1900&to=1990&hidden=lotFile",
                   statement: dated(SeriesAnalyticsExport.provenance(
                       figureTitle: "Archival provenance over time", axisLabel: "By coverage decade, share of source notes",
                       scopeLabel: nil, yearRange: 1900...1990,
                       volumeCount: provenance.volumesCovered, noteCount: provenance.totalSourceNotes,
                       hiddenCategories: [SourceProvenanceCategory.lotFile.displayName], generated: provenance.generated)),
                   table: ChartInspectorAdapters.provenanceMixTable(
                       provenance.shareByDecade(in: effectiveDomain(userStart: 1900, userEnd: 1990, kind: .coverage), excluding: [.lotFile])),
                   figure: true),
            Export(path: "about", query: "dashboard=sourcing&chart=composition",
                   statement: dated(SeriesAnalyticsExport.provenance(
                       figureTitle: "Overall provenance composition", axisLabel: "By provenance, across the whole span",
                       scopeLabel: nil, yearRange: nil,
                       volumeCount: provenance.volumesCovered, noteCount: provenance.totalSourceNotes,
                       hiddenCategories: [], generated: provenance.generated)),
                   table: ChartInspectorAdapters.compositionTable(provenance.overallComposition(excluding: [])), figure: true),
            Export(path: "about", query: "dashboard=administrations&chart=documents&editorialNotes=true",
                   statement: dated(SeriesAnalyticsExport.administration(
                       figureTitle: "Documents per administration", axisLabel: "By administration, documents",
                       scopeLabel: nil, yearRange: 1861...2026, volumeCount: administrations.volumesCovered,
                       includesEditorialNotes: true)),
                   table: ChartInspectorAdapters.administrationDocumentsTable(visible), figure: true),
            Export(path: "about", query: "dashboard=administrations&chart=perYear&editorialNotes=true",
                   statement: dated(SeriesAnalyticsExport.administration(
                       figureTitle: "Volumes per administration-year", axisLabel: "By administration, volumes per term-year",
                       scopeLabel: nil, yearRange: 1861...2026, volumeCount: administrations.volumesCovered,
                       includesEditorialNotes: true)),
                   table: ChartInspectorAdapters.administrationVolumesPerYearTable(visible.filter { $0.termYears > 0 }), figure: true),
        ]
        let read = try await ServedFixture.run { client, _ in
            var read: [(csv: String, moments: ClosedRange<Date>, disposition: String?,
                        plate: (lines: [AnalyticsPlate.Line], moments: ClosedRange<Date>)?)] = []
            for export in exports {
                let before = Date()
                let response = try await client.execute(uri: "/api/v1/\(export.path)/export?\(export.query)&timeZone=\(zone)", method: .get)
                let after = Date()
                guard response.status == .ok else { throw APIParityError("\(export.query): \(response.status.code) \(String(buffer: response.body))") }
                #expect(response.headers[.contentType] == "text/csv; charset=utf-8", "\(export.query)")
                let figureBefore = Date()
                let plated = try await client.execute(uri: "/api/v1/\(export.path)/plate?\(export.query)&timeZone=\(zone)", method: .get)
                let figureAfter = Date()
                var plate: (lines: [AnalyticsPlate.Line], moments: ClosedRange<Date>)?
                if export.figure {
                    plate = (try ServedFixture.decode(AnalyticsPlate.self, plated).lines, figureBefore...figureAfter)
                } else {
                    #expect(plated.status == .notFound, "\(export.query) has no figure")
                }
                read.append((String(buffer: response.body), before...after, response.headers[.contentDisposition], plate))
            }
            return read
        }
        let english = AnalyticsProvenance.Host(appVersion: "Light \(FRUSLightVersion.string)", locale: Locale(identifier: "en_US"),
                                               calendar: Calendar(identifier: .gregorian), timeZone: timeZone)
        for (export, (csv, moments, disposition, plate)) in zip(exports, read) {
            if let plate {
                let expected = [plate.moments.lowerBound, plate.moments.upperBound].map { export.statement($0).plateLines(for: english).map(\.text) }
                #expect(expected.contains(plate.lines.map(\.text)), "\(export.query): \(plate.lines.map(\.text))")
            }
            let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let written = Array(lines.prefix { $0.hasPrefix("#") })
            let expected = [moments.lowerBound, moments.upperBound].map { export.statement($0).csvPreambleLines(for: english) }
            #expect(expected.contains(written), "\(export.query): \(written)")
            // The table after it, the kit's rows under the app's columns, as `provenancedCSV` writes them.
            #expect(!export.table.rows.isEmpty, "\(export.query) exports a table with rows")
            #expect(Array(lines.dropFirst(written.count)).joined(separator: "\n") == export.table.csv + "\n", "\(export.query)")
            #expect(disposition?.hasPrefix("attachment; filename=\"FRUS-Analytics-") == true, "\(export.query): \(disposition ?? "")")
        }
    }
}
