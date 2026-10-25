// Check 7's matcher half through the API (PLAN's S19a). The fixture index is imported as the owner's
// export is, and Citation Lookup's three modes are asked over HTTP: every answer is held, field by
// field, to the kit's own for the same citation, from an engine the test builds over the same file
// and the same catalogue with the kit's calls alone, as the app's Citation Lookup makes them
// (`CitationLookupFields`, `CitationMatchingEngine`, `CitationBlockSplitter`, `BatchCitationRunner`).
// Beside that, the kit's own expectations for its fixtures over the bundled catalogue hold through
// the API: its test of the app's own citation of every volume in all three styles
// (`ownCitationsAreNeverBestGuesses`), and its tests of titles printed whole, of the series' name, of
// a dated footnote and of links (CitationMatchingEngineTests, which FRUSCoreKitTests runs on Linux).
// Over the three indexed volumes the server answers with documents where a manifest-only engine
// answers with volumes; the volume each answer names is the same.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import FTS5Store
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSLightAPI

@Suite struct CitationLookupAPIParityTests {
    /// The kit's engine over the served index, the published catalogue and the three fixture volumes
    /// as the downloaded ones, opened read-only as the server opens its own, with the kit's calls.
    struct Kit: Sendable {
        let engine: CitationMatchingEngine
        let pipeline: IndexingPipeline
        let pages: PageRangeStore
        let catalogue: [VolumeManifestEntry]

        init(_ files: DataDirectory) throws {
            let store = try FTS5Store(readingDatabaseAt: files.liveIndex)
            pipeline = try IndexingPipeline(readingIndexAt: files.liveIndex, fts5Store: store, resources: .none,
                                            volumesDirectory: files.volumesDirectory)
            pages = try PageRangeStore(readingDatabaseAt: files.liveIndex)
            let manifest = try FixedVolumeCatalogue(contentsOf: ServedFixture.resources.appendingPathComponent("manifest.json"))
            catalogue = manifest.citableEntries
            engine = CitationMatchingEngine(manifestStore: manifest, searchService: SearchService(fts5Store: store, pipeline: pipeline),
                                            pageRangeStore: pages, downloadedVolumeIds: Set(ParityFixtures.volumes))
        }

        /// What the app's Paste Citation looks up for `text`, its fields edited as `edits` says.
        func paste(_ text: String, edits: (inout CitationLookupFields) -> Void = { _ in }) async throws -> [CitationMatch] {
            let parser = CitationParser()
            var fields = CitationLookupFields().refreshed(forPaste: text, mode: .paste, parser: parser)
            edits(&fields)
            return try await engine.match(input: fields.input(mode: .paste, pasteText: text, parser: parser))
        }

        /// What the app's Structured Entry looks up for `fields`.
        func structured(_ fields: CitationLookupFields) async throws -> [CitationMatch] {
            try await engine.match(input: fields.input(mode: .structured, pasteText: "", parser: CitationParser()))
        }

        /// Batch's rows for `block`, as the app's Look Up runs it.
        func batch(_ block: String) async -> [BatchCitationRow] {
            await KitRows.collect(CitationBlockSplitter.split(block), engine: engine)
        }
    }

    /// The draft's names for the kit's strategies (FRUS-API.openapi.yaml, `CitationMatch.matchStrategy`),
    /// with the values each carries.
    static func named(_ strategy: MatchStrategy) -> (name: String, explanation: String?, documents: Int?) {
        switch strategy {
        case .exactDocumentNumber: ("exactDocumentNumber", nil, nil)
        case .pageRange: ("pageRange", nil, nil)
        case .sharedPage(let documents): ("sharedPage", nil, documents)
        case .superimposedDocumentNumber: ("superimposedDocumentNumber", nil, nil)
        case .titleFragmentMatch: ("titleFragmentMatch", nil, nil)
        case .manifestOnly: ("manifestOnly", nil, nil)
        case .bestGuess(let explanation): ("bestGuess", explanation, nil)
        }
    }

