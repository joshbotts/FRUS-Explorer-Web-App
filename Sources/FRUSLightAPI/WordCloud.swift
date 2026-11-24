// The Word Cloud (PLAN's S24i), in Frequency mode: the language family's clouds (PLAN's S29d), `cloud-vectors-core.json`
// (the corpus and each subseries) and `cloud-vectors-volumes.json` (each volume), which the app's generator,
// `CloudVectorsRunner.run(tagger:cloudLenses:environment:)`, counted with the web's tagger over the corpus
// (`scripts/make-language`), read from the family's folder (`FRUS_LANGUAGE_DIR`, resources/language in the repository)
// through the kit's `CloudVectorsFile(contentsOf:)` (FRUS-Explorer#1900, S24d) and held to the server's tagger's identity,
// so that the web counts in one family; the Mac's bundled clouds are read no more. They are read as the app's
// `BundledCloudVectors` reads its own for the clouds it draws before a volume is downloaded, with the four lenses the
// app's bar draws of them. Each list is filtered by the reader's own Word Cloud settings, from their synced
// preferences, as the app's settings bench filters a list of terms (`WordCloudBench.evaluate`): the kit's
// `WordCloudTokenizer.accepts(_:)` over the stop lists, lexicon and markings the app assembles
// (`WordCloudTokenizer.configured`), and the minimum count. What the app's view decides between the kit and the screen
// is app code, mirrored here under its names and held to the app's source by `WordCloudMirrorParityTests`: a thin
// volume's fall-back to its subseries and the chip that says so (`BundledCloudVectors.terms(forScope:lens:)`,
// `LensChip`), the lens bar's order and words, the main area's states (`WordCloudDisplayState.resolve`), the count
// line, the scope menu (`WordCloudScopeBar`) and the scoped hand-off (`scopedAnalyzeMenuLabel`, `analyticsScope()`),
// with the reader's settings as `WordCloudSettings` reads them.
//
// The server counts no scope of its own yet: the kit's tokenizers count with the web's tagger (FRUSLanguage's
// `FRUSWordCloudTagger`), as the family's run did, and a live scope, the Distinctive measure and collocates wait for the
// kit's live count (S29e, S29f), so a request for a live scope is refused. The reader's settings a counted list cannot
// show, those that would let in a word the generator never counted, are named by the kit's own comparability rule
// (`KeynessBaselineFile.Configuration.mismatches`), since the clouds were counted under the generator's configuration
// (`CloudVectorsRunner`: the standard tuning, the diplomatic layer on).

import FRUSCoreKit
import FRUSLightCore
import FRUSLanguage
import Foundation
import Hummingbird
import WordCloudKit

// MARK: - The family's files

/// Why the server reads none of one of the family's files (PLAN's S29d).
enum FamilyRefusal: Error, Equatable, Sendable {
    /// The family's folder holds no such file.
    case missing
    /// The file does not decode.
    case unreadable
    /// It was counted by another tokenizer than the server's tagger: another vocabulary, which the server never shows
    /// or compares with its own (S29a's `Mismatch.tokenizer`, SPEC's rule).
    case otherTokenizer(WordCloudTokenizerIdentity)
    /// A reference whose stamp names the other word form than its name does, which the app's lookup drops too
    /// (`BundledKeynessBaseline.isReference`).
    case otherWordForm(WordCloudWordForm)

    /// What the page says of it, the web's own words.
    var sentence: String {
        switch self {
        case .missing:
            "This server holds none of its language family’s clouds, which its tagger counts from the corpus."
        case .unreadable:
            "This server’s language family’s clouds cannot be read."
        case .otherTokenizer(let other):
            "This server’s clouds were counted by another tokenizer, \(other), not by its own tagger, \(FamilyClouds.family), so it shows none of them."
        case .otherWordForm(let form):
            "A reference of this server’s language family is counted in \(form.rawValue) forms where its name says otherwise, so it is not read."
        }
    }
}

/// One of the language family's files, decoded once by the kit's loader the first time it is asked for and held to the
/// family's identity, its tagger's: a file missing, malformed or counted by another tokenizer is refused, with the reason,
/// and never decoded again. Two first requests at once wait for one decode.
final class FamilyFile<Value: Sendable>: @unchecked Sendable {
    private let name: String
    private let decode: @Sendable (URL) throws -> Value
    private let check: @Sendable (Value) -> FamilyRefusal?
    private let lock = NSLock()
    private var held: Result<Value, FamilyRefusal>?

    init(_ name: String, decode: @escaping @Sendable (URL) throws -> Value, check: @escaping @Sendable (Value) -> FamilyRefusal?) {
        self.name = name
        self.decode = decode
        self.check = check
    }

    /// The file in `directory`, decoded and held to the family, or why it was refused.
    func value(in directory: URL) -> Result<Value, FamilyRefusal> {
        lock.lock()
        defer { lock.unlock() }
        if let held { return held }
        let url = directory.appendingPathComponent(name)
        let outcome: Result<Value, FamilyRefusal>
        if !FileManager.default.fileExists(atPath: url.path) {
            outcome = .failure(.missing)
        } else if let value = try? decode(url) {
            outcome = check(value).map { .failure($0) } ?? .success(value)
        } else {
            outcome = .failure(.unreadable)
        }
        held = outcome
        return outcome
    }
}

/// The language family's clouds and references (PLAN's S29d), from the family's folder, and the app's word lists that
/// filter them, from its data files, each decoded on first use by the kit's loader and kept while the server runs. The
/// four files are held to the server's tagger's identity, and a reference to the form its name says: one of another
/// tokenizer is refused, as the kit's rule refuses a reference counted by another, so that the web counts in one
/// family. Nothing of a file refused is shown: a scope it would have answered has no cloud, with the reason on the page,
/// but a volume's, which takes its era's list from the core file, as the app's rule takes it for a volumes file it cannot
/// read, and the chip says so. The word lists, missing or malformed, give empty lists, as the app's `WordCloudStopwords`
/// and `WordCloudLexicons` give.
final class FamilyClouds: Sendable {
    /// The family's identity: the server's tagger's, `FRUSLanguage`'s, which the first read of a file decodes.
    static var family: WordCloudTokenizerIdentity { LanguageTagger.shared.identity.wordCloudIdentity }

