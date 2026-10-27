// A connection to PostgreSQL for the user store (PLAN's S14d), over PostgresNIO: where the store's
// statements, written once in SQL both of its stores read, run when the store is PostgreSQL's. Each
// `?` goes to PostgreSQL as `$1`, `$2`…; each value as the type SQLite keeps it as, a text cut at its
// first NUL as SQLite's binding cuts it; and each value a row gives comes back as SQLite gives it, so a
// method reads the same from either store. A call waits for PostgreSQL on its own thread, as a call to
// SQLite does: the routes run store calls through `Blocking.run`, off Swift's cooperative pool, and
// PostgresNIO's event loops answer them.

import Foundation
import Logging
import NIOCore
import NIOPosix
import NIOSSL
import PostgresNIO
import Synchronization

/// Where the PostgreSQL store is and how it is reached: `FRUS_POSTGRES_URL`, with the password from
/// it or from `FRUS_POSTGRES_PASSWORD_FILE`.
public struct PostgreSQLConfiguration: Sendable, Equatable, CustomStringConvertible {
    /// How the connection uses TLS, by libpq's names for its `sslmode`.
    public enum TLSMode: String, Sendable, CaseIterable {
        /// No TLS: for a database on the same host or a private network.
        case disable
        /// TLS, with no check of the server's certificate.
        case require
        /// TLS, with the certificate checked against the trusted roots, but not its name.
        case verifyCA = "verify-ca"
        /// TLS, with the certificate checked against the trusted roots and its name against the host's:
        /// the default.
        case verifyFull = "verify-full"
    }

    public var host: String
    public var port: Int
    public var username: String
    public var password: String?
    /// The database, or nil for the server's default, the user's name.
    public var database: String?
    public var tls: TLSMode
    /// A PEM file of the roots a certificate is checked against, libpq's `sslrootcert`, or nil for the
    /// system's.
    public var rootCertificates: String?
    /// The schema the store's tables are made in and read from, which the store makes if it is missing,
    /// or nil for the role's own search path: each of the tests' stores has one of its own.
    public var schema: String?

    public init(host: String, port: Int = 5432, username: String, password: String? = nil, database: String? = nil,
                tls: TLSMode = .verifyFull, rootCertificates: String? = nil, schema: String? = nil) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.tls = tls
        self.rootCertificates = rootCertificates
        self.schema = schema
    }

    /// Reads a URL in the form libpq takes, `postgres://user[:password]@host[:port][/database]`, or
    /// `postgresql://`, with `sslmode` (`disable`, `require`, `verify-ca` or `verify-full`, the default)
    /// and `sslrootcert` as its only parameters. The user, password and database may be percent-encoded.
    /// Throws, with the reason, for anything else, a parameter it does not know included, so that a
    /// misspelt `sslmode` cannot turn checks off unseen.
    public init(url: String) throws {
        guard let components = URLComponents(string: url), let scheme = components.scheme?.lowercased(),
              scheme == "postgres" || scheme == "postgresql" else {
            throw PostgreSQLConfigurationError("is not a postgres:// URL")
        }
        guard let rawHost = components.host, !rawHost.isEmpty else {
            throw PostgreSQLConfigurationError("names no host; a socket path is not supported")
        }
        guard let user = components.user, !user.isEmpty else { throw PostgreSQLConfigurationError("names no user") }
        if let port = components.port, !(1...65_535).contains(port) {
            throw PostgreSQLConfigurationError("has a port out of range")
        }
        let path = components.path.hasPrefix("/") ? String(components.path.dropFirst()) : components.path
        guard !path.contains("/") else { throw PostgreSQLConfigurationError("names a database with a slash in it") }
        guard components.fragment == nil else { throw PostgreSQLConfigurationError("has a fragment") }
        var tls = TLSMode.verifyFull
        var roots: String?
        for item in components.queryItems ?? [] {
            switch item.name {
            case "sslmode":
                guard let mode = item.value.flatMap(TLSMode.init(rawValue:)) else {
                    throw PostgreSQLConfigurationError(
                        "has an sslmode that is none of \(TLSMode.allCases.map(\.rawValue).joined(separator: ", "))")
                }
                tls = mode
            case "sslrootcert":
                guard let value = item.value, !value.isEmpty else { throw PostgreSQLConfigurationError("has an sslrootcert that names no file") }
                roots = value
            default:
                throw PostgreSQLConfigurationError("has a parameter this server does not read, \(item.name): it reads sslmode and sslrootcert")
            }
        }
        // An IPv6 address in brackets, as a URL writes one.
        let host = rawHost.hasPrefix("[") && rawHost.hasSuffix("]") ? String(rawHost.dropFirst().dropLast()) : rawHost
        self.init(host: host, port: components.port ?? 5432, username: user, password: components.password,
                  database: path.isEmpty ? nil : path, tls: tls, rootCertificates: roots)
    }

    /// The URL without its password, for the log.
    public var description: String {
        let name = host.contains(":") ? "[\(host)]" : host
        var parameters = ["sslmode=\(tls.rawValue)"]
        if let rootCertificates { parameters.append("sslrootcert=\(rootCertificates)") }
        return "postgres://\(username)@\(name):\(port)/\(database ?? "")?\(parameters.joined(separator: "&"))"
    }

    /// The TLS PostgresNIO's connection is made with.
    func connectionTLS() throws -> PostgresConnection.Configuration.TLS {
        guard tls != .disable else { return .disable }
        var configuration = TLSConfiguration.makeClientConfiguration()
        configuration.certificateVerification = switch tls {
        case .disable, .require: .none
        case .verifyCA: .noHostnameVerification
        case .verifyFull: .fullVerification
        }
        if let rootCertificates { configuration.trustRoots = .file(rootCertificates) }
        do {
            return .require(try NIOSSLContext(configuration: configuration))
        } catch {
            throw PostgreSQLConfigurationError("cannot make a TLS context from sslrootcert's file (\(error))")
        }
    }
}

