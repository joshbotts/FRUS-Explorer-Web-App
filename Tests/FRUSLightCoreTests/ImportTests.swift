// Import mode: a synthetic export, built from a real export's schema, through every step and every refusal.

import CSQLite
@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

/// Records each step an import reaches, once per step.
actor StepRecorder: ImportObserver {
    private(set) var steps: [ReadinessStep] = []
    private(set) var progress: [Double] = []

    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) {
        if steps.last != step { steps.append(step) }
        if let progress { self.progress.append(progress) }
    }
}

/// A data directory with an importer, and a place to drop exports.
struct ImportFixture {
    let directory: TemporaryDirectory
    let files: DataDirectory
    let importer: IndexImporter

    init() throws {
        directory = try TemporaryDirectory()
        files = DataDirectory(root: directory.url.appendingPathComponent("data"))
        try files.prepare()
        importer = IndexImporter(files: files, writer: LocalIndexWriter(files: files))
    }

    func drop(_ export: SyntheticExport, as name: String = "export.sqlite") throws -> URL {
        let url = files.importDirectory.appendingPathComponent(name)
        try export.write(to: url)
        return url
    }

    func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
}

@Suite struct ImportTests {
    @Test func validExportGoesThroughEveryStep() async throws {
        let fixture = try ImportFixture()
        let source = try fixture.drop(SyntheticExport())
        let recorder = StepRecorder()

        let index = try await fixture.importer.importExport(at: source, observer: recorder)

        #expect(await recorder.steps == ReadinessStep.importSteps)
        #expect(await recorder.progress.last == 1)
        #expect(index.summary == IndexSummary(documents: 3, volumes: 2, indexVersion: 65, ftsSchemaVersion: 4,
                                              exportedAt: "2026-10-03T15:14:19Z", appVersion: "0.2", appBuild: "49"))
        #expect(fixture.exists(fixture.files.liveIndex))
        #expect(!fixture.exists(fixture.files.candidateIndex))
        #expect(fixture.exists(source), "the importer leaves the source to its caller")
    }

    @Test func liveIndexIsServedWithoutSideFiles() async throws {
        let fixture = try ImportFixture()
        let index = try await fixture.importer.importExport(at: try fixture.drop(SyntheticExport()), observer: StepRecorder())
        _ = index.summary
        let directory = fixture.files.liveIndex.deletingLastPathComponent().path
        let names = try FileManager.default.contentsOfDirectory(atPath: directory)
        #expect(names == ["frus.db"], "immutable=1 creates no journal, -wal or -shm")
        // Rollback-journal mode: header bytes 18 and 19 are 1, not WAL's 2.
        let header = try Data(contentsOf: fixture.files.liveIndex).prefix(20)
        #expect(header[18] == 1 && header[19] == 1)
    }

    @Test func secondImportKeepsThePreviousIndex() async throws {
        let fixture = try ImportFixture()
        _ = try await fixture.importer.importExport(at: try fixture.drop(SyntheticExport(), as: "first.sqlite"), observer: StepRecorder())
        _ = try await fixture.importer.importExport(at: try fixture.drop(SyntheticExport(), as: "second.sqlite"), observer: StepRecorder())
        #expect(fixture.exists(fixture.files.liveIndex))
        #expect(fixture.exists(fixture.files.previousIndex))
    }

    @Test func acceptsAnUnstampedCopyAtTheSupportedVersion() async throws {
        let fixture = try ImportFixture()
        var export = SyntheticExport()
        export.stamped = false
        let index = try await fixture.importer.importExport(at: try fixture.drop(export), observer: StepRecorder())
        #expect(index.summary.indexVersion == 65)
        #expect(index.summary.exportedAt == nil)
    }

    @Test func acceptsACopyLeftInWALMode() async throws {
        let fixture = try ImportFixture()
        var export = SyntheticExport()
        export.walMode = true
        let index = try await fixture.importer.importExport(at: try fixture.drop(export), observer: StepRecorder())
        #expect(index.summary.documents == 3)
        let header = try Data(contentsOf: fixture.files.liveIndex).prefix(20)
        #expect(header[18] == 1, "the installed copy is switched to rollback-journal mode")
    }

    struct Refusal: Sendable, CustomTestStringConvertible {
        let name: String
        let export: SyntheticExport
        let step: ReadinessStep
        let reason: String
        var testDescription: String { name }
    }

    static let refusals: [Refusal] = {
        func export(_ change: (inout SyntheticExport) -> Void) -> SyntheticExport {
            var e = SyntheticExport()
            change(&e)
            return e
        }
        return [
            Refusal(name: "an older index version", export: export { $0.indexVersion = 64 },
                    step: .checkingVersions, reason: "index version 64; this server serves index version 65"),
            Refusal(name: "a library still re-indexing", export: export { $0.installedIndexVersion = 64 },
                    step: .checkingVersions, reason: "finish re-indexing"),
            Refusal(name: "another FTS schema generation", export: export { $0.ftsSchemaVersion = 3 },
                    step: .checkingFormat, reason: "generation 3"),
            Refusal(name: "an unstamped copy at another version", export: export { $0.stamped = false; $0.indexVersion = 64 },
                    step: .checkingVersions, reason: "no export stamp"),
            Refusal(name: "writing included", export: export { $0.stampsWritingIncluded = true; $0.containsWriting = true },
                    step: .checkingWriting, reason: "includes your notes"),
            Refusal(name: "writing behind a stamp that denies it", export: export { $0.containsWriting = true },
                    step: .checkingWriting, reason: "says it excludes your writing"),
            Refusal(name: "an unstamped copy with writing", export: export { $0.stamped = false; $0.containsWriting = true },
                    step: .checkingWriting, reason: "no export stamp"),
            Refusal(name: "a full-text index out of step", export: export { $0.corruptFullTextIndex = true },
                    step: .checkingIntegrity, reason: "frus_documents"),
            Refusal(name: "a stamp missing a version", export: export { $0.omittedStampKeys = ["current_index_version"] },
                    step: .checkingVersions, reason: "stamp has no current_index_version"),
            Refusal(name: "a stamped FTS version unlike the file's", export: export { $0.stampedFTSSchemaVersion = 3 },
                    step: .checkingVersions, reason: "installed_fts_schema_version is 3"),
            Refusal(name: "a user tag", export: export { $0.containsUserTag = true },
                    step: .checkingWriting, reason: "says it excludes your writing"),
            Refusal(name: "a damaged page", export: export { $0.damagedPage = true },
                    step: .checkingIntegrity, reason: "integrity check"),
        ]
    }()

    @Test(arguments: refusals)
    func refusesAndChangesNothing(_ refusal: Refusal) async throws {
        let fixture = try ImportFixture()
        let source = try fixture.drop(refusal.export)
        await #expect {
            _ = try await fixture.importer.importExport(at: source, observer: StepRecorder())
        } throws: { error in
            guard let error = error as? ImportRefusal else { return false }
            return error.step == refusal.step && error.reason.contains(refusal.reason)
        }
        #expect(!fixture.exists(fixture.files.liveIndex))
        #expect(!fixture.exists(fixture.files.candidateIndex))
        #expect(fixture.exists(source))
    }

    @Test func refusalLeavesTheLiveIndexServing() async throws {
        let fixture = try ImportFixture()
        _ = try await fixture.importer.importExport(at: try fixture.drop(SyntheticExport(), as: "good.sqlite"), observer: StepRecorder())
        var bad = SyntheticExport()
        bad.indexVersion = 64
        await #expect(throws: ImportRefusal.self) {
            _ = try await fixture.importer.importExport(at: try fixture.drop(bad, as: "bad.sqlite"), observer: StepRecorder())
        }
        #expect(try CorpusIndex.open(fixture.files.liveIndex).summary.documents == 3)
        #expect(!fixture.exists(fixture.files.previousIndex))
    }

    @Test func thirdImportKeepsTheSecondAsPrevious() async throws {
        let fixture = try ImportFixture()
        for (name, time) in [("a.sqlite", "2026-09-01T00:00:00Z"), ("b.sqlite", "2026-09-15T00:00:00Z"), ("c.sqlite", "2026-10-01T00:00:00Z")] {
            var export = SyntheticExport()
            export.exportedAt = time
            _ = try await fixture.importer.importExport(at: try fixture.drop(export, as: name), observer: StepRecorder())
        }
        #expect(try CorpusIndex.open(fixture.files.liveIndex).summary.exportedAt == "2026-10-01T00:00:00Z")
        #expect(try CorpusIndex.open(fixture.files.previousIndex).summary.exportedAt == "2026-09-15T00:00:00Z")
    }

    @Test func refusesACopyThatArrivedWithAWriteAheadLog() async throws {
        let fixture = try ImportFixture()
        let source = try fixture.drop(SyntheticExport())
        try Data(repeating: 1, count: 4_096).write(to: URL(fileURLWithPath: source.path + "-wal"))
        await #expect {
            _ = try await fixture.importer.importExport(at: source, observer: StepRecorder())
        } throws: { error in
            guard let refusal = error as? ImportRefusal else { return false }
            return refusal.step == .copyingExport && refusal.reason.contains("copy of a database in use")
        }
    }

    @Test func tooLittleDiskSpaceIsTheServersProblem() async throws {
        let fixture = try ImportFixture()
        let tight = TightFileStore(base: fixture.files, free: 1_000)
        let importer = IndexImporter(files: tight, writer: LocalIndexWriter(files: tight))
        await #expect {
            _ = try await importer.importExport(at: try fixture.drop(SyntheticExport()), observer: StepRecorder())
        } throws: { ($0 as? ImportProblem)?.reason.contains("free beside the index") == true }
        #expect(!fixture.exists(fixture.files.candidateIndex))
    }

    @Test func sqliteFailuresAreSortedByFault() {
        let full = ExportChecks.classify(SQLiteError(code: SQLITE_FULL, message: "database or disk is full"), at: .copyingExport, file: "x")
        #expect(full is ImportProblem)
        let ioError = ExportChecks.classify(SQLiteError(code: SQLITE_IOERR | (4 << 8), message: "disk I/O error"), at: .copyingExport, file: "x")
        #expect(ioError is ImportProblem)
        let corrupt = ExportChecks.classify(SQLiteError(code: SQLITE_CORRUPT, message: "malformed"), at: .checkingFormat, file: "x")
        #expect((corrupt as? ImportRefusal)?.step == .checkingFormat)
    }

    @Test func refusesAFileThatIsNotSQLite() async throws {
        let fixture = try ImportFixture()
        let source = fixture.files.importDirectory.appendingPathComponent("notes.txt")
        try Data("Not a database.".utf8).write(to: source)
        await #expect {
            _ = try await fixture.importer.importExport(at: source, observer: StepRecorder())
        } throws: { ($0 as? ImportRefusal)?.step == .copyingExport }
    }

    @Test func refusesADatabaseThatIsNotAnExport() async throws {
        let fixture = try ImportFixture()
        let source = fixture.files.importDirectory.appendingPathComponent("other.sqlite")
        let db = try SQLiteConnection(source.path, readOnly: false, create: true)
        try db.execute("CREATE TABLE things (name TEXT)")
        db.close()
        await #expect {
            _ = try await fixture.importer.importExport(at: source, observer: StepRecorder())
        } throws: { error in
            guard let refusal = error as? ImportRefusal else { return false }
            return refusal.step == .checkingFormat && refusal.reason.contains("document_cache")
        }
    }

    @Test func openingAnIndexFromAnotherVersionReportsAMismatch() async throws {
        let fixture = try ImportFixture()
        var old = SyntheticExport()
        old.indexVersion = 64
        try old.write(to: fixture.files.liveIndex)
        #expect {
            _ = try CorpusIndex.open(fixture.files.liveIndex)
        } throws: { ($0 as? ImportRefusal)?.step == .indexVersionMismatch }
    }
}

/// A data directory that reports how much disk is free as the test says.
final class TightFileStore: FileStore, @unchecked Sendable {
    private let base: DataDirectory
    private let lock = NSLock()
    private var freeBytes: Int64

    init(base: DataDirectory, free: Int64) {
        self.base = base
        self.freeBytes = free
    }

    var free: Int64 {
        get { lock.withLock { freeBytes } }
        set { lock.withLock { freeBytes = newValue } }
    }

    var importDirectory: URL { base.importDirectory }
    var liveIndex: URL { base.liveIndex }
    var candidateIndex: URL { base.candidateIndex }
    var previousIndex: URL { base.previousIndex }
    var userStore: URL { base.userStore }
    var volumesDirectory: URL { base.volumesDirectory }
    var exportsDirectory: URL { base.exportsDirectory }
    var backupsDirectory: URL { base.backupsDirectory }
    func prepare() throws { try base.prepare() }
    func availableCapacity() throws -> Int64 { free }
}
