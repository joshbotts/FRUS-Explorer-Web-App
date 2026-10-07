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
