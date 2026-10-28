// The Hummingbird application: the routes, the app's data files, the reader, and the import watcher.

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
    let userStore: SQLiteUserStore
    let sessions: InMemorySessionStore
    let jobs: InProcessJobQueue
    let indexWriter: LocalIndexWriter
    let imports: ImportCoordinator

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
        let jobs = InProcessJobQueue()
        let writer = LocalIndexWriter(files: files)
        let userStore = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
        if let migration = userStore.migration {
            let copy = migration.backup.map { ", after a copy of the store at \(migration.from) in \($0.path)" } ?? ""
            logger.info("app.db migrated from \(migration.from) to \(migration.to)\(copy)")
        }
        return ServerComponents(
            files: files,
            state: state,
            resources: resources,
            reader: ReaderService(volumesDirectory: files.volumesDirectory, resources: resources),
            webClient: webClient,
            userStore: userStore,
            sessions: InMemorySessionStore(),
            jobs: jobs,
            indexWriter: writer,
            // An export made with the owner's writing has it kept in the user store (S16e); a server
            // that keeps no user data refuses one.
            imports: ImportCoordinator(
                files: files,
                importer: IndexImporter(files: files, writer: writer,
                                        writing: configuration.userData ? ResearchDatabaseImport.move(into: userStore) : nil),
                state: state, jobs: jobs))
    }
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
    if let folder = getenv("SQLITE_TMPDIR") {
        logger.info("SQLite's temporary files go to \(String(cString: folder))")
    }
    var app = apiApplication(
        router: buildRouter(state: components.state, resources: components.resources, reader: components.reader,
                            webClient: components.webClient,
                            userData: UserDataServices(store: components.userStore, configuration: configuration,
                                                       jobs: components.jobs),
                            base: configuration.basePath, logger: logger),
        base: configuration.basePath,
        configuration: .init(address: .hostname(configuration.host, port: configuration.port), serverName: "frus-light"),
        logger: logger)
    app.addServices(ImportWatcher(files: components.files, state: components.state,
                                  coordinator: components.imports, interval: configuration.importPollInterval))
    return app
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
