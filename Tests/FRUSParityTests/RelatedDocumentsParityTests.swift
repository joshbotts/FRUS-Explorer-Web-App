// Related Documents and Suggested Next (PLAN's S23d), over the kit's fixture index imported as an export.
// Every fixture document's related list through the API is the kit's `RelatedDocumentsEngine.rank` over
// the same index, with the dependencies a host has at this pin, built here apart from the server's: the
// rows, their scores, their chips' words with the shared topics named as the app's view names them, the
// count before the limit and the pool's line; and in each scope the app's picker offers, and under a
// tuning of the app's stored form. A project seeded through the API, by its notes and a focus tag, has
// the leads the kit's `ProjectLeadsAggregator` makes of the kit's rankings of its seed, as the app's
// `ProjectLeadsService` makes them, and a lead dismissed stays hidden while the next fills its place.
// And the server's and the browser app's mirrors of the app's rules and words, held to the app's source.

import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSCoreKit
@testable import FRUSLightAPI

@Suite struct RelatedDocumentsParityTests {
    static let locale = Locale(identifier: "en_US")

    /// The bundled manifest by volume id, as a host's `VolumeManifestLookup`.
    struct Manifest: VolumeManifestLookup {
        let entries: [String: VolumeManifestEntry]

        func entry(forVolumeId id: String) -> VolumeManifestEntry? { entries[id] }
    }

    /// What a host has at this pin, read here apart from the server: the fixture index's pipeline, person
    /// store and cross-reference store (FRUS-Explorer#1891, since S23c's pin move), the bundled subject
    /// index and manifest, and no lexical search or semantic axis.
    struct Host: @unchecked Sendable {
        let pipeline: IndexingPipeline
        let persons: PersonMentionStore
        let crossReferences: CrossReferenceStore
        let subjects: DocumentSubjectIndex
        let manifest: [String: VolumeManifestEntry]
        let catalogue: [VolumeManifestEntry]

        static func open() async throws -> Host {
            let built = try await FixtureIndex.value()
            let resources = ServedFixture.resources
            let subjects = try JSONDecoder().decode(DocumentSubjectIndex.self,
                                                    from: Data(contentsOf: resources.appendingPathComponent("document-subject-index.json")))
            let catalogue = try FixedVolumeCatalogue(contentsOf: resources.appendingPathComponent("manifest.json")).citableEntries
            // Opened as a host opens it, with its own copies of the two bundled files the app's store reads.
            let crossReferences = try CrossReferenceStore(
                readingDatabaseAt: built.copy, volumes: catalogue,
                resolvedEdgeIndex: try ResolvedEdgeIndex(contentsOf: resources.appendingPathComponent("resolved-edge-index.json")),
                citedPageMap: try JSONDecoder().decode(CitedPageMap.self,
                                                       from: Data(contentsOf: resources.appendingPathComponent("cited-page-map.json"))))
            return Host(pipeline: built.index.pipeline, persons: try PersonMentionStore(readingDatabaseAt: built.copy),
                        crossReferences: crossReferences, subjects: subjects,
                        manifest: Dictionary(catalogue.map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first }),
                        catalogue: catalogue)
        }

        @MainActor
        func dependencies() -> RelatedDocumentsDependencies {
            RelatedDocumentsDependencies(
                indexingPipeline: pipeline, crossReferenceStore: crossReferences, personMentionStore: persons, documentSubjectIndex: subjects,
                manifestStore: Manifest(entries: manifest), searchService: nil, indexedVolumeIds: Set(ParityFixtures.volumes),
                lexicalStopwords: [], semantic: nil)
        }

        /// The kit's ranking for `anchor`, as the app's list loads it: the year of the index's date, and
        /// the shared topics named on the rows the shared-topics axis scored.
        @MainActor
        func ranked(_ anchor: DocumentKey, weights: AxisWeights, scope: Set<String>?, limit: Int = 30) async throws -> RelatedDocumentsResult {
            let dates = try await pipeline.documentDates(for: [(volumeId: anchor.volumeId, documentId: anchor.documentId)])
            let year = dates[anchor.compositeString].flatMap { Int($0.prefix(4)) }
            let result = await RelatedDocumentsEngine.rank(anchor: anchor, anchorYear: year, weights: weights, scopeVolumeIds: scope,
                                                           limit: limit, dependencies: dependencies())
            var rows = result.rows
            let scored = rows.indices.filter { rows[$0].axisScores[.sharedSubjects] != nil }
            let names = subjects.sharedSubjectNames(anchor: anchor, candidates: scored.map { rows[$0].key })
            for index in scored {
                if let found = names[rows[index].key], !found.isEmpty {
                    rows[index].axisEvidenceLabel[.sharedSubjects] = found.joined(separator: "\u{1F}")
                }
            }
            return RelatedDocumentsResult(rows: rows, totalBeforeLimit: result.totalBeforeLimit, poolCutFrom: result.poolCutFrom)
        }

