// Source Explorer's bundled files (PLAN's S22d): the archival indexes the panels, the collection record and
// the classifier read beyond the four the server read already (the central files, the volume sources and the
// lot claimants, for a collection's Sources & Archives block, and the collection authority, for the graph),
// each the app's `Bundle.main` store's file read through the kit's own loader, once, on the first request that
// needs it, as the app's stores decode on first use. A file missing or malformed gives nothing, as the app's
// store gives `nil`, and the panel that reads it shows what the app shows without it.

import FRUSCoreKit
import Foundation

/// One bundled file, decoded once by the kit's loader the first time it is asked for: `nil` for a file
/// missing or malformed, and never decoded again. Two first requests at once wait for one decode.
final class DecodedFile<Value: Sendable>: @unchecked Sendable {
    private let name: String
    private let decode: @Sendable (URL) throws -> Value
    private let lock = NSLock()
    private var held: Value??

    init(_ name: String, _ decode: @escaping @Sendable (URL) throws -> Value) {
        self.name = name
        self.decode = decode
    }

    /// The file in `directory`, decoded, or nil.
    func value(in directory: URL) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        if let held { return held }
        let value = try? decode(directory.appendingPathComponent(name))
        held = .some(value)
        return value
    }

    /// Whether the file has been read, decoded or not.
    var isRead: Bool {
        lock.lock()
        defer { lock.unlock() }
        return held != nil
    }
}

/// The files Source Explorer reads, each the app store named beside it, decoded once on first use.
final class SourceExplorerFiles: Sendable {
    /// `PresidentialLibraryIndexStore`: the library catalogue, 3.3 MB, read only for a library citation.
    let presidentialLibraries = DecodedFile("presidential-library-catalog.json") { try PresidentialLibraryIndex(contentsOf: $0) }
    /// `CuratedLibraryResolutionsStore`: the hand-curated finding aids for library collections.
    let curatedLibraries = DecodedFile("curated-library-resolutions.json") { try CuratedLibraryResolutions(contentsOf: $0) }
    /// `CuratedLotResolutionsStore`: the hand-curated outcomes for lots NARA does not resolve by control number.
    let curatedLots = DecodedFile("curated-lot-resolutions.json") { try CuratedLotResolutions(contentsOf: $0) }
    /// `SeriesFactsIndexStore`: NARA's facts about the series a bundled lot names.
    let seriesFacts = DecodedFile("series-facts-index.json") { try SeriesFactsIndex(contentsOf: $0) }
    /// `DigitizedRangeIndexStore`: the decimal file's scanned ranges.
    let digitizedRanges = DecodedFile("digitized-ranges-index.json") { try DigitizedRangeIndex(contentsOf: $0) }
    /// `RollScansIndexStore`: each Numerical File roll's scan, by its NAID.
    let rollScans = DecodedFile("roll-scans-index.json") { try RollScansIndex(contentsOf: $0) }
    /// `CollectionUsageIndexStore`: the documents each collection's notes name, by volume.
    let collectionUsage = DecodedFile("collection-usage-index.json") { try CollectionUsageIndex(contentsOf: $0) }
    /// `ExternalCitationIndexStore`: the footnotes that point at each collection, by volume.
    let externalCitations = DecodedFile("external-citation-index.json") { try ExternalCitationIndex(contentsOf: $0) }
    /// `ProvenanceFlowIndexStore`: the cross-references between the collections documents were drawn from.
    let provenanceFlows = DecodedFile("provenance-flow-index.json") { try ProvenanceFlowIndex(contentsOf: $0) }
    /// `SubjectNumericLabelStore`: the Subject-Numeric File's labels.
    let subjectNumericLabels = DecodedFile("subject-numeric-labels.json") { try SubjectNumericLabelTable(contentsOf: $0) }
    /// `DecimalClassLabelStore`: the decimal file's class labels, which the indexer reads through its own
    /// resources and keeps to itself.
    let decimalClassLabels = DecodedFile("decimal-class-labels.json") { try DecimalClassLabelTable(contentsOf: $0) }
    /// `ChiefsOfMissionRoster.bundled`: the register the pre-1906 addressee rule reads, from `pocom-index.json`;
    /// the app's roster is empty without the file, and so is this.
    let chiefsOfMission = DecodedFile("pocom-index.json") { ChiefsOfMissionRoster(index: try POCOMIndex(contentsOf: $0)) }
}
