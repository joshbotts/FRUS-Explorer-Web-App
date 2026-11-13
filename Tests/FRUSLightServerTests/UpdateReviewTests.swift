// The corrections check and the update review (PLAN's S21f), through the router. On a Standalone server: Check
// for Corrections lists a volume GitHub corrected, by the kit's rule; Download, the app's Update, replaces its file
// and the library's indexing indexes it again with `indexVolume`, whose stamp records the document the correction
// changed; Research's Changed by an update lists it for a user who annotated it; the banner says what changed; the
// review sheet's search for a highlight's passage is the kit's, and Move Here moves it there; Mark Reviewed records
// the user's review, which hides the change from that user alone, and the index's own stamp, through the one
// writer. A download a stop cuts short of its re-index leaves the volume owed for the next start. In Import mode,
// the comparison of the served export with the mounted TEI finds the document whose TEI changed, which is reviewed
// the same way, and the served index is never written.

@testable import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import FTS5Store
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite(.timeLimit(.minutes(3))) struct UpdateReviewTests {
    static let volume = "frus1894Nicaragua"
    static let document = DocumentKey(volumeId: "frus1894Nicaragua", documentId: "d2")
    /// The passage a highlight covers, after the correction in the paragraph before it.
    static let passage = "touching an invasion of the troops of Honduras at Cape Gracias"

    /// The fixture volume, corrected as the Office of the Historian corrects one in place: two letters more in d2's
    /// first paragraph, before the highlighted passage, which then reads two characters later.
    static func corrected() throws -> Data {
        var xml = try String(contentsOf: RepositoryFiles.tei.appendingPathComponent("\(volume).xml"), encoding: .utf8)
        let d2 = try #require(xml.range(of: #"xml:id="d2""#))
        let target = try #require(xml.range(of: "information a copy of a", range: d2.upperBound..<xml.endIndex))
        xml.replaceSubrange(target, with: "information a copy of the")
        return Data(xml.utf8)
    }

    /// A Standalone server keeping user data, the fixture volume indexed from its library, and GitHub's listing
    /// naming the corrected file.
    struct Standalone {
        let users: UserDataFixture
        let github: FakeGitHub
        let library: VolumeLibrary
        let indexer: LibraryIndexer
        let provider: ServedIndexProvider
        let resources: ServerResources
        let reader: ReaderService

        init() async throws {
            users = try await UserDataFixture()
            let files = users.server.files
            try RepositoryFiles.mountTEI([UpdateReviewTests.volume], at: files.volumesDirectory)
            resources = users.server.resources.withOwnCatalogueOverlay()
            reader = ReaderService(volumesDirectory: files.volumesDirectory, resources: resources)
            github = FakeGitHub()
            github.serve("\(UpdateReviewTests.volume).xml", data: try UpdateReviewTests.corrected())
            library = VolumeLibrary(volumesDirectory: files.volumesDirectory, store: users.store, jobs: users.jobs,
                                    catalogue: resources.manifest, sources: github.sources, transport: github, mode: .standalone)
            try library.prepare()
            let state = users.server.state
            provider = ServedIndexProvider(state: state, resources: resources, volumesDirectory: files.volumesDirectory,
                                           userStore: users.store.searchDatabase)
            let indexer = LibraryIndexer(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory, mode: .standalone,
                                         resources: resources.indexing, jobs: users.jobs, state: state,
                                         observer: ServedIndexWriting(state: state, provider: provider, log: { _ in }), capacity: { .max })
            self.indexer = indexer
            // As the server wires them: a download's end queues the indexing, and a new file owes its volume a pass.
            library.whenDownloadsEnd { fetched in _ = try? await indexer.index(.afterDownload(fetched), requestedBy: nil) }
            library.whenFileWillBeReplaced { volumeId in indexer.oweReindex(volumeId) }
        }

        var app: some ApplicationProtocol {
            Application(router: ServedRouter(base: .root, router: buildRouter(
                state: users.server.state, resources: resources, reader: reader, provider: provider,
                userData: users.services, library: library, indexer: indexer)))
        }

        /// The page of the document as the reader renders it now.
        func page() async throws -> HighlightRoutes.Page {
            try await HighlightRoutes.page(of: UpdateReviewTests.document, reader: reader, provider: provider, resources: resources)
        }
    }

    /// A highlight over the passage, made on the page as it reads now, with the text and version the kit takes.
    static func highlightThePassage(on page: HighlightRoutes.Page, store: any HighlightStore, for user: String = "owner") throws -> HighlightRecord {
        let flat = buildFlatText(from: page.model)
        let range = try #require(flat.range(of: passage))
        let start = flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
        let end = start + passage.utf16.count
        return try store.createHighlight(in: document, start: start, end: end, colorTag: "yellow",
                                         selectedText: flatTextExcerpt(from: page.model, start: start, end: end) ?? "",
                                         renderingVersion: page.renderingVersion, for: user, at: UserDataFixture.now)
    }

    /// The done-when, in Swift: an update found, downloaded and indexed again, its change recorded and listed, the
    /// highlight's passage found where the kit finds it and moved there, and the change reviewed.
    @Test func aCorrectedVolumeIsFoundIndexedAgainAndItsChangeReviewed() async throws {
        let fixture = try await Standalone()
        defer { withExtendedLifetime(fixture) {} }
        _ = try await fixture.indexer.index(.asked(nil), requestedBy: nil)
        await fixture.users.jobs.waitUntilIdle()
        let before = try await fixture.page()
        let highlight = try Self.highlightThePassage(on: before, store: fixture.users.store)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            // Nothing changed yet: no banner, no Changed by an update.
            let quiet = try decode(DocumentChange.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d2/change"))
            #expect(quiet.line == nil && quiet.changeKind == nil && !quiet.canMarkReviewed && !quiet.highlightsStale)
            #expect(try decode(ResearchPage.self, try await owner.get("/api/v1/me/research")).updated == 0)

            // Check for Corrections: the volume GitHub corrected, by the kit's rule, and nothing downloaded.
            let checked = try await owner.send(.post, "/api/v1/admin/library/corrections")
            #expect(checked.status == .ok)
            let corrections = try decode(AdminLibrary.Corrections.self, checked)
            #expect(corrections.volumes.map(\.volumeId) == [Self.volume] && corrections.volumes.first?.indexed == true)
            #expect(corrections.volumes.first?.sideloaded == false)

            // Update: Download of the indexed volume, its corrected file in place, and the indexing after it.
            let posted = try await owner.send(.post, "/api/v1/admin/library/downloads", #"{"volumeIds":["frus1894Nicaragua"]}"#)
            #expect(posted.status == .accepted)
            await fixture.users.jobs.waitUntilIdle()
            await fixture.users.jobs.waitUntilIdle()
            #expect(try Data(contentsOf: fixture.users.server.files.volumesDirectory.appendingPathComponent("\(Self.volume).xml"))
                    == Self.corrected())
            let jobs = try decode(AdminJobList.self, try await owner.get("/api/v1/admin/jobs")).jobs
            #expect(jobs.contains { $0.kind == "libraryIndex" && $0.state == "succeeded" }, "\(jobs.map { "\($0.kind) \($0.state)" })")
            #expect(!fixture.indexer.owesReindex(Self.volume), "indexed again from its new file")
            #expect(try decode(AdminLibrary.Corrections.self, try await owner.send(.post, "/api/v1/admin/library/corrections")).volumes.isEmpty)

            // The kit's stamp: d2's text changed, the other documents' not.
            let served = try #require(try await fixture.provider.servedIfReady())
            let revision = try #require(try await served.pipeline.documentRevision(volumeId: Self.volume, documentId: "d2"))
            #expect(revision.changeKind == "body" && revision.changedAt != nil && revision.reviewedAt == nil)
            let changed = try await served.pipeline.unreviewedDocumentRevisions()
            #expect(changed.map(\.documentId) == ["d2"], "\(changed.map(\.documentId))")

            // Research: Changed by an update lists it, in the kit's words.
            #expect(try decode(ResearchPage.self, try await owner.get("/api/v1/me/research")).updated == 1)
            let updated = try decode(ResearchDocumentList.self, try await owner.get("/api/v1/me/research/documents?group=updated"))
            #expect(updated.items.map(\.documentId) == ["d2"])
            #expect(updated.items.first?.change == .init(kind: "body", line: "Text changed in an update — highlight positions may have moved"))
            #expect(updated.items.first?.reviewable == true && updated.items.first?.opens == nil, "opens the document itself")

            // The banner, in the app's words.
            let banner = try decode(DocumentChange.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d2/change"))
            #expect(banner.line == "The text of this document changed in a volume update. Some highlights may be misaligned.")
            #expect(banner.changeKind == "body" && banner.highlightsStale && banner.canMarkReviewed && !banner.foundInTEI)

            // The sheet: the highlight stale, its passage found once, two characters on, where the kit's search finds it.
            let after = try await fixture.page()
            let kit = HighlightReanchor.locate(passage: highlight.selectedText, storedStart: highlight.startOffset,
                                               storedEnd: highlight.endOffset, in: buildFlatTextBlocks(from: after.model))
            guard case .moved(let match) = kit else { Issue.record("the kit's search: \(kit)"); return }
            #expect(match.shift == 2)
            let sheet = try decode(DocumentReview.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d2/review"))
            #expect(sheet.currentVersion == after.renderingVersion && sheet.change == banner)
            #expect(sheet.changeLine == banner.line)
            let row = try #require(sheet.highlights.first)
            #expect(sheet.highlights.count == 1 && row.id == highlight.id && row.status == "stale")
            #expect(row.statusLine == "Made against an earlier version of the text — its position may have moved.")
            #expect(row.search == "moved" && row.searchLine == "Found once, at a new position in the corrected text.")
            #expect(row.context?.start == match.start && row.context?.end == match.end && row.context?.found == Self.passage)
            #expect(row.canMove && row.canConfirm)

            // Move Here: refused for another version of the text, then to the kit's match.
            let stale = try await owner.send(.post, "/api/v1/me/highlights/\(highlight.id)/move", #"{"renderingVersion":"\#(before.renderingVersion)"}"#)
            #expect(problemCode(stale) == "DOCUMENT_CHANGED")
            let moved = try decode(Highlight.self, try await owner.send(.post, "/api/v1/me/highlights/\(highlight.id)/move",
                                                                       #"{"renderingVersion":"\#(after.renderingVersion)"}"#))
            #expect(moved.startOffset == match.start && moved.endOffset == match.end && moved.renderingVersion == after.renderingVersion)
            #expect(moved.selectedText == highlight.selectedText && moved.isStale == false)
            #expect(problemCode(try await owner.send(.post, "/api/v1/me/highlights/\(highlight.id)/move",
                                                    #"{"renderingVersion":"\#(after.renderingVersion)"}"#)) == "HIGHLIGHT_NOT_MOVABLE")
            #expect(problemCode(try await owner.send(.post, "/api/v1/me/highlights/\(highlight.id)/confirm",
                                                    #"{"renderingVersion":"\#(after.renderingVersion)"}"#)) == "HIGHLIGHT_ALIGNED")

            // Mark Reviewed: refused for a change the sheet did not show; then the user's ledger row, the change hidden from
            // them, and the index's own stamp, since no one else's research is on the document.
            #expect(banner.contentHash == revision.contentHash)
            let path = "/api/v1/me/volumes/\(Self.volume)/documents/d2/review"
            #expect(problemCode(try await owner.send(.post, path, #"{"contentHash":"0000","changeKind":"body"}"#)) == "DOCUMENT_CHANGED")
            #expect(problemCode(try await owner.send(.post, path, #"{"contentHash":"\#(revision.contentHash)","changeKind":"apparatus"}"#)) == "DOCUMENT_CHANGED")
            let shown = #"{"contentHash":"\#(revision.contentHash)","changeKind":"body"}"#
            let reviewed = try decode(DocumentChange.self, try await owner.send(.post, path, shown))
            #expect(reviewed.line == nil && reviewed.changeKind == nil && !reviewed.canMarkReviewed && reviewed.reviewedAt != nil)
            #expect(problemCode(try await owner.send(.post, path, shown)) == "NOTHING_TO_REVIEW")
            let ledger = try fixture.users.store.documentReviews(of: Self.document, for: "owner")
            #expect(ledger.map(\.contentHash) == [revision.contentHash] && ledger.map(\.changeKind) == ["body"])
            #expect(try decode(ResearchPage.self, try await owner.get("/api/v1/me/research")).updated == 0)
            await fixture.users.jobs.waitUntilIdle()
            let stamped = try #require(try await fixture.provider.servedIfReady())
            #expect(try await stamped.pipeline.documentRevision(volumeId: Self.volume, documentId: "d2")?.reviewedAt != nil,
                    "the index's own record that the change was reviewed, by the job of its one writer")
            let review = try decode(AdminJobList.self, try await owner.get("/api/v1/admin/jobs")).jobs.first { $0.kind == "indexReviews" }
            #expect(review?.state == "succeeded" && review?.progress == "Recorded 1 review in the index.", "\(String(describing: review))")
            // Administration's tallies: the change reviewed by everyone whose research is on it, and stamped.
            let tallies = try decode(AdminUpdates.self, try await owner.get("/api/v1/admin/library/updates"))
            #expect(tallies.volumes.isEmpty, "\(tallies.volumes)")
            #expect(tallies.totals == .init(changedDocuments: 0, volumes: 0, annotatedDocuments: 0))
        }
        // Another user's review is their own: one who annotated the document still has the change to review.
        _ = try fixture.users.store.signedInUser("bob", at: UserDataFixture.now)
        _ = try Self.highlightThePassage(on: try await fixture.page(), store: fixture.users.store, for: "bob")
        let bobs = try await ResearchRoutes.unreviewedChanges(for: "bob", store: fixture.users.store, provider: fixture.provider,
                                                             reviews: UpdateReviewSources(indexer: fixture.indexer, teiCheck: nil))
        #expect(bobs.unreviewed.keys.sorted() == ["frus1894Nicaragua/d2"])
        let owners = try await ResearchRoutes.unreviewedChanges(for: "owner", store: fixture.users.store, provider: fixture.provider,
                                                               reviews: UpdateReviewSources(indexer: fixture.indexer, teiCheck: nil))
        #expect(owners.unreviewed.isEmpty)
        // The index's stamp keeps it out of the tallies, as the kit's `VolumeUpdateReview` counts it, while bob sees it.
        try await fixture.app.test(.router) { client in
            let tallies = try decode(AdminUpdates.self, try await Browser(client: client).get("/api/v1/admin/library/updates"))
            #expect(tallies.totals == .init(changedDocuments: 0, volumes: 0, annotatedDocuments: 0))
        }
    }

    /// A download whose re-index a stop cut short: the volume is owed in the stamps from before its file took its
    /// place, so the next start's indexing indexes it again and stamps the change.
    @Test func aCorrectedFileAStopLeftIsIndexedAgainAtTheNextStart() async throws {
        let fixture = try await Standalone()
        defer { withExtendedLifetime(fixture) {} }
        _ = try await fixture.indexer.index(.asked(nil), requestedBy: nil)
        await fixture.users.jobs.waitUntilIdle()
        // As a download's, the file replaced after the volume is owed, and no job after it.
        fixture.indexer.oweReindex(Self.volume)
        try Self.corrected().write(to: fixture.users.server.files.volumesDirectory.appendingPathComponent("\(Self.volume).xml"))
        let files = fixture.users.server.files
        let next = LibraryIndexer(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory, mode: .standalone,
                                  resources: fixture.resources.indexing, jobs: fixture.users.jobs, state: fixture.users.server.state,
                                  observer: ServedIndexWriting(state: fixture.users.server.state, provider: fixture.provider, log: { _ in }),
                                  capacity: { .max })
        #expect(next.owesReindex(Self.volume), "read back from the stamps")
        let job = try #require(await next.resumeAtStart())
        #expect(job.kind == .libraryIndex)
        await fixture.users.jobs.waitUntilIdle()
        #expect(!next.owesReindex(Self.volume))
        let served = try #require(try await fixture.provider.servedIfReady())
        #expect(try await served.pipeline.documentRevision(volumeId: Self.volume, documentId: "d2")?.changeKind == "body")
    }

    /// A reset while a corrected file waits for its pass: the volume stays owed through the emptying, and is indexed
    /// with `indexVolume` before the reset's pass over every volume, so that its change is stamped, and kept.
    @Test func aResetKeepsTheChangeOfACorrectedFileThatWaitsForItsPass() async throws {
        let fixture = try await Standalone()
        defer { withExtendedLifetime(fixture) {} }
        _ = try await fixture.indexer.index(.asked(nil), requestedBy: nil)
        await fixture.users.jobs.waitUntilIdle()
        fixture.indexer.oweReindex(Self.volume)
        try Self.corrected().write(to: fixture.users.server.files.volumesDirectory.appendingPathComponent("\(Self.volume).xml"))
        _ = try await fixture.indexer.reset(requestedBy: nil)
        await fixture.users.jobs.waitUntilIdle()
        #expect(!fixture.indexer.owesReindex(Self.volume))
        let served = try #require(try await fixture.provider.servedIfReady())
        let revision = try #require(try await served.pipeline.documentRevision(volumeId: Self.volume, documentId: "d2"))
        #expect(revision.changeKind == "body" && revision.changedAt != nil, "\(revision)")
        #expect(try await served.pipeline.unreviewedDocumentRevisions().map(\.documentId) == ["d2"])
    }

    /// The index records a change as reviewed once every user whose research is on the document has reviewed it, so
    /// that one user's review never tells another, at the next correction, that the text did not change.
    @Test func theIndexRecordsAReviewOnceEveryoneConcernedHasMadeIt() async throws {
        let users = try await UserDataFixture()
        defer { withExtendedLifetime(users) {} }
        let store = users.store
        _ = try store.signedInUser("bob", at: UserDataFixture.now)
        _ = try store.signedInUser("carol", at: UserDataFixture.now)
        for user in ["owner", "bob"] {
            _ = try store.createHighlight(in: Self.document, start: 0, end: 5, colorTag: "yellow", selectedText: "words",
                                          renderingVersion: "0000000000000001", for: user, at: UserDataFixture.now)
        }
        _ = try store.recordDocumentReview(of: Self.document, contentHash: "c1", changeKind: "body", for: "owner", at: UserDataFixture.now)
        // Carol, who has no research on it, reviewed it too: hers counts for nothing.
        _ = try store.recordDocumentReview(of: Self.document, contentHash: "c1", changeKind: "body", for: "carol", at: UserDataFixture.now)
        #expect(try await ReviewRoutes.settledReviews(store: store).isEmpty, "bob, whose highlight is on it, has not reviewed it")
        _ = try store.recordDocumentReview(of: Self.document, contentHash: "c1", changeKind: "apparatus", for: "bob", at: UserDataFixture.now)
        #expect(try await ReviewRoutes.settledReviews(store: store).isEmpty, "bob reviewed another change")
        _ = try store.recordDocumentReview(of: Self.document, contentHash: "c1", changeKind: "body", for: "bob", at: UserDataFixture.now)
        let settled = try await ReviewRoutes.settledReviews(store: store)
        #expect(settled == [AnnotationReviewData(annotationType: "document", volumeId: Self.volume, documentId: "d2",
                                                 contentHash: "c1", changeKind: "body")])
    }

    /// Import mode's step 5: the served export compared with the mounted TEI, the document whose TEI changed found,
    /// the banner and the sheet reading it as they read an update's, and Mark Reviewed recording the user's review
    /// alone, the served index, the Mac's, never written.
    @Test func importModesComparisonWithTheTEIFindsTheChangedDocument() async throws {
        let users = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(users) {} }
        let files = users.server.files
        try await Self.buildIndex(of: [Self.volume], from: RepositoryFiles.tei, at: files.liveIndex, resources: users.server.resources)
        await users.server.state.openExistingIndex(files: files)
        let served = try #require(await users.server.state.index)
        let indexBytes = try Data(contentsOf: files.liveIndex)
        // The highlight made on the page the Mac's TEI rendered, then the TEI folder given the corrected volume.
        let reader = ReaderService(volumesDirectory: files.volumesDirectory, resources: users.server.resources)
        let provider = ServedIndexProvider(state: users.server.state, resources: users.server.resources,
                                           volumesDirectory: files.volumesDirectory, userStore: users.store.searchDatabase)
        let page = { try await HighlightRoutes.page(of: Self.document, reader: reader, provider: provider, resources: users.server.resources) }
        let highlight = try Self.highlightThePassage(on: try await page(), store: users.store)
        // Bob's research is on the document too, so Administration's tallies wait for his review as well as the owner's.
        _ = try users.store.signedInUser("bob", at: UserDataFixture.now)
        _ = try Self.highlightThePassage(on: try await page(), store: users.store, for: "bob")
        try FileManager.default.removeItem(at: files.volumesDirectory.appendingPathComponent("\(Self.volume).xml"))
        try Self.corrected().write(to: files.volumesDirectory.appendingPathComponent("\(Self.volume).xml"))

        let check = TEIChangeCheck(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory,
                                   folder: files.root.appendingPathComponent("tei-check"),
                                   resources: users.server.resources.indexing, state: users.server.state, jobs: users.jobs)
        await check.ensureCurrent()
        await users.jobs.waitUntilIdle()
        let status = await check.status()
        #expect(!status.running && status.problem == nil)
        #expect(status.record?.checked == [Self.volume] && status.record?.changed == [Self.volume], "\(String(describing: status.record))")
        #expect(status.record?.describes(served) == true)
        let comparison = try #require(await check.comparison())
        let changed = try await comparison.pipeline.unreviewedDocumentRevisions()
        #expect(changed.map(\.documentId) == ["d2"] && changed.first?.changeKind == "body")
        let comparisons = await users.jobs.jobs().filter { $0.kind == .teiComparison }
        #expect(comparisons.map(\.state) == [.succeeded], "a job of the queue")
        #expect(comparisons.first?.progress == "Compared 1 of the index's 1 volumes with the TEI folder: 1 with a document whose TEI changed after the export was indexed")
        // Once for the index served while its files stay as they were compared: a second look queues nothing, and a
        // new start reads the record.
        await check.ensureCurrent()
        let looked = await check.status()
        #expect(looked.record == status.record && !looked.running)
        let again = TEIChangeCheck(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory,
                                   folder: files.root.appendingPathComponent("tei-check"),
                                   resources: users.server.resources.indexing, state: users.server.state, jobs: users.jobs)
        await again.ensureCurrent()
        let read = await again.status()
        #expect(read.record == status.record && !read.running)
        let afterwards = await users.jobs.jobs().filter { $0.kind == .teiComparison }
        #expect(afterwards.count == 1)

        let reviews = UpdateReviewSources(indexer: nil, teiCheck: check)
        let app = Application(router: ServedRouter(base: .root, router: buildRouter(
            state: users.server.state, resources: users.server.resources, reader: reader, provider: provider,
            userData: users.services, teiCheck: check)))
        try await app.test(.router) { client in
            let owner = Browser(client: client)
            let banner = try decode(DocumentChange.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d2/change"))
            #expect(banner.line == "The text of this document changed in a volume update. Some highlights may be misaligned.")
            #expect(banner.foundInTEI && banner.canMarkReviewed)
            let sheet = try decode(DocumentReview.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d2/review"))
            #expect(sheet.highlights.first?.search == "moved" && sheet.highlights.first?.canMove == true)
            #expect(try decode(ResearchPage.self, try await owner.get("/api/v1/me/research")).updated == 1)
            let tallies = try decode(AdminUpdates.self, try await owner.get("/api/v1/admin/library/updates"))
            #expect(tallies.mode == "import" && tallies.totals == .init(changedDocuments: 1, volumes: 1, annotatedDocuments: 1))
            #expect(tallies.volumes.first?.body == 1 && tallies.teiCheck?.changed == [Self.volume] && tallies.teiCheck?.running == false)
            let reviewed = try decode(DocumentChange.self, try await owner.send(
                .post, "/api/v1/me/volumes/\(Self.volume)/documents/d2/review",
                #"{"contentHash":"\#(banner.contentHash ?? "")","changeKind":"body"}"#))
            #expect(!reviewed.canMarkReviewed && reviewed.line == "Some highlights may be misaligned — the document has been updated since they were created.")
            #expect(try decode(ResearchPage.self, try await owner.get("/api/v1/me/research")).updated == 0)
            // The tallies, by the rule a Standalone server stamps its index by: the change waits for everyone whose
            // research is on the document, by their ledgers, since this index is never written.
            let waiting = try decode(AdminUpdates.self, try await owner.get("/api/v1/admin/library/updates"))
            #expect(waiting.totals == .init(changedDocuments: 1, volumes: 1, annotatedDocuments: 1), "bob has not reviewed it")
            _ = try users.store.recordDocumentReview(of: Self.document, contentHash: banner.contentHash ?? "", changeKind: "body",
                                                     for: "bob", at: UserDataFixture.now)
            let settled = try decode(AdminUpdates.self, try await owner.get("/api/v1/admin/library/updates"))
            #expect(settled.totals == .init(changedDocuments: 0, volumes: 0, annotatedDocuments: 0) && settled.volumes.isEmpty)
            // Someone new annotates it, and it counts again, since this index holds no stamp of it, where a Standalone
            // server's would keep it out; an account disabled, which can review nothing, waits on no review.
            _ = try users.store.signedInUser("carol", at: UserDataFixture.now)
            _ = try users.store.createHighlight(in: Self.document, start: 0, end: 5, colorTag: "yellow", selectedText: "words",
                                                renderingVersion: "0000000000000001", for: "carol", at: UserDataFixture.now)
            let again = try decode(AdminUpdates.self, try await owner.get("/api/v1/admin/library/updates"))
            #expect(again.totals == .init(changedDocuments: 1, volumes: 1, annotatedDocuments: 1), "carol has not reviewed it")
            try users.store.setDisabled(true, of: "carol", at: UserDataFixture.now)
            let disabled = try decode(AdminUpdates.self, try await owner.get("/api/v1/admin/library/updates"))
            #expect(disabled.totals == .init(changedDocuments: 0, volumes: 0, annotatedDocuments: 0))
        }
        _ = reviews
        await users.jobs.waitUntilIdle()
        #expect(try Data(contentsOf: files.liveIndex) == indexBytes, "the served index, the Mac's, is never written")
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.liveIndex.deletingLastPathComponent().path).sorted() == ["frus.db"],
                "nor its folder")
        #expect(try users.store.documentReviews(of: Self.document, for: "owner").count == 1)
        _ = highlight
    }

    /// An export whose change its reader reviewed on the Mac, the index's stamp brought with it: Administration's tallies
    /// leave it out, as the kit's `VolumeUpdateReview` and the app's After an Update do, whoever reviews it on the server;
    /// a user of the server still sees the change, their own ledger holding no review of it.
    @Test func anExportsReviewedChangeIsLeftOutOfTheTalliesAndShownToEachUser() async throws {
        let users = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(users) {} }
        let files = users.server.files
        // The Mac's index: the volume as first published, then corrected and indexed again, its change reviewed there.
        try await Self.buildIndex(of: [Self.volume], from: RepositoryFiles.tei, at: files.liveIndex, resources: users.server.resources)
        let corrected = try TemporaryDirectory()
        try Self.corrected().write(to: corrected.url.appendingPathComponent("\(Self.volume).xml"))
        do {
            let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: files.liveIndex), databaseURL: files.liveIndex,
                                                volumesDirectory: corrected.url, resources: users.server.resources.indexing,
                                                defaults: InMemoryIndexingStampStore())
            try await pipeline.indexVolume(Self.volume)
            let change = try #require(try await pipeline.documentRevision(volumeId: Self.volume, documentId: "d2"))
            #expect(change.changeKind == "body")
            _ = try await pipeline.applyAnnotationReviews([AnnotationReviewData(
                annotationType: AnnotationReviewLedger.documentKind, volumeId: Self.volume, documentId: "d2",
                contentHash: change.contentHash, changeKind: "body")])
        }
        let db = try SQLiteConnection(files.liveIndex.path, readOnly: false)
        _ = try db.query("PRAGMA wal_checkpoint(TRUNCATE)")
        _ = try db.query("PRAGMA journal_mode=DELETE")
        db.close()
        // The TEI folder holds the volume the Mac indexed last.
        try FileManager.default.removeItem(at: files.volumesDirectory.appendingPathComponent("\(Self.volume).xml"))
        try Self.corrected().write(to: files.volumesDirectory.appendingPathComponent("\(Self.volume).xml"))
        await users.server.state.openExistingIndex(files: files)
        let served = try #require(await users.server.state.index)
        #expect(served.summary.documents > 0)
        let reader = ReaderService(volumesDirectory: files.volumesDirectory, resources: users.server.resources)
        let provider = ServedIndexProvider(state: users.server.state, resources: users.server.resources,
                                           volumesDirectory: files.volumesDirectory, userStore: users.store.searchDatabase)
        _ = try users.store.signedInUser("bob", at: UserDataFixture.now)
        for user in ["owner", "bob"] {
            _ = try users.store.createHighlight(in: Self.document, start: 0, end: 5, colorTag: "yellow", selectedText: "words",
                                                renderingVersion: "0000000000000001", for: user, at: UserDataFixture.now)
        }
        let app = Application(router: ServedRouter(base: .root, router: buildRouter(
            state: users.server.state, resources: users.server.resources, reader: reader, provider: provider,
            userData: users.services)))
        try await app.test(.router) { client in
            let owner = Browser(client: client)
            let left = try decode(AdminUpdates.self, try await owner.get("/api/v1/admin/library/updates"))
            #expect(left.totals == .init(changedDocuments: 0, volumes: 0, annotatedDocuments: 0), "the Mac's reader reviewed it")
            let banner = try decode(DocumentChange.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d2/change"))
            #expect(banner.changeKind == "body" && banner.canMarkReviewed, "the owner's own ledger holds no review of it")
            // The owner reviews it, and bob, whose research is on it too, still has it to review.
            let reviewed = try decode(DocumentChange.self, try await owner.send(
                .post, "/api/v1/me/volumes/\(Self.volume)/documents/d2/review",
                #"{"contentHash":"\#(banner.contentHash ?? "")","changeKind":"body"}"#))
            #expect(!reviewed.canMarkReviewed && reviewed.changeKind == nil)
            let bobs = try await ResearchRoutes.unreviewedChanges(for: "bob", store: users.store, provider: provider,
                                                                 reviews: UpdateReviewSources(indexer: nil, teiCheck: nil))
            #expect(bobs.unreviewed.keys.sorted() == ["frus1894Nicaragua/d2"])
            let still = try decode(AdminUpdates.self, try await owner.get("/api/v1/admin/library/updates"))
            #expect(still.totals == .init(changedDocuments: 0, volumes: 0, annotatedDocuments: 0))
        }
    }

    /// An index of `volumes`, built by the kit's read-write pipeline from `tei`, as the Mac's export holds one, with
    /// no log beside it.
    static func buildIndex(of volumes: [String], from tei: URL, at url: URL, resources: ServerResources) async throws {
        do {
            let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: url), databaseURL: url, volumesDirectory: tei,
                                                resources: resources.indexing, defaults: InMemoryIndexingStampStore())
            for volume in volumes { try await pipeline.indexVolume(volume) }
            await pipeline.runPostIndexPasses()
        }
        let db = try SQLiteConnection(url.path, readOnly: false)
        defer { db.close() }
        _ = try db.query("PRAGMA wal_checkpoint(TRUNCATE)")
        _ = try db.query("PRAGMA journal_mode=DELETE")
    }
}
