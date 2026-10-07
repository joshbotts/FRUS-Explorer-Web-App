// The reader's links, through GET …/documents/{d}/link, and browsing a volume's contents: its
// structure from the index or the TEI, a section's documents, and a document the index lacks.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

private let v06 = "frus1961-63v06"
private let v06Title = "Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges"

/// The link route's address for a link in `document` of frus1961-63v06.
private func linkURI(_ href: String, in document: String = "d1", volume: String = v06) -> String {
    var components = URLComponents()
    components.percentEncodedQuery = formEncoded(["href": href])
    return "/api/v1/volumes/\(volume)/documents/\(document)/link?\(components.percentEncodedQuery ?? "")"
}

/// A query string as a browser's URLSearchParams writes it.
private func formEncoded(_ fields: [String: String]) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "*-._")
    return fields.map { name, value in
        let encode = { (text: String) in text.addingPercentEncoding(withAllowedCharacters: allowed)!.replacingOccurrences(of: "%20", with: "+") }
        return "\(encode(name))=\(encode(value))"
    }.joined(separator: "&")
}

@Suite struct ReaderLinkRouteTests {
    @Test func aPersonOrATermLinkGivesTheVolumesEntry() async throws {
        let fixture = try await servingSyntheticExport(volumes: [v06])
        try await fixture.app.test(.router) { client in
            let khrushchev = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://person/p_KNS2"), method: .get))
            #expect(khrushchev.kind == "person" && khrushchev.ref == "p_KNS2")
            #expect(khrushchev.person?.name == "Khrushchev, Nikita S.")
            #expect(khrushchev.person?.description == "Chairman of the Council of Ministers of the Soviet Union")
            let kennedy = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://person/p_KJF2"), method: .get))
            #expect(kennedy.person?.name == "Kennedy, John F.")
            #expect(kennedy.person?.description == "President of the United States until November 22, 1963")
            // A ref the volume's list lacks is answered, with no entry.
            let nobody = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://person/p_NOBODY"), method: .get))
            #expect(nobody.kind == "person" && nobody.ref == "p_NOBODY" && nobody.person == nil)
            let ussr = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://gloss/t_USSR1", in: "d3"), method: .get))
            #expect(ussr.kind == "gloss" && ussr.term?.term == "USSR")
            #expect(ussr.term?.definition?.split(whereSeparator: \.isWhitespace).joined(separator: " ") == "Union of Soviet Socialist Republics")
        }
    }

    /// A person's count is their rollup's, across the corpus, else their documents in the volume,
    /// as the app's card counts them; with no index served, there is none.
    @Test func aPersonIsCountedAsTheAppCountsThem() async throws {
        let fixture = try await servingSyntheticExport(volumes: [v06])
        try await fixture.app.test(.router) { client in
            func count(_ ref: String) async throws -> Int? {
                try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://person/\(ref)"), method: .get)).mentionCount
            }
            // Khrushchev's rollup counts his two documents; Kennedy has no rollup, and two documents in v06.
            let khrushchev = try await count("p_KNS2"), kennedy = try await count("p_KJF2")
            #expect(khrushchev == 2 && kennedy == 2)
            // A person of the volume's list whom no indexed document mentions, and one the list lacks.
            let zorin = try await count("p_ZVA1"), nobody = try await count("p_NOBODY")
            #expect(zorin == 0 && nobody == nil)
        }
        // A rollup spans the corpus, so its count wins over the volume's.
        let rolled = try await ServerFixture(volumes: [v06])
        var export = SyntheticExport()
        export.rollupMentionCount = 120
        try export.write(to: rolled.files.liveIndex)
        await rolled.state.openExistingIndex(files: rolled.files)
        try await rolled.app.test(.router) { client in
            let khrushchev = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://person/p_KNS2"), method: .get))
            let kennedy = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://person/p_KJF2"), method: .get))
            #expect(khrushchev.mentionCount == 120 && kennedy.mentionCount == 2)
        }
        let before = try await ServerFixture(volumes: [v06])
        try await before.app.test(.router) { client in
            let khrushchev = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://person/p_KNS2"), method: .get))
            #expect(khrushchev.person?.name == "Khrushchev, Nikita S." && khrushchev.mentionCount == nil)
            // Nor does a page land anywhere before an import.
            let page = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://doc/%23pg_1"), method: .get))
            #expect(page.destination == nil && page.volume?.indexed == false)
        }
    }

