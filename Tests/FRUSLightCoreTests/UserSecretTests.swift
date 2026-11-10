// The stored API keys (PLAN's S20c): migration 5's `secrets` table on both stores, a store at migration
// 4 brought to 5 on each, and the store's methods, written once on `RelationalUserStore`, each over
// every store `UserStoreKind.available` names; how a key is sealed, held to a reference answer made
// with another library; the key file, made once, whole, for the server's user alone, by however many
// servers start together; the rules a start holds its key file and its store to, with the sentences
// the install guide gives; and the backup's manifest and the restore's report, which list the table
// and never hold a key file.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

/// Hexadecimal, as the reference answers are written.
private func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }

/// Whether `bytes` holds `part` anywhere.
private func holds(_ bytes: [UInt8], _ part: [UInt8]) -> Bool {
    guard !part.isEmpty, bytes.count >= part.count else { return false }
    return (0...(bytes.count - part.count)).contains { Array(bytes[$0..<$0 + part.count]) == part }
}

@Suite struct UserSecretTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z

    /// Migration 5 makes `secrets` as the other store makes it: a user's rows by their id, the
    /// instance's with none, one row for an owner's name, and a user's rows gone with the user.
    @Test(arguments: UserStoreKind.available)
    func migrationFiveMakesTheSecretsTable(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let columns: [String]
        switch kind {
        case .sqlite:
            columns = try rows.stored("SELECT name, type, \"notnull\" FROM pragma_table_info('secrets')", [])
                .map { "\($0[0].text ?? "") \($0[1].text ?? "") \($0[2].integer == 1 ? "NOT NULL" : "NULL")" }
        case .postgreSQL:
            columns = try rows.stored(
                """
                SELECT column_name::text, data_type::text, is_nullable::text, coalesce(collation_name::text, '')
                    FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'secrets'
                    ORDER BY ordinal_position
                """, []).map { row in
                    if row[1].text == "text" { #expect(row[3].text == "C", "secrets.\(row[0].text ?? "") compares as bytes") }
                    let type = row[1].text == "text" ? "TEXT" : row[1].text == "bytea" ? "BLOB" : row[1].text ?? ""
                    return "\(row[0].text ?? "") \(type) \(row[2].text == "NO" ? "NOT NULL" : "NULL")"
                }
        }
        #expect(columns == ["user_id TEXT NULL", "name TEXT NOT NULL", "key_id TEXT NOT NULL", "sealed BLOB NOT NULL",
                            "updated_at TEXT NOT NULL"])

        try rows.addUser("reader@example.org")
        try store.setSecret([1, 2, 3], keyID: "k", named: "nara", of: .user("reader@example.org"), at: Self.created)
        try store.setSecret([4, 5, 6], keyID: "k", named: "nara", of: .instance, at: Self.created)
        let insert = "INSERT INTO secrets (user_id, name, key_id, sealed, updated_at) VALUES (?, 'nara', 'k', ?, '2026-10-24T00:00:00.000Z')"
        #expect(throws: (any Error).self, "a user has one of a name") {
            try rows.run(insert, [.text("reader@example.org"), .blob([7])])
        }
        #expect(throws: (any Error).self, "and so has the instance") { try rows.run(insert, [.null, .blob([7])]) }
        #expect(throws: (any Error).self, "a row is a user's the store holds, or the instance's") {
            if kind == .sqlite { try rows.run("PRAGMA foreign_keys = ON") }
            try rows.run(insert, [.text("nobody"), .blob([7])])
        }
        #expect(try rows.stored("SELECT count(*) FROM secrets", []) == [[.integer(2)]])

        // The test's own connection to app.db enforces foreign keys only when asked, as the store's does.
        if kind == .sqlite { try rows.run("PRAGMA foreign_keys = ON") }
        try rows.run("DELETE FROM users WHERE user_id = ?", [.text("reader@example.org")])
        #expect(try store.secretEntries(of: .user("reader@example.org")).isEmpty, "a user's keys go with the user")
        #expect(try store.secretEntries(of: .instance).map(\.name) == ["nara"], "and the instance's stay")
    }

    /// The done-when's migration, on app.db: a store at migration 4, with a user and their tag, reaches
    /// 5 after a copy of itself, with what it held and an empty `secrets`.
    @Test func aStoreAtMigrationFourReachesFiveOnAppDB() async throws {
        let directory = try TemporaryDirectory()
        let old = try await UserStoreTests.store(at: 4, in: directory)
        #expect(try old.schemaVersion() == 4)
        _ = try old.signedInUser("reader@example.org", at: Self.created)
        let tag = try old.createTag(named: "Kept", for: "reader@example.org", at: Self.created)

        let store = try await UserStoreTests.open(directory)
        #expect(try store.schemaVersion() == 5)
        let backup = try #require(store.migration?.backup)
        #expect(store.migration == UserStoreMigration(from: 4, to: 5, backup: backup))
        #expect(backup.lastPathComponent == "app-20261024T000000Z-before-migration-5.db")
        #expect(BackupManifest.Secrets.held(in: backup) == nil, "the copy from before has no table for them")
        #expect(try store.tags(of: "reader@example.org") == [tag])
        #expect(try store.secretCounts().isEmpty)
        try store.setSecret([1], keyID: "k", named: "zotero", of: .user("reader@example.org"), at: Self.created)
        #expect(try store.secretCounts() == ["k": 1])
        #expect(try store.enforcesForeignKeys())
    }

    /// The store's methods: an owner has one secret of a name, set in place of the one before, read as
    /// it was kept, listed by name without what it holds, and removed once; a user's are theirs alone,
    /// and the instance's no user's.
    @Test(arguments: UserStoreKind.available) func aSecretIsKeptOnceForItsOwnerAndName(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try rows.addUser("alice")
        try rows.addUser("bob")
        let later = Self.created.addingTimeInterval(90.0004)
        let alice = SecretOwner.user("alice")

        let first = try store.setSecret([1, 2, 3], keyID: "key-a", named: "zotero", of: alice, at: Self.created)
        #expect(first == SecretEntry(name: "zotero", updatedAt: Self.created))
        #expect(try store.sealedSecret(named: "zotero", of: alice) == SealedSecret(keyID: "key-a", sealed: [1, 2, 3], updatedAt: Self.created))
        #expect(try store.sealedSecret(named: "zotero", of: .user("bob")) == nil)
        #expect(try store.sealedSecret(named: "zotero", of: .user("Alice")) == nil, "a name is matched exactly")
        #expect(try store.sealedSecret(named: "zotero", of: .instance) == nil)
        #expect(try store.sealedSecret(named: "nara", of: alice) == nil)

        let bytes = (0..<300).map { UInt8($0 % 256) }
        let second = try store.setSecret(bytes, keyID: "key-b", named: "zotero", of: alice, at: later)
        #expect(second.updatedAt == UserStoreDate.rounded(later), "to the store's precision")
        #expect(try store.sealedSecret(named: "zotero", of: alice) == SealedSecret(keyID: "key-b", sealed: bytes, updatedAt: second.updatedAt),
                "every byte as it was given, in place of the one before")
        #expect(try rows.stored("SELECT count(*) FROM secrets", []) == [[.integer(1)]])

        try store.setSecret([9], keyID: "key-b", named: "nara", of: alice, at: Self.created)
        try store.setSecret([8], keyID: "key-b", named: "nara", of: .instance, at: later)
        try store.setSecret([7], keyID: "key-a", named: "nara", of: .user("bob"), at: Self.created)
        #expect(try store.secretEntries(of: alice) == [SecretEntry(name: "nara", updatedAt: Self.created), second], "by name")
        #expect(try store.secretEntries(of: .instance) == [SecretEntry(name: "nara", updatedAt: UserStoreDate.rounded(later))])
        #expect(try store.secretEntries(of: .user("carol")).isEmpty)
        #expect(try store.secretCounts() == ["key-a": 1, "key-b": 3])

        #expect(throws: AccountStoreError.notFound("carol")) {
            try store.setSecret([1], keyID: "key-a", named: "nara", of: .user("carol"), at: Self.created)
        }
        #expect(try store.removeSecret(named: "nara", of: alice))
        #expect(try !store.removeSecret(named: "nara", of: alice), "they have none now")
        #expect(try store.sealedSecret(named: "nara", of: .instance)?.sealed == [8], "the instance's is no user's")
        #expect(try store.sealedSecret(named: "nara", of: .user("bob"))?.sealed == [7])
        #expect(try store.removeSecret(named: "nara", of: .instance))
        #expect(try store.secretEntries(of: .instance).isEmpty)
        #expect(try store.sealedSecret(named: "zotero", of: alice)?.sealed == bytes)
    }

    /// What `frus-light secrets forget` runs: every secret not sealed under the key file named goes,
    /// or with none named every secret, and the count is what went.
    @Test(arguments: UserStoreKind.available) func forgettingRemovesWhatAKeyFileDoesNotOpen(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try rows.addUser("alice")
        #expect(try store.removeSecrets(notSealedUnder: nil) == 0)
        try store.setSecret([1], keyID: "key-a", named: "zotero", of: .user("alice"), at: Self.created)
        try store.setSecret([2], keyID: "key-b", named: "nara", of: .user("alice"), at: Self.created)
        try store.setSecret([3], keyID: "key-b", named: "nara", of: .instance, at: Self.created)
        #expect(try store.removeSecrets(notSealedUnder: "key-a") == 2)
        #expect(try store.secretCounts() == ["key-a": 1])
        #expect(try store.removeSecrets(notSealedUnder: "key-a") == 0)
        #expect(try store.sealedSecret(named: "zotero", of: .user("alice"))?.sealed == [1])
        #expect(try store.removeSecrets(notSealedUnder: nil) == 1)
        #expect(try store.secretCounts().isEmpty)
    }

    /// A stored key is nothing the kit's search reads, so no write of one moves the search mark, which
    /// would drop every user's kept searches.
    @Test(arguments: UserStoreKind.available) func secretsMoveNoSearchMark(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let mark = try store.searchMark()
        try store.setSecret([1], keyID: "k", named: "nara", of: .user("owner"), at: Self.created)
        try store.setSecret([2], keyID: "k", named: "nara", of: .instance, at: Self.created)
        try store.removeSecret(named: "nara", of: .user("owner"))
        try store.removeSecrets(notSealedUnder: nil)
        #expect(try store.searchMark() == mark)
    }
}

