// Live word clouds (PLAN's S29e) over the fixture index: a live count of each fixture volume is the language family's
// list for it, and a document's, a collection's and a saved search's clouds through the API are the kit's count over the
// same texts.
//
// The family's lists were counted by the app's generator from the TEI's document divisions (`TEIBodyTextExtractor`),
// and a live count reads the index's text. Over the documents the family counted, a live count of each fixture volume at
// the family's settings is its list under every lens the family carries, but for six entries of the 900, which the two
// texts join apart (#1421: the index joins a run as the page prints it, as "—Qadhafi", where the generator's scan puts
// a space at every tag), named here one by one so that any other difference fails. A volume's own cloud reads every
// document the index holds of it, as the app's resolver reads them, the front matter it promotes to documents
// (index version 70: a preface, the terms, a note on covert actions) among them, which the family's scan never counted;
// that cloud is held to the kit's count over the same rows.

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

@Suite struct WordCloudLiveParityTests {
    /// The fixture index served as a server serves it, and the data files a server reads, opened once for the suite.
    struct Fixture: @unchecked Sendable {
        let served: ServedIndex
        let resources: ServerResources
        let pipeline: IndexingPipeline
    }

    static let shared = Task<Fixture, any Error> {
        let built = try await FixtureIndex.value()
        let resources = try ServerResources.load(from: ServedFixture.resources, language: RepositoryFiles.language)
        let served = try ServedIndex(corpus: try CorpusIndex.open(built.copy), resources: resources,
                                     volumesDirectory: built.directory.url.appendingPathComponent("Volumes"))
        // What a count reads once, read here, so that no test's first count waits on it.
        _ = WordCloudLive.tagger.identity
        _ = resources.familyClouds.stopwords(in: resources.directory)
        _ = resources.familyClouds.lexicons(in: resources.directory)
        return Fixture(served: served, resources: resources, pipeline: built.index.pipeline)
    }

    /// The lenses the family's files carry, `CloudVectorsRunner.baselineLenses`'.
    static let familyLenses: [WordCloudLens] = [.allTerms, .descriptors, .concepts, .topics, .actions, .sentiment]

    /// The entries of the family's lists a live count over the same documents gives otherwise: the words the index's
    /// printed join (#1421) reads apart from the generator's scan, each its list's index, the file's entry and the
    /// count's.
    static let printedJoinResidue: [String: [(index: Int, file: String, live: String)]] = [
        "frus1894Nicaragua allTerms": [(46, "braida 115", "braida 114")],
        "frus1894Nicaragua topics": [(33, "braida 115", "braida 114")],
        "frus1961-63v06 actions": [(35, "remain 70", "bring 69"), (36, "bring 69", "remain 69")],
        "frus1969-76ve09p1 allTerms": [(7, "qadhafi 330", "qadhafi 328")],
        "frus1969-76ve09p1 topics": [(5, "qadhafi 325", "qadhafi 323")],
    ]

