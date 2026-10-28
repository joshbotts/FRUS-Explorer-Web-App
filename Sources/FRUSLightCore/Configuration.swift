// Server configuration from the environment variables in docs/SPEC.md (Deployment > Configuration).

import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// The settings a server process runs with: Import mode, with no sign-in or, from PLAN's S14e,
/// sign-in through a trusted proxy.
public struct ServerConfiguration: Sendable, Equatable {
    public enum Mode: String, Sendable, Codable { case `import`, standalone }
    public enum Auth: String, Sendable, Codable { case none, local, header }
    /// Where users and their data are kept (`FRUS_USER_STORE`): app.db, or since S14d a PostgreSQL
    /// database, SPEC's option B.
    public enum UserStoreChoice: Sendable, Equatable {
        case sqlite
        case postgreSQL(PostgreSQLConfiguration)
    }

    public var mode: Mode
    public var auth: Auth
    /// Root of all state (`FRUS_DATA_DIR`).
    public var dataDirectory: URL
    /// Origin used for links and cookies (`FRUS_PUBLIC_URL`), with the path the server answers
    /// under when it ends in one.
    public var publicURL: String
    /// Gotenberg base URL (`FRUS_PDF_URL`); PDF export is hidden when nil.
    public var pdfURL: String?
    /// Blocks all outbound traffic (`FRUS_OFFLINE`).
    public var offline: Bool
    /// Address to listen on (`FRUS_HOST`). 127.0.0.1 by default; the image sets 0.0.0.0 and
    /// Compose publishes the port on the host's 127.0.0.1 only.
    public var host: String
    public var port: Int
    /// How often Import mode looks for a new export in `/data/import` (`FRUS_IMPORT_POLL_SECONDS`).
    public var importPollInterval: Duration
    /// The app's data files, `FRUSExplorer/Resources` from the pinned FRUS-Explorer commit
    /// (`FRUS_RESOURCES_DIR`). The image copies them to the default; `scripts/swift` points at
    /// the submodule's folder.
    public var resourcesDirectory: URL
    /// The browser app's build, web/dist (`FRUS_WEB_DIR`). The image copies it to the default;
    /// without it the server serves the API alone, unless the variable names it explicitly.
    public var webDirectory: URL
    /// Set when `FRUS_WEB_DIR` names the folder, so a server without the app refuses to start.
    public var requiresWebDirectory: Bool
    /// Whether the server keeps user data (`FRUS_USER_DATA`): off, it is read-only, with no tags,
    /// notes, highlights or collections, as an instance others reach with no sign-in must be.
    public var userData: Bool
    /// The user store: app.db in the data directory, or a PostgreSQL database, its password from the
    /// URL or from `FRUS_POSTGRES_PASSWORD_FILE`.
    public var userStore: UserStoreChoice
    /// The hour of the user store's daily backup (`FRUS_BACKUP_HOUR`), 0 to 23 in the container's
    /// time zone, which `TZ` sets: 3 by default (PLAN's S14b).
    public var backupHour: Int
    /// A folder each finished backup is also copied to (`FRUS_BACKUP_COPY_DIR`), such as the host
    /// folder Compose mounts at `/backups`, which outlives the volume; none by default.
    public var backupCopyDirectory: URL?
    /// In `header` mode, the header the proxy names the user in (`FRUS_AUTH_HEADER`).
    public var authHeader: String
    /// In `header` mode, the proxies a request may come from (`FRUS_TRUSTED_PROXIES`); a request
    /// from any other peer is refused.
    public var trustedProxies: [AddressRange]
    /// In `header` mode, the users who hold the admin role (`FRUS_ADMIN_USERS`), as the header
    /// names them.
    public var adminUsers: Set<String>

    /// The path the server answers under, `FRUS_PUBLIC_URL`'s: the root unless it ends in a path.
    public var basePath: BasePath {
        Self.components(of: publicURL).flatMap { BasePath($0.percentEncodedPath) } ?? .root
    }