/// The PostgreSQL store's half of the done-when's migration.
@Suite(.enabled(if: TestPostgreSQL.isConfigured, "the PostgreSQL store's own tests need a database: FRUS_TEST_POSTGRES_URL, as scripts/swift --postgres sets"))
struct PostgreSQLSecretMigrationTests {
    /// A store at migration 4, with a user and their tag, reaches 5, as app.db does.
    @Test func aStoreAtMigrationFourReachesFive() async throws {
        try await PostgreSQLUserStoreTests.inSchema { configuration, directory in
            let old = try await PostgreSQLUserStoreTests.open(configuration, in: directory,
                                                               migrations: Array(PostgreSQLMigrations.all.prefix(4)))
            #expect(try old.schemaVersion() == 4)
            _ = try old.signedInUser("reader@example.org", at: UserSecretTests.created)
            let tag = try old.createTag(named: "Kept", for: "reader@example.org", at: UserSecretTests.created)
            old.close()

            let store = try await PostgreSQLUserStoreTests.open(configuration, in: directory)
            defer { store.close() }
            #expect(store.migration == UserStoreMigration(from: 4, to: 5, backup: nil))
            #expect(try store.schemaVersion() == 5)
            #expect(try store.tags(of: "reader@example.org") == [tag])
            #expect(try store.secretCounts().isEmpty)
            try store.setSecret([1], keyID: "k", named: "zotero", of: .user("reader@example.org"), at: UserSecretTests.created)
            #expect(try store.sealedSecret(named: "zotero", of: .user("reader@example.org"))?.sealed == [1])
        }
    }
}

