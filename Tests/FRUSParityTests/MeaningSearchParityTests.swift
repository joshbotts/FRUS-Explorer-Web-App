// Search by meaning through the API (PLAN's S27d), over the kit's fixture index imported as an export, the fixture
// volumes' shards where the image holds every volume's, and the encoder's stand-in (S27b), which answers as llama-server
// does. Every answer is the kit's `SemanticSearchBackend.run` (FRUS-Explorer#1982) over the same index, shards and query
// vectors, built here apart from the server, its encoder a second over the same stand-in, whose vector of a question is
// the server's own, which the admin's embedding route shows: the rows in order, each with its score to twelve places,
// its prose snippet and its chip; the hits beyond the library; every count of the disclosure; the strip's sentences; the
// trail's signature and the rendered expression. Over the series, inside a working corpus, under filters the kit
// intersects after its ranking, in the date's orders and a page at a time. Over an index of two of the three volumes, the
// third's hits, its shard held, are listed apart, titled from the catalogue, under the volume scope alone. The questions
// are chosen by the kit's own runs, among stand-in questions whose vectors reach the fixture volumes, since a stand-in's
// vector has no meaning to aim with. And the words: the kit's sentences in a server's, each replacement held to a sentence
// the kit says; a capture's account of a search by meaning's list, the app's, mirrored; and the browser app's words.

import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import SemanticVectorsKit
import Testing

@testable import FRUSCoreKit
@testable import FRUSLightAPI

@Suite struct MeaningSearchParityTests {
    /// What the kit's Meaning engine is given here, apart from the server: the fixture index's search service, the
    /// bundled tier, the fixture volumes' shards each opened by the kit, the catalogue and the volumes indexed.
    struct Host: @unchecked Sendable {
        let search: SearchService
        let tiers: SemanticBundledTiers
        let shards: FixtureShards
        let manifest: [String: VolumeManifestEntry]
        let indexed: Set<String>

        static func open(_ built: FixtureIndex.Built, volumes: [String]) throws -> Host {
            let resources = ServedFixture.resources
            let tiers = try SemanticBundledTiers(indexAt: resources.appendingPathComponent("semantic-vectors-index.json"),
                                                 binaryAt: resources.appendingPathComponent("semantic-vectors-binary.bin"))
            let catalogue = try FixedVolumeCatalogue(contentsOf: resources.appendingPathComponent("manifest.json")).citableEntries
            return Host(search: built.index.service, tiers: tiers, shards: FixtureShards(index: tiers.index),
                        manifest: Dictionary(catalogue.map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first }),
                        indexed: Set(volumes))
        }

