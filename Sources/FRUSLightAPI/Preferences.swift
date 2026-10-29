// /api/v1/me/preferences (PLAN's S17f): the user's synced preferences, the Mac's `SyncedPreferences`,
// one row of them for each user, as a Mac keeps the earliest record. The browser app reads the
// citation style, the document mode, Log Research Sessions and the reader's own order of the tag and
// project lists here, which until S17f it kept in its own storage; the word cloud's criteria are kept
// for phase 3's clouds. A user who has set nothing has the app's initial values, as a Mac with no
// record reads its own defaults, and the row is made the first time something is set, written as the
// import writes a Mac's (`MacImport.preferences`) and read as the export reads one.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// The user's synced preferences.
public struct Preferences: Codable, Equatable, Sendable, ResponseEncodable {
    /// Cite's style, `CitationStyle`'s raw value, or empty for none chosen, which Cite reads as
    /// history.state.gov's (`citationStyleRaw`).
    public var citationStyle: String
    /// The mode a document opens in, `DefaultDocumentMode`'s raw value (`read`, `research` or
    /// `rememberLast`), or empty for none chosen, which is Remember Last (`defaultDocumentModeRaw`).
    public var defaultDocumentMode: String
    /// Log Research Sessions: off, nothing new is added to the trail.
    public var researchLoggingEnabled: Bool
    /// The reader's own order of the tag and project lists, by id, the most wanted first
    /// (`ListOrderPreferences`); empty for none, and for a stored order that does not read.
    public var tagOrder: [String]
    public var projectOrder: [String]
    /// The word cloud's criteria, as the Mac's settings keep them.
    public var wordCloud: WordCloud
    /// When the row was made and last changed; absent while the user has set nothing.
    public var createdAt: String?
    public var updatedAt: String?

    public struct WordCloud: Codable, Equatable, Sendable {
        public var minLength: Int
        public var minCount: Int
        public var foldPlurals: Bool
        public var filterMarkings: Bool
        public var excludeBoilerplate: Bool
        /// The hidden words of every lens, as the Mac's settings decode their JSON; and each lens's own,
        /// as stored.
        public var globalStopwords: [String]
        public var lensStopwordsJSON: String
    }

    init(_ preferences: SyncedPreferencesExport, stored: Bool) {
        citationStyle = preferences.citationStyleRaw
        defaultDocumentMode = preferences.defaultDocumentModeRaw
        researchLoggingEnabled = preferences.researchLoggingEnabled
        let order = ListOrder.decode(preferences.listOrderJSON)
        tagOrder = (order?.tags ?? []).map(\.uuidString)
        projectOrder = (order?.projects ?? []).map(\.uuidString)
        wordCloud = WordCloud(minLength: preferences.wcMinLength, minCount: preferences.wcMinCount,
                              foldPlurals: preferences.wcFoldPlurals, filterMarkings: preferences.wcFilterMarkings,
                              excludeBoilerplate: preferences.wcExcludeBoilerplate,
                              globalStopwords: TagReferences.decode(preferences.wcGlobalStopwordsJSON) ?? [],
                              lensStopwordsJSON: preferences.wcLensStopwordsJSON)
        createdAt = stored ? UserStoreDate.text(preferences.createdAt) : nil
        updatedAt = stored ? UserStoreDate.text(preferences.updatedAt) : nil
    }
}

/// `SyncedPreferences.listOrderJSON`'s shape (`ListOrderPreferences.Payload`): both lists, each by id.
struct ListOrder: Codable, Equatable {
    var tags: [UUID] = []
    var projects: [UUID] = []

    /// The stored order, as the app decodes it: none for empty text, or text that does not read as
    /// both lists.
    static func decode(_ json: String) -> ListOrder? {
        guard !json.isEmpty else { return nil }
        return try? JSONDecoder().decode(ListOrder.self, from: Data(json.utf8))
    }

    /// The JSON the app writes, its two keys in the order the app's payload declares them, which a
    /// keyed encoder on Linux does not keep, and each id an uppercase `uuidString`.
    var encoded: String {
        "{\"tags\":\(TagReferences.encode(tags.map(\.uuidString))),\"projects\":\(TagReferences.encode(projects.map(\.uuidString)))}"
    }
}

enum PreferenceRoutes {
    struct Change: Decodable {
        let citationStyle: String?
        let defaultDocumentMode: String?
        let researchLoggingEnabled: Bool?
        let tagOrder: [String]?
        let projectOrder: [String]?
    }