    /// The corpus and every subseries, as `BundledCloudVectors.core` holds the app's.
    let core = FamilyFile("cloud-vectors-core.json", decode: { try CloudVectorsFile(contentsOf: $0) }, check: { FamilyClouds.counted($0) })
    /// Every volume, as `BundledCloudVectors.volumes` holds the app's.
    let volumes = FamilyFile("cloud-vectors-volumes.json", decode: { try CloudVectorsFile(contentsOf: $0) }, check: { FamilyClouds.counted($0) })
    /// The references in dictionary and printed forms, which Distinctive and collocates rank against (S29f).
    let dictionaryReference = FamilyFile(KeynessBaselineFile.resourceName(for: .dictionary) + ".json",
                                         decode: { try KeynessBaselineFile(contentsOf: $0) }, check: { FamilyClouds.reference($0, .dictionary) })
    let printedReference = FamilyFile(KeynessBaselineFile.resourceName(for: .printed) + ".json",
                                      decode: { try KeynessBaselineFile(contentsOf: $0) }, check: { FamilyClouds.reference($0, .printed) })
    private let stopwordFile = DecodedFile("word-cloud-stopwords.json") { try WordCloudStopwordSet(contentsOf: $0) }
    private let lexiconFile = DecodedFile("word-cloud-lexicons.json") { try WordCloudLexiconSet(contentsOf: $0) }

    /// A cloud file counted by another tokenizer than the family's, refused.
    static func counted(_ file: CloudVectorsFile) -> FamilyRefusal? {
        file.provenance.tokenizer == family ? nil : .otherTokenizer(file.provenance.tokenizer)
    }

    /// A reference counted by another tokenizer, or in the other form than its name's, refused.
    static func reference(_ file: KeynessBaselineFile, _ form: WordCloudWordForm) -> FamilyRefusal? {
        if file.configuration.tokenizer != family { return .otherTokenizer(file.configuration.tokenizer) }
        return file.configuration.wordForm == form ? nil : .otherWordForm(file.configuration.wordForm)
    }

    /// The reference counted in `form`, or why it is refused.
    func reference(_ form: WordCloudWordForm, in directory: URL) -> Result<KeynessBaselineFile, FamilyRefusal> {
        (form == .dictionary ? dictionaryReference : printedReference).value(in: directory)
    }

    /// `WordCloudStopwords.shared`: the bundled stop lists, empty where the file is missing or malformed.
    func stopwords(in directory: URL) -> WordCloudStopwordSet { stopwordFile.value(in: directory) ?? .empty }
    /// `WordCloudLexicons.shared`: the bundled lexicons, empty where the file is missing or malformed.
    func lexicons(in directory: URL) -> WordCloudLexiconSet { lexiconFile.value(in: directory) ?? .empty }
}

// MARK: - The reader's settings

/// The reader's Word Cloud settings, from their synced preferences, read as the app reads its own (`WordCloudSettings`):
/// the tuning through the kit's reading of the stored values, the boilerplate switch as it is stored
/// (`includeDiplomatic`, never inverted), and the hidden words of every cloud with each lens's own.
struct CloudSettings: Equatable, Sendable {
    var tuning: WordCloudTuning
    /// "Hide common diplomatic words", `excludeBoilerplate`: the diplomatic stop list's layer.
    var includeDiplomatic: Bool
    /// The hidden words of every cloud, as stored.
    var globalStopwords: [String]
    /// Each lens's own hidden words, by the lens's raw value, as stored.
    var lensStopwords: [String: [String]]

    /// The app's own values, `SyncedPreferences()`'s, for a request that acts for no one.
    static let standard = CloudSettings(PreferenceRoutes.initial(at: Date(timeIntervalSince1970: 0)))

    init(_ preferences: SyncedPreferencesExport) {
        tuning = WordCloudTuning(settingsMinimumLength: preferences.wcMinLength, minimumCount: preferences.wcMinCount,
                                 foldPlurals: preferences.wcFoldPlurals, filterMarkings: preferences.wcFilterMarkings)
        includeDiplomatic = preferences.wcExcludeBoilerplate
        globalStopwords = Self.decodeStringArray(preferences.wcGlobalStopwordsJSON)
        lensStopwords = Self.lensStopwordMap(preferences.wcLensStopwordsJSON)
    }

    /// `WordCloudSettings.lensStopwords(_:)`: the words hidden under `lens` alone.
    func lensStopwords(_ lens: WordCloudLens) -> [String] {
        lensStopwords[lens.rawValue] ?? []
    }

    /// `WordCloudSettings.extraStopwords(for:)`: the global list unioned with the lens's own.
    func extraStopwords(for lens: WordCloudLens) -> Set<String> {
        Set(globalStopwords).union(lensStopwords(lens))
    }

    /// `SettingsSyncCoordinator.decodeStringArray(_:)`: the synced global list, none for text that does not read.
    static func decodeStringArray(_ json: String) -> [String] {
        guard !json.isEmpty, let data = json.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return array
    }

    /// `WordCloudSettings.lensStopwordMap()`, over the synced JSON the app keeps as its data: none for text that does
    /// not read.
    static func lensStopwordMap(_ json: String) -> [String: [String]] {
        guard let map = try? JSONDecoder().decode([String: [String]].self, from: Data(json.utf8)) else { return [:] }
        return map
    }

