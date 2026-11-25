// Distinctive and Collocates (PLAN's S29f) over the fixture index: each ranking through the API is the kit's
// `KeynessCloud.rank` of the same count against the same reference, and each collocation through the API is the kit's
// `SearchService.collocation` over the same index, results and reference, each made here apart from the server: the
// count by the kit's `WordCloudCount.count` with the web's tagger over the fixture index's own pipeline, the results by
// the fixture index's own search service, the configuration by the kit over the word lists decoded here, and the
// references by the kit's reading of the family's two files by URL. The refusals are the kit's, each in the app's words:
// a reader's settings the reference was not counted under, a reference another tokenizer counted, none at all, and a
// scope whose text the served index does not hold; and the scan runs on the queue it prefers, off Swift's cooperative
// pool.

import Dispatch
import FRUSCoreKit
import FRUSLanguage
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing
import WordCloudKit

@testable import FRUSLightAPI

/// What both suites read apart from the server, read once.
enum LanguageReadings {
    /// The family's references as the kit reads them by URL, with the digests of the app's word lists.
    static let references = KeynessReferences(
        dictionaryAt: RepositoryFiles.language.appendingPathComponent("keyness-baseline.json"),
        printedAt: RepositoryFiles.language.appendingPathComponent("keyness-baseline-printed.json"),
        lexiconsAt: ServedFixture.resources.appendingPathComponent("word-cloud-lexicons.json"),
        stopwordsAt: ServedFixture.resources.appendingPathComponent("word-cloud-stopwords.json"))

    /// Whether two doubles are one, but for the last bits a JSON round trip on Linux can move (S23d's lesson).
    static func same(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= 1e-9 * max(1, abs(b)) }

    /// A request through the test client, its answer decoded, or what the server said instead. The client is the router's,
    /// which waits as long as an answer takes, where a live server's client gives up at 20 s.
    static func answer<T: Decodable>(_ type: T.Type, _ client: any TestClientProtocol, _ path: String) async throws -> T {
        let response = try await client.execute(uri: path, method: .get)
        guard response.status == .ok else { throw APIParityError("\(path): \(response.status.code) \(String(buffer: response.body))") }
        return try ServedFixture.decode(T.self, response)
    }

    /// A language folder of the family's clouds with other references beside them, or none: `references` maps each
    /// reference's name to the file it is a copy of.
    static func folder(references: [String: URL]) throws -> TemporaryDirectory {
        let directory = try TemporaryDirectory()
        for name in ["cloud-vectors-core.json", "cloud-vectors-volumes.json"] {
            try FileManager.default.copyItem(at: RepositoryFiles.language.appendingPathComponent(name),
                                             to: directory.url.appendingPathComponent(name))
        }
        for (name, source) in references {
            try FileManager.default.copyItem(at: source, to: directory.url.appendingPathComponent(name))
        }
        return directory
    }
}

/// Serialized, since its tests count the fixture volumes' words in a debug build beside the target's live servers, as
/// S29e's suite is (CI's warning, S29e's hand-over).
@Suite(.serialized) struct DistinctiveParityTests {
    typealias Fixture = WordCloudLiveParityTests.Fixture

    /// The kit's ranking of `count`, as the app's view ranks the terms its cloud shows (`WordCloudView.recomputeKeyness`),
    /// made apart: its terms less `hidden`, its true total, the terms it fetched against the app's limit of 1,000
    /// (`WordCloudLoader.standardTermLimit`), the reader's tuning and layer, the count's verdict and the tagger's identity.
    static func kitsRanking(_ count: WordCloudResult, lens: WordCloudLens, hidden: Set<String> = [], tuning: WordCloudTuning = .standard,
                            includeDiplomatic: Bool = true, references: KeynessReferences = LanguageReadings.references) -> KeynessCloud.Outcome {
        let tagger = FRUSWordCloudTagger()
        return KeynessCloud.rank(terms: count.visibleTerms(excluding: hidden), scopeTotal: count.totalTokenCount,
                                 fetchedTermCount: count.terms.count, termLimit: 1_000, lens: lens, tuning: tuning,
                                 includeDiplomatic: includeDiplomatic, languageAnalysis: count.languageAnalysis ?? tagger.health,
                                 references: references, tokenizer: tagger.identity)
    }