/// Why a PostgreSQL URL was refused.
public struct PostgreSQLConfigurationError: Error, CustomStringConvertible, Equatable {
    public let reason: String

    public init(_ reason: String) { self.reason = reason }

    public var description: String { reason }
}

/// A failure of the PostgreSQL store's connection, or of a statement on it, in words a log can carry:
/// PostgreSQL's own message and state for a statement it refused, or what failed on the connection.
/// PostgresNIO's own errors print a placeholder, so that a statement's values cannot reach a log
/// unseen; this keeps only the server's message and the failure's kind.
public struct PostgreSQLError: Error, CustomStringConvertible, Sendable {
    /// The SQLSTATE of a statement the server refused, such as 23505 for a duplicate key, or nil.
    public let sqlState: String?
    public let message: String

    init(sqlState: String? = nil, message: String) {
        self.sqlState = sqlState
        self.message = message
    }

    init(_ error: any Error) {
        if let error = error as? PostgreSQLError {
            self = error
        } else if let error = error as? PSQLError {
            if let info = error.serverInfo {
                sqlState = info[.sqlState]
                message = [info[.message], info[.detail]].compactMap { $0 }.joined(separator: ": ")
            } else {
                sqlState = nil
                message = "\(error.code)" + (error.underlying.map { " (\($0))" } ?? "")
            }
        } else {
            sqlState = nil
            message = "\(error)"
        }
    }

    public var description: String {
        sqlState.map { "PostgreSQL error \($0): \(message)" } ?? "PostgreSQL connection: \(message)"
    }
}

/// One connection to PostgreSQL, as the user store's statements use one. Not for two callers at once:
/// the store holds its lock for each use, as the SQLite store does its connection's.
public final class PostgreSQLConnection: UserStoreConnection, @unchecked Sendable {
    private let connection: PostgresConnection
    private let logger: Logger

    private init(_ connection: PostgresConnection, logger: Logger) {
        self.connection = connection
        self.logger = logger
    }

    deinit { close() }

    public var dialect: UserStoreDialect { .postgreSQL }

    /// Whether the connection has closed, by either end.
    public var isClosed: Bool { connection.isClosed }

    /// Connects, waiting at most ten seconds, and with a schema in the configuration makes it if it is
    /// missing and reads and writes in it.
    public static func connect(_ configuration: PostgreSQLConfiguration,
                               logger: Logger = Logger(label: "frus-light.postgresql")) throws -> PostgreSQLConnection {
        var options = PostgresConnection.Configuration(host: configuration.host, port: configuration.port,
                                                       username: configuration.username, password: configuration.password,
                                                       database: configuration.database, tls: try configuration.connectionTLS())
        options.options.connectTimeout = .seconds(10)
        options.options.additionalStartupParameters = [("application_name", applicationName(configuration))]
        let connected: PostgresConnection
        do {
            connected = try PostgresConnection.connect(on: MultiThreadedEventLoopGroup.singleton.next(), configuration: options,
                                                       id: ids.add(1, ordering: .relaxed).newValue, logger: logger).wait()
        } catch {
            throw PostgreSQLError(error)
        }
        let connection = PostgreSQLConnection(connected, logger: logger)
        if let schema = configuration.schema {
            try connection.execute("CREATE SCHEMA IF NOT EXISTS \(quoted(schema))")
            try connection.execute("SET search_path TO \(quoted(schema))")
        }
        return connection
    }

