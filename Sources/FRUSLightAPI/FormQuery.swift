// Query strings with HTML form semantics, as a browser's URLSearchParams writes them.

import Foundation

/// A query string's name and value pairs, in order, decoded as `application/x-www-form-urlencoded`:
/// `+` is a space, and a literal plus arrives as `%2B`. A list is the same name repeated, and one
/// empty value, `name=`, is the empty list.
///
/// Hummingbird's `uri.queryParameters` leaves `+` as it is, and its form decoder takes repeated
/// names only as `name[]=`, so the API reads the raw query itself. A pair that will not decode,
/// such as a malformed percent escape or bytes that are not UTF-8, is refused with a 400.
struct FormQuery: Sendable {
    let pairs: [(name: String, value: String)]

    init(_ query: String?) throws(APIProblem) {
        var pairs: [(String, String)] = []
        for item in (query ?? "").split(separator: "&", omittingEmptySubsequences: true) {
            let parts = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = try Self.decode(parts[0], in: item)
            let value = try parts.count > 1 ? Self.decode(parts[1], in: item) : ""
            pairs.append((name, value))
        }
        self.pairs = pairs
    }

    static func decode(_ raw: Substring, in item: Substring) throws(APIProblem) -> String {
        guard let decoded = raw.replacingOccurrences(of: "+", with: " ").removingPercentEncoding else {
            throw APIProblem(.badRequest, code: "MALFORMED_QUERY", detail: "\(item) is not form-encoded UTF-8: percent-encode every byte outside A-Z a-z 0-9 - . _ ~, and send a space as + or %20")
        }
        return decoded
    }

    /// Every value given for `name`, in order.
    func values(_ name: String) -> [String] { pairs.filter { $0.name == name }.map(\.value) }

    /// The one value given for `name`, or nil when there is none. Refused when it is given twice.
    func single(_ name: String) throws(APIProblem) -> String? {
        let values = values(name)
        guard values.count <= 1 else { throw APIProblem.invalidParameter(name, "given \(values.count) times; it takes one value") }
        return values.first
    }

    /// The list given for `name`: nil when there is none, and empty for one empty value. An empty
    /// value among others is refused, since it could mean either.
    func list(_ name: String) throws(APIProblem) -> [String]? {
        let values = values(name)
        if values.isEmpty { return nil }
        if values == [""] { return [] }
        guard !values.contains("") else {
            throw APIProblem.invalidParameter(name, "an empty value means the empty list, so it cannot be given with other values")
        }
        return values
    }

    /// `true` or `false`, or nil when absent.
    func bool(_ name: String) throws(APIProblem) -> Bool? {
        switch try single(name) {
        case nil: return nil
        case "true": return true
        case "false": return false
        case let value?: throw APIProblem.invalidParameter(name, "must be true or false, not \(value)")
        }
    }

    /// A decimal integer in `range`, or `defaultValue` when absent.
    func integer(_ name: String, in range: ClosedRange<Int>, default defaultValue: Int) throws(APIProblem) -> Int {
        guard let raw = try single(name) else { return defaultValue }
        guard !raw.isEmpty, raw.allSatisfy(\.isASCIIDigitCharacter), let value = Int(raw), range.contains(value) else {
            throw APIProblem.invalidParameter(name, "must be a whole number from \(range.lowerBound) to \(range.upperBound), not \(raw)")
        }
        return value
    }

    /// The value whose raw value is given, or nil when absent. `known` names the values a refusal lists.
    func choice<T: RawRepresentable>(_ name: String, among known: [T]) throws(APIProblem) -> T? where T.RawValue == String {
        guard let raw = try single(name) else { return nil }
        guard let value = T(rawValue: raw) else {
            throw APIProblem.invalidParameter(name, "must be one of \(known.map(\.rawValue).joined(separator: ", ")), not \(raw)")
        }
        return value
    }

    /// Refuses a name outside `known`, so a misspelt filter is never silently ignored.
    func refuseUnknown(_ known: Set<String>) throws(APIProblem) {
        if let unknown = pairs.first(where: { !known.contains($0.name) }) {
            throw APIProblem(.badRequest, code: "UNKNOWN_PARAMETER",
                             detail: "\(unknown.name) is not a parameter here; known: \(known.sorted().joined(separator: ", "))")
        }
    }
}

extension Character {
    /// 0 to 9 alone. A range of characters would also take a digit carrying a combining mark,
    /// such as `2\u{301}`, which compares as text after every real date.
    var isASCIIDigitCharacter: Bool { asciiValue.map { (0x30...0x39).contains($0) } ?? false }
}
