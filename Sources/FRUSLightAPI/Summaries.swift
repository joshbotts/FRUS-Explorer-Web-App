// /api/v1/me/summaries and a document's summaries (PLAN's S15d): a document's summaries, newest first
// by the app's order, as the Research rail shows them, each named by its prompt only while that
// prompt is the user's, as the app names one; and the reader's own, the web's own, written, changed
// and deleted here. Every other summary, an AI summary or an import, is read-only. Nothing here
// generates a summary.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// One of a document's summaries, with the fields of the Mac's export (`GeneratedSummaryExport`).
public struct Summary: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var volumeId: String
    public var documentId: String
    public var promptId: String
    /// The name of the prompt it was made with, only while the user has that prompt, as the app's
    /// `SummarizationPrompt.resolve` names it (`.requested`); null otherwise, a standard prompt's
    /// summary among them, since an export carries no standard prompt.
    public var promptName: String?
    /// The text, which for a structured summary is the model's JSON, shown as the app shows it.
    public var responseText: String
    /// The kit's `ResponseFormat`: general or structured, or unknown for a value it cannot read.
    public var responseFormat: String
    public var wasChunked: Bool
    /// `SummaryAuthorship`'s raw value; a summary with none is `aiGenerated`, as every reader in the
    /// app takes it.
    public var authorship: String
    /// A collection's headnote draft, which the app keeps out of the document's own summaries: never
    /// in a document's list, and given by its id, so that a client knows it was given one.
    public var isHeadnoteDraft: Bool
    public var projectId: String?
    public var createdAt: String?
    public var lastModified: String?
    /// Whether the reader may change or delete it: one of their own (`OwnSummary.isEditable`).
    public var editable: Bool
    /// A document's newest summary from a research database, an export made with the owner's writing,
    /// which keeps no other (`ResearchDatabaseMark.isFromResearchDatabase`, S16e).
    public var fromResearchDatabase: Bool

    init(_ record: SummaryRecord, promptNames: [String: String]) {
        id = NoteRoutes.wire(record.id)
        volumeId = record.volumeId
        documentId = record.documentId
        promptId = NoteRoutes.wire(record.promptId)
        promptName = promptNames[UserSearchText.uuidString(record.promptId)]
        responseText = record.responseText
        responseFormat = Self.format(record.responseFormat)
        wasChunked = record.wasChunked
        authorship = (record.authorship.flatMap(SummaryAuthorship.init(rawValue:)) ?? .aiGenerated).rawValue
        isHeadnoteDraft = record.isHeadnoteDraft
        projectId = record.projectId.map(NoteRoutes.wire)
        createdAt = record.createdAt.map(UserStoreDate.text)
        lastModified = record.lastModified.map(UserStoreDate.text)
        editable = record.isEditable
        fromResearchDatabase = ResearchDatabaseMark.isFromResearchDatabase(record)
    }

    /// The kit's `ResponseFormat` of a stored value, by its case's name.
    static func format(_ stored: String) -> String {
        switch try? JSONDecoder().decode(ResponseFormat.self, from: Data(stored.utf8)) {
        case .general?: "general"
        case .structured?: "structured"
        case nil: "unknown"
        }
    }

    /// The `response_format` of the reader's own summaries: the kit's `ResponseFormat.general`, as
    /// its encoder writes it, `{"general":{}}`.
    static let generalFormat: String = {
        let data = (try? JSONEncoder().encode(ResponseFormat.general)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }()

    /// Each field, a prompt's name, a project and a date with none as null.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(volumeId, forKey: .volumeId)
        try container.encode(documentId, forKey: .documentId)
        try container.encode(promptId, forKey: .promptId)
        try container.encode(promptName, forKey: .promptName)
        try container.encode(responseText, forKey: .responseText)
        try container.encode(responseFormat, forKey: .responseFormat)
        try container.encode(wasChunked, forKey: .wasChunked)
        try container.encode(authorship, forKey: .authorship)
        try container.encode(isHeadnoteDraft, forKey: .isHeadnoteDraft)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(editable, forKey: .editable)
        try container.encode(fromResearchDatabase, forKey: .fromResearchDatabase)
    }
}

