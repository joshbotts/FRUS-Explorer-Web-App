// A search's query string, decoded into the kit's SearchParameters: what GET /api/v1/search reads,
// and the endpoints that describe a search, such as its facets. And the reverse: a search's
// parameters as the query fields that say them, for a facet that narrows one.

import FRUSCoreKit
import Foundation

/// A search request: the kit's `SearchParameters`, and the page wanted, in the order wanted.
///
/// The query string has form semantics (`FormQuery`). A field left out keeps `SearchParameters`'
/// default, which is the app's. Eighteen names set seventeen of its fields, by the draft's names,
/// and by `SearchParameters`' own for those the draft lacks (`yearKeys`, `includeDocumentText`,
/// `includeFrontMatter`, and the four a facet narrows by):
///
/// - `keywords`, the search box's text, passed on exactly as typed, spaces and all;
/// - `phrase` and `prefixWildcard`, the structured fields the parser reads with the text;
/// - `excludedTerms`, a list;
/// - `dateRangeEarliest` and `dateRangeLatest`, each `yyyy-MM-dd` or empty for no bound. The range
///   is present when either is given, and a present range leaves out undated documents, so
///   `dateRangeEarliest=` alone is a range with no bounds;
/// - `volumeIds`, a list: the empty list means no filter;
/// - `yearKeys`, a list of start years: the empty list matches nothing;
/// - `documentType`, a `DocumentTypeFilter` raw value;
/// - `includeDocumentText`, `includeSummaries`, `includeNotes` and `includeFrontMatter`, `true`
///   or `false`: the first three are the Mac's Search in, the document text, the summaries and the
///   notes, and the last two read the user's own, which is the request's user's (S17d, `SearchUsers`);
/// - `userTagIds`, a list of the user's tags, every one of which a document must carry: the empty
///   list means no filter, and a tag that is not the user's is refused where the user is known;
/// - `personRollupId`, a person's rollup in the served index, with `personLabel`, the name a filter
///   shows; and `subjectBucket`, a subject's place in the subject vocabulary, with
///   `subjectBucketKey`, its durable name, which wins. The facets set these (`FacetNarrowing`).
///
/// - `workingCorpusId`, one of the user's working corpora (PLAN's S17e), which the search runs inside,
///   as the Mac's runs inside the corpus it has applied: `SearchUsers` resolves it for the request's
///   user over the served index (`WorkingCorpusResolver`), into the parameters' document gate
///   (`SearchParameters.runningInside(workingCorpus:)`). One that is not the user's is refused.
///
/// `limit` is 1 to 100, 20 by default, and `offset` is at least 0; together they stay within the
/// 7,500 results the app keeps of a search. `sort` is a `SearchSortOrder` raw value, `relevance` by
/// default. `reviewed`, a list of `volumeId/documentId` keys, is what Checklist Mode hides (S17e): the
/// page is cut from the results kept less those, as the Mac's window pages what its checklist leaves
/// (`MacSearchViewModel.displayedResults`), and the count is the match's, unchanged. The draft's `booleanMode` and `personRef` arrive later and are refused until then, as is
/// `subjectTagIds`, which the kit has kept inert since the subject taxonomy was retired, and the
/// draft's `facets`, which is a resource of its own here (`/api/v1/search/facets`), and any name not
/// listed here.
public struct SearchRequest: Equatable, Sendable {
    public static let maximumLimit = 100
    public static let defaultLimit = 20
    /// How many of a search's results the app keeps (`MacSearchViewModel`); the count is exact.
    public static let retainedLimit = 7_500
    /// The fields that choose a page and its order, beside the search's, and the results Checklist
    /// Mode hides from it.
    static let pageFields: Set<String> = ["limit", "offset", "sort", "reviewed"]

    public var parameters: SearchParameters
    public var limit: Int
    public var offset: Int
    /// The order of the results the app keeps, which the page is cut from.
    public var sort: SearchSortOrder
    /// The working corpus the search runs inside, by its id in upper case, or nil.
    public var workingCorpusId: String?
    /// The results Checklist Mode hides, by `volumeId/documentId`: none outside it.
    public var reviewed: Set<String>

    public static let fields: Set<String> = [
        "keywords", "phrase", "prefixWildcard", "excludedTerms", "dateRangeEarliest", "dateRangeLatest",
        "volumeIds", "yearKeys", "documentType",
        "includeDocumentText", "includeSummaries", "includeNotes", "includeFrontMatter", "userTagIds",
        "personRollupId", "personLabel", "subjectBucket", "subjectBucketKey", "workingCorpusId",
    ]

    /// The most keys `reviewed` may hold: the results a search keeps.
    public static let reviewedLimit = retainedLimit

    /// The draft's parameters this build does not take, and why.
    public static let laterFields: [(name: String, detail: String)] = [
        ("facets", "facets are a resource of their own here: GET /api/v1/search/facets, one section a request"),
        ("booleanMode", "booleanMode arrives in a later build; write OR between terms, as the search box reads it"),
        ("subjectTagIds", "subjectTagIds filters nothing in FRUS Explorer, whose subject taxonomy was retired; a user's tags are userTagIds"),
        ("personRef", "personRef arrives in a later build; a person is narrowed to by personRollupId"),
    ]

