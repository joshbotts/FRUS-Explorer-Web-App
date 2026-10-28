// FRUS_* environment variables.

import FRUSLightCore
import FRUSLightTestSupport
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

    /// The daily backup's hour, and the folder each backup is copied to (S14b).
    @Test func theBackupsHourAndSecondFolder() throws {
        let defaults = try ServerConfiguration.fromEnvironment([:])
        #expect(defaults.backupHour == 3 && defaults.backupCopyDirectory == nil)
        let config = try ServerConfiguration.fromEnvironment(["FRUS_BACKUP_HOUR": "0", "FRUS_BACKUP_COPY_DIR": "/backups"])
        #expect(config.backupHour == 0 && config.backupCopyDirectory?.path == "/backups")
        #expect(try ServerConfiguration.fromEnvironment(["FRUS_BACKUP_HOUR": "23"]).backupHour == 23)
        for hour in ["24", "-1", "3:00", "three"] {
            #expect(throws: ConfigurationError.self, "\(hour)") { try ServerConfiguration.fromEnvironment(["FRUS_BACKUP_HOUR": hour]) }
        }
    }

    @Test func userDataIsOnUnlessTurnedOff() throws {
        #expect(try ServerConfiguration.fromEnvironment([:]).userData)
        #expect(try ServerConfiguration.fromEnvironment(["FRUS_USER_DATA": "on"]).userData)
        #expect(try ServerConfiguration.fromEnvironment(["FRUS_USER_DATA": "OFF"]).userData == false)
        #expect(throws: ConfigurationError.self) { try ServerConfiguration.fromEnvironment(["FRUS_USER_DATA": "no"]) }
    }

    /// The user store is app.db unless FRUS_USER_STORE names a PostgreSQL database (S14d), whose
    /// password the URL or FRUS_POSTGRES_PASSWORD_FILE gives, never both; a problem with either never
    /// repeats the URL, which may hold the password.
    @Test func theUserStoreIsAppDBUnlessAPostgreSQLURLIsGiven() throws {
        #expect(try ServerConfiguration.fromEnvironment([:]).userStore == .sqlite)
        #expect(try ServerConfiguration.fromEnvironment(["FRUS_USER_STORE": "sqlite"]).userStore == .sqlite)
        let url = "postgres://frus:s%40cret@db.example.org:6543/research?sslmode=require"
        let given = try ServerConfiguration.fromEnvironment(["FRUS_USER_STORE": url]).userStore
        #expect(given == .postgreSQL(PostgreSQLConfiguration(host: "db.example.org", port: 6543, username: "frus", password: "s@cret",
                                                             database: "research", tls: .require)))

        let directory = try TemporaryDirectory()
        let file = directory.url.appendingPathComponent("postgres-password")
        try Data("from a file\n".utf8).write(to: file)
        let secret = try ServerConfiguration.fromEnvironment([
            "FRUS_USER_STORE": "postgresql://frus@db.example.org/research", "FRUS_POSTGRES_PASSWORD_FILE": file.path,
        ]).userStore
        #expect(secret == .postgreSQL(PostgreSQLConfiguration(host: "db.example.org", username: "frus", password: "from a file",
                                                              database: "research")), "verify-full unless the URL says otherwise")

        for environment in [
            ["FRUS_USER_STORE": url, "FRUS_POSTGRES_PASSWORD_FILE": file.path],
            ["FRUS_POSTGRES_PASSWORD_FILE": file.path],
            ["FRUS_USER_STORE": "postgres://frus@db.example.org/research", "FRUS_POSTGRES_PASSWORD_FILE": "/no/such/file"],
            ["FRUS_USER_STORE": "postgres://frus:s%40cret@db.example.org/research?sslmode=prefer"],
            ["FRUS_USER_STORE": "mysql://frus:s%40cret@db.example.org/research"],
        ] {
            #expect(throws: ConfigurationError.self, "\(environment)") { try ServerConfiguration.fromEnvironment(environment) }
            do {
                _ = try ServerConfiguration.fromEnvironment(environment)
            } catch let error as ConfigurationError {
                #expect(!error.description.contains("s%40cret") && !error.description.contains("s@cret"), "\(error)")
            }
        }
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

    /// Sign-in through a proxy (S14e): its header, its proxies and its admins, each read as listed.
    @Test func headerModeReadsItsHeaderProxiesAndAdmins() throws {
        let config = try ServerConfiguration.fromEnvironment([
            "FRUS_AUTH": "header", "FRUS_TRUSTED_PROXIES": "172.18.0.5, 10.0.0.0/8 fd00::/8,::1",
            "FRUS_ADMIN_USERS": " alice@example.org , bob ,", "FRUS_AUTH_HEADER": "X-Auth-Request-Email",
        ])
        #expect(config.auth == .header && config.authHeader == "X-Auth-Request-Email")
        #expect(config.trustedProxies.map(\.description) == ["172.18.0.5", "10.0.0.0/8", "fd00::/8", "::1"])
        #expect(config.adminUsers == ["alice@example.org", "bob"])
        let plain = try ServerConfiguration.fromEnvironment(["FRUS_AUTH": "header", "FRUS_TRUSTED_PROXIES": "127.0.0.1"])
        #expect(plain.authHeader == "X-Forwarded-User" && plain.adminUsers.isEmpty)
        #expect(ServerConfiguration().authHeader == "X-Forwarded-User" && ServerConfiguration().trustedProxies.isEmpty)
    }

    /// Header mode with no proxy, or one that trusts every peer, and sign-in's settings with no
    /// sign-in to use them, which would leave every visitor one user, are refused.
    @Test func headerModeRefusesWhatCouldNotWork() {
        for environment in [
            ["FRUS_AUTH": "header"],
            ["FRUS_AUTH": "header", "FRUS_TRUSTED_PROXIES": "proxy.example"],
            ["FRUS_AUTH": "header", "FRUS_TRUSTED_PROXIES": "10.0.0.0/33"],
            ["FRUS_AUTH": "header", "FRUS_TRUSTED_PROXIES": "10.0.0.256"],
            ["FRUS_AUTH": "header", "FRUS_TRUSTED_PROXIES": "0.0.0.0/0"],
            ["FRUS_AUTH": "header", "FRUS_TRUSTED_PROXIES": "::/0"],
            ["FRUS_AUTH": "header", "FRUS_TRUSTED_PROXIES": "::ffff:0:0/96"],
            ["FRUS_AUTH": "header", "FRUS_TRUSTED_PROXIES": "127.0.0.1", "FRUS_AUTH_HEADER": "X User"],
            ["FRUS_AUTH": "header", "FRUS_TRUSTED_PROXIES": "127.0.0.1", "FRUS_AUTH_HEADER": "X-User:"],
            ["FRUS_TRUSTED_PROXIES": "127.0.0.1"],
            ["FRUS_AUTH": "none", "FRUS_ADMIN_USERS": "alice"],
            ["FRUS_AUTH_HEADER": "X-Forwarded-User"],
        ] {
            #expect(throws: ConfigurationError.self, "\(environment)") { try ServerConfiguration.fromEnvironment(environment) }
        }
    }

    /// A proxy's address or range, as FRUS_TRUSTED_PROXIES names it, and the peers it holds, an IPv4
    /// peer in either of the forms a socket gives it.
    @Test func anAddressRangeHoldsThePeersItNames() throws {
        let one = try #require(AddressRange("127.0.0.1"))
        #expect(one.contains("127.0.0.1") && one.contains("::ffff:127.0.0.1") && !one.contains("127.0.0.2") && !one.contains("::1"))
        let network = try #require(AddressRange("172.18.0.1/16"))
        #expect(network.contains("172.18.0.1") && network.contains("172.18.255.254") && !network.contains("172.19.0.1"))
        let odd = try #require(AddressRange("10.0.0.0/9"))
        #expect(odd.contains("10.127.255.255") && !odd.contains("10.128.0.0"))
        let v6 = try #require(AddressRange("fd00::/8"))
        #expect(v6.contains("fd12:3456::1") && !v6.contains("fe80::1") && !v6.contains("10.0.0.1"))
        let loopback = try #require(AddressRange("::1"))
        #expect(loopback.contains("::1") && !loopback.contains("::2") && !loopback.contains("127.0.0.1"))
        for peer in ["localhost", "", "10.0.0", "unix:/tmp/socket"] { #expect(!network.contains(peer), "\(peer)") }
        for text in ["", "10.0.0.0/", "/8", "10.0.0.0/-1", "10.0.0.0/8/8", "fd00::/129", "fe80::1%eth0", "proxy.example"] {
            #expect(AddressRange(text) == nil, "\(text)")
        }
        let everyV4 = try #require(AddressRange("0.0.0.0/0"))
        let everyV6 = try #require(AddressRange("::/0"))
        let half = try #require(AddressRange("0.0.0.0/1"))
        #expect(everyV4.isEveryAddress && everyV6.isEveryAddress && !half.isEveryAddress && !network.isEveryAddress)
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
