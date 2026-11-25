// The feedback on a semantic match (PLAN's S26d): the app's two verdicts on a row of Related Documents that the
// semantic axis scored, Semantic match: helpful and Semantic match: not useful, kept for each user in the store
// (UserSemanticFeedback.swift, migration 9), where the app keeps one file a device, by the owner's answer of 23
// November. A verdict is built as the app's `RelatedDocumentsRequest.semanticFeedback` builds it, mirrored and held to
// its source by `RelatedDocumentsParityTests`: the pair, the verdict, the cosine the row was ranked on, the anchor's
// era from its year in the index, in the app's own `CoverageEra` banding, whether one volume holds both, the bundled
// generation's provenance digest, and when. The cosine is the server's, never the browser's: the kit's re-score of the
// pair (`SemanticVectorsSimilaritySource.reScore`), calibrated by the generation's document offset and clamped as the
// ranker reads a self-normalising axis, which is the row's semantic score, so a pair the axis cannot score is refused, as
// is a neighbour the server does not serve, which no list of it shows. The server does not rank the anchor's list again,
// so a pair of a served neighbour that the axis scores is taken whether a list showed it or not, at its own cosine.
// Settings ▸ Data lists them as the app's Semantic Match Feedback screen does (`SemanticFeedbackView`), from the app's
// summary (`SemanticFeedbackLog.summary()`): the verdicts, those marked helpful, and how many of each era. Its file is
// the app's, `frus-semantic-feedback.json`, the kit's export (`SemanticFeedbackEntry.exportData`), and Clear Recorded
// Feedback deletes them; an erasure of the user's research deletes them too.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import SemanticVectorsKit

/// A verdict recorded: the app's entry, as the store keeps it.
struct SemanticFeedbackRecorded: Codable, Equatable, Sendable, ResponseEncodable {
    var anchor: String
    var neighbour: String
    var verdict: String
    var cosine: Double?
    var era: String?
    var sameVolume: Bool?
    var provenanceDigest: String?
    var recordedAt: String

    init(_ entry: SemanticFeedbackEntry) {
        anchor = entry.anchor
        neighbour = entry.neighbour
        verdict = entry.verdict.rawValue
        cosine = entry.cosine
        era = entry.era
        sameVolume = entry.sameVolume
        provenanceDigest = entry.provenanceDigest
        recordedAt = UserStoreDate.text(entry.recordedAt)
    }
}

/// Settings ▸ Data's Semantic Match Feedback: the app's summary of a user's verdicts (`SemanticFeedbackLog.summary()`).
struct SemanticFeedbackSummary: Codable, Equatable, Sendable, ResponseEncodable {
    struct Era: Codable, Equatable, Sendable {
        /// As the entry stores it: `CoverageEra`'s raw value as a string, or `unknown` for an undated anchor.
        var era: String
        /// Its label: the kit's `CoverageEra.label`, or the app's "Undated anchor" (`SemanticFeedbackView.eraLabel`).
        var label: String
        var count: Int
    }

    var total: Int
    var helpful: Int
    /// Each era with its count, by the stored value's order, as the app sorts them.
    var byEra: [Era]
    /// Where the app's screen asks for the file (`SemanticFeedbackMail.address`).
    var address: String
    /// The file's name (`SemanticFeedbackMail.fileName`).
    var fileName: String
}

/// The verdicts Clear Recorded Feedback deleted.
struct SemanticFeedbackCleared: Codable, Equatable, Sendable, ResponseEncodable {
    var removed: Int
}

enum SemanticFeedbackRoutes {
    /// The file's name, the app's (`SemanticFeedbackMail.fileName`).
    static let fileName = "frus-semantic-feedback.json"
    /// Where the owner asked for the verdicts on 18 October (`SemanticFeedbackMail.address`).
    static let address = "feedback@frusexplorer.app"
    /// The app's label for a verdict whose anchor has no era (`settings.semanticFeedback.era.unknown`).
    static let undatedAnchor = "Undated anchor"

