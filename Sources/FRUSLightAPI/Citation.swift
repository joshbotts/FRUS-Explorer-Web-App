// GET /api/v1/volumes/{v}/documents/{d}/citation: the kit's citation of a document, as the reader's Cite shows it.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// A document's citation in one style, made by the kit's formatter as the app's Cite makes it.
///
/// The number is the index's, which the indexer writes as the TEI's printed number or the one the
/// heading names, as the Mac's citation popover takes it; for a row with none, or with no index,
/// it is the TEI's printed number, as the reader takes it; failing both, the number the id spells
/// (`CitableDocumentNumber.resolve`). The publication year is the manifest's
/// (`FRUSVolumeMetadata(entry)`): the app prefers the year in the volume's TEI header, which it
/// reads with app code, and the two agree for every volume in the published catalogue at the
/// pinned corpus.
public struct DocumentCitation: Codable, Equatable, Sendable {
    /// A style the endpoint can write, with the kit's names for it.
    public struct Style: Codable, Equatable, Sendable {
        public var style: String
        public var name: String
        public var shortName: String
    }

    public var volumeId: String
    public var documentId: String
    public var style: String
    /// The formatter's text, with Markdown emphasis: `_…_` around the series title in the
    /// history.state.gov style, `*…*` around the whole volume title in Chicago and Turabian.
    public var citation: String
    /// What Copy writes: `CitationPlainText.plain(citation)`.
    public var plainText: String
    /// The document's page on history.state.gov.
    public var canonicalURL: String
    /// The number the citation names, or nil for a document the volume prints without one.
    public var documentNumber: String?
    /// How the app labels the document beside its citation: "Doc 12", or "Unnumbered (d710a-1)".
    public var documentLabel: String
    /// Where `documentNumber` came from: `index`, `tei` or `documentId`; nil when there is none.
    public var numberSource: String?
    /// Where the publication year came from: `manifest`.
    public var publicationYearSource: String
    public var styles: [Style]
}

extension DocumentCitation: ResponseEncodable {}

enum CitationRoutes {
    static let styles = CitationStyle.allCases.map {
        DocumentCitation.Style(style: $0.rawValue, name: $0.displayName, shortName: $0.shortDisplayName)
    }

    static func add(to router: Router<BasicRequestContext>, reader: ReaderService, provider: ServedIndexProvider,
                    resources: ServerResources) {
        router.get("/api/v1/volumes/:volumeId/documents/:documentId/citation") { request, context -> DocumentCitation in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["style"])
            let style = try query.choice("style", among: CitationStyle.allCases) ?? .historyAtState
            let volumeId = try context.parameters.require("volumeId")
            let documentId = try context.parameters.require("documentId")
            guard let volume = resources.volume(volumeId) else { throw APIProblem.volumeNotFound(volumeId) }

            // The index's row and number first, as the Mac's citation popover takes them; for a row
            // with no number, or no row, the TEI's printed number, as the reader takes it. The reader
            // cites without search, so a stack that cannot be had leaves the TEI.
            var entry: DocumentBrowserEntry?
            if let served = try? await provider.servedIfReady() {
                entry = try await served.pipeline.document(forDocumentId: documentId, inVolume: volumeId)
            }
            // An empty value counts as none, as `CitableDocumentNumber.resolve` counts it.
            func given(_ value: String?) -> String? {
                value.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            }
            var number = given(entry?.documentNumber)
            var numberSource: String? = number == nil ? nil : "index"
            if number == nil {
                do {
                    let parsed = try await reader.document(volume: volumeId, document: documentId)
                    number = given(parsed.ast.printedNumber)
                    if number != nil { numberSource = "tei" }
                    // The formatters read the number and the volume, never the header.
                    if entry == nil {
                        entry = DocumentBrowserEntry(documentId: parsed.ast.documentId, volumeId: volumeId, header: "")
                    }
                } catch where entry != nil {
                    // An indexed document whose TEI is not mounted: the id's number, as the Mac's popover cites it.
                }
            }
            guard let entry else { throw APIProblem(.notFound, code: "DOCUMENT_NOT_FOUND", detail: "No document \(documentId) in \(volumeId).") }
            let document = FRUSDocumentMetadata(citing: entry, printedNumber: number)
            let documentNumber = CitableDocumentNumber.resolve(printed: number, documentId: entry.documentId)
            // A bracketed description cites no number; with nothing given, the id spells it.
            if documentNumber == nil { numberSource = nil } else if numberSource == nil { numberSource = "documentId" }
            let citation = style.makeFormatter().format(document: document, volume: FRUSVolumeMetadata(volume))
            return DocumentCitation(
                volumeId: volumeId, documentId: entry.documentId, style: style.rawValue,
                citation: citation, plainText: CitationPlainText.plain(citation),
                canonicalURL: FRUSCanonicalURL.string(volumeId: volumeId, documentId: entry.documentId),
                documentNumber: documentNumber,
                documentLabel: CitableDocumentNumber.captionLabel(printed: number, documentId: entry.documentId),
                numberSource: numberSource, publicationYearSource: "manifest", styles: styles)
        }
    }
}
