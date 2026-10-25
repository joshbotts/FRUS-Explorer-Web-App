// The golden spans (PLAN's S15d): the web's codec reads every RTF of fixtures/golden/rich-text as the
// app reads it, every text byte of every code page included, and writes RTF that the app reads back
// to its runs, in the canonical form the server stores. The app's reading is AppKit's, made on a Mac
// by tools/mac-golden; Linux has no RTF reader, so the codec is held to the file. A colour that
// AppKit converts from another colour space, through ColorSync, is held within one step per
// channel; everything else, colours in sRGB, gray and the catalog included, exactly.

@testable import FRUSRichText
import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct RichTextGoldenTests {
    static func currentGolden() throws -> RichTextGolden {
        switch try GoldenValidation.load(.richText, as: RichTextGolden.self, layout: Repository.layout) {
        case .present(let golden, let stale):
            guard stale.isEmpty else { throw GoldenError.stale(GoldenFile.richText.rawValue, stale.joined(separator: "; ")) }
            return golden
        case .pending:
            throw GoldenError.malformed(GoldenFile.richText.rawValue, "it is made from the app's source alone and must be committed, not pending: run scripts/make-golden")
        }
    }

    static func bytes(of item: RichTextCase) throws -> [UInt8] {
        if let rtf = item.rtf { return Array(rtf.utf8) }
        return Array(try Data(contentsOf: Repository.root.appendingPathComponent(item.source ?? "")))
    }

    @Test func theCodecReadsEveryCaseAsTheAppDoes() throws {
        let golden = try Self.currentGolden()
        var exact = 0, converted = 0
        for item in golden.cases {
            let bytes = try Self.bytes(of: item)
            let reading = RTFReader.read(bytes) ?? RTFReading(text: "", runs: [], convertedColors: [])
            #expect(reading.text.utf16.elementsEqual(item.text.utf16), "\(item.id): the text is \(reading.text.debugDescription), the app's \(item.text.debugDescription)")
            let ours = zip(reading.runs, reading.convertedColors).map { Span(RichTextSpan($0.0), converted: $0.1) }
            if let difference = Span.difference(Span.merged(ours), Span.merged(item.runs.map { Span($0) })) {
                Issue.record("\(item.id): runs: \(difference)")
            }
            let paragraphs = Span.paragraphs(of: ours).map(Span.merged)
            let theirs = item.paragraphs.map { Span.merged($0.map { Span($0) }) }
            if paragraphs.count != theirs.count {
                Issue.record("\(item.id): \(paragraphs.count) paragraphs, the app's \(theirs.count)")
            } else {
                for (index, pair) in zip(paragraphs, theirs).enumerated() {
                    if let difference = Span.difference(pair.0, pair.1) { Issue.record("\(item.id): paragraph \(index + 1): \(difference)") }
                }
            }
            for span in ours where span.span.colorHex != nil {
                if span.converted { converted += 1 } else { exact += 1 }
            }
        }
        print("golden spans: \(golden.cases.count) cases read as the app reads them; \(exact) coloured runs exactly, \(converted) converted from another colour space within one step")
    }

    /// The done-when's second half for every golden RTF: what the server stores when a web edit
    /// sends back the codec's reading of a case, its runs in canonical form, the app reads back to
    /// the app's own spans of the case, in canonical form.
    @Test func theAppReadsTheCodecsRewriteOfEveryCaseAsItReadTheCase() throws {
        let golden = try Self.currentGolden()
        var count = 0
        for item in golden.cases where item.kind != .web {
            guard let rewritten = item.rewritten else {
                Issue.record("\(item.id): no rewrite")
                continue
            }
            let reading = RTFReader.read(try Self.bytes(of: item)) ?? RTFReading(text: "", runs: [], convertedColors: [])
            #expect(RTFWriter.write(RichTextRuns.canonical(reading.runs)) == Array(rewritten.rtf.utf8),
                    "\(item.id): the codec no longer writes the golden's rewrite: run scripts/make-golden")
            // The rewrite's colours are the codec's, which came through a conversion where the case's did.
            let converted = Span.convertedColors(reading)
            let back = Span.merged(rewritten.runs.map { Span($0, converted: converted) })
            if let difference = Span.difference(back, Span.canonical(item.runs)) {
                Issue.record("\(item.id): the app reads the codec's rewrite differently: \(difference)")
            }
            #expect(rewritten.runs.map(\.text).joined().utf16.elementsEqual(item.text.utf16), "\(item.id): the rewrite's text")
            count += 1
        }
        print("golden spans: the app reads the codec's rewrite of all \(count) written and read cases back to its own spans")
    }

    /// The cases whose rewrite the app's exporters split into other paragraphs than the case: each
    /// holds a blank line across two of AppKit's runs, which the app's `append` does not split, and
    /// the runs on the wire are merged and canonical, so the rewrite holds it in one run, which it
    /// splits. A web edit of such a Mac note gains a paragraph in the Mac's exports.
    static let rewritesSplitOtherwise: Set<String> = [
        "blank-line-across-runs", "paste-baseline-blank-line", "paste-font-boundary-blank-line", "paste-paragraph-styles",
        "read-baseline-up-down", "read-fonts-applied", "read-nosupersub",
    ]

    @Test func theAppSplitsTheRewriteOfEveryOtherCaseIntoItsParagraphs() throws {
        let golden = try Self.currentGolden()
        var otherwise: Set<String> = []
        for item in golden.cases where item.kind != .web {
            guard let rewritten = item.rewritten,
                  let reading = RTFReader.read(try Self.bytes(of: item)) else { continue }
            let converted = Span.convertedColors(reading)
            let back = ProseParagraphs.paragraphs(of: rewritten.runs).map { Span.canonical($0, converted: converted) }
            let theirs = item.paragraphs.map { Span.canonical($0) }
            if back.count != theirs.count || zip(back, theirs).contains(where: { Span.difference($0.0, $0.1) != nil }) {
                otherwise.insert(item.id)
            }
        }
        #expect(otherwise == Self.rewritesSplitOtherwise, "the cases whose rewrite the app splits into other paragraphs")
    }

    @Test func theGoldenRunsGiveTheAppsParagraphs() throws {
        for item in try Self.currentGolden().cases {
            #expect(ProseParagraphs.paragraphs(of: item.runs) == item.paragraphs, "\(item.id)")
        }
    }

    @Test func theWriterWritesTheCommittedWebFixtures() throws {
        let cases = try GoldenJSON.read(RichTextWebCases.self, from: Repository.root.appendingPathComponent(RichTextWebCases.path))
        for fixture in RichTextParity.webFixtures(cases) {
            let committed = Array(try Data(contentsOf: Repository.root.appendingPathComponent(fixture.path)))
            #expect(committed == fixture.bytes, "\(fixture.path) is not what the codec writes: run scripts/swift run frus-parity rich-text-fixtures, then scripts/make-golden")
        }
    }

    @Test func theAppReadsTheWebCasesBackToTheirRuns() throws {
        let golden = try Self.currentGolden()
        let cases = try GoldenJSON.read(RichTextWebCases.self, from: Repository.root.appendingPathComponent(RichTextWebCases.path))
        let read = Dictionary(uniqueKeysWithValues: golden.cases.filter { $0.kind == .web }.map { ($0.source ?? "", $0) })
        for item in cases.cases {
            guard let app = read[RichTextWebCases.rtfPath(item.id)] else {
                Issue.record("\(item.id): the golden spans hold no web case for it")
                continue
            }
            // The file is what the server stores for the case's runs, so the app reads their canonical form.
            let canonical = RichTextRuns.canonical(item.runs.map(RichTextRun.init)).map(RichTextSpan.init)
            #expect(ProseParagraphs.merged(app.runs) == canonical, "\(item.id)")
            #expect(app.text == item.runs.map(\.text).joined(), "\(item.id)")
        }
        print("golden spans: the app reads the codec's RTF back to the runs of all \(cases.cases.count) web cases")
    }

    @Test func theCodecReadsItsOwnRTFBackToItsRuns() throws {
        let cases = try GoldenJSON.read(RichTextWebCases.self, from: Repository.root.appendingPathComponent(RichTextWebCases.path))
        for item in cases.cases {
            let runs = RichTextRuns.canonical(item.runs.map(RichTextRun.init))
            let reading = try #require(RTFReader.read(RTFWriter.write(runs)))
            #expect(reading.mergedRuns == runs, "\(item.id)")
            #expect(reading.text == RichTextRuns.text(runs), "\(item.id)")
            #expect(!reading.convertedColors.contains(true), "\(item.id)")
            #expect(RichTextRuns.canonical(runs) == runs, "\(item.id): canonical runs are their own canonical form")
        }
    }

    /// Every text byte of every code page, and every pair of a double-byte one, as the app reads
    /// it: the codec's reading of each page's document has the golden's digest. The harness checks
    /// the codec entry by entry on the Mac; this holds Linux's Foundation, which reads most pairs of
    /// a double-byte page for the codec, to the Mac's reading.
    @Test func theCodecReadsEveryCodePageAsTheAppDoes() throws {
        let golden = try Self.currentGolden()
        let readings = Dictionary(uniqueKeysWithValues: golden.codePages.map { ($0.name, $0) })
        for page in RichTextCodePages.pages {
            let app = try #require(readings[page.name], "\(page.name)")
            let text = try #require(RTFReader.read(RichTextCodePages.document(page)), "\(page.name)").text
            #expect(text.utf16.count == app.length && ParityFormat.Digest.sha256(text) == app.sha256,
                    "\(page.name): the codec's reading is not the app's, on this platform")
        }
        print("golden spans: the codec reads every byte of all \(RichTextCodePages.pages.count) code pages as the app does")
    }

    @Test func theCatalogTableIsTheGoldens() throws {
        let golden = try Self.currentGolden()
        let table = Dictionary(uniqueKeysWithValues: golden.catalogColors.map { ($0.name, $0.colorHex) })
        #expect(RTFCatalogColors.aqua == table, "RTFCatalogColors.aqua is not the golden spans' catalogColors")
    }

    /// The writer gives each byte its bucket's midpoint, and the app's truncation reads it back.
    @Test func everyByteSurvivesTheWriter() {
        for byte in 0...255 {
            #expect(Int(Double(RTFColor.component(byte: byte)) / 100_000 * 255) == byte, "\(byte)")
        }
    }
}