    /// The JSON the app keeps a lens map as, `JSONEncoder`'s, its keys sorted so that one map is always one text.
    static func encodeLensMap(_ map: [String: [String]]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(map)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    /// `WordCloudTokenizer.configured(tuning:lens:includeDiplomatic:extraStopwords:wordForm:)`, the app's assembly of
    /// its tokenizer, over the bundled lists: the stop lists the boilerplate switch chooses with the reader's hidden
    /// words, the lens's lexicon, and the markings when they are filtered. Its filters read no tagger, so the form
    /// plays no part in what they keep (`WordCloudBench.evaluate`).
    func tokenizer(for lens: WordCloudLens, stopwords: WordCloudStopwordSet, lexicons: WordCloudLexiconSet) -> WordCloudTokenizer {
        WordCloudTokenizer(
            stopwords: stopwords.active(includeDiplomatic: includeDiplomatic)
                .union(extraStopwords(for: lens)),
            minimumLength: tuning.minimumLength,
            foldPlurals: tuning.foldPlurals,
            lens: lens,
            lexicon: lexicons.filter(for: lens),
            markings: tuning.filterMarkings ? stopwords.markings : [],
            wordForm: .dictionary
        )
    }

    /// `WordCloudBench.evaluate`: the terms of `sample` these settings keep, in the sample's order, each at least the
    /// minimum count and accepted by the kit's tokenizer.
    func kept(_ sample: [TermCount], lens: WordCloudLens, stopwords: WordCloudStopwordSet,
              lexicons: WordCloudLexiconSet) -> [TermCount] {
        let tokenizer = tokenizer(for: lens, stopwords: stopwords, lexicons: lexicons)
        return sample.filter {
            $0.count >= tuning.minimumCount && tokenizer.accepts($0.term.lowercased())
        }
    }

    /// The settings of these a counted cloud cannot show, by the kit's comparability rule between a count and the
    /// generator's: those that would let in a word the generator never counted. The generator counted the clouds at
    /// the file's own tuning, with the diplomatic layer on (`CloudVectorsRunner`), and with the app's word lists,
    /// which are the ones read here, so the digests are not compared. The settings filter the file's own counts, so
    /// both sides name the tokenizer the file was counted by (S29a's `Mismatch.tokenizer`): a file another tokenizer
    /// counted is never called another tokenizer's by its own filter.
    func notShown(byCloudsOf file: CloudVectorsFile) -> [KeynessBaselineFile.Configuration.Mismatch] {
        KeynessBaselineFile.Configuration(tuning: file.provenance.tuning,
                                          includeDiplomatic: CloudRules.generatorIncludesDiplomatic,
                                          lexiconsDigest: "", stopwordsDigest: "", tokenizer: file.provenance.tokenizer)
            .mismatches(against: tuning, includeDiplomatic: includeDiplomatic, lexiconsDigest: "", stopwordsDigest: "",
                        tokenizer: file.provenance.tokenizer)
    }
}

// MARK: - The answers

/// What the Word Cloud opens on: its lenses and measures, the scope menu (`WordCloudScopeBar`: Entire Corpus, each
/// subseries, each volume under its subseries) and what the family's clouds say of themselves.
public struct CloudContext: Codable, Equatable, Sendable, ResponseEncodable {
    /// The lenses the page draws of the clouds, in the lens bar's order (`WordCloudLens.allCases`).
    public var lenses: [CloudLens]
    /// "Size words by": Frequency and Distinctive (`KeynessCloudMeasure`).
    public var measures: [CloudMeasure]
    /// "Entire Corpus".
    public var corpus: String
    /// The catalogue's subseries in its order, each with its volumes.
    public var subseries: [CloudSubseries]
    /// The clouds' own account, or none while their file cannot be read or is refused.
    public var made: Made?

    public struct Made: Codable, Equatable, Sendable {
        /// The day the generator ran, as the file stamps it.
        public var generated: String
        public var volumeCount: Int
        public var documentCount: Int
        /// The words each list keeps.
        public var topTermsPerList: Int
        /// The tokenizer the clouds were counted by, the language family's: its name and version (PLAN's S29d).
        public var family: String
        /// The sentence the page says them in.
        public var line: String
    }
}

/// A lens, by its raw value, with the lens bar's name and the chip's (`WordCloudLens.label`, `shortLabel`).
public struct CloudLens: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var shortLabel: String
    /// Whether the cloud colours its words by sentiment (`WordCloudLens.colorsBySentiment`).
    public var colorsBySentiment: Bool
}

/// A measure the cloud can size its words by, by its raw value (`KeynessCloudMeasure.pickerLabel`).
public struct CloudMeasure: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
}

/// A subseries the scope menu offers, with its volumes.
public struct CloudSubseries: Codable, Equatable, Sendable {
    public var id: String
    public var volumes: [Volume]

    public struct Volume: Codable, Equatable, Sendable {
        public var id: String
        /// The menu's name for it: its title, or its id where it has none.
        public var title: String
    }
}

/// One scope's cloud under one lens: the family's list's words that the reader's settings keep.
public struct CloudAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// The scope, by the app's signature, with the title the app gives it.
    public var scope: Scope
    public var lens: CloudLens
    /// The chip: the lens's name, and the era's where a volume's own list stood aside for it (`LensChip`).
    public var chip: String
    /// The subseries whose list stands in for a volume's, which the chip names, or none.
    public var fallbackSubseries: String?
    /// What the main area shows: `terms`, `noTerms`, `insufficientSignal`, or `noCloud` where the family's clouds hold no
    /// list for the scope, or are refused.
    public var state: String
    /// The words of a state with nothing to draw.
    public var message: Message?
    /// "48 terms": how many words are drawn, in the app's words; none where there is no list.
    public var countLine: String?
    /// The words kept, by count, as the file ranks them; on the sentiment lens each with its polarity.
    public var terms: [Term]
    /// How many words the family's list holds, and how many of them the reader's settings took out.
    public var listed: Int
    public var removed: Int
    /// The settings of the reader's the family's clouds cannot show, in one sentence, or none.
    public var settingsNotShown: String?
    /// The scoped hand-off a word's menu offers a volume's or a subseries' cloud.
    public var analyzeWithin: AnalyzeWithin?

    public struct Scope: Codable, Equatable, Sendable {
        /// `corpus`, `sub:<subseries>` or `vol:<volume>`.
        public var signature: String
        public var title: String
    }

    public struct Message: Codable, Equatable, Sendable {
        public var title: String
        public var detail: String
    }

    public struct Term: Codable, Equatable, Sendable {
        public var term: String
        public var count: Int
        /// On the sentiment lens, the lexicon's polarity: 1, -1, or 0 for none.
        public var polarity: Int?
    }

    /// "Analyze within this volume", or this subseries: Corpus Analytics over the cloud's volumes, by its title.
    public struct AnalyzeWithin: Codable, Equatable, Sendable {
        public var label: String
        public var volumeIds: [String]
        public var scopeLabel: String
    }
}