    /// The kit's name of a refusal.
    static func reason(_ outcome: KeynessCloud.Outcome) -> String? {
        guard case .unavailable(let reason) = outcome else { return nil }
        switch reason {
        case .pending: return "pending"
        case .noArtifact: return "noArtifact"
        case .lensNotPriced: return "lensNotPriced"
        case .configurationMismatch: return "configurationMismatch"
        case .languageAnalysisUnavailable: return "languageAnalysisUnavailable"
        case .noTermsAboveFloor: return "noTermsAboveFloor"
        case .nothingOverRepresented: return "nothingOverRepresented"
        }
    }

    /// Holds the server's reading to the kit's outcome, word for word and number for number.
    static func expect(_ reading: CloudDistinctive?, isTheKits outcome: KeynessCloud.Outcome, documents: Int, _ label: String) {
        guard let reading else {
            Issue.record("\(label): no Distinctive reading")
            return
        }
        switch outcome {
        case .unavailable(let reason):
            #expect(reading.state == "unavailable" && reading.reason == Self.reason(outcome) && reading.scores.isEmpty, "\(label): \(reason)")
            #expect(reading.message?.title == "No Distinctiveness Ranking", "\(label)")
        case .ranked(let ranking):
            #expect(reading.state == "ranked", "\(label): \(reading.reason ?? "")")
            #expect(reading.scores.map(\.term) == ranking.scores.map(\.term), "\(label): the words, in the kit's order")
            for (served, kits) in zip(reading.scores, ranking.scores) {
                #expect(served.scopeCount == kits.scopeCount && served.referenceCount == kits.referenceCount
                        && LanguageReadings.same(served.logLikelihood, kits.logLikelihood) && LanguageReadings.same(served.logRatio, kits.logRatio)
                        && LanguageReadings.same(served.fold, kits.foldOverRepresentation) && served.unpriced == ranking.isUnpriced(kits),
                        "\(label): \(kits.term)")
            }
            #expect(reading.layout.map { "\($0.term) \($0.count)" } == KeynessCloud.layoutTerms(ranking.scores).map { "\($0.term) \($0.count)" },
                    "\(label): the cloud's layout input")
            #expect(reading.candidateCount == ranking.candidateCount && reading.rankedAmongTopFrequent == ranking.rankedAmongTopFrequent
                    && reading.minimumScopeCount == ranking.minimumScopeCount && reading.referenceRetained == ranking.referenceRetained
                    && reading.referenceDistinct == ranking.referenceDistinct && reading.referenceCutoffCount == ranking.referenceCutoffCount
                    && reading.generated == ranking.generated && reading.wordForm == ranking.wordForm.rawValue, "\(label): the ranking's facts")
            // The app's words over the kit's facts (`keynessCaveat`, `headerCountLine`), which the words suite holds to its source.
            let bound = ranking.rankedAmongTopFrequent
                ? "Ranked among this scope’s \(ranking.candidateCount) most frequent words."
                : "Ranked over every word occurring at least \(ranking.minimumScopeCount) times here."
            #expect(reading.caveat == "\(bound) Words occurring fewer than \(ranking.referenceCutoffCount) times corpus-wide are unpriced and score as if new.",
                    "\(label): the caveat")
            #expect(reading.countLine == CloudRules.countLine(terms: ranking.scores.count, documents: documents), "\(label): the count line")
            #expect(reading.comparedAsPrinted == nil && ranking.wordForm == .dictionary, "\(label): the web's tagger reduces every word")
        }
    }

    /// A cloud under Distinctive through the API, with the words hidden from it.
    static func cloud(_ client: any TestClientProtocol, _ scope: String, _ lens: WordCloudLens, hidden: [String] = []) async throws -> CloudAnswer {
        let encoded = scope.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let words = hidden.map { "&hidden=\($0.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)" }.joined()
        return try await LanguageReadings.answer(CloudAnswer.self, client, "/api/v1/cloud?scope=\(encoded)&lens=\(lens.rawValue)&measure=keyness\(words)")
    }

    @Test func eachRankingThroughTheAPIIsTheKitsForTheSameCountsAndReference() async throws {
        let fixture = try await WordCloudLiveParityTests.shared.value
        let pipeline = fixture.pipeline
        try await ServedFixture.run { client, _ in
            // A volume, which the family holds a list of, counted live under Distinctive at the family's settings, as the
            // app's view counts every scope it ranks: every row the index holds of it.
            let rows = try await WordCloudLiveParityTests.rows("frus1961-63v06", in: pipeline)
            let volume = try await WordCloudLiveParityTests.kitsCount(rows, lens: .allTerms, pipeline: pipeline)
            let ranked = try await Self.cloud(client, "vol:frus1961-63v06", .allTerms)
            #expect(ranked.source == "live" && ranked.state == "terms" && ranked.documentCount == rows.count)
            #expect(ranked.terms.map { "\($0.term) \($0.count)" } == WordCloudLiveParityTests.lines(volume.terms), "the volume's count is the kit's")
            let outcome = Self.kitsRanking(volume, lens: .allTerms)
            guard case .ranked(let ranking) = outcome else {
                Issue.record("the kit ranks the volume: \(outcome)")
                return
            }
            #expect(ranking.scores.count > 20 && ranking.rankedAmongTopFrequent, "a volume's thousand words are a pool the limit cut")
            Self.expect(ranked.distinctive, isTheKits: outcome, documents: rows.count, "the volume under All terms")

            // The words hidden from this cloud alone: ranked without them, the fetched count still the thousand.
            let hidden = ranking.scores.prefix(2).map(\.term)
            let without = try await Self.cloud(client, "vol:frus1961-63v06", .allTerms, hidden: hidden)
            Self.expect(without.distinctive, isTheKits: Self.kitsRanking(volume, lens: .allTerms, hidden: Set(hidden)), documents: rows.count,
                        "the volume without \(hidden)")
            #expect(without.distinctive?.scores.contains { hidden.contains($0.term) } == false)
            #expect(without.terms.count == ranked.terms.count, "the count's terms are the count's; the page hides them under Frequency")

            // The sentiment lens: each word with the lexicon's polarity.
            let sentimentCount = try await WordCloudLiveParityTests.kitsCount(rows, lens: .sentiment, pipeline: pipeline)
            let sentiment = try await Self.cloud(client, "vol:frus1961-63v06", .sentiment)
            Self.expect(sentiment.distinctive, isTheKits: Self.kitsRanking(sentimentCount, lens: .sentiment), documents: rows.count, "the volume under Sentiment")
            let host = try WordCloudParityTests.Host.open()
            #expect(sentiment.distinctive?.scores.allSatisfy { $0.polarity == host.lexicons.polarity(of: $0.term.lowercased()) } == true)

            // A document of another volume, whatever the kit's ranking of it says.
            let key = WordCloudDocumentKey(volumeId: "frus1969-76ve09p1", documentId: "d12")
            let one = try await WordCloudLiveParityTests.kitsCount([key], lens: .topics, pipeline: pipeline)
            let document = try await Self.cloud(client, "doc:frus1969-76ve09p1/d12", .topics)
            Self.expect(document.distinctive, isTheKits: Self.kitsRanking(one, lens: .topics), documents: 1, "a document under Topics")

            // Frequency carries no ranking, and takes no hidden word.
            let frequency = try await LanguageReadings.answer(CloudAnswer.self, client, "/api/v1/cloud?scope=vol%3Afrus1961-63v06&lens=allTerms")
            #expect(frequency.distinctive == nil && frequency.source == "family", "Frequency's list is the family's at its settings")
            let refused = try await client.execute(uri: "/api/v1/cloud?scope=corpus&lens=allTerms&hidden=treaty", method: .get)
            #expect(refused.status == .badRequest && String(buffer: refused.body).contains("INVALID_PARAMETER"))
        }
    }

    @Test func aReadersSettingsTheReferenceWasNotCountedUnderAreRefusedInTheAppsWords() async throws {
        try await ServedFixture.run { client, _ in
            let me = try ServedFixture.decode(Me.self, try await client.execute(uri: "/api/v1/me", method: .get))
            func patch(_ json: String) async throws {
                let response = try await client.execute(uri: "/api/v1/me/preferences", method: .patch,
                                                        headers: [.origin: "http://localhost:8080", CSRFTokens.header: me.csrfToken,
                                                                  .contentType: "application/json"],
                                                        body: ByteBuffer(string: #"{"wordCloud":\#(json)}"#))
                #expect(response.status == .ok, "\(json)")
            }
            // Each setting the kit's rule names, in the app's words, as the reference's lookup refuses it.
            let cases: [(json: String, mismatch: KeynessBaselineFile.Configuration.Mismatch, words: String)] = [
                (#"{"minLength":2}"#, .minimumLength, "your minimum word length is shorter"),
                (#"{"minLength":3,"foldPlurals":false}"#, .foldPlurals, "plural folding differs"),
                (#"{"foldPlurals":true,"filterMarkings":false}"#, .filterMarkings, "classification-marking filtering differs"),
                (#"{"filterMarkings":true,"excludeBoilerplate":false}"#, .diplomaticLayer, "“Hide common diplomatic words” is off"),
            ]
            for each in cases {
                try await patch(each.json)
                let answer = try await Self.cloud(client, "doc:frus1961-63v06/d3", .allTerms)
                #expect(answer.state == "terms" && answer.source == "live", "\(each.mismatch): the count is the reader's")
                let reading = try #require(answer.distinctive, "\(each.mismatch)")
                #expect(reading.state == "unavailable" && reading.reason == "configurationMismatch" && reading.mismatches == [each.mismatch.rawValue],
                        "\(each.mismatch): \(reading.reason ?? "")")
                #expect(reading.message?.detail == "Your settings count words differently from the bundled corpus reference, so the two can’t be compared: \(each.words). Restore that setting to compare this scope with the corpus.",
                        "\(each.mismatch): \(reading.message?.detail ?? "")")
            }
            // A longer word than the reference's is no mismatch: it trims the scope, which the kit ranks.
            try await patch(#"{"minLength":5,"excludeBoilerplate":true}"#)
            let longer = try await Self.cloud(client, "vol:frus1961-63v06", .allTerms)
            #expect(longer.distinctive?.state == "ranked" && longer.distinctive?.scores.allSatisfy { $0.term.count >= 5 } == true)

            // A volume the served index holds none of: the family's list, which Distinctive cannot rank, says why.
            let unheld = try await Self.cloud(client, "vol:frus1961-63v05", .allTerms)
            #expect(unheld.source == "family" && unheld.distinctive?.reason == "noCount" && unheld.distinctive?.state == "unavailable")
            #expect(unheld.distinctive?.message?.detail.contains("this server’s index holds none of them") == true)
        }
    }

    @Test func aReferenceAnotherTokenizerCountedOrNoneAtAllIsRefusedInTheAppsWords() async throws {
        let fixture = try await WordCloudLiveParityTests.shared.value
        let rows = try await WordCloudLiveParityTests.rows("frus1894Nicaragua", in: fixture.pipeline)
        let count = try await WordCloudLiveParityTests.count(rows, fixture: fixture)
        let apps = ServedFixture.resources
        // The app's bundled references, which NaturalLanguage counted, beside the family's clouds.
        let other = try LanguageReadings.folder(references: [
            "keyness-baseline.json": apps.appendingPathComponent("keyness-baseline.json"),
            "keyness-baseline-printed.json": apps.appendingPathComponent("keyness-baseline-printed.json"),
        ])
        let none = try LanguageReadings.folder(references: [:])
        for (folder, words) in [(other, "the reference was counted by another tokenizer"), (none, "")] {
            let resources = try ServerResources.load(from: ServedFixture.resources, language: folder.url)
            let references = resources.familyClouds.references(language: resources.languageDirectory, lists: resources.directory)
            let lexicons = resources.familyClouds.lexicons(in: resources.directory)
            let reading = CloudRules.distinctive(count, lens: .allTerms, settings: .standard, hidden: [], references: references, lexicons: lexicons)
            let kits = Self.kitsRanking(count, lens: .allTerms, references: KeynessReferences(
                dictionaryAt: folder.url.appendingPathComponent("keyness-baseline.json"),
                printedAt: folder.url.appendingPathComponent("keyness-baseline-printed.json"),
                lexiconsAt: apps.appendingPathComponent("word-cloud-lexicons.json"), stopwordsAt: apps.appendingPathComponent("word-cloud-stopwords.json")))
            Self.expect(reading, isTheKits: kits, documents: rows.count, words.isEmpty ? "no reference" : "another tokenizer's")
            if words.isEmpty {
                #expect(kits == .unavailable(.noArtifact))
                #expect(reading.message?.detail == "The bundled corpus reference could not be loaded, so there is nothing to measure this scope against.")
            } else {
                #expect(kits == .unavailable(.configurationMismatch([.tokenizer])))
                #expect(reading.mismatches == ["tokenizer"] && reading.message?.detail.contains(": \(words). Restore") == true, "\(reading.message?.detail ?? "")")
            }
        }
    }
}

extension WordCloudLiveParityTests {
    /// The server's own count of `keys` under All terms at the standard settings.
    static func count(_ keys: [WordCloudDocumentKey], fixture: Fixture) async throws -> WordCloudResult {
        try await WordCloudLive.count(keys, lens: .allTerms, settings: .standard, served: fixture.served, resources: fixture.resources)
    }
}

/// Serialized, since its scans tag the fixture volumes' words in a debug build beside the target's live servers.
@Suite(.serialized) struct CollocatesParityTests {
    /// The kit's collocation of the search `query` says over the fixture index, made apart from the server, as the Mac's
    /// window builds it: the results it keeps, 7,500 at most, less `reviewed`; the kit's configuration over the word lists
    /// decoded here, at the app's own settings; the reference the kit's lookup gives it; and the kit's scan with the web's
    /// tagger.
    static func kits(_ query: String, window: Int, reviewed: Set<String> = []) async throws -> (CollocationAnalysis.Outcome, results: Int) {
        let service = try await FixtureIndex.value().index.service
        let parameters = try SearchRequest(formEncoded: query).parameters
        let kept = try await service.search(parameters: parameters, limit: 7_500, offset: 0)
            .filter { !reviewed.contains("\($0.volumeId)/\($0.documentId)") }
        guard !kept.isEmpty else { return (.unavailable(.noMatches), 0) }
        let host = try WordCloudParityTests.Host.open()
        let tagger = FRUSWordCloudTagger()
        let configuration = CollocationConfiguration.configured(tuning: .standard, includeDiplomatic: true, languageAnalysis: tagger.health,
                                                                stopwords: host.stopwords, lexicons: host.lexicons)
        guard case .available(let reference) = LanguageReadings.references.baseline(
            for: .allTerms, tuning: .standard, includeDiplomatic: true, languageAnalysis: tagger.health, tokenizer: tagger.identity)
        else { throw APIParityError("the family's reference is refused at the app's own settings") }
        let outcome = try await service.collocation(for: kept, parameters: parameters, windowSize: window, configuration: configuration,
                                                    reference: reference, tagger: tagger)
        return (outcome, kept.count)
    }

    /// Holds the server's collocates to the kit's outcome, word for word and number for number, with each order's.
    static func expect(_ served: SearchCollocates, isTheKits outcome: CollocationAnalysis.Outcome, window: Int, _ label: String) {
        #expect(served.window == window && served.windowChoices.map(\.value) == ["5", "10", "20", "50"]
                && served.orderChoices.map(\.title) == ["Evidence", "Concentration"], "\(label): the panel's controls")
        switch outcome {
        case .unavailable(let reason):
            #expect(served.state == "unavailable" && served.reason == CollocationRules.name(of: reason) && served.items.isEmpty, "\(label): \(reason)")
            #expect(served.message?.title == "No Collocates", "\(label)")
        case .ranked(let result):
            #expect(served.state == "ranked", "\(label): \(served.reason ?? "")")
            #expect(served.items.map(\.term) == result.scores.map(\.term), "\(label): the neighbours, in the kit's order")
            for (neighbour, kits) in zip(served.items, result.scores) {
                #expect(neighbour.nearby == kits.scopeCount && neighbour.corpusWide == kits.referenceCount
                        && LanguageReadings.same(neighbour.logLikelihood, kits.logLikelihood) && LanguageReadings.same(neighbour.logRatio, kits.logRatio)
                        && LanguageReadings.same(neighbour.fold, kits.foldOverRepresentation)
                        && neighbour.unpriced == (kits.referenceCount == 0 && result.referenceCutoffCount > 1), "\(label): \(kits.term)")
            }
            #expect(served.documentsScanned == result.documentsScanned && served.documentsInScope == result.documentsInScope
                    && served.documentsOffered == result.documentsOffered && served.anchorCount == result.anchorCount
                    && served.omittedAnchorCount == result.omittedAnchorCount && served.windowTokenCount == result.windowTokenCount
                    && served.minimumCount == result.minimumCount && served.referenceCutoffCount == result.referenceCutoffCount
                    && served.generated == result.generated && served.wordForm == result.wordForm.rawValue
                    && served.wasBounded == result.wasBounded, "\(label): what the scan read")
            // The two orders, made here as the app's `CollocationOrder.apply` makes them: G² down, and the multiple down
            // with the unpriced last, each tie broken by the word.
            let unpriced = { (score: KeynessScore) in score.referenceCount == 0 && result.referenceCutoffCount > 1 }
            let evidence = result.scores.sorted { ($0.logLikelihood, $1.term) > ($1.logLikelihood, $0.term) }.map(\.term)
            let effect = result.scores.sorted {
                unpriced($0) != unpriced($1) ? !unpriced($0) : ($0.logRatio, $1.term) > ($1.logRatio, $0.term)
            }.map(\.term)
            #expect(served.orders["evidence"]?.map { served.items[$0].term } == evidence, "\(label): Evidence")
            #expect(served.orders["effect"]?.map { served.items[$0].term } == effect, "\(label): Concentration")
            #expect(served.caveat?.contains(CollocationRules.scanned(matches: result.anchorCount, documents: result.documentsScanned)) == true,
                    "\(label): \(served.caveat ?? "")")
            #expect(served.printedFormsNote == nil && result.wordForm == .dictionary, "\(label): the web's tagger reduces every word")
        }
    }

    static func collocates(_ client: any TestClientProtocol, _ query: String) async throws -> SearchCollocates {
        try await LanguageReadings.answer(SearchCollocates.self, client, "/api/v1/search/collocates?\(query)")
    }

    @Test func eachCollocationThroughTheAPIIsTheKitsOverTheSameIndex() async throws {
        let service = try await FixtureIndex.value().index.service
        try await ServedFixture.run { client, _ in
            // Searches of the three volumes: a word in all three, a name in one, two words together, and a sparse name,
            // each within a window the panel offers, the app's ten when none is asked.
            for (query, window) in [("keywords=treaty", 10), ("keywords=Berlin&window=5", 5), ("keywords=nuclear%20test&window=20", 20),
                                    ("keywords=Mosquito&window=50", 50), ("keywords=Zorin", 10)] {
                let served = try await Self.collocates(client, query)
                let (outcome, results) = try await Self.kits(query.components(separatedBy: "&window=")[0], window: window)
                Self.expect(served, isTheKits: outcome, window: window, query)
                #expect(served.retainedCount == results && served.retainedLimit == 7_500, "\(query)")
            }

            // The fixtures hold every match the index has of "treaty", so the caveat measured every matching document.
            let treaty = try await Self.collocates(client, "keywords=treaty")
            #expect(treaty.state == "ranked" && treaty.items.count > 10, "treaty: \(treaty.reason ?? "")")
            #expect(treaty.caveat?.contains("Measured over every result this search loaded, which is every matching document.") == true)
            #expect(treaty.caveat?.hasPrefix("Words occurring fewer than \(treaty.referenceCutoffCount ?? 0) times corpus-wide are unpriced and score as if new. ") == true)

            // In Checklist Mode, the results kept less those it hides, and the caveat counts them.
            let first = try await service.search(parameters: try SearchRequest(formEncoded: "keywords=treaty").parameters, limit: 3, offset: 0)
            let reviewed = first.map { "\($0.volumeId)/\($0.documentId)" }
            let fields = "keywords=treaty&" + reviewed.map { "reviewed=\($0.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)" }.joined(separator: "&")
            let hiding = try await Self.collocates(client, fields)
            let (outcome, results) = try await Self.kits("keywords=treaty", window: 10, reviewed: Set(reviewed))
            Self.expect(hiding, isTheKits: outcome, window: 10, "treaty in Checklist Mode")
            #expect(hiding.caveat?.contains("which is every matching document. 3 reviewed documents are excluded.") == true, "\(hiding.caveat ?? "")")
            #expect(hiding.documentsInScope == results && results == treaty.documentsInScope.map { $0 - 3 })
            // The same as a POST of its form, for a Checklist Mode that hides more results than an address holds.
            let posted = try await client.execute(uri: "/api/v1/search/collocates", method: .post,
                                                  headers: [.contentType: "application/x-www-form-urlencoded"], body: ByteBuffer(string: fields))
            #expect(posted.status == .ok)
            #expect(try ServedFixture.decode(SearchCollocates.self, posted) == hiding, "the POST's answer is the address's")
            // In the date's order, which decides what a scan the budget stops reads; the fixtures' scans read every result.
            let dated = try await Self.collocates(client, "keywords=treaty&sort=dateAscending")
            #expect(dated.items == treaty.items && dated.documentsOffered == treaty.documentsOffered)

            // A search that matched nothing, and one with no word the scan can centre on.
            let none = try await Self.collocates(client, "keywords=zzyzx")
            #expect(none.state == "unavailable" && none.reason == "noMatches" && none.retainedCount == 0)
            #expect(none.message?.detail == "None of these results contains a whole word this measure can center on. Phrase, wildcard and proximity searches match in ways a word window cannot anchor to.")
            // A window the panel does not offer is refused.
            let refused = try await client.execute(uri: "/api/v1/search/collocates?keywords=treaty&window=13", method: .get)
            #expect(refused.status == .badRequest && String(buffer: refused.body).contains("INVALID_PARAMETER"))
        }
    }

    @Test func theRefusalsAreTheKitsInTheAppsWords() async throws {
        let built = try await FixtureIndex.value()
        let results = try await built.index.service.search(parameters: try SearchRequest(formEncoded: "keywords=treaty").parameters, limit: 7_500, offset: 0)
        let parameters = try SearchRequest(formEncoded: "keywords=treaty").parameters
        let fixture = try await WordCloudLiveParityTests.shared.value
        let scoped = try fixture.served.ownSearch(for: nil)
        // A reader's settings the reference was not counted under: the kit's lookup refuses them before any scan.
        var settings = CloudSettings.standard
        settings.tuning.minimumLength = 2
        settings.includeDiplomatic = false
        let mismatch = try await CollocatesRoutes.outcome(of: results, parameters: parameters, window: 10, settings: settings, scoped: scoped,
                                                          resources: fixture.resources)
        #expect(mismatch == .unavailable(.configurationMismatch([.diplomaticLayer, .minimumLength])))
        #expect(CollocationRules.detail(for: try #require(mismatch.reason))
                == "Your Word Cloud settings count words differently from the bundled corpus reference, so the two can’t be compared: “Hide common diplomatic words” is off; your minimum word length is shorter. Restore that setting to rank these neighbors.")

        // A reference another tokenizer counted, the app's bundled ones, and none at all.
        let apps = ServedFixture.resources
        let other = try LanguageReadings.folder(references: [
            "keyness-baseline.json": apps.appendingPathComponent("keyness-baseline.json"),
            "keyness-baseline-printed.json": apps.appendingPathComponent("keyness-baseline-printed.json"),
        ])
        let none = try LanguageReadings.folder(references: [:])
        for (folder, expected) in [(other, CollocationAnalysis.Outcome.unavailable(.configurationMismatch([.tokenizer]))), (none, .unavailable(.noArtifact))] {
            let resources = try ServerResources.load(from: ServedFixture.resources, language: folder.url)
            let outcome = try await CollocatesRoutes.outcome(of: results, parameters: parameters, window: 10, settings: .standard, scoped: scoped,
                                                             resources: resources)
            #expect(outcome == expected)
        }
        #expect(CollocationRules.detail(for: .configurationMismatch([.tokenizer])).contains(": the reference was counted by another tokenizer. Restore"))
        #expect(CollocationRules.detail(for: .noArtifact)
                == "The bundled corpus reference could not be loaded, so there is nothing to measure these neighborhoods against.")
        // No results, before anything is read.
        #expect(try await CollocatesRoutes.outcome(of: [], parameters: parameters, window: 10, settings: .standard, scoped: scoped,
                                                   resources: fixture.resources) == .unavailable(.noMatches))
    }

    /// The web's tagger, noting the queue each of its walks runs on.
    final class QueueNotingTagger: WordCloudTagger, @unchecked Sendable {
        let inner = FRUSWordCloudTagger()
        private let lock = NSLock()
        private var noted: [String?] = []

        var queues: [String?] {
            lock.lock()
            defer { lock.unlock() }
            return noted
        }
        var identity: WordCloudTokenizerIdentity { inner.identity }
        var health: NaturalLanguageHealth { inner.health }

        private func note() {
            let queue = DispatchQueue.getSpecific(key: CollocationExecutor.label)
            lock.lock()
            noted.append(queue)
            lock.unlock()
        }

        func enumerateWords(in text: String, reading: WordCloudTagReading,
                            using body: (Range<String.Index>, String?, () -> WordCloudLexicalClass?) -> Bool) {
            note()
            inner.enumerateWords(in: text, reading: reading, using: body)
        }

        func enumerateNames(in text: String, using body: (Range<String.Index>, WordCloudNameType?) -> Bool) {
            note()
            inner.enumerateNames(in: text, using: body)
        }
    }

    @Test func theScansTaggingRunsOnTheQueueItPrefers() async throws {
        // The kit's scan as the route runs it, on a service of its own over the served index, which hops to the index's
        // pipeline for each chunk's texts and fans the chunk out before it tags: every walk of the tagger is on the queue.
        let fixture = try await WordCloudLiveParityTests.shared.value
        let scoped = try fixture.served.ownSearch(for: nil)
        let parameters = try SearchRequest(formEncoded: "keywords=treaty").parameters
        let results = try await scoped.service.search(parameters: parameters, limit: 7_500, offset: 0)
        let host = try WordCloudParityTests.Host.open()
        let tagger = QueueNotingTagger()
        let configuration = CollocationConfiguration.configured(tuning: .standard, includeDiplomatic: true, languageAnalysis: tagger.health,
                                                                stopwords: host.stopwords, lexicons: host.lexicons)
        guard case .available(let reference) = LanguageReadings.references.baseline(
            for: .allTerms, tuning: .standard, includeDiplomatic: true, languageAnalysis: tagger.health, tokenizer: tagger.identity)
        else { throw APIParityError("the family's reference is refused at the app's own settings") }
        let outcome = try await CollocationExecutor.run(label: "frus-light.collocates") {
            try await scoped.service.collocation(for: results, parameters: parameters, windowSize: 10, configuration: configuration,
                                                 reference: reference, tagger: tagger)
        }
        #expect(tagger.queues.count >= 2 && tagger.queues.allSatisfy { $0 == "frus-light.collocates" }, "\(tagger.queues)")
        let kits = try await Self.kits("keywords=treaty", window: 10).0
        #expect(outcome == kits, "the same scan as the kit's apart")
    }

    @Test func theScopeSentenceIsTheAppsForEachSet() {
        // Every match kept; the 7,500 reached, or a count above what was kept; inside a corpus captured short; and the
        // reviewed documents Checklist Mode excludes, one and more.
        let complete = "Measured over every result this search loaded, which is every matching document."
        let capped = "Measured over every result this search loaded, not the page on screen — those are the highest-scoring matches, not a sample of all of them."
        #expect(CollocationRules.scopeDescription(.init(loaded: 30, shown: 30, total: 30, insideTruncatedCorpus: false)) == complete)
        #expect(CollocationRules.scopeDescription(.init(loaded: 7_500, shown: 7_499, total: 9_012, insideTruncatedCorpus: false))
                == capped + " 1 reviewed document is excluded.")
        #expect(CollocationRules.scopeDescription(.init(loaded: 40, shown: 40, total: 41, insideTruncatedCorpus: false)) == capped)
        #expect(CollocationRules.scopeDescription(.init(loaded: 12, shown: 10, total: 12, insideTruncatedCorpus: true))
                == capped + " 2 reviewed documents are excluded.")
    }

    @Test func theScanRunsOnTheQueueItPrefersOffTheCooperativePool() async throws {
        // A default actor's work follows the executor its caller's task prefers (SE-0417), as the search service's does,
        // once the task is on it: entered first, from a thread of the pool, it runs there, so `run` moves the task first.
        actor Probe {
            func queue() -> String? { DispatchQueue.getSpecific(key: CollocationExecutor.label) }
            func afterASuspension() async -> String? {
                await Task.yield()
                return DispatchQueue.getSpecific(key: CollocationExecutor.label)
            }
        }
        let probe = Probe()
        let preferred = try await CollocationExecutor.run(label: "frus-light.collocates") {
            (await probe.queue(), await probe.afterASuspension())
        }
        #expect(preferred.0 == "frus-light.collocates" && preferred.1 == "frus-light.collocates", "\(preferred)")
        #expect(await probe.queue() == nil, "without the preference, the pool")
    }
}

extension CollocationAnalysis.Outcome {
    /// The refusal, for a test.
    var reason: CollocationAnalysis.Unavailable? {
        if case .unavailable(let reason) = self { reason } else { nil }
    }
}
