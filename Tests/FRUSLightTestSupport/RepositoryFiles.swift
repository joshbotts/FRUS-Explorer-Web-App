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

    /// Copies the fixture volumes named into `directory`, creating it, as a TEI folder is mounted
    /// at `/data/volumes`.
    public static func mountTEI(_ volumes: [String], at directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for volume in volumes {
            try FileManager.default.copyItem(at: tei.appendingPathComponent("\(volume).xml"),
                                             to: directory.appendingPathComponent("\(volume).xml"))
        }
    }
}
