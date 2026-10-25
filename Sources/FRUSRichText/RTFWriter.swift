// The codec's writer (S15d): runs to RTF the app reads back to them. It writes what the Mac's note
// editor writes for the same text, as the golden spans record it: AppKit's header, the 13-point
// system font, unformatted text in the catalog text colour, so a Mac draws it in the appearance's
// own colour, and each colour as \cssrgb at its byte's midpoint, so the app's truncation reads the
// byte back. The golden spans' web cases hold the app's reading of it.

import Foundation

public enum RTFWriter {
    /// RTF for `runs`, or for the runs' text alone when they are all plain. Runs must pass
    /// `RichTextRuns.problem`; text the writer cannot hold is the caller's to refuse.
    public static func write(_ runs: [RichTextRun]) -> [UInt8] {
        let runs = RichTextRuns.merged(runs)
        // Each colour in the order the runs first use it, and its \cf index: 2 is the catalog text
        // colour, and the runs' own follow it.
        var colors: [String] = []
        var indexes: [String: Int] = [:]
        for run in runs {
            if let hex = run.colorHex, indexes[hex] == nil {
                indexes[hex] = colors.count + 3
                colors.append(hex)
            }
        }
        var out = "{\\rtf1\\ansi\\ansicpg1252\\cocoartf2907\n"
        out += "\\cocoatextscaling0\\cocoaplatform0{\\fonttbl\\f0\\fnil\\fcharset0 HelveticaNeue;}\n"
        out += "{\\colortbl;\\red255\\green255\\blue255;\\red0\\green0\\blue0;"
        for hex in colors {
            let (r, g, b) = RTFColor.rgb(hex: hex) ?? (0, 0, 0)
            out += "\\red\(r)\\green\(g)\\blue\(b);"
        }
        out += "}\n{\\*\\expandedcolortbl;;\\cssrgb\\c0\\c0\\c0\\cname textColor;"
        for hex in colors {
            let (r, g, b) = RTFColor.rgb(hex: hex) ?? (0, 0, 0)
            out += "\\cssrgb\\c\(RTFColor.component(byte: r))\\c\(RTFColor.component(byte: g))\\c\(RTFColor.component(byte: b));"
        }
        out += "}\n\\pard\\tx560\\tx1120\\tx1680\\tx2240\\tx2800\\tx3360\\tx3920\\tx4480\\tx5040\\tx5600\\tx6160\\tx6720"
        out += "\\pardirnatural\\partightenfactor0\n\n\\f0\\fs26 \\cf2 \\uc0 "

        // The formatting in force outside a link's field, and inside the one open.
        var outside = Format()
        var index = 0
        while index < runs.count {
            guard let url = runs[index].linkURL else {
                let format = Format(runs[index], indexes)
                out += outside.change(to: format) + escaped(runs[index].text)
                outside = format
                index += 1
                continue
            }
            // One field per stretch of runs with the same link, its formatting scoped to its group,
            // the link as the app reads it back, so that the field holds what the app's reading of
            // it gives. The text's \uc0 holds in the field's groups too, as AppKit reads RTF.
            let link = RichTextRuns.appReading(ofLink: url) ?? url
            out += "{\\field{\\*\\fldinst{HYPERLINK \"\(link)\"}}{\\fldrslt "
            var inside = outside
            while index < runs.count, runs[index].linkURL == url {
                let format = Format(runs[index], indexes)
                out += inside.change(to: format) + escaped(runs[index].text)
                inside = format
                index += 1
            }
            out += "}}"
        }
        out += "}"
        return Array(out.utf8)
    }

    /// The character formatting the writer controls.
    private struct Format: Equatable {
        var bold = false
        var italic = false
        var underline = false
        /// The `\cf` index: 2 is the catalog text colour, and each run's own colour follows it.
        var color = 2

        init() {}

        init(_ run: RichTextRun, _ indexes: [String: Int]) {
            bold = run.bold
            italic = run.italic
            underline = run.underline
            color = run.colorHex.flatMap { indexes[$0] } ?? 2
        }

        /// The control words that take this formatting to `next`, with their delimiter.
        func change(to next: Format) -> String {
            var words = ""
            if bold != next.bold { words += next.bold ? "\\b" : "\\b0" }
            if italic != next.italic { words += next.italic ? "\\i" : "\\i0" }
            if underline != next.underline { words += next.underline ? "\\ul" : "\\ulnone" }
            if color != next.color { words += "\\cf\(next.color)" }
            return words.isEmpty ? "" : words + " "
        }
    }

    /// Text as RTF: ASCII as itself but for the three characters RTF reserves, a line break as
    /// AppKit writes one, and anything else as `\u` with its UTF-16 unit, as `\uc0` lets it.
    static func escaped(_ text: String) -> String {
        var out = ""
        for unit in text.utf16 {
            switch unit {
            case 0x5C: out += "\\\\"
            case 0x7B: out += "\\{"
            case 0x7D: out += "\\}"
            case 0x0A: out += "\\\n"
            case 0x09: out += "\t"
            case 0x20...0x7E: out.unicodeScalars.append(Unicode.Scalar(UInt8(unit)))
            default: out += "\\u\(unit) "
            }
        }
        return out
    }
}
