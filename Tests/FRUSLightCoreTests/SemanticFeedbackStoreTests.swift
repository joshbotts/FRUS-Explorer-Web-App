// The feedback on a semantic match kept for each user (PLAN's S26d, migration 9), on every store `UserStoreKind.available`
// names, by the app's `SemanticFeedbackLog`'s rules: each entry as the kit's `SemanticFeedbackEntry`, every field back as
// it was recorded; a second verdict on a pair replacing the first as the newest; the newest 2,000 of a user's kept; two
// users' verdicts apart; and a user's cleared, or gone with the user.

@testable import FRUSLightCore
import FRUSCoreKit
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct SemanticFeedbackStoreTests {
    static let recorded = Date(timeIntervalSince1970: 1_795_000_000.125)
    static let anchor = "frus1961-63v06/d1"

    static func entry(_ neighbour: String, _ verdict: SemanticFeedbackEntry.Verdict, anchor: String = anchor, cosine: Double? = 0.6834,
                      era: String? = "2", sameVolume: Bool? = true, digest: String? = "89481b18", at offset: TimeInterval = 0)
        -> SemanticFeedbackEntry {
        SemanticFeedbackEntry(recordedAt: recorded.addingTimeInterval(offset), anchor: anchor, neighbour: neighbour, verdict: verdict,
                              cosine: cosine, era: era, sameVolume: sameVolume, provenanceDigest: digest)
    }

    /// Each entry as the kit's, every field as it was recorded, its time to the store's millisecond; listed oldest first;
    /// a second verdict on a pair replacing the first, as the newest; and a row's verdict by its neighbour.
    @Test(arguments: UserStoreKind.available)
    func verdictsAreKeptAsTheAppsLogKeepsThem(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let first = Self.entry("frus1961-63v06/d2", .helpful)
        let second = Self.entry("frus1894Nicaragua/d7", .notHelpful, cosine: 0.4127, era: nil, sameVolume: false, at: 1)
        let undated = Self.entry("frus1961-63v06/d3", .helpful, anchor: "frus1894Nicaragua/d1", cosine: nil, era: nil, sameVolume: nil,
                                 digest: nil, at: 2)
        for entry in [first, second, undated] { try store.recordSemanticFeedback(entry, for: "owner") }
        let kept = try store.semanticFeedback(of: "owner")
        #expect(kept == [first, second, undated].map(Self.rounded), "every field as recorded, oldest first")
        #expect(kept.first?.recordedAt == UserStoreDate.rounded(Self.recorded))

        // A tester who changes their mind has one verdict, the newest: the app's `removeAll` of the pair, then `append`.
        let changed = Self.entry("frus1961-63v06/d2", .notHelpful, cosine: 0.7, at: 3)
        try store.recordSemanticFeedback(changed, for: "owner")
        #expect(try store.semanticFeedback(of: "owner").map(\.neighbour) == ["frus1894Nicaragua/d7", "frus1961-63v06/d3", "frus1961-63v06/d2"])
        #expect(try store.semanticFeedback(of: "owner").last == Self.rounded(changed))
        #expect(try store.semanticVerdicts(of: "owner", anchor: Self.anchor)
                == ["frus1961-63v06/d2": .notHelpful, "frus1894Nicaragua/d7": .notHelpful])
        #expect(try store.semanticVerdicts(of: "owner", anchor: "frus1894Nicaragua/d1") == ["frus1961-63v06/d3": .helpful])
        #expect(try store.semanticVerdicts(of: "owner", anchor: "frus1969-76ve09p1/d1").isEmpty)
    }

    /// A user keeps the newest 2,000, the app's `maxEntries`: past it, their oldest go, and no one else's.
    @Test(arguments: UserStoreKind.available)
    func aUserKeepsTheNewestTwoThousand(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        #expect(RelationalUserStore.semanticFeedbackLimit == 2_000)
        try rows.addUser("reader")
        try store.recordSemanticFeedback(Self.entry("frus1961-63v06/d2", .helpful), for: "reader")
        // 1,999 verdicts of the owner's, written as the store writes one, in a statement both stores read.
        try rows.run("""
            WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 1999)
            INSERT INTO semantic_feedback (user_id, anchor, neighbour, verdict, cosine, era, same_volume, provenance_digest, recorded_at)
                SELECT 'owner', 'frus1961-63v06/d1', 'frus1961-63v06/n' || i, 'helpful', 0.5, '2', 1, '89481b18', '2026-11-24T00:00:00.000Z'
                FROM n ORDER BY i
            """)
        #expect(try store.semanticFeedback(of: "owner").count == 1_999)
        try store.recordSemanticFeedback(Self.entry("frus1961-63v06/d3", .notHelpful), for: "owner")
        #expect(try store.semanticFeedback(of: "owner").count == 2_000, "the limit, and none gone")
        try store.recordSemanticFeedback(Self.entry("frus1961-63v06/d4", .helpful, at: 1), for: "owner")
        let kept = try store.semanticFeedback(of: "owner")
        #expect(kept.count == 2_000)
        #expect(kept.first?.neighbour == "frus1961-63v06/n2", "the oldest went")
        #expect(kept.suffix(2).map(\.neighbour) == ["frus1961-63v06/d3", "frus1961-63v06/d4"])
        // A verdict that replaces another keeps the count where it is.
        try store.recordSemanticFeedback(Self.entry("frus1961-63v06/n2", .notHelpful, at: 2), for: "owner")
        let replaced = try store.semanticFeedback(of: "owner")
        #expect(replaced.count == 2_000 && replaced.first?.neighbour == "frus1961-63v06/n3" && replaced.last?.neighbour == "frus1961-63v06/n2")
        #expect(try store.semanticFeedback(of: "reader").map(\.neighbour) == ["frus1961-63v06/d2"], "another user's are as they were")
    }

    /// Two users' verdicts on one pair stay apart; Clear Recorded Feedback deletes the user's alone, and a user's go with
    /// them.
    @Test(arguments: UserStoreKind.available)
    func twoUsersVerdictsStayApart(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try rows.addUser("reader")
        try rows.addUser("writer")
        try store.recordSemanticFeedback(Self.entry("frus1961-63v06/d2", .helpful), for: "owner")
        try store.recordSemanticFeedback(Self.entry("frus1961-63v06/d2", .notHelpful, cosine: 0.69), for: "reader")
        try store.recordSemanticFeedback(Self.entry("frus1961-63v06/d5", .helpful), for: "reader")
        try store.recordSemanticFeedback(Self.entry("frus1961-63v06/d6", .helpful), for: "writer")
        #expect(try store.semanticFeedback(of: "owner").map(\.verdict) == [.helpful])
        #expect(try store.semanticFeedback(of: "reader").map(\.verdict) == [.notHelpful, .helpful])
        #expect(try store.semanticVerdicts(of: "owner", anchor: Self.anchor) == ["frus1961-63v06/d2": .helpful])
        #expect(try store.semanticVerdicts(of: "reader", anchor: Self.anchor)
                == ["frus1961-63v06/d2": .notHelpful, "frus1961-63v06/d5": .helpful])

        #expect(try store.clearSemanticFeedback(of: "reader") == 2)
        #expect(try store.semanticFeedback(of: "reader").isEmpty)
        #expect(try store.semanticFeedback(of: "owner").count == 1, "another user's are as they were")
        #expect(try store.clearSemanticFeedback(of: "reader") == 0)

        // As the store's own connection does: this one's SQLite enforces no foreign key unless asked to.
        if kind == .sqlite { try rows.run("PRAGMA foreign_keys = ON") }
        try rows.run("DELETE FROM users WHERE user_id = 'writer'")
        #expect(try rows.stored("SELECT count(*) FROM semantic_feedback WHERE user_id = 'writer'") == [[.integer(0)]],
                "a user's verdicts go with the user")
    }

    /// The entry as the store gives it back: its time to the millisecond, as every time the store keeps.
    static func rounded(_ entry: SemanticFeedbackEntry) -> SemanticFeedbackEntry {
        SemanticFeedbackEntry(recordedAt: UserStoreDate.rounded(entry.recordedAt), anchor: entry.anchor, neighbour: entry.neighbour,
                              verdict: entry.verdict, cosine: entry.cosine, era: entry.era, sameVolume: entry.sameVolume,
                              provenanceDigest: entry.provenanceDigest)
    }
}
