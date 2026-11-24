// The model and the lists this module carries (S29c): each read and held to its recorded digest, the
// family's identity made from both, the self-test's digest the one committed, which the smoke test holds
// the image's binary to on each architecture, and the tagger reading FRUS's English as a tagger should.

@testable import FRUSLanguage
import Foundation
import Testing

@Suite struct EmbeddedLanguageTests {
    /// The repository's root, found above this file, which a scratch package may reach through a link.
    static let root: URL = {
        var folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while folder.path != "/" {
            if FileManager.default.fileExists(atPath: folder.appendingPathComponent("fixtures/language").path) { return folder }
            folder.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }()

    /// `fixtures/language/selftest.sha256`'s digest: its first field.
    static func committedDigest() throws -> String {
        let text = try String(contentsOf: root.appendingPathComponent("fixtures/language/selftest.sha256"), encoding: .utf8)
        return String(text.split(whereSeparator: { $0 == " " || $0 == "\n" }).first ?? "")
    }

    @Test func theModelAndTheListsReadAtTheirDigests() throws {
        let model = try EmbeddedModel.bytes()
        #expect(model.count == EmbeddedModel.byteCount)
        #expect(LanguageTagger.sha256(model) == EmbeddedModel.sha256)
        let lists = try EmbeddedWordNet.canonicalText()
        #expect(LanguageTagger.sha256(Array(lists.utf8)) == EmbeddedWordNet.sha256)
        let identity = LanguageTagger.shared.identity
        #expect(identity.modelSHA256 == EmbeddedModel.sha256 && identity.listsSHA256 == EmbeddedWordNet.sha256)
        #expect(identity.name == "FRUSLanguage")
        #expect(identity.version == "\(LanguageTagger.rulesVersion)+\(EmbeddedModel.sha256.prefix(8)).\(EmbeddedWordNet.sha256.prefix(8))")
    }

    @Test func theSelftestsDigestIsTheOneCommitted() throws {
        let digest = LanguageSelftest.digest(LanguageTagger.shared)
        #expect(digest == (try Self.committedDigest()), "fixtures/language/selftest.sha256: frus-light language-selftest prints the new digest\n\(LanguageSelftest.lines(LanguageTagger.shared).joined(separator: "\n"))")
    }

    @Test func everyTagHasAClassAndTheLensesClassesAreThere() {
        let model = LanguageTagger.shared.model
        #expect(model.tags.count == model.tagClasses.count)
        for name in ["NN", "NNS", "NNP", "VB", "VBD", "VBZ", "JJ", "RB", "DT", "IN", "TO", "CD", "PRP", "."] {
            #expect(model.tags.contains(name), "the model knows \(name)")
        }
        #expect(Set(model.tagClasses.map(\.lensClass)) == Set(LexicalClass.LensClass.allCases))
    }

    @Test func theProvenanceNamesTheTextsAndTheirLicences() {
        #expect(LanguageData.modelProvenance.contains("MASC 3.0.0"))
        #expect(LanguageData.modelProvenance.contains("Creative Commons Attribution 3.0 United States"))
        #expect(LanguageData.listsProvenance.contains("WordNet 3.0"))
        #expect(LanguageData.listsProvenance.contains("https://wordnet.princeton.edu/license-and-commercial-use"))
    }

    /// FRUS's English, read as a tagger should: what the lenses keep, and the lemmas a cloud counts.
    @Test func itReadsFRUSsEnglish() {
        let text = "The Secretary of State met the Soviet Ambassador on October 26, 1962, and the negotiations continued."
        let words = LanguageTagger.shared.tagged(text)
        let read = Dictionary(words.map { (String(text[$0.range]), $0) }, uniquingKeysWith: { first, _ in first })
        #expect(read["Secretary"]?.lexicalClass == .noun)
        #expect(read["met"]?.lexicalClass == .verb)
        #expect(read["met"]?.lemma == "meet")
        #expect(read["negotiations"]?.lexicalClass == .noun)
        #expect(read["negotiations"]?.lemma == "negotiation")
        #expect(read["continued"]?.lemma == "continue")
        #expect(read["the"]?.lexicalClass == .determiner)
        #expect(read["1962"]?.lexicalClass == .number)
        #expect(read["1962"]?.lemma == nil)
    }
}
