// The Hummingbird application: the routes, the app's data files, the reader, the import watcher, and
// the user store's daily backup.

import FRUSLightCore
import Foundation
import Hummingbird
import Logging
import ServiceLifecycle

/// Everything a running server holds, built from its configuration.
struct ServerComponents: Sendable {
    let files: DataDirectory
    let state: ServerState
    let resources: ServerResources
    let reader: ReaderService
    let webClient: WebClient?
    let userStore: RelationalUserStore
    /// For app.db, held shared while the server runs, so a restore never replaces the store it has
    /// open, and the store's daily backups (S14b); neither for a PostgreSQL store, whose backups are
    /// its database service's.
    let serverLock: FileLock?
    let backups: UserStoreBackups?
    /// The stored API keys, over the key file this start read or made (PLAN's S20c).
    let secrets: SecretVault
    /// The server's jobs, each a row of the user store (PLAN's S20d), opened once the store is: the jobs
    /// a server stopped before they finished are marked failed before any other is queued.
    let jobs: InProcessJobQueue
    let indexWriter: LocalIndexWriter
    let imports: ImportCoordinator
    /// The stacks over the served index, which every route reads it through.
    let provider: ServedIndexProvider
    /// Suggested Next's computations (PLAN's S23d), which an export made the served index queues for every project.
    let leads: ProjectLeadsQueue

    static func make(configuration: ServerConfiguration, logger: Logger) async throws -> ServerComponents {
        // Before anything is written: a server without its data files cannot serve the reader.
        let resources = try await Blocking.run { try ServerResources.load(from: configuration.resourcesDirectory) }
        let webClient = try WebClient.load(configuration)
        let files = DataDirectory(root: configuration.dataDirectory)
        do {
            try files.prepare()
        } catch {
            throw DataDirectoryError(path: files.root.path, underlying: error)
        }
        let state = ServerState(configuration: configuration) { logger.info("\($0)") }
        // The watcher opens it once the server is listening, so /healthz answers at once.
        await state.prepareToOpenExistingIndex(files: files)
        let writer = LocalIndexWriter(files: files)
        let (userStore, serverLock, backups) = try await openUserStore(configuration, files: files, logger: logger)
        let secrets = try await openSecrets(configuration, files: files, store: userStore, logger: logger)
        let jobs = try await InProcessJobQueue.open(store: userStore, log: { logger.info("\($0)") })
        // With user data on, each stack attaches the user store's search database, for each user's half of a search (S17d).
        let provider = ServedIndexProvider(state: state, resources: resources, volumesDirectory: files.volumesDirectory,
                                           userStore: configuration.userData ? userStore.searchDatabase : nil)
        let leads = ProjectLeadsQueue(store: userStore, jobs: jobs, provider: provider, resources: resources)
        return ServerComponents(
            files: files,
            state: state,
            resources: resources,
            reader: ReaderService(volumesDirectory: files.volumesDirectory, resources: resources),
            webClient: webClient,
            userStore: userStore,
            serverLock: serverLock,
            backups: backups,
            secrets: secrets,
            jobs: jobs,
            indexWriter: writer,
            // An export made with the owner's writing has it kept in the user store (S16e); a server
            // that keeps no user data refuses one.
            imports: ImportCoordinator(
                files: files,
                importer: IndexImporter(files: files, writer: writer,
                                        writing: configuration.userData ? ResearchDatabaseImport.move(into: userStore) : nil),
                state: state, jobs: jobs, alsoNotify: configuration.userData ? LeadsAfterIndexImport(leads: leads) : nil),
            provider: provider,
            leads: leads)
    }

