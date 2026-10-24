// The golden spans: the RTF the Mac's note editor writes, and how the app reads RTF, for the web's
// rich-text codec (S15d).

import Foundation

/// `fixtures/golden/rich-text/spans.json`. Each case is RTF and the app's reading of it: the RTF
/// the editor writes for a formatting it offers, a hand-written file under `fixtures/rich-text/read`,
/// or the RTF the web's codec writes, under `fixtures/rich-text/web`.
public struct RichTextGolden: Codable, Equatable, Sendable {
    public var format: Int
    public var provenance: Provenance
    /// How the cases were made and read, in words: the code path and its settings.
    public var configuration: String
    /// The appearance the app read every case under, by its `NSAppearance.Name`.
    public var appearance: String
    public var cases: [RichTextCase]
    /// Each colour of the system's catalog list, as the app reads it under `appearance`.
    public var catalogColors: [CatalogColor]

    public static let currentFormat = 1
    /// The appearance the app's reading is made under: the light one.
    public static let appearance = "NSAppearanceNameAqua"
    /// The harness that writes the cases, an input of the file, since the submodule's digest does not cover it.
    public static let harnessPath = "tools/mac-golden/Sources/mac-golden/RichText.swift"
    /// The hand-written RTF the app reads, one `read` case per file.
    public static let readFolder = "fixtures/rich-text/read"

    public init(provenance: Provenance, configuration: String, appearance: String,
                cases: [RichTextCase], catalogColors: [CatalogColor]) {
        self.format = Self.currentFormat
        self.provenance = provenance
        self.configuration = configuration
        self.appearance = appearance
        self.cases = cases
        self.catalogColors = catalogColors
    }
}

public struct RichTextCase: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// The editor's own path: the RTF is the golden's.
        case written
        /// A hand-written file the app reads: the RTF is the file `source` names.
        case read
        /// The RTF the web's codec writes for a case of `fixtures/rich-text/web/cases.json`.
        case web
    }

    public var id: String
    public var kind: Kind
    /// For a `read` or `web` case, its RTF file, relative to the repository.
    public var source: String?
    /// For a `written` case, the RTF the editor wrote. Apple's writer emits 7-bit text.
    public var rtf: String?
    /// The decoded text, `NSAttributedString.string`.
    public var text: String
    /// The decoded attribute runs, in order and unmerged, each read by the app's span rules.
    public var runs: [RichTextSpan]
    /// `CollectionProse.paragraphs(fromRTF:)`, the app's own reading.
    public var paragraphs: [[RichTextSpan]]
    /// For a `written` or `read` case, the RTF the web's codec writes for its own reading of the
    /// case, and the app's reading of that.
    public var rewritten: RichTextRewrite?

    public init(id: String, kind: Kind, source: String?, rtf: String?, text: String,
                runs: [RichTextSpan], paragraphs: [[RichTextSpan]], rewritten: RichTextRewrite? = nil) {
        self.id = id
        self.kind = kind
        self.source = source
        self.rtf = rtf
        self.text = text
        self.runs = runs
        self.paragraphs = paragraphs
        self.rewritten = rewritten
    }
}

/// What the web's codec writes for a case it has read, and how the app reads that back: the
/// golden spans' proof that the codec writes RTF the app reads back to the spans it read.
public struct RichTextRewrite: Codable, Equatable, Sendable {
    /// The codec's RTF, 7-bit.
    public var rtf: String
    /// The app's reading of it: its runs, unmerged, by the app's span rules.
    public var runs: [RichTextSpan]

    public init(rtf: String, runs: [RichTextSpan]) {
        self.rtf = rtf
        self.runs = runs
    }
}

/// One span, as the app's `ProseFormattedSpan` holds it.
public struct RichTextSpan: Codable, Equatable, Sendable {
    public var text: String
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    /// Uppercase `RRGGBB`, or nil for (near-)black or no colour.
    public var colorHex: String?
    public var linkURL: String?

    public init(text: String, bold: Bool = false, italic: Bool = false, underline: Bool = false,
                colorHex: String? = nil, linkURL: String? = nil) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.colorHex = colorHex
        self.linkURL = linkURL
    }

    /// The same formatting, whatever the text.
    public func formatted(like other: RichTextSpan) -> Bool {
        bold == other.bold && italic == other.italic && underline == other.underline
            && colorHex == other.colorHex && linkURL == other.linkURL
    }
}

/// `fixtures/rich-text/web/cases.json`: the runs the web's codec writes RTF for, each to
/// `<id>.rtf` beside it, for the app to read back as a `web` case.
public struct RichTextWebCases: Codable, Equatable, Sendable {
    public var format: Int
    public var cases: [RichTextWebCase]

    public static let currentFormat = 1
    public static let path = "fixtures/rich-text/web/cases.json"

    public static func rtfPath(_ id: String) -> String { "fixtures/rich-text/web/\(id).rtf" }

    public init(cases: [RichTextWebCase]) {
        self.format = Self.currentFormat
        self.cases = cases
    }
}

public struct RichTextWebCase: Codable, Equatable, Sendable {
    public var id: String
    /// The runs to write, whose texts joined are the note's plain text.
    public var runs: [RichTextSpan]

    public init(id: String, runs: [RichTextSpan]) {
        self.id = id
        self.runs = runs
    }
}

public struct CatalogColor: Codable, Equatable, Sendable {
    /// The colour's name in its RTF `\cname`, such as `systemRedColor`.
    public var name: String
    public var colorHex: String?

    public init(name: String, colorHex: String?) {
        self.name = name
        self.colorHex = colorHex
    }
}

/// The app's reading of spans into paragraphs, `CollectionProse.append`: each run is split on
/// blank lines (`"\n\n"`) by itself, so one that straddles two runs splits nothing; a blank line
/// starts a paragraph and empty parts are dropped. Golden checks hold this to the app's own
/// paragraphs on every case.
public enum ProseParagraphs {
    public static func paragraphs(of runs: [RichTextSpan]) -> [[RichTextSpan]] {
        guard !runs.isEmpty else { return [] }
        var paragraphs: [[RichTextSpan]] = [[]]
        for run in runs {
            for (index, part) in run.text.components(separatedBy: "\n\n").enumerated() {
                if index > 0 { paragraphs.append([]) }
                if !part.isEmpty {
                    var span = run
                    span.text = part
                    paragraphs[paragraphs.count - 1].append(span)
                }
            }
        }
        return paragraphs
    }

    /// Adjacent spans of the same formatting joined, within each paragraph, so readings that break
    /// runs at different places compare equal.
    public static func merged(_ paragraphs: [[RichTextSpan]]) -> [[RichTextSpan]] {
        paragraphs.map(merged)
    }

    public static func merged(_ spans: [RichTextSpan]) -> [RichTextSpan] {
        var out: [RichTextSpan] = []
        for span in spans {
            if let last = out.last, last.formatted(like: span) {
                out[out.count - 1].text += span.text
            } else {
                out.append(span)
            }
        }
        return out
    }
}
