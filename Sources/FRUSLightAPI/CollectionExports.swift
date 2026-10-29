// A collection's live preview and its exports (PLAN's S18e), each the kit's: the collection resolved by
// its assembly (`CollectionContentAssembly`) over this server's data source (CollectionContent.swift),
// then rendered by its renderers, as the app's preview and export sheet resolve and render one.
// - The preview, `GET /api/v1/me/collections/{id}/preview`, is the HTML export's page,
//   `CollectionItemHTMLRenderer.pageHTML`, resolved for the preview, which downloads and generates
//   nothing: the first 20 documents, with every apparatus block, until Render All asks for all; a
//   document of a volume the server's folder lacks as its citation card; a summary not stored as its
//   placeholder. It is a page of its own, for the editor's sandboxed frame, which loads nothing from
//   elsewhere and runs no script.
// - The exports, `POST /api/v1/me/collections/{id}/export`: HTML, the page `HTMLCollectionExporter`
//   writes; Word, `DocxCollectionExporter.documentData`; BibTeX and RIS, `BibTeXCollectionExporter.bibTeX`
//   and `ZoteroCollectionExporter.ris`, the bytes each exporter writes to its file, named as it names
//   it, which the browser saves. Each is kept in the history as the app's `ExportHistoryRecorder`
//   keeps it, while Log Research Sessions is on. No word cloud is drawn, since its drawing is the
//   app's (SwiftUI); PDF waits for phase 3, `.fruscollection` for S18f.
// - The quotation check, `GET /api/v1/me/collections/{id}/excerpt-check`, which the export sheet runs
//   as it opens and which warns without blocking: the kit's `ExcerptVerifier` over the served index's
//   body texts, a document an update removed told apart by its revision, and the report's sentence.
// A smart collection's documents come from its saved search, which S18f resolves: until then neither
// is offered for one.
//
// App code mirrored here, held to its source by CollectionExportParityTests:
// - `CollectionPreviewView`: its cap, `capEntries(_:cap:)`, `previewOptions()` and the volumes it
//   names as not downloaded, here those the server's folder of volumes lacks;
// - `ExportFormat`: the four formats' raw values, suffixes and `exportOptions(for:)`;
// - `CollectionExportMetadata.forExport(of:activeProject:modelContext:)`, with its method appendix
//   (`ResearchDataExporter.collectionMethodAppendixLines`);
// - `ProseRichText.exportRTF` read by `CollectionProse.paragraphs(fromRTF:)`, through the web's codec;
// - `ExportSheetView`'s `verifyExcerpts()`, `exportZoteroRIS()` and `recordExport`, with
//   `ExportHistoryRecorder.record`.

import FRUSCoreKit
import FRUSLightCore
import FRUSRichText
import Foundation
import Hummingbird

/// What the export sheet's check of a collection's quotations says, as the kit's
/// `ExcerptVerificationReport` reports it.
public struct ExcerptCheck: Codable, Equatable, Sendable, ResponseEncodable {
    /// The sentence the sheet shows above its Export button, or nil when there is nothing to say,
    /// as for a collection with no excerpt.
    public var summary: String?
    /// Whether a quotation was not found in the document it names, which the sheet shows in orange.
    public var hasFailures: Bool
    /// How many were found in their documents.
    public var verified: Int
    /// Those not found in the document they name.
    public var notFound: [ExcerptQuotation]
    /// Those of a document the served index does not hold, which could not be checked.
    public var notIndexed: [ExcerptQuotation]
    /// Those of a document an update removed from its volume.
    public var vanished: [ExcerptQuotation]
    /// Those too short, or too elided, to check.
    public var inconclusive: [ExcerptQuotation]
}

/// One quotation the check names.
public struct ExcerptQuotation: Codable, Equatable, Sendable {
    public var volumeId: String
    public var documentId: String
    public var text: String
}

/// The formats a collection exports to here, the app's `ExportFormat` cases but PDF, which waits for
/// phase 3's Chromium, and `.fruscollection`, S18f's.
enum CollectionExportFormat: String, CaseIterable, Sendable {
    case html, docx, bibtex, zoteroJSON

