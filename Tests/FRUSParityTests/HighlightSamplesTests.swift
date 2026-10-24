// Check 6's Swift half on the fixtures (PLAN's S15c): fixtures/highlights/samples.json is the kit's
// flat text of every golden row, along the server's path, with highlights placed by offset over it.
// The browser suite reads the same rows back from the reader's page in Chromium
// (web/e2e/highlights-check6.spec.ts), so the file must be what the pinned kit gives: a pin move that
// changes a row's flat text fails here until `frus-parity highlight-samples` writes it again.

import FRUSCoreKit
import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct HighlightSamplesTests {
    static var committed: URL { Repository.root.appendingPathComponent(HighlightSamples.path) }

    @Test func theCommittedSamplesAreTheKitsAtThePin() async throws {
        let (golden, _) = try RenderParityTests.currentGolden()
        let file = try await HighlightSamples.make(layout: Repository.layout, rows: golden.rows.map { ($0.volume, $0.document) })
        #expect(file.rows.map { "\($0.volume)/\($0.document)" } == golden.rows.map { "\($0.volume)/\($0.document)" },
                "every golden row, in the manifest's order")
        let made = try GoldenJSON.encode(file)
        let committed = try Data(contentsOf: Self.committed)
        #expect(made == committed, "\(HighlightSamples.path) is not the kit's at the pin: run scripts/swift run frus-parity highlight-samples --out \(HighlightSamples.path)")
        print("check 6's samples: \(file.rows.count) rows, \(file.rows.map(\.samples.count).reduce(0, +)) highlights placed over the kit's flat text")
    }

    /// What the browser suite relies on: each sample's text is the flat text between its offsets,
    /// none ends on a line break, and each draws under one of the kit's five names. Its selected
    /// text is the kit's excerpt, `flatTextExcerpt`: the text itself within one block, and across
    /// blocks each one's part joined by a blank line, written beside it.
    @Test func eachSampleIsTheFlatTextBetweenItsOffsets() async throws {
        let file = try GoldenJSON.read(HighlightSampleFile.self, from: Self.committed)
        #expect(file.formatVersion == HighlightSamples.formatVersion)
        let models = try await ReaderRenderer(layout: Repository.layout).fullParseModels(Array(Set(file.rows.map(\.volume))).sorted()) { model in
            (flat: buildFlatText(from: model), blocks: buildFlatTextBlocks(from: model))
        }
        var byKey: [String: (flat: String, blocks: [String])] = [:]
        for row in models where byKey["\(row.volume)/\(row.document)"] == nil { byKey["\(row.volume)/\(row.document)"] = row.value }
        var withinOneBlock = 0
        var acrossBlocks = 0
        var mismatches: [String] = []
        let names = Set(HighlightColor.allCases.map(\.rawValue))
        for row in file.rows {
            let key = "\(row.volume)/\(row.document)"
            guard let model = byKey[key] else {
                mismatches.append("\(key): no such document in a full parse")
                continue
            }
            let units = Array(model.flat.utf16)
            // A row whose text has changed is reported, and its samples are not read.
            guard units.count == row.length else {
                mismatches.append("\(key): \(units.count) UTF-16 units, where the file says \(row.length)")
                continue
            }
            if row.samples.first.map({ $0.startOffset == 0 && $0.endOffset == row.length && $0.text == nil }) != true {
                mismatches.append("\(key): the whole row is not the first sample")
            }
            if row.samples.contains(where: \.isStale) != (row.samples.count > 1) { mismatches.append("\(key): no stale sample") }
            var edges: [Int] = [0]
            for block in model.blocks { edges.append(edges.last! + block.utf16.count) }
            for sample in row.samples {
                let span = "\(key) \(sample.startOffset)–\(sample.endOffset)"
                guard 0 <= sample.startOffset, sample.startOffset < sample.endOffset, sample.endOffset <= units.count else {
                    mismatches.append("\(span): outside the text")
                    continue
                }
                if units[sample.endOffset - 1] == 0x0A { mismatches.append("\(span): ends on a line break") }
                if !names.contains(sample.color) { mismatches.append("\(span): \(sample.color) is not a colour") }
                guard let text = sample.text else { continue }
                if text != String(decoding: units[sample.startOffset..<sample.endOffset], as: UTF16.self) {
                    mismatches.append("\(span): its text is not the flat text there")
                }
                if text.utf16.count > HighlightSamples.longestText { mismatches.append("\(span): longer than the file allows") }
                let excerpt = flatTextExcerpt(blocks: model.blocks, start: sample.startOffset, end: sample.endOffset) ?? ""
                if (sample.selectedText ?? text) != excerpt || sample.selectedText == text {
                    mismatches.append("\(span): its selected text is not the kit's excerpt")
                }
                let block = edges.lastIndex { $0 <= sample.startOffset } ?? 0
                if block + 1 < edges.count, sample.endOffset <= edges[block + 1], text.contains(where: { !$0.isWhitespace }) {
                    withinOneBlock += 1
                    if sample.selectedText != nil { mismatches.append("\(span): within one block its selected text is its text") }
                } else if sample.selectedText != nil {
                    acrossBlocks += 1
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) problems, the first 50:\n\(mismatches.prefix(50).joined(separator: "\n"))")
        #expect(withinOneBlock > 1_000 && acrossBlocks > 300, "\(withinOneBlock) within one block, \(acrossBlocks) across")
        #expect(file.rows.contains { $0.samples.contains { $0.text?.contains("\n") == true } }, "a span across a <br>")
    }
}
