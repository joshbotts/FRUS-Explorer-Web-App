// swift-tools-version: 6.0
// FRUS Explorer Light: the server, plus Linux builds of the Mac app's shared kits.
//
// The shared kits are compiled from the pinned FRUS-Explorer submodule, never copied
// (CLAUDE.md, rule 4). Each kit keeps the settings upstream's Package.swift gives it. Seven kits so
// far, each with upstream's tests: SourceNoteKit, CrossRefKit and GeneratorKit since session 0;
// TEIHeaderKit, SemanticVectorsKit and FTS5Store since session 1's Linux guards, with
// ManifestGeneratorCore, whose tests hold TEIHeaderKit's; and FRUSCoreKit, part 1 since session 3
// and part 2 since session 6's pin move. The server links FRUSCoreKit and FTS5Store since session 8,
// through FRUSLightAPI.
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
        // The rich-text codec (S15d), for tools/mac-golden, which has the app read what it writes.
        .library(name: "FRUSRichText", targets: ["FRUSRichText"]),
        // The parity harness's command line: swift run frus-parity summarize | compare-summary | compare-results | parse | render | index | check-golden.
        .executable(name: "frus-parity", targets: ["FRUSParityTool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        // NIOCore for the channel handler that notices a client closing its connection; Hummingbird
        // already resolves it.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.81.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        // SHA-256 for the parity harness. Hummingbird already resolves 5.x; on macOS it wraps CryptoKit.
        .package(url: "https://github.com/apple/swift-crypto.git", "3.12.3"..<"6.0.0"),
        // The PostgreSQL user store (S14d), SPEC's option B: PostgresNIO speaks PostgreSQL's protocol in
        // Swift, so the image gains no client tools. 1.33.2 is 1.33.1 with swift-crypto 5 allowed. NIOSSL,
        // which it already resolves, makes the TLS context a connection asks for.
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.33.2"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.25.0"),
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
        // conversion and HTML serializer, and the citation formatter, parser and models; part 2
        // (session 6, upstream #1573 and #1574): the indexing pipeline, the search service and
        // Citation Lookup's matcher; and since session 8b's pin move (upstream #1575), the read-only
        // open of an index, a host's figure addresses and the reader's page. Upstream's Package.swift
        // gives it SourceNoteKit and FTS5Store,
        // and links sqlite3, here for macOS only as for FTS5Store; its CryptoKit and SQLite3 guards
        // need swift-crypto's Crypto and CSQLite, declared here for Linux only.
        .target(
            name: "FRUSCoreKit",
            dependencies: [
                "SourceNoteKit", "FTS5Store",
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
                .target(name: "CSQLite", condition: .when(platforms: [.linux])),
            ],
            path: "\(upstream)/FRUSCoreKit",
            swiftSettings: swift6,
            linkerSettings: [.linkedLibrary("sqlite3", .when(platforms: [.macOS]))]
        ),
        // The app's own suites for the kit, which live in its test folder: under SwiftPM they import
        // FRUSCoreKit, and FTS5Store, SourceNoteKit and SQLite behind `canImport`, never the app;
        // whatever needs the app is inside `#if !SWIFT_PACKAGE`. Since upstream #1575 two of them hash
        // with CryptoKit, swift-crypto's Crypto on Linux. They read the app's data files and manifest
        // from the submodule's FRUSExplorer/Resources by #filePath.
        .testTarget(
            name: "FRUSCoreKitTests",
            dependencies: [
                "FRUSCoreKit", "FTS5Store", "SourceNoteKit",
                .target(name: "CSQLite", condition: .when(platforms: [.linux])),
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            ],
            path: "\(upstream)/FRUSExplorerTests/FRUSCoreKit",
            swiftSettings: swift6
        ),

        // Web-only logic: configuration, Import mode, readiness, and the five v1 interfaces. It
        // links no shared kit: SQLite; swift-crypto, for SHA-1 in the name-based ids of what an import
        // takes from a research database (S16e), whose strip the kit gives it, and SHA-256 for the
        // user store's backups (S14b); and since S14d PostgresNIO, for the user store's PostgreSQL
        // implementation, with NIO's event loops and TLS beneath it.
        .target(
            name: "FRUSLightCore",
            dependencies: [
                "CSQLite",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/FRUSLightCore",
            swiftSettings: swift6
        ),
        // The rich-text codec (S15d): RTF to the runs the app reads from it, and runs to RTF, held to
        // the app's reading by the golden spans. Foundation and the kit's span rules only (since S17c's
        // pin move, FRUS-Explorer#1807's `CollectionProse.hex`), so tools/mac-golden links it too.
        .target(
            name: "FRUSRichText",
            dependencies: ["FRUSCoreKit"],
            path: "Sources/FRUSRichText",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "FRUSRichTextTests",
            dependencies: ["FRUSRichText"],
            path: "Tests/FRUSRichTextTests",
            swiftSettings: swift6
        ),
        // The HTTP application (session 8): the routes, problem details, the app's data files, the
        // catalogue, the reader and the search request, over FRUSLightCore and the shared kits. Since
        // S12c it watches each connection for its client closing it, through HummingbirdCore and NIOCore.
        .target(
            name: "FRUSLightAPI",
            dependencies: [
                "FRUSLightCore", "FRUSCoreKit", "FTS5Store", "FRUSRichText",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdCore", package: "hummingbird"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/FRUSLightAPI",
            swiftSettings: swift6
        ),
        // The process: its command line, configuration from the environment, and the health check.
        .executableTarget(
            name: "FRUSLightServer",
            dependencies: [
                "FRUSLightAPI", "FRUSLightCore",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/FRUSLightServer",
            swiftSettings: swift6
        ),

        // The parity harness (checks 2-4): golden-file formats, shared with tools/mac-golden. Since
        // S17c's pin move it splits prose into paragraphs with the kit's `CollectionProse.append`.
        .target(
            name: "ParityFormat",
            dependencies: ["FRUSCoreKit", .product(name: "Crypto", package: "swift-crypto")],
            path: "Tests/ParityFormat",
            swiftSettings: swift6
        ),
        // The harness itself: the index summary (check 2), the parse and results comparisons
        // (check 3), the render comparison (check 4), the golden files' validation, and the
        // indexing metrics; since S16c, the import of a Mac JSON export it is given, through the
        // server's own mapping, read back from the store.
        .target(
            name: "FRUSParity",
            dependencies: [
                "ParityFormat", "FTS5Store", "FRUSCoreKit", "CSQLite", "FRUSLightCore", "FRUSRichText", "FRUSLightAPI",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Tests/FRUSParity",
            swiftSettings: swift6
        ),
        .executableTarget(
            name: "FRUSParityTool",
            dependencies: ["FRUSParity", "ParityFormat", "FRUSLightAPI"],
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
                "FRUSLightAPI",
                "FRUSLightCore",
                "FRUSLightTestSupport",
                // For the search statements' test hook (upstream #1698), which a test holds a search at.
                "FRUSCoreKit",
                // For a note's runs and RTF (S15d), which the note routes' tests write and read.
                "FRUSRichText",
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Tests/FRUSLightServerTests",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "FRUSParityTests",
            dependencies: [
                "FRUSParity", "ParityFormat", "FTS5Store", "FRUSCoreKit", "FRUSLightTestSupport", "FRUSLightCore", "CSQLite",
                "FRUSLightAPI", "FRUSRichText", .product(name: "HummingbirdTesting", package: "hummingbird"),
            ],
            path: "Tests/FRUSParityTests",
            swiftSettings: swift6
        ),
    ]
)
