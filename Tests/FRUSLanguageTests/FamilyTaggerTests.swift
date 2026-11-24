// The family's adapter to WordCloudKit (PLAN's S29d): the web's tagger as the kit's tokenizers read a host's tagger,
// its walk the tagger's own under each reading the kit asks for, its identity and health the family's; the kit's
// tokenizer counting with it; and the app's generator run with it over the three fixture volumes, as
// scripts/make-language runs it over the corpus, twice to the same bytes, every file naming the family.

import CloudVectorsGeneratorCore
import FRUSLanguage
import Foundation
import Testing
import WordCloudKit

@Suite struct FamilyTaggerTests {
    static let tagger = FRUSWordCloudTagger()
    static let text = "The Secretary negotiated the treaties. The delegations signed the agreements; a dangerous crisis passed. "
        + "Mr. Rusk\u{2019}s telegram warned of Soviet intentions."

    /// A walk of the adapter under `reading`, word by word: the word, its lemma and its class.
    static func walk(_ reading: WordCloudTagReading) -> [String] {
        var seen: [String] = []
        tagger.enumerateWords(in: text, reading: reading) { range, lemma, lexicalClass in
            seen.append("\(text[range]) \(lemma ?? "-") \(reading.contains(.lexicalClasses) ? "\(lexicalClass().map { "\($0)" } ?? "-")" : "")")
            return true
        }
        return seen
    }

    /// The same walk of the tagger itself, its classes in the lenses' four.
    static func taggers(_ reading: LanguageReading) -> [String] {
        var seen: [String] = []
        LanguageTagger.shared.enumerateWords(in: text, reading: reading) { range, lemma, lexicalClass in
            seen.append("\(text[range]) \(lemma ?? "-") \(reading.contains(.lexicalClasses) ? "\(lexicalClass().map { "\(WordCloudLexicalClass($0.lensClass))" } ?? "-")" : "")")
            return true
        }
        return seen
    }

