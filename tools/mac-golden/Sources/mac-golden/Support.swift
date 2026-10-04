// What the three commands share: arguments, the repository, provenance, and scratch space.

import Foundation
import ParityFormat
import SQLite3
@testable import FRUSExplorer

struct ToolError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Writes a line to standard error.
func note(_ line: String) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
}

/// A command and its `--name value` options.
struct Arguments {
    struct UsageError: Error {
        let message: String
    }

    let command: String
    private var options: [String: String] = [:]

    init(_ arguments: [String]) throws {
        guard let command = arguments.first, !command.hasPrefix("-") else { throw UsageError(message: "no command") }
        self.command = command
        var rest = arguments.dropFirst()
        while let name = rest.popFirst() {
            guard name.hasPrefix("--"), let value = rest.popFirst() else {
                throw UsageError(message: "expected --option value, found \(name)")
            }
            guard options.updateValue(value, forKey: name) == nil else { throw UsageError(message: "\(name) given twice") }
        }
    }

    mutating func take(_ name: String) -> String? { options.removeValue(forKey: name) }

    /// An option naming a file, relative to the current directory.
    mutating func path(_ name: String) -> URL? { take(name).map { URL(fileURLWithPath: $0).standardizedFileURL } }

    /// Refuses options the command did not read.
    func finish() throws {
        if let name = options.keys.sorted().first { throw UsageError(message: "\(command) takes no \(name)") }
    }
}

/// This repository's checkout, with the submodule.
struct Repository {
    let root: URL

    init(root path: String) throws {
        root = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        for required in ["fixtures/tei", "upstream/FRUS-Explorer/FRUSExplorer"] {
            guard FileManager.default.fileExists(atPath: root.appendingPathComponent(required).path) else {
                throw ToolError("\(root.path) has no \(required): run from the repository's root, or pass --repo, with the submodule checked out")
            }
        }
    }

    var upstream: URL { url("upstream/FRUS-Explorer") }

    func url(_ relative: String) -> URL { root.appendingPathComponent(relative).standardizedFileURL }

    /// `url`'s path from the root, or its absolute path when it lies outside the repository.
    func relativePath(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }

    /// The provenance of a golden file made from `inputs`, keyed as `Provenance.inputs` says: a
    /// file's path from the root, a query list's path from the root with `#records`, or a key
    /// that is information only, such as an export's `research_provenance.app_build`.
    func provenance(tool: String, inputs: [String: String]) throws -> Provenance {
        Provenance(
            tool: tool,
            upstreamCommit: try? run("/usr/bin/git", ["-C", upstream.path, "rev-parse", "HEAD"]),
            appBuild: appBuild(),
            indexVersion: IndexingPipeline.currentDateIndexVersion,
            sourceDigest: try UpstreamDigest.compute(upstream: upstream),
            inputs: inputs,
            platform: Platform.current(sqlite: String(cString: sqlite3_libversion()))
        )
    }

    /// The input that records the query list at `url` by its records rather than its bytes, so a
    /// changed note or rule leaves the golden file current: `QueryList.recordDigest` of `queries`,
    /// under `Provenance.recordsKey` of the list's path from the root. A list outside the
    /// repository keeps its absolute path, which check-golden then reports as stale.
    func records(_ url: URL, _ queries: [ParityQuery]) -> [String: String] {
        [Provenance.recordsKey(relativePath(url)): QueryList.recordDigest(queries)]
    }

    /// `CURRENT_PROJECT_VERSION` in the submodule's `project.yml`, when every target agrees on it.
    func appBuild() -> Int? {
        guard let text = try? String(contentsOf: upstream.appendingPathComponent("project.yml"), encoding: .utf8) else {
            return nil
        }
        let builds = Set(text.matches(of: /CURRENT_PROJECT_VERSION: (\d+)/).compactMap { Int($0.1) })
        return builds.count == 1 ? builds.first : nil
    }
}

/// Runs a program and returns its standard output, trimmed.
func run(_ program: String, _ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: program)
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw ToolError("\(program) exited with \(process.terminationStatus)") }
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

