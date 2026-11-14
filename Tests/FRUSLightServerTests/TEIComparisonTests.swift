// Import mode's comparison of the served index with the TEI folder as a job of the queue (PLAN's S21f, by the
// owner's choice of 13 November): it gives way after a volume to a job queued behind it and goes on from where it
// stopped, in a job of its own; a file of the folder changed since it was compared is compared again alone, over
// the comparison before; and an admin's cancel holds until a start, which goes on with what the stop left. Since
// S21f's follow-up it hashes each volume's documents with the kit's public functions first, and gives the kit's
// indexer only a volume that differs from the export's rows: none of an unchanged export, the changed volume alone,
// and a volume for each of the three differences that count, a repeated id compared by its last document.

@testable import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
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

    /// A job queued while the comparison runs waits one volume: the comparison gives way to it, and goes on after it
    /// from the volume it stopped at, in a job of its own, deleting each volume nothing moved in as it goes.
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
        // Nothing moved, so the comparison index keeps nothing of either volume, its revision rows included.
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
        let indexed: [String]
        let record: TEIChangeRecord
    }

    /// The comparison of the two fixture volumes over the export `fixture` serves.
    static func compare(_ fixture: Fixture) async throws -> Run {
        let check = fixture.check()
        let compared = Events(), indexed = Events()
        await check.setVolumeComparedTestHook { await compared.add($0) }
        await check.setVolumeIndexedTestHook { await indexed.add($0) }
        await check.ensureCurrent()
        await fixture.jobs.waitUntilIdle()
        let status = await check.status()
        #expect(!status.running && status.problem == nil)
        let record = try #require(status.record)
        return Run(fixture: fixture, check: check, compared: await compared.all, indexed: await indexed.all, record: record)
    }

    /// An export of the TEI the folder holds: each volume compared by its hashes, none given to the kit's indexer, and
    /// nothing written to the comparison index but the kit's empty tables.
    @Test func anUnchangedExportIsComparedWithNoVolumeIndexed() async throws {
        let run = try await Self.compare(try await Fixture())
        defer { withExtendedLifetime(run.fixture) {} }
        #expect(run.compared == TEIComparisonTests.volumes)
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
        #expect(run.indexed == [UpdateReviewTests.volume])
        #expect(run.record.checked == TEIComparisonTests.volumes && run.record.changed == [UpdateReviewTests.volume])
        let comparison = try #require(await run.check.comparison())
        let changed = try await comparison.pipeline.unreviewedDocumentRevisions()
        #expect(changed.map(\.documentId) == ["d2"] && changed.first?.changeKind == "body")
        #expect(try await comparison.pipeline.documentRevisions(forVolumeId: "frus1961-63v06").isEmpty)
    }

    /// A row the export holds, at the indexer's version, of a document the volume's TEI does not give selects the
    /// volume, and the kit's stamp says the document vanished.
    @Test func aRowOfADocumentTheTEIDoesNotGiveSelectsItsVolume() async throws {
        let volume = "frus1961-63v06"
        let run = try await Self.compare(try await Fixture { db in
            _ = try db.query(
                """
                INSERT INTO document_revisions (volume_id, document_id, content_hash, body_hash, index_version)
                SELECT volume_id, 'd999', content_hash, body_hash, index_version FROM document_revisions
                 WHERE volume_id = ? AND document_id = 'd1'
                """, [.text(volume)])
        })
        defer { withExtendedLifetime(run.fixture) {} }
        #expect(run.indexed == [volume])
        #expect(run.record.changed == [volume])
        let comparison = try #require(await run.check.comparison())
        let row = try #require(try await comparison.pipeline.documentRevision(volumeId: volume, documentId: "d999"))
        #expect(row.changeKind == "vanished" && row.changedAt != nil)
    }

    /// A document of the TEI with no row in the export, or with a row that records it as vanished, selects its
    /// volume, and the kit's stamp says whether it changed: of the document with no row, which is new to the
    /// comparison, it records no change.
    @Test func aDocumentWithNoRowOrAVanishedOneSelectsItsVolume() async throws {
        let run = try await Self.compare(try await Fixture { db in
            _ = try db.query("DELETE FROM document_revisions WHERE volume_id = 'frus1961-63v06' AND document_id = 'd1'")
            _ = try db.query("UPDATE document_revisions SET change_kind = 'vanished' WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd1'")
        })
        defer { withExtendedLifetime(run.fixture) {} }
        #expect(run.indexed == TEIComparisonTests.volumes)
        #expect(run.record.checked == TEIComparisonTests.volumes && !run.record.changed.contains("frus1961-63v06"))
    }

    /// A document whose hash is not its row's, at the indexer's version, selects its volume, and the kit's stamp says
    /// how it changed: the content hash alone here, so the change is to the document's apparatus, not its text.
    @Test func aDocumentHashedOtherwiseSelectsItsVolume() async throws {
        let volume = UpdateReviewTests.volume
        let run = try await Self.compare(try await Fixture { db in
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

    /// A volume whose file repeats a document's id is compared by the last document of that id, which the export's
    /// row records, as the kit's indexer keeps the last: the comparison gives the volume to no indexer, though the first
    /// document of the id is hashed otherwise.
    @Test func aRepeatedIdIsComparedByItsLastDocument() async throws {
        let users = try await UserDataFixture(volumes: [UpdateReviewTests.volume])
        defer { withExtendedLifetime(users) {} }
        let files = users.server.files
        let file = files.volumesDirectory.appendingPathComponent("\(UpdateReviewTests.volume).xml")
        try FileManager.default.removeItem(at: file)
        try Self.repeatingAnId().write(to: file)
        try await UpdateReviewTests.buildIndex(of: [UpdateReviewTests.volume], from: files.volumesDirectory, at: files.liveIndex,
                                               resources: users.server.resources)
        await users.server.state.openExistingIndex(files: files)
        let twice = try await FRUSDocumentParser().parseVolumeFull(volumeURL: file).documents.filter { $0.documentId == "d2" }
        #expect(twice.count == 2)
        let export = try SQLiteConnection.immutable(files.liveIndex)
        let row = try #require(try TEIChangeCheck.storedRevisions(UpdateReviewTests.volume, in: export)["d2"])
        export.close()
        let first = TEIChangeCheck.revisionHashes(of: twice[0]), last = TEIChangeCheck.revisionHashes(of: twice[1])
        #expect(first != last)
        #expect(TEIRevisionHashes(content: row.content, body: row.body) == last)

        let check = TEIChangeCheck(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory,
                                   folder: files.root.appendingPathComponent("tei-check"),
                                   resources: users.server.resources.indexing, state: users.server.state, jobs: users.jobs)
        let indexed = Events()
        await check.setVolumeIndexedTestHook { await indexed.add($0) }
        await check.ensureCurrent()
        await users.jobs.waitUntilIdle()
        let given = await indexed.all
        #expect(given.isEmpty)
        let record = try #require(await check.status().record)
        #expect(record.checked == [UpdateReviewTests.volume] && record.changed.isEmpty)
    }

    /// The selection's rules over the export's rows, alone: what gives a volume to the kit's indexer, with a row
    /// another index version wrote compared by neither hash, nor when its document has gone, but counted when it
    /// records as vanished a document the file gives.
    @Test func theSelectionsRules() {
        let version = IndexingPipeline.currentDateIndexVersion
        let a = TEIRevisionHashes(content: "c1", body: "b1")
        func row(_ hashes: TEIRevisionHashes, _ indexVersion: Int? = version, vanished: Bool = false) -> TEIStoredRevision {
            TEIStoredRevision(content: hashes.content, body: hashes.body, indexVersion: indexVersion, vanished: vanished)
        }
        func differences(_ parsed: [String: TEIRevisionHashes], _ stored: [String: TEIStoredRevision]) -> TEIDifferences {
            TEIChangeCheck.differences(parsed: parsed, stored: stored)
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
    }
}
