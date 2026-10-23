// GET /api/v1/volumes/{v}/documents/{d}/link?href=…: what a link in the reader's page leads to.
//
// The reader's page writes its links as `frusexplorer://` URLs (FRUSRenderNodeHTMLSerializer), and
// its host script posts each one to the browser app, which asks here what to do with it. The
// answers are the kit's: `FRUSURLScheme.readerLink(from:)` reads the link as the app's handler does
// (joshbotts/FRUS-Explorer#1579), the reader's lookups give a person or a glossary term, the
// bundled broken-refs index an unresolved reference, `FRUSURLScheme.resolveCrossRefTarget` a
// cross-reference, `PageLink` where a link to a printed page goes and `WholeVolumeLink` where a
// link that opens a volume goes (joshbotts/FRUS-Explorer#1784), and, over the served index,
// `PageRangeStore` a page's document and `PersonMentionStore` a person's mentions. Only the choice
// between a person's two counts is the app's, and `mentionCount` mirrors it.

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

    /// `person`, `gloss`, `document`, `page`, `volume`, `external`, `unresolved` or `brokenReference`.
    public var kind: String
    /// The link, as the page wrote it.
    public var href: String
    /// The person or term the link names, as decoded; for `person` and `gloss`.
    public var ref: String?
    /// The volume's entry for it; absent when the volume's list has none.
    public var person: Person?
    /// For a person the volume's list has, how many indexed documents mention them; absent while no
    /// index is served.
    public var mentionCount: Int?
    public var term: Term?
    /// The reference's target, as the TEI gives it; for `document`, `page`, `volume`, `unresolved`
    /// and `brokenReference`.
    public var target: String?
    public var destination: Destination?
    /// Whether the destination is a note in the document the link is in, which the reader shows in
    /// place, as the app does.
    public var inPlace: Bool?
    public var volume: DestinationVolume?
    /// The page a page reference names, and its volume; for `page`. Its `destination` is the
    /// document the kit's `PageLink` lands on: the one the served index's page ranges place on the
    /// page, for a volume the index holds, else the one the bundled page map names there. Where
    /// `PageLink` opens the volume instead, `volumeId` names it.
    public var page: Int?
    public var pageVolumeId: String?
    /// The volume the link opens: for `volume`, the one a reference to a whole volume names, as its
    /// target gives it; for `page`, the page's, when the kit's `PageLink` can name no document on
    /// the page without the volume. Its `volume` is what this server holds of it, absent for a
    /// volume outside the catalogue.
    public var volumeId: String?
    /// Where the volume `volumeId` names opens, as the kit's `WholeVolumeLink` sends it: `browse`,
    /// its page in Browse, for a volume the catalogue holds, or `web`, its page on history.state.gov,
    /// `url`; absent when the id can name neither.
    public var wholeVolumeLink: String?
    /// For `external`, the link's address; for `volume`, and for `page` when it opens the volume, the
    /// volume's page on history.state.gov (`FRUSCanonicalURL.volumeURL`), which the app opens for a
    /// volume outside its catalogue.
    public var url: String?
    /// The bundled index's account of an unresolved reference; for `brokenReference`, when it has one.
    public var brokenReference: BrokenReference?
}

extension ReaderLinkTarget: ResponseEncodable {}

/// The longest link the route takes, in UTF-8 bytes: far beyond any the kit writes.
let readerLinkMaximumLength = 2_048

enum ReaderLinkRoutes {
    /// The prefix the kit's serializer gives a note's entry in the page's list of footnotes
    /// (`FRUSRenderNodeHTMLSerializer`), before the note's key; the kit's `FootnoteLanding` script
    /// adds it to the key it is given.
    static let footnoteEntryPrefix = "fnote-"

