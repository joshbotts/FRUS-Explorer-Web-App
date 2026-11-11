// /api/v1/admin/library (PLAN's S21c): the admin's Library, every catalogue volume with its state, not
// downloaded, waiting, downloading, downloaded, indexed or failed, and its download, a job of the queue;
// and Remove, which takes a downloaded volume's file and figure images away. A Standalone server's: an
// Import server lists its TEI folder and the index, and downloads and removes nothing; a server under
// FRUS_OFFLINE downloads nothing. An admin's, behind `AdminRoutes`' guard.
//   GET    /api/v1/admin/library                       the volumes, with what this server may do
//   POST   /api/v1/admin/library/downloads             {"volumeIds": [...]} or {"all": true}: 202, with the job
//   DELETE /api/v1/admin/library/volumes/{volumeId}    204

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// `GET /api/v1/admin/library`.
public struct AdminLibrary: Codable, Equatable, Sendable, ResponseEncodable {
    /// `import` or `standalone`.
    public var mode: String
    /// `FRUS_OFFLINE`.
    public var offline: Bool
    /// Whether this server downloads: in Standalone mode, and not offline.
    public var downloads: Bool
    /// Why it downloads nothing, in the server's words; absent when it downloads.
    public var unavailable: String?
    /// Where it downloads from: `github`, GitHub and history.state.gov, or `mirror`, the operator's.
    public var source: String
    /// How many volumes are in each `status`.
    public var counts: [String: Int]
    /// Every catalogue volume, in the catalogue's order.
    public var volumes: [Volume]

    public struct Volume: Codable, Equatable, Sendable {
        public var volumeId: String
        public var title: String
        public var subseries: String
        /// The catalogue's length of its file, in bytes.
        public var catalogueBytes: Int
        /// `notDownloaded`, `queued`, `downloading`, `downloaded`, `indexed` or `failed`: a download waiting or
        /// under way first, then one that failed, then the index, then the file.
        public var status: String
        /// Whether its file is in the volumes folder.
        public var downloaded: Bool
        /// Whether the served index holds it.
        public var indexed: Bool
        public var sideloaded: Bool
        /// The file's length and git blob SHA-1, checked against GitHub's listing, and when it was downloaded.
        public var bytes: Int?
        public var blobSha: String?
        public var downloadedAt: String?
        /// The figure images beside it, and the names the image host refused.
        public var figures: Int?
        public var figuresRefused: Int?
        /// Why its download failed, or what of it was left undone.
        public var error: String?
        /// Who asked for its download; absent for the server itself.
        public var requestedBy: String?
    }
}

enum AdminLibraryRoutes {
    static func add(to admin: RouterGroup<APIRequestContext>, state: ServerState, resources: ServerResources,
                    library: VolumeLibrary?) {
        admin.get("library") { request, _ -> EditedResponse<AdminLibrary> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let library = try available(library)
            let indexed = await state.index?.documentsByVolume ?? [:]
            // Off the cooperative pool: the store's rows, and a look at each volume's file.
            let (rows, present) = try await Blocking.run {
                (Dictionary(try library.libraryVolumes().map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first }),
                 Set(resources.manifest.map(\.volumeId).filter(library.isVolumeDownloaded)))
            }
            var counts: [String: Int] = [:]
            let volumes = resources.manifest.map { entry -> AdminLibrary.Volume in
                let row = rows[entry.volumeId]
                let isIndexed = (indexed[entry.volumeId] ?? 0) > 0
                let isDownloaded = present.contains(entry.volumeId)
                let status: String = switch row?.state {
                case .queued?: "queued"
                case .downloading?: "downloading"
                case .failed?: "failed"
                default: isIndexed ? "indexed" : isDownloaded ? "downloaded" : "notDownloaded"
                }
                counts[status, default: 0] += 1
                // What the row says of a file, while the file is there.
                let file = isDownloaded ? row : nil
                return AdminLibrary.Volume(
                    volumeId: entry.volumeId, title: entry.title, subseries: entry.subseries, catalogueBytes: entry.sizeBytes,
                    status: status, downloaded: isDownloaded, indexed: isIndexed, sideloaded: file?.sideloaded ?? false,
                    bytes: file?.sizeBytes, blobSha: file?.blobSHA, downloadedAt: file?.downloadedAt.map(UserStoreDate.text),
                    figures: file?.figuresStored, figuresRefused: file?.figuresRefused, error: row?.error,
                    requestedBy: row?.isUnfinished == true ? row?.requestedBy : nil)
            }
            let refusal = library.downloadsRefusal
            let body = AdminLibrary(
                mode: library.mode.rawValue, offline: refusal == .offline, downloads: refusal == nil,
                unavailable: refusal.map(sentence), source: library.sources.isGitHub ? "github" : "mirror",
                counts: counts, volumes: volumes)
            return EditedResponse(headers: [.cacheControl: "no-store"], response: body)
        }

