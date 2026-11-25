// GET /api/v1/search/collocates (PLAN's S29f): Search's fourth reading, Collocates, the words a search's matches keep
// company with, as the Mac's window builds it (`SearchSheet.rebuildCollocation`): over the results the app keeps of the
// search, 7,500 at most, less those Checklist Mode hides, in the order `sort` gives them (`displayedResults`, whose order
// decides which results a scan the budget stops reads), not the page on screen, the kit's scan
// (`SearchService.collocation(for:parameters:windowSize:configuration:reference:tagger:maxMatches:)`, S29b) collects the
// words within a window of each match, the windows merged so that a word near two matches counts once, at most 200
// matches a document and the kit's token budget, counts them with the web's tagger (FRUSLanguage's
// `FRUSWordCloudTagger`, S29d) in its word form, and ranks them through `Keyness` against the language family's reference
// counted in that form. The configuration is the kit's over the reader's own Word Cloud settings and the app's word
// lists (`CollocationConfiguration.configured`: All terms, the reader's tuning and diplomatic layer, the tagger's
// verdict), and the reference the kit's lookup for it (`KeynessReferences.baseline`), whose refusals map to Collocates'
// as the app's rebuild maps them. What the app's panel says of a ranking and of each refusal is app code
// (`CollocationView`, `CollocationCaveatCopy`, `ResultSetScope.collocationScopeDescription`, `CollocationOrder`),
// mirrored here under its names and held to the app's source by `CollocatesParityTests`; a count in a form no reference
// this server holds was counted in is said in the server's words, since the app's are a device's (FRUS-Explorer#1972).
//
// The scan tags for a second or more over a full index, on its search service's actor: the request has a service of
// its own, so the corpus's shared one is never held, takes a turn of the counts' gate (S29e), and prefers an executor of
// its own, a serial Dispatch queue, which a default actor's work follows, so that the tagging holds no thread of Swift's
// cooperative pool, and the kit's fan-out of a chunk's documents runs on it one after another, bounded as the tagging
// is; and it stops when its client goes, between chunks of 400 documents.

import FRUSCoreKit
import FRUSLanguage
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird
import WordCloudKit

/// A search's collocates (PLAN's S29f): the words near its matches over the results the app keeps of it, ranked by how
/// distinctive their company is, or why there are none, with what the scan saw, as the Mac's panel says it.
public struct SearchCollocates: Codable, Equatable, Sendable, ResponseEncodable {
    /// Words either side of each match, and the windows the panel offers, each with the app's label (`±10 words`).
    public var window: Int
    public var windowChoices: [Choice]
    /// The orders the list can be ranked in, `CollocationOrder`'s, each with the app's label; the first is the app's.
    public var orderChoices: [Choice]
    /// `ranked`, or `unavailable` with its reason and the panel's words for it.
    public var state: String
    /// Why there is no ranking: the kit's `CollocationAnalysis.Unavailable` (`scanFailed`, `noArtifact`,
    /// `configurationMismatch`, `languageAnalysisUnavailable`, `noMatches`, `noNeighboursAboveFloor`, `nothingDistinctive`).
    public var reason: String?
    /// "No Collocates", and the refusal's detail.
    public var message: Message?
    /// For `configurationMismatch`, the kit's names of what differs.
    public var mismatches: [String]?
    /// The row a ranking of printed forms opens with, and a refusal that is a result of such a count (#1608).
    public var printedFormsNote: String?
    /// What the scan could and could not see, above the list (`CollocationView.caveat`).
    public var caveat: String?
    /// The neighbours over-represented beside the matches, most distinctive first, as the kit ranks them.
    public var items: [Neighbour]
    /// Each order of the neighbours, by its raw value, as positions in `items` (`CollocationOrder.apply(to:cutoffCount:)`).
    public var orders: [String: [Int]]
    /// What the scan read, as the kit's `CollocationResult` holds it.
    public var documentsScanned: Int?
    public var documentsInScope: Int?
    public var documentsOffered: Int?
    public var anchorCount: Int?
    public var omittedAnchorCount: Int?
    public var windowTokenCount: Int?
    public var minimumCount: Int?
    public var referenceCutoffCount: Int?
    public var generated: String?
    /// `dictionary` or `printed`: the form the neighbours and the reference were both counted in.
    public var wordForm: String?
    /// Whether the budget stopped the scan short of the results (`CollocationResult.wasBounded`).
    public var wasBounded: Bool?
    /// The results the app keeps of a search, and how many of this one's it kept, before Checklist Mode.
    public var retainedLimit: Int
    public var retainedCount: Int
    public var coverage: Coverage

