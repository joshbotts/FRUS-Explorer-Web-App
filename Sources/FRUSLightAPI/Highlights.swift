// /api/v1/me/highlights and a document's highlights (PLAN's S15c): the user's highlights, made as the
// app's reader makes one, from a selection's offsets, with the text and rendering version the kit
// takes from the page's own model; listed for a document in the order the app's reader draws them,
// each stale or not by the kit's rule; given another colour; and deleted, as a tap's Remove deletes
// one.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// One of the user's highlights, with the fields of the Mac's export (`DocumentHighlightExport`).
public struct Highlight: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var volumeId: String
    public var documentId: String
    /// UTF-16 offsets into the document's flat text, the first included and the last not.
    public var startOffset: Int
    public var endOffset: Int
    public var colorTag: String
    public var noteId: String?
    public var selectedText: String
    /// The kit's rendering version of the document's text when it was made.
    public var renderingVersion: String
    /// When it was made, as the store keeps dates.
    public var createdAt: String?
    /// In a document's list only: whether the document's text has changed since, by the kit's rule
    /// (`ReaderHighlight.isStale`). Absent when the server cannot render the document.
    public var isStale: Bool?

    init(_ record: HighlightRecord, currentVersion: String? = nil) {
        id = record.id
        volumeId = record.volumeId
        documentId = record.documentId
        startOffset = record.startOffset
        endOffset = record.endOffset
        colorTag = record.colorTag
        noteId = record.noteId
        selectedText = record.selectedText
        renderingVersion = record.renderingVersion
        createdAt = record.createdAt.map(UserStoreDate.text)
        isStale = currentVersion.map { ReaderHighlight.isStale(renderingVersion: record.renderingVersion, currentVersion: $0) }
    }
}

/// All the user's highlights, by volume and document.
public struct HighlightList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [Highlight]
}

/// A document's highlights, in the order the app's reader draws them, with the document's current
/// rendering version, which a new highlight's request names. The version is absent, and so is each
/// item's `isStale`, when the server cannot render the document: highlights are the user's, and may
/// name a document this server does not hold, as tags may.
public struct DocumentHighlights: Codable, Equatable, Sendable, ResponseEncodable {
    public var volumeId: String
    public var documentId: String
    public var renderingVersion: String?
    public var items: [Highlight]
}

enum HighlightRoutes {
    struct NewHighlight: Decodable {
        let startOffset: Int
        let endOffset: Int
        let colorTag: String
        /// The rendering version of the page the selection was made in.
        let renderingVersion: String
    }

    struct Recolor: Decodable { let colorTag: String }

