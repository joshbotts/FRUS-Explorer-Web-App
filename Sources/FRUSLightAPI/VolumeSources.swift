// A volume's Sources outline (PLAN's S22d): the app's `VolumeSourcesView`, which Browse opens for a section of
// `divType` "sources". The index's rows (`IndexingPipeline.volumeSources(forVolumeId:)`), in the TEI's order, each
// with its kind, depth, heading flag and text; an outline row also carries what the view draws beside and beneath
// it, the editors' note and, from the kit's `ArchivalResolver.frontMatterResolution`, the catalogue record's
// address, the file series a file unit sits in and the HMS/MLR entry numbers. The view's other affordances, the
// Archival Neighbors button and its count, the collection record's link, the cross-volume link and the line for a
// lot NARA divides, read kit members still internal at this pin, and follow when they are public.

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
            withExtendedLifetime(served) {}
            // The catalogue lookups read the central files, the volume sources and the claimants, and, for a row
            // naming a library's collection with no lot, the library catalogue: each decoded once, off the pool.
            return try await Blocking.run { outline(volumeId: volumeId, entries: entries, resources: resources) }
        }
    }

    /// The rows, as `VolumeSourcesView`'s `sourceNodeRow(_:)` and `resolutionEnrichment(_:lotFile:)` draw them.
    static func outline(volumeId: String, entries: [VolumeSourceEntry], resources: ServerResources) -> VolumeSourcesOutline {
        let archival = resources.archivalIndexes
        let rows = entries.map { entry -> VolumeSourcesOutline.Row in
            var row = VolumeSourcesOutline.Row(kind: entry.kind.rawValue, depth: entry.depth, isHeading: entry.isHeading,
                                               text: entry.rawText)
            // The prose and the published works are plain rows: no note, and no catalogue or neighbours affordance.
            guard entry.kind == .item else { return row }
            if let note = entry.note, !note.isEmpty { row.note = note }
            guard let resolution = ArchivalResolver.frontMatterResolution(
                recordGroup: entry.recordGroup, lotFile: entry.lotFile, entryText: entry.rawText,
                repository: entry.repository, centralFiles: archival.centralFiles,
                volumeSources: archival.volumeSources, claimants: archival.claimants,
                presidentialLibrary: resources.sourceExplorer(\.presidentialLibraries))
            else { return row }
            row.catalogURL = resolution.url?.absoluteString
            if !resolution.isSeriesLevel, let series = resolution.displaySeriesTitle { row.seriesTitle = series }
            if let numbers = resolution.hmsMlrEntryNumbers, !numbers.isEmpty {
                row.entryNumbers = numbers
            } else if let numbers = resolution.seriesHmsMlrEntryNumbers, !numbers.isEmpty {
                row.seriesEntryNumbers = numbers
            }
            return row
        }
        return VolumeSourcesOutline(volumeId: volumeId, rows: rows)
    }
}
