// /api/v1/admin/library (PLAN's S21c): the admin's Library, every catalogue volume with its state, not
// downloaded, waiting, downloading, downloaded, indexing, indexed or failed, and its download, a job of
// the queue; and Remove, which takes a downloaded volume's file and figure images away. A Standalone
// server's: an Import server lists its TEI folder and the index, and downloads and removes nothing; a
// server under FRUS_OFFLINE downloads nothing. From S21d a Standalone server indexes what it keeps, in
// jobs of the queue, and Index asks for one. From S21e an admin side-loads a volume's file, which the
// catalogue overlay lists when the catalogue does not, and Remove takes an indexed volume out of the index
// first, in a job. An admin's, behind `AdminRoutes`' guard.
//   GET    /api/v1/admin/library                       the volumes, with what this server may do
//   POST   /api/v1/admin/library/downloads             {"volumeIds": [...]} or {"all": true}: 202, with the job
//   POST   /api/v1/admin/library/index                 {"volumeIds": [...]} or {"all": true}: 202, with the job
//   POST   /api/v1/admin/library/sideload?file=<name>  the volume's XML: 202, with its indexing's job
//   DELETE /api/v1/admin/library/volumes/{volumeId}    204, or 202 with the removal's job for an indexed volume

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
    /// The volumes a removal waits or runs for (PLAN's S21e).
    public var removing: [String]
    /// Every catalogue volume, in the catalogue's order, then each volume side-loaded under an id the
    /// catalogue lacks, by id (PLAN's S21e).
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
        /// Whether the published catalogue lists it, so that it can be downloaded: false for a volume side-loaded
        /// under an id the catalogue lacks (PLAN's S21e).
        public var catalogued: Bool
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
        /// The upgrade a start began, while volumes of it are still to be re-indexed (PLAN's S21e).
        public var upgrade: IndexUpgradeStatus?

        public init(active: Bool, volume: String?, upgrade: IndexUpgradeStatus? = nil) {
            self.active = active
            self.volume = volume
            self.upgrade = upgrade
        }
    }

    /// What `POST /api/v1/admin/library/sideload` answers (PLAN's S21e): the volume, whether the published
    /// catalogue lists it, and its indexing's job.
    public struct Sideload: Codable, Equatable, Sendable, ResponseEncodable {
        public var volumeId: String
        public var catalogued: Bool
        public var job: AdminJob
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
    static func add(to admin: RouterGroup<APIRequestContext>, sideloads: RouterGroup<APIRequestContext>, state: ServerState,
                    resources: ServerResources, library: VolumeLibrary?, indexer: LibraryIndexer?) {
        admin.get("library") { request, _ -> EditedResponse<AdminLibrary> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let library = try available(library)
            let indexed = await state.index?.documentsByVolume ?? [:]
            let indexing = await indexer?.status()
            let upgrade = await state.upgrade
            // The catalogue's volumes, then those side-loaded under an id it lacks (PLAN's S21e), in Standalone mode.
            let entries = resources.manifest + (library.mode == .standalone ? resources.localVolumes : [])
            // Off the cooperative pool: the store's rows, and a look at each volume's file.
            let (rows, sizes) = try await Blocking.run {
                (Dictionary(try library.libraryVolumes().map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first }),
                 Dictionary(entries.compactMap { entry in library.fileSize(entry.volumeId).map { (entry.volumeId, $0) } },
                            uniquingKeysWith: { first, _ in first }))
            }
            var counts: [String: Int] = [:]
            let volumes = entries.map { entry -> AdminLibrary.Volume in
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
                    status: status, downloaded: isDownloaded, indexed: isIndexed,
                    sideloaded: file?.sideloaded ?? false || (isDownloaded && entry.provenance == .sideloaded),
                    catalogued: entry.provenance != .sideloaded,
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
                counts: counts, indexing: .init(active: indexing?.jobActive ?? false, volume: indexing?.indexing, upgrade: upgrade),
                removing: (await indexer?.removing() ?? []).sorted(), volumes: volumes)
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
            // A volume whose removal waits or runs is not downloaded meanwhile (PLAN's S21e).
            if case .volumes(let ids) = wanted, let indexer {
                for id in ids where await indexer.isRemoving(id) { throw Self.removalInProgress(id) }
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
            // pass that did not finish. One indexed whole is indexed again by an upgrade's pass over every volume
            // (PLAN's S21e) and with the corrections check, which comes later (PLAN's S21f).
            func waits(_ id: String) -> Bool {
                library.isVolumeDownloaded(id) && ((indexed[id] ?? 0) == 0 || Self.pass(id, indexing) != nil)
            }
            let wanted: LibraryIndexer.Request
            switch (body.volumeIds, body.all) {
            case (nil, true?):
                guard (resources.manifest + resources.localVolumes).contains(where: { waits($0.volumeId) }) else {
                    throw APIProblem(.conflict, code: "NOTHING_TO_INDEX",
                                     detail: "Every volume in the library is indexed already, or waits for its download.")
                }
                wanted = .asked(nil)
            case (let ids?, nil) where !ids.isEmpty && ids.count <= resources.manifest.count:
                for id in ids {
                    guard resources.volume(id) != nil else { throw APIProblem.volumeNotFound(id) }
                    if await indexer.isRemoving(id) { throw Self.removalInProgress(id) }
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
            if await indexer?.holds(volumeId) == true {
                throw APIProblem(.conflict, code: "INDEXING_IN_PROGRESS",
                                 detail: "An indexing job may index \(volumeId), which waits or runs: remove it once the job has ended.")
            }
            if let indexer, await indexer.isRemoving(volumeId) { throw Self.removalInProgress(volumeId) }
            // A volume the index holds leaves it first, in a job, the index's one writer, and then its files (PLAN's S21e).
            if (await state.index?.documentsByVolume[volumeId] ?? 0) > 0, let indexer {
                if let row = try? await Blocking.run({ try library.libraryVolumes().first { $0.volumeId == volumeId } }), row.isUnfinished {
                    throw problem(.inProgress(volumeId))
                }
                let job: Job
                do {
                    job = try await indexer.remove(volumeId, requestedBy: user.id) { id in
                        do {
                            try await library.remove(id)
                        } catch LibraryRefusal.notDownloaded, LibraryRefusal.unknownVolume {
                            // The index held it with no file in the library, as a volume of a seeding export can.
                        }
                        await resources.refreshLocalVolumes(in: library.volumesDirectory)
                    }
                } catch LibraryIndexingRefusal.removalInProgress(let id) {
                    throw Self.removalInProgress(id)
                } catch {
                    throw APIProblem(.serviceUnavailable, code: "JOB_NOT_QUEUED",
                                     detail: "The removal could not be queued, since the server could not keep its job: try again in a moment.")
                }
                context.logger.info("\(user.id) asked for the removal of \(volumeId) from the index and the library, as job \(job.id)")
                let location = context.basePath.prefixing("/api/v1/admin/jobs/\(job.id)")
                return try EditedResponse(status: .accepted, headers: [.location: location, .cacheControl: "no-store"], response: AdminJob(job))
                    .response(from: request, context: context)
            }
            do {
                try await library.remove(volumeId)
            } catch let refusal as LibraryRefusal {
                throw problem(refusal)
            }
            await resources.refreshLocalVolumes(in: library.volumesDirectory)
            context.logger.info("\(user.id) removed \(volumeId) from the library")
            return Response(status: .noContent, headers: [.cacheControl: "no-store"])
        }

        // A volume's file, side-loaded (PLAN's S21e): XML of 64 MiB at most, in a group of its own, whose guard
        // takes it; refused if the volume exists; checked by the kit's validator; then indexed, in a job.
        sideloads.post("library/sideload") { request, context -> EditedResponse<AdminLibrary.Sideload> in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["file"])
            let user = try context.requireUser()
            let library = try available(library)
            guard library.mode == .standalone, let indexer else { throw problem(.importMode) }
            guard let name = try query.single("file"), let volumeId = VolumeLibrary.sideloadedVolumeId(fromFileName: name) else {
                throw APIProblem(.badRequest, code: "INVALID_FILE_NAME",
                                 detail: "file: the volume's file name, <volume id>.xml, its id of letters, digits, '.', '_' and '-', beginning with a letter or a digit, of 128 characters at most.")
            }
            if (await state.index?.documentsByVolume[volumeId] ?? 0) > 0 || library.isVolumeDownloaded(volumeId) {
                throw Self.exists(volumeId, SideloadError.duplicateVolume(volumeId: volumeId).errorDescription)
            }
            if await indexer.isRemoving(volumeId) { throw Self.removalInProgress(volumeId) }
            let staged = try library.sideloadStaging(for: volumeId)
            do {
                try await Self.write(request.body, to: staged, limit: VolumeLibrary.sideloadLimit)
                _ = try await library.sideload(staged: staged, requestedBy: user.id)
            } catch let refusal as VolumeLibrary.SideloadRefusal {
                try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
                switch refusal {
                case .importMode: throw problem(.importMode)
                case .exists(let id, let sentence): throw Self.exists(id, sentence)
                case .notAVolume(let sentence): throw APIProblem(.unprocessableContent, code: "NOT_A_VOLUME", detail: sentence)
                case .noRoom(let sentence): throw APIProblem(.init(code: 507, reasonPhrase: "Insufficient Storage"), code: "NOT_ENOUGH_ROOM", detail: sentence)
                }
            } catch {
                try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
                throw error
            }
            await resources.refreshLocalVolumes(in: library.volumesDirectory)
            let job: Job
            do {
                job = try await indexer.index(.asked([volumeId]), requestedBy: user.id)
            } catch {
                throw APIProblem(.serviceUnavailable, code: "JOB_NOT_QUEUED",
                                 detail: "\(volumeId) was side-loaded, and its indexing could not be queued, since the server could not keep its job: Index asks again.")
            }
            context.logger.info("\(user.id) side-loaded \(volumeId), indexed in job \(job.id)")
            let location = context.basePath.prefixing("/api/v1/admin/jobs/\(job.id)")
            return EditedResponse(status: .accepted, headers: [.location: location, .cacheControl: "no-store"],
                                  response: AdminLibrary.Sideload(volumeId: volumeId, catalogued: resources.manifest.contains { $0.volumeId == volumeId },
                                                                  job: AdminJob(job)))
        }
    }

    /// A volume of that id exists, in the kit's sentence for a duplicate side-load, or the server's.
    static func exists(_ volumeId: String, _ sentence: String?) -> APIProblem {
        APIProblem(.conflict, code: "VOLUME_EXISTS", detail: sentence ?? "\(volumeId) is in the library already.")
    }

    /// A removal waits or runs for the volume (PLAN's S21e).
    static func removalInProgress(_ volumeId: String) -> APIProblem {
        APIProblem(.conflict, code: "REMOVAL_IN_PROGRESS", detail: "\(volumeId) is being removed from the index and the library, in a job that waits or runs.")
    }

    /// Writes a request's body to `file` as it comes, refusing it past `limit` bytes, which its length
    /// header, when it has one, the group's guard has refused already.
    static func write(_ body: RequestBody, to file: URL, limit: Int) async throws {
        guard FileManager.default.createFile(atPath: file.path, contents: nil) else {
            throw APIProblem(.internalServerError, code: "INTERNAL_ERROR", detail: "The server could not write the file it was sent.")
        }
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        var written = 0
        for try await buffer in body {
            written += buffer.readableBytes
            guard written <= limit else { throw JSONBody.tooLarge(limit) }
            try handle.write(contentsOf: Data(buffer: buffer))
        }
        guard written > 0 else {
            throw APIProblem(.badRequest, code: "INVALID_BODY", detail: "The body must be the volume's XML file.")
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