/// A span with whether a colour-space conversion made its colour.
private struct Span: Equatable {
    var span: RichTextSpan
    var converted = false

    init(_ span: RichTextSpan, converted: Bool = false) {
        self.span = span
        self.converted = converted
    }

    /// A span of the codec's colours, converted where `converted` holds its colour.
    init(_ span: RichTextSpan, converted: Set<String>) {
        self.init(span, converted: span.colorHex.map(converted.contains) ?? false)
    }

    /// The colours the codec's reading made through a conversion.
    static func convertedColors(_ reading: RTFReading) -> Set<String> {
        Set(zip(reading.runs, reading.convertedColors).compactMap { $0.1 ? $0.0.colorHex : nil })
    }

    /// Spans in canonical form, as the server writes runs.
    static func canonical(_ spans: [RichTextSpan], converted: Set<String> = []) -> [Span] {
        RichTextRuns.canonical(spans.map(RichTextRun.init)).map { Span(RichTextSpan($0), converted: converted) }
    }

    static func merged(_ spans: [Span]) -> [Span] {
        var out: [Span] = []
        for item in spans where !item.span.text.isEmpty {
            if let last = out.last, last.span.formatted(like: item.span) {
                out[out.count - 1].span.text += item.span.text
                out[out.count - 1].converted = last.converted || item.converted
            } else {
                out.append(item)
            }
        }
        return out
    }

