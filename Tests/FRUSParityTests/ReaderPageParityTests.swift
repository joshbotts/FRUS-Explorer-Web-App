// Check 4 with what upstream #1575 gives a host: its own figure addresses, and the reader's page as
// kit code. Every golden row, along the server's full-parse path.

import FRUSCoreKit
import FRUSLightTestSupport
import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct ReaderPageParityTests {
    static let volumes = ParityFixtures.volumes.sorted()

    /// `reader(figureURL:)` given the app's own addresses writes `.reader`'s bytes: all 392 rows are
    /// the golden files'.
    @Test func theAppsFigureAddressesRenderEveryRowAsBefore() async throws {
        let (golden, directory) = try RenderParityTests.currentGolden()
        // The serializer is not Sendable, so each document's write makes its own.
        let (rendered, _) = try await ReaderRenderer(layout: Repository.layout).fullParsePass(Self.volumes, write: {
            FRUSRenderNodeHTMLSerializer.reader(figureURL: FRUSURLScheme.figureURL(for:)).serialize($0)
        })
        #expect(rendered.map { "\($0.volume)/\($0.document)" } == golden.rows.map { "\($0.volume)/\($0.document)" })
        let mismatches = RenderParity.mismatches(rendered, golden: golden, directory: directory)
        #expect(mismatches.isEmpty, "\(mismatches.count) rows differ:\n\(mismatches.map(\.description).joined(separator: "\n"))")
    }

    /// A host's figure addresses change the image sources and nothing else: exactly the 8 in
    /// frus1969-76ve09p1's d87 and d116. Mapped back to the app's addresses, every row is the
    /// golden file's.
    @Test func aHostsFigureAddressesChangeOnlyTheImages() async throws {
        let (golden, directory) = try RenderParityTests.currentGolden()
        let base = "http://localhost:8080/api/v1/volumes/"
        let (rendered, _) = try await ReaderRenderer(layout: Repository.layout).fullParsePass(Self.volumes, write: {
            FRUSRenderNodeHTMLSerializer.reader(figureURL: { image in
                guard let volume = image.volumeId, let file = image.fileName else { return nil }
                return URL(string: "\(base)\(volume)/figures/\(file)")
            }).serialize($0)
        })
        var replaced: [String: Int] = [:]
        let mapped = rendered.map { document -> RenderedDocument in
            guard let html = document.html else { return document }
            let count = html.components(separatedBy: base).count - 1
            if count > 0 { replaced["\(document.volume)/\(document.document)"] = count }
            let back = html.replacing(/http:\/\/localhost:8080\/api\/v1\/volumes\/([^\/"]+)\/figures\//) { "frusexplorer://figure/\($0.1)/" }
            return RenderedDocument(volume: document.volume, document: document.document, html: back)
        }
        #expect(replaced == ["frus1969-76ve09p1/d87": 7, "frus1969-76ve09p1/d116": 1])
        #expect(rendered.allSatisfy { !($0.html ?? "").contains("frusexplorer://figure/") })
        let mismatches = RenderParity.mismatches(mapped, golden: golden, directory: directory)
        #expect(mismatches.isEmpty, "\(mismatches.count) rows differ:\n\(mismatches.map(\.description).joined(separator: "\n"))")
        print("a host's figure addresses: \(replaced.values.reduce(0, +)) images in \(replaced.count) rows; mapped back, \(golden.rows.count - mismatches.count) of \(golden.rows.count) rows identical")
    }

    /// The reader's page, `ReaderPage.build` with its defaults, holds each row's golden fragment
    /// between its one `<body>\n` and its one `\n</body>\n</html>`, after a head that is the same
    /// for every document. Dark and extra large change the head only.
    @Test func thePageHoldsEveryRowsFragment() async throws {
        let (golden, directory) = try RenderParityTests.currentGolden()
        let renderer = try ReaderRenderer(layout: Repository.layout)
        let (pages, _) = try await renderer.fullParsePass(Self.volumes, write: { ReaderPage.build(model: $0) })
        let (darkPages, _) = try await renderer.fullParsePass(
            Self.volumes, write: { ReaderPage.build(model: $0, appearance: .dark, textSize: .extraLarge) })

        func split(_ page: String) -> (head: String, body: String)? {
            let open = page.components(separatedBy: "<body>\n")
            guard open.count == 2, open[1].hasSuffix("\n</body>\n</html>"),
                  open[1].components(separatedBy: "\n</body>").count == 2 else { return nil }
            return (open[0], String(open[1].dropLast("\n</body>\n</html>".count)))
        }
        var heads = Set<String>()
        var darkHeads = Set<String>()
        var bodies: [RenderedDocument] = []
        for (page, dark) in zip(pages, darkPages) {
            guard let parts = split(page.html ?? ""), let darkParts = split(dark.html ?? "") else {
                Issue.record("\(page.volume)/\(page.document): the page has not exactly one body")
                continue
            }
            heads.insert(parts.head)
            darkHeads.insert(darkParts.head)
            #expect(darkParts.body == parts.body, "\(page.volume)/\(page.document): dark and extra large change the body")
            bodies.append(RenderedDocument(volume: page.volume, document: page.document, html: parts.body))
        }
        #expect(bodies.count == golden.rows.count)
        #expect(heads.count == 1 && darkHeads.count == 1 && heads != darkHeads)
        #expect(heads.first?.hasPrefix("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n") == true)
        let mismatches = RenderParity.mismatches(bodies, golden: golden, directory: directory)
        #expect(mismatches.isEmpty, "\(mismatches.count) rows differ:\n\(mismatches.map(\.description).joined(separator: "\n"))")
        print("the reader's page: \(bodies.count - mismatches.count) of \(golden.rows.count) rows' bodies identical, one head for every document")
    }
}
