// The catalogue and browsing: GET /api/v1/volumes, /volumes/{v}, /volumes/{v}/documents and
// /volumes/{v}/documents/{d}. The catalogue is the published one, from the manifest, and works with
// no index; a volume's documents come from the index, through the kit's read-only stack.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// What a count-bearing response counted over: the volumes and documents the live index holds,
/// beside the 553 volumes of the published catalogue (docs/SPEC.md, HTTP API > Conventions).
public struct Coverage: Codable, Equatable, Sendable {
    public var indexedVolumes: Int
    public var indexedDocuments: Int
    public var manifestVolumes: Int
    /// The live index's version; nil while no index is open.
    public var indexVersion: Int?

    public init(indexedVolumes: Int, indexedDocuments: Int, manifestVolumes: Int, indexVersion: Int?) {
        self.indexedVolumes = indexedVolumes
        self.indexedDocuments = indexedDocuments
        self.manifestVolumes = manifestVolumes
        self.indexVersion = indexVersion
    }

    init(index: CorpusIndex?, resources: ServerResources) {
        indexedVolumes = index?.summary.volumes ?? 0
        indexedDocuments = index?.summary.documents ?? 0
        manifestVolumes = resources.manifest.count
        indexVersion = index?.summary.indexVersion
    }
}

/// One volume: the draft's `VolumeManifestEntry` fields, written here rather than by the kit's
/// synthesized `Encodable`, which would add the app's `provenance`, plus what this server holds.
public struct Volume: Codable, Equatable, Sendable {
    public var volumeId: String
    public var filename: String
    public var subseries: String
    public var title: String
    public var dateRange: DateRange
    public var publicationDate: String?
    public var status: String
    public var editors: [String]
    public var generalEditor: String?
    public var sizeBytes: Int
    public var tags: [String]
    /// Whether the live index holds any of its documents.
    public var indexed: Bool
    /// How many of its documents the live index holds.
    public var indexedDocuments: Int
    /// Whether its TEI is in the mounted folder, so the reader can render it.
    public var teiAvailable: Bool
    /// Its front matter, chapters and back matter, on `/volumes/{v}` alone: the index's when it holds
    /// them, else the TEI's, parsed by the kit as the app parses a volume it has not indexed.
    public var structure: [Section]?
    /// `index` or `tei`: where `structure` came from.
    public var structureSource: String?
    /// How many documents `structure` holds, and how many of those the index holds.
    public var documentCount: Int?
    public var indexedDocumentCount: Int?
    /// True for a volume side-loaded under an id the published catalogue lacks, which the catalogue overlay
    /// lists (PLAN's S21e), the app's Side-loaded badge; absent for a catalogue volume.
    public var sideloaded: Bool?

    /// A section of a volume: its divisions, in source order, with the documents directly in it.
    /// Its flags are the kit's `VolumeSection` properties.
    public struct Section: Codable, Equatable, Sendable {
        public var sectionId: String
        public var divType: String
        public var title: String
        public var documentIds: [String]
        public var subsections: [Section]
        /// How many documents it holds, its subsections' included, and how many of those the index
        /// holds.
        public var documentCount: Int
        public var indexedDocumentCount: Int
        /// A front-matter kind, such as a preface or a list of names.
        public var isFrontMatter: Bool
        /// Prose with no documents, read as a whole, such as a preface.
        public var canReadDirectly: Bool
        /// Whether Browse opens it in the reader, as the app's Read opens it: a section the full parse
        /// makes a document, such as a preface, or one Read opens that the reader parses alone, such as
        /// a back-of-volume index (`ReaderService.ParsedVolume.browseReaderIds`), which only a parse of
        /// its TEI can say; absent when the TEI is not mounted. The reader opens more sections than
        /// these, by Previous and Next and by links, the lists of persons and sources among them.
        public var readable: Bool?
        /// Whether the index holds a row of the text it prints outside the documents and sections
        /// it holds, which its page lists first: the kit's `VolumeSection.ownTextEntry(among:)`
        /// over the index's rows for the volume, so never for a leaf, a section with a generated
        /// id, or a volume the index does not hold.
        public var hasOwnText: Bool

