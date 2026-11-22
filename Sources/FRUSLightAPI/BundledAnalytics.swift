// The bundled files Archival Analytics and About the Series read (PLAN's S24h), and what they compute from them, each
// once for the bundle and kept. The files are the app's `Bundle.main` stores', read through the kit's own loaders on the
// first request that needs them, as the app's stores decode on first use: the collection usage index, the provenance
// flows, the decimal-class and subject-numeric label tables, the source-provenance index and the tag taxonomy; the
// authority, the external citations and the administrations' profiles the server read already (`ServerResources`). A
// file missing or malformed gives nothing, as the app's store gives `nil`, and the surface that reads it says what the
// app says without it. The series are the kit's, each computed once for its scope, or its focus, and kept while the
// server runs, as S24f's `ServedIndex.analytics` and S24g's `KeptSeries` keep theirs for an index: the bundle does not
// change while the server runs, so a series computed from it never goes stale.

import FRUSCoreKit
import Foundation

/// The bundled files and the series kept from them (PLAN's S24h).
final class BundledAnalytics: Sendable {
    /// `CollectionUsageIndexStore.shared`: the documents each collection supplied, by volume, which the Documents weight,
    /// the network's shared-documents measure and the Your Library composition read.
    let usage = DecodedFile("collection-usage-index.json") { try CollectionUsageIndex(contentsOf: $0) }
    /// `ProvenanceFlowIndexStore.shared`: the cross-references between collections, which Flows maps.
    let flows = DecodedFile("provenance-flow-index.json") { try ProvenanceFlowIndex(contentsOf: $0) }
    /// `DecimalClassLabelStore.shared`: the decimal file's class glosses, which the class lens reads.
    let decimalLabels = DecodedFile("decimal-class-labels.json") { try DecimalClassLabelTable(contentsOf: $0) }
    /// `SubjectNumericLabelStore.shared`: the Subject-Numeric File's glosses, which the class lens reads.
    let subjectNumericLabels = DecodedFile("subject-numeric-labels.json") { try SubjectNumericLabelTable(contentsOf: $0) }
    /// `SourceProvenanceStore`'s index: the source notes' provenance by decade and volume, which Archival Sourcing reads.
    let sourceProvenance = DecodedFile("source-provenance-index.json") { try SourceProvenanceIndex(contentsOf: $0) }

    /// The Collections derivation for each scope (`ArchivalCollectionsData.make`), which Archival Analytics' ranking and
    /// Archival Sourcing's top collections read: about twelve thousand memberships and usage rows a scope, so fewer kept.
    let collections = KeptSeries<SeriesScopeKey, ArchivalCollectionsData>(capacity: 16)
    /// The co-citation network around each focus, by its measure, threshold and Central Files expansion.
    let networks = KeptSeries<ArchivalNetworkKey, ArchivalNetworkGraph>()
    /// The reference flows, corpus-wide or around a focus, on either layer.
    let flowsData = KeptSeries<ArchivalFlowsKey, ArchivalFlowsData>()
    /// About the Series' four dashboards' data, each for its scope.
    let production = KeptSeries<SeriesScopeKey, SeriesProductionData>(capacity: 16)
    let geography = KeptSeries<SeriesScopeKey, SeriesGeographyData>(capacity: 16)
    let provenance = KeptSeries<SeriesScopeKey, SourceProvenanceData>(capacity: 16)
    let administrations = KeptSeries<AdministrationsKey, AdministrationProfilesData>(capacity: 16)

    /// `VolumeLevelTagStore.allTags(inCategory: .places)` mapped to their regions, the Geographic Emphasis dashboard's
    /// `placeRegions`: each place tag's slug and the region its subcategory names.
    func placeRegions(in directory: URL) -> [String: GeographicRegion] {
        var map: [String: GeographicRegion] = [:]
        for tag in tags(in: directory).values where (TagCategory(rawValue: tag.category) ?? .topics) == .places {
            map[tag.slug] = GeographicRegion.from(subcategory: tag.subcategory)
        }
        return map
    }

    /// `VolumeLevelTagStore.resolve(slug:)?.displayName`: a tag's name, or its slug for a tag the taxonomy lacks.
    func tagName(_ slug: String, in directory: URL) -> String {
        tags(in: directory)[slug]?.displayName ?? slug
    }

    /// The taxonomy by slug, as `VolumeLevelTagStore.entries` keys it, or none for a file missing or malformed.
    func tags(in directory: URL) -> [String: TagTaxonomyEntry] {
        taxonomy.value(in: directory) ?? [:]
    }

    /// `VolumeLevelTagStore`'s taxonomy: the editors' volume tags, whose places Geographic Emphasis maps to regions.
    private let taxonomy = DecodedFile("volume-tag-taxonomy.json") { url in
        let entries = try JSONDecoder().decode([TagTaxonomyEntry].self, from: Data(contentsOf: url))
        // The app's store keys them with `uniqueKeysWithValues`, which the shipped file meets; the first is kept here.
        return Dictionary(entries.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

/// A scope a kept series is kept by: its volumes, sorted, or nil for the whole series.
struct SeriesScopeKey: Hashable, Sendable {
    var volumeIds: [String]?

    init(_ volumeIds: [String]?) {
        self.volumeIds = volumeIds.map { Array(Set($0)).sorted() }
    }

    var set: Set<String>? { volumeIds.map(Set.init) }
}

/// What a kept network is kept by: the view's `rebuildToken`, its focus, measure, Central Files expansion and threshold.
struct ArchivalNetworkKey: Hashable, Sendable {
    var focusId: String
    var measure: String
    var expansion: String
    var threshold: Double
}

/// What kept flows are kept by: the view's `rebuild()` task id, its focus, direction and layer.
struct ArchivalFlowsKey: Hashable, Sendable {
    var focusId: String?
    var direction: String
    var layer: String
}

/// What the administrations' data is kept by: the scope and whether editorial notes are counted.
struct AdministrationsKey: Hashable, Sendable {
    var scope: SeriesScopeKey
    var includeEditorialNotes: Bool
}
