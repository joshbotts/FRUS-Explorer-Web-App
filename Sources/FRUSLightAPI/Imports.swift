// POST /api/v1/me/import and GET /api/v1/me/import/{id} (PLAN's S16c): a Mac JSON export, sent as the
// request's body, imported into the user's store as a job, and its report. The file's format version
// is read at once, so a file that is not an export, or of a version the server does not read, is
// refused before it waits; the rest, its decoding with the kit's envelope and its rows, is the job's.
// A user has one import at a time. What each job did is kept while the server runs, under an id of
// its own, so that after a restart an old id names no import rather than another. Since S20d the job
// is a row of the server's queue too, under the same id, in two steps, the file's reading and its
// writing, between which an admin may stop it; the row keeps the server's own sentences, never what
// the file holds, and outlives a restart, while the report stays the user's, and the process's.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import NIOCore

/// An import of a Mac JSON export, and where it is.
public struct ImportStatus: Codable, Equatable, Sendable, ResponseEncodable {
    /// A UUID, new for each import.
    public var id: String
    /// `queued` behind another job, `running`, `succeeded` with its report, or `failed` with why, as
    /// when an admin stopped it (`IMPORT_CANCELLED`).
    public var state: State

    public enum State: String, Codable, Equatable, Sendable { case queued, running, succeeded, failed }
    /// The file's `formatVersion`, which was read before the job was queued.
    public var formatVersion: Int
    public var report: ResearchImportReport?
    /// Why the import failed, as a problem's `code` and `detail`.
    public var problem: ImportProblem?

    /// Each field, a report and a problem with none as null.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(state, forKey: .state)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(report, forKey: .report)
        try container.encode(problem, forKey: .problem)
    }
}

/// Why an import failed.
public struct ImportProblem: Codable, Equatable, Sendable {
    public var code: String
    public var detail: String
}

/// Each import's status while the server runs, by its id, each the user's who made it.
actor ResearchImports {
    private var imports: [String: (user: String, status: ImportStatus)] = [:]
    /// The ids in the order the imports began.
    private var order: [String] = []
    /// How many finished imports are kept, the oldest forgotten first.
    private let kept = 50
    /// The users whose research an admin is erasing (PLAN's S20d), whom no import begins for meanwhile.
    private var erasing: Set<String> = []

    /// A new import of `user`'s, queued; nil while another of theirs is queued or running, or while an
    /// admin erases their research.
    func begin(for user: String, formatVersion: Int) -> ImportStatus? {
        guard !erasing.contains(user), !isImporting(user) else { return nil }
        let status = ImportStatus(id: UUID().uuidString, state: .queued, formatVersion: formatVersion, report: nil, problem: nil)
        imports[status.id] = (user, status)
        order.append(status.id)
        let finished = order.filter { [.succeeded, .failed].contains(imports[$0]?.status.state) }
        for id in finished.dropLast(kept) { imports[id] = nil }
        order.removeAll { imports[$0] == nil }
        return status
    }

    private func isImporting(_ user: String) -> Bool {
        imports.values.contains { $0.user == user && [.queued, .running].contains($0.status.state) }
    }

    /// Holds off `user`'s imports while an admin erases their research: false, holding nothing, while an
    /// import of theirs is queued or running, or another erasure of theirs is under way.
    func beginErasure(of user: String) -> Bool {
        guard !erasing.contains(user), !isImporting(user) else { return false }
        erasing.insert(user)
        return true
    }

    func endErasure(of user: String) { erasing.remove(user) }

    func run(_ id: String) { imports[id]?.status.state = .running }

    func succeed(_ id: String, with report: ResearchImportReport) {
        imports[id]?.status.state = .succeeded
        imports[id]?.status.report = report
    }

    func fail(_ id: String, with problem: ImportProblem) {
        imports[id]?.status.state = .failed
        imports[id]?.status.problem = problem
    }

    /// The import, if it is the user's; an id in any case names it.
    func status(_ id: String, of user: String) -> ImportStatus? {
        guard let entry = imports[TagReferences.normalized(id) ?? id], entry.user == user else { return nil }
        return entry.status
    }
}

