// /healthz, /readyz and /api/v1/status through the router, including /readyz at every step of an import.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import ServiceLifecycle
import Testing

@testable import FRUSLightAPI
@testable import FRUSLightServer

/// Asks `/readyz` what it reports at each import step, through the test client.
actor ReadinessProbe: ImportObserver {
    let client: any TestClientProtocol
    private(set) var seen: [(step: ReadinessStep, status: Int, body: Readiness)] = []

    init(client: any TestClientProtocol) { self.client = client }

    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) async {
        guard seen.last?.step != step,
              let response = try? await client.execute(uri: "/readyz", method: .get),
              let body = try? JSONDecoder().decode(Readiness.self, from: Data(buffer: response.body)) else { return }
        seen.append((step, Int(response.status.code), body))
    }
}

/// The submodule's data files, read once per test process.
enum TestResources {
    static let loaded = Result { try ServerResources.load(from: RepositoryFiles.resources) }
    static func value() throws -> ServerResources { try loaded.get() }
}

struct ServerFixture {
    let directory: TemporaryDirectory
    let files: DataDirectory
    let state: ServerState
    let resources: ServerResources
    let reader: ReaderService

    /// A server with no index, and `volumes` from fixtures/tei in its TEI folder.
    init(volumes: [String] = []) async throws {
        directory = try TemporaryDirectory()
        files = DataDirectory(root: directory.url.appendingPathComponent("data"))
        try files.prepare()
        if !volumes.isEmpty { try RepositoryFiles.mountTEI(volumes, at: files.volumesDirectory) }
        state = ServerState(configuration: ServerConfiguration(dataDirectory: files.root))
        await state.openExistingIndex(files: files)
        resources = try TestResources.value()
        reader = ReaderService(volumesDirectory: files.volumesDirectory, resources: resources)
    }

    var router: Router<BasicRequestContext> { buildRouter(state: state, resources: resources, reader: reader) }
    var app: some ApplicationProtocol { Application(router: router) }
}

extension ServerConfiguration {
    /// A test server's settings: its data in `directory`, the submodule's data files.
    static func testing(_ directory: URL, port: Int = 8080, poll: Duration = .milliseconds(50)) -> ServerConfiguration {
        ServerConfiguration(dataDirectory: directory, port: port, importPollInterval: poll,
                            resourcesDirectory: RepositoryFiles.resources)
    }
}

func decode<T: Decodable>(_ type: T.Type, _ response: TestResponse) throws -> T {
    try JSONDecoder().decode(type, from: Data(buffer: response.body))
}

