// `frus-light user` (PLAN's S20b): the first admin made without a browser, and each account changed
// from the command line, the password read from a terminal twice or from standard input once, never
// from the command line; held to the password rules, and refused for a name made already or missing.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Synchronization
import Testing

@testable import FRUSLightServer

@Suite struct UserCommandTests {
    static let hasher = PasswordHasher(.leastCost)

    /// A console that answers each prompt with the next of `answers`, and keeps what is said.
    final class Script: Sendable {
        private let state: Mutex<(answers: [String], prompts: [String], said: [String], complaints: [String])>

        init(_ answers: [String]) { state = Mutex((answers, [], [], [])) }

        var prompts: [String] { state.withLock { $0.prompts } }
        var said: [String] { state.withLock { $0.said } }
        var complaints: [String] { state.withLock { $0.complaints } }

        func console(terminal: Bool = false) -> UserCommands.Console {
            UserCommands.Console(
                isTerminal: terminal,
                readPassword: { prompt in
                    self.state.withLock { state in
                        state.prompts.append(prompt)
                        return state.answers.isEmpty ? nil : state.answers.removeFirst()
                    }
                },
                say: { line in self.state.withLock { $0.said.append(line) } },
                complain: { line in self.state.withLock { $0.complaints.append(line) } })
        }
    }

    /// A data directory of its own, under `auth`.
    static func configuration(_ directory: TemporaryDirectory, auth: ServerConfiguration.Auth = .local) -> ServerConfiguration {
        ServerConfiguration(auth: auth, dataDirectory: directory.url.appendingPathComponent("data"))
    }

    static func run(_ arguments: [String], _ configuration: ServerConfiguration, _ script: Script, terminal: Bool = false) async -> Int32 {
        await UserCommands.run(arguments, configuration, console: script.console(terminal: terminal), hasher: hasher,
                               now: { UserDataFixture.now })
    }

    static func store(_ configuration: ServerConfiguration) async throws -> SQLiteUserStore {
        let files = DataDirectory(root: configuration.dataDirectory)
        return try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
    }

    /// Before the server has ever started, `user add` makes the store and the first admin, the
    /// password read as one line of standard input, and says where they sign in.
    @Test func theFirstAdminIsMadeWithoutABrowser() async throws {
        let directory = try TemporaryDirectory()
        let configuration = Self.configuration(directory)
        let script = Script(["correct horse battery staple"])
        #expect(await Self.run(["add", "alice", "--role", "admin", "--display-name", "Alice Liddell"], configuration, script) == 0)
        #expect(script.prompts == ["Password for alice: "], "asked once, as standard input is no terminal")
        #expect(script.said == ["Made alice, an admin. They sign in at http://localhost:8080/."])
        let alice = try #require(try await Self.store(configuration).account("alice"))
        #expect(alice.role == .admin && alice.displayName == "Alice Liddell" && alice.createdAt == UserDataFixture.now)
        #expect(Self.hasher.verify("correct horse battery staple", against: try #require(alice.passwordHash)))

        let reader = Script(["another long passphrase"])
        #expect(await Self.run(["add", "--role", "reader", "bob"], Self.configuration(directory, auth: .none), reader) == 0)
        #expect(reader.said == ["Made bob, a reader. Accounts sign in once FRUS_AUTH=local; this server's FRUS_AUTH is none."])
        #expect(try await Self.store(configuration).account("bob")?.displayName == "bob", "named by their name when no other is given")
    }

