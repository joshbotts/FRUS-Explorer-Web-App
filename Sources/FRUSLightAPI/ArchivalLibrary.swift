// Archival Analytics' Your Library mode (PLAN's S24h): the archival profile of the volumes the served index holds, as
// the app's `ArchivalAnalyticsView` counts it in the volumes its reader has indexed. The profile is the kit's
// `ArchivalLibraryProfile.make` over the pipeline's two grouped queries (`archivalLibraryGroups()`,
// `archivalLibraryCollectionGroups()`), the series' coverage and the authority, as the view's `loadLibraryIfNeeded()`
// loads it, computed once for the served index and kept (`ServedIndex.archivalLibrary`); a query that fails leaves the
// profile empty, as the view's does. The cards, their tables and words are the view's, mirrored under its names.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// Your Library's cards (`yourLibraryMode`).
public struct ArchivalLibraryAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// "No Source Notes Yet", when the index holds no source note.
    public var empty: Empty?
    /// The intro, whose `**…**` the browser sets in bold, as the app's Markdown body does.
    public var intro: String
    public var composition: Composition
    public var bands: Bands
    public var collections: Collections
    public var footer: Footer

    public struct Empty: Codable, Equatable, Sendable {
        public var title: String
        public var detail: String
    }

    public struct Composition: Codable, Equatable, Sendable {
        public var title: String
        public var caption: String
        public var axisLabel: String
        public var legendTitle: String
        public var items: [Item]
        public var table: CorpusAnalyticsAnswer.Table

        public struct Item: Codable, Equatable, Sendable {
            public var category: String
            public var categoryName: String
            public var documents: Int
            public var share: String
            public var accessibilityValue: String
        }
    }

    public struct Bands: Codable, Equatable, Sendable {
        public var title: String
        public var caption: String
        public var xLabel: String
        public var yLabel: String
        public var legendTitle: String
        public var items: [Item]
        public var table: CorpusAnalyticsAnswer.Table

        public struct Item: Codable, Equatable, Sendable {
            public var band: String
            public var category: String
            public var categoryName: String
            public var documents: Int
        }
    }

    public struct Collections: Codable, Equatable, Sendable {
        public var title: String
        public var caption: String
        public var empty: String?
        public var hint: String
        public var rows: [Row]
        public var table: CorpusAnalyticsAnswer.Table

        public struct Row: Codable, Equatable, Sendable {
            public var id: String
            public var name: String
            public var repository: String?
            public var count: String
        }
    }

    public struct Footer: Codable, Equatable, Sendable {
        public var title: String
        public var lines: [String]
    }
}

enum ArchivalLibraryRoutes {
    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/analytics/archives/library") { request, _ -> ArchivalLibraryAnswer in
            try FormQuery(request.uri.query).refuseUnknown([])
            let served = try await provider.served()
            let profile = try await profile(served: served, resources: resources)
            let answer = ArchivalLibraryView(profile: profile, indexedVolumeCount: served.indexedVolumeIds.count,
                                             corpusVolumeCount: resources.manifest.count).answer()
            withExtendedLifetime(served) {}
            return answer
        }
    }

    /// The view's `loadLibraryIfNeeded()`, once for the served index and kept: the pipeline's two grouped queries over
    /// the series' coverage and the authority, or the empty profile when a query fails. A failure is not kept, so the
    /// next visit asks again, as the app's view does.
    static func profile(served: ServedIndex, resources: ServerResources) async throws -> ArchivalLibraryProfile {
        do {
            return try await served.archivalLibrary.value(for: 0) {
                let pipeline = served.pipeline
                let (coverage, authority) = try await Blocking.run {
                    let coverage = ArchivalVolumeCoverage.map(from: resources.manifest, limitedTo: nil)
                    let authority = resources.collectionAuthority
                    return (coverage, authority)
                }
                let groups = try await pipeline.archivalLibraryGroups()
                let collectionGroups = try await pipeline.archivalLibraryCollectionGroups()
                return ArchivalLibraryProfile.make(
                    groups: groups, collectionGroups: collectionGroups,
                    coverage: coverage, authority: authority)
            }
        } catch {
            return .empty
        }
    }
}

