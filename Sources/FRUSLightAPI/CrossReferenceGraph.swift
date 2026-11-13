// The cross-reference graph (PLAN's S23e): a document's graph as the app's graph view draws it, built by
// the kit's store and display half (FRUS-Explorer#1891) over the served index and the server's data
// files, in the order the app's `CrossReferenceGraphViewModel` calls them:
// - `loadGraph`: the store's `expandedGraph` at the degree the reader chose, or, while they have chosen
//   none, at one hop, widened to two when that graph is sparse and the wider one adds edges
//   (`widensSparseGraph`, `keepsWidenedGraph`); then the corpus-wide connection counts the app sizes its
//   nodes by (`connectionCounts`) and the unprinted units and central-file classes the graph's documents
//   point at (`loadUnprintedUnits`: the pipeline's `externalCitations`, the kit's `unitNodes` over the
//   bundled collection authority);
// - `rebuildDisplay`: the display build with its volume clusters, the units attached to the documents it
//   kept, the date labels and values, and the default layout, the timeline whenever the graph can be
//   drawn as one;
// - `rerunLayout`: the timeline's date clusters and layout, at the canvas size the browser names.
// Every computation is the kit's, compiled from the submodule; that order, and the view's few rules the
// answer carries (a node's label, `makeEntry`'s test of what opens), are mirrored and held to the app's
// source by `CrossReferenceGraphParityTests`. The network layout is the browser's, as it is the app's
// view's, and the reference list's sections are in the kit's order (`precedesInReferenceList`).
//
// Two of the kit's behaviours are worked around until upstream fixes them, each where it is met:
// FRUS-Explorer#1892, a graph loaded at two or three hops drops `undownloadedCitingVolumeIds`, so the
// volumes are taken from the degree-1 graph; and FRUS-Explorer#1893, `timelineLayout` traps on a canvas
// narrower than 116 pt, so the width is kept at 116 or more before the timeline is laid out.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// A document's cross-reference graph, as the app's graph view draws it.
public struct DocumentGraph: Codable, Equatable, Sendable, ResponseEncodable {
    public var volumeId: String
    public var documentId: String
    /// The central node's key, `volumeId/documentId`.
    public var centralKey: String
    /// The hops the reader chose, or nil while they have chosen none.
    public var chosenDegree: Int?
    /// The hops the graph was loaded at: the reader's choice, else one, or two when a sparse graph was widened.
    public var degree: Int
    /// Whether a sparse graph was widened to two hops, the app's "Few direct references — showing 2 hops".
    public var widened: Bool
    /// The layout the reader chose, `timeline` or `network`, or nil while they have chosen none.
    public var chosenLayout: String?
    /// The layout drawn: the timeline when it is chosen, or chosen by default, and the graph can be drawn as one.
    public var layout: String
    /// Whether the graph can be drawn as a timeline (`isTimelineEligible`), which the layout picker needs.
    public var timelineEligible: Bool
    /// Whether a volume this server does not serve cites the document.
    public var hasUndownloadedSources: Bool
    /// Those volumes, sorted, from the degree-1 graph (FRUS-Explorer#1892).
    public var undownloadedCitingVolumeIds: [String]
    /// How many of the document's citing documents are in those volumes: the app's banner's first figure.
    public var undownloadedCitingCount: Int
    /// The volume clusters the reader expanded, as asked.
    public var expandedClusters: [String]
    /// The display build's nodes with the archival nodes after them (`attachingUnits`), in its order: what
    /// the network draws and the reference list lists.
    public var nodes: [Node]
    /// Their edges, one for each pair of documents, aggregated as the kit aggregates them.
    public var edges: [Edge]
    /// The reference list's sections, each in the kit's order (`precedesInReferenceList`).
    public var referenceList: ReferenceList
    /// The timeline, when it is the layout drawn, laid out at the canvas size the request named.
    public var timeline: Timeline?

