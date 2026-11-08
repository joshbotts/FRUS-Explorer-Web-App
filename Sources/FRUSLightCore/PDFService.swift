// The PDF service `FRUS_PDF_URL` names (PLAN's S25a): Gotenberg 8, compose.yaml's `pdf` service under the
// profile of that name, whose Chromium prints a page of HTML. The server asks it two things: whether its
// Chromium is up, which `GET /api/v1/pdf` answers for the export sheet, so that PDF is offered only while
// the service answers; and the PDF of a page, the kit's self-contained HTML export of a collection, which
// Chromium prints with the page's own print CSS, on the app's page: US Letter with an inch's margin, as
// the app's `PDFCollectionExporter` draws it, backgrounds printed, as a highlight's is.
//
// Each request is one HTTP/1.1 exchange on a connection of its own, through NIO, which the server already
// links for its PostgreSQL store: FoundationNetworking's URLSession would need libcurl, which the image
// does not carry.

import Foundation
import NIOCore
import NIOPosix
import NIOSSL

/// Why the PDF service made no PDF, or did not answer its health check.
public enum PDFServiceError: Error, Equatable, Sendable, CustomStringConvertible {
    /// It could not be reached, or did not answer in time: no name, no connection, a reset, a timeout.
    case unavailable(String)
    /// It answered with an error: its status and the start of its words.
    case refused(status: Int, detail: String)
    /// It answered with something that is no PDF, or no HTTP.
    case badAnswer(String)
    /// Its answer was larger than the server takes, in bytes.
    case tooLarge(Int)

    public var description: String {
        switch self {
        case .unavailable(let reason): "it did not answer: \(reason)"
        case .refused(let status, let detail): "it answered \(status)\(detail.isEmpty ? "" : ": \(detail)")"
        case .badAnswer(let reason): reason
        case .tooLarge(let limit): "its answer was larger than \(limit / 1_048_576) MiB"
        }
    }
}

