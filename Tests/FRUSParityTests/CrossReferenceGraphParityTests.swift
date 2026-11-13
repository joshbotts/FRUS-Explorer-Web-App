// The cross-reference graph (PLAN's S23e), over the kit's fixture index imported as an export. Every
// fixture document's graph through the API is the kit's, as the app's `CrossReferenceGraphViewModel`
// loads, builds and lays it out, computed here with a host's own store and data files, apart from the
// server: the store's graph at each degree and, while no degree is chosen, widened as the app widens it;
// the display build with its volume clusters, expanded and not; the unprinted units and central-file
// classes; the date labels and values; the reference list's order; the connection counts; and the
// timeline's date clusters, expanded and not, and its layout, at several canvas sizes and over a brushed
// window. The two upstream issues the server works around are held as they stand at this pin, so a
// failure here says when a fix has merged and its workaround can go. And the server's and the browser
// app's mirrors of the app's view and words, held to the app's source.

import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSCoreKit
@testable import FRUSLightAPI

@Suite struct CrossReferenceGraphParityTests {
    /// What a host has at this pin, read here apart from the server: the fixture index's pipeline and its
    /// cross-reference store, opened as a host opens it with its own copies of the bundled files, and the
    /// collection authority.
    struct Host: @unchecked Sendable {
        let pipeline: IndexingPipeline
        let store: CrossReferenceStore
        let authority: CollectionAuthorityIndex
        let downloaded: Set<String>

        static func open() async throws -> Host {
            let built = try await FixtureIndex.value()
            let resources = ServedFixture.resources
            let catalogue = try FixedVolumeCatalogue(contentsOf: resources.appendingPathComponent("manifest.json")).citableEntries
            let store = try CrossReferenceStore(
                readingDatabaseAt: built.copy, volumes: catalogue,
                resolvedEdgeIndex: try ResolvedEdgeIndex(contentsOf: resources.appendingPathComponent("resolved-edge-index.json")),
                citedPageMap: try JSONDecoder().decode(CitedPageMap.self,
                                                       from: Data(contentsOf: resources.appendingPathComponent("cited-page-map.json"))))
            let authority = try CollectionAuthorityIndex(contentsOf: resources.appendingPathComponent("collection-authority.json"))
            return Host(pipeline: built.index.pipeline, store: store, authority: authority, downloaded: Set(ParityFixtures.volumes))
        }

        /// The graph the app's view model shows for `key` with the reader's `degree`, or none chosen
        /// (`loadGraph`), and the degree-1 graph beside it.
        func loaded(_ key: DocumentKey, degree chosen: Int?) async throws -> (graph: CrossReferenceGraph, widened: Bool, oneHop: CrossReferenceGraph) {
            let degree = chosen ?? 1
            var graph = try await store.expandedGraph(forDocumentId: key.documentId, volumeId: key.volumeId, degree: degree,
                                                      downloadedVolumeIds: downloaded)
            var widened = false
            if chosen == nil, CrossReferenceGraphDisplay.widensSparseGraph(loadedAtDegree: degree, edgeCount: graph.edgeCount) {
                let wider = try await store.expandedGraph(forDocumentId: key.documentId, volumeId: key.volumeId, degree: 2,
                                                          downloadedVolumeIds: downloaded)
                if CrossReferenceGraphDisplay.keepsWidenedGraph(wider, over: graph) {
                    graph = wider
                    widened = true
                }
            }
            let oneHop = try await store.graph(forDocumentId: key.documentId, volumeId: key.volumeId, downloadedVolumeIds: downloaded)
            return (graph, widened, oneHop)
        }

        /// The display the view model builds for a loaded graph (`loadUnprintedUnits`, `rebuildDisplay`).
        func display(_ key: DocumentKey, graph: CrossReferenceGraph, expanded: Set<String>) async throws
            -> (nodes: [DisplayNode], edges: [DisplayEdge], counts: [String: Int]) {
            let keys = graph.nodeMetadata.values.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
            let counts = try await store.connectionCounts(forKeys: keys)
            var rows: [String: [ExternalCitation]] = [:]
            for each in keys {
                let found = try await pipeline.externalCitations(volumeId: each.volumeId, documentId: each.documentId)
                if !found.isEmpty { rows["\(each.volumeId)/\(each.documentId)"] = found }
            }
            let units = CrossReferenceGraphDisplay.unitNodes(rowsByDocument: rows, authority: authority)
            let built = CrossReferenceGraphDisplay.buildDisplayNodesAndEdges(graph: graph, centralKey: key.compositeString,
                                                                             expandedClusterKeys: expanded, downloadedVolumeIds: downloaded)
            let attached = CrossReferenceGraphDisplay.attachingUnits(units, to: built.nodes, edges: built.edges)
            return (attached.nodes, attached.edges, counts)
        }
    }

