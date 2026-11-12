// /api/v1/admin/index (PLAN's S21e): a Standalone server's index, its room and the upkeep an admin asks
// for, each a job of the queue, the index's one writer: Compact, the kit's `vacuumIndex()` once the data
// volume has the room the app's rule asks, and Check, the kit's `checkIndexIntegrity()`. Standalone's reset,
// which empties the index and indexes the library again, is `POST /api/v1/admin/index/reset`, Import mode's
// route (AdminStatus.swift). An admin's, behind `AdminRoutes`' guard.
//   GET  /api/v1/admin/index            the index's room, and whether compacting it is worth it and fits
//   POST /api/v1/admin/index/compact    202, with the job
//   POST /api/v1/admin/index/check      202, with the job

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// `GET /api/v1/admin/index`.
public struct AdminIndex: Codable, Equatable, Sendable, ResponseEncodable {
    /// `import` or `standalone`.
    public var mode: String
    /// Whether this server compacts and checks its index: a Standalone server's, while it serves one.
    public var upkeep: Bool
    /// The index's room, by the kit's `indexPageStatistics()`: absent while none is served, and in Import mode.
    public var storage: Storage?
    /// The upgrade a start began, while volumes of it are still to be re-indexed.
    public var upgrade: IndexUpgradeStatus?

    public struct Storage: Codable, Equatable, Sendable {
        /// The file, the data in it, and the room a compaction would give back, in bytes.
        public var fileBytes: Int
        public var liveBytes: Int
        public var reclaimableBytes: Int
        /// The free room on the data volume, and what this server's compaction needs of it, for its copy and its
        /// log (`IndexCompactionRule.serverRequired`).
        public var availableBytes: Int?
        public var requiredBytes: Int
        /// `insufficientSpace` while the data volume has less than that; otherwise the app's word, whether a
        /// compaction is worth offering, `available` once 200 MB or more could be reclaimed, else `notWorthwhile`.
        public var compaction: String
    }
}

enum AdminIndexRoutes {
    static func add(to admin: RouterGroup<APIRequestContext>, services: UserDataServices, state: ServerState,
                    indexer: LibraryIndexer?, provider: ServedIndexProvider?) {
        let files = DataDirectory(root: state.configuration.dataDirectory)

        admin.get("index") { request, _ -> EditedResponse<AdminIndex> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let standalone = state.configuration.mode == .standalone && indexer != nil
            var storage: AdminIndex.Storage?
            if standalone, let served = try? await provider?.servedIfReady(),
               let statistics = try? await served.pipeline.indexPageStatistics() {
                let available = (try? files.availableCapacity()).map { Int($0) }
                let required = IndexCompactionRule.serverRequired(statistics)
                let compaction = if let available, Int64(available) < required {
                    "insufficientSpace"
                } else {
                    switch IndexCompactionRule.availability(statistics: statistics, availableBytes: Int(required)) {
                    case .notWorthwhile: "notWorthwhile"
                    case .insufficientSpace, .available: "available"
                    }
                }
                storage = .init(fileBytes: statistics.fileBytes, liveBytes: statistics.liveBytes,
                                reclaimableBytes: statistics.reclaimableBytes, availableBytes: available,
                                requiredBytes: Int(required), compaction: compaction)
            }
            let body = AdminIndex(mode: state.configuration.mode.rawValue, upkeep: standalone && storage != nil,
                                  storage: storage, upgrade: await state.upgrade)
            return EditedResponse(headers: [.cacheControl: "no-store"], response: body)
        }

        admin.post("index/compact") { request, context -> EditedResponse<AdminJob> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let indexer = try standalone(state, indexer)
            guard let served = try await provider?.servedIfReady() else { throw noIndex(await state.readiness()) }
            // The room this server's compaction needs, before the job is queued; the job asks again before it holds the index.
            if let statistics = try await served.pipeline.indexPageStatistics(), let free = try? files.availableCapacity(),
               free < IndexCompactionRule.serverRequired(statistics) {
                throw APIProblem(.init(code: 507, reasonPhrase: "Insufficient Storage"), code: "NOT_ENOUGH_ROOM",
                                 detail: "Compacting the index needs about \(LibraryIndexer.megabytes(IndexCompactionRule.serverRequired(statistics))) free on the data volume, for its copy and its log, which has \(LibraryIndexer.megabytes(free)).")
            }
            let job = try await queued { try await indexer.compact(requestedBy: user.id) }
            context.logger.info("\(user.id) asked for the index to be compacted, as job \(job.id)")
            return accepted(job, context)
        }

        admin.post("index/check") { request, context -> EditedResponse<AdminJob> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let indexer = try standalone(state, indexer)
            guard try await provider?.servedIfReady() != nil else { throw noIndex(await state.readiness()) }
            let job = try await queued { try await indexer.checkIntegrity(requestedBy: user.id) }
            context.logger.info("\(user.id) asked for the index to be checked, as job \(job.id)")
            return accepted(job, context)
        }
    }

    /// The indexer of a Standalone server, which compacts and checks its index; an Import server's index is
    /// the Mac's export, which it serves as it was installed.
    static func standalone(_ state: ServerState, _ indexer: LibraryIndexer?) throws -> LibraryIndexer {
        guard state.configuration.mode == .standalone, let indexer else {
            throw APIProblem(.conflict, code: "UPKEEP_NOT_AVAILABLE",
                             detail: "An Import server serves the Mac's export as it was installed: it compacts and checks nothing, and the Mac's own Storage settings compact and check the index an export is made from.")
        }
        return indexer
    }

    static func noIndex(_ readiness: Readiness) -> APIProblem {
        APIProblem(.serviceUnavailable, code: "INDEX_NOT_READY",
                   detail: "No index is being served (\(readiness.step.rawValue)): \(readiness.detail)")
    }

    /// The job `submit` queues, or the server's 503 when the store could not keep it.
    static func queued(_ submit: () async throws -> Job) async throws -> Job {
        do {
            return try await submit()
        } catch {
            throw APIProblem(.serviceUnavailable, code: "JOB_NOT_QUEUED",
                             detail: "The job could not be queued, since the server could not keep it: try again in a moment.")
        }
    }

    /// 202 with the job, and its address.
    static func accepted(_ job: Job, _ context: APIRequestContext) -> EditedResponse<AdminJob> {
        let location = context.basePath.prefixing("/api/v1/admin/jobs/\(job.id)")
        return EditedResponse(status: .accepted, headers: [.location: location, .cacheControl: "no-store"], response: AdminJob(job))
    }
}
