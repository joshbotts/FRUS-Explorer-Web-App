// The semantic map's tools (PLAN's S28e): the lasso, a region's save, the two-pole axis and the slice it lays out,
// Nearest in language and the export, each by the kit's rules (FRUSCoreKit's `Semantic/`, S28a) over the map S28c
// reads (`SemanticMapReading`), the bundled vectors S26c reads, the catalogue and the served index.
//   POST /api/v1/semantic/map/lasso?…                 what a lasso drawn in the map's own coordinates encloses under the
//                                                     scope (`SemanticMapPicking.rows(insideGrid:…)`, at the capture's
//                                                     7,500 with the whole count beside them, `SemanticMapCapture.lasso`):
//                                                     its count, the three regions it caught most of, and what the served
//                                                     index holds of it
//   POST /api/v1/me/working-corpora/lasso?…           the lasso saved as a working corpus as the app saves it: named by those
//                                                     regions and the moment (`corpusName`, `stamp`) and described as a
//                                                     Semantic map selection (`sourceDescription(scopeLabel:)`)
//   POST /api/v1/me/working-corpora/region?…          a region's card saved the same way (`SemanticMapCapture.region`)
//   GET  /api/v1/semantic/map/slice?from=&to=         two volumes as the axis's poles (`SemanticAxis.centroid`,
//                                                     `SemanticMapPoles.resolve`): the app's refusals, or the slice's
//                                                     scale, ticks and caveat (`SemanticMapSlice`)
//   GET  /api/v1/semantic/map/slice/points?from=&to=  the slice's points, six bytes a point as the map's are, each at its
//                                                     projection and its volume's year (`SemanticMapSlice.layout`), with
//                                                     its region from the map
//   GET  /api/v1/semantic/map/slice/pick?…            the point nearest a point of the slice's grid, as the map's pick is
//   GET  /api/v1/semantic/map/nearest?document=       Nearest in language, a point's card's ten: the semantic source S26d
//                                                     ranks Related Documents' axis with (`SemanticVectorsSimilaritySource.
//                                                     candidates`), which needs the anchor's shard
//   GET  /api/v1/semantic/map/export?…                the regions' CSV with the kit's method block (`regionsTable`,
//                                                     `provenance`), as the app's Export writes it
//   GET  /api/v1/semantic/map/plate?…                 the figure's caption band and its names, laid out for its plate
//                                                     (`provenance(…frame:)`, `FigureFrame`), for the PNG the browser draws
// A slice is the map laid out again, so whatever is drawn on it is asked of it: the lasso and a pick take its poles, and
// scan its positions, as the app's scan the positions on screen. The slice's layout traps when no volume has a year
// (FRUS-Explorer#1986, open); a slice is refused before it is laid out when no volume the map places has one in the
// catalogue, which never happens at the pin, whose 553 volumes all have a coverage year.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import NIOCore
import SemanticVectorsKit

// MARK: - The answers

/// `POST /api/v1/semantic/map/lasso`: what a lasso encloses, as the app's lasso card shows it (`lassoCard`).
public struct SemanticMapLassoAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// What the lasso caught (`SemanticMapPicking.LassoResult`), and what the served index holds of it.
    public struct Capture: Codable, Equatable, Sendable {
        /// Every document of the scope inside the lasso, and those of them a corpus keeps, 7,500 at most.
        public var total: Int
        public var kept: Int
        /// The regions it caught most of, most first, two terms each (`SemanticMapCapture.lasso`).
        public var regionNames: [String]
        /// What the served index holds of the kept documents, by volume, as the app's card says it
        /// (`WorkingCorpusResolver`); absent while no index is served.
        public var coverage: CorpusCoverage?
    }

    /// The capture, or none: an unscoped lasso that caught nothing, or a path of fewer than three points, has no card.
    public var capture: Capture?
    /// Whether a scope gated it: a scoped lasso that caught nothing says so.
    public var scoped: Bool
}

