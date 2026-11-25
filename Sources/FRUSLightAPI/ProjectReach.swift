// Project Home's reach (PLAN's S26d): Beyond your library at a project's grain, under Suggested Next, the kit's
// `SemanticProjectReach` (FRUS-Explorer#1980): one multi-probe Hamming pass over the bundled sign bits, probed by the
// project's seed documents at once, gathered as Suggested Next gathers them (`ProjectLeadsSeed`), its first forty, as the
// app's `ProjectLeadsService.recompute` asks it, and ranked by the seeds that reach each volume, then its documents, up
// to five volumes the served index does not hold. It needs no shard and fetches none. The tuning is the leads': the
// project's own, else the asking browser's, else the defaults (`effectiveWeights(projectRaw:browserRaw:)`), and the scan
// runs only while it leaves the semantic axis on, the kit's gate. The app hands its finding to the view and keeps none,
// a fact about one device's disk; here it is a fact about the served index, read when Project Home asks, and kept by
// no one either.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import SemanticVectorsKit

/// `GET /api/v1/me/projects/{id}/reach`: the volumes the project reaches beyond the served index.
struct ProjectReachAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    struct Volume: Codable, Equatable, Sendable {
        var volumeId: String
        /// Its title in the catalogue, or its id.
        var title: String
        /// Its documents that read as close to one of the seeds as that seed's nearest neighbours in the served index.
        var documentCount: Int
        /// The seeds that reached it.
        var reachingSeeds: Int
    }

    /// The volumes, best first, five at most.
    var volumes: [Volume]
    /// The documents admitted across every volume.
    var documentCount: Int
    /// The seeds that carried a vector and were probed.
    var seedsProbed: Int

    init(_ reach: ProjectReach, resources: ServerResources) {
        volumes = reach.volumes.map {
            .init(volumeId: $0.volumeID, title: resources.volume($0.volumeID)?.title ?? $0.volumeID, documentCount: $0.documentCount,
                  reachingSeeds: $0.reachingSeeds)
        }
        documentCount = reach.documentCount
        seedsProbed = reach.seedsProbed
    }
}

enum ProjectReachRoutes {
    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    provider: ServedIndexProvider, leads: ProjectLeadsQueue) {
        let store = services.store
        me.get("projects/:projectId/reach") { request, context -> EditedResponse<ProjectReachAnswer> in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["weights"])
            // The browser's tuning of Related Documents, which the project's own replaces, as a Refresh brings it.
            let browserWeights = try query.single("weights")
            if let browserWeights { _ = try RelatedDocumentsRoutes.requestedWeights(browserWeights) }
            let user = try context.requireUser()
            let project = try await ProjectRoutes.project(try context.parameters.require("projectId"), of: user.id, in: store)
            // Beyond the index served, of which there must be one.
            let served = try await provider.served()
            let seed: [String]
            do {
                seed = try await ProjectLeadsSeed.gather(project.id.uuidString, of: user.id, in: store)?.seed ?? []
            } catch let error as ResearchExportError {
                throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The project could not be read: \(error.description)")
            }
            let weights = ProjectLeadsSeed.effectiveWeights(projectRaw: project.leadAxisWeights, browserRaw: browserWeights)
            var found = ProjectReach.none
            if let vectors = leads.vectors, case .success(let bundle) = await vectors.bundle() {
                found = await reach(seed: seed, weights: weights, bundle: bundle, shards: vectors, served: served)
            }
            return EditedResponse(headers: [.cacheControl: "no-store"], response: ProjectReachAnswer(found, resources: resources))
        }
    }

    /// The kit's reach of `seed`, its first forty (`Array(seedKeys.prefix(seedCap))`), over the bundled tier and the
    /// served index's volumes.
    @MainActor
    static func reach(seed: [String], weights: AxisWeights, bundle: SemanticBundle, shards: any SemanticShardSource,
                      served: ServedIndex) async -> ProjectReach {
        let host = ServedSemantics(bundle: bundle, shards: shards, served: served).source.host
        return await SemanticProjectReach.reach(seedKeys: Array(seed.prefix(ProjectLeadsSeed.seedCap)), weights: weights, host: host)
    }
}
