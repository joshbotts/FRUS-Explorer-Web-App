// The API under /api/v1 through the router: problem details, the catalogue, and the reader.
// FRUSParityTests checks the reader's HTML against every golden row; these check the routes.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import Testing

@testable import FRUSLightAPI

/// A response's problem details, after checking it is one with `status`.
func problem(_ response: TestResponse, _ status: HTTPResponse.Status, sourceLocation: SourceLocation = #_sourceLocation) throws -> APIProblem.Body {
    #expect(response.status == status, sourceLocation: sourceLocation)
    #expect(response.headers[.contentType] == APIProblem.contentType, sourceLocation: sourceLocation)
    let body = try decode(APIProblem.Body.self, response)
    #expect(body.type == "about:blank" && body.status == Int(status.code) && body.title == status.reasonPhrase, sourceLocation: sourceLocation)
    return body
}

@Suite struct ProblemTests {
    @Test func anUnknownAPIPathIsAProblem() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let body = try problem(try await client.execute(uri: "/api/v1/nothing-here?x=1", method: .get), .notFound)
            #expect(body.code == "NOT_FOUND" && body.instance == "/api/v1/nothing-here")
            #expect(body.searchError == nil)
            // A known path with another method is not found either.
            #expect(try problem(try await client.execute(uri: "/api/v1/volumes", method: .delete), .notFound).code == "NOT_FOUND")
        }
    }

    @Test func otherPathsKeepHummingbirdsAnswer() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/nothing-here", method: .get)
            #expect(response.status == .notFound)
            #expect(response.headers[.contentType] != APIProblem.contentType)
        }
    }

    @Test func theBodyIsRFC9457sWithTheCodeAndTheSearchRefusal() throws {
        let problem = APIProblem(.badRequest, code: "EMPTY_QUERY", detail: "The query is empty.", searchError: "emptyQuery")
        let body = problem.body(instance: "/api/v1/search")
        #expect(body == APIProblem.Body(type: "about:blank", title: "Bad Request", status: 400, detail: "The query is empty.",
                                        instance: "/api/v1/search", code: "EMPTY_QUERY", searchError: "emptyQuery"))
    }

    /// An error no route expected is a 500 that names nothing internal; the log has the rest.
    @Test func anUnexpectedErrorIsAProblemThatHidesItsCause() async throws {
        struct Secret: Error {}
        let router = Router()
        router.add(middleware: ProblemMiddleware(logger: Logger(label: "test")))
        router.get("/api/v1/broken") { _, _ -> String in throw Secret() }
        try await Application(router: router).test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/broken", method: .get)
            let body = try problem(response, .internalServerError)
            #expect(body.code == "INTERNAL_ERROR" && !body.detail.contains("Secret"))
        }
    }

    @Test func theStatusRefusesParametersItDoesNotTake() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/status?verbose=true", method: .get)
            #expect(try problem(response, .badRequest).code == "UNKNOWN_PARAMETER")
        }
    }

    @Test func aMalformedQueryStringIsRefused() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for uri in ["/api/v1/volumes?limit=%ZZ", "/api/v1/volumes?subseries=%FF"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(try problem(response, .badRequest).code == "MALFORMED_QUERY", "\(uri)")
            }
        }
    }
}

