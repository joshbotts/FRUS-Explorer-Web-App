// The doors the app's reader opens a section's printed text by, and the reader behind them (S21b's
// follow-up, and its own follow-up). Browse's Read: a section the kit's `VolumeSection.canReadDirectly`
// passes, a preface, a chapter of prose or, among the sections a full parse leaves out, a
// back-of-volume index and a table of contents, opens the reader on its id from its section's page,
// "Read" and its title, on the iPhone, the iPad and the Mac; the persons and sources lists open views of
// their own instead. Previous and Next: the reader turns through the kit's reading order, which holds
// every leaf with an id of its own, those lists, a subseries' list of volumes, a table of citations.
// A link: a table of contents' entry, or any cross-reference, opens the reader on the id it names, a
// chapter that prints only its heading among them. Behind each, the reader parses the one division
// (`parseDocument(documentId:volumeURL:)`, which `parseDocumentWindow` shares), the kit capturing a
// list it leaves out of the index whole, and reading a division the index leaves out a second time,
// whole but for its documents. The server reads alone every section with an id of its own beside a full
// parse's documents (`ReaderService.sectionsReadAlone`), and the browser app's Browse links to the
// reader only those Read opens (`ReaderService.sectionsReadOpens`). Read from the app's source and the
// web's at once, with the kit's sets and reading order compiled: a pin move that changes a door fails
// here until the web follows it.

