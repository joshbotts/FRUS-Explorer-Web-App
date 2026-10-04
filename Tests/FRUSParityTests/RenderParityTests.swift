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
    /// file's bytes. The bytes cannot show which persons and terms a row was rendered with: the
    /// fixtures' HTML does not depend on them, as `RenderParity.swift` says. The next two tests
    /// check those.
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
    /// the server will serve, without a parse per document, and it gives the same bytes. Since the
    /// bytes would be the same with any lists, the parse's persons and terms are compared with
    /// those the reader parses, field for field.
    @Test func aFullParseYieldsTheRowsAndRendersThemTheSame() async throws {
        let (golden, directory) = try Self.currentGolden()
        let renderer = try ReaderRenderer(layout: Repository.layout)
        let volumes = ParityFixtures.volumes.sorted()
        let (rendered, lists) = try await renderer.fullParsePass(volumes)
        let goldenRows = golden.rows.map { "\($0.volume)/\($0.document)" }
        #expect(rendered.map { "\($0.volume)/\($0.document)" } == goldenRows)
        let mismatches = RenderParity.mismatches(rendered, golden: golden, directory: directory)
        #expect(mismatches.isEmpty, "\(mismatches.count) of \(rendered.count) rows differ:\n\(mismatches.map(\.description).joined(separator: "\n"))")

        let readerLists = try await renderer.readerLists(volumes)
        #expect(lists.keys.sorted() == volumes)
        #expect(readerLists.keys.sorted() == volumes)
        for volume in volumes {
            #expect(lists[volume]?.persons == readerLists[volume]?.persons, "\(volume)'s persons")
            #expect(lists[volume]?.terms == readerLists[volume]?.terms, "\(volume)'s terms")
        }
        // Not only empty lists: the two modern volumes list both persons and terms.
        #expect(lists.values.filter { !$0.persons.isEmpty && !$0.terms.isEmpty }.count >= 2)
        print("check 4, one full parse per volume: \(rendered.count - mismatches.count) of \(goldenRows.count) rows identical, "
              + "and its persons and terms are the reader's: "
              + volumes.map { "\(lists[$0]?.persons.count ?? 0) and \(lists[$0]?.terms.count ?? 0)" }.joined(separator: ", "))
    }

    /// The one link a lookup decides: an `<abbr>` whose text names a glossary term, in any case,
    /// renders as that term's link along both paths, and one that names no term stays text. None
    /// of the fixture volumes has an `<abbr>`, so a volume written here holds two.
    @Test func anAbbreviationNamingATermRendersAsItsLink() async throws {
        let directory = try TemporaryDirectory()
        defer { withExtendedLifetime(directory) {} }
        let volume = "frus-synthetic-abbr"
        try Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="\(volume)">
              <teiHeader><fileDesc><titleStmt><title>Abbreviations</title></titleStmt>
                <publicationStmt><p/></publicationStmt><sourceDesc><p/></sourceDesc></fileDesc></teiHeader>
              <text>
                <front>
                  <div type="section" xml:id="terms">
                    <head>List of Abbreviations</head>
                    <list type="terms">
                      <item><hi rend="strong"><term xml:id="t_NATO1">NATO</term>,</hi> North Atlantic Treaty Organization</item>
                    </list>
                  </div>
                </front>
                <body>
                  <div type="document" xml:id="d1" n="1">
                    <head>1. Memorandum</head>
                    <p>The <abbr>nato</abbr> ministers met; <abbr>SEATO</abbr> did not.</p>
                  </div>
                </body>
              </text>
            </TEI>
            """.utf8).write(to: directory.url.appendingPathComponent("\(volume).xml"))

        let renderer = try ReaderRenderer(layout: Repository.layout, tei: directory.url)
        let reader = try await renderer.readerPass([(volume, "d1")])
        let full = try await renderer.fullParsePass([volume])
        #expect(full.lists[volume]?.terms == [LookupLists.Term(ref: "t_NATO1", term: "NATO", definition: "North Atlantic Treaty Organization")])
        let readerLists = try await renderer.readerLists([volume])
        #expect(full.lists == readerLists)
        let link = "<a class=\"gloss\" href=\"frusexplorer://gloss/t_NATO1\">nato</a>"
        for (pass, html) in [("the reader's path", reader.first?.html), ("one full parse", full.documents.first { $0.document == "d1" }?.html)] {
            let html = try #require(html, "\(pass) renders d1")
            #expect(html.contains("The \(link) ministers met; SEATO did not."), "\(pass): \(html)")
            #expect(html.components(separatedBy: "class=\"gloss\"").count == 2, "\(pass): \(html)")
        }
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