    /// A document's page as the reader builds it: its model, its flat text's length in UTF-16 units
    /// and its rendering version.
    struct Page {
        let model: FRUSDocumentRenderModel
        let length: Int
        let renderingVersion: String
    }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    reader: ReaderService, provider: ServedIndexProvider) {
        let store = services.store
        let now = services.now

        me.get("highlights") { request, context -> HighlightList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let highlights = try await Blocking.run { try store.highlights(for: user.id) }
            return HighlightList(total: highlights.count, items: highlights.map { Highlight($0) })
        }
        me.get("highlights/:highlightId") { request, context -> Highlight in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("highlightId")
            guard let highlight = try await Blocking.run({ try store.highlight(id, of: user.id) }) else {
                throw problem(.highlightNotFound(id))
            }
            return Highlight(highlight)
        }
        // Another colour, the web's own: the app has no way to change one.
        me.patch("highlights/:highlightId") { request, context -> Highlight in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("highlightId")
            let body = try await JSONBody.decode(Recolor.self, from: request, fields: ["colorTag"])
            try checkColor(body.colorTag)
            return Highlight(try await stored { try store.recolorHighlight(id, to: body.colorTag, for: user.id) })
        }
        // A tap's Remove.
        me.delete("highlights/:highlightId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("highlightId")
            try await stored { try store.deleteHighlight(id, for: user.id) }
            return Response(status: .noContent)
        }

        let documentHighlights: RouterPath = "volumes/:volumeId/documents/:documentId/highlights"
        me.get(documentHighlights) { request, context -> DocumentHighlights in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try UserDataRoutes.document(context, resources: resources)
            let highlights = try await Blocking.run { try store.highlights(of: document, for: user.id) }
            let version: String?
            do {
                version = try await reader.renderingVersion(volume: document.volumeId, document: document.documentId)
            } catch let problem as APIProblem where ["TEI_NOT_AVAILABLE", "DOCUMENT_NOT_FOUND"].contains(problem.code) {
                // Highlights the server cannot judge, on a volume it does not hold or a document
                // its TEI lacks; anything else, a TEI that will not parse, is the server's problem.
                version = nil
            }
            return DocumentHighlights(volumeId: document.volumeId, documentId: document.documentId, renderingVersion: version,
                                      items: highlights.map { Highlight($0, currentVersion: version) })
        }
        // A colour chosen in the selection bar: a new highlight over the selection's offsets, its
        // text and version the kit's over the page's model, as the app's reader makes one
        // (`createWebKitHighlight`). Over text another highlight holds, it is another highlight, as
        // in the app.
        me.post(documentHighlights) { request, context -> EditedResponse<Highlight> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try UserDataRoutes.document(context, resources: resources)
            let body = try await JSONBody.decode(NewHighlight.self, from: request,
                                                 fields: ["startOffset", "endOffset", "colorTag", "renderingVersion"])
            try checkColor(body.colorTag)
            guard body.startOffset >= 0 else { throw invalidField("startOffset", "must be 0 or more, not \(body.startOffset).") }
            guard body.endOffset > body.startOffset else {
                throw invalidField("endOffset", "must be after startOffset, \(body.startOffset), not \(body.endOffset).")
            }
            let page = try await page(of: document, reader: reader, provider: provider, resources: resources)
            // Offsets name text in one version of the document: a page loaded before its TEI changed
            // would put them on other words.
            guard body.renderingVersion == page.renderingVersion else {
                throw APIProblem(.conflict, code: "DOCUMENT_CHANGED",
                                 detail: "renderingVersion: the document's text has changed since the page was loaded, from \(body.renderingVersion) to \(page.renderingVersion). Load it again and select once more.")
            }
            guard body.endOffset <= page.length else {
                throw invalidField("endOffset", "the document's text has \(page.length) characters, so a highlight ends at \(page.length) at most, not \(body.endOffset).")
            }
            let selectedText = flatTextExcerpt(from: page.model, start: body.startOffset, end: body.endOffset) ?? ""
            let highlight = try await Blocking.run {
                try store.createHighlight(in: document, start: body.startOffset, end: body.endOffset, colorTag: body.colorTag,
                                          selectedText: selectedText, renderingVersion: page.renderingVersion,
                                          for: user.id, at: now())
            }
            let location = context.basePath.prefixing("/api/v1/me/highlights/\(highlight.id)")
            return EditedResponse(status: .created, headers: [.location: location], response: Highlight(highlight))
        }
    }

    /// The document's page as the reader builds it, with the served index's classification, as the
    /// page's route builds it. Throws the reader's problems: a volume whose TEI is not mounted, a
    /// document not in it.
    static func page(of document: DocumentKey, reader: ReaderService, provider: ServedIndexProvider,
                     resources: ServerResources) async throws -> Page {
        let parsed = try await reader.document(volume: document.volumeId, document: document.documentId)
        let classification = await ReaderRoutes.classification(of: document.volumeId, document.documentId, provider: provider)
        let model = ReaderService.model(parsed, volume: document.volumeId, classification: classification,
                                        brokenRefs: resources.brokenRefs)
        return Page(model: model, length: buildFlatText(from: model).utf16.count,
                    renderingVersion: ASTToRenderNodeConverter.renderingVersion(for: model))
    }

    /// One of the four colours the app's selection bar offers, as `HighlightColor` names them.
    static func checkColor(_ colorTag: String) throws {
        guard HighlightColor(rawValue: colorTag) == nil else { return }
        let names = HighlightColor.allCases.map(\.rawValue)
        throw invalidField("colorTag", "\(colorTag) is not a highlight's colour, which is \(names.dropLast().joined(separator: ", ")) or \(names.last ?? "").")
    }

    static func invalidField(_ name: String, _ detail: String) -> APIProblem {
        APIProblem(.badRequest, code: "INVALID_FIELD", detail: "\(name): \(detail)")
    }

    /// Runs a store call off the cooperative pool, its refusals as problems.
    private static func stored<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        do {
            return try await Blocking.run(work)
        } catch let error as HighlightStoreError {
            throw problem(error)
        }
    }

    static func problem(_ error: HighlightStoreError) -> APIProblem {
        switch error {
        case .highlightNotFound(let id):
            APIProblem(.notFound, code: "HIGHLIGHT_NOT_FOUND", detail: "You have no highlight with the id \(id).")
        }
    }
}
