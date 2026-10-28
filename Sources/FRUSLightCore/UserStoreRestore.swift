// The user store's restore (PLAN's S14b), `frus-light restore`, run with the server stopped: it checks
// a backup, keeps the store it replaces, and puts the backup in place, which the next start migrates
// forward. It refuses while a server holds the store.

import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

public enum UserStoreRestore {
    /// What a restore did.
    public struct Report: Sendable {
        /// The backup put in place, and the store's migration in it.
        public let backup: URL
        public let migration: Int
        /// Where the store it replaced is kept; nil when there was none.
        public let kept: URL?
        /// Set when that store could not be copied, so its files were moved there as they were.
        public let keptAsFiles: Bool
        /// Whether the kept store reached the folder backups are copied to.
        public let copy: UserStoreBackups.Copy
    }

    /// Why a restore changed nothing.
    public enum Refusal: Error, CustomStringConvertible, Equatable {
        case serverRunning
        case missing(URL)
        case sideFile(URL, String)
        case notAStore(URL, String)
        case damaged(URL, String)
        case newerThanThisBuild(URL, store: Int, build: Int)
        case archive(URL, String)

        public var description: String {
            switch self {
            case .serverRunning:
                return "the server is running, and holds app.db: stop it first, with docker compose stop frus"
            case .missing(let url):
                return "there is no backup at \(url.path)"
            case .sideFile(let url, let side):
                return "\(url.lastPathComponent) has a \(side) file beside it, which may hold changes the file lacks: restore a backup the server made, which has none"
            case .notAStore(let url, let reason):
                return "\(url.lastPathComponent) is not a backup of the user store: \(reason)"
            case .damaged(let url, let reason):
                return "\(url.lastPathComponent) is damaged: \(reason)"
            case .newerThanThisBuild(let url, let store, let build):
                return "\(url.lastPathComponent) is at migration \(store), newer than this build's \(build): restore it with the image that made it"
            case .archive(let url, let reason):
                return "\(url.lastPathComponent) is not an archive this server can restore: \(reason)"
            }
        }
    }

    /// The backup `argument` names: a path as it is; a name, from the backups folder, else from the
    /// folder backups are copied to.
    public static func locate(_ argument: String, files: DataDirectory, copyDirectory: URL?) -> URL {
        guard !argument.contains("/") else { return URL(fileURLWithPath: argument) }
        let ours = files.backupsDirectory.appendingPathComponent(argument)
        if let copyDirectory, !FileManager.default.fileExists(atPath: ours.path) {
            let theirs = copyDirectory.appendingPathComponent(argument)
            if FileManager.default.fileExists(atPath: theirs.path) { return theirs }
        }
        return ours
    }

    /// Checks `file` as a store this build can open and migrate: a SQLite database that passes
    /// `integrity_check` and `foreign_key_check`, with the store's tables, at a migration from 1 to
    /// `build`. Returns that migration.
    public static func check(_ file: URL, build: Int = UserStoreMigrations.all.count) throws -> Int {
        let db: SQLiteConnection
        do {
            db = try SQLiteConnection.immutable(file)
        } catch {
            throw Refusal.notAStore(file, "\(error)")
        }
        defer { db.close() }
        let integrity: String
        do {
            integrity = try db.query("PRAGMA integrity_check").compactMap { $0.first?.text }.joined(separator: "; ")
        } catch let error as SQLiteError where error.code & 0xff == 26 {  // SQLITE_NOTADB
            throw Refusal.notAStore(file, "it is not a SQLite database")
        } catch {
            throw Refusal.damaged(file, "\(error)")
        }
        guard integrity == "ok" else { throw Refusal.damaged(file, integrity) }
        guard try db.hasObject(named: "schema_migrations"), try db.hasObject(named: "users") else {
            throw Refusal.notAStore(file, "it has no users or schema_migrations table")
        }
        let migration = Int(try db.scalar("SELECT coalesce(max(version), 0) FROM schema_migrations")?.integer ?? 0)
        guard migration >= 1 else { throw Refusal.notAStore(file, "no migration has been applied to it") }
        guard migration <= build else { throw Refusal.newerThanThisBuild(file, store: migration, build: build) }
        let violations = try db.query("PRAGMA foreign_key_check")
        guard violations.isEmpty else {
            throw Refusal.damaged(file, "\(violations.count) rows break a foreign key, the first in \(violations[0][0].text ?? "a table")")
        }
        return migration
    }

