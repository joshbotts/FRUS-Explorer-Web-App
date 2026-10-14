// GET /api/v1/volumes/{v}/documents/{d}/citation: the kit's citation of a document, as the reader's
// Cite shows it, with its BibTeX and RIS records; …/citation.bib and …/citation.ris, the records as
// files, as the Mac's Cite saves a .bib file.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// A document's citation in one style, made by the kit's formatter as the app's Cite makes it, and
/// its BibTeX and RIS records, made by the kit's exporters as the Mac's Cite makes them.
///
/// The number is the index's, which the indexer writes as the TEI's printed number or the one the
/// heading names, as the Mac's citation popover takes it; for a row with none, or with no index,
/// it is the TEI's printed number, as the reader takes it; failing both, the number the id spells
/// (`CitableDocumentNumber.resolve`).
///
/// The publication year is the one the volume's TEI header states, read by the kit's
/// `TEIPublicationYear` as both of the app's hosts read it, when the TEI is mounted; else the
/// manifest's (`FRUSVolumeMetadata(entry)`), and for the records the Mac's fallback, the manifest
/// date's first four-digit year, else "n.d." (`DocumentExportSupport.effectiveYear`, app code,
/// which `manifestYear` mirrors: the kit leaves the fallback to each host). The citation and both
/// records are made from one volume's metadata, as iOS's reader makes them, so the printer's name
/// always follows the year cited. The Mac's popover gives the records the manifest's printer, which
/// differs only for a volume whose header and manifest name years either side of 2014, and none do.
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
    /// The year the citation and the records name, such as "1996", or "n.d." when neither the TEI
    /// header nor the manifest states one.
    public var publicationYear: String
    /// Where the publication year came from: `tei` or `manifest`; nil for "n.d.".
    public var publicationYearSource: String?
    /// The kit's BibTeX `@incollection` record, as Copy BibTeX writes it; `…/citation.bib` serves it.
    public var bibtex: String
    /// The kit's RIS record, as Copy RIS writes it; `…/citation.ris` serves it.
    public var ris: String
    public var styles: [Style]
}

extension DocumentCitation: ResponseEncodable {}

/// What a document is cited from: its entry and number, and its volume's metadata and year.
struct CitedDocument: Sendable {
    let volumeId: String
    let documentId: String
    let document: FRUSDocumentMetadata
    let volume: FRUSVolumeMetadata
    let documentNumber: String?
    let numberSource: String?
    let documentLabel: String
    let year: String
    let yearSource: String?

    var canonicalURL: String { FRUSCanonicalURL.string(volumeId: volumeId, documentId: documentId) }

    var bibtex: String {
        BibtexExporter().export(volumeId: volumeId, document: document, volume: volume, year: year, url: canonicalURL)
    }

    var ris: String {
        RISExporter().export(document: document, volume: volume, year: year, url: canonicalURL)
    }

    /// The name a saved record is given, as the Mac names its .bib file: `{volume}-{document}.{suffix}`,
    /// or `citation.{suffix}` should an id hold a character a file name should not.
    func fileName(_ suffix: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        let parts = [volumeId, documentId]
        guard parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(allowed.contains) }) else { return "citation.\(suffix)" }
        return "\(volumeId)-\(documentId).\(suffix)"
    }
}

enum CitationRoutes {
    static let styles = CitationStyle.allCases.map {
        DocumentCitation.Style(style: $0.rawValue, name: $0.displayName, shortName: $0.shortDisplayName)
    }

    /// The two record files, by suffix: BibTeX and RIS, with their media types.
    static let recordFiles: [(suffix: String, contentType: String)] = [
        ("bib", "application/x-bibtex; charset=utf-8"),
        ("ris", "application/x-research-info-systems; charset=utf-8"),
    ]

    /// The first four-digit year in the manifest's publication date, when it is later than 1750,
    /// else nil: the Mac's fallback for a volume whose TEI header states no year
    /// (`DocumentExportSupport.effectiveYear`, app code, which this mirrors).
    static func manifestYear(_ publicationDate: String?) -> String? {
        guard let publicationDate else { return nil }
        let segments = publicationDate.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
        guard let year = segments.first(where: { $0.count == 4 }), let value = Int(year), value > 1750 else { return nil }
        return year
    }

