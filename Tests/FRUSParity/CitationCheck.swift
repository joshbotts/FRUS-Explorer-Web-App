// Check 7 through the API (docs/SPEC.md, Verification): Citation Lookup as a server answers it, every answer held,
// field by field, to the kit's own for the same citation, from an engine built over the same index and catalogue with
// the kit's calls alone, as the app's Citation Lookup makes them (`CitationLookupFields`, `CitationMatchingEngine`,
// `CitationBlockSplitter`, `BatchCitationRunner`). PLAN's S19a holds it over the fixture index in process
// (`CitationLookupAPIParityTests`, which compares through `differences` here); `frus-parity check-citations` holds a
// running server to it over a whole corpus (PLAN's S25b): the app's own citation of every catalogue volume through
// Batch, in each style, marked and as Copy Citation copies it, row for row; and each volume's first, middle and last
// documents by every form S19a asks: the link that names it, its citation in each style as the server's Cite writes it,
// that citation with its number edited in the Parsed Fields, and Structured Entry by its number and by the first and
// last pages it may be printed on.

import FRUSCoreKit
import FRUSLightAPI
import FTS5Store
import Foundation

public enum CitationCheck {
    /// The kit's engine over an index, the published catalogue, and the volumes the index holds as the downloaded
    /// ones, as the server's `ServedIndex` builds its own, opened read-only and immutable.
    public struct Kit: Sendable {
        public let engine: CitationMatchingEngine
        public let pipeline: IndexingPipeline
        public let pages: PageRangeStore
        public let catalogue: [VolumeManifestEntry]
        /// The volumes the index holds, in the catalogue's order.
        public let volumes: [String]

        public init(index: URL, manifest: URL, volumesDirectory: URL) throws {
            // The kit opens it immutable, which would miss a log's pages: refused, as the summary refuses them.
            try IndexSummarizerFile.refuseUnfinished(index)
            let store = try FTS5Store(readingDatabaseAt: index)
            pipeline = try IndexingPipeline(readingIndexAt: index, fts5Store: store, resources: .none, volumesDirectory: volumesDirectory)
            pages = try PageRangeStore(readingDatabaseAt: index)
            let catalogue = try FixedVolumeCatalogue(contentsOf: manifest)
            self.catalogue = catalogue.citableEntries
            let held = Set(try ParityDatabase.immutable(index).strings("SELECT DISTINCT volume_id FROM document_cache"))
            volumes = catalogue.citableEntries.map(\.volumeId).filter(held.contains)
            engine = CitationMatchingEngine(manifestStore: catalogue, searchService: SearchService(fts5Store: store, pipeline: pipeline),
                                            pageRangeStore: pages, downloadedVolumeIds: held)
        }

        /// What the app's Paste Citation looks up for `text`, its fields edited as `edits` says.
        public func paste(_ text: String, edits: (inout CitationLookupFields) -> Void = { _ in }) async throws -> [CitationMatch] {
            let parser = CitationParser()
            var fields = CitationLookupFields().refreshed(forPaste: text, mode: .paste, parser: parser)
            edits(&fields)
            return try await engine.match(input: fields.input(mode: .paste, pasteText: text, parser: parser))
        }

        /// What the app's Structured Entry looks up for `fields`.
        public func structured(_ fields: CitationLookupFields) async throws -> [CitationMatch] {
            try await engine.match(input: fields.input(mode: .structured, pasteText: "", parser: CitationParser()))
        }

        /// Batch's rows for `block`, as the app's Look Up runs it.
        public func batch(_ block: String) async -> [BatchCitationRow] {
            await RowCollector.collect(CitationBlockSplitter.split(block), engine: engine)
        }
    }

    // MARK: - Comparing an answer with the kit's

