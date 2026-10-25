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

    /// Runs in canonical form: each line break formatted as the text before it, plain at the start;
    /// each link as the app reads it back; neighbours of one formatting joined; none empty. The
    /// browser sends runs so but for their links, and the server makes sure before it writes, so one
    /// text and formatting is always one RTF, which the codec and the app read back to these runs.
    /// A blank line that straddles two formattings becomes one run, which the app's exporters then
    /// split into two paragraphs where they split the Mac's RTF into one.
    public static func canonical(_ runs: [RichTextRun]) -> [RichTextRun] {
        var pieces: [RichTextRun] = []
        var before = RichTextRun(text: "")
        for var run in runs {
            if let url = run.linkURL { run.linkURL = appReading(ofLink: url) ?? url }
            var segment = ""
            for scalar in run.text.unicodeScalars {
                guard scalar == "\n" else {
                    segment.unicodeScalars.append(scalar)
                    continue
                }
                if !segment.isEmpty {
                    pieces.append(piece(segment, like: run))
                    before = run
                    segment = ""
                }
                pieces.append(piece("\n", like: before))
            }
            if !segment.isEmpty {
                pieces.append(piece(segment, like: run))
                before = run
            }
        }
        return merged(pieces)
    }

    private static func piece(_ text: String, like run: RichTextRun) -> RichTextRun {
        var piece = run
        piece.text = text
        return piece
    }

    /// The link the app reads back from a `HYPERLINK` field that holds `url`, or nil when it reads
    /// none. AppKit's reader makes an NSURL of the field, which percent-encodes, in uppercase
    /// hexadecimal, what a URL may not hold where it stands and keeps everything else as it is: a
    /// space, `"`, `<`, `>`, `\`, `^`, `` ` ``, `{`, `|` and `}`; `[` and `]` but an IP literal's;
    /// `%` not before two hexadecimal digits; each `#` after the first; `@` in the user information
    /// but its last; and anything beyond ASCII, in UTF-8. A link whose port is not digits it reads
    /// as none, and so too an IP literal that holds what a URL may not; in one, it encodes each `%`
    /// but a zone's `%25` (probe of 24 Oct 2026, every printable character at each place in a URL).
    ///
    /// Three readings this leaves as they are, which no field the Mac or the codec writes holds,
    /// since Apple's writer writes a link already read so, and the codec writes this reading:
    /// - a link that starts with no scheme but holds one later, or starts with `//`, which AppKit
    ///   reads otherwise again, and the browser follows no such link;
    /// - a port of `(` or `)` after digits, which AppKit cuts short;
    /// - an http, https or ftp link whose host holds what a host may not, such as `|`, `^`, `]`, a
    ///   space or a `%` not before two hexadecimal digits: AppKit then decodes every escape of the
    ///   whole link, when all decode to UTF-8, reads the result as a link again, so that a decoded
    ///   `/`, `?` or `#` takes its place there, and encodes what that may not hold, `%` included, and
    ///   a host beyond ASCII in Punycode (probe of 24 Oct 2026: `https://ex|ample.com/%41` reads as
    ///   `https://ex%7Cample.com/A`, and `https://exa%mple.com/%41` as `https://exa%25mple.com/%2541`).
    public static func appReading(ofLink url: String) -> String? {
        let bytes = Array(url.utf8)
        let count = bytes.count
        func byte(_ index: Int) -> UInt8? { index < count ? bytes[index] : nil }
        // The scheme, a letter then letters, digits, "+", "-" or ".", and its colon.
        var start = 0
        if let first = byte(0), isLetter(first) {
            var end = 1
            while let next = byte(end), isLetter(next) || isDigit(next) || next == UInt8(ascii: "+") || next == UInt8(ascii: "-")
                    || next == UInt8(ascii: ".") { end += 1 }
            if byte(end) == UInt8(ascii: ":") { start = end + 1 }
        }
        // The authority, after "//" and up to the first "/", "?" or "#".
        var authority = start..<start
        if byte(start) == UInt8(ascii: "/"), byte(start + 1) == UInt8(ascii: "/") {
            var end = start + 2
            while let next = byte(end), next != UInt8(ascii: "/"), next != UInt8(ascii: "?"), next != UInt8(ascii: "#") { end += 1 }
            authority = start + 2..<end
        }
        let lastAt = authority.isEmpty ? nil : bytes[authority].lastIndex(of: UInt8(ascii: "@"))
        let host = (lastAt.map { $0 + 1 } ?? authority.lowerBound)..<authority.upperBound
        // An IP literal's brackets, kept, and the port, digits or nothing.
        var literal = host.lowerBound..<host.lowerBound
        var portStart: Int?
        if byte(host.lowerBound) == UInt8(ascii: "["), let close = bytes[host].firstIndex(of: UInt8(ascii: "]")) {
            literal = host.lowerBound..<close + 1
            if close + 1 < host.upperBound {
                guard bytes[close + 1] == UInt8(ascii: ":") else { return nil }
                portStart = close + 2
            }
        } else if let colon = bytes[host].firstIndex(of: UInt8(ascii: ":")) {
            portStart = colon + 1
        }
        if let portStart, !bytes[portStart..<host.upperBound].allSatisfy(isDigit) { return nil }

        var out: [UInt8] = []
        var sawHash = false
        for (index, value) in bytes.enumerated() {
            let encode: Bool
            switch value {
            case _ where literal.contains(index):
                // An IP literal AppKit reads as no link when it holds what a URL may not, and in one
                // it encodes each `%` but a zone's `%25`.
                if value == UInt8(ascii: "%") {
                    encode = !(byte(index + 1) == UInt8(ascii: "2") && byte(index + 2) == UInt8(ascii: "5"))
                } else if index != literal.lowerBound, index != literal.upperBound - 1, Self.mustEncode(value) {
                    return nil
                } else {
                    encode = false
                }
            case UInt8(ascii: "#"):
                encode = sawHash
                sawHash = true
            case UInt8(ascii: "%"):
                encode = !(byte(index + 1).map(isHexDigit) == true && byte(index + 2).map(isHexDigit) == true)
            case UInt8(ascii: "@"):
                encode = lastAt.map { authority.contains(index) && index < $0 } ?? false
            default:
                encode = Self.mustEncode(value)
            }
            if encode {
                out += [UInt8(ascii: "%"), hexDigits[Int(value >> 4)], hexDigits[Int(value & 0xF)]]
            } else {
                out.append(value)
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// What AppKit percent-encodes wherever it stands but in an IP literal's brackets.
    private static func mustEncode(_ value: UInt8) -> Bool {
        switch value {
        case 0x00...0x20, 0x7F...0xFF, UInt8(ascii: "\""), UInt8(ascii: "<"), UInt8(ascii: ">"), UInt8(ascii: "\\"),
             UInt8(ascii: "^"), UInt8(ascii: "`"), UInt8(ascii: "{"), UInt8(ascii: "|"), UInt8(ascii: "}"),
             UInt8(ascii: "["), UInt8(ascii: "]"):
            true
        default:
            false
        }
    }

    private static let hexDigits = Array("0123456789ABCDEF".utf8)
    private static func isLetter(_ byte: UInt8) -> Bool { (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte) }
    private static func isDigit(_ byte: UInt8) -> Bool { (0x30...0x39).contains(byte) }
    private static func isHexDigit(_ byte: UInt8) -> Bool { isDigit(byte) || (0x41...0x46).contains(byte) || (0x61...0x66).contains(byte) }

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

    /// The characters a note may not hold: control characters other than a line break and a tab;
    /// U+2029, which RTF can only write as a line break; and U+FFFD, which the app's RTF reader
    /// reads as no character, from the Mac's own RTF too (probe of 24 Oct 2026).
    public static func textProblem(_ text: String) -> String? {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0A, 0x09: continue
            case 0x00...0x1F, 0x7F...0x9F: return "text holds the control character U+\(String(scalar.value, radix: 16, uppercase: true))"
            case 0x2029: return "text holds a paragraph separator, U+2029"
            case 0xFFFD: return "text holds U+FFFD, which the app's RTF reader drops"
            default: continue
            }
        }
        return nil
    }

    /// A link the codec can write and the app reads back as a link: printable ASCII without spaces,
    /// quotes, backslashes or braces, with a port of digits if any and an IP literal the app reads,
    /// and 1 to 2,048 characters as the app reads it, which `canonical` makes it. AppKit writes every link the Mac makes that
    /// way, percent-escaping the rest, and a browser's `new URL()` writes all but a few characters
    /// so, which the app's reading percent-encodes.
    public static func linkProblem(_ url: String) -> String? {
        guard !url.isEmpty, url.utf8.count <= 2048 else { return "linkURL must be 1 to 2,048 characters" }
        guard url.utf8.allSatisfy({ $0 > 0x20 && $0 < 0x7F && $0 != UInt8(ascii: "\"") && $0 != UInt8(ascii: "\\")
            && $0 != UInt8(ascii: "{") && $0 != UInt8(ascii: "}") }) else {
            return "linkURL must be printable ASCII without spaces, quotes, backslashes or braces"
        }
        guard let read = appReading(ofLink: url) else {
            return "linkURL has a port that is not digits, or an IP literal holding what a URL may not, which the app reads as no link"
        }
        guard read.utf8.count <= 2048 else { return "linkURL must be 1 to 2,048 characters once percent-encoded as the app reads it" }
        return nil
    }

    /// Whether a browser may follow a link: http, https or mailto. The Mac links any text its
    /// reader types, so a note may hold others, which the web keeps and never follows.
    public static func isFollowable(_ url: String) -> Bool {
        guard let colon = url.firstIndex(of: ":") else { return false }
        return ["http", "https", "mailto"].contains(url[..<colon].lowercased())
    }
}
