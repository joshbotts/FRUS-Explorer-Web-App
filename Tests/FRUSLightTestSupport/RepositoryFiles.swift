// Where the server's tests find the repository's files: the app's data files and the TEI fixtures.

import Foundation

/// Paths in this repository, found from this file, so the tests read the submodule's data files
/// as the image's copy of them.
public enum RepositoryFiles {
    public static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    /// The pinned commit's `FRUSExplorer/Resources`, which the image copies.
    public static let resources = root.appendingPathComponent("upstream/FRUS-Explorer/FRUSExplorer/Resources", isDirectory: true)
    /// The three fixture volumes' TEI.
    public static let tei = root.appendingPathComponent("fixtures/tei", isDirectory: true)
    /// The kit's fixture volumes for a section's own text (fixtures/own-text/README.md).
    public static let ownText = root.appendingPathComponent("fixtures/own-text", isDirectory: true)

    /// Copies the fixture volumes named, from `fixtures/tei` or else `fixtures/own-text`, into
    /// `directory`, creating it, as a TEI folder is mounted at `/data/volumes`.
    public static func mountTEI(_ volumes: [String], at directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for volume in volumes {
            let name = "\(volume).xml"
            let own = ownText.appendingPathComponent(name)
            let source = FileManager.default.fileExists(atPath: tei.appendingPathComponent(name).path) || !FileManager.default.fileExists(atPath: own.path)
                ? tei.appendingPathComponent(name) : own
            try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent(name))
        }
    }
}
