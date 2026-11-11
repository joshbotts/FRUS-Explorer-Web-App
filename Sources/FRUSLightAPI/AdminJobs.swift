// /api/v1/admin/jobs (PLAN's S20d): the server's jobs, as its queue holds them, each one queued or
// running and the newest it finished, and a cancel: a job waiting leaves the line at once, and one
// running stops at its next step; one past the point where it can stop runs to its end. The list is the
// queue's, so it answers while an import holds the store; the store keeps each job as it goes, so the
// list outlives a restart. An admin's, behind `AdminRoutes`' guard.
//   GET  /api/v1/admin/jobs               every job the queue holds, newest first
//   GET  /api/v1/admin/jobs/{id}          one
//   POST /api/v1/admin/jobs/{id}/cancel   stops it

import FRUSLightCore
import Foundation
import Hummingbird

/// One job, as the admin's Jobs list shows it.
public struct AdminJob: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    /// What it does: `indexImport`, `researchImport` or `indexReset`, and from S21c and S21d theirs.
    public var kind: String
    /// What it works on, in the server's words, such as an export's file name.
    public var subject: String?
    /// `queued`, `running`, `succeeded`, `failed` or `cancelled`.
    public var state: String
    /// A line of what it does now, or of what it did once it has finished.
    public var progress: String?
    /// How far through it is, 0 to 1, where it can tell.
    public var fraction: Double?
    /// The user who asked for it; absent for the server itself.
    public var requestedBy: String?
    public var queuedAt: String
    public var startedAt: String?
    public var finishedAt: String?
    /// Why it failed, in the server's words.
    public var error: String?
    /// Whether a cancel is taken now.
    public var cancellable: Bool
    public var cancelRequestedBy: String?
    public var cancelRequestedAt: String?

    init(_ job: Job) {
        id = job.id
        kind = job.kind.rawValue
        subject = job.subject
        state = job.state.rawValue
        progress = job.progress
        fraction = job.fraction
        requestedBy = job.requestedBy
        queuedAt = UserStoreDate.text(job.queuedAt)
        startedAt = job.startedAt.map(UserStoreDate.text)
        finishedAt = job.finishedAt.map(UserStoreDate.text)
        error = job.error
        cancellable = job.cancellable
        cancelRequestedBy = job.cancelRequestedBy
        cancelRequestedAt = job.cancelRequestedAt.map(UserStoreDate.text)
    }
}

/// `GET /api/v1/admin/jobs`.
public struct AdminJobList: Codable, Equatable, Sendable, ResponseEncodable {
    public var jobs: [AdminJob]
}

enum AdminJobRoutes {
    static func add(to admin: RouterGroup<APIRequestContext>, services: UserDataServices) {
        let jobs = services.jobs

        admin.get("jobs") { request, _ -> EditedResponse<AdminJobList> in
            try FormQuery(request.uri.query).refuseUnknown([])
            return EditedResponse(headers: [.cacheControl: "no-store"], response: AdminJobList(jobs: await jobs.jobs().map(AdminJob.init)))
        }

        admin.get("jobs/:jobId") { request, context -> EditedResponse<AdminJob> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let id = try jobID(context)
            guard let job = await jobs.job(id) else { throw notFound(id) }
            return EditedResponse(headers: [.cacheControl: "no-store"], response: AdminJob(job))
        }

        // 200 with the job cancelled, for one that waited; 202 with the job still running, for one that
        // stops at its next step.
        admin.post("jobs/:jobId/cancel") { request, context -> EditedResponse<AdminJob> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try jobID(context)
            do {
                let job = try await jobs.cancel(id, by: user.id)
                return EditedResponse(status: job.state == .cancelled ? .ok : .accepted, headers: [.cacheControl: "no-store"],
                                      response: AdminJob(job))
            } catch let refusal as JobCancelRefusal {
                switch refusal {
                case .notFound:
                    throw notFound(id)
                case .finished(let state):
                    throw APIProblem(.conflict, code: "JOB_FINISHED", detail: "That job has \(finished(state)) already.")
                case .committed(let job):
                    throw APIProblem(.conflict, code: "JOB_NOT_CANCELLABLE",
                                     detail: "That job is past the point where it can stop, and runs to its end\(job.progress.map { ": \($0)" } ?? "").")
                }
            }
        }
    }

    /// The job a route names: its id in any letter case.
    private static func jobID(_ context: APIRequestContext) throws -> String {
        let given = try context.parameters.require("jobId")
        return TagReferences.normalized(given) ?? given
    }

    private static func notFound(_ id: String) -> APIProblem {
        APIProblem(.notFound, code: "JOB_NOT_FOUND", detail: "The server holds no job with the id \(id).")
    }

    private static func finished(_ state: Job.State) -> String {
        switch state {
        case .succeeded: "finished"
        case .failed: "failed"
        case .cancelled: "been cancelled"
        case .queued, .running: "ended"
        }
    }
}
