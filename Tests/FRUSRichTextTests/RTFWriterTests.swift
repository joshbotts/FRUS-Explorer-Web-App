// The codec's writer (S15d) on what the golden spans' web cases do not show: its cost for a note of
// many colours, and the link it writes.

import FRUSRichText
import Testing

@Suite struct RTFWriterTests {
    /// A note's body may be 4 MiB, room for some 50,000 runs each of its own colour, and the writer
    /// writes them in time linear in the runs: each colour's index is looked up, not searched for.
    @Test func manyColoursAreWrittenPromptly() throws {
        let runs = (0..<50_000).map { index in
            RichTextRun(text: "x", colorHex: String(0x200000 + index, radix: 16, uppercase: true))
        }
        let clock = ContinuousClock()
        var bytes: [UInt8] = []
        let elapsed = clock.measure { bytes = RTFWriter.write(runs) }
        #expect(elapsed < .seconds(5), "\(elapsed) to write 50,000 runs of distinct colours")
        let reading = try #require(RTFReader.read(bytes))
        #expect(reading.runs.count == runs.count && reading.runs.first == runs.first && reading.runs.last == runs.last)
    }

    /// The field holds the link as the app reads it back, so that reading the field gives it.
    @Test func aLinkIsWrittenAsTheAppReadsIt() throws {
        let bytes = RTFWriter.write([RichTextRun(text: "x", linkURL: "https://example.com/a|b#c#d")])
        let rtf = String(decoding: bytes, as: UTF8.self)
        #expect(rtf.contains(#"{\field{\*\fldinst{HYPERLINK "https://example.com/a%7Cb#c%23d"}}{\fldrslt x}}"#))
        #expect(RTFReader.read(bytes)?.runs == [RichTextRun(text: "x", linkURL: "https://example.com/a%7Cb#c%23d")])
    }

    /// One `\uc0` at the start, which AppKit holds in every group within, a link's field result too.
    @Test func noFallbackCharacterIsWrittenAnywhere() {
        let rtf = String(decoding: RTFWriter.write([RichTextRun(text: "caf\u{E9}", linkURL: "https://example.com/"), RichTextRun(text: " \u{4E2D}")]),
                         as: UTF8.self)
        #expect(rtf.components(separatedBy: #"\uc0 "#).count == 2)
        #expect(rtf.hasSuffix("{\\fldrslt caf\\u233 }} \\u\(20013) }"))
    }
}
