// POST /api/v1/me/import and GET /api/v1/me/import/{id} (PLAN's S16c): a Mac JSON export, sent as the
// request's body, imported into the user's store as a job, and its report. The file's format version
// is read at once, so a file that is not an export, or of a version the server does not read, is
// refused before it waits; the rest, its decoding with the kit's envelope and its rows, is the job's.
// A user has one import at a time. What each job did is kept while the server runs.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import NIOCore

/// An import of a Mac JSON export, and where it is.
public struct ImportStatus: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: Int
    /// `queued` behind another job, `running`, `succeeded` with its report, or `failed` with why.
    public var state: JobRecord.State
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
    private var imports: [Int: (user: String, status: ImportStatus)] = [:]
    private var nextID = 1
    /// How many finished imports are kept, the oldest forgotten first.
    private let kept = 50

    /// A new import of `user`'s, queued; nil while another of theirs is queued or running.
    func begin(for user: String, formatVersion: Int) -> ImportStatus? {
        guard !imports.values.contains(where: { $0.user == user && [.queued, .running].contains($0.status.state) }) else {
            return nil
        }
        let status = ImportStatus(id: nextID, state: .queued, formatVersion: formatVersion, report: nil, problem: nil)
        imports[nextID] = (user, status)
        nextID += 1
        let finished = imports.filter { [.succeeded, .failed].contains($0.value.status.state) }.keys.sorted()
        for id in finished.dropLast(kept) { imports[id] = nil }
        return status
    }

    func run(_ id: Int) { imports[id]?.status.state = .running }

    func succeed(_ id: Int, with report: ResearchImportReport) {
        imports[id]?.status.state = .succeeded
        imports[id]?.status.report = report
    }

    func fail(_ id: Int, with problem: ImportProblem) {
        imports[id]?.status.state = .failed
        imports[id]?.status.problem = problem
    }

    /// The import, if it is the user's.
    func status(_ id: Int, of user: String) -> ImportStatus? {
        guard let entry = imports[id], entry.user == user else { return nil }
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
            let version: Int
            do {
                version = try MacImport.formatVersion(of: data)
            } catch let error as MacImportError {
                throw error.problem
            }
            guard let status = await imports.begin(for: user.id, formatVersion: version) else {
                throw APIProblem(.conflict, code: "IMPORT_IN_PROGRESS",
                                 detail: "An import of yours is under way: its report comes before another can start.")
            }
            // An instance's corrections change the index every user shares: a curator imports them.
            let curator = user.roles.contains(.curator)
            _ = await jobs.submit("import of a Mac JSON export for \(user.id)") {
                await imports.run(status.id)
                do {
                    let report = try await Blocking.run {
                        try MacImport.run(try MacImport.envelope(of: data), into: store, for: user.id, includingInstanceWide: curator)
                    }
                    await imports.succeed(status.id, with: report)
                } catch {
                    await imports.fail(status.id, with: problem(error))
                    throw error
                }
            }
            let location = context.basePath.prefixing("/api/v1/me/import/\(status.id)")
            return EditedResponse(status: .accepted, headers: [.location: location, .cacheControl: "no-store"], response: status)
        }

        me.get("import/:importId") { request, context -> EditedResponse<ImportStatus> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("importId")
            guard let number = Int(id), let status = await imports.status(number, of: user.id) else {
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

    /// A failed job's problem, as an answer would give it.
    static func problem(_ error: any Error) -> ImportProblem {
        let problem = (error as? MacImportError)?.problem
            ?? APIProblem(.internalServerError, code: "IMPORT_FAILED",
                          detail: "The import could not be written, and nothing of it was kept: \(error)")
        return ImportProblem(code: problem.code, detail: problem.detail)
    }
}
