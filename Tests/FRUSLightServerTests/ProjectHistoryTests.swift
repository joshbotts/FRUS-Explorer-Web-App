// Projects, the history, the method appendix and the synced preferences through the API (PLAN's
// S17f): a project is made, changed, merged and deleted as the app's editor and admin service do, and
// the user works in one at a time; Project Home shows what the app's view shows of one; a visit and a
// search are recorded as the app records them, the search with the Mac's capture fields from the
// server's own run of it, under Log Research Sessions; the history, its Session Log and its appendix
// are the kit's; the preferences are the Mac's synced settings; and each user's are theirs alone.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct ProjectHistoryTests {
    static let volume = UserHalfSearchTests.volume
    static let stranger = "5E17F000-0000-4000-8000-0000000000FF"
    static let utc = QueryMethodAppendix.Host(appVersion: "Light \(FRUSLightVersion.string)", resources: .none,
                                              locale: Locale(identifier: "en_US"), calendar: Calendar(identifier: .gregorian),
                                              timeZone: TimeZone(identifier: "UTC")!)

    static func entry(_ n: Int) -> String { String(format: "5E17F000-0000-4000-8000-%012d", 100 + n) }

    /// A visit's row, as the API writes one.
    static func visitRow(_ id: String, at time: String?, project: String?) -> [String: SQLiteValue] {
        ["id": .text(id), "document_id": .text("d1"), "volume_id": .text(volume), "display_title": .null,
         "project_id": project.map { .text($0) } ?? .null, "accessed_at": time.map { .text($0) } ?? .null]
    }

    static func json(_ object: [String: Any?]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object.mapValues { $0 ?? NSNull() }), as: UTF8.self)
    }

    static func made(_ browser: Browser, _ name: String, question: String? = nil) async throws -> Project {
        let response = try await browser.send(.post, "/api/v1/me/projects", try json(["name": name, "researchQuestion": question]))
        #expect(response.status == .created, "\(String(buffer: response.body))")
        return try decode(Project.self, response)
    }

    static func visit(_ browser: Browser, _ documentId: String, volume: String = volume) async throws -> RecordedVisit {
        let response = try await browser.send(.post, "/api/v1/me/history/documents", try json(["volumeId": volume, "documentId": documentId]))
        #expect(response.status == .ok, "\(String(buffer: response.body))")
        return try decode(RecordedVisit.self, response)
    }

    static func searched(_ browser: Browser, _ search: String, anchor: SearchAnchor? = nil) async throws -> RecordedSearchRun {
        var body: [String: Any?] = ["search": search]
        if let anchor { body["anchor"] = ["entryId": anchor.entryId, "queryText": anchor.queryText] }
        let response = try await browser.send(.post, "/api/v1/me/history/searches", try json(body))
        #expect(response.status == .ok, "\(String(buffer: response.body))")
        return try decode(RecordedSearchRun.self, response)
    }

    static func logging(_ browser: Browser, _ on: Bool) async throws {
        #expect(try await browser.send(.patch, "/api/v1/me/preferences", #"{"researchLoggingEnabled": \#(on)}"#).status == .ok)
    }

    /// New Project makes it and works in it, its name and question trimmed; the editor's Save and
    /// Project Home's question change what they give, the focus tags the user's own; the project picker
    /// chooses one or Global Context; Merge into… moves what is filed under it; and Delete Project
    /// leaves the activity that names it with the id, and the user in Global Context.
    @Test func projectsAreMadeChangedMergedAndDeletedAsTheAppDoes() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let grain = try await Self.made(owner, "  Grain\n", question: "  ")
            #expect(grain.name == "Grain" && grain.researchQuestion == nil)
            #expect(grain.defaultSubjectTagIds.isEmpty && grain.defaultUserTagIds.isEmpty)
            #expect(grain.createdAt == UserStoreDate.text(UserDataFixture.now) && grain.lastModified == grain.createdAt)
            #expect(try decode(ActiveProject.self, try await owner.get("/api/v1/me/active-project")).projectId == grain.id,
                    "creating a project is switching to it")
            let berlin = try await Self.made(owner, "Berlin", question: " How did the wall go up? ")
            #expect(berlin.researchQuestion == "How did the wall go up?")
            let list = try decode(ProjectList.self, try await owner.get("/api/v1/me/projects"))
            #expect(list.items.map(\.name) == ["Berlin", "Grain"] && list.activeProjectId == berlin.id)
            var listed = list.items[0]
            #expect(listed.tally == "Nothing filed yet", "the kit's tally of what is filed under it")
            listed.tally = nil
            #expect(listed == berlin, "each whole")

            // The editor's Save and Project Home's question, trimmed, none when empty.
            let asked = try decode(Project.self, try await owner.send(.patch, "/api/v1/me/projects/\(grain.id.lowercased())",
                                                                      #"{"researchQuestion": " Why wheat? "}"#))
            #expect(asked.researchQuestion == "Why wheat?" && asked.name == "Grain")
            let cleared = try decode(Project.self, try await owner.send(.patch, "/api/v1/me/projects/\(grain.id)",
                                                                        #"{"researchQuestion": "", "name": " Grain trade "}"#))
            #expect(cleared.researchQuestion == nil && cleared.name == "Grain trade")
            let empty = try await owner.send(.patch, "/api/v1/me/projects/\(grain.id)", #"{"name": "  "}"#)
            #expect(empty.status == .badRequest && problemCode(empty) == "INVALID_FIELD")
            let tag = try decode(UserTag.self, try await owner.send(.post, "/api/v1/me/tags", #"{"name": "Wheat"}"#))
            let focused = try decode(Project.self, try await owner.send(
                .patch, "/api/v1/me/projects/\(grain.id)", #"{"defaultUserTagIds": ["\#(tag.id.lowercased())", "\#(tag.id)"]}"#))
            #expect(focused.defaultUserTagIds == [tag.id], "the user's tag, once")
            let foreign = try await owner.send(.patch, "/api/v1/me/projects/\(grain.id)", #"{"defaultUserTagIds": ["\#(Self.stranger)"]}"#)
            #expect(foreign.status == .notFound && problemCode(foreign) == "TAG_NOT_FOUND")
            #expect(problemCode(try await owner.send(.patch, "/api/v1/me/projects/\(grain.id)", #"{"color": "red"}"#)) == "UNKNOWN_FIELD")

            // The project picker.
            func active(_ id: String?) async throws -> String? {
                let body = try Self.json(["projectId": id])
                let response = try await owner.send(.put, "/api/v1/me/active-project", body)
                #expect(response.status == .ok, "\(String(buffer: response.body))")
                return try decode(ActiveProject.self, response).projectId
            }
            #expect(try await active(grain.id.lowercased()) == grain.id)
            #expect(try await active(nil) == nil, "Global Context")
            let missing = try await owner.send(.put, "/api/v1/me/active-project", #"{"projectId": "\#(Self.stranger)"}"#)
            #expect(missing.status == .notFound && problemCode(missing) == "PROJECT_NOT_FOUND")

            // Merge into…: a note filed under Berlin is Grain's after, and the user follows the merge.
            #expect(try await active(berlin.id) == berlin.id)
            var note = NoteJSON(bodyText: "Under Berlin")
            note.projectIds = [berlin.id]
            let filed = try decode(Note.self, try await owner.send(.post, "\(UserHalfSearchTests.d1)/notes", note.json))
            let merged = try decode(Project.self, try await owner.send(.post, "/api/v1/me/projects/\(berlin.id)/merge",
                                                                       #"{"into": "\#(grain.id)"}"#))
            #expect(merged.id == grain.id)
            let left = try decode(ProjectList.self, try await owner.get("/api/v1/me/projects"))
            #expect(left.items.map(\.name) == ["Grain trade"] && left.items.first?.tally == "1 note", "the merged note counted")
            #expect(try decode(ActiveProject.self, try await owner.get("/api/v1/me/active-project")).projectId == grain.id)
            #expect(try decode(Note.self, try await owner.get(NoteTests.note(filed.id))).projectIds == [grain.id])
            let itself = try await owner.send(.post, "/api/v1/me/projects/\(grain.id)/merge", #"{"into": "\#(grain.id)"}"#)
            #expect(itself.status == .badRequest && problemCode(itself) == "INVALID_FIELD")
            #expect(problemCode(try await owner.send(.post, "/api/v1/me/projects/\(berlin.id)/merge", #"{"into": "\#(grain.id)"}"#))
                    == "PROJECT_NOT_FOUND")

            // Delete Project: the note keeps the id, and the user works in Global Context.
            #expect(try await owner.send(.delete, "/api/v1/me/projects/\(grain.id)").status == .noContent)
            #expect(try decode(ActiveProject.self, try await owner.get("/api/v1/me/active-project")).projectId == nil)
            #expect(try decode(Note.self, try await owner.get(NoteTests.note(filed.id))).projectIds == [grain.id],
                    "activity records are kept, unlinked from the project")
            #expect(problemCode(try await owner.get("/api/v1/me/projects/\(grain.id)")) == "PROJECT_NOT_FOUND")
            #expect(problemCode(try await owner.send(.delete, "/api/v1/me/projects/\(grain.id)")) == "PROJECT_NOT_FOUND")
            let unnamed = try await owner.send(.post, "/api/v1/me/projects", #"{"name": "\n"}"#)
            #expect(unnamed.status == .badRequest && problemCode(unnamed) == "INVALID_FIELD")
        }
    }

    /// A visit is recorded under the reader's title of its document, a search with what the server's
    /// run of it gives and the scope's signature the kit writes, each stamped with the project the user
    /// works in; a re-run of the anchored query, in either spelling of its quotation marks, refreshes
    /// its row, and another query adds one; a search with no words is skipped, and with Log Research
    /// Sessions off nothing is recorded.
    /// A visit to a document the index does not hold, as front matter is, or to any while no index is
    /// served, takes the title the reader gives it from its TEI, as the app's records the head it parsed.
    @Test func aVisitTheIndexCannotTitleTakesTheReadersTitleFromItsTEI() async throws {
        for indexed in [true, false] {
            let fixture = try await UserDataFixture(volumes: [Self.volume], indexed: indexed)
            defer { withExtendedLifetime(fixture) {} }
            try await fixture.app.test(.router) { client in
                let owner = Browser(client: client)
                for documentId in ["preface", "d3", "d1"] {
                    let detail = try decode(DocumentDetail.self,
                                            try await owner.get("/api/v1/volumes/\(Self.volume)/documents/\(documentId)"))
                    let visit = try #require(try await Self.visit(owner, documentId).visit)
                    #expect(visit.title == detail.document.displayTitle && visit.displayTitle == detail.document.displayTitle,
                            "\(documentId), indexed \(indexed): the reader's title")
                }
            }
        }
    }

    @Test func aVisitAndASearchAreRecordedAsTheAppRecordsThem() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let grain = try await Self.made(owner, "Grain")
            let detail = try decode(DocumentDetail.self, try await owner.get("/api/v1/volumes/\(Self.volume)/documents/d1"))
            let recorded = try await Self.visit(owner, "d1")
            let visit = try #require(recorded.visit)
            #expect(recorded.outcome == "inserted")
            #expect(visit.displayTitle == detail.document.displayTitle && visit.title == detail.document.displayTitle,
                    "the reader's title")
            #expect(visit.caption == "\(Self.volume) · d1" && visit.projectId == grain.id)
            #expect(visit.accessedAt == UserStoreDate.text(UserDataFixture.now))
            let unknown = try await owner.send(.post, "/api/v1/me/history/documents", #"{"volumeId": "frus9999", "documentId": "d1"}"#)
            #expect(unknown.status == .notFound && problemCode(unknown) == "VOLUME_NOT_FOUND")

            // A search's row: the Mac's capture fields, as the server ran it.
            let query = "keywords=treaties&volumeIds=\(Self.volume)"
            let first = try await Self.searched(owner, query)
            #expect(first.outcome == "inserted")
            let anchor = try #require(first.anchor)
            #expect(anchor.queryText == "treaties")
            let row = try #require(try fixture.store.researchRow(TrailTable.searches.table, id: anchor.entryId, of: "owner"))
            let parameters = try SearchRequest(formEncoded: query).parameters
            #expect(row.values["result_count"] == .integer(2) && row.values["match_count"] == .integer(2))
            #expect(row.values["loaded_count"] == .integer(2) && row.values["fetch_limit"] == .integer(7_500))
            #expect(row.values["indexed_volume_count"] == .integer(2))
            #expect(row.values["scope_signature"] == .text(SearchScopeSignature.signature(for: parameters)))
            let inspected = try decode(SearchInspection.self, try await owner.get("/api/v1/search/inspect?\(query)"))
            #expect(row.values["rendered_expression"] == inspected.search.corpus.map { .text($0) }, "the expression it compiled to")
            #expect(row.values["project_id"] == .text(grain.id) && row.values["applied_corpus_id"] == .null)
            #expect(first.search?.count == "2" && first.search?.countBasis == "exact")

            // Run again in curly marks with the anchor: the same row, in the later spelling.
            let phrase = try await Self.searched(owner, "keywords=%22negotiating%20treaties%22")
            let curly = try await Self.searched(owner, "keywords=%E2%80%9Cnegotiating%20treaties%E2%80%9D", anchor: phrase.anchor)
            #expect(curly.outcome == "refreshed" && curly.anchor?.entryId == phrase.anchor?.entryId)
            #expect(curly.anchor?.queryText == "\u{201C}negotiating treaties\u{201D}")
            let other = try await Self.searched(owner, "keywords=canal", anchor: curly.anchor)
            #expect(other.outcome == "inserted" && other.anchor?.entryId != curly.anchor?.entryId)
            #expect(try await Self.searched(owner, "volumeIds=\(Self.volume)").outcome == "skipped", "no words")
            let gone = try await Self.searched(owner, "keywords=canal", anchor: SearchAnchor(entryId: Self.stranger, queryText: "canal"))
            #expect(gone.outcome == "inserted", "an anchor whose row has gone adds one")

            // A search inside a working corpus records the corpus and names it in its scope.
            let corpus = try await SearchSetTests.corpus(owner, "Treaties", "keywords=treaties")
            let inside = try await Self.searched(owner, "keywords=ambassador&workingCorpusId=\(corpus.id)")
            #expect(inside.search?.workingCorpusId == corpus.id)
            #expect(inside.search?.scope.hasPrefix("inside \u{201C}Treaties\u{201D}") == true, "\(inside.search?.scope ?? "")")

            let page = try decode(HistoryPage.self, try await owner.get("/api/v1/me/history"))
            #expect(page.documents.map(\.id) == [visit.id] && page.totalDocuments == 1)
            #expect(page.searches.map(\.queryText) == ["ambassador", "canal", "canal", "\u{201C}negotiating treaties\u{201D}", "treaties"],
                    "newest first, the refreshed row at its run's time")
            #expect(page.totalSearches == 5 && page.exports.isEmpty && page.loggingEnabled)
            #expect(page.projects.map(\.name) == ["Grain"])
            #expect(try decode(HistoryPage.self, try await owner.get("/api/v1/me/history?scope=unfiled")).totalSearches == 0)
            #expect(try decode(HistoryPage.self, try await owner.get("/api/v1/me/history?scope=\(grain.id.lowercased())")).totalSearches == 5)
            let limited = try decode(HistoryPage.self, try await owner.get("/api/v1/me/history?limit=2"))
            #expect(limited.searches.count == 2 && limited.totalSearches == 5, "the page is cut, its total is not")
            #expect(problemCode(try await owner.get("/api/v1/me/history?scope=somewhere")) == "INVALID_PARAMETER")

            // Log Research Sessions off: nothing is recorded, and the page says so.
            try await Self.logging(owner, false)
            #expect(try await Self.visit(owner, "d2").outcome == "suppressed")
            #expect(try await Self.searched(owner, "keywords=minister").outcome == "suppressed")
            let off = try decode(HistoryPage.self, try await owner.get("/api/v1/me/history"))
            #expect(!off.loggingEnabled && off.totalDocuments == 1 && off.totalSearches == 5)
            try await Self.logging(owner, true)

            // A row's Delete, and Delete Recorded Sessions….
            #expect(try await owner.send(.delete, "/api/v1/me/history/searches/\(anchor.entryId.lowercased())").status == .noContent)
            let again = try await owner.send(.delete, "/api/v1/me/history/searches/\(anchor.entryId)")
            #expect(again.status == .notFound && problemCode(again) == "HISTORY_ENTRY_NOT_FOUND")
            #expect(problemCode(try await owner.send(.delete, "/api/v1/me/history/documents/\(anchor.entryId)")) == "HISTORY_ENTRY_NOT_FOUND",
                    "each table's own")
            let deleted = try decode(DeletedTrail.self, try await owner.send(.delete, "/api/v1/me/history"))
            #expect(deleted == DeletedTrail(visits: 1, searches: 4, exports: 0))
            #expect(try decode(HistoryPage.self, try await owner.get("/api/v1/me/history")).totalSearches == 0)
            #expect(try decode(ProjectList.self, try await owner.get("/api/v1/me/projects")).total == 1, "nothing else goes")
        }
    }

    /// The Session Log is the kit's sessions over the trail's newest window, split by a gap of 30
    /// minutes, the newest ongoing while the next activity would join it; a row with no time has no
    /// place in one but counts among the pane's events.
    @Test func theSessionLogIsTheKitsSessionsOverTheTrail() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        let now = UserDataFixture.now
        let at: @Sendable (Double) -> String = { UserStoreDate.text(now.addingTimeInterval($0 * 60)) }
        let reading = TrailTable.reading.table
        let searching = TrailTable.searches.table
        for (n, minutes) in [(1, -200.0), (2, -190.0), (3, -20.0)] {
            try fixture.store.addResearchRow(reading, Self.visitRow(Self.entry(n), at: at(minutes), project: nil),
                                             for: "owner", outsideSearch: true)
        }
        try fixture.store.addResearchRow(reading, Self.visitRow(Self.entry(4), at: nil, project: nil), for: "owner",
                                         outsideSearch: true)
        try fixture.store.addResearchRow(searching, ["id": .text(Self.entry(5)), "query_text": .text("wheat"),
                                                     "result_count": .integer(7), "executed_at": .text(at(-10))],
                                         for: "owner", outsideSearch: true)
        try fixture.store.addResearchRow(TrailTable.exports.table,
                                         ["id": .text(Self.entry(6)), "format": .text("zotero-api"), "document_count": .integer(3),
                                          "collection_name": .text("Grain"), "exported_at": .text(at(-175))],
                                         for: "owner", outsideSearch: true)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let log = try decode(SessionLog.self, try await owner.get("/api/v1/me/history/sessions"))
            #expect(log.sessions.map(\.activityCount) == [2, 3], "newest first: 20 and 10 minutes ago, then 200, 190 and 175")
            #expect(log.sessions.map(\.isOngoing) == [true, false])
            #expect(log.sessions[0].activities.map(\.kind) == ["documentOpen", "search"], "oldest first within one")
            #expect(log.sessions[1].activities.last?.formatName == "Zotero (web)")
            #expect(log.sessions[1].duration == 25 * 60 && log.sessions[1].startedAt == at(-200) && log.sessions[1].endedAt == at(-175))
            #expect(log.loadedActivities == 5 && log.totalActivities == 5 && !log.hasMore)
            #expect(log.summary == SessionLog.Summary(sessionCount: 2, isSessionCountExact: true, eventCount: 6,
                                                      lastSessionStart: at(-20)), "the undated row among the events")
            let cut = try decode(SessionLog.self, try await owner.get("/api/v1/me/history/sessions?limit=2"))
            #expect(cut.loadedActivities == 2 && cut.hasMore && cut.sessions.map(\.activityCount) == [2])
            #expect(cut.summary == log.summary, "the pane's summary is over its own window")
        }
    }

    /// The done-when's appendix: the kit's Markdown and CSV for the recorded trail, headed by the
    /// project the user works in, with the coverage of the corpus its searches ran inside, held to what
    /// the kit writes from the store's rows; dates in the time zone the browser names.
    @Test func theMethodAppendixIsTheKitsForTheRecordedTrail() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let grain = try await Self.made(owner, "Grain", question: "How were treaties negotiated?")
            let corpus = try await SearchSetTests.corpus(owner, "Treaties", "keywords=treaties")
            _ = try await Self.searched(owner, "keywords=treaties")
            _ = try await Self.searched(owner, "keywords=zanzibar")
            _ = try await Self.searched(owner, "keywords=ambassador&workingCorpusId=\(corpus.id)")
            _ = try await Self.visit(owner, "d1")
            // A row a build before M-2 wrote, as an import brings it: no time and no capture.
            try fixture.store.addResearchRow(TrailTable.searches.table,
                                             ["id": .text(Self.entry(1)), "query_text": .text("Kennan"), "result_count": .integer(41)],
                                             for: "owner", outsideSearch: true)

            // What the kit writes for the rows the store holds.
            let rows = try fixture.store.researchRows(TrailTable.searches.table, of: "owner")
            let searches = try rows.map { HistoryRoutes.recorded(try ResearchExport.search(ResearchExport.Fields("trail_search", $0))) }
            let corpusId = try #require(UUID(uuidString: corpus.id))
            let corpora = try #require(UserStoreSchema.table(for: "WorkingCorpus"))
            let corpusRow = try #require(try fixture.store.researchRow(corpora, id: corpus.id, of: "owner"))
            let held = try ResearchExport.corpus(ResearchExport.Fields("working_corpora", corpusRow))
            let keys = DocumentEngagementService.GatheredKeys(opened: ["\(Self.volume)/d1"], annotated: [], collected: [])
            let coverage = QueryMethodAppendix.CorpusCoverage(
                corpusId: corpusId, corpusName: "Treaties",
                coverage: DocumentEngagementService.partition(corpusKeys: held.documentKeys, keys: keys, isOpenedComplete: true),
                truncation: CorpusCaptureTruncation(wasTruncated: held.wasTruncatedAtCapture, totalMatchCount: held.totalMatchCountAtCapture))
            #expect(held.documentKeys == ["\(Self.volume)/d1", "\(Self.volume)/d2"])
            let expected = QueryMethodAppendix.make(recordedSearches: searches, corpusNames: [corpusId: "Treaties"], projectName: "Grain",
                                                    researchQuestion: "How were treaties negotiated?", generatedAt: UserDataFixture.now,
                                                    corpusCoverage: [coverage])
            #expect(expected.rows.count == 4 && expected.unrecordedRowCount == 1 && expected.keywordZeroResultRowCount == 1)
            #expect(expected.applicableCoverage.count == 1 && grain.name == "Grain")

            let markdown = try await owner.get("/api/v1/me/history/appendix?format=markdown&timeZone=UTC")
            #expect(markdown.status == .ok && markdown.headers[.contentType] == "text/markdown; charset=utf-8")
            #expect(markdown.headers[.contentDisposition] == #"attachment; filename="frus-query-log.md""#)
            #expect(String(buffer: markdown.body) == expected.markdown(for: Self.utc))
            let csv = try await owner.get("/api/v1/me/history/appendix?format=csv")
            #expect(csv.headers[.contentDisposition] == #"attachment; filename="frus-query-log.csv""#)
            #expect(String(buffer: csv.body) == expected.csv(for: Self.utc), "UTC unless the browser names another")
            let berlin = TimeZone(identifier: "Europe/Berlin")!
            var there = Self.utc
            there.timeZone = berlin
            #expect(String(buffer: try await owner.get("/api/v1/me/history/appendix?timeZone=Europe/Berlin").body)
                    == expected.markdown(for: there))
            #expect(problemCode(try await owner.get("/api/v1/me/history/appendix?format=pdf")) == "INVALID_PARAMETER")
            #expect(problemCode(try await owner.get("/api/v1/me/history/appendix?timeZone=Mars/Olympus")) == "INVALID_PARAMETER")

            // In Global Context it names no project, and measures the corpus by every search.
            #expect(try await owner.send(.put, "/api/v1/me/active-project", #"{"projectId": null}"#).status == .ok)
            let global = String(buffer: try await owner.get("/api/v1/me/history/appendix?format=markdown").body)
            #expect(!global.contains("**Project:**") && global.contains("Coverage counts what has been done on this device"))
        }
    }

    /// Project Home: the summary's tiles and Recent Activity over what is filed under the project and
    /// recorded while it was active, a coverage tile for the corpus its searches ran inside in the
    /// kit's words, its focus tags, and Suggested Next, the Mac's leads not dismissed, the most related
    /// first, NEW for a week, the editorial flag the user's corrections give, until Dismiss.
    @Test func projectHomeShowsWhatTheAppsViewShows() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let grain = try await Self.made(owner, "Grain")
            let tag = try decode(UserTag.self, try await owner.send(.post, "/api/v1/me/tags", #"{"name": "Wheat"}"#))
            _ = try await owner.send(.patch, "/api/v1/me/projects/\(grain.id)", #"{"defaultUserTagIds": ["\#(tag.id)"]}"#)
            let corpus = try await SearchSetTests.corpus(owner, "Treaties", "keywords=treaties")
            for document in ["d1", "d2", "d1"] { _ = try await Self.visit(owner, document) }
            _ = try await Self.searched(owner, "keywords=ambassador&workingCorpusId=\(corpus.id)")
            var note = NoteJSON(bodyText: "Filed under Grain")
            note.projectIds = [grain.id]
            let filed = try decode(Note.self, try await owner.send(.post, "\(UserHalfSearchTests.d2)/notes", note.json))
            _ = try await owner.send(.post, "\(UserHalfSearchTests.d1)/notes", NoteJSON(bodyText: "Unfiled").json)
            // The Mac's leads, as an import brings them: one dismissed, one old, one a correction makes a note.
            let day = 24 * 3600.0
            for (n, score, surfaced, dismissed, document) in [(1, 0.5, -30 * day, false, "d1"), (2, 2.5, -1 * day, false, "d2"),
                                                               (3, 9.0, -1 * day, true, "d1")] {
                try fixture.rows.run(
                    """
                    INSERT INTO project_leads (user_id, id, project_id, volume_id, document_id, aggregate_score, contributing_seed_keys,
                                               header, is_editorial_note, first_surfaced_at, last_computed_at, dismissed)
                        VALUES ('owner', ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
                    """, [.text(Self.entry(n)), .text(grain.id), .text(Self.volume), .text(document), .real(score),
                          .text(TagReferences.encode(["a/1", "b/2"].prefix(n).map { $0 })), .text(n == 1 ? "" : "Lead \(n)"),
                          .text(UserStoreDate.text(UserDataFixture.now.addingTimeInterval(surfaced))),
                          .text(UserStoreDate.text(UserDataFixture.now)), .integer(dismissed ? 1 : 0)])
            }
            try fixture.store.record(ClassificationOverride(volumeId: Self.volume, documentId: "d2", isEditorialNote: true,
                                                            parsedIsEditorialNote: false, createdAt: UserDataFixture.now))

            let home = try decode(ProjectHome.self, try await owner.get("/api/v1/me/projects/\(grain.id)/home"))
            let whole = try decode(Project.self, try await owner.get("/api/v1/me/projects/\(grain.id)"))
            #expect(home.isActive && home.project == whole)
            #expect(home.counts == .init(collections: 0, notes: 1, documentsVisited: 2, searches: 1))
            #expect(home.recentVisits.map(\.documentId) == ["d1", "d2"], "each document once, the latest visit first")
            #expect(home.recentNotes.map(\.id) == [filed.id] && home.recentSearches.map(\.queryText) == ["ambassador"])
            #expect(!home.isEmpty && home.hasTags && home.focusTags == [.init(id: tag.id, name: "Wheat")])
            let tile = try #require(home.coverage.first)
            let partition = DocumentEngagementService.partition(
                corpusKeys: ["\(Self.volume)/d1", "\(Self.volume)/d2"],
                keys: .init(opened: ["\(Self.volume)/d1", "\(Self.volume)/d2"], annotated: ["\(Self.volume)/d2"], collected: []),
                isOpenedComplete: true)
            #expect(home.coverage.count == 1 && tile.corpusName == "Treaties" && tile.engagedCount == 2 && tile.totalCount == 2)
            #expect(tile.untouched == partition.untouchedDescription(locale: SearchItem.locale))
            #expect(tile.description == partition.coverageDescription(locale: SearchItem.locale) && tile.truncationLine == nil)
            // A corpus from an older Mac, which never recorded its capture's completeness: the kit's line,
            // drawn orange, as the app's tile draws every line but a Meaning search's.
            try fixture.rows.run("UPDATE working_corpora SET was_truncated_at_capture = NULL WHERE user_id = 'owner' AND upper(id) = upper(?)",
                                 [.text(corpus.id)])
            let unrecorded = try #require(try decode(ProjectHome.self, try await owner.get("/api/v1/me/projects/\(grain.id)/home")).coverage.first)
            let unrecordedLine = CorpusCaptureTruncation(wasTruncated: nil, totalMatchCount: nil)
                .line(documentCount: 2, isMeaningCapture: false, locale: SearchItem.locale)
            #expect(unrecorded.truncationLine == unrecordedLine && unrecordedLine != nil && unrecorded.truncationWarns)
            #expect(home.leads.map(\.id) == [Self.entry(2), Self.entry(1)], "the dismissed gone, the most related first")
            #expect(home.leads.map(\.isNew) == [true, false] && home.leads.map(\.relatedCount) == [2, 1])
            #expect(home.leads.map(\.isEditorialNote) == [true, false], "the correction wins over the lead's snapshot")
            #expect(home.leads[1].title == "\(Self.volume)/d1", "no header: its key")

            #expect(try await owner.send(.post, "/api/v1/me/projects/\(grain.id)/leads/\(Self.entry(2))/dismiss").status == .noContent)
            let after = try decode(ProjectHome.self, try await owner.get("/api/v1/me/projects/\(grain.id)/home"))
            #expect(after.leads.map(\.id) == [Self.entry(1)])
            let elsewhere = try await Self.made(owner, "Elsewhere")
            #expect(problemCode(try await owner.send(.post, "/api/v1/me/projects/\(elsewhere.id)/leads/\(Self.entry(1))/dismiss"))
                    == "LEAD_NOT_FOUND", "another project's lead")
            let quiet = try decode(ProjectHome.self, try await owner.get("/api/v1/me/projects/\(elsewhere.id)/home"))
            #expect(quiet.isEmpty && quiet.coverage.isEmpty && quiet.leads.isEmpty && quiet.recentVisits.isEmpty)
            let left = try decode(ProjectHome.self, try await owner.get("/api/v1/me/projects/\(grain.id)/home"))
            #expect(quiet.isActive && !left.isActive, "the project made last is the one worked in")
            #expect(problemCode(try await owner.get("/api/v1/me/projects/\(Self.stranger)/home")) == "PROJECT_NOT_FOUND")
        }
    }

    /// The synced preferences: the app's initial values until something sets them; each field set as
    /// the Mac's settings set it, a list's order replacing that list's alone, written as the Mac
    /// writes `listOrderJSON`; what is not one of the app's values refused.
    @Test func preferencesAreTheMacsSyncedSettings() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let initial = try decode(Preferences.self, try await owner.get("/api/v1/me/preferences"))
            #expect(initial.citationStyle == "" && initial.defaultDocumentMode == "" && initial.researchLoggingEnabled)
            #expect(initial.tagOrder.isEmpty && initial.projectOrder.isEmpty && initial.createdAt == nil)
            #expect(initial.wordCloud == .init(minLength: 3, minCount: 1, foldPlurals: true, filterMarkings: true, excludeBoilerplate: true,
                                               globalStopwords: [], lensStopwordsJSON: ""))

            let (a, b, p) = ("5E17F000-0000-4000-8000-0000000000A1", "5E17F000-0000-4000-8000-0000000000A2",
                             "5E17F000-0000-4000-8000-0000000000B1")
            let styled = try decode(Preferences.self, try await owner.send(
                .patch, "/api/v1/me/preferences", #"{"citationStyle": "chicago", "defaultDocumentMode": "research", "tagOrder": ["\#(b.lowercased())", "\#(a)", "\#(b)"]}"#))
            #expect(styled.citationStyle == "chicago" && styled.defaultDocumentMode == "research" && styled.tagOrder == [b, a])
            #expect(styled.createdAt == UserStoreDate.text(UserDataFixture.now))
            let ordered = try decode(Preferences.self, try await owner.send(.patch, "/api/v1/me/preferences", #"{"projectOrder": ["\#(p)"]}"#))
            #expect(ordered.tagOrder == [b, a] && ordered.projectOrder == [p], "one list replaced, the other kept")
            #expect(try fixture.rows.column("SELECT list_order_json FROM preferences") == [#"{"tags":["\#(b)","\#(a)"],"projects":["\#(p)"]}"#])

            for (body, code) in [(#"{"citationStyle": "mla"}"#, "INVALID_FIELD"), (#"{"defaultDocumentMode": "split"}"#, "INVALID_FIELD"),
                                 (#"{"tagOrder": ["not an id"]}"#, "INVALID_FIELD"), (#"{"appearance": "dark"}"#, "UNKNOWN_FIELD")] {
                let refused = try await owner.send(.patch, "/api/v1/me/preferences", body)
                #expect(refused.status == .badRequest && problemCode(refused) == code, "\(body)")
            }
            // A Mac's order that does not read as both lists is no custom order, as the app reads it.
            try fixture.rows.run(#"UPDATE preferences SET list_order_json = '{"tags":[]}'"#)
            let unread = try decode(Preferences.self, try await owner.get("/api/v1/me/preferences"))
            #expect(unread.tagOrder.isEmpty && unread.projectOrder.isEmpty && unread.citationStyle == "chicago")
            let reset = try decode(Preferences.self, try await owner.send(.patch, "/api/v1/me/preferences", #"{"citationStyle": ""}"#))
            #expect(reset.citationStyle == "", "unset again")
        }
    }

    /// Two users, signed in through the proxy: neither reaches the other's projects, the project they
    /// work in, their trail, its appendix or their preferences, by list or by id.
    @Test func twoUsersProjectsHistoryAndPreferencesStayApart() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let grain = try await Self.made(alice, "Grain")
            let visit = try #require(try await Self.visit(alice, "d1").visit)
            let search = try #require(try await Self.searched(alice, "keywords=treaties").anchor)
            _ = try await alice.send(.patch, "/api/v1/me/preferences", #"{"citationStyle": "turabian", "researchLoggingEnabled": false}"#)

            #expect(try decode(ProjectList.self, try await bob.get("/api/v1/me/projects")).total == 0)
            #expect(try decode(ActiveProject.self, try await bob.get("/api/v1/me/active-project")).projectId == nil)
            let history = try decode(HistoryPage.self, try await bob.get("/api/v1/me/history"))
            #expect(history.totalDocuments == 0 && history.totalSearches == 0 && history.loggingEnabled)
            #expect(try decode(SessionLog.self, try await bob.get("/api/v1/me/history/sessions")).summary.eventCount == 0)
            #expect(!String(buffer: try await bob.get("/api/v1/me/history/appendix?format=csv").body).contains("treaties"))
            #expect(try decode(Preferences.self, try await bob.get("/api/v1/me/preferences")).citationStyle == "")
            #expect(try await Self.visit(bob, "d1").outcome == "inserted", "his switch is his own")

            let byId: [(TestResponse, String)] = [
                (try await bob.get("/api/v1/me/projects/\(grain.id)"), "PROJECT_NOT_FOUND"),
                (try await bob.send(.patch, "/api/v1/me/projects/\(grain.id)", #"{"name": "Bob's"}"#), "PROJECT_NOT_FOUND"),
                (try await bob.send(.delete, "/api/v1/me/projects/\(grain.id)"), "PROJECT_NOT_FOUND"),
                (try await bob.send(.post, "/api/v1/me/projects/\(grain.id)/merge", #"{"into": "\#(grain.id)"}"#), "PROJECT_NOT_FOUND"),
                (try await bob.get("/api/v1/me/projects/\(grain.id)/home"), "PROJECT_NOT_FOUND"),
                (try await bob.send(.put, "/api/v1/me/active-project", #"{"projectId": "\#(grain.id)"}"#), "PROJECT_NOT_FOUND"),
                (try await bob.send(.delete, "/api/v1/me/history/documents/\(visit.id)"), "HISTORY_ENTRY_NOT_FOUND"),
                (try await bob.send(.delete, "/api/v1/me/history/searches/\(search.entryId)"), "HISTORY_ENTRY_NOT_FOUND"),
            ]
            for (index, (response, code)) in byId.enumerated() { #expect(problemCode(response) == code, "\(index)") }
            // His re-run of her anchor writes a row of his own, and hers stands.
            #expect(try await Self.searched(bob, "keywords=treaties", anchor: search).outcome == "inserted")
            let hers = try decode(HistoryPage.self, try await alice.get("/api/v1/me/history"))
            #expect(hers.totalDocuments == 1 && hers.searches.map(\.id) == [search.entryId] && !hers.loggingEnabled)
            #expect(try decode(ProjectList.self, try await alice.get("/api/v1/me/projects")).activeProjectId == grain.id)
        }
    }
}
