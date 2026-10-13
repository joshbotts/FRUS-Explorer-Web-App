// Checks 3 and 4 against a server that is running, such as a Compose install serving the owner's
// export (S10): check 3's records through GET /api/v1/search, and the reader's bodies through
// GET …/html?part=body, with the server's figure addresses written back as the reader's. A caller
// passes `get`, which fetches a path from the server; frus-parity's results and render-api use it.

import Foundation
import ParityFormat

public enum LiveAPI {
    /// A response to a GET: its status code and body.
    public typealias Response = (status: Int, body: Data)

    /// The fields of a search's JSON that check 3 reads.
    public struct SearchPage: Decodable, Sendable {
        public struct Item: Decodable, Sendable {
            public let volumeId: String
            public let documentId: String
            public let bm25Score: Double
        }

        public let total: Int
        public let countBasis: String
        public let limit: Int
        public let offset: Int
        public let items: [Item]
    }

    /// What a request throws when the server refuses it or fails. A refused search's description
    /// is the kit's refusal, from the problem's `searchError`, which check 3 records as the error.
    public struct Failure: Error, CustomStringConvertible {
        public let description: String

        public init(_ description: String) { self.description = description }
    }

    /// The part of a problem's details that carries a refused search's reason.
    private struct Refusal: Decodable {
        let searchError: String?
    }

    /// Each query's count, first 50 results and tie tail, read through ResultsLoop as the golden
    /// tool reads them, as `ServedAPIParityTests` reads them in process. Also returns what a page
    /// says that check 3 does not expect: a count that is not exact, another page than the one
    /// asked for, or a total that changes between pages.
    public static func results(_ queries: [ParityQuery],
                               get: (String) async throws -> Response) async -> (records: [ResultRecord], anomalies: [String]) {
        var records: [ResultRecord] = []
        var anomalies: [String] = []
        for query in queries {
            var first: SearchPage?
            func page(_ limit: Int, _ offset: Int) async throws -> SearchPage {
                if offset == 0, let first, first.limit == limit { return first }
                let response = try await get("/api/v1/search?\(APIParity.formEncode(query, limit: limit, offset: offset))")
                if response.status == 400, let refusal = try? JSONDecoder().decode(Refusal.self, from: response.body).searchError {
                    throw Failure(refusal)
                }
                guard response.status == 200 else {
                    throw Failure("\(query.id): \(response.status) \(String(decoding: response.body.prefix(300), as: UTF8.self))")
                }
                let list = try JSONDecoder().decode(SearchPage.self, from: response.body)
                if list.countBasis != "exact" || list.limit != limit || list.offset != offset {
                    anomalies.append("\(query.id) at \(offset): \(list.countBasis), \(list.limit)/\(list.offset)")
                }
                if let first, first.total != list.total { anomalies.append("\(query.id): total \(first.total), then \(list.total)") }
                return list
            }
            records.append(await ResultsLoop.record(
                id: query.id,
                count: {
                    let list = try await page(ResultsLoop.limit, 0)
                    first = list
                    return list.total
                },
                page: { limit, offset in
                    try await page(limit, offset).items.map { SearchHit(volume: $0.volumeId, document: $0.documentId, score: $0.bm25Score) }
                }))
        }
        return (records, anomalies)
    }

    /// The body of each row's page, for `RenderParity.mismatches`, with every figure image the
    /// server names by its own address (`/api/v1/volumes/{v}/figures/…`) written back as the
    /// reader's (`frusexplorer://figure/{v}/…`), and how many each row had. A page the server does
    /// not serve throws.
    public static func bodies(_ rows: [(volume: String, document: String)],
                              get: (String) async throws -> Response) async throws -> (documents: [RenderedDocument], figures: [String: Int]) {
        var documents: [RenderedDocument] = []
        var figures: [String: Int] = [:]
        for row in rows {
            let response = try await get("/api/v1/volumes/\(row.volume)/documents/\(row.document)/html?part=body")
            guard response.status == 200 else {
                throw Failure("\(row.volume)/\(row.document): \(response.status) \(String(decoding: response.body.prefix(300), as: UTF8.self))")
            }
            let body = String(decoding: response.body, as: UTF8.self)
            let count = body.components(separatedBy: "src=\"/api/v1/volumes/").count - 1
            if count > 0 { figures["\(row.volume)/\(row.document)"] = count }
            let back = body.replacing(/src="\/api\/v1\/volumes\/([^\/"]+)\/figures\//) { "src=\"frusexplorer://figure/\($0.1)/" }
            documents.append(RenderedDocument(volume: row.volume, document: row.document, html: back))
        }
        return (documents, figures)
    }
}
