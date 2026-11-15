// S22d's follow-up, over the kit's fixture index imported as an export and the pinned bundled files: a collection's
// record and a volume's Sources outline through the API, each part held to what the app's two views compute with the
// same kit calls over the same files. `CollectionDetailView`'s NARA Catalog link, Related Collections, Cited Over
// Time, Divided at NARA and Pointed At, Not Printed, for a sample of the authority's records and the records the
// fixtures cite; and `VolumeSourcesView`'s row affordances, the Collection link, a heading's volumes, the line for a
// lot NARA divides and the Archival Neighbors button, whose count is the neighbours' page's total for the row. The
// views' stores read the bundled files; here the kit's loaders read the repository's copies, as
// `SourceExplorerTestSupport.swift` gives the kit's own suites the app's stores. The words, formats and mirrored view
// code are `SourceExplorerParityTests`' tables.

import FRUSCoreKit
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSLightAPI

@Suite struct SourceExplorerRecordParityTests {
    /// The bundled files the views' stores read, each decoded by the kit's loader from the pinned copy.
    struct Stores {
        let authority: CollectionAuthorityIndex
        let central: CentralFilesIndex
        let claimants: LotClaimantsIndex
        let citations: ExternalCitationIndex
        let volumeSources: VolumeSourcesIndex
        let presidentialLibraries: PresidentialLibraryIndex
        /// `ManifestStore.entry(forVolumeId:)`'s bundled entries.
        let manifest: [String: VolumeManifestEntry]

