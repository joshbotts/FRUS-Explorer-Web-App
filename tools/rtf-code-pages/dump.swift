// The code pages of the codec's charsets, decoded by this platform's Foundation (S15d): every byte
// from 0x80, and every lead and trail pair of a double-byte page whose lead is no character by
// itself, one line each: the page, the bytes in hexadecimal, and the scalars read, joined by "+",
// or "-" for none. tools/rtf-code-pages/make runs it on the Mac and in swift:6.4-noble.
//   dump <output file>

import Foundation

let pages: [(name: String, encoding: UInt, doubleByte: Bool)] = [
    ("cp1252", 0x8000_0500, false), ("cp1250", 0x8000_0501, false), ("cp1251", 0x8000_0502, false), ("cp1253", 0x8000_0503, false),
    ("cp1254", 0x8000_0504, false), ("cp1255", 0x8000_0505, false), ("cp1256", 0x8000_0506, false), ("cp1257", 0x8000_0507, false),
    ("cp1258", 0x8000_0508, false), ("cp874", 0x8000_041D, false), ("macRoman", 0x8000_0000, false), ("nextstep", String.Encoding.nextstep.rawValue, false),
    ("cp932", 0x8000_0420, true), ("cp949", 0x8000_0422, true), ("cp936", 0x8000_0421, true), ("cp950", 0x8000_0423, true),
]

func scalars(_ bytes: [UInt8], _ encoding: UInt) -> String {
    guard let text = String(bytes: bytes, encoding: String.Encoding(rawValue: encoding)) else { return "-" }
    return text.unicodeScalars.map { String($0.value, radix: 16, uppercase: true) }.joined(separator: "+")
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: dump <output file>\n".utf8))
    exit(2)
}
var out = ""
for page in pages {
    for byte in 0x80...0xFF { out += "\(page.name) \(String(format: "%02X", byte)) \(scalars([UInt8(byte)], page.encoding))\n" }
    guard page.doubleByte else { continue }
    for lead in 0x81...0xFE where scalars([UInt8(lead)], page.encoding) == "-" {
        for trail in 0x40...0xFE {
            out += "\(page.name) \(String(format: "%02X%02X", lead, trail)) \(scalars([UInt8(lead), UInt8(trail)], page.encoding))\n"
        }
    }
}
try out.write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
