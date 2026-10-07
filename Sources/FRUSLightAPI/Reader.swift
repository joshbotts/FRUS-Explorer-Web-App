// The reader: GET /api/v1/volumes/{v}/documents/{d}/html, the document's page rendered from the
// mounted TEI by FRUSCoreKit, its figures at /api/v1/volumes/{v}/figures/{file}, and the page's
// host script at /reader/host.js.
//
// The path is check 4's (Tests/FRUSParity/RenderParity.swift, `fullParsePass`): one
// `parseVolumeFull` of the volume, whose persons and glossary terms make the reader's lookups,
// then the reader's converter with the app's broken-refs index, and the reader's serializer, here
// with the server's own figure addresses (upstream #1575's `reader(figureURL:)`). The page is the
// kit's `ReaderPage.build`, which the app's `HTMLTemplate.build` forwards to. When an index is
// served, its effective classification of the document reshapes the parse first, as the app's
// reader does. The golden HTML was made by the Mac reader, and FRUSParityTests compares every row
// through this route. The reader needs no index, so it answers before an import and while search
// is unavailable (docs/SPEC.md, Upgrades).

import FRUSCoreKit
import Foundation
import Hummingbird

/// Parses each volume's TEI once and keeps the most recent few, so a reader paging through a
/// volume parses it once. A volume whose file changes, by size or modification time, is parsed
/// again; requests for a volume being parsed wait for that parse.
public actor ReaderService {
    /// One volume's documents, the reader's lookups and the volume's structure, from one parse.
    struct ParsedVolume: Sendable {
        let signature: FileSignature
        let documents: [String: FRUSDocumentAST]
        let lookups: ReaderLookups
        /// Its front matter, chapters and back matter, as the parse found them in the TEI.
        let structure: [VolumeSection]
    }

    struct FileSignature: Equatable, Sendable {
        let size: Int
        let modified: Date?
    }

    /// A document parsed from its volume, and the volume's lookups.
    public struct Parsed: Sendable {
        public let ast: FRUSDocumentAST
        public let lookups: ReaderLookups
    }

    /// What a request asks for: the whole page, in an appearance and a text size, or the
    /// fragment its body holds.
    public enum Part: Sendable, Equatable {
        case page(ReaderAppearance, TextSizePreference)
        case body
    }

    /// A document's reader HTML, and the kit's rendering version of its text.
    public struct Rendered: Sendable {
        public let html: String
        public let renderingVersion: String
    }

    let volumesDirectory: URL
    let resources: ServerResources
    /// How many parsed volumes are kept. A large volume's parse holds tens of megabytes.
    let capacity: Int
    private var parsed: [String: ParsedVolume] = [:]
    /// Volume ids in `parsed`, least recently used first.
    private var recency: [String] = []
    private var parsing: [String: Task<ParsedVolume, any Error>] = [:]
    /// How many parses have started.
    private(set) var parseCount = 0

    public init(volumesDirectory: URL, resources: ServerResources, capacity: Int = 4) {
        self.volumesDirectory = volumesDirectory
        self.resources = resources
        self.capacity = max(1, capacity)
    }

    /// `<volumeId>.xml` in `directory`, when it is there. Callers pass a manifest id only, so
    /// nothing from a request is joined into a path.
    nonisolated static func teiFile(for volumeId: String, in directory: URL) -> URL? {
        let url = directory.appendingPathComponent("\(volumeId).xml")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
        return url
    }

    /// One volume, parsed. Throws an `APIProblem` for an unknown volume, a volume whose TEI is not
    /// mounted, or TEI that will not parse.
    func volume(_ volumeId: String) async throws -> ParsedVolume {
        guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
        guard let url = Self.teiFile(for: volumeId, in: volumesDirectory) else {
            throw APIProblem(.notFound, code: "TEI_NOT_AVAILABLE",
                             detail: "\(volumeId).xml is not in the TEI folder, \(volumesDirectory.path). Mount a folder of TEI volumes there, such as FRUS Explorer's own or a clone of HistoryAtState/frus's volumes/.")
        }
        return try await parsedVolume(volumeId, at: url)
    }

    /// One document, parsed. Throws an `APIProblem` for an unknown volume or document, a volume
    /// whose TEI is not mounted, or TEI that will not parse.
    public func document(volume volumeId: String, document documentId: String) async throws -> Parsed {
        let volume = try await volume(volumeId)
        guard let ast = volume.documents[documentId] else {
            throw APIProblem(.notFound, code: "DOCUMENT_NOT_FOUND", detail: "\(volumeId) has no document \(documentId).")
        }
        return Parsed(ast: ast, lookups: volume.lookups)
    }

    /// One document's body, with no classification applied.
    public func body(volume volumeId: String, document documentId: String) async throws -> Rendered {
        Self.render(try await document(volume: volumeId, document: documentId), volume: volumeId,
                    classification: nil, part: .body, brokenRefs: resources.brokenRefs)
    }

    /// The reader's converter, as `ReaderRenderer.html` in FRUSParity calls it, then its serializer
    /// with the server's figure addresses, alone or in the kit's page. `classification`, the
    /// index's effective classification of the document, reshapes the parse first, as the app's
    /// reader applies it (`DocumentViewModel.load`); nil leaves the parse as it is.
    nonisolated static func render(_ parsed: Parsed, volume: String, classification: Bool?, part: Part,
                                   brokenRefs: BrokenRefsIndex) -> Rendered {
        var ast = parsed.ast
        if let classification { ast = ast.applyingClassificationOverride(isEditorialNote: classification) }
        var converter = ASTToRenderNodeConverter(readerOf: volume, lookups: parsed.lookups, brokenRefs: brokenRefs)
        let model = converter.convert(ast)
        let serializer = FRUSRenderNodeHTMLSerializer.reader(figureURL: ReaderRoutes.figureURL(for:))
        let html: String
        switch part {
        case .body:
            html = serializer.serialize(model)
        case .page(let appearance, let textSize):
            html = ReaderPage.build(model: model, appearance: appearance, textSize: textSize,
                                    serializer: serializer, head: ReaderRoutes.pageHead)
        }
        return Rendered(html: html, renderingVersion: ASTToRenderNodeConverter.renderingVersion(for: model))
    }

    private func parsedVolume(_ volumeId: String, at url: URL) async throws -> ParsedVolume {
        let signature = Self.signature(of: url)
        if let cached = parsed[volumeId], cached.signature == signature {
            touch(volumeId)
            return cached
        }
        if let running = parsing[volumeId] { return try await running.value }
        parseCount += 1
        let task = Task<ParsedVolume, any Error> {
            let parse: VolumeFullParseResult
            do {
                parse = try await FRUSDocumentParser().parseVolumeFull(volumeURL: url)
            } catch {
                throw APIProblem(.internalServerError, code: "TEI_UNREADABLE", detail: "\(volumeId).xml could not be parsed: \(error)")
            }
            var documents: [String: FRUSDocumentAST] = [:]
            for ast in parse.documents where documents[ast.documentId] == nil { documents[ast.documentId] = ast }
            return ParsedVolume(signature: signature, documents: documents,
                                lookups: ReaderLookups(persons: parse.persons, terms: parse.terms),
                                structure: parse.structureSections)
        }
        parsing[volumeId] = task
        defer { parsing[volumeId] = nil }
        let volume = try await task.value
        parsed[volumeId] = volume
        touch(volumeId)
        while recency.count > capacity { parsed[recency.removeFirst()] = nil }
        return volume
    }

    private func touch(_ volumeId: String) {
        recency.removeAll { $0 == volumeId }
        recency.append(volumeId)
    }

    nonisolated static func signature(of url: URL) -> FileSignature {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return FileSignature(size: (attributes?[.size] as? NSNumber)?.intValue ?? -1,
                             modified: attributes?[.modificationDate] as? Date)
    }
}

