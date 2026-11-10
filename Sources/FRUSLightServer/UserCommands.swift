// `frus-light user` (PLAN's S20b): local accounts from the command line, beside backup and restore, so
// that the first admin is made without a browser, in the running container or before the first start.
//   docker compose exec frus frus-light user add <name> [--role reader|curator|admin] [--display-name <name>]
//   docker compose exec frus frus-light user set-password <name>
//   docker compose exec frus frus-light user set-role <name> reader|curator|admin
//   docker compose exec frus frus-light user disable <name>
//   docker compose exec frus frus-light user enable <name>
//   docker compose exec frus frus-light user list
// A password is read from the terminal, twice and unseen, or as one line of standard input when that
// is no terminal, as `printf '%s\n' "$password" | docker compose exec -T frus frus-light user add …`
// gives it; never from the command line, which `ps` and the shell's history show.

import FRUSLightCore
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

enum UserCommands {
    static let usage = """
        usage: frus-light user add <name> [--role reader|curator|admin] [--display-name <name>]
               frus-light user set-password <name>
               frus-light user set-role <name> reader|curator|admin
               frus-light user disable <name>
               frus-light user enable <name>
               frus-light user list
        """

    /// Where a command reads a password and writes what it says: the process's own, or a test's.
    struct Console: Sendable {
        /// Whether the password comes from a terminal, which asks for it twice.
        var isTerminal: Bool
        /// Asks with the prompt and reads one line, unseen on a terminal; nil at the end of the input.
        var readPassword: @Sendable (String) -> String?
        var say: @Sendable (String) -> Void
        var complain: @Sendable (String) -> Void

