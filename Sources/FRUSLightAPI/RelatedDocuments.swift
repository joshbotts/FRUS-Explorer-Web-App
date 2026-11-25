// Related Documents (PLAN's S23d): the documents related to one, ranked by the kit's engine,
// `RelatedDocumentsEngine.rank(…dependencies:)` (FRUS-Explorer#1872), over the served index and the
// server's data files, with the app's weights, scope and "why related" chips. The engine, its model, its
// weights' stored form and its chips' words are the kit's, compiled from the submodule. What the app's
// view and request do around the engine is mirrored here and held to their source by
// `RelatedDocumentsParityTests`: the anchor's year read from the index
// (`RelatedDocumentsRequest.resolvedAnchorYear(pipeline:)`), the scopes the picker offers and the volumes
// each stands for (`RelatedDocumentsContent.availableScopes`, `NeighborScope.resolveVolumeIds(appState:)`),
// and the subjects named on the rows shown (`RelatedDocumentsContent.attachSubjectEvidence()`). A row's line
// prefers its reader's summary, as the app's does: the engine reads it from the rows of the user the request
// searches as in the store the served index attaches, or from the index's own for no one (FRUS-Explorer#1907).
//
// The cross-reference axis ranks by the kit's `CrossReferenceStore` (FRUS-Explorer#1891) over the served
// index, since S23c's pin move, as the app's ranks by its `appState.crossReferenceStore`. Since PLAN's S26d
// all eight of the app's axes rank here. The lexical axis, which ships at weight 0 and then skips its
// generation, has the served index's search service and WordCloudKit's stop words, the word cloud's with the
// diplomatic list, which its query terms are chosen past, as the app's engine dependencies give them: S24e's
// follow-up, which rides with S26d. And the semantic axis is the kit's source, `SemanticVectorsSimilaritySource`
// (FRUS-Explorer#1980), over a host of the server's (`ServedSemantics`): the bundled tier, the image's shards
// through the server's `SemanticVectors` (S26c), and the served index's volumes and pipeline. Its candidates come
// from the bundled sign bits, fenced to the served volumes inside the scan, scored by exact int8 cosine against the
// shards and calibrated by the generation's document offset, and the other axes' candidates are re-scored; one
// whose shard the server lacks is dropped, never ranked by Hamming, and its volume is counted, as the request for
// a shard it is (the image holds every shard, so a server has none to fetch). Beyond your library, the off-index
// section the engine has always computed, is sent: the volumes the server does not serve that hold near
// documents, from the sign bits alone, and the documents it can name and score where both shards are held, in
// the kit's captions; each volume's page in Browse stands where the app offers a download. The section's view
// rules, its five volumes and its row for a document, are the app's `RelatedDocumentsContent` and
// `SemanticUndownloadedRow`, mirrored. Each row says its semantic score, `axisScores[.semanticSimilarity]`, which a
// verdict on it records (SemanticFeedback.swift), and the verdict the request's user gave it.
//
// Since PLAN's S29g a row matched by meaning or by wording says what it shares with the anchor, in the kit's chip,
// "shares: …", as the app's view says it once its pass over the rows shown has run: the kit's `SemanticSharedTerms` with
// the language family's reference and the web's tagger, off the main actor (RelatedSharedTerms.swift).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import SemanticVectorsKit

/// Related Documents for one document, as the app's list shows them.
public struct RelatedDocuments: Codable, Equatable, Sendable, ResponseEncodable {
    public var volumeId: String
    public var documentId: String
    /// The scope ranked over: `volume`, `subseries` or `all`.
    public var scope: String
    /// The scopes the app's picker offers for this document, in its order: `volume`, `subseries` when the
    /// volume's subseries has another volume in the catalogue, and `all`.
    public var scopes: [String]
    /// The tuning ranked with, in the app's stored form (`AxisWeights.rawValue`): its departures from the
    /// defaults, `""` for none.
    public var weights: String
    /// Each of the app's eight axes, in its order.
    public var axes: [Axis]
    /// The ranked rows, the most related first.
    public var rows: [Row]
    /// How many documents scored above 0 before the list was cut to its length: the app's "N more related".
    public var totalBeforeLimit: Int
    /// The footer under a list whose archival pool was cut (`RelatedDocumentsCounts.poolCut`), when the
    /// pool held more than scored.
    public var poolCut: String?
    /// What the semantic axis saw in volumes this server does not serve (the app's Beyond your library), when it
    /// saw any.
    public var beyondLibrary: BeyondLibrary?
    /// The volumes whose shard the semantic axis asked for and this server does not hold, sorted: its candidates in
    /// them were dropped, never ranked by Hamming. None while the image holds every shard.
    public var missingShards: [String]

