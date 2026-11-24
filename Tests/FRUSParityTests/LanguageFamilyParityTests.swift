// The language family's files (PLAN's S29d): what resources/language holds is the family's, counted by the server's own
// tagger from the pinned catalogue with the pinned word lists, each file the one its provenance names; and the server
// refuses a file of another identity, as the kit's rule refuses a reference counted by another tokenizer. A test here
// fails when a pin move or a change of the tagger leaves the files stale, which is when scripts/make-language makes them
// again (COORDINATION §5's pin-move checklist): a new catalogue, new lexicons or stop words, or a new identity.

import FRUSCoreKit
import FRUSLanguage
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing
import WordCloudKit

@testable import FRUSLightAPI

@Suite struct LanguageFamilyParityTests {
    static let folder = RepositoryFiles.language
    static let resources = ServedFixture.resources
    /// The six lenses the generator counts, in its order (`CloudVectorsRunner.baselineLenses`): the cloud files carry
    /// them all, and the references price them.
    static let lenses = ["allTerms", "descriptors", "concepts", "topics", "actions", "sentiment"]

    static func core() throws -> CloudVectorsFile { try CloudVectorsFile(contentsOf: folder.appendingPathComponent("cloud-vectors-core.json")) }
    static func volumes() throws -> CloudVectorsFile { try CloudVectorsFile(contentsOf: folder.appendingPathComponent("cloud-vectors-volumes.json")) }
    static func reference(_ name: String, in directory: URL = folder) throws -> KeynessBaselineFile {
        try KeynessBaselineFile(contentsOf: directory.appendingPathComponent(name))
    }