/// What `ArchivalAnalyticsView`'s Your Library cards decide, under their names; held to the app's source by the mirror
/// test.
struct ArchivalLibraryView {
    let profile: ArchivalLibraryProfile
    /// The served index's volumes, the footer's "you have indexed" and the statement's.
    let indexedVolumeCount: Int
    /// The series' volumes (`corpusVolumeCount`).
    let corpusVolumeCount: Int

    static func percentString(_ value: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        return (Double(value) / Double(total))
            .formatted(.percent.precision(.fractionLength(0...1)).locale(SearchItem.locale))
    }

    var intro: String {
        String(format: appWords("archival.library.intro %lld %lld",
                                "The archival profile of **your** library — computed from the %1$lld source notes across the %2$lld indexed volumes that carry them, not from the bundled corpus-wide aggregates."),
               Int64(profile.noteCount), Int64(profile.volumeCount))
    }

    static let compositionTitle = appWords("archival.library.composition.title", "Where your documents come from")
    static let bandsTitle = appWords("archival.library.bands.title", "Citation forms across your volumes")
    static let collectionsTitle = appWords("archival.library.collections.title", "Your most-cited collections")

    var compositionTable: ChartInspectorData {
        ChartInspectorData(
            id: "archival.library.composition",
            title: Self.compositionTitle,
            columns: [
                appWords("archival.table.provenance", "Provenance"),
                appWords("archival.table.documents", "Documents"),
                appWords("archival.table.share", "Share"),
            ],
            rowCells: profile.composition.map {
                [$0.category.displayName, "\($0.documentCount)",
                 Self.percentString($0.documentCount, of: profile.noteCount)]
            })
    }

    var bandsTable: ChartInspectorData {
        ChartInspectorData(
            id: "archival.library.bands",
            title: Self.bandsTitle,
            columns: [
                appWords("archival.filter.era", "Era"),
                appWords("archival.table.provenance", "Provenance"),
                appWords("archival.table.documents", "Documents"),
            ],
            rowCells: profile.bands.flatMap { band in
                band.categories.map {
                    [band.band.title, $0.category.displayName, "\($0.documentCount)"]
                }
            })
    }

    var collectionsTable: ChartInspectorData {
        ChartInspectorData(
            id: "archival.library.collections",
            title: Self.collectionsTitle,
            columns: [
                appWords("archival.table.unit", "Archival unit"),
                appWords("archival.table.custodian", "Custodian"),
                appWords("archival.table.documents", "Documents"),
            ],
            rowCells: profile.collections.map {
                [$0.record.name,
                 $0.record.repository ?? ArchivalRepositoryCategory.from($0.record).displayName,
                 "\($0.documentCount)"]
            })
    }

    func provenance(title: String, axisLabel: String) -> AnalyticsProvenance {
        ArchivalAnalyticsExport.library(
            title: title, axisLabel: axisLabel,
            profile: profile, indexedVolumeCount: indexedVolumeCount,
            corpusVolumeCount: corpusVolumeCount)
    }

    /// A card's table and statement, as its export control makes them.
    func export(_ chart: ArchivalAnalyticsChart) -> (ChartInspectorData, AnalyticsProvenance) {
        switch chart {
        case .bands:
            return (bandsTable, provenance(title: Self.bandsTitle,
                                           axisLabel: appWords("archival.export.axis.bands", "Divided by coverage era and kind of collection")))
        case .collections:
            return (collectionsTable, provenance(title: Self.collectionsTitle,
                                                 axisLabel: appWords("archival.export.axis.collections", "Ranked by documents drawn from the collection")))
        default:
            return (compositionTable, provenance(title: Self.compositionTitle,
                                                 axisLabel: appWords("archival.export.axis.composition", "Divided by kind of archival collection")))
        }
    }