/// Gotenberg's Chromium, at the address `FRUS_PDF_URL` gives.
public actor PDFService {
    /// How long an answer to the health check is kept, so that an export sheet opened again and again
    /// asks the service at most this often.
    public static let checkInterval: Duration = .seconds(10)
    /// The longest the server waits for the health check's answer.
    static let checkTimeout: Duration = .seconds(3)
    /// The longest it waits for a PDF. compose.yaml gives Gotenberg 300 seconds a request, for a long
    /// collection's print, and its own 30 by default answers 503 before this.
    static let printTimeout: Duration = .seconds(320)
    /// The largest PDF the server takes, as it holds the file to send it.
    static let largestPDF = 512 * 1_048_576

    /// The app's page (`PDFCollectionExporter`): 612 by 792 points, US Letter, with 72 points of margin,
    /// in Gotenberg's inches; and backgrounds printed, as a highlight's and a card's are. Chromium prints
    /// the page as its print media, its own `@media print` rules, which is Gotenberg's default.
    public static let printFields: [(name: String, value: String)] = [
        ("paperWidth", "8.5"), ("paperHeight", "11"),
        ("marginTop", "1"), ("marginBottom", "1"), ("marginLeft", "1"), ("marginRight", "1"),
        ("printBackground", "true"),
    ]

    /// The address, as the configuration gives it.
    public nonisolated let url: String
    nonisolated let endpoint: Endpoint
    private nonisolated let tls: Result<NIOSSLContext, PDFServiceError>?
    private let log: @Sendable (String) -> Void
    /// The last answer to the health check, and when it came.
    private var checked: (at: ContinuousClock.Instant, available: Bool)?
    /// The check under way, which a second asker waits for.
    private var checking: Task<Health, Never>?
    /// What the log last said of the service, so that it says each change once.
    private var said: Bool?

    /// The service at `url`, an http or https URL, which may end in the path Gotenberg's
    /// `--api-root-path` gives it; nil for another.
    public init?(url: String, log: @escaping @Sendable (String) -> Void = { _ in }) {
        guard let endpoint = Endpoint(url) else { return nil }
        self.url = url
        self.endpoint = endpoint
        if endpoint.tls {
            do {
                tls = .success(try NIOSSLContext(configuration: .makeClientConfiguration()))
            } catch {
                tls = .failure(.unavailable("TLS could not be set up: \(error)"))
            }
        } else {
            tls = nil
        }
        self.log = log
    }

    // MARK: - The health check

    /// Whether the service's Chromium answers now, asked at most every `checkInterval`. The log says
    /// when the answer changes, the first answer included, with what went wrong.
    public func isAvailable() async -> Bool {
        if let checked, ContinuousClock.now - checked.at < Self.checkInterval { return checked.available }
        if let checking { return await checking.value.available }
        let task = Task { await self.check() }
        checking = task
        let health = await task.value
        checking = nil
        checked = (ContinuousClock.now, health.available)
        if said != health.available {
            said = health.available
            log(health.available
                ? "The PDF service at \(url) answers: collections export as PDF"
                : "The PDF service at \(url) does not answer, so no PDF is offered until it does: \(health.reason)")
        }
        return health.available
    }

    struct Health: Sendable {
        var available: Bool
        var reason: String
    }

    /// After a print that found the service not answering: the next health check is asked at once, so
    /// that the sheet stops offering PDF without waiting out the last answer's ten seconds.
    func forgetAnswer() {
        checked = nil
    }

    /// Gotenberg's `GET /health`, once.
    nonisolated func check() async -> Health {
        do {
            let answer = try await exchange(request("GET", "health"), limit: 64 * 1_024, timeout: Self.checkTimeout)
            return Self.health(of: answer)
        } catch PDFServiceError.unavailable(let reason) {
            return Health(available: false, reason: reason)
        } catch {
            return Health(available: false, reason: "\(error)")
        }
    }

    /// What Gotenberg's health check says of its Chromium: `{"status", "details": {"chromium":
    /// {"status"}, …}}`, 503 when any module is down. Chromium's own status decides, whatever another
    /// module's, LibreOffice's in the image that has it; an answer that names no Chromium, its status.
    static func health(of answer: HTTPAnswer) -> Health {
        struct Body: Decodable {
            struct Module: Decodable { let status: String }
            let details: [String: Module]?
        }
        if let chromium = (try? JSONDecoder().decode(Body.self, from: answer.body))?.details?["chromium"] {
            return Health(available: chromium.status == "up", reason: "its Chromium is \(chromium.status)")
        }
        return Health(available: answer.status == 200, reason: "its health check answered \(answer.status)")
    }

    // MARK: - Printing

    /// The PDF Chromium prints of `html`, a page that loads nothing from elsewhere, through Gotenberg's
    /// `POST /forms/chromium/convert/html`, the page as its `index.html`.
    public nonisolated func pdf(fromHTML html: Data) async throws -> Data {
        let boundary = Self.boundary(avoiding: html)
        let body = Self.form(html: html, boundary: boundary)
        let answer: HTTPAnswer
        do {
            answer = try await exchange(
                request("POST", "forms/chromium/convert/html",
                        headers: [("Content-Type", "multipart/form-data; boundary=\(boundary)"), ("Accept", "application/pdf")], body: body),
                limit: Self.largestPDF, timeout: Self.printTimeout)
        } catch PDFServiceError.unavailable(let reason) {
            await forgetAnswer()
            throw PDFServiceError.unavailable(reason)
        }
        guard answer.status == 200 else {
            throw PDFServiceError.refused(status: answer.status, detail: Self.words(answer.body))
        }
        guard answer.body.starts(with: Array("%PDF-".utf8)) else {
            throw PDFServiceError.badAnswer("its answer was no PDF but \(answer.headers["content-type"] ?? "no type") of \(answer.body.count) bytes")
        }
        return answer.body
    }

    /// A boundary the page does not hold, as `multipart/form-data` needs.
    static func boundary(avoiding html: Data) -> String {
        while true {
            let boundary = "frus-light-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            if html.range(of: Data(boundary.utf8)) == nil { return boundary }
        }
    }

    /// The form Gotenberg's Chromium route reads: the page as `files`, named `index.html`, which the route
    /// requires, then the print fields.
    static func form(html: Data, boundary: String) -> [UInt8] {
        var form: [UInt8] = []
        func line(_ text: String) { form += Array(text.utf8) + [13, 10] }
        line("--\(boundary)")
        line("Content-Disposition: form-data; name=\"files\"; filename=\"index.html\"")
        line("Content-Type: text/html; charset=utf-8")
        line("")
        form += html
        line("")
        for field in printFields {
            line("--\(boundary)")
            line("Content-Disposition: form-data; name=\"\(field.name)\"")
            line("")
            line(field.value)
        }
        line("--\(boundary)--")
        return form
    }

    /// The start of an error's words, as Gotenberg writes them, plain text.
    static func words(_ body: Data) -> String {
        let text = String(decoding: body.prefix(2_048), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.count > 300 ? String(line.prefix(300)) + "…" : line
    }

    // MARK: - HTTP

    /// A request to `path`, under the service's own path: one exchange, after which the service closes
    /// the connection.
    nonisolated func request(_ method: String, _ path: String, headers: [(String, String)] = [], body: [UInt8] = []) -> [UInt8] {
        var head = "\(method) \(endpoint.basePath)\(path) HTTP/1.1\r\n"
        head += "Host: \(endpoint.authority)\r\n"
        head += "User-Agent: FRUS-Explorer-Light/\(FRUSLightVersion.string)\r\n"
        head += "Connection: close\r\n"
        if method != "GET" || !body.isEmpty { head += "Content-Length: \(body.count)\r\n" }
        for (name, value) in headers { head += "\(name): \(value)\r\n" }
        head += "\r\n"
        return Array(head.utf8) + body
    }

    /// One exchange, which `timeout` bounds from the first connection to the last byte; a task that is
    /// cancelled, as when the browser that asked has gone, closes the connection.
    nonisolated func exchange(_ request: [UInt8], limit: Int, timeout: Duration) async throws -> HTTPAnswer {
        try await withThrowingTaskGroup(of: HTTPAnswer.self) { group in
            group.addTask { try await self.send(request, limit: limit, connectWithin: timeout) }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw PDFServiceError.unavailable("no answer within \(timeout.components.seconds) seconds")
            }
            defer { group.cancelAll() }
            guard let answer = try await group.next() else { throw CancellationError() }
            return answer
        }
    }

    /// The connection is bounded by `connectWithin` as well, at most five seconds: NIO's connect does not
    /// stop when its task is cancelled, so the exchange's own timeout could not end it sooner.
    private nonisolated func send(_ request: [UInt8], limit: Int, connectWithin timeout: Duration) async throws -> HTTPAnswer {
        let endpoint = endpoint
        let context: NIOSSLContext?
        switch tls {
        case .success(let made): context = made
        case .failure(let error): throw error
        case nil: context = nil
        }
        let channel: NIOAsyncChannel<ByteBuffer, ByteBuffer>
        do {
            channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
                .connectTimeout(.milliseconds(min(5_000, Int64(timeout.components.seconds) * 1_000)))
                .connect(host: endpoint.host, port: endpoint.port) { channel in
                    channel.eventLoop.makeCompletedFuture {
                        if let context {
                            try channel.pipeline.syncOperations.addHandler(
                                try NIOSSLClientHandler(context: context, serverHostname: endpoint.serverName))
                        }
                        return try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                    }
                }
        } catch {
            try Task.checkCancellation()
            throw PDFServiceError.unavailable("no connection to \(endpoint.authority): \(Self.brief(error))")
        }
        let underlying = channel.channel
        return try await withTaskCancellationHandler {
            try await channel.executeThenClose { inbound, outbound in
                var reader = HTTPAnswer.Reader(limit: limit)
                do {
                    try await outbound.write(ByteBuffer(bytes: request))
                    for try await buffer in inbound {
                        try reader.append(buffer.readableBytesView)
                        if let answer = try reader.answer(ended: false) { return answer }
                    }
                } catch let error as PDFServiceError {
                    throw error
                } catch {
                    try Task.checkCancellation()
                    // A connection closed without TLS's farewell may still have brought the whole answer.
                    if let answer = try? reader.answer(ended: true) { return answer }
                    throw PDFServiceError.unavailable("the connection to \(endpoint.authority) failed: \(Self.brief(error))")
                }
                try Task.checkCancellation()
                guard let answer = try reader.answer(ended: true) else {
                    throw PDFServiceError.badAnswer("its answer ended early")
                }
                return answer
            }
        } onCancel: {
            underlying.close(promise: nil)
        }
    }

    /// An error in a line, for the log.
    static func brief(_ error: any Error) -> String {
        let text = String(describing: error)
        return text.count > 200 ? String(text.prefix(200)) + "…" : text
    }

    // MARK: - The address

    /// Where the service listens: the scheme, host and port of `FRUS_PDF_URL`, and the path under which
    /// Gotenberg answers, its root unless `--api-root-path` moves it.
    struct Endpoint: Sendable, Equatable {
        let host: String
        let port: Int
        let tls: Bool
        /// The path, ending in a slash.
        let basePath: String

        init?(_ url: String) {
            guard let address = PublicAddress(url), let separator = url.range(of: "://") else { return nil }
            host = address.host
            port = address.port
            tls = address.scheme == "https"
            let rest = url[separator.upperBound...]
            let path = rest.drop { $0 != "/" && $0 != "?" && $0 != "#" }.prefix { $0 != "?" && $0 != "#" }
            basePath = path.hasSuffix("/") ? String(path) : String(path) + "/"
        }

        /// `Host`'s value: the host, an IPv6 address in brackets, and the port unless it is the scheme's.
        var authority: String {
            let name = host.contains(":") ? "[\(host)]" : host
            return port == (tls ? 443 : 80) ? name : "\(name):\(port)"
        }

        /// The name TLS checks the certificate against, none for an address, which SNI cannot carry.
        var serverName: String? {
            (try? SocketAddress(ipAddress: host, port: 0)) == nil ? host : nil
        }
    }
}