/// `GET /api/v1/semantic/map/slice`: two poles' slice, or why they draw none.
public struct SemanticMapSliceAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// Why the poles draw no slice (`SemanticMapPoles.Refusal`).
    public struct Refusal: Codable, Equatable, Sendable {
        /// The kit's case: `sameVolume`, `noSummary` or `tooAlike`.
        public var reason: String
        /// What the reader is told (`notice`).
        public var notice: String
    }

    /// The years the slice's height spans, and the documents of volumes with none (`SemanticMapSlice.Scale`).
    public struct Scale: Codable, Equatable, Sendable {
        public var minYear: Int
        public var maxYear: Int
        public var undatedCount: Int
    }

    /// A year the slice's side names (`tickYears`), at its place on the slice's grid (`y(forYear:scale:)`).
    public struct Tick: Codable, Equatable, Sendable {
        public var year: Int
        public var y: Float
    }

    /// The low end's volume and the high end's, which name the axis (`negativeLabel`, `positiveLabel`).
    public var from: String
    public var to: String
    public var refusal: Refusal?
    /// Half the slice's grid: every point lies within it of zero (`SemanticAxis.sliceExtent`).
    public var gridExtent: Int?
    public var scale: Scale?
    public var ticks: [Tick]?
    /// The undated volumes' row on the slice's grid (`gutterY`), when any document is in it.
    public var gutterY: Float?
    /// What the slice's position means and what it does not (`SemanticMapSlice.caveat`).
    public var caveat: String?
}

/// `GET /api/v1/semantic/map/nearest`: a point's ten nearest in language (`nearestSection`).
public struct SemanticMapNearestAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public struct Neighbour: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// Its heading in the served index (`record.header`), as the app's row names it.
        public var title: String
        /// The calibrated cosine (`strength`), and the percentage the app's row prints of it.
        public var score: Double
        public var percent: Int
    }

    /// The anchor, `volumeId/documentId`.
    public var document: String
    public var neighbours: [Neighbour]
    /// Why there are none: `noIndex`, the server serving no index; `noShard`, its lacking the anchor's vectors; `none`.
    public var empty: String?
}

/// `GET /api/v1/semantic/map/plate`: an exported figure's caption band, and the names it draws over its plate.
public struct SemanticMapFigure: Codable, Equatable, Sendable, ResponseEncodable {
    /// The kit's lines (`plateLines(for:)`) and the file's name.
    public var plate: AnalyticsPlate
    /// The plate's rectangle in points, which the browser draws the map into at twice its size.
    public var width: Int
    public var height: Int
    /// The names over the plate, laid out for it (`SemanticMapLabelLayout.labels`): none on a slice.
    public var labels: [SemanticMapLabelsAnswer.Label]
}

// MARK: - The tools