    /// `DefaultDocumentMode`'s raw values, the app's, in its order.
    static let documentModes = ["read", "research", "rememberLast"]

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices) {
        let store = services.store
        let now = services.now

        me.get("preferences") { request, context -> Preferences in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            return try await preferences(of: user.id, in: store)
        }
        // A change to the fields given, each written as the Mac's settings write it: a list's order
        // replacing that list's alone (`ListOrderPreferences.setOrder`).
        me.patch("preferences") { request, context -> Preferences in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(
                Change.self, from: request,
                fields: ["citationStyle", "defaultDocumentMode", "researchLoggingEnabled", "tagOrder", "projectOrder"])
            var values: [String: SQLiteValue] = [:]
            if let style = body.citationStyle {
                guard style.isEmpty || CitationStyle(rawValue: style) != nil else {
                    throw APIProblem(.badRequest, code: "INVALID_FIELD",
                                     detail: "citationStyle: one of \(CitationStyle.allCases.map(\.rawValue).joined(separator: ", ")), or empty for none.")
                }
                values["citation_style_raw"] = .text(style)
            }
            if let mode = body.defaultDocumentMode {
                guard mode.isEmpty || documentModes.contains(mode) else {
                    throw APIProblem(.badRequest, code: "INVALID_FIELD",
                                     detail: "defaultDocumentMode: one of \(documentModes.joined(separator: ", ")), or empty for none.")
                }
                values["default_document_mode_raw"] = .text(mode)
            }
            if let logging = body.researchLoggingEnabled { values["research_logging_enabled"] = .integer(logging ? 1 : 0) }
            let tags = try body.tagOrder.map { try ordered($0, "tagOrder") }
            let projects = try body.projectOrder.map { try ordered($0, "projectOrder") }
            let reorders = tags != nil || projects != nil
            guard !values.isEmpty || reorders else { return try await preferences(of: user.id, in: store) }
            // A list's order replaces that list in the payload as the write finds it, so a change to the
            // other list made meanwhile, from another tab, is kept.
            let merge: @Sendable (ExportRow?) throws -> [String: SQLiteValue] = { held in
                guard reorders else { return [:] }
                var order = try held.map { ListOrder.decode(try read($0).listOrderJSON) ?? ListOrder() } ?? ListOrder()
                if let tags { order.tags = tags }
                if let projects { order.projects = projects }
                return ["list_order_json": .text(order.encoded)]
            }
            let (time, changed) = (now(), values)
            let row = try await Blocking.run {
                try store.setPreferences(changed, initial: MacImport.preferences(initial(at: time)).values, for: user.id, at: time,
                                         merging: merge)
            }
            return Preferences(try read(row), stored: true)
        }
    }

    /// The user's preferences: the row's, or the app's initial values while they have none.
    static func preferences(of user: String, in store: any UserDataStore) async throws -> Preferences {
        guard let row = try await Blocking.run({ try store.preferences(of: user) }) else {
            return Preferences(initial(at: Date(timeIntervalSince1970: 0)), stored: false)
        }
        return Preferences(try read(row), stored: true)
    }

    /// Whether the user's trail records what they do: Log Research Sessions, on until it is turned off.
    static func isLogging(_ user: String, in store: any UserDataStore) async throws -> Bool {
        try await Blocking.run { try store.preferences(of: user) }.map { try read($0).researchLoggingEnabled } ?? true
    }

    /// A list's order as the store keeps it: each id an uppercase `uuidString`, once, where given first.
    static func ordered(_ ids: [String], _ field: String) throws -> [UUID] {
        var order: [UUID] = []
        for id in ids {
            guard let uuid = UUID(uuidString: id) else {
                throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "\(field): \(id) is not an id.")
            }
            if !order.contains(uuid) { order.append(uuid) }
        }
        return order
    }

    /// The values of `SyncedPreferences()`, made at `time`.
    static func initial(at time: Date) -> SyncedPreferencesExport {
        SyncedPreferencesExport(createdAt: time, updatedAt: time, wcMinLength: 3, wcMinCount: 1, wcFoldPlurals: true,
                                wcFilterMarkings: true, wcExcludeBoilerplate: true, wcGlobalStopwordsJSON: "",
                                wcLensStopwordsJSON: "", citationStyleRaw: "", defaultDocumentModeRaw: "",
                                researchLoggingEnabled: true, listOrderJSON: "")
    }

    static func read(_ row: ExportRow) throws -> SyncedPreferencesExport {
        do {
            return try ResearchExport.preferences(ResearchExport.Fields("preferences", row))
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The preferences could not be read: \(error.description)")
        }
    }
}
