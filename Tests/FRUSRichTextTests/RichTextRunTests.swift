// The codec's rules for runs on the wire (S15d): what the store takes as a note's formatting, the
// canonical form it writes them in, and the app's reading of a link.

import FRUSRichText
import Testing

@Suite struct RichTextRunTests {
    @Test func runsMustHoldTheBodyTextExactly() {
        let runs = [RichTextRun(text: "a "), RichTextRun(text: "b", bold: true)]
        #expect(RichTextRuns.problem(runs, bodyText: "a b") == nil)
        #expect(RichTextRuns.problem(runs, bodyText: "a b ") != nil)
        #expect(RichTextRuns.problem([], bodyText: "") == nil)
    }

    @Test func aColourMustBeHexAndNotNearBlack() {
        func problem(_ hex: String) -> String? { RichTextRuns.problem([RichTextRun(text: "x", colorHex: hex)], bodyText: "x") }
        #expect(problem("336699") == nil)
        #expect(problem("141414") == nil, "the writer's 20 reads above 0.08")
        #expect(problem("131313") != nil, "19 reads below 0.08 in every channel")
        #expect(problem("130000") != nil)
        #expect(problem("140000") == nil)
        #expect(problem("33669g") != nil)
        #expect(problem("33669") != nil)
        #expect(problem("aabbcc") != nil, "uppercase only")
    }

    @Test func aLinkMustBeOneTheWriterCanWrite() {
        #expect(RichTextRuns.linkProblem("https://example.com/a?b=c#d") == nil)
        #expect(RichTextRuns.linkProblem("not%20a%20url") == nil, "the Mac links any text, which AppKit escapes")
        #expect(RichTextRuns.linkProblem("javascript:alert(1)") == nil, "kept, though never followed")
        #expect(RichTextRuns.linkProblem("a b") != nil)
        #expect(RichTextRuns.linkProblem("a\"b") != nil)
        #expect(RichTextRuns.linkProblem("a\\b") != nil)
        #expect(RichTextRuns.linkProblem("a{b") != nil)
        #expect(RichTextRuns.linkProblem("caf\u{E9}") != nil)
        #expect(RichTextRuns.linkProblem("") != nil)
        #expect(RichTextRuns.linkProblem(String(repeating: "a", count: 2049)) != nil)
        #expect(RichTextRuns.linkProblem("https://example.com/a|b[c]") == nil, "the app's reading percent-encodes them")
        #expect(RichTextRuns.linkProblem("https://example.com:8x/") != nil, "the app reads a port that is not digits as no link")
        #expect(RichTextRuns.linkProblem("https://example.com:8080/") == nil)
        #expect(RichTextRuns.linkProblem("https://[::1|]/") != nil, "nor an IP literal holding what a URL may not")
        #expect(RichTextRuns.linkProblem(String(repeating: "|", count: 700)) != nil, "2,100 characters as the app reads it")
    }