enum ReaderRoutes {
    /// `HTTPField.Name`, which Hummingbird does not re-export as it does `HTTPFields`.
    typealias HeaderName = HTTPFields.Element.Name

    static let renderingVersionHeader = HeaderName("X-FRUS-Rendering-Version")!

    /// What the page adds to the kit's head: the host script, which runs after the body parses.
    static let pageHead = "<script src=\"/reader/host.js\" defer></script>\n"

    /// The one inline script the reader's markup holds: a figure image's `onerror`, which shows
    /// its placeholder (`FRUSRenderNodeHTMLSerializer.figureImageHTML`), allowed by its SHA-256.
    static let figureErrorHandler = "this.parentNode.classList.add('missing')"
    static let figureErrorHandlerHash = "sha256-O4LSTB5IvR0PUzEjwmFCMZeO+YGjgMu2Q5Kea551jqY="

    /// The page loads nothing from elsewhere, runs only the host script and the figure handler,
    /// and can be framed only by the server's own pages.
    static let pagePolicy = [
        "default-src 'none'", "style-src 'unsafe-inline'", "img-src 'self' data:", "script-src 'self'",
        "script-src-attr 'unsafe-hashes' '\(figureErrorHandlerHash)'", "base-uri 'none'", "form-action 'none'",
        "frame-ancestors 'self'",
    ].joined(separator: "; ")

