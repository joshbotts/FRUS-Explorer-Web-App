// v1 interface 4, sessions and the job queue: small interfaces rather than files under /data. Since
// PLAN's S20b, a session is a row of the user store's `sessions` table, in app.db or the PostgreSQL
// store, written by `RelationalUserStore` (UserAccounts.swift); and since S20d each job is a row of its
// `jobs` table (UserJobs.swift), which the queue, still the process's, keeps as the job goes.

import Crypto
import Foundation

/// The token a session's cookie carries, and the id the store keys the session by (PLAN's S20b).
public enum SessionToken {
    /// A new token: 32 bytes from the system's generator, which reads the kernel's, in lowercase hex.
    public static func make() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<4).map { _ in String(format: "%016llx", generator.next() as UInt64) }.joined()
    }

    /// Whether `text` has a token's form, 64 lowercase hex digits: anything else names no session.
    public static func isWellFormed(_ text: Substring) -> Bool {
        text.utf8.count == 64 && text.utf8.allSatisfy { (0x30...0x39).contains($0) || (0x61...0x66).contains($0) }
    }

    /// The id of the session `token` signs in: its SHA-256, in lowercase hex.
    public static func id(of token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// A browser signed in under `FRUS_AUTH=local` (PLAN's S20b), as the store's `sessions` table keeps it.
public struct Session: Sendable, Equatable {
    /// The SHA-256 of the token the session's cookie carries, in lowercase hex: the table's key. The
    /// token itself is kept nowhere but in the browser.
    public let id: String
    public let userID: String
    public let createdAt: Date
    /// When a request last came with it, as the server last wrote it down.
    public var lastUsedAt: Date
    /// When it ends, unless it is ended before.
    public var expiresAt: Date

    public init(id: String, userID: String, createdAt: Date, lastUsedAt: Date, expiresAt: Date) {
        self.id = id
        self.userID = userID
        self.createdAt = UserStoreDate.rounded(createdAt)
        self.lastUsedAt = UserStoreDate.rounded(lastUsedAt)
        self.expiresAt = UserStoreDate.rounded(expiresAt)
    }
}

extension SessionStore {
    /// Keeps `session`, whatever its user's password.
    public func startSession(_ session: Session) throws { try startSession(session, passwordHash: nil) }
}

/// A session that has not expired, and the account it signs in.
public struct SignedInSession: Sendable, Equatable {
    public let session: Session
    public let account: Account
}

/// Where sessions are kept: the user store (PLAN's S20b).
public protocol SessionStore: Sendable {
    /// Keeps `session`, made at a sign-in, records the sign-in as its user's last, removes every
    /// session that has expired by then, and the user's oldest past `RelationalUserStore.mostSessions`.
    /// A user the store does not hold is `AccountStoreError.notFound`; with `passwordHash`, the hash the
    /// sign-in verified, a user who no longer has it, or has been disabled since, is
    /// `AccountStoreError.changed`, and no session is kept.
    func startSession(_ session: Session, passwordHash: String?) throws
    /// The session with `id` that has not expired at `time`, with its user's account; nil for any other.
    func session(_ id: String, at time: Date) throws -> SignedInSession?
    /// Records a use of the session at `time`, which moves its end to `expiresAt`.
    func touchSession(_ id: String, at time: Date, expiresAt: Date) throws
    /// Ends the session with `id`, if there is one.
    func endSession(_ id: String) throws
}