        init(_ section: VolumeSection, indexed: Set<String>, rows: [DocumentBrowserEntry], browseOpens: Set<String>?) {
            sectionId = section.sectionId
            divType = section.divType
            title = section.title
            documentIds = section.documentIds
            subsections = section.subsections.map { Section($0, indexed: indexed, rows: rows, browseOpens: browseOpens) }
            let all = section.allDocumentIds
            documentCount = all.count
            indexedDocumentCount = all.filter(indexed.contains).count
            isFrontMatter = section.isFrontMatterKind
            canReadDirectly = section.canReadDirectly
            readable = browseOpens.map { $0.contains(section.sectionId) }
            hasOwnText = section.ownTextEntry(among: rows) != nil
        }
    }

    init(_ entry: VolumeManifestEntry, index: CorpusIndex?, volumesDirectory: URL) {
        volumeId = entry.volumeId
        filename = entry.filename
        subseries = entry.subseries
        title = entry.title
        dateRange = entry.dateRange
        publicationDate = entry.publicationDate
        status = entry.status.rawValue
        editors = entry.editors
        generalEditor = entry.generalEditor
        sizeBytes = entry.sizeBytes
        tags = entry.tags
        indexedDocuments = index?.documentsByVolume[entry.volumeId] ?? 0
        indexed = indexedDocuments > 0
        teiAvailable = ReaderService.teiFile(for: entry.volumeId, in: volumesDirectory) != nil
        sideloaded = entry.provenance == .sideloaded ? true : nil
    }
}

/// A page of volumes, in the manifest's order.
public struct VolumeList: Codable, Equatable, Sendable {
    public var total: Int
    public var limit: Int
    public var offset: Int
    public var items: [Volume]
    public var coverage: Coverage
}

extension Volume: ResponseEncodable {}
extension VolumeList: ResponseEncodable {}

enum CatalogRoutes {
    /// The draft's paging, with a larger page here, so one request can list all 553 volumes.
    static let maximumLimit = 1_000
    static let defaultLimit = 20

