// Related Documents' semantic axis through the router (PLAN's S26d), over the synthetic export, whose two volumes are
// served, with the fixture volumes' shards where the image holds every volume's. The feedback on a match: a verdict on
// a row the semantic axis scored is the app's entry, its cosine the row's own score, its era the anchor's year in the
// index in the app's banding, one volume holding both and the generation's digest; a second on the pair replaces the
// first; two users' verdicts stay apart, each row saying its own user's; Settings ▸ Data's summary; the file in the app's
// shape, the kit's export of the store's entries; Clear; and the refusals. With them a candidate whose shard the server
// lacks, dropped and its volume counted, and the semantic weight's gate; and the reach's refusals. The ranking itself is
// held to the kit's over the fixture index in `RelatedDocumentsParityTests`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct SemanticFeedbackTests {
    static let volume = UserHalfSearchTests.volume
    static let anchor = "\(volume)/d1"

    /// The router over `fixture`'s server and store, with the semantic vectors over `shards`, the fixture volumes', or
    /// the store `vectors` given.
    static func app(_ fixture: UserDataFixture, shards: URL = RepositoryFiles.semanticShards,
                    vectors: SemanticVectors? = nil) -> some ApplicationProtocol {
        let base = fixture.configuration.basePath
        return Application(router: ServedRouter(base: base, router: buildRouter(
            state: fixture.server.state, resources: fixture.server.resources, reader: fixture.server.reader, userData: fixture.services,
            vectors: vectors ?? SemanticVectors(resources: fixture.server.resources.directory, shards: shards), base: base)))
    }

    /// The semantic vectors over the fixture shards, with what a server reads once already read: the bundled pair,
    /// through this store, and `fixture`'s subject index and the lexical axis's stop words. A live test's client waits
    /// 20 s for each answer, and a debug build decoding these under the whole target's load can take longer than that
    /// (CI's x86_64 runner did, on the first list's request), so a live test reads them before its server starts.
    static func warmed(_ fixture: UserDataFixture) async throws -> SemanticVectors {
        let resources = fixture.server.resources
        let vectors = SemanticVectors(resources: resources.directory, shards: RepositoryFiles.semanticShards)
        _ = try await vectors.bundle().get()
        _ = try await Blocking.run { resources.documentSubjectIndex != nil && !RelatedDocumentsRoutes.lexicalStopwords(resources).isEmpty }
        return vectors
    }

    static func verdict(_ verdict: String, on neighbour: String, anchor: String = anchor) throws -> String {
        try ProjectHistoryTests.json(["anchor": anchor, "neighbour": neighbour, "verdict": verdict])
    }

    static func related(_ browser: Browser, _ document: String = "d1", query: String = "") async throws -> RelatedDocuments {
        try decode(RelatedDocuments.self, try await browser.get("/api/v1/volumes/\(volume)/documents/\(document)/related\(query)"))
    }

    /// The calibrated cosine the kit's re-score gives a pair over the fixture shards, before the route's clamp, whether
    /// or not the server serves either document.
    @MainActor static func pairScore(_ anchor: String, _ neighbour: String) async throws -> Double? {
        let vectors = SemanticVectors(resources: RepositoryFiles.resources, shards: RepositoryFiles.semanticShards)
        let bundle = try await vectors.bundle().get()
        let (index, corpus) = (bundle.index, bundle.corpus)
        let source = SemanticVectorsSimilaritySource(host: SemanticSimilarityHost(
            index: index, corpusVectors: corpus, shardStore: vectors, indexedVolumeIds: [], indexingPipeline: nil))
        let (from, to) = (try #require(DocumentKey(compositeString: anchor)), try #require(DocumentKey(compositeString: neighbour)))
        return await source.reScore(anchor: from, candidates: [to], floor: -.infinity)[to]
    }

    /// The bundled generation's provenance digest, as the server reads it.
    static func digest() async throws -> String {
        try await SemanticVectors(resources: RepositoryFiles.resources, shards: RepositoryFiles.semanticShards).bundle().get().provenance.digestHex
    }

    @Test func aVerdictIsTheAppsEntryKeptForEachUser() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        let vectors = try await Self.warmed(fixture)
        let digest = try await Self.digest()
        // Live, so that each request comes from the proxy's address.
        try await Self.app(fixture, vectors: vectors).test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let list = try await Self.related(alice)
            #expect(list.axes.allSatisfy { $0.available }, "every axis ranks, the semantic and the lexical among them")
            #expect(list.missingShards.isEmpty, "both served volumes' shards are held")
            let row = try #require(list.rows.first { $0.semanticScore != nil }, "a row the semantic axis scored: \(list.rows.map(\.documentId))")
            #expect(row.chips.contains { $0.axis == "semanticSimilarity" && $0.text.contains("Semantic match · ") },
                    "its chip, the kit's label: \(row.chips)")
            #expect(row.verdict == nil)
            #expect(list.rows.filter { $0.semanticScore == nil }.allSatisfy { !$0.chips.contains { $0.axis == "semanticSimilarity" } })
            let neighbour = "\(row.volumeId)/\(row.documentId)"

            let recorded = try await alice.send(.post, "/api/v1/me/semantic-feedback", try Self.verdict("helpful", on: neighbour))
            #expect(recorded.status == .ok, "\(String(buffer: recorded.body))")
            let entry = try decode(SemanticFeedbackRecorded.self, recorded)
            #expect(entry.anchor == Self.anchor && entry.neighbour == neighbour && entry.verdict == "helpful")
            // The cosine the row was ranked on, its semantic score; to twelve places, as a score read back from JSON on Linux
            // can differ in its last bit.
            #expect(String(format: "%.12f", entry.cosine ?? -1) == String(format: "%.12f", row.semanticScore ?? -2))
            #expect(entry.era == "2", "the anchor's 1960, in the Cold War's band")
            #expect(entry.sameVolume == (row.volumeId == Self.volume) && entry.provenanceDigest == digest)
            #expect(entry.recordedAt == "2026-10-24T00:00:00.000Z", "the server's clock")

            // Bob's verdict on the same pair is his: each row says its own user's.
            #expect(try await bob.send(.post, "/api/v1/me/semantic-feedback", try Self.verdict("notHelpful", on: neighbour)).status == .ok)
            #expect(try await Self.related(alice).rows.first { $0.documentId == row.documentId }?.verdict == "helpful")
            #expect(try await Self.related(bob).rows.first { $0.documentId == row.documentId }?.verdict == "notHelpful")
            let nobody = try decode(RelatedDocuments.self, try await client.execute(
                uri: "/api/v1/volumes/\(Self.volume)/documents/d1/related", method: .get, headers: [Browser.userHeader: "carol"]))
            #expect(nobody.rows.allSatisfy { $0.verdict == nil }, "a third user's rows say none")

            // A second verdict on a pair replaces the first.
            #expect(try await alice.send(.post, "/api/v1/me/semantic-feedback", try Self.verdict("notHelpful", on: neighbour)).status == .ok)
            #expect(try await Self.related(alice).rows.first { $0.documentId == row.documentId }?.verdict == "notHelpful")
            #expect(try await alice.send(.post, "/api/v1/me/semantic-feedback", try Self.verdict("helpful", on: neighbour)).status == .ok)
            let summary = try decode(SemanticFeedbackSummary.self, try await alice.get("/api/v1/me/semantic-feedback"))
            #expect(summary.total == 1 && summary.helpful == 1)
            #expect(summary.byEra == [.init(era: "2", label: "1945–1990", count: 1)], "the kit's label for the era")
            #expect(summary.address == "feedback@frusexplorer.app" && summary.fileName == "frus-semantic-feedback.json")
            let bobs = try decode(SemanticFeedbackSummary.self, try await bob.get("/api/v1/me/semantic-feedback"))
            #expect(bobs.total == 1 && bobs.helpful == 0)

            // The file is the app's: the kit's export of the user's entries, as Prepare Feedback File writes it.
            let file = try await alice.get("/api/v1/me/semantic-feedback/file")
            #expect(file.status == .ok && file.headers[.contentType] == "application/json")
            #expect(file.headers[.contentDisposition] == "attachment; filename=\"frus-semantic-feedback.json\"")
            let kept = try fixture.store.semanticFeedback(of: "alice")
            #expect(Data(buffer: file.body) == (try SemanticFeedbackEntry.exportData(kept)))
            let read = try SemanticFeedbackEntry.entries(from: Data(buffer: file.body))
            #expect(read.map(\.neighbour) == [neighbour] && read.map(\.verdict) == [.helpful] && read.first?.era == "2")

            // Clear Recorded Feedback: the user's alone.
            let cleared = try decode(SemanticFeedbackCleared.self, try await alice.send(.delete, "/api/v1/me/semantic-feedback"))
            #expect(cleared.removed == 1)
            #expect(try decode(SemanticFeedbackSummary.self, try await alice.get("/api/v1/me/semantic-feedback")).total == 0)
            #expect(try decode(SemanticFeedbackSummary.self, try await bob.get("/api/v1/me/semantic-feedback")).total == 1)
            #expect(Data(buffer: try await alice.get("/api/v1/me/semantic-feedback/file").body) == (try SemanticFeedbackEntry.exportData([])),
                    "an empty file, as the app's")
        }
    }

    @Test func aVerdictTheAxisCannotScoreIsRefused() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await Self.app(fixture).test(.router) { client in
            let owner = Browser(client: client)
            let path = "/api/v1/me/semantic-feedback"
            for (body, code) in [
                (try Self.verdict("maybe", on: "\(Self.volume)/d2"), "INVALID_FIELD"),
                (try Self.verdict("helpful", on: "nonsense"), "INVALID_FIELD"),
                (try Self.verdict("helpful", on: "frus1800nowhere/d2"), "INVALID_FIELD"),
                (try Self.verdict("helpful", on: Self.anchor), "INVALID_FIELD"),
                (#"{"anchor": "frus1961-63v06/d1", "neighbour": "frus1961-63v06/d2", "verdict": "helpful", "note": "x"}"#, "UNKNOWN_FIELD"),
                // A volume whose shard the server does not hold: the axis gives the pair no score.
                (try Self.verdict("helpful", on: "frus1955-57v01/d1"), "NOT_A_SEMANTIC_MATCH"),
            ] {
                #expect(problemCode(try await owner.send(.post, path, body)) == code, "\(body)")
            }
            #expect(problemCode(try await owner.send(.post, "\(path)?x=1", try Self.verdict("helpful", on: "\(Self.volume)/d2"))) == "UNKNOWN_PARAMETER")
            // Pairs the axis scores whose neighbour the server does not serve, a document the index lacks of a volume it
            // serves and one of a volume it does not: no list holds either, so neither is judged.
            for neighbour in ["\(Self.volume)/d3", "frus1969-76ve09p1/d1"] {
                #expect((try await Self.pairScore(Self.anchor, neighbour) ?? 0) > 0, "the axis scores \(neighbour) beside the anchor")
                let refused = try await owner.send(.post, path, try Self.verdict("helpful", on: neighbour))
                #expect(refused.status == .unprocessableContent && problemCode(refused) == "NOT_A_SEMANTIC_MATCH", "\(neighbour)")
            }
            #expect(try fixture.store.semanticFeedback(of: "owner").isEmpty, "nothing recorded")
        }
        // A server whose vectors are refused has no match to judge.
        let empty = try TemporaryDirectory()
        let refused = Application(router: ServedRouter(base: .root, router: buildRouter(
            state: fixture.server.state, resources: fixture.server.resources, reader: fixture.server.reader, userData: fixture.services,
            vectors: SemanticVectors(resources: empty.url, shards: empty.url))))
        try await refused.test(.router) { client in
            let response = try await Browser(client: client).send(.post, "/api/v1/me/semantic-feedback",
                                                                  try Self.verdict("helpful", on: "\(Self.volume)/d2"))
            #expect(response.status == .serviceUnavailable && problemCode(response) == "SEMANTIC_UNAVAILABLE")
            let list = try await Self.related(Browser(client: client))
            #expect(list.axes.first { $0.id == "semanticSimilarity" }?.available == false && list.beyondLibrary == nil)
            #expect(list.rows.allSatisfy { $0.semanticScore == nil })
        }
    }

    /// A candidate whose shard the server lacks is dropped and counted, never ranked by Hamming; an anchor whose own shard
    /// it lacks ranks nothing by meaning, though Beyond your library, from the sign bits alone, still answers; and at a
    /// semantic weight of 0 the axis runs not at all, the kit's gate.
    @Test func aCandidateWhoseShardIsMissingIsDroppedAndCounted() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let folder = try TemporaryDirectory()
        try FileManager.default.copyItem(at: RepositoryFiles.semanticShards.appendingPathComponent("\(Self.volume).vec"),
                                         to: folder.url.appendingPathComponent("\(Self.volume).vec"))
        try await Self.app(fixture, shards: folder.url).test(.router) { client in
            let owner = Browser(client: client)
            let full = try await Self.related(owner)
            #expect(full.missingShards == ["frus1894Nicaragua"], "the served volume whose shard is not held")
            #expect(full.rows.filter { $0.volumeId == "frus1894Nicaragua" }.allSatisfy { $0.semanticScore == nil })
            #expect(full.rows.contains { $0.semanticScore != nil }, "d1's own volume still ranks by meaning")
            let beyond = try #require(full.beyondLibrary, "the volumes not served that hold near documents")
            #expect(beyond.documentCount > 0 && !beyond.volumes.isEmpty && beyond.volumes.count <= 5)
            #expect(beyond.documents.isEmpty, "no document is named where its volume's shard is not held")
            #expect(beyond.volumes.allSatisfy { $0.volumeId != Self.volume && $0.volumeId != "frus1894Nicaragua" })

            let nicaragua = try decode(RelatedDocuments.self, try await owner.get("/api/v1/volumes/frus1894Nicaragua/documents/d1/related"))
            #expect(nicaragua.missingShards == ["frus1894Nicaragua"], "the anchor's own, which it asked for and ranks nothing without")
            #expect(nicaragua.rows.allSatisfy { $0.semanticScore == nil })
            #expect(nicaragua.beyondLibrary != nil, "the volume channel needs no shard")

            let off = try await Self.related(owner, query: "?weights=semanticSimilarity:0.0")
            #expect(off.missingShards.isEmpty && off.beyondLibrary == nil && off.rows.allSatisfy { $0.semanticScore == nil })
        }
    }

    @Test func theReachIsRefusedAsTheProjectIs() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        let vectors = try await Self.warmed(fixture)
        try await Self.app(fixture, vectors: vectors).test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let project = try await ProjectHistoryTests.made(alice, "Grain")
            let path = "/api/v1/me/projects/\(project.id)/reach"
            let empty = try decode(ProjectReachAnswer.self, try await alice.get(path))
            #expect(empty.volumes.isEmpty && empty.seedsProbed == 0, "no seed, nothing reached")
            let note = try await alice.send(.post, "/api/v1/me/volumes/\(Self.volume)/documents/d1/notes", try ProjectHistoryTests.json(
                ["bodyText": "A seed", "runs": nil, "userTagIds": [String](), "projectIds": [project.id], "selectedSummaryIds": [String]()]))
            #expect(note.status == .created, "\(String(buffer: note.body))")
            let reached = try decode(ProjectReachAnswer.self, try await alice.get(path))
            #expect(reached.seedsProbed == 1 && !reached.volumes.isEmpty && reached.volumes.count <= 5)
            #expect(reached.volumes.allSatisfy { $0.volumeId != Self.volume && $0.volumeId != "frus1894Nicaragua" && $0.reachingSeeds == 1 })
            #expect(reached.volumes.allSatisfy { !$0.title.isEmpty && $0.documentCount > 0 })
            #expect(try decode(ProjectReachAnswer.self, try await alice.get("\(path)?weights=semanticSimilarity:0.0")).volumes.isEmpty,
                    "the kit's gate: the axis off, no scan")
            for (query, code) in [("?weights=nonsense", "INVALID_PARAMETER"), ("?sort=date", "UNKNOWN_PARAMETER")] {
                #expect(problemCode(try await alice.get("\(path)\(query)")) == code, "\(query)")
            }
            #expect(try await bob.get(path).status == .notFound, "another user's project")
        }
        let waiting = try await UserDataFixture()
        defer { withExtendedLifetime(waiting) {} }
        try await Self.app(waiting).test(.router) { client in
            let owner = Browser(client: client)
            let project = try await ProjectHistoryTests.made(owner, "Grain")
            let response = try await owner.get("/api/v1/me/projects/\(project.id)/reach")
            #expect(response.status == .serviceUnavailable && problemCode(response) == "INDEX_NOT_READY")
        }
    }
}
