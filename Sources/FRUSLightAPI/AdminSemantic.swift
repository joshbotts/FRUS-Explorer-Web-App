// Administration ▸ Semantic (PLAN's S27b): Search Model, the app's section in a server's words. The model in
// the image, its size and its SHA-256 held to the bundled index's, the engine that runs it, and the encoder's
// setting and state, on and loaded or idle, or off, with nothing to download or remove, since the image holds
// the model; and one query embedded through the server's own path, as the smoke test and `frus-parity embed`
// ask, check 9's encoder half. An admin's, behind `AdminRoutes`' guard. Since S26c, Vectors beside it: the
// bundled generation, its model and its count, the shards in the image of those the bundled manifest
// publishes, each checked before the answer, and any refused, with why, in the app's storage sentences.
//   GET /api/v1/admin/semantic
//   GET /api/v1/admin/semantic/embedding?query=…

import FRUSLightCore
import Foundation
import Hummingbird

/// `GET /api/v1/admin/semantic/embedding`: the query, the prompt it was embedded under and the vector, with
/// the tokens it took and the time.
public struct EmbeddingAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var query: String
    /// The kit's prompt and the query, as the encoder was given them.
    public var prompt: String
    public var tokens: Int
    public var dimensions: Int
    /// The 768 values, of unit length, normalised as the app's are.
    public var vector: [Double]
    public var seconds: Double
    /// Whether this query started the encoder.
    public var started: Bool
}

/// `GET /api/v1/admin/semantic`: Search Model's report as S27b gave it, its members where they were, and the
/// vectors' report under `vectors` (S26c).
public struct SemanticAdminReport: Codable, Equatable, Sendable, ResponseEncodable {
    public var searchModel: EncoderReport
    public var vectors: SemanticVectorsReport

    private enum Keys: String, CodingKey {
        case vectors
    }

    public init(searchModel: EncoderReport, vectors: SemanticVectorsReport) {
        self.searchModel = searchModel
        self.vectors = vectors
    }

    public init(from decoder: any Decoder) throws {
        searchModel = try EncoderReport(from: decoder)
        vectors = try decoder.container(keyedBy: Keys.self).decode(SemanticVectorsReport.self, forKey: .vectors)
    }

    public func encode(to encoder: any Encoder) throws {
        try searchModel.encode(to: encoder)
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(vectors, forKey: .vectors)
    }
}

enum AdminSemanticRoutes {
    static func add(to admin: RouterGroup<APIRequestContext>, encoder: QueryEncoder, vectors: SemanticVectors) {
        admin.get("semantic") { request, _ -> EditedResponse<SemanticAdminReport> in
            try FormQuery(request.uri.query).refuseUnknown([])
            async let model = encoder.report()
            async let held = vectors.report()
            return EditedResponse(headers: [.cacheControl: "no-store"], response: SemanticAdminReport(searchModel: await model, vectors: await held))
        }

        admin.get("semantic/embedding") { request, _ -> EditedResponse<EmbeddingAnswer> in
            let form = try FormQuery(request.uri.query)
            try form.refuseUnknown(["query"])
            guard let query = try form.single("query") else {
                throw APIProblem(.badRequest, code: "QUERY_MISSING", detail: "Give the words to embed as query.")
            }
            do {
                let embedding = try await encoder.embed(query)
                return EditedResponse(headers: [.cacheControl: "no-store"], response: EmbeddingAnswer(
                    query: query, prompt: SearchModel.queryPrefix + query, tokens: embedding.tokens,
                    dimensions: embedding.vector.count, vector: embedding.vector, seconds: embedding.seconds,
                    started: embedding.started))
            } catch let refusal as EncoderRefusal {
                throw refusal.problem
            }
        }
    }
}

extension EncoderRefusal {
    /// The problem a route answers with, in the refusal's words.
    var problem: APIProblem {
        switch self {
        case .off: APIProblem(.conflict, code: "ENCODER_OFF", detail: description)
        case .unavailable: APIProblem(.serviceUnavailable, code: "ENCODER_UNAVAILABLE", detail: description)
        case .emptyQuery: APIProblem(.badRequest, code: "QUERY_MISSING", detail: description)
        case .tooLong: APIProblem(.unprocessableContent, code: "QUERY_TOO_LONG", detail: description)
        case .failed: APIProblem(.serviceUnavailable, code: "ENCODER_FAILED", detail: description)
        }
    }
}

extension EncoderReport: ResponseEncodable {}
