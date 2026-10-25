// rich-text: the golden spans (S15d). The RTF the Mac's note editor writes for each formatting it
// offers, and the app's reading of that RTF, of hand-written RTF and of the RTF the web's codec
// writes, for the codec to match.

import AppKit
import Foundation
import FRUSRichText
import ParityFormat
@testable import FRUSExplorer

let richTextConfiguration = """
    Written cases drive the note editor's own path on macOS: an NSTextView set up as \
    RichTextPlatformEditor.makeNSView sets it (rich text, undo, the 13-point system font, its inset, no \
    background), loaded as initialAttributed() loads a note (the stored RTF, else the plain body), with \
    RichTextEditorController given the view as the representable gives it. Text is typed with \
    insertText(_:replacementRange:); bold, italic, underline and links go through the controller's \
    toggleBold(), toggleItalic(), toggleUnderline() and applyLink(_:) after refreshSelectionState(), as \
    the formatting bar's buttons call them; a colour is applied as colorPanelDidPick(_:) applies the \
    panel's colour, which mac-golden cannot open; text pasted with other attributes is inserted as an \
    attributed string. The RTF is what report(_:) stores on macOS: \
    RichTextRestingText.withBreaksRestored, then ProseRichText.rtfData(from:). Read and web cases are \
    files under fixtures/rich-text. Every case is read under the aqua appearance, since the app's reading \
    of a dynamic colour follows the appearance current when it runs: text is NSAttributedString.string \
    of ProseRichText.decodedRTF; runs are its enumerateAttributes runs, unmerged, each read by \
    CollectionProse's span rules (bold and italic from the font's symbolic traits, underline from a \
    nonzero underline style, the colour through usingColorSpace(.sRGB) with near-black as none, the \
    link's absoluteString or string); paragraphs are CollectionProse.paragraphs(fromRTF:). Catalog \
    colours are each key of the System colour list, as an RTF \\cname entry, read the same way. \
    Each written and read case is also rewritten: the web's codec (FRUSRichText) reads it, writes its \
    runs in canonical form with RTFWriter, as the server stores a web edit, and the app reads that RTF \
    the same way. Code pages are ParityFormat's RichTextCodePages documents, every text byte and \
    double-byte pair in a group of its own, read by ProseRichText.decodedRTF; the web's codec must read \
    each the same before its digest is recorded. \
    A release build of the app module, with testing enabled, compiled from the submodule unmodified.
    """

/// The repository paths a rich-text golden reads besides the cases written here.
enum RichTextPaths {
    static let harness = RichTextGolden.harnessPath
    static let read = RichTextGolden.readFolder
    static let webCases = RichTextWebCases.path
    static let golden = "fixtures/golden/" + GoldenFile.richText.rawValue
}

@MainActor
func richTextGolden(repo: Repository, out: URL) throws {
    let aqua = try NSAppearance(named: .aqua).orThrow("no aqua appearance")
    var cases: [RichTextCase] = []
    var catalog: [CatalogColor] = []
    var codePages: [RichTextCodePageReading] = []
    var inputs: [String: String] = [:]
    var failure: Error?
    aqua.performAsCurrentDrawingAppearance {
        do {
            for written in try writtenCases() {
                let rtf = try written.make()
                cases.append(try reading(id: written.id, kind: .written, source: nil, rtf: rtf))
            }
            let readFolder = repo.url(RichTextPaths.read)
            let readFiles = try FileManager.default.contentsOfDirectory(atPath: readFolder.path)
                .filter { $0.hasSuffix(".rtf") }.sorted()
            for name in readFiles {
                let path = "\(RichTextPaths.read)/\(name)"
                let data = try Data(contentsOf: repo.url(path))
                inputs[path] = Digest.sha256(data)
                cases.append(try reading(id: "read-" + String(name.dropLast(4)), kind: .read, source: path, rtf: data))
            }
            let webCasesURL = repo.url(RichTextPaths.webCases)
            inputs[RichTextPaths.webCases] = try Digest.sha256(contentsOf: webCasesURL)
            for web in try GoldenJSON.read(RichTextWebCases.self, from: webCasesURL).cases {
                let path = RichTextWebCases.rtfPath(web.id)
                let data = try Data(contentsOf: repo.url(path))
                inputs[path] = Digest.sha256(data)
                cases.append(try reading(id: "web-" + web.id, kind: .web, source: path, rtf: data))
            }
            catalog = try catalogColors()
            codePages = try codePageReadings()
        } catch {
            failure = error
        }
    }
    if let failure { throw failure }
    var ids = Set<String>()
    for item in cases where !ids.insert(item.id).inserted { throw ToolError("rich-text: case \(item.id) appears twice") }
    inputs[RichTextPaths.harness] = try Digest.sha256(contentsOf: repo.url(RichTextPaths.harness))

    let golden = RichTextGolden(
        provenance: try repo.provenance(tool: "tools/mac-golden rich-text", inputs: inputs),
        configuration: richTextConfiguration,
        appearance: NSAppearance.Name.aqua.rawValue,
        cases: cases,
        catalogColors: catalog,
        codePages: codePages
    )
    try GoldenJSON.write(golden, to: out)
    let counts = Dictionary(grouping: cases, by: \.kind).mapValues(\.count)
    note("rich-text: \(counts[.written] ?? 0) written, \(counts[.read] ?? 0) read and \(counts[.web] ?? 0) web cases, "
        + "\(catalog.count) catalog colours, \(codePages.count) code pages, to \(repo.relativePath(out))")
}