/// A document's summaries but its headnote drafts, newest first by the app's `ranksAbove`, every one:
/// the rail shows 20 at most, as the app's carousel fetches.
public struct DocumentSummaries: Codable, Equatable, Sendable, ResponseEncodable {
    public var volumeId: String
    public var documentId: String
    public var items: [Summary]
}

enum SummaryRoutes {
    struct Text: Decodable { let responseText: String }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources) {
        let store = services.store
        let now = services.now

        let documentSummaries: RouterPath = "volumes/:volumeId/documents/:documentId/summaries"
        me.get(documentSummaries) { request, context -> DocumentSummaries in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try UserDataRoutes.document(context, resources: resources)
            let (summaries, names) = try await Blocking.run {
                (try store.summaries(of: document, for: user.id), try store.prompts(for: user.id))
            }
            // A headnote draft is a collection's own, as the app's carousel leaves it out.
            return DocumentSummaries(volumeId: document.volumeId, documentId: document.documentId,
                                     items: summaries.filter { !$0.isHeadnoteDraft }.map { Summary($0, promptNames: names) })
        }
        // Write a Summary, the web's own: the reader's own summary of the document.
        me.post(documentSummaries) { request, context -> EditedResponse<Summary> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try UserDataRoutes.document(context, resources: resources)
            let body = try await JSONBody.decode(Text.self, from: request, fields: ["responseText"])
            try checkText(body.responseText)
            let (summary, names) = try await stored {
                (try store.createOwnSummary(in: document, text: body.responseText, responseFormat: Summary.generalFormat,
                                            for: user.id, at: now()),
                 try store.prompts(for: user.id))
            }
            let response = Summary(summary, promptNames: names)
            let location = context.basePath.prefixing("/api/v1/me/summaries/\(response.id)")
            return EditedResponse(status: .created, headers: [.location: location], response: response)
        }
        // Any of the user's summaries by its id, a headnote draft too, which says it is one.
        me.get("summaries/:summaryId") { request, context -> Summary in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("summaryId")
            let (summary, names) = try await Blocking.run { (try store.summary(id, of: user.id), try store.prompts(for: user.id)) }
            guard let summary else { throw problem(.summaryNotFound(id)) }
            return Summary(summary, promptNames: names)
        }
        // Edit… on one of the reader's own. PUT, where tags and highlights change by PATCH: the
        // whole text is replaced.
        me.put("summaries/:summaryId") { request, context -> Summary in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("summaryId")
            let body = try await JSONBody.decode(Text.self, from: request, fields: ["responseText"])
            try checkText(body.responseText)
            let (summary, names) = try await stored {
                (try store.updateOwnSummary(id, text: body.responseText, for: user.id, at: now()), try store.prompts(for: user.id))
            }
            return Summary(summary, promptNames: names)
        }
        // Delete… on one of the reader's own.
        me.delete("summaries/:summaryId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("summaryId")
            try await stored { try store.deleteOwnSummary(id, for: user.id) }
            return Response(status: .noContent)
        }
    }

    /// SQLite's text ends at a NUL, so a summary may not hold one; the store refuses one that is
    /// only white space.
    private static func checkText(_ text: String) throws {
        guard !text.unicodeScalars.contains("\0") else {
            throw NoteRoutes.invalidField("responseText", "a summary cannot hold U+0000.")
        }
    }

    /// Runs a store call off the cooperative pool, its refusals as problems.
    private static func stored<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        do {
            return try await Blocking.run(work)
        } catch let error as SummaryStoreError {
            throw problem(error)
        }
    }

    static func problem(_ error: SummaryStoreError) -> APIProblem {
        switch error {
        case .summaryNotFound(let id):
            APIProblem(.notFound, code: "SUMMARY_NOT_FOUND", detail: "You have no summary with the id \(id).")
        case .readOnly(let id):
            APIProblem(.forbidden, code: "SUMMARY_READ_ONLY",
                       detail: "The summary \(id) is not one you wrote here, so it can be read but not changed or deleted.")
        case .emptyText:
            NoteRoutes.invalidField("responseText", "a summary's text, trimmed of spaces and new lines, cannot be empty.")
        }
    }
}