    /// How the API's answer differs from the kit's, field by field; empty when it is the kit's.
    static func differences(_ api: [CitationLookupMatch], _ kit: [CitationMatch]) -> [String] {
        guard api.count == kit.count else {
            return ["\(api.count) through the API, \(kit.count) from the kit: \(api.map(\.volumeId)) and \(kit.map(\.volumeId))"]
        }
        return zip(api, kit).compactMap { api, kit in
            let strategy = named(kit.matchStrategy)
            let same = api.documentId == kit.documentId && api.volumeId == kit.volumeId && api.rank == kit.rank
                && api.matchStrategy == strategy.name && api.bestGuessExplanation == strategy.explanation
                && api.sharedPageDocuments == strategy.documents && api.confidenceLabel == kit.confidenceLabel
                && api.correctionNote == kit.correctionNote && api.requiresDownload == kit.requiresDownload
                && api.awaitingIndex == kit.awaitingIndex && api.volumeManifestEntry == kit.volumeManifestEntry
                && api.sharedPageTotal == kit.sharedPageTotal && api.volumeIsBestGuess == kit.volumeIsBestGuess
                && api.isBestGuess == kit.isBestGuess
            return same ? nil : "rank \(kit.rank): \(api) is not \(kit)"
        }
    }

    /// The outcome's name, count and reason, as the API writes them.
    static func named(_ outcome: BatchCitationOutcome) -> (name: String, count: Int?, reason: String?) {
        switch outcome {
        case .resolved: ("resolved", nil, nil)
        case .bestGuess: ("bestGuess", nil, nil)
        case .ambiguous(let count): ("ambiguous", count, nil)
        case .missing: ("missing", nil, nil)
        case .failed(let reason): ("failed", nil, reason)
        }
    }

    /// How a batch through the API differs from the kit's rows; empty when it is the kit's.
    static func differences(_ api: CitationBatch, _ kit: [BatchCitationRow]) -> [String] {
        var found: [String] = []
        let summary = BatchCitationOutcome.summary(of: kit.map(\.outcome), locale: Locale(identifier: "en_US"))
        if api.summary != summary { found.append("summary \(api.summary), not \(summary)") }
        guard api.items.count == kit.count else { return found + ["\(api.items.count) rows, not \(kit.count)"] }
        for (row, kit) in zip(api.items, kit) {
            let outcome = named(kit.outcome)
            if row.index != kit.entry.index || row.marker != kit.entry.marker || row.text != kit.entry.text
                || row.outcome != outcome.name || row.count != outcome.count || row.reason != outcome.reason
                || row.triageOrder != kit.outcome.triageOrder || row.loneCandidateLabel != kit.loneCandidateLabel {
                found.append("row \(kit.entry.index): \(row.index) \(row.marker ?? "-") \(row.outcome) is not \(kit.entry) \(kit.outcome)")
            }
            found += differences(row.matches, kit.matches).map { "row \(kit.entry.index), \($0)" }
        }
        return found
    }

    /// GETs `path` and decodes its JSON, or names the answer.
    static func get<T: Decodable>(_ type: T.Type, _ client: any TestClientProtocol, _ path: String) async throws -> T {
        let response = try await client.execute(uri: path, method: .get)
        guard response.status == .ok else { throw APIParityError("\(path): \(response.status.code) \(String(buffer: response.body))") }
        return try ServedFixture.decode(type, response)
    }

    /// The query string for `items`, as a browser's `URLSearchParams` writes it.
    static func query(_ items: [(String, String)]) -> String {
        items.map { "\($0.0)=\(APIParity.encode($0.1, .urlSearchParams))" }.joined(separator: "&")
    }

    /// Batch's answer for `block`.
    static func batch(_ client: any TestClientProtocol, _ block: String) async throws -> CitationBatch {
        let response = try await client.execute(
            uri: "/api/v1/citation-lookup/batch", method: .post,
            headers: [.contentType: "application/x-www-form-urlencoded;charset=UTF-8"],
            body: ByteBuffer(string: query([("text", block)])))
        guard response.status == .ok else { throw APIParityError("batch: \(response.status.code) \(String(buffer: response.body))") }
        return try ServedFixture.decode(CitationBatch.self, response)
    }

