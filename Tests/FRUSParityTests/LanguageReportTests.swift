// The web tagger against the Mac's over the fixtures (PLAN's S29c): the report over the golden tags, which
// holds each document's body text to the one the Mac tagged and so fails when the inputs differ, and prints
// the agreement, which SPEC asks no parity of. The codec of the golden file's words reads back what it writes.

import FRUSLanguage
@testable import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct LanguageReportTests {
    @Test func theReportOverTheMacsTags() async throws {
        let status = try GoldenStatus(directory: Repository.layout.golden)
        guard status.isPresent(.languageTags) else {
            Issue.record("\(GoldenFile.languageTags.rawValue) is made from the app's source alone and must be committed: run scripts/make-golden")
            return
        }
        let golden = try GoldenJSON.read(LanguageTagsGolden.self, from: status.url(.languageTags))
        let built = try await FixtureIndex.value()
        let documents = try await LanguageComparison.documents(golden: golden, pipeline: built.index.pipeline)
        #expect(documents.count == golden.documents.count)
        let report = LanguageComparison.report(documents: documents, golden: golden, tagger: LanguageTagger.shared)
        #expect(report.words.mac > 0 && report.words.both > 0 && report.classes.words == report.words.both)
        print(report.text)
    }

    @Test func theWordsCodecReadsBackWhatItWrites() throws {
        let text = "The Department\u{2019}s view, as DEPTEL 1234 said, was \u{201C}firm,\u{201D} 100%."
        let words = [
            LanguageWord(start: 0, length: 3, lexicalClass: "Determiner", lemma: "the"),
            LanguageWord(start: 4, length: 10, lexicalClass: "Noun", lemma: "Department"),
            LanguageWord(start: 14, length: 2, lexicalClass: "Particle", lemma: nil),
            LanguageWord(start: 17, length: 4, lexicalClass: "Noun", lemma: "view"),
            LanguageWord(start: 23, length: 2, lexicalClass: "Preposition", lemma: "as"),
            LanguageWord(start: 26, length: 6, lexicalClass: nil, lemma: "deptel, a=b ~%"),
            LanguageWord(start: 33, length: 4, lexicalClass: "Classifier", lemma: "1234"),
            LanguageWord(start: 38, length: 4, lexicalClass: "Verb", lemma: "be"),
            LanguageWord(start: 44, length: 4, lexicalClass: "SomethingNew", lemma: "="),
        ]
        let line = LanguageWordCodec.encode(words, text: text)
        #expect(line.hasPrefix("0,3,D,~ 1,10,N,= 0,2,T 1,4,N,= 2,2,I,= 1,6,-,deptel%2C%20a%3Db%20%7E%25 1,4,L,= 1,4,V,be 2,4,*SomethingNew,%3D"))
        #expect(try LanguageWordCodec.decode(line, text: text) == words)
        #expect(throws: GoldenError.self) { try LanguageWordCodec.decode("0,999,N", text: text) }
        #expect(throws: GoldenError.self) { try LanguageWordCodec.decode("0,3,Q", text: text) }
    }

    @Test func theCountedForm() {
        #expect(LanguageComparison.countedForm(lemma: "Treaty", printed: "Treaties") == "treaty")
        #expect(LanguageComparison.countedForm(lemma: nil, printed: "Treaties") == "treaty", "the kit's plural fold")
        #expect(LanguageComparison.countedForm(lemma: "", printed: "Documents") == "document")
        #expect(LanguageComparison.countedForm(lemma: "O\u{2019}Brien", printed: "O\u{2019}Brien") == "o'brien")
        #expect(LanguageComparison.lensClass("Adjective") == "adjective" && LanguageComparison.lensClass("Adverb") == "other")
    }
}