    /// The end of the file's name, as each exporter names its file (`CollectionExportNaming.fileName`).
    var suffix: String {
        switch self {
        case .html: ".html"
        case .docx: ".docx"
        case .bibtex: ".bib"
        case .zoteroJSON: "-zotero.ris"
        }
    }

    var mediaType: String {
        switch self {
        case .html: "text/html; charset=utf-8"
        case .docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .bibtex: "application/x-bibtex; charset=utf-8"
        case .zoteroJSON: "application/x-research-info-systems; charset=utf-8"
        }
    }

    /// `ExportFormat.printsFigureImages`: HTML and Word print a figure's image.
    var printsFigureImages: Bool { self == .html || self == .docx }

    /// `ExportFormat.drawsWordCloud`: HTML and Word draw the word cloud when the collection asks.
    var drawsWordCloud: Bool { self == .html || self == .docx }

    /// `ExportFormat.exportOptions(for:)`: the collection's composition, the word cloud asked of a
    /// format that draws one.
    func exportOptions(for collection: CollectionExport) -> CollectionExportOptions {
        var options = CollectionExportOptions(composing: collection)
        options.includeWordCloud = options.includeWordCloud && drawsWordCloud
        return options
    }
}

enum CollectionExportRoutes {
    /// `CollectionPreviewView.initialDocumentCap`: the documents the preview resolves before Render All.
    static let initialDocumentCap = 20
    /// The locale the app writes an export's dates in on the owner's devices: the Word cover's and the
    /// colophon's long date, and the Chronology's.
    static let locale = Locale(identifier: "en_US")

