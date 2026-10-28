// GET /api/v1/admin/backup (PLAN's S14b): the newest of the user store's daily backups with a
// manifest of versions, as one tar archive, `BackupArchiveSource`'s. The store holds every user's
// data, so the route is an admin's, by the role check the server makes for an instance's data, and
// it passes the guard /api/v1/me passes: it is sent to the server's own address, and refused while
// FRUS_USER_DATA is off, as a user's data is. A server with a PostgreSQL store (S14d) has none: that
// store's backups are its database service's, and a backup of an app.db left in the volume is not it.

import FRUSLightCore
import Foundation
import Hummingbird
import NIOCore

enum AdminRoutes {
    static func add(to router: Router<APIRequestContext>, services: UserDataServices) {
        let admin = router.group("/api/v1/admin").add(middleware: UserDataGuard(services: services))
        let (directory, copyDirectory) = (services.backupsDirectory, services.backupCopyDirectory)

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