        static func load() throws -> Stores {
            let folder = RepositoryFiles.resources
            func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
                try JSONDecoder().decode(type, from: Data(contentsOf: folder.appendingPathComponent(name)))
            }
            let entries = try FixedVolumeCatalogue(contentsOf: folder.appendingPathComponent("manifest.json")).citableEntries
            return Stores(
                authority: try CollectionAuthorityIndex(contentsOf: folder.appendingPathComponent("collection-authority.json")),
                central: try decode(CentralFilesIndex.self, "central-files-index.json"),
                claimants: try decode(LotClaimantsIndex.self, "lot-claimants-index.json"),
                citations: try ExternalCitationIndex(contentsOf: folder.appendingPathComponent("external-citation-index.json")),
                volumeSources: try decode(VolumeSourcesIndex.self, "volume-sources-index.json"),
                presidentialLibraries: try PresidentialLibraryIndex(contentsOf: folder.appendingPathComponent("presidential-library-catalog.json")),
                manifest: Dictionary(entries.map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first }))
        }
    }

    /// The record's sections as `CollectionDetailView` computes them, in the answer's shape: each a condition of the
    /// view's `body`, and each value the kit's, from the stores.
    static func viewsSections(_ record: AuthorityCollectionRecord, _ stores: Stores) -> ArchivalCollectionAnswer {
        var view = ArchivalCollectionAnswer(
            id: record.id, name: record.name, repository: record.repository, recordGroup: record.recordGroup,
            lotFileNorm: record.lotFileNorm, aliases: record.aliases, documentCount: 0, volumeCount: 0,
            volumes: record.volumeIds.map { .init(volumeId: $0, title: stores.manifest[$0]?.title) },
            children: record.children.map { .init(name: $0.name, decimalClass: $0.decimalClass, volumeCount: $0.volumeIds.count) },
            previewRowCap: CollectionRelations.previewRowCap)
        // `showsCatalogLink`, and the section's link and NAID.
        if let url = record.url, stores.central.isUntrustworthyNAID(record.naId) != true {
            view.catalog = .init(url: url.absoluteString, naId: record.naId)
        }
        // `relatedCollectionsSection`, shown for a record citing two or more volumes, from `loadRelated`.
        if record.volumeIds.count >= CollectionRelations.minimumSharedVolumes {
            view.related = CollectionRelations.related(to: record, in: stores.authority.collections).map {
                .init(id: $0.record.id, name: $0.record.name, repository: $0.record.repository, recordGroup: $0.record.recordGroup,
                      sharedVolumeCount: $0.sharedVolumeCount, overlap: $0.overlap)
            }
        }
        // `loadTimeline`, and `citedOverTimeSection` where it buckets anything.
        let midpoints = record.volumeIds.compactMap { volumeId -> Int? in
            guard let entry = stores.manifest[volumeId] else { return nil }
            return CollectionRelations.midpointYear(earliest: entry.dateRange.earliest, latest: entry.dateRange.latest)
        }
        let buckets = CollectionRelations.citedOverTime(volumeMidpoints: midpoints)
        if !buckets.isEmpty {
            view.timeline = .init(eras: buckets.map { .init(shortLabel: $0.era.shortLabel, fullLabel: $0.era.fullLabel, volumeCount: $0.volumeCount) },
                                  narrative: CollectionRelations.timelineNarrative(for: buckets))
        }
        // `dividedLotClaimants`, and `dividedAtNARASection`'s intro, rows and footer.
        if let lot = record.lotFileNorm, let claimants = stores.claimants.claimants(forRawLot: lot) {
            view.divided = .init(
                claimants: claimants.map {
                    .init(naId: $0.naId, title: $0.title, recordGroup: $0.recordGroup, entryNumbers: $0.hmsMlrEntryNumbers,
                          dateRange: $0.dateRange, catalogURL: URL(string: $0.catalogURL) == nil ? nil : $0.catalogURL)
                },
                includesRecordsNAID: record.naId.map { naId in claimants.contains(where: { claimant in claimant.naId == naId }) } ?? false,
                dividedLots: stores.claimants.lots.count)
        }
        // `unprintedPointers`, shown where its total is above none.
        let total = stores.citations.referenceCount(forCollectionId: record.id)
        if total > 0 {
            view.pointers = .init(total: total, volumes: stores.citations.volumeCounts(forCollectionId: record.id).map {
                .init(volumeId: $0.volumeId, title: stores.manifest[$0.volumeId]?.title, count: $0.count)
            })
        }
        return view
    }

    /// The Related Collections rows, each overlap to twelve places: a `Double` read back from the API's JSON on Linux
    /// can differ in its last bit (S23d).
    static func rows(_ related: [ArchivalCollectionAnswer.Related]?) -> [String]? {
        related?.map { "\($0.id) \($0.name) \($0.repository ?? "-") \($0.recordGroup ?? "-") \($0.sharedVolumeCount) \(String(format: "%.12f", $0.overlap))" }
    }

    /// The done-when's first part, for the record: every section the API gives a sample of the authority's records,
    /// every twentieth, those the fixtures and the access proof name, the one whose names are longest and one with
    /// no related collection, is the one the view computes, field for field, the In Your Library counts aside, which
    /// are the served index's.
    @Test func theRecordsSectionsAreTheViews() async throws {
        let stores = try Stores.load()
        let records = stores.authority.collections
        let longest = try #require(records.max { ([$0.name] + $0.aliases).joined().utf8.count < ([$1.name] + $1.aliases).joined().utf8.count })
        let alone = try #require(records.first {
            $0.volumeIds.count >= CollectionRelations.minimumSharedVolumes && CollectionRelations.related(to: $0, in: records).isEmpty
        })
        let named = ["lot:64D563", "lot:66D204", "lot:77D163", longest.id, alone.id]
        let sample = Set(records.enumerated().compactMap { $0.offset % 20 == 0 ? $0.element.id : nil }).union(named).sorted()
        let answers = try await ServedFixture.run { client, _ in
            var answers: [String: ArchivalCollectionAnswer] = [:]
            for id in sample {
                var components = URLComponents()
                components.queryItems = [URLQueryItem(name: "id", value: id)]
                let response = try await client.execute(uri: "/api/v1/archival-collection?\(components.percentEncodedQuery ?? "")", method: .get)
                answers[id] = try ServedFixture.decode(ArchivalCollectionAnswer.self, response)
            }
            return answers
        }
        var shown = (catalog: 0, related: 0, relatedEmpty: 0, timeline: 0, divided: 0, pointers: 0)
        for id in sample {
            let record = try #require(stores.authority.record(id: id), "\(id)")
            let answer = try #require(answers[id], "\(id)")
            let view = Self.viewsSections(record, stores)
            #expect(answer.catalog == view.catalog, "\(id): the NARA Catalog link")
            #expect(Self.rows(answer.related) == Self.rows(view.related), "\(id): Related Collections")
            #expect(answer.timeline == view.timeline, "\(id): Cited Over Time")
            #expect(answer.divided == view.divided, "\(id): Divided at NARA")
            #expect(answer.pointers == view.pointers, "\(id): Pointed At, Not Printed")
            #expect(answer.previewRowCap == CollectionRelations.previewRowCap)
            #expect(answer.volumes == view.volumes && answer.children == view.children && answer.aliases == view.aliases, "\(id)")
            if view.catalog != nil { shown.catalog += 1 }
            if let related = view.related { if related.isEmpty { shown.relatedEmpty += 1 } else { shown.related += 1 } }
            if view.timeline != nil { shown.timeline += 1 }
            if view.divided != nil { shown.divided += 1 }
            if view.pointers != nil { shown.pointers += 1 }
        }
        print("[SourceExplorerRecordParity] \(sample.count) records: catalog \(shown.catalog), related \(shown.related) (+\(shown.relatedEmpty) empty), timeline \(shown.timeline), divided \(shown.divided), pointers \(shown.pointers)")
        // Every section is reached; lot 64 D 563's figures, which the access proof printed, are said.
        #expect(shown.catalog > 0 && shown.related > 0 && shown.relatedEmpty > 0 && shown.timeline > 0 && shown.divided > 0 && shown.pointers > 0)
        let divided = try #require(answers["lot:64D563"])
        print("[SourceExplorerRecordParity] lot 64 D 563: \(divided.related?.count ?? 0) related, \(divided.divided?.claimants.count ?? 0) claiming series, \(divided.divided?.dividedLots ?? 0) divided lots, \(divided.pointers?.total ?? 0) pointers across \(divided.pointers?.volumes.count ?? 0) volumes")
    }

    /// The done-when's first part, for the outline: every row of the fixture volumes' Sources sections has the
    /// Collection link, the heading's volumes and the divided lot's line the view computes for it; its Archival
    /// Neighbors button names the record the view's fallback reads, and its count, where above none, is the total
    /// the neighbours' page lists for the row on All volumes, as the view's badge and sheet agree where the direct
    /// keys match.
    @Test func theOutlinesAffordancesAreTheViews() async throws {
        let stores = try Stores.load()
        let volumes = ParityFixtures.volumes
        let (outlines, totals) = try await ServedFixture.run { client, _ in
            var outlines: [String: VolumeSourcesOutline] = [:]
            var totals: [String: Int] = [:]
            for volume in volumes {
                let outline = try ServedFixture.decode(VolumeSourcesOutline.self,
                                                       try await client.execute(uri: "/api/v1/volumes/\(volume)/sources", method: .get))
                outlines[volume] = outline
                for row in outline.rows {
                    guard let neighbours = row.neighbours, (neighbours.count ?? 0) > 0 else { continue }
                    var components = URLComponents()
                    components.queryItems = [("lotFile", neighbours.lotFile), ("recordGroup", neighbours.recordGroup),
                                             ("series", neighbours.series), ("repository", neighbours.repository),
                                             ("decimalClass", neighbours.decimalClass), ("jobNumber", neighbours.jobNumber),
                                             ("aliasCollection", neighbours.aliasCollection), ("anchor", volume), ("scope", "all")]
                        .compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
                    let list = try ServedFixture.decode(ArchivalNeighborsAnswer.self, try await client.execute(
                        uri: "/api/v1/archival-neighbors?\(components.percentEncodedQuery ?? "")", method: .get))
                    totals["\(volume)/\(row.text)"] = list.totalCount
                }
            }
            return (outlines, totals)
        }
        var figures = (rows: 0, items: 0, collection: 0, crossVolume: 0, divided: 0, neighbours: 0, counted: 0, jobs: 0)
        for volume in volumes {
            let entries = try await FRUSDocumentParser()
                .parseVolumeFull(volumeURL: Repository.layout.tei.appendingPathComponent("\(volume).xml")).volumeSources
            let rows = try #require(outlines[volume]).rows
            #expect(rows.map(\.text) == entries.map(\.rawText), "\(volume): the rows in the TEI's order")
            for (entry, row) in zip(entries, rows) {
                figures.rows += 1
                guard entry.kind == .item else {
                    #expect(row.neighbours == nil && row.collection == nil && row.crossVolume == nil && row.dividedSeriesCount == nil)
                    continue
                }
                figures.items += 1
                // `sourceNodeRow`'s authority record, its legacy cross-volume fallback and `resolutionEnrichment`'s line.
                let authority = stores.authority.record(forFrontMatterText: entry.rawText, repository: entry.repository,
                                                        lotFileNorm: entry.lotFileNorm, decimalClass: entry.decimalClass)
                let crossVolume: MajorCollectionRecord? = (entry.isHeading && authority == nil)
                    ? stores.volumeSources.authority(recordGroup: entry.recordGroup, lotFile: entry.lotFile, text: entry.rawText) : nil
                let resolution = ArchivalResolver.frontMatterResolution(
                    recordGroup: entry.recordGroup, lotFile: entry.lotFile, entryText: entry.rawText, repository: entry.repository,
                    centralFiles: stores.central, volumeSources: stores.volumeSources, claimants: stores.claimants,
                    presidentialLibrary: stores.presidentialLibraries)
                let divided = resolution == nil
                    ? ArchivalResolver.dividedLotClaimants(lotFile: entry.lotFile, claimants: stores.claimants)?.count : nil
                #expect(row.collection?.id == authority?.id && row.collection?.volumeCount == authority?.volumeIds.count, "\(entry.rawText)")
                let volumesCiting = authority == nil ? crossVolume.flatMap { $0.volumeIds.count > 1 ? $0.volumeIds : nil } : nil
                #expect(row.crossVolume?.map(\.volumeId) == volumesCiting, "\(entry.rawText)")
                #expect((row.crossVolume ?? []).allSatisfy { $0.title == stores.manifest[$0.volumeId]?.title })
                #expect(row.dividedSeriesCount == divided, "\(entry.rawText)")
                // The button: a row with a lot or a class has one; the record its fallback reads is the row's authority
                // record; and a count above none is the neighbours' total for the row. A job number is no key here:
                // the kit's `volumeSources(forVolumeId:)`, which the app's view and the server both read the rows
                // through, selects no `job_number`, so a CIA job's row has no button in either, though the TEI gives
                // it one and `makeNeighborsTarget` would key on it.
                func given(_ value: String?) -> Bool { !(value?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) }
                if given(entry.lotFile) || given(entry.decimalClass) { #expect(row.neighbours != nil, "\(entry.rawText) has a key") }
                if given(entry.jobNumber) { figures.jobs += 1 }
                #expect(row.neighbours?.jobNumber == nil, "\(entry.rawText): the index's rows carry no job number")
                if let neighbours = row.neighbours {
                    figures.neighbours += 1
                    #expect(neighbours.aliasCollection == authority?.id, "\(entry.rawText)")
                    #expect(neighbours.count != nil, "\(entry.rawText): the batch answered")
                    if let count = neighbours.count, count > 0 {
                        figures.counted += 1
                        #expect(totals["\(volume)/\(entry.rawText)"] == count, "\(entry.rawText): the page lists the badge's count")
                    }
                }
                if row.collection != nil { figures.collection += 1 }
                if row.crossVolume != nil { figures.crossVolume += 1 }
                if row.dividedSeriesCount != nil { figures.divided += 1 }
            }
        }
        print("[SourceExplorerRecordParity] outline: \(figures.rows) rows, \(figures.items) outline rows; collection \(figures.collection), cross-volume \(figures.crossVolume), divided \(figures.divided), neighbours \(figures.neighbours) (\(figures.counted) counted), CIA jobs \(figures.jobs)")
        #expect(figures.collection > 0 && figures.crossVolume > 0 && figures.neighbours > 0 && figures.counted > 0 && figures.jobs > 0)
    }
}
