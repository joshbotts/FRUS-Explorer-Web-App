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
    /// Origin used for links and cookies (`FRUS_PUBLIC_URL`).
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

    public init(
        mode: Mode = .import, auth: Auth = .none, dataDirectory: URL = URL(fileURLWithPath: "/data"),
        publicURL: String = "http://localhost:8080", pdfURL: String? = nil, offline: Bool = false,
        host: String = "127.0.0.1", port: Int = 8080, importPollInterval: Duration = .seconds(2)
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
            if Self.isHTTPOrigin(raw) { config.publicURL = raw } else {
                problems.append("FRUS_PUBLIC_URL must be an http or https URL, not \(raw)")
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

        if !problems.isEmpty { throw ConfigurationError(problems: problems) }
        return config
    }

    private static func isHTTPOrigin(_ raw: String) -> Bool {
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(), url.host != nil else { return false }
        return scheme == "http" || scheme == "https"
    }
}

/// Every problem found in the environment, so one start reports them all.
public struct ConfigurationError: Error, CustomStringConvertible, Equatable {
    public let problems: [String]
    public var description: String { "Configuration problems:\n" + problems.map { "- \($0)" }.joined(separator: "\n") }
}