    @Test func itsWalkIsTheTaggersUnderEachReading() {
        let readings: [(WordCloudTagReading, LanguageReading)] = [
            ([], []), ([.lemmas], [.lemmas]), ([.lexicalClasses], [.lexicalClasses]),
            ([.lemmas, .lexicalClasses], [.lemmas, .lexicalClasses]),
        ]
        for (kit, family) in readings {
            #expect(Self.walk(kit) == Self.taggers(family), "\(kit)")
        }
        let full = Self.walk([.lemmas, .lexicalClasses])
        #expect(full.contains("negotiated negotiate verb") && full.contains("treaties treaty noun") && full.contains("dangerous dangerous adjective"),
                "\(full)")
        #expect(Self.walk([]).allSatisfy { $0.hasSuffix(" - ") }, "a walk that reads nothing gives no lemma")
        #expect(Self.walk([.lexicalClasses]).allSatisfy { $0.split(separator: " ")[1] == "-" }, "a walk that reads no lemma gives none")
        #expect(Self.walk([]).map { $0.split(separator: " ")[0] } == Self.walk([.lemmas, .lexicalClasses]).map { $0.split(separator: " ")[0] },
                "every reading walks the same words")
        // A reading the kit may add later is not read as one of the two.
        #expect(LanguageReading(WordCloudTagReading(rawValue: 1 << 5)) == [])
        #expect(WordCloudLexicalClass.allCases.count == LexicalClass.LensClass.allCases.count)
    }

    @Test func itStopsWhenTold() {
        var count = 0
        Self.tagger.enumerateWords(in: Self.text, reading: [.lemmas, .lexicalClasses]) { _, _, _ in
            count += 1
            return count < 3
        }
        #expect(count == 3)
        count = 0
        Self.tagger.enumerateNames(in: Self.text) { _, _ in
            count += 1
            return count < 2
        }
        #expect(count == 2)
    }

    @Test func itNamesNoOne() {
        var names: [String] = []
        Self.tagger.enumerateNames(in: Self.text) { range, type in
            #expect(type == nil)
            names.append(String(Self.text[range]))
            return true
        }
        #expect(names == Self.walk([]).map { String($0.split(separator: " ")[0]) })
    }

    @Test func itsIdentityAndHealthAreTheFamilys() {
        let identity = LanguageTagger.shared.identity
        #expect(Self.tagger.identity == WordCloudTokenizerIdentity(name: "FRUSLanguage", version: identity.version))
        #expect(Self.tagger.identity.description == "FRUSLanguage \(identity.version)" && identity.version.hasPrefix("\(LanguageTagger.rulesVersion)+"))
        #expect(Self.tagger.identity != .naturalLanguage && Self.tagger.identity != .legacyNaturalLanguage)
        #expect(Self.tagger.health == NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false))
        #expect(Self.tagger.health.supports(.topics) && Self.tagger.health.supports(.allTerms) && !Self.tagger.health.supports(.people))
        #expect(Self.tagger.health.wordForm == .dictionary)
    }

    /// The kit's one pass counts with the adapter by the kit's rules: lemmas, the lenses' classes, the stop lists.
    @Test func theKitsTokenizerCountsWithIt() throws {
        let tokenizer = try #require(WordCloudMultiLensTokenizer(
            lenses: CloudVectorsRunner.baselineLenses, tuning: .standard, stopwords: ["the", "of"],
            lexicons: WordCloudLexiconSet(payload: .init(concepts: ["treaty", "crisis"], sentimentPositive: ["agreement"],
                                                         sentimentNegative: ["crisis", "dangerous"])),
            markings: []))
        var counts: [WordCloudLens: [String: Int]] = [:]
        var printed: [WordCloudLens: [String: Int]] = [:]
        tokenizer.accumulate(from: Self.text, into: &counts, printedInto: &printed, tagger: Self.tagger)
        #expect(counts[.topics]?["treaty"] == 1 && counts[.topics]?["delegation"] == 1 && counts[.topics]?["secretary"] == 1, "\(counts[.topics] ?? [:])")
        #expect(counts[.actions]?["negotiate"] == 1 && counts[.actions]?["sign"] == 1, "\(counts[.actions] ?? [:])")
        #expect(counts[.descriptors]?["dangerous"] == 1, "\(counts[.descriptors] ?? [:])")
        #expect(counts[.concepts] == ["treaty": 1, "crisis": 1] && counts[.sentiment] == ["agreement": 1, "crisis": 1, "dangerous": 1])
        #expect(counts[.allTerms]?["the"] == nil && counts[.allTerms]?["negotiate"] == 1)
        #expect(printed[.actions]?["negotiated"] == 1 && printed[.actions]?["negotiate"] == nil, "the printed tally reads no lemma")
    }

    /// The app's generator, with the web's tagger and the six lenses, over the three fixture volumes: the four files and
    /// the provenance, twice to the same bytes, the first with the verification walks, which hold the printed tally to
    /// walks that read no lemma; every file names the family.
    @Test func theGeneratorRunsWithItToTheSameBytes() throws {
        let root = EmbeddedLanguageTests.root
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("FamilyTaggerTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let resources = root.appendingPathComponent("upstream/FRUS-Explorer/FRUSExplorer/Resources")
        let inputs = ["manifest.json", "word-cloud-lexicons.json", "word-cloud-stopwords.json"].map { resources.appendingPathComponent($0) }
        func run(_ name: String, verify: Bool) throws -> URL {
            let out = scratch.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            var environment = ["VOLUMES_DIR": root.appendingPathComponent("fixtures/tei").path, "MANIFEST": inputs[0].path,
                               "LEXICONS": inputs[1].path, "STOPWORDS": inputs[2].path, "OUTPUT_DIR": out.path,
                               "GENERATED_DATE": "2026-11-24"]
            if verify { environment["VERIFY_PRINTED_WALK"] = "1" }
            try CloudVectorsRunner.run(tagger: Self.tagger, cloudLenses: CloudVectorsRunner.baselineLenses, environment: environment)
            let provenance = try LanguageFamily.provenance(of: out, family: LanguageTagger.shared.identity, repository: "https://example.org/corpus",
                                                           commit: String(repeating: "0", count: 40), upstream: "pin", inputs: inputs)
            try LanguageFamily.encoded(provenance).write(to: out.appendingPathComponent(LanguageFamily.provenanceFileName))
            return out
        }
        let first = try run("first", verify: true)
        let second = try run("second", verify: false)
        for name in LanguageFamily.fileNames + [LanguageFamily.provenanceFileName] {
            let a = try Data(contentsOf: first.appendingPathComponent(name)), b = try Data(contentsOf: second.appendingPathComponent(name))
            #expect(!a.isEmpty && a == b, "\(name): the same bytes")
        }
        let family = Self.tagger.identity
        for name in LanguageFamily.fileNames.prefix(2) {
            let file = try CloudVectorsFile(contentsOf: first.appendingPathComponent(name))
            #expect(file.provenance.tokenizer == family && file.lenses == CloudVectorsRunner.baselineLenses.map(\.rawValue), "\(name)")
            #expect(file.provenance.volumeCount == 3 && file.provenance.tuning == .standard, "\(name)")
        }
        let volumes = try CloudVectorsFile(contentsOf: first.appendingPathComponent(LanguageFamily.fileNames[1]))
        #expect(Set(volumes.scopes.keys) == ["frus1894Nicaragua", "frus1961-63v06", "frus1969-76ve09p1"])
        for (name, form) in [(LanguageFamily.fileNames[2], WordCloudWordForm.dictionary), (LanguageFamily.fileNames[3], .printed)] {
            let reference = try KeynessBaselineFile(contentsOf: first.appendingPathComponent(name))
            #expect(reference.configuration.tokenizer == family && reference.configuration.wordForm == form, "\(name)")
            #expect(Set(reference.lenses.keys) == Set(CloudVectorsRunner.baselineLenses.map(\.rawValue)), "\(name): the six lenses priced")
            #expect(reference.configuration.mismatches(against: .standard, includeDiplomatic: true, lexiconsDigest: reference.configuration.lexiconsDigest,
                                                       stopwordsDigest: reference.configuration.stopwordsDigest, tokenizer: family).isEmpty)
            #expect(reference.configuration.mismatches(against: .standard, includeDiplomatic: true, lexiconsDigest: reference.configuration.lexiconsDigest,
                                                       stopwordsDigest: reference.configuration.stopwordsDigest, tokenizer: .naturalLanguage) == [.tokenizer],
                    "\(name): a scope another tokenizer counted is refused")
        }
        let provenance = try LanguageFamily.provenance(in: first)
        #expect(provenance.family == LanguageTagger.shared.identity && provenance.corpus.volumes == 3 && provenance.generated == "2026-11-24")
        #expect(provenance.files.map(\.name) == LanguageFamily.fileNames && provenance.inputs.map(\.name) == inputs.map(\.lastPathComponent))
        #expect(provenance.lenses == CloudVectorsRunner.baselineLenses.map(\.rawValue))
    }
}
