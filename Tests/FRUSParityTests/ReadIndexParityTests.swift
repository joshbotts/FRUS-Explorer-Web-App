// The door the app's Browse opens a section's printed text by, and the reader behind it (S21b's
// follow-up): a section the kit's `VolumeSection.canReadDirectly` passes, a preface, a chapter of
// prose or, among the sections a full parse leaves out, a back-of-volume index and a table of
// contents, opens the reader on its id from its section's page, "Read" and its title, on the iPhone,
// the iPad and the Mac; the persons and sources lists open views of their own instead. The reader
// parses the one division (`parseDocument(documentId:volumeURL:)`, which `parseDocumentWindow`
// shares), and the kit captures a list it leaves out of the index whole, so the reader can open it.
// The server reads alone the same sections beside a full parse's documents
// (`ReaderService.sectionsReadAlone`), and the browser app's Browse links each to the reader. Read
// from the app's source and the web's at once, with the kit's sets compiled: a pin move that changes
// the door fails here until the web follows it.

@testable import FRUSCoreKit
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
    /// leaves out whole, so the reader opens a back-of-volume index or a table of contents by its id.
    @Test func theAppsReaderParsesTheSectionAlone() throws {
        NoteViewParityTests.expect(try SearchSetParityTests.app("DocumentView/DocumentViewModel.swift"), holds: [
            "return try await parser.parseDocument(documentId: entry.documentId, volumeURL: volumeURL)",
            "let window = try await parser.parseDocumentWindow( documentId: entry.documentId, volumeURL: volumeURL, trailingDocuments: 1 )",
        ], file: "DocumentViewModel.swift")
        let parser = try SearchSetParityTests.kit("FRUSCoreKit/TEI/FRUSDocumentParser.swift")
        NoteViewParityTests.expect(parser, holds: [
            "let delegate = try Self.parseTarget(documentId: documentId, volumeURL: volumeURL, trailingDocuments: 0)",
            "let delegate = try Self.parseTarget(documentId: documentId, volumeURL: volumeURL, trailingDocuments: trailingDocuments)",
            #"private static let listKinds: Set<String> = ["persons", "sources", "table-of-contents", "index"]"#,
            "// tables of its own (persons, sources, a table of contents, an index), a div of no",
            "let doc = FRUSDocumentAST(documentId: docId, nodes: frame.children)",
        ], file: "FRUSDocumentParser.swift")
    }

    /// The kit's sets, compiled: the Read door opens an index and a table of contents, which the index
    /// leaves out, so a full parse gives no document for them; not the persons and sources lists.
    @Test func theDoorOpensAnIndexAndATableOfContentsThatAFullParseLeavesOut() throws {
        for kind in ["index", "table-of-contents"] {
            #expect(VolumeSection.proseReadableKinds.contains(kind), "\(kind) opens by Read")
            #expect(VolumeSection(sectionId: kind, divType: kind, title: "", documentIds: [], subsections: []).canReadDirectly)
        }
        for kind in ["persons", "sources"] {
            #expect(!VolumeSection.proseReadableKinds.contains(kind), "\(kind) opens a view of its own")
        }
        NoteViewParityTests.expect(try SearchSetParityTests.kit("FRUSCoreKit/TEI/FRUSDocumentParser.swift"), holds: [
            "/// `\"table-of-contents\"`/`\"index\"` (navigation aids — page numbers and chapter",
        ], file: "FRUSDocumentParser.swift")
    }

    /// The server reads alone the sections the door opens that a full parse gives no document for, by
    /// the kit's parse of the one division, and Browse links a section the reader opens to it.
    @Test func theWebReadsTheSameSectionsAloneAndBrowseLinksThem() throws {
        NoteViewParityTests.expect(try SearchSetParityTests.server("Sources/FRUSLightAPI/Reader.swift"), holds: [
            "if section.canReadDirectly, !documents.contains(section.sectionId), seen.insert(section.sectionId).inserted {",
            "return try await FRUSDocumentParser().parseDocument(documentId: sectionId, volumeURL: url)",
            "sectionsReadAlone = Set(ReaderService.sectionsReadAlone(in: structure, documents: Set(documents.keys)))",
        ], file: "Reader.swift")
        NoteViewParityTests.expect(try SearchSetParityTests.server("Sources/FRUSLightAPI/Catalog.swift"), holds: [
            "var readerDocuments: Set<String>? { parsed.map(\\.readerIds) }",
            "readable = readerDocuments.map { $0.contains(section.sectionId) }",
        ], file: "Catalog.swift")
        NoteViewParityTests.expect(try SearchSetParityTests.web("browse/SectionTree.tsx"), holds: [
            "if (section.readable) { return ( <Link to=\"/doc/$volumeId/$documentId\" params={{ volumeId, documentId: section.sectionId }}> {title} </Link>",
        ], file: "SectionTree.tsx")
        // mac-golden's rows hold the same sections, by the same rule, so check 4 holds their pages.
        NoteViewParityTests.expect(NoteViewParityTests.flattened(try String(contentsOf: RepositoryFiles.root
            .appendingPathComponent("tools/mac-golden/Sources/mac-golden/Render.swift"), encoding: .utf8)), holds: [
            "if section.canReadDirectly, !documents.contains(section.sectionId), seen.insert(section.sectionId).inserted {",
            "for (index, document) in (documents + sections).enumerated() {",
        ], file: "tools/mac-golden Render.swift")
    }
}
