// The averaged perceptron (S29c): training on a small text of the suite's own, its integer arithmetic
// and determinism, its tie-breaking, the class rules and its file.

@testable import FRUSLanguage
import Testing

@Suite struct PerceptronTests {
    static let tags = [".", "DT", "IN", "JJ", "NN", "NNP", "TO", "VB", "VBD", "CD"]
    static let classes: [LexicalClass] = [.sentenceTerminator, .determiner, .preposition, .adjective, .noun, .noun,
                                          .preposition, .verb, .verb, .number]

    /// A small tagged text: sentences of the patterns a tagger learns from context and suffixes.
    static var lines: [TrainingLine] {
        let sentences: [[(String, String)]] = [
            [("The", "DT"), ("ambassador", "NN"), ("signed", "VBD"), ("the", "DT"), ("treaty", "NN"), (".", ".")],
            [("The", "DT"), ("minister", "NN"), ("rejected", "VBD"), ("a", "DT"), ("proposal", "NN"), (".", ".")],
            [("A", "DT"), ("secretary", "NN"), ("visited", "VBD"), ("the", "DT"), ("embassy", "NN"), ("in", "IN"), ("Managua", "NNP"), (".", ".")],
            [("The", "DT"), ("new", "JJ"), ("treaty", "NN"), ("failed", "VBD"), ("in", "IN"), ("1962", "CD"), (".", ".")],
            [("Rusk", "NNP"), ("wanted", "VBD"), ("to", "TO"), ("sign", "VB"), ("the", "DT"), ("old", "JJ"), ("treaty", "NN"), (".", ".")],
            [("Dobrynin", "NNP"), ("went", "VBD"), ("to", "TO"), ("Moscow", "NNP"), ("in", "IN"), ("1963", "CD"), (".", ".")],
            [("The", "DT"), ("good", "JJ"), ("minister", "NN"), ("hoped", "VBD"), ("to", "TO"), ("visit", "VB"), ("Washington", "NNP"), (".", ".")],
            [("A", "DT"), ("long", "JJ"), ("telegram", "NN"), ("reached", "VBD"), ("the", "DT"), ("department", "NN"), (".", ".")],
        ]
        let place = Dictionary(uniqueKeysWithValues: tags.enumerated().map { ($0.element, UInt8($0.offset)) })
        return sentences.map { sentence in
            TrainingLine(tokens: sentence.map { Substring($0.0) }, tags: sentence.map { place[$0.1]! })
        }
    }

    static func trained(seed: UInt64 = 7, passes: Int = 8) -> PerceptronModel {
        var trainer = PerceptronTrainer(tags: tags, tagClasses: classes)
        trainer.train(lines, passes: passes, seed: seed)
        return trainer.model()
    }

    static func tagNames(_ model: PerceptronModel, _ words: [Substring]) -> [String] {
        model.tag(line: words).map { model.tags[Int($0)] }
    }

    @Test func itLearnsItsText() {
        let model = Self.trained()
        for line in Self.lines {
            #expect(model.tag(line: line.tokens) == line.tags, "\(line.tokens.joined(separator: " "))")
        }
    }