    @Test func aCrossReferenceLandsWhereTheKitResolvesIt() async throws {
        let fixture = try await servingSyntheticExport(volumes: [v06])
        try await fixture.app.test(.router) { client in
            func resolve(_ href: String, in document: String) async throws -> ReaderLinkTarget {
                try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI(href, in: document), method: .get))
            }
            // d2's footnote names Document 1, in the same volume.
            let d1 = try await resolve("frusexplorer://doc/%23d1", in: "d2")
            #expect(d1.kind == "document" && d1.target == "#d1" && d1.inPlace == false)
            #expect(d1.destination == .init(volumeId: v06, documentId: "d1", footnoteAnchor: nil, footnoteElementId: nil,
                                            canonicalURL: "https://history.state.gov/historicaldocuments/frus1961-63v06/d1"))
            #expect(d1.volume == .init(title: v06Title, teiAvailable: true, indexed: true))
            // d21 names a note of d16; the list of footnotes holds it as fnote-x-d16fn2.
            let note = try await resolve("frusexplorer://doc/%23d16fn2", in: "d21")
            #expect(note.destination?.documentId == "d16" && note.destination?.footnoteAnchor == "d16fn2")
            #expect(note.destination?.footnoteElementId == "fnote-x-d16fn2")
            #expect(note.inPlace == false)
            // A note of the document the link is in is shown in place.
            #expect(try await resolve("frusexplorer://doc/%23d2fn1", in: "d2").inPlace == true)
            // Another volume: in the catalogue, but neither mounted nor indexed here.
            let v05 = try await resolve("frusexplorer://doc/frus1961-63v05%23d28/frus1961-63v05", in: "d7")
            #expect(v05.destination?.volumeId == "frus1961-63v05" && v05.destination?.documentId == "d28")
            #expect(v05.volume?.teiAvailable == false && v05.volume?.indexed == false)
            #expect(v05.destination?.canonicalURL == "https://history.state.gov/historicaldocuments/frus1961-63v05/d28")
            // A page lands on the document the index's page ranges place there: d1 and d2 begin pages 1 and 2.
            let page2 = try await resolve("frusexplorer://doc/%23pg_2", in: "d1")
            #expect(page2.kind == "page" && page2.page == 2 && page2.pageVolumeId == v06 && page2.inPlace == false)
            #expect(page2.destination?.documentId == "d2" && page2.destination?.footnoteAnchor == nil && page2.volume?.indexed == true)
            #expect(try await resolve("frusexplorer://doc/%23pg_1", in: "d2").destination?.documentId == "d1")
            // A page the index places nowhere, and a volume it does not hold, land nowhere.
            let unplaced = try await resolve("frusexplorer://doc/%23pg_313", in: "d2")
            #expect(unplaced.pageVolumeId == v06 && unplaced.destination == nil && unplaced.volume?.indexed == true)
            let page = try await resolve("frusexplorer://doc/frus1961-63v14%23pg_387/frus1961-63v14", in: "d21")
            #expect(page.kind == "page" && page.page == 387 && page.pageVolumeId == "frus1961-63v14" && page.destination == nil)
            #expect(page.volume?.indexed == false && page.volume?.teiAvailable == false)
            let external = try await resolve("frusexplorer://doc/https%3A%2F%2Fhistory.state.gov%2Fabout", in: "d1")
            #expect(external.kind == "external" && external.url == "https://history.state.gov/about")
            #expect(try await resolve("frusexplorer://doc/%23fn3", in: "d1").kind == "unresolved")
            // A target naming a whole volume is a document of that name, as the kit resolves it.
            let whole = try await resolve("frusexplorer://doc/frus1961-63v05", in: "preface")
            #expect(whole.destination?.volumeId == v06 && whole.destination?.documentId == "frus1961-63v05")
            // No fixture volume has a broken reference.
            let broken = try await resolve("frusexplorer://brokenref/%23pg_700", in: "d1")
            #expect(broken.kind == "brokenReference" && broken.target == "#pg_700" && broken.brokenReference == nil)
        }
    }

    /// Every link the reader's pages hold for the walk the browser suite takes is answered.
    @Test func everyLinkOnAFixturePageIsAnswered() async throws {
        let fixture = try await servingSyntheticExport(volumes: [v06])
        try await fixture.app.test(.router) { client in
            for document in ["d1", "d2", "d3", "d7", "d21"] {
                let page = String(buffer: try await client.execute(uri: "/api/v1/volumes/\(v06)/documents/\(document)/html", method: .get).body)
                let hrefs = Set(page.matches(of: /href="(frusexplorer:[^"]+)"/).map { String($0.1).replacingOccurrences(of: "&amp;", with: "&") })
                #expect(!hrefs.isEmpty, "\(document)")
                for href in hrefs {
                    let response = try await client.execute(uri: linkURI(href, in: document), method: .get)
                    #expect(response.status == .ok, "\(document): \(href)")
                    let target = try decode(ReaderLinkTarget.self, response)
                    // Every person and term the fixtures name is in its volume's lists.
                    if target.kind == "person" { #expect(target.person != nil, "\(href)") }
                    if target.kind == "gloss" { #expect(target.term != nil, "\(href)") }
                }
            }
        }
    }

    /// The bundled index's account of an unresolved reference: the page writes the reference as a
    /// broken one, and its link gives the reason.
    @Test func aBrokenReferenceCarriesTheIndexsAccount() async throws {
        let fixture = try await servingSyntheticExport(volumes: [v06])
        let bundled = try TestResources.value()
        let index = try JSONDecoder().decode(BrokenRefsIndex.self, from: Data("""
            {"records":[{"sv":"frus1961-63v06","sd":"d2","t":"#d1","r":"unknownAnchor","rv":"frus1961-63v06","ra":"d1"}]}
            """.utf8))
        let resources = ServerResources(directory: bundled.directory, manifest: bundled.manifest, brokenRefs: index, indexing: bundled.indexing)
        let reader = ReaderService(volumesDirectory: fixture.files.volumesDirectory, resources: resources)
        let app = Application(router: buildRouter(state: fixture.state, resources: resources, reader: reader))
        try await app.test(.router) { client in
            let page = String(buffer: try await client.execute(uri: "/api/v1/volumes/\(v06)/documents/d2/html", method: .get).body)
            let href = try #require(page.firstMatch(of: /href="(frusexplorer:\/\/brokenref\/[^"]+)"/)).1
            #expect(href == "frusexplorer://brokenref/%23d1")
            let target = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI(String(href), in: "d2"), method: .get))
            #expect(target.kind == "brokenReference" && target.target == "#d1")
            #expect(target.brokenReference == .init(target: "#d1", reason: "unknownAnchor", resolvedVolume: v06, resolvedAnchor: "d1"))
        }
    }

    @Test func aLinkThatIsNotTheReadersIsRefused() async throws {
        let fixture = try await servingSyntheticExport(volumes: [v06])
        try await fixture.app.test(.router) { client in
            let missing = try await client.execute(uri: "/api/v1/volumes/\(v06)/documents/d1/link", method: .get)
            #expect(try problem(missing, .badRequest).code == "INVALID_PARAMETER")
            for href in ["https://history.state.gov", "frusexplorer://figure/x.png"] {
                #expect(try problem(try await client.execute(uri: linkURI(href), method: .get), .badRequest).code == "INVALID_PARAMETER", "\(href)")
            }
            let extra = try await client.execute(uri: linkURI("frusexplorer://person/p_KNS2") + "&style=chicago", method: .get)
            #expect(try problem(extra, .badRequest).code == "UNKNOWN_PARAMETER")
            let unknown = try await client.execute(uri: linkURI("frusexplorer://person/p_KNS2", volume: "frus1961-63v99"), method: .get)
            #expect(try problem(unknown, .notFound).code == "VOLUME_NOT_FOUND")
            // A person needs the volume's TEI, which the server does not have for v05.
            let unmounted = try await client.execute(uri: linkURI("frusexplorer://person/p_KNS2", volume: "frus1961-63v05"), method: .get)
            #expect(try problem(unmounted, .notFound).code == "TEI_NOT_AVAILABLE")
            // The kit reads the link as the app does: a person's ref decoded twice, an empty one
            // named as the empty ref, which no entry has.
            let twice = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://person/p_KNS%2532"), method: .get))
            #expect(twice.ref == "p_KNS2" && twice.person?.name == "Khrushchev, Nikita S.")
            let empty = try decode(ReaderLinkTarget.self, try await client.execute(uri: linkURI("frusexplorer://person"), method: .get))
            #expect(empty.kind == "person" && empty.ref == "" && empty.person == nil)
            // A link far longer than any the kit writes is refused before it is parsed.
            let long = "frusexplorer://doc/" + String(repeating: "d1fn", count: 1_000) + "!"
            #expect(try problem(try await client.execute(uri: linkURI(long), method: .get), .badRequest).code == "INVALID_PARAMETER")
        }
    }
}

