// Source Explorer (PLAN's S22d): a document's source note resolved as the app's Source Explorer resolves it,
// before it asks the NARA Catalog anything, and the panels the app draws from what it resolved.
//
// The resolution is the kit's `SourceExplorerResolution` (FRUS-Explorer#1894), which both of the app's views
// run in `load()`: the parse, the collection authority's record, the pre-1906 country series, the document's
// day, the marking the index stores, the unprinted pointers, the archival neighbours and the presidential-library
// catalogue's answer, over the served index and the server's copies of the bundled files. The panels are the
// iOS view's sections (`SourceExplorerView`), in its order, each built from the kit's readers that view calls
// while drawing (FRUS-Explorer#1895 made them public, with `SourceExplorerPanels`): the view's few rules that
// choose a section, a row or a link are mirrored here and held to the app's source by
// `SourceExplorerParityTests`, and every word the kit writes is the kit's, sent as it writes it. The words the
// view writes itself are the browser app's (web/src/copy.ts), held to the app's source by the same suite.
//
// Nothing here calls NARA or any other service: the NARA Catalog section names the query the app would run
// and the manual search it offers, which PLAN's S22e runs through a proxy of its own. The `offline` block is
// what check 8 reads (`frus-parity check-source-explorer`): the lot the bundled central files resolve, the
// Numerical File's rolls and the authority's record, beside the parse and its keys, which the check holds to
// the export generator's record for the same note.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import SourceNoteKit

