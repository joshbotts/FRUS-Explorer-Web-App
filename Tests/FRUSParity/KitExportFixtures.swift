// The kit's own research exports, one of each format version from 1 to 7, which its suites decode
// (`ResearchDataFixtures`, in the app's test folder for FRUSCoreKit): one record of every type each
// version carried, in that version's shape, with fixed ids. The import's tests read them from the
// submodule's source, since a test target of the kit's is no library this package can link.

import Foundation
import ParityFormat

public enum KitExportFixtures {
    /// The fixtures' file in the submodule.
    public static let path = "FRUSExplorerTests/FRUSCoreKit/ResearchDataFixtures.swift"

    /// Each version's file, by version, as the kit's `ResearchDataFixtures.versionN` holds it.
    public static func files(layout: RepositoryLayout) throws -> [(version: Int, json: String)] {
        let source = try String(contentsOf: layout.upstream.appendingPathComponent(path), encoding: .utf8)
        var files: [(version: Int, json: String)] = []
        for match in source.matches(of: /static let version([0-9]+) = #"""\n((?:.|\n)*?)\n"""#/) {
            guard let version = Int(match.1) else { continue }
            files.append((version, String(match.2)))
        }
        guard files.map(\.version) == Array(1...files.count), !files.isEmpty else {
            throw GoldenError.malformed(path, "no longer holds one raw string for each format version from 1, as versionN")
        }
        return files
    }
}
