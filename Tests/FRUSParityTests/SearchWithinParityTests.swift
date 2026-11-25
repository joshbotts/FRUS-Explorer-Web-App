// Search Within These Results and the fallback through the API (PLAN's S27e), over the kit's fixture index imported as an
// export, the fixture volumes' shards and the encoder's stand-in (S27b), as `MeaningSearchParityTests` reads search by
// meaning. Each layered list through the API is the kit's for the same held list and query, built here apart from the
// server: the kit's `PinnedResultBase` held from the same search's rows, as the app's view models hold one, its members
// those Checklist Mode was not hiding; then words found in a Meaning list, the kit's `LayeredResultComposer.wordsInMatches`
// over the keyword search gated to them; a keyword list ranked by a question, the kit's `rerank`; and, the server's
// ceiling lowered to cut the fixtures, a list's whole match ranked, the kit's `rankWholeMatch`, under filters chosen since.
// The rows in order, each with its score to twelve places, its snippet and its chip; the route's counts, the disclosure,
// the trail's signature and expression, the line over the rows a ranking could not rank, and the held list's sentences.
// The fallback is the kit's searcher's nearest across the series, each resolved as the app's view resolves it, with the
// kit's caption. And the words: the sentences the server mirrors from the app's search screen and `ResultSetScope`, and
// the browser app's, each held to the app's source.

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

@Suite struct SearchWithinParityTests {
    typealias Host = MeaningSearchParityTests.Host

    static let model = "embeddinggemma-2-Q8_0"

    static func query(_ fields: [(String, String)]) -> String { MeaningSearchParityTests.query(fields) }

    /// The kit's Meaning engine over `host`, its questions embedded by `encoder`.
    @MainActor
    static func backend(_ host: Host, encoder: QueryEncoder) -> SemanticSearchBackend {
        let searcher = SemanticQuerySearcher(index: host.tiers.index, corpus: host.tiers.corpus, shards: host.shards,
                                             encoder: SemanticEmbedFunction { try await encoder.embed($0).vector },
                                             requestShardFetch: { _ in false })
        let manifest = host.manifest
        let indexed = host.indexed
        return SemanticSearchBackend(searcher: searcher, searchService: host.search, manifestEntry: { manifest[$0] },
                                     indexedVolumeIds: { indexed })
    }

    /// The kit's held list of `rows`, as the app's view model holds the list on screen (`SearchViewModel.holdBase`): its
    /// members the rows `hidden` leaves, in the search's order, its kind by the kit's rule, nothing set aside.
    static func held(route: ExecutedSearchRoute, query: String, rows: [SearchResult], hidden: Set<String>, fetchLimit: Int,
                     total: Int?, expression: String?, outcome: SemanticSearchBackend.Outcome?,
                     parameters: SearchParameters) -> PinnedResultBase {
        let members = PinnedResultBase.members(of: rows, shown: rows.filter { !hidden.contains($0.id) })
        let scope: UserTagCountScope = route == .meaning
            ? .resultKeys(rows.map { .init(volumeId: $0.volumeId, documentId: $0.documentId) }) : .match(parameters)
        let (kind, described) = PinnedResultBase.kind(route: route, query: query, ran: scope.ranParameters, browseName: nil)
        return PinnedResultBase(
            direction: SearchLayerDirection.starting(over: route)!, kind: kind, query: query, rows: rows, members: members,
            hiddenByChecklist: rows.count - members.count, notDownloaded: outcome?.beyondLibrary.count ?? 0, route: route,
            fetchLimit: fetchLimit, totalMatchCount: total, renderedExpression: expression, disclosure: outcome?.disclosure,
            beyondLibraryHits: outcome?.beyondLibrary ?? [], userTagCountScope: scope, setAside: nil,
            filterSignature: SearchScopeSignature.signature(for: parameters), describedQuery: described)
    }

    /// The second line of the row of a Meaning list with `notDownloaded` hits beyond the library, as the kit says it.
    static func leftOut(notDownloaded: Int) -> String? {
        PinnedResultBase(direction: .wordsInMatches, kind: .meaning, query: "q", rows: [], members: [], hiddenByChecklist: 0,
                         notDownloaded: notDownloaded, route: .meaning, fetchLimit: 100, totalMatchCount: nil, renderedExpression: nil,
                         disclosure: nil, beyondLibraryHits: [], userTagCountScope: nil, setAside: nil, filterSignature: "")
            .leftOutDescription
    }

    /// What the held list's row says, as the server sends it, of the kit's held list.
    static func expectTheRow(_ summary: HeldListSummary, _ base: PinnedResultBase, _ context: String) {
        #expect(summary.setDescription == base.setDescription, "\(context)")
        #expect(summary.rowDescription == base.rowDescription && summary.accessibilityLabel == base.accessibilityLabel, "\(context)")
        #expect(summary.leftOutDescription == base.leftOutDescription.map(MeaningSearchWords.server), "\(context)")
        #expect(summary.backTitle == base.backTitle && summary.captureLabel == base.captureLabel, "\(context)")
        #expect(summary.signaturePart == base.signaturePart && summary.members == base.members.count, "\(context)")
        #expect(summary.rows == base.rows.count && summary.hiddenByChecklist == base.hiddenByChecklist, "\(context)")
        #expect(summary.wasCut == base.wasCut && summary.ranksWholeMatch == base.ranksWholeMatch, "\(context)")
        #expect(summary.startTitle == base.direction.startTitle && summary.fieldPrompt == base.direction.fieldPrompt, "\(context)")
        #expect(summary.memberDigest == SearchWithinRoutes.memberDigest(base), "\(context)")
    }

