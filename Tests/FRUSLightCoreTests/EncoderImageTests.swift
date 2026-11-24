// The encoder in the image (PLAN's S27b), held to the pinned app: docker/Dockerfile's llama.cpp commit to the
// one the app's Scripts/build-llama-xcframework.sh names, the engine its corpus was embedded through, so that a
// pin move that moves one moves both; and its model to the file the app's fetcher names, the length the app
// publishes and the SHA-256 the bundled index's provenance names, so that a build with another file fails.
// With them, the image's NOTICE, which names the model's file and digest; the server's query limit, prompt
// and idle window, the app's; and the app's fixture of its 25 judged queries, check 9's encoder half, made by
// the same engine and model.

import FRUSLightTestSupport
import Foundation
import Testing

@testable import FRUSLightCore

@Suite struct EncoderImageTests {
    static let app = RepositoryFiles.root.appendingPathComponent("upstream/FRUS-Explorer", isDirectory: true)

    static func read(_ path: String, in folder: URL = RepositoryFiles.root) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(path), encoding: .utf8)
    }

    /// The value of the Dockerfile's `ARG name=value` before its first stage.
    static func dockerArgument(_ name: String) throws -> String {
        let dockerfile = try read("docker/Dockerfile")
        let lines = dockerfile.split(separator: "\n").map(String.init).filter { $0.hasPrefix("ARG \(name)=") }
        #expect(lines.count == 1, "one ARG \(name)= in docker/Dockerfile")
        return try #require(lines.first).dropFirst("ARG \(name)=".count).trimmingCharacters(in: .whitespaces)
    }

    @Test func theEncodersCommitIsTheOneTheAppPins() throws {
        let script = try Self.read("Scripts/build-llama-xcframework.sh", in: Self.app)
        let pinned = try #require(script.firstMatch(of: /\nLLAMA_COMMIT=([0-9a-f]{40})\n/)?.1)
        #expect(try Self.dockerArgument("LLAMA_COMMIT") == String(pinned))
    }

    @Test func theModelIsTheAppsFileAtTheBundledDigest() throws {
        let bundled = try SearchModel.bundled(in: RepositoryFiles.resources)
        #expect(bundled.name == "embeddinggemma-2-Q8_0" && bundled.dimensions == 768)
        #expect(try Self.dockerArgument("MODEL_SHA256") == bundled.sha256)
        #expect(try Self.dockerArgument("MODEL_BYTES") == String(SearchModel.publishedBytes))

        // The app's store and fetcher, as its source declares them.
        let store = try Self.read("FRUSExplorer/Semantic/SemanticModelStore.swift", in: Self.app)
        let bytes = try #require(store.firstMatch(of: /static let publishedBytes = ([0-9_]+)\n/)?.1)
        #expect(Int(bytes.replacingOccurrences(of: "_", with: "")) == SearchModel.publishedBytes)
        #expect(store.contains(#"static let fileName = "\#(SearchModel.fileName)""#))
        let fetcher = try Self.read("FRUSExplorer/Semantic/SemanticModelFetcher.swift", in: Self.app)
        let url = try #require(fetcher.firstMatch(of: /static let defaultModelURL = URL\(\s*string: "([^"]+)"\)!/)?.1)
        #expect(try Self.dockerArgument("MODEL_URL") == String(url) && url.hasSuffix("/" + SearchModel.fileName))
        #expect(ServerConfiguration.imageEncoderModel.lastPathComponent == SearchModel.fileName)
    }

    /// The model stage holds the file to both and fixes its time and mode, and the runtime copies it in a
    /// layer of its own; the encoder stage builds llama-server at the commit without the processor's own tuning.
    @Test func theDockerfileHoldsTheModelAndBuildsTheEncoderAsThePlanSays() throws {
        let dockerfile = try Self.read("docker/Dockerfile")
        #expect(dockerfile.contains(#"if [ "$bytes" != "$MODEL_BYTES" ]; then"#))
        #expect(dockerfile.contains(#"echo "$MODEL_SHA256  $folder/$name" | sha256sum --check --strict"#))
        #expect(dockerfile.contains("--location --max-redirs 1 --proto '=https' --proto-redir '=https'"))
        #expect(dockerfile.contains("touch --no-dereference --date='2026-10-15 00:00:00 UTC'"))
        #expect(dockerfile.contains("COPY --link --from=model /out/ /"))
        #expect(dockerfile.contains("-DGGML_NATIVE=OFF") && dockerfile.contains("git fetch -q --depth 1 origin \"${LLAMA_COMMIT}\""))
        #expect(dockerfile.contains("COPY --from=encoder /out/llama-server /usr/local/bin/llama-server"))
        #expect(dockerfile.contains("libgomp1"), "the runtime holds what llama-server links")
        #expect(ServerConfiguration.imageEncoderBinary.path == "/usr/local/bin/llama-server")
    }

    @Test func theImagesNoticeNamesTheModel() throws {
        let notice = try Self.read("NOTICE")
        let bundled = try SearchModel.bundled(in: RepositoryFiles.resources)
        #expect(notice.contains(SearchModel.fileName) && notice.contains("309,855,456"))
        #expect(notice.replacingOccurrences(of: "\n", with: "").contains(bundled.sha256))
        #expect(notice.contains("Apache License, Version 2.0") && notice.contains("Copyright (c) 2023-2026 The ggml authors"))
        // The app's own notice names the same file and digest.
        let appNotice = try Self.read("NOTICE", in: Self.app)
        #expect(appNotice.replacingOccurrences(of: "\n", with: "").contains(bundled.sha256))
        #expect(try Self.read("docker/Dockerfile").contains("COPY LICENSE NOTICE /usr/share/doc/frus-light/"))
    }

    /// The server's limit, prompt and idle window are the app's.
    @Test func theQueryLimitPromptAndIdleWindowAreTheApps() throws {
        let encoder = try Self.read("FRUSExplorer/Semantic/SemanticQueryEncoder.swift", in: Self.app)
        #expect(encoder.contains("static let maxTokens = \(SearchModel.maxTokens)\n"))
        let searcher = try Self.read("FRUSExplorer/Semantic/SemanticQuerySearcher.swift", in: Self.app)
        #expect(searcher.contains("static let encoderIdleSeconds: UInt64 = \(EncoderSettings.appIdleTimeout.components.seconds)\n"))
        let index = try JSONSerialization.jsonObject(with: Data(contentsOf: RepositoryFiles.resources.appendingPathComponent(SearchModel.indexFile)))
        let provenance = try #require((index as? [String: Any])?["provenance"] as? [String: Any])
        #expect(provenance["queryPrefix"] as? String == SearchModel.queryPrefix)
    }

    /// The app's fixture of its 25 judged queries, which `frus-parity embed` holds the server's vectors to, was
    /// made by the engine at the commit and the model the image holds.
    @Test func theAppsQueryFixtureIsOfThisEngineAndModel() throws {
        let fixture = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.app.appendingPathComponent(
            "FRUSExplorerTests/Fixtures/query-parity-fixture-embeddinggemma-2.json"))) as? [String: Any]
        let queries = try #require(fixture?["queries"] as? [[String: Any]])
        #expect(queries.count == 25 && queries.allSatisfy { ($0["vector"] as? [Double])?.count == 768 })
        #expect(fixture?["queryPrefix"] as? String == SearchModel.queryPrefix)
        #expect(fixture?["ggufSHA256"] as? String == (try SearchModel.bundled(in: RepositoryFiles.resources)).sha256)
        let engine = try #require(fixture?["referenceEngine"] as? String)
        #expect(engine.contains("llama.cpp \(try Self.dockerArgument("LLAMA_COMMIT").prefix(7))"))
    }
}
