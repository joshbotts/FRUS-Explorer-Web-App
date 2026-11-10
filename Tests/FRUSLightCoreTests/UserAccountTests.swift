// Local accounts (PLAN's S20b): migration 4's columns and `sessions` table on both stores, a store at
// migration 3 brought to 4 on each, the account and session methods written once on
// `RelationalUserStore`, each over every store `UserStoreKind.available` names, and the passwords'
// Argon2id hash and rules.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserAccountTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z
    static let hasher = PasswordHasher(.leastCost)

    /// A session for `user` made at `time`, lasting `seconds`, with a token of its own.
    static func session(for user: String, at time: Date = created, lasting seconds: TimeInterval = 3_600) -> Session {
        Session(id: SessionToken.id(of: SessionToken.make()), userID: user, createdAt: time, lastUsedAt: time,
                expiresAt: time.addingTimeInterval(seconds))
    }

    /// Migration 4 gives `users` the hash, the role, a reader's unless the user is `owner`, the time
    /// the account was disabled and its last sign-in, and makes `sessions`, which goes with its user,
    /// each as the other store makes it; a role other than the three is refused by each.
    @Test(arguments: UserStoreKind.available)
    func migrationFourMakesTheAccountsColumnsAndTheSessionsTable(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        func columns(_ table: String) throws -> [String] {
            switch kind {
            case .sqlite:
                return try rows.stored("SELECT name, type, \"notnull\", coalesce(dflt_value, ''), pk FROM pragma_table_info(?)", [.text(table)])
                    .map { "\($0[0].text ?? "") \($0[1].text ?? "") \($0[2].integer == 1 ? "NOT NULL" : "NULL") \($0[3].text ?? "") \($0[4].integer ?? 0)" }
            case .postgreSQL:
                return try rows.stored(
                    """
                    SELECT c.column_name::text, c.data_type::text, c.is_nullable::text, coalesce(c.column_default::text, ''),
                           coalesce(c.collation_name::text, ''),
                           coalesce((SELECT k.ordinal_position FROM information_schema.key_column_usage k
                                     JOIN information_schema.table_constraints t
                                       ON t.constraint_name = k.constraint_name AND t.table_schema = k.table_schema
                                     WHERE t.constraint_type = 'PRIMARY KEY' AND k.table_schema = c.table_schema
                                       AND k.table_name = c.table_name AND k.column_name = c.column_name), 0)
                        FROM information_schema.columns c
                        WHERE c.table_schema = current_schema() AND c.table_name = ?
                        ORDER BY c.ordinal_position
                    """, [.text(table)]).map { row in
                        #expect(row[4].text == "C", "\(table).\(row[0].text ?? "") compares as bytes")
                        let type = row[1].text == "text" ? "TEXT" : row[1].text ?? ""
                        // PostgreSQL writes a default with its type: 'reader'::text.
                        let fallback = (row[3].text ?? "").replacingOccurrences(of: "::text", with: "")
                        return "\(row[0].text ?? "") \(type) \(row[2].text == "NO" ? "NOT NULL" : "NULL") \(fallback) \(row[5].integer ?? 0)"
                    }
            }
        }
        #expect(try columns("users") == [
            "user_id TEXT NULL  1", "display_name TEXT NOT NULL  0", "created_at TEXT NOT NULL  0", "active_project_id TEXT NULL  0",
            "password_hash TEXT NULL  0", "role TEXT NOT NULL 'reader' 0", "disabled_at TEXT NULL  0", "last_sign_in_at TEXT NULL  0",
        ].map { kind == .postgreSQL ? $0.replacingOccurrences(of: "user_id TEXT NULL", with: "user_id TEXT NOT NULL") : $0 },
                "SQLite leaves a TEXT key nullable, as it has since migration 1")
        #expect(try columns("sessions") == [
            "session_id TEXT \(kind == .sqlite ? "NULL" : "NOT NULL")  1", "user_id TEXT NOT NULL  0", "created_at TEXT NOT NULL  0",
            "last_used_at TEXT NOT NULL  0", "expires_at TEXT NOT NULL  0",
        ])
        #expect(try store.account("owner")?.role == .admin, "the one user of a server with no sign-in holds the three roles")
        #expect(try store.account("owner")?.passwordHash == nil, "and has no password until one is set")
        try rows.addUser("reader@example.org")
        #expect(try store.account("reader@example.org")?.role == .reader)
        #expect(throws: (any Error).self) { try rows.run("UPDATE users SET role = 'root' WHERE user_id = 'owner'") }
        #expect(try store.account("owner")?.role == .admin)

        try store.startSession(Self.session(for: "reader@example.org"))
        // The test's own connection to app.db enforces foreign keys only when asked, as the store's does.
        if kind == .sqlite { try rows.run("PRAGMA foreign_keys = ON") }
        try rows.run("DELETE FROM users WHERE user_id = ?", [.text("reader@example.org")])
        #expect(try rows.stored("SELECT count(*) FROM sessions", []) == [[.integer(0)]], "a session goes with its user")
    }

    /// The done-when's migration, on app.db: a store at migration 3, with a user a proxy made and their
    /// tag, reaches 4 after a copy of itself, its users and their research kept, `owner` an admin and
    /// every other user a reader, none with a password, and no session.
    @Test func aStoreAtMigrationThreeReachesFourOnAppDB() async throws {
        let directory = try TemporaryDirectory()
        let old = try await UserStoreTests.store(at: 3, in: directory)
        #expect(try old.schemaVersion() == 3)
        _ = try old.signedInUser("reader@example.org", at: Self.created)
        let tag = try old.createTag(named: "Kept", for: "reader@example.org", at: Self.created)

        let store = try await UserStoreTests.open(directory, migrations: Array(UserStoreMigrations.all.prefix(4)))
        #expect(try store.schemaVersion() == 4)
        let backup = try #require(store.migration?.backup)
        #expect(store.migration == UserStoreMigration(from: 3, to: 4, backup: backup))
        #expect(backup.lastPathComponent == "app-20261024T000000Z-before-migration-4.db")
        #expect(try store.accounts().map { "\($0.id) \($0.role.rawValue) \($0.passwordHash == nil) \($0.disabledAt == nil)" } == [
            "owner admin true true", "reader@example.org reader true true",
        ])
        #expect(try store.tags(of: "reader@example.org") == [tag])
        #expect(try store.account("reader@example.org")?.createdAt == Self.created)
        #expect(try store.enforcesForeignKeys())
    }

    /// The account methods: a name made once, found by name, and listed by it; each change refused for a
    /// name the store does not hold; the role, the password and the disabled time as set.
    @Test(arguments: UserStoreKind.available) func anAccountIsMadeOnceAndChangedByName(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let hash = try Self.hasher.hash("correct horse battery staple")
        let alice = try store.addAccount("alice", displayName: "Alice Liddell", role: .admin, passwordHash: hash, at: Self.created)
        #expect(alice == Account(id: "alice", displayName: "Alice Liddell", role: .admin, passwordHash: hash, disabledAt: nil,
                                 lastSignInAt: nil, createdAt: Self.created))
        #expect(alice.canSignIn)
        #expect(try store.account("alice") == alice)
        #expect(try store.account("Alice") == nil, "a name is matched exactly, as a proxy's is")
        #expect(throws: AccountStoreError.exists("alice")) {
            try store.addAccount("alice", displayName: "Another", role: .reader, passwordHash: hash, at: Self.created)
        }
        #expect(throws: AccountStoreError.exists("owner")) {
            try store.addAccount("owner", displayName: "Owner", role: .reader, passwordHash: hash, at: Self.created)
        }
        try store.addAccount("Zoë", displayName: "Zoë", role: .reader, passwordHash: hash, at: Self.created)
        #expect(try store.accounts().map(\.id) == ["Zoë", "alice", "owner"], "by name, byte by byte, on both stores")

        try store.setRole(.curator, of: "alice")
        #expect(try store.account("alice")?.role == .curator)
        let newHash = try Self.hasher.hash("a different passphrase")
        try store.setPasswordHash(newHash, of: "owner")
        #expect(try store.account("owner")?.passwordHash == newHash && store.account("owner")?.canSignIn == true)
        try store.setDisabled(true, of: "alice", at: Self.created.addingTimeInterval(60))
        try store.setDisabled(true, of: "alice", at: Self.created.addingTimeInterval(120))
        #expect(try store.account("alice")?.disabledAt == Self.created.addingTimeInterval(60), "disabled once, when first disabled")
        #expect(try store.account("alice")?.canSignIn == false)
        try store.setDisabled(false, of: "alice", at: Self.created)
        #expect(try store.account("alice")?.disabledAt == nil)
        let changes: [() throws -> Void] = [{ try store.setRole(.admin, of: "nobody") }, { try store.setPasswordHash(hash, of: "nobody") },
                                            { try store.setDisabled(true, of: "nobody", at: Self.created) }]
        for change in changes {
            #expect(throws: AccountStoreError.notFound("nobody")) { try change() }
        }
        #expect(try store.account("nobody") == nil)
    }

    /// A session is found by its id until it expires or is ended; a sign-in records itself as its user's
    /// last and removes every session that has expired; a use moves its end; and the token itself is
    /// kept nowhere, only its SHA-256.
    @Test(arguments: UserStoreKind.available) func aSessionLastsUntilItExpiresOrEnds(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try store.addAccount("alice", displayName: "alice", role: .reader, passwordHash: try Self.hasher.hash("correct horse battery staple"),
                             at: Self.created)
        let token = SessionToken.make()
        let first = Session(id: SessionToken.id(of: token), userID: "alice", createdAt: Self.created, lastUsedAt: Self.created,
                            expiresAt: Self.created.addingTimeInterval(60))
        try store.startSession(first)
        let found = try #require(try store.session(first.id, at: Self.created))
        #expect(found.session == first && found.account.id == "alice")
        #expect(found.account.lastSignInAt == Self.created, "the sign-in is the account's last")
        #expect(try rows.stored("SELECT count(*) FROM sessions WHERE session_id = ?", [.text(token)]) == [[.integer(0)]],
                "the store keys a session by its token's hash")
        #expect(first.id.count == 64 && first.id != token)

        try store.touchSession(first.id, at: Self.created.addingTimeInterval(30), expiresAt: Self.created.addingTimeInterval(90))
        let moved = try #require(try store.session(first.id, at: Self.created.addingTimeInterval(61)))
        #expect(moved.session.lastUsedAt == Self.created.addingTimeInterval(30) && moved.session.expiresAt == Self.created.addingTimeInterval(90))
        #expect(try store.session(first.id, at: Self.created.addingTimeInterval(90)) == nil, "expired at its end")
        #expect(try store.session(SessionToken.id(of: SessionToken.make()), at: Self.created) == nil)

        // The next sign-in removes it, and keeps a session that has not expired.
        let live = Self.session(for: "alice", at: Self.created, lasting: 3_600)
        try store.startSession(live)
        let next = Self.session(for: "alice", at: Self.created.addingTimeInterval(100))
        try store.startSession(next)
        #expect(Set(try rows.stored("SELECT session_id FROM sessions", []).compactMap { $0[0].text }) == [live.id, next.id])
        #expect(try store.account("alice")?.lastSignInAt == Self.created.addingTimeInterval(100))

        try store.endSession(live.id)
        try store.endSession(live.id)
        #expect(try store.session(live.id, at: Self.created) == nil)
        #expect(try store.session(next.id, at: Self.created.addingTimeInterval(100)) != nil, "only the session ended")
        #expect(throws: AccountStoreError.notFound("nobody")) { try store.startSession(Self.session(for: "nobody")) }
    }

    /// A user keeps at most a hundred sessions: a sign-in past them ends the oldest, and no one else's.
    @Test(arguments: UserStoreKind.available) func aUserKeepsAtMostAHundredSessions(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let hash = try Self.hasher.hash("correct horse battery staple")
        for name in ["alice", "bob"] { try store.addAccount(name, displayName: name, role: .reader, passwordHash: hash, at: Self.created) }
        let bobs = Self.session(for: "bob", lasting: 86_400)
        try store.startSession(bobs)
        let sessions = (0...RelationalUserStore.mostSessions).map { Self.session(for: "alice", at: Self.created.addingTimeInterval(Double($0)), lasting: 86_400) }
        for session in sessions { try store.startSession(session) }
        let kept = try rows.stored("SELECT session_id FROM sessions WHERE user_id = 'alice'", []).compactMap { $0[0].text }
        #expect(Set(kept) == Set(sessions.dropFirst().map(\.id)), "the oldest ended")
        #expect(try store.session(bobs.id, at: Self.created) != nil)
    }

    /// A new password, or the account disabled, ends every session of theirs and no one else's.
    @Test(arguments: UserStoreKind.available) func aNewPasswordOrADisabledAccountEndsTheirSessions(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let hash = try Self.hasher.hash("correct horse battery staple")
        for name in ["alice", "bob"] { try store.addAccount(name, displayName: name, role: .reader, passwordHash: hash, at: Self.created) }
        let (one, two, bobs) = (Self.session(for: "alice"), Self.session(for: "alice"), Self.session(for: "bob"))
        for session in [one, two, bobs] { try store.startSession(session) }
        try store.setPasswordHash(try Self.hasher.hash("another long passphrase"), of: "alice")
        #expect(try store.session(one.id, at: Self.created) == nil && store.session(two.id, at: Self.created) == nil)
        #expect(try store.session(bobs.id, at: Self.created) != nil)

        let three = Self.session(for: "alice")
        try store.startSession(three)
        try store.setDisabled(true, of: "alice", at: Self.created)
        #expect(try store.session(three.id, at: Self.created) == nil)
        #expect(try store.session(bobs.id, at: Self.created) != nil)
        try store.setRole(.admin, of: "bob")
        #expect(try store.session(bobs.id, at: Self.created)?.account.role == .admin, "a role changes and the session stays")
    }

    /// A restore ends every session the backup holds, since some may have ended after it was taken; a
    /// backup from before migration 4 has none to end.
    @Test func aRestoreEndsEverySessionTheBackupHolds() async throws {
        let directory = try TemporaryDirectory()
        let store = try await UserStoreTests.open(directory)
        try store.addAccount("alice", displayName: "alice", role: .reader, passwordHash: try Self.hasher.hash("correct horse battery staple"),
                             at: Self.created)
        let session = Self.session(for: "alice")
        try store.startSession(session)
        try UserStoreRestore.endSessions(in: directory.url.appendingPathComponent("app.db"))
        #expect(try store.session(session.id, at: Self.created) == nil)
        #expect(try store.account("alice")?.canSignIn == true, "the account stays")
        let older = try TemporaryDirectory()
        _ = try await UserStoreTests.store(at: 3, in: older)
        try UserStoreRestore.endSessions(in: older.url.appendingPathComponent("app.db"))
    }

    /// A session is kept only for the password the sign-in verified, of an account not disabled since.
    @Test(arguments: UserStoreKind.available) func aSessionIsKeptOnlyForThePasswordVerified(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let hash = try Self.hasher.hash("correct horse battery staple")
        try store.addAccount("alice", displayName: "alice", role: .reader, passwordHash: hash, at: Self.created)
        try store.startSession(Self.session(for: "alice"), passwordHash: hash)
        #expect(throws: AccountStoreError.changed("alice")) { try store.startSession(Self.session(for: "alice"), passwordHash: "another") }
        try store.setDisabled(true, of: "alice", at: Self.created)
        #expect(throws: AccountStoreError.changed("alice")) { try store.startSession(Self.session(for: "alice"), passwordHash: hash) }
    }

    /// No account or session write changes anything the kit's search reads, so none moves the search
    /// mark, and every user's kept searches stand (S17d).
    @Test(arguments: UserStoreKind.available) func accountsAndSessionsMoveNoSearchMark(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let mark = try store.searchMark()
        let hash = try Self.hasher.hash("correct horse battery staple")
        try store.addAccount("alice", displayName: "alice", role: .reader, passwordHash: hash, at: Self.created)
        let session = Self.session(for: "alice")
        try store.startSession(session)
        try store.touchSession(session.id, at: Self.created, expiresAt: Self.created.addingTimeInterval(7_200))
        try store.endSession(session.id)
        try store.setRole(.curator, of: "alice")
        try store.setPasswordHash(hash, of: "alice")
        try store.setDisabled(true, of: "alice", at: Self.created)
        #expect(try store.searchMark() == mark)
    }

    /// A name is trimmed, never empty, at most 256 bytes and free of control characters, as a proxy's
    /// header is held.
    @Test func aNameIsCheckedAsAProxysIs() throws {
        #expect(try AccountNames.checked("  alice ").get() == "alice")
        #expect(try AccountNames.checked("José Martí").get() == "José Martí")
        #expect(try AccountNames.checked(String(repeating: "é", count: 128)).get().utf8.count == 256)
        for name in ["", "   ", String(repeating: "a", count: 257), "al\u{0}ice", "line\nbreak", "bad\u{FFFD}"] {
            #expect(throws: AccountNameProblem.self, "\(name.debugDescription)") { try AccountNames.checked(name).get() }
        }
        #expect(AccountRole.reader.held == [.reader] && AccountRole.curator.held == [.reader, .curator])
        #expect(AccountRole.admin.held == [.reader, .curator, .admin])
    }
}

