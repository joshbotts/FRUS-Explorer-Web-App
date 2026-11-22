// Archival Analytics' Network mode (PLAN's S24h): the co-citation neighbourhood of one collection, as the app's
// `ArchivalNetworkView` draws it in custodian sectors. The graph is the kit's `ArchivalNetworkBuilder.graph` over the
// bundled authority and usage index, kept for its focus, measure, threshold and Central Files expansion; its layout is
// the kit's `layout(_:in:captionSize:)` for the canvas the browser draws in, with a caption measure of the server's
// own, the package's estimate of the canvas's 9-point semibold (0.55 em a character, 1.25 em a line, rounded up), since
// the server has no font to measure with; and its labels are placed by the kit's `GraphNodeLabels.place`, avoiding the
// layout's captions, at the same estimate of the canvas's 8- and 9-point labels. What the view decides between those
// calls is mirrored under its names: the threshold's range and default, the measure's fallback, the first focus, the
// picker's candidates, "Show only this group", the dock's summary and cards, and the export's table.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// The network around a focus, laid out for a canvas, with the dock's words (`ArchivalNetworkView`).
public struct ArchivalNetworkAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// The focus the network is drawn around, or nil when the authority holds no collection.
    public var focus: Focus?
    /// The measure in force, which falls back to shared volumes without the usage index (`measure`).
    public var measure: String
    /// Whether the measure and expansion menus are offered: both need the usage index.
    public var usageAvailable: Bool
    public var expansion: String
    public var threshold: Double
    public var thresholdText: String
    /// The partners drawn: every one, or the group's alone under "Show Only This Group" (`drawnGraph`).
    public var nodes: [Node]
    public var layout: Layout?
    /// Each drawn label's place, the focus's first, and the plate behind the focus's.
    public var labels: [Label]
    public var plate: Rect?
    /// The four sectors' zones, in the order the canvas lays them over each other.
    public var sectors: [Sector]
    /// The dock: a partner's card, a group's, or the placeholder's summary and legend.
    public var dock: Dock
    /// The toolbar's chip for the group selected, shown whenever one is, a partner in the dock or not
    /// (`selectedSector`'s chip).
    public var groupChip: GroupChip?
    /// The empty state, when no partner is drawn.
    public var empty: Empty?
    /// The neighbourhood's table, as its CSV lists it.
    public var table: CorpusAnalyticsAnswer.Table?

    public struct Focus: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        /// The focus as the network's sentences name it (`focusLabel`).
        public var label: String
        public var drawnLabel: String
    }

    public struct Node: Codable, Equatable, Sendable {
        public var id: String
        public var label: String
        /// The unit's own name: a class's key, which "Show Documents in This Class" asks its neighbours by.
        public var name: String
        public var drawnLabel: String?
        public var kind: String
        public var category: String
        public var categoryName: String
        public var sharedVolumes: Int
        public var sharedDocuments: Int?
        public var relativeStrength: Double
        /// The disc's radius, and the radius it is drawn at when shown (`drawnRadius(for:isSelected:)`).
        public var radius: Double
        public var selectedRadius: Double
        /// What a screen reader says of it (`accessibilityValue(for:in:)`).
        public var accessibilityValue: String
        /// Whether its record is in the authority, so that it can be explored, opened and shown its neighbours.
        public var isCollection: Bool
    }

    public struct Point: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double
    }

    public struct Rect: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
    }

    public struct Caption: Codable, Equatable, Sendable {
        public var text: String
        public var rect: Rect
    }

    public struct Layout: Codable, Equatable, Sendable {
        public var width: Double
        public var height: Double
        public var center: Point
        public var outerRadius: Double
        public var ringRadii: [Double]
        public var positions: [String: Point]
        public var classHull: Rect?
        public var hullCaption: Caption?
        public var captions: [String: Caption]
    }

    public struct Label: Codable, Equatable, Sendable {
        public var id: String
        public var text: String
        public var isFocus: Bool
        public var rect: Rect
    }

    public struct Sector: Codable, Equatable, Sendable {
        public var category: String
        public var name: String
        /// The wedge's start, in degrees clockwise from east, as the canvas draws it.
        public var start: Double
    }

    public struct Dock: Codable, Equatable, Sendable {
        public var title: String
        public var summary: String
        public var legend: [String]
        public var node: NodeCard?
        public var group: GroupCard?
    }

    public struct NodeCard: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var caption: String
        public var detail: String
        public var isCollection: Bool
    }

    public struct GroupChip: Codable, Equatable, Sendable {
        public var category: String
        public var name: String
        /// "Clear the … group", the chip's spoken name.
        public var clearLabel: String
    }

    public struct GroupCard: Codable, Equatable, Sendable {
        public var category: String
        public var name: String
        public var caption: String
        public var detail: String
        /// "Only this group is drawn, …", while it is.
        public var rescaled: String?
        /// The toggle's words, Show Only This Group or Show Every Group, when the group has partners.
        public var toggle: String?
        public var onlyThisGroup: Bool
        public var clearLabel: String
    }

    public struct Empty: Codable, Equatable, Sendable {
        public var title: String
        public var detail: String
    }
}

