// Live word clouds (PLAN's S29e): every scope the app's Word Cloud takes, counted on the server from the served index's
// text by the kit's count (FRUS-Explorer#1987, S29b) with the web's tagger (FRUSLanguage's `FRUSWordCloudTagger`, S29d),
// under the reader's own settings.
//
// A scope is resolved as the app's `WordCloudScopeResolver.resolve` resolves it, with its limits, from the reader's rows
// and the served index: a document; a volume's documents, a subseries' (the catalogue's volumes of it), a volume
// scope's members' and a subject's volumes'; a collection's entries; the documents a tag is on; a saved search's
// results, run as the reader's search at the app's `SearchViewModel.searchHardLimit`, 1,000; the documents of a range
// of dates, at most the app's 5,000 (`dateRangeKeyLimit`); and the corpus, every document the index holds. The count is
// `WordCloudCount.count` over their `body_text`, the tokenizer the kit's assembly (`WordCloudTokenizer.configured`)
// from the reader's settings and the app's word lists in the tagger's word form, the result its top 1,000, the app's
// `WordCloudLoader.standardTermLimit`.
//
// A count is kept by its scope, its lens, the settings it was counted under and the tagger's identity, on the served
// index it was counted from (`ServedIndex.wordClouds`), so a new index starts with none; a scope of a reader's own is
// kept by its owner and its documents too, so that a collection that gains a document is counted again. A count that
// outlasts a request is a job of the server's queue, which the page follows: the corpus's, a subseries' and a subject's,
// the scopes whose counts the app keeps on disk and reports progress for (`WordCloudLoader`'s persistent scopes, and the
// corpus), and, the web's own, any other of more than 5,000 documents. A request for a scope whose job runs is that
// job. The app's disk cache, which keeps a count across launches, is not the server's: a count is kept while its index
// is served, and a restart counts again.

import FRUSCoreKit
import FRUSLanguage
import FRUSLightCore
import FTS5Store
import Foundation
import WordCloudKit

extension JobKind {
    /// A word cloud counted over the served index that outlasts a request (PLAN's S29e).
    static let wordCloud = JobKind(rawValue: "wordCloud")
}

// MARK: - A scope resolved

/// A scope as the app's `WordCloudScopeResolver.resolve` resolves it, on the server: its title, the documents whose text
/// feeds its cloud, and whose records it reads.
struct CloudResolution: Sendable {
    /// Where the scope's documents come from, read from the served index when the cloud is counted.
    enum Documents: Sendable {
        /// Every document the index holds (`allDocumentKeys()`).
        case corpus
        /// Each volume's documents, in this order (`keys(forVolume:)`): a volume, a subseries, a volume scope, a subject.
        case volumes([String])
        /// These documents: a document, a collection's entries, the documents a tag is on.
        case keys([WordCloudDocumentKey])
        /// A saved search's results, run as `user`'s search.
        case search(SearchParameters, user: String)
        /// The documents dated in the range, oldest first, at most `WordCloudLive.dateRangeKeyLimit`.
        case dateRange(DateRange)
    }

    let scope: WordCloudScope
    /// The cloud's title, the resolver's.
    let title: String
    let documents: Documents
    /// The user whose records the scope reads: a collection's, a tag's, a saved search's or a volume scope's owner.
    let owner: String?
    /// The volume scope's members, for the scoped hand-off (`customScopeAnalyticsIds()`).
    let members: [String]?
}

// MARK: - The count's key and its keeping

/// What a count is kept by (PLAN's S29e): its scope, its lens, the settings it was counted under and the tagger's
/// identity; a scope of a reader's own by its owner and its documents too.
struct CloudCountKey: Hashable, Sendable {
    let scope: String
    let lens: WordCloudLens
    let settings: String
    let tokenizer: WordCloudTokenizerIdentity
}