    /// The user store `FRUS_USER_STORE` names, migrated to this build's schema: app.db in the data
    /// directory, under the server's lock and with its daily backups; or the PostgreSQL store, with
    /// its local copy for search beside app.db's place, and neither.
    private static func openUserStore(_ configuration: ServerConfiguration, files: DataDirectory, logger: Logger)
        async throws -> (RelationalUserStore, FileLock?, UserStoreBackups?) {
        switch configuration.userStore {
        case .sqlite:
            // Before the store is opened: a restore under way finishes first.
            let serverLock = try FileLock(files.serverLock)
            if try !serverLock.lock(.shared, wait: false) {
                logger.info("A restore of app.db is under way: waiting for it to finish")
                try await serverLock.lock(.shared)
            }
            let userStore = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
            // As the app's launch sync: a row written before a summary was searched by its fields (the pin
            // move to `fe9325b2`) takes them. The PostgreSQL store's copy is made again at each start. As
            // the app's, it is no reason not to start: a search over the user's writing is all it serves.
            do {
                let synced = try userStore.syncSummarySearchText()
                if synced > 0 { logger.info("app.db's search text of \(synced) documents' summaries was rewritten as their fields") }
            } catch {
                logger.warning("app.db's search text of the users' summaries could not be brought up to date: \(error)")
            }
            let copies = configuration.backupCopyDirectory
            let problem = copies.flatMap(UserStoreBackups.problem(writing:))
            if let migration = userStore.migration {
                let copy = migration.backup.map { ", after a copy of the store at \(migration.from) in \($0.path)" } ?? ""
                logger.info("app.db migrated from \(migration.from) to \(migration.to)\(copy)")
                if let backup = migration.backup, let copies, problem == nil,
                   !FileManager.default.fileExists(atPath: copies.appendingPathComponent(backup.lastPathComponent).path) {
                    do {
                        _ = try UserStoreBackup.copyFile(backup, into: copies)
                    } catch {
                        logger.warning("The copy from before the migration could not be copied to \(copies.path): \(error)")
                    }
                }
            }
            let schedule = BackupSchedule(hour: configuration.backupHour)
            let backups = UserStoreBackups(files: files, copyDirectory: copies, schedule: schedule,
                                           changeMarker: { [userStore] in try userStore.changeMarker() })
            let hour = String(format: "%02d:00", schedule.hour)
            logger.info("app.db is backed up daily at \(hour) \(schedule.timeZone.identifier), and whenever the newest backup is a day old, into \(files.backupsDirectory.path), which keeps the newest \(UserStoreBackups.kept)\(copies.map { ", each also copied to \($0.path)" } ?? "")")
            if let copies, let problem {
                logger.warning("Backups cannot be copied to \(copies.path), so they stay in the volume alone: \(problem). On Linux, the host folder must be writable by UID \(getuid()): chown \(getuid()):\(getgid()) <folder>")
            }
            return (userStore, serverLock, backups)
        case .postgreSQL(let postgres):
            let store: PostgreSQLUserStore
            do {
                store = try await PostgreSQLUserStore(configuration: postgres, searchCopy: files.userSearchCopy,
                                                      logger: logger)
            } catch let error as PostgreSQLError {
                throw UserStoreUnreachable(configuration: postgres, underlying: error)
            }
            let migrated = store.migration.map { ", migrated from \($0.from) to \($0.to)" } ?? ""
            logger.info("User store: PostgreSQL at \(postgres)\(migrated), searched through \(files.userSearchCopy.path). The server takes no backups of it: they are its database service's")
            return (store, nil, nil)
        }
    }

    /// The stored API keys' vault (PLAN's S20c), over the key file `FRUS_SECRET_KEY_FILE` names or the
    /// server's own beside app.db, which this start makes when there is none and the store holds no
    /// stored key. A store whose stored keys the key file does not open, or whose key file is gone,
    /// keeps the server from starting, with `SecretKeyProblem`'s sentence, which the install guide
    /// gives: a new key file would leave every stored key unreadable, and say nothing. So does a
    /// PostgreSQL store with no key file named, since every server that shares it would make its own.
    /// The log names the file and its id, never the key.
    private static func openSecrets(_ configuration: ServerConfiguration, files: DataDirectory, store: RelationalUserStore,
                                    logger: Logger) async throws -> SecretVault {
        let keyFile = configuration.secretKeyFile ?? files.secretKey
        let named = configuration.secretKeyFile != nil
        let shared = configuration.userStore != .sqlite
        let (vault, origin, held) = try await Blocking.run {
            let (vault, origin) = try SecretVault.open(store: store, keyFile: keyFile, named: named, shared: shared)
            return (vault, origin, try store.secretCounts().values.reduce(0, +))
        }
        switch origin {
        case .made:
            logger.info("Made the key file \(keyFile.path) (id \(vault.key.id)), which stored API keys are sealed under. No backup holds it: keep a copy of it somewhere safe, apart from the backups, since no stored key can be read without it")
        case .found:
            let keys = held == 0 ? "the store holds none yet" : held == 1 ? "it opens the 1 the store holds" : "it opens the \(held) the store holds"
            logger.info("Stored API keys are sealed under the key file \(keyFile.path) (id \(vault.key.id)): \(keys)")
        }
        return vault
    }
}

