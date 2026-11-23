// The Word Cloud's routes (PLAN's S24i): what a request may ask of the bundled clouds and what is refused, a live
// scope among them; the reader's settings carried from their synced preferences to their clouds, the criteria set by a
// change to the preferences and the hidden words by routes of their own, each written as the app's settings write it
// and stored as the app syncs it; the settings bench; and two users' settings kept apart. The clouds themselves are
// held to the file's lists, and the settings to the kit's tokenizer, in `WordCloudParityTests`.

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
            #expect(context.lenses.map(\.id) == ["topics", "actions", "concepts", "sentiment"] && context.subseries.count == 107)
            #expect(context.subseries.first?.id == "1861" && context.subseries.first?.volumes.first?.id == "frus1861")
            let first = try await Self.cloud(client)
            #expect(first.scope == .init(signature: "corpus", title: "Entire Corpus") && first.lens.id == "topics", "the corpus, under the bar's first lens")
            #expect(first.state == "terms" && first.terms.count == 50 && first.analyzeWithin == nil)
            let volume = try await Self.cloud(client, "?scope=vol:frus1961-63v06&lens=sentiment")
            #expect(volume.scope.signature == "vol:frus1961-63v06" && volume.scope.title.hasPrefix("Foreign Relations of the United States, 1961–1963, Volume VI"))
            #expect(volume.analyzeWithin?.label == "Analyze within this volume" && volume.analyzeWithin?.volumeIds == ["frus1961-63v06"])
            #expect(volume.analyzeWithin?.scopeLabel == volume.scope.title && volume.terms.allSatisfy { $0.polarity != nil })
            let subseries = try await Self.cloud(client, "?scope=sub:1961-63&lens=concepts")
            #expect(subseries.scope.title == "1961-63" && subseries.analyzeWithin?.label == "Analyze within this subseries")
            #expect(subseries.analyzeWithin?.volumeIds.allSatisfy { $0.hasPrefix("frus1961-63") } == true && subseries.analyzeWithin?.scopeLabel == "1961-63")

            let refusals: [(String, HTTPResponse.Status, String)] = [
                ("/api/v1/cloud?scope=doc:frus1961-63v06/d1", .unprocessableContent, "LIVE_SCOPE"),
                ("/api/v1/cloud?scope=col:5E17F000-0000-4000-8000-0000000000A1", .unprocessableContent, "LIVE_SCOPE"),
                ("/api/v1/cloud?scope=daterange:1962-10-01..1962-10-31", .unprocessableContent, "LIVE_SCOPE"),
                ("/api/v1/cloud?scope=sub:1800", .notFound, "SUBSERIES_NOT_FOUND"),
                ("/api/v1/cloud?scope=vol:frus1800v01", .notFound, "VOLUME_NOT_FOUND"),
                ("/api/v1/cloud?scope=everything", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?scope=era:1969-76", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?lens=people", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?lens=allTerms", .badRequest, "INVALID_PARAMETER"),
                ("/api/v1/cloud?measure=keyness", .badRequest, "UNKNOWN_PARAMETER"),
                ("/api/v1/cloud/context?scope=corpus", .badRequest, "UNKNOWN_PARAMETER"),
                ("/api/v1/cloud?scope=corpus&scope=sub:1861", .badRequest, "INVALID_PARAMETER"),
            ]
            for (path, status, code) in refusals {
                let response = try await client.execute(uri: path, method: .get)
                #expect(response.status == status && problemCode(response) == code, "\(path): \(response.status) \(String(buffer: response.body))")
            }
            let live = try decode(APIProblem.Body.self, try await client.execute(uri: "/api/v1/cloud?scope=doc:frus1961-63v06/d1", method: .get))
            #expect(live.detail.contains("this server's language analysis cannot do yet"))
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
    @Test func theHiddenWordsAreKeptAsTheAppKeepsThem() async throws {
        let fixture = try await UserDataFixture()
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
            _ = try await owner.send(.post, "/api/v1/me/preferences/hidden-words", #"{"word": "ambassador", "lens": "concepts"}"#)
            #expect(try await sample().kept.contains { $0.term == "ambassador" }, "a lens's word is hidden under that lens alone")
            let concepts = try await sample("?lens=concepts")
            #expect(!concepts.kept.contains { $0.term == "ambassador" } && concepts.kept.count < thresholds.kept.count, "the lens's lexicon and its own list")
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
}
