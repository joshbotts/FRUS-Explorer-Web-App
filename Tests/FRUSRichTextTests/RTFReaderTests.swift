// The codec's reader (S15d) on what the golden spans hold little of: what it reads as a document,
// its limit on nesting, the code page of each text byte and how it holds them, `\u`'s fallback text,
// control symbols, `\*`, a field's text, the fonts and baseline offsets that break runs, and links.
// Each expectation is AppKit's reading, as probes on macOS 27.0.1 found it on 24 Oct 2026, but the
// nesting limit, which is the codec's own, and a page the codec does not read; the read fixtures of
// fixtures/rich-text/read hold the same documents to AppKit's reading at each pin move.

@testable import FRUSRichText
import Testing

@Suite struct RTFReaderTests {
    static func read(_ rtf: String) -> RTFReading? { RTFReader.read(Array(rtf.utf8)) }

    static func text(_ rtf: String) -> String? { read(rtf)?.text }

    /// `\uN` and its delimiter, built so that no escape in this source spells it.
    static func u(_ value: Int) -> String { "\\u\(value) " }

    @Test func aDocumentIsAGroupOpenedAfterLineBreaksAndClosed() {
        #expect(Self.text(#"{\rtf1\ansi ab}"#) == "ab")
        #expect(Self.text("\n\r\n" + #"{\rtf1\ansi ab}"#) == "ab", "line breaks before it")
        #expect(Self.text("\u{0}" + #"{\rtf1\ansi ab}"#) == "ab", "a NUL before it")
        #expect(Self.text(" " + #"{\rtf1\ansi ab}"#) == nil, "AppKit reads nothing after a space")
        #expect(Self.text("\t" + #"{\rtf1\ansi ab}"#) == nil, "or a tab")
        #expect(Self.text(#"{ab}"#) == "ab" && Self.text(#"{\foo ab}"#) == "ab", #"AppKit needs no \rtf"#)
        #expect(Self.text(#"{\rtf1\ansi abc} trailing"#) == "abc" && Self.text(#"{\rtf1\ansi abc}}"#) == "abc",
                "what follows the document's group is not read")
        #expect(Self.text(#"{\rtf1\ansi abc"#) == nil, "a document cut short is not read")
        #expect(Self.text(#"{\rtf1\ansi {\b abc}"#) == nil)
        #expect(Self.text(#"{\rt"#) == nil)
        #expect(Self.text("Not RTF.") == nil && Self.text("") == nil)
    }

    /// The codec's own guard: AppKit reads 600 groups nested, and a note never holds 256.
    @Test func moreThan256GroupsNestedAreNotRead() {
        func nested(_ groups: Int) -> String {
            "{\\rtf1 " + String(repeating: "{", count: groups - 1) + "x" + String(repeating: "}", count: groups)
        }
        #expect(Self.text(nested(256)) == "x", "256 groups in all, the document's included")
        #expect(Self.text(nested(257)) == nil)
    }

    @Test func binaryDataIsReadAsRTF() {
        #expect(Self.text(#"{\rtf1\ansi a\bin3 xyzb}"#) == "axyzb", #"AppKit skips no data after \bin"#)
        #expect(Self.text(#"{\rtf1\ansi a\bin99 x}"#) == "ax", "and a count beyond the data is no matter")
        #expect(Self.text(#"{\rtf1\ansi a{\*\pict\bin3 {}}}b}"#) == "a", "the third brace closes the document")
    }

    @Test func unicodeFallbackCountsAreScopedToTheirGroup() {
        #expect(Self.text(#"{\rtf1\ansi\uc2"# + Self.u(20013) + #"\'d6\'d0x}"#) == "\u{4E2D}x")
        #expect(Self.text(#"{\rtf1\ansi caf"# + Self.u(233) + "XY}") == "caf\u{E9}Y", "one fallback character by default")
        #expect(Self.text(#"{\rtf1\ansi {\uc0 a"# + Self.u(233) + "X}b" + Self.u(233) + "YZ}") == "a\u{E9}Xb\u{E9}Z")
        // The writer's one \uc0 holds in a link's field result, a group within groups.
        let field = Self.read(#"{\rtf1\ansi\uc0 {\field{\*\fldinst{HYPERLINK "https://example.com/"}}{\fldrslt caf"#
                              + Self.u(233) + "X}} after" + Self.u(233) + "W}")
        #expect(field?.text == "caf\u{E9}X after\u{E9}W")
        #expect(field?.mergedRuns == [RichTextRun(text: "caf\u{E9}X", linkURL: "https://example.com/"), RichTextRun(text: " after\u{E9}W")])
    }

    /// AppKit counts only text as a `\u`'s fallback: a byte but a space, which it drops uncounted,
    /// and \' \\ \{ \} \:. A tab, a control word, any other control symbol or a group ends it.
    @Test func aUnicodeFallbackIsTextAndEndsAtAnythingElse() {
        let p = Self.u(1055)
        #expect(Self.text(#"{\rtf1\ansi\uc1 "# + p + #"\tab x}"#) == "\u{41F}\tx")
        #expect(Self.text(#"{\rtf1\ansi\uc1 "# + p + #"\par x}"#) == "\u{41F}\nx")
        #expect(Self.text(#"{\rtf1\ansi\uc1 "# + p + Self.u(1056) + "x}") == "\u{41F}\u{420}", "another escape, and its own fallback")
        #expect(Self.text(#"{\rtf1\ansi\uc2 "# + p + #"\foo xy}"#) == "\u{41F}xy")
        #expect(Self.text(#"{\rtf1\ansi\uc2 "# + p + #"\*x}"#) == "\u{41F}x")
        #expect(Self.text(#"{\rtf1\ansi\uc3 "# + p + #"a\par bcd}"#) == "\u{41F}\nbcd")
        #expect(Self.text(#"{\rtf1\ansi\uc2 "# + p + #"\~xy}"#) == "\u{41F}\u{A0}xy")
        #expect(Self.text(#"{\rtf1\ansi\uc2 "# + p + #"\:\'41xy}"#) == "\u{41F}xy", #"\: and \' count"#)
        #expect(Self.text(#"{\rtf1\ansi\uc2 "# + p + "x  y z}") == "\u{41F} z", "a space counts not")
        #expect(Self.text(#"{\rtf1\ansi\uc1 "# + p + "\tx}") == "\u{41F}\tx", "a tab ends it")
    }

    /// U+FFFD AppKit reads as no character, and the fallback after it as text, so the Mac's own
    /// RTF loses it.
    @Test func aReplacementCharacterIsReadAsNone() {
        #expect(Self.text(#"{\rtf1\ansi\uc0 a"# + Self.u(65533) + "b}") == "ab")
        #expect(Self.text(#"{\rtf1\ansi\uc0 a"# + Self.u(-3) + "b}") == "ab")
        #expect(Self.text(#"{\rtf1\ansi\uc1 a"# + Self.u(65533) + "?b}") == "a?b")
        #expect(Self.text(#"{\rtf1\ansi\uc0 a"# + Self.u(55357) + "b}") == "a\u{FFFD}b", "a lone surrogate is U+FFFD")
    }

    @Test func controlSymbolsAndWordsAreReadAsAppKitReadsThem() {
        #expect(Self.text(#"{\rtf1\ansi a\:b}"#) == "a:b")
        #expect(Self.text(#"{\rtf1\ansi a\'0ab\'0dc\'00d\'0be}"#) == "abcd\u{0B}e", "a line feed, a return and a NUL are ignored")
        #expect(Self.text(#"{\rtf1\ansi a\b- x\i--1 y}"#) == "ax-1 y", "a minus with no digit belongs to the word")
        #expect(Self.text(#"{\rtf1\ansi a\ltrmark\rtlmark\qmspace b\page c}"#) == "ab\u{0C}c")
    }

    /// `\*` marks a destination only first in a group, and AppKit skips one it does not know and
    /// reads one it knows as the word.
    @Test func aStarMarksADestinationOnlyFirstInAGroup() {
        #expect(Self.text(#"{\rtf1\ansi a{\*\foo b}c}"#) == "ac")
        #expect(Self.text("{\\rtf1\\ansi a{\\*\n\\foo b}c}") == "ac", "after a line break")
        #expect(Self.text(#"{\rtf1\ansi a\*\foo b}"#) == "ab")
        #expect(Self.text(#"{\rtf1\ansi a{\b\*\foo b}c}"#) == "abc")
        #expect(Self.text(#"{\rtf1\ansi a{\* \foo b}c}"#) == "a bc")
        #expect(Self.text(#"{\rtf1\ansi a{\*\*\foo b}c}"#) == "abc")
        #expect(Self.read(#"{\rtf1\ansi a{\*\b x}c}"#)?.mergedRuns == [RichTextRun(text: "a"), RichTextRun(text: "x", bold: true), RichTextRun(text: "c")])
    }

    /// Text in a field's group but outside its result AppKit reads, linked once the instruction has
    /// been read.
    @Test func aFieldsOtherTextIsRead() {
        let reading = Self.read(#"{\rtf1\ansi {\field X{\*\fldinst{HYPERLINK "https://e.com/"}}Y{\fldrslt L}\b M}N}"#)
        #expect(reading?.mergedRuns == [RichTextRun(text: "X"), RichTextRun(text: "YL", linkURL: "https://e.com/"),
                                         RichTextRun(text: "M", bold: true, linkURL: "https://e.com/"), RichTextRun(text: "N")])
    }

    /// `\nosupersub` ends superscript and subscript only: AppKit keeps the run raised by `\up6`
    /// before it apart from the plain one, so a blank line between them splits no paragraph.
    @Test func noSuperscriptKeepsABaselineOffset() throws {
        let reading = try #require(Self.read("{\\rtf1\\ansi \\sub s\\up6 \\nosupersub x\\\n\\up0 \\\ny}"))
        #expect(reading.text == "sx\n\ny")
        #expect(reading.runs.map(\.text) == ["s", "x\n", "\ny"])
    }

    static func runs(_ rtf: String) -> [String]? { read(rtf)?.runs.map(\.text) }

    /// `\up` and `\dn` set one baseline offset, 12 half points by default, which `\up0` and `\dn0`
    /// both end, as Apple's writer ends a lowered run with `\up0`.
    @Test func upAndDownAreOneBaselineOffset() {
        #expect(Self.runs("{\\rtf1\\ansi \\dn4 x\\\n\\up0 \\\ny}") == ["x\n", "\ny"])
        #expect(Self.runs("{\\rtf1\\ansi \\up6 x\\\n\\dn0 \\\ny}") == ["x\n", "\ny"])
        #expect(Self.runs("{\\rtf1\\ansi \\up4 x\\\n\\dn-4 \\\ny}") == ["x\n\ny"])
        #expect(Self.runs("{\\rtf1\\ansi \\up x\\\n\\up12 \\\ny}") == ["x\n\ny"])
        #expect(Self.runs("{\\rtf1\\ansi \\up x\\\n\\up6 \\\ny}") == ["x\n", "\ny"])
    }

    /// AppKit's font for text in no font, or in one the table does not hold or gives no name, is
    /// Helvetica, whatever `\deff` names; `\plain` selects font 0.
    @Test func runsBreakAtTheFontAppKitApplies() {
        #expect(Self.runs("{\\rtf1\\ansi x\\\n\\plain \\\ny}") == ["x\n\ny"], "a table with no font 0")
        #expect(Self.runs("{\\rtf1\\ansi{\\fonttbl\\f1\\fnil Times-Roman;} x\\\n\\f5 \\\ny}") == [" x\n\ny"])
        #expect(Self.runs("{\\rtf1\\ansi{\\fonttbl\\f0\\fnil Helvetica;\\f1\\fnil;} x\\\n\\f0 \\\ny\\\n\\f1 \\\nz}") == [" x\n\ny\n\nz"])
        #expect(Self.runs("{\\rtf1\\ansi\\deff1{\\fonttbl\\f0\\fnil Courier;\\f1\\fnil Times-Roman;} x\\\n\\f1 \\\ny}") == [" x\n", "\ny"],
                "text before any font is Helvetica, not the default font's")
        #expect(Self.runs("{\\rtf1\\ansi\\deff1{\\fonttbl\\f0\\fnil Courier;\\f1\\fnil Times-Roman;} x\\\n\\plain \\\ny}") == [" x\n", "\ny"])
        #expect(Self.runs(#"{\rtf1\ansi a\highlight3 b}"#) == ["ab"], "a word AppKit does not know breaks no run")
    }

    // MARK: Code pages

    /// Text in no font of the table is in the document's code page, a font's in its charset's, and a
    /// font of no charset's in Windows-1252: \ansicpg1251 changes only text in no font.
    @Test func ansicpgIsTheCodePageOfTextInNoFont() {
        let rtf = #"{\rtf1\ansi\ansicpg1251{\fonttbl\f0\fnil\fcharset0 Helvetica;\f1\fnil\fcharset204 PTSans-Regular;\f2\fnil Helvetica;}"#
            + #"\'cf\par\f0 \'cf\par\f1 \'cf\par\f2 \'cf\par\f9 \'cf}"#
        #expect(Self.text(rtf) == "\u{041F}\n\u{00CF}\n\u{041F}\n\u{00CF}\n\u{041F}", "no font, charset 0, 204, none, a font not in the table")
        #expect(Self.text(#"{\rtf1\ansi\ansicpg1251{\fonttbl\f1\fnil\fcharset0 A;}{\f1 \'c0}\'c0}"#) == "\u{00C0}\u{0410}",
                "a group's font ends with it")
        #expect(Self.text(#"{\rtf1\ansi\deff1{\fonttbl\f1\fnil\fcharset204 PTSans;}\'c0}"#) == "\u{00C0}", #"\deff selects no font"#)
        #expect(Self.text(#"{\rtf1\ansi{\fonttbl\f0\fnil\fcharset204 A;\f1\fnil\fcharset0 B;}\f1 \plain \'c0}"#) == "\u{0410}",
                #"\plain selects font 0"#)
        #expect(Self.text(#"{\rtf1\ansi\deff1{\fonttbl\f0\fnil\fcharset204 A;\f1\fnil\fcharset0 B;}\f1 \plain \'c0}"#) == "\u{0410}",
                #"whatever \deff names"#)
    }

    @Test func macIsMacOSRomanForTextInNoFontOrAFontOfNoCharset() {
        let rtf = #"{\rtf1\mac{\fonttbl\f0\fnil Helvetica;\f1\fnil\fcharset0 Helvetica;\f2\fnil\fcharset77 Helvetica;\f3\fnil\fcharset1 Helvetica;}"#
            + #"\'8e\par\f0 \'8e\par\f1 \'8e\par\f2 \'8e\par\f3 \'8e}"#
        #expect(Self.text(rtf) == "\u{E9}\n\u{E9}\n\u{017D}\n\u{E9}\n\u{E9}", "no font, no charset, 0, 77, 1")
        #expect(Self.text(#"{\rtf1\ansicpg1251\mac \'c0}"#) == "\u{BF}", #"the last of \mac and \ansicpg holds"#)
        #expect(Self.text(#"{\rtf1\mac\ansicpg1251 \'c0}"#) == "\u{0410}")
        #expect(Self.text(#"{\rtf1\mac\ansicpg1251{\fonttbl\f1\fnil PTSans;}\f1 \'c0}"#) == "\u{C0}", #"\ansicpg's fonts are Windows-1252's"#)
    }

    @Test func aDocumentThatNamesNoCodePageIsNeXTSTEPs() {
        #expect(Self.text(#"{\rtf1 \'c0\'e9}"#) == "\u{B9}\u{D8}")
        #expect(Self.text(#"{\rtf1{\fonttbl\f0\fnil A;}\f0 \'8e}"#) == "\u{17D}", "with fonts in Windows-1252")
    }

    /// `\pc` and `\pca` name NeXTSTEP, and make a font of no charset Windows-1252's.
    @Test func pcIsNeXTSTEP() {
        #expect(Self.text(#"{\rtf1\ansicpg1251 \pc \'c0}"#) == "\u{B9}")
        #expect(Self.text(#"{\rtf1\ansicpg1251 \pca \'c0}"#) == "\u{B9}")
        #expect(Self.text(#"{\rtf1\mac\pc{\fonttbl\f0\fnil A;}\f0 \'8e}"#) == "\u{17D}")
    }

    /// The page the last `\f` or the last word naming the document's page set ends with its group;
    /// the document's page, and that of a font of no charset, hold beyond it.
    @Test func codePagesAreScopedAsAppKitScopesThem() {
        #expect(Self.text(#"{\rtf1\ansi \'8e{\mac \'8e}\'8e}"#) == "\u{17D}\u{E9}\u{17D}")
        #expect(Self.text(#"{\rtf1\ansi\ansicpg1251 \'c0{\ansicpg1252 \'c0}\'c0}"#) == "\u{410}\u{C0}\u{410}")
        #expect(Self.text(#"{\rtf1{\ansi}\'c0}"#) == "\u{B9}")
        #expect(Self.text(#"{\rtf1\ansi{\fonttbl\f0\fnil\fcharset0 A;}{\ansicpg1251}\f0 \'c0\f9 \'c0}"#) == "\u{C0}\u{410}",
                "a font the table does not hold is in the document's page")
        #expect(Self.text(#"{\rtf1\ansi{\fonttbl\f0\fnil A;}{\mac}\f0 \'8e}"#) == "\u{E9}")
        #expect(Self.text(#"{\rtf1\ansi{\fonttbl\f0\fnil\fcharset204 A;}\f0 \'c0{\mac \'c0}\'c0\ansicpg1253 \'c1}"#)
                    == "\u{410}\u{BF}\u{410}\u{391}", "a word after the font names the page of what follows")
        #expect(Self.text(#"{\rtf1\ansi\ansicpg1251\f0{\fonttbl\f0\fnil\fcharset0 A;}\'c0}"#) == "\u{410}",
                "a font selected before the table holds it")
    }

    /// A font of no charset takes the fonts' page when it is first selected, and keeps it.
    @Test func aFontOfNoCharsetKeepsItsFirstPage() {
        #expect(Self.text(#"{\rtf1\ansi{\fonttbl\f0\fnil A;\f1\fnil B;}\f0 \'8e\mac\f1 \'8e\f0 \'8e}"#) == "\u{17D}\u{E9}\u{17D}")
        #expect(Self.text(#"{\rtf1\ansi{\fonttbl\f0\fnil A;}{\f0 \'8e}\mac\plain \'8e}"#) == "\u{17D}\u{17D}")
    }

    /// `\ansicpg` of a Mac page makes a font of no charset Mac OS Roman's, and so does one AppKit
    /// does not know, which it reads as Mac OS Roman; a page AppKit reads and the codec does not,
    /// the codec reads no byte from 0x80 in.
    @Test func ansicpgsOtherPages() {
        let fonts = #"{\fonttbl\f0\fnil A;\f1\fnil\fcharset1 B;\f2\fnil\fcharset0 C;}\f0 \'8e\f1 \'8e\f2 \'8e}"#
        #expect(Self.text(#"{\rtf1\ansi\ansicpg10000"# + fonts) == "\u{E9}\u{E9}\u{17D}")
        #expect(Self.text(#"{\rtf1\ansi\ansicpg10007"# + fonts) == "\u{E9}\u{E9}\u{17D}")
        #expect(Self.text(#"{\rtf1\ansi\ansicpg9999 \'8e}"#) == "\u{E9}" && Self.text(#"{\rtf1\ansi\ansicpg \'8e}"#) == "\u{E9}")
        #expect(Self.text(#"{\rtf1\ansi\ansicpg437 ab\'bb\par c}"#) == "\nc", "the codec's own: AppKit reads U+2557")
    }

    /// AppKit holds text bytes, ASCII included, until a control word it acts on, a group's start or
    /// end, or a control symbol but \' \\ \{ \}, and decodes them together: a byte its code page does
    /// not define loses them all, and a lead byte with no trail is dropped alone.
    @Test func textBytesAreDecodedTogether() {
        let fonts = #"{\rtf1\ansi\ansicpg1252{\fonttbl\f0\fnil\fcharset0 Helvetica;\f1\fnil\fcharset134 PingFangSC-Regular;"#
            + #"\f2\fnil\fcharset204 PTSans-Regular;\f3\fnil\fcharset136 PingFangTC-Regular;}"#
        #expect(Self.text(fonts + #"\f0 before \b bold\b0  plain \'81 lost\b  after}"#) == "before bold after")
        #expect(Self.text(fonts + #"\f1 lead\'d6\par next}"#) == "lead\nnext", "a lead byte with no trail")
        #expect(Self.text(fonts + #"\f1 \'d6P}"#) == "\u{8AF4}", "an ASCII trail")
        #expect(Self.text(fonts + #"\f1 \'d6\\}"#) == "\u{8B00}", "an escaped trail")
        #expect(Self.text(fonts + #"\f1 \'d6\foo \'d0}"#) == "\u{4E2D}", "a word AppKit does not know holds the bytes")
        #expect(Self.text(fonts + #"\f1 \'d6\cf0 \'d0b}"#) == "\u{884E}", "one it acts on decodes them, and the lead is dropped")
        #expect(Self.text(fonts + #"\f1 x\par a\'d6\'7fb\par y}"#) == "x\n\ny", "a pair the page does not define")
        #expect(Self.text(fonts + #"\f2 x\par \'c0\'98\'c1\par y}"#) == "x\n\ny", "a byte the page does not define")
        // Pairs Foundation on Linux reads otherwise, which Apple's writer writes.
        #expect(Self.text(fonts + #"\f1 \'a2\'e3\f3 \'a1\'f3\'a2\'cc}"#) == "\u{20AC}\u{2609}\u{5341}\u{F87F}")
        // AppKit decodes at every word it knows, a document's own words among them.
        #expect(Self.text(#"{\rtf1\ansi x\cocoartf2907 \'81\par}"#) == "x\n")
        #expect(Self.text(#"{\rtf1\ansi x\paperw11900 \'81\par}"#) == "x\n")
        #expect(Self.text(#"{\rtf1\ansi x\insrsid1 \'81\par}"#) == "\n", "but not at Word's revision marks")
    }

    /// After a word that names a double-byte page as the document's, a lead byte at the end loses
    /// the bytes held; after `\f` selects one, it is dropped alone, and so is any last byte the
    /// page in force then does not define.
    @Test func aTrailingLeadLosesTheBytesInTheDocumentsPage() {
        #expect(Self.text(#"{\rtf1\ansi\ansicpg936 ab\'d6\'d0cd\'d6\par}"#) == "\n")
        #expect(Self.text(#"{\rtf1\ansi\ansicpg932 ab\'82\par}"#) == "\n")
        #expect(Self.text(#"{\rtf1\ansi\ansicpg936 \f9 ab\'d6\par}"#) == "ab\n")
        #expect(Self.text(#"{\rtf1\ansi{\fonttbl\f0\fnil\fcharset134 A;}\f0 \ansi ab\'81\par}"#) == "ab\n")
        #expect(Self.text(#"{\rtf1\ansi\ansicpg936{\fonttbl\f0\fnil\fcharset0 A;}\f0 \ansicpg936 ab\'d6\par}"#) == "\n")
    }

    @Test func linksAreReadAsTheAppReadsThem() {
        func link(_ url: String) -> String? {
            Self.read(#"{\rtf1\ansi {\field{\*\fldinst{HYPERLINK ""# + url + #""}}{\fldrslt L}}}"#)?.runs.first?.linkURL
        }
        #expect(link("https://example.org/a b") == "https://example.org/a%20b")
        #expect(link("https://example.org/a|b^c") == "https://example.org/a%7Cb%5Ec")
        #expect(link("https://example.org/caf\\'e9") == "https://example.org/caf%C3%A9")
        #expect(link("https://example.org/a#b#c") == "https://example.org/a#b%23c")
        #expect(link("not%20a%20url") == "not%20a%20url")
        #expect(link("https://example.org:x/") == nil, "a port that is not digits is no link")
        #expect(link("https://[::1|]/x") == nil && link("https://[::1]/x") == "https://[::1]/x", "nor an IP literal holding what a URL may not")
        #expect(link("https://[fe80::1%en0]/x") == "https://[fe80::1%25en0]/x" && link("https://[fe80::1%25en0]/x") == "https://[fe80::1%25en0]/x")
    }
}
