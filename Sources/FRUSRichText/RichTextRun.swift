// A note's formatting (S15d), as the Mac's note editor offers it: bold, italic, underline, a text
// colour and a link, and no lists. The browser sends runs, the store keeps RTF, and the codec in
// RTFReader and RTFWriter turns one into the other, held to the app's own reading of RTF by the
// golden spans (fixtures/golden/rich-text/spans.json).

import Foundation

/// A stretch of a note's text with one formatting, as the app's `ProseFormattedSpan` reads it.
public struct RichTextRun: Codable, Equatable, Sendable {
    public var text: String
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    /// Uppercase `RRGGBB`, or nil for no colour: the app reads (near-)black as none.
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
    public func formatted(like other: RichTextRun) -> Bool {
        bold == other.bold && italic == other.italic && underline == other.underline
            && colorHex == other.colorHex && linkURL == other.linkURL
    }

    public var isPlain: Bool { !bold && !italic && !underline && colorHex == nil && linkURL == nil }
}

public enum RichTextRuns {
    /// Adjacent runs of the same formatting joined, and empty runs dropped.
    public static func merged(_ runs: [RichTextRun]) -> [RichTextRun] {
        var out: [RichTextRun] = []
        for run in runs where !run.text.isEmpty {
            if let last = out.last, last.formatted(like: run) {
                out[out.count - 1].text += run.text
            } else {
                out.append(run)
            }
        }
        return out
    }

    /// The runs' text, joined.
    public static func text(_ runs: [RichTextRun]) -> String { runs.map(\.text).joined() }

    /// Why runs cannot be a note's formatting, or nil when they can: their text must be the note's
    /// plain text exactly, a colour six uppercase hexadecimal digits and not (near-)black, which the
    /// app would read as no colour, and a link one the codec can write. Which links a browser may
    /// follow is `isFollowable`'s.
    public static func problem(_ runs: [RichTextRun], bodyText: String) -> String? {
        guard text(runs).utf16.elementsEqual(bodyText.utf16) else { return "runs: their text must be bodyText exactly" }
        for run in runs {
            if let problem = textProblem(run.text) { return "runs: \(problem)" }
            if let hex = run.colorHex {
                guard let rgb = RTFColor.rgb(hex: hex) else { return "runs: colorHex must be six uppercase hexadecimal digits" }
                if RTFColor.isNearBlack(rgb) { return "runs: colorHex \(hex) is (near-)black, which is no colour" }
            }
            if let url = run.linkURL, let problem = linkProblem(url) { return "runs: \(problem)" }
        }
        return nil
    }

    /// The characters a note may not hold: control characters other than a line break and a tab,
    /// and U+2029, which RTF can only write as a line break.
    public static func textProblem(_ text: String) -> String? {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0A, 0x09: continue
            case 0x00...0x1F, 0x7F...0x9F: return "text holds the control character U+\(String(scalar.value, radix: 16, uppercase: true))"
            case 0x2029: return "text holds a paragraph separator, U+2029"
            default: continue
            }
        }
        return nil
    }

    /// A link the codec can write and the app reads back: 1 to 2,048 characters of printable
    /// ASCII without spaces, quotes, backslashes or braces. AppKit writes every link the Mac makes
    /// that way, percent-escaping the rest, and a browser's `new URL()` does the same.
    public static func linkProblem(_ url: String) -> String? {
        guard !url.isEmpty, url.utf8.count <= 2048 else { return "linkURL must be 1 to 2,048 characters" }
        guard url.utf8.allSatisfy({ $0 > 0x20 && $0 < 0x7F && $0 != UInt8(ascii: "\"") && $0 != UInt8(ascii: "\\")
            && $0 != UInt8(ascii: "{") && $0 != UInt8(ascii: "}") }) else {
            return "linkURL must be printable ASCII without spaces, quotes, backslashes or braces"
        }
        return nil
    }

    /// Whether a browser may follow a link: http, https or mailto. The Mac links any text its
    /// reader types, so a note may hold others, which the web keeps and never follows.
    public static func isFollowable(_ url: String) -> Bool {
        guard let colon = url.firstIndex(of: ":") else { return false }
        return ["http", "https", "mailto"].contains(url[..<colon].lowercased())
    }
}
