// Watching /data/import: import a file only once it is complete, and never retry a refused file unchanged.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

/// A coordinator over a fresh data directory.
struct WatchFixture {
    let directory: TemporaryDirectory
    let files: DataDirectory
    let state: ServerState
    let jobs: InProcessJobQueue
    let coordinator: ImportCoordinator

    init(store: ((DataDirectory) -> any FileStore)? = nil, retryDelay: Duration = .seconds(60),
         removeFile: (@Sendable (URL) throws -> Void)? = nil) throws {
        directory = try TemporaryDirectory()
        files = DataDirectory(root: directory.url.appendingPathComponent("data"))
        try files.prepare()
        let used = store?(files) ?? files
        state = ServerState(configuration: ServerConfiguration(dataDirectory: files.root))
        jobs = InProcessJobQueue()
        coordinator = ImportCoordinator(
            files: used, importer: IndexImporter(files: used, writer: LocalIndexWriter(files: used)),
            state: state, jobs: jobs, retryDelay: retryDelay,
            removeFile: removeFile ?? { try FileManager.default.removeItem(at: $0) })
    }

    /// Writes an export into the drop zone with a modification time of its own.
    func drop(_ export: SyntheticExport, as name: String = "export.sqlite", modified: Date = Date()) throws -> URL {
        let url = files.importDirectory.appendingPathComponent(name)
        try export.write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return url
    }

    /// Scans until an import starts or `limit` scans pass, then waits for the import to finish.
    @discardableResult
    func scanUntilImported(limit: Int = 3) async -> Int? {
        for _ in 0..<limit {
            if let job = await coordinator.scan() {
                await jobs.waitUntilIdle()
                return job
            }
        }
        return nil
    }
}

@Suite struct ImportCoordinatorTests {
    @Test func importsAFileOnceItStopsChanging() async throws {
        let fixture = try WatchFixture()
        let source = fixture.files.importDirectory.appendingPathComponent("export.sqlite")
        try SyntheticExport().write(to: source)

        #expect(await fixture.coordinator.scan() == nil, "the first look only notes the file")
        let job = await fixture.coordinator.scan()
        #expect(job != nil)
        await fixture.jobs.waitUntilIdle()

        #expect(await fixture.state.readiness().ready)
        #expect(await fixture.state.status().lastImport?.outcome == .installed)
        #expect(!FileManager.default.fileExists(atPath: source.path), "an installed export is removed from the drop zone")
        #expect(await fixture.jobs.record(id: job!)?.state == .succeeded)
    }

    @Test func waitsForAFileStillBeingCopied() async throws {
        let fixture = try WatchFixture()
        let complete = fixture.directory.url.appendingPathComponent("complete.sqlite")
        try SyntheticExport().write(to: complete)
        let bytes = try Data(contentsOf: complete)
        let target = fixture.files.importDirectory.appendingPathComponent("export.sqlite")

        // Half the file, unchanged between looks: its header says it is longer, so it waits.
        try bytes.prefix(bytes.count / 2).write(to: target)
        #expect(await fixture.scanUntilImported(limit: 3) == nil)

        try bytes.write(to: target)
        #expect(await fixture.scanUntilImported() != nil)
        #expect(await fixture.state.readiness().ready)
    }

    @Test func doesNotRetryARefusedFileUntilItChanges() async throws {
        let fixture = try WatchFixture()
        let target = fixture.files.importDirectory.appendingPathComponent("export.sqlite")
        var old = SyntheticExport()
        old.indexVersion = 64
        try old.write(to: target)

        #expect(await fixture.scanUntilImported() != nil)
        let report = await fixture.state.status().lastImport
        #expect(report?.outcome == .refused && report?.step == .checkingVersions)
        #expect(FileManager.default.fileExists(atPath: target.path), "a refused file stays")
        let readiness = await fixture.state.readiness()
        #expect(readiness.step == .waitingForExport && readiness.detail.contains("was refused"))

        #expect(await fixture.scanUntilImported(limit: 4) == nil, "unchanged, it is not tried again")

        _ = try fixture.drop(SyntheticExport(), modified: Date().addingTimeInterval(60))
        #expect(await fixture.scanUntilImported() != nil)
        #expect(await fixture.state.readiness().ready)
    }

