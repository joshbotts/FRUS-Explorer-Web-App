// Archival Analytics' Flows mode (PLAN's S24h): where the editors sent the reader when they annotated one published
// document by pointing at another, or at material they did not print, as the app's `ArchivalFlowsView` shows it. The
// data is the kit's `ArchivalFlowsData`, corpus-wide or around a focus, on either layer, over the bundled provenance
// flows or external citations and the authority, built as the view's `rebuild()` builds it and kept for its focus,
// direction and layer. What the view decides between it and the screen is mirrored under its names: the intro, the
// titles and captions, the remainder, the hand-off card, the caveats, the picker and the export's table and statement.
// The ribbon diagram is drawn in the browser by the view's geometry (`blockFrames`, `focusFrame`, `ribbonCanvas`).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// The flows, corpus-wide or around a focus, on a layer, with their words (`ArchivalFlowsView`).
public struct ArchivalFlowsAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var layer: String
    public var direction: String
    public var focus: Focus?
    public var intro: String
    /// The focus chip's caption and value, and the clear button's words.
    public var focusCaption: String
    public var focusValue: String
    public var clearFocus: String
    /// The heaviest pairs, with no focus (`corpusWideCard`).
    public var corpusWide: CorpusWide?
    /// The diagram around a focus (`diagramCard`), with the folded remainder's rows.
    public var diagram: Diagram?
    /// No flow around the focus in this direction (`noFlowsState`).
    public var none: None?
    /// The hand-off a reader selected, unless it is the remainder (`flowCard`).
    public var card: Card?
    public var caveats: Caveats
    public var table: CorpusAnalyticsAnswer.Table?

    public struct Focus: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
    }

    public struct Endpoint: Codable, Equatable, Sendable {
        public var id: String
        public var label: String
        public var repository: String?
        public var category: String
        public var categoryName: String
        public var count: Int
        public var isRemainder: Bool
        public var accessibilityValue: String
        public var hint: String
    }

    public struct Pair: Codable, Equatable, Sendable {
        public var source: Endpoint
        public var target: Endpoint
        public var count: Int
        public var accessibilityLabel: String
    }

    public struct CorpusWide: Codable, Equatable, Sendable {
        public var title: String
        public var caption: String
        public var pairs: [Pair]
    }

    public struct Diagram: Codable, Equatable, Sendable {
        public var title: String
        public var countLabel: String
        /// The caption, whose `*…*` the browser sets in italics, as the app's Markdown body does.
        public var caption: String
        public var focusName: String
        public var focusCategory: String
        public var focusTotal: String
        public var endpoints: [Endpoint]
        public var remainderTitle: String
        public var remainder: [Endpoint]
    }

    public struct None: Codable, Equatable, Sendable {
        public var title: String
        public var detail: String
    }

    public struct Card: Codable, Equatable, Sendable {
        public var title: String
        public var detail: String
        /// The authority's record the endpoint names, which Show Archival Neighbors and Open Collection read.
        public var collectionId: String?
        public var neighbors: String
        public var openCollection: String
    }

    public struct Caveats: Codable, Equatable, Sendable {
        public var title: String
        public var lines: [String]
    }
}

/// What the flows ask: the layer, the focus, the direction and the hand-off selected.
struct ArchivalFlowsAsk: Sendable {
    var layer: ArchivalFlowLayer
    var focus: AuthorityCollectionRecord?
    var direction: ArchivalFlowDirection
    var selectedEndpointId: String?
}

