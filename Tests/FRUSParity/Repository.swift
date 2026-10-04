// Where the harness finds the repository's fixtures and golden files, and what it reads from the submodule.

import Foundation
import ParityFormat

/// The paths the parity checks read, from the repository root.
public struct RepositoryLayout: Sendable {
    public let root: URL

    public init(root: URL) { self.root = root.standardizedFileURL }

    public var upstream: URL { root.appendingPathComponent("upstream/FRUS-Explorer", isDirectory: true) }
    public var golden: URL { root.appendingPathComponent("fixtures/golden", isDirectory: true) }
    public var queries: URL { root.appendingPathComponent(Self.queriesPath) }
    public var rules: URL { root.appendingPathComponent(Self.rulesPath) }
    public var tei: URL { root.appendingPathComponent(ParityFixtures.teiPath, isDirectory: true) }

    /// `git rev-parse HEAD` in the submodule, or nil when git cannot say.
    public func upstreamCommit() -> String? { Upstream.commit(upstream) }

    public static let queriesPath = "fixtures/parity/queries.jsonl"
    public static let rulesPath = "fixtures/parity/rules.tsv"

    /// The repository holding `directory`: the nearest folder at or above it with a Package.swift
    /// and the FRUS-Explorer submodule beside it.
    public static func locate(from directory: URL) throws -> RepositoryLayout {
        var candidate = directory.standardizedFileURL
        while true {
            let manager = FileManager.default
            if manager.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path),
               manager.fileExists(atPath: candidate.appendingPathComponent("upstream/FRUS-Explorer").path) {
                return RepositoryLayout(root: candidate)
            }
            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else {
                throw GoldenError.malformed(directory.path, "no folder at or above it holds Package.swift and upstream/FRUS-Explorer; pass --repo")
            }
            candidate = parent
        }
    }
}

/// What the harness reads from the submodule for a golden file's provenance.
enum Upstream {
    /// `UpstreamDigest.compute`, once per submodule path in a process: it hashes about 600 files,
    /// 66 MB with the app's resources.
    static func sourceDigest(_ upstream: URL) throws -> String {
        try cache.value(for: upstream.standardizedFileURL.path) { try UpstreamDigest.compute(upstream: upstream) }
    }

    /// `CURRENT_PROJECT_VERSION` in the submodule's `project.yml`, or nil when it has none.
    static func appBuild(_ upstream: URL) -> Int? {
        guard let text = try? String(contentsOf: upstream.appendingPathComponent("project.yml"), encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("CURRENT_PROJECT_VERSION:") else { continue }
            let value = trimmed.dropFirst("CURRENT_PROJECT_VERSION:".count).trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
            if let build = Int(value) { return build }
        }
        return nil
    }

    /// `git rev-parse HEAD` in the submodule, or nil when git cannot say, as in a container
    /// that mounts a worktree whose git directory lies outside it.
    static func commit(_ upstream: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", upstream.path, "rev-parse", "HEAD"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let commit = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, commit.count == 40, commit.allSatisfy(\.isHexDigit) else { return nil }
        return commit
    }

    private static let cache = DigestCache()
}

/// A lock-guarded memo of submodule digests.
private final class DigestCache: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func value(for key: String, _ compute: () throws -> String) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        if let value = values[key] { return value }
        let value = try compute()
        values[key] = value
        return value
    }
}
