// The feedback on a semantic match (PLAN's S26d): each user's verdicts on Related Documents' semantic rows, kept in
// `semantic_feedback` (migration 9) as the app's `SemanticFeedbackLog` keeps a device's in its file. An entry is the
// kit's `SemanticFeedbackEntry` (FRUS-Explorer#1980). The log's rules, which are the app's and mirrored here, held to its
// source by `RelatedDocumentsParityTests`: a second verdict on a pair replaces the first and is the newest, a user keeps
// the newest 2,000, and the verdicts are listed oldest first. Written once, on `RelationalUserStore`, in SQL both stores
// read; no write touches what the kit's search reads.

import FRUSCoreKit
import Foundation

/// What the store keeps of the verdicts each user gives on Related Documents' semantic matches.
public protocol SemanticFeedbackStore: Sendable {
    /// Records `entry` as `user`'s (`SemanticFeedbackLog.record`): it replaces any verdict of theirs on the pair it
    /// names, as their newest, and past `semanticFeedbackLimit` their oldest go.
    func recordSemanticFeedback(_ entry: SemanticFeedbackEntry, for user: String) throws
    /// `user`'s verdicts, oldest first (`SemanticFeedbackLog.entries()`).
    func semanticFeedback(of user: String) throws -> [SemanticFeedbackEntry]
    /// `user`'s verdicts on the neighbours of `anchor`, a `volumeId/documentId`, by the neighbour's.
    func semanticVerdicts(of user: String, anchor: String) throws -> [String: SemanticFeedbackEntry.Verdict]
    /// Deletes every verdict of `user`'s (`SemanticFeedbackLog.clear()`), and gives how many there were.
    @discardableResult
    func clearSemanticFeedback(of user: String) throws -> Int
}

extension RelationalUserStore: SemanticFeedbackStore {
    /// The verdicts' table, which an erasure of a user's research empties of theirs too.
    public static let semanticFeedbackTable = "semantic_feedback"
    /// The verdicts a user keeps: the app's log keeps 2,000 a device (`SemanticFeedbackLog.maxEntries`).
    public static let semanticFeedbackLimit = 2_000

    public func recordSemanticFeedback(_ entry: SemanticFeedbackEntry, for user: String) throws {
        try writing(outsideSearch: true) { db in
            // The pair's earlier verdict goes, and this one is written after every other, so that `rowid` orders the
            // user's verdicts as the app's log does: `removeAll` of the pair, then `append`.
            _ = try db.query("DELETE FROM semantic_feedback WHERE user_id = ? AND anchor = ? AND neighbour = ?",
                             [.text(user), .text(entry.anchor), .text(entry.neighbour)])
            _ = try db.query("""
                INSERT INTO semantic_feedback (user_id, anchor, neighbour, verdict, cosine, era, same_volume, provenance_digest,
                                               recorded_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, [.text(user), .text(entry.anchor), .text(entry.neighbour), .text(entry.verdict.rawValue),
                      entry.cosine.map(SQLiteValue.real) ?? .null, entry.era.map(SQLiteValue.text) ?? .null,
                      entry.sameVolume.map { .integer($0 ? 1 : 0) } ?? .null,
                      entry.provenanceDigest.map(SQLiteValue.text) ?? .null,
                      .text(UserStoreDate.text(UserStoreDate.rounded(entry.recordedAt)))])
            // `rows.removeFirst(rows.count - maxEntries)`: the oldest past the limit.
            _ = try db.query("""
                DELETE FROM semantic_feedback WHERE user_id = ? AND rowid NOT IN (
                    SELECT rowid FROM semantic_feedback WHERE user_id = ? ORDER BY rowid DESC LIMIT ?)
                """, [.text(user), .text(user), .integer(Int64(Self.semanticFeedbackLimit))])
        }
    }

    public func semanticFeedback(of user: String) throws -> [SemanticFeedbackEntry] {
        try reading { db in
            try db.query("""
                SELECT anchor, neighbour, verdict, cosine, era, same_volume, provenance_digest, recorded_at
                    FROM semantic_feedback WHERE user_id = ? ORDER BY rowid
                """, [.text(user)]).compactMap(Self.feedbackEntry)
        }
    }

    public func semanticVerdicts(of user: String, anchor: String) throws -> [String: SemanticFeedbackEntry.Verdict] {
        try reading { db in
            var verdicts: [String: SemanticFeedbackEntry.Verdict] = [:]
            for row in try db.query("SELECT neighbour, verdict FROM semantic_feedback WHERE user_id = ? AND anchor = ? ORDER BY rowid",
                                    [.text(user), .text(anchor)]) {
                guard let neighbour = row[0].text, let verdict = row[1].text.flatMap(SemanticFeedbackEntry.Verdict.init(rawValue:))
                else { continue }
                verdicts[neighbour] = verdict
            }
            return verdicts
        }
    }

    @discardableResult
    public func clearSemanticFeedback(of user: String) throws -> Int {
        try writing(outsideSearch: true) { db in
            let held = Int(try db.scalar("SELECT count(*) FROM semantic_feedback WHERE user_id = ?", [.text(user)])?.integer ?? 0)
            _ = try db.query("DELETE FROM semantic_feedback WHERE user_id = ?", [.text(user)])
            return held
        }
    }

    /// A row as the kit's entry, or nil for one whose pair, verdict or time cannot be read, which the app's log, decoding
    /// its file whole, would not hold.
    private static func feedbackEntry(_ row: [SQLiteValue]) -> SemanticFeedbackEntry? {
        guard let anchor = row[0].text, let neighbour = row[1].text,
              let verdict = row[2].text.flatMap(SemanticFeedbackEntry.Verdict.init(rawValue:)),
              let recordedAt = row[7].text.flatMap(UserStoreDate.date)
        else { return nil }
        let cosine: Double? = switch row[3] {
        case .real(let value): value
        case .integer(let value): Double(value)
        case .text(let value): Double(value)
        case .null, .blob: nil
        }
        return SemanticFeedbackEntry(recordedAt: recordedAt, anchor: anchor, neighbour: neighbour, verdict: verdict, cosine: cosine,
                                     era: row[4].text, sameVolume: row[5].integer.map { $0 != 0 }, provenanceDigest: row[6].text)
    }
}