    /// The origin `FRUS_PUBLIC_URL` names, which a write's `Host` and `Origin` must name too.
    public var publicAddress: PublicAddress {
        PublicAddress(publicURL) ?? PublicAddress("http://localhost:8080")!
    }

    /// Where the image puts the app's data files.
    public static let imageResourcesDirectory = URL(fileURLWithPath: "/usr/share/frus-light/resources", isDirectory: true)
    /// Where the image puts the browser app.
    public static let imageWebDirectory = URL(fileURLWithPath: "/usr/share/frus-light/web", isDirectory: true)

    public init(
        mode: Mode = .import, auth: Auth = .none, dataDirectory: URL = URL(fileURLWithPath: "/data"),
        publicURL: String = "http://localhost:8080", pdfURL: String? = nil, offline: Bool = false,
        host: String = "127.0.0.1", port: Int = 8080, importPollInterval: Duration = .seconds(2),
        resourcesDirectory: URL = ServerConfiguration.imageResourcesDirectory,
        webDirectory: URL = ServerConfiguration.imageWebDirectory, requiresWebDirectory: Bool = false,
        userData: Bool = true, userStore: UserStoreChoice = .sqlite, backupHour: Int = 3,
        backupCopyDirectory: URL? = nil, authHeader: String = "X-Forwarded-User",
        trustedProxies: [AddressRange] = [], adminUsers: Set<String> = []
    ) {
        self.mode = mode
        self.auth = auth
        self.dataDirectory = dataDirectory
        self.publicURL = publicURL
        self.pdfURL = pdfURL
        self.offline = offline
        self.host = host
        self.port = port
        self.importPollInterval = importPollInterval
        self.resourcesDirectory = resourcesDirectory
        self.webDirectory = webDirectory
        self.requiresWebDirectory = requiresWebDirectory
        self.userData = userData
        self.userStore = userStore
        self.backupHour = backupHour
        self.backupCopyDirectory = backupCopyDirectory
        self.authHeader = authHeader
        self.trustedProxies = trustedProxies
        self.adminUsers = adminUsers
    }

