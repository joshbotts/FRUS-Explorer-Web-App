// /api/v1/me/history (PLAN's S17f): the research trail, the Mac's three typed tables, as its History
// screen, its Session Log and its method appendix read them.
// - A page of each table for a project's scope, newest first, with the scope's totals, as
//   `HistoryPaneSnapshot.fetch` reads them, each row drawn by the app's rules (`ReadingHistoryTitle`,
//   `ExportRow.formatDisplayName`), mirrored, and each search with its count and scope in the kit's
//   words (`RecordedSearch.RecordedCount`, `QueryMethodAppendix.Row.scopeProse`).
// - A visit and a search recorded as the browser app makes them, under Log Research Sessions, each
//   stamped with the project the user works in: a visit under its document's title, as the reader
//   titles it; a search with the Mac's capture fields, from the server's own run of it, and re-run by
//   the rule of the app's `SearchHistoryWriter`, which refreshes the row the screen last wrote.
// - A row deleted, and the whole trail, as `HistoryTrailAdmin` deletes them.
// - The Session Log, the kit's sessions over the trail's newest window (`ResearchTrailSessions`,
//   `SessionLogSnapshot`), with the summary the Research Sessions pane gives (`ResearchSessionsSummary`).
// - The method appendix, the kit's Markdown and CSV (`QueryMethodAppendix`), for the whole trail,
//   headed by the project the user works in, with the coverage of the corpora its searches ran inside,
//   as the app's `ResearchDataExporter.methodAppendix(modelContext:activeProjectId:)` makes it.

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird

/// One page of the trail for one scope (`HistoryPaneSnapshot`).
public struct HistoryPage: Codable, Equatable, Sendable, ResponseEncodable {
    /// `all`, `unfiled` or a project's id.
    public var scope: String
    /// How many rows of each table the page holds at most.
    public var limit: Int
    public var documents: [DocumentVisit]
    public var searches: [SearchRun]
    public var exports: [ExportRecord]
    /// How many of each the scope holds, beyond the page too.
    public var totalDocuments: Int
    public var totalSearches: Int
    public var totalExports: Int
    /// The scope picker's projects, by name.
    public var projects: [ProjectChoice]
    /// Log Research Sessions, which the documents' section says when it is off.
    public var loggingEnabled: Bool

    public struct ProjectChoice: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
    }
}

/// One recorded visit (`HistoryPaneSnapshot.DocumentRow`).
public struct DocumentVisit: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var volumeId: String
    public var documentId: String
    /// The title stored with it, as written.
    public var displayTitle: String?
    /// Its first line: the document's own title, else `volumeId · documentId`.
    public var title: String
    /// Its second line before the time: `volumeId · documentId` under a document's title; absent when
    /// the title is that pair.
    public var caption: String?
    public var accessedAt: String?
    public var projectId: String?
}

/// One recorded search (`HistoryPaneSnapshot.SearchRow`), with what the method appendix says of it.
public struct SearchRun: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var queryText: String
    /// The headline number the row shows.
    public var resultCount: Int
    public var executedAt: String?
    public var projectId: String?
    /// Its count as the appendix prints it (`RecordedCount.appendixDescription(locale:)`), "at least N"
    /// for a floor, and how it was made (`basisToken`).
    public var count: String
    public var countBasis: String
    /// Its scope as the appendix prints it (`QueryMethodAppendix.Row.scopeProse`), the corpus it ran
    /// inside named first.
    public var scope: String
    public var workingCorpusId: String?
}

/// One recorded export (`HistoryPaneSnapshot.ExportRow`).
public struct ExportRecord: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    /// `ExportFormat`'s raw value, or `zotero-api` for the Zotero web send.
    public var format: String
    /// The format's name (`formatDisplayName`).
    public var formatName: String
    public var documentCount: Int
    public var collectionName: String?
    /// Its first line: the collection's name, else the format's.
    public var title: String
    public var exportedAt: String?
    public var projectId: String?
}

/// What recording a visit did.
public struct RecordedVisit: Codable, Equatable, Sendable, ResponseEncodable {
    /// `inserted`, or `suppressed` while Log Research Sessions is off.
    public var outcome: String
    public var visit: DocumentVisit?
}

