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

    @Test func userDataIsOnUnlessTurnedOff() throws {
        #expect(try ServerConfiguration.fromEnvironment([:]).userData)
        #expect(try ServerConfiguration.fromEnvironment(["FRUS_USER_DATA": "on"]).userData)
        #expect(try ServerConfiguration.fromEnvironment(["FRUS_USER_DATA": "OFF"]).userData == false)
        #expect(throws: ConfigurationError.self) { try ServerConfiguration.fromEnvironment(["FRUS_USER_DATA": "no"]) }
    }

    /// The address a write must come from and be sent to (S14c): FRUS_PUBLIC_URL's scheme, host
    /// and port, with the three names of this machine one address.
    @Test func thePublicAddressIsWhatAWritesHostAndOriginMustName() throws {
        let local = ServerConfiguration().publicAddress
        #expect(local == PublicAddress("http://localhost:8080") && local.description == "http://localhost:8080")
        for host in ["localhost:8080", "LOCALHOST:8080", "127.0.0.1:8080", "[::1]:8080", "localhost"] {
            #expect(local.allows(host: host), "\(host)")
        }
        for host in ["localhost:9999", "attacker.example:8080", "attacker.example", "", "user@localhost:8080", "localhost:8080/x",
                     "[::1", "localhost:", "localhost:+8080", "127.0.0.2:8080"] {
            #expect(!local.allows(host: host), "\(host)")
        }
        for origin in ["http://localhost:8080", "http://127.0.0.1:8080", "http://[::1]:8080"] {
            #expect(local.allows(origin: origin), "\(origin)")
        }
        for origin in ["null", "", "http://localhost", "https://localhost:8080", "http://localhost:8080/", "http://localhost:8081",
                       "http://attacker.example:8080", "file://", "http://localhost:8080?x"] {
            #expect(!local.allows(origin: origin), "\(origin)")
        }

        let proxied = try ServerConfiguration.fromEnvironment(["FRUS_PUBLIC_URL": "https://Example.org/frus-explorer/"]).publicAddress
        #expect(proxied.scheme == "https" && proxied.host == "example.org" && proxied.port == 443)
        #expect(proxied.description == "https://example.org")
        #expect(proxied.allows(host: "example.org") && proxied.allows(host: "example.org:443") && !proxied.allows(host: "localhost"))
        #expect(proxied.allows(origin: "https://example.org") && proxied.allows(origin: "https://example.org:443"))
        #expect(!proxied.allows(origin: "http://example.org") && !proxied.allows(origin: "https://frus.example.org"))
        #expect(PublicAddress("http://[::1]:8080")?.description == "http://[::1]:8080")
        #expect(PublicAddress("ftp://example.org") == nil && PublicAddress("http://") == nil)
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