@testable import FRUSCoreKit
import FRUSLightAPI
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct ReadIndexParityTests {
    /// The app's Browse: a section `canReadDirectly` passes opens the reader on its id, under its title,
    /// before the persons and sources lists route to views of their own, in `CompilationView` and in the
    /// Mac's corpus browser alike.
    @Test func theAppsReadOpensASectionByItsIdInTheReader() throws {
        NoteViewParityTests.expect(try SearchSetParityTests.app("Browser/CompilationDocumentsPresentation.swift"), holds: [
            "if canReadDirectly { return .readDirectly } if isPersonsList { return .personsList } if isSourcesList { return .sourcesList }",
        ], file: "CompilationDocumentsPresentation.swift")
        let compilation = try SearchSetParityTests.app("Browser/CompilationView.swift")
        NoteViewParityTests.expect(compilation, holds: [
            "canReadDirectly: section.canReadDirectly, isPersonsList: section.isPersonsList, isSourcesList: section.isSourcesList,",
            "case .readDirectly: // Prose-only section (front matter, or a chapter of prose alone, #1535): open directly. readSectionDirectlySection",
            "case .personsList: // Persons list — rendered by FrontMatterPersonsView without requiring indexing. FrontMatterPersonsView(",
            "case .sourcesList: // Archival sources list — rendered by VolumeSourcesView from the indexed table. VolumeSourcesView(",
            "let entry = DocumentBrowserEntry( documentId: section.sectionId, volumeId: volumeId, documentNumber: nil, header: section.title,",
            #"format: String(localized: "browser.compilation.readSection", defaultValue: "Read %@"), section.title"#,
        ], file: "CompilationView.swift")
        NoteViewParityTests.expect(try SearchSetParityTests.app("App/MacCorpusBrowserWindow.swift"), holds: [
            "private var canReadSectionDirectly: Bool { section.canReadDirectly }",
            "if canReadSectionDirectly { proseSectionView } else if isPersonsSection {",
            "appState.openDocument(DocumentBrowserEntry( documentId: section.sectionId, volumeId: volumeId, documentNumber: nil, header: section.title,",
        ], file: "MacCorpusBrowserWindow.swift")
    }

    /// The app's reader parses the one division it is opened on, the window's parse or the plain one,
    /// which share their reading of the file (`parseTarget`), and the kit captures a list the index
    /// leaves out whole, so the reader opens a back-of-volume index or a table of contents by its id;
    /// a division the index leaves out, a chapter that prints nothing of its own but its heading, it
    /// reads a second time, deciding nothing inside it, and gives it whole but for its documents.
    @Test func theAppsReaderParsesTheSectionAlone() throws {
        NoteViewParityTests.expect(try SearchSetParityTests.app("DocumentView/DocumentViewModel.swift"), holds: [
            "return try await parser.parseDocument(documentId: entry.documentId, volumeURL: volumeURL)",
            "let window = try await parser.parseDocumentWindow( documentId: entry.documentId, volumeURL: volumeURL, trailingDocuments: 1 )",
        ], file: "DocumentViewModel.swift")
        let parser = try SearchSetParityTests.kit("FRUSCoreKit/TEI/FRUSDocumentParser.swift")
        NoteViewParityTests.expect(parser, holds: [
            "let delegate = try Self.parseTarget(documentId: documentId, volumeURL: volumeURL, trailingDocuments: 0)",
            "let delegate = try Self.parseTarget(documentId: documentId, volumeURL: volumeURL, trailingDocuments: trailingDocuments)",
            "return delegate.targetIsLeftOut ? try run(decidingTargetSection: false) : delegate",
            #"private static let listKinds: Set<String> = ["persons", "sources", "table-of-contents", "index"]"#,
            "// tables of its own (persons, sources, a table of contents, an index), a div of no",
            "// structural kind, or, on a second reading, a section the index leaves out",
            "// (`targetIsLeftOut`). Captured whole, with everything inside it but its documents,",
            "let doc = FRUSDocumentAST(documentId: docId, nodes: frame.children)",
        ], file: "FRUSDocumentParser.swift")
    }

    /// The app's reader turns its pages through the kit's reading order, which holds every leaf with an
    /// id of its own, synthesized from the outline where the index holds no row of it, and no
    /// container that prints nothing of its own; and both of the app's readers open a cross-reference's
    /// target, such as a table of contents' entry, on the id it names, whatever division it is.
    @Test func theAppsReaderTurnsToEveryLeafAndOpensWhatALinkNames() throws {
        NoteViewParityTests.expect(try SearchSetParityTests.app("DocumentView/DocumentViewModel.swift"), holds: [
            "if let docs = try? await pipeline.readingSequence(forVolume: entry.volumeId), let idx = docs.firstIndex(where: { $0.documentId == entry.documentId }) {",
            "previousEntry = idx > 0 ? docs[idx - 1] : nil nextEntry = idx + 1 < docs.count ? docs[idx + 1] : nil",
        ], file: "DocumentViewModel.swift")
        NoteViewParityTests.expect(try SearchSetParityTests.kit("FRUSCoreKit/Search/IndexingPipeline.swift"), holds: [
            "return Self.mergeReadingSequence(structure: structure, cached: cached, volumeId: volumeId)",
            "if let own = section.ownTextRowId, byId[own] != nil { append(id: own, fallbackTitle: section.title) }",
            "} else if section.hasExplicitSectionId { // Leaf section: prose front/back matter, or a structured / navigation // section (Persons, Sources, TOC, Index) opened as a quasi-document. append(id: section.sectionId, fallbackTitle: section.title)",
        ], file: "IndexingPipeline.swift")
        NoteViewParityTests.expect(try SearchSetParityTests.app("DocumentView/DocumentView.swift"), holds: [
            "let crossEntry = DocumentBrowserEntry( documentId: documentId, volumeId: volumeId, documentNumber: nil,",
            "onNavigateToDocument(crossEntry, .push)",
        ], file: "DocumentView.swift")
        NoteViewParityTests.expect(try SearchSetParityTests.app("App/MacDocumentView.swift"), holds: [
            "case .document(let targetVolumeId, let documentId): navigateToCrossRef(documentId: documentId, volumeId: targetVolumeId ?? entry.volumeId)",
            "let dest = DocumentBrowserEntry( documentId: documentId, volumeId: volumeId,",
            "navigationPath.append(dest)",
        ], file: "MacDocumentView.swift")
    }

    /// The kit's sets, compiled: the Read door opens an index, a table of contents and a division of
    /// the kind `section` (frus1958-60v05mSupp's seventeen take it from their subtype), the kinds Read
    /// opens that the index leaves out, so a full parse gives no document for them; not the persons and
    /// sources lists, and not a list of another name, such as frus1902app2's Table of Citations.
    @Test func theDoorOpensAnIndexAndATableOfContentsThatAFullParseLeavesOut() throws {
        for kind in ["index", "table-of-contents", "section"] {
            #expect(VolumeSection.proseReadableKinds.contains(kind), "\(kind) opens by Read")
            #expect(VolumeSection(sectionId: "s1", divType: kind, title: "", documentIds: [], subsections: []).canReadDirectly)
        }
        for kind in ["persons", "sources", "citations", "additional-volumes"] {
            #expect(!VolumeSection.proseReadableKinds.contains(kind), "\(kind) does not open by Read")
        }
        NoteViewParityTests.expect(try SearchSetParityTests.kit("FRUSCoreKit/TEI/FRUSDocumentParser.swift"), holds: [
            "/// `\"persons\"`/`\"sources\"` (structured data with dedicated views and tables),",
            "/// `\"table-of-contents\"`/`\"index\"` (navigation aids — page numbers and chapter",
            "/// titles would pollute search results), and `\"section\"` (unidentifiable).",
        ], file: "FRUSDocumentParser.swift")
    }

    /// The kit's reading order and the server's rules, compiled over one outline: every entry the order
    /// synthesizes for a leaf the index holds no row of is a section the server reads alone, which reads
    /// alone besides only the containers a link opens; a section with a generated id is in neither, as
    /// the `<front>` and `<back>` wrappers are not; and Browse links to the reader, of them, only those
    /// the app's Read opens, a table of contents and an index.
    @Test func theServerReadsAloneEveryLeafOfTheKitsReadingOrder() {
        func section(_ id: String, _ kind: String, documents: [String] = [], _ subsections: [VolumeSection] = []) -> VolumeSection {
            VolumeSection(sectionId: id, divType: kind, title: id, documentIds: documents, subsections: subsections)
        }
        let structure = [
            section("front-1", "front", [
                section("preface", "preface"), section("toc", "table-of-contents"), section("sources", "sources"),
                section("persons", "persons"), section("subseriesvols", "additional-volumes"), section("section-7", "section"),
            ]),
            section("comp1", "compilation", [section("ch1", "chapter", documents: ["d1", "d2"]), section("ch2", "chapter", documents: ["d3"])]),
            section("back-9", "back", [section("index", "index"), section("citations", "citations")]),
        ]
        // The index's rows: the documents, and the preface, which the index promotes.
        let rows = ["preface", "d1", "d2", "d3"].map { DocumentBrowserEntry(documentId: $0, volumeId: "v", header: $0) }
        let indexed = Set(rows.map(\.documentId))
        let order = IndexingPipeline.mergeReadingSequence(structure: VolumeStructure(volumeId: "v", sections: structure),
                                                          cached: rows, volumeId: "v").map(\.documentId)
        let synthesized = order.filter { !indexed.contains($0) }
        let alone = ReaderService.sectionsReadAlone(in: structure, documents: indexed)
        #expect(order == ["preface", "toc", "sources", "persons", "subseriesvols", "d1", "d2", "d3", "index", "citations"])
        #expect(synthesized == ["toc", "sources", "persons", "subseriesvols", "index", "citations"])
        #expect(alone == ["toc", "sources", "persons", "subseriesvols", "comp1", "ch1", "ch2", "index", "citations"])
        #expect(Set(alone).subtracting(synthesized) == ["comp1", "ch1", "ch2"], "besides the order's leaves, the containers a link opens")
        #expect(ReaderService.sectionsReadOpens(in: structure, documents: indexed) == ["toc", "index"])
    }

    /// The server reads alone every section with an id of its own beside a full parse's documents, by
    /// the kit's parse of the one division, and says the reader opens each of them where the reading
    /// order turns to it; Browse links to the reader only what Read opens, and the browser app's Browse
    /// links a section to the reader where the server says Browse opens it.
    @Test func theWebReadsTheSameSectionsAloneAndBrowseLinksOnlyWhatReadOpens() throws {
        NoteViewParityTests.expect(try SearchSetParityTests.server("Sources/FRUSLightAPI/Reader.swift"), holds: [
            "sections(in: structure, notIn: documents) { $0.hasExplicitSectionId }",
            "sections(in: structure, notIn: documents) { $0.canReadDirectly }",
            "if opens(section), !documents.contains(section.sectionId), seen.insert(section.sectionId).inserted {",
            "return try await FRUSDocumentParser().parseDocument(documentId: sectionId, volumeURL: url)",
            "sectionsReadAlone = Set(ReaderService.sectionsReadAlone(in: structure, documents: parsed))",
            "sectionsReadOpens = Set(ReaderService.sectionsReadOpens(in: structure, documents: parsed))",
            "func opens(_ id: String) -> Bool { documents[id] != nil || sectionsReadAlone.contains(id) }",
            "var browseReaderIds: Set<String> { Set(documents.keys).union(sectionsReadOpens) }",
        ], file: "Reader.swift")
        NoteViewParityTests.expect(try SearchSetParityTests.server("Sources/FRUSLightAPI/Catalog.swift"), holds: [
            "var browseOpens: Set<String>? { parsed.map(\\.browseReaderIds) }",
            "readable = browseOpens.map { $0.contains(section.sectionId) }",
            "readable: parsed.map { $0.opens(other.documentId) })",
        ], file: "Catalog.swift")
        NoteViewParityTests.expect(try SearchSetParityTests.web("browse/SectionTree.tsx"), holds: [
            "if (section.readable) { return ( <Link to=\"/doc/$volumeId/$documentId\" params={{ volumeId, documentId: section.sectionId }}> {title} </Link>",
        ], file: "SectionTree.tsx")
        NoteViewParityTests.expect(try SearchSetParityTests.web("reader/ReaderScreen.tsx"), holds: [
            "const previous = detail.data?.previous?.readable === false ? undefined : detail.data?.previous;",
            "const next = detail.data?.next?.readable === false ? undefined : detail.data?.next;",
        ], file: "ReaderScreen.tsx")
        // mac-golden's rows hold the same sections, by the same rule, so check 4 holds their pages.
        NoteViewParityTests.expect(NoteViewParityTests.flattened(try String(contentsOf: RepositoryFiles.root
            .appendingPathComponent("tools/mac-golden/Sources/mac-golden/Render.swift"), encoding: .utf8)), holds: [
            "if section.hasExplicitSectionId, !documents.contains(section.sectionId), seen.insert(section.sectionId).inserted {",
            "for (index, document) in (documents + sections).enumerated() {",
        ], file: "tools/mac-golden Render.swift")
    }
}