    private static let ids = Atomic<Int>(0)

    /// The name a connection gives the server, which `pg_stat_activity` shows: `frus-light`, and the
    /// schema's name after it when the configuration names one.
    public static func applicationName(_ configuration: PostgreSQLConfiguration) -> String {
        ["frus-light", configuration.schema].compactMap { $0 }.joined(separator: " ")
    }

    /// `name` as PostgreSQL reads a quoted name.
    public static func quoted(_ name: String) -> String {
        "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Closes the connection, waiting until it has. Safe to call twice.
    public func close() {
        guard !connection.isClosed else { return }
        try? connection.close().wait()
    }

    public func query(_ sql: String, _ bindings: [SQLiteValue]) throws -> [[SQLiteValue]] {
        var binds = PostgresBindings(capacity: bindings.count)
        for value in bindings {
            switch value {
            case .null: binds.appendNull()
            case .integer(let integer): binds.append(integer)
            case .real(let real): binds.append(real)
            case .text(let text): binds.append(text.firstIndex(of: "\0").map { String(text[..<$0]) } ?? text)
            case .blob(let bytes): binds.append(ByteBuffer(bytes: bytes))
            }
        }
        do {
            let result = try connection.query(PostgresQuery(unsafeSQL: Self.numbered(sql), binds: binds), logger: logger).wait()
            return try result.rows.map { row in try row.map(Self.value) }
        } catch {
            throw PostgreSQLError(error)
        }
    }

    public func scalar(_ sql: String, _ bindings: [SQLiteValue]) throws -> SQLiteValue? {
        try query(sql, bindings).first?.first
    }

    /// Runs one statement that binds nothing, such as `BEGIN` or a migration's.
    public func execute(_ sql: String) throws {
        _ = try query(sql, [])
    }

    /// `sql` with each `?` outside a quoted text, a quoted name and a comment numbered as PostgreSQL's
    /// `$1`, `$2`…, in order.
    static func numbered(_ sql: String) -> String {
        var numbered = ""
        numbered.reserveCapacity(sql.utf8.count + 8)
        var count = 0
        var quote: Character?
        var lineComment = false
        var blockComment = false
        var characters = sql.makeIterator()
        var pending: Character?
        while let character = pending ?? characters.next() {
            pending = nil
            if lineComment {
                if character == "\n" { lineComment = false }
            } else if blockComment {
                if character == "*", let next = characters.next() {
                    numbered.append(character)
                    if next == "/" { blockComment = false; numbered.append(next) } else { pending = next }
                    continue
                }
            } else if let open = quote {
                // A doubled quote closes and opens again, which leaves the same text.
                if character == open { quote = nil }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character == "-" || character == "/", let next = characters.next() {
                numbered.append(character)
                if (character == "-" && next == "-") || (character == "/" && next == "*") {
                    if character == "-" { lineComment = true } else { blockComment = true }
                    numbered.append(next)
                } else {
                    pending = next
                }
                continue
            } else if character == "?" {
                count += 1
                numbered += "$\(count)"
                continue
            }
            numbered.append(character)
        }
        return numbered
    }

    /// A value as SQLite gives it: an integer, a boolean as 0 or 1, a real, the bytes of a `bytea`, and
    /// anything else as text, which for the `void` the advisory lock gives is empty.
    private static func value(_ cell: PostgresCell) throws -> SQLiteValue {
        guard let bytes = cell.bytes else { return .null }
        switch cell.dataType {
        case .int2, .int4, .int8: return .integer(try cell.decode(Int64.self))
        case .float4, .float8: return .real(try cell.decode(Double.self))
        case .bool: return .integer(try cell.decode(Bool.self) ? 1 : 0)
        case .bytea: return .blob(Array(buffer: bytes))
        default: return .text((try? cell.decode(String.self)) ?? String(buffer: bytes))
        }
    }
}
