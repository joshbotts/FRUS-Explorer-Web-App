#if !canImport(Darwin)
import Foundation
// Linux stand-in for Apple's String(localized:). The app ships English only (Localizable.strings is a
// 641-byte placeholder), so the literal or defaultValue IS the en string.
struct LinuxLocalizationValue: ExpressibleByStringInterpolation, Sendable {
    struct StringInterpolation: StringInterpolationProtocol {
        var s = ""
        init(literalCapacity: Int, interpolationCount: Int) {}
        mutating func appendLiteral(_ l: String) { s += l }
        mutating func appendInterpolation<T>(_ v: T) { s += "\(v)" }
        mutating func appendInterpolation<F: FormatStyle>(_ v: F.FormatInput, format: F) where F.FormatOutput == String {
            s += format.format(v)
        }
    }
    let s: String
    init(stringLiteral value: String) { s = value }
    init(stringInterpolation i: StringInterpolation) { s = i.s }
}
extension String {
    init(localized value: LinuxLocalizationValue, table: String? = nil, bundle: Bundle? = nil,
         locale: Locale = .current, comment: StaticString? = nil) { self = value.s }
    init(localized key: StaticString, defaultValue: LinuxLocalizationValue, table: String? = nil,
         bundle: Bundle? = nil, locale: Locale = .current, comment: StaticString? = nil) { self = defaultValue.s }
}
#endif
