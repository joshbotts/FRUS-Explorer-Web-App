// Source Explorer's bundled files (PLAN's S22d): the indexes its panels, its classifier and a collection's record
// read beyond the four the server read already (the central files, the volume sources and the lot claimants, for a
// collection's Sources & Archives block, and the collection authority, for the graph), each the app's `Bundle.main`
// store's file read through the kit's own loader, once, on the first request that needs it, as the app's stores
// decode on first use: nothing is read at start. A file missing or malformed gives nothing, as the app's store
// gives `nil`, and the panel that reads it shows what the app shows without it. A collection's record reads the
// external citations here, for Pointed At, Not Printed (S22d's follow-up), and its Divided at NARA the lot claimants
// the server read already; the app's record reads no usage index.

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
    /// `ChiefsOfMissionRoster.bundled`: the register the pre-1906 addressee rule reads, from `pocom-index.json`;
    /// the app's roster is empty without the file, and so is this.
    let chiefsOfMission = DecodedFile("pocom-index.json") { ChiefsOfMissionRoster(index: try POCOMIndex(contentsOf: $0)) }
    /// `ExternalCitationIndexStore`: the editors' footnotes that point at unprinted material in each collection,
    /// which a collection's record counts under Pointed At, Not Printed.
    let externalCitations = DecodedFile("external-citation-index.json") { try ExternalCitationIndex(contentsOf: $0) }
}