enum ArchivalFlowsRoutes {
    static let parameters: Set<String> = ["layer", "focus", "direction", "selected"]

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/analytics/archives/flows") { request, _ -> ArchivalFlowsAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters)
            let (index, authority) = try await files(resources)
            let ask = try ask(query, authority: authority, resources: resources)
            let data = try await flows(ask, index: index, authority: authority, resources: resources)
            return ArchivalFlowsView(ask: ask, data: data, authority: authority).answer()
        }
        router.get("/api/v1/analytics/archives/flows/candidates") { request, _ -> ArchivalFocusCandidates in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["layer", "q"])
            let (index, authority) = try await files(resources)
            let layer = try layer(query, resources: resources)
            let text = try query.single("q") ?? ""
            let candidates = try await Blocking.run {
                ArchivalFlowsView.pickerCandidates(layer: layer, searchText: text, index: index,
                                                   external: resources.sourceExplorer(\.externalCitations), authority: authority)
            }
            return ArchivalFocusCandidates(
                title: appWords("archival.flows.picker.title", "Focus Collection"),
                prompt: appWords("archival.flows.picker.prompt", "Set focus collection…"),
                candidates: candidates.map { .init(id: $0.record.id, name: $0.record.name, caption: ArchivalFlowsView.pickerCaption($0)) })
        }
    }

    /// The flow index and the authority, or a 404 in the app's words where the bundle lacks either. Each is decoded
    /// once, on its first read, off the cooperative pool, with the external citations the unprinted layer reads.
    static func files(_ resources: ServerResources) async throws -> (ProvenanceFlowIndex, CollectionAuthorityIndex) {
        let (flows, authority) = try await Blocking.run {
            _ = resources.sourceExplorer(\.externalCitations)
            return (resources.bundledAnalytics.flows.value(in: resources.directory), resources.collectionAuthority)
        }
        guard let index = flows, let authority else {
            throw APIProblem(.notFound, code: "NO_FLOWS",
                             detail: appWords("archival.flows.unavailable", "The bundled reference-flow index is unavailable in this build, so hand-offs cannot be shown. This is not the same as the series having none."))
        }
        return (index, authority)
    }

    /// The layer asked for: the printed one unless the unprinted is asked, which needs the external-citation index, as
    /// the app offers the layer picker only with it.
    static func layer(_ query: FormQuery, resources: ServerResources) throws -> ArchivalFlowLayer {
        let layer = try query.choice("layer", among: ArchivalFlowLayer.allCases) ?? .betweenPrinted
        if layer == .toUnprinted, resources.sourceExplorer(\.externalCitations) == nil {
            throw APIProblem.invalidParameter("layer", "this server has no external-citation index")
        }
        return layer
    }

    static func ask(_ query: FormQuery, authority: CollectionAuthorityIndex, resources: ServerResources) throws -> ArchivalFlowsAsk {
        var focus: AuthorityCollectionRecord?
        if let id = try query.single("focus") {
            guard let record = authority.record(id: id) else {
                throw APIProblem(.notFound, code: "COLLECTION_NOT_FOUND", detail: "The authority holds no collection \(id).")
            }
            focus = record
        }
        return ArchivalFlowsAsk(
            layer: try layer(query, resources: resources),
            focus: focus,
            direction: try query.choice("direction", among: ArchivalFlowDirection.allCases) ?? .outgoing,
            selectedEndpointId: try query.single("selected"))
    }

    /// The view's `rebuild()`: the unprinted layer over the external citations, corpus-wide or focused, else the printed
    /// one over the flow index, kept for the focus, direction and layer.
    static func flows(_ ask: ArchivalFlowsAsk, index: ProvenanceFlowIndex, authority: CollectionAuthorityIndex,
                      resources: ServerResources) async throws -> ArchivalFlowsData {
        let key = ArchivalFlowsKey(focusId: ask.focus?.id, direction: ask.direction.rawValue, layer: ask.layer.rawValue)
        let external = resources.sourceExplorer(\.externalCitations)
        let entries = Dictionary(resources.manifest.map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first })
        return try await resources.bundledAnalytics.flowsData.value(for: key) {
            try await Blocking.run {
                if ask.layer == .toUnprinted, let external {
                    guard let focus = ask.focus else {
                        return ArchivalFlowsData.corpusWideExternal(index: external,
                                                                    authority: authority,
                                                                    entriesById: entries)
                    }
                    return ArchivalFlowsData.focusedExternal(on: focus, direction: ask.direction,
                                                             index: external,
                                                             authority: authority,
                                                             entriesById: entries)
                }
                guard let focus = ask.focus else {
                    return ArchivalFlowsData.corpusWide(index: index,
                                                        authority: authority)
                }
                return ArchivalFlowsData.focused(on: focus, direction: ask.direction,
                                                 index: index, authority: authority)
            }
        }
    }

    /// The flows' table and statement (`export(_:)`).
    static func export(query: FormQuery, resources: ServerResources, indexedVolumeCount: Int) async throws -> (ChartInspectorData, AnalyticsProvenance) {
        let (index, authority) = try await files(resources)
        let ask = try ask(query, authority: authority, resources: resources)
        let data = try await flows(ask, index: index, authority: authority, resources: resources)
        let view = ArchivalFlowsView(ask: ask, data: data, authority: authority)
        let (table, provenance) = view.export(indexedVolumeCount: indexedVolumeCount)
        guard !table.rows.isEmpty else {
            throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "\(table.title) holds nothing to export.")
        }
        return (table, provenance)
    }
}

/// What `ArchivalFlowsView` decides between the kit's flows and its diagram, under its names
/// (`ArchivalFlowsView.swift`); held to the app's source by the mirror test.
struct ArchivalFlowsView {
    let ask: ArchivalFlowsAsk
    let data: ArchivalFlowsData
    let authority: CollectionAuthorityIndex

