// /api/v1/citation-lookup, /api/v1/citation-lookup/fields and POST /api/v1/citation-lookup/batch
// (PLAN's S19a): Citation Lookup's Paste Citation, Structured Entry and
// Batch, as the app's Citation Lookup window runs them, through the kit's form
// (`CitationLookupFields`), its matcher (`CitationMatchingEngine`), its splitter
// (`CitationBlockSplitter`) and its batch runner and outcomes (`BatchCitationRunner`,
// `BatchCitationOutcome`). Nothing here reads a citation or ranks a match: the kit does both.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// A candidate the kit's matcher gives, by the draft's `CitationMatch` (FRUS-API.openapi.yaml), with
/// the three values the draft's schema leaves out: `isBestGuess`, the kit's own reading of whether
/// the engine labels the match a best guess, and the two values a strategy carries,
/// `bestGuessExplanation` and `sharedPageDocuments`.
public struct CitationLookupMatch: Codable, Equatable, Sendable {
    public var documentId: String
    public var volumeId: String
    public var rank: Int
    /// The strategy by the draft's names: `exactDocumentNumber`, `pageRange`, `sharedPage`,
    /// `superimposedDocumentNumber`, `titleFragmentMatch`, `manifestOnly` or `bestGuess`.
    public var matchStrategy: String
    /// The kit's label (`ConfidenceLabels`), which the app shows above the result.
    public var confidenceLabel: String
    public var correctionNote: String?
    public var requiresDownload: Bool
    public var awaitingIndex: Bool
    public var volumeManifestEntry: VolumeManifestEntry?
    public var sharedPageTotal: Int?
    public var volumeIsBestGuess: Bool
    /// `CitationMatch.isBestGuess`.
    public var isBestGuess: Bool
    /// What `MatchStrategy.bestGuess(explanation:)` carries, for a `bestGuess` match alone.
    public var bestGuessExplanation: String?
    /// What `MatchStrategy.sharedPage(documents:)` carries, for a `sharedPage` match alone.
    public var sharedPageDocuments: Int?

    init(_ match: CitationMatch) {
        documentId = match.documentId
        volumeId = match.volumeId
        rank = match.rank
        switch match.matchStrategy {
        case .exactDocumentNumber: matchStrategy = "exactDocumentNumber"
        case .pageRange: matchStrategy = "pageRange"
        case .sharedPage(let documents):
            matchStrategy = "sharedPage"
            sharedPageDocuments = documents
        case .superimposedDocumentNumber: matchStrategy = "superimposedDocumentNumber"
        case .titleFragmentMatch: matchStrategy = "titleFragmentMatch"
        case .manifestOnly: matchStrategy = "manifestOnly"
        case .bestGuess(let explanation):
            matchStrategy = "bestGuess"
            bestGuessExplanation = explanation
        }
        confidenceLabel = match.confidenceLabel
        correctionNote = match.correctionNote
        requiresDownload = match.requiresDownload
        awaitingIndex = match.awaitingIndex
        volumeManifestEntry = match.volumeManifestEntry
        sharedPageTotal = match.sharedPageTotal
        volumeIsBestGuess = match.volumeIsBestGuess
        isBestGuess = match.isBestGuess
    }

    /// Each field, one with no value as null.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(documentId, forKey: .documentId)
        try container.encode(volumeId, forKey: .volumeId)
        try container.encode(rank, forKey: .rank)
        try container.encode(matchStrategy, forKey: .matchStrategy)
        try container.encode(confidenceLabel, forKey: .confidenceLabel)
        try container.encode(correctionNote, forKey: .correctionNote)
        try container.encode(requiresDownload, forKey: .requiresDownload)
        try container.encode(awaitingIndex, forKey: .awaitingIndex)
        try container.encode(volumeManifestEntry, forKey: .volumeManifestEntry)
        try container.encode(sharedPageTotal, forKey: .sharedPageTotal)
        try container.encode(volumeIsBestGuess, forKey: .volumeIsBestGuess)
        try container.encode(isBestGuess, forKey: .isBestGuess)
        try container.encode(bestGuessExplanation, forKey: .bestGuessExplanation)
        try container.encode(sharedPageDocuments, forKey: .sharedPageDocuments)
    }
}

