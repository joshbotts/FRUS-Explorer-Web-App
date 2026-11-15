// Person Analytics (PLAN's S24g): the most-mentioned people of a year range, the mention trajectories of up to five
// people, the relationship of two, and the co-mention network around one, as the app's `PersonAnalyticsView` and
// `PersonCoMentionGraphView` show them. Every query is the kit's `PersonMentionStore` over the served index
// (`topPeopleByMentions(inYearRange:)`, `mentionTrajectories`, `mentioningDocumentTrajectories`,
// `datedDocumentTotalsByYear`, `coMentionTimeline`, `rollupsMatchingName`), in the order the view asks them; the
// trajectory and relationship maths are the kit's `PersonAnalyticsMath` and `PersonRelationshipMath`, the network's
// nodes, edges, partners and cap the kit's `PersonCoMentionNetwork` (FRUS-Explorer#1899), the tables the kit's
// `AnalyticsChartTables` and the method block the kit's `AnalyticsProvenance`, all compiled from the submodule. What
// the view decides between them is mirrored here under the view's names and held to the app's source by
// `PersonAndCrossReferenceMirrorParityTests`: the two caps, the year range and `yearRangeIsCustom`,
// `trajectoryPoints`, `trajectorySeriesBody`, `relationshipPoints`, the period's name, the export's statement with its
// caveats, and the words. Each series is computed once for its index and kept (`ServedIndex.personAnalytics`).
//
// The web's own: the browser shows a chart and its table at once, so the view's chart or table mode is not asked for;
// the comparison is the address's, so a person added or removed is a new request; and the network's focus is the
// browser's, the ranking's first person until the reader picks one, as the app's `PersonNetworkFocus` seeds it. The
// caption under the scope bar that counts the volumes tagging their people (`PeopleTaggingCaption`) is not here.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

// MARK: - The answers

/// The Trends half of the app's Person Analytics for a year range, a scope and a comparison: the ranking, the
/// trajectories and, for two people, their relationship, each with its table and words.
public struct PersonAnalyticsAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var years: Years
    public var scope: CorpusAnalyticsAnswer.Scope
    public var ranking: Ranking
    public var comparison: Comparison
    /// The relationship of the two people compared, or nil unless exactly two are.
    public var relationship: Relationship?

    public struct Years: Codable, Equatable, Sendable {
        public var start: Int
        public var end: Int
        /// Whether the range is narrowed away from 1861 to the corpus's last year (`yearRangeIsCustom`).
        public var isCustom: Bool
    }

    /// An empty state's title and words (`ContentUnavailableView`).
    public struct Words: Codable, Equatable, Sendable {
        public var title: String
        public var detail: String
    }

    /// Most-Mentioned People: the top people by mentions in dated documents within the range.
    public struct Ranking: Codable, Equatable, Sendable {
        public var heading: String
        public var subtitle: String
        public var rows: [Row]
        public var empty: Words?
        public var table: CorpusAnalyticsAnswer.Table

        public struct Row: Codable, Equatable, Sendable {
            public var rollupId: Int
            public var name: String
            /// The chart's axis label, the name told apart from another rollup's of the same name.
            public var axisLabel: String
            public var mentions: Int
            /// "12 mentions", a bar's value for a screen reader.
            public var mentionsLabel: String
        }
    }

    /// Mention Trajectories: each compared person's mentions, or share of dated documents, by year or decade.
    public struct Comparison: Codable, Equatable, Sendable {
        public var heading: String
        public var people: [Person]
        /// The rollup ids the request named that the index no longer holds, left out of the comparison: a correction
        /// that renumbers the rollup, or an old address, leaves them, and the page drops them, where a refusal would
        /// leave it nothing to show.
        public var missing: [Int]
        /// Whether the comparison holds its five, and the sentence the add field says then.
        public var atCap: Bool
        public var capNote: String
        /// The prompt shown while no one is compared.
        public var prompt: String
        public var isNormalized: Bool
        public var byDecade: Bool
        /// Year or Decade, the period column's name.
        public var periodLabel: String
        public var xAxisLabel: String
        public var valueAxisLabel: String
        public var points: [Point]
        public var empty: Words?
        public var caption: String
        public var table: CorpusAnalyticsAnswer.Table

        public struct Person: Codable, Equatable, Sendable {
            public var rollupId: Int
            public var name: String
        }

        public struct Point: Codable, Equatable, Sendable {
            public var rollupId: Int
            public var name: String
            public var period: Int
            public var value: Double
        }
    }

    /// Relationship Dynamics: the dated documents that tag both people compared, by year or decade.
    public struct Relationship: Codable, Equatable, Sendable {
        public var heading: String
        public var subtitle: String
        public var xAxisLabel: String
        public var valueAxisLabel: String
        public var points: [Point]
        public var empty: Words?
        public var caption: String
        public var table: CorpusAnalyticsAnswer.Table

        public struct Point: Codable, Equatable, Sendable {
            public var period: Int
            public var coMentions: Int
        }
    }
}

