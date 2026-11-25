// Search Within These Results and the fallback through the router (PLAN's S27e), over the synthetic export, its volumes
// served with the fixture volumes' shards, and the encoder's stand-in (S27b). A layer is refused in its own words and the
// encoder's: no list named, a list named in a form the server does not read, no words, and an encoder turned off for a
// ranking, a Meaning list and the fallback, though a keyword list is held with none. S14e's two users, signed in through a
// proxy, search within their own lists apart: each list held inside its user's own corpus, the other's refused; each
// layer's rows with their own tags, which My Tags counts over the layer; each layer in their own trail, its rows whole,
// under the kit's layered signature with the list's part; and each saved as their own working corpus with the app's
// account of a layer. A layer is paged, ordered and checklisted from the run the server keeps, asking the encoder nothing
// again. And the fallback lists the nearest across the series, filter-blind, saying so where the search had filters.
// Each layered list's rows are held to the kit's composer's over the fixture index in `SearchWithinParityTests`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import SemanticVectorsKit
import Testing

@testable import FRUSLightAPI

@Suite struct SearchWithinTests {
    /// A form value percent-encoded, as a browser's `URLSearchParams` writes one.
    static func encoded(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// `within`, naming the list the search `fields` found.
    static func within(_ fields: String) -> String { "within=\(encoded(fields))" }

    static let question = "the Soviet note on Berlin"
    static let questionField = "keywords=\(encoded(question))"

    static func layer(_ browser: Browser, _ query: String) async throws -> LayeredSearchResult {
        let response = try await browser.get("/api/v1/search/within?\(query)")
        #expect(response.status == .ok, "\(String(buffer: response.body))")
        return try decode(LayeredSearchResult.self, response)
    }

    static func held(_ browser: Browser, _ list: String) async throws -> HeldListSummary {
        let response = try await browser.get("/api/v1/search/held?\(within(list))")
        #expect(response.status == .ok, "\(String(buffer: response.body))")
        return try decode(HeldListSummary.self, response)
    }

    /// A layer is refused in its own words: no list named, a list in a form the server does not read, a field the held
    /// list's row does not take, and no words; and in the encoder's where it is off, for a ranking, a Meaning list and the
    /// fallback, while a keyword list is held with none, since holding it asks the encoder nothing.
    @Test func aLayerIsRefusedInItsOwnWordsAndTheEncoders() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let vectors = try await MeaningSearchTests.warmed(fixture)
        try await MeaningSearchTests.app(fixture, encoder: .none, vectors: vectors).test(.router) { client in
            let owner = Browser(client: client)
            let row = try await Self.held(owner, "keywords=treaties")
            #expect(row.kind == "keywords" && row.direction == "rankByMeaning" && row.members == 2, "\(row)")
            #expect(row.rowDescription == "Within 2 results for “treaties”" && row.backTitle == "Back to the 2 Results")
            #expect(row.startTitle == "Rank These Results by a Question" && row.fieldPrompt == "A question to rank these results by…")
            let ranking = try await owner.get("/api/v1/search/within?\(Self.questionField)&\(Self.within("keywords=treaties"))")
            #expect(ranking.status == .conflict && problemCode(ranking) == "ENCODER_OFF")
            let meaning = try await owner.get("/api/v1/search/held?\(Self.within("keywords=Berlin&by=meaning"))")
            #expect(meaning.status == .conflict && problemCode(meaning) == "ENCODER_OFF")
            let fallback = try await owner.get("/api/v1/search/fallback?keywords=zeppelin")
            #expect(fallback.status == .conflict && problemCode(fallback) == "ENCODER_OFF")
        }
        let directory = try TemporaryDirectory()
        let encoder = try MeaningSearchTests.standIn(directory)
        try await MeaningSearchTests.app(fixture, encoder: encoder, vectors: vectors).test(.router) { client in
            let owner = Browser(client: client)
            let unnamed = try await owner.get("/api/v1/search/within?\(Self.questionField)")
            #expect(unnamed.status == .badRequest && problemCode(unnamed) == "INVALID_PARAMETER")
            let sideways = try await owner.get("/api/v1/search/within?\(Self.questionField)&\(Self.within("keywords=treaties&by=sideways"))")
            #expect(sideways.status == .badRequest && problemCode(sideways) == "INVALID_PARAMETER")
            let unread = try await owner.get("/api/v1/search/within?\(Self.questionField)&\(Self.within("keywords=treaties&facets=x"))")
            #expect(unread.status == .badRequest)
            let blank = try await owner.get("/api/v1/search/within?keywords=%20&\(Self.within("keywords=treaties"))")
            #expect(blank.status == .badRequest && problemCode(blank) == "QUERY_MISSING")
            let noQuestion = try await owner.get("/api/v1/search/held?\(Self.within("keywords=&by=meaning"))")
            #expect(noQuestion.status == .badRequest && problemCode(noQuestion) == "QUERY_MISSING")
            let extra = try await owner.get("/api/v1/search/held?\(Self.within("keywords=treaties"))&keywords=Berlin")
            #expect(extra.status == .badRequest)
            let tooLong = Array(repeating: "containment", count: 2_100).joined(separator: "%20")
            let long = try await owner.get("/api/v1/search/fallback?keywords=\(tooLong)")
            #expect(long.status == .unprocessableContent && problemCode(long) == "QUERY_TOO_LONG")
        }
        await encoder.shutdown()
    }

