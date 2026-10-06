// Check 3 through the API: a parity query as the query string of GET /api/v1/search.

import Foundation
import ParityFormat

public enum APIParity {
    /// How a client writes a query string.
    public enum Encoding: Sendable, CaseIterable {
        /// Every byte outside `A-Z a-z 0-9 - . _ ~` percent-encoded, a space as `%20`.
        case strict
        /// As a browser's `URLSearchParams` writes it: a space as `+`, and every byte outside
        /// `A-Z a-z 0-9 * - . _` percent-encoded.
        case urlSearchParams
    }

    /// The name and value pairs that ask the API for `query`'s search: its text always, even when
    /// empty or blank, and each filter it names. A list is its name repeated, and the empty list
    /// one empty value. A date range sends both bounds, an absent one empty.
    public static func items(_ query: ParityQuery, limit: Int? = nil, offset: Int? = nil) -> [(name: String, value: String)] {
        let filters = query.filters
        var items: [(String, String)] = [("keywords", query.query)]
        func list(_ name: String, _ values: [String]?) {
            guard let values else { return }
            items += values.isEmpty ? [(name, "")] : values.map { (name, $0) }
        }
        if let phrase = filters.phrase { items.append(("phrase", phrase)) }
        if let prefix = filters.prefixWildcard { items.append(("prefixWildcard", prefix)) }
        list("excludedTerms", filters.excludedTerms)
        list("volumeIds", filters.volumeIds)
        list("yearKeys", filters.yearKeys)
        if let range = filters.dateRange {
            items.append(("dateRangeEarliest", range.earliest ?? ""))
            items.append(("dateRangeLatest", range.latest ?? ""))
        }
        if let type = filters.documentType { items.append(("documentType", type)) }
        for (name, value) in [("includeDocumentText", filters.includeDocumentText), ("includeSummaries", filters.includeSummaries),
                              ("includeNotes", filters.includeNotes), ("includeFrontMatter", filters.includeFrontMatter)] {
            if let value { items.append((name, value ? "true" : "false")) }
        }
        if let limit { items.append(("limit", String(limit))) }
        if let offset { items.append(("offset", String(offset))) }
        return items
    }

    /// `items(query)` as a query string, without the leading `?`.
    public static func formEncode(_ query: ParityQuery, limit: Int? = nil, offset: Int? = nil, encoding: Encoding = .strict) -> String {
        items(query, limit: limit, offset: offset)
            .map { "\(encode($0.name, encoding))=\(encode($0.value, encoding))" }
            .joined(separator: "&")
    }

    public static func encode(_ text: String, _ encoding: Encoding) -> String {
        var encoded = ""
        for byte in text.utf8 {
            switch byte {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "-"), UInt8(ascii: "."), UInt8(ascii: "_"):
                encoded.append(Character(Unicode.Scalar(byte)))
            case UInt8(ascii: "~") where encoding == .strict, UInt8(ascii: "*") where encoding == .urlSearchParams:
                encoded.append(Character(Unicode.Scalar(byte)))
            case UInt8(ascii: " ") where encoding == .urlSearchParams:
                encoded.append("+")
            default:
                encoded += String(format: "%%%02X", byte)
            }
        }
        return encoded
    }
}
