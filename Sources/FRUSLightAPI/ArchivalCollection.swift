// An archival collection's record (PLAN's S22d and its follow-up): one record of the bundled collection authority,
// as the app's `CollectionDetailView` shows it, every section from the kit's public readers. The record's identity,
// names and sub-series (`AuthorityCollectionRecord`); its NARA Catalog link, past the central files' guard against
// mis-resolved NAIDs (`CentralFilesIndex.isUntrustworthyNAID`); the documents of the served index that cite it
// (`IndexingPipeline.localCollectionStats`); Related Collections and Cited Over Time (`CollectionRelations`); Divided
// at NARA (`LotClaimantsIndex.claimants(forRawLot:)` and `lots`); Pointed At, Not Printed (`ExternalCitationIndex`'s
// per-collection counts); and the volumes across the series that cite it, each titled by the catalogue. Each
// section's condition is the view's, mirrored here and held to the app's source by `SourceExplorerParityTests`.

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
    /// How many rows each capped list shows before Show all, the kit's `CollectionRelations.previewRowCap`.
    public var previewRowCap: Int
    /// The NARA Catalog section, where the record has a catalogue address the central files do not mark as a
    /// mis-resolution (the view's `showsCatalogLink`).
    public var catalog: Catalog?
    /// Related Collections, best first, for a record citing two or more volumes; none where the view shows no such
    /// section, and empty where it says no collection is cited alongside.
    public var related: [Related]?
    /// Cited Over Time, where the citing volumes reach two or more coverage eras.
    public var timeline: Timeline?
    /// Divided at NARA, where NARA divided the record's lot across several series.
    public var divided: Divided?
    /// Pointed At, Not Printed, where editors' footnotes point at unprinted material in the record.
    public var pointers: Pointers?

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

    /// The record's catalogue link and the NAID the section names beside it.
    public struct Catalog: Codable, Equatable, Sendable {
        public var url: String
        public var naId: String?
    }

    /// A collection cited alongside this one (`RelatedCollection`), which opens its own record.
    public struct Related: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var repository: String?
        public var recordGroup: String?
        /// The volumes that cite both.
        public var sharedVolumeCount: Int
        /// The overlap coefficient the list is ranked by, in 0...1.
        public var overlap: Double
    }

    /// The citing volumes by coverage era (`CollectionEraCount`), contiguous from the first era with volumes to the
    /// last, and the kit's reading of them (`CollectionRelations.timelineNarrative(for:)`).
    public struct Timeline: Codable, Equatable, Sendable {
        public var eras: [Era]
        public var narrative: String

        public struct Era: Codable, Equatable, Sendable {
            /// The axis's form, `’61–63` (`CollectionCoverageEra.shortLabel`).
            public var shortLabel: String
            /// The prose and the table's form, `1961–1963` (`fullLabel`).
            public var fullLabel: String
            public var volumeCount: Int
        }
    }

    /// The NARA series claiming the record's lot (`LotClaimant`), in the index's order.
    public struct Divided: Codable, Equatable, Sendable {
        public var claimants: [Claimant]
        /// Whether the record's own NAID, the catalogue link's, is one of them.
        public var includesRecordsNAID: Bool
        /// How many lots the index lists, each claimed by more than one series: the section's footer.
        public var dividedLots: Int

        public struct Claimant: Codable, Equatable, Sendable {
            public var naId: String
            public var title: String
            public var recordGroup: String?
            /// Its HMS/MLR entry numbers.
            public var entryNumbers: [String]?
            /// Its span, as NARA states it.
            public var dateRange: String?
            /// Its catalogue record, where the address parses, as the view's link needs.
            public var catalogURL: String?
        }
    }

    /// The editors' footnotes that point at unprinted material in the record, and the volumes they are in.
    public struct Pointers: Codable, Equatable, Sendable {
        public var total: Int
        /// The volumes in the index's order, each with the catalogue's title and its count.
        public var volumes: [Volume]

        public struct Volume: Codable, Equatable, Sendable {
            public var volumeId: String
            public var title: String?
            public var count: Int
        }
    }
}

/// A record's citing documents in the served index, every one, as its In Your Library's Add to an Archives Visit seeds a
/// plan from them (PLAN's S30d).
public struct ArchivalCollectionDocuments: Codable, Equatable, Sendable, ResponseEncodable {
    /// The record's name, which the picker's basis quotes and a plan made from them takes.
    public var name: String
    /// How many documents cite it, which `documents` holds all of below the fetch's ceiling.
    public var totalCount: Int
    public var documents: [Document]

    public struct Document: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
    }
}

