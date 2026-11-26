// Archives Visits' packet and ways in through the router (PLAN's S30d), over the synthetic export, whose documents carry no
// source note, so that no target derives and each answer is the plan's own: an add of documents by the kit's one add, a
// seed's halves turned on and never off, and the picker's New row; the sheet's writes of the topic and the four
// deliverables; the packet's states and its files, the text as it is and the PDF through a stand-in of the PDF service,
// the text on the app's page, named by the kit's rule; Project Home's Plan a Visit, which opens the project's plan or makes
// one from its engaged documents, and its gate; a collection's reading list, a static one's by the kit's rule and a smart
// one's results; the review sheet's rows for the plans a document seeds; and the refusals. The packet's text, held to the
// kit's exporter over targets that derive, and a plan's round trip through the export, are `ArchivePacketParityTests`'.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct ArchivePacketTests {
    static let volume = ArchiveVisitTests.volume
    static let day = "2026-11-25"

    static func seeds(_ ids: [String], volume: String = volume) -> [[String: String]] {
        ids.map { ["volumeId": volume, "documentId": $0] }
    }

    static func added(_ browser: Browser, _ plan: String, _ ids: [String], source: Bool, refs: Bool,
                      sourceLocation: SourceLocation = #_sourceLocation) async throws -> VisitPlanDetail {
        try ArchiveVisitTests.detail(try await browser.send(.post, "/api/v1/me/visits/\(plan)/documents", try ArchiveVisitTests.json([
            "documents": seeds(ids), "includeSource": source, "includeExternalRefs": refs,
        ])), sourceLocation: sourceLocation)
    }

    static func packet(_ browser: Browser, _ plan: String, _ query: String = "day=\(day)") async throws -> VisitPacket {
        let response = try await browser.get("/api/v1/me/visits/\(plan)/packet?\(query)")
        #expect(response.status == .ok, "\(String(buffer: response.body))")
        return try decode(VisitPacket.self, response)
    }

    /// The seeds as the store holds them, each `key source refs`.
    static func seedRows(_ fixture: UserDataFixture, _ plan: String) throws -> [String] {
        try #require(try ArchiveVisitTests.held(fixture, plan)).documents
            .map { "\($0.documentKey) \($0.includeSource) \($0.includeExternalRefs)" }
    }

    /// An add is the kit's one add: new documents minted under their derived ids with exactly the halves asked for, in the
    /// order they came, and a document already seeded gaining the halves asked for, never losing one; the plan stamped.
    @Test func anAddSeedsThePlanByTheKitsOneAdd() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let plan = try await ArchiveVisitTests.created(owner, ["name": "Berlin"])
            let first = try await Self.added(owner, plan.id, ["d2", "d1", "d2"], source: true, refs: false)
            #expect(first.documents.map(\.key) == ["\(Self.volume)/d1", "\(Self.volume)/d2"], "listed by their keys, the second d2 one seed")
            #expect(try Self.seedRows(fixture, plan.id) == ["\(Self.volume)/d1 true false", "\(Self.volume)/d2 true false"])
            let held = try #require(try ArchiveVisitTests.held(fixture, plan.id))
            let id = try #require(UUID(uuidString: plan.id))
            #expect(held.documents.map(\.id) == ["\(Self.volume)/d1", "\(Self.volume)/d2"].map {
                ArchiveVisitPlanWrites.derivedChildId(planId: id, key: $0)
            }, "each under its derived id, as the app mints it")

            // The references half for d2 and d3: d2 keeps its source, d3 is minted with the references alone, as the kit's
            // rule answers over the rows the store held.
            let kit = ArchiveVisitPlanWrites.addingSeeds([(Self.volume, "d2"), (Self.volume, "d3")], includeSource: false,
                                                         includeExternalRefs: true, to: held.documents, planId: id)
            #expect(kit.updated.map(\.index) == [1] && kit.inserted.map(\.documentKey) == ["\(Self.volume)/d3"])
            _ = try await Self.added(owner, plan.id, ["d2", "d3"], source: false, refs: true)
            #expect(try Self.seedRows(fixture, plan.id)
                == ["\(Self.volume)/d1 true false", "\(Self.volume)/d2 true true", "\(Self.volume)/d3 false true"])
            let after = try #require(try ArchiveVisitTests.held(fixture, plan.id))
            #expect(after.lastModified == UserDataFixture.now, "the plan stamped as its seeds join it")

            // The refusals: no documents, neither half, a volume the catalogue does not list, an id that is no document's,
            // more than the app's ceiling, and a plan the user does not have.
            let path = "/api/v1/me/visits/\(plan.id)/documents"
            for (body, code) in [
                (["documents": [[String: String]](), "includeSource": true, "includeExternalRefs": true], "INVALID_PARAMETER"),
                (["documents": Self.seeds(["d1"]), "includeSource": false, "includeExternalRefs": false], "INVALID_PARAMETER"),
                (["documents": Self.seeds(["d1"], volume: "frus1999v99"), "includeSource": true, "includeExternalRefs": false], "VOLUME_NOT_FOUND"),
                (["documents": Self.seeds(["../d1"]), "includeSource": true, "includeExternalRefs": false], "INVALID_PARAMETER"),
                (["documents": Self.seeds((0...ArchiveVisitRoutes.seedLimit).map { "d\($0)" }), "includeSource": true,
                  "includeExternalRefs": false], "INVALID_PARAMETER"),
            ] as [([String: Any?], String)] {
                let refused = try await owner.send(.post, path, try ArchiveVisitTests.json(body))
                #expect(refused.status.code >= 400 && problemCode(refused) == code, "\(String(buffer: refused.body))")
            }
            let missing = try await owner.send(.post, "/api/v1/me/visits/\(UUID().uuidString)/documents",
                                               try ArchiveVisitTests.json(["documents": Self.seeds(["d1"]), "includeSource": true,
                                                                           "includeExternalRefs": false]))
            #expect(missing.status == .notFound && problemCode(missing) == "VISIT_NOT_FOUND")
            #expect(try Self.seedRows(fixture, plan.id).count == 3, "nothing refused was written")
        }
    }

    /// The picker's New row: a plan made under the active project, named as the way in suggests, seeded in the same write;
    /// documents come with both halves named.
    @Test func theNewRowMakesAPlanWithItsDocuments() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let project = try await ArchiveVisitTests.project(owner, "Berlin", question: "What did Khrushchev want?")
            let made = try await ArchiveVisitTests.created(owner, [
                "name": "Files, Lot 66 D 204", "documents": Self.seeds(["d1", "d2"]), "includeSource": true, "includeExternalRefs": false,
            ])
            #expect(made.name == "Files, Lot 66 D 204" && made.projectIds == [project] && made.inquiryText == "What did Khrushchev want?")
            #expect(made.documents.map { "\($0.key) \($0.includeSource) \($0.includeExternalRefs)" }
                == ["\(Self.volume)/d1 true false", "\(Self.volume)/d2 true false"])
            #expect(made.createdAt == ArchiveVisitTests.now && made.lastModified == ArchiveVisitTests.now)
            let halfless = try await owner.send(.post, "/api/v1/me/visits", try ArchiveVisitTests.json(["documents": Self.seeds(["d1"])]))
            #expect(halfless.status == .badRequest && problemCode(halfless) == "INVALID_PARAMETER")
            #expect(try await UserHalfSearchTests.answer(VisitPlanList.self, owner, "/api/v1/me/visits").total == 1)
        }
    }

    /// The sheet's writes: the topic as typed, a blank one as none, and the toggles the body names, the others kept.
    @Test func theSheetWritesTheTopicAndTheDeliverables() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let plan = try await ArchiveVisitTests.created(owner, ["name": "Berlin"])
            let path = "/api/v1/me/visits/\(plan.id)"
            let crib = try ArchiveVisitTests.detail(try await owner.send(.patch, path, #"{"deliverables": {"includeCitationCrib": true}}"#))
            #expect(crib.deliverables == .init(includeLinks: true, includeTargets: true, includeInquiry: true, includeCitationCrib: true))
            let links = try ArchiveVisitTests.detail(try await owner.send(.patch, path, #"{"deliverables": {"includeLinks": false}}"#))
            #expect(links.deliverables == .init(includeLinks: false, includeTargets: true, includeInquiry: true, includeCitationCrib: true))
            #expect(try #require(try ArchiveVisitTests.held(fixture, plan.id)).deliverables
                == ArchiveVisitDeliverables(includeLinks: false, includeCitationCrib: true))
            let topic = try ArchiveVisitTests.detail(try await owner.send(.patch, path, #"{"inquiryText": "The Vienna letters  "}"#))
            #expect(topic.inquiryText == "The Vienna letters  ", "as typed, the drafts sending the field as it is")
            let blank = try ArchiveVisitTests.detail(try await owner.send(.patch, path, #"{"inquiryText": "  "}"#))
            #expect(blank.inquiryText == nil)
            let unknown = try await owner.send(.patch, path, #"{"deliverables": {"includeAppendix": true}}"#)
            #expect(unknown.status == .badRequest && problemCode(unknown) == "INVALID_PARAMETER", "a toggle the packet has none of")
        }
    }

    /// The packet's states, each for its cause, the index first: no documents, then the packet itself, the kit's
    /// exporter's text on the day given or today's, with the deliverables written and the topic; its text file is that
    /// text, named by the kit's rule; and the refusals of a day, a format and a file with no packet.
    @Test func thePacketIsTheExportersTextAndItsTextFileIsThatText() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let plan = try await ArchiveVisitTests.created(owner, ["name": "Café / Berlin"])
            let empty = try await Self.packet(owner, plan.id)
            #expect(empty.unavailable == "noDocuments" && empty.text == nil && empty.repositories.isEmpty)
            #expect(empty.title == "Café / Berlin" && empty.fileName == TripPacketPDFRenderer.fileName(title: "Café / Berlin"))
            #expect(empty.fileName == "Archives Visit — Café - Berlin.pdf" && empty.textFileName == "Archives Visit — Café - Berlin.txt")
            #expect(empty.topicPlaceholder == TripPacketTopicSentence.placeholder && empty.day == Self.day)
            let none = try await owner.get("/api/v1/me/visits/\(plan.id)/packet/file?format=text")
            #expect(none.status == .conflict && problemCode(none) == "NOTHING_TO_EXPORT")

            _ = try await Self.added(owner, plan.id, ["d1", "d2"], source: true, refs: true)
            _ = try await owner.send(.patch, "/api/v1/me/visits/\(plan.id)",
                                     #"{"inquiryText": "The Vienna letters", "deliverables": {"includeCitationCrib": true}}"#)
            let shown = try await Self.packet(owner, plan.id)
            let text = try #require(shown.text)
            #expect(shown.unavailable == nil && shown.repository == nil && shown.repositories.isEmpty && shown.drafts.isEmpty)
            #expect(text.hasPrefix("# Archive visit packet: Café / Berlin\n\n0 research targets\n\nGenerated 2026-11-25. "))
            #expect(text.contains("## Advance inquiry") && text.contains("## What this packet covers"))
            #expect(text.contains("2 of 2 seeding documents indexed on this device."), "the seed coverage, the kit's words")
            #expect(text.contains("## Citing what you find"), "the appendix the deliverables turned on")
            #expect(shown.topic == "The Vienna letters" && shown.deliverables.includeCitationCrib)
            // Today's, by the server's clock, with no day given.
            #expect(try await Self.packet(owner, plan.id, "").day == "2026-10-24")
            // A repository the packet does not cover renders the whole plan.
            #expect(try await Self.packet(owner, plan.id, "repository=Nowhere&day=\(Self.day)").repository == nil)

            let file = try await owner.get("/api/v1/me/visits/\(plan.id)/packet/file?format=text&day=\(Self.day)")
            #expect(file.status == .ok && file.headers[.contentType] == "text/plain; charset=utf-8")
            #expect(Data(buffer: file.body) == Data(text.utf8), "the text the sheet shows, byte for byte")
            #expect(file.headers[.contentDisposition]
                == "attachment; filename=\"Archives Visit _ Caf_ - Berlin.txt\"; filename*=UTF-8''Archives%20Visit%20%E2%80%94%20Caf%C3%A9%20-%20Berlin.txt")
            #expect(file.headers[.cacheControl] == "no-store" && file.headers[.xContentTypeOptions] == "nosniff")

            for query in ["day=2026-11-31", "day=26-11-25", "day=2026-1-125", "format=text&day=2026-02-30"] {
                let refused = try await owner.get("/api/v1/me/visits/\(plan.id)/packet?\(query)")
                #expect(refused.status == .badRequest, "\(query)")
            }
            for format in ["markdown", ""] {
                let refused = try await owner.get("/api/v1/me/visits/\(plan.id)/packet/file?format=\(format)")
                #expect(refused.status == .badRequest && problemCode(refused) == "INVALID_PARAMETER")
            }
            let pdf = try await owner.get("/api/v1/me/visits/\(plan.id)/packet/file?format=pdf")
            #expect(pdf.status == .serviceUnavailable && problemCode(pdf) == "PDF_SERVICE_UNAVAILABLE", "no PDF service named")
        }
    }

    /// With no index served the packet says so, before it reads the plan's seeds.
    @Test func withNoIndexThePacketSaysTheIndexIsNotReady() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let plan = try await ArchiveVisitTests.created(owner, ["name": "Berlin"])
            #expect(try await Self.packet(owner, plan.id).unavailable == "indexUnavailable")
            let file = try await owner.get("/api/v1/me/visits/\(plan.id)/packet/file?format=text")
            #expect(file.status == .serviceUnavailable && problemCode(file) == "INDEX_NOT_READY")
        }
    }

    /// The fixture's server with its PDF service at `pdfURL`, serving the synthetic export.
    static func app(_ fixture: UserDataFixture, pdfURL: String) async -> some ApplicationProtocol {
        var configuration = ServerConfiguration(dataDirectory: fixture.server.files.root)
        configuration.pdfURL = pdfURL
        let state = ServerState(configuration: configuration, pdfCheckWithin: PDFExportTests.checkWithin)
        await state.openExistingIndex(files: fixture.server.files)
        return Application(router: ServedRouter(base: .root, router: buildRouter(
            state: state, resources: fixture.server.resources, reader: fixture.server.reader, userData: fixture.services)))
    }

    /// The PDF is the packet's text on the app's page, through the PDF service's Chromium: the page holds the text as it
    /// is, escaped, in the fixed-width face at 9 points, printed on US Letter at 54 points' margin, nothing else asked;
    /// the service's PDF answered under the kit's name, and kept in no history.
    @Test func thePacketsPDFIsItsTextPrintedOnTheAppsPage() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let service = StandInPDFService()
        try await service.app.test(.live) { standIn in
            let address = "http://localhost:\(try #require(standIn.port))"
            try await Self.app(fixture, pdfURL: address).test(.router) { client in
                let owner = Browser(client: client)
                let plan = try await ArchiveVisitTests.created(owner, ["name": "Lots <&> files"])
                _ = try await Self.added(owner, plan.id, ["d1"], source: true, refs: false)
                let text = try #require(try await Self.packet(owner, plan.id).text)
                let pdf = try await owner.get("/api/v1/me/visits/\(plan.id)/packet/file?format=pdf&day=\(Self.day)")
                #expect(pdf.status == .ok && pdf.headers[.contentType] == "application/pdf", "\(String(buffer: pdf.body))")
                #expect(Data(buffer: pdf.body) == StandInPDFService.pdf)
                #expect(pdf.headers[.contentDisposition]?.contains("filename*=UTF-8''Archives%20Visit%20%E2%80%94%20Lots%20%3C&%3E%20files.pdf") == true,
                        "\(pdf.headers[.contentDisposition] ?? "")")

                let form = try #require(await service.prints.first)
                let boundary = try #require(form.contentType.components(separatedBy: "multipart/form-data; boundary=").last)
                let parts = FormPart.parts(of: form.body, boundary: boundary)
                #expect(parts.map(\.name) == ["files", "paperWidth", "paperHeight", "marginTop", "marginBottom", "marginLeft", "marginRight"])
                #expect(parts.dropFirst().map { String(decoding: $0.body, as: UTF8.self) } == ["8.5", "11", "0.75", "0.75", "0.75", "0.75"])
                let page = try #require(parts.first)
                #expect(page.fileName == "index.html" && page.contentType == "text/html; charset=utf-8")
                #expect(page.body == ArchivePacketRoutes.page(packet: text, title: "Lots <&> files"))
                let html = String(decoding: page.body, as: UTF8.self)
                #expect(html.contains("<pre>\(ArchivePacketRoutes.escaped(text))</pre>"))
                #expect(html.contains("# Archive visit packet: Lots &lt;&amp;&gt; files"), "the text escaped, as it is")
                #expect(html.contains(#"font-family: "DejaVu Sans Mono", monospace; font-size: 9pt;"#))
                #expect(html.contains("<title>Archives Visit — Lots &lt;&amp;&gt; files</title>"))
                #expect(!html.contains("<script") && !html.contains("src=") && !html.contains("@import"), "a page that loads nothing")
                let history = try decode(HistoryPage.self, try await owner.get("/api/v1/me/history"))
                #expect(history.exports.isEmpty, "a packet's export is kept in no history")
            }
        }
    }

    /// Plan a Visit: offered while the project engages a document or has a plan; it makes the project's plan from its
    /// engaged documents, named after it, its question the topic, both halves on, then opens that plan, the most recently
    /// changed that names the project; a project that engages nothing and has no plan has none made.
    @Test func planAVisitOpensTheProjectsPlanOrMakesOne() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let empty = try await ArchiveVisitTests.project(owner, "Nothing yet", question: nil)
            let gate = try decode(ProjectVisit.self, try await owner.get("/api/v1/me/projects/\(empty)/visit"))
            #expect(gate == ProjectVisit(planId: nil, engagedDocuments: 0))
            let refused = try await owner.send(.post, "/api/v1/me/projects/\(empty)/visit")
            #expect(refused.status == .conflict && problemCode(refused) == "NOTHING_TO_PLAN")
            #expect(try await UserHalfSearchTests.answer(VisitPlanList.self, owner, "/api/v1/me/visits").total == 0)

            let berlin = try await ArchiveVisitTests.project(owner, "Berlin", question: "What did Khrushchev want?")
            try await ArchiveVisitTests.note(owner, on: "d2", project: berlin)
            try await ArchiveVisitTests.note(owner, on: "d1", project: berlin)
            #expect(try decode(ProjectVisit.self, try await owner.get("/api/v1/me/projects/\(berlin)/visit")).engagedDocuments == 2)
            let made = try await owner.send(.post, "/api/v1/me/projects/\(berlin)/visit")
            #expect(made.status == .created, "\(String(buffer: made.body))")
            let answer = try decode(ProjectVisitAnswer.self, made)
            #expect(answer.created && answer.plan.name == "Berlin" && answer.plan.projectIds == [berlin])
            #expect(answer.plan.inquiryText == "What did Khrushchev want?")
            #expect(answer.plan.documents.map { "\($0.key) \($0.includeSource) \($0.includeExternalRefs)" }
                == ["\(Self.volume)/d1 true true", "\(Self.volume)/d2 true true"])
            #expect(made.headers[.location] == "/api/v1/me/visits/\(answer.plan.id)")
            #expect(try decode(ProjectVisit.self, try await owner.get("/api/v1/me/projects/\(berlin)/visit")).planId == answer.plan.id)

            // Opened, not made again: the most recently changed plan that names the project.
            let again = try await owner.send(.post, "/api/v1/me/projects/\(berlin)/visit")
            #expect(again.status == .ok)
            #expect(try decode(ProjectVisitAnswer.self, again).created == false)
            #expect(try decode(ProjectVisitAnswer.self, again).plan.id == answer.plan.id)
            let unknown = try await owner.send(.post, "/api/v1/me/projects/\(UUID().uuidString)/visit")
            #expect(unknown.status == .notFound && problemCode(unknown) == "PROJECT_NOT_FOUND")
        }
    }

    /// A collection's reading list: a static one's documents and excerpts in their order, each once, its headings left
    /// out, by the kit's rule; a smart one's saved search's results; with the names the picker reads.
    @Test func aCollectionsReadingListIsTheKitsRule() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume], indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let letters = try await CollectionTests.made(owner, "  Letters  ")
            let path = "\(CollectionTests.base)/\(letters.id)"
            _ = try await CollectionTests.edit(owner, "\(path)/documents", try CollectionTests.documents(["d2", "d1"]))
            _ = try await CollectionTests.edit(owner, "\(path)/blocks", #"{"kind": "heading"}"#)
            let list = try decode(VisitSeedDocuments.self, try await owner.get("\(path)/visit-documents"))
            #expect(list.documents.map(\.documentId) == ["d2", "d1"] && list.documents.allSatisfy { $0.volumeId == Self.volume })
            #expect(list.listName == "Letters" && list.suggestedName == "Letters")

            let search = try await SearchSetTests.saved(owner, "Treaties", "keywords=treaties")
            let treaties = try await CollectionTests.made(owner, "Treaties")
            let smartPath = "\(CollectionTests.base)/\(treaties.id)"
            _ = try await CollectionTests.detail(owner, .patch, smartPath, try CollectionTests.json(["savedSearchId": search.id]))
            let results = try decode(CollectionExportRoutes.Results.self, try await owner.get("\(smartPath)/results"))
            let smart = try decode(VisitSeedDocuments.self, try await owner.get("\(smartPath)/visit-documents"))
            #expect(smart.documents.map(\.documentId) == results.items.map(\.documentId) && smart.documents.count == 2)
            let unknown = try await owner.get("\(CollectionTests.base)/\(UUID().uuidString)/visit-documents")
            #expect(unknown.status == .notFound)
        }
    }

    /// The review sheet's rows: one a plan the document seeds, by name whatever its case, then by id; a plan that seeds
    /// it no longer is not listed.
    @Test func theReviewSheetOpensEachPlanTheDocumentSeeds() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume], indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let zurich = try await ArchiveVisitTests.created(owner, ["name": "zurich"])
            let berlin = try await ArchiveVisitTests.created(owner, ["name": "Berlin"])
            let untitled = try await ArchiveVisitTests.created(owner, ["name": ""])
            let other = try await ArchiveVisitTests.created(owner, ["name": "Abilene"])
            for plan in [zurich, berlin, untitled] { _ = try await Self.added(owner, plan.id, ["d1"], source: true, refs: false) }
            _ = try await Self.added(owner, other.id, ["d2"], source: true, refs: false)
            let review = try decode(DocumentReview.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/review"))
            #expect(review.others.inVisitPlan)
            #expect(review.others.plans.map(\.name) == ["Berlin", "Untitled Archives Visit", "zurich"])
            #expect(review.others.plans.map(\.id) == [berlin.id, untitled.id, zurich.id])
            let removed = try await owner.send(.delete, "/api/v1/me/visits/\(berlin.id)/documents?key=\(Self.volume)/d1")
            #expect(removed.status == .ok)
            let after = try decode(DocumentReview.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/review"))
            #expect(after.others.plans.map(\.name) == ["Untitled Archives Visit", "zurich"])
        }
    }
}
