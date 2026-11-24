// The Word Cloud (PLAN's S24i), over the language family's files since S29d: the clouds equal the file's lists. Every
// cloud the API gives, for the corpus, each subseries and each volume of the catalogue under each of the four lenses the
// page draws, is held to the family's file's own list, read from resources/language apart from the server by the kit's
// `CloudVectorsFile(contentsOf:)` and de-indexed as the app's `BundledCloudVectors.list(in:scope:lens:)` does, a volume
// whose own list the generator flagged thin answered with its era's, as the app's rule answers it; at the app's own
// settings the reader's filters keep every word of it, since the generator counted each list under them. A reader's
// other settings are held to the kit's tokenizer, assembled here apart from the server as the app's settings bench
// assembles it, with the settings the clouds cannot show named by the kit's own rule; and the fall-back, the de-indexing
// and the states, over values too. The family's identity, its staleness and its refusals are LanguageFamilyParityTests'.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing
import WordCloudKit

@testable import FRUSLightAPI

@Suite struct WordCloudParityTests {
    /// The family's files and the app's lists as a host decodes them with the kit's loaders, apart from the server's.
    struct Host: @unchecked Sendable {
        let core: CloudVectorsFile
        let volumes: CloudVectorsFile
        let stopwords: WordCloudStopwordSet
        let lexicons: WordCloudLexiconSet
        let catalogue: [VolumeManifestEntry]

        static func open() throws -> Host {
            let directory = ServedFixture.resources
            func at(_ name: String) -> URL { directory.appendingPathComponent(name) }
            func family(_ name: String) -> URL { RepositoryFiles.language.appendingPathComponent(name) }
            return Host(core: try CloudVectorsFile(contentsOf: family("cloud-vectors-core.json")),
                        volumes: try CloudVectorsFile(contentsOf: family("cloud-vectors-volumes.json")),
                        stopwords: try WordCloudStopwordSet(contentsOf: at("word-cloud-stopwords.json")),
                        lexicons: try WordCloudLexiconSet(contentsOf: at("word-cloud-lexicons.json")),
                        catalogue: try FixedVolumeCatalogue(contentsOf: at("manifest.json")).citableEntries)
        }

        /// The file's own list for a scope under a lens, each entry's index read in the shared vocabulary.
        static func list(_ file: CloudVectorsFile, _ scope: String, _ lens: WordCloudLens) -> [String] {
            (file.scopes[scope]?.lists[lens.rawValue]?.entries ?? []).map { "\(file.vocabulary[$0.term]) \($0.count)" }
        }

        /// The list the app's rule answers a scope with, read here apart from the server: the corpus's or a subseries'
        /// own, and a volume's own unless the generator flagged it below its lens's signal threshold or holds none, when
        /// its subseries' stands in, which the chip names.
        func answered(_ scope: CloudScope, _ lens: WordCloudLens) -> (list: [String], fallback: String?) {
            switch scope {
            case .corpus:
                return (Host.list(core, "corpus", lens), nil)
            case .subseries(let id):
                return (Host.list(core, id, lens), nil)
            case .volume(let id, let subseries):
                if let own = volumes.scopes[id]?.lists[lens.rawValue], !own.entries.isEmpty, !own.belowSignalThreshold {
                    return (Host.list(volumes, id, lens), nil)
                }
                return (Host.list(core, subseries, lens), subseries)
            }
        }

        /// The stored lists as the app's settings read them (`SettingsSyncCoordinator.decodeStringArray`,
        /// `WordCloudSettings.lensStopwordMap`), decoded here apart from the server's own readers.
        static func global(_ json: String) -> [String] {
            json.isEmpty ? [] : (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
        }

        static func lenses(_ json: String) -> [String: [String]] {
            (try? JSONDecoder().decode([String: [String]].self, from: Data(json.utf8))) ?? [:]
        }

        /// What a reader's settings keep of a list, as the app's settings bench keeps it: the tokenizer the app
        /// assembles (`WordCloudTokenizer.configured`) over the bundled lists, and the minimum count.
        func kept(_ terms: [String], lens: WordCloudLens, tuning: WordCloudTuning, includeDiplomatic: Bool,
                  global: [String], lensWords: [String]) -> [String] {
            let tokenizer = WordCloudTokenizer(
                stopwords: stopwords.active(includeDiplomatic: includeDiplomatic).union(Set(global).union(lensWords)),
                minimumLength: tuning.minimumLength, foldPlurals: tuning.foldPlurals, lens: lens,
                lexicon: lexicons.filter(for: lens), markings: tuning.filterMarkings ? stopwords.markings : [])
            return terms.filter { line in
                let parts = line.split(separator: " ")
                return Int(parts[1])! >= tuning.minimumCount && tokenizer.accepts(String(parts[0]).lowercased())
            }
        }
    }

