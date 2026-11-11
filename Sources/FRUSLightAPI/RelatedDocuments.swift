// Related Documents (PLAN's S23d): the documents related to one, ranked by the kit's engine,
// `RelatedDocumentsEngine.rank(…dependencies:)` (FRUS-Explorer#1872), over the served index and the
// server's data files, with the app's weights, scope and "why related" chips. The engine, its model, its
// weights' stored form and its chips' words are the kit's, compiled from the submodule. What the app's
// view and request do around the engine is mirrored here and held to their source by
// `RelatedDocumentsParityTests`: the anchor's year read from the index
// (`RelatedDocumentsRequest.resolvedAnchorYear(pipeline:)`), the scopes the picker offers and the volumes
// each stands for (`RelatedDocumentsContent.availableScopes`, `NeighborScope.resolveVolumeIds(appState:)`),
// and the topics named on the rows shown (`RelatedDocumentsContent.attachSubjectEvidence()`).
//
// Three of the app's eight axes contribute nothing here, which the answer's `axes` says: the
// cross-reference axis until S23c's pin move brings the kit's `CrossReferenceStore` (FRUS-Explorer#1891),
// which S23c passes as `crossReferenceStore`; the lexical axis, which ships at weight 0 and then skips its
// generation, until S24d compiles WordCloudKit, whose stopwords its query terms are chosen past; and the
// semantic axis, which reads the bundled vectors, until phase 4.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

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

    public struct Axis: Codable, Equatable, Sendable {
        /// Its stored name (`SimilarityAxis.rawValue`), which the weights' string keys it by.
        public var id: String
        /// Its name in the app's words (`SimilarityAxis.displayName`).
        public var name: String
        /// Its weight in this tuning.
        public var weight: Double
        public var defaultWeight: Double
        /// Whether it can contribute on this server: never the cross-reference axis until S23c's pin move,
        /// the lexical axis until S24d, or the semantic axis until phase 4; nor shared topics on a server
        /// whose data files hold no document subject index, as the app's slider says on a device without one.
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
        /// The opening of its text in the served index, as the kit reads it for the rows shown.
        public var snippet: String?
        /// The "why related" chips, strongest first (`RelatedDocumentRow.whyRelatedChips`).
        public var chips: [Chip]
    }

    public struct Chip: Codable, Equatable, Sendable {
        /// The axis's stored name.
        public var axis: String
        /// The axis's name, which a screen reader is given before the chip's words, as the app's label is.
        public var name: String
        /// The chip's words (`WhyRelatedChip.displayText(locale:)`), in US English.
        public var text: String
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

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
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
            // The subject index is 6 MB of JSON, decoded once, off the cooperative pool.
            let subjects = try await Blocking.run { resources.documentSubjectIndex }
            let anchor = DocumentKey(volumeId: volumeId, documentId: documentId)
            let rows = await ranked(anchor, scope: scope, weights: weights, limit: limit, served: served, resources: resources,
                                    subjects: subjects)
            return answer(anchor, scope: scope, offered: offered, weights: weights, result: rows, subjects: subjects)
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

    /// The engine's dependencies over the served index and the data files: the index's pipeline, its
    /// person store, the document subject index, and the catalogue's manifest; no cross-reference query
    /// until S23c's pin move, no search service or stopwords for the lexical axis until S24d, and no
    /// semantic axis until phase 4.
    @MainActor
    static func dependencies(served: ServedIndex, resources: ServerResources,
                             subjects: DocumentSubjectIndex?) -> RelatedDocumentsDependencies {
        RelatedDocumentsDependencies(
            indexingPipeline: served.pipeline,
            // S23c: the kit's `CrossReferenceStore`, opened read-only and immutable over the served index.
            crossReferenceStore: nil,
            personMentionStore: served.persons,
            documentSubjectIndex: subjects,
            manifestStore: ServedManifest(resources: resources),
            // The lexical axis's: none until S24d brings WordCloudKit's stopwords.
            searchService: nil,
            indexedVolumeIds: served.indexedVolumeIds,
            lexicalStopwords: [],
            semantic: nil)
    }

    /// The anchor's related documents, as the app's list loads them: the anchor's year from the index, the
    /// scope's volumes and the kit's ranking, with the shared topics of the rows shown named.
    @MainActor
    static func ranked(_ anchor: DocumentKey, scope: RelatedScope, weights: AxisWeights, limit: Int, served: ServedIndex,
                       resources: ServerResources, subjects: DocumentSubjectIndex?) async -> RelatedDocumentsResult {
        let dates = (try? await served.pipeline.documentDates(for: [(volumeId: anchor.volumeId, documentId: anchor.documentId)])) ?? [:]
        let year = anchorYear(indexDate: dates[anchor.compositeString], doorYear: nil)
        let result = await RelatedDocumentsEngine.rank(
            anchor: anchor, anchorYear: year, weights: weights,
            scopeVolumeIds: volumeIds(of: scope, anchorVolumeId: anchor.volumeId, resources: resources),
            limit: limit, dependencies: dependencies(served: served, resources: resources, subjects: subjects))
        return RelatedDocumentsResult(rows: namingSharedSubjects(result.rows, anchor: anchor, subjects: subjects),
                                      totalBeforeLimit: result.totalBeforeLimit, poolCutFrom: result.poolCutFrom,
                                      offIndexLeads: result.offIndexLeads)
    }

    /// `rows` with the topics each shares with the anchor named, for its shared-topics chip, on the rows
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

    /// Whether an axis can contribute on this server.
    static func isAvailable(_ axis: SimilarityAxis, subjects: DocumentSubjectIndex?) -> Bool {
        switch axis {
        case .crossReference, .lexicalSimilarity, .semanticSimilarity: false
        case .sharedSubjects: subjects != nil
        case .archivalProvenance, .dateProximity, .subseries, .sharedPersons: true
        }
    }

    static func answer(_ anchor: DocumentKey, scope: RelatedScope, offered: [RelatedScope], weights: AxisWeights,
                       result: RelatedDocumentsResult, subjects: DocumentSubjectIndex?) -> RelatedDocuments {
        RelatedDocuments(
            volumeId: anchor.volumeId, documentId: anchor.documentId, scope: scope.rawValue,
            scopes: offered.map(\.rawValue), weights: weights.rawValue,
            axes: SimilarityAxis.allCases.map { axis in
                .init(id: axis.rawValue, name: axis.displayName, weight: weights[axis], defaultWeight: axis.defaultWeight,
                      available: isAvailable(axis, subjects: subjects))
            },
            rows: result.rows.map(row),
            totalBeforeLimit: result.totalBeforeLimit,
            // The app's footer, shown only when the pool held more than scored.
            poolCut: result.poolCutFrom.flatMap { cut in
                cut > result.totalBeforeLimit ? RelatedDocumentsCounts.poolCut(ranked: result.totalBeforeLimit, of: cut, locale: locale) : nil
            })
    }

    static func row(_ row: RelatedDocumentRow) -> RelatedDocuments.Row {
        RelatedDocuments.Row(
            volumeId: row.volumeId, documentId: row.documentId, header: row.record.header, dateline: row.record.dateline,
            documentNumber: row.record.documentNumber, isEditorialNote: row.record.isEditorialNote, score: row.totalScore,
            snippet: row.snippet.flatMap { $0.isEmpty ? nil : $0 },
            chips: row.whyRelatedChips.map { axis, chip in
                .init(axis: axis.rawValue, name: axis.displayName, text: chip.displayText(locale: locale))
            })
    }
}

/// The catalogue's manifest by volume id, which the corpus-proximity scorer reads a volume's subseries
/// from, as the app's `ManifestStore` answers it.
struct ServedManifest: VolumeManifestLookup {
    let resources: ServerResources

    func entry(forVolumeId id: String) -> VolumeManifestEntry? { resources.volume(id) }
}

/// The document subject index, `document-subject-index.json`, decoded the first time Related Documents or
/// Suggested Next ranks, as the app's `DocumentSubjectStore.shared` decodes it on first use: none for a file
/// missing or malformed, and the shared-topics axis then contributes nothing, as the app's does.
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