/// The people whose canonical name holds a fragment, for the add field and the focus search (`rollupsMatchingName`).
public struct PersonAnalyticsMatches: Codable, Equatable, Sendable, ResponseEncodable {
    public var people: [Person]

    public struct Person: Codable, Equatable, Sendable {
        public var rollupId: Int
        public var name: String
        /// Mentions across the whole corpus, the rollup's own count.
        public var mentions: Int
    }
}

/// The co-mention network around one person (CA-8): the focus and their partners, the kit's choice, with the edges
/// among them and the words the app's graph says.
public struct PersonNetworkAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var focus: Node
    /// `graph`, or `empty` when the focus is co-mentioned with no one.
    public var state: String
    public var empty: PersonAnalyticsAnswer.Words?
    /// The focus first, then the partners, most shared documents first (`partners`).
    public var nodes: [Node]
    public var edges: [Edge]
    /// The probe's count, a lower bound once the cap bites (#1385), and whether it did.
    public var totalPartnerCount: Int
    public var capApplied: Bool
    /// The legend's sentence: the cap's disclosure, or that every partner is shown.
    public var footer: String

    public struct Node: Codable, Equatable, Sendable {
        public var rollupId: Int
        public var name: String
        /// The name cut to sixteen characters at a word's end (`GraphNodeLabels.shortLabel`), as the canvas labels it.
        public var label: String
        public var sharedWithFocus: Int
        public var isFocus: Bool
        /// "12 shared documents with Kennan, George F.", the node's value for a screen reader; nil for the focus.
        public var accessibilityValue: String?
        /// "12 shared documents with …", the info dock's line; nil for the focus.
        public var sharedLine: String?
    }

    public struct Edge: Codable, Equatable, Sendable {
        public var a: Int
        public var b: Int
        public var sharedDocuments: Int
        /// Whether the edge meets the focus, drawn in the accent colour as a spoke.
        public var isSpoke: Bool
    }
}

// MARK: - The request

/// What a request asks: the years, the scope, the people compared in the order added, the decade switch and the values.
struct PersonAnalyticsAsk: Sendable, Equatable {
    var start: Int
    var end: Int
    var scope: CorpusAnalyticsAsk.ResolvedScope
    var people: [PersonAnalyticsAnswer.Comparison.Person]
    /// The ids named that the index no longer holds.
    var missing: [Int] = []
    var byDecade: Bool
    var normalization: PersonTrajectoryNormalization
}

/// What the kept series are kept by.
enum PersonSeriesKey: Hashable, Sendable {
    case ranking(ClosedRange<Int>, scope: [String]?)
    case trajectories([Int], scope: [String]?)
    case totals(scope: [String]?)
    case relationship(Int, Int, scope: [String]?)
    case network(Int, scope: [String]?)
}

/// A kept series of Person Analytics.
enum PersonSeries: Sendable {
    case ranking([PersonMentionRanking])
    case trajectories(raw: [Int: [Int: Int]], documents: [Int: [Int: Int]])
    case totals([Int: Int])
    case relationship([Int: Int])
    case network(nodes: [PersonCoMentionNode], totalPartnerCount: Int, edges: [PersonCoMentionEdge])
}

