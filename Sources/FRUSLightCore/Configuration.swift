// Server configuration from the environment variables in docs/SPEC.md (Deployment > Configuration).

import Foundation

/// The settings a server process runs with. Phase 1 supports Import mode with no sign-in.
public struct ServerConfiguration: Sendable, Equatable {
    public enum Mode: String, Sendable, Codable { case `import`, standalone }
    public enum Auth: String, Sendable, Codable { case none, local, header }

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
    /// notes, highlights or collections, as an instance others reach must be until sign-in.
    public var userData: Bool

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
        userData: Bool = true
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
        if config.auth != .none {
            problems.append("FRUS_AUTH=\(config.auth.rawValue) arrives in a later phase; this build supports none")
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

    /// The parts of `raw` as `URL` reads it, so a character it escapes is seen escaped.
    private static func components(of raw: String) -> URLComponents? {
        URL(string: raw).flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
    }

    private static func isHTTPOrigin(_ raw: String) -> Bool {
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(), url.host != nil else { return false }
        return (scheme == "http" || scheme == "https") && PublicAddress(raw) != nil
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
