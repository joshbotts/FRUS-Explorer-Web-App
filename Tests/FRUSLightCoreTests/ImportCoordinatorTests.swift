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
         removeFile: (@Sendable (URL) throws -> Void)? = nil,
         isReadable: (@Sendable (String) -> Bool)? = nil, alsoNotify: (any ImportObserver)? = nil,
         holding: (any IndexFileObserver)? = nil, log: @escaping @Sendable (String) -> Void = { _ in }) throws {
        directory = try TemporaryDirectory()
        files = DataDirectory(root: directory.url.appendingPathComponent("data"))
        try files.prepare()
        let used = store?(files) ?? files
        state = ServerState(configuration: ServerConfiguration(dataDirectory: files.root), indexFileObserver: holding, log: log)
        jobs = InProcessJobQueue()
        coordinator = ImportCoordinator(
            files: used, importer: IndexImporter(files: used, writer: LocalIndexWriter(files: used)),
            state: state, jobs: jobs, alsoNotify: alsoNotify, retryDelay: retryDelay,
            removeFile: removeFile ?? { try FileManager.default.removeItem(at: $0) },
            isReadable: isReadable ?? { FileManager.default.isReadableFile(atPath: $0) })
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
    func scanUntilImported(limit: Int = 3) async -> String? {
        for _ in 0..<limit {
            if let job = await coordinator.scan() {
                await jobs.waitUntilIdle()
                return job
            }
        }
        return nil
    }
}

/// Cancels the import's job as it reaches a step (S20d).
final class CancelAtStep: ImportObserver, @unchecked Sendable {
    let step: ReadinessStep
    var jobs: InProcessJobQueue?
    var reached: [ReadinessStep] = []

    init(_ step: ReadinessStep) { self.step = step }

    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) async {
        if reached.last != step { reached.append(step) }
        guard step == self.step, let jobs, let job = await jobs.jobs().first(where: { $0.state == .running }) else { return }
        _ = try? await jobs.cancel(job.id, by: "alice")
    }
}

/// Holds the start's open, or the reset, at the moments it names until the test lets each go (S20d).
final class HoldAt: IndexFileObserver {
    private let gates: [IndexFileMoment: JobGate]

    init(_ moments: [IndexFileMoment]) {
        gates = Dictionary(uniqueKeysWithValues: moments.map { ($0, JobGate()) })
    }

    func reached(_ moment: IndexFileMoment) async { await gates[moment]?.wait() }

    func hasReached(_ moment: IndexFileMoment) -> Bool { gates[moment]?.reached ?? false }

    func untilReached(_ moment: IndexFileMoment) async { await gates[moment]?.untilReached() }

    func letGo(_ moment: IndexFileMoment) { gates[moment]?.open() }
}

/// The orders in which the start's open of the index found there and a reset reach its file (S20d), each
/// held in place by `HoldAt`, and once more unheld, as the server runs them.
enum StartAndReset: CaseIterable, Sendable {
    /// The reset runs whole before the open begins, which finds no file.
    case resetBeforeTheOpenBegins
    /// The order of main's ci run 45672715631, at 3f5a04b: the reset has moved the generation and not yet
    /// removed the files when the open begins.
    case resetUnderWayAsTheOpenBegins
    /// The open has taken its generation and not yet read the file when the reset runs whole: the open then
    /// fails for want of the file.
    case resetBeforeTheOpenReads
    /// The open has read the file and not yet said so when the reset runs whole.
    case resetBeforeTheOpenReports
    /// The two race, unheld.
    case racing

    var holds: [IndexFileMoment] {
        switch self {
        case .resetBeforeTheOpenBegins, .racing: []
        case .resetUnderWayAsTheOpenBegins: [.resetWillRemove, .openWillRead]
        case .resetBeforeTheOpenReads: [.openWillRead]
        case .resetBeforeTheOpenReports: [.openDidRead]
        }
    }
}

