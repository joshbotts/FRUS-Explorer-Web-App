// Project Home (PLAN's S17f): a project's workspace, as the app's `ProjectHomeView` lays it out for
// the project it shows. Its activity summary and recent feeds are the app's `ProjectHomeSummary` over
// the project's notes, collections, visits and searches, mirrored; its coverage tiles are the kit's
// engagement rules (`DocumentEngagementService.gather(among:forProject:)` and `partition`) over the
// corpora the project searched inside, in the kit's words; its focus subjects are the subjects of the
// kit's vocabulary it chose, with those their editor suggests (ProjectFocus.swift, PLAN's S25c); its
// focus tags are the user's tags it chose; and Suggested Next is the leads the Mac computed, which
// Dismiss keeps from surfacing again, until phase 3's Related Documents computes them here, each with
// the line the kit reads for it from the served index (`documentSnippets(forKeys:maxLength:userSource:)`
// with its default source, the index, S25c).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// What Project Home shows of a project.
public struct ProjectHome: Codable, Equatable, Sendable, ResponseEncodable {
    public var project: Project
    /// Whether it is the project the user works in.
    public var isActive: Bool
    /// The summary's four tiles (`ProjectHomeSummary`): its collections and notes, the distinct
    /// documents visited and the searches run while it was active.
    public var counts: Counts
    /// A coverage tile for each corpus a search run under it ran inside, by the corpus's name.
    public var coverage: [Coverage]
    /// Its focus subjects (S25c): the vocabulary's subjects it chose, in the vocabulary's order. Absent
    /// on a server with no vocabulary, where the section is left out, as the Mac's is.
    public var focusSubjects: [FocusSubject]?
    /// "Suggested from your volumes", for the focus subjects' editor: the kit's suggestions over the
    /// volumes the project engages, the subjects it chose left out. Absent with `focusSubjects`.
    public var focusSuggestions: [FocusSubject]?
    /// Whether the user has any tag, which the focus tags section waits for, as the Mac's does.
    public var hasTags: Bool
    /// Its focus tags, the user's tags it chose, by name.
    public var focusTags: [FocusTag]
    /// Suggested Next: its leads the reader has not dismissed, the most related first.
    public var leads: [Lead]
    /// Where the newest computation of its leads stands (PLAN's S23d), absent when none was asked for
    /// since the server started.
    var leadsRefresh: LeadsRefresh?
    /// Recent Activity's three feeds, five each at most: the documents read, each once; the notes; and
    /// the searches.
    public var recentVisits: [RecentVisit]
    public var recentNotes: [RecentNote]
    public var recentSearches: [RecentSearch]
    /// Whether nothing is filed under it or recorded while it was active, which Recent Activity's
    /// sentence says.
    public var isEmpty: Bool

    public struct Counts: Codable, Equatable, Sendable {
        public var collections: Int
        public var notes: Int
        public var documentsVisited: Int
        public var searches: Int
    }

    /// One corpus the project searched inside, and how much of it the project has worked on
    /// (`ProjectCorpusCoverage`), in the kit's words, in US English.
    public struct Coverage: Codable, Equatable, Sendable {
        public var corpusId: String
        public var corpusName: String
        /// The tile's fraction: the corpus's documents opened, annotated or collected under the project,
        /// of all it holds.
        public var engagedCount: Int
        public var totalCount: Int
        /// The line under it (`EngagementCoverage.untouchedDescription(locale:)`).
        public var untouched: String
        /// The tile's whole sentence, which a screen reader is given (`coverageDescription(locale:)`).
        public var description: String
        /// The capture's completeness (`CorpusCaptureTruncation.line`), and whether it warns.
        public var truncationLine: String?
        public var truncationWarns: Bool
    }

    public struct FocusTag: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
    }

    /// One lead (`ProjectLeadEntry`), as its row draws it.
    public struct Lead: Codable, Equatable, Sendable {
        public var id: String
        public var volumeId: String
        public var documentId: String
        /// Its header as the Mac captured it, or its document's key for none.
        public var title: String
        /// Whether it first surfaced within the last week, the row's NEW.
        public var isNew: Bool
        /// How many of the project's documents it is related to.
        public var relatedCount: Int
        /// Whether its document is an editorial note, the user's corrections applied.
        public var isEditorialNote: Bool
        /// The line under it (S25c): its document's text in the served index, from its head on, cut at
        /// a word within 240 characters, as the kit reads it. Absent while no index is served, and for
        /// a document the index does not hold or holds no text of.
        public var snippet: String?
    }

    public struct RecentVisit: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// Its one-line label (`ReadingHistoryTitle.label(for:in:)`).
        public var title: String
    }

    public struct RecentNote: Codable, Equatable, Sendable {
        public var id: String
        public var volumeId: String
        public var documentId: String
    }

    public struct RecentSearch: Codable, Equatable, Sendable {
        public var id: String
        public var queryText: String
        public var resultCount: Int
    }
}

