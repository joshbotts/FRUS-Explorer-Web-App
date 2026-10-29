// PLAN's S18e done-when: each export byte for byte the kit's for the same collection. Over the kit's
// own index of the three fixture volumes, imported as an export, with their TEI mounted and a figure
// image beside one, collections made through the API with every kind of entry and every part of a
// composition are exported in each format and previewed, capped and whole, and each answer is held to
// the kit's: the file its exporter writes, `HTMLCollectionExporter`, `DocxCollectionExporter`,
// `BibTeXCollectionExporter` and `ZoteroCollectionExporter`, and the page its renderer builds for the
// preview, of the items its assembly resolves for the same collection over a data source the test
// makes as the app's resolver reads SwiftData: the user's research as their JSON export carries it,
// the index, each document parsed as the app parses one, and the figures' folder. The app code the
// routes mirror is held to its source by the second test.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import FTS5Store
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct CollectionExportParityTests {
    static let kennedy = "frus1961-63v06"
    static let sahara = "frus1969-76ve09p1"
    static let nicaragua = "frus1894Nicaragua"

    /// A one-pixel PNG, as a figure image's file.
    static let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
                           0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
                           0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
                           0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82])

    /// The browser app's requests: its origin, its token and JSON.
    struct Session {
        let client: any TestClientProtocol
        let token: String

        static func open(_ client: any TestClientProtocol) async throws -> Session {
            Session(client: client, token: try ServedFixture.decode(Me.self, try await client.execute(uri: "/api/v1/me", method: .get)).csrfToken)
        }

        func send(_ method: HTTPRequest.Method, _ path: String, _ body: String? = nil) async throws -> TestResponse {
            var headers: HTTPFields = [.origin: "http://localhost:8080", CSRFTokens.header: token]
            if body != nil { headers[.contentType] = "application/json" }
            let response = try await client.execute(uri: path, method: method, headers: headers, body: body.map { ByteBuffer(string: $0) })
            guard (200..<300).contains(response.status.code) else {
                throw APIParityError("\(method) \(path): \(response.status.code) \(String(buffer: response.body))")
            }
            return response
        }

        func json<T: Decodable>(_ type: T.Type, _ method: HTTPRequest.Method, _ path: String, _ body: [String: Any?]? = nil) async throws -> T {
            try ServedFixture.decode(type, try await send(method, path, try body.map(CollectionExportParityTests.json)))
        }

        func get(_ path: String) async throws -> TestResponse {
            let response = try await client.execute(uri: path, method: .get)
            guard response.status == .ok else { throw APIParityError("GET \(path): \(response.status.code) \(String(buffer: response.body))") }
            return response
        }

        /// The rendering version the reader's page names, which an excerpt or a highlight of it sends.
        func version(_ volume: String, _ document: String) async throws -> String {
            let page = try await get("/api/v1/volumes/\(volume)/documents/\(document)/html")
            return try #require(page.headers[ReaderRoutes.renderingVersionHeader])
        }
    }

    static func json(_ object: [String: Any?]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object.mapValues { $0 ?? NSNull() }), as: UTF8.self)
    }

    static func documents(_ volume: String, _ ids: [String]) -> [String: Any?] {
        ["documents": ids.map { ["volumeId": volume, "documentId": $0] }]
    }

    static func run(_ text: String, bold: Bool = false, italic: Bool = false, link: String? = nil) -> [String: Any?] {
        ["text": text, "bold": bold, "italic": italic, "underline": false, "colorHex": nil, "linkURL": link]
    }

    @Test func eachExportAndThePreviewAreTheKitsByteForByte() async throws {
        try await ServedFixture.run { client, files in
            let session = try await Session.open(client)
            // A figure image of Sahara's d87, as FRUS Explorer keeps one beside its volume.
            let figures = files.volumesDirectory.appendingPathComponent("\(Self.sahara).figures", isDirectory: true)
            try FileManager.default.createDirectory(at: figures, withIntermediateDirectories: true)
            try Self.png.write(to: figures.appendingPathComponent("genassemblybldg.png"))

            // The research the collections draw on: a project worked in, a search run under it, a tag on
            // a document and on a note, a highlight and a summary of the reader's own.
            let project = try await session.json(Project.self, .post, "/api/v1/me/projects",
                                                 ["name": "Kennedy and Khrushchev", "researchQuestion": "How did the letters begin?"])
            _ = try await session.send(.post, "/api/v1/me/history/searches", #"{"search": "keywords=Khrushchev", "anchor": null}"#)
            let tag = try await session.json(UserTag.self, .post, "/api/v1/me/tags", ["name": "Letters"])
            _ = try await session.send(.put, "/api/v1/me/volumes/\(Self.kennedy)/documents/d1/tags", try Self.json(["tagIds": [tag.id]]))
            _ = try await session.send(.post, "/api/v1/me/volumes/\(Self.kennedy)/documents/d2/notes", try Self.json([
                "bodyText": "Read beside the first letter.", "runs": nil, "userTagIds": [tag.id], "projectIds": [], "selectedSummaryIds": [],
            ]))
            let v1 = try await session.version(Self.kennedy, "d1")
            _ = try await session.send(.post, "/api/v1/me/volumes/\(Self.kennedy)/documents/d1/highlights", try Self.json([
                "startOffset": 12, "endOffset": 60, "colorTag": "green", "renderingVersion": v1,
            ]))
            _ = try await session.send(.post, "/api/v1/me/volumes/\(Self.kennedy)/documents/d3/summaries",
                                       try Self.json(["responseText": "Khrushchev answers the President."]))

            // Every part of a composition: the title page, the introduction, the colophon, the project and
            // the method appendix; sections two deep; documents of three volumes, one at the index's depth,
            // two with their See also lines, one with a headnote, one with its figure; a note block; an
            // excerpt; and the five apparatus blocks.
            let base = "/api/v1/me/collections"
            let rich = try await session.json(CollectionDetail.self, .post, base, ["name": "Letters, every part"])
            let path = "\(base)/\(rich.id)"
            _ = try await session.send(.patch, path, try Self.json([
                "subtitle": "A reader", "authorLine": "A. Historian", "includeColophon": true, "includeProjectProvenance": true,
                "includeMethodAppendix": true, "applyHighlights": true, "includeSourceNote": true, "tocStyle": "headerAndDateline",
                "introductionText": "An introduction, in part bold.", "introductionRuns": [Self.run("An introduction, "), Self.run("in part bold.", bold: true)],
            ]))
            let heading = try await session.json(CollectionEdit.self, .post, "\(path)/blocks", ["kind": "heading"])
            _ = try await session.send(.patch, "\(path)/entries/\(heading.entryIds[0])", try Self.json(["text": "The first letters"]))
            let letters = try await session.json(CollectionEdit.self, .post, "\(path)/documents", Self.documents(Self.kennedy, ["d1", "d2", "d3", "d4"]))
            let prose = try await session.json(CollectionEdit.self, .post, "\(path)/blocks", ["kind": "prose"])
            _ = try await session.send(.patch, "\(path)/entries/\(prose.entryIds[0])", try Self.json([
                "text": "Read these together. See the volume online.",
                "runs": [Self.run("Read these "), Self.run("together", italic: true), Self.run(". See the "),
                         Self.run("volume online", link: "https://history.state.gov/historicaldocuments/frus1961-63v06"), Self.run(".")],
            ]))
            let v2 = try await session.version(Self.kennedy, "d2")
            let excerpt = try await session.json(CollectionEdit.self, .post, "\(path)/excerpts", [
                "volumeId": Self.kennedy, "documentId": "d2", "startOffset": 200, "endOffset": 340, "renderingVersion": v2,
            ])
            let frozen = excerpt.collection.entries.last?.text ?? ""
            let later = try await session.json(CollectionEdit.self, .post, "\(path)/blocks", ["kind": "heading"])
            _ = try await session.send(.patch, "\(path)/entries/\(later.entryIds[0])", try Self.json(["text": "Elsewhere"]))
            _ = try await session.send(.post, "\(path)/entries/\(later.entryIds[0])/indent")
            let elsewhere = try await session.json(CollectionEdit.self, .post, "\(path)/documents",
                                                   ["documents": [["volumeId": Self.sahara, "documentId": "d87"], ["volumeId": Self.nicaragua, "documentId": "d1"]]])
            for type in CollectionGeneratedBlockType.allCases {
                _ = try await session.send(.post, "\(path)/blocks", try Self.json(["generatedBlockType": type.rawValue]))
            }
            for (entry, change) in [(letters.entryIds[1], ["includeRelatedDocuments": true]), (letters.entryIds[3], ["includeRelatedDocuments": true]),
                                    (letters.entryIds[2], ["includeHeadnote": true]), (elsewhere.entryIds[1], ["bodyDepthOverride": "index"])] {
                _ = try await session.send(.patch, "\(path)/entries/\(entry)", try Self.json(change))
            }

            // A collection as it is made, two letters and nothing else; one past the preview's cap, with a
            // bibliography; and one of a volume the folder lacks.
            let plain = try await session.json(CollectionDetail.self, .post, base, ["name": "Two letters"])
            _ = try await session.send(.post, "\(base)/\(plain.id)/documents", try Self.json(Self.documents(Self.kennedy, ["d1", "d2"])))
            let many = try await session.json(CollectionDetail.self, .post, base, ["name": "Twenty-two letters"])
            _ = try await session.send(.post, "\(base)/\(many.id)/documents", try Self.json(Self.documents(Self.kennedy, (1...22).map { "d\($0)" })))
            _ = try await session.send(.post, "\(base)/\(many.id)/blocks", try Self.json(["generatedBlockType": "bibliography"]))
            let away = try await session.json(CollectionDetail.self, .post, base, ["name": "A volume away"])
            let awayDetail = try await session.json(CollectionEdit.self, .post, "\(base)/\(away.id)/documents",
                                                    ["documents": [["volumeId": "frus1961-63v05", "documentId": "d1"], ["volumeId": Self.kennedy, "documentId": "d5"]]])
            #expect(awayDetail.collection.volumesNotHeld == ["frus1961-63v05"])

            // The quotation frozen from d2's page is found in the index's d2.
            let check = try ServedFixture.decode(ExcerptCheck.self, try await session.get("\(path)/excerpt-check"))
            #expect(check.summary == nil && check.verified == 1 && !check.hasFailures, "\(frozen): \(check)")

            let kit = try await KitReference(files: files, session: session, project: project.id)
            for collection in [rich.id, plain.id, many.id, away.id] {
                for format in CollectionExportFormat.allCases {
                    try await Self.sameDay { day in
                        let served = Data(buffer: try await session.send(.post, "\(base)/\(collection)/export",
                                                                         try Self.json(["format": format.rawValue, "timeZone": "UTC"])).body)
                        let theirs = try await kit.export(collection, format, on: day)
                        #expect(served == theirs, "\(collection) as \(format.rawValue): \(served.count) bytes, the kit's \(theirs.count)")
                        if format == .html, collection == rich.id {
                            let page = String(decoding: served, as: UTF8.self)
                            for part in ["See also", "data:image/png;base64,", "Compiled with FRUS Explorer", "Query log — method appendix",
                                         "Kennedy and Khrushchev", "excerpt-block", "generated-thematicIndex", "<strong>in part bold.</strong>",
                                         "Khrushchev answers the President.", "<mark class="] {
                                #expect(page.contains(part), "the rich collection's page holds \(part)")
                            }
                        }
                        if format == .docx, collection == rich.id {
                            #expect(served.range(of: Data("word/media/figure1.png".utf8)) != nil, "d87's figure, embedded")
                        }
                    }
                }
                for renderAll in [false, true] {
                    try await Self.sameDay { day in
                        let served = String(buffer: try await session.get("\(base)/\(collection)/preview?renderAll=\(renderAll)&timeZone=UTC").body)
                        let theirs = try await kit.preview(collection, renderAll: renderAll, on: day)
                        #expect(served == theirs, "\(collection)'s preview, renderAll \(renderAll)")
                    }
                }
            }
            let capped = String(buffer: try await session.get("\(base)/\(many.id)/preview").body)
            #expect(capped.components(separatedBy: "<section id=\"doc-").count - 1 == 20)
            #expect(String(buffer: try await session.get("\(base)/\(away.id)/preview").body).contains("Volume not downloaded — citation only"))
        }
    }

    /// Runs `body` again when the day it dated its comparison by is gone before it ends.
    static func sameDay(_ body: (Date) async throws -> Void) async throws {
        for _ in 0..<2 {
            let day = Date()
            try await body(day)
            if Calendar.gregorianUTC.isDate(day, inSameDayAs: Date()) { return }
        }
    }
}