    public struct Message: Codable, Equatable, Sendable {
        public var title: String
        public var detail: String
    }

    /// A neighbour: the kit's `KeynessScore`, with the multiple the app's row says, and whether it is rarer corpus-wide
    /// than the reference prices, which the row says plainly.
    public struct Neighbour: Codable, Equatable, Sendable {
        public var term: String
        /// Occurrences within the merged windows, and in the corpus reference.
        public var nearby: Int
        public var corpusWide: Int
        /// Signed log-likelihood, G², Evidence's measure.
        public var logLikelihood: Double
        /// Log₂ of the two relative frequencies, Concentration's, and the plain multiple it is (`foldOverRepresentation`).
        public var logRatio: Double
        public var fold: Double
        public var unpriced: Bool
    }
}

/// What the results the panel measured over say of themselves (`ResultSetScope`'s keyword route): how many the app kept,
/// how many Checklist Mode left, the match's count, and whether the working corpus the search ran inside was itself a
/// capture cut short.
struct CollocationScopeFacts: Equatable, Sendable {
    let loaded: Int
    let shown: Int
    let total: Int
    let insideTruncatedCorpus: Bool

    /// `didHitFetchLimit`, the keyword route's: the fetch reached its ceiling, or the count exceeds it.
    var didHitFetchLimit: Bool { loaded >= SearchRequest.retainedLimit || total > loaded }
    /// `isPartialEvidence` for a keyword search.
    var isPartialEvidence: Bool { didHitFetchLimit || insideTruncatedCorpus }
    /// `hiddenByChecklist`.
    var hiddenByChecklist: Int { max(0, loaded - shown) }
}

enum CollocatesRoutes {
    /// The field `/search/collocates` takes beside a search's and its page's: the window. The page says nothing of it,
    /// which reads every result kept, and is taken so a search's address can be read as it stands; the order is the
    /// order the scan reads the results in.
    static let fields: Set<String> = ["window"]

    /// The collocates of the search `form` says, for the user `request` acts for, under their Word Cloud settings.
    static func collocates(_ form: FormQuery, request: Request, context: APIRequestContext, provider: ServedIndexProvider,
                           resources: ServerResources, users: SearchUsers) async throws -> SearchCollocates {
        let search = try SearchRequest(form: form, alsoTaking: fields)
        let window = try CollocationRules.window(form)
        let user = try await users.user(searching: search.parameters, for: request, context: context)
        let reader = try await WordCloudRoutes.reader(for: request, context: context, users: users)
        let served = try await provider.served()
        let insideTruncated = try await truncatedCorpus(search.workingCorpusId, of: user, users: users)
        let parameters = try await users.inside(search.workingCorpusId, search.parameters, for: user, served: served)
        // A service of the request's own, which the scan holds while it tags, never the corpus's shared one.
        let scoped = try served.ownSearch(for: user)
        let coverage = Coverage(index: served.corpus, resources: resources)
        return try await context.whileClientConnected {
            do {
                async let kept = served.retained.results(of: parameters, in: scoped)
                let total = try await served.recent.count(of: parameters, in: scoped)
                let loaded = try await kept
                // In Checklist Mode, the results kept less those it hides, in the order chosen, as the Mac's panel reads
                // `displayedResults`: a scan the budget stops reads the first of them.
                let shown = search.sort.sorted(loaded.filter { !search.hides($0) })
                let outcome = try await outcome(of: shown, parameters: parameters, window: window, settings: reader.settings,
                                                scoped: scoped, resources: resources)
                let facts = CollocationScopeFacts(loaded: loaded.count, shown: shown.count, total: total,
                                                  insideTruncatedCorpus: insideTruncated)
                return answer(outcome, window: window, facts: facts, coverage: coverage)
            } catch let error as FTS5Error {
                throw SearchRoutes.refusal(error)
            }
        }
    }

