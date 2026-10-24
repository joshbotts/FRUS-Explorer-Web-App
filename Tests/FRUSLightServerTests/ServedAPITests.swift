// Search, the inspector, browsing and the reader's page through the router, over a synthetic export
// served read-only. FRUSParityTests runs the parity queries and every golden row through the same
// routes over the kit's fixture index.

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif
import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

/// A server fixture serving the synthetic export as its live index, with `edits`, SQL, made to it
/// first, such as a document's number or header as a real export would give them; with
/// `includesOwnText`, the export's rows of the kit's fixture for a section's own text.
func servingSyntheticExport(volumes: [String] = [], edits: String? = nil, includesOwnText: Bool = false) async throws -> ServerFixture {
    let fixture = try await ServerFixture(volumes: volumes)
    var export = SyntheticExport()
    export.includesOwnText = includesOwnText
    try export.write(to: fixture.files.liveIndex)
    if let edits {
        let index = try SQLiteConnection(fixture.files.liveIndex.path, readOnly: false)
        defer { index.close() }
        try index.execute(edits)
    }
    await fixture.state.openExistingIndex(files: fixture.files)
    return fixture
}

@Suite struct SearchRouteTests {
    @Test func searchWaitsForAnIndexNamingTheStep() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)
            let body = try problem(response, .serviceUnavailable)
            #expect(body.code == "INDEX_NOT_READY" && body.detail.contains("waiting_for_export"))
        }
    }

    @Test func aSearchGivesTheExactCountAndAPageOfResults() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)
            #expect(response.status == .ok)
            let list = try decode(SearchResultList.self, response)
            #expect(list.total == 2 && list.countBasis == "exact" && list.retainedLimit == 7_500)
            #expect(list.limit == 20 && list.offset == 0)
            #expect(Set(list.items.map(\.documentId)) == ["d1", "d2"] && list.items.allSatisfy { $0.volumeId == "frus1961-63v06" })
            // Both match in their prose, so both mark it (aSnippetMarksAMatchOnlyInTheProse).
            #expect(list.items.allSatisfy { $0.snippet.contains("<b>") && $0.bm25Score < 0 })
            #expect(list.coverage == Coverage(indexedVolumes: 2, indexedDocuments: 3, manifestVolumes: 553, indexVersion: IndexCompatibility.supportedIndexVersion))
            #expect(list.items.first?.header.isEmpty == false)

            let second = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=treaties&limit=1&offset=1", method: .get))
            #expect(second.total == 2 && second.items.count == 1 && second.items.first?.documentId == list.items.last?.documentId)
            let none = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=zanzibar", method: .get))
            #expect(none.total == 0 && none.items.isEmpty)
        }
    }

    /// A row names its document as the Mac's search window does: the header less a source note run
    /// on into it, and beside the volume the document's label, withheld when the header already
    /// opens with the number. A row with no header, which the window would leave blank, takes the
    /// name the app's lists give it.
    @Test func aRowNamesItsDocumentAsTheMacsSearchWindowDoes() async throws {
        // As a real export would hold them: numbers for the three rows, d2's header run on into its
        // source note as an index before v15 could leave it, and Nicaragua's d1 an editorial note
        // with no header.
        let fixture = try await servingSyntheticExport(edits: """
            UPDATE document_cache SET document_number = '1' WHERE document_id = 'd1';
            UPDATE document_cache SET document_number = '2',
                header = '2. Memorandum of Conversation Source: Department of State, Central Files, 611.61/5–2661'
              WHERE document_id = 'd2';
            UPDATE document_cache SET header = '', is_editorial_note = 1 WHERE volume_id = 'frus1894Nicaragua';
            """)
        try await fixture.app.test(.router) { client in
            let treaties = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get))
            let rows = Dictionary(uniqueKeysWithValues: treaties.items.map { ($0.documentId, $0) })
            let d1 = try #require(rows["d1"])
            #expect(d1.displayTitle == "1. Telegram From the Embassy in the Soviet Union" && d1.documentLabel == "Doc 1" && d1.headerRepeatsNumber)
            let d2 = try #require(rows["d2"])
            #expect(d2.displayTitle == "2. Memorandum of Conversation" && d2.header.hasSuffix("611.61/5–2661"))
            #expect(d2.documentLabel == "Doc 2" && d2.headerRepeatsNumber)
            let canal = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=canal", method: .get))
            let note = try #require(canal.items.first)
            #expect(note.header.isEmpty && note.displayTitle == "Editorial Note 1")
            #expect(note.documentLabel == "Doc 1" && !note.headerRepeatsNumber)
        }
        // With no number, the label is the one the id spells, and nothing withholds it.
        let unnumbered = try await servingSyntheticExport()
        try await unnumbered.app.test(.router) { client in
            let treaties = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get))
            #expect(treaties.items.allSatisfy { $0.displayTitle == $0.header && !$0.headerRepeatsNumber })
            #expect(Set(treaties.items.map(\.documentLabel)) == ["Doc 1", "Doc 2"])
        }
    }

    /// A row carries the kit's date and the words the Mac's window draws for a row that prints no
    /// dateline (#1746): a day, the span of the documents a section's row holds, a month, a year, or
    /// none for a row with no date. The rows here are dated as a real index dates them: every bound a
    /// day, a month's or a year's at its first and last.
    @Test func aRowCarriesItsDateAndTheWordsTheMacsWindowDrawsForIt() async throws {
        // d1 prints its dateline, and d2 none, dated by a span as a section's row is; Nicaragua's d1
        // is dated to a month.
        let fixture = try await servingSyntheticExport(edits: """
            UPDATE document_cache SET dateline = 'Moscow, November 9, 1960.' WHERE volume_id = 'frus1961-63v06' AND document_id = 'd1';
            UPDATE document_dates SET date_iso_max = '1961-01-20' WHERE volume_id = 'frus1961-63v06' AND document_id = 'd2';
            UPDATE document_dates SET date_iso = '1894-01-01', date_iso_max = '1894-03-31', date_precision = 'month'
              WHERE volume_id = 'frus1894Nicaragua';
            """)
        try await fixture.app.test(.router) { client in
            let treaties = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get))
            let rows = Dictionary(uniqueKeysWithValues: treaties.items.map { ($0.documentId, $0) })
            let d1 = try #require(rows["d1"])
            #expect(d1.dateline == "Moscow, November 9, 1960." && d1.dateISO == "1960-11-09" && d1.dateISOMax == "1960-11-09")
            #expect(d1.datePrecision == "day" && d1.drawnDate == "November 9, 1960", "the row draws its dateline; the words are there for a client that wants them")
            let d2 = try #require(rows["d2"])
            #expect(d2.dateline == nil && d2.dateISO == "1960-11-10" && d2.dateISOMax == "1961-01-20" && d2.datePrecision == "day")
            #expect(d2.drawnDate == "November 10, 1960 – January 20, 1961")
            let canal = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=canal", method: .get))
            let month = try #require(canal.items.first)
            #expect(month.datePrecision == "month" && month.drawnDate == "January 1894 – March 1894")
        }
        // A year's row, and a row the index gives no date.
        let other = try await servingSyntheticExport(edits: """
            UPDATE document_dates SET date_iso = '1960-01-01', date_iso_max = '1960-12-31', date_precision = 'year'
              WHERE volume_id = 'frus1961-63v06' AND document_id = 'd1';
            DELETE FROM document_dates WHERE volume_id = 'frus1894Nicaragua';
            """)
        try await other.app.test(.router) { client in
            let treaties = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get))
            #expect(treaties.items.first { $0.documentId == "d1" }?.drawnDate == "1960")
            let canal = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=canal", method: .get))
            let undated = try #require(canal.items.first)
            #expect(undated.dateISO == nil && undated.dateISOMax == nil && undated.datePrecision == nil && undated.drawnDate == nil)
        }
    }

    /// A snippet marks its match only in the document's own prose (#1736). A body opens with the
    /// row's heading, source note and dateline, which the row draws already: a row whose only match
    /// is there gets the opening of its prose with nothing marked, and a row with no match in its
    /// body at all its heading and dateline again, as the Mac's window draws both.
    @Test func aSnippetMarksAMatchOnlyInTheProse() async throws {
        let fixture = try await servingSyntheticExport(edits: """
            UPDATE document_cache SET dateline = 'Moscow, November 9, 1960.',
                body_text = '1. Telegram From the Embassy in the Soviet Union Moscow, November 9, 1960. '
                    || 'The ambassador was negotiating treaties with the minister.'
              WHERE volume_id = 'frus1961-63v06' AND document_id = 'd1';
            """)
        try await fixture.app.test(.router) { client in
            func snippets(_ keywords: String) async throws -> [String: String] {
                let list = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=\(keywords)", method: .get))
                return Dictionary(uniqueKeysWithValues: list.items.map { ("\($0.volumeId)/\($0.documentId)", $0.snippet) })
            }
            let prose = try await snippets("treaties")
            #expect(prose["frus1961-63v06/d1"]?.hasPrefix("The ambassador was negotiating <b>treaties</b>") == true)
            #expect(prose["frus1961-63v06/d2"]?.contains("<b>treaties</b>") == true)
            // In the heading the body opens with, and in the dateline after it: the prose, unmarked.
            for keywords in ["embassy", "moscow"] {
                let heading = try await snippets(keywords)
                #expect(heading == ["frus1961-63v06/d1": "The ambassador was negotiating treaties with the minister."], "\(keywords)")
            }
            // In the heading alone, which the body does not repeat: the heading again.
            let header = try await snippets("gresham")
            #expect(header == ["frus1894Nicaragua/d1": "No. 1. Mr. Baker to Mr. Gresham"])
        }
    }

    /// In an order of the date, a page is cut from what the app keeps of the search, sorted by the
    /// kit: oldest or newest first, undated documents last either way. By relevance it is as before,
    /// and every list offers the three orders by the kit's labels.
    @Test func aDateOrderPagesWhatTheAppKeepsByDate() async throws {
        @Sendable func order(_ client: any TestClientProtocol, _ query: String) async throws -> [String] {
            let list = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=negotiating+OR+canal&\(query)", method: .get))
            #expect(list.total == 3 && list.sortChoices.map(\.title) == ["Relevance", "Date ↑", "Date ↓"])
            #expect(list.sortChoices.map(\.value) == ["relevance", "dateAscending", "dateDescending"])
            return list.items.map { "\($0.volumeId)/\($0.documentId)" }
        }
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let ascending = try await order(client, "sort=dateAscending")
            let descending = try await order(client, "sort=dateDescending")
            let middle = try await order(client, "sort=dateDescending&limit=1&offset=1")
            #expect(ascending == ["frus1894Nicaragua/d1", "frus1961-63v06/d1", "frus1961-63v06/d2"])
            #expect(descending == ["frus1961-63v06/d2", "frus1961-63v06/d1", "frus1894Nicaragua/d1"])
            #expect(middle == ["frus1961-63v06/d1"])
            let relevance = try await order(client, "sort=relevance")
            let unsorted = try await order(client, "limit=20")
            #expect(relevance == unsorted)
            let list = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=canal&sort=dateAscending", method: .get))
            #expect(list.sort == "dateAscending" && list.items.map(\.documentId) == ["d1"])
            let byDefault = try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=canal", method: .get))
            #expect(byDefault.sort == "relevance")
        }
        let undated = try await servingSyntheticExport(edits: "DELETE FROM document_dates WHERE volume_id = 'frus1894Nicaragua';")
        try await undated.app.test(.router) { client in
            let ascending = try await order(client, "sort=dateAscending")
            let descending = try await order(client, "sort=dateDescending")
            #expect(ascending == ["frus1961-63v06/d1", "frus1961-63v06/d2", "frus1894Nicaragua/d1"])
            #expect(descending == ["frus1961-63v06/d2", "frus1961-63v06/d1", "frus1894Nicaragua/d1"])
        }
    }

    /// A query with nothing left to search is the kit's refusal, carried as it names it.
    @Test func aRefusedQueryIsAProblemCarryingTheKitsRefusal() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            for query in ["keywords=", "keywords=treaties&includeDocumentText=false&includeSummaries=false&includeNotes=false"] {
                let body = try problem(try await client.execute(uri: "/api/v1/search?\(query)", method: .get), .badRequest)
                #expect(body.code == "EMPTY_QUERY" && body.searchError == "emptyQuery", "\(query)")
            }
            let bad = try problem(try await client.execute(uri: "/api/v1/search?keywords=x&limit=500", method: .get), .badRequest)
            #expect(bad.code == "INVALID_PARAMETER")
        }
    }

    /// The inspector answers before an import, from a scratch compiler, and after, from the served
    /// stack, through GET or a form-encoded POST, compiling the same; a refused query is a 200 naming
    /// the refusal. The Query Inspector's account comes with the served index.
    @Test func theInspectorShowsWhatTheKitCompiles() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let before = try decode(SearchInspection.self, try await client.execute(uri: "/api/v1/search/inspect?keywords=%3Dtreaty+-canal", method: .get))
            #expect(before.parse.exactTerms == ["treaty"] && before.parse.operands.map(\.kind) == ["word", "word"])
            #expect(before.parse.operands.map(\.isNegated) == [false, true])
            #expect(before.search.corpus?.contains("treaty") == true && before.search.error == nil)

            try SyntheticExport().write(to: fixture.files.liveIndex)
            await fixture.state.openExistingIndex(files: fixture.files)
            let posted = try await client.execute(uri: "/api/v1/search/inspect", method: .post,
                                                  body: ByteBuffer(string: "keywords=%3Dtreaty+-canal"))
            let after = try decode(SearchInspection.self, posted)
            #expect(after.parse == before.parse && after.search == before.search)
            #expect(before.inspection == nil && after.inspection?.operands.map(\.operand.text) == ["treaty", "canal"])
            let refused = try await client.execute(uri: "/api/v1/search/inspect?keywords=", method: .get)
            #expect(refused.status == .ok)
            #expect(try decode(SearchInspection.self, refused).search.error == "emptyQuery")
        }
    }

    /// The Query Inspector's account waits for an index, which its passes read: before one, an
    /// inspection has none, and a pass is refused as a search is. Over one, each term has its stem and
    /// corpus counts, a scoped count when asked for, and the terms that match nothing are named.
    @Test func theInspectorsPassesReadTheServedIndex() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let before = try decode(SearchInspection.self, try await client.execute(uri: "/api/v1/search/inspect?keywords=negotiating", method: .get))
            #expect(before.inspection == nil && before.emptyConjuncts == nil)
            for pass in ["scopedCounts", "emptyConjuncts"] {
                let waits = try problem(try await client.execute(uri: "/api/v1/search/inspect?keywords=negotiating&\(pass)=true", method: .get), .serviceUnavailable)
                #expect(waits.code == "INDEX_NOT_READY", "\(pass)")
            }

            try SyntheticExport().write(to: fixture.files.liveIndex)
            await fixture.state.openExistingIndex(files: fixture.files)
            let cheap = try decode(SearchInspection.self, try await client.execute(uri: "/api/v1/search/inspect?keywords=negotiating+-canal", method: .get))
            let inspection = try #require(cheap.inspection)
            #expect(inspection.indexedVolumeCount == 2 && inspection.showsStrip && inspection.hasUncountedOperands)
            #expect(inspection.expression?.displayed == cheap.search.corpus)
            #expect(inspection.operands.map(\.operand.text) == ["negotiating", "canal"])
            let negotiating = try #require(inspection.operands.first)
            #expect(negotiating.stem == "negoti" && negotiating.isStemBroadening)
            #expect(negotiating.corpusDocumentFrequency == 2 && negotiating.corpusOccurrences == 2 && negotiating.scopedCount == nil)
            #expect(inspection.operands.last?.operand.isNegated == true && cheap.emptyConjuncts == nil)

            // Within the filters: of the two negotiating documents, one is dated by the 9th.
            let counted = try decode(SearchInspection.self, try await client.execute(uri: "/api/v1/search/inspect?keywords=negotiating+-canal&dateRangeLatest=1960-11-09&scopedCounts=true", method: .get))
            #expect(counted.inspection?.operands.map(\.scopedCount) == [1, nil], "an excluded term has no count")
            #expect(counted.inspection?.operands.first?.corpusDocumentFrequency == 2, "the corpus count ignores the filters")
            #expect(counted.inspection?.hasUncountedOperands == false)

            let blamed = try decode(SearchInspection.self, try await client.execute(uri: "/api/v1/search/inspect?keywords=negotiating+formosa&emptyConjuncts=true", method: .get))
            #expect(blamed.emptyConjuncts?.map(\.text) == ["formosa"])
            let none = try decode(SearchInspection.self, try await client.execute(uri: "/api/v1/search/inspect?keywords=negotiating+canal&emptyConjuncts=true", method: .get))
            #expect(none.emptyConjuncts == [], "each term matches something; only the combination matches nothing")

            let bad = try problem(try await client.execute(uri: "/api/v1/search/inspect?keywords=x&scopedCounts=yes", method: .get), .badRequest)
            #expect(bad.code == "INVALID_PARAMETER" && bad.detail.contains("scopedCounts"))

            // A query of more terms than the inspector looks up is compiled, and its terms are not looked up.
            let words = (1...65).map { "w\($0)" }
            let long = try decode(SearchInspection.self, try await client.execute(uri: "/api/v1/search/inspect?keywords=\(words.joined(separator: "+"))", method: .get))
            #expect(long.parse.operands.count == 65 && long.search.corpus != nil && long.inspection == nil)
            let refused = try problem(try await client.execute(uri: "/api/v1/search/inspect?keywords=\(words.joined(separator: "+"))&emptyConjuncts=true", method: .get), .badRequest)
            #expect(refused.code == "TOO_MANY_TERMS" && refused.detail.contains("64") && refused.detail.contains("65"))
            let most = try decode(SearchInspection.self, try await client.execute(uri: "/api/v1/search/inspect?keywords=\(words.dropLast().joined(separator: "+"))", method: .get))
            #expect(most.inspection?.operands.count == 64)
        }
    }

    /// A search between an import's rename of its file over `frus.db` and the server serving it
    /// waits: the path no longer names the served index's file, and a stack over it would answer as
    /// the old index.
    @Test func aSearchBetweenTheRenameAndTheSwitchWaits() async throws {
        let fixture = try await servingSyntheticExport()
        var next = SyntheticExport()
        next.exportedAt = "2026-10-07T09:00:00Z"
        let staged = fixture.directory.url.appendingPathComponent("next.sqlite")
        try next.write(to: staged)
        #expect(rename(staged.path, fixture.files.liveIndex.path) == 0)
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)
            let body = try problem(response, .serviceUnavailable)
            #expect(body.code == "INDEX_NOT_READY" && body.detail.contains("being installed"))
        }
    }

    /// An import that replaces the live index gives the next search a stack over the new file.
    @Test func aNewIndexGetsANewStack() async throws {
        let fixture = try await ServerFixture()
        let provider = ServedIndexProvider(state: fixture.state, resources: fixture.resources, volumesDirectory: fixture.files.volumesDirectory)
        let app = Application(router: buildRouter(state: fixture.state, resources: fixture.resources, reader: fixture.reader, provider: provider))
        let jobs = InProcessJobQueue()
        let coordinator = ImportCoordinator(files: fixture.files, importer: IndexImporter(files: fixture.files, writer: LocalIndexWriter(files: fixture.files)),
                                            state: fixture.state, jobs: jobs)
        @Sendable func importExport(_ export: SyntheticExport) async throws {
            try export.write(to: fixture.files.importDirectory.appendingPathComponent("export.sqlite"))
            _ = await coordinator.scan()
            _ = await coordinator.scan()
            await jobs.waitUntilIdle()
        }
        try await app.test(.router) { client in
            try await importExport(SyntheticExport())
            #expect(try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)).total == 2)
            #expect(try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=canal", method: .get)).total == 1)
            #expect(await provider.opened == 1)
            var second = SyntheticExport()
            second.exportedAt = "2026-10-07T09:00:00Z"
            try await importExport(second)
            #expect(try decode(SearchResultList.self, try await client.execute(uri: "/api/v1/search?keywords=treaties", method: .get)).total == 2)
            #expect(await provider.opened == 2)
        }
        #expect(FileManager.default.fileExists(atPath: fixture.files.previousIndex.path))
    }
}

