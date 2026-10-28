// The user half of a search through the API (PLAN's S17d): the user's notes and summaries in the
// scopes Search in chooses, their tags in the filter, a row's tags, the facets, the Query Inspector's
// counts, the readings and the My Tags counts, all read from the user store attached to the served
// index; each write found by the next search, past every answer the server keeps; and no one's
// writing for a search that acts for no one. SignInTests holds two users' searches apart.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct UserHalfSearchTests {
    static let volume = "frus1961-63v06"
    static let d1 = "/api/v1/me/volumes/frus1961-63v06/documents/d1"
    static let d2 = "/api/v1/me/volumes/frus1961-63v06/documents/d2"
    static let nicaragua = "/api/v1/me/volumes/frus1894Nicaragua/documents/d1"
    /// An id no one's tag has.
    static let strangerTag = "5E17D000-0000-4000-8000-0000000000FF"

    /// What a user wrote on the synthetic export's documents: a tag on frus1961-63v06's d1, a note on
    /// d1 whose word no document holds, and a summary of their own on d2 with another.
    struct Writing {
        let tag: UserTag
        let note: Note
        let summary: Summary
    }

    static func write(_ browser: Browser, note word: String = "zanzibar", summary other: String = "quixotic",
                      tag name: String = "Berlin") async throws -> Writing {
        let tag = try decode(UserTag.self, try await browser.send(.post, "/api/v1/me/tags", #"{"name": "\#(name)"}"#))
        #expect(try await browser.send(.put, "\(d1)/tags", #"{"tagIds": ["\#(tag.id)"]}"#).status == .ok)
        let note = try decode(Note.self, try await browser.send(.post, "\(d1)/notes", NoteJSON(bodyText: "A \(word) cable").json))
        let summary = try decode(Summary.self, try await browser.send(.post, "\(d2)/summaries", #"{"responseText": "A \#(other) proposal."}"#))
        return Writing(tag: tag, note: note, summary: summary)
    }

    /// The answer to a GET, which must be 200.
    static func answer<T: Decodable>(_ type: T.Type, _ browser: Browser, _ path: String) async throws -> T {
        let response = try await browser.get(path)
        #expect(response.status == .ok, "\(path): \(response.status.code) \(String(buffer: response.body))")
        return try decode(type, response)
    }

    static func search(_ browser: Browser, _ query: String) async throws -> SearchResultList {
        try await answer(SearchResultList.self, browser, "/api/v1/search?\(query)")
    }

    /// A list's documents, as `volume/document`, in its order.
    static func documents(_ list: SearchResultList) -> [String] { list.items.map { "\($0.volumeId)/\($0.documentId)" } }

    /// Each row's tags, by its document.
    static func rowTags(_ list: SearchResultList) -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: list.items.map { ("\($0.volumeId)/\($0.documentId)", $0.userTagIds) })
    }

    /// Everything the server answers of one search that reads its match, through each route that keeps an
    /// answer and each that counts: the count and the page by relevance, the results kept for the date
    /// order, the timeline over them, a facet section, the inspector's count of each term, and, for a
    /// user, the My Tags counts.
    struct Answers: Equatable {
        var total = 0
        var page: [String] = []
        var tags: [String: [String]] = [:]
        var byDate: [String] = []
        var retained = 0
        var volumes: [String: Int] = [:]
        var termCounts: [Int?] = []
        var myTags: [String: Int]?
    }

    static func answers(_ browser: Browser, _ query: String, myTags: Bool = true) async throws -> Answers {
        var answers = Answers()
        let list = try await search(browser, query)
        answers.total = list.total
        answers.page = documents(list).sorted()
        answers.tags = rowTags(list)
        answers.byDate = documents(try await search(browser, "\(query)&sort=dateAscending"))
        answers.retained = try await answer(SearchTimeline.self, browser, "/api/v1/search/timeline?\(query)").retainedCount
        let section = try await answer(SearchFacetSection.self, browser, "/api/v1/search/facets?\(query)&section=volumes")
        answers.volumes = Dictionary(uniqueKeysWithValues: section.rows.map { ($0.key, $0.count) })
        answers.termCounts = try await answer(SearchInspection.self, browser, "/api/v1/search/inspect?\(query)&scopedCounts=true")
            .inspection?.operands.map(\.scopedCount) ?? []
        if myTags {
            let counts = try await answer(SearchTagCounts.self, browser, "/api/v1/me/search/tags?\(query)")
            answers.myTags = Dictionary(uniqueKeysWithValues: counts.items.map { ($0.name, $0.count) })
        }
        return answers
    }

    /// The done-when's first half, under `FRUS_AUTH=none`: the single user's notes and summaries are
    /// found in the scopes searched, by their words and their exact words; their tags filter the search,
    /// in any case, and each row carries its document's; and the facets, the inspector, the readings and
    /// the My Tags counts count the same match.
    @Test func theUsersWritingIsSearchedInTheScopesChosen() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let writing = try await Self.write(owner)
            let tag = writing.tag.id

            // A note's words, in the scopes searched, stemmed as the corpus's are.
            #expect(Self.documents(try await Self.search(owner, "keywords=zanzibar")) == ["\(Self.volume)/d1"])
            #expect(try await Self.search(owner, "keywords=zanzibars&includeDocumentText=false&includeSummaries=false").total == 1)
            #expect(try await Self.search(owner, "keywords=zanzibar&includeNotes=false").total == 0, "Notes off")
            #expect(try await Self.search(owner, "keywords=%3Dzanzibar").total == 1, "the exact word reads the note's own text")
            #expect(try await Self.search(owner, "keywords=%3Dzanzibars").total == 0, "and only its own word")
            // A summary's, the researcher's own.
            #expect(Self.documents(try await Self.search(owner, "keywords=quixotic&includeDocumentText=false&includeNotes=false"))
                    == ["\(Self.volume)/d2"])
            #expect(try await Self.search(owner, "keywords=quixotic&includeSummaries=false").total == 0, "Summaries off")
            // With the corpus's, by the OR the search box reads, which the API's booleanMode would be.
            #expect(Set(Self.documents(try await Self.search(owner, "keywords=zanzibar+OR+quixotic+OR+canal")))
                    == ["\(Self.volume)/d1", "\(Self.volume)/d2", "frus1894Nicaragua/d1"])
            #expect(try await Self.search(owner, "keywords=zanzibar+OR+canal&includeDocumentText=false").total == 1, "Documents off")
            // All three off is a query with nothing to search, as the kit refuses it.
            let nowhere = try await owner.get("/api/v1/search?keywords=zanzibar&includeDocumentText=false&includeNotes=false&includeSummaries=false")
            #expect(nowhere.status == .badRequest && problemCode(nowhere) == "EMPTY_QUERY")

            // A row's tags, and the tag filter, by an id in any case, as the kit matches it.
            let treaties = try await Self.search(owner, "keywords=treaties")
            #expect(Self.rowTags(treaties) == ["\(Self.volume)/d1": [SearchUsers.caseFolded(tag)], "\(Self.volume)/d2": []])
            #expect(Self.documents(try await Self.search(owner, "keywords=treaties&userTagIds=\(tag)")) == ["\(Self.volume)/d1"])
            #expect(try await Self.search(owner, "keywords=treaties&userTagIds=\(tag.lowercased())").total == 1)
            #expect(try await Self.search(owner, "keywords=treaties&userTagIds=").total == 2, "the empty list filters nothing")

            // A tag that is not the user's is refused, by every route that takes a search.
            for path in ["/api/v1/search?", "/api/v1/search/inspect?", "/api/v1/search/facets?section=volumes&",
                         "/api/v1/search/facets/selection?section=volumes&", "/api/v1/search/timeline?",
                         "/api/v1/search/concordance?", "/api/v1/me/search/tags?"] {
                let refused = try await owner.get("\(path)keywords=treaties&userTagIds=\(tag)&userTagIds=\(Self.strangerTag)")
                #expect(refused.status == .notFound && problemCode(refused) == "TAG_NOT_FOUND", "\(path)")
            }

            // The facets, the inspector, the readings and the My Tags counts count the same match.
            let either = "keywords=zanzibar+OR+quixotic"
            let answers = try await Self.answers(owner, either)
            #expect(answers == Answers(total: 2, page: ["\(Self.volume)/d1", "\(Self.volume)/d2"],
                                       tags: ["\(Self.volume)/d1": [SearchUsers.caseFolded(tag)], "\(Self.volume)/d2": []],
                                       byDate: answers.byDate, retained: 2, volumes: [Self.volume: 2], termCounts: [1, 1],
                                       myTags: ["Berlin": 1]))
            #expect(Set(answers.byDate) == ["\(Self.volume)/d1", "\(Self.volume)/d2"])
            let both = try await Self.answer(SearchInspection.self, owner, "/api/v1/search/inspect?keywords=zanzibar+quixotic&emptyConjuncts=true")
            #expect(both.emptyConjuncts == [], "each word alone matches a document, the note's and the summary's")
            let tagged = try await Self.answer(SearchFacetSection.self, owner,
                                               "/api/v1/search/facets?\(either)&userTagIds=\(tag)&section=volumes")
            #expect(tagged.matchCount == 1)
            let concordance = try await Self.answer(SearchConcordance.self, owner, "/api/v1/search/concordance?keywords=zanzibar")
            #expect(concordance.documentsOnPage == 1 && concordance.items.isEmpty, "the note's word is in no document's text")
            let canal = try await Self.answer(SearchTagCounts.self, owner, "/api/v1/me/search/tags?keywords=canal")
            #expect(canal.items == [.init(id: tag, name: "Berlin", count: 0)], "a tag none of the results carries counts 0")
        }
    }

    /// Each write is in the next search, though the server keeps the answers of the searches asked
    /// lately: a note deleted, a tag moved to another document, a summary rewritten.
    @Test func eachWriteIsInTheNextSearch() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let writing = try await Self.write(owner)
            let tag = SearchUsers.caseFolded(writing.tag.id)
            let query = "keywords=zanzibar+OR+canal"
            let first = try await Self.answers(owner, query)
            #expect(first.total == 2 && first.retained == 2 && first.volumes == [Self.volume: 1, "frus1894Nicaragua": 1])
            #expect(first.termCounts == [1, 1] && first.myTags == ["Berlin": 1])
            #expect(try await Self.answers(owner, query) == first, "asked again, as kept")

            #expect(try await owner.send(.delete, NoteTests.note(writing.note.id)).status == .noContent)
            let deleted = try await Self.answers(owner, query)
            #expect(deleted.total == 1 && deleted.page == ["frus1894Nicaragua/d1"] && deleted.byDate == deleted.page)
            #expect(deleted.retained == 1 && deleted.volumes == ["frus1894Nicaragua": 1] && deleted.termCounts == [0, 1])
            #expect(deleted.myTags == ["Berlin": 0])

            #expect(try await owner.send(.put, "\(Self.nicaragua)/tags", #"{"tagIds": ["\#(writing.tag.id)"]}"#).status == .ok)
            #expect(try await owner.send(.delete, "\(Self.d1)/tags/\(writing.tag.id)").status == .ok)
            let moved = try await Self.answers(owner, query)
            #expect(moved.tags == ["frus1894Nicaragua/d1": [tag]] && moved.myTags == ["Berlin": 1])
            #expect(Self.rowTags(try await Self.search(owner, "keywords=treaties")) == ["\(Self.volume)/d1": [], "\(Self.volume)/d2": []])

            #expect(try await owner.send(.put, SummaryTests.summary(writing.summary.id), #"{"responseText": "A canal proposal."}"#).status == .ok)
            #expect(try await Self.search(owner, "keywords=quixotic").total == 0)
            #expect(Set(Self.documents(try await Self.search(owner, "keywords=canal"))) == ["frus1894Nicaragua/d1", "\(Self.volume)/d2"])
        }
    }

    /// A search sent to another address than `FRUS_PUBLIC_URL`'s, as a page under another name pointed
    /// at the server would send it, acts for no one, as a read under /me is refused: it finds none of
    /// the user's writing, and refuses their tags. So does every search on a server that keeps no user
    /// data, whose store the index does not attach.
    @Test func aSearchThatActsForNoOneFindsNoOnesWriting() async throws {
        for (publicURL, userData, code) in [("https://frus.example.org", true, "HOST_NOT_ALLOWED"),
                                            ("http://localhost:8080", false, "USER_DATA_OFF")] {
            let fixture = try await UserDataFixture(publicURL: publicURL, userData: userData, indexed: true)
            defer { withExtendedLifetime(fixture) {} }
            let time = UserDataFixture.now
            let document = FRUSLightCore.DocumentKey(volumeId: Self.volume, documentId: "d1")
            let tag = try fixture.store.createTag(named: "Berlin", for: "owner", at: time)
            try fixture.store.setTags([tag.id], of: document, for: "owner", at: time)
            _ = try fixture.store.createNote(in: document, bodyText: "A zanzibar cable", richText: nil, projectIds: [], userTagIds: [],
                                             selectedSummaryIds: [], linkedHighlightId: nil, for: "owner", at: time)
            try await fixture.app.test(.router) { client in
                let browser = Browser(client: client)
                #expect(try await Self.search(browser, "keywords=zanzibar").total == 0, "\(publicURL)")
                #expect(Self.rowTags(try await Self.search(browser, "keywords=treaties")).values.allSatisfy(\.isEmpty))
                let refused = try await browser.get("/api/v1/search?keywords=treaties&userTagIds=\(tag.id)")
                #expect(refused.status == .notFound && problemCode(refused) == "TAG_NOT_FOUND")
                #expect(try decode(APIProblem.Body.self, refused).detail.contains("acts for no one"))
                #expect(problemCode(try await browser.get("/api/v1/me/search/tags?keywords=treaties")) == code)
                let answers = try await Self.answers(browser, "keywords=zanzibar+OR+canal", myTags: false)
                #expect(answers.total == 1 && answers.retained == 1 && answers.termCounts == [0, 1], "\(publicURL)")
            }
        }
    }
}
