// The PDF service's client (PLAN's S25a), apart from the network, which FRUSLightServerTests'
// PDFExportTests reach through a stand-in: the address `FRUS_PDF_URL` gives, the request each exchange
// sends, the form Chromium's route reads, an answer read as its bytes arrive, whichever way its length
// is told, and what Gotenberg's health check says of its Chromium.

import Foundation
import Testing

@testable import FRUSLightCore

@Suite struct PDFServiceTests {
    typealias Endpoint = PDFService.Endpoint

    @Test func theAddressIsTheURLsWithGotenbergsPath() throws {
        let sidecar = try #require(Endpoint("http://pdf:3000"))
        #expect(sidecar.host == "pdf" && sidecar.port == 3000 && !sidecar.tls && sidecar.basePath == "/")
        #expect(sidecar.authority == "pdf:3000" && sidecar.serverName == "pdf")
        let behind = try #require(Endpoint("https://Print.example.org/gotenberg?x=1"))
        #expect(behind.host == "print.example.org" && behind.port == 443 && behind.tls && behind.basePath == "/gotenberg/")
        #expect(behind.authority == "print.example.org" && behind.serverName == "print.example.org")
        let v6 = try #require(Endpoint("http://[::1]:3000/root/"))
        #expect(v6.host == "::1" && v6.authority == "[::1]:3000" && v6.basePath == "/root/" && v6.serverName == nil)
        let v4 = try #require(Endpoint("http://10.0.0.5"))
        #expect(v4.port == 80 && v4.authority == "10.0.0.5" && v4.serverName == nil)
        for url in ["ftp://pdf:3000", "pdf:3000", "http://user@pdf:3000", "http://"] {
            #expect(Endpoint(url) == nil, "\(url)")
            #expect(PDFService(url: url) == nil, "\(url)")
        }
    }