/// Citation Lookup's form as the app's holds it (`CitationLookupFields`): the five Parsed Fields it
/// shows, by the draft's names for them, and whether Look Up has anything to go on.
public struct CitationLookupForm: Codable, Equatable, Sendable, ResponseEncodable {
    /// `paste`, `structured` or `batch`.
    public var mode: String
    public var subseries: String
    public var volumeNumber: String
    public var partNumber: String
    public var documentNumber: String
    public var pageNumber: String
    /// `CitationLookupFields.isActionable(mode:pasteText:parser:)`: Look Up's gate.
    public var actionable: Bool
}

/// Batch's triage table: one row per citation the kit's splitter finds in the block, each looked up
/// by the kit's runner, with the table's summary.
public struct CitationBatch: Codable, Equatable, Sendable, ResponseEncodable {
    /// `BatchCitationOutcome.summary(of:)` over the rows, in US English: "12 citations · 7 resolved
    /// · 2 ambiguous · 2 best guesses · 1 unresolved".
    public var summary: String
    /// The rows in the order of the paste.
    public var items: [Row]

    /// A row: the citation as the splitter lifted it out (`CitationBlockSplitter.Entry`), what it
    /// resolved to (`BatchCitationOutcome`) and the matcher's candidates.
    public struct Row: Codable, Equatable, Sendable {
        /// Its place in the paste, from 1.
        public var index: Int
        /// The footnote's number as printed, or null for a block with none.
        public var marker: String?
        public var text: String
        /// `resolved`, `bestGuess`, `ambiguous`, `missing` or `failed`.
        public var outcome: String
        /// How many documents an `ambiguous` row may be, or null.
        public var count: Int?
        /// Why a `failed` row could not be looked up, or null.
        public var reason: String?
        /// `BatchCitationOutcome.triageOrder`, by which Needs work first sorts the rows.
        public var triageOrder: Int
        /// `BatchCitationRow.loneCandidateLabel`: the label a row shows in place of a count.
        public var loneCandidateLabel: String?
        public var matches: [CitationLookupMatch]

        init(_ row: BatchCitationRow) {
            index = row.entry.index
            marker = row.entry.marker
            text = row.entry.text
            switch row.outcome {
            case .resolved: outcome = "resolved"
            case .bestGuess: outcome = "bestGuess"
            case .ambiguous(let count):
                outcome = "ambiguous"
                self.count = count
            case .missing: outcome = "missing"
            case .failed(let reason):
                outcome = "failed"
                self.reason = reason
            }
            triageOrder = row.outcome.triageOrder
            loneCandidateLabel = row.loneCandidateLabel
            matches = row.matches.map(CitationLookupMatch.init)
        }

        /// Each field, one with no value as null.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(index, forKey: .index)
            try container.encode(marker, forKey: .marker)
            try container.encode(text, forKey: .text)
            try container.encode(outcome, forKey: .outcome)
            try container.encode(count, forKey: .count)
            try container.encode(reason, forKey: .reason)
            try container.encode(triageOrder, forKey: .triageOrder)
            try container.encode(loneCandidateLabel, forKey: .loneCandidateLabel)
            try container.encode(matches, forKey: .matches)
        }
    }

    init(_ rows: [BatchCitationRow]) {
        summary = BatchCitationOutcome.summary(of: rows.map(\.outcome), locale: SearchItem.locale)
        items = rows.map(Row.init)
    }
}

/// What a request to Paste Citation, Structured Entry or Batch asks of the kit's form: its mode, the
/// paste's text, and the Parsed Fields as the app's form would hold them.
struct CitationLookupRequest {
    let mode: CitationLookupMode
    let text: String
    let fields: CitationLookupFields

