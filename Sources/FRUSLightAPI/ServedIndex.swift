// The kit's stack over the live index, opened read-only and immutable: search and browse (upstream
// #1575), the page ranges and persons the reader's links need (upstream #1579), and the citation
// matcher over both that Citation Lookup asks (PLAN's S19a); with the user store's search database
// attached, read-only, for each user's half of a search (upstream #1806, PLAN's S17d); and a
// connection of its own for what the app reads with its own queries, a collection document's
// cross-references (PLAN's S18e).

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation

/// The live index as the kit reads it, for one installed `CorpusIndex`: `FTS5Store(readingDatabaseAt:)`,
/// the pipeline's read-only open and a `SearchService` over both, and the page-range and person
/// stores' read-only opens. Nothing here writes to the file: every connection is
/// `mode=ro&immutable=1`, as `CorpusIndex`'s own. The pipeline's connection also attaches the user
/// store's search database, when the server keeps user data, read-only and never immutable, as the
/// kit attaches a store its host writes to while it is served (`attachedUserStoreSchema`).
public final class ServedIndex: Sendable {
    public let corpus: CorpusIndex
    public let pipeline: IndexingPipeline
    /// The corpus's search, whose user half is the index's own, which an import leaves empty: a search
    /// that acts for no one, Citation Lookup's matcher, and what compiles a query.
    public let service: SearchService
    private let fts5: FTS5Store
    /// Whether the user store's search database is attached, so that a search can read a user's half.
    let attachesUserStore: Bool
    /// Which document holds a printed page, for a page link.
    public let pages: PageRangeStore
    /// The persons' mentions and rollups, for a person card's count, and a collection's Persons Index.
    public let persons: PersonMentionStore
    /// The index read as the app's own stores read it, where the kit offers no read: a collection
    /// document's cross-references (PLAN's S18e, `outboundTargets`).
    let references: SQLiteConnection
    /// The kit's citation matcher over this index and the published catalogue, with the volumes
    /// the index holds as the device's downloaded ones, as the reader's page links take them: the
    /// app builds its engine over its own index, its catalogue and the volumes on its disk.
    public let citations: CitationMatchingEngine
    /// The facet sections computed lately over this index; a new index starts with none.
    public let facets = FacetCache()
    /// The results the app keeps of each search run lately over this index, for its date order.
    public let retained = RetainedResults()
    /// The pages and counts of the searches run lately by relevance over this index.
    public let recent = RecentSearches()
    /// The volumes the index holds documents of: what a working corpus and a volume scope resolve
    /// against (PLAN's S17e), as the app resolves them against the volumes its device has indexed.
    public let indexedVolumeIds: Set<String>

    /// Opens the stack, with `userStore` attached when it names the user store's search database,
    /// and refuses it unless the path still named the file `corpus` opened before the first open and
    /// after the last: an import renames its new file over the path before the server starts serving
    /// it, and a stack over that file would answer as the old index.
    init(corpus: CorpusIndex, resources: ServerResources, volumesDirectory: URL, userStore: URL? = nil) throws {
        self.corpus = corpus
        let before = FileIdentity(corpus.url)
        let store = try FTS5Store(readingDatabaseAt: corpus.url)
        pipeline = try IndexingPipeline(readingIndexAt: corpus.url, fts5Store: store,
                                        resources: resources.indexing, volumesDirectory: volumesDirectory, userStore: userStore)
        service = SearchService(fts5Store: store, pipeline: pipeline)
        fts5 = store
        attachesUserStore = userStore != nil
        pages = try PageRangeStore(readingDatabaseAt: corpus.url)
        persons = try PersonMentionStore(readingDatabaseAt: corpus.url)
        references = try SQLiteConnection.immutable(corpus.url)
        indexedVolumeIds = Set(corpus.documentsByVolume.filter { $0.value > 0 }.keys)
        citations = CitationMatchingEngine(manifestStore: FixedVolumeCatalogue(entries: resources.manifest),
                                           searchService: service, pageRangeStore: pages,
                                           downloadedVolumeIds: indexedVolumeIds)
        guard let expected = corpus.file, before == expected, FileIdentity(corpus.url) == expected else {
            throw APIProblem(.serviceUnavailable, code: "INDEX_NOT_READY",
                             detail: "A new index is being installed; ask again in a moment.")
        }
    }