    /// Restores `source`, a backup or an archive the API gave, as `files`' store. With the server's
    /// lock held exclusively, so no server has the store open or opens it meanwhile:
    /// 1. the backup is copied beside the store and checked there, an archive's held to its manifest;
    /// 2. the store it replaces, when there is one, is copied into the backups folder through the
    ///    backup API, `-wal` and all, as `app-<time>-before-restore.db`, and to `copyDirectory`; one
    ///    the API cannot read, as a damaged store may be, has its files moved there as they are;
    /// 3. the store's side files are removed, so no `-wal` of another store is ever read with it,
    ///    and the backup takes its place.
    /// Up to the last step nothing of the store has changed, and a refusal or a failure leaves it so.
    public static func restore(_ source: URL, files: DataDirectory, copyDirectory: URL?, now: Date = Date(),
                               build: Int = UserStoreMigrations.all.count) async throws -> Report {
        let manager = FileManager.default
        let folder = files.userStore.deletingLastPathComponent()
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let lock = try FileLock(files.serverLock)
        guard try lock.lock(.exclusive, wait: false) else { throw Refusal.serverRunning }
        defer { lock.unlock() }

        guard manager.fileExists(atPath: source.path) else { throw Refusal.missing(source) }
        for side in ["-wal", "-journal"] where manager.fileExists(atPath: source.path + side) {
            throw Refusal.sideFile(source, side)
        }
        let staged = folder.appendingPathComponent("app.db.\(UUID().uuidString).restoring")
        defer { try? manager.removeItem(at: staged) }
        if BackupArchive.isArchive(source) {
            do {
                _ = try BackupArchive.extract(source, to: staged)
            } catch let error as ArchiveError {
                throw Refusal.archive(source, error.reason)
            }
        } else {
            _ = try UserStoreBackup.copyFile(source, into: folder, named: staged.lastPathComponent)
        }
        let migration: Int
        do {
            migration = try check(staged, build: build)
        } catch let refusal as Refusal {
            // Named by what was asked for, not by the copy beside the store.
            throw refusal.naming(source)
        }

        var kept: URL?
        var keptAsFiles = false
        var copy = UserStoreBackups.Copy.none
        let store = files.userStore
        if manager.fileExists(atPath: store.path) {
            let directories = [files.backupsDirectory] + (copyDirectory.map { [$0] } ?? [])
            let name = UserStoreBackup.nameBeforeRestore(at: now, in: directories)
            do {
                kept = try await UserStoreBackup.copy(of: store, into: files.backupsDirectory, named: name)
            } catch {
                let destination = files.backupsDirectory.appendingPathComponent(name)
                try manager.createDirectory(at: files.backupsDirectory, withIntermediateDirectories: true)
                for side in ["", "-wal", "-shm", "-journal"] where manager.fileExists(atPath: store.path + side) {
                    try manager.moveItem(atPath: store.path + side, toPath: destination.path + side)
                }
                kept = destination
                keptAsFiles = true
            }
            if let kept, !keptAsFiles, let copyDirectory {
                do {
                    _ = try UserStoreBackup.copyFile(kept, into: copyDirectory)
                    copy = .copied
                } catch {
                    copy = .failed("\(error)")
                }
            }
        }
        for side in ["-wal", "-shm", "-journal"] where manager.fileExists(atPath: store.path + side) {
            try manager.removeItem(atPath: store.path + side)
        }
        // One rename, which replaces the store at once: there is never a moment with none.
        guard rename(staged.path, store.path) == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: store.path,
                                                           NSLocalizedDescriptionKey: String(cString: strerror(errno))])
        }
        return Report(backup: source, migration: migration, kept: kept, keptAsFiles: keptAsFiles, copy: copy)
    }

    /// What every backup and copy in the two folders is, for `frus-light restore` with nothing named.
    public static func choices(files: DataDirectory, copyDirectory: URL?) -> [UserStoreBackupFile] {
        var seen = Set<String>()
        var choices: [UserStoreBackupFile] = []
        for file in UserStoreBackup.files(in: files.backupsDirectory) + (copyDirectory.map(UserStoreBackup.files(in:)) ?? [])
        where seen.insert(file.name).inserted {
            choices.append(file)
        }
        return choices.sorted { $0.isNewer(than: $1) }
    }
}

extension UserStoreRestore.Refusal {
    /// The same refusal of `file`.
    func naming(_ file: URL) -> Self {
        switch self {
        case .serverRunning: return self
        case .missing: return .missing(file)
        case .sideFile(_, let side): return .sideFile(file, side)
        case .notAStore(_, let reason): return .notAStore(file, reason)
        case .damaged(_, let reason): return .damaged(file, reason)
        case .newerThanThisBuild(_, let store, let build): return .newerThanThisBuild(file, store: store, build: build)
        case .archive(_, let reason): return .archive(file, reason)
        }
    }
}