/// The settings bench (`WordCloudBench`): what the reader's settings keep of the sample, and the pane's words for it.
public struct CloudSample: Codable, Equatable, Sendable, ResponseEncodable {
    /// The kept terms, in the sample's order.
    public var kept: [CloudAnswer.Term]
    public var sampleSize: Int
    /// "Keeps 18 of 24 terms in this sample".
    public var summary: String
    /// Where the sample comes from.
    public var provenance: String
}

// MARK: - The rules mirrored

/// A scope the family's clouds hold, `BundledCloudVectors.Scope`, named in the address by the app's own scope signature
/// (`WordCloudScope.signature`): `corpus`, `sub:<subseries>` or `vol:<volume>`.
enum CloudScope: Equatable, Sendable {
    case corpus
    case subseries(String)
    case volume(volumeId: String, subseries: String)

    /// The app's signature for the scope (`WordCloudScope.signature`).
    var signature: String {
        switch self {
        case .corpus: "corpus"
        case .subseries(let id): "sub:\(id)"
        case .volume(let volumeId, _): "vol:\(volumeId)"
        }
    }
}

/// What the app's Word Cloud decides between the kit and the screen, mirrored.
enum CloudRules {
    /// `CloudVectorsAggregatorScopeKeys.corpus`: the corpus's key in the core file.
    static let corpusKey = "corpus"

    /// The diplomatic layer the generator counted the clouds with (`CloudVectorsRunner.run(tagger:cloudLenses:
    /// environment:)`, which `run()` calls: `let includeDiplomatic = true`), which the file does not record.
    static let generatorIncludesDiplomatic = true

    /// The lenses the page draws, in the lens bar's order: the app's bar lists `WordCloudLens.allCases`, and the app's
    /// clouds carry `bundledCloudLenses`; the family's carry two more, All terms and Descriptors, which S29e's live
    /// clouds bring to the bar.
    static let lenses: [WordCloudLens] = WordCloudLens.allCases.filter { WordCloudLens.bundledCloudLenses.contains($0) }

    /// `BundledCloudVectors.terms(forScope:lens:)`: a scope's list, and, for a volume whose own list the generator
    /// flagged below its lens's signal threshold, or whose file cannot be read, its subseries' list, which the chip
    /// must name. Nil where neither holds a list.
    static func terms(forScope scope: CloudScope, lens: WordCloudLens, core: CloudVectorsFile?,
                      volumes: CloudVectorsFile?) -> (terms: [TermCount], fallbackSubseries: String?)? {
        switch scope {
        case .corpus:
            return list(in: core, scope: corpusKey, lens: lens)
                .map { ($0, nil) }

        case .subseries(let id):
            return list(in: core, scope: id, lens: lens).map { ($0, nil) }

        case .volume(let volumeId, let subseries):
            if let own = list(in: volumes, scope: volumeId, lens: lens),
               !isBelowSignal(volumes, volumeId, lens) {
                return (own, nil)
            }
            return list(in: core, scope: subseries, lens: lens)
                .map { ($0, subseries) }
        }
    }

    /// `BundledCloudVectors.isBelowSignal`: whether the generator flagged the stored list below its lens's threshold.
    private static func isBelowSignal(_ file: CloudVectorsFile?, _ scope: String, _ lens: WordCloudLens) -> Bool {
        file?.scopes[scope]?.lists[lens.rawValue]?.belowSignalThreshold ?? false
    }

    /// `BundledCloudVectors.list(in:scope:lens:)`: one scope's list as terms, the shared vocabulary de-indexed, an index
    /// outside it dropped; nil for a list missing or empty.
    static func list(in file: CloudVectorsFile?, scope: String, lens: WordCloudLens) -> [TermCount]? {
        guard let file, let stored = file.scopes[scope]?.lists[lens.rawValue], !stored.entries.isEmpty
        else { return nil }
        return stored.entries.compactMap { entry in
            guard entry.term >= 0, entry.term < file.vocabulary.count else { return nil }
            return TermCount(term: file.vocabulary[entry.term], count: entry.count)
        }
    }

    /// `LensChip.label`: "Concepts", or "Concepts · 1969-76 (era)" when an era stood in.
    static func chip(lens: WordCloudLens, fallbackSubseries: String?) -> String {
        guard let subseries = fallbackSubseries else { return shortLabel(lens) }
        return "\(shortLabel(lens)) · \(subseries) (era)"
    }

    /// `WordCloudDisplayState.resolve`'s states for a list in hand: no terms when the reader's settings kept none, too
    /// few for a signal-dependent lens, and otherwise the terms.
    static func state(kept: [TermCount], lens: WordCloudLens) -> String {
        if kept.isEmpty { return "noTerms" }
        if lens.isSignalDependent && kept.count < lens.minimumSignalTerms {
            return "insufficientSignal"
        }
        return "terms"
    }

    /// `WordCloudDisplayState.countLine(terms:documents:)`'s terms: "1 term", "48 terms", by `CountCopy`'s rule. The
    /// counted lists carry no count of a scope's documents, so the line names none.
    static func countLine(terms: Int) -> String {
        CountCopy.phrase(terms,
                         one: appWords("wordcloud.count.terms.one", "%@ term"),
                         many: appWords("wordcloud.count.terms.many", "%@ terms"),
                         locale: SearchItem.locale)
    }

    /// The message of a state with nothing to draw: `WordCloudMainArea`'s views, in the app's words.
    static func message(state: String, lens: WordCloudLens) -> CloudAnswer.Message? {
        switch state {
        case "noTerms":
            return .init(title: appWords("wordcloud.lens.noTerms.title", "Nothing Found for This Lens"),
                         detail: noTermsDetail(for: lens))
        case "insufficientSignal":
            return .init(title: appWords("wordcloud.lens.insufficient.title", "Not Enough Signal"),
                         detail: String(
                            format: appWords("wordcloud.lens.insufficient.detail %@",
                                             "There aren’t enough %@ in this scope to fill a cloud. Try a broader scope or a different lens."),
                            label(lens).lowercased()))
        case "noCloud":
            // The web's own: the app's backdrop draws nothing for a scope its clouds lack.
            return .init(title: "No Counted Cloud",
                         detail: "The clouds this server’s tagger counted from the corpus hold no list for this scope under this lens.")
        default:
            return nil
        }
    }

