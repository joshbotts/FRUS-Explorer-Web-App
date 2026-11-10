// The `secrets` table (PLAN's S20c), migration 5's: the keys the server keeps for the outside services
// it calls, each a user's own or the instance's, by its name. The store holds each one sealed, and
// knows nothing of how: what seals and opens them is `SecretKey`, and what a route reads one through is
// `SecretVault` (Secrets.swift). Each method is written once, on `RelationalUserStore`, in SQL both
// stores read, and each write is one that changes nothing the kit's search reads.

import Foundation

/// Whose a secret is: one user's, or the instance's, which serves everyone who has none of their own.
public enum SecretOwner: Sendable, Hashable {
    case user(String)
    case instance
}

/// A secret as the store keeps it: sealed, with the id of the key file it was sealed under.
public struct SealedSecret: Sendable, Equatable {
    public let keyID: String
    public let sealed: [UInt8]
    public let updatedAt: Date
}

/// What the store says of a secret without opening it: its name, and when it was last set.
public struct SecretEntry: Sendable, Equatable {
    public let name: String
    public let updatedAt: Date
}

/// Where the sealed secrets are kept: the user store's `secrets` (PLAN's S20c).
public protocol SecretStore: Sendable {
    /// Keeps `sealed`, sealed under the key file `keyID` names, as `owner`'s secret `name`, in place of
    /// any they had. A user the store does not hold is `AccountStoreError.notFound`.
    @discardableResult
    func setSecret(_ sealed: [UInt8], keyID: String, named name: String, of owner: SecretOwner, at time: Date) throws -> SecretEntry
    /// `owner`'s secret `name` as it is kept, or nil when they have none.
    func sealedSecret(named name: String, of owner: SecretOwner) throws -> SealedSecret?
    /// Removes `owner`'s secret `name`; false when they had none.
    @discardableResult
    func removeSecret(named name: String, of owner: SecretOwner) throws -> Bool
    /// `owner`'s secrets, by name: what each is called and when it was set, and nothing of what it holds.
    func secretEntries(of owner: SecretOwner) throws -> [SecretEntry]
    /// How many secrets the store keeps under each key file's id, every owner's together.
    func secretCounts() throws -> [String: Int]
    /// Removes every secret that was not sealed under the key file `keyID` names, or with nil every
    /// secret, and returns how many: what `frus-light secrets forget` does for a key file that is lost.
    @discardableResult
    func removeSecrets(notSealedUnder keyID: String?) throws -> Int
}

extension RelationalUserStore: SecretStore {
    /// The rows that are `owner`'s: a user's by their id, the instance's by having none. A NULL is never
    /// equal to a value bound, so the two are written apart.
    private static func rows(of owner: SecretOwner) -> (clause: String, bindings: [SQLiteValue]) {
        switch owner {
        case .user(let id): ("user_id = ?", [.text(id)])
        case .instance: ("user_id IS NULL", [])
        }
    }

    @discardableResult
    public func setSecret(_ sealed: [UInt8], keyID: String, named name: String, of owner: SecretOwner,
                          at time: Date) throws -> SecretEntry {
        let stamp = UserStoreDate.rounded(time)
        let rows = Self.rows(of: owner)
        return try writing(outsideSearch: true) { db in
            var user = SQLiteValue.null
            if case .user(let id) = owner {
                guard try db.scalar("SELECT 1 FROM users WHERE user_id = ?", [.text(id)]) != nil else {
                    throw AccountStoreError.notFound(id)
                }
                user = .text(id)
            }
            // In one transaction, so the owner has the old one or the new one, and never none or two.
            _ = try db.query("DELETE FROM secrets WHERE \(rows.clause) AND name = ?", rows.bindings + [.text(name)])
            _ = try db.query("INSERT INTO secrets (user_id, name, key_id, sealed, updated_at) VALUES (?, ?, ?, ?, ?)",
                             [user, .text(name), .text(keyID), .blob(sealed), .text(UserStoreDate.text(stamp))])
            return SecretEntry(name: name, updatedAt: stamp)
        }
    }

    public func sealedSecret(named name: String, of owner: SecretOwner) throws -> SealedSecret? {
        let rows = Self.rows(of: owner)
        return try reading { db in
            try db.query("SELECT key_id, sealed, updated_at FROM secrets WHERE \(rows.clause) AND name = ?",
                         rows.bindings + [.text(name)]).first.map { row in
                var sealed: [UInt8] = []
                if case .blob(let bytes) = row[1] { sealed = bytes }
                return SealedSecret(keyID: row[0].text ?? "", sealed: sealed,
                                    updatedAt: row[2].text.flatMap(UserStoreDate.date) ?? Date(timeIntervalSince1970: 0))
            }
        }
    }

    @discardableResult
    public func removeSecret(named name: String, of owner: SecretOwner) throws -> Bool {
        let rows = Self.rows(of: owner)
        return try writing(outsideSearch: true) { db in
            let held = try db.scalar("SELECT 1 FROM secrets WHERE \(rows.clause) AND name = ?", rows.bindings + [.text(name)]) != nil
            if held {
                _ = try db.query("DELETE FROM secrets WHERE \(rows.clause) AND name = ?", rows.bindings + [.text(name)])
            }
            return held
        }
    }

    public func secretEntries(of owner: SecretOwner) throws -> [SecretEntry] {
        let rows = Self.rows(of: owner)
        return try reading { db in
            try db.query("SELECT name, updated_at FROM secrets WHERE \(rows.clause) ORDER BY name", rows.bindings).map {
                SecretEntry(name: $0[0].text ?? "", updatedAt: $0[1].text.flatMap(UserStoreDate.date) ?? Date(timeIntervalSince1970: 0))
            }
        }
    }

    public func secretCounts() throws -> [String: Int] {
        try reading { db in
            var counts: [String: Int] = [:]
            for row in try db.query("SELECT key_id, count(*) FROM secrets GROUP BY key_id", []) {
                counts[row[0].text ?? ""] = Int(row[1].integer ?? 0)
            }
            return counts
        }
    }

    @discardableResult
    public func removeSecrets(notSealedUnder keyID: String?) throws -> Int {
        try writing(outsideSearch: true) { db in
            let (clause, bindings): (String, [SQLiteValue]) = keyID.map { (" WHERE key_id <> ?", [.text($0)]) } ?? ("", [])
            let count = Int(try db.scalar("SELECT count(*) FROM secrets\(clause)", bindings)?.integer ?? 0)
            if count > 0 { _ = try db.query("DELETE FROM secrets\(clause)", bindings) }
            return count
        }
    }
}