    /// AppKit's reading of a link (probe of 24 Oct 2026): what a URL may not hold where it stands,
    /// percent-encoded, and the rest as it is.
    @Test func aLinkReadsAsTheAppReadsIt() {
        for (url, read) in [
            ("https://example.com/a|b^c`d", "https://example.com/a%7Cb%5Ec%60d"),
            ("https://example.com/a[b]<c>", "https://example.com/a%5Bb%5D%3Cc%3E"),
            ("https://example.com/100%", "https://example.com/100%25"),
            ("https://example.com/a%zzb%7c%41", "https://example.com/a%25zzb%7c%41"),
            ("https://example.com/a#b#c", "https://example.com/a#b%23c"),
            ("https://u@v@example.com/", "https://u%40v@example.com/"),
            ("https://u:p|w@example.com/", "https://u:p%7Cw@example.com/"),
            ("https://[::1]:8080/a|b", "https://[::1]:8080/a%7Cb"),
            ("https://ex|ample.com:80/", "https://ex%7Cample.com:80/"),
            ("https://example.com:/", "https://example.com:/"),
            ("mailto:a@b.c?subject=a|b#x#y", "mailto:a@b.c?subject=a%7Cb#x%23y"),
            ("x#y#z", "x#y%23z"),
            ("//h|/p", "//h%7C/p"),
            (#"https://example.com/a b\c"d{e}"#, "https://example.com/a%20b%5Cc%22d%7Be%7D"),
            ("https://example.com/caf\u{E9}", "https://example.com/caf%C3%A9"),
            ("HTTPS://Example.COM/A?b?c", "HTTPS://Example.COM/A?b?c"),
            ("javascript:alert(1)", "javascript:alert(1)"),
            ("not%20a%20url", "not%20a%20url"),
        ] {
            #expect(RichTextRuns.appReading(ofLink: url) == read, "\(url)")
        }
        for url in ["https://example.com:8x/", "https://[::1]:x/", "https://u:p@example.com:8|/", "http://a:b:c/"] {
            #expect(RichTextRuns.appReading(ofLink: url) == nil, "\(url)")
        }
    }

    /// Runs in canonical form: a line break formatted as the text before it, plain at the start;
    /// links as the app reads them; neighbours of one formatting joined; none empty. Canonical runs
    /// are their own canonical form, and what the codec writes for them it reads back to them.
    @Test func canonicalRunsAreWhatTheCodecReadsBack() throws {
        let given = [RichTextRun(text: "\n"), RichTextRun(text: "Bold", bold: true), RichTextRun(text: "\n\nnext"),
                     RichTextRun(text: ""), RichTextRun(text: "!", linkURL: "https://example.com/a|b"),
                     RichTextRun(text: "\n", italic: true)]
        let canonical = RichTextRuns.canonical(given)
        #expect(canonical == [RichTextRun(text: "\n"), RichTextRun(text: "Bold\n\n", bold: true), RichTextRun(text: "next"),
                              RichTextRun(text: "!\n", linkURL: "https://example.com/a%7Cb")])
        #expect(RichTextRuns.canonical(canonical) == canonical)
        let reading = try #require(RTFReader.read(RTFWriter.write(canonical)))
        #expect(reading.mergedRuns == canonical)
        // A blank line across two formattings joins one run, which the app's exporters split.
        #expect(RichTextRuns.canonical([RichTextRun(text: "x\n", bold: true), RichTextRun(text: "\ny")])
                == [RichTextRun(text: "x\n\n", bold: true), RichTextRun(text: "y")])
    }

    @Test func onlyHttpHttpsAndMailtoAreFollowed() {
        #expect(RichTextRuns.isFollowable("https://example.com"))
        #expect(RichTextRuns.isFollowable("HTTP://example.com"))
        #expect(RichTextRuns.isFollowable("mailto:a@b.c"))
        #expect(!RichTextRuns.isFollowable("javascript:alert(1)"))
        #expect(!RichTextRuns.isFollowable("data:text/html,x"))
        #expect(!RichTextRuns.isFollowable("example.com"))
    }

    @Test func runsMayHoldLineBreaksAndTabsButNoOtherControls() {
        #expect(RichTextRuns.textProblem("a\nb\tc\u{2028}d") == nil)
        #expect(RichTextRuns.textProblem("a\rb") != nil)
        #expect(RichTextRuns.textProblem("a\u{2029}b") != nil)
        #expect(RichTextRuns.textProblem("a\u{FFFD}b") != nil, "the app's RTF reader drops U+FFFD")
        #expect(RichTextRuns.textProblem("a\u{FFFC}\u{FFFE}b") == nil)
        #expect(RichTextRuns.textProblem("a\u{0}b") != nil)
        #expect(RichTextRuns.textProblem("a\u{85}b") != nil)
    }

    @Test func mergingJoinsEqualNeighboursAndDropsEmptyRuns() {
        let merged = RichTextRuns.merged([RichTextRun(text: "a"), RichTextRun(text: ""), RichTextRun(text: "b"),
                                          RichTextRun(text: "c", bold: true)])
        #expect(merged == [RichTextRun(text: "ab"), RichTextRun(text: "c", bold: true)])
    }
}
