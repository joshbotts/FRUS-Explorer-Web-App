// The app's SwiftData models as its source at the pin declares them, for UserStoreParityTests.

import FRUSLightTestSupport
import Foundation

/// Reads the pinned app's model types from its source: the list the app's container is built
/// from, the CloudKit inventory the app's own test derives from that container's schema, and
/// each model class's declarations.
enum AppModelSource {
    static let app = RepositoryFiles.root.appendingPathComponent("upstream/FRUS-Explorer/FRUSExplorer", isDirectory: true)

    /// `ModelContainer.frusModelTypes`, the model types the app's container holds, in its order.
    static func modelTypes() throws -> [String] {
        let code = Code(Substring(try read("Models/ModelContainer+FRUS.swift"))).blanked
        guard let start = code.range(of: "static var frusModelTypes"),
              let body = Code.body(in: code, after: start.upperBound),
              let open = code[body].firstIndex(of: "["),
              let close = code[open..<body.upperBound].firstIndex(of: "]") else {
            throw SourceError("ModelContainer+FRUS.swift no longer declares frusModelTypes as a list")
        }
        return code[open...close].matches(of: /(\w+)\.self/).map { String($0.1) }
    }

    /// `CloudKitSchemaInventory.installedIdentifiers`, by model type: every stored property of
    /// each type, relationships included. The app's `CloudKitSchemaInventoryTests` rebuilds this
    /// list from the live schema of `frusModelTypes`, so a stored property cannot be added to a
    /// model without it.
    static func storedProperties() throws -> [String: Set<String>] {
        let source = try read("Models/CloudKitSchemaInventory.swift")
        guard let start = source.range(of: "static let installedIdentifiers: [String] = ["),
              let close = source[start.upperBound...].range(of: "\n    ]") else {
            throw SourceError("CloudKitSchemaInventory.swift no longer declares installedIdentifiers as a list")
        }
        var properties: [String: Set<String>] = [:]
        for match in source[start.upperBound..<close.lowerBound].matches(of: /"CD_(\w+)(?:\.CD_(\w+))?"/) {
            let model = String(match.1)
            if let property = match.2 {
                properties[model, default: []].insert(String(property))
            } else {
                properties[model, default: []] = properties[model] ?? []
            }
        }
        return properties
    }

    /// A declaration in a model class: the type as written, such as `String`, `Date?` or
    /// `[CollectionEntry]?`, and whether SwiftData stores it.
    struct Member: Equatable {
        let type: String
        let stored: Bool
    }

    /// Each `var` or `let` directly inside the `@Model` class `model`, by name. Searches every
    /// Swift file of the app.
    static func declarations(of model: String) throws -> [String: Member] {
        for source in try sources() {
            guard source.contains("class \(model)") else { continue }
            let code = Code(Substring(source)).blanked
            let pattern = try Regex("@Model\\s+(?:(?:public|internal|final)\\s+)*class\\s+\(model)\\b")
            guard let match = code.firstMatch(of: pattern),
                  let body = Code.body(in: code, after: match.range.upperBound) else { continue }
            return Code.memberDeclarations(in: code[body])
        }
        throw SourceError("no @Model class \(model) under FRUSExplorer/")
    }

    /// Whether the app assigns `property` the output of a `JSONEncoder` anywhere, as
    /// `parametersData = try? JSONEncoder().encode(parameters)` does, or the `encoded` blob of a kit
    /// type that writes itself with a plain one, as `freshnessData =
    /// SavedSearchFreshness.run(at:matchCount:indexedVolumeCount:).encoded` does since S17b's
    /// FRUS-Explorer#1805.
    static func isWrittenAsJSON(_ property: String) throws -> Bool {
        // Not `\b`: Swift's regexes find words by Unicode's rules, under which `self.parametersData`
        // is one word.
        let pattern = try Regex("(?:^|[^A-Za-z0-9_])\(property)\\s*=\\s*try[?!]?\\s*JSONEncoder\\(\\)")
        // The raw text first, which is quick; then only those files without their comments and strings.
        for source in try sources() where source.contains(pattern) {
            if Code(Substring(source)).blanked.contains(pattern) { return true }
        }
        // `Type.call(…).encoded`, its type named in the assignment.
        let kitBlob = try Regex("(?:^|[^A-Za-z0-9_])\(property)\\s*=\\s*([A-Z][A-Za-z0-9_]*)\\.[A-Za-z0-9_]+\\([^()]*\\)\\.encoded(?![A-Za-z0-9_])")
        for source in try sources() where source.contains(".encoded") {
            for match in Code(Substring(source)).blanked.matches(of: kitBlob) {
                if let type = match.output[1].substring, try kitWritesAsJSON(String(type)) { return true }
            }
        }
        return false
    }

