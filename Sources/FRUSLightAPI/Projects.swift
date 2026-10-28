// /api/v1/me/projects (PLAN's S15d and S17f): the user's projects, by name, for a note's Projects and
// All Notes' Project filter (S15d), and since S17f each project whole, as the Mac's `Project` holds
// it; New Project, the editor's Save and Delete Project, as `ProjectEditorView` and
// `ProjectAdminService` make and change them; Merge into…; the project each user works in, the web's
// own, which the Mac keeps on each device (`AppState.activeProjectId`); and Project Home
// (`ProjectHome.swift`), with Suggested Next's Dismiss. A project is written as the import writes a
// Mac's record (`MacImport.project`) and read as the export reads one (`ResearchExport.project`).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// One of the user's projects, as the Mac's `Project` holds it.
public struct Project: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var name: String
    /// The editor's and Project Home's research question; absent for none.
    public var researchQuestion: String?
    /// The date focus Project Home's header shows, the first and last days of its range, as the store
    /// keeps a time; absent for an end with none. Only an import sets them, as only the Mac's earlier
    /// builds set them.
    public var defaultDateRangeStart: String?
    public var defaultDateRangeEnd: String?
    /// Its focus subjects, the refs of the bundled subject profiles' vocabulary, as an import brings
    /// them (`defaultSubjectTagIds`, which #377 reuses for them).
    public var defaultSubjectTagIds: [String]
    /// Its focus tags, the ids of the user's tags whose documents anchor its Suggested Next.
    public var defaultUserTagIds: [String]
    public var createdAt: String?
    public var lastModified: String?
    /// In the list alone, what is filed under it, as Settings ▸ Projects' rows say it, the kit's
    /// `ResearchItemCounts.ProjectTally.summary`: "12 notes · 3 collections", or "Nothing filed yet".
    public var tally: String?

    init(_ record: ProjectRecord) {
        id = NoteRoutes.wire(record.id)
        name = record.name
        defaultSubjectTagIds = []
        defaultUserTagIds = []
    }

    init(_ project: ProjectExport) {
        id = project.id.uuidString
        name = project.name
        researchQuestion = project.researchQuestion
        defaultDateRangeStart = project.defaultDateRangeStart.map(UserStoreDate.text)
        defaultDateRangeEnd = project.defaultDateRangeEnd.map(UserStoreDate.text)
        defaultSubjectTagIds = project.defaultSubjectTagIds
        defaultUserTagIds = (project.defaultUserTagIds ?? []).map(\.uuidString)
        createdAt = project.createdAt.map(UserStoreDate.text)
        lastModified = project.lastModified.map(UserStoreDate.text)
    }
}

/// The user's projects, by name, and the one they work in.
public struct ProjectList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [Project]
    /// The project the user works in; absent for the Mac's Global Context.
    public var activeProjectId: String?
}

/// The project the user works in, the web's own: absent for Global Context.
public struct ActiveProject: Codable, Equatable, Sendable, ResponseEncodable {
    public var projectId: String?
}

enum ProjectRoutes {
    struct New: Decodable {
        let name: String
        let researchQuestion: String?
    }

    /// The editor's fields and Project Home's, each changed only when given: the name and the research
    /// question as the editor's Save writes them, and the focus tags as `ProjectFocusTagsEditor` sets
    /// them.
    struct Change: Decodable {
        let name: String?
        let researchQuestion: String?
        let defaultUserTagIds: [String]?
    }

    struct Merge: Decodable { let into: String }

