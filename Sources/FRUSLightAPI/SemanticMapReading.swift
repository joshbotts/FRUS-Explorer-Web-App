// The semantic map's reading (PLAN's S28c): what a point's colour means, which points a scope ghosts, the regions'
// names, a point's card and a region's, and the map a link names, each by the kit's rules (FRUSCoreKit's `Semantic/`,
// S28a) over the bundled map and the bundled vectors' index S28b and S26c read, the catalogue, the bundled
// source-provenance aggregate and the served index's volumes.
//   GET /api/v1/semantic/map/reading          the lenses this server can draw, each with its name, legend, caption and
//                                             palette, and the administration menu's presidencies with their mapped volumes
//   GET /api/v1/semantic/map/lens?lens=       a lens's palette slot for every point, one byte a point in the vectors' row
//                                             order (`SemanticMapColouring.indices`)
//   GET /api/v1/semantic/map/scope?…          what a scope holds (`scopeMask`): its documents, volumes and regions, the
//                                             kit's sentence, and the regions the keyboard's list names, largest first
//   GET /api/v1/semantic/map/scope/flags?…    the scope's mask, one byte a point, 1 for a point outside it, which the
//                                             renderer ghosts as the app's does
//   GET /api/v1/semantic/map/labels?…         the regions' names for a view, twenty-two at most (`SemanticMapLabelLayout`)
//   GET /api/v1/semantic/map/pick?…           the point nearest a point of the map's own grid, within a tolerance in its
//                                             units, under the scope (`SemanticMapPicking.hit(nearGrid:…)`): a point's card
//   GET /api/v1/semantic/map/request?…        the map a link names (`SemanticMapRequest`): its lens, and the document it
//                                             reveals or the region it focuses (`SemanticMapReveal`)
//   GET /api/v1/semantic/map/regions/{id}?…   a region's card (`SemanticMapRegionRows`) with its documents in the scope,
//                                             the set the app's card saves (`SemanticMapCapture.region`), a page at a time
// A scope is named as Archival Analytics' scope bar and administration menu name one, over the same series: the 553
// volumes the catalogue lists are the 553 the bundled vectors place, which `SemanticMapReadingParityTests` holds.
// On This Server is the app's Downloaded lens, the volumes the served index holds documents of, as the app's are the
// volumes its device has indexed; a point's card opens a document the server serves and says so of one it does not.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import NIOCore
import SemanticVectorsKit

// MARK: - The answers

/// `GET /api/v1/semantic/map/reading`: what the map can be read through here.
public struct SemanticMapReadingContext: Codable, Equatable, Sendable, ResponseEncodable {
    /// A lens the app's picker offers (`availableLenses`), with what its colours mean.
    public struct Lens: Codable, Equatable, Sendable {
        /// The kit's raw value: `cluster`, `era`, `availability` or `provenance`.
        public var id: String
        /// Its name in the picker: the kit's, On This Server where the app says Downloaded.
        public var name: String
        /// The key's entries, in palette order (`legend`).
        public var legend: [String]
        /// What the lens measures, under the key, where the kit says (`caption`).
        public var caption: String?
        /// Whether the key names every colour the lens draws (`namesEveryColour`): not the regions', which cycle.
        public var namesEveryColour: Bool
        /// The sixteen slots' colours, red, green, blue and alpha, each 0 to 1, as the renderer draws them (`palette(for:)`).
        public var palette: [[Float]]
    }

    /// A presidency of the administration menu, with the volumes of it the map places (`administrationMenu`).
    public struct Administration: Codable, Equatable, Sendable {
        public var id: String
        public var president: String
        /// The presidency's volumes the map places: none disables the item, in the app's words.
        public var mappedVolumes: Int
    }

    /// The layout's identity (`MapIndex.layoutIdentity`), against which alone a region's id means anything.
    public var layoutIdentity: String
    public var lenses: [Lens]
    public var administrations: [Administration]
    /// The volumes the map places: what a scope's sentence counts its volumes of.
    public var mappedVolumes: Int
}

