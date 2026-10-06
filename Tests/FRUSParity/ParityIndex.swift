// Checks 2 and 3 on Linux: TEI volumes indexed by FRUSCoreKit's pipeline through its public API
// alone, as the server's indexer will be, and the copy of that index the summary reads.
//
// The pipeline is given what the app gives it: the four data files that change what an index holds,
// from the submodule's FRUSExplorer/Resources, and a stamp store, here in memory. It indexes the
// volumes in the order given and then runs the passes after indexing, as the app's launch does.

import FRUSCoreKit
import FTS5Store
import Foundation
import ParityFormat

/// An index FRUSCoreKit built from TEI volumes: the database, the search service over it, and how
/// the build went.
public struct ParityIndex: Sendable {
    /// The app's data files, relative to the submodule.
    public static let resourcesPath = "FRUSExplorer/Resources"

    /// The index, in write-ahead-log mode while the pipeline holds it open.
    public let database: URL
    public let pipeline: IndexingPipeline
    public let service: SearchService
    /// Each volume's documents in `document_cache`, by volume id.
    public let documents: [String: Int]
    /// Whether the passes after indexing rebuilt the person rollup, as they must on a new index.
    public let rollupRebuilt: Bool
    /// Each volume's indexing, then the passes after it, timed, with the peak memory.
    public let metrics: IndexingMetrics

    /// Indexes `volumes`, in the order given, from `<tei>/<volume>.xml` into a new database at
    /// `database`, with the data files in `resources`, then runs the passes after indexing. It
    /// refuses a database that exists, and a folder lacking one of the four data files.
    public static func build(volumes: [String], tei: URL, resources: URL, database: URL) async throws -> ParityIndex {
        guard !FileManager.default.fileExists(atPath: database.path) else {
            throw IndexBuildError("\(database.path) exists; the index is built into a new file")
        }
        let resources = try IndexingResources.loading(fromDirectory: resources)
        let store = try FTS5Store(databaseURL: database)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: database, volumesDirectory: tei,
                                            resources: resources, defaults: InMemoryIndexingStampStore())
        var metrics = IndexingMetrics()
        var documents: [String: Int] = [:]
        for volume in volumes {
            documents[volume] = try await metrics.measureDocuments("index \(volume)") {
                try await pipeline.indexVolume(volume)
                return try await pipeline.documents(forVolume: volume).count
            }
        }
        let rebuilt = await metrics.measure("post-index passes") { await pipeline.runPostIndexPasses() }
        return ParityIndex(database: database, pipeline: pipeline, service: SearchService(fts5Store: store, pipeline: pipeline),
                           documents: documents, rollupRebuilt: rebuilt, metrics: metrics)
    }
}

/// Why an index could not be built or copied.
public struct IndexBuildError: Error, CustomStringConvertible, Equatable, Sendable {
    public let description: String
    public init(_ description: String) { self.description = description }
}

public enum IndexCopy {
    /// Copies the index at `source` page for page into a new file at `destination` with SQLite's
    /// backup API, and takes the copy out of write-ahead-log mode: what `IndexSummarizer` reads,
    /// since it refuses an index whose log may hold pages. The source is opened read-only through
    /// the normal pager, which reads its log, never with `immutable=1`, which would not. Both
    /// connections close before it returns.
    public static func rollbackJournal(of source: URL, to destination: URL) throws {
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw IndexBuildError("\(destination.path) exists; the copy is made into a new file")
        }
        let target = try ParityDatabase.create(destination)
        try ParityDatabase.readOnly(source).backup(into: target)
        try target.execute("PRAGMA journal_mode=DELETE")
        let mode = try target.scalar("PRAGMA journal_mode")?.text
        guard mode == "delete" else {
            throw IndexBuildError("the copy's journal mode is \(mode ?? "unknown"), not delete")
        }
    }
}
