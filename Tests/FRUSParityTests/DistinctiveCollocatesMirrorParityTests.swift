// What the server and the browser app mirror of the app's Distinctive measure and its Collocates panel (PLAN's S29f),
// held to the app's source at the pin, line beside line, where the kit does not hold it: the Word Cloud's ranking of the
// terms it shows (`WordCloudView.recomputeKeyness`), its caveat, its count line and its bar; Collocates' rebuild over the
// results kept (`SearchView.rebuildCollocation`), the panel's windows, orders and caveat (`CollocationView`,
// `CollocationOrder`, `CollocationCaveatCopy`), and what it says of the set it measured
// (`ResultSetScope.collocationScopeDescription`); the browser's keys for the window and the order
// (`SearchCollocationDefaults`) and its rows' numbers; and every word the server writes and copy.ts holds, under the
// app's key.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct DistinctiveCollocatesMirrorParityTests {
    static let collocationView = "Search/CollocationView.swift"
    static let searchView = "Search/SearchView.swift"
    static let searchSheet = "App/SearchSheet.swift"
    static let scope = "Search/ResultSetScope.swift"
    static let cloudView = "Analytics/WordCloud/WordCloudView.swift"
    static let collocates = "Sources/FRUSLightAPI/Collocates.swift"
    static let distinctive = "Sources/FRUSLightAPI/WordCloudDistinctive.swift"
    static let readings = "web:search/Readings.tsx"
    static let screen = "web:cloud/CloudScreen.tsx"
    static let copy = "web:copy.ts"

    @Test func collocatesAreRebuiltAsTheAppsPanelRebuildsThem() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.searchSheet, #"guard !results.isEmpty else { collocation = .unavailable(.noMatches); return }"#,
             Self.collocates, #"guard !results.isEmpty else { return .unavailable(.noMatches) }"#),
            (Self.searchSheet, #"let availability = BundledKeynessBaseline.baseline( for: .allTerms, tuning: configuration.tuning, includeDiplomatic: configuration.includeDiplomatic, languageAnalysis: configuration.languageAnalysis)"#,
             Self.collocates, #"let availability = references.baseline( for: .allTerms, tuning: configuration.tuning, includeDiplomatic: configuration.includeDiplomatic, languageAnalysis: configuration.languageAnalysis, tokenizer: WordCloudLive.tagger.identity)"#),
            (Self.searchSheet, #"case .unavailable(.noArtifact), .unavailable(.lensNotPriced): collocation = .unavailable(.noArtifact); return"#,
             Self.collocates, #"case .unavailable(.noArtifact), .unavailable(.lensNotPriced): return .unavailable(.noArtifact)"#),
            (Self.searchSheet, #"case .unavailable(.languageAnalysisUnavailable): collocation = .unavailable(.languageAnalysisUnavailable); return"#,
             Self.collocates, #"case .unavailable(.languageAnalysisUnavailable): return .unavailable(.languageAnalysisUnavailable)"#),
            (Self.searchSheet, #"case .unavailable(.configurationMismatch(let mismatches)): collocation = .unavailable(.configurationMismatch(mismatches)); return"#,
             Self.collocates, #"case .unavailable(.configurationMismatch(let mismatches)): return .unavailable(.configurationMismatch(mismatches))"#),
            (Self.searchSheet, #"case .available(let found): reference = found"#,
             Self.collocates, #"case .available(let found): reference = found"#),
            (Self.searchSheet, #"windowSize: collocationWindow, configuration: configuration, reference: reference)"#,
             Self.collocates, #"windowSize: window, configuration: configuration, reference: reference,"#),
            (Self.searchSheet, #"} catch is CancellationError {"#,
             Self.collocates, #"} catch is CancellationError { throw CancellationError()"#),
            (Self.searchSheet, #"} catch { collocation = .unavailable(.scanFailed) }"#,
             Self.collocates, #"return .unavailable(.scanFailed)"#),
            // The whole retained set, less what Checklist Mode hides, as `displayedResults` is: not the page.
            (Self.searchSheet, #"let results = searchVM.displayedResults"#,
             Self.collocates, #"let shown = search.sort.sorted(loaded.filter { !search.hides($0) })"#),
            // The order a scan reads the results in, which decides what one the budget stops reads.
            ("App/MacSearchViewModel.swift", #"var allSortedResults: [SearchResult] { sortOrder.sorted(results) }"#,
             Self.collocates, #"search.sort.sorted(loaded.filter"#),
            // iOS's panel rebuilds as the Mac's does.
            (Self.searchView, #"guard !results.isEmpty else { collocation = .unavailable(.noMatches); return }"#,
             Self.collocates, #"guard !results.isEmpty else { return .unavailable(.noMatches) }"#),
            ("kit:FRUSCoreKit/Search/CollocationConfiguration.swift", #"public static func configured(tuning: WordCloudTuning, includeDiplomatic: Bool, languageAnalysis: NaturalLanguageHealth, stopwords: WordCloudStopwordSet, lexicons: WordCloudLexiconSet) -> CollocationConfiguration {"#,
             Self.collocates, #"let configuration = CollocationConfiguration.configured( tuning: settings.tuning, includeDiplomatic: settings.includeDiplomatic, languageAnalysis: WordCloudLive.tagger.health, stopwords: stopwords, lexicons: lexicons)"#),
            ("Search/CollocationService.swift", #"let includeDiplomatic = UserDefaults.standard .object(forKey: WordCloudSettings.Keys.excludeBoilerplate) as? Bool ?? true"#,
             Self.collocates, #"tuning: settings.tuning, includeDiplomatic: settings.includeDiplomatic,"#),
        ])
    }

    @Test func thePanelsControlsOrdersAndCaveatAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.collocationView, #"static let windowSizes = [5, 10, 20, 50]"#,
             Self.collocates, #"static let windowSizes = [5, 10, 20, 50]"#),
            (Self.searchSheet, #"@AppStorage(SearchCollocationDefaults.windowKey) private var collocationWindow = 10"#,
             Self.collocates, #"static let defaultWindow = 10"#),
            (Self.collocationView, #"case evidence"#, Self.collocates, #"case evidence"#),
            (Self.collocationView, #"case effect"#, Self.collocates, #"case effect"#),
            (Self.collocationView, #"return scores.sorted { $0.logLikelihood == $1.logLikelihood ? $0.term < $1.term : $0.logLikelihood > $1.logLikelihood }"#,
             Self.collocates, #"return scores.sorted { $0.logLikelihood == $1.logLikelihood ? $0.term < $1.term : $0.logLikelihood > $1.logLikelihood }"#),
            (Self.collocationView, #"func unpriced(_ s: KeynessScore) -> Bool { s.referenceCount == 0 && cutoffCount > 1 } return scores.sorted { if unpriced($0) != unpriced($1) { return !unpriced($0) } return $0.logRatio == $1.logRatio ? $0.term < $1.term : $0.logRatio > $1.logRatio }"#,
             Self.collocates, #"func unpriced(_ s: KeynessScore) -> Bool { s.referenceCount == 0 && cutoffCount > 1 } return scores.sorted { if unpriced($0) != unpriced($1) { return !unpriced($0) } return $0.logRatio == $1.logRatio ? $0.term < $1.term : $0.logRatio > $1.logRatio }"#),
            (Self.collocationView, #"ForEach(Array(order.apply(to: result.scores, cutoffCount: result.referenceCutoffCount)"#,
             Self.collocates, #"order.apply(to: result.scores, cutoffCount: result.referenceCutoffCount)"#),
            (Self.collocationView, #"if score.referenceCount == 0, result.referenceCutoffCount > 1 {"#,
             Self.collocates, #"unpriced: score.referenceCount == 0 && result.referenceCutoffCount > 1)"#),
            (Self.collocationView, #"CollocationCaveatCopy.scanned(matches: result.anchorCount, documents: result.documentsScanned)"#,
             Self.collocates, #"scanned(matches: result.anchorCount, documents: result.documentsScanned),"#),
            (Self.collocationView, #"if result.wasBounded { parts.append(CollocationCaveatCopy.bounded(offered: result.documentsOffered, inScope: result.documentsInScope)) }"#,
             Self.collocates, #"if result.wasBounded { parts.append(bounded(offered: result.documentsOffered, inScope: result.documentsInScope)) }"#),
            (Self.collocationView, #"if result.omittedAnchorCount > 0 {"#, Self.collocates, #"if result.omittedAnchorCount > 0 {"#),
            (Self.collocationView, #"Int64(result.referenceCutoffCount)), at: 0)"#, Self.collocates, #"Int64(result.referenceCutoffCount)), at: 0)"#),
            (Self.collocationView, #"let text = parts.joined(separator: " ")"#, Self.collocates, #"return parts.joined(separator: " ")"#),
            (Self.collocationView, #"CountCopy.documents(documents, locale: locale))"#, Self.collocates, #"CountCopy.documents(documents, locale: SearchItem.locale))"#),
            (Self.collocationView, #"offered.formatted(.number.locale(locale)), inScope.formatted(.number.locale(locale)))"#,
             Self.collocates, #"grouped(offered), grouped(inScope))"#),
            (Self.collocationView, #"Text(String(format: String(localized: "search.collocation.window %lld", defaultValue: "±%lld words"), Int64($0))).tag($0)"#,
             Self.collocates, #"String(format: appWords("search.collocation.window %lld", "±%lld words"), Int64(size))"#),
            // What the set measured over says of itself, the keyword route's.
            (Self.scope, #"var hiddenByChecklist: Int { max(0, loaded - shown) }"#, Self.collocates, #"var hiddenByChecklist: Int { max(0, loaded - shown) }"#),
            (Self.scope, #"if didHitFetchLimit { return true } if case .truncated = appliedCorpusTruncation { return true }"#,
             Self.collocates, #"var isPartialEvidence: Bool { didHitFetchLimit || insideTruncatedCorpus }"#),
            (Self.scope, #"case .keywords: break } if loaded >= fetchLimit { return true } if let totalMatchCount { return totalMatchCount > loaded }"#,
             Self.collocates, #"var didHitFetchLimit: Bool { loaded >= SearchRequest.retainedLimit || total > loaded }"#),
            (Self.scope, #"description = isPartialEvidence ? String(localized: "search.collocation.caveat.scope.loaded.capped","#,
             Self.collocates, #"var description = facts.isPartialEvidence ? appWords("search.collocation.caveat.scope.loaded.capped","#),
            (Self.scope, #"if hiddenByChecklist > 0 { // #1683: one excluded document read "1 reviewed documents are excluded." description += CountCopy.phrase(hiddenByChecklist,"#,
             Self.collocates, #"if facts.hiddenByChecklist > 0 { description += CountCopy.phrase( facts.hiddenByChecklist,"#),
        ])
    }

    @Test func distinctiveRanksTheTermsShownAsTheAppsViewRanksThem() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.cloudView, #"result.visibleTerms(excluding: sessionHiddenWords)"#,
             Self.distinctive, #"terms: result.visibleTerms(excluding: hidden),"#),
            (Self.cloudView, #"scopeTotal: result.totalTokenCount,"#, Self.distinctive, #"scopeTotal: result.totalTokenCount,"#),
            (Self.cloudView, #"fetchedTermCount: result.terms.count, termLimit: Self.termLimit, lens: lens, tuning: WordCloudSettings.tuning, includeDiplomatic: excludeBoilerplate,"#,
             Self.distinctive, #"fetchedTermCount: result.terms.count, termLimit: WordCloudLive.termLimit, lens: lens, tuning: settings.tuning, includeDiplomatic: settings.includeDiplomatic,"#),
            (Self.cloudView, #"result.languageAnalysis ?? languageHealth"#,
             Self.distinctive, #"languageAnalysis: result.languageAnalysis ?? WordCloudLive.tagger.health,"#),
            (Self.cloudView, #"return KeynessCloud.layoutTerms(ranking.scores)"#, Self.distinctive, #"reading.layout = KeynessCloud.layoutTerms(ranking.scores)"#),
            (Self.cloudView, #"for: displayState, shownTerms: ranking?.scores.count ?? visibleTerms.count,"#,
             Self.distinctive, #"reading.countLine = countLine(terms: ranking.scores.count, documents: result.documentCount)"#),
            (Self.cloudView, #"if ranking.rankedAmongTopFrequent {"#, Self.distinctive, #"if ranking.rankedAmongTopFrequent {"#),
            (Self.cloudView, #"Int64(ranking.candidateCount)))"#, Self.distinctive, #"Int64(ranking.candidateCount)))"#),
            (Self.cloudView, #"Int64(ranking.minimumScopeCount)))"#, Self.distinctive, #"Int64(ranking.minimumScopeCount)))"#),
            (Self.cloudView, #"if ranking.referenceCutoffCount > 1 {"#, Self.distinctive, #"if ranking.referenceCutoffCount > 1 {"#),
            (Self.cloudView, #"if ranking?.isUnpriced(score) == true, let cutoff = ranking?.referenceCutoffCount {"#,
             Self.distinctive, #"unpriced: ranking.isUnpriced(score),"#),
            (Self.cloudView, #"Self.mismatchDescription(mismatches))"#, Self.distinctive, #"mismatchDescription(mismatches))"#),
            (Self.cloudView, #"guard fold.isFinite, fold > 0 else { return "" }"#,
             Self.screen, #"const fold = Number.isFinite(score.fold) && score.fold > 0 ? words.foldPhrase(multiple) : '';"#),
            (Self.cloudView, #"let fraction = maxScore > 0 ? CGFloat(max(0, min(1, score / maxScore))) : 0"#,
             Self.screen, #"style={{ width: `${Math.round(60 * Math.max(0, Math.min(1, term.score.logLikelihood / maxScore)))}px` }}"#),
            (Self.cloudView, #"let maxScore = scores.first?.logLikelihood ?? 1"#, Self.screen, #"const maxScore = scores?.[0]?.logLikelihood ?? 1;"#),
            (Self.cloudView, #"Text("\(foldDifference(score)) · \(countsCaption(for: score))")"#, Self.screen, #"{fold ? `${fold} · ${counts}` : counts}"#),
        ])
    }

    @Test func theBrowsersKeysAndNumbersAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.collocationView, #"static let windowKey = "frus.search.collocation.window""#,
             Self.readings, #"const collocationKeys = { window: 'frus.search.collocation.window', order: 'frus.search.collocation.order' };"#),
            (Self.collocationView, #"static let orderKey = "frus.search.collocation.order""#,
             Self.readings, #"order: 'frus.search.collocation.order' };"#),
            (Self.collocationView, #"static let windowSizes = [5, 10, 20, 50]"#, Self.readings, #"const collocationWindows = [5, 10, 20, 50];"#),
            (Self.searchSheet, #"private var collocationWindow = 10"#, Self.readings, #"return collocationWindows.includes(value) ? value : 10;"#),
            (Self.searchSheet, #"private var collocationOrderRaw = CollocationOrder.evidence.rawValue"#,
             Self.readings, #"return storedValue(collocationKeys.order) === 'effect' ? 'effect' : 'evidence';"#),
            (Self.collocationView, #"let formatted = fold >= 10 ? fold.formatted(.number.precision(.fractionLength(0))) : fold.formatted(.number.precision(.fractionLength(1)))"#,
             Self.copy, #"fold >= 10 ? fold.toLocaleString('en-US', { maximumFractionDigits: 0, roundingMode: 'halfEven' }) : fold.toLocaleString('en-US', { minimumFractionDigits: 1, maximumFractionDigits: 1, roundingMode: 'halfEven' }),"#),
            (Self.collocationView, #"case .evidence: return Self.scoreFormatter.string(from: NSNumber(value: score.logLikelihood)) ?? """#,
             Self.readings, #"{order === 'evidence' ? copy.collocates.evidence(neighbour.logLikelihood) : copy.collocates.concentration(multiple)}"#),
            (Self.collocationView, #"f.maximumFractionDigits = 1 f.minimumFractionDigits = 1"#,
             Self.copy, #"logLikelihood.toLocaleString('en-US', { minimumFractionDigits: 1, maximumFractionDigits: 1, roundingMode: 'halfEven' }),"#),
            (Self.collocationView, #"fold.formatted(.number.precision(.fractionLength(1)))) + "×""#, Self.copy, #"concentration: (multiple: string) => `${multiple}×`,"#),
            (Self.collocationView, #"if let note = result.printedFormsNote { printedFormsNoteRow(note) }"#,
             Self.readings, #"{data.printedFormsNote && <p className="caption collocates-printed">{data.printedFormsNote}</p>}"#),
            (Self.collocationView, #"enum CollocationOrder: String, CaseIterable, Sendable { /// Log-likelihood — the corpus-linguistics standard, and comparable with published figures. case evidence"#,
             Self.readings, #"const collocationOrders: readonly CollocationOrder[] = ['evidence', 'effect'];"#),
        ])
    }

    /// Every word the two new server files write through `appWords`, each where the app's source writes it under its key.
    @Test func theAppsWordsAreTheServers() throws {
        let apps = try [Self.collocationView, Self.scope, Self.cloudView].map(ArchivalAndSeriesMirrorParityTests.source).joined(separator: " ")
        let server = try [Self.collocates, Self.distinctive].map(ArchivalAndSeriesMirrorParityTests.source).joined(separator: " ")
        let pattern = try NSRegularExpression(pattern: #"appWords\("((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\)"#)
        let words = pattern.matches(in: server, range: NSRange(server.startIndex..., in: server)).map { match in
            (key: String(server[Range(match.range(at: 1), in: server)!]), value: String(server[Range(match.range(at: 2), in: server)!]))
        }
        #expect(words.count >= 30, "the server writes \(words.count) of the app's words")
        for word in words {
            #expect(NoteViewParityTests.writes(apps, word.key, word.value), "the app writes \(word.key) as \(word.value)")
        }
    }

    /// The app's words copy.ts takes for Collocates and Distinctive, each where the app's source writes it, and the
    /// phrases it composes from the app's.
    @Test func theAppsWordsAreTheWebs() throws {
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let words: [(file: String, key: String, value: String, block: String, web: String)] = [
            (Self.collocationView, "search.collocation.window.label", "Within", "collocates", "within"),
            (Self.collocationView, "search.collocation.order.label", "Rank by", "collocates", "rankBy"),
            (Self.collocationView, "search.collocation.loading", "Reading the words around your matches…", "collocates", "loading"),
            (Self.collocationView, "search.collocation.order.evidence", "Evidence", "collocates", "evidence"),
            (Self.collocationView, "search.collocation.order.effect", "Concentration", "collocates", "effect"),
            (Self.cloudView, "wordcloud.word.search", "Search for this term", "collocates", "searchHint"),
            (Self.searchView, "search.mode.collocates", "Collocates", "readings", "collocates"),
            (Self.cloudView, "wordcloud.keyness.unavailable.title", "No Distinctiveness Ranking", "wordCloud", "keynessTitle"),
        ]
        for word in words {
            let app = try ArchivalAndSeriesMirrorParityTests.source(word.file)
            #expect(NoteViewParityTests.writes(app, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            let block = try NoteViewParityTests.block(word.block, of: copy)
            #expect(block.contains("\(word.web): '\(word.value)'"), "copy.ts's \(word.block) block has \(word.web): \(word.value)")
        }
        let view = try ArchivalAndSeriesMirrorParityTests.source(Self.collocationView)
        let cloud = try ArchivalAndSeriesMirrorParityTests.source(Self.cloudView)
        let collocates = try NoteViewParityTests.block("collocates", of: copy)
        let wordCloud = try NoteViewParityTests.block("wordCloud", of: copy)
        // The Within picker's choices.
        #expect(view.contains(#"Text(String(format: String(localized: "search.collocation.window %lld", defaultValue: "±%lld words"), Int64($0))).tag($0)"#)
                && collocates.contains("window: (size: number) => `±${size} words`"))
        // A neighbour's row, the app's two forms, its counts grouped as #1683 grouped the caveat's.
        #expect(NoteViewParityTests.writes(view, "search.collocation.row.counts %@ %lld %lld", "%@× more often here · %lld nearby · %lld corpus-wide")
                && collocates.contains("`${multiple}× more often here · ${nearby.toLocaleString('en-US')} nearby · ${corpusWide.toLocaleString('en-US')} corpus-wide`"))
        #expect(NoteViewParityTests.writes(view, "search.collocation.row.unpriced %@ %lld %lld", "%@× more often here · %lld nearby · fewer than %lld corpus-wide (unpriced)")
                && collocates.contains("`${multiple}× more often here · ${nearby.toLocaleString('en-US')} nearby · fewer than ${cutoff.toLocaleString('en-US')} corpus-wide (unpriced)`"))
        // A Distinctive row's multiple, its counts in their two forms, and the app's reading of it aloud.
        #expect(NoteViewParityTests.writes(cloud, "wordcloud.keyness.row.fold %@", "%@× more often here")
                && wordCloud.contains("foldPhrase: (multiple: string) => `${multiple}× more often here`"))
        #expect(NoteViewParityTests.writes(cloud, "wordcloud.keyness.row.counts %lld %lld", "%lld here · %lld corpus-wide")
                && wordCloud.contains("`${here.toLocaleString('en-US')} here · ${corpusWide.toLocaleString('en-US')} corpus-wide`"))
        #expect(NoteViewParityTests.writes(cloud, "wordcloud.keyness.row.counts.unpriced %lld %lld", "%lld here · fewer than %lld corpus-wide (unpriced)")
                && wordCloud.contains("`${here.toLocaleString('en-US')} here · fewer than ${cutoff.toLocaleString('en-US')} corpus-wide (unpriced)`"))
        #expect(NoteViewParityTests.writes(cloud, "wordcloud.keyness.row.a11y %@ %@ %@", "keyness %@; %@; %@")
                && wordCloud.contains("keynessA11y: (value: string, fold: string, counts: string) => `keyness ${value}; ${fold}; ${counts}`"))
        // The refusal S24i offered in the picker's place is gone, and so is Distinctive's.
        #expect(!copy.contains("collocatesUnavailable") && !copy.contains("keynessReason"))
    }
}
