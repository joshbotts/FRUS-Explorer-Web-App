// The codec's reader (S15d): RTF to the text and runs the app reads from it. The app reads RTF only
// through AppKit (ProseRichText.decodedRTF), and Linux's Foundation reads no RTF, so this reads it
// as AppKit does for what the app's spans hold, and the golden spans hold it to the app's reading:
// the text is NSAttributedString.string, and runs break where AppKit's attribute runs break, since
// CollectionProse splits paragraphs one run at a time. What the spans do not hold, such as fonts,
// sizes, strikethrough or a paragraph's style, still breaks runs, through each run's key.

import Foundation

/// What the app reads from RTF: `NSAttributedString.string`, and its attribute runs, unmerged,
/// each with the app's span formatting.
public struct RTFReading: Equatable, Sendable {
    public var text: String
    public var runs: [RichTextRun]
    /// For each run, whether its colour came through a colour-space conversion, which the app's
    /// reading matches within one step per channel rather than exactly.
    public var convertedColors: [Bool]

    /// The runs with adjacent ones of the same formatting joined, as the browser edits them.
    public var mergedRuns: [RichTextRun] { RichTextRuns.merged(runs) }
}

public enum RTFReader {
    /// The app's reading of `data`, or nil when it is not RTF. The app reads an empty payload, or
    /// anything AppKit does not read as RTF, as no formatting, and so does the store.
    public static func read(_ data: [UInt8]) -> RTFReading? {
        var start = 0
        while start < data.count, [0x20, 0x09, 0x0A, 0x0D].contains(data[start]) { start += 1 }
        guard data.count - start >= 5, Array(data[start..<start + 5]) == Array("{\\rtf".utf8) else { return nil }
        var parser = RTFParser(data, from: start)
        parser.parse()
        return parser.unreadable ? nil : parser.reading()
    }
}

// MARK: - The parser

private struct CharacterState: Equatable {
    var bold = false
    var italic = false
    /// The control word of the underline's style, or nil for none.
    var underline: String?
    /// The `\cf` index.
    var color = 0
    var font: Int?
    var size = 24
    /// Other character attributes, each by its control word, which change AppKit's attributes and
    /// so break runs, though the app's spans do not hold them.
    var other: [String: Int] = [:]
    /// `\uc`: the fallback characters after each `\u`.
    var unicodeSkip = 1

    /// Everything but the skip count, which is no attribute.
    func sameAttributes(as other: CharacterState) -> Bool {
        var a = self, b = other
        a.unicodeSkip = 0
        b.unicodeSkip = 0
        return a == b
    }
}

private enum Destination {
    case text, skip, fontTable, colorTable, expandedColorTable, field, fieldInstruction, fieldResult
}

private struct GroupState {
    var character = CharacterState()
    /// The paragraph's properties since its `\pard`, each with its parameter, in order.
    var paragraph: [String] = []
    var destination = Destination.text
    var field: Int?
    /// A `\*` was read and no control word since.
    var starred = false
}

/// Text in one state: AppKit's attributes for it are a function of this.
private struct Piece {
    var units: [UInt16]
    var character: CharacterState
    var link: String?
    var paragraph: Int
}

private struct RTFParser {
    let data: [UInt8]
    var index: Int
    var stack: [GroupState] = []
    var state = GroupState()
    var pieces: [Piece] = []
    /// Each paragraph's properties, fixed at its end, by paragraph number.
    var paragraphKeys: [[String]] = []
    var fonts: [Int: String] = [:]
    /// Each font's `\fcharset`, which its `\'xx` bytes are in.
    var charsets: [Int: Int] = [:]
    var defaultFont: Int?
    /// Bytes in the current font's charset, decoded together, since a double-byte character is two.
    var pendingBytes: [UInt8] = []
    /// Nested past what AppKit's documents need, or a `\bin` beyond the data.
    var unreadable = false
    var legacyColors: [(Int, Int, Int)?] = []
    var expandedColors: [RTFColorEntry?] = []
    var fieldInstructions: [[UInt16]] = []
    var fieldLinks: [String?] = []
    /// Fallback characters still to skip after a `\u`.
    var skip = 0
    // The table entry being read.
    var fontIndex: Int?
    var fontCharset: Int?
    var fontName: [UInt16] = []
    var red: Int?, green: Int?, blue: Int?
    var entry = RTFColorEntry()
    var readingName = false
    var name: [UInt16] = []

    init(_ data: [UInt8], from start: Int) {
        self.data = data
        self.index = start
    }

