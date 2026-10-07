// The routes: health, readiness and status, the API under /api/v1 (docs/SPEC.md, HTTP API), the
// reader's host script, and the browser app.

import FRUSLightCore
import Foundation
import Hummingbird
import Logging

func buildRouter(state: ServerState, resources: ServerResources, reader: ReaderService,
                 provider: ServedIndexProvider? = nil, webClient: WebClient? = nil,
                 logger: Logger = Logger(label: "frus-light")) -> Router<BasicRequestContext> {
    let provider = provider ?? ServedIndexProvider(state: state, resources: resources, volumesDirectory: reader.volumesDirectory)
    // Every GET route answers HEAD too, so HEAD /readyz says what GET says rather than falling to
    // the browser app's fallback.
    let router = Router(options: .autoGenerateHeadEndpoints)
    // First, so it covers every route, and the paths no route matches.
    router.add(middleware: ProblemMiddleware(logger: logger))
    // The process is up. It says nothing about the index; /readyz does.
    router.get("/healthz") { _, _ in Health(status: "ok") }
    // 200 once an index is open and searchable; until then 503, naming the current step.
    router.get("/readyz") { _, _ in
        let readiness = await state.readiness()
        return EditedResponse(status: readiness.ready ? .ok : .serviceUnavailable, response: readiness)
    }
    router.get("/api/v1/status") { request, _ in
        try FormQuery(request.uri.query).refuseUnknown([])
        return await state.status()
    }
    CatalogRoutes.add(to: router, state: state, provider: provider, resources: resources, reader: reader)
    SearchRoutes.add(to: router, provider: provider, resources: resources)
    ReaderRoutes.add(to: router, reader: reader, provider: provider, resources: resources)
    CitationRoutes.add(to: router, reader: reader, provider: provider, resources: resources)
    ReaderLinkRoutes.add(to: router, state: state, provider: provider, reader: reader, resources: resources)
    // Last, so it wraps only the requests no route answers.
    if let webClient { router.add(middleware: WebClientMiddleware(webClient, logger: logger)) }
    return router
}

struct Health: ResponseEncodable {
    let status: String
}

extension Readiness: ResponseEncodable {}
extension ServerStatus: ResponseEncodable {}
