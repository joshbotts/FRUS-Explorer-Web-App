// Check 6 on a Mac JSON export's highlights (PLAN's S16c), its Swift half: each highlight's document
// rendered from a TEI folder along the server's path, and where the TEI matches, the page's rendering
// version the one the highlight stores, its selected text one of the two forms SPEC's check 6 names,
// the kit's excerpt of the flat text between its offsets (`flatTextExcerpt`), or for one the Mac made
// before 3 July that text itself. A highlight whose TEI differs goes to review and nothing moves. The
// matched highlights are written as check 6's samples, the format of fixtures/highlights/samples.json,
// for the browser suite to read back from the reader's page in Chromium (FRUS_CHECK6_SAMPLES).
//
// The two forms are the kit's own test, `HighlightReanchor.extracts(passage:start:end:in:)`, public
// since FRUS-Explorer#1789, which the check calls over the page's blocks.

import Crypto
import FRUSCoreKit
import Foundation

public enum ExportHighlights {
    /// What the check found, by highlight id, never by what a highlight says.
    public struct Result: Sendable {
        public var highlights = 0
        /// Highlights whose TEI matches: their document is in the folder, in the version they store.
        public var matched = 0
        /// Of those, the ones whose selected text is one of the two forms.
        public var passed = 0
        /// Of those, the ones stored in the raw form, made before 3 July.
        public var rawForm = 0
        /// Highlights for review: their TEI is not in the folder, or not the version they store.
        public var toReview: [(id: String, reason: String)] = []
        /// Highlights whose TEI matches and whose selected text is neither form.
        public var failures: [(id: String, reason: String)] = []
        /// Passed highlights that end on a line break: left out of the samples, as the fixtures' are
        /// (`HighlightSamples.sampled`). The kit's renderer draws one since FRUS-Explorer#1789, ending
        /// its range after the `<br>`, but check 6 in Chromium also reads each range back through the
        /// kit's selection bridge, whose map names the `<br>` and not the end after it.
        public var endingOnALineBreak: [String] = []
        /// The matched highlights, as check 6's samples.
        public var samples = HighlightSampleFile(formatVersion: HighlightSamples.formatVersion, rows: [])
    }

    /// Check 6 over `highlights`, their documents read from `tei`, one full parse of each volume.
    public static func check(_ highlights: [DocumentHighlightExport], layout: RepositoryLayout, tei: URL) async throws -> Result {
        var result = Result()
        result.highlights = highlights.count
        let volumes = Set(highlights.map(\.volumeId)).sorted()
        let present = volumes.filter { FileManager.default.fileExists(atPath: tei.appendingPathComponent("\($0).xml").path) }
        let models = try await ReaderRenderer(layout: layout, tei: tei).fullParseModels(present) { model in
            (flat: buildFlatText(from: model), blocks: buildFlatTextBlocks(from: model),
             version: ASTToRenderNodeConverter.renderingVersion(for: model))
        }
        // The server keeps the first of a volume's documents that share an id.
        var byKey: [String: (flat: String, blocks: [String], version: String)] = [:]
        for row in models where byKey["\(row.volume)/\(row.document)"] == nil { byKey["\(row.volume)/\(row.document)"] = row.value }
        var rows: [String: HighlightSampleFile.Row] = [:]
        for highlight in highlights {
            let id = highlight.id.uuidString
            let key = "\(highlight.volumeId)/\(highlight.documentId)"
            guard present.contains(highlight.volumeId) else {
                result.toReview.append((id, "\(highlight.volumeId) is not in the TEI folder"))
                continue
            }
            guard let model = byKey[key] else {
                result.toReview.append((id, "\(highlight.volumeId) has no \(highlight.documentId)"))
                continue
            }
            guard model.version == highlight.renderingVersion else {
                result.toReview.append((id, "the text changed since it was made"))
                continue
            }
            result.matched += 1
            let units = Array(model.flat.utf16)
            guard highlight.startOffset >= 0, highlight.endOffset > highlight.startOffset, highlight.endOffset <= units.count else {
                result.failures.append((id, "offsets outside the text"))
                continue
            }
            let raw = String(decoding: units[highlight.startOffset..<highlight.endOffset], as: UTF16.self)
            let excerpt = flatTextExcerpt(blocks: model.blocks, start: highlight.startOffset, end: highlight.endOffset)
            guard HighlightReanchor.extracts(passage: highlight.selectedText, start: highlight.startOffset,
                                             end: highlight.endOffset, in: model.blocks) else {
                result.failures.append((id, "its selected text is neither the excerpt nor the text between its offsets"))
                continue
            }
            result.passed += 1
            if highlight.selectedText != excerpt { result.rawForm += 1 }
            if units[highlight.endOffset - 1] == 0x0A {
                result.endingOnALineBreak.append(id)
                continue
            }
            let digest = SHA256.hash(data: Data(model.flat.utf8)).map { String(format: "%02x", $0) }.joined()
            var row = rows[key] ?? HighlightSampleFile.Row(volume: highlight.volumeId, document: highlight.documentId,
                                                           length: units.count, sha256: digest,
                                                           renderingVersion: model.version, samples: [])
            row.samples.append(HighlightSampleFile.Sample(startOffset: highlight.startOffset, endOffset: highlight.endOffset,
                                                          color: highlight.colorTag, isStale: false, text: raw,
                                                          selectedText: highlight.selectedText == raw ? nil : highlight.selectedText))
            rows[key] = row
        }
        result.samples.rows = rows.values.sorted { ($0.volume, $0.document) < ($1.volume, $1.document) }
        return result
    }
}
