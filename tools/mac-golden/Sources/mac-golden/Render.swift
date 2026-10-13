// render: check 4's golden HTML, as the Mac reader renders each fixture document.

import Foundation
import ParityFormat
@testable import FRUSExplorer

let renderConfiguration = """
    The Mac reader's own path, without an index. For each row, DocumentViewModel(entry:volumeEntry:parser:) \
    with an entry naming only the volume and the document (its other fields do not reach the HTML; \
    mac-golden checks that on every 25th row), no volume entry, a new FRUSDocumentParser, no person-mention \
    store, no AST cache and no classification override. load(volumeURL:) on the main actor then parses \
    the document alone and takes persons and glossary terms from the volume's TEI. broken-refs-index.json \
    lists no reference in the fixture volumes, so no cross-reference is degraded. Then \
    HTMLTemplate.build(model:colorScheme: .light), keeping the body: the fragment \
    FRUSRenderNodeHTMLSerializer.reader writes (annotateSourceClassification: true, \
    figureImages: .reader, listsNamedReferences: true). \
    Rows are every document a full parse of each volume yields, in parse order, volumes sorted. \
    A release build of the app module, with testing enabled, compiled from the submodule unmodified.
    """

@MainActor
func renderGolden(repo: Repository, out: URL) async throws {
    // The command replaces out/html and out/manifest.json, so it never deletes what it did not
    // write: a folder holding either must hold a render manifest too.
    let manager = FileManager.default
    let html = out.appendingPathComponent("html"), manifest = out.appendingPathComponent("manifest.json")
    if itemType(html.path) != nil || itemType(manifest.path) != nil,
       (try? GoldenJSON.read(RenderManifestMarker.self, from: manifest)) == nil {
        throw ToolError("\(repo.relativePath(out)) holds html or manifest.json but no render manifest: choose a new or empty --out")
    }
    let tei = repo.url(ParityFixtures.teiPath)
    let inputs = try verifyFixtures(repo)
    try checkBrokenRefs(repo)

    var rows: [RenderRow] = []
    var pages: [(path: String, html: String)] = []
    for volume in ParityFixtures.volumes.sorted() {
        let volumeURL = tei.appendingPathComponent("\(volume).xml")
        let documents = try await FRUSDocumentParser().parseVolumeFull(volumeURL: volumeURL).documents
        var seen = Set<String>()
        for (index, document) in documents.map(\.documentId).enumerated() {
            guard document.wholeMatch(of: /[A-Za-z0-9_-][A-Za-z0-9._-]*/) != nil else {
                throw ToolError("\(volume)/\(document) is not a safe file name")
            }
            // Lowercased, since a Mac's file system ignores case by default.
            guard seen.insert(document.lowercased()).inserted else {
                throw ToolError("\(volume)/\(document) appears twice, ignoring case")
            }
            let entry = DocumentBrowserEntry(documentId: document, volumeId: volume, header: "")
            let html = try await readerHTML(entry, volumeURL: volumeURL)
            if index % 25 == 0 {
                let full = DocumentBrowserEntry(
                    documentId: document, volumeId: volume, documentNumber: "999", header: "A header",
                    dateline: "A dateline", sourceNote: "A source note", isEditorialNote: true,
                    footnoteAnchor: "\(document)fn1")
                guard try await readerHTML(full, volumeURL: volumeURL) == html else {
                    throw ToolError("\(entry.id): the entry's fields change the HTML, so the golden files must set them")
                }
            }
            rows.append(RenderRow(volume: volume, document: document, html: html))
            pages.append((RenderGolden.htmlPath(volume: volume, document: document), html))
        }
        note("render: \(volume), \(documents.count) rows")
    }

    // Everything rendered, so replace the old files: any html file not written now is stale. A
    // failed removal stops the command, since stale files would stay beside the new ones.
    if itemType(html.path) != nil { try manager.removeItem(at: html) }
    for page in pages {
        let url = out.appendingPathComponent(page.path)
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(page.html.utf8).write(to: url)
    }
    let golden = RenderGolden(
        provenance: try repo.provenance(tool: "tools/mac-golden render", inputs: inputs),
        configuration: renderConfiguration,
        rows: rows
    )
    try GoldenJSON.write(golden, to: manifest)
    let bytes = rows.reduce(0) { $0 + $1.bytes }
    note("render: \(rows.count) rows, \(bytes) bytes of HTML, in \(repo.relativePath(out))")
}

