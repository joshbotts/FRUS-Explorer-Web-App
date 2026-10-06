// GET /api/v1/volumes and /api/v1/volumes/{volumeId}: the published catalogue, and what this server holds of it.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// What a count-bearing response counted over: the volumes and documents the live index holds,
/// beside the 553 volumes of the published catalogue (docs/SPEC.md, HTTP API > Conventions).
public struct Coverage: Codable, Equatable, Sendable {
    public var indexedVolumes: Int
    public var indexedDocuments: Int
    public var manifestVolumes: Int
    /// The live index's version; nil while no index is open.
    public var indexVersion: Int?

    public init(indexedVolumes: Int, indexedDocuments: Int, manifestVolumes: Int, indexVersion: Int?) {
        self.indexedVolumes = indexedVolumes
        self.indexedDocuments = indexedDocuments
        self.manifestVolumes = manifestVolumes
        self.indexVersion = indexVersion
    }

    init(index: CorpusIndex?, resources: ServerResources) {
        indexedVolumes = index?.summary.volumes ?? 0
        indexedDocuments = index?.summary.documents ?? 0
        manifestVolumes = resources.manifest.count
        indexVersion = index?.summary.indexVersion
    }
}

/// One volume: the draft's `VolumeManifestEntry` fields, written here rather than by the kit's
/// synthesized `Encodable`, which would add the app's `provenance`, plus what this server holds.
public struct Volume: Codable, Equatable, Sendable {
    public var volumeId: String
    public var filename: String
    public var subseries: String
    public var title: String
    public var dateRange: DateRange
    public var publicationDate: String?
    public var status: String
    public var editors: [String]
    public var generalEditor: String?
    public var sizeBytes: Int
    public var tags: [String]
    /// Whether the live index holds any of its documents.
    public var indexed: Bool
    /// How many of its documents the live index holds.
    public var indexedDocuments: Int
    /// Whether its TEI is in the mounted folder, so the reader can render it.
    public var teiAvailable: Bool

    init(_ entry: VolumeManifestEntry, index: CorpusIndex?, volumesDirectory: URL) {
        volumeId = entry.volumeId
        filename = entry.filename
        subseries = entry.subseries
        title = entry.title
        dateRange = entry.dateRange
        publicationDate = entry.publicationDate
        status = entry.status.rawValue
        editors = entry.editors
        generalEditor = entry.generalEditor
        sizeBytes = entry.sizeBytes
        tags = entry.tags
        indexedDocuments = index?.documentsByVolume[entry.volumeId] ?? 0
        indexed = indexedDocuments > 0
        teiAvailable = ReaderService.teiFile(for: entry.volumeId, in: volumesDirectory) != nil
    }
}

/// A page of volumes, in the manifest's order.
public struct VolumeList: Codable, Equatable, Sendable {
    public var total: Int
    public var limit: Int
    public var offset: Int
    public var items: [Volume]
    public var coverage: Coverage
}

extension Volume: ResponseEncodable {}
extension VolumeList: ResponseEncodable {}

enum CatalogRoutes {
    /// The draft's paging, with a larger page here, so one request can list all 553 volumes.
    static let maximumLimit = 1_000
    static let defaultLimit = 20

    static func add(to router: Router<BasicRequestContext>, state: ServerState, resources: ServerResources, volumesDirectory: URL) {
        router.get("/api/v1/volumes") { request, _ -> VolumeList in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["limit", "offset", "status", "subseries"])
            let limit = try query.integer("limit", in: 1...maximumLimit, default: defaultLimit)
            let offset = try query.integer("offset", in: 0...Int(Int32.max), default: 0)
            let status = try query.choice("status", among: [VolumeStatus.published, .partiallyPublished, .planned])
            let subseries = try query.single("subseries")
            let index = await state.index
            let matching = resources.manifest.filter {
                (status == nil || $0.status == status) && (subseries == nil || $0.subseries == subseries)
            }
            let page = matching.dropFirst(offset).prefix(limit)
            return VolumeList(total: matching.count, limit: limit, offset: offset,
                              items: page.map { Volume($0, index: index, volumesDirectory: volumesDirectory) },
                              coverage: Coverage(index: index, resources: resources))
        }
        router.get("/api/v1/volumes/:volumeId") { request, context -> Volume in
            try FormQuery(request.uri.query).refuseUnknown([])
            let volumeId = try context.parameters.require("volumeId")
            guard let entry = resources.volume(volumeId) else { throw APIProblem.volumeNotFound(volumeId) }
            return Volume(entry, index: await state.index, volumesDirectory: volumesDirectory)
        }
    }
}