    mutating func parse() {
        while index < data.count, !unreadable {
            let byte = data[index]
            let hexByte = byte == UInt8(ascii: "\\") && index + 1 < data.count && data[index + 1] == UInt8(ascii: "'")
            if !hexByte, byte < 0x80 || state.destination != .text && state.destination != .fieldResult { flushBytes() }
            switch byte {
            case UInt8(ascii: "{"):
                index += 1
                skip = 0
                stack.append(state)
                state.starred = false
                if stack.count > 256 { unreadable = true }
            case UInt8(ascii: "}"):
                index += 1
                skip = 0
                endGroup()
            case UInt8(ascii: "\\"):
                index += 1
                controlSequence()
            case 0x0A, 0x0D, 0x00:
                index += 1
            default:
                index += 1
                if skip > 0 { skip -= 1; continue }
                if byte >= 0x80 { textByte(byte) } else { text(UInt16(byte)) }
            }
            // The document's own group has closed.
            if stack.isEmpty, byte == UInt8(ascii: "}") { break }
        }
        flushBytes()
        paragraphKeys.append(state.paragraph)
    }

    /// A byte of 8-bit text, in the current font's charset when it is text, else in Windows-1252.
    mutating func textByte(_ byte: UInt8) {
        guard state.destination == .text || state.destination == .fieldResult,
              RTFCodePage.encoding(forCharset: charsets[state.character.font ?? defaultFont ?? -1]) != nil else {
            text(RTFCodePage.cp1252(byte))
            return
        }
        pendingBytes.append(byte)
    }

    mutating func flushBytes() {
        guard !pendingBytes.isEmpty else { return }
        let bytes = pendingBytes
        pendingBytes = []
        let charset = charsets[state.character.font ?? defaultFont ?? -1]
        if let encoding = RTFCodePage.encoding(forCharset: charset), let decoded = String(bytes: bytes, encoding: encoding) {
            for unit in decoded.utf16 { text(unit) }
        } else {
            for byte in bytes { text(RTFCodePage.cp1252(byte)) }
        }
    }

    mutating func endGroup() {
        if state.destination == .fontTable { finishFont() }
        // A field's result, and its link, end with its group.
        guard let outer = stack.popLast() else { return }
        state = outer
    }

    // MARK: Control words and symbols

    mutating func controlSequence() {
        guard index < data.count else { return }
        let first = data[index]
        if isLetter(first) {
            var end = index
            while end < data.count, isLetter(data[end]), end - index < 32 { end += 1 }
            let word = String(decoding: data[index..<end], as: UTF8.self)
            index = end
            var parameter: Int?
            if index < data.count, data[index] == UInt8(ascii: "-") || isDigit(data[index]) {
                let negative = data[index] == UInt8(ascii: "-")
                var digits = negative ? index + 1 : index
                var value = 0
                var count = 0
                while digits < data.count, isDigit(data[digits]), count < 10 {
                    value = value * 10 + Int(data[digits] - 0x30)
                    digits += 1
                    count += 1
                }
                if count > 0 || !negative {
                    parameter = negative ? -value : value
                    index = digits
                }
            }
            if index < data.count, data[index] == 0x20 { index += 1 }
            if word == "bin" {
                // Raw data, which no destination the reader keeps holds.
                let count = max(0, parameter ?? 0)
                if count > data.count - index { unreadable = true } else { index += count }
                return
            }
            if skip > 0 { skip -= 1; return }
            controlWord(word, parameter)
            state.starred = false
            return
        }
        index += 1
        switch first {
        case UInt8(ascii: "'"):
            guard index + 1 < data.count, let high = hexValue(data[index]), let low = hexValue(data[index + 1]) else { return }
            index += 2
            if skip > 0 { skip -= 1; return }
            textByte(UInt8(high * 16 + low))
        case UInt8(ascii: "*"):
            state.starred = true
        case 0x0A, 0x0D:
            if skip > 0 { skip -= 1; return }
            controlWord("par", nil)
        default:
            if skip > 0 { skip -= 1; return }
            switch first {
            case UInt8(ascii: "\\"), UInt8(ascii: "{"), UInt8(ascii: "}"): text(UInt16(first))
            case UInt8(ascii: "~"): text(0x00A0)
            case UInt8(ascii: "_"): text(0x2011)
            default: break
            }
        }
    }

