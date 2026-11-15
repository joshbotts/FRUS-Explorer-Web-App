// Cross-Reference Analytics (PLAN's S24g): the citation network as a statistical object, as the app's
// `CrossReferenceAnalyticsView` shows it: the most-referenced documents, the degree distribution, the volume heat
// matrix and the PageRank landmarks, with the broken references excluded and said. Every query is the kit's
// `CrossReferenceStore` over the served index (`excludedBrokenCount`, `topDocumentsByInDegree`, `documentTitleFacts`,
// `resolvedInDegrees`, `resolvedOutDegrees`, `volumeLevelConnections`, `resolvedCitationEdges`), in the order the
// view's `loadAll()` asks them; the stats are the kit's `CrossReferenceStats` and `PageRank` (FRUS-Explorer#1891), the
// tables the kit's `AnalyticsChartTables`, the volume labels the kit's `VolumeLabels` and the method block the kit's
// `AnalyticsProvenance`, all compiled from the submodule. What the view and its label files decide between them is
// app code, mirrored here under its names and held to the app's source by `PersonAndCrossReferenceMirrorParityTests`:
// the three limits, `effectiveYearRange`, a row's label (`CrossReferenceTargetLabel`), the matrix's column codes and
// row labels (`matrixColumnCodes`, `HeatMatrixColumnAxis`, `HeatMatrixRowAxis`), the cells' words, the export's
// statement with its caveats, and the words. Each answer is computed once for its index, years and scope and kept
// (`ServedIndex.crossReferenceAnalytics`).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

// MARK: - The answer

/// The app's Cross-Reference Analytics for a year range and a scope: its four sections, each with its table and words.
public struct CrossReferenceAnalyticsAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var years: PersonAnalyticsAnswer.Years
    public var scope: CorpusAnalyticsAnswer.Scope
    /// What the document-level figures count, and the broken references excluded, said when there are any.
    public var resolvedCaption: String
    public var excludedBrokenCount: Int
    public var excludedBrokenCaption: String?
    /// "No Data", the title over a section's empty words.
    public var emptyTitle: String
    public var ranking: Ranking
    public var distribution: Distribution
    public var matrix: Matrix
    public var landmarks: Landmarks

    public struct Document: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// What the row calls the document (`CrossReferenceTargetLabel`).
        public var label: String
        /// Whether the index holds it; a row of a volume not served says so.
        public var isIndexed: Bool
    }

    /// Most-Referenced Documents: the top documents by inbound citations.
    public struct Ranking: Codable, Equatable, Sendable {
        public var heading: String
        public var subtitle: String
        public var rows: [Row]
        public var empty: String?
        public var table: CorpusAnalyticsAnswer.Table

        public struct Row: Codable, Equatable, Sendable {
            public var document: Document
            /// The chart's axis label, the label told apart from another row's of the same words.
            public var axisLabel: String
            public var inDegree: Int
            /// "12 inbound citations", a bar's value for a screen reader.
            public var valueLabel: String
        }
    }

    /// Citation Degree Distribution: how many documents have each inbound count, and each outbound count.
    public struct Distribution: Codable, Equatable, Sendable {
        public var heading: String
        public var subtitle: String
        public var inDegree: [Bucket]
        public var outDegree: [Bucket]
        /// Whether the out-degree overlay is shown, as the request asked; the table's outbound column with it.
        public var showsOutDegree: Bool
        public var empty: String?
        public var table: CorpusAnalyticsAnswer.Table

        public struct Bucket: Codable, Equatable, Sendable {
            public var degree: Int
            public var label: String
            public var documentCount: Int
        }
    }

    /// Volume Citation Heat Matrix: the citations between the volumes with the most references in and out.
    public struct Matrix: Codable, Equatable, Sendable {
        public var heading: String
        public var subtitle: String
        public var volumes: [Volume]
        /// Each row's cells, in the volumes' order, a row citing the column.
        public var rows: [[Cell]]
        public var maxCount: Int
        public var empty: String?
        public var legend: Legend
        public var table: CorpusAnalyticsAnswer.Table

        public struct Volume: Codable, Equatable, Sendable {
            public var id: String
            /// The column's code ("’61–63 VI"), the row's topic and tag, and the volume's title.
            public var code: String
            public var topic: String
            public var tag: String
            public var title: String
        }

        public struct Cell: Codable, Equatable, Sendable {
            public var count: Int
            /// The pointer's help, and what a screen reader says of the cell.
            public var help: String
            public var accessibilityLabel: String
        }

        public struct Legend: Codable, Equatable, Sendable {
            public var low: String
            public var high: String
            public var max: String?
        }
    }

    /// Landmark Documents (Influence): the top documents by an offline PageRank score.
    public struct Landmarks: Codable, Equatable, Sendable {
        public var heading: String
        public var subtitle: String
        public var rows: [Row]
        public var empty: String?
        public var table: CorpusAnalyticsAnswer.Table

        public struct Row: Codable, Equatable, Sendable {
            public var document: Document
            public var score: Double
            /// The score to two significant digits, as a screen reader hears it, and its share of the highest.
            public var scoreLabel: String
            public var fraction: Double
        }
    }
}