/// The row a search screen last wrote (`SearchHistoryWriter.Anchor`): its query, in the spelling of
/// its latest run, and its id.
public struct SearchAnchor: Codable, Equatable, Sendable {
    public var entryId: String
    public var queryText: String
}

/// What recording a search did (`SearchHistoryWriter.Outcome`).
public struct RecordedSearchRun: Codable, Equatable, Sendable, ResponseEncodable {
    /// `inserted`, `refreshed`, `suppressed` while Log Research Sessions is off, or `skipped` for a
    /// search with no words or one that failed.
    public var outcome: String
    /// The screen's anchor after it: the row inserted or refreshed, or the anchor given, unchanged.
    public var anchor: SearchAnchor?
    public var search: SearchRun?
}

/// What deleting the whole trail removed (`HistoryTrailAdmin.DeletedCounts`).
public struct DeletedTrail: Codable, Equatable, Sendable, ResponseEncodable {
    public var visits: Int
    public var searches: Int
    public var exports: Int
}

/// The Session Log (`SessionLogSnapshot`) and the Research Sessions pane's summary of it.
public struct SessionLog: Codable, Equatable, Sendable, ResponseEncodable {
    /// The sessions, newest first, each with its activities oldest first.
    public var sessions: [Session]
    public var loadedActivities: Int
    /// The trail's rows that carry a time, which the window is read from.
    public var totalActivities: Int
    public var pageLimit: Int
    public var hasMore: Bool
    public var summary: Summary

    public struct Session: Codable, Equatable, Sendable {
        public var id: String
        public var startedAt: String
        public var endedAt: String
        /// Seconds, none for a session of one activity.
        public var duration: Double
        public var activityCount: Int
        /// Whether the next activity would still join it (`isOngoing(asOf:)`).
        public var isOngoing: Bool
        public var activities: [Activity]
    }

    public struct Activity: Codable, Equatable, Sendable {
        public var id: String
        /// `documentOpen`, `search` or `export`.
        public var kind: String
        public var timestamp: String
        public var projectId: String?
        public var volumeId: String?
        public var documentId: String?
        public var displayTitle: String?
        public var query: String?
        public var resultCount: Int?
        public var format: String?
        /// The format's name, for an export.
        public var formatName: String?
        public var documentCount: Int?
        public var collectionName: String?
    }

    /// `ResearchSessionsSummary`: how many sessions the newest window holds, whether that is every
    /// one, how many rows the trail holds, and when the newest session began.
    public struct Summary: Codable, Equatable, Sendable {
        public var sessionCount: Int
        public var isSessionCountExact: Bool
        public var eventCount: Int
        public var lastSessionStart: String?
    }
}

enum HistoryRoutes {
    struct Visit: Decodable {
        let volumeId: String
        let documentId: String
    }

    struct Search: Decodable {
        /// The search, as the query string `GET /api/v1/search` reads.
        let search: String
        let anchor: SearchAnchor?
    }

