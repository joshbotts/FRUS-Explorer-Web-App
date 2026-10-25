// The code pages RTF text bytes are in (S15d): which one AppKit's reader decodes a byte in, and how,
// measured on macOS 27.0.1 (probes of 24 Oct 2026; docs/DEVLOG.md, S15d).
// - The bytes are decoded in the code page in force in their group, which the last \f or \plain, or
//   the last of \ansi, \mac, \pc, \pca and \ansicpg, set there, and a group's end restores.
// - \f sets its font's: a font of the font table decodes in its \fcharset's code page, 0 in
//   Windows-1252, 77 in Mac OS Roman, 128, 129, 134 and 136 in the Windows double-byte pages 932, 949,
//   936 and 950 (not Big5), 161 to 238 in the Windows single-byte pages; any other charset, or none,
//   in the fonts' page when the font is first selected, which it keeps. A font the table does not
//   hold yet decodes in the document's page. \plain sets font 0's, and \deff none.
// - \ansi sets Windows-1252, \mac Mac OS Roman, \pc and \pca NeXTSTEP, and \ansicpg the page it
//   names; each also makes that the document's page, and the fonts' page Windows-1252, or Mac OS Roman
//   after \mac or an \ansicpg of a Mac page. Those two hold beyond the group. A document that names
//   no page is NeXTSTEP's, with fonts in Windows-1252, and an \ansicpg that AppKit does not know, or
//   one with no number, Mac OS Roman's.
// - AppKit reads some 50 other \ansicpg pages, DOS, ISO, KOI8, EUC, GB 18030, UTF-8 and UTF-16 among
//   them, which the codec does not: it reads no byte from 0x80 in one, which loses the bytes held with
//   it, so the text is not the app's and a note keeps its RTF.
// - Bytes held together are all lost when the page does not define one of them. But after \f sets
//   a double-byte page, until the next \f or the group's end, whatever page a word names meanwhile,
//   the last byte is dropped alone when the rest decode, as a lead byte with no trail is.
// - Cocoa writes the system's code page in \ansicpg (936 on a Mac set to Chinese, 1251 to Russian),
//   but writes \f0 before any text, and each font with its charset, so it changes nothing a Mac note
//   holds.
// Charset 2, Symbol, which AppKit reads in the Symbol font's own encoding, and the few others it reads
// otherwise, such as 130 and 89, are read as a font of no charset.

import Foundation

/// A code page of RTF text bytes, and AppKit's reading of them.
enum RTFCodePage: Sendable {
    /// Each byte from 0x80 its UTF-16 unit, or 0 where the page defines none.
    case singleByte([UInt16])
    case doubleByte(RTFDoubleByteTable)
    /// A page AppKit reads and the codec does not: ASCII as itself, and no byte from 0x80.
    case unread

    var isDoubleByte: Bool {
        if case .doubleByte = self { return true }
        return false
    }

    /// The code page of a font's `\fcharset`, or nil for one read as a font of no charset.
    static func of(charset: Int?) -> RTFCodePage? {
        switch charset {
        case 0?: .singleByte(cp1252)
        case 77?: .singleByte(macRoman)
        case 128?: .doubleByte(cp932)
        case 129?: .doubleByte(cp949)
        case 134?: .doubleByte(cp936)
        case 136?: .doubleByte(cp950)
        case 161?: .singleByte(cp1253)
        case 162?: .singleByte(cp1254)
        case 163?: .singleByte(cp1258)
        case 177?: .singleByte(cp1255)
        case 178?: .singleByte(cp1256)
        case 186?: .singleByte(cp1257)
        case 204?: .singleByte(cp1251)
        case 222?: .singleByte(cp874)
        case 238?: .singleByte(cp1250)
        default: nil
        }
    }