    /// The three styles' formatters, each as it writes a citation and as Copy Citation copies it.
    static var formats: [(name: String, formatter: any CitationFormatter)] {
        [("history.state.gov", HistoryAtStateCitationFormatter()),
         ("Chicago", ChicagoCitationFormatter()),
         ("Turabian", TurabianCitationFormatter())]
    }

    /// The kit's `ownCitationsAreNeverBestGuesses` through Batch: the app's own citation of every
    /// volume of the bundled catalogue, in each of the three styles, marked and as Copy Citation
    /// copies it, comes back first as that volume, never as a best guess, bar the two volumes the
    /// kit's test excuses by name, whose titles cannot tell them from a sibling's. The three indexed
    /// volumes answer with their document 1, found by its number; every other volume is one to
    /// download. One style's batch is held to the kit's runner row for row; every row of every batch
    /// is the kit's classification of its matches.
    @Test func theAppsOwnCitationOfEveryVolumeResolvesThroughBatch() async throws {
        let excused = ["frus1877app", "frus1894app2"]
        let (reports, checked) = try await ServedFixture.run { client, files in
            let kit = try Kit(files)
            #expect(kit.catalogue.count == 553)
            var reports: [String] = []
            var checked = false
            for format in Self.formats {
                for plain in [false, true] {
                    let name = format.name + (plain ? " (plain)" : "")
                    let citations = kit.catalogue.map { entry -> String in
                        let marked = format.formatter.format(
                            document: FRUSDocumentMetadata(documentId: "d1", documentNumber: "1", header: "Header", dateline: "Dateline"),
                            volume: FRUSVolumeMetadata(entry))
                        return plain ? CitationPlainText.plain(marked) : marked
                    }
                    // Within Batch's bound, and one citation a line: no title opens with a footnote's number.
                    var rows: [CitationBatch.Row] = []
                    for start in stride(from: 0, to: citations.count, by: CitationLookupRoutes.batchLimit) {
                        let block = citations[start..<min(start + CitationLookupRoutes.batchLimit, citations.count)].joined(separator: "\n")
                        let answer = try await Self.batch(client, block)
                        if !checked {
                            let differing = Self.differences(answer, await kit.batch(block))
                            #expect(differing.isEmpty, "\(name): \(differing.prefix(5))")
                        }
                        rows += answer.items
                    }
                    checked = true
                    #expect(rows.map(\.text) == citations.map { $0.trimmingCharacters(in: .whitespaces) }, "\(name): the splitter split a citation")
                    var misses: [String] = []
                    var guesses: [String] = []
                    for (entry, row) in zip(kit.catalogue, rows) {
                        guard let first = row.matches.first, first.volumeId == entry.volumeId else {
                            misses.append(entry.volumeId)
                            continue
                        }
                        let indexed = ParityFixtures.volumes.contains(entry.volumeId)
                        let expected = indexed
                            ? (first.documentId == "d1" && ["exactDocumentNumber", "superimposedDocumentNumber"].contains(first.matchStrategy))
                            : (first.matchStrategy == "manifestOnly" && first.requiresDownload && first.confidenceLabel == ConfidenceLabels.manifestOnly)
                        if first.isBestGuess || !expected { guesses.append("\(entry.volumeId): \(first.matchStrategy) \(first.confidenceLabel)") }
                    }
                    #expect(misses == excused, "\(name): \(misses)")
                    #expect(guesses.isEmpty, "\(name): \(guesses)")
                    reports.append("\(name) \(rows.count - misses.count)")
                }
            }
            return (reports, checked)
        }
        #expect(checked && reports.count == 6)
        print("check 7 through the API: the app's own citation of every volume, by Batch: \(reports.joined(separator: ", ")) of 553 first to their own volume")
    }