/// The live counts of one served index (PLAN's S29e). A count within a request and a job's count are kept apart, each
/// the least recently asked let go past its capacity, so that many small counts never push out a count of the corpus
/// that took minutes; a count that fails keeps nothing. A job is tracked by its key while it has not ended, with the
/// readers who wait on it: a request for a key whose job runs is that job, and a reader who asks for another count that
/// runs as a job leaves the one they waited on, which is stopped once no one waits on it, as the app's view stops the
/// count a new scope, lens or setting replaces.
actor WordCloudKeeper {
    private var kept: [CloudCountKey: WordCloudResult] = [:]
    private var recency: [CloudCountKey] = []
    private var counted: [CloudCountKey: WordCloudResult] = [:]
    private var countedRecency: [CloudCountKey] = []
    private var jobs: [CloudCountKey: String] = [:]
    private var waiters: [CloudCountKey: Set<String>] = [:]
    /// The key of the job each reader waits on, by their id, or `WordCloudLive.noOne` for the requests that act for no one.
    private var waiting: [String: CloudCountKey] = [:]
    private var submitting: [CloudCountKey: Task<Job, any Error>] = [:]
    let capacity: Int
    let jobCapacity: Int

    init(capacity: Int = 48, jobCapacity: Int = 24) {
        self.capacity = capacity
        self.jobCapacity = jobCapacity
    }

    /// The count kept for `key`, a job's or a request's, or nil.
    func result(for key: CloudCountKey) -> WordCloudResult? {
        if let result = counted[key] {
            countedRecency.removeAll { $0 == key }
            countedRecency.append(key)
            return result
        }
        guard let result = kept[key] else { return nil }
        recency.removeAll { $0 == key }
        recency.append(key)
        return result
    }

    /// Keeps `result` for `key`: among the jobs' counts, or among the requests'.
    func keep(_ result: WordCloudResult, for key: CloudCountKey, byJob: Bool = false) {
        if byJob {
            counted[key] = result
            countedRecency.removeAll { $0 == key }
            countedRecency.append(key)
            while countedRecency.count > jobCapacity { counted[countedRecency.removeFirst()] = nil }
        } else {
            kept[key] = result
            recency.removeAll { $0 == key }
            recency.append(key)
            while recency.count > capacity { kept[recency.removeFirst()] = nil }
        }
    }

    /// The job counting `key` for `reader`: the one `queue` holds for it while it has not ended, the one being queued
    /// meanwhile, or the one `submit` queues now. The job `reader` waited on for another key is stopped, by `canceller`,
    /// once no one else waits on it.
    func job(for key: CloudCountKey, reader: String, in queue: any JobQueue, canceller: String?,
             submit: @escaping @Sendable () async throws -> Job) async throws -> Job {
        if let previous = waiting[reader], previous != key {
            waiters[previous]?.remove(reader)
            if waiters[previous]?.isEmpty ?? true, let id = jobs[previous] {
                waiters[previous] = nil
                _ = try? await queue.cancel(id, by: canceller)
            }
        }
        waiting[reader] = key
        waiters[key, default: []].insert(reader)
        if let pending = submitting[key] { return try await pending.value }
        if let id = jobs[key], let job = await queue.job(id), !job.state.isFinished { return job }
        // Asked again while the queue answered: that request's job is this one.
        if let pending = submitting[key] { return try await pending.value }
        let task = Task { try await submit() }
        submitting[key] = task
        defer { submitting[key] = nil }
        let job = try await task.value
        jobs[key] = job.id
        return job
    }

    /// How many counts are kept, for the tests.
    var count: Int { kept.count + counted.count }
}