    /// The modes by the names the API takes.
    static let modes: [(name: String, mode: CitationLookupMode)] = [
        ("paste", .paste), ("structured", .structured), ("batch", .batch),
    ]

    /// The five Parsed Fields by the draft's names, each with its place in the kit's form.
    static let fields: [(name: String, path: WritableKeyPath<CitationLookupFields, String> & Sendable)] = [
        ("subseries", \.subseries), ("volumeNumber", \.volume), ("partNumber", \.part),
        ("documentNumber", \.document), ("pageNumber", \.page),
    ]

    /// The draft's parameters the web edition takes from a paste's text instead, each with why.
    static let unsupported: [String: String] = [
        "volumeId": "send the citation's history.state.gov link as text, from which the kit's parser takes the volume and document it names, as the app's Paste Citation does",
        "documentId": "send the citation's history.state.gov link as text, from which the kit's parser takes the volume and document it names, as the app's Paste Citation does",
        "titleFragment": "send the citation as text, from which the kit's parser takes its title fragment, as the app's Paste Citation does",
    ]

    /// The request `form` makes, in one of `allowed`. The mode is `paste` when `text` is given and
    /// `structured` otherwise, unless `mode` names one. In Paste Citation every field is what the
    /// kit derives from the text, as a paste fills the app's form, and a field the request gives
    /// stands for the reader's edit of it; Structured Entry and Batch read no text into the fields.
    init(_ form: FormQuery, allowed: [CitationLookupMode]) throws(APIProblem) {
        if let pair = form.pairs.first(where: { Self.unsupported[$0.name] != nil }) {
            throw APIProblem(.badRequest, code: "UNSUPPORTED_PARAMETER",
                             detail: "\(pair.name) is the draft's, and not taken here: \(Self.unsupported[pair.name] ?? "")")
        }
        try form.refuseUnknown(Set(["mode", "text"] + Self.fields.map(\.name)))
        let text = try form.single("text")
        let names = Self.modes.filter { allowed.contains($0.mode) }
        var mode: CitationLookupMode = text == nil ? .structured : .paste
        if let name = try form.single("mode") {
            guard let named = names.first(where: { $0.name == name }) else {
                throw APIProblem.invalidParameter("mode", "must be one of \(names.map(\.name).joined(separator: ", ")), not \(name)")
            }
            mode = named.mode
        }
        guard allowed.contains(mode) else {
            throw APIProblem.invalidParameter("mode", "this route takes \(names.map(\.name).joined(separator: " or ")); give mode")
        }
        if mode == .structured, text != nil {
            throw APIProblem.invalidParameter("text", "Structured Entry reads only the five fields; send mode=paste to look the text up")
        }
        var fields = mode == .paste
            ? CitationLookupFields.derived(fromPaste: text ?? "", parser: CitationLookupRoutes.parser)
            : CitationLookupFields()
        for field in Self.fields {
            if let value = try form.single(field.name) { fields[keyPath: field.path] = value }
        }
        self.mode = mode
        self.text = text ?? ""
        self.fields = fields
    }

    /// The matcher's input, as the app's Look Up hands it over.
    var input: CitationInput { fields.input(mode: mode, pasteText: text, parser: CitationLookupRoutes.parser) }

    /// The form's answer: its fields, and whether Look Up has anything to go on.
    var form: CitationLookupForm {
        CitationLookupForm(
            mode: Self.modes.first { $0.mode == mode }?.name ?? "paste",
            subseries: fields.subseries, volumeNumber: fields.volume, partNumber: fields.part,
            documentNumber: fields.document, pageNumber: fields.page,
            actionable: fields.isActionable(mode: mode, pasteText: text, parser: CitationLookupRoutes.parser))
    }
}

enum CitationLookupRoutes {
    /// The kit's citation parser, which keeps no state.
    static let parser = CitationParser()

    /// The most citations one Batch request looks up. The app's runner looks up a chapter's
    /// footnotes one after another on the index every search shares, and has no bound of its own;
    /// a block of thousands of short lines would hold the index for minutes.
    static let batchLimit = 500