    /// `WordCloudDisplayState.noTermsDetail(for:)`, for the four lenses the page draws.
    static func noTermsDetail(for lens: WordCloudLens) -> String {
        switch lens {
        case .topics:
            appWords("wordcloud.lens.noTerms.topics",
                     "This scope’s documents were read, but none of their nouns passed the Word Cloud’s filters. Try a broader scope or a different lens.")
        case .actions:
            appWords("wordcloud.lens.noTerms.actions",
                     "This scope’s documents were read, but none of their verbs passed the Word Cloud’s filters. Try a broader scope or a different lens.")
        case .concepts:
            appWords("wordcloud.lens.noTerms.concepts",
                     "This scope’s documents were read, but none of them uses a word from the Concepts list. Try a broader scope or a different lens.")
        case .sentiment:
            appWords("wordcloud.lens.noTerms.sentiment",
                     "This scope’s documents were read, but none of them uses a word from the Sentiment list. Try a broader scope or a different lens.")
        default:
            ""
        }
    }

    /// `WordCloudLens.label`, the lens bar's name, for the four lenses the page draws.
    static func label(_ lens: WordCloudLens) -> String {
        switch lens {
        case .topics: appWords("wordcloud.lens.topics", "Topics (nouns)")
        case .actions: appWords("wordcloud.lens.actions", "Actions (verbs)")
        case .concepts: appWords("wordcloud.lens.concepts", "Concepts")
        case .sentiment: appWords("wordcloud.lens.sentiment", "Sentiment")
        default: lens.rawValue
        }
    }

    /// `WordCloudLens.shortLabel`, the chip's name, for the four lenses the page draws.
    static func shortLabel(_ lens: WordCloudLens) -> String {
        switch lens {
        case .topics: appWords("wordcloud.lens.short.topics", "Topics")
        case .actions: appWords("wordcloud.lens.short.actions", "Actions")
        case .concepts: appWords("wordcloud.lens.short.concepts", "Concepts")
        case .sentiment: appWords("wordcloud.lens.short.sentiment", "Sentiment")
        default: lens.rawValue
        }
    }

    static func lens(_ lens: WordCloudLens) -> CloudLens {
        CloudLens(id: lens.rawValue, label: label(lens), shortLabel: shortLabel(lens), colorsBySentiment: lens.colorsBySentiment)
    }

    /// `KeynessCloudMeasure.pickerLabel`.
    static func measureLabel(_ measure: KeynessCloudMeasure) -> String {
        switch measure {
        case .frequency: appWords("wordcloud.measure.frequency", "Frequency")
        case .keyness: appWords("wordcloud.measure.keyness", "Distinctive")
        }
    }

    /// `WordCloudView.mismatchDescription(_:)`: the settings, in the reader's own words, each once, joined.
    static func mismatchDescription(_ mismatches: [KeynessBaselineFile.Configuration.Mismatch]) -> String {
        mismatches.map { mismatch in
            switch mismatch {
            case .diplomaticLayer:
                appWords("wordcloud.keyness.mismatch.boilerplate",
                         "“Hide common diplomatic words” is off")
            case .foldPlurals:
                appWords("wordcloud.keyness.mismatch.plurals",
                         "plural folding differs")
            case .filterMarkings:
                appWords("wordcloud.keyness.mismatch.markings",
                         "classification-marking filtering differs")
            case .minimumLength:
                appWords("wordcloud.keyness.mismatch.length",
                         "your minimum word length is shorter")
            case .lexicons, .stopwords:
                appWords("wordcloud.keyness.mismatch.payload",
                         "the bundled word lists have changed since the reference was built")
            case .tokenizer:
                appWords("wordcloud.keyness.mismatch.tokenizer",
                         "the reference was counted by another tokenizer")
            }
        }
        // Duplicates are possible: `.lexicons` and `.stopwords` share one description.
        .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        .joined(separator: "; ")
    }

    /// The sentence naming the settings a counted cloud cannot show, the web's own around the app's words, or none.
    static func notShownSentence(_ mismatches: [KeynessBaselineFile.Configuration.Mismatch]) -> String? {
        guard !mismatches.isEmpty else { return nil }
        return "These clouds were counted once, at the standard settings, so your settings can take words out of them but cannot count them differently: \(mismatchDescription(mismatches))."
    }

    /// `WordCloudScopeBar.subseriesList`: the distinct subseries, in the catalogue's order.
    static func subseriesList(_ entries: [VolumeManifestEntry]) -> [String] {
        var seen = Set<String>()
        var all: [String] = []
        for entry in entries where seen.insert(entry.subseries).inserted { all.append(entry.subseries) }
        return all
    }

    /// `WordCloudScopeResolver.resolve`'s title: "Entire Corpus", the subseries, or the volume's title or id.
    static func title(of scope: CloudScope, resources: ServerResources) -> String {
        switch scope {
        case .corpus:
            appWords("wordcloud.scope.corpus", "Entire Corpus")
        case .subseries(let subseriesId):
            subseriesId
        case .volume(let volumeId, _):
            resources.volume(volumeId)?.title ?? volumeId
        }
    }

    /// `scopedAnalyzeMenuLabel` and `analyticsScope()`: the scoped hand-off a volume's or a subseries' cloud offers,
    /// over the volume, or the catalogue's volumes of the subseries, by the cloud's title; none for the corpus.
    static func analyzeWithin(_ scope: CloudScope, title: String, resources: ServerResources) -> CloudAnswer.AnalyzeWithin? {
        switch scope {
        case .volume(let volumeId, _):
            return .init(label: appWords("wordcloud.word.analyze.volume", "Analyze within this volume"),
                         volumeIds: [volumeId], scopeLabel: title.isEmpty ? volumeId : title)
        case .subseries(let subseriesId):
            let volumeIds = resources.manifest
                .filter { $0.subseries == subseriesId }
                .map(\.volumeId)
            guard !volumeIds.isEmpty else { return nil }
            return .init(label: appWords("wordcloud.word.analyze.subseries", "Analyze within this subseries"),
                         volumeIds: volumeIds, scopeLabel: title.isEmpty ? subseriesId : title)
        case .corpus:
            return nil
        }
    }