/// The focus picker's candidates (`focusCandidates`).
public struct ArchivalFocusCandidates: Codable, Equatable, Sendable, ResponseEncodable {
    public var title: String
    public var prompt: String
    public var candidates: [Candidate]

    public struct Candidate: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var caption: String
    }
}

/// What the network asks: the focus, the measure stored, the expansion, the threshold, the canvas, the partner shown,
/// the group and whether only it is drawn.
struct ArchivalNetworkAsk: Sendable, Equatable {
    var focus: AuthorityCollectionRecord
    var storedMeasure: ArchivalEdgeMeasure
    var expansion: ArchivalUmbrellaExpansion
    var threshold: Double
    var width: Double
    var height: Double
    var selectedNodeId: String?
    var selectedSector: ArchivalRepositoryCategory?
    var showsOnlySelectedSector: Bool
}

enum ArchivalNetworkRoutes {
    static let parameters: Set<String> = ["focus", "measure", "expansion", "threshold", "width", "height",
                                          "selected", "group", "only"]

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/analytics/archives/network") { request, _ -> ArchivalNetworkAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters)
            let collections = try await authority(resources)
            guard let ask = try ask(query, collections: collections, resources: resources) else {
                return ArchivalNetworkView.noFocus(usageAvailable: resources.bundledAnalytics.usage.value(in: resources.directory) != nil)
            }
            let graph = try await graph(ask, collections: collections, resources: resources)
            return ArchivalNetworkView(ask: ask, graph: graph, usage: resources.bundledAnalytics.usage.value(in: resources.directory)).answer()
        }
        router.get("/api/v1/analytics/archives/network/candidates") { request, _ -> ArchivalFocusCandidates in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["q"])
            let collections = try await authority(resources)
            let text = try query.single("q") ?? ""
            return ArchivalFocusCandidates(
                title: appWords("archival.network.picker.title", "Focus Collection"),
                prompt: appWords("archival.network.picker.prompt", "Set focus collection…"),
                candidates: ArchivalNetworkView.focusCandidates(collections, searchText: text).map {
                    .init(id: $0.id, name: $0.name, caption: ArchivalNetworkView.pickerCaption($0))
                })
        }
    }

    /// The authority's collections, the network's population, or a 404 where the bundle has none, as the app draws
    /// its unavailable state.
    static func authority(_ resources: ServerResources) async throws -> [AuthorityCollectionRecord] {
        // The usage index the network reads beside it is decoded here too, once, off the cooperative pool.
        let collections = try await Blocking.run {
            _ = resources.bundledAnalytics.usage.value(in: resources.directory)
            return resources.collectionAuthority?.collections ?? []
        }
        guard !collections.isEmpty else {
            throw APIProblem(.notFound, code: "NO_AUTHORITY",
                             detail: appWords("archival.network.unavailable", "The bundled collection authority is unavailable in this build, so the network cannot be drawn."))
        }
        return collections
    }

    /// The request's network, or nil when no focus is named and the authority gives none to seed it with.
    static func ask(_ query: FormQuery, collections: [AuthorityCollectionRecord], resources: ServerResources) throws -> ArchivalNetworkAsk? {
        let focus: AuthorityCollectionRecord
        if let id = try query.single("focus") {
            guard let record = collections.first(where: { $0.id == id }) else {
                throw APIProblem(.notFound, code: "COLLECTION_NOT_FOUND", detail: "The authority holds no collection \(id).")
            }
            focus = record
        } else if let seeded = ArchivalNetworkView.seedFocus(collections) {
            focus = seeded
        } else {
            return nil
        }
        let threshold: Double
        if let raw = try query.single("threshold") {
            guard let value = ArchivalNetworkView.thresholds.first(where: { String(format: "%.2f", $0) == raw || String($0) == raw }) else {
                throw APIProblem.invalidParameter("threshold", "must be one of \(ArchivalNetworkView.thresholds.map { String(format: "%.2f", $0) }.joined(separator: ", ")), not \(raw)")
            }
            threshold = value
        } else {
            threshold = ArchivalNetworkView.defaultThreshold
        }
        let sector = try query.choice("group", among: ArchivalRepositoryCategory.allCases)
        let only = try query.bool("only") ?? false
        if only, sector == nil { throw APIProblem.invalidParameter("only", "is taken only with a group") }
        return ArchivalNetworkAsk(
            focus: focus,
            storedMeasure: try query.choice("measure", among: ArchivalEdgeMeasure.allCases) ?? .sharedVolumes,
            expansion: try query.choice("expansion", among: ArchivalUmbrellaExpansion.allCases) ?? .collapsed,
            threshold: threshold,
            width: Double(try query.integer("width", in: 200...4_000, default: 720)),
            height: Double(try query.integer("height", in: 150...4_000, default: 420)),
            selectedNodeId: try query.single("selected"),
            selectedSector: sector,
            showsOnlySelectedSector: only)
    }

    /// The kit's graph for the view's `rebuild()` inputs, once for them and kept.
    static func graph(_ ask: ArchivalNetworkAsk, collections: [AuthorityCollectionRecord], resources: ServerResources) async throws -> ArchivalNetworkGraph {
        let bundle = resources.bundledAnalytics
        let usage = bundle.usage.value(in: resources.directory)
        let measure = ArchivalNetworkView.measure(ask.storedMeasure, usage: usage)
        let key = ArchivalNetworkKey(focusId: ask.focus.id, measure: measure.rawValue, expansion: ask.expansion.rawValue, threshold: ask.threshold)
        return try await bundle.networks.value(for: key) {
            try await Blocking.run {
                ArchivalNetworkBuilder.graph(
                    focus: ask.focus, in: collections, usage: usage,
                    measure: measure, minimumRelativeStrength: ask.threshold,
                    expansion: ask.expansion)
            }
        }
    }

    /// The neighbourhood's table and statement (`exportNeighbourhood(_:)`), refused for an empty network, where the
    /// app offers no export.
    static func export(query: FormQuery, resources: ServerResources, indexedVolumeCount: Int) async throws -> (ChartInspectorData, AnalyticsProvenance) {
        let collections = try await authority(resources)
        guard let ask = try ask(query, collections: collections, resources: resources) else {
            throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "No network is drawn.")
        }
        let graph = try await graph(ask, collections: collections, resources: resources)
        guard !graph.nodes.isEmpty else {
            throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "The network around \(ask.focus.name) holds nothing to export.")
        }
        let view = ArchivalNetworkView(ask: ask, graph: graph, usage: resources.bundledAnalytics.usage.value(in: resources.directory))
        return (view.neighbourhoodTable, view.neighbourhoodProvenance(indexedVolumeCount: indexedVolumeCount))
    }
}