enum PersonAnalyticsRoutes {
    /// The parameters each route takes.
    static let parameters: Set<String> = ["from", "to", "people", "decade", "values",
                                          "subseries", "volume", "topic", "subtopic", "volumes", "scopeLabel"]
    static let scopeParameters: Set<String> = ["subseries", "volume", "topic", "subtopic", "volumes", "scopeLabel"]
    /// The longest fragment the name search takes.
    static let maximumQueryLength = 200

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/analytics/people") { request, _ -> PersonAnalyticsAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters)
            let served = try await provider.served()
            let ask = try await ask(query, served: served, resources: resources)
            let answer = try await answer(ask, served: served, resources: resources)
            withExtendedLifetime(served) {}
            return answer
        }
        router.get("/api/v1/analytics/people/search") { request, _ -> PersonAnalyticsMatches in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["q"])
            // `runPersonSearch()` trims the field's spaces, and a blank field matches no one.
            let text = (try query.single("q") ?? "").trimmingCharacters(in: .whitespaces)
            guard text.count <= maximumQueryLength else {
                throw APIProblem.invalidParameter("q", "is longer than \(maximumQueryLength) characters")
            }
            let served = try await provider.served()
            let people = text.isEmpty ? [] : try await served.persons.rollupsMatchingName(text, limit: 20)
            withExtendedLifetime(served) {}
            return PersonAnalyticsMatches(people: people.map { .init(rollupId: $0.rollupId, name: $0.canonicalName, mentions: $0.mentionCount) })
        }
        router.get("/api/v1/analytics/people/network") { request, _ -> PersonNetworkAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(scopeParameters.union(["focus"]))
            let served = try await provider.served()
            guard let raw = try query.single("focus") else { throw APIProblem.invalidParameter("focus", "a network is centred on a person") }
            let focus = try await person(raw, parameter: "focus", served: served)
            let scope = try CorpusAnalyticsRoutes.scope(query, served: served, resources: resources)
            let answer = try await network(focus: focus, scope: scope, served: served)
            withExtendedLifetime(served) {}
            return answer
        }
        router.get("/api/v1/analytics/people/export") { request, _ -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters.union(["chart", "timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let chart = try query.choice("chart", among: PersonAnalyticsChart.allCases) ?? .ranking
            let served = try await provider.served()
            let ask = try await ask(query, served: served, resources: resources)
            let answer = try await answer(ask, served: served, resources: resources)
            let now = Date()
            withExtendedLifetime(served) {}
            let (table, provenance) = try export(chart, ask: ask, answer: answer, indexedVolumeCount: served.indexedVolumeIds.count,
                                                 figure: false, date: now)
            let csv = table.provenancedCSV(provenance, for: CorpusAnalyticsRoutes.host(timeZone: timeZone))
            return AnalyticsFigures.csv(csv, name: CorpusAnalyticsRoutes.filenameStem(title: provenance.figureTitle, date: now))
        }
        router.get("/api/v1/analytics/people/plate") { request, _ -> AnalyticsPlate in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(parameters.union(["chart", "timeZone"]))
            let timeZone = try AnalyticsFigures.timeZone(query)
            let chart = try query.choice("chart", among: PersonAnalyticsChart.allCases) ?? .ranking
            // The app exports the ranking and the trajectories as figures, and the relationship as a CSV alone.
            guard chart != .relationship else {
                throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "The relationship is exported as a CSV alone.")
            }
            let served = try await provider.served()
            let ask = try await ask(query, served: served, resources: resources)
            let answer = try await answer(ask, served: served, resources: resources)
            let now = Date()
            withExtendedLifetime(served) {}
            let (_, provenance) = try export(chart, ask: ask, answer: answer, indexedVolumeCount: served.indexedVolumeIds.count,
                                             figure: true, date: now)
            return AnalyticsPlate(provenance, host: CorpusAnalyticsRoutes.host(timeZone: timeZone), date: now)
        }
    }

    // MARK: Reading the request

    /// The request's years, scope, people, decade switch and values, each checked.
    static func ask(_ query: FormQuery, served: ServedIndex, resources: ServerResources) async throws -> PersonAnalyticsAsk {
        let maxYear = CorpusAnalyticsRoutes.corpusMaxYear(resources.manifest)
        let earliest = CorpusAnalyticsRoutes.earliestYear
        let start = try query.integer("from", in: earliest...maxYear, default: CorpusAnalyticsRoutes.floorYear)
        let end = try query.integer("to", in: earliest...maxYear, default: maxYear)
        guard start <= end else { throw APIProblem.invalidParameter("from", "the range must start before it ends, not \(start)–\(end)") }
        let raw = query.values("people")
        // The add field disables at the cap (`atComparisonCap`), and a person is added once (`isSelected`).
        guard raw.count <= PersonAnalyticsView.maxComparisonPeople else {
            throw APIProblem.invalidParameter("people", "compares at most \(PersonAnalyticsView.maxComparisonPeople) people, not \(raw.count)")
        }
        let ids = try raw.map { try rollupId($0, parameter: "people") }
        // Once each by rollup id: the view's names are keyed by it (`selectedNames`).
        guard Set(ids).count == ids.count else { throw APIProblem.invalidParameter("people", "names a person twice") }
        var people: [PersonAnalyticsAnswer.Comparison.Person] = []
        var missing: [Int] = []
        for id in ids {
            if let person = try await named(id, served: served) { people.append(person) } else { missing.append(id) }
        }
        return PersonAnalyticsAsk(
            start: start, end: end,
            scope: try CorpusAnalyticsRoutes.scope(query, served: served, resources: resources),
            people: people,
            missing: missing,
            byDecade: try query.bool("decade") ?? false,
            normalization: try query.choice("values", among: PersonTrajectoryNormalization.allCases) ?? .raw)
    }

    /// A rollup id as the server writes it, so that one person is never two requests' keys.
    static func rollupId(_ raw: String, parameter: String) throws -> Int {
        guard !raw.isEmpty, raw.allSatisfy(\.isASCIIDigitCharacter), raw.count <= 18, let id = Int(raw), String(id) == raw else {
            throw APIProblem.invalidParameter(parameter, "names a person by their rollup id, not \(raw)")
        }
        return id
    }

    /// A person of the served index's rollup, with their canonical name, which the app's ranking and search rows carry
    /// (`PersonMentionRanking.canonicalName`), or nil when the index holds no such rollup.
    static func named(_ id: Int, served: ServedIndex) async throws -> PersonAnalyticsAnswer.Comparison.Person? {
        try await served.people.list(served.persons).byRollup[id].map { .init(rollupId: id, name: $0.entry.name) }
    }

    /// The person a network is centred on, refused when the index holds no such rollup.
    static func person(_ raw: String, parameter: String, served: ServedIndex) async throws -> PersonAnalyticsAnswer.Comparison.Person {
        let id = try rollupId(raw, parameter: parameter)
        guard let person = try await named(id, served: served) else {
            throw APIProblem(.notFound, code: "PERSON_NOT_FOUND", detail: "No person of the served index has the rollup id \(id).")
        }
        return person
    }

    // MARK: The kept series

    static func ranking(_ range: ClosedRange<Int>, scope: [String]?, served: ServedIndex) async throws -> [PersonMentionRanking] {
        let store = served.persons
        guard case .ranking(let rows) = try await served.personAnalytics.value(for: .ranking(range, scope: scope), compute: {
            .ranking(try await store.topPeopleByMentions(inYearRange: range, limit: PersonAnalyticsView.rankingLimit, volumeIds: scope))
        }) else { return [] }
        return rows
    }

    static func trajectories(_ ids: [Int], scope: [String]?, served: ServedIndex) async throws
        -> (raw: [Int: [Int: Int]], documents: [Int: [Int: Int]], totals: [Int: Int]) {
        let store = served.persons
        // `loadTrajectories()` asks the three at once, for the people compared.
        guard case .trajectories(let raw, let documents) = try await served.personAnalytics.value(for: .trajectories(ids.sorted(), scope: scope), compute: {
            async let raw = store.mentionTrajectories(rollupIds: ids, volumeIds: scope)
            async let documents = store.mentioningDocumentTrajectories(rollupIds: ids, volumeIds: scope)
            return .trajectories(raw: try await raw, documents: try await documents)
        }), case .totals(let totals) = try await served.personAnalytics.value(for: .totals(scope: scope), compute: {
            .totals(try await store.datedDocumentTotalsByYear(volumeIds: scope))
        }) else { return ([:], [:], [:]) }
        return (raw, documents, totals)
    }

    static func relationship(_ a: Int, _ b: Int, scope: [String]?, served: ServedIndex) async throws -> [Int: Int] {
        let store = served.persons
        guard case .relationship(let timeline) = try await served.personAnalytics.value(for: .relationship(a, b, scope: scope), compute: {
            .relationship(try await store.coMentionTimeline(rollupA: a, rollupB: b, volumeIds: scope))
        }) else { return [:] }
        return timeline
    }

    // MARK: The answers

    /// The Trends dashboard, as the view's `loadRanking()`, `loadTrajectories()` and `loadRelationship()` load it.
    static func answer(_ ask: PersonAnalyticsAsk, served: ServedIndex, resources: ServerResources) async throws -> PersonAnalyticsAnswer {
        let corpusMaxYear = CorpusAnalyticsRoutes.corpusMaxYear(resources.manifest)
        let yearRange = PersonAnalyticsView.yearRange(start: ask.start, end: ask.end)
        let scope = ask.scope.volumeIds
        let ranking = try await ranking(yearRange, scope: scope, served: served)
        let ids = ask.people.map(\.rollupId)
        let loaded = ids.isEmpty
            ? (raw: [:], documents: [:], totals: [:])
            : try await trajectories(ids, scope: scope, served: served)
        let timeline = ask.people.count == 2
            ? try await relationship(ask.people[0].rollupId, ask.people[1].rollupId, scope: scope, served: served)
            : [:]
        let view = PersonAnalyticsView(ask: ask, ranking: ranking, rawTrajectories: loaded.raw, mentioningDocs: loaded.documents,
                                       datedTotals: loaded.totals, relationshipTimeline: timeline)
        return view.answer(corpusMaxYear: corpusMaxYear)
    }

    /// The network around `focus`, as the graph's view model's `load(from:volumeIds:)` reads it, in the kit's two halves.
    static func network(focus: PersonAnalyticsAnswer.Comparison.Person, scope: CorpusAnalyticsAsk.ResolvedScope,
                        served: ServedIndex) async throws -> PersonNetworkAnswer {
        let store = served.persons
        let volumeIds = scope.volumeIds
        guard case .network(let nodes, let total, let edges) = try await served.personAnalytics.value(
            for: .network(focus.rollupId, scope: volumeIds), compute: {
                let ego = try await PersonCoMentionNetwork.nodes(
                    focusRollupId: focus.rollupId, focusName: focus.name, store: store, volumeIds: volumeIds)
                let edges = try await PersonCoMentionNetwork.edges(among: ego.nodes, store: store, volumeIds: volumeIds)
                return .network(nodes: ego.nodes, totalPartnerCount: ego.totalPartnerCount, edges: edges)
            }) else { throw APIProblem(.internalServerError, code: "INTERNAL_ERROR", detail: "The network was not kept as one.") }
        return PersonNetworkView.answer(focus: focus, nodes: nodes, totalPartnerCount: total, edges: edges)
    }

    // MARK: The export

    /// A chart's table and statement, as the view's `exportRankingCSV()`, `exportTrajectoryCSV()`,
    /// `exportRelationshipCSV()`, `exportRankingFigure(_:)` and `exportTrajectoryFigure(_:)` make them, refused where the
    /// view's control is disabled.
    static func export(_ chart: PersonAnalyticsChart, ask: PersonAnalyticsAsk, answer: PersonAnalyticsAnswer,
                       indexedVolumeCount: Int, figure: Bool, date: Date) throws -> (ChartInspectorData, AnalyticsProvenance) {
        let statement = { (title: String, periodGrain: String?, valueMode: String?, extra: [String]) in
            PersonAnalyticsView.personProvenance(figureTitle: title, periodGrain: periodGrain, valueMode: valueMode, extra: extra,
                                                 scopeLabel: ask.scope.volumeIds == nil ? nil : answer.scope.label,
                                                 indexedVolumeCount: indexedVolumeCount, start: ask.start, end: ask.end, date: date)
        }
        let periodGrain = PersonAnalyticsView.periodGrainLabel(byDecade: ask.byDecade)
        switch chart {
        case .ranking:
            guard !answer.ranking.rows.isEmpty else {
                throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "No one is ranked in this range.")
            }
            return (inspectorData(answer.ranking.table, id: "person.ranking"),
                    statement(answer.ranking.heading, nil, nil, []))
        case .trajectories:
            guard !ask.people.isEmpty else {
                throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "No one is compared.")
            }
            // The figure's statement leaves the decade shares' caveat to the CSV, as the app's does.
            let extra = figure ? [] : PersonAnalyticsView.decadeShareCaveat(byDecade: ask.byDecade, isNormalized: ask.normalization == .percentOfDocuments)
            return (inspectorData(answer.comparison.table, id: "person.trajectory"),
                    statement(answer.comparison.heading, periodGrain, ask.normalization.pickerLabel, extra))
        case .relationship:
            guard let relationship = answer.relationship else {
                throw APIProblem(.notFound, code: "NOTHING_TO_EXPORT", detail: "A relationship is of two people compared.")
            }
            return (inspectorData(relationship.table, id: "person.relationship"),
                    statement(relationship.heading, periodGrain, nil, []))
        }
    }

    static func inspectorData(_ table: CorpusAnalyticsAnswer.Table, id: String) -> ChartInspectorData {
        ChartInspectorData(id: id, title: table.title, columns: table.columns, rowCells: table.rows)
    }
}

