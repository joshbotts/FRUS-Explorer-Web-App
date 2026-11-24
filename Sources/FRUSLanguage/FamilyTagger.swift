// The web's tagger as WordCloudKit's tokenizers read a host's tagger (PLAN's S29d): the adapter S29c's
// `LanguageTagger.swift` sketched, to S29a's `WordCloudTagger` (FRUS-Explorer#1979, in the pin since S26b's
// move). Through it the kit's own tokenizers count with the web's words, lemmas and classes, by the kit's
// rules, so that the app's generator, `CloudVectorsRunner.run(tagger:cloudLenses:environment:)`, counts the
// family's clouds and references with it, and the server's live counts are to (S29e).

import Foundation
import WordCloudKit

/// The web's tagger, ``LanguageTagger``, as WordCloudKit reads a host's tagger: its identity, its health, and
/// its walk by word.
///
/// The identity is the family's (``LanguageIdentity/wordCloudIdentity``), so every file counted with it names
/// the family, and a reference of another identity refuses a scope it counted. The health says what
/// ``LanguageTagger`` says: lemmas and lexical classes, and no names. The word walk is
/// ``LanguageTagger/enumerateWords(in:reading:using:)``, its reading and its classes mapped case for case; the
/// name walk gives every word with no type, since the tagger names no one and the kit's entity lenses are
/// refused by its health.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29d): initial implementation
public struct FRUSWordCloudTagger: WordCloudTagger, Sendable {
    /// The tagger it walks.
    public let tagger: LanguageTagger

    /// The web's tagger over this module's model and lists, or another for a test.
    public init(_ tagger: LanguageTagger = .shared) {
        self.tagger = tagger
    }

    /// The family's identity.
    public var identity: WordCloudTokenizerIdentity { tagger.identity.wordCloudIdentity }

    /// What the tagger can do, in the kit's three flags.
    public var health: NaturalLanguageHealth {
        NaturalLanguageHealth(lemmatizes: tagger.lemmatizes, classifiesWords: tagger.classifiesWords,
                              recognizesNames: tagger.recognizesNames)
    }

    /// The tagger's word walk, under the reading the kit asks for, each word's class in the lenses' four. The tagger
    /// classes a line's words as it tags the line, so a word's class is read as the word is given, which costs nothing.
    public func enumerateWords(in text: String, reading: WordCloudTagReading,
                               using body: (_ range: Range<String.Index>, _ lemma: String?,
                                            _ lexicalClass: () -> WordCloudLexicalClass?) -> Bool) {
        tagger.enumerateWords(in: text, reading: LanguageReading(reading)) { range, lemma, lexicalClass in
            let lensClass = lexicalClass().map { WordCloudLexicalClass($0.lensClass) }
            return body(range, lemma) { lensClass }
        }
    }

    /// Every word of `text` with no name type: the tagger recognizes no names.
    public func enumerateNames(in text: String,
                               using body: (_ range: Range<String.Index>, _ nameType: WordCloudNameType?) -> Bool) {
        tagger.enumerateWords(in: text, reading: []) { range, _, _ in body(range, nil) }
    }
}

extension LanguageIdentity {
    /// The family's identity as WordCloudKit's files record a tokenizer: its name and its version.
    public var wordCloudIdentity: WordCloudTokenizerIdentity {
        WordCloudTokenizerIdentity(name: name, version: version)
    }
}

extension LanguageReading {
    /// The reading a kit's walk asks for, bit by bit by name, so that a reading the kit adds is not read as one
    /// of these.
    public init(_ reading: WordCloudTagReading) {
        self = []
        if reading.contains(.lemmas) { insert(.lemmas) }
        if reading.contains(.lexicalClasses) { insert(.lexicalClasses) }
    }
}

extension WordCloudLexicalClass {
    /// The kit's class for a lens class of the tagger's.
    public init(_ lensClass: LexicalClass.LensClass) {
        switch lensClass {
        case .noun: self = .noun
        case .verb: self = .verb
        case .adjective: self = .adjective
        case .other: self = .other
        }
    }
}