    /// `ProseParagraphs.paragraphs(of:)`, keeping each span's flag.
    static func paragraphs(of runs: [Span]) -> [[Span]] {
        guard !runs.isEmpty else { return [] }
        var paragraphs: [[Span]] = [[]]
        for run in runs {
            for (index, part) in run.span.text.components(separatedBy: "\n\n").enumerated() {
                if index > 0 { paragraphs.append([]) }
                if !part.isEmpty {
                    var span = run
                    span.span.text = part
                    paragraphs[paragraphs.count - 1].append(span)
                }
            }
        }
        return paragraphs
    }

    /// Where the codec's spans first differ from the app's, or nil when they agree: a converted
    /// colour may be one step off on any channel.
    static func difference(_ ours: [Span], _ theirs: [Span]) -> String? {
        for (index, pair) in zip(ours, theirs).enumerated() {
            let (a, b) = (pair.0.span, pair.1.span)
            let same = a.text.utf16.elementsEqual(b.text.utf16) && a.bold == b.bold && a.italic == b.italic
                && a.underline == b.underline && a.linkURL == b.linkURL
                && (a.colorHex == b.colorHex || (pair.0.converted && withinOneStep(a.colorHex, b.colorHex)))
            if !same { return "span \(index + 1) is \(describe(pair.0)), the app's \(describe(pair.1))" }
        }
        guard ours.count == theirs.count else { return "\(ours.count) spans, the app's \(theirs.count)" }
        return nil
    }

    static func withinOneStep(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b, let x = RTFColor.rgb(hex: a), let y = RTFColor.rgb(hex: b) else { return false }
        return abs(x.0 - y.0) <= 1 && abs(x.1 - y.1) <= 1 && abs(x.2 - y.2) <= 1
    }

    static func describe(_ item: Span) -> String {
        let s = item.span
        var marks = [s.bold ? "bold" : nil, s.italic ? "italic" : nil, s.underline ? "underline" : nil,
                     s.colorHex.map { "#\($0)" }, s.linkURL.map { "-> \($0)" }].compactMap { $0 }
        if item.converted { marks.append("converted") }
        return "\(s.text.debugDescription)" + (marks.isEmpty ? "" : " [\(marks.joined(separator: ", "))]")
    }
}