/// The charts Person Analytics exports.
enum PersonAnalyticsChart: String, CaseIterable, Sendable {
    case ranking
    case trajectories
    case relationship
}

// MARK: - The view's rules

/// What `PersonAnalyticsView` decides between the kit's queries and its charts, under its names (`PersonAnalyticsView.swift`),
/// with `PersonAnalyticsCopy.rankingSubtitle(_:)`; held to the app's source by the mirror test.
struct PersonAnalyticsView {
    /// Maximum people in the comparison chart — the documented cap (no silent truncation: the add field disables at the
    /// cap and says why).
    static let maxComparisonPeople = 5
    /// Top-N size for the "most mentioned" ranking.
    static let rankingLimit = 15

    let ask: PersonAnalyticsAsk
    let ranking: [PersonMentionRanking]
    let rawTrajectories: [Int: [Int: Int]]
    let mentioningDocs: [Int: [Int: Int]]
    let datedTotals: [Int: Int]
    let relationshipTimeline: [Int: Int]

    static func yearRange(start: Int, end: Int) -> ClosedRange<Int> {
        let lo = min(start, end)
        let hi = max(start, end)
        return lo...hi
    }

    static func yearRangeIsCustom(start: Int, end: Int, corpusMaxYear: Int) -> Bool {
        start != 1861 || end != corpusMaxYear
    }