/// What `ArchivalNetworkView` decides between the kit's graph and its canvas, under its names
/// (`ArchivalNetworkView.swift`); held to the app's source by the mirror test.
struct ArchivalNetworkView {
    /// The slider's stops, 5% to 60% in steps of 5% (`Slider(value:in: 0.05...0.60, step: 0.05)`), and where it opens.
    static let thresholds: [Double] = stride(from: 5, through: 60, by: 5).map { Double($0) / 100 }
    static let defaultThreshold = 0.25

    let ask: ArchivalNetworkAsk
    let graph: ArchivalNetworkGraph
    let usage: CollectionUsageIndex?

    /// The measure in force: shared documents needs the usage index.
    static func measure(_ stored: ArchivalEdgeMeasure, usage: CollectionUsageIndex?) -> ArchivalEdgeMeasure {
        (stored == .sharedDocuments && usage == nil) ? .sharedVolumes : stored
    }

    var measure: ArchivalEdgeMeasure { Self.measure(ask.storedMeasure, usage: usage) }
    var selectedSector: ArchivalRepositoryCategory? { ask.selectedSector }
    var showsOnlySelectedSector: Bool { ask.showsOnlySelectedSector }

    /// The collection the network opens on: the most widely cited one, the umbrella aside, ties to the lower id.
    static func seedFocus(_ collections: [AuthorityCollectionRecord]) -> AuthorityCollectionRecord? {
        collections
            .filter { $0.id != ArchivalCollectionsData.umbrellaCollectionId }
            .max { a, b in
                if a.volumeIds.count != b.volumeIds.count {
                    return a.volumeIds.count < b.volumeIds.count
                }
                return a.id > b.id
            }
    }