@Suite struct ImportCoordinatorTests {
    /// A reset while the start opens the index found there wins (S20d), in every order the two reach its
    /// file: nothing is served, and the server waits for an export, with no word of the open's failure.
    @Test(arguments: StartAndReset.allCases)
    func aResetWinsOverTheStartsOpen(_ order: StartAndReset) async throws {
        let held = HoldAt(order.holds)
        let f = try WatchFixture(holding: order.holds.isEmpty ? nil : held)
        let (state, files) = (f.state, f.files)
        try SyntheticExport().write(to: files.liveIndex)
        await state.prepareToOpenExistingIndex(files: files)
        let generation = await state.indexGeneration
        let reset: @Sendable () async throws -> Void = { _ = try await state.resetIndex(files: files, askedAt: generation) }
        switch order {
        case .resetBeforeTheOpenBegins:
            try await reset()
            await state.openExistingIndex(files: files)
        case .resetUnderWayAsTheOpenBegins:
            let resetting = Task { try await reset() }
            await held.untilReached(.resetWillRemove)
            let ended = Switch(false)
            let opening = Task {
                await state.openExistingIndex(files: files)
                ended.value = true
            }
            // The open ends at once. Were it to read, it would hold before reading until the files are gone.
            while !ended.value, !held.hasReached(.openWillRead) { try await Task.sleep(for: .milliseconds(5)) }
            held.letGo(.resetWillRemove)
            try await resetting.value
            held.letGo(.openWillRead)
            await opening.value
            #expect(!held.hasReached(.openWillRead), "the open read nothing while the reset was under way")
        case .resetBeforeTheOpenReads, .resetBeforeTheOpenReports:
            let moment = order.holds[0]
            let opening = Task { await state.openExistingIndex(files: files) }
            await held.untilReached(moment)
            try await reset()
            held.letGo(moment)
            await opening.value
        case .racing:
            async let opening: Void = state.openExistingIndex(files: files)
            try await reset()
            await opening
        }
        #expect(await state.status().index == nil, "the reset wins")
        let readiness = await state.readiness()
        #expect(readiness.step == .waitingForExport, "\(readiness)")
        #expect(!FileManager.default.fileExists(atPath: files.liveIndex.path))
    }

    /// A failure that is not a reset's doing is still said (S20d): an index found at start that cannot be
    /// opened is reported, before any reset and after one has ended.
    @Test func anIndexFoundAtStartThatCannotBeOpenedIsReported() async throws {
        let f = try WatchFixture()
        let notAnIndex = Data("Not an index.".utf8)
        try notAnIndex.write(to: f.files.liveIndex)
        await f.state.prepareToOpenExistingIndex(files: f.files)
        await f.state.openExistingIndex(files: f.files)
        var readiness = await f.state.readiness()
        #expect(readiness.step == .openingIndex && readiness.detail.hasPrefix("The index could not be opened: "), "\(readiness)")

        _ = try await f.state.resetIndex(files: f.files, askedAt: f.state.indexGeneration)
        #expect(await f.state.readiness().step == .waitingForExport)
        try notAnIndex.write(to: f.files.liveIndex)
        await f.state.openExistingIndex(files: f.files)
        readiness = await f.state.readiness()
        #expect(readiness.step == .openingIndex && readiness.detail.hasPrefix("The index could not be opened: "), "\(readiness)")
    }

    /// The index's reset (S20d) removes nothing an import made live after it was asked for.
    @Test func aResetRemovesNoIndexMadeLiveAfterItWasAskedFor() async throws {
        let fixture = try WatchFixture()
        let asked = await fixture.state.indexGeneration
        _ = try fixture.drop(SyntheticExport())
        #expect(await fixture.scanUntilImported() != nil)
        #expect(await fixture.state.readiness().ready)
        await #expect(throws: IndexResetRefusal.self) { _ = try await fixture.state.resetIndex(files: fixture.files, askedAt: asked) }
        #expect(await fixture.state.readiness().ready, "the new index is still served")
        #expect(FileManager.default.fileExists(atPath: fixture.files.liveIndex.path))
        let served = try #require(await fixture.state.status().index)
        let removed = try await fixture.state.resetIndex(files: fixture.files, askedAt: fixture.state.indexGeneration)
        #expect(removed == served)
        #expect(await fixture.state.readiness().step == .waitingForExport)
        #expect(!FileManager.default.fileExists(atPath: fixture.files.liveIndex.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.files.previousIndex.path))
    }