    var yearRange: ClosedRange<Int> { Self.yearRange(start: ask.start, end: ask.end) }
    var isNormalized: Bool { ask.normalization == .percentOfDocuments }
    var byDecade: Bool { ask.byDecade }
    var selectedPeople: [PersonAnalyticsAnswer.Comparison.Person] { ask.people }
    var atComparisonCap: Bool { selectedPeople.count >= Self.maxComparisonPeople }
    var isTwoPersonComparison: Bool { selectedPeople.count == 2 }

    /// Names keyed by rollup id, for the chart series labels.
    var selectedNames: [Int: String] {
        Dictionary(uniqueKeysWithValues: selectedPeople.map { ($0.rollupId, $0.name) })
    }

    /// The chart points for the current normalization + decade toggle.
    var trajectoryPoints: [PersonTrajectoryPoint] {
        let base: [PersonTrajectoryPoint]
        if isNormalized {
            base = PersonAnalyticsMath.sharePoints(
                mentioningDocs: mentioningDocs, totals: datedTotals,
                names: selectedNames, range: yearRange)
        } else {
            base = PersonAnalyticsMath.rawPoints(
                trajectories: rawTrajectories, names: selectedNames, range: yearRange)
        }
        return byDecade ? PersonAnalyticsMath.bucketByDecade(base, isShare: isNormalized) : base
    }

