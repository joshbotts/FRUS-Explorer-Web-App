// How the app reads an RTF colour (S15d): AppKit's reader makes an NSColor from the colour table, and
// CollectionProse.hexColor takes it through usingColorSpace(.sRGB) as the light appearance draws it
// (FRUS-Explorer#1790), and the kit's CollectionProse.hex truncates each channel to a byte and reads
// (near-)black as no colour. Measured on macOS 27 over the golden spans and dense sweeps
// (docs/DEVLOG.md, S15d): an sRGB entry is its stored values, and a catalog name the system's colour
// of that name in the light appearance, exactly; a gray entry, Display P3, Generic RGB and the legacy
// \colortbl, which AppKit reads as Generic RGB, are converted by ColorSync, which this reproduces
// within one step per channel.

import Foundation
// The kit's span rules, hidden from this module's clients: tools/mac-golden links the codec beside
// the app module, which compiles the kit's files itself.
internal import FRUSCoreKit

/// One entry of a document's colour tables, as the reader resolves it.
struct RTFColorEntry: Equatable, Sendable {
    enum Space: Equatable, Sendable {
        case sRGB, gray, displayP3, genericRGB, other
    }

    /// The legacy `\colortbl` entry's bytes, or nil when it is empty (auto).
    var legacy: (Int, Int, Int)?
    /// The `\*\expandedcolortbl` entry, when there is one and it is not empty.
    var space: Space?
    var components: [Int] = []
    var catalogName: String?

    static func == (a: RTFColorEntry, b: RTFColorEntry) -> Bool {
        a.legacy?.0 == b.legacy?.0 && a.legacy?.1 == b.legacy?.1 && a.legacy?.2 == b.legacy?.2
            && a.space == b.space && a.components == b.components && a.catalogName == b.catalogName
    }
}

/// A colour as the app reads it: its hex, or none, and whether a colour-space conversion made it.
struct RTFResolvedColor: Equatable, Sendable {
    var hex: String?
    var converted: Bool
}

public enum RTFColor {
    /// The app's `hex(r:g:b:)`, the kit's `CollectionProse.hex` since FRUS-Explorer#1807: nil when
    /// every channel is under 0.08, else each channel clamped to 0…1 and truncated.
    static func hex(_ r: Double, _ g: Double, _ b: Double) -> String? {
        CollectionProse.hex(r: CGFloat(r), g: CGFloat(g), b: CGFloat(b))
    }

    /// Whether the app reads a colour the writer gives these bytes as (near-)black, so as none: the
    /// writer gives each byte its bucket's midpoint, under 0.08 for 19 and below and over it for 20.
    public static func isNearBlack(_ rgb: (Int, Int, Int)) -> Bool {
        [rgb.0, rgb.1, rgb.2].allSatisfy { (Double($0) + 0.5) / 255 < 0.08 }
    }

    /// `RRGGBB`'s bytes, or nil when it is not six uppercase hexadecimal digits.
    public static func rgb(hex: String) -> (Int, Int, Int)? {
        guard hex.utf8.count == 6, hex.utf8.allSatisfy({ (0x30...0x39).contains($0) || (0x41...0x46).contains($0) }),
              let value = Int(hex, radix: 16) else { return nil }
        return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
    }