    /// How many rows of each table a page holds at first, and how many Show More adds
    /// (`HistoryPaneSnapshot.defaultPageLimit`, `pageIncrement`).
    static let defaultPageLimit = 500
    static let pageIncrement = 500

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, provider: ServedIndexProvider,
                    resources: ServerResources) {
        let store = services.store
        let now = services.now

        me.get("history") { request, context -> HistoryPage in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["scope", "limit"])
            let user = try context.requireUser()
            let scope = try trailScope(try query.single("scope"))
            let limit = try query.integer("limit", in: 0...1_000_000, default: defaultPageLimit)
            let (pages, projects, corpora, logging) = try await Blocking.run {
                (try TrailTable.allCases.map { try store.trailPage($0, of: user.id, scope: scope, limit: limit) },
                 try store.projects(for: user.id), try store.researchRows(for: user.id, tables: ["working_corpora"]),
                 try store.preferences(of: user.id))
            }
            let names = try corpusNames(corpora)
            return HistoryPage(
                scope: try query.single("scope") ?? "all", limit: limit,
                documents: try pages[0].rows.map { DocumentVisit(try reading($0), resources: resources) },
                searches: try pages[1].rows.map { SearchRun(try searching($0), corpusNames: names, resources: resources) },
                exports: try pages[2].rows.map { ExportRecord(try exporting($0)) },
                totalDocuments: pages[0].total, totalSearches: pages[1].total, totalExports: pages[2].total,
                projects: projects.map { .init(id: NoteRoutes.wire($0.id), name: $0.name) },
                loggingEnabled: try logging.map { try PreferenceRoutes.read($0).researchLoggingEnabled } ?? true)
        }
        // A document the reader opened, as `DocumentViewModel.recordReadingHistory` records it after a
        // load, under its title as the reader titles it.
        me.post("history/documents") { request, context -> RecordedVisit in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Visit.self, from: request, fields: ["volumeId", "documentId"])
            guard resources.volume(body.volumeId) != nil else { throw APIProblem.volumeNotFound(body.volumeId) }
            guard body.documentId.utf8.count <= 256, FRUSURLScheme.isSafeComponent(body.documentId) else {
                throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "documentId: \(body.documentId) is not a document's id.")
            }
            guard try await PreferenceRoutes.isLogging(user.id, in: store) else { return RecordedVisit(outcome: "suppressed") }
            let title = await visitTitle(volumeId: body.volumeId, documentId: body.documentId, provider: provider)
            let project = try await Blocking.run { try store.activeProjectId(of: user.id) }.flatMap(UUID.init(uuidString:))
            let visit = ReadingHistoryEntryExport(id: UUID(), documentId: body.documentId, volumeId: body.volumeId,
                                                  displayTitle: title, projectId: project, accessedAt: UserStoreDate.rounded(now()))
            try await Blocking.run {
                try store.addResearchRow(TrailTable.reading.table, MacImport.reading(visit).values, for: user.id, outsideSearch: true)
            }
            return RecordedVisit(outcome: "inserted", visit: DocumentVisit(visit, resources: resources))
        }
        // A search the browser ran, recorded with what the server's run of it gives, as the Mac's
        // window records its executed state: its count, the rows it keeps, their ceiling, the volumes
        // indexed, its scope's signature, the corpus it ran inside and the expression it compiled to.
        me.post("history/searches") { request, context -> RecordedSearchRun in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Search.self, from: request, fields: ["search", "anchor"])
            let asked = try SearchRequest(formEncoded: body.search)
            guard try await PreferenceRoutes.isLogging(user.id, in: store) else {
                return RecordedSearchRun(outcome: "suppressed", anchor: body.anchor)
            }
            let queryText = (asked.parameters.keywords ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !queryText.isEmpty,
                  let run = try? await ranSearch(asked, queryText: queryText, for: user.id, in: store, provider: provider) else {
                return RecordedSearchRun(outcome: "skipped", anchor: body.anchor)
            }
            let project = try await Blocking.run { try store.activeProjectId(of: user.id) }.flatMap(UUID.init(uuidString:))
            var entry = SearchHistoryEntryExport(
                id: UUID(), queryText: queryText, resultCount: run.count, projectId: project,
                executedAt: UserStoreDate.rounded(now()), loadedCount: run.loaded, matchCount: run.count,
                fetchLimit: SearchRequest.retainedLimit, indexedVolumeCount: run.indexedVolumeCount,
                scopeSignature: run.signature, appliedCorpusId: run.corpus, renderedExpression: run.expression)
            let table = TrailTable.searches.table
            var outcome = "inserted"
            // A re-run of the anchored query refreshes the row it wrote, its spelling, scope, counts and
            // time this run's, unless the row has gone since, as the History screen can delete it.
            if let anchor = body.anchor, isSameQuery(anchor.queryText, queryText),
               try await Blocking.run({ try store.researchRow(table, id: anchor.entryId, of: user.id) }) != nil {
                entry.id = UUID(uuidString: anchor.entryId) ?? entry.id
                let values = MacImport.search(entry, version: ResearchDataEnvelope.currentFormatVersion).values
                    .filter { $0.key != "id" }
                _ = try await Blocking.run {
                    try store.updateResearchRow(table, id: anchor.entryId, values, for: user.id, outsideSearch: true)
                }
                outcome = "refreshed"
            } else {
                let values = MacImport.search(entry, version: ResearchDataEnvelope.currentFormatVersion).values
                try await Blocking.run { try store.addResearchRow(table, values, for: user.id, outsideSearch: true) }
            }
            let names = try corpusNames(try await Blocking.run { try store.researchRows(for: user.id, tables: ["working_corpora"]) })
            return RecordedSearchRun(outcome: outcome, anchor: SearchAnchor(entryId: entry.id.uuidString, queryText: queryText),
                                     search: SearchRun(entry, corpusNames: names, resources: resources))
        }
        for (kind, table) in [("documents", TrailTable.reading), ("searches", .searches), ("exports", .exports)] {
            // A row's Delete, which removes it at once, as a history list does.
            me.delete("history/\(kind)/:entryId") { request, context -> Response in
                try FormQuery(request.uri.query).refuseUnknown([])
                let user = try context.requireUser()
                let id = try context.parameters.require("entryId")
                guard try await Blocking.run({ try store.deleteResearchRow(table.table, id: id, for: user.id, outsideSearch: true) }) else {
                    throw APIProblem(.notFound, code: "HISTORY_ENTRY_NOT_FOUND", detail: "Your history has no entry with the id \(id).")
                }
                return Response(status: .noContent)
            }
        }
        // Delete Recorded Sessions…: every visit, search and export, and nothing else.
        me.delete("history") { request, context -> DeletedTrail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let counts = try await Blocking.run { try store.deleteTrail(of: user.id) }
            return DeletedTrail(visits: counts[.reading] ?? 0, searches: counts[.searches] ?? 0, exports: counts[.exports] ?? 0)
        }
        me.get("history/sessions") { request, context -> SessionLog in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["limit"])
            let user = try context.requireUser()
            let limit = try query.integer("limit", in: 1...1_000_000, default: SessionLogSnapshot.defaultPageLimit)
            return try await sessionLog(of: user.id, limit: limit, in: store, now: now())
        }
        me.get("history/appendix") { request, context -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["format", "timeZone"])
            let user = try context.requireUser()
            let format = try query.single("format") ?? "markdown"
            guard ["markdown", "csv"].contains(format) else {
                throw APIProblem.invalidParameter("format", "\(format) is neither markdown nor csv.")
            }
            let zone = try query.single("timeZone") ?? "UTC"
            guard let timeZone = TimeZone(identifier: zone) else {
                throw APIProblem.invalidParameter("timeZone", "\(zone) is not a time zone this server knows.")
            }
            let appendix = try await methodAppendix(of: user.id, in: store, generatedAt: now())
            let host = QueryMethodAppendix.Host(appVersion: "Light \(FRUSLightVersion.string)", resources: resources.indexing,
                                                locale: SearchItem.locale, calendar: Calendar(identifier: .gregorian),
                                                timeZone: timeZone)
            let (text, type, name) = format == "csv"
                ? (appendix.csv(for: host), "text/csv; charset=utf-8", "frus-query-log.csv")
                : (appendix.markdown(for: host), "text/markdown; charset=utf-8", "frus-query-log.md")
            var headers = ReaderRoutes.commonHeaders
            headers[.contentType] = type
            headers[.contentDisposition] = "attachment; filename=\"\(name)\""
            headers[.cacheControl] = "no-store"
            return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: text)))
        }
    }

    /// The scope a page reads: `all`, `unfiled`, or a project's id.
    static func trailScope(_ value: String?) throws -> TrailScope {
        switch value {
        case nil, "all": return .all
        case "unfiled": return .unfiled
        case let id?:
            guard let uuid = UUID(uuidString: id) else {
                throw APIProblem.invalidParameter("scope", "\(id) is neither all, unfiled nor a project's id.")
            }
            return .project(uuid.uuidString)
        }
    }

    /// The title a visit is recorded under: the reader's title of the document as the index holds it,
    /// the kit's display title of its head (`DocumentViewModel.readingHistoryTitle`), or none for a
    /// document with no head that is no editorial note, or one the index does not hold.
    static func visitTitle(volumeId: String, documentId: String, provider: ServedIndexProvider) async -> String? {
        guard let served = try? await provider.servedIfReady(),
              let entry = try? await served.pipeline.document(forDocumentId: documentId, inVolume: volumeId),
              !entry.header.isEmpty || entry.isEditorialNote else { return nil }
        return displayTitle(header: entry.header, documentNumber: entry.documentNumber, isEditorialNote: entry.isEditorialNote,
                            documentId: entry.documentId)
    }

    /// What the server's run of a search gives the row that records it.
    struct Run {
        let count: Int
        let loaded: Int
        let indexedVolumeCount: Int
        let signature: String
        let corpus: UUID?
        let expression: String?
    }

    /// The user's search `asked`, as the server runs it: its exact count with their half, the rows it
    /// keeps of it, up to the Mac's ceiling, which it fetches whole for an order of the date or
    /// Checklist Mode alone; the parameters it ran with, a corpus's documents in their gate, whose
    /// signature is the scope's (`SearchScopeSignature.signature(for:)`); and the expression it
    /// compiled to (`SearchService.matchExpressions(for:)`). A search the server refuses throws.
    static func ranSearch(_ asked: SearchRequest, queryText: String, for user: String, in store: any UserDataStore,
                          provider: ServedIndexProvider) async throws -> Run {
        let served = try await provider.served()
        let searcher = try await SearchUsers.user(user, searching: asked.parameters, in: store)
        let parameters = try await SearchUsers.inside(asked.workingCorpusId, asked.parameters, for: user, in: store, served: served)
        let count = try await SavedSearchRoutes.count(parameters, for: user, in: store, served: served, context: nil)
        let expression = try? await served.search(for: searcher).service.matchExpressions(for: parameters).corpus
        return Run(count: count, loaded: min(count, SearchRequest.retainedLimit), indexedVolumeCount: served.indexedVolumeIds.count,
                   signature: SearchScopeSignature.signature(for: parameters),
                   corpus: asked.workingCorpusId.flatMap(UUID.init(uuidString:)), expression: expression)
    }

    /// Whether `query` re-runs the query `anchored` names (`SearchHistoryWriter.isSameQuery(_:_:)`): the
    /// same text once the kit folds its typographic double quotation marks, nothing else folded.
    static func isSameQuery(_ anchored: String?, _ query: String) -> Bool {
        guard let anchored else { return false }
        return FTS5InlineQueryParser.normalizingQuotationMarks(anchored) == FTS5InlineQueryParser.normalizingQuotationMarks(query)
    }

    /// The Session Log's newest `limit` activities, read as the app's `ResearchTrailSessions.activities
    /// (in:limit:)` reads them, each table's newest `limit` rows, those with no time passed over, and
    /// grouped by the kit; and the Research Sessions pane's summary, over the window of
    /// `ResearchSessionsSummary.activityScanLimit`.
    static func sessionLog(of user: String, limit: Int, in store: any UserDataStore, now: Date) async throws -> SessionLog {
        let scan = SessionLogSnapshot.defaultPageLimit
        let (pages, scanned, dated) = try await Blocking.run {
            (try TrailTable.allCases.map { try store.trailPage($0, of: user, scope: .all, limit: limit) },
             limit == scan ? nil : try TrailTable.allCases.map { try store.trailPage($0, of: user, scope: .all, limit: scan) },
             try store.datedTrailCount(of: user))
        }
        let window = ResearchTrailSessions.newestFirst(try activities(pages), limit: limit)
        let snapshot = SessionLogSnapshot.page(of: window, datedActivityCount: dated, limit: limit)
        let summaryWindow = try scanned.map { ResearchTrailSessions.newestFirst(try activities($0), limit: scan) } ?? window
        let summarySessions = ResearchTrailSessions.group(summaryWindow)
        let total = pages.reduce(0) { $0 + $1.total }
        return SessionLog(
            sessions: snapshot.sessions.map { session in
                SessionLog.Session(id: session.id.uuidString, startedAt: UserStoreDate.text(session.startedAt),
                                   endedAt: UserStoreDate.text(session.endedAt), duration: session.duration,
                                   activityCount: session.activityCount, isOngoing: session.isOngoing(asOf: now),
                                   activities: session.activities.map(activity))
            },
            loadedActivities: snapshot.loadedActivities, totalActivities: snapshot.totalActivities, pageLimit: snapshot.pageLimit,
            hasMore: snapshot.hasMore,
            summary: .init(sessionCount: summarySessions.count, isSessionCountExact: summaryWindow.count < scan, eventCount: total,
                           lastSessionStart: summarySessions.first.map { UserStoreDate.text($0.startedAt) }))
    }

    /// The trail's pages as the kit's activities, a row with no time passed over.
    static func activities(_ pages: [TrailPage]) throws -> [ResearchTrailActivity] {
        var merged: [ResearchTrailActivity] = []
        for row in pages[0].rows {
            let visit = try reading(row)
            guard let at = visit.accessedAt else { continue }
            merged.append(ResearchTrailActivity(id: visit.id, kind: .documentOpen(volumeId: visit.volumeId, documentId: visit.documentId,
                                                                                   displayTitle: visit.displayTitle),
                                                timestamp: at, projectId: visit.projectId))
        }
        for row in pages[1].rows {
            let search = try searching(row)
            guard let at = search.executedAt else { continue }
            merged.append(ResearchTrailActivity(id: search.id, kind: .search(query: search.queryText, resultCount: search.resultCount),
                                                timestamp: at, projectId: search.projectId))
        }
        for row in pages[2].rows {
            let export = try exporting(row)
            guard let at = export.exportedAt else { continue }
            merged.append(ResearchTrailActivity(id: export.id, kind: .export(format: export.format, documentCount: export.documentCount,
                                                                              collectionName: export.collectionName),
                                                timestamp: at, projectId: export.projectId))
        }
        return merged
    }

    static func activity(_ activity: ResearchTrailActivity) -> SessionLog.Activity {
        var made = SessionLog.Activity(id: activity.id.uuidString, kind: "", timestamp: UserStoreDate.text(activity.timestamp),
                                       projectId: activity.projectId?.uuidString)
        switch activity.kind {
        case .documentOpen(let volumeId, let documentId, let displayTitle):
            made.kind = "documentOpen"
            (made.volumeId, made.documentId, made.displayTitle) = (volumeId, documentId, displayTitle)
        case .search(let query, let resultCount):
            made.kind = "search"
            (made.query, made.resultCount) = (query, resultCount)
        case .export(let format, let documentCount, let collectionName):
            made.kind = "export"
            (made.format, made.formatName, made.documentCount, made.collectionName)
                = (format, ExportFormatName.displayName(format), documentCount, collectionName)
        }
        return made
    }

    /// The method appendix of the whole trail, as `ResearchDataExporter.methodAppendix` makes it: every
    /// recorded search, the corpora's names, the project the user works in heading it, and the coverage
    /// of each corpus its searches ran inside, or every search's in Global Context.
    static func methodAppendix(of user: String, in store: any UserDataStore, generatedAt: Date) async throws -> QueryMethodAppendix {
        let tables: Set<String> = ["trail_search", "working_corpora", "projects", "trail_reading", "notes", "highlights", "collections",
                                   "collection_entries"]
        let (rows, active, logging) = try await Blocking.run {
            (try store.researchRows(for: user, tables: tables), try store.activeProjectId(of: user), try store.preferences(of: user))
        }
        do {
            let searches = try ResearchExport.records(rows, "trail_search", ResearchExport.search)
            let corpora = try ResearchExport.records(rows, "working_corpora", ResearchExport.corpus)
            let project = try active.flatMap { id in
                try ResearchExport.records(rows, "projects", ResearchExport.project).first { $0.id.uuidString == UserSearchText.uuidString(id) }
            }
            var names: [UUID: String] = [:]
            for corpus in corpora where names[corpus.id] == nil { names[corpus.id] = corpus.name }
            // The project's own searches, or every one with no project, name the corpora measured.
            let searched = Set(searches.filter { project == nil || $0.projectId == project?.id }.compactMap(\.appliedCorpusId))
            let measurable = corpora.filter { searched.contains($0.id) }
            var coverage: [QueryMethodAppendix.CorpusCoverage] = []
            if !measurable.isEmpty {
                let highlights = try ResearchExport.records(rows, "highlights", ResearchExport.highlight)
                let notes = try ResearchExport.records(rows, "notes") { try ResearchExport.note($0, links: [:]) }
                let entries = try ResearchExport.children(rows["collection_entries"], in: "collection_entries", of: "collection_id")
                let collections = try ResearchExport.records(rows, "collections") { row in
                    try ResearchExport.collection(row, entries: entries[try row.uuid("id")] ?? [])
                }
                let visits = try ResearchExport.records(rows, "trail_reading", ResearchExport.reading)
                let keys = DocumentEngagementService.gather(
                    among: ProjectHomeRoutes.engagementSources(visits: visits, notes: notes, highlights: highlights, collections: collections),
                    forProject: project?.id)
                let isOpenedComplete = try logging.map { try PreferenceRoutes.read($0).researchLoggingEnabled } ?? true
                coverage = measurable.map { corpus in
                    QueryMethodAppendix.CorpusCoverage(
                        corpusId: corpus.id, corpusName: corpus.name,
                        coverage: DocumentEngagementService.partition(corpusKeys: corpus.documentKeys, keys: keys,
                                                                      isOpenedComplete: isOpenedComplete),
                        truncation: CorpusCaptureTruncation(wasTruncated: corpus.wasTruncatedAtCapture,
                                                            totalMatchCount: corpus.totalMatchCountAtCapture),
                        isMeaningCapture: WorkingCorpusProvenance.isMeaningCapture(corpus.sourceDescription))
                }
            }
            return QueryMethodAppendix.make(recordedSearches: searches.map(recorded), corpusNames: names, projectName: project?.name,
                                            researchQuestion: project?.researchQuestion, generatedAt: generatedAt,
                                            corpusCoverage: coverage)
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The trail could not be read: \(error.description)")
        }
    }

    /// A trail row as the kit's recorded search (`SearchHistoryEntry.recordedSearch`), field for field.
    static func recorded(_ entry: SearchHistoryEntryExport) -> RecordedSearch {
        RecordedSearch(id: entry.id, queryText: entry.queryText, resultCount: entry.resultCount, projectId: entry.projectId,
                       executedAt: entry.executedAt, loadedCount: entry.loadedCount, matchCount: entry.matchCount,
                       fetchLimit: entry.fetchLimit, indexedVolumeCount: entry.indexedVolumeCount, scopeSignature: entry.scopeSignature,
                       appliedCorpusId: entry.appliedCorpusId, renderedExpression: entry.renderedExpression)
    }

    /// The user's corpora's names by id, the first of each id.
    static func corpusNames(_ rows: ResearchRows) throws -> [UUID: String] {
        var names: [UUID: String] = [:]
        for corpus in try ResearchExport.records(rows, "working_corpora", ResearchExport.corpus) where names[corpus.id] == nil {
            names[corpus.id] = corpus.name
        }
        return names
    }

    static func reading(_ row: ExportRow) throws -> ReadingHistoryEntryExport {
        try damaged { try ResearchExport.reading(ResearchExport.Fields("trail_reading", row)) }
    }

    static func searching(_ row: ExportRow) throws -> SearchHistoryEntryExport {
        try damaged { try ResearchExport.search(ResearchExport.Fields("trail_search", row)) }
    }

    static func exporting(_ row: ExportRow) throws -> ExportHistoryEntryExport {
        try damaged { try ResearchExport.exported(ResearchExport.Fields("trail_export", row)) }
    }

    static func damaged<T>(_ read: () throws -> T) throws -> T {
        do {
            return try read()
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The trail could not be read: \(error.description)")
        }
    }
}

