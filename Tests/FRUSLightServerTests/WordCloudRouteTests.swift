// The Word Cloud's routes (PLAN's S24i, S29e): what a request may ask of the language family's clouds and of a live count,
// and what is refused; every scope the app's cloud takes, resolved from the reader's rows and the served index and
// counted live; a count that outlasts a request, a job the page follows; the family's lists at the family's settings
// and counts under any other; the entity lenses unavailable; the reader's settings carried from their synced
// preferences to their clouds, the criteria set by a change to the preferences and the hidden words by routes of their
// own, each written as the app's settings write it and stored as the app syncs it; the settings bench; and two users'
// settings and scopes kept apart. The clouds themselves are held to the file's lists and the kit's count, and the
// settings to the kit's tokenizer, in `WordCloudParityTests` and `WordCloudLiveParityTests`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct WordCloudRouteTests {
    static func cloud(_ client: any TestClientProtocol, _ query: String = "", user: String? = nil) async throws -> CloudAnswer {
        try decode(CloudAnswer.self, try await Browser(client: client, user: user).get("/api/v1/cloud\(query)"))
    }

    @Test func theRequestsAndRefusals() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let context = try decode(CloudContext.self, try await client.execute(uri: "/api/v1/cloud/context", method: .get))
            #expect(context.lenses.map(\.id) == ["allTerms", "people", "places", "organizations", "topics", "actions", "descriptors", "concepts", "sentiment"])
            #expect(context.lenses.filter { !$0.available }.map(\.id) == ["people", "places", "organizations"], "the entity lenses, by the tagger's health")
            #expect(context.lenses.map(\.label) == ["All terms", "People", "Places", "Organizations", "Topics (nouns)", "Actions (verbs)",
                                                    "Descriptors (adjectives)", "Concepts", "Sentiment"])
            #expect(context.subseries.count == 107 && context.subseries.first?.id == "1861" && context.subseries.first?.volumes.first?.id == "frus1861")
            #expect(!context.subjects.isEmpty && context.subjects.allSatisfy { !$0.subcategories.isEmpty }, "By Subject's categories that narrow")
            #expect(context.dateRange.from < context.dateRange.to && context.dateRange.to.hasSuffix("-12-31"), "the corpus's last year")
            let first = try await Self.cloud(client)
            #expect(first.scope == .init(signature: "corpus", title: "Entire Corpus") && first.lens.id == "allTerms", "the corpus, under the bar's first lens")
            #expect(first.state == "terms" && first.terms.count == 50 && first.analyzeWithin == nil && first.source == "family")
            let volume = try await Self.cloud(client, "?scope=vol:frus1961-63v06&lens=sentiment")
            #expect(volume.scope.signature == "vol:frus1961-63v06" && volume.scope.title.hasPrefix("Foreign Relations of the United States, 1961–1963, Volume VI"))
            #expect(volume.analyzeWithin?.label == "Analyze within this volume" && volume.analyzeWithin?.volumeIds == ["frus1961-63v06"])
            #expect(volume.analyzeWithin?.scopeLabel == volume.scope.title && volume.terms.allSatisfy { $0.polarity != nil })
            let subseries = try await Self.cloud(client, "?scope=sub:1961-63&lens=concepts")
            #expect(subseries.scope.title == "1961-63" && subseries.analyzeWithin?.label == "Analyze within this subseries")
            #expect(subseries.analyzeWithin?.volumeIds.allSatisfy { $0.hasPrefix("frus1961-63") } == true && subseries.analyzeWithin?.scopeLabel == "1961-63")
            // The family's clouds carry All terms and Descriptors too.
            #expect(try await Self.cloud(client, "?lens=descriptors").terms.count == 50)

            // An entity lens: not drawn, in the terms of the kit's health, with no index needed to say so.
            let people = try await Self.cloud(client, "?scope=vol:frus1961-63v06&lens=people")
            #expect(people.state == "lensUnavailable" && people.terms.isEmpty && people.countLine == nil)
            #expect(people.message == .init(title: "Lens Unavailable on This Server",
                                            detail: "This server’s tagger does not recognize names, so the “People” lens can’t be drawn. All terms, Topics (nouns), Actions (verbs), Descriptors (adjectives), Concepts, and Sentiment still work."))

            let refusals: [(String, HTTPResponse.Status, String)] = [
                // A scope counted live waits for an index; a reader's record that is not theirs is not found.
                ("/api/v1/cloud?scope=doc:frus1961-63v06/d1", .serviceUnavailable, "INDEX_NOT_READY"),
                ("/api/v1/cloud?scope=daterange:1962-10-01..1962-10-31", .serviceUnavailable, "INDEX_NOT_READY"),
                ("/api/v1/cloud?scope=subject:Economics%1FTrade", .serviceUnavailable, "INDEX_NOT_READY"),
                ("/api/v1/cloud?scope=col:5E17F000-0000-4000-8000-0000000000A1", .notFound, "COLLECTION_NOT_FOUND"),
                ("/api/v1/cloud?scope=tag:5E17F000-0000-4000-8000-0000000000A1", .notFound, "TAG_NOT_FOUND"),
                ("/api/v1/cloud?scope=search:5E17F000-0000-4000-8000-0000000000A1", .notFound, "SAVED_SEARCH_NOT_FOUND"),
                ("/api/v1/cloud?scope=scope:5E17F000-0000-4000-8000-0000000000A1", .notFound, "SCOPE_NOT_FOUND"),
                ("/api/v1/cloud?scope=doc:frus1800v01/d1", .notFound, "VOLUME_NOT_FOUND"),
                ("/api/v1/cloud?scope=daterange:1962-13-01..1962-10-31", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?scope=sub:1800", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?scope=doc:frus1961-63v06", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?scope=col:not-a-uuid", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?scope=subject:", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?scope=daterange:1962-10-01", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?scope=vol:frus1800v01", .notFound, "VOLUME_NOT_FOUND"),
                ("/api/v1/cloud?scope=everything", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?scope=era:1969-76", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?lens=nouns", .badRequest, "INVALID_PARAMETER"),
                // Since S29f Distinctive is a measure the route takes, and the words hidden from a cloud its alone.
                ("/api/v1/cloud?measure=loudness", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?hidden=treaty", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?collocates=1", .badRequest, "UNKNOWN_PARAMETER"),
                ("/api/v1/cloud/context?scope=corpus", .badRequest, "UNKNOWN_PARAMETER"),
                ("/api/v1/cloud?scope=corpus&scope=sub:1861", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud/jobs/5E17F000-0000-4000-8000-0000000000A1", .notFound, "JOB_NOT_FOUND"),
            ]
            for (path, status, code) in refusals {
                let response = try await client.execute(uri: path, method: .get)
                #expect(response.status == status && problemCode(response) == code, "\(path): \(response.status) \(String(buffer: response.body))")
            }
        }
    }

    /// Distinctive (PLAN's S29f) on a server that serves no index: the family's list, which no ranking reads, says why, as
    /// the reason it is, no index served, not that one holds none of the scope (the parity suite's `noCount`), and
    /// Search's Collocates wait for an index, as its other readings do. The rankings themselves are held to the kit's in
    /// `DistinctiveParityTests` and `CollocatesParityTests`.
    @Test func distinctiveAndCollocatesWithoutAnIndex() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let ranked = try await Self.cloud(client, "?scope=vol:frus1961-63v06&lens=topics&measure=keyness&hidden=soviet")
            #expect(ranked.source == "family" && ranked.state == "terms" && ranked.terms.count == 50, "Frequency's list stands beside it")
            #expect(ranked.distinctive?.state == "unavailable" && ranked.distinctive?.reason == "noIndex" && ranked.distinctive?.scores.isEmpty == true)
            #expect(ranked.distinctive?.message?.title == "No Distinctiveness Ranking")
            #expect(ranked.distinctive?.message?.detail.contains("this server serves no index at the moment") == true, "not that the index holds none")
            #expect(try await Self.cloud(client, "?scope=vol:frus1961-63v06&lens=topics").distinctive == nil, "Frequency carries no ranking")
            // A lens the tagger cannot serve says so first, as the app's main area draws the state before any ranking.
            let people = try await Self.cloud(client, "?scope=vol:frus1961-63v06&lens=people&measure=keyness")
            #expect(people.state == "lensUnavailable" && people.distinctive == nil)

            let refusals: [(String, HTTPResponse.Status, String)] = [
                ("/api/v1/search/collocates?keywords=treaty", .serviceUnavailable, "INDEX_NOT_READY"),
                ("/api/v1/search/collocates?keywords=treaty&window=13", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/search/collocates?keywords=treaty&window=10&window=20", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/search/collocates?keywords=treaty&order=effect", .badRequest, "UNKNOWN_PARAMETER"),
            ]
            for (path, status, code) in refusals {
                let response = try await client.execute(uri: path, method: .get)
                #expect(response.status == status && problemCode(response) == code, "\(path): \(response.status) \(String(buffer: response.body))")
            }
        }
    }

    /// The criteria a change to the preferences sets, each within its control's range, reach the reader's clouds; and
    /// the settings their clouds cannot show are named.
    @Test func theCriteriaReachTheReadersClouds() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let standard = try await Self.cloud(client, "?lens=topics")
            #expect(standard.removed == 0 && standard.settingsNotShown == nil)
            let longer = try decode(Preferences.self, try await owner.send(.patch, "/api/v1/me/preferences", #"{"wordCloud": {"minLength": 8, "minCount": 20}}"#))
            #expect(longer.wordCloud.minLength == 8 && longer.wordCloud.minCount == 20 && longer.wordCloud.foldPlurals)
            #expect(try fixture.rows.column("SELECT wc_min_length || ' ' || wc_min_count FROM preferences") == ["8 20"])
            let trimmed = try await Self.cloud(client, "?lens=topics")
            #expect(trimmed.terms.allSatisfy { $0.term.count >= 8 && $0.count >= 20 } && trimmed.removed > 0)
            #expect(trimmed.terms.map(\.term) == standard.terms.map(\.term).filter { $0.count >= 8 }, "the longer words, in the file's order")
            #expect(trimmed.countLine == "\(trimmed.terms.count) terms" && trimmed.settingsNotShown == nil, "a setting that only takes words out")

            _ = try await owner.send(.patch, "/api/v1/me/preferences", #"{"wordCloud": {"minLength": 2, "foldPlurals": false, "excludeBoilerplate": false, "filterMarkings": true}}"#)
            let adding = try await Self.cloud(client, "?lens=topics")
            #expect(adding.settingsNotShown == "These clouds were counted once, at the standard settings, so your settings can take words out of them but cannot count them differently: plural folding differs; “Hide common diplomatic words” is off; your minimum word length is shorter.",
                    "\(adding.settingsNotShown ?? "none")")
            #expect(try fixture.rows.column("SELECT wc_fold_plurals || wc_exclude_boilerplate || wc_filter_markings FROM preferences") == ["001"])

            for (body, code) in [(#"{"wordCloud": {"minLength": 1}}"#, "INVALID_FIELD"), (#"{"wordCloud": {"minLength": 9}}"#, "INVALID_FIELD"),
                                 (#"{"wordCloud": {"minCount": 0}}"#, "INVALID_FIELD"), (#"{"wordCloud": {"minCount": 21}}"#, "INVALID_FIELD"),
                                 (#"{"wordCloud": {"density": "airy"}}"#, "INVALID_FIELD"), (#"{"wordCloud": {"foldPlurals": "no"}}"#, "INVALID_FIELD"),
                                 (#"{"wordCloud": 3}"#, "INVALID_FIELD"), (#"{"cloud": {}}"#, "UNKNOWN_FIELD")] {
                let refused = try await owner.send(.patch, "/api/v1/me/preferences", body)
                #expect(refused.status == .badRequest && problemCode(refused) == code, "\(body): \(String(buffer: refused.body))")
            }
            #expect(try decode(Preferences.self, try await owner.get("/api/v1/me/preferences")).wordCloud.minLength == 2, "a refused change sets nothing")
        }
    }

    /// The hidden words, each written as the app's settings write it and stored as the app syncs it: a word trimmed and
    /// lowercased into a sorted set, a lens's list gone once emptied, a change that alters nothing writing nothing.
    /// A clock that moves a second each time it is read, so a write that should not happen would stamp another time.
    final class MovingClock: @unchecked Sendable {
        private let lock = NSLock()
        private var reads = 0

        func now() -> Date {
            lock.lock()
            defer { lock.unlock() }
            reads += 1
            return UserDataFixture.now.addingTimeInterval(TimeInterval(reads))
        }
    }

    @Test func theHiddenWordsAreKeptAsTheAppKeepsThem() async throws {
        let clock = MovingClock()
        let fixture = try await UserDataFixture(now: { clock.now() })
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let standard = try await Self.cloud(client, "?lens=topics")
            let (first, second) = (standard.terms[0].term, standard.terms[1].term)

            let hidden = try decode(Preferences.self, try await owner.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "  \#(first.uppercased())\n"}"#))
            #expect(hidden.wordCloud.globalStopwords == [first] && hidden.wordCloud.lensStopwords.isEmpty)
            _ = try await owner.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "aardvark"}"#)
            #expect(try fixture.rows.column("SELECT wc_global_stopwords_json FROM preferences") == [#"["aardvark","\#(first)"]"#], "sorted, as the app keeps it")
            let stamp = try fixture.rows.column("SELECT updated_at FROM preferences")
            let again = try decode(Preferences.self, try await owner.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "\#(first)"}"#))
            let restamped = try fixture.rows.column("SELECT updated_at FROM preferences")
            #expect(again.wordCloud.globalStopwords == ["aardvark", first] && restamped == stamp, "a word hidden already writes nothing")
            _ = try await owner.send(.delete, "/api/v1/me/preferences/hidden-words?word=never-hidden")
            #expect(try fixture.rows.column("SELECT updated_at FROM preferences") == stamp, "nor does a word never hidden, shown again")
            _ = try await owner.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "zebra"}"#)
            #expect(try fixture.rows.column("SELECT updated_at FROM preferences") != stamp, "a change is stamped, by the clock that moves")
            _ = try await owner.send(.delete, "/api/v1/me/preferences/hidden-words?word=zebra")

            let lens = try decode(Preferences.self, try await owner.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "\#(second)", "lens": "topics"}"#))
            _ = try await owner.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "zeal", "lens": "sentiment"}"#)
            #expect(lens.wordCloud.lensStopwords == ["topics": [second]])
            #expect(try fixture.rows.column("SELECT wc_lens_stopwords_json FROM preferences") == [#"{"sentiment":["zeal"],"topics":["\#(second)"]}"#])
            let topics = try await Self.cloud(client, "?lens=topics")
            #expect(!topics.terms.contains { $0.term == first || $0.term == second } && topics.removed == 2)
            #expect(topics.terms.map(\.term) == Array(standard.terms.map(\.term).dropFirst(2)))

            let shown = try decode(Preferences.self, try await owner.send(.delete, "/api/v1/me/preferences/hidden-words?word=\(first.uppercased())"))
            #expect(shown.wordCloud.globalStopwords == ["aardvark"], "shown again by its word in any case, as the app's removal lowercases it")
            _ = try await owner.send(.delete, "/api/v1/me/preferences/hidden-words?word=aardvark")
            #expect(try fixture.rows.column("SELECT wc_global_stopwords_json FROM preferences") == ["[]"])
            _ = try await owner.send(.delete, "/api/v1/me/preferences/hidden-words?word=zeal&lens=sentiment")
            #expect(try fixture.rows.column("SELECT wc_lens_stopwords_json FROM preferences") == [#"{"topics":["\#(second)"]}"#], "an emptied list goes")
            let none = try decode(Preferences.self, try await owner.send(.delete, "/api/v1/me/preferences/hidden-words?word=\(second)&lens=topics"))
            let emptied = try fixture.rows.column("SELECT wc_lens_stopwords_json FROM preferences")
            #expect(none.wordCloud.lensStopwords.isEmpty && emptied == ["{}"], "the empty map, which a Mac syncing it reads as no lens's words")
            #expect(try await Self.cloud(client, "?lens=topics").terms == standard.terms)

            let refusals: [(HTTPRequest.Method, String, String?, String)] = [
                (.post, "/api/v1/me/preferences/hidden-words", #"{"word": "   "}"#, "INVALID_FIELD"),
                (.post, "/api/v1/me/preferences/hidden-words", #"{"word": "\#(String(repeating: "a", count: 201))"}"#, "INVALID_FIELD"),
                (.post, "/api/v1/me/preferences/hidden-words", #"{"word": "x", "lens": "nouns"}"#, "INVALID_FIELD"),
                (.post, "/api/v1/me/preferences/hidden-words", #"{"word": "x", "colour": "red"}"#, "UNKNOWN_FIELD"),
                (.post, "/api/v1/me/preferences/hidden-words", #"{"lens": "topics"}"#, "INVALID_FIELD"),
                (.delete, "/api/v1/me/preferences/hidden-words", nil, "INVALID_PARAMETER"),
                (.delete, "/api/v1/me/preferences/hidden-words?word=x&lens=nouns", nil, "INVALID_PARAMETER"),
            ]
            for (method, path, body, code) in refusals {
                let refused = try await owner.send(method, path, body)
                #expect(refused.status == .badRequest && problemCode(refused) == code, "\(method) \(path) \(body ?? ""): \(String(buffer: refused.body))")
            }
        }
    }

    /// The settings bench: the stand-in sample, as the reader's settings keep it, each control moving it.
    @Test func theBenchKeepsWhatTheSettingsKeep() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            func sample(_ query: String = "") async throws -> CloudSample {
                try decode(CloudSample.self, try await owner.get("/api/v1/me/preferences/word-cloud-sample\(query)"))
            }
            let standard = try await sample()
            let kept = standard.kept.map(\.term)
            #expect(standard.sampleSize == 23 && standard.summary == "Keeps \(kept.count) of 23 terms in this sample")
            #expect(!kept.contains("telegram") && !kept.contains("confidential") && kept.contains("war") && kept.contains("rapprochement"))
            #expect(standard.provenance.hasPrefix("A stand-in sample"))
            _ = try await owner.send(.patch, "/api/v1/me/preferences", #"{"wordCloud": {"excludeBoilerplate": false, "filterMarkings": false}}"#)
            let open = try await sample()
            #expect(open.kept.map(\.term).contains("telegram") && open.kept.map(\.term).contains("confidential"))
            _ = try await owner.send(.patch, "/api/v1/me/preferences", #"{"wordCloud": {"minLength": 4, "minCount": 3}}"#)
            let thresholds = try await sample()
            #expect(!thresholds.kept.contains { $0.term == "war" || $0.term == "aid" || $0.term == "détente" || $0.term == "rapprochement" })
            let concepts = try await sample("?lens=concepts")
            #expect(concepts.kept.contains { $0.term == "sovereignty" } && !concepts.kept.contains { $0.term == "ambassador" },
                    "the lens's lexicon: a concept kept, a word outside it not")
            _ = try await owner.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "sovereignty", "lens": "concepts"}"#)
            #expect(try await sample().kept.contains { $0.term == "sovereignty" }, "a lens's word is hidden under that lens alone")
            let hidden = try await sample("?lens=concepts")
            #expect(!hidden.kept.contains { $0.term == "sovereignty" } && hidden.kept.count == concepts.kept.count - 1, "and under that lens")
            let refused = try await owner.get("/api/v1/me/preferences/word-cloud-sample?lens=nouns")
            #expect(problemCode(refused) == "INVALID_PARAMETER")
        }
    }

    /// Behind a proxy that signs people in: each reader's clouds follow their own settings, and a request that names no
    /// one reads the app's own.
    @Test func eachReadersSettingsAreTheirOwn() async throws {
        let fixture = try await UserDataFixture(auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let standard = try await Self.cloud(client, "?lens=actions", user: "alice")
            let word = try #require(standard.terms.first?.term)
            _ = try await alice.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "\#(word)"}"#)
            _ = try await alice.send(.patch, "/api/v1/me/preferences", #"{"wordCloud": {"foldPlurals": false}}"#)
            let hers = try await Self.cloud(client, "?lens=actions", user: "alice")
            #expect(!hers.terms.contains { $0.term == word } && hers.settingsNotShown != nil)
            let his = try await Self.cloud(client, "?lens=actions", user: "bob")
            #expect(his.terms == standard.terms && his.settingsNotShown == nil)
            let no = try await Self.cloud(client, "?lens=actions")
            #expect(no.terms == standard.terms && no.settingsNotShown == nil, "a request that names no one")
            #expect(try decode(Preferences.self, try await Browser(client: client, user: "bob").get("/api/v1/me/preferences")).wordCloud.globalStopwords.isEmpty)
        }
    }

    // MARK: Live clouds (PLAN's S29e)

    /// A tag the owner makes and puts on `documents`, by the tags' routes; its id.
    static func tag(_ owner: Browser, _ name: String, on documents: [(String, String)]) async throws -> String {
        let tag = try decode(UserTag.self, try await owner.send(.post, "/api/v1/me/tags", #"{"name": "\#(name)"}"#))
        for (volume, document) in documents {
            _ = try await owner.send(.put, "/api/v1/me/volumes/\(volume)/documents/\(document)/tags", #"{"tagIds": ["\#(tag.id)"]}"#)
        }
        return tag.id
    }

    /// A collection `owner` makes of `documents`; its id.
    static func collection(_ owner: Browser, _ name: String, of documents: [(String, String)]) async throws -> String {
        let id = try decode(CollectionDetail.self, try await owner.send(.post, "/api/v1/me/collections", #"{"name": "\#(name)"}"#)).id
        let keys = documents.map { #"{"volumeId": "\#($0.0)", "documentId": "\#($0.1)"}"# }.joined(separator: ", ")
        _ = try await owner.send(.post, "/api/v1/me/collections/\(id)/documents", #"{"documents": [\#(keys)]}"#)
        return id
    }

    static func query(_ scope: String, _ lens: String = "allTerms") -> String {
        "?scope=\(scope.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)&lens=\(lens)"
    }

    /// Every scope the app's cloud takes beside the catalogue's, over the synthetic export: each resolved from the
    /// owner's rows and the served index as the app's resolver resolves it, titled as it titles it, and counted.
    @Test func everyLiveScopeIsResolvedAndCounted() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let collection = try await Self.collection(owner, "Treaty talks", of: [("frus1961-63v06", "d1"), ("frus1961-63v06", "d2")])
            let tag = try await Self.tag(owner, "Canal", on: [("frus1894Nicaragua", "d1")])
            let search = try decode(SavedSearch.self, try await owner.send(.post, "/api/v1/me/saved-searches",
                                                                         #"{"name": "Treaties", "search": "keywords=treaties"}"#)).id
            let scope = try decode(VolumeScope.self, try await owner.send(.post, "/api/v1/me/volume-scopes",
                                                                       #"{"name": "Kennedy", "volumeIds": ["frus1961-63v06"]}"#)).id
            let cases: [(scope: String, title: String, documents: Int)] = [
                ("doc:frus1961-63v06/d2", "Foreign Relations of the United States, 1961–1963, Volume VI,", 1),
                ("col:\(collection)", "Treaty talks", 2),
                ("tag:\(tag)", "Canal", 1),
                ("search:\(search)", "Treaties", 2),
                ("scope:\(scope)", "Kennedy", 2),
                ("daterange:1960-11-01..1960-11-30", WordCloudScope.dateRangeTitle(startISO: "1960-11-01", endISO: "1960-11-30"), 2),
                ("daterange:1894-01-01..1894-12-31", WordCloudScope.dateRangeTitle(startISO: "1894-01-01", endISO: "1894-12-31"), 1),
            ]
            for each in cases {
                let answer = try await Self.cloud(client, Self.query(each.scope))
                #expect(answer.source == "live" && answer.state == "terms" && answer.documentCount == each.documents, "\(each.scope): \(answer.state)")
                #expect(answer.scope.signature == each.scope && answer.scope.title.hasPrefix(each.title), "\(each.scope): \(answer.scope.title)")
                #expect(!answer.terms.isEmpty && answer.listed == answer.terms.count && answer.removed == 0 && answer.settingsNotShown == nil)
                #expect(answer.countLine == CloudRules.countLine(terms: answer.terms.count, documents: each.documents), "\(each.scope)")
                #expect(answer.account == "This cloud was counted from its scope’s \(each.documents == 1 ? "1 document" : "\(each.documents) documents") by this server’s own tagger, \(WordCloudLive.tagger.identity), at the standard settings.")
            }
            // The scoped hand-off: a volume scope's indexed members; none for a document, a collection or a search.
            #expect(try await Self.cloud(client, Self.query("scope:\(scope)")).analyzeWithin
                    == .init(label: "Analyze within this scope", volumeIds: ["frus1961-63v06"], scopeLabel: "Kennedy"))
            #expect(try await Self.cloud(client, Self.query("col:\(collection)")).analyzeWithin == nil)
            // A document the index lacks, and a range with none dated in it: no indexed text.
            for empty in ["doc:frus1961-63v06/d99", "daterange:1700-01-01..1700-12-31"] {
                let answer = try await Self.cloud(client, Self.query(empty))
                #expect(answer.state == "noIndexedText" && answer.documentCount == 0 && answer.message?.title == "No Terms", "\(empty)")
            }
            // A job's row names a reader's own scope by its kind and id, never by what the reader called it.
            let secret = try #require(UUID(uuidString: collection))
            let named = CloudResolution(scope: .collection(id: secret), title: "Treaty talks", documents: .keys([]), owner: "owner", members: nil)
            #expect(WordCloudLive.subject(named, lens: .topics) == "Collection \(secret.uuidString) · Topics (nouns)")
            let corpus = CloudResolution(scope: .corpus, title: "Entire Corpus", documents: .corpus, owner: nil, members: nil)
            #expect(WordCloudLive.subject(corpus, lens: .allTerms) == "Entire Corpus · All terms")
            // A lens with nothing of the document's words: read, and its own words for nothing found.
            let concepts = try await Self.cloud(client, Self.query("doc:frus1894Nicaragua/d1", "concepts"))
            #expect(concepts.state == "noTerms" && concepts.documentCount == 1 && concepts.message == CloudRules.message(state: "noTerms", lens: .concepts))
            // A volume scope with no name is the scope bar's Untitled, never an empty heading.
            let unnamed = try decode(VolumeScope.self, try await owner.send(.post, "/api/v1/me/volume-scopes", #"{"volumeIds": ["frus1894Nicaragua"]}"#)).id
            let untitled = try await Self.cloud(client, Self.query("scope:\(unnamed)"))
            #expect(untitled.scope.title == "Untitled" && untitled.documentCount == 1 && untitled.analyzeWithin?.scopeLabel == "Volume Scope")
        }
    }

    /// The corpus, a subseries and a subject outlast a request: each a job of the server's queue, which the page follows
    /// until it ends, its count kept for the next request; a volume's is counted within the request. The family's lists
    /// answer at the family's settings, and a scope the index holds none of is its list filtered by any others.
    @Test func aCountThatOutlastsARequestIsAJobThePageFollows() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await Self.cloud(client, Self.query("corpus")).source == "family", "the family's list at the family's settings")
            #expect(try await Self.cloud(client, Self.query("vol:frus1961-63v06")).source == "family")
            _ = try await owner.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "treaty"}"#)

            let response = try await owner.get("/api/v1/cloud\(Self.query("corpus"))")
            #expect(response.status == .accepted && response.headers[.cacheControl] == "no-store")
            let counting = try decode(CloudAnswer.self, response)
            let job = try #require(counting.job)
            #expect(counting.state == "counting" && counting.source == "live" && counting.terms.isEmpty)
            #expect(counting.message?.detail.contains("leaving this page does not stop it") == true)
            let again = try decode(CloudAnswer.self, try await owner.get("/api/v1/cloud\(Self.query("corpus"))"))
            #expect(again.job?.id == job.id || again.state == "terms", "asked again while it runs, the same job")
            await fixture.jobs.waitUntilIdle()
            let followed = try decode(CloudJob.self, try await owner.get("/api/v1/cloud/jobs/\(job.id)"))
            #expect(followed.state == "succeeded" && followed.progress?.hasPrefix("Counted ") == true && followed.fraction == 1 && followed.error == nil)
            let counted = try await Self.cloud(client, Self.query("corpus"))
            #expect(counted.source == "live" && counted.state == "terms" && counted.documentCount == 3 && counted.job == nil)
            #expect(!counted.terms.contains { $0.term == "treaty" } && counted.account?.contains("under your settings") == true)
            let jobs = try decode(AdminJobList.self, try await owner.get("/api/v1/admin/jobs"))
            #expect(jobs.jobs.contains { $0.id == job.id && $0.kind == "wordCloud" && $0.subject == "Entire Corpus · All terms" && $0.requestedBy == "owner" })

            // A volume the index holds, counted within the request; one it holds none of, its family's list filtered.
            let volume = try await Self.cloud(client, Self.query("vol:frus1961-63v06"))
            #expect(volume.source == "live" && volume.state == "terms" && volume.documentCount == 2 && volume.job == nil)
            let unheld = try await Self.cloud(client, Self.query("vol:frus1969-76ve09p1"))
            #expect(unheld.source == "family" && unheld.state == "terms" && !unheld.terms.contains { $0.term == "treaty" })
            // A subseries' count is a job, even of one volume's documents.
            let subseries = try await owner.get("/api/v1/cloud\(Self.query("sub:1894"))")
            let subseriesAnswer = try decode(CloudAnswer.self, subseries)
            #expect(subseries.status == .accepted && subseriesAnswer.message?.detail.contains("subseries") == true)
            await fixture.jobs.waitUntilIdle()
            #expect(try await Self.cloud(client, Self.query("sub:1894")).documentCount == 1)
            // A subject's count is a job at any settings: the documents of its volumes the index holds.
            let resolved = try #require(CorpusAnalyticsRoutes.detectedTopics(fixture.server.resources))
            let subject = try #require(ScopeFacets.narrowingCategories(resolvedByVolume: resolved).lazy.flatMap { category in
                ScopeFacets.subCategoryCatalog(forCategory: category.label, resolvedByVolume: resolved).map { (category.label, $0.subcategory) }
            }.first { ScopeFacets.volumeIds(forCategory: $0.0, subcategory: $0.1, resolvedByVolume: resolved).contains("frus1961-63v06") })
            let volumes = ScopeFacets.volumeIds(forCategory: subject.0, subcategory: subject.1, resolvedByVolume: resolved)
            let held = SyntheticExport.documents.filter { volumes.contains($0.volume) }.count
            let signature = "subject:\(subject.0)\u{1f}\(subject.1)"
            let asked = try await owner.get("/api/v1/cloud\(Self.query(signature))")
            #expect(asked.status == .accepted, "\(signature)")
            await fixture.jobs.waitUntilIdle()
            let subjectCloud = try await Self.cloud(client, Self.query(signature))
            #expect(subjectCloud.documentCount == held && subjectCloud.scope.title == "\(subject.0) · \(subject.1)")
            #expect(subjectCloud.analyzeWithin?.label == "Analyze within this subject" && subjectCloud.analyzeWithin?.volumeIds == volumes.sorted())
            // An entity lens under the reader's settings is still unavailable, and counts nothing.
            #expect(try await Self.cloud(client, Self.query("corpus", "organizations")).state == "lensUnavailable")
        }
    }

    /// Behind a proxy that signs people in, over the synthetic export: one reader's collection is no one else's, and each
    /// reader's settings count their own clouds of the same document.
    @Test func twoReadersScopesStayApart() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let hers = try await Self.collection(alice, "Alice’s", of: [("frus1961-63v06", "d1")])
            for reader in [bob, Browser(client: client)] {
                let refused = try await reader.get("/api/v1/cloud\(Self.query("col:\(hers)"))")
                #expect(refused.status == .notFound && problemCode(refused) == "COLLECTION_NOT_FOUND", "\(reader.user ?? "no one")")
            }
            let document = Self.query("doc:frus1961-63v06/d1")
            let before = try await Self.cloud(client, document, user: "bob")
            let word = try #require(before.terms.first?.term)
            _ = try await alice.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "\#(word)"}"#)
            let aliceDocument = try await Self.cloud(client, document, user: "alice")
            #expect(!aliceDocument.terms.contains { $0.term == word } && aliceDocument.account?.contains("under your settings") == true)
            #expect(try await Self.cloud(client, document, user: "bob").terms == before.terms, "Bob's count is his, under his settings")
            let aliceCollection = try await Self.cloud(client, Self.query("col:\(hers)"), user: "alice")
            #expect(aliceCollection.documentCount == 1 && aliceCollection.terms == aliceDocument.terms && aliceCollection.scope.title == "Alice’s")
            let his = try await Self.collection(bob, "Bob’s", of: [("frus1961-63v06", "d1")])
            let bobCollection = try await Self.cloud(client, Self.query("col:\(his)"), user: "bob")
            #expect(bobCollection.terms == before.terms && bobCollection.scope.title == "Bob’s")
            let refused = try await alice.get("/api/v1/cloud\(Self.query("col:\(his)"))")
            #expect(refused.status == .notFound)
        }
    }

    /// While a job of the server's holds the queue: a count asked for twice is one job, and a reader's next count that runs
    /// as a job leaves the one they waited on, which is cancelled since no one else waits on it; the requests that act for
    /// no one wait as one reader, so they hold one place in the queue at most.
    @Test func aReadersNextCountReplacesTheJobTheyWaitedOn() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            _ = try await owner.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "treaty"}"#)
            let gate = JobGate()
            _ = try await fixture.jobs.submit(.indexCheck, subject: "frus.db") { job in
                await gate.wait()
                return nil
            }
            await gate.untilReached()
            async let first = owner.get("/api/v1/cloud\(Self.query("corpus"))")
            async let second = owner.get("/api/v1/cloud\(Self.query("corpus"))")
            let (a, b) = try await (first, second)
            let (one, two) = (try decode(CloudAnswer.self, a), try decode(CloudAnswer.self, b))
            #expect(a.status == .accepted && b.status == .accepted && one.job?.id == two.job?.id && one.job?.state == "queued")
            let topics = try decode(CloudAnswer.self, try await owner.get("/api/v1/cloud\(Self.query("corpus", "topics"))"))
            let replaced = try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(try #require(one.job?.id))"))
            #expect(replaced.state == "cancelled" && replaced.cancelRequestedBy == "owner", "the job the owner waited on, stopped")
            #expect(topics.job?.id != one.job?.id && topics.job?.state == "queued")
            gate.open()
            await fixture.jobs.waitUntilIdle()
            let counted = try await Self.cloud(client, Self.query("corpus", "topics"))
            #expect(counted.state == "terms" && counted.documentCount == 3)
            let jobs = try decode(AdminJobList.self, try await owner.get("/api/v1/admin/jobs")).jobs.filter { $0.kind == "wordCloud" }
            #expect(jobs.map(\.subject) == ["Entire Corpus · Topics (nouns)", "Entire Corpus · All terms"] && jobs.map(\.state) == ["succeeded", "cancelled"])
        }
    }

    @Test func theRequestsThatActForNoOneHoldOnePlaceInTheQueue() async throws {
        let fixture = try await UserDataFixture(userData: false, indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let resolved = try #require(CorpusAnalyticsRoutes.detectedTopics(fixture.server.resources))
            let subjects = ScopeFacets.narrowingCategories(resolvedByVolume: resolved).flatMap { category in
                ScopeFacets.subCategoryCatalog(forCategory: category.label, resolvedByVolume: resolved).map { "subject:\(category.label)\u{1f}\($0.subcategory)" }
            }
            #expect(subjects.count >= 2)
            let gate = JobGate()
            _ = try await fixture.jobs.submit(.indexCheck, subject: "frus.db") { job in
                await gate.wait()
                return nil
            }
            await gate.untilReached()
            let firstAnswer = try decode(CloudAnswer.self, try await client.execute(uri: "/api/v1/cloud\(Self.query(subjects[0]))", method: .get))
            let secondAnswer = try decode(CloudAnswer.self, try await client.execute(uri: "/api/v1/cloud\(Self.query(subjects[1]))", method: .get))
            let first = try #require(firstAnswer.job)
            #expect(firstAnswer.state == "counting" && secondAnswer.state == "counting" && secondAnswer.job?.id != first.id)
            #expect(await fixture.jobs.job(first.id)?.state == .cancelled, "the first request's job, which no one waits on any more")
            gate.open()
            await fixture.jobs.waitUntilIdle()
        }
    }
}
