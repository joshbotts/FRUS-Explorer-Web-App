// The Manually Annotated Sub-Corpus's GrAF files (https://anc.org/data/masc/): each text, `<name>.txt`,
// with its segmentation, `<name>-seg.xml`, whose regions anchor character offsets in the text, and its
// Penn Treebank tokens, `<name>-penn.xml`, whose nodes link regions and whose `tok` annotations give
// each token's tag (`msd`) and lemma (`base`).

import FRUSLanguage
import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum MASCReader {
    /// Every text under `folder` with both files beside it, in the order of their paths.
    static func read(_ folder: URL) throws -> TrainingCorpus {
        let manager = FileManager.default
        guard let walk = manager.enumerator(at: folder, includingPropertiesForKeys: nil) else {
            throw ToolError("\(folder.path) cannot be read")
        }
        var texts: [URL] = []
        for case let url as URL in walk where url.pathExtension == "txt" {
            let base = url.deletingPathExtension().path
            if manager.fileExists(atPath: base + "-penn.xml"), manager.fileExists(atPath: base + "-seg.xml") { texts.append(url) }
        }
        texts.sort { $0.path < $1.path }
        guard !texts.isEmpty else { throw ToolError("\(folder.path) holds no text with its -seg.xml and -penn.xml") }
        var documents: [AnnotatedText] = []
        var skipped = 0
        for url in texts {
            let base = url.deletingPathExtension().path
            let text = try String(contentsOf: url, encoding: .utf8)
            let regions = try GrAF.regions(URL(fileURLWithPath: base + "-seg.xml"))
            let tokens = try GrAF.tokens(URL(fileURLWithPath: base + "-penn.xml"))
            // Anchors count UTF-16 units, as the corpus's Java tools count characters; the spans count
            // Unicode scalars.
            var scalarOfUnit: [Int] = []
            scalarOfUnit.reserveCapacity(text.utf16.count + 1)
            for (scalarIndex, scalar) in text.unicodeScalars.enumerated() {
                for _ in 0..<UTF16.width(scalar) { scalarOfUnit.append(scalarIndex) }
            }
            scalarOfUnit.append(text.unicodeScalars.count)
            var spans: [Span] = []
            for token in tokens {
                let anchors = token.regions.compactMap { regions[$0] }
                guard !anchors.isEmpty, anchors.count == token.regions.count,
                      let start = anchors.map(\.0).min(), let end = anchors.map(\.1).max(),
                      start < end, end < scalarOfUnit.count else { skipped += 1; continue }
                spans.append(Span(start: scalarOfUnit[start], end: scalarOfUnit[end], tag: token.tag))
            }
            spans.sort { ($0.start, $0.end) < ($1.start, $1.end) }
            documents.append(AnnotatedText(text: text, spans: spans))
        }
        if skipped > 0 { note("masc: \(skipped) tokens whose regions could not be read, left out") }
        return TrainingCorpus(name: "MASC (\(texts.count) texts)", documents: documents)
    }
}

/// A GrAF file's regions and its tokens.
final class GrAF: NSObject, XMLParserDelegate {
    var regions: [String: (Int, Int)] = [:]
    var nodes: [String: [String]] = [:]
    var tokenTags: [(node: String, tag: String)] = []
    private var currentNode: String?
    private var currentAnnotation: String?
    private var currentTag: String?
    private var failure: Error?

    /// The regions of a segmentation file, by id: each one's start and end anchor.
    static func regions(_ url: URL) throws -> [String: (Int, Int)] {
        try parse(url).regions
    }

    /// The `tok` annotations of a token file, in order: each one's tag and the regions its node links.
    static func tokens(_ url: URL) throws -> [(tag: String, regions: [String])] {
        let graph = try parse(url)
        return graph.tokenTags.map { (tag: $0.tag, regions: graph.nodes[$0.node] ?? []) }
    }

    static func parse(_ url: URL) throws -> GrAF {
        guard let parser = XMLParser(contentsOf: url) else { throw ToolError("\(url.lastPathComponent) cannot be read") }
        let graph = GrAF()
        parser.delegate = graph
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            throw graph.failure ?? parser.parserError ?? ToolError("\(url.lastPathComponent) is not XML")
        }
        return graph
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        switch elementName {
        case "region":
            guard let id = attributes["xml:id"], let anchors = attributes["anchors"] else { return }
            let parts = anchors.split(separator: " ").compactMap { Int($0) }
            if parts.count == 2 { regions[id] = (parts[0], parts[1]) }
        case "node":
            currentNode = attributes["xml:id"]
        case "link":
            if let node = currentNode, let targets = attributes["targets"] {
                nodes[node, default: []] += targets.split(separator: " ").map(String.init)
            }
        case "a":
            currentAnnotation = attributes["label"] == "tok" ? attributes["ref"] : nil
            currentTag = nil
        case "f":
            if currentAnnotation != nil, attributes["name"] == "msd" { currentTag = attributes["value"] }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "node":
            currentNode = nil
        case "a":
            if let node = currentAnnotation, let tag = currentTag { tokenTags.append((node, tag)) }
            currentAnnotation = nil
            currentTag = nil
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        failure = parseError
    }
}