    /// Whether the working corpus a search runs inside was itself a capture cut short (`appliedCorpusTruncation`).
    static func truncatedCorpus(_ id: String?, of user: SearchUser?, users: SearchUsers) async throws -> Bool {
        guard let id, let user, let services = users.services else { return false }
        let corpus = try await WorkingCorpusRoutes.corpus(id, of: user.id, in: services.store)
        if case .truncated = CorpusCaptureTruncation(wasTruncated: corpus.wasTruncatedAtCapture,
                                                      totalMatchCount: corpus.totalMatchCountAtCapture) {
            return true
        }
        return false
    }

    /// `SearchView.rebuildCollocation` on the server: none for no results; the kit's configuration over the reader's
    /// settings and the app's lists in the tagger's form, and the reference the kit's lookup gives it, whose refusals
    /// are Collocates' as the app maps them; then the kit's scan over `results`, a cancellation the client's going and a
    /// failure `scanFailed`.
    static func outcome(of results: [SearchResult], parameters: SearchParameters, window: Int, settings: CloudSettings,
                        scoped: ServedSearch, resources: ServerResources) async throws -> CollocationAnalysis.Outcome {
        guard !results.isEmpty else { return .unavailable(.noMatches) }
        let (stopwords, lexicons, references) = try await Blocking.run {
            (resources.familyClouds.stopwords(in: resources.directory), resources.familyClouds.lexicons(in: resources.directory),
             resources.familyClouds.references(language: resources.languageDirectory, lists: resources.directory))
        }
        // ONE resolution of the settings and of the verdict, shared by the tokenizer and the reference lookup.
        let configuration = CollocationConfiguration.configured(
            tuning: settings.tuning, includeDiplomatic: settings.includeDiplomatic,
            languageAnalysis: WordCloudLive.tagger.health, stopwords: stopwords, lexicons: lexicons)
        let availability = references.baseline(
            for: .allTerms, tuning: configuration.tuning,
            includeDiplomatic: configuration.includeDiplomatic,
            languageAnalysis: configuration.languageAnalysis, tokenizer: WordCloudLive.tagger.identity)
        let reference: KeynessReference
        switch availability {
        case .unavailable(.noArtifact), .unavailable(.lensNotPriced):
            return .unavailable(.noArtifact)
        case .unavailable(.languageAnalysisUnavailable):
            return .unavailable(.languageAnalysisUnavailable)
        case .unavailable(.configurationMismatch(let mismatches)):
            return .unavailable(.configurationMismatch(mismatches))
        case .available(let found):
            reference = found
        }
        do {
            // In a turn of the counts' gate, on an executor of its own: see the file's head.
            return try await WordCloudLive.gate.run {
                try await CollocationExecutor.run(label: "frus-light.collocates") {
                    try await scoped.service.collocation(for: results, parameters: parameters, windowSize: window,
                                                         configuration: configuration, reference: reference,
                                                         tagger: WordCloudLive.tagger)
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            return .unavailable(.scanFailed)
        }
    }

    /// The answer of `outcome`, in the app's words.
    static func answer(_ outcome: CollocationAnalysis.Outcome, window: Int, facts: CollocationScopeFacts,
                       coverage: Coverage) -> SearchCollocates {
        var answer = SearchCollocates(
            window: window,
            windowChoices: CollocationRules.windowSizes.map { Choice(value: String($0), title: CollocationRules.windowLabel($0)) },
            orderChoices: CollocationRules.Order.allCases.map { Choice(value: $0.rawValue, title: $0.pickerLabel) },
            state: "unavailable", items: [], orders: [:], retainedLimit: SearchRequest.retainedLimit,
            retainedCount: facts.loaded, coverage: coverage)
        switch outcome {
        case .unavailable(let reason):
            answer.reason = CollocationRules.name(of: reason)
            answer.message = .init(title: CollocationRules.unavailableTitle, detail: CollocationRules.detail(for: reason))
            answer.printedFormsNote = CollocationRules.printedFormsNote(for: reason)
            if case .configurationMismatch(let mismatches) = reason { answer.mismatches = mismatches.map(\.rawValue) }
        case .ranked(let result):
            answer.state = "ranked"
            answer.items = result.scores.map { score in
                SearchCollocates.Neighbour(term: score.term, nearby: score.scopeCount, corpusWide: score.referenceCount,
                                           logLikelihood: score.logLikelihood, logRatio: score.logRatio,
                                           fold: score.foldOverRepresentation,
                                           unpriced: score.referenceCount == 0 && result.referenceCutoffCount > 1)
            }
            let position = Dictionary(result.scores.enumerated().map { ($0.element.term, $0.offset) }, uniquingKeysWith: { first, _ in first })
            answer.orders = Dictionary(uniqueKeysWithValues: CollocationRules.Order.allCases.map { order in
                (order.rawValue, order.apply(to: result.scores, cutoffCount: result.referenceCutoffCount).compactMap { position[$0.term] })
            })
            answer.caveat = CollocationRules.caveat(result, facts: facts)
            answer.printedFormsNote = CollocationRules.printedFormsNote(for: result.wordForm)
            answer.documentsScanned = result.documentsScanned
            answer.documentsInScope = result.documentsInScope
            answer.documentsOffered = result.documentsOffered
            answer.anchorCount = result.anchorCount
            answer.omittedAnchorCount = result.omittedAnchorCount
            answer.windowTokenCount = result.windowTokenCount
            answer.minimumCount = result.minimumCount
            answer.referenceCutoffCount = result.referenceCutoffCount
            answer.generated = result.generated
            answer.wordForm = result.wordForm.rawValue
            answer.wasBounded = result.wasBounded
        }
        return answer
    }
}

/// What the Mac's Collocates panel decides between the kit and the screen, mirrored (PLAN's S29f).
enum CollocationRules {
    /// `CollocationView.windowSizes`: a clause, a sentence, a paragraph, where an arbitrary 13 is not a better question.
    static let windowSizes = [5, 10, 20, 50]
    /// `@AppStorage(SearchCollocationDefaults.windowKey) private var collocationWindow = 10`.
    static let defaultWindow = 10

    /// The window an address names, one the panel offers, or the app's default.
    static func window(_ form: FormQuery) throws -> Int {
        guard let raw = try form.single("window") else { return defaultWindow }
        guard let window = Int(raw), windowSizes.contains(window) else {
            throw APIProblem.invalidParameter("window", "must be one of \(windowSizes.map(String.init).joined(separator: ", ")), the windows the Mac's panel offers, not \(raw)")
        }
        return window
    }

    /// The Within picker's label for a window.
    static func windowLabel(_ size: Int) -> String {
        String(format: appWords("search.collocation.window %lld", "±%lld words"), Int64(size))
    }

    /// `CollocationOrder`: which number the list is ranked on.
    enum Order: String, CaseIterable, Sendable {
        /// Log-likelihood, the corpus-linguistics standard.
        case evidence
        /// The fold difference: how much more often the word appears here than corpus-wide.
        case effect

        /// `CollocationOrder.pickerLabel`.
        var pickerLabel: String {
            switch self {
            case .evidence: appWords("search.collocation.order.evidence", "Evidence")
            case .effect: appWords("search.collocation.order.effect", "Concentration")
            }
        }

        /// `CollocationOrder.apply(to:cutoffCount:)`: both orders total, the term breaking ties; Concentration puts the
        /// priced terms first, since an unpriced term's ratio is an upper bound.
        func apply(to scores: [KeynessScore], cutoffCount: Int = 1) -> [KeynessScore] {
            switch self {
            case .evidence:
                return scores.sorted { $0.logLikelihood == $1.logLikelihood ? $0.term < $1.term : $0.logLikelihood > $1.logLikelihood }
            case .effect:
                func unpriced(_ s: KeynessScore) -> Bool { s.referenceCount == 0 && cutoffCount > 1 }
                return scores.sorted {
                    if unpriced($0) != unpriced($1) { return !unpriced($0) }
                    return $0.logRatio == $1.logRatio ? $0.term < $1.term : $0.logRatio > $1.logRatio
                }
            }
        }
    }

    /// `search.collocation.unavailable.title`.
    static var unavailableTitle: String { appWords("search.collocation.unavailable.title", "No Collocates") }

    /// The kit's name of a refusal, `CollocationAnalysis.Unavailable`'s case.
    static func name(of reason: CollocationAnalysis.Unavailable) -> String {
        switch reason {
        case .pending: "pending"
        case .scanFailed: "scanFailed"
        case .noArtifact: "noArtifact"
        case .configurationMismatch: "configurationMismatch"
        case .languageAnalysisUnavailable: "languageAnalysisUnavailable"
        case .noMatches: "noMatches"
        case .noNeighboursAboveFloor: "noNeighboursAboveFloor"
        case .nothingDistinctive: "nothingDistinctive"
        }
    }

    /// `CollocationView.detail(for:)`: what the panel says for each refusal. A count in a form no reference this server
    /// holds was counted in is the server's words, the kit's health's terms (FRUS-Explorer#1972).
    static func detail(for reason: CollocationAnalysis.Unavailable) -> String {
        switch reason {
        case .pending:
            appWords("search.collocation.unavailable.pending", "Loading the bundled corpus reference…")
        case .scanFailed:
            appWords("search.collocation.unavailable.scanFailed", "The scan couldn’t finish. Try opening this panel again.")
        case .noArtifact:
            appWords("search.collocation.unavailable.noArtifact", "The bundled corpus reference could not be loaded, so there is nothing to measure these neighborhoods against.")
        case .configurationMismatch(let mismatches):
            String(format: appWords("search.collocation.unavailable.mismatch %@", "Your Word Cloud settings count words differently from the bundled corpus reference, so the two can’t be compared: %@. Restore that setting to rank these neighbors."),
                   CloudRules.mismatchDescription(mismatches))
        case .languageAnalysisUnavailable:
            "This server’s tagger does not reduce words to their dictionary forms, so the words near your matches were counted as printed, and this server holds no corpus reference counted as printed to compare them with."
        case .noMatches:
            appWords("search.collocation.unavailable.noMatches", "None of these results contains a whole word this measure can center on. Phrase, wildcard and proximity searches match in ways a word window cannot anchor to.")
        case .noNeighboursAboveFloor(let minimum, _):
            String(format: appWords("search.collocation.unavailable.floor %lld", "No word appears at least %lld times near your matches. A word used once or twice can top a ranking while telling you nothing about the documents, so nothing is ranked. Widen the window or run a broader search to give this more text to read."),
                   Int64(minimum))
        case .nothingDistinctive:
            appWords("search.collocation.unavailable.nothingDistinctive", "Nothing near your matches is used more here than across the corpus. That is a real result, not an error: this query sits in ordinary FRUS prose.")
        }
    }

    /// `CollocationAnalysis.printedFormsNote(for:)`: what the panel says of neighbours counted and compared as printed,
    /// none for a count in dictionary forms, in the server's words, since the kit's are a device's (FRUS-Explorer#1972).
    /// This server's tagger reduces words to their dictionary forms, so its counts never say it.
    static func printedFormsNote(for wordForm: WordCloudWordForm) -> String? {
        guard wordForm == .printed else { return nil }
        return "Compared as printed: this server’s tagger does not reduce words to their dictionary forms, so “negotiate” and “negotiated” count as two words, here and in the corpus reference. A device that does reduce them can rank these neighbors differently."
    }

    /// `Unavailable.printedFormsNote`: only the two refusals reached after the neighbours were counted carry a form.
    static func printedFormsNote(for reason: CollocationAnalysis.Unavailable) -> String? {
        switch reason {
        case .noNeighboursAboveFloor(_, let wordForm), .nothingDistinctive(let wordForm):
            printedFormsNote(for: wordForm)
        case .pending, .scanFailed, .noArtifact, .configurationMismatch, .languageAnalysisUnavailable, .noMatches:
            nil
        }
    }

    /// `CollocationView.caveat(_:)`: what the scan could and could not see, stated, never implied by a short list: which
    /// set was measured, then how much of it was seen, where it stopped, the matches the per-document bound skipped, and
    /// first the reference's cut, below which a word is unpriced.
    static func caveat(_ result: CollocationResult, facts: CollocationScopeFacts) -> String {
        var parts: [String] = [
            scopeDescription(facts),
            scanned(matches: result.anchorCount, documents: result.documentsScanned),
        ]
        if result.wasBounded {
            parts.append(bounded(offered: result.documentsOffered, inScope: result.documentsInScope))
        }
        if result.omittedAnchorCount > 0 {
            parts.append(String(format: appWords("search.collocation.caveat.perDocument %lld", "%lld further matches were skipped so no single document can dominate."),
                                Int64(result.omittedAnchorCount)))
        }
        if result.referenceCutoffCount > 1 {
            parts.insert(String(format: appWords("search.collocation.caveat.unpriced %lld", "Words occurring fewer than %lld times corpus-wide are unpriced and score as if new."),
                                Int64(result.referenceCutoffCount)), at: 0)
        }
        return parts.joined(separator: " ")
    }

    /// `ResultSetScope.collocationScopeDescription` for a keyword search, the readings' route: what the collocation
    /// measured over, with no numbers, and the reviewed documents Checklist Mode excludes.
    static func scopeDescription(_ facts: CollocationScopeFacts) -> String {
        var description = facts.isPartialEvidence
            ? appWords("search.collocation.caveat.scope.loaded.capped", "Measured over every result this search loaded, not the page on screen — those are the highest-scoring matches, not a sample of all of them.")
            : appWords("search.collocation.caveat.scope.loaded.complete", "Measured over every result this search loaded, which is every matching document.")
        if facts.hiddenByChecklist > 0 {
            description += CountCopy.phrase(
                facts.hiddenByChecklist,
                one: appWords("search.collocation.caveat.scope.checklist.one", " %@ reviewed document is excluded."),
                many: appWords("search.collocation.caveat.scope.checklist %@", " %@ reviewed documents are excluded."),
                locale: SearchItem.locale)
        }
        return description
    }

    /// `CollocationCaveatCopy.scanned(matches:documents:locale:)`: "6,387 matches, in 1,512 documents that had indexed text."
    static func scanned(matches: Int, documents: Int) -> String {
        String(format: appWords("search.collocation.caveat.scope.v3 %@ %@", "%1$@, in %2$@ that had indexed text."),
               CountCopy.phrase(matches,
                                one: appWords("search.collocation.caveat.matches.one", "%@ match"),
                                many: appWords("search.collocation.caveat.matches.many", "%@ matches"),
                                locale: SearchItem.locale),
               CountCopy.documents(documents, locale: SearchItem.locale))
    }

    /// `CollocationCaveatCopy.bounded(offered:inScope:locale:)`: the scan read fewer of the results than there are.
    static func bounded(offered: Int, inScope: Int) -> String {
        String(format: appWords("search.collocation.caveat.bounded.v3 %@ %@", "The scan stopped at %1$@ of your %2$@ results, so this ranking covers part of them, not all."),
               grouped(offered), grouped(inScope))
    }
}

// MARK: - Where the scan runs

/// A task executor over a serial Dispatch queue of its own (PLAN's S29f). Collocates' scan runs on its search service's
/// actor, a default actor, whose work runs on the executor the calling task prefers (SE-0417): so its tagging, which holds
/// a thread for a second or more over a full index, runs on this queue, rather than on Swift's cooperative pool, which has
/// one thread per processor, as `WordCloudCounter` keeps a count off it; and the kit's fan-out of a chunk's documents,
/// whose child tasks inherit the preference, runs on it one after another, where the app's runs them side by side.
///
/// Measured in swift:6.4-noble: an actor entered as a task's first work under the preference, from a thread of the pool,
/// runs on that thread until the task first suspends; entered once the task has moved to the preferred executor, it runs
/// there. So ``run(label:_:)`` moves the task onto the queue before its work begins.
final class CollocationExecutor: TaskExecutor, @unchecked Sendable {
    /// What a job on one of these queues finds as its queue's own value: the queue's label.
    static let label = DispatchSpecificKey<String>()

    private let queue: DispatchQueue

    init(label: String) {
        queue = DispatchQueue(label: label, qos: .utility)
        queue.setSpecific(key: Self.label, value: label)
    }

    func enqueue(_ job: consuming ExecutorJob) {
        let unowned = UnownedJob(job)
        queue.async { unowned.runSynchronously(on: self.asUnownedTaskExecutor()) }
    }

    func asUnownedTaskExecutor() -> UnownedTaskExecutor {
        UnownedTaskExecutor(ordinary: self)
    }

    /// `work`, preferring a queue of its own named `label`, onto which the task moves first.
    static func run<T: Sendable>(label: String, _ work: () async throws -> T) async throws -> T {
        try await withTaskExecutorPreference(CollocationExecutor(label: label)) {
            await Task.yield()
            return try await work()
        }
    }
}