    /// On a terminal the password is asked twice, and two that differ change nothing; a password the
    /// rules refuse, none at all, and a name made already are refused too, with nothing made.
    @Test func whatCannotBeMadeIsRefusedAndNothingMade() async throws {
        let directory = try TemporaryDirectory()
        let configuration = Self.configuration(directory)
        let twice = Script(["correct horse battery staple", "correct horse battery stable"])
        #expect(await Self.run(["add", "alice"], configuration, twice, terminal: true) == 1)
        #expect(twice.prompts == ["Password for alice: ", "The same again: "])
        #expect(twice.complaints == ["frus-light: the two passwords differ, so nothing was changed."])
        let short = Script(["too short"])
        #expect(await Self.run(["add", "alice"], configuration, short) == 1)
        #expect(short.complaints.first?.contains("at least 15 characters") == true)
        #expect(await Self.run(["add", "alice"], configuration, Script([])) == 1)
        #expect(try await Self.store(configuration).account("alice") == nil)

        #expect(await Self.run(["add", "alice"], configuration, Script(["correct horse battery staple", "correct horse battery staple"]),
                               terminal: true) == 0)
        let again = Script(["a different passphrase"])
        #expect(await Self.run(["add", "alice"], configuration, again) == 1)
        #expect(again.prompts.isEmpty, "refused before a password is asked for")
        #expect(again.complaints == ["frus-light: There is already a user named alice."])
        let owner = Script(["a different passphrase"])
        #expect(await Self.run(["add", "owner"], configuration, owner) == 1, "the store's own user is made already")
        let blank = Script(["a different passphrase"])
        #expect(await Self.run(["add", "  "], configuration, blank) == 1)
        #expect(blank.complaints == ["frus-light: A name cannot be empty."])
    }

    /// `set-password`, `set-role`, `disable` and `enable` change an account by its name, and `list`
    /// names each; a name the store does not hold is refused before a password is asked for.
    @Test func eachAccountIsChangedByItsName() async throws {
        let directory = try TemporaryDirectory()
        let configuration = Self.configuration(directory)
        #expect(await Self.run(["add", "alice", "--role", "admin"], configuration, Script(["correct horse battery staple"])) == 0)
        let store = try await Self.store(configuration)
        let session = Session(id: SessionToken.id(of: SessionToken.make()), userID: "alice", createdAt: UserDataFixture.now,
                              lastUsedAt: UserDataFixture.now, expiresAt: UserDataFixture.now.addingTimeInterval(3_600))
        try store.startSession(session)

        let reset = Script(["a brand new passphrase"])
        #expect(await Self.run(["set-password", "alice"], configuration, reset) == 0)
        #expect(Self.hasher.verify("a brand new passphrase", against: try #require(try store.account("alice")?.passwordHash)))
        #expect(try store.session(session.id, at: UserDataFixture.now) == nil, "her sessions ended")
        let missing = Script(["a brand new passphrase"])
        #expect(await Self.run(["set-password", "nobody"], configuration, missing) == 1)
        #expect(missing.prompts.isEmpty && missing.complaints == ["frus-light: There is no user named nobody."])
        #expect(await Self.run(["set-password", "owner"], configuration, Script(["the owner's passphrase"])) == 0,
                "the store's own user, whom an import's writing may belong to, can be given one")

        let role = Script([])
        #expect(await Self.run(["set-role", "alice", "curator"], configuration, role) == 0)
        #expect(role.said == ["alice is now a curator."])
        #expect(try store.account("alice")?.role == .curator)
        #expect(await Self.run(["set-role", "alice", "root"], configuration, Script([])) == 2)
        #expect(await Self.run(["disable", "alice"], configuration, Script([])) == 0)
        #expect(try store.account("alice")?.disabledAt == UserDataFixture.now)

        let list = Script([])
        #expect(await Self.run(["list"], configuration, list) == 0)
        #expect(list.said == [
            "alice          curator  disabled 2026-10-24T00:00:00.000Z, last signed in 2026-10-24T00:00:00.000Z",
            "owner (Owner)  admin    can sign in",
        ])
        #expect(await Self.run(["enable", "alice"], configuration, Script([])) == 0)
        #expect(try store.account("alice")?.disabledAt == nil)
        #expect(await Self.run(["disable", "nobody"], configuration, Script([])) == 1)
    }

    /// Words it does not take are refused with its usage, and so is a password on the command line,
    /// which it never reads.
    @Test func wordsItDoesNotTakeAreRefused() async throws {
        let directory = try TemporaryDirectory()
        let configuration = Self.configuration(directory)
        for arguments in [[], ["remove", "alice"], ["add"], ["add", "alice", "hunter2hunter2hunter2"], ["add", "alice", "--role"],
                          ["add", "alice", "--role", "owner"], ["list", "alice"], ["set-role", "alice"], ["disable"]] {
            let script = Script(["correct horse battery staple"])
            #expect(await Self.run(arguments, configuration, script) == 2, "\(arguments)")
            #expect(script.prompts.isEmpty && script.complaints.first?.contains("usage: frus-light user add") == true, "\(arguments)")
        }
        #expect(!FileManager.default.fileExists(atPath: DataDirectory(root: configuration.dataDirectory).userStore.path),
                "no command opened the store")
    }
}
