// Saved searches, working corpora and volume scopes through the API (PLAN's S17e): a saved search
// keeps its whole search as the Mac's archives it, is recalled with the kit's watermark stamped from
// its own count, and says "+N since last run" by the kit's rules; a working corpus is captured from
// the rows a search shows, with what the app's capture says of them, is listed and opened as Browse's
// axis shows it, and gates a search through every route; a volume scope resolves as the kit resolves
// one; Checklist Mode's reviewed rows leave the pages and the timeline, not the count; and each user's
// are theirs alone.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct SearchSetTests {
    static let volume = UserHalfSearchTests.volume
    static let stranger = "5E17E000-0000-4000-8000-0000000000FF"

    static func saved(_ browser: Browser, _ name: String, _ search: String) async throws -> SavedSearch {
        let body = try JSONSerialization.data(withJSONObject: ["name": name, "search": search])
        let response = try await browser.send(.post, "/api/v1/me/saved-searches", String(decoding: body, as: UTF8.self))
        #expect(response.status == .created, "\(String(buffer: response.body))")
        return try decode(SavedSearch.self, response)
    }

    static func freshness(_ browser: Browser, _ id: String) async throws -> SavedSearchFreshnessResult {
        let response = try await browser.send(.post, "/api/v1/me/saved-searches/\(id)/freshness")
        #expect(response.status == .ok, "\(String(buffer: response.body))")
        return try decode(SavedSearchFreshnessResult.self, response)
    }

    static func capture(_ browser: Browser, _ path: String, _ fields: [String: Any]) async throws -> TestResponse {
        let body = try JSONSerialization.data(withJSONObject: fields)
        return try await browser.send(.post, path, String(decoding: body, as: UTF8.self))
    }

    static func corpus(_ browser: Browser, _ name: String, _ search: String, reviewed: [String] = []) async throws -> WorkingCorpus {
        let response = try await capture(browser, "/api/v1/me/working-corpora", ["name": name, "search": search, "reviewed": reviewed])
        #expect(response.status == .created, "\(String(buffer: response.body))")
        return try decode(WorkingCorpus.self, response)
    }

    /// A saved search keeps its whole search, as `SavedSearch.init(name:parameters:)` writes it, its
    /// name trimmed; is listed newest first and found by its id in any case; renamed as given; and
    /// deleted. A recall's search is its query fields, with nothing the API cannot take.
    @Test func aSavedSearchKeepsItsWholeSearch() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let query = "keywords=treaties&volumeIds=\(Self.volume)&dateRangeEarliest=1960-01-01&dateRangeLatest=1960-12-31"
                + "&includeNotes=false&excludedTerms=canal"
            let search = try await Self.saved(owner, "  Treaties  ", query)
            #expect(search.name == "Treaties" && search.queryText == "treaties")
            #expect(search.search == ["keywords": ["treaties"], "volumeIds": [Self.volume], "dateRangeEarliest": ["1960-01-01"],
                                      "dateRangeLatest": ["1960-12-31"], "includeNotes": ["false"], "excludedTerms": ["canal"]])
            #expect(search.notRecalled.isEmpty && search.lastRunAt == nil && search.matchCountAtLastRun == nil)
            #expect(search.createdAt == UserStoreDate.text(UserDataFixture.now) && search.lastModified == search.createdAt)

            // The columns the app's initialiser writes beside the whole search, which it archives.
            let row = try #require(try fixture.store.searchSet(.savedSearches, id: search.id, of: "owner"))
            #expect(row.values["query_text"] == .text("treaties") && row.values["scope_flags"] == .integer(3))
            #expect(row.values["excluded_terms_csv"] == .text("canal") && row.values["sort_order"] == .text("relevance"))
            #expect(row.values["date_range_start"]?.text?.hasPrefix("1960-01-01") == true)
            #expect(row.values["freshness_data"] == .null, "never run")
            let archived = try #require(row.values["parameters_data"]?.text)
            let parameters = try JSONDecoder().decode(SearchParameters.self, from: Data(archived.utf8))
            #expect(parameters == (try SearchRequest(formEncoded: query).parameters))

            // An older one, as an import leaves it, comes after; a Mac's that sets what the API does
            // not take says so, and its recall runs without its own gates.
            var mac = SearchParameters(keywords: "canal", booleanMode: .or, documentIds: ["frus1894Nicaragua/d1"])
            mac.subjectRef = "rec00812a40defabcb"
            let older = SavedSearchExport(id: UUID(), name: "Mac's", parameters: mac,
                                          createdAt: UserDataFixture.now.addingTimeInterval(-86_400))
            try fixture.store.addSearchSet(.savedSearches, MacImport.savedSearch(older).values, for: "owner")
            let list = try await UserHalfSearchTests.answer(SavedSearchList.self, owner, "/api/v1/me/saved-searches")
            #expect(list.items.map(\.name) == ["Treaties", "Mac's"])
            #expect(list.items[1].search == ["keywords": ["canal"]], "no documentIds: a recall runs inside the screen's corpus alone")
            #expect(list.items[1].notRecalled == ["booleanMode", "subjectRef"])
            let found = try await UserHalfSearchTests.answer(SavedSearch.self, owner, "/api/v1/me/saved-searches/\(search.id.lowercased())")
            #expect(found == search)

            // Rename takes the name as given, as the sheet's alert does.
            let renamed = try decode(SavedSearch.self, try await owner.send(.patch, "/api/v1/me/saved-searches/\(search.id)",
                                                                             #"{"name": " Treaty talks "}"#))
            #expect(renamed.name == " Treaty talks " && renamed.search == search.search)
            #expect(try await owner.send(.delete, "/api/v1/me/saved-searches/\(search.id)").status == .noContent)
            let gone = try await owner.get("/api/v1/me/saved-searches/\(search.id)")
            #expect(gone.status == .notFound && problemCode(gone) == "SAVED_SEARCH_NOT_FOUND")

            // A name with nothing in it, and a tag that is not theirs, are refused.
            let unnamed = try await owner.send(.post, "/api/v1/me/saved-searches", #"{"name": "   ", "search": "keywords=x"}"#)
            #expect(unnamed.status == .badRequest && problemCode(unnamed) == "INVALID_FIELD")
            let stranger = try await owner.send(.post, "/api/v1/me/saved-searches",
                                                #"{"name": "Tagged", "search": "keywords=x&userTagIds=\#(Self.stranger)"}"#)
            #expect(stranger.status == .notFound && problemCode(stranger) == "TAG_NOT_FOUND")
        }
    }

    /// A recall stamps the run with the saved search's own count, the user's half in it, and the
    /// volumes the index holds; "+N since last run" is the kit's verdict over a later count, a
    /// baseline that never was is backfilled and shows nothing, and fewer results show nothing.
    @Test func aRecallStampsTheRunAndTheBadgeCountsWhatIsNew() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            _ = try await owner.send(.post, "\(UserHalfSearchTests.d1)/notes", NoteJSON(bodyText: "A zanzibar cable").json)
            let search = try await Self.saved(owner, "Zanzibar", "keywords=zanzibar")
            #expect(try await Self.freshness(owner, search.id).newResults == nil, "never run: nothing counted")

            let run = try decode(SavedSearch.self, try await owner.send(.post, "/api/v1/me/saved-searches/\(search.id)/run"))
            #expect(run.lastRunAt == UserStoreDate.text(UserDataFixture.now))
            #expect(run.matchCountAtLastRun == 1 && run.indexedVolumeCountAtLastRun == 2)
            let mark = try #require(try fixture.store.searchSet(.savedSearches, id: search.id, of: "owner")?.values["freshness_data"]?.text)
            #expect(SavedSearchFreshness.decoded(from: Data(mark.utf8))
                    == SavedSearchFreshness.run(at: UserDataFixture.now, matchCount: 1, indexedVolumeCount: 2), "the kit's mark")
            #expect(try await Self.freshness(owner, search.id).newResults == nil, "nothing new")

            // A second note with the word, past every answer the server keeps of the search.
            _ = try await owner.send(.post, "\(UserHalfSearchTests.d2)/notes", NoteJSON(bodyText: "Zanzibar again").json)
            let fresh = try await Self.freshness(owner, search.id)
            #expect(fresh.newResults == 1 && fresh.savedSearch.matchCountAtLastRun == 1, "+1 since last run, the baseline kept")

            // A baseline above the count now: results went away, which is not news.
            func stamp(_ freshness: SavedSearchFreshness) throws {
                try fixture.store.updateSearchSet(.savedSearches, id: search.id,
                                                  ["freshness_data": .text(String(decoding: freshness.encoded!, as: UTF8.self))],
                                                  for: "owner")
            }
            try stamp(SavedSearchFreshness(lastRunAt: UserDataFixture.now, matchCountAtLastRun: 5, indexedVolumeCountAtLastRun: 2))
            #expect(try await Self.freshness(owner, search.id).newResults == nil)
            // A run whose count was never learned: the evaluation backfills the count now, and shows
            // nothing this time; the next has a baseline.
            try stamp(SavedSearchFreshness(lastRunAt: UserDataFixture.now, matchCountAtLastRun: nil, indexedVolumeCountAtLastRun: 2))
            let backfilled = try await Self.freshness(owner, search.id)
            #expect(backfilled.newResults == nil && backfilled.savedSearch.matchCountAtLastRun == 2)
            #expect(backfilled.savedSearch.lastRunAt == UserStoreDate.text(UserDataFixture.now), "a backfill, not a run")
            #expect(try await Self.freshness(owner, search.id).newResults == nil)

            // A tag of theirs the search names that they have since deleted matches nothing, as the
            // Mac's does, where a search through the API refuses it.
            let tag = try decode(UserTag.self, try await owner.send(.post, "/api/v1/me/tags", #"{"name": "Gone"}"#))
            let tagged = try await Self.saved(owner, "Tagged", "keywords=zanzibar&userTagIds=\(tag.id)")
            #expect(try await owner.send(.delete, "/api/v1/me/tags/\(tag.id)").status == .noContent)
            let stale = try decode(SavedSearch.self, try await owner.send(.post, "/api/v1/me/saved-searches/\(tagged.id)/run"))
            #expect(stale.matchCountAtLastRun == 0)
            for path in ["run", "freshness"] {
                let missing = try await owner.send(.post, "/api/v1/me/saved-searches/\(Self.stranger)/\(path)")
                #expect(missing.status == .notFound && problemCode(missing) == "SAVED_SEARCH_NOT_FOUND")
            }
        }
    }

    /// A capture takes the whole retained set less what Checklist Mode hides, with the app's words for
    /// it, and the corpus it saves is listed with the kit's coverage and opened by volume, in date order.
    @Test func aCorpusIsCapturedFromTheRowsASearchShows() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let preview = try decode(CorpusCapturePreview.self, try await Self.capture(
                owner, "/api/v1/me/working-corpora/capture", ["search": "keywords=treaties&limit=1"]))
            #expect(preview == CorpusCapturePreview(documentCount: 2, sourceQuery: "treaties", narrowing: [], indexedVolumeCount: 2,
                                                    truncationWarning: nil, checklistWarning: nil, sourceDescription: "Search results",
                                                    wasTruncated: false, totalMatchCount: 2), "the retained set, not the page")
            let hiding = try decode(CorpusCapturePreview.self, try await Self.capture(
                owner, "/api/v1/me/working-corpora/capture",
                ["search": "keywords=treaties&yearKeys=1960", "reviewed": ["\(Self.volume)/d2"]]))
            #expect(hiding.documentCount == 1)
            #expect(hiding.checklistWarning == "Checklist mode is hiding 1 reviewed document. It will not be in this corpus.")
            #expect(hiding.narrowing == ["years 1960"])
            #expect(hiding.sourceDescription == "Search results (years 1960); 1 reviewed document excluded")

            let corpus = try await Self.corpus(owner, " Treaty talks\n", "keywords=treaties")
            #expect(corpus.name == "Treaty talks" && corpus.documentCount == 2 && corpus.sourceQuery == "treaties")
            #expect(corpus.sourceDescription == "Search results" && corpus.wasTruncatedAtCapture == false)
            #expect(corpus.totalMatchCountAtCapture == 2 && corpus.indexedVolumeCountAtCapture == 2)
            #expect(corpus.capturedAt == UserStoreDate.text(UserDataFixture.now))
            #expect(corpus.truncationLine == nil && !corpus.truncationWarns && !corpus.isMeaningCapture)
            #expect(corpus.coverage == CorpusCoverage(WorkingCorpusResolution(
                indexedKeys: ["\(Self.volume)/d1", "\(Self.volume)/d2"], totalCount: 2, missingVolumeIds: [])))
            let row = try #require(try fixture.store.searchSet(.workingCorpora, id: corpus.id, of: "owner"))
            #expect(row.values["document_keys"] == .text(#"["frus1961-63v06\/d1","frus1961-63v06\/d2"]"#)
                    || row.values["document_keys"] == .text(#"["frus1961-63v06/d1","frus1961-63v06/d2"]"#))

            // One captured earlier, as an import leaves it, whose capture was cut short, and whose
            // documents are partly in a volume the index does not hold.
            let imported = WorkingCorpusExport(
                id: UUID(), name: "", documentKeys: ["frus1969-76v01/d5", "frus1894Nicaragua/d1"],
                capturedAt: UserDataFixture.now.addingTimeInterval(-86_400), wasTruncatedAtCapture: true, totalMatchCountAtCapture: 9_000)
            try fixture.store.addSearchSet(.workingCorpora, MacImport.corpus(imported).values, for: "owner")
            let list = try await UserHalfSearchTests.answer(WorkingCorpusList.self, owner, "/api/v1/me/working-corpora")
            #expect(list.items.map(\.id) == [corpus.id, imported.id.uuidString], "the most recently captured first")
            #expect(list.items[1].truncationLine == "Saved 2 of 9,000 matches" && list.items[1].truncationWarns)
            #expect(list.items[1].coverage?.indexedCount == 1 && list.items[1].coverage?.missingVolumeIds == ["frus1969-76v01"])

            let detail = try await UserHalfSearchTests.answer(WorkingCorpusDetail.self, owner, "/api/v1/me/working-corpora/\(imported.id)")
            #expect(detail.sections.map(\.volumeId) == ["frus1894Nicaragua", "frus1969-76v01"])
            #expect(detail.sections[0].indexed && detail.sections[0].documents.first?.dateISO == "1894-01-25")
            #expect(detail.sections[0].documents.first?.displayTitle == "No. 1. Mr. Baker to Mr. Gresham")
            #expect(!detail.sections[1].indexed && detail.sections[1].documents.first?.displayTitle == nil)
            let ordered = try await UserHalfSearchTests.answer(WorkingCorpusDetail.self, owner, "/api/v1/me/working-corpora/\(corpus.id)")
            #expect(ordered.sections.map { $0.documents.map(\.documentId) } == [["d1", "d2"]], "by date")

            // Renamed, trimmed; refused empty; deleted.
            let renamed = try decode(WorkingCorpus.self, try await owner.send(.patch, "/api/v1/me/working-corpora/\(corpus.id)",
                                                                               #"{"name": " Talks "}"#))
            #expect(renamed.name == "Talks" && renamed.documentCount == 2)
            let empty = try await owner.send(.patch, "/api/v1/me/working-corpora/\(corpus.id)", #"{"name": " "}"#)
            #expect(empty.status == .badRequest && problemCode(empty) == "INVALID_FIELD")
            let nothing = try await Self.capture(owner, "/api/v1/me/working-corpora", ["name": "None", "search": "keywords=zanzibar"])
            #expect(nothing.status == .badRequest && problemCode(nothing) == "NOTHING_TO_CAPTURE")
            #expect(try await owner.send(.delete, "/api/v1/me/working-corpora/\(imported.id)").status == .noContent)
            let gone = try await owner.get("/api/v1/me/working-corpora/\(imported.id)")
            #expect(gone.status == .notFound && problemCode(gone) == "CORPUS_NOT_FOUND")
        }
    }

    /// A search inside a corpus runs inside the documents of it the index holds, through every route
    /// that takes a search, each answer kept apart from the same search's outside it; a corpus none of
    /// whose documents the index holds finds nothing; and one that is not the user's is refused.
    @Test func aSearchRunsInsideAWorkingCorpus() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let either = "keywords=treaties+OR+canal"
            let outside = try await UserHalfSearchTests.answers(owner, either)
            #expect(outside.total == 3)
            let corpus = try await Self.corpus(owner, "Talks", "keywords=treaties", reviewed: ["\(Self.volume)/d2"])
            #expect(corpus.documentCount == 1)
            let inside = try await UserHalfSearchTests.answers(owner, "\(either)&workingCorpusId=\(corpus.id.lowercased())")
            #expect(inside.total == 1 && inside.page == ["\(Self.volume)/d1"] && inside.byDate == ["\(Self.volume)/d1"])
            #expect(inside.retained == 1 && inside.volumes == [Self.volume: 1] && inside.termCounts == [1, 0])
            #expect(try await UserHalfSearchTests.answers(owner, either) == outside, "each kept apart")
            let concordance = try await UserHalfSearchTests.answer(
                SearchConcordance.self, owner, "/api/v1/search/concordance?\(either)&workingCorpusId=\(corpus.id)")
            #expect(concordance.documentsOnPage == 1)
            // A search saved inside it keeps the corpus's documents, as the Mac's window saves them,
            // and counts inside them; its recall runs inside whatever corpus is applied then.
            let saved = try await Self.saved(owner, "Inside", "\(either)&workingCorpusId=\(corpus.id)")
            #expect(saved.search["workingCorpusId"] == nil && saved.search["keywords"] == ["treaties OR canal"])
            let run = try decode(SavedSearch.self, try await owner.send(.post, "/api/v1/me/saved-searches/\(saved.id)/run"))
            #expect(run.matchCountAtLastRun == 1)

            // None of its documents held: the kit's empty gate, which matches nothing.
            let elsewhere = WorkingCorpusExport(id: UUID(), name: "Elsewhere", documentKeys: ["frus1969-76v01/d5"])
            try fixture.store.addSearchSet(.workingCorpora, MacImport.corpus(elsewhere).values, for: "owner")
            #expect(try await UserHalfSearchTests.search(owner, "\(either)&workingCorpusId=\(elsewhere.id)").total == 0)

            for path in ["/api/v1/search?", "/api/v1/search/inspect?", "/api/v1/search/facets?section=volumes&",
                         "/api/v1/search/facets/selection?section=volumes&", "/api/v1/search/timeline?",
                         "/api/v1/search/concordance?", "/api/v1/me/search/tags?"] {
                let refused = try await owner.get("\(path)\(either)&workingCorpusId=\(Self.stranger)")
                #expect(refused.status == .notFound && problemCode(refused) == "CORPUS_NOT_FOUND", "\(path)")
            }
            let malformed = try await owner.get("/api/v1/search?\(either)&workingCorpusId=talks")
            #expect(malformed.status == .badRequest && problemCode(malformed) == "INVALID_PARAMETER")
        }

        // A search sent to another address than FRUS_PUBLIC_URL's acts for no one, who has no corpus.
        let away = try await UserDataFixture(publicURL: "https://frus.example.org", indexed: true)
        defer { withExtendedLifetime(away) {} }
        let hers = WorkingCorpusExport(id: UUID(), name: "Hers", documentKeys: ["\(Self.volume)/d1"])
        try away.store.addSearchSet(.workingCorpora, MacImport.corpus(hers).values, for: "owner")
        try await away.app.test(.router) { client in
            let refused = try await Browser(client: client).get("/api/v1/search?keywords=treaties&workingCorpusId=\(hers.id)")
            #expect(refused.status == .notFound && problemCode(refused) == "CORPUS_NOT_FOUND")
            #expect(try decode(APIProblem.Body.self, refused).detail.contains("acts for no one"))
        }
    }

    /// Checklist Mode's reviewed rows leave the pages, in either order, the concordance's page and the
    /// timeline, as the Mac pages what its checklist leaves; the count is the match's, and the response
    /// says how many were hidden. A POST carries what an address cannot.
    @Test func checklistModesReviewedRowsLeaveThePages() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let reviewed = "reviewed=\(Self.volume)%2Fd1"
            let plain = try await UserHalfSearchTests.search(owner, "keywords=treaties")
            #expect(plain.total == 2 && plain.hidden == nil)
            let hiding = try await UserHalfSearchTests.search(owner, "keywords=treaties&\(reviewed)")
            #expect(hiding.total == 2 && hiding.hidden == 1 && UserHalfSearchTests.documents(hiding) == ["\(Self.volume)/d2"])
            let byDate = try await UserHalfSearchTests.search(owner, "keywords=treaties&sort=dateDescending&\(reviewed)")
            #expect(UserHalfSearchTests.documents(byDate) == ["\(Self.volume)/d2"] && byDate.hidden == 1)
            let timeline = try await UserHalfSearchTests.answer(SearchTimeline.self, owner, "/api/v1/search/timeline?keywords=treaties&\(reviewed)")
            #expect(timeline.retainedCount == 1 && timeline.years.map(\.count) == [1])
            #expect(try await UserHalfSearchTests.answer(SearchTimeline.self, owner, "/api/v1/search/timeline?keywords=treaties")
                .retainedCount == 2, "kept apart")
            let concordance = try await UserHalfSearchTests.answer(
                SearchConcordance.self, owner, "/api/v1/search/concordance?keywords=treaties&\(reviewed)")
            #expect(concordance.documentsOnPage == 1)

            let posted = try await client.execute(uri: "/api/v1/search", method: .post,
                                                  headers: [.contentType: "application/x-www-form-urlencoded"],
                                                  body: ByteBuffer(string: "keywords=treaties&\(reviewed)"))
            #expect(posted.status == .ok)
            #expect(try decode(SearchResultList.self, posted) == hiding)
            let bad = try await owner.get("/api/v1/search?keywords=treaties&reviewed=d1")
            #expect(bad.status == .badRequest && problemCode(bad) == "INVALID_PARAMETER")
        }
    }

    /// A scope is made unnamed and empty, given its name as typed and its volumes each once and sorted,
    /// and resolved as the kit resolves one: at the index's grain the members it holds, or the outcome
    /// that it holds none; at the catalogue's, the members it lists. The most recently edited is first.
    @Test func aScopeIsResolvedAsTheKitResolvesOne() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let new = try decode(VolumeScope.self, try await owner.send(.post, "/api/v1/me/volume-scopes", "{}"))
            #expect(new.name == "" && new.volumeIds.isEmpty && new.indexedResolution == "noIndexedMembers")
            #expect(new.indexedVolumeIds == nil && new.cataloguedCount == 0)
            let edited = try decode(VolumeScope.self, try await owner.send(
                .patch, "/api/v1/me/volume-scopes/\(new.id.lowercased())",
                #"{"name": "Cuba ", "volumeIds": ["frus1961-63v06", "frus1964-68v32", "frus1961-63v06", "frus-gone"]}"#))
            #expect(edited.name == "Cuba " && edited.volumeIds == ["frus-gone", "frus1961-63v06", "frus1964-68v32"])
            #expect(edited.indexedResolution == "resolved" && edited.indexedVolumeIds == ["frus1961-63v06"])
            #expect(edited.cataloguedCount == 2, "frus-gone is no catalogue volume")

            let unindexed = try decode(VolumeScope.self, try await owner.send(
                .post, "/api/v1/me/volume-scopes", #"{"name": "Planned", "volumeIds": ["frus1964-68v32"]}"#))
            #expect(unindexed.indexedResolution == "noIndexedMembers" && unindexed.indexedVolumeIds == nil)
            let older = CustomVolumeScopeExport(id: UUID(), name: "Older", volumeIds: [],
                                                lastModified: UserDataFixture.now.addingTimeInterval(-60))
            try fixture.store.addSearchSet(.volumeScopes, MacImport.scope(older).values, for: "owner")
            let list = try await UserHalfSearchTests.answer(VolumeScopeList.self, owner, "/api/v1/me/volume-scopes")
            #expect(list.items.map(\.name) == ["Cuba ", "Planned", "Older"])

            let bad = try await owner.send(.patch, "/api/v1/me/volume-scopes/\(new.id)", #"{"volumeIds": ["a/b"]}"#)
            #expect(bad.status == .badRequest && problemCode(bad) == "INVALID_PARAMETER")
            #expect(try await owner.send(.delete, "/api/v1/me/volume-scopes/\(new.id)").status == .noContent)
            let gone = try await owner.get("/api/v1/me/volume-scopes/\(new.id)")
            #expect(gone.status == .notFound && problemCode(gone) == "SCOPE_NOT_FOUND")
        }
    }

    /// Two users' saved searches, corpora and scopes stay apart, as every resource under /me does: one's
    /// are not listed, opened, run, changed or searched inside by the other.
    @Test func eachUsersSetsAreTheirsAlone() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let search = try await Self.saved(alice, "Hers", "keywords=treaties")
            let corpus = try await Self.corpus(alice, "Hers", "keywords=treaties")
            let scope = try decode(VolumeScope.self, try await alice.send(.post, "/api/v1/me/volume-scopes", #"{"name": "Hers"}"#))
            #expect(try await UserHalfSearchTests.answer(SavedSearchList.self, bob, "/api/v1/me/saved-searches").total == 0)
            #expect(try await UserHalfSearchTests.answer(WorkingCorpusList.self, bob, "/api/v1/me/working-corpora").total == 0)
            #expect(try await UserHalfSearchTests.answer(VolumeScopeList.self, bob, "/api/v1/me/volume-scopes").total == 0)
            for (method, path) in [(HTTPRequest.Method.get, "/api/v1/me/saved-searches/\(search.id)"),
                                   (.post, "/api/v1/me/saved-searches/\(search.id)/run"),
                                   (.delete, "/api/v1/me/saved-searches/\(search.id)"),
                                   (.get, "/api/v1/me/working-corpora/\(corpus.id)"),
                                   (.delete, "/api/v1/me/working-corpora/\(corpus.id)"),
                                   (.get, "/api/v1/me/volume-scopes/\(scope.id)"),
                                   (.delete, "/api/v1/me/volume-scopes/\(scope.id)")] {
                // A live client sends a POST with no body in chunks, which the guard reads as a body to be JSON.
                let response = method == .get ? try await bob.get(path) : try await bob.send(method, path, method == .post ? "{}" : nil)
                #expect(response.status == .notFound, "\(method) \(path)")
            }
            let inside = try await bob.get("/api/v1/search?keywords=treaties&workingCorpusId=\(corpus.id)")
            #expect(inside.status == .notFound && problemCode(inside) == "CORPUS_NOT_FOUND")
            #expect(try await UserHalfSearchTests.search(alice, "keywords=treaties&workingCorpusId=\(corpus.id)").total == 2)
            #expect(try await UserHalfSearchTests.answer(SavedSearchList.self, alice, "/api/v1/me/saved-searches").items == [search])
        }
    }
}