    /// What one request asks, as the query string the browser sends.
    struct Ask: Sendable, CustomStringConvertible {
        var degree: Int?
        var layout: GraphLayoutMode?
        var width = 960.0
        var height = 560.0
        var expanded: [String] = []
        var expandedDates: [String] = []
        var domain: ClosedRange<TimeInterval>?

        var query: String {
            var items: [String] = []
            if let degree { items.append("degree=\(degree)") }
            if let layout { items.append("layout=\(layout.rawValue)") }
            items.append("width=\(Int(width))")
            items.append("height=\(Int(height))")
            for key in expanded { items.append("expand=\(Self.encoded(key))") }
            for key in expandedDates { items.append("expandDates=\(Self.encoded(key))") }
            if let domain { items.append("from=\(domain.lowerBound)&to=\(domain.upperBound)") }
            return items.joined(separator: "&")
        }

        var description: String { query }

        static func encoded(_ text: String) -> String {
            text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? text
        }
    }

    /// A coordinate or a date to nine significant places past the point: a value read back from JSON on
    /// Linux can differ from the kit's in its last bit.
    static func number(_ value: Double) -> String { String(format: "%.6f", value) }

    /// The kit's answer for one request, as lines: what the app's view model holds once it has loaded,
    /// built and laid out the graph.
    static func kit(_ host: Host, _ key: DocumentKey, _ ask: Ask) async throws -> [String] {
        let (graph, widened, oneHop) = try await host.loaded(key, degree: ask.degree)
        let (nodes, edges, counts) = try await host.display(key, graph: graph, expanded: Set(ask.expanded))
        let labels = CrossReferenceGraphDisplay.buildDateLabels(for: nodes)
        let values = CrossReferenceGraphDisplay.buildDateValues(for: nodes)
        let central = key.compositeString
        let eligible = CrossReferenceGraphDisplay.isTimelineEligible(centralKey: central, dateValues: values, nodes: nodes)
        let layout = ask.layout ?? (eligible ? .timeline : .network)
        let missing = Set(oneHop.undownloadedCitingVolumeIds)
        var lines = [
            "degree \(graph.fetchedDegree) widened \(widened) eligible \(eligible) drawn \(layout == .timeline && eligible ? "timeline" : "network")",
            "undownloaded \(graph.hasUndownloadedSources) \(oneHop.undownloadedCitingVolumeIds) \(graph.inboundEdges.count { missing.contains($0.sourceVolumeId) })",
        ]
        lines += nodes.map { node in
            nodeLine(node, label: labels[node.id], value: values[node.id], count: counts[node.id],
                     opens: node.isDownloaded && opensEntry(graph.nodeMetadata[node.id]))
        }
        lines += edges.map(edgeLine)
        func section(_ belongs: (DisplayNode) -> Bool) -> String {
            nodes.filter { !$0.isCentral && belongs($0) }.sorted(by: CrossReferenceGraphDisplay.precedesInReferenceList).map(\.id)
                .joined(separator: " ")
        }
        lines.append("inbound " + section { if case .inbound = $0.kind { true } else if case .clusterInbound = $0.kind { true } else { false } })
        lines.append("outbound " + section { if case .outbound = $0.kind { true } else if case .clusterOutbound = $0.kind { true } else { false } })
        lines.append("extended " + section { if case .extended = $0.kind { true } else { false } })
        if layout == .timeline && eligible {
            // FRUS-Explorer#1893: the server keeps the width at 116 or more; asked narrower, the kit is called at 116.
            let width = max(ask.width, 116)
            let clustered = CrossReferenceGraphDisplay.dateClusteredDisplay(
                nodes: nodes, edges: edges, dateValues: values, canvasWidth: width, expandedKeys: Set(ask.expandedDates),
                domain: ask.domain)
            let merged = values.merging(clustered.clusterDateValues) { base, _ in base }
            let laid = CrossReferenceGraphDisplay.timelineLayout(nodes: clustered.nodes, dateValues: merged, centralKey: central,
                                                                 canvasWidth: width, canvasHeight: ask.height, domain: ask.domain)
            lines.append("timeline \(number(width)) \(number(ask.height)) axis \(number(laid.axisY)) parked \(laid.hasParkedNodes)")
            lines.append("visible " + clustered.nodes.map(\.id).joined(separator: " "))
            lines += clustered.nodes.filter(\.isDateCluster).map { node in
                "cluster " + nodeLine(node, label: nil, value: clustered.clusterDateValues[node.id], count: nil, opens: false)
            }
            lines += clustered.edges.map { "timeline " + edgeLine($0) }
            lines += laid.positions.sorted { $0.key < $1.key }.map { "at \($0.key) \(number($0.value.x)) \(number($0.value.y))" }
            lines += laid.ticks.map { "tick \(number($0.x)) \($0.label)" }
        }
        return lines
    }