    @Test func itTagsANewSentenceByItsContext() {
        let model = Self.trained()
        #expect(Self.tagNames(model, ["The", "minister", "visited", "the", "department", "."]) == ["DT", "NN", "VBD", "DT", "NN", "."])
        #expect(Self.tagNames(model, ["A", "secretary", "rejected", "the", "treaty", "in", "1964", "."]) ==
                ["DT", "NN", "VBD", "DT", "NN", "IN", "CD", "."], "a year it never saw, by its shape")
    }

    @Test func theSameTextAndSeedMakeTheSameModel() {
        let first = Self.trained(seed: 42).encoded()
        #expect(first == Self.trained(seed: 42).encoded())
        #expect(LanguageTagger.sha256(first) == LanguageTagger.sha256(Self.trained(seed: 42).encoded()))
    }

    @Test func theFileReadsBack() throws {
        let model = Self.trained()
        let bytes = model.encoded()
        #expect(Array(bytes.prefix(8)) == Array("FRUSPTG".utf8) + [1])
        let read = try PerceptronModel(decoding: bytes)
        #expect(read == model)
        #expect(read.encoded() == bytes)
        #expect(read.featureCount > 0 && read.weightCount >= read.featureCount)
    }

    @Test func aBrokenFileIsRefused() {
        let bytes = Self.trained().encoded()
        #expect(throws: PerceptronModelError.self) { try PerceptronModel(decoding: Array(bytes.dropLast())) }
        #expect(throws: PerceptronModelError.self) { try PerceptronModel(decoding: bytes + [0]) }
        var otherVersion = bytes
        otherVersion[7] = 2
        #expect(throws: PerceptronModelError.self) { try PerceptronModel(decoding: otherVersion) }
        #expect(throws: PerceptronModelError.self) { try PerceptronModel(decoding: []) }
    }

    @Test func aTieGoesToTheTagThatComesFirst() {
        let untrained = PerceptronTrainer(tags: Self.tags, tagClasses: Self.classes).model()
        #expect(untrained.tag(line: ["anything", "at", "all"]) == [0, 0, 0])
    }

    @Test func weightsAreAveragedInThousandths() {
        // One wrong guess on the first of four steps: a weight counts from the step after it changed, as in
        // Honnibal's tagger, so the truth's weight of 1 counts for 3 of the 4 steps, an average of 750
        // thousandths, and the guess's -750.
        var trainer = PerceptronTrainer(tags: ["A", "B"], tagClasses: [.noun, .verb])
        let keys = [UInt32](repeating: 9, count: 1)
        trainer.update(truth: 1, guess: 0, keys: keys)
        trainer.update(truth: 1, guess: 1, keys: keys)
        trainer.update(truth: 1, guess: 1, keys: keys)
        trainer.update(truth: 1, guess: 1, keys: keys)
        let model = trainer.model()
        #expect(model.features[9] != nil)
        let span = model.features[9]!
        let first = Int(span >> 8), count = Int(span & 0xFF)
        #expect(Array(zip(model.weightTags[first..<first + count], model.weightValues[first..<first + count])).map { "\($0.0):\($0.1)" } == ["0:-750", "1:750"])
    }

    @Test func theDictionaryHoldsWordsAlwaysTaggedOneWay() {
        var trainer = PerceptronTrainer(tags: ["DT", "NN"], tagClasses: [.determiner, .noun])
        let line = TrainingLine(tokens: ["the", "treaty"], tags: [0, 1])
        let rare = TrainingLine(tokens: ["once"], tags: [1])
        trainer.makeDictionary(Array(repeating: line, count: 20) + [rare])
        #expect(trainer.dictionary[FeatureHash.fold(FeatureHash.fnv("the"))] == 0)
        #expect(trainer.dictionary[FeatureHash.fold(FeatureHash.fnv("treaty"))] == 1)
        #expect(trainer.dictionary[FeatureHash.fold(FeatureHash.fnv("once"))] == nil, "seen once")
        var mixed = PerceptronTrainer(tags: ["DT", "NN"], tagClasses: [.determiner, .noun])
        mixed.makeDictionary(Array(repeating: TrainingLine(tokens: ["that"], tags: [0]), count: 95)
                             + Array(repeating: TrainingLine(tokens: ["that"], tags: [1]), count: 5))
        #expect(mixed.dictionary.isEmpty, "95 in 100 is under 97")
    }

    @Test func theClassRules() {
        let model = Self.trained()
        let words: [Substring] = ["to", "sign", "to", "Moscow", "1,500", "1962", "3.5"]
        let place = Dictionary(uniqueKeysWithValues: Self.tags.enumerated().map { ($0.element, UInt8($0.offset)) })
        let tags = ["TO", "VB", "TO", "NNP", "CD", "CD", "CD"].map { place[$0]! }
        #expect(words.indices.map { model.lexicalClass(at: $0, tags: tags, tokens: words) } ==
                [.particle, .verb, .preposition, .noun, .otherWord, .number, .otherWord])
    }

    @Test func splitMixIsSteeleLeaAndFloods() {
        var random = SplitMix64(seed: 0)
        #expect(random.next() == 0xE220_A839_7B1D_CDAF)
        #expect(random.next() == 0x6E78_9E6A_A1B9_65F4)
        var values = Array(0..<10)
        var shuffler = SplitMix64(seed: 1)
        shuffler.shuffle(&values)
        var again = Array(0..<10)
        var second = SplitMix64(seed: 1)
        second.shuffle(&again)
        #expect(values == again)
        #expect(values.sorted() == Array(0..<10))
    }

    @Test func featureKeysAreFixedNumbers() {
        // The keys are integer arithmetic over FNV-1a, so these hold on every architecture.
        #expect(FeatureHash.fnv("") == 0xcbf2_9ce4_8422_2325)
        #expect(FeatureHash.fnv("a") == 0xaf63_dc4c_8601_ec8c)
        #expect(FeatureHash.key(1, 0) == FeatureHash.key(1, 0))
        #expect(FeatureHash.key(1, 0) != FeatureHash.key(2, 0))
        #expect(FeatureHash.key(4, 1, 2) != FeatureHash.key(4, 2, 1))
    }

    @Test func theShapes() {
        #expect(Shape("1962").fourDigits)
        #expect(LineFeatures.normalise("1962", shape: Shape("1962")) == "!YEAR")
        #expect(LineFeatures.normalise("1,500", shape: Shape("1,500")) == "!DIGITS")
        #expect(LineFeatures.normalise("anti-Communist", shape: Shape("anti-Communist")) == "!HYPHEN")
        #expect(LineFeatures.normalise("Treaty", shape: Shape("Treaty")) == "treaty")
        #expect(LineFeatures.normalise("-", shape: Shape("-")) == "-")
        #expect(Shape("SECRET").allCapitals && !Shape("Secret").allCapitals)
        #expect(Shape("SECRET").code != Shape("Secret").code)
        #expect(Shape("U.S.").code != Shape("US").code)
        #expect(LineFeatures.lastThree("ab") == "ab")
        #expect(LineFeatures.lastThree("treaty") == "aty")
    }
}
