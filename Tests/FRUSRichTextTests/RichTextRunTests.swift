// The codec's rules for runs on the wire (S15d): what the store takes as a note's formatting.

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
        #expect(RichTextRuns.textProblem("a\u{0}b") != nil)
        #expect(RichTextRuns.textProblem("a\u{85}b") != nil)
    }

    @Test func mergingJoinsEqualNeighboursAndDropsEmptyRuns() {
        let merged = RichTextRuns.merged([RichTextRun(text: "a"), RichTextRun(text: ""), RichTextRun(text: "b"),
                                          RichTextRun(text: "c", bold: true)])
        #expect(merged == [RichTextRun(text: "ab"), RichTextRun(text: "c", bold: true)])
    }
}
