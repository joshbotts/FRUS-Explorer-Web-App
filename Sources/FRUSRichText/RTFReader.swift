// The codec's reader (S15d): RTF to the text and runs the app reads from it. The app reads RTF only
// through AppKit (ProseRichText.decodedRTF), and Linux's Foundation reads no RTF, so this reads it
// as AppKit does for what the app's spans hold, and the golden spans hold it to the app's reading:
// the text is NSAttributedString.string, and runs break where AppKit's attribute runs break, since
// CollectionProse splits paragraphs one run at a time. What the spans do not hold, such as fonts,
// sizes, strikethrough or a paragraph's style, still breaks runs, through each run's key. Text bytes
// are read as AppKit reads them (RTFCodePage), held together until a control word AppKit knows
// (RTFKeywords), a group's start or end, or a control symbol but \' \\ \{ \} \:, and then decoded
// in the code page in force: a byte the page does not define loses them all, as AppKit loses them.

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
    /// anything AppKit does not read as RTF, as no formatting, and so does the store. AppKit reads
    /// as RTF what opens a group after any line breaks and NULs, `{\rtf` or not, and only once that
    /// group closes; a space or a tab before it, or a document cut short, it does not read (probe of
    /// 24 Oct 2026). More than 256 groups nested the codec does not read either, though AppKit does.
    public static func read(_ data: [UInt8]) -> RTFReading? {
        var start = 0
        while start < data.count, [0x0A, 0x0D, 0x00].contains(data[start]) { start += 1 }
        guard start < data.count, data[start] == UInt8(ascii: "{") else { return nil }
        var parser = RTFParser(data, from: start)
        parser.parse()
        return parser.unreadable || !parser.closed ? nil : parser.reading()
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
    func sameAttributes(as state: CharacterState) -> Bool {
        bold == state.bold && italic == state.italic && underline == state.underline && color == state.color
            && font == state.font && size == state.size && other == state.other
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
    /// The code page text bytes are decoded in, which the last `\f` or `\plain` set, or the last word
    /// that names the document's page: NeXTSTEP's in a document that names none.
    var codePage = RTFCodePage.singleByte(RTFCodePage.nextstep)
    /// Whether the last byte of those held is dropped alone when the rest decode and it does not,
    /// as a lead byte with no trail is after `\f` set a double-byte page, until the next `\f`.
    var dropsTrailingLead = false
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
    /// Each font's `\fcharset`, which its text bytes are in.
    var charsets: [Int: Int] = [:]
    /// The fonts the font table holds, whatever their names and charsets.
    var tableFonts: Set<Int> = []
    /// The code page of text in a font the table does not hold, from the last `\ansi`, `\mac`, `\pc`,
    /// `\pca` or `\ansicpg`, which holds beyond its group.
    var documentCodePage = RTFCodePage.singleByte(RTFCodePage.nextstep)
    /// The code page of a font of no charset: Mac OS Roman after `\mac` or an `\ansicpg` of a Mac
    /// page, else Windows-1252, which holds beyond its group too.
    var fontCodePage = RTFCodePage.singleByte(RTFCodePage.cp1252)
    /// The code page each font of no charset took when it was first selected, which it keeps.
    var noCharsetPages: [Int: RTFCodePage] = [:]
    /// Text bytes held until AppKit would decode them, together, since a double-byte character is two.
    var pendingBytes: [UInt8] = []
    /// Nested past 256 groups, which no document AppKit writes needs.
    var unreadable = false
    /// The document's own group has closed.
    var closed = false
    var legacyColors: [(Int, Int, Int)?] = []
    var expandedColors: [RTFColorEntry?] = []
    var fieldInstructions: [[UInt16]] = []
    var fieldLinks: [String?] = []
    /// Fallback characters still to skip after a `\u`.
    var skip = 0
    /// A group has opened and nothing but line breaks has followed: only there does `\*` mark a
    /// destination, as AppKit reads it (probe of 24 Oct 2026).
    var groupStart = false
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
            switch byte {
            case UInt8(ascii: "{"):
                flushBytes()
                index += 1
                skip = 0
                stack.append(state)
                state.starred = false
                groupStart = true
                if stack.count > 256 { unreadable = true }
            case UInt8(ascii: "}"):
                flushBytes()
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
                groupStart = false
                state.starred = false
                if skip > 0 {
                    // A space in a \u's fallback text AppKit drops without counting it, and a tab ends
                    // the fallback (probe of 24 Oct 2026).
                    if byte == 0x20 { continue }
                    if byte != 0x09 { skip -= 1; continue }
                    skip = 0
                }
                textByte(byte)
            }
            // The document's own group has closed.
            if stack.isEmpty, byte == UInt8(ascii: "}") {
                closed = true
                break
            }
        }
        flushBytes()
        paragraphKeys.append(state.paragraph)
    }

    /// A byte of text, held until AppKit would decode it; outside text, as itself or in Windows-1252.
    mutating func textByte(_ byte: UInt8) {
        switch state.destination {
        case .text, .field, .fieldResult: pendingBytes.append(byte)
        default: text(RTFCodePage.windows1252(byte))
        }
    }

    /// The text bytes held, decoded together in the code page in force, or dropped when the page
    /// does not define one of them.
    mutating func flushBytes() {
        guard !pendingBytes.isEmpty else { return }
        let bytes = pendingBytes
        pendingBytes = []
        guard let units = state.codePage.decode(bytes, dropsTrailingLead: state.dropsTrailingLead) else { return }
        for unit in units { text(unit) }
    }

    /// `\f` and `\plain`: the code page of text in `font` from now in the group, its charset's when
    /// the font table holds it, else the document's. A font of no charset takes the fonts' page when
    /// it is first selected and keeps it, as AppKit reads it (probe of 24 Oct 2026).
    mutating func selectFont(_ font: Int?) {
        if let font, tableFonts.contains(font) {
            if let page = RTFCodePage.of(charset: charsets[font]) {
                state.codePage = page
            } else {
                let page = noCharsetPages[font] ?? fontCodePage
                noCharsetPages[font] = page
                state.codePage = page
            }
        } else {
            state.codePage = documentCodePage
        }
        state.dropsTrailingLead = state.codePage.isDoubleByte
    }

    /// A word that names the document's code page: the text that follows it, and text in a font
    /// the table does not hold, are in `page`, and a font of no charset in `fonts`.
    mutating func nameDocumentCodePage(_ page: RTFCodePage, fonts: RTFCodePage) {
        documentCodePage = page
        fontCodePage = fonts
        state.codePage = page
    }

    mutating func endGroup() {
        if state.destination == .fontTable { finishFont() }
        // A field's instruction is read when its group ends, and the text after it in the field's
        // group is linked; a field's result, and its link, end with its group.
        guard let outer = stack.popLast() else { return }
        if state.destination == .fieldInstruction, outer.destination != .fieldInstruction, let field = state.field {
            fieldLinks[field] = Self.hyperlink(fieldInstructions[field])
        }
        state = outer
    }

    // MARK: Control words and symbols

    mutating func controlSequence() {
        guard index < data.count else { return }
        let first = data[index]
        let atGroupStart = groupStart
        groupStart = false
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
                // A minus with no digit AppKit reads as part of the word, which then has no
                // parameter: \b- is \b (probe of 24 Oct 2026).
                parameter = count > 0 ? (negative ? -value : value) : nil
                index = digits
            }
            if index < data.count, data[index] == 0x20 { index += 1 }
            // A control word ends a \u's fallback text rather than standing for one of its characters,
            // as any control symbol but \' \\ \{ \} \: does (probe of 24 Oct 2026). \bin's data AppKit
            // reads as RTF, as if the word were not there.
            skip = 0
            // AppKit decodes the text bytes it holds at each control word it knows, and not at one it
            // does not.
            if RTFKeywords.appKit.contains(word) { flushBytes() }
            controlWord(word, parameter)
            state.starred = false
            return
        }
        index += 1
        switch first {
        case UInt8(ascii: "'"):
            guard index + 1 < data.count, let high = hexValue(data[index]), let low = hexValue(data[index + 1]) else { return }
            index += 2
            let byte = UInt8(high * 16 + low)
            // A NUL, a line feed or a carriage return AppKit ignores, as it ignores the byte itself.
            if [0x00, 0x0A, 0x0D].contains(byte) { return }
            if skip > 0 { skip -= 1; return }
            textByte(byte)
        case UInt8(ascii: "\\"), UInt8(ascii: "{"), UInt8(ascii: "}"), UInt8(ascii: ":"):
            // Bytes of the text, which may be a double-byte character's trail.
            if skip > 0 { skip -= 1; return }
            textByte(first)
        case UInt8(ascii: "*"):
            skip = 0
            flushBytes()
            state.starred = atGroupStart
        case 0x0A, 0x0D:
            skip = 0
            flushBytes()
            controlWord("par", nil)
        default:
            skip = 0
            flushBytes()
            switch first {
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
            // A destination AppKit does not know it skips; a word it knows it reads as it reads the
            // word anywhere.
            switch word {
            case "expandedcolortbl": state.destination = .expandedColorTable; entry = RTFColorEntry(); return
            case "fldinst": startFieldInstruction(); return
            case _ where !RTFKeywords.appKit.contains(word): state.destination = .skip; return
            default: break
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
        case .fieldInstruction:
            if word == "fldrslt" { startFieldResult() }
            return
        case .text, .field, .fieldResult:
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
        case "ansi":
            nameDocumentCodePage(.singleByte(RTFCodePage.cp1252), fonts: .singleByte(RTFCodePage.cp1252))
        case "mac":
            nameDocumentCodePage(.singleByte(RTFCodePage.macRoman), fonts: .singleByte(RTFCodePage.macRoman))
        case "pc", "pca":
            nameDocumentCodePage(.singleByte(RTFCodePage.nextstep), fonts: .singleByte(RTFCodePage.cp1252))
        case "ansicpg":
            let named = RTFCodePage.named(byANSICodePage: parameter)
            nameDocumentCodePage(named.text, fonts: named.fonts)
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
        case "f":
            state.character.font = parameter
            selectFont(parameter)
        case "fs": state.character.size = parameter ?? 24
        case "plain":
            // Font 0, whatever \deff names, as AppKit reads text after it (probe of 24 Oct 2026).
            let skipCount = state.character.unicodeSkip
            state.character = CharacterState()
            state.character.font = 0
            state.character.unicodeSkip = skipCount
            selectFont(0)
        case "super", "sub":
            state.character.other["super"] = nil
            state.character.other["sub"] = nil
            state.character.other[word] = 1
        case "nosupersub":
            // Superscript only: a baseline offset from \up or \dn holds until \up0 or \dn0, as
            // AppKit reads it (probe of 24 Oct 2026).
            state.character.other["super"] = nil
            state.character.other["sub"] = nil
        case "up", "dn":
            // One baseline offset, in half points, 12 by default, which each sets and \up0 and \dn0
            // both end, as Apple's writer ends a lowered run with \up0 (probe of 24 Oct 2026).
            let offset = (parameter ?? 12) * (word == "dn" ? -1 : 1)
            state.character.other["baseline"] = offset == 0 ? nil : offset
        case _ where Self.otherCharacterWords.contains(word):
            setOther(word, parameter)
        case "uc":
            state.character.unicodeSkip = max(0, parameter ?? 1)
        case "u":
            var value = parameter ?? 0
            if value < 0 { value += 65_536 }
            let unit = UInt16(truncatingIfNeeded: value)
            // U+FFFD AppKit reads as no character, and its fallback as text (probe of 24 Oct 2026).
            guard unit != 0xFFFD else { return }
            text(unit)
            skip = state.character.unicodeSkip
        case "par":
            text(0x0A)
            paragraphKeys.append(state.paragraph)
        case "line": text(0x2028)
        case "page": text(0x0C)
        case "tab": text(0x09)
        case "emdash": text(0x2014)
        case "endash": text(0x2013)
        case "emspace": text(0x2003)
        case "enspace": text(0x2002)
        case "bullet": text(0x2022)
        case "lquote": text(0x2018)
        case "rquote": text(0x2019)
        case "ldblquote": text(0x201C)
        case "rdblquote": text(0x201D)
        case "zwj": text(0x200D)
        case "zwnj": text(0x200C)
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

    /// The link of a `HYPERLINK "url"` instruction as AppKit reads it, percent-encoded where a URL
    /// may not hold what it holds, or nil when AppKit reads no link.
    static func hyperlink(_ instruction: [UInt16]) -> String? {
        let text = String(decoding: instruction, as: UTF16.self).trimmingCharacters(in: .whitespaces)
        guard text.uppercased().hasPrefix("HYPERLINK") else { return nil }
        let rest = text.dropFirst("HYPERLINK".count).trimmingCharacters(in: .whitespaces)
        let url: String?
        if rest.hasPrefix("\"") {
            let body = rest.dropFirst()
            url = body.firstIndex(of: "\"").map { String(body[..<$0]) } ?? String(body)
        } else {
            url = rest.split(separator: " ").first.map(String.init)
        }
        return url.flatMap(RichTextRuns.appReading(ofLink:))
    }

    // MARK: Text

    private let semicolon: UInt16 = 0x3B

    mutating func text(_ unit: UInt16) {
        switch state.destination {
        case .text, .field, .fieldResult:
            // Text in a field's group AppKit reads too, linked once the instruction has been read.
            let link = state.destination == .text ? nil : state.field.flatMap { fieldLinks[$0] }
            let paragraph = paragraphKeys.count
            if let last = pieces.last, last.paragraph == paragraph, last.link == link,
               last.character.sameAttributes(as: state.character) {
                // In place: a copy of the piece would copy its text at each character.
                pieces[pieces.count - 1].units.append(unit)
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
        case .skip:
            break
        }
    }

    mutating func finishFont() {
        if let fontIndex {
            tableFonts.insert(fontIndex)
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
            var font: String
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
            // AppKit's font: the table's, by its name, or Helvetica, its default, for text in no font
            // or in one the table does not hold, whatever \deff names, and for a font with no name.
            // AppKit gives a name the Mac lacks a font of its family, and a family's name its regular
            // face, which the codec does not know, so it breaks runs there that AppKit does not.
            let font = piece.character.font.flatMap { tableFonts.contains($0) ? fonts[$0] : nil } ?? "Helvetica"
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

    /// The destinations whose text the codec does not read: those AppKit skips, which a probe of
    /// 24 Oct 2026 found by reading each word it knows before text, and others Word writes, which
    /// AppKit skips after `\*` or which hold only destinations it skips.
    static let destinations: [String: Destination] = {
        var table: [String: Destination] = ["fonttbl": .fontTable, "colortbl": .colorTable, "fldinst": .fieldInstruction]
        for word in ["AppleHighlightTable", "AppleHilightClrSchTbl", "aftncn", "aftnsep", "aftnsepc", "annotation", "atnauthor",
                     "atnicn", "atnid", "atnref", "atntime", "atrfend", "atrfstart", "author", "background", "bkmkend",
                     "bkmkstart", "buptim", "category", "comment", "company", "copyright", "creatim", "datafield", "do",
                     "doccomm", "falt", "file", "filetbl", "fonteb", "fontfile", "footer", "footerf", "footerl", "footerr",
                     "footnote", "ftncn", "ftnsep", "ftnsepc", "glid", "header", "headerf", "headerl", "headerr", "keycode",
                     "keywords", "listoverridetable", "listtable", "listtext", "manager", "nextcolor", "nextcolortbl",
                     "nextfile", "objalias", "objclass", "objdata", "object", "objitem", "objname", "objsect", "objtopic",
                     "operator", "pgnhn", "pict", "pn", "pnseclvl", "pntext", "pntexta", "pntextb", "printim", "result",
                     "revtbl", "revtim", "rxe", "stylesheet", "subject", "tc", "template", "title", "txe", "verscomm",
                     "version", "xe",
                     // Word's, which AppKit reads as text unless \* comes before them, or holding only what it skips.
                     "info", "pntxta", "pntxtb", "xmlnstbl", "rsidtbl", "mmathPr", "themedata", "colorschememapping",
                     "latentstyles", "datastore", "generator", "nonshppict", "shppict"] {
            table[word] = .skip
        }
        return table
    }()

    static let underlineStyles: Set<String> = [
        "ul", "ulw", "uld", "uldash", "uldashd", "uldashdd", "uldb", "ulth", "ulthd", "ulthdash", "ulthdashd",
        "ulthdashdd", "ulwave", "ulhwave", "ululdbwave", "ulldash", "ulthldash",
    ]

    /// The character words AppKit reads as an attribute the app's spans do not hold, each of which
    /// breaks its runs. A word AppKit does not know, such as Word's \highlight, breaks none.
    static let otherCharacterWords: Set<String> = [
        "strike", "striked", "strikec", "cb", "shad", "outl", "embo", "impr", "scaps", "caps", "v", "expnd",
        "expndtw", "kerning", "obliqueness", "expansion", "strokewidth", "strokec", "shadx", "shady", "shadr", "shadc",
    ]

    /// The paragraph words AppKit reads, each of which may break its runs.
    static let paragraphWords: Set<String> = [
        "ql", "qc", "qr", "qj", "li", "ri", "fi", "sb", "sa", "sl", "slmult", "slleading", "slmaximum", "slminimum",
        "tx", "tb", "tqr", "tqc", "tqdec", "tldot", "tlhyph", "tlul", "tlth", "tleq", "ls", "ilvl", "pardeftab",
        "pardirnatural", "partightenfactor", "s", "keep", "keepn", "intbl", "itap", "nowidctlpar", "hyphpar", "rtlpar",
        "ltrpar", "noline", "pagebb", "parhyphenfactor",
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