/// How a key is sealed and opened.
@Suite struct SecretKeyTests {
    /// The key file's bytes 0 to 31.
    static let key = SecretKey(Array(0..<32))!
    static let zotero = Array("P9NiFoyLeZu2bZNvvuQPDWsd".utf8)

    /// The sealing is what Secrets.swift's head says, to the byte: HKDF-SHA256 over the key file with
    /// the write's salt and the secret's binding, then AES-256-GCM under the derived key with the
    /// write's nonce, authenticating the binding. The answers are Node's `crypto` module's, OpenSSL's,
    /// for the same inputs (`hkdfSync('sha256', key, salt, binding, 32)`, `createCipheriv('aes-256-gcm',
    /// …)` with `setAAD(binding)`): the key file's bytes 0 to 31, the salt 32 to 63, the nonce 64 to 75,
    /// and alice's Zotero key.
    @Test func theSealingIsTheReferenceAnswer() throws {
        #expect(Self.key.id == "141c99669e6cf0cc", "HKDF-SHA256 with no salt, info frus-light/secret-key-id/v1, 8 bytes")
        let binding = SecretBinding(owner: .user("alice"), name: "zotero")
        #expect(hex(binding.bytes) == "667275732d6c696768742f7365637265742f7631000100000005616c696365000000067a6f7465726f")
        #expect(hex(SecretBinding(owner: .instance, name: "nara").bytes) == "667275732d6c696768742f7365637265742f7631000000000000000000046e617261")
        let sealed = try Self.key.seal(Self.zotero, for: binding, salt: Array(32..<64), nonce: Array(64..<76))
        #expect(hex(sealed) == "01" + "202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f" + "404142434445464748494a4b"
            + "d8f0f39b4641c895ceb3a2612a893ac2447fe0171eb861de" + "c8ca94a3ce1e75cce61aab7f9d2e46cc")
        #expect(Self.key.open(sealed, for: binding) == Self.zotero)
    }

    /// Each write draws a salt and a nonce of its own, so the same key set twice is sealed under two
    /// keys, with two nonces, into bytes that share nothing but their format.
    @Test func eachWriteHasASaltAndANonceOfItsOwn() throws {
        let binding = SecretBinding(owner: .user("alice"), name: "zotero")
        let writes = try (0..<64).map { _ in try Self.key.seal(Self.zotero, for: binding) }
        #expect(Set(writes.map { Array($0[1..<33]) }).count == 64, "a salt for each")
        #expect(Set(writes.map { Array($0[33..<45]) }).count == 64, "and a nonce")
        #expect(Set(writes.map { Array($0[45...]) }).count == 64, "so no two ciphertexts are the same")
        for sealed in writes {
            #expect(sealed.count == 1 + 32 + 12 + Self.zotero.count + 16 && sealed[0] == 1)
            #expect(!holds(sealed, Self.zotero), "the key is nowhere in what is kept")
            #expect(Self.key.open(sealed, for: binding) == Self.zotero)
        }
    }

    /// The tag binds whose the secret is and what it is called: it opens for its owner under its name,
    /// and for no other user, no other name, and not as the instance's, however the names are cut.
    @Test func aSecretOpensOnlyAsItsOwnersUnderItsName() throws {
        let binding = SecretBinding(owner: .user("alice"), name: "zotero")
        let sealed = try Self.key.seal(Self.zotero, for: binding)
        #expect(Self.key.open(sealed, for: binding) == Self.zotero)
        let others: [SecretBinding] = [
            SecretBinding(owner: .user("bob"), name: "zotero"), SecretBinding(owner: .user("alice"), name: "nara"),
            SecretBinding(owner: .instance, name: "zotero"), SecretBinding(owner: .user(""), name: "zotero"),
            SecretBinding(owner: .user("Alice"), name: "zotero"), SecretBinding(owner: .user("alicez"), name: "otero"),
            SecretBinding(owner: .user("alic"), name: "ezotero"), SecretBinding(owner: .user("alice\u{0}"), name: "zotero"),
            SecretBinding(owner: .instance, name: "alicezotero"),
        ]
        for other in others {
            #expect(Self.key.open(sealed, for: other) == nil, "\(other.owner) \(other.name)")
            #expect(other.bytes != binding.bytes)
        }
        let instance = try Self.key.seal(Self.zotero, for: SecretBinding(owner: .instance, name: "nara"))
        #expect(Self.key.open(instance, for: SecretBinding(owner: .user(""), name: "nara")) == nil, "the instance is no user, not one named nothing")
        #expect(Self.key.open(instance, for: SecretBinding(owner: .instance, name: "nara")) == Self.zotero)
    }

    /// Nothing opens but what was sealed: not with a bit changed anywhere, cut short, in another
    /// format, or under another key file.
    @Test func aChangedByteOpensNothing() throws {
        let binding = SecretBinding(owner: .user("alice"), name: "zotero")
        let sealed = try Self.key.seal(Self.zotero, for: binding)
        for index in sealed.indices {
            var changed = sealed
            changed[index] ^= 0x01
            #expect(Self.key.open(changed, for: binding) == nil, "byte \(index)")
        }
        for count in [0, 1, 44, 60, sealed.count - 1] {
            #expect(Self.key.open(Array(sealed.prefix(count)), for: binding) == nil, "\(count) bytes")
        }
        #expect(Self.key.open(sealed + [0], for: binding) == nil)
        #expect(SecretKey.random().open(sealed, for: binding) == nil, "another key file")
        #expect(SecretKey(Array(1..<33))?.open(sealed, for: binding) == nil)
    }

    /// A key file is 32 bytes, and its id names it without holding any of it: the same for the same
    /// bytes, another for others, and none of the key's own.
    @Test func theKeyIdNamesTheKeyAndSaysNothingOfIt() throws {
        for count in [0, 16, 31, 33, 64] { #expect(SecretKey([UInt8](repeating: 7, count: count)) == nil) }
        let (first, second) = (SecretKey.random(), SecretKey.random())
        #expect(first.bytes.count == 32 && first.bytes != second.bytes)
        #expect(first.id != second.id && first.id.count == 16 && first.id.allSatisfy(\.isHexDigit))
        #expect(SecretKey(first.bytes)?.id == first.id)
        #expect(!hex(first.bytes).contains(first.id))
    }

    /// What a key may be: what a service gives to paste, trimmed, in visible ASCII, and no reason
    /// repeats what was given.
    @Test func aKeyIsHeldToItsRule() throws {
        #expect(SecretValues.checked("  P9NiFoyLeZu2bZNvvuQPDWsd\r\n") == .success("P9NiFoyLeZu2bZNvvuQPDWsd"))
        #expect(SecretValues.checked(String(repeating: "k", count: 1_024)) == .success(String(repeating: "k", count: 1_024)))
        #expect(SecretValues.checked("a!#$%&'()*+,-./:;<=>?@[\\]^_`{|}~Z09") == .success("a!#$%&'()*+,-./:;<=>?@[\\]^_`{|}~Z09"))
        let refused = ["", "   \n", String(repeating: "k", count: 1_025), "two words", "line\nbreak", "tab\there", "nul\u{0}here",
                       "del\u{7f}", "clé", "kéy-ΑΒΓ", "smart“quotes”", "zero\u{200B}width", "header\r\nX-Injected: 1"]
        for value in refused {
            guard case .failure(let problem) = SecretValues.checked(value) else {
                Issue.record("\(value.debugDescription) was taken")
                continue
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(trimmed.count < 3 || !problem.reason.contains(trimmed), "the reason does not repeat the value")
        }
    }
}

/// The key file: made once, whole, for the server's user alone.
@Suite struct SecretKeyFileTests {
    @Test func theServerMakesItsKeyFileOnceForItsUserAlone() throws {
        let directory = try TemporaryDirectory()
        let url = directory.url.appendingPathComponent("secret.key")
        #expect(try SecretKeyFile.key(at: url) == nil, "none until one is made")
        let made = try SecretKeyFile.make(at: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "its user's alone to read")
        #expect((attributes[.size] as? NSNumber)?.intValue == 32)
        #expect(try Array(Data(contentsOf: url)) == made.bytes)
        #expect(try SecretKeyFile.key(at: url)?.id == made.id)
        #expect(try SecretKeyFile.make(at: url).id == made.id, "one that is there is kept, never replaced")
        #expect(try Array(Data(contentsOf: url)) == made.bytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.url.path) == ["secret.key"], "and nothing is left beside it")
        #expect(try SecretKeyFile.make(at: directory.url.appendingPathComponent("another.key")).id != made.id)

        let nowhere = directory.url.appendingPathComponent("missing/secret.key")
        #expect(throws: SecretKeyProblem.self) { try SecretKeyFile.make(at: nowhere) }
    }

    /// Two servers that start at once, and sixteen: each makes a key, one of them names its file
    /// `secret.key`, and every one reads that file, whole.
    @Test func serversThatStartTogetherReadOneKey() async throws {
        for _ in 0..<25 {
            let directory = try TemporaryDirectory()
            let url = directory.url.appendingPathComponent("secret.key")
            let ids = try await withThrowingTaskGroup(of: String.self) { group in
                for _ in 0..<16 { group.addTask { try SecretKeyFile.make(at: url).id } }
                var ids: Set<String> = []
                for try await id in group { ids.insert(id) }
                return ids
            }
            #expect(ids.count == 1, "one key among them")
            #expect(try SecretKeyFile.key(at: url)?.id == ids.first)
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.url.path) == ["secret.key"])
        }
    }

    /// A file that is not 32 bytes is no key file, and is said to be none, not read as one: an empty
    /// one, one cut short, a longer one, and a folder.
    @Test func aFileThatIsNoKeyFileIsRefused() throws {
        let directory = try TemporaryDirectory()
        let url = directory.url.appendingPathComponent("secret.key")
        for count in [0, 1, 31, 33, 44, 64, 4_096] {
            try Data(repeating: 0x41, count: count).write(to: url)
            #expect(throws: SecretKeyProblem.wrongSize(path: url.path, bytes: count)) { try SecretKeyFile.key(at: url) }
        }
        try Data(repeating: 0x41, count: 32).write(to: url)
        #expect(try SecretKeyFile.key(at: url)?.bytes == [UInt8](repeating: 0x41, count: 32), "the file's bytes as they are")
        #expect(throws: SecretKeyProblem.unreadable(path: directory.url.path, reason: "it is not a file")) {
            try SecretKeyFile.key(at: directory.url)
        }
    }
}