/// The app's reading of one RTF payload, checked against itself: the runs, split as
/// CollectionProse splits them, must give the app's own paragraphs.
@MainActor
private func reading(id: String, kind: RichTextCase.Kind, source: String?, rtf: Data) throws -> RichTextCase {
    guard let decoded = ProseRichText.decodedRTF(rtf) else {
        guard rtf.isEmpty else { throw ToolError("rich-text: \(id) is not RTF the app reads") }
        return RichTextCase(id: id, kind: kind, source: source, rtf: kind == .written ? "" : nil, text: "", runs: [], paragraphs: [])
    }
    let runs = spanRuns(decoded)
    let paragraphs = CollectionProse.paragraphs(fromRTF: rtf).map { $0.map(RichTextSpan.init) }
    guard ProseParagraphs.paragraphs(of: runs) == paragraphs else {
        throw ToolError("rich-text: \(id): the runs, split as CollectionProse splits them, are not the app's paragraphs")
    }
    var text: String?
    if kind == .written {
        guard rtf.allSatisfy({ $0 < 0x80 }) else { throw ToolError("rich-text: \(id): the editor wrote RTF that is not 7-bit") }
        text = String(decoding: rtf, as: UTF8.self)
    }
    var rewritten: RichTextRewrite?
    if kind != .web {
        guard let codec = RTFReader.read(Array(rtf)) else { throw ToolError("rich-text: \(id): the web's codec does not read it") }
        let bytes = RTFWriter.write(RichTextRuns.canonical(codec.runs))
        guard let back = ProseRichText.decodedRTF(Data(bytes)) else { throw ToolError("rich-text: \(id): the app does not read the codec's RTF") }
        rewritten = RichTextRewrite(rtf: String(decoding: bytes, as: UTF8.self), runs: spanRuns(back))
    }
    return RichTextCase(id: id, kind: kind, source: source, rtf: text, text: decoded.string, runs: runs, paragraphs: paragraphs,
                        rewritten: rewritten)
}