/// One kept computation: the view's `loadAll()` for a year range and a scope.
struct CrossReferenceSeries: Sendable {
    var excludedBrokenCount: Int
    var ranking: [(document: CrossReferenceAnalyticsAnswer.Document, inDegree: Int)]
    var distribution: [DegreeBucket]
    var outDistribution: [DegreeBucket]
    var matrixVolumes: [String]
    var matrixCells: [VolumeConnectionEdge]
    var matrixMaxCount: Int
    var landmarks: [(document: CrossReferenceAnalyticsAnswer.Document, score: Double)]
}

/// What the kept answers are kept by: the years the store is given and the scope.
struct CrossReferenceSeriesKey: Hashable, Sendable {
    var yearRange: ClosedRange<Int>?
    var scope: [String]?
}

/// The charts Cross-Reference Analytics exports.
enum CrossReferenceAnalyticsChart: String, CaseIterable, Sendable {
    case ranking
    case distribution
    case matrix
    case landmarks
}

/// What a request asks: the years, the scope and whether the out-degree overlay is shown.
struct CrossReferenceAnalyticsAsk: Sendable, Equatable {
    var start: Int
    var end: Int
    var scope: CorpusAnalyticsAsk.ResolvedScope
    var showOutDegree: Bool
}

enum CrossReferenceAnalyticsRoutes {
    static let parameters: Set<String> = ["from", "to", "outDegree",
                                          "subseries", "volume", "topic", "subtopic", "volumes", "scopeLabel"]

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/analytics/cross-references") { request, _ -> CrossReferenceAnalyticsAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters)
            let served = try await provider.served()
            let ask = try ask(query, served: served, resources: resources)
            let answer = try await answer(ask, served: served, resources: resources)
            withExtendedLifetime(served) {}
            return answer
        }
        router.get("/api/v1/analytics/cross-references/export") { request, _ -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters.union(["chart", "timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let chart = try query.choice("chart", among: CrossReferenceAnalyticsChart.allCases) ?? .ranking
            let served = try await provider.served()
            let ask = try ask(query, served: served, resources: resources)
            let answer = try await answer(ask, served: served, resources: resources)
            let now = Date()
            withExtendedLifetime(served) {}
            let (table, provenance) = try export(chart, ask: ask, answer: answer, indexedVolumeCount: served.indexedVolumeIds.count, date: now)
            let csv = table.provenancedCSV(provenance, for: CorpusAnalyticsRoutes.host(timeZone: timeZone))
            return AnalyticsFigures.csv(csv, name: CorpusAnalyticsRoutes.filenameStem(title: provenance.figureTitle, date: now))
        }
        router.get("/api/v1/analytics/cross-references/plate") { request, _ -> AnalyticsPlate in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters.union(["chart", "timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let chart = try query.choice("chart", among: CrossReferenceAnalyticsChart.allCases) ?? .ranking
            // The app exports the landmarks as a CSV alone.
            guard chart != .landmarks else {
                throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "The landmarks are exported as a CSV alone.")
            }
            let served = try await provider.served()
            let ask = try ask(query, served: served, resources: resources)
            let answer = try await answer(ask, served: served, resources: resources)
            let now = Date()
            withExtendedLifetime(served) {}
            let (_, provenance) = try export(chart, ask: ask, answer: answer, indexedVolumeCount: served.indexedVolumeIds.count, date: now)
            return AnalyticsPlate(provenance, host: CorpusAnalyticsRoutes.host(timeZone: timeZone), date: now)
        }
    }

    // MARK: Reading the request

    static func ask(_ query: FormQuery, served: ServedIndex, resources: ServerResources) throws -> CrossReferenceAnalyticsAsk {
        let maxYear = CorpusAnalyticsRoutes.corpusMaxYear(resources.manifest)
        let start = try query.integer("from", in: CorpusAnalyticsRoutes.earliestYear...maxYear, default: CorpusAnalyticsRoutes.floorYear)
        let end = try query.integer("to", in: CorpusAnalyticsRoutes.earliestYear...maxYear, default: maxYear)
        guard start <= end else { throw APIProblem.invalidParameter("from", "the range must start before it ends, not \(start)–\(end)") }
        return CrossReferenceAnalyticsAsk(
            start: start, end: end,
            scope: try CorpusAnalyticsRoutes.scope(query, served: served, resources: resources),
            showOutDegree: try query.bool("outDegree") ?? false)
    }

    // MARK: The kept series

    /// The view's `loadAll()`: every query in its order, for the store's years and the scope, kept for the index.
    static func series(_ key: CrossReferenceSeriesKey, served: ServedIndex, resources: ServerResources) async throws -> CrossReferenceSeries {
        let store = served.crossReferences
        return try await served.crossReferenceAnalytics.value(for: key) {
            let range = key.yearRange
            let scope = key.scope
            let volumeTitle = { (volumeId: String) in CorpusAnalyticsRoutes.volumeTitle(volumeId, resources: resources) }
            // Unresolvable references excluded from this scope (#240B) — disclosed in the caption.
            let excludedBrokenCount = try await store.excludedBrokenCount(yearRange: range, volumeIds: scope)
            // In-degree ranking.
            let topDocs = try await store.topDocumentsByInDegree(limit: CrossReferenceAnalyticsView.rankingLimit, yearRange: range, volumeIds: scope)
            // One query answers both questions a row asks — is it indexed, and what is it called (#1372).
            let rankingFacts = try await store.documentTitleFacts(
                for: topDocs.map { (volumeId: $0.volumeId, documentId: $0.documentId) })
            let ranking = topDocs.map {
                let target = CrossReferenceTargetLabel.resolve(
                    volumeId: $0.volumeId, documentId: $0.documentId, in: rankingFacts,
                    volumeTitle: volumeTitle($0.volumeId))
                return (document: CrossReferenceAnalyticsAnswer.Document(volumeId: $0.volumeId, documentId: $0.documentId,
                                                                        label: target.label, isIndexed: target.isIndexed),
                        inDegree: $0.inDegree)
            }
            // Degree distributions.
            let inDeg = try await store.resolvedInDegrees(yearRange: range, volumeIds: scope)
            let outDeg = try await store.resolvedOutDegrees(yearRange: range, volumeIds: scope)
            let distribution = CrossReferenceStats.degreeDistribution(inDeg)
            let outDistribution = CrossReferenceStats.degreeDistribution(outDeg)
            // Volume heat matrix (both-endpoints volume scope via limitToVolumeIds; source-anchored date).
            let edges = try await store.volumeLevelConnections(limitToVolumeIds: scope, yearRange: range)
            let topVolumes = CrossReferenceStats.topVolumesByTotalDegree(edges, limit: CrossReferenceAnalyticsView.matrixVolumeLimit)
            let volumeSet = Set(topVolumes)
            let cells = edges
                .filter { volumeSet.contains($0.sourceVolumeId) && volumeSet.contains($0.targetVolumeId) }
            // PageRank landmarks, over the resolved citation graph.
            let citationEdges = try await store.resolvedCitationEdges(yearRange: range, volumeIds: scope)
            // Off the cooperative pool, as the view computes it off the main actor (bounded, offline).
            let scored = try await Blocking.run { PageRank.compute(edges: citationEdges) }
            let topScored = Array(scored.prefix(CrossReferenceAnalyticsView.landmarkLimit))
            // Title facts for the landmark set — membership and name in one query, as for the ranking.
            let landmarkKeys = topScored.map { (volumeId: $0.key.volumeId, documentId: $0.key.documentId) }
            let landmarkFacts = try await store.documentTitleFacts(for: landmarkKeys)
            let landmarks = topScored.map {
                let target = CrossReferenceTargetLabel.resolve(
                    volumeId: $0.key.volumeId, documentId: $0.key.documentId, in: landmarkFacts,
                    volumeTitle: volumeTitle($0.key.volumeId))
                return (document: CrossReferenceAnalyticsAnswer.Document(volumeId: $0.key.volumeId, documentId: $0.key.documentId,
                                                                        label: target.label, isIndexed: target.isIndexed),
                        score: $0.score)
            }
            return CrossReferenceSeries(
                excludedBrokenCount: excludedBrokenCount, ranking: ranking, distribution: distribution,
                outDistribution: outDistribution, matrixVolumes: topVolumes, matrixCells: cells,
                matrixMaxCount: cells.map(\.count).max() ?? 0, landmarks: landmarks)
        }
    }

    static func answer(_ ask: CrossReferenceAnalyticsAsk, served: ServedIndex, resources: ServerResources) async throws -> CrossReferenceAnalyticsAnswer {
        let corpusMaxYear = CorpusAnalyticsRoutes.corpusMaxYear(resources.manifest)
        let key = CrossReferenceSeriesKey(
            yearRange: CrossReferenceAnalyticsView.effectiveYearRange(start: ask.start, end: ask.end, corpusMaxYear: corpusMaxYear),
            scope: ask.scope.volumeIds)
        let series = try await series(key, served: served, resources: resources)
        return CrossReferenceAnalyticsView(ask: ask, series: series, resources: resources).answer(corpusMaxYear: corpusMaxYear)
    }

    // MARK: The export

    /// A chart's table and statement, as the view's `exportRankingCSV()`, `exportDistributionCSV()`, `exportMatrixCSV()`,
    /// `exportLandmarkCSV()` and the three figures' make them, refused where the view's control is disabled.
    static func export(_ chart: CrossReferenceAnalyticsChart, ask: CrossReferenceAnalyticsAsk, answer: CrossReferenceAnalyticsAnswer,
                       indexedVolumeCount: Int, date: Date) throws -> (ChartInspectorData, AnalyticsProvenance) {
        let statement = { (title: String, axisLabel: String, extra: [String]) in
            CrossReferenceAnalyticsView.crossRefProvenance(
                figureTitle: title, axisLabel: axisLabel, extra: extra, excludedBrokenCount: answer.excludedBrokenCount,
                scopeLabel: ask.scope.volumeIds == nil ? nil : answer.scope.label,
                indexedVolumeCount: indexedVolumeCount, start: ask.start, end: ask.end, date: date)
        }
        func nothing(_ what: String) -> APIProblem {
            APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "\(what) holds nothing to export.")
        }
        switch chart {
        case .ranking:
            guard !answer.ranking.rows.isEmpty else { throw nothing(answer.ranking.heading) }
            return (PersonAnalyticsRoutes.inspectorData(answer.ranking.table, id: "crossref.ranking"),
                    statement(answer.ranking.heading, appWords("crossRefAnalytics.export.axis.inDegree", "Ranked by inbound references"), []))
        case .distribution:
            guard !answer.distribution.inDegree.isEmpty else { throw nothing(answer.distribution.heading) }
            return (PersonAnalyticsRoutes.inspectorData(answer.distribution.table, id: "crossref.distribution"),
                    statement(answer.distribution.heading, appWords("crossRefAnalytics.export.axis.degree", "Grouped by references received"), []))
        case .matrix:
            guard !answer.matrix.table.rows.isEmpty else { throw nothing(answer.matrix.heading) }
            return (PersonAnalyticsRoutes.inspectorData(answer.matrix.table, id: "crossref.matrix"),
                    statement(answer.matrix.heading, appWords("crossRefAnalytics.export.axis.matrix", "Cross-volume citation counts"),
                              CrossReferenceAnalyticsView.matrixCaveats))
        case .landmarks:
            guard !answer.landmarks.rows.isEmpty else { throw nothing(answer.landmarks.heading) }
            return (PersonAnalyticsRoutes.inspectorData(answer.landmarks.table, id: "crossref.landmarks"),
                    statement(answer.landmarks.heading, appWords("crossRefAnalytics.export.axis.pageRank", "Ranked by PageRank influence score"),
                              [appWords("crossRefAnalytics.export.caveat.pageRank", "Score: an offline PageRank over the resolved citation graph — a structural measure of how often a document is cited by other well-cited documents. It is a measure of editorial handling, not a claim of historical importance.")]))
        }
    }
}