/// The map's tools, over the map's reading, with the last few slices kept.
actor SemanticMapTools {
    /// Two poles' slice: its layout, and its points as the answer sends them.
    struct Slice: Sendable {
        let from: String
        let to: String
        let layout: SemanticMapSlice.Layout
        let points: SemanticMapReading.Bytes
        /// The bundled vectors' width, which the caveat names.
        let shippingDims: Int
    }

    /// What two poles come to.
    enum Poles: Sendable {
        case refused(SemanticMapPoles.Refusal)
        case slice(Slice)
    }

    let reading: SemanticMapReading
    let vectors: SemanticVectors
    let provider: ServedIndexProvider
    let resources: ServerResources
    private var slices: [(key: String, task: Task<Result<Poles, APIProblem>, Never>)] = []

    init(reading: SemanticMapReading, vectors: SemanticVectors, provider: ServedIndexProvider, resources: ServerResources) {
        self.reading = reading
        self.vectors = vectors
        self.provider = provider
        self.resources = resources
    }

    // MARK: The slice

    /// The slice two poles draw, laid out on the first ask and kept for the last few pairs asked; two first asks of a
    /// pair wait for one layout.
    func poles(from: String, to: String) async throws -> Poles {
        let key = "\(from)|\(to)"
        if let at = slices.firstIndex(where: { $0.key == key }) {
            let kept = slices.remove(at: at)
            slices.insert(kept, at: 0)
            return try await kept.task.value.get()
        }
        let plane = try await reading.plane()
        guard case .success(let tiers) = await vectors.tiers() else {
            throw SemanticMapFiles.malformed("the bundled vectors are refused")
        }
        let resources = resources
        let task = Task<Result<Poles, APIProblem>, Never> {
            do {
                return try await Blocking.run {
                    Self.laidOut(from: from, to: to, plane: plane, corpus: tiers.corpus,
                                 yearForVolume: { SemanticMapVolumes.coverageYear(of: resources.volume($0)) })
                }
            } catch {
                return .failure(SemanticMapFiles.malformed("\(error)"))
            }
        }
        slices.insert((key, task), at: 0)
        if slices.count > Self.keptSlices { slices.removeLast() }
        return try await task.value.get()
    }

    /// The slices kept: each 1.9 MB of points beside its 1.3 MB of positions.
    static let keptSlices = 4

    /// The kit's rule for two poles, as the app's `setPole` applies it, and the slice it lays out: each point by its
    /// sign bits' projection onto the axis and its volume's year, the coverage midpoint the catalogue gives it.
    static func laidOut(from: String, to: String, plane: SemanticMapReading.Plane, corpus: SemanticCorpusVectors,
                        yearForVolume: (String) -> Int?) -> Result<Poles, APIProblem> {
        let index = plane.index
        // The server's plane is read before it is asked, so the pair is never deferred for a load.
        let resolution = SemanticMapPoles.resolve(negative: from, positive: to, isReady: true) { volume in
            SemanticAxis.centroid(forVolume: volume, index: index, corpus: corpus)
        }
        let axis: SemanticAxis
        switch resolution {
        case .refused(let refusal):
            return .success(.refused(refusal))
        case .axis(let found):
            axis = found
        case .incomplete, .deferred:
            return .failure(SemanticMapFiles.malformed("the poles \(from) and \(to) were neither refused nor resolved"))
        }
        // FRUS-Explorer#1986: the layout's year span overflows when no volume it places has a year, so the slice is
        // refused before it is laid out, rather than end the process.
        guard index.volumes.contains(where: { index.rows(forVolume: $0.volumeID) != nil && yearForVolume($0.volumeID) != nil }) else {
            return .failure(APIProblem(.serviceUnavailable, code: "SLICE_UNAVAILABLE", detail: undatedWords))
        }
        let layout = SemanticMapSlice.layout(along: axis, map: plane.map.vectors, index: index, corpus: corpus,
                                             yearForVolume: yearForVolume)
        var points = ByteBufferAllocator().buffer(capacity: layout.positions.count * SemanticMapArtifacts.bytesPerDocument)
        for (row, position) in layout.positions.enumerated() {
            points.writeInteger(UInt16(bitPattern: position.x), endianness: .little)
            points.writeInteger(UInt16(bitPattern: position.y), endianness: .little)
            points.writeInteger(plane.map.vectors.placement(at: row)?.cluster ?? SemanticMapArtifacts.unclustered, endianness: .little)
        }
        return .success(.slice(Slice(from: from, to: to, layout: layout,
                                     points: SemanticMapReading.Bytes(body: points, tag: SemanticMapFiles.entityTag(points)),
                                     shippingDims: index.provenance.shippingDims)))
    }

    /// The server's words for a slice no volume's year can lay out, which the bundled catalogue never gives.
    static let undatedWords = "No volume the map places has a coverage year in this server’s catalogue, so no slice can be laid out."

    func slice(from: String, to: String) async throws -> SemanticMapSliceAnswer {
        switch try await poles(from: from, to: to) {
        case .refused(let refusal):
            return SemanticMapSliceAnswer(from: from, to: to, refusal: .init(reason: refusal.rawValue, notice: refusal.notice))
        case .slice(let slice):
            let scale = slice.layout.scale
            let extent = Float(SemanticAxis.sliceExtent)
            return SemanticMapSliceAnswer(
                from: from, to: to, gridExtent: SemanticAxis.sliceExtent,
                scale: .init(minYear: scale.minYear, maxYear: scale.maxYear, undatedCount: scale.undatedCount),
                ticks: SemanticMapSlice.tickYears(min: scale.minYear, max: scale.maxYear).map {
                    .init(year: $0, y: SemanticMapSlice.y(forYear: $0, scale: scale) * extent)
                },
                gutterY: scale.undatedCount > 0 ? SemanticMapSlice.gutterY * extent : nil,
                caveat: SemanticMapSlice.caveat(from: from, to: to, shippingDims: slice.shippingDims))
        }
    }

    /// The slice a request's `from` and `to` name, which must draw one; none for a request that names neither.
    func drawnSlice(_ query: FormQuery) async throws -> Slice? {
        let from = try Self.pole(query, "from")
        let to = try Self.pole(query, "to")
        guard from != nil || to != nil else { return nil }
        guard let from, let to else {
            throw APIProblem.invalidParameter(from == nil ? "from" : "to", "a slice is named by both of its poles")
        }
        switch try await poles(from: from, to: to) {
        case .slice(let slice): return slice
        case .refused(let refusal):
            throw APIProblem.invalidParameter("to", "\(from) and \(to) draw no slice: \(refusal.notice)")
        }
    }

    /// A pole: a volume's id, as the map's index names it.
    static func pole(_ query: FormQuery, _ name: String) throws -> String? {
        guard let raw = try query.single(name) else { return nil }
        guard !raw.isEmpty, raw.count <= 64,
              raw.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "._-".unicodeScalars.contains($0)) })
        else {
            throw APIProblem.invalidParameter(name, "names a volume by its id, not \(raw)")
        }
        return raw
    }

    /// The positions drawn under a request: its slice's, or the map's own.
    func positions(_ query: FormQuery, plane: SemanticMapReading.Plane) async throws -> [SIMD2<Int16>] {
        try await drawnSlice(query)?.layout.positions ?? plane.positions
    }

    /// The point nearest a point of the slice's grid, under the scope: the map's pick, among the slice's positions, as
    /// the app's hit test scans the positions on screen; the point at its place on the slice.
    func slicePick(_ query: FormQuery) async throws -> SemanticMapPickAnswer {
        guard let slice = try await drawnSlice(query) else {
            throw APIProblem.invalidParameter("from", "a slice's pick names the slice's poles")
        }
        let target = SIMD2<Float>(Float(try SemanticMapReading.number(query, "x")), Float(try SemanticMapReading.number(query, "y")))
        let tolerance = Float(try SemanticMapReading.number(query, "tolerance", positive: true))
        let mask = try await reading.mask(query)
        let plane = try await reading.plane()
        let positions = slice.layout.positions
        let hit = try await Blocking.run {
            SemanticMapPicking.hit(nearGrid: target, tolerance: tolerance, positions: positions, scopeMask: mask.mask?.flags)
        }
        guard let hit else { return SemanticMapPickAnswer(point: nil) }
        guard let document = plane.index.document(at: hit.row) else {
            throw SemanticMapFiles.malformed("row \(hit.row) has a placement but no document id")
        }
        let selection = SemanticMapPicking.Selection(
            row: hit.row, volumeID: document.volumeID, documentID: document.documentID, position: hit.position,
            regionName: SemanticMapPicking.regionName(ofRow: hit.row, map: plane.map.vectors, clusters: plane.clusters),
            isDownloaded: await reading.served().contains(document.volumeID))
        return SemanticMapPickAnswer(point: try await reading.point(selection, plane: plane))
    }

    // MARK: The lasso and the region

    /// What a lasso encloses, as the app's `finishLasso` resolves it: the rows inside the path, in the map's own
    /// coordinates, among the positions drawn and under the scope, at the capture's 7,500 with every one counted; then the
    /// kit's capture of them. A path of fewer than three points draws no card, as the app's lasso closes none.
    func lasso(_ polygon: [SIMD2<Float>], query: FormQuery) async throws
        -> (capture: SemanticMapPicking.LassoResult?, scope: ArchivalScope) {
        let mask = try await reading.mask(query)
        let plane = try await reading.plane()
        let positions = try await positions(query, plane: plane)
        guard polygon.count >= 3 else { return (nil, mask.scope) }
        let capture = try await Blocking.run { () -> SemanticMapPicking.LassoResult? in
            let found = SemanticMapPicking.rows(insideGrid: polygon, positions: positions,
                                                limit: SemanticMapPicking.corpusCaptureLimit, scopeMask: mask.mask?.flags)
            return SemanticMapCapture.lasso(rows: found.rows, total: found.total, isScoped: mask.mask != nil,
                                            map: plane.map.vectors, index: plane.index, clusters: plane.clusters)
        }
        return (capture, mask.scope)
    }

    func lassoAnswer(_ polygon: [SIMD2<Float>], query: FormQuery) async throws -> SemanticMapLassoAnswer {
        let (capture, scope) = try await lasso(polygon, query: query)
        let served = try await provider.servedIfReady()
        defer { withExtendedLifetime(served) {} }
        return SemanticMapLassoAnswer(
            capture: capture.map { capture in
                .init(total: capture.total, kept: capture.documentKeys.count, regionNames: capture.regionNames,
                      coverage: served.map {
                          CorpusCoverage(WorkingCorpusResolver(indexedVolumeIds: $0.indexedVolumeIds).resolve(documentKeys: capture.documentKeys))
                      })
            },
            scoped: scope.volumeIds != nil)
    }

    /// A region's capture under the scope, as the app's card saves it (`regionCapture()`).
    func region(_ id: Int, layout: String?, query: FormQuery) async throws
        -> (capture: SemanticMapPicking.LassoResult, scope: ArchivalScope) {
        let plane = try await reading.plane()
        if let layout, layout != plane.map.index.layoutIdentity {
            throw APIProblem(.conflict, code: "LAYOUT_CHANGED",
                             detail: "Region \(id) was named in another layout of the map; this server's is \(plane.map.index.layoutIdentity).")
        }
        guard let cluster = plane.clusters.first(where: { $0.id == id }) else {
            throw APIProblem(.notFound, code: "REGION_NOT_FOUND", detail: "The map has no region \(id).")
        }
        let mask = try await reading.mask(query)
        let capture = try await Blocking.run {
            SemanticMapCapture.region(cluster, map: plane.map.vectors, index: plane.index, scopeMask: mask.mask?.flags)
        }
        return (capture, mask.scope)
    }

    /// A capture saved as the app's `saveWorkingCorpus` saves it: named by its regions at `time` in `timeZone`
    /// (`corpusName`, `stamp`), with no query, described by its scope (`sourceDescription(scopeLabel:)`), for the served
    /// index as it is now. One that holds nothing is refused, as the app's card offers no Save for it.
    func corpus(_ capture: SemanticMapPicking.LassoResult?, scope: ArchivalScope, at time: Date, in timeZone: TimeZone)
        async throws -> (corpus: WorkingCorpusExport, served: ServedIndex?) {
        guard let capture, !capture.documentKeys.isEmpty else {
            throw APIProblem(.badRequest, code: "NOTHING_TO_CAPTURE", detail: "The selection holds no documents to save as a working corpus.")
        }
        let name = SemanticMapCapture.corpusName(
            regionNames: capture.regionNames,
            stamp: SemanticMapCapture.stamp(for: time, locale: SearchItem.locale, timeZone: timeZone))
        let served = try await provider.servedIfReady()
        // No query produced the set, and none could make it again, so it records none (`sourceQuery: nil`).
        let corpus = WorkingCorpusExport(
            id: UUID(), name: name, documentKeys: capture.documentKeys, capturedAt: time, sourceQuery: nil,
            sourceDescription: SemanticMapCapture.sourceDescription(scopeLabel: scope.volumeIds == nil ? nil : scope.label),
            indexedVolumeCountAtCapture: served?.indexedVolumeIds.count ?? 0,
            wasTruncatedAtCapture: capture.isTruncated, totalMatchCountAtCapture: capture.total,
            createdAt: time, lastModified: time)
        return (corpus, served)
    }

    // MARK: Nearest in language

    /// The ten nearest documents in the corpus's language to a document of the map, as the app's point card asks the
    /// related documents' semantic generator for them (`loadNeighbours`): unscoped, with no year, from the volumes the
    /// server serves, scored against their shards; none without the anchor's own shard, which the answer says.
    func nearest(_ key: String) async throws -> SemanticMapNearestAnswer {
        guard let parts = SemanticMapReveal.documentKey(key) else {
            throw APIProblem.invalidParameter("document", "names a document as volumeId/documentId, not \(key)")
        }
        let plane = try await reading.plane()
        guard plane.index.row(documentID: parts.documentID, volumeID: parts.volumeID) != nil else {
            throw APIProblem(.notFound, code: "NOT_ON_MAP", detail: "\(key) has no place on the map.")
        }
        let anchor = DocumentKey(volumeId: parts.volumeID, documentId: parts.documentID)
        guard let served = try await provider.servedIfReady() else {
            return SemanticMapNearestAnswer(document: key, neighbours: [], empty: "noIndex")
        }
        defer { withExtendedLifetime(served) {} }
        guard case .success(let bundle) = await vectors.bundle() else {
            throw APIProblem(.serviceUnavailable, code: "SEMANTIC_UNAVAILABLE",
                             detail: "This server’s semantic vectors could not be read, so it finds no nearest documents.")
        }
        let (pool, missing) = try await Self.candidates(anchor, bundle: bundle, shards: vectors, served: served)
        let neighbours = pool.candidates.map { candidate in
            SemanticMapNearestAnswer.Neighbour(
                volumeId: candidate.key.volumeId, documentId: candidate.key.documentId,
                title: candidate.record.header.isEmpty
                    ? reading.headline(volumeId: candidate.key.volumeId, documentId: candidate.key.documentId)
                    : candidate.record.header,
                score: candidate.strength, percent: Int((candidate.strength * 100).rounded()))
        }
        let empty: String? = !neighbours.isEmpty ? nil
            : missing.contains(anchor.volumeId) ? "noShard"
            : served.indexedVolumeIds.isEmpty ? "noIndex" : "none"
        return SemanticMapNearestAnswer(document: key, neighbours: neighbours, empty: empty)
    }

    /// How many neighbours the card lists (`nearestCount`).
    static let nearestCount = 10

    /// The semantic source's candidates over the server's vectors (`ServedSemantics`), and the volumes whose shard it
    /// asked for and the server did not hold.
    @MainActor
    static func candidates(_ anchor: DocumentKey, bundle: SemanticBundle, shards: any SemanticShardSource, served: ServedIndex)
        async throws -> (pool: GeneratedPool, missing: [String]) {
        let semantic = ServedSemantics(bundle: bundle, shards: shards, served: served)
        // Unscoped, as the app's card asks: a map's scope narrows what is drawn, not what a document is nearest to.
        let pool = try await semantic.source.candidates(for: anchor, anchorYear: nil, limit: nearestCount, scopeVolumeIds: nil)
        return (pool, semantic.missingShards)
    }

    // MARK: The export

    /// A lens a request names to state in the method block: the drawn one, Regions by default.
    func lens(_ query: FormQuery) throws -> SemanticMapLens {
        let lens = try query.choice("lens", among: SemanticMapLens.allCases) ?? .cluster
        guard reading.availableLenses.contains(lens) else {
            throw APIProblem(.notFound, code: "LENS_UNAVAILABLE",
                             detail: "This server's source-provenance aggregate has no table by volume, so the \(lens.displayName) lens cannot be drawn.")
        }
        return lens
    }

    /// The regions' table under the scope and its method block, as the app's `exportRegionsCSV` writes them: the regions
    /// the map names in the scope, with their in-scope counts (`labelledClusters`), and the statement over the volumes
    /// the server serves.
    func regions(_ query: FormQuery, lens: SemanticMapLens) async throws -> (table: ChartInspectorData, provenance: AnalyticsProvenance) {
        let mask = try await reading.mask(query)
        let plane = try await reading.plane()
        let served = await reading.served()
        let table = SemanticMapExport.regionsTable(clusters: SemanticMapLabelLayout.labelledClusters(plane.clusters, scope: mask.mask))
        let provenance = SemanticMapExport.provenance(
            index: plane.map.index, scopeLabel: mask.mask == nil ? nil : mask.scope.label,
            scopedDocumentCount: mask.mask?.documentCount, lens: lens, indexedVolumeCount: served.count)
        return (table, provenance)
    }

    /// The figure's caption band and names, as the app's `exportMapFigure` makes them: the plate's rectangle, the names
    /// laid out for it from the camera on screen, none on a slice, and the method block with the figure's title, the
    /// slice's sentence and the frame (`FigureFrame`).
    func figure(_ query: FormQuery, lens: SemanticMapLens, camera: SemanticMapCamera, timeZone: TimeZone) async throws -> SemanticMapFigure {
        let mask = try await reading.mask(query)
        let plane = try await reading.plane()
        let slice = try await drawnSlice(query)
        let served = await reading.served()
        let size = CGSize(width: Self.plateWidth, height: Self.plateHeight)
        let labels = slice == nil
            ? SemanticMapLabelLayout.labels(for: SemanticMapLabelLayout.labelledClusters(plane.clusters, scope: mask.mask),
                                            camera: camera, size: size)
            : []
        let now = Date()
        let provenance = SemanticMapExport.provenance(
            index: plane.map.index, scopeLabel: mask.mask == nil ? nil : mask.scope.label,
            scopedDocumentCount: mask.mask?.documentCount, lens: lens, indexedVolumeCount: served.count,
            figureTitle: Self.figureTitle,
            sliceDescription: slice.map { String(format: Self.sliceDescription, $0.from, $0.to) },
            frame: SemanticMapExport.FigureFrame(camera: camera, size: size, labelledRegionCount: labels.count))
        return SemanticMapFigure(
            plate: AnalyticsPlate(provenance, host: CorpusAnalyticsRoutes.host(timeZone: timeZone), date: now),
            width: Int(Self.plateWidth), height: Int(Self.plateHeight),
            labels: labels.map {
                .init(id: $0.id, text: $0.text, x: Double($0.position.x), y: Double($0.position.y), documentCount: $0.documentCount)
            })
    }

    /// The plate's rectangle (`exportMapFigure`'s `mapPoints`): the figure's width, 1,200 points, less its margins, by 900.
    static let plateWidth: CGFloat = 1_200 - 56
    static let plateHeight: CGFloat = 900
    /// The figure's title (`semanticMap.export.figureTitle`).
    static let figureTitle = "Semantic map"
    /// What a slice's figure says first (`semanticMap.export.caveat.slice %@ %@`).
    static let sliceDescription = "This figure shows a SLICE (%1$@ → %2$@), not a map: the horizontal axis is the slice projection and the vertical axis is time. The map’s region labels are omitted because a slice offers a totally different illustration of the series’s semantic space."
}

