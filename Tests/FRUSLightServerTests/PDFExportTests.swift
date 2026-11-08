// PDF through the server's PDF service (PLAN's S25a), against a stand-in for Gotenberg on a port of this
// machine, which the server reaches as it reaches the `pdf` service, over HTTP. `GET /api/v1/pdf` says
// whether the service answers: never without `FRUS_PDF_URL`, and not while it cannot be reached or says
// its Chromium is down. A collection's PDF is its HTML export's page, posted to Chromium's route as
// `index.html` with the app's page, US Letter with an inch's margin, and its backgrounds; the service's
// PDF is answered under the name the app gives its file, and kept in the history as a PDF. What goes
// wrong is the sheet's refusal, kept nowhere: a service that does not answer or is too busy a 503 the
// sheet can try again, any other failure a 502 with the service's words.

import FRUSLightCore
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

/// A stand-in for Gotenberg: its health check and its Chromium route answer as a test sets them, and it
/// keeps what it was asked.
actor StandInPDFService {
    static let up = #"{"status":"up","details":{"chromium":{"status":"up","timestamp":"2026-11-08T12:00:00Z"}}}"#
    static let pdf = Data("%PDF-1.4\n% A stand-in's PDF\n%%EOF\n".utf8)

    private(set) var health: (status: HTTPResponse.Status, body: String) = (.ok, up)
    private(set) var answer: (status: HTTPResponse.Status, contentType: String, body: Data) = (.ok, "application/pdf", pdf)
    private(set) var checks = 0
    private(set) var prints: [(contentType: String, body: Data)] = []

    func answerHealth(_ status: HTTPResponse.Status, _ body: String) {
        health = (status, body)
    }

    func answerPrints(_ status: HTTPResponse.Status, _ contentType: String, _ body: Data) {
        answer = (status, contentType, body)
    }

    fileprivate func checked() -> (status: HTTPResponse.Status, body: String) {
        checks += 1
        return health
    }

    fileprivate func printed(_ contentType: String, _ body: Data) -> (status: HTTPResponse.Status, contentType: String, body: Data) {
        prints.append((contentType, body))
        return answer
    }

    /// Its two routes, Gotenberg's.
    nonisolated var app: some ApplicationProtocol {
        let router = Router()
        router.get("/health") { _, _ -> Response in
            let health = await self.checked()
            return Response(status: health.status, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(string: health.body)))
        }
        router.post("/forms/chromium/convert/html") { request, _ -> Response in
            let body = try await request.body.collect(upTo: 64 * 1_048_576)
            let answer = await self.printed(request.headers[.contentType] ?? "", Data(buffer: body))
            return Response(status: answer.status, headers: [.contentType: answer.contentType],
                            body: .init(byteBuffer: ByteBuffer(bytes: answer.body)))
        }
        return Application(router: router)
    }
}

/// One part of a `multipart/form-data` body.
struct FormPart: Equatable {
    var name: String
    var fileName: String?
    var contentType: String?
    var body: Data