/// A document's Source Explorer, as the app's view shows it before any NARA Catalog search.
public struct SourceExplorerAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var volumeId: String
    public var documentId: String
    /// The document's title, as a list calls it, for the page's subtitle.
    public var documentTitle: String
    /// The source note the index stores for the document, the reader's (`IndexingPipeline.extractSourceNote`);
    /// empty for a document that prints none.
    public var rawSourceNote: String
    /// Whether the note is more than blank: the view's `hasSourceNote`.
    public var hasSourceNote: Bool
    /// The note, parsed (`SourceNoteParser`): its case and its values.
    public var parsed: ParsedNote
    /// The chip beside the note: the marking it prints, else the one the index stores
    /// (`IndexingPipeline.classificationMarking(sourceNote:stored:)`).
    public var classificationMarking: String?
    /// The dateline the panels read, the reader's or the index's (`SourceExplorerDocumentContext`), and the year
    /// every year-dependent section reads, which comes from it (`effectiveYear`).
    public var dateline: String?
    public var year: Int?
    /// The keys the parse gives, which the archival neighbours and the lot rows are matched on.
    public var keys: Keys
    /// The provenance section's panels, in the view's order, for a document with a note.
    public var provenance: [Panel]
    /// The pre-1906 section, when it found the digitized series a document was likely filed in.
    public var countrySeries: CountrySeries?
    /// The section a document with no note shows when the pre-1906 section found none.
    public var noSourceNote: NoSourceNote?
    /// The Archival Neighbors section.
    public var neighbours: Neighbours
    /// The Archival Collection section: the authority's record, when the note names one.
    public var collection: CollectionRow?
    /// The Unprinted Material section, for a document whose footnotes point at material FRUS did not print.
    public var unprinted: Unprinted?
    /// What check 8 reads.
    public var offline: Offline

    /// A parsed source note: its `ParsedSourceNote` case and the values the case holds, by their labels,
    /// absent ones left out.
    public struct ParsedNote: Codable, Equatable, Sendable {
        public var kind: String
        public var fields: [String: String]
    }

    /// The keys the app derives from the parse (SourceNoteKit's).
    public struct Keys: Codable, Equatable, Sendable {
        /// Whether the parse supports the archival neighbours' query (`supportsArchivalNeighbors`).
        public var supportsArchivalNeighbors: Bool
        /// The neighbours' key (`archivalNeighborKey`).
        public var archivalNeighborKey: String?
        /// The compact lot key of the lot the note cites (`SourceNoteParser.lotFileNorm`).
        public var lotFileNorm: String?
        /// The central-file class the note cites (`CollectionKeying.centralFilesClass`).
        public var decimalClass: String?
        /// The marking the note prints (`SourceNoteParser.classificationMarking(fromSourceNote:)`).
        public var noteMarking: String?
    }

    /// One of the provenance section's panels: its kind, and what it shows.
    public struct Panel: Codable, Equatable, Sendable {
        public var kind: String
        // The Provenance rows' values, each a fact the panel's kind names.
        public var recordGroup: String?
        public var recordGroupSource: String?
        public var fileIdentifier: String?
        public var lotNumber: String?
        public var series: String?
        public var lotFile: String?
        public var box: String?
        public var jobNumber: String?
        public var library: String?
        public var libraryCollection: String?
        public var seriesName: String?
        public var description: String?
        public var citation: String?
        /// A lot file's type: true for a post's lot file (RG 84).
        public var postRecords: Bool?
        /// The kit's sentence for a named series with nothing curated (`NamedFileSeriesRouting.explainer`).
        public var explainer: String?
        /// A link and its words: NARA's State Department records page, a CREST search, a finding aid.
        public var link: Link?
        public var links: [Link]?
        /// A Subject-Numeric citation's designation, block of years, handbooks and the era's page.
        public var designation: String?
        public var block: String?
        public var handbooks: [Link]?
        /// The filing period a year resolves, or, with none, the full table (`allFilingPeriods`).
        public var period: Link?
        public var manual: Link?
        public var periods: [FilingPeriodRow]?
        /// The Numerical File's rolls for a file number, or none: the gap's two links.
        public var scans: [Scan]?
        public var scanState: String?
        public var rangeCount: Int?
        public var caveat: String?
        /// The kit's words for a section it titles itself, and its notes.
        public var title: String?
        public var notes: [String]?
        /// Paris Peace Conference records, the library catalogue's collection and series.
        public var records: [Record]?
        public var findingAidsTitle: String?
        public var findingAids: [Record]?
        /// A curated lot outcome, or NARA's divided series.
        public var outcome: CuratedOutcome?
        /// A bundled lot's NARA series.
        public var lot: BundledLot?
        /// The presidential-library catalogue's answer.
        public var libraryOutcome: LibraryOutcome?
        /// The repository's own guidance, outside NARA's custody.
        public var guidance: Guidance?
        /// The NARA Catalog query the app would run here, which PLAN's S22e runs, and its manual search.
        public var catalogQuery: CatalogQuery?
        /// A curated finding aid's rationale, a named series' evidence.
        public var rationale: String?

        init(kind: String) { self.kind = kind }
    }

    /// A link: where it goes and the words it shows, when the kit writes them.
    public struct Link: Codable, Equatable, Sendable {
        public var url: String
        public var label: String?
    }

    /// A row of the full table of filing periods (`FilingPeriod`).
    public struct FilingPeriodRow: Codable, Equatable, Sendable {
        public var id: String
        public var label: String
        public var url: String
        public var manuals: [Link]
    }

    /// A digitized scan: a decimal file range or a Numerical File roll (`DigitizedScanPresentation`).
    public struct Scan: Codable, Equatable, Sendable {
        public var title: String
        public var objectCount: Int
        /// The kit's count of images, when there are any.
        public var imageCountLabel: String?
        public var pdf: Link?
        public var catalogURL: String?
        /// Whether it is one of several ranges that hold the file, each shown with the app's "Possible" chip.
        public var candidate: Bool
        /// A Numerical File roll's NAID, for check 8.
        public var naId: String?
    }

    /// A catalog record the panel names: NARA's title, its dates, its address and the label above it.
    public struct Record: Codable, Equatable, Sendable {
        public var label: String?
        public var title: String
        public var dates: String?
        public var catalogURL: String?
    }

    /// A curated lot outcome (`CuratedLotOutcome`), or the series NARA divided a lot across.
    public struct CuratedOutcome: Codable, Equatable, Sendable {
        /// `possible`, `candidates` or `referral`.
        public var kind: String
        public var series: [CuratedSeriesRow]
        public var rationale: String
        public var creatorName: String?
        public var seeAllURL: String?
        public var guidance: String?
        public var seriesCount: Int?
        public var entryNumberRange: String?
        public var browseURL: String?
    }

    /// A curated series (`CuratedSeries`).
    public struct CuratedSeriesRow: Codable, Equatable, Sendable {
        public var title: String
        public var catalogURL: String
        public var entryNumber: String?
        public var dateRange: String?
    }

    /// A lot's one bundled series (`LotFileEntry`), with NARA's facts about it.
    public struct BundledLot: Codable, Equatable, Sendable {
        public var title: String
        /// The enclosing series' title, for a record below the series level.
        public var seriesTitle: String?
        public var creator: String?
        public var accessStatus: String?
        public var accessRestrictions: [String]?
        /// Shown only when publication is restricted (`isUseRestricted`).
        public var useStatus: String?
        public var useRestrictions: [String]?
        public var years: String?
        public var extent: String?
        public var heldAt: String?
        public var findingAids: [String]?
        public var entryNumbers: [String]?
        public var seriesEntryNumbers: [String]?
        public var catalogURL: String
    }

    /// The presidential-library catalogue's answer (`PresidentialLibraryOutcome`), in the kit's words.
    public struct LibraryOutcome: Codable, Equatable, Sendable {
        public var sectionTitle: String
        public var collection: Record?
        public var resolvedSeries: Record?
        public var caveat: String?
        public var candidates: [Record]
        public var provenanceNote: String
    }

    /// The repository that holds what NARA does not (`ManuscriptRepositoryGuidance.Entry`), in the kit's words.
    public struct Guidance: Codable, Equatable, Sendable {
        public var name: String
        public var formerName: String?
        public var citedAsLabel: String
        public var holdings: String
        public var link: Link?
    }

    /// The NARA Catalog query the app's `load()` would run for the note with a key, and the manual search
    /// its section offers. Nothing runs it here.
    public struct CatalogQuery: Codable, Equatable, Sendable {
        /// `lotVariants`, `recordGroup` or `presidentialMaterials`, or nil when the app would run none.
        public var route: String?
        public var manualSearchURL: String?
    }

    /// The pre-1906 section's homes (`CountrySeriesOutcome.resolved`), in the kit's words.
    public struct CountrySeries: Codable, Equatable, Sendable {
        /// The serial FRUS prints above the document, labelled by the lead home's direction.
        public var serial: Serial?
        /// Whether a row names the part of the page it is for (`showsPartLabels`), and the kit's note then.
        public var enclosureNote: String?
        public var homes: [Home]

        public struct Serial: Codable, Equatable, Sendable {
            public var title: String
            public var caption: String
        }

        public struct Home: Codable, Equatable, Sendable {
            public var category: String
            public var confidence: String
            /// `high` or `medium`, for the chip's colour.
            public var confidenceLevel: String
            /// Whether the register of chiefs of mission decided the row (the second provenance chip).
            public var chiefOfMission: Bool
            /// The part of the page its rolls hold, when a row names it.
            public var part: String?
            public var rationale: String
            public var rolls: [Record]
        }
    }

    /// The section a document with no note shows when the pre-1906 section found no roll.
    public struct NoSourceNote: Codable, Equatable, Sendable {
        /// `notChecked`, `notApplicable` or `noMatch`.
        public var state: String
        /// Why it was not checked (`NotCheckedReason`'s case), and the kit's sentence for it.
        public var reason: String?
        public var message: String?
        /// The era's likely series by the year: `diplomatic` before 1906, `numerical` for 1906–1910.
        public var predictedSeries: String?
    }

    /// The Archival Neighbors section (`relatedDocumentsSection`).
    public struct Neighbours: Codable, Equatable, Sendable {
        /// The documents from the same archival source, at most 30.
        public var documents: [Neighbour]
        /// How many matched in all.
        public var totalCount: Int
        /// The line above the list (`archivalNeighborBasis`), the kit's.
        public var basis: String?
        /// Why the list is empty (`relatedEmptyState`): `noNeighbors`, `subjectNumericNoNeighbors`,
        /// `subjectNumericUnkeyed` or `unmatched`.
        public var emptyState: String?
        /// The footer's key (`relatedMatchKey`).
        public var matchKey: String?
    }

    /// One neighbour, as the view's row draws it (`DocumentHeaderDisplay.numberedRow`).
    public struct Neighbour: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        public var number: String?
        public var title: String
        public var dateline: String?
    }

    /// The authority's record the note resolves to, as the section's link names it.
    public struct CollectionRow: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        /// The volumes that cite it, the section's "Cited in N volumes across the series".
        public var volumeCount: Int
    }

    /// The Unprinted Material section: each pointer's row, in reading order, and the kit's footer.
    public struct Unprinted: Codable, Equatable, Sendable {
        public var rows: [UnprintedRow]
        public var footer: String
    }

    /// One pointer's row (`UnprintedPointer.rowText`), and the record it opens, when it resolved to one.
    public struct UnprintedRow: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var spokenTitle: String
        public var clause: String?
        public var repeatNote: String?
        public var sameLotNote: String?
        public var fileId: String?
        public var inherited: Bool
        /// The provenance chip's source (`ProvenanceSource`'s case).
        public var source: String
        public var record: CollectionRow?
    }

    /// What check 8 reads: the resolutions the export generator records for the note, each through the kit.
    public struct Offline: Codable, Equatable, Sendable {
        /// The lot the bundled central files resolve, the #321 and #351 guards applied
        /// (`ArchivalResolver.documentResolution` with the central files alone).
        public var lotBundle: Resolution?
        /// The Numerical File's rolls that hold the file, when the section shows them, and whether it
        /// showed none (the coverage gap).
        public var numericalFileRolls: [Resolution]?
        public var numericalFileCoverageGap: Bool?
        /// The authority's record (`SourceExplorerResolution.authorityRecord`).
        public var collectionAuthority: AuthorityRecord?
    }

    /// A catalog resolution (`ArchivalResolution`), or a roll's identity.
    public struct Resolution: Codable, Equatable, Sendable {
        public var naId: String
        public var catalogURL: String
        public var title: String
        public var recordGroup: String?
        public var matchType: String?
        public var hmsMlrEntryNumbers: [String]?
        public var levelOfDescription: String?
        public var seriesNaId: String?
        public var seriesTitle: String?
        public var seriesHmsMlrEntryNumbers: [String]?
    }

    /// The authority record's identity (`AuthorityCollectionRecord`).
    public struct AuthorityRecord: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var naId: String?
        public var catalogURL: String?
    }
}

