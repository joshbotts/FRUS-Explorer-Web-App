// The lemmatizer's rules (S29c), over lists of the suite's own, each rule of morph.c's morphy and the
// clitics' and closed classes' lemmas.

@testable import FRUSLanguage
import Testing

@Suite struct LemmatizerTests {
    static let lemmatizer = Lemmatizer(lists: [
        .noun: WordNetPartLists(
            exceptions: ["children": ["child"], "axes": ["axis", "axe"]],
            lemmas: ["treaty", "relation", "relations", "box", "boxful", "church", "woman", "glass", "ox", "state", "lao",
                     "kennedy", "handful", "means", "mean", "news"]),
        .verb: WordNetPartLists(
            exceptions: ["went": ["go"], "is": ["be"], "hopped": ["hop"]],
            lemmas: ["hope", "hop", "visit", "negotiate", "agree", "be", "go", "die", "use", "state"]),
        .adjective: WordNetPartLists(exceptions: ["better": ["good"]], lemmas: ["large", "great", "good", "big"]),
        .adverb: WordNetPartLists(exceptions: ["better": ["well"]], lemmas: ["quickly", "well", "not"]),
    ])

    static func lemma(_ word: Substring, _ lexicalClass: LexicalClass) -> String? {
        lemmatizer.lemma(of: word, as: lexicalClass)
    }

    @Test func nouns() {
        #expect(Self.lemma("children", .noun) == "child", "an exception")
        #expect(Self.lemma("axes", .noun) == "axis", "an exception's first base")
        #expect(Self.lemma("treaties", .noun) == "treaty", "ies to y")
        #expect(Self.lemma("relations", .noun) == "relation", "a rule before the word itself, as morph.c tries them")
        #expect(Self.lemma("boxes", .noun) == "box", "xes to x, once s alone makes no word")
        #expect(Self.lemma("churches", .noun) == "church")
        #expect(Self.lemma("women", .noun) == "woman", "men to man")
        #expect(Self.lemma("glass", .noun) == "glass", "a noun in ss is its own lemma")
        #expect(Self.lemma("ox", .noun) == "ox", "two letters")
        #expect(Self.lemma("boxesful", .noun) == "boxful", "ful taken off and put back")
        #expect(Self.lemma("handful", .noun) == "handful")
        #expect(Self.lemma("States", .noun) == "state", "a name in capitals, lowercased")
        #expect(Self.lemma("Laos", .noun) == "lao", "as NaturalLanguage gives it")
        #expect(Self.lemma("Kennedy", .noun) == "kennedy")
        #expect(Self.lemma("Zelaya", .noun) == nil, "a name WordNet does not know has none")
        #expect(Self.lemma("news", .noun) == "news")
    }

    @Test func verbs() {
        #expect(Self.lemma("went", .verb) == "go")
        #expect(Self.lemma("is", .verb) == "be")
        #expect(Self.lemma("hoped", .verb) == "hope", "ed to e first")
        #expect(Self.lemma("hopped", .verb) == "hop", "a doubled consonant is an exception")
        #expect(Self.lemma("visited", .verb) == "visit", "ed, once ed to e makes no word")
        #expect(Self.lemma("negotiating", .verb) == "negotiate")
        #expect(Self.lemma("dies", .verb) == "die", "s alone, the first rule")
        #expect(Self.lemma("Agreed", .verb) == "agree")
        #expect(Self.lemma("stated", .verb) == "state")
        #expect(Self.lemma("frobbed", .verb) == nil)
    }

    @Test func adjectivesAndAdverbs() {
        #expect(Self.lemma("larger", .adjective) == "large", "er to e, once er alone makes no word")
        #expect(Self.lemma("greatest", .adjective) == "great")
        #expect(Self.lemma("better", .adjective) == "good")
        #expect(Self.lemma("better", .adverb) == "well")
        #expect(Self.lemma("quickly", .adverb) == "quickly")
        #expect(Self.lemma("quicklier", .adverb) == nil, "an adverb has no rule but its exceptions")
    }

    @Test func wordsWithPeriodsOrDigits() {
        #expect(Self.lemma("U.S.", .noun) == nil)
        #expect(Self.lemma("1960s", .noun) == nil)
        #expect(Self.lemma("B52s", .noun) == nil)
    }

    @Test func clitics() {
        #expect(Self.lemma("n't", .adverb) == "not")
        #expect(Self.lemma("N'T", .adverb) == "not")
        #expect(Self.lemma("n\u{2019}t", .adverb) == "not")
        #expect(Self.lemma("'re", .verb) == "be")
        #expect(Self.lemma("\u{2019}ve", .verb) == "have")
        #expect(Self.lemma("'ll", .verb) == "will")
        #expect(Self.lemma("'m", .verb) == "be")
        #expect(Self.lemma("'d", .verb) == "have")
        #expect(Self.lemma("'s", .particle) == nil)
        #expect(Self.lemma("\u{2019}s", .verb) == nil)
    }