    /// A node of the graph (`DisplayNode`).
    public struct Node: Codable, Equatable, Sendable {
        /// Its key: `volumeId/documentId` for a document or a page, else the cluster's, unit's or class's own.
        public var id: String
        /// `central`, `inbound`, `outbound`, `extended`, `clusterInbound`, `clusterOutbound`, `dateCluster`,
        /// `unit` or `centralFileClass`.
        public var kind: String
        /// Its hops from the central document: 0 for it, 1 for its direct references, 2 or 3 for further ones.
        public var degree: Int
        /// Whether this server serves its volume; true for an archival node, which has none.
        public var isDownloaded: Bool
        /// What a screen reader hears for it, the kit's `accessibilityLabel`.
        public var label: String
        /// Its first label line on the canvas, as the app's view writes it, or nil for none.
        public var title: String?
        /// Its date as the canvas labels it (`buildDateLabels`), or nil.
        public var dateLabel: String?
        /// Its date as the timeline places it (`buildDateValues`): seconds since 2001, or nil.
        public var dateValue: Double?
        /// Its volume: the document's, the cluster's, or nil for an archival node.
        public var volumeId: String?
        /// The document or page it stands for, or nil for a cluster or an archival node.
        public var documentId: String?
        /// Whether it is a page of a volume rather than a document (`isPageNode`), which opens nothing.
        public var isPageNode: Bool
        /// Whether the reader can open its document, the app's `makeEntry` (a header and no cited page) and
        /// its volume served.
        public var opens: Bool
        public var header: String?
        public var dateline: String?
        public var documentNumber: String?
        /// The page it names, for a page node.
        public var citedPage: Int?
        /// How a node the index holds no row for is dated: `pageIndex`, `pageMap` or `volume`.
        public var dating: String?
        /// The documents a volume or date cluster stands for.
        public var count: Int?
        /// A date cluster's period, "Jun 1967".
        public var period: String?
        /// The keys of the documents a date cluster stands for.
        public var members: [String]?
        /// A unit's collection record and its name.
        public var collectionId: String?
        public var name: String?
        /// A central-file class's number, and its gloss, which the kit leaves out (`classGloss`).
        public var classKey: String?
        public var gloss: String?
        /// Its references across the corpus's index (`connectionCounts`), which the app sizes it by.
        public var connectionCount: Int?
    }

    /// An edge (`DisplayEdge`): every reference from one node to another, aggregated.
    public struct Edge: Codable, Equatable, Sendable {
        /// `source->target`.
        public var id: String
        public var source: String
        public var target: String
        /// `editorialNote` when every reference it aggregates is one, else `footnote`.
        public var referenceType: String
        /// The text of each note that held a reference, in order.
        public var contexts: [String]
        public var referenceCount: Int
        public var degree: Int
    }

    /// The reference list's sections, by node key: the documents and volume clusters citing the document,
    /// those it cites, and those further hops out.
    public struct ReferenceList: Codable, Equatable, Sendable {
        public var inbound: [String]
        public var outbound: [String]
        public var extended: [String]
    }

    /// The timeline the kit lays out (`dateClusteredDisplay`, `timelineLayout`).
    public struct Timeline: Codable, Equatable, Sendable {
        /// The canvas it was laid out on, in points: the width at least 116 (FRUS-Explorer#1893).
        public var width: Double
        public var height: Double
        /// The nodes drawn, in the clustered display's order: the nodes of `nodes` no date cluster holds,
        /// then the date clusters.
        public var visible: [String]
        /// The date clusters, whose members are left out of `visible`.
        public var dateClusters: [Node]
        /// The clustered display's edges, an edge to a member of a date cluster drawn to the cluster.
        public var edges: [Edge]
        /// Each node's place on the canvas; a dated node outside the brushed window has none.
        public var positions: [String: Point]
        /// The date axis's ticks, its height, and whether an Undated column is drawn at its end.
        public var ticks: [Tick]
        public var axisY: Double
        public var hasParkedNodes: Bool
        /// The dates of the graph's dated nodes, the earliest and the latest (`timelineFullDateRange`), or nil
        /// when they span no time.
        public var fullRange: Span?
        /// The window the request brushed, or nil for the whole range.
        public var domain: Span?
        /// The date clusters the reader expanded, as asked.
        public var expandedDateClusters: [String]
    }

    public struct Point: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double
    }

    public struct Tick: Codable, Equatable, Sendable {
        public var x: Double
        public var label: String
    }

    /// A span of dates, in seconds since 2001.
    public struct Span: Codable, Equatable, Sendable {
        public var from: Double
        public var to: Double
    }
}