    var direction: ArchivalFlowDirection { ask.direction }

    var intro: String {
        data.layer == .toUnprinted
            ? appWords("archival.flows.intro.unprinted",
                       "FRUS editors often include references to documents they did not print, and say where they are filed. Added up across the series, those pointers show where in the archives the editors sent readers for records they left out.")
            : appWords("archival.flows.intro",
                       "When a FRUS editor annotated one published document by pointing to another, the two documents sometimes came from different archives. Added up across the series, those pointers map the research paths the editors walked between bodies of records.")
    }

    var topTitle: String {
        data.layer == .toUnprinted
            ? appWords("archival.flows.top.title.unprinted", "The heaviest pointers to unprinted material")
            : appWords("archival.flows.top.title", "The heaviest hand-offs in the series")
    }

    var topCaption: String {
        data.layer == .toUnprinted
            ? appWords("archival.flows.top.caption.unprinted", "Choose a focus collection above to see everywhere its footnotes send you.")
            : appWords("archival.flows.top.caption", "Choose a focus collection above to see everywhere its documents point.")
    }

    var diagramTitle: String {
        if data.layer == .toUnprinted {
            return direction == .outgoing
                ? appWords("archival.flows.title.unprinted.outgoing", "Where the footnotes send you")
                : appWords("archival.flows.title.unprinted.incoming", "Which collections’ footnotes send you here")
        }
        return direction == .outgoing
            ? appWords("archival.flows.title.outgoing", "Where these documents point")
            : appWords("archival.flows.title.incoming", "What points at these documents")
    }

    var diagramCaption: String {
        if data.layer == .toUnprinted {
            return String(format: direction == .outgoing
                    ? appWords("archival.flows.caption.unprinted.outgoing %lld %lld",
                               "%1$lld footnotes on documents from this collection name unprinted material in other collections. A further %2$lld name unprinted material in this collection itself, and these are left out because the diagram only shows where FRUS editors sent you *away* to.")
                    : appWords("archival.flows.caption.unprinted.incoming %lld %lld",
                               "%1$lld footnotes on documents from other collections name unprinted material in this one. A further %2$lld come from documents already in this collection, and are left out."),
                Int64(data.totalReferences), Int64(data.sameUnitReferences))
        }
        return String(format: direction == .outgoing
                ? appWords("archival.flows.caption.outgoing %lld %lld",
                           "%1$lld references run from this collection to others. A further %2$lld stay inside the collection itself and are excluded.")
                : appWords("archival.flows.caption.incoming %lld %lld",
                           "%1$lld references run from other collections to this one. A further %2$lld stay inside the collection itself and are excluded."),
            Int64(data.totalReferences), Int64(data.sameUnitReferences))
    }

    var countLabel: String {
        direction == .outgoing
            ? CountCopy.phrase(data.allEndpoints.count,
                               one: appWords("archival.flows.showingAll.outgoing.one", "%@ destination"),
                               many: appWords("archival.flows.showingAll.outgoing.many", "all %@ destinations"),
                               locale: SearchItem.locale)
            : CountCopy.phrase(data.allEndpoints.count,
                               one: appWords("archival.flows.showingAll.incoming.one", "%@ origin"),
                               many: appWords("archival.flows.showingAll.incoming.many", "all %@ origins"),
                               locale: SearchItem.locale)
    }

    func endpoint(_ endpoint: ArchivalFlowEndpoint) -> ArchivalFlowsAnswer.Endpoint {
        ArchivalFlowsAnswer.Endpoint(
            id: endpoint.id, label: endpoint.label, repository: endpoint.repository,
            category: endpoint.category.rawValue, categoryName: endpoint.category.displayName,
            count: endpoint.count, isRemainder: endpoint.isRemainder,
            accessibilityValue: String(format: appWords("archival.flows.block.a11y %lld", "%lld references"), Int64(endpoint.count)),
            hint: endpoint.isRemainder
                ? appWords("archival.flows.block.hint.remainder", "Expands the collections folded into this block")
                : appWords("archival.flows.block.hint", "Selects this hand-off"))
    }