    static func add(to router: Router<APIRequestContext>, state: ServerState, provider: ServedIndexProvider,
                    reader: ReaderService, resources: ServerResources) {
        router.get("/api/v1/volumes/:volumeId/documents/:documentId/link") { request, context -> ReaderLinkTarget in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["href"])
            guard let href = try query.single("href") else {
                throw APIProblem.invalidParameter("href", "is required: a link from the reader's page")
            }
            // A reader link's target is a few dozen characters; a longer one is refused before any
            // parse, so no request can make the kit's target patterns work on a long input.
            guard href.utf8.count <= readerLinkMaximumLength else {
                throw APIProblem.invalidParameter("href", "is longer than a reader link can be")
            }
            guard let url = URL(string: href), let link = FRUSURLScheme.readerLink(from: url) else {
                throw APIProblem.invalidParameter("href", "must be a frusexplorer:// person, gloss, doc or brokenref link")
            }
            let volumeId = try context.parameters.require("volumeId")
            let documentId = try context.parameters.require("documentId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            var target = ReaderLinkTarget(kind: "", href: href)
            // The links work without an index; what only the index knows is left out without one.
            let served = try? await provider.servedIfReady()
            switch link {
            case .person(let ref):
                target.kind = "person"
                target.ref = ref
                if let person = try await reader.volume(volumeId).lookups.personsByRef[ref] {
                    target.person = .init(ref: person.ref, name: person.name, description: person.description,
                                          role: person.role, eraText: person.eraText)
                    if let served { target.mentionCount = await mentionCount(of: person.ref, in: volumeId, persons: served.persons) }
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
            case .crossReference(let raw, let hrefVolume, let citing):
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
                    // Where the kit's `PageLink` sends a link to a printed page, as both of the app's
                    // readers ask it, with the volumes the served index holds as the device's: for a
                    // volume it holds, the document its page ranges place on the page, of several the
                    // one the footnote around the link names (`citing`); else the document the
                    // bundled page map names there; else, for a volume it does not hold, the volume,
                    // as a link to the whole volume opens it. A page of a volume it holds that
                    // neither names leads nowhere.
                    let pageVolume = otherVolume ?? volumeId
                    target.kind = "page"
                    target.page = page
                    target.pageVolumeId = pageVolume
                    let held = (served?.corpus.documentsByVolume[pageVolume] ?? 0) > 0
                    switch await PageLink.destination(page: page, volumeId: pageVolume, citing: citing, onDevice: held,
                                                      store: served?.pages, map: { resources.citedPages }) {
                    case .document(let landingVolume, let landingDocument)?:
                        try await land(&target, volumeId: landingVolume, documentId: landingDocument, anchor: nil,
                                       from: (volumeId, documentId), state: state, reader: reader, resources: resources)
                    case .volume(let landingVolume, _)?:
                        await openVolume(landingVolume, into: &target, state: state, reader: reader, resources: resources)
                    case nil:
                        target.volume = await describe(pageVolume, state: state, reader: reader, resources: resources)
                    }
                case .volume(let otherVolume):
                    // A whole volume (joshbotts/FRUS-Explorer#1603).
                    target.kind = "volume"
                    await openVolume(otherVolume, into: &target, state: state, reader: reader, resources: resources)
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
            footnoteElementId: anchor.map { footnoteEntryPrefix + FRUSRenderNode.footnoteDOMKey(id: $0, sequentialNumber: 0) },
            canonicalURL: FRUSCanonicalURL.string(volumeId: volumeId, documentId: documentId))
        target.inPlace = anchor != nil && volumeId == origin.volumeId && documentId == origin.documentId
        target.volume = await describe(volumeId, state: state, reader: reader, resources: resources)
    }

    /// Fills in where a link that opens a volume goes, as the kit's `WholeVolumeLink` sends it: the
    /// volume's page in Browse when the catalogue holds it, else its page on history.state.gov,
    /// whose address the kit gives (`FRUSCanonicalURL.volumeURL`), with what this server holds of it.
    private static func openVolume(_ volumeId: String, into target: inout ReaderLinkTarget, state: ServerState,
                                   reader: ReaderService, resources: ServerResources) async {
        target.volumeId = volumeId
        target.volume = await describe(volumeId, state: state, reader: reader, resources: resources)
        target.url = FRUSCanonicalURL.volumeURL(volumeId: volumeId)?.absoluteString
        switch WholeVolumeLink.destination(for: volumeId, inCatalogue: resources.volume(volumeId) != nil) {
        case .browse?:
            target.wholeVolumeLink = "browse"
        case .web(let url)?:
            target.wholeVolumeLink = "web"
            target.url = url.absoluteString
        case nil:
            break
        }
    }

    /// What this server holds of a volume; nil for one outside the catalogue.
    private static func describe(_ volumeId: String, state: ServerState, reader: ReaderService,
                                 resources: ServerResources) async -> ReaderLinkTarget.DestinationVolume? {
        guard let entry = resources.volume(volumeId) else { return nil }
        let indexed = (await state.index?.documentsByVolume[volumeId] ?? 0) > 0
        return .init(title: entry.title,
                     teiAvailable: ReaderService.teiFile(for: volumeId, in: reader.volumesDirectory) != nil,
                     indexed: indexed)
    }

    /// How many indexed documents mention a person, as the app's person card counts them
    /// (`DocumentViewModel.loadPersonMentionCount`, app code, which this mirrors): the count of the
    /// person's rollup across the corpus when they belong to one, else their documents in this
    /// volume. Each count is the kit's (`PersonMentionStore`); 0 when the index has neither.
    static func mentionCount(of ref: String, in volumeId: String, persons: PersonMentionStore) async -> Int {
        if let rollup = try? await persons.rollupEntry(forVolumeId: volumeId, ref: ref) { return rollup.mentionCount }
        return (try? await persons.documentCount(volumeId: volumeId, ref: ref)) ?? 0
    }
}