    /// The parts of `form`, split on `boundary`.
    static func parts(of form: Data, boundary: String) -> [FormPart] {
        let delimiter = Data("--\(boundary)".utf8)
        var pieces: [Data] = []
        var rest = form[...]
        while let found = rest.range(of: delimiter) {
            pieces.append(Data(rest[rest.startIndex..<found.lowerBound]))
            rest = rest[found.upperBound...]
        }
        guard Data(rest) == Data("--\r\n".utf8) else { return [] }
        return pieces.dropFirst().compactMap { piece -> FormPart? in
            guard piece.starts(with: Data("\r\n".utf8)), let end = piece.range(of: Data("\r\n\r\n".utf8)) else { return nil }
            let head = String(decoding: piece[(piece.startIndex + 2)..<end.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
            var body = Data(piece[end.upperBound...])
            guard body.suffix(2) == Data("\r\n".utf8) else { return nil }
            body.removeLast(2)
            func quoted(_ key: String) -> String? {
                guard let disposition = head.first(where: { $0.hasPrefix("Content-Disposition: form-data;") }),
                      let start = disposition.range(of: "\(key)=\"") else { return nil }
                return String(disposition[start.upperBound...].prefix { $0 != "\"" })
            }
            guard let name = quoted(" name") else { return nil }
            let type = head.first { $0.hasPrefix("Content-Type: ") }.map { String($0.dropFirst("Content-Type: ".count)) }
            return FormPart(name: name, fileName: quoted("filename"), contentType: type, body: body)
        }
    }
}

@Suite struct PDFExportTests {
    static let base = CollectionTests.base

    /// The fixture's server, its PDF service the one at `pdfURL`, or none, in a state of its own, so that
    /// each server asks its service afresh.
    static func app(_ fixture: UserDataFixture, pdfURL: String?) -> some ApplicationProtocol {
        var configuration = ServerConfiguration(dataDirectory: fixture.server.files.root)
        configuration.pdfURL = pdfURL
        let state = ServerState(configuration: configuration)
        return Application(router: ServedRouter(base: .root, router: buildRouter(
            state: state, resources: fixture.server.resources, reader: fixture.server.reader, userData: fixture.services)))
    }

    static func available(_ client: some TestClientProtocol) async throws -> Bool {
        let answer = try await client.execute(uri: "/api/v1/pdf", method: .get)
        #expect(answer.status == .ok && answer.headers[.cacheControl] == "no-store")
        return try decode(PDFAvailability.self, answer).available
    }

    /// A collection of `documents` of the fixture's volume, by its owner.
    static func collection(_ owner: Browser, _ name: String, _ documents: [String]) async throws -> String {
        let made = try await CollectionTests.made(owner, name)
        _ = try await CollectionTests.edit(owner, "\(Self.base)/\(made.id)/documents", try CollectionTests.documents(documents))
        return made.id
    }

    /// With no `FRUS_PDF_URL` the server offers no PDF, and refuses one as a format it does not export.
    @Test func withNoAddressThereIsNoPDF() async throws {
        let fixture = try await UserDataFixture(volumes: [CollectionTests.volume])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            #expect(try await Self.available(client) == false)
            let unknown = try await client.execute(uri: "/api/v1/pdf?format=pdf", method: .get)
            #expect(unknown.status == .badRequest && problemCode(unknown) == "UNKNOWN_PARAMETER")
            let owner = Browser(client: client)
            let berlin = try await Self.collection(owner, "Berlin", ["d1"])
            let refused = try await CollectionExportTests.export(owner, berlin, "pdf")
            #expect(refused.status == .badRequest && problemCode(refused) == "INVALID_FIELD")
            #expect(try decode(APIProblem.Body.self, refused).detail
                == "format: pdf is not a format this server exports: html, docx, bibtex, zoteroJSON, fruscollection.")
        }
    }

