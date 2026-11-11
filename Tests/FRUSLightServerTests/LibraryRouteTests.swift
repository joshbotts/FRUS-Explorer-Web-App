// /api/v1/admin/library through the router (PLAN's S21c): every catalogue volume with its state; a
// download, a job whose volumes the reader then reads, with their figures; Remove; and what an Import
// server, a server under FRUS_OFFLINE and an indexed volume refuse. And the library's transport,
// FoundationNetworking's URLSession, against a live server on this machine: a body written to its file
// and bounded, an error's status kept, a redirect followed within its host alone.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import Testing

@testable import FRUSLightAPI

@Suite struct LibraryRouteTests {
    static let path = "/api/v1/admin/library"
    static let downloads = "/api/v1/admin/library/downloads"

    /// A server keeping user data, whose library asks `github` or, with `offline`, nothing.
    struct Fixture {
        let users: UserDataFixture
        let library: VolumeLibrary

        init(mode: ServerConfiguration.Mode = .standalone, offline: Bool = false, volumes: [String] = [], indexed: Bool = false,
             github: FakeGitHub? = nil) async throws {
            users = try await UserDataFixture(volumes: volumes, indexed: indexed)
            if offline {
                library = VolumeLibrary.make(
                    configuration: ServerConfiguration(mode: mode, dataDirectory: users.server.files.root, offline: true),
                    files: users.server.files, store: users.store, jobs: users.jobs, catalogue: users.server.resources.manifest, log: { _ in })
            } else {
                let github = try github ?? LibraryRouteTests.servingFixtures()
                library = VolumeLibrary(volumesDirectory: users.server.files.volumesDirectory, store: users.store, jobs: users.jobs,
                                        catalogue: users.server.resources.manifest, sources: github.sources, transport: github, mode: mode)
            }
            try library.prepare()
        }

        var app: some ApplicationProtocol {
            Application(router: ServedRouter(base: .root, router: buildRouter(
                state: users.server.state, resources: users.server.resources, reader: users.server.reader,
                userData: users.services, library: library)))
        }
    }

    static func servingFixtures() throws -> FakeGitHub {
        let github = FakeGitHub()
        for id in ["frus1894Nicaragua", "frus1961-63v06", "frus1969-76ve09p1"] { try github.serveFixture(id) }
        github.serveFigure("frus1969-76ve09p1", "OpenPitMine.jpg.png", data: FakeGitHub.png("OpenPitMine"))
        return github
    }

    static func volume(_ library: AdminLibrary, _ id: String) throws -> AdminLibrary.Volume {
        try #require(library.volumes.first { $0.volumeId == id })
    }

