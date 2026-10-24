// FRUS_* environment variables.

import FRUSLightCore
import Foundation
import Testing

@Suite struct ConfigurationTests {
    @Test func defaultsServeImportModeOnLocalhost() throws {
        let config = try ServerConfiguration.fromEnvironment([:])
        #expect(config == ServerConfiguration())
        #expect(config.mode == .import && config.auth == .none)
        #expect(config.dataDirectory.path == "/data")
        #expect(config.host == "127.0.0.1" && config.port == 8080)
        #expect(config.resourcesDirectory.path == "/usr/share/frus-light/resources", "where the image puts them")
    }

    @Test func readsEveryVariable() throws {
        let config = try ServerConfiguration.fromEnvironment([
            "FRUS_MODE": "import", "FRUS_AUTH": "none", "FRUS_DATA_DIR": "/srv/frus",
            "FRUS_PUBLIC_URL": "https://frus.example.org", "FRUS_PDF_URL": "http://pdf:3000",
            "FRUS_OFFLINE": "true", "FRUS_HOST": "0.0.0.0", "FRUS_PORT": "9090", "FRUS_IMPORT_POLL_SECONDS": "0.5",
            "FRUS_RESOURCES_DIR": "/src/upstream/FRUS-Explorer/FRUSExplorer/Resources",
        ])
        #expect(config.dataDirectory.path == "/srv/frus")
        #expect(config.publicURL == "https://frus.example.org")
        #expect(config.pdfURL == "http://pdf:3000")
        #expect(config.offline && config.host == "0.0.0.0" && config.port == 9090)
        #expect(config.importPollInterval == .milliseconds(500))
        #expect(config.resourcesDirectory.path == "/src/upstream/FRUS-Explorer/FRUSExplorer/Resources")
        #expect(config.basePath == .root)
    }

    /// A public URL that ends in a path is served under it (S14f), with or without its last slash;
    /// one with no path, or `/`, at the root.
    @Test func aPublicURLWithAPathIsTheBasePath() throws {
        for (url, path) in [
            ("http://localhost:8080", "/"), ("https://example.org/", "/"),
            ("https://example.org/frus-explorer/", "/frus-explorer/"), ("https://example.org/frus-explorer", "/frus-explorer/"),
            ("http://localhost:8080/tools/frus_1.0~x/", "/tools/frus_1.0~x/"),
        ] {
            let config = try ServerConfiguration.fromEnvironment(["FRUS_PUBLIC_URL": url])
            #expect(config.publicURL == url && config.basePath.path == path, "\(url)")
        }
        #expect(ServerConfiguration().basePath.isRoot)
        let base = try #require(BasePath("/frus-explorer/"))
        #expect(base.prefixing("/api/v1/status") == "/frus-explorer/api/v1/status" && base.prefixing("/") == "/frus-explorer/")
        #expect(BasePath.root.prefixing("/reader/host.js") == "/reader/host.js")
        #expect(base.stripping("/frus-explorer/search?keywords=x") == "/search?keywords=x" && base.stripping("/frus-explorer/") == "/")
        #expect(base.stripping("/frus-explorer") == nil && base.stripping("/frus-explorers/") == nil && base.stripping("/search") == nil)
        #expect(BasePath.root.stripping("/search?keywords=x") == "/search?keywords=x")
    }

    /// A path a proxy could forward in more than one spelling, or that would need escaping where the
    /// server writes it, is refused, as is a query or a fragment.
    @Test func refusesAPathItCouldNotWriteAsItIs() {
        for url in [
            "https://example.org/frus%20explorer/", "https://example.org/a//b/", "https://example.org/a/../b/",
            "https://example.org/./", "https://example.org//", "https://example.org/a\"b/", "https://example.org/?x=1",
            "https://example.org/frus-explorer/#top",
        ] {
            #expect(throws: ConfigurationError.self, "\(url)") { try ServerConfiguration.fromEnvironment(["FRUS_PUBLIC_URL": url]) }
        }
        for path in ["frus-explorer/", "/a b/", "/%41/", "/a/./"] { #expect(BasePath(path) == nil, "\(path)") }
    }

    @Test func reportsEveryProblemAtOnce() {
        #expect {
            _ = try ServerConfiguration.fromEnvironment([
                "FRUS_MODE": "standalone", "FRUS_AUTH": "local", "FRUS_PORT": "80000",
                "FRUS_OFFLINE": "maybe", "FRUS_PUBLIC_URL": "localhost:8080",
            ])
        } throws: { error in
            guard let error = error as? ConfigurationError else { return false }
            return error.problems.count == 5
                && error.problems.contains { $0.contains("standalone arrives in phase 3") }
                && error.problems.contains { $0.contains("FRUS_AUTH=local") }
        }
    }
}