enum SourceExplorerRoutes {
    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources,
                    reader: ReaderService) {
        router.get("/api/v1/volumes/:volumeId/documents/:documentId/sources") { request, context -> SourceExplorerAnswer in
            try FormQuery(request.uri.query).refuseUnknown([])
            let volumeId = try context.parameters.require("volumeId")
            let documentId = try context.parameters.require("documentId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            guard documentId.utf8.count <= 256, FRUSURLScheme.isSafeComponent(documentId) else {
                throw APIProblem.invalidParameter("documentId", "\(documentId) is not a document's id.")
            }
            let served = try await provider.served()
            guard let entry = try await served.pipeline.document(forDocumentId: documentId, inVolume: volumeId) else {
                throw APIProblem(.notFound, code: "DOCUMENT_NOT_FOUND", detail: "The index holds no document \(documentId) in \(volumeId).")
            }
            // The stack is held until the answer is built, so that a job waits for it before it writes (PLAN's S21d).
            let answer = await answer(for: entry, pipeline: served.pipeline, resources: resources,
                                      documents: ReaderDocuments(reader: reader))
            withExtendedLifetime(served) {}
            return answer
        }
    }

    /// The NARA client, for the addresses it builds without a key, which need no network; it never searches here,
    /// so its session, the kit's default, sends nothing.
    static let client = NARACatalogClient(keyProvider: NoKey())

    /// A key provider with no key: nothing in S22d asks NARA anything.
    struct NoKey: NARACatalogKeyProvider {
        func naraCatalogAPIKey() async throws -> String? { nil }
    }

    /// The reader's parses, which the classifier reads a pre-1906 document's enclosures from, so that a volume is
    /// parsed once for the reader and for Source Explorer alike. It keeps nothing of its own: the reader keeps its
    /// recent parses.
    struct ReaderDocuments: DocumentASTSource {
        let reader: ReaderService

        func ast(volumeId: String, documentId: String) async -> FRUSDocumentAST? {
            try? await reader.document(volume: volumeId, document: documentId).ast
        }

        func store(_ documents: [FRUSDocumentAST], volumeId: String) async {}
    }

    /// The document's Source Explorer: the kit's resolution, as the app's view runs it, and the panels drawn from it.
    static func answer(for entry: DocumentBrowserEntry, pipeline: IndexingPipeline, resources: ServerResources,
                       documents: any DocumentASTSource) async -> SourceExplorerAnswer {
        let note = entry.sourceNote ?? ""
        // The app's route: the reader's header and dateline, and the year its `extractYear(from:)` reads from
        // the dateline, which is the classifier's own `documentYear(fromDateline:)`, applied in the hydration
        // when the route passes none.
        let route = CountrySeriesRoute(header: entry.header, dateline: entry.dateline, year: nil,
                                       volumeId: entry.volumeId, documentId: entry.documentId)
        let archival = resources.archivalIndexes
        let dependencies = SourceExplorerResolution.Dependencies(
            collectionAuthority: resources.collectionAuthority,
            centralFiles: archival.centralFiles,
            chiefsOfMission: resources.sourceExplorer(\.chiefsOfMission) ?? .empty,
            presidentialLibraries: resources.sourceExplorer(\.presidentialLibraries),
            curatedLibraries: resources.sourceExplorer(\.curatedLibraries),
            parsedDocuments: documents, volumeURL: nil)
        let resolution = await SourceExplorerResolution(rawSourceNote: note)
            .resolved(route: route, pipeline: pipeline, dependencies: dependencies)
        return answer(entry: entry, resolution: resolution, resources: resources)
    }

    /// The panels for a resolved note, as the view's `body` draws them.
    static func answer(entry: DocumentBrowserEntry, resolution: SourceExplorerResolution,
                       resources: ServerResources) -> SourceExplorerAnswer {
        let note = resolution.rawSourceNote
        let parsed = resolution.parsed
        let hasSourceNote = resolution.hasSourceNote
        let year = resolution.documentContext?.year
        let panels = Panels(note: note, resolution: resolution, year: year, resources: resources)

        var countrySeries: SourceExplorerAnswer.CountrySeries?
        var noSourceNote: SourceExplorerAnswer.NoSourceNote?
        switch resolution.countrySeries {
        case .resolved(let homes, let serialLabel):
            countrySeries = panels.countrySeries(homes, serialLabel: serialLabel, serial: resolution.documentContext?.despatchSerial)
        case .loading, .notChecked, .noMatch, .notApplicable:
            if !hasSourceNote { noSourceNote = panels.noSourceNote(resolution.countrySeries) }
        }

        let isEditorialNote = entry.isEditorialNote
        return SourceExplorerAnswer(
            volumeId: entry.volumeId, documentId: entry.documentId,
            documentTitle: displayTitle(header: entry.header, documentNumber: entry.documentNumber,
                                        isEditorialNote: isEditorialNote, documentId: entry.documentId),
            rawSourceNote: note, hasSourceNote: hasSourceNote,
            parsed: Self.describe(parsed),
            classificationMarking: hasSourceNote
                ? IndexingPipeline.classificationMarking(sourceNote: note, stored: resolution.storedClassification) : nil,
            dateline: resolution.documentContext?.dateline, year: year,
            keys: SourceExplorerAnswer.Keys(
                supportsArchivalNeighbors: parsed.supportsArchivalNeighbors,
                archivalNeighborKey: parsed.archivalNeighborKey,
                lotFileNorm: Self.rawLot(of: parsed).map { SourceNoteParser.lotFileNorm($0) },
                decimalClass: CollectionKeying.centralFilesClass(parsed: parsed, note: note),
                noteMarking: SourceNoteParser.classificationMarking(fromSourceNote: note)),
            provenance: hasSourceNote ? panels.provenance(parsed) : [],
            countrySeries: countrySeries, noSourceNote: noSourceNote,
            neighbours: panels.neighbours(resolution.relatedDocuments),
            collection: resolution.authorityRecord.map(Self.row),
            unprinted: resolution.unprintedPointers.isEmpty ? nil : SourceExplorerAnswer.Unprinted(
                rows: resolution.unprintedPointers.map(Self.row),
                footer: SourceExplorerResolution.UnprintedPointer.sectionFooter),
            offline: panels.offline(parsed))
    }

    /// A parse, as its case and its values by their labels, absent ones left out.
    static func describe(_ parsed: ParsedSourceNote) -> SourceExplorerAnswer.ParsedNote {
        func note(_ kind: String, _ fields: [String: String?]) -> SourceExplorerAnswer.ParsedNote {
            SourceExplorerAnswer.ParsedNote(kind: kind, fields: fields.compactMapValues { $0 })
        }
        switch parsed {
        case .centralFiles(let recordGroup, let fileIdentifier):
            return note("centralFiles", ["recordGroup": recordGroup, "fileIdentifier": fileIdentifier])
        case .cfpfFile(let fileIdentifier):
            return note("cfpfFile", ["fileIdentifier": fileIdentifier])
        case .lotFile(let recordGroup, let lotNumber, let fileIdentifier):
            return note("lotFile", ["recordGroup": recordGroup, "lotNumber": lotNumber, "fileIdentifier": fileIdentifier])
        case .presidentialLibrary(let library, let collection, let fileIdentifier):
            return note("presidentialLibrary", ["library": library, "collection": collection, "fileIdentifier": fileIdentifier])
        case .naraCollection(let recordGroup, let series, let lotFile, let box):
            return note("naraCollection", ["recordGroup": recordGroup, "series": series, "lotFile": lotFile, "box": box])
        case .ciaCollection(let jobNumber, let box, let description):
            return note("ciaCollection", ["jobNumber": jobNumber, "box": box, "description": description])
        case .namedFileSeries(let seriesName, let fileIdentifier):
            return note("namedFileSeries", ["seriesName": seriesName, "fileIdentifier": fileIdentifier])
        case .foreignGovernmentArchive(let description):
            return note("foreignGovernmentArchive", ["description": description])
        case .previouslyPublished(let citation):
            return note("previouslyPublished", ["citation": citation])
        case .unrecognized(let rawText):
            return note("unrecognized", ["rawText": rawText])
        }
    }

    /// The lot a parse cites: a lot file's, or a National Archives citation's.
    static func rawLot(of parsed: ParsedSourceNote) -> String? {
        switch parsed {
        case .lotFile(_, let lotNumber, _): return lotNumber
        case .naraCollection(_, _, let lotFile, _): return lotFile
        default: return nil
        }
    }

    static func row(_ record: AuthorityCollectionRecord) -> SourceExplorerAnswer.CollectionRow {
        SourceExplorerAnswer.CollectionRow(id: record.id, name: record.name, volumeCount: record.volumeIds.count)
    }

    static func row(_ pointer: SourceExplorerResolution.UnprintedPointer) -> SourceExplorerAnswer.UnprintedRow {
        let text = pointer.rowText
        let fileId = pointer.citation.fileId.flatMap { $0.isEmpty ? nil : $0 }
        return SourceExplorerAnswer.UnprintedRow(
            id: pointer.id, title: text.title, spokenTitle: text.spokenTitle, clause: text.clause,
            repeatNote: text.repeatNote, sameLotNote: text.sameLotNote, fileId: fileId,
            inherited: pointer.citation.inherited,
            source: "\(SourceExplorerProvenance.unprintedPointerSource(for: pointer.citation))",
            record: pointer.record.map(row))
    }
}

