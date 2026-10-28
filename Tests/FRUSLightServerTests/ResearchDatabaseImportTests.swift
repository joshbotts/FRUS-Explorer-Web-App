// Import mode and an export made with the owner's writing (PLAN's S16e), through the server's own
// wiring: the kit's strip, `ResearchDatabaseStrip.steps`, and the user store. The installed index holds
// none of the writing, as scripts/check-stripped-export searches a stripped export, and the store holds
// all of it, marked as from a research database; a second import changes nothing, and a later export
// replaces what an earlier one brought and the reader has not changed; what the user's own records
// hold already is not added again; a refusal still changes nothing, and too little room is asked for
// before anything is copied; and the report says what moved, through /api/v1/status and the user's
// routes, where a summary from a research database can be deleted but not changed.

import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

/// Records each step an import reaches, once per step, and each detail.
actor WritingStepRecorder: ImportObserver {
    private(set) var steps: [ReadinessStep] = []
    private(set) var details: [String] = []

    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) {
        if steps.last != step { steps.append(step) }
        details.append(detail)
    }
}

/// A data directory with a user store, and an importer that keeps the writing as the server's does.
struct WritingImportFixture {
    let directory: TemporaryDirectory
    let files: DataDirectory
    let store: RelationalUserStore
    let rows: UserStoreRows
    let importer: IndexImporter
    /// What holds the PostgreSQL store (S14d), which drops its schema once the test lets it go, or nil
    /// for app.db.
    let postgreSQL: TestUserStore?

    /// `free`, the free space each look at the disk finds in turn, the last for every later one; and
    /// the store the writing goes into, app.db in the data directory or the PostgreSQL store.
    init(free: [Int64]? = nil, kind: UserStoreKind = .sqlite) async throws {
        directory = try TemporaryDirectory()
        let files = DataDirectory(root: directory.url.appendingPathComponent("data"))
        try files.prepare()
        self.files = files
        switch kind {
        case .sqlite:
            store = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
            rows = try UserStoreRows(files.userStore)
            postgreSQL = nil
        case .postgreSQL:
            let test = try await TestUserStore.open(.postgreSQL)
            store = test.store
            rows = test.rows
            postgreSQL = test
        }
        let held: any FileStore = free.map { FreeSpace(base: files, free: $0) } ?? files
        importer = IndexImporter(files: held, writer: LocalIndexWriter(files: held),
                                 writing: ResearchDatabaseImport.move(into: store))
    }

    /// Writes `export` outside the drop zone, to read it beside the installed index, and copies it in.
    func drop(_ export: SyntheticExport, as name: String = "export.sqlite") throws -> (source: URL, dropped: URL) {
        let source = directory.url.appendingPathComponent(name)
        try export.write(to: source)
        return (source, try copyIn(source, as: name))
    }

    func copyIn(_ source: URL, as name: String) throws -> URL {
        let dropped = files.importDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dropped)
        try FileManager.default.copyItem(at: source, to: dropped)
        return dropped
    }

    static var withWriting: SyntheticExport {
        var export = SyntheticExport()
        export.includesWriting = true
        return export
    }
}

/// A data directory that reports how much disk is free as the test says, one answer for each look in
/// turn, the last for every later one.
final class FreeSpace: FileStore, @unchecked Sendable {
    let base: DataDirectory
    private let lock = NSLock()
    private var answers: [Int64]

    init(base: DataDirectory, free: [Int64]) {
        self.base = base
        answers = free
    }

    var importDirectory: URL { base.importDirectory }
    var liveIndex: URL { base.liveIndex }
    var candidateIndex: URL { base.candidateIndex }
    var previousIndex: URL { base.previousIndex }
    var userStore: URL { base.userStore }
    var userSearchCopy: URL { base.userSearchCopy }
    var volumesDirectory: URL { base.volumesDirectory }
    var exportsDirectory: URL { base.exportsDirectory }
    var backupsDirectory: URL { base.backupsDirectory }
    func prepare() throws { try base.prepare() }
    func availableCapacity() throws -> Int64 {
        lock.withLock { answers.count > 1 ? answers.removeFirst() : answers[0] }
    }
}