/// How many counts run within requests at once (PLAN's S29e): each holds a thread of its own while it tags, so a burst of
/// requests waits its turn rather than taking every processor; a request that goes before its turn leaves the line.
actor CountGate {
    private let limit: Int
    private var running = 0
    private var line: [(id: UUID, continuation: CheckedContinuation<Void, any Error>)] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    /// Runs `work` once a turn is free, the turn given back when it ends, however it ends.
    func run<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await acquire()
        do {
            let value = try await work()
            release()
            return value
        } catch {
            release()
            throw error
        }
    }

    private func acquire() async throws {
        if running < limit {
            running += 1
            return
        }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    line.append((id, continuation))
                }
            }
        } onCancel: {
            Task { await self.leave(id) }
        }
    }

    private func leave(_ id: UUID) {
        guard let index = line.firstIndex(where: { $0.id == id }) else { return }
        line.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    /// A turn given back: to the first in line, or to no one.
    private func release() {
        if line.isEmpty {
            running -= 1
        } else {
            line.removeFirst().continuation.resume()
        }
    }
}

// MARK: - Where a count runs

/// A serial executor over a Dispatch queue of its own: a count's tagging, which holds a thread for seconds, or for minutes
/// over the corpus, runs on it rather than on Swift's cooperative pool, which has one thread per CPU, as `Blocking` runs
/// the server's blocking work.
final class CloudCountExecutor: SerialExecutor, @unchecked Sendable {
    private let queue: DispatchQueue

    init(label: String) {
        queue = DispatchQueue(label: label, qos: .utility)
    }

    func enqueue(_ job: consuming ExecutorJob) {
        let unowned = UnownedJob(job)
        queue.async { unowned.runSynchronously(on: self.asUnownedSerialExecutor()) }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }
}

/// One count's actor (PLAN's S29e), on an executor of its own: `WordCloudCount.count` runs on its caller's actor, as the
/// app's runs on its service's, so the tagging runs on this one's queue, and each count on another's.
actor WordCloudCounter {
    private let executor = CloudCountExecutor(label: "frus-light.word-cloud")

    nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }

    /// The kit's count of `keys`, in the tokenizer's lens and form, with the web's tagger, stamped with the index version.
    func count(keys: [WordCloudDocumentKey], pipeline: IndexingPipeline, tokenizer: WordCloudTokenizer, tagger: FRUSWordCloudTagger,
               indexVersion: Int, minimumCount: Int, progress: WordCloudProgress?) async throws -> WordCloudResult {
        try await WordCloudCount.count(keys: keys, pipeline: pipeline, tokenizer: tokenizer, tagger: tagger,
                                       countedUnder: tagger.health, indexVersion: indexVersion,
                                       limit: WordCloudLive.termLimit, minimumCount: minimumCount, progress: progress)
    }
}

/// The documents a job's count has read, which its watcher reports.
private final class CountProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var value: (done: Int, total: Int)?

    func set(_ done: Int, _ total: Int) {
        lock.lock()
        value = (done, total)
        lock.unlock()
    }

    var latest: (done: Int, total: Int)? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

// MARK: - The live count

/// The live count's rules and limits (PLAN's S29e).
enum WordCloudLive {
    /// `WordCloudLoader.standardTermLimit`: the terms a count keeps, the candidate pool Distinctive re-ranks (S29f).
    static let termLimit = 1_000
    /// `WordCloudScopeResolver.dateRangeKeyLimit`: the documents a range of dates reads, Chronology's load limit.
    static let dateRangeKeyLimit = 5_000
    /// The documents a count reads within a request, the web's own: one of more is a job.
    static let requestLimit = 5_000

    /// The tagger the server counts with, and its identity and health, the family's (S29d).
    static let tagger = FRUSWordCloudTagger()

    /// The turns of the counts within requests: half the processors, from one to four.
    static let gate = CountGate(limit: min(4, ProcessInfo.processInfo.activeProcessorCount / 2))

    /// Whom the requests that act for no one wait as, together: a reader's id never holds a NUL.
    static let noOne = "\u{0}no one"

    /// Whether a scope's count always runs as a job: the corpus, a subseries and a subject, the scopes whose counts the
    /// app keeps on disk and whose progress it reports (`WordCloudLoader`'s `isPersistentScope`, and the corpus's
    /// `corpusTopTerms`).
    static func isHeavy(_ scope: WordCloudScope) -> Bool {
        switch scope {
        case .corpus, .subseries, .subjectCategory: true
        case .document, .volume, .collection, .userTag, .savedSearch, .customScope, .dateRange: false
        }
    }