extension SourceExplorerRoutes {
    typealias Panel = SourceExplorerAnswer.Panel
    typealias Link = SourceExplorerAnswer.Link

    /// The panels, as `SourceExplorerView` draws them, over the server's files.
    struct Panels {
        let note: String
        let resolution: SourceExplorerResolution
        /// `effectiveYear`.
        let year: Int?
        let resources: ServerResources
        var client: NARACatalogClient { SourceExplorerRoutes.client }

        // MARK: The provenance section

        /// `provenanceSection(parsed:)`: a Subject-Numeric citation's own panel in any of its wordings, else the
        /// panel its case names.
        func provenance(_ parsed: ParsedSourceNote) -> [Panel] {
            if let subjectNumeric = SourceExplorerPanels.subjectNumericCitation(parsed: parsed, note: note,
                                                                               documentDay: resolution.documentDay) {
                return [subjectNumericPanel(subjectNumeric)]
            }
            switch parsed {
            case .centralFiles(let rg, let fileId):
                return centralFilesPanel(recordGroup: rg, fileIdentifier: fileId)
            case .cfpfFile(let fileId):
                var panel = Panel(kind: "cfpf")
                panel.fileIdentifier = fileId
                panel.links = [Link(url: client.cfpfFAQURL.absoluteString), Link(url: client.cfpfAADURL.absoluteString)]
                return [panel]
            case .lotFile(let rg, let lotNumber, let fileId):
                return lotFilePanel(recordGroup: rg, lotNumber: lotNumber, fileIdentifier: fileId)
            case .naraCollection(let rg, let series, let lot, let box):
                return naraCollectionPanel(recordGroup: rg, series: series, lotFile: lot, box: box)
            case .ciaCollection(let job, let box, let desc):
                var panel = Panel(kind: "cia")
                panel.jobNumber = job
                panel.box = box
                panel.description = desc
                panel.link = Link(url: client.ciaResearchURL(jobNumber: job).absoluteString)
                return [panel]
            case .presidentialLibrary(let library, let collection, let fileId):
                return presidentialLibraryPanel(library: library, collection: collection, fileIdentifier: fileId)
            case .namedFileSeries(let series, let fileId):
                return namedFileSeriesPanel(seriesName: series, fileIdentifier: fileId)
            case .foreignGovernmentArchive(let desc):
                var panel = Panel(kind: "foreignArchive")
                panel.description = desc
                return [panel]
            case .previouslyPublished(let citation):
                var panel = Panel(kind: "previouslyPublished")
                panel.citation = citation
                return [panel]
            case .unrecognized:
                return [Panel(kind: "unrecognized")]
            }
        }

