// swift-tools-version: 6.0
// FRUS Explorer Light: the server, plus Linux builds of the Mac app's shared kits.
//
// The shared kits are compiled from the pinned FRUS-Explorer submodule, never copied
// (CLAUDE.md, rule 4). Each kit keeps the settings upstream's Package.swift gives it.
// Build and test through scripts/swift, which runs this package in swift:6.4-noble.

import PackageDescription

let upstream = "upstream/FRUS-Explorer"
let swift6: [SwiftSetting] = [.swiftLanguageMode(.v6)]

let package = Package(
    name: "FRUSLight",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
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

        // FTS5Types.swift alone, so the FTS5 check builds the index with the app's own DDL.
        // It imports only Foundation, so it needs none of FTS5Store's sqlite3 linking. The rest
        // of FTS5Store needs Linux guards upstream first (session 1). If a pin move changes the
        // directory's files, SwiftPM warns ("unhandled" or "Invalid Exclude"): update the list.
        .target(
            name: "FTS5Schema",
            path: "\(upstream)/FTS5Store",
            exclude: [
                "ExactWordMatcher.swift", "FTS5Connection.swift", "FTS5Errors.swift",
                "FTS5InlineQueryParser.swift", "FTS5Query.swift", "FTS5Store.swift",
                "FTS5Tokenizer.swift", "FTS5Vocabulary.swift",
            ],
            sources: ["FTS5Types.swift"],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "FTS5CheckTests",
            dependencies: ["CSQLite", "FTS5Schema"],
            path: "Tests/FTS5CheckTests",
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
            dependencies: ["FRUSLightCore", "FRUSLightTestSupport", "FTS5Schema"],
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
    ]
)
