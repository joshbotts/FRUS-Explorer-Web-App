// The three fixture volumes indexed once per test process by FRUSCoreKit, for checks 2 and 3.

import FRUSLightTestSupport
import FRUSParity
import Foundation
import ParityFormat

/// The fixture index the check 2 and check 3 tests share, and the copy of it check 2 summarizes.
///
/// Swift Testing has no set-up for a suite, so the first test to await `value()` starts the build
/// and the others wait for the same one. The volumes are copied into the index's folder first, so
/// indexing never touches `fixtures/tei`; the copy is taken as soon as the passes after indexing
/// have run, before any search, as an export is. The folder lasts as long as the process.
enum FixtureIndex {
    struct Built: Sendable {
        let directory: TemporaryDirectory
        let index: ParityIndex
        /// The index, copied out of write-ahead-log mode, as `IndexSummarizer` reads it.
        let copy: URL
    }

    static func value() async throws -> Built { try await shared.value }

    private static let shared = Task<Built, any Error> {
        let directory = try TemporaryDirectory()
        let layout = Repository.layout
        let tei = directory.url.appendingPathComponent("Volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: tei, withIntermediateDirectories: true)
        for volume in ParityFixtures.volumes {
            try FileManager.default.copyItem(at: layout.tei.appendingPathComponent("\(volume).xml"),
                                             to: tei.appendingPathComponent("\(volume).xml"))
        }
        let index = try await ParityIndex.build(
            volumes: ParityFixtures.volumes, tei: tei,
            resources: layout.upstream.appendingPathComponent(ParityIndex.resourcesPath),
            database: directory.url.appendingPathComponent("frus.db"))
        let copy = directory.url.appendingPathComponent("copy.db")
        try IndexCopy.rollbackJournal(of: index.database, to: copy)
        return Built(directory: directory, index: index, copy: copy)
    }
}