        /// `subjectNumericPanel(_:)`: the file designation, its block of years, the era's page and handbooks.
        func subjectNumericPanel(_ citation: SourceExplorerPanels.SubjectNumericCitation) -> Panel {
            var panel = Panel(kind: "subjectNumeric")
            panel.designation = citation.designation
            panel.block = citation.block
            panel.handbooks = citation.handbooks.map { Link(url: $0.url.absoluteString, label: $0.label) }
            panel.period = Link(url: citation.pageURL.absoluteString)
            return panel
        }

        /// `centralFilesPanel(recordGroup:fileIdentifier:)`: the Provenance rows, then the Numerical File's rolls
        /// for a document of 1906–1910, the filing period for RG 59, the Paris Peace Conference's records for its
        /// record group, and the decimal file's scans.
        func centralFilesPanel(recordGroup: String, fileIdentifier: String?) -> [Panel] {
            var provenance = Panel(kind: "centralFiles")
            provenance.recordGroup = recordGroup.replacingOccurrences(of: "RG-", with: "RG ")
            provenance.fileIdentifier = fileIdentifier
            var panels = [provenance]
            if let fileIdentifier, let year, (1906...1910).contains(year) {
                panels.append(numericalFilePanel(fileIdentifier: fileIdentifier))
            }
            if recordGroup == "RG-59" || recordGroup == "59" {
                panels.append(periodPanel(fileIdentifier: fileIdentifier))
            }
            if ParisPeaceRecords.applies(recordGroup: recordGroup) {
                panels.append(parisPeacePanel())
            }
            if let fileIdentifier, let scans = digitizedScansPanel(fileIdentifier: fileIdentifier) {
                panels.append(scans)
            }
            return panels
        }

        /// The Numerical File's rolls for a 1906–1910 file number (`numericalFileSection`), or the gap's links.
        func numericalFilePanel(fileIdentifier: String) -> Panel {
            let rolls = resources.archivalIndexes.centralFiles?.numericalFile.rolls(forFileNumber: fileIdentifier) ?? []
            var panel = Panel(kind: "numericalFile")
            panel.fileIdentifier = fileIdentifier
            if rolls.isEmpty {
                panel.links = [Link(url: NumericalFileIndex.cardIndexURL.absoluteString),
                               Link(url: NumericalFileIndex.numericalFileSeriesURL.absoluteString)]
            } else {
                let rollScans = resources.sourceExplorer(\.rollScans)
                panel.scans = rolls.map { roll in
                    var scan = Self.scan(DigitizedScanPresentation(roll: roll, scan: rollScans?.scan(forNaId: roll.naId)))
                    scan.naId = roll.naId
                    return scan
                }
            }
            return panel
        }

        /// `centralFilesPeriodSection(fileIdentifier:)`: the period the file's year resolves, with its finding
        /// aids and manual, or the full table of periods with none.
        func periodPanel(fileIdentifier: String?) -> Panel {
            var panel = Panel(kind: "filingPeriod")
            if let year = DecimalFileSegment.filingYear(for: fileIdentifier, documentDay: resolution.documentDay,
                                                        documentYear: self.year) {
                panel.period = Link(url: client.decimalFilePeriodURL(year: year, fileIdentifier: fileIdentifier).absoluteString,
                                    label: client.decimalFilePeriodLabel(year: year, fileIdentifier: fileIdentifier))
                panel.manual = client.filingManualURL(year: year, fileIdentifier: fileIdentifier).map { Link(url: $0.absoluteString) }
            } else {
                panel.periods = SourceExplorerPanels.allFilingPeriods.map { period in
                    SourceExplorerAnswer.FilingPeriodRow(
                        id: period.id, label: period.label, url: period.url.absoluteString,
                        manuals: period.filingManuals.map { Link(url: $0.url.absoluteString, label: $0.label) })
                }
            }
            return panel
        }

        /// `parisPeaceSection()`: the Commission's record group and series, and NARA's finding aids for them.
        func parisPeacePanel() -> Panel {
            var panel = Panel(kind: "parisPeace")
            panel.title = ParisPeaceRecords.sectionTitle
            panel.records = [Self.record(ParisPeaceRecords.recordGroup, label: ParisPeaceRecords.recordGroupLabel),
                             Self.record(ParisPeaceRecords.series, label: ParisPeaceRecords.seriesLabel)]
            panel.notes = [ParisPeaceRecords.provenanceNote, ParisPeaceRecords.rollNote]
            panel.findingAidsTitle = ParisPeaceRecords.findingAidsTitle
            panel.findingAids = ParisPeaceRecords.findingAids.map { Self.record($0, label: nil) }
            return panel
        }

        /// `digitizedScansSection(fileIdentifier:)`: NARA's scans of the range a decimal citation's serial lands
        /// in, the ranges when several hold it, or the class's ranges when none covers it; nil for none.
        func digitizedScansPanel(fileIdentifier: String) -> Panel? {
            guard let index = resources.sourceExplorer(\.digitizedRanges),
                  let (cls, serial) = DigitizedRangeIndex.classAndSerial(fromFileIdentifier: fileIdentifier) else { return nil }
            var panel = Panel(kind: "digitizedScans")
            panel.fileIdentifier = fileIdentifier
            panel.series = cls
            switch index.match(decimalClass: cls, serial: serial) {
            case .resolved(let range):
                panel.scanState = "resolved"
                panel.scans = [Self.scan(DigitizedScanPresentation(range))]
                panel.caveat = SourceExplorerPanels.scanCaveat
            case .multipleRanges(let ranges):
                panel.scanState = "multiple"
                panel.scans = ranges.map { range in
                    var scan = Self.scan(DigitizedScanPresentation(range))
                    scan.candidate = true
                    return scan
                }
            case .classDigitizedButSerialNotCovered(let count):
                panel.scanState = "classOnly"
                panel.rangeCount = count
            case .none:
                return nil
            }
            return panel
        }

