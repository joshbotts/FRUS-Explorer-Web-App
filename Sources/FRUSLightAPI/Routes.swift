// The routes: health, readiness and status, the API under /api/v1 (docs/SPEC.md, HTTP API), the
// user's own under /api/v1/me and an admin's under /api/v1/admin, the reader's host script, and the
// browser app, at the root or under the server's base path.

import FRUSLightCore
import Foundation
import Hummingbird
import Logging

/// The routes, written at the root. `base` is the path the server answers under, for the addresses
/// the reader's page names; `ServedRouter` puts the routes under it.
func buildRouter(state: ServerState, resources: ServerResources, reader: ReaderService,
                 provider: ServedIndexProvider? = nil, webClient: WebClient? = nil, userData: UserDataServices? = nil,
                 base: BasePath = .root, logger: Logger = Logger(label: "frus-light")) -> Router<APIRequestContext> {
    let provider = provider ?? ServedIndexProvider(state: state, resources: resources, volumesDirectory: reader.volumesDirectory)
    // Every GET route answers HEAD too, so HEAD /readyz says what GET says rather than falling to
    // the browser app's fallback.
    let router = Router(context: APIRequestContext.self, options: .autoGenerateHeadEndpoints)
    // First, so it covers every route, and the paths no route matches.
    router.add(middleware: ProblemMiddleware(logger: logger))
    // The process is up. It says nothing about the index; /readyz does.
    router.get("/healthz") { _, _ in Health(status: "ok") }
    // 200 once an index is open and searchable; until then 503, naming the current step.
    router.get("/readyz") { _, _ in
        let readiness = await state.readiness()
        return EditedResponse(status: readiness.ready ? .ok : .serviceUnavailable, response: readiness)
    }
    // Behind a proxy that signs people in (S14e), everything after the health endpoints, the paths no
    // route answers and the browser app included, comes through the proxy.
    if let proxies = userData?.proxies { router.add(middleware: TrustedProxyGuard(proxies: proxies)) }
    router.get("/api/v1/status") { request, _ in
        try FormQuery(request.uri.query).refuseUnknown([])
        return await state.status()
    }
    CatalogRoutes.add(to: router, state: state, provider: provider, resources: resources, reader: reader)
    SearchRoutes.add(to: router, provider: provider, resources: resources)
    FacetRoutes.add(to: router, provider: provider, resources: resources)
    ReadingRoutes.add(to: router, provider: provider, resources: resources)
    ReaderRoutes.add(to: router, reader: reader, provider: provider, resources: resources, base: base)
    CitationRoutes.add(to: router, reader: reader, provider: provider, resources: resources)
    CitationLookupRoutes.add(to: router, provider: provider, resources: resources)
    ReaderLinkRoutes.add(to: router, state: state, provider: provider, reader: reader, resources: resources)
    if let userData {
        UserDataRoutes.add(to: router, services: userData, resources: resources, reader: reader, provider: provider)
        AdminRoutes.add(to: router, services: userData)
    }
    // Last, so it wraps only the requests no route answers.
    if let webClient { router.add(middleware: WebClientMiddleware(webClient, logger: logger)) }
    return router
}

/// The routes under the server's base path (`ServerConfiguration.basePath`, PLAN's S14f). At the
/// root they are the router alone. Under a path such as `/frus-explorer/`, a request under it
/// reaches the routes at the path they are written for, `/frus-explorer/api/v1/status` as
/// `/api/v1/status`, with the base in its context. `/healthz` and `/readyz` answer at the root as
/// well, for the container's health check and a proxy's. A GET of the base without its last slash,
/// or of the root, is redirected to the base, and any other path is a 404.
struct ServedRouter: HTTPResponderBuilder {
    let base: BasePath
    let router: Router<APIRequestContext>

    func buildResponder() -> Responder { Responder(base: base, routes: router.buildResponder()) }

    struct Responder: HTTPResponder {
        let base: BasePath
        let routes: RouterResponder<APIRequestContext>

        func respond(to request: Request, context: APIRequestContext) async throws -> Response {
            let path = request.uri.path
            if base.isRoot || path == "/healthz" || path == "/readyz" {
                return try await routes.respond(to: request, context: context)
            }
            if let inside = base.stripping(request.head.path ?? path) {
                var head = request.head
                head.path = inside
                var context = context
                context.basePath = base
                return try await routes.respond(to: Request(head: head, body: request.body), context: context)
            }
            if request.method == .get || request.method == .head, path == "/" || path + "/" == base.path {
                let query = request.uri.query.map { "?\($0)" } ?? ""
                // The base's own redirect is permanent; the root's is not, as the base may move.
                return Response(status: path == "/" ? .found : .permanentRedirect, headers: [.location: base.path + query])
            }
            return try APIProblem(.notFound, code: "NOT_FOUND", detail: "This server answers under \(base.path), and \(path) is outside it.")
                .response(from: request, context: context)
        }
    }
}

struct Health: ResponseEncodable {
    let status: String
}

extension Readiness: ResponseEncodable {}
extension ServerStatus: ResponseEncodable {}