    static func add(to router: Router<APIRequestContext>, state: ServerState, provider: ServedIndexProvider,
                    resources: ServerResources, reader: ReaderService) {
        let volumesDirectory = reader.volumesDirectory
        router.get("/api/v1/volumes") { request, _ -> VolumeList in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["limit", "offset", "status", "subseries"])
            let limit = try query.integer("limit", in: 1...maximumLimit, default: defaultLimit)
            let offset = try query.integer("offset", in: 0...Int(Int32.max), default: 0)
            let status = try query.choice("status", among: [VolumeStatus.published, .partiallyPublished, .planned])
            let subseries = try query.single("subseries")
            let index = await state.index
            // The catalogue's volumes, then those side-loaded under an id it lacks, as the app's Browse lists them (S21e).
            let matching = (resources.manifest + resources.localVolumes).filter {
                (status == nil || $0.status == status) && (subseries == nil || $0.subseries == subseries)
            }
            let page = matching.dropFirst(offset).prefix(limit)
            return VolumeList(total: matching.count, limit: limit, offset: offset,
                              items: page.map { Volume($0, index: index, volumesDirectory: volumesDirectory) },
                              coverage: Coverage(index: index, resources: resources))
        }
        router.get("/api/v1/volumes/:volumeId") { request, context -> Volume in
            try FormQuery(request.uri.query).refuseUnknown([])
            let volumeId = try context.parameters.require("volumeId")
            guard let entry = resources.volume(volumeId) else { throw APIProblem.volumeNotFound(volumeId) }
            var volume = Volume(entry, index: await state.index, volumesDirectory: volumesDirectory)
            if let contents = try await VolumeContents(volumeId, indexed: volume.indexed, provider: provider, reader: reader) {
                // Each set made once, not once for each section.
                let (indexed, browseOpens) = (contents.indexed, contents.browseOpens)
                let sections = contents.sections.map {
                    Volume.Section($0, indexed: indexed, rows: contents.rows, browseOpens: browseOpens)
                }
                volume.structure = sections
                volume.structureSource = contents.source
                volume.documentCount = sections.reduce(0) { $0 + $1.documentCount }
                volume.indexedDocumentCount = sections.reduce(0) { $0 + $1.indexedDocumentCount }
            }
            return volume
        }
        router.get("/api/v1/volumes/:volumeId/sections/:sectionId") { request, context -> VolumeSectionPage in
            try FormQuery(request.uri.query).refuseUnknown([])
            let volumeId = try context.parameters.require("volumeId")
            let sectionId = try context.parameters.require("sectionId")
            guard let entry = resources.volume(volumeId) else { throw APIProblem.volumeNotFound(volumeId) }
            let indexedVolume = (await state.index?.documentsByVolume[volumeId] ?? 0) > 0
            guard let contents = try await VolumeContents(volumeId, indexed: indexedVolume, provider: provider, reader: reader),
                  let (section, path) = VolumeContents.find(sectionId, in: contents.sections) else {
                throw APIProblem(.notFound, code: "SECTION_NOT_FOUND",
                                 detail: "\(volumeId) has no section \(sectionId) in its structure.")
            }
            // Made once, not once for each document.
            let browseOpens = contents.browseOpens
            let documents = section.documentIds.map { documentId -> SectionDocument in
                if let indexed = contents.entries[documentId] {
                    return SectionDocument(indexed, readable: browseOpens?.contains(documentId))
                }
                return SectionDocument(documentId: documentId, ast: contents.parsed?.documents[documentId],
                                       structure: contents.sections, readable: browseOpens?.contains(documentId))
            }
            // The app's Browse finds the row by the same rule, among the same rows (#1536).
            let ownText = section.ownTextEntry(among: contents.rows).map {
                SectionDocument($0, readable: browseOpens?.contains($0.documentId))
            }
            return VolumeSectionPage(
                volumeId: volumeId, volumeTitle: entry.title,
                section: Volume.Section(section, indexed: contents.indexed, rows: contents.rows, browseOpens: browseOpens),
                path: path.map { .init(sectionId: $0.sectionId, title: $0.title) },
                ownText: ownText, documents: documents, structureSource: contents.source)
        }
        router.get("/api/v1/volumes/:volumeId/documents") { request, context -> DocumentList in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["limit", "offset"])
            let limit = try query.integer("limit", in: 1...maximumLimit, default: defaultLimit)
            let offset = try query.integer("offset", in: 0...Int(Int32.max), default: 0)
            let volumeId = try context.parameters.require("volumeId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            let served = try await provider.served()
            let browse = try await VolumeBrowse(volumeId, served: served)
            let page = Array(browse.sequence.dropFirst(offset).prefix(limit))
            let dates = try await served.pipeline.datesByDocumentKey(
                page.filter { browse.indexed.contains($0.documentId) }.map { (volumeId: volumeId, documentId: $0.documentId) })
            return DocumentList(total: browse.sequence.count, limit: limit, offset: offset,
                                items: page.map { DocumentEntry($0, inIndex: browse.indexed.contains($0.documentId),
                                                                dateISO: dates["\(volumeId)/\($0.documentId)"]) },
                                coverage: Coverage(index: served.corpus, resources: resources))
        }
        router.get("/api/v1/volumes/:volumeId/documents/:documentId") { request, context -> DocumentDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let volumeId = try context.parameters.require("volumeId")
            let documentId = try context.parameters.require("documentId")
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            let teiAvailable = ReaderService.teiFile(for: volumeId, in: volumesDirectory) != nil
            // The parse the reader renders from: which documents it can open, and a document the
            // index lacks. Nil without the TEI; TEI that will not parse is reported where it matters.
            var parse: Result<ReaderService.ParsedVolume, any Error>?
            if teiAvailable {
                do { parse = .success(try await reader.volume(volumeId)) } catch { parse = .failure(error) }
            }
            let parsed = try? parse?.get()
            /// A document the index cannot answer for, or a section the reader parses alone, named from
            /// its TEI, with its neighbours in `browse`'s reading order when that holds it; else
            /// `problem`, or the TEI's own when it will not parse.
            func fromTEI(otherwise problem: any Error, browse: VolumeBrowse? = nil) async throws -> DocumentDetail {
                if let parse, case .failure(let error) = parse { throw error }
                guard let parsed, parsed.opens(documentId) else { throw problem }
                let ast = try await reader.document(volume: volumeId, document: documentId).ast
                var detail = DocumentDetail(teiOnly: ast, structure: parsed.structure, volumeId: volumeId)
                detail.canonicalURL = resources.canonicalURL(volumeId: volumeId, documentId: ast.documentId)
                if let browse { (detail.previous, detail.next) = browse.neighbours(of: documentId, readable: parsed) }
                return detail
            }
            let served: ServedIndex
            do {
                served = try await provider.served()
            } catch {
                // The reader works without an index.
                return try await fromTEI(otherwise: error)
            }
            guard let entry = try await served.pipeline.document(forDocumentId: documentId, inVolume: volumeId) else {
                // A leaf the index leaves out, such as a back-of-volume index or a list of persons, is in
                // its reading order all the same, and the app's reader turns its pages from it as from a
                // document (`DocumentViewModel.loadAdjacentEntries`): read for a page the reader opens
                // alone. A chapter that prints only its heading is not in it, so its page has none, in
                // the app as here; an order that cannot be read leaves none.
                let browse = parsed?.opens(documentId) == true ? try? await VolumeBrowse(volumeId, served: served) : nil
                return try await fromTEI(otherwise: APIProblem(.notFound, code: "DOCUMENT_NOT_FOUND",
                                                               detail: "The index holds no document \(documentId) in \(volumeId)."),
                                         browse: browse)
            }
            let browse = try await VolumeBrowse(volumeId, served: served)
            let (previous, next) = browse.neighbours(of: entry.documentId, readable: parsed)
            let date = try await served.pipeline.datesByDocumentKey([(volumeId: volumeId, documentId: entry.documentId)])
            let classification = try await served.pipeline.effectiveIsEditorialNote(volumeId: volumeId, documentId: entry.documentId)
            var document = DocumentEntry(entry, inIndex: true, dateISO: date["\(volumeId)/\(entry.documentId)"])
            document.classify(asEditorialNote: classification ?? entry.isEditorialNote)
            return DocumentDetail(document: document,
                                  canonicalURL: resources.canonicalURL(volumeId: volumeId, documentId: entry.documentId),
                                  previous: previous, next: next, teiAvailable: teiAvailable)
        }
    }
}