        /// `lotFilePanel(recordGroup:lotNumber:fileIdentifier:)`: the Provenance rows with the curated record group
        /// over the parser's, the lot cards, and the NARA Catalog section with its manual search.
        func lotFilePanel(recordGroup: String?, lotNumber: String, fileIdentifier: String?) -> [Panel] {
            let curatedRG = resources.sourceExplorer(\.curatedLots)?.recordGroup(forRawLot: lotNumber)
            let effectiveRG = curatedRG ?? recordGroup
            var provenance = Panel(kind: "lotFile")
            provenance.postRecords = (effectiveRG ?? "RG-59") == "RG-84"
            if let rg = effectiveRG {
                provenance.recordGroup = rg.replacingOccurrences(of: "RG-", with: "RG ")
                provenance.recordGroupSource = "\(SourceExplorerProvenance.lotRecordGroupSource(curated: curatedRG))"
            }
            provenance.lotNumber = lotNumber
            provenance.fileIdentifier = fileIdentifier
            let fallback: URL = (effectiveRG ?? "RG-59") == "RG-84"
                ? client.resolveRG84LotFile(lotNumber: lotNumber)
                : client.resolveRG59CentralFiles(fileIdentifier: "Lot \(lotNumber)")
            return [provenance]
                + lotCards(for: .lotFile(recordGroup: recordGroup, lotNumber: lotNumber, fileIdentifier: fileIdentifier))
                + [catalogPanel(route: "lotVariants", fallback: fallback)]
        }

        /// `naraCollectionPanel(recordGroup:series:lotFile:box:)`: the Provenance rows, the lot cards a lot cited
        /// through the National Archives gets (#1589), and the NARA Catalog section.
        func naraCollectionPanel(recordGroup: String, series: String?, lotFile: String?, box: String?) -> [Panel] {
            var provenance = Panel(kind: "naraCollection")
            provenance.recordGroup = recordGroup
            provenance.series = series
            provenance.lotFile = lotFile
            provenance.box = box
            let fallback = client.resolveRG59CentralFiles(fileIdentifier: [series, lotFile].compactMap { $0 }.joined(separator: " "))
            return [provenance]
                + lotCards(for: .naraCollection(recordGroup: recordGroup, series: series, lotFile: lotFile, box: box))
                + [catalogPanel(route: lotFile != nil ? "lotVariants" : "recordGroup", fallback: fallback)]
        }

        /// `lotCardSections(for:)`: the series NARA divided the lot across, else its one bundled series, then any
        /// hand-curated outcome, by the rule both of the app's views share (`SourceExplorerProvenance.lotCards`).
        func lotCards(for parsed: ParsedSourceNote) -> [Panel] {
            let archival = resources.archivalIndexes
            let seriesFacts = resources.sourceExplorer(\.seriesFacts)
            let cards = SourceExplorerProvenance.lotCards(for: parsed, note: note, claimants: archival.claimants,
                                                          centralFiles: archival.centralFiles,
                                                          curated: resources.sourceExplorer(\.curatedLots),
                                                          seriesFacts: seriesFacts)
            var panels: [Panel] = []
            switch cards?.bundled {
            case .divided(let divided)?:
                panels.append(curatedPanel(divided))
            case .single(let entry)?:
                panels.append(bundledLotPanel(entry, centralFiles: archival.centralFiles, seriesFacts: seriesFacts))
            case nil:
                break
            }
            if let outcome = cards?.curated { panels.append(curatedPanel(outcome)) }
            return panels
        }

        /// `curatedLotSection(_:)`: a curated outcome, in the confidence grammar of the pre-1906 section.
        func curatedPanel(_ outcome: CuratedLotOutcome) -> Panel {
            var panel = Panel(kind: "curatedLot")
            func row(_ series: CuratedSeries) -> SourceExplorerAnswer.CuratedSeriesRow {
                SourceExplorerAnswer.CuratedSeriesRow(title: series.title, catalogURL: series.catalogURL,
                                                      entryNumber: series.entryNumber, dateRange: series.dateRange)
            }
            switch outcome {
            case .possible(let series, let rationale):
                panel.outcome = SourceExplorerAnswer.CuratedOutcome(kind: "possible", series: [row(series)], rationale: rationale)
            case .candidates(let series, let rationale, let creatorName, let seeAllURL):
                panel.outcome = SourceExplorerAnswer.CuratedOutcome(kind: "candidates", series: series.map(row), rationale: rationale,
                                                                    creatorName: creatorName, seeAllURL: seeAllURL?.absoluteString)
            case .referral(let referral):
                panel.outcome = SourceExplorerAnswer.CuratedOutcome(
                    kind: "referral", series: [], rationale: referral.rationale, guidance: referral.guidance,
                    seriesCount: referral.seriesCount, entryNumberRange: referral.entryNumberRange,
                    browseURL: referral.url?.absoluteString)
            }
            return panel
        }

        /// `bundledLotSection(_:)`: a lot's one bundled series, with the creator NARA names and NARA's facts about it.
        func bundledLotPanel(_ entry: LotFileEntry, centralFiles: CentralFilesIndex?, seriesFacts: SeriesFactsIndex?) -> Panel {
            var lot = SourceExplorerAnswer.BundledLot(title: entry.title, catalogURL: entry.catalogURL)
            if !entry.isSeriesLevel { lot.seriesTitle = entry.displaySeriesTitle }
            lot.creator = SeriesFactsIndex.creatorName(for: entry, centralFiles: centralFiles, seriesFacts: seriesFacts)
            if let facts = SeriesFactsIndex.facts(for: entry, centralFiles: centralFiles, seriesFacts: seriesFacts) {
                if let access = facts.accessStatus {
                    lot.accessStatus = access
                    lot.accessRestrictions = facts.accessRestrictions
                }
                if facts.isUseRestricted, let use = facts.useStatus {
                    lot.useStatus = use
                    lot.useRestrictions = facts.useRestrictions
                }
                lot.years = facts.years
                lot.extent = facts.extent
                lot.heldAt = facts.referenceUnit
                lot.findingAids = facts.findingAids.isEmpty ? nil : facts.findingAids
            }
            if let entries = entry.hmsMlrEntryNumbers, !entries.isEmpty {
                lot.entryNumbers = entries
            } else if let seriesEntries = entry.seriesHmsMlrEntryNumbers, !seriesEntries.isEmpty {
                lot.seriesEntryNumbers = seriesEntries
            }
            var panel = Panel(kind: "bundledLot")
            panel.lot = lot
            return panel
        }