    /// The picker's candidates: collections cited by enough volumes to link, matching the search, most cited first.
    static func focusCandidates(_ collections: [AuthorityCollectionRecord], searchText: String) -> [AuthorityCollectionRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return collections
            .filter { $0.volumeIds.count >= ArchivalNetworkBuilder.minimumSharedVolumes }
            .filter {
                query.isEmpty || $0.name.lowercased().contains(query)
                    || ($0.repository?.lowercased().contains(query) ?? false)
            }
            .sorted { a, b in
                if a.volumeIds.count != b.volumeIds.count {
                    return a.volumeIds.count > b.volumeIds.count
                }
                return a.id < b.id
            }
            .prefix(200)
            .map { $0 }
    }

    /// A candidate's line under its name: its holder and how many volumes cite it.
    static func pickerCaption(_ record: AuthorityCollectionRecord) -> String {
        String(format: appWords("archival.network.picker.caption %@ %lld", "%1$@ · cited by %2$lld volumes"),
               record.repository ?? ArchivalRepositoryCategory.from(record).displayName,
               Int64(record.volumeIds.count))
    }

    /// The graph drawn: every partner, or the selected group's alone while "Show Only This Group" is on.
    func drawnGraph(_ graph: ArchivalNetworkGraph) -> ArchivalNetworkGraph {
        guard showsOnlySelectedSector, let selectedSector else { return graph }
        let kept = graph.nodes.filter { $0.category == selectedSector }
        guard !kept.isEmpty else { return graph }
        return ArchivalNetworkGraph(
            focus: graph.focus,
            focusCategory: graph.focusCategory,
            nodes: kept,
            nodesAboveThreshold: graph.nodesAboveThreshold,
            partnersTotal: graph.partnersTotal,
            strongestMeasureValue: kept.map(\.measureValue).max() ?? graph.strongestMeasureValue,
            expandedUmbrella: graph.expandedUmbrella,
            expansion: graph.expansion)
    }

    /// The canvas's wedges: State Department from 180°, lot files from 270°, libraries from 0°, others from 90°.
    static let sectorStarts: [(ArchivalRepositoryCategory, Double)] = [
        (.stateDepartment, 180), (.lotFile, 270), (.presidentialLibrary, 0),
        (.otherInstitution, 90),
    ]

    func accessibilityValue(for node: ArchivalNetworkNode) -> String {
        let kind = node.kind == .collection
            ? appWords("archival.network.kind.collection", "collection")
            : appWords("archival.network.kind.class", "central-file class")
        return String(format: appWords("archival.network.node.a11y %@ %@ %@", "%1$@, %2$@, %3$@"),
                      kind, node.category.displayName,
                      measure.detail(shared: node.sharedVolumeCount,
                                     documents: node.sharedDocumentCount))
    }

    static func dockSummarySentence(drawn: Int, aboveThreshold: Int, strongest: String) -> String {
        String(format: appWords("archival.network.dock.summary.v3 %@ %@ %@",
                                "%1$@ of the %2$@ above the current threshold drawn. Distance from the center shows link strength. The dashed rings mark three quarters, one half, and one quarter of the strongest link here (%3$@)."),
               drawn.formatted(.number.locale(SearchItem.locale)),
               CountCopy.phrase(aboveThreshold,
                                one: appWords("archival.network.dock.nodes.one", "%@ node"),
                                many: appWords("archival.network.dock.nodes.many", "%@ nodes"),
                                locale: SearchItem.locale),
               strongest)
    }