/// What a volume's contents come from: the index's cached structure when it holds the volume, else
/// the structure the kit parses from its TEI; with the index's entries for its documents, and the
/// documents Browse opens in the reader, from the same parse the reader renders.
struct VolumeContents {
    let sections: [VolumeSection]
    let source: String
    /// The index's rows for the volume, in the order the kit gives them; empty when it holds none.
    let rows: [DocumentBrowserEntry]
    /// The same rows by document id, the first where two share one.
    let entries: [String: DocumentBrowserEntry]
    var indexed: Set<String> { Set(entries.keys) }
    let parsed: ReaderService.ParsedVolume?
    /// What Browse opens in the reader, as the app's Browse does: the full parse's documents and the
    /// sections its Read opens (`ReaderService.ParsedVolume.browseReaderIds`), not every section the
    /// reader opens.
    var browseOpens: Set<String>? { parsed.map(\.browseReaderIds) }

    /// Nil when neither the index nor the TEI gives the volume a structure. An index that cannot be
    /// read, or TEI that will not parse when the index gives no structure, throws its problem; TEI
    /// that will not parse beside the index's structure only leaves out which sections the reader
    /// can open.
    init?(_ volumeId: String, indexed: Bool, provider: ServedIndexProvider, reader: ReaderService) async throws {
        let served = indexed ? try await provider.servedIfReady() : nil
        let rows = try await served?.pipeline.documents(forVolume: volumeId) ?? []
        var entries: [String: DocumentBrowserEntry] = [:]
        for entry in rows where entries[entry.documentId] == nil {
            entries[entry.documentId] = entry
        }
        let cached = try await served?.pipeline.cachedVolumeStructure(forVolumeId: volumeId)
        let mounted = ReaderService.teiFile(for: volumeId, in: reader.volumesDirectory) != nil
        let parsed: ReaderService.ParsedVolume?
        if let cached, !cached.isEmpty {
            parsed = mounted ? try? await reader.volume(volumeId) : nil
            (sections, source) = (cached.sections, "index")
        } else if mounted {
            let volume = try await reader.volume(volumeId)
            guard !volume.structure.isEmpty else { return nil }
            parsed = volume
            (sections, source) = (volume.structure, "tei")
        } else {
            return nil
        }
        self.rows = rows
        self.entries = entries
        self.parsed = parsed
    }