        /// `naraResultSection(requiresKey:fallbackURL:)`: the NARA Catalog section. The app runs its query once it
        /// has a key; here the section names the query and offers the manual search the app offers when the
        /// query finds nothing, and PLAN's S22e runs the query.
        func catalogPanel(route: String?, fallback: URL?) -> Panel {
            var panel = Panel(kind: "naraCatalog")
            panel.catalogQuery = SourceExplorerAnswer.CatalogQuery(route: route, manualSearchURL: fallback?.absoluteString)
            return panel
        }

        /// `presidentialLibraryPanel(library:collection:fileIdentifier:)`: the Provenance rows, a curated finding
        /// aid, then the bundled catalogue's answer, the NARA Catalog section for a repository NARA administers,
        /// or what a repository outside its custody holds.
        func presidentialLibraryPanel(library: String, collection: String, fileIdentifier: String?) -> [Panel] {
            var provenance = Panel(kind: "presidentialLibrary")
            provenance.library = library
            provenance.libraryCollection = collection.isEmpty ? nil : collection
            provenance.fileIdentifier = fileIdentifier
            var panels = [provenance]
            if let curated = resources.sourceExplorer(\.curatedLibraries)?.resolution(
                repository: library, collection: collection,
                subCollection: CuratedLibraryResolutions.subCollection(inNote: note, afterCollection: collection)) {
                var panel = Panel(kind: "curatedLibrary")
                panel.title = curated.title
                panel.link = curated.findingAid.map { Link(url: $0.absoluteString) }
                panel.links = curated.catalogURL.map { [Link(url: $0.absoluteString)] }
                panel.rationale = curated.rationale.flatMap { $0.isEmpty ? nil : $0 }
                panels.append(panel)
            }
            let outcome = resolution.presidentialLibrary
            if outcome.isHit {
                panels.append(offlineLibraryPanel(outcome))
            } else if NARACustody.mayQueryCatalog(forRepository: library) {
                panels.append(catalogPanel(route: "presidentialMaterials", fallback: client.libraryFallbackURL(libraryName: library)))
            } else {
                var panel = Panel(kind: "outsideNARA")
                panel.library = library
                panel.guidance = ManuscriptRepositoryGuidance.guidance(forRepository: library).map { guidance in
                    SourceExplorerAnswer.Guidance(
                        name: guidance.name, formerName: guidance.formerName,
                        citedAsLabel: ManuscriptRepositoryGuidance.citedAsLabel, holdings: guidance.holdings,
                        link: guidance.url.map { Link(url: $0.absoluteString, label: ManuscriptRepositoryGuidance.linkLabel(guidance)) })
                }
                panels.append(panel)
            }
            return panels
        }

        /// `offlineLibrarySection(_:)`: the bundled catalogue's collection and series, in the kit's words.
        func offlineLibraryPanel(_ outcome: PresidentialLibraryOutcome) -> Panel {
            func series(_ series: PresidentialLibraryIndex.Series, label: String?) -> SourceExplorerAnswer.Record {
                SourceExplorerAnswer.Record(label: label, title: series.title, dates: series.inclusiveDates,
                                            catalogURL: series.catalogURL?.absoluteString)
            }
            var panel = Panel(kind: "offlineLibrary")
            panel.libraryOutcome = SourceExplorerAnswer.LibraryOutcome(
                sectionTitle: outcome.sectionTitle,
                collection: outcome.verifiedCollection.map {
                    SourceExplorerAnswer.Record(label: outcome.collectionRowLabel, title: $0.title, dates: nil,
                                                catalogURL: $0.catalogURL?.absoluteString)
                },
                resolvedSeries: outcome.resolvedSeries.map { series($0, label: outcome.seriesRowLabel) },
                caveat: outcome.caveat,
                candidates: (outcome.candidateSeries ?? []).map { series($0, label: nil) },
                provenanceNote: outcome.provenanceNote)
            return panel
        }

        /// `namedFileSeriesPanel(seriesName:fileIdentifier:)`: the Provenance rows, with the kit's explainer and
        /// NARA's State Department records page when nothing curated answers; the curated outcome; and where the
        /// volume's own Sources section or the name says the series is held.
        func namedFileSeriesPanel(seriesName: String, fileIdentifier: String?) -> [Panel] {
            let curatedLots = resources.sourceExplorer(\.curatedLots)
            let curated = curatedLots?.record(forSeriesName: seriesName)
            var provenance = Panel(kind: "namedFileSeries")
            provenance.seriesName = seriesName
            provenance.recordGroup = curatedLots?.recordGroup(forSeriesName: seriesName)?.replacingOccurrences(of: "RG-", with: "RG ")
            provenance.fileIdentifier = fileIdentifier
            if curated == nil {
                provenance.explainer = NamedFileSeriesRouting.explainer(seriesName: seriesName)
                if NamedFileSeriesRouting.offersStateRecordsLink(seriesName: seriesName) {
                    provenance.link = Link(url: NARACatalogClient.stateDepartmentRecordsURL.absoluteString,
                                           label: NARACatalogClient.stateDepartmentRecordsLabel)
                }
            }
            var panels = [provenance]
            if let outcome = curatedLots?.outcome(forSeriesName: seriesName) { panels.append(curatedPanel(outcome)) }
            if let routing = NamedFileSeriesRouting.routing(forSeriesName: seriesName) {
                var panel = Panel(kind: "namedSeriesRouting")
                panel.title = NamedFileSeriesRouting.sectionTitle
                panel.notes = [NamedFileSeriesRouting.label(routing), NamedFileSeriesRouting.title(routing)]
                panel.link = NamedFileSeriesRouting.url(routing).map {
                    Link(url: $0.absoluteString, label: NamedFileSeriesRouting.linkLabel(routing))
                }
                panel.rationale = routing.evidence
                panels.append(panel)
            }
            return panels
        }

        // MARK: The other sections