@Suite struct VolumeContentsRouteTests {
    /// The synthetic export caches no structure, so the volume's comes from its TEI; the index's
    /// two documents are counted against it.
    @Test func aVolumesStructureComesFromItsTEIWhenTheIndexHasNone() async throws {
        let fixture = try await servingSyntheticExport(volumes: [v06])
        try await fixture.app.test(.router) { client in
            let volume = try decode(Volume.self, try await client.execute(uri: "/api/v1/volumes/\(v06)", method: .get))
            #expect(volume.structureSource == "tei")
            let sections = try #require(volume.structure)
            func flatten(_ sections: [Volume.Section]) -> [Volume.Section] { sections.flatMap { [$0] + flatten($0.subsections) } }
            let all = Dictionary(flatten(sections).map { ($0.sectionId, $0) }, uniquingKeysWith: { first, _ in first })
            let compilation = try #require(all["comp1"])
            #expect(compilation.title.split(whereSeparator: \.isWhitespace).joined(separator: " ") == "Kennedy-Khrushchev Exchanges")
            #expect(compilation.documentCount == 120 && compilation.indexedDocumentCount == 2 && compilation.readable == false)
            #expect(compilation.documentIds.prefix(2) == ["d1", "d2"])
            // The reader opens a preface, which the parse makes a document, but not the list of names.
            #expect(all["preface"]?.readable == true && all["preface"]?.canReadDirectly == true && all["preface"]?.isFrontMatter == true)
            #expect(all["persons"]?.readable == false && all["persons"]?.isFrontMatter == true)
            #expect(volume.documentCount == 120 && volume.indexedDocumentCount == 2)
        }
        // Neither an index's structure nor the TEI: no structure.
        let bare = try await ServerFixture()
        try await bare.app.test(.router) { client in
            let volume = try decode(Volume.self, try await client.execute(uri: "/api/v1/volumes/\(v06)", method: .get))
            #expect(volume.structure == nil && volume.structureSource == nil && volume.documentCount == nil)
        }
    }