    /// What `\ansicpg` names, as AppKit reads it: the page of the text that follows it, and of text
    /// in a font the table does not hold, and the page of a font of no charset.
    static func named(byANSICodePage codePage: Int?) -> (text: RTFCodePage, fonts: RTFCodePage) {
        switch codePage {
        case 1252?: (.singleByte(cp1252), .singleByte(cp1252))
        case 1250?: (.singleByte(cp1250), .singleByte(cp1252))
        case 1251?: (.singleByte(cp1251), .singleByte(cp1252))
        case 1253?: (.singleByte(cp1253), .singleByte(cp1252))
        case 1254?: (.singleByte(cp1254), .singleByte(cp1252))
        case 1255?: (.singleByte(cp1255), .singleByte(cp1252))
        case 1256?: (.singleByte(cp1256), .singleByte(cp1252))
        case 1257?: (.singleByte(cp1257), .singleByte(cp1252))
        case 1258?: (.singleByte(cp1258), .singleByte(cp1252))
        case 874?: (.singleByte(cp874), .singleByte(cp1252))
        case 932?: (.doubleByte(cp932), .singleByte(cp1252))
        case 936?: (.doubleByte(cp936), .singleByte(cp1252))
        case 949?: (.doubleByte(cp949), .singleByte(cp1252))
        case 950?: (.doubleByte(cp950), .singleByte(cp1252))
        case 10000?: (.singleByte(macRoman), .singleByte(macRoman))
        case let page? where unreadMacPages.contains(page): (.unread, .singleByte(macRoman))
        case let page? where unreadPages.contains(page): (.unread, .singleByte(cp1252))
        default: (.singleByte(macRoman), .singleByte(macRoman))
        }
    }

    /// The Mac pages AppKit reads in `\ansicpg` besides Mac OS Roman, whose fonts it reads in Mac OS
    /// Roman (probe of 24 Oct 2026, every number from 0 to 65535).
    static let unreadMacPages: Set<Int> = [
        10001, 10002, 10003, 10004, 10005, 10006, 10007, 10008, 10010, 10017, 10021, 10029, 10079, 10081, 10082,
    ]

    /// The other pages AppKit reads in `\ansicpg`, whose fonts it reads in Windows-1252: EBCDIC 37, the
    /// DOS, ISO 8859, KOI8, EUC, ISO 2022 and GB 18030 pages, US-ASCII, and UTF-7, UTF-8, UTF-16 and
    /// UTF-32. CFString names Johab (1361) and 28602 too, but AppKit reads them as a page it does not know.
    static let unreadPages: Set<Int> = [
        37, 437, 737, 775, 850, 851, 852, 855, 857, 860, 861, 862, 863, 864, 865, 866, 869, 1200, 1201,
        20127, 20866, 21866, 28591, 28592, 28593, 28594, 28595, 28596, 28597, 28598, 28599, 28600, 28601, 28603,
        28604, 28605, 28606, 50221, 50225, 50227, 51932, 51936, 51949, 51950, 52936, 54936, 65000, 65001, 65005,
        65006,
    ]

    /// A byte outside text, such as in a font's name or a field's instruction, in Windows-1252, or
    /// as itself where that defines none.
    static func windows1252(_ byte: UInt8) -> UInt16 {
        guard byte >= 0x80 else { return UInt16(byte) }
        let unit = cp1252[Int(byte) - 0x80]
        return unit == 0 ? UInt16(byte) : unit
    }

    /// AppKit's reading of text bytes it holds together, or nil when it reads none of them: a byte
    /// the page does not define loses them all, but for the last when `dropsTrailingLead` and the
    /// rest decode. ASCII is itself in every page but those the codec does not read.
    func decode(_ bytes: [UInt8], dropsTrailingLead: Bool) -> [UInt16]? {
        if let units = decode(bytes) { return units }
        guard dropsTrailingLead, !bytes.isEmpty else { return nil }
        return decode(Array(bytes.dropLast()))
    }

    private func decode(_ bytes: [UInt8]) -> [UInt16]? {
        switch self {
        case .singleByte(let table):
            var units: [UInt16] = []
            units.reserveCapacity(bytes.count)
            for byte in bytes {
                guard byte >= 0x80 else {
                    units.append(UInt16(byte))
                    continue
                }
                let unit = table[Int(byte) - 0x80]
                guard unit != 0 else { return nil }
                units.append(unit)
            }
            return units
        case .doubleByte(let table):
            return table.decode(bytes)
        case .unread:
            guard bytes.allSatisfy({ $0 < 0x80 }) else { return nil }
            return bytes.map(UInt16.init)
        }
    }
}