        /// `countrySeriesSection`: the homes the pre-1906 section found, with the serial to look for on the images.
        func countrySeries(_ homes: [CentralFilesResolution], serialLabel: CentralFilesSerialLabel,
                           serial: String?) -> SourceExplorerAnswer.CountrySeries {
            let showsPartLabels = homes.contains { $0.part.isEnclosure }
            return SourceExplorerAnswer.CountrySeries(
                serial: serial.map { SourceExplorerAnswer.CountrySeries.Serial(title: serialLabel.title(serial: $0), caption: serialLabel.caption) },
                enclosureNote: showsPartLabels ? CentralFilesDocumentPart.enclosureNote : nil,
                homes: homes.map { home in
                    let classification = home.classification
                    return SourceExplorerAnswer.CountrySeries.Home(
                        category: classification.category.displayName,
                        confidence: classification.confidence.label,
                        confidenceLevel: classification.confidence == .high ? "high" : "medium",
                        chiefOfMission: home.chiefOfMission != nil,
                        part: showsPartLabels ? home.part.displayName : nil,
                        rationale: classification.rationale,
                        rolls: home.rolls.map { SourceExplorerAnswer.Record(title: $0.title, catalogURL: $0.catalogURL) })
                })
        }

        /// `noSourceNoteSection`: why the pre-1906 section found no roll, and the era's likely series by the year
        /// (`predictedSeriesNote`).
        func noSourceNote(_ outcome: CountrySeriesOutcome) -> SourceExplorerAnswer.NoSourceNote {
            var section = SourceExplorerAnswer.NoSourceNote(state: "noMatch")
            switch outcome {
            case .notChecked(let reason):
                section.state = "notChecked"
                section.reason = "\(reason)"
                section.message = reason.message
            case .notApplicable:
                section.state = "notApplicable"
                section.message = CountrySeriesOutcome.notApplicableMessage
            case .noMatch, .loading, .resolved:
                break
            }
            if let year {
                switch year {
                case ..<1906: section.predictedSeries = "diplomatic"
                case 1906...1910: section.predictedSeries = "numerical"
                default: break
                }
            }
            return section
        }

        /// `relatedDocumentsSection`: the documents from the same archival source, the line above them, and why
        /// there are none.
        func neighbours(_ lookup: SourceExplorerResolution.RelatedDocumentsLookup) -> SourceExplorerAnswer.Neighbours {
            let parsed = resolution.parsed
            let documents = lookup.documents.map { document in
                let row = DocumentHeaderDisplay.numberedRow(header: document.header, number: document.documentNumber)
                return SourceExplorerAnswer.Neighbour(volumeId: document.volumeId, documentId: document.documentId,
                                                      number: row.number, title: row.title.isEmpty ? document.documentId : row.title,
                                                      dateline: document.dateline)
            }
            var emptyState: String?
            if documents.isEmpty {
                switch SourceExplorerPanels.relatedEmptyState(for: parsed, note: note) {
                case .noNeighbors: emptyState = "noNeighbors"
                case .subjectNumericNoNeighbors: emptyState = "subjectNumericNoNeighbors"
                case .subjectNumericUnkeyed: emptyState = "subjectNumericUnkeyed"
                case .unmatched: emptyState = "unmatched"
                }
            }
            return SourceExplorerAnswer.Neighbours(
                documents: documents, totalCount: lookup.totalCount,
                basis: documents.isEmpty ? nil : SourceExplorerPanels.archivalNeighborBasis(
                    for: parsed, note: note, documentYear: year, documentDay: resolution.documentDay),
                emptyState: emptyState,
                matchKey: SourceExplorerPanels.relatedMatchKey(for: parsed, note: note))
        }

        // MARK: Check 8

        /// The resolutions the export generator records for the note, each through the kit: the lot the central files
        /// resolve with their guards and no other index, the Numerical File section's rolls, and the authority's record.
        func offline(_ parsed: ParsedSourceNote) -> SourceExplorerAnswer.Offline {
            var offline = SourceExplorerAnswer.Offline()
            if let lot = SourceExplorerRoutes.rawLot(of: parsed) {
                offline.lotBundle = ArchivalResolver.documentResolution(
                    lotFile: lot, centralFiles: resources.archivalIndexes.centralFiles, volumeSources: nil, claimants: nil)
                    .map(Self.resolution)
            }
            // The Numerical File section's gate, `centralFilesPanel`'s: a central-files citation with a file number,
            // of 1906–1910. A Subject-Numeric citation takes its own panel, which has no such section.
            if resolution.hasSourceNote, case .centralFiles(_, let fileIdentifier?) = parsed,
               SourceExplorerPanels.subjectNumericCitation(parsed: parsed, note: note, documentDay: resolution.documentDay) == nil,
               let year, (1906...1910).contains(year) {
                let rolls = resources.archivalIndexes.centralFiles?.numericalFile.rolls(forFileNumber: fileIdentifier) ?? []
                if rolls.isEmpty {
                    offline.numericalFileCoverageGap = true
                } else {
                    offline.numericalFileRolls = rolls.map {
                        SourceExplorerAnswer.Resolution(naId: $0.naId, catalogURL: $0.catalogURL, title: $0.title)
                    }
                }
            }
            offline.collectionAuthority = resolution.authorityRecord.map {
                SourceExplorerAnswer.AuthorityRecord(id: $0.id, name: $0.name, naId: $0.naId, catalogURL: $0.catalogURL)
            }
            return offline
        }

        // MARK: Rows

        static func scan(_ scan: DigitizedScanPresentation) -> SourceExplorerAnswer.Scan {
            SourceExplorerAnswer.Scan(
                title: scan.title, objectCount: scan.objectCount,
                imageCountLabel: scan.objectCount > 0 ? scan.imageCountLabel : nil,
                pdf: scan.pdfURL.flatMap { url in scan.pdfLabel.map { Link(url: url.absoluteString, label: $0) } },
                catalogURL: scan.catalogURL?.absoluteString, candidate: false)
        }

        static func record(_ record: ParisPeaceRecords.CatalogRecord, label: String?) -> SourceExplorerAnswer.Record {
            SourceExplorerAnswer.Record(label: label, title: record.title, dates: record.inclusiveDates,
                                        catalogURL: record.catalogURL?.absoluteString)
        }

        static func resolution(_ resolution: ArchivalResolution) -> SourceExplorerAnswer.Resolution {
            SourceExplorerAnswer.Resolution(
                naId: resolution.naId, catalogURL: resolution.catalogURL, title: resolution.title,
                recordGroup: resolution.recordGroup, matchType: resolution.matchType,
                hmsMlrEntryNumbers: resolution.hmsMlrEntryNumbers, levelOfDescription: resolution.levelOfDescription,
                seriesNaId: resolution.seriesNaId, seriesTitle: resolution.seriesTitle,
                seriesHmsMlrEntryNumbers: resolution.seriesHmsMlrEntryNumbers)
        }
    }
}
