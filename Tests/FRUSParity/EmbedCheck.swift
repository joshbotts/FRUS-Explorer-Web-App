// Check 9's encoder half (PLAN's S27b, Phase 4's "Check 9, as the rows read it"): each query of a fixture
// embedded through a running server's own path, `GET /api/v1/admin/semantic/embedding`, and held to the vector
// the fixture gives it, at the app's own bar for its encoder, a cosine of 0.999 or more
// (`QueryEncoderParityTests`), since a processor's arithmetic and Metal's differ and a re-embedded query is
// never held to exactness. The fixture is the app's, `query-parity-fixture-embeddinggemma-2.json`: its 25
// judged queries, embedded on a Mac by llama.cpp's command line at the app's commit. With each cosine, as
// information, how many of the first 512 values' signs differ, which the retrieval's Hamming stage reads.

import FRUSLightCore
import Foundation

public enum EmbedCheck {
    /// The app's fixture, in its repository.
    public static let fixturePath = "FRUSExplorerTests/Fixtures/query-parity-fixture-embeddinggemma-2.json"
    /// The app's bar for its own encoder against the command line's vectors.
    public static let bar = 0.999
    /// The width the Hamming stage reads the signs of: the shipping width.
    public static let signWidth = 512

    /// The app's fixture: the prompt its queries were embedded under, the model's digest, the engine, and
    /// each query with its vector.
    public struct Fixture: Decodable, Sendable {
        public struct Query: Decodable, Sendable {
            public let text: String
            public let vector: [Double]
        }

        public let queryPrefix: String
        public let ggufSHA256: String
        public let referenceEngine: String
        public let queries: [Query]

        public init(contentsOf url: URL) throws {
            self = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        }
    }

    /// One query's result.
    public struct Row: Codable, Sendable, Equatable {
        public let query: String
        public let cosine: Double
        /// Signs of the first 512 values that differ from the fixture's.
        public let signsDiffering: Int
        public let tokens: Int
        public let seconds: Double
    }

    /// What the server's encoder is, as its report says.
    public struct Server: Codable, Sendable, Equatable {
        public let modelSHA256: String?
        public let engine: String?
    }

    public struct Result: Codable, Sendable {
        public var rows: [Row] = []
        /// Queries the server did not embed, with why.
        public var failures: [String] = []
        /// Why the fixture and the server cannot be compared at all.
        public var refusals: [String] = []
        public var server: Server?
        public var reference: String = ""

        public var least: Row? { rows.min { $0.cosine < $1.cosine } }
        public var mean: Double { rows.isEmpty ? 0 : rows.map(\.cosine).reduce(0, +) / Double(rows.count) }
        public var passes: Bool {
            refusals.isEmpty && failures.isEmpty && !rows.isEmpty && rows.allSatisfy { $0.cosine >= EmbedCheck.bar }
        }

        public func summary() -> String {
            guard refusals.isEmpty else { return "check 9's encoder half fails: \(refusals.joined(separator: "; "))" }
            let lowest = self.least.map { "least cosine \(String(format: "%.6f", $0.cosine)) (\($0.query))" } ?? "no query embedded"
            let signs = rows.map(\.signsDiffering).reduce(0, +)
            let facts = "\(rows.count) queries, \(lowest), mean \(String(format: "%.6f", mean)), \(signs) of \(rows.count * EmbedCheck.signWidth) signs of the first \(EmbedCheck.signWidth) values differing, against \(reference), by \(server?.engine ?? "an engine the server did not name")"
            if passes { return "check 9's encoder half passes: \(facts)" }
            let below = rows.filter { $0.cosine < EmbedCheck.bar }.count
            return "check 9's encoder half fails: \(facts); \(below) below \(EmbedCheck.bar), \(failures.count) not embedded"
        }
    }

    /// A response to a GET: its status code and body.
    public typealias Get = @Sendable (String) async throws -> (status: Int, body: Data)

    /// Embeds each of `fixture`'s queries through `get`, a running server's routes, one at a time as its
    /// encoder serves them, and holds each to its vector.
    public static func run(fixture: Fixture, get: Get) async -> Result {
        var result = Result()
        result.reference = fixture.referenceEngine
        if fixture.queryPrefix != SearchModel.queryPrefix {
            result.refusals.append("the fixture's queries were embedded under \"\(fixture.queryPrefix)\", where the kit's prompt is \"\(SearchModel.queryPrefix)\"")
        }
        struct Report: Decodable {
            struct Model: Decodable { let sha256: String?; let bundledSHA256: String? }
            struct Engine: Decodable { let version: String? }
            let model: Model
            let engine: Engine
        }
        do {
            let answer = try await get("/api/v1/admin/semantic")
            guard answer.status == 200 else { throw Failure(answer) }
            let report = try JSONDecoder().decode(Report.self, from: answer.body)
            result.server = Server(modelSHA256: report.model.sha256, engine: report.engine.version)
            if report.model.sha256 != nil, report.model.sha256 != fixture.ggufSHA256 {
                result.refusals.append("the server's model is \(report.model.sha256 ?? ""), where the fixture's vectors were made by \(fixture.ggufSHA256)")
            }
        } catch {
            result.refusals.append("the server's Search Model could not be read: \(error)")
        }
        guard result.refusals.isEmpty else { return result }
        struct Embedded: Decodable {
            let vector: [Double]
            let tokens: Int
            let seconds: Double
        }
        for query in fixture.queries {
            do {
                let answer = try await get("/api/v1/admin/semantic/embedding?query=\(formEncoded(query.text))")
                guard answer.status == 200 else { throw Failure(answer) }
                let embedded = try JSONDecoder().decode(Embedded.self, from: answer.body)
                guard embedded.vector.count == query.vector.count else {
                    result.failures.append("\(query.text): \(embedded.vector.count) values, where the fixture has \(query.vector.count)")
                    continue
                }
                result.rows.append(Row(query: query.text, cosine: cosine(embedded.vector, query.vector),
                                       signsDiffering: signsDiffering(embedded.vector, query.vector), tokens: embedded.tokens,
                                       seconds: embedded.seconds))
            } catch {
                result.failures.append("\(query.text): \(error)")
            }
        }
        return result
    }

    /// The cosine of two vectors, in double precision.
    public static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        var dot = 0.0, aa = 0.0, bb = 0.0
        for (x, y) in zip(a, b) {
            dot += x * y
            aa += x * x
            bb += y * y
        }
        return aa > 0 && bb > 0 ? dot / (aa.squareRoot() * bb.squareRoot()) : 0
    }

    /// Of the first 512 values, how many have another sign: the bits the Hamming stage reads, a zero
    /// packed as one, as the artifacts pack it.
    public static func signsDiffering(_ a: [Double], _ b: [Double]) -> Int {
        zip(a.prefix(signWidth), b.prefix(signWidth)).filter { ($0 >= 0) != ($1 >= 0) }.count
    }

    /// `text` as a form's value: everything but letters, digits and `-._~` escaped.
    static func formEncoded(_ text: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ answer: (status: Int, body: Data)) {
            description = "\(answer.status) \(String(decoding: answer.body.prefix(300), as: UTF8.self))"
        }
    }
}