    public struct Axis: Codable, Equatable, Sendable {
        /// Its stored name (`SimilarityAxis.rawValue`), which the weights' string keys it by.
        public var id: String
        /// Its name in the app's words (`SimilarityAxis.displayName`).
        public var name: String
        /// Its weight in this tuning.
        public var weight: Double
        public var defaultWeight: Double
        /// Whether it can contribute on this server: every axis, but shared subjects on a server whose data files
        /// hold no document subject index, as the app's slider says on a device without one, and the semantic axis on
        /// one whose bundled vectors are refused (S26c).
        public var available: Bool
    }

    public struct Row: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// Its head as the index holds it, which may be empty: the app's row then shows the document's id.
        public var header: String
        public var dateline: String?
        public var documentNumber: String?
        public var isEditorialNote: Bool
        /// Its total proximity, the weighted sum of its axes' scores.
        public var score: Double
        /// The opening of the reader's summary of it, else of its text in the served index, as the kit reads
        /// it for the rows shown.
        public var snippet: String?
        /// The "why related" chips, strongest first (`RelatedDocumentRow.whyRelatedChips`).
        public var chips: [Chip]
        /// The semantic axis's score of it, the calibrated cosine the ranking read (`axisScores[.semanticSimilarity]`),
        /// when that axis scored it: only such a row carries the app's two verdicts, as only it carries its menu.
        public var semanticScore: Double?
        /// The verdict the request's user gave on it, `helpful` or `notHelpful`, if any.
        public var verdict: String?
    }

    public struct Chip: Codable, Equatable, Sendable {
        /// The axis's stored name.
        public var axis: String
        /// The axis's name, which a screen reader is given before the chip's words, as the app's label is.
        public var name: String
        /// The chip's words (`WhyRelatedChip.displayText(locale:)`), in US English.
        public var text: String
    }

    /// Beyond your library (S-3), as the app's `RelatedDocumentsContent.offIndexSection` shows it.
    public struct BeyondLibrary: Codable, Equatable, Sendable {
        /// The section's opening sentence (`RelatedDocumentsCounts.offIndexCaption`), "At least …" when the scan's cap
        /// bound.
        public var caption: String
        /// The documents at or nearer than the anchor's own band, and the volumes holding them.
        public var documentCount: Int
        public var volumeCount: Int
        public var isCapped: Bool
        /// Up to five documents named and scored, where the anchor's shard and their volume's are held, best first.
        public var documents: [Document]
        /// The first five volumes, most matches first.
        public var volumes: [Volume]
        /// The line under them for the volumes they leave out (`RelatedDocumentsCounts.offIndexMoreVolumes`).
        public var moreVolumes: String?
    }

    public struct Document: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// The volume's title in the catalogue, or its id.
        public var volumeTitle: String
        /// The calibrated cosine, on the ranked rows' scale.
        public var score: Double
        /// Its chip, the kit's `evidenceLabel(for:)`: "Semantic match · 82%", as the app's `SemanticScoreChip` words it.
        public var chip: String
        /// Whether this server serves its volume. A scoped list's leads look past its scope, the kit's scan counting a
        /// volume outside the scope as not held (`SemanticSimilarityGenerator.offIndexSection`), so a document of another
        /// volume the server serves is named here too; the browser opens it, where it says of the others that their
        /// volume is not on this server. The app's section words both as not downloaded.
        public var served: Bool
    }

    public struct Volume: Codable, Equatable, Sendable {
        public var volumeId: String
        /// Its title in the catalogue, or its id.
        public var title: String
        public var count: Int
        /// Its count in the kit's words (`RelatedDocumentsCounts.offIndexVolumeCount`).
        public var countText: String
    }
}

/// A scope of the app's picker (`NeighborScope`), by the name the API gives it.
enum RelatedScope: String, CaseIterable, Sendable {
    case volume, subseries, all
}