    @Test func anExportAlreadyLiveIsNotImportedAgain() async throws {
        let fixture = try WatchFixture()
        var older = SyntheticExport()
        older.exportedAt = "2026-09-01T00:00:00Z"
        _ = try fixture.drop(older)
        #expect(await fixture.scanUntilImported() != nil)
        _ = try fixture.drop(SyntheticExport())
        #expect(await fixture.scanUntilImported() != nil)

        // The same export again, as after a restart between installing it and removing it.
        let again = try fixture.drop(SyntheticExport(), modified: Date().addingTimeInterval(120))
        #expect(await fixture.scanUntilImported() == nil)
        #expect(!FileManager.default.fileExists(atPath: again.path), "it is removed, not re-imported")
        #expect(try CorpusIndex.open(fixture.files.previousIndex).summary.exportedAt == "2026-09-01T00:00:00Z",
                "the rollback copy is kept")
    }

    @Test func anInstalledFileThatCannotBeRemovedIsNotImportedAgain() async throws {
        let fixture = try WatchFixture(removeFile: { _ in throw CocoaError(.fileWriteNoPermission) })
        let source = try fixture.drop(SyntheticExport())
        #expect(await fixture.scanUntilImported() != nil)
        #expect(await fixture.state.status().lastImport?.message.contains("could not be removed") == true)
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(await fixture.scanUntilImported(limit: 4) == nil)
    }

    @Test func aServerSideProblemIsTriedAgain() async throws {
        var tight: TightFileStore?
        let fixture = try WatchFixture(store: { files in
            let store = TightFileStore(base: files, free: 1_000)
            tight = store
            return store
        }, retryDelay: .zero)
        _ = try fixture.drop(SyntheticExport())
        #expect(await fixture.scanUntilImported() != nil)
        let report = await fixture.state.status().lastImport
        #expect(report?.outcome == .failed)
        #expect(await fixture.state.readiness().detail.contains("will be tried again"))

        tight?.free = 1 << 40
        #expect(await fixture.scanUntilImported() != nil)
        #expect(await fixture.state.readiness().ready)
    }

    @Test func readinessNamesAFileStillBeingCopied() async throws {
        let fixture = try WatchFixture()
        let complete = fixture.directory.url.appendingPathComponent("complete.sqlite")
        try SyntheticExport().write(to: complete)
        let bytes = try Data(contentsOf: complete)
        try bytes.prefix(bytes.count / 2).write(to: fixture.files.importDirectory.appendingPathComponent("big.sqlite"))
        await fixture.coordinator.scan()
        await fixture.coordinator.scan()
        #expect(await fixture.state.readiness().detail == "Waiting for big.sqlite to finish copying into /data/import")
    }

    @Test func ignoresHiddenAndSideFiles() async throws {
        let fixture = try WatchFixture()
        try SyntheticExport().write(to: fixture.files.importDirectory.appendingPathComponent(".export.sqlite"))
        try Data("journal".utf8).write(to: fixture.files.importDirectory.appendingPathComponent("export.sqlite-journal"))
        #expect(await fixture.scanUntilImported() == nil)
    }

    @Test func startsReadyWithAnInstalledIndex() async throws {
        let fixture = try WatchFixture()
        try SyntheticExport().write(to: fixture.files.liveIndex)
        await fixture.state.openExistingIndex(files: fixture.files)
        #expect(await fixture.state.readiness().ready)
    }

    @Test func startsNotReadyWithAnIndexFromAnotherVersion() async throws {
        let fixture = try WatchFixture()
        var old = SyntheticExport()
        old.indexVersion = 64
        try old.write(to: fixture.files.liveIndex)
        await fixture.state.openExistingIndex(files: fixture.files)
        let readiness = await fixture.state.readiness()
        #expect(readiness.step == .indexVersionMismatch)
        #expect(readiness.detail.contains("index version 64; this server serves index version 65"))
    }
}
