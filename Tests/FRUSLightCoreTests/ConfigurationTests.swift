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
