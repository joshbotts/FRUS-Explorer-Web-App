// The user store's restore (S14b), with the server stopped: a backup is checked, the store it replaces
// is kept, and the backup is put in place, which the next start migrates forward. A backup that
// cannot be opened, one from a newer build, a store a server holds, or an archive changed since the
// API wrote it is refused, and the store is left as it was.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserStoreRestoreTests {
    static let hour = UserStoreBackupTests.hour
    /// 15:00 on the backup's day.
    static let now = hour.addingTimeInterval(12 * 3_600)

    /// A stopped server's data directory: its store at this build's migration with a tag of each
    /// of `tags`, and no connection to it open.
    static func store(in directory: TemporaryDirectory, tags: [String]) async throws -> DataDirectory {
        let files = DataDirectory(root: directory.url.appendingPathComponent("data"))
        try files.prepare()
        let store = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
        #expect(try store.schemaVersion() == UserStoreMigrations.all.count)
        try tag(files, tags)
        return files
    }

    static func tag(_ files: DataDirectory, _ names: [String]) throws {
        let rows = try UserStoreRows(files.userStore)
        for name in names {
            try rows.run("INSERT INTO tags (user_id, id, name) VALUES ('owner', ?, ?)", [.text(UUID().uuidString), .text(name)])
        }
    }

    /// The tags a store holds, by name.
    static func tags(_ store: URL) throws -> [String] {
        let db = try SQLiteConnection(store.path, readOnly: true)
        defer { db.close() }
        return try db.query("SELECT name FROM tags ORDER BY name").compactMap { $0.first?.text }
    }

    /// A daily backup of the store as it stands, as `frus-light backup` takes one.
    static func backUp(_ files: DataDirectory, at date: Date = hour) async throws -> URL {
        let backups = UserStoreBackups(files: files, copyDirectory: nil, schedule: BackupSchedule(hour: 3, timeZone: UserStoreBackupTests.utc))
        guard case .taken(let backup, _) = try await backups.backUp(at: date) else { throw CocoaError(.fileNoSuchFile) }
        return backup.url
    }

    static func restore(_ source: URL, _ files: DataDirectory, copyDirectory: URL? = nil) async throws -> UserStoreRestore.Report {
        try await UserStoreRestore.restore(source, files: files, copyDirectory: copyDirectory, now: now)
    }

    /// What is beside the store but its locks.
    static func besideTheStore(_ files: DataDirectory) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: files.userStore.deletingLastPathComponent().path)
            .filter { !$0.hasSuffix(".lock") }.sorted()
    }

    /// The copies a restore staged beside the store and left there: none, whatever it did.
    static func staged(_ files: DataDirectory) throws -> [String] {
        try besideTheStore(files).filter { $0.hasSuffix(".restoring") }
    }

    @Test func aRestoreKeepsTheStoreItReplacesAndPutsTheBackupInPlace() async throws {
        let directory = try TemporaryDirectory()
        let files = try await Self.store(in: directory, tags: ["In the backup"])
        let backup = try await Self.backUp(files)
        try Self.tag(files, ["Since the backup"])
        // The server stopped with its last change still in the write-ahead log.
        let server = try SQLiteConnection(files.userStore.path, readOnly: false)
        try server.execute("INSERT INTO tags (user_id, id, name) VALUES ('owner', 'W', 'In the log')")
        #expect(FileManager.default.fileExists(atPath: files.userStore.path + "-wal"))
        let replaced = try Self.tags(files.userStore)
        #expect(replaced == ["In the backup", "In the log", "Since the backup"])
        let copies = directory.url.appendingPathComponent("host-backups")
        try FileManager.default.createDirectory(at: copies, withIntermediateDirectories: true)

        let source = UserStoreRestore.locate(backup.lastPathComponent, files: files, copyDirectory: copies)
        #expect(source == backup, "a name is the backups folder's")
        let report = try await Self.restore(source, files, copyDirectory: copies)
        server.close()
        #expect(report.backup == backup && report.migration == UserStoreMigrations.all.count)
        let kept = try #require(report.kept)
        #expect(kept.lastPathComponent == "app-20261027T150000Z-before-restore.db" && !report.keptAsFiles)
        #expect(try Self.tags(kept) == replaced, "the store it replaced, its log's last change among them")
        #expect(report.copy == .copied)
        #expect(FileManager.default.contentsEqual(atPath: copies.appendingPathComponent(kept.lastPathComponent).path, andPath: kept.path))

        #expect(try Self.tags(files.userStore) == ["In the backup"])
        #expect(try StoreDump(files.userStore) == StoreDump(backup))
        #expect(try Self.besideTheStore(files) == ["app.db"], "no -wal of the store it replaced, and nothing staged")
        let reopened = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
        #expect(reopened.migration == nil, "the next start opens it as it is")
    }

    /// The next start migrates a backup from an earlier build forward, as it migrates any store.
    @Test func aBackupFromAnEarlierMigrationIsMigratedForwardAtTheNextStart() async throws {
        let directory = try TemporaryDirectory()
        let files = DataDirectory(root: directory.url.appendingPathComponent("data"))
        try files.prepare()
        _ = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory,
                                      migrations: Array(UserStoreMigrations.all.prefix(1)), now: Self.hour)
        let db = try SQLiteConnection(files.userStore.path, readOnly: false)
        try db.execute("""
            INSERT INTO index_corrections (volume_id, document_id, field, value, recorded_by, recorded_at)
                VALUES ('frus1961-63v06', 'd1', 'is_editorial_note', '1', 'owner', '2026-10-23T12:00:00Z')
            """)
        db.close()
        let backup = try await Self.backUp(files)
        _ = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
        #expect(try UserStoreRestore.check(files.userStore) == 2)

        let report = try await Self.restore(backup, files)
        #expect(report.migration == 1)
        let store = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
        #expect(store.migration?.from == 1 && store.migration?.to == 2)
        #expect(try store.classificationOverrides().map(\.documentId) == ["d1"], "its correction carried forward")
    }

    @Test func whatCannotBeRestoredIsRefusedAndTheStoreLeftAsItWas() async throws {
        let directory = try TemporaryDirectory()
        let files = try await Self.store(in: directory, tags: ["Kept"])
        let backup = try await Self.backUp(files)
        let before = try StoreDump(files.userStore)
        let given = directory.url.appendingPathComponent("given")
        try FileManager.default.createDirectory(at: given, withIntermediateDirectories: true)
        func refusal(_ source: URL) async -> UserStoreRestore.Refusal? {
            do {
                _ = try await Self.restore(source, files)
                Issue.record("\(source.lastPathComponent) was restored")
            } catch let refusal as UserStoreRestore.Refusal {
                return refusal
            } catch {
                Issue.record("\(source.lastPathComponent): \(error)")
            }
            return nil
        }
        func copy(_ name: String) throws -> URL {
            let url = given.appendingPathComponent(name)
            try FileManager.default.copyItem(at: backup, to: url)
            return url
        }

        let missing = given.appendingPathComponent("app-20261020T030000Z.db")
        #expect(await refusal(missing) == .missing(missing))

        let text = given.appendingPathComponent("notes.txt")
        try Data("Not a database, but some notes.".utf8).write(to: text)
        #expect(await refusal(text) == .notAStore(text, "it is not a SQLite database"))

        let other = given.appendingPathComponent("other.db")
        let otherDB = try SQLiteConnection(other.path, readOnly: false, create: true)
        try otherDB.execute("CREATE TABLE things (a TEXT); INSERT INTO things VALUES ('x');")
        otherDB.close()
        #expect(await refusal(other) == .notAStore(other, "it has no users or schema_migrations table"))

        let newer = try copy("newer.db")
        let newerDB = try SQLiteConnection(newer.path, readOnly: false)
        try newerDB.execute("CREATE TABLE later (a TEXT); INSERT INTO schema_migrations VALUES (3, '2026-11-01T00:00:00Z');")
        newerDB.close()
        #expect(await refusal(newer) == .newerThanThisBuild(newer, store: 3, build: 2))

        let damaged = try copy("damaged.db")
        let handle = try FileHandle(forWritingTo: damaged)
        try handle.seek(toOffset: 4_096)
        try handle.write(contentsOf: Data(repeating: 0xFF, count: 4_096))
        try handle.close()
        guard case .damaged(let url, _) = await refusal(damaged) else {
            Issue.record("a page overwritten is damage")
            return
        }
        #expect(url == damaged)

        let logged = try copy("logged.db")
        try Data().write(to: URL(fileURLWithPath: logged.path + "-wal"))
        #expect(await refusal(logged) == .sideFile(logged, "-wal"))

        let server = try FileLock(files.serverLock)
        #expect(try server.lock(.shared, wait: false))
        #expect(await refusal(backup) == .serverRunning)
        server.unlock()

        #expect(try StoreDump(files.userStore) == before)
        #expect(try Self.staged(files).isEmpty)
        #expect(UserStoreBackup.files(in: files.backupsDirectory).map(\.name) == [backup.lastPathComponent], "nothing was kept")
        #expect(try await Self.restore(backup, files).migration == 2, "and once it is stopped, the backup is restored")
    }

    /// The archive `GET /api/v1/admin/backup` gives is a tar file of the manifest and the backup,
    /// which a restore takes as it is, holding the backup to the manifest.
    @Test func anArchiveFromTheAPIIsRestoredAsItIs() async throws {
        let directory = try TemporaryDirectory()
        let files = try await Self.store(in: directory, tags: ["Archived"])
        let backup = try await Self.backUp(files)
        let source = try #require(try BackupArchiveSource.newest(in: files.backupsDirectory, copyDirectory: nil))
        var archive = Data()
        try await source.write { archive.append($0) }
        #expect(Int64(archive.count) == source.length && archive.count % 512 == 0)
        #expect(source.fileName == "frus-light-backup-20261027T030000Z.tar")
        let manifest = source.manifest
        #expect(manifest.backup.name == backup.lastPathComponent && manifest.backup.kind == .daily)
        #expect(manifest.backup.sha256 == (try UserStoreBackup.sha256(of: backup)))
        #expect(manifest.backup.migration == 2 && manifest.backup.takenAt == "2026-10-27T03:00:00Z")
        #expect(manifest.server == .current && manifest.server.migration == 2)
        #expect(manifest.versions == [manifest.backup])
        let file = directory.url.appendingPathComponent(source.fileName)
        try archive.write(to: file)

        // tar lists it, and gives the manifest back as the archive holds it.
        for tar in ["/usr/bin/tar", "/bin/tar"] where FileManager.default.isExecutableFile(atPath: tar) {
            #expect(try Self.run(tar, ["-tf", file.path]) == "manifest.json\n\(backup.lastPathComponent)\n")
            #expect(try Self.run(tar, ["-xOf", file.path, "manifest.json"]) == String(decoding: try manifest.encoded(), as: UTF8.self))
            break
        }

        try Self.tag(files, ["Since"])
        let report = try await Self.restore(file, files)
        #expect(report.backup == file && report.migration == 2)
        #expect(try Self.tags(files.userStore) == ["Archived"])

        // An archive whose backup changed after the API wrote it is refused.
        var changed = archive
        let inBackup = BackupArchive.member(Int64(try manifest.encoded().count)) + 512 + 100
        changed[Int(inBackup)] ^= 0x01
        let tampered = directory.url.appendingPathComponent("tampered.tar")
        try changed.write(to: tampered)
        do {
            _ = try await Self.restore(tampered, files)
            Issue.record("the changed archive was restored")
        } catch let refusal as UserStoreRestore.Refusal {
            guard case .archive(let url, let reason) = refusal else {
                Issue.record("\(refusal)")
                return
            }
            #expect(url == tampered && reason.contains("SHA-256"), "\(reason)")
        }
        #expect(try Self.staged(files).isEmpty)
        #expect(try Self.tags(files.userStore) == ["Archived"])
    }

    /// A store the backup API cannot read, as a damaged one may be, is kept as its files are.
    @Test func aStoreThatCannotBeCopiedIsKeptAsItsFiles() async throws {
        let directory = try TemporaryDirectory()
        let files = try await Self.store(in: directory, tags: ["Backed up"])
        let backup = try await Self.backUp(files)
        let damage = Data("Not a database any more.".utf8)
        try damage.write(to: files.userStore)
        let report = try await Self.restore(backup, files)
        let kept = try #require(report.kept)
        #expect(report.keptAsFiles && kept.lastPathComponent == "app-20261027T150000Z-before-restore.db")
        #expect(try Data(contentsOf: kept) == damage, "moved as it was")
        #expect(try Self.tags(files.userStore) == ["Backed up"])
    }

    @Test func aNameIsLookedForInTheSecondFolderTooAndAPathIsTakenAsItIs() throws {
        let directory = try TemporaryDirectory()
        let files = DataDirectory(root: directory.url.appendingPathComponent("data"))
        let copies = directory.url.appendingPathComponent("host-backups")
        try FileManager.default.createDirectory(at: copies, withIntermediateDirectories: true)
        let name = "app-20261027T030000Z.db"
        try Data().write(to: copies.appendingPathComponent(name))
        #expect(UserStoreRestore.locate(name, files: files, copyDirectory: copies) == copies.appendingPathComponent(name))
        #expect(UserStoreRestore.locate("app-20261026T030000Z.db", files: files, copyDirectory: copies)
                == files.backupsDirectory.appendingPathComponent("app-20261026T030000Z.db"), "one in neither is the backups folder's")
        #expect(UserStoreRestore.locate("/backups/\(name)", files: files, copyDirectory: copies) == URL(fileURLWithPath: "/backups/\(name)"))
    }

    /// Runs `tool` and gives what it wrote.
    static func run(_ tool: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
