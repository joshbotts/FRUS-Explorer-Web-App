// The reader's page links and person counts through the API, on the real Import path, against the
// app's own stores over the writable fixture index: what the server answers from its immutable
// opens is what the app's opens answer.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSLightAPI

@Suite struct ReaderLinkParityTests {
    /// The link route's address for a link in `document` of `volume`.
    static func uri(_ href: String, volume: String, document: String = "d1") -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "*-._")
        return "/api/v1/volumes/\(volume)/documents/\(document)/link?href=\(href.addingPercentEncoding(withAllowedCharacters: allowed)!)"
    }

    /// Every arabic page of every fixture volume, one past the last and page 0, lands on the
    /// document the app's `PageRangeStore` places there, and so do page links whose footnotes name
    /// a number or a day, which choose among the documents that begin on one page.
    @Test func everyPageLinkLandsWhereTheAppsStorePlacesIt() async throws {
        let built = try await FixtureIndex.value()
        let store = try PageRangeStore(databaseURL: built.index.database)
        let index = try SQLiteConnection(built.copy.path, readOnly: true)
        defer { index.close() }
        // Each link is sent from `from`, and names a page of `volume`.
        var cases: [(from: String, volume: String, href: String, expected: String?)] = []
        for volume in ParityFixtures.volumes {
            let last = Int(try index.scalar(
                "SELECT MAX(page_number_int) FROM page_ranges WHERE volume_id = ? AND page_number_type = 'arabic'", [.text(volume)])?.integer ?? 0)
            for page in 0...(last + 1) {
                cases.append((volume, volume, "frusexplorer://doc/%23pg_\(page)", try await store.document(forPage: page, inVolume: volume, citing: nil)))
            }
        }
        // Footnote hints, in the serializer's form, where several documents begin on the page.
        let hinted: [(volume: String, page: Int, query: String, named: String)] = [
            ("frus1961-63v06", 2, "day=1-20", "d3"), ("frus1961-63v06", 2, "no=3", "d3"),
            ("frus1961-63v06", 2, "day=1-20-1962", "d2"), ("frus1961-63v06", 2, "no=3&day=11-10", "d3"),
            ("frus1894Nicaragua", 15, "day=3-6", "d8"), ("frus1894Nicaragua", 15, "no=10&day=3-6", "d10"),
        ]
        for hint in hinted {
            let items = URLComponents(string: "x:?\(hint.query)")?.queryItems ?? []
            let expected = try await store.document(forPage: hint.page, inVolume: hint.volume, citing: PageCitationHint(queryItems: items))
            #expect(expected == hint.named, "the app's store, \(hint.volume) page \(hint.page) with \(hint.query)")
            cases.append((hint.volume, hint.volume, "frusexplorer://doc/%23pg_\(hint.page)?\(hint.query)", expected))
        }
        // A page of another indexed volume, named as the serializer names it, from frus1961-63v06,
        // whose own pages 9 and 15 hold other documents: the lookup is in the volume the link names.
        for (page, query) in [(9, ""), (15, "?no=10&day=3-6")] {
            let items = URLComponents(string: "x:\(query)")?.queryItems ?? []
            let expected = try await store.document(forPage: page, inVolume: "frus1894Nicaragua", citing: PageCitationHint(queryItems: items))
            let local = try await store.document(forPage: page, inVolume: "frus1961-63v06", citing: PageCitationHint(queryItems: items))
            #expect(expected != nil && expected != local, "Nicaragua's page \(page) and v06's hold different documents")
            cases.append(("frus1961-63v06", "frus1894Nicaragua", "frusexplorer://doc/frus1894Nicaragua%23pg_\(page)/frus1894Nicaragua\(query)", expected))
        }
        let pairs = cases
        let answers = try await ServedFixture.run { client, _ in
            var answers: [ReaderLinkTarget] = []
            for item in pairs {
                answers.append(try ServedFixture.decode(ReaderLinkTarget.self,
                                                        try await client.execute(uri: Self.uri(item.href, volume: item.from), method: .get)))
            }
            return answers
        }
        var landed = 0
        for (item, answer) in zip(pairs, answers) {
            #expect(answer.kind == "page" && answer.pageVolumeId == item.volume, "\(item.volume) \(item.href)")
            #expect(answer.destination?.documentId == item.expected, "\(item.volume) \(item.href)")
            #expect(answer.destination.map { $0.volumeId == item.volume && $0.footnoteAnchor == nil } ?? true)
            if answer.destination != nil { landed += 1 }
        }
        #expect(landed > 600, "most pages of the three volumes place a document")
        print("page links through the API: \(pairs.count) links, \(landed) placed on a document, every one as the app's store places it")
    }

    /// Every person in each fixture volume's list is counted as the app's card counts them, over
    /// the app's own `PersonMentionStore`; a person the volume's list lacks gets no count.
    /// Every link in the fixture volumes' pages to a printed page of another volume, read through the
    /// API, is that page of that volume, which this server, holding only the three fixture volumes,
    /// cannot place: no destination, and the volume as the server holds it, unindexed and unread.
    ///
    /// 1.0's index resolves such a reference under rule C (#1747) through the bundled page map. Where
    /// the map names a document on the page, read as one page with the link's hint, the index stores
    /// the reference against that document, unless the link ends a range across documents, which the
    /// index leaves on the page, as it leaves every page the map names nothing on. The app lands a tap
    /// on the document the map names (#1778); this server will, through the kit's `PageLink`, once its
    /// pin moves past the pull request that moves the landing into the kit.
    @Test func everyPageLinkIntoAnotherVolumeIsWhereTheIndexStoresIt() async throws {
        let rendered = Repository.layout.golden.appendingPathComponent("render/html")
        var links: [(volume: String, document: String, href: String)] = []
        for volume in ParityFixtures.volumes {
            let folder = rendered.appendingPathComponent(volume)
            for file in try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() where file.hasSuffix(".html") {
                let html = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
                var seen = Set<String>()
                for match in html.matches(of: /href="(frusexplorer:\/\/doc\/([^"%\/]+)%23pg_[0-9]+[^"]*)"/) where match.2 != volume {
                    let href = String(match.1).replacingOccurrences(of: "&amp;", with: "&")
                    if seen.insert(href).inserted { links.append((volume, String(file.dropLast(".html".count)), href)) }
                }
            }
        }
        let map = try JSONDecoder().decode(CitedPageMap.self,
                                           from: Data(contentsOf: ServedFixture.resources.appendingPathComponent("cited-page-map.json")))
        let built = try await FixtureIndex.value()
        let index = try SQLiteConnection(built.copy.path, readOnly: true)
        defer { index.close() }
        func stored(_ volume: String, _ document: String, into target: String) throws -> Set<String> {
            Set(try index.query("""
                SELECT target_document_id FROM cross_references
                WHERE source_volume_id = ? AND source_document_id = ? AND target_volume_id = ?
                """, [.text(volume), .text(document), .text(target)]).compactMap { $0.first?.text })
        }
        let asked = links
        let answers = try await ServedFixture.run { client, _ in
            var answers: [ReaderLinkTarget] = []
            for link in asked {
                answers.append(try ServedFixture.decode(ReaderLinkTarget.self,
                                                        try await client.execute(uri: Self.uri(link.href, volume: link.volume, document: link.document), method: .get)))
            }
            return answers
        }
        var volumes = Set<String>()
        var named = 0
        var storedAsNamed = 0
        for (link, answer) in zip(links, answers) {
            // The kit's reading of the link, as the route reads it.
            guard let url = URL(string: link.href), case .crossReference(let target, let hrefVolume, let citing)? = FRUSURLScheme.readerLink(from: url),
                  case .page(let pageVolume?, let page) = FRUSURLScheme.resolveCrossRefTarget(target, volumeId: hrefVolume) else {
                Issue.record("\(link.href) is not read as a page of another volume")
                continue
            }
            volumes.insert(pageVolume)
            #expect(answer.kind == "page" && answer.pageVolumeId == pageVolume && answer.page == page, "\(link.href)")
            #expect(answer.destination == nil && answer.volume?.indexed == false && answer.volume?.teiAvailable == false, "\(link.href)")
            let kept = try stored(link.volume, link.document, into: pageVolume)
            if let document = PageSpanResolver.citedDocument(inVolume: pageVolume, page: page, form: .single, citing: citing, map: map) {
                named += 1
                if kept.contains(document) { storedAsNamed += 1 }
                #expect(kept.contains(document) || kept.contains("pg_\(page)"), "\(link.volume)/\(link.document) \(link.href): \(kept)")
            } else {
                #expect(kept.contains("pg_\(page)"), "\(link.volume)/\(link.document) \(link.href): \(kept)")
            }
        }
        #expect(links.count == 31 && volumes.count == 6)
        // frus1894Nicaragua d15's page 469 of frus1889, now d173, among them.
        #expect(storedAsNamed > 0 && named >= storedAsNamed)
        print("page links into other volumes: \(links.count) into \(volumes.count) volumes this server does not hold, each placed nowhere; the map names a document for \(named), and \(storedAsNamed) are stored against it under rule C")
    }

    @Test func everyPersonIsCountedAsTheAppCountsThem() async throws {
        let built = try await FixtureIndex.value()
        let store = try PersonMentionStore(databaseURL: built.index.database)
        let index = try SQLiteConnection(built.copy.path, readOnly: true)
        defer { index.close() }
        var people: [(volume: String, ref: String, expected: Int)] = []
        for row in try index.query("SELECT volume_id, ref FROM persons ORDER BY volume_id, ref") {
            guard let volume = row[0].text, let ref = row[1].text else { continue }
            let expected: Int
            if let rollup = try await store.rollupEntry(forVolumeId: volume, ref: ref) {
                expected = rollup.mentionCount
            } else {
                expected = try await store.documentCount(volumeId: volume, ref: ref)
            }
            people.append((volume, ref, expected))
        }
        #expect(people.count == 58 + 63, "v06's 58 persons and ve09p1's 63")
        let list = people
        let answers = try await ServedFixture.run { client, _ in
            var answers: [ReaderLinkTarget] = []
            for person in list {
                answers.append(try ServedFixture.decode(ReaderLinkTarget.self,
                                                        try await client.execute(uri: Self.uri("frusexplorer://person/\(person.ref)", volume: person.volume), method: .get)))
            }
            return answers
        }
        var counted = 0
        for (person, answer) in zip(list, answers) where answer.person != nil {
            #expect(answer.mentionCount == person.expected, "\(person.volume) \(person.ref)")
            counted += 1
        }
        let khrushchev = zip(list, answers).first { $0.0.ref == "p_KNS2" }?.1
        #expect(khrushchev?.mentionCount == 120 && khrushchev?.person?.name == "Khrushchev, Nikita S.")
        #expect(counted >= list.count - 4, "the reader's lists hold nearly every person the index holds")
        print("person counts through the API: \(counted) of \(list.count) persons in the reader's lists, each as the app counts them")
    }
}
