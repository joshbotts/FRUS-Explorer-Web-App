// An archival collection's record (PLAN's S22d): one record of the bundled collection authority, as the app's
// `CollectionDetailView` shows it, from the kit's public readers: the record's identity, names and sub-series
// (`AuthorityCollectionRecord`), the documents of the served index that cite it
// (`IndexingPipeline.localCollectionStats`), and the volumes across the series that cite it, each titled by the
// catalogue. The record's other sections read kit members that are internal at this pin, Related Collections and
// Cited Over Time (`CollectionRelations`), Divided at NARA (`LotClaimantsIndex.claimants(forRawLot:)`), Pointed At,
// Not Printed (`ExternalCitationIndex`'s per-collection counts) and the NARA Catalog link's guard
// (`CentralFilesIndex.isUntrustworthyNAID`), and wait for an upstream pull request that makes them public.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// One record of the collection authority, as the app's collection page shows it.
public struct ArchivalCollectionAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var name: String
    public var repository: String?
    public var recordGroup: String?
    public var lotFileNorm: String?
    /// The other forms FRUS cites it by, in the authority's order.
    public var aliases: [String]
    /// The documents of the served index that cite it, and their volumes (`CollectionLocalStats`).
    public var documentCount: Int
    public var volumeCount: Int
    /// The volumes across the series that cite it, in the authority's order, each with the catalogue's title.
    public var volumes: [Volume]
    /// Its sub-series.
    public var children: [Child]

    public struct Volume: Codable, Equatable, Sendable {
        public var volumeId: String
        /// The catalogue's title, or none for a volume it does not list, which the page names by its id.
        public var title: String?
    }

    public struct Child: Codable, Equatable, Sendable {
        public var name: String
        /// The central-file class whose documents its neighbours are, when it has one.
        public var decimalClass: String?
        public var volumeCount: Int
    }
}

enum ArchivalCollectionRoutes {
    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/archival-collection") { request, _ -> ArchivalCollectionAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["id"])
            guard let id = try query.single("id")?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
                throw APIProblem.invalidParameter("id", "name a record of the collection authority")
            }
            // The authority is 2 MB of JSON, decoded once, off the cooperative pool.
            guard let record = try await Blocking.run({ try resources.collectionAuthorityRecord(id) }) else {
                throw APIProblem(.notFound, code: "COLLECTION_NOT_FOUND", detail: "The collection authority has no record \(id).")
            }
            let served = try await provider.served()
            // `loadLocalStats`: the record's lot, repository, record group and every name it is cited by; a query
            // that fails counts nothing, as the app's `try?` does.
            let stats = (try? await served.pipeline.localCollectionStats(
                lotFileNorm: record.lotFileNorm, repository: record.repository, recordGroup: record.recordGroup,
                names: [record.name] + record.aliases)) ?? IndexingPipeline.CollectionLocalStats(documentCount: 0, volumeCount: 0)
            withExtendedLifetime(served) {}
            return ArchivalCollectionAnswer(
                id: record.id, name: record.name, repository: record.repository, recordGroup: record.recordGroup,
                lotFileNorm: record.lotFileNorm, aliases: record.aliases,
                documentCount: stats.documentCount, volumeCount: stats.volumeCount,
                volumes: record.volumeIds.map { ArchivalCollectionAnswer.Volume(volumeId: $0, title: resources.volume($0)?.title) },
                children: record.children.map {
                    ArchivalCollectionAnswer.Child(name: $0.name, decimalClass: $0.decimalClass, volumeCount: $0.volumeIds.count)
                })
        }
    }
}
