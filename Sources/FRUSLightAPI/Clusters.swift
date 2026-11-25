// Browse's clusters (PLAN's S28d): the axis the Mac's Browse lists and the web's left out until now, the app's
// `ClustersIndexView` and `ClusterDocumentsView` over the kit's `ClustersAxis` (FRUSCoreKit's `Semantic/`, S28a), read
// through the semantic map's reading (S28c), so that the bundled map and vectors are read once for the map and the axis.
//   GET  /api/v1/clusters                      the regions, largest first, ties by id (`ordered`), each with its four
//                                              terms (`rowLabel`), its count and its eras' histogram (`eraBars`), and
//                                              the counts the index's caption states (`indexCaption`)
//   GET  /api/v1/clusters/{id}?…               a region's documents, as `ClusterDocumentsView` lists them: its count in
//                                              the series and its eras' rows (`SemanticMapRegionRows.eraRows`), what the
//                                              served index holds of its members (`WorkingCorpusResolver`), and the first
//                                              `shown` of its members (`membershipRows`, `documentKeys`), in volume order,
//                                              a section a volume, each section by date (`CorporaAxis`, app code mirrored)
//   POST /api/v1/me/working-corpora/cluster    Save as Working Corpus: the region's members as the kit captures them
//                                              (`capture(keys:cluster:)`), at the app's 7,500 with the whole count beside
//                                              them, named by the map's rule at the reader's time (`SemanticMapCapture.
//                                              corpusName`, `stamp(for:locale:timeZone:)`), and described as the kit
//                                              describes a browse (`corpusSourceDescription`)
// A region's id means something only in the layout that minted it, so the documents and the save take the layout's
// identity (`MapIndex.layoutIdentity`) beside it, as See on the Semantic Map's link does, and refuse another layout's.
// The app's drill pages its members 500 at a time, "Show more" adding 500; here a page names how many are listed and
// how many were listed before, at most 500 more, and answers the sections of the listed members, less those of volumes
// none of whose listed members came after the ones listed before, so that a browser replaces the one volume a page
// boundary split and adds the rest, each section ordered over every listed member as the app orders it. Each page says
// how many volumes the served index held when it was listed, as the app's drill reloads its rows when that count
// changes, so that a browser lists its pages again rather than keep rows listed against another index.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import SemanticVectorsKit

// MARK: - The answers

/// `GET /api/v1/clusters`: Browse's Clusters, as the app's `ClustersIndexView` lists them.
public struct ClustersIndex: Codable, Equatable, Sendable, ResponseEncodable {
    /// One bar of a region's eras' histogram (`ClustersAxis.EraBar`).
    public struct EraBar: Codable, Equatable, Sendable {
        /// The coverage era's number (`CoverageEra.rawValue`), or nil for the pooled bar of the volumes no era dates.
        public var era: Int?
        public var count: Int
        /// One of the two largest bars, which the app accents.
        public var isPeak: Bool
    }

    /// A region, as the index's row shows it.
    public struct Cluster: Codable, Equatable, Sendable {
        public var id: Int
        /// Its four terms, as the row reads them (`rowLabel`), which titles its documents' page too.
        public var label: String
        public var documentCount: Int
        /// Its eras' histogram, oldest era first, each era in its slot (`eraBars`).
        public var eras: [EraBar]
    }

    /// The layout's identity (`MapIndex.layoutIdentity`), against which alone a region's id means anything.
    public var layoutIdentity: String
    /// What the index's caption states (`indexCaption`): the regions, the documents placed and those between regions.
    public var clusterCount: Int
    public var documentCount: Int
    public var unclusteredCount: Int
    /// The regions, largest first, ties by id (`ordered`).
    public var clusters: [Cluster]
}

/// `GET /api/v1/clusters/{id}`: a region's documents, as the app's `ClusterDocumentsView` lists them.
public struct ClusterDocuments: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: Int
    /// Its four terms (`rowLabel`), the page's title.
    public var label: String
    /// The map's form of its name, its first three terms (`mapStyleName`), which a saved corpus is named by.
    public var name: String
    public var layoutIdentity: String
    /// Documents in the series, as the map's index counts them.
    public var documentCount: Int
    /// Its eras' rows (`SemanticMapRegionRows.eraRows`), in US English.
    public var eraRows: [SemanticMapRegionCard.EraRow]
    /// Every member, as the kit finds them (`membershipRows`): what Save as Working Corpus captures from.
    public var total: Int
    /// What the served index holds of the members, by the kit's resolver; absent while no index is served.
    public var coverage: CorpusCoverage?
    /// How many volumes the served index held when the page was listed, nil while none is served: the count the app's
    /// drill reloads its rows' titles and dates on, by which a browser lists its pages again when one is listed
    /// against another index than the first.
    public var indexedVolumes: Int?
    /// How many of the members, in volume order, the sections list: the first `shown`.
    public var shown: Int
    /// How many were listed before, whose volumes' sections this answer leaves out where none of the members after them is theirs.
    public var after: Int
    /// The listed members, a section a volume, the volumes by id (`CorporaAxis.volumeSections`), each section's documents
    /// by date, then their volume's first day of coverage, then none, ties by id (`CorporaAxis.ordered`): every section,
    /// or with `after`, those of the volumes with a member listed after it.
    public var sections: [WorkingCorpusDetail.Section]
}

