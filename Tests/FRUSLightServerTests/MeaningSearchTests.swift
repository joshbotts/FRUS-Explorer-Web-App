// Search by meaning through the router (PLAN's S27d), over the synthetic export, its two volumes served with the fixture
// volumes' shards where the image holds every volume's, and the encoder's stand-in (S27b): the status says the server
// searches by meaning where its vectors are served and its encoder can start; a search is refused in the encoder's words
// when the encoder is off, when it has no words, and when it is too long for the model, and in a sentence of its own when
// the vectors are refused. Two users signed in through a proxy (S14e) search apart: each inside their own working corpus
// alone, each row with their own tags, each run kept in their own trail under the kit's Meaning signature, and saved as
// their own working corpus with the kit's capture line. A set's members whose shard the server lacks are dropped and
// counted with their volumes, which the answer names; Checklist Mode's reviewed rows leave the pages; and a search its
// client abandons stops before it asks the shards anything. Each answer's rows are held to the kit's backend's over the
// fixture index in `MeaningSearchParityTests`.

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif
import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import SemanticVectorsKit
import Synchronization
import Testing

@testable import FRUSLightAPI

/// The fixture shards as the server holds them, with a count of what a search asked of them.
actor WatchedShards: SemanticShardSource {
    let vectors: SemanticVectors
    private(set) var asked = 0

    init(_ vectors: SemanticVectors) {
        self.vectors = vectors
    }

    func shard(for volumeID: String) async -> SemanticShard? {
        asked += 1
        return await vectors.shard(for: volumeID)
    }
}

@Suite struct MeaningSearchTests {
    static let volume = UserHalfSearchTests.volume

    /// The router over `fixture`'s server and store, the encoder `encoder`, the stand-in's by default, and the vectors
    /// over the fixture shards, or those `vectors` gives.
    static func app(_ fixture: UserDataFixture, encoder: QueryEncoder, vectors: SemanticVectors) -> some ApplicationProtocol {
        let base = fixture.configuration.basePath
        return Application(router: ServedRouter(base: base, router: buildRouter(
            state: fixture.server.state, resources: fixture.server.resources, reader: fixture.server.reader, userData: fixture.services,
            encoder: encoder, vectors: vectors, base: base)))
    }

    /// The encoder over the stand-in, in `directory`.
    static func standIn(_ directory: TemporaryDirectory, loadMilliseconds: Int = 0) throws -> QueryEncoder {
        QueryEncoder(settings: try StandInEncoder.settings(in: directory.url.appendingPathComponent("model"), loadMilliseconds: loadMilliseconds))
    }

    /// The vectors over `shards`, the bundled pair read before a live server starts, as `SemanticFeedbackTests.warmed(_:)`
    /// reads it, since a live test's client waits 20 s for an answer.
    static func warmed(_ fixture: UserDataFixture, shards: URL = RepositoryFiles.semanticShards) async throws -> SemanticVectors {
        let vectors = SemanticVectors(resources: fixture.server.resources.directory, shards: shards)
        _ = try await vectors.bundle().get()
        return vectors
    }

    static func meaning(_ browser: Browser, _ query: String) async throws -> MeaningSearchResult {
        let response = try await browser.get("/api/v1/search/meaning?\(query)")
        #expect(response.status == .ok, "\(String(buffer: response.body))")
        return try decode(MeaningSearchResult.self, response)
    }