/// `GET /api/v1/semantic/map/scope`: what a scope holds, or the whole series.
public struct SemanticMapScopeAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// A region the keyboard's list names, as the app's accessibility list names it (`mapAccessibilityList`).
    public struct Region: Codable, Equatable, Sendable {
        public var id: Int
        /// The map's form of its name: its first three terms (`terms.prefix(3)`).
        public var name: String
        /// Its documents in the scope, or in the series when unscoped (`labelledClusters`).
        public var documentCount: Int
        /// The app's spoken name, "[name], region", and its value: the count and the era most of it falls in.
        public var accessibilityLabel: String
        public var accessibilityValue: String
    }

    /// The scope's name, or nil for the whole series.
    public var label: String?
    /// The scope's volumes, or nil for the whole series.
    public var volumeIds: [String]?
    /// Documents in the scope (`ScopeMask.documentCount`), or the map's when unscoped.
    public var documentCount: Int
    /// The scope's volumes the map places (`ScopeMask.volumeCount`), or all of them when unscoped.
    public var volumeCount: Int
    public var mappedVolumes: Int
    /// The kit's sentence (`scopeSummary`), under a scope alone.
    public var summary: String?
    /// Documents in the scope by region id, the regions with any (`ScopeMask.regionCounts`), under a scope alone.
    public var regionCounts: [String: Int]?
    /// The regions the names may name and the keyboard's list lists, largest first, ties by id.
    public var regions: [Region]
}

/// `GET /api/v1/semantic/map/labels`: the names for one view (`SemanticMapLabel`).
public struct SemanticMapLabelsAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public struct Label: Codable, Equatable, Sendable {
        public var id: Int
        public var text: String
        /// Where its middle is drawn, in the view's CSS pixels from its top left.
        public var x: Double
        public var y: Double
        public var documentCount: Int
    }

    public var labels: [Label]
}

/// A point of the map, as a point's card shows it (`selectionCard`), from the kit's `SemanticMapPicking.Selection`.
public struct SemanticMapPoint: Codable, Equatable, Sendable {
    /// The row of the map and of the vectors.
    public var row: Int
    public var volumeId: String
    public var documentId: String
    /// Where it sits on the grid, for the ring drawn on it.
    public var x: Int
    public var y: Int
    /// Its region's id, and its name (`regionName(ofRow:map:clusters:)`), or neither between regions.
    public var regionId: Int?
    public var regionName: String?
    /// The card's headline, the volume's title and the document's id, ids where the catalogue has no title
    /// (`selectionHeadline`), and its caption, the two ids.
    public var headline: String
    public var ids: String
    /// The document's own heading, from the served index, where the server serves it.
    public var title: String?
    /// Whether the server serves its volume, so that it opens (`isDownloaded`).
    public var served: Bool
}

/// `GET /api/v1/semantic/map/pick`: the point a pick found, or none.
public struct SemanticMapPickAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var point: SemanticMapPoint?
}

/// `GET /api/v1/semantic/map/request`: where the map a link names opens.
public struct SemanticMapRequestAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// A camera on the grid (`SemanticMapCamera`).
    public struct Camera: Codable, Equatable, Sendable {
        public var x: Float
        public var y: Float
        public var halfExtent: Float
    }

    /// A document the link reveals: its point and the camera brought to it, or that it has no place on the map.
    public struct Reveal: Codable, Equatable, Sendable {
        public var key: String
        public var revealed: Bool
        public var point: SemanticMapPoint?
        public var camera: Camera?
        /// The document's volume's title, or its id, for the sentence that it has no place on the map (`volumeTitle(forKey:)`).
        public var volumeTitle: String
    }

    /// A region the link focuses: the camera brought to its centre, or nothing when the id or the layout does not land.
    public struct Focus: Codable, Equatable, Sendable {
        public var region: Int
        public var focused: Bool
        public var camera: Camera?
    }

    /// The lens the map opens on: the link's, where this server draws it, or Regions.
    public var lens: String
    public var scopeLabel: String?
    public var reveal: Reveal?
    public var focus: Focus?
}

/// `GET /api/v1/semantic/map/regions/{id}`: a region's card, with a page of its documents in the scope.
public struct SemanticMapRegionCard: Codable, Equatable, Sendable, ResponseEncodable {
    /// An era's row (`SemanticMapRegionRows.Row`).
    public struct EraRow: Codable, Equatable, Sendable {
        public var label: String
        public var count: String
    }

