// Where a golden file came from, and the fixtures every parity check runs on.

import Crypto
import Foundation

/// The three fixture volumes every parity check runs on (`fixtures/tei`).
public enum ParityFixtures {
    public static let volumes = ["frus1894Nicaragua", "frus1961-63v06", "frus1969-76ve09p1"]
}

/// What made a golden file, and from which inputs. A test compares `sourceDigest` and the input
/// digests with the checkout, so a golden file made before a pin move, or from another query
/// list or other fixtures, fails as stale rather than as a parity difference.
public struct Provenance: Codable, Equatable, Sendable {
    /// The command that wrote the file, such as `tools/mac-golden render`.
    public var tool: String
    /// `git rev-parse HEAD` in the submodule when the file was made, for people to read. Tests
    /// compare `sourceDigest` instead, which needs no git.
    public var upstreamCommit: String?
    /// `CURRENT_PROJECT_VERSION` in the submodule's `project.yml`.
    public var appBuild: Int?
    /// `IndexingPipeline.currentDateIndexVersion` at the pin.
    public var indexVersion: Int
    /// `UpstreamDigest` over the submodule's Swift sources.
    public var sourceDigest: String
    /// SHA-256 of each input file, keyed by its path from the repository root.
    public var inputs: [String: String]
    public var platform: Platform

    public init(tool: String, upstreamCommit: String?, appBuild: Int?, indexVersion: Int,
                sourceDigest: String, inputs: [String: String], platform: Platform) {
        self.tool = tool
        self.upstreamCommit = upstreamCommit
        self.appBuild = appBuild
        self.indexVersion = indexVersion
        self.sourceDigest = sourceDigest
        self.inputs = inputs
        self.platform = platform
    }
}

/// The machine a golden file was made on. Recorded so a difference can be traced to a platform;
/// never compared.
public struct Platform: Codable, Equatable, Sendable {
    public var os: String
    public var arch: String
    public var sqlite: String?
    public var timeZone: String
    public var locale: String

    public init(os: String, arch: String, sqlite: String?, timeZone: String, locale: String) {
        self.os = os
        self.arch = arch
        self.sqlite = sqlite
        self.timeZone = timeZone
        self.locale = locale
    }

    /// This process's platform.
    public static func current(sqlite: String? = nil) -> Platform {
        #if arch(arm64)
        let arch = "arm64"
        #elseif arch(x86_64)
        let arch = "x86_64"
        #else
        let arch = "other"
        #endif
        #if os(macOS)
        let name = "macOS"
        #elseif os(Linux)
        let name = "Linux"
        #else
        let name = "other"
        #endif
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return Platform(os: "\(name) \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
                        arch: arch, sqlite: sqlite, timeZone: TimeZone.current.identifier,
                        locale: Locale.current.identifier)
    }
}

/// A digest of the submodule's Swift sources: SHA-256 over each file's path and SHA-256, in
/// path order. Any change to those files, as a pin move makes, changes it.
public enum UpstreamDigest {
    /// The submodule directories whose Swift files the Mac golden tool compiles.
    public static let directories = [
        "FRUSExplorer", "FTS5Store", "SemanticVectorsKit", "SourceNoteKit", "TEIHeaderKit", "WordCloudKit",
    ]

    /// The digest of `directories` under `upstream`, the submodule's root.
    public static func compute(upstream: URL) throws -> String {
        var lines: [String] = []
        for directory in directories {
            let root = upstream.appendingPathComponent(directory, isDirectory: true)
            for path in try swiftFiles(under: root) {
                let data = try Data(contentsOf: root.appendingPathComponent(path))
                lines.append("\(directory)/\(path)\t\(Digest.sha256(data))")
            }
        }
        return Digest.sha256(Data(lines.sorted().joined(separator: "\n").utf8))
    }

    /// Relative paths of the `.swift` files under `root`, sorted.
    static func swiftFiles(under root: URL) throws -> [String] {
        guard let enumerator = FileManager.default.enumerator(atPath: root.path) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: root.path])
        }
        var paths: [String] = []
        while let path = enumerator.nextObject() as? String {
            if path.hasSuffix(".swift") { paths.append(path) }
        }
        return paths.sorted()
    }
}

/// SHA-256, as lowercase hex.
public enum Digest {
    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { byte in
            let hex = String(byte, radix: 16)
            return byte < 16 ? "0" + hex : hex
        }.joined()
    }

    public static func sha256(_ string: String) -> String { sha256(Data(string.utf8)) }

    public static func sha256(contentsOf url: URL) throws -> String { sha256(try Data(contentsOf: url)) }
}