    /// `WordCloudBench.canonicalSample`: the settings bench's stand-in sample, chosen so every control moves it.
    static let canonicalSample: [TermCount] = [
        TermCount(term: "negotiation", count: 84),
        TermCount(term: "telegram", count: 71),
        TermCount(term: "ambassador", count: 63),
        TermCount(term: "settlement", count: 55),
        TermCount(term: "negotiations", count: 48),
        TermCount(term: "memorandum", count: 44),
        TermCount(term: "sovereignty", count: 39),
        TermCount(term: "confidential", count: 37),
        TermCount(term: "withdrawal", count: 33),
        TermCount(term: "communiqué", count: 28),
        TermCount(term: "recognition", count: 24),
        TermCount(term: "armistice", count: 21),
        TermCount(term: "delegation", count: 19),
        TermCount(term: "priority", count: 17),
        TermCount(term: "sanctions", count: 15),
        TermCount(term: "ceasefire", count: 13),
        TermCount(term: "mediation", count: 11),
        TermCount(term: "war", count: 9),
        TermCount(term: "protocol", count: 8),
        TermCount(term: "blockade", count: 6),
        TermCount(term: "aid", count: 5),
        TermCount(term: "détente", count: 2),
        TermCount(term: "rapprochement", count: 1),
    ]

    /// `WordCloudBench.summary`: "Keeps 18 of 24 terms in this sample".
    static func benchSummary(kept: Int, sampleSize: Int) -> String {
        guard sampleSize > 0 else {
            return appWords("settings.wordcloud.bench.pending", "Measuring…")
        }
        return String(format: appWords("settings.wordcloud.bench.keeps %lld %lld", "Keeps %lld of %lld terms in this sample"),
                      Int64(kept), Int64(sampleSize))
    }

    /// The day a file stamps, `yyyy-MM-dd`, as the web writes dates: "October 12, 2026"; the stamp itself where it does
    /// not read as a day.
    static func day(_ stamp: String) -> String {
        let parts = stamp.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]) else { return stamp }
        var components = DateComponents()
        (components.year, components.month, components.day) = (parts[0], parts[1], parts[2])
        components.timeZone = TimeZone(identifier: "UTC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let date = calendar.date(from: components) else { return stamp }
        return date.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: SearchItem.locale,
                                               calendar: calendar, timeZone: calendar.timeZone))
    }
}

// MARK: - The routes

enum WordCloudRoutes {
    /// The scope signatures of the app's other clouds, each counted live from a scope's text, which this server
    /// cannot do (`WordCloudScope.init?(signature:)`).
    static let liveSignatures: Set<String> = ["doc", "col", "tag", "search", "scope", "subject", "daterange"]