    /// The fragment alone is not meant to be opened: it runs no script at all.
    static let bodyPolicy = "default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'self'"

    static let commonHeaders: HTTPFields = [
        .xContentTypeOptions: "nosniff",
        HeaderName("Referrer-Policy")!: "no-referrer",
    ]

    /// Where the server serves a figure's image, or nil, and the placeholder, for a name that is
    /// no file name or a volume id that could not be one path component.
    @Sendable static func figureURL(for image: FigureImageName) -> URL? {
        guard let volumeId = image.volumeId, let file = image.fileName,
              FRUSURLScheme.isSafeComponent(volumeId), FRUSURLScheme.isSafeComponent(file) else { return nil }
        var components = URLComponents()
        components.path = "/api/v1/volumes/\(volumeId)/figures/\(file)"
        return components.url
    }

    static func add(to router: Router<BasicRequestContext>, reader: ReaderService, provider: ServedIndexProvider,
                    resources: ServerResources) {
        router.get("/api/v1/volumes/:volumeId/documents/:documentId/html") { request, context -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["part", "textSize", "colorScheme"])
            let textSize = try query.choice("textSize", among: TextSizePreference.allCases) ?? .medium
            let appearance = try query.choice("colorScheme", among: ReaderAppearance.allCases) ?? .light
            let part: ReaderService.Part
            switch try query.single("part") {
            case nil, "page"?: part = .page(appearance, textSize)
            case "body"?: part = .body
            case let other?: throw APIProblem.invalidParameter("part", "must be page or body, not \(other)")
            }
            let volumeId = try context.parameters.require("volumeId")
            let documentId = try context.parameters.require("documentId")
            let parsed = try await reader.document(volume: volumeId, document: documentId)
            // The reader works without search: when no stack can be had, the parse stays as it is.
            let served = try? await provider.servedIfReady()
            let classification = try? await served?.pipeline.effectiveIsEditorialNote(volumeId: volumeId, documentId: documentId)
            let rendered = ReaderService.render(parsed, volume: volumeId, classification: classification ?? nil,
                                                part: part, brokenRefs: resources.brokenRefs)
            var headers = commonHeaders
            headers[.contentSecurityPolicy] = part == .body ? bodyPolicy : pagePolicy
            headers[renderingVersionHeader] = rendered.renderingVersion
            headers[.eTag] = "W/\"\(rendered.renderingVersion)-\(fnv1a64(rendered.html))\""
            headers[.cacheControl] = "no-cache"
            if let tags = request.headers[.ifNoneMatch], tags.split(separator: ",").contains(where: {
                $0.trimmingCharacters(in: .whitespaces) == headers[.eTag] }) {
                return Response(status: .notModified, headers: headers)
            }
            headers[.contentType] = "text/html; charset=utf-8"
            return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: rendered.html)))
        }

        router.get("/api/v1/volumes/:volumeId/figures/:file") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let volumeId = try context.parameters.require("volumeId")
            let raw = try context.parameters.require("file")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            guard let file = raw.removingPercentEncoding, FRUSURLScheme.isSafeComponent(file), file.hasSuffix(".png"),
                  let image = figureFile(volumeId: volumeId, file: file, in: reader.volumesDirectory),
                  let data = try? Data(contentsOf: image) else {
                throw APIProblem(.notFound, code: "FIGURE_NOT_FOUND",
                                 detail: "\(volumeId) has no figure image \(raw) in the TEI folder. Figure images come with FRUS Explorer's own folder of volumes; a clone of HistoryAtState/frus has none.")
            }
            var headers = commonHeaders
            headers[.contentType] = "image/png"
            headers[.cacheControl] = "max-age=3600"
            return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(bytes: data)))
        }

        router.get("/reader/host.js") { _, _ -> Response in
            var headers = commonHeaders
            headers[.contentType] = "text/javascript; charset=utf-8"
            headers[.cacheControl] = "no-cache"
            return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: ReaderHostScript.source)))
        }
    }

    /// `<volumeId>.figures/<file>` in the TEI folder, where FRUS Explorer keeps a volume's figure
    /// images, when it is a file there. Both parts are single path components by then.
    static func figureFile(volumeId: String, file: String, in volumesDirectory: URL) -> URL? {
        let url = volumesDirectory.appendingPathComponent("\(volumeId).figures", isDirectory: true).appendingPathComponent(file)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
        return url
    }

    /// FNV-1a over the page's UTF-8 bytes, for its ETag: cheap, and the same in every process.
    static func fnv1a64(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