    /// A section anywhere in the tree, and the sections above it, outermost first.
    static func find(_ sectionId: String, in sections: [VolumeSection],
                     above: [VolumeSection] = []) -> (VolumeSection, [VolumeSection])? {
        for section in sections {
            if section.sectionId == sectionId { return (section, above) }
            if let found = find(sectionId, in: section.subsections, above: above + [section]) { return found }
        }
        return nil
    }
}

/// A section of a volume, with the row of its own text, its documents in order and the sections
/// above it.
public struct VolumeSectionPage: Codable, Equatable, Sendable {
    public struct Ancestor: Codable, Equatable, Sendable {
        public var sectionId: String
        public var title: String
    }

    public var volumeId: String
    public var volumeTitle: String
    public var section: Volume.Section
    /// The sections above it, outermost first.
    public var path: [Ancestor]
    /// The row the index holds for the text the section prints outside the documents and sections
    /// it holds, which the app's Browse lists first, above them (`VolumeSection.ownTextEntry(among:)`);
    /// absent when it holds none.
    public var ownText: SectionDocument?
    public var documents: [SectionDocument]
    public var structureSource: String
}

/// A document in a section's list: the index's entry when it holds the document, else what the
/// TEI's parse gives, its header the kit's label for a document by its number ("Document 3") and its
/// name the head the reader heads it by (`parsedTitle(of:)`), so the row reads as the heading it opens.
public struct SectionDocument: Codable, Equatable, Sendable {
    public var documentId: String
    public var header: String
    /// What the list calls it (`displayTitle(header:documentNumber:isEditorialNote:documentId:)`).
    public var displayTitle: String
    public var documentNumber: String?
    public var dateline: String?
    public var isEditorialNote: Bool
    public var inIndex: Bool
    /// Whether the reader can open it; absent when the TEI is not mounted.
    public var readable: Bool?

    init(_ entry: DocumentBrowserEntry, readable: Bool?) {
        documentId = entry.documentId
        header = entry.header
        documentNumber = entry.documentNumber
        dateline = entry.dateline
        isEditorialNote = entry.isEditorialNote
        displayTitle = FRUSLightAPI.displayTitle(header: header, documentNumber: documentNumber,
                                                 isEditorialNote: isEditorialNote, documentId: documentId)
        inIndex = true
        self.readable = readable
    }

    init(documentId: String, ast: FRUSDocumentAST?, structure: [VolumeSection], readable: Bool?) {
        self.documentId = documentId
        header = teiHeader(documentId: documentId, printed: ast?.printedNumber, structure: structure)
        documentNumber = CitableDocumentNumber.resolve(printed: ast?.printedNumber, documentId: documentId)
        isEditorialNote = ast?.isShapedAsEditorialNote ?? false
        displayTitle = ast.flatMap(parsedTitle(of:))
            ?? FRUSLightAPI.displayTitle(header: header, documentNumber: documentNumber,
                                         isEditorialNote: isEditorialNote, documentId: documentId)
        inIndex = false
        self.readable = readable
    }
}

/// What a list calls a document: the kit's `DocumentDisplayTitle`, from its header, number and
/// classification. A printed head names it, unless it is an editorial note's head that says only what
/// it is ("Editorial Note"), when the note is named by its number ("Editorial Note 304"); a document
/// with no head and no note's flag is named by its id. The app's Research, working-corpus and cluster
/// lists name a document by it, and its reader's title too. Its Browse rows print the stored head
/// (`DocumentRowLabel`), which for 2,560 notes is only "Editorial Note"; Browse here takes the kit's
/// rule instead, so a row reads as the heading of the reader it opens.
func displayTitle(header: String, documentNumber: String?, isEditorialNote: Bool, documentId: String) -> String {
    // An empty header is none, as the app's `CrossReferenceStore.documentHeaders(for:)` leaves it out.
    DocumentDisplayTitle.text(.init(header: header.isEmpty ? nil : header, documentNumber: documentNumber,
                                    isEditorialNote: isEditorialNote),
                              documentId: documentId)
}

