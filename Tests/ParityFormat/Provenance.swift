// Where a golden file came from, and the fixtures every parity check runs on.

import Crypto
import Foundation

/// The three fixture volumes every parity check runs on (`fixtures/tei`).
public enum ParityFixtures {
    public static let volumes = ["frus1894Nicaragua", "frus1961-63v06", "frus1969-76ve09p1"]

    /// The fixtures' folder, from the repository root.
    public static let teiPath = "fixtures/tei"

    /// The input keys of the fixture files, as a golden file made from them records them: each
    /// volume's TEI, then `SHA256SUMS`.
    public static var teiInputKeys: [String] {
        volumes.map { "\(teiPath)/\($0).xml" } + ["\(teiPath)/SHA256SUMS"]
    }

    /// Checks `tei`, the fixtures' folder, against its `SHA256SUMS`: it lists exactly the fixture
    /// volumes, the folder holds no other TEI, and each file matches its line. Returns the SHA-256
    /// of each of `teiInputKeys`, by key. Throws `GoldenError.malformed` otherwise.
    public static func verifiedInputs(tei: URL) throws -> [String: String] {
        let sums: Data
        do {
            sums = try Data(contentsOf: tei.appendingPathComponent("SHA256SUMS"))
        } catch {
            throw GoldenError.malformed(teiPath, "SHA256SUMS could not be read: \(error.localizedDescription)")
        }
        var listed: [String: String] = [:]
        for line in String(decoding: sums, as: UTF8.self).split(separator: "\n") {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count == 2 else { throw GoldenError.malformed(teiPath, "SHA256SUMS cannot read \"\(line)\"") }
            listed[fields[1]] = fields[0]
        }
        let expected = Set(volumes.map { "\($0).xml" })
        let present = Set((try? FileManager.default.contentsOfDirectory(atPath: tei.path)) ?? []).filter { $0.hasSuffix(".xml") }
        guard Set(listed.keys) == expected, present == expected else {
            throw GoldenError.malformed(teiPath, "it must hold exactly \(expected.sorted().joined(separator: ", ")), each listed in SHA256SUMS")
        }
        var inputs: [String: String] = [:]
        for file in expected.sorted() {
            let digest = try Digest.sha256(contentsOf: tei.appendingPathComponent(file))
            guard digest == listed[file] else { throw GoldenError.malformed(teiPath, "\(file) does not match SHA256SUMS") }
            inputs["\(teiPath)/\(file)"] = digest
        }
        inputs["\(teiPath)/SHA256SUMS"] = Digest.sha256(sums)
        return inputs
    }
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
    /// `UpstreamDigest` over the app's sources and resources in the submodule.
    public var sourceDigest: String
    /// What the file was made from, by key:
    /// - a key holding a `/` is a file's path from the repository root, and its value is that
    ///   file's SHA-256;
    /// - a key `<path>#records` (`recordsKey(_:)`) names the query list at `<path>`, and its value
    ///   is `QueryList.recordDigest` of its queries, which leaves out what cannot change a result;
    /// - any other key is information only, such as an export's `research_provenance.app_build`.
    ///
    /// The validation compares the first two with the checkout.
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

    /// The suffix of an input key that records a query list's records rather than its bytes.
    public static let recordsSuffix = "#records"

    /// The input key for the records of the query list at `path`, from the repository root.
    public static func recordsKey(_ path: String) -> String { path + recordsSuffix }
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

/// A digest of the app's sources and resources in the submodule: SHA-256 over each file's path and
/// SHA-256, in path order. Any change to those files, as a pin move makes, changes it. The bundled
/// resources count as much as the Swift files: `broken-refs-index.json`, for one, changes the
/// reader's HTML and the indexer's output.
public enum UpstreamDigest {
    /// The submodule directories the Mac golden tool compiles, and whose resources the app bundles.
    public static let directories = [
        "FRUSExplorer", "FTS5Store", "SemanticVectorsKit", "SourceNoteKit", "TEIHeaderKit", "WordCloudKit",
    ]

    /// The digest of `directories` under `upstream`, the submodule's root.
    public static func compute(upstream: URL) throws -> String {
        var lines: [String] = []
        for directory in directories {
            let root = upstream.appendingPathComponent(directory, isDirectory: true)
            for file in try files(under: root) {
                let path = root.appendingPathComponent(file.path).path
                let data: Data
                if file.isLink {
                    data = Data(try FileManager.default.destinationOfSymbolicLink(atPath: path).utf8)
                } else {
                    data = try Data(contentsOf: URL(fileURLWithPath: path))
                }
                lines.append("\(directory)/\(file.path)\t\(Digest.sha256(data))")
            }
        }
        lines.sort { $0.utf8.lexicographicallyPrecedes($1.utf8) }
        return Digest.sha256(Data(lines.joined(separator: "\n").utf8))
    }

    /// Every regular file and symbolic link under `root`, by its relative path, sorted by the
    /// path's UTF-8 bytes so that Linux and macOS agree. A name starting with `.`, such as
    /// `.DS_Store`, is left out with everything under it. A symbolic link is not followed: it is
    /// listed with `isLink`, and `compute` hashes the path it holds.
    static func files(under root: URL) throws -> [(path: String, isLink: Bool)] {
        let manager = FileManager.default
        var files: [(path: String, isLink: Bool)] = []
        func walk(_ relative: String) throws {
            let directory = relative.isEmpty ? root.path : root.appendingPathComponent(relative).path
            for name in try manager.contentsOfDirectory(atPath: directory) where !name.hasPrefix(".") {
                let path = relative.isEmpty ? name : "\(relative)/\(name)"
                // Not followed: the attributes of a symbolic link are its own.
                let type = try manager.attributesOfItem(atPath: "\(directory)/\(name)")[.type] as? FileAttributeType
                switch type {
                case .typeDirectory?: try walk(path)
                case .typeRegular?: files.append((path, false))
                case .typeSymbolicLink?: files.append((path, true))
                default: continue
                }
            }
        }
        try walk("")
        return files.sorted { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }
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
