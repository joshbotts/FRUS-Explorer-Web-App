// swift-tools-version: 6.0
// FRUS Explorer Light: the server, plus Linux builds of the Mac app's shared kits.
//
// The shared kits are compiled from the pinned FRUS-Explorer submodule, never copied
// (CLAUDE.md, rule 4). Each kit keeps the settings upstream's Package.swift gives it. Seven kits so
// far, each with upstream's tests: SourceNoteKit, CrossRefKit and GeneratorKit since session 0;
// TEIHeaderKit, SemanticVectorsKit and FTS5Store since session 1's Linux guards, with
// ManifestGeneratorCore, whose tests hold TEIHeaderKit's; and FRUSCoreKit, part 1, since session 3.
// The server depends on none of them yet.
// Build and test through scripts/swift, which runs this package in swift:6.4-noble.

import PackageDescription

let upstream = "upstream/FRUS-Explorer"
let swift6: [SwiftSetting] = [.swiftLanguageMode(.v6)]

let package = Package(
    name: "FRUSLight",
    platforms: [.macOS(.v15)],
    products: [
        // The golden-file formats, for tools/mac-golden, the Mac-only tool that writes them.
        .library(name: "ParityFormat", targets: ["ParityFormat"]),
        // The parity harness's command line: swift run frus-parity summarize | compare-summary | parse | check-golden.
        .executable(name: "frus-parity", targets: ["FRUSParityTool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        // SHA-256 for the parity harness. Hummingbird already resolves 5.x; on macOS it wraps CryptoKit.
        .package(url: "https://github.com/apple/swift-crypto.git", "3.12.3"..<"6.0.0"),
    ],
    targets: [
        // SQLite with FTS5: the system library. On Linux its header comes from libsqlite3-dev,
        // which scripts/swift and ci.yml install; on macOS, from the SDK. Neither needs pkg-config.
        .systemLibrary(name: "CSQLite", path: "Sources/CSQLite"),

        // Shared kits, from the submodule's own directories.
        .target(
            name: "SourceNoteKit",
            path: "\(upstream)/SourceNoteKit",
            exclude: ["eval-baseline.txt", "eval-report.txt"],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "SourceNoteKitTests",
            dependencies: ["SourceNoteKit"],
            path: "\(upstream)/SourceNoteKitTests",
            swiftSettings: swift6
        ),
        .target(
            name: "CrossRefKit",
            path: "\(upstream)/CrossRefKit",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "CrossRefKitTests",
            dependencies: ["CrossRefKit"],
            path: "\(upstream)/CrossRefKitTests",
            swiftSettings: swift6
        ),
        .target(
            name: "GeneratorKit",
            path: "\(upstream)/GeneratorKit",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "GeneratorKitTests",
            dependencies: ["GeneratorKit"],
            path: "\(upstream)/GeneratorKitTests",
            swiftSettings: swift6
        ),

        // The session 1 kits. Upstream's Package.swift declares no dependencies for them, so the two
        // their Linux guards need are declared here, for Linux only: CSQLite where the SDK's SQLite3
        // module is missing, and swift-crypto's Crypto where CryptoKit is.
        .target(
            name: "TEIHeaderKit",
            path: "\(upstream)/TEIHeaderKit",
            swiftSettings: swift6
        ),
        // TEIHeaderKit has no test target upstream: its tests live in ManifestGeneratorTests,
        // which needs ManifestGeneratorCore.
        .target(
            name: "ManifestGeneratorCore",
            dependencies: ["TEIHeaderKit"],
            path: "\(upstream)/ManifestGeneratorCore",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "ManifestGeneratorTests",
            dependencies: ["ManifestGeneratorCore", "TEIHeaderKit"],
            path: "\(upstream)/ManifestGeneratorTests",
            swiftSettings: swift6
        ),
        .target(
            name: "SemanticVectorsKit",
            dependencies: [.product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))],
            path: "\(upstream)/SemanticVectorsKit",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "SemanticVectorsKitTests",
            dependencies: ["SemanticVectorsKit"],
            path: "\(upstream)/SemanticVectorsKitTests",
            swiftSettings: swift6
        ),
        // The whole of FTS5Store. It replaces session 0's FTS5Schema target, which compiled only its
        // pure-Swift files: two targets cannot compile the same files, and upstream's tests import
        // the module as FTS5Store. sqlite3 is linked from one place on each platform: on Linux by
        // CSQLite's module map, and on macOS, whose SDK SQLite3 module links nothing, by the linker
        // setting upstream gives the kit, here for macOS only.
        .target(
            name: "FTS5Store",
            dependencies: [.target(name: "CSQLite", condition: .when(platforms: [.linux]))],
            path: "\(upstream)/FTS5Store",
            swiftSettings: swift6,
            linkerSettings: [.linkedLibrary("sqlite3", .when(platforms: [.macOS]))]
        ),
        // On Linux one test is skipped by name: swift-corelibs-foundation keeps no backup attribute.
        // ci.yml allows that skip alone (SPEC, check 1).
        .testTarget(
            name: "FTS5StoreTests",
            dependencies: ["FTS5Store", .target(name: "CSQLite", condition: .when(platforms: [.linux]))],
            path: "\(upstream)/FTS5StoreTests",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "FTS5CheckTests",
            dependencies: ["CSQLite", "FTS5Store"],
            path: "Tests/FTS5CheckTests",
            swiftSettings: swift6
        ),

        // FRUSCoreKit, part 1 (session 3, upstream #1569): the TEI parser, the AST, the render
        // conversion and HTML serializer, and the citation formatter, parser and models. Upstream's
        // Package.swift gives it SourceNoteKit; its CryptoKit guard needs swift-crypto's Crypto,
        // declared here for Linux only, as SemanticVectorsKit's is.
        .target(
            name: "FRUSCoreKit",
            dependencies: [
                "SourceNoteKit",
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            ],
            path: "\(upstream)/FRUSCoreKit",
            swiftSettings: swift6
        ),
        // The app's own suites for the kit, which live in its test folder: under SwiftPM each
        // imports FRUSCoreKit alone, and whatever needs the app is inside `#if !SWIFT_PACKAGE`.
        .testTarget(
            name: "FRUSCoreKitTests",
            dependencies: ["FRUSCoreKit"],
            path: "\(upstream)/FRUSExplorerTests/FRUSCoreKit",
            swiftSettings: swift6
        ),

        // Web-only logic: configuration, Import mode, readiness, and the five v1 interfaces.
        .target(
            name: "FRUSLightCore",
            dependencies: ["CSQLite"],
            path: "Sources/FRUSLightCore",
            swiftSettings: swift6
        ),
        .executableTarget(
            name: "FRUSLightServer",
            dependencies: [
                "FRUSLightCore",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/FRUSLightServer",
            swiftSettings: swift6
        ),

        // The parity harness (checks 2-4): golden-file formats, shared with tools/mac-golden.
        .target(
            name: "ParityFormat",
            dependencies: [.product(name: "Crypto", package: "swift-crypto")],
            path: "Tests/ParityFormat",
            swiftSettings: swift6
        ),
        // The harness itself: the index summary (check 2), the parse comparison (check 3) and the
        // golden files' validation. Crypto stays here, out of FRUSLightCore and the server.
        .target(
            name: "FRUSParity",
            dependencies: [
                "ParityFormat", "FTS5Store", "CSQLite", "FRUSLightCore",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Tests/FRUSParity",
            swiftSettings: swift6
        ),
        .executableTarget(
            name: "FRUSParityTool",
            dependencies: ["FRUSParity", "ParityFormat"],
            path: "Tests/FRUSParityTool",
            swiftSettings: swift6
        ),

        // Builds synthetic Mac exports from the schema of a real one, for the tests below.
        .target(
            name: "FRUSLightTestSupport",
            dependencies: ["FRUSLightCore", "CSQLite"],
            path: "Tests/FRUSLightTestSupport",
            resources: [.copy("Fixtures")],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "FRUSLightCoreTests",
            dependencies: ["FRUSLightCore", "FRUSLightTestSupport", "FTS5Store"],
            path: "Tests/FRUSLightCoreTests",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "FRUSLightServerTests",
            dependencies: [
                "FRUSLightServer",
                "FRUSLightCore",
                "FRUSLightTestSupport",
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Tests/FRUSLightServerTests",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "FRUSParityTests",
            dependencies: ["FRUSParity", "ParityFormat", "FTS5Store", "FRUSLightTestSupport", "FRUSLightCore", "CSQLite"],
            path: "Tests/FRUSParityTests",
            swiftSettings: swift6
        ),
    ]
)
