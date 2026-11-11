// Add Documents' Citations and Tags through the router (PLAN's S25d): a paste resolved line by line by the
// kit's resolver into each of its buckets, over the served index and over the catalogue alone, each row
// with its document's head and its volume's title, a link to a numbered document of a catalogued volume the
// index does not hold resolved by its id, a paste past Batch's bound refused, and a stopped resolve stopping
// before its next line; and the Tags tab's list and a tag's documents, the kit's union of the user's notes
// and assignments, through the routes on either store.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

/// A server with a user store of `kind`, serving the synthetic export with each frus1961-63v06 document's
/// number (`CitationLookupTests.numbered`), or no index, built as `buildApplication` builds it.
struct AddDocumentsFixture {
    let server: ServerFixture
    let test: TestUserStore
    let services: UserDataServices

    init(kind: UserStoreKind = .sqlite, indexed: Bool = true) async throws {
        server = try await indexed ? servingSyntheticExport(edits: CitationLookupTests.numbered) : ServerFixture()
        test = try await TestUserStore.open(kind)
        let configuration = ServerConfiguration(dataDirectory: server.files.root, publicURL: "http://localhost:8080", userData: true)
        let secrets = try SecretVault.open(store: test.store, keyFile: server.files.secretKey, named: false).vault
        services = UserDataServices(store: test.store, configuration: configuration, secrets: secrets, jobs: InProcessJobQueue(),
                                    passwords: PasswordHasher(.leastCost), now: { UserDataFixture.now })
    }

    var app: some ApplicationProtocol {
        Application(router: ServedRouter(base: "", router: buildRouter(
            state: server.state, resources: server.resources, reader: server.reader, userData: services, base: "")))
    }

    func served() async throws -> ServedIndex {
        try await ServedIndexProvider(state: server.state, resources: server.resources, volumesDirectory: server.reader.volumesDirectory).served()
    }
}

@Suite struct AddDocumentsTests {
    static let citations = "/api/v1/me/add-documents/citations"
    static let tags = "/api/v1/me/add-documents/tags"
    static let v06 = "frus1961-63v06"
    /// A catalogued volume no fixture index holds.
    static let v30 = "frus1964-68v30"
    /// A volume the published catalogue does not list, as a Mac's side-loaded volume is named.
    static let sideloaded = "frus1900sideloaded"