    /// The per-person trajectory series exactly as the CSV exports them — plotted value included.
    func trajectorySeriesBody()
        -> [(rollupId: Int, name: String,
             points: [(period: Int, mentions: Int, mentioningDocs: Int?,
                       datedTotal: Int?, plotted: Double)])] {
        let plottedByPerson = Dictionary(grouping: trajectoryPoints, by: { $0.rollupId })
        return selectedPeople.map { person -> (rollupId: Int, name: String, points: [(period: Int, mentions: Int, mentioningDocs: Int?, datedTotal: Int?, plotted: Double)]) in
            let points = (plottedByPerson[person.rollupId] ?? []).sorted { $0.year < $1.year }.map { point in
                let years = PersonAnalyticsMath.sourceYears(
                    forPeriod: point.year, byDecade: byDecade, range: yearRange)
                let mentions = years.reduce(0) { $0 + (rawTrajectories[person.rollupId]?[$1] ?? 0) }
                // A document carries one date, so it falls in exactly one year — summing the
                // per-year distinct-document counts across a decade cannot double-count.
                let docs = years.compactMap { mentioningDocs[person.rollupId]?[$0] }
                let totals = years.compactMap { datedTotals[$0] }
                return (period: point.year,
                        mentions: mentions,
                        mentioningDocs: docs.isEmpty ? nil : docs.reduce(0, +),
                        datedTotal: totals.isEmpty ? nil : totals.reduce(0, +),
                        plotted: point.value)
            }
            return (rollupId: person.rollupId, name: person.name, points: points)
        }
    }

    /// The relationship-dynamics chart points for the current year range + decade toggle (CA-8).
    var relationshipPoints: [PersonRelationshipPoint] {
        let base = PersonRelationshipMath.points(timeline: relationshipTimeline, range: yearRange)
        return byDecade ? PersonRelationshipMath.bucketByDecade(base) : base
    }

    /// The period grain label for the trajectory/relationship charts.
    static func periodGrainLabel(byDecade: Bool) -> String {
        byDecade
            ? appWords("analytics.axis.decade", "Decade")
            : appWords("analytics.axis.year", "Year")
    }

    /// "Top people by tagged mentions in dated documents, 1940–1992. …" — the caption under Most-Mentioned People, each
    /// year written whole (`PersonAnalyticsCopy.rankingSubtitle(_:)`).
    static func rankingSubtitle(_ years: ClosedRange<Int>) -> String {
        appWords("personAnalytics.ranking.subtitle", "Top people by tagged mentions in dated documents, \(String(years.lowerBound))–\(String(years.upperBound)). Select a person to compare them below.")
    }

    /// The caveat a decade-grained **share** trajectory needs, and only that combination.
    static func decadeShareCaveat(byDecade: Bool, isNormalized: Bool) -> [String] {
        guard byDecade, isNormalized else { return [] }
        return [appWords("personAnalytics.export.caveat.decadeShare", "Decade shares: the share plotted for a decade is the average of the yearly shares for the years this person was tagged. Years with no tags are dropped from that average rather than counted as zero. The “Dated documents in period” column, by contrast, sums every year of the decade. So dividing this file’s columns gives the decade’s own share, which can be far lower than the plotted value. Someone tagged in one year of a decade plots that single year’s share for the whole decade. Use the columns for the decade’s share and the plotted value for the average across the tagged years. They answer different questions.")]
    }