    /// The key `resolution`'s count under `lens` and `settings` is kept by: a scope of a reader's own by its owner and
    /// its documents, since they change without the index.
    static func key(_ resolution: CloudResolution, lens: WordCloudLens, settings: CloudSettings,
                    keys: [WordCloudDocumentKey]?) -> CloudCountKey {
        var scope = resolution.scope.signature
        if let owner = resolution.owner {
            scope += "|owner=\(owner)|documents=\(keys.map(fingerprint) ?? "")"
        }
        return CloudCountKey(scope: scope, lens: lens, settings: settings.token(for: lens), tokenizer: tagger.identity)
    }

    /// A fingerprint of a list of documents: its length and FNV-1a, 64 bits, over each key in order.
    static func fingerprint(_ keys: [WordCloudDocumentKey]) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for key in keys {
            for byte in key.volumeId.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3 }
            hash = (hash ^ 0x2f) &* 0x0000_0100_0000_01b3
            for byte in key.documentId.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3 }
            hash = (hash ^ 0x0a) &* 0x0000_0100_0000_01b3
        }
        return "\(keys.count).\(String(hash, radix: 16))"
    }

    /// The documents `resolution` counts, read from `served` as the app's resolver reads them.
    static func keys(_ resolution: CloudResolution, served: ServedIndex, services: UserDataServices?) async throws -> [WordCloudDocumentKey] {
        switch resolution.documents {
        case .corpus:
            return try await served.pipeline.allDocumentKeys()
        case .volumes(let ids):
            var keys: [WordCloudDocumentKey] = []
            for id in ids {
                keys += try await served.pipeline.documents(forVolume: id).map {
                    WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
                }
            }
            return keys
        case .keys(let keys):
            return keys
        case .search(let parameters, let user):
            guard let services else { return [] }
            let store = services.store
            let mark = try await Blocking.run { try store.searchMark() }
            let search = try served.search(for: SearchUser(id: user, mark: mark))
            do {
                return try await search.service.search(parameters: parameters, limit: SmartCollectionSnapshot.resultLimit)
                    .map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
            } catch let error as FTS5Error {
                throw SearchRoutes.refusal(error)
            }
        case .dateRange(let range):
            return try await served.pipeline.documentsInDateRange(range, scopeVolumeIds: nil, ascending: true, limit: dateRangeKeyLimit)
                .map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
        }
    }

    /// The kit's tokenizer for `lens` under `settings`, over the app's lists, in the tagger's form (S29b's notes: the
    /// count holds the tokenizer's form to its verdict's).
    static func tokenizer(for lens: WordCloudLens, settings: CloudSettings, resources: ServerResources) async throws -> WordCloudTokenizer {
        let (stopwords, lexicons) = try await Blocking.run {
            (resources.familyClouds.stopwords(in: resources.directory), resources.familyClouds.lexicons(in: resources.directory))
        }
        return WordCloudTokenizer.configured(tuning: settings.tuning, lens: lens, includeDiplomatic: settings.includeDiplomatic,
                                             extraStopwords: settings.extraStopwords(for: lens), wordForm: tagger.health.wordForm,
                                             stopwords: stopwords, lexicons: lexicons)
    }

    /// The kit's count of `keys` over `served` under `lens` and `settings`, on a counter of its own.
    static func count(_ keys: [WordCloudDocumentKey], lens: WordCloudLens, settings: CloudSettings, served: ServedIndex,
                      resources: ServerResources, progress: WordCloudProgress? = nil) async throws -> WordCloudResult {
        guard !keys.isEmpty else { return .empty }
        let tokenizer = try await tokenizer(for: lens, settings: settings, resources: resources)
        return try await WordCloudCounter().count(keys: keys, pipeline: served.pipeline, tokenizer: tokenizer, tagger: tagger,
                                                  indexVersion: served.corpus.summary.indexVersion,
                                                  minimumCount: settings.tuning.minimumCount, progress: progress)
    }

    /// What a job's row in the admin's Jobs list says it counts, in the server's words, holding nothing of a reader's
    /// research, as a job's subject never does: the catalogue's scopes by their titles, and a reader's own by its kind and
    /// id, as Suggested Next's job names its project.
    static func subject(_ resolution: CloudResolution, lens: WordCloudLens) -> String {
        let scope: String
        switch resolution.scope {
        case .collection(let id): scope = "Collection \(id.uuidString)"
        case .userTag(let id): scope = "Tag \(id.uuidString)"
        case .savedSearch(let id): scope = "Saved search \(id.uuidString)"
        case .customScope(let id): scope = "Volume scope \(id.uuidString)"
        case .corpus, .subseries, .volume, .document, .subjectCategory, .dateRange: scope = resolution.title
        }
        return "\(scope.replacingOccurrences(of: "\n", with: " ").split(separator: " ").joined(separator: " ")) · \(CloudRules.label(lens))"
    }

    /// The job counting `resolution` under `lens` and `settings` for `reader`, the one queued already while it has not
    /// ended, or one queued now; the job `reader` waited on for another count is stopped once no one else waits on it. The
    /// job reads the index served when it starts, not the one served when it was asked for, so that a job queued behind a
    /// reset or a compaction holds no stack the queue's job before it must let go; its steps say what it reads, a cancel
    /// stops it between two chunks of documents, and its count is kept on that index's keeper when it ends.
    static func job(_ resolution: CloudResolution, key: CloudCountKey, lens: WordCloudLens, settings: CloudSettings,
                    keeper: WordCloudKeeper, provider: ServedIndexProvider, resources: ServerResources, services: UserDataServices,
                    requestedBy user: String?) async throws -> Job {
        try await keeper.job(for: key, reader: user ?? noOne, in: services.jobs, canceller: user) {
            try await submit(resolution, key: key, lens: lens, settings: settings, provider: provider, resources: resources,
                             services: services, requestedBy: user)
        }
    }

    /// Queues the job ``job(_:key:lens:settings:keeper:provider:resources:services:requestedBy:)`` gives.
    private static func submit(_ resolution: CloudResolution, key: CloudCountKey, lens: WordCloudLens, settings: CloudSettings,
                               provider: ServedIndexProvider, resources: ServerResources, services: UserDataServices,
                               requestedBy user: String?) async throws -> Job {
        try await services.jobs.submit(.wordCloud, subject: subject(resolution, lens: lens), requestedBy: user, id: nil) { job in
            try await job.step("Finding the scope’s documents")
            guard let served = try await provider.servedIfReady() else {
                throw JobFailed("No index is served, so the cloud was not counted.")
            }
            let keys = try await Self.keys(resolution, served: served, services: services)
            try await job.step("Counting the words of \(CountCopy.documents(keys.count, locale: SearchItem.locale))", fraction: 0)
            let progress = CountProgress()
            let result = try await withThrowingTaskGroup(of: WordCloudResult?.self) { group in
                group.addTask {
                    try await Self.count(keys, lens: lens, settings: settings, served: served, resources: resources,
                                         progress: { done, total in progress.set(done, total) })
                }
                // The watcher: the job's line follows the count, and a cancel asked for stops it at its next chunk.
                group.addTask {
                    while true {
                        try await Task.sleep(for: .milliseconds(500))
                        if await job.cancelRequested { throw JobCancelled() }
                        if let latest = progress.latest, latest.total > 0 {
                            await job.progress("Counted the words of \(grouped(latest.done)) of \(CountCopy.documents(latest.total, locale: SearchItem.locale))",
                                               fraction: Double(latest.done) / Double(latest.total))
                        }
                    }
                }
                defer { group.cancelAll() }
                guard let first = try await group.next(), let result = first else { throw JobCancelled() }
                return result
            }
            await served.wordClouds.keep(result, for: key, byJob: true)
            return "Counted \(CloudRules.countLine(terms: result.terms.count, documents: result.documentCount))"
        }
    }
}