// MARK: - The view's rules

/// What `CrossReferenceAnalyticsView` decides between the kit's queries and its sections, under its names
/// (`CrossReferenceAnalyticsView.swift`); held to the app's source by the mirror test.
struct CrossReferenceAnalyticsView {
    /// Top-N size for the in-degree ranking.
    static let rankingLimit = 15
    /// Top-N size for the PageRank landmark list.
    static let landmarkLimit = 15
    /// N for the N×N volume heat matrix (readable bound; disclosed in-UI).
    static let matrixVolumeLimit = 15

    let ask: CrossReferenceAnalyticsAsk
    let series: CrossReferenceSeries
    let resources: ServerResources

    /// `true` once the user has narrowed the range away from the full-corpus default.
    static func yearRangeIsCustom(start: Int, end: Int, corpusMaxYear: Int) -> Bool {
        start != 1861 || end != corpusMaxYear
    }

    /// The year range to pass to the store, or `nil` when the range is the full-corpus default (so the store emits no
    /// date SQL and whole-corpus output is byte-for-byte unchanged).
    static func effectiveYearRange(start: Int, end: Int, corpusMaxYear: Int) -> ClosedRange<Int>? {
        yearRangeIsCustom(start: start, end: end, corpusMaxYear: corpusMaxYear) ? PersonAnalyticsView.yearRange(start: start, end: end) : nil
    }