    /// The draft's names for the kit's strategies (FRUS-API.openapi.yaml, `CitationMatch.matchStrategy`), with the
    /// values each carries.
    public static func named(_ strategy: MatchStrategy) -> (name: String, explanation: String?, documents: Int?) {
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
    public static func differences(_ api: [CitationLookupMatch], _ kit: [CitationMatch]) -> [String] {
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
    public static func named(_ outcome: BatchCitationOutcome) -> (name: String, count: Int?, reason: String?) {
        switch outcome {
        case .resolved: ("resolved", nil, nil)
        case .bestGuess: ("bestGuess", nil, nil)
        case .ambiguous(let count): ("ambiguous", count, nil)
        case .missing: ("missing", nil, nil)
        case .failed(let reason): ("failed", nil, reason)
        }
    }

    /// How a batch through the API differs from the kit's rows; empty when it is the kit's.
    public static func differences(_ api: CitationBatch, _ kit: [BatchCitationRow]) -> [String] {
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

    /// The three styles' formatters, each as it writes a citation and as Copy Citation copies it.
    public static var formats: [(name: String, formatter: any CitationFormatter)] {
        [("history.state.gov", HistoryAtStateCitationFormatter()),
         ("Chicago", ChicagoCitationFormatter()),
         ("Turabian", TurabianCitationFormatter())]
    }

    /// The app's own citation of each catalogue volume, as the kit's `ownCitationsAreNeverBestGuesses` writes it:
    /// its document 1, in a style, marked or as Copy Citation copies it.
    public static func ownCitations(of catalogue: [VolumeManifestEntry], formatter: any CitationFormatter, plain: Bool) -> [String] {
        catalogue.map { entry in
            let marked = formatter.format(
                document: FRUSDocumentMetadata(documentId: "d1", documentNumber: "1", header: "Header", dateline: "Dateline"),
                volume: FRUSVolumeMetadata(entry))
            return plain ? CitationPlainText.plain(marked) : marked
        }
    }

    /// The query string for `items`, as a browser's `URLSearchParams` writes it.
    public static func query(_ items: [(String, String)]) -> String {
        items.map { "\($0.0)=\(APIParity.encode($0.1, .urlSearchParams))" }.joined(separator: "&")
    }

    /// Structured Entry's five fields, by the API's names, for a query string.
    public static func items(_ fields: CitationLookupFields) -> [(String, String)] {
        [("subseries", fields.subseries), ("volumeNumber", fields.volume), ("partNumber", fields.part),
         ("documentNumber", fields.document), ("pageNumber", fields.page)]
    }

    // MARK: - The full corpus through a server

    /// A request to the server: a path with its query string, and a form body for a POST.
    public typealias Fetch = @Sendable (_ path: String, _ formBody: String?) async throws -> (status: Int, body: Data)

    /// What the check found.
    public struct Result: Sendable, Codable, Equatable {
        /// Lookups held to the kit's: each Paste Citation or Structured Entry answer, and each Batch row.
        public var lookups = 0
        public var batchRows = 0
        public var documents = 0
        public var volumes = 0
        /// The strategies of every answer's matches, by the draft's names.
        public var strategies: [String: Int] = [:]
        /// For each form of the app's own citation, how many volumes come back first as themselves, and those that do
        /// not, and those that come back first as themselves by a best guess: the kit's own answers, reported.
        public var ownCitationsFirst: [String: Int] = [:]
        public var ownCitationsNotFirst: [String: [String]] = [:]
        public var ownCitationsGuessed: [String: [String]] = [:]
        /// The Batch chunks of own citations the kit's splitter did not split one row a citation, which the server's
        /// rows followed: the kit's own answer, reported, those volumes left out of the tallies above.
        public var ownCitationBatchesSplit: [String] = []
        /// The numbered documents whose own citation, in each style, does not come back first as that document found
        /// by its number: the kit's answers, reported.
        public var citationsNotFindingTheirDocument: [String] = []
        /// Each answer that is not the kit's, or that the server refused.
        public var differences: [String] = []

        public init() {}

        public var passes: Bool { differences.isEmpty && lookups > 0 }

        public func summary() -> String {
            let strategies = strategies.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            let own = ownCitationsFirst.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            guard passes else { return "check 7 fails: \(differences.count) answers differ from the kit's, of \(lookups)" }
            return "check 7 passes through the API: \(lookups) lookups, every answer the kit's: the app's own citation of every volume by Batch, "
                + "\(batchRows) rows, first to their own volume \(own); \(documents) documents of \(volumes) volumes by Paste Citation and "
                + "Structured Entry; strategies \(strategies)"
        }
    }

    /// Holds a server's Citation Lookup to `kit` over the same index: the app's own citation of every catalogue volume
    /// through Batch, in each style, marked and plain, row for row; and up to `perVolume` documents of each volume the
    /// index holds (its first, middle and last), by every form S19a asks. `progress` hears each volume done.
    public static func run(kit: Kit, perVolume: Int = 3, progress: (Int, Result) -> Void = { _, _ in },
                           fetch: Fetch) async -> Result {
        var result = Result()
        func ask<T: Decodable>(_ type: T.Type, _ path: String, form: String? = nil) async throws -> T {
            let (status, body) = try await fetch(path, form)
            guard status == 200 else { throw CitationCheckError("\(path.prefix(200)): \(status) \(String(decoding: body.prefix(300), as: UTF8.self))") }
            return try JSONDecoder().decode(type, from: body)
        }
        func tally(_ matches: [CitationLookupMatch]) {
            for match in matches { result.strategies[match.matchStrategy, default: 0] += 1 }
        }

        // The app's own citation of every catalogue volume, through Batch, within its bound.
        for format in formats {
            for plain in [false, true] {
                let name = format.name + (plain ? " (plain)" : "")
                let citations = ownCitations(of: kit.catalogue, formatter: format.formatter, plain: plain)
                var first = 0
                for start in stride(from: 0, to: citations.count, by: 500) {
                    let end = min(start + 500, citations.count)
                    let block = citations[start..<end].joined(separator: "\n")
                    do {
                        let answer = try await ask(CitationBatch.self, "/api/v1/citation-lookup/batch", form: query([("text", block)]))
                        let found = differences(answer, await kit.batch(block))
                        result.differences += found.map { "\(name), from volume \(start + 1): \($0)" }
                        result.batchRows += answer.items.count
                        result.lookups += answer.items.count
                        for row in answer.items { tally(row.matches) }
                        // Each row is its volume's only when the splitter kept one citation a line. Where it did not and
                        // the server's rows are the kit's, that is the kit's own answer, reported, and the chunk's volumes
                        // go untallied; a server whose rows are not the kit's has differed above.
                        guard answer.items.count == end - start else {
                            if found.isEmpty {
                                result.ownCitationBatchesSplit.append("\(name), from volume \(start + 1): \(answer.items.count) rows for \(end - start) citations")
                            }
                            continue
                        }
                        for (entry, row) in zip(kit.catalogue[start..<end], answer.items) {
                            guard let match = row.matches.first, match.volumeId == entry.volumeId else {
                                result.ownCitationsNotFirst[name, default: []].append(entry.volumeId)
                                continue
                            }
                            first += 1
                            if match.isBestGuess { result.ownCitationsGuessed[name, default: []].append(entry.volumeId) }
                        }
                    } catch {
                        result.differences.append("\(name), from volume \(start + 1): \(error)")
                    }
                }
                result.ownCitationsFirst[name] = first
            }
        }

        // Each volume's first, middle and last documents.
        for (offset, volume) in kit.volumes.enumerated() {
            result.volumes += 1
            guard let entry = kit.catalogue.first(where: { $0.volumeId == volume }),
                  let documents = try? await kit.pipeline.documents(forVolume: volume), !documents.isEmpty else {
                result.differences.append("\(volume): the kit lists no documents")
                continue
            }
            let picked = Set([0, documents.count / 2, documents.count - 1].prefix(max(0, perVolume))).sorted().map { documents[$0] }
            for document in picked {
                result.documents += 1
                let id = document.documentId
                func check(_ path: String, _ expected: @autoclosure () async throws -> [CitationMatch]) async -> [CitationLookupMatch]? {
                    result.lookups += 1
                    do {
                        let answer = try await ask([CitationLookupMatch].self, path)
                        result.differences += differences(answer, try await expected()).map { "\(volume)/\(id) \(path.prefix(160)): \($0)" }
                        tally(answer)
                        return answer
                    } catch {
                        result.differences.append("\(volume)/\(id) \(path.prefix(160)): \(error)")
                        return nil
                    }
                }
                // The link, which names the document exactly.
                let link = FRUSCanonicalURL.string(volumeId: volume, documentId: id)
                _ = await check("/api/v1/citation-lookup?\(query([("text", link)]))", try await kit.paste(link))
                // Its citation in each style, as the server's Cite writes it.
                let numbered = document.documentNumber.map { !$0.isEmpty } ?? false
                for style in ["historyAtState", "chicago", "turabian"] {
                    guard let cited = try? await ask(DocumentCitation.self, "/api/v1/volumes/\(volume)/documents/\(id)/citation?style=\(style)") else {
                        result.differences.append("\(volume)/\(id): no \(style) citation")
                        continue
                    }
                    let text = cited.plainText
                    let answer = await check("/api/v1/citation-lookup?\(query([("text", text)]))", try await kit.paste(text))
                    if numbered, cited.documentNumber == document.documentNumber,
                       !(answer?.first?.documentId == id && answer?.first?.isBestGuess == false
                         && ["exactDocumentNumber", "superimposedDocumentNumber"].contains(answer?.first?.matchStrategy ?? "")) {
                        result.citationsNotFindingTheirDocument.append("\(volume)/\(id) in \(style): \(answer?.first.map { "\($0.volumeId)/\($0.documentId) \($0.matchStrategy)" } ?? "nothing")")
                    }
                }
                // The Parsed Fields as a paste fills them, the server's held to the kit's form, then with the number
                // edited, as the reader may, from the kit's fields.
                if let text = try? await ask(DocumentCitation.self, "/api/v1/volumes/\(volume)/documents/\(id)/citation").plainText,
                   let derived = try? await ask(CitationLookupForm.self, "/api/v1/citation-lookup/fields?\(query([("text", text)]))") {
                    result.lookups += 1
                    let parser = CitationParser()
                    let fields = CitationLookupFields().refreshed(forPaste: text, mode: .paste, parser: parser)
                    let form = [derived.subseries, derived.volumeNumber, derived.partNumber, derived.documentNumber, derived.pageNumber]
                    let kitForm = [fields.subseries, fields.volume, fields.part, fields.document, fields.page]
                    let actionable = fields.isActionable(mode: .paste, pasteText: text, parser: parser)
                    if form != kitForm || derived.actionable != actionable || derived.mode != "paste" {
                        result.differences.append("\(volume)/\(id): the Parsed Fields are \(form), \(derived.actionable) through the API, \(kitForm), \(actionable) from the kit")
                    }
                    let edited = String((Int(fields.document) ?? 0) + 1)
                    _ = await check("/api/v1/citation-lookup?\(query([("text", text), ("documentNumber", edited)]))",
                                    try await kit.paste(text) { $0.document = edited })
                } else {
                    result.differences.append("\(volume)/\(id): no citation or fields to edit")
                }
                // Structured Entry: its volume's fields and its number, then the pages it may be printed on.
                let fields = CitationLookupFields.derived(fromPaste: link, parser: CitationParser())
                var structured = CitationLookupFields(subseries: entry.subseries, volume: fields.volume, part: fields.part,
                                                      document: document.documentNumber ?? "")
                _ = await check("/api/v1/citation-lookup?\(query(items(structured)))", try await kit.structured(structured))
                if let pages = try? await kit.pages.printedPages(forDocument: id, inVolume: volume) {
                    for page in Set([pages.lowerBound, pages.upperBound]).sorted() {
                        structured.document = ""
                        structured.page = String(page)
                        _ = await check("/api/v1/citation-lookup?\(query(items(structured)))", try await kit.structured(structured))
                    }
                }
            }
            progress(offset + 1, result)
        }
        return result
    }
}

/// Why a request of the check could not be read.
public struct CitationCheckError: Error, CustomStringConvertible, Sendable {
    public let description: String
    public init(_ description: String) { self.description = description }
}

/// The rows the kit's runner hands back, kept on the main actor, where it hands each one.
@MainActor
private final class RowCollector {
    var rows: [BatchCitationRow] = []

    nonisolated init() {}

    nonisolated static func collect(_ entries: [CitationBlockSplitter.Entry], engine: CitationMatchingEngine) async -> [BatchCitationRow] {
        let kept = RowCollector()
        await BatchCitationRunner.run(entries: entries, engine: engine, parser: CitationParser()) { kept.rows.append($0) }
        return await kept.rows
    }
}
