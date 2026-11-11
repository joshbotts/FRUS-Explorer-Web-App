// The served index while the library's indexing writes it (PLAN's S21d), and what an import that seeds a
// Standalone server's index tells the indexer.

import FRUSCoreKit
import FRUSLightCore
import Foundation

/// The served index as the library's indexing writes it, by the owner's choice of 11 November (PLAN's
/// S21d): the served stack's connections are immutable, which cannot read a file being written, so from
/// before a job's first write until it has closed the index nothing reads it. Search answers 503 meanwhile,
/// naming the indexing, `/readyz` says so, and the reader renders from the volumes' files; then the index
/// is opened again and served, with what it holds now, and the stack's computations over the index before
/// it go with that stack. A follow-up, once a pin move brings the kit's read-only opens without
/// `immutable`, serves the index while it is written.
struct ServedIndexWriting: IndexWritingObserver {
    let state: ServerState
    let provider: ServedIndexProvider?
    let log: @Sendable (String) -> Void

    func willWriteIndex(at url: URL) async {
        await state.beginIndexWrite()
        if let provider, await !provider.letGoOfStacks() {
            log("A request still reads the index the library's indexing is about to write, after five minutes: the indexing goes on")
        }
    }

    func didWriteVolume(_ volumeId: String, at url: URL) async {}

    func didFinishWritingIndex(at url: URL) async {
        guard FileManager.default.fileExists(atPath: url.path) else {
            await state.endIndexWrite()
            return
        }
        do {
            let index = try await Blocking.run { try CorpusIndex.open(url) }
            await state.indexWritten(index)
        } catch let refusal as ImportRefusal {
            await state.endIndexWrite()
            log("The index the library's indexing wrote cannot be served: \(refusal.reason)")
        } catch {
            await state.endIndexWrite()
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