/// The type of the item at `path` itself, a symbolic link not followed, or nil when there is
/// none. A dangling link is an item.
func itemType(_ path: String) -> FileAttributeType? {
    (try? FileManager.default.attributesOfItem(atPath: path))?[.type] as? FileAttributeType
}

/// A temporary directory and a throwaway defaults suite for the app's pipeline, so a command
/// touches neither the app's data nor its settings. `remove()` deletes both.
final class Scratch {
    let directory: URL
    private let suite = "mac-golden.\(UUID().uuidString)"

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("mac-golden-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Copies a database into the directory. A database is never opened where it lies. A symbolic
    /// link is resolved first, so the checks and the copy are the database's own, and anything but
    /// a regular file is refused. So is one with a `-wal` or `-journal` beside it: it may be open
    /// in another program or hold unfinished writes, which a copy of the file alone would lose.
    func copy(database: URL) throws -> URL {
        let source = database.resolvingSymlinksInPath()
        switch itemType(source.path) {
        case .typeRegular?: break
        case nil: throw ToolError("\(database.path) does not exist")
        default: throw ToolError("\(database.path) is not a regular file: use a file Export Research Database… wrote")
        }
        for suffix in ["-wal", "-journal"] where itemType(source.path + suffix) != nil {
            throw ToolError("\(source.path)\(suffix) exists, so the database may be open or unfinished: use a file Export Research Database… wrote")
        }
        let copy = directory.appendingPathComponent("frus.db")
        try FileManager.default.copyItem(at: source, to: copy)
        guard itemType(copy.path) == .typeRegular else {
            throw ToolError("the copy of \(source.path) is not a regular file")
        }
        return copy
    }

    /// The app's SearchService over the database at `url`, built as the app builds it.
    func searchService(database url: URL) throws -> SearchService {
        guard let defaults = UserDefaults(suiteName: suite) else { throw ToolError("no defaults suite \(suite)") }
        let store = try FTS5Store(databaseURL: url)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: url, volumesDirectory: directory,
                                            defaults: defaults)
        return SearchService(fts5Store: store, pipeline: pipeline)
    }

    func remove() {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

/// The `SearchParameters` a parity query sets: its text, and each filter it names. A filter it
/// leaves out keeps the app's default.
func searchParameters(_ query: ParityQuery) throws -> SearchParameters {
    let filters = query.filters
    var parameters = SearchParameters(keywords: query.query)
    parameters.phrase = filters.phrase
    parameters.prefixWildcard = filters.prefixWildcard
    if let excluded = filters.excludedTerms { parameters.excludedTerms = excluded }
    parameters.volumeIds = filters.volumeIds
    parameters.yearKeys = filters.yearKeys
    if let range = filters.dateRange { parameters.dateRange = DateRange(earliest: range.earliest, latest: range.latest) }
    if let type = filters.documentType {
        guard let filter = DocumentTypeFilter(rawValue: type) else {
            throw ToolError("\(query.id): \(type) is not a DocumentTypeFilter")
        }
        parameters.documentTypeFilter = filter
    }
    if let value = filters.includeFrontMatter { parameters.includeFrontMatter = value }
    if let value = filters.includeDocumentText { parameters.includeDocumentText = value }
    if let value = filters.includeSummaries { parameters.includeSummaries = value }
    if let value = filters.includeNotes { parameters.includeNotes = value }
    return parameters
}

/// Reads a query list, refusing repeated ids and, given the rules, a rule the rules file lacks.
func loadQueries(_ url: URL, rules: URL? = nil) throws -> [ParityQuery] {
    let queries = try QueryList.load(url)
    var seen = Set<String>()
    for query in queries where !seen.insert(query.id).inserted {
        throw ToolError("\(url.lastPathComponent): \(query.id) appears twice")
    }
    if let rules {
        let known = Set(try QueryList.loadRules(rules).map(\.id))
        for query in queries where !known.contains(query.rule) {
            throw ToolError("\(query.id): rule \(query.rule) is not in \(rules.lastPathComponent)")
        }
    }
    return queries
}