extension Calendar {
    static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}

/// What the kit writes for a collection, from the user's JSON export, the index and the TEI, as the
/// app's export sheet and preview write it from SwiftData, its index and its volumes.
struct KitReference: Sendable {
    let envelope: ResearchDataEnvelope
    let files: DataDirectory
    let resources: ServerResources
    let pipeline: IndexingPipeline
    let persons: PersonMentionStore
    let references: SQLiteConnection

    init(files: DataDirectory, session: CollectionExportParityTests.Session, project: String) async throws {
        let file = try await session.get("/api/v1/me/export?includeGeneratedSummaries=true&projectId=\(project)")
        envelope = try ResearchDataEnvelope.makeDecoder().decode(ResearchDataEnvelope.self, from: Data(buffer: file.body))
        self.files = files
        resources = try ServerResources.load(from: ServedFixture.resources)
        pipeline = try IndexingPipeline(readingIndexAt: files.liveIndex, fts5Store: try FTS5Store(readingDatabaseAt: files.liveIndex),
                                        resources: resources.indexing, volumesDirectory: files.volumesDirectory)
        persons = try PersonMentionStore(readingDatabaseAt: files.liveIndex)
        references = try SQLiteConnection.immutable(files.liveIndex)
    }

    func collection(_ id: String) throws -> CollectionExport {
        try #require(envelope.collections.first { $0.id.uuidString == id })
    }

