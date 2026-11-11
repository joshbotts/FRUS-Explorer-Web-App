// /api/v1/admin/library (PLAN's S21c): the admin's Library, every catalogue volume with its state, not
// downloaded, waiting, downloading, downloaded, indexing, indexed or failed, and its download, a job of
// the queue; and Remove, which takes a downloaded volume's file and figure images away. A Standalone
// server's: an Import server lists its TEI folder and the index, and downloads and removes nothing; a
// server under FRUS_OFFLINE downloads nothing. From S21d a Standalone server indexes what it keeps, in
// jobs of the queue, and Index asks for one. An admin's, behind `AdminRoutes`' guard.
//   GET    /api/v1/admin/library                       the volumes, with what this server may do
//   POST   /api/v1/admin/library/downloads             {"volumeIds": [...]} or {"all": true}: 202, with the job
//   POST   /api/v1/admin/library/index                 {"volumeIds": [...]} or {"all": true}: 202, with the job
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
    /// The library's indexing (PLAN's S21d): whether a job waits or runs, and the volume it indexes now.
    public var indexing: Indexing
    /// Every catalogue volume, in the catalogue's order.
    public var volumes: [Volume]

    public struct Volume: Codable, Equatable, Sendable {
        public var volumeId: String
        public var title: String
        public var subseries: String
        /// The catalogue's length of its file, in bytes.
        public var catalogueBytes: Int
        /// `notDownloaded`, `queued`, `downloading`, `downloaded`, `indexing`, `indexed` or `failed`: a download
        /// waiting or under way first, then one that failed, then its pass under way, then a pass that did
        /// not index it, then the index, then the file.
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
        /// Why its download failed, or what of it was left undone, or why its last pass did not index it.
        public var error: String?
        /// Its last pass, when it did not index the volume whose file is in place (PLAN's S21d).
        public var index: IndexPass?
        /// Who asked for its download; absent for the server itself.
        public var requestedBy: String?
    }

    /// Where the library's indexing stands.
    public struct Indexing: Codable, Equatable, Sendable {
        /// Whether an indexing job waits or runs.
        public var active: Bool
        /// The volume it indexes now.
        public var volume: String?
    }

    /// A volume's last pass, which did not index it: `failed`, for a reason of its own, and not tried again
    /// until Index asks or a download fetches it again; `stopped` by a cancel or a problem of the server's,
    /// which the next indexing takes again; or `interrupted` by a stop of the server, which Index finishes.
    public struct IndexPass: Codable, Equatable, Sendable {
        public var state: String
        /// Where it was, from the kit's progress stream: `starting`, `reading`, `storingDocuments` or
        /// `storingTables`; none for a pass a stop of the server cut short.
        public var stage: String?
        public var at: String?
    }
}