        static var process: Console {
            Console(isTerminal: isatty(STDIN_FILENO) == 1, readPassword: readHidden,
                    say: { print($0) },
                    complain: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) })
        }
    }

    /// A command's failure, said in a sentence. `SecretCommands` (S20c) reads it too.
    struct Failure: Error {
        let message: String
        var status: Int32 = 1
    }

    /// Runs `arguments`, the words after `user`. Exits 0 when the command did what it says, 1 when it
    /// could not, and 2 for words it does not take.
    static func run(_ arguments: [String], _ configuration: ServerConfiguration, console: Console = .process,
                    hasher: PasswordHasher = PasswordHasher(), now: @escaping @Sendable () -> Date = Date.init) async -> Int32 {
        do {
            try await perform(arguments, configuration, console: console, hasher: hasher, now: now)
            return 0
        } catch let failure as Failure {
            console.complain(failure.status == 2 ? "\(failure.message)\n\(usage)" : "frus-light: \(failure.message)")
            return failure.status
        } catch {
            console.complain("frus-light: \(error)")
            return 1
        }
    }

    private static func perform(_ arguments: [String], _ configuration: ServerConfiguration, console: Console,
                                hasher: PasswordHasher, now: @escaping @Sendable () -> Date) async throws {
        guard let command = arguments.first else { throw Failure(message: "frus-light user needs a command.", status: 2) }
        var words = Array(arguments.dropFirst())
        var role: AccountRole?
        var displayName: String?
        if command == "add" {
            // Its options, wherever they come after the command.
            var rest: [String] = []
            while !words.isEmpty {
                let word = words.removeFirst()
                switch word {
                case "--role":
                    guard !words.isEmpty else { throw Failure(message: "--role needs a role.", status: 2) }
                    role = try parseRole(words.removeFirst())
                case "--display-name":
                    guard !words.isEmpty else { throw Failure(message: "--display-name needs a name.", status: 2) }
                    displayName = words.removeFirst()
                default:
                    rest.append(word)
                }
            }
            words = rest
        }
        let expected = ["add": 1, "set-password": 1, "set-role": 2, "disable": 1, "enable": 1, "list": 0]
        guard let count = expected[command] else { throw Failure(message: "frus-light user has no command \(command).", status: 2) }
        guard words.count == count else { throw Failure(message: "frus-light user \(command) takes \(count == 0 ? "no name" : count == 1 ? "a name" : "a name and a role").", status: 2) }
        if command == "list" {
            try await withStore(configuration) { store in try list(store, console: console) }
            return
        }
        let id = try checkedName(words[0])
        switch command {
        case "add":
            let shown = try checkedName(displayName ?? id)
            let role = role ?? .reader
            // Asked for once the name is known to be free, with the store closed and the lock let go, so
            // a prompt left unanswered keeps no restore waiting; the add checks the name again.
            try await withStore(configuration) { store in
                guard try store.account(id) == nil else { throw AccountStoreError.exists(id) }
            }
            let hash = try hasher.hash(try newPassword(for: id, console: console))
            try await withStore(configuration) { store in
                try store.addAccount(id, displayName: shown, role: role, passwordHash: hash, at: now())
            }
            console.say("Made \(id), \(article(role)) \(role.rawValue). \(whereToSignIn(configuration))")
        case "set-password":
            try await withStore(configuration) { store in
                guard try store.account(id) != nil else { throw AccountStoreError.notFound(id) }
            }
            let hash = try hasher.hash(try newPassword(for: id, console: console))
            try await withStore(configuration) { store in try store.setPasswordHash(hash, of: id) }
            console.say("Set \(id)'s password, and ended their sessions: a session the server holds ends within half a minute.")
        case "set-role":
            let role = try parseRole(words[1])
            try await withStore(configuration) { store in try store.setRole(role, of: id) }
            console.say("\(id) is now \(article(role)) \(role.rawValue).")
        case "disable":
            try await withStore(configuration) { store in try store.setDisabled(true, of: id, at: now()) }
            console.say("Disabled \(id): they cannot sign in, and a session the server holds of theirs ends within half a minute.")
        default:
            try await withStore(configuration) { store in try store.setDisabled(false, of: id, at: now()) }
            console.say("Enabled \(id) again.")
        }
    }

    private static func parseRole(_ word: String) throws -> AccountRole {
        guard let role = AccountRole(rawValue: word) else {
            throw Failure(message: "A role is reader, curator or admin, not \(word).", status: 2)
        }
        return role
    }

    private static func checkedName(_ name: String) throws -> String {
        switch AccountNames.checked(name) {
        case .success(let name): return name
        case .failure(let problem): throw Failure(message: problem.reason)
        }
    }

    private static func article(_ role: AccountRole) -> String { role == .admin ? "an" : "a" }

    private static func whereToSignIn(_ configuration: ServerConfiguration) -> String {
        let address = configuration.publicAddress.description + configuration.basePath.path
        return configuration.auth == .local
            ? "They sign in at \(address)."
            : "Accounts sign in once FRUS_AUTH=local; this server's FRUS_AUTH is \(configuration.auth.rawValue)."
    }

    /// A new password for `id`: asked twice on a terminal, or read once, and held to `PasswordRules`.
    private static func newPassword(for id: String, console: Console) throws -> String {
        guard let password = console.readPassword("Password for \(id): ") else {
            throw Failure(message: "no password was given: type it when asked, or give it as one line of standard input.")
        }
        if let problem = PasswordRules.problem(with: password) { throw Failure(message: problem) }
        if console.isTerminal, console.readPassword("The same again: ") != password {
            throw Failure(message: "the two passwords differ, so nothing was changed.")
        }
        return password
    }

    /// Every account, one a line: its name, and its display name where that differs; its role; whether
    /// it can sign in; and its last sign-in.
    private static func list(_ store: RelationalUserStore, console: Console) throws {
        let accounts = try store.accounts()
        let names = accounts.map { $0.displayName == $0.id ? $0.id : "\($0.id) (\($0.displayName))" }
        let width = names.map(\.count).max() ?? 0
        for (account, name) in zip(accounts, names) {
            let state = account.disabledAt.map { "disabled \(UserStoreDate.text($0))" }
                ?? (account.passwordHash == nil ? "no password" : "can sign in")
            let last = account.lastSignInAt.map { ", last signed in \(UserStoreDate.text($0))" } ?? ""
            let padded = name + String(repeating: " ", count: width - name.count)
            console.say("\(padded)  \(account.role.rawValue.padding(toLength: 7, withPad: " ", startingAt: 0))  \(state)\(last)")
        }
        if accounts.isEmpty { console.say("The store holds no users.") }
    }

    /// Opens the store `FRUS_USER_STORE` names, migrated to this build's schema, for `body`: app.db under
    /// the server's lock, held shared as a server holds it, so that no restore replaces the store while
    /// a command writes; or the PostgreSQL store, with a search copy of the command's own, which it
    /// removes, so that a running server's is left as it is. `SecretCommands` (S20c) opens it here too,
    /// `exclusive`: app.db's lock held as a restore holds it, so that the command runs only with the
    /// server stopped.
    static func withStore(_ configuration: ServerConfiguration, exclusive: Bool = false,
                          _ body: @escaping @Sendable (RelationalUserStore) throws -> Void) async throws {
        let files = DataDirectory(root: configuration.dataDirectory)
        try files.prepare()
        switch configuration.userStore {
        case .sqlite:
            let lock = try FileLock(files.serverLock)
            if exclusive {
                guard try lock.lock(.exclusive, wait: false) else {
                    throw Failure(message: "the server is running, and holds app.db: stop it first, with docker compose stop frus")
                }
            } else {
                guard try lock.lock(.shared, wait: false) else { throw Failure(message: "a restore of app.db is under way") }
            }
            defer { lock.unlock() }
            let store = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
            try await Blocking.run { try body(store) }
        case .postgreSQL(let postgres):
            let copy = files.temporaryDirectory.appendingPathComponent("user-search-\(UUID().uuidString).db")
            defer {
                for suffix in ["", "-wal", "-shm", "-journal"] {
                    try? FileManager.default.removeItem(atPath: copy.path + suffix)
                }
            }
            let store = try await PostgreSQLUserStore(configuration: postgres, searchCopy: copy)
            defer { store.close() }
            try await Blocking.run { try body(store) }
        }
    }

    /// Reads a line from standard input: when that is a terminal, after asking with `prompt` on
    /// standard error, with the terminal's echo off while it is read.
    private static func readHidden(_ prompt: String) -> String? {
        var saved = termios()
        let isTerminal = tcgetattr(STDIN_FILENO, &saved) == 0
        if isTerminal {
            FileHandle.standardError.write(Data(prompt.utf8))
            var hidden = saved
            hidden.c_lflag &= ~tcflag_t(ECHO)
            _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &hidden)
        }
        defer {
            if isTerminal {
                _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &saved)
                FileHandle.standardError.write(Data("\n".utf8))
            }
        }
        return readLine(strippingNewline: true)
    }
}
