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
            if let (line, isProblem) = keyFileLine(for: report.secrets, configuration, files: files) {
                if isProblem { printError(line) } else { print(line) }
            }
            return 0
        } catch let refusal as UserStoreRestore.Refusal {
            return fail("nothing was restored: \(refusal)")
        } catch {
            return fail("nothing was restored: \(error)")
        }
    }

    /// What a restore says of the stored API keys the backup carries (PLAN's S20c), since no backup holds
    /// a key file: that the key file in place opens them, or, as a problem, that it is another or is not
    /// there, so that the server will not start until the one they were sealed under is. Nil when the
    /// backup carries none.
    static func keyFileLine(for secrets: BackupManifest.Secrets?, _ configuration: ServerConfiguration,
                            files: DataDirectory) -> (line: String, isProblem: Bool)? {
        guard let secrets, secrets.rows > 0 else { return nil }
        let keyFile = configuration.secretKeyFile ?? files.secretKey
        let held = secrets.rows == 1 ? "1 stored key" : "\(secrets.rows) stored keys"
        func ids(_ list: [String]) -> String { (list.count == 1 ? "the key file with id " : "the key files with ids ") + list.joined(separator: ", ") }
        let putItBack = "No backup holds a key file: put the one they were sealed under there before you start the server, which does not start without it"
        switch Result(catching: { try SecretKeyFile.key(at: keyFile) }) {
        case .success(let key?):
            let others = secrets.keyIds.filter { $0 != key.id }
            if others.isEmpty { return ("It carries \(held), which the key file \(keyFile.path) opens.", false) }
            let which = secrets.keyIds.contains(key.id)
                ? "It carries \(held): the key file \(keyFile.path), id \(key.id), opens those sealed under it, and not those sealed under \(ids(others))."
                : "It carries \(held), sealed under \(ids(others)), and \(keyFile.path) is another, id \(key.id)."
            return ("\(which) \(putItBack), or forget those it does not open with \(SecretKeyProblem.forget).", true)
        case .success(nil):
            return ("It carries \(held), sealed under \(ids(secrets.keyIds)), and there is no key file at \(keyFile.path). \(putItBack), or forget them all with \(SecretKeyProblem.forgetAll).", true)
        case .failure(let error):
            return ("It carries \(held), sealed under \(ids(secrets.keyIds)), and \(error)", true)
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