@Suite struct BrowseRouteTests {
    @Test func aVolumesDocumentsAreListedInReadingOrder() async throws {
        let fixture = try await servingSyntheticExport()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents", method: .get)
            #expect(response.status == .ok)
            let list = try decode(DocumentList.self, response)
            #expect(list.total == 2 && list.items.map(\.documentId) == ["d1", "d2"] && list.items.allSatisfy(\.inIndex))
            #expect(list.items.first?.header == "1. Telegram From the Embassy in the Soviet Union")
            let page = try decode(DocumentList.self, try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents?limit=1&offset=1", method: .get))
            #expect(page.total == 2 && page.items.map(\.documentId) == ["d2"])
            // A catalogue volume the index does not hold has no documents.
            #expect(try decode(DocumentList.self, try await client.execute(uri: "/api/v1/volumes/frus1861/documents", method: .get)).total == 0)
        }
    }

    @Test func aDocumentsMetadataNamesItsNeighbours() async throws {
        let fixture = try await servingSyntheticExport(volumes: ["frus1961-63v06"])
        try await fixture.app.test(.router) { client in
            let detail = try decode(DocumentDetail.self, try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents/d1", method: .get))
            #expect(detail.document.documentId == "d1" && detail.document.inIndex && !detail.document.isEditorialNote)
            #expect(detail.canonicalURL == "https://history.state.gov/historicaldocuments/frus1961-63v06/d1")
            #expect(detail.previous == nil && detail.next?.documentId == "d2" && detail.teiAvailable)
            let missing = try problem(try await client.execute(uri: "/api/v1/volumes/frus1961-63v06/documents/d999", method: .get), .notFound)
            #expect(missing.code == "DOCUMENT_NOT_FOUND")
            #expect(try problem(try await client.execute(uri: "/api/v1/volumes/frus1969-76v99/documents/d1", method: .get), .notFound).code == "VOLUME_NOT_FOUND")
        }
    }

    @Test func browsingADocumentWaitsForAnIndex() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            for uri in ["/api/v1/volumes/frus1961-63v06/documents", "/api/v1/volumes/frus1961-63v06/documents/d1"] {
                let response = try await client.execute(uri: uri, method: .get)
                #expect(try problem(response, .serviceUnavailable).code == "INDEX_NOT_READY", "\(uri)")
            }
            // The catalogue does not wait.
            let volume = try await client.execute(uri: "/api/v1/volumes/frus1961-63v06", method: .get)
            #expect(volume.status == .ok)
        }
    }
}