    @Test func aSectionListsItsDocumentsFromTheIndexAndTheTEI() async throws {
        let fixture = try await servingSyntheticExport(volumes: [v06])
        try await fixture.app.test(.router) { client in
            let page = try decode(VolumeSectionPage.self, try await client.execute(uri: "/api/v1/volumes/\(v06)/sections/comp1", method: .get))
            #expect(page.volumeTitle == v06Title && page.structureSource == "tei" && page.path.isEmpty)
            #expect(page.documents.count == 120 && page.section.indexedDocumentCount == 2)
            // The index names its two; the rest are named by number, as the kit names a document.
            let first = page.documents[0]
            #expect(first.documentId == "d1" && first.header == "1. Telegram From the Embassy in the Soviet Union")
            #expect(first.inIndex && first.readable == true && !first.isEditorialNote)
            #expect(page.documents[2].header == "Document 3" && page.documents[2].documentNumber == "3")
            #expect(!page.documents[2].inIndex && page.documents[2].readable == true)
            let missing = try await client.execute(uri: "/api/v1/volumes/\(v06)/sections/nowhere", method: .get)
            #expect(try problem(missing, .notFound).code == "SECTION_NOT_FOUND")
        }
        let bare = try await ServerFixture()
        try await bare.app.test(.router) { client in
            let none = try await client.execute(uri: "/api/v1/volumes/\(v06)/sections/comp1", method: .get)
            #expect(try problem(none, .notFound).code == "SECTION_NOT_FOUND")
        }
    }

