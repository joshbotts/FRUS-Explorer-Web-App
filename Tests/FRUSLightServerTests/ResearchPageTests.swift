// The Research page through the API (PLAN's S19b): over a Mac export imported as the owner's, the
// categories with their counts, and each category's documents with their rows, as the app's
// `ResearchView` shows them, the kit's aggregation deciding which documents count; the titles the
// served index gives; Changed by an update refused as waiting for phase 3; the refusals of a key that
// names no category; and each user's research theirs alone.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct ResearchPageTests {
    static let v06 = "frus1961-63v06"
    static let nicaragua = "frus1894Nicaragua"

    static func id(_ number: Int) -> UUID { UUID(uuidString: String(format: "5E19B000-0000-4000-8000-%012d", number))! }
    static func day(_ day: Int) -> Date { Date(timeIntervalSince1970: 1_767_225_600 + Double(day - 1) * 86_400) }  // 2026-01-<day>

    static let berlin = id(1), revisit = id(2), unused = id(3), alpha = id(4), twin = id(5), otherTwin = id(6)
    static let briefing = id(50), unnamed = id(51), empty = id(52), smart = id(53), atlas = id(54), twins = id(55), otherTwins = id(56)

    /// The owner's research, as a Mac's export brings it: notes, the newest of one document's empty,
    /// two of another's changed at one time, and one on no document; highlights of each colour, one of
    /// a colour this build does not know, one with no words and two made at one time; a document tagged
    /// directly, and one with a tag the user does not have; tags and collections whose names tie, and
    /// whose case would order them otherwise; summaries, one a headnote draft; a visit plan; and
    /// collections, curated, unnamed, empty and smart. Each tie comes in the order its id would not.
    static func envelope() -> ResearchDataEnvelope {
        let notes = [
            ResearchNoteExport(id: id(10), documentId: "d1", volumeId: v06, bodyText: "First thought", projectIds: [], userTagIds: [berlin],
                               selectedSummaryIds: [], linkedHighlightIds: [], createdAt: day(2), lastModified: day(2)),
            ResearchNoteExport(id: id(11), documentId: "d1", volumeId: v06, bodyText: "", projectIds: [], userTagIds: [],
                               selectedSummaryIds: [], linkedHighlightIds: [], createdAt: day(5), lastModified: day(5)),
            ResearchNoteExport(id: id(14), documentId: "d2", volumeId: v06, bodyText: "Again on d2", projectIds: [], userTagIds: [],
                               selectedSummaryIds: [], linkedHighlightIds: [], createdAt: day(3), lastModified: day(3)),
            ResearchNoteExport(id: id(12), documentId: "d2", volumeId: v06, bodyText: "On d2", projectIds: [], userTagIds: [revisit],
                               selectedSummaryIds: [], linkedHighlightIds: [], createdAt: day(3), lastModified: day(3)),
            ResearchNoteExport(id: id(15), documentId: "", volumeId: "", bodyText: "On no document", projectIds: [], userTagIds: [],
                               selectedSummaryIds: [], linkedHighlightIds: [], createdAt: day(1), lastModified: day(1)),
            ResearchNoteExport(id: id(13), documentId: "d1", volumeId: nicaragua, bodyText: "Managua", projectIds: [],
                               userTagIds: [berlin, revisit], selectedSummaryIds: [], linkedHighlightIds: []),
        ]
        let highlight = { (n: Int, document: String, color: String, text: String, at: Date?) in
            DocumentHighlightExport(id: id(n), volumeId: v06, documentId: document, startOffset: 0, endOffset: 5, colorTag: color,
                                    selectedText: text, renderingVersion: "", createdAt: at)
        }
        let highlights = [
            highlight(20, "d1", "yellow", "Allow me", day(4)),
            highlight(21, "d1", "pink", "", day(1)),
            highlight(22, "d1", "purple", "Purple text", day(6)),
            highlight(23, "d1", "green", "Green text", nil),
            highlight(25, "d9", "blue", "Blue again", day(7)),
            highlight(24, "d9", "blue", "Blue text", day(7)),
        ]
        let tags = [UserTagExport(id: berlin, name: "Berlin"), UserTagExport(id: revisit, name: "revisit"),
                    UserTagExport(id: unused, name: "Unused"), UserTagExport(id: alpha, name: "alpha"),
                    UserTagExport(id: otherTwin, name: "Twin"), UserTagExport(id: twin, name: "Twin")]
        let assignments = [
            DocumentTagAssignmentExport(id: id(30), volumeId: v06, documentId: "d3", tagId: berlin),
            DocumentTagAssignmentExport(id: id(31), volumeId: v06, documentId: "d4", tagId: id(39)),
            DocumentTagAssignmentExport(id: id(32), volumeId: v06, documentId: "d2", tagId: alpha),
            DocumentTagAssignmentExport(id: id(33), volumeId: v06, documentId: "d3", tagId: alpha),
            DocumentTagAssignmentExport(id: id(34), volumeId: v06, documentId: "d2", tagId: otherTwin),
            DocumentTagAssignmentExport(id: id(35), volumeId: v06, documentId: "d3", tagId: twin),
        ]
        let summary = { (n: Int, document: String, draft: Bool) in
            GeneratedSummaryExport(id: id(n), documentId: document, volumeId: v06, promptId: id(49), responseText: "A summary.",
                                   responseFormat: .general, wasChunked: false, createdAt: day(1), lastModified: day(1),
                                   authorship: .aiGenerated, isHeadnoteDraft: draft)
        }
        let entry = { (n: Int, document: String, kind: String, order: Int) in
            CollectionEntryExport(id: id(n), documentId: document, volumeId: document.isEmpty ? "" : v06, sortOrder: order,
                                  selectedNoteIds: [], kind: kind, level: 1, text: kind == "document" ? nil : "Text",
                                  generatedBlockType: kind == "generated" ? "bibliography" : nil, selectedHighlightIds: [])
        }
        let collection = { (collectionId: UUID, name: String, search: UUID?, entries: [CollectionEntryExport]) in
            CollectionExport(id: collectionId, name: name, projectIds: [], savedSearchId: search, entries: entries)
        }
        var envelope = ResearchDataEnvelope(
            formatVersion: ResearchDataEnvelope.currentFormatVersion, exportedAt: day(10), exportedForProjectName: nil,
            exportedForProjectResearchQuestion: nil, notes: notes, tags: tags, tagAssignments: assignments, highlights: highlights,
            collections: [
                collection(briefing, "Briefing book", nil, [entry(60, "d1", "document", 0), entry(61, "d1", "excerpt", 1),
                                                          entry(62, "", "heading", 2), entry(63, "", "prose", 3),
                                                          entry(64, "d8", "excerpt", 4), entry(65, "", "generated", 5)]),
                collection(unnamed, "", nil, [entry(66, "d2", "document", 0)]),
                collection(empty, "Empty", nil, [entry(67, "", "heading", 0)]),
                collection(smart, "Smart", id(98), [entry(68, "d10", "document", 0)]),
                collection(atlas, "atlas", nil, [entry(69, "d2", "document", 0)]),
                collection(otherTwins, "Twins", nil, [entry(76, "d3", "document", 0)]),
                collection(twins, "Twins", nil, [entry(75, "d3", "document", 0)]),
            ],
            prompts: [], projects: [],
            summaries: [summary(40, "d1", false), summary(41, "d1", false), summary(42, "d5", false), summary(43, "d6", true)])
        envelope.archiveVisits = [
            ArchiveVisitPlanExport(id: id(70), name: "College Park", projectIds: [], tiers: [],
                                   deliverables: ArchiveVisitDeliverables(includeLinks: false, includeTargets: false, includeInquiry: false,
                                                                          includeCitationCrib: false),
                                   documents: [ArchiveVisitDocumentExport(id: id(71), documentKey: "\(v06)/d7", includeSource: true,
                                                                          includeExternalRefs: false)],
                                   targets: []),
        ]
        return envelope
    }

    /// A fixture serving the synthetic export, with the owner's research imported.
    static func fixture(indexed: Bool = true) async throws -> UserDataFixture {
        let fixture = try await UserDataFixture(indexed: indexed)
        _ = try MacImport.run(envelope(), into: fixture.store, for: "owner", includingInstanceWide: true)
        return fixture
    }

    static func list(_ browser: Browser, _ group: String? = nil) async throws -> ResearchDocumentList {
        let response = try await browser.get("/api/v1/me/research/documents" + (group.map { "?group=\($0)" } ?? ""))
        #expect(response.status == .ok, "\(String(buffer: response.body))")
        return try decode(ResearchDocumentList.self, response)
    }

    static func keys(_ list: ResearchDocumentList) -> [String] { list.items.map { "\($0.volumeId)/\($0.documentId)" } }

    /// The categories, as the app's sidebar counts them: every annotated document, the kit's six
    /// sources' union, a headnote draft and a heading counting for nothing; the documents a note is on;
    /// every note; the curated collections with a document, by the name each prints, an excerpt and its
    /// document counting once; the tags on documents, the most used first, then by name whatever the
    /// case; and the colours in the kit's order, one this build does not know read as yellow.
    @Test func theCategoriesAreTheAppsWithTheKitsCounts() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let response = try await Browser(client: client).get("/api/v1/me/research")
            #expect(response.status == .ok, "\(String(buffer: response.body))")
            let page = try decode(ResearchPage.self, response)
            #expect(page.allAnnotated == 10, "a note on no document none of them")
            #expect(page.hasNotes == 4 && page.notes == 6, "Contains Notes counting the note on no document, as the app's badge does")
            #expect(page.collections == [
                .init(id: Self.atlas.uuidString, name: "atlas", count: 1),
                .init(id: Self.briefing.uuidString, name: "Briefing book", count: 2),
                .init(id: Self.twins.uuidString, name: "Twins", count: 1),
                .init(id: Self.otherTwins.uuidString, name: "Twins", count: 1),
                .init(id: Self.unnamed.uuidString, name: "Untitled Collection", count: 1),
            ], "by name whatever the case, then by id")
            #expect(page.tags == [
                .init(id: Self.berlin.uuidString, name: "Berlin", count: 3),
                .init(id: Self.alpha.uuidString, name: "alpha", count: 2),
                .init(id: Self.revisit.uuidString, name: "revisit", count: 2),
                .init(id: Self.twin.uuidString, name: "Twin", count: 1),
                .init(id: Self.otherTwin.uuidString, name: "Twin", count: 1),
            ], "the most used first, then by name whatever the case, then by id")
            #expect(page.highlightColors.map(\.color) == ["yellow", "green", "blue", "pink"])
            #expect(page.highlightColors.allSatisfy { $0.count == 1 })
            #expect(try await Browser(client: client).get("/api/v1/me/research?group=hasNotes").status == .badRequest,
                    "the page takes no parameter")
        }
    }

    /// All Research Documents, the most recently annotated first and then by key, and each row as the
    /// app's draws it: the served index's title or the id, the catalogue's volume title, the newest
    /// annotation's time, the newest note's text or none for an empty one, the counts, three highlights
    /// newest first, and the tags and collections in their orders.
    @Test func eachRowIsTheAppsRow() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let all = try await Self.list(browser)
            #expect(all.group == "allAnnotated" && all.name == nil && all.total == 10)
            #expect(Self.keys(all) == ["\(Self.v06)/d9", "\(Self.v06)/d1", "\(Self.v06)/d2", "\(Self.nicaragua)/d1", "\(Self.v06)/d10",
                                       "\(Self.v06)/d3", "\(Self.v06)/d4", "\(Self.v06)/d5", "\(Self.v06)/d7", "\(Self.v06)/d8"])
            #expect(try await Self.list(browser, "allAnnotated") == all, "the page's first category")

            let volumeTitle = try #require(fixture.server.resources.volume(Self.v06)?.title)
            let d1 = try #require(all.items.first { $0.volumeId == Self.v06 && $0.documentId == "d1" })
            #expect(d1 == ResearchDocument(
                volumeId: Self.v06, documentId: "d1", title: "1. Telegram From the Embassy in the Soviet Union", volumeTitle: volumeTitle,
                annotatedAt: UserStoreDate.text(Self.day(6)), latestNote: nil, noteCount: 2, summaryCount: 2, isInVisitPlan: false,
                highlights: [.init(id: Self.id(22).uuidString, color: "yellow", selectedText: "Purple text"),
                             .init(id: Self.id(20).uuidString, color: "yellow", selectedText: "Allow me"),
                             .init(id: Self.id(21).uuidString, color: "pink", selectedText: "")],
                highlightCount: 4, tags: [.init(id: Self.berlin.uuidString, name: "Berlin")],
                collections: [.init(id: Self.briefing.uuidString, name: "Briefing book")]))
            let d2 = try #require(all.items.first { $0.documentId == "d2" })
            #expect(d2.latestNote == "On d2", "of two notes changed at one time, the first by id")
            #expect(d2.noteCount == 2 && d2.annotatedAt == UserStoreDate.text(Self.day(3)))
            #expect(d2.tags.map(\.name) == ["alpha", "revisit", "Twin"], "by name, whatever the case")
            let d3 = try #require(all.items.first { $0.volumeId == Self.v06 && $0.documentId == "d3" })
            #expect(d3.tags.map(\.name) == ["alpha", "Berlin", "Twin"], "whatever the case, where case would put Berlin first")
            #expect(d3.collections.map(\.id) == [Self.twins.uuidString, Self.otherTwins.uuidString], "two of one name, by id")
            #expect(d2.collections.map(\.name) == ["atlas", "Untitled Collection"], "by the name each prints")
            let managua = try #require(all.items.first { $0.volumeId == Self.nicaragua })
            #expect(managua.title == "No. 1. Mr. Baker to Mr. Gresham" && managua.annotatedAt == nil && managua.latestNote == "Managua")
            #expect(managua.tags.map(\.name) == ["Berlin", "revisit"])
            // A document the index does not hold is named by its id; one only in a smart collection is
            // in it; one with only a summary, a plan or a tag the user lacks has its one fact.
            let d9 = try #require(all.items.first { $0.documentId == "d9" })
            #expect(d9.title == "d9" && d9.highlights.map(\.selectedText) == ["Blue text", "Blue again"] && d9.highlightCount == 2,
                    "two made at one time, by id")
            #expect(all.items.first { $0.documentId == "d10" }?.collections.map(\.name) == ["Smart"])
            #expect(all.items.first { $0.documentId == "d5" }?.summaryCount == 1)
            #expect(all.items.first { $0.documentId == "d7" }?.isInVisitPlan == true)
            #expect(all.items.first { $0.documentId == "d4" }?.tags == [])
            #expect(!Self.keys(all).contains("\(Self.v06)/d6"), "a headnote draft alone annotates nothing")
        }
    }

    /// Each category's documents: Contains Notes; a tag's, by its notes and its own; a collection's,
    /// curated, unnamed or smart; a colour's; and a tag or a collection the user has none of.
    @Test func eachCategoryListsTheAppsDocuments() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            // The note on no document, which Contains Notes' badge counts, the app's list leaves out.
            let noted = try await Self.list(browser, "hasNotes")
            #expect(Self.keys(noted) == ["\(Self.v06)/d1", "\(Self.v06)/d2", "\(Self.nicaragua)/d1"] && noted.total == 3)
            let tag = try await Self.list(browser, "tag.\(Self.berlin.uuidString.lowercased())")
            #expect(tag.name == "Berlin" && Self.keys(tag) == ["\(Self.v06)/d1", "\(Self.nicaragua)/d1", "\(Self.v06)/d3"])
            let collection = try await Self.list(browser, "collection.\(Self.briefing.uuidString)")
            #expect(collection.name == "Briefing book" && Self.keys(collection) == ["\(Self.v06)/d1", "\(Self.v06)/d8"])
            #expect(try await Self.list(browser, "collection.\(Self.unnamed.uuidString)").name == "Untitled Collection")
            #expect(Self.keys(try await Self.list(browser, "collection.\(Self.smart.uuidString)")) == ["\(Self.v06)/d10"])
            #expect(Self.keys(try await Self.list(browser, "collection.\(Self.empty.uuidString)")) == [])
            #expect(Self.keys(try await Self.list(browser, "highlightColor.yellow")) == ["\(Self.v06)/d1"])
            #expect(Self.keys(try await Self.list(browser, "highlightColor.blue")) == ["\(Self.v06)/d9"])
            let gone = try await Self.list(browser, "tag.\(Self.id(97).uuidString)")
            #expect(gone.name == nil && gone.items.isEmpty, "a tag the user has none of: the browser app's Tag, and nothing")
            let missing = try await Self.list(browser, "collection.\(Self.id(97).uuidString)")
            #expect(missing.name == "Untitled Collection" && missing.items.isEmpty)
        }
    }

    /// Changed by an update waits for phase 3's review of changed text, and says so; a key that names
    /// no category, given twice, or beside another parameter is refused; and a server keeping no user
    /// data keeps no page.
    @Test func whatWaitsAndWhatIsRefused() async throws {
        let fixture = try await Self.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let updated = try await browser.get("/api/v1/me/research/documents?group=updated")
            #expect(updated.status == .conflict && problemCode(updated) == "UPDATE_REVIEW_NOT_OFFERED")
            #expect(String(buffer: updated.body).contains("which this server does not offer yet"))
            for group in ["notes", "history", "tag.d1", "highlightColor.red", "collection", ""] {
                let response = try await browser.get("/api/v1/me/research/documents?group=\(group)")
                #expect(response.status == .badRequest && problemCode(response) == "INVALID_PARAMETER", "\(group)")
            }
            #expect(try await browser.get("/api/v1/me/research/documents?group=hasNotes&group=allAnnotated").status == .badRequest)
            #expect(try await browser.get("/api/v1/me/research/documents?page=2").status == .badRequest)
        }
        let off = try await UserDataFixture(userData: false)
        defer { withExtendedLifetime(off) {} }
        try await off.app.test(.router) { client in
            let response = try await Browser(client: client).get("/api/v1/me/research")
            #expect(response.status == .forbidden && problemCode(response) == "USER_DATA_OFF")
        }
    }

    /// While no index is served every row is named by its document's id, as the kit names a document
    /// it has no facts of; and another user's research is none of the owner's.
    @Test func withoutAnIndexAndForEachUser() async throws {
        let fixture = try await Self.fixture(indexed: false)
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addUser("stranger")
        try fixture.rows.addNote("5E19B000-0000-4000-8000-0000000000F1", user: "stranger", documentId: "d42")
        try fixture.rows.addHighlight("5E19B000-0000-4000-8000-0000000000F2", user: "stranger", documentId: "d43", colorTag: "pink")
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let all = try await Self.list(browser)
            #expect(all.items.first { $0.volumeId == Self.v06 && $0.documentId == "d1" }?.title == "d1")
            #expect(!Self.keys(all).contains("\(Self.v06)/d42") && !Self.keys(all).contains("\(Self.v06)/d43"))
            let page = try decode(ResearchPage.self, try await browser.get("/api/v1/me/research"))
            #expect(page.allAnnotated == 10 && page.notes == 6 && page.highlightColors.allSatisfy { $0.count == 1 })
        }
    }
}