        /// The kit's run of `question` under `parameters`, its question embedded by `encoder`.
        @MainActor
        func run(_ question: String, _ parameters: SearchParameters, encoder: QueryEncoder) async throws -> SemanticSearchBackend.Outcome {
            let searcher = SemanticQuerySearcher(
                index: tiers.index, corpus: tiers.corpus, shards: shards,
                encoder: SemanticEmbedFunction { try await encoder.embed($0).vector }, requestShardFetch: { _ in false })
            let manifest = manifest
            let indexed = indexed
            let backend = SemanticSearchBackend(searcher: searcher, searchService: search,
                                                manifestEntry: { manifest[$0] }, indexedVolumeIds: { indexed })
            return try await backend.run(query: question, parameters: parameters)
        }
    }

    static let locale = Locale(identifier: "en_US")
    static func score(_ value: Double) -> String { String(format: "%.12f", value) }

    /// A row as the comparison reads it: its key, its score to twelve places, its negation, which orders the date's ties,
    /// its chip and its snippet.
    static func row(_ result: SearchResult) -> String {
        "\(result.volumeId)/\(result.documentId) \(score(result.semanticScore ?? -9)) \(score(result.bm25Score)) "
            + "\(result.semanticScore.map(SemanticScoreCopy.chipLabel(for:)) ?? "-") \(result.snippet)"
    }

    static func row(_ item: SearchItem) -> String {
        "\(item.volumeId)/\(item.documentId) \(score(item.semanticScore ?? -9)) \(score(item.bm25Score)) \(item.chip ?? "-") \(item.snippet)"
    }

    static func beyond(_ hits: [SemanticSearchBackend.BeyondLibraryHit]) -> [String] {
        hits.map { "\($0.volumeID)/\($0.documentID) \(score($0.score)) \($0.volumeTitle) \(SemanticScoreCopy.chipLabel(for: $0.score))" }
    }

    static func beyond(_ hits: [MeaningBeyondHit]) -> [String] {
        hits.map { "\($0.volumeId)/\($0.documentId) \(score($0.score)) \($0.volumeTitle) \($0.chip)" }
    }

    /// A query string of `fields`, each value percent-encoded as a form's.
    static func query(_ fields: [(String, String)]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.1)" }.joined(separator: "&")
    }

    /// Stand-in questions, in order, and the kit's run of each over the series, until `enough` say yes to `wanted`.
    @MainActor
    static func questions(host: Host, encoder: QueryEncoder, enough: Int, scan: Int = 160,
                          wanted: (SemanticSearchBackend.Outcome) -> Bool) async throws -> [String] {
        var chosen: [String] = []
        for index in 0..<scan where chosen.count < enough {
            let question = "Question \(index) on the policy of the United States"
            if wanted(try await host.run(question, SearchParameters(keywords: question), encoder: encoder)) { chosen.append(question) }
        }
        return chosen
    }

    /// Each request of a variant and what the kit is asked for it: the question, the fields beside it, the parameters the
    /// server runs with, and the page and order the answer is cut in.
    struct Asked: Sendable {
        let question: String
        let fields: [(String, String)]
        let parameters: SearchParameters
        let sort: SearchSortOrder
        let offset: Int
        let limit: Int

        var path: String {
            "/api/v1/search/meaning?" + MeaningSearchParityTests.query([("keywords", question)] + fields)
        }
    }

    /// `asked`'s answer through the API is the kit's run for the same parameters, cut and ordered as the kit orders kept
    /// results; and what it says beside its rows is the kit's.
    @MainActor
    static func expectTheKits(_ answer: MeaningSearchResult, _ asked: Asked, host: Host, encoder: QueryEncoder) async throws
        -> SemanticSearchBackend.Outcome {
        let kit = try await host.run(asked.question, asked.parameters, encoder: encoder)
        let ordered = asked.sort.sorted(kit.results)
        let page = Array(ordered.dropFirst(asked.offset).prefix(asked.limit))
        #expect(answer.items.map(Self.row) == page.map(Self.row), "\(asked.path)")
        #expect(answer.total == kit.results.count && answer.countBasis == "exact" && answer.hidden == nil)
        #expect(answer.sort == asked.sort.rawValue && answer.offset == asked.offset && answer.limit == asked.limit)
        #expect(answer.retainedLimit == 100)
        #expect(answer.meaning.disclosure == MeaningDisclosure(kit.disclosure), "\(asked.path)")
        #expect(Self.beyond(answer.meaning.beyondLibrary) == Self.beyond(kit.beyondLibrary), "\(asked.path)")
        #expect(answer.meaning.strip == MeaningSearchWords.strip(kit.disclosure, beyondCount: kit.beyondLibrary.count))
        #expect(answer.meaning.emptyStatement == MeaningSearchWords.emptyStatement(kit.disclosure))
        #expect(answer.meaning.beyondHeader == (kit.beyondLibrary.isEmpty ? nil : MeaningSearchWords.beyondHeader(kit.beyondLibrary.count)))
        #expect(answer.meaning.signature == SearchScopeSignature.semanticSignature(for: asked.parameters))
        #expect(answer.meaning.renderedExpression == "route=semantic; model=embeddinggemma-2-Q8_0; top=100")
        #expect(answer.meaning.question == asked.question)
        return kit
    }

    /// The parameters the server runs `fields` with, inside the corpus whose indexed documents are `corpus`.
    static func parameters(_ question: String, _ fields: [(String, String)], corpus: [String]? = nil) throws -> SearchParameters {
        let parameters = try SearchRequest(formEncoded: query([("keywords", question)] + fields)).parameters
        return corpus.map { parameters.runningInside(workingCorpus: $0) } ?? parameters
    }

    /// Every answer of a search by meaning through the API, over the series and inside a working corpus, under filters,
    /// in another order and a page at a time, is the kit's over the same index, shards and query vectors.
    @Test func everyAnswerIsTheKitsBackends() async throws {
        let directory = try TemporaryDirectory()
        let settings = try StandInEncoder.settings(in: directory.url.appendingPathComponent("model"))
        let encoder = QueryEncoder(settings: settings)
        let built = try await FixtureIndex.value()
        let host = try Host.open(built, volumes: ParityFixtures.volumes)
        do {
            let reaching = try await Self.questions(host: host, encoder: encoder, enough: 6) { !$0.results.isEmpty }
            #expect(reaching.count == 6, "stand-in questions whose nearest candidates hold fixture documents: \(reaching)")
            let missing = try await Self.questions(host: host, encoder: encoder, enough: 1) { $0.results.isEmpty }
            let questions = reaching + missing
            let (answers, corpus, vector) = try await ServedFixture.run(index: built.copy, volumes: ParityFixtures.volumes,
                                                                         encoder: settings) { client, _ in
                let session = try await CollectionExportParityTests.Session.open(client)
                // A working corpus of the documents a keyword search finds, each a member a search inside it ranks.
                let saved = try await session.json(WorkingCorpus.self, .post, "/api/v1/me/working-corpora",
                                                   ["name": "The Treaty", "search": "keywords=president"])
                let detail = try ServedFixture.decode(WorkingCorpusDetail.self, try await session.get("/api/v1/me/working-corpora/\(saved.id)"))
                let corpus = detail.sections.flatMap { section in section.documents.map { "\($0.volumeId)/\($0.documentId)" } }
                // The server's own vector of a question, which the test's encoder gives too.
                let embedded = try ServedFixture.decode(EmbeddingAnswer.self, try await session.get(
                    "/api/v1/admin/semantic/embedding?" + Self.query([("query", questions[0])])))
                var answers: [(String, String, MeaningSearchResult)] = []
                for question in questions {
                    for (name, fields) in Self.variants(corpus: saved.id) {
                        let path = "/api/v1/search/meaning?" + Self.query([("keywords", question)] + fields)
                        answers.append((question, name, try ServedFixture.decode(MeaningSearchResult.self, try await session.get(path))))
                    }
                }
                return (answers, corpus, embedded.vector)
            }
            #expect(try await encoder.embed(questions[0]).vector == vector, "the server's vector of the question is the test's")
            let indexedKeys = WorkingCorpusResolver(indexedVolumeIds: host.indexed).resolve(documentKeys: corpus).indexedKeys
            #expect(indexedKeys.count > 100, "a set larger than the hundred a search lists: \(indexedKeys.count)")

            var rows = 0
            var filtered = 0
            var unscored = 0
            var withoutVector = 0
            for (question, name, answer) in answers {
                let fields = try #require(Self.variants(corpus: "").first { $0.name == name }).fields
                let inside = fields.contains { $0.0 == "workingCorpusId" }
                let kept = fields.filter { $0.0 != "workingCorpusId" }
                let asked = Asked(
                    question: question, fields: fields,
                    parameters: try Self.parameters(question, kept, corpus: inside ? indexedKeys : nil),
                    sort: fields.first { $0.0 == "sort" }.flatMap { SearchSortOrder(rawValue: $0.1) } ?? .relevance,
                    offset: fields.first { $0.0 == "offset" }.flatMap { Int($0.1) } ?? 0,
                    limit: fields.first { $0.0 == "limit" }.flatMap { Int($0.1) } ?? 20)
                let kit = try await Self.expectTheKits(answer, asked, host: host, encoder: encoder)
                rows += answer.items.count
                filtered += kit.disclosure.filteredOut
                unscored += kit.disclosure.unscoredCandidates
                withoutVector += kit.disclosure.withoutVector
                if inside {
                    #expect(kit.disclosure.rankedWithin == indexedKeys.count, "a search inside the corpus ranks every member the index holds")
                    #expect(answer.items.allSatisfy { indexedKeys.contains("\($0.volumeId)/\($0.documentId)") })
                }
            }
            #expect(rows > 500, "the answers hold rows to compare: \(rows)")
            #expect(filtered > 0, "the filters removed ranked rows, and the answer counts them: \(filtered)")
            #expect(unscored > 0, "candidates whose shard the server lacks are dropped and counted: \(unscored)")
            #expect(withoutVector > 0, "a set's members with no vector are counted: \(withoutVector)")
        } catch {
            await encoder.shutdown()
            throw error
        }
        await encoder.shutdown()
    }

    /// The fields of each request a question is asked with, by name: over the series and inside the corpus, each under a
    /// date range and in the date's order a page at a time, and over the series in one served volume and one the server
    /// does not serve.
    static func variants(corpus: String) -> [(name: String, fields: [(String, String)])] {
        [
            ("series", [("limit", "100")]),
            ("series in a volume", [("volumeIds", "frus1961-63v06"), ("limit", "100")]),
            ("inside", [("workingCorpusId", corpus), ("limit", "100")]),
            ("inside 1962", [("workingCorpusId", corpus), ("dateRangeEarliest", "1962-01-01"), ("dateRangeLatest", "1962-12-31"),
                             ("limit", "100")]),
            ("inside by date", [("workingCorpusId", corpus), ("sort", "dateAscending"), ("offset", "10"), ("limit", "10")]),
            ("inside documents only", [("workingCorpusId", corpus), ("documentType", "documentsOnly"), ("sort", "dateDescending"),
                                       ("limit", "50")]),
        ]
    }

    /// Over an index of two of the three volumes, a hit in the third, Nicaragua's, whose shard is held, is listed apart, in
    /// rank order, titled from the catalogue; a volume scope that leaves it out removes it, and one that names it keeps it
    /// when no row of the index passes; a date range leaves it, and the strip says it was checked by the volume scope
    /// alone. Each answer is the kit's.
    @Test func aHitTheServerDoesNotServeIsListedApart() async throws {
        let directory = try TemporaryDirectory()
        let settings = try StandInEncoder.settings(in: directory.url.appendingPathComponent("model"))
        let encoder = QueryEncoder(settings: settings)
        let built = try await TwoVolumeIndex.value()
        let host = try Host.open(built, volumes: TwoVolumeIndex.volumes)
        do {
            let questions = try await Self.questions(host: host, encoder: encoder, enough: 3) { outcome in
                outcome.beyondLibrary.contains { $0.volumeID == TwoVolumeIndex.offIndex }
            }
            #expect(questions.count == 3, "stand-in questions whose nearest candidates hold Nicaragua's documents: \(questions)")
            let scopes: [[(String, String)]] = [
                [("limit", "100")],
                [("volumeIds", "frus1961-63v06"), ("limit", "100")],
                [("volumeIds", TwoVolumeIndex.offIndex), ("limit", "100")],
                [("dateRangeEarliest", "1800-01-01"), ("dateRangeLatest", "1999-12-31"), ("limit", "100")],
            ]
            let answers = try await ServedFixture.run(index: built.copy, volumes: TwoVolumeIndex.volumes, encoder: settings) { client, _ in
                var answers: [(String, Int, MeaningSearchResult)] = []
                for question in questions {
                    for (index, fields) in scopes.enumerated() {
                        let path = "/api/v1/search/meaning?" + Self.query([("keywords", question)] + fields)
                        let response = try await client.execute(uri: path, method: .get)
                        guard response.status == .ok else { throw APIParityError("GET \(path): \(response.status.code) \(String(buffer: response.body))") }
                        answers.append((question, index, try ServedFixture.decode(MeaningSearchResult.self, response)))
                    }
                }
                return answers
            }
            var listed = 0
            var unchecked = 0
            for (question, index, answer) in answers {
                let asked = Asked(question: question, fields: scopes[index], parameters: try Self.parameters(question, scopes[index]),
                                  sort: .relevance, offset: 0, limit: 100)
                let kit = try await Self.expectTheKits(answer, asked, host: host, encoder: encoder)
                let beyond = answer.meaning.beyondLibrary
                #expect(beyond.allSatisfy { $0.volumeId == TwoVolumeIndex.offIndex }, "only the volume the server does not serve")
                #expect(beyond.allSatisfy { $0.volumeTitle == host.manifest[TwoVolumeIndex.offIndex]?.title }, "titled from the catalogue")
                switch index {
                case 0, 2:
                    #expect(!beyond.isEmpty, "the series, and a scope that names its volume, keep it")
                    listed += beyond.count
                case 1:
                    #expect(beyond.isEmpty, "a scope that leaves its volume out removes it")
                default:
                    #expect(!beyond.isEmpty && kit.disclosure.beyondUncheckedByFilters)
                    #expect(answer.meaning.strip.contains(
                        "Matches in volumes this server does not serve are checked against your volume scope only, not your other filters."))
                    unchecked += 1
                }
                if index == 2 { #expect(answer.items.isEmpty, "no row of the index is in the volume it names") }
                #expect(answer.meaning.beyondHeader == "In volumes this server does not serve (\(beyond.count))" || beyond.isEmpty)
            }
            #expect(listed > 0 && unchecked == questions.count)
        } catch {
            await encoder.shutdown()
            throw error
        }
        await encoder.shutdown()
    }

    /// The Meaning mode's sentences are the kit's, of a server where the kit's speak of a device: each replacement's phrase
    /// is one the kit says, so a pin move that rewords it fails here, and no sentence the server gives offers a download.
    @Test func theStripsWordsAreTheKitsInAServersWords() throws {
        let locale = Self.locale
        let kit = [
            SemanticUnscoredCopy.unscored(candidates: 12, volumes: 3, downloading: 0, locale: locale),
            SemanticUnscoredCopy.warming(volumes: 3, downloading: 0, locale: locale),
            SemanticUnscoredCopy.unranked(members: 5, volumes: 2, downloading: 0, locale: locale),
            SemanticUnscoredCopy.notIndexedHere(3, locale: locale),
            SemanticUnscoredCopy.emptyInsideSet(setSize: 0, ranked: 0, filteredOut: 0, volumes: 0, downloading: 0, locale: locale),
            SemanticUnscoredCopy.emptyInsideSet(setSize: 5, ranked: 2, filteredOut: 0, volumes: 0, downloading: 0, locale: locale),
            SemanticUnscoredCopy.emptyInsideSet(setSize: 5, ranked: 0, filteredOut: 0, volumes: 0, downloading: 0, locale: locale),
            SemanticUnscoredCopy.emptyInsideSet(setSize: 5, ranked: 0, filteredOut: 0, volumes: 2, downloading: 0, locale: locale),
            SemanticModeStripCopy.opening(setSize: 0, locale: locale),
            SemanticModeStripCopy.beyondHeader(count: 2),
            // A held list's row (PLAN's S27e): its Meaning list's hits beyond the library, which no layer searches.
            try #require(SearchWithinParityTests.leftOut(notDownloaded: 1)),
            try #require(SearchWithinParityTests.leftOut(notDownloaded: 2)),
        ] + SemanticModeStripCopy.parts(
            disclosure: SemanticSearchBackend.Disclosure(unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0, filtersApplied: true,
                                                         filteredOut: 2, beyondUncheckedByFilters: true),
            beyondCount: 1, locale: locale)
        for (device, server) in MeaningSearchWords.replacements {
            #expect(kit.contains { $0.contains(device) }, "the kit says \"\(device)\", which the server says as \"\(server)\"")
        }
        for sentence in kit.map(MeaningSearchWords.server) {
            for word in ["device", "Settings", "Download", "downloaded", "the app"] {
                #expect(!sentence.contains(word), "\(sentence)")
            }
        }
        #expect(kit.map(MeaningSearchWords.server).prefix(5) == [
            "12 possible matches in 3 volumes could not be scored. This server does not hold their match files.",
            "Match files for 3 volumes are required. This server does not hold them.",
            "5 documents in 2 volumes could not be ranked: their match files are not on this server.",
            "3 close matches are not listed: this server's index does not hold those documents.",
            "The set you are searching within holds no documents on this server, so there is nothing to rank.",
        ])
        #expect(MeaningSearchWords.beyondHeader(2) == "In volumes this server does not serve (2)")
        // The opening is the kit's as it stands: it names no device.
        #expect(MeaningSearchWords.strip(SemanticSearchBackend.Disclosure(
            unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0, filtersApplied: false, filteredOut: 0,
            beyondUncheckedByFilters: false), beyondCount: 0) == [SemanticModeStripCopy.opening(setSize: nil)])
        #expect(SemanticScoreCopy.chipLabel(for: 0.6449) == "Semantic match · 64%")
    }

    /// The browser app's words for search by meaning: the app's picker, its field's prompt, its tip, its header's count,
    /// its empty state's title and a hit in a volume not on the device, which the web says of a volume the server does
    /// not serve, with no download to offer.
    @Test func theBrowserAppsWordsAreTheApps() throws {
        let sources = NoteViewParityTests.Sources()
        let models = try sources.app("Search/SearchModels.swift")
        let sheet = try sources.app("App/SearchSheet.swift")
        let scope = try sources.app("Search/ResultSetScope.swift")
        let views = try sources.app("Search/SemanticMeaningModeViews.swift")
        let shared = try sources.app("Search/SemanticSearchSharedViews.swift")
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let block = try NoteViewParityTests.block("meaningSearch", of: copy)
        #expect(NoteViewParityTests.writes(sheet, "search.mode.title", "Search by") && block.contains("searchBy: 'Search by'"))
        #expect(NoteViewParityTests.writes(models, "search.mode.keywords", "Keywords"))
        #expect(NoteViewParityTests.writes(models, "search.mode.meaning", "Meaning"))
        #expect(block.contains("modes: { keywords: 'Keywords', meaning: 'Meaning' }"))
        #expect(NoteViewParityTests.writes(models, "search.meaning.placeholder", "A question in your own words…"))
        #expect(block.contains("placeholder: 'A question in your own words…'"))
        let tip = "These tips are for Keywords search. A Meaning search reads your words as a whole, so quotation marks, AND, OR, NOT, a minus sign, parentheses, *, NEAR and = have no special effect."
        #expect(NoteViewParityTests.writes(models, "search.tips.note.meaningMode", tip) && block.contains("tip: '\(tip)'"))
        #expect(NoteViewParityTests.writes(scope, "search.count.closest.one", "1 closest match"))
        #expect(NoteViewParityTests.writes(scope, "search.count.closest %@", "%@ closest matches"))
        #expect(block.contains("closest: (count: number) => (count === 1 ? '1 closest match' : `${count.toLocaleString('en-US')} closest matches`)"))
        #expect(NoteViewParityTests.writes(scope, "search.count.none", "No results") && block.contains("noResults: 'No results'"))
        #expect(NoteViewParityTests.writes(views, "search.semantic.empty.title", "No semantic matches yet"))
        #expect(block.contains("emptyTitle: 'No semantic matches yet'"))
        #expect(shared.contains(#"localized: "search.semantic.row.undownloaded %@ %@", defaultValue: "Document %1$@ in %2$@")"#))
        #expect(block.contains("beyondDocument: (documentId: string, volumeTitle: string) => `Document ${documentId} in ${volumeTitle}`"))
        #expect(NoteViewParityTests.writes(shared, "search.semantic.row.notDownloaded",
                                           "Volume not downloaded — its documents are shown without titles until you download it."))
        #expect(block.contains("beyondNotServed: 'Volume not on this server — its documents are shown without titles.'"))
        // No download to offer: the model and the vectors are in the image.
        for (key, label) in [("search.semantic.row.download", "Download Volume"), ("search.semantic.offer.button", "Download Search Model")] {
            #expect(NoteViewParityTests.writes(shared, key, label), "the app offers \(label)")
            #expect(!block.contains(label), "the web offers no \(label)")
        }
    }

    /// What a capture says of a search by meaning's list, as `ResultSetScope` says it for the Meaning route and the
    /// server's `CorpusCapture` mirrors it: its provenance, the kit's sentence, by which a corpus is read back as a Meaning
    /// search's; its warning, which is never none; and a capture that is never the whole answer, with no total.
    @Test func aMeaningCapturesAccountIsTheMirror() throws {
        NoteViewParityTests.expect(try SearchSetParityTests.app("Search/ResultSetScope.swift"), holds: [
            #"description = loaded == 1 ? String(localized: "corpus.save.source.meaning.one", defaultValue: "Meaning search — the closest match") : String(format: Self.meaningProvenance, grouped(loaded))"#,
            #"? String(localized: "corpus.save.meaning.one", defaultValue: "This document is the closest match a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.")"#,
            #": String(localized: "corpus.save.meaning", defaultValue: "These documents are the closest matches a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.")"#,
            "var isCapturePartial: Bool { isMeaningSearch || isPartialEvidence }",
            "case .meaning, .wordsInMatches: return false",
            "WorkingCorpusProvenance.meaningSearch",
        ], file: "ResultSetScope.swift")
        NoteViewParityTests.expect(try SearchSetParityTests.server("Sources/FRUSLightAPI/WorkingCorpora.swift"), holds: [
            #"description = loaded == 1 ? "Meaning search — the closest match" : String(format: WorkingCorpusProvenance.meaningSearch, Self.grouped(loaded))"#,
            #"? "This document is the closest match a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.""#,
            #": "These documents are the closest matches a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.""#,
            // A layer's rows say what they record by the app's layered routes (PLAN's S27e), `SearchWithinParityTests`'.
            "var isCapturePartial: Bool { layer?.isCapturePartial ?? (isMeaning || didHitFetchLimit || insideTruncatedCorpus) }",
            "var totalMatchCount: Int? { layer.map(\\.totalMatchCount) ?? (isMeaning ? nil : total) }",
        ], file: "WorkingCorpora.swift")
        // The kit reads the sentence back as a Meaning search's, and says its line so.
        let capture = CorpusCapture(meaning: [], reviewed: [], sourceQuery: "q", narrowing: [])
        #expect(WorkingCorpusProvenance.isMeaningCapture(capture.provenance))
        #expect(!capture.didHitFetchLimit && capture.isCapturePartial && capture.totalMatchCount == nil)
    }
}
