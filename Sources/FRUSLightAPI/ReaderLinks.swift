// GET /api/v1/volumes/{v}/documents/{d}/link?href=…: what a link in the reader's page leads to.
//
// The reader's page writes its links as `frusexplorer://` URLs (FRUSRenderNodeHTMLSerializer), and
// its host script posts each one to the browser app, which asks here what to do with it. Every
// decision is the kit's: the reader's lookups for a person or a glossary term, the bundled
// broken-refs index for an unresolved reference, and `FRUSURLScheme.resolveCrossRefTarget` for a
// cross-reference. Only the parse of the URL itself is the app's (`FRUSURLSchemeHandler.dispatch`,
// app code), and `ReaderLinkParse` mirrors it until the kit offers it.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// What a reader link leads to, by its kind. Fields that do not apply are left out.
public struct ReaderLinkTarget: Codable, Equatable, Sendable {
    /// A person from the volume's list of names: the fields the kit's `PersonEntry` gives.
    public struct Person: Codable, Equatable, Sendable {
        public var ref: String
        public var name: String
        public var description: String?
        public var role: String?
        public var eraText: String?
    }

    /// A term from the volume's list of abbreviations and terms.
    public struct Term: Codable, Equatable, Sendable {
        public var ref: String
        public var term: String
        public var definition: String?
    }

    /// Where a cross-reference lands: a document, and a note in it when the link names one.
    public struct Destination: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// The note's `xml:id`, for a link to a footnote.
        public var footnoteAnchor: String?
        /// The id of the note's entry in the page's list of footnotes, for the frame's fragment.
        public var footnoteElementId: String?
        /// The document's page on history.state.gov, for a volume this server cannot show.
        public var canonicalURL: String
    }

    /// The bundled broken-refs index's account of a reference that resolves nowhere: the kit's
    /// `BrokenRefInfo`, written here as the server writes the kit's other types.
    public struct BrokenReference: Codable, Equatable, Sendable {
        /// The verbatim target, such as `#pg_700`.
        public var target: String
        /// `unknownPage`, `unknownAnchor`, `unknownVolume`, `malformedTarget` or `emptyTarget`.
        public var reason: String
        public var resolvedVolume: String?
        public var resolvedAnchor: String?
    }

    /// The destination's volume, as this server holds it; absent for a volume outside the catalogue.
    public struct DestinationVolume: Codable, Equatable, Sendable {
        public var title: String
        public var teiAvailable: Bool
        public var indexed: Bool
    }

    /// `person`, `gloss`, `document`, `page`, `external`, `unresolved` or `brokenReference`.
    public var kind: String
    /// The link, as the page wrote it.
    public var href: String
    /// The person or term the link names, as decoded; for `person` and `gloss`.
    public var ref: String?
    /// The volume's entry for it; absent when the volume's list has none.
    public var person: Person?
    public var term: Term?
    /// The reference's target, as the TEI gives it; for `document`, `page`, `unresolved` and
    /// `brokenReference`.
    public var target: String?
    public var destination: Destination?
    /// Whether the destination is a note in the document the link is in, which the reader shows in
    /// place, as the app does.
    public var inPlace: Bool?
    public var volume: DestinationVolume?
    /// The page a page reference names, and its volume; for `page`.
    public var page: Int?
    public var pageVolumeId: String?
    /// For `external`.
    public var url: String?
    /// The bundled index's account of an unresolved reference; for `brokenReference`, when it has one.
    public var brokenReference: BrokenReference?
}

extension ReaderLinkTarget: ResponseEncodable {}

/// A reader link, parsed as `FRUSURLSchemeHandler.dispatch(url:)` parses it. That is app code, so
/// this mirrors it until the kit offers the parse (upstream, FRUS-Explorer: `FRUSURLScheme`'s
/// `readerLink(from:)`); every decision after it is the kit's.
enum ReaderLinkParse: Equatable {
    /// The longest link the route takes, in UTF-8 bytes: far beyond any the kit writes.
    static let maximumLength = 2_048

    case person(ref: String)
    case gloss(ref: String)
    case crossReference(target: String, volumeId: String?, citing: PageCitationHint?)
    case brokenReference(target: String)

    /// Nil for another scheme, another host, or no first part. As in the app, the path's parts are
    /// percent-decoded twice, `URL.pathComponents` decoding them once, except a broken reference's
    /// target, which is decoded once: its encoding is strict, and a second pass would corrupt a
    /// literal `%`.
    init?(_ href: String) {
        guard let url = URL(string: href), url.scheme == "frusexplorer" else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        let parts = components.map { $0.removingPercentEncoding ?? $0 }
        switch url.host {
        case "person":
            guard let ref = parts.first else { return nil }
            self = .person(ref: ref)
        case "gloss":
            guard let ref = parts.first else { return nil }
            self = .gloss(ref: ref)
        case "doc":
            guard let target = parts.first else { return nil }
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            self = .crossReference(target: target, volumeId: parts.count >= 2 ? parts[1] : nil,
                                   citing: PageCitationHint(queryItems: query))
        case "brokenref":
            guard let target = components.first else { return nil }
            self = .brokenReference(target: target)
        default:
            return nil
        }
    }
}