/// The PostgreSQL store's half of the done-when's migration.
@Suite(.enabled(if: TestPostgreSQL.isConfigured, "the PostgreSQL store's own tests need a database: FRUS_TEST_POSTGRES_URL, as scripts/swift --postgres sets"))
struct PostgreSQLAccountMigrationTests {
    /// A store at migration 3, with a user a proxy made and their tag, reaches 4, as app.db does.
    @Test func aStoreAtMigrationThreeReachesFour() async throws {
        try await PostgreSQLUserStoreTests.inSchema { configuration, directory in
            let old = try await PostgreSQLUserStoreTests.open(configuration, in: directory,
                                                               migrations: Array(PostgreSQLMigrations.all.prefix(3)))
            #expect(try old.schemaVersion() == 3)
            _ = try old.signedInUser("reader@example.org", at: UserAccountTests.created)
            let tag = try old.createTag(named: "Kept", for: "reader@example.org", at: UserAccountTests.created)
            old.close()

            let store = try await PostgreSQLUserStoreTests.open(configuration, in: directory,
                                                                 migrations: Array(PostgreSQLMigrations.all.prefix(4)))
            defer { store.close() }
            #expect(store.migration == UserStoreMigration(from: 3, to: 4, backup: nil))
            #expect(try store.schemaVersion() == 4)
            #expect(try store.accounts().map { "\($0.id) \($0.role.rawValue) \($0.passwordHash == nil) \($0.disabledAt == nil)" } == [
                "owner admin true true", "reader@example.org reader true true",
            ])
            #expect(try store.tags(of: "reader@example.org") == [tag])
            let session = UserAccountTests.session(for: "reader@example.org")
            try store.startSession(session)
            #expect(try store.session(session.id, at: UserAccountTests.created)?.account.id == "reader@example.org")
        }
    }
}