    /// Reads the configuration, reporting every problem at once.
    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> ServerConfiguration {
        var config = ServerConfiguration()
        var problems: [String] = []
        func value(_ name: String) -> String? {
            guard let raw = environment[name]?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
            return raw
        }

        if let raw = value("FRUS_MODE") {
            if let mode = Mode(rawValue: raw) { config.mode = mode } else {
                problems.append("FRUS_MODE must be import or standalone, not \(raw)")
            }
        }
        if config.mode == .standalone {
            problems.append("FRUS_MODE=standalone arrives in phase 3; this build serves Import mode only")
        }
        if let raw = value("FRUS_AUTH") {
            if let auth = Auth(rawValue: raw) { config.auth = auth } else {
                problems.append("FRUS_AUTH must be none, local or header, not \(raw)")
            }
        }
        if config.auth == .local {
            problems.append("FRUS_AUTH=local arrives in phase 3; this build supports none and header")
        }
        if let raw = value("FRUS_AUTH_HEADER") {
            if Self.isFieldName(raw) { config.authHeader = raw } else {
                problems.append("FRUS_AUTH_HEADER must be a header's name, such as X-Forwarded-User, not \(raw)")
            }
        }
        if let raw = value("FRUS_TRUSTED_PROXIES") {
            for item in raw.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init) {
                if let range = AddressRange(item) {
                    if range.isEveryAddress {
                        problems.append("FRUS_TRUSTED_PROXIES must name the proxy, not every address, as \(item) does")
                    } else {
                        config.trustedProxies.append(range)
                    }
                } else {
                    problems.append("FRUS_TRUSTED_PROXIES must list IPv4 or IPv6 addresses or CIDR ranges, such as 172.18.0.1 or 10.0.0.0/8, not \(item)")
                }
            }
        }
        if let raw = value("FRUS_ADMIN_USERS") {
            config.adminUsers = Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        }
        if config.auth == .header, config.trustedProxies.isEmpty, value("FRUS_TRUSTED_PROXIES") == nil {
            problems.append("FRUS_AUTH=header needs FRUS_TRUSTED_PROXIES: the addresses of the proxy that signs people in and sets \(config.authHeader)")
        }
        if config.auth != .header {
            // Sign-in's settings without sign-in: every visitor would share one user's research.
            for name in ["FRUS_AUTH_HEADER", "FRUS_TRUSTED_PROXIES", "FRUS_ADMIN_USERS"] where value(name) != nil {
                problems.append("\(name) is for sign-in through a proxy, and FRUS_AUTH is \(config.auth.rawValue): set FRUS_AUTH=header, or leave \(name) out")
            }
        }
        if let raw = value("FRUS_DATA_DIR") {
            config.dataDirectory = URL(fileURLWithPath: raw, isDirectory: true)
        }
        if let raw = value("FRUS_PUBLIC_URL") {
            let components = Self.components(of: raw)
            if !Self.isHTTPOrigin(raw) {
                problems.append("FRUS_PUBLIC_URL must be an http or https URL, not \(raw)")
            } else if components?.query != nil || components?.fragment != nil {
                problems.append("FRUS_PUBLIC_URL must have no query or fragment, not \(raw)")
            } else if BasePath(components?.percentEncodedPath ?? "") == nil {
                problems.append("FRUS_PUBLIC_URL's path must be names of letters, digits and - . _ ~ between slashes, such as /frus-explorer/, not \(components?.percentEncodedPath ?? raw)")
            } else {
                config.publicURL = raw
            }
        }
        if let raw = value("FRUS_PDF_URL") {
            if Self.isHTTPOrigin(raw) { config.pdfURL = raw } else {
                problems.append("FRUS_PDF_URL must be an http or https URL, not \(raw)")
            }
        }
        if let raw = value("FRUS_OFFLINE") {
            switch raw.lowercased() {
            case "true": config.offline = true
            case "false": config.offline = false
            default: problems.append("FRUS_OFFLINE must be true or false, not \(raw)")
            }
        }
        if let raw = value("FRUS_USER_DATA") {
            switch raw.lowercased() {
            case "on": config.userData = true
            case "off": config.userData = false
            default: problems.append("FRUS_USER_DATA must be on or off, not \(raw)")
            }
        }
        // The URL is never echoed: it may carry the store's password.
        let passwordFile = value("FRUS_POSTGRES_PASSWORD_FILE")
        switch value("FRUS_USER_STORE") {
        case nil, "sqlite":
            if passwordFile != nil {
                problems.append("FRUS_POSTGRES_PASSWORD_FILE is for a PostgreSQL user store, and FRUS_USER_STORE names none")
            }
        case let raw?:
            do {
                var postgres = try PostgreSQLConfiguration(url: raw)
                if let passwordFile {
                    if postgres.password != nil {
                        problems.append("FRUS_POSTGRES_PASSWORD_FILE gives a password for a FRUS_USER_STORE URL that has one: give it in one place")
                    } else if let password = Self.password(in: passwordFile) {
                        postgres.password = password
                    } else {
                        problems.append("FRUS_POSTGRES_PASSWORD_FILE must name a readable file holding the password, not \(passwordFile)")
                    }
                }
                config.userStore = .postgreSQL(postgres)
            } catch {
                problems.append("FRUS_USER_STORE must be sqlite or a postgres:// URL, and this one \(error)")
            }
        }
        if let raw = value("FRUS_HOST") { config.host = raw }
        if let raw = value("FRUS_PORT") {
            if let port = Int(raw), (1...65_535).contains(port) { config.port = port } else {
                problems.append("FRUS_PORT must be a port number, not \(raw)")
            }
        }
        if let raw = value("FRUS_IMPORT_POLL_SECONDS") {
            if let seconds = Double(raw), seconds >= 0.05, seconds <= 3_600 {
                config.importPollInterval = .milliseconds(Int64(seconds * 1_000))
            } else {
                problems.append("FRUS_IMPORT_POLL_SECONDS must be a number of seconds from 0.05 to 3600, not \(raw)")
            }
        }