// MARK: - The reading

/// Browse's clusters over the map's reading: the plane S28c reads once, and the members of the last regions asked.
actor ClustersReading {
    let reading: SemanticMapReading
    let provider: ServedIndexProvider
    let resources: ServerResources
    /// The last few regions' members, in volume order, by region id, the latest asked first: the largest holds 37,899.
    /// Each is the scan that finds them, so that two first asks of a region wait for one scan.
    private var members: [(id: Int, scan: Task<[String], any Error>)] = []

    init(reading: SemanticMapReading, provider: ServedIndexProvider, resources: ServerResources) {
        self.reading = reading
        self.provider = provider
        self.resources = resources
    }

    /// The map's plane, or its refusal in the clusters' words.
    func plane() async throws -> SemanticMapReading.Plane {
        do {
            return try await reading.plane()
        } catch let problem as APIProblem {
            throw ClustersRoutes.refusal(problem)
        }
    }

    func index() async throws -> ClustersIndex {
        let plane = try await plane()
        let index = plane.map.index
        return ClustersIndex(
            layoutIdentity: index.layoutIdentity, clusterCount: index.clusters.count, documentCount: index.documentCount,
            unclusteredCount: index.layout.unclusteredCount,
            clusters: ClustersAxis.ordered(index.clusters).map { cluster in
                ClustersIndex.Cluster(
                    id: cluster.id, label: ClustersAxis.rowLabel(cluster), documentCount: cluster.documentCount,
                    eras: ClustersAxis.eraBars(cluster.eraCounts).map { .init(era: $0.era?.rawValue, count: $0.count, isPeak: $0.isPeak) })
            })
    }

    /// The region `id` of the plane's layout: refused for another layout's identity, or an id it has not.
    func cluster(_ id: Int, layout: String?, plane: SemanticMapReading.Plane) throws -> SemanticMapArtifacts.Cluster {
        if let layout, layout != plane.map.index.layoutIdentity {
            throw APIProblem(.conflict, code: "LAYOUT_CHANGED",
                             detail: "Cluster \(id) was named in another layout of the map; this server's is \(plane.map.index.layoutIdentity).")
        }
        guard let cluster = plane.clusters.first(where: { $0.id == id }) else { throw ClustersRoutes.notFound(String(id)) }
        return cluster
    }

    /// Every member of `cluster`, `"volumeId/documentId"`, in row order, which is volume order: the kit's membership
    /// (`membershipRows`) keyed by the vectors' index (`documentKeys`), kept for the last few regions asked.
    func members(of cluster: SemanticMapArtifacts.Cluster, plane: SemanticMapReading.Plane) async throws -> [String] {
        let id = cluster.id
        let scan: Task<[String], any Error>
        if let at = members.firstIndex(where: { $0.id == id }) {
            scan = members.remove(at: at).scan
        } else {
            scan = Task {
                try await Blocking.run {
                    ClustersAxis.documentKeys(rows: ClustersAxis.membershipRows(in: plane.map.vectors, clusterId: id).rows,
                                              index: plane.index)
                }
            }
        }
        members.insert((id, scan), at: 0)
        if members.count > 4 { members.removeLast() }
        do {
            return try await scan.value
        } catch {
            members.removeAll { $0.id == id }
            throw error
        }
    }

    /// A region's documents: its card's facts, what the served index holds of its members, and the sections of the first
    /// `shown`, less those that hold none of the members after the first `after`.
    func documents(_ id: Int, query: FormQuery) async throws -> ClusterDocuments {
        let plane = try await plane()
        let cluster = try cluster(id, layout: try query.single("layout"), plane: plane)
        let keys = try await members(of: cluster, plane: plane)
        let after = try query.integer("after", in: 0...ClustersRoutes.shownLimit, default: 0)
        let asked = try query.integer("shown", in: 1...ClustersRoutes.shownLimit, default: after + ClustersRoutes.pageSize)
        // A page, as "Show more" adds one: never more than 500 members past those listed before.
        guard asked <= after + ClustersRoutes.pageSize else {
            throw APIProblem.invalidParameter("shown", "lists at most \(ClustersRoutes.pageSize) members past after, \(after), not \(asked)")
        }
        let shown = min(asked, keys.count)
        guard after < max(shown, 1) else {
            throw APIProblem.invalidParameter("after", "must be fewer than the \(shown) members listed, not \(after)")
        }
        let served = try await provider.servedIfReady()
        let listed = Array(keys.prefix(shown))
        let changed = after == 0 ? nil : Set(listed[after...].compactMap { ClustersRoutes.volume(of: $0) })
        let sections = try await ClustersRoutes.sections(of: listed, onlyVolumes: changed, served: served, resources: resources)
        return ClusterDocuments(
            id: cluster.id, label: ClustersAxis.rowLabel(cluster), name: ClustersAxis.mapStyleName(cluster),
            layoutIdentity: plane.map.index.layoutIdentity, documentCount: cluster.documentCount,
            eraRows: SemanticMapRegionRows.eraRows(cluster, locale: SearchItem.locale).map { .init(label: $0.label, count: $0.count) },
            total: keys.count,
            coverage: served.map { CorpusCoverage(WorkingCorpusResolver(indexedVolumeIds: $0.indexedVolumeIds).resolve(documentKeys: keys)) },
            indexedVolumes: served?.indexedVolumeIds.count, shown: shown, after: after, sections: sections)
    }

    /// Save as Working Corpus, as the app's drill saves its cluster (`saveAsWorkingCorpus`): the kit's capture of every
    /// member, its name at `time` in `timeZone`, and the corpus it records, for the served index as it is now.
    func capture(_ id: Int, layout: String?, at time: Date, in timeZone: TimeZone)
        async throws -> (corpus: WorkingCorpusExport, served: ServedIndex?) {
        let plane = try await plane()
        let cluster = try cluster(id, layout: layout, plane: plane)
        let keys = try await members(of: cluster, plane: plane)
        let capture = ClustersAxis.capture(keys: keys, cluster: cluster)
        // The app's Save waits for a member (`.disabled(keys.isEmpty)`), and a search's capture refuses an empty set.
        guard !capture.documentKeys.isEmpty else {
            throw APIProblem(.badRequest, code: "NOTHING_TO_CAPTURE", detail: "Cluster \(id) has no documents to save as a working corpus.")
        }
        let name = SemanticMapCapture.corpusName(
            regionNames: capture.regionNames,
            stamp: SemanticMapCapture.stamp(for: time, locale: SearchItem.locale, timeZone: timeZone))
        let served = try await provider.servedIfReady()
        // No query produced the set, and a cluster's id cannot re-derive it in another layout, so it records no query.
        let corpus = WorkingCorpusExport(
            id: UUID(), name: name, documentKeys: capture.documentKeys, capturedAt: time, sourceQuery: nil,
            sourceDescription: ClustersAxis.corpusSourceDescription,
            indexedVolumeCountAtCapture: served?.indexedVolumeIds.count ?? 0,
            wasTruncatedAtCapture: capture.isTruncated, totalMatchCountAtCapture: capture.total,
            createdAt: time, lastModified: time)
        return (corpus, served)
    }
}