    /// The methods statement for a Person Analytics export (`personProvenance`): dated documents only, the person
    /// authority's identity, and the people register among the sources.
    static func personProvenance(figureTitle: String, periodGrain: String?, valueMode: String?, extra: [String],
                                 scopeLabel: String?, indexedVolumeCount: Int, start: Int, end: Int, date: Date) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: figureTitle,
            axisLabel: periodGrain ?? appWords("personAnalytics.export.axis.ranking", "Ranked by mentions"),
            scopeLabel: scopeLabel,
            indexedVolumeCount: indexedVolumeCount,
            yearRange: start...end,
            appliesDocumentDating: false,
            valueMode: valueMode,
            extraCaveats: [
                appWords("personAnalytics.export.caveat.dated", "Population: person mentions are counted in dated documents only. The Corpus Analytics charts fall back to the volume’s start year for undated documents; these charts do not. Counts from the two views are therefore not directly comparable."),
                appWords("personAnalytics.export.caveat.identity", "Identity: mentions are grouped by the app’s person authority, so spelling variants and name forms for one individual merge into a single identity. The person id column is that grouped identity."),
            ] + extra,
            sources: [.frusText, .ohPeopleRegister],
            exportDate: date
        )
    }

    /// The scope chip's name for the scope (`AnalyticsScopeBar.currentLabel`).
    var scopeLabel: String {
        ask.scope.volumeIds == nil
            ? appWords("analytics.scope.wholeCorpus", "Whole corpus")
            : (ask.scope.label ?? appWords("analytics.scope.custom", "Selected volumes"))
    }

    // MARK: The answer

    func answer(corpusMaxYear: Int) -> PersonAnalyticsAnswer {
        let rankingHeading = appWords("personAnalytics.ranking.heading", "Most-Mentioned People")
        // Same id/suffix pairing the chart uses, so the "chart label" column matches the figure's y-axis text row for row.
        let labels = disambiguatedRankingLabels(
            ranking.map { (id: String($0.rollupId), name: $0.canonicalName, shortSuffix: String($0.rollupId)) })
        let rankingTable = AnalyticsChartTables.personRankingTable(
            title: rankingHeading,
            rows: ranking.map { (rollupId: $0.rollupId,
                                 name: $0.canonicalName,
                                 axisLabel: labels[String($0.rollupId)] ?? $0.canonicalName,
                                 mentions: $0.mentionCount) })
        let comparisonHeading = appWords("personAnalytics.comparison.heading", "Mention Trajectories")
        let points = trajectoryPoints
        let trajectoryTable = AnalyticsChartTables.personTrajectoryTable(
            title: comparisonHeading, periodColumn: Self.periodGrainLabel(byDecade: byDecade), series: trajectorySeriesBody(),
            isNormalized: isNormalized, locale: SearchItem.locale)
        var relationship: PersonAnalyticsAnswer.Relationship?
        if isTwoPersonComparison {
            let heading = appWords("personAnalytics.relationship.heading", "Relationship Dynamics")
            let a = selectedPeople[0].name
            let b = selectedPeople[1].name
            let shown = relationshipPoints
            relationship = .init(
                heading: heading,
                subtitle: appWords("personAnalytics.relationship.subtitle", "How often \(a) and \(b) are tagged together over time."),
                xAxisLabel: appWords("personAnalytics.axis.year", "Year"),
                valueAxisLabel: appWords("personAnalytics.axis.coMentions", "Shared documents"),
                points: shown.map { .init(period: $0.year, coMentions: $0.coMentions) },
                empty: shown.isEmpty
                    ? .init(title: appWords("personAnalytics.relationship.empty.title", "No Shared Documents"),
                            detail: appWords("personAnalytics.relationship.empty.detail", "These two people are never co-mentioned in a dated document within this year range."))
                    : nil,
                caption: appWords("personAnalytics.relationship.caption", "Co-occurrences in dated documents only; documents tagging mentions of both people. Undated documents cannot be placed on the year axis."),
                table: Self.table(AnalyticsChartTables.personRelationshipTable(
                    title: heading,
                    periodColumn: Self.periodGrainLabel(byDecade: byDecade),
                    personA: a,
                    personB: b,
                    points: shown.map { (period: $0.year, coMentions: $0.coMentions) })))
        }
        let maxComparisonPeople = grouped(Self.maxComparisonPeople)
        return PersonAnalyticsAnswer(
            years: .init(start: ask.start, end: ask.end,
                         isCustom: Self.yearRangeIsCustom(start: ask.start, end: ask.end, corpusMaxYear: corpusMaxYear)),
            scope: .init(label: scopeLabel, volumeIds: ask.scope.volumeIds),
            ranking: .init(
                heading: rankingHeading,
                subtitle: Self.rankingSubtitle(yearRange),
                rows: ranking.map { row in
                    .init(rollupId: row.rollupId, name: row.canonicalName,
                          axisLabel: labels[String(row.rollupId)] ?? row.canonicalName, mentions: row.mentionCount,
                          mentionsLabel: appWords("personAnalytics.axis.mentionsValue", "\(grouped(row.mentionCount)) mentions"))
                },
                empty: ranking.isEmpty
                    ? .init(title: appWords("personAnalytics.ranking.empty.title", "No People in Range"),
                            detail: appWords("personAnalytics.ranking.empty.detail", "No dated documents in this year range mention indexed people. Widen the range or index more volumes."))
                    : nil,
                table: Self.table(rankingTable)),
            comparison: .init(
                heading: comparisonHeading,
                people: selectedPeople,
                missing: ask.missing,
                atCap: atComparisonCap,
                capNote: appWords("personAnalytics.search.cap", "Comparison is limited to \(maxComparisonPeople) people. Remove one to add another."),
                prompt: appWords("personAnalytics.comparison.empty", "Add up to \(maxComparisonPeople) people — from the ranking above or the search field — to compare how often each is tagged over time."),
                isNormalized: isNormalized,
                byDecade: byDecade,
                periodLabel: Self.periodGrainLabel(byDecade: byDecade),
                xAxisLabel: appWords("personAnalytics.axis.year", "Year"),
                valueAxisLabel: isNormalized
                    ? appWords("personAnalytics.axis.share", "% of documents")
                    : appWords("personAnalytics.axis.mentions", "Mentions"),
                points: points.map { .init(rollupId: $0.rollupId, name: $0.name, period: $0.year, value: $0.value) },
                empty: !selectedPeople.isEmpty && points.isEmpty
                    ? .init(title: appWords("personAnalytics.comparison.noData.title", "No Dated Mentions"),
                            detail: appWords("personAnalytics.comparison.noData.detail", "The selected people have no mentions in dated documents within this year range."))
                    : nil,
                caption: appWords("personAnalytics.comparison.caption", "Counts tagged mentions in dated documents only; tagged mentions in undated documents cannot be placed on the year axis."),
                table: Self.table(trajectoryTable)),
            relationship: relationship)
    }

    static func table(_ data: ChartInspectorData) -> CorpusAnalyticsAnswer.Table {
        .init(title: data.title, columns: data.columns, rows: data.rows.map(\.cells))
    }
}

