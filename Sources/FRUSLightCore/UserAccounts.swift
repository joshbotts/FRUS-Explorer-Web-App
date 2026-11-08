// Local accounts and their sessions (PLAN's S20b), `FRUS_AUTH=local`: what migration 4 keeps of a
// user, their password's hash, their role, when they were disabled and their last sign-in, and the
// `sessions` table. Each method is written once, on `RelationalUserStore`, in SQL both stores read, and
// each write is one that changes nothing the kit's search reads, so none moves the search mark.

import Foundation

/// The role an account holds, each the one before it and more (SPEC, Tenancy and roles): a reader
/// keeps their own research; a curator also corrects the index everyone shares; an admin also
/// manages the instance.
public enum AccountRole: String, Sendable, Codable, CaseIterable {
    case reader, curator, admin

    /// The roles a user of this one holds.
    public var held: [AccountRole] { Array(Self.allCases.prefix { $0 != self }) + [self] }
}

/// A user the store holds, with what `FRUS_AUTH=local` signs them in by.
public struct Account: Sendable, Equatable {
    public let id: String
    public var displayName: String
    public var role: AccountRole
    /// The Argon2id hash of their password, as its PHC string; nil for a user with none, who cannot
    /// sign in, as a user made by a proxy's sign-in or the store's own `owner` begins.
    public var passwordHash: String?
    public var disabledAt: Date?
    public var lastSignInAt: Date?
    public var createdAt: Date?

    /// Whether they can sign in: they have a password and are not disabled.
    public var canSignIn: Bool { passwordHash != nil && disabledAt == nil }
}

/// Why an account could not be changed.
public enum AccountStoreError: Error, Equatable, CustomStringConvertible {
    /// The store holds a user of this name already.
    case exists(String)
    /// The store holds no user of this name.
    case notFound(String)
    /// The user's password changed, or they were disabled, while they signed in.
    case changed(String)

    public var description: String {
        switch self {
        case .exists(let id): "There is already a user named \(id)."
        case .notFound(let id): "There is no user named \(id)."
        case .changed(let id): "\(id)'s password or account changed while they signed in."
        }
    }
}

/// Where local accounts are kept: the user store's `users` (PLAN's S20b).
public protocol AccountStore: Sendable {
    /// Makes an account at `time`, with its password's hash; a name the store holds already is
    /// `AccountStoreError.exists`.
    @discardableResult
    func addAccount(_ id: String, displayName: String, role: AccountRole, passwordHash: String, at time: Date) throws -> Account
    /// The user with this name, or nil.
    func account(_ id: String) throws -> Account?
    /// Every user the store holds, by name.
    func accounts() throws -> [Account]
    /// Gives a user a new password, ending each of their sessions.
    func setPasswordHash(_ hash: String, of id: String) throws
    func setRole(_ role: AccountRole, of id: String) throws
    /// Disables a user, at `time` unless they were already, ending each of their sessions; or enables
    /// them again.
    func setDisabled(_ disabled: Bool, of id: String, at time: Date) throws
}

/// What a name or a display name may be: the rule a proxy's header is held to (S14e), at most 256
/// bytes of UTF-8, with no control characters and nothing that was not UTF-8, and not empty once its
/// spaces are trimmed, as a name is when it is given.
public enum AccountNames {
    public static let longest = 256

    /// `name` trimmed of the spaces at its ends, or why it is no name.
    public static func checked(_ name: String) -> Result<String, AccountNameProblem> {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .failure(AccountNameProblem(reason: "A name cannot be empty.")) }
        if trimmed.utf8.count > longest {
            return .failure(AccountNameProblem(reason: "A name may be at most \(longest) bytes long."))
        }
        if trimmed.unicodeScalars.contains(where: { $0.properties.generalCategory == .control || $0 == "\u{FFFD}" }) {
            return .failure(AccountNameProblem(reason: "A name may not hold a control character."))
        }
        return .success(trimmed)
    }
}

public struct AccountNameProblem: Error, Equatable, CustomStringConvertible {
    public let reason: String
    public var description: String { reason }
}

extension RelationalUserStore: AccountStore, SessionStore {
    private static let accountColumns = "user_id, display_name, role, password_hash, disabled_at, last_sign_in_at, created_at"

    private static func account(_ row: [SQLiteValue], at offset: Int = 0) -> Account {
        Account(id: row[offset].text ?? "", displayName: row[offset + 1].text ?? "",
                role: row[offset + 2].text.flatMap(AccountRole.init(rawValue:)) ?? .reader,
                passwordHash: row[offset + 3].text, disabledAt: row[offset + 4].text.flatMap(UserStoreDate.date),
                lastSignInAt: row[offset + 5].text.flatMap(UserStoreDate.date),
                createdAt: row[offset + 6].text.flatMap(UserStoreDate.date))
    }

    private static func account(_ id: String, in db: UserStoreTransaction) throws -> Account? {
        try db.query("SELECT \(accountColumns) FROM users WHERE user_id = ?", [.text(id)]).first.map { account($0) }
    }

    /// Throws `notFound` unless the store holds `id`.
    private static func requireUser(_ id: String, in db: UserStoreTransaction) throws {
        guard try db.scalar("SELECT 1 FROM users WHERE user_id = ?", [.text(id)]) != nil else {
            throw AccountStoreError.notFound(id)
        }
    }

    private static func date(_ date: Date) -> SQLiteValue { .text(UserStoreDate.text(date)) }

    // MARK: AccountStore

