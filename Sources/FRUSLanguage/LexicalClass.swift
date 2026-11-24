// A word's lexical class (PLAN's S29c), in NaturalLanguage's names, so that the web's classes compare
// with the Mac's tag for tag (`NLTag`'s raw values), and the three a word cloud's lenses read.

/// A token's lexical class: NaturalLanguage's word classes, by their `NLTag` raw values, and its
/// punctuation classes for the tokens a word walk leaves out.
///
/// The tagger tags with its model's own tags (the Penn Treebank's, for a model trained on text tagged
/// with them) and gives each tag one of these, by the table its model carries, as close to
/// NaturalLanguage's reading as a tag can say; a few rules read the word or its neighbour too
/// (`PerceptronModel.lexicalClass(at:)`).
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29c): initial implementation
public enum LexicalClass: String, Sendable, Hashable, CaseIterable, Codable {
    case noun = "Noun"
    case verb = "Verb"
    case adjective = "Adjective"
    case adverb = "Adverb"
    case pronoun = "Pronoun"
    case determiner = "Determiner"
    case particle = "Particle"
    case preposition = "Preposition"
    case number = "Number"
    case conjunction = "Conjunction"
    case interjection = "Interjection"
    case classifier = "Classifier"
    case idiom = "Idiom"
    case otherWord = "OtherWord"
    case sentenceTerminator = "SentenceTerminator"
    case openQuote = "OpenQuote"
    case closeQuote = "CloseQuote"
    case openParenthesis = "OpenParenthesis"
    case closeParenthesis = "CloseParenthesis"
    case wordJoiner = "WordJoiner"
    case dash = "Dash"
    case punctuation = "Punctuation"
    case otherPunctuation = "OtherPunctuation"

    /// Whether this is a word's class rather than punctuation's.
    public var isWordClass: Bool {
        switch self {
        case .noun, .verb, .adjective, .adverb, .pronoun, .determiner, .particle, .preposition, .number,
             .conjunction, .interjection, .classifier, .idiom, .otherWord:
            return true
        default:
            return false
        }
    }

    /// The class a word cloud's part-of-speech lens keeps it under: Topics' nouns, Actions' verbs and
    /// Descriptors' adjectives, or none, as WordCloudKit's `WordCloudLexicalClass` reads NaturalLanguage's
    /// classes (noun, verb, adjective, and every other class one class, which no lens keeps).
    public var lensClass: LensClass {
        switch self {
        case .noun: return .noun
        case .verb: return .verb
        case .adjective: return .adjective
        default: return .other
        }
    }

    /// A word's class as the word cloud's lenses read it (S29a's `WordCloudLexicalClass`), so that an
    /// adapter maps one to the other case for case.
    public enum LensClass: String, Sendable, Hashable, CaseIterable {
        case noun, verb, adjective, other
    }
}
