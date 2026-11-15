// A volume's Sources outline (PLAN's S22d and its follow-up): the app's `VolumeSourcesView`, which Browse opens for a
// section of `divType` "sources". The index's rows (`IndexingPipeline.volumeSources(forVolumeId:)`), in the TEI's
// order, each with its kind, depth, heading flag and text; an outline row also carries what `sourceNodeRow` draws
// beside and beneath it: the catalogue record's address, the file series a file unit sits in and the HMS/MLR entry
// numbers, from the kit's `ArchivalResolver.frontMatterResolution`; the editors' note; the Archival Neighbors button,
// its keys as the view's `makeNeighborsTarget` builds them, mirrored, with the library route from the kit's
// `IndexingPipeline.isLibraryRepository(_:)`, and its count from one batched query
// (`archivalNeighborCounts(forKeys:)`); the collection authority's record the row resolves to
// (`CollectionAuthorityIndex.record(forFrontMatterText:…)`); a heading's volumes where the authority has no record
// (`VolumeSourcesIndex.authority(recordGroup:lotFile:text:)`); and, where the row resolves to no record, the series
// NARA divides its lot across (`ArchivalResolver.dividedLotClaimants(lotFile:claimants:)`).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// A volume's Sources section, as the app's `VolumeSourcesView` lists it.
public struct VolumeSourcesOutline: Codable, Equatable, Sendable, ResponseEncodable {
    public var volumeId: String
    /// The index's rows in the TEI's order: the narrative paragraphs, the outline's rows, each after its parent,
    /// and the published works. Empty when the index holds no Sources section for the volume.
    public var rows: [Row]

    /// One row of the section (`VolumeSourceEntry`).
    public struct Row: Codable, Equatable, Sendable {
        /// `prose`, `item` or `bibliography` (`VolumeSourceKind`): About These Sources, Archival Collections or
        /// Published Sources.
        public var kind: String
        /// An outline row's depth, 0 for a top-level collection.
        public var depth: Int
        /// Whether an outline row is a major named collection, which the view sets in bold.
        public var isHeading: Bool
        public var text: String
        /// The editors' description of an outline row's collection, where the encoding writes it apart.
        public var note: String?
        /// The catalogue record an outline row resolves to.
        public var catalogURL: String?
        /// The file series the resolved record sits in, when the record is a file unit (`displaySeriesTitle`).
        public var seriesTitle: String?
        /// The resolved record's HMS/MLR entry numbers.
        public var entryNumbers: [String]?
        /// Its series' entry numbers, where the record carries none of its own.
        public var seriesEntryNumbers: [String]?
        /// The Archival Neighbors button, for a row with a key the kit's neighbour queries match on.
        public var neighbours: Neighbours?
        /// The collection authority's record the row resolves to, which its Collection link opens.
        public var collection: Collection?
        /// The volumes that cite a heading the authority has no record for, where more than one does: the link
        /// to them.
        public var crossVolume: [Volume]?
        /// How many series NARA divides the row's lot across, where the row resolves to no catalogue record.
        public var dividedSeriesCount: Int?
    }

    /// A row's Archival Neighbors button (`VolumeSourceNeighborsTarget`): the keys its neighbours are asked for by,
    /// anchored on the volume, and how many indexed documents they match.
    public struct Neighbours: Codable, Equatable, Sendable {
        public var lotFile: String?
        public var recordGroup: String?
        public var series: String?
        /// Set only where the row takes the presidential library's route.
        public var repository: String?
        public var decimalClass: String?
        public var jobNumber: String?
        /// The record whose lot and names the neighbours' matcher tries when the row's own keys match nothing
        /// (`CollectionAliasFallback(record:)`): the row's collection's.
        public var aliasCollection: String?
        /// The indexed documents the row's keys match, by their direct keys alone; none while the count is unknown,
        /// where the batch failed, when the button is drawn plain.
        public var count: Int?
    }

    /// The record a row resolves to: its id in the authority, and how many volumes across the series cite it.
    public struct Collection: Codable, Equatable, Sendable {
        public var id: String
        public var volumeCount: Int
    }

    /// A volume that cites a heading, with the catalogue's title, or none for a volume it does not list.
    public struct Volume: Codable, Equatable, Sendable {
        public var volumeId: String
        public var title: String?
    }
}