    /// The Library lists the catalogue; a download is a job whose volumes the reader then renders, with
    /// their figures; Remove takes one away; each refusal says why.
    @Test func anAdminDownloadsListsAndRemovesVolumes() async throws {
        let fixture = try await Fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let before = try decode(AdminLibrary.self, try await owner.get(Self.path))
            #expect(before.mode == "standalone" && before.downloads && before.unavailable == nil && !before.offline && before.source == "mirror")
            #expect(before.volumes.count == 553 && before.counts == ["notDownloaded": 553])
            #expect(try Self.volume(before, "frus1894Nicaragua").catalogueBytes == 1_273_810)

            let posted = try await owner.send(.post, Self.downloads, #"{"volumeIds":["frus1894Nicaragua","frus1969-76ve09p1"]}"#)
            #expect(posted.status == .accepted)
            let job = try decode(AdminJob.self, posted)
            #expect(job.kind == "libraryDownload" && job.subject == "2 volumes" && job.requestedBy == "owner")
            #expect(posted.headers[.location] == "/api/v1/admin/jobs/\(job.id)")
            await fixture.users.jobs.waitUntilIdle()
            let after = try decode(AdminLibrary.self, try await owner.get(Self.path))
            #expect(after.counts == ["downloaded": 2, "notDownloaded": 551])
            let ve09 = try Self.volume(after, "frus1969-76ve09p1")
            let data = try Data(contentsOf: RepositoryFiles.tei.appendingPathComponent("frus1969-76ve09p1.xml"))
            #expect(ve09.status == "downloaded" && ve09.downloaded && !ve09.indexed && ve09.bytes == data.count)
            #expect(ve09.blobSha == VolumeUpdateChecker.gitBlobSHA1(for: data) && ve09.figures == 1 && ve09.figuresRefused == 7)
            #expect(ve09.downloadedAt != nil && ve09.error == nil && ve09.requestedBy == nil)
            // The reader reads what was downloaded, and its figures.
            #expect(try await owner.get("/api/v1/volumes/frus1894Nicaragua/documents/d1/html?part=body").status == .ok)
            let figure = try await owner.get("/api/v1/volumes/frus1969-76ve09p1/figures/OpenPitMine.jpg.png")
            #expect(figure.status == .ok && Data(buffer: figure.body) == FakeGitHub.png("OpenPitMine"))

            for (body, code) in [("{}", "INVALID_FIELD"), (#"{"volumeIds":[]}"#, "INVALID_FIELD"),
                                 (#"{"volumeIds":["frus1894Nicaragua"],"all":true}"#, "INVALID_FIELD"), (#"{"all":false}"#, "INVALID_FIELD"),
                                 (#"{"volumeIds":["frus1999v99"]}"#, "VOLUME_NOT_FOUND"), (#"{"other":1}"#, "UNKNOWN_FIELD")] {
                #expect(problemCode(try await owner.send(.post, Self.downloads, body)) == code, "\(body)")
            }

            let all = try await owner.send(.post, Self.downloads, #"{"all":true}"#)
            #expect(all.status == .accepted && (try decode(AdminJob.self, all)).subject == "551 volumes")
            await fixture.users.jobs.waitUntilIdle()
            #expect(try decode(AdminLibrary.self, try await owner.get(Self.path)).counts == ["downloaded": 3, "notDownloaded": 550])

            let removed = try await owner.send(.delete, "\(Self.path)/volumes/frus1894Nicaragua")
            #expect(removed.status == .noContent)
            #expect(try Self.volume(try decode(AdminLibrary.self, try await owner.get(Self.path)), "frus1894Nicaragua").status == "notDownloaded")
            #expect(problemCode(try await owner.get("/api/v1/volumes/frus1894Nicaragua/documents/d1/html?part=body")) == "TEI_NOT_AVAILABLE")
            #expect(problemCode(try await owner.send(.delete, "\(Self.path)/volumes/frus1894Nicaragua")) == "VOLUME_NOT_DOWNLOADED")
            #expect(problemCode(try await owner.send(.delete, "\(Self.path)/volumes/frus1999v99")) == "VOLUME_NOT_FOUND")
            #expect(problemCode(try await owner.send(.delete, "\(Self.path)/volumes/..%2Fapp")) == "VOLUME_NOT_FOUND")
        }
    }

    /// A download waiting or under way is listed with who asked; asking again for a volume it holds is
    /// refused, and so is its removal.
    @Test func aDownloadUnderWayIsListedAndHoldsItsVolumes() async throws {
        let github = try Self.servingFixtures()
        let gate = JobGate()
        github.hold(github.sources.listing, at: gate)
        let fixture = try await Fixture(github: github)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            _ = try await owner.send(.post, Self.downloads, #"{"volumeIds":["frus1894Nicaragua"]}"#)
            await gate.untilReached()
            let listed = try Self.volume(try decode(AdminLibrary.self, try await owner.get(Self.path)), "frus1894Nicaragua")
            #expect(listed.status == "queued" && listed.requestedBy == "owner" && !listed.downloaded)
            #expect(problemCode(try await owner.send(.post, Self.downloads, #"{"volumeIds":["frus1894Nicaragua"]}"#)) == "DOWNLOAD_IN_PROGRESS")
            #expect(problemCode(try await owner.send(.delete, "\(Self.path)/volumes/frus1894Nicaragua")) == "DOWNLOAD_IN_PROGRESS")
            gate.open()
            await fixture.users.jobs.waitUntilIdle()
            #expect(try Self.volume(try decode(AdminLibrary.self, try await owner.get(Self.path)), "frus1894Nicaragua").status == "downloaded")
        }
    }

    /// An Import server lists its TEI folder and the index, and downloads and removes nothing; a server
    /// under FRUS_OFFLINE downloads nothing; an indexed volume is not removed.
    @Test func importModeOfflineAndAnIndexedVolumeAreRefused() async throws {
        let imports = try await Fixture(mode: .import, volumes: ["frus1894Nicaragua"], indexed: true)
        defer { withExtendedLifetime(imports) {} }
        try await imports.app.test(.router) { client in
            let owner = Browser(client: client)
            let library = try decode(AdminLibrary.self, try await owner.get(Self.path))
            #expect(library.mode == "import" && !library.downloads && library.unavailable?.hasPrefix("An Import server reads the TEI folder") == true)
            #expect(try Self.volume(library, "frus1894Nicaragua").status == "downloaded" && Self.volume(library, "frus1961-63v06").status == "indexed")
            #expect(problemCode(try await owner.send(.post, Self.downloads, #"{"all":true}"#)) == "LIBRARY_NOT_AVAILABLE")
            #expect(problemCode(try await owner.send(.delete, "\(Self.path)/volumes/frus1894Nicaragua")) == "LIBRARY_NOT_AVAILABLE")
            #expect(FileManager.default.fileExists(atPath: imports.users.server.files.volumesDirectory.appendingPathComponent("frus1894Nicaragua.xml").path))
        }
        let offline = try await Fixture(offline: true, indexed: true)
        defer { withExtendedLifetime(offline) {} }
        try await offline.app.test(.router) { client in
            let owner = Browser(client: client)
            let library = try decode(AdminLibrary.self, try await owner.get(Self.path))
            #expect(library.offline && !library.downloads && library.unavailable == "This server makes no request outside (FRUS_OFFLINE=true), so it downloads nothing.")
            let refused = try await owner.send(.post, Self.downloads, #"{"volumeIds":["frus1894Nicaragua"]}"#)
            #expect(refused.status == .conflict && problemCode(refused) == "OFFLINE")
            let jobs = await offline.users.jobs.jobs()
            #expect(try offline.users.store.libraryVolumes().isEmpty && jobs.isEmpty)
            #expect(problemCode(try await owner.send(.delete, "\(Self.path)/volumes/frus1961-63v06")) == "VOLUME_INDEXED")
        }
    }

    // MARK: The transport

    /// A server on this machine that answers as a host may: a file, an error, a redirect within its host
    /// and one to another, and a body longer than it says.
    static func host() -> some ApplicationProtocol {
        let router = Router()
        let file = String(repeating: "x", count: 1_000)
        router.get("file") { _, _ in file }
        router.get("forbidden") { _, _ -> Response in
            Response(status: .forbidden, headers: [.contentType: "text/plain"], body: ResponseBody(byteBuffer: ByteBuffer(string: "no")))
        }
        router.get("moved") { _, _ -> Response in Response(status: .found, headers: [.location: "/file"]) }
        router.get("elsewhere") { request, _ -> Response in
            // Asked at localhost, it sends the browser to 127.0.0.1: another host.
            let port = request.head.authority?.split(separator: ":").last.map(String.init) ?? "80"
            return Response(status: .found, headers: [.location: "http://127.0.0.1:\(port)/file"])
        }
        router.get("streamed") { _, _ -> Response in
            Response(status: .ok, body: ResponseBody { writer in
                for _ in 0..<10 { try await writer.write(ByteBuffer(string: String(repeating: "y", count: 500))) }
                try await writer.finish(nil)
            })
        }
        return Application(router: router, configuration: .init(address: .hostname("127.0.0.1", port: 0)))
    }

    /// URLSession through libcurl, as the library asks: a 2xx body written to its file and bounded,
    /// whether the length is said first or not, leaving no file when it is too long; an error's status
    /// and words kept, its file never made; a redirect followed within its host and refused to another;
    /// and a host that is not there.
    @Test func theTransportWritesBoundsAndFollowsWithinItsHostAlone() async throws {
        let directory = try TemporaryDirectory()
        let transport = URLSessionLibraryTransport()
        try await Self.host().test(.live) { client in
            let port = try #require(client.port)
            let base = "http://localhost:\(port)/"
            let file = directory.url.appendingPathComponent(".file.download")
            let answer = try await transport.get(URL(string: base + "file")!, headers: ["User-Agent": "test"], limit: 1_000, into: file)
            #expect(answer.status == 200 && answer.body.isEmpty && (try Data(contentsOf: file)) == Data(String(repeating: "x", count: 1_000).utf8))
            await #expect(throws: LibraryTransportError.tooLarge(limit: 999)) {
                try await transport.get(URL(string: base + "file")!, headers: [:], limit: 999, into: file)
            }
            #expect(!FileManager.default.fileExists(atPath: file.path), "a file too long is removed")
            await #expect(throws: LibraryTransportError.tooLarge(limit: 4_000)) {
                try await transport.get(URL(string: base + "streamed")!, headers: [:], limit: 4_000, into: file)
            }
            #expect(!FileManager.default.fileExists(atPath: file.path))
            let streamed = try await transport.get(URL(string: base + "streamed")!, headers: [:], limit: 5_000, into: nil)
            #expect(streamed.status == 200 && streamed.body.count == 5_000)
            let refused = try await transport.get(URL(string: base + "forbidden")!, headers: [:], limit: 1_000, into: file)
            #expect(refused.status == 403 && refused.body == Data("no".utf8) && !FileManager.default.fileExists(atPath: file.path))
            let moved = try await transport.get(URL(string: base + "moved")!, headers: [:], limit: 1_000, into: nil)
            #expect(moved.status == 200 && moved.body.count == 1_000, "a redirect within its host is followed")
            await #expect(throws: LibraryTransportError.redirected("127.0.0.1")) {
                try await transport.get(URL(string: base + "elsewhere")!, headers: [:], limit: 1_000, into: nil)
            }
        }
        // A port nothing listens on.
        await #expect {
            try await transport.get(URL(string: "http://127.0.0.1:9/file")!, headers: [:], limit: 1_000, into: nil)
        } throws: { error in
            if case LibraryTransportError.unreachable = error { true } else { false }
        }
        withExtendedLifetime(directory) {}
    }
}