// MARK: - The routes

enum ClustersRoutes {
    /// How many members the app's drill lists first and adds at each "Show more" (`ClusterDocumentsView.pageSize`).
    static let pageSize = 500
    /// The most members a page may name: more than any region holds.
    static let shownLimit = 1_000_000

    struct Save: Decodable {
        let cluster: Int
        let layout: String?
        /// The reader's time zone, an IANA name, in which the corpus's name says when it was saved.
        let timeZone: String?
    }

    /// Browse's clusters over the map's reading, and Save as Working Corpus where the server keeps user data.
    static func add(to router: Router<APIRequestContext>, reading: SemanticMapReading, provider: ServedIndexProvider,
                    resources: ServerResources, userData: UserDataServices?) {
        let clusters = ClustersReading(reading: reading, provider: provider, resources: resources)
        router.get("/api/v1/clusters") { request, _ -> ClustersIndex in
            try FormQuery(request.uri.query).refuseUnknown([])
            return try await clusters.index()
        }
        router.get("/api/v1/clusters/:cluster") { request, context -> ClusterDocuments in
            let id = try Self.id(try context.parameters.require("cluster"))
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["shown", "after", "layout"])
            return try await clusters.documents(id, query: query)
        }
        guard let services = userData else { return }
        let me = router.group("/api/v1/me").add(middleware: UserDataGuard(services: services))
        me.post("working-corpora/cluster") { request, context -> EditedResponse<WorkingCorpus> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Save.self, from: request, fields: ["cluster", "layout", "timeZone"])
            let timeZone = try CollectionExportRoutes.zone(body.timeZone, field: "timeZone")
            let (corpus, served) = try await clusters.capture(body.cluster, layout: body.layout,
                                                              at: UserStoreDate.rounded(services.now()), in: timeZone)
            try await Blocking.run { try services.store.addSearchSet(.workingCorpora, MacImport.corpus(corpus).values, for: user.id) }
            let location = context.basePath.prefixing("/api/v1/me/working-corpora/\(corpus.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location], response: WorkingCorpus(corpus, served: served))
        }
    }

    /// A region's id in the path, in its canonical spelling.
    static func id(_ raw: String) throws -> Int {
        guard !raw.isEmpty, raw.count <= 5, raw.allSatisfy(\.isASCIIDigitCharacter), let id = Int(raw), String(id) == raw else {
            throw notFound(raw)
        }
        return id
    }

    static func notFound(_ id: String) -> APIProblem {
        APIProblem(.notFound, code: "CLUSTER_NOT_FOUND", detail: "The map has no cluster \(id).")
    }

    /// The map's refusal in the clusters' words, as the app's `ClustersIndexView` says why it has no list: the map's
    /// files and the bundled vectors from different releases, or the map not read, in a server's words, with the reason.
    static func refusal(_ problem: APIProblem) -> APIProblem {
        guard problem.code == "SEMANTIC_MAP_UNAVAILABLE" else { return problem }
        if problem.detail.hasPrefix(SemanticMapFiles.mismatchWords) {
            return APIProblem(problem.status, code: "CLUSTERS_UNAVAILABLE", detail: mismatchWords)
        }
        return APIProblem(problem.status, code: "CLUSTERS_UNAVAILABLE", detail: "\(unreadableWords) \(problem.detail)")
    }

    /// The app's `browser.clusters.mismatch`.
    static let mismatchWords = "The cluster data and the semantic vectors come from different releases, so the list is not shown."
    /// The app's `browser.clusters.missing`, a server's: "This build’s cluster data could not be read."
    static let unreadableWords = "This server’s cluster data could not be read."

    /// A key's volume, or nil for a key that is no `volumeId/documentId`.
    static func volume(of key: String) -> String? {
        let parts = key.split(separator: "/", maxSplits: 1)
        return parts.count == 2 ? String(parts[0]) : nil
    }

    /// The drill's sections of `keys`, as `ClusterDocumentsView` draws them from `CorporaAxis`, app code mirrored (as
    /// `WorkingCorpusRoutes.detail` mirrors it for a corpus): a section a volume, the volumes by id, a key that is no
    /// `volumeId/documentId` passed over (`volumeSections(from:)`); each section's documents by the day the index dates
    /// each by, then the volume's first day of coverage, then none last, a tie by id (`ordered`, `sortKey`); and a
    /// volume the served index holds titled and dated from it, its documents opening in the reader (`rowState`). With
    /// `onlyVolumes`, the sections of those volumes alone.
    static func sections(of keys: [String], onlyVolumes: Set<String>?, served: ServedIndex?,
                         resources: ServerResources) async throws -> [WorkingCorpusDetail.Section] {
        var byVolume: [String: [String]] = [:]
        for key in keys {
            let parts = key.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { continue }
            byVolume[String(parts[0]), default: []].append(String(parts[1]))
        }
        var sections: [WorkingCorpusDetail.Section] = []
        for volumeId in byVolume.keys.sorted() where onlyVolumes?.contains(volumeId) ?? true {
            let documentIds = byVolume[volumeId] ?? []
            let entry = resources.volume(volumeId)
            let indexed = served?.indexedVolumeIds.contains(volumeId) ?? false
            var titles: [String: String] = [:]
            var dates: [String: String] = [:]
            if indexed, let served {
                let wanted = Set(documentIds)
                for document in try await served.pipeline.documents(forVolume: volumeId) where wanted.contains(document.documentId) {
                    titles[document.documentId] = DocumentEntry(document, inIndex: true, dateISO: nil).displayTitle
                }
                dates = try await served.pipeline.datesByDocumentKey(documentIds.map { (volumeId: volumeId, documentId: $0) })
            }
            let earliest = entry?.dateRange.earliest
            func sortKey(_ id: String) -> String { dates["\(volumeId)/\(id)"] ?? earliest ?? "9999" }
            let ordered = documentIds.sorted { a, b in
                let (x, y) = (sortKey(a), sortKey(b))
                return x != y ? x < y : a < b
            }
            sections.append(.init(volumeId: volumeId, title: entry?.title, indexed: indexed, documents: ordered.map {
                .init(volumeId: volumeId, documentId: $0, displayTitle: titles[$0], dateISO: dates["\(volumeId)/\($0)"])
            }))
        }
        return sections
    }
}
