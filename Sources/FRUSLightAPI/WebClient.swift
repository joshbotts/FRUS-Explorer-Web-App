// The browser app: web/'s Vite build, served from FRUS_WEB_DIR beside the API. The build names its
// files by relative paths, and its page carries `<base href="/">`, into which the server writes the
// path it answers under, so one build serves at the root or under a path.

import FRUSLightCore
import Foundation
import Hummingbird
import Logging

/// The browser app's built files, read at start.
public struct WebClient: Sendable {
    public let directory: URL
    /// `index.html`, with the server's base path in its `<base>`: the page every client route
    /// answers with.
    let index: ByteBuffer

    /// What the build's page holds, and the server writes its base path into.
    static let basePlaceholder = "<base href=\"/\""

    /// The app in `configuration.webDirectory`, or nil when it is not there. Throws
    /// `WebClientError` when the configuration names a folder explicitly and it holds no app, or
    /// when the app's page has no `<base href="/">` to write the base path into.
    public static func load(_ configuration: ServerConfiguration) throws -> WebClient? {
        let directory = configuration.webDirectory
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("index.html")) else {
            if configuration.requiresWebDirectory { throw WebClientError(path: directory.path) }
            return nil
        }
        let page = String(decoding: data, as: UTF8.self)
        guard let placeholder = page.range(of: basePlaceholder) else {
            throw WebClientError(path: directory.path, problem: .noBase)
        }
        // The path holds only unreserved characters, so it needs no escaping in the attribute.
        let written = page.replacingCharacters(in: placeholder, with: "<base href=\"\(configuration.basePath.path)\"")
        return WebClient(directory: directory, index: ByteBuffer(string: written))
    }

    init(directory: URL, index: ByteBuffer) {
        self.directory = directory
        self.index = index
    }

    /// The app loads its own scripts, styles and images, and frames only the server's own pages,
    /// the reader's; nothing frames it.
    static let policy = [
        "default-src 'self'", "img-src 'self' data:", "object-src 'none'", "base-uri 'self'",
        "form-action 'self'", "frame-ancestors 'none'",
    ].joined(separator: "; ")

    /// Vite names the files under `/assets/` by their content, so they never change; everything
    /// else, `index.html` above all, is revalidated.
    static func secure(_ headers: inout HTTPFields, immutable: Bool) {
        headers[.cacheControl] = immutable ? "public, max-age=31536000, immutable" : "no-cache"
        headers[.contentSecurityPolicy] = policy
        headers[.xContentTypeOptions] = "nosniff"
        headers[ReaderRoutes.HeaderName("Referrer-Policy")!] = "no-referrer"
    }
}

/// FRUS_WEB_DIR names a folder with no `index.html` in it, or one whose page is not this server's
/// build of the app.
public struct WebClientError: Error, CustomStringConvertible, Equatable {
    public enum Problem: Sendable, Equatable { case noIndex, noBase }

    public let path: String
    public var problem: Problem = .noIndex

    public var description: String {
        switch problem {
        case .noIndex:
            "FRUS_WEB_DIR is \(path), which holds no index.html: it must name the browser app's build, web/dist"
        case .noBase:
            "\(path)/index.html has no <base href=\"/\"> for the server to write its path into: the folder must hold the browser app's build, web/dist, from this release"
        }
    }
}

/// Serves the browser app's files, and its page, with the base path written, for every client route.
///
/// Added after the routes, so it sees only the requests no route answers, at the paths they are
/// written for. A GET or HEAD outside `/api/` and `/reader/` is a file of the app when one is there,
/// `index.html` aside, whose own path and `/` answer with the page; otherwise a path whose last part
/// has no extension, such as `/search` or `/doc/frus1961-63v06/d1`, is a client route and gets the
/// page, while a missing file such as an old `/assets/*.js` stays a 404. So an unknown API path
/// keeps its problem details, and no script URL is ever answered with HTML.
struct WebClientMiddleware<Context: RequestContext>: RouterMiddleware {
    let client: WebClient
    let files: FileMiddleware<Context, LocalFileSystem>

    init(_ client: WebClient, logger: Logger) {
        self.client = client
        files = FileMiddleware(client.directory.path, searchForIndexHtml: false, logger: logger)
    }

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let path = request.uri.path
        guard request.method == .get || request.method == .head,
              !path.hasPrefix("/api/"), !path.hasPrefix("/reader/") else {
            return try await next(request, context)
        }
        if path == "/" || path == "/index.html" { return page(for: request) }
        do {
            var response = try await files.handle(request, context: context, next: next)
            // Vite writes UTF-8, and the page says so as the fallback does.
            if response.headers[.contentType] == "text/html" {
                response.headers[.contentType] = "text/html; charset=utf-8"
            }
            WebClient.secure(&response.headers, immutable: path.hasPrefix("/assets/"))
            return response
        } catch let error as any HTTPResponseError where error.status == .notFound {
            guard !(path.split(separator: "/").last ?? "").contains(".") else { throw error }
            return page(for: request)
        }
    }

    /// The app's page, which takes the base path from its `<base>`.
    func page(for request: Request) -> Response {
        var headers: HTTPFields = [.contentType: "text/html; charset=utf-8"]
        WebClient.secure(&headers, immutable: false)
        // HEAD keeps GET's headers, the length among them.
        let response = Response(status: .ok, headers: headers, body: .init(byteBuffer: client.index))
        return request.method == .head ? response.createHeadResponse() : response
    }
}