    /// A server over the app's data files and the family's that keeps no user data, so every request reads the clouds at
    /// the app's own settings; the clouds need nothing indexed.
    static func run<T: Sendable>(_ body: @escaping @Sendable (any TestClientProtocol) async throws -> T) async throws -> T {
        let directory = try TemporaryDirectory()
        defer { withExtendedLifetime(directory) {} }
        let app = try await buildApplication(configuration: ServerConfiguration(
            dataDirectory: directory.url.appendingPathComponent("data"), resourcesDirectory: ServedFixture.resources,
            languageDirectory: RepositoryFiles.language, userData: false))
        return try await app.test(.router) { client in try await body(client) }
    }

    static let lenses: [WordCloudLens] = [.topics, .actions, .concepts, .sentiment]

    @Test func everyCloudIsTheFilesList() async throws {
        let host = try Host.open()
        let subseries = CloudRules.subseriesList(host.catalogue)
        #expect(subseries.count == 107 && Set(subseries) == Set(host.core.scopes.keys).subtracting(["corpus"]),
                "the catalogue's subseries are the core file's")
        let checked = try await Self.run { client in
            let context = try ServedFixture.decode(CloudContext.self, try await client.execute(uri: "/api/v1/cloud/context", method: .get))
            #expect(context.lenses.map(\.id) == Self.lenses.map(\.rawValue), "the lens bar's order")
            #expect(context.lenses.map(\.label) == ["Topics (nouns)", "Actions (verbs)", "Concepts", "Sentiment"])
            #expect(context.lenses.map(\.shortLabel) == ["Topics", "Actions", "Concepts", "Sentiment"])
            #expect(context.lenses.map(\.colorsBySentiment) == [false, false, false, true])
            #expect(context.measures.map(\.label) == ["Frequency", "Distinctive"] && context.corpus == "Entire Corpus")
            #expect(context.subseries.map(\.id) == subseries)
            #expect(context.subseries.flatMap(\.volumes).map(\.id) == subseries.flatMap { id in host.catalogue.filter { $0.subseries == id }.map(\.volumeId) })
            #expect(context.subseries.flatMap(\.volumes).map(\.title)
                    == subseries.flatMap { id in host.catalogue.filter { $0.subseries == id }.map { $0.title.isEmpty ? $0.volumeId : $0.title } })
            let made = try #require(context.made)
            #expect(made.generated == host.core.generated && made.volumeCount == 553 && made.documentCount == host.core.provenance.documentCount)
            #expect(made.family == FamilyClouds.family.description && made.family.hasPrefix("FRUSLanguage "), "the account names the family")
            #expect(made.line.hasPrefix("These clouds were counted by this server’s own tagger, \(FamilyClouds.family), on \(CloudRules.day(host.core.generated)) from the corpus’s 553 volumes and \(grouped(host.core.provenance.documentCount)) documents at the standard settings."),
                    "\(made.line)")