    /// One of the region's documents.
    public struct Document: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        public var headline: String
        public var title: String?
        public var served: Bool
    }

    public var id: Int
    /// The map's form of the region's name, its first three terms, as the card shows it.
    public var name: String
    /// The card's headline (`countSummary`): the series' count, and the scope's beside it.
    public var countSummary: String
    public var eraRows: [EraRow]
    /// Every document of the region in the scope, and those of them the card lists: the capture's, at most 7,500.
    public var total: Int
    public var kept: Int
    public var offset: Int
    public var documents: [Document]
}

// MARK: - The reading

/// The map's reading, over the files `SemanticMapFiles` reads once, with what each lens, scope and region computes kept.
actor SemanticMapReading {
    /// The map, the vectors' index and the plane's positions, read once.
    struct Plane: Sendable {
        let map: SemanticMapFiles.Map
        let index: SemanticVectorIndex
        /// Each row's place on the grid, as the hit test scans them (`positions(of:)`).
        let positions: [SIMD2<Int16>]
        /// The volumes the map places.
        let mapped: Set<String>
        var clusters: [SemanticMapArtifacts.Cluster] { map.index.clusters }
    }

    /// A binary answer and its entity tag.
    struct Bytes: Sendable {
        let body: ByteBuffer
        let tag: String
    }

    /// A scope's mask, with its flags as the answer sends them.
    struct Mask: Sendable {
        let scope: ArchivalScope
        let mask: SemanticMapColouring.ScopeMask?
        let flags: Bytes?
    }

    let files: SemanticMapFiles
    let provider: ServedIndexProvider
    let resources: ServerResources
    private var reading: Task<Result<Plane, APIProblem>, Never>?
    private var slots: [SemanticMapLens: Bytes] = [:]
    private var availability: (served: Set<String>, answer: Bytes)?
    private var masks: [(key: String, mask: Mask)] = []
    private var captures: [(key: String, capture: SemanticMapPicking.LassoResult)] = []
    private var provenance: [String: SourceProvenanceCategory]?

    init(files: SemanticMapFiles, provider: ServedIndexProvider, resources: ServerResources) {
        self.files = files
        self.provider = provider
        self.resources = resources
    }

    /// The plane, read on the first call and kept, refusal and all, as the map is.
    func plane() async throws -> Plane {
        if let reading { return try await reading.value.get() }
        let (files, vectors) = (files, files.vectors)
        let task = Task<Result<Plane, APIProblem>, Never> {
            let map: SemanticMapFiles.Map
            switch await files.map() {
            case .success(let read): map = read
            case .failure(let refused): return .failure(refused)
            }
            guard case .success(let tiers) = await vectors.tiers() else {
                return .failure(SemanticMapFiles.malformed("the bundled vectors are refused"))
            }
            let index = tiers.index
            do {
                return .success(try await Blocking.run {
                    Plane(map: map, index: index, positions: SemanticMapPicking.positions(of: map.vectors),
                          mapped: Set(index.volumes.map(\.volumeID)))
                })
            } catch {
                return .failure(SemanticMapFiles.malformed("\(error)"))
            }
        }
        reading = task
        return try await task.value.get()
    }

    /// The volumes the served index holds documents of: none while no index is served.
    func served() async -> Set<String> {
        (try? await provider.servedIfReady())?.indexedVolumeIds ?? []
    }

    // MARK: The lenses

    /// The bundled aggregate's per-volume table, or nil where the build's aggregate has none, which withholds the lens.
    nonisolated var volumeProvenance: [VolumeProvenance]? {
        resources.bundledAnalytics.sourceProvenance.value(in: resources.directory)?.byVolume
    }

    /// The lenses the app's picker offers this build (`availableLenses`).
    nonisolated var availableLenses: [SemanticMapLens] {
        let byVolume = volumeProvenance
        return SemanticMapLens.allCases.filter { $0.isAvailable(volumeProvenance: byVolume) }
    }

    func context() async throws -> SemanticMapReadingContext {
        let plane = try await plane()
        let resources = resources
        let lenses = availableLenses
        return try await Blocking.run {
            let administrations = (resources.administrationProfiles?.administrations ?? []).map { profile in
                SemanticMapReadingContext.Administration(
                    id: profile.id, president: profile.president,
                    mappedVolumes: Set(profile.volumes.map(\.volumeId)).intersection(plane.mapped).count)
            }
            return SemanticMapReadingContext(
                layoutIdentity: plane.map.index.layoutIdentity,
                lenses: lenses.map(Self.lens),
                administrations: administrations,
                mappedVolumes: plane.mapped.count)
        }
    }

    /// A lens as the picker, the key and the renderer read it: the kit's, On This Server in a server's words.
    static func lens(_ lens: SemanticMapLens) -> SemanticMapReadingContext.Lens {
        let isServer = lens == .availability
        return SemanticMapReadingContext.Lens(
            id: lens.rawValue,
            name: isServer ? onThisServer : lens.displayName,
            legend: isServer ? onThisServerLegend : lens.legend,
            caption: lens.caption,
            namesEveryColour: lens.namesEveryColour,
            palette: SemanticMapColouring.palette(for: lens).map { [$0.x, $0.y, $0.z, $0.w] })
    }

    /// The app's Downloaded lens, `semanticMap.lens.availability`, a server's: the volumes it serves.
    static let onThisServer = "On This Server"
    /// The lens's key, `semanticMap.legend.notDownloaded` and `semanticMap.legend.downloaded`, a server's.
    static let onThisServerLegend = ["Not on this server", "On this server"]

    /// Each point's slot under `lens` (`SemanticMapColouring.indices`): each volume's era from the catalogue, whether the
    /// server serves it, and its plurality provenance from the bundled aggregate.
    func slots(_ lens: SemanticMapLens) async throws -> Bytes {
        guard availableLenses.contains(lens) else {
            throw APIProblem(.notFound, code: "LENS_UNAVAILABLE",
                             detail: "This server's source-provenance aggregate has no table by volume, so the \(lens.displayName) lens cannot be drawn.")
        }
        let plane = try await plane()
        if lens == .availability {
            let served = await served()
            if let availability, availability.served == served { return availability.answer }
            let answer = try await Self.computed(lens, plane: plane, resources: resources, served: served, provenance: [:])
            availability = (served, answer)
            return answer
        }
        if let kept = slots[lens] { return kept }
        let provenance = lens == .provenance ? try await dominantProvenance() : [:]
        let answer = try await Self.computed(lens, plane: plane, resources: resources, served: [], provenance: provenance)
        slots[lens] = answer
        return answer
    }

    /// The kit's colouring over the server's values.
    static func computed(_ lens: SemanticMapLens, plane: Plane, resources: ServerResources, served: Set<String>,
                         provenance: [String: SourceProvenanceCategory]) async throws -> Bytes {
        try await Blocking.run {
            let colours = SemanticMapColouring.indices(
                for: lens, map: plane.map.vectors, index: plane.index,
                eraForVolume: { SemanticMapVolumes.era(of: resources.volume($0)) },
                isDownloaded: { served.contains($0) },
                provenanceForVolume: { provenance[$0] })
            let body = ByteBuffer(bytes: colours)
            return Bytes(body: body, tag: SemanticMapFiles.entityTag(body))
        }
    }

    /// The dominant category of each volume the bundled aggregate covers above the kit's floor, computed once.
    func dominantProvenance() async throws -> [String: SourceProvenanceCategory] {
        if let provenance { return provenance }
        let table = SemanticMapVolumes.dominantProvenance(byVolume: volumeProvenance ?? [])
        provenance = table
        return table
    }

    // MARK: The scope

    /// The scope a request names, its mask kept for the last few scopes asked.
    func mask(_ query: FormQuery) async throws -> Mask {
        let scope = try ArchivalAnalyticsRoutes.scope(query, resources: resources)
        let plane = try await plane()
        let key = scope.volumeIds.map { $0.sorted().joined(separator: ",") } ?? ""
        if let kept = masks.first(where: { $0.key == key }) {
            // The label is the request's: the same volumes may be a subseries in one address and a reader's scope in another.
            return Mask(scope: scope, mask: kept.mask.mask, flags: kept.mask.flags)
        }
        let mask = try await Blocking.run { () -> Mask in
            guard let ids = scope.volumeIds else { return Mask(scope: scope, mask: nil, flags: nil) }
            let mask = SemanticMapColouring.scopeMask(volumeIDs: Set(ids), map: plane.map.vectors, index: plane.index)
            let flags = mask.map { ByteBuffer(bytes: $0.flags) }
            return Mask(scope: scope, mask: mask, flags: flags.map { Bytes(body: $0, tag: SemanticMapFiles.entityTag($0)) })
        }
        masks.insert((key, mask), at: 0)
        if masks.count > 6 { masks.removeLast() }
        return mask
    }

    func scope(_ query: FormQuery) async throws -> SemanticMapScopeAnswer {
        let mask = try await mask(query)
        let plane = try await plane()
        return Self.scopeAnswer(mask, plane: plane)
    }

    static func scopeAnswer(_ mask: Mask, plane: Plane) -> SemanticMapScopeAnswer {
        let labelled = SemanticMapLabelLayout.labelledClusters(plane.clusters, scope: mask.mask)
        // The keyboard's list in the order the app's accessibility list reads them: largest first, ties by id.
        let regions = labelled.sorted {
            $0.documentCount == $1.documentCount ? $0.id < $1.id : $0.documentCount > $1.documentCount
        }.map { cluster in
            SemanticMapScopeAnswer.Region(
                id: cluster.id, name: regionName(cluster), documentCount: cluster.documentCount,
                accessibilityLabel: accessibilityLabel(cluster), accessibilityValue: accessibilityValue(cluster))
        }
        guard let found = mask.mask else {
            return SemanticMapScopeAnswer(
                label: nil, volumeIds: nil, documentCount: plane.map.vectors.documentCount, volumeCount: plane.mapped.count,
                mappedVolumes: plane.mapped.count, summary: nil, regionCounts: nil, regions: regions)
        }
        return SemanticMapScopeAnswer(
            label: mask.scope.label, volumeIds: mask.scope.volumeIds, documentCount: found.documentCount,
            volumeCount: found.volumeCount, mappedVolumes: plane.mapped.count,
            summary: SemanticMapColouring.scopeSummary(documents: found.documentCount, volumes: found.volumeCount,
                                                       ofVolumes: plane.mapped.count),
            regionCounts: Dictionary(uniqueKeysWithValues: found.regionCounts.map { (String($0.key), $0.value) }),
            regions: regions)
    }

    /// The map's form of a region's name, as its card, its point's card and its row read it: its first three terms.
    static func regionName(_ cluster: SemanticMapArtifacts.Cluster) -> String {
        cluster.terms.prefix(3).joined(separator: " ")
    }

    /// The app's `regionAccessibilityLabel`: "[name], region".
    static func accessibilityLabel(_ cluster: SemanticMapArtifacts.Cluster) -> String {
        String(format: appWords("semanticMap.a11y.region.label %@", "%1$@, region"), regionName(cluster))
    }

    /// The app's `regionAccessibilityValue`: the count, and the era most of the region falls in. The app takes the
    /// first of equal eras in a dictionary's order; here the earlier era, so that the words are the same at each start.
    static func accessibilityValue(_ cluster: SemanticMapArtifacts.Cluster) -> String {
        let count = CountCopy.documents(cluster.documentCount)
        guard let top = cluster.eraCounts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }),
              let era = CoverageEra(rawValue: Int(top.key) ?? -1) else { return count }
        return count + ", " + String(format: appWords("semanticMap.a11y.region.era %@", "mostly %1$@"), era.label)
    }

    // MARK: The names, the picks and the cards

    func labels(_ query: FormQuery) async throws -> SemanticMapLabelsAnswer {
        let camera = SemanticMapCamera(centre: SIMD2<Float>(Float(try Self.number(query, "x")), Float(try Self.number(query, "y"))),
                                       halfExtent: Float(try Self.number(query, "halfExtent", positive: true)))
        let size = CGSize(width: try Self.size(query, "width"), height: try Self.size(query, "height"))
        let mask = try await mask(query)
        let plane = try await plane()
        let labels = SemanticMapLabelLayout.labels(
            for: SemanticMapLabelLayout.labelledClusters(plane.clusters, scope: mask.mask), camera: camera, size: size)
        return SemanticMapLabelsAnswer(labels: labels.map {
            .init(id: $0.id, text: $0.text, x: Double($0.position.x), y: Double($0.position.y), documentCount: $0.documentCount)
        })
    }

    func pick(_ query: FormQuery) async throws -> SemanticMapPickAnswer {
        let target = SIMD2<Float>(Float(try Self.number(query, "x")), Float(try Self.number(query, "y")))
        let tolerance = Float(try Self.number(query, "tolerance", positive: true))
        let mask = try await mask(query)
        let plane = try await plane()
        let hit = try await Blocking.run {
            SemanticMapPicking.hit(nearGrid: target, tolerance: tolerance, positions: plane.positions, scopeMask: mask.mask?.flags)
        }
        guard let hit else { return SemanticMapPickAnswer(point: nil) }
        // A row the map places but the vectors' index cannot name is a keying failure, not an empty pick, as the app has it.
        guard let document = plane.index.document(at: hit.row) else {
            throw SemanticMapFiles.malformed("row \(hit.row) has a placement but no document id")
        }
        let selection = SemanticMapPicking.Selection(
            row: hit.row, volumeID: document.volumeID, documentID: document.documentID, position: hit.position,
            regionName: SemanticMapPicking.regionName(ofRow: hit.row, map: plane.map.vectors, clusters: plane.clusters),
            isDownloaded: await served().contains(document.volumeID))
        return SemanticMapPickAnswer(point: try await point(selection, plane: plane))
    }

    /// A point's card from the kit's selection, the document's heading from the served index where it is served.
    func point(_ selection: SemanticMapPicking.Selection, plane: Plane) async throws -> SemanticMapPoint {
        let cluster = plane.map.vectors.placement(at: selection.row)?.cluster ?? SemanticMapArtifacts.unclustered
        let titles = selection.isDownloaded
            ? try await headings([DocumentKey(volumeId: selection.volumeID, documentId: selection.documentID)]) : [:]
        return SemanticMapPoint(
            row: selection.row, volumeId: selection.volumeID, documentId: selection.documentID,
            x: Int(selection.position.x), y: Int(selection.position.y),
            regionId: cluster == SemanticMapArtifacts.unclustered ? nil : Int(cluster), regionName: selection.regionName,
            headline: headline(volumeId: selection.volumeID, documentId: selection.documentID),
            ids: "\(selection.volumeID) · \(selection.documentID)",
            title: titles[DocumentKey(volumeId: selection.volumeID, documentId: selection.documentID)],
            served: selection.isDownloaded)
    }

    /// The app's `selectionHeadline`: the volume's title from the catalogue and the document's id, the ids where it has none.
    nonisolated func headline(volumeId: String, documentId: String) -> String {
        guard let title = resources.volume(volumeId)?.title, !title.isEmpty else { return "\(volumeId) · \(documentId)" }
        return "\(title) · \(documentId)"
    }

    /// The headings the served index holds of `keys`: none for a document it does not hold, or one with no heading.
    func headings(_ keys: [DocumentKey]) async throws -> [DocumentKey: String] {
        guard !keys.isEmpty, let served = try await provider.servedIfReady() else { return [:] }
        let records = try await served.pipeline.candidateRecords(forKeys: keys)
        return records.compactMapValues { $0.header.isEmpty ? nil : $0.header }
    }

    /// The map a link names, applied in the app's order (`applyContinuedRequestIfNeeded`): its lens, where this server
    /// draws it; its scope; and then the document it reveals, or else the region it focuses.
    func request(_ query: FormQuery) async throws -> SemanticMapRequestAnswer {
        let scope = try ArchivalAnalyticsRoutes.scope(query, resources: resources)
        let request = SemanticMapRequest(
            volumeIDs: scope.volumeIds, scopeLabel: scope.label,
            lensRawValue: try query.single("lens") ?? SemanticMapRequest.wholeCorpus.lensRawValue,
            focusDocumentKey: try query.single("document"),
            focusClusterID: try query.optionalInteger("region", in: 0...Int(UInt16.max) - 1),
            focusClusterDigest: try query.single("layout"))
        let plane = try await plane()
        // An unknown lens is ignored rather than refused, and one this build cannot draw falls back to Regions.
        let lens = SemanticMapLens(rawValue: request.lensRawValue).flatMap { availableLenses.contains($0) ? $0 : nil } ?? .cluster
        var answer = SemanticMapRequestAnswer(lens: lens.rawValue, scopeLabel: request.scopeLabel)
        if let key = request.focusDocumentKey {
            let volume = SemanticMapReveal.documentKey(key)?.volumeID ?? String(key.split(separator: "/", maxSplits: 1).first ?? "")
            let title = resources.volume(volume)?.title
            var reveal = SemanticMapRequestAnswer.Reveal(key: key, revealed: false, volumeTitle: (title?.isEmpty == false ? title : nil) ?? volume)
            if let parts = SemanticMapReveal.documentKey(key) {
                let served = await served()
                if let revealed = SemanticMapReveal.reveal(
                    volumeID: parts.volumeID, documentID: parts.documentID, index: plane.index, map: plane.map.vectors,
                    clusters: plane.clusters, isReadable: { served.contains($0) }) {
                    reveal.revealed = true
                    reveal.point = try await point(revealed.selection, plane: plane)
                    reveal.camera = .init(x: revealed.camera.centre.x, y: revealed.camera.centre.y, halfExtent: revealed.camera.halfExtent)
                }
            }
            answer.reveal = reveal
        } else if let region = request.focusClusterID {
            // A focus whose layout is not this one, or whose id is no region of it, opens the map unfocused.
            var focus = SemanticMapRequestAnswer.Focus(region: region, focused: false)
            if let focused = SemanticMapReveal.focus(regionID: region, digest: request.focusClusterDigest,
                                                     artifactDigest: plane.map.index.layoutIdentity, clusters: plane.clusters) {
                focus.focused = true
                focus.camera = .init(x: focused.camera.centre.x, y: focused.camera.centre.y, halfExtent: focused.camera.halfExtent)
            }
            answer.focus = focus
        }
        return answer
    }

    /// A region's card: the kit's headline and era rows, and a page of the documents the app's card saves.
    func region(_ id: Int, query: FormQuery) async throws -> SemanticMapRegionCard {
        let plane = try await plane()
        if let layout = try query.single("layout"), layout != plane.map.index.layoutIdentity {
            throw APIProblem(.conflict, code: "LAYOUT_CHANGED",
                             detail: "Region \(id) was named in another layout of the map; this server's is \(plane.map.index.layoutIdentity).")
        }
        guard let cluster = plane.clusters.first(where: { $0.id == id }) else {
            throw APIProblem(.notFound, code: "REGION_NOT_FOUND", detail: "The map has no region \(id).")
        }
        let offset = try query.integer("offset", in: 0...SemanticMapPicking.corpusCaptureLimit, default: 0)
        let limit = try query.integer("limit", in: 1...Self.pageLimit, default: Self.pageSize)
        let mask = try await mask(query)
        let key = "\(id)|" + (mask.scope.volumeIds.map { $0.sorted().joined(separator: ",") } ?? "")
        let capture: SemanticMapPicking.LassoResult
        if let kept = captures.first(where: { $0.key == key }) {
            capture = kept.capture
        } else {
            capture = try await Blocking.run {
                SemanticMapCapture.region(cluster, map: plane.map.vectors, index: plane.index, scopeMask: mask.mask?.flags)
            }
            captures.insert((key, capture), at: 0)
            if captures.count > 4 { captures.removeLast() }
        }
        let page = capture.documentKeys.dropFirst(offset).prefix(limit).compactMap { key -> DocumentKey? in
            SemanticMapReveal.documentKey(key).map { DocumentKey(volumeId: $0.volumeID, documentId: $0.documentID) }
        }
        let served = await served()
        let titles = try await headings(page.filter { served.contains($0.volumeId) })
        return SemanticMapRegionCard(
            id: id, name: Self.regionName(cluster),
            countSummary: SemanticMapRegionRows.countSummary(
                documentCount: cluster.documentCount, inScope: mask.mask?.regionCounts[UInt16(clamping: cluster.id)]),
            eraRows: SemanticMapRegionRows.eraRows(cluster, locale: SearchItem.locale).map { .init(label: $0.label, count: $0.count) },
            total: capture.total, kept: capture.documentKeys.count, offset: offset,
            documents: page.map {
                .init(volumeId: $0.volumeId, documentId: $0.documentId, headline: headline(volumeId: $0.volumeId, documentId: $0.documentId),
                      title: titles[$0], served: served.contains($0.volumeId))
            })
    }

    /// How many of a region's documents a page of its card lists, and at most.
    static let pageSize = 25
    static let pageLimit = 200

    // MARK: Reading a request

    /// A finite number named `name`, which every view and pick gives.
    static func number(_ query: FormQuery, _ name: String, positive: Bool = false) throws -> Double {
        guard let raw = try query.single(name) else { throw APIProblem.invalidParameter(name, "is needed here") }
        guard let value = Double(raw), value.isFinite, abs(value) <= 1e9, !positive || value > 0 else {
            throw APIProblem.invalidParameter(name, "must be a finite number\(positive ? " above 0" : ""), not \(raw)")
        }
        return value
    }

    /// A view's side in CSS pixels: above 0, and no wider than a canvas is drawn.
    static func size(_ query: FormQuery, _ name: String) throws -> Double {
        let value = try number(query, name, positive: true)
        guard value <= 16_384 else { throw APIProblem.invalidParameter(name, "must be at most 16384, not \(value)") }
        return value
    }
}

