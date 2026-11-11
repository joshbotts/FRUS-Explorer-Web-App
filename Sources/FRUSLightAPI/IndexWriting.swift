// The served index while the library's indexing writes it (PLAN's S21d), and what an import that seeds a
// Standalone server's index tells the indexer.

import FRUSCoreKit
import FRUSLightCore
import Foundation

/// The served index as the library's indexing writes it: once a job has closed the index, it is opened
/// again and served, with the volumes and the counts it holds now, so that the next request's stack is
/// over it, and the stack's computations kept over the index before it are let go with it.
struct ServedIndexWriting: IndexWritingObserver {
    let state: ServerState
    let log: @Sendable (String) -> Void

    func willWriteIndex(at url: URL) async {}

    func didWriteVolume(_ volumeId: String, at url: URL) async {}

    func didFinishWritingIndex(at url: URL) async {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let index = try await Blocking.run { try CorpusIndex.open(url) }
            await state.indexWritten(index)
        } catch let refusal as ImportRefusal {
            log("The index the library's indexing wrote cannot be served: \(refusal.reason)")
        } catch {
            log("The index the library's indexing wrote could not be opened: \(error)")
        }
    }
}

/// Several observers of an import, told in order.
struct ImportObservers: ImportObserver {
    let observers: [any ImportObserver]

    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) async {
        for observer in observers { await observer.importDidReach(step, detail: detail, progress: progress) }
    }
}

/// An export installed as a Standalone server's index (PLAN's S21c's seed): the stamps and the records of
/// the index it replaced, which describe another file, are forgotten.
struct IndexerAfterIndexImport: ImportObserver {
    let indexer: LibraryIndexer

    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) async {
        // The import's last step, reached once the new index is installed.
        guard step == .openingIndex else { return }
        await indexer.indexWasReplaced()
    }
}
