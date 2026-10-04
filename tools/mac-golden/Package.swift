// swift-tools-version: 6.2
// tools/mac-golden: writes the parity harness's golden files by running the Mac app's own code.
// Mac only, and debug builds only, since the tool imports the app module with @testable. The
// owner runs it through scripts/make-golden.
//
// The FRUSExplorer target is the whole app module, compiled from the submodule unmodified
// (CLAUDE.md, rule 4). Its folder holds relative symlinks to the six submodule directories the
// Xcode app target compiles, and one stub for the asset symbol Xcode generates; nothing from the
// submodule is copied. `upstream` here is a relative symlink to the submodule.

import Foundation
import PackageDescription

/// The submodule directories the macOS app target compiles (`project.yml`). The same list as
/// ParityFormat's `UpstreamDigest.directories`.
let appDirectories = [
    "FRUSExplorer", "FTS5Store", "SemanticVectorsKit", "SourceNoteKit", "TEIHeaderKit", "WordCloudKit",
]

/// Everything in those directories that is not Swift: the app's bundle resources, plists,
/// entitlements and the like. The tool does not need them, and listing them keeps SwiftPM from
/// warning about unhandled files. An asset catalog counts as one item. SwiftPM caches this
/// manifest's result, so after a pin move adds or removes such a file, build with
/// `--manifest-cache none`, as scripts/make-golden does.
func nonSwiftFiles() -> [String] {
    let upstream = ((Context.packageDirectory + "/upstream") as NSString).resolvingSymlinksInPath
    var excluded: [String] = []
    for directory in appDirectories {
        guard let walk = FileManager.default.enumerator(atPath: "\(upstream)/\(directory)") else { continue }
        while let path = walk.nextObject() as? String {
            let isDirectory = (walk.fileAttributes?[.type] as? FileAttributeType) == .typeDirectory
            if isDirectory, path.hasSuffix(".xcassets") {
                excluded.append("\(directory)/\(path)")
                walk.skipDescendants()
            } else if !isDirectory, !path.hasSuffix(".swift") {
                excluded.append("\(directory)/\(path)")
            }
        }
    }
    return excluded.sorted()
}

let package = Package(
    name: "MacGolden",
    // The app's deployment target. It uses FoundationModels, so an earlier one does not build.
    platforms: [.macOS("26.0")],
    dependencies: [
        // The golden-file formats, from this repository's package.
        .package(name: "FRUSLight", path: "../.."),
    ],
    targets: [
        .binaryTarget(name: "llama", path: "upstream/Vendor/llama.xcframework"),
        .target(
            name: "FRUSExplorer",
            dependencies: ["llama"],
            path: "Sources/FRUSExplorer",
            exclude: nonSwiftFiles(),
            swiftSettings: [
                .swiftLanguageMode(.v6),
                // Renames the app's @main entry point, so the tool's own main can link with it.
                .unsafeFlags(["-Xfrontend", "-entry-point-function-name", "-Xfrontend", "frus_app_main"]),
            ]
        ),
        .executableTarget(
            name: "mac-golden",
            dependencies: [
                "FRUSExplorer",
                .product(name: "ParityFormat", package: "FRUSLight"),
            ],
            path: "Sources/mac-golden",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
