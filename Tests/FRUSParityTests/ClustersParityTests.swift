// Browse's clusters through the API (PLAN's S28d), held to the kit's `ClustersAxis` (S28a) over the same files, computed
// here apart from the server: the bundled map and vectors through SemanticVectorsKit's loaders, the catalogue through
// FRUSCoreKit's, and the three fixture volumes as the server's, whose index the server imports and serves and the test
// reads through the kit's pipeline. The index's order, labels, counts and histograms; each region's documents, its
// members in the kit's order, a section a volume as the app's `CorporaAxis` makes them, page by page and whole; what the
// served index holds of them; and Save as Working Corpus, the kit's capture, name and description, are the kit's.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import SemanticVectorsKit
import Testing

@testable import FRUSLightAPI

@Suite struct ClustersParityTests {
    typealias Kit = SemanticMapReadingParityTests.Kit
    typealias Section = WorkingCorpusDetail.Section

    /// The volumes the server serves: the three fixture volumes, whose index it imports.
    static let served = Set(ParityFixtures.volumes)

    /// Every member of `cluster`, as the kit enumerates them: its rows in the map, keyed by the vectors' index.
    static func members(_ kit: Kit, _ cluster: SemanticMapArtifacts.Cluster) -> [String] {
        ClustersAxis.documentKeys(rows: ClustersAxis.membershipRows(in: kit.map.vectors, clusterId: cluster.id).rows, index: kit.index)
    }

    /// The sections `ClusterDocumentsView` draws of `keys` from `CorporaAxis`, written here from the app's rules apart from
    /// the server's: a section a volume, the volumes by id; each section's documents by the day the index dates them, then
    /// the volume's first day of coverage, then none, ties by id; a served volume titled and dated from its index. With
    /// `after`, the sections of the volumes with a key past the first `after`.
    static func expected(_ keys: [String], after: Int, kit: Kit, pipeline: IndexingPipeline) async throws -> [Section] {
        var byVolume: [String: [String]] = [:]
        for key in keys {
            let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
            byVolume[parts[0], default: []].append(parts[1])
        }
        let changed = Set(keys.dropFirst(after).map { String($0.split(separator: "/")[0]) })
        var sections: [Section] = []
        for volume in byVolume.keys.sorted() where after == 0 || changed.contains(volume) {
            let ids = byVolume[volume]!
            let indexed = served.contains(volume)
            var titles: [String: String] = [:]
            var dates: [String: String] = [:]
            if indexed {
                for entry in try await pipeline.documents(forVolume: volume) where ids.contains(entry.documentId) {
                    titles[entry.documentId] = DocumentDisplayTitle.text(
                        .init(header: entry.header.isEmpty ? nil : entry.header, documentNumber: entry.documentNumber,
                              isEditorialNote: entry.isEditorialNote),
                        documentId: entry.documentId)
                }
                dates = try await pipeline.datesByDocumentKey(ids.map { (volumeId: volume, documentId: $0) })
            }
            let earliest = kit.catalogue[volume]?.dateRange.earliest
            let ordered = ids.sorted {
                let (a, b) = (dates["\(volume)/\($0)"] ?? earliest ?? "9999", dates["\(volume)/\($1)"] ?? earliest ?? "9999")
                return a != b ? a < b : $0 < $1
            }
            sections.append(Section(volumeId: volume, title: kit.catalogue[volume]?.title, indexed: indexed, documents: ordered.map {
                .init(volumeId: volume, documentId: $0, displayTitle: titles[$0], dateISO: dates["\(volume)/\($0)"])
            }))
        }
        return sections
    }

    /// The pages' sections merged as the browser app merges them (`clusterSections`): a later page's section of a volume
    /// replacing the earlier one where it stands, any other added.
    static func merged(_ pages: [ClusterDocuments]) -> [Section] {
        var sections: [Section] = []
        for page in pages {
            for section in page.sections {
                if let at = sections.firstIndex(where: { $0.volumeId == section.volumeId }) { sections[at] = section } else { sections.append(section) }
            }
        }
        return sections
    }

    static func documents(_ client: any TestClientProtocol, _ id: Int, shown: Int, after: Int = 0, layout: String) async throws -> ClusterDocuments {
        try await SemanticMapReadingParityTests.json(ClusterDocuments.self, client, "/api/v1/clusters/\(id)",
                                                     "shown=\(shown)&after=\(after)&layout=\(layout)")
    }