/// One HTTP/1.1 answer, read whole: its status, its headers by lowercase name, and its body, copied once
/// from the bytes read, as a PDF may be large.
struct HTTPAnswer: Sendable, Equatable {
    var status: Int
    var headers: [String: String]
    var body: Data

    /// Reads an answer as its bytes arrive: whole once its `Content-Length` has come, or, for a chunked
    /// answer or one with no length, once the connection has closed, as `Connection: close` asks.
    struct Reader {
        let limit: Int
        private var bytes: [UInt8] = []
        private var head: (status: Int, headers: [String: String], bodyStart: Int)?

        init(limit: Int) {
            self.limit = limit
        }

        mutating func append(_ more: some Collection<UInt8>) throws {
            bytes.append(contentsOf: more)
            if bytes.count - (head?.bodyStart ?? 0) > limit + 65_536 { throw PDFServiceError.tooLarge(limit) }
        }

        /// The answer once it is whole, nil while more is to come; `ended` once the connection has closed.
        mutating func answer(ended: Bool) throws -> HTTPAnswer? {
            if head == nil {
                guard let end = bytes.firstRange(of: [13, 10, 13, 10]) else {
                    if ended { throw PDFServiceError.badAnswer(bytes.isEmpty ? "it answered nothing" : "its answer ended in its headers") }
                    return nil
                }
                head = try Self.head(String(decoding: bytes[..<end.lowerBound], as: UTF8.self), bodyStart: end.upperBound)
            }
            guard let head else { return nil }
            let body = bytes[head.bodyStart...]
            guard body.count <= limit else { throw PDFServiceError.tooLarge(limit) }
            if head.headers["transfer-encoding"]?.lowercased().contains("chunked") == true {
                return ended ? HTTPAnswer(status: head.status, headers: head.headers, body: Data(try Self.dechunked(body))) : nil
            }
            if let length = head.headers["content-length"].flatMap({ Int($0) }) {
                guard length >= 0 else { throw PDFServiceError.badAnswer("its answer's length was \(length)") }
                guard length <= limit else { throw PDFServiceError.tooLarge(limit) }
                if body.count >= length { return HTTPAnswer(status: head.status, headers: head.headers, body: Data(body.prefix(length))) }
                if ended { throw PDFServiceError.badAnswer("its answer ended after \(body.count) of \(length) bytes") }
                return nil
            }
            return ended ? HTTPAnswer(status: head.status, headers: head.headers, body: Data(body)) : nil
        }