    /// Whether the kit's `type` declares its `encoded` blob as a plain `JSONEncoder`'s output.
    static func kitWritesAsJSON(_ type: String) throws -> Bool {
        let kit = app.deletingLastPathComponent().appendingPathComponent("FRUSCoreKit", isDirectory: true)
        let declared = try Regex("(?:struct|enum|final class|class)\\s+\(type)\\b")
        let encoded = try Regex("var\\s+encoded:\\s*Data\\?\\s*\\{\\s*try\\?\\s*JSONEncoder\\(\\)\\.encode\\(self\\)\\s*\\}")
        guard let walk = FileManager.default.enumerator(at: kit, includingPropertiesForKeys: nil) else { return false }
        for case let url as URL in walk where url.pathExtension == "swift" {
            guard let source = try? String(contentsOf: url, encoding: .utf8), source.contains(type) else { continue }
            let code = Code(Substring(source)).blanked
            if code.contains(declared), code.contains(encoded) { return true }
        }
        return false
    }

    private static func read(_ path: String) throws -> String {
        try String(contentsOf: app.appendingPathComponent(path), encoding: .utf8)
    }

    /// Every Swift file of the app, read once for all the tests.
    private static func sources() throws -> [String] {
        guard !allSources.isEmpty else { throw SourceError("no Swift files under \(app.path)") }
        return allSources
    }

    private static let allSources: [String] = {
        guard let walk = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil) else { return [] }
        return walk.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
    }()
}

struct SourceError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Swift source with its comments and string literals blanked to spaces, so braces and
/// declarations inside them are not read. Offsets and line breaks are kept. A string's
/// interpolations are read as code, so a string inside one ends where it ends, and are then
/// blanked with the string.
struct Code {
    let blanked: String

    init(_ source: Substring) {
        var scanner = Scanner(Array(source))
        scanner.code(inInterpolation: false)
        blanked = String(scanner.out)
    }

    private struct Scanner {
        let text: [Character]
        var at = 0
        var out: [Character] = []

        init(_ text: [Character], at: Int = 0) {
            self.text = text
            self.at = at
        }

        func starts(_ prefix: String) -> Bool {
            var index = at
            for character in prefix {
                guard index < text.count, text[index] == character else { return false }
                index += 1
            }
            return true
        }

        mutating func keep(_ count: Int = 1) {
            for _ in 0..<count where at < text.count {
                out.append(text[at])
                at += 1
            }
        }

        mutating func blank(_ count: Int = 1) {
            for _ in 0..<count where at < text.count {
                out.append(text[at] == "\n" ? "\n" : " ")
                at += 1
            }
        }

        /// Code, to the end or, in an interpolation, to the `)` that closes it, which is left unread.
        mutating func code(inInterpolation: Bool) {
            var parentheses = 0
            while at < text.count {
                if starts("//") {
                    while at < text.count, text[at] != "\n" { blank() }
                } else if starts("/*") {
                    blockComment()
                } else if rawHashes() > 0 {
                    rawString()
                } else if starts("\"\"\"") {
                    string(multiline: true)
                } else if text[at] == "\"" {
                    string(multiline: false)
                } else if inInterpolation, text[at] == "(" {
                    parentheses += 1
                    keep()
                } else if inInterpolation, text[at] == ")" {
                    if parentheses == 0 { return }
                    parentheses -= 1
                    keep()
                } else {
                    keep()
                }
            }
        }

