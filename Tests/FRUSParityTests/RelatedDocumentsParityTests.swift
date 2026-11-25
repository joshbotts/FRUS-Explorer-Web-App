// Related Documents and Suggested Next (PLAN's S23d), over the kit's fixture index imported as an export.
// Every fixture document's related list through the API is the kit's `RelatedDocumentsEngine.rank` over
// the same index, with the dependencies a host has at this pin, built here apart from the server's: the
// rows, their scores, their chips' words with the shared subjects named as the app's view names them, the
// count before the limit and the pool's line; and in each scope the app's picker offers, and under a
// tuning of the app's stored form. Since PLAN's S26d every axis ranks: the lexical axis with the index's
// search service and the bundled stop lists, read here, and the semantic axis with the kit's source,
// `SemanticVectorsSimilaritySource`, over a host of this suite's own, the bundled tier read here and the fixture
// volumes' shards each opened through the kit's `SemanticShard`; and the list's Beyond your library and each row's
// semantic score are the kit's too, over the fixture index and over an index of two of the three volumes, whose
// third's shard is held. A project seeded through the API, by its notes and a focus tag, has the leads the
// kit's `ProjectLeadsAggregator` makes of the kit's rankings of its seed, as the app's `ProjectLeadsService`
// makes them, and a lead dismissed stays hidden while the next fills its place; and its reach is the kit's
// `SemanticProjectReach` of the same seed. And the server's and the browser app's mirrors of the app's rules and
// words, held to the app's source. Since PLAN's S29g a row matched by meaning or by wording names the words it shares
// with the anchor, and the kit's names them in every list here too: its `SemanticSharedTerms` pass over the rows either
// axis scored, as the app's view runs it, with the language family's references read apart by URL, the web's tagger and
// the bundled stop lists read here, so that each pair's chips are the kit's.

import FRUSLanguage
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import SemanticVectorsKit
import Testing
import WordCloudKit

@testable import FRUSCoreKit
@testable import FRUSLightAPI

/// The fixture volumes' shards as a host reads them, apart from the server's store: each `<volume>.vec` of
/// `fixtures/semantic` through the kit's `SemanticShard`, validated against the bundled index's provenance and the
/// volume's count, once.
actor FixtureShards: SemanticShardSource {
    let folder: URL
    let index: SemanticVectorIndex
    private var opened: [String: SemanticShard] = [:]
    private var absent: Set<String> = []

    init(folder: URL = RepositoryFiles.semanticShards, index: SemanticVectorIndex) {
        self.folder = folder
        self.index = index
    }

    func shard(for volumeID: String) async -> SemanticShard? {
        if let shard = opened[volumeID] { return shard }
        guard !absent.contains(volumeID) else { return nil }
        let url = folder.appendingPathComponent("\(volumeID).vec")
        guard FileManager.default.fileExists(atPath: url.path),
              let shard = try? SemanticShard(contentsOf: url, provenance: index.provenance,
                                             expectedDocumentCount: index.volume(volumeID)?.documentCount)
        else {
            absent.insert(volumeID)
            return nil
        }
        opened[volumeID] = shard
        return shard
    }
}

/// The web's tagger, its walks given again in this suite apart from the server's `KeptWalks` (PLAN's S29g): each text is
/// walked once by the tagger, and its words given again in their order for every later list the text is in, each range
/// made again from its UTF-8 offsets, so that the kit's pass over a list here tags no text twice. A walk is the tagger's, a
/// function of the text and of what the walk reads; one its reader stopped is not kept, and a walk is given again only to
/// a text of the same bytes, never to one that `String` holds equal in other scalars.
final class ReplayedWalks: WordCloudTagger, @unchecked Sendable {
    private struct Walked {
        let start: Int
        let end: Int
        let lemma: String?
        let lexicalClass: WordCloudLexicalClass?
    }

    let tagger = FRUSWordCloudTagger()
    private let lock = NSLock()
    private var walks: [String: (text: String, walk: [Walked])] = [:]

    var identity: WordCloudTokenizerIdentity { tagger.identity }
    var health: NaturalLanguageHealth { tagger.health }

    func enumerateWords(in text: String, reading: WordCloudTagReading,
                        using body: (Range<String.Index>, String?, () -> WordCloudLexicalClass?) -> Bool) {
        let key = "\(reading.rawValue)\u{0}\(text)"
        lock.lock()
        let kept = walks[key]
        lock.unlock()
        let utf8 = text.utf8
        if let kept, kept.text.utf8.elementsEqual(utf8) {
            let walked = kept.walk
            for word in walked {
                let range = utf8.index(utf8.startIndex, offsetBy: word.start)..<utf8.index(utf8.startIndex, offsetBy: word.end)
                guard body(range, word.lemma, { word.lexicalClass }) else { return }
            }
            return
        }
        var walk: [Walked] = []
        var whole = true
        tagger.enumerateWords(in: text, reading: reading) { range, lemma, lexicalClass in
            let found = reading.contains(.lexicalClasses) ? lexicalClass() : nil
            walk.append(Walked(start: utf8.distance(from: utf8.startIndex, to: range.lowerBound),
                               end: utf8.distance(from: utf8.startIndex, to: range.upperBound), lemma: lemma, lexicalClass: found))
            whole = body(range, lemma, { found })
            return whole
        }
        guard whole else { return }
        lock.lock()
        walks[key] = (text, walk)
        lock.unlock()
    }

    func enumerateNames(in text: String, using body: (Range<String.Index>, WordCloudNameType?) -> Bool) {
        tagger.enumerateNames(in: text, using: body)
    }
}

/// Two of the three fixture volumes indexed by the kit, Kennedy and Khrushchev's letters and North Africa's documents,
/// once a process, for the off-index leads (PLAN's S26d): the third, 1894's Nicaragua, is off the index, and its shard is
/// held.
enum TwoVolumeIndex {
    static let volumes = ["frus1961-63v06", "frus1969-76ve09p1"]
    static let offIndex = "frus1894Nicaragua"

    static func value() async throws -> FixtureIndex.Built { try await shared.value }

    private static let shared = Task<FixtureIndex.Built, any Error> {
        let directory = try TemporaryDirectory()
        let layout = Repository.layout
        let tei = directory.url.appendingPathComponent("Volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: tei, withIntermediateDirectories: true)
        for volume in volumes {
            try FileManager.default.copyItem(at: layout.tei.appendingPathComponent("\(volume).xml"),
                                             to: tei.appendingPathComponent("\(volume).xml"))
        }
        let index = try await ParityIndex.build(
            volumes: volumes, tei: tei, resources: layout.upstream.appendingPathComponent(ParityIndex.resourcesPath),
            database: directory.url.appendingPathComponent("frus.db"))
        let copy = directory.url.appendingPathComponent("copy.db")
        try IndexCopy.rollbackJournal(of: index.database, to: copy)
        return FixtureIndex.Built(directory: directory, index: index, copy: copy)
    }
}

@Suite struct RelatedDocumentsParityTests {
    static let locale = Locale(identifier: "en_US")

    /// The bundled manifest by volume id, as a host's `VolumeManifestLookup`.
    struct Manifest: VolumeManifestLookup {
        let entries: [String: VolumeManifestEntry]

        func entry(forVolumeId id: String) -> VolumeManifestEntry? { entries[id] }
    }

    /// What a host has at this pin, read here apart from the server: the fixture index's pipeline, person
    /// store and cross-reference store (FRUS-Explorer#1891, since S23c's pin move), the bundled subject
    /// index and manifest; the lexical axis's search service and stop lists (S26d, S24e's follow-up); the
    /// semantic axis's bundled tier and shards, over the volumes the index holds (S26d); and the shared words' stop
    /// lists, references and tagger (S29g).
    struct Host: @unchecked Sendable {
        let pipeline: IndexingPipeline
        let persons: PersonMentionStore
        let crossReferences: CrossReferenceStore
        let subjects: DocumentSubjectIndex
        let manifest: [String: VolumeManifestEntry]
        let catalogue: [VolumeManifestEntry]
        let search: SearchService
        let stopwords: Set<String>
        let tiers: SemanticBundledTiers
        let shards: FixtureShards
        let indexed: Set<String>
        /// The bundled stop lists whole, which the shared words' tokenizer reads with the diplomatic one (S29g).
        let stopwordSet: WordCloudStopwordSet
        /// The web's tagger, each fixture text walked once for every list this host names the shared words of (S29g).
        let walks = ReplayedWalks()