extension VolumeSectionPage: ResponseEncodable {}

/// A volume's reading order, from the index: its front matter, documents and back matter as
/// `readingSequence(forVolume:)` walks its structure, and which of them the index holds.
struct VolumeBrowse {
    let sequence: [DocumentBrowserEntry]
    let indexed: Set<String>

    init(_ volumeId: String, served: ServedIndex) async throws {
        sequence = try await served.pipeline.readingSequence(forVolume: volumeId)
        indexed = Set(try await served.pipeline.documents(forVolume: volumeId).map(\.documentId))
    }

    /// The entries before and after `documentId` in the reading order, none where it is not in it, each
    /// marked with whether the reader of `parsed`'s volume opens it, unknown without the TEI.
    func neighbours(of documentId: String, readable parsed: ReaderService.ParsedVolume?)
        -> (previous: DocumentDetail.Neighbour?, next: DocumentDetail.Neighbour?) {
        guard let position = sequence.firstIndex(where: { $0.documentId == documentId }) else { return (nil, nil) }
        func neighbour(_ offset: Int) -> DocumentDetail.Neighbour? {
            guard sequence.indices.contains(position + offset) else { return nil }
            let other = sequence[position + offset]
            return DocumentDetail.Neighbour(documentId: other.documentId, header: other.header,
                                            inIndex: indexed.contains(other.documentId),
                                            readable: parsed.map { $0.opens(other.documentId) })
        }
        return (neighbour(-1), neighbour(1))
    }
}

/// A document in a volume's list: the draft's `DocumentBrowserEntry`, and whether the index holds
/// it. An entry the index does not hold, such as a front-matter section, comes from the volume's
/// structure and has no number, dateline or source note.
public struct DocumentEntry: Codable, Equatable, Sendable {
    public var documentId: String
    public var volumeId: String
    public var documentNumber: String?
    public var header: String
    /// What a list calls it, and the reader's heading
    /// (`displayTitle(header:documentNumber:isEditorialNote:documentId:)`); for a document the index
    /// does not hold, the reader's heading is its parsed head (`DocumentDetail(teiOnly:)`).
    public var displayTitle: String
    public var dateline: String?
    public var sourceNote: String?
    public var dateISO: String?
    public private(set) var isEditorialNote: Bool
    public var inIndex: Bool

    init(documentId: String, volumeId: String, documentNumber: String?, header: String, isEditorialNote: Bool, inIndex: Bool) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.documentNumber = documentNumber
        self.header = header
        self.isEditorialNote = isEditorialNote
        self.inIndex = inIndex
        displayTitle = FRUSLightAPI.displayTitle(header: header, documentNumber: documentNumber,
                                                 isEditorialNote: isEditorialNote, documentId: documentId)
    }

    init(_ entry: DocumentBrowserEntry, inIndex: Bool, dateISO: String?) {
        documentId = entry.documentId
        volumeId = entry.volumeId
        documentNumber = entry.documentNumber
        header = entry.header
        dateline = entry.dateline
        sourceNote = entry.sourceNote
        self.dateISO = dateISO
        isEditorialNote = entry.isEditorialNote
        self.inIndex = inIndex
        displayTitle = FRUSLightAPI.displayTitle(header: header, documentNumber: documentNumber,
                                                 isEditorialNote: isEditorialNote, documentId: documentId)
    }

    /// Takes a classification, such as the index's effective one, and the title that goes with it.
    mutating func classify(asEditorialNote isEditorialNote: Bool) {
        self.isEditorialNote = isEditorialNote
        displayTitle = FRUSLightAPI.displayTitle(header: header, documentNumber: documentNumber,
                                                 isEditorialNote: isEditorialNote, documentId: documentId)
    }
}

/// A page of a volume's documents, in reading order.
public struct DocumentList: Codable, Equatable, Sendable {
    public var total: Int
    public var limit: Int
    public var offset: Int
    public var items: [DocumentEntry]
    public var coverage: Coverage
}