    @Test func theIndexIsTheKits() async throws {
        let kit = try Kit.open()
        try await ServedFixture.run { client, _ in
            let index = try await SemanticMapReadingParityTests.json(ClustersIndex.self, client, "/api/v1/clusters")
            #expect(index.layoutIdentity == kit.map.index.layoutIdentity)
            // The caption's counts, the kit's `indexCaption` arguments: the regions, the documents placed and those between.
            #expect(index.clusterCount == kit.clusters.count && index.clusterCount == 140)
            #expect(index.documentCount == kit.map.index.documentCount && index.documentCount == 314_616)
            #expect(index.unclusteredCount == kit.map.index.layout.unclusteredCount && index.unclusteredCount == 88_059)
            let ordered = ClustersAxis.ordered(kit.clusters)
            #expect(index.clusters.map(\.id) == ordered.map(\.id), "largest first, ties by id")
            #expect(index.clusters.map(\.label) == ordered.map(ClustersAxis.rowLabel))
            #expect(index.clusters.map(\.documentCount) == ordered.map(\.documentCount))
            for (row, cluster) in zip(index.clusters, ordered) {
                let bars = ClustersAxis.eraBars(cluster.eraCounts)
                #expect(row.eras == bars.map { .init(era: $0.era?.rawValue, count: $0.count, isPeak: $0.isPeak) }, "cluster \(cluster.id)'s eras")
                #expect(row.eras.reduce(0) { $0 + $1.count } == cluster.documentCount, "the bars count the region's documents")
            }
            // The largest first, its four terms read as a term list, its bars every era's slot with two accented.
            #expect(index.clusters.first?.label == "nanking · shanghai · chinese · tientsin" && index.clusters.first?.documentCount == 37_899)
            #expect(index.clusters.allSatisfy { $0.eras.count == CoverageEra.allCases.count && $0.eras.filter(\.isPeak).count <= 2 })
            #expect(index.clusters.contains { $0.eras.filter(\.isPeak).count == 2 })
        }
    }

