// Import mode's comparison of the served index with the TEI folder as a job of the queue (PLAN's S21f, by the
// owner's choice of 13 November): it gives way after a volume to a job queued behind it and goes on from where it
// stopped, in a job of its own; a file of the folder changed since it was compared is compared again alone, over
// the comparison before; and an admin's cancel holds until a start, which goes on with what the stop left.

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

    /// An Import server serving an export of the two fixture volumes, whose TEI is in its folder.
    struct Fixture {
        let users: UserDataFixture
        var files: DataDirectory { users.server.files }
        var jobs: InProcessJobQueue { users.jobs }

        init() async throws {
            users = try await UserDataFixture(volumes: TEIComparisonTests.volumes)
            try await UpdateReviewTests.buildIndex(of: TEIComparisonTests.volumes, from: RepositoryFiles.tei,
                                                   at: users.server.files.liveIndex, resources: users.server.resources)
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
}
