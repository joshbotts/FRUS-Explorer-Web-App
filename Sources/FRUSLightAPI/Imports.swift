// POST /api/v1/me/import and GET /api/v1/me/import/{id} (PLAN's S16c): a Mac JSON export, sent as the
// request's body, imported into the user's store as a job, and its report. The file's format version
// is read at once, so a file that is not an export, or of a version the server does not read, is
// refused before it waits; the rest, its decoding with the kit's envelope and its rows, is the job's.
// A user has one import at a time. What each job did is kept while the server runs, under an id of
// its own, so that after a restart an old id names no import rather than another.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import NIOCore

/// An import of a Mac JSON export, and where it is.
public struct ImportStatus: Codable, Equatable, Sendable, ResponseEncodable {
    /// A UUID, new for each import.
    public var id: String
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
    private var imports: [String: (user: String, status: ImportStatus)] = [:]
    /// The ids in the order the imports began.
    private var order: [String] = []
    /// How many finished imports are kept, the oldest forgotten first.
    private let kept = 50

    /// A new import of `user`'s, queued; nil while another of theirs is queued or running.
    func begin(for user: String, formatVersion: Int) -> ImportStatus? {
        guard !imports.values.contains(where: { $0.user == user && [.queued, .running].contains($0.status.state) }) else {
            return nil
        }
        let status = ImportStatus(id: UUID().uuidString, state: .queued, formatVersion: formatVersion, report: nil, problem: nil)
        imports[status.id] = (user, status)
        order.append(status.id)
        let finished = order.filter { [.succeeded, .failed].contains(imports[$0]?.status.state) }
        for id in finished.dropLast(kept) { imports[id] = nil }
        order.removeAll { imports[$0] == nil }
        return status
    }

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
            _ = await jobs.submit("import of a Mac JSON export for \(user.id)") {
                await imports.run(status.id)
                do {
                    let report = try await Blocking.run {
                        try MacImport.run(try MacImport.envelope(of: data, formatVersion: version), into: store, for: user.id,
                                          includingInstanceWide: curator)
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

    /// A failed job's problem, as an answer would give it.
    static func problem(_ error: any Error) -> ImportProblem {
        let problem = (error as? MacImportError)?.problem
            ?? APIProblem(.internalServerError, code: "IMPORT_FAILED",
                          detail: "The import could not be written, and nothing of it was kept: \(error)")
        return ImportProblem(code: problem.code, detail: problem.detail)
    }
}
