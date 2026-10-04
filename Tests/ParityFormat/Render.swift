// Check 4: the golden HTML of each fixture document, as the Mac reader renders it.

import Foundation

/// `fixtures/golden/render/manifest.json`. Each row's HTML is at `html/<volume>/<document>.html`
/// beside it: the fragment `FRUSRenderNodeHTMLSerializer` writes, without the page around it.
public struct RenderGolden: Codable, Equatable, Sendable {
    public var format: Int
    public var provenance: Provenance
    /// How the HTML was made, in words: the code path and the serializer's settings.
    public var configuration: String
    /// Every row a full parse of each fixture volume yields, in parse order, volumes sorted.
    public var rows: [RenderRow]

    public static let currentFormat = 1

    public init(provenance: Provenance, configuration: String, rows: [RenderRow]) {
        self.format = Self.currentFormat
        self.provenance = provenance
        self.configuration = configuration
        self.rows = rows
    }

    /// Where a row's HTML lives, relative to the manifest's folder.
    public static func htmlPath(volume: String, document: String) -> String {
        "html/\(volume)/\(document).html"
    }
}

public struct RenderRow: Codable, Equatable, Sendable {
    public var volume: String
    public var document: String
    public var sha256: String
    public var bytes: Int

    public init(volume: String, document: String, sha256: String, bytes: Int) {
        self.volume = volume
        self.document = document
        self.sha256 = sha256
        self.bytes = bytes
    }

    public init(volume: String, document: String, html: String) {
        let data = Data(html.utf8)
        self.init(volume: volume, document: document, sha256: Digest.sha256(data), bytes: data.count)
    }
}

public enum RenderDiff {
    /// Where two HTML fragments first differ, for a failure message. The serializer writes one
    /// line, so this splits at tag boundaries and reports the first differing piece with a
    /// little context. Fragments and pieces are compared by their UTF-8 bytes, never by Swift's
    /// `==`, which takes canonically equivalent text, such as `é` and `e` with a combining accent,
    /// as equal.
    public static func firstDifference(golden: String, candidate: String, context: Int = 2) -> String? {
        if golden.utf8.elementsEqual(candidate.utf8) { return nil }
        let a = pieces(golden)
        let b = pieces(candidate)
        let index = (0..<min(a.count, b.count)).first { !a[$0].utf8.elementsEqual(b[$0].utf8) } ?? min(a.count, b.count)
        let from = max(0, index - context)
        func excerpt(_ p: [String]) -> String {
            p.indices.contains(index) ? p[from...min(p.count - 1, index + context)].joined(separator: "") : "(ends)"
        }
        return "piece \(index + 1) of \(a.count) golden, \(b.count) candidate\n  golden:    \(excerpt(a))\n  candidate: \(excerpt(b))"
    }

    /// The fragment split before each `<`, scalar by scalar, so the pieces hold its exact bytes.
    static func pieces(_ html: String) -> [String] {
        var result: [String] = []
        var current = String.UnicodeScalarView()
        for scalar in html.unicodeScalars {
            if scalar == "<", !current.isEmpty {
                result.append(String(current))
                current = String.UnicodeScalarView()
            }
            current.append(scalar)
        }
        if !current.isEmpty { result.append(String(current)) }
        return result
    }
}