    static func edgeLine(_ edge: DisplayEdge) -> String {
        "edge \(edge.id) \(edge.referenceType.rawValue) \(edge.referenceCount) \(edge.degree) \(edge.contexts)"
    }

    /// A kit node as a line: its kind with what the kind carries, its place, its words and its numbers.
    static func nodeLine(_ node: DisplayNode, label: String?, value: TimeInterval?, count: Int?, opens: Bool) -> String {
        var kind: String
        switch node.kind {
        case .central: kind = "central"
        case .inbound: kind = "inbound"
        case .outbound: kind = "outbound"
        case .extended: kind = "extended"
        case .clusterInbound(let volume, let count): kind = "clusterInbound \(volume) \(count)"
        case .clusterOutbound(let volume, let count): kind = "clusterOutbound \(volume) \(count)"
        case .dateCluster(let period, let count, let members): kind = "dateCluster \(period) \(count) \(members)"
        case .unit(let id, let name): kind = "unit \(id) \(name)"
        case .centralFileClass(let key, let gloss): kind = "centralFileClass \(key) \(gloss ?? "-")"
        }
        let volume = node.terminatesWalk || node.isDateCluster ? nil : node.volumeId
        let meta = node.metadata
        let row = DocumentHeaderDisplay.numberedRow(header: meta?.header ?? node.id, number: meta?.documentNumber)
        let fields: [String?] = [
            node.id, kind, "\(node.degree)", "\(node.isDownloaded)", node.accessibilityLabel, title(for: node), row.title, row.number, label,
            value.map(number), volume, node.documentId, "\(node.isPageNode)", "\(opens)", meta?.header, meta?.dateline,
            meta?.documentNumber, meta?.citedPage.map(String.init), meta?.dating.map { "\($0)" }, count.map(String.init),
        ]
        return "node " + fields.map { $0 ?? "-" }.joined(separator: " | ")
    }

    /// The same line from the API's fields.
    static func nodeLine(_ node: DocumentGraph.Node) -> String {
        var kind = node.kind
        switch node.kind {
        case "clusterInbound", "clusterOutbound": kind += " \(node.volumeId ?? "-") \(node.count ?? -1)"
        case "dateCluster": kind += " \(node.period ?? "-") \(node.count ?? -1) \(node.members ?? [])"
        case "unit": kind += " \(node.collectionId ?? "-") \(node.name ?? "-")"
        case "centralFileClass": kind += " \(node.classKey ?? "-") \(node.gloss ?? "-")"
        default: break
        }
        let fields: [String?] = [
            node.id, kind, "\(node.degree)", "\(node.isDownloaded)", node.label, node.title, node.rowTitle, node.rowNumber, node.dateLabel,
            node.dateValue.map(number), node.volumeId, node.documentId, "\(node.isPageNode)", "\(node.opens)", node.header,
            node.dateline, node.documentNumber, node.citedPage.map(String.init), node.dating, node.connectionCount.map(String.init),
        ]
        return "node " + fields.map { $0 ?? "-" }.joined(separator: " | ")
    }