    /// The ids of a fixture volume's TEI document divisions, the documents the family's generator counted.
    static func documentDivisions(_ volume: String) throws -> Set<String> {
        let xml = try String(contentsOf: RepositoryFiles.tei.appendingPathComponent("\(volume).xml"), encoding: .utf8)
        let tags = try NSRegularExpression(pattern: #"<div\b[^>]*>"#)
        var ids = Set<String>()
        for match in tags.matches(in: xml, range: NSRange(xml.startIndex..., in: xml)) {
            let tag = String(xml[Range(match.range, in: xml)!])
            guard tag.contains(#"type="document""#), let id = tag.range(of: #"xml:id="[^"]*""#, options: .regularExpression)
            else { continue }
            ids.insert(String(tag[id].dropFirst(8).dropLast()))
        }
        return ids
    }

    static func rows(_ volume: String, in pipeline: IndexingPipeline) async throws -> [WordCloudDocumentKey] {
        try await pipeline.documents(forVolume: volume).map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
    }

    /// The kit's count of `keys`, made apart from the server: the tokenizer the kit assembles over the lists a host
    /// decodes, the web's tagger, over the fixture index's own pipeline.
    static func kitsCount(_ keys: [WordCloudDocumentKey], lens: WordCloudLens, tuning: WordCloudTuning = .standard,
                          includeDiplomatic: Bool = true, hidden: Set<String> = [], pipeline: IndexingPipeline) async throws -> WordCloudResult {
        let host = try WordCloudParityTests.Host.open()
        let tagger = FRUSWordCloudTagger()
        let tokenizer = WordCloudTokenizer.configured(tuning: tuning, lens: lens, includeDiplomatic: includeDiplomatic, extraStopwords: hidden,
                                                      wordForm: tagger.health.wordForm, stopwords: host.stopwords, lexicons: host.lexicons)
        return try await WordCloudCount.count(keys: keys, pipeline: pipeline, tokenizer: tokenizer, tagger: tagger, countedUnder: tagger.health,
                                              indexVersion: IndexCompatibility.supportedIndexVersion, limit: 1_000,
                                              minimumCount: tuning.minimumCount)
    }

    static func lines(_ terms: [TermCount]) -> [String] { terms.map { "\($0.term) \($0.count)" } }

    @Test func aLiveCountOfEachFixtureVolumeIsTheFamilysList() async throws {
        let fixture = try await Self.shared.value
        let host = try WordCloudParityTests.Host.open()
        var compared = 0
        var residue = 0
        for volume in ParityFixtures.volumes {
            let rows = try await Self.rows(volume, in: fixture.served.pipeline)
            let divisions = try Self.documentDivisions(volume)
            let documents = rows.filter { divisions.contains($0.documentId) }
            #expect(documents.count == divisions.count, "\(volume): the index holds every document the family counted")
            #expect(rows.count > documents.count, "\(volume): the index holds front matter as documents too, which the family's scan leaves out")
            for lens in Self.familyLenses {
                let live = try await WordCloudLive.count(documents, lens: lens, settings: .standard, served: fixture.served,
                                                         resources: fixture.resources)
                let stored = try #require(host.volumes.scopes[volume]?.lists[lens.rawValue], "\(volume) \(lens)")
                let file = WordCloudParityTests.Host.list(host.volumes, volume, lens)
                #expect(file.count == 50, "\(volume) \(lens): the family keeps fifty words")
                var expected = file
                for known in Self.printedJoinResidue["\(volume) \(lens.rawValue)"] ?? [] {
                    #expect(expected[known.index] == known.file, "\(volume) \(lens): the family's entry \(known.index)")
                    expected[known.index] = known.live
                    residue += 1
                }
                #expect(Array(Self.lines(live.terms).prefix(file.count)) == expected, "\(volume) \(lens)")
                #expect(live.documentCount == divisions.count, "\(volume) \(lens): every document counted")
                // The tokens each lens counted: the family's total within the printed join's 0.05%.
                let drift = abs(Double(live.totalTokenCount - stored.total)) / Double(stored.total)
                #expect(drift < 0.0005, "\(volume) \(lens): \(live.totalTokenCount) tokens, the family's \(stored.total)")
                #expect(live.lens == lens && live.languageAnalysis == WordCloudLive.tagger.health)
                compared += file.count
            }
        }
        #expect(compared == 900 && residue == 6, "\(compared) entries compared, \(residue) of them the printed join's")
    }

    @Test func aVolumesLiveCloudIsTheKitsCountOfEveryRowItHolds() async throws {
        let fixture = try await Self.shared.value
        let hidden: Set<String> = ["president"]
        var settings = CloudSettings.standard
        settings.globalStopwords = Array(hidden)
        for volume in ParityFixtures.volumes {
            let rows = try await Self.rows(volume, in: fixture.served.pipeline)
            let resolution = try await WordCloudRoutes.resolve(.volume(volumeId: volume), reader: .init(settings: settings, user: nil),
                                                               services: nil, resources: fixture.resources)
            let keys = try await WordCloudLive.keys(resolution, served: fixture.served, services: nil)
            #expect(keys == rows, "\(volume): the resolver reads the volume's rows, as the app's `keys(forVolume:)`")
            for lens in [WordCloudLens.allTerms, .topics] {
                let live = try await WordCloudLive.count(keys, lens: lens, settings: settings, served: fixture.served, resources: fixture.resources)
                let kits = try await Self.kitsCount(rows, lens: lens, hidden: hidden, pipeline: fixture.pipeline)
                #expect(Self.lines(live.terms) == Self.lines(kits.terms) && live.documentCount == kits.documentCount
                        && live.totalTokenCount == kits.totalTokenCount, "\(volume) \(lens)")
                #expect(!live.terms.contains { $0.term == "president" } && live.terms.count == 1_000, "\(volume) \(lens)")
            }
        }
    }

    // MARK: Through the API

    /// A server serving the fixture index, its single user's research written through the API.
    static func send(_ client: any TestClientProtocol, _ method: HTTPRequest.Method, _ path: String, _ json: String) async throws -> TestResponse {
        let me = try ServedFixture.decode(Me.self, try await client.execute(uri: "/api/v1/me", method: .get))
        return try await client.execute(uri: path, method: method,
                                        headers: [.origin: "http://localhost:8080", CSRFTokens.header: me.csrfToken, .contentType: "application/json"],
                                        body: ByteBuffer(string: json))
    }

    /// A cloud through the API, asked again while the server's first loads outrun the test client's 20 s wait under
    /// CI's load (S27c's `EmbedCheckTests`).
    static func cloud(_ client: any TestClientProtocol, _ scope: String, _ lens: WordCloudLens) async throws -> CloudAnswer {
        let path = "/api/v1/cloud?scope=\(scope.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)&lens=\(lens.rawValue)"
        var failure: (any Error)?
        for _ in 0..<6 {
            do {
                let response = try await client.execute(uri: path, method: .get)
                guard response.status == .ok else { throw APIParityError("\(path): \(response.status.code) \(String(buffer: response.body))") }
                return try ServedFixture.decode(CloudAnswer.self, response)
            } catch let error as APIParityError {
                throw error
            } catch {
                failure = error
            }
        }
        throw failure ?? APIParityError("\(path) never answered")
    }

    @Test func aDocumentsACollectionsAndASavedSearchsCloudsAreTheKitsCount() async throws {
        let fixture = try await Self.shared.value
        let pipeline = fixture.pipeline
        let kitsSearch = try await FixtureIndex.value().index.service
        try await ServedFixture.run { client, _ in
            // A document: its own text, counted live, titled by its volume as the app's resolver titles it.
            let document = WordCloudDocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
            for lens in [WordCloudLens.allTerms, .actions] {
                let answer = try await Self.cloud(client, "doc:frus1961-63v06/d1", lens)
                let kits = try await Self.kitsCount([document], lens: lens, pipeline: pipeline)
                #expect(answer.source == "live" && answer.state == "terms" && answer.documentCount == 1, "\(lens)")
                #expect(answer.terms.map { "\($0.term) \($0.count)" } == Self.lines(kits.terms), "the document under \(lens)")
                #expect(answer.scope.title.hasPrefix("Foreign Relations of the United States, 1961–1963, Volume VI"))
                #expect(answer.countLine == CloudRules.countLine(terms: kits.terms.count, documents: 1) && answer.account?.contains("1 document") == true)
            }

            // A collection: its entries, each document once, and an entry of another volume.
            let keys = [("frus1961-63v06", "d3"), ("frus1969-76ve09p1", "d12"), ("frus1894Nicaragua", "d2"), ("frus1961-63v06", "d7")]
                .map { WordCloudDocumentKey(volumeId: $0.0, documentId: $0.1) }
            let made = try await Self.send(client, .post, "/api/v1/me/collections", #"{"name":"Live parity"}"#)
            #expect(made.status == .created)
            let collection = try ServedFixture.decode(CollectionDetail.self, made).id
            let documents = keys.map { #"{"volumeId":"\#($0.volumeId)","documentId":"\#($0.documentId)"}"# }.joined(separator: ",")
            #expect(try await Self.send(client, .post, "/api/v1/me/collections/\(collection)/documents", #"{"documents":[\#(documents)]}"#).status == .ok)
            for lens in [WordCloudLens.topics, .sentiment] {
                let answer = try await Self.cloud(client, "col:\(collection)", lens)
                let kits = try await Self.kitsCount(keys, lens: lens, pipeline: pipeline)
                #expect(answer.terms.map { "\($0.term) \($0.count)" } == Self.lines(kits.terms) && answer.documentCount == 4, "the collection under \(lens)")
                #expect(answer.scope.title == "Live parity" && answer.source == "live")
            }

            // A saved search: its results, run as the reader's search at the app's 1,000.
            let saved = try await Self.send(client, .post, "/api/v1/me/saved-searches", #"{"name":"Treaties","search":"keywords=treaty"}"#)
            #expect(saved.status == .created)
            let search = try ServedFixture.decode(SavedSearch.self, saved).id
            let results = try await kitsSearch.search(parameters: try SearchRequest(formEncoded: "keywords=treaty").parameters, limit: 1_000)
                .map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
            #expect(results.count > 10)
            let answer = try await Self.cloud(client, "search:\(search)", .allTerms)
            let kits = try await Self.kitsCount(results, lens: .allTerms, pipeline: pipeline)
            #expect(answer.terms.map { "\($0.term) \($0.count)" } == Self.lines(kits.terms) && answer.documentCount == results.count,
                    "the saved search's \(results.count) results")
            #expect(answer.scope.title == "Treaties")

            // The reader's settings are counted: words hidden from the lens, and a longer word, a count of their own.
            let patched = try await Self.send(client, .patch, "/api/v1/me/preferences", #"{"wordCloud":{"minLength":5}}"#)
            #expect(patched.status == .ok)
            #expect(try await Self.send(client, .post, "/api/v1/me/preferences/hidden-words", #"{"word":"soviet","lens":"allTerms"}"#).status == .ok)
            let tuned = try await Self.cloud(client, "col:\(collection)", .allTerms)
            var tuning = WordCloudTuning.standard
            tuning.minimumLength = 5
            let kitsTuned = try await Self.kitsCount(keys, lens: .allTerms, tuning: tuning, hidden: ["soviet"], pipeline: pipeline)
            #expect(tuned.terms.map { "\($0.term) \($0.count)" } == Self.lines(kitsTuned.terms), "the collection under the reader's settings")
            #expect(!tuned.terms.contains { $0.term == "soviet" || $0.term.count < 5 } && tuned.account?.contains("under your settings") == true)
        }
    }
}
