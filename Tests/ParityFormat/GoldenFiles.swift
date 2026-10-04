// The golden files in fixtures/golden, and which of them are still to be made.

import Foundation

/// The golden files the parity checks read, relative to `fixtures/golden`.
public enum GoldenFile: String, CaseIterable, Sendable {
    /// Check 4, made from the app's source by `scripts/make-golden`.
    case render = "render/manifest.json"
    /// Check 3's compiled expressions, made from the app's source by `scripts/make-golden`.
    case expressions = "queries.expressions.json"
    /// Check 3's counts and results, made from the owner's three-volume export.
    case results = "queries.results.json"
    /// Check 2, made from the owner's three-volume export.
    case indexSummary = "index-summary.json"

    /// True for a file made from the owner's export, which may wait for it. One made from the
    /// app's source alone is made in the session and committed, never left pending.
    public var needsExport: Bool {
        switch self {
        case .render, .expressions: false
        case .results, .indexSummary: true
        }
    }
}

/// Which golden files exist and which wait, from `fixtures/golden/PENDING`. That file lists one
/// golden file per line, a tab, and what it waits for. Each golden file must be either present or
/// listed, never both and never neither, so a test can say what waits without skipping anything.
public struct GoldenStatus: Sendable {
    public enum State: Equatable, Sendable {
        case present
        case pending(String)
    }

    public let directory: URL
    public let states: [GoldenFile: State]

    public static let pendingFile = "PENDING"

    public init(directory: URL) throws {
        self.directory = directory
        var pending: [String: String] = [:]
        let pendingURL = directory.appendingPathComponent(Self.pendingFile)
        if FileManager.default.fileExists(atPath: pendingURL.path) {
            let text = try String(contentsOf: pendingURL, encoding: .utf8)
            for line in text.split(separator: "\n") where !line.hasPrefix("#") {
                let fields = line.split(separator: "\t", maxSplits: 1).map(String.init)
                guard fields.count == 2, GoldenFile(rawValue: fields[0]) != nil else {
                    throw GoldenError.malformed(Self.pendingFile, "\"\(line)\" is not a golden file, a tab and a reason")
                }
                pending[fields[0]] = fields[1]
            }
        }
        var states: [GoldenFile: State] = [:]
        for file in GoldenFile.allCases {
            let exists = FileManager.default.fileExists(atPath: directory.appendingPathComponent(file.rawValue).path)
            switch (exists, pending[file.rawValue]) {
            case (true, nil): states[file] = .present
            case (false, let reason?): states[file] = .pending(reason)
            case (true, _?):
                throw GoldenError.malformed(Self.pendingFile, "\(file.rawValue) exists but is still listed as pending")
            case (false, nil):
                throw GoldenError.malformed(Self.pendingFile, "\(file.rawValue) is missing and not listed as pending")
            }
        }
        self.states = states
    }

    public func url(_ file: GoldenFile) -> URL { directory.appendingPathComponent(file.rawValue) }

    public func isPresent(_ file: GoldenFile) -> Bool { states[file] == .present }
}

public enum GoldenError: Error, CustomStringConvertible, Equatable {
    case malformed(String, String)
    case stale(String, String)

    public var description: String {
        switch self {
        case .malformed(let file, let detail): return "\(file): \(detail)"
        case .stale(let file, let detail): return "\(file) is stale: \(detail). Run scripts/make-golden"
        }
    }
}

/// Reads and writes golden JSON. Keys are sorted and output is indented, so a refreshed golden
/// file diffs line by line.
public enum GoldenJSON {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }

    public static func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encode(value).write(to: url, options: .atomic)
    }

    public static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        } catch let error as DecodingError {
            throw GoldenError.malformed(url.lastPathComponent, "\(error)")
        }
    }
}