enum RelatedDocumentsRoutes {
    /// How many rows a list shows (`RelatedDocumentsRequest.defaultLimit`).
    static let defaultLimit = 30
    /// The longest list the API gives: the engine's candidate pool floor, past which a longer list ranks a
    /// deeper pool than the app's does.
    static let maximumLimit = 120
    /// The locale the chips' words and their counts are written in, as the server's other words are.
    static let locale = Locale(identifier: "en_US")
    /// How many volumes Beyond your library names before its line for the rest (`offIndexVolumeDisplayLimit`).
    static let offIndexVolumeDisplayLimit = 5

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources,
                    users: SearchUsers, vectors: SemanticVectors) {
        router.get("/api/v1/volumes/:volumeId/documents/:documentId/related") { request, context -> RelatedDocuments in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["scope", "weights", "limit"])
            let volumeId = try context.parameters.require("volumeId")
            let documentId = try context.parameters.require("documentId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            guard documentId.utf8.count <= 256, FRUSURLScheme.isSafeComponent(documentId) else {
                throw APIProblem.invalidParameter("documentId", "\(documentId) is not a document's id.")
            }
            let scope = try query.choice("scope", among: RelatedScope.allCases) ?? .all
            let weights = try requestedWeights(try query.single("weights"))
            let limit = try query.integer("limit", in: 1...maximumLimit, default: defaultLimit)
            let offered = scopes(for: volumeId, resources: resources)
            guard offered.contains(scope) else {
                throw APIProblem(.badRequest, code: "SCOPE_NOT_OFFERED",
                                 detail: "\(volumeId) is in no subseries with another volume of the catalogue, so its related documents have no subseries scope.")
            }
            let served = try await provider.served()
            let summaries = try await users.summarySource(for: request, context: context, served: served)
            // The subject index is 6 MB of JSON, decoded once, off the cooperative pool, as the stop lists are.
            let (subjects, stopwords) = try await Blocking.run { (resources.documentSubjectIndex, lexicalStopwords(resources)) }
            let bundle = try? await vectors.bundle().get()
            let anchor = DocumentKey(volumeId: volumeId, documentId: documentId)
            let ranking = await ranked(anchor, scope: scope, weights: weights, limit: limit, summaries: summaries, served: served,
                                       resources: resources, subjects: subjects, stopwords: stopwords,
                                       vectors: bundle.map { (bundle: $0, shards: vectors) })
            let verdicts = try await users.semanticVerdicts(on: anchor, for: request, context: context)
            return answer(anchor, scope: scope, offered: offered, weights: weights, result: ranking.result, subjects: subjects,
                          semantic: bundle != nil, missingShards: ranking.missingShards, verdicts: verdicts,
                          servedVolumes: served.indexedVolumeIds, resources: resources)
        }
    }

    /// The tuning a request names, in the app's stored form, or the defaults for none. A string the kit
    /// cannot read, or a weight outside the app's sliders, is refused.
    static func requestedWeights(_ raw: String?) throws -> AxisWeights {
        guard let raw else { return .default }
        guard raw.utf8.count <= 1_024, let weights = AxisWeights(rawValue: raw) else {
            throw APIProblem.invalidParameter("weights", "\(raw) is not a tuning of the axes, as axis:weight pairs.")
        }
        for axis in SimilarityAxis.allCases where !(0...1).contains(weights[axis]) {
            throw APIProblem.invalidParameter("weights", "\(axis.rawValue)'s weight is \(weights[axis]), outside 0 to 1.")
        }
        return weights
    }

    /// The scopes the picker offers (`RelatedDocumentsContent.availableScopes`): this volume; this subseries,
    /// when the volume has a subseries with more than one volume the catalogue knows; and all volumes.
    static func scopes(for volumeId: String, resources: ServerResources) -> [RelatedScope] {
        var scopes: [RelatedScope] = [.volume]
        if let key = subseriesKey(of: volumeId, resources: resources),
           resources.manifest.filter({ $0.subseries == key }).count > 1 {
            scopes.append(.subseries)
        }
        scopes.append(.all)
        return scopes
    }

    /// The volume's non-empty subseries key (`anchorSubseriesKey`), or nil.
    static func subseriesKey(of volumeId: String, resources: ServerResources) -> String? {
        guard let key = resources.volume(volumeId)?.subseries, !key.isEmpty else { return nil }
        return key
    }

    /// The volumes a scope ranks over (`NeighborScope.resolveVolumeIds(appState:)`): nil for all of them;
    /// the document's own; or the catalogue's volumes of its subseries, nil when it names none.
    static func volumeIds(of scope: RelatedScope, anchorVolumeId: String, resources: ServerResources) -> Set<String>? {
        switch scope {
        case .all:
            return nil
        case .volume:
            return [anchorVolumeId]
        case .subseries:
            guard let key = subseriesKey(of: anchorVolumeId, resources: resources) else { return nil }
            let members = resources.manifest.filter { $0.subseries == key }.map(\.volumeId)
            return members.isEmpty ? nil : Set(members)
        }
    }

    /// The anchor's year as Related Documents ranks with it (`RelatedDocumentsRequest.anchorYear(indexDate:doorYear:)`):
    /// the year of the index's date for it, else the year the door read from its dateline, which no door of
    /// the web passes.
    static func anchorYear(indexDate: String?, doorYear: Int?) -> Int? {
        indexDate.flatMap { Int($0.prefix(4)) } ?? doorYear
    }

    /// The lexical axis's stop words (`WordCloudStopwords.active(includeDiplomatic: true)`): the word cloud's stop lists
    /// with the diplomatic one, decoded once, and none for a file missing or malformed, as the app's are.
    static func lexicalStopwords(_ resources: ServerResources) -> Set<String> {
        resources.familyClouds.stopwords(in: resources.directory).active(includeDiplomatic: true)
    }

    /// The engine's dependencies over the served index and the data files: the index's pipeline, its
    /// cross-reference and person stores, the document subject index, the catalogue's manifest, the served
    /// index's search service and the stop words for the lexical axis, and the semantic axis, `semantic`, the
    /// kit's source over the server's vectors (`ServedSemantics`), or none on a server whose vectors are refused.
    @MainActor
    static func dependencies(served: ServedIndex, resources: ServerResources, subjects: DocumentSubjectIndex?,
                             stopwords: Set<String>, semantic: (any SemanticSimilaritySource)?) -> RelatedDocumentsDependencies {
        RelatedDocumentsDependencies(
            indexingPipeline: served.pipeline,
            // The kit's store, opened read-only and immutable with the served stack (S23c's pin move).
            crossReferenceStore: served.crossReferences,
            personMentionStore: served.persons,
            documentSubjectIndex: subjects,
            manifestStore: ServedManifest(resources: resources),
            // The lexical axis's, the corpus's search, whose half of a user's is the index's own, which it never reads.
            searchService: served.service,
            indexedVolumeIds: served.indexedVolumeIds,
            lexicalStopwords: stopwords,
            semantic: semantic)
    }

    /// The anchor's related documents, as the app's list loads them: the anchor's year from the index, the
    /// scope's volumes and the kit's ranking, each row's line read from `summaries` where the reader has
    /// summarised its document, with the shared subjects of the rows shown named, and then the words the rows matched by
    /// meaning or by wording share with the anchor (S29g); and the volumes whose shard the semantic axis asked for, over
    /// `vectors`, the bundled generation and the server's shards, when they are served.
    @MainActor
    static func ranked(_ anchor: DocumentKey, scope: RelatedScope, weights: AxisWeights, limit: Int, summaries: SearchUserSource,
                       served: ServedIndex, resources: ServerResources, subjects: DocumentSubjectIndex?, stopwords: Set<String>,
                       vectors: (bundle: SemanticBundle, shards: any SemanticShardSource)?)
        async -> (result: RelatedDocumentsResult, missingShards: [String]) {
        let dates = (try? await served.pipeline.documentDates(for: [(volumeId: anchor.volumeId, documentId: anchor.documentId)])) ?? [:]
        let year = anchorYear(indexDate: dates[anchor.compositeString], doorYear: nil)
        let semantic = vectors.map { ServedSemantics(bundle: $0.bundle, shards: $0.shards, served: served) }
        let result = await RelatedDocumentsEngine.rank(
            anchor: anchor, anchorYear: year, weights: weights,
            scopeVolumeIds: volumeIds(of: scope, anchorVolumeId: anchor.volumeId, resources: resources),
            limit: limit, userSource: summaries,
            dependencies: dependencies(served: served, resources: resources, subjects: subjects, stopwords: stopwords,
                                       semantic: semantic?.source))
        // The two passes over the rows shown, in the app's order: the subjects, then the shared words, which tag, off this
        // actor (`namingSharedTerms`).
        let rows = await namingSharedTerms(namingSharedSubjects(result.rows, anchor: anchor, subjects: subjects), anchor: anchor,
                                           pipeline: served.pipeline, resources: resources)
        return (RelatedDocumentsResult(rows: rows, totalBeforeLimit: result.totalBeforeLimit, poolCutFrom: result.poolCutFrom,
                                       offIndexLeads: result.offIndexLeads),
                semantic?.missingShards ?? [])
    }

    /// `rows` with the subjects each shares with the anchor named, for its shared-subjects chip, on the rows
    /// that axis scored (`attachSubjectEvidence()`): the subject index's names, most distinctive first,
    /// joined as the kit's chip splits them.
    static func namingSharedSubjects(_ rows: [RelatedDocumentRow], anchor: DocumentKey,
                                     subjects: DocumentSubjectIndex?) -> [RelatedDocumentRow] {
        guard let subjects else { return rows }
        var rows = rows
        let scored = rows.indices.filter { rows[$0].axisScores[.sharedSubjects] != nil }
        guard !scored.isEmpty else { return rows }
        let names = subjects.sharedSubjectNames(anchor: anchor, candidates: scored.map { rows[$0].key })
        guard !names.isEmpty else { return rows }
        for index in scored {
            guard let found = names[rows[index].key], !found.isEmpty else { continue }
            rows[index].axisEvidenceLabel[.sharedSubjects] = found.joined(separator: "\u{1F}")
        }
        return rows
    }

    /// Whether an axis can contribute on this server: shared subjects with the subject index, the semantic axis with
    /// the bundled vectors (`semantic`), and every other axis always.
    static func isAvailable(_ axis: SimilarityAxis, subjects: DocumentSubjectIndex?, semantic: Bool) -> Bool {
        switch axis {
        case .semanticSimilarity: semantic
        case .sharedSubjects: subjects != nil
        case .archivalProvenance, .crossReference, .dateProximity, .subseries, .sharedPersons, .lexicalSimilarity: true
        }
    }

    static func answer(_ anchor: DocumentKey, scope: RelatedScope, offered: [RelatedScope], weights: AxisWeights,
                       result: RelatedDocumentsResult, subjects: DocumentSubjectIndex?, semantic: Bool, missingShards: [String],
                       verdicts: [String: SemanticFeedbackEntry.Verdict], servedVolumes: Set<String>,
                       resources: ServerResources) -> RelatedDocuments {
        RelatedDocuments(
            volumeId: anchor.volumeId, documentId: anchor.documentId, scope: scope.rawValue,
            scopes: offered.map(\.rawValue), weights: weights.rawValue,
            axes: SimilarityAxis.allCases.map { axis in
                .init(id: axis.rawValue, name: axis.displayName, weight: weights[axis], defaultWeight: axis.defaultWeight,
                      available: isAvailable(axis, subjects: subjects, semantic: semantic))
            },
            rows: result.rows.map { row($0, verdict: verdicts[$0.key.compositeString]) },
            totalBeforeLimit: result.totalBeforeLimit,
            // The app's footer, shown only when the pool held more than scored.
            poolCut: result.poolCutFrom.flatMap { cut in
                cut > result.totalBeforeLimit ? RelatedDocumentsCounts.poolCut(ranked: result.totalBeforeLimit, of: cut, locale: locale) : nil
            },
            beyondLibrary: beyondLibrary(result.offIndexLeads, resources: resources, served: servedVolumes),
            missingShards: missingShards)
    }

    static func row(_ row: RelatedDocumentRow, verdict: SemanticFeedbackEntry.Verdict? = nil) -> RelatedDocuments.Row {
        RelatedDocuments.Row(
            volumeId: row.volumeId, documentId: row.documentId, header: row.record.header, dateline: row.record.dateline,
            documentNumber: row.record.documentNumber, isEditorialNote: row.record.isEditorialNote, score: row.totalScore,
            snippet: row.snippet.flatMap { $0.isEmpty ? nil : $0 },
            chips: row.whyRelatedChips.map { axis, chip in
                .init(axis: axis.rawValue, name: axis.displayName, text: chip.displayText(locale: locale))
            },
            semanticScore: row.axisScores[.semanticSimilarity],
            verdict: row.axisScores[.semanticSimilarity] == nil ? nil : verdict?.rawValue)
    }

    /// Beyond your library as the app's section shows it (`offIndexSection`), shown only when the scan found a
    /// document (`offIndexLeads.documentCount > 0`): the kit's sentence, the documents it named, the first
    /// `offIndexVolumeDisplayLimit` volumes each with its count in the kit's words, and the kit's line for the rest; each
    /// document named says whether `served`, the volumes this server serves, holds it.
    static func beyondLibrary(_ leads: SemanticOffIndexLeads, resources: ServerResources,
                              served: Set<String>) -> RelatedDocuments.BeyondLibrary? {
        guard leads.documentCount > 0 else { return nil }
        func title(_ volumeId: String) -> String { resources.volume(volumeId)?.title ?? volumeId }
        return RelatedDocuments.BeyondLibrary(
            caption: RelatedDocumentsCounts.offIndexCaption(documents: leads.documentCount, volumes: leads.volumes.count,
                                                            isCapped: leads.isCapped, locale: locale),
            documentCount: leads.documentCount, volumeCount: leads.volumes.count, isCapped: leads.isCapped,
            documents: leads.documents.map {
                .init(volumeId: $0.volumeID, documentId: $0.documentID, volumeTitle: title($0.volumeID), score: $0.score,
                      chip: SemanticSimilarityGenerator.evidenceLabel(for: $0.score), served: served.contains($0.volumeID))
            },
            volumes: leads.volumes.prefix(offIndexVolumeDisplayLimit).map {
                .init(volumeId: $0.volumeID, title: title($0.volumeID), count: $0.count,
                      countText: RelatedDocumentsCounts.offIndexVolumeCount($0.count, locale: locale))
            },
            moreVolumes: leads.volumes.count > offIndexVolumeDisplayLimit
                ? RelatedDocumentsCounts.offIndexMoreVolumes(leads.volumes.count - offIndexVolumeDisplayLimit, locale: locale) : nil)
    }
}

