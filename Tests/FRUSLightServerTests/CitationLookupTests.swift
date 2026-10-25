// Citation Lookup through the router (PLAN's S19a): Paste Citation, Structured Entry and Batch over
// the synthetic export, with no index and under a path, and every refusal. FRUSParityTests holds every
// answer to the kit's own over the fixture index: check 7's matcher half through the API.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct CitationLookupTests {
    /// The synthetic export with each frus1961-63v06 document's number, as the indexer writes a
    /// printed number, and the record that the volume's last store pass finished, which a real
    /// export holds for every volume it indexed.
    static let numbered = """
        UPDATE document_cache SET document_number = substr(document_id, 2) WHERE volume_id = 'frus1961-63v06';
        INSERT INTO volume_structures (volume_id, structure_json) VALUES ('frus1961-63v06', '[]');
        """

    /// The query string for `items`, every byte outside `A-Z a-z 0-9 - . _ ~` percent-encoded.
    static func query(_ items: [(String, String)]) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        func encode(_ text: String) -> String { text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "" }
        return items.map { "\(encode($0.0))=\(encode($0.1))" }.joined(separator: "&")
    }

    static func lookup(_ client: any TestClientProtocol, _ items: [(String, String)]) async throws -> [CitationLookupMatch] {
        let response = try await client.execute(uri: "/api/v1/citation-lookup?\(query(items))", method: .get)
        #expect(response.status == .ok, "\(String(buffer: response.body))")
        return try decode([CitationLookupMatch].self, response)
    }

    static func batch(_ client: any TestClientProtocol, _ block: String) async throws -> TestResponse {
        try await client.execute(uri: "/api/v1/citation-lookup/batch", method: .post,
                                 headers: [.contentType: "application/x-www-form-urlencoded;charset=UTF-8"],
                                 body: ByteBuffer(string: query([("text", block)])))
    }

    /// With no index served, the matcher answers from the catalogue alone, as the app's does with
    /// nothing downloaded: the volume a citation names is one to download, with its manifest entry.
    /// Each value the draft makes nullable is written as null.
    @Test func withNoIndexTheCatalogueAnswers() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/citation-lookup?\(Self.query([("text", "FRUS, 1961–1963, vol. VI, doc. 1")]))", method: .get)
            let matches = try decode([CitationLookupMatch].self, response)
            #expect(matches.count == 1)
            let match = try #require(matches.first)
            #expect(match.volumeId == "frus1961-63v06" && match.documentId.isEmpty && match.rank == 1)
            #expect(match.matchStrategy == "manifestOnly" && match.requiresDownload && !match.awaitingIndex && !match.isBestGuess)
            #expect(match.confidenceLabel == ConfidenceLabels.manifestOnly)
            #expect(match.volumeManifestEntry == fixture.resources.volume("frus1961-63v06"))
            let json = try #require(try JSONSerialization.jsonObject(with: Data(buffer: response.body)) as? [[String: Any]]).first
            #expect(json?["correctionNote"] is NSNull && json?["sharedPageTotal"] is NSNull && json?["bestGuessExplanation"] is NSNull)

            // A volume in parts: Structured Entry's Part takes a Roman numeral, as the app's field does.
            let parts = try await Self.lookup(client, [("subseries", "1952-54"), ("volumeNumber", "II"), ("partNumber", "II"), ("documentNumber", "41")])
            #expect(parts.map(\.volumeId) == ["frus1952-54v02p2"] && parts.first?.confidenceLabel == ConfidenceLabels.manifestOnly)
        }
    }

    /// Paste Citation looks the text up as the app's does, its Parsed Fields derived from the text by
    /// the kit; a field the request gives stands for the reader's edit of it. A link names its
    /// document exactly, until a field it filled is edited, when the fields decide.
    @Test func pasteCitationReadsTheTextAndTheReadersEdits() async throws {
        let fixture = try await servingSyntheticExport(volumes: ["frus1961-63v06"], edits: Self.numbered)
        try await fixture.app.test(.router) { client in
            let cited = try await Self.lookup(client, [("text", "FRUS, 1961–1963, vol. VI, doc. 1")])
            #expect(cited.map(\.documentId) == ["d1"] && cited.first?.matchStrategy == "exactDocumentNumber")
            #expect(cited.first?.confidenceLabel == ConfidenceLabels.exactMatch && cited.first?.volumeManifestEntry == nil)
            let edited = try await Self.lookup(client, [("text", "FRUS, 1961–1963, vol. VI, doc. 1"), ("documentNumber", "2")])
            #expect(edited.map(\.documentId) == ["d2"])

            let link = "https://history.state.gov/historicaldocuments/frus1961-63v06/d2"
            let linked = try await Self.lookup(client, [("text", link)])
            #expect(linked.map(\.documentId) == ["d2"] && linked.first?.matchStrategy == "exactDocumentNumber")
            // The form as the paste filled it; with the number edited, the link no longer decides.
            let form = try decode(CitationLookupForm.self, try await client.execute(uri: "/api/v1/citation-lookup/fields?\(Self.query([("text", link)]))", method: .get))
            let fields = [("subseries", form.subseries), ("volumeNumber", form.volumeNumber), ("partNumber", form.partNumber), ("pageNumber", form.pageNumber)]
            let unlinked = try await Self.lookup(client, [("text", link), ("documentNumber", "1")] + fields)
            #expect(form.documentNumber != "1" && unlinked.map(\.documentId) == ["d1"], "\(form) \(unlinked)")

            // A page: the document that begins on it.
            let page = try await Self.lookup(client, [("text", "FRUS, 1961–1963, vol. VI, p. 2")])
            #expect(page.map(\.documentId) == ["d2"] && page.first?.matchStrategy == "pageRange"
                    && page.first?.confidenceLabel.hasPrefix("Matched by page number") == true)
            // A volume the index does not hold is one to download.
            let elsewhere = try await Self.lookup(client, [("text", "FRUS, 1961–1963, vol. V, doc. 84")])
            #expect(elsewhere.map(\.volumeId) == ["frus1961-63v05"] && elsewhere.first?.requiresDownload == true)
            // A cited part the volume does not have: a best guess, which says so.
            let guess = try #require(try await Self.lookup(client, [("text", "FRUS, 1961–1963, vol. VI, pt. 2, doc. 1")]).first)
            #expect(guess.documentId == "d1" && guess.matchStrategy == "bestGuess" && guess.isBestGuess)
            #expect(guess.confidenceLabel == ConfidenceLabels.bestGuess(ConfidenceLabels.unmetFields(["part 2"])))
            #expect(guess.bestGuessExplanation == ConfidenceLabels.unmetFields(["part 2"]) && guess.correctionNote == ConfidenceLabels.unmetFieldsNote)
            // Nothing to go on: nothing found, as the kit's matcher answers.
            #expect(try await Self.lookup(client, [("text", "A memorandum with no citation in it.")]).isEmpty)
        }
    }

    /// Structured Entry reads its five fields as the app's form reads them: white space around a
    /// number is dropped, a volume may be Arabic, and a document or page that is no whole number is
    /// none, never a refusal.
    @Test func structuredEntryReadsTheFieldsAsTheAppsFormDoes() async throws {
        let fixture = try await servingSyntheticExport(volumes: ["frus1961-63v06"], edits: Self.numbered)
        try await fixture.app.test(.router) { client in
            let arabic = try await Self.lookup(client, [("subseries", "1961-63"), ("volumeNumber", "6"), ("documentNumber", " 2 ")])
            #expect(arabic.map(\.documentId) == ["d2"])
            let explicit = try await Self.lookup(client, [("mode", "structured"), ("subseries", "1961–63"), ("volumeNumber", "VI"), ("pageNumber", "1")])
            #expect(explicit.map(\.documentId) == ["d1"] && explicit.first?.matchStrategy == "pageRange")
            // A document that is no number is none, which leaves the volume alone: nothing to find in it.
            #expect(try await Self.lookup(client, [("subseries", "1961-63"), ("volumeNumber", "VI"), ("documentNumber", "abc")]).isEmpty)
            #expect(try await Self.lookup(client, []).isEmpty)
        }
    }

    /// A downloaded volume whose index cannot say yet what it holds (#1522): the synthetic export
    /// keeps no record that frus1961-63v06's store finished, so a document it does not hold is
    /// answered with the volume, not yet indexed, and one it holds is found.
    @Test func aVolumeTheIndexCannotAnswerForIsNotYetIndexed() async throws {
        let fixture = try await servingSyntheticExport(volumes: ["frus1961-63v06"])
        try await fixture.app.test(.router) { client in
            let waiting = try #require(try await Self.lookup(client, [("text", "FRUS, 1961–1963, vol. VI, doc. 9")]).first)
            #expect(waiting.volumeId == "frus1961-63v06" && waiting.documentId.isEmpty && waiting.awaitingIndex && !waiting.requiresDownload)
            #expect(waiting.confidenceLabel == ConfidenceLabels.notYetIndexed && waiting.volumeManifestEntry?.volumeId == "frus1961-63v06")
            let linked = try await Self.lookup(client, [("text", "https://history.state.gov/historicaldocuments/frus1961-63v06/d1")])
            #expect(linked.map(\.documentId) == ["d1"])
        }
    }

    /// The form's fields and Look Up's gate, in each mode, as the kit's form gives them.
    @Test func theFormDerivesTheFieldsAndGatesLookUp() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            func form(_ items: [(String, String)]) async throws -> CitationLookupForm {
                let response = try await client.execute(uri: "/api/v1/citation-lookup/fields?\(Self.query(items))", method: .get)
                #expect(response.status == .ok, "\(String(buffer: response.body))")
                return try decode(CitationLookupForm.self, response)
            }
            let pasted = try await form([("text", "Foreign Relations of the United States, 1952–1954, Volume II, Part 2, Document 41.")])
            #expect(pasted == CitationLookupForm(mode: "paste", subseries: "1952-54", volumeNumber: "II", partNumber: "2",
                                                 documentNumber: "41", pageNumber: "", actionable: true))
            #expect(try await form([("text", "")]) == CitationLookupForm(mode: "paste", subseries: "", volumeNumber: "", partNumber: "",
                                                                        documentNumber: "", pageNumber: "", actionable: false))
            // The reader's edit stands, and Look Up follows it.
            let cleared = try await form([("text", "FRUS, 1961–1963, vol. VI, doc. 1"), ("volumeNumber", ""), ("documentNumber", "")])
            #expect(cleared.subseries == "1961-63" && cleared.volumeNumber.isEmpty && cleared.documentNumber.isEmpty && !cleared.actionable)
            #expect(try await form([("mode", "structured"), ("documentNumber", "abc")]).actionable == false)
            #expect(try await form([("mode", "structured"), ("volumeNumber", "VI")]).actionable)
            #expect(try await form([("mode", "structured"), ("pageNumber", "47")]) == CitationLookupForm(
                mode: "structured", subseries: "", volumeNumber: "", partNumber: "", documentNumber: "", pageNumber: "47", actionable: true))
            #expect(try await form([("mode", "batch"), ("text", "1. ")]).actionable == false)
            #expect(try await form([("mode", "batch"), ("text", "1. FRUS, 1961–1963, vol. VI, doc. 1")]).actionable)
        }
    }

    /// Batch splits the block on its notes' numbers and triages each, row by row in the order of the
    /// paste, with the table's summary, as the app's Batch does.
    @Test func batchTriagesEveryNoteOfABlock() async throws {
        let fixture = try await servingSyntheticExport(volumes: ["frus1961-63v06"], edits: Self.numbered)
        let block = """
            1. FRUS, 1961–1963, vol. VI, doc. 1.
            2. https://history.state.gov/historicaldocuments/frus1961-63v06/d2
            [3] FRUS, 1961–1963,
            vol. V, doc. 84.
            4) Memorandum, no citation at all.
            5. FRUS, 1961–1963, vol. VI, pt. 2, doc. 1.
            """
        try await fixture.app.test(.router) { client in
            let response = try await Self.batch(client, block)
            #expect(response.status == .ok, "\(String(buffer: response.body))")
            let batch = try decode(CitationBatch.self, response)
            #expect(batch.summary == "5 citations · 2 resolved · 1 ambiguous · 1 best guess · 1 unresolved")
            #expect(batch.items.map(\.index) == [1, 2, 3, 4, 5] && batch.items.map(\.marker) == ["1", "2", "3", "4", "5"])
            #expect(batch.items[2].text == "FRUS, 1961–1963, vol. V, doc. 84.", "a note wrapped across lines is rejoined")
            #expect(batch.items.map(\.outcome) == ["resolved", "resolved", "ambiguous", "missing", "bestGuess"])
            #expect(batch.items.map(\.triageOrder) == [4, 4, 3, 1, 2])
            #expect(batch.items[2].count == 1 && batch.items[2].loneCandidateLabel == ConfidenceLabels.manifestOnly)
            #expect(batch.items[4].loneCandidateLabel == ConfidenceLabels.bestGuess(ConfidenceLabels.unmetFields(["part 2"])))
            #expect(batch.items[0].matches.map(\.documentId) == ["d1"] && batch.items[3].matches.isEmpty && batch.items[0].count == nil)

            let empty = try decode(CitationBatch.self, try await Self.batch(client, " \n\n "))
            #expect(empty.items.isEmpty && empty.summary == "0 citations · 0 resolved · 0 ambiguous · 0 best guesses · 0 unresolved")
        }
    }

    /// What each route refuses: a parameter it does not take, the draft's three it takes from the text
    /// instead, a mode it does not run, text in Structured Entry, a field given twice, a block of more
    /// citations than Batch looks up at once, and a body past its bound. Every GET route answers HEAD.
    @Test func eachRouteRefusesWhatItDoesNotTake() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            func refused(_ path: String, _ status: HTTPResponse.Status = .badRequest) async throws -> APIProblem.Body {
                try problem(try await client.execute(uri: path, method: .get), status)
            }
            #expect(try await refused("/api/v1/citation-lookup?keywords=x").code == "UNKNOWN_PARAMETER")
            for name in ["volumeId", "documentId", "titleFragment"] {
                let body = try await refused("/api/v1/citation-lookup?\(name)=x")
                #expect(body.code == "UNSUPPORTED_PARAMETER" && body.detail.contains("as text"), "\(name)")
            }
            #expect(try await refused("/api/v1/citation-lookup?mode=batch&text=x").code == "INVALID_PARAMETER")
            #expect(try await refused("/api/v1/citation-lookup?mode=other").code == "INVALID_PARAMETER")
            #expect(try await refused("/api/v1/citation-lookup?mode=structured&text=x").code == "INVALID_PARAMETER")
            #expect(try await refused("/api/v1/citation-lookup?documentNumber=1&documentNumber=2").code == "INVALID_PARAMETER")
            #expect(try await refused("/api/v1/citation-lookup?text=%E2%80").code == "MALFORMED_QUERY")
            #expect(try await refused("/api/v1/citation-lookup/fields?style=x").code == "UNKNOWN_PARAMETER")

            let unknown = try problem(try await client.execute(uri: "/api/v1/citation-lookup/batch", method: .post,
                                                               headers: [.contentType: "application/x-www-form-urlencoded"],
                                                               body: ByteBuffer(string: "block=x")), .badRequest)
            #expect(unknown.code == "UNKNOWN_PARAMETER")
            let notes = (1...(CitationLookupRoutes.batchLimit + 1)).map { "\($0 % 999 + 1). FRUS, vol. V, doc. \($0)." }.joined(separator: "\n")
            let tooMany = try problem(try await Self.batch(client, notes), .badRequest)
            #expect(tooMany.code == "TOO_MANY_CITATIONS" && tooMany.detail.contains("501"))
            let tooLarge = try problem(try await Self.batch(client, String(repeating: "x", count: CitationLookupRoutes.bodyLimit)), .contentTooLarge)
            #expect(tooLarge.code == "CONTENT_TOO_LARGE")
            #expect(try await client.execute(uri: "/api/v1/citation-lookup/batch", method: .get).status == .notFound)

            for path in ["/api/v1/citation-lookup?text=FRUS%2C+1961-63%2C+vol.+VI", "/api/v1/citation-lookup/fields?text=x"] {
                let head = try await client.execute(uri: path, method: .head)
                #expect(head.status == .ok && head.body.readableBytes == 0, "\(path)")
            }
        }
    }

    /// Each read answers a POST of its fields as a form body as it answers them in the query, as
    /// `/search/inspect` does, so a paste longer than a proxy takes in an address is looked up whole.
    @Test func eachReadAnswersAPostedFormAsItsQuery() async throws {
        let fixture = try await servingSyntheticExport(volumes: ["frus1961-63v06"], edits: Self.numbered)
        try await fixture.app.test(.router) { client in
            func post(_ path: String, _ items: [(String, String)]) async throws -> TestResponse {
                try await client.execute(uri: path, method: .post, headers: [.contentType: "application/x-www-form-urlencoded"],
                                         body: ByteBuffer(string: Self.query(items)))
            }
            let items = [("text", "FRUS, 1961–1963, vol. VI, doc. 1"), ("documentNumber", "2")]
            let posted = try decode([CitationLookupMatch].self, try await post("/api/v1/citation-lookup", items))
            #expect(posted == (try await Self.lookup(client, items)) && posted.map(\.documentId) == ["d2"])
            let form = try decode(CitationLookupForm.self, try await post("/api/v1/citation-lookup/fields", [("mode", "structured"), ("pageNumber", "47")]))
            #expect(form.actionable && form.pageNumber == "47")
            // A citation inside a page of prose: an address of 20,000 characters, which nginx refuses.
            let long = String(repeating: "A memorandum of no consequence. ", count: 600) + "FRUS, 1961–1963, vol. VI, doc. 1"
            #expect(try decode([CitationLookupMatch].self, try await post("/api/v1/citation-lookup", [("text", long)])).map(\.documentId) == ["d1"])
            #expect(try problem(try await post("/api/v1/citation-lookup", [("bogus", "1")]), .badRequest).code == "UNKNOWN_PARAMETER")
            // A block of notes as Batch sends it, for Look Up's gate.
            let block = (1...200).map { "\($0). FRUS, 1961–1963, vol. VI, doc. \($0 % 2 + 1)." }.joined(separator: "\n")
            #expect(try decode(CitationLookupForm.self, try await post("/api/v1/citation-lookup/fields", [("mode", "batch"), ("text", block)])).actionable)
        }
    }

    /// Batch runs the kit's runner a slice at a time, so a block whose request's task is stopped, as
    /// when its client goes, stops at the next slice rather than looking up every note; and the
    /// slices give the rows the runner gives the whole block, in order.
    @Test func batchStopsBetweenSlicesWhenItsTaskIsStopped() async throws {
        let resources = try TestResources.value()
        let engine = CitationMatchingEngine(manifestStore: FixedVolumeCatalogue(entries: resources.manifest),
                                            searchService: nil, pageRangeStore: nil, downloadedVolumeIds: [])
        let entries = CitationBlockSplitter.split((1...(BatchRows.slice * 3)).map { "\($0). FRUS, 1961–1963, vol. VI, doc. \($0)." }.joined(separator: "\n"))
        #expect(entries.count == BatchRows.slice * 3)
        let rows = try await BatchRows.collect(entries, engine: engine)
        #expect(rows.map(\.entry) == entries && rows.allSatisfy { $0.matches.first?.volumeId == "frus1961-63v06" })
        let stopped = Task { try await BatchRows.collect(entries, engine: engine) }
        stopped.cancel()
        await #expect(throws: CancellationError.self) { try await stopped.value }
    }

    /// Under a path, as behind a proxy that forwards it (PLAN's S14f).
    @Test func citationLookupAnswersUnderThePath() async throws {
        let fixture = try await ServerFixture()
        try await BasePathTests.app(fixture).test(.router) { client in
            let found = try await client.execute(uri: "/frus-explorer/api/v1/citation-lookup?\(Self.query([("text", "FRUS, 1961–1963, vol. VI, doc. 1")]))", method: .get)
            #expect(try decode([CitationLookupMatch].self, found).map(\.volumeId) == ["frus1961-63v06"])
            let batch = try await client.execute(uri: "/frus-explorer/api/v1/citation-lookup/batch", method: .post,
                                                 headers: [.contentType: "application/x-www-form-urlencoded"],
                                                 body: ByteBuffer(string: Self.query([("text", "1. FRUS, 1961–1963, vol. VI, doc. 1")])))
            #expect(try decode(CitationBatch.self, batch).items.count == 1)
            let refused = try problem(try await client.execute(uri: "/frus-explorer/api/v1/citation-lookup?bogus=1", method: .get), .badRequest)
            #expect(refused.instance == "/frus-explorer/api/v1/citation-lookup")
        }
    }
}
