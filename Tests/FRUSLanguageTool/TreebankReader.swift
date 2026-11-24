// The Penn Treebank syntax of MASC (https://anc.org/data/masc/, "Penn Treebank Syntax"): each text's
// trees in bracketed `.mrg` files, whose leaves, read in order, are the text's tokens with the tags the
// Penn Treebank project gave them, and the tag normalisation both of MASC's tag sources take.

import Foundation

enum TreebankReader {
    /// The leaves of a bracketed file, in order: each tag and token, empty elements left out.
    static func leaves(_ text: String) -> [(tag: String, token: String)] {
        let pattern = /\(([^()\s]+) ([^()\s]+)\)/
        return text.matches(of: pattern).compactMap { match in
            let tag = String(match.1), token = String(match.2)
            return tag == "-NONE-" ? nil : (tag, token)
        }
    }

    /// The ways a leaf's token may be printed in the text it was made from, the treebank's escapes undone.
    static func printings(_ token: String) -> [String] {
        switch token {
        case "-LRB-": return ["(", "[", "{"]
        case "-RRB-": return [")", "]", "}"]
        case "-LSB-": return ["["]
        case "-RSB-": return ["]"]
        case "-LCB-": return ["{"]
        case "-RCB-": return ["}"]
        case "``", "''", "\"": return ["\"", "\u{201C}", "\u{201D}", "``", "''"]
        case "`", "'": return ["'", "\u{2018}", "\u{2019}", "`"]
        case "...": return ["...", "\u{2026}"]
        case "--": return ["--", "\u{2014}", "\u{2013}"]
        default:
            // The treebank's own spellings: `\/` and `\*`, `RSQUO` for the typographer's apostrophe, `XTILDE`
            // for a tilde, `$$` for a slash in an address, and a leading `AMP` for an ampersand.
            var plain = token.replacingOccurrences(of: "\\/", with: "/").replacingOccurrences(of: "\\*", with: "*")
                .replacingOccurrences(of: "RSQUO", with: "\u{2019}").replacingOccurrences(of: "XTILDE", with: "~")
                .replacingOccurrences(of: "$$", with: "/")
            if plain.hasPrefix("AMP"), plain.count == 3 || plain.dropFirst(3).first?.isUppercase == true {
                plain = "&" + plain.dropFirst(3)
            }
            var variants = [plain]
            if plain.contains("'") { variants.append(plain.replacingOccurrences(of: "'", with: "\u{2019}")) }
            if plain.contains("\u{2019}") { variants.append(plain.replacingOccurrences(of: "\u{2019}", with: "'")) }
            return variants
        }
    }

    /// The leaves found in `text`, in order, as spans, with how many could not be found: each leaf at the
    /// cursor, after any spaces, or, for a leaf that is not a marker of the treebank's own, the first place
    /// it starts a token within the next 400 scalars, the text skipped before it being text the trees
    /// leave out, such as headers.
    static func align(_ leaves: [(tag: String, token: String)], to text: String) -> (spans: [Span], missed: Int) {
        let scalars = Array(text.unicodeScalars)
        var cursor = 0, missed = 0
        var spans: [Span] = []
        func matches(_ printing: [Unicode.Scalar], at position: Int) -> Bool {
            position + printing.count <= scalars.count && Array(scalars[position..<position + printing.count]) == printing
        }
        for leaf in leaves {
            while cursor < scalars.count, scalars[cursor].properties.isWhitespace { cursor += 1 }
            let printings = Self.printings(leaf.token).map { Array($0.unicodeScalars) }
            if let printing = printings.first(where: { matches($0, at: cursor) }) {
                spans.append(Span(start: cursor, end: cursor + printing.count, tag: leaf.tag))
                cursor += printing.count
                continue
            }
            // A marker of the treebank's own (<TURN>, {COM:…}) is in no text.
            if leaf.tag == "CODE", !["-LRB-", "-RRB-"].contains(leaf.token) { continue }
            var found: (Int, Int)?
            search: for position in cursor..<min(scalars.count, cursor + 400) {
                guard position == 0 || !scalars[position - 1].properties.isAlphabetic else { continue }
                for printing in printings where matches(printing, at: position) {
                    found = (position, printing.count)
                    break search
                }
            }
            if let (position, length) = found {
                spans.append(Span(start: position, end: position + length, tag: leaf.tag))
                cursor = position + length
            } else {
                missed += 1
            }
        }
        return (spans, missed)
    }
}

/// The tags of MASC's two sources made one tag set, the Penn Treebank's as the English Web Treebank
/// extends it: GATE's parentheses and quotes in `-penn.xml`, the treebank's parentheses tagged `CODE`, a
/// function tag or an index left on a leaf, and the few leaves tagged with a phrase's label, which are
/// left out.
enum TagNormalizer {
    static func normalize(_ tag: String, token: String) -> String? {
        switch tag {
        case "(", "LRB", "-LRB-", "-LSB-", "-LCB-": return "-LRB-"
        case ")", "-RRB-", "-RSB-", "-RCB-": return "-RRB-"
        case "CODE":
            switch token {
            case "-LRB-", "(", "[", "{": return "-LRB-"
            case "-RRB-", ")", "]", "}": return "-RRB-"
            default: return nil
            }
        case "\"", "&quot;", "'": return "''"
        case "-", "--", "...", ";", "SU": return ":"
        case "PP", "PRO$": return "PRP$"
        case "HVS", "BES": return "VBZ"
        case "UH`": return "UH"
        case "VBG|NN": return "VBG"
        case "D": return "DT"
        case "/", "*", "<", ">": return "SYM"
        default: break
        }
        if TagClasses.penn(tag) != nil { return tag }
        // A function tag or an index on a leaf: CC-2, RB=2, VBP-CLR, NNS-1.
        if let base = tag.split(whereSeparator: { $0 == "-" || $0 == "=" }).first.map(String.init), TagClasses.penn(base) != nil {
            return base
        }
        return nil
    }
}