    /// Every page of the layer `fields` asks for through the API, `limit` 100 a page, and the rows they hold.
    static func layer(_ client: any TestClientProtocol, _ fields: [(String, String)]) async throws
        -> (first: LayeredSearchResult, items: [SearchItem]) {
        var items: [SearchItem] = []
        var first: LayeredSearchResult?
        var offset = 0
        repeat {
            let path = "/api/v1/search/within?" + query(fields + [("limit", "100"), ("offset", String(offset))])
            let response = try await client.execute(uri: path, method: .get)
            guard response.status == .ok else { throw APIParityError("GET \(path): \(response.status.code) \(String(buffer: response.body))") }
            let page = try ServedFixture.decode(LayeredSearchResult.self, response)
            first = first ?? page
            items += page.items
            offset += 100
        } while offset < (first?.total ?? 0)
        return (try #require(first), items)
    }

    static func held(_ client: any TestClientProtocol, _ within: String) async throws -> HeldListSummary {
        let path = "/api/v1/search/held?" + query([("within", within)])
        let response = try await client.execute(uri: path, method: .get)
        guard response.status == .ok else { throw APIParityError("GET \(path): \(response.status.code) \(String(buffer: response.body))") }
        return try ServedFixture.decode(HeldListSummary.self, response)
    }

    /// The `count` stand-in questions, of the first `scan`, whose runs over the series list the most rows of the fixture
    /// index, most first: a stand-in's vector has no meaning to aim with, so the kit's own runs choose them.
    @MainActor
    static func richest(host: Host, encoder: QueryEncoder, count: Int, scan: Int = 400) async throws -> [String] {
        var listed: [(question: String, rows: Int)] = []
        for index in 0..<scan {
            let question = "Question \(index) on the policy of the United States"
            let rows = try await host.run(question, SearchParameters(keywords: question), encoder: encoder).results.count
            if rows > 0 { listed.append((question, rows)) }
        }
        return listed.sorted { $0.rows > $1.rows }.prefix(count).map(\.question)
    }

    /// One layer asked for, and the kit's run of it.
    struct Asked: @unchecked Sendable {
        let name: String
        let fields: [(String, String)]
    }

    /// Each layered list through the API, words found in a Meaning list and a keyword list ranked by a question, at the
    /// Mac's ceiling, is the kit's composer's for the same held list and query; and the held list's row is the kit's.
    @Test func everyLayerIsTheKitsComposers() async throws {
        let directory = try TemporaryDirectory()
        let settings = try StandInEncoder.settings(in: directory.url.appendingPathComponent("model"))
        let encoder = QueryEncoder(settings: settings)
        let built = try await FixtureIndex.value()
        let host = try Host.open(built, volumes: ParityFixtures.volumes)
        do {
            // The stand-in questions whose closest hundred hold the most fixture documents: the first a Meaning list to find
            // words in, and both questions to rank a keyword list by.
            let questions = try await Self.richest(host: host, encoder: encoder, count: 2)
            #expect(questions.count == 2, "stand-in questions whose closest matches hold fixture documents: \(questions)")
            let question = questions[0]
            let meaningList = Self.query([("keywords", question), ("by", "meaning")])
            // A keyword list with three rows hidden by the checklist when it was held.
            let president = try SearchRequest(formEncoded: "keywords=president").parameters
            let keywordRows = try await host.search.search(parameters: president, limit: SearchRequest.retainedLimit, offset: 0)
            let hidden = Set(keywordRows.prefix(3).map(\.id))
            let keywordList = Self.query([("keywords", "president")] + hidden.sorted().map { ("reviewed", $0) })
            let finding: [Asked] = ["the", "president", "Soviet", "zzzzunfindable"].map {
                Asked(name: "words \($0)", fields: [("keywords", $0), ("within", meaningList)])
            } + [Asked(name: "words the in 1962", fields: [("keywords", "the"), ("within", meaningList),
                                                                 ("dateRangeEarliest", "1962-01-01"), ("dateRangeLatest", "1962-12-31")])]
            let rankings: [Asked] = questions.map { Asked(name: "rank \($0)", fields: [("keywords", $0), ("within", keywordList)]) }
                + [Asked(name: "rank by date", fields: [("keywords", questions[1]), ("within", keywordList), ("sort", "dateAscending")]),
                   Asked(name: "rank documents only", fields: [("keywords", questions[0]), ("within", keywordList),
                                                              ("documentType", "documentsOnly")])]
            let (answers, rows) = try await ServedFixture.run(index: built.copy, volumes: ParityFixtures.volumes, encoder: settings) { client, _ in
                var answers: [(String, LayeredSearchResult, [SearchItem])] = []
                for asked in finding + rankings {
                    let (first, items) = try await Self.layer(client, asked.fields)
                    answers.append((asked.name, first, items))
                }
                return (answers, [try await Self.held(client, meaningList), try await Self.held(client, keywordList)])
            }

            // The kit's two held lists.
            let meaningParameters = try MeaningSearchParityTests.parameters(question, [])
            let outcome = try await host.run(question, meaningParameters, encoder: encoder)
            let meaningBase = Self.held(route: .meaning, query: question, rows: outcome.results, hidden: [], fetchLimit: 100, total: nil,
                                        expression: "route=semantic; model=\(Self.model); top=100", outcome: outcome,
                                        parameters: meaningParameters)
            let keywordBase = Self.held(route: .keywords, query: "president", rows: keywordRows, hidden: hidden,
                                        fetchLimit: SearchRequest.retainedLimit,
                                        total: try await host.search.searchCount(parameters: president),
                                        expression: try? await host.search.matchExpressions(for: president).corpus, outcome: nil,
                                        parameters: president)
            Self.expectTheRow(rows[0], meaningBase, "the Meaning list")
            Self.expectTheRow(rows[1], keywordBase, "the keyword list")
            #expect(rows[0].kind == "meaning" && rows[0].direction == "wordsInMatches" && rows[1].kind == "keywords")
            #expect(rows[1].leftOutDescription == "3 results hidden as reviewed are not included.")

            var narrowed = 0
            var found = 0
            var words = 0
            var unranked = 0
            for (name, answer, items) in answers {
                let asked = try #require((finding + rankings).first { $0.name == name })
                let fields = asked.fields.filter { $0.0 != "within" && $0.0 != "sort" }
                let outside = try SearchRequest(formEncoded: Self.query(fields)).parameters
                let sort = asked.fields.first { $0.0 == "sort" }.flatMap { SearchSortOrder(rawValue: $0.1) } ?? .relevance
                let text = try #require(fields.first { $0.0 == "keywords" }).1
                if name.hasPrefix("words") {
                    let gated = LayeredResultComposer.gating(outside, inside: meaningBase)
                    let kept = LayeredResultComposer.wordsInMatches(
                        keywordRows: try await host.search.search(parameters: gated, limit: max(1, meaningBase.members.count), offset: 0),
                        base: meaningBase)
                    #expect(items.map(MeaningSearchParityTests.row) == sort.sorted(kept).map(MeaningSearchParityTests.row), "\(name)")
                    #expect(answer.total == kept.count && answer.layer.route == LayerRoute(kind: "wordsInMatches", base: meaningBase.members.count))
                    let filters = meaningBase.filtersNarrow(outside)
                    #expect(answer.layer.filtersNarrowed == filters, "\(name)")
                    #expect(answer.layer.signature == SearchScopeSignature.layered(nil, parameters: gated, basePart: meaningBase.signaturePart))
                    #expect(answer.layer.renderedExpression
                        == (try? await host.search.matchExpressions(for: gated).corpus).map { $0 + meaningBase.renderedExpressionSuffix })
                    #expect(answer.layer.disclosure == nil && answer.layer.strip == nil && answer.layer.unrankedTail == nil)
                    let size = meaningBase.members.count
                    let expected = filters
                        ? (kept.isEmpty ? "None of your \(size) closest matches both contains these words and passes your filters"
                           : "\(kept.count) of your \(size) closest matches contain\(kept.count == 1 ? "s these words and passes" : " these words and pass") your filters")
                        : (kept.isEmpty ? "None of your \(size) closest matches contains these words"
                           : kept.count == 1 ? "1 of your \(size) closest matches contains these words"
                           : "\(kept.count) of your \(size) closest matches contain these words")
                    #expect(answer.layer.header == expected, "\(name)")
                    words += kept.isEmpty ? 0 : 1
                    if kept.isEmpty {
                        #expect(answer.layer.empty == LayerEmpty(statement: expected, searchLibraryTitle: "Search the Whole Library for These Words",
                                                                 backTitle: meaningBase.backTitle))
                    }
                    #expect(answer.layer.swap?.help == "Search for “\(text)” first, then rank what it finds by “\(question)”")
                    narrowed += filters ? 1 : 0
                    Self.expectTheRow(answer.layer.base, meaningBase, name)
                } else {
                    let gated = LayeredResultComposer.gating(outside, inside: keywordBase)
                    let ranking = try await Self.backend(host, encoder: encoder).rerank(query: text, base: keywordBase.members,
                                                                                        parameters: gated)
                    let ordered = sort.sorted(ranking.results)
                    #expect(items.map(MeaningSearchParityTests.row) == ordered.map(MeaningSearchParityTests.row), "\(name)")
                    let tail = ranking.results.filter { $0.semanticScore == nil }.count
                    #expect(answer.total == ranking.results.count && answer.layer.route == LayerRoute(kind: "rankedByMeaning", unranked: tail))
                    #expect(answer.layer.disclosure == MeaningDisclosure(ranking.disclosure), "\(name)")
                    #expect(answer.layer.strip == MeaningSearchWords.strip(ranking.disclosure, beyondCount: 0))
                    let signature = SearchScopeSignature.semanticSignature(for: gated)
                    #expect(answer.layer.signature == SearchScopeSignature.layered(signature, parameters: gated, basePart: keywordBase.signaturePart))
                    #expect(answer.layer.renderedExpression == SemanticSearchBackend.renderedExpression(
                        rankingAll: keywordBase.members.count, model: Self.model) + keywordBase.renderedExpressionSuffix)
                    let expectedTail = LayeredResultComposer.unrankedTail(of: ordered, route: .rankedByMeaning(unranked: tail), sortOrder: sort)
                    #expect(answer.layer.unrankedTail?.firstKey == expectedTail?.firstId && answer.layer.unrankedTail?.count == expectedTail?.count)
                    if let count = expectedTail?.count {
                        #expect(answer.layer.unrankedTail?.line == (count == 1 ? "1 result not ranked by meaning" : "\(count) results not ranked by meaning"))
                    }
                    let loaded = ranking.results.count
                    let header = tail > 0 ? "\(loaded) results · \(loaded - tail) ranked · \(tail) not ranked"
                        : sort == .relevance ? "\(loaded) results, closest first" : "\(loaded) results"
                    #expect(answer.layer.header == header, "\(name): \(answer.layer.header)")
                    #expect(answer.layer.swap?.help == "Ask “\(text)” first, then find “president” among its closest matches")
                    unranked += tail
                    Self.expectTheRow(answer.layer.base, keywordBase, name)
                }
                found += items.count
            }
            #expect(found > 300, "the layers hold rows to compare: \(found)")
            #expect(narrowed == 1, "a filter chosen since narrows the words found, and the header says so")
            #expect(words >= 2, "words are found in the Meaning list: \(words)")
            #expect(unranked > 0, "a ranking's rows it could not rank are counted and listed last: \(unranked)")
        } catch {
            await encoder.shutdown()
            throw error
        }
        await encoder.shutdown()
    }

    /// A keyword list cut at the server's ceiling, lowered here to fifty rows, is ranked whole by a question, as the app
    /// ranks a list held at its ceiling: the kit's `rankWholeMatch` over the list's whole match, the closest listed up to
    /// the ceiling, and under a filter chosen since, the match narrowed before the ranking, which the header says.
    @Test func aListCutAtItsCeilingIsRankedWhole() async throws {
        let directory = try TemporaryDirectory()
        let settings = try StandInEncoder.settings(in: directory.url.appendingPathComponent("model"))
        let encoder = QueryEncoder(settings: settings)
        let built = try await FixtureIndex.value()
        let host = try Host.open(built, volumes: ParityFixtures.volumes)
        let ceiling = 50
        do {
            let president = try SearchRequest(formEncoded: "keywords=president").parameters
            let total = try await host.search.searchCount(parameters: president)
            #expect(total > ceiling, "the match is larger than the ceiling: \(total)")
            let list = Self.query([("keywords", "president")])
            let questions = ["Question 3 on the policy of the United States", "Question 11 on the policy of the United States"]
            let variants: [[(String, String)]] = [
                [("keywords", questions[0]), ("within", list)],
                [("keywords", questions[1]), ("within", list)],
                [("keywords", questions[0]), ("within", list), ("dateRangeEarliest", "1962-01-01"), ("dateRangeLatest", "1962-12-31")],
            ]
            let (answers, row) = try await ServedFixture.run(index: built.copy, volumes: ParityFixtures.volumes, encoder: settings,
                                                             searchCeiling: ceiling) { client, _ in
                var answers: [(LayeredSearchResult, [SearchItem])] = []
                for fields in variants { answers.append(try await Self.layer(client, fields)) }
                return (answers, try await Self.held(client, list))
            }
            let rows = try await host.search.search(parameters: president, limit: ceiling, offset: 0)
            var base = Self.held(route: .keywords, query: "president", rows: rows, hidden: [], fetchLimit: ceiling, total: total,
                                 expression: try? await host.search.matchExpressions(for: president).corpus, outcome: nil,
                                 parameters: president)
            #expect(base.wasCut && base.ranksWholeMatch)
            Self.expectTheRow(row, base, "the list cut at its ceiling")
            #expect(row.setDescription == "all \(total) results for “president”", "\(row.setDescription)")
            var filtered = 0
            for (index, (answer, items)) in answers.enumerated() {
                let fields = variants[index].filter { $0.0 != "within" }
                let outside = try SearchRequest(formEncoded: Self.query(fields)).parameters
                let question = fields[0].1
                let whole = try await Self.backend(host, encoder: encoder).rankWholeMatch(
                    query: question, base: base, match: president, parameters: outside, limit: ceiling)
                base.keepWholeMatch(whole.matchKeys)
                #expect(items.map(MeaningSearchParityTests.row) == whole.outcome.results.map(MeaningSearchParityTests.row), "\(fields)")
                let tail = whole.outcome.results.filter { $0.semanticScore == nil }.count
                let ranking = whole.ranking
                #expect(answer.layer.route == LayerRoute(kind: "rankedByMeaning", unranked: tail, wholeMatch: WholeMatch(
                    size: ranking.size, filteredOut: ranking.filteredOut, notRanked: ranking.notRanked, closest: ranking.closest,
                    isCut: ranking.isCut)), "\(fields)")
                #expect(answer.layer.disclosure == MeaningDisclosure(whole.outcome.disclosure))
                let gated = LayeredResultComposer.gating(outside, inside: base)
                #expect(answer.layer.signature == SearchScopeSignature.layered(whole.setSignature, parameters: gated, basePart: base.signaturePart))
                #expect(answer.layer.renderedExpression == SemanticSearchBackend.renderedExpression(
                    rankingAll: ranking.size, listing: ceiling, model: Self.model) + base.renderedExpressionSuffix)
                #expect(answer.total == whole.outcome.results.count)
                if ranking.filteredOut == 0 { #expect(ranking.isCut && answer.total == ceiling, "the closest fifty of a larger match") }
                let loaded = whole.outcome.results.count
                var header: String
                if ranking.isCut {
                    header = ranking.filteredOut > 0
                        ? "Closest \(ranking.closest) of the \(ranking.size) results that pass your filters"
                        : "Closest \(ranking.closest) of \(ranking.size) results"
                    if ranking.notRanked > 0 { header += " · \(ranking.notRanked) not ranked" }
                } else {
                    header = tail > 0 ? "\(loaded) results · \(loaded - tail) ranked · \(tail) not ranked" : "\(loaded) results, closest first"
                }
                #expect(answer.layer.header == header, "\(answer.layer.header)")
                filtered += ranking.filteredOut > 0 ? 1 : 0
            }
            #expect(filtered == 1, "a filter chosen since narrows the match before the ranking")
        } catch {
            await encoder.shutdown()
            throw error
        }
        await encoder.shutdown()
    }

    /// The fallback under a keyword search that found nothing is the kit's searcher's nearest ten across the series,
    /// filter-blind, each hit the index holds opening and resolved from its record, the rest titled from the catalogue,
    /// with the kit's caption in a server's words, which says the filters are not applied where the search had any.
    @Test func theFallbackIsTheKitsNearestAcrossTheSeries() async throws {
        let directory = try TemporaryDirectory()
        let settings = try StandInEncoder.settings(in: directory.url.appendingPathComponent("model"))
        let encoder = QueryEncoder(settings: settings)
        let built = try await FixtureIndex.value()
        let host = try Host.open(built, volumes: ParityFixtures.volumes)
        do {
            let questions = try await MeaningSearchParityTests.questions(host: host, encoder: encoder, enough: 2) { !$0.results.isEmpty }
            let answers = try await ServedFixture.run(index: built.copy, volumes: ParityFixtures.volumes, encoder: settings) { client, _ in
                var answers: [(String, Bool, MeaningFallback)] = []
                for question in questions {
                    for filtered in [false, true] {
                        let fields = [("keywords", question)] + (filtered ? [("volumeIds", "frus1961-63v06")] : [])
                        let response = try await client.execute(uri: "/api/v1/search/fallback?" + Self.query(fields), method: .get)
                        guard response.status == .ok else { throw APIParityError("\(response.status.code) \(String(buffer: response.body))") }
                        answers.append((question, filtered, try ServedFixture.decode(MeaningFallback.self, response)))
                    }
                }
                return answers
            }
            var opened = 0
            for (question, filtered, answer) in answers {
                let searcher = SemanticQuerySearcher(index: host.tiers.index, corpus: host.tiers.corpus, shards: host.shards,
                                                     encoder: SemanticEmbedFunction { try await encoder.embed($0).vector },
                                                     requestShardFetch: { _ in false })
                let results = try await searcher.search(question)
                #expect(answer.hits.map { "\($0.volumeId)/\($0.documentId) \(MeaningSearchParityTests.score($0.score)) \($0.chip)" }
                    == results.hits.map { "\($0.volumeID)/\($0.documentID) \(MeaningSearchParityTests.score($0.score)) \(SemanticScoreCopy.chipLabel(for: $0.score))" })
                let keys = results.hits.filter { host.indexed.contains($0.volumeID) }.map { DocumentKey(volumeId: $0.volumeID, documentId: $0.documentID) }
                let records = try await built.index.pipeline.candidateRecords(forKeys: keys)
                for hit in answer.hits {
                    let record = records[DocumentKey(volumeId: hit.volumeId, documentId: hit.documentId)]
                    #expect(hit.opens == (record != nil) && hit.dateline == record?.dateline, "\(hit)")
                    #expect(hit.volumeTitle == host.manifest[hit.volumeId]?.title ?? hit.volumeId)
                    opened += hit.opens ? 1 : 0
                }
                #expect(answer.caption == MeaningSearchWords.server(SemanticFallbackCopy.caption(
                    unscored: results.unscoredCandidates, unscoredVolumes: results.unscoredVolumes,
                    downloadingVolumes: results.downloadingVolumes, filtersActive: filtered, locale: MeaningSearchWords.locale)))
                #expect(answer.caption.contains("Your filters are not applied here.") == filtered, "\(answer.caption)")
                #expect(answer.caption.hasPrefix("Ranked by meaning, not keywords, across the whole series — your exact words may not appear."))
                #expect(!answer.caption.contains("Settings") && !answer.caption.contains("device"), "\(answer.caption)")
            }
            #expect(opened > 0, "hits the fixture index holds open in the reader")
        } catch {
            await encoder.shutdown()
            throw error
        }
        await encoder.shutdown()
    }

    /// The sentences the server mirrors from the app: `ResultSetScope`'s for the two layered routes, its header and a
    /// capture's warnings and record, and the search screen's `SearchLayerEmptyState` and `SearchLayerCopy`; each held to the
    /// app's source, so that a pin move that rewords one fails here.
    @Test func theServersLayerWordsAreTheApps() throws {
        let scope = try SearchSetParityTests.app("Search/ResultSetScope.swift")
        let views = try SearchSetParityTests.app("Search/SearchLayerViews.swift")
        let sentences = [
            "Your closest match does not contain these words", "Your closest match contains these words",
            "None of your %@ closest matches contains these words", "1 of your %@ closest matches contains these words",
            "%1$@ of your %2$@ closest matches contain these words", "%@, closest first", "%1$@ · %2$@ ranked · %3$@ not ranked",
            "None of the %@ results that pass your filters could be ranked", "None of the %@ results could be ranked",
            "Closest %1$@ of the %2$@ results that pass your filters", "Closest %1$@ of %2$@ results", "%@ not ranked",
            "Your closest match does not both contain these words and pass your filters",
            "Your closest match contains these words and passes your filters",
            "None of your %@ closest matches both contains these words and passes your filters",
            "1 of your %@ closest matches contains these words and passes your filters",
            "%1$@ of your %2$@ closest matches contain these words and pass your filters", "%@ shown",
            "This document is the one among a Meaning search’s closest matches that contains your words, not every document that contains them. Counts taken inside this corpus are counts inside that set.",
            "These documents are the ones among a Meaning search’s closest matches that contain your words, not every document that contains them. Counts taken inside this corpus are counts inside that set.",
            "This document is the closest to your question of %@ matching documents, not all of them. Counts taken inside this corpus are counts inside that subset.",
            "These %1$@ documents are the closest to your question of %2$@ matching documents, not all of them. Counts taken inside this corpus are counts inside that subset.",
            "These %1$@ documents are the %2$@ closest to your question of %3$@ matching documents, and %4$@ that it could not rank. Counts taken inside this corpus are counts inside that subset.",
            "These %1$@ documents are the highest-scoring of %2$@ matching documents. Counts taken inside this corpus are counts inside that subset.",
            "These %@ documents are the highest-scoring of a larger match, not all of it. Counts taken inside this corpus are counts inside that subset.",
            " — the highest-scoring %1$@ of %2$@ matches", "Words found in a Meaning search’s closest matches to %3$@ — %1$@ of %2$@",
            "Words found in a Meaning search’s closest matches — %1$@ of %2$@", "Search results for %@, ranked by a question",
            "Search results, ranked by a question", " — the closest %1$@ of %2$@ matches, and %3$@ not ranked",
            " — the closest %1$@ of %2$@ matches", " — the highest-scoring %@ of a larger match",
        ]
        for sentence in sentences + Self.templates.values {
            #expect(scope.contains("defaultValue: \"\(sentence)\""), "ResultSetScope.swift says \"\(sentence)\"")
        }
        // The server's say them in its own interpolation: each held, its placeholders filled, in its file.
        let server = try SearchSetParityTests.server("Sources/FRUSLightAPI/SearchWithin.swift")
        for line in [
            #"return loaded == 0 ? "Your closest match does not contain these words" : "Your closest match contains these words""#,
            #"case 0: return "None of your \(grouped(base)) closest matches contains these words""#,
            #"default: return "\(grouped(loaded)) of your \(grouped(base)) closest matches contain these words""#,
            #"return "\(resultsPhrase(loaded)), closest first""#,
            #"return "\(resultsPhrase(loaded)) · \(grouped(max(0, loaded - unranked))) ranked · \(grouped(unranked)) not ranked""#,
            #"? "Closest \(grouped(wholeMatch.closest)) of the \(grouped(wholeMatch.size)) results that pass your filters""#,
            #"description = "Words found in a Meaning search’s closest matches to \(label) — \(grouped(loaded)) of \(grouped(base))""#,
            #"description = layerBaseLabel.map { "Search results for \($0), ranked by a question" }"#,
            #"static let searchLibraryTitle = "Search the Whole Library for These Words""#,
            #"static let rankedStatementOfRows = "None of the results you are searching within passes your filters.""#,
            #"case .rankByMeaning: "Search for “\(list)” first, then rank what it finds by “\(inside)”""#,
            #"case .wordsInMatches: "Ask “\(list)” first, then find “\(inside)” among its closest matches""#,
        ] {
            #expect(server.contains(line), "SearchWithin.swift holds \(line)")
        }
        NoteViewParityTests.expect(views, holds: [
            #"String(localized: "search.layer.empty.searchLibrary", defaultValue: "Search the Whole Library for These Words")"#,
            #"defaultValue: "None of the results you are searching within passes your filters.")"#,
            #"defaultValue: "Search for “%1$@” first, then rank what it finds by “%2$@”"),"#,
            #"defaultValue: "Ask “%1$@” first, then find “%2$@” among its closest matches"),"#,
            #"defaultValue: "%@ result not ranked by meaning"),"#,
            #"defaultValue: "%@ results not ranked by meaning"))"#,
        ], file: "SearchLayerViews.swift")
        // The layered routes' rules, read as the app reads them.
        NoteViewParityTests.expect(scope, holds: [
            "case .meaning, .wordsInMatches: return false",
            "case .rankedByMeaning(_, let wholeMatch?): return wholeMatch.isCut",
            "case .rankedByMeaning: if let layerBaseWasCut { return layerBaseWasCut }",
            "if case .wordsInMatches = route { return true }",
            "var isCapturePartial: Bool { isMeaningSearch || isPartialEvidence }",
        ], file: "ResultSetScope.swift")
    }

    /// The app's templates for the two layered routes (`ResultSetScope.swift`), each held to its source by
    /// `theServersLayerWordsAreTheApps`, by the key the account below fills them in under.
    static let templates: [String: String] = [
        "one result": "1 result", "results": "%@ results", "shown": "%@ shown",
        "words single none": "Your closest match does not contain these words", "words single": "Your closest match contains these words",
        "words none": "None of your %@ closest matches contains these words", "words one": "1 of your %@ closest matches contains these words",
        "words": "%1$@ of your %2$@ closest matches contain these words",
        "words single none filtered": "Your closest match does not both contain these words and pass your filters",
        "words single filtered": "Your closest match contains these words and passes your filters",
        "words none filtered": "None of your %@ closest matches both contains these words and passes your filters",
        "words one filtered": "1 of your %@ closest matches contains these words and passes your filters",
        "words filtered": "%1$@ of your %2$@ closest matches contain these words and pass your filters",
        "ranked": "%@, closest first", "ranked partial": "%1$@ · %2$@ ranked · %3$@ not ranked",
        "whole none filtered": "None of the %@ results that pass your filters could be ranked",
        "whole none": "None of the %@ results could be ranked",
        "whole filtered": "Closest %1$@ of the %2$@ results that pass your filters", "whole": "Closest %1$@ of %2$@ results",
        "whole not ranked": "%@ not ranked",
        "warn words one": "This document is the one among a Meaning search’s closest matches that contains your words, not every document that contains them. Counts taken inside this corpus are counts inside that set.",
        "warn words": "These documents are the ones among a Meaning search’s closest matches that contain your words, not every document that contains them. Counts taken inside this corpus are counts inside that set.",
        "warn whole one": "This document is the closest to your question of %@ matching documents, not all of them. Counts taken inside this corpus are counts inside that subset.",
        "warn whole": "These %1$@ documents are the closest to your question of %2$@ matching documents, not all of them. Counts taken inside this corpus are counts inside that subset.",
        "warn whole unranked": "These %1$@ documents are the %2$@ closest to your question of %3$@ matching documents, and %4$@ that it could not rank. Counts taken inside this corpus are counts inside that subset.",
        "warn highest": "These %1$@ documents are the highest-scoring of %2$@ matching documents. Counts taken inside this corpus are counts inside that subset.",
        "warn highest unknown": "These %@ documents are the highest-scoring of a larger match, not all of it. Counts taken inside this corpus are counts inside that subset.",
        "checklist one": "Checklist mode is hiding %@ reviewed document. It will not be in this corpus.",
        "checklist": "Checklist mode is hiding %@ reviewed documents. They will not be in this corpus.",
        "source words within": "Words found in a Meaning search’s closest matches to %3$@ — %1$@ of %2$@",
        "source words": "Words found in a Meaning search’s closest matches — %1$@ of %2$@",
        "source ranked": "Search results for %@, ranked by a question", "source ranked unlabelled": "Search results, ranked by a question",
        "source narrowed": "%1$@ (%2$@)", "source highest": " — the highest-scoring %1$@ of %2$@ matches",
        "source highest unknown": " — the highest-scoring %@ of a larger match",
        "source whole unranked": " — the closest %1$@ of %2$@ matches, and %3$@ not ranked", "source whole": " — the closest %1$@ of %2$@ matches",
        "source checklist one": "; %@ reviewed document excluded", "source checklist": "; %@ reviewed documents excluded",
    ]

    /// `templates[key]` with its placeholders filled in, in order, as `String(format:)` fills `%@` and `%n$@`.
    static func fill(_ key: String, _ values: String...) -> String {
        var text = templates[key]!
        for (index, value) in values.enumerated() {
            text = text.replacingOccurrences(of: "%\(index + 1)$@", with: value)
        }
        for value in values where text.contains("%@") {
            text = text.replacingOccurrences(of: "%@", with: value, range: text.range(of: "%@"))
        }
        return text
    }

    /// What the server says of a layer's rows, `LayerScope`, is what the app's `ResultSetScope` says of the two layered
    /// routes, case by case: the header, the capture's warnings, its record and its flags, each sentence the app's own
    /// template with its counts filled in, grouped as the browser app's words are.
    @Test func theLayersAccountIsTheApps() {
        func scope(_ route: ExecutedSearchRoute, loaded: Int, shown: Int? = nil, total: Int? = nil, narrowed: Bool = false,
                   rankOrder: Bool = true, label: String? = nil, baseCut: Bool? = nil, baseHidden: Int = 0,
                   narrowing: [String] = []) -> LayerScope {
            var scope = LayerScope(loaded: loaded, shown: shown ?? loaded, fetchLimit: 7_500, totalMatchCount: total, route: route)
            scope.layerFiltersNarrowed = narrowed
            scope.listIsInRankOrder = rankOrder
            scope.layerBaseLabel = label
            scope.layerBaseWasCut = baseCut
            scope.layerBaseHiddenByChecklist = baseHidden
            scope.narrowing = narrowing
            return scope
        }
        let g = CorpusCapture.grouped
        // The header of words found in a Meaning list, with and without filters chosen since, and with rows hidden.
        for narrowed in [false, true] {
            let suffix = narrowed ? " filtered" : ""
            #expect(scope(.wordsInMatches(base: 1), loaded: 0, narrowed: narrowed).headerDescription == Self.fill("words single none" + suffix))
            #expect(scope(.wordsInMatches(base: 1), loaded: 1, narrowed: narrowed).headerDescription == Self.fill("words single" + suffix))
            #expect(scope(.wordsInMatches(base: 1_200), loaded: 0, narrowed: narrowed).headerDescription == Self.fill("words none" + suffix, "1,200"))
            #expect(scope(.wordsInMatches(base: 1_200), loaded: 1, narrowed: narrowed).headerDescription == Self.fill("words one" + suffix, "1,200"))
            #expect(scope(.wordsInMatches(base: 1_200), loaded: 1_100, narrowed: narrowed).headerDescription
                == Self.fill("words" + suffix, "1,100", "1,200"))
        }
        #expect(scope(.wordsInMatches(base: 100), loaded: 5, shown: 3).headerDescription
            == [Self.fill("shown", "3"), Self.fill("words", "5", "100")].joined(separator: " · "))
        // A ranking's header: none, closest first in its order, a date order, rows it could not rank, a whole match.
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 0).headerDescription == "No results")
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1).headerDescription == Self.fill("ranked", Self.fill("one result")))
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1_500).headerDescription == Self.fill("ranked", Self.fill("results", "1,500")))
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1_500, rankOrder: false).headerDescription == Self.fill("results", "1,500"))
        #expect(scope(.rankedByMeaning(unranked: 7), loaded: 1_500).headerDescription
            == Self.fill("ranked partial", Self.fill("results", "1,500"), "1,493", "7"))
        let whole = WholeMatchRanking(size: 35_275, notRanked: 0, closest: 7_500, isCut: true)
        let filtered = WholeMatchRanking(size: 4_012, filteredOut: 31_263, notRanked: 3, closest: 4_009, isCut: true)
        let noneRanked = WholeMatchRanking(size: 24, filteredOut: 0, notRanked: 24, closest: 0, isCut: true)
        #expect(scope(.rankedByMeaning(unranked: 0, wholeMatch: whole), loaded: 7_500, total: 35_275).headerDescription
            == Self.fill("whole", "7,500", "35,275"))
        #expect(scope(.rankedByMeaning(unranked: 3, wholeMatch: filtered), loaded: 4_012, total: 35_275).headerDescription
            == [Self.fill("whole filtered", "4,009", "4,012"), Self.fill("whole not ranked", "3")].joined(separator: " · "))
        #expect(scope(.rankedByMeaning(unranked: 24, wholeMatch: noneRanked), loaded: 24).headerDescription == Self.fill("whole none", "24"))
        let noneFiltered = WholeMatchRanking(size: 24, filteredOut: 5, notRanked: 24, closest: 0, isCut: true)
        #expect(scope(.rankedByMeaning(unranked: 24, wholeMatch: noneFiltered), loaded: 24).headerDescription
            == Self.fill("whole none filtered", "24"))

        // A capture's warnings.
        #expect(scope(.wordsInMatches(base: 100), loaded: 1).captureTruncationWarning == Self.fill("warn words one"))
        #expect(scope(.wordsInMatches(base: 100), loaded: 7).captureTruncationWarning == Self.fill("warn words"))
        #expect(scope(.rankedByMeaning(unranked: 24, wholeMatch: noneRanked), loaded: 24).captureTruncationWarning
            == Self.fill("warn highest", "24", "24"))
        let one = WholeMatchRanking(size: 35_275, notRanked: 0, closest: 1, isCut: true)
        #expect(scope(.rankedByMeaning(unranked: 0, wholeMatch: one), loaded: 1).captureTruncationWarning == Self.fill("warn whole one", "35,275"))
        #expect(scope(.rankedByMeaning(unranked: 0, wholeMatch: whole), loaded: 7_500).captureTruncationWarning
            == Self.fill("warn whole", "7,500", "35,275"))
        #expect(scope(.rankedByMeaning(unranked: 3, wholeMatch: filtered), loaded: 4_012).captureTruncationWarning
            == Self.fill("warn whole unranked", "4,012", "4,009", "4,012", "3"))
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 7_500, total: 9_000, baseCut: true).captureTruncationWarning
            == Self.fill("warn highest", "7,500", "9,000"))
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 7_500, baseCut: true).captureTruncationWarning == Self.fill("warn highest unknown", "7,500"))
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 212, total: 212, baseCut: false).captureTruncationWarning == nil)
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 10, shown: 9).captureChecklistWarning == Self.fill("checklist one", "1"))
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 10, shown: 9, baseHidden: 2).captureChecklistWarning == Self.fill("checklist", "3"))

        // A capture's record, and its flags.
        #expect(scope(.wordsInMatches(base: 100), loaded: 7, label: "“how did the embassy”").captureProvenanceDescription
            == Self.fill("source words within", "7", "100", "“how did the embassy”"))
        #expect(scope(.wordsInMatches(base: 1_100), loaded: 1_007, narrowing: ["years 1945", "documents only"]).captureProvenanceDescription
            == Self.fill("source narrowed", Self.fill("source words", "1,007", "1,100"), "years 1945; documents only"))
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 212, total: 212, label: "“treaties”", baseCut: false).captureProvenanceDescription
            == Self.fill("source ranked", "“treaties”"))
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 212, total: 212, baseCut: false).captureProvenanceDescription
            == Self.fill("source ranked unlabelled"))
        #expect(scope(.rankedByMeaning(unranked: 0, wholeMatch: whole), loaded: 7_500, label: "“war”").captureProvenanceDescription
            == Self.fill("source ranked", "“war”") + Self.fill("source whole", "7,500", "35,275"))
        #expect(scope(.rankedByMeaning(unranked: 3, wholeMatch: filtered), loaded: 4_012, label: "“war”").captureProvenanceDescription
            == Self.fill("source ranked", "“war”") + Self.fill("source whole unranked", "4,009", "4,012", "3"))
        #expect(scope(.rankedByMeaning(unranked: 24, wholeMatch: noneRanked), loaded: 24).captureProvenanceDescription
            == Self.fill("source ranked unlabelled") + Self.fill("source highest", "24", "24"))
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 7_500, total: 9_000, baseCut: true, baseHidden: 1).captureProvenanceDescription
            == Self.fill("source ranked unlabelled") + Self.fill("source highest", "7,500", "9,000") + Self.fill("source checklist one", "1"))
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 7_500, shown: 7_000, baseCut: true).captureProvenanceDescription
            == Self.fill("source ranked unlabelled") + Self.fill("source highest unknown", "7,500") + Self.fill("source checklist", g(500)))
        #expect(scope(.wordsInMatches(base: 100), loaded: 7).isCapturePartial)
        #expect(!scope(.rankedByMeaning(unranked: 0), loaded: 212, total: 212, baseCut: false).isCapturePartial)
        #expect(scope(.rankedByMeaning(unranked: 0, wholeMatch: whole), loaded: 7_500).isCapturePartial)
        var inside = scope(.rankedByMeaning(unranked: 0), loaded: 12, total: 12, baseCut: false)
        inside.insideTruncatedCorpus = true
        #expect(inside.isCapturePartial, "inside a corpus captured short, as the app reads `isPartialEvidence`")
    }

    /// The browser app's words for Search Within These Results and the fallback: the commands, the field's prompts, the
    /// Mac's toolbar help, the held list's row, Swap and its close button, what a screen reader hears, Save this search's
    /// line, and the fallback's title and lines, each the app's.
    @Test func theBrowserAppsWordsAreTheApps() throws {
        let sources = NoteViewParityTests.Sources()
        let layering = try sources.app("FRUSCoreKit/Search/SearchLayering.swift")
        let views = try sources.app("Search/SearchLayerViews.swift")
        let fallback = try sources.app("Search/SemanticSearchFallbackView.swift")
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let layer = try NoteViewParityTests.block("searchLayer", of: copy)
        let semantic = try NoteViewParityTests.block("meaningFallback", of: copy)
        let pairs: [(String, String, String, String)] = [
            ("kit", "search.layer.start.wordsInMatches", "Find Words in These Matches", "wordsInMatches: 'Find Words in These Matches'"),
            ("kit", "search.layer.start.rankByMeaning", "Rank These Results by a Question", "rankByMeaning: 'Rank These Results by a Question'"),
            ("kit", "search.layer.prompt.wordsInMatches", "Words to find in these matches…", "wordsInMatches: 'Words to find in these matches…'"),
            ("kit", "search.layer.prompt.rankByMeaning", "A question to rank these results by…", "rankByMeaning: 'A question to rank these results by…'"),
            ("views", "search.layer.swap", "Swap", "swap: 'Swap'"),
            ("views", "search.layer.swap.a11y", "Swap the two searches", "swapLabel: 'Swap the two searches'"),
            ("views", "search.layer.leave.a11y", "Stop searching within these results", "leave: 'Stop searching within these results'"),
            ("views", "search.layer.leave.help", "Show the list you were searching within again, as it was",
             "leaveHelp: 'Show the list you were searching within again, as it was'"),
            ("views", "search.layer.announce.leave", "Stopped searching within these results", "left: 'Stopped searching within these results'"),
            ("views", "search.saveSearch.layered", "Not while searching within results. Save as Working Corpus keeps these results.",
             "saveSearchUnavailable: 'Not while searching within results. Save as Working Corpus keeps these results.'"),
            ("views", "search.layer.toolbar.help.wordsInMatches",
             "Find words in these closest matches. They keep their order, and only those that contain your words stay listed.",
             "wordsInMatches: 'Find words in these closest matches. They keep their order, and only those that contain your words stay listed.'"),
            ("views", "search.layer.toolbar.help.rankByMeaning", "Rank these results by a question. Every result stays listed, the closest first.",
             "rankByMeaning: 'Rank these results by a question. Every result stays listed, the closest first.'"),
        ]
        for (source, key, value, line) in pairs {
            let text = source == "kit" ? layering : views
            #expect(NoteViewParityTests.writes(text, key, value), "the app writes \(key) as \(value)")
            #expect(layer.contains(line), "copy.ts says \(line)")
        }
        #expect(views.contains(#"defaultValue: "Rank every result of this search by a question, not only those loaded. The closest %@ are listed.")"#))
        #expect(layer.contains("`Rank every result of this search by a question, not only those loaded. The closest ${ceiling.toLocaleString('en-US')} are listed.`"))
        for (key, value, line) in [
            ("search.semantic.results.title", "Semantic matches (experimental)", "title: 'Semantic matches (experimental)'"),
            ("search.semantic.searching", "Searching by meaning…", "searching: 'Searching by meaning…'"),
            ("search.semantic.empty.title", "No semantic matches yet", "emptyTitle: 'No semantic matches yet'"),
            ("search.semantic.tooLong", "This search is too long for the model. Try a shorter phrasing.",
             "tooLong: 'This search is too long for the model. Try a shorter phrasing.'"),
            ("search.semantic.failed", "Semantic search could not run. Try again.", "failed: 'Semantic search could not run. Try again.'"),
        ] {
            #expect(NoteViewParityTests.writes(fallback, key, value), "the app writes \(key) as \(value)")
            #expect(semantic.contains(line), "copy.ts says \(line)")
        }
    }
}