/// The app's reading of each code page's document, which the web's codec must read the same, here
/// first, so that a difference names its entry.
@MainActor
private func codePageReadings() throws -> [RichTextCodePageReading] {
    try RichTextCodePages.pages.map { page in
        let rtf = RichTextCodePages.document(page)
        let decoded = try ProseRichText.decodedRTF(Data(rtf)).orThrow("rich-text: code page \(page.name) does not read")
        let codec = try RTFReader.read(rtf).orThrow("rich-text: the web's codec does not read code page \(page.name)")
        let app = decoded.string.unicodeScalars.split(separator: "|", omittingEmptySubsequences: false)
        let ours = codec.text.unicodeScalars.split(separator: "|", omittingEmptySubsequences: false)
        let differing = zip(app, ours).enumerated().first(where: { !$0.element.0.elementsEqual($0.element.1) })?.offset
        if let entry = differing ?? (app.count == ours.count ? nil : min(app.count, ours.count)) {
            throw ToolError("rich-text: the web's codec reads entry \(entry) of code page \(page.name) (\(RichTextCodePages.entry(entry, of: page))) "
                + "otherwise than the app: \(entry < ours.count ? String(String.UnicodeScalarView(ours[entry])).debugDescription : "nothing"), "
                + "the app's \(entry < app.count ? String(String.UnicodeScalarView(app[entry])).debugDescription : "nothing")")
        }
        return RichTextCodePageReading(name: page.name, length: decoded.length, sha256: Digest.sha256(Data(decoded.string.utf8)))
    }
}

/// Each attribute run of `decoded`, read by `CollectionProse.paragraphs(fromDecoded:)`'s rules.
private func spanRuns(_ decoded: NSAttributedString) -> [RichTextSpan] {
    var runs: [RichTextSpan] = []
    let plain = decoded.string as NSString
    decoded.enumerateAttributes(in: NSRange(location: 0, length: decoded.length), options: []) { attrs, range, _ in
        var span = RichTextSpan(text: plain.substring(with: range))
        if let link = attrs[.link] { span.linkURL = (link as? URL)?.absoluteString ?? (link as? String) }
        if let font = attrs[.font] as? NSFont {
            let traits = font.fontDescriptor.symbolicTraits
            span.bold = traits.contains(.bold)
            span.italic = traits.contains(.italic)
        }
        if let color = attrs[.foregroundColor] as? NSColor { span.colorHex = hexColor(color) }
        if let style = attrs[.underlineStyle] as? Int, style != 0 { span.underline = true }
        runs.append(span)
    }
    return runs
}

