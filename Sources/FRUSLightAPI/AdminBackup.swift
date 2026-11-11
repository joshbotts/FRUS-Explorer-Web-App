// GET /api/v1/admin/backup (PLAN's S14b): the newest of the user store's daily backups with a
// manifest of versions, as one tar archive, `BackupArchiveSource`'s. The store holds every user's
// data, so the route is an admin's, by the role check the server makes for an instance's data, and
// it passes the guard /api/v1/me passes: it is sent to the server's own address, and refused while
// FRUS_USER_DATA is off, as a user's data is. A server with a PostgreSQL store (S14d) has none: that
// store's backups are its database service's, and a backup of an app.db left in the volume is not it.
// Since PLAN's S20d every route under /api/v1/admin needs the admin role, which the group's own guard
// checks after /api/v1/me's, before any route reads a body; the routes are registered here, one line
// a part, beside their kin.

import FRUSLightCore
import Foundation
import Hummingbird
import NIOCore

/// The admin role, for every route under /api/v1/admin (PLAN's S20d): checked once the user is
/// resolved and a change has passed /api/v1/me's checks, before the route runs, so that no route
/// answers anyone else, whether or not it checks the role itself.
struct AdminRoleGuard: RouterMiddleware {
    typealias Context = APIRequestContext

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        try context.requireUser().require(.admin)
        return try await next(request, context)
    }
}

enum AdminRoutes {
    static func add(to router: Router<APIRequestContext>, services: UserDataServices, state: ServerState, resources: ServerResources,
                    library: VolumeLibrary? = nil, indexer: LibraryIndexer? = nil) {
        let admin = router.group("/api/v1/admin").add(middleware: UserDataGuard(services: services)).add(middleware: AdminRoleGuard())
        let (directory, copyDirectory) = (services.backupsDirectory, services.backupCopyDirectory)
        // The instance's stored keys (PLAN's S20c), an admin's too.
        SecretRoutes.addInstance(to: admin, services: services)
        // Status, the backups' list and the index's reset; the jobs; the users and an erasure (S20d).
        AdminStatusRoutes.add(to: admin, services: services, state: state, resources: resources)
        AdminJobRoutes.add(to: admin, services: services)
        // The library's volumes, their downloads (S21c) and their indexing (S21d).
        AdminLibraryRoutes.add(to: admin, state: state, resources: resources, library: library, indexer: indexer)
        AdminUserRoutes.add(to: admin, services: services)

        admin.get("backup") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            try context.requireUser().require(.admin)
            guard let directory else {
                throw APIProblem(.notFound, code: "BACKUP_NOT_FOUND",
                                 detail: "The user store is a PostgreSQL database, which the server does not back up: its backups are its database service's.")
            }
            // Hashed off the cooperative pool, as it reads the whole backup.
            guard let source = try await Blocking.run({ try BackupArchiveSource.newest(in: directory, copyDirectory: copyDirectory) })
            else {
                throw APIProblem(.notFound, code: "BACKUP_NOT_FOUND",
                                 detail: "No backup of the user store has been taken yet: the server takes the first soon after it starts, and frus-light backup takes one now.")
            }
            var headers = HTTPFields()
            headers[.contentType] = "application/x-tar"
            headers[.contentDisposition] = "attachment; filename=\"\(source.fileName)\""
            headers[.cacheControl] = "no-store"
            let body = ResponseBody(contentLength: Int(source.length)) { writer in
                try await source.write { try await writer.write(ByteBuffer(bytes: $0)) }
                try await writer.finish(nil)
            }
            return Response(status: .ok, headers: headers, body: body)
        }
    }
}
