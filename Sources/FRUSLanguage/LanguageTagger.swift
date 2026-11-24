// The web's tagger (PLAN's S29c): the word splitter, the lexical-class tagger and the lemmatizer
// together, under one identity, a name and a version with the digests of the model and the lists, which
// is the tokenizer family the web's clouds and references are counted in (S29d).
//
// Its walk is the one WordCloudKit's `WordCloudTagger` asks of a host's tagger (FRUS-Explorer#1979, S29a):
// each word of a text in order, with its range, its lemma when the walk reads lemmas and a function that
// answers its lexical class. Since S29d the module conforms it to the kit's protocol, in the pin since S26b's
// move: `FRUSWordCloudTagger` (FamilyTagger.swift), with which the app's generator counts the family's clouds
// and references.

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation

/// What a word walk reads of each word besides its range, as WordCloudKit's `WordCloudTagReading` has it,
/// bit for bit: lemmas, then lexical classes.
public struct LanguageReading: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Each word's lemma.
    public static let lemmas = LanguageReading(rawValue: 1 << 0)
    /// Each word's lexical class.
    public static let lexicalClasses = LanguageReading(rawValue: 1 << 1)
}

/// The tokenizer family's identity: a name and a version, with the digests of the model and the lists the
/// version is made from.
public struct LanguageIdentity: Sendable, Hashable, Codable, CustomStringConvertible {
    /// The family's name.
    public let name: String
    /// Its version: the rules' version, a plus, and the first eight hex digits of the model's SHA-256 and
    /// of the lists', so that a new model or new lists change it as a change of rule does.
    public let version: String
    /// The SHA-256 of the model's file.
    public let modelSHA256: String
    /// The SHA-256 of the lists, as ``WordNetLists/canonicalText`` writes them.
    public let listsSHA256: String

    public init(name: String, rulesVersion: Int, modelSHA256: String, listsSHA256: String) {
        self.name = name
        self.version = "\(rulesVersion)+\(modelSHA256.prefix(8)).\(listsSHA256.prefix(8))"
        self.modelSHA256 = modelSHA256
        self.listsSHA256 = listsSHA256
    }

    public var description: String { "\(name) \(version)" }
}

/// A word the tagger tagged: its range in the text, its tag, its class and its lemma.
public struct TaggedWord: Sendable, Equatable {
    public let range: Range<String.Index>
    public let tag: String
    public let lexicalClass: LexicalClass
    public let lemma: String?
}

/// The web's tagger: splitter, tagger and lemmatizer, with the model and lists this module carries.
///
/// What it can do, in the terms of WordCloudKit's `NaturalLanguageHealth`: it lemmatizes and classifies
/// words, and recognizes no names, so the People, Places and Organizations lenses stay phase 5's.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29c): initial implementation
public final class LanguageTagger: Sendable {
    /// The family's name.
    public static let familyName = "FRUSLanguage"

    /// The rules' version: raised whenever a rule of the splitter, the tagger's class rules or the
    /// lemmatizer changes what the family counts, as a new model or new lists change the version by
    /// their digests.
    public static let rulesVersion = 1

    /// Whether it gives lemmas, as `NaturalLanguageHealth.lemmatizes` says.
    public let lemmatizes = true
    /// Whether it gives lexical classes, as `NaturalLanguageHealth.classifiesWords` says.
    public let classifiesWords = true
    /// Whether it names people, places and organizations, as `NaturalLanguageHealth.recognizesNames`
    /// says: it does not.
    public let recognizesNames = false

    /// The tagger over this module's model and lists, read on its first use.
    public static let shared: LanguageTagger = {
        do {
            return try LanguageTagger(modelFile: EmbeddedModel.bytes(), listsText: EmbeddedWordNet.canonicalText())
        } catch {
            fatalError("FRUSLanguage's embedded model or lists do not read: \(error)")
        }
    }()

    public let model: PerceptronModel
    public let lemmatizer: Lemmatizer
    public let identity: LanguageIdentity

    /// A tagger over a model's file and the lists' canonical text.
    public init(modelFile: [UInt8], listsText: String) throws {
        model = try PerceptronModel(decoding: modelFile)
        lemmatizer = Lemmatizer(lists: try WordNetLists.parse(canonicalText: listsText))
        identity = LanguageIdentity(name: Self.familyName, rulesVersion: Self.rulesVersion,
                                    modelSHA256: Self.sha256(modelFile), listsSHA256: Self.sha256(Array(listsText.utf8)))
    }