    static func add(to router: Router<APIRequestContext>, resources: ServerResources, users: SearchUsers) {
        router.get("/api/v1/cloud/context") { request, _ -> CloudContext in
            try FormQuery(request.uri.query).refuseUnknown([])
            return try await Blocking.run { context(resources: resources) }
        }
        router.get("/api/v1/cloud") { request, context -> CloudAnswer in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["scope", "lens"])
            let scope = try scope(query.single("scope"), resources: resources)
            let lens = try lens(query.single("lens"))
            let settings = try await settings(for: request, context: context, users: users)
            return try await Blocking.run { answer(scope, lens: lens, settings: settings, resources: resources) }
        }
    }

    // MARK: The context

    static func context(resources: ServerResources) -> CloudContext {
        let entries = resources.manifest
        let subseries = CloudRules.subseriesList(entries).map { id in
            CloudSubseries(id: id, volumes: entries.filter { $0.subseries == id }.map {
                CloudSubseries.Volume(id: $0.volumeId, title: $0.title.isEmpty ? $0.volumeId : $0.title)
            })
        }
        let made = (try? resources.familyClouds.core.value(in: resources.languageDirectory).get()).map { file in
            CloudContext.Made(generated: file.generated, volumeCount: file.provenance.volumeCount,
                              documentCount: file.provenance.documentCount,
                              topTermsPerList: file.provenance.topTermsPerList,
                              family: file.provenance.tokenizer.description, line: madeLine(file))
        }
        return CloudContext(lenses: CloudRules.lenses.map(CloudRules.lens),
                            measures: KeynessCloudMeasure.allCases.map { CloudMeasure(id: $0.rawValue, label: CloudRules.measureLabel($0)) },
                            corpus: appWords("wordcloud.scope.corpus", "Entire Corpus"),
                            subseries: subseries, made: made)
    }

    /// The family's clouds' own account, the web's sentence over the file's provenance, naming the tokenizer that counted
    /// them (PLAN's S29d).
    static func madeLine(_ file: CloudVectorsFile) -> String {
        "These clouds were counted by this server’s own tagger, \(file.provenance.tokenizer), on \(CloudRules.day(file.generated)) from the corpus’s \(grouped(file.provenance.volumeCount)) volumes and \(CountCopy.documents(file.provenance.documentCount, locale: SearchItem.locale)) at the standard settings. Each list keeps the \(grouped(file.provenance.topTermsPerList)) words its scope uses most."
    }

    // MARK: The cloud

    /// The scope an address names by the app's signature: the corpus, a subseries or a volume of the catalogue's. A
    /// signature of the app's other clouds is refused (`LIVE_SCOPE`): each is counted live, which this server cannot do;
    /// one the app would not read as a scope at all is a bad parameter, as the analytics routes refuse a subseries.
    static func scope(_ raw: String?, resources: ServerResources) throws -> CloudScope {
        guard let raw, raw != "corpus" else { return .corpus }
        guard let colon = raw.firstIndex(of: ":") else {
            throw APIProblem.invalidParameter("scope", "must be corpus, sub:<subseries> or vol:<volume>, not \(raw)")
        }
        let prefix = String(raw[..<colon])
        let value = String(raw[raw.index(after: colon)...])
        switch prefix {
        case "sub":
            guard CloudRules.subseriesList(resources.manifest).contains(value) else {
                throw APIProblem.invalidParameter("scope", "names no subseries of the published catalogue, \(value)")
            }
            return .subseries(value)
        case "vol":
            guard let entry = resources.volume(value) else { throw APIProblem.volumeNotFound(value) }
            return .volume(volumeId: entry.volumeId, subseries: entry.subseries)
        case let live where liveSignatures.contains(live) && isLiveScope(live, value):
            throw APIProblem(.unprocessableContent, code: "LIVE_SCOPE",
                             detail: "A cloud of this scope is counted from its documents' text, in their dictionary forms, which this server does not count yet. It reads the clouds its tagger counted from the corpus, of the corpus, each subseries and each volume.")
        default:
            throw APIProblem.invalidParameter("scope", "must be corpus, sub:<subseries> or vol:<volume>, not \(raw)")
        }
    }

    /// Whether `value` makes a scope of the app's under the live signature `prefix`, as `WordCloudScope.init?(signature:)`
    /// reads it: a document by its volume and id, a record of the reader's by its id, a subject by its category, and a
    /// range by its two days.
    static func isLiveScope(_ prefix: String, _ value: String) -> Bool {
        switch prefix {
        case "doc":
            guard value.firstIndex(of: "/") != nil else { return false }
            return true
        case "col", "tag", "search", "scope":
            return UUID(uuidString: value) != nil
        case "subject":
            let parts = value.components(separatedBy: "\u{1f}")
            guard let category = parts.first, !category.isEmpty else { return false }
            return true
        case "daterange":
            let bounds = value.components(separatedBy: "..")
            guard bounds.count == 2, !bounds[0].isEmpty, !bounds[1].isEmpty else { return false }
            return true
        default:
            return false
        }
    }

    /// The lens an address names, one the page draws; the lens bar's first where it names none.
    static func lens(_ raw: String?) throws -> WordCloudLens {
        guard let raw else { return CloudRules.lenses[0] }
        guard let lens = WordCloudLens(rawValue: raw), CloudRules.lenses.contains(lens) else {
            throw APIProblem.invalidParameter("lens", "must be one of \(CloudRules.lenses.map(\.rawValue).joined(separator: ", ")), the lenses the page draws, not \(raw)")
        }
        return lens
    }

    /// The Word Cloud settings of the user `request` acts for, as their synced preferences hold them, or the app's own
    /// for a request that acts for no one.
    static func settings(for request: Request, context: APIRequestContext, users: SearchUsers) async throws -> CloudSettings {
        guard let services = users.services, let user = try await users.requestUser(request, context: context, services: services)
        else { return .standard }
        return try await CloudSettings(PreferenceRoutes.syncedPreferences(of: user.id, in: services.store))
    }

    /// One scope's cloud under one lens, its list filtered by `settings`.
    static func answer(_ scope: CloudScope, lens: WordCloudLens, settings: CloudSettings, resources: ServerResources) -> CloudAnswer {
        let directory = resources.directory
        let bundle = resources.familyClouds
        let coreFile = bundle.core.value(in: resources.languageDirectory)
        // The volumes file is read only for a volume's cloud, as the app reads it once a volume is chosen.
        let volumesFile: Result<CloudVectorsFile, FamilyRefusal>? =
            if case .volume = scope { bundle.volumes.value(in: resources.languageDirectory) } else { nil }
        let core = try? coreFile.get()
        let volumes = try? volumesFile?.get()
        let title = CloudRules.title(of: scope, resources: resources)
        let resolved = CloudRules.terms(forScope: scope, lens: lens, core: core, volumes: volumes)
        var answer = CloudAnswer(scope: .init(signature: scope.signature, title: title), lens: CloudRules.lens(lens),
                                 chip: CloudRules.chip(lens: lens, fallbackSubseries: resolved?.fallbackSubseries),
                                 fallbackSubseries: resolved?.fallbackSubseries, state: "noCloud",
                                 message: CloudRules.message(state: "noCloud", lens: lens), countLine: nil, terms: [],
                                 listed: 0, removed: 0, settingsNotShown: nil,
                                 analyzeWithin: CloudRules.analyzeWithin(scope, title: title, resources: resources))
        guard let resolved else {
            // A file refused says why: the first of the files the scope read, a volume's file and then the core, which
            // its era's list comes from.
            let refusal = [volumesFile, coreFile].lazy.compactMap { file -> FamilyRefusal? in
                if case .failure(let refusal)? = file { refusal } else { nil }
            }.first
            if let refusal, let message = answer.message {
                answer.message = .init(title: message.title, detail: refusal.sentence)
            }
            return answer
        }
        let stopwords = bundle.stopwords(in: directory)
        let lexicons = bundle.lexicons(in: directory)
        let kept = settings.kept(resolved.terms, lens: lens, stopwords: stopwords, lexicons: lexicons)
        let state = CloudRules.state(kept: kept, lens: lens)
        answer.state = state
        answer.message = CloudRules.message(state: state, lens: lens)
        answer.countLine = CloudRules.countLine(terms: kept.count)
        answer.terms = kept.map {
            CloudAnswer.Term(term: $0.term, count: $0.count,
                             polarity: lens.colorsBySentiment ? lexicons.polarity(of: $0.term.lowercased()) : nil)
        }
        answer.listed = resolved.terms.count
        answer.removed = resolved.terms.count - kept.count
        // Both files come out of one run, at one tuning.
        if let file = core ?? volumes {
            answer.settingsNotShown = CloudRules.notShownSentence(settings.notShown(byCloudsOf: file))
        }
        return answer
    }
}

/// The Word Cloud's routes under /me (PLAN's S24i): the hidden words, written as the app's settings write them, and
/// the settings bench.
enum WordCloudSettingsRoutes {
    struct HiddenWord: Decodable {
        let word: String
        let lens: String?
    }