/// The PostgreSQL user store could not be reached, or refused a statement, at start: named by its
/// URL without the password.
struct UserStoreUnreachable: Error, CustomStringConvertible {
    let configuration: PostgreSQLConfiguration
    let underlying: PostgreSQLError

    var description: String { "the user store at \(configuration) could not be opened: \(underlying)" }
}

/// The server for `configuration`, with its import watcher as a service. Throws
/// `ServerResourcesError` when the app's data files are missing, `WebClientError` when
/// `FRUS_WEB_DIR` names a folder without the browser app, and `DataDirectoryError` when the data
/// directory cannot be written.
public func buildApplication(configuration: ServerConfiguration) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "frus-light")
    logger.logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"].flatMap(Logger.Level.init(rawValue:)) ?? .info
    let components = try await ServerComponents.make(configuration: configuration, logger: logger)
    logger.info("frus-light \(FRUSLightVersion.string): \(configuration.mode.rawValue) mode, data in \(configuration.dataDirectory.path), \(components.resources.manifest.count) volumes in the manifest from \(configuration.resourcesDirectory.path)")
    if let webClient = components.webClient {
        logger.info("Serving the browser app from \(webClient.directory.path)")
    } else {
        logger.info("No browser app at \(configuration.webDirectory.path): serving the API alone")
    }
    if !configuration.basePath.isRoot {
        logger.info("Serving under \(configuration.basePath), with /healthz and /readyz at the root too")
    }
    logger.info(configuration.userData
        ? "User data on: changes are taken from pages of \(configuration.publicAddress), with its token"
        : "User data off (FRUS_USER_DATA=off): this server is read-only")
    if configuration.auth == .header {
        let proxies = configuration.trustedProxies.map(\.description).joined(separator: ", ")
        let admins = configuration.adminUsers.isEmpty ? "no admins" : "admins \(configuration.adminUsers.sorted().joined(separator: ", "))"
        logger.info("Sign-in through a proxy (FRUS_AUTH=header): the user is \(configuration.authHeader) on requests from \(proxies), and every other request but /healthz and /readyz is refused; \(admins)")
    }
    if configuration.auth == .local {
        try await logAccounts(components.userStore, configuration: configuration, logger: logger)
    }
    if let folder = getenv("SQLITE_TMPDIR") {
        logger.info("SQLite's temporary files go to \(String(cString: folder))")
    }
    var app = apiApplication(
        router: buildRouter(state: components.state, resources: components.resources, reader: components.reader,
                            provider: components.provider, webClient: components.webClient,
                            userData: UserDataServices(store: components.userStore, configuration: configuration,
                                                       secrets: components.secrets, jobs: components.jobs),
                            leads: components.leads,
                            base: configuration.basePath, logger: logger),
        base: configuration.basePath,
        configuration: .init(address: .hostname(configuration.host, port: configuration.port), serverName: "frus-light"),
        logger: logger)
    app.addServices(ImportWatcher(files: components.files, state: components.state,
                                  coordinator: components.imports, interval: configuration.importPollInterval))
    if let backups = components.backups, let serverLock = components.serverLock {
        app.addServices(BackupService(backups: backups, serverLock: serverLock, logger: logger))
    }
    return app
}

