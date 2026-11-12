// The served index while the library's jobs write it (PLAN's S21d, S21e), and what an import that seeds a
// Standalone server's index tells the indexer.

import FRUSCoreKit
import FRUSLightCore
import Foundation

/// The served index as the library's jobs write it. A Standalone server serves its own index through the
/// kit's live read-only opens (PLAN's S21e): its indexing writes the file while search reads it, and after
/// each volume the index is opened again and served, so that the counts, the stack and its caches follow
/// each volume as its store commits. A job that holds the file to itself, a compaction or a reset while it
/// empties the index, says why: from before its first write until it has closed the file nothing reads the
/// index, search answers 503 with the sentence, `/readyz` says so, and the reader renders from the volumes'
/// files, as S21d's indexing did while the served stack's connections were immutable.
struct ServedIndexWriting: IndexWritingObserver {
    let state: ServerState
    let provider: ServedIndexProvider?
    let log: @Sendable (String) -> Void

    func willWriteIndex(at url: URL, holding reason: String?) async {
        guard let reason else { return }
        await state.beginIndexWrite(reason)
        if let provider, await !provider.letGoOfStacks() {
            log("A request still reads the index a job of the library's is about to hold to itself, after five minutes: the job goes on")
        }
    }

    func didWriteVolume(_ volumeId: String, at url: URL) async {
        _ = await reopen(url, quietly: true)
    }

    func didFinishWritingIndex(at url: URL) async {
        guard FileManager.default.fileExists(atPath: url.path), await reopen(url, quietly: false) else {
            await state.endIndexWrite()
            return
        }
    }

    /// Opens the index again over the file as it is now, live, and serves it; gives whether it could. One
    /// that cannot be opened leaves the index served before it, whose connection reads the file too.
    private func reopen(_ url: URL, quietly: Bool) async -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            let index = try await Blocking.run { try CorpusIndex.open(url, live: true) }
            await state.indexWritten(index, quietly: quietly)
            return true
        } catch let refusal as ImportRefusal {
            log("The index the library's job wrote cannot be served: \(refusal.reason)")
        } catch {
            log("The index the library's job wrote could not be opened: \(error)")
        }
        return false
    }
}

/// Several observers of an import, told in order.
struct ImportObservers: ImportObserver {
    let observers: [any ImportObserver]

    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) async {
        for observer in observers { await observer.importDidReach(step, detail: detail, progress: progress) }
    }
}

/// An export installed as a Standalone server's index (PLAN's S21c's seed): before it takes the index's place,
/// the log of the index it replaces is folded into that file (PLAN's S21e), so that no commit of it waits in a
/// log beside the name a live read-only open reads the new file by; and once it has, the stamps and the
/// records of the index it replaced, which describe another file, are forgotten.
struct IndexerAfterIndexImport: ImportObserver {
    let indexer: LibraryIndexer

    func importDidReach(_ step: ReadinessStep, detail: String, progress: Double?) async {
        switch step {
        case .installingIndex: await indexer.indexWillBeReplaced()
        // The import's last step, reached once the new index is installed.
        case .openingIndex: await indexer.indexWasReplaced()
        default: break
        }
    }
}
