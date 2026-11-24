// The family's walk and identity (S29c), over a tagger of the suite's own: the walk WordCloudKit's
// WordCloudTagger asks of a host's tagger, reading what it is asked to and stopping when told.

@testable import FRUSLanguage
import Testing

@Suite struct LanguageTaggerTests {
    static let tagger: LanguageTagger = {
        let model = PerceptronTests.trained()
        let lemmatizer = LemmatizerTests.lemmatizer
        let identity = LanguageIdentity(name: "Test", rulesVersion: 3, modelSHA256: LanguageTagger.sha256(model.encoded()),
                                        listsSHA256: String(repeating: "ab", count: 32))
        return LanguageTagger(model: model, lemmatizer: lemmatizer, identity: identity)
    }()

    static let text = "The minister visited the treaty\u{2019}s department.\nThe new treaty failed."

    @Test func aWalkThatReadsNothingOnlySplits() {
        var seen: [String] = []
        Self.tagger.enumerateWords(in: Self.text, reading: []) { range, lemma, lexicalClass in
            #expect(lemma == nil)
            #expect(lexicalClass() == nil)
            seen.append(String(Self.text[range]))
            return true
        }
        #expect(seen == ["The", "minister", "visited", "the", "treaty", "\u{2019}s", "department", "The", "new", "treaty", "failed"])
    }

    @Test func aWalkReadsLemmasAndClasses() {
        var seen: [String] = []
        Self.tagger.enumerateWords(in: Self.text, reading: [.lemmas, .lexicalClasses]) { range, lemma, lexicalClass in
            // The suite's model never saw a clitic, so its class is the model's guess; its lemma is the rule's.
            let word = String(Self.text[range])
            seen.append(word == "\u{2019}s" ? "\(word)/?/\(lemma ?? "-")" : "\(word)/\(lexicalClass()?.rawValue ?? "-")/\(lemma ?? "-")")
            return true
        }
        #expect(seen == ["The/Determiner/the", "minister/Noun/-", "visited/Verb/visit", "the/Determiner/the", "treaty/Noun/treaty",
                         "\u{2019}s/?/-", "department/Noun/-", "The/Determiner/the", "new/Adjective/-", "treaty/Noun/treaty",
                         "failed/Verb/-"])
    }

    @Test func aWalkThatReadsNoLemmasGivesNone() {
        Self.tagger.enumerateWords(in: Self.text, reading: [.lexicalClasses]) { _, lemma, lexicalClass in
            #expect(lemma == nil)
            #expect(lexicalClass() != nil)
            return true
        }
    }

    @Test func aWalkStopsWhenTold() {
        for reading: LanguageReading in [[], [.lemmas]] {
            var count = 0
            Self.tagger.enumerateWords(in: Self.text, reading: reading) { _, _, _ in
                count += 1
                return count < 3
            }
            #expect(count == 3)
        }
    }

    @Test func taggedGivesEveryWord() {
        let words = Self.tagger.tagged(Self.text)
        #expect(words.map { String(Self.text[$0.range]) } == WordSplitter.words(in: Self.text).map { String(Self.text[$0]) })
        #expect(words.first?.tag == "DT")
        #expect(words.map(\.lexicalClass) == words.map(\.lexicalClass).filter(\.isWordClass), "punctuation is never reported")
    }

    @Test func eachLineIsTaggedApart() {
        // A line's first word is tagged after the line's start, not the last line's last word: the same
        // line alone or after another tags the same.
        let alone = Self.tagger.tagged("The new treaty failed.").map(\.tag)
        let after = Self.tagger.tagged("Rusk wanted to sign\nThe new treaty failed.").map(\.tag).suffix(alone.count)
        #expect(Array(after) == alone)
    }

    @Test func theIdentity() {
        let identity = LanguageIdentity(name: "FRUSLanguage", rulesVersion: 1, modelSHA256: "0123456789abcdef" + String(repeating: "0", count: 48),
                                        listsSHA256: "fedcba9876543210" + String(repeating: "0", count: 48))
        #expect(identity.version == "1+01234567.fedcba98")
        #expect(identity.description == "FRUSLanguage 1+01234567.fedcba98")
        #expect(LanguageTagger.sha256([]) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test func itNamesNoOne() {
        #expect(Self.tagger.lemmatizes && Self.tagger.classifiesWords && !Self.tagger.recognizesNames)
    }

    @Test func theLensesClasses() {
        #expect(LexicalClass.allCases.filter { $0.lensClass != .other } == [.noun, .verb, .adjective])
        #expect(LexicalClass.noun.rawValue == "Noun" && LexicalClass.otherWord.rawValue == "OtherWord")
        #expect(LanguageReading.lemmas.rawValue == 1 && LanguageReading.lexicalClasses.rawValue == 2, "WordCloudTagReading's bits")
    }
}