enum ProjectHomeRoutes {
    /// The tables Project Home reads, at one moment.
    static let tables: Set<String> = ["projects", "notes", "highlights", "collections", "collection_entries", "trail_reading",
                                      "trail_search", "project_leads", "working_corpora", "classification_overrides"]

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    provider: ServedIndexProvider, leads: ProjectLeadsQueue) {
        let store = services.store
        let now = services.now

        me.get("projects/:projectId/home") { request, context -> ProjectHome in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("projectId")
            let (rows, tags, active, preferences) = try await Blocking.run {
                (try store.researchRows(for: user.id, tables: tables), try store.tags(of: user.id),
                 try store.activeProjectId(of: user.id), try store.preferences(of: user.id))
            }
            let projects = try ResearchExport.records(rows, "projects", ResearchExport.project)
            guard let project = projects.first(where: { $0.id.uuidString == UserSearchText.uuidString(id) }) else {
                throw ProjectRoutes.notFound(id)
            }
            let logging = try preferences.map { try PreferenceRoutes.read($0).researchLoggingEnabled } ?? true
            var answer: ProjectHome
            do {
                answer = try home(project, rows: rows, tags: tags, logging: logging, now: now(),
                                  resources: resources,
                                  isActive: active.map(UserSearchText.uuidString) == project.id.uuidString)
            } catch let error as ResearchExportError {
                throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "Project Home could not be read: \(error.description)")
            }
            answer.leads = await withLines(answer.leads, provider: provider)
            answer.leadsRefresh = await leads.latestJob(project.id.uuidString, of: user.id).map(LeadsRefresh.init)
            return answer
        }
        // Suggested Next's ×: the lead stays dismissed, so it does not surface again.
        me.post("projects/:projectId/leads/:leadId/dismiss") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let projectId = try context.parameters.require("projectId")
            let leadId = try context.parameters.require("leadId")
            _ = try await ProjectRoutes.project(projectId, of: user.id, in: store)
            let table = leadsTable
            let lead = try await Blocking.run { try store.researchRow(table, id: leadId, of: user.id) }
            guard let lead, (lead.values["project_id"]?.text).map(UserSearchText.uuidString) == UserSearchText.uuidString(projectId) else {
                throw APIProblem(.notFound, code: "LEAD_NOT_FOUND", detail: "The project has no lead with the id \(leadId).")
            }
            _ = try await Blocking.run {
                try store.updateResearchRow(table, id: leadId, ["dismissed": .integer(1)], for: user.id, outsideSearch: true)
            }
            return Response(status: .noContent)
        }
    }

    static var leadsTable: UserStoreSchema.Table {
        guard let table = UserStoreSchema.table(for: "ProjectLeadEntry") else { preconditionFailure("UserStoreSchema has no project_leads") }
        return table
    }

    /// `leads` with the line under each (`ProjectHomeView.loadLeadSnippets()`): the kit's snippets of
    /// the served index for the leads shown, read at once by their keys. None while no index is
    /// served; and none when the read fails, as the app's rows then draw as they did without a line.
    /// The kit prefers the summary the index's own `summary_text` holds, which the served copy never
    /// holds, so each line is its document's text.
    static func withLines(_ leads: [ProjectHome.Lead], provider: ServedIndexProvider) async -> [ProjectHome.Lead] {
        guard !leads.isEmpty, let served = try? await provider.servedIfReady() else { return leads }
        let keys = leads.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        let lines = (try? await served.pipeline.documentSnippets(forKeys: keys)) ?? [:]
        return leads.map { lead in
            var lead = lead
            // The row draws a line only when it has one (`if let snippet = leadSnippets[lead.documentKey], !snippet.isEmpty`).
            if let line = lines[ProjectFocusRoutes.key(lead.volumeId, lead.documentId)], !line.isEmpty { lead.snippet = line }
            return lead
        }
    }

    /// Project Home for `project` over the user's `rows`, as the app's view computes it.
    static func home(_ project: ProjectExport, rows: ResearchRows, tags: [UserTagRecord],
                     logging: Bool, now: Date, resources: ServerResources, isActive: Bool) throws -> ProjectHome {
        let id = project.id
        // The instance's corrections, in the order they hold, so the last for a document is its own.
        let corrections = try ResearchExport.records(rows, "classification_overrides", byTime: "created_at",
                                                     ResearchExport.classificationCorrection)
        let highlights = try ResearchExport.records(rows, "highlights", ResearchExport.highlight)
        var links: [UUID: [UUID]] = [:]
        for highlight in highlights { if let note = highlight.noteId { links[note, default: []].append(highlight.id) } }
        let notes = try ResearchExport.records(rows, "notes") { try ResearchExport.note($0, links: links) }
        let entries = try ResearchExport.children(rows["collection_entries"], in: "collection_entries", of: "collection_id")
        let collections = try ResearchExport.records(rows, "collections") { row in
            let held = try row.uuid("id")
            return try ResearchExport.collection(
                row, entries: try ResearchExport.ordered(entries[held] ?? [], in: "collection_entries") { try $0.int("sort_order") })
        }
        let visits = try ResearchExport.records(rows, "trail_reading", ResearchExport.reading)
        let searches = try ResearchExport.records(rows, "trail_search", ResearchExport.search)
        let leads = try ResearchExport.records(rows, "project_leads", ResearchExport.lead)
        let corpora = try ResearchExport.records(rows, "working_corpora", ResearchExport.corpus)

        // The view's queries, each sorted as it sorts it, newest first, and filtered to the project.
        let summary = Summary(
            notes: newestFirst(notes.filter { $0.projectIds.contains(id) }) { $0.lastModified },
            collections: newestFirst(collections.filter { $0.projectIds.contains(id) }) { $0.lastModified },
            visits: newestFirst(visits.filter { $0.projectId == id }) { $0.accessedAt },
            searches: newestFirst(searches.filter { $0.projectId == id }) { $0.executedAt })

        // The corpora its searches ran inside, by name, each partitioned by the kit's rules against
        // the engagement gathered once, over every visit, note, highlight and collection, for the project.
        let searched = Set(summary.searches.compactMap(\.appliedCorpusId))
        let measurable = corpora.enumerated()
            .sorted { $0.element.name != $1.element.name ? $0.element.name < $1.element.name : $0.offset < $1.offset }
            .map(\.element).filter { searched.contains($0.id) }
        var coverage: [ProjectHome.Coverage] = []
        if !measurable.isEmpty {
            let keys = DocumentEngagementService.gather(among: engagementSources(visits: visits, notes: notes, highlights: highlights,
                                                                                 collections: collections),
                                                        forProject: id)
            coverage = measurable.map { corpus in
                let partition = DocumentEngagementService.partition(corpusKeys: corpus.documentKeys, keys: keys,
                                                                    isOpenedComplete: logging)
                let isMeaning = WorkingCorpusProvenance.isMeaningCapture(corpus.sourceDescription)
                let truncation = CorpusCaptureTruncation(wasTruncated: corpus.wasTruncatedAtCapture,
                                                         totalMatchCount: corpus.totalMatchCountAtCapture)
                let line = truncation.line(documentCount: partition.totalCount, isMeaningCapture: isMeaning, locale: SearchItem.locale)
                return ProjectHome.Coverage(
                    corpusId: corpus.id.uuidString, corpusName: corpus.name, engagedCount: partition.engagedCount,
                    totalCount: partition.totalCount, untouched: partition.untouchedDescription(locale: SearchItem.locale),
                    description: partition.coverageDescription(locale: SearchItem.locale),
                    // The tile draws any line in orange but a Meaning search's, as the app's tile does,
                    // where the corpus lists warn of a cut capture alone.
                    truncationLine: line, truncationWarns: line != nil && !isMeaning)
            }
        }

        // The focus subjects, where the server has their vocabulary: those the project chose, and those
        // their editor suggests, from the volumes of what is filed under the project and read in it.
        var focusSubjects: [FocusSubject]?
        var focusSuggestions: [FocusSubject]?
        if let profiles = resources.subjectProfiles.profiles {
            let engaged = ProjectFocusRoutes.engagedKeys(collections: summary.collections, notes: summary.notes, visits: summary.visits)
            focusSubjects = ProjectFocusRoutes.chosenSubjects(project.defaultSubjectTagIds, in: profiles)
            focusSuggestions = ProjectFocusRoutes.suggestedSubjects(engagedVolumeIds: ProjectFocusRoutes.engagedVolumeIds(engaged),
                                                                    excluding: project.defaultSubjectTagIds, in: profiles)
        }

        // The focus tags, in the tag list's order, which is by name.
        let chosen = Set((project.defaultUserTagIds ?? []).map(\.uuidString))
        let focusTags = tags.filter { chosen.contains(UserSearchText.uuidString($0.id)) }
            .map { ProjectHome.FocusTag(id: $0.id, name: $0.name) }

        // Suggested Next: the project's leads not dismissed, by their summed relatedness, highest first.
        let week = now.addingTimeInterval(-7 * 24 * 3600)
        let ranked = leads.enumerated()
            .filter { $0.element.projectId == id && !$0.element.dismissed }
            .sorted { $0.element.aggregateScore != $1.element.aggregateScore
                ? $0.element.aggregateScore > $1.element.aggregateScore : $0.offset < $1.offset }
            .map(\.element)
        let shownLeads = ranked.map { lead in
            ProjectHome.Lead(
                id: lead.id.uuidString, volumeId: lead.volumeId, documentId: lead.documentId,
                title: lead.header.isEmpty ? "\(lead.volumeId)/\(lead.documentId)" : lead.header,
                isNew: lead.firstSurfacedAt > week, relatedCount: lead.contributingSeedKeys.count,
                isEditorialNote: corrections.last { $0.volumeId == lead.volumeId && $0.documentId == lead.documentId }?
                    .isEditorialNote ?? lead.isEditorialNote)
        }

        return ProjectHome(
            project: Project(project), isActive: isActive,
            counts: .init(collections: summary.collections.count, notes: summary.notes.count,
                          documentsVisited: summary.documentsVisitedCount, searches: summary.searches.count),
            coverage: coverage, focusSubjects: focusSubjects, focusSuggestions: focusSuggestions,
            hasTags: !tags.isEmpty, focusTags: focusTags, leads: shownLeads,
            recentVisits: summary.recentVisits.map { visit in
                ProjectHome.RecentVisit(volumeId: visit.volumeId, documentId: visit.documentId,
                                        title: ReadingHistoryTitle.label(stored: visit.displayTitle,
                                                                         volumeTitle: resources.volume(visit.volumeId)?.title,
                                                                         volumeId: visit.volumeId, documentId: visit.documentId))
            },
            recentNotes: summary.recentNotes.map {
                ProjectHome.RecentNote(id: $0.id.uuidString, volumeId: $0.volumeId, documentId: $0.documentId)
            },
            recentSearches: summary.recentSearches.map {
                ProjectHome.RecentSearch(id: $0.id.uuidString, queryText: $0.queryText, resultCount: $0.resultCount)
            },
            isEmpty: summary.isEmpty)
    }

    /// The kit's engagement sources from the user's records, as the app's gatherer reads its models: a
    /// collection's entries by their kinds, one an older file left without a kind read as a document's.
    static func engagementSources(visits: [ReadingHistoryEntryExport], notes: [ResearchNoteExport],
                                  highlights: [DocumentHighlightExport],
                                  collections: [CollectionExport]) -> DocumentEngagementService.Sources {
        DocumentEngagementService.Sources(
            visits: visits.map { .init(volumeId: $0.volumeId, documentId: $0.documentId, projectId: $0.projectId) },
            notes: notes.map { .init(id: $0.id, volumeId: $0.volumeId, documentId: $0.documentId, projectIds: $0.projectIds) },
            highlights: highlights.map { .init(volumeId: $0.volumeId, documentId: $0.documentId, noteId: $0.noteId) },
            collections: collections.map { collection in
                .init(projectIds: collection.projectIds,
                      entries: collection.entries.map {
                          .init(kind: $0.kind ?? CollectionEntryKind.document.rawValue, volumeId: $0.volumeId, documentId: $0.documentId)
                      })
            })
    }

    /// `records` newest first by `time`, as a fetch sorted by it in reverse gives them: one with no
    /// time last, of two of one time the later written first, as the trail's pages order them.
    static func newestFirst<T>(_ records: [T], by time: (T) -> Date?) -> [T] {
        records.enumerated().sorted { a, b in
            switch (time(a.element), time(b.element)) {
            case let (x?, y?) where x != y: x > y
            case (_?, nil): true
            case (nil, _?): false
            default: a.offset > b.offset
            }
        }.map(\.element)
    }

    /// The app's `ProjectHomeSummary`, mirrored: the counts and the short recent feeds of a project's
    /// already-filtered records, each newest first.
    struct Summary {
        /// How many rows each recent feed shows (`ProjectHomeSummary.recentLimit`).
        static let recentLimit = 5

        let notes: [ResearchNoteExport]
        let collections: [CollectionExport]
        let visits: [ReadingHistoryEntryExport]
        let searches: [SearchHistoryEntryExport]

        /// Distinct documents visited, by `volumeId/documentId`.
        var documentsVisitedCount: Int { Set(visits.map { "\($0.volumeId)/\($0.documentId)" }).count }

        var isEmpty: Bool { notes.isEmpty && collections.isEmpty && visits.isEmpty && searches.isEmpty }

        var recentNotes: [ResearchNoteExport] { Array(notes.prefix(Self.recentLimit)) }

        /// The most recently visited documents, each once, so a re-read does not crowd out the rest.
        var recentVisits: [ReadingHistoryEntryExport] {
            var seen = Set<String>()
            var result: [ReadingHistoryEntryExport] = []
            for entry in visits where seen.insert("\(entry.volumeId)/\(entry.documentId)").inserted {
                result.append(entry)
                if result.count == Self.recentLimit { break }
            }
            return result
        }

        var recentSearches: [SearchHistoryEntryExport] { Array(searches.prefix(Self.recentLimit)) }
    }
}