    /// The methods statement for a Cross-Reference Analytics export (`crossRefProvenance`), which always discloses the
    /// unresolvable-reference exclusion.
    static func crossRefProvenance(figureTitle: String, axisLabel: String, extra: [String], excludedBrokenCount: Int,
                                   scopeLabel: String?, indexedVolumeCount: Int, start: Int, end: Int, date: Date) -> AnalyticsProvenance {
        let excluded = CountCopy.phrase(
            excludedBrokenCount,
            one: appWords("crossRefAnalytics.export.caveat.excluded.one", "Unresolvable references: %@ cross-reference is excluded from this analysis — a reference in the printed volumes that points to a document, page, or volume not present in this corpus."),
            many: appWords("crossRefAnalytics.export.caveat.excluded.many", "Unresolvable references: %@ cross-references are excluded from this analysis — references in the printed volumes that point to a document, page, or volume not present in this corpus."),
            locale: SearchItem.locale)
        let sameVolume = appWords("crossRefAnalytics.export.caveat.sameVolume", "Attribution: the document-level figures count same-volume references, including resolved page references, toward the document’s own volume. The volume heat matrix counts only citations between different volumes, so it leaves same-volume references out.")
        return AnalyticsProvenance(
            figureTitle: figureTitle,
            axisLabel: axisLabel,
            scopeLabel: scopeLabel,
            indexedVolumeCount: indexedVolumeCount,
            yearRange: start...end,
            appliesDocumentDating: false,
            valueMode: nil,
            extraCaveats: [excluded, sameVolume] + extra,
            exportDate: date
        )
    }

