// The library (PLAN's S21c): a Standalone server's downloads, jobs of the queue, over a folder served as
// GitHub serves it, in memory (`FakeGitHub`), so that no test makes a request outside. Each volume is kept
// only once its length and git blob SHA-1, the kit's, are the listing's, with its figure images, as the
// app's figure library fetches them, and no name reaches outside its folder; a cancel stops a download
// between volumes, and a restart resumes it volume by volume; FRUS_OFFLINE and Import mode download
// nothing. The store's methods are the conformance suite's, on every store `UserStoreKind.available` names.

import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct LibraryTests {
    static let fixtures = ["frus1894Nicaragua", "frus1961-63v06", "frus1969-76ve09p1"]
    /// The images frus1969-76ve09p1's figures name outside its title page, in its order.
    static let figures = ["genassemblybldg", "OpenPitMine.jpg", "autoconveyorbelt.jpg", "SaharanFamily.jpg", "SpanishSaharaMap.jpg",
                          "SpanishSaharaMap2.jpg", "1973SummitMeeting.jpg", "WesternSahara.jpg"]
    static let start = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z

    /// A volume of the tests' own, whose figures name paths and characters an address must not keep.
    static let syntheticId = "frus1999v99"
    static let synthetic = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><front><titlePage><figure><graphic url="titlefigure"/></figure></titlePage></front>
        <body><div type="document" xml:id="d1"><head>One</head>
        <figure><graphic url="../../escape"/></figure><figure><graphic url="sub/dir"/></figure><figure><graphic url=".."/></figure>
        <figure><graphic url="back\\slash"/></figure><figure><graphic url="Document A.1"/></figure><figure><graphic url="what?#%"/></figure>
        <figure><graphic url="Document A.1"/></figure><figure><graphic url="  "/></figure>
        </div></body></text><facsimile><surface><graphic url="https://static.history.state.gov/frus/frus1999v99/tiff/0001.tif"/></surface></facsimile></TEI>
        """ + "\n<!-- " + String(repeating: "Padded past the 20,000 bytes the kit's listing takes a volume from. ", count: 300) + "-->\n"

    /// The bundled catalogue, and the tests' own volume.
    static func catalogue() throws -> [VolumeManifestEntry] {
        let entry = """
            {"dateRange": {"earliest": "1999-01-01T00:00:00-05:00", "latest": "1999-12-31T23:59:59-05:00"}, "editors": [],
             "filename": "frus1999v99.xml", "publicationDate": "2026", "sizeBytes": 2000, "status": "published", "subseries": "1999",
             "tags": [], "title": "A volume of the tests' own", "volumeId": "frus1999v99"}
            """
        return try FixedVolumeCatalogue(contentsOf: RepositoryFiles.resources.appendingPathComponent("manifest.json")).citableEntries
            + [try JSONDecoder().decode(VolumeManifestEntry.self, from: Data(entry.utf8))]
    }

    static func fixture(_ volumeId: String) throws -> Data {
        try Data(contentsOf: RepositoryFiles.tei.appendingPathComponent("\(volumeId).xml"))
    }

    /// A library over app.db and a folder of its own, asking `github`, as a Standalone server's at its start.
    struct Fixture {
        let directory: TemporaryDirectory
        let store: SQLiteUserStore
        let rows: UserStoreRows
        let queue: InProcessJobQueue
        let github: FakeGitHub
        let library: VolumeLibrary

        var volumes: URL { library.volumesDirectory }

        func file(_ volumeId: String) -> URL { volumes.appendingPathComponent("\(volumeId).xml") }
        func figure(_ volumeId: String, _ name: String) -> URL {
            volumes.appendingPathComponent("\(volumeId).figures").appendingPathComponent(name)
        }
        func row(_ volumeId: String) throws -> LibraryVolume? { try store.libraryVolume(volumeId) }

        /// The library again over the same folder and store, as a server's next start has it.
        func restarted(github: FakeGitHub, mode: ServerConfiguration.Mode = .standalone, offline: Bool = false) async throws -> (InProcessJobQueue, VolumeLibrary) {
            let queue = try await InProcessJobQueue.open(store: store)
            let library = VolumeLibrary(volumesDirectory: volumes, store: store, jobs: queue, catalogue: try LibraryTests.catalogue(),
                                        sources: github.sources, transport: offline ? nil : github, mode: mode)
            return (queue, library)
        }
    }

    static func open(github: FakeGitHub = FakeGitHub(), mode: ServerConfiguration.Mode = .standalone, offline: Bool = false,
                     token: String? = nil, clock: JobClock = JobClock()) async throws -> Fixture {
        let (store, rows, directory) = try await UserTagTests.open()
        let queue = try await InProcessJobQueue.open(store: store)
        let library = VolumeLibrary(volumesDirectory: directory.url.appendingPathComponent("volumes", isDirectory: true), store: store,
                                    jobs: queue, catalogue: try catalogue(), sources: github.sources,
                                    transport: github, mode: mode, offline: offline, githubToken: token, now: { clock.now })
        try library.prepare()
        return Fixture(directory: directory, store: store, rows: rows, queue: queue, github: github, library: library)
    }

    /// GitHub serving the three fixture volumes, and every image frus1969-76ve09p1 names but its last,
    /// which the image host refuses.
    static func servingFixtures() throws -> FakeGitHub {
        let github = FakeGitHub()
        for id in fixtures { try github.serveFixture(id) }
        for name in figures.dropLast() { github.serveFigure("frus1969-76ve09p1", "\(name).png", data: FakeGitHub.png(name)) }
        return github
    }

    static func finished(_ queue: InProcessJobQueue, _ job: Job) async throws -> Job {
        await queue.waitUntilIdle()
        return try #require(await queue.job(job.id))
    }

    // MARK: Downloads

    /// The three fixture volumes, each the listing's file byte for byte, its blob SHA-1 and length kept,
    /// with frus1969-76ve09p1's figure images beside it, the one the host refuses left out; the listing
    /// asked once, as the app asks it; no title page's figure asked for; and the kit's corrections check
    /// reads the library as it reads the app's `DownloadManager`.
    @Test func theFixtureVolumesAreDownloadedWithTheirFigures() async throws {
        let f = try await Self.open(github: try Self.servingFixtures())
        defer { withExtendedLifetime(f.directory) {} }
        let job = try await f.library.download(.volumes(Self.fixtures), requestedBy: "alice")
        #expect(job.kind == .libraryDownload && job.subject == "3 volumes" && job.requestedBy == "alice")
        let done = try await Self.finished(f.queue, job)
        #expect(done.state == .succeeded && done.progress == "Downloaded 3 volumes." && done.error == nil)
        for id in Self.fixtures {
            let data = try Self.fixture(id)
            #expect(try Data(contentsOf: f.file(id)) == data, "\(id) is the fixture's file, byte for byte")
            let row = try #require(try f.row(id))
            #expect(row.state == .downloaded && row.blobSHA == VolumeUpdateChecker.gitBlobSHA1(for: data) && row.sizeBytes == data.count)
            #expect(row.downloadedAt != nil && row.error == nil && !row.sideloaded && row.requestedBy == "alice")
            #expect(f.github.count(f.github.volumeURL("\(id).xml")) == 1)
            #expect(await f.library.localVolumeInfo(for: id) == LocalVolumeInfo(sha: row.blobSHA, sizeBytes: data.count))
            #expect(await !f.library.isSideloaded(id) && f.library.isVolumeDownloaded(id))
        }
        let ve09 = try #require(try f.row("frus1969-76ve09p1"))
        #expect(ve09.figuresStored == 7 && ve09.figuresRefused == 1)
        #expect(try f.row("frus1894Nicaragua")?.figuresStored == 0 && f.row("frus1894Nicaragua")?.figuresRefused == 0)
        for name in Self.figures.dropLast() {
            #expect(try Data(contentsOf: f.figure("frus1969-76ve09p1", "\(name).png")) == FakeGitHub.png(name))
        }
        #expect(!FileManager.default.fileExists(atPath: f.figure("frus1969-76ve09p1", "WesternSahara.jpg.png").path))
        #expect(!FileManager.default.fileExists(atPath: f.volumes.appendingPathComponent("frus1894Nicaragua.figures").path),
                "a title page's figure is not one the app draws, nor fetches")
        let listing = f.github.requests.filter { $0.url == f.github.sources.listing.absoluteString }
        #expect(listing.count == 1 && listing[0].headers["Accept"] == "application/vnd.github+json")
        #expect(listing[0].headers["X-GitHub-Api-Version"] == "2022-11-28" && listing[0].headers["Authorization"] == nil)
        #expect(f.github.requests.allSatisfy { $0.headers["User-Agent"]?.hasPrefix("FRUS-Explorer-Light/") == true })
        #expect(!f.github.requests.contains { $0.url.contains("/frus/frus1894Nicaragua/") || $0.url.contains("/frus/frus1961-63v06/") })
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.volumes.path).filter { $0.hasPrefix(".") }.isEmpty, "no file left half-written")

        // The kit's corrections check, over the library.
        let catalogue = try Self.catalogue().filter { Self.fixtures.contains($0.volumeId) }
        var live = Dictionary(uniqueKeysWithValues: try Self.fixtures.map { ($0, LiveVolumeInfo(sha: VolumeUpdateChecker.gitBlobSHA1(for: try Self.fixture($0)), sizeBytes: try Self.fixture($0).count)) })
        #expect(await VolumeUpdateChecker.updatableVolumes(known: catalogue, liveInfoByVolumeId: live, downloadManager: f.library).isEmpty)
        live["frus1961-63v06"] = LiveVolumeInfo(sha: String(repeating: "a", count: 40), sizeBytes: 1)
        #expect(await VolumeUpdateChecker.updatableVolumes(known: catalogue, liveInfoByVolumeId: live, downloadManager: f.library)
            .map(\.id) == ["frus1961-63v06"])
        // A file whose length changed is hashed again, and so is one of the same length whose modification
        // time is not the one its download recorded.
        try Data("changed".utf8).write(to: f.file("frus1894Nicaragua"))
        #expect(await f.library.localVolumeInfo(for: "frus1894Nicaragua") == LocalVolumeInfo(
            sha: VolumeUpdateChecker.gitBlobSHA1(for: Data("changed".utf8)), sizeBytes: 7))
        let blanks = Data(repeating: 0x20, count: try Self.fixture("frus1961-63v06").count)
        try blanks.write(to: f.file("frus1961-63v06"))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: f.file("frus1961-63v06").path)
        #expect(await f.library.localVolumeInfo(for: "frus1961-63v06")?.sha == VolumeUpdateChecker.gitBlobSHA1(for: blanks))
    }

    /// A file is kept only once its length and blob SHA-1 are the listing's: one whose hash differs, one
    /// longer than the listing says and one the host refuses are not, and leave nothing behind; a copy in
    /// place stays when its replacement fails the check.
    @Test func aFileIsCheckedBeforeItTakesItsPlace() async throws {
        let github = FakeGitHub()
        let nicaragua = try Self.fixture("frus1894Nicaragua")
        github.serve("frus1894Nicaragua.xml", data: nicaragua, listedSHA: String(repeating: "0", count: 40))
        github.serve("frus1961-63v06.xml", data: try Self.fixture("frus1961-63v06"), listedSize: 25_000)
        github.serve("frus1969-76ve09p1.xml", data: try Self.fixture("frus1969-76ve09p1"))
        github.answer(github.volumeURL("frus1969-76ve09p1.xml"), with: LibraryAnswer(status: 404))
        let f = try await Self.open(github: github)
        defer { withExtendedLifetime(f.directory) {} }
        let done = try await Self.finished(f.queue, try await f.library.download(.volumes(Self.fixtures), requestedBy: "alice"))
        #expect(done.state == .failed && done.error == "Downloaded 0 of 3 volumes; 3 could not be downloaded, which the Library says why.")
        #expect(try f.row("frus1894Nicaragua")?.error?.hasPrefix("The file served for frus1894Nicaragua.xml is not the one GitHub's listing names, so it was not kept") == true)
        #expect(try f.row("frus1961-63v06")?.error == "The file served for frus1961-63v06.xml was longer than the 25000 bytes GitHub's listing gives it, so it was not kept.")
        #expect(try f.row("frus1969-76ve09p1")?.error == "library.test answered 404 for frus1969-76ve09p1.xml.")
        for id in Self.fixtures {
            #expect(try f.row(id)?.state == .failed && f.row(id)?.blobSHA == nil && !f.library.isVolumeDownloaded(id))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.volumes.path).isEmpty, "nothing left behind")

        // A copy in place, then a replacement whose hash is not the listing's: the copy stays.
        github.serve("frus1894Nicaragua.xml", data: nicaragua)
        #expect(try await Self.finished(f.queue, try await f.library.download(.volumes(["frus1894Nicaragua"]), requestedBy: nil)).state == .succeeded)
        let kept = try #require(try f.row("frus1894Nicaragua"))
        let changed = nicaragua + Data(" ".utf8)
        github.serve("frus1894Nicaragua.xml", data: changed, listedSHA: String(repeating: "1", count: 40), listedSize: changed.count)
        #expect(try await Self.finished(f.queue, try await f.library.download(.volumes(["frus1894Nicaragua"]), requestedBy: nil)).state == .failed)
        #expect(try Data(contentsOf: f.file("frus1894Nicaragua")) == nicaragua)
        let after = try #require(try f.row("frus1894Nicaragua"))
        #expect(after.state == .failed && after.blobSHA == kept.blobSHA && after.downloadedAt == kept.downloadedAt)
        #expect(after.error?.contains("the copy in place was kept") == true)
    }

    /// A volume whose file in place is the listing's is not downloaded again, and keeps when it was.
    @Test func aFileInPlaceThatIsTheListingsIsKept() async throws {
        let f = try await Self.open(github: try Self.servingFixtures())
        defer { withExtendedLifetime(f.directory) {} }
        let url = f.github.volumeURL("frus1969-76ve09p1.xml")
        _ = try await Self.finished(f.queue, try await f.library.download(.volumes(["frus1969-76ve09p1"]), requestedBy: nil))
        let first = try #require(try f.row("frus1969-76ve09p1"))
        // A figure image lost meanwhile is fetched again.
        try FileManager.default.removeItem(at: f.figure("frus1969-76ve09p1", "genassemblybldg.png"))
        let again = try await Self.finished(f.queue, try await f.library.download(.volumes(["frus1969-76ve09p1"]), requestedBy: nil))
        #expect(again.state == .succeeded && f.github.count(url) == 1, "the file in place is the listing's")
        #expect(try f.row("frus1969-76ve09p1")?.downloadedAt == first.downloadedAt)
        #expect(FileManager.default.fileExists(atPath: f.figure("frus1969-76ve09p1", "genassemblybldg.png").path))
    }

    /// A figure's name becomes one file name of one path component, the kit's rule: a name with a slash
    /// or a backslash, `..`, or nothing is never asked for nor written, and every other character is
    /// percent-encoded in the address; a title page's figure and a page's scan are not figures to fetch.
    @Test func noFigureNameReachesOutsideItsFolder() async throws {
        let github = FakeGitHub()
        github.serve("frus1999v99.xml", data: Data(Self.synthetic.utf8))
        github.serveFigure(Self.syntheticId, "Document A.1.png", data: FakeGitHub.png("A.1"))
        let f = try await Self.open(github: github)
        defer { withExtendedLifetime(f.directory) {} }
        let done = try await Self.finished(f.queue, try await f.library.download(.volumes([Self.syntheticId]), requestedBy: nil))
        #expect(done.state == .succeeded)
        #expect(LibraryFigureNames.graphicNames(inVolumeAt: f.file(Self.syntheticId)) == ["../../escape", "sub/dir", "..", "back\\slash", "Document A.1", "what?#%"])
        let asked = github.requests.map(\.url).filter { $0.contains("/frus/\(Self.syntheticId)/") }
        let base = github.sources.figures.absoluteString + "frus/\(Self.syntheticId)/"
        #expect(asked == [base + "Document%20A.1.png", base + "what%3F%23%25.png"])
        let folder = f.volumes.appendingPathComponent("\(Self.syntheticId).figures")
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["Document A.1.png"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.volumes.path).sorted() == ["frus1999v99.figures", "frus1999v99.xml"])
        for outside in [f.directory.url, f.directory.url.deletingLastPathComponent(), f.volumes] {
            for name in ["escape", "escape.png", "dir", "dir.png", "slash.png", "back\\slash.png"] {
                #expect(!FileManager.default.fileExists(atPath: outside.appendingPathComponent(name).path), "\(name) in \(outside.path)")
            }
        }
        #expect(try f.row(Self.syntheticId)?.figuresStored == 1 && f.row(Self.syntheticId)?.figuresRefused == 1)
        // A link where the folder of figures goes is no folder: it is replaced, and nothing is written through it.
        let elsewhere = f.directory.url.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try FileManager.default.removeItem(at: folder)
        try FileManager.default.createSymbolicLink(at: folder, withDestinationURL: elsewhere)
        _ = try await Self.finished(f.queue, try await f.library.download(.volumes([Self.syntheticId]), requestedBy: nil))
        #expect(try FileManager.default.contentsOfDirectory(atPath: elsewhere.path).isEmpty)
        #expect(VolumeLibrary.kind(at: folder) == .typeDirectory && FileManager.default.fileExists(atPath: folder.appendingPathComponent("Document A.1.png").path))
    }

    /// A cancel stops a download between two volumes: the volume being fetched is finished, and those not
    /// begun go back to what they were; one cancelled while it waits never begins.
    @Test func aCancelStopsADownloadBetweenVolumes() async throws {
        let github = try Self.servingFixtures()
        let gate = JobGate()
        github.hold(github.volumeURL("frus1961-63v06.xml"), at: gate)
        let f = try await Self.open(github: github)
        defer { withExtendedLifetime(f.directory) {} }
        let job = try await f.library.download(.volumes(Self.fixtures), requestedBy: "alice")
        await gate.untilReached()
        // Queued behind it: a second download, which is cancelled while it waits.
        let waiting = try await f.library.download(.volumes([Self.syntheticId]), requestedBy: "bob")
        #expect(try f.row(Self.syntheticId)?.state == .queued)
        #expect(try await f.queue.cancel(waiting.id, by: "alice").state == .cancelled)
        #expect(try f.row(Self.syntheticId) == nil, "a volume never downloaded has no row once its download is cancelled")
        #expect(try f.row("frus1961-63v06")?.state == .downloading && f.row("frus1969-76ve09p1")?.state == .queued)
        #expect(try await f.queue.cancel(job.id, by: "alice").state == .running, "it stops at its next step")
        gate.open()
        let done = try await Self.finished(f.queue, job)
        #expect(done.state == .cancelled && done.cancelRequestedBy == "alice")
        #expect(try f.row("frus1894Nicaragua")?.state == .downloaded && f.row("frus1961-63v06")?.state == .downloaded)
        #expect(try f.row("frus1969-76ve09p1") == nil && !f.library.isVolumeDownloaded("frus1969-76ve09p1"))
        #expect(f.github.count(f.github.volumeURL("frus1969-76ve09p1.xml")) == 0)
    }

    /// What a stopped server left, queued or downloading, is downloaded at the next start, in a job of the
    /// server's own, volume by volume: a volume it finished is not asked for again, and the file it was
    /// writing is removed first.
    @Test func aDownloadAStopLeftIsResumedAtTheNextStart() async throws {
        let f = try await Self.open(github: try Self.servingFixtures())
        defer { withExtendedLifetime(f.directory) {} }
        _ = try await Self.finished(f.queue, try await f.library.download(.volumes(["frus1894Nicaragua"]), requestedBy: "alice"))
        // As a server that stopped while it fetched the second leaves them.
        #expect(try f.store.queueLibraryDownloads(["frus1961-63v06", "frus1969-76ve09p1"], requestedBy: "alice", at: Self.start) == ["frus1961-63v06", "frus1969-76ve09p1"])
        try f.store.markLibraryDownloading("frus1961-63v06", at: Self.start)
        let partial = f.volumes.appendingPathComponent(".frus1961-63v06.xml.download")
        try Data("half".utf8).write(to: partial)
        let github = try Self.servingFixtures()
        let (queue, library) = try await f.restarted(github: github)
        try library.prepare()
        #expect(!FileManager.default.fileExists(atPath: partial.path), "the file a stopped download was writing is removed")
        let resumed = try #require(await library.resumeUnfinished())
        #expect(resumed.requestedBy == nil && resumed.subject == "2 volumes, resumed after a restart")
        #expect(try await Self.finished(queue, resumed).state == .succeeded)
        for id in Self.fixtures { #expect(try f.row(id)?.state == .downloaded && library.isVolumeDownloaded(id)) }
        #expect(github.count(github.volumeURL("frus1894Nicaragua.xml")) == 0, "a volume it finished is kept")
        #expect(github.count(github.volumeURL("frus1961-63v06.xml")) == 1 && github.count(github.volumeURL("frus1969-76ve09p1.xml")) == 1)
        #expect(await library.resumeUnfinished() == nil, "nothing is left")
    }

    /// Under FRUS_OFFLINE the library holds no transport, and in Import mode it downloads nothing: each
    /// refuses a download before anything is queued, and a stopped download is not resumed but failed,
    /// with why.
    @Test func offlineAndImportModeDownloadNothing() async throws {
        let offline = try await Self.open(github: try Self.servingFixtures(), offline: true)
        defer { withExtendedLifetime(offline.directory) {} }
        #expect(offline.library.downloadsRefusal == .offline)
        await #expect(throws: LibraryRefusal.offline) { try await offline.library.download(.all, requestedBy: "alice") }
        #expect(try offline.store.libraryVolumes().isEmpty)
        _ = try offline.store.queueLibraryDownloads(["frus1894Nicaragua"], requestedBy: "alice", at: Self.start)
        #expect(await offline.library.resumeUnfinished() == nil)
        #expect(try offline.row("frus1894Nicaragua")?.state == .failed
            && offline.row("frus1894Nicaragua")?.error == "The server started with FRUS_OFFLINE=true, so this download, which a restart stopped, was not resumed.")
        let offlineJobs = await offline.queue.jobs()
        #expect(offline.github.requests.isEmpty && offlineJobs.isEmpty, "the fake was given, and asked nothing")

        let imports = try await Self.open(github: try Self.servingFixtures(), mode: .import)
        defer { withExtendedLifetime(imports.directory) {} }
        #expect(imports.library.downloadsRefusal == .importMode && !FileManager.default.fileExists(atPath: imports.volumes.path),
                "an Import server's folder is the operator's mount, which it never makes")
        await #expect(throws: LibraryRefusal.importMode) { try await imports.library.download(.volumes(["frus1894Nicaragua"]), requestedBy: "alice") }
        await #expect(throws: LibraryRefusal.importMode) { try await imports.library.remove("frus1894Nicaragua") }
        let importJobs = await imports.queue.jobs()
        #expect(imports.github.requests.isEmpty && importJobs.isEmpty)
        // An Import server leaves aside the rows a Standalone run kept, which describe files that are not the mount's.
        try imports.store.recordLibraryDownload("frus1894Nicaragua", LibraryDownloadRecord(blobSHA: "abc", sizeBytes: 1, figuresStored: 0, figuresRefused: 0), at: Self.start)
        #expect(try imports.library.libraryVolumes().isEmpty && imports.store.libraryVolumes().count == 1)
    }

    /// GitHub's listing is read once a job, with the last answer's ETag, which a 304 answers; a token goes
    /// to GitHub's own API alone, never to its raw files or the image host, nor to a mirror; and GitHub's
    /// rate limit fails the job, saying when it lifts, and every volume with it, none asked for.
    @Test func theListingItsETagItsTokenAndGitHubsLimit() async throws {
        let clock = JobClock()
        let f = try await Self.open(github: try Self.servingFixtures(), token: "ghp_secret", clock: clock)
        defer { withExtendedLifetime(f.directory) {} }
        let listing = f.github.sources.listing
        _ = try await Self.finished(f.queue, try await f.library.download(.volumes(["frus1894Nicaragua"]), requestedBy: nil))
        _ = try await Self.finished(f.queue, try await f.library.download(.volumes(["frus1961-63v06"]), requestedBy: nil))
        #expect(f.github.count(listing) == 1, "a reading within five minutes is used as it is")
        clock.advance(by: 301)
        _ = try await Self.finished(f.queue, try await f.library.download(.volumes(["frus1969-76ve09p1"]), requestedBy: nil))
        let asked = f.github.requests.filter { $0.url == listing.absoluteString }
        #expect(asked.count == 2 && asked[0].headers["If-None-Match"] == nil && asked[1].headers["If-None-Match"]?.hasPrefix("\"") == true)
        #expect(try f.row("frus1969-76ve09p1")?.state == .downloaded, "a 304 answers with the listing kept")
        #expect(f.github.requests.allSatisfy { $0.headers["Authorization"] == nil }, "a mirror is given no token")

        let github = FakeGitHub(sources: .github)
        try github.serveFixture("frus1894Nicaragua")
        let gh = try await Self.open(github: github, token: "ghp_secret", clock: clock)
        defer { withExtendedLifetime(gh.directory) {} }
        #expect(github.sources.listing.absoluteString == "https://api.github.com/repos/HistoryAtState/frus/contents/volumes")
        #expect(try await Self.finished(gh.queue, try await gh.library.download(.volumes(["frus1894Nicaragua"]), requestedBy: nil)).state == .succeeded)
        #expect(github.requests.map(\.url) == [github.sources.listing.absoluteString,
                                               "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/frus1894Nicaragua.xml"])
        #expect(github.requests.map { $0.headers["Authorization"] } == ["Bearer ghp_secret", nil])

        clock.advance(by: 301)
        github.answer(github.sources.listing, with: LibraryAnswer(status: 403, headers: [
            "x-ratelimit-limit": "60", "x-ratelimit-remaining": "0", "x-ratelimit-reset": "1792803900"]))
        let limited = try await Self.finished(gh.queue, try await gh.library.download(.volumes(["frus1961-63v06", "frus1969-76ve09p1"]), requestedBy: nil))
        #expect(limited.state == .failed && limited.error == "GitHub's limit of 60 requests an hour for this server is reached until 2026-10-24T01:05:00Z, so its listing of the corpus's volumes could not be read.")
        #expect(try gh.row("frus1961-63v06")?.error == "Not downloaded: " + (limited.error ?? ""))
        #expect(!github.requests.contains { $0.url.hasSuffix("frus1961-63v06.xml") || $0.url.hasSuffix("frus1969-76ve09p1.xml") })
        #expect(VolumeLibrary.rateLimited(["x-ratelimit-limit": "60"], token: false)
            == "GitHub's limit of 60 requests an hour for this server is reached, so its listing of the corpus's volumes could not be read: try again then, or give the server a token (FRUS_GITHUB_TOKEN), which raises the limit.")
        github.answer(github.sources.listing, with: LibraryAnswer(status: 403))
        clock.advance(by: 301)
        let refused = try await Self.finished(gh.queue, try await gh.library.download(.volumes(["frus1961-63v06"]), requestedBy: nil))
        #expect(refused.error == "GitHub's listing of the corpus's volumes could not be read: api.github.com answered 403.")
        #expect(!(limited.error ?? "").contains("ghp_secret") && !(refused.error ?? "").contains("ghp_secret"))
    }

    /// Download All asks for every catalogue volume not downloaded, and leaves out each the listing does not
    /// name; a volume asked for alone that the listing does not name fails, saying so.
    @Test func downloadAllLeavesOutWhatTheListingDoesNotName() async throws {
        let f = try await Self.open(github: try Self.servingFixtures())
        defer { withExtendedLifetime(f.directory) {} }
        let catalogue = try Self.catalogue().count
        let all = try await f.library.download(.all, requestedBy: "alice")
        #expect(all.subject == "\(catalogue) volumes")
        let done = try await Self.finished(f.queue, all)
        #expect(done.state == .succeeded && done.progress == "Downloaded 3 volumes. \(catalogue - 3) volumes GitHub's listing does not name were left out.")
        #expect(try f.store.libraryVolumes().map(\.volumeId) == Self.fixtures.sorted())
        let alone = try await Self.finished(f.queue, try await f.library.download(.volumes([Self.syntheticId]), requestedBy: nil))
        let aloneError = try f.row(Self.syntheticId)?.error
        #expect(alone.state == .failed && aloneError == "GitHub's listing of the corpus no longer names frus1999v99.xml, so it was not downloaded.")
        await #expect(throws: LibraryRefusal.unknownVolume("frus1999v100")) { try await f.library.download(.volumes(["frus1999v100"]), requestedBy: nil) }
        await #expect(throws: LibraryRefusal.unknownVolume("../app/app.db")) { try await f.library.download(.volumes(["../app/app.db"]), requestedBy: nil) }
    }

    /// Three volumes in a row whose host gives no answer stop a download: the rest are not tried.
    @Test func aHostThatGivesNoAnswerStopsTheDownload() async throws {
        let github = try Self.servingFixtures()
        github.serve("frus1999v99.xml", data: Data(Self.synthetic.utf8))
        for id in Self.fixtures { github.leaveUnanswered(github.volumeURL("\(id).xml")) }
        let f = try await Self.open(github: github)
        defer { withExtendedLifetime(f.directory) {} }
        let done = try await Self.finished(f.queue, try await f.library.download(.volumes(Self.fixtures + [Self.syntheticId]), requestedBy: nil))
        #expect(done.state == .failed && done.error == "Downloaded 0 of 4 volumes, then stopped, since 3 volumes in a row had no answer from their host. The Library says which were not downloaded.")
        #expect(try f.row("frus1894Nicaragua")?.error == "library.test gave no answer the server takes for frus1894Nicaragua.xml.")
        #expect(try f.row(Self.syntheticId)?.error == "Not tried: the download stopped, since 3 volumes in a row had no answer from their host.")
        #expect(github.count(github.volumeURL("frus1999v99.xml")) == 0)
    }

    /// A host that says it limits this server stops the download at once, and so the rest are not tried; the
    /// image host that gives no answer for three images in a row is asked nothing more in that job, its
    /// volume kept, saying which images it lacks.
    @Test func aHostsLimitStopsTheDownloadAndAnImageHostThatDoesNotAnswerIsLeft() async throws {
        let github = try Self.servingFixtures()
        github.answer(github.volumeURL("frus1894Nicaragua.xml"), with: LibraryAnswer(status: 429, headers: ["retry-after": "60"]))
        let f = try await Self.open(github: github)
        defer { withExtendedLifetime(f.directory) {} }
        let done = try await Self.finished(f.queue, try await f.library.download(.volumes(Self.fixtures), requestedBy: nil))
        #expect(done.error == "Downloaded 0 of 3 volumes, then stopped, since library.test limits how often this server may ask it, and asks it to wait 60 seconds. The Library says which were not downloaded.")
        #expect(try f.row("frus1961-63v06")?.error == "Not tried: the download stopped, since library.test limits how often this server may ask it, and asks it to wait 60 seconds.")
        #expect(github.count(github.volumeURL("frus1961-63v06.xml")) == 0)

        let images = FakeGitHub()
        try images.serveFixture("frus1969-76ve09p1")
        for name in Self.figures {
            images.leaveUnanswered(try #require(images.sources.figure(volumeId: "frus1969-76ve09p1", fileName: "\(name).png")))
        }
        let g = try await Self.open(github: images)
        defer { withExtendedLifetime(g.directory) {} }
        #expect(try await Self.finished(g.queue, try await g.library.download(.volumes(["frus1969-76ve09p1"]), requestedBy: nil)).state == .succeeded)
        #expect(images.requests.filter { $0.url.contains("/frus/frus1969-76ve09p1/") }.count == 3, "three images with no answer, then none asked")
        let row = try #require(try g.row("frus1969-76ve09p1"))
        #expect(row.state == .downloaded && row.figuresStored == 0)
        #expect(row.error == "8 of its figure images were not fetched, since library.test gave no answer for 3 images in a row: Download asks for them again.")
    }

    /// Remove takes a downloaded volume's file and figure images away and forgets it; it is refused while a
    /// download waits for the volume, for one not downloaded, and for an id the catalogue lacks.
    @Test func removeTakesAVolumesFilesAway() async throws {
        let github = try Self.servingFixtures()
        let f = try await Self.open(github: github)
        defer { withExtendedLifetime(f.directory) {} }
        _ = try await Self.finished(f.queue, try await f.library.download(.volumes(["frus1969-76ve09p1"]), requestedBy: nil))
        try await f.library.remove("frus1969-76ve09p1")
        #expect(!FileManager.default.fileExists(atPath: f.file("frus1969-76ve09p1").path))
        #expect(!FileManager.default.fileExists(atPath: f.volumes.appendingPathComponent("frus1969-76ve09p1.figures").path))
        #expect(try f.row("frus1969-76ve09p1") == nil)
        await #expect(throws: LibraryRefusal.notDownloaded("frus1969-76ve09p1")) { try await f.library.remove("frus1969-76ve09p1") }
        await #expect(throws: LibraryRefusal.unknownVolume("../volumes")) { try await f.library.remove("../volumes") }
        // Held at its volume's own request: the listing of the first download is used as it is, and not asked for.
        let gate = JobGate()
        github.hold(github.volumeURL("frus1894Nicaragua.xml"), at: gate)
        let job = try await f.library.download(.volumes(["frus1894Nicaragua"]), requestedBy: nil)
        await gate.untilReached()
        await #expect(throws: LibraryRefusal.inProgress("frus1894Nicaragua")) { try await f.library.remove("frus1894Nicaragua") }
        await #expect(throws: LibraryRefusal.inProgress("frus1894Nicaragua")) {
            try await f.library.download(.volumes(["frus1894Nicaragua"]), requestedBy: nil)
        }
        gate.open()
        _ = try await Self.finished(f.queue, job)
    }

    /// A Standalone server's folder is made at its start; one it cannot write keeps it from starting.
    @Test func aFolderTheServerCannotWriteKeepsItFromStarting() async throws {
        let (store, _, directory) = try await UserTagTests.open()
        defer { withExtendedLifetime(directory) {} }
        let file = directory.url.appendingPathComponent("volumes")
        try Data("a file where the folder goes".utf8).write(to: file)
        let library = VolumeLibrary(volumesDirectory: file, store: store, jobs: InProcessJobQueue(), catalogue: [],
                                    sources: .github, transport: nil, mode: .standalone)
        #expect { try library.prepare() } throws: { error in
            (error as? LibraryFolderError)?.description.hasPrefix("In Standalone mode the server keeps the volumes it downloads in \(file.path), which it cannot write") == true
        }
    }

    /// The addresses: GitHub's are the kit's `downloadUrl` and the app's figure library's; a mirror's hold
    /// each host's files under its name.
    @Test func theAddressesAreTheKitsAndTheAppsOrAMirrorsOfThem() throws {
        let entry = try #require(try Self.catalogue().first { $0.volumeId == "frus1969-76ve09p1" })
        #expect(LibrarySources.github.volume(entry)?.absoluteString == entry.downloadUrl)
        #expect(LibrarySources.github.figure(volumeId: entry.volumeId, fileName: "OpenPitMine.jpg.png")?.absoluteString
            == "https://static.history.state.gov/frus/frus1969-76ve09p1/OpenPitMine.jpg.png")
        let mirror = LibrarySources.mirror(URL(string: "http://library:8000/mirror")!)
        #expect(mirror.listing.absoluteString == "http://library:8000/mirror/api.github.com/repos/HistoryAtState/frus/contents/volumes")
        #expect(mirror.volume(entry)?.absoluteString == "http://library:8000/mirror/raw.githubusercontent.com/HistoryAtState/frus/master/volumes/frus1969-76ve09p1.xml")
        #expect(mirror.figure(volumeId: entry.volumeId, fileName: "Document A.1.png")?.absoluteString
            == "http://library:8000/mirror/static.history.state.gov/frus/frus1969-76ve09p1/Document%20A.1.png")
        #expect(!mirror.isGitHub && LibrarySources.github.isGitHub)
        for bad in ["", ".", "..", "a/b", "a\\b", "a\0b"] {
            #expect(mirror.figure(volumeId: entry.volumeId, fileName: bad) == nil && mirror.figure(volumeId: bad, fileName: "x.png") == nil)
        }
    }

    // MARK: The store

    /// `library_volumes` on both stores: a volume queued once however often it is asked for while it waits,
    /// its download recorded with its file's hash and length, a failure keeping what the row says of a file
    /// in place, a withdrawal putting a volume back as it was, and a restart queueing again what a stopped
    /// server left, the earliest asked for first.
    @Test(arguments: UserStoreKind.available)
    func theLibrarysVolumesAsTheStoreKeepsThem(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        let (t1, t2, t3) = (Self.start, Self.start.addingTimeInterval(60), Self.start.addingTimeInterval(120))
        #expect(try store.queueLibraryDownloads(["b", "a", "b"], requestedBy: "alice", at: t1) == ["b", "a"])
        #expect(try store.queueLibraryDownloads(["a", "c"], requestedBy: nil, at: t2) == ["c"], "a waits already")
        let a = try #require(try store.libraryVolume("a"))
        #expect(a == LibraryVolume(volumeId: "a", state: .queued, requestedBy: "alice", queuedAt: t1, updatedAt: t1))
        try store.markLibraryDownloading("a", at: t2)
        #expect(try store.unfinishedLibraryDownloads().map(\.volumeId) == ["a", "b", "c"])
        #expect(try store.libraryVolume("a")?.state == .downloading)
        #expect(try store.requeueUnfinishedLibraryDownloads(at: t3).map { "\($0.volumeId) \($0.state)" } == ["a queued", "b queued", "c queued"])
        let record = LibraryDownloadRecord(blobSHA: "abc", sizeBytes: 12, modifiedAt: t1, figuresStored: 3, figuresRefused: 1)
        try store.recordLibraryDownload("a", record, at: t1)
        #expect(try store.libraryVolume("a")?.modifiedAt == t1)
        try store.recordLibraryDownload("a", LibraryDownloadRecord(blobSHA: "abc", sizeBytes: 12, figuresStored: 4, figuresRefused: 0), at: t2)
        var downloaded = try #require(try store.libraryVolume("a"))
        #expect(downloaded.state == .downloaded && downloaded.blobSHA == "abc" && downloaded.sizeBytes == 12 && downloaded.figuresStored == 4)
        #expect(downloaded.downloadedAt == t1 && downloaded.updatedAt == t2, "the same file keeps when it was downloaded")
        try store.recordLibraryDownload("a", LibraryDownloadRecord(blobSHA: "def", sizeBytes: 13, figuresStored: 0, figuresRefused: 0, problem: "Two figures failed."), at: t3)
        downloaded = try #require(try store.libraryVolume("a"))
        #expect(downloaded.downloadedAt == t3 && downloaded.error == "Two figures failed." && !downloaded.sideloaded)
        try store.recordLibraryFailure("a", error: "It failed.", at: t3)
        #expect(try store.libraryVolume("a")?.state == .failed && store.libraryVolume("a")?.blobSHA == "def" && store.libraryVolume("a")?.error == "It failed.")
        try store.recordLibraryFailure("d", error: "Never listed.", at: t3)
        #expect(try store.libraryVolume("d") == LibraryVolume(volumeId: "d", state: .failed, error: "Never listed.", updatedAt: t3))
        // A withdrawal leaves a failure as it is, puts a queued volume with a file back as downloaded, and
        // forgets one with none.
        #expect(try store.queueLibraryDownloads(["a"], requestedBy: "bob", at: t3) == ["a"])
        try store.withdrawLibraryDownloads(["a", "b", "d"], at: t3)
        #expect(try store.libraryVolume("a")?.state == .downloaded && store.libraryVolume("a")?.error == nil && store.libraryVolume("a")?.blobSHA == "def")
        #expect(try store.libraryVolume("b") == nil && store.libraryVolume("d")?.state == .failed)
        #expect(try store.forgetLibraryVolume("a") == .forgotten && store.forgetLibraryVolume("a") == .nothing)
        #expect(try store.forgetLibraryVolume("c") == .heldByADownload && store.libraryVolume("c")?.state == .queued, "a download holds it")
        #expect(try store.libraryVolumes().map(\.volumeId) == ["c", "d"] && store.unfinishedLibraryDownloads().map(\.volumeId) == ["c"])
    }
}