    @discardableResult
    public func addAccount(_ id: String, displayName: String, role: AccountRole, passwordHash: String,
                           at time: Date) throws -> Account {
        try writing(outsideSearch: true) { db in
            guard try db.scalar("SELECT 1 FROM users WHERE user_id = ?", [.text(id)]) == nil else {
                throw AccountStoreError.exists(id)
            }
            _ = try db.query("INSERT INTO users (user_id, display_name, created_at, password_hash, role) VALUES (?, ?, ?, ?, ?)",
                             [.text(id), .text(displayName), Self.date(time), .text(passwordHash), .text(role.rawValue)])
            guard let account = try Self.account(id, in: db) else { throw AccountStoreError.notFound(id) }
            return account
        }
    }

    public func account(_ id: String) throws -> Account? {
        try reading { db in try Self.account(id, in: db) }
    }

    public func accounts() throws -> [Account] {
        try reading { db in
            try db.query("SELECT \(Self.accountColumns) FROM users ORDER BY user_id", []).map { Self.account($0) }
        }
    }

    public func setPasswordHash(_ hash: String, of id: String) throws {
        try writing(outsideSearch: true) { db in
            try Self.requireUser(id, in: db)
            _ = try db.query("UPDATE users SET password_hash = ? WHERE user_id = ?", [.text(hash), .text(id)])
            _ = try db.query("DELETE FROM sessions WHERE user_id = ?", [.text(id)])
        }
    }

    public func setRole(_ role: AccountRole, of id: String) throws {
        try writing(outsideSearch: true) { db in
            try Self.requireUser(id, in: db)
            _ = try db.query("UPDATE users SET role = ? WHERE user_id = ?", [.text(role.rawValue), .text(id)])
        }
    }

    public func setDisabled(_ disabled: Bool, of id: String, at time: Date) throws {
        try writing(outsideSearch: true) { db in
            try Self.requireUser(id, in: db)
            if disabled {
                _ = try db.query("UPDATE users SET disabled_at = coalesce(disabled_at, ?) WHERE user_id = ?",
                                 [Self.date(time), .text(id)])
                _ = try db.query("DELETE FROM sessions WHERE user_id = ?", [.text(id)])
            } else {
                _ = try db.query("UPDATE users SET disabled_at = NULL WHERE user_id = ?", [.text(id)])
            }
        }
    }

    // MARK: SessionStore

    private static let sessionColumns = "s.session_id, s.user_id, s.created_at, s.last_used_at, s.expires_at"

    /// The most sessions a user keeps: a sign-in past them ends the oldest, so that no one fills the
    /// table by signing in again and again.
    public static let mostSessions = 100

    public func startSession(_ session: Session, passwordHash: String?) throws {
        try writing(outsideSearch: true) { db in
            try Self.requireUser(session.userID, in: db)
            if let passwordHash {
                guard try db.scalar("SELECT 1 FROM users WHERE user_id = ? AND password_hash = ? AND disabled_at IS NULL",
                                    [.text(session.userID), .text(passwordHash)]) != nil else {
                    throw AccountStoreError.changed(session.userID)
                }
            }
            _ = try db.query("DELETE FROM sessions WHERE expires_at <= ?", [Self.date(session.createdAt)])
            _ = try db.query("INSERT INTO sessions (session_id, user_id, created_at, last_used_at, expires_at) VALUES (?, ?, ?, ?, ?)",
                             [.text(session.id), .text(session.userID), Self.date(session.createdAt), Self.date(session.lastUsedAt),
                              Self.date(session.expiresAt)])
            _ = try db.query(
                """
                DELETE FROM sessions WHERE user_id = ? AND session_id NOT IN (
                    SELECT session_id FROM sessions WHERE user_id = ? ORDER BY created_at DESC, session_id DESC LIMIT ?)
                """, [.text(session.userID), .text(session.userID), .integer(Int64(Self.mostSessions))])
            _ = try db.query("UPDATE users SET last_sign_in_at = ? WHERE user_id = ?", [Self.date(session.createdAt), .text(session.userID)])
        }
    }

    public func session(_ id: String, at time: Date) throws -> SignedInSession? {
        try reading { db in
            try db.query(
                """
                SELECT \(Self.sessionColumns), u.user_id, u.display_name, u.role, u.password_hash, u.disabled_at,
                       u.last_sign_in_at, u.created_at
                    FROM sessions s JOIN users u ON u.user_id = s.user_id
                    WHERE s.session_id = ? AND s.expires_at > ?
                """, [.text(id), Self.date(time)]).first.map { row in
                    let epoch = Date(timeIntervalSince1970: 0)
                    let session = Session(id: row[0].text ?? "", userID: row[1].text ?? "",
                                          createdAt: row[2].text.flatMap(UserStoreDate.date) ?? epoch,
                                          lastUsedAt: row[3].text.flatMap(UserStoreDate.date) ?? epoch,
                                          expiresAt: row[4].text.flatMap(UserStoreDate.date) ?? epoch)
                    return SignedInSession(session: session, account: Self.account(row, at: 5))
                }
        }
    }

    public func touchSession(_ id: String, at time: Date, expiresAt: Date) throws {
        try writing(outsideSearch: true) { db in
            _ = try db.query("UPDATE sessions SET last_used_at = ?, expires_at = ? WHERE session_id = ?",
                             [Self.date(time), Self.date(expiresAt), .text(id)])
        }
    }

    public func endSession(_ id: String) throws {
        try writing(outsideSearch: true) { db in
            _ = try db.query("DELETE FROM sessions WHERE session_id = ?", [.text(id)])
        }
    }
}