    /// The caveats every heat-matrix export carries, CSV and figure alike.
    static var matrixCaveats: [String] {
        [
            String(format: appWords("crossRefAnalytics.export.caveat.matrixLimit %lld", "Selection: the matrix covers the %lld volumes with the most references in and out. The CSV lists only pairs with at least one reference between them. The figure draws the whole grid and leaves the rest of the cells blank."),
                   Int64(Self.matrixVolumeLimit)),
            appWords("crossRefAnalytics.export.caveat.matrixAxes", "Axes: rows cite columns. In the figure the column headings are abbreviated volume codes and the row labels are shortened descriptive labels; both volumes’ full titles appear in this CSV."),
        ]
    }

    /// The scope chip's name for the scope (`AnalyticsScopeBar.currentLabel`).
    var scopeLabel: String {
        ask.scope.volumeIds == nil
            ? appWords("analytics.scope.wholeCorpus", "Whole corpus")
            : (ask.scope.label ?? appWords("analytics.scope.custom", "Selected volumes"))
    }

    func volumeTitle(_ volumeId: String) -> String {
        CorpusAnalyticsRoutes.volumeTitle(volumeId, resources: resources)
    }

    func shortVolumeLabel(_ volumeId: String) -> String {
        volumeId.hasPrefix("frus") ? String(volumeId.dropFirst(4)) : volumeId
    }

    // MARK: The answer

