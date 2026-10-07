// The kit's stack over the live index, opened read-only and immutable: search and browse (upstream
// #1575), and the page ranges and persons the reader's links need (upstream #1579).

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation

/// The live index as the kit reads it, for one installed `CorpusIndex`: `FTS5Store(readingDatabaseAt:)`,
/// the pipeline's read-only open and a `SearchService` over both, and the page-range and person
/// stores' read-only opens. Nothing here writes to the file: every connection is
/// `mode=ro&immutable=1`, as `CorpusIndex`'s own.
public final class ServedIndex: Sendable {
    public let corpus: CorpusIndex
    public let pipeline: IndexingPipeline
    public let service: SearchService
    /// Which document holds a printed page, for a page link.
    public let pages: PageRangeStore
    /// The persons' mentions and rollups, for a person card's count.
    public let persons: PersonMentionStore

    /// Opens the stack, and refuses it unless the path still named the file `corpus` opened before
    /// the first open and after the last: an import renames its new file over the path before the
    /// server starts serving it, and a stack over that file would answer as the old index.
    init(corpus: CorpusIndex, resources: ServerResources, volumesDirectory: URL) throws {
        self.corpus = corpus
        let before = FileIdentity(corpus.url)
        let store = try FTS5Store(readingDatabaseAt: corpus.url)
        pipeline = try IndexingPipeline(readingIndexAt: corpus.url, fts5Store: store,
                                        resources: resources.indexing, volumesDirectory: volumesDirectory)
        service = SearchService(fts5Store: store, pipeline: pipeline)
        pages = try PageRangeStore(readingDatabaseAt: corpus.url)
        persons = try PersonMentionStore(readingDatabaseAt: corpus.url)
        guard let expected = corpus.file, before == expected, FileIdentity(corpus.url) == expected else {
            throw APIProblem(.serviceUnavailable, code: "INDEX_NOT_READY",
                             detail: "A new index is being installed; ask again in a moment.")
        }
    }
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
    private var current: (corpus: ObjectIdentifier, served: ServedIndex)?
    private var opening: (corpus: ObjectIdentifier, task: Task<ServedIndex, any Error>)?
    /// How many stacks have been opened, for the tests.
    private(set) var opened = 0

    public init(state: ServerState, resources: ServerResources, volumesDirectory: URL) {
        self.state = state
        self.resources = resources
        self.volumesDirectory = volumesDirectory
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
        let (resources, volumesDirectory) = (self.resources, self.volumesDirectory)
        let task = Task<ServedIndex, any Error> {
            try await Blocking.run { try ServedIndex(corpus: corpus, resources: resources, volumesDirectory: volumesDirectory) }
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