// MARK: - The routes

enum SemanticMapToolsRoutes {
    static let scopeParameters = ArchivalAnalyticsRoutes.scopeParameters
    static let sliceParameters: Set<String> = ["from", "to"]
    /// The most points a lasso's path may hold: a stroke thinned at the app's four points, twice around a wide window.
    static let polygonLimit = 2_000
    /// The largest lasso's body, in bytes.
    static let bodyLimit = 64 * 1_024

    struct Lasso: Decodable {
        let polygon: [[Double]]
    }

    struct LassoSave: Decodable {
        let polygon: [[Double]]
        /// The reader's time zone, an IANA name, in which the corpus's name says when it was saved.
        let timeZone: String?
    }

    struct RegionSave: Decodable {
        let region: Int
        let layout: String?
        let timeZone: String?
    }

    /// The tools over the map's reading, and the two saves where the server keeps user data.
    static func add(to router: Router<APIRequestContext>, reading: SemanticMapReading, vectors: SemanticVectors,
                    provider: ServedIndexProvider, resources: ServerResources, userData: UserDataServices?) {
        let tools = SemanticMapTools(reading: reading, vectors: vectors, provider: provider, resources: resources)
        router.post("/api/v1/semantic/map/lasso") { request, _ -> SemanticMapLassoAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters.union(sliceParameters))
            let body = try await JSONBody.decode(Lasso.self, from: request, fields: ["polygon"], limit: bodyLimit)
            return try await tools.lassoAnswer(try polygon(body.polygon), query: query)
        }
        router.get("/api/v1/semantic/map/slice") { request, _ -> SemanticMapSliceAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(sliceParameters)
            let (from, to) = try poles(query)
            return try await tools.slice(from: from, to: to)
        }
        router.get("/api/v1/semantic/map/slice/points") { request, _ -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(sliceParameters)
            let (from, to) = try poles(query)
            guard case .slice(let slice) = try await tools.poles(from: from, to: to) else {
                throw APIProblem(.notFound, code: "NO_SLICE", detail: "\(from) and \(to) draw no slice.")
            }
            return SemanticMapRoutes.answer(request, slice.points.body, tag: slice.points.tag, type: "application/octet-stream")
        }
        router.get("/api/v1/semantic/map/slice/pick") { request, _ -> SemanticMapPickAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters.union(sliceParameters).union(["x", "y", "tolerance"]))
            return try await tools.slicePick(query)
        }
        router.get("/api/v1/semantic/map/nearest") { request, _ -> SemanticMapNearestAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["document"])
            guard let key = try query.single("document") else {
                throw APIProblem.invalidParameter("document", "names the document whose neighbours are asked for")
            }
            return try await tools.nearest(key)
        }
        router.get("/api/v1/semantic/map/export") { request, _ -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters.union(["lens", "timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let (table, provenance) = try await tools.regions(query, lens: try await tools.lens(query))
            let csv = table.provenancedCSV(provenance, for: CorpusAnalyticsRoutes.host(timeZone: timeZone))
            return AnalyticsFigures.csv(csv, name: CorpusAnalyticsRoutes.filenameStem(title: provenance.figureTitle, date: provenance.exportDate))
        }
        router.get("/api/v1/semantic/map/plate") { request, _ -> SemanticMapFigure in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters.union(sliceParameters).union(["lens", "x", "y", "halfExtent", "timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let camera = SemanticMapCamera(
                centre: SIMD2<Float>(Float(try SemanticMapReading.number(query, "x")), Float(try SemanticMapReading.number(query, "y"))),
                halfExtent: Float(try SemanticMapReading.number(query, "halfExtent", positive: true)))
            return try await tools.figure(query, lens: try await tools.lens(query), camera: camera, timeZone: timeZone)
        }

        guard let services = userData else { return }
        let me = router.group("/api/v1/me").add(middleware: UserDataGuard(services: services))
        me.post("working-corpora/lasso") { request, context -> EditedResponse<WorkingCorpus> in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters.union(sliceParameters))
            let user = try context.requireUser()
            let body = try await JSONBody.decode(LassoSave.self, from: request, fields: ["polygon", "timeZone"], limit: bodyLimit)
            let timeZone = try CollectionExportRoutes.zone(body.timeZone, field: "timeZone")
            let (capture, scope) = try await tools.lasso(try polygon(body.polygon), query: query)
            let (corpus, served) = try await tools.corpus(capture, scope: scope, at: UserStoreDate.rounded(services.now()), in: timeZone)
            return try await saved(corpus, served: served, for: user, services: services, context: context)
        }
        me.post("working-corpora/region") { request, context -> EditedResponse<WorkingCorpus> in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters)
            let user = try context.requireUser()
            let body = try await JSONBody.decode(RegionSave.self, from: request, fields: ["region", "layout", "timeZone"])
            let timeZone = try CollectionExportRoutes.zone(body.timeZone, field: "timeZone")
            let (capture, scope) = try await tools.region(body.region, layout: body.layout, query: query)
            let (corpus, served) = try await tools.corpus(capture, scope: scope, at: UserStoreDate.rounded(services.now()), in: timeZone)
            return try await saved(corpus, served: served, for: user, services: services, context: context)
        }
    }

    /// A corpus written as the import writes a Mac's (`MacImport.corpus`), as Browse's clusters save one, and answered
    /// with 201 and its address.
    static func saved(_ corpus: WorkingCorpusExport, served: ServedIndex?, for user: RequestUser, services: UserDataServices,
                      context: APIRequestContext) async throws -> EditedResponse<WorkingCorpus> {
        defer { withExtendedLifetime(served) {} }
        try await Blocking.run { try services.store.addSearchSet(.workingCorpora, MacImport.corpus(corpus).values, for: user.id) }
        let location = context.basePath.prefixing("/api/v1/me/working-corpora/\(corpus.id.uuidString)")
        return EditedResponse(status: .created, headers: [.location: location], response: WorkingCorpus(corpus, served: served))
    }

    /// A slice's two poles, both named.
    static func poles(_ query: FormQuery) throws -> (from: String, to: String) {
        guard let from = try SemanticMapTools.pole(query, "from") else { throw APIProblem.invalidParameter("from", "names the slice's low end") }
        guard let to = try SemanticMapTools.pole(query, "to") else { throw APIProblem.invalidParameter("to", "names the slice's high end") }
        return (from, to)
    }

    /// A lasso's path in the map's own coordinates, each point two finite numbers, at most `polygonLimit` of them.
    static func polygon(_ raw: [[Double]]) throws -> [SIMD2<Float>] {
        guard raw.count <= polygonLimit else {
            throw APIProblem.invalidParameter("polygon", "a lasso's path holds at most \(polygonLimit) points, not \(raw.count)")
        }
        return try raw.map { pair in
            guard pair.count == 2, pair.allSatisfy({ $0.isFinite && abs($0) <= 1e7 }) else {
                throw APIProblem.invalidParameter("polygon", "each point is two finite numbers on the map's grid")
            }
            return SIMD2<Float>(Float(pair[0]), Float(pair[1]))
        }
    }
}