    /// An import's job cancelled between its steps (S20d) stops before the next, changing nothing: no
    /// index served, no copy left, the file kept in the drop zone and not tried again while unchanged;
    /// and one cancelled while it waits never begins.
    @Test func anImportCancelledBetweenItsStepsChangesNothing() async throws {
        let observer = CancelAtStep(.checkingFormat)
        let fixture = try WatchFixture(alsoNotify: observer)
        observer.jobs = fixture.jobs
        let source = try fixture.drop(SyntheticExport())
        let job = try #require(await fixture.scanUntilImported())
        let stopped = try #require(await fixture.jobs.job(job))
        #expect(stopped.state == .cancelled && stopped.cancelRequestedBy == "alice" && stopped.progress == "Checking the file's format")
        #expect(observer.reached == [.copyingExport, .checkingFormat], "it stopped before checking the versions")
        #expect(await fixture.state.status().lastImport?.outcome == .cancelled)
        #expect(await !fixture.state.readiness().ready)
        #expect(await fixture.state.status().index == nil)
        #expect(!FileManager.default.fileExists(atPath: fixture.files.candidateIndex.path), "its copy removed")
        #expect(!FileManager.default.fileExists(atPath: fixture.files.liveIndex.path))
        #expect(FileManager.default.fileExists(atPath: source.path), "the file is kept")
        #expect(await fixture.coordinator.scan() == nil, "and not tried again while it is unchanged")

        // One queued behind another job, cancelled while it waits, never begins, and frees the watcher.
        let other = try WatchFixture()
        let gate = JobGate()
        _ = try await other.jobs.submit(.researchImport) { _ in
            await gate.wait()
            return nil
        }
        _ = try other.drop(SyntheticExport())
        #expect(await other.coordinator.scan() == nil)
        let waiting = try #require(await other.coordinator.scan())
        _ = try await other.jobs.cancel(waiting, by: "alice")
        #expect(await other.state.status().lastImport?.outcome == .cancelled)
        gate.open()
        await other.jobs.waitUntilIdle()
        #expect(await other.jobs.job(waiting)?.startedAt == nil, "it never began")
        let renamed = try other.drop(SyntheticExport(), as: "export-2.sqlite")
        #expect(await other.scanUntilImported() != nil, "the watcher takes the next file")
        #expect(!FileManager.default.fileExists(atPath: renamed.path))
    }

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
        #expect(await fixture.jobs.job(job!)?.state == .succeeded)
        let listed = await fixture.jobs.job(job!)
        #expect(listed?.kind == .indexImport && listed?.subject == "export.sqlite")
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

    @Test func anUnreadableFileIsReportedAndTriedAgain() async throws {
        let readable = Switch(false)
        let fixture = try WatchFixture(retryDelay: .zero, isReadable: { _ in readable.value })
        _ = try fixture.drop(SyntheticExport())
        #expect(await fixture.scanUntilImported() == nil)
        let readiness = await fixture.state.readiness()
        #expect(readiness.detail.contains("cannot read export.sqlite") && readiness.detail.contains("docker compose cp -a"))
        #expect(!readiness.detail.contains("finish copying"), "it is not reported as still arriving")

        readable.value = true  // the owner fixes its permissions
        #expect(await fixture.scanUntilImported() != nil)
        #expect(await fixture.state.readiness().ready)
    }

    /// `docker compose cp` copies a link as a link, usually to a path that exists only on the
    /// host. It is refused, not read as unreadable or still copying, and not tried again unchanged.
    @Test(arguments: [true, false])
    func aSymbolicLinkIsRefusedWithoutBeingFollowed(toAnExport: Bool) async throws {
        let lines = Lines()
        let fixture = try WatchFixture(retryDelay: .zero, log: { lines.append($0) })
        let target = fixture.directory.url.appendingPathComponent("elsewhere.sqlite")
        if toAnExport { try SyntheticExport().write(to: target) }
        let link = fixture.files.importDirectory.appendingPathComponent("export.sqlite")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        #expect(await fixture.scanUntilImported() == nil, "no import starts")
        let report = await fixture.state.status().lastImport
        #expect(report?.outcome == .refused && report?.step == .copyingExport)
        #expect(report?.message.contains("export.sqlite is a symbolic link") == true)
        let readiness = await fixture.state.readiness()
        #expect(!readiness.ready && !readiness.detail.contains("cannot read") && !readiness.detail.contains("finish copying"))

        #expect(await fixture.scanUntilImported(limit: 4) == nil)
        #expect(lines.value.filter { $0.hasPrefix("Import of export.sqlite refused") }.count == 1,
                "unchanged, it is not reported again")
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == target.path, "the link stays")

        // The export itself, copied in place of the link, is imported.
        try FileManager.default.removeItem(at: link)
        _ = try fixture.drop(SyntheticExport())
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
        #expect(readiness.detail.contains("index version 64; this server serves index version \(IndexCompatibility.supportedIndexVersion)"))
    }
}

/// A flag a test flips while the code under test reads it.
/// The lines the server logs, as a test reads them.
final class Lines: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func append(_ line: String) { lock.withLock { lines.append(line) } }

    var value: [String] { lock.withLock { lines } }
}

final class Switch: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Bool

    init(_ value: Bool) { current = value }

    var value: Bool {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}