    @Test func eachFileIsTheOneItsProvenanceNames() throws {
        let provenance = try LanguageFamily.provenance(in: Self.folder)
        #expect(provenance.files.map(\.name) == LanguageFamily.fileNames)
        for file in provenance.files {
            let bytes = [UInt8](try Data(contentsOf: Self.folder.appendingPathComponent(file.name)))
            #expect(bytes.count == file.bytes && LanguageTagger.sha256(bytes) == file.sha256, "\(file.name): scripts/make-language writes it with its provenance")
        }
        #expect(try LanguageFamily.encoded(provenance) == Data(contentsOf: Self.folder.appendingPathComponent(LanguageFamily.provenanceFileName)),
                "the provenance as frus-language clouds writes it")
        let core = try Self.core(), volumes = try Self.volumes()
        #expect(provenance.generated == core.generated && provenance.generated == volumes.generated)
        #expect(provenance.corpus.volumes == core.provenance.volumeCount && provenance.corpus.documents == core.provenance.documentCount)
        #expect(provenance.corpus.repository == "https://github.com/HistoryAtState/frus")
        #expect(provenance.corpus.commit.count == 40 && provenance.corpus.commit.allSatisfy(\.isHexDigit), "the corpus's commit, which a run counts again")
        #expect(provenance.lenses == Self.lenses && core.lenses == Self.lenses && volumes.lenses == Self.lenses, "the six lenses the references price")
        #expect(provenance.remake == LanguageFamily.remakeCommand(commit: provenance.corpus.commit, generated: provenance.generated)
                && provenance.remake.contains("--commit \(provenance.corpus.commit) --generated \(provenance.generated)"),
                "the command that makes them again names the commit and the day")
        for name in LanguageFamily.fileNames.suffix(2) {
            let reference = try Self.reference(name)
            #expect(reference.generated == core.generated && reference.provenance == core.provenance, "\(name): one run's")
            #expect(Set(reference.lenses.keys) == Set(Self.lenses), "\(name): the six lenses priced")
        }
    }

    /// The four files and their provenance name the server's own tagger; a new rule, model or list moves its identity, and
    /// the files are counted again.
    @Test func theyAreTheServersTaggers() throws {
        let identity = LanguageTagger.shared.identity
        let family = WordCloudTokenizerIdentity(name: "FRUSLanguage", version: identity.version)
        #expect(try LanguageFamily.provenance(in: Self.folder).family == identity, "scripts/make-language: the tagger changed")
        #expect(try Self.core().provenance.tokenizer == family && Self.volumes().provenance.tokenizer == family)
        #expect(try Self.reference("keyness-baseline.json").configuration.tokenizer == family)
        #expect(try Self.reference("keyness-baseline-printed.json").configuration.tokenizer == family)
        #expect(try Self.reference("keyness-baseline.json").configuration.wordForm == .dictionary)
        #expect(try Self.reference("keyness-baseline-printed.json").configuration.wordForm == .printed)
    }

    /// The files count the pinned catalogue: its volumes, each under its subseries, and no other.
    @Test func theyCountThePinnedCatalogue() throws {
        let manifest = Self.resources.appendingPathComponent("manifest.json")
        let catalogue = try FixedVolumeCatalogue(contentsOf: manifest).citableEntries
        #expect(try LanguageFamily.provenance(in: Self.folder).catalogue == LanguageFamily.catalogue(of: manifest),
                "scripts/make-language: the catalogue's volumes or subseries changed")
        let volumes = try Self.volumes(), core = try Self.core()
        #expect(Set(volumes.scopes.keys) == Set(catalogue.map(\.volumeId)) && volumes.scopes.count == catalogue.count)
        #expect(Set(core.scopes.keys) == Set(["corpus"] + catalogue.map(\.subseries)))
        #expect(core.provenance.volumeCount == catalogue.count && catalogue.count == 553)
    }

    /// The references were counted with the pinned lexicons and stop words, the files the server filters the clouds by.
    @Test func theyCountThePinnedWordLists() throws {
        let lexicons = try #require(WordCloudPayloadDigest.digest(ofFileAt: Self.resources.appendingPathComponent("word-cloud-lexicons.json")))
        let stopwords = try #require(WordCloudPayloadDigest.digest(ofFileAt: Self.resources.appendingPathComponent("word-cloud-stopwords.json")))
        for name in LanguageFamily.fileNames.suffix(2) {
            let configuration = try Self.reference(name).configuration
            #expect(configuration.lexiconsDigest == lexicons && configuration.stopwordsDigest == stopwords,
                    "\(name): scripts/make-language: the lexicons or stop words changed")
            #expect(configuration.tuning == .standard && configuration.includeDiplomatic == CloudRules.generatorIncludesDiplomatic)
        }
        let inputs = try LanguageFamily.provenance(in: Self.folder).inputs
        #expect(inputs.map(\.name) == ["manifest.json", "word-cloud-lexicons.json", "word-cloud-stopwords.json"])
        #expect(inputs[1].sha256 == lexicons && inputs[2].sha256 == stopwords)
    }

    /// A reference of another identity is refused: by the kit's rule, against a scope counted by another tokenizer, both
    /// ways; and by the server, which reads none of a family's files counted by another tokenizer, or a reference under
    /// the other form's name, and says why.
    @Test func aReferenceOfAnotherIdentityIsRefused() throws {
        let family = FamilyClouds.family
        let ours = try Self.reference("keyness-baseline.json").configuration
        let apps = try Self.reference("keyness-baseline.json", in: Self.resources).configuration
        #expect(apps.tokenizer == .legacyNaturalLanguage, "the app's bundled reference was counted by NaturalLanguage")
        func mismatches(_ reference: KeynessBaselineFile.Configuration, _ tokenizer: WordCloudTokenizerIdentity) -> [KeynessBaselineFile.Configuration.Mismatch] {
            reference.mismatches(against: .standard, includeDiplomatic: true, lexiconsDigest: reference.lexiconsDigest,
                                 stopwordsDigest: reference.stopwordsDigest, tokenizer: tokenizer)
        }
        #expect(mismatches(ours, family).isEmpty, "the family's reference prices the family's counts")
        #expect(mismatches(ours, .naturalLanguage) == [.tokenizer], "and refuses a scope NaturalLanguage counted")
        #expect(mismatches(apps, family) == [.tokenizer], "the app's reference refuses a scope the family counted")
        #expect(CloudRules.mismatchDescription(mismatches(apps, family)) == "the reference was counted by another tokenizer")

        // The server, over folders of its own: the app's four, which name no tokenizer, so NaturalLanguage's.
        let scratch = try TemporaryDirectory()
        defer { withExtendedLifetime(scratch) {} }
        func folder(_ name: String, _ files: [(from: URL, as: String)]) throws -> URL {
            let url = scratch.url.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            for file in files { try FileManager.default.copyItem(at: file.from, to: url.appendingPathComponent(file.as)) }
            return url
        }
        let apps4 = try folder("apps", LanguageFamily.fileNames.map { (Self.resources.appendingPathComponent($0), $0) })
        let refused = try ServerResources.load(from: Self.resources, language: apps4)
        let other = FamilyRefusal.otherTokenizer(.legacyNaturalLanguage)
        for result in [refused.familyClouds.core.value(in: apps4).map { _ in () }, refused.familyClouds.volumes.value(in: apps4).map { _ in () },
                       refused.familyClouds.reference(.dictionary, in: apps4).map { _ in () },
                       refused.familyClouds.reference(.printed, in: apps4).map { _ in () }] {
            #expect(result.error == other)
        }
        let corpus = WordCloudRoutes.answer(.corpus, lens: .topics, settings: .standard, resources: refused)
        #expect(corpus.state == "noCloud" && corpus.terms.isEmpty && corpus.message?.detail == other.sentence)
        #expect(other.sentence == "This server’s clouds were counted by another tokenizer, NaturalLanguage 1, not by its own tagger, \(family), so it shows none of them.")
        let volume = WordCloudRoutes.answer(.volume(volumeId: "frus1961-63v06", subseries: "1961-63"), lens: .concepts, settings: .standard, resources: refused)
        #expect(volume.state == "noCloud" && volume.message?.detail == other.sentence)
        #expect(WordCloudRoutes.context(resources: refused).made == nil, "no account of clouds it does not show")

        // The family's clouds with the app's reference beside them: the clouds served, that reference refused.
        let mixed = try folder("mixed", [(Self.folder.appendingPathComponent("cloud-vectors-core.json"), "cloud-vectors-core.json"),
                                         (Self.folder.appendingPathComponent("cloud-vectors-volumes.json"), "cloud-vectors-volumes.json"),
                                         (Self.resources.appendingPathComponent("keyness-baseline.json"), "keyness-baseline.json"),
                                         (Self.folder.appendingPathComponent("keyness-baseline.json"), "keyness-baseline-printed.json")])
        let served = try ServerResources.load(from: Self.resources, language: mixed)
        #expect(WordCloudRoutes.answer(.corpus, lens: .topics, settings: .standard, resources: served).state == "terms")
        #expect(served.familyClouds.reference(.dictionary, in: mixed).error == other)
        #expect(served.familyClouds.reference(.printed, in: mixed).error == .otherWordForm(.dictionary),
                "a reference under the other form's name is not read")
        #expect(try ServerResources.load(from: Self.resources, language: Self.folder).familyClouds.reference(.printed, in: Self.folder).error == nil)

        // A volume's scope reads the volumes file and, for its era, the core: the app's volumes file beside the family's
        // core gives no volume its own list, and the era's stands in, which the chip names, as for a volumes file the app
        // cannot read; the family's volumes file beside the app's core serves a volume's own list, and the corpus's
        // cloud says why it has none.
        let appsVolumes = try folder("apps-volumes", [(Self.folder.appendingPathComponent("cloud-vectors-core.json"), "cloud-vectors-core.json"),
                                                      (Self.resources.appendingPathComponent("cloud-vectors-volumes.json"), "cloud-vectors-volumes.json")])
        let era = WordCloudRoutes.answer(.volume(volumeId: "frus1961-63v06", subseries: "1961-63"), lens: .topics, settings: .standard,
                                         resources: try ServerResources.load(from: Self.resources, language: appsVolumes))
        let familyEra = WordCloudParityTests.Host.list(try Self.core(), "1961-63", .topics)
        #expect(era.state == "terms" && era.fallbackSubseries == "1961-63" && era.chip == "Topics · 1961-63 (era)")
        #expect(era.terms.map { "\($0.term) \($0.count)" } == familyEra, "the family's era, never the app's volume")
        let appsCore = try folder("apps-core", [(Self.resources.appendingPathComponent("cloud-vectors-core.json"), "cloud-vectors-core.json"),
                                                (Self.folder.appendingPathComponent("cloud-vectors-volumes.json"), "cloud-vectors-volumes.json")])
        let ownVolume = try ServerResources.load(from: Self.resources, language: appsCore)
        let own = WordCloudRoutes.answer(.volume(volumeId: "frus1961-63v06", subseries: "1961-63"), lens: .topics, settings: .standard, resources: ownVolume)
        let familyVolume = WordCloudParityTests.Host.list(try Self.volumes(), "frus1961-63v06", .topics)
        #expect(own.state == "terms" && own.fallbackSubseries == nil && own.terms.map { "\($0.term) \($0.count)" } == familyVolume)
        let corpusOfApps = WordCloudRoutes.answer(.corpus, lens: .topics, settings: .standard, resources: ownVolume)
        #expect(corpusOfApps.state == "noCloud" && corpusOfApps.message?.detail == other.sentence)

        // A folder with none of them.
        let empty = try folder("empty", [])
        let none = try ServerResources.load(from: Self.resources, language: empty)
        #expect(WordCloudRoutes.answer(.corpus, lens: .topics, settings: .standard, resources: none).message?.detail == FamilyRefusal.missing.sentence)
        #expect(WordCloudRoutes.context(resources: none).made == nil)
    }
}

extension Result {
    /// The failure, or nil for a success.
    var error: Failure? {
        if case .failure(let failure) = self { return failure }
        return nil
    }
}
