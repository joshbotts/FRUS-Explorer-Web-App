// Check 8's year (PLAN's S25b): the year both of the app's Source Explorer views read from a dateline, asked of the kit
// itself through its public resolution, as the server's route asks it. The rule is the kit's own and internal
// (`CentralFilesClassifier.documentYear(fromDateline:)`, which the document context's hydration applies when a route
// passes no year): the year of the dateline's first `Month D, YYYY`, the sent date, else its first whole year from 1800
// to 2029. The API's answer names the dateline the kit hydrated, so the kit's reading of that dateline is exactly the
// year the API must give. This file imports FRUSCoreKit, which shares names with the generator's cores, so that
// `SourceExplorerCheck`, which imports the cores, asks the kit through it alone.

import FRUSCoreKit
import Foundation

/// The kit's reading of a dateline's year, through `SourceExplorerResolution`.
public struct KitViewsYear: Sendable {
    let dependencies: SourceExplorerResolution.Dependencies

    public init() {
        // A note-less resolution with no index and no bundled files: what the hydration reads is the route alone.
        dependencies = SourceExplorerResolution.Dependencies(
            collectionAuthority: nil, centralFiles: nil, chiefsOfMission: .empty, presidentialLibraries: nil,
            curatedLibraries: nil, parsedDocuments: NoDocuments(), volumeURL: nil)
    }

    /// The year the app's views read from `dateline`, as the server's route asks the kit for it: the dateline on the
    /// route, no year passed, and no index to hydrate from.
    public func year(dateline: String?) async -> Int? {
        let route = CountrySeriesRoute(header: "", dateline: dateline, year: nil, volumeId: nil, documentId: nil)
        return await SourceExplorerResolution(rawSourceNote: "").resolved(route: route, pipeline: nil, dependencies: dependencies)
            .documentContext?.year
    }
}

/// A source of parsed documents that holds none.
private struct NoDocuments: DocumentASTSource {
    func ast(volumeId: String, documentId: String) async -> FRUSDocumentAST? { nil }
    func store(_ documents: [FRUSDocumentAST], volumeId: String) async {}
}
