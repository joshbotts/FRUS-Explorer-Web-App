// Check 6 on the fixtures (PLAN's S15c): highlights placed by offset over each golden row's flat
// text, the kit's `buildFlatText` along the server's path, for the browser suite to read back from
// the reader's page in Chromium. There the kit's offset engine builds the flat text from the page's
// DOM, and the suite compares, for each row, its length and digest with these, and for each sample
// the text the page holds between its offsets with the sample's text, then draws the samples with
// the kit's renderer (web/e2e/highlights-check6.spec.ts). The file is fixtures/highlights/samples.json,
// written by `frus-parity highlight-samples` and held to the kit by FRUSParityTests.
//
// Check 6 is two steps, since a highlight's selected text is the kit's excerpt of the text between
// its offsets, not always that text: across paragraphs, `flatTextExcerpt` joins each one's part with
// a blank line, as the app stores it. In Chromium, the page's text between the offsets is the flat
// text's (`text`); in Swift, the selected text is the kit's excerpt of it (`selectedText`, written
// where it differs), which is what the API stores for a highlight there.

import Crypto
import FRUSCoreKit
import Foundation
import ParityFormat

/// Highlights placed by offset over the golden rows' flat text.
public struct HighlightSampleFile: Codable, Equatable, Sendable {
    public var formatVersion: Int
    /// The golden render manifest's rows, in its order.
    public var rows: [Row]

    public struct Row: Codable, Equatable, Sendable {
        public var volume: String
        public var document: String
        /// The flat text's length in UTF-16 units, which the kit's offsets count.
        public var length: Int
        /// The SHA-256 of the flat text's UTF-8 bytes, in lowercase hex.
        public var sha256: String
        /// The kit's rendering version of the text, which the reader's page sends.
        public var renderingVersion: String
        public var samples: [Sample]
    }

    /// A highlight as the kit's renderer reads one (`ReaderHighlight`), with the flat text between
    /// its offsets, none for the whole row, whose length and digest stand for it; and, where it is
    /// not that text, the selected text a highlight there has, the kit's `flatTextExcerpt`.
    public struct Sample: Codable, Equatable, Sendable {
        public var startOffset: Int
        public var endOffset: Int
        public var color: String
        public var isStale: Bool
        public var text: String?
        public var selectedText: String?
    }
}

public enum HighlightSamples {
    public static let path = "fixtures/highlights/samples.json"
    public static let formatVersion = 1
    /// The longest sample's text, but the whole row's, in UTF-16 units, so the file stays small.
    public static let longestText = 160

    /// The samples for every row of the golden render manifest, in its order, each document's model
    /// from one full parse of its volume, as the server reads it.
    public static func make(layout: RepositoryLayout, rows: [(volume: String, document: String)]) async throws -> HighlightSampleFile {
        let volumes = Array(Set(rows.map(\.volume))).sorted()
        let models = try await ReaderRenderer(layout: layout).fullParseModels(volumes) { model in
            (flat: buildFlatText(from: model), blocks: buildFlatTextBlocks(from: model),
             version: ASTToRenderNodeConverter.renderingVersion(for: model))
        }
        // The server keeps the first of a volume's documents that share an id, as the golden rows do.
        var byKey: [String: ReaderRenderer.ModelRow<(flat: String, blocks: [String], version: String)>] = [:]
        for row in models where byKey["\(row.volume)/\(row.document)"] == nil { byKey["\(row.volume)/\(row.document)"] = row }
        return HighlightSampleFile(formatVersion: formatVersion, rows: try rows.map { wanted in
            guard let row = byKey["\(wanted.volume)/\(wanted.document)"] else {
                throw GoldenError.malformed(path, "\(wanted.volume) has no document \(wanted.document) in a full parse")
            }
            return sampled(volume: row.volume, document: row.document, flat: row.value.flat, blocks: row.value.blocks,
                           renderingVersion: row.value.version)
        })
    }

    /// One row's samples, placed over `flat` in UTF-16 units: the whole row; its first and last
    /// words; a span across up to two of its blocks' boundaries (`buildFlatTextBlocks`), where a
    /// paragraph's last letter meets the next one's first with nothing between; a span holding its
    /// first line break, a `<br>` in the page; and a few words at its middle. None ends on a line
    /// break: the kit's renderer ends such a range after the `<br>` since FRUS-Explorer#1789, but the
    /// kit's selection bridge, which reads each range back in Chromium, maps the `<br>` itself and not
    /// the end after it. None splits a surrogate pair. Colours follow `HighlightColor`'s order, and the
    /// last sample is stale.
    public static func sampled(volume: String, document: String, flat: String, blocks: [String],
                               renderingVersion: String) -> HighlightSampleFile.Row {
        let units = Array(flat.utf16)
        let count = units.count
        let newline: UInt16 = 0x0A
        func isSpace(_ unit: UInt16) -> Bool { unit == 0x20 || unit == newline || unit == 0x09 || unit == 0xA0 }
        var spans: [(start: Int, end: Int)] = []
        func add(_ from: Int, _ to: Int, whole: Bool = false) {
            let start = max(0, from)
            var end = min(count, whole ? to : min(to, start + longestText))
            while end > start, units[end - 1] == newline { end -= 1 }
            guard end > start, !UTF16.isTrailSurrogate(units[start]), !UTF16.isLeadSurrogate(units[end - 1]),
                  !spans.contains(where: { $0 == (start, end) }) else { return }
            spans.append((start, end))
        }
        add(0, count, whole: true)
        if let first = units.firstIndex(where: { !isSpace($0) }) {
            add(first, units[first...].firstIndex(where: isSpace) ?? count)
        }
        if let last = units.lastIndex(where: { !isSpace($0) }) {
            add(units[..<last].lastIndex(where: isSpace).map { $0 + 1 } ?? 0, last + 1)
        }
        var edges: [Int] = []
        var edge = 0
        for block in blocks.dropLast() {
            edge += block.utf16.count
            if edge > 0, edge < count { edges.append(edge) }
        }
        for boundary in Set([edges.first, edges.isEmpty ? nil : edges[edges.count / 2]].compactMap { $0 }).sorted() {
            add(boundary - 12, boundary + 12)
        }
        if let lineBreak = units.firstIndex(of: newline) { add(lineBreak - 10, lineBreak + 11) }
        let middle = units[..<(count / 2)].lastIndex(where: isSpace).map { $0 + 1 } ?? 0
        var end = middle
        var words = 0
        while end < count, words < 6 {
            if isSpace(units[end]) { words += 1 }
            end += 1
        }
        add(middle, end)

        let colors = HighlightColor.allCases.map(\.rawValue)
        let samples = spans.enumerated().map { index, span in
            let text = String(decoding: units[span.start..<span.end], as: UTF16.self)
            let selected = flatTextExcerpt(blocks: blocks, start: span.start, end: span.end) ?? ""
            return HighlightSampleFile.Sample(startOffset: span.start, endOffset: span.end, color: colors[index % colors.count],
                                              isStale: spans.count > 1 && index == spans.count - 1,
                                              text: index == 0 ? nil : text,
                                              selectedText: index == 0 || selected == text ? nil : selected)
        }
        let digest = SHA256.hash(data: Data(flat.utf8)).map { String(format: "%02x", $0) }.joined()
        return HighlightSampleFile.Row(volume: volume, document: document, length: count, sha256: digest,
                                       renderingVersion: renderingVersion, samples: samples)
    }
}