/// Argon2id through libargon2, and what a new password must be.
@Suite struct PasswordTests {
    /// The reference implementation's own known answer for Argon2id, version 1.3: "password" with the
    /// salt "somesalt", two passes over 64 MiB in one lane, a 32-byte tag. Its PHC string is what the
    /// library's test suite holds it to.
    @Test func argon2idGivesTheReferenceAnswer() throws {
        let reference = "$argon2id$v=19$m=65536,t=2,p=1$c29tZXNhbHQ$CTFhFdXPJO1aFaMaO6Mm5c8y7cJHAph8ArZWb2GRPPc"
        let hasher = PasswordHasher(.init(iterations: 2, memoryKiB: 65_536, lanes: 1))
        #expect(try hasher.hash("password", salt: Array("somesalt".utf8)) == reference)
        #expect(hasher.verify("password", against: reference))
        #expect(!hasher.verify("Password", against: reference))
    }

    /// A hash carries its costs and a salt of its own, so two of one password differ and each
    /// verifies, under any hasher's costs; a wrong password, or a string that is no Argon2id hash,
    /// verifies nothing.
    @Test func aHashCarriesItsCostsAndSalt() throws {
        let standard = PasswordHasher()
        #expect(standard.parameters == .init(iterations: 3, memoryKiB: 65_536, lanes: 4), "RFC 9106's second recommended option")
        let hash = try standard.hash("correct horse battery staple")
        #expect(hash.hasPrefix("$argon2id$v=19$m=65536,t=3,p=4$"))
        let parts = hash.split(separator: "$")
        #expect(parts.count == 5 && parts[3].count == 22 && parts[4].count == 43, "a 16-byte salt and a 32-byte tag, unpadded base64")
        #expect(try standard.hash("correct horse battery staple") != hash)
        #expect(PasswordHasher(.leastCost).verify("correct horse battery staple", against: hash), "the hash names its own costs")
        #expect(!standard.verify("correct horse battery stable", against: hash))
        for other in ["", "plain text", "$argon2i$v=19$m=65536,t=2,p=1$c29tZXNhbHQ$CTFhFdXPJO1aFaMaO6Mm5c8y7cJHAph8ArZWb2GRPPc",
                      String(hash.dropLast())] {
            #expect(!standard.verify("correct horse battery staple", against: other), "\(other)")
        }
        let decoy = try standard.decoy()
        #expect(decoy.hasPrefix("$argon2id$v=19$m=65536,t=3,p=4$") && decoy != hash)
    }