    @Test func eachRequestIsOneExchangeTheServiceThenCloses() async throws {
        let service = try #require(PDFService(url: "http://pdf:3000/"))
        #expect(String(decoding: service.request("GET", "health"), as: UTF8.self) == """
            GET /health HTTP/1.1\r
            Host: pdf:3000\r
            User-Agent: FRUS-Explorer-Light/\(FRUSLightVersion.string)\r
            Connection: close\r
            \r

            """)
        let post = String(decoding: service.request("POST", "forms/chromium/convert/html", headers: [("Accept", "application/pdf")],
                                                    body: Array("body".utf8)), as: UTF8.self)
        #expect(post.hasPrefix("POST /forms/chromium/convert/html HTTP/1.1\r\nHost: pdf:3000\r\n"))
        #expect(post.hasSuffix("Content-Length: 4\r\nAccept: application/pdf\r\n\r\nbody"))
    }

    /// The page as `files`, named `index.html`, then the app's page and its backgrounds, each a part;
    /// and a boundary the page does not hold.
    @Test func theFormIsThePageThenThePrintFields() {
        let html = Data("<!DOCTYPE html><title>Berlin</title>".utf8)
        let boundary = PDFService.boundary(avoiding: html)
        #expect(boundary.hasPrefix("frus-light-") && boundary.count == 43)
        let form = String(decoding: PDFService.form(html: html, boundary: boundary), as: UTF8.self)
        let fields = ["paperWidth": "8.5", "paperHeight": "11", "marginTop": "1", "marginBottom": "1", "marginLeft": "1",
                      "marginRight": "1", "printBackground": "true"]
        var expected = "--\(boundary)\r\nContent-Disposition: form-data; name=\"files\"; filename=\"index.html\"\r\n"
        expected += "Content-Type: text/html; charset=utf-8\r\n\r\n<!DOCTYPE html><title>Berlin</title>\r\n"
        for name in ["paperWidth", "paperHeight", "marginTop", "marginBottom", "marginLeft", "marginRight", "printBackground"] {
            expected += "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(fields[name]!)\r\n"
        }
        expected += "--\(boundary)--\r\n"
        #expect(form == expected)
    }

    @Test func anAnswerIsWholeOnceItsLengthHasCome() throws {
        let head = "HTTP/1.1 200 OK\r\nContent-Type: application/pdf\r\ncontent-length: 8\r\nX-A: 1\r\nx-a: 2\r\n\r\n"
        var reader = HTTPAnswer.Reader(limit: 1_024)
        try reader.append(Array(head.utf8.prefix(20)))
        #expect(try reader.answer(ended: false) == nil)
        try reader.append(Array(head.utf8.dropFirst(20)) + Array("%PDF".utf8))
        #expect(try reader.answer(ended: false) == nil)
        try reader.append(Array("-1.4 and more".utf8))
        let answer = try #require(try reader.answer(ended: false))
        #expect(answer.status == 200 && answer.body == Data("%PDF-1.4".utf8))
        #expect(answer.headers["content-type"] == "application/pdf" && answer.headers["x-a"] == "1, 2")
    }

    @Test func aChunkedAnswerOrOneWithNoLengthIsWholeOnceTheConnectionCloses() throws {
        var chunked = HTTPAnswer.Reader(limit: 1_024)
        try chunked.append(Array("HTTP/1.1 503 Service Unavailable\r\nTransfer-Encoding: chunked\r\n\r\n4;ext=1\r\nTime\r\n4\r\nout.\r\n0\r\nX: y\r\n\r\n".utf8))
        #expect(try chunked.answer(ended: false) == nil)
        let answer = try #require(try chunked.answer(ended: true))
        #expect(answer.status == 503 && answer.body == Data("Timeout.".utf8))
        var open = HTTPAnswer.Reader(limit: 1_024)
        try open.append(Array("HTTP/1.0 200 OK\r\n\r\n{\"status\":\"up\"}".utf8))
        #expect(try open.answer(ended: false) == nil)
        #expect(try open.answer(ended: true)?.body == Data("{\"status\":\"up\"}".utf8))
    }

    @Test func anAnswerCutShortTooLargeOrNoHTTPIsRefused() throws {
        func refusal(_ text: String, limit: Int = 1_024) -> PDFServiceError? {
            var reader = HTTPAnswer.Reader(limit: limit)
            do {
                try reader.append(Array(text.utf8))
                _ = try reader.answer(ended: true)
                return nil
            } catch {
                return error as? PDFServiceError
            }
        }
        #expect(refusal("") == .badAnswer("it answered nothing"))
        #expect(refusal("HTTP/1.1 200 OK\r\nContent-Length: 5") == .badAnswer("its answer ended in its headers"))
        #expect(refusal("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n%PDF") == .badAnswer("its answer ended after 4 of 5 bytes"))
        #expect(refusal("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n10\r\nshort") == .badAnswer("its chunked answer ended early"))
        #expect(refusal("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\n") == .badAnswer("its chunked answer was malformed"))
        // Lengths that would trap: a negative one, and a chunk's size at `Int.max`.
        #expect(refusal("HTTP/1.1 200 OK\r\nContent-Length: -1\r\n\r\n%PDF") == .badAnswer("its answer's length was -1"))
        #expect(refusal("HTTP/1.1 200 OK\r\nContent-Length: 4096\r\n\r\n%PDF") == .tooLarge(1_024))
        #expect(refusal("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n7FFFFFFFFFFFFFFF\r\nx") == .badAnswer("its chunked answer ended early"))
        #expect(refusal("SSH-2.0-OpenSSH_9.6\r\n\r\n") == .badAnswer("its answer was no HTTP: SSH-2.0-OpenSSH_9.6"))
        #expect(refusal("HTTP/1.1 200 OK\r\n\r\n" + String(repeating: "x", count: 2_000), limit: 1_024) == .tooLarge(1_024))
        var reader = HTTPAnswer.Reader(limit: 1_024)
        #expect(throws: PDFServiceError.tooLarge(1_024)) { try reader.append([UInt8](repeating: 0, count: 1_024 + 65_537)) }
    }

    /// Chromium's own status decides, whatever another module's; an answer that names none, its status.
    @Test func theHealthCheckIsChromiums() {
        func health(_ status: Int, _ body: String) -> (Bool, String) {
            let checked = PDFService.health(of: HTTPAnswer(status: status, headers: [:], body: Data(body.utf8)))
            return (checked.available, checked.reason)
        }
        #expect(health(200, #"{"status":"up","details":{"chromium":{"status":"up"},"libreoffice":{"status":"up"}}}"#) == (true, "its Chromium is up"))
        #expect(health(503, #"{"status":"down","details":{"chromium":{"status":"up"},"libreoffice":{"status":"down"}}}"#)
            == (true, "its Chromium is up"))
        #expect(health(503, #"{"status":"down","details":{"chromium":{"status":"down"}}}"#) == (false, "its Chromium is down"))
        #expect(health(200, "OK") == (true, "its health check answered 200"))
        #expect(health(404, "Not Found") == (false, "its health check answered 404"))
    }

    @Test func anErrorsWordsAreItsFirstLine() {
        #expect(PDFService.words(Data("  Invalid form data: 'paperWidth'\nmore\n".utf8)) == "Invalid form data: 'paperWidth'")
        #expect(PDFService.words(Data()) == "")
        #expect(PDFService.words(Data(String(repeating: "é", count: 400).utf8)) == String(repeating: "é", count: 300) + "…")
        #expect(PDFServiceError.refused(status: 400, detail: "Bad Request").description == "it answered 400: Bad Request")
        #expect(PDFServiceError.refused(status: 500, detail: "").description == "it answered 500")
        #expect(PDFServiceError.tooLarge(512 * 1_048_576).description == "its answer was larger than 512 MiB")
    }
}