// MARK: - The routes

enum SemanticMapReadingRoutes {
    static let scopeParameters = ArchivalAnalyticsRoutes.scopeParameters

    static func add(to router: Router<APIRequestContext>, reading: SemanticMapReading) {
        router.get("/api/v1/semantic/map/reading") { request, _ -> SemanticMapReadingContext in
            try FormQuery(request.uri.query).refuseUnknown([])
            return try await reading.context()
        }
        router.get("/api/v1/semantic/map/lens") { request, _ -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["lens"])
            guard let lens = try query.choice("lens", among: SemanticMapLens.allCases) else {
                throw APIProblem.invalidParameter("lens", "names the lens: one of \(SemanticMapLens.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            let slots = try await reading.slots(lens)
            return SemanticMapRoutes.answer(request, slots.body, tag: slots.tag, type: "application/octet-stream")
        }
        router.get("/api/v1/semantic/map/scope") { request, _ -> SemanticMapScopeAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters)
            return try await reading.scope(query)
        }
        router.get("/api/v1/semantic/map/scope/flags") { request, _ -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters)
            guard let flags = try await reading.mask(query).flags else {
                throw APIProblem.invalidParameter("scope", "the whole series ghosts nothing: name a scope")
            }
            return SemanticMapRoutes.answer(request, flags.body, tag: flags.tag, type: "application/octet-stream")
        }
        router.get("/api/v1/semantic/map/labels") { request, _ -> SemanticMapLabelsAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters.union(["x", "y", "halfExtent", "width", "height"]))
            return try await reading.labels(query)
        }
        router.get("/api/v1/semantic/map/pick") { request, _ -> SemanticMapPickAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters.union(["x", "y", "tolerance"]))
            return try await reading.pick(query)
        }
        router.get("/api/v1/semantic/map/request") { request, _ -> SemanticMapRequestAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters.union(["lens", "document", "region", "layout"]))
            return try await reading.request(query)
        }
        router.get("/api/v1/semantic/map/regions/:region") { request, context -> SemanticMapRegionCard in
            let raw = try context.parameters.require("region")
            guard !raw.isEmpty, raw.allSatisfy(\.isASCIIDigitCharacter), let id = Int(raw), String(id) == raw else {
                throw APIProblem(.notFound, code: "REGION_NOT_FOUND", detail: "The map has no region \(raw).")
            }
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters.union(["offset", "limit", "layout"]))
            return try await reading.region(id, query: query)
        }
    }
}