        if let raw = value("FRUS_BACKUP_HOUR") {
            if let hour = Int(raw), (0...23).contains(hour) { config.backupHour = hour } else {
                problems.append("FRUS_BACKUP_HOUR must be an hour from 0 to 23, not \(raw)")
            }
        }
        if let raw = value("FRUS_BACKUP_COPY_DIR") {
            config.backupCopyDirectory = URL(fileURLWithPath: raw, isDirectory: true)
        }

        if let raw = value("FRUS_RESOURCES_DIR") {
            config.resourcesDirectory = URL(fileURLWithPath: raw, isDirectory: true)
        }
        if let raw = value("FRUS_WEB_DIR") {
            config.webDirectory = URL(fileURLWithPath: raw, isDirectory: true)
            config.requiresWebDirectory = true
        }

        if !problems.isEmpty { throw ConfigurationError(problems: problems) }
        return config
    }

    /// The password in `file`, without the line break that ends it, or nil when it cannot be read or
    /// holds none.
    private static func password(in file: String) -> String? {
        guard var text = try? String(contentsOfFile: file, encoding: .utf8) else { return nil }
        if text.hasSuffix("\n") { text.removeLast() }
        if text.hasSuffix("\r") { text.removeLast() }
        return text.isEmpty ? nil : text
    }

    /// The parts of `raw` as `URL` reads it, so a character it escapes is seen escaped.
    private static func components(of raw: String) -> URLComponents? {
        URL(string: raw).flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
    }

    private static func isHTTPOrigin(_ raw: String) -> Bool {
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(), url.host != nil else { return false }
        return (scheme == "http" || scheme == "https") && PublicAddress(raw) != nil
    }

    /// Whether `raw` is a header's name: a token, as RFC 9110 writes one.
    private static func isFieldName(_ raw: String) -> Bool {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&'*+-.^_`|~")
        return raw.allSatisfy(allowed.contains)
    }
}

/// An IPv4 or IPv6 address, or a CIDR range of them, as `FRUS_TRUSTED_PROXIES` names the proxies a
/// request behind sign-in may come from (PLAN's S14e). An IPv4 address is held as IPv6 maps it,
/// `::ffff:a.b.c.d`, so a range of IPv4 addresses takes a peer that a server listening on IPv6 sees
/// in that form.
public struct AddressRange: Sendable, Equatable, CustomStringConvertible {
    /// The range's first address, in 16 bytes, those after its prefix zero.
    private let network: [UInt8]
    /// How many of an address's 128 bits the range fixes.
    private let prefix: Int
    public let description: String

    /// An address, `172.18.0.1` or `::1`, which is a range of one, or a range, `10.0.0.0/8` or
    /// `fd00::/8`; nil for anything else, a host name included. The bits after a range's prefix
    /// are ignored, so `172.18.0.1/16` is `172.18.0.0/16`.
    public init?(_ text: String) {
        let parts = text.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard let address = Self.bytes(of: String(parts[0])) else { return nil }
        let width = parts[0].contains(":") ? 128 : 32
        var length = width
        if parts.count == 2 {
            guard !parts[1].isEmpty, parts[1].count <= 3, parts[1].allSatisfy({ $0.isASCII && $0.isNumber }),
                  let given = Int(parts[1]), given <= width else { return nil }
            length = given
        }
        prefix = 128 - width + length
        network = Self.masked(address, to: prefix)
        description = text
    }

    /// Whether the range is every address of its kind, as `0.0.0.0/0` is, which trusts any peer.
    public var isEveryAddress: Bool { prefix == 0 || (prefix == 96 && network[10] == 0xff && network[11] == 0xff) }

