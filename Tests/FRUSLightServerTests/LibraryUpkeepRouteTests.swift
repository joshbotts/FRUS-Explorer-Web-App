// A Standalone server's side-load and the index's upkeep through the router (PLAN's S21e): a side-loaded
// volume, which the catalogue overlay lists, read and cited with the app's sentence; the side-load's
// refusals, its file read with the parser's external entities off; a volume removed, gone from search,
// Browse and the reader; the index compacted and checked; and Standalone's reset, which empties the index
// and indexes the library again.

@testable import FRUSCoreKit
@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite(.timeLimit(.minutes(3))) struct LibraryUpkeepRouteTests {
    typealias Fixture = LibraryIndexingRouteTests.Fixture
    static let library = "/api/v1/admin/library"
    static let sideload = "/api/v1/admin/library/sideload"

    /// A copy of a fixture volume's TEI, to side-load under another name.
    static func fixtureXML(_ volumeId: String = "frus1894Nicaragua") throws -> String {
        try String(contentsOf: RepositoryFiles.tei.appendingPathComponent("\(volumeId).xml"), encoding: .utf8)
    }

    static func sideload(_ owner: Browser, file: String, _ xml: String, type: String = "application/xml") async throws -> TestResponse {
        try await owner.send(.post, "\(Self.sideload)?file=\(file.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? file)",
                             xml, contentType: type)
    }

    /// The row's done-when: a side-loaded fixture volume is read and cited with the sentence. Its file, under
    /// an id the catalogue lacks, is checked by the kit's validator, kept with `sideloaded = 1`, listed by the
    /// catalogue overlay from its own header, indexed in a job, found by search, read by the reader and
    /// Browse, and cited with the app's sentence and no history.state.gov link; and side-loaded again, it
    /// is refused, as the app refuses a volume already present.
    @Test func aSideloadedVolumeIsReadAndCitedWithTheAppsSentence() async throws {
        let fixture = try await Fixture(volumes: [])
        defer { withExtendedLifetime(fixture) {} }
        let id = "frus1894Nicaragua-draft"
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(problemCode(try await owner.get("/api/v1/volumes/\(id)")) == "VOLUME_NOT_FOUND")
            let posted = try await Self.sideload(owner, file: "\(id).xml", try Self.fixtureXML())
            #expect(posted.status == .accepted, "\(problemCode(posted) ?? "")")
            let answer = try decode(AdminLibrary.Sideload.self, posted)
            #expect(answer.volumeId == id && !answer.catalogued && answer.job.kind == "libraryIndex" && answer.job.subject == id)
            await fixture.users.jobs.waitUntilIdle()
            #expect(try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(answer.job.id)")).state == "succeeded")

            // The store's row, the Library's, Browse's and the reader's.
            let row = try #require(try fixture.users.store.libraryVolume(id))
            #expect(row.sideloaded && row.state == .downloaded && row.blobSHA != nil && row.sizeBytes != nil && row.figuresStored == 0)
            let listed = try #require(try decode(AdminLibrary.self, try await owner.get(Self.library)).volumes.first { $0.volumeId == id })
            #expect(listed.sideloaded && listed.status == "indexed" && listed.downloaded, "\(listed)")
            let volume = try decode(Volume.self, try await owner.get("/api/v1/volumes/\(id)"))
            #expect(volume.sideloaded == true && volume.indexed && volume.teiAvailable && volume.title.contains("Nicaragua"), "\(volume.title)")
            #expect(volume.subseries == "1894")
            let browse = try decode(VolumeList.self, try await owner.get("/api/v1/volumes?limit=1&offset=553"))
            #expect(browse.total == 554 && browse.items.first?.volumeId == id)
            #expect(try await owner.get("/api/v1/volumes/\(id)/documents/d1/html?part=body").status == .ok)
            let detail = try await owner.get("/api/v1/volumes/\(id)/documents/d1")
            #expect(detail.status == .ok && !String(buffer: detail.body).contains("history.state.gov"))
            let found = try decode(SearchResultList.self, try await owner.get("/api/v1/search?keywords=nicaragua"))
            #expect(found.total > 0 && found.items.allSatisfy { $0.volumeId == id })

            // Its citation carries the app's sentence, and no link to a page history.state.gov may not have.
            let cited = try decode(DocumentCitation.self, try await owner.get("/api/v1/volumes/\(id)/documents/d1/citation"))
            #expect(cited.provenanceNote == CitationRoutes.sideloadedNote)
            #expect(cited.canonicalURL == nil && !cited.bibtex.contains("history.state.gov") && !cited.ris.contains("history.state.gov"))
            let catalogued = try decode(DocumentCitation.self,
                                        try await owner.get("/api/v1/volumes/frus1894Nicaragua/documents/d1/citation"))
            #expect(catalogued.provenanceNote == nil && catalogued.canonicalURL != nil, "a catalogue volume's, as before")

            // Present already: refused, in the kit's words.
            let again = try await Self.sideload(owner, file: "\(id).xml", try Self.fixtureXML())
            #expect(problemCode(again) == "VOLUME_EXISTS" && again.status == .conflict)
        }
    }

    /// The side-load refuses a name that becomes no single, visible file name, a body that is not XML or
    /// not a FRUS volume, one larger than 64 MiB by its length, and an Import server; and nothing of a
    /// refused file is left in the volumes folder.
    @Test func theSideloadRefusesWhatIsNoVolume() async throws {
        let fixture = try await Fixture(volumes: [])
        defer { withExtendedLifetime(fixture) {} }
        let folder = fixture.users.server.files.volumesDirectory
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let xml = try Self.fixtureXML()
            for name in ["../escape.xml", ".hidden.xml", "a/b.xml", "frus1894Nicaragua.txt", "frus1894Nicaragua", "x.figures.xml",
                         String(repeating: "v", count: 129) + ".xml", "volume id.xml", ""] {
                #expect(problemCode(try await Self.sideload(owner, file: name, xml)) == "INVALID_FILE_NAME", "\(name)")
            }
            #expect(problemCode(try await owner.send(.post, Self.sideload, xml, contentType: "application/xml")) == "INVALID_FILE_NAME")
            #expect(problemCode(try await Self.sideload(owner, file: "frusX.xml", xml, type: "application/json")) == "UNSUPPORTED_MEDIA_TYPE")
            #expect(problemCode(try await Self.sideload(owner, file: "frusX.xml", "<html><body>not a volume</body></html>")) == "NOT_A_VOLUME")
            #expect(problemCode(try await Self.sideload(owner, file: "frusX.xml", "this is not XML at all")) == "NOT_A_VOLUME")
            // A body its length says is larger than 64 MiB is refused before it is read.
            var headers = HTTPFields()
            headers[.origin] = "http://localhost:8080"
            headers[CSRFTokens.header] = try await owner.me().csrfToken
            headers[.contentType] = "application/xml"
            headers[.contentLength] = String(VolumeLibrary.sideloadLimit + 1)
            let large = try await client.execute(uri: "\(Self.sideload)?file=frusX.xml", method: .post, headers: headers,
                                                 body: ByteBuffer(string: "<TEI/>"))
            #expect(problemCode(large) == "CONTENT_TOO_LARGE")
        }
        let left = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(left.filter { !$0.hasPrefix(".write-check") }.isEmpty, "\(left)")

        let imports = try await Fixture(mode: .import, volumes: [])
        defer { withExtendedLifetime(imports) {} }
        try await imports.app.test(.router) { client in
            #expect(problemCode(try await Self.sideload(Browser(client: client), file: "frusX.xml", try Self.fixtureXML())) == "LIBRARY_NOT_AVAILABLE")
        }
    }

    /// A side-loaded file is parsed with the parser's external entities off: an external entity naming a file
    /// of the server's is never read into the index or the reader's page; and an entity that expands without
    /// end stops each parse, the header's, which refuses the file of a volume the catalogue lacks, and the
    /// indexer's, which lists a catalogue volume's file failed, as a volume that does not parse is.
    @Test func aSideloadedFilesExternalEntitiesAreNeverRead() async throws {
        let fixture = try await Fixture(volumes: [])
        defer { withExtendedLifetime(fixture) {} }
        let secret = fixture.users.server.files.root.appendingPathComponent("secret.txt")
        try "zqxjvorpal is the server's secret".write(to: secret, atomically: true, encoding: .utf8)
        let entity = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE TEI [<!ENTITY secret SYSTEM "\(secret.absoluteString)">]>
            <TEI xmlns="http://www.tei-c.org/ns/1.0"><teiHeader><fileDesc><titleStmt><title type="complete">A volume naming a file</title></titleStmt></fileDesc></teiHeader>
            <text><body><div type="document" xml:id="d1" n="1"><head>One</head><p>Before &secret; after.</p></div></body></text></TEI>
            """
        var bomb = "<?xml version=\"1.0\"?>\n<!DOCTYPE TEI [\n<!ENTITY a \"aaaaaaaaaa\">\n"
        for level in 1...9 { bomb += "<!ENTITY a\(level) \"" + String(repeating: "&a\(level == 1 ? "" : String(level - 1));", count: 10) + "\">\n" }
        bomb += "]>\n<TEI xmlns=\"http://www.tei-c.org/ns/1.0\"><teiHeader><fileDesc><titleStmt><title>A bomb</title></titleStmt></fileDesc></teiHeader>"
        bomb += "<text><body><div type=\"document\" xml:id=\"d1\"><p>&a9;</p></div></body></text></TEI>\n"
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await Self.sideload(owner, file: "frus2001entity.xml", entity).status == .accepted)
            #expect(problemCode(try await Self.sideload(owner, file: "frus2001bomb.xml", bomb)) == "NOT_A_VOLUME")
            let catalogued = try await Self.sideload(owner, file: "frus1964-68v01.xml", bomb)
            #expect(catalogued.status == .accepted)
            #expect(try decode(AdminLibrary.Sideload.self, catalogued).catalogued, "a catalogue volume's id")
            await fixture.users.jobs.waitUntilIdle()
            #expect(try decode(SearchResultList.self, try await owner.get("/api/v1/search?keywords=zqxjvorpal")).total == 0)
            #expect(try decode(SearchResultList.self, try await owner.get("/api/v1/search?keywords=before")).total > 0, "the document is indexed")
            let page = try await owner.get("/api/v1/volumes/frus2001entity/documents/d1/html?part=body")
            #expect(page.status == .ok && !String(buffer: page.body).contains("zqxjvorpal"))
            let listed = try decode(AdminLibrary.self, try await owner.get(Self.library)).volumes
            #expect(!listed.contains { $0.volumeId == "frus2001bomb" })
            let bombed = try #require(listed.first { $0.volumeId == "frus1964-68v01" })
            #expect(bombed.status == "failed" && bombed.error?.contains("could not be parsed") == true, "\(bombed)")
        }
    }

    /// The row's done-when: a volume removed is gone from search, Browse and the reader. Remove of an indexed
    /// volume is a job, the index's one writer: the kit's `removeVolume`, then its file; the other volume
    /// stays; and a removal refuses what holds the volume meanwhile.
    @Test func aRemovedVolumeIsGoneFromSearchBrowseAndTheReader() async throws {
        let fixture = try await Fixture(volumes: ["frus1894Nicaragua", "frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await owner.send(.post, LibraryIndexingRouteTests.index, #"{"all":true}"#).status == .accepted)
            await fixture.users.jobs.waitUntilIdle()
            #expect(try decode(SearchResultList.self, try await owner.get("/api/v1/search?keywords=nicaragua")).total > 0)
            #expect(try await owner.get("/api/v1/volumes/frus1894Nicaragua/documents/d1/html?part=body").status == .ok)

            let removal = try await owner.send(.delete, "\(Self.library)/volumes/frus1894Nicaragua")
            #expect(removal.status == .accepted, "\(problemCode(removal) ?? "")")
            let job = try decode(AdminJob.self, removal)
            #expect(job.kind == "libraryRemove" && job.subject == "frus1894Nicaragua")
            await fixture.users.jobs.waitUntilIdle()
            let ended = try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(job.id)"))
            #expect(ended.state == "succeeded" && ended.progress == "Removed frus1894Nicaragua from the index and the library.", "\(ended)")

            #expect(try decode(SearchResultList.self, try await owner.get("/api/v1/search?keywords=nicaragua")).total == 0)
            #expect(try decode(SearchResultList.self, try await owner.get("/api/v1/search?keywords=khrushchev")).total > 0)
            let volume = try decode(Volume.self, try await owner.get("/api/v1/volumes/frus1894Nicaragua"))
            #expect(!volume.indexed && volume.indexedDocuments == 0 && !volume.teiAvailable)
            #expect(try await owner.get("/api/v1/volumes/frus1894Nicaragua/documents/d1/html?part=body").status == .notFound)
            #expect(problemCode(try await owner.get("/api/v1/volumes/frus1894Nicaragua/documents/d1")) != nil)
            let listed = try LibraryIndexingRouteTests.volume(try decode(AdminLibrary.self, try await owner.get(Self.library)), "frus1894Nicaragua")
            #expect(listed.status == "notDownloaded" && !listed.indexed && !listed.downloaded)
            #expect(problemCode(try await owner.send(.delete, "\(Self.library)/volumes/frus1894Nicaragua")) == "VOLUME_NOT_DOWNLOADED")
            #expect(fixture.indexer.stamps.removals().isEmpty)
        }
    }

    /// The row's done-when, in Swift beside the smoke test's: the index is compacted, giving back the room a
    /// removal left, and checked; the index's room is read; and an Import server compacts and checks nothing.
    @Test func theIndexIsCompactedAndChecked() async throws {
        let fixture = try await Fixture(volumes: ["frus1894Nicaragua", "frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await owner.send(.post, LibraryIndexingRouteTests.index, #"{"all":true}"#).status == .accepted)
            await fixture.users.jobs.waitUntilIdle()
            #expect(try await owner.send(.delete, "\(Self.library)/volumes/frus1961-63v06").status == .accepted)
            await fixture.users.jobs.waitUntilIdle()

            let room = try decode(AdminIndex.self, try await owner.get("/api/v1/admin/index"))
            let storage = try #require(room.storage)
            #expect(room.mode == "standalone" && room.upkeep && storage.reclaimableBytes > 0 && storage.compaction == "notWorthwhile", "\(room)")
            #expect(storage.requiredBytes == IndexCompactionRule.required(IndexPageStatistics(fileBytes: storage.fileBytes,
                                                                                                    reclaimableBytes: storage.reclaimableBytes)))

            let compacted = try await owner.send(.post, "/api/v1/admin/index/compact")
            #expect(compacted.status == .accepted, "\(problemCode(compacted) ?? "")")
            let compaction = try decode(AdminJob.self, compacted)
            await fixture.users.jobs.waitUntilIdle()
            let done = try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(compaction.id)"))
            #expect(done.kind == "indexCompact" && done.state == "succeeded" && done.progress?.hasPrefix("Compacted the index from") == true, "\(done)")
            let after = try #require(try decode(AdminIndex.self, try await owner.get("/api/v1/admin/index")).storage)
            #expect(after.fileBytes < storage.fileBytes && after.reclaimableBytes < storage.reclaimableBytes, "\(after) after \(storage)")
            #expect(try decode(SearchResultList.self, try await owner.get("/api/v1/search?keywords=nicaragua")).total > 0, "served again")

            let checked = try decode(AdminJob.self, try await owner.send(.post, "/api/v1/admin/index/check"))
            await fixture.users.jobs.waitUntilIdle()
            let check = try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(checked.id)"))
            #expect(check.kind == "indexCheck" && check.state == "succeeded" && check.progress?.hasPrefix("The index's check found no problems") == true,
                    "\(check)")
        }

        let imports = try await Fixture(mode: .import, volumes: [])
        defer { withExtendedLifetime(imports) {} }
        try await imports.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(problemCode(try await owner.send(.post, "/api/v1/admin/index/compact")) == "UPKEEP_NOT_AVAILABLE")
            #expect(problemCode(try await owner.send(.post, "/api/v1/admin/index/check")) == "UPKEEP_NOT_AVAILABLE")
            #expect(try decode(AdminIndex.self, try await owner.get("/api/v1/admin/index")).upkeep == false)
        }
    }

    /// Standalone's reset empties the index the server serves, with the kit's `removeAllVolumesFromIndex()`,
    /// forgets its stamps and records, and queues the indexing of every volume the library holds, after
    /// which search answers as before.
    @Test func aStandaloneResetEmptiesTheIndexAndIndexesTheLibraryAgain() async throws {
        let fixture = try await Fixture(volumes: ["frus1894Nicaragua", "frus1961-63v06"])
        defer { withExtendedLifetime(fixture) {} }
        try fixture.breakVolume("frus1961-63v06")
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await owner.send(.post, LibraryIndexingRouteTests.index, #"{"all":true}"#).status == .accepted)
            await fixture.users.jobs.waitUntilIdle()
            #expect(fixture.indexer.stamps.failures().keys.sorted() == ["frus1961-63v06"])
            let before = try decode(SearchResultList.self, try await owner.get("/api/v1/search?keywords=nicaragua")).total
            try FileManager.default.removeItem(at: fixture.users.server.files.volumesDirectory.appendingPathComponent("frus1961-63v06.xml"))
            try RepositoryFiles.mountTEI(["frus1961-63v06"], at: fixture.users.server.files.volumesDirectory)

            let reset = try await owner.send(.post, "/api/v1/admin/index/reset")
            #expect(reset.status == .accepted, "\(problemCode(reset) ?? "")")
            let job = try decode(AdminJob.self, reset)
            #expect(job.kind == "indexReset")
            await fixture.users.jobs.waitUntilIdle()
            let ended = try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(job.id)"))
            #expect(ended.state == "succeeded" && ended.progress?.hasPrefix("Emptied the index of 139 documents from 1 volumes: job") == true, "\(ended)")
            let jobs = try decode(AdminJobList.self, try await owner.get("/api/v1/admin/jobs")).jobs
            let again = try #require(jobs.first { $0.kind == "libraryIndex" })
            #expect(again.state == "succeeded" && again.progress == "Indexed 2 volumes.", "\(again)")
            #expect(try decode(SearchResultList.self, try await owner.get("/api/v1/search?keywords=nicaragua")).total == before)
            #expect(fixture.indexer.stamps.failures().isEmpty, "the stamps begin again")
            #expect(await fixture.users.server.state.index?.documentsByVolume == ["frus1894Nicaragua": 139, "frus1961-63v06": 123])
        }
    }
}
