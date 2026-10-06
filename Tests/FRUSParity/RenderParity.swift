// Check 4 on Linux: the reader's HTML, rendered by FRUSCoreKit, against the golden HTML.
//
// The Mac reader renders a document in two steps, and since upstream #1569 the kit holds what both
// call. DocumentViewModel.load parses the document alone, takes the volume's persons and glossary
// terms from its TEI when no person store has them, and converts the document with the reader's
// lookups and the bundled broken-refs index; HTMLTemplate.build then writes the serializer's
// fragment. tools/mac-golden ran that path to make the golden files. This file makes the same calls
// through the kit's public API alone, with a plain import, as the server will. It chooses only what
// the app chooses: persons and terms from the TEI, no classification override, and the app's
// bundled broken-refs index.
//
// The golden HTML cannot show where the persons and terms came from. The serializer writes a
// person's or a term's link from its ref alone, and the one link a lookup decides, an <abbr> whose
// text names a term, occurs in none of the three fixture volumes. So the passes also return the
// lists they rendered with, for the tests to compare, and a synthetic volume tests the <abbr> link.

import FRUSCoreKit
import Foundation
import ParityFormat

/// One document's HTML, as a pass rendered it. `html` is nil when the pass found no such document.
public struct RenderedDocument: Equatable, Sendable {
    public var volume: String
    public var document: String
    public var html: String?

    public init(volume: String, document: String, html: String?) {
        self.volume = volume
        self.document = document
        self.html = html
    }
}

/// How a rendered document differs from its golden row.
public struct RenderMismatch: Equatable, Sendable, CustomStringConvertible {
    public var volume: String
    public var document: String
    public var detail: String

    public init(volume: String, document: String, detail: String) {
        self.volume = volume
        self.document = document
        self.detail = detail
    }

    public var description: String { "\(volume)/\(document): \(detail)" }
}

/// A volume's persons and glossary terms, field by field, with the reader's lookups made from them.
/// The kit's entries are not `Equatable`, so their fields are copied out for two parses to be
/// compared; the lookups are made from the entries themselves.
public struct LookupLists: Equatable, Sendable {
    public struct Person: Equatable, Sendable {
        public var ref: String
        public var name: String
        public var description: String?
        public var role: String?
        public var startYear: Int?
        public var endYear: Int?

        public init(ref: String, name: String, description: String?, role: String?, startYear: Int?, endYear: Int?) {
            self.ref = ref
            self.name = name
            self.description = description
            self.role = role
            self.startYear = startYear
            self.endYear = endYear
        }
    }

    public struct Term: Equatable, Sendable {
        public var ref: String
        public var term: String
        public var definition: String?

        public init(ref: String, term: String, definition: String?) {
            self.ref = ref
            self.term = term
            self.definition = definition
        }
    }

    public let persons: [Person]
    public let terms: [Term]
    let lookups: ReaderLookups

    init(persons: [PersonEntry], terms: [GlossEntry]) {
        self.persons = persons.map {
            Person(ref: $0.ref, name: $0.name, description: $0.description, role: $0.role,
                   startYear: $0.startYear, endYear: $0.endYear)
        }
        self.terms = terms.map { Term(ref: $0.ref, term: $0.term, definition: $0.definition) }
        lookups = ReaderLookups(persons: persons, terms: terms)
    }

    /// Equal when the persons and terms are, field for field and in order. The lookups are made
    /// from them, so they are equal too.
    public static func == (lhs: LookupLists, rhs: LookupLists) -> Bool {
        lhs.persons == rhs.persons && lhs.terms == rhs.terms
    }
}

/// Renders the fixture volumes' documents as the Mac reader does, through FRUSCoreKit's public API.
public struct ReaderRenderer: Sendable {
    /// The broken-refs index the app bundles, from the submodule's root.
    public static let brokenRefsPath = "FRUSExplorer/Resources/broken-refs-index.json"

    let tei: URL
    let brokenRefs: BrokenRefsIndex

    /// A renderer for the volumes in `tei`, by default `layout`'s fixtures, with the broken-refs
    /// index the pinned app bundles. A volume is the file `<volume>.xml` in that folder.
    public init(layout: RepositoryLayout, tei: URL? = nil) throws {
        self.tei = tei ?? layout.tei
        let url = layout.upstream.appendingPathComponent(Self.brokenRefsPath)
        brokenRefs = try JSONDecoder().decode(BrokenRefsIndex.self, from: Data(contentsOf: url))
    }

    /// The persons and terms the reader takes from each of `volumes`' TEI when no person store has
    /// them: `parsePersons` and `parseTerms`, each with a new parser. As in the reader, a list that
    /// cannot be parsed is empty.
    public func readerLists(_ volumes: [String]) async throws -> [String: LookupLists] {
        let volumes = Array(Set(volumes))
        let lists = try await Self.map(volumes.count) { index in
            let url = self.volumeURL(volumes[index])
            return LookupLists(persons: (try? await FRUSDocumentParser().parsePersons(volumeURL: url)) ?? [],
                               terms: (try? await FRUSDocumentParser().parseTerms(volumeURL: url)) ?? [])
        }
        return Dictionary(uniqueKeysWithValues: zip(volumes, lists))
    }