    /// The export sheet's file for `format`: the exporter's own, written to its temporary file.
    @MainActor
    func export(_ id: String, _ format: CollectionExportFormat, on day: Date) async throws -> Data {
        let collection = try collection(id)
        var options = CollectionExportOptions(composing: collection)
        options.includeWordCloud = options.includeWordCloud && (format == .html || format == .docx)
        let url: URL
        switch format {
        case .zoteroJSON:
            let documents = try await assembly(collection).resolveDocuments(entries: entries(collection), purpose: .export)
            url = try await ZoteroCollectionExporter().export(metadata: CollectionExportMetadata(name: collection.name, note: collection.note),
                                                              documents: documents, options: options)
        default:
            let items = try await assembly(collection).resolve(entries: entries(collection), introduction: CollectionExportRoutes.introduction(of: collection),
                                                               purpose: .export, printsFigureImages: format != .bibtex)
            let exporter: any CollectionExporter = switch format {
            case .html: HTMLCollectionExporter(figureImages: figures)
            case .docx: DocxCollectionExporter(figureImages: figures)
            default: BibTeXCollectionExporter()
            }
            url = try await exporter.export(metadata: try metadata(collection, on: day), items: items, options: options)
        }
        defer { try? FileManager.default.removeItem(at: url) }
        return try Data(contentsOf: url)
    }