// MARK: - The settings, as a count is kept by them

extension CloudSettings {
    /// What a count under these settings is kept by, for `lens`: the tuning's token, the diplomatic layer and the
    /// words hidden from the lens, as the app's caches key them (`WordFrequencyService.cacheKey`), the words as a JSON
    /// list, where the app joins them with commas, so that one hidden word holding a comma is never two.
    func token(for lens: WordCloudLens) -> String {
        "t=\(tuning.cacheToken)|diplo=\(includeDiplomatic)|x=\(TagReferences.encode(extraStopwords(for: lens).sorted()))"
    }

    /// Whether these settings are those the family's clouds were counted under, for `lens`: the file's tuning, the
    /// diplomatic layer on and no word hidden from the lens, so that its list is the count they would make (PLAN's
    /// S29e). Any other settings are counted live.
    func areTheFamilys(_ file: CloudVectorsFile, lens: WordCloudLens) -> Bool {
        tuning == file.provenance.tuning && includeDiplomatic == CloudRules.generatorIncludesDiplomatic
            && extraStopwords(for: lens).isEmpty
    }
}

// MARK: - The answers

extension CloudRules {
    /// `WordCloudDisplayState.resolve`'s states for a count in hand: none read when no document was, no terms when the
    /// lens kept none, too few for a signal-dependent lens, and otherwise the terms.
    static func state(counted result: WordCloudResult, lens: WordCloudLens) -> String {
        if result.terms.isEmpty { return result.documentCount == 0 ? "noIndexedText" : "noTerms" }
        if lens.isSignalDependent && result.terms.count < lens.minimumSignalTerms { return "insufficientSignal" }
        return "terms"
    }