    /// A node's first label line, as the app's view writes it (`labelText(for:)`), with the kit's cut.
    static func title(for node: DisplayNode) -> String? {
        switch node.kind {
        case .clusterInbound(_, let count), .clusterOutbound(_, let count): return "\(count) docs"
        case .dateCluster(let period, let count, _): return "\(count) docs · \(period)"
        default:
            if let page = node.metadata?.citedPage { return "p. \(page)" }
            if let number = node.metadata?.documentNumber { return "Doc. \(number)" }
            if let header = node.metadata?.header {
                let cut = GraphNodeLabels.shortLabel(header.trimmingCharacters(in: .whitespaces), limit: 20)
                return cut.isEmpty ? nil : cut
            }
            return nil
        }
    }

    /// The app's `makeEntry(for:)`: a node opens when its metadata has a header and names no page.
    static func opensEntry(_ meta: CrossReferenceNodeMetadata?) -> Bool {
        guard let meta, meta.citedPage == nil, meta.header != nil else { return false }
        return true
    }

    /// The API's answer as the same lines.
    static func api(_ graph: DocumentGraph) -> [String] {
        var lines = [
            "degree \(graph.degree) widened \(graph.widened) eligible \(graph.timelineEligible) drawn \(graph.layout)",
            "undownloaded \(graph.hasUndownloadedSources) \(graph.undownloadedCitingVolumeIds) \(graph.undownloadedCitingCount)",
        ]
        lines += graph.nodes.map(nodeLine)
        lines += graph.edges.map(edgeLine)
        lines.append("inbound " + graph.referenceList.inbound.joined(separator: " "))
        lines.append("outbound " + graph.referenceList.outbound.joined(separator: " "))
        lines.append("extended " + graph.referenceList.extended.joined(separator: " "))
        if let timeline = graph.timeline {
            lines.append("timeline \(number(timeline.width)) \(number(timeline.height)) axis \(number(timeline.axisY)) parked \(timeline.hasParkedNodes)")
            lines.append("visible " + timeline.visible.joined(separator: " "))
            lines += timeline.dateClusters.map { "cluster " + nodeLine($0) }
            lines += timeline.edges.map { "timeline " + edgeLine($0) }
            lines += timeline.positions.sorted { $0.key < $1.key }.map { "at \($0.key) \(number($0.value.x)) \(number($0.value.y))" }
            lines += timeline.ticks.map { "tick \(number($0.x)) \($0.label)" }
        }
        return lines
    }

    static func edgeLine(_ edge: DocumentGraph.Edge) -> String {
        "edge \(edge.id) \(edge.referenceType) \(edge.referenceCount) \(edge.degree) \(edge.contexts)"
    }

    /// Every document the fixture index holds.
    static func documents() async throws -> [DocumentKey] {
        try await RelatedDocumentsParityTests.documents()
    }