enum ImportRoutes {
    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices) {
        let store = services.store
        let imports = services.imports
        let jobs = services.jobs
        let limit = services.importLimit

        me.post("import") { request, context -> EditedResponse<ImportStatus> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let data = try await body(of: request, limit: limit)
            // Read off the cooperative pool, as the parse reads the whole file.
            let version: Int
            do {
                version = try await Blocking.run { try MacImport.formatVersion(of: data) }
            } catch let error as MacImportError {
                throw error.problem
            }
            guard let status = await imports.begin(for: user.id, formatVersion: version) else {
                throw APIProblem(.conflict, code: "IMPORT_IN_PROGRESS",
                                 detail: "An import of yours is under way: its report comes before another can start.")
            }
            // An instance's corrections change the index every user shares: a curator imports them.
            let curator = user.roles.contains(.curator)
            do {
                _ = try await jobs.submit(.researchImport, subject: "A Mac JSON export, format \(version)", requestedBy: user.id,
                                          id: status.id, onCancel: {
                    await imports.fail(status.id, with: ImportProblem(code: "IMPORT_CANCELLED", detail: cancelledDetail))
                }) { job in
                    await imports.run(status.id)
                    do {
                        try await job.step("Reading the export")
                        let envelope = try await Blocking.run { try MacImport.envelope(of: data, formatVersion: version) }
                        // One transaction writes it all, so from here it runs to its end.
                        try await job.commit()
                        await job.progress("Writing its records into \(user.id)'s research")
                        let report = try await Blocking.run {
                            try MacImport.run(envelope, into: store, for: user.id, includingInstanceWide: curator)
                        }
                        await imports.succeed(status.id, with: report)
                        return jobLine(report, for: user.id)
                    } catch is JobCancelled {
                        await imports.fail(status.id, with: ImportProblem(code: "IMPORT_CANCELLED", detail: cancelledDetail))
                        throw JobCancelled()
                    } catch {
                        await imports.fail(status.id, with: problem(error))
                        throw JobFailed(jobMessage(error))
                    }
                }
            } catch {
                await imports.fail(status.id, with: problem(error))
                throw APIProblem(.serviceUnavailable, code: "IMPORT_NOT_QUEUED",
                                 detail: "The import could not be queued, since the server could not keep its job: try again in a moment.")
            }
            let location = context.basePath.prefixing("/api/v1/me/import/\(status.id)")
            return EditedResponse(status: .accepted, headers: [.location: location, .cacheControl: "no-store"], response: status)
        }

        me.get("import/:importId") { request, context -> EditedResponse<ImportStatus> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("importId")
            guard let status = await imports.status(id, of: user.id) else {
                throw APIProblem(.notFound, code: "IMPORT_NOT_FOUND", detail: "You have no import with the id \(id).")
            }
            return EditedResponse(headers: [.cacheControl: "no-store"], response: status)
        }
    }

    /// The request's body, the export, of `limit` bytes at most.
    private static func body(of request: Request, limit: Int) async throws -> Data {
        do {
            return Data(buffer: try await request.body.collect(upTo: limit))
        } catch is NIOTooManyBytesError {
            throw JSONBody.tooLarge(limit)
        } catch let error as HTTPError where error.status == .contentTooLarge {
            throw JSONBody.tooLarge(limit)
        }
    }

    /// What the user's status says of an import an admin stopped.
    static let cancelledDetail = "An admin stopped this import before it wrote anything, and nothing of it was kept. Import the file again to bring it in."

    /// The line a finished import's job ends with, in the admin's Jobs list: how many records came in
    /// and how many replaced an older copy, which says nothing of what they hold.
    static func jobLine(_ report: ResearchImportReport, for user: String) -> String {
        let added = report.types.reduce(0) { $0 + $1.added }
        let replaced = report.types.reduce(0) { $0 + $1.replaced }
        func records(_ count: Int) -> String { count == 1 ? "1 record" : "\(count) records" }
        return "Imported into \(user)'s research: \(records(added)) came in, and \(records(replaced)) replaced an older copy"
    }

    /// The `error` a failed import's job keeps: the problem's code and the server's sentence for it,
    /// never a decoder's or the store's words, which may quote what the file holds.
    static func jobMessage(_ error: any Error) -> String {
        switch error {
        case MacImportError.unsupportedVersion(let version):
            "UNSUPPORTED_FORMAT_VERSION: the export is format version \(version), which this server does not read."
        case is MacImportError:
            "INVALID_EXPORT: the export's records could not be read, and nothing of it was kept."
        default:
            "IMPORT_FAILED: the import could not be written, and nothing of it was kept."
        }
    }

    /// A failed job's problem, as an answer would give it.
    static func problem(_ error: any Error) -> ImportProblem {
        let problem = (error as? MacImportError)?.problem
            ?? APIProblem(.internalServerError, code: "IMPORT_FAILED",
                          detail: "The import could not be written, and nothing of it was kept: \(error)")
        return ImportProblem(code: problem.code, detail: problem.detail)
    }
}
