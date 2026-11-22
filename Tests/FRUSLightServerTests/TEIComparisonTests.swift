// Import mode's comparison of the served index with the TEI folder as a job of the queue (PLAN's S21f, by the
// owner's choice of 13 November): it gives way after a volume to a job queued behind it and goes on from where it
// stopped, in a job of its own; a file of the folder changed since it was compared is compared again alone, over
// the comparison before; and an admin's cancel holds until a start, which goes on with what the stop left. Since
// S21f's second follow-up it holds each mounted file to the export's record of the file its volume was indexed from,
// by the kit's blob SHA-1, and parses only a volume whose file is another or of which the export records none, an
// export from before index version 75 or a volume indexed before it. Since S21f's follow-up it hashes such a volume's
// documents with the kit's public functions, and gives the kit's indexer only a volume that differs from the export's
// rows: none of an unchanged export, the changed volume alone, and a volume for each of the differences that count, an
// id given twice among them; the rows it passes over are ones the kit stamps nothing for; and a comparison index that
// does not read whole is not compared again over.

@testable import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import FTS5Store
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite(.timeLimit(.minutes(3))) struct TEIComparisonTests {
    static let volumes = ["frus1894Nicaragua", "frus1961-63v06"]

    /// What happened, in order, across the queue's jobs.
    actor Events {
        private(set) var all: [String] = []
        func add(_ event: String) { all.append(event) }
    }

    /// An Import server serving an export of the two fixture volumes, whose TEI is in its folder: the export the kit's
    /// indexer makes of their files, its revision rows changed by `alter` before it is served.
    struct Fixture {
        let users: UserDataFixture
        var files: DataDirectory { users.server.files }
        var jobs: InProcessJobQueue { users.jobs }

        init(altering alter: ((SQLiteConnection) throws -> Void)? = nil) async throws {
            users = try await UserDataFixture(volumes: TEIComparisonTests.volumes)
            try await UpdateReviewTests.buildIndex(of: TEIComparisonTests.volumes, from: RepositoryFiles.tei,
                                                   at: users.server.files.liveIndex, resources: users.server.resources)
            if let alter {
                let db = try SQLiteConnection(users.server.files.liveIndex.path, readOnly: false)
                defer { db.close() }
                try alter(db)
            }
            await users.server.state.openExistingIndex(files: users.server.files)
        }

        /// The check, as a start makes one.
        func check() -> TEIChangeCheck {
            TEIChangeCheck(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory,
                           folder: files.root.appendingPathComponent("tei-check"),
                           resources: users.server.resources.indexing, state: users.server.state, jobs: jobs)
        }

        /// The comparison's jobs, the oldest first.
        func comparisons() async -> [Job] {
            await jobs.jobs().filter { $0.kind == .teiComparison }.reversed()
        }
    }

    /// The export with no record of the file each volume was indexed from, as a volume indexed before index version
    /// 75 has none: its volumes are compared by their documents' hashes, as every volume was before the record.
    static func withoutFileRecord(_ db: SQLiteConnection) throws {
        _ = try db.query("UPDATE volume_structures SET file_blob_sha1 = NULL, file_size_bytes = NULL")
    }

    /// A job queued while the comparison runs waits one volume: the comparison gives way to it, and goes on after it
    /// from the volume it stopped at, in a job of its own.
    @Test func theComparisonGivesWayToAQueuedJobAndGoesOnWhereItStopped() async throws {
        let fixture = try await Fixture()
        defer { withExtendedLifetime(fixture) {} }
        let check = fixture.check()
        let events = Events()
        let jobs = fixture.jobs
        await check.setVolumeComparedTestHook { volume in
            await events.add("compared \(volume)")
            guard volume == TEIComparisonTests.volumes[0] else { return }
            _ = try? await jobs.submit(JobKind(rawValue: "aUsersJob"), subject: "a user's job") { _ in
                await events.add("the user's job")
                return "Done."
            }
        }
        await check.ensureCurrent()
        await jobs.waitUntilIdle()
        let order = await events.all
        #expect(order == ["compared frus1894Nicaragua", "the user's job", "compared frus1961-63v06"])
        let comparisons = await fixture.comparisons()
        #expect(comparisons.map(\.state) == [.succeeded, .succeeded])
        #expect(comparisons.first?.progress == "Compared 1 of 2 volumes with the TEI folder; goes on once the jobs waiting have run.")
        #expect(comparisons.last?.progress == "Compared 2 of the index's 2 volumes with the TEI folder: 0 with a document whose TEI changed after the export was indexed")
        let status = await check.status()
        #expect(!status.running && !status.waiting && status.problem == nil)
        let record = try #require(status.record)
        #expect(record.checked == TEIComparisonTests.volumes && record.changed.isEmpty && record.unchecked.isEmpty)
        #expect(record.files.keys.sorted() == TEIComparisonTests.volumes)
        #expect(!FileManager.default.fileExists(atPath: fixture.files.root.appendingPathComponent("tei-check/.work").path))
        // Nothing moved, so the comparison index holds nothing of either volume, its revision rows included.
        let comparison = try #require(await check.comparison())
        for volume in TEIComparisonTests.volumes {
            let rows = try await comparison.pipeline.documentRevisions(forVolumeId: volume)
            #expect(rows.isEmpty, "\(volume)")
        }
    }

    /// A file of the TEI folder changed after the comparison, as a pull of the TEI repository changes one, is compared
    /// again alone, over the comparison before, and the change it brings found; with no file changed, nothing is
    /// queued.
    @Test func aFileChangedSinceTheComparisonIsComparedAgainAlone() async throws {
        let fixture = try await Fixture()
        defer { withExtendedLifetime(fixture) {} }
        let check = fixture.check()
        await check.ensureCurrent()
        await fixture.jobs.waitUntilIdle()
        let first = try #require(await check.status().record)
        await check.ensureCurrent()
        let unchanged = await fixture.comparisons()
        #expect(unchanged.count == 1, "no file changed, so nothing is queued")

        let compared = Events()
        await check.setVolumeComparedTestHook { await compared.add($0) }
        let file = fixture.files.volumesDirectory.appendingPathComponent("\(UpdateReviewTests.volume).xml")
        try FileManager.default.removeItem(at: file)
        try UpdateReviewTests.corrected().write(to: file)
        await check.ensureCurrent()
        let queued = await check.status()
        #expect(queued.running && queued.recheck && queued.total == 1)
        await fixture.jobs.waitUntilIdle()
        let again = await compared.all
        #expect(again == [UpdateReviewTests.volume])
        let status = await check.status()
        #expect(!status.running && status.problem == nil)
        let record = try #require(status.record)
        #expect(record.checked == TEIComparisonTests.volumes && record.changed == [UpdateReviewTests.volume])
        #expect(record.files[UpdateReviewTests.volume] != first.files[UpdateReviewTests.volume])
        #expect(record.files["frus1961-63v06"] == first.files["frus1961-63v06"])
        let comparisons = await fixture.comparisons()
        #expect(comparisons.count == 2)
        #expect(comparisons.last?.progress == "Compared again the 1 volume whose TEI file changed: of the index's 2 volumes compared, 1 with a document whose TEI changed after the export was indexed")
        let comparison = try #require(await check.comparison())
        let changed = try await comparison.pipeline.unreviewedDocumentRevisions()
        #expect(changed.map(\.documentId) == ["d2"] && changed.first?.changeKind == "body")
        await check.ensureCurrent()
        let settled = await fixture.comparisons()
        #expect(settled.count == 2, "compared, so nothing more is queued")
    }

    /// A cancel asked for during a volume stops the comparison there, though a job is queued that it would give way to:
    /// the queued job runs, and no job of the comparison follows it.
    @Test func aCancelDuringAVolumeHoldsThoughAJobIsQueued() async throws {
        let fixture = try await Fixture()
        defer { withExtendedLifetime(fixture) {} }
        let check = fixture.check()
        let events = Events()
        let jobs = fixture.jobs
        await check.setVolumeComparedTestHook { volume in
            guard volume == TEIComparisonTests.volumes[0],
                  let running = await jobs.jobs().first(where: { $0.kind == .teiComparison && $0.state == .running }) else { return }
            _ = try? await jobs.submit(JobKind(rawValue: "aUsersJob"), subject: "a user's job") { _ in
                await events.add("the user's job")
                return "Done."
            }
            _ = try? await jobs.cancel(running.id, by: "owner")
        }
        await check.ensureCurrent()
        await jobs.waitUntilIdle()
        let comparisons = await fixture.comparisons()
        #expect(comparisons.map(\.state) == [.cancelled])
        let order = await events.all
        #expect(order == ["the user's job"])
        let stopped = await check.status()
        #expect(!stopped.running && !stopped.waiting && stopped.problem == TEIChangeCheck.cancelled)
    }

    /// An admin's cancel stops the comparison at its next volume, which no look in /data/import queues again; a
    /// start goes on with what the stop left, the volume compared before it kept.
    @Test func aStartGoesOnWithTheComparisonACancelLeft() async throws {
        let fixture = try await Fixture()
        defer { withExtendedLifetime(fixture) {} }
        let check = fixture.check()
        let jobs = fixture.jobs
        await check.setVolumeComparedTestHook { volume in
            guard volume == TEIComparisonTests.volumes[0],
                  let running = await jobs.jobs().first(where: { $0.kind == .teiComparison && $0.state == .running }) else { return }
            _ = try? await jobs.cancel(running.id, by: "owner")
        }
        await check.ensureCurrent()
        await jobs.waitUntilIdle()
        let stopped = await check.status()
        #expect(!stopped.running && stopped.problem == TEIChangeCheck.cancelled)
        #expect(stopped.record == nil && stopped.done == 1 && stopped.total == 2)
        let cancelled = await fixture.comparisons()
        #expect(cancelled.map(\.state) == [.cancelled])
        await check.ensureCurrent()
        let looked = await fixture.comparisons()
        #expect(looked.count == 1, "no look queues it again")

        let next = fixture.check()
        let compared = Events()
        await next.setVolumeComparedTestHook { await compared.add($0) }
        await next.ensureCurrent()
        await jobs.waitUntilIdle()
        let rest = await compared.all
        #expect(rest == [TEIComparisonTests.volumes[1]])
        let record = try #require(await next.status().record)
        #expect(record.checked == TEIComparisonTests.volumes && record.changed.isEmpty)
    }

    // MARK: Which volumes the kit's indexer is given

    /// What a comparison did over an export: the volumes it compared and those it gave the kit's indexer, in order,
    /// and its record. The fixture is kept with it, for the caller to keep alive.
    struct Run {
        let fixture: Fixture
        let check: TEIChangeCheck
        let compared: [String]
        /// The volumes whose TEI was parsed to compare their documents: none whose file is the one the export indexed.
        let parsed: [String]
        let indexed: [String]
        let record: TEIChangeRecord
    }

    /// The comparison of the two fixture volumes over the export `fixture` serves.
    static func compare(_ fixture: Fixture) async throws -> Run {
        let check = fixture.check()
        let compared = Events(), parsed = Events(), indexed = Events()
        await check.setVolumeComparedTestHook { await compared.add($0) }
        await check.setVolumeParsedTestHook { await parsed.add($0) }
        await check.setVolumeIndexedTestHook { await indexed.add($0) }
        await check.ensureCurrent()
        await fixture.jobs.waitUntilIdle()
        let status = await check.status()
        #expect(!status.running && status.problem == nil)
        let record = try #require(status.record)
        return Run(fixture: fixture, check: check, compared: await compared.all, parsed: await parsed.all,
                   indexed: await indexed.all, record: record)
    }

    /// An export of the TEI the folder holds: each volume compared by its file, which is the one the export indexed,
    /// none parsed or given to the kit's indexer, and nothing written to the comparison index but the kit's empty tables.
    @Test func anUnchangedExportIsComparedWithNoVolumeIndexed() async throws {
        let run = try await Self.compare(try await Fixture())
        defer { withExtendedLifetime(run.fixture) {} }
        #expect(run.compared == TEIComparisonTests.volumes)
        #expect(run.parsed.isEmpty, "each file is the one the export indexed")
        #expect(run.indexed.isEmpty, "no volume is indexed to compare it")
        #expect(run.record.checked == TEIComparisonTests.volumes && run.record.changed.isEmpty && run.record.unchecked.isEmpty)
        let comparisons = await run.fixture.comparisons()
        #expect(comparisons.last?.progress == "Compared 2 of the index's 2 volumes with the TEI folder: 0 with a document whose TEI changed after the export was indexed")
        #expect(await run.check.comparison() != nil, "the comparison index is in place, for the review's readers")
        let placed = try SQLiteConnection.immutable(await run.check.comparisonURL)
        defer { placed.close() }
        #expect(try placed.query("PRAGMA quick_check").first?.first?.text == "ok")
        for table in ["document_cache", "document_revisions"] {
            #expect(try placed.scalar("SELECT count(*) FROM \(table)")?.integer == 0, "\(table)")
        }
    }

    /// A volume whose TEI changed after the export, the one alone, is given to the kit's indexer, which says what
    /// changed and how: d2's text, a `body` change, as an update stamps it.
    @Test func aChangedVolumeAloneIsIndexedAndTheKitSaysHowItChanged() async throws {
        let fixture = try await Fixture()
        let file = fixture.files.volumesDirectory.appendingPathComponent("\(UpdateReviewTests.volume).xml")
        try FileManager.default.removeItem(at: file)
        try UpdateReviewTests.corrected().write(to: file)
        let run = try await Self.compare(fixture)
        defer { withExtendedLifetime(run.fixture) {} }
        #expect(run.compared == TEIComparisonTests.volumes)
        #expect(run.parsed == [UpdateReviewTests.volume], "the one whose file is not the one the export indexed")
        #expect(run.indexed == [UpdateReviewTests.volume])
        #expect(run.record.checked == TEIComparisonTests.volumes && run.record.changed == [UpdateReviewTests.volume])
        let comparison = try #require(await run.check.comparison())
        let changed = try await comparison.pipeline.unreviewedDocumentRevisions()
        #expect(changed.map(\.documentId) == ["d2"] && changed.first?.changeKind == "body")
        #expect(try await comparison.pipeline.documentRevisions(forVolumeId: "frus1961-63v06").isEmpty)
    }

    /// The export's record of the file each volume was indexed from decides whether its documents are compared: a
    /// volume whose mounted file is that file, by the kit's blob SHA-1 and its length, is compared with nothing parsed,
    /// though the export's rows of it say otherwise, since the file is the one they describe; one whose record names
    /// another file has its documents compared, and found as the export records them, so nothing is indexed.
    @Test func theFileTheExportIndexedDecidesWhetherAVolumesDocumentsAreCompared() async throws {
        let other = String(repeating: "0", count: 40)
        let fixture = try await Fixture { db in
            _ = try db.query("UPDATE document_revisions SET content_hash = 'another' WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd1'")
            _ = try db.query("UPDATE volume_structures SET file_blob_sha1 = ? WHERE volume_id = 'frus1961-63v06'", [.text(other)])
        }
        let export = try SQLiteConnection.immutable(fixture.files.liveIndex)
        let recorded = try export.query("SELECT volume_id, file_blob_sha1, file_size_bytes FROM volume_structures ORDER BY volume_id")
        export.close()
        let mounted = try TEIChangeCheck.blobSHA1(of: fixture.files.volumesDirectory.appendingPathComponent("frus1894Nicaragua.xml"))
        #expect(recorded.map { $0[0].text } == TEIComparisonTests.volumes)
        #expect(recorded.first?[1].text == mounted.sha && recorded.first?[2].integer == Int64(mounted.bytes),
                "the kit's record of the file it indexed is the mounted file's blob SHA-1 and length")
        let run = try await Self.compare(fixture)
        defer { withExtendedLifetime(run.fixture) {} }
        #expect(run.compared == TEIComparisonTests.volumes)
        #expect(run.parsed == ["frus1961-63v06"], "the one whose record names another file")
        #expect(run.indexed.isEmpty, "its documents are the export's, and frus1894Nicaragua's rows are not read")
        #expect(run.record.checked == TEIComparisonTests.volumes && run.record.changed.isEmpty && run.record.unchecked.isEmpty)
    }

    /// An export without the record compares every volume by its documents, as every volume was compared before it:
    /// one whose volumes were indexed before index version 75, which left the record NULL, and one from before 75, with
    /// no such columns, of which the kit's read-only open answers none.
    @Test(arguments: [false, true]) func anExportWithoutTheRecordComparesEveryVolumeByItsDocuments(fromBefore75: Bool) async throws {
        let run = try await Self.compare(try await Fixture { db in
            if fromBefore75 {
                _ = try db.query("ALTER TABLE volume_structures DROP COLUMN file_blob_sha1")
                _ = try db.query("ALTER TABLE volume_structures DROP COLUMN file_size_bytes")
            } else {
                try Self.withoutFileRecord(db)
            }
        })
        defer { withExtendedLifetime(run.fixture) {} }
        let url = run.fixture.files.liveIndex
        let pipeline = try IndexingPipeline(readingIndexAt: url, fts5Store: try FTS5Store(readingDatabaseAt: url),
                                            resources: run.fixture.users.server.resources.indexing,
                                            volumesDirectory: run.fixture.files.volumesDirectory)
        #expect(try pipeline.indexedVolumeFiles().isEmpty, "the kit's read-only open answers no record, and throws none")
        #expect(run.compared == TEIComparisonTests.volumes && run.parsed == TEIComparisonTests.volumes)
        #expect(run.indexed.isEmpty, "their documents are as the export records them")
        #expect(run.record.checked == TEIComparisonTests.volumes && run.record.changed.isEmpty)
    }

    /// A comparison an earlier rule placed, its record's format 1, before a volume whose file the export indexed was
    /// passed over, is made again whole at the first look of a start: that rule found in such a volume, as a change in
    /// the TEI, what the export itself records, which the reader reads from the export.
    @Test func aComparisonAnEarlierRulePlacedIsMadeAgain() async throws {
        let fixture = try await Fixture()
        defer { withExtendedLifetime(fixture) {} }
        let check = fixture.check()
        await check.ensureCurrent()
        await fixture.jobs.waitUntilIdle()
        let url = await check.recordURL
        var object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect(object["format"] as? Int == TEIChangeRecord.currentFormat)
        object["format"] = 1
        try JSONSerialization.data(withJSONObject: object).write(to: url)

        let next = fixture.check()
        let compared = Events()
        await next.setVolumeComparedTestHook { await compared.add($0) }
        await next.ensureCurrent()
        let queued = await next.status()
        #expect(queued.running && !queued.recheck && queued.total == TEIComparisonTests.volumes.count)
        await fixture.jobs.waitUntilIdle()
        let again = await compared.all
        #expect(again == TEIComparisonTests.volumes, "every volume compared afresh")
        let record = try #require(await next.status().record)
        #expect(record.format == TEIChangeRecord.currentFormat && record.checked == TEIComparisonTests.volumes)
        #expect(await fixture.comparisons().count == 2)
    }

    /// A row the export holds, at the indexer's version, of a document the volume's TEI does not give selects the
    /// volume, and the kit's stamp says the document vanished.
    @Test func aRowOfADocumentTheTEIDoesNotGiveSelectsItsVolume() async throws {
        let volume = "frus1961-63v06"
        let run = try await Self.compare(try await Fixture { db in
            try Self.withoutFileRecord(db)
            _ = try db.query(
                """
                INSERT INTO document_revisions (volume_id, document_id, content_hash, body_hash, index_version)
                SELECT volume_id, 'd999', content_hash, body_hash, index_version FROM document_revisions
                 WHERE volume_id = ? AND document_id = 'd1'
                """, [.text(volume)])
        })
        defer { withExtendedLifetime(run.fixture) {} }
        #expect(run.parsed == TEIComparisonTests.volumes, "no record of the files")
        #expect(run.indexed == [volume])
        #expect(run.record.changed == [volume])
        let comparison = try #require(await run.check.comparison())
        let row = try #require(try await comparison.pipeline.documentRevision(volumeId: volume, documentId: "d999"))
        #expect(row.changeKind == "vanished" && row.changedAt != nil)
    }

    /// A document of the TEI with no row in the export, or with a row that records it as vanished, selects its
    /// volume, and the kit's stamp says whether it changed. Of the document with no row, which is new to the
    /// comparison, it records none. The vanished row reaches the kit as S21f's seed writes it, with no change kind,
    /// so the kit compares its hashes, which are the document's, and records none either. Each volume, the kit having
    /// stamped nothing in it, is deleted from the comparison index again.
    @Test func aDocumentWithNoRowOrAVanishedOneSelectsItsVolume() async throws {
        let run = try await Self.compare(try await Fixture { db in
            try Self.withoutFileRecord(db)
            _ = try db.query("DELETE FROM document_revisions WHERE volume_id = 'frus1961-63v06' AND document_id = 'd1'")
            _ = try db.query("UPDATE document_revisions SET change_kind = 'vanished' WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd1'")
        })
        defer { withExtendedLifetime(run.fixture) {} }
        #expect(run.indexed == TEIComparisonTests.volumes)
        #expect(run.record.checked == TEIComparisonTests.volumes && run.record.changed.isEmpty)
        let placed = try SQLiteConnection.immutable(await run.check.comparisonURL)
        defer { placed.close() }
        for table in ["document_cache", "document_revisions"] {
            #expect(try placed.scalar("SELECT count(*) FROM \(table)")?.integer == 0, "\(table): each volume deleted again")
        }
    }

    /// A document whose hash is not its row's, at the indexer's version, selects its volume, and the kit's stamp says
    /// how it changed: the content hash alone here, so the change is to the document's apparatus, not its text.
    @Test func aDocumentHashedOtherwiseSelectsItsVolume() async throws {
        let volume = UpdateReviewTests.volume
        let run = try await Self.compare(try await Fixture { db in
            try Self.withoutFileRecord(db)
            _ = try db.query("UPDATE document_revisions SET content_hash = 'another' WHERE volume_id = ? AND document_id = 'd1'",
                             [.text(volume)])
        })
        defer { withExtendedLifetime(run.fixture) {} }
        #expect(run.indexed == [volume])
        #expect(run.record.changed == [volume])
        let comparison = try #require(await run.check.comparison())
        let changed = try await comparison.pipeline.unreviewedDocumentRevisions()
        #expect(changed.map(\.documentId) == ["d1"] && changed.first?.changeKind == "apparatus")
    }

    /// The fixture volume with d3's id made d2's, so that its file gives d2 twice, the second time with d3's text.
    static func repeatingAnId() throws -> Data {
        var xml = try String(contentsOf: RepositoryFiles.tei.appendingPathComponent("\(UpdateReviewTests.volume).xml"), encoding: .utf8)
        let d3 = try #require(xml.range(of: #"xml:id="d3""#))
        xml.replaceSubrange(d3, with: #"xml:id="d2""#)
        return Data(xml.utf8)
    }

    /// A volume whose file gives an id to two documents that differ is given to the kit's indexer, which writes them
    /// in turn and says what that is, as it said at every comparison before the hashes: the export's row of the id,
    /// which records the last document, as the kit's indexer keeps the last, is compared with the last and is that
    /// document's, and the id given twice is what selects the volume.
    @Test func anIdGivenTwiceHashedDifferentlySelectsItsVolume() async throws {
        let users = try await UserDataFixture(volumes: [UpdateReviewTests.volume])
        defer { withExtendedLifetime(users) {} }
        let files = users.server.files
        let file = files.volumesDirectory.appendingPathComponent("\(UpdateReviewTests.volume).xml")
        try FileManager.default.removeItem(at: file)
        try Self.repeatingAnId().write(to: file)
        try await UpdateReviewTests.buildIndex(of: [UpdateReviewTests.volume], from: files.volumesDirectory, at: files.liveIndex,
                                               resources: users.server.resources)
        // The file the volume was indexed from is the one mounted, which would pass the volume over unparsed: with no
        // record of it, as a volume indexed before index version 75, its documents are compared.
        let db = try SQLiteConnection(files.liveIndex.path, readOnly: false)
        try Self.withoutFileRecord(db)
        db.close()
        await users.server.state.openExistingIndex(files: files)
        let parsed = try await TEIChangeCheck.revisionHashes(of: file)
        let twice = parsed.filter { $0.id == "d2" }
        #expect(twice.count == 2 && twice[0].hashes != twice[1].hashes)
        let export = try SQLiteConnection.immutable(files.liveIndex)
        let stored = try TEIChangeCheck.storedRevisions(UpdateReviewTests.volume, in: export)
        export.close()
        let row = try #require(stored["d2"])
        #expect(TEIRevisionHashes(content: row.content, body: row.body) == twice[1].hashes)
        #expect(TEIChangeCheck.differences(parsed: parsed, stored: stored) == TEIDifferences(repeated: ["d2"]))

        let check = TEIChangeCheck(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory,
                                   folder: files.root.appendingPathComponent("tei-check"),
                                   resources: users.server.resources.indexing, state: users.server.state, jobs: users.jobs)
        let indexed = Events()
        await check.setVolumeIndexedTestHook { await indexed.add($0) }
        await check.ensureCurrent()
        await users.jobs.waitUntilIdle()
        let given = await indexed.all
        #expect(given == [UpdateReviewTests.volume])
        let record = try #require(await check.status().record)
        #expect(record.checked == [UpdateReviewTests.volume] && record.changed == [UpdateReviewTests.volume])
        let comparison = try #require(await check.comparison())
        let changed = try await comparison.pipeline.unreviewedDocumentRevisions()
        #expect(changed.map(\.documentId) == ["d2"], "the kit's own word on the id it writes twice")
    }

    /// The selection's rules over the export's rows, alone: what gives a volume to the kit's indexer, with a row
    /// another index version wrote compared by neither hash, nor when its document has gone, but counted when it
    /// records as vanished a document the file gives; and an id the file gives twice compared by its last document,
    /// and counted when its documents differ.
    @Test func theSelectionsRules() {
        let version = IndexingPipeline.currentDateIndexVersion
        let a = TEIRevisionHashes(content: "c1", body: "b1")
        func row(_ hashes: TEIRevisionHashes, _ indexVersion: Int? = version, vanished: Bool = false) -> TEIStoredRevision {
            TEIStoredRevision(content: hashes.content, body: hashes.body, indexVersion: indexVersion, vanished: vanished)
        }
        func differences(_ parsed: [String: TEIRevisionHashes], _ stored: [String: TEIStoredRevision]) -> TEIDifferences {
            TEIChangeCheck.differences(parsed: parsed.map { TEIParsedDocument(id: $0.key, hashes: $0.value) }, stored: stored)
        }
        func inOrder(_ parsed: [(String, TEIRevisionHashes)], _ stored: [String: TEIStoredRevision]) -> TEIDifferences {
            TEIChangeCheck.differences(parsed: parsed.map { TEIParsedDocument(id: $0.0, hashes: $0.1) }, stored: stored)
        }
        #expect(differences(["d1": a, "d2": a], ["d1": row(a), "d2": row(a)]).isEmpty)
        #expect(differences([:], [:]).isEmpty)
        // A row of a document the file does not give, at the indexer's version; at another, or none, nothing.
        #expect(differences(["d1": a], ["d1": row(a), "d2": row(a)]) == TEIDifferences(notInTEI: ["d2"]))
        #expect(differences(["d1": a], ["d1": row(a), "d2": row(a, version - 1), "d3": row(a, nil)]).isEmpty)
        #expect(differences(["d1": a], ["d1": row(a), "d2": row(a, version - 1, vanished: true)]).isEmpty)
        // A document with no row, or with a vanished one at any version.
        #expect(differences(["d1": a, "d2": a, "d3": a], ["d2": row(a, vanished: true), "d3": row(a, version - 1, vanished: true)])
                == TEIDifferences(notInExport: ["d1", "d2", "d3"]))
        // Either hash otherwise, at the indexer's version; at another, or none, nothing.
        let content = TEIRevisionHashes(content: "c2", body: "b1"), body = TEIRevisionHashes(content: "c1", body: "b2")
        #expect(differences(["d1": a, "d2": a], ["d1": row(content), "d2": row(body)]) == TEIDifferences(hashes: ["d1", "d2"]))
        #expect(differences(["d1": a, "d2": a], ["d1": row(content, version - 1), "d2": row(body, nil)]).isEmpty)
        // All three at once, each in order.
        #expect(differences(["d3": a, "d1": a, "d2": a, "d5": a],
                            ["d5": row(body), "d4": row(a), "d2": row(content), "d9": row(a), "d3": row(a, vanished: true)])
                == TEIDifferences(notInTEI: ["d4", "d9"], notInExport: ["d1", "d3"], hashes: ["d2", "d5"]))
        // An id given twice: its row compared with the last; the twice-given id counted only when its documents differ,
        // whatever its row says.
        #expect(inOrder([("d1", a), ("d1", a)], ["d1": row(a)]).isEmpty)
        #expect(inOrder([("d1", content), ("d1", a)], ["d1": row(a)]) == TEIDifferences(repeated: ["d1"]))
        #expect(inOrder([("d1", a), ("d1", content)], ["d1": row(a)]) == TEIDifferences(hashes: ["d1"], repeated: ["d1"]))
        #expect(inOrder([("d1", content), ("d1", a)], ["d1": row(a, version - 1)]) == TEIDifferences(repeated: ["d1"]))
        #expect(inOrder([("d1", a), ("d2", a), ("d1", a)], ["d1": row(a), "d2": row(a)]).isEmpty)
    }

    /// An export stamped as a Mac's export is, so that its rows may be at any version.
    static func stamp(_ db: SQLiteConnection) throws {
        let version = IndexCompatibility.supportedIndexVersion, fts = IndexCompatibility.ftsSchemaVersion
        try db.execute(
            """
            CREATE TABLE IF NOT EXISTS research_provenance (key TEXT PRIMARY KEY, value TEXT);
            INSERT OR REPLACE INTO research_provenance (key, value) VALUES
              ('exported_at', '2026-11-14T12:00:00Z'), ('my_writing_included', '0'),
              ('installed_index_version', '\(version)'), ('current_index_version', '\(version)'),
              ('installed_fts_schema_version', '\(fts)'), ('current_fts_schema_version', '\(fts)');
            """)
    }

    /// The rows the selection passes over are ones the kit's indexer stamps nothing for: over an export holding, in
    /// each fixture volume, a row at an older version and one at none, of a document the TEI does not give and of a
    /// document hashed otherwise, the comparison gives the kit no volume; and the kit, given each volume anyway over
    /// the export's rows as the comparison seeds them, stamps no change in either.
    @Test func theVolumesTheSelectionSkipsAreOnesTheKitStampsNothingIn() async throws {
        let older = Int64(IndexingPipeline.currentDateIndexVersion - 1)
        let fixture = try await Fixture { db in
            try Self.stamp(db)
            try Self.withoutFileRecord(db)
            for (volume, version) in [("frus1894Nicaragua", SQLiteValue.integer(older)), ("frus1961-63v06", .null)] {
                _ = try db.query(
                    """
                    INSERT INTO document_revisions (volume_id, document_id, content_hash, body_hash, index_version)
                    SELECT volume_id, 'd999', content_hash, body_hash, ? FROM document_revisions WHERE volume_id = ? AND document_id = 'd1'
                    """, [version, .text(volume)])
                _ = try db.query("UPDATE document_revisions SET content_hash = 'another', body_hash = 'another', index_version = ? WHERE volume_id = ? AND document_id = 'd2'",
                                 [version, .text(volume)])
            }
        }
        let run = try await Self.compare(fixture)
        defer { withExtendedLifetime(run.fixture) {} }
        #expect(run.compared == TEIComparisonTests.volumes && run.parsed == TEIComparisonTests.volumes)
        #expect(run.indexed.isEmpty, "the selection gives the kit no volume")
        #expect(run.record.changed.isEmpty && run.record.unchecked.isEmpty)

        let export = try SQLiteConnection.immutable(fixture.files.liveIndex)
        defer { export.close() }
        for volume in TEIComparisonTests.volumes {
            let directory = try TemporaryDirectory()
            let url = directory.url.appendingPathComponent("scratch.db")
            let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: url), databaseURL: url,
                                                volumesDirectory: fixture.files.volumesDirectory,
                                                resources: fixture.users.server.resources.indexing, defaults: InMemoryIndexingStampStore())
            let seeder = try SQLiteConnection(url.path, readOnly: false)
            try TEIChangeCheck.seed(volume, from: export, into: seeder)
            seeder.close()
            try await pipeline.indexVolume(volume)
            let stamped = try await pipeline.documentRevisions(forVolumeId: volume).filter { $0.changedAt != nil }
            #expect(stamped.isEmpty, "\(volume): the kit stamps \(stamped.map(\.documentId))")
            withExtendedLifetime(directory) {}
        }
    }

    /// A comparison index that does not read whole, as a comparison that indexed no volume placed before the log was
    /// folded through a connection of its own, is not compared again over: when a file of the folder changes, every
    /// volume is compared afresh, the change found, and a whole comparison index placed.
    @Test func aComparisonIndexThatDoesNotReadWholeIsComparedAfresh() async throws {
        let fixture = try await Fixture()
        defer { withExtendedLifetime(fixture) {} }
        let check = fixture.check()
        await check.ensureCurrent()
        await fixture.jobs.waitUntilIdle()
        let placed = await check.comparisonURL
        #expect(TEIChangeCheck.readsWhole(placed))
        // Its pages after the first written over, its schema kept.
        let handle = try FileHandle(forUpdating: placed)
        try handle.seek(toOffset: 4096)
        try handle.write(contentsOf: Data(repeating: 0xA5, count: 8192))
        try handle.close()
        #expect(!TEIChangeCheck.readsWhole(placed))

        let file = fixture.files.volumesDirectory.appendingPathComponent("\(UpdateReviewTests.volume).xml")
        try FileManager.default.removeItem(at: file)
        try UpdateReviewTests.corrected().write(to: file)
        await check.ensureCurrent()
        await fixture.jobs.waitUntilIdle()
        let status = await check.status()
        #expect(!status.running && status.problem == nil)
        let record = try #require(status.record)
        #expect(record.checked == TEIComparisonTests.volumes && record.changed == [UpdateReviewTests.volume])
        let comparisons = await fixture.comparisons()
        #expect(comparisons.map(\.state) == [.succeeded, .succeeded])
        #expect(comparisons.last?.progress == "Compared 2 of the index's 2 volumes with the TEI folder: 1 with a document whose TEI changed after the export was indexed")
        #expect(TEIChangeCheck.readsWhole(placed))
        let comparison = try #require(await check.comparison())
        let changed = try await comparison.pipeline.unreviewedDocumentRevisions()
        #expect(changed.map(\.documentId) == ["d2"] && changed.first?.changeKind == "body")
    }
}