    static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }

    /// How the app reads the colour at `index` of a document's tables, or nil for no colour.
    static func resolve(_ index: Int, in table: [RTFColorEntry]) -> RTFResolvedColor? {
        guard index > 0, index < table.count else { return nil }
        let entry = table[index]
        if let space = entry.space {
            if let name = entry.catalogName, let hex = RTFCatalogColors.aqua[name] {
                return RTFResolvedColor(hex: hex, converted: false)
            }
            let c = entry.components.map { Double($0) / 100_000 }
            switch space {
            case .sRGB where c.count >= 3:
                return RTFResolvedColor(hex: hex(c[0], c[1], c[2]), converted: false)
            case .gray where c.count >= 1:
                // AppKit's gray is its value in each channel, but a hair under it where the value is
                // a whole byte, which truncation then drops a step.
                return RTFResolvedColor(hex: hex(c[0], c[0], c[0]), converted: true)
            case .displayP3 where c.count >= 3:
                return RTFResolvedColor(hex: convert(c, decode: sRGBDecode, matrix: displayP3ToSRGB), converted: true)
            case .genericRGB where c.count >= 3:
                return RTFResolvedColor(hex: convert(c, decode: genericDecode, matrix: genericToSRGB), converted: true)
            default:
                break
            }
        }
        guard let (r, g, b) = entry.legacy else { return nil }
        let c = [Double(r) / 255, Double(g) / 255, Double(b) / 255]
        return RTFResolvedColor(hex: convert(c, decode: genericDecode, matrix: genericToSRGB), converted: true)
    }

    private static func convert(_ c: [Double], decode: (Double) -> Double, matrix: [[Double]]) -> String? {
        let linear = c.prefix(3).map { decode(clamp($0)) }
        let out = matrix.map { row in sRGBEncode(max(0, row[0] * linear[0] + row[1] * linear[1] + row[2] * linear[2])) }
        return hex(out[0], out[1], out[2])
    }

    static func sRGBDecode(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    static func sRGBEncode(_ l: Double) -> Double { l <= 0.0031308 ? 12.92 * l : 1.055 * pow(l, 1 / 2.4) - 0.055 }
    /// Generic RGB's tone curve, gamma 1.8.
    static func genericDecode(_ c: Double) -> Double { pow(c, 1.8) }

    static let displayP3ToSRGB = multiply(inverse(rgbToXYZ(sRGBPrimaries)), rgbToXYZ(displayP3Primaries))
    static let genericToSRGB = multiply(inverse(rgbToXYZ(sRGBPrimaries)), rgbToXYZ(genericPrimaries))

    private static let d65 = (0.3127, 0.3290)
    private static let sRGBPrimaries = [(0.64, 0.33), (0.30, 0.60), (0.15, 0.06)]
    private static let displayP3Primaries = [(0.680, 0.320), (0.265, 0.690), (0.150, 0.060)]
    /// Generic RGB's primaries, Apple's Trinitron set, with a D65 white.
    private static let genericPrimaries = [(0.630, 0.340), (0.295, 0.605), (0.155, 0.077)]

    /// The matrix from linear RGB with these primaries and a D65 white to XYZ.
    private static func rgbToXYZ(_ primaries: [(Double, Double)]) -> [[Double]] {
        func xyz(_ p: (Double, Double)) -> [Double] { [p.0 / p.1, 1, (1 - p.0 - p.1) / p.1] }
        let columns = primaries.map(xyz)
        let m = (0..<3).map { r in (0..<3).map { c in columns[c][r] } }
        let scale = apply(inverse(m), xyz(d65))
        return (0..<3).map { r in (0..<3).map { c in m[r][c] * scale[c] } }
    }

    private static func apply(_ m: [[Double]], _ v: [Double]) -> [Double] {
        m.map { row in row[0] * v[0] + row[1] * v[1] + row[2] * v[2] }
    }

    private static func multiply(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
        (0..<3).map { r in (0..<3).map { c in (0..<3).reduce(0) { $0 + a[r][$1] * b[$1][c] } } }
    }

    private static func inverse(_ m: [[Double]]) -> [[Double]] {
        let (a, b, c) = (m[0][0], m[0][1], m[0][2])
        let (d, e, f) = (m[1][0], m[1][1], m[1][2])
        let (g, h, i) = (m[2][0], m[2][1], m[2][2])
        let det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
        return [[(e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det],
                [(f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det],
                [(d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det]]
    }

    /// The `\cssrgb` value the writer gives a byte: its bucket's midpoint, so the app's truncation
    /// reads the byte back whatever its rounding.
    static func component(byte: Int) -> Int {
        min(100_000, Int(((Double(byte) + 0.5) / 255 * 100_000).rounded()))
    }
}