    func flowCard(_ endpoint: ArchivalFlowEndpoint) -> ArchivalFlowsAnswer.Card {
        ArchivalFlowsAnswer.Card(
            title: String(format: appWords("archival.flows.card.title %@ %@", "%1$@ → %2$@"),
                          direction == .outgoing ? (data.focus?.name ?? "") : endpoint.label,
                          direction == .outgoing ? endpoint.label : (data.focus?.name ?? "")),
            detail: String(format: direction == .outgoing
                           ? appWords("archival.flows.card.detail.outgoing %lld %lld",
                                      "%1$lld references, %2$lld%% of everything this collection hands off.")
                           : appWords("archival.flows.card.detail.incoming %lld %lld",
                                      "%1$lld references, %2$lld%% of everything handed off to this collection."),
                           Int64(endpoint.count),
                           Int64(data.totalReferences > 0
                                 ? (endpoint.count * 100 / data.totalReferences) : 0)),
            collectionId: authority.record(id: endpoint.id)?.id,
            neighbors: appWords("archival.flows.card.neighbors", "Show Archival Neighbors"),
            openCollection: appWords("archival.flows.card.openCollection", "Open Collection"))
    }

    var noFlowsState: ArchivalFlowsAnswer.None {
        ArchivalFlowsAnswer.None(
            title: appWords("archival.flows.none.title", "No Hand-Offs Recorded"),
            detail: String(format: appWords("archival.flows.none.detail %@ %lld %lld",
                                            "No cross-reference runs between %1$@ and another collection in this direction. The cross-reference style these come from postdates 1945. Only %2$lld of the %3$lld volumes in the series carry any of these references."),
                           data.focus?.name ?? "", Int64(data.volumesWithEdges),
                           Int64(data.volumesScanned)))
    }

    var caveats: ArchivalFlowsAnswer.Caveats {
        let title = appWords("archival.caveats.measured", "Measured here")
        if let facts = data.externalFacts {
            var lines = [String(format: appWords("archival.flows.caveats.unprinted.scope.v2 %lld %lld %lld %lld",
                                                 "%1$lld citations were found and %2$lld of them matched a known collection, across %3$lld of the %4$lld volumes in the series. What this layer reads, and why the earlier volumes are nearly absent, is in the ⓘ."),
                                Int64(facts.referencesFound), Int64(facts.referencesJoined),
                                Int64(data.volumesWithEdges), Int64(data.volumesScanned))]
            if let span = facts.eraSpan {
                lines.append(String(format: appWords("archival.flows.caveats.unprinted.era %lld %lld",
                                                     "The volumes contributing here cover %1$lld to %2$lld."),
                                    Int64(span.lowerBound), Int64(span.upperBound)))
            }
            lines.append(String(format: appWords("archival.flows.caveats.unprinted.ibid.v2 %@",
                                                 "%@ of these citations come from an “Ibid.”, which the app follows back — a reading rather than a quotation, explained in the ⓘ."),
                                facts.inheritedShare.formatted(.percent.precision(.fractionLength(1)).locale(SearchItem.locale))))
            return .init(title: title, lines: lines)
        }
        return .init(title: title, lines: [
            String(format: appWords("archival.flows.caveats.footnotes %@",
                                    "%@ of these references are footnotes. While annotating material from one collection, they pointed the reader to material from another. It is not necessarily a relationship between the archives themselves."),
                   data.footnoteShare.formatted(.percent.precision(.fractionLength(1)).locale(SearchItem.locale))),
            String(format: appWords("archival.flows.caveats.body.v3 %lld %lld %lld %lld",
                                    "Only %1$lld of the %2$lld volumes in the series contribute a single reference. The central-file classes left out of the diagrams carry %3$lld references over %4$lld pairs. These figures cover the whole series regardless of what you have downloaded, and carry no dates, so this mode cannot be narrowed to a period."),
                   Int64(data.volumesWithEdges), Int64(data.volumesScanned),
                   Int64(data.classBetweenReferences), Int64(data.classBetweenPairs)),
        ])
    }

