// The few lines of the app's model and export code that the server's notes and summaries mirror
// (PLAN's S15d, and PLAN's rule for app code: "mirrored with a parity test that reads the app's
// source at the pin"), read from the app's source and held against the mirror's behaviour:
// `GeneratedSummary.ranksAbove` and `newestNonDraftPerDocument`, which `SummaryOrder` and
// `UserSearchText.summaryText` mirror; `ResearchNote.indexedTextPerDocument`, which
// `UserSearchText.noteText` mirrors; the headnote prompt id the web's own summaries must never take;
// the kit's summary types, whose encoding the store keeps; the rule that names a summary's prompt;
// the editor's rules for a body, its RTF kept until an edit, a highlight's link and a delete; the
// Markdown exporter's citation; and CollectionProse's paragraphs and colours, which the golden spans'
// mirror and the codec follow. A pin move that changes one fails here until the server follows it.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import ParityFormat
import Testing

@testable import FRUSLightAPI
@testable import FRUSRichText

@Suite struct NotesAndSummariesParityTests {
    static let app = RepositoryFiles.root.appendingPathComponent("upstream/FRUS-Explorer/FRUSExplorer")

    static func read(_ path: String) throws -> String {
        try String(contentsOf: app.appendingPathComponent(path), encoding: .utf8)
    }

    /// The statements of a function's body, each with its run of white space read as one space.
    static func body(of signature: String, in source: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> [String] {
        let found = try #require(source.range(of: signature), "\(signature)", sourceLocation: sourceLocation)
        // A signature that does not end at its brace, as one over several lines, runs to the first.
        var start = found.upperBound
        if !signature.hasSuffix("{") {
            start = try #require(source[start...].firstIndex(of: "{"), sourceLocation: sourceLocation)
            start = source.index(after: start)
        }
        var depth = 0
        var text = ""
        for character in source[start...] {
            if character == "{" { depth += 1 }
            if character == "}" {
                if depth == 0 { break }
                depth -= 1
            }
            text.append(character)
        }
        return text.split(separator: "\n").map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    static func summary(_ id: String, created: Double?, modified: Double?, draft: Bool = false, text: String = "") -> SummaryRecord {
        SummaryRecord(id: id, volumeId: "v", documentId: "d", promptId: "", responseText: text, responseFormat: "", wasChunked: false,
                      authorship: nil, isHeadnoteDraft: draft, sourceContentHash: nil, projectId: nil,
                      createdAt: created.map(Date.init(timeIntervalSince1970:)), lastModified: modified.map(Date.init(timeIntervalSince1970:)))
    }

    static func note(_ id: String, _ body: String, created: Double?) -> NoteRecord {
        NoteRecord(id: id, volumeId: "v", documentId: "d", bodyText: body, richText: nil, projectIds: [], userTagIds: [],
                   selectedSummaryIds: [], createdAt: created.map(Date.init(timeIntervalSince1970:)), lastModified: nil)
    }

    /// `SummaryOrder.ranksAbove` is the app's, statement for statement, and orders as it does: by
    /// `createdAt`, one with none last, then `lastModified`, then the id in uppercase.
    @Test func summariesAreOrderedByTheAppsRanksAbove() throws {
        let source = try Self.read("Models/GeneratedSummary.swift")
        #expect(try Self.body(of: "static func ranksAbove(_ a: GeneratedSummary, _ b: GeneratedSummary) -> Bool {", in: source) == [
            "let ca = a.createdAt ?? .distantPast, cb = b.createdAt ?? .distantPast",
            "if ca != cb { return ca > cb }",
            "let la = a.lastModified ?? .distantPast, lb = b.lastModified ?? .distantPast",
            "if la != lb { return la > lb }",
            "return a.id.uuidString < b.id.uuidString",
        ])
        let samples = [
            Self.summary("10000000-0000-4000-8000-000000000001", created: 300, modified: 0),
            Self.summary("20000000-0000-4000-8000-000000000002", created: 200, modified: 500),
            Self.summary("30000000-0000-4000-8000-000000000003", created: 200, modified: 400),
            // Tied, a lowercase id goes as its uppercase `uuidString`: "a…" before "B…", which ids
            // compared as written would put the other way.
            Self.summary("a0000000-0000-4000-8000-00000000000a", created: 200, modified: nil),
            Self.summary("B0000000-0000-4000-8000-00000000000B", created: 200, modified: nil),
            Self.summary("40000000-0000-4000-8000-000000000004", created: nil, modified: 900),
            Self.summary("50000000-0000-4000-8000-000000000005", created: nil, modified: nil),
        ]
        #expect(samples.reversed().sorted(by: SummaryOrder.ranksAbove).map(\.id) == samples.map(\.id))
        // The carousel shows non-drafts, 20 at most, in this order.
        let carousel = Self.flattened(try Self.read("DocumentView/DocumentViewModel.swift"))
        #expect(carousel.contains("!s.isHeadnoteDraft") && carousel.contains("descriptor.fetchLimit = 20"))
    }