    @Test func otherClasses() {
        #expect(Self.lemma("The", .determiner) == "the")
        #expect(Self.lemma("they", .pronoun) == "they")
        #expect(Self.lemma("of", .preposition) == "of")
        #expect(Self.lemma("and", .conjunction) == "and")
        #expect(Self.lemma("up", .particle) == "up")
        #expect(Self.lemma("Yes", .interjection) == "yes")
        #expect(Self.lemma("two", .number) == "two")
        #expect(Self.lemma("1962", .number) == nil)
        #expect(Self.lemma("1,500", .otherWord) == nil)
        #expect(Self.lemma(".", .sentenceTerminator) == nil)
    }

    @Test func noListsNoLemmas() {
        let empty = Lemmatizer(lists: [:])
        #expect(empty.lemma(of: "treaties", as: .noun) == nil)
        #expect(empty.lemma(of: "the", as: .determiner) == "the")
    }
}

@Suite struct WordNetListsTests {
    static let lists: [WordNetPart: WordNetPartLists] = [
        .noun: WordNetPartLists(exceptions: ["children": ["child"], "axes": ["axis", "axe"]], lemmas: ["treaty", "child"]),
        .verb: WordNetPartLists(exceptions: ["went": ["go"]], lemmas: ["go"]),
        .adjective: WordNetPartLists(exceptions: [:], lemmas: ["large"]),
        .adverb: WordNetPartLists(exceptions: ["better": ["well"]], lemmas: []),
    ]

    @Test func canonicalTextReadsBack() throws {
        let text = WordNetLists.canonicalText(Self.lists)
        #expect(text == """
            # FRUSLanguage WordNet lists 1
            ## noun exceptions
            axes axis axe
            children child
            ## noun lemmas
            child
            treaty
            ## verb exceptions
            went go
            ## verb lemmas
            go
            ## adjective exceptions
            ## adjective lemmas
            large
            ## adverb exceptions
            better well
            ## adverb lemmas

            """)
        #expect(try WordNetLists.parse(canonicalText: text) == Self.lists)
    }

    @Test func malformedTextIsRefused() {
        let text = WordNetLists.canonicalText(Self.lists)
        #expect(throws: WordNetListsError.self) { try WordNetLists.parse(canonicalText: String(text.dropLast())) }
        #expect(throws: WordNetListsError.self) { try WordNetLists.parse(canonicalText: text.replacingOccurrences(of: "## verb lemmas\n", with: "")) }
        #expect(throws: WordNetListsError.self) { try WordNetLists.parse(canonicalText: "# another format\n") }
        #expect(throws: WordNetListsError.self) { try WordNetLists.parse(canonicalText: text.replacingOccurrences(of: "went go", with: "went")) }
    }

    @Test func wordNetsOwnFilesAreRead() throws {
        let manager = FileManager.default
        let dict = manager.temporaryDirectory.appendingPathComponent("wordnet-\(UUID().uuidString)")
        try manager.createDirectory(at: dict, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: dict) }
        let header = "  1 This software and database is being provided to you, the LICENSEE, by  \n  2 Princeton University under the following license.\n"
        let files = [
            "noun.exc": "attorneys_general attorney_general\nchildren child\nmen man\n",
            "index.noun": header + "child n 1 2 @ ~ 1 1 09917593  \ncivil_war n 1 1 @ 1 0 00973077  \ntreaty n 1 1 @ 1 1 06773434  \n",
            "verb.exc": "went go\n",
            "index.verb": header + "go v 30 5 @ ~ 30 13 01835496  \nlook_up v 1 1 @ 1 0 00668099  \n",
            "adj.exc": "better good well\n",
            "index.adj": header + "good a 21 5 ! & 21 1 01123148  \n",
            "adv.exc": "best well\n",
            "index.adv": header + "well r 13 3 ! 13 1 00011093  \n",
        ]
        for (name, content) in files { try content.write(to: dict.appendingPathComponent(name), atomically: true, encoding: .utf8) }
        let lists = try WordNetLists.read(dict: dict)
        #expect(lists[.noun]?.exceptions == ["children": ["child"], "men": ["man"]], "a collocation is left out")
        #expect(lists[.noun]?.lemmas == ["child", "treaty"], "the licence's lines and collocations are left out")
        #expect(lists[.verb]?.lemmas == ["go"])
        #expect(lists[.adjective]?.exceptions == ["better": ["good", "well"]])
        #expect(lists[.adverb]?.lemmas == ["well"])
    }
}

import Foundation