/// What a recorded visit is called (`ReadingHistoryTitle`, #1361), mirrored: a stored title that is
/// only its volume's title in the manifest, or only the visit's own identifier pair, names no document.
enum ReadingHistoryTitle {
    /// `volumeId · documentId`, the pair a visit is always known by.
    static func identifier(volumeId: String, documentId: String) -> String { "\(volumeId) · \(documentId)" }

    /// The document's own title from a stored one: none when none was stored, or it is empty, its
    /// volume's title or the pair.
    static func documentTitle(stored: String?, volumeTitle: String?, volumeId: String, documentId: String) -> String? {
        guard let stored, !stored.isEmpty else { return nil }
        if let volumeTitle, stored == volumeTitle { return nil }
        if stored == identifier(volumeId: volumeId, documentId: documentId) { return nil }
        return stored
    }

    /// A visit's one-line label, as Project Home's Recently Read draws it: its title, else the pair.
    static func label(stored: String?, volumeTitle: String?, volumeId: String, documentId: String) -> String {
        documentTitle(stored: stored, volumeTitle: volumeTitle, volumeId: volumeId, documentId: documentId)
            ?? identifier(volumeId: volumeId, documentId: documentId)
    }
}

/// A recorded export's format by name (`HistoryPaneSnapshot.ExportRow.formatDisplayName`), mirrored:
/// `ExportFormat`'s own name for one of its raw values, the Zotero web send's, or the raw value.
enum ExportFormatName {
    /// `ExportFormat.displayName`, by raw value, in the app's words.
    static let names: [String: String] = [
        "pdf": "PDF", "html": "HTML", "docx": "DOCX", "zoteroJSON": "Zotero RIS (desktop)", "bibtex": "BibTeX",
        "fruscollection": "FRUS Collection (shareable)",
    ]