@Suite struct CatalogTests {
    @Test func theCatalogueListsThe553VolumesWithCoverage() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/volumes?limit=1000", method: .get)
            #expect(response.status == .ok)
            let list = try decode(VolumeList.self, response)
            #expect(list.total == 553 && list.items.count == 553 && list.limit == 1000 && list.offset == 0)
            #expect(list.coverage == Coverage(indexedVolumes: 0, indexedDocuments: 0, manifestVolumes: 553, indexVersion: nil))
            #expect(list.items.map(\.volumeId) == fixture.resources.manifest.map(\.volumeId))
            #expect(list.items.allSatisfy { !$0.indexed && $0.indexedDocuments == 0 && !$0.teiAvailable })
            // The draft's default page.
            let first = try decode(VolumeList.self, try await client.execute(uri: "/api/v1/volumes", method: .get))
            #expect(first.items.count == 20 && first.limit == 20 && first.items.first?.volumeId == "frus1861")
        }
    }

    @Test func aVolumeIsTheManifestsEntryAndWhatTheServerHolds() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        try SyntheticExport().write(to: fixture.files.liveIndex)
        await fixture.state.openExistingIndex(files: fixture.files)
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/volumes/frus1961-63v06", method: .get)
            #expect(response.status == .ok)
            let volume = try decode(Volume.self, response)
            #expect(volume.volumeId == "frus1961-63v06" && volume.filename == "frus1961-63v06.xml")
            #expect(volume.subseries == "1961-63" && volume.status == "published" && volume.publicationDate == "1996")
            #expect(volume.generalEditor == "Glenn W. LaFantasie" && volume.tags.count == 30 && volume.sizeBytes == 1_646_822)
            #expect(volume.dateRange.earliest == "1960-11-09T00:00:00-05:00")
            // The synthetic export holds two of its documents; its TEI is not mounted.
            #expect(volume.indexed && volume.indexedDocuments == 2 && !volume.teiAvailable)
            // The kit's provenance is not part of the API.
            #expect(!String(buffer: response.body).contains("provenance"))

            let nicaragua = try decode(Volume.self, try await client.execute(uri: "/api/v1/volumes/frus1894Nicaragua", method: .get))
            #expect(nicaragua.indexed && nicaragua.indexedDocuments == 1 && nicaragua.teiAvailable)

            let list = try decode(VolumeList.self, try await client.execute(uri: "/api/v1/volumes?subseries=1894", method: .get))
            #expect(list.coverage == Coverage(indexedVolumes: 2, indexedDocuments: 3, manifestVolumes: 553, indexVersion: 65))
        }
    }

    @Test func theListFiltersAndPagesAsTheDraftSays() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            func list(_ query: String) async throws -> VolumeList {
                try decode(VolumeList.self, try await client.execute(uri: "/api/v1/volumes?\(query)", method: .get))
            }
            let partial = try await list("status=partiallyPublished")
            #expect(partial.total == 3 && partial.items.allSatisfy { $0.status == "partiallyPublished" })
            let kennedy = try await list("subseries=1961-63&status=published&limit=10&offset=20")
            #expect(kennedy.total == 27 && kennedy.items.count == 7 && kennedy.offset == 20)
            #expect(kennedy.items.allSatisfy { $0.subseries == "1961-63" })
            #expect(try await list("subseries=1961-63&offset=27").items.isEmpty)
            #expect(try await list("subseries=none").total == 0)
        }
    }

    @Test func badParametersAreRefusedByName() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for (query, code, named) in [
                ("limit=0", "INVALID_PARAMETER", "limit"), ("limit=1001", "INVALID_PARAMETER", "limit"),
                ("limit=ten", "INVALID_PARAMETER", "limit"), ("offset=-1", "INVALID_PARAMETER", "offset"),
                ("status=planned2", "INVALID_PARAMETER", "status"), ("limit=5&limit=6", "INVALID_PARAMETER", "limit"),
                ("sort=title", "UNKNOWN_PARAMETER", "sort"),
            ] {
                let body = try problem(try await client.execute(uri: "/api/v1/volumes?\(query)", method: .get), .badRequest)
                #expect(body.code == code && body.detail.hasPrefix(named), "\(query): \(body.detail)")
            }
        }
    }

    @Test func anUnknownVolumeIsNotFound() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for id in ["frus1969-76v99", "FRUS1894NICARAGUA", "frus1894Nicaragua.xml"] {
                let body = try problem(try await client.execute(uri: "/api/v1/volumes/\(id)", method: .get), .notFound)
                #expect(body.code == "VOLUME_NOT_FOUND", "\(id)")
            }
        }
    }
}

@Suite struct ReaderTests {
    static func uri(_ volume: String, _ document: String, _ query: String = "part=body") -> String {
        "/api/v1/volumes/\(volume)/documents/\(document)/html?\(query)"
    }