enum AdminLibraryRoutes {
    static func add(to admin: RouterGroup<APIRequestContext>, state: ServerState, resources: ServerResources,
                    library: VolumeLibrary?, indexer: LibraryIndexer?) {
        admin.get("library") { request, _ -> EditedResponse<AdminLibrary> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let library = try available(library)
            let indexed = await state.index?.documentsByVolume ?? [:]
            let indexing = await indexer?.status()
            // Off the cooperative pool: the store's rows, and a look at each volume's file.
            let (rows, sizes) = try await Blocking.run {
                (Dictionary(try library.libraryVolumes().map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first }),
                 Dictionary(resources.manifest.compactMap { entry in library.fileSize(entry.volumeId).map { (entry.volumeId, $0) } },
                            uniquingKeysWith: { first, _ in first }))
            }
            var counts: [String: Int] = [:]
            let volumes = resources.manifest.map { entry -> AdminLibrary.Volume in
                let row = rows[entry.volumeId]
                // A volume the job running has indexed is in the index it writes, served once the job ends.
                let isIndexed = (indexed[entry.volumeId] ?? 0) > 0 || indexing?.indexedSoFar.contains(entry.volumeId) == true
                let isDownloaded = sizes[entry.volumeId] != nil
                // A pass that did not index a volume whose file is in place: its record, or the kit's sentinel.
                let pass = isDownloaded ? Self.pass(entry.volumeId, indexing) : nil
                let status: String = switch row?.state {
                case .queued?: "queued"
                case .downloading?: "downloading"
                case .failed?: "failed"
                default:
                    indexing?.indexing == entry.volumeId && isDownloaded ? "indexing"
                        : pass != nil ? "failed" : isIndexed ? "indexed" : isDownloaded ? "downloaded" : "notDownloaded"
                }
                counts[status, default: 0] += 1
                // What the row says of a file, while the file is there.
                let file = isDownloaded ? row : nil
                return AdminLibrary.Volume(
                    volumeId: entry.volumeId, title: entry.title, subseries: entry.subseries, catalogueBytes: entry.sizeBytes,
                    status: status, downloaded: isDownloaded, indexed: isIndexed, sideloaded: file?.sideloaded ?? false,
                    bytes: sizes[entry.volumeId], blobSha: file?.blobSHA, downloadedAt: file?.downloadedAt.map(UserStoreDate.text),
                    figures: file?.figuresStored, figuresRefused: file?.figuresRefused,
                    error: row?.state == .failed || row?.isUnfinished == true ? row?.error : pass?.sentence ?? row?.error,
                    index: row?.state == .failed || row?.isUnfinished == true ? nil : pass?.pass,
                    requestedBy: row?.isUnfinished == true ? row?.requestedBy : nil)
            }
            let refusal = library.downloadsRefusal
            let body = AdminLibrary(
                mode: library.mode.rawValue, offline: library.offline, downloads: refusal == nil,
                unavailable: refusal.map(sentence), source: library.sources.isGitHub ? "github" : "mirror",
                counts: counts, indexing: .init(active: indexing?.jobActive ?? false, volume: indexing?.indexing),
                volumes: volumes)
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
            // A file the served index was made from is not replaced until the corrections check and the
            // review of what a correction touched come (PLAN's S21f).
            if case .volumes(let ids) = wanted, library.downloadsRefusal == nil {
                let indexed = await state.index?.documentsByVolume ?? [:]
                if let held = ids.first(where: { (indexed[$0] ?? 0) > 0 && library.isVolumeDownloaded($0) }) {
                    throw APIProblem(.conflict, code: "VOLUME_INDEXED",
                                     detail: "\(held) is in the served index, which was made from the file in place: a corrected file replaces it with the corrections check, which comes later.")
                }
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

        // 202 with the indexing's job, and its address (PLAN's S21d).
        admin.post("library/index") { request, context -> EditedResponse<AdminJob> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let library = try available(library)
            let body = try await JSONBody.decode(DownloadRequest.self, from: request, fields: ["volumeIds", "all"])
            guard let indexer, library.mode == .standalone else { throw problem(.importMode) }
            let indexed = await state.index?.documentsByVolume ?? [:]
            let indexing = await indexer.status()
            // What Index takes: a volume whose file is in place, and which the index lacks, or holds from a
            // pass that did not finish. One indexed whole is indexed again with the corrections check and the
            // upgrade, which come later (PLAN's S21e and S21f).
            func waits(_ id: String) -> Bool {
                library.isVolumeDownloaded(id) && ((indexed[id] ?? 0) == 0 || Self.pass(id, indexing) != nil)
            }
            let wanted: LibraryIndexer.Request
            switch (body.volumeIds, body.all) {
            case (nil, true?):
                guard resources.manifest.contains(where: { waits($0.volumeId) }) else {
                    throw APIProblem(.conflict, code: "NOTHING_TO_INDEX",
                                     detail: "Every volume in the library is indexed already, or waits for its download.")
                }
                wanted = .asked(nil)
            case (let ids?, nil) where !ids.isEmpty && ids.count <= resources.manifest.count:
                for id in ids {
                    guard resources.volume(id) != nil else { throw APIProblem.volumeNotFound(id) }
                    guard library.isVolumeDownloaded(id) else { throw problem(.notDownloaded(id)) }
                    guard waits(id) else {
                        throw APIProblem(.conflict, code: "VOLUME_INDEXED",
                                         detail: "\(id) is in the served index already: a volume indexed whole is indexed again with the corrections check and the upgrade, which come later.")
                    }
                }
                wanted = .asked(ids)
            default:
                throw APIProblem(.badRequest, code: "INVALID_FIELD",
                                 detail: "volumeIds: one catalogue volume's id or more, at most \(resources.manifest.count); or all: true, alone.")
            }
            let job: Job
            do {
                job = try await indexer.index(wanted, requestedBy: user.id)
            } catch let refusal as LibraryIndexingRefusal where refusal == .importMode {
                throw problem(.importMode)
            } catch {
                throw APIProblem(.serviceUnavailable, code: "JOB_NOT_QUEUED",
                                 detail: "The indexing could not be queued, since the server could not keep its job: try again in a moment.")
            }
            context.logger.info("\(user.id) asked for the indexing of \(job.subject ?? "volumes"), as job \(job.id)")
            let location = context.basePath.prefixing("/api/v1/admin/jobs/\(job.id)")
            return EditedResponse(status: .accepted, headers: [.location: location, .cacheControl: "no-store"], response: AdminJob(job))
        }

        admin.delete("library/volumes/:volumeId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let library = try available(library)
            let volumeId = try context.parameters.require("volumeId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            guard library.mode == .standalone else { throw problem(.importMode) }
            if (await state.index?.documentsByVolume[volumeId] ?? 0) > 0 {
                throw APIProblem(.conflict, code: "VOLUME_INDEXED",
                                 detail: "\(volumeId) is in the served index, and the reader renders its documents from this file: a volume leaves the index with the library's indexing, which comes later.")
            }
            if await indexer?.holds(volumeId) == true {
                throw APIProblem(.conflict, code: "INDEXING_IN_PROGRESS",
                                 detail: "An indexing job may index \(volumeId), which waits or runs: remove it once the job has ended.")
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

    /// What a volume's last pass left, when it did not index it: its record, or the kit's sentinel's word
    /// that a stop of the server cut it short; nil for a volume indexed, or never begun.
    static func pass(_ volumeId: String, _ indexing: LibraryIndexingStatus?) -> (pass: AdminLibrary.IndexPass, sentence: String)? {
        guard let indexing, indexing.indexing != volumeId else { return nil }
        if let record = indexing.failures[volumeId] {
            return (AdminLibrary.IndexPass(state: record.kind.rawValue, stage: record.stage, at: UserStoreDate.text(record.at)),
                    record.sentence)
        }
        if indexing.interrupted.contains(volumeId) {
            return (AdminLibrary.IndexPass(state: "interrupted", stage: nil, at: nil),
                    "A stop of the server cut its pass short: Index finishes it.")
        }
        return nil
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
        case .nothingToDownload(let all):
            all ? "Every catalogue volume is downloaded already, or waits for a download."
                : "Each volume asked for waits for a download already."
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
