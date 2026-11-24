// The lemmatizer (PLAN's S29c): WordNet's morphological processor, morphy, as WordNet 3's `morph.c` runs
// it for a single word, over WordNet's exception lists and the lemmas of its index, read by the class the
// tagger gives the word.
//
// ## The rules
//
// For a noun, a verb, an adjective or an adverb, the word lowercased:
// 1. A word holding a period or a digit has no lemma ("U.S.", "1960s"), as NaturalLanguage gives none.
// 2. A word in the class's exception list has the list's first base form ("went" → "go", "children" →
//    "child", "better" → "good").
// 3. An adverb has no other rule: it is its own lemma when WordNet lists it, and has none otherwise.
// 4. A noun of two letters or fewer, or one ending in `ss`, is its own lemma when WordNet lists it.
//    A noun ending in `ful` is lemmatized without it and has it put back ("boxesful" → "boxful").
// 5. Otherwise each of the class's detachment rules is tried in `morph.c`'s order, and the first that
//    makes a different word WordNet lists as the class's gives the lemma: for nouns `s`, `ses` → `s`,
//    `xes` → `x`, `zes` → `z`, `ches` → `ch`, `shes` → `sh`, `men` → `man`, `ies` → `y`; for verbs `s`,
//    `ies` → `y`, `es` → `e`, `es`, `ed` → `e`, `ed`, `ing` → `e`, `ing`; for adjectives `er`, `est`,
//    `er` → `e`, `est` → `e`.
// 6. Failing that, the word is its own lemma when WordNet lists it as the class's, and has none
//    otherwise: so a name WordNet does not know has no lemma, as NaturalLanguage gives a name it does
//    not know none, and the word cloud then counts the word as printed, plural-folded.
//
// For the clitics the splitter takes off a word, NaturalLanguage's lemmas: `n't` → `not`, `'re` → `be`,
// `'ve` → `have`, `'ll` → `will`, `'m` → `be`, `'d` → `have`, and none for `'s`, either apostrophe.
//
// For a word of any other class, a pronoun, a determiner, a preposition, a conjunction, a particle, an
// interjection or a number in letters, the word lowercased, which WordNet does not list but
// NaturalLanguage gives; a number in digits and another word have none.

/// WordNet's parts of speech, which its lists are kept by.
public enum WordNetPart: String, Sendable, Hashable, CaseIterable {
    case noun, verb, adjective, adverb

    /// The part a lexical class is lemmatized as, if any.
    public init?(_ lexicalClass: LexicalClass) {
        switch lexicalClass {
        case .noun: self = .noun
        case .verb: self = .verb
        case .adjective: self = .adjective
        case .adverb: self = .adverb
        default: return nil
        }
    }

    /// `morph.c`'s detachment rules for the part, in its order: each suffix and its ending.
    var detachments: [(suffix: String, ending: String)] {
        switch self {
        case .noun:
            return [("s", ""), ("ses", "s"), ("xes", "x"), ("zes", "z"), ("ches", "ch"), ("shes", "sh"),
                    ("men", "man"), ("ies", "y")]
        case .verb:
            return [("s", ""), ("ies", "y"), ("es", "e"), ("es", ""), ("ed", "e"), ("ed", ""), ("ing", "e"), ("ing", "")]
        case .adjective:
            return [("er", ""), ("est", ""), ("er", "e"), ("est", "e")]
        case .adverb:
            return []
        }
    }
}

/// WordNet's lists for one part of speech: its exceptions, each inflected form with its base forms, and
/// the single words its index lists.
public struct WordNetPartLists: Sendable, Equatable {
    public var exceptions: [String: [String]]
    public var lemmas: Set<String>

    public init(exceptions: [String: [String]], lemmas: Set<String>) {
        self.exceptions = exceptions
        self.lemmas = lemmas
    }
}

/// The lemmatizer: the rules at the top of this file over WordNet's lists.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29c): initial implementation
public struct Lemmatizer: Sendable {
    /// WordNet's lists, by part.
    public let lists: [WordNetPart: WordNetPartLists]

    /// The clitics' lemmas, lowercased, with the typewriter's apostrophe.
    public static let cliticLemmas: [String: String?] = [
        "n't": "not", "'re": "be", "'ve": "have", "'ll": "will", "'m": "be", "'d": "have", "'s": nil,
    ]

    /// Creates a lemmatizer over WordNet's lists.
    public init(lists: [WordNetPart: WordNetPartLists]) {
        self.lists = lists
    }

    /// The lemma of `word`, which the tagger gave `lexicalClass`, lowercased, or `nil` for none.
    public func lemma(of word: Substring, as lexicalClass: LexicalClass) -> String? {
        let lowered = word.lowercased()
        if lowered.first == "'" || lowered.first == "\u{2019}" || lowered.hasSuffix("n't") || lowered.hasSuffix("n\u{2019}t") {
            let typewriter = lowered.replacingApostrophes()
            if let lemma = Self.cliticLemmas[typewriter] { return lemma }
        }
        guard let part = WordNetPart(lexicalClass) else {
            switch lexicalClass {
            case .pronoun, .determiner, .preposition, .conjunction, .particle, .interjection, .number:
                return lowered.unicodeScalars.allSatisfy({ $0.properties.isAlphabetic }) ? lowered : nil
            default:
                return nil
            }
        }
        if lowered.contains(where: { $0 == "." || $0.isNumber }) { return nil }
        return morphy(lowered, part)
    }

    /// WordNet's morphy for one word of one part, already lowercased: rules 2 to 6.
    public func morphy(_ word: String, _ part: WordNetPart) -> String? {
        guard let lists = lists[part] else { return nil }
        if let bases = lists.exceptions[word], let first = bases.first { return first }
        if part == .adverb { return lists.lemmas.contains(word) ? word : nil }
        var stem = word, ending = ""
        if part == .noun {
            if word.hasSuffix("ful"), word.count > 3 {
                stem = String(word.dropLast(3))
                ending = "ful"
            } else if word.hasSuffix("ss") || word.count <= 2 {
                return lists.lemmas.contains(word) ? word : nil
            }
        }
        for (suffix, replacement) in part.detachments where stem.hasSuffix(suffix) {
            let candidate = String(stem.dropLast(suffix.count)) + replacement
            if candidate != stem, lists.lemmas.contains(candidate) { return candidate + ending }
        }
        return lists.lemmas.contains(word) ? word : nil
    }
}

extension String {
    /// The text with U+2019, the typographer's apostrophe, as U+0027.
    func replacingApostrophes() -> String {
        String(String.UnicodeScalarView(unicodeScalars.map { $0.value == 0x2019 ? "'" : $0 }))
    }
}