    static func pickerCandidates(layer: ArchivalFlowLayer, searchText: String, index: ProvenanceFlowIndex,
                                 external: ExternalCitationIndex?, authority: CollectionAuthorityIndex)
        -> [(record: AuthorityCollectionRecord, references: Int)] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidates: [(record: AuthorityCollectionRecord, references: Int)]
        if layer == .toUnprinted, let external {
            candidates = ArchivalFlowsData.externalFocusCandidates(index: external,
                                                                   authority: authority)
        } else {
            candidates = ArchivalFlowsData.focusCandidates(index: index, authority: authority)
        }
        return candidates
            .filter {
                query.isEmpty || $0.record.name.lowercased().contains(query)
                    || ($0.record.repository?.lowercased().contains(query) ?? false)
            }
            .prefix(200)
            .map { $0 }
    }

    static func pickerCaption(_ candidate: (record: AuthorityCollectionRecord, references: Int)) -> String {
        String(format: appWords("archival.flows.picker.caption %@ %lld", "%1$@ · %2$lld references"),
               candidate.record.repository
                   ?? ArchivalRepositoryCategory.from(candidate.record).displayName,
               Int64(candidate.references))
    }

    func export(indexedVolumeCount: Int) -> (ChartInspectorData, AnalyticsProvenance) {
        let title: String
        let axis: String
        let columns: [String]
        let rows: [[String]]
        if let focus = data.focus {
            title = String(format: appWords("archival.export.title.flows %@ %@", "%1$@ — %2$@"),
                           focus.name, direction.title)
            if data.layer == .toUnprinted {
                axis = direction == .outgoing
                    ? appWords("archival.export.axis.flows.unprinted.outgoing", "Unprinted material this collection’s footnotes name")
                    : appWords("archival.export.axis.flows.unprinted.incoming", "Footnotes naming unprinted material in this collection")
            } else {
                axis = direction == .outgoing
                    ? appWords("archival.export.axis.flows.outgoing", "References out of this collection")
                    : appWords("archival.export.axis.flows.incoming", "References into this collection")
            }
            columns = [
                appWords("archival.table.unit", "Archival unit"),
                appWords("archival.table.custodian", "Custodian"),
                appWords("archival.export.unit.references", "References"),
            ]
            rows = data.allEndpoints.map {
                [$0.label, $0.category.displayName, "\($0.count)"]
            }
        } else {
            title = data.layer == .toUnprinted
                ? appWords("archival.flows.top.title.unprinted", "The heaviest pointers to unprinted material")
                : appWords("archival.flows.top.title", "The heaviest hand-offs in the series")
            axis = appWords("archival.export.axis.flows.top", "Ranked by references between the pair")
            columns = [
                appWords("archival.export.column.source", "From"),
                appWords("archival.export.column.target", "To"),
                appWords("archival.export.unit.references", "References"),
            ]
            rows = data.topPairs.map { [$0.source.label, $0.target.label, "\($0.source.count)"] }
        }
        return (ChartInspectorData(id: "archival.flows", title: title, columns: columns, rowCells: rows),
                ArchivalAnalyticsExport.flows(title: title, axisLabel: axis, data: data,
                                              indexedVolumeCount: indexedVolumeCount))
    }

    func answer() -> ArchivalFlowsAnswer {
        let (table, _) = export(indexedVolumeCount: 0)
        var answer = ArchivalFlowsAnswer(
            layer: data.layer.rawValue, direction: direction.rawValue,
            focus: data.focus.map { .init(id: $0.id, name: $0.name) },
            intro: intro,
            focusCaption: appWords("archival.flows.focus", "Focus"),
            focusValue: data.focus?.name ?? appWords("archival.flows.focus.all", "The whole series"),
            clearFocus: appWords("archival.flows.clearFocus", "Clear focus"),
            corpusWide: nil, diagram: nil, none: nil, card: nil,
            caveats: caveats,
            table: table.rows.isEmpty ? nil : ArchivalTables.table(table))
        if data.focus == nil {
            answer.corpusWide = .init(
                title: topTitle, caption: topCaption,
                pairs: data.topPairs.map { pair in
                    .init(source: endpoint(pair.source), target: endpoint(pair.target), count: pair.source.count,
                          accessibilityLabel: String(format: appWords("archival.flows.top.a11y %@ %@ %lld", "%1$@ to %2$@, %3$lld references"),
                                                     pair.source.label, pair.target.label, Int64(pair.source.count)))
                })
        } else if data.endpoints.isEmpty {
            answer.none = noFlowsState
        } else {
            answer.diagram = .init(
                title: diagramTitle, countLabel: countLabel, caption: diagramCaption,
                focusName: data.focus?.name ?? "",
                focusCategory: (data.focusCategory ?? .otherInstitution).rawValue,
                focusTotal: String(format: appWords("archival.flows.focusBlock %lld", "%lld references"), Int64(data.totalReferences)),
                endpoints: data.endpoints.map(endpoint),
                remainderTitle: direction == .outgoing
                    ? appWords("archival.flows.remainder.title.outgoing", "The rest of the destinations")
                    : appWords("archival.flows.remainder.title.incoming", "The rest of the origins"),
                remainder: Array(data.allEndpoints.dropFirst(ArchivalFlowsData.endpointCap)).map(endpoint))
        }
        if let selected = data.endpoints.first(where: { $0.id == ask.selectedEndpointId }),
           !selected.isRemainder {
            answer.card = flowCard(selected)
        }
        return answer
    }
}
