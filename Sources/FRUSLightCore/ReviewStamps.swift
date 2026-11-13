// The index's own record of a review (PLAN's S21f): on a Standalone server, the reviews users have marked are
// recorded in its index's `document_revisions.reviewed_at` too, as the app's device stamps its own index when its
// reader marks a document reviewed and when its ledger brings a review from another device (the kit's
// `applyAnnotationReviews`, which stamps a change only where the ledger's row holds its content hash and change
// kind). Each user's review is their ledger's row, which Changed by an update, the banner and the review sheet
// read; the index's stamp says that every user whose research is on the document has reviewed the change, which
// Administration's After an Update counts and a copy of the index carries. Not before: the kit keeps a change of
// the text marked so through a later change of the notes alone only while it is unreviewed, and one user's review
// must not tell another that the text did not change. It is a job of the queue, the index's one writer, which reads
// the ledgers when it runs, so that a review whose job a stop of the server lost is recorded by the next.

import FRUSCoreKit
import Foundation

extension LibraryIndexer {
    /// Queues the job that records every user's reviews in the index, or gives the one that waits already, which
    /// reads the ledgers when it runs. `ledgers` reads them. Throws `LibraryIndexingRefusal.importMode` on an
    /// Import server, whose index the server never writes, or what the queue throws.
    @discardableResult
    public func recordReviews(requestedBy: String?, ledgers: @escaping @Sendable () async throws -> [AnnotationReviewData]) async throws -> Job {
        guard mode == .standalone else { throw LibraryIndexingRefusal.importMode }
        if let id = waitingReviewJob, let job = await jobs.job(id), job.state == .queued, waitingReviewJob == id { return job }
        let id = UUID().uuidString
        waitingReviewJob = id
        do {
            return try await jobs.submit(.indexReviews, subject: nil, requestedBy: requestedBy, id: id, onCancel: {
                await self.forgetReviewJob(id)
            }) { job in
                try await self.runReviews(id, job: job, ledgers: ledgers)
            }
        } catch {
            forgetReviewJob(id)
            throw error
        }
    }

    func forgetReviewJob(_ id: String) {
        if waitingReviewJob == id { waitingReviewJob = nil }
    }

    private func runReviews(_ id: String, job: JobContext, ledgers: @Sendable () async throws -> [AnnotationReviewData]) async throws -> String? {
        forgetReviewJob(id)
        try await job.step("Recording the reviews users have marked in the index", fraction: 0)
        guard FileManager.default.fileExists(atPath: liveIndex.path) else {
            throw JobFailed("No index is served, so no review was recorded in it.")
        }
        let rows = try await ledgers()
        guard !rows.isEmpty else { return "No review was waiting to be recorded in the index." }
        let stamped = try await withWriter(holding: nil) { writer in try await writer.pipeline.applyAnnotationReviews(rows) }
        return stamped == 1 ? "Recorded 1 review in the index." : "Recorded \(stamped) reviews in the index."
    }
}