    /// `WordCloudDisplayState.countLine(terms:documents:)`: "12 terms from 4,591 documents", both by `CountCopy`'s rule.
    static func countLine(terms: Int, documents: Int) -> String {
        String(format: appWords("wordcloud.provenance %@ %@", "%1$@ from %2$@"),
               CountCopy.phrase(terms,
                                one: appWords("wordcloud.count.terms.one", "%@ term"),
                                many: appWords("wordcloud.count.terms.many", "%@ terms"),
                                locale: SearchItem.locale),
               CountCopy.documents(documents, locale: SearchItem.locale))
    }

    /// `WordCloudDisplayState.lensesStillWorking(under:)`: the lenses `health` draws, in the lens bar's order.
    static func lensesStillWorking(under health: NaturalLanguageHealth) -> [WordCloudLens] {
        WordCloudLens.allCases.filter { health.supports($0) }
    }

    /// The message of a lens the server's tagger cannot serve, in the terms of the kit's health, the web's own, since
    /// the app's are a device's whose tagger fails for a while (FRUS-Explorer#1972): which capability it lacks, so the
    /// lens is not drawn, and the lenses still drawn.
    static func lensUnavailable(_ lens: WordCloudLens, health: NaturalLanguageHealth) -> CloudAnswer.Message {
        let working = listed(lensesStillWorking(under: health).map(label))
        let lacks = lens.isEntity ? "does not recognize names" : "does not tell nouns, verbs and adjectives apart"
        return .init(title: "Lens Unavailable on This Server",
                     detail: "This server’s tagger \(lacks), so the “\(label(lens))” lens can’t be drawn. \(working) still work.")
    }

    /// Names joined as the app's English list joins them: "a and b", "a, b, and c".
    static func listed(_ names: [String]) -> String {
        switch names.count {
        case 0: ""
        case 1: names[0]
        case 2: "\(names[0]) and \(names[1])"
        default: names.dropLast().joined(separator: ", ") + ", and " + names[names.count - 1]
        }
    }