    struct Active: Decodable { let projectId: String? }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources) {
        let store = services.store
        let now = services.now

        me.get("projects") { request, context -> ProjectList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let (projects, active, rows) = try await Blocking.run {
                (try store.projects(for: user.id), try store.activeProjectId(of: user.id),
                 try store.researchRows(for: user.id, tables: ["notes", "collections"]))
            }
            let held = try await wholeProjects(of: user.id, in: store)
            // What is filed under each, counted by the kit as the app's pane counts it, one copy of each.
            let filed: (String) throws -> [[UUID]] = { table in
                try rows[table].map { try ResearchExport.Fields(table, $0).uuids("project_ids") }
            }
            let counts: ResearchItemCounts
            do {
                counts = ResearchItemCounts.tally(noteProjectIds: try filed("notes"), noteTagIds: [],
                                                  collectionProjectIds: try filed("collections"), assignmentTagIds: [])
            } catch let error as ResearchExportError {
                throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The projects could not be counted: \(error.description)")
            }
            return ProjectList(total: projects.count,
                               items: projects.map { record in
                                   var project = held[UserSearchText.uuidString(record.id)].map(Project.init) ?? Project(record)
                                   project.tally = UUID(uuidString: record.id).map { counts.project($0).summary }
                                   return project
                               },
                               activeProjectId: active.map(NoteRoutes.wire))
        }
        // New Project…: the editor's Save of a new one, its name and question trimmed, which makes it
        // the project the user works in, as creating one is switching to it on the Mac.
        me.post("projects") { request, context -> EditedResponse<Project> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(New.self, from: request, fields: ["name", "researchQuestion"])
            let time = UserStoreDate.rounded(now())
            // A new project's focus lists are empty, as `Project.init` seeds them.
            let project = ProjectExport(id: UUID(), name: try projectName(body.name),
                                        researchQuestion: question(body.researchQuestion),
                                        defaultSubjectTagIds: [], defaultCountryTagIds: [],
                                        createdAt: time, lastModified: time, defaultUserTagIds: [])
            try await Blocking.run {
                try store.addResearchRow(table, MacImport.project(project, version: ResearchDataEnvelope.currentFormatVersion).values,
                                         for: user.id, outsideSearch: true)
                try store.setActiveProject(project.id.uuidString, for: user.id)
            }
            let location = context.basePath.prefixing("/api/v1/me/projects/\(project.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location], response: Project(project))
        }
        me.get("projects/:projectId") { request, context -> Project in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            return Project(try await project(try context.parameters.require("projectId"), of: user.id, in: store))
        }
        me.patch("projects/:projectId") { request, context -> Project in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("projectId")
            let body = try await JSONBody.decode(Change.self, from: request, fields: ["name", "researchQuestion", "defaultUserTagIds"])
            var project = try await project(id, of: user.id, in: store)
            var columns: Set<String> = []
            if let name = body.name {
                project.name = try projectName(name)
                columns.insert("name")
            }
            if let text = body.researchQuestion {
                project.researchQuestion = question(text)
                columns.insert("research_question")
            }
            if let ids = body.defaultUserTagIds {
                project.defaultUserTagIds = try await focusTags(ids, of: user.id, in: store)
                columns.insert("default_user_tag_ids")
            }
            // A change that changes nothing writes nothing, as `commitQuestion` writes only an edit.
            let held = try await self.project(id, of: user.id, in: store)
            columns = columns.filter { column in
                switch column {
                case "name": held.name != project.name
                case "research_question": held.researchQuestion != project.researchQuestion
                default: held.defaultUserTagIds ?? [] != project.defaultUserTagIds ?? []
                }
            }
            guard !columns.isEmpty else { return Project(held) }
            project.lastModified = UserStoreDate.rounded(now())
            columns.insert("last_modified")
            let values = MacImport.project(project, version: ResearchDataEnvelope.currentFormatVersion).values
                .filter { columns.contains($0.key) }
            guard let row = try await Blocking.run({
                try store.updateResearchRow(table, id: id, values, for: user.id, outsideSearch: true)
            }) else { throw notFound(id) }
            return Project(try read(row))
        }
        // Delete Project: the activity records that name it keep the id, and the user works in Global
        // Context if they worked in it.
        me.delete("projects/:projectId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("projectId")
            guard try await Blocking.run({ try store.deleteProject(id, for: user.id) }) else { throw notFound(id) }
            return Response(status: .noContent)
        }
        // Merge into…: everything filed under it is filed under the other, which answers.
        me.post("projects/:projectId/merge") { request, context -> Project in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("projectId")
            let body = try await JSONBody.decode(Merge.self, from: request, fields: ["into"])
            do {
                try await Blocking.run { try store.mergeProject(id, into: body.into, for: user.id, at: now()) }
            } catch let error as ProjectStoreError {
                switch error {
                case .projectNotFound(let missing): throw notFound(missing)
                case .mergeIntoItself:
                    throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "into: a project cannot be merged into itself.")
                }
            }
            return Project(try await project(body.into, of: user.id, in: store))
        }
        me.get("active-project") { request, context -> ActiveProject in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            return ActiveProject(projectId: try await Blocking.run { try store.activeProjectId(of: user.id) }.map(NoteRoutes.wire))
        }
        // The project picker's choice: a project, or null for Global Context.
        me.put("active-project") { request, context -> ActiveProject in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Active.self, from: request, fields: ["projectId"])
            do {
                try await Blocking.run { try store.setActiveProject(body.projectId, for: user.id) }
            } catch ProjectStoreError.projectNotFound(let missing) {
                throw notFound(missing)
            }
            return ActiveProject(projectId: try await Blocking.run { try store.activeProjectId(of: user.id) }.map(NoteRoutes.wire))
        }
        ProjectHomeRoutes.add(to: me, services: services, resources: resources)
    }

    static var table: UserStoreSchema.Table {
        guard let table = UserStoreSchema.table(for: "Project") else { preconditionFailure("UserStoreSchema has no projects") }
        return table
    }

    /// A project's name as the editor saves it: trimmed of spaces and line breaks, and never empty, as
    /// its Save is disabled for an empty one.
    static func projectName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "name: a project's name, trimmed, cannot be empty.")
        }
        return trimmed
    }

    /// A research question as the editor and Project Home save it: trimmed, and none when empty.
    static func question(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The focus tags `ids` name, each one of the user's, in the order given, once each, as the focus
    /// tags editor's toggles keep them; `TAG_NOT_FOUND` for an id that is not theirs.
    static func focusTags(_ ids: [String], of user: String, in store: any UserDataStore) async throws -> [UUID] {
        let held = Set(try await Blocking.run { try store.tags(of: user) }.map(\.id))
        var chosen: [UUID] = []
        for id in ids {
            guard let normalized = TagReferences.normalized(id), held.contains(normalized), let uuid = UUID(uuidString: normalized) else {
                throw APIProblem(.notFound, code: "TAG_NOT_FOUND", detail: "You have no tag with the id \(id).")
            }
            if !chosen.contains(uuid) { chosen.append(uuid) }
        }
        return chosen
    }

    /// Every project of the user's, whole, by its id in uppercase.
    static func wholeProjects(of user: String, in store: any UserDataStore) async throws -> [String: ProjectExport] {
        let rows = try await Blocking.run { try store.researchRows(table, of: user) }
        var projects: [String: ProjectExport] = [:]
        for row in rows {
            let project = try read(row)
            projects[project.id.uuidString] = projects[project.id.uuidString] ?? project
        }
        return projects
    }

    static func project(_ id: String, of user: String, in store: any UserDataStore) async throws -> ProjectExport {
        guard let row = try await Blocking.run({ try store.researchRow(table, id: id, of: user) }) else { throw notFound(id) }
        return try read(row)
    }

    static func read(_ row: ExportRow) throws -> ProjectExport {
        do {
            return try ResearchExport.project(ResearchExport.Fields("projects", row))
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The project could not be read: \(error.description)")
        }
    }

    static func notFound(_ id: String) -> APIProblem {
        APIProblem(.notFound, code: "PROJECT_NOT_FOUND", detail: "You have no project with the id \(id).")
    }
}