    mutating func controlWord(_ word: String, _ parameter: Int?) {
        let on = parameter.map { $0 != 0 } ?? true
        if state.destination == .skip { return }
        if state.starred {
            switch word {
            case "expandedcolortbl": state.destination = .expandedColorTable; entry = RTFColorEntry(); return
            case "fldinst": startFieldInstruction(); return
            default: state.destination = .skip; return
            }
        }
        if let destination = Self.destinations[word] {
            switch destination {
            case .fontTable: state.destination = .fontTable; fontIndex = nil; fontName = []
            case .colorTable: state.destination = .colorTable; red = nil; green = nil; blue = nil
            default: state.destination = destination
            }
            return
        }
        switch state.destination {
        case .skip:
            return
        case .fontTable:
            if word == "f" {
                finishFont()
                fontIndex = parameter
            } else if word == "fcharset" {
                fontCharset = parameter
            }
            return
        case .colorTable:
            switch word {
            case "red": red = parameter ?? 0
            case "green": green = parameter ?? 0
            case "blue": blue = parameter ?? 0
            default: break
            }
            return
        case .expandedColorTable:
            switch word {
            case "cssrgb": entry.space = .sRGB
            case "csgray": entry.space = .gray
            case "cspthree": entry.space = .displayP3
            case "csgenericrgb": entry.space = .genericRGB
            case "c": entry.components.append(parameter ?? 0)
            case "cname": readingName = true; name = []
            default: if word.hasPrefix("cs") { entry.space = .other }
            }
            return
        case .field, .fieldInstruction:
            if word == "fldrslt" { startFieldResult() }
            return
        case .text, .fieldResult:
            break
        }
        switch word {
        case "field":
            fieldInstructions.append([])
            fieldLinks.append(nil)
            state.field = fieldInstructions.count - 1
            state.destination = .field
        case "fldrslt":
            startFieldResult()
        case "deff":
            defaultFont = parameter
        case "b": state.character.bold = on
        case "i": state.character.italic = on
        case "ulnone": state.character.underline = nil
        case "ulc": setOther(word, parameter)
        case "strike", "striked":
            setOther(word, parameter)
            if !on { state.character.other["strikec"] = nil }
        case _ where word.hasPrefix("ul") && Self.underlineStyles.contains(word):
            state.character.underline = on ? word : nil
        case "cf": state.character.color = parameter ?? 0
        case "f": state.character.font = parameter
        case "fs": state.character.size = parameter ?? 24
        case "plain":
            let skipCount = state.character.unicodeSkip
            state.character = CharacterState()
            state.character.font = defaultFont
            state.character.unicodeSkip = skipCount
        case "super", "sub":
            state.character.other["super"] = nil
            state.character.other["sub"] = nil
            state.character.other[word] = 1
        case "nosupersub":
            state.character.other["super"] = nil
            state.character.other["sub"] = nil
            state.character.other["up"] = nil
            state.character.other["dn"] = nil
        case _ where Self.otherCharacterWords.contains(word):
            setOther(word, parameter)
        case "uc":
            state.character.unicodeSkip = max(0, parameter ?? 1)
        case "u":
            var value = parameter ?? 0
            if value < 0 { value += 65_536 }
            text(UInt16(truncatingIfNeeded: value))
            skip = state.character.unicodeSkip
        case "par":
            text(0x0A)
            paragraphKeys.append(state.paragraph)
        case "line": text(0x2028)
        case "tab": text(0x09)
        case "emdash": text(0x2014)
        case "endash": text(0x2013)
        case "emspace": text(0x2003)
        case "enspace": text(0x2002)
        case "qmspace": text(0x2005)
        case "bullet": text(0x2022)
        case "lquote": text(0x2018)
        case "rquote": text(0x2019)
        case "ldblquote": text(0x201C)
        case "rdblquote": text(0x201D)
        case "zwj": text(0x200D)
        case "zwnj": text(0x200C)
        case "ltrmark": text(0x200E)
        case "rtlmark": text(0x200F)
        case "pard":
            state.paragraph = []
        case _ where Self.paragraphWords.contains(word):
            state.paragraph.append(parameter.map { "\(word)\($0)" } ?? word)
        default:
            break
        }
    }

    mutating func setOther(_ word: String, _ parameter: Int?) {
        let value = parameter ?? 1
        state.character.other[word] = value == 0 ? nil : value
    }

    mutating func startFieldInstruction() {
        state.destination = .fieldInstruction
    }

    mutating func startFieldResult() {
        state.destination = .fieldResult
        guard let field = state.field else { return }
        fieldLinks[field] = Self.hyperlink(fieldInstructions[field])
    }