    @Test func theBodyIsTheKitsHTMLWithTheReadersHeaders() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: Self.uri("frus1894Nicaragua", "d1"), method: .get)
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "text/html; charset=utf-8")
            #expect(response.headers[.xContentTypeOptions] == "nosniff")
            #expect(response.headers[.contentSecurityPolicy]?.hasPrefix("default-src 'none'") == true)
            let version = try #require(response.headers[ReaderRoutes.renderingVersionHeader])
            #expect(version.count == 16 && version.allSatisfy(\.isHexDigit))
            let html = String(buffer: response.body)
            #expect(!html.isEmpty && !html.contains("<body>") && !html.contains("<html"))
            // The draft's appearance parameters are taken, and do not change the body.
            let dark = try await client.execute(uri: Self.uri("frus1894Nicaragua", "d1", "part=body&colorScheme=dark&textSize=extraLarge"), method: .get)
            #expect(String(buffer: dark.body) == html)
        }
    }

    /// The reader needs no index, so it answers while /readyz says the server is waiting.
    @Test func theReaderAnswersBeforeAnyImport() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1961-63v06"])
        try await fixture.app.test(.router) { client in
            let readiness = try await client.execute(uri: "/readyz", method: .get)
            let reader = try await client.execute(uri: Self.uri("frus1961-63v06", "d1"), method: .get)
            #expect(readiness.status == .serviceUnavailable)
            #expect(reader.status == .ok)
        }
    }

    @Test func eachWayARequestFailsIsAProblem() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        try await fixture.app.test(.router) { client in
            func body(_ uri: String, _ status: HTTPResponse.Status) async throws -> APIProblem.Body {
                try problem(try await client.execute(uri: uri, method: .get), status)
            }
            #expect(try await body(Self.uri("frus1969-76v99", "d1"), .notFound).code == "VOLUME_NOT_FOUND")
            let notMounted = try await body(Self.uri("frus1961-63v06", "d1"), .notFound)
            #expect(notMounted.code == "TEI_NOT_AVAILABLE" && notMounted.detail.contains("frus1961-63v06.xml"))
            #expect(try await body(Self.uri("frus1894Nicaragua", "d9999"), .notFound).code == "DOCUMENT_NOT_FOUND")
            #expect(try await body(Self.uri("frus1894Nicaragua", "d1", ""), .notImplemented).code == "PAGE_NOT_AVAILABLE")
            #expect(try await body(Self.uri("frus1894Nicaragua", "d1", "part=head"), .badRequest).code == "INVALID_PARAMETER")
            #expect(try await body(Self.uri("frus1894Nicaragua", "d1", "part=body&textSize=huge"), .badRequest).code == "INVALID_PARAMETER")
            #expect(try await body(Self.uri("frus1894Nicaragua", "d1", "part=body&theme=dark"), .badRequest).code == "UNKNOWN_PARAMETER")
        }
    }

    /// A TEI file that changes is parsed again: here the volume's first document is renamed.
    @Test func aChangedVolumeIsParsedAgain() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        let file = fixture.files.volumesDirectory.appendingPathComponent("frus1894Nicaragua.xml")
        try await fixture.app.test(.router) { client in
            #expect(try await client.execute(uri: Self.uri("frus1894Nicaragua", "d1"), method: .get).status == .ok)
            let text = try String(contentsOf: file, encoding: .utf8)
            let renamed = text.replacingOccurrences(of: #"xml:id="d1""#, with: #"xml:id="d1renamed""#)
            #expect(renamed != text)
            try Data(renamed.utf8).write(to: file, options: .atomic)
            #expect(try await client.execute(uri: Self.uri("frus1894Nicaragua", "d1"), method: .get).status == .notFound)
            #expect(try await client.execute(uri: Self.uri("frus1894Nicaragua", "d1renamed"), method: .get).status == .ok)
        }
    }

    /// The one link a lookup decides: an `<abbr>` naming a glossary term renders as that term's
    /// link, and one naming no term stays text. No fixture volume has an `<abbr>`, so check 4's
    /// bytes cannot show the route's lookups; this volume, written under a manifest id, does.
    @Test func theRoutesLookupsComeFromTheVolumesGlossary() async throws {
        let fixture = try await ServerFixture()
        try FileManager.default.createDirectory(at: fixture.files.volumesDirectory, withIntermediateDirectories: true)
        try Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="frus1894Nicaragua">
              <teiHeader><fileDesc><titleStmt><title>Abbreviations</title></titleStmt>
                <publicationStmt><p/></publicationStmt><sourceDesc><p/></sourceDesc></fileDesc></teiHeader>
              <text>
                <front>
                  <div type="section" xml:id="terms">
                    <head>List of Abbreviations</head>
                    <list type="terms">
                      <item><hi rend="strong"><term xml:id="t_NATO1">NATO</term>,</hi> North Atlantic Treaty Organization</item>
                    </list>
                  </div>
                </front>
                <body>
                  <div type="document" xml:id="d1" n="1">
                    <head>1. Memorandum</head>
                    <p>The <abbr>nato</abbr> ministers met; <abbr>SEATO</abbr> did not.</p>
                  </div>
                </body>
              </text>
            </TEI>
            """.utf8).write(to: fixture.files.volumesDirectory.appendingPathComponent("frus1894Nicaragua.xml"))
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: Self.uri("frus1894Nicaragua", "d1"), method: .get)
            let html = String(buffer: response.body)
            #expect(response.status == .ok)
            #expect(html.contains("The <a class=\"gloss\" href=\"frusexplorer://gloss/t_NATO1\">nato</a> ministers met; SEATO did not."), "\(html)")
            #expect(html.components(separatedBy: "class=\"gloss\"").count == 2, "\(html)")
        }
    }

    /// A volume that will not parse, here for mismatched tags, is a 500 naming it, for every
    /// request waiting on that parse; the failure is not kept, so the repaired file renders. (A file
    /// cut short is not such a volume on Linux: it renders the documents before the cut.)
    @Test func aVolumeThatWillNotParseIsAProblemUntilItIsRepaired() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        let file = fixture.files.volumesDirectory.appendingPathComponent("frus1894Nicaragua.xml")
        let original = try Data(contentsOf: file)
        try Data("<?xml version=\"1.0\"?>\n<TEI><text><body></TEI>".utf8).write(to: file)
        try await fixture.app.test(.router) { client in
            let codes = try await withThrowingTaskGroup(of: String.self) { group in
                for _ in 0..<3 {
                    group.addTask {
                        let response = try await client.execute(uri: Self.uri("frus1894Nicaragua", "d1"), method: .get)
                        return try problem(response, .internalServerError).code
                    }
                }
                return try await group.reduce(into: [String]()) { $0.append($1) }
            }
            #expect(codes == Array(repeating: "TEI_UNREADABLE", count: 3))
            try original.write(to: file)
            let repaired = try await client.execute(uri: Self.uri("frus1894Nicaragua", "d1"), method: .get)
            #expect(repaired.status == .ok)
        }
    }

    /// The cache keeps the `capacity` volumes used most recently: a hit makes a volume the newest,
    /// and the least recently used is the one dropped.
    @Test func theCacheDropsTheLeastRecentlyUsedVolume() async throws {
        let fixture = try await ServerFixture(volumes: ParityVolumes.all)
        let reader = ReaderService(volumesDirectory: fixture.files.volumesDirectory, resources: fixture.resources, capacity: 2)
        let (a, b, c) = (ParityVolumes.all[0], ParityVolumes.all[1], ParityVolumes.all[2])
        func open(_ volume: String) async throws -> Int {
            _ = try await reader.body(volume: volume, document: "d1")
            return await reader.parseCount
        }
        #expect(try await open(a) == 1)
        #expect(try await open(b) == 2)
        #expect(try await open(a) == 2, "a hit, which makes \(a) the newest")
        #expect(try await open(c) == 3, "which drops \(b), the least recently used")
        #expect(try await open(a) == 3)
        #expect(try await open(b) == 4)
    }

    /// Requests for a volume being parsed share its parse, and the cache keeps `capacity` volumes.
    @Test func concurrentRequestsShareOneParse() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua", "frus1961-63v06"])
        let reader = ReaderService(volumesDirectory: fixture.files.volumesDirectory, resources: fixture.resources, capacity: 1)
        let bodies = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<8 { group.addTask { try await reader.body(volume: "frus1894Nicaragua", document: "d2").html } }
            return try await group.reduce(into: [String]()) { $0.append($1) }
        }
        #expect(Set(bodies).count == 1)
        #expect(await reader.parseCount == 1)
        _ = try await reader.body(volume: "frus1961-63v06", document: "d1")
        _ = try await reader.body(volume: "frus1894Nicaragua", document: "d1")
        #expect(await reader.parseCount == 3, "a cache of one volume parses Nicaragua again")
    }
}

/// The three fixture volumes, each with a document `d1`.
enum ParityVolumes {
    static let all = ["frus1894Nicaragua", "frus1961-63v06", "frus1969-76ve09p1"]
}

@Suite struct ResourcesTests {
    @Test func theSubmodulesDataFilesLoad() throws {
        let resources = try TestResources.value()
        #expect(resources.manifest.count == 553)
        #expect(resources.volume("frus1969-76ve09p1")?.subseries == "1969-76")
        #expect(resources.volume("nothing") == nil)
        #expect(ServerResources.requiredFiles.count == 5)
    }

    @Test func aFolderWithoutThemIsRefusedNamingEachFile() throws {
        let directory = try TemporaryDirectory()
        try Data("[]".utf8).write(to: directory.url.appendingPathComponent("manifest.json"))
        #expect {
            _ = try ServerResources.load(from: directory.url)
        } throws: { error in
            guard case .missing(_, let files)? = error as? ServerResourcesError else { return false }
            return files == ServerResources.requiredFiles.filter { $0 != "manifest.json" }
                && "\(error)".contains("FRUS_RESOURCES_DIR")
        }
    }

    @Test func theServerWillNotStartWithoutThem() async throws {
        let directory = try TemporaryDirectory()
        var config = ServerConfiguration.testing(directory.url.appendingPathComponent("data"))
        config.resourcesDirectory = directory.url.appendingPathComponent("missing")
        await #expect(throws: ServerResourcesError.self) { _ = try await buildApplication(configuration: config) }
        // Refused before anything is written.
        #expect(!FileManager.default.fileExists(atPath: config.dataDirectory.path))
    }
}