    /// A hidden word's bound, past which a word is refused.
    static let wordLimit = 200

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources) {
        let store = services.store
        let now = services.now
        // `WordCloudSettings.addGlobalStopword(_:)`, or `addLensStopword(_:lens:)` for a lens.
        me.post("preferences/hidden-words") { request, context -> Preferences in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(HiddenWord.self, from: request, fields: ["word", "lens"])
            let lens = try settingsLens(body.lens, inQuery: false)
            guard let word = normalize(body.word) else {
                throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "word: a word to hide, not blank.")
            }
            guard word.count <= wordLimit else {
                throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "word: at most \(wordLimit) characters.")
            }
            return try await change(of: user.id, in: store, at: now()) { adding(word, lens: lens, to: $0) }
        }
        // `WordCloudSettings.removeGlobalStopword(_:)`, or `removeLensStopword(_:lens:)` for a lens.
        me.delete("preferences/hidden-words") { request, context -> Preferences in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["word", "lens"])
            let user = try context.requireUser()
            guard let word = try query.single("word") else {
                throw APIProblem.invalidParameter("word", "required: the word to show again")
            }
            let lens = try settingsLens(try query.single("lens"), inQuery: true)
            return try await change(of: user.id, in: store, at: now()) { removing(word, lens: lens, from: $0) }
        }
        // The settings bench (`WordCloudBench`): the stand-in sample, under the lens the editor shows, or every cloud's.
        me.get("preferences/word-cloud-sample") { request, context -> CloudSample in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["lens"])
            let user = try context.requireUser()
            let lens = try settingsLens(try query.single("lens"), inQuery: true) ?? .allTerms
            let settings = try await CloudSettings(PreferenceRoutes.syncedPreferences(of: user.id, in: store))
            return try await Blocking.run {
                let bundle = resources.familyClouds
                let kept = settings.kept(CloudRules.canonicalSample, lens: lens, stopwords: bundle.stopwords(in: resources.directory),
                                         lexicons: bundle.lexicons(in: resources.directory))
                return CloudSample(kept: kept.map { CloudAnswer.Term(term: $0.term, count: $0.count, polarity: nil) },
                                   sampleSize: CloudRules.canonicalSample.count,
                                   summary: CloudRules.benchSummary(kept: kept.count, sampleSize: CloudRules.canonicalSample.count),
                                   // The web's own: the app samples its last cloud, which this server never counts.
                                   provenance: "A stand-in sample: this server counts no clouds of its own for the sample to come from.")
            }
        }
    }

    /// A lens a hidden word may be kept under: any of the app's nine, as the settings pane offers each; none for every
    /// cloud. A body's field and a query's parameter are refused each in its own code.
    static func settingsLens(_ raw: String?, inQuery: Bool) throws -> WordCloudLens? {
        guard let raw, !raw.isEmpty else { return nil }
        guard let lens = WordCloudLens(rawValue: raw) else {
            let known = "one of \(WordCloudLens.allCases.map(\.rawValue).joined(separator: ", ")), or none for every cloud"
            throw inQuery ? APIProblem.invalidParameter("lens", "must be \(known), not \(raw)")
                : APIProblem(.badRequest, code: "INVALID_FIELD", detail: "lens: \(known).")
        }
        return lens
    }

    /// `WordCloudSettings.normalize(_:)`: trimmed, lowercased, none when empty.
    static func normalize(_ word: String) -> String? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The columns `word` hidden changes, as `addGlobalStopword(_:)` and `addLensStopword(_:lens:)` change their lists:
    /// a set, sorted; none where the word is hidden already.
    static func adding(_ word: String, lens: WordCloudLens?, to preferences: SyncedPreferencesExport) -> [String: SQLiteValue] {
        if let lens {
            var map = CloudSettings.lensStopwordMap(preferences.wcLensStopwordsJSON)
            var set = Set(map[lens.rawValue] ?? [])
            guard set.insert(word).inserted else { return [:] }
            map[lens.rawValue] = set.sorted()
            return ["wc_lens_stopwords_json": .text(CloudSettings.encodeLensMap(map))]
        }
        var set = Set(CloudSettings.decodeStringArray(preferences.wcGlobalStopwordsJSON))
        guard set.insert(word).inserted else { return [:] }
        return ["wc_global_stopwords_json": .text(TagReferences.encode(set.sorted()))]
    }

    /// The columns `word` shown again changes, as `removeGlobalStopword(_:)` and `removeLensStopword(_:lens:)` change
    /// their lists: the word lowercased, a lens's list gone once empty; none where the word was not hidden.
    static func removing(_ word: String, lens: WordCloudLens?, from preferences: SyncedPreferencesExport) -> [String: SQLiteValue] {
        if let lens {
            var map = CloudSettings.lensStopwordMap(preferences.wcLensStopwordsJSON)
            var set = Set(map[lens.rawValue] ?? [])
            guard set.remove(word.lowercased()) != nil else { return [:] }
            map[lens.rawValue] = set.isEmpty ? nil : set.sorted()
            return ["wc_lens_stopwords_json": .text(CloudSettings.encodeLensMap(map))]
        }
        var set = Set(CloudSettings.decodeStringArray(preferences.wcGlobalStopwordsJSON))
        guard set.remove(word.lowercased()) != nil else { return [:] }
        return ["wc_global_stopwords_json": .text(TagReferences.encode(set.sorted()))]
    }

    /// The user's preferences after `change`, which is given the row as the write finds it, so a change made meanwhile,
    /// from another tab, is kept; a change that alters nothing writes nothing, as the app's settings write only a
    /// difference.
    static func change(of user: String, in store: any UserDataStore, at time: Date,
                       _ change: @escaping @Sendable (SyncedPreferencesExport) -> [String: SQLiteValue]) async throws -> Preferences {
        let current = try await PreferenceRoutes.syncedPreferences(of: user, in: store)
        guard !change(current).isEmpty else { return try await PreferenceRoutes.preferences(of: user, in: store) }
        let row = try await Blocking.run {
            try store.setPreferences([:], initial: MacImport.preferences(PreferenceRoutes.initial(at: time)).values, for: user, at: time,
                                     merging: { held in change(try held.map(PreferenceRoutes.read) ?? PreferenceRoutes.initial(at: time)) })
        }
        return Preferences(try PreferenceRoutes.read(row), stored: true)
    }
}