    /// The reader's path, for each of `rows` in order: a new parser's `parseDocument`, then
    /// `ASTToRenderNodeConverter(readerOf:lookups:brokenRefs:)` with `ReaderLookups` from the
    /// volume's `readerLists`, then `FRUSRenderNodeHTMLSerializer.reader`. Rows render
    /// concurrently, each with its own parser, as many at once as the machine has processors.
    ///
    /// The persons and terms are parsed once per volume. The reader parses them for each document
    /// it opens, but `FRUSDocumentParser` keeps no state between calls: each reads the file with a
    /// new `XMLParser`, so they are the same every time.
    public func readerPass(_ rows: [(volume: String, document: String)]) async throws -> [RenderedDocument] {
        let lists = try await readerLists(rows.map(\.volume))
        return try await Self.map(rows.count) { index in
            let (volume, document) = rows[index]
            let ast = try await FRUSDocumentParser().parseDocument(documentId: document, volumeURL: self.volumeURL(volume))
            return RenderedDocument(volume: volume, document: document,
                                    html: ast.map { self.html($0, volume: volume, lookups: lists[volume]!.lookups) })
        }
    }

    /// The path the server serves (FRUSLightAPI's `ReaderService`): one `parseVolumeFull` of each volume, whose
    /// persons and terms make the lookups, then every document it yields, in parse order, with the
    /// reader's converter and serializer. Volumes render concurrently, in the order given. Each
    /// volume's persons and terms are returned too, to be compared with `readerLists`.
    public func fullParsePass(_ volumes: [String]) async throws -> (documents: [RenderedDocument], lists: [String: LookupLists]) {
        let passes = try await Self.map(volumes.count) { index in
            let volume = volumes[index]
            let parse = try await FRUSDocumentParser().parseVolumeFull(volumeURL: self.volumeURL(volume))
            let lists = LookupLists(persons: parse.persons, terms: parse.terms)
            let documents = parse.documents.map { ast in
                RenderedDocument(volume: volume, document: ast.documentId,
                                 html: self.html(ast, volume: volume, lookups: lists.lookups))
            }
            return (documents, lists)
        }
        return (passes.flatMap(\.0), Dictionary(zip(volumes, passes.map(\.1)), uniquingKeysWith: { first, _ in first }))
    }

    func volumeURL(_ volume: String) -> URL { tei.appendingPathComponent("\(volume).xml") }

    /// The reader's HTML for a parsed document: the fragment `HTMLTemplate.build` writes in the page's body.
    func html(_ ast: FRUSDocumentAST, volume: String, lookups: ReaderLookups) -> String {
        var converter = ASTToRenderNodeConverter(readerOf: volume, lookups: lookups, brokenRefs: brokenRefs)
        return FRUSRenderNodeHTMLSerializer.reader.serialize(converter.convert(ast))
    }

    /// `body` of each index below `count`, in index order, run as many at once as the machine has
    /// processors.
    static func map<T: Sendable>(_ count: Int, _ body: @escaping @Sendable (Int) async throws -> T) async throws -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            var results = [T?](repeating: nil, count: count)
            var next = 0
            func start() {
                guard next < count else { return }
                let index = next
                next += 1
                group.addTask { (index, try await body(index)) }
            }
            for _ in 0..<max(1, ProcessInfo.processInfo.activeProcessorCount) { start() }
            for try await (index, value) in group {
                results[index] = value
                start()
            }
            return results.map { $0! }
        }
    }
}

public enum RenderParity {
    /// The committed golden render manifest, and each way it is stale at this pin. One made from
    /// other app sources tests other code than the pin's, so a comparison with it means nothing.
    public static func golden(_ layout: RepositoryLayout) throws -> (golden: RenderGolden, stale: [String]) {
        let status = try GoldenStatus(directory: layout.golden)
        guard case .present = status.states[.render] else {
            throw GoldenError.malformed(GoldenFile.render.rawValue, "it is made from the app's source alone and must be committed, not pending: run scripts/make-golden")
        }
        let golden = try GoldenJSON.read(RenderGolden.self, from: status.url(.render))
        let stale = GoldenValidation.staleness(of: golden.provenance, file: GoldenFile.render.rawValue, layout: layout,
                                               sourceDigest: try Upstream.sourceDigest(layout.upstream))
        return (golden, stale)
    }

    /// Every rendered document that differs from its golden row. A document matches when its
    /// HTML's UTF-8 bytes are the committed file's, and their size and SHA-256 are the manifest
    /// row's. Each difference gives both sizes and digests, and `RenderDiff.firstDifference`.
    /// `directory` is the manifest's folder.
    public static func mismatches(_ rendered: [RenderedDocument], golden: RenderGolden, directory: URL) -> [RenderMismatch] {
        var rows: [String: RenderRow] = [:]
        for row in golden.rows { rows["\(row.volume)/\(row.document)"] = row }
        var mismatches: [RenderMismatch] = []
        for document in rendered {
            func mismatch(_ detail: String) {
                mismatches.append(RenderMismatch(volume: document.volume, document: document.document, detail: detail))
            }
            guard let html = document.html else {
                mismatch("the kit finds no such document in the volume")
                continue
            }
            guard let row = rows["\(document.volume)/\(document.document)"] else {
                mismatch("rendered, but the golden manifest has no such row")
                continue
            }
            let path = RenderGolden.htmlPath(volume: document.volume, document: document.document)
            guard let file = try? Data(contentsOf: directory.appendingPathComponent(path)) else {
                mismatch("the golden file \(path) cannot be read")
                continue
            }
            let data = Data(html.utf8)
            let sha = ParityFormat.Digest.sha256(data)
            guard data != file || data.count != row.bytes || sha != row.sha256 else { continue }
            var detail = "rendered \(data.count) bytes with SHA-256 \(sha.prefix(12)); the manifest says \(row.bytes) bytes, \(row.sha256.prefix(12))"
            if let difference = RenderDiff.firstDifference(golden: String(decoding: file, as: UTF8.self), candidate: html) {
                detail += ", and the golden file differs at \(difference)"
            } else {
                detail += ", but the golden file is the same: the manifest is inconsistent"
            }
            mismatch(detail)
        }
        return mismatches
    }
}
