// What the server and the browser app mirror of the app's Browse clusters (PLAN's S28d), held to the app's source at the
// pin, line beside line. The axis's order, labels, histograms, membership and capture are the kit's `ClustersAxis` (S28a),
// computed on the server and held to the kit by `ClustersParityTests`; what is mirrored is the app's view: the drill's
// pages and their sections (`ClusterDocumentsView` over `CorporaAxis`), the coverage line and the save's record of it,
// See on the semantic map's request, the histogram's bars (`ClusterEraHistogramView`), the axis's place in the Mac's
// sidebar, and every word the server writes and copy.ts holds, under the app's key. A pin move that changes one fails
// here until the web follows it.

import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct ClustersMirrorParityTests {
    static let view = "Browser/ClustersBrowseView.swift"
    static let corpora = "Browser/CorpusBrowseView.swift"
    static let sidebar = "App/MacCorpusBrowserWindow.swift"
    static let axis = "kit:FRUSCoreKit/Semantic/ClustersAxis.swift"
    static let server = "Sources/FRUSLightAPI/Clusters.swift"
    static let api = "web:api/clusters.ts"
    static let screen = "web:browse/ClustersScreen.tsx"
    static let axes = "web:browse/BrowseAxes.tsx"
    static let styles = "web:styles/app.css"

    @Test func theDrillsPagesAndSectionsAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            // The kit's rules, which the app's views call and the server calls in their place.
            (Self.view, #"ForEach(ClustersAxis.ordered(index.clusters), id: \.id) { cluster in"#,
             Self.server, #"clusters: ClustersAxis.ordered(index.clusters).map { cluster in"#),
            (Self.view, #"let label = ClustersAxis.rowLabel(cluster)"#, Self.server, #"id: cluster.id, label: ClustersAxis.rowLabel(cluster), documentCount: cluster.documentCount,"#),
            (Self.view, #"ClusterEraHistogramView(bars: ClustersAxis.eraBars(cluster.eraCounts))"#,
             Self.server, #"eras: ClustersAxis.eraBars(cluster.eraCounts).map"#),
            (Self.view, #"""
             let found = ClustersAxis.membershipRows(in: map, clusterId: id)
             return ClustersAxis.documentKeys(rows: found.rows, index: vectorIndex)
             """#,
             Self.server, #"ClustersAxis.documentKeys(rows: ClustersAxis.membershipRows(in: plane.map.vectors, clusterId: id).rows,"#),
            (Self.view, #"ForEach(SemanticMapRegionRows.eraRows(cluster), id: \.label) { row in"#,
             Self.server, #"eraRows: SemanticMapRegionRows.eraRows(cluster, locale: SearchItem.locale)"#),
            (Self.view, #"LabeledContent(String(localized: "browser.clusters.drill.count", defaultValue: "Documents in the series"), value: cluster.documentCount.formatted())"#,
             Self.screen, #"<dd>{first.documentCount.toLocaleString('en-US')}</dd>"#),
            // The pages: 500 first, 500 more at each Show more, never past the members.
            (Self.view, #"private static let pageSize = 500"#, Self.server, #"static let pageSize = 500"#),
            (Self.view, #"private static let pageSize = 500"#, Self.api, #"export const clusterPage = 500;"#),
            (Self.view, #"shownCount: min(loadedKeys.count, Self.pageSize),"#, Self.server, #"let shown = min(asked, keys.count)"#),
            (Self.view, #"shown = min(memberKeys.count, shown + pageSize)"#,
             Self.api, #"last.shown < last.total ? { shown: Math.min(last.shown + clusterPage, last.total), after: last.shown, layout: last.layoutIdentity } : undefined,"#),
            (Self.view, #"private static let pageSize = 500"#,
             Self.server, #"guard asked <= after + ClustersRoutes.pageSize else {"#),
            (Self.view, #"ForEach(CorporaAxis.volumeSections(from: Array(keys.prefix(shownCount)))) { section in"#,
             Self.server, #"let listed = Array(keys.prefix(shown))"#),
            (Self.view, #"if shownCount < keys.count { showMoreSection }"#, Self.screen, #"{pages.hasNextPage && ("#),
            // `CorporaAxis`: a section a volume, the volumes by id; a section's documents by date, then the volume's first day
            // of coverage, then none, ties by id; a volume the device has indexed opening its documents.
            (Self.corpora, #"guard parts.count == 2 else { continue }"#, Self.server, #"guard parts.count == 2 else { continue }"#),
            (Self.corpora, #"return byVolume.keys.sorted().map { VolumeSection(volumeId: $0, documents: byVolume[$0] ?? []) }"#,
             Self.server, #"for volumeId in byVolume.keys.sorted() where onlyVolumes?.contains(volumeId) ?? true {"#),
            (Self.corpora, #"dateISO ?? volumeEarliest ?? "9999""#,
             Self.server, #"func sortKey(_ id: String) -> String { dates["\(volumeId)/\(id)"] ?? earliest ?? "9999" }"#),
            (Self.corpora, #"if a != b { return a < b } return $0.documentId < $1.documentId"#, Self.server, #"return x != y ? x < y : a < b"#),
            (Self.view, #"ForEach(CorporaAxis.ordered(section.documents, dates: dates, volumeEarliest: entry?.dateRange.earliest)) { ref in"#,
             Self.server, #"let earliest = entry?.dateRange.earliest"#),
            (Self.corpora, #"if volumeIndexed { return .open }"#, Self.server, #"let indexed = served?.indexedVolumeIds.contains(volumeId) ?? false"#),
            (Self.view, #"Section(entry?.title ?? section.volumeId) {"#, Self.screen, #"{section.title ?? section.volumeId}"#),
            (Self.view, #"Text(DocumentDisplayTitle.text(headers[ref.key], documentId: ref.documentId))"#,
             Self.server, #"titles[document.documentId] = DocumentEntry(document, inIndex: true, dateISO: nil).displayTitle"#),
            (Self.view, #"Text("\(ref.volumeId) · \(ref.documentId)")"#, Self.screen, #"{document.volumeId} · {document.documentId}"#),
            // The coverage, once, in the resolver's words, amber when this server lacks some of it.
            (Self.view, #"let resolution = WorkingCorpusResolver(indexedVolumeIds: appState.indexedVolumeIds) .resolve(WorkingCorpus(name: "", documentKeys: keys))"#,
             Self.server, #"WorkingCorpusResolver(indexedVolumeIds: $0.indexedVolumeIds).resolve(documentKeys: keys)"#),
            (Self.view, #"if !keys.isEmpty { Text(resolution.coverageDescription)"#, Self.screen, #"{first.coverage && first.total > 0 && ("#),
            (Self.view, #".foregroundStyle(resolution.isComplete ? Color.secondary : Color.orange)"#,
             Self.screen, #"<p className={first.coverage.isComplete ? 'count' : 'count warning'}>"#),
        ])
    }

    @Test func theSaveAndTheMapsLinkAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.view, #"let capture = ClustersAxis.capture(keys: keys, cluster: cluster)"#,
             Self.server, #"let capture = ClustersAxis.capture(keys: keys, cluster: cluster)"#),
            (Self.view, #"let name = SemanticMapCapture.corpusName(regionNames: capture.regionNames, stamp: SemanticMapCapture.stamp(for: Date()))"#,
             Self.server, #"let name = SemanticMapCapture.corpusName(regionNames: capture.regionNames, stamp: SemanticMapCapture.stamp(for: time, locale: SearchItem.locale, timeZone: timeZone))"#),
            (Self.view, #"sourceQuery: nil, sourceDescription: ClustersAxis.corpusSourceDescription, indexedVolumeCountAtCapture: appState.indexedVolumeIds.count,"#,
             Self.server, #"id: UUID(), name: name, documentKeys: capture.documentKeys, capturedAt: time, sourceQuery: nil, sourceDescription: ClustersAxis.corpusSourceDescription, indexedVolumeCountAtCapture: served?.indexedVolumeIds.count ?? 0,"#),
            (Self.view, #"wasTruncatedAtCapture: capture.isTruncated, totalMatchCountAtCapture: capture.total)"#,
             Self.server, #"wasTruncatedAtCapture: capture.isTruncated, totalMatchCountAtCapture: capture.total,"#),
            // The confirmation, amber for a capture cut short at the app's 7,500.
            (Self.view, #"if savedCapture.isTruncated {"#, Self.screen, #"warns: truncated,"#),
            (Self.view, #".foregroundStyle(.orange)"#, Self.screen, #"<p className={saved?.warns ? 'note warning' : 'note'} role="status">"#),
            (Self.view, #".disabled(keys.isEmpty)"#,
             Self.screen, #"<button type="button" disabled={first.total === 0} aria-disabled={saving ? 'true' : undefined} onClick={() => void save(first)}>"#),
            (Self.view, #".disabled(keys.isEmpty)"#, Self.server, #"guard !capture.documentKeys.isEmpty else {"#),
            // The app reloads its rows' metadata when the count of indexed volumes changes; the web lists its pages again.
            (Self.view, #".clusterMetadataLoad(clusterId: clusterId, indexedVolumeCount: appState.indexedVolumeIds.count) {"#,
             Self.screen, #"const mixed = loaded !== undefined && loaded.some((page) => page.indexedVolumes !== loaded[0]?.indexedVolumes);"#),
            // See on the semantic map: the map on the region, its lens Regions, against the layout's identity.
            (Self.view, #"if let onSeeMap, let digest = BundledSemanticMap.index?.layoutIdentity {"#,
             Self.screen, #"<Link to="/analytics/semantic" search={{ region: first.id, layout: first.layoutIdentity }}>"#),
            (Self.view, #"onSeeMap(SemanticMapRequest(volumeIDs: nil, scopeLabel: nil, lensRawValue: SemanticMapLens.cluster.rawValue, focusClusterID: clusterId, focusClusterDigest: digest))"#,
             "Sources/FRUSLightAPI/SemanticMapReading.swift", #"focusClusterID: try query.optionalInteger("region", in: 0...Int(UInt16.max) - 1), focusClusterDigest: try query.single("layout"))"#),
        ])
    }

    @Test func theHistogramIsTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.view, #"private static let maxBarHeight: CGFloat = 18"#, Self.screen, #"const tallest = 18;"#),
            (Self.view, #"private static let minBarHeight: CGFloat = 2"#, Self.screen, #"const shortest = 2;"#),
            (Self.view, #"let peak = bars.map(\.count).max() ?? 0"#, Self.screen, #"const peak = Math.max(0, ...bars.map((bar) => bar.count));"#),
            (Self.view, #"guard peak > 0, count > 0 else { return Self.minBarHeight }"#, Self.screen, #"if (peak <= 0 || count <= 0) return shortest;"#),
            (Self.view, #"return max(Self.minBarHeight, Self.maxBarHeight * CGFloat(count) / CGFloat(peak))"#,
             Self.screen, #"return Math.max(shortest, (tallest * count) / peak);"#),
            (Self.view, #"HStack(alignment: .bottom, spacing: 3) {"#, Self.styles, #"gap: 3px;"#),
            (Self.view, #".frame(width: 5, height: barHeight(bar.count, peak: peak))"#, Self.styles, #".cluster-bar { width: 5px;"#),
            (Self.view, #".fill(bar.isPeak ? Color.accentColor : Color.secondary.opacity(0.35))"#,
             Self.styles, #"background: color-mix(in srgb, var(--text-secondary) 35%, transparent); } .cluster-bar.peak { background: var(--accent); }"#),
            (Self.view, #".accessibilityHidden(true)"#, Self.screen, #"<span className="cluster-histogram" aria-hidden="true">"#),
        ])
    }

    @Test func theWordsAndTheAxissPlaceAreTheApps() throws {
        let sources = NoteViewParityTests.Sources()
        let view = try sources.app(Self.view)
        let sidebar = try sources.app(Self.sidebar)
        let axis = try sources.app(String(Self.axis.dropFirst("kit:".count)))
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let block = try NoteViewParityTests.block("clusters", of: copy)
        let axesBlock = try NoteViewParityTests.block("axes", of: copy)
        let server = try SearchSetParityTests.server(Self.server)

        // Clusters in the Mac's sidebar after Archives and before Editors' Annotations; in the web's axes after All Volumes,
        // whose arrangements, Administrations, Editors and Archives are not the web's yet, and before Editors' Annotations.
        #expect(sidebar.contains(#"Label(String(localized: "browser.clusters.title", defaultValue: "Clusters"),"#))
        let order = ["CorpusSidebarItem.archives", "CorpusSidebarItem.clusters", "CorpusSidebarItem.annotations"].compactMap { sidebar.range(of: ".tag(\($0))")?.lowerBound }
        #expect(order.count == 3 && order == order.sorted())
        let axes = try SearchSetParityTests.web("browse/BrowseAxes.tsx")
        let webOrder = ["axis: 'volumes'", "axis: 'clusters'", "axis: 'annotations'"].compactMap { axes.range(of: $0)?.lowerBound }
        #expect(webOrder.count == 3 && webOrder == webOrder.sorted())
        #expect(axesBlock.contains("clusters: 'Clusters',"))

        for (key, words, line) in [
            ("browser.clusters.title", "Clusters", "title: 'Clusters',"),
            ("browser.clusters.pending", "Loading the cluster data…", "loading: 'Loading the cluster data…',"),
            ("browser.clusters.unavailable.title", "Clusters Unavailable", "unavailableTitle: 'Clusters Unavailable',"),
            ("browser.clusters.row.help", "Browse this cluster’s documents, grouped by volume", "rowHelp: 'Browse this cluster’s documents, grouped by volume',"),
            ("browser.clusters.drill.unavailable", "This cluster’s data could not be loaded.", "drillUnavailable: 'This cluster’s data could not be loaded.',"),
            ("browser.clusters.drill.count", "Documents in the series", "countLabel: 'Documents in the series',"),
            ("browser.clusters.seeOnMap", "See on the semantic map", "seeOnMap: 'See on the semantic map',"),
            ("browser.clusters.saveCorpus", "Save as Working Corpus", "saveCorpus: 'Save as Working Corpus',"),
            ("browser.clusters.showMore", "Show more", "showMore: 'Show more',"),
        ] {
            #expect(NoteViewParityTests.writes(view, key, words), "the app writes \(key)")
            #expect(block.contains(line), "copy.ts holds \(line)")
        }
        // The words with counts and names in them, the app's integers grouped as the web groups numbers.
        for (key, words, line) in [
            ("browser.clusters.row.count", #"\(cluster.documentCount) documents"#,
             "rowCount: (count: number) => `${count.toLocaleString('en-US')} documents`,"),
            ("browser.clusters.row.a11y", #"\(label), \(cluster.documentCount) documents"#,
             "rowLabel: (label: string, count: number) => `${label}, ${count.toLocaleString('en-US')} documents`,"),
            ("browser.clusters.saved", #"Saved “\(savedCorpusName)”."#, "saved: (name: string) => `Saved “${name}”.`,"),
            ("browser.clusters.saved.truncated", #"Saved “\(savedCorpusName)” with the first \(savedCapture.documentKeys.count) of \(savedCapture.total) documents."#,
             "savedTruncated: (name: string, kept: number, total: number) => `Saved “${name}” with the first ${kept.toLocaleString('en-US')} of ${total.toLocaleString('en-US')} documents.`,"),
            ("browser.clusters.paging", #"Showing the first \(shownCount) of \(keys.count) documents, in volume order."#,
             "paging: (shown: number, total: number) => `Showing the first ${shown.toLocaleString('en-US')} of ${total.toLocaleString('en-US')} documents, in volume order.`,"),
        ] {
            #expect(NoteViewParityTests.writes(view, key, words), "the app writes \(key)")
            #expect(block.contains(line), "copy.ts holds \(line)")
        }
        let footer = "A cluster is a grouping detected by an AI model that the corpus fell into on its own. It is comprised of documents whose language reads alike to an AI model. It is detected mathematically by turning its text into numeric vectors and clustering documents measured as similar rather than chosen by an editor. Its label is automatically assigned from the most distinctive words in a sample of the cluster’s documents. It is not a subject heading. Era counts reflect each volume’s coverage era, not each document’s own date."
        #expect(NoteViewParityTests.writes(view, "browser.clusters.drill.footer", footer))
        #expect(block.contains("footer: '\(footer)',"))

        // The kit's caption over the list, its counts the server's and its figures the web's.
        #expect(axis.contains(NoteViewParityTests.flattened(#"""
            return String(localized: "browser.clusters.caption",
                          defaultValue: """
                          \(clusterCount) clusters computed from document text. Labels are the most \
                          distinctive sampled terms, not subject headings. \(unclusteredCount) documents \
                          (\(percentText)%) belong to no cluster and cannot be reached from this list. \
                          Era bars reflect each volume's coverage era, not document dates.
                          """)
            """#)))
        #expect(axis.contains("let percent = documentCount > 0 ? Double(unclusteredCount) / Double(documentCount) * 100 : 0"))
        #expect(axis.contains("let percentText = percent.formatted(.number.precision(.fractionLength(1)))"))
        #expect(block.contains(NoteViewParityTests.flattened("""
            `${clusters.toLocaleString('en-US')} clusters computed from document text. Labels are the most distinctive sampled terms, not subject headings. ${unclustered.toLocaleString('en-US')} documents (${(documents > 0 ? (unclustered / documents) * 100 : 0).toLocaleString('en-US', { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%) belong to no cluster and cannot be reached from this list. Era bars reflect each volume's coverage era, not document dates.`,
            """)))
        #expect(view.contains(NoteViewParityTests.flattened("""
            Text(ClustersAxis.indexCaption(
                clusterCount: index.clusters.count,
                unclusteredCount: index.layout.unclusteredCount,
                documentCount: index.documentCount))
            """)))
        #expect(server.contains("layoutIdentity: index.layoutIdentity, clusterCount: index.clusters.count, documentCount: index.documentCount, unclusteredCount: index.layout.unclusteredCount,"))

        // A document of a volume this server lacks, and the server's refusals, the app's, its device and build a server.
        #expect(NoteViewParityTests.writes(view, "browser.clusters.row.notIndexed", "Not indexed on this device"))
        #expect(block.contains("notIndexed: 'Not indexed on this server',"))
        #expect(NoteViewParityTests.writes(view, "browser.clusters.mismatch",
                                           "The cluster data and the semantic vectors come from different releases, so the list is not shown."))
        #expect(server.contains(#"static let mismatchWords = "The cluster data and the semantic vectors come from different releases, so the list is not shown.""#))
        #expect(NoteViewParityTests.writes(view, "browser.clusters.missing",
                                           "This build’s cluster data could not be read. Reinstalling the app restores it."))
        #expect(server.contains(#"static let unreadableWords = "This server’s cluster data could not be read.""#))
    }
}
