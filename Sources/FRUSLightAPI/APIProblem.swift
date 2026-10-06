// Errors as RFC 9457 problem details, application/problem+json (docs/SPEC.md, HTTP API > Conventions).

import Foundation
import Hummingbird
import Logging

/// An error the API answers with a problem details body:
/// `{type, title, status, detail, instance, code, searchError?}`.
///
/// `type` is `about:blank`, so `title` is the status's reason phrase, as RFC 9457 asks. The
/// machine-readable identity is `code`, in the draft's SCREAMING_SNAKE_CASE, and `searchError`
/// carries a refusal from the kit's search, such as `emptyQuery`, as `String(describing:)` gives it.
public struct APIProblem: HTTPResponseError, Equatable, CustomStringConvertible {
    public let status: HTTPResponse.Status
    public let code: String
    public let detail: String
    public var searchError: String?

    public init(_ status: HTTPResponse.Status, code: String, detail: String, searchError: String? = nil) {
        self.status = status
        self.code = code
        self.detail = detail
        self.searchError = searchError
    }

    public var description: String { "\(status.code) \(code): \(detail)" }

    public static let contentType = "application/problem+json"

    /// The body as it is sent, for a request to `instance`.
    public struct Body: Codable, Equatable, Sendable {
        public var type: String
        public var title: String
        public var status: Int
        public var detail: String
        public var instance: String
        public var code: String
        public var searchError: String?
    }

    public func body(instance: String) -> Body {
        Body(type: "about:blank", title: status.reasonPhrase, status: Int(status.code), detail: detail,
             instance: instance, code: code, searchError: searchError)
    }

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(body(instance: request.uri.path))
        return Response(status: status, headers: [.contentType: Self.contentType],
                        body: .init(byteBuffer: ByteBuffer(bytes: data)))
    }

    // MARK: Problems more than one route answers

    static func invalidParameter(_ name: String, _ detail: String) -> APIProblem {
        APIProblem(.badRequest, code: "INVALID_PARAMETER", detail: "\(name): \(detail)")
    }

    static func volumeNotFound(_ volumeId: String) -> APIProblem {
        APIProblem(.notFound, code: "VOLUME_NOT_FOUND", detail: "The published catalogue has no volume \(volumeId).")
    }
}

/// Answers every error under `/api/` with a problem details body: Hummingbird's own, such as a
/// path no route matches, and any other, which is logged and answered as a 500 that names
/// nothing internal. Other paths keep Hummingbird's answers. Added before the routes, since a
/// router applies middleware only to the routes added after it.
struct ProblemMiddleware<Context: RequestContext>: RouterMiddleware {
    let logger: Logger

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        guard request.uri.path.hasPrefix("/api/") else { return try await next(request, context) }
        do {
            return try await next(request, context)
        } catch let problem as APIProblem {
            throw problem
        } catch let error as HTTPError {
            throw APIProblem(error.status, code: Self.code(error.status),
                             detail: error.body ?? Self.detail(error.status, path: request.uri.path))
        } catch let error as any HTTPResponseError {
            throw APIProblem(error.status, code: Self.code(error.status), detail: error.status.reasonPhrase)
        } catch {
            logger.error("\(request.method) \(request.uri.path) failed: \(error)")
            throw APIProblem(.internalServerError, code: "INTERNAL_ERROR", detail: "The server could not answer this request; its log says why.")
        }
    }

    static func code(_ status: HTTPResponse.Status) -> String {
        switch status.code {
        case 400: "BAD_REQUEST"
        case 404: "NOT_FOUND"
        case 405: "METHOD_NOT_ALLOWED"
        case 413: "CONTENT_TOO_LARGE"
        default: status.reasonPhrase.uppercased().map { $0.isLetter || $0.isNumber ? $0 : "_" }.reduce(into: "") { $0.append($1) }
        }
    }

    static func detail(_ status: HTTPResponse.Status, path: String) -> String {
        status == .notFound ? "No endpoint answers \(path)." : status.reasonPhrase
    }
}