    func answer(corpusMaxYear: Int) -> CrossReferenceAnalyticsAnswer {
        let rankingHeading = appWords("crossRefAnalytics.ranking.heading", "Most-Referenced Documents")
        let distributionHeading = appWords("crossRefAnalytics.distribution.heading", "Citation Degree Distribution")
        let matrixHeading = appWords("crossRefAnalytics.matrix.heading", "Volume Citation Heat Matrix")
        let landmarksHeading = appWords("crossRefAnalytics.landmarks.heading", "Landmark Documents (Influence)")
        let ranking = series.ranking
        // The chart's axis labels (`CrossReferenceRankingChart`): the label, and the document id where two read alike.
        let axisLabels = disambiguatedRankingLabels(
            ranking.map { row in
                (id: "\(row.document.volumeId)/\(row.document.documentId)",
                 name: row.document.label,
                 shortSuffix: row.document.documentId)
            }
        )
        let rankingTable = AnalyticsChartTables.crossRefRankingTable(
            title: rankingHeading,
            rows: ranking.map { (volumeId: $0.document.volumeId, documentId: $0.document.documentId,
                                 label: $0.document.label, inDegree: $0.inDegree) })
        // The distribution's tabular form; the outbound column exists only while the overlay is shown.
        let outByLabel = Dictionary(series.outDistribution.map { ($0.label, $0.documentCount) },
                                    uniquingKeysWith: { first, _ in first })
        let showOutDegree = ask.showOutDegree
        let distributionTable = AnalyticsChartTables.crossRefDistributionTable(
            title: distributionHeading,
            rows: series.distribution.map { (bucket: $0.label,
                                             inDegreeDocuments: $0.documentCount,
                                             outDegreeDocuments: showOutDegree ? outByLabel[$0.label] : nil) })
        let matrixTable = AnalyticsChartTables.crossRefMatrixTable(
            title: matrixHeading,
            rows: series.matrixCells.map { cell in
                (sourceId: cell.sourceVolumeId, sourceTitle: volumeTitle(cell.sourceVolumeId),
                 targetId: cell.targetVolumeId, targetTitle: volumeTitle(cell.targetVolumeId),
                 count: cell.count)
            })
        let landmarkTable = AnalyticsChartTables.crossRefLandmarkTable(
            title: landmarksHeading,
            rows: series.landmarks.map { (volumeId: $0.document.volumeId, documentId: $0.document.documentId,
                                          label: $0.document.label, score: $0.score) })
        let maxLandmarkScore = series.landmarks.map(\.score).max() ?? 1
        let excluded = series.excludedBrokenCount
        return CrossReferenceAnalyticsAnswer(
            years: .init(start: ask.start, end: ask.end,
                         isCustom: Self.yearRangeIsCustom(start: ask.start, end: ask.end, corpusMaxYear: corpusMaxYear)),
            scope: .init(label: scopeLabel, volumeIds: ask.scope.volumeIds),
            resolvedCaption: appWords("crossRefAnalytics.resolvedCaption", "The most-referenced, degree, and PageRank charts count same-volume references, including resolved page references, toward the document’s own volume. Set a year range or scope and they count citations made by documents in that era or scope. The heat matrix counts only connections between different volumes, so it leaves same-volume citations out."),
            excludedBrokenCount: excluded,
            excludedBrokenCaption: excluded > 0
                ? CountCopy.phrase(
                    excluded,
                    one: appWords("crossRefAnalytics.excludedBrokenCaption.one", "%@ unresolvable reference is excluded from this analysis — a cross-reference in the printed volumes that points to a document, page, or volume not present in the corpus."),
                    many: appWords("crossRefAnalytics.excludedBrokenCaption.many", "%@ unresolvable references are excluded from this analysis — cross-references in the printed volumes that point to a document, page, or volume not present in the corpus."),
                    locale: SearchItem.locale)
                : nil,
            emptyTitle: appWords("crossRefAnalytics.section.empty.title", "No Data"),
            ranking: .init(
                heading: rankingHeading,
                subtitle: appWords("crossRefAnalytics.ranking.subtitle", "Top documents by inbound citation count (in-degree). Select a document to open it."),
                rows: ranking.map { row in
                    let id = "\(row.document.volumeId)/\(row.document.documentId)"
                    return .init(document: row.document, axisLabel: axisLabels[id] ?? row.document.label, inDegree: row.inDegree,
                                 valueLabel: appWords("crossRefAnalytics.axis.inDegreeValue", "\(grouped(row.inDegree)) inbound citations"))
                },
                empty: ranking.isEmpty
                    ? appWords("crossRefAnalytics.ranking.empty", "No resolved cross-references are indexed yet. Index more volumes to build the citation network.")
                    : nil,
                table: PersonAnalyticsView.table(rankingTable)),
            distribution: .init(
                heading: distributionHeading,
                subtitle: appWords("crossRefAnalytics.distribution.subtitle", "How many documents have each inbound-citation count — a few landmark documents and a long tail. Toggle the out-degree overlay to compare how many citations documents make."),
                inDegree: series.distribution.map { .init(degree: $0.degree, label: $0.label, documentCount: $0.documentCount) },
                outDegree: series.outDistribution.map { .init(degree: $0.degree, label: $0.label, documentCount: $0.documentCount) },
                showsOutDegree: showOutDegree,
                empty: series.distribution.isEmpty
                    ? appWords("crossRefAnalytics.distribution.empty", "No resolved cross-references to chart.")
                    : nil,
                table: PersonAnalyticsView.table(distributionTable)),
            matrix: matrix(heading: matrixHeading, table: matrixTable),
            landmarks: .init(
                heading: landmarksHeading,
                subtitle: appWords("crossRefAnalytics.landmarks.subtitle", "Ranked by a PageRank score computed on this device over the citations the app resolved. These are the documents a reader who follows citations would keep returning to. The score measures position in the citation network, not historical importance. Select one to open it."),
                rows: series.landmarks.map { row in
                    .init(document: row.document, score: row.score,
                          scoreLabel: row.score.formatted(.number.precision(.significantDigits(2)).locale(SearchItem.locale)),
                          fraction: maxLandmarkScore > 0 ? row.score / maxLandmarkScore : 0)
                },
                empty: series.landmarks.isEmpty
                    ? appWords("crossRefAnalytics.landmarks.empty", "No resolved citation graph to rank yet.")
                    : nil,
                table: PersonAnalyticsView.table(landmarkTable)))
    }