    /// The preview's page, as `CollectionPreviewView.refresh()` builds it.
    @MainActor
    func preview(_ id: String, renderAll: Bool, on day: Date) async throws -> String {
        let collection = try collection(id)
        let all = collection.entries.sorted { $0.sortOrder < $1.sortOrder }
        let shown = renderAll ? all : CollectionExportRoutes.capped(all, cap: CollectionExportRoutes.initialDocumentCap)
        let items = try await assembly(collection).resolve(entries: shown.map(Self.entry), introduction: CollectionExportRoutes.introduction(of: collection),
                                                           purpose: .preview)
        let needed = Set(all.filter { $0.entryKind == .document && !$0.volumeId.isEmpty }.map(\.volumeId))
        var renderer = CollectionItemHTMLRenderer(options: CollectionExportRoutes.previewOptions(collection))
        renderer.figureImages = figures
        renderer.citationOnlyVolumeIds = needed.filter {
            !FileManager.default.fileExists(atPath: files.volumesDirectory.appendingPathComponent("\($0).xml").path)
        }
        renderer.showsSummaryPlaceholders = true
        return renderer.pageHTML(metadata: try metadata(collection, on: day), items: items)
    }

    @MainActor
    private func assembly(_ collection: CollectionExport) -> CollectionContentAssembly {
        // The editor's notes, newest first, as `@Query(sort: \ResearchNote.lastModified, order: .reverse)`.
        let notes = envelope.notes.sorted {
            ($0.lastModified ?? .distantPast, $1.id.uuidString) > ($1.lastModified ?? .distantPast, $0.id.uuidString)
        }.map {
            ResearchNoteExport(id: $0.id, documentId: $0.documentId, volumeId: $0.volumeId, bodyText: $0.bodyText, projectIds: [],
                               userTagIds: $0.userTagIds, selectedSummaryIds: [], linkedHighlightIds: [])
        }
        return CollectionContentAssembly(collection: collection, notes: notes,
                                         source: KitSource(reference: self), locale: Locale(identifier: "en_US"))
    }