    /// Decodes a raw query string, such as `uri.query`. Throws an `APIProblem` with status 400
    /// for anything it cannot take.
    public init(formEncoded query: String?) throws(APIProblem) {
        try self.init(form: FormQuery(query))
    }

    /// Decodes `form`. An endpoint that takes more than a search and its page names its own fields
    /// in `extra`, and reads them from `form` itself.
    init(form: FormQuery, alsoTaking extra: Set<String> = []) throws(APIProblem) {
        parameters = try Self.parameters(from: form, alsoTaking: Self.pageFields.union(extra))
        limit = try form.integer("limit", in: 1...Self.maximumLimit, default: Self.defaultLimit)
        offset = try form.integer("offset", in: 0...Self.retainedLimit, default: 0)
        guard offset + limit <= Self.retainedLimit else {
            throw APIProblem.invalidParameter("offset", "with limit, it must stay within the \(Self.retainedLimit) results a search keeps: offset + limit is \(offset + limit)")
        }
        sort = try form.choice("sort", among: SearchSortOrder.allCases) ?? .relevance
        workingCorpusId = try Self.workingCorpusId(in: form)
        reviewed = try Self.reviewed(in: form)
    }

    /// The working corpus `form` names, its id in upper case, or nil for none.
    static func workingCorpusId(in form: FormQuery) throws(APIProblem) -> String? {
        guard let value = try form.single("workingCorpusId"), !value.isEmpty else { return nil }
        guard let id = UUID(uuidString: value) else {
            throw APIProblem.invalidParameter("workingCorpusId", "must be a working corpus's id, a UUID, not \(value)")
        }
        return id.uuidString
    }

    /// The results `form` says Checklist Mode hides: each a `volumeId/documentId` key, at most
    /// `reviewedLimit` of them.
    static func reviewed(in form: FormQuery) throws(APIProblem) -> Set<String> {
        try reviewed(try form.list("reviewed")?.filter { !$0.isEmpty } ?? [])
    }