/// `CollectionProse.hexColor(_:)` on macOS, which is private.
private func hexColor(_ color: NSColor) -> String? {
    guard let c = color.usingColorSpace(.sRGB) else { return nil }
    if c.redComponent < 0.08, c.greenComponent < 0.08, c.blueComponent < 0.08 { return nil }
    return String(format: "%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
}

/// Each key of the System colour list, as RTF names it in `\cname`, read as the app reads a colour.
@MainActor
private func catalogColors() throws -> [CatalogColor] {
    let system = try NSColorList(named: "System").orThrow("no System colour list")
    return try system.allKeys.sorted().map { name in
        let rtf = "{\\rtf1\\ansi{\\colortbl;\\red0\\green0\\blue0;}{\\*\\expandedcolortbl;\\cssrgb\\c50000\\c50000\\c50000\\cname \(name);}\\cf1 x}"
        let decoded = try ProseRichText.decodedRTF(Data(rtf.utf8)).orThrow("rich-text: catalog colour \(name) does not read")
        guard let color = decoded.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, color.type == .catalog else {
            throw ToolError("rich-text: \(name) does not read as a catalog colour")
        }
        return CatalogColor(name: name, colorHex: hexColor(color))
    }
}

extension RichTextSpan {
    init(_ span: ProseFormattedSpan) {
        self.init(text: span.text, bold: span.bold, italic: span.italic, underline: span.underline,
                  colorHex: span.colorHex, linkURL: span.linkURL)
    }
}

extension Optional {
    func orThrow(_ message: String) throws -> Wrapped {
        guard let self else { throw ToolError(message) }
        return self
    }
}

// MARK: - The editor

/// The note editor's text view and its formatting bar's controller, as the representable makes
/// them. The controller holds its view weakly, so the harness holds it.
@MainActor
final class NoteEditorHarness {
    let textView: NSTextView
    let controller = RichTextEditorController()

    init(initialRTF: Data? = nil, plainFallback: String = "") {
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 320))
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.drawsBackground = false
        textView.textStorage?.setAttributedString(Self.initialAttributed(initialRTF, plainFallback))
        controller.textView = textView
        controller.refreshSelectionState()
    }

    /// `RichTextPlatformEditor.initialAttributed()` on macOS, which is fileprivate.
    static func initialAttributed(_ rtf: Data?, _ plain: String) -> NSAttributedString {
        if let rtf {
            if let decoded = ProseRichText.decodedRTF(rtf) { return decoded }
            if let legacy = ProseRichText.legacyNSAttributedString(fromJSON: rtf) { return legacy }
        }
        return NSAttributedString(string: plain)
    }

    /// Types at the selection, as a key press does.
    func type(_ text: String) {
        textView.insertText(text, replacementRange: textView.selectedRange())
        controller.refreshSelectionState()
    }

    /// Inserts text that arrives with attributes of its own, as a paste does.
    func paste(_ text: String, _ attributes: [NSAttributedString.Key: Any]) {
        textView.insertText(NSAttributedString(string: text, attributes: attributes), replacementRange: textView.selectedRange())
        controller.refreshSelectionState()
    }

    func caretAtEnd() {
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        controller.refreshSelectionState()
    }

    /// Selects the `occurrence`th match of `needle`, counting from zero.
    func select(_ needle: String, occurrence: Int = 0) throws {
        let text = textView.string as NSString
        var from = 0
        var found = NSRange(location: NSNotFound, length: 0)
        for _ in 0...occurrence {
            found = text.range(of: needle, range: NSRange(location: from, length: text.length - from))
            guard found.location != NSNotFound else { throw ToolError("rich-text: no \(needle.debugDescription) to select") }
            from = found.location + found.length
        }
        textView.setSelectedRange(found)
        controller.refreshSelectionState()
    }

    func select(_ range: NSRange) {
        textView.setSelectedRange(range)
        controller.refreshSelectionState()
    }

    func selectAll() {
        textView.setSelectedRange(NSRange(location: 0, length: (textView.string as NSString).length))
        controller.refreshSelectionState()
    }

    func bold() { controller.toggleBold() }
    func italic() { controller.toggleItalic() }
    func underline() { controller.toggleUnderline() }
    func link(_ url: String) { controller.applyLink(url) }

    /// The body of `colorPanelDidPick(_:)`, with `color` for the panel's.
    func color(_ color: NSColor) {
        let range = textView.selectedRange()
        if range.length > 0, let storage = textView.textStorage {
            guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
            storage.addAttribute(.foregroundColor, value: color, range: range)
            textView.didChangeText()
        } else {
            textView.typingAttributes[.foregroundColor] = color
        }
    }

    /// What `report(_:)` stores on macOS.
    func rtf() throws -> Data {
        let storage = try textView.textStorage.orThrow("rich-text: the text view has no storage")
        let stored = RichTextRestingText.withBreaksRestored(storage)
        return try ProseRichText.rtfData(from: stored).orThrow("rich-text: the editor's text does not encode as RTF")
    }
}

// MARK: - The written cases

struct WrittenCase {
    let id: String
    let make: @MainActor () throws -> Data
}

@MainActor
private func edit(_ id: String, initialRTF: Data? = nil, plain: String = "",
                  _ steps: @escaping @MainActor (NoteEditorHarness) throws -> Void) -> WrittenCase {
    WrittenCase(id: id) {
        let editor = NoteEditorHarness(initialRTF: initialRTF, plainFallback: plain)
        try steps(editor)
        return try editor.rtf()
    }
}