    private func entries(_ collection: CollectionExport) -> [CollectionContentAssembly.Entry] {
        collection.entries.sorted { $0.sortOrder < $1.sortOrder }.map(Self.entry)
    }

    static func entry(_ entry: CollectionEntryExport) -> CollectionContentAssembly.Entry {
        .init(entry, proseParagraphs: entry.entryKind == .prose ? CollectionExportRoutes.proseParagraphs(stored: entry.richText, text: entry.text) : nil)
    }

    /// `CollectionExportMetadata.forExport`: the project the export was made under, the method appendix
    /// of the searches run under it, dated in the app's `en_US`, in UTC.
    private func metadata(_ collection: CollectionExport, on day: Date) throws -> CollectionExportMetadata {
        let provenance = CollectionExportMetadata.projectProvenance(enabled: collection.includeProjectProvenance ?? false,
                                                                    projectName: envelope.exportedForProjectName,
                                                                    researchQuestion: envelope.exportedForProjectResearchQuestion)
        let project = envelope.projects.first { $0.name == envelope.exportedForProjectName }
        var lines: [String] = []
        if collection.includeMethodAppendix ?? false {
            let appendix = QueryMethodAppendix.make(recordedSearches: envelope.searchHistory.map(HistoryRoutes.recorded), corpusNames: [:],
                                                    projectName: project?.name, researchQuestion: project?.researchQuestion,
                                                    generatedAt: day, corpusCoverage: [])
                .scoped(toProject: project?.id)
            if !appendix.rows.isEmpty {
                lines = appendix.plainTextLines(for: HistoryRoutes.appendixHost(resources: resources, timeZone: TimeZone(identifier: "UTC")!))
            }
        }
        return CollectionExportMetadata(name: collection.name, note: collection.note, subtitle: collection.subtitle,
                                        authorLine: collection.authorLine, projectName: provenance.name,
                                        projectResearchQuestion: provenance.question, includeColophon: collection.includeColophon ?? false,
                                        methodAppendixLines: lines,
                                        exportDate: CollectionExportDate(date: day, locale: Locale(identifier: "en_US"),
                                                                         timeZone: TimeZone(identifier: "UTC")!))
    }

    /// The figures' folder, as the app's `FigureImageStore` reads its own.
    var figures: any FigureImageSource { FolderFigures(volumes: files.volumesDirectory) }

    struct FolderFigures: FigureImageSource {
        let volumes: URL
        func data(for image: FigureImageName) -> Data? {
            guard let volume = image.volumeId, let file = image.fileName else { return nil }
            return try? Data(contentsOf: volumes.appendingPathComponent("\(volume).figures").appendingPathComponent(file))
        }
    }
}

