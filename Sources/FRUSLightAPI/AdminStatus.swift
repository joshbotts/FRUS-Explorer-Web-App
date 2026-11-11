// /api/v1/admin/status, /api/v1/admin/backups and /api/v1/admin/index/reset (PLAN's S20d): what the
// admin's Status shows, the mode, the index and the volumes it serves, the user store and its
// migration, the backups, the stored keys' key file and the server's version, with the job running;
// the backups the server keeps, for its Backups list beside S14b's archive; and the recovery action
// that removes the served index in Import mode, a job of the queue, so that it waits for any import
// before it and the server then waits for an export, as at its first start. Standalone's reset, which
// indexes again, comes with PLAN's S21e. An admin's, behind `AdminRoutes`' guard.
//   GET  /api/v1/admin/status
//   GET  /api/v1/admin/backups
//   POST /api/v1/admin/index/reset   202, with the job

import FRUSLightCore
import Foundation
import Hummingbird

/// `GET /api/v1/admin/status`.
public struct AdminStatus: Codable, Equatable, Sendable, ResponseEncodable {
    public var version: String
    /// `import` or `standalone`.
    public var mode: String
    public var auth: String
    public var userData: Bool
    public var startedAt: String
    public var supportedIndexVersion: Int
    public var readiness: Readiness
    /// The index served, as `/api/v1/status` gives it; absent while none is.
    public var index: IndexSummary?
    /// The volumes the published catalogue lists.
    public var catalogueVolumes: Int
    public var store: Store
    /// The daily backups; absent for a PostgreSQL store, whose backups are its database service's.
    public var backups: Backups?
    public var keys: Keys
    public var jobs: Jobs

    public struct Store: Codable, Equatable, Sendable {
        /// `sqlite`, app.db, or `postgreSQL`.
        public var kind: String
        /// The newest migration applied, and this build's.
        public var migration: Int
        public var latestMigration: Int
    }

    public struct Backups: Codable, Equatable, Sendable {
        /// The daily backups kept, at most `kept`.
        public var daily: Int
        public var kept: Int
        /// The newest daily backup; absent before the first.
        public var newest: BackupManifest.Version?
        /// When a backup is due each day, as `03:00`, in `timeZone`.
        public var hour: String
        public var timeZone: String
        /// Whether each is also copied to a folder on the host, `FRUS_BACKUP_COPY_DIR`.
        public var copiedToHost: Bool
    }

    public struct Keys: Codable, Equatable, Sendable {
        /// The id of the key file the stored keys are sealed under, which says nothing of the key.
        public var keyFileId: String
        /// How many keys the store holds, every owner's.
        public var stored: Int
    }

    public struct Jobs: Codable, Equatable, Sendable {
        public var queued: Int
        /// The job running, if one is.
        public var running: AdminJob?
    }
}

/// `GET /api/v1/admin/backups`.
public struct AdminBackups: Codable, Equatable, Sendable, ResponseEncodable {
    /// Every backup and copy the server keeps, newest first, as the archive's manifest lists them;
    /// none for a PostgreSQL store.
    public var backups: [BackupManifest.Version]
    /// Whether the store is app.db, which the server backs up; false for a PostgreSQL store.
    public var backedUp: Bool
    public var copiedToHost: Bool
}

enum AdminStatusRoutes {
    static func add(to admin: RouterGroup<APIRequestContext>, services: UserDataServices, state: ServerState,
                    resources: ServerResources) {
        let store = services.store
        let files = DataDirectory(root: state.configuration.dataDirectory)

        admin.get("status") { request, _ -> EditedResponse<AdminStatus> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let served = await state.status()
            let configuration = state.configuration
            let (directory, copies) = (services.backupsDirectory, services.backupCopyDirectory)
            // Off the cooperative pool: the store's reads, and the backups' folder with the newest's migration.
            let (migration, stored, kept) = try await Blocking.run {
                (try store.schemaVersion(), try store.secretCounts().values.reduce(0, +),
                 directory.map { (UserStoreBackup.files(in: $0).filter { $0.kind == .daily }.count,
                                  BackupManifest.newestDaily(in: $0, copyDirectory: copies)) })
            }
            var backups: AdminStatus.Backups?
            if let kept {
                let schedule = BackupSchedule(hour: configuration.backupHour)
                backups = .init(daily: kept.0, kept: UserStoreBackups.kept, newest: kept.1,
                                hour: String(format: "%02d:00", schedule.hour), timeZone: schedule.timeZone.identifier,
                                copiedToHost: copies != nil)
            }
            let jobs = await services.jobs.jobs()
            let status = AdminStatus(
                version: served.version, mode: served.mode.rawValue, auth: served.auth.rawValue, userData: services.enabled,
                startedAt: served.startedAt, supportedIndexVersion: served.supportedIndexVersion, readiness: served.readiness,
                index: served.index, catalogueVolumes: resources.manifest.count,
                store: .init(kind: configuration.userStore == .sqlite ? "sqlite" : "postgreSQL", migration: migration,
                             latestMigration: UserStoreMigrations.all.count),
                backups: backups, keys: .init(keyFileId: services.secrets.key.id, stored: stored),
                jobs: .init(queued: jobs.filter { $0.state == .queued }.count,
                            running: jobs.first { $0.state == .running }.map(AdminJob.init)))
            return EditedResponse(headers: [.cacheControl: "no-store"], response: status)
        }

        admin.get("backups") { request, _ -> EditedResponse<AdminBackups> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let copies = services.backupCopyDirectory
            var backups: [BackupManifest.Version] = []
            if let directory = services.backupsDirectory {
                backups = try await Blocking.run { BackupManifest.versions(in: directory, copyDirectory: copies) }
            }
            return EditedResponse(headers: [.cacheControl: "no-store"],
                                  response: AdminBackups(backups: backups, backedUp: services.backupsDirectory != nil,
                                                         copiedToHost: copies != nil))
        }

        admin.post("index/reset") { request, context -> EditedResponse<AdminJob> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            guard state.configuration.mode == .import else {
                throw APIProblem(.conflict, code: "RESET_NOT_AVAILABLE",
                                 detail: "A Standalone server's index is reset by indexing its volumes again, which comes with the library's own indexing.")
            }
            let job: Job
            do {
                job = try await services.jobs.submit(.indexReset, subject: nil, requestedBy: user.id, id: nil) { job in
                    try await job.step("Removing the served index")
                    try await job.commit()
                    let removed = try await state.resetIndex(files: files)
                    return removed.map {
                        "Removed the index of \($0.documents) documents from \($0.volumes) volumes: the server waits for an export in /data/import"
                    } ?? "No index was served: the server waits for an export in /data/import"
                }
            } catch {
                throw APIProblem(.serviceUnavailable, code: "JOB_NOT_QUEUED",
                                 detail: "The reset could not be queued, since the server could not keep its job: try again in a moment.")
            }
            context.logger.info("\(user.id) asked for the served index to be removed, as job \(job.id)")
            let location = context.basePath.prefixing("/api/v1/admin/jobs/\(job.id)")
            return EditedResponse(status: .accepted, headers: [.location: location, .cacheControl: "no-store"], response: AdminJob(job))
        }
    }
}
