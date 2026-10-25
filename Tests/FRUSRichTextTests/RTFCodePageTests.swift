// The codec's code pages (S15d), on the platform the tests run on: one text byte or pair of each
// charset the codec reads, as AppKit reads it on macOS 27.0.1 (probe of 24 Oct 2026), so that a code
// page this platform's Foundation lacks, or reads otherwise, fails here. The golden spans' code pages
// hold every byte and pair of each.

@testable import FRUSRichText
import Testing

@Suite struct RTFCodePageTests {
    /// The bytes in a font of `charset`, as `\f` selects one, or a word that names the document's
    /// page when `named`.
    static func read(_ charset: Int?, _ bytes: [UInt8], named: Bool = false) -> [UInt16]? {
        let page = RTFCodePage.of(charset: charset) ?? .singleByte(RTFCodePage.cp1252)
        return page.decode(bytes, dropsTrailingLead: page.isDoubleByte && !named)
    }

    @Test(arguments: [
        (0, [0xE9], 0x00E9), (0, [0x80], 0x20AC), (77, [0x8E], 0x00E9),
        (128, [0x82, 0xA0], 0x3042), (128, [0x95, 0x5C], 0x8868), (128, [0xB1], 0xFF71),
        (129, [0xB0, 0xA1], 0xAC00), (134, [0xD6, 0xD0], 0x4E2D), (136, [0xA4, 0xA4], 0x4E2D),
        (136, [0xA1, 0x45], 0x2027), (161, [0xC1], 0x0391), (162, [0xD0], 0x011E), (163, [0xC3], 0x0102),
        (177, [0xE0], 0x05D0), (178, [0xC7], 0x0627), (186, [0xC0], 0x0104), (204, [0xCF], 0x041F),
        (222, [0xA1], 0x0E01), (238, [0xA3], 0x0141),
    ] as [(Int, [UInt8], UInt16)])
    func eachCharsetReadsAsTheAppReadsIt(_ charset: Int, _ bytes: [UInt8], _ unit: UInt16) {
        #expect(Self.read(charset, bytes) == [unit], "\\fcharset\(charset)")
    }

    /// Charset 136 is code page 950, as AppKit reads it, not Big5, which reads 0xA145 as U+2022.
    @Test func traditionalChineseIsCodePage950() {
        #expect(Self.read(136, [0xA1, 0x45]) == [0x2027])
        #expect(Self.read(136, [0xF9, 0xD6]) == [0x7881], "an extension Big5 lacks")
    }

    /// Pairs Foundation on Linux reads otherwise, or not at all, the first two of which Apple's
    /// writer writes: the euro sign in 936, the sun sign in 950, a character with Apple's own
    /// variant mark, and a duplicate the Mac reads in 932.
    @Test func pairsLinuxReadsOtherwiseReadAsTheAppReadsThem() {
        #expect(Self.read(134, [0xA2, 0xE3]) == [0x20AC])
        #expect(Self.read(136, [0xA1, 0xF3]) == [0x2609])
        #expect(Self.read(136, [0xA2, 0xCC]) == [0x5341, 0xF87F])
        #expect(Self.read(128, [0x85, 0x40]) == [0x2460])
    }

    @Test func aByteOrPairThePageDoesNotDefineReadsNothing() {
        #expect(Self.read(0, [0x61, 0x81, 0x62]) == nil)
        #expect(Self.read(204, [0x98]) == nil)
        #expect(Self.read(134, [0xD6, 0x7F]) == nil)
        #expect(Self.read(134, [0xD6, 0x20]) == nil, "a trail below 0x40")
        #expect(Self.read(136, [0x81, 0x40]) == nil, "a lead of no pair 950 defines")
    }