    /// `UserSearchText.summaryText` is `newestNonDraftPerDocument` for one document: the newest by
    /// `ranksAbove` that is no headnote draft, and none when every one is (`draftOnlyDocuments`).
    @Test func searchTakesTheNewestSummaryButADraftAsTheAppDoes() throws {
        let source = try Self.read("Models/GeneratedSummary.swift")
        let newest = try Self.body(of: "static func newestNonDraftPerDocument(_ summaries: [GeneratedSummary]) -> [GeneratedSummary] {",
                                   in: source)
        #expect(newest == [
            "var best: [String: GeneratedSummary] = [:]",
            "for s in summaries where !s.isHeadnoteDraft && !s.volumeId.isEmpty && !s.documentId.isEmpty {",
            #"let key = "\(s.volumeId)/\(s.documentId)""#,
            "if let current = best[key], !Self.ranksAbove(s, current) { continue }",
            "best[key] = s",
            "}",
            "return best.keys.sorted().compactMap { best[$0] }",
        ])
        #expect(Self.flattened(source).contains("if !s.isHeadnoteDraft { hasLive.insert(key) }"), "a draft-only document is cleared")
        #expect(UserSearchText.summaryText([
            Self.summary("10000000-0000-4000-8000-000000000001", created: 100, modified: nil, text: "older"),
            Self.summary("20000000-0000-4000-8000-000000000002", created: 900, modified: nil, draft: true, text: "draft"),
            Self.summary("30000000-0000-4000-8000-000000000003", created: 200, modified: nil, text: "newest"),
        ]) == "newest")
        #expect(UserSearchText.summaryText([Self.summary("10000000-0000-4000-8000-000000000001", created: 1, modified: nil, draft: true)]) == nil)
    }

    /// `UserSearchText.noteText` is `indexedTextPerDocument` for one document: oldest first by
    /// `createdAt`, none first of all, then by `uuidString`; blank bodies left out; joined by the
    /// app's separator; none when nothing is left (`noteTextWrite`'s `.clear`).
    @Test func searchJoinsADocumentsNotesAsTheAppIndexesThem() throws {
        let source = try Self.read("Models/ResearchNote.swift")
        #expect(source.contains(#"static let indexedTextSeparator = "\n\n""#) && UserSearchText.separator == "\n\n")
        let joined = try Self.body(of: "static func indexedTextPerDocument(", in: source)
        for line in [
            "for note in notes where !note.volumeId.isEmpty && !note.documentId.isEmpty {",
            "let left = $0.createdAt ?? .distantPast",
            "let right = $1.createdAt ?? .distantPast",
            "if left != right { return left < right }",
            "return $0.id.uuidString < $1.id.uuidString",
            "let text = ordered.map(\\.bodyText)",
            ".filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }",
            ".joined(separator: indexedTextSeparator)",
            "guard !text.isEmpty else { return nil }",
        ] {
            #expect(joined.contains(line), "\(line)")
        }
        #expect(Self.flattened(source).contains("if let text = indexedTextPerDocument(notes).first?.text { return .write(text) } return .clear"))
        #expect(UserSearchText.noteText([
            Self.note("B0000000-0000-0000-0000-000000000000", "b", created: 50),
            Self.note("30000000-0000-0000-0000-000000000000", "later", created: 90),
            Self.note("a0000000-0000-0000-0000-000000000000", "a", created: 50),
            Self.note("C0000000-0000-0000-0000-000000000000", "undated", created: nil),
            Self.note("D0000000-0000-0000-0000-000000000000", " \n ", created: 10),
        ]) == "undated\n\na\n\nb\n\nlater")
        #expect(UserSearchText.noteText([Self.note("A0000000-0000-0000-0000-000000000000", "\t", created: 1)]) == nil)
    }

    /// The web's own summaries take a prompt id of their own: the app's headnote drafts carry its
    /// reserved one, which is how an import tells a draft from a document's summary in a file older
    /// than format 7. Their authorship and format are the kit's types, as the app writes them.
    @Test func theWebsOwnSummariesAreNotTheAppsHeadnoteDrafts() throws {
        let inspector = try Self.read("Collections/CollectionEntryInspector.swift")
        let reserved = try #require(inspector.firstMatch(of: /static let headnoteDraftPromptId = UUID\(uuidString: "([0-9A-F-]+)"\)!/)?.1)
        #expect(reserved == "0EAD0000-0000-4000-8000-000000000001")
        #expect(OwnSummary.promptId != String(reserved) && UUID(uuidString: OwnSummary.promptId)?.uuidString == OwnSummary.promptId)
        #expect(Self.flattened(inspector).contains("promptId: Self.headnoteDraftPromptId, responseText: text, authorship: authorship, isHeadnoteDraft: true)"))
        #expect(OwnSummary.authorship == SummaryAuthorship.userWritten.rawValue)
        #expect(SummaryAuthorship.allCases.map(\.rawValue) == ["aiGenerated", "aiEdited", "userWritten"])
        // The app's own JSON for a general summary's format, which the store keeps as the kit encodes it.
        let provenance = try String(contentsOf: RepositoryFiles.root.appendingPathComponent(
            "upstream/FRUS-Explorer/FRUSExplorerTests/SummaryProvenanceExportTests.swift"), encoding: .utf8)
        #expect(provenance.contains(#""responseFormat":{"general":{}}"#) && Summary.generalFormat == #"{"general":{}}"#)
        #expect(Summary.format(Summary.generalFormat) == "general")
        let structured = String(decoding: try JSONEncoder().encode(ResponseFormat.structured(schema: StructuredSummarySchema(
            fields: [.init(name: "People", description: "Who")]))), as: UTF8.self)
        #expect(Summary.format(structured) == "structured" && Summary.format("{}") == "unknown")
        // Nil authorship is the app's aiGenerated wherever it is read.
        let model = Self.flattened(try Self.read("Models/GeneratedSummary.swift"))
        #expect(model.contains("var authorship: SummaryAuthorship? = SummaryAuthorship.aiGenerated"))
        #expect(model.contains("authorship: draft.authorship ?? .aiGenerated"))
    }

    /// The editor's rules for the store: the note's RTF is the editor's from `load` until its view
    /// reports an edit, and Save writes it back, so a save that leaves the body keeps it byte for
    /// byte; a plain-mode edit, and a summary's insertion, drop it; Save links the highlight, if it
    /// is still there, by its `noteId`; and Delete deletes the note alone, the highlight's plain id
    /// left dangling.
    @Test func theEditorsRulesForTheBodyAndTheHighlightAreTheApps() throws {
        let model = try Self.read("ResearchNoteEditor/ResearchNoteEditorViewModel.swift")
        #expect(try Self.body(of: "func load(context: ModelContext) {", in: model).first == "richText = noteToEdit?.richText")
        let save = try Self.body(of: "func save(context: ModelContext) -> UUID? {", in: model)
        #expect(save.filter { $0 == "note.richText = richText" }.count == 2, "an existing note and a new one")
        #expect(try Self.body(of: "func setPlainBody(_ text: String) {", in: model) == ["bodyText = text", "richText = nil"])
        #expect(try Self.body(of: "func replaceBody(with text: String) {", in: model).contains("richText = nil"))
        let view = try Self.read("ResearchNoteEditor/ResearchNoteEditorView.swift")
        #expect(Self.flattened(view).contains(
            "RichTextEditor(initialRTF: vm.richText, plainFallback: vm.bodyText) { rtf, plain in vm.richText = rtf vm.bodyText = plain }"),
                "the formatted editor's edit, the one place the view writes the RTF")
        #expect(view.components(separatedBy: "vm.richText =").count == 2)
        let link = try Self.body(of: "private func linkNoteToHighlight(noteId: UUID) {", in: view)
        #expect(link.first == "guard let hlId = linkedHighlightId else { return }")
        #expect(link.contains("guard let highlight = try? modelContext.fetch(descriptor).first else { return }"))
        #expect(link.last == "highlight.noteId = noteId")
        #expect(try Self.withoutDebug(Self.body(of: "func delete(context: ModelContext) {", in: model))
            == ["guard let note = noteToEdit else { return }", "context.delete(note)"])
        #expect(try Self.read("Models/DocumentHighlight.swift").contains("var noteId: UUID? = nil"), "a plain id, no relationship")
    }

    /// A summary's prompt is named only when the prompt that made it is still the user's: the rail
    /// resolves the summary's own `promptId`, and only `.requested` has a `provenanceName`; a
    /// standard prompt that would remake it is never named. The API names it from the user's
    /// prompts by id, in any case, and otherwise not at all.
    @Test func aSummarysPromptIsNamedOnlyWhileItIsTheOneThatMadeIt() throws {
        let prompt = try Self.read("Models/SummarizationPrompt.swift")
        #expect(try Self.body(of: "var provenanceName: String? {", in: prompt) == [
            "if case .requested(let p) = self { return p.name }",
            "return nil",
        ])
        #expect(Self.flattened(prompt).contains(
            "if let id = preferredId, let prompt = (try? context.fetch( FetchDescriptor<SummarizationPrompt>(predicate: #Predicate { $0.id == id })))?.first { return .requested(prompt) }"))
        let rail = Self.flattened(try Self.read("App/SupportingViews.swift"))
        #expect(rail.contains("SummarizationPrompt.resolve(preferredId: vm.activeSummary?.promptId, in: modelContext)"))
        #expect(rail.contains("if vm.activeSummary != nil, let name = resolution.provenanceName {"))
        let record = SummaryRecord(id: "10000000-0000-4000-8000-000000000001", volumeId: "v", documentId: "d",
                                   promptId: "aa000000-0000-4000-8000-000000000001", responseText: "x", responseFormat: Summary.generalFormat,
                                   wasChunked: false, authorship: nil, isHeadnoteDraft: false, sourceContentHash: nil, projectId: nil,
                                   createdAt: nil, lastModified: nil)
        #expect(Summary(record, promptNames: ["AA000000-0000-4000-8000-000000000001": "Meeting Record"]).promptName == "Meeting Record")
        #expect(Summary(record, promptNames: ["BB000000-0000-4000-8000-000000000002": "Another"]).promptName == nil)
    }

    /// A function's statements without its `#if DEBUG` blocks.
    static func withoutDebug(_ lines: [String]) -> [String] {
        var kept: [String] = []
        var depth = 0
        for line in lines {
            if line == "#if DEBUG" { depth += 1; continue }
            if depth > 0, line == "#endif" { depth -= 1; continue }
            if depth == 0 { kept.append(line) }
        }
        return kept
    }

    /// The Markdown export's citation is the exporter's, of the index's row and the manifest's entry,
    /// and none without either; its tags' names keep the first of two; its files are the kit's.
    @Test func theExportsCitationIsTheExportersOwn() throws {
        let exporter = Self.flattened(try Self.read("Export/ResearchDataExporter.swift"))
        for line in ["let volumeEntry = appState.manifestStore.entry(forVolumeId: volumeId)",
                     "let documents = try? await pipeline.documents(forVolume: volumeId)",
                     "let documentEntry = documents.first(where: { $0.documentId == documentId })",
                     "return HistoryAtStateCitationFormatter().format( document: FRUSDocumentMetadata(citing: documentEntry, printedNumber: documentEntry.documentNumber), volume: FRUSVolumeMetadata(volumeEntry) )",
                     "let tagNamesById = Dictionary(tags.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })",
                     "ResearchNoteMarkdownExport.render( noteId: note.id, documentId: note.documentId, volumeId: note.volumeId, bodyText: note.bodyText, userTagIds: note.userTagIds, createdAt: note.createdAt, lastModified: note.lastModified, citation: citation,"] {
            #expect(exporter.contains(line), "\(line)")
        }
        let view = try Self.read("Export/ResearchDataExportView.swift")
        #expect(view.contains(#".appendingPathComponent("FRUSResearchNotes-\(UUID().uuidString)", isDirectory: true)"#))
        #expect(NotesExport.fileName == "FRUSResearchNotes.zip")
        let entry = DocumentBrowserEntry(documentId: "d1", volumeId: "frus1961-63v06", documentNumber: "1", header: "1. Telegram")
        let manifest = try #require(try ServerResources.load(from: RepositoryFiles.resources).volume("frus1961-63v06"))
        #expect(NotesExport.citation(of: "d1", among: [entry], volume: manifest) == HistoryAtStateCitationFormatter().format(
            document: FRUSDocumentMetadata(citing: entry, printedNumber: "1"), volume: FRUSVolumeMetadata(manifest)))
        #expect(NotesExport.citation(of: "d2", among: [entry], volume: manifest) == nil, "a document the index lacks")
        #expect(NotesExport.citation(of: "d1", among: nil, volume: manifest) == nil, "a volume not indexed")
        #expect(NotesExport.citation(of: "d1", among: [entry], volume: nil) == nil, "a volume not in the manifest")
    }

    /// `CollectionProse.append`, which `ProseParagraphs.paragraphs(of:)` mirrors, splits each run on
    /// blank lines by itself; `hex` reads a colour under 0.08 in every channel as none and truncates
    /// each channel to a byte, as `RTFColor.hex` does, of the colour in sRGB. The golden spans check
    /// the mirror against the app's paragraphs on every case once a Mac remakes them; this names the
    /// rule a pin move changes on Linux, before then.
    @Test func theAppsParagraphsAndColoursAreTheMirrors() throws {
        let source = try Self.read("Collections/CollectionExporter.swift")
        #expect(try Self.body(of: "private static func append(text: String, bold: Bool, italic: Bool, underline: Bool,", in: source) == [
            #"let parts = text.components(separatedBy: "\n\n")"#,
            "for (index, part) in parts.enumerated() {",
            "if index > 0 { paragraphs.append([]) } // a blank line starts a new paragraph",
            "if !part.isEmpty {",
            "paragraphs[paragraphs.count - 1].append(",
            "ProseFormattedSpan(text: part, bold: bold, italic: italic,",
            "underline: underline, colorHex: colorHex,",
            "linkURL: linkURL))",
            "}",
            "}",
        ])
        #expect(try Self.body(of: "private static func hex(r: CGFloat, g: CGFloat, b: CGFloat) -> String? {", in: source) == [
            "if r < 0.08, g < 0.08, b < 0.08 { return nil } // (near-)black default text",
            #"return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))"#,
        ])
        #expect(try Self.body(of: "private static func hexColor(_ color: NSColor) -> String? {", in: source) == [
            "guard let c = color.usingColorSpace(.sRGB) else { return nil }",
            "return hex(r: c.redComponent, g: c.greenComponent, b: c.blueComponent)",
        ])
        let bold = RichTextSpan(text: "\n\n", bold: true)
        #expect(ProseParagraphs.paragraphs(of: [RichTextSpan(text: "a\n\nb"), bold, RichTextSpan(text: "c")])
                == [[RichTextSpan(text: "a")], [RichTextSpan(text: "b")], [RichTextSpan(text: "c")]])
        #expect(ProseParagraphs.paragraphs(of: [RichTextSpan(text: "x\n"), RichTextSpan(text: "\ny")]).count == 1,
                "a blank line across two runs splits nothing")
        #expect(RTFColor.hex(0.079, 0.079, 0.079) == nil && RTFColor.hex(0.08, 0, 0) == "140000")
        #expect(RTFColor.hex(0.5, 0.25, 1.0) == "7F3FFF")
    }

    static func flattened(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