    /// Whether `address`, as a socket names its peer, `127.0.0.1` or `::ffff:127.0.0.1` or `::1`, is
    /// in the range.
    public func contains(_ address: String) -> Bool {
        guard let bytes = Self.bytes(of: address) else { return false }
        return Self.masked(bytes, to: prefix) == network
    }

    /// The 16 bytes of an IPv4 or IPv6 address, an IPv4 one mapped into IPv6; nil for anything else.
    private static func bytes(of text: String) -> [UInt8]? {
        var v4 = in_addr()
        if inet_pton(AF_INET, text, &v4) == 1 {
            return [UInt8](repeating: 0, count: 10) + [0xff, 0xff] + withUnsafeBytes(of: &v4) { Array($0) }
        }
        var v6 = in6_addr()
        if inet_pton(AF_INET6, text, &v6) == 1 { return withUnsafeBytes(of: &v6) { Array($0) } }
        return nil
    }

    private static func masked(_ bytes: [UInt8], to prefix: Int) -> [UInt8] {
        bytes.enumerated().map { index, byte in
            let kept = min(max(prefix - index * 8, 0), 8)
            return kept == 8 ? byte : byte & ~(0xff >> kept)
        }
    }
}

/// The scheme, host and port of `FRUS_PUBLIC_URL`: the address people open, and so the one a write
/// must come from and be sent to (PLAN's S14c). A server with no sign-in can be reached by any page
/// in the browser, and a name an attacker controls can be pointed at it: a write's `Origin` names the
/// page that sent it, and its `Host` the name the browser looked up, so both must name this address.
/// Reads of a user's data check the `Host` too, since a page under such a name could read them.
public struct PublicAddress: Sendable, Equatable, CustomStringConvertible {
    /// `http` or `https`.
    public let scheme: String
    /// The host, in lowercase, an IPv6 address without its brackets.
    public let host: String
    /// The port, given or the scheme's own.
    public let port: Int

    /// The address of an http or https URL; nil for another scheme, or one with no host.
    public init?(_ url: String) {
        guard let separator = url.range(of: "://") else { return nil }
        let scheme = url[..<separator.lowerBound].lowercased()
        guard scheme == "http" || scheme == "https" else { return nil }
        let rest = url[separator.upperBound...]
        let authority = rest.prefix { $0 != "/" && $0 != "?" && $0 != "#" }
        guard let (host, port) = Self.split(authority) else { return nil }
        self.scheme = scheme
        self.host = host
        self.port = port ?? (scheme == "https" ? 443 : 80)
    }

    /// `scheme://host[:port]`, the port left out where it is the scheme's own, as a browser writes
    /// an `Origin`.
    public var description: String {
        let name = host.contains(":") ? "[\(host)]" : host
        return port == (scheme == "https" ? 443 : 80) ? "\(scheme)://\(name)" : "\(scheme)://\(name):\(port)"
    }

    /// Whether a request's `Host` names this address: its host, or for an address on this machine
    /// (`localhost`, `127.0.0.1`, `::1`) any of those three, with this port when it gives one. A proxy
    /// may leave the port out, as nginx's `$host` does, and a host name is what a page under another
    /// name cannot forge.
    public func allows(host authority: String) -> Bool {
        guard let (host, port) = Self.split(Substring(authority)) else { return false }
        return names(host) && (port == nil || port == self.port)
    }

    /// Whether a request's `Origin` is this address: the same scheme and port, and its host, or for
    /// an address on this machine any of the three names it goes by. `null`, which a sandboxed frame
    /// or a page from a file sends, is never this address.
    public func allows(origin: String) -> Bool {
        // An origin is a scheme and an authority, with no path, query or fragment after them.
        guard let other = PublicAddress(origin),
              let separator = origin.range(of: "://"),
              !origin[separator.upperBound...].contains(where: { "/?#".contains($0) }) else { return false }
        return other.scheme == scheme && other.port == port && names(other.host)
    }