let sampleConfiguration = """
    The Mac reader's own path, as render's, over the rows a rows file names from another folder of TEI: \
    for each row, DocumentViewModel(entry:volumeEntry:parser:) with an entry naming only the volume and \
    the document (mac-golden checks on every 25th row that its other fields do not reach the HTML), no \
    volume entry, a new FRUSDocumentParser, no person-mention store, no AST cache and no classification \
    override. load(volumeURL:) on the main actor then parses the document alone and takes persons and \
    glossary terms from the volume's TEI. The reader degrades the cross-references the submodule's \
    broken-refs-index.json lists: BrokenRefsIndexStore.shared reads it from the app's bundle, and \
    mac-golden puts it in its own. Then HTMLTemplate.build(model:colorScheme: .light), keeping the body: \
    the fragment FRUSRenderNodeHTMLSerializer.reader writes (annotateSourceClassification: true, \
    figureImages: .reader, listsNamedReferences: true). Rows are in the rows file's order. A release \
    build of the app module, with testing enabled, compiled from the submodule unmodified.
    """

/// Check 4 beyond the fixtures (SPEC, Verification; S10): the reader's HTML of the rows a TSV file
/// names, one `volume<TAB>document` a line, from `tei`'s volumes, written as `render` writes the
/// fixtures' but to a folder outside `fixtures/golden`. frus-parity's `render-api` compares a
/// server's pages with them.
@MainActor
func renderSample(repo: Repository, tei: URL, rowsFile: URL, out: URL) async throws {
    let golden = repo.url("fixtures/golden").standardizedFileURL.path
    guard !out.standardizedFileURL.path.hasPrefix(golden) else {
        throw ToolError("a sample is not a golden file: choose an --out outside fixtures/golden")
    }
    let manager = FileManager.default
    let html = out.appendingPathComponent("html"), manifest = out.appendingPathComponent("manifest.json")
    if itemType(html.path) != nil || itemType(manifest.path) != nil,
       (try? GoldenJSON.read(RenderManifestMarker.self, from: manifest)) == nil {
        throw ToolError("\(out.path) holds html or manifest.json but no render manifest: choose a new or empty --out")
    }
    let text = try String(contentsOf: rowsFile, encoding: .utf8)
    var wanted: [(volume: String, document: String)] = []
    var seen = Set<String>()
    for line in text.split(separator: "\n") where !line.isEmpty {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 2 else { throw ToolError("\(rowsFile.path): \"\(line)\" is not volume<TAB>document") }
        for name in fields where name.wholeMatch(of: /[A-Za-z0-9_-][A-Za-z0-9._-]*/) == nil {
            throw ToolError("\(rowsFile.path): \(name) is not a safe file name")
        }
        // Lowercased, since a Mac's file system ignores case by default.
        guard seen.insert("\(fields[0])/\(fields[1])".lowercased()).inserted else {
            throw ToolError("\(rowsFile.path): \(fields[0])/\(fields[1]) appears twice, ignoring case")
        }
        wanted.append((fields[0], fields[1]))
    }
    guard !wanted.isEmpty else { throw ToolError("\(rowsFile.path) names no rows") }
    let degradable = try installBrokenRefsIndex(repo)

    var rows: [RenderRow] = []
    var pages: [(path: String, html: String)] = []
    for (index, row) in wanted.enumerated() {
        let volumeURL = tei.appendingPathComponent("\(row.volume).xml")
        guard itemType(volumeURL.path) == .typeRegular else { throw ToolError("\(volumeURL.path) is not a TEI volume") }
        let entry = DocumentBrowserEntry(documentId: row.document, volumeId: row.volume, header: "")
        let html = try await readerHTML(entry, volumeURL: volumeURL)
        if index % 25 == 0 {
            let full = DocumentBrowserEntry(
                documentId: row.document, volumeId: row.volume, documentNumber: "999", header: "A header",
                dateline: "A dateline", sourceNote: "A source note", isEditorialNote: true,
                footnoteAnchor: "\(row.document)fn1")
            guard try await readerHTML(full, volumeURL: volumeURL) == html else {
                throw ToolError("\(entry.id): the entry's fields change the HTML, so the sample must set them")
            }
        }
        rows.append(RenderRow(volume: row.volume, document: row.document, html: html))
        pages.append((RenderGolden.htmlPath(volume: row.volume, document: row.document), html))
        if (index + 1) % 100 == 0 { note("render: \(index + 1) of \(wanted.count) rows") }
    }

    if itemType(html.path) != nil { try manager.removeItem(at: html) }
    for page in pages {
        let url = out.appendingPathComponent(page.path)
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(page.html.utf8).write(to: url)
    }
    let inputs = [
        "sample.rows": String(rows.count),
        "sample.rowsSHA256": ParityFormat.Digest.sha256(text),
        "sample.brokenRefsDegradable": String(degradable),
    ]
    let sample = RenderGolden(
        provenance: try repo.provenance(tool: "tools/mac-golden render --tei --rows", inputs: inputs),
        configuration: sampleConfiguration,
        rows: rows
    )
    try GoldenJSON.write(sample, to: manifest)
    let bytes = rows.reduce(0) { $0 + $1.bytes }
    note("render: \(rows.count) rows from \(tei.path), \(bytes) bytes of HTML, in \(out.path)")
}