/// The app's `CollectionContentResolver` data source, over the user's JSON export, the index and the
/// TEI: each read the fetch it makes, a document parsed as its cache's miss parses one.
@MainActor
struct KitSource: CollectionContentDataSource {
    let reference: KitReference

    var manifestEntries: [VolumeManifestEntry] { reference.resources.manifest }
    var indexingPipeline: IndexingPipeline? { reference.pipeline }

    func documentAST(volumeId: String, documentId: String) async -> FRUSDocumentAST? {
        let url = reference.files.volumesDirectory.appendingPathComponent("\(volumeId).xml")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? await FRUSDocumentParser().parseDocument(documentId: documentId, volumeURL: url)
    }

    func crossReferenceTargets(volumeId: String, documentId: String) async -> [(volumeId: String, documentId: String)]? {
        ((try? reference.references.query(ServedIndex.outboundEdgesQuery, [.text(documentId), .text(volumeId)])) ?? []).compactMap { row in
            guard let volume = row[0].text, let document = row[1].text else { return nil }
            return (volumeId: volume, documentId: document)
        }
    }

    var personMentionStore: PersonMentionStore? { reference.persons }

    var archivalIndexes: ArchivalIndexes {
        func decode<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
            (try? Data(contentsOf: ServedFixture.resources.appendingPathComponent(name))).flatMap { try? JSONDecoder().decode(type, from: $0) }
        }
        return ArchivalIndexes(centralFiles: decode(CentralFilesIndex.self, "central-files-index.json"),
                               volumeSources: decode(VolumeSourcesIndex.self, "volume-sources-index.json"),
                               claimants: decode(LotClaimantsIndex.self, "lot-claimants-index.json"))
    }

    func highlights(volumeId: String, documentId: String) -> [DocumentHighlightExport] {
        reference.envelope.highlights.filter { $0.volumeId == volumeId && $0.documentId == documentId }
    }

    func summary(id: UUID) -> GeneratedSummaryExport? { reference.envelope.summaries.first { $0.id == id } }

    /// A document's summaries newest first, the web's order where the app's fetch sets none.
    private func summaries(_ volumeId: String, _ documentId: String) -> [GeneratedSummaryExport] {
        reference.envelope.summaries.filter { $0.volumeId == volumeId && $0.documentId == documentId }.sorted(by: CollectionResearch.ranksAbove)
    }

    func headnoteSummaries(volumeId: String, documentId: String) -> [GeneratedSummaryExport] {
        summaries(volumeId, documentId).filter { $0.isHeadnoteDraft != true }
    }

    func summary(volumeId: String, documentId: String, promptId: UUID) -> GeneratedSummaryExport? {
        summaries(volumeId, documentId).first { $0.promptId == promptId }
    }

    /// `ZoteroJSONExporter.fetchTagsAndNotes`'s tags.
    func zoteroTags(volumeId: String, documentId: String) -> [String] {
        let names = Dictionary(reference.envelope.tags.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        var tags = Set(reference.envelope.tagAssignments.filter { $0.volumeId == volumeId && $0.documentId == documentId }.compactMap { names[$0.tagId] })
        for note in reference.envelope.notes where note.volumeId == volumeId && note.documentId == documentId {
            tags.formUnion(note.userTagIds.compactMap { names[$0] })
        }
        return tags.sorted()
    }

    func userTags() -> [UserTagExport] { reference.envelope.tags }
    func tagAssignments() -> [DocumentTagAssignmentExport] { reference.envelope.tagAssignments }
    func smartDocumentRefs() async throws -> [SmartCollectionDocumentRef] { [] }
    func prepareVolumesForExport(_ volumeIds: Set<String>) async {}
    func fetchAbsentFigureImages(_ images: [FigureImageName]) async {}

    func generateSummaries(for documents: [CollectionExportDocument], promptId: UUID,
                           bodyTexts: [String: String]) async throws -> [String: String] {
        var result: [String: String] = [:]
        for document in documents {
            guard let stored = summary(volumeId: document.volumeId, documentId: document.documentId, promptId: promptId) else {
                throw ExportError.renderingFailed
            }
            result["\(document.volumeId)/\(document.documentId)"] = stored.responseText
        }
        return result
    }
}