    /// The heat matrix: its volumes' codes, labels and titles (`matrixLabels`), and every cell with its words.
    func matrix(heading: String, table: ChartInspectorData) -> CrossReferenceAnalyticsAnswer.Matrix {
        let volumes = series.matrixVolumes
        let entries = volumes.map { (id: $0, entry: resources.volume($0)) }
        let codes = matrixColumnCodes(entries.map { HeatMatrixColumnAxis.column(volumeId: $0.id, entry: $0.entry) })
        let rows = Dictionary(uniqueKeysWithValues: entries.map { id, entry in (id, HeatMatrixRowAxis.label(volumeId: id, entry: entry)) })
        var counts: [String: Int] = [:]
        for cell in series.matrixCells { counts["\(cell.sourceVolumeId)\u{1}\(cell.targetVolumeId)"] = cell.count }
        func cellCount(source: String, target: String) -> Int { counts["\(source)\u{1}\(target)"] ?? 0 }
        return .init(
            heading: heading,
            subtitle: appWords("crossRefAnalytics.matrix.subtitle", "Citations between the \(grouped(Self.matrixVolumeLimit)) volumes with the most references in and out. Rows cite columns. Darker cells mean more references. Select a volume label to open it."),
            volumes: volumes.map { id in
                let parts = rows[id] ?? HeatMatrixRowAxis.label(volumeId: id, entry: nil)
                return .init(id: id, code: codes[id] ?? shortVolumeLabel(id), topic: parts.topic, tag: parts.tag, title: volumeTitle(id))
            },
            rows: volumes.map { source in
                volumes.map { target in
                    let count = cellCount(source: source, target: target)
                    return .init(
                        count: count,
                        help: count > 0
                            ? appWords("crossRefAnalytics.matrix.cell.help", "\(shortVolumeLabel(source)) → \(shortVolumeLabel(target)): \(grouped(count)) references")
                            : appWords("crossRefAnalytics.matrix.cell.none", "\(shortVolumeLabel(source)) → \(shortVolumeLabel(target)): no references"),
                        accessibilityLabel: count > 0
                            ? appWords("crossRefAnalytics.matrix.cell.axLabel", "\(volumeTitle(source)) cites \(volumeTitle(target)): \(grouped(count)) references")
                            : appWords("crossRefAnalytics.matrix.cell.axLabel.none", "\(volumeTitle(source)) cites \(volumeTitle(target)): no references"))
                }
            },
            maxCount: series.matrixMaxCount,
            empty: volumes.count < 2
                ? appWords("crossRefAnalytics.matrix.empty", "Not enough cross-volume references are indexed to build a heat matrix. Index more volumes.")
                : nil,
            legend: .init(low: appWords("crossRefAnalytics.matrix.legend.low", "Fewer"),
                          high: appWords("crossRefAnalytics.matrix.legend.high", "More"),
                          max: series.matrixMaxCount > 0 ? appWords("crossRefAnalytics.matrix.legend.max", "(max \(grouped(series.matrixMaxCount)))") : nil),
            table: PersonAnalyticsView.table(table))
    }
}

// MARK: - A row's label

/// What a Cross-Reference Analytics row calls the document it names (#1372), `CrossReferenceTargetLabel`: an indexed
/// document is named as every other list names it, `DocumentDisplayTitle`, and only a document the index does not hold
/// gets the manifest form, "Document 245 — <volume title>", or its id where it spells no number.
enum CrossReferenceTargetLabel {
    static func text(facts: CrossReferenceStore.DocumentTitleFacts?,
                     documentId: String, volumeTitle: String) -> String {
        if let facts { return DocumentDisplayTitle.text(facts, documentId: documentId) }
        guard let number = CitableDocumentNumber.fromDocumentId(documentId) else {
            return "\(documentId) — \(volumeTitle)"
        }
        let prefix = appWords("crossRefAnalytics.row.documentPrefix", "Document")
        return "\(prefix) \(number) — \(volumeTitle)"
    }

    static func resolve(volumeId: String, documentId: String,
                        in facts: [String: CrossReferenceStore.DocumentTitleFacts],
                        volumeTitle: String) -> (label: String, isIndexed: Bool) {
        let found = facts["\(volumeId)/\(documentId)"]
        return (text(facts: found, documentId: documentId, volumeTitle: volumeTitle), found != nil)
    }
}

// MARK: - The heat matrix's labels