/// Says how local accounts sign in (PLAN's S20b), and how to make the first when no account can.
private func logAccounts(_ store: RelationalUserStore, configuration: ServerConfiguration, logger: Logger) async throws {
    let accounts = try await Blocking.run { try store.accounts() }.filter(\.canSignIn)
    let proxies = configuration.trustedProxies.isEmpty
        ? "" : ", each browser's address read from X-Forwarded-For behind \(configuration.trustedProxies.map(\.description).joined(separator: ", "))"
    logger.info("Local accounts (FRUS_AUTH=local): people sign in at \(configuration.publicAddress) with a name and a password\(proxies); \(accounts.count) can sign in, \(accounts.filter { $0.role == .admin }.count) of them admins")
    if accounts.isEmpty {
        logger.warning("No account can sign in yet: make the first admin with docker compose exec frus frus-light user add <name> --role admin")
    }
    if configuration.publicAddress.scheme == "https", configuration.trustedProxies.isEmpty {
        logger.warning("FRUS_PUBLIC_URL is https, so a proxy forwards to this server, and FRUS_TRUSTED_PROXIES names none: failed sign-ins are counted by the proxy's address, which everyone behind it shares, so a few failures slow everyone's. Name the proxy there")
    }
}

/// The application around `router`, under `base`, on the server's HTTP/1.1 channel, which watches
/// each connection for its client closing it (`APIServer.http1`). The server and the tests of that
/// watch both build it here.
func apiApplication(router: Router<APIRequestContext>, base: BasePath = .root, configuration: ApplicationConfiguration,
                    logger: Logger) -> Application<ServedRouter.Responder> {
    Application(router: ServedRouter(base: base, router: router), server: APIServer.http1,
                configuration: configuration, logger: logger)
}

/// The data directory exists but the server cannot write to it, as with a bind mount owned by
/// another user.
struct DataDirectoryError: Error, CustomStringConvertible {
    let path: String
    let underlying: any Error

    var description: String {
        "cannot write to \(path) (\(underlying.localizedDescription)). It must be writable by the server's user, UID \(getuid()). A named Docker volume is; for a host folder, run: chown -R \(getuid()):\(getgid()) <folder>"
    }
}

/// The user store's daily backup (S14b): a look at the start, then every few minutes and when the
/// hour begins, until the server shuts down. It holds the server's lock, so a restore cannot start
/// until it has stopped.
struct BackupService: Service {
    let backups: UserStoreBackups
    let serverLock: FileLock
    let logger: Logger

    func run() async throws {
        // Shutdown cancels the loop; that is the normal way out, not an error.
        try? await cancelWhenGracefulShutdown {
            var said: String?
            while !Task.isCancelled {
                let now = Date()
                do {
                    switch try await backups.check(at: now) {
                    case .notDue:
                        break
                    case .empty:
                        let line = "app.db holds no research yet, so no backup was taken"
                        if line != said { logger.info("\(line)") }
                        said = line
                    case .unchanged(let newest):
                        // Once for each newest, not at each look while one is due.
                        let line = "app.db has not changed since \(newest.name), the newest backup, so no other was taken"
                        if line != said { logger.info("\(line)") }
                        said = line
                    case .taken(let backup, let copy):
                        said = nil
                        switch copy {
                        case .none: logger.info("Backed up app.db to \(backup.url.path)")
                        case .copied: logger.info("Backed up app.db to \(backup.url.path), and copied it to \(backups.copyDirectory?.path ?? "")")
                        case .failed(let reason):
                            logger.warning("Backed up app.db to \(backup.url.path), but could not copy it to \(backups.copyDirectory?.path ?? ""): \(reason)")
                        }
                    }
                } catch {
                    said = nil
                    logger.error("The backup of app.db failed, and is tried again in five minutes: \(error)")
                }
                let untilHour = backups.schedule.nextHour(after: now).timeIntervalSince(Date())
                try await Task.sleep(for: min(BackupSchedule.checkInterval, .milliseconds(Int64(max(1, untilHour) * 1_000))))
            }
        }
        withExtendedLifetime(serverLock) {}
    }
}

/// Opens the index found at start, then looks for a new export in /data/import every
/// `interval`, until the server shuts down.
struct ImportWatcher: Service {
    let files: DataDirectory
    let state: ServerState
    let coordinator: ImportCoordinator
    let interval: Duration

    func run() async throws {
        await state.openExistingIndex(files: files)
        // Shutdown cancels the loop; that is the normal way out, not an error.
        try? await cancelWhenGracefulShutdown {
            while !Task.isCancelled {
                await coordinator.scan()
                try await Task.sleep(for: interval)
            }
        }
    }
}
