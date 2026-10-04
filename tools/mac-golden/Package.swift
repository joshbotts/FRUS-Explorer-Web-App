// swift-tools-version: 6.2
// tools/mac-golden: writes the parity harness's golden files by running the Mac app's own code.
// Mac only, and debug builds only, since the tool imports the app module with @testable. The
// owner runs it through scripts/make-golden.
//
// The FRUSExplorer target is the whole app module, compiled from the submodule unmodified
// (CLAUDE.md, rule 4). Its folder holds a stub for the asset symbol Xcode generates, and
// `upstream`, a relative symlink to the submodule, which exists at every pin. The target compiles
// the Swift files of the app's directories the submodule has (`appDirectories`) and excludes
// everything else in it. Nothing from the submodule is copied. `upstream` here is a relative
// symlink to the submodule too.

import Foundation
import PackageDescription

/// The submodule directories the macOS app target compiles (`project.yml`). The same list as
/// ParityFormat's `UpstreamDigest.directories`. FRUSCoreKit arrives with upstream's FRUSCoreKit,
/// part 1, which moves the TEI pipeline and the citation code out of FRUSExplorer and has both app
/// targets compile it. It is listed before the pin reaches it: the target compiles only the listed
/// directories the submodule has, so the same manifest builds the app module at either pin.
let appDirectories = [
    "FRUSCoreKit", "FRUSExplorer", "FTS5Store", "SemanticVectorsKit", "SourceNoteKit", "TEIHeaderKit", "WordCloudKit",
]

/// The submodule's root.
let upstream = ((Context.packageDirectory + "/upstream") as NSString).resolvingSymlinksInPath

/// The listed directories the submodule has at the pin.
let compiledDirectories = appDirectories.filter { directory in
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: "\(upstream)/\(directory)", isDirectory: &isDirectory)
        && isDirectory.boolValue
}

/// What the target leaves out of the submodule, by its path from the target's folder: every entry
/// at the submodule's top level other than the compiled directories, and everything in those that
/// is not Swift: the app's bundle resources, plists, entitlements and the like. The tool does not
/// need them, and listing them keeps SwiftPM from warning about unhandled files. An asset catalog
/// counts as one item. SwiftPM caches this manifest's result, so after a pin move adds or removes
/// such a file, build with `--manifest-cache none`, as scripts/make-golden does.
func excludedFiles() -> [String] {
    let manager = FileManager.default
    let topLevel = (try? manager.contentsOfDirectory(atPath: upstream)) ?? []
    var excluded = topLevel.filter { !compiledDirectories.contains($0) }.map { "upstream/\($0)" }
    for directory in compiledDirectories {
        guard let walk = manager.enumerator(atPath: "\(upstream)/\(directory)") else { continue }
        while let path = walk.nextObject() as? String {
            let isDirectory = (walk.fileAttributes?[.type] as? FileAttributeType) == .typeDirectory
            if isDirectory, path.hasSuffix(".xcassets") {
                excluded.append("upstream/\(directory)/\(path)")
                walk.skipDescendants()
            } else if !isDirectory, !path.hasSuffix(".swift") {
                excluded.append("upstream/\(directory)/\(path)")
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
            exclude: excludedFiles(),
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