    static func displayName(_ format: String) -> String {
        format == "zotero-api" ? "Zotero (web)" : names[format] ?? format
    }
}

extension DocumentVisit {
    init(_ visit: ReadingHistoryEntryExport, resources: ServerResources) {
        id = visit.id.uuidString
        volumeId = visit.volumeId
        documentId = visit.documentId
        displayTitle = visit.displayTitle
        let own = ReadingHistoryTitle.documentTitle(stored: visit.displayTitle, volumeTitle: resources.volume(visit.volumeId)?.title,
                                                    volumeId: visit.volumeId, documentId: visit.documentId)
        title = own ?? ReadingHistoryTitle.identifier(volumeId: visit.volumeId, documentId: visit.documentId)
        caption = own == nil ? nil : ReadingHistoryTitle.identifier(volumeId: visit.volumeId, documentId: visit.documentId)
        accessedAt = visit.accessedAt.map(UserStoreDate.text)
        projectId = visit.projectId?.uuidString
    }
}

extension SearchRun {
    init(_ entry: SearchHistoryEntryExport, corpusNames: [UUID: String], resources: ServerResources) {
        id = entry.id.uuidString
        queryText = entry.queryText
        resultCount = entry.resultCount
        executedAt = entry.executedAt.map(UserStoreDate.text)
        projectId = entry.projectId?.uuidString
        let recorded = HistoryRoutes.recorded(entry)
        count = recorded.recordedCount.appendixDescription(locale: SearchItem.locale)
        countBasis = recorded.recordedCount.basisToken
        scope = QueryMethodAppendix.Row(executedAt: entry.executedAt, queryText: entry.queryText, count: recorded.recordedCount,
                                        scopeSignature: entry.scopeSignature, indexedVolumeCount: entry.indexedVolumeCount,
                                        workingCorpusName: entry.appliedCorpusId.flatMap { corpusNames[$0] },
                                        workingCorpusId: entry.appliedCorpusId)
            .scopeProse(resources: resources.indexing, locale: SearchItem.locale)
        workingCorpusId = entry.appliedCorpusId?.uuidString
    }
}

extension ExportRecord {
    init(_ entry: ExportHistoryEntryExport) {
        id = entry.id.uuidString
        format = entry.format
        formatName = ExportFormatName.displayName(entry.format)
        documentCount = entry.documentCount
        collectionName = entry.collectionName
        title = entry.collectionName?.isEmpty == false ? entry.collectionName! : formatName
        exportedAt = entry.exportedAt.map(UserStoreDate.text)
        projectId = entry.projectId?.uuidString
    }
}