    /// The largest form body a request may send, in bytes: Batch's block of notes, or a paste.
    static let bodyLimit = 256 * 1_024

    /// A request's fields: a POST's form body, or the query when its body is empty, as
    /// `/search/inspect` reads them. The browser app posts every request, so neither a long paste nor
    /// Batch's block outruns a proxy's limit on an address, 8 KiB in nginx's default.
    static func form(of request: Request) async throws -> FormQuery {
        let body = try await request.body.collect(upTo: bodyLimit)
        return try FormQuery(body.readableBytes > 0 ? String(buffer: body) : request.uri.query)
    }

    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        // With no index served, the matcher answers from the published catalogue alone, as the
        // app's does with nothing downloaded: every volume it names is one to download.
        let catalogueOnly = CitationMatchingEngine(manifestStore: FixedVolumeCatalogue(entries: resources.manifest),
                                                   searchService: nil, pageRangeStore: nil, downloadedVolumeIds: [])
        let engine: @Sendable () async throws -> CitationMatchingEngine = {
            try await provider.servedIfReady()?.citations ?? catalogueOnly
        }

        // Each answers GET, with the fields in the query, and POST, with them in a form body.
        let lookup: @Sendable (Request, APIRequestContext) async throws -> [CitationLookupMatch] = { request, context in
            let lookup = try CitationLookupRequest(try await form(of: request), allowed: [.paste, .structured])
            let engine = try await engine()
            let input = lookup.input
            return try await context.whileClientConnected {
                try await engine.match(input: input).map(CitationLookupMatch.init)
            }
        }
        router.get("/api/v1/citation-lookup", use: lookup)
        router.post("/api/v1/citation-lookup", use: lookup)

        let fields: @Sendable (Request, APIRequestContext) async throws -> CitationLookupForm = { request, _ in
            try CitationLookupRequest(try await form(of: request), allowed: [.paste, .structured, .batch]).form
        }
        router.get("/api/v1/citation-lookup/fields", use: fields)
        router.post("/api/v1/citation-lookup/fields", use: fields)

        router.post("/api/v1/citation-lookup/batch") { request, context -> CitationBatch in
            let query = try await form(of: request)
            try query.refuseUnknown(["text"])
            let entries = CitationBlockSplitter.split(try query.single("text") ?? "")
            guard entries.count <= batchLimit else {
                throw APIProblem(.badRequest, code: "TOO_MANY_CITATIONS",
                                 detail: "Batch looks up at most \(batchLimit) citations at a time, and this text holds \(entries.count). Send it in parts.")
            }
            let engine = try await engine()
            return try await context.whileClientConnected {
                CitationBatch(try await BatchRows.collect(entries, engine: engine))
            }
        }
    }
}

/// The rows the kit's runner hands back, kept on the main actor, where it hands each one as it
/// completes, as the app's table fills.
@MainActor
final class BatchRows {
    var rows: [BatchCitationRow] = []

    nonisolated init() {}

    /// How many entries the runner is given at a time. It looks each up in turn and turns a lookup
    /// stopped by its task into a failed row, so a block a client abandons would otherwise run to its
    /// end, on the matcher every search shares; between two slices the work stops.
    nonisolated static let slice = 25

    /// Every row of `entries`, in their order, as `BatchCitationRunner.run` looks them up, a slice at
    /// a time while the request's task goes on.
    nonisolated static func collect(_ entries: [CitationBlockSplitter.Entry],
                                    engine: CitationMatchingEngine) async throws -> [BatchCitationRow] {
        let collected = BatchRows()
        for start in stride(from: 0, to: entries.count, by: slice) {
            try Task.checkCancellation()
            let part = Array(entries[start..<min(start + slice, entries.count)])
            await BatchCitationRunner.run(entries: part, engine: engine, parser: CitationLookupRoutes.parser) { row in
                collected.rows.append(row)
            }
        }
        return await collected.rows
    }
}
