// Add Documents' Citations and Tags through the router (PLAN's S25d): a paste resolved line by line by the
// kit's resolver into each of its buckets, over the served index and over the catalogue alone, each row
// with its document's head and its volume's title, a link into a catalogued volume the index does not
// hold resolved by its id, and a paste past Batch's bound refused; and the Tags tab's list and a tag's
// documents, the kit's union of the user's notes and assignments, gathered on either store.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

extension UserDataFixture {
    /// The fixture serving the synthetic export with `edits` made to it, as `servingSyntheticExport`
    /// makes them, with the store and the services `init` gives.
    init(servingWith edits: String) async throws {
        server = try await servingSyntheticExport(edits: edits)
        let url = server.files.userStore
        store = try await SQLiteUserStore(url: url, backupsDirectory: server.files.backupsDirectory)
        rows = try UserStoreRows(url)
        configuration = ServerConfiguration(auth: .none, dataDirectory: server.files.root, publicURL: "http://localhost:8080", userData: true)
        jobs = InProcessJobQueue()
        let secrets = try SecretVault.open(store: store, keyFile: server.files.secretKey, named: false).vault
        services = UserDataServices(store: store, configuration: configuration, secrets: secrets, jobs: jobs,
                                    importLimit: UserDataServices.importBodyLimit, resolver: nil,
                                    passwords: PasswordHasher(.leastCost), now: { UserDataFixture.now })
    }
}

@Suite struct AddDocumentsTests {
    static let citations = "/api/v1/me/add-documents/citations"
    static let tags = "/api/v1/me/add-documents/tags"
    static let v06 = "frus1961-63v06"
    /// A catalogued volume no fixture index holds.
    static let v30 = "frus1964-68v30"

