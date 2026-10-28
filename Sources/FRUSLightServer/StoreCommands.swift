// `frus-light backup` and `frus-light restore` (PLAN's S14b): a backup of the user store now, in the
// running container, and a restore of one, with the server stopped. Both are app.db's: a PostgreSQL
// store (S14d) is backed up and restored by its database service.
//   docker compose exec frus frus-light backup
//   docker compose run --rm frus restore <backup>

import FRUSLightCore
import Foundation

enum StoreCommands {
    /// Takes a backup now, as the daily one is taken, unless the store has not changed since the
    /// newest. Exits 0 when there is one of the store as it is.
    static func backup(_ configuration: ServerConfiguration) async -> Int32 {
        guard configuration.userStore == .sqlite else { return fail(postgreSQLStore) }
        let files = DataDirectory(root: configuration.dataDirectory)
        guard FileManager.default.fileExists(atPath: files.userStore.path) else {
            return fail("there is no store at \(files.userStore.path) to back up: the server makes it when it first starts")
        }
        do {
            // Shared, as a server holds it: a restore does not start while the store is read.
            let lock = try FileLock(files.serverLock)
            guard try lock.lock(.shared, wait: false) else { return fail("a restore of app.db is under way") }
            defer { lock.unlock() }
            let backups = UserStoreBackups(files: files, copyDirectory: configuration.backupCopyDirectory,
                                           schedule: BackupSchedule(hour: configuration.backupHour))
            switch try await backups.backUp(at: Date()) {
            case .notDue:
                return 0
            case .empty:
                print("app.db holds no research yet, so no backup was taken.")
            case .unchanged(let newest):
                print("app.db has not changed since \(newest.name), the newest backup, so no other was taken.")
            case .taken(let backup, let copy):
                print("Backed up app.db to \(backup.url.path).")
                switch copy {
                case .none: break
                case .copied: print("Copied it to \(configuration.backupCopyDirectory?.path ?? "").")
                case .failed(let reason):
                    printError("It could not be copied to \(configuration.backupCopyDirectory?.path ?? ""): \(reason)")
                }
            }
            return 0
        } catch {
            return fail("the backup failed: \(error)")
        }
    }

    /// Restores the backup `argument` names, or with none lists those there are.
    static func restore(_ argument: String?, _ configuration: ServerConfiguration) async -> Int32 {
        guard configuration.userStore == .sqlite else { return fail(postgreSQLStore) }
        let files = DataDirectory(root: configuration.dataDirectory)
        let copies = configuration.backupCopyDirectory
        guard let argument else {
            printError("usage: frus-light restore <backup>, a name below or a path, with the server stopped")
            let choices = UserStoreRestore.choices(files: files, copyDirectory: copies)
            if choices.isEmpty { printError("There are no backups in \(files.backupsDirectory.path)\(copies.map { " or \($0.path)" } ?? "").") }
            for choice in choices { printError("  \(choice.name)  \(choice.url.deletingLastPathComponent().path)") }
            return 2
        }
        let source = UserStoreRestore.locate(argument, files: files, copyDirectory: copies)
        do {
            let report = try await UserStoreRestore.restore(source, files: files, copyDirectory: copies)
            if let kept = report.kept {
                print(report.keptAsFiles
                    ? "app.db could not be copied, so its files were moved to \(kept.path) as they were."
                    : "Kept the store it replaces as \(kept.path).")
                switch report.copy {
                case .none: break
                case .copied: print("Copied that to \(copies?.path ?? "").")
                case .failed(let reason): printError("That could not be copied to \(copies?.path ?? ""): \(reason)")
                }
            }
            let next = report.migration < UserStoreMigrations.all.count
                ? " The next start migrates it from \(report.migration) to \(UserStoreMigrations.all.count), after a copy of it."
                : ""
            print("Restored \(source.path), at migration \(report.migration), as \(files.userStore.path).\(next) Start the server again: docker compose start frus")
            return 0
        } catch let refusal as UserStoreRestore.Refusal {
            return fail("nothing was restored: \(refusal)")
        } catch {
            return fail("nothing was restored: \(error)")
        }
    }

    /// Why neither command runs for a PostgreSQL store.
    private static let postgreSQLStore = "FRUS_USER_STORE names a PostgreSQL store, which its database service backs up and restores, as with pg_dump and pg_restore: frus-light backup and restore are app.db's"

    private static func fail(_ message: String) -> Int32 {
        printError("frus-light: \(message)")
        return 1
    }

    private static func printError(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}
