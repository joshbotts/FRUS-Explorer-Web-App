// What the server and the browser app mirror of the app's Word Cloud (PLAN's S24i), held to the app's source at the pin,
// line beside line: `BundledCloudVectors`' reading of a scope's list and `LensChip`'s words; the tokenizer the app
// assembles (`WordCloudTokenizer.configured`) and its settings bench (`WordCloudBench`); `WordCloudSettings`' lists and
// their JSON as `SettingsSyncCoordinator` syncs it; `WordCloudDisplayState`'s states and count line; the scope menu
// (`WordCloudScopeBar`), the scope's title (`WordCloudScopeResolver`) and the scoped hand-off; the generator's layer; the
// browser's layout (`WordCloudLayout`), palette, typefaces and densities, and the settings pane's controls; and every
// word the server writes and copy.ts holds, under the app's key.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct WordCloudMirrorParityTests {
    static let bundled = "Analytics/WordCloud/BundledCloudVectors.swift"
    static let backdrop = "Analytics/WordCloud/WordCloudBackdropView.swift"
    static let configured = "Analytics/WordCloud/WordCloudTokenizer+App.swift"
    static let bench = "Analytics/WordCloud/WordCloudBench.swift"
    static let settings = "Analytics/WordCloud/WordCloudSettings.swift"
    static let sync = "Settings/SettingsSyncCoordinator.swift"
    static let view = "Analytics/WordCloud/WordCloudView.swift"
    static let resolver = "Analytics/WordCloud/WordCloudScopeResolver.swift"
    static let lensUI = "Analytics/WordCloud/WordCloudLens+UI.swift"
    static let keyness = "Analytics/WordCloud/KeynessCloud.swift"
    static let layout = "Analytics/WordCloud/WordCloudLayout.swift"
    static let models = "Analytics/WordCloud/WordCloudModels.swift"
    static let lexicons = "Analytics/WordCloud/WordCloudLexicons.swift"
    static let pane = "Settings/WordCloudSettingsView.swift"
    static let rail = "DocumentView/ResearchRailView.swift"
    static let menu = "App/FRUSExplorerApp.swift"
    static let runner = "kit:CloudVectorsGeneratorCore/CloudVectorsRunner.swift"
    static let server = "Sources/FRUSLightAPI/WordCloud.swift"
    static let preferences = "Sources/FRUSLightAPI/Preferences.swift"

    @Test func theBundledCloudsAreReadAsTheAppReadsThem() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.bundled, #"case .corpus: return list(in: core, scope: CloudVectorsAggregatorScopeKeys.corpus, lens: lens) .map { ($0, .exact) }"#,
             Self.server, #"case .corpus: return list(in: core, scope: corpusKey, lens: lens) .map { ($0, nil) }"#),
            (Self.bundled, #"case .subseries(let id): return list(in: core, scope: id, lens: lens).map { ($0, .exact) }"#,
             Self.server, #"case .subseries(let id): return list(in: core, scope: id, lens: lens).map { ($0, nil) }"#),
            (Self.bundled, #"if let own = list(in: volumes, scope: volumeId, lens: lens), !isBelowSignal(volumes, volumeId, lens) { return (own, .exact) } return list(in: core, scope: subseries, lens: lens) .map { ($0, .subseriesFallback(subseries)) }"#,
             Self.server, #"if let own = list(in: volumes, scope: volumeId, lens: lens), !isBelowSignal(volumes, volumeId, lens) { return (own, nil) } return list(in: core, scope: subseries, lens: lens) .map { ($0, subseries) }"#),
            (Self.bundled, #"file?.scopes[scope]?.lists[lens.rawValue]?.belowSignalThreshold ?? false"#,
             Self.server, #"file?.scopes[scope]?.lists[lens.rawValue]?.belowSignalThreshold ?? false"#),
            (Self.bundled, #"guard let file, let stored = file.scopes[scope]?.lists[lens.rawValue], !stored.entries.isEmpty else { return nil } return stored.entries.compactMap { entry in guard entry.term >= 0, entry.term < file.vocabulary.count else { return nil } return TermCount(term: file.vocabulary[entry.term], count: entry.count) }"#,
             Self.server, #"guard let file, let stored = file.scopes[scope]?.lists[lens.rawValue], !stored.entries.isEmpty else { return nil } return stored.entries.compactMap { entry in guard entry.term >= 0, entry.term < file.vocabulary.count else { return nil } return TermCount(term: file.vocabulary[entry.term], count: entry.count) }"#),
            (Self.bundled, #"static let corpus = "corpus""#,
             Self.server, #"static let corpusKey = "corpus""#),
            (Self.backdrop, #"case .exact: return lens.shortLabel"#,
             Self.server, #"guard let subseries = fallbackSubseries else { return shortLabel(lens) }"#),
            (Self.backdrop, #"defaultValue: "\(lens.shortLabel) · \(subseries) (era)","#,
             Self.server, #"return "\(shortLabel(lens)) · \(subseries) (era)""#),
            (Self.runner, #"let tuning = WordCloudTuning.standard"#,
             Self.server, #"KeynessBaselineFile.Configuration(tuning: file.provenance.tuning,"#),
            (Self.runner, #"let includeDiplomatic = true"#,
             Self.server, #"static let generatorIncludesDiplomatic = true"#),
            (Self.view, #"ForEach(WordCloudLens.allCases) { option in"#,
             Self.server, #"static let lenses: [WordCloudLens] = WordCloudLens.allCases.filter { WordCloudLens.bundledCloudLenses.contains($0) }"#),
        ])
    }

    @Test func theReadersSettingsAreReadAndKeptAsTheAppsAre() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.configured, #"stopwords: WordCloudStopwords.active(includeDiplomatic: includeDiplomatic) .union(extraStopwords),"#,
             Self.server, #"stopwords: stopwords.active(includeDiplomatic: includeDiplomatic) .union(extraStopwords(for: lens)),"#),
            (Self.configured, #"minimumLength: tuning.minimumLength, foldPlurals: tuning.foldPlurals, lens: lens, lexicon: WordCloudLexicons.filter(for: lens), markings: tuning.filterMarkings ? WordCloudStopwords.markings : [],"#,
             Self.server, #"minimumLength: tuning.minimumLength, foldPlurals: tuning.foldPlurals, lens: lens, lexicon: lexicons.filter(for: lens), markings: tuning.filterMarkings ? stopwords.markings : [],"#),
            (Self.bench, #"let kept = sample.filter { $0.count >= tuning.minimumCount && tokenizer.accepts($0.term.lowercased()) }"#,
             Self.server, #"return sample.filter { $0.count >= tuning.minimumCount && tokenizer.accepts($0.term.lowercased()) }"#),
            (Self.bench, #"wordForm: .dictionary"#,
             Self.server, #"wordForm: .dictionary"#),
            (Self.bench, #"guard sampleSize > 0 else { return String(localized: "settings.wordcloud.bench.pending", defaultValue: "Measuring…") }"#,
             Self.server, #"guard sampleSize > 0 else { return appWords("settings.wordcloud.bench.pending", "Measuring…") }"#),
            (Self.bench, #"return String(format: String(localized: "settings.wordcloud.bench.keeps %lld %lld", defaultValue: "Keeps %lld of %lld terms in this sample"), Int64(keptCount), Int64(sampleSize))"#,
             Self.server, #"return String(format: appWords("settings.wordcloud.bench.keeps %lld %lld", "Keeps %lld of %lld terms in this sample"), Int64(kept), Int64(sampleSize))"#),
            (Self.settings, #"Set(globalStopwords).union(lensStopwords(lens))"#,
             Self.server, #"Set(globalStopwords).union(lensStopwords(lens))"#),
            (Self.settings, #"lensStopwordMap()[lens.rawValue] ?? []"#,
             Self.server, #"lensStopwords[lens.rawValue] ?? []"#),
            (Self.settings, #"guard let data = store.data(forKey: Keys.lensStopwords), let map = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }"#,
             Self.server, #"guard let map = try? JSONDecoder().decode([String: [String]].self, from: Data(json.utf8)) else { return [:] }"#),
            (Self.sync, #"let modelLensData = Data(p.wcLensStopwordsJSON.utf8)"#,
             Self.server, #"CloudSettings.lensStopwordMap(preferences.wcLensStopwordsJSON)"#),
            (Self.sync, #"guard !json.isEmpty, let data = json.data(using: .utf8), let array = try? JSONDecoder().decode([String].self, from: data) else { return [] } return array"#,
             Self.server, #"guard !json.isEmpty, let data = json.data(using: .utf8), let array = try? JSONDecoder().decode([String].self, from: data) else { return [] } return array"#),
            (Self.sync, #"guard let data = try? JSONEncoder().encode(array),"#,
             Self.server, #"return ["wc_global_stopwords_json": .text(TagReferences.encode(set.sorted()))]"#),
            (Self.settings, #"let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() return trimmed.isEmpty ? nil : trimmed"#,
             Self.server, #"let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() return trimmed.isEmpty ? nil : trimmed"#),
            (Self.settings, #"var set = Set(globalStopwords) guard set.insert(normalized).inserted else { return } store.set(set.sorted(), forKey: Keys.globalStopwords)"#,
             Self.server, #"var set = Set(CloudSettings.decodeStringArray(preferences.wcGlobalStopwordsJSON)) guard set.insert(word).inserted else { return [:] } return ["wc_global_stopwords_json": .text(TagReferences.encode(set.sorted()))]"#),
            (Self.settings, #"guard set.remove(word.lowercased()) != nil else { return } store.set(set.sorted(), forKey: Keys.globalStopwords)"#,
             Self.server, #"guard set.remove(word.lowercased()) != nil else { return [:] } return ["wc_global_stopwords_json": .text(TagReferences.encode(set.sorted()))]"#),
            (Self.settings, #"var set = Set(map[lens.rawValue] ?? []) guard set.insert(normalized).inserted else { return } map[lens.rawValue] = set.sorted()"#,
             Self.server, #"var set = Set(map[lens.rawValue] ?? []) guard set.insert(word).inserted else { return [:] } map[lens.rawValue] = set.sorted()"#),
            (Self.settings, #"guard set.remove(word.lowercased()) != nil else { return } map[lens.rawValue] = set.isEmpty ? nil : set.sorted()"#,
             Self.server, #"guard set.remove(word.lowercased()) != nil else { return [:] } map[lens.rawValue] = set.isEmpty ? nil : set.sorted()"#),
            (Self.pane, #"Stepper(value: $minLength, in: 2...8) {"#,
             Self.preferences, #"static let minLengths = 2...8"#),
            (Self.pane, #"Stepper(value: $minCount, in: 1...20) {"#,
             Self.preferences, #"static let minCounts = 1...20"#),
        ])
    }

    @Test func theStatesTitlesAndHandOffsAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.view, #"if result.terms.isEmpty { return result.documentCount == 0 ? .noIndexedText : .noTerms(lens) } if lens.isSignalDependent && result.terms.count < lens.minimumSignalTerms { return .insufficientSignal(lens) } return .terms"#,
             Self.server, #"if kept.isEmpty { return "noTerms" } if lens.isSignalDependent && kept.count < lens.minimumSignalTerms { return "insufficientSignal" } return "terms""#),
            (Self.view, #"CountCopy.phrase(terms, one: String(localized: "wordcloud.count.terms.one", defaultValue: "%@ term"), many: String(localized: "wordcloud.count.terms.many", defaultValue: "%@ terms")),"#,
             Self.server, #"CountCopy.phrase(terms, one: appWords("wordcloud.count.terms.one", "%@ term"), many: appWords("wordcloud.count.terms.many", "%@ terms"), locale: SearchItem.locale)"#),
            (Self.view, #"lens.label.lowercased()"#,
             Self.server, #"label(lens).lowercased()))"#),
            (Self.view, #".reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } } .joined(separator: "; ")"#,
             Self.server, #".reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } } .joined(separator: "; ")"#),
            (Self.view, #"var seen = Set<String>() var all: [String] = [] for entry in entries where seen.insert(entry.subseries).inserted { all.append(entry.subseries) } return all"#,
             Self.server, #"var seen = Set<String>() var all: [String] = [] for entry in entries where seen.insert(entry.subseries).inserted { all.append(entry.subseries) } return all"#),
            (Self.view, #"Button(vol.title.isEmpty ? vol.volumeId : vol.title) {"#,
             Self.server, #"title: $0.title.isEmpty ? $0.volumeId : $0.title)"#),
            (Self.resolver, #"let title = manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId return Resolved(scope: scope, title: title, keys: try await keys(forVolume: volumeId), isCorpus: false)"#,
             Self.server, #"resources.volume(volumeId)?.title ?? volumeId"#),
            (Self.resolver, #"return Resolved(scope: scope, title: subseriesId, keys: keys, isCorpus: false)"#,
             Self.server, #"case .subseries(let subseriesId): subseriesId"#),
            (Self.view, #"case let .volume(volumeId): return ([volumeId], title.isEmpty ? volumeId : title)"#,
             Self.server, #"volumeIds: [volumeId], scopeLabel: title.isEmpty ? volumeId : title)"#),
            (Self.view, #"let volumeIds = appState.manifestStore.bundledEntries .filter { $0.subseries == subseriesId } .map(\.volumeId) guard !volumeIds.isEmpty else { return (nil, nil) } return (volumeIds, title.isEmpty ? subseriesId : title)"#,
             Self.server, #"let volumeIds = resources.manifest .filter { $0.subseries == subseriesId } .map(\.volumeId) guard !volumeIds.isEmpty else { return nil }"#),
            (Self.view, #"case .corpus, .document, .collection, .userTag, .savedSearch, .dateRange: return nil"#,
             Self.server, #"case .corpus: return nil"#),
            (Self.models, #"case "doc": guard let slash = value.firstIndex(of: "/") else { return nil }"#,
             Self.server, #"static let liveSignatures: Set<String> = ["doc", "col", "tag", "search", "scope", "subject", "daterange"]"#),
            (Self.lexicons, #"switch shared.polarity(of: term.lowercased()) {"#,
             Self.server, #"polarity: lens.colorsBySentiment ? lexicons.polarity(of: $0.term.lowercased()) : nil)"#),
        ])
    }

    /// Every word the server writes through `appWords`, each where the app's source writes it under its key.
    @Test func theAppsWordsAreTheServers() throws {
        let apps = try [Self.view, Self.lensUI, Self.keyness, Self.resolver, Self.bench, Self.backdrop]
            .map(ArchivalAndSeriesMirrorParityTests.source).joined(separator: " ")
        let server = try ArchivalAndSeriesMirrorParityTests.source(Self.server)
        let pattern = try NSRegularExpression(pattern: #"appWords\("((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\)"#)
        let words = pattern.matches(in: server, range: NSRange(server.startIndex..., in: server)).map { match in
            (key: String(server[Range(match.range(at: 1), in: server)!]), value: String(server[Range(match.range(at: 2), in: server)!]))
        }
        #expect(words.count >= 30, "the server writes \(words.count) of the app's words")
        for word in words {
            #expect(NoteViewParityTests.writes(apps, word.key, word.value), "the app writes \(word.key) as \(word.value)")
        }
    }
}
