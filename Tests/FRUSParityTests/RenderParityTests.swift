// Check 4 on Linux: FRUSCoreKit renders every golden row as the Mac reader does, byte for byte.
//
// The rendering is FRUSParity's, which imports the kit without @testable, so these tests reach only
// its public API, as the server will.

import FRUSParity
import Foundation
import FRUSLightTestSupport
import ParityFormat
import Testing

@Suite struct RenderParityTests {
    /// The committed golden manifest and the folder it lists its HTML in. It comes from the app's
    /// source alone, so it is never pending, and it must be current: made at another pin, it
    /// records other code's HTML, and the comparison would test nothing.
    static func currentGolden() throws -> (golden: RenderGolden, directory: URL) {
        let (golden, stale) = try RenderParity.golden(Repository.layout)
        #expect(stale.isEmpty, "\(stale.joined(separator: "\n"))")
        let directory = Repository.layout.golden.appendingPathComponent(GoldenFile.render.rawValue).deletingLastPathComponent()
        return (golden, directory)
    }

    /// Check 4 along the reader's own path: each row of the golden manifest, parsed alone by a new
    /// parser and rendered with the reader's lookups, converter and serializer, is the golden
    /// file's bytes.
    @Test func everyGoldenRowRendersAsTheReaderDoes() async throws {
        let (golden, directory) = try Self.currentGolden()
        #expect(golden.rows.count >= ParityFixtures.volumes.count)
        let rendered = try await ReaderRenderer(layout: Repository.layout)
            .readerPass(golden.rows.map { ($0.volume, $0.document) })
        #expect(rendered.map(\.document) == golden.rows.map(\.document))
        let mismatches = RenderParity.mismatches(rendered, golden: golden, directory: directory)
        #expect(mismatches.isEmpty, "\(mismatches.count) of \(golden.rows.count) rows differ:\n\(mismatches.map(\.description).joined(separator: "\n"))")
        print("check 4, the reader's path: \(golden.rows.count - mismatches.count) of \(golden.rows.count) rows identical")
    }

    /// The rows are exactly the documents one full parse of each volume yields, in its order,
    /// volumes sorted. Rendering each from that parse, with its own persons and terms, is the path
    /// the server will serve, without a parse per document, and it gives the same bytes.
    @Test func aFullParseYieldsTheRowsAndRendersThemTheSame() async throws {
        let (golden, directory) = try Self.currentGolden()
        let rendered = try await ReaderRenderer(layout: Repository.layout).fullParsePass(ParityFixtures.volumes.sorted())
        let goldenRows = golden.rows.map { "\($0.volume)/\($0.document)" }
        #expect(rendered.map { "\($0.volume)/\($0.document)" } == goldenRows)
        let mismatches = RenderParity.mismatches(rendered, golden: golden, directory: directory)
        #expect(mismatches.isEmpty, "\(mismatches.count) of \(rendered.count) rows differ:\n\(mismatches.map(\.description).joined(separator: "\n"))")
        print("check 4, one full parse per volume: \(rendered.count - mismatches.count) of \(goldenRows.count) rows identical")
    }

    /// The comparison, on golden files written here: identical HTML passes, and each difference
    /// names the row, both sizes and digests, and the first differing piece.
    @Test func renderComparisonNamesEachDifference() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let folder = directory.url
            let pages = [
                ("v1", "d1", "<div class=\"doc\"><p>Caf\u{E9} treaty</p><p>Signed.</p></div>"),
                ("v1", "d2", "<div class=\"doc\"><p>Canal</p></div>"),
                ("v2", "d1", "<div class=\"doc\"><p>Mosquito</p></div>"),
            ]
            var rows: [RenderRow] = []
            for (volume, document, html) in pages {
                let url = folder.appendingPathComponent(RenderGolden.htmlPath(volume: volume, document: document))
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(html.utf8).write(to: url)
                rows.append(RenderRow(volume: volume, document: document, html: html))
            }
            let provenance = Provenance(tool: "tests", upstreamCommit: nil, appBuild: nil, indexVersion: 65,
                                        sourceDigest: "", inputs: [:], platform: .current())
            let golden = RenderGolden(provenance: provenance, configuration: "tests", rows: rows)
            let same = pages.map { RenderedDocument(volume: $0.0, document: $0.1, html: $0.2) }
            #expect(RenderParity.mismatches(same, golden: golden, directory: folder).isEmpty)

            var changed = same
            // Canonically equivalent text, which Swift's == takes as equal, is a difference.
            changed[0].html = "<div class=\"doc\"><p>Cafe\u{301} treaty</p><p>Signed.</p></div>"
            #expect(changed[0].html == same[0].html)
            changed[1].html = nil
            changed[2].document = "d9"
            let mismatches = RenderParity.mismatches(changed, golden: golden, directory: folder)
            let nfd = Data(changed[0].html!.utf8)
            #expect(mismatches == [
                RenderMismatch(volume: "v1", document: "d1", detail: """
                    rendered \(nfd.count) bytes with SHA-256 \(Digest.sha256(nfd).prefix(12)); the manifest says \(rows[0].bytes) bytes, \
                    \(rows[0].sha256.prefix(12)), and the golden file differs at piece 2 of 6 golden, 6 candidate
                      golden:    <div class="doc"><p>Caf\u{E9} treaty</p><p>Signed.
                      candidate: <div class="doc"><p>Cafe\u{301} treaty</p><p>Signed.
                    """),
                RenderMismatch(volume: "v1", document: "d2", detail: "the kit finds no such document in the volume"),
                RenderMismatch(volume: "v2", document: "d9", detail: "rendered, but the golden manifest has no such row"),
            ])

            // A manifest that disagrees with its own file is reported as such.
            var inconsistent = golden
            inconsistent.rows[2].sha256 = String(repeating: "0", count: 64)
            #expect(RenderParity.mismatches(same, golden: inconsistent, directory: folder).map(\.detail) == [
                "rendered \(rows[2].bytes) bytes with SHA-256 \(rows[2].sha256.prefix(12)); the manifest says \(rows[2].bytes) bytes, 000000000000, but the golden file is the same: the manifest is inconsistent",
            ])
        }
    }
}