// MARK: - The network's rules

/// What `PersonCoMentionGraphView` and its view model say around the kit's network (`PersonCoMentionGraphView.swift`).
enum PersonNetworkView {
    /// The most characters a node's label may have, the "…" of a cut included (`labelLimit`).
    static let labelLimit = 16

    static func answer(focus: PersonAnalyticsAnswer.Comparison.Person, nodes: [PersonCoMentionNode], totalPartnerCount: Int,
                       edges: [PersonCoMentionEdge]) -> PersonNetworkAnswer {
        let focusName = focus.name
        let partners = PersonCoMentionNetwork.partners(of: nodes, focusRollupId: focus.rollupId)
        let capApplied = PersonCoMentionNetwork.capApplied(partnerCount: partners.count, totalPartnerCount: totalPartnerCount)
        let focusNode = PersonNetworkAnswer.Node(
            rollupId: focus.rollupId, name: focusName, label: GraphNodeLabels.shortLabel(focusName, limit: labelLimit),
            sharedWithFocus: 0, isFocus: true, accessibilityValue: nil, sharedLine: nil)
        let partnerNodes = partners.map { node -> PersonNetworkAnswer.Node in
            let shared = node.sharedWithFocus
            return .init(
                rollupId: node.rollupId, name: node.name, label: GraphNodeLabels.shortLabel(node.name, limit: labelLimit),
                sharedWithFocus: shared, isFocus: false,
                accessibilityValue: appWords("personCoMention.node.a11yValue", "\(grouped(node.sharedWithFocus)) shared documents with \(focusName)"),
                sharedLine: appWords("personCoMention.info.shared", "\(grouped(shared)) shared document\(shared == 1 ? "" : "s") with \(focusName)"))
        }
        return PersonNetworkAnswer(
            focus: focusNode,
            state: partners.isEmpty ? "empty" : "graph",
            empty: partners.isEmpty
                ? .init(title: appWords("personCoMention.empty.title", "No Co-Mentions"),
                        detail: appWords("personCoMention.empty.detail", "\(focusName) is not co-mentioned with any other indexed person. Index more volumes, or pick a more frequently tagged focus person."))
                : nil,
            nodes: [focusNode] + partnerNodes,
            edges: edges.map { .init(a: $0.a, b: $0.b, sharedDocuments: $0.sharedDocuments, isSpoke: $0.a == focus.rollupId || $0.b == focus.rollupId) },
            totalPartnerCount: totalPartnerCount,
            capApplied: capApplied,
            footer: capApplied
                ? PersonCoMentionNetwork.capDisclosure(partnerCount: partners.count, totalPartnerCount: totalPartnerCount)
                : appWords("personCoMention.cap.all", "Showing all \(grouped(partners.count)) co-mentioned people, sized by shared documents. Edge thickness = documents mentioning both."))
    }
}