    /// After `\f` selects a double-byte page, a lead byte at the end of the bytes is dropped alone,
    /// and so is any byte that is no character by itself, which AppKit reads as a lead of no pair;
    /// after a word that names the document's page, it loses them all.
    @Test func aLeadByteWithNoTrailIsDroppedAloneInAFont() {
        #expect(Self.read(134, [0x61, 0xD6]) == [0x61])
        #expect(Self.read(134, [0xD6, 0xD0, 0xD6]) == [0x4E2D])
        #expect(Self.read(128, [0x61, 0x80]) == [0x61] && Self.read(128, [0xB1, 0xFD]) == [0xFF71])
        #expect(Self.read(136, [0x61, 0xFF]) == [0x61])
        #expect(Self.read(128, [0x80, 0x61]) == nil, "but not before another byte")
        #expect(Self.read(134, [0x61, 0xFF, 0xFF]) == nil, "and only the last")
        #expect(Self.read(134, [0x61, 0xD6], named: true) == nil && Self.read(128, [0x61, 0x80], named: true) == nil)
    }

    /// The last byte is dropped alone in any page while a double-byte font's `\f` holds, and in none
    /// that a single-byte font set.
    @Test func theLastByteIsDroppedAloneOnlyAfterADoubleByteFont() {
        let cp1252 = RTFCodePage.singleByte(RTFCodePage.cp1252)
        #expect(cp1252.decode([0x61, 0x81], dropsTrailingLead: true) == [0x61])
        #expect(cp1252.decode([0x61, 0x81], dropsTrailingLead: false) == nil)
        #expect(cp1252.decode([0x81, 0x61], dropsTrailingLead: true) == nil)
    }

    @Test func asciiIsItselfInEveryPage() {
        let ascii = Array(UInt8(0x20)...UInt8(0x7E))
        for charset in [0, 77, 128, 129, 134, 136, 161, 204, 222, 238] {
            #expect(Self.read(charset, ascii) == ascii.map(UInt16.init), "\\fcharset\(charset)")
        }
        #expect(RTFCodePage.singleByte(RTFCodePage.nextstep).decode(ascii, dropsTrailingLead: false) == ascii.map(UInt16.init))
        #expect(RTFCodePage.unread.decode(ascii, dropsTrailingLead: false) == ascii.map(UInt16.init))
    }

    static func named(_ codePage: Int?, _ bytes: [UInt8]) -> (text: [UInt16]?, fonts: [UInt16]?) {
        let named = RTFCodePage.named(byANSICodePage: codePage)
        return (named.text.decode(bytes, dropsTrailingLead: false), named.fonts.decode(bytes, dropsTrailingLead: false))
    }

    /// `\ansicpg` names the page of the text after it, and makes a font of no charset Windows-1252's,
    /// or Mac OS Roman's for a Mac page or one AppKit does not know, as AppKit reads every number
    /// from 0 to 65535 (probe of 24 Oct 2026).
    @Test func ansicpgNamesTheTextsPageAndTheFonts() {
        #expect(Self.named(1251, [0xC0]) == ([0x0410], [0x00C0]))
        #expect(Self.named(936, [0xD6, 0xD0]).text == [0x4E2D])
        #expect(Self.named(10000, [0x8E]) == ([0x00E9], [0x00E9]))
        #expect(Self.named(9999, [0x8E]) == ([0x00E9], [0x00E9]), "a page AppKit does not know is Mac OS Roman")
        #expect(Self.named(nil, [0x8E]) == ([0x00E9], [0x00E9]) && Self.named(0, [0x8E]) == ([0x00E9], [0x00E9]))
        #expect(Self.named(1361, [0xBB]).text == [0x00AA], "Johab AppKit reads as a page it does not know")
    }

    /// A page AppKit reads and the codec does not, such as DOS 437, which reads 0xBB as U+2557, or
    /// Mac Cyrillic, 10007: the codec reads no byte from 0x80 in it, and its fonts' page is AppKit's.
    @Test func aPageTheCodecDoesNotReadDecodesNoByteFrom0x80() {
        #expect(Self.named(437, [0x61, 0xBB]) == (nil, [0x0061, 0x00BB]))
        #expect(Self.named(65001, [0xC3, 0xA9]).text == nil)
        #expect(Self.named(10007, [0x8E]) == (nil, [0x00E9]))
        #expect(Self.named(437, [0x61]).text == [0x0061])
    }
}