        static func open() async throws -> Host {
            try await open(try await FixtureIndex.value(), volumes: ParityFixtures.volumes)
        }

        static func open(_ built: FixtureIndex.Built, volumes: [String]) async throws -> Host {
            let resources = ServedFixture.resources
            let subjects = try JSONDecoder().decode(DocumentSubjectIndex.self,
                                                    from: Data(contentsOf: resources.appendingPathComponent("document-subject-index.json")))
            let catalogue = try FixedVolumeCatalogue(contentsOf: resources.appendingPathComponent("manifest.json")).citableEntries
            // Opened as a host opens it, with its own copies of the two bundled files the app's store reads.
            let crossReferences = try CrossReferenceStore(
                readingDatabaseAt: built.copy, volumes: catalogue,
                resolvedEdgeIndex: try ResolvedEdgeIndex(contentsOf: resources.appendingPathComponent("resolved-edge-index.json")),
                citedPageMap: try JSONDecoder().decode(CitedPageMap.self,
                                                       from: Data(contentsOf: resources.appendingPathComponent("cited-page-map.json"))))
            // The word cloud's stop lists with the diplomatic one, as the app's engine dependencies give the lexical axis.
            let stopwordSet = try WordCloudStopwordSet(contentsOf: resources.appendingPathComponent("word-cloud-stopwords.json"))
            let tiers = try SemanticBundledTiers(indexAt: resources.appendingPathComponent("semantic-vectors-index.json"),
                                                 binaryAt: resources.appendingPathComponent("semantic-vectors-binary.bin"))
            return Host(pipeline: built.index.pipeline, persons: try PersonMentionStore(readingDatabaseAt: built.copy),
                        crossReferences: crossReferences, subjects: subjects,
                        manifest: Dictionary(catalogue.map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first }),
                        catalogue: catalogue, search: built.index.service, stopwords: stopwordSet.active(includeDiplomatic: true),
                        tiers: tiers, shards: FixtureShards(index: tiers.index), indexed: Set(volumes), stopwordSet: stopwordSet)
        }

        /// The kit's semantic source over this host's tier, shards, volumes and pipeline.
        @MainActor
        func semantic() -> SemanticVectorsSimilaritySource {
            SemanticVectorsSimilaritySource(host: SemanticSimilarityHost(
                index: tiers.index, corpusVectors: tiers.corpus, shardStore: shards, indexedVolumeIds: indexed, indexingPipeline: pipeline))
        }

        @MainActor
        func dependencies() -> RelatedDocumentsDependencies {
            RelatedDocumentsDependencies(
                indexingPipeline: pipeline, crossReferenceStore: crossReferences, personMentionStore: persons, documentSubjectIndex: subjects,
                manifestStore: Manifest(entries: manifest), searchService: search, indexedVolumeIds: indexed,
                lexicalStopwords: stopwords, semantic: semantic())
        }

        /// The kit's ranking for `anchor`, as the app's list loads it: the year of the index's date, the
        /// shared subjects named on the rows the shared-subjects axis scored, and the shared words named on the rows the
        /// semantic or the lexical axis scored (S29g).
        @MainActor
        func ranked(_ anchor: DocumentKey, weights: AxisWeights, scope: Set<String>?, limit: Int = 30) async throws -> RelatedDocumentsResult {
            let dates = try await pipeline.documentDates(for: [(volumeId: anchor.volumeId, documentId: anchor.documentId)])
            let year = dates[anchor.compositeString].flatMap { Int($0.prefix(4)) }
            let result = await RelatedDocumentsEngine.rank(anchor: anchor, anchorYear: year, weights: weights, scopeVolumeIds: scope,
                                                           limit: limit, dependencies: dependencies())
            var rows = result.rows
            let scored = rows.indices.filter { rows[$0].axisScores[.sharedSubjects] != nil }
            let names = subjects.sharedSubjectNames(anchor: anchor, candidates: scored.map { rows[$0].key })
            for index in scored {
                if let found = names[rows[index].key], !found.isEmpty {
                    rows[index].axisEvidenceLabel[.sharedSubjects] = found.joined(separator: "\u{1F}")
                }
            }
            rows = await namingSharedTerms(rows, anchor: anchor)
            return RelatedDocumentsResult(rows: rows, totalBeforeLimit: result.totalBeforeLimit, poolCutFrom: result.poolCutFrom,
                                          offIndexLeads: result.offIndexLeads)
        }

        /// The words each row the semantic or the lexical axis scored shares with the anchor, as the app's view names them
        /// (`attachSemanticEvidence(claimedKey:)`): the kit's pass over those rows, with the family's references read apart
        /// by URL, the web's tagger at its own verdict, its walks given again (`walks`), and the bundled stop lists, the
        /// words joined as the kit's chip splits them under each of the two axes that scored the row. Off the main actor,
        /// which the servers beside it rank on.
        func namingSharedTerms(_ rows: [RelatedDocumentRow], anchor: DocumentKey) async -> [RelatedDocumentRow] {
            let vocabularyAxes: [SimilarityAxis] = [.semanticSimilarity, .lexicalSimilarity]
            let scoredRows = rows.filter { row in vocabularyAxes.contains { row.axisScores[$0] != nil } }
            guard !scoredRows.isEmpty else { return rows }
            let evidence = await SemanticSharedTerms.sharedTerms(
                anchor: anchor, candidates: scoredRows.map(\.key), pipeline: pipeline, references: LanguageReadings.references,
                languageAnalysis: walks.health, stopwords: stopwordSet, tagger: walks, isolation: nil)
            var rows = rows
            for index in rows.indices {
                guard let found = evidence.terms[rows[index].key], !found.isEmpty else { continue }
                for axis in vocabularyAxes where rows[index].axisScores[axis] != nil {
                    rows[index].axisEvidenceLabel[axis] = found.joined(separator: "\u{1F}")
                }
            }
            return rows
        }

        /// The kit's leads for a seed, as `ProjectLeadsService.recompute` makes them.
        @MainActor
        func leads(seed: [String], dismissed: Set<String>) async -> [ProjectLeadCandidate] {
            var perSeed: [(seed: String, related: [(key: String, score: Double)])] = []
            for key in seed.prefix(40) {
                guard let anchor = DocumentKey(compositeString: key) else { continue }
                let result = await RelatedDocumentsEngine.rank(anchor: anchor, anchorYear: nil, weights: .default, scopeVolumeIds: nil,
                                                               limit: 30, includeSnippets: false, includeOffIndexLeads: false,
                                                               dependencies: dependencies())
                perSeed.append((seed: key, related: result.rows.map { ($0.key.compositeString, $0.totalScore) }))
            }
            return ProjectLeadsAggregator.aggregate(perSeedRelated: perSeed, seedKeys: Set(seed), dismissedKeys: dismissed, limit: 24)
        }

        /// The kit's reach of a seed, as `ProjectLeadsService.recompute` asks it: its first forty.
        @MainActor
        func reach(seed: [String], weights: AxisWeights = .default) async -> ProjectReach {
            await SemanticProjectReach.reach(seedKeys: Array(seed.prefix(40)), weights: weights, host: semantic().host)
        }
    }

    /// A row as the comparison reads it: its key, its score to twelve places, its chips by axis and words, its line
    /// and its semantic score. Twelve places, since a score read back from the API's JSON on Linux can differ from the
    /// kit's in its last bit; the rows' order, which the scores decide, is compared whole.
    static func row(_ row: RelatedDocumentRow) -> String {
        let chips = row.whyRelatedChips.map { "\($0.axis.rawValue)=\($0.chip.displayText(locale: locale))" }
        return "\(row.key.compositeString) \(score(row.totalScore)) [\(chips.joined(separator: "; "))] \(row.snippet ?? "-")"
            + " semantic=\(row.axisScores[.semanticSimilarity].map(score) ?? "-")"
    }

    static func row(_ row: RelatedDocuments.Row) -> String {
        "\(row.volumeId)/\(row.documentId) \(score(row.score)) [\(row.chips.map { "\($0.axis)=\($0.text)" }.joined(separator: "; "))] \(row.snippet ?? "-")"
            + " semantic=\(row.semanticScore.map(score) ?? "-")"
    }

    static func score(_ value: Double) -> String { String(format: "%.12f", value) }