    /// `keys` as the results Checklist Mode hides, each checked as ``reviewed(in:)`` checks it.
    static func reviewed(_ keys: [String]) throws(APIProblem) -> Set<String> {
        guard keys.count <= reviewedLimit else {
            throw APIProblem.invalidParameter("reviewed", "names at most \(reviewedLimit) results, the results a search keeps, not \(keys.count)")
        }
        for key in keys {
            let parts = key.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 256 }) else {
                throw APIProblem.invalidParameter("reviewed", "each is a result's volumeId/documentId, not \(key)")
            }
        }
        return Set(keys)
    }

    /// Whether a result is one Checklist Mode hides.
    func hides(_ result: SearchResult) -> Bool {
        !reviewed.isEmpty && reviewed.contains("\(result.volumeId)/\(result.documentId)")
    }

    /// The search `form` describes. An endpoint that takes more than the search names its own
    /// fields in `extra`; any other name is refused.
    static func parameters(from form: FormQuery, alsoTaking extra: Set<String>) throws(APIProblem) -> SearchParameters {
        if let later = Self.laterFields.first(where: { !form.values($0.name).isEmpty }) {
            throw APIProblem(.badRequest, code: "UNSUPPORTED_PARAMETER", detail: later.detail)
        }
        try form.refuseUnknown(Self.fields.union(extra))

        var parameters = SearchParameters(keywords: try form.single("keywords"))
        parameters.phrase = try form.single("phrase")
        parameters.prefixWildcard = try form.single("prefixWildcard")
        if let excluded = try form.list("excludedTerms") { parameters.excludedTerms = excluded }
        parameters.volumeIds = try form.list("volumeIds")
        parameters.yearKeys = try form.list("yearKeys")
        let earliest = try form.single("dateRangeEarliest")
        let latest = try form.single("dateRangeLatest")
        if earliest != nil || latest != nil {
            parameters.dateRange = DateRange(earliest: try Self.bound("dateRangeEarliest", earliest),
                                             latest: try Self.bound("dateRangeLatest", latest))
        }
        if let type = try form.choice("documentType", among: [DocumentTypeFilter.all, .documentsOnly, .editorialNotesOnly]) {
            parameters.documentTypeFilter = type
        }
        if let value = try form.bool("includeDocumentText") { parameters.includeDocumentText = value }
        if let value = try form.bool("includeSummaries") { parameters.includeSummaries = value }
        if let value = try form.bool("includeNotes") { parameters.includeNotes = value }
        if let value = try form.bool("includeFrontMatter") { parameters.includeFrontMatter = value }
        if let tags = try form.list("userTagIds") { parameters.userTagIds = tags }
        parameters.personRollupId = try form.optionalInteger("personRollupId", in: 0...Int(Int32.max))
        parameters.personLabel = try form.single("personLabel")
        parameters.subjectBucket = try form.optionalInteger("subjectBucket", in: 0...Int(Int32.max))
        parameters.subjectBucketKey = try form.single("subjectBucketKey")
        return parameters
    }

    /// The query fields that say `parameters`, as `parameters(from:alsoTaking:)` reads them: each
    /// field that differs from its default, by name, with its values. A list's empty value is one
    /// empty string. A field the API does not take is left out.
    public static func formFields(_ parameters: SearchParameters) -> [String: [String]] {
        let defaults = SearchParameters()
        var fields: [String: [String]] = [:]
        func single(_ name: String, _ value: String?) { if let value { fields[name] = [value] } }
        func list(_ name: String, _ value: [String]?) { if let value { fields[name] = value.isEmpty ? [""] : value } }
        func flag(_ name: String, _ value: Bool, _ fallback: Bool) { if value != fallback { fields[name] = [String(value)] } }
        single("keywords", parameters.keywords)
        single("phrase", parameters.phrase)
        single("prefixWildcard", parameters.prefixWildcard)
        if !parameters.excludedTerms.isEmpty { fields["excludedTerms"] = parameters.excludedTerms }
        list("volumeIds", parameters.volumeIds)
        list("yearKeys", parameters.yearKeys)
        if let range = parameters.dateRange {
            fields["dateRangeEarliest"] = [range.earliest ?? ""]
            fields["dateRangeLatest"] = [range.latest ?? ""]
        }
        if parameters.documentTypeFilter != defaults.documentTypeFilter {
            fields["documentType"] = [parameters.documentTypeFilter.rawValue]
        }
        flag("includeDocumentText", parameters.includeDocumentText, defaults.includeDocumentText)
        flag("includeSummaries", parameters.includeSummaries, defaults.includeSummaries)
        flag("includeNotes", parameters.includeNotes, defaults.includeNotes)
        flag("includeFrontMatter", parameters.includeFrontMatter, defaults.includeFrontMatter)
        if !parameters.userTagIds.isEmpty { fields["userTagIds"] = parameters.userTagIds }
        single("personRollupId", parameters.personRollupId.map(String.init))
        single("personLabel", parameters.personLabel)
        single("subjectBucket", parameters.subjectBucket.map(String.init))
        single("subjectBucketKey", parameters.subjectBucketKey)
        return fields
    }

    /// The search `parameters` say, as one string: the whole of `SearchParameters`, as JSON with its
    /// keys sorted and a gate's documents in order. Two searches the kit runs apart never share one, so
    /// what is computed for a search can be kept by it: a search through the API's fields, one inside a
    /// working corpus, whose documents no field says, and since S17e a saved search counted with its
    /// whole parameters, which a Mac's can give fields the API does not take, such as `booleanMode`,
    /// `subjectRef` or a project's `excludeDocumentIds`.
    static func signature(_ parameters: SearchParameters) -> String {
        var keyed = parameters
        keyed.documentIds = parameters.documentIds?.sorted()
        keyed.excludeDocumentIds = parameters.excludeDocumentIds?.sorted()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(keyed) { return String(decoding: data, as: UTF8.self) }
        // Not reached, as the value always encodes: its query fields, which tell apart what the API reads.
        let fields = formFields(parameters)
        return "fields " + fields.keys.sorted().map { "\($0)=\(fields[$0, default: []])" }.joined(separator: "&")
    }

    /// A date bound: nil for an empty value, otherwise `yyyy-MM-dd`, which the kit compares as text.
    static func bound(_ name: String, _ value: String?) throws(APIProblem) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let shape = value.map { $0.isASCIIDigitCharacter ? "9" : String($0) }.joined()
        guard shape == "9999-99-99" else {
            throw APIProblem.invalidParameter(name, "must be a date as yyyy-MM-dd, or empty for no bound, not \(value)")
        }
        return value
    }
}

/// How one search becomes another: each query field whose values change, with its new values, or
/// nil for a field the new search leaves out. A browser app applies it to the search it shows.
public struct SearchChange: Equatable, Sendable {
    public var fields: [String: [String]?]

    public init(from before: SearchParameters, to after: SearchParameters) {
        let old = SearchRequest.formFields(before)
        let new = SearchRequest.formFields(after)
        var fields: [String: [String]?] = [:]
        for name in Set(old.keys).union(new.keys) where old[name] != new[name] {
            fields[name] = .some(new[name])
        }
        self.fields = fields
    }
}

extension SearchChange: Codable {
    struct Name: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    /// An object, a field's values by its name, `null` for one the new search leaves out.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Name.self)
        for name in fields.keys.sorted() {
            if let values = fields[name] ?? nil {
                try container.encode(values, forKey: Name(stringValue: name))
            } else {
                try container.encodeNil(forKey: Name(stringValue: name))
            }
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Name.self)
        var fields: [String: [String]?] = [:]
        for key in container.allKeys {
            fields[key.stringValue] = .some(try container.decodeIfPresent([String].self, forKey: key))
        }
        self.fields = fields
    }
}
