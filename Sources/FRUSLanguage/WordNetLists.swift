// WordNet's lists as the lemmatizer reads them (PLAN's S29c): from WordNet's database files, the four
// exception lists and the single words of its four indexes, in a canonical text whose SHA-256 is the
// family's lists' digest.

import Foundation

/// WordNet's lists in their canonical text, and the reading of WordNet's own files into it.
///
/// ## The canonical text
/// UTF-8, lines ending in a line feed: a first line naming the format, `# FRUSLanguage WordNet lists 1`,
/// then for each part in the order noun, verb, adjective, adverb, a line `## <part> exceptions`, the
/// part's exceptions one a line, an inflected form and its base forms separated by single spaces, and a
/// line `## <part> lemmas`, the part's lemmas one a line; each list sorted by its lines' UTF-8 bytes.
///
/// ## What is taken from WordNet's files
/// From `noun.exc`, `verb.exc`, `adj.exc` and `adv.exc`, every line whose inflected form is a single word,
/// with its base forms that are single words too; from `index.noun`, `index.verb`, `index.adj` and
/// `index.adv`, the lemma of every line but the licence's at the top, when it is a single word. A
/// collocation, written with underscores, is left out, since the lemmatizer reads one word at a time.
public enum WordNetLists {
    /// The canonical text's first line.
    public static let header = "# FRUSLanguage WordNet lists 1"

    /// WordNet's file names for a part.
    static func files(_ part: WordNetPart) -> (exceptions: String, index: String) {
        switch part {
        case .noun: return ("noun.exc", "index.noun")
        case .verb: return ("verb.exc", "index.verb")
        case .adjective: return ("adj.exc", "index.adj")
        case .adverb: return ("adv.exc", "index.adv")
        }
    }

    /// Reads WordNet's database files from `dict`, its `dict` folder, into lists.
    public static func read(dict: URL) throws -> [WordNetPart: WordNetPartLists] {
        var lists: [WordNetPart: WordNetPartLists] = [:]
        for part in WordNetPart.allCases {
            let (exceptionFile, indexFile) = files(part)
            var exceptions: [String: [String]] = [:]
            for line in try lines(dict.appendingPathComponent(exceptionFile)) {
                let fields = line.split(separator: " ").map(String.init)
                guard fields.count >= 2, !fields[0].contains("_") else { continue }
                let bases = fields.dropFirst().filter { !$0.contains("_") }
                guard !bases.isEmpty else { continue }
                exceptions[fields[0], default: []] += bases
            }
            var lemmas = Set<String>()
            for line in try lines(dict.appendingPathComponent(indexFile)) where !line.hasPrefix(" ") {
                guard let lemma = line.split(separator: " ").first.map(String.init), !lemma.contains("_") else { continue }
                lemmas.insert(lemma)
            }
            lists[part] = WordNetPartLists(exceptions: exceptions, lemmas: lemmas)
        }
        return lists
    }

    static func lines(_ url: URL) throws -> [Substring] {
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: true).map { $0.hasSuffix("\r") ? $0.dropLast() : $0 }
    }

    /// The lists' canonical text.
    public static func canonicalText(_ lists: [WordNetPart: WordNetPartLists]) -> String {
        var out = header + "\n"
        func sorted(_ lines: [String]) -> [String] { lines.sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) } }
        for part in WordNetPart.allCases {
            let partLists = lists[part] ?? WordNetPartLists(exceptions: [:], lemmas: [])
            out += "## \(part.rawValue) exceptions\n"
            for line in sorted(partLists.exceptions.map { ([$0.key] + $0.value).joined(separator: " ") }) { out += line + "\n" }
            out += "## \(part.rawValue) lemmas\n"
            for line in sorted(Array(partLists.lemmas)) { out += line + "\n" }
        }
        return out
    }

    /// Reads the canonical text back into lists.
    /// - Throws: `WordNetListsError` for a text that is not in the format.
    public static func parse(canonicalText text: String) throws -> [WordNetPart: WordNetPartLists] {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.last == "" else { throw WordNetListsError("the text does not end with a line feed") }
        lines.removeLast()
        guard lines.first.map(String.init) == header else { throw WordNetListsError("the first line is not \(header)") }
        var lists: [WordNetPart: WordNetPartLists] = [:]
        var part: WordNetPart?
        var readingExceptions = false
        var expected: [(WordNetPart, Bool)] = WordNetPart.allCases.flatMap { [($0, true), ($0, false)] }
        for line in lines.dropFirst() {
            if line.hasPrefix("## ") {
                let fields = line.dropFirst(3).split(separator: " ")
                guard fields.count == 2, let named = WordNetPart(rawValue: String(fields[0])),
                      fields[1] == "exceptions" || fields[1] == "lemmas", let next = expected.first,
                      next.0 == named, next.1 == (fields[1] == "exceptions") else {
                    throw WordNetListsError("\(line) is not the next section")
                }
                expected.removeFirst()
                part = named
                readingExceptions = fields[1] == "exceptions"
                if lists[named] == nil { lists[named] = WordNetPartLists(exceptions: [:], lemmas: []) }
                continue
            }
            guard let current = part, !line.isEmpty else { throw WordNetListsError("a line outside a section, or empty") }
            if readingExceptions {
                let fields = line.split(separator: " ").map(String.init)
                guard fields.count >= 2 else { throw WordNetListsError("\(line) has no base form") }
                lists[current]!.exceptions[fields[0]] = Array(fields.dropFirst())
            } else {
                lists[current]!.lemmas.insert(String(line))
            }
        }
        guard expected.isEmpty else { throw WordNetListsError("a section is missing") }
        return lists
    }
}

/// Why WordNet's lists could not be read.
public struct WordNetListsError: Error, CustomStringConvertible, Equatable {
    public let description: String
    public init(_ description: String) { self.description = description }
}