    /// S14e's two users, signed in through the proxy, search within their lists apart: her keyword list held inside her
    /// corpus and ranked by a question, every row with her tags, which My Tags counts over the layer; the list refused to
    /// him, and his own list's rows carrying none of her tags; her layer in her trail alone, its rows whole under the kit's
    /// layered signature with the list's part and the expression that names what it ranked; and saved as her corpus with
    /// the app's account of a ranking. Then words found in her Meaning list, saved with the account of words found, and
    /// words found nowhere in it, with the empty layer's ways on.
    @Test func twoUsersSearchWithinTheirListsApart() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        let vectors = try await MeaningSearchTests.warmed(fixture)
        let directory = try TemporaryDirectory()
        let encoder = try MeaningSearchTests.standIn(directory)
        // Live, so that each request comes from the proxy's address.
        try await MeaningSearchTests.app(fixture, encoder: encoder, vectors: vectors).test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let tag = try decode(UserTag.self, try await alice.send(.post, "/api/v1/me/tags", #"{"name": "Berlin"}"#))
            #expect(try await alice.send(.put, "\(UserHalfSearchTests.d1)/tags", #"{"tagIds": ["\#(tag.id)"]}"#).status == .ok)
            let corpus = try await SearchSetTests.corpus(alice, "Treaties", "keywords=treaties")
            #expect(corpus.documentCount == 2)

            // Her keyword list, inside her corpus, ranked by a question.
            let list = "keywords=treaties&workingCorpusId=\(corpus.id)"
            let row = try await Self.held(alice, list)
            #expect(row.rowDescription == "Within 2 results for “treaties”" && row.signaturePart == "base=keywords:2:treaties", "\(row)")
            let layerQuery = "\(Self.questionField)&workingCorpusId=\(corpus.id)&\(Self.within(list))"
            let ranked = try await Self.layer(alice, layerQuery)
            #expect(ranked.total == 2 && Set(ranked.items.map(\.documentId)) == ["d1", "d2"], "\(ranked.items.map(\.documentId))")
            #expect(ranked.items.allSatisfy { $0.semanticScore != nil && $0.chip?.hasPrefix("Semantic match · ") == true })
            #expect(ranked.items.first { $0.documentId == "d1" }?.userTagIds == [tag.id], "her row carries her tag")
            #expect(ranked.layer.header == "2 results, closest first" && ranked.layer.route == LayerRoute(kind: "rankedByMeaning", unranked: 0))
            #expect(ranked.layer.strip?.first?.contains("inside the 2 documents you are searching within") == true, "\(ranked.layer.strip ?? [])")
            #expect(ranked.layer.swap?.help == "Ask “\(Self.question)” first, then find “treaties” among its closest matches")
            #expect(ranked.layer.signature.hasPrefix("route=semantic;engine=on-device;docs=2/") && ranked.layer.signature.hasSuffix(";base=keywords:2:treaties"))
            #expect(ranked.layer.renderedExpression == "route=semantic; model=embeddinggemma-2-Q8_0; ranked=2; base=keywords:2:treaties")
            let counted = try decode(SearchTagCounts.self, try await alice.get(
                "/api/v1/me/search/tags?\(Self.questionField)&workingCorpusId=\(corpus.id)&\(Self.within(list))"))
            #expect(counted.items.map(\.count) == [1], "\(counted.items)")

            // His: her corpus is not his, in the list or the layer, and his own list's rows carry none of her tags.
            let refused = try await bob.get("/api/v1/search/held?\(Self.within(list))")
            #expect(refused.status == .notFound && problemCode(refused) == "CORPUS_NOT_FOUND")
            let refusedLayer = try await bob.get("/api/v1/search/within?\(Self.questionField)&\(Self.within(list))")
            #expect(refusedLayer.status == .notFound && problemCode(refusedLayer) == "CORPUS_NOT_FOUND")
            let his = try await Self.layer(bob, "\(Self.questionField)&\(Self.within("keywords=treaties"))")
            #expect(his.total == 2 && his.items.allSatisfy { $0.userTagIds.isEmpty })
            let filtered = try await bob.get("/api/v1/search/within?\(Self.questionField)&\(Self.within("keywords=treaties&userTagIds=\(tag.id)"))")
            #expect(filtered.status == .notFound && problemCode(filtered) == "TAG_NOT_FOUND", "her tag is no filter of his list")

            // The trail: her layer, its rows whole, under the kit's layered signature; his trail holds none of it.
            try await ProjectHistoryTests.logging(alice, true)
            let search = "\(Self.questionField)&workingCorpusId=\(corpus.id)"
            let recorded = try decode(RecordedSearchRun.self, try await alice.send(
                .post, "/api/v1/me/history/searches", try ProjectHistoryTests.json(["search": search, "within": list])))
            #expect(recorded.outcome == "inserted" && recorded.search?.resultCount == 2, "\(recorded)")
            let export = try ExportRouteTests.object(try await alice.get("/api/v1/me/export"))
            let searches = try #require(export["searchHistory"] as? [[String: Any]])
            let entry = try #require(searches.first)
            #expect(searches.count == 1 && entry["queryText"] as? String == Self.question)
            #expect(entry["scopeSignature"] as? String == ranked.layer.signature, "the kit's layered signature")
            #expect(entry["renderedExpression"] as? String == ranked.layer.renderedExpression)
            #expect(entry["fetchLimit"] as? Int == 7_500 && entry["matchCount"] as? Int == 2 && entry["loadedCount"] as? Int == 2)
            #expect(entry["appliedCorpusId"] as? String == corpus.id)
            let theirs = try ExportRouteTests.object(try await bob.get("/api/v1/me/export"))
            #expect((theirs["searchHistory"] as? [[String: Any]])?.isEmpty != false, "his trail holds none of hers")

            // The capture: her layer saved as her corpus, the app's account of a ranking.
            let preview = try decode(CorpusCapturePreview.self, try await SearchSetTests.capture(
                alice, "/api/v1/me/working-corpora/capture", ["search": search, "within": list]))
            #expect(preview.documentCount == 2 && preview.sourceQuery == Self.question, "\(preview)")
            #expect(preview.sourceDescription == "Search results for “treaties”, ranked by a question (within a set of 2 documents)",
                    "\(preview.sourceDescription)")
            #expect(!preview.wasTruncated && preview.totalMatchCount == 2 && preview.truncationWarning == nil)
            let saved = try await SearchSetTests.capture(alice, "/api/v1/me/working-corpora",
                                                         ["name": "Ranked", "search": search, "within": list])
            #expect(saved.status == .created, "\(String(buffer: saved.body))")

            // Words found in her Meaning list inside her corpus, every member ranked, and their capture.
            let meaningList = "\(Self.questionField)&by=meaning&workingCorpusId=\(corpus.id)"
            let meaningRow = try await Self.held(alice, meaningList)
            #expect(meaningRow.kind == "meaning" && meaningRow.direction == "wordsInMatches" && meaningRow.members == 2, "\(meaningRow)")
            #expect(meaningRow.rowDescription == "Within 2 closest matches to “\(Self.question)”" && meaningRow.backTitle == "Back to the 2 Matches")
            #expect(meaningRow.startTitle == "Find Words in These Matches" && meaningRow.fieldPrompt == "Words to find in these matches…")
            let found = try await Self.layer(alice, "keywords=treaties&\(Self.within(meaningList))")
            let members = meaningRow.members
            #expect(found.items.allSatisfy { $0.semanticScore != nil }, "words found keep the list's chips")
            #expect(found.layer.route == LayerRoute(kind: "wordsInMatches", base: members) && found.layer.strip == nil)
            #expect(found.layer.swap?.help == "Search for “treaties” first, then rank what it finds by “\(Self.question)”")
            #expect(found.layer.signature.hasSuffix(";base=meaning:\(members):the%20Soviet%20note%20on%20Berlin"), "\(found.layer.signature)")
            // Both members hold the word, and keep the list's order and its chips.
            #expect(found.total == 2 && found.layer.header == "2 of your 2 closest matches contain these words", "\(found.layer.header)")
            #expect(found.items.first { $0.documentId == "d1" }?.userTagIds == [tag.id])
            let capture = try decode(CorpusCapturePreview.self, try await SearchSetTests.capture(
                alice, "/api/v1/me/working-corpora/capture", ["search": "keywords=treaties", "within": meaningList]))
            #expect(capture.sourceDescription == "Words found in a Meaning search’s closest matches to “\(Self.question)” — 2 of 2 (within a set of 2 documents)",
                    "\(capture.sourceDescription)")
            #expect(capture.wasTruncated && capture.totalMatchCount == nil && capture.sourceQuery == "treaties")
            #expect(capture.truncationWarning == "These documents are the ones among a Meaning search’s closest matches that contain your words, not every document that contains them. Counts taken inside this corpus are counts inside that set.")
            let nowhere = try await Self.layer(alice, "keywords=zeppelin&\(Self.within(meaningList))")
            #expect(nowhere.total == 0 && nowhere.items.isEmpty)
            let none = members == 1 ? "Your closest match does not contain these words" : "None of your \(members) closest matches contains these words"
            #expect(nowhere.layer.empty == LayerEmpty(statement: none, searchLibraryTitle: "Search the Whole Library for These Words",
                                                      backTitle: members == 1 ? "Back to the Closest Match" : "Back to the \(members) Matches"))
        }
        await encoder.shutdown()
    }

    /// A layer's rows are paged and ordered as a keyword search's kept results, from the run the served index keeps,
    /// which another page asks the encoder nothing again for; Checklist Mode's reviewed rows leave the pages and the header
    /// says how many are shown; and rows the checklist hid when the list was held are not ranked, which its row says.
    @Test func aLayerIsPagedOrderedAndCheckedFromWhatTheServerKeeps() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let directory = try TemporaryDirectory()
        let encoder = try MeaningSearchTests.standIn(directory)
        try await MeaningSearchTests.app(fixture, encoder: encoder, vectors: try await MeaningSearchTests.warmed(fixture)).test(.router) { client in
            let owner = Browser(client: client)
            // Both volumes' documents: Kennedy's two and Nicaragua's one.
            let list = "keywords=the"
            let base = "\(Self.questionField)&\(Self.within(list))"
            let whole = try await Self.layer(owner, base)
            #expect(whole.total == 3 && whole.items.count == 3, "\(whole.items.map(\.documentId))")
            let queries = await encoder.report().queries
            let page = try await Self.layer(owner, "\(base)&limit=1&offset=1")
            #expect(page.items.map(\.documentId) == [whole.items[1].documentId] && page.total == 3)
            let dated = try await Self.layer(owner, "\(base)&sort=dateAscending")
            #expect(dated.items.first?.volumeId == "frus1894Nicaragua", "1894 first")
            #expect(dated.layer.unrankedTail == nil, "a date order keeps no unranked rows together")
            #expect(await encoder.report().queries == queries, "another page and order ask the encoder nothing")
            let first = "\(whole.items[0].volumeId)/\(whole.items[0].documentId)"
            let reviewed = try await Self.layer(owner, "\(base)&reviewed=\(Self.encoded(first))")
            #expect(reviewed.total == 3 && reviewed.hidden == 1 && !reviewed.items.contains { "\($0.volumeId)/\($0.documentId)" == first })
            #expect(reviewed.layer.header.hasPrefix("2 shown · 3 results"), "\(reviewed.layer.header)")
            // The checklist hid a row when the list was held: no layer ranks it, and the list's row says so.
            let hiddenList = "\(list)&reviewed=\(first)"
            let narrower = try await Self.layer(owner, "\(Self.questionField)&\(Self.within(hiddenList))")
            #expect(narrower.total == 2 && !narrower.items.contains { "\($0.volumeId)/\($0.documentId)" == first })
            #expect(narrower.layer.base.leftOutDescription == "1 result hidden as reviewed is not included.")
            #expect(narrower.layer.base.rowDescription == "Within 2 results for “the”")
            let posted = try await owner.send(.post, "/api/v1/search/within", "\(Self.questionField)&\(Self.within(hiddenList))",
                                              contentType: "application/x-www-form-urlencoded")
            #expect(posted.status == .ok, "\(String(buffer: posted.body))")
            let postedTotal = try decode(LayeredSearchResult.self, posted).total
            #expect(postedTotal == 2)
        }
        await encoder.shutdown()
    }

    /// The fallback under a keyword search that found nothing lists the nearest across the whole series, ten at most, each
    /// with its chip, those the server holds opening by their titles, the rest by their volumes'; the caption is the kit's,
    /// in a server's words, and says the filters are not applied where the search had any.
    @Test func theFallbackListsTheNearestAcrossTheSeries() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let directory = try TemporaryDirectory()
        let encoder = try MeaningSearchTests.standIn(directory)
        try await MeaningSearchTests.app(fixture, encoder: encoder, vectors: try await MeaningSearchTests.warmed(fixture)).test(.router) { client in
            let owner = Browser(client: client)
            let plain = try decode(MeaningFallback.self, try await owner.get("/api/v1/search/fallback?\(Self.questionField)"))
            #expect(!plain.hits.isEmpty && plain.hits.count <= 10 && plain.question == Self.question)
            #expect(plain.hits.allSatisfy { $0.chip.hasPrefix("Semantic match · ") })
            #expect(plain.hits.allSatisfy { !$0.opens || ($0.displayTitle?.isEmpty == false && $0.documentLabel != nil) })
            #expect(plain.hits.filter { !$0.opens }.allSatisfy { $0.displayTitle == nil && !$0.volumeTitle.isEmpty })
            #expect(plain.caption.hasPrefix("Ranked by meaning, not keywords, across the whole series — your exact words may not appear."))
            #expect(!plain.caption.contains("Your filters are not applied here."))
            let narrowed = try decode(MeaningFallback.self, try await owner.get(
                "/api/v1/search/fallback?\(Self.questionField)&dateRangeEarliest=1962-01-01&dateRangeLatest=1962-12-31"))
            #expect(narrowed.caption.contains("Your filters are not applied here.") && narrowed.hits == plain.hits, "filter-blind")
        }
        await encoder.shutdown()
    }
}
