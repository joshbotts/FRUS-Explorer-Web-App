// The app's data files, FRUSExplorer/Resources from the pinned commit, read once at start.

import FRUSCoreKit
import FRUSLightCore
import Foundation

/// What the server reads from the app's data files. The manifest and the broken-refs index are
/// decoded at start; the indexing resources, which search reads for subject filters, decode each
/// file on first use.
public final class ServerResources: Sendable {
    /// The folder they were read from.
    public let directory: URL
    /// The published catalogue's 553 volumes, in `manifest.json`'s order, read by the kit's
    /// `FixedVolumeCatalogue`, which decodes it as the app's `ManifestStore` does.
    public let manifest: [VolumeManifestEntry]
    /// Each volume's position in `manifest`, by volume id.
    private let positions: [String: Int]
    /// The reader's broken-refs index, which degrades dead cross-references.
    public let brokenRefs: BrokenRefsIndex
    /// The four files that change what an index holds, for the kit's search stack.
    public let indexing: IndexingResources

    /// The files the server cannot start without: those it reads here, and the four
    /// `IndexingResources` requires.
    public static let requiredFiles = ["manifest.json", "broken-refs-index.json"]
        + IndexingResources.indexResourceNames.map { "\($0).json" }.filter { $0 != "broken-refs-index.json" }

    /// Reads the data files in `directory`. Throws `ServerResourcesError` naming every missing
    /// file, or the one that will not decode.
    public static func load(from directory: URL) throws -> ServerResources {
        let missing = requiredFiles.filter {
            !FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
        guard missing.isEmpty else { throw ServerResourcesError.missing(directory: directory.path, files: missing) }
        func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
            do {
                return try JSONDecoder().decode(type, from: Data(contentsOf: directory.appendingPathComponent(name)))
            } catch {
                throw ServerResourcesError.unreadable(directory: directory.path, file: name, reason: "\(error)")
            }
        }
        let manifest: [VolumeManifestEntry]
        do {
            manifest = try FixedVolumeCatalogue(contentsOf: directory.appendingPathComponent("manifest.json")).citableEntries
        } catch {
            throw ServerResourcesError.unreadable(directory: directory.path, file: "manifest.json", reason: "\(error)")
        }
        let brokenRefs = try decode(BrokenRefsIndex.self, "broken-refs-index.json")
        return ServerResources(directory: directory, manifest: manifest, brokenRefs: brokenRefs,
                               indexing: try IndexingResources.loading(fromDirectory: directory))
    }

    init(directory: URL, manifest: [VolumeManifestEntry], brokenRefs: BrokenRefsIndex, indexing: IndexingResources) {
        self.directory = directory
        self.manifest = manifest
        var positions: [String: Int] = [:]
        for (position, entry) in manifest.enumerated() where positions[entry.volumeId] == nil {
            positions[entry.volumeId] = position
        }
        self.positions = positions
        self.brokenRefs = brokenRefs
        self.indexing = indexing
    }

    /// The manifest's entry for `volumeId`, or nil when the published catalogue has no such
    /// volume. Only a manifest id is ever joined into a path.
    public func volume(_ volumeId: String) -> VolumeManifestEntry? {
        positions[volumeId].map { manifest[$0] }
    }
}

/// The app's data files are not where the configuration says.
public enum ServerResourcesError: Error, CustomStringConvertible, Equatable {
    case missing(directory: String, files: [String])
    case unreadable(directory: String, file: String, reason: String)

    public var description: String {
        switch self {
        case .missing(let directory, let files):
            return "\(directory) lacks \(files.joined(separator: ", ")). FRUS_RESOURCES_DIR must name a copy of FRUSExplorer/Resources from the pinned FRUS-Explorer commit; the image has one at \(ServerConfiguration.imageResourcesDirectory.path)"
        case .unreadable(let directory, let file, let reason):
            return "\(directory)/\(file) cannot be read: \(reason)"
        }
    }
}
