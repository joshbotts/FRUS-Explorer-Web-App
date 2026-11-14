// A curator's corrections (PLAN's S21g), through the router. On a Standalone server a document's classification
// corrected shows at once in search, its document-type facet and the reader, and restored goes back; a merge and a
// separation of people give the served rollup the kit builds with them over the same index, and undone give it
// back; the indexing and the pass over every volume keep the corrections, where S21d's dropped them. On an Import
// server a correction is kept, the served export left as it is, and given to the next export it installs. A reader is
// refused every correction, and the log names each one, who made it and when.

@testable import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import FTS5Store
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite(.timeLimit(.minutes(5))) struct CorrectionRouteTests {
    static let volume = "frus1961-63v06"
    /// A word of d1's alone, Khrushchev's congratulations to the President-elect, a document.
    static let word = "deliverance"

    /// A Standalone server keeping user data, the fixture volume indexed from its library with the corrections the
    /// store keeps, as the server wires them.
    struct Standalone {
        let users: UserDataFixture
        let indexer: LibraryIndexer
        let provider: ServedIndexProvider
        let resources: ServerResources
        let reader: ReaderService

        init(auth: ServerConfiguration.Auth = .none, adminUsers: Set<String> = []) async throws {
            users = try await UserDataFixture(auth: auth, trustedProxies: auth == .header ? SignInTests.loopback : [], adminUsers: adminUsers)
            let files = users.server.files
            try RepositoryFiles.mountTEI([CorrectionRouteTests.volume], at: files.volumesDirectory)
            resources = users.server.resources
            reader = ReaderService(volumesDirectory: files.volumesDirectory, resources: resources)
            let state = users.server.state
            provider = ServedIndexProvider(state: state, resources: resources, volumesDirectory: files.volumesDirectory,
                                           userStore: users.store.searchDatabase)
            indexer = LibraryIndexer(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory, mode: .standalone,
                                     resources: resources.indexing, jobs: users.jobs, state: state,
                                     observer: ServedIndexWriting(state: state, provider: provider, log: { _ in }), capacity: { .max },
                                     corrections: IndexCorrections(store: users.store, volumesDirectory: files.volumesDirectory))
        }

        var app: some ApplicationProtocol {
            Application(router: ServedRouter(base: .root, router: buildRouter(
                state: users.server.state, resources: resources, reader: reader, provider: provider,
                userData: users.services, indexer: indexer)))
        }

        func indexed() async throws -> Standalone {
            _ = try await indexer.index(.asked(nil), requestedBy: nil)
            await users.jobs.waitUntilIdle()
            #expect(await users.server.state.index != nil, "the volume indexed and served")
            return self
        }
    }

    // MARK: What a correction shows

    /// The document's search under each document type, its type facet and its page, as a reader sees them.
    struct Seen: Equatable {
        let asNote: [String]
        let asDocument: [String]
        let facet: [String: Int]
        let styledAsNote: Bool
    }

    static func seen(_ owner: Browser, _ documentId: String = "d1") async throws -> Seen {
        func ids(_ type: String) async throws -> [String] {
            try decode(SearchResultList.self, try await owner.get("/api/v1/search?keywords=\(word)&documentType=\(type)")).items.map(\.documentId)
        }
        let facet = try decode(SearchFacetSection.self, try await owner.get("/api/v1/search/facets?keywords=\(word)&section=documentType"))
        let page = try await owner.get("/api/v1/volumes/\(volume)/documents/\(documentId)/html?part=body")
        return Seen(asNote: try await ids("editorialNotesOnly"), asDocument: try await ids("documentsOnly"),
                    facet: Dictionary(uniqueKeysWithValues: facet.rows.map { ($0.key, $0.count) }),
                    styledAsNote: String(buffer: page.body).contains(#"<div class="editorial-note" role="note">"#))
    }

    static let asDocument = Seen(asNote: [], asDocument: ["d1"], facet: ["0": 1], styledAsNote: false)
    static let asNote = Seen(asNote: ["d1"], asDocument: [], facet: ["1": 1], styledAsNote: true)

    /// The done-when, in Swift: a curator's classification shows in search, the facet and the reader at once on a
    /// Standalone index, and its restore puts FRUS's back; the log names both.
    @Test func aClassificationShowsAtOnceOnAStandaloneIndex() async throws {
        let fixture = try await Standalone().indexed()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await Self.seen(owner) == Self.asDocument)
            let before = try decode(DocumentClassification.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/classification"))
            #expect(before == DocumentClassification(indexed: true, isEditorialNote: false, parsedIsEditorialNote: false, correction: nil,
                                                     waiting: nil, canCorrect: true, mode: "standalone"))

            // Reclassify as Editorial Note…: applied by the one writer's job before the request answers.
            let made = try await owner.send(.put, "/api/v1/me/volumes/\(Self.volume)/documents/d1/classification", #"{"isEditorialNote":true}"#)
            #expect(made.status == .ok)
            #expect(try decode(CorrectionOutcome.self, made).state == "applied")
            #expect(try await Self.seen(owner) == Self.asNote)
            let after = try decode(DocumentClassification.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/classification"))
            #expect(after.isEditorialNote == true && after.parsedIsEditorialNote == false && after.waiting == nil)
            #expect(after.correction?.isEditorialNote == true && after.correction?.madeBy == "Owner")
            let jobs = await fixture.users.jobs.jobs().filter { $0.kind == .indexCorrections }
            #expect(jobs.map(\.state) == [.succeeded] && jobs.first?.requestedBy == "owner")
            // The app offers only the restore while a correction is kept, and refuses what the index has already.
            #expect(problemCode(try await owner.send(.put, "/api/v1/me/volumes/\(Self.volume)/documents/d1/classification",
                                                    #"{"isEditorialNote":false}"#)) == "CORRECTION_EXISTS")
            #expect(problemCode(try await owner.send(.put, "/api/v1/me/volumes/\(Self.volume)/documents/d2/classification",
                                                    #"{"isEditorialNote":false}"#)) == "CLASSIFICATION_UNCHANGED")
            #expect(problemCode(try await owner.send(.put, "/api/v1/me/volumes/\(Self.volume)/documents/d999/classification",
                                                    #"{"isEditorialNote":true}"#)) == "DOCUMENT_NOT_INDEXED")

            // Restore FRUS's Classification: the TEI's parse back, everywhere.
            let restored = try await owner.send(.delete, "/api/v1/me/volumes/\(Self.volume)/documents/d1/classification")
            #expect(try decode(CorrectionOutcome.self, restored).state == "applied")
            #expect(try await Self.seen(owner) == Self.asDocument)
            #expect(problemCode(try await owner.send(.delete, "/api/v1/me/volumes/\(Self.volume)/documents/d1/classification")) == "CORRECTION_NOT_FOUND")
            #expect(try fixture.users.store.classificationOverrides().isEmpty)

            // The log names each, who and when, each taken by the index.
            let log = try decode(CorrectionLogList.self, try await owner.get("/api/v1/admin/corrections")).entries
            #expect(log.map(\.action) == ["undone", "made"] && log.allSatisfy { $0.correction == "classification" })
            #expect(log.allSatisfy { $0.userId == "owner" && $0.userName == "Owner" && $0.appliedAt != nil && $0.documentId == "d1" })
            #expect(log.last?.isEditorialNote == true && log.first?.isEditorialNote == false, "the correction, then FRUS's value restored")
            #expect(log.map(\.madeAt) == log.map(\.madeAt).sorted(by: >) || log.first?.madeAt == log.last?.madeAt)
        }
    }

    /// An editorial note reclassified as a document, the other way round, and a correction the indexing keeps: a pass of
    /// `indexVolume` over the volume and the kit's pass over every volume both restore the parsed value, which every
    /// writer gives the correction again over.
    @Test func theIndexingKeepsAClassification() async throws {
        let fixture = try await Standalone().indexed()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let made = try await owner.send(.put, "/api/v1/me/volumes/\(Self.volume)/documents/d20/classification", #"{"isEditorialNote":false}"#)
            #expect(try decode(CorrectionOutcome.self, made).state == "applied")
            func effective() async throws -> Bool? {
                try decode(DocumentClassification.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d20/classification"))
                    .isEditorialNote
            }
            #expect(try await effective() == false)
            // The volume indexed again from its file, as an Update does.
            #expect(fixture.indexer.oweReindex(Self.volume))
            _ = try await fixture.indexer.index(.asked([Self.volume]), requestedBy: nil)
            await fixture.users.jobs.waitUntilIdle()
            #expect(!fixture.indexer.owesReindex(Self.volume))
            #expect(try await effective() == false, "replayed after indexVolume")
            // Standalone's reset: the index emptied and the pass over every volume.
            _ = try await fixture.indexer.reset(requestedBy: nil)
            await fixture.users.jobs.waitUntilIdle()
            await fixture.users.jobs.waitUntilIdle()
            #expect(try await effective() == false, "given again after the pass over every volume")
        }
    }

    // MARK: People

    /// The rollup a served index holds: each identity's records, by volume and ref.
    static func identities(_ url: URL) throws -> Set<Set<String>> {
        let db = try SQLiteConnection(FTS5Store.readOnlyURI(for: url), readOnly: true)
        defer { db.close() }
        var groups: [Int64: Set<String>] = [:]
        for row in try db.query("SELECT volume_id, ref, rollup_id FROM person_rollup_member") {
            groups[row[2].integer ?? 0, default: []].insert("\(row[0].text ?? "")/\(row[1].text ?? "")")
        }
        return Set(groups.values)
    }

    /// The rollup the kit builds over a copy of `index` with `overrides`, as the app's live correction builds it.
    static func kitsRollup(over index: URL, with overrides: [PersonClusterOverrideData], resources: ServerResources) async throws -> Set<Set<String>> {
        let directory = try TemporaryDirectory()
        let copy = directory.url.appendingPathComponent("copy.db")
        try FileManager.default.copyItem(at: index, to: copy)
        do {
            let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: copy), databaseURL: copy,
                                                volumesDirectory: directory.url, resources: resources.indexing,
                                                defaults: InMemoryIndexingStampStore())
            try await pipeline.consolidatePersonRollup(overrides: overrides, forceReload: false)
        }
        let groups = try identities(copy)
        withExtendedLifetime(directory) {}
        return groups
    }

    /// The people's list, and the row whose name begins so.
    static func person(_ prefix: String, in list: PeopleList) throws -> PersonRow {
        try #require(list.sections.flatMap(\.people).first { $0.name.hasPrefix(prefix) }, "\(prefix) in the list")
    }

    /// The done-when, in Swift: a merge and a separation through the People screen's routes give the served rollup the
    /// kit builds over the same index with the same corrections, as the app's live correction builds it, and each
    /// undone gives back the rollup before it.
    @Test func aMergeAndASeparationGiveTheKitsRollup() async throws {
        let fixture = try await Standalone().indexed()
        defer { withExtendedLifetime(fixture) {} }
        let live = fixture.users.server.files.liveIndex
        let directory = try TemporaryDirectory()
        let before = directory.url.appendingPathComponent("before.db")
        try FileManager.default.copyItem(at: live, to: before)
        let original = try Self.identities(before)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let list = try decode(PeopleList.self, try await owner.get("/api/v1/people"))
            #expect(list.count == list.sections.reduce(0) { $0 + $1.people.count } && list.count == original.count)
            let adenauer = try Self.person("Adenauer", in: list)
            let adzhubei = try Self.person("Adzhubei", in: list)

            // Merge: the two by their representative records, the rollup built again by the job before the answer.
            let merged = try await owner.send(.post, "/api/v1/me/people/merges",
                                              #"{"rollupId":\#(adenauer.rollupId),"otherRollupId":\#(adzhubei.rollupId),"version":"\#(list.version)"}"#)
            #expect(merged.status == .ok)
            #expect(try decode(CorrectionOutcome.self, merged).state == "applied")
            let overrides = try fixture.users.store.personOverrides()
            #expect(overrides.count == 1 && overrides.first?.kind == .merge)
            let afterMerge = try Self.identities(live)
            #expect(afterMerge == (try await Self.kitsRollup(over: before, with: overrides.map(\.data), resources: fixture.resources)))
            #expect(afterMerge.count == original.count - 1)
            let union = try #require(afterMerge.first { $0.contains("\(Self.volume)/p_AK3") })
            #expect(union.contains("\(Self.volume)/p_AAI1"), "one identity now")

            // The page's list is from the rollup before: its numbers may name others now.
            #expect(problemCode(try await owner.send(.post, "/api/v1/me/people/merges",
                                                    #"{"rollupId":\#(adenauer.rollupId),"otherRollupId":\#(adzhubei.rollupId),"version":"\#(list.version)"}"#))
                    == "PEOPLE_CHANGED")

            // The merged identity's sheet, then Separate of Adzhubei's record.
            let fresh = try decode(PeopleList.self, try await owner.get("/api/v1/people"))
            #expect(fresh.version != list.version && fresh.count == list.count - 1)
            let identity = try #require(fresh.sections.flatMap(\.people).first { row in
                row.name.hasPrefix("Adenauer") || row.name.hasPrefix("Adzhubei")
            })
            let sheet = try decode(PersonSheet.self, try await owner.get("/api/v1/people/\(identity.rollupId)"))
            #expect(Set(sheet.records.map(\.ref)) == ["p_AK3", "p_AAI1"] && sheet.version == fresh.version)
            #expect(problemCode(try await owner.send(.post, "/api/v1/me/people/merges",
                                                    #"{"rollupId":\#(identity.rollupId),"otherRollupId":\#(identity.rollupId),"version":"\#(fresh.version)"}"#))
                    == "INVALID_FIELD")
            let separated = try await owner.send(.post, "/api/v1/me/people/separations",
                                                 #"{"rollupId":\#(identity.rollupId),"volumeId":"\#(Self.volume)","ref":"p_AAI1","version":"\#(fresh.version)"}"#)
            #expect(try decode(CorrectionOutcome.self, separated).state == "applied")
            let both = try fixture.users.store.personOverrides()
            #expect(both.map(\.kind) == [.split, .merge], "newest first, as the app's snapshot gives them")
            let afterSplit = try Self.identities(live)
            #expect(afterSplit == (try await Self.kitsRollup(over: before, with: both.map(\.data), resources: fixture.resources)))
            #expect(afterSplit.contains(["\(Self.volume)/p_AAI1"]), "Adzhubei's record a person of its own")

            // Corrections: the sheet's two rows, newest first, by name; Undo of each, the rollup back each time.
            let rows = try decode(PersonCorrectionList.self, try await owner.get("/api/v1/me/people/corrections"))
            #expect(rows.items.map(\.kind) == ["split", "merge"] && rows.items.allSatisfy { $0.applied && $0.madeBy == "Owner" })
            #expect(rows.items.last?.nameA.hasPrefix("Adenauer") == true && rows.items.last?.nameB?.hasPrefix("Adzhubei") == true)
            #expect(rows.mode == "standalone")
            let split = try #require(rows.items.first?.id)
            #expect(try decode(CorrectionOutcome.self, try await owner.send(.delete, "/api/v1/me/people/corrections/\(split)")).state == "applied")
            #expect(try Self.identities(live) == afterMerge)
            #expect(problemCode(try await owner.send(.delete, "/api/v1/me/people/corrections/\(split)")) == "CORRECTION_NOT_FOUND")
            let merge = try #require(rows.items.last?.id)
            #expect(try decode(CorrectionOutcome.self, try await owner.send(.delete, "/api/v1/me/people/corrections/\(merge)")).state == "applied")
            #expect(try Self.identities(live) == original, "every correction undone: the rollup the index had")

            // The log names the four, newest first.
            let log = try decode(CorrectionLogList.self, try await owner.get("/api/v1/admin/corrections")).entries
            #expect(log.map { "\($0.action) \($0.kind ?? "")" } == ["undone merge", "undone split", "made split", "made merge"])
            #expect(log.allSatisfy { $0.correction == "person" && $0.userId == "owner" && $0.appliedAt != nil })
            #expect(log.last?.refA != nil && log.last?.refB != nil)
        }
        withExtendedLifetime(directory) {}
    }

    /// A merge the indexing's passes keep: the reset's pass over every volume rebuilds the rollup, with the corrections.
    @Test func thePassOverEveryVolumeKeepsAMerge() async throws {
        let fixture = try await Standalone().indexed()
        defer { withExtendedLifetime(fixture) {} }
        let live = fixture.users.server.files.liveIndex
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let list = try decode(PeopleList.self, try await owner.get("/api/v1/people"))
            let adenauer = try Self.person("Adenauer", in: list)
            let adzhubei = try Self.person("Adzhubei", in: list)
            _ = try await owner.send(.post, "/api/v1/me/people/merges",
                                     #"{"rollupId":\#(adenauer.rollupId),"otherRollupId":\#(adzhubei.rollupId),"version":"\#(list.version)"}"#)
            let merged = try Self.identities(live)
            _ = try await fixture.indexer.reset(requestedBy: nil)
            await fixture.users.jobs.waitUntilIdle()
            await fixture.users.jobs.waitUntilIdle()
            #expect(try Self.identities(live) == merged, "rebuilt with the merge, where S21d's passes rebuilt it with none")
        }
    }

    /// A correction a stop left waiting, its job never run, is applied by the next start's.
    @Test func aCorrectionAStopLeftWaitingIsAppliedAtTheNextStart() async throws {
        let fixture = try await Standalone().indexed()
        defer { withExtendedLifetime(fixture) {} }
        _ = try fixture.users.store.recordClassification(
            ClassificationOverride(volumeId: Self.volume, documentId: "d1", isEditorialNote: true, parsedIsEditorialNote: false),
            by: "owner", at: UserDataFixture.now)
        #expect(try fixture.users.store.waitingCorrections().count == 1)
        #expect(await fixture.indexer.resumeCorrectionsAtStart() != nil)
        await fixture.users.jobs.waitUntilIdle()
        #expect(try fixture.users.store.waitingCorrections().isEmpty)
        try await fixture.app.test(.router) { client in
            #expect(try await Self.seen(Browser(client: client)) == Self.asNote)
        }
        #expect(await fixture.indexer.resumeCorrectionsAtStart() == nil, "nothing waits")
    }

    // MARK: Import mode

    /// The done-when's other half: on an Import server a correction is kept, the export served as the Mac made it,
    /// and the next export the server installs is given it before it is served.
    @Test func anImportServerGivesTheNextExportItsCorrections() async throws {
        let users = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(users) {} }
        let files = users.server.files
        let export = files.root.appendingPathComponent("frus-export.sqlite")
        try await UpdateReviewTests.buildIndex(of: [Self.volume], from: RepositoryFiles.tei, at: export, resources: users.server.resources)
        let exported = try Data(contentsOf: export)
        try FileManager.default.copyItem(at: export, to: files.liveIndex)
        await users.server.state.openExistingIndex(files: files)
        let served = try Data(contentsOf: files.liveIndex)
        let original = try Self.identities(files.liveIndex)
        try await users.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await Self.seen(owner) == Self.asDocument)
            let made = try await owner.send(.put, "/api/v1/me/volumes/\(Self.volume)/documents/d1/classification", #"{"isEditorialNote":true}"#)
            #expect(try decode(CorrectionOutcome.self, made).state == "nextExport")
            let kept = try decode(DocumentClassification.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/classification"))
            #expect(kept.isEditorialNote == false && kept.correction?.isEditorialNote == true && kept.waiting == "correction" && kept.mode == "import")
            let list = try decode(PeopleList.self, try await owner.get("/api/v1/people"))
            let merge = try await owner.send(.post, "/api/v1/me/people/merges",
                                             #"{"rollupId":\#(try Self.person("Adenauer", in: list).rollupId),"otherRollupId":\#(try Self.person("Adzhubei", in: list).rollupId),"version":"\#(list.version)"}"#)
            #expect(try decode(CorrectionOutcome.self, merge).state == "nextExport")
            // The export served is the Mac's, written by nothing.
            #expect(try await Self.seen(owner) == Self.asDocument)
            #expect(try decode(PeopleList.self, try await owner.get("/api/v1/people")).version == list.version)
            #expect(try Data(contentsOf: files.liveIndex) == served)
            let rows = try decode(PersonCorrectionList.self, try await owner.get("/api/v1/me/people/corrections"))
            #expect(rows.items.map(\.applied) == [false] && rows.mode == "import")
        }
        #expect(await users.jobs.jobs().allSatisfy { $0.kind != .indexCorrections }, "no job writes an Import server's index")

        // The next export installed, as the import's job installs one.
        let recorder = WritingStepRecorder()
        let importer = IndexImporter(files: files, writer: LocalIndexWriter(files: files),
                                     corrections: IndexCorrectionReplay(corrections: IndexCorrections(store: users.store, volumesDirectory: files.volumesDirectory),
                                                                        resources: users.server.resources.indexing))
        let imported = try await importer.importExport(at: export, observer: recorder)
        _ = await users.server.state.importFinished(file: export.lastPathComponent, index: imported.index)
        #expect(await recorder.steps.contains(.applyingCorrections))
        #expect(!imported.index.isLive, "served immutable, as Import mode serves an export")
        #expect(try Data(contentsOf: export) == exported, "the export itself never written")
        let overrides = try users.store.personOverrides().map(\.data)
        #expect(try Self.identities(files.liveIndex) == (try await Self.kitsRollup(over: export, with: overrides, resources: users.server.resources)))
        #expect(try Self.identities(files.liveIndex).count == original.count - 1)
        try await users.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await Self.seen(owner) == Self.asNote)
            let applied = try decode(DocumentClassification.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/classification"))
            #expect(applied.isEditorialNote == true && applied.waiting == nil)
            let log = try decode(CorrectionLogList.self, try await owner.get("/api/v1/admin/corrections")).entries
            #expect(log.count == 2 && log.allSatisfy { $0.appliedAt != nil }, "each taken by the export installed")
        }
        #expect(try users.store.waitingCorrections().isEmpty)
    }

    /// A restore an Import server keeps stands at each install: an export the Mac made with its own correction of the
    /// document, which it carries again, is given FRUS's classification back, read from the TEI.
    @Test func anImportServersRestoreStandsAtEveryInstall() async throws {
        let users = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(users) {} }
        let files = users.server.files
        let export = files.root.appendingPathComponent("frus-export.sqlite")
        try await UpdateReviewTests.buildIndex(of: [Self.volume], from: RepositoryFiles.tei, at: export, resources: users.server.resources)
        // The Mac's own correction of d1, in its export and in the research a curator imported.
        do {
            let db = try SQLiteConnection(export.path, readOnly: false)
            defer { db.close() }
            _ = try db.query("UPDATE document_cache SET is_editorial_note = 1 WHERE volume_id = ? AND document_id = 'd1'", [.text(Self.volume)])
        }
        _ = try users.store.record(ClassificationOverride(volumeId: Self.volume, documentId: "d1", isEditorialNote: true, parsedIsEditorialNote: false))
        try FileManager.default.copyItem(at: export, to: files.liveIndex)
        await users.server.state.openExistingIndex(files: files)
        let replay = IndexCorrectionReplay(corrections: IndexCorrections(store: users.store, volumesDirectory: files.volumesDirectory),
                                           resources: users.server.resources.indexing)
        try await users.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await Self.seen(owner) == Self.asNote, "the Mac's correction, served")
            let restored = try await owner.send(.delete, "/api/v1/me/volumes/\(Self.volume)/documents/d1/classification")
            #expect(try decode(CorrectionOutcome.self, restored).state == "nextExport")
            #expect(try decode(DocumentClassification.self, try await owner.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/classification")).waiting == "restore")
        }
        for _ in 0..<2 {
            let imported = try await IndexImporter(files: files, writer: LocalIndexWriter(files: files), corrections: replay)
                .importExport(at: export, observer: WritingStepRecorder())
            _ = await users.server.state.importFinished(file: export.lastPathComponent, index: imported.index)
            try await users.app.test(.router) { client in
                #expect(try await Self.seen(Browser(client: client)) == Self.asDocument, "FRUS's classification, at each install")
            }
        }
    }

    // MARK: Who may

    /// A reader is refused every correction, before anything is read or written; a curator is not.
    @Test func aReaderIsRefusedEveryCorrection() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume], indexed: true, auth: .header,
                                                trustedProxies: SignInTests.loopback, adminUsers: ["alice"])
        defer { withExtendedLifetime(fixture) {} }
        let writes: [(HTTPRequest.Method, String, String?)] = [
            (.put, "/api/v1/me/volumes/\(Self.volume)/documents/d1/classification", #"{"isEditorialNote":true}"#),
            (.delete, "/api/v1/me/volumes/\(Self.volume)/documents/d1/classification", nil),
            (.post, "/api/v1/me/people/merges", #"{"rollupId":1,"otherRollupId":2,"version":"x"}"#),
            (.post, "/api/v1/me/people/separations", #"{"rollupId":1,"volumeId":"frus1961-63v06","ref":"p_AK3","version":"x"}"#),
            (.get, "/api/v1/me/people/corrections", nil),
            (.delete, "/api/v1/me/people/corrections/5E21G000-0000-4000-8000-000000000001", nil),
        ]
        try await fixture.app.test(.router) { client in
            let bob = Browser(client: client, user: "bob")
            for (method, path, body) in writes {
                let response = method == .get ? try await bob.get(path) : try await bob.send(method, path, body)
                #expect(response.status == .forbidden && problemCode(response) == "ROLE_REQUIRED", "\(method) \(path)")
            }
            let seen = try decode(DocumentClassification.self, try await bob.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/classification"))
            #expect(!seen.canCorrect, "a reader reads it, and corrects nothing")
            let alice = Browser(client: client, user: "alice")
            #expect(try await alice.get("/api/v1/me/people/corrections").status == .ok, "an admin is a curator too")
            #expect(try decode(DocumentClassification.self, try await alice.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/classification")).canCorrect)
        }
        #expect(try fixture.store.correctionLog(limit: 10).isEmpty && fixture.store.personOverrides().isEmpty)
        #expect(try fixture.store.classificationOverrides().isEmpty)
    }
}