    @Test func theStatusSaysTheServerSearchesByMeaning() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let directory = try TemporaryDirectory()
        let encoder = try Self.standIn(directory)
        try await Self.app(fixture, encoder: encoder, vectors: try await Self.warmed(fixture)).test(.router) { client in
            let status = try decode(ServerStatus.self, try await client.execute(uri: "/api/v1/status", method: .get))
            #expect(status.semantic?.encoder == true && status.semantic?.vectors == true && status.semantic?.searchByMeaning == true)
        }
        // Its vectors refused, a server searches nothing by meaning, though its encoder could start.
        let empty = try TemporaryDirectory()
        try await Self.app(fixture, encoder: encoder, vectors: SemanticVectors(resources: empty.url, shards: empty.url)).test(.router) { client in
            let status = try decode(ServerStatus.self, try await client.execute(uri: "/api/v1/status", method: .get))
            #expect(status.semantic?.encoder == true && status.semantic?.searchByMeaning == false)
            let refused = try await client.execute(uri: "/api/v1/search/meaning?keywords=Berlin", method: .get)
            #expect(refused.status == .serviceUnavailable && problemCode(refused) == "SEMANTIC_UNAVAILABLE")
        }
        await encoder.shutdown()
    }

    /// The encoder's refusals, in its words: off, no words, and a question past the model's 2,048 tokens, in the app's.
    @Test func aSearchByMeaningIsRefusedInTheEncodersWords() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let vectors = try await Self.warmed(fixture)
        try await Self.app(fixture, encoder: .none, vectors: vectors).test(.router) { client in
            let status = try decode(ServerStatus.self, try await client.execute(uri: "/api/v1/status", method: .get))
            #expect(status.semantic?.searchByMeaning == false, "an encoder turned off offers Keywords alone")
            let off = try await client.execute(uri: "/api/v1/search/meaning?keywords=Berlin", method: .get)
            #expect(off.status == .conflict && problemCode(off) == "ENCODER_OFF")
            #expect(try decode(APIProblem.Body.self, off).detail.contains("FRUS_ENCODER is off"))
        }
        let directory = try TemporaryDirectory()
        let encoder = try Self.standIn(directory)
        try await Self.app(fixture, encoder: encoder, vectors: vectors).test(.router) { client in
            let blank = try await client.execute(uri: "/api/v1/search/meaning?keywords=%20%20", method: .get)
            #expect(blank.status == .badRequest && problemCode(blank) == "QUERY_MISSING")
            let none = try await client.execute(uri: "/api/v1/search/meaning", method: .get)
            #expect(none.status == .badRequest && problemCode(none) == "QUERY_MISSING")
            let long = Array(repeating: "containment", count: 2_100).joined(separator: "%20")
            let tooLong = try await client.execute(uri: "/api/v1/search/meaning?keywords=\(long)", method: .get)
            #expect(tooLong.status == .unprocessableContent && problemCode(tooLong) == "QUERY_TOO_LONG")
            #expect(try decode(APIProblem.Body.self, tooLong).detail == EncoderRefusal.tooLongWords, "the app's words")
            let unknown = try await client.execute(uri: "/api/v1/search/meaning?keywords=Berlin&booleanMode=any", method: .get)
            #expect(unknown.status == .badRequest)
        }
        await encoder.shutdown()
    }

    /// S14e's two users, signed in through the proxy, search by meaning apart: each inside their own working corpus, every
    /// member of which is ranked; each row with their own tags; the other's corpus refused, and any for no one; each run in
    /// their own trail, its list whole under the kit's Meaning signature; and each list saved as their own working corpus,
    /// as the app captures a Meaning search's closest matches.
    @Test func twoUsersSearchByMeaningApart() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        let vectors = try await Self.warmed(fixture)
        let directory = try TemporaryDirectory()
        let encoder = try Self.standIn(directory)
        // Live, so that each request comes from the proxy's address.
        try await Self.app(fixture, encoder: encoder, vectors: vectors).test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let tag = try decode(UserTag.self, try await alice.send(.post, "/api/v1/me/tags", #"{"name": "Berlin"}"#))
            #expect(try await alice.send(.put, "\(UserHalfSearchTests.d1)/tags", #"{"tagIds": ["\#(tag.id)"]}"#).status == .ok)
            let corpus = try await SearchSetTests.corpus(alice, "Treaties", "keywords=treaties")
            #expect(corpus.documentCount == 2)

            let inside = try await Self.meaning(alice, "keywords=the%20Soviet%20note%20on%20Berlin&workingCorpusId=\(corpus.id)")
            #expect(inside.meaning.disclosure.rankedWithin == 2 && inside.meaning.disclosure.rankedCount == 2, "every member ranked")
            #expect(Set(inside.items.map(\.documentId)) == ["d1", "d2"] && inside.total == 2)
            #expect(inside.items.allSatisfy { $0.semanticScore != nil && $0.chip?.hasPrefix("Semantic match · ") == true })
            #expect(inside.items.allSatisfy { $0.bm25Score == -($0.semanticScore ?? 0) }, "the negated cosine orders the date's ties")
            #expect(inside.items.first { $0.documentId == "d1" }?.userTagIds == [tag.id], "her row carries her tag")
            #expect(inside.meaning.strip.first?.contains("inside the 2 documents you are searching within") == true, "\(inside.meaning.strip)")
            #expect(inside.meaning.signature.hasPrefix("route=semantic;engine=on-device;docs=2/"), "the kit's Meaning signature")
            #expect(inside.meaning.renderedExpression == "route=semantic; model=embeddinggemma-2-Q8_0; top=100")
            // My Tags counts her tags over the rows her search by meaning listed, as the Mac counts a Meaning list's.
            let counted = try decode(SearchTagCounts.self, try await alice.get(
                "/api/v1/me/search/tags?keywords=the%20Soviet%20note%20on%20Berlin&workingCorpusId=\(corpus.id)&mode=meaning"))
            #expect(counted.items.map(\.count) == [1], "\(counted.items)")
            let wrongMode = try await alice.get("/api/v1/me/search/tags?keywords=Berlin&mode=sideways")
            #expect(wrongMode.status == .badRequest && problemCode(wrongMode) == "INVALID_FIELD")

            // Bob's search of the same question is his: the corpus is not his, and his rows carry none of her tags.
            let refused = try await bob.get("/api/v1/search/meaning?keywords=the%20Soviet%20note%20on%20Berlin&workingCorpusId=\(corpus.id)")
            #expect(refused.status == .notFound && problemCode(refused) == "CORPUS_NOT_FOUND")
            let his = try await Self.meaning(bob, "keywords=the%20Soviet%20note%20on%20Berlin")
            #expect(his.items.allSatisfy { $0.userTagIds.isEmpty } && his.meaning.disclosure.rankedWithin == nil)
            #expect(his.meaning.signature == "route=semantic;engine=on-device", "the series' signature, as every Meaning row's before #1577")
            let filtered = try await bob.get("/api/v1/search/meaning?keywords=Berlin&userTagIds=\(tag.id)")
            #expect(filtered.status == .notFound && problemCode(filtered) == "TAG_NOT_FOUND", "her tag is no filter of his")
            let nobody = try await client.execute(uri: "/api/v1/search/meaning?keywords=Berlin&workingCorpusId=\(corpus.id)", method: .get)
            #expect(problemCode(nobody) == "CORPUS_NOT_FOUND", "a request that names no one searches inside no one's corpus")

            // The trail: her run recorded as a Meaning run, its list whole, under the kit's signature; his trail holds none of it.
            try await ProjectHistoryTests.logging(alice, true)
            let record = try ProjectHistoryTests.json([
                "search": "keywords=the%20Soviet%20note%20on%20Berlin&workingCorpusId=\(corpus.id)", "mode": "meaning"])
            let recorded = try decode(RecordedSearchRun.self, try await alice.send(.post, "/api/v1/me/history/searches", record))
            #expect(recorded.outcome == "inserted" && recorded.search?.resultCount == 2, "\(recorded)")
            let export = try ExportRouteTests.object(try await alice.get("/api/v1/me/export"))
            let searches = try #require(export["searchHistory"] as? [[String: Any]])
            let row = try #require(searches.first)
            #expect(searches.count == 1 && row["queryText"] as? String == "the Soviet note on Berlin")
            #expect(row["scopeSignature"] as? String == inside.meaning.signature, "the kit's semanticSignature(for:)")
            #expect(row["renderedExpression"] as? String == inside.meaning.renderedExpression)
            #expect(row["fetchLimit"] as? Int == 100 && row["matchCount"] as? Int == 2 && row["loadedCount"] as? Int == 2)
            #expect(row["appliedCorpusId"] as? String == corpus.id)
            let bad = try await alice.send(.post, "/api/v1/me/history/searches",
                                           try ProjectHistoryTests.json(["search": "keywords=Berlin", "mode": "sideways"]))
            #expect(bad.status == .badRequest && problemCode(bad) == "INVALID_FIELD")
            let theirs = try ExportRouteTests.object(try await bob.get("/api/v1/me/export"))
            #expect((theirs["searchHistory"] as? [[String: Any]])?.isEmpty != false, "his trail holds none of hers")

            // The capture: her list saved as her corpus, the app's Meaning capture.
            let search = "keywords=the%20Soviet%20note%20on%20Berlin&workingCorpusId=\(corpus.id)"
            let preview = try decode(CorpusCapturePreview.self, try await SearchSetTests.capture(
                alice, "/api/v1/me/working-corpora/capture", ["search": search, "mode": "meaning"]))
            #expect(preview.documentCount == 2 && preview.sourceDescription.hasPrefix("Meaning search — the 2 closest matches"))
            #expect(preview.wasTruncated && preview.totalMatchCount == nil && preview.sourceQuery == "the Soviet note on Berlin")
            #expect(preview.truncationWarning?.hasPrefix("These documents are the closest matches a Meaning search found") == true)
            #expect(preview.narrowing == ["within a set of 2 documents"], "\(preview.narrowing)")
            let saved = try await SearchSetTests.capture(alice, "/api/v1/me/working-corpora",
                                                         ["name": "Closest", "search": search, "mode": "meaning"])
            #expect(saved.status == .created, "\(String(buffer: saved.body))")
            let closest = try decode(WorkingCorpus.self, saved)
            #expect(closest.isMeaningCapture && closest.documentCount == 2 && closest.wasTruncatedAtCapture == true)
            #expect(closest.totalMatchCountAtCapture == nil && closest.truncationLine == "The 2 closest matches of a Meaning search")
            #expect(!closest.truncationWarns, "the quiet line, not the amber one")
            let hers = try decode(WorkingCorpusList.self, try await alice.get("/api/v1/me/working-corpora"))
            let bobs = try decode(WorkingCorpusList.self, try await bob.get("/api/v1/me/working-corpora"))
            #expect(hers.items.map(\.name).sorted() == ["Closest", "Treaties"] && bobs.items.isEmpty)
        }
        await encoder.shutdown()
    }

    /// A set's members whose volume's shard the server lacks are dropped, never ranked by Hamming, and counted with their
    /// volume, which the answer names, as the strip says in the server's words; over the series, the candidates in
    /// volumes it lacks are counted, and the volumes asked for named.
    @Test func membersWhoseShardIsMissingAreCountedWithTheirVolume() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        // The fixture shards less Nicaragua's.
        let shards = try TemporaryDirectory()
        for volume in [Self.volume, "frus1969-76ve09p1"] {
            try FileManager.default.copyItem(at: RepositoryFiles.semanticShards.appendingPathComponent("\(volume).vec"),
                                             to: shards.url.appendingPathComponent("\(volume).vec"))
        }
        let directory = try TemporaryDirectory()
        let encoder = try Self.standIn(directory)
        try await Self.app(fixture, encoder: encoder, vectors: try await Self.warmed(fixture, shards: shards.url)).test(.router) { client in
            let owner = Browser(client: client)
            // Both volumes' documents: Kennedy's two and Nicaragua's one.
            let corpus = try await SearchSetTests.corpus(owner, "All", "keywords=the")
            #expect(corpus.documentCount == 3, "\(corpus)")
            let inside = try await Self.meaning(owner, "keywords=Gresham&workingCorpusId=\(corpus.id)")
            let disclosure = inside.meaning.disclosure
            #expect(disclosure.rankedWithin == 3 && disclosure.unscoredCandidates == 1 && disclosure.unscoredVolumes == 1)
            #expect(disclosure.rankedCount == 2 && inside.items.map(\.volumeId) == [Self.volume, Self.volume])
            #expect(inside.meaning.missingShards == ["frus1894Nicaragua"], "the volume it asked for")
            #expect(inside.meaning.strip.contains("1 document in 1 volume could not be ranked: their match files are not on this server."),
                    "\(inside.meaning.strip)")
            let series = try await Self.meaning(owner, "keywords=Gresham")
            #expect(series.meaning.disclosure.unscoredCandidates > 0 && series.meaning.disclosure.unscoredVolumes > 0)
            #expect(!series.meaning.missingShards.isEmpty && !series.meaning.missingShards.contains(Self.volume))
            #expect(series.meaning.strip.contains { $0.hasSuffix("could not be scored. This server does not hold their match files.") })
        }
        await encoder.shutdown()
    }

    /// A run's rows are paged and ordered as a keyword search's kept results, from the run the served index keeps, which
    /// another page asks the encoder nothing again for; and Checklist Mode's reviewed rows leave the pages, which count
    /// them as hidden, in a GET's address or in a POST's body.
    @Test func aRunIsPagedOrderedAndCheckedFromWhatTheServerKeeps() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let directory = try TemporaryDirectory()
        let encoder = try Self.standIn(directory)
        try await Self.app(fixture, encoder: encoder, vectors: try await Self.warmed(fixture)).test(.router) { client in
            let owner = Browser(client: client)
            let corpus = try await SearchSetTests.corpus(owner, "All", "keywords=the")
            let base = "keywords=Gresham&workingCorpusId=\(corpus.id)"
            let whole = try await Self.meaning(owner, base)
            #expect(whole.total == 3 && whole.items.count == 3)
            let queries = await encoder.report().queries
            let page = try await Self.meaning(owner, "\(base)&limit=1&offset=1")
            #expect(page.items.map(\.documentId) == [whole.items[1].documentId] && page.total == 3)
            let dated = try await Self.meaning(owner, "\(base)&sort=dateAscending")
            #expect(dated.items.map(\.volumeId) == ["frus1894Nicaragua", Self.volume, Self.volume], "1894 first")
            #expect(await encoder.report().queries == queries, "another page and order ask the encoder nothing")
            let first = "\(whole.items[0].volumeId)/\(whole.items[0].documentId)"
            let reviewed = try await Self.meaning(owner, "\(base)&reviewed=\(first.replacingOccurrences(of: "/", with: "%2F"))")
            #expect(reviewed.total == 3 && reviewed.hidden == 1 && !reviewed.items.contains { "\($0.volumeId)/\($0.documentId)" == first })
            let posted = try await owner.send(.post, "/api/v1/search/meaning", "\(base)&reviewed=\(first)",
                                              contentType: "application/x-www-form-urlencoded")
            #expect(posted.status == .ok, "\(String(buffer: posted.body))")
            let hidden = try decode(MeaningSearchResult.self, posted).hidden
            #expect(hidden == 1)
        }
        await encoder.shutdown()
    }

    /// A search whose client closes its connection while the encoder starts stops at the encoder: its exchange with the
    /// child is cut short, or, ended first, the encoding sees the cancellation. Once the encoder has done with its
    /// question it asks the shards nothing, and it keeps no run: a search of another question whose client stays runs,
    /// asks the shards and is kept, and after as long again as that one took, it is the only run kept, where an abandoned
    /// search that ran on would have been kept beside it.
    @Test func aSearchWhoseClientLeavesStops() async throws {
        let fixture = try await servingSyntheticExport()
        let provider = ServedIndexProvider(state: fixture.state, resources: fixture.resources,
                                           volumesDirectory: fixture.files.volumesDirectory)
        let directory = try TemporaryDirectory()
        // A start slow enough to close the connection during it.
        let encoder = try Self.standIn(directory, loadMilliseconds: 2_000)
        let vectors = SemanticVectors(resources: fixture.resources.directory, shards: RepositoryFiles.semanticShards)
        _ = try await vectors.bundle().get()
        let shards = WatchedShards(vectors)
        let router = Router(context: APIRequestContext.self)
        router.add(middleware: ProblemMiddleware(logger: Logger(label: "test")))
        MeaningSearchRoutes.add(to: router, provider: provider, resources: fixture.resources, users: SearchUsers(services: nil),
                                engine: .init(encoder: encoder, vectors: vectors, shards: shards))
        // Built as the server builds its own, with its watch of each connection's client.
        let app = apiApplication(router: router, configuration: .init(address: .hostname("127.0.0.1", port: 0)), logger: Logger(label: "test"))
        try await app.test(.live) { client in
            let connection = try RawConnection(port: try #require(client.port))
            try connection.send("GET /api/v1/search/meaning?keywords=Berlin HTTP/1.1\r\nHost: localhost\r\n\r\n")
            #expect(try await eventuallyAsync { await encoder.report().state == "starting" }, "the search reached the encoder")
            connection.close()
            #expect(try await eventuallyAsync { await encoder.report().state == "loaded" }, "the encoder started")
            // The encoder has done with the abandoned question, whether it embedded it or its exchange was cut short.
            #expect(try await eventuallyAsync { await encoder.report().lastQueryAt != nil }, "the question reached the encoder")
            let served = try await provider.served()
            let askedWhenLeft = await shards.asked
            #expect(askedWhenLeft == 0, "the abandoned search asked the shards nothing")

            let began = ContinuousClock.now
            let response = try await client.execute(uri: "/api/v1/search/meaning?keywords=Cuba", method: .get)
            #expect(response.status == .ok, "\(String(buffer: response.body))")
            let took = ContinuousClock.now - began
            let asked = await shards.asked
            #expect(asked > 0, "a search whose client stays asks the shards")
            try await Task.sleep(for: min(took, .seconds(10)))
            let kept = await served.meaning.count
            #expect(kept == 1, "the run of the search whose client stayed is the only one kept")
        }
        await encoder.shutdown()
    }
}