    /// Every fixture document's graph through the API is the kit's: as it opens, with no degree or layout
    /// chosen, so a sparse graph is widened and the timeline drawn where it can be; at each degree chosen;
    /// and, for a seventh of them, in the network layout, at canvases narrow and wide, with a volume or
    /// date cluster expanded and over a brushed window.
    @Test func everyFixtureDocumentsGraphIsTheKits() async throws {
        let host = try await Host.open()
        let documents = try await Self.documents()
        #expect(documents.count > 100, "the three fixture volumes' documents")
        var asks: [(DocumentKey, Ask)] = []
        for (index, document) in documents.enumerated() {
            asks.append((document, Ask()))
            for degree in 1...3 { asks.append((document, Ask(degree: degree))) }
            guard index.isMultiple(of: 7) else { continue }
            asks.append((document, Ask(layout: .network)))
            asks.append((document, Ask(degree: 3, layout: .timeline, width: 400, height: 300)))
            asks.append((document, Ask(degree: 2, width: 1_800, height: 1_100)))
        }
        // A volume cluster, a date cluster and a brushed window, wherever the fixtures have them.
        asks += try await Self.expansions(host, documents)
        let asked = asks
        let read = try await ServedFixture.run { client, _ in
            var read: [DocumentGraph] = []
            for (document, ask) in asked {
                let response = try await client.execute(
                    uri: "/api/v1/volumes/\(document.volumeId)/documents/\(document.documentId)/graph?\(ask.query)", method: .get)
                guard response.status == .ok else {
                    throw APIParityError("\(document.compositeString) \(ask): \(response.status.code) \(String(buffer: response.body))")
                }
                read.append(try ServedFixture.decode(DocumentGraph.self, response))
            }
            return read
        }

        var tally = (widened: 0, timelines: 0, units: 0, classes: 0, clusters: 0, dateClusters: 0, extended: 0, undownloaded: 0)
        for ((document, ask), graph) in zip(asks, read) {
            let kit = try await Self.kit(host, document, ask)
            let api = Self.api(graph)
            #expect(api == kit, "\(document.compositeString) \(ask): \(Self.difference(api, kit))")
            #expect(graph.centralKey == document.compositeString && graph.chosenDegree == ask.degree
                    && graph.chosenLayout == ask.layout?.rawValue && graph.expandedClusters == ask.expanded)
            if graph.widened { tally.widened += 1 }
            if let timeline = graph.timeline {
                tally.timelines += 1
                if !timeline.dateClusters.isEmpty { tally.dateClusters += 1 }
            }
            if graph.nodes.contains(where: { $0.kind == "unit" }) { tally.units += 1 }
            if graph.nodes.contains(where: { $0.kind == "centralFileClass" }) { tally.classes += 1 }
            if graph.nodes.contains(where: { $0.kind.hasPrefix("cluster") }) { tally.clusters += 1 }
            if graph.nodes.contains(where: { $0.kind == "extended" }) { tally.extended += 1 }
            if !graph.undownloadedCitingVolumeIds.isEmpty { tally.undownloaded += 1 }
        }
        // The comparison reached every part of the display the fixtures have.
        #expect(tally.widened > 0 && tally.timelines > 0 && tally.extended > 0 && tally.undownloaded > 0, "\(tally)")
        #expect(tally.units > 0 && tally.classes > 0, "the fixtures' footnotes cite lot files and central files: \(tally)")
        #expect(tally.dateClusters > 0, "a timeline gathers four or more nearby documents: \(tally)")
    }

    /// Requests that expand a volume cluster and a date cluster, and brush a window, of the first
    /// documents whose graphs have them.
    static func expansions(_ host: Host, _ documents: [DocumentKey]) async throws -> [(DocumentKey, Ask)] {
        var asks: [(DocumentKey, Ask)] = []
        var foundCluster = false, foundDateCluster = false, foundRange = false
        for document in documents where !(foundCluster && foundDateCluster && foundRange) {
            for degree in [1, 3] {
                let (graph, _, _) = try await host.loaded(document, degree: degree)
                let (nodes, edges, _) = try await host.display(document, graph: graph, expanded: [])
                if !foundCluster, let cluster = nodes.first(where: \.isCluster) {
                    asks.append((document, Ask(degree: degree, expanded: [cluster.id])))
                    foundCluster = true
                }
                let values = CrossReferenceGraphDisplay.buildDateValues(for: nodes)
                guard CrossReferenceGraphDisplay.isTimelineEligible(centralKey: document.compositeString, dateValues: values,
                                                                    nodes: nodes) else { continue }
                let clustered = CrossReferenceGraphDisplay.dateClusteredDisplay(nodes: nodes, edges: edges, dateValues: values,
                                                                               canvasWidth: 960, expandedKeys: [])
                if !foundDateCluster, let dated = clustered.nodes.first(where: \.isDateCluster) {
                    asks.append((document, Ask(degree: degree, expandedDates: [dated.id])))
                    foundDateCluster = true
                }
                if !foundRange, let lower = values.values.min(), let upper = values.values.max(), upper > lower {
                    let quarter = (upper - lower) / 4
                    asks.append((document, Ask(degree: degree, domain: (lower + quarter)...(upper - quarter))))
                    foundRange = true
                }
            }
        }
        #expect(foundDateCluster && foundRange, "the fixtures have a date cluster and a dated span to brush")
        return asks
    }

    /// The first lines at which two answers part, for a failure's message.
    static func difference(_ api: [String], _ kit: [String]) -> String {
        let first = api.indices.first { $0 >= kit.count || api[$0] != kit[$0] }
        guard let index = first ?? (api.count == kit.count ? nil : min(api.count, kit.count)) else { return "the same" }
        return "line \(index): API \(index < api.count ? api[index] : "(none)") — kit \(index < kit.count ? kit[index] : "(none)")"
    }

    /// The two upstream issues, as they stand at this pin. When either fails, its fix has merged: drop the
    /// workaround its comment names in `CrossReferenceGraph.swift`, and this test's half for it.
    @Test func theTwoUpstreamIssuesStandAtThisPin() async throws {
        let host = try await Host.open()
        let documents = try await Self.documents()
        // FRUS-Explorer#1892: a document whose citers include volumes not served keeps them at one hop and
        // loses them at two, though its inbound edges are the degree-1 graph's.
        var dropped = 0
        for document in documents {
            let one = try await host.store.graph(forDocumentId: document.documentId, volumeId: document.volumeId,
                                                 downloadedVolumeIds: host.downloaded)
            guard !one.undownloadedCitingVolumeIds.isEmpty else { continue }
            let two = try await host.store.expandedGraph(forDocumentId: document.documentId, volumeId: document.volumeId,
                                                         degree: 2, downloadedVolumeIds: host.downloaded)
            #expect(two.hasUndownloadedSources && two.inboundEdges.count == one.inboundEdges.count)
            if two.undownloadedCitingVolumeIds.isEmpty { dropped += 1 }
        }
        #expect(dropped > 0, "FRUS-Explorer#1892 still drops the volumes at two hops; once it does not, the workaround can go")
        // FRUS-Explorer#1893: the API lays a timeline asked at 50 pt out at 116, where the kit's would trap.
        let read = try await ServedFixture.run { client, _ in
            var widths: [Double] = []
            for document in documents.prefix(60) {
                let response = try await client.execute(
                    uri: "/api/v1/volumes/\(document.volumeId)/documents/\(document.documentId)/graph?degree=3&width=50", method: .get)
                if let timeline = try ServedFixture.decode(DocumentGraph.self, response).timeline { widths.append(timeline.width) }
            }
            return widths
        }
        #expect(!read.isEmpty && read.allSatisfy { $0 == 116 }, "\(read)")
        let kitFile = try ProjectHistoryParityTests.kit("FRUSCoreKit/CrossReference/CrossReferenceGraphDisplay.swift")
        #expect(kitFile.contains("visibleRange: (padLeading - 8)...(canvasWidth - padTrailing + 28)"),
                "FRUS-Explorer#1893's range is as it was; once it keeps its ends in order, the clamp can go")
        let storeFile = try ProjectHistoryParityTests.kit("FRUSCoreKit/CrossReference/CrossReferenceStore.swift")
        #expect(!storeFile.contains("undownloadedCitingVolumeIds: base.undownloadedCitingVolumeIds"),
                "FRUS-Explorer#1892's return is as it was; once it passes the volumes on, the degree-1 graph need not be read")
    }

    /// The server's mirror of the app's view model, the order it calls the kit in and the view's few rules
    /// the answer carries, as the app's source writes them.
    @Test func theMirrorsAreTheApps() throws {
        let model = try ProjectHistoryParityTests.app("CrossReference/CrossReferenceGraphViewModel.swift")
        NoteViewParityTests.expect(model, holds: [
            "let degree = graphDegree",
            "if !userAdjustedDegree, CrossReferenceGraphDisplay.widensSparseGraph(loadedAtDegree: degree, edgeCount: loaded.edgeCount) {",
            "degree: 2, downloadedVolumeIds: downloadedVolumeIds ) if CrossReferenceGraphDisplay.keepsWidenedGraph(widened, over: loaded) {",
            "let keys = graph.nodeMetadata.values.map { (volumeId: $0.volumeId, documentId: $0.documentId) }",
            "nodeConnectionCounts = (try? await store.connectionCounts(forKeys: keys)) ?? [:] await loadUnprintedUnits(keys: keys)",
            "let rows = (try? await pipeline.externalCitations(volumeId: key.volumeId, documentId: key.documentId)) ?? []",
            "guard let authority = CollectionAuthorityStore.shared else { return [:] }",
            "return CrossReferenceGraphDisplay.unitNodes(rowsByDocument: snapshot, authority: authority)",
            "let (nodes, edges) = CrossReferenceGraphDisplay.attachingUnits(unitsByDocument, to: built.nodes, edges: built.edges)",
            "nodeDateLabels = CrossReferenceGraphDisplay.buildDateLabels(for: nodes) nodeDateValues = CrossReferenceGraphDisplay.buildDateValues(for: nodes)",
            "if !userPickedLayoutMode { layoutMode = timelineEligible ? .timeline : .network }",
            "if layoutMode == .timeline && timelineEligible {",
            "let layoutDates = nodeDateValues.merging(clustered.clusterDateValues) { base, _ in base }",
            "return graph.inboundEdges.count { missing.contains($0.sourceVolumeId) }",
            "guard let meta = graph?.nodeMetadata[nodeKey], meta.citedPage == nil, let header = meta.header else { return nil }",
        ], file: "CrossReferenceGraphViewModel.swift")
        let server = try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/CrossReferenceGraph.swift")
        NoteViewParityTests.expect(server, holds: [
            "let degree = request.chosenDegree ?? 1",
            "if request.chosenDegree == nil, CrossReferenceGraphDisplay.widensSparseGraph(loadedAtDegree: degree, edgeCount: loaded.edgeCount) {",
            "if CrossReferenceGraphDisplay.keepsWidenedGraph(wider, over: loaded) {",
            "let keys = loaded.nodeMetadata.values.map { (volumeId: $0.volumeId, documentId: $0.documentId) }",
            "let counts = (try? await store.connectionCounts(forKeys: keys)) ?? [:]",
            "let rows = (try? await pipeline.externalCitations(volumeId: key.volumeId, documentId: key.documentId)) ?? []",
            "return CrossReferenceGraphDisplay.unitNodes(rowsByDocument: rowsByDocument, authority: authority)",
            "let (nodes, edges) = CrossReferenceGraphDisplay.attachingUnits(units, to: built.nodes, edges: built.edges)",
            "let layout = request.chosenLayout ?? (eligible ? .timeline : .network)",
            "if layout == .timeline && eligible {",
            "let layoutDates = dateValues.merging(clustered.clusterDateValues) { base, _ in base }",
            "undownloadedCitingCount: loaded.inboundEdges.count { missing.contains($0.sourceVolumeId) }",
            "guard let meta = metadata, meta.citedPage == nil, meta.header != nil else { return false }",
        ], file: "CrossReferenceGraph.swift")
        // A node's first label line, the view's `labelText(for:)`, and the server's.
        let view = try ProjectHistoryParityTests.app("CrossReference/CrossReferenceGraphView.swift")
        NoteViewParityTests.expect(view, holds: [
            #"String(localized: "graph.node.cluster.docsLabel %lld", defaultValue: "%lld docs"), Int64(count)"#,
            #"String(localized: "graph.node.dateCluster.label %lld %@", defaultValue: "%lld docs · %@"), Int64(count), periodLabel"#,
            #"if let page = node.metadata?.citedPage {"#,
            #"String(localized: "graph.node.page %lld", defaultValue: "p. %lld"), Int64(page)"#,
            #"} else if let num = node.metadata?.documentNumber {"#,
            #"String(localized: "graph.node.docNumber %@", defaultValue: "Doc. %@"), num"#,
            "} else if let header = node.metadata?.header { let trimmed = header.trimmingCharacters(in: .whitespaces) return GraphNodeLabels.shortLabel(trimmed, limit: 20) } return \"\"",
        ], file: "CrossReferenceGraphView.swift")
        NoteViewParityTests.expect(server, holds: [
            #"text = "\(count) docs""#, #"text = "\(count) docs · \(periodLabel)""#,
            "if let page = node.metadata?.citedPage {", #"text = "p. \(page)""#,
            "} else if let num = node.metadata?.documentNumber {", #"text = "Doc. \(num)""#,
            "} else if let header = node.metadata?.header { let trimmed = header.trimmingCharacters(in: .whitespaces) text = GraphNodeLabels.shortLabel(trimmed, limit: 20)",
        ], file: "CrossReferenceGraph.swift")
    }
}
