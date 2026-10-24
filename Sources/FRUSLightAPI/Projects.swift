// /api/v1/me/projects (PLAN's S15d): the user's projects, read only, by name, for a note's Projects
// and All Notes' Project filter. Only an import writes them until S17f, which extends this.

import FRUSLightCore
import Foundation
import Hummingbird

/// One of the user's projects, as far as a note names it.
public struct Project: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var name: String

    init(_ record: ProjectRecord) {
        id = NoteRoutes.wire(record.id)
        name = record.name
    }
}

/// The user's projects, by name.
public struct ProjectList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [Project]
}

enum ProjectRoutes {
    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices) {
        let store = services.store
        me.get("projects") { request, context -> ProjectList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let projects = try await Blocking.run { try store.projects(for: user.id) }
            return ProjectList(total: projects.count, items: projects.map(Project.init))
        }
    }
}