    func dockSummary(_ graph: ArchivalNetworkGraph) -> String {
        let strongest: String
        switch measure {
        case .sharedVolumes:
            strongest = graph.strongestMeasureValue
                .formatted(.percent.precision(.fractionLength(0)).locale(SearchItem.locale))
        case .sharedDocuments:
            strongest = Int(graph.strongestMeasureValue).formatted(.number.locale(SearchItem.locale))
        }
        var text = Self.dockSummarySentence(drawn: graph.nodes.count,
                                            aboveThreshold: graph.nodesAboveThreshold,
                                            strongest: strongest)
        text += " " + ArchivalCounts.networkPartners(graph.partnersTotal, locale: SearchItem.locale)
        if graph.isCapped {
            text += " " + ArchivalCounts.networkHeldBack(graph.withheldCount, locale: SearchItem.locale)
        }
        if graph.classNodeCount > 0 {
            text += " " + ArchivalCounts.networkClassSquares(graph.classNodeCount, locale: SearchItem.locale)
        }
        return text
    }

    func sectorPartners(_ graph: ArchivalNetworkGraph) -> [ArchivalNetworkNode] {
        guard let selectedSector else { return [] }
        return graph.nodes.filter { $0.category == selectedSector }
    }

    func groupCard(_ category: ArchivalRepositoryCategory, in graph: ArchivalNetworkGraph) -> ArchivalNetworkAnswer.GroupCard {
        let partners = sectorPartners(graph)
        let strongest = partners.max { $0.sharedVolumeCount < $1.sharedVolumeCount }
        let detail: String
        if partners.isEmpty {
            detail = String(format: appWords("archival.network.group.none %@",
                                             "None of this focus’s partners above the link threshold are held by %@. Lowering the threshold may bring some in."),
                            category.displayName.lowercased())
        } else {
            detail = String(format: appWords("archival.network.group.detail %lld %lld %@ %@ %lld",
                                             "%1$lld of this focus’s %2$lld partners are held by %3$@. Strongest: %4$@, %5$lld shared volumes."),
                            Int64(partners.count), Int64(graph.nodes.count),
                            category.displayName.lowercased(),
                            ArchivalNetworkBuilder.sentenceName(strongest?.label ?? ""),
                            Int64(strongest?.sharedVolumeCount ?? 0))
        }
        return ArchivalNetworkAnswer.GroupCard(
            category: category.rawValue, name: category.displayName,
            caption: appWords("archival.network.group.caption",
                              "Group — select any wedge to inspect it on its own, or a node for one collection."),
            detail: detail,
            rescaled: !partners.isEmpty && showsOnlySelectedSector
                ? appWords("archival.network.group.rescaled",
                           "Only this group is drawn, and the rings have re-scaled to its strongest link — distances are not comparable with the full graph.")
                : nil,
            toggle: partners.isEmpty ? nil
                : (showsOnlySelectedSector
                   ? appWords("archival.network.group.showAll", "Show Every Group")
                   : appWords("archival.network.group.only", "Show Only This Group")),
            onlyThisGroup: showsOnlySelectedSector,
            clearLabel: String(format: appWords("archival.network.group.clear %@", "Clear the %@ group"), category.displayName))
    }

    func selectedCard(_ node: ArchivalNetworkNode, in graph: ArchivalNetworkGraph) -> ArchivalNetworkAnswer.NodeCard {
        ArchivalNetworkAnswer.NodeCard(
            id: node.id, name: node.label,
            caption: node.kind == .collection
                ? node.category.displayName
                : appWords("archival.network.class.caption.v2",
                           "Central-file class — a subject heading inside one of the State Department’s central filing systems, not a collection"),
            detail: ArchivalNetworkBuilder.cardDetail(for: node, in: graph, usage: usage),
            isCollection: node.kind == .collection)
    }

    var emptyState: ArchivalNetworkAnswer.Empty {
        ArchivalNetworkAnswer.Empty(
            title: appWords("archival.network.none.title", "No Co-Cited Collections"),
            detail: String(format: appWords("archival.network.none.detail.v2 %@ %@",
                                            "No other collection shares two or more volumes with %1$@ above the current threshold. %2$@"),
                           ask.focus.name,
                           ask.threshold > 0.05
                               ? appWords("archival.network.none.lower", "Lower the threshold, or choose a more widely cited collection.")
                               : appWords("archival.network.none.floor", "The threshold is already at its lowest, so this collection simply shares no volumes with another — choose a more widely cited one.")))
    }