@Suite struct HTTPTests {
    @Test func healthzAnswersAtOnce() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/healthz", method: .get)
            #expect(response.status == .ok)
            #expect(String(buffer: response.body) == #"{"status":"ok"}"#)
        }
    }

    @Test func readyzWaitsForAnExport() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/readyz", method: .get)
            #expect(response.status == .serviceUnavailable)
            let body = try decode(Readiness.self, response)
            #expect(!body.ready && body.step == .waitingForExport)
            #expect(body.detail.contains("/data/import"))
        }
    }

    /// The session 2 done-criterion: a test imports a synthetic export it builds, and walks
    /// /readyz through every step.
    @Test func readyzWalksThroughEveryImportStep() async throws {
        let fixture = try await ServerFixture()
        try SyntheticExport().write(to: fixture.files.importDirectory.appendingPathComponent("export.sqlite"))

        try await fixture.app.test(.router) { client in
            let probe = ReadinessProbe(client: client)
            let jobs = InProcessJobQueue()
            let coordinator = ImportCoordinator(
                files: fixture.files,
                importer: IndexImporter(files: fixture.files, writer: LocalIndexWriter(files: fixture.files)),
                state: fixture.state, jobs: jobs, alsoNotify: probe)
            #expect(await coordinator.scan() == nil)
            #expect(await coordinator.scan() != nil)
            await jobs.waitUntilIdle()

            let seen = await probe.seen
            #expect(seen.map(\.step) == ReadinessStep.importSteps)
            for entry in seen {
                #expect(entry.status == 503, "\(entry.step.rawValue) is not ready yet")
                #expect(entry.body.step == entry.step, "/readyz names the step under way")
            }
            let done = try await client.execute(uri: "/readyz", method: .get)
            #expect(done.status == .ok)
            let body = try decode(Readiness.self, done)
            #expect(body.ready && body.detail.contains("3 documents from 2 volumes"))
        }
    }

    @Test func statusReportsVersionsAndTheIndex() async throws {
        let fixture = try await ServerFixture()
        try SyntheticExport().write(to: fixture.files.liveIndex)
        await fixture.state.openExistingIndex(files: fixture.files)

        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/status", method: .get)
            #expect(response.status == .ok)
            let status = try decode(ServerStatus.self, response)
            #expect(status.version == FRUSLightVersion.string)
            #expect(status.mode == .import && status.auth == .none)
            #expect(status.supportedIndexVersion == 65 && status.ftsSchemaVersion == 4)
            #expect(status.sqliteVersion.hasPrefix("3."))
            #expect(status.readiness.ready)
            #expect(status.index?.documents == 3 && status.index?.appBuild == "49")
        }
    }

    /// Asks /readyz until it answers 200, for up to `seconds`.
    static func waitUntilReady(_ client: any TestClientProtocol, seconds: Double = 10) async throws -> Readiness {
        var last = Readiness(step: .waitingForExport, detail: "")
        for _ in 0..<Int(seconds * 20) {
            let response = try await client.execute(uri: "/readyz", method: .get)
            last = try decode(Readiness.self, response)
            if response.status == .ok { return last }
            try await Task.sleep(for: .milliseconds(50))
        }
        return last
    }

    @Test func aRestartServesTheInstalledIndex() async throws {
        let directory = try TemporaryDirectory()
        let config = ServerConfiguration.testing(directory.url.appendingPathComponent("data"))
        let files = DataDirectory(root: config.dataDirectory)
        try files.prepare()
        try SyntheticExport().write(to: files.liveIndex)
        let app = try await buildApplication(configuration: config)
        try await app.test(.router) { client in
            let readiness = try await Self.waitUntilReady(client)
            #expect(readiness.ready && readiness.detail.contains("3 documents"))
        }
    }

    @Test func theWatcherImportsADroppedExport() async throws {
        let directory = try TemporaryDirectory()
        let config = ServerConfiguration.testing(directory.url.appendingPathComponent("data"))
        let app = try await buildApplication(configuration: config)
        try await app.test(.router) { client in
            // Built outside the drop zone, then moved in whole.
            let staged = directory.url.appendingPathComponent("staged.sqlite")
            try SyntheticExport().write(to: staged)
            try FileManager.default.moveItem(at: staged, to: DataDirectory(root: config.dataDirectory)
                .importDirectory.appendingPathComponent("export.sqlite"))
            let readiness = try await Self.waitUntilReady(client)
            #expect(readiness.ready)
        }
    }

    @Test func theWatcherStopsCleanlyOnShutdown() async throws {
        let directory = try TemporaryDirectory()
        let files = DataDirectory(root: directory.url)
        try files.prepare()
        let state = ServerState(configuration: ServerConfiguration(dataDirectory: files.root))
        let watcher = ImportWatcher(
            files: files, state: state,
            coordinator: ImportCoordinator(files: files, importer: IndexImporter(files: files, writer: LocalIndexWriter(files: files)),
                                           state: state, jobs: InProcessJobQueue()),
            interval: .seconds(60))
        let group = ServiceGroup(configuration: .init(services: [watcher], logger: Logger(label: "test")))
        try await withThrowingTaskGroup(of: Void.self) { tasks in
            tasks.addTask { try await group.run() }
            try await Task.sleep(for: .milliseconds(100))
            await group.triggerGracefulShutdown()
            try await tasks.waitForAll()  // throws if the watcher ended with an error
        }
    }

    /// `frus-light --check-health`, the image's HEALTHCHECK, against a server on a real port.
    @Test func healthCheckAsksTheServersOwnPort() async throws {
        let fixture = try await ServerFixture()
        let app = Application(router: fixture.router, configuration: .init(address: .hostname("127.0.0.1", port: 0)))
        try await app.test(.live) { client in
            let port = try #require(client.port)
            #expect(HealthCheck.isHealthy(port: port), "\(HealthCheck.probe(port: port))")
            #expect(!HealthCheck.isHealthy(port: port, path: "/readyz"), "/readyz is 503 before an import")
        }
        #expect(!HealthCheck.isHealthy(port: 1, timeout: 1), "nothing listens on port 1")
    }

    @Test func serverStartsFromConfiguration() async throws {
        let directory = try TemporaryDirectory()
        let config = ServerConfiguration.testing(directory.url.appendingPathComponent("data"), port: 0)
        let app = try await buildApplication(configuration: config)
        try await app.test(.router) { client in
            let response = try await client.execute(uri: "/healthz", method: .get)
            #expect(response.status == .ok)
        }
        // The data directory and the user store exist after start.
        let files = DataDirectory(root: config.dataDirectory)
        #expect(FileManager.default.fileExists(atPath: files.importDirectory.path))
        #expect(FileManager.default.fileExists(atPath: files.userStore.path))
    }
}