    /// A search as `user` makes it, with their half from the attached store, or the corpus's alone for
    /// no one. Its service is new for each request, which the kit makes cheap, as the pipeline is shared.
    func search(for user: SearchUser?) throws -> ServedSearch {
        guard let user else { return ServedSearch(service: service, key: "") }
        guard attachesUserStore else {
            throw APIProblem(.internalServerError, code: "INTERNAL_ERROR", detail: "The served index has no user store attached.")
        }
        return ServedSearch(service: SearchService(fts5Store: fts5, pipeline: pipeline, userSource: .attachedStore(userId: user.id)),
                            key: user.key)
    }
}

/// A search over the served index as one user makes it (PLAN's S17d): the kit's service with that
/// user's half, or the corpus's alone, and what begins the key each of its answers is kept by
/// (`RecentSearches`, `RetainedResults`, `FacetCache`), so that no answer is given to another user,
/// nor once their store has moved.
struct ServedSearch: Sendable {
    let service: SearchService
    /// Nothing for the corpus's search, whose keys are as they were before S17d.
    let key: String
}

/// Gives each request the stack for the index being served, built once per installed index.
///
/// An import replaces `frus.db` by renaming the new file over it, and `ServerState` then holds a
/// new `CorpusIndex`. The next request builds a stack over the new file, while requests already
/// holding the old stack finish on the file they opened: its connections are immutable, and keep
/// reading the replaced file, which is also `frus.db.prev`. A request that comes between the
/// rename and the new `CorpusIndex` gets a 503, since the path no longer names the served index's
/// file. Requests that arrive while a stack is being opened wait for it, and a stack that fails to
/// open is tried again by the next request.
public actor ServedIndexProvider {
    let state: ServerState
    let resources: ServerResources
    let volumesDirectory: URL
    /// The user store's search database, which each stack attaches (S17d), or nil for none.
    let userStore: URL?
    private var current: (corpus: ObjectIdentifier, served: ServedIndex)?
    private var opening: (corpus: ObjectIdentifier, task: Task<ServedIndex, any Error>)?
    /// How many stacks have been opened, for the tests.
    private(set) var opened = 0

    public init(state: ServerState, resources: ServerResources, volumesDirectory: URL, userStore: URL? = nil) {
        self.state = state
        self.resources = resources
        self.volumesDirectory = volumesDirectory
        self.userStore = userStore
    }

    /// The stack for the index being served. Throws a 503 `INDEX_NOT_READY` problem naming the
    /// readiness step while none is, as before the first import.
    public func served() async throws -> ServedIndex {
        guard let corpus = await state.index else {
            let readiness = await state.readiness()
            throw APIProblem(.serviceUnavailable, code: "INDEX_NOT_READY",
                             detail: "No index is being served yet (\(readiness.step.rawValue)): \(readiness.detail)")
        }
        let key = ObjectIdentifier(corpus)
        if let current, current.corpus == key { return current.served }
        if let opening, opening.corpus == key { return try await opening.task.value }
        let (resources, volumesDirectory, userStore) = (self.resources, self.volumesDirectory, self.userStore)
        let task = Task<ServedIndex, any Error> {
            try await Blocking.run {
                try ServedIndex(corpus: corpus, resources: resources, volumesDirectory: volumesDirectory, userStore: userStore)
            }
        }
        opening = (key, task)
        opened += 1
        defer { if opening?.corpus == key { opening = nil } }
        let served = try await task.value
        if current?.corpus != key, await state.index.map(ObjectIdentifier.init) == key { current = (key, served) }
        return served
    }

    /// The stack, or nil while no index is served, for routes that work without one.
    public func servedIfReady() async throws -> ServedIndex? {
        await state.index == nil ? nil : try await served()
    }
}
