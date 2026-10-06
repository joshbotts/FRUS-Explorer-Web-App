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
    let userStore: SQLiteUserStore
    let sessions: InMemorySessionStore
    let jobs: InProcessJobQueue
    let indexWriter: LocalIndexWriter
    let imports: ImportCoordinator

    static func make(configuration: ServerConfiguration, logger: Logger) async throws -> ServerComponents {
        // Before anything is written: a server without its data files cannot serve the reader.
        let resources = try await Blocking.run { try ServerResources.load(from: configuration.resourcesDirectory) }
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
        return ServerComponents(
            files: files,
            state: state,
            resources: resources,
            reader: ReaderService(volumesDirectory: files.volumesDirectory, resources: resources),
            userStore: try SQLiteUserStore(url: files.userStore),
            sessions: InMemorySessionStore(),
            jobs: jobs,
            indexWriter: writer,
            imports: ImportCoordinator(files: files, importer: IndexImporter(files: files, writer: writer),
                                       state: state, jobs: jobs))
    }
}

/// The server for `configuration`, with its import watcher as a service. Throws
/// `ServerResourcesError` when the app's data files are missing, and `DataDirectoryError` when
/// the data directory cannot be written.
public func buildApplication(configuration: ServerConfiguration) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "frus-light")
    logger.logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"].flatMap(Logger.Level.init(rawValue:)) ?? .info
    let components = try await ServerComponents.make(configuration: configuration, logger: logger)
    logger.info("frus-light \(FRUSLightVersion.string): \(configuration.mode.rawValue) mode, data in \(configuration.dataDirectory.path), \(components.resources.manifest.count) volumes in the manifest from \(configuration.resourcesDirectory.path)")
    var app = Application(
        router: buildRouter(state: components.state, resources: components.resources, reader: components.reader, logger: logger),
        configuration: .init(address: .hostname(configuration.host, port: configuration.port), serverName: "frus-light"),
        logger: logger)
    app.addServices(ImportWatcher(files: components.files, state: components.state,
                                  coordinator: components.imports, interval: configuration.importPollInterval))
    return app
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
