// The Hummingbird application: health, readiness and status, plus the import watcher.

import FRUSLightCore
import Foundation
import Hummingbird
import Logging
import ServiceLifecycle

/// Everything a running server holds, built from its configuration.
struct ServerComponents: Sendable {
    let files: DataDirectory
    let state: ServerState
    let userStore: SQLiteUserStore
    let sessions: InMemorySessionStore
    let jobs: InProcessJobQueue
    let indexWriter: LocalIndexWriter
    let imports: ImportCoordinator

    static func make(configuration: ServerConfiguration, logger: Logger) async throws -> ServerComponents {
        let files = DataDirectory(root: configuration.dataDirectory)
        try files.prepare()
        let state = ServerState(configuration: configuration) { logger.info("\($0)") }
        // The watcher opens it once the server is listening, so /healthz answers at once.
        await state.prepareToOpenExistingIndex(files: files)
        let jobs = InProcessJobQueue()
        let writer = LocalIndexWriter(files: files)
        return ServerComponents(
            files: files,
            state: state,
            userStore: try SQLiteUserStore(url: files.userStore),
            sessions: InMemorySessionStore(),
            jobs: jobs,
            indexWriter: writer,
            imports: ImportCoordinator(files: files, importer: IndexImporter(files: files, writer: writer),
                                       state: state, jobs: jobs))
    }
}

func buildApplication(configuration: ServerConfiguration) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "frus-light")
    logger.logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"].flatMap(Logger.Level.init(rawValue:)) ?? .info
    let components = try await ServerComponents.make(configuration: configuration, logger: logger)
    logger.info("frus-light \(FRUSLightVersion.string): \(configuration.mode.rawValue) mode, data in \(configuration.dataDirectory.path)")
    var app = Application(
        router: buildRouter(state: components.state),
        configuration: .init(address: .hostname(configuration.host, port: configuration.port), serverName: "frus-light"),
        logger: logger)
    app.addServices(ImportWatcher(files: components.files, state: components.state,
                                  coordinator: components.imports, interval: configuration.importPollInterval))
    return app
}

func buildRouter(state: ServerState) -> Router<BasicRequestContext> {
    let router = Router()
    // The process is up. It says nothing about the index; /readyz does.
    router.get("/healthz") { _, _ in Health(status: "ok") }
    // 200 once an index is open and searchable; until then 503, naming the current step.
    router.get("/readyz") { _, _ in
        let readiness = await state.readiness()
        return EditedResponse(status: readiness.ready ? .ok : .serviceUnavailable, response: readiness)
    }
    router.get("/api/v1/status") { _, _ in await state.status() }
    return router
}

struct Health: ResponseEncodable {
    let status: String
}

extension Readiness: ResponseEncodable {}
extension ServerStatus: ResponseEncodable {}

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