    static func paste(_ text: String) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: ["text": text]), as: UTF8.self)
    }

    static func resolve(_ browser: Browser, _ text: String, sourceLocation: SourceLocation = #_sourceLocation) async throws -> AddDocumentsCitations {
        let response = try await browser.send(.post, citations, try paste(text))
        #expect(response.status == .ok, "\(String(buffer: response.body))", sourceLocation: sourceLocation)
        return try decode(AddDocumentsCitations.self, response)
    }

    /// Each line of a paste has its row, in the paste's order, the kit's bucket and words: a citation and
    /// a link to documents the index holds resolve, with the heads the index holds; a citation that
    /// names no volume is the engine's guess, to review; a link into a catalogued volume the index does
    /// not hold resolves by its id, with no head, as the app adds one from a volume it has not
    /// downloaded; a citation of that volume finds only the volume; and a line that is no citation says
    /// so. A blank line is none, and a line pasted twice is two rows.
    @Test func aPasteResolvesEachLineIntoItsBucket() async throws {
        let fixture = try await UserDataFixture(servingWith: CitationLookupTests.numbered)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let resolved = try await Self.resolve(owner, """
                  FRUS, 1961–1963, vol. VI, doc. 1\r
                \r
                https://history.state.gov/historicaldocuments/frus1961-63v06/d2
                Document 2
                https://history.state.gov/historicaldocuments/\(Self.v30)/d12
                FRUS, 1964–1968, vol. XXX, doc. 12
                a grocery list
                FRUS, 1961–1963, vol. VI, doc. 1
                """)
            #expect(resolved.total == 7 && resolved.items.count == 7)
            #expect(resolved.items.map(\.line) == [
                "FRUS, 1961–1963, vol. VI, doc. 1", "https://history.state.gov/historicaldocuments/frus1961-63v06/d2", "Document 2",
                "https://history.state.gov/historicaldocuments/\(Self.v30)/d12", "FRUS, 1964–1968, vol. XXX, doc. 12", "a grocery list",
                "FRUS, 1961–1963, vol. VI, doc. 1",
            ])
            #expect(resolved.items.map(\.outcome) == ["resolved", "resolved", "ambiguous", "resolved", "unresolved", "unresolved", "resolved"])
            let v06Title = try #require(fixture.server.resources.volume(Self.v06)?.title)
            let first = resolved.items[0]
            #expect(first.volumeId == Self.v06 && first.documentId == "d1" && first.note == nil && first.reason == nil)
            #expect(first.header == "1. Telegram From the Embassy in the Soviet Union" && first.volumeTitle == v06Title)
            #expect(resolved.items[1].documentId == "d2" && resolved.items[1].header == "2. Memorandum of Conversation")
            // No volume named: at most a guess, whatever the engine calls its match.
            let guess = resolved.items[2]
            #expect(guess.volumeId == Self.v06 && guess.documentId == "d2" && guess.header == "2. Memorandum of Conversation")
            #expect(guess.note == "\(ConfidenceLabels.exactMatch) — the citation doesn’t identify a volume, so this match is a guess")
            // A link into a catalogued volume the index does not hold: the document by its id, no head.
            let linked = resolved.items[3]
            #expect(linked.volumeId == Self.v30 && linked.documentId == "d12" && linked.header == nil && linked.note == nil)
            #expect(linked.volumeTitle == fixture.server.resources.volume(Self.v30)?.title && linked.volumeTitle != nil)
            // A citation of that volume finds the volume alone, in the kit's words; a line that is no
            // citation never reaches the matcher.
            #expect(resolved.items[4].reason == ConfidenceLabels.manifestOnly && resolved.items[4].volumeId == nil)
            #expect(resolved.items[5].reason == "Couldn’t read this line as a FRUS citation or document link")
            #expect(resolved.items[4].header == nil && resolved.items[4].volumeTitle == nil && resolved.items[4].note == nil)
            #expect(resolved.items[6] == first, "a line pasted twice is two rows")

            // The kit's resolver over the served index's own matcher answers the same, bucket for bucket.
            let served = try await ServedIndexProvider(state: fixture.server.state, resources: fixture.server.resources,
                                                       volumesDirectory: fixture.server.reader.volumesDirectory).served()
            let kit = try await AddDocumentsRoutes.resolve(resolved.items.map(\.line), engine: served.citations)
            #expect(kit.map(\.outcome) == resolved.items.map { line -> CollectionCitationLineResolver.Outcome in
                switch line.outcome {
                case "resolved": .resolved(volumeId: line.volumeId ?? "", documentId: line.documentId ?? "", note: line.note)
                case "ambiguous": .ambiguous(volumeId: line.volumeId ?? "", documentId: line.documentId ?? "", note: line.note ?? "")
                default: .unresolved(reason: line.reason ?? "")
                }
            })

            // Nothing to resolve, nothing listed; nothing changed by any of it.
            #expect(try await Self.resolve(owner, " \n\t\r\n") == AddDocumentsCitations(total: 0, items: []))
            #expect(try fixture.store.collectionRows(of: "owner").collections.isEmpty)
        }
    }

    /// With no index served, the catalogue alone answers, as the app's matcher does with nothing
    /// downloaded: a citation finds only its volume, and a link names its document by its id.
    @Test func withNoIndexTheCatalogueAloneAnswers() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let resolved = try await Self.resolve(owner, """
                FRUS, 1961–1963, vol. VI, doc. 1
                https://history.state.gov/historicaldocuments/frus1961-63v06/d1
                """)
            #expect(resolved.items.map(\.outcome) == ["unresolved", "resolved"])
            #expect(resolved.items[0].reason == ConfidenceLabels.manifestOnly)
            #expect(resolved.items[1].volumeId == Self.v06 && resolved.items[1].documentId == "d1" && resolved.items[1].header == nil)
            #expect(resolved.items[1].volumeTitle == fixture.server.resources.volume(Self.v06)?.title)
        }
    }

    /// A paste is bounded as Batch's block is: 500 lines, and 256 KiB. Its body is the route's own JSON,
    /// and the route answers only a user.
    @Test func aPastePastBatchsBoundIsRefused() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let lines = (1...CitationLookupRoutes.batchLimit).map { "line \($0)" }
            let full = try await Self.resolve(owner, lines.joined(separator: "\n"))
            #expect(full.total == 500 && full.items.allSatisfy { $0.outcome == "unresolved" })

            let over = try await owner.send(.post, Self.citations, try Self.paste((lines + ["one more"]).joined(separator: "\n")))
            #expect(over.status == .badRequest && problemCode(over) == "TOO_MANY_CITATIONS")
            #expect(try decode(APIProblem.Body.self, over).detail
                    == "Add Documents resolves at most 500 lines at a time, and this text holds 501. Paste it in parts.")
            let large = try await owner.send(.post, Self.citations, try Self.paste(String(repeating: "x", count: CitationLookupRoutes.bodyLimit)))
            #expect(large.status == .contentTooLarge && problemCode(large) == "CONTENT_TOO_LARGE")
            let unknown = try await owner.send(.post, Self.citations, #"{"text": "a", "volumeId": "frus1961-63v06"}"#)
            #expect(unknown.status == .badRequest && problemCode(unknown) == "UNKNOWN_FIELD")
            let missing = try await owner.send(.post, Self.citations, "{}")
            #expect(missing.status == .badRequest && problemCode(missing) == "INVALID_FIELD")
            let tokenless = try await owner.send(.post, Self.citations, try Self.paste("a"), token: "wrong")
            #expect(tokenless.status == .forbidden && problemCode(tokenless) == "CSRF_TOKEN_INVALID")
        }
    }

    /// The Tags tab: each of the user's tags in the tag list's order, with how many documents the kit's
    /// union gathers for it over all their notes and assignments; and a tag's documents, the union's in
    /// its order, its notes' documents first, newest note first, then its assignments', each with the
    /// head the index holds and the catalogue's title. A note with no document gives none, an assignment
    /// of a tag the user no longer has names none, and a tag of another user's is none of theirs.
    @Test func theTagsTabGathersEachTagsDocuments() async throws {
        let fixture = try await UserDataFixture(servingWith: CitationLookupTests.numbered)
        defer { withExtendedLifetime(fixture) {} }
        let rows = fixture.rows
        try rows.addUser("reader")
        let cuba = try fixture.store.createTag(named: "Cuba", for: "owner", at: UserDataFixture.now)
        let berlin = try fixture.store.createTag(named: "berlin", for: "owner", at: UserDataFixture.now)
        let idle = try fixture.store.createTag(named: "Idle", for: "owner", at: UserDataFixture.now)
        let theirs = try fixture.store.createTag(named: "Theirs", for: "reader", at: UserDataFixture.now)
        // Notes: the older on d1, the newer on frus1894Nicaragua's d1, a project's with no document, and
        // one whose tag's id is in lower case; assignments: d2, then d1 again, then a catalogued volume the
        // index does not hold, and one of a deleted tag.
        try rows.addNote("70000000-0000-4000-8000-000000000001", documentId: "d1", tagIds: [cuba.id],
                         lastModified: "2026-02-01T00:00:00.000Z")
        try rows.addNote("70000000-0000-4000-8000-000000000002", volumeId: "frus1894Nicaragua", documentId: "d1",
                         tagIds: [cuba.id.lowercased(), berlin.id], lastModified: "2026-03-01T00:00:00.000Z")
        try rows.addNote("70000000-0000-4000-8000-000000000003", volumeId: "", documentId: "", tagIds: [cuba.id],
                         lastModified: "2026-04-01T00:00:00.000Z")
        try rows.addAssignment("A1", documentId: "d2", tagId: cuba.id)
        try rows.addAssignment("A2", documentId: "d1", tagId: cuba.id)
        try rows.addAssignment("A3", volumeId: Self.v30, documentId: "d12", tagId: cuba.id)
        try rows.addAssignment("A4", documentId: "d2", tagId: UUID().uuidString)
        try rows.addAssignment("A5", user: "reader", documentId: "d2", tagId: theirs.id)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let list = try decode(AddDocumentsTags.self, try await owner.get(Self.tags))
            #expect(list.items.map(\.name) == ["berlin", "Cuba", "Idle"], "the tag list's order")
            #expect(list.total == 3 && list.items.map(\.count) == [1, 4, 0])
            #expect(list.items.map(\.id) == [berlin.id, cuba.id, idle.id])

            let gathered = try decode(AddDocumentsTag.self, try await owner.get("\(Self.tags)/\(cuba.id.lowercased())"))
            #expect(gathered.id == cuba.id && gathered.name == "Cuba" && gathered.total == 4)
            #expect(gathered.items.map { "\($0.volumeId)/\($0.documentId)" }
                    == ["frus1894Nicaragua/d1", "\(Self.v06)/d1", "\(Self.v06)/d2", "\(Self.v30)/d12"])
            #expect(gathered.items.map(\.header) == ["No. 1. Mr. Baker to Mr. Gresham", "1. Telegram From the Embassy in the Soviet Union",
                                                     "2. Memorandum of Conversation", nil])
            #expect(gathered.items.map(\.volumeTitle) == ["frus1894Nicaragua", Self.v06, Self.v06, Self.v30]
                .map { fixture.server.resources.volume($0)?.title })
            let none = try decode(AddDocumentsTag.self, try await owner.get("\(Self.tags)/\(idle.id)"))
            #expect(none.total == 0 && none.items.isEmpty)

            for stranger in [theirs.id, "not-a-tag", UUID().uuidString] {
                let refused = try await owner.get("\(Self.tags)/\(stranger)")
                #expect(refused.status == .notFound && problemCode(refused) == "TAG_NOT_FOUND")
            }
            let query = try await owner.get("\(Self.tags)?sort=name")
            #expect(query.status == .badRequest && problemCode(query) == "UNKNOWN_PARAMETER")
        }
    }

    /// A tag's documents are gathered as the route gathers them on either store, the kit's union over
    /// the store's notes and its new read of the assignments, in the order the store took them.
    @Test(arguments: UserStoreKind.available) func aTagsDocumentsAreTheKitsUnionOnEitherStore(_ kind: UserStoreKind) async throws {
        let test = try await TestUserStore.open(kind)
        defer { withExtendedLifetime(test) {} }
        let store = test.store
        let tag = try store.createTag(named: "Cuba", for: "owner", at: UserDataFixture.now)
        let other = try store.createTag(named: "Other", for: "owner", at: UserDataFixture.now)
        try test.rows.addNote("70000000-0000-4000-8000-000000000001", documentId: "d9", tagIds: [tag.id],
                              lastModified: "2026-02-01T00:00:00.000Z")
        try test.rows.addNote("70000000-0000-4000-8000-000000000002", documentId: "d8", tagIds: [other.id, tag.id],
                              lastModified: "2026-03-01T00:00:00.000Z")
        try store.setTags([tag.id], of: DocumentKey(volumeId: Self.v06, documentId: "d3"), for: "owner", at: UserDataFixture.now)
        try test.rows.addAssignment("LATER", documentId: "d1", tagId: tag.id, createdAt: "2027-01-01T00:00:00.000Z")
        try test.rows.addAssignment("EARLIER", documentId: "d2", tagId: tag.id, createdAt: "2020-01-01T00:00:00.000Z")
        try test.rows.addAssignment("AGAIN", documentId: "d9", tagId: tag.id)

        let union = try TagUnion.read(for: "owner", in: store)
        #expect(union.documents(of: tag.id).map { "\($0.volumeId)/\($0.documentId)" }
                == ["d8", "d9", "d3", "d1", "d2"].map { "\(Self.v06)/\($0)" },
                "the newer note's first; the assignments as the store took them, each document once")
        #expect(union.documents(of: other.id).map(\.documentId) == ["d8"])
        #expect(union.documents(of: "not-a-tag").isEmpty)
        #expect(union.documents(of: tag.id).map(\.documentId) == CollectionGeneratedBlocks.tagDocumentRefs(
            tagId: try #require(UUID(uuidString: tag.id)),
            noteTags: try store.notes(for: "owner").map { (volumeId: $0.volumeId, documentId: $0.documentId,
                                                           tagIds: $0.userTagIds.compactMap(UUID.init(uuidString:))) },
            assignments: try store.tagAssignments(of: "owner").compactMap { a in
                UUID(uuidString: a.tagId).map { (volumeId: a.volumeId, documentId: a.documentId, tagId: $0) }
            }).map(\.documentId))
    }
}