@Suite struct ResearchDatabaseImportTests {
    /// The row's done-when: over a synthetic export with writing, the installed index holds none of
    /// it, in its tables, its `user_content` index or its bytes, which check 5's snippets and the
    /// writing's own words search, and the store holds all of it.
    @Test(arguments: UserStoreKind.available) func theInstalledIndexHoldsNoneOfTheWritingAndTheStoreAllOfIt(_ kind: UserStoreKind) async throws {
        let fixture = try await WritingImportFixture(kind: kind)
        defer { withExtendedLifetime(fixture) {} }
        let (source, dropped) = try fixture.drop(WritingImportFixture.withWriting)
        let writing = try ExportWriting(of: source)
        #expect(writing.summaries.count == 2 && writing.notes.count == 2 && writing.tags.count == 3 && writing.assignments.count == 4)
        let recorder = WritingStepRecorder()

        let imported = try await fixture.importer.importExport(at: dropped, observer: recorder)

        #expect(await recorder.steps == ReadinessStep.writingImportSteps)
        // Each of the kit's statements is named as the kit names it.
        let details = await recorder.details
        #expect(ResearchDatabaseStrip.steps.allSatisfy { step in details.contains { $0.lowercased() == "\(step.action) in the server's copy" } })
        #expect(imported.index.summary.documents == 3)

        // The installed index: no summary, note or tag in its tables, no term in user_content, the
        // stamp of a copy made without the writing, and none of the writing's text in its bytes.
        let live = fixture.files.liveIndex
        #expect(try ExportWriting(of: live).isEmpty)
        let index = try SQLiteConnection.immutable(live)
        defer { index.close() }
        #expect(try index.scalar("SELECT value FROM research_provenance WHERE key = 'my_writing_included'")?.text == "0")
        try index.execute("CREATE VIRTUAL TABLE temp.terms USING fts5vocab(main, 'user_content', 'row')")
        #expect(try index.scalar("SELECT count(*) FROM temp.terms")?.integer == 0)
        let corpus = try index.query("SELECT header || ' ' || body_text FROM document_cache").compactMap { $0[0].text }.joined(separator: " ")
        let snippets = writing.snippets
        // The words a copy made without the writing holds too, in its schema or its stamp, such as
        // "research" and "volume", are not the writing's.
        let plain = fixture.directory.url.appendingPathComponent("plain.sqlite")
        try SyntheticExport().write(to: plain)
        let candidates = writing.words(outside: corpus)
        let words = candidates.subtracting(try FileBytes.found(candidates, in: plain))
        #expect(snippets.count >= 5 && words.count >= 20)
        #expect(try FileBytes.found(snippets, in: source) == snippets, "the search finds the writing in the export with it")
        #expect(try FileBytes.found(words, in: source) == words)
        #expect(try FileBytes.found(snippets, in: live) == [])
        #expect(try FileBytes.found(words, in: live) == [])
        #expect(try FileBytes.found(["The canal concession and the Mosquito Reservation."], in: live).count == 1, "the corpus stays")

        // The store: each note block and summary under its document's id, marked; the tags under the
        // Mac's ids; every document's tags; and the user's search text.
        for note in writing.notes {
            let id = ResearchDatabaseMark.noteId(for: DocumentKey(volumeId: note.volumeId, documentId: note.documentId))
            let stored = try #require(try fixture.rows.storedNote(id))
            #expect(stored.bodyText == note.text && stored.richText == nil)
            #expect(stored.createdAt == "2026-10-03T15:14:19.000Z" && stored.lastModified == "2026-10-03T15:14:19.000Z")
            #expect(stored.userTagIds == "[]" && stored.projectIds == "[]" && stored.selectedSummaryIds == "[]")
        }
        for summary in writing.summaries {
            let document = DocumentKey(volumeId: summary.volumeId, documentId: summary.documentId)
            let stored = try #require(try fixture.store.summary(ResearchDatabaseMark.summaryId(for: document), of: "owner"))
            #expect(stored.responseText == summary.text && stored.promptId == ResearchDatabaseMark.promptId)
            #expect(stored.authorship == nil && !stored.isHeadnoteDraft && !stored.wasChunked && stored.responseFormat == #"{"general":{}}"#)
            #expect(ResearchDatabaseMark.isFromResearchDatabase(stored) && !stored.isEditable)
        }
        #expect(try fixture.store.tags(of: "owner").map(\.name).sorted() == writing.tags.map(\.name).sorted())
        #expect(try Set(fixture.store.tags(of: "owner").map(\.id)) == Set(writing.tags.map(\.id)))
        let assigned = try fixture.rows.column("SELECT volume_id || '/' || document_id || '/' || tag_id FROM tag_assignments WHERE user_id = 'owner'")
        #expect(Set(assigned) == Set(writing.assignments.map { "\($0.volumeId)/\($0.documentId)/\($0.tagId)" }) && assigned.count == 4)
        let search = try fixture.rows.userSearch()
        #expect(search.count == 3)
        #expect(search.first { $0.documentId == "d1" && $0.volumeId == "frus1961-63v06" }?.noteText == writing.notes.first?.text)
        #expect(try fixture.rows.userSearchMatches("archivist") == ["d1"])
        #expect(try fixture.rows.userSearchMatches("Mosquito") == ["d1"])

        #expect(imported.writing == MovedWriting(notes: ImportCount(added: 2), summaries: ImportCount(added: 2),
                                                 tags: ImportCount(added: 3), tagAssignments: ImportCount(added: 4),
                                                 searchableDocuments: 3))
        #expect(!FileManager.default.fileExists(atPath: fixture.files.candidateIndex.path))
    }

    /// The same export again changes nothing: every record is as new as the store's copy.
    @Test(arguments: UserStoreKind.available) func aSecondImportOfTheSameExportKeepsEverything(_ kind: UserStoreKind) async throws {
        let fixture = try await WritingImportFixture(kind: kind)
        defer { withExtendedLifetime(fixture) {} }
        let (source, dropped) = try fixture.drop(WritingImportFixture.withWriting)
        _ = try await fixture.importer.importExport(at: dropped, observer: WritingStepRecorder())
        let before = try (fixture.rows.rows(of: "notes"), fixture.rows.rows(of: "summaries"), fixture.rows.rows(of: "tags"),
                          fixture.rows.rows(of: "tag_assignments"))

        let again = try await fixture.importer.importExport(at: try fixture.copyIn(source, as: "again.sqlite"), observer: WritingStepRecorder())

        #expect(again.writing == MovedWriting(notes: ImportCount(kept: 2), summaries: ImportCount(kept: 2), tags: ImportCount(kept: 3),
                                              tagAssignments: ImportCount(kept: 4), searchableDocuments: 3))
        let after = try (fixture.rows.rows(of: "notes"), fixture.rows.rows(of: "summaries"), fixture.rows.rows(of: "tags"),
                         fixture.rows.rows(of: "tag_assignments"))
        #expect(after.0 == before.0 && after.1 == before.1 && after.2 == before.2 && after.3 == before.3)
        #expect(again.writing?.report.contains("held the notes, summaries and tags in the export already") == true)
    }

    /// A later export replaces the block and the summary an earlier one brought, under the same ids,
    /// where they changed and the reader has not changed them here: what the reader added to a block,
    /// its tags, stays, a block the reader rewrote here is kept, and so is every tag's name, which
    /// the index cannot date.
    @Test(arguments: UserStoreKind.available) func aLaterExportReplacesWhatAnEarlierBroughtAndTheReaderKept(_ kind: UserStoreKind) async throws {
        let fixture = try await WritingImportFixture(kind: kind)
        defer { withExtendedLifetime(fixture) {} }
        let (_, dropped) = try fixture.drop(WritingImportFixture.withWriting)
        _ = try await fixture.importer.importExport(at: dropped, observer: WritingStepRecorder())
        let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
        let d2 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d2")
        let block = ResearchDatabaseMark.noteId(for: d1)
        // A tag on d1's block, as a raw write leaves it, at the time it was made; d2's block rewritten
        // here, a change after it was made.
        try fixture.rows.run("UPDATE notes SET user_tag_ids = '[\"5C1E0003-7E4A-4B9C-9D2E-0A1B2C3D4E5F\"]' WHERE id = ?", [.text(block)])
        try fixture.rows.run("UPDATE notes SET body_text = 'Rewritten here.', last_modified = '2026-10-05T00:00:00.000Z' WHERE id = ?",
                             [.text(ResearchDatabaseMark.noteId(for: d2))])

        var later = WritingImportFixture.withWriting
        later.exportedAt = "2026-10-20T08:00:00Z"
        let laterSource = fixture.directory.url.appendingPathComponent("later.sqlite")
        try later.write(to: laterSource)
        let edit = try SQLiteConnection(laterSource.path, readOnly: false)
        try edit.execute("""
            UPDATE document_cache SET note_text = note_text || char(10) || char(10) || 'A third note, written after the first export.',
                                      summary_text = 'A newer summary of the telegram.'
                WHERE volume_id = 'frus1961-63v06' AND document_id = 'd1';
            UPDATE document_cache SET note_text = 'The note on d2, revised on the Mac.' WHERE volume_id = 'frus1961-63v06' AND document_id = 'd2';
            UPDATE user_tags SET name = 'Berlin crisis, chapter two' WHERE tag_id = '5C1E0001-7E4A-4B9C-9D2E-0A1B2C3D4E5F';
            """)
        edit.close()

        let imported = try await fixture.importer.importExport(at: try fixture.copyIn(laterSource, as: "later.sqlite"), observer: WritingStepRecorder())

        #expect(imported.writing == MovedWriting(notes: ImportCount(replaced: 1, kept: 1), summaries: ImportCount(replaced: 1, kept: 1),
                                                 tags: ImportCount(kept: 3), tagAssignments: ImportCount(kept: 4),
                                                 searchableDocuments: 3))
        let stored = try #require(try fixture.rows.storedNote(block))
        #expect(stored.bodyText.hasSuffix("A third note, written after the first export."))
        #expect(stored.createdAt == "2026-10-20T08:00:00.000Z" && stored.lastModified == "2026-10-20T08:00:00.000Z",
                "made again by the later export")
        #expect(stored.userTagIds == "[\"5C1E0003-7E4A-4B9C-9D2E-0A1B2C3D4E5F\"]", "a replace writes only what the export says")
        #expect(try fixture.rows.storedNote(ResearchDatabaseMark.noteId(for: d2))?.bodyText == "Rewritten here.")
        #expect(try fixture.store.summary(ResearchDatabaseMark.summaryId(for: d1), of: "owner")?.responseText == "A newer summary of the telegram.")
        #expect(try fixture.store.tag("5C1E0001-7E4A-4B9C-9D2E-0A1B2C3D4E5F", of: "owner")?.name == "Berlin crisis chapter")
        #expect(try fixture.rows.column("SELECT count(*) FROM notes").first == "2")
        #expect(try fixture.rows.column("SELECT count(*) FROM summaries").first == "2")
    }

    /// What the user's own records hold already, from a JSON import of the same library, is not added
    /// again: notes that join into the block, a summary with its text, the document's tag, and a tag
    /// under its Mac id, which keeps the name it has here.
    @Test(arguments: UserStoreKind.available) func whatTheUsersOwnRecordsHoldIsNotAddedAgain(_ kind: UserStoreKind) async throws {
        let fixture = try await WritingImportFixture(kind: kind)
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addNote("10000000-0000-4000-8000-000000000001", bodyText: "Ask the archivist whether the Vienna cables survive in the embassy files.",
                                 createdAt: "2026-05-01T00:00:00.000Z")
        try fixture.rows.addNote("10000000-0000-4000-8000-000000000002", bodyText: "Compare this account with the memoir before drafting chapter three.",
                                 createdAt: "2026-05-02T00:00:00.000Z")
        try fixture.rows.addSummary("20000000-0000-4000-8000-000000000001", volumeId: "frus1894Nicaragua", documentId: "d1",
                                    responseText: #"{"overview":"Minister Baker weighs the canal concession against British claims on the Mosquito Coast."}"#)
        try fixture.rows.addAssignment("30000000-0000-4000-8000-000000000001", documentId: "d1", tagId: "5c1e0002-7e4a-4b9c-9d2e-0a1b2c3d4e5f")
        try fixture.rows.run("""
            INSERT INTO tags (user_id, id, name, created_at, last_modified)
                VALUES ('owner', '5C1E0001-7E4A-4B9C-9D2E-0A1B2C3D4E5F', 'Berlin, as renamed here', '2026-04-01T00:00:00.000Z',
                        '2026-04-02T00:00:00.000Z')
            """)
        // A note on d2 that is not its block: the block comes in beside it.
        try fixture.rows.addNote("10000000-0000-4000-8000-000000000003", documentId: "d2", bodyText: "Another note on d2.")

        let (_, dropped) = try fixture.drop(WritingImportFixture.withWriting)
        let imported = try await fixture.importer.importExport(at: dropped, observer: WritingStepRecorder())

        #expect(imported.writing?.notes == ImportCount(added: 1, kept: 1))
        #expect(imported.writing?.summaries == ImportCount(added: 1, kept: 1))
        #expect(imported.writing?.tagAssignments == ImportCount(added: 3, kept: 1))
        #expect(imported.writing?.tags == ImportCount(added: 2, kept: 1))
        #expect(try fixture.store.tag("5C1E0001-7E4A-4B9C-9D2E-0A1B2C3D4E5F", of: "owner")?.name == "Berlin, as renamed here")
        let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
        #expect(try fixture.rows.storedNote(ResearchDatabaseMark.noteId(for: d1)) == nil)
        #expect(try fixture.rows.storedNote(ResearchDatabaseMark.noteId(for: DocumentKey(volumeId: "frus1961-63v06", documentId: "d2"))) != nil)
        #expect(try fixture.store.summary(ResearchDatabaseMark.summaryId(for: DocumentKey(volumeId: "frus1894Nicaragua", documentId: "d1")),
                                          of: "owner") == nil)
        #expect(try fixture.store.summary(ResearchDatabaseMark.summaryId(for: d1), of: "owner") != nil)
        #expect(try fixture.rows.column("SELECT count(*) FROM tag_assignments WHERE document_id = 'd1' AND volume_id = 'frus1961-63v06'").first == "2")
    }

    /// A file refused after its writing was read, damaged where only `VACUUM` reads, changes nothing:
    /// no index, and nothing kept in the store.
    @Test func aRefusalAfterTheWritingIsReadChangesNothing() async throws {
        let fixture = try await WritingImportFixture()
        var export = WritingImportFixture.withWriting
        export.damagedPage = true
        let (_, dropped) = try fixture.drop(export)
        await #expect {
            _ = try await fixture.importer.importExport(at: dropped, observer: WritingStepRecorder())
        } throws: { error in
            guard let refusal = error as? ImportRefusal else { return false }
            return refusal.step == .strippingWriting && refusal.reason.contains("is damaged") && refusal.reason.contains("reclaiming freed pages")
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.files.liveIndex.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.files.candidateIndex.path))
        for table in ["notes", "summaries", "tags", "tag_assignments"] {
            #expect(try fixture.rows.rows(of: table).isEmpty, "\(table) is as it was")
        }
    }

    /// An export with writing needs about three times its size free, for its copy, `VACUUM`'s copy and
    /// its journal: too little is the server's problem, tried again later, asked for before anything
    /// is copied, and it changes nothing.
    @Test func tooLittleRoomToStripIsTheServersProblemBeforeTheCopy() async throws {
        let size = try Self.size(of: WritingImportFixture.withWriting)
        // Room for a copy, as an export without writing asks, but not for the strip.
        let fixture = try await WritingImportFixture(free: [size + 64 * 1_048_576 + 1])
        let (_, dropped) = try fixture.drop(WritingImportFixture.withWriting)
        let recorder = WritingStepRecorder()
        await #expect {
            _ = try await fixture.importer.importExport(at: dropped, observer: recorder)
        } throws: { error in
            guard let problem = error as? FRUSLightCore.ImportProblem else { return false }
            return problem.step == .copyingExport && problem.reason.contains("which includes your notes, summaries and tags")
                && problem.reason.contains("free beside the index")
        }
        #expect(await recorder.details == ["Copying export.sqlite"], "nothing was copied")
        #expect(!FileManager.default.fileExists(atPath: fixture.files.candidateIndex.path))
        #expect(try fixture.rows.rows(of: "notes").isEmpty)
    }

    /// The strip asks again, once the copy is made: room that went meanwhile is the server's problem.
    @Test func roomGoneBeforeTheStripIsTheServersProblem() async throws {
        let size = try Self.size(of: WritingImportFixture.withWriting)
        let fixture = try await WritingImportFixture(free: [3 * size + 64 * 1_048_576, size])
        let (_, dropped) = try fixture.drop(WritingImportFixture.withWriting)
        await #expect {
            _ = try await fixture.importer.importExport(at: dropped, observer: WritingStepRecorder())
        } throws: { error in
            guard let problem = error as? FRUSLightCore.ImportProblem else { return false }
            return problem.step == .strippingWriting && problem.reason.contains("free beside the index")
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.files.candidateIndex.path))
        #expect(try fixture.rows.rows(of: "notes").isEmpty)
    }

    static func size(of export: SyntheticExport) throws -> Int64 {
        let probe = try TemporaryDirectory()
        let url = probe.url.appendingPathComponent("size.sqlite")
        try export.write(to: url)
        return try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber).int64Value
    }

    /// The kit's order rebuilds both full-text indexes after `VACUUM`, which may renumber the rows they
    /// index, so the pages the rebuild of `user_content` frees, holding the words of the notes and
    /// summaries, stay in the file. The server runs the statements with `secure_delete` on, which
    /// leaves zeros there, as Ubuntu's SQLite does by default but macOS's does not: its default is
    /// `FAST`, which zeroes no freed page. The control runs the same statements in `FAST` mode, over
    /// an export whose many notes and summaries give `user_content` pages to free, and finds the words.
    @Test func theStripLeavesNoWordOfTheWritingInFreedPages() async throws {
        let fixture = try await WritingImportFixture()
        let source = fixture.directory.url.appendingPathComponent("many.sqlite")
        var export = SyntheticExport()
        export.stampsWritingIncluded = true
        try export.write(to: source)
        // The documents indexed first, then the writing in one write, so that `user_content` holds
        // it in one segment, which the strip's own deletes do not merge away before `VACUUM`, as a
        // long-kept index holds most of its terms in segments merged long ago.
        let edit = try SQLiteConnection(source.path, readOnly: false)
        try edit.execute("""
            WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 3000)
            INSERT INTO document_cache (volume_id, document_id, header, body_text)
                SELECT 'frus1961-63v06', 'n' || i, 'Header ' || i, 'The body of document ' || i || '.' FROM n;
            UPDATE document_cache SET
                note_text = 'A note naming zqnote' || printf('%05d', rowid) || ' and its own words.',
                summary_text = CASE WHEN rowid % 2 = 0 THEN 'A summary naming xvsumm' || printf('%05d', rowid) || '.' END
                WHERE document_id GLOB 'n[0-9]*';
            """)
        edit.close()

        let control = fixture.directory.url.appendingPathComponent("control.sqlite")
        try FileManager.default.copyItem(at: source, to: control)
        let stripped = try SQLiteConnection(control.path, readOnly: false)
        try stripped.execute("PRAGMA secure_delete = FAST")
        for step in ResearchDatabaseStrip.steps { try stripped.execute(step.sql) }
        stripped.close()
        #expect(try ExportWriting(of: control).isEmpty)
        let left = (notes: try FileBytes.count("zqnote", in: control), summaries: try FileBytes.count("xvsumm", in: control))
        #expect(left.notes > 0 && left.summaries > 0, "without secure_delete, words of the notes and summaries stay in pages the rebuild freed: \(left)")

        // The server's setting, on a connection at FAST as macOS's starts, so that a change to it fails
        // here though Ubuntu's SQLite, CI's, zeroes freed pages by default.
        let set = fixture.directory.url.appendingPathComponent("set.sqlite")
        try FileManager.default.copyItem(at: source, to: set)
        let setting = try SQLiteConnection(set.path, readOnly: false)
        try setting.execute("PRAGMA secure_delete = FAST")
        try setting.execute(ExportChecks.stripSetting)
        for step in ResearchDatabaseStrip.steps { try setting.execute(step.sql) }
        setting.close()
        #expect(try FileBytes.count("zqnote", in: set) == 0 && FileBytes.count("xvsumm", in: set) == 0)

        let imported = try await fixture.importer.importExport(at: try fixture.copyIn(source, as: "many.sqlite"), observer: WritingStepRecorder())

        #expect(try FileBytes.count("zqnote", in: fixture.files.liveIndex) == 0)
        #expect(try FileBytes.count("xvsumm", in: fixture.files.liveIndex) == 0)
        #expect(imported.writing?.notes == ImportCount(added: 3_000) && imported.writing?.summaries == ImportCount(added: 1_500))
        #expect(try fixture.rows.userSearchMatches("zqnote03002") == ["n2999"])
    }

    /// Through the server: /api/v1/status reports what moved in the app's words and recommends the
    /// JSON export, and the user's routes give the records, marked.
    @Test func theReportAndTheUsersRoutesSayWhatMoved() async throws {
        let fixture = try await UserDataFixture(volumes: [])
        let jobs = InProcessJobQueue()
        let coordinator = ImportCoordinator(
            files: fixture.server.files,
            importer: IndexImporter(files: fixture.server.files, writer: LocalIndexWriter(files: fixture.server.files),
                                    writing: ResearchDatabaseImport.move(into: fixture.store)),
            state: fixture.server.state, jobs: jobs)
        try WritingImportFixture.withWriting.write(to: fixture.server.files.importDirectory.appendingPathComponent("with-writing.sqlite"))
        _ = await coordinator.scan()
        _ = await coordinator.scan()
        await jobs.waitUntilIdle()

        try await fixture.app.test(.router) { client in
            let status = try decode(ServerStatus.self, try await client.execute(uri: "/api/v1/status", method: .get))
            let report = try #require(status.lastImport)
            #expect(report.outcome == .installed && report.file == "with-writing.sqlite")
            #expect(report.writing?.notes == ImportCount(added: 2) && report.writing?.tagAssignments == ImportCount(added: 4))
            #expect(report.message.hasPrefix("Installed 3 documents from 2 volumes, index version \(IndexCompatibility.supportedIndexVersion). Your notes, summaries and tags in the export were moved into your research data"))
            #expect(report.message.contains("2 Research Notes, each a document's note block; 2 generated summaries, each a document's newest; and 7 in Tags & Assignments, 3 tags and 4 assignments."))
            #expect(report.message.contains("marked as from a research database"))
            #expect(report.message.contains("Settings ▸ Data & Recovery ▸ Export as JSON"))

            let browser = Browser(client: client)
            let notes = try decode(NoteList.self, try await browser.get("/api/v1/me/notes"))
            #expect(notes.total == 2 && notes.items.allSatisfy(\.fromResearchDatabase))
            let summaries = try decode(DocumentSummaries.self, try await browser.get("/api/v1/me/volumes/frus1961-63v06/documents/d1/summaries"))
            let summary = try #require(summaries.items.first)
            #expect(summaries.items.count == 1 && summary.fromResearchDatabase && !summary.editable && summary.authorship == "aiGenerated")
            #expect(summary.promptId == ResearchDatabaseMark.promptId && summary.promptName == nil && summary.createdAt == nil)
            // Deleted, not changed, as a note block is.
            #expect(summary.deletable)
            let changed = try await browser.send(.put, "/api/v1/me/summaries/\(summary.id)", #"{"responseText":"Mine now."}"#)
            #expect(changed.status == .forbidden && problemCode(changed) == "SUMMARY_READ_ONLY")
            #expect(try await browser.send(.delete, "/api/v1/me/summaries/\(summary.id)").status == .noContent)
            let tags = try decode(DocumentTags.self, try await browser.get("/api/v1/me/volumes/frus1961-63v06/documents/d1/tags"))
            #expect(tags.items.map(\.name) == ["Berlin crisis chapter", "Vienna summit follow-up"])
            // A note the reader writes here is not marked.
            let made = try await browser.send(.post, "/api/v1/me/volumes/frus1961-63v06/documents/d2/notes", #"{"bodyText":"My own.","runs":null,"userTagIds":[],"projectIds":[],"selectedSummaryIds":[]}"#)
            #expect(made.status == .created)
            #expect(try decode(Note.self, made).fromResearchDatabase == false)
        }
    }
}