@Suite struct ReaderPageRouteTests {
    static func uri(_ query: String = "") -> String { "/api/v1/volumes/frus1894Nicaragua/documents/d1/html\(query.isEmpty ? "" : "?\(query)")" }

    /// The page is the kit's, with the host script in its head and the fragment in its body, under
    /// a policy that runs nothing but the host script and the figure handler.
    @Test func thePageIsTheKitsWithTheHostScript() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        try await fixture.app.test(.router) { client in
            let page = try await client.execute(uri: Self.uri(), method: .get)
            #expect(page.status == .ok && page.headers[.contentType] == "text/html; charset=utf-8")
            let html = String(buffer: page.body)
            #expect(html.hasPrefix("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"))
            #expect(html.contains("<script src=\"/reader/host.js\" defer></script>\n</head>\n<body>\n"))
            #expect(html.hasSuffix("\n</body>\n</html>"))
            #expect(page.headers[.contentSecurityPolicy] == ReaderRoutes.pagePolicy)
            #expect(ReaderRoutes.pagePolicy.contains("script-src 'self'") && ReaderRoutes.pagePolicy.contains(ReaderRoutes.figureErrorHandlerHash))

            let body = String(buffer: try await client.execute(uri: Self.uri("part=body"), method: .get).body)
            #expect(html.contains("<body>\n\(body)\n</body>"), "the page's body is the fragment")
            let dark = String(buffer: try await client.execute(uri: Self.uri("colorScheme=dark&textSize=large"), method: .get).body)
            #expect(dark != html && dark.contains("<body>\n\(body)\n</body>"))
        }
    }

    /// The ETag names the rendering version and the page's bytes; asked again with it, the server
    /// answers 304.
    @Test func aPageAlreadyHeldIsNotSentAgain() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        try await fixture.app.test(.router) { client in
            let first = try await client.execute(uri: Self.uri(), method: .get)
            let tag = try #require(first.headers[.eTag])
            let version = try #require(first.headers[ReaderRoutes.renderingVersionHeader])
            #expect(tag.hasPrefix("W/\"\(version)-"))
            let again = try await client.execute(uri: Self.uri(), method: .get, headers: [.ifNoneMatch: tag])
            #expect(again.status == .notModified && again.body.readableBytes == 0)
            let dark = try await client.execute(uri: Self.uri("colorScheme=dark"), method: .get, headers: [.ifNoneMatch: tag])
            #expect(dark.status == .ok && dark.headers[.eTag] != tag)
        }
    }

    /// The index's effective classification reshapes the page, as the app's reader applies it: a
    /// document the index calls an editorial note is rendered as one, and the same document reads
    /// as its TEI shapes it when no index is served. The fixture index cannot show this, since its
    /// classifications are the TEI's.
    @Test func theIndexsClassificationReshapesThePage() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        let unserved = try await fixture.app.test(.router) { client in
            String(buffer: try await client.execute(uri: Self.uri("part=body"), method: .get).body)
        }
        try SyntheticExport().write(to: fixture.files.liveIndex)
        try SQLiteConnection(fixture.files.liveIndex.path, readOnly: false).execute(
            "UPDATE document_cache SET is_editorial_note = 1 WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd1'")
        await fixture.state.openExistingIndex(files: fixture.files)
        let served = try await fixture.app.test(.router) { client in
            String(buffer: try await client.execute(uri: Self.uri("part=body"), method: .get).body)
        }
        let parsed = try await fixture.reader.document(volume: "frus1894Nicaragua", document: "d1")
        #expect(!parsed.ast.isShapedAsEditorialNote, "the TEI shapes d1 as a document")
        let asNote = ReaderService.render(parsed, volume: "frus1894Nicaragua", classification: true, part: .body,
                                          base: .root, brokenRefs: fixture.resources.brokenRefs).html
        let asTEI = ReaderService.render(parsed, volume: "frus1894Nicaragua", classification: nil, part: .body,
                                         base: .root, brokenRefs: fixture.resources.brokenRefs).html
        #expect(asNote != asTEI)
        #expect(unserved == asTEI && served == asNote)
    }

    @Test func theHostScriptIsServed() async throws {
        let fixture = try await ServerFixture()
        try await fixture.app.test(.router) { client in
            let response = try await client.execute(uri: "/reader/host.js", method: .get)
            #expect(response.status == .ok && response.headers[.contentType] == "text/javascript; charset=utf-8")
            let script = String(buffer: response.body)
            #expect(script.contains("frus-reader") && script.contains("frusexplorer:") && script.contains("highlightTapped"))
            // A card hands focus back to the link, a middle click opens nothing, and Space activates an unresolved reference.
            #expect(script.contains("restoreFocus") && script.contains("auxclick") && script.contains("role') === 'button'"))
            #expect(script.contains("kind === 'reveal'") && script.contains("scrollIntoView"))
            // A note is landed on by the app's own script, byte for byte, its key the function's parameter.
            #expect(script.contains("function landOnFootnote(key) {\n    return \(FootnoteLanding.script(keyExpression: "key"));"))
            #expect(script.contains("var prefix = '\(ReaderLinkRoutes.footnoteEntryPrefix)';"))
            #expect(script == ReaderHostScript.source)
        }
    }

    /// A figure's image comes from the volume's `.figures` folder beside its TEI. Nothing else is
    /// served: not a name that leaves the folder, not another kind of file, not another volume.
    @Test func aFigureIsServedFromTheVolumesFigureFolder() async throws {
        let fixture = try await ServerFixture(volumes: ["frus1894Nicaragua"])
        let figures = fixture.files.volumesDirectory.appendingPathComponent("frus1894Nicaragua.figures", isDirectory: true)
        try FileManager.default.createDirectory(at: figures, withIntermediateDirectories: true)
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3])
        try png.write(to: figures.appendingPathComponent("map.png"))
        try Data("secret".utf8).write(to: figures.appendingPathComponent("notes.txt"))
        try Data("secret".utf8).write(to: fixture.files.root.appendingPathComponent("secret.png"))
        try await fixture.app.test(.router) { client in
            let image = try await client.execute(uri: "/api/v1/volumes/frus1894Nicaragua/figures/map.png", method: .get)
            #expect(image.status == .ok && image.headers[.contentType] == "image/png" && Data(buffer: image.body) == png)
            for (uri, code) in [
                ("/api/v1/volumes/frus1894Nicaragua/figures/absent.png", "FIGURE_NOT_FOUND"),
                ("/api/v1/volumes/frus1894Nicaragua/figures/notes.txt", "FIGURE_NOT_FOUND"),
                ("/api/v1/volumes/frus1894Nicaragua/figures/..%2F..%2Fsecret.png", "FIGURE_NOT_FOUND"),
                ("/api/v1/volumes/frus1894Nicaragua/figures/%2E%2E", "FIGURE_NOT_FOUND"),
                ("/api/v1/volumes/frus1969-76v99/figures/map.png", "VOLUME_NOT_FOUND"),
            ] {
                #expect(try problem(try await client.execute(uri: uri, method: .get), .notFound).code == code, "\(uri)")
            }
        }
    }

    /// The page names each figure by the server's address, which is the route above, under the
    /// server's base path.
    @Test func figuresAreNamedByTheServersAddress() throws {
        let image = FigureImageName(volumeId: "frus1969-76ve09p1", graphic: "SpanishSaharaMap.jpg")
        #expect(ReaderRoutes.figureURL(for: image, under: .root)?.absoluteString == "/api/v1/volumes/frus1969-76ve09p1/figures/SpanishSaharaMap.jpg.png")
        let base = try #require(BasePath("/frus-explorer/"))
        #expect(ReaderRoutes.figureURL(for: image, under: base)?.absoluteString == "/frus-explorer/api/v1/volumes/frus1969-76ve09p1/figures/SpanishSaharaMap.jpg.png")
        #expect(ReaderRoutes.figureURL(for: FigureImageName(volumeId: "../x", graphic: "a"), under: .root) == nil)
        #expect(ReaderRoutes.figureURL(for: FigureImageName(volumeId: nil, graphic: "a"), under: .root) == nil)
    }
}