    static func add(to router: Router<BasicRequestContext>, reader: ReaderService, provider: ServedIndexProvider,
                    resources: ServerResources) {
        router.get("/api/v1/volumes/:volumeId/documents/:documentId/citation") { request, context -> DocumentCitation in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["style"])
            let style = try query.choice("style", among: CitationStyle.allCases) ?? .historyAtState
            let cited = try await cite(context: context, reader: reader, provider: provider, resources: resources)
            let citation = style.makeFormatter().format(document: cited.document, volume: cited.volume)
            return DocumentCitation(
                volumeId: cited.volumeId, documentId: cited.documentId, style: style.rawValue,
                citation: citation, plainText: CitationPlainText.plain(citation),
                canonicalURL: cited.canonicalURL, documentNumber: cited.documentNumber,
                documentLabel: cited.documentLabel, numberSource: cited.numberSource,
                publicationYear: cited.year, publicationYearSource: cited.yearSource,
                bibtex: cited.bibtex, ris: cited.ris, styles: styles)
        }
        for file in recordFiles {
            router.get("/api/v1/volumes/:volumeId/documents/:documentId/citation.\(file.suffix)") { request, context -> Response in
                try FormQuery(request.uri.query).refuseUnknown([])
                let cited = try await cite(context: context, reader: reader, provider: provider, resources: resources)
                var headers = ReaderRoutes.commonHeaders
                headers[.contentType] = file.contentType
                headers[.contentDisposition] = "attachment; filename=\"\(cited.fileName(file.suffix))\""
                let record = file.suffix == "bib" ? cited.bibtex : cited.ris
                return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: record)))
            }
        }
    }

    /// The document a request names, ready to cite. Throws an `APIProblem` for a volume outside the
    /// catalogue, or a document neither the index nor the mounted TEI holds.
    static func cite(context: BasicRequestContext, reader: ReaderService, provider: ServedIndexProvider,
                     resources: ServerResources) async throws -> CitedDocument {
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
                // The formatters read the number and the volume, never the header; the records
                // take the id for a title when the header is empty, as the kit's exporters do.
                if entry == nil {
                    entry = DocumentBrowserEntry(documentId: parsed.ast.documentId, volumeId: volumeId, header: "")
                }
            } catch where entry != nil {
                // An indexed document whose TEI is not mounted: the id's number, as the Mac's popover cites it.
            }
        }
        guard let entry else { throw APIProblem(.notFound, code: "DOCUMENT_NOT_FOUND", detail: "No document \(documentId) in \(volumeId).") }
        let documentNumber = CitableDocumentNumber.resolve(printed: number, documentId: entry.documentId)
        // A bracketed description cites no number; with nothing given, the id spells it.
        if documentNumber == nil { numberSource = nil } else if numberSource == nil { numberSource = "documentId" }

        // The year the TEI header states, which both of the app's hosts prefer to the manifest's.
        var metadata = FRUSVolumeMetadata(volume)
        let year: String
        let yearSource: String?
        if let tei = ReaderService.teiFile(for: volumeId, in: reader.volumesDirectory),
           let stated = TEIPublicationYear.read(from: tei) {
            metadata = metadata.overridingPublicationYear(stated)
            (year, yearSource) = (stated, "tei")
        } else if let fromManifest = manifestYear(volume.publicationDate) {
            (year, yearSource) = (fromManifest, "manifest")
        } else {
            (year, yearSource) = ("n.d.", nil)
        }
        return CitedDocument(
            volumeId: volumeId, documentId: entry.documentId,
            document: FRUSDocumentMetadata(citing: entry, printedNumber: number), volume: metadata,
            documentNumber: documentNumber, numberSource: numberSource,
            documentLabel: CitableDocumentNumber.captionLabel(printed: number, documentId: entry.documentId),
            year: year, yearSource: yearSource)
    }
}
