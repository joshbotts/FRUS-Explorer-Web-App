// Each reader's summaries on the lines of Related Documents (FRUS-Explorer#1907), Suggested Next (#1902's source,
// taken with #1907's) and Chronology (#1927), through the API, on a real socket behind a proxy that signs two users
// in: a document one user summarised shows their summary as its line for them, read from the user store the served
// index attaches, and its own text, or its head in Chronology, for the other user and for a request that names no
// one, whose lines read the index's own, which an import leaves empty.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct SummaryLinesTests {
    static let volume = UserHalfSearchTests.volume
    /// Her summary of d2, short enough to be its whole line.
    static let summary = "A quixotic proposal."
    /// d2's text and head, as the synthetic export holds them.
    static let text = SyntheticExport.documents[1].body
    static let head = SyntheticExport.documents[1].header
    /// d1 cites d2, so that Related Documents ranks d2 for d1: the synthetic export holds no archival container and no
    /// cross-reference of its own, the two sources of candidates the server's engine reads.
    static let citation = """
        INSERT INTO cross_references (source_volume_id, source_document_id, target_volume_id, target_document_id)
        VALUES ('frus1961-63v06', 'd1', 'frus1961-63v06', 'd2');
        """

    @Test func eachReadersSummaryIsTheirLineAlone() async throws {
        let fixture = try await UserDataFixture(indexed: true, edits: Self.citation, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let nobody = Browser(client: client)
            _ = try decode(Summary.self, try await alice.send(.post, "/api/v1/me/volumes/\(Self.volume)/documents/d2/summaries",
                                                           #"{"responseText": "\#(Self.summary)"}"#))

            // Related Documents: d2's row in d1's list.
            for (browser, line) in [(alice, Self.summary), (bob, Self.text), (nobody, Self.text)] {
                let response = try await browser.get("/api/v1/volumes/\(Self.volume)/documents/d1/related")
                #expect(response.status == .ok, "\(String(buffer: response.body))")
                let related = try decode(RelatedDocuments.self, response)
                #expect(related.rows.map(\.documentId) == ["d2"], "\(browser.user ?? "no one")")
                #expect(related.rows.first?.snippet == line, "\(browser.user ?? "no one")")
            }

            // Chronology: d2's row in its day, and d1's, which no one summarised, by its head.
            for (browser, line) in [(alice, Self.summary), (bob, Self.head), (nobody, Self.head)] {
                let response = try await browser.get("/api/v1/chronology?from=1960-11-01&to=1960-11-30")
                #expect(response.status == .ok, "\(String(buffer: response.body))")
                let rows = try decode(ChronologyAnswer.self, response).groups.flatMap(\.rows)
                #expect(rows.map(\.documentId) == ["d1", "d2"], "\(browser.user ?? "no one")")
                #expect(rows.map(\.snippet) == [SyntheticExport.documents[0].header, line], "\(browser.user ?? "no one")")
            }

            // Suggested Next: a lead on d2 in a project of each, as a computation leaves it.
            for (browser, line) in [(alice, Self.summary), (bob, Self.text)] {
                let user = try #require(browser.user)
                let project = try await ProjectHistoryTests.made(browser, "Grain")
                let now = UserStoreDate.text(UserDataFixture.now)
                try fixture.rows.run(
                    """
                    INSERT INTO project_leads (user_id, id, project_id, volume_id, document_id, aggregate_score, contributing_seed_keys,
                                               header, is_editorial_note, first_surfaced_at, last_computed_at, dismissed)
                        VALUES (?, ?, ?, ?, 'd2', 1, '[]', 'Lead', 0, ?, ?, 0)
                    """, [.text(user), .text(UUID().uuidString), .text(project.id), .text(Self.volume), .text(now), .text(now)])
                let leads = try await ProjectFocusTests.home(browser, project).leads
                #expect(leads.map(\.documentId) == ["d2"] && leads.map(\.snippet) == [line], "\(user)")
            }
        }
    }
}