    /// The answer for a server whose authority gives no focus to seed: the view's "Choose a Collection".
    static func noFocus(usageAvailable: Bool) -> ArchivalNetworkAnswer {
        ArchivalNetworkAnswer(
            focus: nil, measure: ArchivalEdgeMeasure.sharedVolumes.rawValue, usageAvailable: usageAvailable,
            expansion: ArchivalUmbrellaExpansion.collapsed.rawValue, threshold: defaultThreshold,
            thresholdText: thresholdText(defaultThreshold), nodes: [], layout: nil, labels: [], plate: nil, sectors: [],
            dock: .init(title: "", summary: "", legend: [], node: nil, group: nil), groupChip: nil,
            empty: .init(title: appWords("archival.network.empty.title", "Choose a Collection"),
                         detail: appWords("archival.network.empty.detail", "Pick a collection to see which other bodies of records the same volumes drew on.")),
            table: nil)
    }

    static func thresholdText(_ threshold: Double) -> String {
        threshold.formatted(.percent.precision(.fractionLength(0)).locale(SearchItem.locale))
    }

    // The neighbourhood's export.

    var neighbourhoodTable: ChartInspectorData {
        ChartInspectorData(
            id: "archival.network",
            title: String(format: appWords("archival.export.title.network %@", "Co-cited with %@"), graph.focusLabel),
            columns: [
                appWords("archival.table.unit", "Archival unit"),
                appWords("archival.export.column.kind", "Kind"),
                appWords("archival.table.custodian", "Custodian"),
                appWords("archival.export.column.sharedVolumes", "Shared volumes"),
                appWords("archival.export.column.sharedDocuments", "Jointly supplied documents"),
                appWords("archival.export.column.strength", "Share of strongest link"),
            ],
            rowCells: graph.nodes.map(ArchivalNetworkBuilder.exportCells(for:)))
    }

    func neighbourhoodProvenance(indexedVolumeCount: Int) -> AnalyticsProvenance {
        ArchivalAnalyticsExport.network(
            focusName: graph.focusLabel, measure: measure, drawn: graph.nodes.count,
            aboveThreshold: graph.nodesAboveThreshold, partnersTotal: graph.partnersTotal,
            indexedVolumeCount: indexedVolumeCount)
    }

    // The canvas.

    /// A text's size in the canvas's system font, as the server estimates it: 0.55 em a character, 1.25 em a line.
    static func estimatedSize(_ text: String, fontSize: Double) -> CGSize {
        CGSize(width: CGFloat(Double(text.count) * fontSize * 0.55), height: CGFloat(fontSize * 1.25))
    }

    /// The caption measure the layout reserves room by (`measuredCaptionSize(_:)`, estimated, rounded up).
    static func estimatedCaptionSize(_ text: String) -> CGSize {
        let size = estimatedSize(text, fontSize: Double(ArchivalNetworkBuilder.captionPointSize))
        return CGSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
    }