/// The semantic axis over the server's vectors for one ranking (PLAN's S26d): the kit's `SemanticVectorsSimilaritySource`
/// over a `SemanticSimilarityHost` of the bundled tier, the image's shards and the served index's volumes and pipeline,
/// each given as a value, since none changes while the stack is served; and the volumes whose shard a pass asked for
/// and the server did not hold. A server holds every shard it ever will, so it fetches none: it counts each, and the
/// answer names them.
@MainActor
final class ServedSemantics {
    /// The volumes a pass asked for, which the host's request writes here, on the main actor the passes run on.
    @MainActor final class ShardRequests {
        var volumes: Set<String> = []
    }

    let source: SemanticVectorsSimilaritySource
    /// The bundled generation's provenance digest, which a verdict names.
    let provenanceDigest: String
    private let requests = ShardRequests()

    init(bundle: SemanticBundle, shards: any SemanticShardSource, served: ServedIndex) {
        let requests = requests
        let (index, corpus, volumes, pipeline) = (bundle.index, bundle.corpus, served.indexedVolumeIds, served.pipeline)
        source = SemanticVectorsSimilaritySource(host: SemanticSimilarityHost(
            index: index, corpusVectors: corpus, shardStore: shards, indexedVolumeIds: volumes, indexingPipeline: pipeline,
            requestShard: { requests.volumes.insert($0) }))
        provenanceDigest = bundle.provenance.digestHex
    }

