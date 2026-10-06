// GET /api/v1/volumes/{v}/documents/{d}/html: the reader's HTML, rendered from the mounted TEI by FRUSCoreKit.
//
// The path is check 4's (Tests/FRUSParity/RenderParity.swift, `fullParsePass`): one
// `parseVolumeFull` of the volume, whose persons and glossary terms make the reader's lookups,
// then the reader's converter with the app's broken-refs index, and the reader's serializer. The
// golden HTML was made by the Mac reader, and FRUSParityTests compares every row through this
// route. The reader needs no index, so it answers before an import and while search is
// unavailable (docs/SPEC.md, Upgrades).

import FRUSCoreKit
import Foundation
import Hummingbird

/// Parses each volume's TEI once and keeps the most recent few, so a reader paging through a
/// volume parses it once. A volume whose file changes, by size or modification time, is parsed
/// again; requests for a volume being parsed wait for that parse.
public actor ReaderService {
    /// One volume's documents and the reader's lookups, from one parse.
    struct ParsedVolume: Sendable {
        let signature: FileSignature
        let documents: [String: FRUSDocumentAST]
        let lookups: ReaderLookups
    }

    struct FileSignature: Equatable, Sendable {
        let size: Int
        let modified: Date?
    }

    /// A document's reader HTML, and the kit's rendering version of its text.
    public struct RenderedBody: Sendable {
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

    /// The reader's HTML for one document: the fragment the Mac's `HTMLTemplate.build` writes in
    /// the page's body. Throws an `APIProblem` for an unknown volume or document, a volume whose
    /// TEI is not mounted, or TEI that will not parse.
    public func body(volume volumeId: String, document documentId: String) async throws -> RenderedBody {
        guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
        guard let url = Self.teiFile(for: volumeId, in: volumesDirectory) else {
            throw APIProblem(.notFound, code: "TEI_NOT_AVAILABLE",
                             detail: "\(volumeId).xml is not in the TEI folder, \(volumesDirectory.path). Mount a folder of TEI volumes there, such as FRUS Explorer's own or a clone of HistoryAtState/frus's volumes/.")
        }
        let volume = try await parsedVolume(volumeId, at: url)
        guard let ast = volume.documents[documentId] else {
            throw APIProblem(.notFound, code: "DOCUMENT_NOT_FOUND", detail: "\(volumeId) has no document \(documentId).")
        }
        return Self.render(ast, volume: volumeId, lookups: volume.lookups, brokenRefs: resources.brokenRefs)
    }

    /// The reader's converter and serializer, as `ReaderRenderer.html` in FRUSParity calls them.
    nonisolated static func render(_ ast: FRUSDocumentAST, volume: String, lookups: ReaderLookups, brokenRefs: BrokenRefsIndex) -> RenderedBody {
        var converter = ASTToRenderNodeConverter(readerOf: volume, lookups: lookups, brokenRefs: brokenRefs)
        let model = converter.convert(ast)
        return RenderedBody(html: FRUSRenderNodeHTMLSerializer.reader.serialize(model),
                            renderingVersion: ASTToRenderNodeConverter.renderingVersion(for: model))
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
                                lookups: ReaderLookups(persons: parse.persons, terms: parse.terms))
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
    /// The reader's HTML is the app's own markup around escaped TEI text. A fragment opened on its
    /// own runs no script, loads nothing from elsewhere, and cannot be framed by another site.
    static let securityHeaders: HTTPFields = [
        .contentSecurityPolicy: "default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'self'",
        .xContentTypeOptions: "nosniff",
        HeaderName("Referrer-Policy")!: "no-referrer",
    ]

    static let renderingVersionHeader = HeaderName("X-FRUS-Rendering-Version")!

    /// `HTTPField.Name`, which Hummingbird does not re-export as it does `HTTPFields`.
    typealias HeaderName = HTTPFields.Element.Name

    static func add(to router: Router<BasicRequestContext>, reader: ReaderService) {
        router.get("/api/v1/volumes/:volumeId/documents/:documentId/html") { request, context -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["part", "textSize", "colorScheme"])
            // The draft's appearance parameters are checked now; the body does not depend on them.
            _ = try query.choice("textSize", among: [TextSize.small, .medium, .large, .extraLarge])
            _ = try query.choice("colorScheme", among: [ColorScheme.light, .dark])
            switch try query.single("part") {
            case "body"?:
                break
            case nil:
                throw APIProblem(.notImplemented, code: "PAGE_NOT_AVAILABLE",
                                 detail: "This build serves the page's body only: ask for ?part=body. The full page, with the reader's styles, arrives in a later build.")
            case let part?:
                throw APIProblem.invalidParameter("part", "must be body, not \(part)")
            }
            let body = try await reader.body(volume: try context.parameters.require("volumeId"),
                                             document: try context.parameters.require("documentId"))
            var headers = securityHeaders
            headers[.contentType] = "text/html; charset=utf-8"
            headers[renderingVersionHeader] = body.renderingVersion
            return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: body.html)))
        }
    }

    /// The draft's `textSize` values, `TextSizePreference`'s raw values.
    enum TextSize: String { case small, medium, large, extraLarge }
    /// The draft's `colorScheme` values.
    enum ColorScheme: String { case light, dark }
}