    struct Export: Decodable {
        let format: String
        let timeZone: String?
    }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    reader: ReaderService, provider: ServedIndexProvider) {
        let store = services.store
        let now = services.now
        let parses = CollectionDocumentParses(reader: reader, resources: resources)
        let figures = ServedFigureImages(volumesDirectory: reader.volumesDirectory, resources: resources)

        // The live preview, as the app's pane renders it, for the editor's frame: a problem is a page
        // too, the app's Preview Unavailable over what went wrong, since the frame shows what comes.
        me.get("collections/:collectionId/preview") { request, context -> Response in
            do {
                let query = try FormQuery(request.uri.query)
                try query.refuseUnknown(["renderAll", "timeZone"])
                let user = try context.requireUser()
                let renderAll = try query.bool("renderAll") ?? false
                let timeZone = try zone(try query.single("timeZone"), field: "timeZone")
                let collection = try await CollectionRoutes.collection(try context.parameters.require("collectionId"),
                                                                       of: user.id, in: store)
                guard collection.savedSearchId == nil else { throw CollectionRoutes.smartWaits() }
                let time = now()
                let research = try await Blocking.run { try CollectionResearch.read(for: user.id, in: store) }
                let metadata = try await metadata(of: collection, research: research, for: user.id, in: store,
                                                  resources: resources, at: time, timeZone: timeZone)
                // None while no index is installed; one being installed is a 503, as for a search.
                let served = try await provider.servedIfReady()
                try await warm(collection, resources: resources)
                let entries = renderAll ? collection.entries : capped(collection.entries, cap: initialDocumentCap)
                let items = try await context.whileClientConnected {
                    try await resolve(collection, entries: entries, research: research, served: served, resources: resources,
                                      parses: parses, purpose: .preview)
                }
                let missing = volumesNotHeld(collection.entries, resources: resources, in: reader.volumesDirectory)
                let page = try await Blocking.run {
                    var renderer = CollectionItemHTMLRenderer(options: previewOptions(collection))
                    renderer.figureImages = figures
                    renderer.citationOnlyVolumeIds = missing
                    renderer.showsSummaryPlaceholders = true
                    return renderer.pageHTML(metadata: metadata, items: items)
                }
                return Response(status: .ok, headers: previewHeaders, body: .init(byteBuffer: ByteBuffer(string: page)))
            } catch let problem as APIProblem {
                return Response(status: problem.status, headers: previewHeaders,
                                body: .init(byteBuffer: ByteBuffer(string: unavailablePage(problem.detail))))
            } catch is CancellationError {
                throw CancellationError()
            } catch let closed as ClientClosedConnection {
                throw closed
            } catch {
                context.logger.error("A collection's preview could not be built: \(error)")
                return Response(status: .internalServerError, headers: previewHeaders,
                                body: .init(byteBuffer: ByteBuffer(string: unavailablePage("The server could not build the preview."))))
            }
        }

        // Export {Format}: the file the app's sheet writes for the format chosen, which the browser
        // saves, kept in the history.
        me.post("collections/:collectionId/export") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Export.self, from: request, fields: ["format", "timeZone"])
            guard let format = CollectionExportFormat(rawValue: body.format) else {
                let names = CollectionExportFormat.allCases.map(\.rawValue).joined(separator: ", ")
                throw CollectionRoutes.invalidField("format", "\(body.format) is not a format this server exports: \(names).")
            }
            let timeZone = try zone(body.timeZone, field: "timeZone")
            let collection = try await CollectionRoutes.collection(try context.parameters.require("collectionId"), of: user.id, in: store)
            guard collection.savedSearchId == nil else { throw CollectionRoutes.smartWaits() }
            // The sheet's Export is disabled for a collection with no entry, as its button is.
            guard !collection.entries.isEmpty else {
                throw APIProblem(.conflict, code: "COLLECTION_EMPTY", detail: "This collection has nothing in it to export yet.")
            }
            let time = now()
            let research = try await Blocking.run { try CollectionResearch.read(for: user.id, in: store) }
            let served = try await provider.servedIfReady()
            try await warm(collection, resources: resources)
            let options = format.exportOptions(for: collection)
            let file: (data: Data, documents: Int, name: String)
            if format == .zoteroJSON {
                // `exportZoteroRIS()`: the documents alone, no summary phase, and metadata of the name and
                // note, which names the file; none to send is the sheet's refusal.
                let documents = try await context.whileClientConnected {
                    try await resolveDocuments(collection, research: research, served: served, resources: resources, parses: parses)
                }
                guard !documents.isEmpty else {
                    throw APIProblem(.conflict, code: "NOTHING_TO_EXPORT", detail: "This collection has no documents to send.")
                }
                let metadata = CollectionExportMetadata(name: collection.name, note: collection.note)
                let text = ZoteroCollectionExporter().ris(for: documents.map { .document($0) }, options: options)
                file = (Data(text.utf8), documents.count, CollectionExportNaming.fileName(savedName: metadata.name, suffix: format.suffix))
            } else {
                let metadata = try await metadata(of: collection, research: research, for: user.id, in: store,
                                                  resources: resources, at: time, timeZone: timeZone)
                file = try await context.whileClientConnected {
                    let items = try await resolve(collection, entries: collection.entries, research: research, served: served,
                                                  resources: resources, parses: parses, purpose: .export,
                                                  printsFigureImages: format.printsFigureImages)
                    let data = try await Blocking.run { rendered(items, metadata: metadata, format: format, options: options, figures: figures) }
                    return (data, items.documents.count, CollectionExportNaming.fileName(savedName: metadata.name, suffix: format.suffix))
                }
            }
            // Kept as the app keeps it once the file is written; a row that cannot be written is said in the
            // log, as the file is the export.
            do {
                try await record(format, documents: file.documents, of: collection, for: user.id, in: store, at: now())
            } catch {
                context.logger.error("A collection's export could not be kept in the history: \(error)")
            }
            var headers = HTTPFields()
            headers[.contentType] = format.mediaType
            headers[.contentDisposition] = attachment(file.name)
            headers[.cacheControl] = "no-store"
            headers[.xContentTypeOptions] = "nosniff"
            return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(bytes: file.data)))
        }

        // The quotation check the export sheet runs as it opens (`verifyExcerpts()`), which never blocks.
        me.get("collections/:collectionId/excerpt-check") { request, context -> ExcerptCheck in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let collection = try await CollectionRoutes.collection(try context.parameters.require("collectionId"), of: user.id, in: store)
            return try await excerptCheck(collection.entries, provider: provider)
        }
    }

    // MARK: - Resolving

    /// The collection's items, as the app's resolver gives them to the preview or the export sheet: its
    /// entries as their values, a prose block's paragraphs decoded, the introduction leading, with this
    /// user's research and the library as the data source.
    @MainActor
    static func resolve(_ collection: CollectionExport, entries: [CollectionEntryExport], research: CollectionResearch,
                        served: ServedIndex?, resources: ServerResources, parses: CollectionDocumentParses,
                        purpose: CollectionContentAssembly.Purpose, printsFigureImages: Bool = false) async throws -> [CollectionExportItem] {
        let entries = entries.map(entry)
        do {
            return try await assembly(collection, entries: entries, research: research, served: served, resources: resources, parses: parses)
                .resolve(entries: entries, introduction: introduction(of: collection), purpose: purpose,
                         printsFigureImages: printsFigureImages)
        } catch {
            throw refusal(error)
        }
    }

    /// The collection's documents alone, for RIS, as `resolveDocuments(collection:entries:allNotes:purpose:)`.
    @MainActor
    static func resolveDocuments(_ collection: CollectionExport, research: CollectionResearch, served: ServedIndex?,
                                 resources: ServerResources, parses: CollectionDocumentParses) async throws -> [CollectionExportDocument] {
        let entries = collection.entries.map(entry)
        do {
            return try await assembly(collection, entries: entries, research: research, served: served, resources: resources, parses: parses)
                .resolveDocuments(entries: entries, purpose: .export)
        } catch {
            throw refusal(error)
        }
    }

    /// The kit's refusal of an export as the sheet shows it, in the app's words: no summary prompt for
    /// Summary only, or a summary only an export would write, as on a device without Apple
    /// Intelligence. Any other error is as it was.
    static func refusal(_ error: any Error) -> any Error {
        switch error {
        case let error as CollectionResolveError:
            let code = if case .summaryPromptMissing = error { "SUMMARY_PROMPT_MISSING" } else { "COLLECTION_NOT_RESOLVED" }
            return APIProblem(.conflict, code: code, detail: error.errorDescription ?? "\(error)")
        case let error as ExportError:
            return APIProblem(.conflict, code: "EXPORT_NOT_RENDERED", detail: error.errorDescription ?? "\(error)")
        default:
            return error
        }
    }

    @MainActor
    private static func assembly(_ collection: CollectionExport, entries: [CollectionContentAssembly.Entry], research: CollectionResearch,
                                 served: ServedIndex?, resources: ServerResources,
                                 parses: CollectionDocumentParses) -> CollectionContentAssembly {
        CollectionContentAssembly(
            collection: collection, notes: research.notes,
            source: CollectionContentSource(research: research, served: served, resources: resources, parses: parses,
                                            batch: CollectionDocumentBatch(entries)),
            locale: locale)
    }

    /// The archival indexes, decoded before a collection with a Sources & Archives block is resolved,
    /// off the main actor the assembly runs on, which would otherwise decode them there the first time.
    static func warm(_ collection: CollectionExport, resources: ServerResources) async throws {
        guard collection.entries.contains(where: { $0.generatedBlockType == CollectionGeneratedBlockType.archivalSources.rawValue }) else { return }
        _ = try await Blocking.run { resources.archivalIndexes }
    }

    /// An entry as the assembly reads it: its values, and a prose block's paragraphs.
    static func entry(_ entry: CollectionEntryExport) -> CollectionContentAssembly.Entry {
        CollectionContentAssembly.Entry(entry, proseParagraphs: entry.entryKind == .prose
            ? proseParagraphs(stored: entry.richText, text: entry.text) : nil)
    }

    /// A prose block's paragraphs, as the app's resolver decodes `ProseRichText.exportRTF(from:)` with
    /// `CollectionProse.paragraphs(fromRTF:)`: its RTF when the codec reads it, each run as the app
    /// reads it split by the kit's rule, none for RTF of no text; otherwise its text, which the app
    /// writes as plain RTF and reads back as one run with no formatting. A pre-RTF blob of July 2026's,
    /// which the app reads as its bold and italic, the web reads as that text.
    static func proseParagraphs(stored: Data?, text: String?) -> [[ProseFormattedSpan]] {
        if let stored, let reading = RTFReader.read([UInt8](stored)) { return paragraphs(reading.text, reading.runs) }
        let plain = text ?? ""
        return paragraphs(plain, [RichTextRun(text: plain)])
    }

    /// The collection's introduction, `ProseRichText.exportRTF(richText:plainText:)` read so: its RTF
    /// when that reads as some text, else its text when that holds more than spaces, else none.
    static func introduction(of collection: CollectionExport) -> [[ProseFormattedSpan]]? {
        if let stored = collection.introductionRichText, let reading = RTFReader.read([UInt8](stored)), !reading.text.isEmpty {
            return paragraphs(reading.text, reading.runs)
        }
        guard let plain = collection.introductionText, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return paragraphs(plain, [RichTextRun(text: plain)])
    }

    /// `CollectionProse.paragraphs(fromDecoded:)`: each run appended by the kit's rule, or none for no text.
    private static func paragraphs(_ text: String, _ runs: [RichTextRun]) -> [[ProseFormattedSpan]] {
        guard !text.isEmpty else { return [] }
        var paragraphs: [[ProseFormattedSpan]] = [[]]
        for run in runs {
            CollectionProse.append(text: run.text, bold: run.bold, italic: run.italic, underline: run.underline,
                                   colorHex: run.colorHex, linkURL: run.linkURL, to: &paragraphs)
        }
        return paragraphs
    }

    /// `CollectionPreviewView.capEntries(_:cap:)`: the entries in their order, up to `cap` documents,
    /// and every apparatus block past them, which costs no parse and renders over the whole collection.
    static func capped(_ entries: [CollectionEntryExport], cap: Int) -> [CollectionEntryExport] {
        var documentCount = 0
        var out: [CollectionEntryExport] = []
        for entry in entries.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            if entry.entryKind == .document { documentCount += 1 }
            if documentCount > cap {
                if entry.entryKind == .generated { out.append(entry) }
                continue
            }
            out.append(entry)
        }
        return out
    }

    /// `CollectionPreviewView.previewOptions()`: the composition's options, the word cloud off, and the
    /// headnote default left at its own, which the renderer does not read.
    static func previewOptions(_ collection: CollectionExport) -> CollectionExportOptions {
        let composed = CollectionExportOptions(composing: collection)
        return CollectionExportOptions(tocStyle: composed.tocStyle, includeFootnotes: composed.includeFootnotes,
                                       includeSourceNote: composed.includeSourceNote, applyHighlights: composed.applyHighlights,
                                       includeNotes: composed.includeNotes, summaryPromptId: composed.summaryPromptId,
                                       includeWordCloud: false)
    }

    /// The volumes of the collection's documents the server cannot open, which the preview prints as
    /// citations, as the app's prints those not downloaded: one the folder of volumes lacks, or one
    /// outside the catalogue, whose file the server never opens.
    static func volumesNotHeld(_ entries: [CollectionEntryExport], resources: ServerResources, in volumesDirectory: URL) -> Set<String> {
        let needed = Set(entries.filter { $0.entryKind == .document && !$0.volumeId.isEmpty }.map(\.volumeId))
        return needed.filter { resources.volume($0) == nil || ReaderService.teiFile(for: $0, in: volumesDirectory) == nil }
    }

    /// The metadata an export of `collection` carries, which the preview shows too:
    /// `CollectionExportMetadata.forExport`, the project the user works in as its provenance where the
    /// collection asks, and the method appendix of its searches where it asks; dated now, in the app's
    /// `en_US` and the browser's time zone.
    static func metadata(of collection: CollectionExport, research: CollectionResearch, for user: String,
                         in store: any UserDataStore, resources: ServerResources, at time: Date,
                         timeZone: TimeZone) async throws -> CollectionExportMetadata {
        let project = research.activeProject
        let provenance = CollectionExportMetadata.projectProvenance(
            enabled: collection.includeProjectProvenance ?? false, projectName: project?.name,
            researchQuestion: project?.researchQuestion)
        var appendixLines: [String] = []
        if collection.includeMethodAppendix ?? false {
            // `CollectionExportMetadata.methodAppendix(enabled:appendix:)`: none for an appendix of no search.
            let appendix = try await HistoryRoutes.methodAppendix(of: user, in: store, generatedAt: time)
                .scoped(toProject: project?.id)
            if !appendix.rows.isEmpty {
                appendixLines = appendix.plainTextLines(for: HistoryRoutes.appendixHost(resources: resources, timeZone: timeZone))
            }
        }
        return CollectionExportMetadata(
            name: collection.name, note: collection.note, subtitle: collection.subtitle, authorLine: collection.authorLine,
            projectName: provenance.name, projectResearchQuestion: provenance.question,
            includeColophon: collection.includeColophon ?? false, methodAppendixLines: appendixLines,
            exportDate: CollectionExportDate(date: time, locale: locale, timeZone: timeZone))
    }

    // MARK: - Writing

    /// The file `format`'s exporter writes for `items`: the HTML exporter's page, with no word cloud,
    /// which its drawing alone could add, and the Word exporter's package, both with the folder's
    /// figures; BibTeX's text.
    static func rendered(_ items: [CollectionExportItem], metadata: CollectionExportMetadata, format: CollectionExportFormat,
                         options: CollectionExportOptions, figures: any FigureImageSource) -> Data {
        switch format {
        case .html:
            var renderer = CollectionItemHTMLRenderer(options: options)
            renderer.figureImages = figures
            return Data(renderer.pageHTML(metadata: metadata, items: items, wordCloudPNGBase64: nil).utf8)
        case .docx:
            return DocxCollectionExporter(figureImages: figures).documentData(metadata: metadata, items: items, options: options)
        case .bibtex:
            return Data(BibTeXCollectionExporter().bibTeX(for: items, options: options).utf8)
        case .zoteroJSON:
            return Data(ZoteroCollectionExporter().ris(for: items, options: options).utf8)
        }
    }

    /// `recordExport(format:documentCount:)`, through `ExportHistoryRecorder.record`: the format's raw
    /// value, the documents that went out, the collection's name trimmed or none, and the project the
    /// user works in, unless Log Research Sessions is off.
    static func record(_ format: CollectionExportFormat, documents: Int, of collection: CollectionExport, for user: String,
                       in store: any UserDataStore, at time: Date) async throws {
        guard try await PreferenceRoutes.isLogging(user, in: store) else { return }
        let name = collection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = try await Blocking.run { try store.activeProjectId(of: user) }.flatMap(UUID.init(uuidString:))
        let entry = ExportHistoryEntryExport(id: UUID(), format: format.rawValue, documentCount: documents,
                                             collectionName: name.isEmpty ? nil : name, projectId: project,
                                             exportedAt: UserStoreDate.rounded(time))
        try await Blocking.run {
            try store.addResearchRow(TrailTable.exports.table, MacImport.exported(entry).values, for: user, outsideSearch: true)
        }
    }

    /// A download's `Content-Disposition`: the name in ASCII, a character outside it as `_`, and whole in
    /// UTF-8 (RFC 6266), which a browser prefers.
    static func attachment(_ name: String) -> String {
        let ascii = String(name.unicodeScalars.map { $0.isASCII && $0.value >= 0x20 && $0 != "\"" && $0 != "\\" ? Character($0) : "_" })
        var allowed = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: Unicode.Scalar(0)..<Unicode.Scalar(0x80)))
        allowed.insert(charactersIn: "!#$&+-.^_`|~")
        let encoded = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? ascii
        return "attachment; filename=\"\(ascii)\"; filename*=UTF-8''\(encoded)"
    }

    // MARK: - The preview's page

    /// The preview's page loads nothing from elsewhere, runs no script of its own, styles itself and
    /// embeds its figures; only the server's own app may frame it, and it is sandboxed wherever it is
    /// opened, with its links to history.state.gov opening a tab of their own. The sandbox allows
    /// scripts, as the reader's frame does, so that a browser's own tools, an accessibility check
    /// among them, reach the page, where the policy lets none of the page's run.
    static let previewPolicy = [
        "default-src 'none'", "script-src 'none'", "style-src 'unsafe-inline'", "img-src data:", "base-uri 'none'",
        "form-action 'none'", "frame-ancestors 'self'", "sandbox allow-scripts allow-popups allow-popups-to-escape-sandbox",
    ].joined(separator: "; ")

    static var previewHeaders: HTTPFields {
        var headers = ReaderRoutes.commonHeaders
        headers[.contentType] = "text/html; charset=utf-8"
        headers[.contentSecurityPolicy] = previewPolicy
        headers[.cacheControl] = "no-store"
        return headers
    }

    /// The app's Preview Unavailable over what went wrong, as a page for the frame.
    static func unavailablePage(_ detail: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>Preview Unavailable</title>
          <style>body { font: 15px/1.5 -apple-system, system-ui, sans-serif; color: #1c1c1e; margin: 3rem 1.5rem; text-align: center; }</style>
        </head>
        <body>
          <h1>Preview Unavailable</h1>
          <p>\(escaped(detail))</p>
        </body>
        </html>
        """
    }

    static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - The quotation check

    /// `verifyExcerpts()`: each excerpt's stored text checked against its document's body text as the
    /// served index holds it, a document whose revision says an update removed it told apart from one
    /// the index does not hold, and every one uncheckable while no index is installed. A read that fails
    /// is no verdict: the app reads it as nothing indexed, and so does this; an index being installed is
    /// the 503 a search answers then.
    static func excerptCheck(_ entries: [CollectionEntryExport], provider: ServedIndexProvider) async throws -> ExcerptCheck {
        let requests = entries.compactMap { entry -> ExcerptVerifier.Request? in
            guard entry.entryKind == .excerpt, let text = entry.text, !text.isEmpty,
                  !entry.volumeId.isEmpty, !entry.documentId.isEmpty else { return nil }
            return ExcerptVerifier.Request(volumeId: entry.volumeId, documentId: entry.documentId, text: text)
        }
        guard !requests.isEmpty else { return check(nil) }
        guard let served = try await provider.servedIfReady() else {
            return check(ExcerptVerificationReport(outcomes: Dictionary(requests.map { ($0, .documentNotIndexed) },
                                                                        uniquingKeysWith: { first, _ in first })))
        }
        let keys = Set(requests.map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) })
        let bodies = (try? await served.pipeline.documentBodyTextsByKey(forKeys: Array(keys))) ?? [:]
        let outcomes = ExcerptVerifier.verify(requests, bodyTexts: bodies)
        var changeKinds: [String: String] = [:]
        for request in outcomes.filter({ $0.value == .documentNotIndexed }).keys {
            let key = "\(request.volumeId)/\(request.documentId)"
            guard changeKinds[key] == nil else { continue }
            let row = try? await served.pipeline.documentRevision(volumeId: request.volumeId, documentId: request.documentId)
            changeKinds[key] = row?.changeKind ?? ""
        }
        return check(ExcerptVerificationReport(outcomes: ExcerptVerifier.upgradingVanished(outcomes, changeKinds: changeKinds)))
    }

    private static func check(_ report: ExcerptVerificationReport?) -> ExcerptCheck {
        func quotations(_ requests: [ExcerptVerifier.Request]?) -> [ExcerptQuotation] {
            (requests ?? []).map { ExcerptQuotation(volumeId: $0.volumeId, documentId: $0.documentId, text: $0.text) }
        }
        return ExcerptCheck(summary: report?.summary, hasFailures: report?.hasFailures ?? false, verified: report?.verifiedCount ?? 0,
                            notFound: quotations(report?.failures), notIndexed: quotations(report?.unindexed),
                            vanished: quotations(report?.vanished), inconclusive: quotations(report?.inconclusive))
    }

    // MARK: - Fields

    /// The time zone an export's day is read in, the browser's: UTC when none is named, and a zone this
    /// server does not know refused.
    static func zone(_ name: String?, field: String) throws -> TimeZone {
        let name = name ?? "UTC"
        guard let zone = TimeZone(identifier: name) else {
            throw CollectionRoutes.invalidField(field, "\(name) is not a time zone this server knows.")
        }
        return zone
    }
}