        /// Swift's block comments nest.
        mutating func blockComment() {
            var depth = 0
            while at < text.count {
                if starts("/*") {
                    depth += 1
                    blank(2)
                } else if starts("*/") {
                    depth -= 1
                    blank(2)
                    if depth == 0 { return }
                } else {
                    blank()
                }
            }
        }

        /// How many `#`s open a raw string here, or 0 when none does.
        func rawHashes() -> Int {
            var index = at
            while index < text.count, text[index] == "#" { index += 1 }
            return index > at && index < text.count && text[index] == "\"" ? index - at : 0
        }

        /// A raw string, blanked to its closing quote and as many `#`s, its interpolations with it.
        mutating func rawString() {
            let hashes = rawHashes()
            keep(hashes)
            let multiline = starts("\"\"\"")
            keep(multiline ? 3 : 1)
            let close = (multiline ? "\"\"\"" : "\"") + String(repeating: "#", count: hashes)
            while at < text.count, !starts(close) { blank() }
            keep(close.count)
        }

        mutating func string(multiline: Bool) {
            let close = multiline ? "\"\"\"" : "\""
            keep(close.count)
            while at < text.count {
                if starts(close) {
                    keep(close.count)
                    return
                }
                // A string that a line ends is not closed; the scan goes on as code.
                if !multiline, text[at] == "\n" { return }
                if starts("\\(") {
                    blank(2)
                    var interpolation = Scanner(text, at: at)
                    interpolation.code(inInterpolation: true)
                    out += interpolation.out.map { $0 == "\n" ? "\n" : " " }
                    at = interpolation.at
                    blank()
                } else if text[at] == "\\" {
                    blank(2)
                } else {
                    blank()
                }
            }
        }
    }

    /// The range inside the braces of the first `{` at or after `position`.
    static func body(in code: String, after position: String.Index) -> Range<String.Index>? {
        guard let open = code[position...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return code.index(after: open)..<index }
            default: break
            }
            index = code.index(after: index)
        }
        return nil
    }

    /// Each `var` or `let` declared at the top level of a type's body, not `static` or `class`,
    /// with the type it declares as written, and whether it is stored: not `@Transient`, and with
    /// no block after its type, or one that only observes it (`didSet`, `willSet`).
    static func memberDeclarations(in body: Substring) -> [String: AppModelSource.Member] {
        var declarations: [String: AppModelSource.Member] = [:]
        func read(_ line: Substring, after previous: Substring) {
            guard let match = line.firstMatch(of: /\b(?:var|let)\s+(\w+)\s*:\s*([^={]+)/) else { return }
            let before = line[..<match.range.lowerBound]
            guard before.firstMatch(of: /\b(?:static|class)\b/) == nil else { return }
            let transient = before.contains("@Transient")
                || previous.trimmingCharacters(in: .whitespaces).hasPrefix("@Transient")
            var next = match.range.upperBound
            while next < body.endIndex, body[next].isWhitespace { next = body.index(after: next) }
            var stored = true
            if next < body.endIndex, body[next] == "{" {
                var word = body.index(after: next)
                while word < body.endIndex, body[word].isWhitespace { word = body.index(after: word) }
                stored = body[word...].hasPrefix("didSet") || body[word...].hasPrefix("willSet")
            }
            declarations[String(match.1)] = AppModelSource.Member(
                type: match.2.trimmingCharacters(in: .whitespaces), stored: stored && !transient)
        }
        var depth = 0
        var lineDepth = 0
        var lineStart = body.startIndex
        var previous = body[body.startIndex..<body.startIndex]
        var index = body.startIndex
        while index < body.endIndex {
            let c = body[index]
            if c == "\n" {
                let line = body[lineStart..<index]
                if lineDepth == 0 { read(line, after: previous) }
                if !line.allSatisfy(\.isWhitespace) { previous = line }
                lineStart = body.index(after: index)
                lineDepth = depth
            } else if c == "{" {
                depth += 1
            } else if c == "}" {
                depth -= 1
            }
            index = body.index(after: index)
        }
        if lineDepth == 0 { read(body[lineStart...], after: previous) }
        return declarations
    }
}