    /// Beyond your library as the app's section shows the kit's leads (`offIndexSection`), in the kit's words: its
    /// sentence, its counts, the documents it names, each with whether `served` holds its volume, its first five volumes
    /// and the line for the rest.
    static func beyond(_ leads: SemanticOffIndexLeads, titles: [String: VolumeManifestEntry], served: Set<String>) -> [String] {
        guard leads.documentCount > 0 else { return [] }
        func title(_ id: String) -> String { titles[id]?.title ?? id }
        return [RelatedDocumentsCounts.offIndexCaption(documents: leads.documentCount, volumes: leads.volumes.count,
                                                       isCapped: leads.isCapped, locale: locale),
                "\(leads.documentCount) in \(leads.volumes.count) capped=\(leads.isCapped)"]
            + leads.documents.map { "\($0.volumeID)/\($0.documentID) \(score($0.score)) \(SemanticSimilarityGenerator.evidenceLabel(for: $0.score)) \(title($0.volumeID)) served=\(served.contains($0.volumeID))" }
            + leads.volumes.prefix(5).map { "\($0.volumeID) \($0.count) \(RelatedDocumentsCounts.offIndexVolumeCount($0.count, locale: locale)) \(title($0.volumeID))" }
            + [leads.volumes.count > 5 ? RelatedDocumentsCounts.offIndexMoreVolumes(leads.volumes.count - 5, locale: locale) : "-"]
    }

    static func beyond(_ section: RelatedDocuments.BeyondLibrary?) -> [String] {
        guard let section else { return [] }
        return [section.caption, "\(section.documentCount) in \(section.volumeCount) capped=\(section.isCapped)"]
            + section.documents.map { "\($0.volumeId)/\($0.documentId) \(score($0.score)) \($0.chip) \($0.volumeTitle) served=\($0.served)" }
            + section.volumes.map { "\($0.volumeId) \($0.count) \($0.countText) \($0.title)" }
            + [section.moreVolumes ?? "-"]
    }

    /// Every document `built` holds, by volume and id.
    static func documents(in built: FixtureIndex.Built) throws -> [DocumentKey] {
        let db = try SQLiteConnection.immutable(built.copy)
        defer { db.close() }
        return try db.query("SELECT volume_id, document_id FROM document_cache ORDER BY volume_id, document_id")
            .map { DocumentKey(volumeId: $0[0].text ?? "", documentId: $0[1].text ?? "") }
    }

    /// Every document the fixture index holds, by volume and id.
    static func documents() async throws -> [DocumentKey] {
        try documents(in: try await FixtureIndex.value())
    }

