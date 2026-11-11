// The library's indexing through the router (PLAN's S21d): Index, a job whose volumes the served index then
// holds; the Library's word on each volume, a pass that failed kept with its stage; Status with the job's
// progress while it runs; a cancel within a volume, which S21a's stop ends once its documents are stored and
// the next indexing finishes; Remove refused while a job may index the volume; and an Import server, which
// indexes nothing.

@testable import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite(.timeLimit(.minutes(2))) struct LibraryIndexingRouteTests {
    static let library = "/api/v1/admin/library"
    static let index = "/api/v1/admin/library/index"
    static let fixtures = ["frus1894Nicaragua", "frus1961-63v06", "frus1969-76ve09p1"]

    /// A Standalone server keeping user data, with the fixture volumes in its library's folder, and its indexer.
    struct Fixture {
        let users: UserDataFixture
        let library: VolumeLibrary
        let indexer: LibraryIndexer

        init(mode: ServerConfiguration.Mode = .standalone, volumes: [String] = LibraryIndexingRouteTests.fixtures) async throws {
            users = try await UserDataFixture()
            let files = users.server.files
            try RepositoryFiles.mountTEI(volumes, at: files.volumesDirectory)
            library = VolumeLibrary(volumesDirectory: files.volumesDirectory, store: users.store, jobs: users.jobs,
                                    catalogue: users.server.resources.manifest, sources: FakeGitHub().sources, transport: nil, mode: mode)
            try library.prepare()
            let state = users.server.state
            indexer = LibraryIndexer(liveIndex: files.liveIndex, volumesDirectory: files.volumesDirectory, mode: mode,
                                     resources: users.server.resources.indexing, jobs: users.jobs, state: state,
                                     observer: ServedIndexWriting(state: state, log: { _ in }), capacity: { .max })
        }

        var app: some ApplicationProtocol {
            Application(router: ServedRouter(base: .root, router: buildRouter(
                state: users.server.state, resources: users.server.resources, reader: users.server.reader,
                userData: users.services, library: library, indexer: indexer)))
        }

        func breakVolume(_ volumeId: String) throws {
            let xml = """
                <?xml version="1.0" encoding="UTF-8"?>
                <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body><div type="document" xml:id="d1"><head>One</head>
                <p>A paragraph that is never closed
                """
            try Data(xml.utf8).write(to: users.server.files.volumesDirectory.appendingPathComponent("\(volumeId).xml"))
        }
    }

    static func volume(_ library: AdminLibrary, _ id: String) throws -> AdminLibrary.Volume {
        try #require(library.volumes.first { $0.volumeId == id })
    }

    /// Index indexes what the library holds: the served index then answers for those volumes; one whose
    /// XML does not parse is listed failed, with why and where its pass was, while the others are indexed;
    /// and each refusal says why.
    @Test func anAdminIndexesTheLibraryAndTheLibrarySaysHowEachVolumeWent() async throws {
        let fixture = try await Fixture()
        defer { withExtendedLifetime(fixture) {} }
        try fixture.breakVolume("frus1961-63v06")
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let before = try decode(AdminLibrary.self, try await owner.get(Self.library))
            #expect(before.counts == ["downloaded": 3, "notDownloaded": 550] && before.indexing == .init(active: false, volume: nil))
            #expect(problemCode(try await owner.get("/api/v1/search?keywords=nicaragua")) == "INDEX_NOT_READY")

            let posted = try await owner.send(.post, Self.index, #"{"all":true}"#)
            #expect(posted.status == .accepted)
            let job = try decode(AdminJob.self, posted)
            #expect(job.kind == "libraryIndex" && job.subject == "every volume waiting" && job.requestedBy == "owner")
            #expect(posted.headers[.location] == "/api/v1/admin/jobs/\(job.id)")
            await fixture.users.jobs.waitUntilIdle()
            let ended = try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(job.id)"))
            #expect(ended.state == "failed" && ended.error == "Indexed 2 of 3 volumes; 1 could not be indexed, which the Library says why.")

            let after = try decode(AdminLibrary.self, try await owner.get(Self.library))
            #expect(after.counts == ["indexed": 2, "failed": 1, "notDownloaded": 550], "\(after.counts)")
            let broken = try Self.volume(after, "frus1961-63v06")
            #expect(broken.status == "failed" && broken.downloaded && !broken.indexed)
            #expect(broken.index?.state == "failed" && broken.index?.stage == "reading" && broken.index?.at != nil)
            #expect(broken.error?.hasPrefix("Its XML could not be parsed while its XML was read") == true, "\(broken.error ?? "")")
            #expect(try Self.volume(after, "frus1894Nicaragua").status == "indexed")
            // The served index is the one the job wrote.
            let search = try await owner.get("/api/v1/search?keywords=nicaragua")
            #expect(search.status == .ok)
            let found = try decode(SearchResultList.self, search)
            #expect(found.total > 0)

            for (body, code) in [(#"{"volumeIds":["frus1894Nicaragua"]}"#, "VOLUME_INDEXED"),
                                 (#"{"volumeIds":["frus1999v99"]}"#, "VOLUME_NOT_FOUND"),
                                 (#"{"volumeIds":["frus1964-68v01"]}"#, "VOLUME_NOT_DOWNLOADED"),
                                 ("{}", "INVALID_FIELD"), (#"{"volumeIds":[]}"#, "INVALID_FIELD"), (#"{"all":false}"#, "INVALID_FIELD"),
                                 (#"{"other":1}"#, "UNKNOWN_FIELD")] {
                #expect(problemCode(try await owner.send(.post, Self.index, body)) == code, "\(body)")
            }

            // The failed volume, its file put right, is indexed when asked for, and then nothing waits.
            try FileManager.default.removeItem(at: fixture.users.server.files.volumesDirectory.appendingPathComponent("frus1961-63v06.xml"))
            try RepositoryFiles.mountTEI(["frus1961-63v06"], at: fixture.users.server.files.volumesDirectory)
            #expect(try await owner.send(.post, Self.index, #"{"volumeIds":["frus1961-63v06"]}"#).status == .accepted)
            await fixture.users.jobs.waitUntilIdle()
            let fixed = try decode(AdminLibrary.self, try await owner.get(Self.library))
            #expect(fixed.counts == ["indexed": 3, "notDownloaded": 550], "\(fixed.counts)")
            #expect(try Self.volume(fixed, "frus1961-63v06").index == nil && Self.volume(fixed, "frus1961-63v06").error == nil)
            #expect(problemCode(try await owner.send(.post, Self.index, #"{"all":true}"#)) == "NOTHING_TO_INDEX")
        }
    }

    /// While a job indexes, Status gives its line and how far through it is, the Library names the volume
    /// under way, and Remove is refused for a volume the job may still index.
    @Test func statusShowsTheJobsProgressAndRemoveWaits() async throws {
        let fixture = try await Fixture()
        defer { withExtendedLifetime(fixture) {} }
        let gate = JobGate()
        await fixture.indexer.setWriterOpenedTestHook { pipeline in
            await pipeline.setDocumentBatchStoredTestHook { _, _ in await gate.wait() }
        }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let job = try decode(AdminJob.self, try await owner.send(.post, Self.index, #"{"all":true}"#))
            await gate.untilReached()
            let status = try decode(AdminStatus.self, try await owner.get("/api/v1/admin/status"))
            let running = try #require(status.jobs.running)
            #expect(running.id == job.id && running.kind == "libraryIndex")
            #expect(running.progress?.hasPrefix("Indexing frus1894Nicaragua (1 of 3)") == true, "\(running.progress ?? "")")
            #expect(running.fraction != nil)
            let listed = try decode(AdminLibrary.self, try await owner.get(Self.library))
            #expect(listed.indexing == .init(active: true, volume: "frus1894Nicaragua"))
            #expect(try Self.volume(listed, "frus1894Nicaragua").status == "indexing")
            for id in Self.fixtures {
                #expect(problemCode(try await owner.send(.delete, "\(Self.library)/volumes/\(id)")) == "INDEXING_IN_PROGRESS", "\(id)")
            }
            gate.open()
            await fixture.users.jobs.waitUntilIdle()
            #expect(try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(job.id)")).state == "succeeded")
            #expect(try decode(AdminLibrary.self, try await owner.get(Self.library)).indexing == .init(active: false, volume: nil))
        }
    }

    /// A cancel asked for while a volume's pass runs stops it once its documents are stored (S21a's stop):
    /// the job ends cancelled, the volume is listed stopped with where it was, the index holds its
    /// documents and no record that its pass finished, and the next indexing finishes it.
    @Test func aCancelWithinAVolumeStopsItOnceItsDocumentsAreStored() async throws {
        let fixture = try await Fixture(volumes: ["frus1894Nicaragua"])
        defer { withExtendedLifetime(fixture) {} }
        let jobs = fixture.users.jobs
        await fixture.indexer.setWriterOpenedTestHook { pipeline in
            await pipeline.setDocumentBatchStoredTestHook { _, _ in
                // The documents are committed: an admin asks the job to stop, and the job's watcher cancels
                // the pass, which the kit then stops at its next check.
                let running = await jobs.jobs().first { $0.state == .running }
                if let running { _ = try? await jobs.cancel(running.id, by: "owner") }
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                while !Task.isCancelled, ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(10)) }
            }
        }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let job = try decode(AdminJob.self, try await owner.send(.post, Self.index, #"{"volumeIds":["frus1894Nicaragua"]}"#))
            await jobs.waitUntilIdle()
            let ended = try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(job.id)"))
            #expect(ended.state == "cancelled", "\(ended)")
            #expect(ended.progress == "Indexed 0 of 1 volume before the cancel. frus1894Nicaragua was stopped once its documents were stored, and the next indexing finishes it.",
                    "\(ended.progress ?? "")")
            let listed = try Self.volume(try decode(AdminLibrary.self, try await owner.get(Self.library)), "frus1894Nicaragua")
            #expect(listed.status == "failed" && listed.index?.state == "stopped" && listed.index?.stage == "storingTables", "\(listed)")
            #expect(listed.error == "An admin's cancel stopped its pass once its documents were stored, before its other tables: the next indexing finishes it.")
            let db = try SQLiteConnection(fixture.users.server.files.liveIndex.path, readOnly: true)
            #expect(try db.query("SELECT count(*) FROM document_cache WHERE volume_id = 'frus1894Nicaragua'").first?.first?.integer == 139)
            #expect(try db.query("SELECT count(*) FROM volume_structures WHERE volume_id = 'frus1894Nicaragua'").first?.first?.integer == 0)
            db.close()

            await fixture.indexer.setWriterOpenedTestHook(nil)
            #expect(try await owner.send(.post, Self.index, #"{"volumeIds":["frus1894Nicaragua"]}"#).status == .accepted)
            await jobs.waitUntilIdle()
            let finished = try Self.volume(try decode(AdminLibrary.self, try await owner.get(Self.library)), "frus1894Nicaragua")
            #expect(finished.status == "indexed" && finished.index == nil && finished.error == nil, "\(finished)")
            let again = try SQLiteConnection(fixture.users.server.files.liveIndex.path, readOnly: true)
            defer { again.close() }
            #expect(try again.query("SELECT count(*) FROM volume_structures WHERE volume_id = 'frus1894Nicaragua'").first?.first?.integer == 1)
        }
    }

    /// An Import server indexes nothing.
    @Test func anImportServerIndexesNothing() async throws {
        let fixture = try await Fixture(mode: .import)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let refused = try await owner.send(.post, Self.index, #"{"all":true}"#)
            #expect(problemCode(refused) == "LIBRARY_NOT_AVAILABLE")
            let listed = try decode(AdminLibrary.self, try await owner.get(Self.library))
            #expect(listed.indexing == .init(active: false, volume: nil))
        }
    }
}