    /// Every fixture document through Paste Citation and Structured Entry, each answer the kit's own:
    /// its history.state.gov link, which names it exactly; its citation as Cite writes it in each
    /// style, read back from the server's citation endpoint, and the same with its document number
    /// edited in the Parsed Fields; and its subseries, volume, part and number in Structured Entry,
    /// and the first and last pages it may be printed on. A link opens the document it names, and a
    /// numbered document's own citation comes back first as that document, found by its number.
    @Test func everyFixtureDocumentResolvesThroughPasteAndStructuredEntry() async throws {
        let (lookups, strategies) = try await ServedFixture.run { client, files in
            let kit = try Kit(files)
            var lookups = 0
            var strategies: [String: Int] = [:]
            func check(_ path: String, _ expected: [CitationMatch]) async throws -> [CitationLookupMatch] {
                let answer = try await Self.get([CitationLookupMatch].self, client, path)
                let differing = Self.differences(answer, expected)
                #expect(differing.isEmpty, "\(path): \(differing)")
                lookups += 1
                for match in answer { strategies[match.matchStrategy, default: 0] += 1 }
                return answer
            }
            for volume in ParityFixtures.volumes {
                let entry = try #require(kit.catalogue.first { $0.volumeId == volume })
                let documents = try await kit.pipeline.documents(forVolume: volume)
                #expect(!documents.isEmpty, "\(volume)")
                for document in documents {
                    let id = document.documentId
                    // The link, which names the document exactly.
                    let link = FRUSCanonicalURL.string(volumeId: volume, documentId: id)
                    let linked = try await check("/api/v1/citation-lookup?\(Self.query([("text", link)]))", try await kit.paste(link))
                    #expect(linked.count == 1 && linked.first?.documentId == id && linked.first?.matchStrategy == "exactDocumentNumber"
                            && linked.first?.confidenceLabel == ConfidenceLabels.exactMatch, "\(link): \(linked)")

                    // The app's own citation in each style, as Cite writes it.
                    let numbered = document.documentNumber.map { !$0.isEmpty } ?? false
                    for style in ["historyAtState", "chicago", "turabian"] {
                        let cited = try await Self.get(DocumentCitation.self, client,
                                                       "/api/v1/volumes/\(volume)/documents/\(id)/citation?style=\(style)")
                        let text = cited.plainText
                        let answer = try await check("/api/v1/citation-lookup?\(Self.query([("text", text)]))", try await kit.paste(text))
                        if numbered, cited.documentNumber == document.documentNumber {
                            #expect(answer.first?.documentId == id && answer.first?.isBestGuess == false
                                    && ["exactDocumentNumber", "superimposedDocumentNumber"].contains(answer.first?.matchStrategy ?? ""),
                                    "\(volume)/\(id) in \(style): \(answer.first.map { "\($0.documentId) \($0.matchStrategy)" } ?? "nothing")")
                        }
                    }

                    // The Parsed Fields as a paste fills them, with the number edited, as the reader may:
                    // the text and the edit alone, as the browser app sends them.
                    let text = try await Self.get(DocumentCitation.self, client, "/api/v1/volumes/\(volume)/documents/\(id)/citation").plainText
                    let derived = try await Self.get(CitationLookupForm.self, client,
                                                     "/api/v1/citation-lookup/fields?\(Self.query([("text", text)]))")
                    let edited = String((Int(derived.documentNumber) ?? 0) + 1)
                    _ = try await check("/api/v1/citation-lookup?\(Self.query([("text", text), ("documentNumber", edited)]))",
                                        try await kit.paste(text) { $0.document = edited })

                    // Structured Entry: its volume's fields and its number, then the pages it may be printed on.
                    let fields = CitationLookupFields.derived(fromPaste: link, parser: CitationParser())
                    var structured = CitationLookupFields(subseries: entry.subseries, volume: fields.volume, part: fields.part,
                                                          document: document.documentNumber ?? "")
                    _ = try await check("/api/v1/citation-lookup?\(Self.query(Self.items(structured)))", try await kit.structured(structured))
                    if let pages = try await kit.pages.printedPages(forDocument: id, inVolume: volume) {
                        for page in Set([pages.lowerBound, pages.upperBound]).sorted() {
                            structured.document = ""
                            structured.page = String(page)
                            _ = try await check("/api/v1/citation-lookup?\(Self.query(Self.items(structured)))", try await kit.structured(structured))
                        }
                    }
                }
            }
            return (lookups, strategies)
        }
        // Every strategy these routes reach over the fixture volumes: a best guess needs a citation
        // the volume does not carry, which the batch test and the catalogue's fixtures give.
        for strategy in ["exactDocumentNumber", "pageRange", "sharedPage", "superimposedDocumentNumber", "manifestOnly"] {
            #expect(strategies[strategy, default: 0] > 0, "no \(strategy) answer: \(strategies)")
        }
        print("check 7 through the API: \(lookups) lookups of the fixture documents by Paste Citation and Structured Entry, each the kit's own; strategies \(strategies.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))")
    }

    /// Structured Entry's five fields, by the API's names, for a query string.
    static func items(_ fields: CitationLookupFields) -> [(String, String)] {
        [("subseries", fields.subseries), ("volumeNumber", fields.volume), ("partNumber", fields.part),
         ("documentNumber", fields.document), ("pageNumber", fields.page)]
    }

    /// Batch through the API is the kit's splitter, runner and summary: the kit's splitter fixtures
    /// (CitationBlockSplitterTests), a chapter's notes citing the fixture volumes by number, page and
    /// link, wrapped, bracketed and run together, and the kinds of row the table has, each row and
    /// the summary the kit's own.
    @Test func batchIsTheKitsSplitterAndRunner() async throws {
        let blocks = [
            // CitationBlockSplitterTests' blocks.
            "1. Memorandum of Conversation, FRUS 1969–1976, vol. I, doc. 12.\n2. Telegram 1234 from Saigon, FRUS 1964–1968, vol. IV, doc. 305.\n3. Editorial Note, FRUS 1958–1960, vol. III, doc. 88.",
            "1. Memorandum of Conversation, Washington, March 4, 1970,\nFRUS 1969–1976, vol. I,\ndoc. 12.\n2. Editorial Note, FRUS 1958–1960, vol. III, doc. 88.",
            "1969. Memorandum of Conversation, vol. I.",
            "Memorandum of Conversation, FRUS 1969–1976, vol. I, doc. 12.\nEditorial Note, FRUS 1958–1960, vol. III, doc. 88.",
            "1. First.\n\n2. Second.",
            "First citation.\n\n\nSecond citation.",
            "",
            "   \n\n  \t ",
            "FRUS 1969–1976, vol. I, doc. 12.",
            "1. A.\n\n\n2. B.\n\n3. C.",
            // A chapter's notes, citing the fixture volumes.
            """
            1. Letter From Khrushchev to Kennedy, FRUS, 1961–1963, vol. VI, doc. 1.
            2. Ibid., doc. 2.
            [3] Kennedy to Khrushchev, Foreign Relations of the United States, 1961–1963, Volume VI,
            Kennedy-Khrushchev Exchanges, Document 5.
            4) FRUS, 1961–1963, vol. VI, p. 3.
            5. https://history.state.gov/historicaldocuments/frus1969-76ve09p1/d87
            6. FRUS, 1969–1976, vol. E–9, pt. 1, p. 1.
            7. Foreign Relations, 1894, Nicaragua, doc. 3.
            8. FRUS, 1999–2000, vol. II, doc. 4.
            9. FRUS, 1961–1963, vol. VI, doc. 999.
            10. FRUS, 1961–1963, vol. V, doc. 84.
            11. Memorandum, no citation at all.
            12. FRUS, 1961–1963, vol. VI, pt. 2, doc. 1.
            """,
        ]
        let outcomes = try await ServedFixture.run { client, files in
            let kit = try Kit(files)
            var outcomes: Set<String> = []
            for block in blocks {
                let answer = try await Self.batch(client, block)
                let differing = Self.differences(answer, await kit.batch(block))
                #expect(differing.isEmpty, "\(block.prefix(40)): \(differing)")
                #expect(answer.items.map(\.index) == Array(stride(from: 1, through: answer.items.count, by: 1)))
                outcomes.formUnion(answer.items.map(\.outcome))
            }
            return outcomes
        }
        // Every kind of row the engine can give over a served index; `failed` needs the index to throw.
        #expect(outcomes == ["resolved", "bestGuess", "ambiguous", "missing"], "\(outcomes)")
    }

    /// The form through the API is the kit's: the Parsed Fields a paste fills, and Look Up's gate in
    /// each mode, as `CitationLookupFields` gives them, for pastes of every shape, fields a reader
    /// typed, and blocks of notes.
    @Test func theFormIsTheKitsForm() async throws {
        let pastes = [
            "", "   ", "FRUS, 1961–1963, vol. VI, doc. 1", "Memorandum of Conversation, Moscow, May 5, 1962, FRUS, 1961–1963, vol. V, doc. 84",
            "https://history.state.gov/historicaldocuments/frus1961-63v06/d1", "https://history.state.gov/historicaldocuments/frus1969-76ve09p1",
            "Foreign Relations of the United States, 1952–1954, Volume II, Part 2, Document 41.", "FRUS, 1969–1976, vol. E–9, pt. 1, p. 12",
            "Foreign Relations, 1919, vol. i, p. 258.", "pt. II", "Some prose with no citation in it.", "vol. XIV, doc. 84, https://history.state.gov/historicaldocuments/frus1961-63v05",
        ]
        let typed: [CitationLookupFields] = [
            CitationLookupFields(), CitationLookupFields(subseries: "1961-63"), CitationLookupFields(volume: " "),
            CitationLookupFields(volume: "VI"), CitationLookupFields(document: "abc"), CitationLookupFields(document: "+5"),
            CitationLookupFields(document: " 12 "), CitationLookupFields(page: "47"), CitationLookupFields(part: "II"),
            CitationLookupFields(subseries: "1969-76", volume: "E-9", part: "1", document: "87"),
            CitationLookupFields(document: "99999999999999999999"),
        ]
        let blocks = ["", " \n ", "1. ", "1. FRUS, 1961–1963, vol. VI, doc. 1", "Memorandum.\nTelegram."]
        try await ServedFixture.run { client, _ in
            let parser = CitationParser()
            for text in pastes {
                let derived = CitationLookupFields.derived(fromPaste: text, parser: parser)
                let form = try await Self.get(CitationLookupForm.self, client, "/api/v1/citation-lookup/fields?\(Self.query([("mode", "paste"), ("text", text)]))")
                #expect(form == CitationLookupForm(mode: "paste", subseries: derived.subseries, volumeNumber: derived.volume,
                                                   partNumber: derived.part, documentNumber: derived.document, pageNumber: derived.page,
                                                   actionable: derived.isActionable(mode: .paste, pasteText: text, parser: parser)), "\(text)")
                // Each field typed over the paste's, as the reader edits one.
                for fields in typed {
                    var edited = derived
                    edited.subseries = fields.subseries
                    edited.volume = fields.volume
                    edited.part = fields.part
                    edited.document = fields.document
                    edited.page = fields.page
                    let form = try await Self.get(CitationLookupForm.self, client,
                                                  "/api/v1/citation-lookup/fields?\(Self.query([("mode", "paste"), ("text", text)] + Self.items(fields)))")
                    #expect(form.actionable == edited.isActionable(mode: .paste, pasteText: text, parser: parser), "\(text) with \(fields)")
                }
            }
            for fields in typed {
                let form = try await Self.get(CitationLookupForm.self, client,
                                              "/api/v1/citation-lookup/fields?\(Self.query([("mode", "structured")] + Self.items(fields)))")
                #expect(form == CitationLookupForm(mode: "structured", subseries: fields.subseries, volumeNumber: fields.volume,
                                                   partNumber: fields.part, documentNumber: fields.document, pageNumber: fields.page,
                                                   actionable: fields.isActionable(mode: .structured, pasteText: "", parser: parser)), "\(fields)")
            }
            for block in blocks {
                let form = try await Self.get(CitationLookupForm.self, client, "/api/v1/citation-lookup/fields?\(Self.query([("mode", "batch"), ("text", block)]))")
                #expect(form.actionable == CitationLookupFields().isActionable(mode: .batch, pasteText: block, parser: parser), "\(block)")
            }
        }
    }

    /// The kit's tests over the bundled catalogue, through the API, with their own expectations:
    /// `titlesPrintedWholeComeFirst`, `seriesNameChoosesNoVolume`, `datedFootnoteResolvesToItsVolume`
    /// and the links of `linkNamesItsVolume`. Each answer is also the kit's own over the served index.
    @Test func theKitsCatalogueFixturesAnswerAsItsTestsExpect() async throws {
        try await ServedFixture.run { client, files in
            let kit = try Kit(files)
            func volumes(_ text: String) async throws -> [String] {
                let answer = try await Self.get([CitationLookupMatch].self, client, "/api/v1/citation-lookup?\(Self.query([("text", text)]))")
                let differing = Self.differences(answer, try await kit.paste(text))
                #expect(differing.isEmpty, "\(text): \(differing)")
                return answer.map(\.volumeId)
            }
            func first(_ text: String) async throws -> CitationLookupMatch? {
                try await Self.get([CitationLookupMatch].self, client, "/api/v1/citation-lookup?\(Self.query([("text", text)]))").first
            }
            // titlesPrintedWholeComeFirst.
            #expect(try await volumes("FRUS, 1952–1954, Iran, 1951–1954, doc. 5").first == "frus1951-54Iran")
            #expect(try await volumes("FRUS, 1952–1954, Iran, 1951–1954, vol. X, doc. 5") == ["frus1952-54v10"])
            #expect(try await volumes("Foreign Relations, 1919, vol. i, p. 258.").first == "frus1919v01")
            #expect(try await volumes(
                "For text of this report as received by the Commission to Negotiate Peace, see telegram No. 116 from the Chargé in Denmark, January 18, 1919, 11 p.m., Foreign Relations, 1919, Russia, p. 15."
            ).first == "frus1919Russia")
            #expect(try await volumes("See Foreign Relations, 1915, p. 146.").first == "frus1915")
            #expect(try await volumes("See Foreign Relations, 1894, pp. 3–18.").first == "frus1894")
            let fullName = try await volumes("Foreign Relations of the United States, 1894, doc. 5")
            #expect(fullName.first == "frus1894" && !fullName.contains("frus1893"), "\(fullName)")

            // seriesNameChoosesNoVolume. Volume VI of 1961–63 is indexed here, so it answers with its
            // document 5; the volume is the kit's test's.
            for (text, volume) in [("FRUS, 1961–1963, Volume VI, Document 5", "frus1961-63v06"),
                                   ("Foreign Relations of the United States, 1964–1968, Volume VII, Document 5", "frus1964-68v07"),
                                   ("Foreign Relations, 1964–1968, volume VII.", "frus1964-68v07")] {
                #expect(try await volumes(text) == [volume], "\(text)")
            }
            #expect(try await volumes("FRUS, 1961–1963, doc. 5").first == "frus1961-63v01")
            #expect(try await volumes("FRUS, 1952–1954, Iran, 1951–1954, doc. 5") == ["frus1951-54Iran", "frus1952-54v10"])
            let early = kit.catalogue.filter { $0.volumeId.hasPrefix("frus186") }
            #expect(early.count == 19)
            for entry in early {
                let text = "FRUS, \(entry.subseries), p. 100"
                let answer = try await first(text)
                #expect(answer?.volumeId.hasPrefix("frus\(entry.subseries)") == true && answer?.confidenceLabel == ConfidenceLabels.manifestOnly,
                        "\(text): \(answer?.volumeId ?? "nil")")
            }
            #expect(try await volumes("Foreign Relations of the United States, 1865, Part II, p. 20") == ["frus1865p2"])
            #expect(try await volumes("FRUS, 1865, p. 100") == ["frus1865p1", "frus1865p2", "frus1865p3"])
            #expect(try await volumes("FRUS, 1919, vol. i, doc. 5").first == "frus1919v01")
            #expect(try await volumes("FRUS, 1943, p. 5").first == "frus1943")
            #expect(try await volumes("FRUS, 1888, p. 5").first == "frus1888p1")
            #expect(try await volumes("Foreign Relations, Japan, 1931—1941, vol. i, p. 702.") == ["frus1931-41v01"])

            // datedFootnoteResolvesToItsVolume.
            let dated = "Memorandum of Conversation, Moscow, May 5, 1962, FRUS, 1961–1963, vol. V, doc. 84"
            #expect(try await volumes(dated) == ["frus1961-63v05"])
            #expect(try await first(dated)?.confidenceLabel == ConfidenceLabels.manifestOnly)

            // linkNamesItsVolume, over the bundled catalogue.
            let eVolume = try await first(FRUSCanonicalURL.string(volumeId: "frus1969-76ve05p1", documentId: "d10"))
            #expect(eVolume?.volumeId == "frus1969-76ve05p1" && eVolume?.requiresDownload == true
                    && eVolume?.confidenceLabel == ConfidenceLabels.manifestOnly)
            #expect(try await volumes(FRUSCanonicalURL.string(volumeId: "frus1919Parisv01", documentId: "d5")) == ["frus1919Parisv01"])
            #expect(try await volumes("https://history.state.gov/historicaldocuments/frus1919parisv01/d5") == ["frus1919Parisv01"])
            #expect(try await volumes(FRUSCanonicalURL.string(volumeId: "frus1969-76ve99", documentId: "d10")).isEmpty)
        }
    }

    /// The strategies the API names are the draft's, every one of them: its `CitationMatch` schema
    /// lists them in `matchStrategy`'s enum.
    @Test func theStrategiesAreTheDrafts() throws {
        let draft = try String(contentsOf: Repository.layout.upstream.appendingPathComponent("FRUS-API.openapi.yaml"), encoding: .utf8)
        let schema = try #require(draft.range(of: "\n    CitationMatch:\n"))
        let property = try #require(draft.range(of: "        matchStrategy:\n", range: schema.upperBound..<draft.endIndex))
        let list = try #require(draft.range(of: "          enum:\n", range: property.upperBound..<draft.endIndex))
        var names: [String] = []
        for line in draft[list.upperBound...].split(separator: "\n") {
            guard line.hasPrefix("            - ") else { break }
            names.append(String(line.dropFirst("            - ".count)))
        }
        let all: [MatchStrategy] = [.exactDocumentNumber, .pageRange, .sharedPage(documents: 2), .superimposedDocumentNumber,
                                    .titleFragmentMatch, .manifestOnly, .bestGuess(explanation: "")]
        #expect(names == all.map { Self.named($0).name })
        #expect(all.map { CitationLookupMatch(CitationMatch(documentId: "", volumeId: "", rank: 1, matchStrategy: $0, confidenceLabel: "")).matchStrategy }
                == names)
    }
}

/// The rows the kit's runner hands back, kept on the main actor, where it hands each one.
@MainActor
private final class KitRows {
    var rows: [BatchCitationRow] = []

    nonisolated init() {}

    nonisolated static func collect(_ entries: [CitationBlockSplitter.Entry], engine: CitationMatchingEngine) async -> [BatchCitationRow] {
        let kept = KitRows()
        await BatchCitationRunner.run(entries: entries, engine: engine, parser: CitationParser()) { kept.rows.append($0) }
        return await kept.rows
    }
}