/// Builds compact, horizontal, collision-free column codes for the heat matrix (`matrixColumnCodes`,
/// `RankingChartLabels.swift`): a volume's span in apostrophe form, with its number or its first distinctive topic word,
/// escalated with more topic words, and last with the volume id's suffix, where two would read alike.
func matrixColumnCodes(
    _ columns: [(id: String, subseries: String, title: String, topic: String)]
) -> [String: String] {
    typealias Column = (id: String, subseries: String, title: String, topic: String)
    // Level-0 base code: span + (Roman numeral | first topic word | nothing).
    func base(_ c: Column) -> String {
        let years = matrixYearCode(c.subseries)
        if let numeral = firstVolumeNumeral(in: c.title) { return "\(years) \(numeral)" }
        if let word = matrixTopicWords(c.topic).first { return "\(years) \(String(word.prefix(6)))" }
        return years
    }
    // Escalated code: append the *next* distinctive token beyond what the base used, ≤6 chars so it
    // stays short enough for a narrow column.
    func expanded(_ c: Column) -> String {
        let years = matrixYearCode(c.subseries)
        let words = matrixTopicWords(c.topic)
        if let numeral = firstVolumeNumeral(in: c.title) {
            guard let first = words.first else { return "\(years) \(numeral)" }
            return "\(years) \(numeral) \(String(first.prefix(6)))"
        }
        var s = years
        if let first = words.first { s += " \(String(first.prefix(6)))" }
        if let second = words.dropFirst().first { s += " \(String(second.prefix(6)))" }
        return s
    }
    // Pass 1 — base codes.
    var baseCounts: [String: Int] = [:]
    let bases = columns.map { (id: $0.id, code: base($0)) }
    for b in bases { baseCounts[b.code, default: 0] += 1 }
    // Pass 2 — expand any shared base with topic words.
    var provisional: [String: String] = [:]
    var provisionalCounts: [String: Int] = [:]
    for (c, b) in zip(columns, bases) {
        let code = (baseCounts[b.code] ?? 0) > 1 ? expanded(c) : b.code
        provisional[c.id] = code
        provisionalCounts[code, default: 0] += 1
    }
    // Pass 3 — guaranteed-unique id-suffix fallback for anything still shared.
    var result: [String: String] = [:]
    for c in columns {
        let code = provisional[c.id] ?? base(c)
        if (provisionalCounts[code] ?? 0) > 1 {
            var suffix = c.id
            if suffix.hasPrefix("frus") { suffix = String(suffix.dropFirst(4)) }
            if suffix.hasPrefix(c.subseries) { suffix = String(suffix.dropFirst(c.subseries.count)) }
            suffix = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
            let years = matrixYearCode(c.subseries)
            result[c.id] = suffix.isEmpty ? years : "\(years) \(suffix)"
        } else {
            result[c.id] = code
        }
    }
    return result
}

/// The apostrophe-form coverage span for a subseries: `"1955-57"` → `"’55–57"`, `"1861"` → `"’61"`.
private func matrixYearCode(_ subseries: String) -> String {
    let parts = subseries.split(separator: "-", maxSplits: 1)
    if parts.count == 2 {
        return "\u{2019}\(parts[0].suffix(2))–\(parts[1].suffix(2))"
    }
    return "\u{2019}\(subseries.suffix(2))"
}

/// The first "Volume <N>" number in a manifest title, verbatim, or `nil` when the title carries none.
private func firstVolumeNumeral(in title: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: "Volumes?\\s+(E[–-][0-9]+|[IVXLCDM]+)\\b") else { return nil }
    let ns = title as NSString
    guard let m = regex.firstMatch(in: title, range: NSRange(location: 0, length: ns.length)),
          m.numberOfRanges > 1 else { return nil }
    return ns.substring(with: m.range(at: 1))
}

/// The distinctive words of a distilled topic — dropping leading articles/prepositions and any trailing ellipsis, and a
/// leading "Documents on" when a word follows it.
func matrixTopicWords(_ topic: String) -> [String] {
    let stop: Set<String> = ["the", "of", "and", "to", "a", "an", "in", "on", "for"]
    let tokens = topic
        .replacingOccurrences(of: "…", with: " ")
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { $0.count >= 2 }
    let words = Array(tokens.drop { stop.contains($0.lowercased()) })
    guard words.count >= 2, words[0].lowercased() == "documents", words[1].lowercased() == "on" else {
        return words
    }
    // "Documents on the United Nations" → "United": the words after "on", less their own articles.
    let rest = Array(words.dropFirst(2).drop { stop.contains($0.lowercased()) })
    return rest.isEmpty ? words : rest
}

/// The heat matrix's column axis: what `matrixColumnCodes` is given for each volume (`HeatMatrixColumnAxis`).
enum HeatMatrixColumnAxis {
    typealias Column = (id: String, subseries: String, title: String, topic: String)

    /// A volume's column, from its manifest entry: its topic the joined `distilledVolumeLabel`'s topic half.
    static func column(volumeId: String, entry: VolumeManifestEntry?) -> Column {
        let subseries = entry?.subseries ?? ""
        let title = entry?.title ?? volumeId
        let distilled = VolumeLabels.distilledVolumeLabel(volumeId: volumeId, subseries: subseries, title: title)
        let topic = distilled.contains(" · ") ? String(distilled.components(separatedBy: " · ").first ?? "") : ""
        return (id: volumeId, subseries: subseries, title: title, topic: topic)
    }
}

/// The heat matrix's row axis: what each row's label reads (`HeatMatrixRowAxis`).
enum HeatMatrixRowAxis {
    /// A volume's row label, as its topic and its tag; a volume the manifest does not describe is its tag alone.
    static func label(volumeId: String, entry: VolumeManifestEntry?) -> VolumeLabelParts {
        // No entry, no title: an empty title yields an empty topic, and the tag reads the id alone.
        VolumeLabels.distilledVolumeLabelParts(volumeId: volumeId, subseries: entry?.subseries ?? "",
                                               title: entry?.title ?? "")
    }
}