    private func names(_ other: String) -> Bool {
        other == host || (Self.loopback.contains(host) && Self.loopback.contains(other))
    }

    private static let loopback: Set<String> = ["localhost", "127.0.0.1", "::1"]

    /// `host[:port]` or `[v6]:port`, the host in lowercase; nil for anything else, a user name
    /// included.
    private static func split(_ authority: Substring) -> (String, Int?)? {
        let host: Substring
        var portText: Substring?
        if authority.hasPrefix("[") {
            guard let close = authority.firstIndex(of: "]") else { return nil }
            host = authority[authority.index(after: authority.startIndex)..<close]
            let after = authority[authority.index(after: close)...]
            if !after.isEmpty {
                guard after.hasPrefix(":") else { return nil }
                portText = after.dropFirst()
            }
            guard !host.isEmpty, host.allSatisfy({ $0.isASCII && ($0.isHexDigit || $0 == ":" || $0 == ".") }) else { return nil }
        } else {
            if let colon = authority.lastIndex(of: ":") {
                host = authority[..<colon]
                portText = authority[authority.index(after: colon)...]
            } else {
                host = authority
            }
            let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-.")
            guard !host.isEmpty, host.allSatisfy(allowed.contains) else { return nil }
        }
        var port: Int?
        if let portText {
            guard !portText.isEmpty, portText.count <= 5, portText.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(portText),
                  (1...65_535).contains(number) else { return nil }
            port = number
        }
        return (host.lowercased(), port)
    }
}

/// The path the server answers under (PLAN's S14f): `/`, or one such as `/frus-explorer/`, which a
/// proxy forwards as it is. The routes are written at the root; a request under the path reaches
/// them without it, and every address the server writes, the browser app's base, the reader's host
/// script and its figures, is under it. Its names hold only unreserved characters, so it needs no
/// escaping in a URL, an HTML attribute or a script.
public struct BasePath: Sendable, Equatable, CustomStringConvertible {
    /// `/`, or the path's names between slashes, with one at each end.
    public let path: String

    public static let root = BasePath(names: [])

    /// The base path of a URL's path, such as `/frus-explorer/`; the slash at its end may be left
    /// out, and an empty path is the root. Nil when a name between slashes is empty, `.` or `..`,
    /// or holds anything but letters, digits and `-._~`.
    public init?(_ urlPath: String) {
        guard urlPath.isEmpty || urlPath.hasPrefix("/") else { return nil }
        var names = urlPath.split(separator: "/", omittingEmptySubsequences: false).dropFirst()
        if names.last == "" { names.removeLast() }
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard names.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.allSatisfy(allowed.contains) }) else { return nil }
        self.init(names: names.map(String.init))
    }

    private init(names: [String]) {
        path = names.isEmpty ? "/" : "/" + names.joined(separator: "/") + "/"
    }

    public var isRoot: Bool { path == "/" }

    public var description: String { path }

    /// `rootPath`, a path at the root such as `/api/v1/status`, under this one:
    /// `/frus-explorer/api/v1/status`.
    public func prefixing(_ rootPath: String) -> String {
        path + rootPath.drop(while: { $0 == "/" })
    }

    /// The path at the root that `requestPath`, which may end in a query, names under this one:
    /// `/frus-explorer/search?keywords=x` is `/search?keywords=x`. Nil when it is outside this one,
    /// as the base without its last slash is.
    public func stripping(_ requestPath: String) -> String? {
        guard requestPath.hasPrefix(path) else { return nil }
        return "/" + requestPath.dropFirst(path.count)
    }
}

/// Every problem found in the environment, so one start reports them all.
public struct ConfigurationError: Error, CustomStringConvertible, Equatable {
    public let problems: [String]
    public var description: String { "Configuration problems:\n" + problems.map { "- \($0)" }.joined(separator: "\n") }
}