    static func paste(_ text: String) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: ["text": text]), as: UTF8.self)
    }

    static func resolve(_ browser: Browser, _ text: String, sourceLocation: SourceLocation = #_sourceLocation) async throws -> AddDocumentsCitations {
        let response = try await browser.send(.post, citations, try paste(text))
        #expect(response.status == .ok, "\(String(buffer: response.body))", sourceLocation: sourceLocation)
        return try decode(AddDocumentsCitations.self, response)
    }

    /// The kit's resolver as the app's sheet builds it, over a matcher: what each line of `text` comes to.
    static func kit(_ text: String, over engine: CitationMatchingEngine) async -> [CollectionCitationLineResolver.Outcome] {
        let parser = CitationParser()
        return await CollectionCitationLineResolver(parse: { parser.parse($0) }, match: { try await engine.match(input: $0) })
            .resolve(text: text).map(\.outcome)
    }

    /// A line of the answer as the kit's outcome it carries.
    static func outcome(_ line: AddDocumentsCitations.Line) -> CollectionCitationLineResolver.Outcome {
        switch line.outcome {
        case "resolved": .resolved(volumeId: line.volumeId ?? "", documentId: line.documentId ?? "", note: line.note)
        case "ambiguous": .ambiguous(volumeId: line.volumeId ?? "", documentId: line.documentId ?? "", note: line.note ?? "")
        default: .unresolved(reason: line.reason ?? "")
        }
    }

    /// Each line of a paste has its row, in the paste's order, the kit's bucket and words: a citation and
    /// a link to documents the index holds resolve, with the heads the index holds; a citation of a part the
    /// volume does not have is the engine's best guess, to review; a link to a numbered document of a
    /// catalogued volume the index does not hold resolves by its id, with no head, as the app adds one from
    /// a volume it has not downloaded; a citation of that volume finds only the volume; and a line that is
    /// no citation says so. A blank line is none, and a line pasted twice is two rows.
    @Test func aPasteResolvesEachLineIntoItsBucket() async throws {
        let fixture = try await AddDocumentsFixture()
        defer { fixture.test.close() }
        let text = """
              FRUS, 1961–1963, vol. VI, doc. 1\r
            \r
            https://history.state.gov/historicaldocuments/frus1961-63v06/d2
            FRUS, 1961–1963, vol. VI, pt. 2, doc. 1
            https://history.state.gov/historicaldocuments/\(Self.v30)/d12
            FRUS, 1964–1968, vol. XXX, doc. 12
            a grocery list
            FRUS, 1961–1963, vol. VI, doc. 1
            """
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let resolved = try await Self.resolve(owner, text)
            #expect(resolved.total == 7 && resolved.items.count == 7)
            #expect(resolved.items.map(\.line) == [
                "FRUS, 1961–1963, vol. VI, doc. 1", "https://history.state.gov/historicaldocuments/frus1961-63v06/d2",
                "FRUS, 1961–1963, vol. VI, pt. 2, doc. 1", "https://history.state.gov/historicaldocuments/\(Self.v30)/d12",
                "FRUS, 1964–1968, vol. XXX, doc. 12", "a grocery list", "FRUS, 1961–1963, vol. VI, doc. 1",
            ])
            #expect(resolved.items.map(\.outcome) == ["resolved", "resolved", "ambiguous", "resolved", "unresolved", "unresolved", "resolved"])
            let v06Title = try #require(fixture.server.resources.volume(Self.v06)?.title)
            let first = resolved.items[0]
            #expect(first.volumeId == Self.v06 && first.documentId == "d1" && first.note == nil && first.reason == nil)
            #expect(first.header == "1. Telegram From the Embassy in the Soviet Union" && first.volumeTitle == v06Title)
            #expect(resolved.items[1].documentId == "d2" && resolved.items[1].header == "2. Memorandum of Conversation")
            // A part the volume does not have: the engine's best guess, for review, its label the note.
            let guess = resolved.items[2]
            #expect(guess.volumeId == Self.v06 && guess.documentId == "d1" && guess.header == "1. Telegram From the Embassy in the Soviet Union")
            #expect(guess.note == ConfidenceLabels.bestGuess(ConfidenceLabels.unmetFields(["part 2"])))
            // A link to a numbered document of a catalogued volume the index does not hold: by its id, no head.
            let linked = resolved.items[3]
            #expect(linked.volumeId == Self.v30 && linked.documentId == "d12" && linked.header == nil && linked.note == nil)
            #expect(linked.volumeTitle == fixture.server.resources.volume(Self.v30)?.title && linked.volumeTitle != nil)
            // A citation of that volume finds the volume alone, in the kit's words; a line that is no
            // citation never reaches the matcher.
            #expect(resolved.items[4].reason == ConfidenceLabels.manifestOnly && resolved.items[4].volumeId == nil)
            #expect(resolved.items[4].header == nil && resolved.items[4].volumeTitle == nil && resolved.items[4].note == nil)
            #expect(resolved.items[5].reason == "Couldn’t read this line as a FRUS citation or document link")
            #expect(resolved.items[6] == first, "a line pasted twice is two rows")

            // The kit's resolver, built as the app's sheet builds it, over the served index's matcher, answers
            // the same, line for line.
            #expect(await Self.kit(text, over: try await fixture.served().citations) == resolved.items.map(Self.outcome))

            // Nothing to resolve, nothing listed; nothing changed by any of it.
            #expect(try await Self.resolve(owner, " \n\t\r\n") == AddDocumentsCitations(total: 0, items: []))
            #expect(try fixture.test.store.collectionRows(of: "owner").collections.isEmpty)
        }
    }

    /// With no index served, the catalogue alone answers, as the app's matcher does with nothing
    /// downloaded: a citation finds only its volume, a link to a numbered document names it by its id, and
    /// a link to anything else in the volume, which may be a chapter, finds only the volume.
    @Test func withNoIndexTheCatalogueAloneAnswers() async throws {
        let fixture = try await AddDocumentsFixture(indexed: false)
        defer { fixture.test.close() }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let resolved = try await Self.resolve(owner, """
                FRUS, 1961–1963, vol. VI, doc. 1
                https://history.state.gov/historicaldocuments/frus1961-63v06/d1
                https://history.state.gov/historicaldocuments/frus1961-63v06/ch1
                """)
            #expect(resolved.items.map(\.outcome) == ["unresolved", "resolved", "unresolved"])
            #expect(resolved.items[0].reason == ConfidenceLabels.manifestOnly && resolved.items[2].reason == ConfidenceLabels.manifestOnly)
            #expect(resolved.items[1].volumeId == Self.v06 && resolved.items[1].documentId == "d1" && resolved.items[1].header == nil)
            #expect(resolved.items[1].volumeTitle == fixture.server.resources.volume(Self.v06)?.title)
        }
    }

    /// A paste is bounded as Batch's block is: 500 lines, and 256 KiB. Its body is the route's own JSON, and
    /// as a POST under /me it carries the user's token.
    @Test func aPastePastBatchsBoundIsRefused() async throws {
        let fixture = try await AddDocumentsFixture(indexed: false)
        defer { fixture.test.close() }
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

    /// The kit's resolver turns a lookup its task stopped into an unresolved line and goes on, so the route
    /// asks before each line: a stopped resolve throws before it looks the next line up, and gives no rows.
    @Test func aStoppedResolveStopsBeforeItsNextLine() async throws {
        let fixture = try await AddDocumentsFixture()
        defer { fixture.test.close() }
        let engine = try await fixture.served().citations
        let stopped = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await AddDocumentsRoutes.resolve(["FRUS, 1961–1963, vol. VI, doc. 1"], engine: engine)
        }
        await #expect(throws: CancellationError.self) { try await stopped.value }
        let going = try await Task { try await AddDocumentsRoutes.resolve(["FRUS, 1961–1963, vol. VI, doc. 1"], engine: engine) }.value
        #expect(going.map(\.outcome) == [.resolved(volumeId: Self.v06, documentId: "d1", note: nil)])
    }

    /// The Tags tab, through its routes on either store: each of the user's tags in the tag list's order, with
    /// how many documents the kit's union gathers for it over all their notes and assignments; and a tag's
    /// documents, the union's in its order, its notes' documents first, newest note first, then its
    /// assignments', each with the head the index holds, the catalogue's title, and whether the catalogue
    /// lists the volume. A note with no document gives none, an assignment of a tag the user no longer has
    /// names none, and a tag of another user's is none of theirs.
    @Test(arguments: UserStoreKind.available) func theTagsTabGathersEachTagsDocuments(_ kind: UserStoreKind) async throws {
        let fixture = try await AddDocumentsFixture(kind: kind)
        defer { fixture.test.close() }
        let (store, rows) = (fixture.test.store, fixture.test.rows)
        try rows.addUser("reader")
        let cuba = try store.createTag(named: "Cuba", for: "owner", at: UserDataFixture.now)
        let berlin = try store.createTag(named: "berlin", for: "owner", at: UserDataFixture.now)
        let idle = try store.createTag(named: "Idle", for: "owner", at: UserDataFixture.now)
        let theirs = try store.createTag(named: "Theirs", for: "reader", at: UserDataFixture.now)
        // Notes: the older on d1, the newer on frus1894Nicaragua's d1 with Cuba's id in lower case, and a
        // project's, the newest, with no document; assignments: d2, d1 again, a catalogued volume the index
        // does not hold, a volume the catalogue does not list, a deleted tag's and another user's.
        try rows.addNote("70000000-0000-4000-8000-000000000001", documentId: "d1", tagIds: [cuba.id],
                         lastModified: "2026-02-01T00:00:00.000Z")
        try rows.addNote("70000000-0000-4000-8000-000000000002", volumeId: "frus1894Nicaragua", documentId: "d1",
                         tagIds: [cuba.id.lowercased(), berlin.id], lastModified: "2026-03-01T00:00:00.000Z")
        try rows.addNote("70000000-0000-4000-8000-000000000003", volumeId: "", documentId: "", tagIds: [cuba.id],
                         lastModified: "2026-04-01T00:00:00.000Z")
        try rows.addAssignment("A1", documentId: "d2", tagId: cuba.id)
        try rows.addAssignment("A2", documentId: "d1", tagId: cuba.id)
        try rows.addAssignment("A3", volumeId: Self.v30, documentId: "d12", tagId: cuba.id)
        try rows.addAssignment("A4", volumeId: Self.sideloaded, documentId: "d3", tagId: cuba.id)
        try rows.addAssignment("A5", documentId: "d2", tagId: UUID().uuidString)
        try rows.addAssignment("A6", user: "reader", documentId: "d2", tagId: theirs.id)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let list = try decode(AddDocumentsTags.self, try await owner.get(Self.tags))
            #expect(list.items.map(\.name) == ["berlin", "Cuba", "Idle"], "the tag list's order")
            #expect(list.total == 3 && list.items.map(\.count) == [1, 5, 0])
            #expect(list.items.map(\.id) == [berlin.id, cuba.id, idle.id])

            let gathered = try decode(AddDocumentsTag.self, try await owner.get("\(Self.tags)/\(cuba.id.lowercased())"))
            #expect(gathered.id == cuba.id && gathered.name == "Cuba" && gathered.total == 5)
            #expect(gathered.items.map { "\($0.volumeId)/\($0.documentId)" }
                    == ["frus1894Nicaragua/d1", "\(Self.v06)/d1", "\(Self.v06)/d2", "\(Self.v30)/d12", "\(Self.sideloaded)/d3"])
            #expect(gathered.items.map(\.header) == ["No. 1. Mr. Baker to Mr. Gresham", "1. Telegram From the Embassy in the Soviet Union",
                                                     "2. Memorandum of Conversation", nil, nil])
            #expect(gathered.items.map(\.volumeTitle) == ["frus1894Nicaragua", Self.v06, Self.v06, Self.v30, Self.sideloaded]
                .map { fixture.server.resources.volume($0)?.title })
            #expect(gathered.items.map(\.catalogued) == [true, true, true, true, false])
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

    /// The union the routes give is the kit's over the whole of the store's notes with a document and its
    /// assignments, in the order the store took them: handing the kit each tag's own gives the same answer.
    /// A project's note, with no document, is what the routes pass over; the kit over every note would give
    /// it as a document with no id.
    @Test(arguments: UserStoreKind.available) func aTagsUnionIsTheKitsOverTheStoresRows(_ kind: UserStoreKind) async throws {
        let test = try await TestUserStore.open(kind)
        defer { test.close() }
        let store = test.store
        let tag = try store.createTag(named: "Cuba", for: "owner", at: UserDataFixture.now)
        let other = try store.createTag(named: "Other", for: "owner", at: UserDataFixture.now)
        try test.rows.addNote("70000000-0000-4000-8000-000000000001", documentId: "d9", tagIds: [tag.id],
                              lastModified: "2026-02-01T00:00:00.000Z")
        try test.rows.addNote("70000000-0000-4000-8000-000000000002", documentId: "d8", tagIds: [other.id, tag.id, tag.id],
                              lastModified: "2026-03-01T00:00:00.000Z")
        try test.rows.addNote("70000000-0000-4000-8000-000000000003", volumeId: "", documentId: "", tagIds: [tag.id],
                              lastModified: "2026-04-01T00:00:00.000Z")
        try store.setTags([tag.id], of: DocumentKey(volumeId: Self.v06, documentId: "d3"), for: "owner", at: UserDataFixture.now)
        try test.rows.addAssignment("LATER", documentId: "d1", tagId: tag.id, createdAt: "2027-01-01T00:00:00.000Z")
        try test.rows.addAssignment("EARLIER", documentId: "d2", tagId: other.id, createdAt: "2020-01-01T00:00:00.000Z")
        try test.rows.addAssignment("AGAIN", documentId: "d9", tagId: tag.id)

        let union = try TagUnion.read(for: "owner", in: store)
        let keys = { (refs: [(documentId: String, volumeId: String)]) in refs.map { "\($0.volumeId)/\($0.documentId)" } }
        #expect(keys(union.documents(of: tag.id)) == ["d8", "d9", "d3", "d1"].map { "\(Self.v06)/\($0)" },
                "the newer note's first; the assignments as the store took them, each document once")
        #expect(keys(union.documents(of: other.id)) == ["d8", "d2"].map { "\(Self.v06)/\($0)" })
        #expect(union.documents(of: "not-a-tag").isEmpty && union.documents(of: UUID().uuidString).isEmpty)
        for id in [tag.id, other.id] {
            let uuid = try #require(UUID(uuidString: id))
            #expect(keys(union.documents(of: id)) == keys(CollectionGeneratedBlocks.tagDocumentRefs(
                tagId: uuid, noteTags: union.noteTags, assignments: union.assignments)), "the kit's answer over the whole lists")
        }
        let everyNote = try store.notes(for: "owner").map { (volumeId: $0.volumeId, documentId: $0.documentId,
                                                               tagIds: $0.userTagIds.compactMap(UUID.init(uuidString:))) }
        let unfiltered = CollectionGeneratedBlocks.tagDocumentRefs(tagId: try #require(UUID(uuidString: tag.id)),
                                                                   noteTags: everyNote, assignments: union.assignments)
        #expect(keys(unfiltered) == ["/"] + keys(union.documents(of: tag.id)), "the project's note, which the routes pass over")
    }
}
