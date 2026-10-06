// A search's query string, decoded into the kit's SearchParameters: what GET /api/v1/search reads.

import FRUSCoreKit
import Foundation

/// A search request: the kit's `SearchParameters`, and the page wanted.
///
/// The query string has form semantics (`FormQuery`). A field left out keeps `SearchParameters`'
/// default, which is the app's. Thirteen names set twelve of its fields, by the draft's names,
/// and by `SearchParameters`' own for the three the draft lacks (`yearKeys`,
/// `includeDocumentText` and `includeFrontMatter`):
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
///   or `false`.
///
/// `limit` is 1 to 100, 20 by default, and `offset` is at least 0; together they stay within the
/// 7,500 results the app keeps of a search. The draft's `facets`, `booleanMode`, `subjectTagIds`
/// and `personRef` arrive later and are refused until then, as is any name not listed here.
public struct SearchRequest: Equatable, Sendable {
    public static let maximumLimit = 100
    public static let defaultLimit = 20
    /// How many of a search's results the app keeps (`MacSearchViewModel`); the count is exact.
    public static let retainedLimit = 7_500

    public var parameters: SearchParameters
    public var limit: Int
    public var offset: Int

    public static let fields: Set<String> = [
        "keywords", "phrase", "prefixWildcard", "excludedTerms", "dateRangeEarliest", "dateRangeLatest",
        "volumeIds", "yearKeys", "documentType",
        "includeDocumentText", "includeSummaries", "includeNotes", "includeFrontMatter",
    ]

    /// The draft's parameters this build does not take yet.
    public static let laterFields = ["facets", "booleanMode", "subjectTagIds", "personRef"]

    /// Decodes a raw query string, such as `uri.query`. Throws an `APIProblem` with status 400
    /// for anything it cannot take.
    public init(formEncoded query: String?) throws(APIProblem) {
        let form = try FormQuery(query)
        if let later = Self.laterFields.first(where: { !form.values($0).isEmpty }) {
            throw APIProblem(.badRequest, code: "UNSUPPORTED_PARAMETER", detail: "\(later) arrives in a later build")
        }
        try form.refuseUnknown(Self.fields.union(["limit", "offset"]))

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
        self.parameters = parameters

        limit = try form.integer("limit", in: 1...Self.maximumLimit, default: Self.defaultLimit)
        offset = try form.integer("offset", in: 0...Self.retainedLimit, default: 0)
        guard offset + limit <= Self.retainedLimit else {
            throw APIProblem.invalidParameter("offset", "with limit, it must stay within the \(Self.retainedLimit) results a search keeps: offset + limit is \(offset + limit)")
        }
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