    /// The done-when's server half: a collection's PDF is its HTML export's page printed by the service,
    /// named as the app names its PDF, and kept in the history as one.
    @Test func aCollectionsPDFIsItsHTMLExportPrintedByTheService() async throws {
        let fixture = try await UserDataFixture(volumes: [CollectionTests.volume])
        defer { withExtendedLifetime(fixture) {} }
        let service = StandInPDFService()
        try await service.app.test(.live) { standIn in
            let address = "http://localhost:\(try #require(standIn.port))"
            try await Self.app(fixture, pdfURL: address).test(.router) { client in
                #expect(try await Self.available(client))
                #expect(try await Self.available(client))
                #expect(await service.checks == 1, "the service is asked at most every ten seconds")

                let owner = Browser(client: client)
                let cafe = try await Self.collection(owner, "Café / Berlin", ["d1", "d2"])
                let pdf = try await CollectionExportTests.export(owner, cafe, "pdf", timeZone: "Europe/London")
                #expect(pdf.status == .ok && pdf.headers[.contentType] == "application/pdf")
                #expect(pdf.headers[.contentDisposition] == "attachment; filename=\"Caf_ - Berlin.pdf\"; filename*=UTF-8''Caf%C3%A9%20-%20Berlin.pdf")
                #expect(pdf.headers[.cacheControl] == "no-store" && pdf.headers[.xContentTypeOptions] == "nosniff")
                #expect(Data(buffer: pdf.body) == StandInPDFService.pdf)

                // What Chromium was given: the HTML export's page, byte for byte, as `index.html`, then the
                // app's page, US Letter with an inch's margin, and its backgrounds printed.
                let html = try await CollectionExportTests.export(owner, cafe, "html", timeZone: "Europe/London")
                let prints = await service.prints
                #expect(prints.count == 1)
                let form = try #require(prints.first)
                let boundary = try #require(form.contentType.components(separatedBy: "multipart/form-data; boundary=").last)
                #expect(form.contentType == "multipart/form-data; boundary=\(boundary)" && !boundary.isEmpty)
                let parts = FormPart.parts(of: form.body, boundary: boundary)
                #expect(parts.map(\.name) == ["files", "paperWidth", "paperHeight", "marginTop", "marginBottom", "marginLeft", "marginRight",
                                              "printBackground"])
                let page = try #require(parts.first)
                #expect(page.fileName == "index.html" && page.contentType == "text/html; charset=utf-8")
                #expect(page.body == Data(buffer: html.body), "the HTML export's page")
                #expect(String(decoding: page.body, as: UTF8.self).contains("@media print"), "with its print CSS")
                #expect(parts.dropFirst().map { String(decoding: $0.body, as: UTF8.self) } == ["8.5", "11", "1", "1", "1", "1", "true"])

                // Kept in the history as the app keeps a PDF: its format's raw value and name.
                let history = try decode(HistoryPage.self, try await owner.get("/api/v1/me/history"))
                #expect(history.exports.map(\.format) == ["html", "pdf"])
                #expect(history.exports.map(\.formatName) == ["HTML", "PDF"])
                #expect(history.exports.map(\.documentCount) == [2, 2])
            }
        }
    }

    /// The service's Chromium decides, whatever another module says; one that is down, or a service that
    /// cannot be reached, offers no PDF and refuses one at once, before anything is printed.
    @Test func noPDFIsOfferedWhileTheServiceDoesNotAnswer() async throws {
        let fixture = try await UserDataFixture(volumes: [CollectionTests.volume])
        defer { withExtendedLifetime(fixture) {} }
        let service = StandInPDFService()
        try await service.app.test(.live) { standIn in
            let address = "http://localhost:\(try #require(standIn.port))"
            await service.answerHealth(.serviceUnavailable,
                                       #"{"status":"down","details":{"chromium":{"status":"up"},"libreoffice":{"status":"down"}}}"#)
            try await Self.app(fixture, pdfURL: address).test(.router) { client in
                let available = try await Self.available(client)
                #expect(available, "LibreOffice's state is not Chromium's")
            }
            await service.answerHealth(.serviceUnavailable, #"{"status":"down","details":{"chromium":{"status":"down"}}}"#)
            for url in [address, "http://localhost:1"] {
                try await Self.app(fixture, pdfURL: url).test(.router) { client in
                    #expect(try await Self.available(client) == false, "\(url)")
                    let owner = Browser(client: client)
                    let berlin = try await Self.collection(owner, "Berlin", ["d1"])
                    let refused = try await CollectionExportTests.export(owner, berlin, "pdf")
                    #expect(refused.status == .serviceUnavailable && problemCode(refused) == "PDF_SERVICE_UNAVAILABLE", "\(url)")
                    #expect(try decode(APIProblem.Body.self, refused).detail == PDFRoutes.unavailable.detail)
                }
            }
            #expect(await service.prints.isEmpty)
            let history = try await fixture.app.test(.router) { client in
                try decode(HistoryPage.self, try await Browser(client: client).get("/api/v1/me/history"))
            }
            #expect(history.totalExports == 0, "a refusal is kept nowhere")
        }
    }

    /// A PDF the service cannot make: too busy, as Gotenberg's 503 says a print past its time limit is, a
    /// 503 to try again; an error of its own, or an answer that is no PDF, a 502 with its words.
    @Test func aPDFTheServiceCannotMakeIsTheSheetsRefusal() async throws {
        let fixture = try await UserDataFixture(volumes: [CollectionTests.volume])
        defer { withExtendedLifetime(fixture) {} }
        let service = StandInPDFService()
        try await service.app.test(.live) { standIn in
            let address = "http://localhost:\(try #require(standIn.port))"
            try await Self.app(fixture, pdfURL: address).test(.router) { client in
                let owner = Browser(client: client)
                let berlin = try await Self.collection(owner, "Berlin", ["d1"])
                let cases: [(HTTPResponse.Status, String, String, HTTPResponse.Status, String, String?)] = [
                    (.serviceUnavailable, "text/plain", "Service Unavailable", .serviceUnavailable, "PDF_SERVICE_UNAVAILABLE", nil),
                    (.badRequest, "text/plain; charset=UTF-8", "Invalid form data: 'paperWidth'\nmore", .badGateway, "PDF_NOT_MADE",
                     "The server’s PDF service could not make this PDF: it answered 400: Invalid form data: 'paperWidth'."),
                    (.ok, "text/html", "<html></html>", .badGateway, "PDF_NOT_MADE",
                     "The server’s PDF service could not make this PDF: its answer was no PDF but text/html of 13 bytes."),
                ]
                for (status, type, body, refusal, code, detail) in cases {
                    await service.answerPrints(status, type, Data(body.utf8))
                    let refused = try await CollectionExportTests.export(owner, berlin, "pdf")
                    #expect(refused.status == refusal && problemCode(refused) == code, "\(status)")
                    if let detail { #expect(try decode(APIProblem.Body.self, refused).detail == detail) }
                }
                #expect(await service.prints.count == 3)
                #expect(try decode(HistoryPage.self, try await owner.get("/api/v1/me/history")).totalExports == 0, "a refusal is kept nowhere")
            }
        }
    }
}