    /// Every fixture document's list, in all volumes at the default tuning, is the kit's ranking, with its semantic
    /// scores and its Beyond your library; a seventh of them in each scope offered, under a tuning, and under one that
    /// raises the two experimental axes; every axis ranks.
    @Test func everyFixtureDocumentsRelatedListIsTheKitsRanking() async throws {
        let host = try await Host.open()
        let documents = try await Self.documents()
        #expect(documents.count > 100, "the three fixture volumes' documents")
        let tuning = "dateProximity:0.0,sharedPersons:1.0,subseries:0.9"
        let experimental = "lexicalSimilarity:0.6,semanticSimilarity:1.0"
        let read = try await ServedFixture.run { client, _ in
            var read: [String: RelatedDocuments] = [:]
            for (index, document) in documents.enumerated() {
                let base = "/api/v1/volumes/\(document.volumeId)/documents/\(document.documentId)/related"
                read["\(document.compositeString) all"] = try ServedFixture.decode(RelatedDocuments.self, try await client.execute(uri: base, method: .get))
                guard index.isMultiple(of: 7) else { continue }
                for scope in ["volume", "subseries"] {
                    let response = try await client.execute(uri: "\(base)?scope=\(scope)", method: .get)
                    if response.status == .ok { read["\(document.compositeString) \(scope)"] = try ServedFixture.decode(RelatedDocuments.self, response) }
                }
                read["\(document.compositeString) tuned"] = try ServedFixture.decode(
                    RelatedDocuments.self, try await client.execute(uri: "\(base)?weights=\(tuning)&limit=12", method: .get))
                read["\(document.compositeString) experimental"] = try ServedFixture.decode(
                    RelatedDocuments.self, try await client.execute(uri: "\(base)?weights=\(experimental)", method: .get))
            }
            return read
        }

        var rows = 0
        var chipsNamed = 0
        var cited = 0
        var meant = 0
        var worded = 0
        var beyond = 0
        // S29g: rows whose semantic chip names the words they share with the anchor, and those whose chip still says the
        // match alone; and, with the experimental axes raised, lexical chips that name words.
        var meantShared = 0
        var meantAlone = 0
        var wordedShared = 0
        for (index, document) in documents.enumerated() {
            let all = try #require(read["\(document.compositeString) all"])
            let kit = try await host.ranked(document, weights: .default, scope: nil)
            #expect(all.rows.map(Self.row) == kit.rows.map(Self.row), "\(document.compositeString)")
            #expect(all.totalBeforeLimit == kit.totalBeforeLimit)
            #expect(all.poolCut == kit.poolCutFrom.flatMap { $0 > kit.totalBeforeLimit
                ? RelatedDocumentsCounts.poolCut(ranked: kit.totalBeforeLimit, of: $0, locale: Self.locale) : nil })
            #expect(Self.beyond(all.beyondLibrary) == Self.beyond(kit.offIndexLeads, titles: host.manifest, served: host.indexed), "\(document.compositeString)")
            #expect(all.missingShards.isEmpty, "every served volume's shard is held")
            #expect(all.scope == "all" && all.weights == "")
            rows += all.rows.count
            // The kit's words since FRUS-Explorer#1930 (L15): "subjects: …", where they were "topics: …".
            chipsNamed += all.rows.filter { $0.chips.contains { $0.axis == "sharedSubjects" && $0.text.hasPrefix("subjects: ") } }.count
            cited += all.rows.filter { $0.chips.contains { $0.axis == "crossReference" } }.count
            meant += all.rows.filter { $0.semanticScore != nil && $0.chips.contains { $0.axis == "semanticSimilarity" } }.count
            let semanticChips = all.rows.flatMap(\.chips).filter { $0.axis == "semanticSimilarity" }.map(\.text)
            meantAlone += semanticChips.filter { $0.hasPrefix("shares: Semantic match · ") }.count
            meantShared += semanticChips.filter { $0.hasPrefix("shares: ") && !$0.hasPrefix("shares: Semantic match · ") }.count
            beyond += all.beyondLibrary == nil ? 0 : 1
            guard index.isMultiple(of: 7) else { continue }
            let subseries = host.manifest[document.volumeId]?.subseries ?? ""
            let members = Set(host.catalogue.filter { !subseries.isEmpty && $0.subseries == subseries }.map(\.volumeId))
            #expect(all.scopes == (members.count > 1 ? ["volume", "subseries", "all"] : ["volume", "all"]), "\(document.compositeString)")
            let volume = try #require(read["\(document.compositeString) volume"])
            let kitVolume = try await host.ranked(document, weights: .default, scope: [document.volumeId])
            #expect(volume.rows.map(Self.row) == kitVolume.rows.map(Self.row))
            #expect(Self.beyond(volume.beyondLibrary) == Self.beyond(kitVolume.offIndexLeads, titles: host.manifest, served: host.indexed),
                    "a scoped list's leads look past its scope")
            if members.count > 1 {
                let sub = try #require(read["\(document.compositeString) subseries"])
                #expect(sub.rows.map(Self.row) == (try await host.ranked(document, weights: .default, scope: members)).rows.map(Self.row))
            } else {
                #expect(read["\(document.compositeString) subseries"] == nil, "no subseries scope is offered, and none is ranked")
            }
            let weights = try #require(AxisWeights(rawValue: tuning))
            let tuned = try #require(read["\(document.compositeString) tuned"])
            #expect(tuned.weights == weights.rawValue && tuned.rows.count <= 12)
            #expect(tuned.rows.map(Self.row) == (try await host.ranked(document, weights: weights, scope: nil, limit: 12)).rows.map(Self.row))
            let raised = try #require(AxisWeights(rawValue: experimental))
            let both = try #require(read["\(document.compositeString) experimental"])
            let kitBoth = try await host.ranked(document, weights: raised, scope: nil)
            #expect(both.rows.map(Self.row) == kitBoth.rows.map(Self.row), "\(document.compositeString) with both experimental axes raised")
            #expect(Self.beyond(both.beyondLibrary) == Self.beyond(kitBoth.offIndexLeads, titles: host.manifest, served: host.indexed))
            worded += both.rows.filter { $0.chips.contains { $0.axis == "lexicalSimilarity" } }.count
            wordedShared += both.rows.flatMap(\.chips).filter { $0.axis == "lexicalSimilarity" && $0.text.hasPrefix("shares: ") }.count
        }
        #expect(rows > 1_000, "the lists hold rows to compare: \(rows)")
        #expect(chipsNamed > 0, "a shared-subjects chip names its subjects")
        #expect(cited > 0, "the cross-reference axis ranks: a row cites the anchor or is cited by it, and says so")
        #expect(meant > 1_000, "the semantic axis ranks, and its rows say so: \(meant)")
        #expect(worded > 0, "the lexical axis ranks where it is raised: \(worded)")
        #expect(beyond > 300, "the lists see beyond the three volumes served: \(beyond)")
        // S29g: the chips name the words their rows share, the kit's for each pair, under the semantic axis in most rows and
        // the lexical axis wherever it is raised; a row whose shared words the pass names none of says its match.
        #expect(meantShared > 5_000, "rows matched by meaning name the words they share: \(meantShared), \(meantAlone) the match alone")
        #expect(wordedShared > 500, "rows matched by wording name them too: \(wordedShared)")
        let axes = try #require(read.values.first?.axes)
        #expect(axes.map(\.id) == SimilarityAxis.allCases.map(\.rawValue))
        #expect(axes.allSatisfy { $0.available }, "every axis ranks on this server")
    }

    /// Over an index of two of the three fixture volumes, every document's Beyond your library through the API is the
    /// kit's over the same index and source: the third volume, off the index, among the volumes whose near documents it
    /// counts from the sign bits alone, and, where its shard and the anchor's are held, named and scored. Its documents
    /// themselves, asked for though the server does not serve them, have their own volume's beyond the library.
    @Test func theOffIndexLeadsAreTheKitsOverTwoOfTheThreeVolumes() async throws {
        let built = try await TwoVolumeIndex.value()
        let host = try await Host.open(built, volumes: TwoVolumeIndex.volumes)
        let served = try Self.documents(in: built)
        let all = try await Self.documents()
        let off = all.filter { $0.volumeId == TwoVolumeIndex.offIndex }.enumerated().filter { $0.offset.isMultiple(of: 5) }.map(\.element)
        #expect(Set(served.map(\.volumeId)) == Set(TwoVolumeIndex.volumes) && !off.isEmpty)
        let anchors = served + off
        let read = try await ServedFixture.run(index: built.copy, volumes: TwoVolumeIndex.volumes) { client, _ in
            var read: [String: RelatedDocuments] = [:]
            for anchor in anchors {
                read[anchor.compositeString] = try ServedFixture.decode(RelatedDocuments.self, try await client.execute(
                    uri: "/api/v1/volumes/\(anchor.volumeId)/documents/\(anchor.documentId)/related", method: .get))
            }
            return read
        }
        var counted = 0
        var named = 0
        for anchor in anchors {
            let list = try #require(read[anchor.compositeString])
            let kit = try await host.ranked(anchor, weights: .default, scope: nil)
            #expect(Self.beyond(list.beyondLibrary) == Self.beyond(kit.offIndexLeads, titles: host.manifest, served: host.indexed), "\(anchor.compositeString)")
            #expect(list.rows.map(Self.row) == kit.rows.map(Self.row), "\(anchor.compositeString)")
            #expect(list.missingShards.isEmpty)
            // A document with no vector, a chapter's or the front matter's, sees nothing beyond.
            guard let section = list.beyondLibrary else { continue }
            #expect(section.volumes.allSatisfy { !TwoVolumeIndex.volumes.contains($0.volumeId) }, "no volume the server serves")
            counted += kit.offIndexLeads.volumes.contains { $0.volumeID == TwoVolumeIndex.offIndex } ? 1 : 0
            named += section.documents.count
            #expect(section.documents.allSatisfy { $0.volumeId == TwoVolumeIndex.offIndex && !$0.served },
                    "named only where its volume's shard is held, and not served")
        }
        #expect(counted > 0, "the third volume holds near documents of some anchor: \(counted)")
        #expect(named > 0, "and some are named and scored: \(named)")
    }

    /// A project seeded through the API, by notes filed under it and a focus tag's assignment, has the
    /// kit's leads of its seed after a Refresh, each with its seeds and the record its ranking carried; a
    /// lead dismissed stays hidden after the next, and the next best fills its place; and its reach beyond the
    /// served index, under the defaults and under a tuning the browser brings, is the kit's.
    @Test func aSeededProjectsLeadsAreTheAggregators() async throws {
        let host = try await Host.open()
        let documents = try await Self.documents()
        let volume = try #require(ParityFixtures.volumes.first { $0 == "frus1961-63v06" })
        let ids = documents.filter { $0.volumeId == volume }.map(\.documentId)
        let (noted, tagged) = (Array(ids.prefix(3)), ids[10])
        let tuning = "semanticSimilarity:0.9"
        let (first, second, reaches) = try await ServedFixture.run { client, _ in
            let session = try await CollectionExportParityTests.Session.open(client)
            let project = try await session.json(Project.self, .post, "/api/v1/me/projects", ["name": "Grain"])
            for document in noted {
                _ = try await session.send(.post, "/api/v1/me/volumes/\(volume)/documents/\(document)/notes", try CollectionExportParityTests.json(
                    ["bodyText": "", "runs": nil, "userTagIds": [String](), "projectIds": [project.id], "selectedSummaryIds": [String]()]))
            }
            let tag = try await session.json(UserTag.self, .post, "/api/v1/me/tags", ["name": "Focus"])
            _ = try await session.send(.put, "/api/v1/me/volumes/\(volume)/documents/\(tagged)/tags",
                                       try CollectionExportParityTests.json(["tagIds": [tag.id]]))
            _ = try await session.send(.patch, "/api/v1/me/projects/\(project.id)", try CollectionExportParityTests.json(["defaultUserTagIds": [tag.id]]))
            let reaches = [
                try ServedFixture.decode(ProjectReachAnswer.self, try await session.get("/api/v1/me/projects/\(project.id)/reach")),
                try ServedFixture.decode(ProjectReachAnswer.self, try await session.get("/api/v1/me/projects/\(project.id)/reach?weights=\(tuning)")),
            ]
            let first = try await Self.refreshed(session, project.id)
            guard let lead = first.leads.first else { return (first, first, reaches) }
            _ = try await session.send(.post, "/api/v1/me/projects/\(project.id)/leads/\(lead.id)/dismiss")
            let second = try await Self.refreshed(session, project.id)
            return (first, second, reaches)
        }
        let seed = (noted + [tagged]).map { "\(volume)/\($0)" }.sorted()
        let kit = await host.leads(seed: seed, dismissed: [])
        #expect(!kit.isEmpty, "the seed has leads to compare")
        #expect(first.leads.map { "\($0.volumeId)/\($0.documentId)" } == kit.map(\.key))
        #expect(first.leads.map(\.relatedCount) == kit.map(\.contributingSeedKeys.count))
        #expect(first.leads.allSatisfy(\.isNew) && first.leadsRefresh?.state == "succeeded")
        let lead = try #require(first.leads.first)
        let dismissed = "\(lead.volumeId)/\(lead.documentId)"
        let next = await host.leads(seed: seed, dismissed: [dismissed]).filter { $0.key != dismissed }
        #expect(second.leads.map { "\($0.volumeId)/\($0.documentId)" } == next.map(\.key), "the dismissed lead hidden, the next best in its place")

        // The reach, the kit's of the same seed, under the defaults and under the browser's tuning.
        for (answer, weights) in zip(reaches, [AxisWeights.default, try #require(AxisWeights(rawValue: tuning))]) {
            let reach = await host.reach(seed: seed, weights: ProjectLeadsSeed.effectiveWeights(projectRaw: nil, browserRaw: weights.rawValue))
            #expect(answer.volumes.map { "\($0.volumeId) \($0.documentCount) \($0.reachingSeeds) \($0.title)" }
                    == reach.volumes.map { "\($0.volumeID) \($0.documentCount) \($0.reachingSeeds) \(host.manifest[$0.volumeID]?.title ?? $0.volumeID)" })
            #expect(answer.documentCount == reach.documentCount && answer.seedsProbed == reach.seedsProbed)
            #expect(!answer.volumes.isEmpty && answer.volumes.count <= SemanticProjectReach.volumeLimit && answer.seedsProbed > 0,
                    "the seed reaches past the three volumes")
            #expect(answer.volumes.allSatisfy { !ParityFixtures.volumes.contains($0.volumeId) })
        }
    }

    /// Project Home once the computation a Refresh queued has run to its end, and succeeded.
    static func refreshed(_ session: CollectionExportParityTests.Session, _ project: String) async throws -> ProjectHome {
        let response = try await session.send(.post, "/api/v1/me/projects/\(project)/leads/refresh", "{}")
        #expect(response.status == .accepted)
        let asked = try ServedFixture.decode(LeadsRefresh.self, response)
        for _ in 0..<600 {
            let home = try ServedFixture.decode(ProjectHome.self, try await session.get("/api/v1/me/projects/\(project)/home"))
            if let refresh = home.leadsRefresh, refresh.id == asked.id, refresh.state != "queued", refresh.state != "running" {
                #expect(refresh.state == "succeeded", "\(refresh)")
                return home
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw APIParityError("Suggested Next's computation did not end")
    }

    /// The server's kept walks (S29g) are the web's tagger's own: a quarter of the fixture documents' bodies, walked as the
    /// shared words' pass walks them, with their lemmas, and a tenth of those with their classes too, give the tagger's words,
    /// ranges, lemmas and classes, when first walked and when given again; two spellings of one text that `String` holds
    /// equal, composed and decomposed, are each walked as the tagger walks it, never one given the other's walk; and walks
    /// kept past their limit are let go, the least recently given first, and walked again as they were.
    @Test func theServersKeptWalksAreTheTaggersOwn() async throws {
        let host = try await Host.open()
        let documents = try await Self.documents()
        let texts = try await host.pipeline.documentBodyTextsByKey(
            forKeys: documents.map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) })
        #expect(texts.count > 300, "the fixture documents' bodies: \(texts.count)")
        /// A word of a walk: its range as UTF-8 offsets, its lemma and its class where the walk reads classes.
        struct Step: Equatable {
            let start: Int
            let end: Int
            let lemma: String?
            let lexicalClass: WordCloudLexicalClass?
        }
        func walk(_ tagger: some WordCloudTagger, _ text: String, _ reading: WordCloudTagReading) -> [Step] {
            var steps: [Step] = []
            let utf8 = text.utf8
            tagger.enumerateWords(in: text, reading: reading) { range, lemma, lexicalClass in
                steps.append(Step(start: utf8.distance(from: utf8.startIndex, to: range.lowerBound),
                                  end: utf8.distance(from: utf8.startIndex, to: range.upperBound), lemma: lemma,
                                  lexicalClass: reading.contains(.lexicalClasses) ? lexicalClass() : nil))
                return true
            }
            return steps
        }
        let tagger = FRUSWordCloudTagger()
        let kept = KeptWalks(tagger, wordLimit: 1_000_000)
        var walked = 0
        for (index, key) in texts.keys.sorted().enumerated() where index.isMultiple(of: 4) {
            let text = try #require(texts[key])
            let readings: [WordCloudTagReading] = index.isMultiple(of: 40) ? [[.lemmas], [.lemmas, .lexicalClasses]] : [[.lemmas]]
            for reading in readings {
                let own = walk(tagger, text, reading)
                #expect(walk(kept, text, reading) == own, "\(key) first walked")
                #expect(walk(kept, text, reading) == own, "\(key) given again")
                walked += own.count
            }
        }
        #expect(walked > 75_000 && kept.count.words == walked, "every word kept: \(walked), \(kept.count)")

        // One text in two spellings, equal as strings, a byte apart: each is walked as the tagger walks it, in either order.
        let composed = "The caf\u{E9} was closed when the minister arrived."
        let decomposed = "The cafe\u{301} was closed when the minister arrived."
        #expect(composed == decomposed && !composed.utf8.elementsEqual(decomposed.utf8))
        for first in [composed, decomposed] {
            let second = first.utf8.elementsEqual(composed.utf8) ? decomposed : composed
            let spellings = KeptWalks(tagger, wordLimit: 1_000)
            #expect(walk(spellings, first, [.lemmas]) == walk(tagger, first, [.lemmas]))
            #expect(walk(spellings, second, [.lemmas]) == walk(tagger, second, [.lemmas]), "never the other spelling's walk")
            #expect(walk(spellings, first, [.lemmas]) == walk(tagger, first, [.lemmas]))
            #expect(spellings.count.texts == 2, "each spelling kept apart: \(spellings.count)")
        }

        // Under a limit one word short of three texts of like length, the middle of the fixture's by bytes: the first is let
        // go once the third is kept, the other two being under nine tenths of the limit, and walked again as it was, when
        // the second, given longest ago now, is let go for it.
        let byLength = texts.values.sorted { $0.utf8.count < $1.utf8.count }
        let three = Array(byLength[(byLength.count / 2)..<(byLength.count / 2 + 3)])
        let words = three.map { walk(tagger, $0, [.lemmas]).count }
        let small = KeptWalks(tagger, wordLimit: words.reduce(0, +) - 1)
        let lowWater = small.wordLimit - small.wordLimit / 10
        #expect(words.allSatisfy { $0 > 10 } && words[1] + words[2] <= lowWater && words[0] + words[2] <= lowWater, "\(words)")
        for text in three { _ = walk(small, text, [.lemmas]) }
        #expect(small.count.texts == 2 && small.count.words == words[1] + words[2], "\(small.count)")
        #expect(walk(small, three[0], [.lemmas]) == walk(tagger, three[0], [.lemmas]))
        #expect(small.count.texts == 2 && small.count.words == words[0] + words[2], "\(small.count)")
    }

    /// The server's mirrors of the app's request, view and service, and the browser app's, as the app's
    /// source writes them.
    @Test func theMirrorsAreTheApps() throws {
        let request = try ProjectHistoryParityTests.app("RelatedDocuments/RelatedDocumentsRequest.swift")
        NoteViewParityTests.expect(request, holds: [
            "static let defaultLimit = 30",
            "let dates = (try? await pipeline.documentDates( for: [(volumeId: anchor.volumeId, documentId: anchor.documentId)])) ?? [:]",
            "indexDate.flatMap { Int($0.prefix(4)) } ?? doorYear",
            "case .allIndexed: return nil", "case .volume(let volumeId): return [volumeId]",
            "let members = entries.filter { $0.subseries == key }.map(\\.volumeId) return members.isEmpty ? nil : Set(members)",
            // A verdict's entry (S26d), which the server builds as `SemanticFeedbackRoutes.entry` does.
            "let year = await resolvedAnchorYear(pipeline: pipeline)",
            "return SemanticFeedbackEntry( recordedAt: recordedAt, anchor: anchor.compositeString, neighbour: row.key.compositeString, verdict: verdict, cosine: row.axisScores[.semanticSimilarity], era: year.map { CoverageEra.bucket(year: $0).rawValue.description }, sameVolume: row.key.volumeId == anchor.volumeId, provenanceDigest: provenanceDigest)",
        ], file: "RelatedDocumentsRequest.swift")
        let view = try ProjectHistoryParityTests.app("RelatedDocuments/RelatedDocumentsView.swift")
        NoteViewParityTests.expect(view, holds: [
            "var scopes: [NeighborScope] = [.volume(anchorVolumeId)] if let key = anchorSubseriesKey, subseriesMemberCount(key) > 1 { scopes.append(.subseries(key: key, anchorVolumeId: anchorVolumeId)) } scopes.append(.allIndexed)",
            "guard let key = appState.manifestStore.entry(forVolumeId: request.anchorVolumeId)?.subseries, !key.isEmpty else { return nil }",
            "let scored = rows.indices.filter { rows[$0].axisScores[.sharedSubjects] != nil }",
            "let names = store.sharedSubjectNames(anchor: request.anchor, candidates: scored.map { rows[$0].key })",
            #"rows[index].axisEvidenceLabel[.sharedSubjects] = found.joined(separator: "\u{1F}")"#,
            "Text(row.record.header.isEmpty ? row.documentId : row.record.header)",
            "if totalBeforeLimit > rows.count {", "if let poolCutFrom, poolCutFrom > totalBeforeLimit {",
            "case .allIndexed: return String(localized: \"related.empty.detail\",",
            // The verdicts' menu, on a row the semantic axis scored alone, and the generation it names (S26d).
            ".contextMenu { if row.axisScores[.semanticSimilarity] != nil { semanticFeedbackButtons(for: row) } }",
            "let provenanceDigest = BundledSemanticVectors.provenance?.digestHex",
            // Beyond your library: shown when the scan found a document, its rows, five volumes and the line for the rest.
            "} else if rows.isEmpty, offIndexLeads.documentCount == 0 {",
            "if rows.isEmpty { Text(emptyDetail)",
            "private static let offIndexVolumeDisplayLimit = 5",
            "if offIndexLeads.documentCount > 0 { Section {",
            "ForEach(offIndexLeads.documents) { document in",
            "ForEach(offIndexLeads.volumes.prefix(Self.offIndexVolumeDisplayLimit)) { lead in",
            "if offIndexLeads.volumes.count > Self.offIndexVolumeDisplayLimit { Text(RelatedDocumentsCounts.offIndexMoreVolumes( offIndexLeads.volumes.count - Self.offIndexVolumeDisplayLimit))",
            // The two experimental axes' captions, by whether the axis is off.
            "case .semanticSimilarity: return semanticAxisCaption case .lexicalSimilarity: return lexicalAxisCaption",
            "weights[.lexicalSimilarity] == 0 ?", "weights[.semanticSimilarity] == 0 ?",
            // The shared words (S29g): after the subjects, one pass over the rows either vocabulary axis scored, its words
            // written under each axis that scored the row, and a row it names none for left as it was.
            "attachSubjectEvidence() await attachSemanticEvidence(claimedKey: claimedKey)",
            "let vocabularyAxes: [SimilarityAxis] = [.semanticSimilarity, .lexicalSimilarity]",
            "let scoredRows = rows.filter { row in vocabularyAxes.contains { row.axisScores[$0] != nil } } guard !scoredRows.isEmpty else { return }",
            "let evidence = await SemanticSharedTerms.sharedTerms( anchor: request.anchor, candidates: scoredRows.map(\\.key), appState: appState)",
            #"guard !evidence.terms.isEmpty else { return } for index in rows.indices { guard let found = evidence.terms[rows[index].key], !found.isEmpty else { continue } for axis in vocabularyAxes where rows[index].axisScores[axis] != nil { rows[index].axisEvidenceLabel[axis] = found.joined(separator: "\u{1F}") } }"#,
        ], file: "RelatedDocumentsView.swift")
        // The app's entry for the pass: the reference at the standard tuning with the diplomatic layer in the verdict's form,
        // and the bundled stop lists, which the server's gives with the family's references and the web's tagger (S29g).
        NoteViewParityTests.expect(try ProjectHistoryParityTests.app("RelatedDocuments/SemanticSharedTerms+App.swift"), holds: [
            "let tuning = WordCloudTuning.standard",
            "guard case .available(let reference) = BundledKeynessBaseline.baseline( for: lens, tuning: tuning, includeDiplomatic: true, languageAnalysis: languageAnalysis)",
            "reference: reference, stopwords: WordCloudStopwords.shared, tagger: NaturalLanguageWordCloudTagger())",
        ], file: "SemanticSharedTerms+App.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/RelatedDocuments.swift"), holds: [
            "static let defaultLimit = 30",
            "let dates = (try? await served.pipeline.documentDates(for: [(volumeId: anchor.volumeId, documentId: anchor.documentId)])) ?? [:]",
            "indexDate.flatMap { Int($0.prefix(4)) } ?? doorYear",
            "let members = resources.manifest.filter { $0.subseries == key }.map(\\.volumeId) return members.isEmpty ? nil : Set(members)",
            "var scopes: [RelatedScope] = [.volume] if let key = subseriesKey(of: volumeId, resources: resources), resources.manifest.filter({ $0.subseries == key }).count > 1 { scopes.append(.subseries) } scopes.append(.all)",
            "let scored = rows.indices.filter { rows[$0].axisScores[.sharedSubjects] != nil }",
            "let names = subjects.sharedSubjectNames(anchor: anchor, candidates: scored.map { rows[$0].key })",
            #"rows[index].axisEvidenceLabel[.sharedSubjects] = found.joined(separator: "\u{1F}")"#,
            "cut > result.totalBeforeLimit ? RelatedDocumentsCounts.poolCut(",
            "static let offIndexVolumeDisplayLimit = 5",
            "guard leads.documentCount > 0 else { return nil }",
            "volumes: leads.volumes.prefix(offIndexVolumeDisplayLimit).map {",
            "moreVolumes: leads.volumes.count > offIndexVolumeDisplayLimit ? RelatedDocumentsCounts.offIndexMoreVolumes(leads.volumes.count - offIndexVolumeDisplayLimit, locale: locale) : nil)",
            "semanticScore: row.axisScores[.semanticSimilarity],",
            "verdict: row.axisScores[.semanticSimilarity] == nil ? nil : verdict?.rawValue)",
            "resources.familyClouds.stopwords(in: resources.directory).active(includeDiplomatic: true)",
            // The shared words after the subjects (S29g), as the app's view names them.
            "let rows = await namingSharedTerms(namingSharedSubjects(result.rows, anchor: anchor, subjects: subjects), anchor: anchor,",
        ], file: "RelatedDocuments.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/RelatedSharedTerms.swift"), holds: [
            "static let vocabularyAxes: [SimilarityAxis] = [.semanticSimilarity, .lexicalSimilarity]",
            "let scoredRows = rows.filter { row in vocabularyAxes.contains { row.axisScores[$0] != nil } } guard !scoredRows.isEmpty else { return rows }",
            #"guard !evidence.terms.isEmpty else { return rows } var rows = rows for index in rows.indices { guard let found = evidence.terms[rows[index].key], !found.isEmpty else { continue } for axis in vocabularyAxes where rows[index].axisScores[axis] != nil { rows[index].axisEvidenceLabel[axis] = found.joined(separator: "\u{1F}") } }"#,
            "(resources.familyClouds.stopwords(in: resources.directory), resources.familyClouds.references(language: resources.languageDirectory, lists: resources.directory))",
            "languageAnalysis: tagger.health, stopwords: lists.stopwords, tagger: tagger, isolation: nil)",
        ], file: "RelatedSharedTerms.swift")
        // The verdicts' log, its file and its screen (S26d): the app's, and the server's mirror.
        let log = try ProjectHistoryParityTests.app("Semantic/SemanticFeedbackLog.swift")
        NoteViewParityTests.expect(log, holds: [
            "private let maxEntries = 2_000",
            "rows.removeAll { $0.anchor == entry.anchor && $0.neighbour == entry.neighbour } rows.append(entry) if rows.count > maxEntries { rows.removeFirst(rows.count - maxEntries) }",
            "for row in rows { eras[row.era ?? \"unknown\", default: 0] += 1 }",
            "helpful: rows.filter { $0.verdict == .helpful }.count, byEra: eras.map { (era: $0.key, count: $0.value) }.sorted { $0.era < $1.era })",
            "try? SemanticFeedbackEntry.exportData(loaded())",
            "func entries() -> [SemanticFeedbackEntry] { loaded() }",
        ], file: "SemanticFeedbackLog.swift")
        let screen = try ProjectHistoryParityTests.app("Settings/SemanticFeedbackView.swift")
        NoteViewParityTests.expect(screen, holds: [
            "static let address = \"feedback@frusexplorer.app\"", "static let fileName = \"frus-semantic-feedback.json\"",
            "guard let value = Int(raw), let era = CoverageEra(rawValue: value) else { return String(localized: \"settings.semanticFeedback.era.unknown\", defaultValue: \"Undated anchor\") } return era.label",
            ".disabled((summary?.total ?? 0) == 0)",
        ], file: "SemanticFeedbackView.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/SemanticFeedback.swift"), holds: [
            "static let fileName = \"frus-semantic-feedback.json\"", "static let address = \"feedback@frusexplorer.app\"",
            "static let undatedAnchor = \"Undated anchor\"",
            "era: year.map { CoverageEra.bucket(year: $0).rawValue.description }, sameVolume: neighbour.volumeId == anchor.volumeId, provenanceDigest: bundle.provenance.digestHex)",
            "for row in rows { eras[row.era ?? \"unknown\", default: 0] += 1 }",
            "helpful: rows.filter { $0.verdict == .helpful }.count, byEra: eras.map { (era: $0.key, count: $0.value) }.sorted { $0.era < $1.era }",
            "guard let value = Int(raw), let era = CoverageEra(rawValue: value) else { return undatedAnchor } return era.label",
            "let file = try SemanticFeedbackEntry.exportData(entries)",
        ], file: "SemanticFeedback.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.server("Sources/FRUSLightCore/UserSemanticFeedback.swift"), holds: [
            "public static let semanticFeedbackLimit = 2_000",
            "_ = try db.query(\"DELETE FROM semantic_feedback WHERE user_id = ? AND anchor = ? AND neighbour = ?\",",
            "SELECT rowid FROM semantic_feedback WHERE user_id = ? ORDER BY rowid DESC LIMIT ?)",
        ], file: "UserSemanticFeedback.swift")
        // The leads' seed, tuning and constants: the app's service and the server's mirror.
        let service = try ProjectHistoryParityTests.app("ProjectContext/ProjectLeadsService.swift")
        NoteViewParityTests.expect(service, holds: [
            "static let seedCap = 40", "static let perSeedRelatedLimit = 30", "static let leadLimit = 24",
            "let base = stored.flatMap { AxisWeights(rawValue: $0) } ?? .default",
            "merged[axis] = base.weights[axis] ?? axis.defaultWeight",
            "where entry.kind == CollectionEntryKind.document.rawValue && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {",
            ".filter { $0.projectIds.contains(projectId) && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }",
            "guard !focusTags.isEmpty else { return [] }",
            "where focusTags.contains(assignment.tagId) && !assignment.volumeId.isEmpty && !assignment.documentId.isEmpty {",
            "where !Set(note.userTagIds).isDisjoint(with: focusTags) && !note.volumeId.isEmpty && !note.documentId.isEmpty {",
            ".union(noteSeedKeys(forProject: projectId, in: context)) .union(taggedSeedKeys(forTags: focusTags, in: context)) return (seed.sorted(), raw)",
            "for seedKey in seedKeys.prefix(seedCap) {",
            "anchor: anchor, anchorYear: nil, weights: weights, scopeVolumeIds: nil, limit: perSeedRelatedLimit, includeSnippets: false, includeOffIndexLeads: false, appState: appState)",
            "perSeedRelated: perSeed, seedKeys: seedSet, dismissedKeys: dismissedKeys, limit: leadLimit)",
            "clearVisibleLeads(forProject: projectId, in: context) return .none",
            "if !entry.dismissed { entry.aggregateScore = candidate.aggregateScore entry.contributingSeedKeys = candidate.contributingSeedKeys if let record {",
            "for entry in existing where !candidateKeys.contains(entry.documentKey) { context.delete(entry) }",
            // The reach (S26d): the seed's first forty, at the leads' tuning.
            "let reach = await SemanticProjectReach.reach( seedKeys: Array(seedKeys.prefix(seedCap)), weights: weights, appState: appState)",
        ], file: "ProjectLeadsService.swift")
        let home = try ProjectHistoryParityTests.app("ProjectContext/ProjectHomeView.swift")
        NoteViewParityTests.expect(home, holds: [
            "leadsSection beyondLibrarySection recentSection",
            "if !reach.isEmpty {", "ForEach(reach.volumes, id: \\.volumeID) { lead in",
        ], file: "ProjectHomeView.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/ProjectReach.swift"), holds: [
            "SemanticProjectReach.reach(seedKeys: Array(seed.prefix(ProjectLeadsSeed.seedCap)), weights: weights, host: host)",
            "let weights = ProjectLeadsSeed.effectiveWeights(projectRaw: project.leadAxisWeights, browserRaw: browserWeights)",
        ], file: "ProjectReach.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/ProjectLeads.swift"), holds: [
            "static let seedCap = 40", "static let perSeedRelatedLimit = 30", "static let leadLimit = 24",
            "let base = stored.flatMap { AxisWeights(rawValue: $0) } ?? .default",
            "merged[axis] = base.weights[axis] ?? axis.defaultWeight",
            "guard !focusTags.isEmpty else { return [] }",
            "let ranked = Array(seed.prefix(ProjectLeadsSeed.seedCap))",
            "anchor: anchor, anchorYear: nil, weights: weights, scopeVolumeIds: nil, limit: ProjectLeadsSeed.perSeedRelatedLimit, includeSnippets: false, includeOffIndexLeads: false,",
            "ProjectLeadsAggregator.aggregate(perSeedRelated: perSeed, seedKeys: Set(seed), dismissedKeys: dismissed, limit: ProjectLeadsSeed.leadLimit)",
        ], file: "ProjectLeads.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.web("related/relatedRules.ts"), holds: [
            "return row.header === '' ? row.documentId : row.header;",
            "return scope === 'all' ? copy.related.emptyDetail : copy.related.emptyDetailScoped;",
            "return totalBeforeLimit > shown ? copy.related.overflow(totalBeforeLimit - shown) : undefined;",
        ], file: "relatedRules.ts")
    }

    /// The app's words the browser app takes, where the app's source writes each under its key, and in
    /// copy.ts's block.
    @Test func theAppsWordsAreTheWebs() throws {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let related = try NoteViewParityTests.block("related", of: raw)
        let home = try NoteViewParityTests.block("projectHome", of: raw)
        let view = try ProjectHistoryParityTests.app("RelatedDocuments/RelatedDocumentsView.swift")
        let row = try ProjectHistoryParityTests.app("RelatedDocuments/AxisWeightRow.swift")
        let rail = try ProjectHistoryParityTests.app("DocumentView/ResearchRailView.swift")
        let projectHome = try ProjectHistoryParityTests.app("ProjectContext/ProjectHomeView.swift")
        let words: [(source: String, file: String, key: String, value: String, block: String, web: String)] = [
            (view, "RelatedDocumentsView", "related.title", "Related Documents", related, "title: 'Related Documents'"),
            (rail, "ResearchRailView", "researchRail.tile.related", "Related", related, "tile: 'Related'"),
            (view, "RelatedDocumentsView", "related.scope.label", "Scope", related, "scope: 'Scope'"),
            (view, "RelatedDocumentsView", "related.scope.volume", "This volume", related, "volume: 'This volume'"),
            (view, "RelatedDocumentsView", "related.scope.subseries", "This subseries", related, "subseries: 'This subseries'"),
            (view, "RelatedDocumentsView", "related.scope.all", "All volumes", related, "all: 'All volumes'"),
            (view, "RelatedDocumentsView", "related.weights.label", "Adjust weights", related, "weights: 'Adjust weights'"),
            (view, "RelatedDocumentsView", "related.weights.reset", "Reset to app defaults", related, "reset: 'Reset to app defaults'"),
            (view, "RelatedDocumentsView", "related.preparingIndex", "Preparing your index…", related, "preparing: 'Preparing your index…'"),
            (view, "RelatedDocumentsView", "related.empty", "No Related Documents", related, "empty: 'No Related Documents'"),
            (view, "RelatedDocumentsView", "related.empty.detail",
             "No indexed documents share this document’s archival provenance or cross-references — indexing more volumes may surface some.", related,
             "emptyDetail: 'No indexed documents share this document’s archival provenance or cross-references — indexing more volumes may surface some.'"),
            (view, "RelatedDocumentsView", "related.empty.detail.scoped",
             "No related documents in this scope — switch to All volumes to search the whole index.", related,
             "emptyDetailScoped: 'No related documents in this scope — switch to All volumes to search the whole index.'"),
            (projectHome, "ProjectHomeView", "project.home.leads.refresh", "Refresh", home, "leadsRefresh: 'Refresh'"),
            (projectHome, "ProjectHomeView", "project.home.leads.computing", "Finding leads…", home, "leadsComputing: 'Finding leads…'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(word.block.contains(word.web), "copy.ts holds \(word.web)")
        }
        // The tile's help and the overflow line, which the app writes over several lines or with its count.
        #expect(rail.contains(#"defaultValue: "Find related documents by archival provenance, cross-references, date, and shared people")"#))
        #expect(related.contains("tileHelp: 'Find related documents by archival provenance, cross-references, date, and shared people'"))
        #expect(view.contains(#"defaultValue: "%lld more related — raise a weight or narrow the scope to refine.")"#))
        #expect(related.contains("overflow: (count: number) => `${count} more related — raise a weight or narrow the scope to refine.`"))
        // The slider's word for a missing subject index, said of the server where the app says the device, in the words
        // the app's subject data has had since FRUS-Explorer#1930.
        #expect(row.contains(#"defaultValue: "Subject data is unavailable on this device.")"#))
        #expect(related.contains("subjectsUnavailable: 'Subject data is unavailable on this server.'"))

        // S26d's: the two experimental axes' captions, the verdicts' menu, Beyond your library's header and its row for a
        // document, the reach's header, caption and rows, and Settings ▸ Data's Semantic Match Feedback.
        let search = try ProjectHistoryParityTests.app("Search/SemanticSearchSharedViews.swift")
        let screen = try ProjectHistoryParityTests.app("Settings/SemanticFeedbackView.swift")
        let feedback = try NoteViewParityTests.block("semanticFeedback", of: raw)
        let more: [(source: String, file: String, key: String, value: String, block: String, web: String)] = [
            (view, "RelatedDocumentsView", "related.semantic.helpful", "Semantic match: helpful", related, "helpful: 'Semantic match: helpful'"),
            (view, "RelatedDocumentsView", "related.semantic.notHelpful", "Semantic match: not useful", related,
             "notHelpful: 'Semantic match: not useful'"),
            (view, "RelatedDocumentsView", "related.offIndex.header", "Beyond your library", related, "beyond: 'Beyond your library'"),
            (view, "RelatedDocumentsView", "related.weights.semantic.off",
             "Off. Raise it to also match documents whose meaning an AI model measured as alike, even when they share no words, citations or archive. Experimental, and untested on nineteenth-century prose.",
             related,
             "semanticOff: 'Off. Raise it to also match documents whose meaning an AI model measured as alike, even when they share no words, citations or archive. Experimental, and untested on nineteenth-century prose.'"),
            (view, "RelatedDocumentsView", "related.weights.semantic.on",
             "Matches carry a “Semantic match” score. Consider providing feedback to say whether it helped. Those verdicts are how this axis gets judged.",
             related,
             "semanticOn: 'Matches carry a “Semantic match” score. Consider providing feedback to say whether it helped. Those verdicts are how this axis gets judged.'"),
            (projectHome, "ProjectHomeView", "project.reach.header", "Beyond your library", home, "reachTitle: 'Beyond your library'"),
            (screen, "SemanticFeedbackView", "settings.semanticFeedback.title", "Semantic Match Feedback", feedback, "title: 'Semantic Match Feedback'"),
            (screen, "SemanticFeedbackView", "settings.semanticFeedback.about.header", "About this experiment", feedback,
             "aboutHeader: 'About this experiment'"),
            (screen, "SemanticFeedbackView", "settings.semanticFeedback.how.header", "How to give feedback", feedback,
             "howHeader: 'How to give feedback'"),
            (screen, "SemanticFeedbackView", "settings.semanticFeedback.total", "Verdicts recorded", feedback, "total: 'Verdicts recorded'"),
            (screen, "SemanticFeedbackView", "settings.semanticFeedback.helpful", "Marked helpful", feedback, "helpful: 'Marked helpful'"),
            (screen, "SemanticFeedbackView", "settings.semanticFeedback.clear", "Clear Recorded Feedback", feedback,
             "clear: 'Clear Recorded Feedback'"),
            (screen, "SemanticFeedbackView", "settings.semanticFeedback.clear.confirmAction", "Delete Feedback", feedback,
             "clearAction: 'Delete Feedback'"),
        ]
        for word in more {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(word.block.contains(word.web), "copy.ts holds \(word.web)")
        }
        // The lexical axis's caption, of this server where the app's speaks of this device.
        for (key, value) in [
            ("related.weights.lexical.off", "Off. Raise it to also match documents that reuse this one’s distinctive wording. Experimental; searches only the volumes indexed on this device, so results vary with your library."),
            ("related.weights.lexical.on", "Matches share this document’s distinctive wording. Searches only the volumes indexed on this device, so results vary with your library."),
        ] {
            #expect(NoteViewParityTests.writes(view, key, value), "RelatedDocumentsView writes \(key)")
            let server = value.replacingOccurrences(of: "on this device, so results vary with your library", with: "on this server, so results vary with its library")
            #expect(related.contains(": '\(server)'"), "copy.ts holds \(server)")
        }
        // A document named beyond the library: the app's search row's words, its volume on no server where the app's is not
        // downloaded, and no download to wait for.
        #expect(search.contains(#"defaultValue: "Document %1$@ in %2$@")"#))
        #expect(related.contains("beyondDocument: (documentId: string, volumeTitle: string) => `Document ${documentId} in ${volumeTitle}`"))
        #expect(NoteViewParityTests.writes(search, "search.semantic.row.notDownloaded",
                                           "Volume not downloaded — its documents are shown without titles until you download it."))
        #expect(related.contains("beyondNotServed: 'Volume not on this server — its documents are shown without titles.'"))
        // The reach's caption and a volume's line, of the volumes this server does not serve where the app's speaks of those
        // not downloaded, and of this server where it speaks of this device, with a count of one said in the singular, as
        // the kit's Beyond your library says it since #1618.
        #expect(projectHome.contains("%lld documents in volumes you have not downloaded read as close to one of this \\ project's %lld documents as that document's nearest neighbours already on this device."))
        #expect(home.contains("reachCaption: (documents: number, seeds: number) => `${documents.toLocaleString('en-US')} ${documents === 1 ? 'document' : 'documents'} in volumes this server does not serve ${documents === 1 ? 'reads' : 'read'} as close to one of this project's ${seeds.toLocaleString('en-US')} ${seeds === 1 ? 'document' : 'documents'} as that document's nearest neighbours on this server.`"))
        #expect(projectHome.contains(#"defaultValue: "%lld documents · reached from %lld of yours")"#))
        #expect(home.contains("reachVolume: (documents: number, seeds: number) => `${documents.toLocaleString('en-US')} ${documents === 1 ? 'document' : 'documents'} · reached from ${seeds.toLocaleString('en-US')} of yours`"))
        // Semantic Match Feedback's prose, the app's paragraphs, which it writes over several lines.
        func continued(_ text: String) -> String { text.replacingOccurrences(of: " \\ ", with: " ") }
        let what = "The “Semantically similar (experimental)” axis in Related Documents finds documents by an AI model’s scoring of the meaning of their language rather than by citations or archival provenance. It contributes to every Related Documents list unless you lower its weight there. It is still experimental: how well it works on nineteenth-century material is not established, which is what the verdicts below are for."
        let unknown = "What we do not know is how good it is before 1900. The automatic check we can run relies on the editors’ cross-references, and that citation style only becomes common after 1945 — so it reaches barely 500 early documents out of the whole corpus. Nineteenth-century volumes are exactly where this axis is meant to help most, and exactly where nothing has measured it."
        #expect(continued(screen).contains(what) && feedback.contains("what: '\(what)'"))
        #expect(continued(screen).contains(unknown) && feedback.contains("unknown: '\(unknown)'"))
        // How to give one, by the web's menu where the app's is a long press on a row with the magnifier, which the web has
        // not; the verdicts kept with the user's account, where the app keeps them on the device.
        #expect(continued(screen).contains("Long-press (or right-click) any related document that shows the magnifier icon, then choose whether the match was helpful. Nineteenth-century verdicts are worth the most."))
        #expect(feedback.contains("how: 'Open the Feedback menu of any related document that shows a Semantic match score, then choose whether the match was helpful. Nineteenth-century verdicts are worth the most.'"))
        #expect(NoteViewParityTests.writes(screen, "settings.semanticFeedback.recorded.header", "Recorded on this device"))
        #expect(feedback.contains("recordedHeader: 'Recorded with your account'"))
        #expect(NoteViewParityTests.writes(screen, "settings.semanticFeedback.clear.confirm", "Delete every recorded verdict on this device?"))
        #expect(feedback.contains("clearConfirm: 'Delete every recorded verdict on this server?'"))
        // The file, which a browser saves where the app prepares it to share; and the footer, the app's but for where the
        // verdicts are kept and how the file is had.
        #expect(NoteViewParityTests.writes(screen, "settings.semanticFeedback.export", "Prepare Feedback File"))
        #expect(feedback.contains("download: 'Download Feedback File'"))
        #expect(continued(screen).contains("Stored on-device and not synced to iCloud. Each verdict records the two documents, your judgement, the match score, which release of the vectors it applies to, and when you made it. The app shares none of this on its own: to contribute your verdicts, choose Prepare Feedback File, then send the file to"))
        #expect(feedback.contains("footer: (address: string) => `Kept on this server with your account, and in no research export. Each verdict records the two documents, your judgement, the match score, which release of the vectors it applies to, and when you made it. The server shares none of this on its own: to contribute your verdicts, choose Download Feedback File, then send the file to ${address}.`"))
    }
}