/// One document's metadata, in place of the draft's render model, which the kit cannot encode: the
/// reader's HTML is `…/html`. `isEditorialNote` is the index's effective classification, which the
/// owner's corrections keep current.
public struct DocumentDetail: Codable, Equatable, Sendable {
    public struct Neighbour: Codable, Equatable, Sendable {
        public var documentId: String
        public var header: String
        public var inIndex: Bool
        /// Whether the reader can open it; absent when the TEI is not mounted. The reader opens every
        /// entry of the reading order its volume's TEI holds, the lists of names and of sources and a
        /// subseries' list of volumes among them, which the app's reader turns to as printed pages
        /// (`ReaderService.sectionsReadAlone`), so this is false only for an entry the mounted TEI does
        /// not hold, such as one of an index made from another copy of the volume.
        public var readable: Bool?
    }

    public var document: DocumentEntry
    /// The document's page on history.state.gov; absent for a side-loaded volume's (PLAN's S21e).
    public var canonicalURL: String?
    /// The entries before and after it in the volume's reading order.
    public var previous: Neighbour?
    public var next: Neighbour?
    public var teiAvailable: Bool
}

/// How an entry the index does not hold is named from the TEI. A document with a number is named as
/// the kit names one by its number ("Document 3"); a section the parse makes a document, such as a
/// preface, by its title, as the kit's reading order names an entry the index lacks
/// (`IndexingPipeline.mergeReadingSequence`); anything else by the kit's row label.
func teiHeader(documentId: String, printed: String?, structure: [VolumeSection]) -> String {
    if CitableDocumentNumber.resolve(printed: printed, documentId: documentId) == nil,
       let (section, _) = VolumeContents.find(documentId, in: structure) {
        return section.title
    }
    return CitableDocumentNumber.rowLabel(printed: printed, documentId: documentId)
}

/// The title the app's reader gives a document it parsed (`DocumentViewModel.load`): the kit's display
/// title of the head `IndexingPipeline.extractHeader(from:)` reads from the TEI, which is the header the
/// index would store, with the number the document prints; none for a document with no head that is not
/// shaped as an editorial note, which the reader leaves to the title it was opened with. The reader's
/// heading for a document the index does not hold and History's title of a visit to one both take it
/// (S25c), so the two name it alike. The app's number falls back to the first head that begins with one
/// (`extractDocumentNumber(from:)`, public since FRUS-Explorer#1902, for a follow-up to adopt here), which
/// a title shows only for a note with no `@n` whose first head names nothing; every shipped document
/// carries `@n`, as that rule's own doc says, so the server takes `printedNumber` alone.
func parsedTitle(of ast: FRUSDocumentAST) -> String? {
    let extracted = IndexingPipeline.extractHeader(from: ast.nodes)
    let isEditorialNote = ast.isShapedAsEditorialNote
    guard !extracted.isEmpty || isEditorialNote else { return nil }
    return displayTitle(header: extracted, documentNumber: ast.printedNumber, isEditorialNote: isEditorialNote,
                        documentId: ast.documentId)
}

extension DocumentDetail {
    /// A document the index does not hold, or any while none is served, as the app's reader names a
    /// document it parsed: by its parsed head (`parsedTitle(of:)`), "Index" for a back-of-volume index,
    /// and by its label from the TEI (`teiHeader`), a section's title or "Document 3", where it has no
    /// head and no note's shape, as the app's reader keeps the title Browse opened it with. Its header
    /// is that label. No neighbours: the route adds them where the index's reading order holds it.
    init(teiOnly ast: FRUSDocumentAST, structure: [VolumeSection], volumeId: String) {
        let number = CitableDocumentNumber.resolve(printed: ast.printedNumber, documentId: ast.documentId)
        document = DocumentEntry(documentId: ast.documentId, volumeId: volumeId, documentNumber: number,
                                 header: teiHeader(documentId: ast.documentId, printed: ast.printedNumber, structure: structure),
                                 isEditorialNote: ast.isShapedAsEditorialNote, inIndex: false)
        if let title = parsedTitle(of: ast) { document.displayTitle = title }
        canonicalURL = FRUSCanonicalURL.string(volumeId: volumeId, documentId: ast.documentId)
        teiAvailable = true
    }
}

extension DocumentList: ResponseEncodable {}
extension DocumentDetail: ResponseEncodable {}