enum ArchivalCollectionRoutes {
    /// The citing set's fetch ceiling (`planSeedFetchCeiling`): above the corpus's largest unit, 17,613, so the fetch is
    /// whole in practice; one capped by it says so, as the picker's basis does.
    static let planSeedFetchCeiling = 20_000

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        // `fetchCitingDocumentsForPlan(expected:)`: every indexed document drawn from the record, the match Archival
        // Neighbors runs over its own fields (`collectionNeighbors`), with the limit raised to the ceiling; a query that
        // fails gives none, as the app's `try?` gives no picker.
        router.get("/api/v1/archival-collection/documents") { request, _ -> ArchivalCollectionDocuments in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["id"])
            guard let id = try query.single("id")?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
                throw APIProblem.invalidParameter("id", "name a record of the collection authority")
            }
            guard let record = try await Blocking.run({ try resources.collectionAuthorityRecord(id) }) else {
                throw APIProblem(.notFound, code: "COLLECTION_NOT_FOUND", detail: "The collection authority has no record \(id).")
            }
            let served = try await provider.served()
            let result = (try? await served.pipeline.collectionNeighbors(
                lotFileNorm: record.lotFileNorm, repository: record.repository, recordGroup: record.recordGroup,
                names: [record.name] + record.aliases, limit: planSeedFetchCeiling)) ?? (documents: [], totalCount: 0, basis: nil)
            withExtendedLifetime(served) {}
            return ArchivalCollectionDocuments(
                name: record.name, totalCount: result.totalCount,
                documents: result.documents.map { .init(volumeId: $0.volumeId, documentId: $0.documentId) })
        }
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
            // The sections from the bundled files: the central files, the claimants and the external citations, each
            // decoded once, and the ranking over every record of the authority, off the cooperative pool, as the app
            // ranks off the main actor.
            return try await Blocking.run {
                answer(record: record, stats: stats, resources: resources)
            }
        }
    }

    /// The record's answer, every section the view draws for it, in the view's words for what chooses each.
    static func answer(record: AuthorityCollectionRecord, stats: IndexingPipeline.CollectionLocalStats,
                       resources: ServerResources) -> ArchivalCollectionAnswer {
        let archival = resources.archivalIndexes
        var answer = ArchivalCollectionAnswer(
            id: record.id, name: record.name, repository: record.repository, recordGroup: record.recordGroup,
            lotFileNorm: record.lotFileNorm, aliases: record.aliases,
            documentCount: stats.documentCount, volumeCount: stats.volumeCount,
            volumes: record.volumeIds.map { ArchivalCollectionAnswer.Volume(volumeId: $0, title: resources.volume($0)?.title) },
            children: record.children.map {
                ArchivalCollectionAnswer.Child(name: $0.name, decimalClass: $0.decimalClass, volumeCount: $0.volumeIds.count)
            },
            previewRowCap: CollectionRelations.previewRowCap)
        // `showsCatalogLink`: the record's address, unless the central files trace its NAID to a mis-resolution
        // (#351); with no central files the link shows, as the app's `!= true` reads a missing store.
        let showsCatalogLink = record.url != nil && archival.centralFiles?.isUntrustworthyNAID(record.naId) != true
        if showsCatalogLink, let url = record.url {
            answer.catalog = .init(url: url.absoluteString, naId: record.naId)
        }
        // Related Collections, for a record citing at least the kit's `minimumSharedVolumes`, ranked over every
        // record, or none for an authority missing, as `loadRelated` ranks none.
        if record.volumeIds.count >= CollectionRelations.minimumSharedVolumes {
            let ranked = resources.collectionAuthority.map { CollectionRelations.related(to: record, in: $0.collections) } ?? []
            answer.related = ranked.map {
                ArchivalCollectionAnswer.Related(id: $0.record.id, name: $0.record.name, repository: $0.record.repository,
                                                 recordGroup: $0.record.recordGroup, sharedVolumeCount: $0.sharedVolumeCount,
                                                 overlap: $0.overlap)
            }
        }
        // Cited Over Time: `loadTimeline`, each citing volume's midpoint from the catalogue's date range; the section
        // only where it buckets anything.
        let midpoints = record.volumeIds.compactMap { volumeId -> Int? in
            guard let entry = resources.volume(volumeId) else { return nil }
            return CollectionRelations.midpointYear(earliest: entry.dateRange.earliest, latest: entry.dateRange.latest)
        }
        let timeline = CollectionRelations.citedOverTime(volumeMidpoints: midpoints)
        if !timeline.isEmpty {
            answer.timeline = .init(
                eras: timeline.map { .init(shortLabel: $0.era.shortLabel, fullLabel: $0.era.fullLabel, volumeCount: $0.volumeCount) },
                narrative: CollectionRelations.timelineNarrative(for: timeline))
        }
        // Divided at NARA: `dividedLotClaimants`, the claimants of a lot-keyed record's lot, where NARA divided it.
        if let lot = record.lotFileNorm, let claimants = archival.claimants?.claimants(forRawLot: lot) {
            answer.divided = .init(
                claimants: claimants.map {
                    .init(naId: $0.naId, title: $0.title, recordGroup: $0.recordGroup, entryNumbers: $0.hmsMlrEntryNumbers,
                          dateRange: $0.dateRange, catalogURL: URL(string: $0.catalogURL) == nil ? nil : $0.catalogURL)
                },
                includesRecordsNAID: record.naId.map { naId in claimants.contains(where: { $0.naId == naId }) } ?? false,
                dividedLots: archival.claimants?.lots.count ?? 0)
        }
        // Pointed At, Not Printed: `unprintedPointers`, the record's references and their volumes, or none for an
        // index missing; the section only where they are more than none.
        if let index = resources.sourceExplorer(\.externalCitations) {
            let total = index.referenceCount(forCollectionId: record.id)
            if total > 0 {
                answer.pointers = .init(total: total, volumes: index.volumeCounts(forCollectionId: record.id).map {
                    .init(volumeId: $0.volumeId, title: resources.volume($0.volumeId)?.title, count: $0.count)
                })
            }
        }
        return answer
    }
}