    /// A password is hashed in NFKC, so the same characters typed as one code point or as two, or as a
    /// ligature, are the same password.
    @Test func aPasswordIsNormalizedBeforeItIsHashed() throws {
        let hasher = PasswordHasher(.leastCost)
        let composed = try hasher.hash("caf\u{E9} au lait, s'il vous pla\u{EE}t")
        #expect(hasher.verify("cafe\u{301} au lait, s'il vous plai\u{302}t", against: composed))
        #expect(hasher.verify("\u{FB01}ve long words", against: try hasher.hash("five long words")))
    }

    /// At least fifteen characters, counted in NFKC, at most 1,024 bytes, and no control character.
    @Test func aNewPasswordIsHeldToTheRules() {
        #expect(PasswordRules.problem(with: "fifteen chars!!") == nil)
        #expect(PasswordRules.problem(with: "fourteen chars") != nil)
        #expect(PasswordRules.problem(with: String(repeating: "é", count: 15)) == nil, "fifteen characters, thirty bytes")
        #expect(PasswordRules.problem(with: String(repeating: "e\u{301}", count: 8)) != nil, "eight characters once composed")
        #expect(PasswordRules.problem(with: "with a\ttab inside it") != nil)
        #expect(PasswordRules.problem(with: String(repeating: "a", count: 1_024)) == nil)
        #expect(PasswordRules.problem(with: String(repeating: "a", count: 1_025)) != nil)
        #expect(PasswordRules.problem(with: "a phrase of a few words is fine") == nil)
    }
}
