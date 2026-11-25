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
// Since S29e the server counts every other scope live, and these three too when the reader's settings are not the
// family's (WordCloudLive.swift): the kit's count with the web's tagger (FRUSLanguage's `FRUSWordCloudTagger`), as the
// family's run counted, over the served index. A scope the served index holds no text of is still read from the
// family's files under any settings, filtered as above, and the settings such a list cannot show, those that would let
// in a word the generator never counted, are named by the kit's own comparability rule
// (`KeynessBaselineFile.Configuration.mismatches`), since the clouds were counted under the generator's configuration
// (`CloudVectorsRunner`: the standard tuning, the diplomatic layer on). Since S29f the Distinctive measure ranks a live
// count against the family's reference (WordCloudDistinctive.swift), and Search's Collocates rank against it too
// (Collocates.swift). The lenses are the app's nine, its bar's order, and those the server's tagger cannot serve, the
// entity lenses, which name people, places and organizations, are said to be unavailable in the terms of the kit's health.

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

/// A value made the first time it is asked for, and kept: two first requests at once wait for one making (PLAN's S29f).
final class MadeOnce<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var held: Value?

    /// The value, made by `make` the first time.
    func value(_ make: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        if let held { return held }
        let made = make()
        held = made
        return made
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
    private let keynessReferences = MadeOnce<KeynessReferences>()

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

    /// The two references as the kit reads them, which Distinctive and Collocates rank against (PLAN's S29f):
    /// `KeynessReferences(dictionaryAt:printedAt:lexiconsAt:stopwordsAt:)` over the family's folder, each file held to
    /// its own stamp's form, with the digests of the app's word lists in `lists`, which the scope's tokenizer reads. A
    /// reference another tokenizer counted is kept, where ``reference(_:in:)`` refuses it, so that the kit's rule
    /// refuses a scope against it (`Mismatch.tokenizer`) in the app's words; one missing or unreadable is left out, and
    /// its lookups are the kit's `noArtifact`. Decoded once, on first use, as the family's other files are.
    func references(language directory: URL, lists: URL) -> KeynessReferences {
        keynessReferences.value {
            KeynessReferences(
                dictionaryAt: directory.appendingPathComponent(KeynessBaselineFile.resourceName(for: .dictionary) + ".json"),
                printedAt: directory.appendingPathComponent(KeynessBaselineFile.resourceName(for: .printed) + ".json"),
                lexiconsAt: lists.appendingPathComponent("word-cloud-lexicons.json"),
                stopwordsAt: lists.appendingPathComponent("word-cloud-stopwords.json"))
        }
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

    /// The kit's assembly of the app's tokenizer (`WordCloudTokenizer.configured(tuning:lens:includeDiplomatic:
    /// extraStopwords:wordForm:stopwords:lexicons:)`, S29b), over the bundled lists: the stop lists the boilerplate
    /// switch chooses with the reader's hidden words, the lens's lexicon, and the markings when they are filtered. Its
    /// filters read no tagger, so the form plays no part in what they keep (`WordCloudBench.evaluate`).
    func tokenizer(for lens: WordCloudLens, stopwords: WordCloudStopwordSet, lexicons: WordCloudLexiconSet) -> WordCloudTokenizer {
        WordCloudTokenizer.configured(tuning: tuning, lens: lens, includeDiplomatic: includeDiplomatic,
                                      extraStopwords: extraStopwords(for: lens),
                                      wordForm: .dictionary,
                                      stopwords: stopwords, lexicons: lexicons)
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

/// What the Word Cloud opens on: its lenses and measures, the scope menu's catalogue and subjects (`WordCloudScopeBar`:
/// Entire Corpus, each subseries, each volume under its subseries, and By Subject; the reader's own records are their
/// lists') and what the family's clouds say of themselves.
public struct CloudContext: Codable, Equatable, Sendable, ResponseEncodable {
    /// The lenses the lens bar offers, the app's nine in its order (`WordCloudLens.allCases`), each saying whether the
    /// server's tagger can draw it (PLAN's S29e).
    public var lenses: [CloudLens]
    /// "Size words by": Frequency and Distinctive (`KeynessCloudMeasure`).
    public var measures: [CloudMeasure]
    /// "Entire Corpus".
    public var corpus: String
    /// The catalogue's subseries in its order, each with its volumes.
    public var subseries: [CloudSubseries]
    /// By Subject's categories that narrow, each with its sub-categories (`ScopeFacets.narrowingCategories`,
    /// `subCategoryCatalog`), none without the subject data (PLAN's S29e).
    public var subjects: [CloudSubjectCategory]
    /// The range Date Range opens on, the corpus's last year (`defaultDateRangeScope()`), `yyyy-MM-dd`.
    public var dateRange: CloudDateRange
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
    /// Whether the server's tagger can draw it, by the kit's health (`NaturalLanguageHealth.supports`): not the entity
    /// lenses, since it recognizes no names (PLAN's S29e).
    public var available: Bool
}

/// A category By Subject offers, with its sub-categories, each a scope (`subject:<category>␟<sub-category>`).
public struct CloudSubjectCategory: Codable, Equatable, Sendable {
    public var label: String
    public var subcategories: [String]
}

/// A range of days, `yyyy-MM-dd`.
public struct CloudDateRange: Codable, Equatable, Sendable {
    public var from: String
    public var to: String
}

/// A count's job (PLAN's S29e), which the page follows: its id, where it stands and what it does.
public struct CloudJob: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    /// `queued`, `running`, `succeeded`, `failed` or `cancelled`.
    public var state: String
    /// A line of what it does now, or of what it did.
    public var progress: String?
    /// How far through it is, 0 to 1, where it can tell.
    public var fraction: Double?
    /// Why it failed, in the server's words.
    public var error: String?

    init(_ job: Job) {
        id = job.id
        state = job.state.rawValue
        progress = job.progress
        fraction = job.fraction
        error = job.state == .failed ? job.error : nil
    }
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

/// One scope's cloud under one lens: the family's list's words that the reader's settings keep, or the words a live
/// count of the scope's documents kept (PLAN's S29e).
public struct CloudAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// The scope, by the app's signature, with the title the app gives it.
    public var scope: Scope
    public var lens: CloudLens
    /// The chip: the lens's name, and the era's where a volume's own list stood aside for it (`LensChip`).
    public var chip: String
    /// The subseries whose list stands in for a volume's, which the chip names, or none.
    public var fallbackSubseries: String?
    /// Where the words come from: `family`, the family's files, or `live`, a count of the scope's documents (S29e).
    public var source: String
    /// What the main area shows: `terms`, `noTerms`, `insufficientSignal`, `noIndexedText` where a count read no
    /// document, `lensUnavailable` for a lens the server's tagger cannot serve, `counting` while a job counts the scope,
    /// or `noCloud` where the family's clouds hold no list for the scope, or are refused.
    public var state: String
    /// The words of a state with nothing to draw.
    public var message: Message?
    /// "48 terms", or a count's "48 terms from 393 documents": how many words are drawn, in the app's words; none where
    /// there is no list.
    public var countLine: String?
    /// The words kept, by count, as the file or the count ranks them; on the sentiment lens each with its polarity.
    public var terms: [Term]
    /// How many words the family's list holds, and how many of them the reader's settings took out; a count's words, and
    /// none taken out, since its settings were counted.
    public var listed: Int
    public var removed: Int
    /// The settings of the reader's the family's clouds cannot show, in one sentence, or none.
    public var settingsNotShown: String?
    /// The scoped hand-off a word's menu offers a volume's, a subseries', a volume scope's or a subject's cloud.
    public var analyzeWithin: AnalyzeWithin?
    /// How many documents a count read.
    public var documentCount: Int?
    /// What a count says of itself, the web's own: its documents, the tagger and whose settings; the family's lists say
    /// theirs in the context's account.
    public var account: String?
    /// The job counting the scope, while it is `counting`.
    public var job: CloudJob?
    /// Under Distinctive, for a scope with words to draw, the kit's ranking of them or why there is none (PLAN's S29f).
    public var distinctive: CloudDistinctive?

    public struct Scope: Codable, Equatable, Sendable {
        /// The app's signature (`WordCloudScope.signature`): `corpus`, `sub:<subseries>`, `vol:<volume>`,
        /// `doc:<volume>/<document>`, `col:`, `tag:`, `search:` or `scope:<id>`, `subject:<category>[␟<sub-category>]` or
        /// `daterange:<from>..<to>`.
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

    /// The lenses the page offers, the app's bar's (`WordCloudLens.allCases`), All terms first (PLAN's S29e). The family's
    /// clouds carry six of them; the entity lenses are unavailable, by the server's tagger's health.
    static let lenses: [WordCloudLens] = WordCloudLens.allCases

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
        case "noIndexedText":
            // `WordCloudView.emptyView`, a count that read no document (PLAN's S29e).
            return .init(title: appWords("wordcloud.empty.title", "No Terms"),
                         detail: appWords("wordcloud.empty.detail",
                                          "There’s no indexed text in this scope yet. Download and index the relevant volumes, then try again."))
        default:
            return nil
        }
    }

    /// `WordCloudDisplayState.noTermsDetail(for:)`, for every lens.
    static func noTermsDetail(for lens: WordCloudLens) -> String {
        switch lens {
        case .allTerms:
            appWords("wordcloud.lens.noTerms.allTerms",
                     "This scope’s documents were read, but none of their words passed the Word Cloud’s filters: the stopword lists, your hidden words, the minimum word length and the minimum count. You can change them in Settings → Word Cloud.")
        case .people:
            appWords("wordcloud.lens.noTerms.people",
                     "This scope’s documents were read, but no person’s name in them passed the Word Cloud’s filters. Try a broader scope or a different lens.")
        case .places:
            appWords("wordcloud.lens.noTerms.places",
                     "This scope’s documents were read, but no place name in them passed the Word Cloud’s filters. Try a broader scope or a different lens.")
        case .organizations:
            appWords("wordcloud.lens.noTerms.organizations",
                     "This scope’s documents were read, but no organization’s name in them passed the Word Cloud’s filters. Try a broader scope or a different lens.")
        case .descriptors:
            appWords("wordcloud.lens.noTerms.descriptors",
                     "This scope’s documents were read, but none of their adjectives passed the Word Cloud’s filters. Try a broader scope or a different lens.")
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
        }
    }

    /// `WordCloudLens.label`, the lens bar's name.
    static func label(_ lens: WordCloudLens) -> String {
        switch lens {
        case .allTerms: appWords("wordcloud.lens.all", "All terms")
        case .people: appWords("wordcloud.lens.people", "People")
        case .places: appWords("wordcloud.lens.places", "Places")
        case .organizations: appWords("wordcloud.lens.orgs", "Organizations")
        case .topics: appWords("wordcloud.lens.topics", "Topics (nouns)")
        case .actions: appWords("wordcloud.lens.actions", "Actions (verbs)")
        case .descriptors: appWords("wordcloud.lens.descriptors", "Descriptors (adjectives)")
        case .concepts: appWords("wordcloud.lens.concepts", "Concepts")
        case .sentiment: appWords("wordcloud.lens.sentiment", "Sentiment")
        }
    }

    /// `WordCloudLens.shortLabel`, the chip's name.
    static func shortLabel(_ lens: WordCloudLens) -> String {
        switch lens {
        case .allTerms: appWords("wordcloud.lens.short.all", "All terms")
        case .people: appWords("wordcloud.lens.short.people", "People")
        case .places: appWords("wordcloud.lens.short.places", "Places")
        case .organizations: appWords("wordcloud.lens.short.orgs", "Organizations")
        case .topics: appWords("wordcloud.lens.short.topics", "Topics")
        case .actions: appWords("wordcloud.lens.short.actions", "Actions")
        case .descriptors: appWords("wordcloud.lens.short.descriptors", "Descriptors")
        case .concepts: appWords("wordcloud.lens.short.concepts", "Concepts")
        case .sentiment: appWords("wordcloud.lens.short.sentiment", "Sentiment")
        }
    }

    static func lens(_ lens: WordCloudLens) -> CloudLens {
        CloudLens(id: lens.rawValue, label: label(lens), shortLabel: shortLabel(lens), colorsBySentiment: lens.colorsBySentiment,
                  available: WordCloudLive.tagger.health.supports(lens))
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
    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources, users: SearchUsers) {
        router.get("/api/v1/cloud/context") { request, _ -> CloudContext in
            try FormQuery(request.uri.query).refuseUnknown([])
            return try await Blocking.run { context(resources: resources) }
        }
        // A scope's cloud: 200 with its words, or 202 while a job counts it, which `job` names (PLAN's S29e); under
        // Distinctive, with the kit's ranking of them (PLAN's S29f).
        router.get("/api/v1/cloud") { request, context -> EditedResponse<CloudAnswer> in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["scope", "lens", "measure", "hidden"])
            let scope = try scope(query.single("scope"))
            let lens = try lens(query.single("lens"))
            let measure = try query.choice("measure", among: KeynessCloudMeasure.allCases) ?? .frequency
            let hidden = try hiddenWords(query, measure: measure)
            let reader = try await reader(for: request, context: context, users: users)
            // A count within the request stops when its client goes, as the app's stops when another replaces it.
            let answer = try await context.whileClientConnected {
                try await cloud(scope, lens: lens, reader: reader, provider: provider, resources: resources, services: users.services,
                                measure: measure, hidden: hidden)
            }
            return EditedResponse(status: answer.state == "counting" ? .accepted : .ok, headers: [.cacheControl: "no-store"], response: answer)
        }
        // A count's job, which the page follows until it ends: a word cloud's alone, by its id (PLAN's S29e).
        router.get("/api/v1/cloud/jobs/:jobId") { request, context -> EditedResponse<CloudJob> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let id = try context.parameters.require("jobId")
            guard let jobs = users.services?.jobs, let job = await jobs.job(id), job.kind == .wordCloud else {
                throw APIProblem(.notFound, code: "JOB_NOT_FOUND", detail: "No word cloud is being counted by a job with the id \(id).")
            }
            return EditedResponse(headers: [.cacheControl: "no-store"], response: CloudJob(job))
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
        // By Subject (`subjectScopeMenu`): a category is a heading, and each of its sub-categories a scope (#1040).
        var subjects: [CloudSubjectCategory] = []
        if let resolved = CorpusAnalyticsRoutes.detectedTopics(resources), !resolved.isEmpty {
            subjects = ScopeFacets.narrowingCategories(resolvedByVolume: resolved).map { category in
                CloudSubjectCategory(label: category.label,
                                     subcategories: ScopeFacets.subCategoryCatalog(forCategory: category.label, resolvedByVolume: resolved)
                                        .map(\.subcategory))
            }
        }
        let range = ChronologyRoutes.defaultRange(entries)
        return CloudContext(lenses: CloudRules.lenses.map(CloudRules.lens),
                            measures: KeynessCloudMeasure.allCases.map { CloudMeasure(id: $0.rawValue, label: CloudRules.measureLabel($0)) },
                            corpus: appWords("wordcloud.scope.corpus", "Entire Corpus"),
                            subseries: subseries, subjects: subjects, dateRange: CloudDateRange(from: range.from, to: range.to), made: made)
    }

    /// The family's clouds' own account, the web's sentence over the file's provenance, naming the tokenizer that counted
    /// them (PLAN's S29d).
    static func madeLine(_ file: CloudVectorsFile) -> String {
        "These clouds were counted by this server’s own tagger, \(file.provenance.tokenizer), on \(CloudRules.day(file.generated)) from the corpus’s \(grouped(file.provenance.volumeCount)) volumes and \(CountCopy.documents(file.provenance.documentCount, locale: SearchItem.locale)) at the standard settings. Each list keeps the \(grouped(file.provenance.topTermsPerList)) words its scope uses most."
    }

    // MARK: The scope

    /// The scope an address names by the app's signature, read as the app reads it (`WordCloudScope(signature:)`, the
    /// kit's since S29b); the corpus where it names none. One the app would not read as a scope is a bad parameter.
    static func scope(_ raw: String?) throws -> WordCloudScope {
        guard let raw else { return .corpus }
        guard let scope = WordCloudScope(signature: raw) else {
            throw APIProblem.invalidParameter("scope", "must be the app's signature of a scope, such as corpus, sub:<subseries>, vol:<volume>, doc:<volume>/<document>, col:<id>, tag:<id>, search:<id>, scope:<id>, subject:<category> or daterange:<from>..<to>, not \(raw)")
        }
        return scope
    }

    /// The lens an address names, one of the app's nine; the lens bar's first, All terms, where it names none, as the
    /// app's view opens on it.
    static func lens(_ raw: String?) throws -> WordCloudLens {
        guard let raw else { return CloudRules.lenses[0] }
        guard let lens = WordCloudLens(rawValue: raw), CloudRules.lenses.contains(lens) else {
            throw APIProblem.invalidParameter("lens", "must be one of \(CloudRules.lenses.map(\.rawValue).joined(separator: ", ")), the lenses the page offers, not \(raw)")
        }
        return lens
    }

    /// The most words a request may name hidden from its cloud alone: a count keeps no more terms than this.
    static let hiddenLimit = WordCloudLive.termLimit

    /// The words an address names hidden from its cloud alone (#233), which Distinctive ranks without, as the app's view
    /// ranks the terms its cloud shows (PLAN's S29f): each lower-cased, as the app keeps them. Frequency's are left out by
    /// the page, which draws the count's terms, so the field is Distinctive's alone.
    static func hiddenWords(_ query: FormQuery, measure: KeynessCloudMeasure) throws -> Set<String> {
        let words = try query.list("hidden") ?? []
        guard !words.isEmpty else { return [] }
        guard measure == .keyness else {
            throw APIProblem.invalidParameter("hidden", "only Distinctive ranks without the words hidden from a cloud; the page leaves them out of a cloud sized by frequency")
        }
        guard words.count <= hiddenLimit else {
            throw APIProblem.invalidParameter("hidden", "names at most \(hiddenLimit) words, the terms a count keeps, not \(words.count)")
        }
        return Set(words.map { $0.lowercased() })
    }

    /// Whom a cloud is asked for: their settings, and their id where the request acts for one.
    struct Reader: Sendable {
        let settings: CloudSettings
        let user: String?
    }

    /// The reader `request` acts for, with their Word Cloud settings as their synced preferences hold them; no one, with
    /// the app's own settings, for a request that acts for no one.
    static func reader(for request: Request, context: APIRequestContext, users: SearchUsers) async throws -> Reader {
        guard let services = users.services, let user = try await users.requestUser(request, context: context, services: services)
        else { return Reader(settings: .standard, user: nil) }
        return Reader(settings: try await CloudSettings(PreferenceRoutes.syncedPreferences(of: user.id, in: services.store)), user: user.id)
    }

    /// The Word Cloud settings of the user `request` acts for, as their synced preferences hold them, or the app's own
    /// for a request that acts for no one.
    static func settings(for request: Request, context: APIRequestContext, users: SearchUsers) async throws -> CloudSettings {
        try await reader(for: request, context: context, users: users).settings
    }

    /// `scope` resolved for `reader` as the app's `WordCloudScopeResolver.resolve` resolves it: its title, where its
    /// documents come from and whose records it reads. A subseries or a volume the catalogue lacks is refused, as a
    /// record of the reader's that is not theirs, or any for a request that acts for no one, is refused as not found,
    /// where the app's dangling id resolves to nothing: one reader's scopes are never another's. A range whose days do
    /// not read as days is a bad parameter.
    static func resolve(_ scope: WordCloudScope, reader: Reader, services: UserDataServices?,
                        resources: ServerResources) async throws -> CloudResolution {
        func plain(_ title: String, _ documents: CloudResolution.Documents) -> CloudResolution {
            CloudResolution(scope: scope, title: title, documents: documents, owner: nil, members: nil)
        }
        /// The reader whose record a scope names, and their store, or the record's refusal.
        func owner(_ notFound: APIProblem) throws -> (String, any UserDataStore) {
            guard let user = reader.user, let services else { throw notFound }
            return (user, services.store)
        }
        switch scope {
        case .corpus:
            return plain(appWords("wordcloud.scope.corpus", "Entire Corpus"), .corpus)
        case .subseries(let subseriesId):
            let volumeIds = resources.manifest.filter { $0.subseries == subseriesId }.map(\.volumeId)
            guard !volumeIds.isEmpty else {
                throw APIProblem.invalidParameter("scope", "names no subseries of the published catalogue, \(subseriesId)")
            }
            return plain(subseriesId, .volumes(volumeIds))
        case .volume(let volumeId):
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            return plain(resources.volume(volumeId)?.title ?? volumeId, .volumes([volumeId]))
        case .document(let volumeId, let documentId):
            guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
            let title = resources.volume(volumeId)?.title ?? volumeId
            return plain(title, .keys([WordCloudDocumentKey(volumeId: volumeId, documentId: documentId)]))
        case .collection(let id):
            let (user, store) = try owner(CollectionRoutes.notFound(id.uuidString))
            let collection = try await CollectionRoutes.collection(id.uuidString, of: user, in: store)
            let keys = collection.entries.map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
            return CloudResolution(scope: scope, title: CollectionEditorNaming.listName(savedName: collection.name),
                                   documents: .keys(keys), owner: user, members: nil)
        case .userTag(let id):
            let notFound = APIProblem(.notFound, code: "TAG_NOT_FOUND", detail: "You have no tag with the id \(id.uuidString).")
            let (user, store) = try owner(notFound)
            let wanted = SearchUsers.caseFolded(id.uuidString)
            let (tags, assignments) = try await Blocking.run { (try store.tags(of: user), try store.tagAssignments(of: user)) }
            guard let tag = tags.first(where: { SearchUsers.caseFolded($0.id) == wanted }) else { throw notFound }
            // The documents the reader's assignments of the tag are on, each once, as `documentKeys(forUserTagId:)` reads the
            // index's rows that an attached store's assignments name.
            var seen = Set<WordCloudDocumentKey>()
            let keys = assignments.filter { SearchUsers.caseFolded($0.tagId) == wanted }
                .map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
                .filter { seen.insert($0).inserted }
            return CloudResolution(scope: scope, title: tag.name, documents: .keys(keys), owner: user, members: nil)
        case .savedSearch(let id):
            let (user, store) = try owner(SavedSearchRoutes.notFound(id.uuidString))
            let saved = try await SavedSearchRoutes.savedSearch(id.uuidString, of: user, in: store)
            return CloudResolution(scope: scope, title: saved.name, documents: .search(saved.parameters, user: user), owner: user, members: nil)
        case .customScope(let id):
            let (user, store) = try owner(VolumeScopeRoutes.notFound(id.uuidString))
            let record = try await VolumeScopeRoutes.scope(id.uuidString, of: user, in: store)
            return CloudResolution(scope: scope, title: record.name, documents: .volumes(record.volumeIds), owner: user,
                                   members: record.volumeIds)
        case .subjectCategory(let category, let subcategory):
            // The subjects by volume the scope bars read; none without the subject data, an explicitly empty cloud.
            let resolved = try await Blocking.run { CorpusAnalyticsRoutes.detectedTopics(resources) ?? [:] }
            let volumeIds = subcategory.map {
                ScopeFacets.volumeIds(forCategory: category, subcategory: $0, resolvedByVolume: resolved)
            } ?? ScopeFacets.volumeIds(forCategory: category, resolvedByVolume: resolved)
            return plain(subcategory.map { "\(category) · \($0)" } ?? category, .volumes(volumeIds.sorted()))
        case .dateRange(let startISO, let endISO):
            guard WordCloudScope.day(fromISO: startISO) != nil, WordCloudScope.day(fromISO: endISO) != nil else {
                throw APIProblem.invalidParameter("scope", "a range of dates is daterange:<yyyy-MM-dd>..<yyyy-MM-dd>, not daterange:\(startISO)..\(endISO)")
            }
            return plain(WordCloudScope.dateRangeTitle(startISO: startISO, endISO: endISO),
                         .dateRange(DateRange(earliest: startISO, latest: endISO)))
        }
    }

    /// The scope of the family's files a scope of the catalogue's is, the corpus, a subseries or a volume, which
    /// `resolve` has checked; none for another.
    static func familyScope(_ scope: WordCloudScope, resources: ServerResources) -> CloudScope? {
        switch scope {
        case .corpus: .corpus
        case .subseries(let id): .subseries(id)
        case .volume(let volumeId): resources.volume(volumeId).map { .volume(volumeId: $0.volumeId, subseries: $0.subseries) }
        case .document, .collection, .userTag, .savedSearch, .customScope, .subjectCategory, .dateRange: nil
        }
    }

    // MARK: The cloud

    /// `scope`'s cloud under `lens` for `reader` (PLAN's S29e). A lens the server's tagger cannot serve is not counted.
    /// The corpus, a subseries and a volume are the family's lists at the family's settings; under others they are
    /// counted from the documents the served index holds of them, and with no index served, or none of their documents
    /// in it, the family's list is filtered by the settings; a scope the family holds no list of its own of, such as a
    /// volume side-loaded under an id the generator never counted, is counted wherever the index holds it. Every other
    /// scope is counted, with an index served. A count kept answers at once; one that outlasts a request is `counting`,
    /// with its job. Under Distinctive (PLAN's S29f) the three are counted at any settings, as the app's view counts
    /// every scope it ranks, since a family's list is too short a pool, and a count with words to draw carries the kit's
    /// ranking of them, less `hidden`; a family's list stood in for a count says why there is none.
    static func cloud(_ scope: WordCloudScope, lens: WordCloudLens, reader: Reader, provider: ServedIndexProvider,
                      resources: ServerResources, services: UserDataServices?, measure: KeynessCloudMeasure = .frequency,
                      hidden: Set<String> = []) async throws -> CloudAnswer {
        let resolution = try await resolve(scope, reader: reader, services: services, resources: resources)
        // A record with no name is the scope bar's Untitled, so the cloud's heading is never empty.
        let heading = resolution.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? appWords("wordcloud.scope.untitled", "Untitled") : resolution.title
        var answer = CloudAnswer(scope: .init(signature: scope.signature, title: heading), lens: CloudRules.lens(lens),
                                 chip: CloudRules.chip(lens: lens, fallbackSubseries: nil), fallbackSubseries: nil, source: "live",
                                 state: "noTerms", message: nil, countLine: nil, terms: [], listed: 0, removed: 0,
                                 settingsNotShown: nil, analyzeWithin: nil)
        // `WordCloudDisplayState.resolve`'s check before any count: a lens whose tagger cannot serve it is not counted, and
        // needs no index to say so.
        let health = WordCloudLive.tagger.health
        guard health.supports(lens) else {
            let indexed = (try? await provider.servedIfReady())??.indexedVolumeIds ?? []
            answer.analyzeWithin = CloudRules.analyzeWithin(resolution, indexed: indexed, resources: resources)
            answer.state = "lensUnavailable"
            answer.message = CloudRules.lensUnavailable(lens, health: health)
            return answer
        }
        let served: ServedIndex
        if let familyScope = familyScope(scope, resources: resources) {
            let (atTheFamilys, ownList) = try await Blocking.run { () -> (Bool, Bool) in
                let directory = resources.languageDirectory
                let core = try? resources.familyClouds.core.value(in: directory).get()
                let volumes: CloudVectorsFile? = if case .volume = familyScope { try? resources.familyClouds.volumes.value(in: directory).get() } else { nil }
                // The scope's own list: neither its era's, for a volume the family holds none of or flagged thin, nor none.
                let found = CloudRules.terms(forScope: familyScope, lens: lens, core: core, volumes: volumes)
                return (core.map { reader.settings.areTheFamilys($0, lens: lens) } ?? false, found != nil && found?.fallbackSubseries == nil)
            }
            // At the family's settings the scope's own list, which needs no index, but for Distinctive, which ranks a count.
            // Under others, or where the family holds no list of the scope's own, a count of the documents the index holds
            // of it; with no index served, one being installed, or none of its documents in it, the family's list filtered
            // by the settings, which Distinctive cannot rank.
            let held = atTheFamilys && ownList && measure == .frequency ? nil : (try? await provider.servedIfReady()) ?? nil
            guard let held, holdsText(resolution, served: held) else {
                var family = try await Blocking.run { Self.answer(familyScope, lens: lens, settings: reader.settings, resources: resources) }
                if measure == .keyness, family.state == "terms" { family.distinctive = CloudRules.withoutCount }
                return family
            }
            served = held
        } else {
            served = try await provider.served()
        }
        answer.analyzeWithin = CloudRules.analyzeWithin(resolution, indexed: served.indexedVolumeIds, resources: resources)
        let lexicons = try await Blocking.run { resources.familyClouds.lexicons(in: resources.directory) }
        let hasReader = reader.user != nil
        // Under Distinctive, the family's references as the kit reads them, decoded once (PLAN's S29f).
        let references = measure == .keyness
            ? try await Blocking.run { resources.familyClouds.references(language: resources.languageDirectory, lists: resources.directory) }
            : nil
        /// A count's answer, ranked under Distinctive when it has words to draw, as the app's main area ranks only those.
        func counted(_ result: WordCloudResult, settings: CloudSettings) -> CloudAnswer {
            var counted = answer
            CloudRules.live(result, into: &counted, lens: lens, settings: settings, hasReader: hasReader, lexicons: lexicons)
            if let references, counted.state == "terms" {
                counted.distinctive = CloudRules.distinctive(result, lens: lens, settings: settings, hidden: hidden,
                                                             references: references, lexicons: lexicons)
            }
            return counted
        }
        let heavy = WordCloudLive.isHeavy(scope)
        // The documents, read here for a count within the request and for a scope of a reader's own, which its count is
        // kept by; a heavy scope's job reads its own.
        let keys = heavy ? nil : try await WordCloudLive.keys(resolution, served: served, services: services)
        let key = WordCloudLive.key(resolution, lens: lens, settings: reader.settings, keys: keys)
        let keeper = served.wordClouds
        if let kept = await keeper.result(for: key) {
            return counted(kept, settings: reader.settings)
        }
        if let services, heavy || (keys?.count ?? 0) > WordCloudLive.requestLimit {
            let job = try await WordCloudLive.job(resolution, key: key, lens: lens, settings: reader.settings, keeper: keeper,
                                                  provider: provider, resources: resources, services: services, requestedBy: reader.user)
            // A job that ended between the two reads has kept its count.
            if let kept = await keeper.result(for: key) {
                return counted(kept, settings: reader.settings)
            }
            answer.state = "counting"
            answer.message = CloudRules.countingMessage(scope)
            answer.job = CloudJob(job)
            return answer
        }
        let documents: [WordCloudDocumentKey]
        if let keys { documents = keys } else { documents = try await WordCloudLive.keys(resolution, served: served, services: services) }
        let settings = reader.settings
        // Within the request, in its turn: a burst of requests takes the gate's turns, never every processor.
        let result = try await WordCloudLive.gate.run {
            try await WordCloudLive.count(documents, lens: lens, settings: settings, served: served, resources: resources)
        }
        await keeper.keep(result, for: key)
        return counted(result, settings: settings)
    }

    /// Whether the served index holds any of a family scope's documents: any volume, for the corpus, or any of the
    /// catalogue's volumes of a subseries, or the volume.
    static func holdsText(_ resolution: CloudResolution, served: ServedIndex?) -> Bool {
        guard let indexed = served?.indexedVolumeIds, !indexed.isEmpty else { return false }
        switch resolution.documents {
        case .corpus: return true
        case .volumes(let ids): return ids.contains { indexed.contains($0) }
        case .keys, .search, .dateRange: return true
        }
    }

    /// One scope's cloud under one lens from the family's files, its list filtered by `settings`.
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
                                 fallbackSubseries: resolved?.fallbackSubseries, source: "family", state: "noCloud",
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
                                   // The web's own: the app samples the last All terms cloud its device counted and kept on disk,
                                   // which a server, keeping its counts for its served index and for no one reader, has not.
                                   provenance: "A stand-in sample, as the app’s own when its device has kept no counted cloud of its own to sample.")
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