enum ReaderLinkRoutes {
    static func add(to router: Router<BasicRequestContext>, state: ServerState, reader: ReaderService,
                    resources: ServerResources) {
        router.get("/api/v1/volumes/:volumeId/documents/:documentId/link") { request, context -> ReaderLinkTarget in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["href"])
            guard let href = try query.single("href") else {
                throw APIProblem.invalidParameter("href", "is required: a link from the reader's page")
            }
            // A reader link's target is a few dozen characters; a longer one is refused before any
            // parse, so no request can make the kit's target patterns work on a long input.
            guard href.utf8.count <= ReaderLinkParse.maximumLength else {
                throw APIProblem.invalidParameter("href", "is longer than a reader link can be")
            }
            guard let link = ReaderLinkParse(href) else {
                throw APIProblem.invalidParameter("href", "must be a frusexplorer:// person, gloss, doc or brokenref link")
            }
            let volumeId = try context.parameters.require("volumeId")
            let documentId = try context.parameters.require("documentId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            var target = ReaderLinkTarget(kind: "", href: href)
            switch link {
            case .person(let ref):
                target.kind = "person"
                target.ref = ref
                target.person = try await reader.volume(volumeId).lookups.personsByRef[ref].map {
                    .init(ref: $0.ref, name: $0.name, description: $0.description, role: $0.role, eraText: $0.eraText)
                }
            case .gloss(let ref):
                target.kind = "gloss"
                target.ref = ref
                target.term = try await reader.volume(volumeId).lookups.termsByRef[ref].map {
                    .init(ref: $0.ref, term: $0.term, definition: $0.definition)
                }
            case .brokenReference(let raw):
                target.kind = "brokenReference"
                target.target = raw
                target.brokenReference = resources.brokenRefs.degradableInfo(sourceVolume: volumeId, rawTarget: raw).map {
                    .init(target: $0.target, reason: $0.reason, resolvedVolume: $0.resolvedVolume, resolvedAnchor: $0.resolvedAnchor)
                }
            case .crossReference(let raw, let hrefVolume, _):
                target.target = raw
                // The app resolves with the link's own volume, then falls back to the one it is in.
                switch FRUSURLScheme.resolveCrossRefTarget(raw, volumeId: hrefVolume) {
                case .document(let otherVolume, let otherDocument):
                    target.kind = "document"
                    try await land(&target, volumeId: otherVolume ?? volumeId, documentId: otherDocument, anchor: nil,
                                   from: (volumeId, documentId), state: state, reader: reader, resources: resources)
                case .footnote(let otherVolume, let otherDocument, let anchor):
                    target.kind = "document"
                    try await land(&target, volumeId: otherVolume ?? volumeId, documentId: otherDocument, anchor: anchor,
                                   from: (volumeId, documentId), state: state, reader: reader, resources: resources)
                case .page(let otherVolume, let page):
                    // Which document holds a page is the index's page ranges, through the kit's
                    // PageRangeStore, whose open is not yet immutable; until it is, the reader says so.
                    target.kind = "page"
                    target.page = page
                    target.pageVolumeId = otherVolume ?? volumeId
                case .external(let url):
                    target.kind = "external"
                    target.url = url.absoluteString
                case .unresolved:
                    target.kind = "unresolved"
                }
            }
            return target
        }
    }

    /// Fills in a cross-reference's destination: where it lands, whether that is a note in the
    /// document the link is in, and what this server holds of the destination's volume.
    private static func land(_ target: inout ReaderLinkTarget, volumeId: String, documentId: String, anchor: String?,
                             from origin: (volumeId: String, documentId: String), state: ServerState,
                             reader: ReaderService, resources: ServerResources) async throws {
        // The kit's key for a note, and the prefix its serializer gives the note's entry in the list
        // of footnotes (FRUSRenderNodeHTMLSerializer), so the frame's fragment lands on it.
        target.destination = .init(
            volumeId: volumeId, documentId: documentId, footnoteAnchor: anchor,
            footnoteElementId: anchor.map { "fnote-" + FRUSRenderNode.footnoteDOMKey(id: $0, sequentialNumber: 0) },
            canonicalURL: FRUSCanonicalURL.string(volumeId: volumeId, documentId: documentId))
        target.inPlace = anchor != nil && volumeId == origin.volumeId && documentId == origin.documentId
        if let entry = resources.volume(volumeId) {
            let indexed = (await state.index?.documentsByVolume[volumeId] ?? 0) > 0
            target.volume = .init(title: entry.title,
                                  teiAvailable: ReaderService.teiFile(for: volumeId, in: reader.volumesDirectory) != nil,
                                  indexed: indexed)
        }
    }
}