    struct Verdict: Decodable {
        /// Each `volumeId/documentId`.
        let anchor: String
        let neighbour: String
        /// `helpful` or `notHelpful`.
        let verdict: String
    }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    provider: ServedIndexProvider, vectors: SemanticVectors) {
        let store = services.store
        let now = services.now

        // A verdict on a row the semantic axis scored, as the app's row's menu records it.
        me.post("semantic-feedback") { request, context -> SemanticFeedbackRecorded in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Verdict.self, from: request, fields: ["anchor", "neighbour", "verdict"])
            let anchor = try document(body.anchor, field: "anchor", resources: resources)
            let neighbour = try document(body.neighbour, field: "neighbour", resources: resources)
            guard anchor != neighbour else {
                throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "neighbour: a document is not its own neighbour.")
            }
            guard let verdict = SemanticFeedbackEntry.Verdict(rawValue: body.verdict) else {
                throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "verdict: helpful or notHelpful.")
            }
            guard case .success(let bundle) = await vectors.bundle() else {
                throw APIProblem(.serviceUnavailable, code: "SEMANTIC_UNAVAILABLE",
                                 detail: "This server's semantic vectors are refused, so it has no semantic match to judge.")
            }
            // A row is a document of the index served, so a neighbour it does not hold is in no list to judge; and the era is
            // read from that index, as the app reads it from its own.
            guard let served = try? await provider.servedIfReady(), try await isServed(neighbour, in: served) else {
                throw APIProblem(.unprocessableContent, code: "NOT_A_SEMANTIC_MATCH",
                                 detail: "\(neighbour.compositeString) is not a document this server serves, so no list of \(anchor.compositeString)'s holds it to judge.")
            }
            guard let entry = await entry(verdict, anchor: anchor, neighbour: neighbour, bundle: bundle, shards: vectors,
                                          served: served, recordedAt: now()) else {
                throw APIProblem(.unprocessableContent, code: "NOT_A_SEMANTIC_MATCH",
                                 detail: "The semantic axis gives \(neighbour.compositeString) no score beside \(anchor.compositeString), so there is no semantic match to judge.")
            }
            try await Blocking.run { try store.recordSemanticFeedback(entry, for: user.id) }
            return SemanticFeedbackRecorded(entry)
        }

        // Settings ▸ Data's summary.
        me.get("semantic-feedback") { request, context -> EditedResponse<SemanticFeedbackSummary> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let entries = try await Blocking.run { try store.semanticFeedback(of: user.id) }
            return EditedResponse(headers: [.cacheControl: "no-store"], response: summary(entries))
        }

        // The file, the app's Prepare Feedback File's.
        me.get("semantic-feedback/file") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let entries = try await Blocking.run { try store.semanticFeedback(of: user.id) }
            let file = try SemanticFeedbackEntry.exportData(entries)
            var headers = HTTPFields()
            headers[.contentType] = "application/json"
            headers[.contentDisposition] = "attachment; filename=\"\(fileName)\""
            headers[.cacheControl] = "no-store"
            return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(bytes: file)))
        }

        // Clear Recorded Feedback.
        me.delete("semantic-feedback") { request, context -> SemanticFeedbackCleared in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            return SemanticFeedbackCleared(removed: try await Blocking.run { try store.clearSemanticFeedback(of: user.id) })
        }
    }

    /// A document's key from its `volumeId/documentId`, in a volume of the catalogue, under the rules a route's path holds
    /// a document's id to.
    static func document(_ raw: String, field: String, resources: ServerResources) throws -> DocumentKey {
        guard raw.utf8.count <= 512, let key = DocumentKey(compositeString: raw), resources.volume(key.volumeId) != nil,
              key.documentId.utf8.count <= 256, FRUSURLScheme.isSafeComponent(key.documentId)
        else {
            throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "\(field): \(raw) is not a document of the catalogue, as volumeId/documentId.")
        }
        return key
    }

    /// Whether the index served holds `key`, a document a list of it can show as a row.
    static func isServed(_ key: DocumentKey, in served: ServedIndex) async throws -> Bool {
        guard served.indexedVolumeIds.contains(key.volumeId) else { return false }
        return try await served.pipeline.candidateRecords(forKeys: [key])[key] != nil
    }

    /// The app's entry for a verdict on `neighbour` in `anchor`'s list (`RelatedDocumentsRequest.semanticFeedback`): the
    /// cosine the row was ranked on, the kit's calibrated re-score of the pair clamped as the ranker clamps the axis, nil
    /// when the axis gives the pair no score; the era of the anchor's year in the index served (`resolvedAnchorYear`);
    /// one volume holding both; and the bundled generation's digest.
    @MainActor
    static func entry(_ verdict: SemanticFeedbackEntry.Verdict, anchor: DocumentKey, neighbour: DocumentKey, bundle: SemanticBundle,
                      shards: any SemanticShardSource, served: ServedIndex, recordedAt: Date) async -> SemanticFeedbackEntry? {
        let (index, corpus) = (bundle.index, bundle.corpus)
        let volumes = served.indexedVolumeIds, pipeline = served.pipeline
        let source = SemanticVectorsSimilaritySource(host: SemanticSimilarityHost(
            index: index, corpusVectors: corpus, shardStore: shards, indexedVolumeIds: volumes, indexingPipeline: pipeline))
        // Every score clears a floor below any cosine: the pair's own, as the ranking read it.
        guard let calibrated = await source.reScore(anchor: anchor, candidates: [neighbour], floor: -.infinity)[neighbour]
        else { return nil }
        let cosine = min(1.0, max(0.0, calibrated))
        guard cosine > 0 else { return nil }
        let dates = (try? await served.pipeline.documentDates(for: [(volumeId: anchor.volumeId, documentId: anchor.documentId)])) ?? [:]
        let year = RelatedDocumentsRoutes.anchorYear(indexDate: dates[anchor.compositeString], doorYear: nil)
        return SemanticFeedbackEntry(
            recordedAt: recordedAt,
            anchor: anchor.compositeString,
            neighbour: neighbour.compositeString,
            verdict: verdict,
            cosine: cosine,
            era: year.map { CoverageEra.bucket(year: $0).rawValue.description },
            sameVolume: neighbour.volumeId == anchor.volumeId,
            provenanceDigest: bundle.provenance.digestHex)
    }

    /// The app's summary of the verdicts (`SemanticFeedbackLog.summary()`): the total, those marked helpful, and each
    /// era's count, an entry with none counted as `unknown`, sorted by the stored value, each with the screen's label.
    static func summary(_ rows: [SemanticFeedbackEntry]) -> SemanticFeedbackSummary {
        var eras: [String: Int] = [:]
        for row in rows { eras[row.era ?? "unknown", default: 0] += 1 }
        return SemanticFeedbackSummary(
            total: rows.count,
            helpful: rows.filter { $0.verdict == .helpful }.count,
            byEra: eras.map { (era: $0.key, count: $0.value) }.sorted { $0.era < $1.era }
                .map { .init(era: $0.era, label: eraLabel($0.era), count: $0.count) },
            address: address, fileName: fileName)
    }

    /// A stored era's label (`SemanticFeedbackView.eraLabel`): the kit's `CoverageEra` label for its raw value, else the
    /// app's "Undated anchor".
    static func eraLabel(_ raw: String) -> String {
        guard let value = Int(raw), let era = CoverageEra(rawValue: value) else { return undatedAnchor }
        return era.label
    }
}

extension SearchUsers {
    /// The verdicts the user `request` acts for gave on `anchor`'s neighbours, by the neighbour's key, or none for a request
    /// that acts for no one.
    func semanticVerdicts(on anchor: DocumentKey, for request: Request,
                          context: APIRequestContext) async throws -> [String: SemanticFeedbackEntry.Verdict] {
        guard let services, let user = try await requestUser(request, context: context, services: services) else { return [:] }
        return try await Blocking.run { try services.store.semanticVerdicts(of: user.id, anchor: anchor.compositeString) }
    }
}