enum VolumeSourcesRoutes {
    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/volumes/:volumeId/sources") { request, context -> VolumeSourcesOutline in
            try FormQuery(request.uri.query).refuseUnknown([])
            let volumeId = try context.parameters.require("volumeId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            let served = try await provider.served()
            let entries = try await served.pipeline.volumeSources(forVolumeId: volumeId)
            // `loadNeighborCounts`: ONE batched query for every keyed row, never one a row; a batch that fails counts
            // none, and each row's button is then drawn plain, as the app's `try?` leaves `neighborCounts` nil.
            let keys = entries.compactMap { entry -> IndexingPipeline.ArchivalNeighborCountKey? in
                guard let target = neighboursTarget(for: entry) else { return nil }
                return countKey(target)
            }
            let counts = keys.isEmpty
                ? [:]
                : try? await served.pipeline.archivalNeighborCounts(forKeys: keys)
            withExtendedLifetime(served) {}
            // The catalogue lookups read the central files, the volume sources and the claimants, and, for a row
            // naming a library's collection with no lot, the library catalogue; the Collection links the authority:
            // each decoded once, off the pool.
            return try await Blocking.run { outline(volumeId: volumeId, entries: entries, counts: counts, resources: resources) }
        }
    }

    /// The rows, as `VolumeSourcesView`'s `sourceNodeRow(_:)` and `resolutionEnrichment(_:lotFile:)` draw them, with the
    /// neighbour counts `counts` gives, by each row's key, or none for a batch that failed.
    static func outline(volumeId: String, entries: [VolumeSourceEntry],
                        counts: [IndexingPipeline.ArchivalNeighborCountKey: Int]?,
                        resources: ServerResources) -> VolumeSourcesOutline {
        let archival = resources.archivalIndexes
        let rows = entries.map { entry -> VolumeSourcesOutline.Row in
            var row = VolumeSourcesOutline.Row(kind: entry.kind.rawValue, depth: entry.depth, isHeading: entry.isHeading,
                                               text: entry.rawText)
            // The prose and the published works are plain rows: no note, and no catalogue or neighbours affordance.
            guard entry.kind == .item else { return row }
            if let note = entry.note, !note.isEmpty { row.note = note }
            let resolution = ArchivalResolver.frontMatterResolution(
                recordGroup: entry.recordGroup, lotFile: entry.lotFile, entryText: entry.rawText,
                repository: entry.repository, centralFiles: archival.centralFiles,
                volumeSources: archival.volumeSources, claimants: archival.claimants,
                presidentialLibrary: resources.sourceExplorer(\.presidentialLibraries))
            // Phase 4: the collection authority's record the row resolves to, by the shared front-matter identity.
            let authority = resources.collectionAuthority?.record(
                forFrontMatterText: entry.rawText, repository: entry.repository,
                lotFileNorm: entry.lotFileNorm, decimalClass: entry.decimalClass)
            // The legacy cross-volume fallback for headings the authority does not track.
            let crossVolume: MajorCollectionRecord? = (entry.isHeading && authority == nil)
                ? archival.volumeSources?.authority(
                    recordGroup: entry.recordGroup, lotFile: entry.lotFile, text: entry.rawText)
                : nil
            if let target = neighboursTarget(for: entry) {
                row.neighbours = target
                // The authority record's lot key and alias forms ride along for the matcher's fallback: the record,
                // whose `CollectionAliasFallback(record:)` the neighbours' route builds.
                if let authority { row.neighbours?.aliasCollection = authority.id }
                row.neighbours?.count = counts.flatMap { counts in countKey(target).map { counts[$0] ?? 0 } }
            }
            // `resolutionEnrichment`: where NARA divided the lot, the resolver gives nothing, and the row says why.
            if resolution == nil, let claimants = ArchivalResolver.dividedLotClaimants(lotFile: entry.lotFile, claimants: archival.claimants) {
                row.dividedSeriesCount = claimants.count
            }
            if let resolution {
                row.catalogURL = resolution.url?.absoluteString
                if !resolution.isSeriesLevel, let series = resolution.displaySeriesTitle { row.seriesTitle = series }
                if let numbers = resolution.hmsMlrEntryNumbers, !numbers.isEmpty {
                    row.entryNumbers = numbers
                } else if let numbers = resolution.seriesHmsMlrEntryNumbers, !numbers.isEmpty {
                    row.seriesEntryNumbers = numbers
                }
            }
            if let authority {
                row.collection = .init(id: authority.id, volumeCount: authority.volumeIds.count)
            } else if let crossVolume, crossVolume.volumeIds.count > 1 {
                row.crossVolume = crossVolume.volumeIds.map { .init(volumeId: $0, title: resources.volume($0)?.title) }
            }
            return row
        }
        return VolumeSourcesOutline(volumeId: volumeId, rows: rows)
    }

    /// `VolumeSourcesView.makeNeighborsTarget(for:volumeId:)`, app code, mirrored: the keys a row's neighbours are asked
    /// for by, or none for a row with no key on any path, which has no button. A library's row takes its own text as
    /// the collection's name where it names no series (the kit's `IndexingPipeline.isLibraryRepository(_:)` decides a
    /// library), and the library's heading, whose text names the repository, takes none.
    static func neighboursTarget(for entry: VolumeSourceEntry) -> VolumeSourcesOutline.Neighbours? {
        guard entry.kind == .item else { return nil }
        func trimmed(_ s: String?) -> String? {
            guard let t = s?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
            return t
        }
        let lot  = trimmed(entry.lotFile)
        let cls  = trimmed(entry.decimalClass)
        let job  = trimmed(entry.jobNumber)
        let rg   = trimmed(entry.recordGroup)
        let repo = trimmed(entry.repository)
        var series = trimmed(entry.seriesName)
        var libraryRepo: String? = nil
        if let repo, IndexingPipeline.isLibraryRepository(repo) {
            if series == nil,
               !entry.rawText.localizedCaseInsensitiveContains(repo),
               entry.rawText.count >= 4 {
                series = entry.rawText
            }
            if series != nil { libraryRepo = repo }
        }
        let hasKey = lot != nil || cls != nil || libraryRepo != nil || job != nil
            || (rg != nil && series != nil)
        guard hasKey else { return nil }
        return .init(lotFile: lot, recordGroup: rg, series: series, repository: libraryRepo, decimalClass: cls, jobNumber: job)
    }

    /// The kit's count key for a row's keys (`IndexingPipeline.neighborCountKey`), as `neighborCount(for:)` and
    /// `loadNeighborCounts` derive it.
    static func countKey(_ target: VolumeSourcesOutline.Neighbours) -> IndexingPipeline.ArchivalNeighborCountKey? {
        IndexingPipeline.neighborCountKey(
            forLotFile: target.lotFile, recordGroup: target.recordGroup,
            series: target.series, repository: target.repository,
            decimalClass: target.decimalClass,
            jobNumber: target.jobNumber)
    }
}