        // 202 with the download's job, and its address.
        admin.post("library/downloads") { request, context -> EditedResponse<AdminJob> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let library = try available(library)
            let body = try await JSONBody.decode(DownloadRequest.self, from: request, fields: ["volumeIds", "all"])
            let wanted: VolumeLibrary.DownloadRequest
            switch (body.volumeIds, body.all) {
            case (nil, true?):
                wanted = .all
            case (let ids?, nil) where !ids.isEmpty && ids.count <= resources.manifest.count:
                wanted = .volumes(ids)
            default:
                throw APIProblem(.badRequest, code: "INVALID_FIELD",
                                 detail: "volumeIds: one catalogue volume's id or more, at most \(resources.manifest.count); or all: true, alone.")
            }
            let job: Job
            do {
                job = try await library.download(wanted, requestedBy: user.id)
            } catch let refusal as LibraryRefusal {
                throw problem(refusal)
            } catch {
                throw APIProblem(.serviceUnavailable, code: "JOB_NOT_QUEUED",
                                 detail: "The download could not be queued, since the server could not keep its job: try again in a moment.")
            }
            context.logger.info("\(user.id) asked for the download of \(job.subject ?? "volumes"), as job \(job.id)")
            let location = context.basePath.prefixing("/api/v1/admin/jobs/\(job.id)")
            return EditedResponse(status: .accepted, headers: [.location: location, .cacheControl: "no-store"], response: AdminJob(job))
        }

        admin.delete("library/volumes/:volumeId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let library = try available(library)
            let volumeId = try context.parameters.require("volumeId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            if (await state.index?.documentsByVolume[volumeId] ?? 0) > 0 {
                throw APIProblem(.conflict, code: "VOLUME_INDEXED",
                                 detail: "\(volumeId) is in the served index, and the reader renders its documents from this file: a volume leaves the index with the library's indexing, which comes later.")
            }
            do {
                try await library.remove(volumeId)
            } catch let refusal as LibraryRefusal {
                throw problem(refusal)
            }
            context.logger.info("\(user.id) removed \(volumeId) from the library")
            return Response(status: .noContent, headers: [.cacheControl: "no-store"])
        }
    }

    /// `POST /api/v1/admin/library/downloads`'s body.
    struct DownloadRequest: Decodable {
        let volumeIds: [String]?
        let all: Bool?
    }

    /// The library, which every server builds; a router built without one, as some tests', has none.
    private static func available(_ library: VolumeLibrary?) throws -> VolumeLibrary {
        guard let library else {
            throw APIProblem(.serviceUnavailable, code: "LIBRARY_NOT_AVAILABLE", detail: "This server holds no library.")
        }
        return library
    }

    /// Why this server downloads nothing, in its words.
    static func sentence(_ refusal: LibraryRefusal) -> String {
        switch refusal {
        case .importMode:
            "An Import server reads the TEI folder mounted at /data/volumes, and downloads nothing into it: the library downloads in Standalone mode (FRUS_MODE=standalone)."
        case .offline:
            "This server makes no request outside (FRUS_OFFLINE=true), so it downloads nothing."
        case .unknownVolume(let id):
            "The catalogue has no volume \(id)."
        case .inProgress(let id):
            "A download of \(id) is queued or under way."
        case .nothingToDownload:
            "Every volume asked for is downloaded already, or waits for a download."
        case .notDownloaded(let id):
            "\(id) is not in the library."
        }
    }

    static func problem(_ refusal: LibraryRefusal) -> APIProblem {
        switch refusal {
        case .importMode: APIProblem(.conflict, code: "LIBRARY_NOT_AVAILABLE", detail: sentence(refusal))
        case .offline: APIProblem(.conflict, code: "OFFLINE", detail: sentence(refusal))
        case .unknownVolume(let id): APIProblem.volumeNotFound(id)
        case .inProgress: APIProblem(.conflict, code: "DOWNLOAD_IN_PROGRESS", detail: sentence(refusal))
        case .nothingToDownload: APIProblem(.conflict, code: "NOTHING_TO_DOWNLOAD", detail: sentence(refusal))
        case .notDownloaded: APIProblem(.notFound, code: "VOLUME_NOT_DOWNLOADED", detail: sentence(refusal))
        }
    }
}
