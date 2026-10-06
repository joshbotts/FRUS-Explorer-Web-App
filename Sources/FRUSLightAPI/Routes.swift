// The routes: health, readiness and status, then the API under /api/v1 (docs/SPEC.md, HTTP API).

import FRUSLightCore
import Foundation
import Hummingbird
import Logging

func buildRouter(state: ServerState, resources: ServerResources, reader: ReaderService,
                 logger: Logger = Logger(label: "frus-light")) -> Router<BasicRequestContext> {
    let router = Router()
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
    CatalogRoutes.add(to: router, state: state, resources: resources, volumesDirectory: reader.volumesDirectory)
    ReaderRoutes.add(to: router, reader: reader)
    return router
}

struct Health: ResponseEncodable {
    let status: String
}

extension Readiness: ResponseEncodable {}
extension ServerStatus: ResponseEncodable {}