        /// The kit's leads for a seed, as `ProjectLeadsService.recompute` makes them.
        @MainActor
        func leads(seed: [String], dismissed: Set<String>) async -> [ProjectLeadCandidate] {
            var perSeed: [(seed: String, related: [(key: String, score: Double)])] = []
            for key in seed.prefix(40) {
                guard let anchor = DocumentKey(compositeString: key) else { continue }
                let result = await RelatedDocumentsEngine.rank(anchor: anchor, anchorYear: nil, weights: .default, scopeVolumeIds: nil,
                                                               limit: 30, includeSnippets: false, includeOffIndexLeads: false,
                                                               dependencies: dependencies())
                perSeed.append((seed: key, related: result.rows.map { ($0.key.compositeString, $0.totalScore) }))
            }
            return ProjectLeadsAggregator.aggregate(perSeedRelated: perSeed, seedKeys: Set(seed), dismissedKeys: dismissed, limit: 24)
        }
    }

    /// A row as the comparison reads it: its key, its score to twelve places, and its chips by axis and
    /// words. Twelve places, since a score read back from the API's JSON on Linux can differ from the
    /// kit's in its last bit; the rows' order, which the scores decide, is compared whole.
    static func row(_ row: RelatedDocumentRow) -> String {
        let chips = row.whyRelatedChips.map { "\($0.axis.rawValue)=\($0.chip.displayText(locale: locale))" }
        return "\(row.key.compositeString) \(score(row.totalScore)) [\(chips.joined(separator: "; "))] \(row.snippet ?? "-")"
    }

    static func row(_ row: RelatedDocuments.Row) -> String {
        "\(row.volumeId)/\(row.documentId) \(score(row.score)) [\(row.chips.map { "\($0.axis)=\($0.text)" }.joined(separator: "; "))] \(row.snippet ?? "-")"
    }

    static func score(_ value: Double) -> String { String(format: "%.12f", value) }

    /// Every document the fixture index holds, by volume and id.
    static func documents() async throws -> [DocumentKey] {
        let built = try await FixtureIndex.value()
        let db = try SQLiteConnection.immutable(built.copy)
        defer { db.close() }
        return try db.query("SELECT volume_id, document_id FROM document_cache ORDER BY volume_id, document_id")
            .map { DocumentKey(volumeId: $0[0].text ?? "", documentId: $0[1].text ?? "") }
    }

    /// Every fixture document's list, in all volumes at the default tuning, is the kit's ranking; a
    /// seventh of them in each scope offered and under a tuning; the axes say which this server ranks by.
    @Test func everyFixtureDocumentsRelatedListIsTheKitsRanking() async throws {
        let host = try await Host.open()
        let documents = try await Self.documents()
        #expect(documents.count > 100, "the three fixture volumes' documents")
        let tuning = "dateProximity:0.0,sharedPersons:1.0,subseries:0.9"
        let read = try await ServedFixture.run { client, _ in
            var read: [String: RelatedDocuments] = [:]
            for (index, document) in documents.enumerated() {
                let base = "/api/v1/volumes/\(document.volumeId)/documents/\(document.documentId)/related"
                read["\(document.compositeString) all"] = try ServedFixture.decode(RelatedDocuments.self, try await client.execute(uri: base, method: .get))
                guard index.isMultiple(of: 7) else { continue }
                for scope in ["volume", "subseries"] {
                    let response = try await client.execute(uri: "\(base)?scope=\(scope)", method: .get)
                    if response.status == .ok { read["\(document.compositeString) \(scope)"] = try ServedFixture.decode(RelatedDocuments.self, response) }
                }
                read["\(document.compositeString) tuned"] = try ServedFixture.decode(
                    RelatedDocuments.self, try await client.execute(uri: "\(base)?weights=\(tuning)&limit=12", method: .get))
            }
            return read
        }

        var rows = 0
        var chipsNamed = 0
        var cited = 0
        for (index, document) in documents.enumerated() {
            let all = try #require(read["\(document.compositeString) all"])
            let kit = try await host.ranked(document, weights: .default, scope: nil)
            #expect(all.rows.map(Self.row) == kit.rows.map(Self.row), "\(document.compositeString)")
            #expect(all.totalBeforeLimit == kit.totalBeforeLimit)
            #expect(all.poolCut == kit.poolCutFrom.flatMap { $0 > kit.totalBeforeLimit
                ? RelatedDocumentsCounts.poolCut(ranked: kit.totalBeforeLimit, of: $0, locale: Self.locale) : nil })
            #expect(all.scope == "all" && all.weights == "")
            rows += all.rows.count
            chipsNamed += all.rows.filter { $0.chips.contains { $0.axis == "sharedSubjects" && $0.text.hasPrefix("topics: ") } }.count
            cited += all.rows.filter { $0.chips.contains { $0.axis == "crossReference" } }.count
            guard index.isMultiple(of: 7) else { continue }
            let subseries = host.manifest[document.volumeId]?.subseries ?? ""
            let members = Set(host.catalogue.filter { !subseries.isEmpty && $0.subseries == subseries }.map(\.volumeId))
            #expect(all.scopes == (members.count > 1 ? ["volume", "subseries", "all"] : ["volume", "all"]), "\(document.compositeString)")
            let volume = try #require(read["\(document.compositeString) volume"])
            #expect(volume.rows.map(Self.row) == (try await host.ranked(document, weights: .default, scope: [document.volumeId])).rows.map(Self.row))
            if members.count > 1 {
                let sub = try #require(read["\(document.compositeString) subseries"])
                #expect(sub.rows.map(Self.row) == (try await host.ranked(document, weights: .default, scope: members)).rows.map(Self.row))
            } else {
                #expect(read["\(document.compositeString) subseries"] == nil, "no subseries scope is offered, and none is ranked")
            }
            let weights = try #require(AxisWeights(rawValue: tuning))
            let tuned = try #require(read["\(document.compositeString) tuned"])
            #expect(tuned.weights == weights.rawValue && tuned.rows.count <= 12)
            #expect(tuned.rows.map(Self.row) == (try await host.ranked(document, weights: weights, scope: nil, limit: 12)).rows.map(Self.row))
        }
        #expect(rows > 1_000, "the lists hold rows to compare: \(rows)")
        #expect(chipsNamed > 0, "a shared-topics chip names its topics")
        #expect(cited > 0, "the cross-reference axis ranks: a row cites the anchor or is cited by it, and says so")
        let axes = try #require(read.values.first?.axes)
        #expect(axes.map(\.id) == SimilarityAxis.allCases.map(\.rawValue))
        #expect(axes.filter { !$0.available }.map(\.id) == ["semanticSimilarity", "lexicalSimilarity"])
    }

    /// A project seeded through the API, by notes filed under it and a focus tag's assignment, has the
    /// kit's leads of its seed after a Refresh, each with its seeds and the record its ranking carried; a
    /// lead dismissed stays hidden after the next, and the next best fills its place.
    @Test func aSeededProjectsLeadsAreTheAggregators() async throws {
        let host = try await Host.open()
        let documents = try await Self.documents()
        let volume = try #require(ParityFixtures.volumes.first { $0 == "frus1961-63v06" })
        let ids = documents.filter { $0.volumeId == volume }.map(\.documentId)
        let (noted, tagged) = (Array(ids.prefix(3)), ids[10])
        let (first, second) = try await ServedFixture.run { client, _ in
            let session = try await CollectionExportParityTests.Session.open(client)
            let project = try await session.json(Project.self, .post, "/api/v1/me/projects", ["name": "Grain"])
            for document in noted {
                _ = try await session.send(.post, "/api/v1/me/volumes/\(volume)/documents/\(document)/notes", try CollectionExportParityTests.json(
                    ["bodyText": "", "runs": nil, "userTagIds": [String](), "projectIds": [project.id], "selectedSummaryIds": [String]()]))
            }
            let tag = try await session.json(UserTag.self, .post, "/api/v1/me/tags", ["name": "Focus"])
            _ = try await session.send(.put, "/api/v1/me/volumes/\(volume)/documents/\(tagged)/tags",
                                       try CollectionExportParityTests.json(["tagIds": [tag.id]]))
            _ = try await session.send(.patch, "/api/v1/me/projects/\(project.id)", try CollectionExportParityTests.json(["defaultUserTagIds": [tag.id]]))
            let first = try await Self.refreshed(session, project.id)
            guard let lead = first.leads.first else { return (first, first) }
            _ = try await session.send(.post, "/api/v1/me/projects/\(project.id)/leads/\(lead.id)/dismiss")
            let second = try await Self.refreshed(session, project.id)
            return (first, second)
        }
        let seed = (noted + [tagged]).map { "\(volume)/\($0)" }.sorted()
        let kit = await host.leads(seed: seed, dismissed: [])
        #expect(!kit.isEmpty, "the seed has leads to compare")
        #expect(first.leads.map { "\($0.volumeId)/\($0.documentId)" } == kit.map(\.key))
        #expect(first.leads.map(\.relatedCount) == kit.map(\.contributingSeedKeys.count))
        #expect(first.leads.allSatisfy(\.isNew) && first.leadsRefresh?.state == "succeeded")
        let lead = try #require(first.leads.first)
        let dismissed = "\(lead.volumeId)/\(lead.documentId)"
        let next = await host.leads(seed: seed, dismissed: [dismissed]).filter { $0.key != dismissed }
        #expect(second.leads.map { "\($0.volumeId)/\($0.documentId)" } == next.map(\.key), "the dismissed lead hidden, the next best in its place")
    }

    /// Project Home once the computation a Refresh queued has run to its end, and succeeded.
    static func refreshed(_ session: CollectionExportParityTests.Session, _ project: String) async throws -> ProjectHome {
        let response = try await session.send(.post, "/api/v1/me/projects/\(project)/leads/refresh", "{}")
        #expect(response.status == .accepted)
        let asked = try ServedFixture.decode(LeadsRefresh.self, response)
        for _ in 0..<600 {
            let home = try ServedFixture.decode(ProjectHome.self, try await session.get("/api/v1/me/projects/\(project)/home"))
            if let refresh = home.leadsRefresh, refresh.id == asked.id, refresh.state != "queued", refresh.state != "running" {
                #expect(refresh.state == "succeeded", "\(refresh)")
                return home
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw APIParityError("Suggested Next's computation did not end")
    }

    /// The server's mirrors of the app's request, view and service, and the browser app's, as the app's
    /// source writes them.
    @Test func theMirrorsAreTheApps() throws {
        let request = try ProjectHistoryParityTests.app("RelatedDocuments/RelatedDocumentsRequest.swift")
        NoteViewParityTests.expect(request, holds: [
            "static let defaultLimit = 30",
            "let dates = (try? await pipeline.documentDates( for: [(volumeId: anchor.volumeId, documentId: anchor.documentId)])) ?? [:]",
            "indexDate.flatMap { Int($0.prefix(4)) } ?? doorYear",
            "case .allIndexed: return nil", "case .volume(let volumeId): return [volumeId]",
            "let members = entries.filter { $0.subseries == key }.map(\\.volumeId) return members.isEmpty ? nil : Set(members)",
        ], file: "RelatedDocumentsRequest.swift")
        let view = try ProjectHistoryParityTests.app("RelatedDocuments/RelatedDocumentsView.swift")
        NoteViewParityTests.expect(view, holds: [
            "var scopes: [NeighborScope] = [.volume(anchorVolumeId)] if let key = anchorSubseriesKey, subseriesMemberCount(key) > 1 { scopes.append(.subseries(key: key, anchorVolumeId: anchorVolumeId)) } scopes.append(.allIndexed)",
            "guard let key = appState.manifestStore.entry(forVolumeId: request.anchorVolumeId)?.subseries, !key.isEmpty else { return nil }",
            "let scored = rows.indices.filter { rows[$0].axisScores[.sharedSubjects] != nil }",
            "let names = store.sharedSubjectNames(anchor: request.anchor, candidates: scored.map { rows[$0].key })",
            #"rows[index].axisEvidenceLabel[.sharedSubjects] = found.joined(separator: "\u{1F}")"#,
            "Text(row.record.header.isEmpty ? row.documentId : row.record.header)",
            "if totalBeforeLimit > rows.count {", "if let poolCutFrom, poolCutFrom > totalBeforeLimit {",
            "case .allIndexed: return String(localized: \"related.empty.detail\",",
        ], file: "RelatedDocumentsView.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/RelatedDocuments.swift"), holds: [
            "static let defaultLimit = 30",
            "let dates = (try? await served.pipeline.documentDates(for: [(volumeId: anchor.volumeId, documentId: anchor.documentId)])) ?? [:]",
            "indexDate.flatMap { Int($0.prefix(4)) } ?? doorYear",
            "let members = resources.manifest.filter { $0.subseries == key }.map(\\.volumeId) return members.isEmpty ? nil : Set(members)",
            "var scopes: [RelatedScope] = [.volume] if let key = subseriesKey(of: volumeId, resources: resources), resources.manifest.filter({ $0.subseries == key }).count > 1 { scopes.append(.subseries) } scopes.append(.all)",
            "let scored = rows.indices.filter { rows[$0].axisScores[.sharedSubjects] != nil }",
            "let names = subjects.sharedSubjectNames(anchor: anchor, candidates: scored.map { rows[$0].key })",
            #"rows[index].axisEvidenceLabel[.sharedSubjects] = found.joined(separator: "\u{1F}")"#,
            "cut > result.totalBeforeLimit ? RelatedDocumentsCounts.poolCut(",
        ], file: "RelatedDocuments.swift")
        // The leads' seed, tuning and constants: the app's service and the server's mirror.
        let service = try ProjectHistoryParityTests.app("ProjectContext/ProjectLeadsService.swift")
        NoteViewParityTests.expect(service, holds: [
            "static let seedCap = 40", "static let perSeedRelatedLimit = 30", "static let leadLimit = 24",
            "let base = stored.flatMap { AxisWeights(rawValue: $0) } ?? .default",
            "merged[axis] = base.weights[axis] ?? axis.defaultWeight",
            "where entry.kind == CollectionEntryKind.document.rawValue && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {",
            ".filter { $0.projectIds.contains(projectId) && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }",
            "guard !focusTags.isEmpty else { return [] }",
            "where focusTags.contains(assignment.tagId) && !assignment.volumeId.isEmpty && !assignment.documentId.isEmpty {",
            "where !Set(note.userTagIds).isDisjoint(with: focusTags) && !note.volumeId.isEmpty && !note.documentId.isEmpty {",
            ".union(noteSeedKeys(forProject: projectId, in: context)) .union(taggedSeedKeys(forTags: focusTags, in: context)) return (seed.sorted(), raw)",
            "for seedKey in seedKeys.prefix(seedCap) {",
            "anchor: anchor, anchorYear: nil, weights: weights, scopeVolumeIds: nil, limit: perSeedRelatedLimit, includeSnippets: false, includeOffIndexLeads: false, appState: appState)",
            "perSeedRelated: perSeed, seedKeys: seedSet, dismissedKeys: dismissedKeys, limit: leadLimit)",
            "clearVisibleLeads(forProject: projectId, in: context) return .none",
            "if !entry.dismissed { entry.aggregateScore = candidate.aggregateScore entry.contributingSeedKeys = candidate.contributingSeedKeys if let record {",
            "for entry in existing where !candidateKeys.contains(entry.documentKey) { context.delete(entry) }",
        ], file: "ProjectLeadsService.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.server("Sources/FRUSLightAPI/ProjectLeads.swift"), holds: [
            "static let seedCap = 40", "static let perSeedRelatedLimit = 30", "static let leadLimit = 24",
            "let base = stored.flatMap { AxisWeights(rawValue: $0) } ?? .default",
            "merged[axis] = base.weights[axis] ?? axis.defaultWeight",
            "guard !focusTags.isEmpty else { return [] }",
            "let ranked = Array(seed.prefix(ProjectLeadsSeed.seedCap))",
            "anchor: anchor, anchorYear: nil, weights: weights, scopeVolumeIds: nil, limit: ProjectLeadsSeed.perSeedRelatedLimit, includeSnippets: false, includeOffIndexLeads: false,",
            "ProjectLeadsAggregator.aggregate(perSeedRelated: perSeed, seedKeys: Set(seed), dismissedKeys: dismissed, limit: ProjectLeadsSeed.leadLimit)",
        ], file: "ProjectLeads.swift")
        NoteViewParityTests.expect(try ProjectHistoryParityTests.web("related/relatedRules.ts"), holds: [
            "return row.header === '' ? row.documentId : row.header;",
            "return scope === 'all' ? copy.related.emptyDetail : copy.related.emptyDetailScoped;",
            "return totalBeforeLimit > shown ? copy.related.overflow(totalBeforeLimit - shown) : undefined;",
        ], file: "relatedRules.ts")
    }

    /// The app's words the browser app takes, where the app's source writes each under its key, and in
    /// copy.ts's block.
    @Test func theAppsWordsAreTheWebs() throws {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let related = try NoteViewParityTests.block("related", of: raw)
        let home = try NoteViewParityTests.block("projectHome", of: raw)
        let view = try ProjectHistoryParityTests.app("RelatedDocuments/RelatedDocumentsView.swift")
        let row = try ProjectHistoryParityTests.app("RelatedDocuments/AxisWeightRow.swift")
        let rail = try ProjectHistoryParityTests.app("DocumentView/ResearchRailView.swift")
        let projectHome = try ProjectHistoryParityTests.app("ProjectContext/ProjectHomeView.swift")
        let words: [(source: String, file: String, key: String, value: String, block: String, web: String)] = [
            (view, "RelatedDocumentsView", "related.title", "Related Documents", related, "title: 'Related Documents'"),
            (rail, "ResearchRailView", "researchRail.tile.related", "Related", related, "tile: 'Related'"),
            (view, "RelatedDocumentsView", "related.scope.label", "Scope", related, "scope: 'Scope'"),
            (view, "RelatedDocumentsView", "related.scope.volume", "This volume", related, "volume: 'This volume'"),
            (view, "RelatedDocumentsView", "related.scope.subseries", "This subseries", related, "subseries: 'This subseries'"),
            (view, "RelatedDocumentsView", "related.scope.all", "All volumes", related, "all: 'All volumes'"),
            (view, "RelatedDocumentsView", "related.weights.label", "Adjust weights", related, "weights: 'Adjust weights'"),
            (view, "RelatedDocumentsView", "related.weights.reset", "Reset to app defaults", related, "reset: 'Reset to app defaults'"),
            (view, "RelatedDocumentsView", "related.preparingIndex", "Preparing your index…", related, "preparing: 'Preparing your index…'"),
            (view, "RelatedDocumentsView", "related.empty", "No Related Documents", related, "empty: 'No Related Documents'"),
            (view, "RelatedDocumentsView", "related.empty.detail",
             "No indexed documents share this document’s archival provenance or cross-references — indexing more volumes may surface some.", related,
             "emptyDetail: 'No indexed documents share this document’s archival provenance or cross-references — indexing more volumes may surface some.'"),
            (view, "RelatedDocumentsView", "related.empty.detail.scoped",
             "No related documents in this scope — switch to All volumes to search the whole index.", related,
             "emptyDetailScoped: 'No related documents in this scope — switch to All volumes to search the whole index.'"),
            (projectHome, "ProjectHomeView", "project.home.leads.refresh", "Refresh", home, "leadsRefresh: 'Refresh'"),
            (projectHome, "ProjectHomeView", "project.home.leads.computing", "Finding leads…", home, "leadsComputing: 'Finding leads…'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(word.block.contains(word.web), "copy.ts holds \(word.web)")
        }
        // The tile's help and the overflow line, which the app writes over several lines or with its count.
        #expect(rail.contains(#"defaultValue: "Find related documents by archival provenance, cross-references, date, and shared people")"#))
        #expect(related.contains("tileHelp: 'Find related documents by archival provenance, cross-references, date, and shared people'"))
        #expect(view.contains(#"defaultValue: "%lld more related — raise a weight or narrow the scope to refine.")"#))
        #expect(related.contains("overflow: (count: number) => `${count} more related — raise a weight or narrow the scope to refine.`"))
        // The slider's word for a missing subject index, said of the server where the app says the device.
        #expect(row.contains(#"defaultValue: "Detected-topic data is unavailable on this device.")"#))
        #expect(related.contains("subjectsUnavailable: 'Detected-topic data is unavailable on this server.'"))
    }
}