            var count = 0
            var fallbacks = 0
            for lens in Self.lenses {
                var scopes: [(signature: String, scope: CloudScope, title: String)] = [("corpus", .corpus, "Entire Corpus")]
                scopes += subseries.map { ("sub:\($0)", .subseries($0), $0) }
                scopes += host.catalogue.map { ("vol:\($0.volumeId)", .volume(volumeId: $0.volumeId, subseries: $0.subseries), $0.title) }
                for scope in scopes {
                    let path = "/api/v1/cloud?scope=\(scope.signature.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)&lens=\(lens.rawValue)"
                    let response = try await client.execute(uri: path, method: .get)
                    guard response.status == .ok else { throw APIParityError("\(path): \(response.status.code) \(String(buffer: response.body))") }
                    let answer = try ServedFixture.decode(CloudAnswer.self, response)
                    let (list, fallback) = host.answered(scope.scope, lens)
                    #expect(!list.isEmpty, "\(scope.signature) \(lens) has a list")
                    #expect(answer.terms.map { "\($0.term) \($0.count)" } == list, "\(scope.signature) \(lens)")
                    #expect(answer.state == "terms" && answer.message == nil && answer.fallbackSubseries == fallback, "\(scope.signature) \(lens)")
                    #expect(answer.listed == list.count && answer.removed == 0 && answer.settingsNotShown == nil, "\(scope.signature) \(lens)")
                    #expect(answer.countLine == "\(list.count) terms", "\(scope.signature) \(lens)")
                    #expect(answer.chip == (fallback.map { "\(answer.lens.shortLabel) · \($0) (era)" } ?? answer.lens.shortLabel), "\(scope.signature) \(lens)")
                    #expect(answer.scope == .init(signature: scope.signature, title: scope.title), "\(scope.signature)")
                    count += 1
                    if answer.fallbackSubseries != nil { fallbacks += 1 }
                }
            }
            return (count, fallbacks)
        }
        #expect(checked.0 == 4 * (1 + 107 + 553), "every cloud: \(checked.0)")
        let thin = host.catalogue.reduce(0) { sum, volume in
            sum + Self.lenses.filter { lens in
                let own = host.volumes.scopes[volume.volumeId]?.lists[lens.rawValue]
                return own == nil || own!.entries.isEmpty || own!.belowSignalThreshold
            }.count
        }
        #expect(checked.1 == thin, "the server answers each volume's list the generator flagged thin, or holds none of, with its era's: \(checked.1) of \(thin)")
        #expect(thin == 0, "the family's files flag no volume's list thin in the four lenses, so the fall-back is held over values below")
    }

    /// A reader's settings keep what the kit's tokenizer keeps of each list, and the settings the family's clouds cannot
    /// show are the kit's mismatches, in the app's words.
    @Test func aReadersSettingsKeepWhatTheKitsTokenizerKeeps() throws {
        let host = try Host.open()
        let resources = try ServerResources.load(from: ServedFixture.resources, language: RepositoryFiles.language)
        let initial = PreferenceRoutes.initial(at: Date(timeIntervalSince1970: 0))
        func settings(minLength: Int = 3, minCount: Int = 1, fold: Bool = true, markings: Bool = true, boilerplate: Bool = true,
                      global: String = "", lens: String = "") -> SyncedPreferencesExport {
            var preferences = initial
            preferences.wcMinLength = minLength
            preferences.wcMinCount = minCount
            preferences.wcFoldPlurals = fold
            preferences.wcFilterMarkings = markings
            preferences.wcExcludeBoilerplate = boilerplate
            preferences.wcGlobalStopwordsJSON = global
            preferences.wcLensStopwordsJSON = lens
            return preferences
        }
        let corpusTopics = Host.list(host.core, "corpus", .topics).map { String($0.split(separator: " ")[0]) }
        let variants: [(name: String, preferences: SyncedPreferencesExport, notShown: String?)] = [
            ("the app's own", initial, nil),
            ("longer words, a higher count", settings(minLength: 7, minCount: 40_000), nil),
            ("hidden words", settings(global: #"["\#(corpusTopics[0])","\#(corpusTopics[3])","Upper"]"#,
                                      lens: #"{"topics":["\#(corpusTopics[1])"],"sentiment":["support","peace"],"concepts":["security"]}"#), nil),
            ("unreadable lists", settings(global: "not json", lens: "[]"), nil),
            ("every setting that adds", settings(minLength: 2, fold: false, markings: false, boilerplate: false),
             "These clouds were counted once, at the standard settings, so your settings can take words out of them but cannot count them differently: plural folding differs; classification-marking filtering differs; “Hide common diplomatic words” is off; your minimum word length is shorter."),
            ("plurals alone", settings(minCount: 2, fold: false),
             "These clouds were counted once, at the standard settings, so your settings can take words out of them but cannot count them differently: plural folding differs."),
        ]
        let scopes: [CloudScope] = [.corpus, .subseries("1969-76"), .subseries("1861"), .volume(volumeId: "frus1961-63v06", subseries: "1961-63"),
                                    .volume(volumeId: "frus1969-76ve09p1", subseries: "1969-76"), .volume(volumeId: "frus1894Nicaragua", subseries: "1894")]
        var removedSomewhere = false
        for variant in variants {
            let cloud = CloudSettings(variant.preferences)
            let global = Host.global(variant.preferences.wcGlobalStopwordsJSON)
            let lensMap = Host.lenses(variant.preferences.wcLensStopwordsJSON)
            for scope in scopes {
                for lens in Self.lenses {
                    let answer = WordCloudRoutes.answer(scope, lens: lens, settings: cloud, resources: resources)
                    let list = host.answered(scope, lens).list
                    let tuning = WordCloudTuning(settingsMinimumLength: variant.preferences.wcMinLength, minimumCount: variant.preferences.wcMinCount,
                                                 foldPlurals: variant.preferences.wcFoldPlurals, filterMarkings: variant.preferences.wcFilterMarkings)
                    let kept = host.kept(list, lens: lens, tuning: tuning, includeDiplomatic: variant.preferences.wcExcludeBoilerplate,
                                         global: global, lensWords: lensMap[lens.rawValue] ?? [])
                    #expect(answer.terms.map { "\($0.term) \($0.count)" } == kept, "\(variant.name): \(scope) \(lens)")
                    #expect(answer.listed == list.count && answer.removed == list.count - kept.count, "\(variant.name): \(scope) \(lens)")
                    #expect(answer.settingsNotShown == variant.notShown, "\(variant.name): \(scope) \(lens)")
                    let expected = kept.isEmpty ? "noTerms" : lens.isSignalDependent && kept.count < lens.minimumSignalTerms ? "insufficientSignal" : "terms"
                    #expect(answer.state == expected, "\(variant.name): \(scope) \(lens)")
                    removedSomewhere = removedSomewhere || answer.removed > 0
                }
            }
        }
        #expect(removedSomewhere, "the settings take words out somewhere")
        // The settings bench's stand-in sample, which holds diplomatic words, markings and short and rare words, so the
        // layers the bundled lists already left out are read here: every variant, under every lens of the app's nine.
        let sample = CloudRules.canonicalSample.map { "\($0.term) \($0.count)" }
        var benchKept: Set<Int> = []
        for variant in variants {
            let cloud = CloudSettings(variant.preferences)
            let tuning = WordCloudTuning(settingsMinimumLength: variant.preferences.wcMinLength, minimumCount: variant.preferences.wcMinCount,
                                         foldPlurals: variant.preferences.wcFoldPlurals, filterMarkings: variant.preferences.wcFilterMarkings)
            for lens in WordCloudLens.allCases {
                let server = cloud.kept(CloudRules.canonicalSample, lens: lens, stopwords: host.stopwords, lexicons: host.lexicons)
                let kept = host.kept(sample, lens: lens, tuning: tuning, includeDiplomatic: variant.preferences.wcExcludeBoilerplate,
                                     global: Host.global(variant.preferences.wcGlobalStopwordsJSON),
                                     lensWords: Host.lenses(variant.preferences.wcLensStopwordsJSON)[lens.rawValue] ?? [])
                #expect(server.map { "\($0.term) \($0.count)" } == kept, "the bench, \(variant.name): \(lens)")
                if lens == .allTerms { benchKept.insert(kept.count) }
            }
        }
        #expect(benchKept.count > 2, "the variants keep different parts of the sample: \(benchKept.sorted())")
        let allTerms = CloudSettings(initial).kept(CloudRules.canonicalSample, lens: .allTerms, stopwords: host.stopwords, lexicons: host.lexicons).map(\.term)
        #expect(!allTerms.contains("telegram") && !allTerms.contains("confidential") && allTerms.contains("war"),
                "the app's own settings leave the diplomatic word and the marking out, and keep a short word")
        // The kit's rule names what each setting would let in, and the generator's own configuration nothing.
        let file = host.core
        #expect(CloudSettings(initial).notShown(byCloudsOf: file).isEmpty)
        #expect(CloudSettings(settings(minLength: 4, minCount: 9)).notShown(byCloudsOf: file).isEmpty, "a setting that only takes words out")
        #expect(CloudSettings(settings(minLength: 2)).notShown(byCloudsOf: file) == [.minimumLength])
        #expect(file.provenance.tuning == .standard, "the family's clouds were counted at the standard tuning")
        #expect(file.provenance.tokenizer == FamilyClouds.family, "the family's clouds name the server's tagger")
        // A file another tokenizer counted, such as the app's, is filtered by the same rule over its own counts.
        let hosted = CloudVectorsFile(version: 1, generated: "2026-11-24", provenance: .init(
            volumeCount: 3, documentCount: 393, tuning: .standard, topTermsPerList: 50,
            tokenizer: WordCloudTokenizerIdentity(name: "web", version: "1")), lenses: [], vocabulary: [], scopes: [:])
        #expect(CloudSettings(initial).notShown(byCloudsOf: hosted).isEmpty, "a file's own tokenizer is not another's")
        #expect(CloudSettings(settings(minLength: 2)).notShown(byCloudsOf: hosted) == [.minimumLength])
        #expect(CloudRules.mismatchDescription([.tokenizer]) == "the reference was counted by another tokenizer")
    }

    /// The hidden words are lowercased by the settings that keep them, and compared with each term lowercased; a word
    /// kept in another case is not one the cloud hides, as the app's lists compare.
    @Test func theHiddenWordsCompareAsTheAppsLists() throws {
        let resources = try ServerResources.load(from: ServedFixture.resources, language: RepositoryFiles.language)
        var preferences = PreferenceRoutes.initial(at: Date(timeIntervalSince1970: 0))
        let first = try #require(WordCloudRoutes.answer(.corpus, lens: .topics, settings: CloudSettings(preferences), resources: resources).terms.first)
        preferences.wcGlobalStopwordsJSON = #"["\#(first.term.uppercased())"]"#
        #expect(WordCloudRoutes.answer(.corpus, lens: .topics, settings: CloudSettings(preferences), resources: resources).terms.first == first)
        preferences.wcGlobalStopwordsJSON = #"["\#(first.term)"]"#
        let hidden = WordCloudRoutes.answer(.corpus, lens: .topics, settings: CloudSettings(preferences), resources: resources)
        #expect(!hidden.terms.contains(first) && hidden.removed == 1)
        preferences.wcGlobalStopwordsJSON = ""
        preferences.wcLensStopwordsJSON = #"{"actions":["\#(first.term)"]}"#
        #expect(WordCloudRoutes.answer(.corpus, lens: .topics, settings: CloudSettings(preferences), resources: resources).terms.first == first,
                "another lens's list hides nothing here")
    }

    /// Every sentiment word the files record carries the polarity the kit's lexicon gives it, which is what the cloud
    /// colours it by, as the app's view does.
    @Test func theSentimentWordsCarryTheLexiconsPolarity() throws {
        let host = try Host.open()
        var read = 0
        for file in [host.core, host.volumes] {
            for scope in file.scopes.values {
                for entry in scope.lists["sentiment"]?.entries ?? [] {
                    #expect(host.lexicons.polarity(of: file.vocabulary[entry.term].lowercased()) == entry.polarity,
                            "\(file.vocabulary[entry.term])")
                    read += 1
                }
            }
        }
        #expect(read == 661 * 50, "every scope's sentiment list holds fifty words")
        let resources = try ServerResources.load(from: ServedFixture.resources, language: RepositoryFiles.language)
        let answer = WordCloudRoutes.answer(.corpus, lens: .sentiment, settings: .standard, resources: resources)
        #expect(answer.terms.allSatisfy { $0.polarity == host.lexicons.polarity(of: $0.term) } && answer.terms.contains { $0.polarity == -1 })
        #expect(WordCloudRoutes.answer(.corpus, lens: .concepts, settings: .standard, resources: resources).terms.allSatisfy { $0.polarity == nil })
    }

    /// What the shipped files need not reach, held over values: a volume whose
    /// own list is thin, missing or unread takes its subseries' list, and the chip names the era; an index outside the
    /// vocabulary is dropped; and the states of a list kept too thin or emptied.
    @Test func aThinVolumeTakesItsErasListAndTheChipSaysSo() {
        let provenance = CloudVectorsFile.Provenance(volumeCount: 2, documentCount: 9, tuning: .standard, topTermsPerList: 50)
        func list(_ entries: [(Int, Int)], thin: Bool = false) -> CloudVectorsFile.ScopeVectors {
            .init(lists: ["concepts": .init(total: 99, entries: entries.map { .init(term: $0.0, count: $0.1) }, belowSignalThreshold: thin)])
        }
        let core = CloudVectorsFile(version: 1, generated: "2026-10-12", provenance: provenance, lenses: ["concepts"],
                                    vocabulary: ["sovereignty", "deterrence", "détente"],
                                    scopes: ["corpus": list([(0, 9), (1, 4)]), "1969-76": list([(2, 7), (0, 3), (9, 2)])])
        let volumes = CloudVectorsFile(version: 1, generated: "2026-10-12", provenance: provenance, lenses: ["concepts"],
                                       vocabulary: ["legitimacy", "hegemony"],
                                       scopes: ["frus1969-76v01": list([(0, 5)], thin: true), "frus1969-76v02": list([(1, 6), (0, 1)]),
                                                "frus1969-76v03": list([])])
        func terms(_ scope: CloudScope, volumes: CloudVectorsFile?) -> String {
            guard let found = CloudRules.terms(forScope: scope, lens: .concepts, core: core, volumes: volumes) else { return "none" }
            return found.terms.map { "\($0.term) \($0.count)" }.joined(separator: ", ") + (found.fallbackSubseries.map { " (\($0))" } ?? "")
        }
        #expect(terms(.corpus, volumes: nil) == "sovereignty 9, deterrence 4")
        #expect(terms(.subseries("1969-76"), volumes: nil) == "détente 7, sovereignty 3", "an index outside the vocabulary is dropped")
        #expect(terms(.volume(volumeId: "frus1969-76v02", subseries: "1969-76"), volumes: volumes) == "hegemony 6, legitimacy 1")
        #expect(terms(.volume(volumeId: "frus1969-76v01", subseries: "1969-76"), volumes: volumes) == "détente 7, sovereignty 3 (1969-76)", "thin")
        #expect(terms(.volume(volumeId: "frus1969-76v03", subseries: "1969-76"), volumes: volumes) == "détente 7, sovereignty 3 (1969-76)", "empty")
        #expect(terms(.volume(volumeId: "frus1969-76v09", subseries: "1969-76"), volumes: volumes) == "détente 7, sovereignty 3 (1969-76)", "missing")
        #expect(terms(.volume(volumeId: "frus1969-76v02", subseries: "1969-76"), volumes: nil) == "détente 7, sovereignty 3 (1969-76)", "unread")
        #expect(terms(.volume(volumeId: "frus1969-76v02", subseries: "1961-63"), volumes: nil) == "none")
        #expect(terms(.subseries("1961-63"), volumes: nil) == "none")
        #expect(CloudRules.chip(lens: .concepts, fallbackSubseries: "1969-76") == "Concepts · 1969-76 (era)")
        #expect(CloudRules.chip(lens: .topics, fallbackSubseries: nil) == "Topics")

        let three = [TermCount(term: "a", count: 3), TermCount(term: "b", count: 2), TermCount(term: "c", count: 1)]
        #expect(CloudRules.state(kept: [], lens: .topics) == "noTerms")
        #expect(CloudRules.state(kept: three, lens: .sentiment) == "insufficientSignal")
        #expect(CloudRules.state(kept: three, lens: .concepts) == "insufficientSignal")
        #expect(CloudRules.state(kept: three, lens: .actions) == "terms", "a lens that needs no signal draws any word")
        #expect(CloudRules.state(kept: three + [TermCount(term: "d", count: 1)], lens: .sentiment) == "terms")
        #expect(CloudRules.message(state: "insufficientSignal", lens: .sentiment)?.detail
                == "There aren’t enough sentiment in this scope to fill a cloud. Try a broader scope or a different lens.")
        #expect(CloudRules.message(state: "noTerms", lens: .topics)?.title == "Nothing Found for This Lens")
        #expect(CloudRules.countLine(terms: 1) == "1 term" && CloudRules.countLine(terms: 1_000) == "1,000 terms")
    }
}