/// The vault a server starts with, and the rules it holds its key file and its store to.
@Suite struct SecretVaultTests {
    static let created = UserSecretTests.created
    static let zotero = "P9NiFoyLeZu2bZNvvuQPDWsd"

    /// The done-when's first clause, below the routes: a key written is sealed in the store, and read
    /// back through the vault alone, for its owner under its name; a row moved to another user, another
    /// name or the instance does not open.
    @Test(arguments: UserStoreKind.available) func aKeyWrittenIsReadBackThroughTheVaultAlone(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let keyFile = test.directory.url.appendingPathComponent("secret.key")
        let (vault, origin) = try SecretVault.open(store: store, keyFile: keyFile, named: false)
        #expect(origin == .made && vault.keyFile == keyFile)
        try rows.addUser("alice")
        try rows.addUser("bob")
        let alice = SecretOwner.user("alice")

        let entry = try vault.set("  \(Self.zotero)\n", named: .zotero, for: alice, at: Self.created)
        #expect(entry == SecretEntry(name: "zotero", updatedAt: Self.created))
        #expect(try vault.value(named: .zotero, for: alice) == Self.zotero, "trimmed, as the app trims a paste")
        #expect(try vault.value(named: .zotero, for: .user("bob")) == nil)
        #expect(try vault.value(named: .nara, for: alice) == nil)
        #expect(try vault.value(named: .zotero, for: .instance) == nil)
        #expect(try vault.entries(for: alice) == [.zotero: Self.created])
        #expect(try vault.entries(for: .user("bob")).isEmpty && vault.entries(for: .instance).isEmpty)

        // What the store holds: the key file's id, and bytes with the key nowhere in them.
        let kept = try #require(try store.sealedSecret(named: "zotero", of: alice))
        #expect(kept.keyID == vault.key.id && !holds(kept.sealed, Array(Self.zotero.utf8)))
        #expect(try rows.stored("SELECT count(*) FROM secrets WHERE name LIKE ? OR key_id LIKE ? OR updated_at LIKE ?",
                                Array(repeating: .text("%\(Self.zotero)%"), count: 3)) == [[.integer(0)]])

        // A row moved does not open where it was moved to, and opens again where it was sealed.
        try rows.run("UPDATE secrets SET user_id = 'bob'")
        #expect(throws: SecretError.doesNotOpen(name: "zotero")) { try vault.value(named: .zotero, for: .user("bob")) }
        try rows.run("UPDATE secrets SET user_id = 'alice', name = 'nara'")
        #expect(throws: SecretError.doesNotOpen(name: "nara")) { try vault.value(named: .nara, for: alice) }
        try rows.run("UPDATE secrets SET user_id = NULL")
        #expect(throws: SecretError.doesNotOpen(name: "nara")) { try vault.value(named: .nara, for: .instance) }
        try rows.run("UPDATE secrets SET user_id = 'alice', name = 'zotero'")
        #expect(try vault.value(named: .zotero, for: alice) == Self.zotero)

        // Set again, it is sealed again; and each owner's is its own.
        try vault.set(Self.zotero, named: .zotero, for: alice, at: Self.created)
        #expect(try store.sealedSecret(named: "zotero", of: alice)?.sealed != kept.sealed)
        try vault.set("the-instance-key", named: .nara, for: .instance, at: Self.created)
        try vault.set("bobs-own-key", named: .nara, for: .user("bob"), at: Self.created)
        #expect(try vault.value(named: .nara, for: .instance) == "the-instance-key")
        #expect(try vault.value(named: .nara, for: .user("bob")) == "bobs-own-key")
        #expect(try vault.value(named: .nara, for: alice) == nil)
        #expect(throws: SecretValueProblem.self) { try vault.set("two words", named: .nara, for: alice, at: Self.created) }
        #expect(try vault.value(named: .nara, for: alice) == nil, "a key that is none is not kept")

        #expect(try vault.remove(named: .zotero, for: alice))
        #expect(try !vault.remove(named: .zotero, for: alice))
        #expect(try vault.value(named: .zotero, for: alice) == nil)

        // The next start finds the key file, and reads what this one wrote.
        let next = try SecretVault.open(store: store, keyFile: keyFile, named: false)
        #expect(next.origin == .found && next.vault.key.id == vault.key.id)
        #expect(try next.vault.value(named: .nara, for: .instance) == "the-instance-key")
    }

    /// The done-when's second clause: a store that holds stored keys, without the key file that opens
    /// them, keeps the server from starting, and no new key file is made in its place, which would
    /// leave them unreadable for good; with the key file back it starts; and once they are forgotten
    /// it starts with a new one.
    @Test(arguments: UserStoreKind.available) func aStoreWithoutItsKeyFileRefusesToStart(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let keyFile = test.directory.url.appendingPathComponent("secret.key")
        let vault = try SecretVault.open(store: store, keyFile: keyFile, named: false).vault
        try vault.set(Self.zotero, named: .zotero, for: .user("owner"), at: Self.created)
        try vault.set("the-instance-key", named: .nara, for: .instance, at: Self.created)
        let bytes = try Data(contentsOf: keyFile)

        try FileManager.default.removeItem(at: keyFile)
        #expect(throws: SecretKeyProblem.missing(path: keyFile.path, secrets: 2)) {
            try SecretVault.open(store: store, keyFile: keyFile, named: false)
        }
        #expect(!FileManager.default.fileExists(atPath: keyFile.path), "no new key file takes its place")
        #expect(try store.secretCounts() == [vault.key.id: 2], "and the stored keys are as they were")

        try bytes.write(to: keyFile)
        let back = try SecretVault.open(store: store, keyFile: keyFile, named: false)
        #expect(back.origin == .found)
        #expect(try back.vault.value(named: .zotero, for: .user("owner")) == Self.zotero)

        try FileManager.default.removeItem(at: keyFile)
        #expect(try store.removeSecrets(notSealedUnder: nil) == 2)
        let new = try SecretVault.open(store: store, keyFile: keyFile, named: false)
        #expect(new.origin == .made && new.vault.key.id != vault.key.id)
    }

    /// A key file `FRUS_SECRET_KEY_FILE` names is the operator's: the server reads it and never makes
    /// it, whether or not the store holds a stored key, since a file missing there is a mount that is
    /// missing.
    @Test func aNamedKeyFileIsReadAndNeverMade() async throws {
        let (store, _, directory) = try await UserTagTests.open()
        let keyFile = directory.url.appendingPathComponent("mounted_key")
        #expect(throws: SecretKeyProblem.namedFileMissing(path: keyFile.path)) {
            try SecretVault.open(store: store, keyFile: keyFile, named: true)
        }
        #expect(!FileManager.default.fileExists(atPath: keyFile.path))

        try Data(SecretKeyTests.key.bytes).write(to: keyFile)
        let (vault, origin) = try SecretVault.open(store: store, keyFile: keyFile, named: true)
        #expect(origin == .found && vault.key.id == SecretKeyTests.key.id)
        try vault.set(Self.zotero, named: .zotero, for: .user("owner"), at: Self.created)
        try FileManager.default.removeItem(at: keyFile)
        #expect(throws: SecretKeyProblem.namedFileMissing(path: keyFile.path)) {
            try SecretVault.open(store: store, keyFile: keyFile, named: true)
        }
        try Data(repeating: 1, count: 16).write(to: keyFile)
        #expect(throws: SecretKeyProblem.wrongSize(path: keyFile.path, bytes: 16)) {
            try SecretVault.open(store: store, keyFile: keyFile, named: true)
        }
    }

    /// A key file that is not the one the store's keys were sealed under keeps the server from
    /// starting, as a store restored beside another install's key file would; the vault refuses each
    /// such key, by name, if it meets one; and forgetting removes those alone.
    @Test func aKeyFileThatDoesNotOpenTheStoresKeysRefusesToStart() async throws {
        let (store, _, directory) = try await UserTagTests.open()
        let keyFile = directory.url.appendingPathComponent("secret.key")
        let first = try SecretVault.open(store: store, keyFile: keyFile, named: false).vault
        try first.set(Self.zotero, named: .zotero, for: .user("owner"), at: Self.created)

        let other = SecretKey.random()
        try Data(other.bytes).write(to: keyFile)
        #expect(throws: SecretKeyProblem.anotherKey(path: keyFile.path, id: other.id, secrets: 1, sealedUnder: [first.key.id])) {
            try SecretVault.open(store: store, keyFile: keyFile, named: false)
        }
        let unopened = SecretVault(key: other, keyFile: keyFile, store: store)
        #expect(throws: SecretError.sealedUnderAnotherKey(name: "zotero", keyID: first.key.id)) {
            try unopened.value(named: .zotero, for: .user("owner"))
        }

        // With keys under both, as two servers with a key file each would leave, it names those it
        // does not open, and forgetting keeps the rest.
        try unopened.set("the-instance-key", named: .nara, for: .instance, at: Self.created)
        #expect(throws: SecretKeyProblem.anotherKey(path: keyFile.path, id: other.id, secrets: 1, sealedUnder: [first.key.id])) {
            try SecretVault.open(store: store, keyFile: keyFile, named: false)
        }
        #expect(try store.removeSecrets(notSealedUnder: other.id) == 1)
        let (vault, origin) = try SecretVault.open(store: store, keyFile: keyFile, named: false)
        #expect(origin == .found && vault.key.id == other.id)
        #expect(try vault.value(named: .nara, for: .instance) == "the-instance-key")
        #expect(try vault.value(named: .zotero, for: .user("owner")) == nil)
    }

    /// The sentences a server that does not start says are the install guide's, word for word, as the
    /// server prints them, so the guide a reader searches for one finds it.
    @Test func theGuideGivesTheSentences() throws {
        let guide = try String(contentsOf: RepositoryFiles.root.appendingPathComponent("docs/INSTALL.md"), encoding: .utf8)
        let path = "/data/app/secret.key"
        let problems: [SecretKeyProblem] = [
            .missing(path: path, secrets: 2),
            .anotherKey(path: path, id: "141c99669e6cf0cc", secrets: 2, sealedUnder: ["9f3a6c0d51e27b48"]),
            .namedFileMissing(path: "/run/secrets/frus_secret_key"),
            .postgreSQLNeedsNamedFile,
        ]
        for problem in problems {
            #expect(guide.contains("frus-light: \(problem)"), "\(problem)")
        }
        #expect(SecretKeyProblem.missing(path: path, secrets: 1).description.hasPrefix("the user store holds 1 stored key, and the key file that opens them"))
        #expect(guide.contains(SecretKeyProblem.forget + " ") && guide.contains(SecretKeyProblem.forgetAll))
    }

    /// A store that several servers open, as a PostgreSQL store is, needs the key file named: each server
    /// would otherwise make its own, and none open another's keys.
    @Test func aSharedStoreNeedsANamedKeyFile() async throws {
        let (store, _, directory) = try await UserTagTests.open()
        let own = directory.url.appendingPathComponent("secret.key")
        #expect(throws: SecretKeyProblem.postgreSQLNeedsNamedFile) { try SecretVault.open(store: store, keyFile: own, named: false, shared: true) }
        #expect(!FileManager.default.fileExists(atPath: own.path), "and makes none")
        let named = directory.url.appendingPathComponent("frus_secret_key")
        try Data(SecretKeyTests.key.bytes).write(to: named)
        #expect(try SecretVault.open(store: store, keyFile: named, named: true, shared: true).vault.key.id == SecretKeyTests.key.id)
    }

    /// `FRUS_SECRET_KEY_FILE` names the key file by its whole path, and is read only when a server
    /// starts.
    @Test func theKeyFileIsNamedByItsWholePath() throws {
        #expect(try ServerConfiguration.fromEnvironment([:]).secretKeyFile == nil)
        #expect(try ServerConfiguration.fromEnvironment(["FRUS_SECRET_KEY_FILE": "/run/secrets/frus_secret_key"]).secretKeyFile?.path
            == "/run/secrets/frus_secret_key", "though no file is there: a command that needs no stored key runs without it")
        #expect(throws: ConfigurationError(problems: [
            "FRUS_SECRET_KEY_FILE must be the key file's whole path, such as /run/secrets/frus_secret_key, not frus_secret_key",
        ])) { try ServerConfiguration.fromEnvironment(["FRUS_SECRET_KEY_FILE": "frus_secret_key"]) }
        #expect(DataDirectory(root: URL(fileURLWithPath: "/data")).secretKey.path == "/data/app/secret.key")
    }

    /// The done-when's third clause, below the route: the manifest of a backup's archive lists the
    /// table, how many keys it holds and the key file they were sealed under, and says that the archive
    /// holds no key file; neither the backup nor the archive holds a key or the key file's bytes; and a
    /// restore reports the same, for the command to say which key file the store now needs.
    @Test func aBackupCarriesTheTableAndNoKeyFile() async throws {
        let directory = try TemporaryDirectory()
        let files = try await UserStoreRestoreTests.store(in: directory, tags: ["Archived"])
        let store = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
        let vault = try SecretVault.open(store: store, keyFile: files.secretKey, named: false).vault
        #expect(files.secretKey.path.hasSuffix("/data/app/secret.key"))
        try vault.set(Self.zotero, named: .zotero, for: .user("owner"), at: Self.created)
        try vault.set("the-instance-key", named: .nara, for: .instance, at: Self.created)

        let backup = try await UserStoreRestoreTests.backUp(files)
        let expected = BackupManifest.Secrets(table: "secrets", rows: 2, keyIds: [vault.key.id], keyFileIncluded: false)
        #expect(BackupManifest.Secrets.held(in: backup) == expected)
        let source = try #require(try BackupArchiveSource.newest(in: files.backupsDirectory, copyDirectory: nil))
        #expect(source.manifest.secrets == expected)
        var archive = Data()
        try await source.write { archive.append($0) }
        let manifest = try #require(String(data: try source.manifest.encoded(), encoding: .utf8))
        #expect(manifest.contains(#""table" : "secrets""#) && manifest.contains(#""keyFileIncluded" : false"#))
        #expect(try JSONDecoder().decode(BackupManifest.self, from: source.manifest.encoded()) == source.manifest)

        let key = try Array(Data(contentsOf: files.secretKey))
        for (name, bytes) in [("the backup", try Array(Data(contentsOf: backup))), ("the archive", Array(archive))] {
            #expect(!holds(bytes, key), "\(name) holds no key file")
            #expect(!holds(bytes, Array(Self.zotero.utf8)) && !holds(bytes, Array("the-instance-key".utf8)), "\(name) holds no key as it was given")
            #expect(holds(bytes, Array(vault.key.id.utf8)), "\(name) names the key file by its id")
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.backupsDirectory.path) == [backup.lastPathComponent],
                "the backups folder holds the backup alone")

        // A manifest written before migration 5 has no such member, and reads as it did.
        var older = source.manifest
        older.secrets = nil
        #expect(!String(decoding: try older.encoded(), as: UTF8.self).contains("secrets"))
        #expect(try JSONDecoder().decode(BackupManifest.self, from: older.encoded()).secrets == nil)

        // Restored into a data directory with no key file, the store holds what it held, sealed, and the
        // server that starts over it refuses until the key file is back.
        let elsewhere = DataDirectory(root: directory.url.appendingPathComponent("elsewhere"))
        try elsewhere.prepare()
        let file = directory.url.appendingPathComponent(source.fileName)
        try archive.write(to: file)
        let report = try await UserStoreRestore.restore(file, files: elsewhere, copyDirectory: nil, now: UserStoreRestoreTests.now)
        #expect(report.secrets == expected)
        #expect(!FileManager.default.fileExists(atPath: elsewhere.secretKey.path), "a restore brings no key file")
        let restored = try await SQLiteUserStore(url: elsewhere.userStore, backupsDirectory: elsewhere.backupsDirectory)
        #expect(throws: SecretKeyProblem.missing(path: elsewhere.secretKey.path, secrets: 2)) {
            try SecretVault.open(store: restored, keyFile: elsewhere.secretKey, named: false)
        }
        try Data(key).write(to: elsewhere.secretKey)
        let opened = try SecretVault.open(store: restored, keyFile: elsewhere.secretKey, named: false).vault
        #expect(try opened.value(named: .zotero, for: .user("owner")) == Self.zotero)
        #expect(try opened.value(named: .nara, for: .instance) == "the-instance-key")
    }
}