    @Test func aRegionsDocumentsAreTheKits() async throws {
        let kit = try Kit.open()
        let pipeline = try await FixtureIndex.value().index.pipeline
        let layout = kit.map.index.layoutIdentity
        // The largest region, one under a page, and those that hold the fixture volumes' documents, before the first page
        // ends and after the capture's 7,500.
        let ids = [3, 122, 102, 75, 115, 72]
        try await ServedFixture.run { client, _ in
            for id in ids {
                let cluster = try #require(kit.clusters.first { $0.id == id })
                let keys = Self.members(kit, cluster)
                #expect(keys.count == cluster.documentCount, "cluster \(id)'s members are the index's count")
                var asked = [(shown: min(500, keys.count), after: 0)]
                // Every page to the one past the fixture volumes' first member, as "Show more" asks them.
                let reach = keys.firstIndex { Self.served.contains(String($0.split(separator: "/")[0])) }.map { $0 + 600 } ?? 1_500
                while asked.last!.shown < min(keys.count, reach) {
                    let last = asked.last!.shown
                    asked.append((min(last + 500, keys.count), last))
                }
                var pages: [ClusterDocuments] = []
                for page in asked {
                    let answer = try await Self.documents(client, id, shown: page.shown, after: page.after, layout: layout)
                    #expect(answer.id == id && answer.label == ClustersAxis.rowLabel(cluster) && answer.name == ClustersAxis.mapStyleName(cluster))
                    #expect(answer.layoutIdentity == layout && answer.documentCount == cluster.documentCount && answer.total == keys.count)
                    #expect(answer.shown == page.shown && answer.after == page.after)
                    let rows = SemanticMapRegionRows.eraRows(cluster, locale: Locale(identifier: "en_US"))
                    #expect(answer.eraRows == rows.map { .init(label: $0.label, count: $0.count) })
                    let coverage = WorkingCorpusResolver(indexedVolumeIds: Self.served).resolve(documentKeys: keys)
                    #expect(answer.coverage == CorpusCoverage(coverage), "cluster \(id)'s coverage")
                    let expected = try await Self.expected(Array(keys.prefix(page.shown)), after: page.after, kit: kit, pipeline: pipeline)
                    #expect(answer.sections == expected, "cluster \(id), \(page.shown) shown after \(page.after)")
                    pages.append(answer)
                }
                // The pages merged as the browser merges them are the whole listing at once, its members the kit's, in order.
                let shown = asked.last!.shown
                let whole = try await Self.documents(client, id, shown: shown, layout: layout)
                let sections = Self.merged(pages)
                #expect(sections == whole.sections, "cluster \(id)'s pages merged are its first \(shown) at once")
                let listed = Set(sections.flatMap { $0.documents.map { "\($0.volumeId)/\($0.documentId)" } })
                #expect(listed == Set(keys.prefix(shown)) && listed.count == shown)
                #expect(sections.map(\.volumeId) == sections.map(\.volumeId).sorted())
                // A served volume's documents open, titled and dated from the index; another's are named.
                for section in sections {
                    #expect(section.indexed == Self.served.contains(section.volumeId))
                    #expect(section.title == kit.catalogue[section.volumeId]?.title)
                    if !section.indexed { #expect(section.documents.allSatisfy { $0.displayTitle == nil && $0.dateISO == nil }) }
                }
                if id != 3 && id != 122 { #expect(sections.contains { $0.indexed && $0.documents.contains { $0.displayTitle != nil } }) }
            }
            // frus1961-63v06's d1 comes first of the volume's 79 in "edc nato nuclear": its earliest day, the tie by id.
            let edc = try await Self.documents(client, 115, shown: 8_500, layout: layout)
            let v06 = try #require(edc.sections.first { $0.volumeId == "frus1961-63v06" })
            let opening = v06.documents.prefix(4).map { "\($0.documentId) \($0.dateISO ?? "undated")" }
            #expect(v06.documents.first?.documentId == "d1" && v06.documents.count == 79, "\(opening)")
            #expect(v06.documents.first?.displayTitle == "1. Message From Chairman Khrushchev to President-elect Kennedy",
                    "\(v06.documents.first?.displayTitle ?? "untitled")")
            // The last page of a region ends it.
            let small = try await Self.documents(client, 122, shown: 500, layout: layout)
            #expect(small.shown == small.total && small.total == 254)
        }
    }

    @Test func savingARegionCapturesTheKitsSet() async throws {
        let kit = try Kit.open()
        let layout = kit.map.index.layoutIdentity
        let york = try #require(TimeZone(identifier: "America/New_York"))
        try await ServedFixture.run { client, _ in
            let session = try await CollectionExportParityTests.Session.open(client)
            for (id, truncated) in [(3, true), (122, false)] {
                let cluster = try #require(kit.clusters.first { $0.id == id })
                let capture = ClustersAxis.capture(keys: Self.members(kit, cluster), cluster: cluster)
                #expect(capture.isTruncated == truncated && capture.documentKeys.count == min(cluster.documentCount, 7_500))
                let saved = try await session.json(WorkingCorpus.self, .post, "/api/v1/me/working-corpora/cluster",
                                                   ["cluster": id, "layout": layout, "timeZone": "America/New_York"])
                let time = try #require(saved.capturedAt.flatMap(UserStoreDate.date))
                #expect(saved.name == SemanticMapCapture.corpusName(
                    regionNames: capture.regionNames, stamp: SemanticMapCapture.stamp(for: time, locale: Locale(identifier: "en_US"), timeZone: york)))
                #expect(saved.name.hasPrefix(ClustersAxis.mapStyleName(cluster) + " — "))
                #expect(saved.documentCount == capture.documentKeys.count && saved.totalMatchCountAtCapture == capture.total)
                #expect(saved.wasTruncatedAtCapture == truncated && saved.sourceDescription == ClustersAxis.corpusSourceDescription)
                #expect(saved.sourceQuery == nil && saved.indexedVolumeCountAtCapture == Self.served.count)
                #expect(saved.truncationWarns == truncated && (saved.truncationLine != nil) == truncated)
                // As the corpus is kept: the kit's keys in the kit's order.
                let export = try ResearchDataEnvelope.makeDecoder().decode(
                    ResearchDataEnvelope.self, from: Data(buffer: try await session.get("/api/v1/me/export").body))
                let kept = try #require(export.workingCorpora.first { $0.id.uuidString == saved.id })
                #expect(kept.documentKeys == capture.documentKeys, "cluster \(id)'s corpus holds the kit's capture, in order")
            }
        }
    }
}