        /// The status line and the headers.
        static func head(_ text: String, bodyStart: Int) throws -> (status: Int, headers: [String: String], bodyStart: Int) {
            var lines = text.components(separatedBy: "\r\n")
            let statusLine = lines.removeFirst()
            let parts = statusLine.split(separator: " ", maxSplits: 2)
            guard parts.count >= 2, parts[0].hasPrefix("HTTP/1."), parts[1].count == 3, let status = Int(parts[1]) else {
                throw PDFServiceError.badAnswer("its answer was no HTTP: \(statusLine.prefix(80))")
            }
            var headers: [String: String] = [:]
            for line in lines {
                guard let colon = line.firstIndex(of: ":") else { continue }
                let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[name] = headers[name].map { "\($0), \(value)" } ?? value
            }
            return (status, headers, bodyStart)
        }

        /// A chunked body's data, its chunks joined, its extensions and trailers set aside.
        static func dechunked(_ body: ArraySlice<UInt8>) throws -> [UInt8] {
            var data: [UInt8] = []
            var index = body.startIndex
            while true {
                guard let lineEnd = body[index...].firstRange(of: [13, 10]) else {
                    throw PDFServiceError.badAnswer("its chunked answer ended early")
                }
                let sizeText = String(decoding: body[index..<lineEnd.lowerBound], as: UTF8.self)
                    .split(separator: ";").first?.trimmingCharacters(in: .whitespaces) ?? ""
                guard let size = Int(sizeText, radix: 16), size >= 0 else {
                    throw PDFServiceError.badAnswer("its chunked answer was malformed")
                }
                // Before `size + 2` below, which a size near `Int.max` would overflow.
                guard size <= body.count else { throw PDFServiceError.badAnswer("its chunked answer ended early") }
                index = lineEnd.upperBound
                if size == 0 { return data }
                guard body.distance(from: index, to: body.endIndex) >= size + 2 else {
                    throw PDFServiceError.badAnswer("its chunked answer ended early")
                }
                let end = body.index(index, offsetBy: size)
                data += body[index..<end]
                index = body.index(end, offsetBy: 2)
            }
        }
    }
}