    /// The URL of a `HYPERLINK "url"` instruction, verbatim, as AppKit reads it.
    static func hyperlink(_ instruction: [UInt16]) -> String? {
        let text = String(decoding: instruction, as: UTF16.self).trimmingCharacters(in: .whitespaces)
        guard text.uppercased().hasPrefix("HYPERLINK") else { return nil }
        let rest = text.dropFirst("HYPERLINK".count).trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix("\"") {
            let body = rest.dropFirst()
            guard let close = body.firstIndex(of: "\"") else { return String(body) }
            return String(body[..<close])
        }
        return rest.split(separator: " ").first.map(String.init)
    }

    // MARK: Text

    private let semicolon: UInt16 = 0x3B

    mutating func text(_ unit: UInt16) {
        switch state.destination {
        case .text, .fieldResult:
            let link = state.destination == .fieldResult ? state.field.flatMap { fieldLinks[$0] } : nil
            let paragraph = paragraphKeys.count
            if var last = pieces.last, last.paragraph == paragraph, last.link == link,
               last.character.sameAttributes(as: state.character) {
                last.units.append(unit)
                pieces[pieces.count - 1] = last
            } else {
                pieces.append(Piece(units: [unit], character: state.character, link: link, paragraph: paragraph))
            }
        case .fieldInstruction:
            if let field = state.field { fieldInstructions[field].append(unit) }
        case .fontTable:
            if unit == semicolon { finishFont() } else { fontName.append(unit) }
        case .colorTable:
            if unit == semicolon {
                legacyColors.append(red == nil && green == nil && blue == nil ? nil : (red ?? 0, green ?? 0, blue ?? 0))
                red = nil
                green = nil
                blue = nil
            }
        case .expandedColorTable:
            if unit == semicolon {
                if readingName {
                    entry.catalogName = String(decoding: name, as: UTF16.self).trimmingCharacters(in: .whitespaces)
                }
                expandedColors.append(entry.space == nil && entry.catalogName == nil ? nil : entry)
                entry = RTFColorEntry()
                readingName = false
            } else if readingName {
                name.append(unit)
            }
        case .skip, .field:
            break
        }
    }

    mutating func finishFont() {
        if let fontIndex {
            let name = String(decoding: fontName, as: UTF16.self).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { fonts[fontIndex] = name }
            if let fontCharset { charsets[fontIndex] = fontCharset }
        }
        fontIndex = nil
        fontCharset = nil
        fontName = []
    }

    // MARK: The reading

    func reading() -> RTFReading {
        var table: [RTFColorEntry] = []
        for i in 0..<max(legacyColors.count, expandedColors.count) {
            var entry = (i < expandedColors.count ? expandedColors[i] : nil) ?? RTFColorEntry()
            entry.legacy = i < legacyColors.count ? legacyColors[i] : nil
            table.append(entry)
        }
        struct Key: Equatable {
            var character: CharacterState
            var font: String?
            var color: RTFColorEntry?
            var link: String?
            var paragraph: [String]
        }
        var runs: [RichTextRun] = []
        var converted: [Bool] = []
        var keys: [Key] = []
        var units: [[UInt16]] = []
        for piece in pieces {
            var character = piece.character
            character.unicodeSkip = 0
            let font = (piece.character.font ?? defaultFont).map { fonts[$0] ?? "#\($0)" }
            character.font = nil
            let colorIndex = piece.character.color
            character.color = 0
            let resolved = RTFColor.resolve(colorIndex, in: table)
            let entry = resolved == nil ? nil : table[colorIndex]
            let paragraph = piece.paragraph < paragraphKeys.count ? paragraphKeys[piece.paragraph] : []
            let key = Key(character: character, font: font, color: entry, link: piece.link, paragraph: paragraph)
            if let last = keys.last, last == key {
                units[units.count - 1] += piece.units
                continue
            }
            keys.append(key)
            units.append(piece.units)
            runs.append(RichTextRun(text: "", bold: piece.character.bold, italic: piece.character.italic,
                                    underline: piece.character.underline != nil, colorHex: resolved?.hex,
                                    linkURL: piece.link))
            converted.append(resolved?.converted ?? false)
        }
        for i in runs.indices { runs[i].text = String(decoding: units[i], as: UTF16.self) }
        let text = String(decoding: units.flatMap { $0 }, as: UTF16.self)
        return RTFReading(text: text, runs: runs, convertedColors: converted)
    }

    // MARK: Tables of words