/// A double-byte code page: its lead bytes, each the first of a pair, the bytes that are characters
/// by themselves, and the pairs it does not define, with Foundation reading the rest. Any other byte
/// from 0x80 AppKit reads as a lead byte of no pair, which is no character.
struct RTFDoubleByteTable: Sendable {
    private enum Kind: Sendable {
        case undefined, lead
        case single(UInt16)
    }

    /// The CFString encoding Foundation reads the pairs in.
    let encoding: UInt32
    /// Each byte from 0x80.
    private let kinds: [Kind]
    /// The pairs the page does not define, as lead << 8 | trail: each range's first and last, ascending.
    private let undefined: [UInt16]
    /// The pairs Foundation on Linux reads otherwise, or not at all, with AppKit's reading.
    private let overrides: [UInt16: [UInt16]]

    init(encoding: UInt32, leads: [ClosedRange<UInt8>], singles: [(ClosedRange<UInt8>, UInt16)], undefined: [UInt16],
         overrides: [UInt16: [UInt16]]) {
        var kinds = [Kind](repeating: .undefined, count: 128)
        for range in leads {
            for byte in range { kinds[Int(byte) - 0x80] = .lead }
        }
        for (range, first) in singles {
            for byte in range { kinds[Int(byte) - 0x80] = .single(first + UInt16(byte - range.lowerBound)) }
        }
        self.encoding = encoding
        self.kinds = kinds
        self.undefined = undefined
        self.overrides = overrides
    }

    /// A pair the page defines: a trail from 0x40 to 0xFE, outside its undefined ranges.
    func defines(_ pair: UInt16) -> Bool {
        let trail = pair & 0xFF
        guard trail >= 0x40, trail <= 0xFE else { return false }
        // The last range starting at or before the pair.
        var low = 0, high = undefined.count / 2
        while low < high {
            let middle = (low + high) / 2
            if undefined[middle * 2] <= pair { low = middle + 1 } else { high = middle }
        }
        return low == 0 || undefined[(low - 1) * 2 + 1] < pair
    }

    /// The bytes read, or nil when a byte or pair is not a character, a lead byte at the end included.
    func decode(_ bytes: [UInt8]) -> [UInt16]? {
        var units: [UInt16] = []
        units.reserveCapacity(bytes.count)
        // The pairs Foundation reads, all at once, and where each one's unit goes.
        var pairs: [UInt8] = []
        var slots: [Int] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            guard byte >= 0x80 else {
                units.append(UInt16(byte))
                index += 1
                continue
            }
            switch kinds[Int(byte) - 0x80] {
            case .undefined:
                return nil
            case .single(let unit):
                units.append(unit)
                index += 1
            case .lead:
                guard index + 1 < bytes.count else { return nil }
                let pair = UInt16(byte) << 8 | UInt16(bytes[index + 1])
                guard defines(pair) else { return nil }
                if let override = overrides[pair] {
                    units += override
                } else {
                    slots.append(units.count)
                    units.append(0)
                    pairs += [byte, bytes[index + 1]]
                }
                index += 2
            }
        }
        return fill(units, pairs, slots)
    }

    /// `units` with Foundation's reading of `pairs` at `slots`, one unit each, or each pair read
    /// alone where Foundation's reading is not one unit a pair.
    private func fill(_ units: [UInt16], _ pairs: [UInt8], _ slots: [Int]) -> [UInt16]? {
        guard !slots.isEmpty else { return units }
        if let read = foundation(pairs), read.count == slots.count {
            var units = units
            for (slot, unit) in zip(slots, read) { units[slot] = unit }
            return units
        }
        var out: [UInt16] = []
        var next = 0
        for (number, slot) in slots.enumerated() {
            out += units[next..<slot]
            guard let read = foundation(Array(pairs[number * 2...number * 2 + 1])) else { return nil }
            out += read
            next = slot + 1
        }
        out += units[next...]
        return out
    }

    private func foundation(_ bytes: [UInt8]) -> [UInt16]? {
        String(bytes: bytes, encoding: String.Encoding(rawValue: UInt(0x8000_0000 | encoding))).map { Array($0.utf16) }
    }
}
