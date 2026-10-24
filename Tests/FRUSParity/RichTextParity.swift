// The golden spans' web cases (S15d): the RTF the web's codec writes for each case of
// fixtures/rich-text/web/cases.json, which tools/mac-golden then reads with the app's own code.

import FRUSRichText
import Foundation
import ParityFormat

public enum RichTextParity {
    /// Each web case's file, as the codec writes it.
    public static func webFixtures(_ cases: RichTextWebCases) -> [(path: String, bytes: [UInt8])] {
        cases.cases.map { (RichTextWebCases.rtfPath($0.id), RTFWriter.write($0.runs.map(RichTextRun.init))) }
    }

    /// Writes every web case's file under `root` and returns how many, after checking each case is
    /// runs the store would take as a note's formatting.
    public static func writeWebFixtures(root: URL) throws -> Int {
        let cases = try GoldenJSON.read(RichTextWebCases.self, from: root.appendingPathComponent(RichTextWebCases.path))
        var ids = Set<String>()
        for item in cases.cases {
            guard ids.insert(item.id).inserted, item.id.wholeMatch(of: /[a-z0-9-]+/) != nil else {
                throw GoldenError.malformed(RichTextWebCases.path, "\(item.id) is used twice or is not a file name")
            }
            let runs = item.runs.map(RichTextRun.init)
            if let problem = RichTextRuns.problem(runs, bodyText: RichTextRuns.text(runs)) {
                throw GoldenError.malformed(RichTextWebCases.path, "\(item.id): \(problem)")
            }
        }
        for fixture in webFixtures(cases) {
            try Data(fixture.bytes).write(to: root.appendingPathComponent(fixture.path), options: .atomic)
        }
        return cases.cases.count
    }
}

extension RichTextRun {
    public init(_ span: RichTextSpan) {
        self.init(text: span.text, bold: span.bold, italic: span.italic, underline: span.underline,
                  colorHex: span.colorHex, linkURL: span.linkURL)
    }
}

extension RichTextSpan {
    public init(_ run: RichTextRun) {
        self.init(text: run.text, bold: run.bold, italic: run.italic, underline: run.underline,
                  colorHex: run.colorHex, linkURL: run.linkURL)
    }
}