    static let destinations: [String: Destination] = {
        var table: [String: Destination] = ["fonttbl": .fontTable, "colortbl": .colorTable]
        for word in ["stylesheet", "info", "pict", "object", "header", "headerl", "headerr", "headerf", "footer",
                     "footerl", "footerr", "footerf", "listtable", "listoverridetable", "revtbl", "filetbl",
                     "listtext", "pntext", "pntxta", "pntxtb", "footnote", "annotation", "atnid", "atnauthor",
                     "xmlnstbl", "rsidtbl", "mmathPr", "themedata", "colorschememapping", "latentstyles",
                     "datastore", "generator", "nonshppict", "shppict", "bkmkstart", "bkmkend", "template",
                     "fldinst"] {
            table[word] = word == "fldinst" ? .fieldInstruction : .skip
        }
        return table
    }()

    static let underlineStyles: Set<String> = [
        "ul", "ulw", "uld", "uldash", "uldashd", "uldashdd", "uldb", "ulth", "ulthd", "ulthdash", "ulthdashd",
        "ulthdashdd", "ulwave", "ulhwave", "ululdbwave", "ulldash", "ulthldash",
    ]

    static let otherCharacterWords: Set<String> = [
        "strike", "striked", "strikec", "cb", "highlight", "chcbpat", "up", "dn", "shad", "outl", "embo", "impr",
        "scaps", "caps", "v", "expnd", "expndtw", "kerning", "charscalex", "obliqueness", "expansion", "strokewidth",
        "strokec", "shadx", "shady", "shadr", "shadb", "shadc",
    ]

    static let paragraphWords: Set<String> = [
        "ql", "qc", "qr", "qj", "qd", "qn", "li", "ri", "fi", "lin", "rin", "sb", "sa", "sl", "slmult", "slleading",
        "slmaximum", "slminimum", "tx", "tb", "tqr", "tqc", "tqdec", "tldot", "tlhyph", "tlul", "tlth", "tleq", "ls",
        "ilvl", "pardeftab", "pardirnatural", "partightenfactor", "s", "keep", "keepn", "intbl", "itap", "widctlpar",
        "nowidctlpar", "hyphpar", "rtlpar", "ltrpar", "noline", "pagebb", "sbauto", "saauto", "headerlevel",
        "pardeftab", "parhyphenfactor", "nooverflow", "faauto", "aspalpha", "aspnum", "adjustright",
    ]

    private func isLetter(_ byte: UInt8) -> Bool { (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte) }
    private func isDigit(_ byte: UInt8) -> Bool { (0x30...0x39).contains(byte) }
    private func hexValue(_ byte: UInt8) -> Int? {
        switch byte {
        case 0x30...0x39: Int(byte - 0x30)
        case 0x41...0x46: Int(byte - 0x41 + 10)
        case 0x61...0x66: Int(byte - 0x61 + 10)
        default: nil
        }
    }
}

/// Windows-1252, the code page of `\ansi`, for `\'xx` and 8-bit text.
enum RTFCodePage {
    private static let high: [UInt16] = [
        0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
        0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
    ]

    static func cp1252(_ byte: UInt8) -> UInt16 {
        (0x80...0x9F).contains(byte) ? high[Int(byte) - 0x80] : UInt16(byte)
    }

    /// The encoding of a font's `\fcharset` other than Windows-1252's, as AppKit reads its `\'xx`
    /// bytes: the Windows code page of each charset, double-byte for Japanese, Korean and Chinese.
    static func encoding(forCharset charset: Int?) -> String.Encoding? {
        let windows: UInt32
        switch charset {
        case 128?: windows = 0x0420      // Shift-JIS, code page 932
        case 129?: windows = 0x0422      // Hangul, code page 949
        case 134?: windows = 0x0421      // GBK, code page 936
        case 136?: windows = 0x0A03      // Big5
        case 161?: windows = 0x0503      // Greek, 1253
        case 162?: windows = 0x0504      // Turkish, 1254
        case 163?: windows = 0x0508      // Vietnamese, 1258
        case 177?: windows = 0x0505      // Hebrew, 1255
        case 178?: windows = 0x0506      // Arabic, 1256
        case 186?: windows = 0x0507      // Baltic, 1257
        case 204?: windows = 0x0502      // Cyrillic, 1251
        case 222?: windows = 0x041D      // Thai, 874
        case 238?: windows = 0x0501      // Central European, 1250
        default: return nil
        }
        return String.Encoding(rawValue: UInt(0x8000_0000 | windows))
    }
}