    /// A tagger over a model and lemmatizer already made, for tests and the trainer.
    public init(model: PerceptronModel, lemmatizer: Lemmatizer, identity: LanguageIdentity) {
        self.model = model
        self.lemmatizer = lemmatizer
        self.identity = identity
    }

    /// SHA-256, as lowercase hex.
    public static func sha256(_ bytes: [UInt8]) -> String {
        SHA256.hash(data: bytes).map { byte in
            let hex = String(byte, radix: 16)
            return byte < 16 ? "0" + hex : hex
        }.joined()
    }

    // MARK: - The walk

    /// Calls `body` with each word of `text`, in order, without punctuation, whitespace or symbols, as
    /// WordCloudKit's `WordCloudTagger.enumerateWords(in:reading:using:)` asks.
    ///
    /// `body` is given the word's range in `text`; its lemma when `reading` holds ``LanguageReading/lemmas``,
    /// and `nil` when it does not or the word has none; and a function that answers its lexical class.
    /// A walk that reads neither lemmas nor classes only splits; one that reads either tags each line
    /// first. `body` returns `false` to stop the walk.
    public func enumerateWords(in text: String, reading: LanguageReading,
                               using body: (_ range: Range<String.Index>, _ lemma: String?,
                                            _ lexicalClass: () -> LexicalClass?) -> Bool) {
        let tokens = WordSplitter.tokens(in: text)
        guard !reading.isEmpty else {
            for token in tokens where token.kind == .word {
                guard body(token.range, nil, { nil }) else { return }
            }
            return
        }
        let readsLemmas = reading.contains(.lemmas)
        forEachLine(of: tokens, in: text) { token, printed, tag, lexicalClass in
            let lemma = readsLemmas ? lemmatizer.lemma(of: printed, as: lexicalClass) : nil
            return body(token.range, lemma, { lexicalClass })
        }
    }

    /// Every word of `text`, tagged: its range, tag, class and lemma.
    public func tagged(_ text: String) -> [TaggedWord] {
        let tokens = WordSplitter.tokens(in: text)
        var words: [TaggedWord] = []
        words.reserveCapacity(tokens.count)
        forEachLine(of: tokens, in: text) { token, printed, tag, lexicalClass in
            words.append(TaggedWord(range: token.range, tag: model.tags[Int(tag)], lexicalClass: lexicalClass,
                                    lemma: lemmatizer.lemma(of: printed, as: lexicalClass)))
            return true
        }
        return words
    }

    /// Tags each line of `tokens` and calls `body` with each word, its printed form, its tag and its class,
    /// until `body` returns `false`.
    func forEachLine(of tokens: [LanguageToken], in text: String,
                     _ body: (_ token: LanguageToken, _ printed: Substring, _ tag: UInt8, _ lexicalClass: LexicalClass) -> Bool) {
        var lineStart = 0
        while lineStart < tokens.count {
            var lineEnd = lineStart + 1
            while lineEnd < tokens.count, !tokens[lineEnd].startsLine { lineEnd += 1 }
            let line = tokens[lineStart..<lineEnd]
            // Each token's own scalars, from the scalar view, which rounds no index to a grapheme cluster's boundary.
            let printed = line.map { Substring(text.unicodeScalars[$0.range]) }
            let tags = model.tag(line: printed)
            for (offset, token) in line.enumerated() where token.kind == .word {
                guard body(token, printed[offset], tags[offset], lexicalClass(at: offset, tags: tags, printed: printed)) else { return }
            }
            lineStart = lineEnd
        }
    }

    /// The class of the word at `index` of a line: the model's (`PerceptronModel.lexicalClass(at:tags:tokens:)`),
    /// but for a proper noun's tag (`NNP`, `NNPS`) on a word WordNet lists as an adjective and followed by a
    /// common noun in lowercase, which is an adjective, as NaturalLanguage reads "Libyan government" and
    /// "Soviet relations", while "Soviet Union" stays a noun.
    func lexicalClass(at index: Int, tags: [UInt8], printed: [Substring]) -> LexicalClass {
        let lexicalClass = model.lexicalClass(at: index, tags: tags, tokens: printed)
        guard lexicalClass == .noun, ["NNP", "NNPS"].contains(model.tags[Int(tags[index])]), index + 1 < tags.count,
              ["NN", "NNS"].contains(model.tags[Int(tags[index + 1])]),
              printed[index + 1].unicodeScalars.first?.properties.isLowercase == true,
              lemmatizer.lists[.adjective]?.lemmas.contains(printed[index].lowercased()) == true else { return lexicalClass }
        return .adjective
    }
}