    var footer: ArchivalLibraryAnswer.Footer {
        let indexed = indexedVolumeCount
        let total = corpusVolumeCount
        return .init(title: appWords("archival.caveats.measured", "Measured here"), lines: [
            String(format: appWords("archival.library.footer %lld %lld",
                                    "Counted from the %1$lld volumes you have indexed. %2$lld more exist in the series."),
                   Int64(indexed), Int64(max(total - indexed, 0))),
            String(format: appWords("archival.library.footer.detail %lld %lld",
                                    "%1$lld notes cite the central files, counted in the composition above. Another %2$lld name something the app’s archival authority list does not recognize."),
                   Int64(profile.centralFileNoteCount),
                   Int64(profile.unresolvedCollectionNoteCount)),
        ])
    }

    func answer() -> ArchivalLibraryAnswer {
        let documents = appWords("archival.table.documents", "Documents")
        let provenanceLegend = appWords("archival.table.provenance", "Provenance")
        return ArchivalLibraryAnswer(
            empty: profile.isEmpty
                ? .init(title: appWords("archival.library.empty.title", "No Source Notes Yet"),
                        detail: appWords("archival.library.empty.detail", "Download and index a volume and this page will show where its documents came from. The Collections mode works without any downloads."))
                : nil,
            intro: intro,
            composition: .init(
                title: Self.compositionTitle,
                caption: appWords("archival.library.composition.caption", "Every source note in your index, divided among the kinds of archival collection they cite."),
                axisLabel: documents, legendTitle: provenanceLegend,
                items: profile.composition.map {
                    .init(category: $0.category.rawValue, categoryName: $0.category.displayName, documents: $0.documentCount,
                          share: Self.percentString($0.documentCount, of: profile.noteCount),
                          accessibilityValue: String(format: appWords("archival.library.composition.a11y %lld %@", "%1$lld documents, %2$@"),
                                                     Int64($0.documentCount), Self.percentString($0.documentCount, of: profile.noteCount)))
                },
                table: ArchivalTables.table(compositionTable)),
            bands: .init(
                title: Self.bandsTitle,
                caption: appWords("archival.library.bands.caption", "The same composition, split by the era your volumes cover. Read left to right it is the shift from the State Department’s decimal file, through the postwar bureau lot files, to the presidential libraries."),
                xLabel: appWords("archival.filter.era", "Era"), yLabel: documents, legendTitle: provenanceLegend,
                items: profile.bands.flatMap { band in
                    band.categories.map {
                        .init(band: band.band.title, category: $0.category.rawValue, categoryName: $0.category.displayName,
                              documents: $0.documentCount)
                    }
                },
                table: ArchivalTables.table(bandsTable)),
            collections: .init(
                title: Self.collectionsTitle,
                caption: String(format: appWords("archival.library.collections.caption.v2 %lld %lld",
                                                 "Matched from your own source notes against the archival authority list in the app. %1$lld notes cite the central files, which are filing systems rather than collections. Another %2$lld name something the list does not recognize. Neither group is listed here."),
                                Int64(profile.centralFileNoteCount),
                                Int64(profile.unresolvedCollectionNoteCount)),
                empty: profile.collections.isEmpty
                    ? appWords("archival.library.collections.empty", "None of your volumes’ source notes name a collection the bundled authority recognizes.")
                    : nil,
                hint: appWords("archival.library.collections.hint", "Shows the documents in your index drawn from this collection"),
                rows: profile.collections.map {
                    .init(id: $0.record.id, name: $0.record.name, repository: $0.record.repository,
                          count: String(format: appWords("archival.library.collections.count %lld", "%lld docs"), Int64($0.documentCount)))
                },
                table: ArchivalTables.table(collectionsTable)),
            footer: footer)
    }
}
