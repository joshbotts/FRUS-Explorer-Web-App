// What the server and the browser app mirror of the app's Word Cloud (PLAN's S24i, S29e), held to the app's source at
// the pin, line beside line, where the kit does not hold it: since S29e the server calls the kit's tokenizer assembly
// (`WordCloudTokenizer.configured`), its scope's signatures (`WordCloudScope(signature:)`) and its count
// (`WordCloudCount.count`), and holds what stays the app's: `BundledCloudVectors`' reading of a scope's list and
// `LensChip`'s words; its settings bench (`WordCloudBench`); `WordCloudSettings`' lists and their JSON as
// `SettingsSyncCoordinator` syncs it; `WordCloudDisplayState`'s states, count lines and the lenses a health leaves;
// the resolver (`WordCloudScopeResolver`), each scope's documents, limits and title; the loader's term limit and its
// scopes that outlast a request (`WordCloudLoader`); the service's count and what keys it (`WordFrequencyService`);
// the scope menu (`WordCloudScopeBar`) and the scoped hand-off; the generator's layer; the browser's layout
// (`WordCloudLayout`), palette, typefaces and densities, and the settings pane's controls; and every word the server
// writes and copy.ts holds, under the app's key.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct WordCloudMirrorParityTests {
    static let bundled = "Analytics/WordCloud/BundledCloudVectors.swift"
    static let backdrop = "Analytics/WordCloud/WordCloudBackdropView.swift"
    static let configured = "kit:FRUSCoreKit/Analytics/WordCloud/WordCloudTokenizer+Configured.swift"
    static let bench = "Analytics/WordCloud/WordCloudBench.swift"
    static let settings = "Analytics/WordCloud/WordCloudSettings.swift"
    static let sync = "Settings/SettingsSyncCoordinator.swift"
    static let view = "Analytics/WordCloud/WordCloudView.swift"
    static let resolver = "Analytics/WordCloud/WordCloudScopeResolver.swift"
    static let lensUI = "Analytics/WordCloud/WordCloudLens+UI.swift"
    static let keyness = "kit:FRUSCoreKit/Analytics/WordCloud/KeynessCloud.swift"
    static let layout = "Analytics/WordCloud/WordCloudLayout.swift"
    static let models = "Analytics/WordCloud/WordCloudModels.swift"
    static let scope = "kit:FRUSCoreKit/Analytics/WordCloud/WordCloudScope.swift"
    static let lexicons = "Analytics/WordCloud/WordCloudLexicons.swift"
    static let pane = "Settings/WordCloudSettingsView.swift"
    static let rail = "DocumentView/ResearchRailView.swift"
    static let menu = "App/FRUSExplorerApp.swift"
    static let runner = "kit:CloudVectorsGeneratorCore/CloudVectorsRunner.swift"
    static let server = "Sources/FRUSLightAPI/WordCloud.swift"
    static let live = "Sources/FRUSLightAPI/WordCloudLive.swift"
    static let loader = "Analytics/WordCloud/WordCloudLoader.swift"
    static let service = "Analytics/WordCloud/WordFrequencyService.swift"
    static let searchModel = "Search/SearchViewModel.swift"
    static let chronologyView = "Chronology/ChronologyView.swift"
    static let preferences = "Sources/FRUSLightAPI/Preferences.swift"
    static let rules = "web:cloud/cloudRules.ts"
    static let screen = "web:cloud/CloudScreen.tsx"
    static let settingsPane = "web:settings/WordCloudSettings.tsx"
    static let shell = "web:shell/AppShell.tsx"
    static let reader = "web:reader/ReaderScreen.tsx"

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
             Self.server, #"static let lenses: [WordCloudLens] = WordCloudLens.allCases"#),
        ])
    }

    @Test func theReadersSettingsAreReadAndKeptAsTheAppsAre() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.configured, #"public static func configured(tuning: WordCloudTuning, lens: WordCloudLens = .allTerms, includeDiplomatic: Bool, extraStopwords: Set<String> = [], wordForm: WordCloudWordForm, stopwords: WordCloudStopwordSet, lexicons: WordCloudLexiconSet) -> WordCloudTokenizer {"#,
             Self.server, #"WordCloudTokenizer.configured(tuning: tuning, lens: lens, includeDiplomatic: includeDiplomatic, extraStopwords: extraStopwords(for: lens),"#),
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
            (Self.scope, #"public init?(signature: String) {"#,
             Self.server, #"guard let scope = WordCloudScope(signature: raw) else {"#),
            (Self.lexicons, #"switch shared.polarity(of: term.lowercased()) {"#,
             Self.server, #"polarity: lens.colorsBySentiment ? lexicons.polarity(of: $0.term.lowercased()) : nil)"#),
        ])
    }

    /// The live count (PLAN's S29e): each scope's documents, limits and title as the resolver gives them, the loader's
    /// term limit and the scopes that outlast a request, the service's count and the settings that key it, and the
    /// states a count's result decides, the app's lines beside the server's.
    @Test func theLiveCountIsTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.resolver, #"let title = manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId return Resolved( scope: scope, title: title, keys: [WordCloudDocumentKey(volumeId: volumeId, documentId: documentId)],"#,
             Self.server, #"let title = resources.volume(volumeId)?.title ?? volumeId return plain(title, .keys([WordCloudDocumentKey(volumeId: volumeId, documentId: documentId)]))"#),
            (Self.resolver, #"let volumeIds = manifestStore.bundledEntries .filter { $0.subseries == subseriesId } .map(\.volumeId)"#,
             Self.server, #"let volumeIds = resources.manifest.filter { $0.subseries == subseriesId }.map(\.volumeId)"#),
            (Self.resolver, #"let entries = (try await pipeline?.documents(forVolume: volumeId)) ?? [] return entries.map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }"#,
             Self.live, #"keys += try await served.pipeline.documents(forVolume: id).map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }"#),
            (Self.service, #"let keys = try await pipeline.allDocumentKeys()"#,
             Self.live, #"return try await served.pipeline.allDocumentKeys()"#),
            (Self.resolver, #"let title = collection.map { CollectionEditorNaming.listName(savedName: $0.name) }"#,
             Self.server, #"title: CollectionEditorNaming.listName(savedName: collection.name),"#),
            (Self.resolver, #"let keys = (collection?.documentEntries ?? []).map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }"#,
             Self.server, #"let keys = collection.entries.map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }"#),
            (Self.resolver, #"let keys = (try await pipeline?.documentKeys(forUserTagId: id.uuidString)) ?? []"#,
             Self.server, #"let keys = assignments.filter { SearchUsers.caseFolded($0.tagId) == wanted }"#),
            (Self.resolver, #"let results = try await searchService.search( parameters: saved.searchParameters, limit: SearchViewModel.searchHardLimit )"#,
             Self.live, #"return try await search.service.search(parameters: parameters, limit: SmartCollectionSnapshot.resultLimit)"#),
            (Self.searchModel, #"static let searchHardLimit: Int = 1_000"#,
             "kit:FRUSCoreKit/Collections/SmartCollectionSnapshot.swift", #"public static let resultLimit = 1_000"#),
            (Self.resolver, #"for volumeId in record?.volumeIds ?? [] {"#,
             Self.server, #"documents: .volumes(record.volumeIds), owner: user,"#),
            (Self.resolver, #"volumeIds = ScopeFacets.volumeIds(forCategory: category, subcategory: subcategory, resolvedByVolume: resolved) } else { volumeIds = ScopeFacets.volumeIds(forCategory: category, resolvedByVolume: resolved) }"#,
             Self.server, #"ScopeFacets.volumeIds(forCategory: category, subcategory: $0, resolvedByVolume: resolved) } ?? ScopeFacets.volumeIds(forCategory: category, resolvedByVolume: resolved)"#),
            (Self.resolver, #"for volumeId in volumeIds.sorted() {"#,
             Self.server, #".volumes(volumeIds.sorted()))"#),
            (Self.resolver, #"let title = subcategory.map { "\(category) · \($0)" } ?? category"#,
             Self.server, #"return plain(subcategory.map { "\(category) · \($0)" } ?? category,"#),
            (Self.resolver, #"range, scopeVolumeIds: nil, ascending: true, limit: Self.dateRangeKeyLimit)) ?? []"#,
             Self.live, #"return try await served.pipeline.documentsInDateRange(range, scopeVolumeIds: nil, ascending: true, limit: dateRangeKeyLimit)"#),
            (Self.resolver, #"private static let dateRangeKeyLimit = 5000"#,
             Self.live, #"static let dateRangeKeyLimit = 5_000"#),
            (Self.resolver, #"title: WordCloudScope.dateRangeTitle(startISO: startISO, endISO: endISO),"#,
             Self.server, #"return plain(WordCloudScope.dateRangeTitle(startISO: startISO, endISO: endISO),"#),
            (Self.resolver, #"title: String(localized: "wordcloud.scope.corpus", defaultValue: "Entire Corpus"),"#,
             Self.server, #"return plain(appWords("wordcloud.scope.corpus", "Entire Corpus"), .corpus)"#),
            (Self.loader, #"static let standardTermLimit = 1_000"#,
             Self.live, #"static let termLimit = 1_000"#),
            (Self.loader, #"if case .subseries = scope { return true } if case .subjectCategory = scope { return true }"#,
             Self.live, #"case .corpus, .subseries, .subjectCategory: true"#),
            (Self.service, #"wordForm: languageAnalysis.wordForm"#,
             Self.live, #"wordForm: tagger.health.wordForm,"#),
            (Self.service, #"let result = try await WordCloudCount.count( keys: keys, pipeline: pipeline, tokenizer: tokenizer, tagger: NaturalLanguageWordCloudTagger(), countedUnder: languageAnalysis, indexVersion: indexVersion, limit: limit, minimumCount: tuning.minimumCount, progress: progress)"#,
             Self.live, #"try await WordCloudCount.count(keys: keys, pipeline: pipeline, tokenizer: tokenizer, tagger: tagger, countedUnder: tagger.health, indexVersion: indexVersion, limit: WordCloudLive.termLimit, minimumCount: minimumCount, progress: progress)"#),
            // The key's parts are the app's: the tuning's token, the diplomatic layer and the hidden words sorted, which the
            // server writes as a JSON list where the app joins them with commas.
            (Self.service, #""\(signature)|n=\(limit)|diplo=\(includeDiplomatic)|x=\(extras)|t=\(tuning)""#,
             Self.live, #""t=\(tuning.cacheToken)|diplo=\(includeDiplomatic)|x=\(TagReferences.encode(extraStopwords(for: lens).sorted()))""#),
            (Self.service, #"extras.isEmpty ? "" : extras.sorted().joined(separator: ",")"#,
             Self.live, #"TagReferences.encode(extraStopwords(for: lens).sorted())"#),
            (Self.view, #"if let languageAnalysis, !languageAnalysis.supports(lens) { return .lensUnavailable(lens, languageAnalysis) } if result.terms.isEmpty { return result.documentCount == 0 ? .noIndexedText : .noTerms(lens) }"#,
             Self.live, #"if result.terms.isEmpty { return result.documentCount == 0 ? "noIndexedText" : "noTerms" }"#),
            (Self.view, #"if lens.isSignalDependent && result.terms.count < lens.minimumSignalTerms { return .insufficientSignal(lens) } return .terms"#,
             Self.live, #"if lens.isSignalDependent && result.terms.count < lens.minimumSignalTerms { return "insufficientSignal" } return "terms""#),
            (Self.view, #"WordCloudLens.allCases.filter { health.supports($0) }"#,
             Self.live, #"WordCloudLens.allCases.filter { health.supports($0) }"#),
            (Self.view, #"String(format: String(localized: "wordcloud.provenance %@ %@", defaultValue: "%1$@ from %2$@"), CountCopy.phrase(terms, one: String(localized: "wordcloud.count.terms.one", defaultValue: "%@ term"), many: String(localized: "wordcloud.count.terms.many", defaultValue: "%@ terms")), CountCopy.documents(documents))"#,
             Self.live, #"String(format: appWords("wordcloud.provenance %@ %@", "%1$@ from %2$@"), CountCopy.phrase(terms, one: appWords("wordcloud.count.terms.one", "%@ term"), many: appWords("wordcloud.count.terms.many", "%@ terms"), locale: SearchItem.locale), CountCopy.documents(documents, locale: SearchItem.locale))"#),
            (Self.view, #"guard !state.isLensUnavailable else { return nil }"#,
             Self.server, #"answer.state = "lensUnavailable""#),
            (Self.view, #"guard case let .resolved(ids) = CustomScopeResolver.indexedResolution( memberVolumeIds: record.volumeIds, indexed: appState.indexedVolumeIds) else { return nil } return ids.sorted()"#,
             Self.live, #"guard case .resolved(let ids) = CustomScopeResolver.indexedResolution(memberVolumeIds: resolution.members ?? [], indexed: indexed)"#),
            (Self.view, #"return ids.isEmpty ? nil : ids.sorted()"#,
             Self.live, #"guard case .volumes(let ids) = resolution.documents, !ids.isEmpty else { return nil }"#),
            (Self.view, #"let end = corpus.upperBound let start = cal.date(byAdding: .year, value: -1, to: end) ?? corpus.lowerBound"#,
             "Sources/FRUSLightAPI/Chronology.swift", #"let start = cal.date(byAdding: .year, value: -1, to: upper) ?? lower"#),
            (Self.chronologyView, #"let scope = WordCloudScope.dateRange( startISO: WordCloudScope.isoDay(from: min(vm.rangeStart, vm.rangeEnd)), endISO: WordCloudScope.isoDay(from: max(vm.rangeStart, vm.rangeEnd))"#,
             "web:analytics/ChronologyScreen.tsx", #"search={{ scope: `daterange:${answer.from}..${answer.to}` }}"#),
            (Self.chronologyView, #".disabled(!vm.hasLoaded || vm.totalShown == 0)"#,
             "web:analytics/ChronologyScreen.tsx", #"{answer && answer.state === 'loaded' && answer.groups.length + (answer.spanning?.rows.length ?? 0) + (answer.overflow?.rows.length ?? 0) > 0 && ("#),
        ])
    }

    @Test func theBrowsersLayoutAndChoicesAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.layout, #"maxWords: Int = 180, minFontSize: CGFloat = 13, maxFontSize: CGFloat = 64, spacingScale: CGFloat = 1, widthFactor: CGFloat = 0.54,"#,
             Self.rules, #"{ maxWords = 180, minFontSize = 13, maxFontSize = 64, spacingScale = 1, widthFactor = 0.54 } = {},"#),
            (Self.layout, #"let words = Array(terms.prefix(maxWords))"#,
             Self.rules, #"const words = terms.slice(0, maxWords);"#),
            (Self.layout, #"guard size.width > 0, size.height > 0, let maxCount = words.first?.count, maxCount > 0 else { return [] } let minCount = words.last?.count ?? maxCount"#,
             Self.rules, #"if (!(width > 0 && height > 0) || maxCount === undefined || !(maxCount > 0)) return []; const minCount = words[words.length - 1]?.count ?? maxCount;"#),
            (Self.layout, #"let vertical = rank > words.count / 4 && rank % 3 == 1"#,
             Self.rules, #"const vertical = rank > Math.floor(words.length / 4) && rank % 3 === 1;"#),
            (Self.layout, #"if vertical { estimate = CGSize(width: estimate.height, height: estimate.width) }"#,
             Self.rules, #"if (vertical) estimate = { width: estimate.height, height: estimate.width };"#),
            (Self.layout, #"let angleStep: CGFloat = 0.30 let spiralTightness: CGFloat = max(estimate.height, minFontSize) * 0.22 * spacingScale"#,
             Self.rules, #"const angleStep = 0.3; const spiralTightness = Math.max(estimate.height, minFontSize) * 0.22 * spacingScale;"#),
            (Self.layout, #"while angle < 70 {"#,
             Self.rules, #"while (angle < 70) {"#),
            (Self.layout, #"let radius = spiralTightness * angle let point = CGPoint(x: center.x + radius * cos(angle) * 1.7, y: center.y + radius * sin(angle) * yCompression)"#,
             Self.rules, #"const radius = spiralTightness * angle; const point = { x: center.x + radius * Math.cos(angle) * 1.7, y: center.y + radius * Math.sin(angle) * 1 };"#),
            (Self.layout, #"if bounds.contains(rect), !exclusionZones.contains(where: { $0.intersects(rect) }), !occupied.contains(where: { $0.intersects(rect) }) { slot = rect break } angle += angleStep"#,
             Self.rules, #"if (contains(bounds, rect) && !occupied.some((taken) => intersects(taken, rect))) { slot = rect; break; } angle += angleStep;"#),
            (Self.layout, #"colorIndex: rank, rotationDegrees: vertical ? 90 : 0"#,
             Self.rules, #"colorIndex: rank, rotation: vertical ? 90 : 0,"#),
            (Self.layout, #"let gap = -1.5 * spacingScale occupied.append(rect.insetBy(dx: gap, dy: gap))"#,
             Self.rules, #"const gap = -1.5 * spacingScale; occupied.push({ x: slot.x + gap, y: slot.y + gap, width: slot.width - 2 * gap, height: slot.height - 2 * gap });"#),
            (Self.layout, #"guard maxCount > minCount else { return (minFontSize + maxFontSize) / 2 } let t = max(0, min(1, CGFloat(count - minCount) / CGFloat(maxCount - minCount))) let curve = sizeExponent.map { pow(t, $0) } ?? sqrt(t) return minFontSize + (maxFontSize - minFontSize) * curve"#,
             Self.rules, #"if (!(maxCount > minCount)) return (minFontSize + maxFontSize) / 2; const t = Math.max(0, Math.min(1, (count - minCount) / (maxCount - minCount))); const curve = Math.sqrt(t); return minFontSize + (maxFontSize - minFontSize) * curve;"#),
            (Self.layout, #"let width = CGFloat(term.count) * fontSize * widthFactor + fontSize * 0.4 let height = fontSize * 1.25"#,
             Self.rules, #"const width = characters(term) * size * widthFactor + size * 0.4; const height = size * 1.25;"#),
            (Self.view, #"private static let palette: [Color] = [ .blue, .teal, .indigo, .purple, .pink, .orange, .green, .red, .cyan, .mint ]"#,
             Self.rules, #"export const palette = ['blue', 'teal', 'indigo', 'purple', 'pink', 'orange', 'green', 'red', 'cyan', 'mint'] as const;"#),
            (Self.view, #"case .positive: return .green case .negative: return .red case .none: return .secondary } } return Self.palette[colorIndex % Self.palette.count]"#,
             Self.rules, #"return palette[rank % palette.length]!;"#),
            (Self.view, #".font(.system(size: word.fontSize, weight: .semibold, design: fontDesign.swiftUIDesign))"#,
             "web:styles/app.css", #".cloud-canvas text { font-weight: 600; cursor: pointer; }"#),
            (Self.view, #"spacingScale: density.spacingScale, widthFactor: fontDesign.widthFactor"#,
             Self.screen, #"place(terms, width, height, { spacingScale: spacingScales[density], widthFactor: widthFactors[design] }),"#),
            (Self.view, #".onTapGesture { analyze(for: WordCloudLexicons.bareTerm(word.term)) } .accessibilityHidden(true)"#,
             Self.screen, #"aria-hidden="true" onClick={() => void navigate({ to: '/analytics/corpus', search: { term: word.term } })}"#),
            (Self.models, #"case .rounded: return 0.54 case .standard: return 0.54 case .serif: return 0.52 case .monospaced: return 0.62"#,
             Self.rules, #"export const widthFactors: Record<FontDesign, number> = { rounded: 0.54, standard: 0.54, serif: 0.52, monospaced: 0.62 };"#),
            (Self.models, #"case .compact: return 0.72 case .balanced: return 1.0 case .airy: return 1.45"#,
             Self.rules, #"export const spacingScales: Record<Density, number> = { compact: 0.72, balanced: 1.0, airy: 1.45 };"#),
            (Self.settings, #"static let fontDesign = "frus.wordcloud.fontDesign""#,
             Self.rules, #"fontDesign: 'frus.wordcloud.fontDesign'"#),
            (Self.settings, #"static let density = "frus.wordcloud.density""#,
             Self.rules, #"density: 'frus.wordcloud.density'"#),
            (Self.settings, #"static let measure = "frus.wordcloud.measure""#,
             Self.rules, #"const keys = { measure: 'frus.wordcloud.measure',"#),
            (Self.settings, #"(store.string(forKey: Keys.fontDesign)).flatMap(WordCloudFontDesign.init(rawValue:)) ?? .rounded"#,
             Self.rules, #"return fontDesigns.includes(value as FontDesign) ? (value as FontDesign) : 'rounded';"#),
            (Self.settings, #"(store.string(forKey: Keys.density)).flatMap(WordCloudDensity.init(rawValue:)) ?? .balanced"#,
             Self.rules, #"return densities.includes(value as Density) ? (value as Density) : 'balanced';"#),
            (Self.view, #"@AppStorage(WordCloudSettings.Keys.measure) private var measureRaw = KeynessCloudMeasure.frequency.rawValue"#,
             Self.rules, #"return stored(keys.measure) === 'keyness' ? 'keyness' : 'frequency';"#),
            (Self.pane, #"guard terms.count > 1 else { return 20 } let t = CGFloat(rank) / CGFloat(terms.count - 1) return 20 - (9 * t)"#,
             Self.rules, #"if (!(count > 1)) return 20; const t = rank / (count - 1); return 20 - 9 * t;"#),
            (Self.pane, #"SampleTermsRow(terms: Array(bench.kept.prefix(12)),"#,
             Self.settingsPane, #"const shown = kept.slice(0, 12);"#),
            (Self.pane, #"weight: index < 2 ? .semibold : .regular,"#,
             Self.settingsPane, #"fontWeight: index < 2 ? 600 : 400"#),
            (Self.pane, #".foregroundStyle(index < 3 ? Color.accentColor : Color.primary.opacity(0.75))"#,
             Self.settingsPane, #"data-rank={index < 3 ? 'top' : undefined}"#),
            (Self.pane, #".accessibilityElement(children: .ignore) .accessibilityLabel(sampleAccessibilityLabel)"#,
             Self.settingsPane, #"role="img" aria-label={words.sampleA11y(shown.map((term) => term.term).join(', '))}> {shown.map((term, index) => ( <span key={term.term} aria-hidden="true""#),
            (Self.pane, #"Form { sampleSection filteringSection thresholdsSection appearanceSection stopListSection }"#,
             Self.settingsPane, #"</section> {appearance} <HiddenWords"#),
            (Self.pane, #"Text(bench.summary) .foregroundStyle(bench.kept.isEmpty ? Color.red : Color.secondary)"#,
             Self.settingsPane, #"<span data-empty={sample.data && kept.length === 0 ? 'true' : undefined}>{sample.data?.summary ?? words.measuring}</span>"#),
            (Self.pane, #"lens: stopListScope.lens ?? .allTerms,"#,
             Self.settingsPane, #"const sample = useQuery(cloudSampleQuery(scope || undefined, token));"#),
            (Self.pane, #"ForEach(WordCloudLens.allCases) { lens in Text(lens.label).tag(StopListScope.lens(lens)) }"#,
             Self.settingsPane, #"const lenses = ['allTerms', 'people', 'places', 'organizations', 'topics', 'actions', 'descriptors', 'concepts', 'sentiment'] as const;"#),
            (Self.view, #"sessionHiddenWords.insert(term.lowercased())"#,
             Self.screen, #"setSession({ scope: drawnScope, words: [...sessionWords, term.toLowerCase()] });"#),
            (Self.view, #"WordCloudMainArea(state: displayState) { if measure == .keyness, case .unavailable(let reason) = keyness ?? .pending {"#,
             Self.screen, #"detail={answer.message?.detail ?? ''} /> ) : measure === 'keyness' ? ( <Empty title={words.keynessTitle} detail={words.keynessReason} /> )"#),
            (Self.scope, #"guard !hidden.isEmpty else { return terms } return terms.filter { !hidden.contains($0.term.lowercased()) }"#,
             Self.screen, #"return (answer?.terms ?? []).filter((term) => !hidden.has(term.term.toLowerCase()));"#),
            (Self.view, #"if !hiddenWords.isEmpty || !sessionHiddenWords.isEmpty {"#,
             Self.screen, #"{sessionWords.length > 0 && ("#),
            (Self.view, #"let maxCount = visibleTerms.first?.count ?? 1"#,
             Self.screen, #"const maxCount = terms[0]?.count ?? 1;"#),
            (Self.view, #"let fraction = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) : 0 return RoundedRectangle(cornerRadius: 2) .fill(Color.accentColor.opacity(0.55)) .frame(width: 60 * fraction, height: 6)"#,
             Self.screen, #"style={{ width: `${Math.round((60 * term.count) / maxCount)}px` }}"#),
            (Self.view, #"if let scopedLabel = scopedAnalyzeMenuLabel {"#,
             Self.screen, #"...(within"#),
            (Self.view, #"appState.openSearch(SearchParameters(keywords: term), from: target)"#,
             Self.screen, #"onSelect: () => void navigate({ to: '/search', search: { keywords: term.term } })"#),
            (Self.view, #"AnalyticsParameters(term: term, scopeVolumeIds: volumeIds, scopeLabel: label),"#,
             Self.screen, #"search: { term: term.term, volumes: within.volumeIds, scopeLabel: within.scopeLabel }"#),
            (Self.menu, #"appState.openWordCloud(.corpus, from: nil) // corpus scope, matching the toolbar affordance"#,
             Self.shell, #"{ kind: 'item', label: copy.app.wordCloud, onSelect: () => openTool('/cloud') },"#),
            (Self.menu, #"Button(String(localized: "menu.analytics.chronology", defaultValue: "Chronology")) { appState.bindTool(.chronology, to: nil) openWindow.fronting(id: "frus.chronology") } Button(String(localized: "menu.analytics.wordcloud", defaultValue: "Word Cloud")) {"#,
             Self.shell, #"{ kind: 'item', label: copy.app.chronology, onSelect: () => openTool('/chronology') }, // From S24i, the Word Cloud after Chronology, as the Mac's menu has it, on the whole corpus. { kind: 'item', label: copy.app.wordCloud, onSelect: () => openTool('/cloud') },"#),
            (Self.rail, #"railTile(WordCloudGlyph.symbol, RailTileCopy.wordCloud, action: openWordCloud) railTile("archivebox", RailTileCopy.sources, action: openSources)"#,
             Self.reader, #"<Link to="/cloud" search={{ scope: `doc:${volumeId}/${documentId}` }} title={copy.wordCloud.tileHelp}>"#),
            (Self.rail, #"appState.openWordCloud(.document(volumeId: entry.volumeId, documentId: entry.documentId), from: sceneID)"#,
             Self.reader, #"search={{ scope: `doc:${volumeId}/${documentId}` }}"#),
        ])
    }

    /// The app's words the browser app takes, each where the app's source writes it, and in copy.ts's block.
    @Test func theAppsWordsAreTheWebs() throws {
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let (v, p, m, l) = (Self.view, Self.pane, Self.models, Self.lensUI)
        let words: [(file: String, key: String, value: String, block: String, web: String)] = [
            (v, "wordcloud.title", "Word Cloud", "wordCloud", "title"),
            (Self.rail, "researchRail.tile.wordCloud", "Word Cloud", "wordCloud", "tile"),
            (v, "wordcloud.scopeBar.label", "Scope", "wordCloud", "scope"),
            (v, "wordcloud.scope.subseries", "Subseries", "wordCloud", "subseries"),
            (v, "wordcloud.scope.volume", "Volume", "wordCloud", "volume"),
            (v, "wordcloud.scope.collection", "Collection", "wordCloud", "collection"),
            (v, "wordcloud.scope.tag", "Tag", "wordCloud", "tag"),
            (v, "wordcloud.scope.savedSearch", "Saved Search", "wordCloud", "savedSearch"),
            (v, "analytics.scope.customScopes", "My Volume Scopes", "wordCloud", "customScopes"),
            (v, "wordcloud.scope.bySubject", "By Subject", "wordCloud", "bySubject"),
            (v, "wordcloud.scope.subject.experimental", "Subjects — experimental", "wordCloud", "subjectExperimental"),
            (v, "wordcloud.scope.dateRange", "Date Range", "wordCloud", "dateRange"),
            (v, "wordcloud.scope.dateRange.from", "Range start", "wordCloud", "rangeStart"),
            (v, "wordcloud.scope.dateRange.to", "Range end", "wordCloud", "rangeEnd"),
            (v, "wordcloud.scope.untitled", "Untitled", "wordCloud", "untitled"),
            (v, "wordcloud.viewInChronology", "View in Chronology", "wordCloud", "viewInChronology"),
            (Self.chronologyView, "chronology.wordcloud", "Word Cloud for this range", "chronology", "wordCloud"),
            (Self.chronologyView, "chronology.wordcloud.help", "Build a word cloud from the documents in the displayed date range", "chronology", "wordCloudHelp"),
            (v, "wordcloud.lens.label", "Show", "wordCloud", "show"),
            (v, "wordcloud.measure.label", "Size words by", "wordCloud", "sizeBy"),
            (v, "wordcloud.sentiment.positive", "Positive", "wordCloud", "positive"),
            (v, "wordcloud.sentiment.negative", "Negative", "wordCloud", "negative"),
            (v, "wordcloud.filter.boilerplate", "Hide common diplomatic words", "wordCloud", "boilerplate"),
            (v, "wordcloud.word.analyze", "Analyze in Corpus Analytics", "wordCloud", "analyze"),
            (v, "wordcloud.word.search", "Search for this term", "wordCloud", "searchTerm"),
            (v, "wordcloud.word.hide.session", "Hide in this word cloud", "wordCloud", "hideSession"),
            (v, "wordcloud.word.hide.lens", "Hide this word in this lens", "wordCloud", "hideLens"),
            (v, "wordcloud.word.hide.global", "Hide this word in all word clouds", "wordCloud", "hideGlobal"),
            (v, "wordcloud.tap.hint", "Charts this term in Corpus Analytics", "wordCloud", "tapHint"),
            (v, "wordcloud.keyness.unavailable.title", "No Distinctiveness Ranking", "wordCloud", "keynessTitle"),
            (v, "wordcloud.error.title", "Couldn’t Build Word Cloud", "wordCloud", "errorTitle"),
            (v, "wordcloud.loading", "Building word cloud…", "wordCloud", "loading"),
            (p, "settings.wordcloud.title", "Word Cloud", "wordCloudSettings", "title"),
            (p, "settings.wordcloud.sample.header", "Sample", "wordCloudSettings", "sample"),
            (p, "settings.wordcloud.sample.none", "These settings keep nothing from the sample. Lower a threshold or turn a filter off.", "wordCloudSettings", "sampleNone"),
            (p, "settings.wordcloud.filtering.header", "Filtering", "wordCloudSettings", "filtering"),
            (p, "settings.wordcloud.boilerplate", "Hide common diplomatic words", "wordCloudSettings", "boilerplate"),
            (p, "settings.wordcloud.markings", "Filter classification markings", "wordCloudSettings", "markings"),
            (p, "settings.wordcloud.foldPlurals", "Merge plural and singular forms", "wordCloudSettings", "foldPlurals"),
            (p, "settings.wordcloud.markings.footer", "Classification markings include terms like “Top Secret” and “Confidential”, precedence words like “Priority” and “Immediate”, and month names. These words describe the handling of a document, not its content. Left in, they crowd the cloud, especially the named-entity lenses.", "wordCloudSettings", "markingsFooter"),
            (p, "settings.wordcloud.thresholds.header", "Thresholds", "wordCloudSettings", "thresholds"),
            (p, "settings.wordcloud.bench.label", "Effect", "wordCloudSettings", "effect"),
            (Self.bench, "settings.wordcloud.bench.pending", "Measuring…", "wordCloudSettings", "measuring"),
            (p, "settings.wordcloud.thresholds.footer", "Drops terms shorter than the minimum length, and terms appearing fewer than the minimum number of times. Raising either option results in a sparser cloud of stronger terms. Occurrences are counted across the whole scope before the top terms are picked, so raising the minimum count may thin a “long tail” you never see rather than the sample above.", "wordCloudSettings", "thresholdsFooter"),
            (p, "settings.wordcloud.appearance.header", "Appearance", "wordCloudSettings", "appearance"),
            (p, "settings.wordcloud.font", "Font", "wordCloudSettings", "font"),
            (p, "settings.wordcloud.density", "Density", "wordCloudSettings", "density"),
            (p, "settings.wordcloud.appearance.footer", "Choose the typeface the cloud is drawn in and how tightly its words pack together. Compact fits more terms; airy spaces them out for legibility. These settings apply on this device only.", "wordCloudSettings", "appearanceFooter"),
            (m, "wordcloud.font.rounded", "Rounded", "wordCloudSettings", "rounded"),
            (m, "wordcloud.font.standard", "Default", "wordCloudSettings", "standard"),
            (m, "wordcloud.font.serif", "Serif", "wordCloudSettings", "serif"),
            (m, "wordcloud.font.monospaced", "Monospaced", "wordCloudSettings", "monospaced"),
            (m, "wordcloud.density.compact", "Compact", "wordCloudSettings", "compact"),
            (m, "wordcloud.density.balanced", "Balanced", "wordCloudSettings", "balanced"),
            (m, "wordcloud.density.airy", "Airy", "wordCloudSettings", "airy"),
            (p, "settings.wordcloud.stoplist.header", "Hidden Words", "wordCloudSettings", "hiddenWords"),
            (p, "settings.wordcloud.stoplist.scope", "Applies to", "wordCloudSettings", "appliesTo"),
            (p, "settings.wordcloud.stoplist.allLenses", "Every cloud", "wordCloudSettings", "everyCloud"),
            (l, "wordcloud.lens.all", "All terms", "wordCloudSettings", "allTerms"),
            (l, "wordcloud.lens.people", "People", "wordCloudSettings", "people"),
            (l, "wordcloud.lens.places", "Places", "wordCloudSettings", "places"),
            (l, "wordcloud.lens.orgs", "Organizations", "wordCloudSettings", "organizations"),
            (l, "wordcloud.lens.topics", "Topics (nouns)", "wordCloudSettings", "topics"),
            (l, "wordcloud.lens.actions", "Actions (verbs)", "wordCloudSettings", "actions"),
            (l, "wordcloud.lens.descriptors", "Descriptors (adjectives)", "wordCloudSettings", "descriptors"),
            (l, "wordcloud.lens.concepts", "Concepts", "wordCloudSettings", "concepts"),
            (l, "wordcloud.lens.sentiment", "Sentiment", "wordCloudSettings", "sentiment"),
            (p, "settings.wordcloud.addWord.prompt", "Add a word…", "wordCloudSettings", "addPrompt"),
            (p, "settings.wordcloud.add.a11y", "Add hidden word", "wordCloudSettings", "addA11y"),
            (p, "settings.wordcloud.empty", "No custom words yet.", "wordCloudSettings", "empty"),
            (p, "settings.wordcloud.global.footer", "Words listed here are removed from every word cloud, on top of the built-in stop lists.", "wordCloudSettings", "globalFooter"),
            (p, "settings.wordcloud.lens.footer", "Words hidden only when the selected lens is active — useful for trimming a recurring false positive (for example, a place the recognizer keeps mistaking) without affecting other lenses.", "wordCloudSettings", "lensFooter"),
            ("Search/SearchView.swift", "search.mode.collocates", "Collocates", "readings", "collocates"),
            (Self.menu, "menu.analytics.wordcloud", "Word Cloud", "app", "wordCloud"),
        ]
        var read: [String: String] = [:]
        for word in words {
            let app = try read[word.file] ?? ArchivalAndSeriesMirrorParityTests.source(word.file)
            read[word.file] = app
            #expect(NoteViewParityTests.writes(app, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            let block = try NoteViewParityTests.block(word.block, of: copy)
            #expect(block.contains("\(word.web): '\(word.value)'"), "copy.ts's \(word.block) block has \(word.web): \(word.value)")
        }
        // The words the web composes from the app's: an announcement, the hidden words' count, the sample's name, a removal.
        let view = try ArchivalAndSeriesMirrorParityTests.source(v)
        let pane = try ArchivalAndSeriesMirrorParityTests.source(p)
        let cloud = try NoteViewParityTests.block("wordCloud", of: copy)
        let settings = try NoteViewParityTests.block("wordCloudSettings", of: copy)
        #expect(NoteViewParityTests.writes(view, "wordcloud.word.hidden.a11y", "%@ hidden from this word cloud")
                && cloud.contains("hiddenAnnouncement: (term: string) => `${term} hidden from this word cloud`"))
        #expect(view.contains(#"String(localized: "wordcloud.filter.showHidden %lld", defaultValue: "Show %lld hidden words")"#)
                && cloud.contains("showHidden: (count: number) => `Show ${count} hidden words`"))
        #expect(NoteViewParityTests.writes(pane, "settings.wordcloud.sample.a11y %@", "Sample of kept terms: %@")
                && settings.contains("sampleA11y: (terms: string) => `Sample of kept terms: ${terms}`"))
        #expect(NoteViewParityTests.writes(pane, "settings.wordcloud.remove %@", "Remove %@")
                && settings.contains("remove: (word: string) => `Remove ${word}`"))
        #expect(NoteViewParityTests.writes(view, "wordcloud.count.terms.one", "%@ term") && NoteViewParityTests.writes(view, "wordcloud.count.terms.many", "%@ terms")
                && cloud.contains("countLine: (count: number) => `${count.toLocaleString('en-US')} ${count === 1 ? 'term' : 'terms'}`"))
        // S29e's: a document's scope as the scope bar names it, and a count's line.
        #expect(NoteViewParityTests.writes(view, "wordcloud.scope.document %@", "Document %@")
                && cloud.contains("document: (documentId: string) => `Document ${documentId}`"))
        #expect(NoteViewParityTests.writes(view, "wordcloud.provenance %@ %@", "%1$@ from %2$@")
                && cloud.contains("${count === 1 ? 'term' : 'terms'} from ${documents.toLocaleString('en-US')} ${documents === 1 ? 'document' : 'documents'}`"))
    }

    /// The settings bench's stand-in sample, every term and count, in its order, as the app's `WordCloudBench` lists it.
    @Test func theBenchsSampleIsTheApps() throws {
        let pattern = try NSRegularExpression(pattern: #"TermCount\(term: "([^"]+)", count: (\d+)\)"#)
        func sample(_ path: String) throws -> [String] {
            let source = try ArchivalAndSeriesMirrorParityTests.source(path)
            let start = try #require(source.range(of: "static let canonicalSample: [TermCount] = ["), "\(path) lists the sample")
            let end = try #require(source.range(of: "]", range: start.upperBound..<source.endIndex))
            let block = String(source[start.upperBound..<end.lowerBound])
            return pattern.matches(in: block, range: NSRange(block.startIndex..., in: block)).map { match in
                "\(block[Range(match.range(at: 1), in: block)!]) \(block[Range(match.range(at: 2), in: block)!])"
            }
        }
        let app = try sample(Self.bench)
        let server = try sample(Self.server)
        #expect(app.count == 23 && app.first == "negotiation 84" && app.last == "rapprochement 1")
        #expect(server == app)
    }

    /// Every word the server writes through `appWords`, each where the app's source writes it under its key.
    @Test func theAppsWordsAreTheServers() throws {
        let apps = try [Self.view, Self.lensUI, Self.keyness, Self.resolver, Self.bench, Self.backdrop]
            .map(ArchivalAndSeriesMirrorParityTests.source).joined(separator: " ")
        let server = try [Self.server, Self.live].map(ArchivalAndSeriesMirrorParityTests.source).joined(separator: " ")
        let pattern = try NSRegularExpression(pattern: #"appWords\("((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\)"#)
        let words = pattern.matches(in: server, range: NSRange(server.startIndex..., in: server)).map { match in
            (key: String(server[Range(match.range(at: 1), in: server)!]), value: String(server[Range(match.range(at: 2), in: server)!]))
        }
        #expect(words.count >= 50, "the server writes \(words.count) of the app's words")
        for word in words {
            #expect(NoteViewParityTests.writes(apps, word.key, word.value), "the app writes \(word.key) as \(word.value)")
        }
    }
}
