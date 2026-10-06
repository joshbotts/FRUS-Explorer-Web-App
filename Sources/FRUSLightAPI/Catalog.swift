// The catalogue and browsing: GET /api/v1/volumes, /volumes/{v}, /volumes/{v}/documents and
// /volumes/{v}/documents/{d}. The catalogue is the published one, from the manifest, and works with
// no index; a volume's documents come from the index, through the kit's read-only stack.

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
    /// Its front matter, chapters and back matter as the index holds them, on `/volumes/{v}`
    /// alone, when the index holds the volume.
    public var structure: [Section]?

    /// A section of a volume: its divisions, in source order, with the documents directly in it.
    public struct Section: Codable, Equatable, Sendable {
        public var sectionId: String
        public var divType: String
        public var title: String
        public var documentIds: [String]
        public var subsections: [Section]

        init(_ section: VolumeSection) {
            sectionId = section.sectionId
            divType = section.divType
            title = section.title
            documentIds = section.documentIds
            subsections = section.subsections.map(Section.init)
        }
    }

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

    static func add(to router: Router<BasicRequestContext>, state: ServerState, provider: ServedIndexProvider,
                    resources: ServerResources, volumesDirectory: URL) {
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
            var volume = Volume(entry, index: await state.index, volumesDirectory: volumesDirectory)
            if volume.indexed, let served = try await provider.servedIfReady(),
               let structure = try await served.pipeline.cachedVolumeStructure(forVolumeId: volumeId) {
                volume.structure = structure.sections.map(Volume.Section.init)
            }
            return volume
        }
        router.get("/api/v1/volumes/:volumeId/documents") { request, context -> DocumentList in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["limit", "offset"])
            let limit = try query.integer("limit", in: 1...maximumLimit, default: defaultLimit)
            let offset = try query.integer("offset", in: 0...Int(Int32.max), default: 0)
            let volumeId = try context.parameters.require("volumeId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            let served = try await provider.served()
            let browse = try await VolumeBrowse(volumeId, served: served)
            let page = Array(browse.sequence.dropFirst(offset).prefix(limit))
            let dates = try await served.pipeline.datesByDocumentKey(
                page.filter { browse.indexed.contains($0.documentId) }.map { (volumeId: volumeId, documentId: $0.documentId) })
            return DocumentList(total: browse.sequence.count, limit: limit, offset: offset,
                                items: page.map { DocumentEntry($0, inIndex: browse.indexed.contains($0.documentId),
                                                                dateISO: dates["\(volumeId)/\($0.documentId)"]) },
                                coverage: Coverage(index: served.corpus, resources: resources))
        }
        router.get("/api/v1/volumes/:volumeId/documents/:documentId") { request, context -> DocumentDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let volumeId = try context.parameters.require("volumeId")
            let documentId = try context.parameters.require("documentId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            let served = try await provider.served()
            guard let entry = try await served.pipeline.document(forDocumentId: documentId, inVolume: volumeId) else {
                throw APIProblem(.notFound, code: "DOCUMENT_NOT_FOUND", detail: "The index holds no document \(documentId) in \(volumeId).")
            }
            let browse = try await VolumeBrowse(volumeId, served: served)
            let position = browse.sequence.firstIndex { $0.documentId == entry.documentId }
            func neighbour(_ offset: Int) -> DocumentDetail.Neighbour? {
                guard let position, browse.sequence.indices.contains(position + offset) else { return nil }
                let other = browse.sequence[position + offset]
                return DocumentDetail.Neighbour(documentId: other.documentId, header: other.header,
                                                inIndex: browse.indexed.contains(other.documentId))
            }
            let date = try await served.pipeline.datesByDocumentKey([(volumeId: volumeId, documentId: entry.documentId)])
            let classification = try await served.pipeline.effectiveIsEditorialNote(volumeId: volumeId, documentId: entry.documentId)
            var document = DocumentEntry(entry, inIndex: true, dateISO: date["\(volumeId)/\(entry.documentId)"])
            document.isEditorialNote = classification ?? entry.isEditorialNote
            return DocumentDetail(document: document,
                                  canonicalURL: FRUSCanonicalURL.string(volumeId: volumeId, documentId: entry.documentId),
                                  previous: neighbour(-1), next: neighbour(1),
                                  teiAvailable: ReaderService.teiFile(for: volumeId, in: volumesDirectory) != nil)
        }
    }
}

/// A volume's reading order, from the index: its front matter, documents and back matter as
/// `readingSequence(forVolume:)` walks its structure, and which of them the index holds.
struct VolumeBrowse {
    let sequence: [DocumentBrowserEntry]
    let indexed: Set<String>

    init(_ volumeId: String, served: ServedIndex) async throws {
        sequence = try await served.pipeline.readingSequence(forVolume: volumeId)
        indexed = Set(try await served.pipeline.documents(forVolume: volumeId).map(\.documentId))
    }
}

/// A document in a volume's list: the draft's `DocumentBrowserEntry`, and whether the index holds
/// it. An entry the index does not hold, such as a front-matter section, comes from the volume's
/// structure and has no number, dateline or source note.
public struct DocumentEntry: Codable, Equatable, Sendable {
    public var documentId: String
    public var volumeId: String
    public var documentNumber: String?
    public var header: String
    public var dateline: String?
    public var sourceNote: String?
    public var dateISO: String?
    public var isEditorialNote: Bool
    public var inIndex: Bool

    init(_ entry: DocumentBrowserEntry, inIndex: Bool, dateISO: String?) {
        documentId = entry.documentId
        volumeId = entry.volumeId
        documentNumber = entry.documentNumber
        header = entry.header
        dateline = entry.dateline
        sourceNote = entry.sourceNote
        self.dateISO = dateISO
        isEditorialNote = entry.isEditorialNote
        self.inIndex = inIndex
    }
}

/// A page of a volume's documents, in reading order.
public struct DocumentList: Codable, Equatable, Sendable {
    public var total: Int
    public var limit: Int
    public var offset: Int
    public var items: [DocumentEntry]
    public var coverage: Coverage
}

/// One document's metadata, in place of the draft's render model, which the kit cannot encode: the
/// reader's HTML is `…/html`. `isEditorialNote` is the index's effective classification, which the
/// owner's corrections keep current.
public struct DocumentDetail: Codable, Equatable, Sendable {
    public struct Neighbour: Codable, Equatable, Sendable {
        public var documentId: String
        public var header: String
        public var inIndex: Bool
    }

    public var document: DocumentEntry
    /// The document's page on history.state.gov.
    public var canonicalURL: String
    /// The entries before and after it in the volume's reading order.
    public var previous: Neighbour?
    public var next: Neighbour?
    public var teiAvailable: Bool
}

extension DocumentList: ResponseEncodable {}
extension DocumentDetail: ResponseEncodable {}