/// What a request asks of a graph, as the app's view model holds it as state: the degree and layout the
/// reader picked, the clusters they expanded, the canvas's size and the brushed window.
struct GraphRequest: Sendable, Equatable {
    var chosenDegree: Int?
    var chosenLayout: GraphLayoutMode?
    var expandedClusters: [String] = []
    var expandedDateClusters: [String] = []
    var width: Double = Double(CrossReferenceGraphRoutes.defaultWidth)
    var height: Double = Double(CrossReferenceGraphRoutes.defaultHeight)
    var domain: ClosedRange<TimeInterval>?
}

enum CrossReferenceGraphRoutes {
    /// The canvas a request that names none is laid out on, in points.
    static let defaultWidth = 960
    static let defaultHeight = 560
    /// The widest and tallest canvas laid out: the timeline's lanes grow with the height.
    static let maximumSide = 4_096
    /// FRUS-Explorer#1893: `timelineLayout` builds its axis's tick range as `48...(width - 68)`, which traps
    /// below 116 pt. Until upstream keeps the range's ends in order, the width is kept at this or more.
    static let narrowestTimeline = 116.0
    /// The most expanded clusters, of either kind, a request names, and the longest key.
    static let maximumExpanded = 512
    static let maximumKeyLength = 1_024

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/volumes/:volumeId/documents/:documentId/graph") { request, context -> DocumentGraph in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["degree", "layout", "expand", "expandDates", "width", "height", "from", "to"])
            let volumeId = try context.parameters.require("volumeId")
            let documentId = try context.parameters.require("documentId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            guard documentId.utf8.count <= 256, FRUSURLScheme.isSafeComponent(documentId) else {
                throw APIProblem.invalidParameter("documentId", "\(documentId) is not a document's id.")
            }
            let asked = try graphRequest(query)
            let served = try await provider.served()
            let authority = try await Blocking.run { resources.collectionAuthority }
            return try await graph(volumeId: volumeId, documentId: documentId, request: asked, served: served,
                                   authority: authority)
        }
    }

    /// The request's state, each value checked: a degree of 1 to 3, a layout, expanded keys of the kinds the
    /// kit makes, a canvas of 1 to 4,096 points a side, and a brushed window whose start is before its end.
    static func graphRequest(_ query: FormQuery) throws -> GraphRequest {
        var asked = GraphRequest()
        asked.chosenDegree = try query.optionalInteger("degree", in: 1...3)
        asked.chosenLayout = try query.choice("layout", among: GraphLayoutMode.allCases)
        asked.expandedClusters = try keys(query, "expand", prefixes: ["cluster/inbound/", "cluster/outbound/"])
        asked.expandedDateClusters = try keys(query, "expandDates", prefixes: ["datecluster/"])
        asked.width = Double(try query.integer("width", in: 1...maximumSide, default: defaultWidth))
        asked.height = Double(try query.integer("height", in: 1...maximumSide, default: defaultHeight))
        switch (try query.single("from"), try query.single("to")) {
        case (nil, nil):
            break
        case let (from?, to?):
            guard let lower = Double(from), let upper = Double(to), lower.isFinite, upper.isFinite else {
                throw APIProblem.invalidParameter("from", "from and to must be numbers of seconds since 2001, not \(from) and \(to)")
            }
            guard lower < upper else { throw APIProblem.invalidParameter("from", "the window must start before it ends") }
            asked.domain = lower...upper
        default:
            throw APIProblem.invalidParameter("from", "a window needs both from and to")
        }
        return asked
    }

    /// A list of keys, each starting with one of `prefixes`, none empty past it and none too long.
    static func keys(_ query: FormQuery, _ name: String, prefixes: [String]) throws -> [String] {
        let keys = try query.list(name) ?? []
        guard keys.count <= maximumExpanded else {
            throw APIProblem.invalidParameter(name, "names \(keys.count) clusters, more than \(maximumExpanded)")
        }
        for key in keys {
            guard key.utf8.count <= maximumKeyLength,
                  prefixes.contains(where: { key.hasPrefix($0) && key.count > $0.count }) else {
                throw APIProblem.invalidParameter(name, "\(key) is not a cluster's key")
            }
        }
        return keys
    }

    /// The graph of one document, as the app's view model loads, builds and lays it out.
    static func graph(volumeId: String, documentId: String, request: GraphRequest, served: ServedIndex,
                      authority: CollectionAuthorityIndex?) async throws -> DocumentGraph {
        let store = served.crossReferences
        let downloaded = served.indexedVolumeIds
        let centralKey = "\(volumeId)/\(documentId)"

        // `loadGraph`: the reader's degree, or one hop widened to two while they have chosen none.
        let degree = request.chosenDegree ?? 1
        var loaded = try await store.expandedGraph(forDocumentId: documentId, volumeId: volumeId, degree: degree,
                                                   downloadedVolumeIds: downloaded)
        // FRUS-Explorer#1892: at two or three hops the store leaves `undownloadedCitingVolumeIds` empty, so the
        // degree-1 graph names them. Until the fix merges upstream, it is kept here before any widening.
        var oneHop: CrossReferenceGraph? = degree == 1 ? loaded : nil
        var widened = false
        if request.chosenDegree == nil,
           CrossReferenceGraphDisplay.widensSparseGraph(loadedAtDegree: degree, edgeCount: loaded.edgeCount) {
            let wider = try await store.expandedGraph(forDocumentId: documentId, volumeId: volumeId, degree: 2,
                                                      downloadedVolumeIds: downloaded)
            if CrossReferenceGraphDisplay.keepsWidenedGraph(wider, over: loaded) {
                loaded = wider
                widened = true
            }
        }
        if oneHop == nil {
            oneHop = try await store.graph(forDocumentId: documentId, volumeId: volumeId, downloadedVolumeIds: downloaded)
        }
        let undownloaded = oneHop?.undownloadedCitingVolumeIds ?? []
        let missing = Set(undownloaded)

        // Then the connection counts and the unprinted units, over every node the graph holds metadata for.
        let keys = loaded.nodeMetadata.values.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        let counts = (try? await store.connectionCounts(forKeys: keys)) ?? [:]
        let units = await unitNodes(keys: keys, pipeline: served.pipeline, authority: authority)

        // `rebuildDisplay`.
        let built = CrossReferenceGraphDisplay.buildDisplayNodesAndEdges(
            graph: loaded, centralKey: centralKey, expandedClusterKeys: Set(request.expandedClusters),
            downloadedVolumeIds: downloaded)
        let (nodes, edges) = CrossReferenceGraphDisplay.attachingUnits(units, to: built.nodes, edges: built.edges)
        let dateLabels = CrossReferenceGraphDisplay.buildDateLabels(for: nodes)
        let dateValues = CrossReferenceGraphDisplay.buildDateValues(for: nodes)
        let eligible = CrossReferenceGraphDisplay.isTimelineEligible(centralKey: centralKey, dateValues: dateValues,
                                                                     nodes: nodes)
        let layout = request.chosenLayout ?? (eligible ? .timeline : .network)

        // `rerunLayout`: the timeline, when it is drawn.
        var timeline: DocumentGraph.Timeline?
        if layout == .timeline && eligible {
            timeline = laidOutTimeline(nodes: nodes, edges: edges, dateValues: dateValues, centralKey: centralKey,
                                       request: request, counts: counts, metadata: loaded.nodeMetadata)
        }

        func encoded(_ node: DisplayNode) -> DocumentGraph.Node {
            Self.node(node, dateLabel: dateLabels[node.id], dateValue: dateValues[node.id],
                      connectionCount: counts[node.id], metadata: loaded.nodeMetadata[node.id])
        }
        func section(_ belongs: (DisplayNode) -> Bool) -> [String] {
            nodes.filter { !$0.isCentral && belongs($0) }.sorted(by: CrossReferenceGraphDisplay.precedesInReferenceList).map(\.id)
        }
        return DocumentGraph(
            volumeId: volumeId, documentId: documentId, centralKey: centralKey,
            chosenDegree: request.chosenDegree, degree: loaded.fetchedDegree, widened: widened,
            chosenLayout: request.chosenLayout?.rawValue,
            layout: timeline == nil ? GraphLayoutMode.network.rawValue : GraphLayoutMode.timeline.rawValue,
            timelineEligible: eligible,
            hasUndownloadedSources: loaded.hasUndownloadedSources,
            undownloadedCitingVolumeIds: undownloaded,
            // The app's `undownloadedCitingCount`: the inbound edges from those volumes.
            undownloadedCitingCount: loaded.inboundEdges.count { missing.contains($0.sourceVolumeId) },
            expandedClusters: request.expandedClusters,
            nodes: nodes.map(encoded),
            edges: edges.map(Self.edge),
            referenceList: .init(
                inbound: section { if case .inbound = $0.kind { true } else if case .clusterInbound = $0.kind { true } else { false } },
                outbound: section { if case .outbound = $0.kind { true } else if case .clusterOutbound = $0.kind { true } else { false } },
                extended: section { if case .extended = $0.kind { true } else { false } }),
            timeline: timeline)
    }

    /// The archival nodes of every graph document's unprinted pointers (`loadUnprintedUnits`): the pipeline's
    /// citations for each document, by key, and the kit's nodes for them over the collection authority, none
    /// without it, as the app has none when its store cannot load.
    static func unitNodes(keys: [(volumeId: String, documentId: String)], pipeline: IndexingPipeline,
                          authority: CollectionAuthorityIndex?) async -> [String: [DisplayNode]] {
        var rowsByDocument: [String: [ExternalCitation]] = [:]
        for key in keys {
            let rows = (try? await pipeline.externalCitations(volumeId: key.volumeId, documentId: key.documentId)) ?? []
            guard !rows.isEmpty else { continue }
            rowsByDocument["\(key.volumeId)/\(key.documentId)"] = rows
        }
        guard !rowsByDocument.isEmpty, let authority else { return [:] }
        return CrossReferenceGraphDisplay.unitNodes(rowsByDocument: rowsByDocument, authority: authority)
    }

    /// The timeline at the request's canvas, its width at least 116 (FRUS-Explorer#1893): the kit's date
    /// clusters, then its layout over the clustered display with the clusters' dates merged.
    static func laidOutTimeline(nodes: [DisplayNode], edges: [DisplayEdge], dateValues: [String: TimeInterval],
                                centralKey: String, request: GraphRequest, counts: [String: Int],
                                metadata: [String: CrossReferenceNodeMetadata]) -> DocumentGraph.Timeline {
        // FRUS-Explorer#1893: kept at 116 or more until upstream keeps the tick range's ends in order.
        let width = max(request.width, narrowestTimeline)
        let clustered = CrossReferenceGraphDisplay.dateClusteredDisplay(
            nodes: nodes, edges: edges, dateValues: dateValues, canvasWidth: width,
            expandedKeys: Set(request.expandedDateClusters), domain: request.domain)
        let layoutDates = dateValues.merging(clustered.clusterDateValues) { base, _ in base }
        let result = CrossReferenceGraphDisplay.timelineLayout(
            nodes: clustered.nodes, dateValues: layoutDates, centralKey: centralKey,
            canvasWidth: width, canvasHeight: request.height, domain: request.domain)
        // The app's `timelineFullDateRange`: every dated node's, before any brush.
        let values = dateValues.values
        let full = values.min().flatMap { lower in values.max().flatMap { upper in upper > lower ? (lower, upper) : nil } }
        let clusters = clustered.nodes.filter(\.isDateCluster)
        return DocumentGraph.Timeline(
            width: width, height: request.height,
            visible: clustered.nodes.map(\.id),
            dateClusters: clusters.map {
                node($0, dateLabel: nil, dateValue: clustered.clusterDateValues[$0.id], connectionCount: counts[$0.id],
                     metadata: metadata[$0.id])
            },
            edges: clustered.edges.map(edge),
            positions: result.positions.mapValues { .init(x: $0.x, y: $0.y) },
            ticks: result.ticks.map { .init(x: $0.x, label: $0.label) },
            axisY: result.axisY, hasParkedNodes: result.hasParkedNodes,
            fullRange: full.map { .init(from: $0.0, to: $0.1) },
            domain: request.domain.map { .init(from: $0.lowerBound, to: $0.upperBound) },
            expandedDateClusters: request.expandedDateClusters)
    }

    static func node(_ node: DisplayNode, dateLabel: String?, dateValue: TimeInterval?, connectionCount: Int?,
                     metadata: CrossReferenceNodeMetadata?) -> DocumentGraph.Node {
        var encoded = DocumentGraph.Node(
            id: node.id, kind: kindName(node.kind), degree: node.degree, isDownloaded: node.isDownloaded,
            label: node.accessibilityLabel, title: labelText(for: node), dateLabel: dateLabel, dateValue: dateValue,
            // The kit's best-effort volume reads a key's first part, which an archival node's and a date
            // cluster's name no volume.
            volumeId: node.terminatesWalk || node.isDateCluster ? nil : node.volumeId,
            documentId: node.documentId, isPageNode: node.isPageNode,
            opens: node.isDownloaded && opensEntry(metadata),
            header: node.metadata?.header, dateline: node.metadata?.dateline, documentNumber: node.metadata?.documentNumber,
            citedPage: node.metadata?.citedPage, dating: node.metadata?.dating.map(datingName),
            connectionCount: connectionCount)
        switch node.kind {
        case .clusterInbound(_, let count), .clusterOutbound(_, let count):
            encoded.count = count
        case .dateCluster(let label, let count, let members):
            encoded.count = count
            encoded.period = label
            encoded.members = members
        case .unit(let collectionId, let name):
            encoded.collectionId = collectionId
            encoded.name = name
        case .centralFileClass(let key, let gloss):
            encoded.classKey = key
            encoded.gloss = gloss
        case .central, .inbound, .outbound, .extended:
            break
        }
        return encoded
    }

    static func edge(_ edge: DisplayEdge) -> DocumentGraph.Edge {
        DocumentGraph.Edge(id: edge.id, source: edge.source, target: edge.target, referenceType: edge.referenceType.rawValue,
                           contexts: edge.contexts, referenceCount: edge.referenceCount, degree: edge.degree)
    }

    static func kindName(_ kind: DisplayNode.Kind) -> String {
        switch kind {
        case .central: "central"
        case .inbound: "inbound"
        case .outbound: "outbound"
        case .extended: "extended"
        case .clusterInbound: "clusterInbound"
        case .clusterOutbound: "clusterOutbound"
        case .dateCluster: "dateCluster"
        case .unit: "unit"
        case .centralFileClass: "centralFileClass"
        }
    }

    static func datingName(_ dating: CrossReferenceNodeMetadata.Dating) -> String {
        switch dating {
        case .pageIndex: "pageIndex"
        case .pageMap: "pageMap"
        case .volume: "volume"
        }
    }

    /// Whether a node's document can be opened, the app's `makeEntry(for:)`: its graph's metadata, with a
    /// header and no cited page, since a page node's id names a page (#1799).
    static func opensEntry(_ metadata: CrossReferenceNodeMetadata?) -> Bool {
        guard let meta = metadata, meta.citedPage == nil, meta.header != nil else { return false }
        return true
    }

    /// The first line of a node's label on the canvas, the app's `labelText(for:)`: a cluster's count, a
    /// page's number (#1799), a document's number, or its title cut by the kit's
    /// `GraphNodeLabels.shortLabel(_:limit:)`; nil for an archival node, whose name is in its spoken label.
    static func labelText(for node: DisplayNode) -> String? {
        let text: String
        switch node.kind {
        case .clusterInbound(_, let count), .clusterOutbound(_, let count):
            text = "\(count) docs"
        case .dateCluster(let periodLabel, let count, _):
            text = "\(count) docs · \(periodLabel)"
        default:
            if let page = node.metadata?.citedPage {
                text = "p. \(page)"
            } else if let num = node.metadata?.documentNumber {
                text = "Doc. \(num)"
            } else if let header = node.metadata?.header {
                let trimmed = header.trimmingCharacters(in: .whitespaces)
                text = GraphNodeLabels.shortLabel(trimmed, limit: 20)
            } else {
                text = ""
            }
        }
        return text.isEmpty ? nil : text
    }
}