@MainActor
private func writtenCases() throws -> [WrittenCase] {
    var cases: [WrittenCase] = [
        edit("empty") { _ in },
        edit("plain") { $0.type("Plain text, with no formatting at all.") },
        edit("bold") { e in e.type("A bold word."); try e.select("bold"); e.bold() },
        edit("italic") { e in e.type("An italic word."); try e.select("italic"); e.italic() },
        edit("underline") { e in e.type("An underlined word."); try e.select("underlined"); e.underline() },
        edit("bold-italic-underline") { e in
            e.type("All three at once.")
            try e.select("three"); e.bold(); e.italic(); e.underline()
        },
        edit("bold-off") { e in
            e.type("Bold, then not.")
            e.selectAll(); e.bold()
            try e.select("then not"); e.bold()
        },
        edit("bold-italic-overlap") { e in
            e.type("one two three")
            try e.select("one two"); e.bold()
            try e.select("two three"); e.italic()
        },
        edit("typing-bold") { e in
            e.type("Plain ")
            e.bold(); e.type("bold")
            e.bold(); e.type(" plain again")
        },
        edit("typing-italic-underline") { e in
            e.italic(); e.underline(); e.type("both")
            e.italic(); e.type(" underline only")
            e.underline(); e.type(" neither")
        },
        edit("link-https") { e in e.type("See the record."); try e.select("record"); e.link("https://history.state.gov/historicaldocuments/frus1961-63v01/d1") },
        edit("link-query-fragment") { e in e.type("A query link."); try e.select("query"); e.link("https://example.com/a/b?q=1&r=two#part") },
        edit("link-mailto") { e in e.type("Write to the office."); try e.select("office"); e.link("mailto:history@state.gov") },
        edit("link-not-a-url") { e in e.type("Not a URL here."); try e.select("URL"); e.link("not a url at all") },
        edit("link-spaces-trimmed") { e in e.type("Trimmed link."); try e.select("Trimmed"); e.link("  https://example.com/trim  ") },
        edit("link-non-ascii") { e in e.type("Accented link."); try e.select("Accented"); e.link("https://example.com/caf\u{E9}") },
        edit("link-removed") { e in
            e.type("Linked, then not.")
            try e.select("Linked"); e.link("https://example.com/")
            try e.select("Linked"); e.link("")
        },
        edit("bold-inside-link") { e in
            e.type("A linked phrase here.")
            try e.select("linked phrase"); e.link("https://example.com/phrase")
            try e.select("phrase"); e.bold()
        },
        edit("adjacent-links") { e in
            e.type("first second")
            try e.select("first"); e.link("https://example.com/1")
            try e.select("second"); e.link("https://example.com/2")
        },
        edit("line-break") { $0.type("one\ntwo") },
        edit("blank-line") { $0.type("one\n\ntwo") },
        edit("two-blank-lines") { $0.type("one\n\n\ntwo") },
        edit("three-blank-lines") { $0.type("one\n\n\n\ntwo") },
        edit("leading-breaks") { $0.type("\n\nlead") },
        edit("trailing-breaks") { $0.type("trail\n\n") },
        edit("only-breaks") { $0.type("\n\n") },
        edit("only-newline") { $0.type("\n") },
        edit("bold-across-blank-line") { e in e.type("a bold\n\nrun on"); try e.select("bold\n\nrun"); e.bold() },
        edit("blank-line-across-runs") { e in e.type("x\n\ny"); try e.select("x\n"); e.bold() },
        edit("bold-blank-line-only") { e in e.type("a\n\nb"); try e.select("\n\n"); e.bold() },
        edit("characters") {
            $0.type("caf\u{E9} na\u{EF}ve \u{2014} \u{2013} \u{201C}double\u{201D} \u{2018}single\u{2019} \u{2026} \u{A7}\u{B6} \u{A0}nbsp \u{AD}soft")
        },
        edit("non-latin") { $0.type("\u{4E2D}\u{6587} \u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629} \u{0420}\u{0443}\u{0441}\u{0441}\u{043A}\u{0438}\u{0439} \u{05E2}\u{05D1}\u{05E8}\u{05D9}\u{05EA}") },
        edit("emoji") { $0.type("flag \u{1F1FA}\u{1F1F8} face \u{1F600} family \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}") },
        edit("combining") { $0.type("e\u{301} a\u{308} n\u{303}") },
        edit("rtf-specials") { $0.type("{braces} back\\slash \\b not bold \\'41 \\u65 ") },
        edit("tab") { $0.type("col1\tcol2\t\tcol4") },
        edit("line-separator") { $0.type("one\u{2028}two") },
        edit("paragraph-separator") { $0.type("one\u{2029}two") },
        edit("carriage-returns") { $0.type("one\r\ntwo\rthree") },
        edit("link-javascript") { e in e.type("A script link."); try e.select("script"); e.link("javascript:alert(1)") },
        // Hosts that hold what a host may not, which URL(string:) refuses, so the editor keeps the text
        // and Apple's writer writes the link as AppKit reads such a field.
        edit("link-invalid-host") { e in e.type("A host link."); try e.select("host"); e.link("https://ex|ample.com/%41") },
        edit("link-lone-percent-host") { e in e.type("A percent link."); try e.select("percent"); e.link("https://exa%mple.com/%41") },
        // U+FFFD, which AppKit's reader reads as no character, so the Mac's RTF loses it.
        edit("replacement-character") { $0.type("a\u{FFFD}b") },
        edit("paste-cjk-fonts") { e in
            e.type("Typed ")
            for name in ["PingFangSC-Regular", "HiraginoSans-W3", "AppleSDGothicNeo-Regular"] {
                let font = try NSFont(name: name, size: 13).orThrow("rich-text: no font \(name)")
                e.paste("\(name) \u{4E2D}\u{6587}\u{65E5}\u{672C}\u{D55C}\u{AD6D} ", [.font: font])
            }
        },
        edit("paste-charset-fonts") { e in
            // Fonts Apple writes in charsets of their own, each run's text as \'xx bytes in its code page,
            // with two characters Foundation on Linux reads otherwise: the euro sign in code page 936,
            // and the sun sign in 950.
            e.type("Typed ")
            for (name, text) in [("PingFangTC-Regular", "\u{7E41}\u{9AD4}\u{4E2D}\u{6587} \u{2609}"),
                                 ("PingFangSC-Regular", "\u{4E2D}\u{6587} \u{20AC}"),
                                 ("PTSans-Regular", "\u{041F}\u{0440}\u{0438}\u{0432}\u{0435}\u{0442} caf\u{E9} \u{20AC}"),
                                 ("Thonburi", "\u{0E20}\u{0E32}\u{0E29}\u{0E32} caf\u{E9}"),
                                 ("ArialHebrew", "\u{05E2}\u{05D1}\u{05E8}\u{05D9}\u{05EA} caf\u{E9}"),
                                 ("GeezaPro", "\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629} caf\u{E9}"),
                                 ("DevanagariMT", "caf\u{E9} na\u{EF}ve \u{2014} \u{0928}")] {
                let font = try NSFont(name: name, size: 13).orThrow("rich-text: no font \(name)")
                e.paste("\(name) \(text) ", [.font: font])
            }
        },
        edit("formatted-characters") { e in
            e.type("Bold caf\u{E9} \u{4E2D} \u{1F600}.")
            try e.select("caf\u{E9} \u{4E2D} \u{1F600}"); e.bold()
        },
        edit("reopened-plain", plain: "A plain body.\n\nSecond paragraph.") { e in
            try e.select("plain"); e.bold()
            e.caretAtEnd(); e.type(" Typed.")
        },
        edit("reopened-plain-untouched", plain: "A plain body.\n\nSecond paragraph.") { e in
            e.caretAtEnd(); e.type(" More.")
        },
        edit("paste-fonts") { e in
            e.type("Typed ")
            for name in ["Times-Roman", "Times-Bold", "Times-Italic", "Helvetica-Oblique", "Menlo-Regular", "Menlo-Bold",
                         "HelveticaNeue-Medium", "HelveticaNeue-Light", "Avenir-Heavy", "Avenir-Black", "Georgia-BoldItalic"] {
                let font = try NSFont(name: name, size: 12).orThrow("rich-text: no font \(name)")
                e.paste(name + " ", [.font: font])
            }
        },
        edit("paste-font-boundary-blank-line") { e in
            e.paste("x\n", [.font: try NSFont(name: "Times-Roman", size: 12).orThrow("no Times")])
            e.paste("\ny", [.font: NSFont.systemFont(ofSize: 13)])
        },
        edit("paste-size-boundary-blank-line") { e in
            e.type("a\n")
            e.paste("\nb", [.font: NSFont.systemFont(ofSize: 18)])
        },
        edit("paste-baseline-blank-line") { e in
            // Apple's writer lowers the first run with \dn and ends it with \up0, one offset.
            e.paste("x\n", [.font: NSFont.systemFont(ofSize: 13), .baselineOffset: -2.0])
            e.paste("\ny", [.font: NSFont.systemFont(ofSize: 13)])
        },
        edit("paste-underline-styles") { e in
            for (label, style) in [("single", NSUnderlineStyle.single), ("double", .double), ("thick", .thick),
                                   ("dotted", [.single, .patternDot]), ("dashed", [.single, .patternDash]),
                                   ("word", [.single, .byWord])] {
                e.paste(label + " ", [.font: NSFont.systemFont(ofSize: 13), .underlineStyle: style.rawValue])
            }
        },
        edit("paste-other-attributes") { e in
            let base = NSFont.systemFont(ofSize: 13)
            e.paste("strike ", [.font: base, .strikethroughStyle: NSUnderlineStyle.single.rawValue])
            e.paste("super ", [.font: base, .superscript: 1])
            e.paste("sub ", [.font: base, .superscript: -1])
            e.paste("raised ", [.font: base, .baselineOffset: 3.0])
            e.paste("background ", [.font: base, .backgroundColor: NSColor.yellow])
            e.paste("shadow ", [.font: base, .shadow: NSShadow()])
            e.paste("kern ", [.font: base, .kern: 2.0])
            e.paste("obliqueness ", [.font: base, .obliqueness: 0.2])
            e.paste("expansion ", [.font: base, .expansion: 0.2])
            e.paste("stroke ", [.font: base, .strokeWidth: 3.0])
            e.paste("end", [.font: base])
        },
        edit("paste-paragraph-styles") { e in
            let centered = NSMutableParagraphStyle(); centered.alignment = .center
            let indented = NSMutableParagraphStyle(); indented.headIndent = 36; indented.firstLineHeadIndent = 36
            let spaced = NSMutableParagraphStyle(); spaced.paragraphSpacing = 12
            let base = NSFont.systemFont(ofSize: 13)
            e.type("lead\n")
            e.paste("centered\n\n", [.font: base, .paragraphStyle: centered])
            e.paste("indented\n\n", [.font: base, .paragraphStyle: indented])
            e.paste("spaced\n", [.font: base, .paragraphStyle: spaced])
            e.type("\ntail")
        },
        edit("paste-list") { e in
            let list = NSTextList(markerFormat: .disc, options: 0)
            let style = NSMutableParagraphStyle(); style.textLists = [list]
            let base = NSFont.systemFont(ofSize: 13)
            e.type("Items:\n")
            e.paste("\t\u{2022}\tone\n\t\u{2022}\ttwo\n", [.font: base, .paragraphStyle: style])
            let numbered = NSTextList(markerFormat: .decimal, options: 0)
            let numberedStyle = NSMutableParagraphStyle(); numberedStyle.textLists = [numbered]
            e.paste("\t1.\tfirst\n\t2.\tsecond\n", [.font: base, .paragraphStyle: numberedStyle])
            e.type("after")
        },
        edit("paste-attachment") { e in
            e.type("before ")
            let attachment = NSTextAttachment()
            attachment.image = NSImage(size: NSSize(width: 4, height: 4))
            e.textView.insertText(NSAttributedString(attachment: attachment), replacementRange: e.textView.selectedRange())
            e.type(" after")
        },
    ]

    // Colours, as the panel hands them over from each of its modes.
    let colors: [(String, NSColor)] = [
        ("srgb-red", NSColor(srgbRed: 0.8, green: 0.1, blue: 0.1, alpha: 1)),
        ("srgb-half", NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)),
        ("srgb-near-black-20", NSColor(srgbRed: 20 / 255, green: 20 / 255, blue: 20 / 255, alpha: 1)),
        ("srgb-near-black-21", NSColor(srgbRed: 21 / 255, green: 0, blue: 0, alpha: 1)),
        ("srgb-black", NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)),
        ("srgb-white", NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)),
        ("srgb-alpha", NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 0.5)),
        ("srgb-extended", NSColor(srgbRed: 1.2, green: -0.1, blue: 0.5, alpha: 1)),
        ("p3-red", NSColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)),
        ("p3-mid", NSColor(displayP3Red: 0.2, green: 0.6, blue: 0.4, alpha: 1)),
        ("generic-red", NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)),
        ("generic-mid", NSColor(calibratedRed: 0.3, green: 0.5, blue: 0.7, alpha: 1)),
        ("device-red", NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)),
        ("gray-calibrated", NSColor(calibratedWhite: 0.5, alpha: 1)),
        ("gray-device", NSColor(deviceWhite: 0.5, alpha: 1)),
        ("gray-gamma22", NSColor(genericGamma22White: 0.5, alpha: 1)),
        ("cmyk-cyan", NSColor(deviceCyan: 1, magenta: 0, yellow: 0, black: 0, alpha: 1)),
        ("cmyk-mid", NSColor(deviceCyan: 0.2, magenta: 0.6, yellow: 0.1, black: 0.1, alpha: 1)),
        ("catalog-system-red", .systemRed),
        ("catalog-system-blue", .systemBlue),
        ("catalog-label", .labelColor),
        ("catalog-text", .textColor),
        ("catalog-link", .linkColor),
        ("catalog-secondary-label", .secondaryLabelColor),
    ]
    let listColors: [(String, NSColor?)] = [
        ("crayon-cantaloupe", NSColorList(named: "Crayons")?.color(withKey: "Cantaloupe")),
        ("apple-red", NSColorList(named: "Apple")?.color(withKey: "Red")),
        ("web-safe-336699", NSColorList(named: "Web Safe Colors")?.color(withKey: "336699")),
    ]
    for (id, color) in try colors + listColors.map({ ($0.0, try $0.1.orThrow("rich-text: no colour \($0.0)")) }) {
        cases.append(edit("color-" + id) { e in e.type("A coloured word."); try e.select("coloured"); e.color(color) })
    }
    cases.append(edit("color-typing") { e in
        e.type("plain ")
        e.color(NSColor(srgbRed: 0, green: 0.4, blue: 0.8, alpha: 1)); e.type("blue")
        e.color(.textColor); e.type(" plain")
    })
    cases.append(edit("color-bold-link") { e in
        e.type("All of them.")
        try e.select("All"); e.bold(); e.color(NSColor(srgbRed: 0.6, green: 0, blue: 0.6, alpha: 1)); e.link("https://example.com/all")
    })

    // Sweeps: every sRGB channel value, a gray ramp, and grids in the converted spaces.
    cases.append(sweep("color-sweep-srgb", (0...255).flatMap { v -> [(String, NSColor)] in
        let c = CGFloat(v) / 255
        return [("R\(v)", NSColor(srgbRed: c, green: 0, blue: 0, alpha: 1)),
                ("G\(v)", NSColor(srgbRed: 0, green: c, blue: 0, alpha: 1)),
                ("B\(v)", NSColor(srgbRed: 0, green: 0, blue: c, alpha: 1))]
    }))
    let ramp = stride(from: 0, through: 255, by: 5).map { CGFloat($0) / 255 }
    cases.append(sweep("color-sweep-gray", ramp.map { ("W\(Int($0 * 255))", NSColor(genericGamma22White: $0, alpha: 1)) }))
    let grid = [0, 0.25, 0.5, 0.75, 1.0].map { CGFloat($0) }
    func cube(_ prefix: String, _ make: (CGFloat, CGFloat, CGFloat) -> NSColor) -> [(String, NSColor)] {
        grid.flatMap { r in grid.flatMap { g in grid.map { b in ("\(prefix)\(Int(r * 4))\(Int(g * 4))\(Int(b * 4))", make(r, g, b)) } } }
    }
    cases.append(sweep("color-sweep-p3", cube("P") { NSColor(displayP3Red: $0, green: $1, blue: $2, alpha: 1) }))
    cases.append(sweep("color-sweep-generic", cube("C") { NSColor(calibratedRed: $0, green: $1, blue: $2, alpha: 1) }))
    return cases
}

/// One word per colour, each coloured through the panel's path, with uncoloured spaces between.
@MainActor
private func sweep(_ id: String, _ words: [(String, NSColor)]) -> WrittenCase {
    edit(id) { e in
        e.type(words.map(\.0).joined(separator: " "))
        var location = 0
        for (word, color) in words {
            let length = (word as NSString).length
            e.select(NSRange(location: location, length: length))
            e.color(color)
            location += length + 1
        }
    }
}