    /// The volumes whose shard a pass asked for, sorted.
    var missingShards: [String] { requests.volumes.sorted() }
}

/// The catalogue's manifest by volume id, which the corpus-proximity scorer reads a volume's subseries from,
/// as the app's `ManifestStore` answers it.
struct ServedManifest: VolumeManifestLookup {
    let resources: ServerResources

    func entry(forVolumeId id: String) -> VolumeManifestEntry? { resources.volume(id) }
}

/// The document subject index, `document-subject-index.json`, decoded the first time Related Documents or
/// Suggested Next ranks, as the app's `DocumentSubjectStore.shared` decodes it on first use: none for a file
/// missing or malformed, and the shared-subjects axis then contributes nothing, as the app's does.
final class DocumentSubjectIndexFile: @unchecked Sendable {
    /// The file's name among the app's data files.
    static let name = "document-subject-index.json"

    private let lock = NSLock()
    private var held: DocumentSubjectIndex??

    /// The index in `directory`, decoded once.
    func index(in directory: URL) -> DocumentSubjectIndex? {
        lock.lock()
        defer { lock.unlock() }
        if let held { return held }
        let url = directory.appendingPathComponent(Self.name)
        let index = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(DocumentSubjectIndex.self, from: $0) }
        held = .some(index)
        return index
    }
}