    /// What the main area says while a count runs as a job: the app's words for a subseries, and for the corpus the web's,
    /// since the app's say that closing the screen stops a count, where a job runs on.
    static func countingMessage(_ scope: WordCloudScope) -> CloudAnswer.Message {
        let detail: String
        switch scope {
        case .corpus:
            detail = "This server is counting every indexed document as a job, which on a full library takes some minutes. The finished cloud is kept, and leaving this page does not stop it."
        case .subseries:
            detail = appWords("wordcloud.loading.subseries", "Reading this subseries’ documents. This can take a minute or two.")
        default:
            detail = "This server is counting this scope’s documents as a job. The finished cloud is kept, and leaving this page does not stop it."
        }
        return .init(title: appWords("wordcloud.loading", "Building word cloud…"), detail: detail)
    }

    /// The account of a live count, the web's own: what it counted, with which tagger, under whose settings.
    static func liveAccount(_ result: WordCloudResult, settings: CloudSettings, hasReader: Bool) -> String {
        let under = settings == .standard ? "at the standard settings" : hasReader ? "under your settings" : "at these settings"
        return "This cloud was counted from its scope’s \(CountCopy.documents(result.documentCount, locale: SearchItem.locale)) by this server’s own tagger, \(WordCloudLive.tagger.identity), \(under)."
    }

    /// `scopedAnalyzeMenuLabel` and `analyticsScope()` for the scopes beside a volume and a subseries: a volume scope's
    /// indexed members and a subject's volumes, never an empty set (#258); none for the others.
    static func analyzeWithin(_ resolution: CloudResolution, indexed: Set<String>, resources: ServerResources) -> CloudAnswer.AnalyzeWithin? {
        switch resolution.scope {
        case .volume(let volumeId):
            return analyzeWithin(.volume(volumeId: volumeId, subseries: ""), title: resolution.title, resources: resources)
        case .subseries(let subseriesId):
            return analyzeWithin(.subseries(subseriesId), title: resolution.title, resources: resources)
        case .customScope:
            guard case .resolved(let ids) = CustomScopeResolver.indexedResolution(memberVolumeIds: resolution.members ?? [], indexed: indexed)
            else { return nil }
            return .init(label: appWords("wordcloud.word.analyze.customScope", "Analyze within this scope"), volumeIds: ids.sorted(),
                         scopeLabel: resolution.title.isEmpty ? appWords("wordcloud.scope.customScope", "Volume Scope") : resolution.title)
        case .subjectCategory:
            guard case .volumes(let ids) = resolution.documents, !ids.isEmpty else { return nil }
            return .init(label: appWords("wordcloud.word.analyze.subject", "Analyze within this subject"), volumeIds: ids.sorted(),
                         scopeLabel: resolution.title.isEmpty ? appWords("wordcloud.scope.subject", "Subject") : resolution.title)
        case .corpus, .document, .collection, .userTag, .savedSearch, .dateRange:
            return nil
        }
    }

    /// A count's answer: its words, the state, the count line and the account.
    static func live(_ result: WordCloudResult, into answer: inout CloudAnswer, lens: WordCloudLens, settings: CloudSettings,
                     hasReader: Bool, lexicons: WordCloudLexiconSet) {
        let state = state(counted: result, lens: lens)
        answer.source = "live"
        answer.state = state
        answer.message = message(state: state, lens: lens)
        answer.terms = result.terms.map {
            CloudAnswer.Term(term: $0.term, count: $0.count,
                             polarity: lens.colorsBySentiment ? lexicons.polarity(of: $0.term.lowercased()) : nil)
        }
        answer.countLine = countLine(terms: result.terms.count, documents: result.documentCount)
        answer.documentCount = result.documentCount
        answer.listed = result.terms.count
        answer.removed = 0
        answer.settingsNotShown = nil
        answer.account = liveAccount(result, settings: settings, hasReader: hasReader)
    }
}
