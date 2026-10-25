// GET /api/v1/me/export and GET /api/v1/me/export/contents (PLAN's S16d): Export as JSON, the user's
// research as the Mac's Settings ▸ Data & Recovery writes it, the kit's envelope with the web's one
// key more (`ResearchExport`), saved as the file the app's export sheet names; and what such a file
// would carry, type by type, for the browser app's Contents, as the sheet counts it. Include
// AI-Generated Summaries is the app's switch, off unless asked, and the project an export is made
// under heads it, as the Mac's active project does. A curator's export carries the instance's two
// corrections, as only a curator's import takes them.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// What an export of the user's would carry, for the browser app's Contents.
public struct ExportContents: Codable, Equatable, Sendable, ResponseEncodable {
    /// The format version an export writes, the kit's.
    public var formatVersion: Int
    /// Each of the 23 model types, in the user store's order, with how many of its records an export
    /// carries: the summaries as with Include AI-Generated Summaries on.
    public var types: [ExportTypeCount]
}

/// How many records of one model type an export carries.
public struct ExportTypeCount: Codable, Equatable, Sendable {
    /// The app's model type, such as `ResearchNote`.
    public var type: String
    public var count: Int
}

enum ExportRoutes {
    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices) {
        let store = services.store
        let now = services.now

        me.get("export") { request, context -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["includeGeneratedSummaries", "projectId"])
            let user = try context.requireUser()
            let summaries = try query.bool("includeGeneratedSummaries") ?? false
            var project: UUID?
            if let text = try query.single("projectId") {
                guard let id = UUID(uuidString: text) else { throw APIProblem.invalidParameter("projectId", "\(text) is not a UUID.") }
                project = id
            }
            let options = ResearchExport.Options(includeGeneratedSummaries: summaries,
                                                 includingInstanceWide: user.roles.contains(.curator), projectId: project,
                                                 exportedAt: now())
            // Read and written off the cooperative pool, as it reads every row the user holds.
            let file: Data
            do {
                file = try await Blocking.run { try ResearchExport.file(from: store, for: user.id, options) }
            } catch let error as ResearchExportError {
                throw error.problem
            }
            var headers = HTTPFields()
            headers[.contentType] = "application/json"
            headers[.contentDisposition] = "attachment; filename=\"\(ResearchExport.fileName)\""
            headers[.cacheControl] = "no-store"
            return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(bytes: file)))
        }

        me.get("export/contents") { request, context -> EditedResponse<ExportContents> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let tables = ResearchExport.tables(.init(includeGeneratedSummaries: true,
                                                     includingInstanceWide: user.roles.contains(.curator), exportedAt: now()))
            let counts = try await Blocking.run { try store.researchCounts(for: user.id, tables: tables) }
            let contents = ExportContents(formatVersion: ResearchDataEnvelope.currentFormatVersion,
                                          types: MacImport.types.map { ExportTypeCount(type: $0.model, count: counts[$0.table] ?? 0) })
            return EditedResponse(headers: [.cacheControl: "no-store"], response: contents)
        }
    }
}