    /// The reader works without the index, so a document the index lacks, or every document before
    /// an import, is named from its TEI.
    @Test func aDocumentTheIndexLacksIsNamedFromItsTEI() async throws {
        let fixture = try await servingSyntheticExport(volumes: [v06])
        try await fixture.app.test(.router) { client in
            let d3 = try decode(DocumentDetail.self, try await client.execute(uri: "/api/v1/volumes/\(v06)/documents/d3", method: .get))
            #expect(d3.document.header == "Document 3" && d3.document.documentNumber == "3" && !d3.document.inIndex)
            #expect(d3.previous == nil && d3.next == nil && d3.teiAvailable)
            #expect(d3.canonicalURL == "https://history.state.gov/historicaldocuments/frus1961-63v06/d3")
            // A prose section the parse makes a document is named by its title, as the kit's reading order names it.
            let intro = try decode(DocumentDetail.self, try await client.execute(uri: "/api/v1/volumes/\(v06)/documents/intro1", method: .get))
            #expect(intro.document.header == "Introduction" && intro.document.documentNumber == nil && !intro.document.inIndex)
            // An indexed document's neighbours say whether the reader can open them.
            let d1 = try decode(DocumentDetail.self, try await client.execute(uri: "/api/v1/volumes/\(v06)/documents/d1", method: .get))
            #expect(d1.next?.documentId == "d2" && d1.next?.readable == true)
        }
        let before = try await ServerFixture(volumes: [v06])
        try await before.app.test(.router) { client in
            let d1 = try decode(DocumentDetail.self, try await client.execute(uri: "/api/v1/volumes/\(v06)/documents/d1", method: .get))
            #expect(d1.document.header == "Document 1" && !d1.document.inIndex)
            // A document neither the index nor the TEI holds still waits for the index.
            let missing = try await client.execute(uri: "/api/v1/volumes/\(v06)/documents/d999", method: .get)
            #expect(try problem(missing, .serviceUnavailable).code == "INDEX_NOT_READY")
        }
    }

    /// TEI that will not parse is reported, not taken for a volume without contents.
    @Test func unreadableTEIIsReportedNotHidden() async throws {
        let fixture = try await ServerFixture()
        try FileManager.default.createDirectory(at: fixture.files.volumesDirectory, withIntermediateDirectories: true)
        let file = fixture.files.volumesDirectory.appendingPathComponent("\(v06).xml")
        try Data("<?xml version=\"1.0\"?>\n<TEI><text><body></TEI>".utf8).write(to: file)
        try await fixture.app.test(.router) { client in
            for uri in ["/api/v1/volumes/\(v06)", "/api/v1/volumes/\(v06)/sections/comp1", "/api/v1/volumes/\(v06)/documents/d1"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(try problem(response, .internalServerError).code == "TEI_UNREADABLE", "\(uri)")
            }
        }
    }
}