    func answer() -> ArchivalNetworkAnswer {
        let drawn = drawnGraph(graph)
        let layout = ArchivalNetworkBuilder.layout(drawn, in: CGSize(width: CGFloat(ask.width), height: CGFloat(ask.height)),
                                                   captionSize: Self.estimatedCaptionSize)
        // `drawLabels`: the labels in their priority, the focus's at 9 points and the others' at 8, placed clear of the
        // captions, the hull's edges and one another.
        let selected = drawn.nodes.contains(where: { $0.id == ask.selectedNodeId }) ? ask.selectedNodeId : nil
        let texts = ArchivalNetworkBuilder.drawnLabels(in: drawn)
        var sizes: [String: CGSize] = [:]
        for id in ArchivalNetworkBuilder.labelPriority(drawn, selectedNodeId: selected) {
            sizes[id] = Self.estimatedSize(texts[id] ?? "", fontSize: id == drawn.focus.id ? 9 : 8)
        }
        let requests = ArchivalNetworkBuilder.labelRequests(drawn, layout: layout, selectedNodeId: selected, sizes: sizes)
        let placed = GraphNodeLabels.place(requests, avoiding: ArchivalNetworkBuilder.labelObstacles(layout))
        let plate = GraphNodeLabels.plate(for: requests, placed: placed)
        let labels = requests.compactMap { request -> ArchivalNetworkAnswer.Label? in
            guard let rect = placed[request.id] else { return nil }
            return .init(id: request.id, text: texts[request.id] ?? "", isFocus: request.id == drawn.focus.id, rect: Self.rect(rect))
        }
        let nodes = drawn.nodes.map { node in
            ArchivalNetworkAnswer.Node(
                id: node.id, label: node.label, name: node.name, drawnLabel: texts[node.id], kind: node.kind == .collection ? "collection" : "centralFileClass",
                category: node.category.rawValue, categoryName: node.category.displayName,
                sharedVolumes: node.sharedVolumeCount, sharedDocuments: node.sharedDocumentCount,
                relativeStrength: node.relativeStrength,
                radius: Double(ArchivalNetworkBuilder.drawnRadius(for: node, isSelected: false)),
                selectedRadius: Double(ArchivalNetworkBuilder.drawnRadius(for: node, isSelected: true)),
                accessibilityValue: accessibilityValue(for: node),
                isCollection: node.kind == .collection)
        }
        var captions: [String: ArchivalNetworkAnswer.Caption] = [:]
        for (category, caption) in layout.captions {
            captions[category.rawValue] = .init(text: caption.text, rect: Self.rect(caption.rect))
        }
        // The dock reads the whole graph, as `infoDock(graph)` does, whatever the canvas draws.
        let dockNode = graph.nodes.first(where: { $0.id == ask.selectedNodeId })
        let dock = ArchivalNetworkAnswer.Dock(
            title: appWords("archival.network.dock.title", "Select a node to see the link"),
            summary: dockSummary(graph),
            legend: [appWords("archival.network.legend.collection", "Collection"),
                     appWords("archival.network.legend.class", "Central-file class")],
            node: dockNode.map { selectedCard($0, in: graph) },
            group: dockNode == nil ? selectedSector.map { groupCard($0, in: graph) } : nil)
        return ArchivalNetworkAnswer(
            focus: .init(id: graph.focus.id, name: graph.focus.name, label: graph.focusLabel,
                         drawnLabel: texts[graph.focus.id] ?? graph.focusLabel),
            measure: measure.rawValue, usageAvailable: usage != nil, expansion: ask.expansion.rawValue,
            threshold: ask.threshold, thresholdText: Self.thresholdText(ask.threshold),
            nodes: graph.nodes.isEmpty ? [] : nodes,
            layout: graph.nodes.isEmpty ? nil : .init(
                width: ask.width, height: ask.height,
                center: .init(x: Double(layout.center.x), y: Double(layout.center.y)),
                outerRadius: Double(layout.outerRadius), ringRadii: layout.ringRadii.map { Double($0) },
                positions: layout.positions.mapValues { .init(x: Double($0.x), y: Double($0.y)) },
                classHull: drawn.expandedUmbrella == nil ? nil : layout.classHull.map(Self.rect),
                hullCaption: drawn.expandedUmbrella == nil ? nil
                    : layout.hullCaption.map { .init(text: $0.text, rect: Self.rect($0.rect)) },
                captions: captions),
            labels: graph.nodes.isEmpty ? [] : labels,
            plate: graph.nodes.isEmpty ? nil : plate.map(Self.rect),
            sectors: Self.sectorStarts.map { .init(category: $0.0.rawValue, name: $0.0.displayName, start: $0.1) },
            dock: dock,
            groupChip: selectedSector.map {
                .init(category: $0.rawValue, name: $0.displayName,
                      clearLabel: String(format: appWords("archival.network.group.clear %@", "Clear the %@ group"), $0.displayName))
            },
            empty: graph.nodes.isEmpty ? emptyState : nil,
            table: graph.nodes.isEmpty ? nil : ArchivalTables.table(neighbourhoodTable))
    }

    static func rect(_ rect: CGRect) -> ArchivalNetworkAnswer.Rect {
        .init(x: Double(rect.origin.x), y: Double(rect.origin.y), width: Double(rect.size.width), height: Double(rect.size.height))
    }
}