/// The app's reader degrades the cross-references broken-refs-index.json lists, and
/// BrokenRefsIndexStore.shared reads that file from the app's bundle, which for this tool is the
/// folder its executable is in. Puts the submodule's copy there before the first document loads,
/// and returns how many references the reader then degrades.
@MainActor
func installBrokenRefsIndex(_ repo: Repository) throws -> Int {
    let source = repo.upstream.appendingPathComponent("FRUSExplorer/Resources/broken-refs-index.json")
    let data = try Data(contentsOf: source)
    let target = Bundle.main.bundleURL.appendingPathComponent("broken-refs-index.json")
    if (try? Data(contentsOf: target)) != data {
        if itemType(target.path) != nil { try FileManager.default.removeItem(at: target) }
        try data.write(to: target)
    }
    guard let found = Bundle.main.url(forResource: "broken-refs-index", withExtension: "json"),
          (try? Data(contentsOf: found)) == data, let index = BrokenRefsIndexStore.shared else {
        throw ToolError("the reader does not find broken-refs-index.json in this tool's bundle, \(Bundle.main.bundleURL.path)")
    }
    return index.degradableTargets.reduce(0) { count, _ in count + 1 }
}

/// The body of the page the reader loads for `entry`, failing on any load error.
@MainActor
func readerHTML(_ entry: DocumentBrowserEntry, volumeURL: URL) async throws -> String {
    let model = DocumentViewModel(entry: entry, volumeEntry: nil, parser: FRUSDocumentParser())
    await model.load(volumeURL: volumeURL)
    if let error = model.loadError { throw ToolError("\(entry.id) did not load: \(error)") }
    guard let renderModel = model.renderModel else { throw ToolError("\(entry.id) has no render model") }
    let page = HTMLTemplate.build(model: renderModel, colorScheme: .light)
    // The template writes the serializer's fragment, one line, between these two markers.
    let open = "<body>\n", close = "\n</body>"
    guard page.components(separatedBy: open).count == 2, page.components(separatedBy: close).count == 2,
          let start = page.range(of: open), let end = page.range(of: close), start.upperBound <= end.lowerBound else {
        throw ToolError("\(entry.id): the page does not hold exactly one body")
    }
    return String(page[start.upperBound..<end.lowerBound])
}

/// Checks `fixtures/tei` against its SHA256SUMS: exactly the fixture volumes, unchanged. Returns
/// the digests a golden file made from them records, by their paths from the root
/// (`ParityFixtures.verifiedInputs`, which frus-parity's summary runs too).
func verifyFixtures(_ repo: Repository) throws -> [String: String] {
    try ParityFixtures.verifiedInputs(tei: repo.url(ParityFixtures.teiPath))
}

/// The reader degrades a cross-reference that the bundled broken-refs-index.json lists. This tool
/// runs without the app's bundle, so it checks that the index lists none in the fixture volumes:
/// then the reader's HTML is the same with the index or without it.
func checkBrokenRefs(_ repo: Repository) throws {
    let url = repo.upstream.appendingPathComponent("FRUSExplorer/Resources/broken-refs-index.json")
    let index = try JSONDecoder().decode(BrokenRefsIndex.self, from: Data(contentsOf: url))
    let fixtures = Set(ParityFixtures.volumes)
    if let listed = index.degradableTargets.first(where: { fixtures.contains($0.sourceVolume) }) {
        throw ToolError("broken-refs-index.json degrades \(listed.rawTarget) in \(listed.sourceVolume): the render needs the app's bundle")
    }
}

/// Enough of a render manifest to recognise one of any format version, so that a format change
/// does not make render refuse the folder it wrote.
private struct RenderManifestMarker: Decodable {
    let format: Int
    let configuration: String
    let rows: [Row]

    struct Row: Decodable {
        let volume: String
        let document: String
    }
}
