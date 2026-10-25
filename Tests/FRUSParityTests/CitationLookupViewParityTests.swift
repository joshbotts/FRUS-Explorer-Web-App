// The app's words and the few lines of its Citation Lookup view that the browser app takes (PLAN's
// S19a, and PLAN's rule for view code: "mirrored with a parity test that reads the app's source at
// the pin"), read from the app's source, the kit's and web/src at once: the window's words, Search's
// Find by Citation and the kit's names for the modes, each in copy.ts's `lookup` block; its format
// strings as functions; and, in web/src/lookup, the modes' order, each result's colour, symbol,
// headline and action, a Batch row's label, colour and symbol, the row a tap opens, and Needs work
// first's order. A pin move that changes one fails here until the web follows it. Every label of a
// match and every count is the kit's, which the server sends: CitationLookupAPIParityTests holds those.

import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct CitationLookupViewParityTests {
    static let view = "Citation/CitationLookupView.swift"

    /// The app's words the browser app takes, each where the app's source writes it, under its key,
    /// and in copy.ts's `lookup` block under the key the UI reads.
    @Test func theAppsWordsAreTheWebs() throws {
        let copy = try NoteViewParityTests.block("lookup", of: try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts"))
        let words: [(file: String, key: String, value: String, web: String)] = [
            (Self.view, "citation.lookup.title", "Citation Lookup", "title"),
            (Self.view, "citation.mode.label", "Input mode", "mode"),
            (Self.view, "citation.paste.header", "Citation Text", "pasteHeader"),
            (Self.view, "citation.paste.placeholder", "Paste a FRUS citation…", "pastePlaceholder"),
            (Self.view, "citation.batch.header", "Footnotes", "batchHeader"),
            (Self.view, "citation.batch.footer",
             "Paste a chapter’s footnotes. Numbered notes are split on their numbers, and a note wrapped across lines is rejoined; an unnumbered list is one citation per line.",
             "batchFooter"),
            (Self.view, "citation.fields.header", "Parsed Fields", "fieldsHeader"),
            (Self.view, "citation.fields.footer", "Provide at least a document number, page number, or volume to search.", "fieldsFooter"),
            (Self.view, "citation.field.subseries", "Subseries", "subseries"),
            (Self.view, "citation.field.subseries.placeholder", "e.g. 1969-76", "subseriesPlaceholder"),
            (Self.view, "citation.field.volume", "Volume", "volume"),
            (Self.view, "citation.field.volume.placeholder", "e.g. I or 1", "volumePlaceholder"),
            (Self.view, "citation.field.part", "Part", "part"),
            (Self.view, "citation.field.part.placeholder", "e.g. 1 or I", "partPlaceholder"),
            (Self.view, "citation.field.document", "Document no.", "document"),
            (Self.view, "citation.field.document.placeholder", "e.g. 15", "documentPlaceholder"),
            (Self.view, "citation.field.page", "Page", "page"),
            (Self.view, "citation.field.page.placeholder", "e.g. 47", "pagePlaceholder"),
            (Self.view, "citation.lookup.button", "Look Up", "lookUp"),
            (Self.view, "citation.lookup.button.help", "Resolve the citation to matching FRUS documents", "lookUpHelp"),
            (Self.view, "citation.lookup.searching", "Looking up…", "searching"),
            (Self.view, "citation.error.title", "Lookup Error", "errorTitle"),
            (Self.view, "citation.noMatch.title", "No Matches Found", "noMatchTitle"),
            (Self.view, "citation.noMatch.detail",
             "No FRUS documents matched the provided citation. Check the subseries and volume, then try again.", "noMatchDetail"),
            (Self.view, "citation.result.view", "View Document", "viewDocument"),
            (Self.view, "citation.result.view.help", "Open this document", "viewDocumentHelp"),
            (Self.view, "citation.batch.empty.title", "Nothing to Triage", "batchEmptyTitle"),
            (Self.view, "citation.batch.empty.detail", "No citations were found in that text.", "batchEmptyDetail"),
            (Self.view, "citation.batch.sort", "Needs work first", "needsWorkFirst"),
            (Self.view, "citation.batch.missing", "No match", "noMatch"),
            ("App/SearchSheet.swift", "search.citationLookup.button", "Find by Citation", "findByCitation"),
            ("App/SearchSheet.swift", "search.citationLookup.help",
             "Resolve a pasted or manually entered FRUS citation to a specific document", "findByCitationHelp"),
        ]
        let sources = NoteViewParityTests.Sources()
        for word in words {
            #expect(NoteViewParityTests.writes(try sources.app(word.file), word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(copy.contains("\(word.web): '\(word.value)'"), "copy.lookup.\(word.web) is \(word.value)")
        }
        // The modes are named by the kit, `CitationLookupMode.label`.
        let models = NoteViewParityTests.flattened(try String(contentsOf: Self.kit("Citation/CitationModels.swift"), encoding: .utf8))
        for (key, value, web) in [("citation.mode.paste", "Paste Citation", "paste"), ("citation.mode.structured", "Structured Entry", "structured"),
                                  ("citation.mode.batch", "Batch", "batch")] {
            #expect(NoteViewParityTests.writes(models, key, value), "CitationModels.swift writes \(key) as \(value)")
            #expect(copy.contains("\(web): '\(value)'"), "copy.lookup.modes.\(web) is \(value)")
        }
    }

    /// The window's format strings, each a function in copy.ts that writes what the format writes: a
    /// `%lld` ungrouped, as `String(format:)` prints it, and a count interpolated into a localized
    /// string, which a count this small never groups.
    @Test func theAppsFormatsAreTheWebs() throws {
        let copy = try NoteViewParityTests.block("lookup", of: try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts"))
        let formats: [(key: String, value: String, web: String)] = [
            ("citation.results.header", #"Results (\(matches.count) found)"#, "results: (count: number) => `Results (${count} found)`,"),
            ("citation.results.count.a11y", "%lld matches found", "matchesFound: (count: number) => `${count} matches found`,"),
            ("citation.batch.resolved %@", "Resolved — %@", "resolved: (identity: string) => `Resolved — ${identity}`,"),
            ("citation.batch.ambiguous %lld", "%lld possible documents", "possibleDocuments: (count: number) => `${count} possible documents`,"),
        ]
        let view = try NoteViewParityTests.Sources().app(Self.view)
        for format in formats {
            #expect(NoteViewParityTests.writes(view, format.key, format.value), "\(Self.view) writes \(format.key) as \(format.value)")
            #expect(copy.contains(NoteViewParityTests.flattened(format.web)), "copy.lookup holds \(format.web)")
        }
        // A resolved row names its match by its volume and its document.
        #expect(view.contains(#"row.primaryMatch.map { "\($0.volumeId) \($0.documentId)" } ?? """#))
        NoteViewParityTests.expect(try NoteViewParityTests.Sources().web("lookup/lookupRules.ts"), holds: [
            "copy.lookup.resolved(primary ? `${primary.volumeId} ${primary.documentId}` : '')",
        ], file: "lookupRules.ts")
    }

    /// Each result as the app's result row draws it, and the triage table as the app's lays it out, in
    /// web/src/lookup: every strategy's colour and symbol; the volume's title and id for a row naming
    /// a volume, else the document's id and the volume's; a volume to download's own action, else View
    /// Document for a document, else none; each outcome's label, colour and symbol, a lone candidate's
    /// own label in place of a count; the row a tap opens; Needs work first, on at first, by the kit's
    /// triage order and the paste's within one; the modes in the kit's order; and Parsed Fields shown
    /// in every mode but Batch.
    @Test func theResultRowAndTheTableAreTheApps() throws {
        let sources = NoteViewParityTests.Sources()
        let view = try sources.app(Self.view)
        let rules = try sources.web("lookup/lookupRules.ts")

        // The app's two switches over a match's strategy, read case by case.
        func cases(of function: String) throws -> [String: String] {
            let start = try #require(view.range(of: "private var \(function):"), "\(function) is in \(Self.view)")
            let body = view[start.upperBound...].prefix { $0 != "}" }
            var found: [String: String] = [:]
            for part in body.components(separatedBy: "case .").dropFirst() {
                let pieces = part.components(separatedBy: ": return ")
                guard pieces.count == 2 else { continue }
                found[pieces[0]] = pieces[1].trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".\""))
                    .components(separatedBy: CharacterSet(charactersIn: "\" ")).first
            }
            return found
        }
        let colours = try cases(of: "confidenceLabelColor")
        let symbols = try cases(of: "confidenceLabelIcon")
        let strategies = ["exactDocumentNumber", "pageRange", "sharedPage", "superimposedDocumentNumber", "titleFragmentMatch", "manifestOnly", "bestGuess"]
        #expect(Set(colours.keys) == Set(strategies) && Set(symbols.keys) == Set(strategies), "\(colours) \(symbols)")
        for strategy in strategies {
            let line = "\(strategy): { tone: '\(colours[strategy] ?? "")', symbol: '\(symbols[strategy] ?? "")' },"
            #expect(rules.contains(line), "lookupRules.ts holds \(line)")
        }

        NoteViewParityTests.expect(view, holds: [
            "if let entry = match.volumeManifestEntry { // Manifest-only result Text(entry.title)",
            "Text(entry.volumeId) .font(.caption)",
            "} else { Text(match.documentId) .font(.headline) Text(match.volumeId)",
            "if let note = match.correctionNote {",
            "if match.requiresDownload { Button { onDownload() }",
            "} else if !match.documentId.isEmpty { Button { onNavigate() }",
            #"case .resolved: Label(String(format: String(localized: "citation.batch.resolved %@", defaultValue: "Resolved — %@"), row.primaryMatch.map { "\($0.volumeId) \($0.documentId)" } ?? ""), systemImage: "checkmark.circle.fill") .font(.caption).foregroundStyle(.green)"#,
            #"case .ambiguous(let count): // A lone candidate the engine does not vouch for says what it is (#1474). Label(row.loneCandidateLabel ?? String(format: String(localized: "citation.batch.ambiguous %lld", defaultValue: "%lld possible documents"), Int64(count)), systemImage: "questionmark.circle.fill") .font(.caption).foregroundStyle(.orange)"#,
            #"Label(row.loneCandidateLabel ?? "", systemImage: "lightbulb") .font(.caption).foregroundStyle(.orange)"#,
            #"case .missing: Label(String(localized: "citation.batch.missing", defaultValue: "No match"), systemImage: "minus.circle") .font(.caption).foregroundStyle(.secondary)"#,
            #"Label(reason, systemImage: "exclamationmark.triangle.fill") .font(.caption).foregroundStyle(.red)"#,
            "Text(verbatim: row.entry.marker ?? \"\\(row.entry.index)\")",
            "if let match = row.primaryMatch { openMatch(match) }",
            "guard !match.documentId.isEmpty else { return }",
            "@State private var batchTriageSort: Bool = true",
            "$0.element.outcome.triageOrder == $1.element.outcome.triageOrder ? $0.offset < $1.offset : $0.element.outcome.triageOrder < $1.element.outcome.triageOrder",
            "if mode.showsParsedFields { parsedFieldsSection }",
        ], file: Self.view)
        NoteViewParityTests.expect(rules, holds: [
            "if (match.requiresDownload) return 'volume'; return match.documentId !== '' ? 'document' : null;",
            "return primary && primary.documentId !== '' ? primary : undefined;",
            "return { label: copy.lookup.resolved(primary ? `${primary.volumeId} ${primary.documentId}` : ''), tone: 'green', symbol: 'checkmark.circle.fill' };",
            "return { label: row.loneCandidateLabel ?? copy.lookup.possibleDocuments(row.count ?? 0), tone: 'orange', symbol: 'questionmark.circle.fill' };",
            "return { label: row.loneCandidateLabel ?? '', tone: 'orange', symbol: 'lightbulb' };",
            "return { label: copy.lookup.noMatch, tone: 'secondary', symbol: 'minus.circle' };",
            "return { label: row.reason ?? '', tone: 'red', symbol: 'exclamationmark.triangle.fill' };",
            "if (!needsWorkFirst) return [...rows];",
            ".sort((a, b) => (a.row.triageOrder === b.row.triageOrder ? a.offset - b.offset : a.row.triageOrder - b.row.triageOrder))",
        ], file: "lookupRules.ts")
        NoteViewParityTests.expect(try sources.web("lookup/LookupScreen.tsx"), holds: [
            "const modes: CitationLookupMode[] = ['paste', 'structured', 'batch'];",
            "const title = entry ? plainTitle(entry.title) : match.documentId;",
            "const volumeId = entry?.volumeId ?? match.volumeId;",
            "{match.correctionNote && <p className=\"match-note\">{match.correctionNote}</p>}",
            "<span className=\"batch-marker\">{row.marker ?? row.index}</span>",
            "{form.mode !== 'batch' && <ParsedFields fields={shownFields(form)} />}",
        ], file: "LookupScreen.tsx")
        #expect(try sources.web("lookup/lookupState.ts").contains("needsWorkFirst: true };"))

        // The kit's order of the modes, and the rule that Batch alone shows no Parsed Fields.
        let models = NoteViewParityTests.flattened(try String(contentsOf: Self.kit("Citation/CitationModels.swift"), encoding: .utf8))
        #expect(models.contains("public enum CitationLookupMode: Sendable, CaseIterable, Equatable { case paste case structured /// A pasted block of footnotes, triaged as a table (#263). case batch"))
        #expect(models.contains("public var showsParsedFields: Bool { self != .batch }"))
    }

    /// A file of the kit's, from the submodule.
    static func kit(_ path: String) -> URL {
        RepositoryFiles.root.appendingPathComponent("upstream/FRUS-Explorer/FRUSCoreKit").appendingPathComponent(path)
    }
}
